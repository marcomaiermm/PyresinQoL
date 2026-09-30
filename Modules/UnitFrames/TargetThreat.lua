local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local displays = {}

    local function Percent(text, value)
        if not issecretvalue(value) and value == nil then text:SetText("—")
        else text:SetFormattedText("%.0f%%", value) end
    end

    local function Refresh(changedUnit)
        if not PyresinQoLDB then return end
        local mode = PyresinQoLDB.targetThreat
        for unit, display in pairs(displays) do
            if not changedUnit or changedUnit == unit then
                display.frame:Hide()
                if (mode == "always" or mode == "combat" and InCombatLockdown())
                    and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDeadOrGhost(unit) then
                    local tanking, status, _, percentage = UnitDetailedThreatSituation("player", unit)
                    if not issecretvalue(tanking) and tanking == nil then tanking = false end
                    if issecretvalue(status) or status == nil then status = 0 end
                    display.bg:SetVertexColor(GetThreatStatusColor(status))
                    Percent(display.threat, percentage)
                    local lead = UnitThreatPercentageOfLead("player", unit)
                    -- Restricted lead values cannot be tested for zero; keep the raw percentage visible.
                    if not issecretvalue(lead) and lead and lead > 0 then
                        Percent(display.lead, lead)
                        display.threat:SetAlphaFromBoolean(tanking, 0, 1)
                        display.lead:SetAlphaFromBoolean(tanking, 1, 0)
                    elseif not issecretvalue(percentage) and percentage == nil then
                        display.lead:SetText("100%")
                        display.threat:SetAlphaFromBoolean(tanking, 0, 1)
                        display.lead:SetAlphaFromBoolean(tanking, 1, 0)
                    else
                        display.threat:SetAlpha(1)
                        display.lead:SetAlpha(0)
                    end
                    display.frame:Show()
                end
            end
        end
    end

    function module.UpdateTargetThreat()
        if not PyresinQoLDB then return end
        local mode = PyresinQoLDB.targetThreat
        SetCVar("threatShowNumeric", mode == "auto" and "1" or "0")
        if mode ~= "off" then SetCVar("threatWarning", "3") end
        Refresh()
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_THREAT_LIST_UPDATE",
        "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FACTION" }) do
        events:RegisterEvent(event)
    end
    events:RegisterUnitEvent("UNIT_HEALTH", "target", "focus")
    events:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_LOGIN" then
            self:UnregisterEvent(event)
            for unit, owner in pairs({ target = TargetFrame, focus = FocusFrame }) do
                local native = owner.threatNumericIndicator
                -- Mirrored auras do not reserve space for a hidden native indicator.
                local frame = CreateFrame("Frame", nil, native:GetParent())
                frame:SetSize(49, 18)
                local function UpdatePosition()
                    frame:ClearAllPoints()
                    if owner.buffsOnTop then
                        frame:SetPoint("LEFT", owner, "RIGHT", 4, 0)
                    else
                        frame:SetAllPoints(native)
                    end
                end
                hooksecurefunc(owner, "ConfigureAuraContainer", UpdatePosition)
                UpdatePosition()
                local bg = frame:CreateTexture(nil, "BACKGROUND")
                bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
                bg:SetSize(37, 14)
                bg:SetPoint("TOP", 0, -3)
                local border = frame:CreateTexture(nil, "ARTWORK")
                border:SetTexture("Interface\\TargetingFrame\\NumericThreatBorder")
                border:SetTexCoord(0, 0.765625, 0, 0.5625)
                border:SetAllPoints()
                local display = { frame = frame, bg = bg }
                for _, key in ipairs({ "threat", "lead" }) do
                    display[key] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    display[key]:SetPoint("TOP", 0, -4)
                end
                displays[unit] = display
            end
            module.UpdateTargetThreat()
        elseif event == "UNIT_HEALTH" or event == "UNIT_FACTION" then
            if unit == "target" or unit == "focus" then
                Refresh(unit)
            elseif event == "UNIT_FACTION" and unit == "player" then
                Refresh()
            end
        else
            Refresh()
        end
    end)
end)
