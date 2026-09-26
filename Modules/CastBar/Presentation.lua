local _, ns = ...
local cast = ns.CastBar

function cast.GetLayout(get, nativeWidth, nativeHeight)
    get = get or cast.Get
    local compact = get("layout") == "compact"
    local width, height = get("width"), get("height")
    if not width or width == 0 then width = compact and 240 or nativeWidth or 208 end
    if not height or height == 0 then height = compact and 22 or nativeHeight or 11 end
    local icon = get("icon")
    if icon == "native" and compact then icon = "left" end
    local inside = icon == "inside_left" or icon == "inside_right"
    local slot = inside and height + 1 or 0
    local left = icon == "inside_left" and slot or 0
    local right = icon == "inside_right" and slot or 0
    return { width = width, height = height, fillWidth = width - slot, icon = icon,
        inside = inside, left = left, right = right, gap = inside and 1 or get("iconGap"), compact = compact }
end

function cast.GetTint(mode, color)
    if mode == "custom" then return color end
    if mode == "class" then
        local _, class = UnitClass("player")
        if not (issecretvalue and issecretvalue(class)) then return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] end
    end
end

function cast.AnchorBounds(bounds, fill, layout)
    bounds:ClearAllPoints()
    bounds:SetPoint("TOPLEFT", fill, "TOPLEFT", -layout.left, 0)
    bounds:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", layout.right, 0)
end

function cast.AnchorIcon(icon, fill, layout)
    icon:SetSize(layout.height, layout.height)
    icon:ClearAllPoints()
    if layout.icon == "left" or layout.icon == "inside_left" then
        icon:SetPoint("RIGHT", fill, "LEFT", -layout.gap, 0)
    else
        icon:SetPoint("LEFT", fill, "RIGHT", layout.gap, 0)
    end
end

function cast.AnchorDivider(divider, fill, layout)
    divider:ClearAllPoints()
    divider:SetWidth(1)
    local side, x = layout.left > 0 and "LEFT" or "RIGHT", layout.left > 0 and -.5 or .5
    divider:SetPoint("TOP", fill, "TOP" .. side, x, 0)
    divider:SetPoint("BOTTOM", fill, "BOTTOM" .. side, x, 0)
    divider:SetShown(layout.inside)
end

function cast.HasTextOverrides(get)
    get = get or cast.Get
    for _, key in ipairs({ "name", "time" }) do
        if get(key .. "Position") ~= "native" or get(key .. "Alignment") ~= "native" or get(key .. "Spacing") ~= -1 then return true end
    end
    return false
end

-- Rectangles use fill-local coordinates. Never measure spell names or timing
-- strings: their contents can be restricted, and ticking text must not jitter.
function cast.LayoutText(name, time, fill, layout, get, showName, showTime)
    get = get or cast.Get
    local width, height = fill:GetWidth(), fill:GetHeight()
    local _, _, nativeIcon, _, nativeIconWidth = cast.GetNativeLayout()
    local left, right = layout.left, layout.right
    if layout.icon == "left" then left = height + layout.gap
    elseif layout.icon == "right" then right = height + layout.gap
    elseif layout.icon == "native" and nativeIcon then left = nativeIconWidth + 5 end
    local boxes = { left = 0, right = 0, top = 0, bottom = 0 }
    for _, info in ipairs({ { "name", name, showName }, { "time", time, showTime } }) do
        local key, text, shown = unpack(info)
        local position, alignment, spacing = get(key .. "Position"), get(key .. "Alignment"), get(key .. "Spacing")
        if position == "native" then
            if layout.compact then position = "inside"
            elseif key == "time" then position = "right"
            elseif cast.frame and cast.frame.look == "UNITFRAME" then position = "inside"
            else position = "below" end
        end
        if alignment == "native" then
            if key == "name" then alignment = layout.compact and "left" or "center"
            else alignment = position == "right" and "left" or "right" end
        end
        local inside, side = position == "inside", position == "left" or position == "right"
        if spacing < 0 then
            if inside then spacing = 6
            elseif side then spacing = 10
            else spacing = 2 end
        end
        local size = text and select(2, text:GetFont()) or 12
        local h = inside and height or size + 4
        local inset = math.min(inside and spacing or 0, math.max(0, (width - 2) / 2))
        local available = width - 2 * inset
        local w = available
        if key == "time" then
            w = size * (get("timeFormat") == "remainingTotal" and 6.5 or 4)
            if not side then w = math.min(w, available, width * .48) end
        end
        local x = inset
        if key == "time" and not side then
            if alignment == "right" then x = x + (available - w)
            elseif alignment == "center" then x = x + (available - w) / 2 end
        end
        local y = -h / 2
        if position == "above" then y = height / 2 + spacing
        elseif position == "below" then y = -height / 2 - spacing - h
        elseif position == "left" then x = -left - spacing - w
        elseif position == "right" then x = width + right + spacing end
        boxes[key] = { x = x, y = y, width = w, height = h, alignment = alignment, position = position, shown = shown }
    end
    local n, t = boxes.name, boxes.time
    if showName and showTime and n.y < t.y + t.height and t.y < n.y + n.height
        and n.x < t.x + t.width and t.x < n.x + n.width then
        -- Time owns its slot; align the name in the remaining contiguous space.
        local endX = n.x + n.width
        local before, after = math.max(0, t.x - 6 - n.x), math.max(0, endX - t.x - t.width - 6)
        if (n.alignment == "right" and after > 0) or before == 0 then
            n.x, n.width = t.x + t.width + 6, after
        else
            n.width = before
        end
    end
    for _, info in ipairs({ { name, n }, { time, t } }) do
        local text, box = unpack(info)
        if text then
            text:ClearAllPoints()
            local point = text == time and "RIGHT" or "LEFT"
            local x = point == "RIGHT" and box.x + box.width - width or box.x
            text:SetPoint(point, fill, point, x, box.y + box.height / 2)
            text:SetSize(math.max(1, box.width), box.height)
            text:SetJustifyH(box.alignment:upper())
            text:SetWordWrap(false)
            text:SetNonSpaceWrap(false)
        end
        if box.shown and box.width > 0 then
            boxes.left = math.max(boxes.left, -box.x)
            boxes.right = math.max(boxes.right, box.x + box.width - width)
            boxes.top = math.max(boxes.top, box.y + box.height - height / 2)
            boxes.bottom = math.max(boxes.bottom, -height / 2 - box.y)
        end
    end
    return boxes
end

function cast.CreateBorder(parent, original)
    local art = original or parent:CreateTexture(nil, "OVERLAY")
    if not original then art:SetAtlas("ui-castingbar-frame") end
    local border = { frame = parent, art = art, lines = {}, color = { art:GetVertexColor() },
        alpha = art:GetAlpha(), desaturated = art:IsDesaturated(), points = {} }
    for i = 1, art:GetNumPoints() do border.points[i] = { art:GetPoint(i) } end
    for i = 1, 8 do
        local line = parent:CreateTexture(nil, "OVERLAY")
        line:Hide()
        border.lines[i] = line
    end
    return border
end

function cast.RestoreBorder(border)
    if not border then return end
    for _, line in ipairs(border.lines) do line:Hide() end
    local art = border.art
    art:ClearAllPoints()
    for _, point in ipairs(border.points) do art:SetPoint(unpack(point)) end
    art:SetVertexColor(unpack(border.color))
    art:SetDesaturated(border.desaturated)
    art:SetAlpha(border.alpha)
end

local function edge(region, target, side, inset, size, color)
    region:ClearAllPoints()
    if side == 1 or side == 2 then
        local point = side == 1 and "TOP" or "BOTTOM"
        local y = side == 1 and -inset or inset
        region:SetPoint(point .. "LEFT", target, point .. "LEFT", inset, y)
        region:SetPoint(point .. "RIGHT", target, point .. "RIGHT", -inset, y)
        region:SetHeight(size)
    else
        local point = side == 3 and "LEFT" or "RIGHT"
        local x = side == 3 and inset or -inset
        region:SetPoint("TOP" .. point, target, "TOP" .. point, x, -inset)
        region:SetPoint("BOTTOM" .. point, target, "BOTTOM" .. point, x, inset)
        region:SetWidth(size)
    end
    region:SetColorTexture(color.r, color.g, color.b)
    region:Show()
end

function cast.TintBorderArt(art, color, original, opacity)
    art:SetDesaturated(color and true or original.desaturated)
    if color then art:SetVertexColor(color.r, color.g, color.b)
    else art:SetVertexColor(unpack(original.color)) end
    art:SetAlpha(original.alpha * opacity)
end

local function pixelSize(frame)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
    return factor / frame:GetEffectiveScale()
end

function cast.GetBorderOutset(frame, get)
    get = get or cast.Get
    local style = get("borderStyle")
    if style == "native" then return 2 end
    if style == "none" then return 0 end
    return (style == "thin" and get("borderSize") or 2) * pixelSize(frame)
end

function cast.DrawBorder(border, get)
    get = get or cast.Get
    local style, opacity = get("borderStyle"), get("borderOpacity")
    local color = cast.GetTint(get("borderColorMode"), get("borderColor"))
    for _, line in ipairs(border.lines) do line:Hide() end
    local art = border.art
    art:SetAlpha(0)
    if style == "none" then return end
    if style == "native" then
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT", border.frame, "TOPLEFT", -2, 2)
        art:SetPoint("BOTTOMRIGHT", border.frame, "BOTTOMRIGHT", 2, -2)
        cast.TintBorderArt(art, color, border, opacity)
        return
    end
    color = color or { r = .58, g = .55, b = .48 }
    -- A fixed screen-pixel stroke stays crisp under Blizzard's Bar Size / UI scale.
    local pixel = pixelSize(border.frame)
    local layers = style == "inset" and 8 or 4
    local stroke = (style == "thin" and get("borderSize") or 1) * pixel
    for i = 1, layers do
        local side = (i - 1) % 4 + 1
        local shade = color
        if style == "inset" then
            local factor = i <= 4 and .22 or (side == 1 or side == 3) and .55 or 1
            shade = { r = color.r * factor, g = color.g * factor, b = color.b * factor }
        end
        edge(border.lines[i], border.frame, side, style == "thin" and -stroke or i <= 4 and -2 * pixel or -pixel,
            stroke, shade)
        border.lines[i]:SetAlpha(opacity)
    end
end

-- Static settings sample. It shares geometry and frame rendering with the live bar.
function cast.CreatePreview(parent)
    local view = CreateFrame("Frame", nil, parent)
    view.fill = CreateFrame("Frame", nil, view)
    view.bounds = CreateFrame("Frame", nil, view.fill)
    view.background = view.fill:CreateTexture(nil, "BACKGROUND")
    view.background:SetAtlas("ui-castingbar-background")
    view.background:SetAllPoints(view.fill)
    view.progress = view.fill:CreateTexture(nil, "ARTWORK")
    view.icon = view.fill:CreateTexture(nil, "ARTWORK")
    view.icon:SetTexture("Interface\\Icons\\Spell_Holy_HolyBolt")
    view.divider = view.fill:CreateTexture(nil, "OVERLAY")
    view.divider:SetColorTexture(.12, .10, .08)
    view.iconBounds = CreateFrame("Frame", nil, view.fill)
    view.iconBounds:SetAllPoints(view.icon)
    view.border = cast.CreateBorder(view.bounds)
    view.iconBorder = cast.CreateBorder(view.iconBounds)
    view.name = view.fill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.time = view.fill:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    view.name:SetText(ns.L.castBarPreviewSpell)
    view.name:SetWordWrap(false)
    view.time:SetText("1.8")
    return view
end

function cast.UpdatePreview(view, get, availableWidth, miniature)
    get = get or cast.Get
    local nw, nh, nativeIcon, backgroundAlpha, nativeIconWidth, nativeIconHeight = cast.GetNativeLayout()
    local layout = cast.GetLayout(get, nw, nh)
    local iconShown = layout.icon ~= "off" and (layout.icon ~= "native" or nativeIcon)
    local outside = iconShown and not layout.inside
    local left = layout.left + (outside and layout.icon ~= "right"
        and (layout.icon == "native" and nativeIconWidth + 5 or layout.height + layout.gap) or 0)
    local right = layout.right + (outside and layout.icon == "right" and layout.height + layout.gap or 0)
    local totalWidth = layout.fillWidth + left + right
    view:SetScale(math.min(1, (availableWidth - 8) / (totalWidth + 4), 42 / (layout.height + 4)))
    view:SetSize(totalWidth, layout.height)
    view.fill:ClearAllPoints()
    view.fill:SetPoint("LEFT", view, "LEFT", left, 0)
    view.fill:SetSize(layout.fillWidth, layout.height)
    cast.AnchorBounds(view.bounds, view.fill, layout)
    cast.AnchorIcon(view.icon, view.fill, layout)
    if layout.icon == "native" then
        view.icon:SetSize(nativeIconWidth, nativeIconHeight)
        view.icon:ClearAllPoints()
        view.icon:SetPoint("RIGHT", view.fill, "LEFT", -5, 0)
    end
    view.icon:SetShown(iconShown)
    view.iconBounds:SetShown(iconShown and not layout.inside)
    cast.DrawBorder(view.border, get)
    cast.DrawBorder(view.iconBorder, get)
    cast.AnchorDivider(view.divider, view.fill, layout)
    local descriptor = cast.GetTexture(get("texture"))
    local progress = view.progress
    local color = cast.GetTint(get("colorMode"), get("customColor"))
    progress:SetAlpha(1)
    progress:ClearAllPoints()
    progress:SetPoint("TOPLEFT", view.fill, "TOPLEFT", 0, 0)
    progress:SetPoint("BOTTOMLEFT", view.fill, "BOTTOMLEFT", 0, 0)
    progress:SetSize(layout.fillWidth * .6, layout.height)
    cast.PaintTexture(progress, descriptor, .6, color)
    local opacity = get("backgroundOpacity")
    cast.PaintBackground(view.background, descriptor, opacity, backgroundAlpha)
    local showTime = not miniature and (not cast.frame or cast.frame.showCastTimeSetting)
    view.name:SetAlpha(1)
    view.name:SetShown(not miniature and get("showSpellName"))
    view.time:SetShown(showTime)
    view.time:SetText(get("timeFormat") == "remainingTotal" and "1.8 / 3.0" or "1.8")
    local textBounds = cast.ApplyTextLayout(view.name, view.time, view.fill, layout, get,
        view.name:IsShown(), view.time:IsShown())
    if textBounds then
        view.name:SetAlpha(textBounds.name.width > 0 and 1 or 0)
        local extentLeft, extentRight = math.max(left, textBounds.left), math.max(right, textBounds.right)
        local totalHeight = layout.height + textBounds.top + textBounds.bottom
        view:SetSize(layout.fillWidth + extentLeft + extentRight, totalHeight)
        view.fill:ClearAllPoints()
        view.fill:SetPoint("TOPLEFT", view, "TOPLEFT", extentLeft, -textBounds.top)
        view:SetScale(math.min(1, (availableWidth - 8) / (view:GetWidth() + 4), 42 / (totalHeight + 4)))
    else
        local extra = showTime and 58 or 0
        view:SetWidth(totalWidth + extra)
        view:SetScale(math.min(1, (availableWidth - 8) / (totalWidth + extra + 4), 42 / (layout.height + 20)))
    end
end
