local _, ns = ...
local L = ns.L

-- A bar of flyout buttons, laid out like Blizzard's action bars, each opening its own menu of spells,
-- items, toys, mounts and macros dropped onto it. The buttons are Blizzard's action buttons and the menus
-- its flyout popup; secure snippets open and close them, so they work in combat. Contents are per character
-- (PyresinQoLFlyouts[button][slot] = { type, id }), the bar's options per profile.
local MAX = 12
local BUTTON_SIZE, SLOT_SIZE = 45, 30 -- ActionButtonTemplate, SmallActionButtonTemplate
local SPACING, INITIAL_SPACING, PADDING = 4, 9, 8 -- Blizzard's spell flyout
local module = ns.GetModule("flyouts")
-- Blizzard's action bar visibility, as state driver conditions.
local VISIBILITY = { always = "show", combat = "[combat] show; hide", outOfCombat = "[combat] hide; show", hidden = "hide" }
-- Where a menu sits on its button and grows from, per direction: its point, the button's, and the axis.
local DIRECTIONS = {
    UP = { point = "BOTTOM", relative = "TOP", x = 0, y = 1 },
    DOWN = { point = "TOP", relative = "BOTTOM", x = 0, y = -1 },
    LEFT = { point = "RIGHT", relative = "LEFT", x = -1, y = 0 },
    RIGHT = { point = "LEFT", relative = "RIGHT", x = 1, y = 0 },
}

-- Restricted snippets. A click that dropped something (see DropTarget) is cancelled; otherwise a flyout
-- button shows its own menu and hides the others (a right-click edits its name and icon instead, see
-- CreateButton), and a menu button closes its menu after its action.
local TOGGLE = ([[
    if self:GetAttribute("placing") or button == "RightButton" then return false end
    local own = owner:GetFrameRef("popup" .. self:GetAttribute("index"))
    for i = 1, %d do
        local popup = owner:GetFrameRef("popup" .. i)
        if popup and popup ~= own then popup:Hide() end
    end
    if own:IsShown() then own:Hide() else own:Show() end
    return false
]]):format(MAX)
local SLOT_CLICK = [[
    if self:GetAttribute("placing") then return false end
    return nil, true
]]

local function MountSpell(mountID) return (select(2, C_MountJournal.GetMountInfoByID(mountID))) end

-- Each kind of entry, by its saved type: its id's Lua type, how to pick it up, its icon and tooltip, the
-- spell or item whose cooldown and usability it shows, and the secure action that uses it (type, value).
local TYPES = {
    spell = {
        idType = "number",
        Pickup = function(id) C_Spell.PickupSpell(id) end,
        Icon = function(id) return C_Spell.GetSpellTexture(id) end,
        Tooltip = function(id) GameTooltip:SetSpellByID(id) end,
        Spell = function(id) return id end,
        Action = function(id) return "spell", id end,
    },
    item = {
        idType = "number",
        Pickup = function(id) C_Item.PickupItem(id) end,
        Icon = function(id) return C_Item.GetItemIconByID(id) end,
        Tooltip = function(id) GameTooltip:SetItemByID(id) end,
        Item = function(id) return id end,
        Action = function(id) return "item", "item:" .. id end,
    },
    toy = {
        idType = "number",
        Pickup = function(id) C_ToyBox.PickupToyBoxItem(id) end,
        Icon = function(id) return (select(3, C_ToyBox.GetToyInfo(id))) end,
        Tooltip = function(id) GameTooltip:SetToyByItemID(id) end,
        Item = function(id) return id end,
        Action = function(id) return "toy", id end,
    },
    mount = {
        idType = "number",
        -- The journal picks up by list position, so a mount its filters hide stays where it is.
        Pickup = function(id)
            for index = 1, C_MountJournal.GetNumDisplayedMounts() do
                if C_MountJournal.GetDisplayedMountID(index) == id then return C_MountJournal.Pickup(index) end
            end
        end,
        Icon = function(id) return (select(3, C_MountJournal.GetMountInfoByID(id))) end,
        Tooltip = function(id) GameTooltip:SetMountBySpellID(MountSpell(id)) end,
        Spell = MountSpell,
        Action = function(id) return "spell", MountSpell(id) end,
    },
    -- By name, as a macro's index moves.
    macro = {
        idType = "string",
        Pickup = function(name) PickupMacro(name) end,
        Icon = function(name) return (select(2, GetMacroInfo(name))) end,
        Tooltip = function(name) GameTooltip:SetText(name, HIGHLIGHT_FONT_COLOR:GetRGB()) end,
        Spell = function(name) return GetMacroSpell(name) end,
        Action = function(name) return "macro", name end,
    },
}

local function Valid(entry)
    local kind = type(entry) == "table" and TYPES[entry.type]
    return kind and type(entry.id) == kind.idType or false
end

-- What the cursor holds, as an entry. Toys are the one special case: they come as items.
local function CursorEntry()
    local kind, info, _, spellID = GetCursorInfo()
    if kind == "spell" and spellID then return { type = "spell", id = spellID } end
    if kind == "mount" then return { type = "mount", id = info } end
    if kind == "item" then return { type = PlayerHasToy(info) and "toy" or "item", id = info } end
    if kind == "macro" then
        local name = GetMacroInfo(info)
        if name then return { type = "macro", id = name } end
    end
end

-- Key bindings: Bindings.xml lists one per button, MAX in all.
local function Binding(i) return "CLICK PyresinQoLFlyoutButton" .. i .. ":LeftButton" end
BINDING_HEADER_PYRESINQOL = "PyresinQoL"
for i = 1, MAX do _G["BINDING_NAME_" .. Binding(i)] = L.flyoutsBinding:format(i) end

ns.RegisterModule("flyouts", function()
    -- Saved menus are checked once here, so reads can trust them: each a table of valid entries, with an
    -- optional name and icon.
    PyresinQoLFlyouts = type(PyresinQoLFlyouts) == "table" and PyresinQoLFlyouts or {}
    for i, menu in pairs(PyresinQoLFlyouts) do
        if type(menu) ~= "table" then PyresinQoLFlyouts[i] = nil
        else
            for j = 1, MAX do if not Valid(menu[j]) then menu[j] = nil end end
            if type(menu.name) ~= "string" then menu.name = nil end
            if type(menu.icon) ~= "number" and type(menu.icon) ~= "string" then menu.icon = nil end
        end
    end
    local defaults = {}
    for _, option in ipairs(module.flyoutOptions) do defaults[option.key] = option.default end
    local function Get(key)
        local value = PyresinQoLDB[key]
        if value == nil then return defaults[key] end
        return value
    end
    -- Menu(i) reads a menu, which may not exist yet; List(i) makes it for writing. Never write to what
    -- Menu(i) returns: a missing menu is the one shared NONE.
    local NONE = {}
    local function Menu(i) return PyresinQoLFlyouts[i] or NONE end
    local function List(i)
        PyresinQoLFlyouts[i] = PyresinQoLFlyouts[i] or {}
        return PyresinQoLFlyouts[i]
    end
    local function Entry(i, j) return Menu(i)[j] end
    local function SetEntry(i, j, entry) List(i)[j] = entry end
    -- A menu's own name and icon, kept with its entries; without an icon it shows its first entry's.
    local function DefaultName(i) return L.flyoutsDefaultName:format(i) end
    local function Name(i) return Menu(i).name or DefaultName(i) end
    local function MenuIcon(i)
        if Menu(i).icon then return Menu(i).icon end
        for j = 1, MAX do
            local entry = Entry(i, j)
            if entry then return TYPES[entry.type].Icon(entry.id) end
        end
    end

    -- The bar stays at scale 1 with the scaled size, for its saved position; content carries the scale.
    local bar = CreateFrame("Frame", "PyresinQoLFlyoutBar", UIParent, "SecureHandlerBaseTemplate")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local content = CreateFrame("Frame", nil, bar)
    content:SetPoint("CENTER")
    local buttons, Layout = {}, nil
    -- Changes to protected frames wait for the end of combat.
    local pending = {}
    local function OutOfCombat(Function)
        if not InCombatLockdown() then return true end
        pending[Function] = true
    end

    -- A menu button's look, as Blizzard's spell flyout buttons: cooldown, count, usable colour and the
    -- active spell checked, for the spell or item behind an entry.
    local function RefreshSlot(slot)
        local entry = Entry(slot.flyout, slot.slot)
        local kind = entry and TYPES[entry.type]
        local icon = kind and kind.Icon(entry.id)
        slot.icon:SetTexture(icon)
        slot.icon:SetShown(icon ~= nil)
        local spellID = kind and kind.Spell and kind.Spell(entry.id)
        local itemID = kind and kind.Item and kind.Item(entry.id)
        slot.spellID = spellID
        local usable, noMana, count = true, false, ""
        if spellID then
            ActionButton_UpdateCooldown(slot)
            usable, noMana = C_Spell.IsSpellUsable(spellID)
            count = C_Spell.GetSpellDisplayCount(spellID, 99)
            slot:SetChecked(C_Spell.IsCurrentSpell(spellID))
        else
            local start, duration, enable = 0, 0, false
            if itemID then
                start, duration, enable = C_Item.GetItemCooldown(itemID)
                usable, noMana = C_Item.IsUsableItem(itemID)
                if C_Item.IsConsumableItem(itemID) then count = C_Item.GetItemCount(itemID, false, true) end
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
            local icon = MenuIcon(i)
            button.icon:SetTexture(icon)
            button.icon:SetShown(icon ~= nil)
            if button.popup:IsShown() then
                for _, slot in ipairs(button.slots) do if slot:IsShown() then RefreshSlot(slot) end end
            end
        end
    end

    -- Makes frame take what the cursor holds by drag and, as on Blizzard's bars, by click: Drop() places it
    -- and returns true if it did, and PreClick then flags the click so the snippets cancel it.
    local function DropTarget(frame, Drop)
        frame:SetScript("OnReceiveDrag", Drop)
        frame:SetScript("PreClick", function(self)
            if Drop() then self:SetAttribute("placing", true) end
        end)
        frame:SetScript("PostClick", function(self)
            if not InCombatLockdown() then self:SetAttribute("placing", nil) end
        end)
    end

    local function CreateSlot(button, j)
        local popup, i = button.popup, button:GetAttribute("index")
        local slot = CreateFrame("CheckButton", nil, popup, "SmallActionButtonTemplate, SecureActionButtonTemplate")
        slot.flyout, slot.slot = i, j
        slot:RegisterForClicks("AnyUp")
        slot:RegisterForDrag("LeftButton", "RightButton")
        slot:SetAttribute("useOnKeyDown", false)
        popup:WrapScript(slot, "OnClick", SLOT_CLICK, "owner:Hide()")
        slot:HookScript("OnEnter", function(self)
            local entry = Entry(i, j)
            if not entry then return end
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            TYPES[entry.type].Tooltip(entry.id)
        end)
        slot:HookScript("OnLeave", function() GameTooltip:Hide() end)
        -- As on Blizzard's bars: dragging out takes the action off while the bars are unlocked or with the
        -- pickup modifier, if it reached the cursor; dropping on swaps it with what the cursor holds.
        slot:HookScript("OnDragStart", function()
            local entry = Entry(i, j)
            if not entry or InCombatLockdown() then return end
            if Settings.GetValue("lockActionBars") and not IsModifiedClick("PICKUPACTION") then return end
            TYPES[entry.type].Pickup(entry.id)
            if not GetCursorInfo() then return end
            SetEntry(i, j, nil)
            Layout()
        end)
        DropTarget(slot, function()
            local entry = CursorEntry()
            if not entry or InCombatLockdown() then return end
            local old = Entry(i, j)
            SetEntry(i, j, entry)
            ClearCursor()
            -- The old one goes to the cursor; if it cannot (a mount the journal's filters hide), it stays.
            if old then
                TYPES[old.type].Pickup(old.id)
                if not GetCursorInfo() then SetEntry(i, j, old) end
            end
            Layout()
            return true
        end)
        button.slots[j] = slot
        return slot
    end

    local function EditFlyout(i)
        module.OpenFlyoutEditor(Name(i), Menu(i).icon, function(name, icon)
            local list = List(i)
            list.name = name:match("%S") and name ~= DefaultName(i) and name or nil
            list.icon = icon
            Refresh()
        end)
    end

    local function RefreshHotkey(button)
        local key = GetBindingKey(Binding(button:GetAttribute("index")))
        button.HotKey:SetText(key and GetBindingText(key, 1) or "")
        button.HotKey:SetShown(key ~= nil)
    end

    -- Blizzard's Quick Keybind Mode, wired as on its own bars; its template would replace the secure OnClick.
    hooksecurefunc(ActionButtonUtil, "SetAllQuickKeybindButtonHighlights", function(show)
        for _, button in ipairs(buttons) do button:DoModeChange(show) end
    end)
    local function EnableQuickKeybind(button, command)
        Mixin(button, QuickKeybindButtonTemplateMixin)
        button.commandName = command
        local highlight = button:CreateTexture(nil, "OVERLAY")
        highlight:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.4)
        highlight:SetPoint("CENTER")
        highlight:SetSize(46, 45) -- ActionButtonTemplate's
        highlight:Hide()
        button.QuickKeybindHighlightTexture = highlight
        button:HookScript("OnEnter", button.QuickKeybindButtonOnEnter)
        button:HookScript("OnLeave", button.QuickKeybindButtonOnLeave)
        button:HookScript("PostClick", button.QuickKeybindButtonOnClick)
        button:DoModeChange(KeybindFrames_InQuickKeybindMode())
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
        -- An open menu fades out the buttons it covers, on bars with several rows. Alpha is not protected,
        -- so this works in combat too.
        local function Toggled()
            button:SetChecked(false)
            button:OnPopupToggled()
            local shown = popup:IsShown()
            local left, bottom, width, height = popup:GetRect()
            for _, other in ipairs(buttons) do
                local x, y, w, h = other:GetRect()
                local covered = shown and other ~= button and x and left
                    and x < left + width and left < x + w and y < bottom + height and bottom < y + h
                other:SetAlpha(covered and 0 or 1)
            end
            if shown then Refresh() end
        end
        popup:HookScript("OnShow", Toggled)
        popup:HookScript("OnHide", Toggled)
        button:SetPopup(popup)
        button.slots = {}
        bar:SetFrameRef("popup" .. i, popup)
        bar:WrapScript(button, "OnClick", TOGGLE)
        -- Dropping onto the button adds to its first free slot.
        DropTarget(button, function()
            local entry = CursorEntry()
            if not entry or InCombatLockdown() then return end
            for j = 1, Get("flyoutsSlots") do
                if not Entry(i, j) then
                    SetEntry(i, j, entry)
                    ClearCursor()
                    Layout()
                    return true
                end
            end
        end)
        -- A right-click that dropped nothing edits the menu's name and icon; TOGGLE leaves it unopened.
        button:HookScript("PreClick", function(self, mouseButton)
            if mouseButton == "RightButton" and not self:GetAttribute("placing") then EditFlyout(i) end
        end)
        -- Named like Blizzard's flyouts on its bars.
        button:HookScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetText(Name(i), HIGHLIGHT_FONT_COLOR:GetRGB())
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
        EnableQuickKeybind(button, Binding(i))
        buttons[i] = button
        RefreshHotkey(button)
        return button
    end

    function Layout()
        if not OutOfCombat(Layout) then return end
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
        local along = DIRECTIONS[direction]
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
                local horizontal = along.x ~= 0
                popup:SetSize(horizontal and length or button.popupCrossAxisSize, horizontal and button.popupCrossAxisSize or length)
                popup:ClearAllPoints()
                popup:SetPoint(along.point, button, along.relative, along.x * offset, along.y * offset)
                popup:UpdateBackground()

                for j = 1, MAX do
                    local slot = button.slots[j] or j <= slots and shown and CreateSlot(button, j)
                    if slot then
                        slot:SetShown(j <= slots)
                        -- The action reads only the attribute its type names, so stale ones are harmless.
                        local entry = Entry(i, j)
                        local action, value
                        if entry then action, value = TYPES[entry.type].Action(entry.id) end
                        slot:SetAttribute("type", action)
                        if action then slot:SetAttribute(action, value) end
                        local step = (j - 1) * (SLOT_SIZE + SPACING) + INITIAL_SPACING
                        slot:ClearAllPoints()
                        slot:SetPoint(along.point, along.x * step, along.y * step)
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

    -- Edit Mode shows the bar to move it. Set by the Edit Mode display's OnEnter and OnExit below.
    local editing = false
    local function ApplyVisibility()
        if not OutOfCombat(ApplyVisibility) then return end
        if editing then
            UnregisterStateDriver(bar, "visibility")
            bar:Show()
        else
            RegisterStateDriver(bar, "visibility", VISIBILITY[Get("flyoutsVisibility")] or "show")
        end
    end
    local function Update()
        Layout()
        ApplyVisibility()
    end
    module.UpdateFlyouts = Update

    bar:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            for Function in pairs(pending) do
                pending[Function] = nil
                Function()
            end
        elseif event == "UPDATE_BINDINGS" then
            for _, button in ipairs(buttons) do RefreshHotkey(button) end
        elseif event == "UPDATE_MACROS" or event == "PLAYER_ENTERING_WORLD" then
            Layout()
        else
            Refresh()
        end
    end)
    for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_MACROS", "UPDATE_BINDINGS",
        "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN",
        "BAG_UPDATE_DELAYED", "CURRENT_SPELL_CAST_CHANGED", "UNIT_POWER_FREQUENT" }) do
        if event == "UNIT_POWER_FREQUENT" then bar:RegisterUnitEvent(event, "player") else bar:RegisterEvent(event) end
    end

    local name, OpenDialog = "PyresinQoL · " .. L.flyouts, nil
    local display = ns.CreateEditModeDisplay(bar, {
        name = name, positionKey = "flyoutsPosition", default = { "BOTTOM", UIParent, "BOTTOM", 0, 280 },
        OnSelect = function() OpenDialog() end,
        OnEnter = function()
            editing = true
            ApplyVisibility()
        end,
        -- The menus open towards where the bar now sits.
        OnExit = function()
            editing = false
            Update()
        end,
    })
    OpenDialog = ns.CreateEditModeOptionsDialog(bar, {
        name = name, options = module.flyoutOptions, Get = Get, Format = module.FormatFlyoutOption,
    })
    EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", Update, bar)
    display.Restore()
    Update()
end)
