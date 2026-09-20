local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local debuffs

    local function InitializeDebuff(button, showTimer)
        button:SetSize(21, 21)
        button:SetTooltipAnchorPoint("ANCHOR_RIGHT")
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        button:SetIcon(icon)

        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        button:AddDispelTypeTexture(border, { showAlways = true })

        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetReverse(true)
        cooldown:SetHideCountdownNumbers(not showTimer)
        cooldown:SetCountdownFont("NumberFontNormalSmall")
        cooldown:SetUseAuraDisplayTime(true)
        button:SetDurationCooldown(cooldown)
        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

        local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", 1, -1)
        button:SetApplicationCount(count)
    end

    function module.UpdateTargetDebuffs()
        if not debuffs or not PyresinQoLDB then return end
        local enabled = PyresinQoLDB.targetDebuffs ~= false
        local onlyMine = PyresinQoLDB.targetDebuffsOnlyMine ~= false
        local native = TargetFrame:GetAuraContainer()
        native:SetMaxDebuffs(enabled and 0 or TargetFrame.maxDebuffs or TargetFrameAuraContainerDefaults.MaxDebuffs)
        debuffs:SetEnabled(enabled)
        debuffs:SetShown(enabled)
        -- Switch preconfigured groups, so changing the option never touches restricted buttons.
        debuffs:SetAuraGroupEnabled("Other", onlyMine)
        debuffs:SetAuraGroupEnabled("OtherTimed", not onlyMine)
        if enabled then
            local onTop = TargetFrame.buffsOnTop
            debuffs:ClearAllPoints()
            -- Only our container may depend on native layout, never the other way around.
            debuffs:SetPoint(onTop and "BOTTOMLEFT" or "TOPLEFT", native,
                onTop and "TOPLEFT" or "BOTTOMLEFT", 0, onTop and 3 or -3)
            debuffs:SetFlowLayoutAnchorPoint(onTop and "BOTTOMLEFT" or "TOPLEFT")
            debuffs:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,
                onTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
            debuffs:SetFlowLayoutMaximumLineSize(TargetFrame:IsTargetOfTargetShown() and 101 or 122)
            debuffs:UpdateAllAuras()
        end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        SetCVar("tooltipShowAuraCasterNames", "1")
        -- Native target aura buttons and their tooltip are private in this client.
        -- Register display elements once; Blizzard owns all aura data and updates.
        debuffs = CreateFrame("AuraContainer", nil, TargetFrame, "CustomAuraContainerTemplate")
        debuffs:SetUnit("target")
        for _, group in ipairs({ { "Own", "PLAYER", true }, { "Other", "!PLAYER", false }, { "OtherTimed", "!PLAYER", true } }) do
            local showTimer = group[3]
            debuffs:AddAuraGroup(group[1], "HARMFUL|INCLUDE_NAME_PLATE_ONLY|" .. group[2], {
                maxFrameCount = TargetFrameAuraContainerDefaults.MaxDebuffs,
                initializeFrame = function(button) InitializeDebuff(button, showTimer) end,
                layout = { elementWidth = 21, elementHeight = 21, elementSpacing = 3, lineSpacing = 3 },
            })
        end
        hooksecurefunc(TargetFrame, "ConfigureAuraContainer", module.UpdateTargetDebuffs)
        module.UpdateTargetDebuffs()
    end)
end)
