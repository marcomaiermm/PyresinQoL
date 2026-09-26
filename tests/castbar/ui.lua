local h = assert(loadfile("tests/support/castbar.lua"))(arg[1])
local castBar, frame = h.castBar, PlayerCastingBarFrame
local StartCast, Advance, FailCast = h.StartCast, h.Advance, h.FailCast
local Frame, Region, eventFrames, modelFrames = h.Frame, h.Region, h.eventFrames, h.modelFrames
local Near, CheckModelViewport, secret = h.Near, h.CheckModelViewport, h.secret
castBar.SetEnabled(true)
StartCast(false, false)
MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = "OnValueChanged" } }
EventUtil = { CreateCallbackHandleContainer = function()
    return { RegisterCallback = function(_, slider, event, callback, owner)
        -- Blizzard prepends the owner, even when it generated a numeric owner ID.
        slider.callbacks[event] = function(value) callback(owner or 237, value) end
    end }
end }
function CreateMinimalSliderFormatter(_, format) return format end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function PlaySound() end
local combat, selected = false, 0
function InCombatLockdown() return combat end
EditModeSystemSettingsDialog = Frame()
EditModeSystemSettingsDialog.Settings = Frame()
EditModeSystemSettingsDialog.Settings:SetWidth(1)
EditModeSystemSettingsDialog.Buttons = Frame()
function EditModeSystemSettingsDialog:Layout()
    self.layoutCount = (self.layoutCount or 0) + 1
end
function EditModeSystemSettingsDialog:UpdateDialog(target)
    if self.Settings:GetWidth() == 1 then self.Settings:SetWidth(343) end
    self.attachedToSystem = target
end
EditModeManagerFrame = {
    SelectSystem = function(_, target)
        assert(target == frame)
        selected = selected + 1
        EditModeSystemSettingsDialog:UpdateDialog(target)
    end,
    IsShown = function(self) return self.shown end,
}
function ShowUIPanel(panel) assert(panel == EditModeManagerFrame); panel.shown = true end
local pickerColor, pickerInfo
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info) pickerInfo = info end,
    GetColorRGB = function() return unpack(pickerColor) end,
}
local function InstallUI()
    local session = { CastBar = castBar }
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", session)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/EditMode.lua"))("PyresinQoL", session)
    session.InitializeModules()
    return session
end
PyresinQoLDB.modules.unitFrames = false
local widgetCount = #eventFrames
InstallUI()
assert(#eventFrames == widgetCount, "Disabled unit-frame module must not create Edit Mode UI")
PyresinQoLDB.modules.unitFrames = true
local uiSession = InstallUI()
local labels = uiSession.L
combat = true
castBar.Configure()
assert(selected == 0, "No Edit Mode configuration while combat lockdown is active")
combat = false
castBar.Configure()
assert(selected == 1 and EditModeManagerFrame.shown)
local panel
for _, widget in ipairs(eventFrames) do
    if widget.parent == EditModeSystemSettingsDialog then panel = widget; break end
end
assert(panel and panel:IsShown())
local content
for _, widget in ipairs(eventFrames) do
    if widget.parent == panel and widget.scrollChild then content = widget.scrollChild end
end
assert(content)
assert(panel:GetWidth() == EditModeSystemSettingsDialog.Settings:GetWidth(),
    "The extension must fit the native settings column")
assert(content:GetWidth() == panel:GetWidth() - 24, "Reserve scrollbar space inside the dialog")
local function Control(label)
    for _, widget in ipairs(eventFrames) do
        if widget.parent == content then
            if widget.Label and widget.Label:GetText() == label then return widget end
            for _, text in ipairs(widget.children) do
                if text:GetText() == label then return widget end
            end
        end
    end
    error("Missing native cast-bar control: " .. label)
end
local function Tab(label)
    for _, widget in ipairs(eventFrames) do
        if widget.parent == panel and widget:GetText() == label then
            widget.scripts.OnClick(widget)
            return widget
        end
    end
    error("Missing tab " .. label)
end
local enable
for _, widget in ipairs(eventFrames) do
    if widget.parent == panel and widget.Label and widget.Label:GetText() == labels.castBarEnable then enable = widget end
end
assert(enable and enable:IsShown(), "The embedded enable row must be explicitly shown")
assert(enable.Button:GetChecked())
enable.OnCheckButtonClick(enable)
assert(not castBar.IsEnabled() and not enable.Button:GetChecked())
enable.OnCheckButtonClick(enable)
assert(castBar.IsEnabled() and enable.Button:GetChecked())
local textureChoice = Control(labels.castBarTexture)
do
    local animated = Control(labels.castBarAnimated)
    local previousTexture = castBar.Get("texture")
    assert(animated:IsShown() and animated.points[1][3] == textureChoice.points[1][3] - textureChoice:GetHeight(),
        "Animated belongs directly below the texture selector in Appearance")
    castBar.Set("texture", "alchemy")
    StartCast(false, false)
    local effect, art = frame.pyresinCastAnimation, frame.pyresinCastTexture
    assert(animated.Button.enabled and animated.Button:GetChecked() and effect:IsPlaying())
    animated.OnCheckButtonClick(animated)
    assert(not castBar.Get("animated") and not animated.Button:GetChecked())
    assert(not effect:IsPlaying())
    assert(art:GetBlendMode() == "BLEND", "Animated off restores the original static compositing")
    assert(art:IsShown() and art:GetTexture() == 4242 and art:GetAlpha() == 1,
        "Animation off restores visible static artwork, not the full flipbook atlas")
    local left, top, _, bottom, right = art:GetTexCoord()
    assert(left == 0 and right == .5 and top == 0 and bottom == .5)
    assert(art.masks[frame.pyresinCastTextureMask] and frame.pyresinCastTextureMask.allPoints == frame:GetStatusBarTexture())
    for _, channel in ipairs({ false, true }) do
        StartCast(channel, false)
        frame:Hide(); frame.scripts.OnHide(frame)
        frame:Show(); frame.scripts.OnShow(frame)
        assert(not effect:IsPlaying() and art:GetTexture() == 4242,
            "New casts/channels and OnShow cannot restart disabled flipbooks")
    end
    for _, descriptor in ipairs(castBar.ModelTextures) do
        castBar.Set("texture", descriptor.id)
        assert(animated:IsShown() and not animated.Button.enabled and animated.Button:GetChecked())
        assert(animated.Label.fontObject == "GameFontDisable" and frame.pyresinCastModels:IsShown())
        assert(art:GetBlendMode() == "BLEND", "Model styles must not inherit additive flipbook compositing")
        animated.OnCheckButtonClick(animated)
        assert(not castBar.Get("animated"), "Disabled model controls cannot overwrite the saved flipbook preference")
    end
    castBar.Set("texture", "cooking")
    assert(animated.Button.enabled and not animated.Button:GetChecked() and not effect:IsPlaying())
    assert(animated.Label.fontObject == "GameFontHighlight")
    castBar.Set("texture", "default")
    assert(not animated.Button.enabled and not animated.Button:GetChecked())
    animated.OnCheckButtonClick(animated)
    assert(not castBar.Get("animated"))
    castBar.Set("texture", "alchemy")
    animated.OnCheckButtonClick(animated)
    assert(castBar.Get("animated") and effect:IsPlaying())
    assert(PyresinQoLDB.castBar.animated == nil, "Default animation preference needs no saved override")
    castBar.Set("texture", previousTexture)
end
textureChoice.Dropdown:GenerateMenu()
assert(textureChoice.Dropdown.menuHeight == 420, "The expanded texture list must fit in a scrolling menu")
local function CheckModelPreview(owner, texture, descriptor)
    local effects = owner.pyresinCastModelPreview
    if not descriptor.models then
        assert(not effects or not effects:IsShown(), "Ordinary textures cannot retain a reused model preview")
        return
    end
    assert(effects and effects:IsShown(), "Model swatches must show their model effects, not just base colors")
    assert(effects:GetParent() == owner and effects.allPoints == texture and effects.progress.allPoints == texture)
    assert(effects.clipsChildren and effects.flattens, "Menu particles stay inside their own swatch")
    local count = 0
    for _, model in pairs(effects.models) do
        if model.active then
            count = count + 1
            assert(model.renderReady)
            CheckModelViewport(model, descriptor, texture, texture)
            assert(model.modelFile == model.data.file)
        else assert(not model:IsShown()) end
    end
    assert(count == #descriptor.models)
end
local menuOptions = {}
for _, option in ipairs(textureChoice.Dropdown.options) do
    menuOptions[option.value] = option
    local button = Region()
    button.fontString = Region()
    button.AttachTexture = button.CreateTexture
    assert(option.initializer, "Every texture choice must have a visual preview")
    local width, height = option.initializer(button)
    assert(width == 428 and height == 30 and button.children[1]:GetWidth() == 156)
    CheckModelPreview(button, button.children[1], castBar.GetTexture(option.value))
    if option.value == "alchemy" then
        local preview = button.children[1]
        assert(preview:GetTexture() == 4242)
        local left, top, _, bottom, right = preview:GetTexCoord()
        Near(left, 0); Near(right, .5 * 156 / 441)
        Near(top, 0); Near(bottom, .5)
    end
    if option.resetter then option.resetter(button) end
    assert(not button.pyresinCastModelPreview or not button.pyresinCastModelPreview:IsShown(),
        "Releasing a pooled menu button must hide its effects")
end
local reused = Region()
reused.fontString, reused.AttachTexture = Region(), reused.CreateTexture
for _, id in ipairs({ "elva_fel", "alchemy", "elva_galaxy", "elva_void", "elva_fel" }) do
    menuOptions[id].initializer(reused)
    CheckModelPreview(reused, reused.children[#reused.children], castBar.GetTexture(id))
    menuOptions[id].resetter(reused)
end
local modelCount = #modelFrames
menuOptions.elva_fel.initializer(reused)
assert(#modelFrames == modelCount, "Reopening the same menu reuses its model frames")
reused:Hide()
for _, model in pairs(reused.pyresinCastModelPreview.models) do assert(not model:IsVisible()) end
reused:Show()
CheckModelPreview(reused, reused.children[#reused.children], castBar.GetTexture("elva_fel"))
menuOptions.elva_fel.resetter(reused)
assert(textureChoice.Dropdown:GetHeight() == 56 and textureChoice.preview)
assert(not textureChoice.Dropdown.Background:IsShown(), "A two-line selector cannot stretch the native one-line frame")
assert(textureChoice.Dropdown.Text:GetHeight() == 14)
assert(textureChoice.preview.points[1][1] == "TOPLEFT" and textureChoice.preview.points[1][2] == 10)
assert(textureChoice.preview:GetHeight() == 16, "The swatch keeps its vertical padding")
castBar.Set("texture", "alchemy")
assert(textureChoice.preview:GetTexture() == 4242)
Near(textureChoice.preview:GetWidth(), math.min(textureChoice.Dropdown:GetWidth() - 20, 16 * 441 / 18))
Near(select(5, textureChoice.preview:GetTexCoord()), .5 * textureChoice.preview:GetWidth() / (16 * 441 / 18))
castBar.Set("texture", "default")
assert(textureChoice.preview:GetAtlas() == "ui-castingbar-filling-standard")
Near(textureChoice.preview:GetWidth(), textureChoice.Dropdown:GetWidth() - 20)
for _, id in ipairs({ "elva_galaxy", "elva_fel", "alchemy", "elva_void", "default" }) do
    castBar.Set("texture", id)
    CheckModelPreview(textureChoice.Dropdown, textureChoice.preview, castBar.GetTexture(id))
end
local colorMode = Control(labels.castBarColorMode)
colorMode.Dropdown:GenerateMenu()
local custom
for _, option in ipairs(colorMode.Dropdown.options) do
    if option.value == "custom" then custom = option end
end
assert(custom)
custom.select(custom.value)
assert(castBar.Get("colorMode") == "custom")
Tab(labels.castBarLayout)
local size = Control(labels.castBarWidth)
local slider
for _, widget in ipairs(eventFrames) do
    if widget.parent == size and widget.template == "MinimalSliderWithSteppersTemplate" then slider = widget end
end
assert(slider and slider.callbacks.OnValueChanged and slider.sliderValue == 0)
slider.callbacks.OnValueChanged(151) -- Native slider's registered event, not a replaced row method.
assert(castBar.Get("width") == 250 and frame:GetWidth() == 250)
local layouts = EditModeSystemSettingsDialog.layoutCount
slider.Slider.dragging = true
for _, value in ipairs({ 237, 400, 501, 0 }) do
    slider.callbacks.OnValueChanged(value)
    local expected = value == 0 and 0 or value + 99
    assert(castBar.Get("width") == expected)
    assert(frame:GetWidth() == (expected == 0 and 150 or expected))
end
slider.Slider.dragging = false
assert(EditModeSystemSettingsDialog.layoutCount == layouts, "Dragging must not relayout the dialog")
assert(slider.initCount == 1, "Initialize the slider range once, not on every value change")
castBar.RefreshControls()
assert(slider.sliderValue == 0 and slider.initCount == 1, "Automatic must synchronize without reinitializing")
local heightRow = Control(labels.castBarHeight)
local heightSlider
for _, widget in ipairs(eventFrames) do
    if widget.parent == heightRow and widget.template == "MinimalSliderWithSteppersTemplate" then heightSlider = widget end
end
for _, value in ipairs({ 1, 20, 43, 0 }) do
    heightSlider.callbacks.OnValueChanged(value)
    local expected = value == 0 and 0 or value + 5
    assert(castBar.Get("height") == expected and frame:GetHeight() == (expected == 0 and 10 or expected))
end
EditModeSystemSettingsDialog.Settings:SetWidth(390)
EditModeSystemSettingsDialog:UpdateDialog(frame)
assert(panel:GetWidth() == 390 and content:GetWidth() == 366 and slider:GetWidth() == 366)
EditModeSystemSettingsDialog.Settings:SetWidth(343)
EditModeSystemSettingsDialog:UpdateDialog(frame)
assert(panel:GetWidth() == 343 and slider:GetWidth() == 319)
Tab(labels.castBarStyle)
local colorRow, pick
for _, widget in ipairs(eventFrames) do
    if widget:GetText() == labels.castBarPickColor and widget.parent.parent == content
        and widget.parent:IsShown() then
        pick, colorRow = widget, widget.parent
    end
end
assert(colorRow)
assert(pick and pick.scripts.OnClick)
pick.scripts.OnClick(pick)
assert(pickerInfo)
pickerColor = { .3, .4, .5 }
pickerInfo.swatchFunc()
assert(castBar.Get("customColor").r == .3 and frame:GetStatusBarColor() == .3)
pickerInfo.cancelFunc()
assert(castBar.Get("customColor").r == 1 and frame:GetStatusBarColor() == 1)
local resetButton
for _, widget in ipairs(eventFrames) do
    if widget.parent == panel and widget:GetText() == labels.castBarReset then resetButton = widget end
end
assert(resetButton and resetButton.scripts.OnClick)
resetButton.scripts.OnClick(resetButton)
assert(castBar.Get("width") == 0 and castBar.Get("colorMode") == "original")
assert(castBar.IsEnabled() and frame.look == "UNITFRAME" and frame:GetScale() == .85)
assert(not colorRow:IsShown(), "Original colors hide the custom picker")
assert(not Control(labels.castBarWidth):IsShown(), "Inactive tabs do not leave layout holes")
Tab(labels.castBarDetails)
local interruptToggle = Control(labels.castBarCustomInterruptTexture)
assert(not interruptToggle:IsShown(), "Default texture has no custom interruption option")
castBar.Set("texture", "alchemy")
assert(interruptToggle:IsShown() and interruptToggle.Button:GetChecked())
interruptToggle.OnCheckButtonClick(interruptToggle)
assert(not castBar.Get("customInterruptTexture"))
interruptToggle.OnCheckButtonClick(interruptToggle)
assert(castBar.Get("customInterruptTexture"))
assert(not castBar.Set("customInterruptTexture", "false") and not castBar.Set("customInterruptTexture", secret))
for _, descriptor in ipairs(castBar.ModelTextures) do
    castBar.Set("texture", descriptor.id)
    assert(not interruptToggle:IsShown() and castBar.Get("customInterruptTexture"),
        "Model textures hide the inapplicable toggle without changing the saved preference")
end
castBar.Set("texture", "alchemy")
assert(interruptToggle:IsShown() and interruptToggle.Button:GetChecked())
castBar.Set("texture", "default")
assert(not interruptToggle:IsShown())
assert(not Control(labels.castBarLatencyOpacity):IsShown())
local latencyToggle = Control(labels.castBarLatency)
latencyToggle.OnCheckButtonClick(latencyToggle)
assert(Control(labels.castBarLatencyOpacity):IsShown())
local function TextEditor(label)
    for _, widget in ipairs(eventFrames) do
        if widget.parent and widget.parent.parent == content and widget:GetText() == label then
            widget.scripts.OnClick(widget)
            return
        end
    end
    error("Missing text editor " .. label)
end
local function VisibleControl(label)
    for _, widget in ipairs(eventFrames) do
        if widget.parent == content and widget:IsShown() then
            for _, child in ipairs(widget.children) do
                if child:GetText() == label then return widget end
            end
        end
    end
end
local function SelectTextOption(label, value)
    local row = assert(VisibleControl(label))
    row.Dropdown:GenerateMenu()
    for _, option in ipairs(row.Dropdown.options) do
        if option.value == value then option.select(value); return end
    end
    error("Missing text option " .. value)
end
SelectTextOption(labels.castBarTextPosition, "above")
SelectTextOption(labels.castBarTextAlignment, "center")
assert(castBar.Get("namePosition") == "above" and castBar.Get("nameAlignment") == "center")
TextEditor(labels.castBarTimeText)
SelectTextOption(labels.castBarTextPosition, "inside")
SelectTextOption(labels.castBarTextAlignment, "right")
assert(castBar.Get("timePosition") == "inside" and castBar.Get("namePosition") == "above")
local spacingRow = assert(VisibleControl(labels.castBarTextSpacing))
for _, widget in ipairs(eventFrames) do
    if widget.parent == spacingRow and widget.template == "MinimalSliderWithSteppersTemplate" then
        widget.callbacks.OnValueChanged(10)
        assert(castBar.Get("timeSpacing") == 9 and castBar.Get("nameSpacing") == -1)
        widget.callbacks.OnValueChanged(0)
        assert(castBar.Get("timeSpacing") == -1)
    end
end
frame.showCastTimeSetting = false
EditModeSystemSettingsDialog:UpdateDialog(frame)
assert(not Control(labels.castBarTimeFormat):IsShown(), "Native visibility owns time settings")
assert(not VisibleControl(labels.castBarTextPosition))
assert(VisibleControl(labels.castBarTimeHidden), "Hidden time explains the existing native visibility setting")
frame.showCastTimeSetting = true
EditModeSystemSettingsDialog:UpdateDialog(frame)
assert(Control(labels.castBarTimeFormat):IsShown() and VisibleControl(labels.castBarTextPosition))
EditModeSystemSettingsDialog:UpdateDialog(Frame())
assert(not panel:IsShown(), "Controls only appear for the native player cast bar")
do
    castBar.Reset()
    local fullPreview
    for _, widget in ipairs(eventFrames) do
        if widget.fill and widget.border and widget.parent and widget.parent.parent == panel then fullPreview = widget end
    end
    assert(fullPreview, "A complete preview is shared above the tabs")
    Tab(labels.castBarStyle)
    local styles = Control(labels.castBarBorderStyle)
    assert(#styles.buttons == 4)
    styles.buttons[2].button.scripts.OnClick(styles.buttons[2].button)
    assert(castBar.Get("borderStyle") == "thin" and styles.buttons[2].button.selected:IsShown())
    assert(Control(labels.castBarBorderSize):IsShown() and Control(labels.castBarBorderOpacity):IsShown())
    assert(fullPreview.border.lines[1]:IsShown() and not fullPreview.border.lines[5]:IsShown())
    styles.buttons[3].button.scripts.OnClick(styles.buttons[3].button)
    assert(not Control(labels.castBarBorderSize):IsShown() and fullPreview.border.lines[8]:IsShown())
    styles.buttons[4].button.scripts.OnClick(styles.buttons[4].button)
    assert(not Control(labels.castBarBorderColor):IsShown() and not Control(labels.castBarBorderOpacity):IsShown())
    assert(fullPreview.border.art:GetAlpha() == 0)
    for _, line in ipairs(fullPreview.border.lines) do assert(not line:IsShown()) end
    styles.buttons[1].button.scripts.OnClick(styles.buttons[1].button)
    assert(castBar.Get("borderStyle") == "native")
    local colors = Control(labels.castBarBorderColor)
    colors.Dropdown:GenerateMenu()
    for _, option in ipairs(colors.Dropdown.options) do
        if option.value == "custom" then option.select(option.value) end
    end
    local borderPicker
    for _, widget in ipairs(eventFrames) do
        if widget:GetText() == labels.castBarPickColor and widget.parent.parent == content and widget.parent:IsShown() then
            borderPicker = widget
        end
    end
    assert(borderPicker)
    borderPicker.scripts.OnClick(borderPicker)
    pickerColor = { .25, .5, .75 }
    pickerInfo.swatchFunc()
    assert(castBar.Get("borderColor").r == .25 and fullPreview.border.art:IsDesaturated())
    pickerInfo.cancelFunc()
    assert(castBar.Get("borderColor").r == 1 and fullPreview.border.art:GetVertexColor() == 1)
    Tab(labels.castBarLayout)
    castBar.Set("layout", "compact")
    castBar.Set("width", 240)
    castBar.Set("height", 22)
    local icons = Control(labels.castBarIcon)
    assert(#icons.buttons == 6)
    icons.buttons[5].button.scripts.OnClick(icons.buttons[5].button)
    assert(castBar.Get("icon") == "inside_left" and not Control(labels.castBarIconGap):IsShown())
    assert(fullPreview.fill:GetWidth() == 217 and frame:GetWidth() == 217)
    assert(fullPreview.divider:IsShown() and not fullPreview.iconBounds:IsShown())
    assert(fullPreview.name:GetWidth() == frame.Text:GetWidth(), "Preview and live labels reserve the same space")
    local previousLayouts = EditModeSystemSettingsDialog.layoutCount
    slider.Slider.dragging = true
    slider.callbacks.OnValueChanged(221) -- Width 320, including the 23px icon slot.
    assert(fullPreview.fill:GetWidth() == 297 and frame:GetWidth() == 297)
    assert(EditModeSystemSettingsDialog.layoutCount == previousLayouts)
    slider.Slider.dragging = false
    icons.buttons[6].button.scripts.OnClick(icons.buttons[6].button)
    assert(fullPreview.icon.points[1][1] == "LEFT" and frame.Icon.points[1][1] == "LEFT")
    icons.buttons[3].button.scripts.OnClick(icons.buttons[3].button)
    assert(Control(labels.castBarIconGap):IsShown() and fullPreview.fill:GetWidth() == 320)
    castBar.Set("iconGap", 12)
    assert(select(4, fullPreview.icon:GetPoint(1)) == -12 and select(4, frame.Icon:GetPoint(1)) == -12)
    icons.buttons[2].button.scripts.OnClick(icons.buttons[2].button)
    assert(not fullPreview.icon:IsShown() and not Control(labels.castBarIconGap):IsShown())
    castBar.Reset()
    assert(not frame.pyresinCastPresentation.bounds:IsShown(), "Reset restores native presentation, not equivalent overrides")
    frame:UpdateIconShown()
    assert(frame.Icon:GetWidth() == 16, "Native callbacks after Reset cannot reapply a stale integrated layout")
end

print("PASS: cast-bar ui")
