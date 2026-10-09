local UI = PyresinQoLUITest
local display, saved = PyresinQoLFlightTimer, {}
local keys = { "Style", "Marker", "Time", "Flags", "Overlap", "Zones", "ScrollNames", "Stops", "StopArrows", "ShowPost",
    "Scale" }
local pixelPerfect, pixelPerfectOriginal
local function Setting(key) return Settings.GetSetting("PyresinQoL_FlightTimer" .. key) end

UI.Flow("flight timer Edit Mode options restyle the preview from their own dialog", {
    function()
        for _, key in ipairs(keys) do saved[key] = Setting(key):GetValue() end
        pixelPerfect = Settings.GetSetting("PyresinQoL_PixelPerfectEditMode")
        pixelPerfectOriginal = pixelPerfect:GetValue()
        pixelPerfect:SetValue(true)
        ShowUIPanel(EditModeManagerFrame)
    end,
    function()
        assertTrue(display:IsVisible(), "Edit Mode previews a flight")
        EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
    end,
    function()
        display.Selection:GetScript("OnMouseDown")(display.Selection)
    end,
    function()
        local dialog = assert(display.Dialog, "Selecting the timer opens its options")
        assertTrue(dialog:IsVisible())
        assertFalse(EditModeSystemSettingsDialog:IsShown(), "One selection at a time")
        assertTrue(PyresinQoLPixelPerfect:IsShown(), "The position editor opens with the options")
        UI.AssertInside(dialog, UIParent, "Flight timer options")
        for _, row in ipairs({ dialog:GetChildren() }) do
            for _, slider in ipairs({ row:GetChildren() }) do
                if slider.RightText then UI.AssertInside(slider.RightText, dialog, "Slider value") end
            end
            if row.Label and row.Label.IsTruncated then assertFalse(row.Label:IsTruncated(), row.Label:GetText()) end
        end
        -- Every combination the dialog offers builds without errors and stays on screen.
        for _, style in ipairs({ "castbar", "swing", "breath", "minimal" }) do
            Setting("Style"):SetValue(style)
            for _, marker in ipairs({ "pointed", "round", "mount", "name", "none" }) do
                Setting("Marker"):SetValue(marker)
                for _, flags in ipairs({ "both", "departure", "destination", "none" }) do Setting("Flags"):SetValue(flags) end
                Setting("Zones"):SetValue(false)
                Setting("Zones"):SetValue(true)
                for _, overlap in ipairs({ "ends", "marker", "both", "none" }) do Setting("Overlap"):SetValue(overlap) end
                for _, stops in ipairs({ "off", "scroll", "fixed" }) do
                    Setting("Stops"):SetValue(stops)
                    Setting("StopArrows"):SetValue(false)
                    Setting("StopArrows"):SetValue(true)
                    Setting("ShowPost"):SetValue(false)
                    Setting("ShowPost"):SetValue(true)
                    Setting("ScrollNames"):SetValue(false)
                    Setting("ScrollNames"):SetValue(true)
                end
            end
        end
        -- The scale scales the whole timer, width and all; the mover follows.
        local width, height = display:GetWidth(), display:GetHeight()
        Setting("Scale"):SetValue(200)
        assertTrue(math.abs(display:GetWidth() - 2 * width) < 0.5 and math.abs(display:GetHeight() - 2 * height) < 0.5,
            "The mover grows with the scale")
        UI.AssertInside(display, UIParent, "Flight timer at 200%")
        Setting("Scale"):SetValue(100)
        Setting("Stops"):SetValue("off")
        Setting("Time"):SetValue("off")
        UI.AssertInside(display, UIParent, "Flight timer")
        EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
    end,
    function()
        assertFalse(display.Dialog:IsShown(), "Selecting a Blizzard frame closes the options")
        HideUIPanel(EditModeManagerFrame)
    end,
    function()
        assertFalse(display:IsShown(), "Leaving Edit Mode ends the preview")
        assertFalse(display.Dialog:IsShown())
    end,
}, function()
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
    for key, value in pairs(saved) do Setting(key):SetValue(value) end
    if pixelPerfect then pixelPerfect:SetValue(pixelPerfectOriginal) end
end)

-- Our mover snaps on drop like Blizzard's and takes a snap target's width through its width option.
local position, snap, width
UI.Flow("flight timer mover snaps on drop and matches a snap target's width", {
    function()
        position, snap, width = PyresinQoLDB.flightTimerPosition, EditModeManagerFrame:IsSnapEnabled(), Setting("Width"):GetValue()
        pixelPerfect = Settings.GetSetting("PyresinQoL_PixelPerfectEditMode")
        pixelPerfectOriginal = pixelPerfect:GetValue()
        pixelPerfect:SetValue(true)
        ShowUIPanel(EditModeManagerFrame)
        EditModeManagerFrame:SetEnableSnap(true)
    end,
    function()
        display.Selection:GetScript("OnMouseDown")(display.Selection)
        display.Selection:GetScript("OnDragStart")(display.Selection)
        display:ClearAllPoints()
        display:SetPoint("CENTER", UIParent, "CENTER", 3, 200)
        display.Selection:GetScript("OnUpdate")(display.Selection) -- draws the preview lines
        display.Selection:GetScript("OnDragStop")(display.Selection)
        assertTrue(math.abs(display:GetCenter() - UIParent:GetCenter()) < 0.01, "Drops onto the screen centre")
        UI.OpenMenu(UI.Find(PyresinQoLPixelPerfect, function(frame) return frame.OpenMenu end))
    end,
    function()
        local dropdown = UI.Find(PyresinQoLPixelPerfect, function(frame) return frame.OpenMenu end)
        assert(UI.Find(dropdown.menu, function(frame)
            local label = frame.fontString or frame.Text
            return frame.GetElementDescription and label and label.GetText and label:GetText() == PlayerFrame:GetSystemName()
        end), "Missing player frame option"):Click()
    end,
    function()
        UI.Click(UI.Button(PyresinQoLPixelPerfect, "Match width"), PyresinQoLPixelPerfect, "Match width")
    end,
    function()
        assertTrue(math.abs(display:GetWidth() - PlayerFrame.Selection:GetWidth() * PlayerFrame:GetEffectiveScale()
            / display:GetEffectiveScale()) <= 1, "Takes the player frame's visible width")
    end,
}, function()
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
    EditModeManagerFrame:SetEnableSnap(snap)
    PyresinQoLDB.flightTimerPosition = position
    if width then Setting("Width"):SetValue(width) end
    if pixelPerfect then pixelPerfect:SetValue(pixelPerfectOriginal) end
end)

-- The dialog's own controls write the settings: a checkbox, a dropdown option and a slider stepper.
local controlsSaved = {}
local function Row(text)
    return assert(UI.Find(display.Dialog, function(frame)
        return frame.Label and frame.Label.GetText and frame.Label:GetText() == text
    end), "Missing row: " .. text)
end
local function Dropdown(text)
    return assert(UI.Find(Row(text), function(frame) return frame.OpenMenu end))
end
UI.Flow("flight timer dialog controls write their settings", {
    function()
        for _, key in ipairs({ "Zones", "Time", "Width" }) do controlsSaved[key] = Setting(key):GetValue() end
        ShowUIPanel(EditModeManagerFrame)
    end,
    function()
        display.Selection:GetScript("OnMouseDown")(display.Selection)
    end,
    function()
        local _, _, rise = display:GetClampRectInsets()
        assertTrue(rise > 0, "The screen clamp covers the marker over the frame")
        UI.Click(UI.Checkbox(display.Dialog, "Show zone names"), display.Dialog, "Zone names")
        assertFalse(Setting("Zones"):GetValue())
        local width = Setting("Width"):GetValue()
        UI.Click(UI.Find(Row("Width"), function(frame) return frame.Forward end).Forward, display.Dialog, "Width stepper")
        assertEquals(width + 1, Setting("Width"):GetValue())
        UI.OpenMenu(Dropdown("Time"))
    end,
    function()
        UI.SelectMenu(Dropdown("Time"), "Remaining / total")
        assertEquals("total", Setting("Time"):GetValue())
    end,
}, function()
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
    for key, value in pairs(controlsSaved) do Setting(key):SetValue(value) end
end)
