local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local bar
    local _, class = UnitClass("player")

    function module.UpdateDruidMana()
        if not bar then return end
        local powerType = UnitPowerType("player")
        local show = PyresinQoLDB.druidMana ~= false and not UnitHasVehicleUI("player")
            and not issecretvalue(powerType)
            and (powerType == Enum.PowerType.Energy or powerType == Enum.PowerType.Rage)
        bar:SetShown(show)
        if not show then return end

        local current = UnitPower("player", Enum.PowerType.Mana)
        local maximum = UnitPowerMax("player", Enum.PowerType.Mana)
        -- Forward restricted values to the engine without Lua arithmetic or formatting.
        bar:SetMinMaxValues(0, maximum)
        bar:SetValue(current)
        bar.Text:SetFormattedText("%d / %d", current, maximum)
    end

    if class ~= "DRUID" then return end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self, event, _, powerToken)
        if event == "PLAYER_LOGIN" then
            self:UnregisterEvent("PLAYER_LOGIN")
            bar = CreateFrame("StatusBar", "PyresinQoLDruidManaBar", PlayerFrame)
            bar:SetSize(124, 10)
            bar:SetPoint("TOPRIGHT", PlayerFrame.manabar, "BOTTOMRIGHT", 0, -6)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            local color = PowerBarColor.MANA
            bar:SetStatusBarColor(color.r, color.g, color.b)
            local background = bar:CreateTexture(nil, "BACKGROUND")
            background:SetPoint("TOPLEFT", -1, 1)
            background:SetPoint("BOTTOMRIGHT", 1, -1)
            background:SetColorTexture(0, 0, 0, 0.8)
            bar.Text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
            bar.Text:SetPoint("CENTER")

            self:RegisterEvent("PLAYER_ENTERING_WORLD")
            for _, name in ipairs({ "UNIT_DISPLAYPOWER", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
                "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
                self:RegisterUnitEvent(name, "player")
            end
        elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER")
            and powerToken ~= "MANA" then
            return
        end
        module.UpdateDruidMana()
    end)
end)
