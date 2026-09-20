local _, ns = ...

ns.RegisterModule("unitFrames", function(module)
    local _, class = UnitClass("player")
    if class ~= "ROGUE" and class ~= "DRUID" then return end

    local displays, active = {}, {}
    local previewUnit = NamePlateConstants.PREVIEW_UNIT_TOKEN
    -- ponytail: retain the last public capacity (initially Classic's five) while the maximum is secret.
    local maximum = 5
    local backgroundAtlas = class == "DRUID" and "UF-DruidCP-BG-Dis" or "uf-roguecp-bg-dis"
    local pointAtlas = class == "DRUID" and "UF-DruidCP-Icon" or "uf-roguecp-icon-red"

    local function PointBar(parent, atlas, minimum)
        local bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(14, 14)
        bar:SetMinMaxValues(minimum, minimum + 1)
        local texture = bar:CreateTexture(nil, "ARTWORK")
        texture:SetAtlas(atlas)
        bar:SetStatusBarTexture(texture)
        return bar
    end

    local function Update(unit, display)
        display.frame:Hide()
        local count, capacity = 3, 5
        if unit ~= previewUnit then
            if not UnitCanAttack("player", unit) or UnitIsDeadOrGhost(unit) or UnitHasVehicleUI("player") then return end
            local currentMax = UnitPowerMax("player", Enum.PowerType.ComboPoints)
            if not issecretvalue(currentMax) then maximum = currentMax end
            capacity = maximum
            if capacity <= 0 then return end
            -- Ask about this enemy, never copy the current target's points to other plates.
            count = GetComboPoints("player", unit)
        end

        if display.capacity ~= capacity then
            display.frame:SetSize(capacity * 16 - 2, 14)
            for index = 1, capacity do
                if not display.points[index] then
                    local background = PointBar(display.frame, backgroundAtlas, 0)
                    background:SetPoint("LEFT", display.frame, "LEFT", (index - 1) * 16, 0)
                    local point = PointBar(background, pointAtlas, index - 1)
                    point:SetPoint("CENTER", background, "CENTER")
                    display.points[index] = { background = background, fill = point }
                end
            end
            for index, point in ipairs(display.points) do point.background:SetShown(index <= capacity) end
            display.capacity = capacity
        end

        for index = 1, capacity do
            local point = display.points[index]
            -- Native bars clamp secret integers: empty at i-1, full at i. At zero even the backgrounds disappear.
            point.background:SetValue(count)
            point.fill:SetValue(count)
        end
        display.frame:Show()
    end

    local function Add(unit)
        if PyresinQoLDB.nameplateComboPoints == false then return end
        local plate = NamePlateDriverFrame:GetNamePlateForUnit(unit)
        local frame = plate and plate.UnitFrame
        if not frame or frame:IsForbidden() or not frame.healthBar then return end
        local display = displays[frame]
        if not display then
            local row = CreateFrame("Frame", nil, frame)
            -- Below the cast bar leaves Blizzard's name, debuffs and health text intact.
            row:SetPoint("TOP", frame.CastBarsContainer, "BOTTOM", 0, -4)
            display = { frame = row, points = {} }
            displays[frame] = display
        end
        active[unit] = display
        Update(unit, display)
    end

    function module.UpdateNameplateComboPoints()
        for unit, display in pairs(active) do
            display.frame:Hide()
            active[unit] = nil
        end
        if PyresinQoLDB.nameplateComboPoints == false then return end
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate:GetUnit()
            if unit then Add(unit) end
        end
        if NamePlateDriverFrame:IsScriptNamePlateRegistered(previewUnit) then Add(previewUnit) end
    end

    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit) Add(unit) end)
    hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
        if active[unit] then active[unit].frame:Hide(); active[unit] = nil end
    end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "UNIT_HEALTH", "UNIT_FACTION" }) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:SetScript("OnEvent", function(_, event, unit, powerToken)
        if PyresinQoLDB.nameplateComboPoints == false then return end
        if (event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER")
            and powerToken ~= "COMBO_POINTS" then return end
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            module.UpdateNameplateComboPoints()
        elseif event == "UNIT_HEALTH" or event == "UNIT_FACTION" then
            if active[unit] then Update(unit, active[unit]) end
        else
            for token, display in pairs(active) do Update(token, display) end
        end
    end)
end)
