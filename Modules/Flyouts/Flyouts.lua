local _, ns = ...
local L = ns.L

-- A bar of flyout buttons, laid out like Blizzard's action bars, each opening its own menu of spells,
-- items and macros dropped onto it. The buttons are Blizzard's action buttons and the menus its flyout
-- popup; secure snippets open and close them, so they work in combat. Contents are per character
-- (PyresinQoLFlyouts[button][slot] = { type, id }), the bar's options per profile.
local MAX = 12
local BUTTON_SIZE, SLOT_SIZE = 45, 30 -- ActionButtonTemplate, SmallActionButtonTemplate
local SPACING, INITIAL_SPACING, PADDING = 4, 9, 8 -- Blizzard's spell flyout
local module = ns.GetModule("flyouts")

-- Restricted snippets. A flyout button shows its own menu and hides the others; a menu button closes
-- its menu after its action.
local TOGGLE = [[
    local own = owner:GetFrameRef("popup" .. self:GetAttribute("index"))
    for i = 1, 12 do
        local popup = owner:GetFrameRef("popup" .. i)
        if popup and popup ~= own then popup:Hide() end
    end
    if own:IsShown() then own:Hide() else own:Show() end
    return false
]]

local function Valid(entry)
    if type(entry) ~= "table" then return false end
    if entry.type == "spell" or entry.type == "item" then return type(entry.id) == "number" end
    return entry.type == "macro" and type(entry.id) == "string"
end

-- What the cursor holds, as an entry; macros by name, as their index moves.
local function CursorEntry()
    local kind, info, _, spellID = GetCursorInfo()
    if kind == "spell" and spellID then return { type = "spell", id = spellID } end
    if kind == "item" then return { type = "item", id = info } end
    if kind == "macro" then
        local name = GetMacroInfo(info)
        if name then return { type = "macro", id = name } end
    end
end

local function Pickup(entry)
    if entry.type == "spell" then C_Spell.PickupSpell(entry.id)
    elseif entry.type == "item" then C_Item.PickupItem(entry.id)
    else PickupMacro(entry.id) end
end

local function Icon(entry)
    if entry.type == "spell" then return C_Spell.GetSpellTexture(entry.id) end
    if entry.type == "item" then return C_Item.GetItemIconByID(entry.id) end
    return select(2, GetMacroInfo(entry.id))
end

ns.RegisterModule("flyouts", function()
    PyresinQoLFlyouts = type(PyresinQoLFlyouts) == "table" and PyresinQoLFlyouts or {}
    local defaults = {}
    for _, option in ipairs(module.flyoutOptions) do defaults[option.key] = option.default end
    local function Get(key)
        local value = PyresinQoLDB[key]
        if value == nil then return defaults[key] end
        return value
    end
    local function Entry(i, j)
        local list = PyresinQoLFlyouts[i]
        local entry = type(list) == "table" and list[j]
        return Valid(entry) and entry or nil
    end
    local function SetEntry(i, j, entry)
        if type(PyresinQoLFlyouts[i]) ~= "table" then PyresinQoLFlyouts[i] = {} end
        PyresinQoLFlyouts[i][j] = entry
    end

    -- The bar stays at scale 1 with the scaled size, for its saved position; content carries the scale.
    local bar = CreateFrame("Frame", "PyresinQoLFlyoutBar", UIParent, "SecureHandlerBaseTemplate")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local content = CreateFrame("Frame", nil, bar)
    content:SetPoint("CENTER")
    local buttons, Layout = {}, nil

    -- A menu button's look, as Blizzard's spell flyout buttons: cooldown, count, usable colour and the
    -- active spell checked. Macros show the spell they cast.
    local function RefreshSlot(slot)
        local entry = Entry(slot.flyout, slot.slot)
        local icon = entry and Icon(entry)
        slot.icon:SetTexture(icon)
        slot.icon:SetShown(icon ~= nil)
        local spellID
        if entry and entry.type == "spell" then spellID = entry.id
        elseif entry and entry.type == "macro" then spellID = GetMacroSpell(entry.id) end
        slot.spellID = spellID
        local usable, noMana, count = true, false, ""
        if spellID then
            ActionButton_UpdateCooldown(slot)
            usable, noMana = C_Spell.IsSpellUsable(spellID)
            count = C_Spell.GetSpellDisplayCount(spellID, 99)
            slot:SetChecked(C_Spell.IsCurrentSpell(spellID))
        else
            local start, duration, enable = 0, 0, false
            if entry and entry.type == "item" then
                start, duration, enable = C_Item.GetItemCooldown(entry.id)
                usable, noMana = C_Item.IsUsableItem(entry.id)
                if C_Item.IsConsumableItem(entry.id) then count = C_Item.GetItemCount(entry.id, false, true) end
            end
            ActionButton_ApplyCooldown(slot.cooldown, { startTime = start, duration = duration, modRate = 1,
                isEnabled = enable, isActive = enable and duration > 0 }, slot.chargeCooldown, nil, slot.lossOfControlCooldown)
            slot:SetChecked(false)
        end
        slot.Count:SetText(count)
        if usable then slot.icon:SetVertexColor(1, 1, 1)
        elseif noMana then slot.icon:SetVertexColor(0.5, 0.5, 1)
        else slot.icon:SetVertexColor(0.4, 0.4, 0.4) end
    end

    local function Refresh()
        for i, button in ipairs(buttons) do
            local icon
            for j = 1, MAX do
                local entry = Entry(i, j)
                icon = entry and Icon(entry)
                if icon then break end
            end
            button.icon:SetTexture(icon)
            button.icon:SetShown(icon ~= nil)
            if button.popup:IsShown() then
                for _, slot in ipairs(button.slots) do if slot:IsShown() then RefreshSlot(slot) end end
            end
        end
    end

    local function CreateSlot(button, j)
        local popup, i = button.popup, button:GetAttribute("index")
        local slot = CreateFrame("CheckButton", nil, popup, "SmallActionButtonTemplate, SecureActionButtonTemplate")
        slot.flyout, slot.slot = i, j
        slot:RegisterForClicks("AnyUp")
        slot:RegisterForDrag("LeftButton", "RightButton")
        slot:SetAttribute("useOnKeyDown", false)
        popup:WrapScript(slot, "OnClick", "return nil, true", "owner:Hide()")
        slot:HookScript("OnEnter", function(self)
            local entry = Entry(i, j)
            if not entry then return end
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            if entry.type == "spell" then GameTooltip:SetSpellByID(entry.id)
            elseif entry.type == "item" then GameTooltip:SetItemByID(entry.id)
            else GameTooltip:SetText(entry.id, HIGHLIGHT_FONT_COLOR:GetRGB()) end
        end)
        slot:HookScript("OnLeave", function() GameTooltip:Hide() end)
        -- As on Blizzard's bars: dragging out takes the action off while the bars are unlocked or with the
        -- pickup modifier; dropping on swaps it with what the cursor holds.
        slot:HookScript("OnDragStart", function()
            local entry = Entry(i, j)
            if not entry or InCombatLockdown() then return end
            if Settings.GetValue("lockActionBars") and not IsModifiedClick("PICKUPACTION") then return end
            SetEntry(i, j, nil)
            Pickup(entry)
            Layout()
        end)
        slot:SetScript("OnReceiveDrag", function()
            local entry = CursorEntry()
            if not entry or InCombatLockdown() then return end
            local old = Entry(i, j)
            SetEntry(i, j, entry)
            ClearCursor()
            if old then Pickup(old) end
            Layout()
        end)
        button.slots[j] = slot
        return slot
    end

    local function CreateButton(i)
        local button = CreateFrame("CheckButton", "PyresinQoLFlyoutButton" .. i, content,
            "ActionButtonTemplate, SecureActionButtonTemplate")
        button:SetAttribute("index", i)
        button:RegisterForClicks("AnyUp")
        -- The popup is ours, not an action's: keep it through attribute changes, and open or closed by the
        -- snippets alone.
        function button.UpdateFlyoutPopup() end
        function button.ClosePopup() end
        function button:IsPopupOpen() return self.popup:IsShown() end
        local popup = CreateFrame("Frame", nil, button, "SecureHandlerBaseTemplate, FlyoutPopupTemplate")
        popup:Hide()
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(10)
        popup:EnableMouse(true)
        popup:SetBorderColor(0.7, 0.7, 0.7)
        function popup.GetDirection() return button:GetPopupDirection() end
        function popup.GetCrossAxisSize() return button.popupCrossAxisSize end
        local function Toggled()
            button:SetChecked(false)
            button:OnPopupToggled()
            if popup:IsShown() then Refresh() end
        end
        popup:HookScript("OnShow", Toggled)
        popup:HookScript("OnHide", Toggled)
        button:SetPopup(popup)
        button.slots = {}
        bar:SetFrameRef("popup" .. i, popup)
        bar:WrapScript(button, "OnClick", TOGGLE)
        -- Dropping onto the button adds to its first free slot.
        button:SetScript("OnReceiveDrag", function()
            local entry = CursorEntry()
            if not entry or InCombatLockdown() then return end
            for j = 1, Get("flyoutsSlots") do
                if not Entry(i, j) then
                    SetEntry(i, j, entry)
                    ClearCursor()
                    Layout()
                    return
                end
            end
        end)
        buttons[i] = button
        return button
    end

    local pending
    function Layout()
        if InCombatLockdown() then pending = true; return end
        pending = false
        local icons, slots, padding = Get("flyoutsIcons"), Get("flyoutsSlots"), Get("flyoutsPadding")
        local vertical = Get("flyoutsOrientation") == "vertical"
        local perLine = math.ceil(icons / Get("flyoutsRows"))
        local lines = math.ceil(icons / perLine)
        -- Blizzard's rule for its bars' flyouts: towards the screen's middle.
        local x, y = bar:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        local direction
        if vertical then direction = x and x > centerX and "LEFT" or "RIGHT"
        else direction = y and y > centerY and "DOWN" or "UP" end
        local length = INITIAL_SPACING + slots * (SLOT_SIZE + SPACING) - SPACING + PADDING

        for i = 1, MAX do
            local button = buttons[i] or i <= icons and CreateButton(i)
            if button then
                local shown = i <= icons
                button:SetShown(shown)
                if not shown then button.popup:Hide() end
                local line, position = math.floor((i - 1) / perLine), (i - 1) % perLine
                local column, row = position, line
                if vertical then column, row = line, position end
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", column * (BUTTON_SIZE + padding), -row * (BUTTON_SIZE + padding))
                button:SetPopupDirection(direction)

                local popup, offset = button.popup, button.popupOffset
                local horizontal = direction == "LEFT" or direction == "RIGHT"
                popup:SetSize(horizontal and length or button.popupCrossAxisSize, horizontal and button.popupCrossAxisSize or length)
                popup:ClearAllPoints()
                if direction == "UP" then popup:SetPoint("BOTTOM", button, "TOP", 0, offset)
                elseif direction == "DOWN" then popup:SetPoint("TOP", button, "BOTTOM", 0, -offset)
                elseif direction == "LEFT" then popup:SetPoint("RIGHT", button, "LEFT", -offset, 0)
                else popup:SetPoint("LEFT", button, "RIGHT", offset, 0) end
                popup:UpdateBackground()

                for j = 1, MAX do
                    local slot = button.slots[j] or j <= slots and shown and CreateSlot(button, j)
                    if slot then
                        slot:SetShown(j <= slots)
                        local entry = Entry(i, j)
                        slot:SetAttribute("type", entry and entry.type)
                        slot:SetAttribute("spell", entry and entry.type == "spell" and entry.id or nil)
                        slot:SetAttribute("item", entry and entry.type == "item" and "item:" .. entry.id or nil)
                        slot:SetAttribute("macro", entry and entry.type == "macro" and entry.id or nil)
                        local step = (j - 1) * (SLOT_SIZE + SPACING) + INITIAL_SPACING
                        slot:ClearAllPoints()
                        if direction == "UP" then slot:SetPoint("BOTTOM", 0, step)
                        elseif direction == "DOWN" then slot:SetPoint("TOP", 0, -step)
                        elseif direction == "LEFT" then slot:SetPoint("RIGHT", -step, 0)
                        else slot:SetPoint("LEFT", step, 0) end
                    end
                end
            end
        end

        local scale = Get("flyoutsIconSize") / 100
        local width = perLine * (BUTTON_SIZE + padding) - padding
        local height = lines * (BUTTON_SIZE + padding) - padding
        if vertical then width, height = height, width end
        content:SetScale(scale)
        content:SetSize(width, height)
        bar:SetSize(width * scale, height * scale)
        Refresh()
    end
    module.UpdateFlyouts = Layout

    bar:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then Layout() end
        elseif event == "UPDATE_MACROS" or event == "PLAYER_ENTERING_WORLD" then
            Layout()
        else
            Refresh()
        end
    end)
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_MACROS", "SPELLS_CHANGED",
        "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN",
        "BAG_UPDATE_DELAYED", "CURRENT_SPELL_CAST_CHANGED", "UNIT_POWER_FREQUENT" }) do
        if event == "UNIT_POWER_FREQUENT" then bar:RegisterUnitEvent(event, "player") else bar:RegisterEvent(event) end
    end

    local name, OpenDialog = "PyresinQoL · " .. L.flyouts, nil
    local entry = ns.CreateEditModeDisplay(bar, {
        name = name, positionKey = "flyoutsPosition", default = { "BOTTOM", UIParent, "BOTTOM", 0, 280 },
        OnSelect = function() OpenDialog() end,
        -- The menus open towards where the bar now sits.
        OnExit = Layout,
    })
    OpenDialog = ns.CreateEditModeOptionsDialog(bar, {
        name = name, options = module.flyoutOptions, Get = Get, Format = module.FormatFlyoutOption,
    })
    EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", Layout, bar)
    entry.Restore()
    Layout()
end)
