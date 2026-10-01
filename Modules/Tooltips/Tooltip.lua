local _, ns = ...
local L = ns.L

ns.RegisterModule("tooltips", function(module)
    local bar = GameTooltip.StatusBar
    local originalHeight = bar:GetHeight()
    local healthText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetPoint("CENTER")
    healthText:SetText("")
    local healthElapsed, hasHealthText = 0, false
    local guildLine, guildText
    local states = {}

    local function ClassColor(unit)
        local player = UnitIsPlayer(unit)
        if issecretvalue(player) or not player then return end
        local _, class = UnitClass(unit)
        if not issecretvalue(class) then return RAID_CLASS_COLORS[class] end
    end

    local function ReactionColor(unit)
        local reaction = UnitReaction(unit, "player")
        if not issecretvalue(reaction) then return FACTION_BAR_COLORS[reaction] end
    end

    local function ApplyColors(tooltip)
        local state, db = states[tooltip], PyresinQoLDB
        if not state then return end
        tooltip.NineSlice:SetCenterColor(unpack(state.background))
        tooltip.NineSlice:SetBorderColor(unpack(state.border))
        if not db then return end
        local border = db.tooltipCustomBorder and CreateColorFromHexString(db.tooltipBorderColor or "FFB2B2B2")
        local background = db.tooltipCustomBackground and CreateColorFromHexString(db.tooltipBackgroundColor or "FF000000")
        if state.quality then
            local r, g, b = C_Item.GetItemQualityColor(state.quality)
            local quality = CreateColor(r, g, b)
            if db.tooltipItemQualityBorder then border = quality end
            if db.tooltipItemQualityBackground then background = quality end
        elseif state.unit then
            local class = (db.tooltipUnitClassBorder or db.tooltipUnitClassBackground) and ClassColor(state.unit)
            local reaction = (db.tooltipUnitReactionBorder or db.tooltipUnitReactionBackground) and ReactionColor(state.unit)
            if db.tooltipUnitClassBorder and class then border = class
            elseif db.tooltipUnitReactionBorder and reaction then border = reaction end
            if db.tooltipUnitClassBackground and class then background = class
            elseif db.tooltipUnitReactionBackground and reaction then background = reaction end
        end
        if border then tooltip.NineSlice:SetBorderColor(border.r, border.g, border.b, db.tooltipBorderOpacity or 1) end
        if background then tooltip.NineSlice:SetCenterColor(background.r, background.g, background.b, db.tooltipBackgroundOpacity or 0.9) end
    end

    local function IsWorldObject(tooltip)
        local info = tooltip:GetPrimaryTooltipInfo()
        local data = tooltip:GetPrimaryTooltipData()
        return not issecretvalue(info) and info and not issecretvalue(info.getterName) and info.getterName == "GetWorldCursor"
            and not issecretvalue(data) and data and not issecretvalue(data.type) and data.type == Enum.TooltipDataType.Object
    end

    local function ApplyAnchor()
        local tooltip, db = GameTooltip, PyresinQoLDB
        local state = states[tooltip]
        if not db or not (state.defaultAnchor or IsWorldObject(tooltip)) then return end
        if not state.nativeAnchor then
            state.nativeAnchor = tooltip:GetAnchorType()
            state.nativePoint = { tooltip:GetPoint(1) }
        end
        local mode = db.tooltipAnchor or "default"
        local data = tooltip:GetPrimaryTooltipData()
        local owner = tooltip:GetOwner()
        tooltip:ClearAllPoints()
        if db.tooltipAnchorCombat and InCombatLockdown() then
            tooltip:SetAnchorType(state.nativeAnchor)
            if state.nativePoint[1] then tooltip:SetPoint(unpack(state.nativePoint)) end
        elseif not issecretvalue(data) and data and not issecretvalue(data.type) and data.type == Enum.TooltipDataType.Spell
            and db.tooltipAnchorSpells and owner and owner ~= UIParent then
            tooltip:SetAnchorType("ANCHOR_RIGHT")
        elseif mode == "cursor" then
            tooltip:SetAnchorType(db.tooltipCursorAnchor or "ANCHOR_CURSOR_RIGHT",
                db.tooltipCursorX or 16, db.tooltipCursorY or 8)
        elseif mode == "fixed" then
            local point = db.tooltipAnchorPoint or "BOTTOMRIGHT"
            tooltip:SetAnchorType("ANCHOR_NONE")
            tooltip:SetPoint(point, UIParent, point, db.tooltipAnchorX or -30, db.tooltipAnchorY or 120)
        elseif IsWorldObject(tooltip) and db.tooltipObjectCursor then
            tooltip:SetAnchorType("ANCHOR_CURSOR")
        else
            tooltip:SetAnchorType(state.nativeAnchor)
            if state.nativePoint[1] then tooltip:SetPoint(unpack(state.nativePoint)) end
        end
    end

    local function TrackTooltip(tooltip)
        if states[tooltip] then return states[tooltip] end
        local state = { lines = {}, background = { tooltip.NineSlice:GetCenterColor() }, border = { tooltip.NineSlice:GetBorderColor() } }
        states[tooltip] = state
        tooltip:HookScript("OnTooltipCleared", function()
            state.lines, state.unit, state.quality, state.targetVisible = {}, nil, nil, nil
            ApplyColors(tooltip)
        end)
        tooltip:HookScript("OnShow", function()
            ApplyColors(tooltip)
            if tooltip == GameTooltip then ApplyAnchor() end
        end)
        tooltip:HookScript("OnHide", function()
            state.defaultAnchor, state.nativeAnchor, state.nativePoint = nil, nil, nil
            tooltip.NineSlice:SetCenterColor(unpack(state.background))
            tooltip.NineSlice:SetBorderColor(unpack(state.border))
        end)
        return state
    end

    local function SupportedTooltip(tooltip)
        return tooltip == GameTooltip or tooltip == ItemRefTooltip
            or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2
            or tooltip == ItemRefShoppingTooltip1 or tooltip == ItemRefShoppingTooltip2
    end

    local function ValueLine(tooltip, key, label, value)
        if issecretvalue(value) or type(value) ~= "number" or value <= 0 then return end
        local state = TrackTooltip(tooltip)
        local line = state.lines[key]
        if not line then
            tooltip:AddDoubleLine(label, ("%d"):format(value), 1, 1, 1, 1, 0.75, 0)
            line = tooltip:GetRightLine(tooltip:NumLines())
            state.lines[key] = line
        end
        line:SetFormattedText("%d", value)
    end

    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
        "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
        if _G[name] then TrackTooltip(_G[name]) end
    end
    hooksecurefunc(GameTooltip, "SetOwner", function()
        local state = states[GameTooltip]
        state.defaultAnchor, state.nativeAnchor, state.nativePoint = nil, nil, nil
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
        if tooltip == GameTooltip then states[tooltip].defaultAnchor = true end
    end)
    -- Native item styles are applied after the data callbacks; tint their existing NineSlice last.
    hooksecurefunc("SharedTooltip_SetBackdropStyle", ApplyColors)
    GameTooltip:RegisterEvent("PLAYER_REGEN_DISABLED")
    GameTooltip:RegisterEvent("PLAYER_REGEN_ENABLED")
    GameTooltip:HookScript("OnEvent", function(_, event)
        if GameTooltip:IsShown() and (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED") then ApplyAnchor() end
    end)

    local function ClearHealth()
        healthElapsed = 0
        if hasHealthText then
            healthText:SetText("")
            hasHealthText = false
        end
    end

    local function GetUnit()
        local _, unit = GameTooltip:GetUnit()
        if not issecretvalue(unit) then return unit end
    end

    local function UpdateHealth()
        healthElapsed = 0
        if not PyresinQoLDB or not PyresinQoLDB.tooltipHealth then
            ClearHealth()
            return
        end
        local unit = GetUnit()
        -- Blizzard clears unit data before fading; keep the last text until hide/clear.
        if not unit then return end
        -- Pass restricted HP straight to the native formatter; never inspect or calculate with it.
        healthText:SetFormattedText("%d / %d", UnitHealth(unit), UnitHealthMax(unit))
        hasHealthText = true
    end

    local function UpdateGuildRank()
        if guildLine then guildLine:SetText(guildText) end
        guildLine, guildText = nil, nil
        local unit = GetUnit()
        if not PyresinQoLDB or not PyresinQoLDB.tooltipGuildRank or not unit then return end
        local guild, rank = GetGuildInfo(unit)
        if issecretvalue(guild) or issecretvalue(rank) or not guild or not rank or rank == "" then return end
        for index = 2, GameTooltip:NumLines() do
            local line = GameTooltip:GetLeftLine(index)
            local text = line:GetText()
            if not issecretvalue(text) and text and text:find(guild, 1, true) then
                guildLine, guildText = line, text
                local first, last = text:find(guild, 1, true)
                if text:sub(first - 1, first - 1) == "<" and text:sub(last + 1, last + 1) == ">" then
                    first, last = first - 1, last + 1
                end
                line:SetFormattedText("%s|cff40ff40<%s>|r%s |cff909090%s|r",
                    text:sub(1, first - 1), guild, text:sub(last + 1), rank)
                return
            end
        end
    end

    local function UpdateTarget()
        local db = PyresinQoLDB
        if not db or not db.tooltipTarget then return end
        local unit = GetUnit()
        if not unit then return end
        local target = unit .. "target"
        local exists = UnitExists(target)
        local state = states[GameTooltip]
        if issecretvalue(exists) or not exists then
            if state.targetVisible then
                state.targetVisible = false
                GameTooltip:RefreshDataNextUpdate()
            end
            return
        end
        if not state.lines.target then
            GameTooltip:AddDoubleLine(L.tooltipTargetLine, " ", 1, 1, 1, 1, 1, 1)
            state.lines.target = GameTooltip:GetRightLine(GameTooltip:NumLines())
        end
        state.targetVisible = true
        local line = state.lines.target
        local player = UnitIsUnit(target, "player")
        if not issecretvalue(player) and player then
            line:SetFormattedText(">>%s<<", YOU)
        else
            -- Names may be restricted. Only the native formatter sees their contents.
            line:SetFormattedText("%s", UnitName(target))
        end
        local color = ClassColor(target) or ReactionColor(target)
        if color then line:SetTextColor(color.r, color.g, color.b)
        else line:SetTextColor(1, 1, 1) end
        -- Let the native tooltip resize without measuring potentially restricted names.
        if GameTooltip:IsShown() then GameTooltip:Show() end
    end

    local function UpdateUnit()
        bar:SetHeight(PyresinQoLDB and PyresinQoLDB.tooltipHealth and 14 or originalHeight)
        UpdateHealth()
        UpdateGuildRank()
        UpdateTarget()
    end

    function module.UpdateTooltips()
        UpdateUnit()
        for tooltip in pairs(states) do
            ApplyColors(tooltip)
            if tooltip:IsShown() and tooltip:GetPrimaryTooltipInfo() and tooltip.RefreshDataNextUpdate then
                tooltip:RefreshDataNextUpdate()
            end
        end
        ApplyAnchor()
    end

    bar:HookScript("OnUpdate", function(_, elapsed)
        if not PyresinQoLDB or not (PyresinQoLDB.tooltipHealth or PyresinQoLDB.tooltipTarget) then return end
        healthElapsed = healthElapsed + elapsed
        if healthElapsed >= 0.1 then UpdateHealth(); UpdateTarget() end
    end)
    GameTooltip:HookScript("OnHide", ClearHealth)
    GameTooltip:HookScript("OnTooltipCleared", function()
        guildLine, guildText = nil, nil
        ClearHealth()
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip)
        if tooltip == GameTooltip then ApplyAnchor() end
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip ~= GameTooltip then return end
        states[tooltip].unit = GetUnit()
        UpdateUnit()
        ApplyColors(tooltip)
        ApplyAnchor()
        local unit = GetUnit()
        if unit then
            local color = ClassColor(unit)
            if color then tooltip:GetLeftLine(1):SetTextColor(color.r, color.g, color.b) end
        end
        for index = 2, tooltip:NumLines() do
            local line = tooltip:GetLeftLine(index)
            local text = line:GetText()
            if not issecretvalue(text) then
                if text == FACTION_ALLIANCE then
                    line:SetTextColor(0.25, 0.5, 1)
                    line:SetFormattedText("|A:UI-Character-Info-Honor-Icon-Alliance:16:16|a %s", text)
                elseif text == FACTION_HORDE then
                    line:SetTextColor(1, 0.2, 0.2)
                    line:SetFormattedText("|A:UI-Character-Info-Honor-Icon-Horde:16:16|a %s", text)
                end
            end
        end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not SupportedTooltip(tooltip) or not PyresinQoLDB or issecretvalue(data) or not data then return end
        local primary = tooltip:GetPrimaryTooltipData()
        if issecretvalue(primary) or primary ~= data then return end
        local state = TrackTooltip(tooltip)
        local db, id = PyresinQoLDB, data.id
        state.quality = nil
        if not issecretvalue(id) and type(id) == "number" and id > 0 then
            if db.tooltipItemID then ValueLine(tooltip, "itemID", L.tooltipItemIDLine, id) end
            if db.tooltipItemIconID then
                local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
                ValueLine(tooltip, "iconID", L.tooltipIconIDLine, icon)
            end
            if db.tooltipItemStack or db.tooltipItemQualityBorder or db.tooltipItemQualityBackground then
                local _, _, quality, _, _, _, _, stack = C_Item.GetItemInfo(id)
                if not issecretvalue(quality) then state.quality = quality end
                if db.tooltipItemStack then ValueLine(tooltip, "stack", L.tooltipStackLine, stack) end
            end
        end
        ApplyColors(tooltip)
        if tooltip == GameTooltip then ApplyAnchor() end
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        if not SupportedTooltip(tooltip) or not PyresinQoLDB or issecretvalue(data) or not data then return end
        local primary = tooltip:GetPrimaryTooltipData()
        if issecretvalue(primary) or primary ~= data then return end
        TrackTooltip(tooltip)
        local db, id = PyresinQoLDB, data.id
        if not issecretvalue(id) and type(id) == "number" and id > 0 then
            if db.tooltipSpellID then ValueLine(tooltip, "spellID", L.tooltipSpellIDLine, id) end
            if db.tooltipSpellIconID then ValueLine(tooltip, "iconID", L.tooltipIconIDLine, C_Spell.GetSpellTexture(id)) end
        end
        ApplyColors(tooltip)
        if tooltip == GameTooltip then ApplyAnchor() end
    end)
end)
