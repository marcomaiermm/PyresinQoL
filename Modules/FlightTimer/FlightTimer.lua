local _, ns = ...

-- ETA for flight master flights, shown by Bar.lua. The client exposes no flight duration, so time is
-- route length (Data.lua) / speed, with the speed corrected by every flight that lands normally. A
-- route with a hop missing from the data shows nothing. A /reload mid-flight resumes the bar; a relog
-- or crash drops it until the next takeoff. The Edit Mode mover and options are in EditMode.lua.
local DEFAULT_SPEED = 30.4 -- yards per second until the first landing; each one corrects it
local PREVIEW_SECONDS = 20

-- Preview: a real route per faction, its node ids on the continent's map (Kalimdor, Eastern Kingdoms),
-- played fast-forward in PREVIEW_SECONDS. The names come from the client, in its language.
local PREVIEW_ROUTES = {
    Horde = { map = 1414, 80, 25, 30, 40 },
    Alliance = { map = 1415, 6, 74, 71, 5 },
}

ns.RegisterModule("flightTimer", function(module)
    local routes = ns.flightTimerRoutes
    local bar, display = module.flightTimerBar, module.flightTimerDisplay

    local ticker
    local pending -- destination picked on the flight map, waiting for takeoff
    local flight  -- the flight in progress
    local editing = false -- Edit Mode is open and previews a flight

    -- Learned across characters and outside the profiles: it is the game's, not a preference.
    local function Speed() return PyresinQoLFlightSpeed or DEFAULT_SPEED end

    -- Frequent Flier (node 110300 of tree 1188) makes flight paths 20% faster. Both lookups may
    -- return nothing, which reads as no perk.
    local function SpeedMultiplier()
        local configID = C_Traits.GetConfigIDByTreeID(1188)
        local node = configID and C_Traits.GetNodeInfo(configID, 110300)
        return (node and node.activeRank or 0) > 0 and 1.2 or 1
    end

    -- Sums the stored length of every hop to slot; nil when a hop is missing from the data. Also
    -- returns every node on the way, start first, with the yards flown to reach it.
    local function RouteInfo(slot)
        local hops = GetNumRoutes(slot)
        if hops < 1 then return nil end
        local mapID = GetTaxiMapID and GetTaxiMapID()
        local nodes = mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes(mapID)
        local idBySlot = {}
        for _, node in ipairs(nodes or idBySlot) do idBySlot[node.slotIndex] = node.nodeID end
        local yards = 0
        local points = { { name = TaxiNodeName(TaxiGetNodeSlot(slot, 1, true)), yards = 0 } }
        for hop = 1, hops do
            local toSlot = TaxiGetNodeSlot(slot, hop, false)
            local from, to = idBySlot[TaxiGetNodeSlot(slot, hop, true)], idBySlot[toSlot]
            local hopYards = from and to and routes[from * 10000 + to]
            if not hopYards then return nil end
            yards = yards + hopYards
            points[#points + 1] = { name = TaxiNodeName(toSlot), yards = yards }
        end
        if yards > 0 then return yards, points end
    end

    local StartPreview, Land

    -- In Edit Mode the preview takes over without hiding the timer: hiding it would hide its mover and
    -- with it the options dialog and the pixel-perfect editor.
    local function EndFlight()
        if flight and not flight.preview then PyresinQoLFlight = nil end
        flight = nil
        if editing then return StartPreview() end
        if ticker then ticker:Cancel(); ticker = nil end
        bar.Hide()
    end

    local function Tick()
        local elapsed = GetTime() - flight.start
        if flight.preview and elapsed >= flight.eta then
            EndFlight()
        elseif not flight.preview and elapsed > 2 and not UnitOnTaxi("player") then
            -- Landing edge missed (PLAYER_CONTROL_GAINED is the precise one): end here, learn nothing.
            flight.early = true
            Land()
        else
            bar.UpdateTime()
        end
    end

    local function ShowFlight()
        bar.Show(flight)
        if not ticker then ticker = C_Timer.NewTicker(1, Tick) end
    end

    -- points: every node on the way, start first (see RouteInfo).
    -- preview: a fast-forward flight that neither lands nor learns; scale is how much faster its clock runs.
    local function StartFlight(yards, points, preview)
        flight = { yards = yards, start = GetTime(), points = points, preview = preview }
        if preview then
            flight.eta = PREVIEW_SECONDS
            flight.scale = PREVIEW_SECONDS / (yards / Speed())
        else
            flight.mult = SpeedMultiplier()
            flight.eta = yards / (Speed() * flight.mult)
            -- Per character and outside the profiles; Retarget's changes land in the same table.
            PyresinQoLFlight = flight
        end
        ShowFlight()
    end

    -- A real flight is never replaced by a preview.
    function StartPreview()
        if flight then return end
        local route = PREVIEW_ROUTES[UnitFactionGroup("player")] or PREVIEW_ROUTES.Alliance
        local names = {}
        local nodes = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_TaxiMap.GetTaxiNodesForMap(route.map)
        for _, node in ipairs(nodes or names) do names[node.nodeID] = node.name end
        local points, yards = {}, 0
        for i, nodeID in ipairs(route) do
            if i > 1 then yards = yards + routes[route[i - 1] * 10000 + nodeID] end
            points[i] = { name = names[nodeID], yards = yards }
        end
        StartFlight(yards, points, true)
    end

    -- An early landing stops at the next node on the way: the timer and the route end there.
    -- Assumes the server lands at the very next node; a request right on top of one may land at the
    -- node after, and the bar then ends early.
    local function Retarget()
        flight.early = true
        local points = flight.points
        local flown = (GetTime() - flight.start) / flight.eta * flight.yards
        for i, p in ipairs(points) do
            if p.yards > flown then
                for j = #points, i + 1, -1 do points[j] = nil end
                flight.eta = flight.eta * p.yards / flight.yards
                flight.yards = p.yards
                break
            end
        end
        bar.Show(flight)
    end

    -- Moves the stored speed a quarter of the way toward what this flight measured; a flight more
    -- than a third off is bad data. The stored speed excludes Frequent Flier.
    function Land()
        if not flight.early then
            local measured = flight.yards / (GetTime() - flight.start) / flight.mult
            local speed = Speed()
            if measured > speed * 0.75 and measured < speed * 1.33 then
                PyresinQoLFlightSpeed = speed + (measured - speed) * 0.25
            end
        end
        EndFlight()
    end

    hooksecurefunc("TakeTaxiNode", function(slot)
        local yards, points = RouteInfo(slot)
        pending = yards and { yards = yards, points = points, clicked = GetTime() }
    end)
    -- Blizzard's own leave button calls this during a taxi.
    hooksecurefunc("TaxiRequestEarlyLanding", function()
        if flight and not flight.preview then Retarget() end
    end)

    -- Edit Mode (EditMode.lua) previews a flight while it is open; a real one goes first.
    function module.SetFlightTimerPreview(on)
        editing = on
        if on then StartPreview() elseif flight and flight.preview then EndFlight() end
    end

    display:RegisterEvent("PLAYER_ENTERING_WORLD")
    display:RegisterEvent("PLAYER_CONTROL_LOST")
    display:RegisterEvent("PLAYER_CONTROL_GAINED")
    display:SetScript("OnEvent", function(_, event, isInitialLogin, isReloadingUi)
        if event == "PLAYER_ENTERING_WORLD" then
            -- GetTime() keeps running through a /reload, so a saved flight resumes exactly. After a
            -- relog or crash the clock and the flight's progress are unknown, so it is dropped.
            local saved = PyresinQoLFlight
            if isReloadingUi and saved and not flight and UnitOnTaxi("player") and saved.start <= GetTime() then
                flight = saved
                ShowFlight()
            elseif isInitialLogin or isReloadingUi then
                PyresinQoLFlight = nil
            end
        elseif event == "PLAYER_CONTROL_LOST" then
            -- UnitOnTaxi is still false at takeoff, so a fresh flight-map click is the signal. A
            -- click the server refused leaves pending behind; a takeoff minutes later must not
            -- start from it (a stun right after is ended by Tick's not-on-taxi check).
            if pending and GetTime() - pending.clicked < 5 then
                StartFlight(pending.yards, pending.points)
            end
            pending = nil
        elseif event == "PLAYER_CONTROL_GAINED" then
            -- UnitOnTaxi is still true at this event, so it cannot tell a landing from a stray one;
            -- control only returns mid-flight right after takeoff.
            if flight and not flight.preview and GetTime() - flight.start > 2 then Land() end
        end
    end)
end)
