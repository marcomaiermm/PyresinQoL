local _, ns = ...

-- The flight timer's view: a Blizzard timer bar between the route's two ends, the player's portrait
-- riding the fill and the stops on the way. FlightTimer.lua hands it the flight to show.
local BAR_HEIGHT = 13 -- MirrorTimerTemplate's bar
local PIN_SIZE = 14
local FLAG_SIZE = 20
local AVATAR_SIZE = 30
local MOUNT_HEIGHT = 22 -- the action bar end cap, drawn 154 x 95 there
local NAME_ROOM = 24 -- room for the names above and the stops below the bar
local ARROW_HEIGHT = 7
local LOOKAHEAD = 60 -- seconds before arrival a stop scrolls in at the bar's right end
local STOP_ICON = "Interface\\Minimap\\Tracking\\FlightMaster"
local DIMMED = 0.4 -- a stop already passed
local FADED = 0.3 -- what gives way where the marker meets an end name

-- Bar art: Blizzard's cast bar (yellow, or the blue of crafting / breath), the swing timer, or a thin
-- line. Unset fields fall back to the cast bar's background, frame and spark.
local STYLES = {
    castbar = { fill = "ui-castingbar-filling-standard" },
    breath = { fill = "ui-castingbar-filling-applyingcrafting" },
    swing = { fill = "ui-swingtimerbar-filling-mainhand", background = "ui-swingtimerbar-background",
        frame = "ui-swingtimerbar-frame", spark = "ui-swingtimerbar-pip", x = 5, y = 4 },
    minimal = { height = 3 },
}

-- Portraits cut from the unit frame art: the player frame's ring with its tip and the party frame's
-- round one. Atlas size, the portrait centre in it, portrait and outer ring diameters, and the shape.
local PORTRAITS = {
    pointed = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn", w = 198, h = 71, x = 37, y = 34.5, portrait = 60,
        ring = 66, mask = "UI-HUD-UnitFrame-Player-Portrait-Mask" },
    round = { atlas = "UI-HUD-UnitFrame-Party-PortraitOn", w = 120, h = 49, x = 24.5, y = 22.75, portrait = 37,
        ring = 42, mask = "CircleMask" },
}

ns.RegisterModule("flightTimer", function(module)
    local GOLD = { NORMAL_FONT_COLOR:GetRGB() }
    local display = CreateFrame("Frame", "PyresinQoLFlightTimer", UIParent)
    display:SetMovable(true)
    display:SetClampedToScreen(true)
    display:EnableMouse(false)
    display:Hide()
    module.flightTimerDisplay = display
    -- Everything sits on content, which carries the scale: display stays at scale 1 with the scaled
    -- size, so its saved position and the pixel-perfect editor need no scale of their own.
    local content = CreateFrame("Frame", nil, display)
    content:SetPoint("CENTER")

    local flight -- the one shown, see StartFlight in FlightTimer.lua

    local defaults = {}
    for _, option in ipairs(module.flightTimerOptions) do defaults[option.key] = option.default end

    local function Get(key)
        local value = PyresinQoLDB[key]
        if value == nil then return defaults[key] end
        return value
    end
    module.GetFlightTimerOption = Get

    local function Scale() return Get("flightTimerScale") / 100 end
    -- Before the scale, which scales the whole timer, width and all.
    local function Width() return Get("flightTimerWidth") end

    -- Node names read "Place, Zone"; without zones, the place alone.
    local function PlaceName(name)
        name = name or ""
        return Get("flightTimerZones") and name or name:match("^[^,]*")
    end

    local function FormatTime(sec)
        sec = math.max(0, math.floor(sec + 0.5))
        return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
    end

    -- The bar; ApplyStyle paints it in the chosen style.
    local track = CreateFrame("StatusBar", nil, content)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local fill = track:CreateTexture(nil, "ARTWORK")
    track:SetStatusBarTexture(fill)
    track:SetMinMaxValues(0, 1)
    track:SetValue(0)
    local background = track:CreateTexture(nil, "BACKGROUND")
    -- Marks sit on frames above the bar.
    local over = CreateFrame("Frame", nil, content)
    over:SetAllPoints(content)
    local border = over:CreateTexture(nil, "ARTWORK")
    local timeText = over:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- The minimal line's round ends.
    local dots = {}
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        dots[i] = over:CreateTexture(nil, "ARTWORK")
        dots[i]:SetSize(7, 7)
        dots[i]:SetPoint("CENTER", track, side)
        dots[i]:SetColorTexture(unpack(GOLD))
        local mask = over:CreateMaskTexture()
        mask:SetAtlas("CircleMask", false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(dots[i])
        dots[i]:AddMaskTexture(mask)
    end

    -- A name in a clipping box, at most maxWidth wide when fitted. A longer one slides to its end and
    -- back, pausing at each, or with scrolling off ends in an ellipsis.
    local function NewName(parent, side)
        local box = CreateFrame("Frame", nil, parent)
        box:SetHeight(14)
        local holder = CreateFrame("Frame", nil, box)
        holder:SetAllPoints()
        local text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetWordWrap(false)
        text:SetJustifyH(side)
        text:SetPoint(side)
        local slide = holder:CreateAnimationGroup()
        slide:SetLooping("REPEAT")
        -- There and back as two steps, each after a pause: BOUNCE flickered where it turned round.
        local there, back = slide:CreateAnimation("Translation"), slide:CreateAnimation("Translation")
        there:SetOrder(1)
        back:SetOrder(2)
        for _, move in ipairs({ there, back }) do
            move:SetStartDelay(1.5)
            move:SetSmoothing("IN_OUT")
        end
        local name = { box = box, text = text }
        function name.Fit(value, maxWidth)
            maxWidth = math.max(1, maxWidth) -- crowded fixed stops leave no room; a width of 0 would mean unlimited
            slide:Stop()
            text:SetWidth(0)
            text:SetText(value)
            local full = text:GetStringWidth() or 0
            local overflow = full - maxWidth
            local slides = overflow > 0 and Get("flightTimerScrollNames") == true
            if overflow > 0 and not slides then text:SetWidth(maxWidth) end
            box:SetWidth(math.min(full, maxWidth))
            -- Clipping only where a name slides: boxes nested in the stop strip's clip drew nothing.
            box:SetClipsChildren(slides)
            if slides then
                local offset = side == "LEFT" and -overflow or overflow
                there:SetOffset(offset, 0)
                back:SetOffset(-offset, 0)
                there:SetDuration(overflow / 20)
                back:SetDuration(overflow / 20)
                slide:Play()
            end
        end
        return name
    end

    -- A stop on the route: an icon with a name, under an arrow pointing up at the bar.
    local function NewMark(parent, size)
        local mark = { icon = parent:CreateTexture(nil, "OVERLAY"), name = NewName(parent, "LEFT"),
            arrow = parent:CreateTexture(nil, "OVERLAY") }
        mark.label = mark.name.text
        mark.icon:SetSize(size, size)
        mark.name.box:SetPoint("LEFT", mark.icon, "RIGHT", 2, 0)
        -- A flat chevron; there is no up one, so the down one turned over.
        mark.arrow:SetAtlas("uitools-icon-chevron-down")
        mark.arrow:SetRotation(math.pi)
        mark.arrow:SetSize(ARROW_HEIGHT * 2, ARROW_HEIGHT * 2)
        mark.arrow:SetPoint("BOTTOM", mark.icon, "TOP", 0, -ARROW_HEIGHT / 2)
        -- Left snapped like the name: text always snaps, so an unsnapped icon drifted 1px against it.
        return mark
    end

    local function SetMarkAlpha(mark, alpha)
        for _, part in ipairs({ mark.icon, mark.label, mark.arrow }) do part:SetAlpha(alpha) end
    end

    -- text: a string shows icon and label, at most maxWidth wide; false neither.
    local function ShowMark(mark, text, arrow, maxWidth)
        mark.icon:SetShown(text ~= false)
        mark.label:SetShown(text ~= false)
        mark.arrow:SetShown(text ~= false and arrow)
        SetMarkAlpha(mark, 1)
        if text then mark.name.Fit(text, maxWidth) end
    end

    -- The spark rides the fill's edge; the client resizes the fill, so no OnUpdate.
    local spark = over:CreateTexture(nil, "OVERLAY")
    spark:SetPoint("CENTER", fill, "RIGHT")
    -- End names above the bar's ends, each beside its flag when shown: the arena commentator's pole
    -- and cloth atlases, the cloth in Blizzard gold.
    local ends, names, flags = {}, {}, {}
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        names[i] = NewName(over, side)
        ends[i] = names[i].text
        flags[i] = CreateFrame("Frame", nil, over)
        flags[i]:SetSize(FLAG_SIZE, FLAG_SIZE)
        flags[i]:SetPoint("BOTTOM" .. side, track, "TOP" .. side, i == 1 and -2 or 2, 1)
        for _, atlas in ipairs({ "Flag-1", "Flag-2" }) do
            local texture = flags[i]:CreateTexture(nil, "OVERLAY")
            texture:SetAtlas(atlas)
            texture:SetAllPoints()
            if atlas == "Flag-2" then texture:SetVertexColor(unpack(GOLD)) end
        end
    end
    -- The point scrolling stops cross when reached.
    local post = over:CreateTexture(nil, "OVERLAY")
    post:SetColorTexture(1, 1, 1, 0.8)
    post:SetPoint("CENTER", track, "CENTER")
    -- The player on the fill's edge: a portrait in its unit frame ring, or the name in class colour.
    -- The marker rides above the names and flags, which sit on frames of their own.
    local marks = CreateFrame("Frame", nil, over)
    marks:SetAllPoints()
    local avatars = {}
    for kind, art in pairs(PORTRAITS) do
        local k = AVATAR_SIZE / art.ring
        local avatar = CreateFrame("Frame", nil, marks)
        avatar:SetSize(AVATAR_SIZE, AVATAR_SIZE)
        avatar.portrait = avatar:CreateTexture(nil, "ARTWORK")
        avatar.portrait:SetSize(art.portrait * k, art.portrait * k)
        avatar.portrait:SetPoint("CENTER")
        -- The ring is the whole unit frame art, its bars masked away.
        local ring = avatar:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas(art.atlas)
        ring:SetSize(art.w * k, art.h * k)
        ring:SetPoint("TOPLEFT", AVATAR_SIZE / 2 - art.x * k, art.y * k - AVATAR_SIZE / 2)
        for texture, area in pairs({ [avatar.portrait] = avatar.portrait, [ring] = avatar }) do
            local mask = avatar:CreateMaskTexture()
            -- Clamped to black like Blizzard's portrait masks, or the ring's bars leak past its edge.
            mask:SetAtlas(art.mask, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(area)
            texture:AddMaskTexture(mask)
        end
        avatars[kind] = avatar
    end
    -- The portrait can still be blank when a /reload resumes a flight; the client says when it is ready.
    local function UpdatePortrait()
        for _, avatar in pairs(avatars) do SetPortraitTexture(avatar.portrait, "player") end
    end
    -- Or the main action bar's end cap of the player's faction, as Blizzard picks it: a gryphon, or
    -- a wind rider for the Horde. The left cap faces right, the way the flight goes.
    local mount = marks:CreateTexture(nil, "OVERLAY")
    mount:SetSize(MOUNT_HEIGHT * 154 / 95, MOUNT_HEIGHT)
    mount:SetSnapToPixelGrid(false)
    local nameText = marks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- Points down at the bar, toward the stop arrows pointing up.
    local nameArrow = marks:CreateTexture(nil, "OVERLAY")
    nameArrow:SetAtlas("uitools-icon-chevron-down")
    nameArrow:SetSize(ARROW_HEIGHT * 2, ARROW_HEIGHT * 2)
    nameArrow:SetSnapToPixelGrid(false)
    -- The stops ride a strip inside a clipping frame under the bar (see PlaceStrip).
    local clip = CreateFrame("Frame", nil, content)
    clip:SetClipsChildren(true)
    clip:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -2)
    clip:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
    local strip = CreateFrame("Frame", nil, clip)
    strip:SetSize(1, 1)
    local glide = strip:CreateAnimationGroup()
    local move = glide:CreateAnimation("Translation")
    move:SetSmoothing("NONE")
    local stops = {} -- stops[k] is the stop at points[k + 1]
    local barHeight = BAR_HEIGHT -- of the current style
    local fade -- set by ApplyStyle, see over's OnUpdate
    -- Set by LayoutRoute: stops fixed or scrolling, scrolling past the centre post or the spark, px per
    -- second of flight and px per yard.
    local fixed, byPost, pps, ppy

    -- Puts the stop strip where elapsed has it and glides it on to arrival in one translation, which
    -- the client runs: smooth, and no Lua per frame. Fixed stops keep the strip at the bar's start.
    local function PlaceStrip(elapsed)
        glide:Stop()
        strip:ClearAllPoints()
        if fixed then
            strip:SetPoint("CENTER", content, "LEFT")
            return
        end
        strip:SetPoint("CENTER", content, byPost and "CENTER" or "LEFT", -elapsed * pps, 0)
        local left = flight.eta - elapsed
        if left > 0 then
            move:SetDuration(left)
            move:SetOffset(-left * pps, 0)
            glide:Play()
        end
    end
    -- A flight running past its ETA keeps the strip where the glide left it.
    glide:SetScript("OnFinished", function() if flight then PlaceStrip(flight.eta) end end)

    -- Dims each stop when it is reached: under the spark, or crossing the centre post. A relayout
    -- drops the timers of the one before.
    local dimming = 0
    local function DimStops(elapsed)
        dimming = dimming + 1
        local generation = dimming
        local eta = flight.eta
        for k = 1, #flight.points - 2 do
            local reached = flight.points[k + 1].yards / flight.yards * eta
            local mark, at = stops[k], reached - elapsed
            if at <= 0 then
                SetMarkAlpha(mark, DIMMED)
            else
                C_Timer.After(at, function() if generation == dimming then SetMarkAlpha(mark, DIMMED) end end)
            end
        end
    end

    -- The ends hold still at the bar's ends. Scrolling stops come in from the right under the bar,
    -- cross the centre post when reached and run out to the left, like a side-scroller; fixed stops
    -- sit at their share of the route.
    local function LayoutRoute()
        local points = flight and flight.points
        local n = points and #points or 0
        local level = track:GetFrameLevel() + 2
        over:SetFrameLevel(level)
        clip:SetFrameLevel(level)
        marks:SetFrameLevel(level + 5)

        local flagMode = Get("flightTimerFlags")
        for i, side in ipairs({ "LEFT", "RIGHT" }) do
            local flagged = n > 0 and (flagMode == "both" or flagMode == (i == 1 and "departure" or "destination"))
            flags[i]:SetShown(flagged)
            ends[i]:SetShown(n > 0)
            -- Each end name gets at most 42% of the width, leaving the centre to the stops.
            names[i].Fit(n > 0 and PlaceName(points[i == 1 and 1 or n].name) or "", Width() * 0.42)
            local box = names[i].box
            box:ClearAllPoints()
            if flagged then
                box:SetPoint("BOTTOM" .. side, flags[i], "BOTTOM" .. (i == 1 and "RIGHT" or "LEFT"), i == 1 and 2 or -2, 2)
            else
                box:SetPoint("BOTTOM" .. side, track, "TOP" .. side, 0, 3)
            end
        end

        -- Stop positions come from route lengths, their passing from the ETA. After an early landing
        -- request the route ends at the next stop, so the stops go.
        local scroll = points and not flight.early and n > 2 and Get("flightTimerStops") ~= "off"
        local arrows = Get("flightTimerStopArrows")
        clip:SetShown(scroll)
        fixed = Get("flightTimerStops") == "fixed"
        byPost = Get("flightTimerShowPost")
        if scroll then
            -- px per yard: fixed spreads the route over the bar, scrolling moves per second of flight
            -- (scaled with the clock for a fast-forward preview).
            pps = Width() / 2 / (LOOKAHEAD * (flight.scale or 1))
            -- Past the spark, a stop's spot on the bar (its share of the width) comes on top of what it
            -- scrolls, so it meets the spark when reached.
            ppy = (fixed and Width() or byPost and flight.eta * pps or Width() + flight.eta * pps) / flight.yards
        end
        for k = 1, math.max(n - 2, #stops) do
            local y = scroll and k <= n - 2 and points[k + 1].yards
            local mark = stops[k]
            if y and not mark then
                mark = NewMark(strip, PIN_SIZE)
                mark.icon:SetTexture(STOP_ICON)
                stops[k] = mark
            end
            if mark then
                -- Fixed stops keep their names clear of the next stop and the bar's end; scrolling
                -- ones pass under the bar's ends whole.
                local room = math.huge
                if y and fixed then
                    local nextX = k < n - 2 and points[k + 2].yards * ppy - PIN_SIZE / 2 - 4 or Width()
                    room = nextX - (y * ppy + PIN_SIZE / 2 + 2)
                end
                ShowMark(mark, y and PlaceName(points[k + 1].name) or false, arrows, room)
                if y then
                    mark.icon:ClearAllPoints()
                    mark.icon:SetPoint("CENTER", strip, "CENTER", y * ppy, -barHeight / 2 - 3 - ARROW_HEIGHT - PIN_SIZE / 2)
                end
            end
        end
        if scroll then
            local elapsed = math.max(0, math.min(GetTime() - flight.start, flight.eta))
            PlaceStrip(elapsed)
            DimStops(elapsed)
        end
        post:SetShown(scroll and not fixed and byPost)
    end

    -- Eases a region toward an alpha; settled ones cost nothing.
    local function FadeTo(region, alpha, step)
        local now = region:GetAlpha()
        if now ~= alpha then region:SetAlpha(math.abs(alpha - now) < step and alpha or now + (alpha > now and step or -step)) end
    end
    -- The fill grows in the client, so where the marker is comes from the clock each frame: a few
    -- comparisons, only while the timer shows and something can fade (see ApplyStyle).
    local function Fade(_, dt)
        if not flight then return end
        local width = Width()
        local x = math.min(math.max(GetTime() - flight.start, 0), flight.eta) / flight.eta * width
        local step, hitAny = dt * 4, false
        for i = 1, 2 do
            local reach = (flags[i]:IsShown() and FLAG_SIZE or 0) + (names[i].box:GetWidth() or 0) + 4
            local hit = ends[i]:IsShown() and (i == 1 and x - fade.left < reach or i == 2 and x + fade.right > width - reach)
            hitAny = hitAny or hit
            local alpha = hit and fade.mode ~= "marker" and FADED or 1
            FadeTo(ends[i], alpha, step)
            FadeTo(flags[i], alpha, step)
        end
        for _, region in ipairs(fade.marker) do FadeTo(region, hitAny and fade.mode ~= "ends" and FADED or 1, step) end
    end

    local function ApplyStyle()
        local style = STYLES[Get("flightTimerStyle")] or STYLES.castbar
        local minimal = style == STYLES.minimal
        barHeight = style.height or BAR_HEIGHT
        local scale = Scale()
        content:SetSize(Width(), barHeight + 2 * NAME_ROOM)
        content:SetScale(scale)
        display:SetSize(Width() * scale, (barHeight + 2 * NAME_ROOM) * scale)
        track:SetHeight(barHeight)
        post:SetSize(2, barHeight + 4)
        background:ClearAllPoints()
        border:ClearAllPoints()
        if minimal then
            -- The first look: a gold line in a 1px black outline.
            fill:SetColorTexture(unpack(GOLD))
            background:SetColorTexture(0, 0, 0, 1)
            background:SetPoint("TOPLEFT", -1, 1)
            background:SetPoint("BOTTOMRIGHT", 1, -1)
        else
            local x, y = style.x or 1, style.y or 1
            fill:SetAtlas(style.fill)
            background:SetAtlas(style.background or "ui-castingbar-background")
            background:SetPoint("TOPLEFT", -x, y)
            background:SetPoint("BOTTOMRIGHT", x, -y)
            border:SetAtlas(style.frame or "ui-castingbar-frame")
            -- The cast bar's frame overhangs its background by a pixel.
            border:SetPoint("TOPLEFT", track, "TOPLEFT", -(style.x or 2), style.y or 2)
            border:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", style.x or 2, -(style.y or 2))
            spark:SetAtlas(style.spark or "ui-castingbar-pip", style.spark ~= nil)
            if not style.spark then spark:SetSize(8, 20) end
        end
        border:SetShown(not minimal)
        for _, dot in ipairs(dots) do dot:SetShown(minimal) end
        -- Minimal reads its time before the line, the bars after theirs.
        timeText:ClearAllPoints()
        if minimal then timeText:SetPoint("RIGHT", track, "LEFT", -8, 0) else timeText:SetPoint("LEFT", track, "RIGHT", 8, 0) end
        timeText:SetShown(Get("flightTimerTime") ~= "off")
        spark:SetShown(not minimal)
        local marker = Get("flightTimerMarker")
        local lift = minimal and 3 or 10 -- just over the spark
        UpdatePortrait()
        for kind, avatar in pairs(avatars) do
            avatar:SetShown(marker == kind)
            if marker == kind then
                avatar:ClearAllPoints()
                -- The tip points down at the spark; a round portrait sits centred over it.
                avatar:SetPoint(kind == "pointed" and "BOTTOMRIGHT" or "BOTTOM", fill, "RIGHT", 0, lift)
            end
        end
        mount:SetShown(marker == "mount")
        if marker == "mount" then
            -- Trilinear filtering reads the art's mipmaps: shrunk this far, its highlights blend
            -- instead of flickering into noise.
            mount:SetAtlas(UnitFactionGroup("player") == "Horde" and "ui-hud-actionbar-wyvern-left" or "ui-hud-actionbar-gryphon-left",
                false, "TRILINEAR")
            mount:ClearAllPoints()
            mount:SetPoint("BOTTOM", fill, "RIGHT", 0, lift - 3)
        end
        nameText:SetShown(marker == "name")
        nameArrow:SetShown(marker == "name")
        if marker == "name" then
            local color = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
            nameText:SetText(UnitName("player"))
            if color then nameText:SetTextColor(color.r, color.g, color.b) end
            nameArrow:SetPoint("BOTTOM", fill, "RIGHT", 0, lift - ARROW_HEIGHT / 2)
            nameText:ClearAllPoints()
            nameText:SetPoint("BOTTOM", nameArrow, "TOP", 0, -ARROW_HEIGHT / 2)
        end

        -- What fades where the marker meets an end name, with the marker's reach either side of the spark.
        for _, region in ipairs({ ends[1], ends[2], flags[1], flags[2], nameText, nameArrow, mount, avatars.pointed, avatars.round }) do
            region:SetAlpha(1)
        end
        local overlap = Get("flightTimerOverlap")
        fade = nil
        if marker and marker ~= "none" and overlap ~= "none" then
            local half = marker == "name" and (nameText:GetStringWidth() or 0) / 2
                or marker == "mount" and MOUNT_HEIGHT * 154 / 95 / 2 or AVATAR_SIZE / 2
            fade = { mode = overlap, left = marker == "pointed" and AVATAR_SIZE or half, right = marker == "pointed" and 0 or half,
                marker = marker == "name" and { nameText, nameArrow } or marker == "mount" and { mount } or { avatars[marker] } }
        end
        over:SetScript("OnUpdate", fade and Fade or nil)
        LayoutRoute()
        -- The marker rises over the frame; screen clamping keeps it on screen too.
        local shown = marker == "name" and nameText or marker == "mount" and mount or avatars[marker]
        local top, frameTop = shown and shown:GetTop(), display:GetTop()
        local rise = top and frameTop and top * shown:GetEffectiveScale() / display:GetEffectiveScale() - frameTop or 0
        display:SetClampRectInsets(0, 0, math.max(0, rise), 0)
    end

    local function UpdateTime()
        local left = FormatTime(flight.eta - (GetTime() - flight.start))
        timeText:SetText(Get("flightTimerTime") == "total" and (left .. " / " .. FormatTime(flight.eta)) or left)
    end

    local bar = { UpdateTime = UpdateTime }
    module.flightTimerBar = bar

    -- Shows f, or shows it anew after its ETA or route changed.
    function bar.Show(f)
        flight = f
        local duration = C_DurationUtil.CreateDuration()
        duration:SetTimeFromStart(flight.start, flight.eta)
        track:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
        display:Show()
        ApplyStyle()
        UpdateTime()
    end

    function bar.Hide()
        flight = nil
        display:Hide()
    end

    -- Every option restyles; the time text follows at once rather than on the next tick.
    function module.UpdateFlightTimerStyle()
        ApplyStyle()
        if flight then UpdateTime() end
    end

    over:RegisterEvent("PLAYER_LOGIN")
    over:RegisterEvent("PORTRAITS_UPDATED")
    over:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
    over:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            ApplyStyle()
            over:UnregisterEvent("PLAYER_LOGIN")
        else
            UpdatePortrait()
        end
    end)
end)
