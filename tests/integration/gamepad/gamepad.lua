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

-- Face buttons: swapped once, kept across reloads, reverted, and never destructive.
ResetConfig()
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER", "A and B swapped, nothing else")
assert(configs["1:2"].rawAxisMappings[1].axis == "LeftX" and applyCalls == 1)
session.Fire("GAME_PAD_CONNECTED")
session.Fire("GAME_PAD_ACTIVE_CHANGED")
assert(setConfigCalls == 1, "Reconciling again never swaps twice")
session = Boot(db) -- reload: the client stored the swapped config
session.Fire("PLAYER_LOGIN")
assert(setConfigCalls == 1 and Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER", "A reload does not swap back")
db.gamepadSwapXY = true
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD2,PAD1,PAD4,PAD3,PADLSHOULDER" and setConfigCalls == 2)
db.gamepadSwapAB, db.gamepadSwapXY = false, false
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "Switching off restores the layout")
assert(next(db.profileStore.gamepadSwaps) == nil, "Nothing recorded once reverted")
local calls = setConfigCalls
session.module.UpdateGamepad()
assert(setConfigCalls == calls, "Nothing to revert twice")

-- Combat defers the write.
db.gamepadSwapAB = true
combat = true
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "No config writes in combat")
combat = false
session.Fire("PLAYER_REGEN_ENABLED")
assert(Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER")

-- Disabling the module takes the swap back at the next load, without a frame, with the setting still on.
local store = db.profileStore
Boot({ modules = { gamepad = false }, gamepadSwapAB = true, profileStore = store }).Fire("PLAYER_LOGIN")
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER" and #frames == 0)
assert(next(store.gamepadSwaps) == nil, "Record cleared")

-- Config IDs without vendor or product ID do not abort the reconcile.
ResetConfig()
configs["nil:nil"] = { configID = {}, rawButtonMappings = {}, rawAxisMappings = {} }
configs["9:nil"] = { configID = { vendorID = 9 }, rawButtonMappings = {}, rawAxisMappings = {} }
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER", "Swapped despite partial config IDs")
db.gamepadSwapAB = false
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "Reverted despite partial config IDs")
configs["nil:nil"], configs["9:nil"] = nil, nil

-- Mouse and keyboard mode never starts a swap, a transition to gamepad mode does, switching off still reverts.
gamepadUI = false
calls = setConfigCalls
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
session.module.UpdateGamepad()
assert(setConfigCalls == calls, "No swap in mouse and keyboard mode")
gamepadUI = true
session.Fire("INPUT_DEVICE_INTERFACE_TRANSITION")
assert(Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER", "Swapped once gamepad mode starts")
gamepadUI = false
db.gamepadSwapAB = false
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "Reverts in mouse and keyboard mode")
gamepadUI = true

-- A pad that connects after login gets the swap.
local saved = device
device = nil
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "No pad, no swap")
device = saved
session.Fire("GAME_PAD_CONNECTED")
assert(Buttons("1:2") == "PAD2,PAD1,PAD3,PAD4,PADLSHOULDER", "Swapped when the pad connects")
db.gamepadSwapAB = false
session.module.UpdateGamepad()

-- A restricted SetConfig that returns silently records nothing and cannot invert the layout later.
setConfigSilent = true
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(next(db.profileStore.gamepadSwaps) == nil and Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER")
setConfigSilent = false
db.gamepadSwapAB = false
session.module.UpdateGamepad()
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "Switching off after a silent reject keeps the layout")

-- No stored config, or a rejected SetConfig: nothing happens and nothing is recorded.
configs = {}
db = { modules = {}, gamepadSwapAB = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(next(db.profileStore.gamepadSwaps) == nil)
ResetConfig()
setConfigCalls, setConfigFails = 0, true
session.Fire("PLAYER_LOGIN")
assert(setConfigCalls == 1 and next(db.profileStore.gamepadSwaps) == nil and Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER")
setConfigFails = false

-- Nintendo labels: the config gets Blizzard's "Reverse" style once, and switching off restores what was there.
db = { modules = {}, gamepadSwitchLabels = true }
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == "Reverse" and db.profileStore.gamepadSwaps["1:2"].labels == false)
assert(Buttons("1:2") == "PAD1,PAD2,PAD3,PAD4,PADLSHOULDER", "Labels leave the buttons alone")
setConfigCalls = 0
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(setConfigCalls == 0, "A reload writes nothing again")
db.gamepadSwitchLabels = false
session.module.UpdateGamepad()
assert(configs["1:2"].labelStyle == nil and next(db.profileStore.gamepadSwaps) == nil)
configs["1:2"].labelStyle = "Shapes"
db.gamepadSwitchLabels = true
session.module.UpdateGamepad()
db.modules.gamepad = false
session = Boot(db)
session.Fire("PLAYER_LOGIN")
assert(configs["1:2"].labelStyle == "Shapes", "A disabled module restores the style it replaced")
C_GamePad = nil
session.Fire("PLAYER_LOGIN")
print("PASS: loot-roll tooltips, interaction range ordering and restore, idempotent reversible face-button swap and Nintendo labels")
