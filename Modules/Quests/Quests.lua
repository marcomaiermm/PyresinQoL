local _, ns = ...

ns.RegisterModule("quests", function(module)

    local function DecorateQuest(button, questID, level)
        local font = button:GetFontString()
        local layout = button.PyresinQuestTitleLayout
        if layout then
            font:ClearAllPoints()
            for _, point in ipairs(layout.points) do font:SetPoint(unpack(point)) end
            font:SetWidth(layout.width)
            button.PyresinQuestTitleLayout = nil
            button:SetHeight(math.max(button:GetTextHeight() + 2, button.Icon:GetHeight()))
        end
        if button.PyresinQuestLevel then button.PyresinQuestLevel:Hide() end
        if not PyresinQoLDB or not PyresinQoLDB.questLevels or not questID or questID <= 0 then return end
        if not level or level <= 0 then level = C_QuestLog.GetQuestDifficultyLevel(questID) end
        if not level or level <= 0 then return end

        local color = GetDifficultyColor(C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID))
        -- A separate FontString lets only the level use an outline.
        local prefix = button.PyresinQuestLevel
        if not prefix then
            prefix = button:CreateFontString(nil, "OVERLAY")
            prefix:SetJustifyH("LEFT")
            button.PyresinQuestLevel = prefix
        end
        local path, size, flags = font:GetFont()
        flags = flags or ""
        if not flags:find("OUTLINE", 1, true) then
            flags = flags == "" and "OUTLINE" or flags .. ",OUTLINE"
        end
        prefix:SetFont(path, size, flags)
        prefix:SetText(CreateColor(color.r, color.g, color.b):WrapTextInColorCode(("[%d]"):format(level)))
        local offset = prefix:GetStringWidth() + 4
        layout = { width = font:GetWidth(), points = {} }
        for index = 1, font:GetNumPoints() do layout.points[index] = { font:GetPoint(index) } end
        button.PyresinQuestTitleLayout = layout
        font:ClearAllPoints()
        for _, point in ipairs(layout.points) do
            font:SetPoint(point[1], point[2], point[3], point[4] + offset, point[5])
        end
        font:SetWidth(math.max(1, layout.width - offset))
        prefix:ClearAllPoints()
        prefix:SetPoint("TOPLEFT", font, "TOPLEFT", -offset, 0)
        prefix:Show()
        button:SetHeight(math.max(button:GetTextHeight() + 2, button.Icon:GetHeight()))
    end

    local function UpdateGreeting()
        for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
            local index = button:GetID()
            local questID
            if button.isActive == 1 then
                questID = GetActiveQuestID(index)
            else
                questID = select(5, GetAvailableQuestInfo(index))
            end
            DecorateQuest(button, questID)
        end
    end

    local function UpdateGossipQuest(button, info)
        DecorateQuest(button, info.questID, info.questLevel)
    end

    local function UpdateQuestTitle()
        -- Rebuild the native title to preserve decorations and avoid duplicate prefixes.
        QuestInfo_ShowTitle()
        if not PyresinQoLDB or not PyresinQoLDB.questLevels then return end
        local questID = GetQuestID()
        if not questID or questID <= 0 then return end
        local level = C_QuestLog.GetQuestDifficultyLevel(questID)
        if level and level > 0 then
            QuestInfoTitleHeader:SetText(("[%d] %s"):format(level, QuestInfoTitleHeader:GetText()))
        end
    end

    -- Setup runs for visible rows and the ScrollBox's height-measuring rows.
    hooksecurefunc(GossipAvailableQuestButtonMixin, "Setup", UpdateGossipQuest)
    hooksecurefunc(GossipActiveQuestButtonMixin, "Setup", UpdateGossipQuest)
    -- XML retains the original OnShow callback; the global hook covers later rebuilds only.
    QuestFrameGreetingPanel:HookScript("OnShow", UpdateGreeting)
    hooksecurefunc("QuestFrameGreetingPanel_OnShow", UpdateGreeting)
    hooksecurefunc("QuestInfo_Display", function(template)
        if template == QUEST_TEMPLATE_DETAIL or template == QUEST_TEMPLATE_REWARD then
            UpdateQuestTitle()
        end
    end)

    function module.UpdateQuestLevels()
        -- Let Blizzard rebuild original titles, also restoring them when disabled.
        if QuestFrameGreetingPanel:IsShown() then QuestFrameGreetingPanel_OnShow() end
        if GossipFrame:IsShown() then GossipFrame:Update() end
        if not QuestInfoFrame.questLog and (QuestFrameDetailPanel:IsShown() or QuestFrameRewardPanel:IsShown()) then
            UpdateQuestTitle()
        end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:SetScript("OnEvent", function()
        C_Timer.After(0, module.UpdateQuestLevels)
    end)
end)
