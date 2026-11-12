local _, ns = ...

local RANGE_CVAR, BLIZZARD_RANGE, MAX_RANGE = "SoftTargetInteractRange", 20, 40
local LABELS = "Reverse" -- Blizzard's Nintendo icon set: A on the right, B at the bottom
local active, pendingLabels, reconciling = false, false, false

local function GamepadMode()
    return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
end

-- R3 toggles this CVar, and while it is set every tooltip is hidden over a gamepad-managed frame,
-- including the loot-roll item tooltips.
local function ResetLootTooltips()
    if not active or PyresinQoLDB.gamepadLootTooltips == false or not GamepadMode() then return end
    if C_CVar.GetCVarBool("GamepadDisableTooltips") then pcall(C_CVar.SetCVar, "GamepadDisableTooltips", "0") end
end

-- Blizzard sets this temp CVar to 20 when gamepad mode starts and removes it when it ends.
local function ApplyRange()
    if not active or not GamepadMode() then return end
    local range = math.min(MAX_RANGE, math.max(BLIZZARD_RANGE, tonumber(PyresinQoLDB.gamepadInteractRange) or 30))
    pcall(C_CVar.SetTempCVar, RANGE_CVAR, tostring(range))
end

-- vendorID and productID are both optional in a config ID.
local function Key(id) return tostring(id.vendorID) .. ":" .. tostring(id.productID) end

-- The active device can be the combined one, which has no raw state, so every connected pad counts.
local function AddConnected(ids)
    for _, device in ipairs(C_GamePad.GetAllDeviceIDs() or {}) do
        local raw = C_GamePad.GetDeviceRawState(device)
        if raw then
            local id = { vendorID = raw.vendorID, productID = raw.productID }
            ids[Key(id)] = id
        end
    end
end

-- The client stores the config, so remember per device what this module wrote: true for a config it created
-- (the client keeps none for most pads and fills an empty one from its defaults), else the style it replaced
-- (false for none). Account-wide, outside the profiles. The style only shows in gamepad mode, so it is written in any mode.
local function Reconcile()
    if InCombatLockdown() then pendingLabels = true; return end
    pendingLabels = false
    local store = PyresinQoLDB.profileStore
    if reconciling or not store or not C_GamePad or not C_GamePad.GetAllConfigIDs then return end
    if type(store.gamepadLabels) ~= "table" then store.gamepadLabels = {} end
    reconciling = true -- GAME_PAD_* events are synchronous and may fire from inside SetConfig
    local ok, err = pcall(function()
        local ids = {}
        if active then AddConnected(ids) end
        for _, id in ipairs(C_GamePad.GetAllConfigIDs() or {}) do
            if store.gamepadLabels[Key(id)] ~= nil then ids[Key(id)] = id end
        end
        local wanted = active and PyresinQoLDB.gamepadSwitchLabels == true
        for key, id in pairs(ids) do
            local config, applied = C_GamePad.GetConfig(id), store.gamepadLabels[key]
            -- Blizzard re-reads the icon set only on load, so a change asks for the settings window's reload.
            local function Record(value)
                store.gamepadLabels[key] = value
                ns.GetModule("gamepad").needsReload = true
                if ns.UpdateReloadState then ns.UpdateReloadState() end
            end
            -- A restricted SetConfig returns without error, so the record follows what the client reads back.
            local function Write()
                if not pcall(C_GamePad.SetConfig, config) then return end
                pcall(C_GamePad.ApplyConfigs)
                local stored = C_GamePad.GetConfig(id)
                return stored and stored.labelStyle == LABELS
            end
            if wanted and applied == nil and not (config and config.labelStyle == LABELS) then
                local replaced = not config or config.labelStyle or false
                config = config or { configID = id, rawButtonMappings = {}, rawAxisMappings = {}, axisConfigs = {}, stickConfigs = {} }
                config.labelStyle = LABELS
                if Write() then Record(replaced) end
            elseif not wanted and applied ~= nil then
                if applied == true and config then
                    pcall(C_GamePad.DeleteConfig, id)
                    pcall(C_GamePad.ApplyConfigs)
                    config = C_GamePad.GetConfig(id)
                elseif config then
                    config.labelStyle = applied or nil
                    if Write() == false then config = nil end
                end
                if not config then Record(nil) end
            end
        end
    end)
    reconciling = false
    if not ok then geterrorhandler()(err) end
end

local function Handle(event)
    if event == "START_LOOT_ROLL" then
        ResetLootTooltips()
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- Blizzard's own transition handler sets its CVars first; ours must not depend on who listens first.
        C_Timer.After(0, function() ApplyRange(); Reconcile() end)
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0, ApplyRange)
        Reconcile()
    else
        if event == "PLAYER_REGEN_ENABLED" then ApplyRange() end -- a secure CVar rejects the write in combat
        if event ~= "PLAYER_REGEN_ENABLED" or pendingLabels then Reconcile() end
    end
end

ns.RegisterModule("gamepad", function(module)
    active = true
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GAME_PAD_CONNECTED", "GAME_PAD_ACTIVE_CHANGED",
        "INPUT_DEVICE_INTERFACE_TRANSITION", "START_LOOT_ROLL" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event) Handle(event) end)
    -- Without a connected pad there is no device to label; the settings window greys the page out and says so.
    function module.Unavailable()
        local ids = {}
        AddConnected(ids)
        return not next(ids) and ns.L.gamepadMissing
    end
    function module.UpdateGamepad()
        ApplyRange()
        Reconcile()
    end
end)

-- A disabled module still takes back the button labels it applied while it was on, without a frame of its own.
ns.GetModule("gamepad").onInactive = function(module)
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }) do
        EventRegistry:RegisterFrameEventAndCallback(event, function() Handle(event) end, module)
    end
end
