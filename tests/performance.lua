-- Run from the addon directory: lua tests/performance.lua
local frames, callbacks = {}, {}
local toggles, dragStarts = 0, 0
local editMode = {
    TogglePixelPerfectFrame = function() toggles = toggles + 1 end,
    OnPixelPerfectDragStart = function() dragStarts = dragStarts + 1 end,
    ClearPixelPerfectFrame = function() end,
}
local ns, module = {}, {}
function ns.GetModule(id) assert(id == "editMode"); return editMode end
EditModeManagerFrame = { ClearSelectedSystem = function() end }
local combat, fps, home, world = false, 119.94, 23, 41
local reads = 0
UIParent = { GetCenter = function() return 960, 540 end }
function InCombatLockdown() return combat end
function GetFramerate() return fps end
function GetNetStats() reads = reads + 1; return 0, 0, home, world end
EventRegistry = {
    RegisterCallback = function(_, event, callback) callbacks[event] = callback end,
}

function CreateFrame(_, name, parent, template)
    local frame = { name = name, parent = parent, template = template, scripts = {}, events = {}, texts = {}, shown = true }
    frames[#frames + 1] = frame
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetMovable(value) self.movable = value end
    function frame:SetClampedToScreen(value) self.clamped = value end
    function frame:EnableMouse(value) self.mouse = value end
    function frame:SetShown(value)
        local wasShown = self.shown
        self.shown = value
        if wasShown and not value and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:Show() self:SetShown(true) end
    function frame:Hide() self:SetShown(false) end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetPoint(...)
        assert(not self.point, "Clear old anchors before positioning the display")
        self.point = { ... }
    end
    function frame:SetAllPoints(target) self.allPoints = target end
    function frame:ClearAllPoints() self.point = nil end
    function frame:GetCenter() return self.x, self.y end
    function frame:StartMoving() assert(self.movable); self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:SetBackdrop() end
    function frame:SetFrameStrata(value) self.strata = value end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:RegisterForDrag(button) assert(button == "LeftButton") end
    function frame:SetSystem(system) self.system = system end
    function frame:ShowHighlighted() self.highlighted = true; self.selected = false; self:Show() end
    function frame:ShowSelected() self.highlighted = false; self.selected = true; self:Show() end
    function frame:IsShown() return self.shown end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint(...) self.point = { ... } end
        function text:ClearAllPoints() self.point = nil end
        function text:SetShown(value) self.shown = value end
        function text:SetTextColor(r, g, b) self.color = { r, g, b } end
        function text:SetText(value) self.text = value end
        function text:SetFormattedText(format, value) self.text = string.format(format, value) end
        self.texts[#self.texts + 1] = text
        return text
    end
    return frame
end
function CreateColorFromHexString(hex)
    assert(#hex == 8)
    return {
        GetRGB = function()
            return tonumber(hex:sub(3, 4), 16) / 255,
                tonumber(hex:sub(5, 6), 16) / 255,
                tonumber(hex:sub(7, 8), 16) / 255
        end,
    }
end

ns.RegisterModule = function(id, initialize) assert(id == "performance"); initialize(module) end
assert(loadfile("Modules/Performance/Performance.lua"))("PyresinQoL", ns)
local display, mover = frames[1], frames[2]
assert(not display.shown and not mover.shown and not display.mouse)
assert(mover.template == "EditModeSystemSelectionTemplate" and mover.allPoints == display)
assert(mover.system.GetSystemName() == "PyresinQoL · FPS / MS")
display:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
display.scripts.OnEvent(display, "PLAYER_LOGIN")
assert(display.shown and display.clamped and display.point[1] == "BOTTOMRIGHT")
assert(display.width == 85 and display.height == 35)
assert(display.texts[1].point[5] == 0 and display.texts[3].point[5] == -20)
assert(display.texts[1].text == "FPS:" and display.texts[3].text == "MS:")
assert(display.texts[2].text == "119.9" and display.texts[4].text == "41")
fps, home, world = 59.96, 75, 12
display.scripts.OnUpdate(display, 0.1)
assert(reads == 1, "Do not poll every frame")
display.scripts.OnUpdate(display, 0.15)
assert(reads == 2 and display.texts[2].text == "60.0" and display.texts[4].text == "75")

mover.scripts.OnDragStart()
assert(not display.moving, "Only EditMode may move the display")
callbacks["EditMode.Enter"]()
assert(mover.shown and mover.highlighted)
mover.scripts.OnMouseDown(mover)
assert(mover.selected)
assert(toggles == 1)
mover.scripts.OnDragStart()
assert(display.moving)
assert(dragStarts == 1)
display.x, display.y = 1250, 220
mover.scripts.OnDragStop()
assert(not display.moving)
assert(PyresinQoLDB.performancePosition.x == 290 and PyresinQoLDB.performancePosition.y == -320)
assert(display.point[1] == "CENTER" and display.point[4] == 290)

mover.scripts.OnDragStart()
combat = true
display.scripts.OnEvent(display, "PLAYER_REGEN_DISABLED")
assert(not mover.shown and not display.moving, "Entering combat must end a drag")
mover.scripts.OnDragStart()
assert(not display.moving)
combat = false
display.scripts.OnEvent(display, "PLAYER_REGEN_ENABLED")
assert(mover.shown)
mover.scripts.OnDragStart()
callbacks["EditMode.Exit"]()
assert(not mover.shown and not display.moving and display.shown)
display.scripts.OnEvent(display, "PLAYER_REGEN_ENABLED")
assert(not mover.shown, "Combat exit must not enable dragging outside EditMode")

-- A new UI session must restore the persisted position.
PyresinQoLDB.showFPS = false
PyresinQoLDB.showLatency = false
module.UpdatePerformanceVisibility()
assert(not display.shown and not mover.shown)
callbacks["EditMode.Enter"]()
assert(not display.shown and not mover.shown, "EditMode must respect the disabled feature")
mover.scripts.OnDragStart()
assert(not display.moving)
PyresinQoLDB.showFPS = true
module.UpdatePerformanceLayout()
assert(display.shown and mover.shown, "Enabling while editing must restore the mover")
assert(display.width == 85 and display.height == 15 and not display.texts[3].shown)
mover.scripts.OnDragStart()
PyresinQoLDB.showFPS = false
module.UpdatePerformanceLayout()
assert(not display.shown and not mover.shown and not display.moving, "Disabling must stop an active drag")
PyresinQoLDB.showFPS, PyresinQoLDB.showLatency = true, true
PyresinQoLDB.performanceLayout = "row"
PyresinQoLDB.performanceOrder = "latency"
PyresinQoLDB.performanceColor = "FFFF0000"
PyresinQoLDB.performanceRowPadding = 24
module.UpdatePerformanceLayout()
assert(display.width == 194 and display.height == 15)
assert(display.texts[3].point[4] == 0 and display.texts[1].point[4] == 109)
assert(display.texts[1].color[1] == 1 and display.texts[1].color[2] == 0)
PyresinQoLDB.performanceLayout = "column"
PyresinQoLDB.performanceColumnPadding = 9
module.UpdatePerformanceLayout()
assert(display.width == 85 and display.height == 39)
assert(display.texts[3].point[5] == 0 and display.texts[1].point[5] == -24)
PyresinQoLDB.performanceLayout = "row"
frames = {}
assert(loadfile("Modules/Performance/Performance.lua"))("PyresinQoL", ns)
display = frames[1]
display:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
display.scripts.OnEvent(display, "PLAYER_LOGIN")
assert(display.point[1] == "CENTER" and display.point[4] == 290 and display.point[5] == -320)
assert(display.shown and display.width == 194 and display.height == 15)
PyresinQoLDB.showFPS, PyresinQoLDB.showLatency = false, false
module.UpdatePerformanceLayout()
assert(not display.shown and not frames[2].shown)
-- FPS/latency must remain movable when the Edit Mode extension is disabled.
editMode.TogglePixelPerfectFrame, editMode.OnPixelPerfectDragStart, editMode.ClearPixelPerfectFrame = nil, nil, nil
PyresinQoLDB.showFPS = true
module.UpdatePerformanceLayout()
callbacks["EditMode.Enter"]()
local standaloneMover = frames[2]
standaloneMover.scripts.OnMouseDown(standaloneMover)
standaloneMover.scripts.OnDragStart()
assert(display.moving)
display.x, display.y = 980, 560
standaloneMover.scripts.OnDragStop()
assert(not display.moving and PyresinQoLDB.performancePosition.x == 20)
callbacks["EditMode.Exit"]()
assert(not standaloneMover.shown)
print("PASS: FPS/latency, polling, EditMode, combat, live toggles and persisted state/position")
