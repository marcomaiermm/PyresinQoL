local _, ns = ...

ns.RegisterModule("unitFrames", function()
    local legacyType = 0x5051
    local threatName = THREAT or "Threat"
    local displays = {}
    local refreshEvents = {
        GROUP_ROSTER_UPDATE = true,
        PLAYER_TARGET_CHANGED = true,
        UNIT_CONNECTION = true,
        UNIT_THREAT_LIST_UPDATE = true,
        UNIT_THREAT_SITUATION_UPDATE = true,
    }

    local function AddUnit(sources, unit)
        if not UnitExists(unit) then return end
        local _, _, percentage, _, threatValue = UnitDetailedThreatSituation(unit, "target")
        if not issecretvalue(percentage) and (percentage == nil or percentage < 1) then return end
        local name = UnitName(unit)
        local _, classFilename = UnitClass(unit)
        if not issecretvalue(name) and name == nil then name = UNKNOWNOBJECT end
        if issecretvalue(classFilename) then classFilename = nil end
        if not issecretvalue(threatValue) and threatValue == nil then threatValue = percentage end
        sources[#sources + 1] = {
            name = name, classFilename = classFilename,
            percentage = percentage, threatValue = threatValue,
        }
    end

    local function BuildThreatSources()
        local sources = {}
        if not UnitExists("target") then return sources end
        local canAttack = UnitCanAttack("player", "target")
        if not issecretvalue(canAttack) and not canAttack then return sources end
        if IsInRaid() then
            for index = 1, GetNumGroupMembers() do AddUnit(sources, "raid" .. index) end
        else
            AddUnit(sources, "player")
            for index = 1, GetNumSubgroupMembers() do AddUnit(sources, "party" .. index) end
        end
        -- Restricted threat cannot be compared in Lua; retain roster order in that case.
        for _, source in ipairs(sources) do
            if issecretvalue(source.threatValue) then return sources end
        end
        table.sort(sources, function(left, right) return left.threatValue > right.threatValue end)
        return sources
    end

    local function CreateRow(display)
        -- Reuse Blizzard's visual base, never its source-data Init/UpdateName/UpdateValue path.
        local row = CreateFrame("Button", nil, display, "DamageMeterEntryTemplate")
        row:EnableMouse(false)
        row.sourceDisplayType = Enum.DamageMeterSourceDisplayType.Ally
        row:GetStatusBar():SetMinMaxValues(0, 100)
        return row
    end

    local function RefreshThreat(window)
        local display = displays[window]
        if not display.active or not display:IsVisible() or window:IsEditing() then return end
        local sources = BuildThreatSources()
        -- ponytail: scroll up to the final row; avoid measuring restricted viewport geometry.
        display.offset = math.min(display.offset, math.max(0, #sources - 1))
        local height, spacing = window:GetBarHeight(), window:GetBarSpacing()
        for index, source in ipairs(sources) do
            local row = display.rows[index]
            if not row then
                row = CreateRow(display)
                display.rows[index] = row
            end
            row:ClearAllPoints()
            local y = -(index - display.offset - 1) * (height + spacing)
            row:SetPoint("TOPLEFT", display, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, y)
            row:SetBarHeight(height)
            row:SetTextScale(window:GetTextScale())
            row:SetStyle(window:GetStyle())
            row:SetShowBarIcons(window:ShouldShowBarIcons())
            row:SetBackgroundAlpha(window:GetBackgroundAlpha())
            row.classFilename = source.classFilename
            row:SetUseClassColor(window:ShouldUseClassColor())
            if source.classFilename and source.classFilename ~= "" then
                row:GetIcon():SetAtlas(GetClassAtlas(source.classFilename))
            else
                row:GetIcon():SetTexture(nil)
            end
            -- Native display sinks accept secrets; keep those values out of mixin fields.
            row:GetName():SetFormattedText(DAMAGE_METER_SOURCE_NAME, index, source.name)
            row:GetValue():SetText(C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(source.percentage), "", "%"))
            row:GetStatusBar():SetValue(source.percentage)
            row:SetShown(index > display.offset)
        end
        for index = #sources + 1, #display.rows do display.rows[index]:Hide() end
        display:EnableMouse(not window:IsNonInteractive())
        display:EnableMouseWheel(not window:IsNonInteractive())
    end

    local function ApplyMode(window)
        local display = displays[window]
        if not display.active then return end
        local editing = window:IsEditing() == true
        window:GetDamageMeterTypeName():SetText(editing and display.nativeTitle or threatName)
        window:GetSessionDropdown():SetShown(editing and display.sessionShown)
        window:GetSessionTimerFontString():SetAlpha(editing and 1 or 0)
        display:SetShown(not editing)
        RefreshThreat(window)
    end

    local function LeaveThreat(window)
        local display = displays[window]
        if not display.active then return end
        display.active = false
        display:Hide()
        -- The native selection has already set its own title; do not overwrite it.
        window:GetSessionDropdown():SetShown(display.sessionShown)
        window:GetSessionTimerFontString():SetAlpha(1)
    end

    local function SelectThreat(window)
        local display = displays[window]
        if not display.active then
            display.nativeTitle = window:GetDamageMeterTypeName():GetText()
            display.sessionShown = window:GetSessionDropdown():IsShown()
        end
        display.nativeType = window:GetDamageMeterType()
        display.active, display.offset = true, 0
        window:HideSourceWindow()
        ApplyMode(window)
    end

    local function ConfigureWindow(window)
        if displays[window] then return end
        local container = window:GetMinimizeContainer()
        local display = CreateFrame("Frame", nil, container)
        displays[window] = display
        display.rows, display.offset = {}, 0
        display:Hide()
        display:SetPoint("TOPLEFT", window:GetHeader(), "BOTTOMLEFT", 5, -2)
        display:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 6)
        display:SetFrameLevel(container:GetFrameLevel() + 20)
        display:SetClipsChildren(true)
        local background = display:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 1)
        display:SetScript("OnShow", function() RefreshThreat(window) end)
        display:SetScript("OnMouseWheel", function(_, delta)
            display.offset = math.max(0, display.offset - delta)
            RefreshThreat(window)
        end)

        if window:GetDamageMeterType() == legacyType then
            -- Repair state without invoking native Refresh from addon execution.
            window.damageMeterType = Enum.DamageMeterType.DamageDone
            window:GetSourceWindow().damageMeterType = Enum.DamageMeterType.DamageDone
            window:GetDamageMeterTypeName():SetText(DAMAGE_METER_TYPE_DAMAGE_DONE)
        end
    end

    for _, windowData in pairs(DamageMeterPerCharacterSettings and DamageMeterPerCharacterSettings.windowDataList or {}) do
        if windowData.damageMeterType == legacyType then windowData.damageMeterType = Enum.DamageMeterType.DamageDone end
    end
    for _, windowData in pairs(DamageMeter:GetWindowDataList()) do
        if windowData.damageMeterType == legacyType then windowData.damageMeterType = Enum.DamageMeterType.DamageDone end
    end
    DamageMeter:ForEachSessionWindow(ConfigureWindow)

    -- Own events/timer only: do not wrap native Refresh, entry initializers or menu methods.
    local events = CreateFrame("Frame")
    for event in pairs(refreshEvents) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        for window, display in pairs(displays) do
            if event == "PLAYER_TARGET_CHANGED" or event == "GROUP_ROSTER_UPDATE" then display.offset = 0 end
            RefreshThreat(window)
        end
    end)
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        for window, display in pairs(displays) do
            if display.active then
                if window:GetDamageMeterType() ~= display.nativeType then LeaveThreat(window)
                else ApplyMode(window) end
            end
        end
    end)

    Menu.ModifyMenu("MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE", function(dropdown, root)
        local window = dropdown:GetParent()
        ConfigureWindow(window)
        local display = displays[window]
        -- Set the public anchor during menu generation, without replacing OpenMenu.
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        dropdown:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale))
        root:SetMinimumWidth(140)
        local threatOption = root:CreateRadio(threatName, function() return display.active == true end,
            function() SelectThreat(window) end)
        root:AddMenuResponseCallback(function(_, description)
            if description ~= threatOption and description:IsRadio() then LeaveThreat(window) end
        end)
    end)
end)
