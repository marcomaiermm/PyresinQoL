local _, ns = ...
local L = ns.L

-- The flight timer in Edit Mode: a draggable mover like the FPS / MS display, a preview flight, and the
-- options dialog of the selected timer.
ns.RegisterModule("flightTimer", function(module)
    local display, Get = module.flightTimerDisplay, module.GetFlightTimerOption
    local name = "PyresinQoL · " .. L.flightTimer
    local dialog

    -- The dialog is built like Blizzard's system settings dialog. It writes through the registered
    -- settings (Settings.lua), so the settings page follows.
    local function SetOption(option, value)
        option.setting:SetValue(value)
        dialog:Refresh()
    end

    local function Row(option, template)
        local row = CreateFrame("Frame", nil, dialog, template)
        row:SetSize(330, 32)
        if not template then
            row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
            row.Label:SetPoint("LEFT")
            row.Label:SetWidth(110)
            row.Label:SetJustifyH("LEFT")
        end
        row.Label:SetText(option.label)
        return row
    end

    local function CreateDialog()
        dialog = CreateFrame("Frame", nil, UIParent)
        display.Dialog = dialog
        dialog:SetFrameStrata("DIALOG")
        dialog:SetFrameLevel(200)
        dialog:SetClampedToScreen(true)
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        dialog:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 200) -- Blizzard's default spot
        dialog:Hide()
        CreateFrame("Frame", nil, dialog, "DialogBorderTranslucentTemplate"):SetAllPoints()
        local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText(name)
        local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        close:SetScript("OnClick", function() dialog:Hide() end)
        dialog:SetScript("OnHide", function()
            if display.Selection:IsShown() then display.Selection:ShowHighlighted() end
        end)

        local rows, y = {}, -44
        for _, option in ipairs(module.flightTimerOptions) do
            if option.section then y = y - 10 end
            local row
            if option.choices then
                row = Row(option)
                local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                dropdown:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
                dropdown:SetWidth(215)
                dropdown:SetupMenu(function(_, root)
                    for _, choice in ipairs(option.choices) do
                        local value = choice[1]
                        root:CreateRadio(choice[2], function() return Get(option.key) == value end,
                            function() SetOption(option, value) end)
                    end
                end)
                row.Refresh = function() dropdown:GenerateMenu() end
                row.SetEnabled = function(_, enabled) dropdown:SetEnabled(enabled) end
            elseif option.min then
                row = Row(option)
                local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
                slider:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
                slider:SetSize(160, 32) -- its value text sits right of it
                local step = option.step or 1
                slider:Init(Get(option.key), option.min, option.max, (option.max - option.min) / step, {
                    [MinimalSliderWithSteppersMixin.Label.Right] = function(value) return module.FormatFlightTimerOption(option, value) end,
                })
                slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                    if not row.refreshing then SetOption(option, math.floor(value / step + 0.5) * step) end
                end, row)
                row.SetEnabled = function(_, enabled) slider:SetEnabled(enabled) end
                row.Refresh = function()
                    row.refreshing = true
                    slider:SetValue(Get(option.key))
                    slider:FormatValue(Get(option.key)) -- a new scale changes the width's text alone
                    row.refreshing = false
                end
            else
                row = Row(option, "EditModeSettingCheckboxTemplate")
                row.OnCheckButtonClick = function() SetOption(option, not Get(option.key)) end
                row.Refresh = function() row.Button:SetChecked(Get(option.key)) end
                row.SetEnabled = function(_, enabled) row.Button:SetEnabled(enabled) end
            end
            row:SetPoint("TOPLEFT", 20, y)
            row:Show()
            row.option = option
            rows[#rows + 1] = row
            y = y - 34
        end
        dialog:SetSize(370, 20 - y)
        function dialog:Refresh()
            for _, row in ipairs(rows) do
                row.Refresh()
                -- Children of an option that is off grey out, as Blizzard's own checkboxes do.
                if row.option.parent then
                    local enabled = module.FlightTimerOptionEnabled(row.option, Get)
                    row:SetEnabled(enabled)
                    row.Label:SetFontObject(enabled and "GameFontHighlightMedium" or "GameFontDisableMed2")
                    row.Label:SetJustifyH("LEFT") -- a font object brings its own
                end
            end
        end
        -- A profile switch changes every value under the open dialog.
        EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", function()
            if dialog:IsShown() then dialog:Refresh() end
        end, dialog)
        -- One selection at a time: picking a Blizzard frame closes this dialog.
        EditModeSystemSettingsDialog:HookScript("OnShow", function() dialog:Hide() end)
    end

    local widthOption
    for _, option in ipairs(module.flightTimerOptions) do
        if option.key == "flightTimerWidth" then widthOption = option end
    end
    local entry = ns.CreateEditModeDisplay(display, {
        name = name, positionKey = "flightTimerPosition", default = { "CENTER", UIParent, "CENTER", 0, 250 },
        OnSelect = function()
            if not dialog then CreateDialog() end
            -- The pixel-perfect editor deselects Blizzard's frame itself; clearing again would close it.
            if not ns.GetModule("editMode").TogglePixelPerfectFrame then EditModeManagerFrame:ClearSelectedSystem() end
            dialog:Show()
            dialog:Refresh()
        end,
        width = { Get = function() return Get(widthOption.key) end, min = widthOption.min, max = widthOption.max,
            Set = function(value) widthOption.setting:SetValue(value); if dialog then dialog:Refresh() end end,
            Scale = function() return Get("flightTimerScale") / 100 end },
        OnEnter = function() module.SetFlightTimerPreview(true) end,
        OnExit = function() module.SetFlightTimerPreview(false) end,
    })
    -- The options go with the mover: on leaving Edit Mode and in combat.
    display.Selection:HookScript("OnHide", function() if dialog then dialog:Hide() end end)
    entry.Restore()
end)
