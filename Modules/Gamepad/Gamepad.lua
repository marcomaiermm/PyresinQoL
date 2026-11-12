local _, ns = ...

local RANGE_CVAR, BLIZZARD_RANGE, MAX_RANGE = "SoftTargetInteractRange", 20, 40
local PAIRS = { { "gamepadSwapAB", "PAD1", "PAD2" }, { "gamepadSwapXY", "PAD3", "PAD4" } }
local active, pendingSwap = false, false

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

local function Key(id) return id.vendorID .. ":" .. id.productID end

local function ActiveConfigID()
    local raw = C_GamePad.GetDeviceRawState(C_GamePad.GetActiveDeviceID())
    return raw and { vendorID = raw.vendorID, productID = raw.productID }
end

-- Swaps the two button names of one pair in place; false when the device maps neither.
local function Swap(config, first, second)
    local found = false
    for _, mapping in ipairs(config.rawButtonMappings) do
        if mapping.button == first then mapping.button, found = second, true
        elseif mapping.button == second then mapping.button, found = first, true end
    end
    return found
end

-- The client stores the swapped config, so remember per device what was exchanged and only ever
-- exchange the difference between that and the settings. Account-wide, outside the profiles.
local function Reconcile()
    if InCombatLockdown() then pendingSwap = true; return end
    pendingSwap = false
    local store = PyresinQoLDB.profileStore
    if not store or not C_GamePad or not C_GamePad.GetAllConfigIDs then return end
    if type(store.gamepadSwaps) ~= "table" then store.gamepadSwaps = {} end
    pcall(function()
        local ids = {}
        local current = active and ActiveConfigID()
        if current then ids[Key(current)] = current end
        for _, id in ipairs(C_GamePad.GetAllConfigIDs()) do
            if store.gamepadSwaps[Key(id)] then ids[Key(id)] = id end
        end
        local changed = false
        for key, id in pairs(ids) do
            local config = C_GamePad.GetConfig(id)
            local applied = CopyTable(store.gamepadSwaps[key] or {})
            local dirty = false
            for _, pair in ipairs(PAIRS) do
                local wanted = active and PyresinQoLDB[pair[1]] == true
                if config and wanted ~= (applied[pair[1]] == true) and Swap(config, pair[2], pair[3]) then
                    applied[pair[1]], dirty = wanted or nil, true
                end
            end
            -- Recorded only once the client has taken the config.
            if dirty and pcall(C_GamePad.SetConfig, config) then
                store.gamepadSwaps[key] = next(applied) and applied or nil
                changed = true
            end
        end
        if changed then pcall(C_GamePad.ApplyConfigs) end
    end)
end

local function Handle(event)
    if event == "START_LOOT_ROLL" then
        ResetLootTooltips()
    elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- Blizzard's own transition handler sets its CVars first; ours must not depend on who listens first.
        C_Timer.After(0, ApplyRange)
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0, ApplyRange)
        Reconcile()
    elseif event ~= "PLAYER_REGEN_ENABLED" or pendingSwap then
        Reconcile()
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
    function module.UpdateGamepad()
        ApplyRange()
        Reconcile()
    end
end)

-- A disabled module still takes back the button swap it applied while it was on, without a frame of its own.
ns.GetModule("gamepad").onInactive = function(module)
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }) do
        EventRegistry:RegisterFrameEventAndCallback(event, function() Handle(event) end, module)
    end
end
