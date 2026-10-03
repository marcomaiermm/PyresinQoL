-- Run from the addon directory: luajit tests/actionbars-editmode.lua [de|late]
local h = assert(loadfile("tests/support/castbar.lua"))()
local Frame, Region, widgets = h.Frame, h.Region, h.eventFrames
function GetLocale() return arg[1] == "de" and "deDE" or "enUS" end
function UIParent:GetEffectiveScale() return 1 end
local combat, updates = false, 0
function InCombatLockdown() return combat end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = "OnValueChanged" } }
EventUtil = { CreateCallbackHandleContainer = function()
    return { RegisterCallback = function(_, slider, event, callback, owner)
        slider.callbacks[event] = function(value) callback(owner, value) end
    end }
end }

local dialog = Frame()
dialog.Settings, dialog.Buttons = Frame(), Frame()
dialog.Settings:SetSize(343, 280)
dialog.Buttons:SetHeight(128)
function dialog:Layout() self.layouts = (self.layouts or 0) + 1 end
function dialog:UpdateDialog(frame)
    if frame ~= self.attachedToSystem then return end
    self.Buttons:ClearAllPoints()
    self.Buttons:SetPoint("TOPLEFT", self.Settings, "BOTTOMLEFT", 0, -12)
end
EditModeSystemSettingsDialog = arg[1] ~= "late" and dialog or nil
function EditModeManagerFrame:SelectSystem(frame)
    dialog.attachedToSystem = frame
    dialog:UpdateDialog(frame)
    dialog:Show()
end
function EditModeManagerFrame:IsShown() return self.shown end
function ShowUIPanel(frame) frame.shown = true end
PyresinQoLSettingsFrame = Frame()
local popup
StaticPopupDialogs = {}
function StaticPopup_Show(name, label, _, data) popup = { name = name, label = label, data = data } end
UIErrorsFrame = { AddMessage = function(self, message) self.message = message end }
ACCEPT, CANCEL = "Accept", "Cancel"

local function Initializer(kind, label)
    return { kind = kind, label = label, InitFrame = function() end,
        AddModifyPredicate = function(self, fn) self.predicate = fn end }
end
local registered = {}
Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },
    RegisterAddOnSetting = function(_, _, key, db, _, name, default)
        if db[key] == nil then db[key] = default end
        local value = { name = name }
        function value:GetValue() return db[key] end
        function value:SetValue(v) db[key] = v; self.callback(self, v) end
        function value:SetValueChangedCallback(fn) self.callback = fn end
        registered[key] = value
        return value
    end,
    CreateCheckboxInitializer = function(setting) return Initializer("checkbox", setting.name) end,
    CreateColorSwatchInitializer = function(setting) return Initializer("color", setting.name) end,
    CreateSliderInitializer = function(setting) return Initializer("slider", setting.name) end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
}
function CreateSettingsListSectionHeaderInitializer(label) return Initializer("header", label) end
function CreateSettingsButtonInitializer(label, text, callback)
    local entry = Initializer("button", label)
    entry.text, entry.click = text, callback
    return entry
end

local ns = { CastBar = h.castBar }
for _, path in ipairs({ "Core/Localization.lua", "Core/Modules.lua", "Settings/Controls.lua",
    "Modules/ActionBars/Config.lua", "Modules/CastBar/EditMode.lua", "Modules/ActionBars/EditMode.lua",
    "Modules/ActionBars/Settings.lua" }) do assert(loadfile(path))("PyresinQoL", ns) end
local module, L = ns.GetModule("actionBars"), ns.L
module.UpdateActionBars = function() updates = updates + 1 end
for _, bar in ipairs(ns.ActionBars.bars) do _G[bar.frame] = Frame() end
PyresinQoLDB.actionBarMainEnabled, PyresinQoLDB.actionBarMainAlphaNormal = true, .23
PyresinQoLDB.actionBarBar2Enabled = false
local before = #widgets
ns.InitializeModules()
local page = { module = module, settings = {}, initializers = {} }
module.buildSettings(module, { pages = { main = page }, controls = ns.CreateSettingsControls({}) })
assert(PyresinQoLDB.actionBarMainAlphaNormal == .23, "Moving settings preserves existing values")
assert(#module.pages == 1 and #page.settings == 100, "Per-bar settings remain registered for profiles/defaults")
local renderedCheckboxes = 0
for _, initializer in ipairs(page.initializers) do
    if initializer.kind == "checkbox" then renderedCheckboxes = renderedCheckboxes + 1 end
end
assert(renderedCheckboxes == 3, "Addon settings no longer render a checkbox list for all eight bars")

if arg[1] == "late" then
    EditModeSystemSettingsDialog = dialog
    local lastLoader = #widgets
    for index = before + 1, lastLoader do
        local frame = widgets[index]
        if frame.events.ADDON_LOADED then frame.scripts.OnEvent(frame, "ADDON_LOADED", "Blizzard_EditMode") end
    end
end
combat = true
module.ConfigureActionBars()
assert(not dialog.attachedToSystem, "Edit Mode cannot open during combat")
combat = false
page.initializers[#page.initializers].click()
assert(dialog.attachedToSystem == MainActionBar and not PyresinQoLSettingsFrame:IsShown())
local panel, scroll, enable, macroButton
for _, widget in ipairs(widgets) do
    if widget.template == "EditModeSettingCheckboxTemplate" and widget.Label:GetText() == L.actionBarEnabled then
        enable, panel = widget, widget.parent
    end
    if widget:GetText() == L.actionBarEditCondition then macroButton = widget end
end
for _, widget in ipairs(widgets) do if widget.parent == panel and widget.scrollChild then scroll = widget end end
assert(panel and panel:IsShown() and scroll:IsShown() and enable.Button:GetChecked())
assert(select(2, panel:GetPoint()) == dialog.Settings and select(2, dialog.Buttons:GetPoint()) == panel,
    "The addon section sits between native settings and native buttons")
local function Checkbox(suffix)
    for _, widget in ipairs(widgets) do
        if widget.parent == scroll.scrollChild and widget.Label and widget.Label:GetText() == L["actionBar" .. suffix] then
            return widget
        end
    end
    error("Missing checkbox: " .. suffix)
end
local function Slider(suffix)
    for _, widget in ipairs(widgets) do
        if widget.parent == scroll.scrollChild and widget.slider then
            for _, text in ipairs(widget.children) do
                if text:GetText() == L["actionBar" .. suffix] then return widget.slider end
            end
        end
    end
    error("Missing slider: " .. suffix)
end
local hide, opacity = Checkbox("HideCombat"), Slider("AlphaNormal")
assert(opacity.sliderValue == 23)
hide.OnCheckButtonClick()
assert(PyresinQoLDB.actionBarMainHideCombat and not PyresinQoLDB.actionBarBar2HideCombat)
local layouts = dialog.layouts
opacity.Slider.dragging = true
opacity:SetValue(37)
assert(PyresinQoLDB.actionBarMainAlphaNormal == .37 and dialog.layouts == layouts,
    "A slider drag saves to its bar without changing the thumb's coordinate space")
opacity.Slider.dragging = false
macroButton.scripts.OnClick()
assert(popup.label == L.actionBar1 and popup.data.key == "actionBarMainCustomCondition")

scroll:SetVerticalScroll(100)
EditModeManagerFrame:SelectSystem(MultiBarBottomLeft)
assert(panel:IsShown() and not scroll:IsShown() and scroll:GetVerticalScroll() == 0 and not enable.Button:GetChecked())
enable.OnCheckButtonClick()
assert(PyresinQoLDB.actionBarBar2Enabled and scroll:IsShown() and opacity.sliderValue == 100)
Checkbox("HideStealth").OnCheckButtonClick()
opacity:SetValue(61)
assert(PyresinQoLDB.actionBarBar2HideStealth and PyresinQoLDB.actionBarBar2AlphaNormal == .61)
assert(PyresinQoLDB.actionBarMainAlphaNormal == .37 and not PyresinQoLDB.actionBarMainHideStealth)

local conditionText = "[stealth] hide; show"
local popupFrame = { GetEditBox = function() return { GetText = function() return conditionText end } end }
StaticPopupDialogs[popup.name].OnAccept(popupFrame, popup.data)
assert(PyresinQoLDB.actionBarMainCustomCondition == conditionText and PyresinQoLDB.actionBarBar2CustomCondition == "",
    "An open macro editor keeps the bar it was opened for when selection changes")
conditionText = "[combat] invalid"
assert(StaticPopupDialogs[popup.name].OnAccept(popupFrame, popup.data) and UIErrorsFrame.message)
assert(PyresinQoLDB.actionBarMainCustomCondition == "[stealth] hide; show")
combat = true
conditionText = "hide"
assert(StaticPopupDialogs[popup.name].OnAccept(popupFrame, popup.data))
hide.OnCheckButtonClick()
assert(not PyresinQoLDB.actionBarBar2HideCombat and PyresinQoLDB.actionBarMainCustomCondition ~= "hide")
combat = false

local count = #widgets
for _, bar in ipairs(ns.ActionBars.bars) do
    EditModeManagerFrame:SelectSystem(_G[bar.frame])
    assert(panel:IsShown(), "Each supported action bar owns the same reusable section")
end
assert(#widgets == count, "Switching bars cannot create duplicate controls or callbacks")
dialog.Settings:SetWidth(390)
dialog:UpdateDialog(dialog.attachedToSystem)
assert(panel:GetWidth() == 390 and opacity:GetWidth() == 366)
dialog:UpdateDialog(MainActionBar)
assert(panel:IsShown() and dialog.attachedToSystem == MultiBar7, "Updates for unselected bars cannot retarget controls")

EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
local castPanel = select(2, dialog.Buttons:GetPoint())
assert(not panel:IsShown() and castPanel ~= panel and castPanel ~= dialog.Settings and castPanel:IsShown(),
    "Selecting the cast bar keeps its own section and native button anchors")
EditModeManagerFrame:SelectSystem(MainActionBar)
assert(panel:IsShown() and not castPanel:IsShown() and select(2, dialog.Buttons:GetPoint()) == panel)
EditModeManagerFrame:SelectSystem(Frame())
assert(not panel:IsShown() and not castPanel:IsShown() and select(2, dialog.Buttons:GetPoint()) == dialog.Settings)
EditModeManagerFrame:SelectSystem(MainActionBar)
dialog.scripts.OnHide(dialog)
assert(not panel:IsShown(), "Closing Edit Mode clears the section's active bar")
assert(updates > 0, "Edit Mode edits use the existing settings callbacks")
print("PASS: per-bar Edit Mode section, saved values, sliders, macro ownership, combat guards and cast-bar coexistence")
