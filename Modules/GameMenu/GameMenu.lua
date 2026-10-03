local _, ns = ...

ns.RegisterModule("gameMenu", function(module)
    local L = ns.L

    -- Native layout and controller navigation must never traverse addon children.
    local cooldownButton = CreateFrame("Button", nil, UIParent, "GameMenuFrameButtonTemplate")
    cooldownButton:SetText(L.cooldownMenu)
    cooldownButton:SetMotionScriptsWhileDisabled(true)
    cooldownButton:Hide()
    local layoutReady, nativeHeight, shiftedButtons = false, nil, nil

    local function IsControllerMode()
        return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    end

    local function OpenCooldownSettings()
        if not PyresinQoLDB.cooldownShortcut or InCombatLockdown() or IsControllerMode() then
            return
        end

        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(GameMenuFrame)
        CooldownViewerSettings:ShowUIPanel(false)
    end

    cooldownButton:SetScript("OnClick", OpenCooldownSettings)
    cooldownButton:SetScript("OnEnter", function(button)
        if InCombatLockdown() then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.cooldownMenu)
            GameTooltip_AddErrorLine(GameTooltip, L.combat)
            GameTooltip:Show()
        end
    end)
    cooldownButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function RestoreLayout()
        if not nativeHeight then return end
        for _, entry in ipairs(shiftedButtons) do
            entry.button:ClearAllPoints()
            entry.button:SetPoint(unpack(entry.point))
        end
        GameMenuFrame:SetHeight(nativeHeight)
        nativeHeight, shiftedButtons = nil, nil
    end

    local function UpdateCooldownButton()
        RestoreLayout()
        cooldownButton:Hide()
        if GameTooltip:IsOwned(cooldownButton) then GameTooltip:Hide() end
        if not layoutReady or not GameMenuFrame:IsShown() or IsControllerMode() then return end
        if PyresinQoLDB and PyresinQoLDB.cooldownShortcut then
            for index, button in ipairs(GameMenuFrame.buttons) do
                if button:GetText() == GAMEMENU_OPTIONS then
                    local width, height = button:GetSize()
                    local spacing = GameMenuFrame.spacing or 0
                    local offset = height + spacing
                    nativeHeight, shiftedButtons = GameMenuFrame:GetHeight(), {}
                    -- Reserve a row after native layout while preserving its
                    -- button pool, callbacks and layout indices.
                    for nextIndex = index + 1, #GameMenuFrame.buttons do
                        local nextButton = GameMenuFrame.buttons[nextIndex]
                        local point = { nextButton:GetPoint(1) }
                        shiftedButtons[#shiftedButtons + 1] = { button = nextButton, point = point }
                        nextButton:ClearAllPoints()
                        nextButton:SetPoint(point[1], point[2], point[3], point[4], point[5] - offset)
                    end
                    GameMenuFrame:SetHeight(nativeHeight + offset)
                    cooldownButton:ClearAllPoints()
                    cooldownButton:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -spacing)
                    cooldownButton:SetSize(width, height)
                    cooldownButton:SetScale(GameMenuFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
                    -- Keep the independent button above the menu's mouse-catching frame.
                    cooldownButton:SetFrameStrata("FULLSCREEN_DIALOG")
                    cooldownButton:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 1)
                    cooldownButton:SetEnabled(not InCombatLockdown())
                    cooldownButton:Show()
                    break
                end
            end
        end
    end

    hooksecurefunc(GameMenuFrame, "InitButtons", function()
        layoutReady, nativeHeight, shiftedButtons = false, nil, nil
        cooldownButton:Hide()
    end)
    hooksecurefunc(GameMenuFrame, "Layout", function()
        layoutReady, nativeHeight, shiftedButtons = true, nil, nil
        UpdateCooldownButton()
    end)
    GameMenuFrame:HookScript("OnHide", UpdateCooldownButton)

    module.UpdateCooldownButton = UpdateCooldownButton

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
    events:SetScript("OnEvent", UpdateCooldownButton)
end)
