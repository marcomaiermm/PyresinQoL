local _, ns = ...

ns.RegisterModule("quests", function(module)
    local cvars = {
        outlineModeShowLootEffectWhenDisabled = { "1", "0" },
        graphicsOutlineMode = { "0", "2" },
        OutlineEngineMode = { "0", "2" },
        raidGraphicsOutlineMode = { "0", "2" },
        RAIDOutlineEngineMode = { "0", "2" },
    }
    local watched = {}
    for name in pairs(cvars) do watched[name:lower()] = name end

    local events = CreateFrame("Frame")
    local enabled, applying, pending, resetPending, timer, loginTimer
    module.questSparklesRestartPending = nil

    local function Apply()
        if InCombatLockdown() then
            pending = true
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        pending = nil
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        applying = true
        local errors = {}
        for name, values in pairs(cvars) do
            local value = values[enabled and 1 or 2]
            local current = C_CVar.GetCVar(name)
            if current ~= nil and current ~= value then
                local ok, result = pcall(C_CVar.SetCVar, name, value)
                if not ok or result == false or C_CVar.GetCVar(name) ~= value then
                    local reason = not ok and tostring(result) or "CVar did not accept the requested value"
                    errors[#errors + 1] = ("PyresinQoL: failed to set %s to %s: %s"):format(name, value, reason)
                end
            end
        end
        applying = false
        if not enabled then
            resetPending = #errors > 0
            if not resetPending then
                module.questSparklesRestartPending = true
                if module.MaybePromptQuestSparklesRestart then module.MaybePromptQuestSparklesRestart() end
            end
        end
        -- Restore runtime state before reporting, even if a custom error handler throws.
        if #errors > 0 then geterrorhandler()(table.concat(errors, "\n")) end
    end

    function module.UpdateQuestSparkles()
        local previous = enabled
        enabled = PyresinQoLDB.questItemSparkles == true
        if timer then timer:Cancel(); timer = nil end
        if enabled then
            resetPending = nil
            module.questSparklesRestartPending = nil
            events:RegisterEvent("CVAR_UPDATE")
            Apply()
        else
            events:UnregisterEvent("CVAR_UPDATE")
            if loginTimer then loginTimer:Cancel(); loginTimer = nil end
            -- Retry incomplete off transitions, but leave already-disabled profiles alone.
            if previous then resetPending = true end
            if resetPending then Apply() end
        end
    end

    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_LOGIN" then
            events:UnregisterEvent("PLAYER_LOGIN")
            module.UpdateQuestSparkles()
            if enabled then
                -- Graphics initialization can overwrite the login values later.
                loginTimer = C_Timer.NewTimer(5, function()
                    loginTimer = nil
                    Apply()
                end)
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then Apply() end
        elseif event == "CVAR_UPDATE" and enabled and not applying and not pending and not timer and type(name) == "string" then
            name = name:lower()
            local cvar = watched[name]
            local current = cvar and C_CVar.GetCVar(cvar)
            -- Presets can announce their change before resetting the individual outline CVars.
            if name == "graphicsquality" or name == "raidgraphicsquality"
                or (current ~= nil and current ~= cvars[cvar][1]) then
                -- Coalesce graphics-preset bursts without polling or reacting to our own writes.
                timer = C_Timer.NewTimer(1, function()
                    timer = nil
                    Apply()
                end)
            end
        end
    end)
end)
