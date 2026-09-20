local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local frames = {}
    local healthStyles, updatingColor = {}, {}

    function module.UpdateTargetThreat()
        if not PyresinQoLDB then return end
        local enabled = PyresinQoLDB.targetThreat ~= false
        -- Blizzard owns the indicator, its layout, and restricted threat values.
        SetCVar("threatShowNumeric", enabled and "1" or "0")
        if enabled then SetCVar("threatWarning", "3") end
    end

    local function AddHoverValues(bar)
        local text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        text:SetPoint("CENTER", bar.TextString, "CENTER")
        text:Hide()
        local nativeTexts = { bar.TextString, bar.LeftText, bar.RightText }
        local alphas
        local function Update()
            if not alphas then return end
            local _, maximum = bar:GetMinMaxValues()
            -- Pass restricted values directly to the engine; never calculate or compare them in Lua.
            text:SetFormattedText("%d / %d", bar:GetValue(), maximum)
        end
        local function Leave()
            if not alphas then return end
            text:Hide()
            for index, native in ipairs(nativeTexts) do native:SetAlpha(alphas[index]) end
            alphas = nil
        end
        bar:HookScript("OnEnter", function()
            if alphas then return end
            alphas = {}
            for index, native in ipairs(nativeTexts) do
                alphas[index] = native:GetAlpha()
                native:SetAlpha(0)
            end
            Update()
            text:Show()
        end)
        bar:HookScript("OnLeave", Leave)
        bar:HookScript("OnHide", Leave)
        bar:HookScript("OnValueChanged", Update)
        bar:HookScript("OnMinMaxChanged", Update)
    end

    local function UpdateClassColor(health, unit)
        if not health or updatingColor[health] then return end
        updatingColor[health] = true
        local texture = health:GetStatusBarTexture()
        local originalHealthStyle = healthStyles[health]
        local _, class = UnitClass(unit)
        local color = not issecretvalue(class) and RAID_CLASS_COLORS[class]
        if PyresinQoLDB[unit .. "ClassColor"] and UnitIsPlayer(unit) and color then
            if not originalHealthStyle then
                originalHealthStyle = {
                    desaturation = texture:GetDesaturation(),
                    color = { health:GetStatusBarColor() },
                }
                healthStyles[health] = originalHealthStyle
                -- Remove the green tint while preserving Blizzard's shading and highlights.
                texture:SetDesaturation(1)
            end
            health:SetStatusBarColor(color.r, color.g, color.b)
        elseif originalHealthStyle then
            texture:SetDesaturation(originalHealthStyle.desaturation)
            health:SetStatusBarColor(unpack(originalHealthStyle.color))
            healthStyles[health] = nil
        end
        updatingColor[health] = nil
    end

    function module.UpdatePlayerFrame()
        if not PyresinQoLDB then return end
        for unit, frame in pairs(frames) do
            UpdateClassColor(frame.healthbar, unit)
            for resource, bar in pairs({ HP = frame.healthbar, Mana = frame.manabar }) do
                local text = bar.TextString
                local point = PyresinQoLDB[unit .. resource .. "Position"] or "CENTER"
                local x = point:find("LEFT") and 2 or point:find("RIGHT") and -2 or 0
                text:ClearAllPoints()
                text:SetPoint(point, bar, point, x, 0)
            end
        end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        frames = { player = PlayerFrame, target = TargetFrame }
        for unit, frame in pairs(frames) do
            AddHoverValues(frame.healthbar)
            AddHoverValues(frame.manabar)
            hooksecurefunc(frame.healthbar, "SetStatusBarColor", function(health, r, g, b, a)
                if updatingColor[health] then return end
                if healthStyles[health] then healthStyles[health].color = { r, g, b, a or 1 } end
                UpdateClassColor(health, unit)
            end)
        end
        hooksecurefunc(TargetFrame, "Update", module.UpdatePlayerFrame)
        module.UpdatePlayerFrame()
        module.UpdateTargetThreat()
    end)
end)
