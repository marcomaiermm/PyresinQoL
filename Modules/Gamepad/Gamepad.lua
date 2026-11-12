local _, ns = ...

local RANGE_CVAR, BLIZZARD_RANGE, MAX_RANGE = "SoftTargetInteractRange", 20, 40
local PAIRS = { { "gamepadSwapAB", "PAD1", "PAD2" }, { "gamepadSwapXY", "PAD3", "PAD4" } }
local active, pendingSwap, reconciling = false, false, false

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

local function SameButtons(a, b)
    if not a or #a.rawButtonMappings ~= #b.rawButtonMappings then return false end
    for index, mapping in ipairs(b.rawButtonMappings) do
        if a.rawButtonMappings[index].button ~= mapping.button then return false end
    end
    return true
end

-- The client stores the swapped config, so remember per device what was exchanged and only ever
-- exchange the difference between that and the settings. Account-wide, outside the profiles.
-- A new swap needs gamepad mode; taking one back does not.
local function Reconcile()
    if InCombatLockdown() then pendingSwap = true; return end
    pendingSwap = false
    local store = PyresinQoLDB.profileStore
    if reconciling or not store or not C_GamePad or not C_GamePad.GetAllConfigIDs then return end
    if type(store.gamepadSwaps) ~= "table" then store.gamepadSwaps = {} end
    reconciling = true -- GAME_PAD_* events are synchronous and may fire from inside SetConfig
    pcall(function()
        local ids = {}
        local current = active and ActiveConfigID()
        if current then ids[Key(current)] = current end
        for _, id in ipairs(C_GamePad.GetAllConfigIDs()) do
            if type(store.gamepadSwaps[Key(id)]) == "table" then ids[Key(id)] = id end
        end
        local changed = false
        for key, id in pairs(ids) do
            local config = C_GamePad.GetConfig(id)
            local applied = CopyTable(type(store.gamepadSwaps[key]) == "table" and store.gamepadSwaps[key] or {})
            local dirty = false
            for _, pair in ipairs(PAIRS) do
                local wanted = active and PyresinQoLDB[pair[1]] == true
                if config and wanted ~= (applied[pair[1]] == true) and (not wanted or GamepadMode())
                    and Swap(config, pair[2], pair[3]) then
                    applied[pair[1]], dirty = wanted or nil, true
                end
            end
            -- A restricted SetConfig returns without error, so the record waits for the stored config to match.
            if dirty and pcall(C_GamePad.SetConfig, config) then
                pcall(C_GamePad.ApplyConfigs)
                if SameButtons(C_GamePad.GetConfig(id), config) then
                    store.gamepadSwaps[key] = next(applied) and applied or nil
                end
            end
        end
    end)
    reconciling = false
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
        if event ~= "PLAYER_REGEN_ENABLED" or pendingSwap then Reconcile() end
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
