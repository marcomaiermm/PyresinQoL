local _, ns = ...

ns.RegisterModule("actionBars", function(module)
    local config = ns.ActionBars
    local buttons, buttonState = {}, setmetatable({}, { __mode = "k" })
    local nativeStyle = setmetatable({}, { __mode = "k" })
    local restoring = setmetatable({}, { __mode = "k" })
    local hooked

    local buttonPrefixes = {
        Main = "ActionButton", Bar2 = "MultiBarBottomLeftButton", Bar3 = "MultiBarBottomRightButton",
        Bar4 = "MultiBarRightButton", Bar5 = "MultiBarLeftButton", Bar6 = "MultiBar5Button",
        Bar7 = "MultiBar6Button", Bar8 = "MultiBar7Button",
    }

    local function secret(value)
        return issecretvalue and issecretvalue(value)
    end

    local function publicAction(button)
        local action = button.action
        if action == nil or secret(action) or type(action) ~= "number"
            or action < 1 or action ~= math.floor(action) then return end
        return action
    end

    local function color(hex)
        local a, r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)(%x%x)$")
        return CreateColor(tonumber(r, 16) / 255, tonumber(g, 16) / 255,
            tonumber(b, 16) / 255, tonumber(a, 16) / 255)
    end

    local function choose(value, yes, no)
        if value == nil then return no end
        if secret(value) then
            if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean then
                return C_CurveUtil.EvaluateColorFromBoolean(value, yes, no)
            end
            return no
        end
        return value and yes or no
    end

    local function setColor(region, value)
        if not region or not value then return end
        region:SetVertexColor(value:GetRGBA())
    end

    local function rememberColor(region)
        return region and region.GetVertexColor and { region:GetVertexColor() } or nil
    end

    local function restoreColor(region, saved)
        if region and saved then region:SetVertexColor(unpack(saved)) end
    end

    local function stateColor(state, kind)
        local normal = kind == "Icon" and CreateColor(1, 1, 1, 1)
            or ACTIONBAR_HOTKEY_FONT_COLOR or CreateColor(1, 1, 1, 1)
        local range = color(config.Get("actionBarRange" .. kind .. "Color"))
        local unusable = color(config.Get("actionBarUnusable" .. kind .. "Color"))
        local mana = color(config.Get("actionBarMana" .. kind .. "Color"))
        local result = choose(state.checksRange, choose(state.inRange, normal, range), normal)
        result = choose(state.usable, result, unusable)
        return choose(state.noMana, mana, result)
    end

    local function rememberFont(region)
        if not region or not region.GetFont then return end
        local path, size, flags = region:GetFont()
        return { path = path, size = size, flags = flags,
            object = region.GetFontObject and region:GetFontObject() }
    end

    local function restoreFont(region, saved)
        if not region or not saved then return end
        if saved.path and saved.size then
            region:SetFont(saved.path, saved.size, saved.flags)
        elseif saved.object and region.SetFontObject then
            region:SetFontObject(saved.object)
        end
    end

    local function resizeFont(region, saved, size)
        if not region or not saved then return end
        if size > 0 and saved.path then
            region:SetFont(saved.path, size, saved.flags)
            saved.customized = true
        elseif saved.customized then
            restoreFont(region, saved)
            saved.customized = nil
        end
    end

    local function binding(button)
        local action = button.bindingAction
        local name = button.GetName and button:GetName()
        return action and GetBindingKey(action) or name and GetBindingKey("CLICK " .. name .. ":LeftButton")
    end

    local function compactBinding(button)
        local key = binding(button)
        if not key or (IsBindingForGamePad and IsBindingForGamePad(key)) then
            return key and GetBindingText(key, 1) or nil
        end
        local mods, short = "", { SHIFT = "S", CTRL = "C", ALT = "A", META = "M" }
        while true do
            local modifier, rest = key:match("^([A-Z]+)%-(.+)$")
            if not short[modifier] then break end
            mods, key = mods .. short[modifier], rest
        end
        key = key:gsub("^MOUSEWHEELUP$", "WU"):gsub("^MOUSEWHEELDOWN$", "WD")
            :gsub("^BUTTON", "M"):gsub("^NUMPAD", "N")
        return mods .. (GetBindingText(key, 1) or key)
    end

    local function applyText(button)
        local saved = nativeStyle[button]
        if not saved then return end
        resizeFont(button.HotKey, saved.hotkey, config.Get("actionBarHotkeySize"))
        resizeFont(button.Name, saved.macro, config.Get("actionBarMacroSize"))
        resizeFont(button.Count, saved.count, config.Get("actionBarCountSize"))
        if config.Get("actionBarCompactHotkeys") and button.HotKey then
            local text = compactBinding(button)
            if text and text ~= "" then button.HotKey:SetText(text); button.HotKey:Show() end
        end
    end

    local function applyColors(button)
        if not nativeStyle[button] then return end
        local state = buttonState[button]
        if not state or state.usable == nil or state.noMana == nil then return end
        local icon = button.Icon or button.icon
        if config.Get("actionBarColorIcons") then setColor(icon, stateColor(state, "Icon")) end
        if config.Get("actionBarColorHotkeys") and button.HotKey and binding(button) then
            setColor(button.HotKey, stateColor(state, "Hotkey"))
        end
    end

    local function restoreNative(button)
        local saved = nativeStyle[button]
        if not config.Get("actionBarColorIcons") then restoreColor(button.Icon or button.icon, saved.iconColor) end
        if not config.Get("actionBarColorHotkeys") then restoreColor(button.HotKey, saved.hotkeyColor) end
    end

    local function refreshUsable(button, state)
        local action = publicAction(button)
        if state.action ~= action then
            state.action, state.usable, state.noMana = action, nil, nil
            state.checksRange, state.inRange = nil, nil
        end
        if action and C_ActionBar and C_ActionBar.IsUsableAction then
            state.usable, state.noMana = C_ActionBar.IsUsableAction(action)
        end
    end

    local updateUsable
    local function addButton(button)
        if not button or nativeStyle[button] then return end
        nativeStyle[button] = {
            hotkey = rememberFont(button.HotKey), macro = rememberFont(button.Name), count = rememberFont(button.Count),
            iconColor = rememberColor(button.Icon or button.icon), hotkeyColor = rememberColor(button.HotKey),
        }
        buttons[#buttons + 1] = button
        if button.UpdateUsable then hooksecurefunc(button, "UpdateUsable", updateUsable) end
        if button.Update then
            hooksecurefunc(button, "Update", function(owner)
                if not restoring[owner] then
                    local state = buttonState[owner] or {}
                    buttonState[owner] = state
                    refreshUsable(owner, state)
                    applyText(owner)
                    applyColors(owner)
                end
            end)
        end
        if button.UpdateHotkeys then
            hooksecurefunc(button, "UpdateHotkeys", function(owner)
                if not restoring[owner] then applyText(owner); applyColors(owner) end
            end)
        end
        if button.UpdateCount then
            hooksecurefunc(button, "UpdateCount", function(owner)
                if not restoring[owner] then applyText(owner) end
            end)
        end
        applyText(button)
        applyColors(button)
    end

    local function discover()
        for _, info in ipairs(config.bars) do
            local bar = _G[info.frame]
            local found = false
            local list = bar and (bar.actionButtons or bar.buttons)
            for _, button in ipairs(list or {}) do found = true; addButton(button) end
            if not found then
                local prefix = buttonPrefixes[info.id]
                for index = 1, 12 do addButton(prefix and _G[prefix .. index]) end
            end
        end
    end

    updateUsable = function(button, _, usable, noMana)
        if not nativeStyle[button] then return end
        nativeStyle[button].iconColor = rememberColor(button.Icon or button.icon)
        local state = buttonState[button] or {}
        buttonState[button] = state
        local action = publicAction(button)
        if state.action ~= action then
            state.action, state.usable, state.noMana = action, nil, nil
            state.checksRange, state.inRange = nil, nil
        end
        if usable == nil or noMana == nil then refreshUsable(button, state)
        else state.usable, state.noMana = usable, noMana end
        if not restoring[button] then applyColors(button) end
    end

    local function updateRange(button, checksRange, inRange)
        if not nativeStyle[button] then return end
        nativeStyle[button].hotkeyColor = rememberColor(button.HotKey)
        local state = buttonState[button] or {}
        refreshUsable(button, state)
        state.checksRange, state.inRange = checksRange, inRange
        buttonState[button] = state
        if not restoring[button] then applyColors(button) end
    end

    local function restoreBinding(button)
        if config.Get("actionBarCompactHotkeys") or not button.UpdateHotkeys then return end
        restoring[button] = true
        button:UpdateHotkeys(button.buttonType)
        restoring[button] = nil
    end

    local function installHooks()
        if hooked then return end
        hooked = true
        if ActionButton_UpdateRangeIndicator then hooksecurefunc("ActionButton_UpdateRangeIndicator", updateRange) end
    end

    local siblingUpdate = module.UpdateActionBars
    function module.UpdateActionBars()
        if siblingUpdate then siblingUpdate() end
        installHooks()
        discover()
        for _, button in ipairs(buttons) do
            local state = buttonState[button] or {}
            buttonState[button] = state
            refreshUsable(button, state)
            restoreBinding(button)
            restoreNative(button)
            applyText(button)
            applyColors(button)
        end
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "UPDATE_BINDINGS" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        installHooks()
        discover()
        if event == "UPDATE_BINDINGS" then
            for _, button in ipairs(buttons) do restoreBinding(button); applyText(button) end
        else
            module.UpdateActionBars()
        end
    end)
end)
