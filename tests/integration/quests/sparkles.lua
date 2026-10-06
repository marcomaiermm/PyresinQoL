-- Run from the addon directory: luajit tests/integration/quests/sparkles.lua
local ns = {}
function GetLocale() return "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Quests/Sparkles.lua"))("PyresinQoL", ns)
assert(loadfile("Settings/Controls.lua"))("PyresinQoL", ns)

-- Exercise NotifyUpdate through the real registered-setting callback and module guards.
Settings = { RegisterAddOnSetting = function(_, _, key, db, _, _, default)
    if db[key] == nil then db[key] = default end
    local setting = {}
    function setting:SetValueChangedCallback(callback) self.callback = callback end
    function setting:NotifyUpdate() self.callback(self, db[key]) end
    return setting
end }
local reportedErrors, setting = {}, nil
function geterrorhandler()
    return function(message) reportedErrors[#reportedErrors + 1] = message end
end

local names = { "outlineModeShowLootEffectWhenDisabled", "graphicsOutlineMode", "OutlineEngineMode",
    "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" }
local values, writes, timers, frame, combat, now
local invalidWrites = {}
local module = ns.GetModule("quests")
function InCombatLockdown() return combat end
function CreateFrame()
    frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(name, callback) assert(name == "OnEvent"); self.callback = callback end
    return frame
end
local function Send(event, name)
    if frame.events[event] then frame.callback(frame, event, name) end
end
C_CVar = {
    GetCVar = function(name) return values[name] end,
    SetCVar = function(name, value)
        -- Production catches write errors; retain invalid attempts outside pcall.
        if combat or values[name] == nil or values[name] == value then invalidWrites[#invalidWrites + 1] = name end
        assert(not combat, "Never write CVars during combat")
        assert(values[name] ~= nil, "Never write an unavailable CVar")
        assert(values[name] ~= value, "Never rewrite an unchanged CVar")
        values[name] = value
        writes[#writes + 1] = { name, value }
        Send("CVAR_UPDATE", name:upper())
    end,
}
C_Timer = { NewTimer = function(delay, callback)
    local timer = { at = now + delay, callback = callback }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end }
local function Advance(seconds)
    now = now + seconds
    for _, timer in ipairs(timers) do
        if not timer.cancelled and not timer.fired and timer.at <= now then
            timer.fired = true
            timer.callback()
        end
    end
end
local function ActiveTimers()
    local count = 0
    for _, timer in ipairs(timers) do
        if not timer.cancelled and not timer.fired then count = count + 1 end
    end
    return count
end
local function Start(enabled, inCombat)
    assert(#invalidWrites == 0, "Caught write errors must not hide invalid CVar attempts")
    values, writes, timers, combat, now = {}, {}, {}, inCombat, 0
    for _, name in ipairs(names) do values[name] = "2" end
    values[names[1]] = "0"
    PyresinQoLDB = { modules = { quests = true }, questItemSparkles = enabled }
    module.initializers[1](module)
    module.active = true
    setting = ns.CreateSettingsControls({}).Register({ module = module, settings = {} },
        "QuestItemSparkles", "questItemSparkles", "boolean", ns.L.questItemSparkles, false, module.UpdateQuestSparkles)
    reportedErrors = {}
    assert(#writes == 0 and ActiveTimers() == 0, "Wait for login")
    Send("PLAYER_LOGIN")
    assert(not frame.events.PLAYER_LOGIN)
end
local function Expect(enabled)
    assert(values[names[1]] == (enabled and "1" or "0"))
    for index = 2, #names do assert(values[names[index]] == (enabled and "0" or "2")) end
end

Start(nil, false)
Expect(false)
assert(PyresinQoLDB.questItemSparkles == false and #writes == 0 and ActiveTimers() == 0,
    "Default off must leave the player's graphics untouched")
setting:NotifyUpdate()
assert(#writes == 0 and not module.questSparklesRestartPending, "Default off must not reset or prompt")

Start(true, false)
Expect(true)
assert(#writes == 5 and ActiveTimers() == 1, "Only the late-login check remains")
Send("CVAR_UPDATE", "unrelated")
Send("CVAR_UPDATE")
Send("CVAR_UPDATE", 42)
for _, name in ipairs(names) do Send("CVAR_UPDATE", name) end
assert(ActiveTimers() == 1, "Ignore unrelated, unchanged and self-generated events")
-- Late graphics initialization need not send CVAR_UPDATE.
values.raidGraphicsOutlineMode = "2"
Advance(4.9)
assert(#writes == 5)
Advance(0.1)
Expect(true)
assert(#writes == 6 and ActiveTimers() == 0)
for _ = 1, 100 do
    for _, name in ipairs(names) do
        values[name] = "2"
        Send("CVAR_UPDATE", name:upper())
    end
end
assert(ActiveTimers() == 1, "A preset event storm must schedule only one timer")
Advance(0.9)
assert(#writes == 6)
Advance(0.1)
Expect(true)
assert(#writes == 11 and ActiveTimers() == 0, "Self writes must not create a timer loop")
module.UpdateQuestSparkles() -- Profile NotifyUpdate with the same value.
assert(#writes == 11 and ActiveTimers() == 0)

values.graphicsOutlineMode = "2"
Send("CVAR_UPDATE", "graphicsOutlineMode")
combat = true
Advance(1)
assert(#writes == 11 and frame.events.PLAYER_REGEN_ENABLED)
for _ = 1, 100 do Send("CVAR_UPDATE", "graphicsOutlineMode") end
assert(ActiveTimers() == 0, "While pending combat exit, don't keep scheduling timers")
PyresinQoLDB.questItemSparkles = false
module.UpdateQuestSparkles()
assert(#writes == 11 and not frame.events.CVAR_UPDATE)
combat = false
Send("PLAYER_REGEN_ENABLED")
Expect(false)
assert(#writes == 15 and not frame.events.PLAYER_REGEN_ENABLED, "Combat exit applies the latest option")
module.UpdateQuestSparkles()
Advance(10)
assert(#writes == 15, "Off is a one-time reset, not continuing enforcement")
values.graphicsOutlineMode = "1"
Send("CVAR_UPDATE", "graphicsOutlineMode")
Advance(2)
assert(values.graphicsOutlineMode == "1" and ActiveTimers() == 0)
PyresinQoLDB.questItemSparkles = true
module.UpdateQuestSparkles()
Expect(true)
assert(#writes == 20 and frame.events.CVAR_UPDATE, "Re-enable works immediately")

Start(true, false)
values.graphicsOutlineMode = "2"
Send("CVAR_UPDATE", "graphicsOutlineMode")
assert(ActiveTimers() == 2)
PyresinQoLDB.questItemSparkles = false
module.UpdateQuestSparkles()
Expect(false)
assert(ActiveTimers() == 0, "Disabling cancels both preset and late-login timers")
local count = #writes
Advance(10)
assert(#writes == count)

Start(true, true)
assert(#writes == 0 and frame.events.PLAYER_REGEN_ENABLED)
Advance(5)
assert(#writes == 0 and ActiveTimers() == 0)
PyresinQoLDB.questItemSparkles = false
module.UpdateQuestSparkles()
PyresinQoLDB.questItemSparkles = true
module.UpdateQuestSparkles()
combat = false
Send("PLAYER_REGEN_ENABLED")
Expect(true)
assert(#writes == 5 and not frame.events.PLAYER_REGEN_ENABLED)

Start(false, false)
assert(#writes == 0 and ActiveTimers() == 0 and not frame.events.CVAR_UPDATE)
-- Existing user graphics values survive disabled startup and repeated profile refreshes.
values.graphicsOutlineMode = "1"
module.UpdateQuestSparkles()
Advance(10)
assert(#writes == 0 and values.graphicsOutlineMode == "1")
PyresinQoLDB.questItemSparkles = true
module.UpdateQuestSparkles()
Expect(true)
assert(#writes == 5)
-- Preset events can arrive before outlines change, without per-outline events.
Start(true, false)
Advance(5)
for _, preset in ipairs({ "graphicsQuality", "RAIDGraphicsQuality" }) do
    local count = #writes
    for _ = 1, 100 do Send("CVAR_UPDATE", preset) end
    assert(ActiveTimers() == 1, "Preset events must schedule one delayed check even with correct outlines")
    Advance(0.5)
    values.graphicsOutlineMode = "2"
    Advance(0.5)
    Expect(true)
    assert(#writes == count + 1 and ActiveTimers() == 0)
end
Send("CVAR_UPDATE", "graphicsQuality")
local count = #writes
Advance(1)
assert(#writes == count, "A preset check must not rewrite correct values")
PyresinQoLDB.questItemSparkles = false
module.UpdateQuestSparkles()
Send("CVAR_UPDATE", "raidGraphicsQuality")
assert(ActiveTimers() == 0, "Ignore preset events while disabled")

Start(false, false)
values.OutlineEngineMode = nil
PyresinQoLDB.questItemSparkles = true
module.UpdateQuestSparkles()
assert(values.OutlineEngineMode == nil and #writes == 4, "Skip unavailable CVars; apply the others")
Send("CVAR_UPDATE", "OutlineEngineMode")
Advance(1)
assert(#writes == 4)
PyresinQoLDB.questItemSparkles = false
module.UpdateQuestSparkles()
assert(values.OutlineEngineMode == nil and #writes == 8, "Disabling also skips unavailable CVars")

-- A failed off transition must remain retryable through NotifyUpdate, unlike disabled startup.
Start(true, false)
Advance(5)
local setCVar = C_CVar.SetCVar
C_CVar.SetCVar = function(name, value)
    if name == "graphicsOutlineMode" and value == "2" then error("simulated-reset-failure") end
    setCVar(name, value)
end
PyresinQoLDB.questItemSparkles = false
setting:NotifyUpdate()
assert(values.graphicsOutlineMode == "0" and #writes == 9, "Apply the other reset values despite one failure")
assert(not module.questSparklesRestartPending, "Do not imply that a failed reset is complete")
C_CVar.SetCVar = setCVar
setting:NotifyUpdate()
Expect(false)
assert(#writes == 10 and ActiveTimers() == 0 and module.questSparklesRestartPending,
    "NotifyUpdate must finish only the incomplete reset and request the restart reminder")
assert(#reportedErrors == 1 and reportedErrors[1]:find("graphicsOutlineMode", 1, true)
    and reportedErrors[1]:find("simulated-reset-failure", 1, true), "Reset errors must stay visible with CVar context")
values.graphicsOutlineMode = "1"
setting:NotifyUpdate()
assert(#writes == 10 and values.graphicsOutlineMode == "1", "A completed reset must stop touching disabled profiles")
Start(false, false)
values.graphicsOutlineMode = "1"
setting:NotifyUpdate()
assert(#writes == 0 and values.graphicsOutlineMode == "1", "Never reset an already-disabled startup profile")

for _, failure in ipairs({ "false", "unchanged" }) do
    Start(true, false)
    Advance(5)
    C_CVar.SetCVar = function(name, value)
        if name == "graphicsOutlineMode" and value == "2" then
            if failure == "false" then return false end
            return -- A nonthrowing write can still leave the old value behind.
        end
        setCVar(name, value)
    end
    PyresinQoLDB.questItemSparkles = false
    setting:NotifyUpdate()
    setting:NotifyUpdate()
    assert(#reportedErrors == 2 and values.graphicsOutlineMode == "0" and not module.questSparklesRestartPending,
        "Nonthrowing failed resets must remain visible and retryable")
    C_CVar.SetCVar = setCVar
    combat = true
    setting:NotifyUpdate()
    assert(frame.events.PLAYER_REGEN_ENABLED and #writes == 9, "Retry must still respect combat")
    combat = false
    Send("PLAYER_REGEN_ENABLED")
    Expect(false)
    assert(#writes == 10 and module.questSparklesRestartPending)
end

Start(true, false)
Advance(5)
C_CVar.SetCVar = function(name, value)
    if name == "graphicsOutlineMode" and value == "2" then error("simulated-reset-failure") end
    setCVar(name, value)
end
PyresinQoLDB.questItemSparkles = false
local errorHandler = geterrorhandler
function geterrorhandler() return function(message) error(message) end end
local ok, reason = pcall(setting.NotifyUpdate, setting)
assert(not ok and reason:find("graphicsOutlineMode", 1, true), "Custom error handlers may propagate the failure")
geterrorhandler = errorHandler
C_CVar.SetCVar = setCVar
PyresinQoLDB.questItemSparkles = true
setting:NotifyUpdate()
Expect(true)
assert(not module.questSparklesRestartPending and ActiveTimers() == 0,
    "Reporting errors must not leave self-event suppression or a stale off transition behind")
PyresinQoLDB.questItemSparkles = false
setting:NotifyUpdate()
Expect(false)

Start(false, false)
local attempts = 0
C_CVar.SetCVar = function(name, value)
    if name == "graphicsOutlineMode" then
        attempts = attempts + 1
        error("simulated-cvar-write-failure")
    end
    setCVar(name, value)
end
PyresinQoLDB.questItemSparkles = true
module.UpdateQuestSparkles()
assert(attempts == 1 and #writes == 4 and ActiveTimers() == 0,
    "A rejected write must not abort remaining writes or leave self-event suppression stuck")
assert(#reportedErrors == 1 and reportedErrors[1]:find("simulated-cvar-write-failure", 1, true),
    "Enabling errors must be reported too")
Send("CVAR_UPDATE", "graphicsQuality")
Advance(1)
assert(attempts == 2 and ActiveTimers() == 0 and #reportedErrors == 2,
    "Repeated failure must remain visible without causing a timer loop")
C_CVar.SetCVar = setCVar
Send("CVAR_UPDATE", "graphicsOutlineMode")
assert(ActiveTimers() == 1, "Events must still work after a write failure")
Advance(1)
Expect(true)
assert(#writes == 5 and ActiveTimers() == 0)
assert(#invalidWrites == 0, "Caught write errors must not hide invalid CVar attempts")
print("PASS: quest sparkles login, presets, timers, combat, profiles, unavailable CVars, visible errors and reset retries")
