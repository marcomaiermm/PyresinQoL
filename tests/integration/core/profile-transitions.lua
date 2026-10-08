-- Real Performance and CastBar runtimes share the profile switch boundary.
local h = assert(loadfile("tests/support/castbar.lua"))()
local cast, bar = h.castBar, PlayerCastingBarFrame
local combat, editing, pickerInfo = false, true
function InCombatLockdown() return combat end
function UnitGUID() return "Player-transitions" end
function UnitName() return "Transitions" end
function CopyTable(value)
    local copy = {}
    for key, item in pairs(value) do copy[key] = type(item) == "table" and CopyTable(item) or item end
    return copy
end
function GetFramerate() return 60 end
function CreateColorFromHexString() return { GetRGB = function() return 1, 1, 1 end } end
function UIParent:GetCenter() return 960, 540 end
local callbacks = {}
EventRegistry = {}
function EventRegistry:RegisterCallback(name, callback, owner)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], function(...) callback(owner, ...) end)
end
function EventRegistry:TriggerEvent(name, ...)
    for _, callback in ipairs(callbacks[name] or {}) do callback(...) end
end
local create = CreateFrame
function CreateFrame(...)
    local frame = create(...)
    function frame:SetMovable(value) self.movable = value end
    function frame:SetClampedToScreen() end
    function frame:EnableMouse() end
    function frame:SetSystem(system) self.system = system end
    function frame:ShowHighlighted() self:Show() end
    function frame:ShowSelected() self:Show() end
    function frame:StartMoving() assert(self.movable); self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:GetCenter()
        local _, _, _, x, y = self:GetPoint()
        return self.dragX or 960 + x, self.dragY or 540 + y
    end
    local originalFontString = frame.CreateFontString
    function frame:CreateFontString(...)
        local text = originalFontString(self, ...)
        function text:SetFormattedText(format, ...) self:SetText(format:format(...)) end
        return text
    end
    return frame
end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = "OnValueChanged" } }
EventUtil = { CreateCallbackHandleContainer = function()
    return { RegisterCallback = function(_, slider, event, callback, owner)
        slider.callbacks[event] = function(value) callback(owner or 237, value) end
    end }
end }
function CreateMinimalSliderFormatter(_, format) return format end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
EditModeSystemSettingsDialog = h.Frame()
EditModeSystemSettingsDialog.Settings, EditModeSystemSettingsDialog.Buttons = h.Frame(), h.Frame()
EditModeSystemSettingsDialog.Settings:SetWidth(343)
function EditModeSystemSettingsDialog:Layout() end
function EditModeSystemSettingsDialog:UpdateDialog(target) self.attachedToSystem = target end
function EditModeManagerFrame:IsShown() return editing end
function EditModeManagerFrame:HasActiveChanges() return false end
function EditModeManagerFrame:SelectSystem(target) EditModeSystemSettingsDialog:UpdateDialog(target) end
function ShowUIPanel() editing = true end
ColorPickerFrame = {
    SetupColorPickerAndShow = function(self, info) self.shown = true; pickerInfo = info end,
    GetColorRGB = function() return .8, .7, .6 end,
    IsShown = function(self) return self.shown end,
    Hide = function(self) self.shown = false end,
}
local ns = { CastBar = cast }
for _, file in ipairs({ "Core/Localization.lua", "Core/Modules.lua", "Core/Profiles.lua", "Core/Database.lua",
    "Modules/Performance/Performance.lua", "Modules/CastBar/EditMode.lua" }) do
    assert(loadfile(file))("PyresinQoL", ns)
end
Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 }
Enum.EditModePresetLayoutsMeta = { NumValues = 3 }
local info = { activeLayout = 4, layouts = {
    { layoutType = 1, layoutName = "A" }, { layoutType = 1, layoutName = "B" }, { layoutType = 1, layoutName = "C" },
} }
C_EditMode = { GetLayouts = function() return CopyTable(info) end }
local modules = {}
for _, module in ipairs(ns.modules) do modules[module.id] = module.id == "performance" or module.id == "unitFrames" end
PyresinQoLDB = { modules = modules, showFPS = true, showLatency = true,
    performancePosition = { x = 10, y = 20 }, castBarCustomization = true,
    castBar = { width = 220, colorMode = "custom", customColor = { r = .1, g = .2, b = .3 } } }
local queued, prompts = {}, 0
C_Timer = { After = function(_, callback) queued[#queued + 1] = callback end }
function StaticPopup_Show(name) assert(name == "PYRESINQOL_PROFILE_RELOAD"); prompts = prompts + 1 end
function ns.InitializeSettings()
    -- Use real module refreshes; registered-setting callback wiring is covered by
    -- settings.lua and the native UI transition scenario.
    function ns.RefreshProfileSettings()
        ns.GetModule("performance").UpdatePerformanceLayout()
        cast.Apply()
        cast.RefreshControls()
    end
end
assert(loadfile("Core/Bootstrap.lua"))("PyresinQoL", ns)
local core = h.eventFrames[#h.eventFrames]
core.scripts.OnEvent(core, "ADDON_LOADED", "PyresinQoL")
local function Event(name) core.scripts.OnEvent(core, name) end
local function Flush()
    local work = queued; queued = {}
    for _, callback in ipairs(work) do callback() end
end
Event("PLAYER_LOGIN"); Flush()
local store = PyresinQoLDB.profileStore
local firstProfile = store.active
store.profiles.B = CopyTable(PyresinQoLDB); store.profiles.B.profileStore = nil
store.profiles.B.performancePosition = { x = 300, y = -80 }
store.profiles.B.castBar = { width = 340, colorMode = "custom", customColor = { r = .3, g = .4, b = .5 } }
store.profiles.C = CopyTable(store.profiles.B)
store.profiles.C.performancePosition = { x = -200, y = 100 }
store.characterBindings[UnitGUID("player")]["account:1:B"] = "B"
store.characterBindings[UnitGUID("player")]["account:1:C"] = "C"
local performance = ns.GetModule("performance")
local display, mover = performance.performanceDisplay, performance.performanceDisplay.Selection
display.scripts.OnEvent(display, "PLAYER_LOGIN")
EventRegistry:TriggerEvent("EditMode.Enter")
cast.Configure()
h.StartCast(false, false)
local panel, preview, colorButton
for _, widget in ipairs(h.eventFrames) do
    if widget.parent == EditModeSystemSettingsDialog then panel = widget end
    if widget.progress and widget.name and widget.time and not preview then preview = widget end
    if widget:GetText() == ns.L.castBarPickColor and widget.parent:IsShown() then colorButton = colorButton or widget end
end
assert(panel and panel:IsShown() and preview and colorButton)
colorButton.scripts.OnClick(colorButton)
local oldPicker = assert(pickerInfo)
mover.scripts.OnDragStart()
assert(display.isDragging and display.moving)
display.dragX, display.dragY = 1000, 630
info.activeLayout = 5
Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
assert(store.active == "B" and not display.isDragging and not display.moving)
assert(store.profiles[firstProfile].performancePosition.x == 40 and store.profiles[firstProfile].performancePosition.y == 90)
assert(PyresinQoLDB.performancePosition.x == 300 and PyresinQoLDB.performancePosition.y == -80)
assert(select(4, display:GetPoint()) == 300 and select(5, display:GetPoint()) == -80)
mover.scripts.OnDragStop() -- A queued mouse release from the outgoing profile.
assert(PyresinQoLDB.performancePosition.x == 300 and store.profiles[firstProfile].performancePosition.x == 40)
assert(not ColorPickerFrame:IsShown() and bar.casting and bar:GetWidth() == 340)
assert(preview.fill:GetWidth() == 340, "Visible editor preview refreshes with the incoming profile")
oldPicker.cancelFunc()
assert(cast.Get("customColor").r == .3, "Old picker cancel must not overwrite the incoming profile")
oldPicker.swatchFunc()
assert(cast.Get("customColor").r == .3, "Old picker commit must not overwrite the incoming profile")
h.Advance(.25)
assert(bar:GetWidth() == 340 and bar.Text:GetText() == "Arcane Blast")
h.FailCast(false)
assert(bar:GetWidth() == 340, "The old cast lifecycle keeps the incoming customization")
print("PASS: automatic profile switch composes real drag stop/save/restore, active cast, editor preview and stale picker callbacks")

-- Both event orders occur in practice: queued work can run in combat or only
-- after combat has ended. Neither may apply the intermediate layout.
for _, flushDuringCombat in ipairs({ true, false }) do
    info.activeLayout = 4; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
    local outgoing = PyresinQoLDB.profileStore.active
    PyresinQoLDB.transitionSentinel = "outgoing"
    store.profiles.C.modules.performance = false
    combat, editing = true, false
    info.activeLayout = 5; Event("EDIT_MODE_LAYOUTS_UPDATED")
    if flushDuringCombat then Flush(); assert(store.active == outgoing) end
    info.activeLayout = 6; Event("EDIT_MODE_LAYOUTS_UPDATED"); Event("PLAYER_SPECIALIZATION_CHANGED")
    local before = prompts
    if flushDuringCombat then Flush(); assert(store.active == outgoing) end
    combat = false; Event("PLAYER_REGEN_ENABLED"); Flush()
    assert(store.active == "C" and not PyresinQoLDB.transitionSentinel)
    assert(store.profiles[outgoing].transitionSentinel == "outgoing")
    assert(not store.profiles.B.transitionSentinel and prompts == before + 1)
    assert(select(4, display:GetPoint()) == -200)
    Event("PLAYER_REGEN_ENABLED"); Flush()
    assert(prompts == before + 1, "Duplicate post-combat events must not repeat the reload prompt")
end
-- An unbound intermediate layout must not even create a throwaway profile.
info.activeLayout = 4; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
store.profiles.B = nil; store.characterBindings[UnitGUID("player")]["account:1:B"] = nil
store.profileLayouts[UnitGUID("player")].B = nil
combat = true
info.activeLayout = 5; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
info.activeLayout = 6; Event("EDIT_MODE_LAYOUTS_UPDATED")
combat = false; Event("PLAYER_REGEN_ENABLED"); Flush()
assert(store.active == "C" and not store.profiles.B, "Do not create intermediate profiles while combat defers switching")
print("PASS: queued A/B/C layout bursts apply only final C, preserve outgoing settings and prompt once")

-- Table identity alone cannot distinguish two untouched default configurations.
info.activeLayout = 4; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
PyresinQoLDB.castBar = nil
cast.RefreshControls()
local staleChoice
for _, widget in ipairs(h.eventFrames) do
    for _, option in ipairs(widget.options or {}) do
        if option.value == "class" then staleChoice = option; break end
    end
    if staleChoice then break end
end
assert(staleChoice)
store.profiles.C.castBar = nil
info.activeLayout = 6; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
assert(store.active == "C" and PyresinQoLDB.castBar == nil)
staleChoice.select(staleChoice.value)
assert(PyresinQoLDB.castBar == nil, "A stale dropdown must not edit an incoming default profile (nil to nil)")
print("PASS: profile boundary invalidates outgoing dropdowns even when both profiles use default cast-bar settings")

-- A damaged snapshot must never replace the registry driving the live switch.
store.profiles[firstProfile].profileStore = { profiles = {} }
store.profiles[firstProfile].futureSetting = { keep = "incoming" }
info.activeLayout = 4; Event("EDIT_MODE_LAYOUTS_UPDATED"); Flush()
assert(PyresinQoLDB.profileStore == store and store.active == firstProfile)
assert(PyresinQoLDB.futureSetting.keep == "incoming", "Preserve ordinary unknown snapshot fields")
assert(PyresinQoLDB.futureSetting ~= store.profiles[firstProfile].futureSetting, "Restored settings remain isolated from the snapshot")
assert(store.profiles.C and store.characterBindings[UnitGUID("player")]["account:1:C"] == "C")
print("PASS: automatic profile restore excludes the reserved registry field while preserving unknown settings")
