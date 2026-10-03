local _, ns = ...

ns.RegisterModule("actionBars", function(module)
    local config, L = ns.ActionBars, ns.L
    local dialog, panel, selected, refresh
    local changingSlider

    local function available()
        return module.active and PyresinQoLDB.modules[module.id] and not InCombatLockdown()
    end

    local function setting(suffix)
        return selected and config.settings and config.settings[selected.prefix .. suffix]
    end

    local function set(suffix, value)
        local option = setting(suffix)
        if available() and option then option:SetValue(value) end
    end

    local function install()
        if dialog or not EditModeSystemSettingsDialog then return end
        dialog = EditModeSystemSettingsDialog
        panel = CreateFrame("Frame", nil, dialog)
        panel:SetSize(343, 60)
        panel:Hide()

        local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 0, -2)
        heading:SetText("PyresinQoL - " .. L.actionBarVisibility)
        local divider = panel:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", 0, 5)
        divider:SetPoint("TOPRIGHT", 0, 5)
        divider:SetHeight(1)
        divider:SetColorTexture(.6, .5, .3, .35)

        local enable = CreateFrame("Frame", nil, panel, "EditModeSettingCheckboxTemplate")
        enable:SetPoint("TOPLEFT", 0, -22)
        enable.Label:SetFontObject("GameFontHighlight")
        enable.Label:SetJustifyH("LEFT")
        enable.Label:SetText(L.actionBarEnabled)
        enable.OnCheckButtonClick = function()
            if selected then set("Enabled", not config.Get(selected.prefix .. "Enabled")) end
        end
        enable.OnEnter = function(row)
            GameTooltip:SetOwner(row.Button, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.actionBarVisibilityHelp, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end
        enable.OnLeave = function() GameTooltip:Hide() end
        enable:Show()

        local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -62)
        scroll:SetPoint("BOTTOMRIGHT", -24, 26)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(319)
        scroll:SetScrollChild(content)
        local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 0, 6)
        hint:SetText(L.actionBarSavedImmediately)
        local rows, height = {}, 0

        local function row(template, size)
            local frame = CreateFrame("Frame", nil, content, template)
            frame:SetPoint("TOPLEFT", 0, -height)
            frame:SetSize(content:GetWidth(), size)
            frame.fixedWidth, frame.fixedHeight = content:GetWidth(), size
            frame:Show()
            height = height + size
            rows[#rows + 1] = frame
            return frame
        end

        local function checkbox(suffix)
            local control = row("EditModeSettingCheckboxTemplate", 36)
            control.Label:SetFontObject("GameFontHighlight")
            control.Label:SetJustifyH("LEFT")
            control.Label:SetWordWrap(true)
            control.Label:SetText(L["actionBar" .. suffix])
            control.OnCheckButtonClick = function()
                if selected then set(suffix, not config.Get(selected.prefix .. suffix)) end
            end
            control.Refresh = function()
                control.Button:SetChecked(config.Get(selected.prefix .. suffix))
                control.Button:SetEnabled(available())
            end
        end

        for _, suffix in ipairs({ "HideCombat", "HideOutOfCombat", "HideStealth", "HideNotStealth",
            "HideForm", "HideNoForm", "Mouseover" }) do checkbox(suffix) end

        local function opacity(suffix)
            local control = row(nil, 56)
            local label = control:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("TOPLEFT", 0, -2)
            label:SetText(L["actionBar" .. suffix])
            local valueLabel = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            valueLabel:SetPoint("TOPRIGHT", 0, -2)
            local slider = CreateFrame("Frame", nil, control, "MinimalSliderWithSteppersTemplate")
            slider:SetPoint("TOPLEFT", 0, -22)
            slider:SetSize(content:GetWidth(), 32)
            slider:Init(100, 0, 100, 100)
            control.slider = slider
            control.handles = EventUtil.CreateCallbackHandleContainer()
            control.handles:RegisterCallback(slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged,
                function(_, value)
                    if control.initializing then return end
                    value = math.floor(value + .5)
                    changingSlider = true
                    set(suffix, value / 100)
                    changingSlider = nil
                    valueLabel:SetText(("%d%%"):format(value))
                end, control)
            control.Refresh = function()
                local value = math.floor(config.Get(selected.prefix .. suffix) * 100 + .5)
                valueLabel:SetText(("%d%%"):format(value))
                slider:SetEnabled(available())
                if slider.Slider:IsDraggingThumb() then return end
                control.initializing = true
                slider:SetValue(value)
                control.initializing = false
            end
        end
        opacity("AlphaNormal")
        opacity("AlphaCombat")

        local condition = row(nil, 34)
        local edit = CreateFrame("Button", nil, condition, "UIPanelButtonTemplate")
        edit:SetPoint("TOPLEFT")
        edit:SetPoint("TOPRIGHT")
        edit:SetHeight(26)
        edit:SetText(L.actionBarEditCondition)
        edit:SetScript("OnClick", function()
            local option = setting("CustomCondition")
            if available() and option then
                StaticPopup_Show("PYRESINQOL_ACTIONBAR_CONDITION", L[selected.label], nil, {
                    key = selected.prefix .. "CustomCondition", setting = option,
                })
            end
        end)
        edit:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.actionBarCustomConditionHelp, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        edit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        condition.Refresh = function() edit:SetEnabled(available()) end
        content:SetHeight(height)

        refresh = function()
            if changingSlider or not selected or not panel:IsShown() then return end
            local width = dialog.Settings:GetWidth()
            if width <= 24 then width = 343 end
            panel:SetWidth(width)
            content:SetWidth(width - 24)
            enable.fixedWidth = width
            enable.Label:SetWidth(width - 32)
            enable.Button:SetChecked(config.Get(selected.prefix .. "Enabled"))
            enable.Button:SetEnabled(available())
            local enabled = config.Get(selected.prefix .. "Enabled")
            scroll:SetShown(enabled)
            hint:SetShown(enabled)
            for _, control in ipairs(rows) do
                control.fixedWidth = content:GetWidth()
                control:SetWidth(content:GetWidth())
                if control.Label then control.Label:SetWidth(content:GetWidth() - 32) end
                if control.slider then control.slider:SetWidth(content:GetWidth()) end
                control.Refresh()
            end
            local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale() / dialog:GetEffectiveScale()
            local room = screenHeight * .9 - dialog.Settings:GetHeight() - dialog.Buttons:GetHeight() - 168
            panel:SetHeight(enabled and (math.min(height, math.max(80, math.min(240, room))) + 88) or 58)
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, height - scroll:GetHeight())))
            dialog:Layout()
        end

        hooksecurefunc(dialog, "UpdateDialog", function(self, frame)
            if frame ~= self.attachedToSystem then return end
            local nextBar
            for _, bar in ipairs(config.bars) do
                if frame and frame == _G[bar.frame] then nextBar = bar; break end
            end
            if selected ~= nextBar then scroll:SetVerticalScroll(0) end
            selected = nextBar
            if not selected or not available() then
                if panel:IsShown() then panel:Hide(); self:Layout() end
                return
            end
            -- Keep addon controls separate from the native setting IDs and frame pools.
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", self.Settings, "BOTTOMLEFT", 0, -12)
            self.Buttons:ClearAllPoints()
            self.Buttons:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -12)
            panel:Show()
            refresh()
        end)
        dialog:HookScript("OnHide", function() selected = nil; panel:Hide() end)
    end

    local update = module.UpdateActionBars
    function module.UpdateActionBars()
        if update then update() end
        if refresh then refresh() end
    end

    function module.ConfigureActionBars()
        if not available() then return end
        if not EditModeManagerFrame then C_AddOns.LoadAddOn("Blizzard_EditMode") end
        install()
        if not EditModeManagerFrame or not MainActionBar then return end
        if PyresinQoLSettingsFrame then PyresinQoLSettingsFrame:Hide() end
        ShowUIPanel(EditModeManagerFrame)
        if EditModeManagerFrame:IsShown() then EditModeManagerFrame:SelectSystem(MainActionBar) end
    end

    install()
    if not dialog then
        local loader = CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent", function(self, _, addon)
            if addon == "Blizzard_EditMode" then self:UnregisterEvent("ADDON_LOADED"); install() end
        end)
    end
end)
