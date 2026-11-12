-- luajit tests/integration/gamepad/gamepad.lua
function GetLocale() return "enUS" end
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do copy[key] = type(value) == "table" and CopyTable(value) or value end
    return copy
end

-- Client state that outlives a "reload": CVars, stored device configs.
local gamepadUI, combat, timers = true, false, {}
local cvars, temp, cvarWrites = { GamepadDisableTooltips = "0" }, {}, 0
local configs, setConfigCalls, applyCalls, setConfigFails, setConfigSilent = {}, 0, 0, false, false
local function Id(id) return tostring(id.vendorID) .. ":" .. tostring(id.productID) end
local device = { vendorID = 1, productID = 2 }
local function Config(buttons)
    local mappings = {}
    for index, name in ipairs(buttons) do mappings[index] = { rawIndex = index, button = name } end
    return { configID = { vendorID = 1, productID = 2 }, rawButtonMappings = mappings,
        rawAxisMappings = { { rawIndex = 1, axis = "LeftX" } }, axisConfigs = {}, stickConfigs = {} }
end
local function Buttons(id)
    local names = {}
    for _, mapping in ipairs(configs[id].rawButtonMappings) do names[#names + 1] = mapping.button end
    return table.concat(names, ",")
end
local function ResetConfig() configs["1:2"] = Config({ "PAD1", "PAD2", "PAD3", "PAD4", "PADLSHOULDER" }) end

InputUtil = { IsGamepadUIEnabled = function() return gamepadUI end }
InCombatLockdown = function() return combat end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
C_CVar = {
    GetCVarBool = function(name) return cvars[name] == "1" end,
    SetCVar = function(name, value) cvarWrites = cvarWrites + 1; cvars[name] = value; return true end,
    SetTempCVar = function(name, value) temp[name] = value end,
}
C_GamePad = {
    GetAllDeviceIDs = function() return { 3, 7 } end, -- 3 is the combined device without a raw state
    GetDeviceRawState = function(id) return id == 7 and device or nil end,
    GetAllConfigIDs = function()
        local ids = {}
        for _, config in pairs(configs) do ids[#ids + 1] = config.configID end
        return ids
    end,
    GetConfig = function(id) return configs[Id(id)] and CopyTable(configs[Id(id)]) end,
    SetConfig = function(config)
        setConfigCalls = setConfigCalls + 1
        if setConfigFails then error("restricted") end
        if setConfigSilent then return end -- HasRestrictions returns nothing
        configs[Id(config.configID)] = CopyTable(config)
    end,
    DeleteConfig = function(id) configs[Id(id)] = nil end,
    ApplyConfigs = function() applyCalls = applyCalls + 1 end,
}
local registered = {}
EventRegistry = { RegisterFrameEventAndCallback = function(_, event, callback) registered[event] = callback end }
local frames
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, callback) self.onEvent = callback end
    frames[#frames + 1] = frame
    return frame
end

local function Flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

-- A fresh addon session on the persisted database; Blizzard's transition handler runs after ours.
local function Boot(db)
    frames, registered, timers = {}, {}, {}
    local ns = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
    assert(loadfile("Modules/Gamepad/Gamepad.lua"))("PyresinQoL", ns)
    PyresinQoLDB = db
    db.profileStore = db.profileStore or {}
    ns.InitializeModules()
    local session = { ns = ns, module = ns.GetModule("gamepad") }
    function session.Fire(event)
        if frames[1] then
            assert(frames[1].events[event], event .. " is not registered")
            frames[1].onEvent(frames[1], event)
        elseif registered[event] then registered[event]() end
        if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
            if gamepadUI then temp.SoftTargetInteractRange = "20" else temp.SoftTargetInteractRange = nil end
        end
        Flush()
    end
    return session
end

-- Loot-roll tooltips: only in gamepad mode, only when R3 left them off, only with the setting.
local db = { modules = {} }
local session = Boot(db)
assert(frames[1].events.START_LOOT_ROLL)
session.Fire("START_LOOT_ROLL")
assert(cvarWrites == 0, "Nothing to reset while tooltips are on")
cvars.GamepadDisableTooltips = "1"
gamepadUI = false
session.Fire("START_LOOT_ROLL")
assert(cvars.GamepadDisableTooltips == "1", "Mouse and keyboard mode keeps the CVar")
gamepadUI = true
db.gamepadLootTooltips = false
session.Fire("START_LOOT_ROLL")
assert(cvars.GamepadDisableTooltips == "1", "The setting turns the reset off")
db.gamepadLootTooltips = true
session.Fire("START_LOOT_ROLL")
assert(cvars.GamepadDisableTooltips == "0", "A loot roll turns tooltips back on")

-- Interaction range: applied after Blizzard's 20, kept out of mouse and keyboard mode.
temp = {}
db.gamepadInteractRange = 30
session.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
assert(temp.SoftTargetInteractRange == "30", "Applied after Blizzard's gamepad init")
db.gamepadInteractRange = 20
session.module.UpdateGamepad()
assert(temp.SoftTargetInteractRange == "20", "Lowering to Blizzard's value restores it")
db.gamepadInteractRange = 99
session.module.UpdateGamepad()
assert(temp.SoftTargetInteractRange == "40", "Capped at the slider maximum")
gamepadUI = false
session.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
assert(temp.SoftTargetInteractRange == nil, "Nothing left behind in mouse and keyboard mode")
session.module.UpdateGamepad()
assert(temp.SoftTargetInteractRange == nil, "Setting changes do nothing outside gamepad mode")
gamepadUI = true
C_CVar.SetTempCVar = function() error("rejected") end
session.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
C_CVar.SetTempCVar = function(name, value) temp[name] = value end
temp = {}
Boot({ modules = { gamepad = false }, gamepadInteractRange = 30 }).Fire("PLAYER_LOGIN")
assert(temp.SoftTargetInteractRange == nil, "A disabled module leaves Blizzard's value alone")

-- The login path of a player already in gamepad mode.
temp = { SoftTargetInteractRange = "20" }
Boot({ modules = {}, gamepadInteractRange = 30 }).Fire("PLAYER_LOGIN")
assert(temp.SoftTargetInteractRange == "30", "Applied at login")

-- Nintendo labels on a stored config: written once, kept across reloads, restored, buttons untouched.
ResetConfig()
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == "Reverse" and db.profileStore.gamepadLabels["1:2"] == false and applyCalls == 1)
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER" and configs["1:2"].rawAxisMappings[1].axis == "LeftX")
assert(session.module.needsReload and session.ns.ModulesNeedReload(), "The icons change after a reload, so the window offers one")
session.Fire("GAME_PAD_CONNECTED")
session.Fire("GAME_PAD_ACTIVE_CHANGED")
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(setConfigCalls == 1 and not session.ns.ModulesNeedReload(), "Reconciling and reloading write nothing again")
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil and next(db.profileStore.gamepadLabels) == nil, "Switching off restores the style")
session.module.UpdateGamepad()
assert(setConfigCalls == 2, "Nothing to take back twice")

-- Combat defers the write.
db.gamepadSwitchLabels = true
combat = true
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil, "No config writes in combat")
combat = false
session.Fire("PLAYER_REGEN_ENABLED")
assert(configs["1:2"].labelStyle == "Reverse")

-- Disabling the module takes the labels back at the next load, without a frame, with the setting still on.
local store = db.profileStore
Boot({ modules = { gamepad = false }, gamepadSwitchLabels = true, profileStore = store }).Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == nil and #frames == 0 and next(store.gamepadLabels) == nil)

-- A replaced style comes back, and a pad that already shows Nintendo labels is left alone.
configs["1:2"].labelStyle = "Shapes"
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == "Shapes")
configs["1:2"].labelStyle = "Reverse"
db.gamepadSwitchLabels = true
session.module.UpdateGamepad()
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == "Reverse" and next(db.profileStore.gamepadLabels) == nil)

-- Config IDs without vendor or product ID do not abort the reconcile.
ResetConfig()
configs["nil:nil"] = { configID = {}, rawButtonMappings = {}, rawAxisMappings = {} }
configs["9:nil"] = { configID = { vendorID = 9 }, rawButtonMappings = {}, rawAxisMappings = {} }
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == "Reverse" and configs["nil:nil"].labelStyle == nil)
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil)
configs["nil:nil"], configs["9:nil"] = nil, nil

-- Mouse and keyboard mode never applies, a transition to gamepad mode does, switching off still takes back.
gamepadUI = false
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil, "Nothing in mouse and keyboard mode")
gamepadUI = true
session.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
assert(configs["1:2"].labelStyle == "Reverse", "Applied once gamepad mode starts")
gamepadUI = false
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil, "Taken back in mouse and keyboard mode")
gamepadUI = true

-- A pad that connects after login gets the labels.
local saved = device
device = nil
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == nil, "No pad, no labels")
device = saved
session.Fire("GAME_PAD_CONNECTED")
assert(configs["1:2"].labelStyle == "Reverse")
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()

-- A SetConfig that is restricted, silently or with an error, records nothing.
for _, flag in ipairs({ "silent", "fails" }) do
    setConfigSilent, setConfigFails = flag == "silent", flag == "fails"
    db = { modules = {}, gamepadSwitchLabels = true }
    session = Boot(db)
    session.Fire("PLAYER_LOGIN")
    assert(next(db.profileStore.gamepadLabels) == nil and configs["1:2"].labelStyle == nil, flag)
end
setConfigSilent, setConfigFails = false, false

-- A pad without a stored config gets one that only carries the style, and it is deleted again.
configs = {}
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == "Reverse" and #configs["1:2"].rawButtonMappings == 0)
assert(db.profileStore.gamepadLabels["1:2"] == true)
setConfigCalls = 0
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(setConfigCalls == 0, "A reload writes nothing again")
db.modules.gamepad = false
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"] == nil and next(db.profileStore.gamepadLabels) == nil, "A disabled module deletes the config it created")
C_GamePad = nil
session.Fire("PLAYER_LOGIN")
print("PASS: loot-roll tooltips, interaction range ordering and restore, idempotent reversible Nintendo labels")
