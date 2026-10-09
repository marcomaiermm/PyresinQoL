local UI = PyresinQoLUITest
local display, saved = PyresinQoLFlightTimer, {}
local keys = { "Style", "Marker", "Flags", "Overlap", "ShowStops", "Stops", "StopArrows", "ShowPost", "ShowTime" }
local function Setting(key) return Settings.GetSetting("PyresinQoL_FlightTimer" .. key) end

UI.Flow("flight timer Edit Mode options restyle the preview from their own dialog", {
    function()
        for _, key in ipairs(keys) do saved[key] = Setting(key):GetValue() end
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
        UI.AssertInside(dialog, UIParent, "Flight timer options")
        -- Every combination the dialog offers builds without errors and stays on screen.
        for _, style in ipairs({ "castbar", "swing", "breath", "minimal" }) do
            Setting("Style"):SetValue(style)
            for _, marker in ipairs({ "pointed", "round", "name", "none" }) do
                Setting("Marker"):SetValue(marker)
                for _, flags in ipairs({ "both", "departure", "destination", "none" }) do Setting("Flags"):SetValue(flags) end
                for _, overlap in ipairs({ "ends", "marker", "both", "none" }) do Setting("Overlap"):SetValue(overlap) end
                for _, stops in ipairs({ "scroll", "fixed" }) do
                    Setting("Stops"):SetValue(stops)
                    Setting("StopArrows"):SetValue(false)
                    Setting("StopArrows"):SetValue(true)
                    Setting("ShowPost"):SetValue(false)
                    Setting("ShowPost"):SetValue(true)
                end
            end
        end
        Setting("ShowStops"):SetValue(false)
        Setting("ShowTime"):SetValue(false)
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
end)
