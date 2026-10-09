-- Run from the addon directory: luajit tests/integration/flighttimer/flighttimer.lua
local frames, fontStrings, hooks, callbacks = {}, {}, {}, {}
local now, onTaxi, ticker = 1000, false, nil
local ns = { customEditModeDisplays = {}, L = { flightTimer = "Flight Timer" } }
local module = {}
local rank = 0

local function Object(template)
    local object = { template = template, shown = true, alpha = 1 }
    function object:SetAlpha(value) self.alpha = value end
    function object:GetAlpha() return self.alpha end
    function object:GetStringWidth() return 40 end
    return setmetatable(object, { __index = function(_, key)
        if key:match("^Create") then return function() return Object() end end
        return function() end
    end })
end
local function Frame(template)
    local frame = Object(template)
    frame.scripts, frame.events, frame.isDragging = {}, {}, false
    function frame:SetShown(value)
        local wasShown = self.shown
        self.shown = value
        if wasShown and not value and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:Show() self:SetShown(true) end
    function frame:Hide() self:SetShown(false) end
    function frame:IsShown() return self.shown end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:ClearAllPoints() self.point = nil end
    function frame:GetFrameLevel() return 1 end
    function frame:GetCenter() return self.x, self.y end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:ShowHighlighted() self.highlighted = true; self:Show() end
    function frame:ShowSelected() self.highlighted = false; self:Show() end
    function frame:SetSystem(system) self.system = system end
    function frame:CreateFontString(_, _, fontTemplate)
        local text = Object(fontTemplate)
        function text:SetText(value) self.text = value end
        function text:SetWidth(value) self.width = value end
        function text:SetShown(value) self.shown = value end
        function text:IsShown() return self.shown end
        fontStrings[#fontStrings + 1] = text
        return text
    end
    return frame
end
function CreateFrame(_, name, _, template)
    local frame = Frame(template)
    frame.name = name
    if template == "EditModeSettingCheckboxTemplate" then
        frame.Label, frame.Button = frame:CreateFontString(), Object()
        function frame.Button:SetEnabled(value) self.enabled = value end
    end
    if name then _G[name] = frame end -- named frames are globals, as in WoW
    frame:Hide()
    frame.shown = true -- WoW frames start shown; the module hides what it must
    frames[#frames + 1] = frame
    return frame
end
NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
function UnitClass() return "Mage", "MAGE" end
function UnitName() return "Pyresin" end
function SetPortraitTexture() end
-- Settings.lua registers every option; setting one saves it and restyles.
local function Setting(key)
    return { SetValue = function(_, value) PyresinQoLDB[key] = value; module.UpdateFlightTimerStyle() end }
end
EditModeManagerFrame = { ClearSelectedSystem = function() end, IsSnapEnabled = function() return false end }
EditModeSystemSettingsDialog = Object()
MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }
UIParent = { GetCenter = function() return 960, 540 end }
EventRegistry = { RegisterCallback = function(_, event, callback) callbacks[event] = callback end }
local combat = false
function InCombatLockdown() return combat end
function GetTime() return now end
function UnitOnTaxi() return onTaxi end
function UnitFactionGroup() return "Alliance" end
Enum = { StatusBarInterpolation = { Immediate = 0 }, StatusBarTimerDirection = { ElapsedTime = 0 } }
C_DurationUtil = { CreateDuration = function() return Object() end }
local timers = {}
C_Timer = { After = function(seconds, callback) timers[#timers + 1] = { at = now + seconds, callback = callback } end,
    NewTicker = function(_, callback)
    local t = { callback = callback }
    function t:Cancel() self.cancelled = true end
    ticker = t
    return t
end }
C_Traits = {
    GetConfigIDByTreeID = function() return 1 end,
    GetNodeInfo = function() return { activeRank = rank } end,
}
function hooksecurefunc(name, callback) hooks[name] = callback end
function TakeTaxiNode(slot) hooks.TakeTaxiNode(slot) end
function TaxiRequestEarlyLanding() hooks.TaxiRequestEarlyLanding() end
-- Slots 1 (start), 2 and 3 are nodes 10, 20, 30; the flight goes 1 -> 2 -> 3.
function GetNumRoutes() return 2 end
function TaxiGetNodeSlot(_, hop, source) return source and hop or hop + 1 end
function TaxiNodeName(slot) return ({ "Start, North", "Middle, Centre", "End, South" })[slot] end
function GetTaxiMapID() return 1 end
C_TaxiMap = { GetAllTaxiNodes = function()
    return { { slotIndex = 1, nodeID = 10 }, { slotIndex = 2, nodeID = 20 }, { slotIndex = 3, nodeID = 30 } }
end, GetTaxiNodesForMap = function(mapID)
    assert(mapID == 1415, "The Alliance preview flies in the Eastern Kingdoms")
    return { { nodeID = 6, name = "Eisenschmiede" }, { nodeID = 5, name = "Seenhain" } }
end }

assert(loadfile("Modules/EditMode/CustomDisplay.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/Data.lua"))("PyresinQoL", ns)
-- 3040 yards per hop: 100 s each at the default 30.4 yards/s.
ns.flightTimerRoutes[10 * 10000 + 20] = 3040
ns.flightTimerRoutes[20 * 10000 + 30] = 3040
function ns.GetModule(id) return id == "flightTimer" and module or {} end
function ns.RegisterModule(id, initialize) assert(id == "flightTimer"); initialize(module) end
assert(loadfile("Modules/FlightTimer/Options.lua"))("PyresinQoL", ns)
for _, option in ipairs(module.flightTimerOptions) do option.setting = Setting(option.key) end
PyresinQoLDB = {}
assert(loadfile("Modules/FlightTimer/Bar.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/FlightTimer.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/EditMode.lua"))("PyresinQoL", ns)

local display, mover = frames[1], nil
for _, frame in ipairs(frames) do if frame.template == "EditModeSystemSelectionTemplate" then mover = frame end end
assert(display.name == "PyresinQoLFlightTimer" and not display.shown)
assert(mover.system.GetSystemName() == "PyresinQoL · Flight Timer" and not mover.shown)
assert(ns.customEditModeDisplays[1] == display.customEditModeEntry and display.customEditModeEntry.frame == display)
display.scripts.OnEvent(display, "PLAYER_LOGIN")
assert(display.point[1] == "CENTER" and display.point[4] == 0 and display.point[5] == 250)

local timeText
for _, text in ipairs(fontStrings) do if text.template == "GameFontHighlight" then timeText = text end end
local function Event(event) display.scripts.OnEvent(display, event) end
local function Tick() assert(ticker and not ticker.cancelled); ticker.callback() end
local function Takeoff()
    onTaxi = false
    TakeTaxiNode(3)
    Event("PLAYER_CONTROL_LOST")
    onTaxi = true
end
local function Land(after)
    now = now + after
    onTaxi = false
    Event("PLAYER_CONTROL_GAINED")
end
local function Approx(actual, expected) assert(math.abs(actual - expected) < 1e-6, actual .. " ~= " .. expected) end

-- Route sum across both hops, ETA and countdown.
Takeoff()
assert(display.shown and timeText.text == "3:20", timeText.text)
-- The stop between the hops dims as it crosses the spark: halfway, 100 s in, in both modes.
assert(#timers > 0 and timers[#timers].at == now + 100)
-- Where the marker meets an end name, the name fades by default, the marker with the other options.
local over, departure
for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then over = frame end end
for _, text in ipairs(fontStrings) do if text.template == "GameFontHighlightSmall" then departure = departure or text end end
over.scripts.OnUpdate(over, 1)
assert(departure.alpha == 0.3)
-- Names keep their zone by default; one switch drops it everywhere.
local stopLabel
for _, text in ipairs(fontStrings) do if text.text == "Middle, Centre" then stopLabel = text end end
assert(departure.text == "Start, North" and stopLabel)
Setting("flightTimerZones"):SetValue(false)
assert(departure.text == "Start" and stopLabel.text == "Middle")
PyresinQoLDB.flightTimerZones = nil
-- A name wider than its room (40 > 50 * 0.42) scrolls whole, or with scrolling off ends in an
-- ellipsis at the room's width.
Setting("flightTimerWidth"):SetValue(50)
assert(departure.width == 0)
Setting("flightTimerScrollNames"):SetValue(false)
assert(departure.width == 21, departure.width)
PyresinQoLDB.flightTimerScrollNames = nil
-- The width reads what it measures on screen, at the timer's scale.
local widthOption = module.flightTimerOptions[#module.flightTimerOptions - 1]
assert(widthOption.key == "flightTimerWidth" and module.FormatFlightTimerOption(widthOption, 300) == "300 px")
PyresinQoLDB.flightTimerScale = 50
assert(module.FormatFlightTimerOption(widthOption, 300) == "150 px")
PyresinQoLDB.flightTimerScale = nil
Setting("flightTimerWidth"):SetValue(300)
now = now + 100 -- the marker in the middle, clear of both ends
over.scripts.OnUpdate(over, 1)
assert(departure.alpha == 1)
now = now - 100
now = now + 50
Tick()
assert(timeText.text == "2:30", timeText.text)
Setting("flightTimerTime"):SetValue("total")
assert(timeText.text == "2:30 / 3:20", "The total shows at once, not on the next tick")
PyresinQoLDB.flightTimerTime = nil

-- A normal landing learns a quarter of the way toward the measured speed.
Land(140) -- 6080 yards in 190 s = 32 yards/s
assert(not display.shown and ticker.cancelled)
Approx(PyresinQoLFlightSpeed, 30.4 + 1.6 / 4)
-- An outlier more than a third off is ignored.
local learned = PyresinQoLFlightSpeed
Takeoff()
Land(50)
assert(PyresinQoLFlightSpeed == learned)
-- So is an early landing, which also retargets the route to the next stop.
Takeoff()
now = now + 50
Tick()
TaxiRequestEarlyLanding()
-- Halfway at 98.7 s, 50 s in: 0:49 left.
assert(timeText.text == "0:49", timeText.text)
Land(50)
assert(PyresinQoLFlightSpeed == learned and not display.shown)

-- A pending click older than five seconds must not start a flight.
TakeTaxiNode(3)
now = now + 6
Event("PLAYER_CONTROL_LOST")
assert(not display.shown)

-- A landing edge that was missed ends the flight on the next tick, without learning.
Takeoff()
now = now + 3
onTaxi = false
Tick()
assert(not display.shown and PyresinQoLFlightSpeed == learned)

-- Frequent Flier: 20% faster, and the stored speed excludes it.
PyresinQoLFlightSpeed = nil
rank = 1
Takeoff()
assert(timeText.text == "2:47", timeText.text) -- 6080 / (30.4 * 1.2) = 166.7 s
Land(150) -- 6080 / 150 / 1.2 = 33.78 yards/s
Approx(PyresinQoLFlightSpeed, 30.4 + (6080 / 150 / 1.2 - 30.4) / 4)
rank = 0
-- Without the node info at all, no perk is assumed.
C_Traits.GetConfigIDByTreeID = function() return nil end
PyresinQoLFlightSpeed = nil
Takeoff()
assert(timeText.text == "3:20", timeText.text)
Land(200)

-- A hop missing from the route data shows nothing and learns nothing.
PyresinQoLFlightSpeed = nil
local removed = ns.flightTimerRoutes[20 * 10000 + 30]
ns.flightTimerRoutes[20 * 10000 + 30] = nil
Takeoff()
assert(not display.shown and PyresinQoLFlight == nil)
Land(65)
assert(PyresinQoLFlightSpeed == nil, "Nothing is learned without a route length")
ns.flightTimerRoutes[20 * 10000 + 30] = removed

-- Edit Mode runs the preview, restarts it, and ends it on exit.
callbacks["EditMode.Enter"]()
assert(display.shown and mover.shown and mover.highlighted and timeText.text == "0:20", timeText.text)
local hides = 0
mover.scripts.OnHide = function() hides = hides + 1 end -- hiding the mover would close the options
now = now + 20
Tick()
assert(display.shown and timeText.text == "0:20", "The preview restarts when it finishes")
assert(hides == 0, "A restarting preview keeps the timer, its mover and its options shown")
mover.scripts.OnHide = nil
combat = true
mover.scripts.OnEvent(mover, "PLAYER_REGEN_DISABLED")
assert(not mover.shown)
combat = false
mover.scripts.OnEvent(mover, "PLAYER_REGEN_ENABLED")
assert(mover.shown)
mover.scripts.OnDragStart()
assert(display.moving)
display.x, display.y = 1000, 700
mover.scripts.OnDragStop()
assert(PyresinQoLDB.flightTimerPosition.x == 40 and PyresinQoLDB.flightTimerPosition.y == 160)
-- Selecting it opens its options; they write the saved variables and restyle at once.
mover.scripts.OnMouseDown(mover)
local checkboxes = {}
for _, frame in ipairs(frames) do
    if frame.template == "EditModeSettingCheckboxTemplate" then checkboxes[#checkboxes + 1] = frame end
end
local zones, scrollNames, stopArrows, showPost = unpack(checkboxes)
assert(zones and scrollNames and stopArrows.Button.enabled and showPost.Button.enabled)
zones.OnCheckButtonClick()
assert(PyresinQoLDB.flightTimerZones == false)
zones.OnCheckButtonClick()
-- Stops off greys out their own options; the centre line only runs with scrolling stops.
local stops = module.flightTimerOptions[8]
assert(stops.key == "flightTimerStops")
stops.setting:SetValue("off")
display.Dialog:Refresh()
assert(stopArrows.Button.enabled == false and showPost.Button.enabled == false)
stops.setting:SetValue("fixed")
display.Dialog:Refresh()
assert(stopArrows.Button.enabled and showPost.Button.enabled == false)
stops.setting:SetValue("scroll")
display.Dialog:Refresh()
assert(stopArrows.Button.enabled and showPost.Button.enabled)
Setting("flightTimerTime"):SetValue("off")
assert(timeText.shown == false)
Setting("flightTimerTime"):SetValue("left")
assert(timeText.shown == true)
callbacks["EditMode.Exit"]()
assert(not display.shown and not mover.shown and ticker.cancelled)

-- A real flight is never replaced by the preview.
Takeoff()
callbacks["EditMode.Enter"]()
assert(timeText.text == "3:20", timeText.text)
callbacks["EditMode.Exit"]()
assert(display.shown and timeText.text == "3:20")
Land(190)
assert(PyresinQoLFlight == nil, "A landing clears the saved flight")

-- /reload: the saved variable is copied, the module rebuilt and PLAYER_ENTERING_WORLD fires.
local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = Copy(inner) end
    return copy
end
local function Reload(isInitialLogin, isReloadingUi)
    PyresinQoLFlight = Copy(PyresinQoLFlight)
    ticker = nil
    ns.customEditModeDisplays = {}
    assert(loadfile("Modules/FlightTimer/Bar.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/FlightTimer.lua"))("PyresinQoL", ns)
    assert(loadfile("Modules/FlightTimer/EditMode.lua"))("PyresinQoL", ns)
    for _, frame in ipairs(frames) do if frame.name == "PyresinQoLFlightTimer" then display = frame end end
    for _, text in ipairs(fontStrings) do if text.template == "GameFontHighlight" then timeText = text end end
    display.scripts.OnEvent(display, "PLAYER_LOGIN")
    display.scripts.OnEvent(display, "PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)
end
-- A reload mid-flight resumes on the same clock, and the landing still learns.
Takeoff()
now = now + 50
Tick()
local before = timeText.text
Reload(false, true)
assert(display.shown and timeText.text == before, timeText.text .. " ~= " .. before)
Land(150) -- 6080 yards in 200 s
Approx(PyresinQoLFlightSpeed, learned + (30.4 - learned) / 4)
assert(PyresinQoLFlight == nil)
-- An early landing request survives a reload too.
Takeoff()
now = now + 50
TaxiRequestEarlyLanding()
before = timeText.text
Reload(false, true)
assert(display.shown and timeText.text == before, timeText.text .. " ~= " .. before)
Land(50)
-- A relog drops the flight; so does a reload after the flight ended unseen.
Takeoff()
Reload(true, false)
assert(not display.shown and PyresinQoLFlight == nil)
Takeoff()
onTaxi = false
Reload(false, true)
assert(not display.shown and PyresinQoLFlight == nil)
-- A saved start after the current clock means the client restarted: dropped.
onTaxi = true
Takeoff()
PyresinQoLFlight.start = now + 1000
Reload(false, true)
assert(not display.shown and PyresinQoLFlight == nil)
-- A reload during the Edit Mode preview leaves nothing to resume.
onTaxi = false
callbacks["EditMode.Enter"]()
Reload(false, true)
assert(not display.shown and PyresinQoLFlight == nil)
-- A zone change mid-flight keeps the saved flight; previews are never saved.
onTaxi = true
Takeoff()
Event("PLAYER_ENTERING_WORLD")
assert(PyresinQoLFlight and display.shown)
Land(190)
callbacks["EditMode.Enter"]()
assert(display.shown and PyresinQoLFlight == nil)
callbacks["EditMode.Exit"]()
print("PASS: flight timer routes, ETA, speed learning, early landing, Frequent Flier, Edit Mode preview and options, /reload recovery")
