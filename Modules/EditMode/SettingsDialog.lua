local _, ns = ...

-- Pixel-perfect additions to Blizzard's Edit Mode settings dialog. Changes still flow through the
-- native sliders' setting path, so Save, Revert and the dirty state behave exactly as before.
ns.RegisterModule("editMode", function(module)
    local dialog = EditModeSystemSettingsDialog
    local sliderTemplate = "EditModeSettingSliderTemplate"
    -- Percent settings that resize the whole frame; their saved step index cannot hold finer values.
    local resizingKeys = { Size = true, Scale = true, BarSize = true, FrameSize = true, BarWidth = true,
        BarWidthScale = true, OverallSize = true, IconSize = true }
    local resizingBySystem, unitDisplayInfo = {}, {}
    local unitSliders, pixelLabels = {}, {}
    local coarseSliders, percentSliders = {}, {}
    local measurePending = false

    local function Clear(list)
        for index = #list, 1, -1 do list[index] = nil end
    end

    -- Saves every whole unit but steps coarser or hides its value in Blizzard's slider.
    local function IsCoarse(info)
        return info.type == Enum.EditModeSettingDisplayType.Slider and ((info.stepSize or 1) > 1 or info.hideValue)
            and info:ConvertValue(info.minValue + 1) - info:ConvertValue(info.minValue) == 1
    end

    -- Dialog refreshes repeat on every slider tick, so resolve each system's enum names only once.
    local function IsResizing(system, setting)
        local resizing = resizingBySystem[system]
        if not resizing then
            resizing = {}
            for name, id in pairs(Enum.EditModeSystem) do
                local settings = id == system and Enum["EditMode" .. name .. "Setting"]
                if settings then
                    for key, value in pairs(settings) do
                        if resizingKeys[key] then resizing[value] = true end
                    end
                end
            end
            resizingBySystem[system] = resizing
        end
        return resizing[setting]
    end

    local function FormatUnits(value) return ("%d"):format(math.floor(value + 0.5)) end

    local function CreateUnitSlider()
        local slider = CreateFrame("Frame", nil, dialog.Settings, sliderTemplate)
        -- While dragging, stick to the snap target's size like Blizzard's frame magnetism.
        -- Steppers never snap, so single units next to the target stay reachable.
        slider.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if not slider.Slider.Slider:IsDraggingThumb() or not EditModeManagerFrame:IsSnapEnabled() then return end
            local frame = dialog.attachedToSystem
            local axis = module.GetSizeAxis(frame, slider.setting)
            local units = axis and module.GetSnapTargetUnits(frame, axis, frame:GetSettingValue(slider.setting))
            if units and units ~= value and math.abs(units - value) <= EditModeMagnetismManager.magnetismRange then
                slider.Slider:SetValue(units)
            end
        end, {})
        return slider
    end

    -- Swap in an identical template slider with one-unit steps and a visible value.
    local function ReplaceSlider(slider, native, systemFrame)
        local info = systemFrame.settingDisplayInfoMap[native.setting]
        unitDisplayInfo[info] = unitDisplayInfo[info] or setmetatable(
            { stepSize = 1, hideValue = false, minText = false, maxText = false, formatter = FormatUnits },
            { __index = info })
        native:Hide()
        slider.layoutIndex = native.layoutIndex
        slider:ClearAllPoints()
        slider:SetPoint("TOPLEFT")
        slider:Show()
        slider:SetupSetting({ displayInfo = unitDisplayInfo[info], settingName = native.Label:GetText(),
            currentValue = systemFrame:GetSettingValue(native.setting) })
    end

    local function ShowPixelLabel(native)
        local label = pixelLabels[native]
        if not label then
            label = native:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("TOP", native.Slider.RightText, "BOTTOM", 0, -1)
            pixelLabels[native] = label
        end
        label:Show()
    end

    local function MeasureFrame()
        measurePending = false
        local frame = dialog.attachedToSystem
        if not frame or not percentSliders[1] then return end
        local pixels = frame:GetWidth() * frame:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
        local text = ("%d px"):format(math.floor(pixels + 0.5))
        for _, native in ipairs(percentSliders) do pixelLabels[native]:SetText(text) end
    end

    hooksecurefunc(dialog, "UpdateSettings", function(_, systemFrame)
        if systemFrame ~= dialog.attachedToSystem then return end
        Clear(coarseSliders); Clear(percentSliders)
        for _, label in pairs(pixelLabels) do label:Hide() end
        if PyresinQoLDB.pixelPerfectEditMode then
            for native in dialog.pools:EnumerateActiveByTemplate(sliderTemplate) do
                local info = native:IsShown() and systemFrame.settingDisplayInfoMap[native.setting]
                -- Direct size sliders are swapped even at one-unit steps, so dragging can snap to the target.
                if info and (IsCoarse(info) or module.GetSizeAxis(systemFrame, native.setting)) then
                    coarseSliders[#coarseSliders + 1] = native
                elseif info and info.formatter and IsResizing(systemFrame.system, native.setting) then
                    ShowPixelLabel(native)
                    percentSliders[#percentSliders + 1] = native
                end
            end
        end
        for index = 1, math.max(#coarseSliders, #unitSliders) do
            local native = coarseSliders[index]
            if native then
                unitSliders[index] = unitSliders[index] or CreateUnitSlider()
                ReplaceSlider(unitSliders[index], native, systemFrame)
            else
                unitSliders[index]:Hide()
            end
        end
        dialog.Settings:Layout()
        -- Blizzard refreshes this dialog before the frame applies its new size, so measure next frame.
        if percentSliders[1] and not measurePending then
            measurePending = true
            C_Timer.After(0, MeasureFrame)
        end
    end)

    -- Toggling the option with the dialog open swaps the sliders immediately.
    function module.UpdateSettingsDialog()
        if dialog:IsShown() and dialog.attachedToSystem then dialog:UpdateDialog(dialog.attachedToSystem) end
    end
end)
