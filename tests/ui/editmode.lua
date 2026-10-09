local UI = PyresinQoLUITest
local setting, original, startWidth
local dialog = EditModeSystemSettingsDialog

local function WidthSlider()
    local found
    for _, child in ipairs({ dialog.Settings:GetChildren() }) do
        if child:IsShown() and child.setting == Enum.EditModeSwingTimerSetting.Width then
            assertEquals(nil, found, "Exactly one visible width slider")
            found = child
        end
    end
    return assert(found, "Missing width slider")
end

local barSizeWidth, dialogWidth, dialogHeight
local function BarSizeSlider()
    for slider in dialog.pools:EnumerateActiveByTemplate("EditModeSettingSliderTemplate") do
        if slider:IsShown() and slider.setting == Enum.EditModeCastBarSetting.BarSize then return slider end
    end
    error("Missing Bar Size slider")
end
local function PixelLabel(slider)
    for _, region in ipairs({ slider:GetRegions() }) do
        local text = region:IsObjectType("FontString") and region:GetText()
        if text and text:find(" px$") then return region end
    end
    error("Missing pixel label")
end
local function MeasuredPixels(frame)
    return ("%d px"):format(math.floor(frame:GetWidth() * frame:GetEffectiveScale()
        / PixelUtil.GetPixelToUIUnitFactor() + 0.5))
end

UI.Flow("pixel-perfect Edit Mode swaps coarse size sliders and measures percent sliders", {
    function()
        setting = Settings.GetSetting("PyresinQoL_PixelPerfectEditMode")
        original = setting:GetValue()
        setting:SetValue(false)
        ShowUIPanel(EditModeManagerFrame)
    end,
    function()
        assertTrue(EditModeManagerFrame:IsEditModeActive())
        EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
    end,
    function()
        dialogWidth, dialogHeight = dialog:GetSize()
        setting:SetValue(true)
    end,
    function()
        assertEquals(PlayerCastingBarFrame, dialog.attachedToSystem)
        local width, height = dialog:GetSize()
        assertEquals(dialogWidth, width, "Pixel labels must not change the dialog layout")
        assertEquals(dialogHeight, height, "Pixel labels must not change the dialog layout")
        local slider = BarSizeSlider()
        assertEquals(10, slider.Slider.Slider:GetValueStep(), "Percent sliders keep Blizzard's steps")
        local label = PixelLabel(slider)
        assertEquals(MeasuredPixels(PlayerCastingBarFrame), label:GetText())
        UI.AssertInside(label, dialog, "Pixel label")
        barSizeWidth = label:GetText()
        slider.Slider.Forward:Click()
    end,
    function()
        local label = PixelLabel(BarSizeSlider())
        assertEquals(MeasuredPixels(PlayerCastingBarFrame), label:GetText())
        assertTrue(label:GetText() ~= barSizeWidth, "Pixel label follows the resized frame")
        dialog.Buttons.RevertChangesButton:Click()
        EditModeManagerFrame:SelectSystem(SwingTimerMainHandFrame)
    end,
    function()
        assertEquals(SwingTimerMainHandFrame, dialog.attachedToSystem)
        local slider = WidthSlider()
        assertEquals(1, slider.Slider.Slider:GetValueStep())
        UI.AssertInside(slider, dialog, "Width slider")
        startWidth = SwingTimerMainHandFrame:GetWidth()
        assertEquals(("%d"):format(startWidth), slider.Slider.RightText:GetText())
        slider.Slider.Forward:Click()
    end,
    function()
        assertEquals(startWidth + 1, SwingTimerMainHandFrame:GetWidth())
        assertEquals(("%d"):format(startWidth + 1), WidthSlider().Slider.RightText:GetText())
        assertTrue(dialog.Buttons.RevertChangesButton:IsEnabled())
        setting:SetValue(false)
    end,
    function()
        assertEquals(10, WidthSlider().Slider.Slider:GetValueStep(), "Disabled mode keeps Blizzard's slider")
    end,
}, function()
    if dialog.attachedToSystem then dialog.Buttons.RevertChangesButton:Click() end
    HideUIPanel(EditModeManagerFrame)
    if setting then setting:SetValue(original) end
end)

-- Regression: the player frame pads its art, so Match width must compare visible selections.
local castOriginal, castEnabledOriginal
local function VisibleWidth(frame)
    return frame.Selection:GetWidth() * frame:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
end
UI.Flow("pixel-perfect Match width gives the customized cast bar the target's visible width", {
    function()
        setting = Settings.GetSetting("PyresinQoL_PixelPerfectEditMode")
        original = setting:GetValue()
        castOriginal = PyresinQoLDB.castBar and CopyTable(PyresinQoLDB.castBar)
        castEnabledOriginal = PyresinQoLDB.castBarCustomization
        setting:SetValue(true)
        ShowUIPanel(EditModeManagerFrame)
    end,
    function() EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame) end,
    function()
        local enable = UI.Checkbox(dialog, "Customize cast bar")
        if not enable:GetChecked() then enable:Click() end
        UI.OpenMenu(UI.Find(PyresinQoLPixelPerfect, function(frame) return frame.OpenMenu end))
    end,
    function()
        -- The player frame option sits in the menu's scrolled-out part; select the rendered option directly.
        local dropdown = UI.Find(PyresinQoLPixelPerfect, function(frame) return frame.OpenMenu end)
        local option = assert(UI.Find(dropdown.menu, function(frame)
            local label = frame.fontString or frame.Text
            return frame.GetElementDescription and label and label.GetText and label:GetText() == PlayerFrame:GetSystemName()
        end), "Missing player frame option")
        option:Click()
    end,
    function()
        UI.Click(UI.Button(PyresinQoLPixelPerfect, "Match width"), PyresinQoLPixelPerfect, "Match width")
    end,
    function()
        local target = PlayerFrame
        assertTrue(target:GetWidth() > target.Selection:GetWidth(), "The player frame pads its visible art")
        local scale = PlayerCastingBarFrame:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
        assertTrue(math.abs(VisibleWidth(PlayerCastingBarFrame) - VisibleWidth(target)) <= scale / 2 + 1e-6,
            "Visible widths differ: " .. VisibleWidth(PlayerCastingBarFrame) .. " vs " .. VisibleWidth(target))
    end,
}, function()
    HideUIPanel(EditModeManagerFrame)
    PyresinQoLDB.castBar = castOriginal
    PyresinQoLDB.castBarCustomization = castEnabledOriginal
    if setting then setting:SetValue(original) end
end)
