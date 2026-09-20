local _, ns = ...

ns.RegisterModule("experience", function(module)
    local L = ns.L
    local bars = {}
    local hoveredBar, hoveredOwner
    local completedQuests, totalQuests, questXP = 0, 0, 0
    local questsDirty = true

    local function UpdateText(bar)
        if not PyresinQoLDB or PyresinQoLDB.xpTextFormat == "blizzard" then return end
        local current, maximum = bar:GetLevelData()
        if issecretvalue(current) or issecretvalue(maximum) then return end
        if maximum <= 0 then
            bar.OverlayFrame.Text:Hide()
            return
        end
        local percent = ("%.1f%%"):format(current / maximum * 100)
        local text = FormatLargeNumber(current) .. " / " .. FormatLargeNumber(maximum)
        if PyresinQoLDB.xpTextFormat == "percent" then
            text = percent
        elseif PyresinQoLDB.xpTextFormat ~= "value" then
            text = text .. " (" .. percent .. ")"
        end
        bar.OverlayFrame.Text:SetText(text)
        bar.OverlayFrame.Text:SetShown(PyresinQoLDB.xpAlwaysShow ~= false or hoveredBar == bar)
    end

    local function RefreshQuestSummary()
        if not questsDirty or not PyresinQoLDB.xpQuestRewards then return end
        local completed, total, xp = 0, 0, 0
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and not info.isHidden then
                total = total + 1
                if C_QuestLog.ReadyForTurnIn(info.questID) then
                    completed = completed + 1
                    xp = xp + (GetQuestLogRewardXP(info.questID) or 0)
                end
            end
        end
        completedQuests, totalQuests, questXP = completed, total, xp
        questsDirty = false
    end

    local function UpdateQuestPreview(bar)
        local preview = bar.PyresinQuestPreview
        preview:Hide()
        if not PyresinQoLDB or not PyresinQoLDB.xpQuestRewards then return end
        local current, maximum = bar:GetLevelData()
        if issecretvalue(current) or issecretvalue(maximum) or maximum <= 0 then return end
        local reward = math.min(questXP, maximum - current)
        if reward <= 0 then return end
        local width = bar.StatusBar:GetWidth()
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", bar.StatusBar, "TOPLEFT", current / maximum * width, 0)
        preview:SetPoint("BOTTOMLEFT", bar.StatusBar, "BOTTOMLEFT", current / maximum * width, 0)
        preview:SetWidth(reward / maximum * width)
        preview:Show()
    end

    local function UpdateQuestPreviewTexture(bar, isRested)
        bar.PyresinQuestPreview:SetAtlas(isRested and "UI-HUD-ExperienceBar-Fill-Rested"
            or "UI-HUD-ExperienceBar-Fill-Experience")
    end

    local function ShowTooltip()
        if not hoveredBar or not PyresinQoLDB.xpTooltip then return end
        local current, maximum = hoveredBar:GetLevelData()
        if issecretvalue(current) or issecretvalue(maximum) or maximum <= 0 then return end
        GameTooltip:SetOwner(hoveredOwner, "ANCHOR_RIGHT")
        GameTooltip:SetText(XPBAR_LABEL)
        local function Line(label, value)
            GameTooltip:AddDoubleLine(label, value, 1, 0.82, 0, 1, 1, 1)
        end
        Line(L.xpCurrent, ("%s / %s (%.1f%%)"):format(FormatLargeNumber(current),
            FormatLargeNumber(maximum), current / maximum * 100))
        Line(L.xpRemaining, ("%s (%.1f%%)"):format(FormatLargeNumber(math.max(0, maximum - current)),
            math.max(0, maximum - current) / maximum * 100))
        local rested = GetXPExhaustion() or 0
        Line(L.xpRested, ("%s (%.1f%%)"):format(FormatLargeNumber(rested), rested / maximum * 100))
        if PyresinQoLDB.xpQuestRewards then
            GameTooltip:AddLine(" ")
            Line(L.xpCompletedQuests, completedQuests .. " / " .. totalQuests)
            Line(L.xpQuestXP, ("%s (%.1f%%)"):format(FormatLargeNumber(questXP), questXP / maximum * 100))
        end
        GameTooltip:Show()
    end

    function module.UpdateExperience()
        if not PyresinQoLDB.xpQuestRewards then questsDirty = true end
        if #bars > 0 then RefreshQuestSummary() end
        for _, bar in ipairs(bars) do
            bar:UpdateCurrentText()
            bar:UpdateTextVisibility()
        end
        if hoveredOwner then
            if PyresinQoLDB.xpTooltip then
                ShowTooltip()
            elseif GameTooltip:IsOwned(hoveredOwner) then
                GameTooltip:Hide()
                hoveredBar.ExhaustionTick:ExhaustionToolTipText()
            end
        end
    end

    local updatePending = false
    local function RefreshDisplays()
        updatePending = false
        RefreshQuestSummary()
        for _, bar in ipairs(bars) do UpdateQuestPreview(bar) end
        if hoveredOwner and GameTooltip:IsOwned(hoveredOwner) then ShowTooltip() end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self, event)
        if event ~= "PLAYER_LOGIN" then
            if event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP" then questsDirty = true end
            if not updatePending then
                updatePending = true
                C_Timer.After(0, RefreshDisplays)
            end
            return
        end
        self:UnregisterEvent("PLAYER_LOGIN")
        -- Forever 1.60.1 has an XP bar in each of the two Retail-style containers.
        for _, container in ipairs(StatusTrackingBarManager.barContainers) do
            local bar = container.bars[StatusTrackingBarInfo.BarsEnum.Experience]
            bars[#bars + 1] = bar
            bar.PyresinQuestPreview = bar.StatusBar:CreateTexture(nil, "ARTWORK", nil, 1)
            bar.PyresinQuestPreview:SetAlpha(0.25)
            UpdateQuestPreviewTexture(bar, GetRestState() == 1)
            bar.PyresinQuestPreview:Hide()
            hooksecurefunc(bar, "UpdateStatusBarTextures", UpdateQuestPreviewTexture)
            hooksecurefunc(bar, "UpdateCurrentText", UpdateText)
            hooksecurefunc(bar, "UpdateCurrentText", UpdateQuestPreview)
            hooksecurefunc(bar, "UpdateTextVisibility", UpdateText)
            bar.StatusBar:HookScript("OnSizeChanged", function() UpdateQuestPreview(bar) end)
            for _, frame in ipairs({ bar, bar.ExhaustionTick }) do
                frame:HookScript("OnEnter", function(owner)
                    hoveredBar, hoveredOwner = bar, owner
                    UpdateText(bar)
                    ShowTooltip()
                end)
                frame:HookScript("OnLeave", function(owner)
                    if hoveredOwner == owner then hoveredBar, hoveredOwner = nil, nil end
                    UpdateText(bar)
                end)
            end
            bar:HookScript("OnHide", function()
                if hoveredBar == bar then
                    if GameTooltip:IsOwned(hoveredOwner) then GameTooltip:Hide() end
                    hoveredBar, hoveredOwner = nil, nil
                end
            end)
        end
        for _, name in ipairs({ "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION" }) do
            self:RegisterEvent(name)
        end
        module.UpdateExperience()
    end)
end)
