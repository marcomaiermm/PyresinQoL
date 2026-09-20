local _, ns = ...

ns.RegisterModule("tooltips", function(module)
    local bar = GameTooltip.StatusBar
    local originalHeight = bar:GetHeight()
    local healthText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetPoint("CENTER")
    healthText:SetText("")
    local healthElapsed, hasHealthText = 0, false
    local guildLine, guildText

    local function ClearHealth()
        healthElapsed = 0
        if hasHealthText then
            healthText:SetText("")
            hasHealthText = false
        end
    end

    local function GetUnit()
        local _, unit = GameTooltip:GetUnit()
        if not issecretvalue(unit) then return unit end
    end

    local function UpdateHealth()
        healthElapsed = 0
        if not PyresinQoLDB or not PyresinQoLDB.tooltipHealth then
            ClearHealth()
            return
        end
        local unit = GetUnit()
        -- Blizzard clears unit data before fading; keep the last text until hide/clear.
        if not unit then return end
        -- Pass restricted HP straight to the native formatter; never inspect or calculate with it.
        healthText:SetFormattedText("%d / %d", UnitHealth(unit), UnitHealthMax(unit))
        hasHealthText = true
    end

    local function UpdateGuildRank()
        if guildLine then guildLine:SetText(guildText) end
        guildLine, guildText = nil, nil
        local unit = GetUnit()
        if not PyresinQoLDB or not PyresinQoLDB.tooltipGuildRank or not unit then return end
        local guild, rank = GetGuildInfo(unit)
        if issecretvalue(guild) or issecretvalue(rank) or not guild or not rank or rank == "" then return end
        for index = 2, GameTooltip:NumLines() do
            local line = GameTooltip:GetLeftLine(index)
            local text = line:GetText()
            if not issecretvalue(text) and text and text:find(guild, 1, true) then
                guildLine, guildText = line, text
                local first, last = text:find(guild, 1, true)
                if text:sub(first - 1, first - 1) == "<" and text:sub(last + 1, last + 1) == ">" then
                    first, last = first - 1, last + 1
                end
                line:SetFormattedText("%s|cff40ff40<%s>|r%s |cff909090%s|r",
                    text:sub(1, first - 1), guild, text:sub(last + 1), rank)
                return
            end
        end
    end

    function module.UpdateTooltips()
        bar:SetHeight(PyresinQoLDB and PyresinQoLDB.tooltipHealth and 14 or originalHeight)
        UpdateHealth()
        UpdateGuildRank()
    end

    bar:HookScript("OnUpdate", function(_, elapsed)
        if not PyresinQoLDB or not PyresinQoLDB.tooltipHealth then return end
        healthElapsed = healthElapsed + elapsed
        if healthElapsed >= 0.1 then UpdateHealth() end
    end)
    GameTooltip:HookScript("OnHide", ClearHealth)
    GameTooltip:HookScript("OnTooltipCleared", function()
        guildLine, guildText = nil, nil
        ClearHealth()
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip)
        if tooltip ~= GameTooltip or not PyresinQoLDB or not PyresinQoLDB.tooltipObjectCursor then return end
        local info = tooltip:GetPrimaryTooltipInfo()
        if not info or info.getterName ~= "GetWorldCursor" then return end
        -- SetOwner would clear the contents. Blizzard resets the anchor on the next world hover.
        tooltip:ClearAllPoints()
        tooltip:SetAnchorType("ANCHOR_CURSOR")
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip ~= GameTooltip then return end
        guildLine, guildText = nil, nil
        module.UpdateTooltips()
        local unit = GetUnit()
        if unit then
            local isPlayer = UnitIsPlayer(unit)
            if not issecretvalue(isPlayer) and isPlayer then
                local _, class = UnitClass(unit)
                local color = not issecretvalue(class) and RAID_CLASS_COLORS[class]
                if color then tooltip:GetLeftLine(1):SetTextColor(color.r, color.g, color.b) end
            end
        end
        for index = 2, tooltip:NumLines() do
            local line = tooltip:GetLeftLine(index)
            local text = line:GetText()
            if not issecretvalue(text) then
                if text == FACTION_ALLIANCE then
                    line:SetTextColor(0.25, 0.5, 1)
                    line:SetFormattedText("|A:UI-Character-Info-Honor-Icon-Alliance:16:16|a %s", text)
                elseif text == FACTION_HORDE then
                    line:SetTextColor(1, 0.2, 0.2)
                    line:SetFormattedText("|A:UI-Character-Info-Honor-Icon-Horde:16:16|a %s", text)
                end
            end
        end
    end)
end)
