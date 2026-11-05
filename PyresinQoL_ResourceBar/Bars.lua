local ns = PyresinQoL
local module = ns.GetModule("resourceBar")
local Get = module.GetResourceBarOption

-- The player's health, power and combo points on Bar.lua's views, with their visibility rules, the
-- warlock's Life Tap preview and the option to hide Blizzard's personal resource display. EditMode.lua
-- moves the bars and previews them in Edit Mode.
local CLASSIC = "Interface\\TargetingFrame\\UI-StatusBar" -- Blizzard's bar texture for flat colors
local FLAT = "Interface\\Buttons\\WHITE8X8"
local HEALTH_ATLAS = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"
local POWER_ATLAS = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-" -- plus PowerBarColor's atlasElementName
local HEALTH_COLOR = { r = 0, g = 1, b = 0 }
local PREVIEW_COMBO_POINTS = 3
local TRAVEL_FORMS = { [DRUID_TRAVEL_FORM] = true, [DRUID_ACQUATIC_FORM] = true, [DRUID_FLIGHT_FORM] = true }

-- Forever's Life Tap ranks, highest first, with the mana each restores before Spirit and talents.
local LIFE_TAP_RANKS = { { 11689, 430 }, { 11688, 310 }, { 11687, 220 }, { 1456, 140 }, { 1455, 75 }, { 1454, 30 } }
local IMPROVED_LIFE_TAP = 18182

-- At PLAYER_LOGIN, with PyresinQoL's settings in place.
ns.RegisterModule("resourceBar", function()
    local _, class = UnitClass("player")
    local editing = false -- Edit Mode is open and shows every bar this class has
    local inCombat = InCombatLockdown()
    local powerType = Enum.PowerType.Mana -- the last readable one
    local comboMaximum = 5 -- the last readable one, initially Classic's five
    local lifeTapGain

    local function Restricted(value) return issecretvalue and issecretvalue(value) end

    local function ImprovedLifeTapRank()
        local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID()
        local config = configID and C_Traits.GetConfigInfo(configID)
        if not config then return 0 end
        for _, treeID in ipairs(config.treeIDs or {}) do
            for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if node and node.activeEntry and node.activeRank > 0 then
                    local entry = C_Traits.GetEntryInfo(configID, node.activeEntry.entryID)
                    local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                    if definition and definition.spellID == IMPROVED_LIFE_TAP then return node.activeRank end
                end
            end
        end
        return 0
    end

    -- Mana from the highest learned Life Tap rank: (rank base + effective Spirit) × (1 + 10% per Improved Life Tap
    -- point). nil without Life Tap or while Spirit is restricted.
    -- ponytail: no T1 5-piece bonus until its stacking with Improved Life Tap is verified.
    function module.LifeTapManaGain()
        for _, rank in ipairs(LIFE_TAP_RANKS) do
            if C_SpellBook.IsSpellKnown(rank[1]) then
                local _, spirit = UnitStat("player", 5)
                if Restricted(spirit) or type(spirit) ~= "number" then return end
                return math.floor((rank[2] + spirit) * (100 + 10 * ImprovedLifeTapRank()) / 100)
            end
        end
    end

    -- The fill's color: the bar's own (resource), the class color or a custom one.
    local function Color(id, default)
        local mode = Get(id .. "Color")
        if mode == "class" then
            local r, g, b = GetClassColor(class)
            return { r = r, g = g, b = b }
        elseif mode == "custom" then
            local r, g, b = CreateColorFromHexString(Get(id .. "CustomColor")):GetRGB()
            return { r = r, g = g, b = b }
        end
        return default
    end

    -- Blizzard's own bar art while the bar keeps its own color, else its flat texture tinted.
    local function Texture(id, atlas, color, default)
        if Get(id .. "Texture") == "flat" then return FLAT end
        if atlas and color == default then return atlas, true end
        return CLASSIC
    end

    local bars = {}
    local health = { id = "healthBar" }
    local power = { id = "powerBar" }
    local combo = { id = "comboPointsBar" }

    function health.IsAvailable() return true end
    function health.IsActive() return true end
    function health.Style()
        local color = Color(health.id, HEALTH_COLOR)
        return 1, color, Texture(health.id, HEALTH_ATLAS, color, HEALTH_COLOR)
    end
    function health.Values() return UnitHealth("player"), UnitHealthMax("player") end
    function health.Percent() return UnitHealthPercent("player", true, CurveConstants.ScaleTo100) end

    function power.IsAvailable() return true end
    function power.IsActive()
        local maximum = UnitPowerMax("player", powerType)
        return Restricted(maximum) or maximum > 0
    end
    function power.Style()
        local info = PowerBarColor[powerType] or PowerBarColor.MANA
        local default = { r = info.r, g = info.g, b = info.b }
        -- Only mana takes the class or custom color; rage and energy keep Blizzard's.
        local color = powerType == Enum.PowerType.Mana and Color(power.id, default) or default
        return 1, color, Texture(power.id, info.atlasElementName and POWER_ATLAS .. info.atlasElementName, color, default)
    end
    function power.Values() return UnitPower("player", powerType), UnitPowerMax("player", powerType) end
    function power.Percent() return UnitPowerPercent("player", powerType, false, CurveConstants.ScaleTo100) end

    function combo.IsAvailable() return module.comboPointClasses[class] == true end
    function combo.IsActive() return class == "ROGUE" or class == "DRUID" and GetShapeshiftFormID() == DRUID_CAT_FORM end
    function combo.Style()
        local info = PowerBarColor.COMBO_POINTS
        local default = { r = info.r, g = info.g, b = info.b }
        local color = Color(combo.id, default)
        return comboMaximum, color, Texture(combo.id, nil, color, default)
    end
    function combo.Values()
        if editing then return PREVIEW_COMBO_POINTS, comboMaximum end
        -- Classic keeps combo points on the target.
        return GetComboPoints("player", "target"), comboMaximum
    end

    local function IsShown(bar)
        if editing then return bar.IsAvailable() end
        if not bar.IsActive() then return false end
        if Get(bar.id .. "HideMounted") and (IsMounted() or TRAVEL_FORMS[GetShapeshiftFormID() or 0]) then return false end
        local visibility, target = Get(bar.id .. "Visibility"), UnitExists("target")
        return visibility == "always" or visibility == "combat" and inCombat or visibility == "target" and target
            or visibility == "targetOrCombat" and (inCombat or target)
    end

    -- An overlay of the first cell that starts at its fill's edge and runs length along the fill.
    local function AttachToFill(overlay, view, length)
        local fill = view.cells[1]:GetStatusBarTexture()
        overlay:ClearAllPoints()
        if view.vertical then
            overlay:SetPoint(view.reverse and "TOPLEFT" or "BOTTOMLEFT", fill, view.reverse and "BOTTOMLEFT" or "TOPLEFT")
            overlay:SetSize(view.cells[1]:GetWidth(), length)
        else
            overlay:SetPoint(view.reverse and "TOPRIGHT" or "TOPLEFT", fill, view.reverse and "TOPLEFT" or "TOPRIGHT")
            overlay:SetSize(length, view.cells[1]:GetHeight())
        end
    end

    -- Absorb shields continue the health fill, at the same scale.
    local function UpdateAbsorbs(maximum)
        local view = health.view
        if not view.absorbs then
            view.absorbs = CreateFrame("StatusBar", nil, view.cells[1])
            view.absorbs:SetStatusBarTexture(FLAT)
            view.absorbs:SetStatusBarColor(1, 1, 1, 0.35)
        end
        local absorbs = view.absorbs
        absorbs:SetShown(Get("healthBarAbsorbs") == true)
        if not absorbs:IsShown() then return end
        AttachToFill(absorbs, view, view.length)
        absorbs:SetOrientation(view.vertical and "VERTICAL" or "HORIZONTAL")
        absorbs:SetReverseFill(view.reverse)
        absorbs:SetMinMaxValues(0, maximum)
        absorbs:SetValue(UnitGetTotalAbsorbs("player") or 0)
    end

    -- A lighter segment from the mana fill's edge over the mana Life Tap would restore. The cell clips it at
    -- maximum mana, so current mana, which may be restricted, is never read.
    local function UpdateLifeTap(maximum)
        local view = power.view
        local show = class == "WARLOCK" and Get("powerBarLifeTap") == true and powerType == Enum.PowerType.Mana
            and lifeTapGain and not Restricted(maximum) and maximum > 0
        if not show then
            if view.lifeTap then view.lifeTap:Hide() end
            return
        end
        if not view.lifeTap then
            view.lifeTap = CreateFrame("Frame", nil, view.cells[1])
            view.lifeTap.texture = view.lifeTap:CreateTexture(nil, "OVERLAY")
            view.lifeTap.texture:SetAllPoints()
        end
        local _, color = power.Style()
        view.lifeTap.texture:SetColorTexture(color.r + (1 - color.r) * 0.2, color.g + (1 - color.g) * 0.2,
            color.b + (1 - color.b) * 0.2, 0.35)
        AttachToFill(view.lifeTap, view, view.length * math.min(lifeTapGain / maximum, 1))
        view.lifeTap:Show()
    end

    local function UpdateValues(bar)
        local view = bar.view
        if not view.frame:IsShown() then return end
        local current, maximum = bar.Values()
        view:SetValue(current, maximum)
        if bar.Percent and view.text:IsShown() then
            local format = Get(bar.id .. "TextFormat")
            if format == "currentMax" then view.text:SetFormattedText("%d / %d", current, maximum)
            elseif format == "percent" then view.text:SetFormattedText("%.0f%%", bar.Percent())
            elseif format == "both" then view.text:SetFormattedText("%d (%.0f%%)", current, bar.Percent())
            else view.text:SetFormattedText("%d", current) end
        end
        if bar == health then UpdateAbsorbs(maximum) elseif bar == power then UpdateLifeTap(maximum) end
    end

    -- Hides Blizzard's display under the character while the option is on. The player's own value waits in
    -- the account-wide profile store until the option is turned off, or the addon disabled (see
    -- ns.InitializeAddonModules). A client setting, so it waits for the end of combat.
    local function UpdatePersonalDisplay()
        if InCombatLockdown() then return end
        local store = PyresinQoLDB.profileStore
        local current = C_CVar.GetCVar("nameplateShowSelf")
        if current == nil then return end -- unavailable: never created
        if Get("powerBarHidePersonal") == true then
            if current ~= "0" then
                store.personalDisplay = store.personalDisplay or current
                C_CVar.SetCVar("nameplateShowSelf", "0")
            end
        elseif store.personalDisplay then
            if current == "0" then C_CVar.SetCVar("nameplateShowSelf", store.personalDisplay) end
            store.personalDisplay = nil
        end
    end

    local function UpdateBar(bar)
        local shown = IsShown(bar)
        bar.view.frame:SetShown(shown)
        if not shown then return end
        local count, color, texture, native = bar.Style()
        bar.view:Layout(count, texture, native and 1 or color.r, native and 1 or color.g, native and 1 or color.b)
        UpdateValues(bar)
    end

    function module.UpdateResourceBars()
        local readable = UnitPowerType("player")
        if not Restricted(readable) then powerType = readable end
        local maximum = UnitPowerMax("player", Enum.PowerType.ComboPoints)
        if not Restricted(maximum) and maximum > 0 then comboMaximum = maximum end
        lifeTapGain = class == "WARLOCK" and module.LifeTapManaGain() or nil
        UpdatePersonalDisplay()
        for _, bar in ipairs(bars) do UpdateBar(bar) end
    end

    -- Edit Mode shows every bar this class has, whatever its visibility, and a sample of combo points.
    function module.SetResourceBarPreview(enabled)
        editing = enabled
        module.UpdateResourceBars()
    end

    module.resourceBarViews = {}
    for _, bar in ipairs({ health, power, combo }) do
        bar.view = module.CreateResourceBarView(bar.id)
        bar.view.IsAvailable = bar.IsAvailable
        module.resourceBarViews[bar.id] = bar.view
        bars[#bars + 1] = bar
    end

    local VALUE_EVENTS = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_ABSORB_AMOUNT_CHANGED = true,
        UNIT_POWER_FREQUENT = true, UNIT_POWER_UPDATE = true }
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_TARGET_CHANGED", "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED",
        "TRAIT_CONFIG_UPDATED" }) do
        events:RegisterEvent(event)
    end
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_POWER_FREQUENT",
        "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_STATS" }) do
        events:RegisterUnitEvent(event, "player")
    end
    events:SetScript("OnEvent", function(_, event)
        -- InCombatLockdown is still false while PLAYER_REGEN_DISABLED is handled.
        if event == "PLAYER_REGEN_DISABLED" then inCombat = true elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false end
        if VALUE_EVENTS[event] then
            for _, bar in ipairs(bars) do UpdateValues(bar) end
        else
            module.UpdateResourceBars()
        end
    end)
    EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", module.UpdateResourceBars, events)
    module.UpdateResourceBars()
end)
