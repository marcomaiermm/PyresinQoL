local _, ns = ...

ns.RegisterModule("actionBars", function(module)
    local config = ns.ActionBars
    local managed, deferred = {}, false
    local controller = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
    local editing = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive() or false

    local function run(handler, body)
        handler:Execute(body)
    end

    local function setSuspended(entry, value, preview)
        entry.suspended = value
        entry.handler:SetAttribute("suspended", value)
        entry.handler:SetAttribute("preview", preview)
        entry.handler:SetAttribute("controllerActive", controller)
        run(entry.handler, [[
            local bar = self:GetFrameRef("bar")
            if self:GetAttribute("suspended") then
                self:SetAttribute("ruleHidden", false)
                local override = self:GetFrameRef("override")
                local nativeControllerHide = self:GetAttribute("controllerActive")
                    and self:GetAttribute("nativeControllerHide")
                if self:GetAttribute("weHid") and self:GetAttribute("externalShown")
                    and not bar:GetAttribute("statehidden")
                    and (self:GetAttribute("preview")
                        or self:GetAttribute("state-barvisibility") ~= "nativehide")
                    and not (override and override:IsShown()) and not nativeControllerHide then
                    self:SetAttribute("ownShow", true)
                    bar:Show(true)
                    self:SetAttribute("ownShow", false)
                end
                self:SetAttribute("weHid", false)
                bar:SetAlpha(self:GetAttribute("preview") and 1 or self:GetAttribute("nativeAlpha"))
            else
                self:RunAttribute("applyRule")
                bar:SetAlpha(self:GetAttribute("baseAlpha"))
            end
        ]])
    end

    local function buildDriver(entry)
        local info, bar = entry.info, entry.bar
        local prefix, clauses = info.prefix, {}
        if bar.visibility == "Hidden" then
            clauses[#clauses + 1] = "nativehide"
        elseif bar.visibility == "InCombat" then
            clauses[#clauses + 1] = "[nocombat] nativehide"
        elseif bar.visibility == "OutOfCombat" then
            clauses[#clauses + 1] = "[combat] nativehide"
        end
        local function add(key, condition)
            if config.Get(prefix .. key) then clauses[#clauses + 1] = condition .. " hide" end
        end
        add("HideCombat", "[combat]")
        add("HideOutOfCombat", "[nocombat]")
        add("HideStealth", "[stealth]")
        add("HideNotStealth", "[nostealth]")
        add("HideForm", "[stance]")
        add("HideNoForm", "[nostance]")
        local custom = config.Get(prefix .. "CustomCondition")
        if custom ~= "" then clauses[#clauses + 1] = custom end
        clauses[#clauses + 1] = "show"
        return table.concat(clauses, "; ")
    end

    local function leaveHover(entry)
        entry.hovered = nil
        if not entry.enabled or entry.handler:GetAttribute("suspended") or editing then return end
        entry.bar:SetAlpha(entry.handler:GetAttribute("baseAlpha") or entry.nativeAlpha)
    end

    local function enterHover(entry)
        entry.hovered = true
        if entry.enabled and not entry.handler:GetAttribute("suspended")
            and not editing and entry.mouseover then entry.bar:SetAlpha(1) end
    end

    local function hookMouseover(entry)
        if entry.mouseHooks then return end
        entry.mouseHooks = true
        local list = entry.bar.actionButtons or entry.bar.buttons
        for _, button in ipairs(list or {}) do
            button:HookScript("OnEnter", function() enterHover(entry) end)
            button:HookScript("OnLeave", function() leaveHover(entry) end)
        end
    end

    local function hookController(entry)
        local gamepad = GamepadMainActionBarFrame
        if entry.controllerHook or not gamepad then return end
        entry.controllerHook = true
        entry.handler:SetFrameRef("gamepad", gamepad)
        entry.handler:WrapScript(gamepad, "OnShow", [[
            if control:GetAttribute("enabled") then
                local bar = control:GetFrameRef("bar")
                control:SetAttribute("suspended", true)
                control:SetAttribute("controllerActive", true)
                control:SetAttribute("ruleHidden", false)
                if not control:GetAttribute("nativeControllerHide")
                    and control:GetAttribute("weHid") and control:GetAttribute("externalShown")
                    and not bar:GetAttribute("statehidden")
                    and control:GetAttribute("state-barvisibility") ~= "nativehide" then
                    control:SetAttribute("ownShow", true)
                    bar:Show(true)
                    control:SetAttribute("ownShow", false)
                end
                control:SetAttribute("weHid", false)
                bar:SetAlpha(control:GetAttribute("nativeAlpha"))
            end
        ]])
        entry.handler:WrapScript(gamepad, "OnHide", [[
            if control:GetAttribute("enabled") and not control:GetAttribute("editing") then
                control:SetAttribute("suspended", false)
                control:SetAttribute("controllerActive", false)
                control:RunAttribute("applyRule")
                control:GetFrameRef("bar"):SetAlpha(control:GetAttribute("baseAlpha"))
            end
        ]])
    end

    local function hookMainNativeVisibility(entry)
        if entry.info.id ~= "Main" then return end
        entry.handler:SetAttribute("nativeControllerHide", true)
        local override = OverrideActionBar
        if entry.overrideHook or not override then return end
        entry.overrideHook = true
        entry.handler:SetFrameRef("override", override)
        local body = [[
            if control:GetAttribute("enabled") and not control:GetAttribute("suspended") then
                control:RunAttribute("applyRule")
            end
        ]]
        entry.handler:WrapScript(override, "OnShow", body)
        entry.handler:WrapScript(override, "OnHide", body)
    end

    local function create(info, bar)
        local handler = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        handler:SetFrameRef("bar", bar)
        handler:SetAttribute("nativeHidden", not bar:IsShown())
        handler:SetAttribute("externalShown", bar.isShownExternal ~= false)
        handler:SetAttribute("applyRule", [[
            local bar = self:GetFrameRef("bar")
            local state = self:GetAttribute("state-barvisibility")
            local override = self:GetFrameRef("override")
            local nativeHidden = state == "nativehide" or not self:GetAttribute("externalShown")
                or bar:GetAttribute("statehidden") or (override and override:IsShown())
            self:SetAttribute("nativeHidden", nativeHidden)
            local hide = state == "hide"
            self:SetAttribute("ruleHidden", hide)
            if nativeHidden then
                self:SetAttribute("weHid", false)
            elseif hide then
                if bar:IsShown() then
                    self:SetAttribute("ownHide", true)
                    bar:Hide(true)
                    self:SetAttribute("ownHide", false)
                    self:SetAttribute("weHid", true)
                end
            elseif self:GetAttribute("weHid") and not self:GetAttribute("nativeHidden") then
                self:SetAttribute("ownShow", true)
                bar:Show(true)
                self:SetAttribute("ownShow", false)
                self:SetAttribute("weHid", false)
            end
        ]])
        handler:SetAttribute("_onstate-barvisibility", [[
            if not self:GetAttribute("suspended") then self:RunAttribute("applyRule") end
        ]])
        handler:SetAttribute("_onstate-alpha", [[
            local alpha = self:GetAttribute(newstate == "combat" and "combatAlpha" or "normalAlpha")
            self:SetAttribute("baseAlpha", alpha)
            if not self:GetAttribute("suspended") then
                local bar = self:GetFrameRef("bar")
                if self:GetAttribute("mouseover") and bar:IsUnderMouse(true) then alpha = 1 end
                bar:SetAlpha(alpha)
            end
        ]])
        handler:WrapScript(bar, "OnShow", [[
            if not control:GetAttribute("ownShow") then
                control:SetAttribute("nativeHidden", false)
                if control:GetAttribute("ruleHidden") and not control:GetAttribute("suspended") then
                    control:SetAttribute("ownHide", true)
                    self:Hide(true)
                    control:SetAttribute("ownHide", false)
                    control:SetAttribute("weHid", true)
                end
            end
        ]])
        handler:WrapScript(bar, "OnHide", [[
            if not control:GetAttribute("ownHide") then control:SetAttribute("nativeHidden", true) end
        ]])
        local entry = { info = info, bar = bar, handler = handler, nativeAlpha = bar:GetAlpha() }
        handler:SetAttribute("nativeAlpha", entry.nativeAlpha)
        managed[info.id] = entry
        hookController(entry)
        hookMainNativeVisibility(entry)
        if bar.UpdateVisibility then
            hooksecurefunc(bar, "UpdateVisibility", function(owner)
                if InCombatLockdown() or handler:GetAttribute("suspended") then return end
                handler:SetAttribute("externalShown", owner.isShownExternal ~= false)
                handler:Execute([[ self:RunAttribute("applyRule") ]])
            end)
        end
        hookMouseover(entry)
        return entry
    end

    local function disable(entry)
        if entry.enabled then
            UnregisterStateDriver(entry.handler, "barvisibility")
            UnregisterStateDriver(entry.handler, "alpha")
        end
        entry.enabled, entry.mouseover = false, false
        entry.handler:SetAttribute("enabled", false)
        entry.handler:SetAttribute("suspended", true)
        entry.handler:SetAttribute("controllerActive", controller)
        run(entry.handler, [[
            local bar = self:GetFrameRef("bar")
            local override = self:GetFrameRef("override")
            local gamepad = self:GetFrameRef("gamepad")
            local nativeControllerHide = self:GetAttribute("nativeControllerHide")
                and gamepad and gamepad:IsShown()
            self:SetAttribute("ruleHidden", false)
            if self:GetAttribute("weHid") and self:GetAttribute("externalShown")
                and not bar:GetAttribute("statehidden") and not (override and override:IsShown())
                and self:GetAttribute("state-barvisibility") ~= "nativehide" and not nativeControllerHide then
                self:SetAttribute("ownShow", true)
                bar:Show(true)
                self:SetAttribute("ownShow", false)
            end
            self:SetAttribute("weHid", false)
        ]])
        entry.bar:SetAlpha(entry.nativeAlpha)
    end

    local function apply(entry)
        hookController(entry)
        hookMainNativeVisibility(entry)
        local prefix = entry.info.prefix
        if not config.Get(prefix .. "Enabled") then disable(entry); return end
        if entry.enabled then
            UnregisterStateDriver(entry.handler, "barvisibility")
            UnregisterStateDriver(entry.handler, "alpha")
        end
        entry.enabled = true
        entry.handler:SetAttribute("enabled", true)
        entry.handler:SetAttribute("editing", editing)
        entry.mouseover = config.Get(prefix .. "Mouseover")
        entry.handler:SetAttribute("mouseover", entry.mouseover)
        entry.handler:SetAttribute("externalShown", entry.bar.isShownExternal ~= false)
        entry.handler:SetAttribute("normalAlpha", config.Get(prefix .. "AlphaNormal"))
        entry.handler:SetAttribute("combatAlpha", config.Get(prefix .. "AlphaCombat"))
        entry.handler:SetAttribute("baseAlpha", InCombatLockdown()
            and config.Get(prefix .. "AlphaCombat") or config.Get(prefix .. "AlphaNormal"))
        entry.handler:SetAttribute("suspended", controller or editing)
        -- The reserved "visibility" state would hide the handler without running our snippet.
        RegisterStateDriver(entry.handler, "barvisibility", buildDriver(entry))
        RegisterStateDriver(entry.handler, "alpha", "[combat] combat; normal")
        if controller or editing then
            setSuspended(entry, true, editing)
        elseif entry.hovered and entry.mouseover then
            entry.bar:SetAlpha(1)
        else
            entry.bar:SetAlpha(entry.handler:GetAttribute("baseAlpha"))
        end
    end

    local function update()
        if InCombatLockdown() then deferred = true; return end
        deferred = false
        for _, info in ipairs(config.bars) do
            local bar = _G[info.frame]
            local entry = managed[info.id]
            if bar and (entry or config.Get(info.prefix .. "Enabled")) then apply(entry or create(info, bar)) end
        end
    end

    local function controllerChanged(active)
        controller = active
        if InCombatLockdown() then
            deferred = true
            return
        end
        for _, entry in pairs(managed) do
            if entry.enabled then setSuspended(entry, active or editing, editing) end
        end
    end

    if InputUtil and InputUtil.RegisterForInterfaceTransitions and Enum and Enum.InputDeviceInterfaceType then
        local subscriber = { "PyresinQoLActionBars" }
        InputUtil.RegisterForInterfaceTransitions(subscriber)
        InputUtil.RegisterGamepadInit(subscriber, function() controllerChanged(true) end)
        InputUtil.RegisterGamepadUninit(subscriber, function() controllerChanged(false) end)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            editing = true
            if not InCombatLockdown() then
                for _, entry in pairs(managed) do
                    entry.handler:SetAttribute("editing", true)
                    if entry.enabled then setSuspended(entry, true, true) end
                end
            end
        end, module)
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            editing = false
            if not InCombatLockdown() then update() else deferred = true end
        end, module)
    end

    local siblingUpdate = module.UpdateActionBars
    function module.UpdateActionBars()
        if siblingUpdate then siblingUpdate() end
        update()
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
        "EDIT_MODE_LAYOUTS_UPDATED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_REGEN_ENABLED" or deferred then update() end
    end)
end)
