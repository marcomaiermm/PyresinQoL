local _, ns = ...
local castBar = ns.CastBar
local frame, native, latency, styled, presentation, layout
local sparkFX = { "StandardGlow", "CraftGlow", "ChannelShadow" }
local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function rememberFill()
    castBar.ClearTexture(frame)
    local texture = frame:GetStatusBarTexture()
    if not texture then native.fill, native.color = nil, nil; return end
    local atlas = texture.GetAtlas and texture:GetAtlas()
    local file = texture:GetTexture()
    local r, g, b, a = frame:GetStatusBarColor()
    if secret(atlas) or secret(file) or secret(r) or secret(g) or secret(b) or secret(a) then
        native.fill, native.color = nil, nil
        return
    end
    native.fill = atlas or file
    native.color = { r, g, b, a }
end

local function restoreFill()
    castBar.ClearTexture(frame)
    if secret(frame.barType) then native.fill, native.color = nil, nil; return end
    if native.fill then frame:SetStatusBarTexture(native.fill) end
    if native.color then frame:SetStatusBarColor(unpack(native.color)) end
end

local function rememberFont(region)
    if not region or not region.GetFont then return end
    local path, size, flags = region:GetFont()
    local object = region.GetFontObject and region:GetFontObject()
    if secret(path) or secret(size) or secret(flags) or secret(object) then return end
    return { path, size, flags, object }
end

local function setFont(region, original, size)
    if not region or not original then return end
    if not size and original[4] and region.SetFontObject then
        region:SetFontObject(original[4])
    elseif original[1] and original[2] then
        region:SetFont(original[1], size or original[2], original[3])
    end
end

local function capturePoints(region)
    local points = {}
    if region then
        for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    end
    return points
end

local function restorePoints(region, points)
    if not region then return end
    region:ClearAllPoints()
    for _, point in ipairs(points) do region:SetPoint(unpack(point)) end
end

local function anchorInset(shape, point)
    if not shape or not shape.inside then return 0 end
    local fraction = point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5
    return shape.left * (1 - fraction) - shape.right * fraction
end

local function shiftAnchor(previous, current, factor)
    native.adjustingAnchor = true
    for _, point in ipairs(capturePoints(frame)) do
        local offset = (anchorInset(current, point[1]) - anchorInset(previous, point[1])) * (factor or 1)
        if offset ~= 0 then
            point[4] = point[4] + offset
            -- Presentation offsets must not announce a new user position or snap.
            local setPoint = frame.SetPointBase or frame.SetPoint
            setPoint(frame, unpack(point))
        end
    end
    native.adjustingAnchor = nil
    native.anchorDirty = false
    native.anchorScale = frame:GetScale()
end

local function applyNativeAnchor()
    if native.anchorDirty and layout then shiftAnchor(nil, layout) end
end

function castBar.InstallPositionHooks()
    local manager = EditModeManagerFrame
    if not native or native.positionHooks or not manager or not manager.UpdateSystemAnchorInfo then return end
    native.positionHooks = true
    if EditModeSystemMixin and EditModeSystemMixin.ApplySystemAnchor then
        hooksecurefunc(EditModeSystemMixin, "ApplySystemAnchor", function(systemFrame)
            if systemFrame == frame then applyNativeAnchor() end
        end)
    end
    hooksecurefunc(manager, "UpdateSystemAnchorInfo", function(self, systemFrame)
        if systemFrame ~= frame or not layout or not layout.inside then return end
        local info = self:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
        if info then
            -- Blizzard saves the complete bar's logical anchor, not the fill inset.
            -- This prevents accumulating the icon offset after dragging or reloading.
            for _, key in ipairs({ "anchorInfo", "anchorInfo2" }) do
                local anchor = info[key]
                if anchor then anchor.offsetX = anchor.offsetX - anchorInset(layout, anchor.point) * frame:GetScale() end
            end
        end
        native.anchorDirty = false
    end)
end

local function restoreIcon()
    local icon = frame.Icon
    if not icon or not native.iconPoints then return end
    restorePoints(icon, native.iconPoints)
    if native.iconSize and icon.SetSize then icon:SetSize(unpack(native.iconSize)) end
end

local function captureIcon()
    local icon = frame.Icon
    if not icon or not icon.GetNumPoints then return end
    native.iconPoints = capturePoints(icon)
    if icon.GetWidth and icon.GetHeight then native.iconSize = { icon:GetWidth(), icon:GetHeight() } end
end

local function rememberSpark()
    native.sparkShown = frame.Spark and frame.Spark:IsShown()
    native.fxShown = native.fxShown or {}
    for _, key in ipairs(sparkFX) do
        if frame[key] then native.fxShown[key] = frame[key]:IsShown() end
    end
end

local function restoreSpark()
    if frame.Spark and native.sparkShown ~= nil then frame.Spark:SetShown(native.sparkShown) end
    for _, key in ipairs(sparkFX) do
        if frame[key] and native.fxShown[key] ~= nil then frame[key]:SetShown(native.fxShown[key]) end
    end
end

local function applySparkFX(customSize)
    customSize = not not (customSize and frame.Spark and not secret(frame.barType)
        and not secret(frame.channeling) and frame.barType ~= "empowered")
    if customSize and not frame.pyresinSparkMask then
        local mask = frame:CreateMaskTexture()
        mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(frame)
        frame.pyresinSparkMask = mask
    end
    local mask = frame.pyresinSparkMask
    if customSize ~= not not native.sparkClipped then
        for _, key in ipairs({ "Spark", unpack(sparkFX) }) do
            local region, state = frame[key], native.fx[key]
            if region then
                if customSize then
                    -- Replace the shaped mask for these regions, rather than intersecting both masks.
                    if state and state.borderMasked then region:RemoveMaskTexture(frame.BorderMask) end
                    region:AddMaskTexture(mask)
                else
                    region:RemoveMaskTexture(mask)
                    if state and state.borderMasked then region:AddMaskTexture(frame.BorderMask) end
                end
            end
        end
        native.sparkClipped = customSize
    end
    for _, key in ipairs(sparkFX) do
        local region, state = frame[key], native.fx[key]
        if region and state then
            region:SetHeight(customSize and frame:GetHeight() or state.height)
            region:ClearAllPoints()
            local c = state.texCoords
            if customSize then
                local channel = frame.channeling
                region:SetPoint(channel and "LEFT" or "RIGHT", frame.Spark, "CENTER", 0, 0)
                if channel then
                    region:SetTexCoord(c[5], c[6], c[7], c[8], c[1], c[2], c[3], c[4])
                else
                    region:SetTexCoord(unpack(c))
                end
            else
                for _, point in ipairs(state.points) do region:SetPoint(unpack(point)) end
                region:SetTexCoord(unpack(c))
            end
        end
    end
end

local function rememberText(region)
    if not region then return end
    return { points = capturePoints(region), width = region:GetWidth(), height = region:GetHeight(),
        justify = region:GetJustifyH(), wordWrap = region:CanWordWrap(), nonSpaceWrap = region:CanNonSpaceWrap() }
end

local function restoreText(region, state, target)
    if not region or not state then return end
    region:ClearAllPoints()
    region:SetSize(state.width, state.height)
    region:SetJustifyH(state.justify)
    region:SetWordWrap(state.wordWrap)
    region:SetNonSpaceWrap(state.nonSpaceWrap)
    for _, point in ipairs(state.points) do
        if point[2] == frame then
            region:SetPoint(point[1], target or frame, unpack(point, 3))
        else
            region:SetPoint(unpack(point))
        end
    end
end

-- Both the live bar and its preview start from the same native text baseline.
function castBar.ApplyTextLayout(name, time, fill, shape, get, showName, showTime)
    get = get or castBar.Get
    if native then
        restoreText(name, native.nameLayout, fill)
        restoreText(time, native.timeLayout, fill)
        local size = get("fontSize")
        if size == 0 then size = shape.compact and 12 or nil end
        setFont(name, native.nameFont, size)
        setFont(time, native.timeFont, size)
    end
    if not native or shape.compact or castBar.HasTextOverrides(get) then
        return castBar.LayoutText(name, time, fill, shape, get, showName, showTime)
    end
    -- Icon placement does not opt into Compact text placement or font sizing.
    if name and native.nameLayout and native.nameLayout.width > 0 then
        name:SetWidth(math.min(native.nameLayout.width, fill:GetWidth()))
    end
    local right = shape.right + (shape.icon == "right" and shape.height + shape.gap or 0)
    if right > 0 and time then
        for _, point in ipairs(capturePoints(time)) do
            if point[2] == fill and point[3] == "RIGHT" then
                point[4] = point[4] + right
                time:SetPoint(unpack(point))
            end
        end
    end
end

local function applyTextLayout()
    if not layout then return end
    local showName = frame.Text and frame.Text:IsShown()
        and (castBar.Get("showSpellName") or secret(frame.barType) or frame.barType == "interrupted")
    presentation.textBounds = castBar.ApplyTextLayout(frame.Text, frame.CastTimeText, frame, layout, nil,
        showName, frame.CastTimeText and frame.CastTimeText:IsShown())
    if frame.Text and presentation.textBounds then
        frame.Text:SetAlpha(showName and presentation.textBounds.name.width > 0 and native.alpha.Text or 0)
    end
end

local function restoreSelection()
    if not native.selectionModified then return end
    restorePoints(frame.Selection, native.selectionPoints)
    native.selectionModified = false
    if frame.UpdateClampOffsets then frame:UpdateClampOffsets() end
end

local function visualSides()
    local left, right = layout.left, layout.right
    if frame.Icon and frame.Icon:IsShown() and not layout.inside and layout.icon ~= "off" then
        if layout.icon == "right" then right = frame.Icon:GetWidth() + layout.gap
        elseif layout.icon == "left" then left = frame.Icon:GetWidth() + layout.gap
        else left = frame.Icon:GetWidth() + 5 end
    end
    return left, right
end

local function applySelection()
    if not layout or not frame.Selection then return end
    if not layout.compact and layout.icon == "native" and castBar.Get("borderStyle") == "native" and not castBar.HasTextOverrides() then
        restoreSelection()
        return
    end
    local left, right = visualSides()
    local outset = castBar.GetBorderOutset(frame)
    local iconOverhang = frame.Icon and frame.Icon:IsShown() and math.max(0, (frame.Icon:GetHeight() - layout.height) / 2) or 0
    local text = presentation.textBounds or { left = 0, right = 0, top = 0, bottom = 0 }
    frame.Selection:ClearAllPoints()
    frame.Selection:SetPoint("TOPLEFT", frame, "TOPLEFT", -math.max(left + outset, text.left), math.max(outset + iconOverhang, text.top))
    frame.Selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", math.max(right + outset, text.right),
        math.min(-text.bottom, -outset + math.min(-iconOverhang, layout.compact and 0 or frame.editModeSelectionBottomOffset or 0)))
    native.selectionModified = true
    if frame.UpdateClampOffsets then frame:UpdateClampOffsets() end
end

local function restore()
    if not styled then return end
    styled = false
    shiftAnchor(layout, nil)
    frame:SetWidth(native.width)
    frame:SetHeight(native.height)
    restoreFill()
    castBar.ClearModels(frame)
    castBar.RestoreBorder(presentation.border)
    if frame.TextBorder then castBar.TintBorderArt(frame.TextBorder, nil, native.textBorder, 1) end
    presentation.bounds:Hide()
    presentation.iconBounds:Hide()
    presentation.divider:Hide()
    presentation.textBounds = nil
    restorePoints(frame.BorderShield, native.shieldPoints)
    if frame.BorderShield then frame.BorderShield:SetSize(unpack(native.shieldSize)) end
    restoreSelection()
    if frame.Spark and native.sparkHeight then
        frame.Spark:SetSize(native.sparkWidth, native.sparkHeight)
    end
    for _, key in ipairs({ "Text", "Border", "BorderShield", "TextBorder", "Background" }) do
        local region = frame[key]
        if region and native.alpha[key] then region:SetAlpha(native.alpha[key]) end
    end
    setFont(frame.Text, native.nameFont)
    setFont(frame.CastTimeText, native.timeFont)
    restoreText(frame.Text, native.nameLayout)
    restoreText(frame.CastTimeText, native.timeLayout)
    restoreIcon()
    if frame.Icon then frame.Icon:SetShown(native.iconShown) end
    restoreSpark()
    applySparkFX(false)
    if frame.CastTimeText and frame.UpdateCastTimeText then frame:UpdateCastTimeText() end
    if latency then latency:Hide() end
end

local function applyLatency()
    if not latency then return end
    latency:Hide()
    if not castBar.Get("showLatency") or not GetNetStats then return end
    local casting, channeling, reverse = frame.casting, frame.channeling, frame.reverseChanneling
    local duration, width, barType = frame.maxValue, frame:GetWidth(), frame.barType
    if secret(casting) or secret(channeling) or secret(reverse) or secret(duration)
        or secret(width) or secret(barType) or not (casting or channeling or reverse)
        or type(duration) ~= "number" or duration <= 0 or type(width) ~= "number"
        or barType == "interrupted" or barType == "empowered" then return end
    local _, _, _, world = GetNetStats()
    if secret(world) or type(world) ~= "number" or world <= 0 then return end
    latency:SetWidth(math.min(width, width * (world / 1000) / duration))
    latency:SetAlpha(castBar.Get("latencyOpacity"))
    latency:ClearAllPoints()
    local side = channeling and "LEFT" or "RIGHT"
    latency:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0)
    latency:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0)
    latency:Show()
end

local function applyTime()
    local text = frame.CastTimeText
    local format = castBar.Get("timeFormat")
    if not text or format == "native" then return end
    local casting, channeling = frame.casting, frame.channeling
    if secret(casting) or secret(channeling) or not (casting or channeling) then return end
    local low, high = frame:GetMinMaxValues()
    local value = frame:GetValue()
    if secret(low) or secret(high) or secret(value)
        or type(low) ~= "number" or type(high) ~= "number" or type(value) ~= "number" then return end
    local remaining = math.max(low, casting and high - value or value)
    if format == "remaining" then
        text:SetText(string.format("%.1f", remaining))
    else
        text:SetText(string.format("%.1f / %.1f", remaining, high))
    end
    native.customTime = true
end

local function getFillStyle()
    local barType = frame.barType
    if secret(barType) then return end
    if barType == "empowered" then return end -- Native staged casts own their fill.
    local mode = castBar.Get("colorMode")
    local uninterruptible = barType == "uninterruptable"
    local interrupted = barType == "interrupted"
    local customShield = uninterruptible and castBar.Get("uninterruptible") == "custom"
    local descriptor = castBar.GetTexture(castBar.Get("texture"))
    if interrupted and (descriptor.id == "default" or descriptor.models or not castBar.Get("customInterruptTexture")) then return end
    -- Keep the chosen texture on interruption; red state feedback wins over its tint.
    if uninterruptible and not customShield then return end
    local color
    if customShield then
        color = castBar.Get("uninterruptibleColor")
    else
        color = castBar.GetTint(mode, castBar.Get("customColor"))
    end
    return descriptor, color, interrupted
end

local function applyFill()
    local descriptor, color, interrupted = getFillStyle()
    restoreFill()
    local custom = castBar.ApplyTexture(frame, descriptor, color)
    castBar.ApplyModels(frame, custom and descriptor)
    if custom then
        -- The hidden native fill has alpha zero; never copy its color/alpha to the artwork.
        local texture = frame.pyresinCastTexture
        texture:SetDesaturated(interrupted)
        if interrupted then
            castBar.ApplyInterruptStyle(frame)
        else
            castBar.AnimateTexture(frame, descriptor)
        end
    elseif color and descriptor.supportsTint ~= false then
        frame:SetStatusBarColor(color.r, color.g, color.b)
    end
end

local function applyIcon()
    local icon = frame.Icon
    if not icon then return end
    local iconMode = layout.icon
    restoreIcon()
    if iconMode == "off" then
        icon:Hide()
    elseif iconMode == "native" or secret(frame.barType) or secret(frame.casting)
        or secret(frame.channeling) or secret(frame.reverseChanneling) then
        icon:SetShown(native.iconShown)
    else
        castBar.AnchorIcon(icon, frame, layout)
        icon:SetShown((frame.casting or frame.channeling or frame.reverseChanneling or frame.isInEditMode) and true or false)
    end
end
local function applyPresentation()
    local width, height = castBar.Get("width"), castBar.Get("height")
    local nextLayout = castBar.GetLayout(nil, native.width, native.height)
    shiftAnchor(layout, nextLayout)
    layout = nextLayout
    local compact = layout.compact
    frame:SetWidth(layout.fillWidth)
    frame:SetHeight(layout.height)
    if frame.Spark and native.sparkHeight and native.sparkHeight > 0 then
        local sparkHeight = (compact or layout.inside or height ~= 0) and frame:GetHeight() or native.sparkHeight
        frame.Spark:SetSize(native.sparkWidth * sparkHeight / native.sparkHeight, sparkHeight)
    end
    applySparkFX(compact or layout.inside or width ~= 0 or height ~= 0 or castBar.Get("texture") ~= "default")
    applyFill()

    local name = frame.Text
    if name then
        local interrupted = frame.barType
        local show = secret(interrupted) or interrupted == "interrupted"
        name:SetAlpha((castBar.Get("showSpellName") or show) and native.alpha.Text or 0)
    end
    applyTextLayout()
    if castBar.Get("timeFormat") == "native" and native.customTime and frame.UpdateCastTimeText then
        native.customTime = false
        frame:UpdateCastTimeText()
    else
        applyTime()
    end

    presentation.bounds:Show()
    castBar.AnchorBounds(presentation.bounds, frame, layout)
    castBar.DrawBorder(presentation.border)
    if frame.TextBorder then
        local opacity = castBar.Get("borderStyle") == "native" and not compact
            and castBar.Get("namePosition") == "native" and castBar.Get("nameSpacing") == -1
            and castBar.Get("borderOpacity") or 0
        castBar.TintBorderArt(frame.TextBorder,
            castBar.GetTint(castBar.Get("borderColorMode"), castBar.Get("borderColor")), native.textBorder, opacity)
    end
    -- The native shield conveys interruptibility, independently of the decorative border.
    if frame.BorderShield then
        frame.BorderShield:SetAlpha(native.alpha.BorderShield)
        restorePoints(frame.BorderShield, native.shieldPoints)
        frame.BorderShield:SetSize(unpack(native.shieldSize))
    end
    if frame.Background and native.alpha.Background then
        local opacity = castBar.Get("backgroundOpacity")
        local custom = frame.pyresinCastBackground and frame.pyresinCastBackground:IsShown()
        frame.Background:SetAlpha(custom and 0 or (opacity < 0 and native.alpha.Background or opacity))
    end
    if castBar.Get("showSpark") then
        restoreSpark()
    else
        if frame.Spark then frame.Spark:Hide() end
        for _, key in ipairs(sparkFX) do if frame[key] then frame[key]:Hide() end end
    end
    applyIcon()
    presentation.iconBounds:SetShown(frame.Icon and frame.Icon:IsShown() and not layout.inside)
    castBar.DrawBorder(presentation.iconBorder)
    castBar.AnchorDivider(presentation.divider, frame, layout)
    if frame.BorderShield and layout.icon ~= "native" and frame.BorderShield:GetAtlas() == "ui-castingbar-shield" then
        local left = visualSides()
        local shieldHeight = math.max(22, layout.height + 8)
        frame.BorderShield:ClearAllPoints()
        frame.BorderShield:SetSize(shieldHeight * 29 / 33, shieldHeight)
        frame.BorderShield:SetPoint("RIGHT", frame, "LEFT", -left - 4, 0)
    end
    applySelection()
    applyLatency()
    styled = true
end

function castBar.GetNativeLayout()
    if native then
        return native.width, native.height, native.iconShown, native.alpha.Background or 1,
            native.iconSize and native.iconSize[1] or 16, native.iconSize and native.iconSize[2] or 16
    end
    return 208, 11, false, 1, 16, 16
end

function castBar.Apply()
    if not frame then return end
    if not castBar.IsEnabled() or not castBar.HasOverrides() then
        restore()
        layout = nil
        return
    end
    applyPresentation()
end

local function attach()
    local player = PlayerCastingBarFrame
    if not player or not player.UpdateBarFillTexture or not player.SetLook or not hooksecurefunc then return false end
    frame = player
    castBar.frame = frame
    native = { width = frame:GetWidth(), height = frame:GetHeight(), alpha = {}, fx = {}, anchorScale = frame:GetScale(),
        sparkWidth = frame.Spark and frame.Spark:GetWidth(),
        sparkHeight = frame.Spark and frame.Spark:GetHeight() }
    for _, key in ipairs({ "Text", "Border", "BorderShield", "TextBorder", "Background" }) do
        local region = frame[key]
        if region then native.alpha[key] = region:GetAlpha() end
    end
    for _, key in ipairs(sparkFX) do
        local region = frame[key]
        if region then
            local state = { height = region:GetHeight(), points = capturePoints(region), texCoords = { region:GetTexCoord() } }
            for i = 1, region:GetNumMaskTextures() do
                if region:GetMaskTexture(i) == frame.BorderMask then state.borderMasked = true end
            end
            native.fx[key] = state
        end
    end
    if frame.TextBorder then
        native.textBorder = { color = { frame.TextBorder:GetVertexColor() },
            desaturated = frame.TextBorder:IsDesaturated(), alpha = frame.TextBorder:GetAlpha() }
    end
    native.shieldPoints = capturePoints(frame.BorderShield)
    native.shieldSize = frame.BorderShield and { frame.BorderShield:GetSize() }
    native.selectionPoints = capturePoints(frame.Selection)
    native.selectionLocked = frame.lockedToPlayerFrame
    native.nameLayout = rememberText(frame.Text)
    native.timeLayout = rememberText(frame.CastTimeText)
    -- Native timer text has no explicit size; retain automatic text measurement.
    if native.timeLayout then native.timeLayout.width, native.timeLayout.height = 0, 0 end
    native.nameFont = rememberFont(frame.Text)
    native.timeFont = rememberFont(frame.CastTimeText)
    native.iconShown = frame.Icon and frame.Icon:IsShown()
    captureIcon()
    rememberFill()
    if frame.CreateTexture then
        latency = frame:CreateTexture(nil, "ARTWORK", nil, 2)
        latency:SetColorTexture(1, 1, 1)
        latency:Hide()
        frame.pyresinCastLatency = latency
    end

    presentation = {}
    frame.pyresinCastPresentation = presentation
    presentation.bounds = CreateFrame("Frame", nil, frame)
    presentation.bounds:Hide()
    presentation.border = castBar.CreateBorder(presentation.bounds, frame.Border)
    presentation.iconBounds = CreateFrame("Frame", nil, frame)
    if frame.Icon then presentation.iconBounds:SetAllPoints(frame.Icon) end
    presentation.iconBounds:Hide()
    presentation.iconBorder = castBar.CreateBorder(presentation.iconBounds)
    presentation.divider = frame:CreateTexture(nil, "OVERLAY")
    presentation.divider:SetColorTexture(.12, .10, .08)
    presentation.divider:Hide()
    hooksecurefunc(frame, "SetPoint", function()
        if not native.adjustingAnchor then native.anchorDirty = true end
    end)
    if frame.ApplySystemAnchor then hooksecurefunc(frame, "ApplySystemAnchor", applyNativeAnchor) end
    for _, name in ipairs({ "PlayerFrame_AttachCastBar", "PlayerFrame_AdjustAttachments" }) do
        if _G[name] then hooksecurefunc(name, function()
            if frame.attachedToPlayerFrame then applyNativeAnchor() end
        end) end
    end
    local parent = frame.layoutParent
    if parent and parent.Layout then
        hooksecurefunc(parent, "Layout", function()
            if frame.IsInDefaultPosition and frame:IsInDefaultPosition() then applyNativeAnchor() end
        end)
    end
    castBar.InstallPositionHooks()
    local function refreshBounds()
        if not castBar.IsEnabled() or not layout then return end
        applySelection()
        castBar.DrawBorder(presentation.border)
        castBar.DrawBorder(presentation.iconBorder)
    end
    hooksecurefunc(frame, "SetScale", function()
        -- Blizzard rescales existing offsets; keep the icon inset in current bar units.
        if frame.SetScaleBase and layout and native.anchorScale ~= frame:GetScale() then
            shiftAnchor(nil, layout, 1 - native.anchorScale / frame:GetScale())
        end
        native.anchorScale = frame:GetScale()
        refreshBounds()
    end)
    if frame.AnchorSelectionFrame then
        hooksecurefunc(frame, "AnchorSelectionFrame", function()
            if native.selectionLocked ~= frame.lockedToPlayerFrame then
                native.selectionPoints = capturePoints(frame.Selection)
                native.selectionLocked = frame.lockedToPlayerFrame
            end
            refreshBounds()
        end)
    end
    hooksecurefunc(frame, "UpdateBarFillTexture", function()
        rememberFill()
        if castBar.IsEnabled() then castBar.Apply() end
    end)
    hooksecurefunc(frame, "SetLook", function()
        native.width, native.height = frame:GetWidth(), frame:GetHeight()
        native.shieldPoints = capturePoints(frame.BorderShield)
        native.shieldSize = frame.BorderShield and { frame.BorderShield:GetSize() }
        native.nameFont = rememberFont(frame.Text)
        -- SetLook changes geometry and font, but not wrapping or justification.
        if native.nameLayout then
            native.nameLayout.points = capturePoints(frame.Text)
            native.nameLayout.width, native.nameLayout.height = frame.Text:GetSize()
        end
        if castBar.IsEnabled() then castBar.Apply() end
    end)
    if frame.UpdateIconShown then
        hooksecurefunc(frame, "UpdateIconShown", function()
            if frame.Icon then native.iconShown = frame.Icon:IsShown() end
            if castBar.IsEnabled() and layout then
                applyIcon()
                presentation.iconBounds:SetShown(frame.Icon and frame.Icon:IsShown() and not layout.inside)
                applySelection()
            end
        end)
    end
    if frame.ShowSpark then
        hooksecurefunc(frame, "ShowSpark", function()
            rememberSpark()
            if castBar.IsEnabled() then castBar.Apply() end
        end)
    end
    if frame.HideSpark then
        hooksecurefunc(frame, "HideSpark", function()
            rememberSpark()
            if latency then latency:Hide() end
        end)
    end
    if frame.UpdateCastTimeTextShown then
        hooksecurefunc(frame, "UpdateCastTimeTextShown", function()
            if castBar.IsEnabled() then applyTextLayout(); applySelection() end
        end)
    end
    if frame.UpdateCastTimeText then
        hooksecurefunc(frame, "UpdateCastTimeText", function()
            if castBar.IsEnabled() then applyTime() end
        end)
    end
    if frame.HandleCastStart then
        hooksecurefunc(frame, "HandleCastStart", function() if castBar.IsEnabled() then castBar.Apply() end end)
    end
    for _, method in ipairs({ "HandleCastDelayed", "HandleChannelUpdateDelayed" }) do
        if frame[method] then
            hooksecurefunc(frame, method, function()
                if castBar.IsEnabled() then applyLatency() end
            end)
        end
    end
    if frame.Text and frame.Text.SetText then
        hooksecurefunc(frame.Text, "SetText", function()
            if castBar.IsEnabled() and not castBar.Get("showSpellName") then
                local barType = frame.barType
                frame.Text:SetAlpha((secret(barType) or barType == "interrupted") and native.alpha.Text or 0)
                applyTextLayout()
                applySelection()
            end
        end)
    end
    rememberSpark()
    castBar.Apply()
    return true
end

ns.RegisterModule("unitFrames", function()
    if attach() then return end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        attach()
    end)
end)
