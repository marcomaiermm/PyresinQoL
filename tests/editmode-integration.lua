-- luajit tests/editmode-integration.lua [both|editMode|performance|neither]
local frames, callbacks = {}, {}
local combat, locked = false, false
local physicalHeight = 1080
local snapEnabled, magneticInfos, magneticQueries = true, nil, 0
local ns = {}
function GetLocale() return "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
local mode = arg[1] or "both"
assert(mode == "both" or mode == "editMode" or mode == "performance" or mode == "neither")
local hasEditor = mode == "both" or mode == "editMode"
local hasPerformance = mode == "both" or mode == "performance"
PyresinQoLDB = { modules = {}, pixelPerfectEditMode = true, showFPS = true, showLatency = true,
    performancePosition = { x = 100, y = 50 } }
for _, module in ipairs(ns.modules) do PyresinQoLDB.modules[module.id] = false end
PyresinQoLDB.modules.editMode, PyresinQoLDB.modules.performance = hasEditor, hasPerformance
UIParent = { GetCenter = function() return 960, 540 end, GetEffectiveScale = function() return 0.8 end }
function UIParent:IsShown() return true end
function UIParent:GetRect() return 0, 0, 1920, 1080 end
PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / physicalHeight end }
function InCombatLockdown() return combat end
Enum = { EditModeCastBarSetting = { LockToPlayerFrame = 1 } }
EventRegistry = { RegisterCallback = function(_, event, callback)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], callback)
end }
local function Emit(event)
    for _, callback in ipairs(callbacks[event] or {}) do callback() end
end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, 20, 40 end
function CreateColorFromHexString() return { GetRGB = function() return 1, 1, 1 end } end
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
        assert(frame ~= ns.GetModule("performance").performanceDisplay, "Custom display must not enter Blizzard's system API")
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
        ClearAllPoints = function() end, SetShown = function() end, SetTextColor = function() end,
        SetText = function(self, value) self.text = value end,
        SetFormattedText = function(self, format, ...) self.text = format:format(...) end,
    }
end
function CreateFrame(kind, name, parent, template)
    local frame = { name = name, parent = parent, template = template, scripts = {}, events = {}, texts = {}, shown = true, x = 1200, y = 700, scale = 0.8, width = 200, height = 50 }
    frames[#frames + 1] = frame
    function frame:SetMovable(value) self.movable = value end
    function frame:SetAllPoints(target) self.allPoints = target end
    function frame:SetSystem(system) self.system = system end
    function frame:ShowHighlighted() self.selected = false; self:Show() end
    function frame:ShowSelected() self.selected = true; self:Show() end
    function frame:SetShown(value) if value then self:Show() else self:Hide() end end
    function frame:StartMoving() assert(self.movable); self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:RegisterForDrag() end
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
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
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

-- Load runtime definitions before saved module state is applied, exactly as in the TOC.
assert(loadfile("Modules/Performance/Performance.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/EditMode/PixelPerfect.lua"))("PyresinQoL", ns)
assert(#frames == 0 and next(callbacks) == nil)
ns.InitializeModules()
local editor, performance = ns.GetModule("editMode"), ns.GetModule("performance")
assert(editor.active == hasEditor and performance.active == hasPerformance)
local panel, right
for _, frame in ipairs(frames) do
    if frame.name == "PyresinQoLPixelPerfect" then panel = frame end
    if panel and frame.parent == panel and frame.point and frame.point[2] == 162 then right = frame end
end
assert((panel ~= nil) == hasEditor)
assert((performance.performanceDisplay ~= nil) == hasPerformance)
assert((editor.SelectPixelPerfectFrame ~= nil) == hasEditor)
assert(#(callbacks["EditMode.Enter"] or {}) == (hasEditor and 1 or 0) + (hasPerformance and 1 or 0))
if mode == "neither" then assert(#frames == 0 and next(callbacks) == nil) end
local display = performance.performanceDisplay
if display then
    display.scripts.OnEvent(display, "PLAYER_LOGIN")
    assert(display.point[1] == "CENTER" and display.point[4] == 100 and display.point[5] == 50)
end
Emit("EditMode.Enter")
if display then
    local mover = display.Selection
    assert(mover:IsShown())
    mover.scripts.OnMouseDown(mover)
    if panel then
        assert(panel:IsShown(), "Performance selection must open the real editor")
        local x = display.x
        right.scripts.OnClick()
        assert(display.x > x and PyresinQoLDB.performancePosition.x == display.x - 960,
            "Editor nudges must persist through the real Performance module")
    end
    mover.scripts.OnDragStart()
    assert(display.moving)
    display.x, display.y = 1250, 220
    mover.scripts.OnDragStop()
    assert(not display.moving and PyresinQoLDB.performancePosition.x == 290 and PyresinQoLDB.performancePosition.y == -320)
    if panel then
        editor.UpdatePixelPerfectMode()
        assert(panel:IsShown())
    end
    mover.scripts.OnDragStart()
    combat = true
    display.scripts.OnEvent(display, "PLAYER_REGEN_DISABLED")
    if panel then panel.scripts.OnEvent(panel, "PLAYER_REGEN_DISABLED") end
    assert(not display.moving and not mover:IsShown() and (not panel or not panel:IsShown()))
    combat = false
    display.scripts.OnEvent(display, "PLAYER_REGEN_ENABLED")
    if panel then panel.scripts.OnEvent(panel, "PLAYER_REGEN_ENABLED") end
    assert(mover:IsShown())
    Emit("EditMode.Exit")
    assert(not mover:IsShown() and (not panel or not panel:IsShown()))
    -- Simulate login restoration in a fresh runtime, with the saved table intact.
    local fresh = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", fresh)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", fresh)
    assert(loadfile("Modules/Performance/Performance.lua"))("PyresinQoL", fresh)
    fresh.InitializeModules()
    local restored = fresh.GetModule("performance").performanceDisplay
    restored.scripts.OnEvent(restored, "PLAYER_LOGIN")
    assert(restored.point[4] == 290 and restored.point[5] == -320)
elseif panel then
    -- The editor still operates on native frames without a Performance display.
    local native = CreateFrame("Frame")
    function native:CanBeMoved() return true end
    function native:GetSystemName() return "Native frame" end
    function native:ClearFrameSnap() end
    function native:BreakFrameSnap(dx, dy) self.x, self.y = self.x + dx, self.y + dy end
    editor.SelectPixelPerfectFrame(native)
    assert(panel:IsShown())
    local x = native.x
    right.scripts.OnClick()
    assert(native.x > x and PyresinQoLDB.performancePosition.x == 100)
    Emit("EditMode.Exit")
    assert(not panel:IsShown())
end
print("PASS: real EditMode/Performance integration (" .. mode .. "), optional startup, movement and saved positions")
