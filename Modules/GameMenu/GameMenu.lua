local _, ns = ...

ns.RegisterModule("gameMenu", function(module)
    local L = ns.L

    -- Keep addon callbacks out of Blizzard's reusable button pool.
    local cooldownButton = CreateFrame("Button", nil, GameMenuFrame, "GameMenuFrameButtonTemplate")
    cooldownButton:SetText(L.cooldownMenu)
    cooldownButton:SetMotionScriptsWhileDisabled(true)
    cooldownButton:Hide()

    local function OpenCooldownSettings()
        if not PyresinQoLDB.cooldownShortcut or InCombatLockdown() then
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

    local function UpdateCooldownButton()
        cooldownButton:Hide()
        if PyresinQoLDB and PyresinQoLDB.cooldownShortcut then
            for _, button in ipairs(GameMenuFrame.buttons) do
                if button:GetText() == GAMEMENU_OPTIONS then
                    -- Layout discovers this child without modifying native buttons, indices or callbacks.
                    cooldownButton.layoutIndex = button.layoutIndex + 0.5
                    cooldownButton:SetSize(button:GetSize())
                    cooldownButton:SetEnabled(not InCombatLockdown())
                    cooldownButton:Show()
                    break
                end
            end
        end
        if GameTooltip:IsOwned(cooldownButton) then GameTooltip:Hide() end
        GameMenuFrame:MarkDirty()
    end

    hooksecurefunc(GameMenuFrame, "InitButtons", UpdateCooldownButton)

    module.UpdateCooldownButton = UpdateCooldownButton

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function()
        if GameMenuFrame:IsShown() then
            cooldownButton:SetEnabled(not InCombatLockdown())
            if GameTooltip:IsOwned(cooldownButton) then
                GameTooltip:Hide()
            end
        end
    end)
end)
