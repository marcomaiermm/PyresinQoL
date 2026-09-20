-- Run from the addon directory: lua tests/pixelperfect.lua
local frames, callbacks = {}, {}
local combat, locked = false, false
local physicalHeight = 1080
local snapEnabled, magneticInfos, magneticQueries = true, nil, 0
local ns, module, performance = {}, {}, {}
function ns.GetModule(id) assert(id == "performance"); return performance end
function GetLocale() return "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
PyresinQoLDB = {}
UIParent = { GetCenter = function() return 960, 540 end, GetEffectiveScale = function() return 0.8 end }
function UIParent:IsShown() return true end
function UIParent:GetRect() return 0, 0, 1920, 1080 end
PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / physicalHeight end }
function InCombatLockdown() return combat end
Enum = { EditModeCastBarSetting = { LockToPlayerFrame = 1 } }
EventRegistry = { RegisterCallback = function(_, event, callback) callbacks[event] = callback end }
function hooksecurefunc(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...) original(self, ...); callback(self, ...) end
end
EditModeManagerFrame = {
    registeredSystemFrames = {},
    IsShown = function() return false end,
    IsEditModeLocked = function() return locked end,
    IsSnapEnabled = function() return snapEnabled end,
    SelectSystem = function(_, frame) frame.isSelected = not locked end,
    ClearSelectedSystem = function() end,
    OnSystemSettingChange = function(_, frame, setting, value)
        assert(frame == PlayerCastingBarFrame and setting == 1 and value == 0)
        frame.unlocked = true
    end,
}
EditModeMagnetismManager = {
    magnetismRange = 8,
    GetMagneticFrameInfos = function(_, frame)
        assert(frame ~= performance.performanceDisplay, "Custom display must not enter Blizzard's system API")
        magneticQueries = magneticQueries + 1
        return magneticInfos
    end,
    ApplyMagnetism = function(_, frame)
        local target = magneticInfos and magneticInfos[1].frame
        frame.snappedToFrame = target ~= UIParent and target or nil
    end,
}
local function Text()
    return {
        SetPoint = function() end, SetWidth = function() end,
        SetText = function(self, value) self.text = value end,
        SetFormattedText = function(self, format, ...) self.text = format:format(...) end,
    }
end
function CreateFrame(kind, name, parent)
    local frame = { scripts = {}, texts = {}, shown = true, x = 1200, y = 700, scale = 0.8, width = 200, height = 50 }
    frames[#frames + 1] = frame
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetSize() return self.width, self.height end
    function frame:GetRect() return self.x - self.width / 2, self.y - self.height / 2, self.width, self.height end
    function frame:SetFrameStrata() end
    function frame:SetClampedToScreen() end
    function frame:EnableMouse() end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:Show() self.shown = true end
    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:IsShown() return self.shown end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text end
    function frame:SetAutoFocus(value) self.autoFocus = value end
    function frame:SetMaxLetters(value) self.maxLetters = value end
    function frame:SetJustifyH() end
    function frame:SetTextColor(...) self.color = { ... } end
    function frame:HighlightText() end
    function frame:HasFocus() return self.focused end
    function frame:SetFocus()
        for _, other in ipairs(frames) do if other ~= self then other:ClearFocus() end end
        self.focused = true
    end
    function frame:ClearFocus()
        local wasFocused = self.focused
        self.focused = false
        if wasFocused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
    function frame:SetEnabled(enabled) self.enabled = enabled end
    function frame:SetDefaultText(text) self.defaultText = text end
    function frame:SetupMenu(generator) self.generator = generator end
    function frame:GenerateMenu()
        self.generations = (self.generations or 0) + 1
        self.options = {}
        local root = { SetScrollMode = function() end }
        function root:CreateRadio(name, isSelected, select)
            frame.options[#frame.options + 1] = { name = name, isSelected = isSelected, select = select }
        end
        self.generator(self, root)
    end
    function frame:RegisterEvent() end
    function frame:OnDragStart() self.isDragging = true end
    function frame:GetCenter() return self.x, self.y end
    function frame:GetEffectiveScale() return self.scale end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        assert(not self.point, "Clear anchors before repositioning")
        self.point = { point, relativeTo, relativePoint, x, y }
        if point == "CENTER" then self.x, self.y = 960 + x, 540 + y end
    end
    function frame:ClearAllPoints() self.point = nil end
    function frame:CreateFontString()
        local text = Text()
        self.texts[#self.texts + 1] = text
        return text
    end
    function frame:SetNormalTexture() end
    function frame:SetPushedTexture() end
    function frame:SetHighlightTexture() end
    function frame:GetNormalTexture() return { SetRotation = function() end } end
    frame.GetPushedTexture = frame.GetNormalTexture
    return frame
end
local function Approx(actual, expected) assert(math.abs(actual - expected) < 1e-8, actual .. " ~= " .. expected) end
local display = CreateFrame()
display.Selection = { IsShown = function() return display.shown end, ShowHighlighted = function() display.highlighted = true end }
function display.Selection:GetRect() return display:GetRect() end
function display.Selection:GetEffectiveScale() return display:GetEffectiveScale() end
performance.performanceDisplay = display
function performance.SavePerformancePosition()
    PyresinQoLDB.performancePosition = { x = display.x - 960, y = display.y - 540 }
end
ns.RegisterModule = function(id, initialize) assert(id == "editMode"); initialize(module) end
assert(loadfile("Modules/EditMode/PixelPerfect.lua"))("PyresinQoL", ns)
local panel = frames[2]
local left, up, down, right = frames[3], frames[4], frames[5], frames[6]
local xInput, yInput = frames[11], frames[12]
local function Click(button) button.scripts.OnClick() end
module.SelectPixelPerfectFrame(display)
assert(not panel.shown)
callbacks["EditMode.Enter"]()
module.UpdatePixelPerfectMode()
assert(not panel.shown, "Disabled by default")
PyresinQoLDB.pixelPerfectEditMode = true
module.UpdatePixelPerfectMode()
assert(panel.shown and panel.texts[1].text == "PyresinQoL · FPS / MS")
assert(xInput.text == "270.00" and yInput.text == "180.00")
local x, y = display.x, display.y
Click(right)
Approx((display.x - x) * display.scale / PixelUtil.GetPixelToUIUnitFactor(), 1)
Approx(PyresinQoLDB.performancePosition.x, display.x - 960)
assert(xInput.text == "271.00" and yInput.text == "180.00")
Click(left); Click(up); Click(down)
Approx(display.x, x); Approx(display.y, y)
display.x = display.x + 8
panel.scripts.OnUpdate()
assert(xInput.text == "279.00" and yInput.text == "180.00", "Track drag position live")
display.isDragging = true
x = display.x
Click(right)
Approx(display.x, x)
display.isDragging = false

local native = CreateFrame()
native.isManagedFrame, native.default, native.changed = true, true, 0
function native:GetSystemName() return "Action Bar 1" end
function native:CanBeMoved() return self.isSelected and not self.isLocked end
function native:IsInDefaultPosition() return self.default end
function native:BreakFromFrameManager() self.detached = true end
function native:ClearFrameSnap() self.unsnapped = true end
function native:StopMovingOrSizing() self.stopped = true end
function native:BreakFrameSnap(dx, dy)
    assert(self.detached and self.unsnapped and self.stopped)
    self.x, self.y = self.x + dx, self.y + dy
    self.changed = self.changed + 1 -- Native method notifies the manager to save/revert the layout.
end
EditModeManagerFrame:SelectSystem(native)
assert(panel.shown and display.highlighted and panel.texts[1].text == "Action Bar 1")
-- Physical pixel deltas must stay correct for scaled frames and different resolutions.
for _, scale in ipairs({ 0.6, 0.8, 1.2 }) do
    for _, height in ipairs({ 1080, 1440, 2160 }) do
        native.scale, physicalHeight = scale, height
        x, y = native.x, native.y
        Click(right); Click(up)
        Approx((native.x - x) * scale / (768 / height), 1)
        Approx((native.y - y) * scale / (768 / height), 1)
        Click(left); Click(down)
        Approx(native.x, x); Approx(native.y, y)
    end
end
assert(native.changed == 36)
-- Regression: a bottom-edge action bar must place the panel above, never clamp onto the bar.
local function CheckPlacement()
    panel.scripts.OnUpdate()
    assert(panel.point[1] == "BOTTOMLEFT" and panel.point[2] == UIParent)
    local px, py = panel.point[4], panel.point[5]
    assert(px >= 0 and py >= 0 and px + panel.width <= 1920 and py + panel.height <= 1080)
    local target = native.Selection or native
    local tx, ty, tw, th = target:GetRect()
    local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
    tx, ty, tw, th = tx * scale, ty * scale, tw * scale, th * scale
    assert(px + panel.width <= tx - 12 or px >= tx + tw + 12
        or py + panel.height <= ty - 12 or py >= ty + th + 12, "Panel overlaps selected frame")
    return px, py
end
native.scale = 0.8
native.x, native.y = 1400, 25
local px, py = CheckPlacement()
assert(py >= 50 + 12)
native.y = 1055
px, py = CheckPlacement()
assert(py + panel.height <= 1030 - 12)
for _, position in ipairs({ { 100, 25 }, { 1820, 25 }, { 100, 1055 }, { 1820, 1055 } }) do
    native.x, native.y = position[1], position[2]
    CheckPlacement()
end
-- A tall selection uses a side; scaled selection bounds can exceed the underlying frame.
native.Selection = CreateFrame()
native.Selection.x, native.Selection.y = 700, 360
native.Selection.scale = 1.2
native.Selection.width, native.Selection.height = 100, 700
px, py = CheckPlacement()
Approx(px, (700 + 50) * 1.5 + 12)
native.Selection = nil
native.x, native.y = 1000, 500
px, py = CheckPlacement()
EditModeSystemSettingsDialog = CreateFrame()
EditModeSystemSettingsDialog:SetSize(panel.width, panel.height)
EditModeSystemSettingsDialog.x = px + panel.width / 2
EditModeSystemSettingsDialog.y = py + panel.height / 2
local newX, newY = CheckPlacement()
assert(newY >= native.y + native.height / 2 + 12, "Avoid the Blizzard settings dialog")
EditModeSystemSettingsDialog:Hide()
-- Position updates happen immediately after a nudge, not only on the next rendered frame.
Click(right)
assert(panel.point[4] ~= newX or panel.point[5] ~= newY)
PlayerCastingBarFrame = native
Click(right)
assert(native.unlocked, "The player cast bar must detach from the player frame")
local changed = native.changed
native.isLocked = true
Click(right); module.UpdatePixelPerfectMode()
assert(native.changed == changed and not panel.shown)
native.isLocked = false
combat = true
panel.scripts.OnEvent()
Click(right)
assert(not panel.shown and native.changed == changed)
combat = false
panel.scripts.OnEvent()
assert(panel.shown)
locked = true
Click(right); module.UpdatePixelPerfectMode()
assert(not panel.shown and native.changed == changed)
locked = false
PyresinQoLDB.pixelPerfectEditMode = false
module.UpdatePixelPerfectMode(); Click(right)
assert(not panel.shown and native.changed == changed)
PyresinQoLDB.pixelPerfectEditMode = true
module.UpdatePixelPerfectMode()
assert(panel.shown)
module.ClearPixelPerfectFrame(display)
assert(panel.shown, "Hiding the FPS display must not clear a selected Blizzard frame")
EditModeManagerFrame:ClearSelectedSystem()
assert(not panel.shown and not panel.point)
EditModeManagerFrame:SelectSystem(native)
callbacks["EditMode.Exit"]()
Click(right)
assert(not panel.shown and native.changed == changed)
callbacks["EditMode.Enter"]()
module.UpdatePixelPerfectMode()
assert(not panel.shown, "Do not restore a stale selection")

local dropdown, above, below, center = frames[7], frames[8], frames[9], frames[10]
local target = CreateFrame()
function target:GetSystemName() return "Cast Bar" end
target.Selection = { IsShown = function() return target.shown end }
native.Selection = { IsShown = function() return native.shown end,
    GetRect = function() return native:GetRect() end, GetEffectiveScale = function() return native.scale end }
EditModeManagerFrame.registeredSystemFrames = { native, target }
local function SelectTarget(frame)
    dropdown:GenerateMenu()
    for _, option in ipairs(dropdown.options) do
        local name = frame == display and "PyresinQoL · FPS / MS" or frame:GetSystemName()
        if option.name == name then option.select(); assert(option.isSelected()); return end
    end
    error("Missing snap target")
end
EditModeManagerFrame:SelectSystem(native)
assert(not above.enabled, "Require a target before snapping")
assert(#dropdown.options == 2, "Exclude the selected frame and include the addon display")
SelectTarget(target)
assert(above.enabled and below.enabled and center.enabled)
for _, scale in ipairs({ 0.6, 0.8, 1.2 }) do
    native.scale, target.scale = scale, 0.9
    target.x, target.y = 700, 500
    target.width, target.height = 180, 30
    Click(above)
    Approx(native.x * native.scale, target.x * target.scale)
    Approx((native.y - native.height / 2) * native.scale, (target.y + target.height / 2) * target.scale)
    Click(below)
    Approx(native.x * native.scale, target.x * target.scale)
    Approx((native.y + native.height / 2) * native.scale, (target.y - target.height / 2) * target.scale)
    native.x, native.y = 600, 300
    Click(center)
    Approx(native.x * native.scale, target.x * target.scale)
    Approx(native.y, 300)
end
local before = native.changed
target:Hide()
module.UpdatePixelPerfectMode(); Click(above)
assert(not above.enabled and native.changed == before)
target:Show()
native.isDragging = true
Click(below)
assert(native.changed == before)
native.isDragging = false
combat = true
Click(above)
assert(native.changed == before)
combat = false
PyresinQoLDB.pixelPerfectEditMode = false
Click(center)
assert(native.changed == before)
PyresinQoLDB.pixelPerfectEditMode = true
module.SelectPixelPerfectFrame(display)
SelectTarget(target)
Click(above)
Approx(display.x * display.scale, target.x * target.scale)
Approx((display.y - display.height / 2) * display.scale, (target.y + target.height / 2) * target.scale)
Approx(PyresinQoLDB.performancePosition.x, display.x - 960)
Approx(PyresinQoLDB.performancePosition.y, display.y - 540)
-- Snapping is one-time alignment; nudging remains exactly one physical pixel afterwards.
x = display.x
Click(right)
Approx((display.x - x) * display.scale / PixelUtil.GetPixelToUIUnitFactor(), 1)

local function CurrentTargetName()
    for _, option in ipairs(dropdown.options) do
        if option.isSelected() then return option.name end
    end
end
EditModeManagerFrame:SelectSystem(native)
native.isDragging = true
magneticInfos = { { frame = target } }
local beforeX, beforeY, beforeChanges = native.x, native.y, native.changed
panel.scripts.OnUpdate()
assert(CurrentTargetName() == "Cast Bar" and not above.enabled)
local generations = dropdown.generations
panel.scripts.OnUpdate()
assert(dropdown.generations == generations, "Do not rebuild an unchanged target menu every frame")
Approx(native.x, beforeX); Approx(native.y, beforeY)
assert(native.changed == beforeChanges, "Detection must not move or save Blizzard frames")
native.isDragging = false
EditModeMagnetismManager:ApplyMagnetism(native)
magneticInfos = nil
panel.scripts.OnUpdate()
assert(CurrentTargetName() == "Cast Bar" and above.enabled, "Keep the actual Blizzard snap after release")
-- Manual overrides must survive idle updates even while the frame remains natively anchored.
SelectTarget(display)
local queries = magneticQueries
panel.scripts.OnUpdate()
assert(CurrentTargetName() == "PyresinQoL · FPS / MS" and magneticQueries == queries)
native.isDragging = true
display.x, display.y = 50, 50
magneticInfos = { { frame = UIParent } }
panel.scripts.OnUpdate()
assert(CurrentTargetName() == nil, "Grid/screen snapping is not a selectable target frame")
magneticInfos = { { frame = target } }
target:Hide()
panel.scripts.OnUpdate()
assert(CurrentTargetName() == nil, "Ignore hidden candidates")
target:Show()
snapEnabled = false
panel.scripts.OnUpdate()
assert(CurrentTargetName() == nil)
snapEnabled = true
native.isDragging = false
module.ClearPixelPerfectFrame()
-- A fast drop is detected even if the panel never rendered during the drag.
EditModeManagerFrame:SelectSystem(native)
EditModeMagnetismManager:ApplyMagnetism(native)
assert(CurrentTargetName() == "Cast Bar")
native.snappedToFrame = nil
magneticInfos = nil
module.SelectPixelPerfectFrame(display)
display.isDragging = true
native:Hide()
-- Different effective scales: place our bottom edge within Blizzard's magnetism range of the target top.
display.x = target.x * target.scale / display.scale
display.y = ((target.y + target.height / 2) * target.scale + 4) / display.scale + display.height / 2
panel.scripts.OnUpdate()
assert(CurrentTargetName() == "Cast Bar")
display.y = display.y + 100
panel.scripts.OnUpdate()
assert(CurrentTargetName() == nil, "Moving away must clear an automatic candidate")
display.y = display.y - 100
panel.scripts.OnUpdate()
display.isDragging = false
panel.scripts.OnUpdate()
assert(CurrentTargetName() == "Cast Bar" and above.enabled)
module.ClearPixelPerfectFrame()
native:Show()
native.isDragging = true
native.x = display.x * display.scale / native.scale
native.y = ((display.y + display.height / 2) * display.scale + 3) / native.scale + native.height / 2
EditModeManagerFrame:SelectSystem(native)
assert(CurrentTargetName() == "PyresinQoL · FPS / MS", "Native frames should also detect our display")
native.isDragging = false
-- Every native mover needs the same nearby-frame fallback, including when Blizzard only offers a grid line.
display.x, display.y = 50, 50
native.isDragging = true
native.x = target.x * target.scale / native.scale
native.y = ((target.y + target.height / 2) * target.scale + 3) / native.scale + native.height / 2
magneticInfos = nil
module.UpdatePixelPerfectMode()
assert(CurrentTargetName() == "Cast Bar", "Native-to-native detection must not depend on a Blizzard snap candidate")
magneticInfos = { { frame = UIParent } }
module.UpdatePixelPerfectMode()
assert(CurrentTargetName() == "Cast Bar", "Grid preview must not prevent detecting a nearby native frame")
native.isDragging = false
target.CanBeMoved = native.CanBeMoved
function target.Selection:GetRect() return target:GetRect() end
function target.Selection:GetEffectiveScale() return target.scale end
magneticInfos = nil
for _, pair in ipairs({ { native, target }, { target, native } }) do
    local mover, destination = pair[1], pair[2]
    for _, scale in ipairs({ 0.6, 1.2 }) do
        mover.scale, destination.scale = scale, 0.8
        destination.x, destination.y = 900, 500
        mover.x = destination.x * destination.scale / mover.scale
        mover.y = ((destination.y + destination.height / 2) * destination.scale + 3) / mover.scale + mover.height / 2
        mover.isDragging = true
        EditModeManagerFrame:SelectSystem(mover)
        assert(CurrentTargetName() == destination:GetSystemName(), "Every native frame must work in both directions")
        mover.isDragging = false
    end
end
-- A visible target remains eligible even if its selection overlay is disabled in EditMode.
native.Selection.IsShown = function() return false end
target.isDragging = true
module.UpdatePixelPerfectMode()
assert(CurrentTargetName() == "Action Bar 1")
native:Hide()
module.UpdatePixelPerfectMode()
assert(CurrentTargetName() == nil, "Actually hidden frames must still be excluded")
target.isDragging = false
native:Show()
native.Selection.IsShown = function() return true end
EditModeManagerFrame:SelectSystem(native)
local function Enter(input, text)
    input:SetFocus()
    input:SetText(text)
    input.scripts.OnEnterPressed(input)
end
local function Position(frame)
    local pixel = PixelUtil.GetPixelToUIUnitFactor()
    return (frame.x * frame.scale - 960 * 0.8) / pixel, (frame.y * frame.scale - 540 * 0.8) / pixel
end
for _, scale in ipairs({ 0.6, 1.2 }) do
    for _, height in ipairs({ 1080, 2160 }) do
        native.scale, physicalHeight = scale, height
        local oldX, oldY = Position(native)
        Enter(xInput, "-123,25")
        local newX, newY = Position(native)
        Approx(newX, -123.25); Approx(newY, oldY)
        assert(xInput.text == "-123.25")
        Enter(yInput, "+45.5")
        newX, newY = Position(native)
        Approx(newX, -123.25); Approx(newY, 45.5)
        assert(not yInput:HasFocus())
    end
end
local changesBeforeInput = native.changed
xInput:SetFocus(); xInput:SetText("-12.")
panel.scripts.OnUpdate()
assert(xInput.text == "-12.", "Live updates must not overwrite an unfinished edit")
xInput.scripts.OnEscapePressed(xInput)
assert(not xInput:HasFocus() and native.changed == changesBeforeInput)
for _, invalid in ipairs({ "", "hello", "nan", "1e309", "999999999", "1,2,3" }) do
    Enter(xInput, invalid)
    assert(native.changed == changesBeforeInput and xInput:HasFocus() and xInput.color[2] == 0.2)
end
xInput.scripts.OnEscapePressed(xInput)
xInput:SetFocus(); xInput:SetText("15")
xInput.scripts.OnTabPressed(xInput)
assert(yInput:HasFocus() and not xInput:HasFocus())
local currentX = Position(native)
Approx(currentX, 15)
yInput:SetText("999")
module.SelectPixelPerfectFrame(display)
assert(not yInput:HasFocus(), "Changing frames must discard the old draft")
Enter(xInput, "0"); Enter(yInput, "-100.25")
local actualX, actualY = Position(display)
Approx(actualX, 0); Approx(actualY, -100.25)
Approx(PyresinQoLDB.performancePosition.x, display.x - 960)
Approx(PyresinQoLDB.performancePosition.y, display.y - 540)
local beforeInputX, beforeInputY = display.x, display.y
xInput:SetFocus(); xInput:SetText("100")
combat = true
panel.scripts.OnEvent()
assert(not xInput:HasFocus() and not panel.shown)
xInput.scripts.OnEnterPressed(xInput)
Approx(display.x, beforeInputX); Approx(display.y, beforeInputY)
combat = false
panel.scripts.OnEvent()
display.isDragging = true
Enter(yInput, "55")
Approx(display.y, beforeInputY)
display.isDragging = false
xInput:SetFocus(); xInput:SetText("123")
callbacks["EditMode.Exit"]()
assert(not xInput:HasFocus() and not panel.shown)
local closeButton = frames[13]
callbacks["EditMode.Enter"]()
EditModeManagerFrame:SelectSystem(native)
assert(panel.shown)
SelectTarget(target)
EditModeManagerFrame:SelectSystem(native)
assert(not panel.shown and native.shown and native.isSelected, "Second click hides only the popover")
module.UpdatePixelPerfectMode()
assert(not panel.shown, "Live refresh must not reopen a dismissed popover")
EditModeManagerFrame:SelectSystem(native)
assert(panel.shown and CurrentTargetName() == "Cast Bar", "Third click reopens and preserves the target")
xInput:SetFocus(); xInput:SetText("777")
local changeCount = native.changed
Click(closeButton)
assert(not panel.shown and not xInput:HasFocus() and native.changed == changeCount)
combat = true; panel.scripts.OnEvent()
combat = false; panel.scripts.OnEvent()
assert(not panel.shown, "Leaving combat must not undo explicit dismissal")
EditModeManagerFrame:SelectSystem(native)
assert(panel.shown)
EditModeManagerFrame:SelectSystem(native)
assert(not panel.shown)
native:OnDragStart()
assert(panel.shown, "Dragging must restore live coordinates and automatic target detection")
native.isDragging = false
Click(closeButton)
EditModeManagerFrame:SelectSystem(target)
assert(panel.shown and panel.texts[1].text == "Cast Bar", "Selecting another frame opens its popover")
module.TogglePixelPerfectFrame(display)
assert(panel.shown)
module.TogglePixelPerfectFrame(display)
assert(not panel.shown and display.shown)
module.TogglePixelPerfectFrame(display)
assert(panel.shown)
Click(closeButton)
module.TogglePixelPerfectFrame(display)
assert(panel.shown)
module.TogglePixelPerfectFrame(display)
display.isDragging = true
module.OnPixelPerfectDragStart(display)
assert(panel.shown)
display.isDragging = false
Click(closeButton)
callbacks["EditMode.Exit"]()
module.TogglePixelPerfectFrame(display)
assert(not panel.shown, "Clicks outside EditMode must not open the popover")
callbacks["EditMode.Enter"]()
module.TogglePixelPerfectFrame(display)
assert(panel.shown, "A new EditMode session resets the dismissal")
-- Native frames must still work when the FPS/latency module is absent.
module.ClearPixelPerfectFrame()
performance.performanceDisplay, performance.SavePerformancePosition = nil, nil
module.ClearPixelPerfectFrame()
module.SelectPixelPerfectFrame(native)
module.UpdatePixelPerfectMode()
assert(panel.shown)
callbacks["EditMode.Exit"]()
assert(not panel.shown)
print("PASS: coordinates, snapping, scaling, persistence, click/X dismissal, reopening, dragging and combat")

-- Idle updates may poll geometry but must not re-render or solve placement.
callbacks["EditMode.Enter"]()
native.Selection = nil
module.SelectPixelPerfectFrame(native)
panel.scripts.OnUpdate()
local textWrites, enabledWrites, placementCalculations = 0, 0, 0
for _, input in ipairs({ xInput, yInput }) do
    local original = input.SetText
    input.SetText = function(self, ...)
        textWrites = textWrites + 1
        return original(self, ...)
    end
end
for _, control in ipairs({ xInput, yInput, above, below, center }) do
    local original = control.SetEnabled
    control.SetEnabled = function(self, ...)
        enabledWrites = enabledWrites + 1
        return original(self, ...)
    end
end
local originalMin = math.min
math.min = function(...)
    placementCalculations = placementCalculations + 1
    return originalMin(...)
end
for _ = 1, 240 do panel.scripts.OnUpdate() end
assert(textWrites == 0 and enabledWrites == 0 and placementCalculations == 0,
    "Stationary EditMode must not rewrite controls or recalculate placement")
native.x = native.x + 10
panel.scripts.OnUpdate()
assert(textWrites == 1 and placementCalculations > 0, "Native movement must refresh immediately")
local function ExpectPlacementRefresh(change)
    placementCalculations = 0
    change()
    panel.scripts.OnUpdate()
    assert(placementCalculations > 0, "Geometry changes must invalidate cached placement")
end
ExpectPlacementRefresh(function() EditModeSystemSettingsDialog:Show() end)
ExpectPlacementRefresh(function() EditModeSystemSettingsDialog.x = EditModeSystemSettingsDialog.x + 40 end)
ExpectPlacementRefresh(function() EditModeSystemSettingsDialog:Hide() end)
ExpectPlacementRefresh(function() panel:SetSize(280, 180) end)
local parentRect, parentScale = UIParent.GetRect, UIParent.GetEffectiveScale
ExpectPlacementRefresh(function() UIParent.GetRect = function() return 0, 0, 1800, 1000 end end)
ExpectPlacementRefresh(function() UIParent.GetEffectiveScale = function() return 0.9 end end)
UIParent.GetRect, UIParent.GetEffectiveScale = parentRect, parentScale
math.min = originalMin
panel.scripts.OnUpdate()
local savedCoordinate = xInput.text
xInput:SetFocus(); xInput:SetText("unfinished")
xInput.scripts.OnEscapePressed(xInput)
assert(xInput.text == savedCoordinate, "Discarding a draft must restore an unchanged coordinate")
print("PASS: idle controls, cached placement and geometry/focus invalidation")
