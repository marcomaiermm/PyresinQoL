local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local frames = {}
    local statusTexts = {}
    local healthStyles, updatingColor = {}, {}

    function module.UpdateTargetThreat()
        if not PyresinQoLDB then return end
        local enabled = PyresinQoLDB.targetThreat ~= false
        -- Blizzard owns the indicator, its layout, and restricted threat values.
        SetCVar("threatShowNumeric", enabled and "1" or "0")
        if enabled then SetCVar("threatWarning", "3") end
    end

    function module.UpdateStatusText()
        if not PyresinQoLDB then return end
        for _, entry in ipairs(statusTexts) do
            local hidden = PyresinQoLDB[entry.unit .. "HideStatusText"] == true
            if hidden and not entry.hidden then
                entry.alpha = entry.text:GetAlpha()
                entry.text:SetAlpha(0)
            elseif not hidden and entry.hidden then
                entry.text:SetAlpha(entry.alpha)
            end
            entry.hidden = hidden
        end
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
            hooksecurefunc(frame.healthbar, "SetStatusBarColor", function(health, r, g, b, a)
                if updatingColor[health] then return end
                if healthStyles[health] then healthStyles[health].color = { r, g, b, a or 1 } end
                UpdateClassColor(health, unit)
            end)
        end
        hooksecurefunc(TargetFrame, "Update", module.UpdatePlayerFrame)
        for unit, frame in pairs({ pet = PetFrame, target = TargetFrame,
            targettarget = TargetFrame.totFrame, focus = FocusFrame }) do
            local content = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
            for _, region in pairs({ frame.healthbar, frame.manabar, content and content.HealthBarsContainer }) do
                for _, key in ipairs({ "TextString", "LeftText", "RightText", "DeadText", "UnconsciousText" }) do
                    local text = region[key]
                    if text then statusTexts[#statusTexts + 1] = { unit = unit, text = text } end
                end
            end
        end
        -- Only change font opacity; Blizzard retains its values, formatter and shown state.
        module.UpdateStatusText()
        module.UpdatePlayerFrame()
        module.UpdateTargetThreat()
    end)
end)
