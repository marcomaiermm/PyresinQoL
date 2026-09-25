local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local labels, active = {}, {}
    local previewUnit = NamePlateConstants.PREVIEW_UNIT_TOKEN
    local tankColors = { [0] = { 1, 1, 1 }, { 1, 1, 0.47 }, { 0.3, 0.7, 1 }, { 0.2, 1, 0.3 } }

    local positions = {
        RIGHT = { "LEFT", "RIGHT", 42, 0 }, LEFT = { "RIGHT", "LEFT", -8, 0 },
        TOP = { "BOTTOM", "TOP", 0, 6 }, BOTTOM = { "TOP", "BOTTOM", 0, -6 },
    }

    local function UpdatePosition(display)
        local point = positions[PyresinQoLDB.nameplateThreatPosition] or positions.RIGHT
        if display.position == point then return end
        display.frame:ClearAllPoints()
        display.frame:SetPoint(point[1], display.bar, point[2], point[3], point[4])
        for _, text in ipairs({ display.threat, display.lead }) do
            text:ClearAllPoints()
            text:SetPoint(point[1], display.frame, point[1], 0, 0)
        end
        display.position = point
    end

    local function PercentText(value)
        if not issecretvalue(value) and value >= 1000 then return "999%+" end
        -- FormatNumber rejects secrets in addon code; these helpers accept them.
        -- Restricted percentages must remain uncapped because Lua cannot compare them.
        return C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(value), "", "%")
    end

    local function UpdateColor(display, status)
        -- Native color lookup and table indexing cannot accept restricted values.
        if issecretvalue(status) or status == nil then status = 0 end
        local role = UnitGroupRolesAssigned("player")
        local color = not issecretvalue(role) and role == "TANK" and tankColors[status]
        local r, g, b
        if color then r, g, b = unpack(color) else r, g, b = GetThreatStatusColor(status) end
        display.threat:SetTextColor(r, g, b)
        display.lead:SetTextColor(r, g, b)
    end

    local function Clear(display)
        display.frame:Hide()
        display.threat:SetText("")
        display.lead:SetText("")
    end

    local function Update(unit, display)
        Clear(display)
        UpdatePosition(display)
        if unit == previewUnit then
            UpdateColor(display, 3)
            display.threat:SetText("125%")
            display.threat:SetAlphaFromBoolean(false, 0, 1)
            display.frame:SetAlphaFromBoolean(false, 0, 1)
            display.frame:Show()
            return
        end
        if not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) then return end
        local tanking, _, _, percentage = UnitDetailedThreatSituation("player", unit)
        if not issecretvalue(percentage) and (not percentage or percentage < 1) then return end
        if not issecretvalue(tanking) and tanking == nil then return end

        UpdateColor(display, UnitThreatSituation("player", unit))

        -- Native formatting and alpha selection accept secrets, including the tanking boolean.
        display.threat:SetText(PercentText(percentage))
        display.threat:SetAlphaFromBoolean(tanking, 0, 1)
        local lead = UnitThreatPercentageOfLead("player", unit)
        local hasLead = issecretvalue(lead) or (lead and lead >= 1)
        if hasLead then
            display.lead:SetText(PercentText(lead))
            display.lead:SetAlphaFromBoolean(tanking, 1, 0)
        end
        display.frame:SetAlphaFromBoolean(tanking, hasLead and 1 or 0, 1)
        display.frame:Show()
    end

    local function Add(unit)
        if PyresinQoLDB.nameplateThreat == false then return end
        local plate = NamePlateDriverFrame:GetNamePlateForUnit(unit)
        local frame = plate and plate.UnitFrame
        local bar = frame and frame.healthBar
        if not bar or frame:IsForbidden() then return end
        local display = labels[bar]
        if not display then
            local badge = CreateFrame("Frame", nil, bar)
            badge:SetSize(1, 1)
            display = { frame = badge, bar = bar }
            for _, key in ipairs({ "threat", "lead" }) do
                local text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
                text:SetTextColor(1, 1, 1)
                display[key] = text
            end
            labels[bar] = display
        end
        active[unit] = display
        Update(unit, display)
    end

    function module.UpdateNameplateThreat()
        for unit, display in pairs(active) do
            Clear(display)
            active[unit] = nil
        end
        if PyresinQoLDB.nameplateThreat == false then return end
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate:GetUnit()
            if unit then Add(unit) end
        end
        if NamePlateDriverFrame:IsScriptNamePlateRegistered(previewUnit) then Add(previewUnit) end
    end

    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) Add(unit) end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if active[unit] then Clear(active[unit]); active[unit] = nil end
    end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
        "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FACTION", "UNIT_HEALTH" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if PyresinQoLDB.nameplateThreat == false then
            return
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
            module.UpdateNameplateThreat()
        elseif active[unit] then
            Update(unit, active[unit])
        elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_THREAT_SITUATION_UPDATE" then
            for token, display in pairs(active) do Update(token, display) end
        end
    end)
end)
