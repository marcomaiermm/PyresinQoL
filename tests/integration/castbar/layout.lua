local h = assert(loadfile("tests/support/castbar.lua"))(arg[1])
local castBar, frame = h.castBar, PlayerCastingBarFrame
local StartCast, Advance, FailCast = h.StartCast, h.Advance, h.FailCast
local secret, Frame, Region = h.secret, h.Frame, h.Region
local Near, usingNativeSource = h.Near, h.usingNativeSource
local latency = frame.pyresinCastLatency
castBar.SetEnabled(true)

-- Automatic, explicit text placement and custom fonts use the same native baseline.
do
    local preview = castBar.CreatePreview(Frame())
    for _, look in ipairs({ "UNITFRAME", "CLASSIC" }) do
        frame:SetLook(look)
        for _, style in ipairs({ "native", "compact" }) do
            castBar.Set("layout", style)
            for _, icon in ipairs({ "native", "right", "inside_left" }) do
                castBar.Set("icon", icon)
                for _, position in ipairs({ "native", "above" }) do
                    castBar.Set("namePosition", position)
                    for _, size in ipairs({ 0, 16 }) do
                        castBar.Set("fontSize", size)
                        castBar.UpdatePreview(preview, nil, 343)
                        for _, pair in ipairs({ { frame.Text, preview.name }, { frame.CastTimeText, preview.time } }) do
                            local live, sample = unpack(pair)
                            assert(live:GetNumPoints() == sample:GetNumPoints())
                            for i = 1, live:GetNumPoints() do
                                local actual, expected = { sample:GetPoint(i) }, { live:GetPoint(i) }
                                for j, value in ipairs(expected) do
                                    assert(actual[j] == (value == frame and preview.fill or value),
                                        "Preview text anchors must match the live native/overridden layout")
                                end
                            end
                            Near(sample:GetWidth(), live:GetWidth())
                            Near(sample:GetHeight(), live:GetHeight())
                            assert(select(2, sample:GetFont()) == select(2, live:GetFont()),
                                "Preview uses the same native or explicit text size")
                        end
                    end
                end
            end
            castBar.Reset()
        end
    end
    frame:SetLook("UNITFRAME")
    for _, finish in ipairs({ castBar.Reset, function() castBar.SetEnabled(false) end }) do
        castBar.SetEnabled(true)
        local wordWrap, nonSpaceWrap = frame.Text:CanWordWrap(), frame.Text:CanNonSpaceWrap()
        assert(wordWrap and nonSpaceWrap, "Each restoration case starts from the untouched native baseline")
        castBar.Set("layout", "compact")
        frame:SetLook("CLASSIC")
        finish()
        assert(frame.Text:CanWordWrap() == wordWrap and frame.Text:CanNonSpaceWrap() == nonSpaceWrap,
            "Reset/disable cannot retain Compact wrapping after a native look change")
        castBar.Reset()
        frame:SetLook("UNITFRAME")
    end
    castBar.SetEnabled(true)
end
castBar.Reset()

assert(castBar.Set("width", 260) and castBar.Set("height", 22))
assert(castBar.Set("fontSize", 18) and castBar.Set("icon", "right"))
StartCast(false, false)
frame:SetLook("CLASSIC") -- Real Blizzard SetLook nests UpdateIconShown before returning.
assert(frame:GetWidth() == 260 and frame:GetHeight() == 22)
assert(select(2, frame.Text:GetFont()) == 18)
assert(castBar.SetEnabled(false))
assert(frame:GetWidth() == 208 and frame:GetHeight() == 11,
    "Disabling after a native look change must restore that look, not a customized dimension")
assert(select(2, frame.Text:GetFont()) == 12 and not frame.Icon:IsShown())
assert(castBar.SetEnabled(true))
frame:SetLook("UNITFRAME")
assert(frame:GetWidth() == 260 and frame:GetHeight() == 22)
castBar.Reset()
assert(frame.Icon:GetWidth() == 16 and frame.Icon:GetHeight() == 16)
assert(frame:GetWidth() == 150 and frame:GetHeight() == 10)
assert(select(2, frame.Text:GetFont()) == 12)
assert(frame.Icon.points[1][1] == "CENTER" and frame:GetScale() == .85)
frame.CraftGlow:Show() -- Native XML animation owns this FX; it is not a Lua mixin property.
frame:ShowSpark()
assert(frame.CraftGlow:IsShown())
assert(castBar.Set("showSpark", false))
assert(not frame.CraftGlow:IsShown(), "Hiding Spark also hides Blizzard's XML CraftGlow")
assert(castBar.SetEnabled(false))
assert(frame.CraftGlow:IsShown(), "Disable restores the native FX visibility")
assert(castBar.SetEnabled(true))
castBar.Reset()
assert(frame.CraftGlow:IsShown(), "Reset restores native FX without changing cast state")

local originalWordWrap, originalNonSpaceWrap = frame.Text:CanWordWrap(), frame.Text:CanNonSpaceWrap()
assert(castBar.Set("layout", "compact"))
assert(frame:GetWidth() == 240 and frame:GetHeight() == 22)
assert(frame.Text.points[1][1] == "LEFT" and frame.Text:GetJustifyH() == "LEFT")
assert(frame.CastTimeText.points[1][1] == "RIGHT" and frame.Icon.points[1][1] == "RIGHT")
assert(frame.Icon:GetWidth() == 22 and frame.TextBorder:GetAlpha() == 0)
local function CheckSparkBounds()
    local mask = frame.pyresinSparkMask
    assert(mask and mask.allPoints == frame, "Spark mask must follow the actual bar bounds")
    assert(mask:GetTexture() == "Interface\\Buttons\\WHITE8X8"
        and mask.hWrap == "CLAMPTOBLACKADDITIVE" and mask.vWrap == "CLAMPTOBLACKADDITIVE",
        "Opaque rectangle must clip outside the bar without the native atlas's internal gaps")
    assert(frame.BorderMask:GetAtlas() == "cast_standard_barmask"
        and frame.BorderMask:GetWidth() == 256 and frame.BorderMask:GetHeight() == 13,
        "Other native effects retain their original mask")
    for _, key in ipairs({ "Spark", "StandardGlow", "CraftGlow", "ChannelShadow" }) do
        assert(frame[key].masks[mask] and not frame[key].masks[frame.BorderMask],
            "A second shaped mask must not punch holes into the rectangular clip")
        assert(frame[key]:GetHeight() == frame:GetHeight(), "Spark and trail fill the bar height")
    end
end
CheckSparkBounds()
for _, channel in ipairs({ false, true, false }) do
    StartCast(channel, false)
    CheckSparkBounds()
    local key = channel and "ChannelShadow" or "StandardGlow"
    local trail = frame[key]
    local point, relative, relativePoint, x, y = trail:GetPoint(1)
    assert(point == (channel and "LEFT" or "RIGHT") and relative == frame.Spark
        and relativePoint == "CENTER" and x == 0 and y == 0,
        "Trail must meet the spark and follow the direction of travel")
    local ulX, ulY, llX, llY, urX, urY, lrX, lrY = trail:GetTexCoord()
    assert(ulX == (channel and .3 or .1) and urX == (channel and .1 or .3)
        and llX == ulX and lrX == urX and ulY == .2 and urY == .2 and llY == .4 and lrY == .4,
        "Channel mirroring preserves the native atlas cell")
    local previous = frame:GetValue()
    Advance(.1)
    assert((channel and frame:GetValue() < previous) or (not channel and frame:GetValue() > previous),
        "Native channels empty while ordinary casts fill")
    if usingNativeSource then
        local _, relative, edge, x = frame.Spark:GetPoint(1)
        assert(relative == frame and edge == "LEFT")
        Near(x, frame:GetValue() / frame.maxValue * frame:GetWidth())
    end
end
assert(castBar.Set("width", 182)) -- Screenshot: native 256px mask over a 182px cast bar.
CheckSparkBounds()
assert(castBar.Set("width", 600))
CheckSparkBounds()
assert(castBar.Set("width", 0))
assert(frame.Spark:GetHeight() == 22, "Compact spark must fit the cast bar height")
Near(frame.Spark:GetWidth() / frame.Spark:GetHeight(), 8 / 20)
assert(select(2, frame.CastTimeText:GetFont()) == 12)
for _, height in ipairs({ 6, 20, 48 }) do
    assert(castBar.Set("height", height))
    frame:ShowSpark()
    CheckSparkBounds()
    assert(frame.Spark:GetHeight() == height, "Spark must fit after resizing and native cast refresh")
    Near(frame.Spark:GetWidth() / frame.Spark:GetHeight(), 8 / 20)
end
assert(castBar.Set("height", 0))
assert(frame.Spark:GetHeight() == 22)
castBar.Reset()
assert(frame.Spark:GetWidth() == 8 and frame.Spark:GetHeight() == 20,
    "Automatic native layout restores original spark dimensions")
assert(frame.BorderMask:GetWidth() == 256 and frame.BorderMask:GetHeight() == 13)
for _, key in ipairs({ "Spark", "StandardGlow", "CraftGlow", "ChannelShadow" }) do
    assert(not frame[key].masks[frame.pyresinSparkMask], "Original style must remove custom clipping")
    if key ~= "Spark" then
        assert(frame[key].masks[frame.BorderMask])
        assert(select(3, frame[key]:GetPoint(1)) == "LEFT")
        assert(frame[key]:GetTexCoord() == .1)
    end
end
assert(frame.StandardGlow:GetHeight() == 12 and frame.CraftGlow:GetHeight() == 12
    and frame.ChannelShadow:GetHeight() == 11, "Reset restores original native FX sizes")
assert(castBar.Set("layout", "compact"))
local nameWidth = frame.Text:GetWidth()
frame.CastTimeText:Hide()
castBar.Apply()
assert(frame.Text:GetWidth() > nameWidth, "Hidden native cast time releases label space")
frame.CastTimeText:Show()
assert(castBar.Set("width", 320) and castBar.Set("height", 26))
assert(frame:GetWidth() == 320 and frame:GetHeight() == 26 and frame.Icon:GetWidth() == 26)
frame:SetLook("CLASSIC")
castBar.SetEnabled(false)
assert(frame:GetWidth() == 208 and frame.TextBorder:GetAlpha() == 1)
assert(frame.Spark:GetWidth() == 8 and frame.Spark:GetHeight() == 20,
    "Disabling restores both native spark dimensions")
assert(frame.BorderMask:GetWidth() == 256 and frame.BorderMask:GetHeight() == 13)
for _, key in ipairs({ "Spark", "StandardGlow", "CraftGlow", "ChannelShadow" }) do
    assert(not frame[key].masks[frame.pyresinSparkMask], "Original style must remove custom clipping")
    if key ~= "Spark" then
        assert(frame[key].masks[frame.BorderMask])
        assert(select(3, frame[key]:GetPoint(1)) == "LEFT")
        assert(frame[key]:GetTexCoord() == .1)
    end
end
assert(frame.StandardGlow:GetHeight() == 12 and frame.CraftGlow:GetHeight() == 12
    and frame.ChannelShadow:GetHeight() == 11, "Disable restores original native FX sizes")
assert(frame.Text:GetJustifyH() == "CENTER" and frame.CastTimeText:GetJustifyH() == "CENTER")
assert(frame.Text:CanWordWrap() == originalWordWrap and frame.Text:CanNonSpaceWrap() == originalNonSpaceWrap,
    "Disabling after a look change restores the original wrapping flags")
castBar.SetEnabled(true)
castBar.Reset()
frame:SetLook("UNITFRAME")
assert(castBar.Get("layout") == "native" and frame:GetWidth() == 150)

assert(castBar.Set("width", 280) and castBar.Set("icon", "off"))
assert(castBar.Set("timeFormat", "remainingTotal"))
-- A recreated addon environment reads DB values; neither native dimensions
-- nor Edit Mode layout settings are written to addon saved variables.
-- Integrated icons reserve width in the native StatusBar, not over its fill.
castBar.Reset()
-- GetPoint identifies the fill's anchor; the visible container must retain its
-- original rectangle when that fill gives space to an integrated icon.
for _, look in ipairs({ "UNITFRAME", "CLASSIC" }) do
    frame:SetLook(look)
    for _, width in ipairs({ 0, 240 }) do
        castBar.Set("width", width)
        local totalWidth, height = frame:GetSize()
        local nameSize, timeSize = select(2, frame.Text:GetFont()), select(2, frame.CastTimeText:GetFont())
        for _, point in ipairs({ "LEFT", "CENTER", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOM" }) do
            frame:ClearAllPoints()
            frame:SetPoint(point, UIParent, point, 120, -40)
            local scale = frame:GetScale()
            local factor = point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5
            local expectedLeft = 120 - totalWidth * factor
            for _, icon in ipairs({ "inside_left", "inside_right", "native", "left", "right", "off", "inside_left", "native" }) do
                castBar.Set("icon", icon)
                local current = castBar.GetLayout(nil, totalWidth, height)
                local x = select(4, frame:GetPoint(1))
                Near(x - frame:GetWidth() * factor - current.left, expectedLeft)
                Near(frame:GetWidth() + current.left + current.right, totalWidth)
                assert(frame:GetHeight() == height and frame:GetScale() == scale)
                assert(select(5, frame:GetPoint(1)) == -40)
                assert(select(2, frame.Text:GetFont()) == nameSize and select(2, frame.CastTimeText:GetFont()) == timeSize)
                assert(frame.CastTimeText.points[1][1] == "LEFT", "Icon styles cannot switch native text to Compact")
                local right = current.right + (icon == "right" and height + current.gap or 0)
                Near(select(4, frame.CastTimeText:GetPoint(1)), right + 10)
            end
            assert(select(4, frame:GetPoint(1)) == 120)
        end
        castBar.Reset()
    end
end
frame:SetLook("UNITFRAME")
frame:ClearAllPoints()
frame:SetPoint("CENTER", UIParent, "CENTER", 120, -40)
castBar.Set("icon", "inside_left")
Near(select(4, frame:GetPoint(1)), 125.5)
for _ = 1, 3 do
    EditModeManagerFrame:UpdateSystemAnchorInfo(frame)
    Near(EditModeManagerFrame.info.anchorInfo.offsetX / frame:GetScale(), 120)
    frame:ApplySystemAnchor()
    Near(select(4, frame:GetPoint(1)), 125.5)
end
-- Dragging, then a native re-anchor/reload, keeps the new logical position.
frame:SetPoint("CENTER", UIParent, "CENTER", 225.5, -60)
EditModeManagerFrame:UpdateSystemAnchorInfo(frame)
Near(EditModeManagerFrame.info.anchorInfo.offsetX / frame:GetScale(), 220)
frame:ApplySystemAnchor()
Near(select(4, frame:GetPoint(1)), 225.5)
castBar.Set("icon", "inside_right")
Near(select(4, frame:GetPoint(1)), 214.5)
castBar.Reset()
Near(select(4, frame:GetPoint(1)), 220)
frame:ApplySystemAnchor()
castBar.Set("icon", "inside_left")
Near(select(4, frame:GetPoint(1)), 225.5)
castBar.SetEnabled(false)
Near(select(4, frame:GetPoint(1)), 220)
castBar.SetEnabled(true)
Near(select(4, frame:GetPoint(1)), 225.5)
local scaleSetter, oldScale = frame.SetScale, frame:GetScale()
frame.SetScaleBase = function(self, value) self.scale = value end
frame.SetScale = function(self, value)
    -- Native EditModeSystemMixin:SetScaleOverride rescales saved point offsets.
    local scale = self:GetScale()
    local point, relative, relativePoint, x, y = self:GetPoint(1)
    self:SetPoint(point, relative, relativePoint, x * scale / value, y * scale / value)
    scaleSetter(self, value)
end
frame:SetScale(oldScale * 2)
Near(select(4, frame:GetPoint(1)), 115.5)
frame:SetScale(oldScale)
Near(select(4, frame:GetPoint(1)), 225.5)
frame.SetScale, frame.SetScaleBase = scaleSetter, nil
castBar.Reset()
assert(castBar.Set("layout", "compact"))
assert(castBar.Set("width", 240) and castBar.Set("height", 22))
assert(castBar.Set("showLatency", true))
local presentation = frame.pyresinCastPresentation
for _, icon in ipairs({ "native", "off", "left", "right", "inside_left", "inside_right" }) do
    assert(castBar.Set("icon", icon))
    StartCast(false, false)
    local inside = icon == "inside_left" or icon == "inside_right"
    assert(frame:GetWidth() == (inside and 217 or 240))
    assert(presentation.divider:IsShown() == inside)
    if inside then
        assert(frame:GetWidth() + frame.Icon:GetWidth() + 1 == 240)
        assert(not presentation.iconBounds:IsShown(), "An inner icon has one shared outer frame")
        assert(frame.Text.points[1][2] == frame and frame.CastTimeText.points[1][2] == frame)
        assert(not frame.Text:CanWordWrap() and not frame.Text:CanNonSpaceWrap())
        assert(frame.Text:GetWidth() + frame.CastTimeText:GetWidth() + 18 <= frame:GetWidth() + .001)
        assert(frame.pyresinSparkMask.allPoints == frame, "Spark clipping excludes the icon slot")
    end
    local _, _, _, left = frame.Selection:GetPoint(1)
    local _, _, _, right = frame.Selection:GetPoint(2)
    local expectedLeft = icon == "inside_left" and -23 or (icon == "left" or icon == "native") and -27 or 0
    local expectedRight = icon == "inside_right" and 23 or icon == "right" and 27 or 0
    assert(left == expectedLeft - 2 and right == expectedRight + 2, "Edit Mode must include the icon and border overhang")
    Near(latency:GetWidth(), frame:GetWidth() * .2 / 5)
    StartCast(true, false)
    Near(latency:GetWidth(), frame:GetWidth() * .2 / 5)
    assert(latency.points[1][1] == "TOPLEFT")
end
for _, width in ipairs({ 100, 600 }) do
    for _, height in ipairs({ 6, 48 }) do
        assert(castBar.Set("width", width) and castBar.Set("height", height))
        for _, icon in ipairs({ "native", "off", "left", "right", "inside_left", "inside_right" }) do
            castBar.Set("icon", icon)
            local inside = icon == "inside_left" or icon == "inside_right"
            assert(frame:GetWidth() > 0 and frame:GetWidth() + (inside and frame.Icon:GetWidth() + 1 or 0) == width)
        end
    end
end
assert(castBar.Set("iconGap", 12) and castBar.Set("icon", "left"))
assert(select(4, frame.Icon:GetPoint(1)) == -12)
assert(castBar.Set("icon", "inside_left"))
assert(select(4, frame.Icon:GetPoint(1)) == -1, "Outside spacing cannot move an integrated icon")
frame.testLocked = true
frame:AnchorSelectionFrame()
assert(select(4, frame.Selection:GetPoint(1)) == -51)
castBar.SetEnabled(false)
assert(select(4, frame.Selection:GetPoint(1)) == -20, "Disable restores the current native lock selection")
castBar.SetEnabled(true)
frame.testLocked = false
frame:AnchorSelectionFrame()
castBar.Reset()
assert(select(4, frame.Selection:GetPoint(1)) == 0 and select(5, frame.Selection:GetPoint(2)) == -12)
frame:AnchorSelectionFrame()
frame:SetScale(1)
assert(select(2, frame.Border:GetPoint(1)) == frame, "Default settings must not reactivate custom border anchors")

-- Border effects touch only decoration; states and the fill keep their native meaning.
assert(castBar.Set("layout", "compact") and castBar.Set("icon", "inside_right"))
assert(castBar.Set("borderStyle", "thin") and castBar.Set("borderSize", 3))
assert(castBar.Set("borderColorMode", "custom") and castBar.Set("borderColor", { r = .3, g = .6, b = .9 }))
assert(castBar.Set("borderOpacity", .4))
assert(frame.Border:GetAlpha() == 0)
for i, line in ipairs(presentation.border.lines) do
    assert(line:IsShown() == (i <= 4))
    if i <= 4 then assert(line.color[1] == .3 and line:GetAlpha() == .4) end
end
presentation.bounds.scale = 2
castBar.Apply()
Near(presentation.border.lines[1]:GetHeight(), 1.5)
presentation.bounds.scale = 1
PixelUtil = { GetPixelToUIUnitFactor = function() return .75 end }
frame:SetScale(2)
Near(select(4, frame.Selection:GetPoint(2)), 23 + 3 * .75 / 2)
PixelUtil = nil
frame:SetScale(1)
assert(castBar.Set("borderStyle", "inset"))
for _, line in ipairs(presentation.border.lines) do assert(line:IsShown()) end
assert(presentation.border.lines[1].color[1] < presentation.border.lines[8].color[1])
assert(castBar.Set("borderStyle", "native"))
assert(frame.Border:IsDesaturated() and frame.Border:GetVertexColor() == .3 and frame.Border:GetAlpha() == .4)
assert(castBar.Set("borderColorMode", "class"))
assert(frame.Border:GetVertexColor() == RAID_CLASS_COLORS.MAGE.r)
assert(castBar.Set("borderColorMode", "original"))
assert(not frame.Border:IsDesaturated() and frame.Border:GetVertexColor() == 1)
StartCast(false, true)
assert(castBar.Set("borderStyle", "none"))
assert(frame.Border:GetAlpha() == 0 and frame.BorderShield:GetAlpha() == 1)
assert(select(4, frame.BorderShield:GetPoint(1)) < 0, "Shield remains outside the icon and bar cluster")
for _, line in ipairs(presentation.border.lines) do assert(not line:IsShown()) end
FailCast(false)
assert(frame.Text:GetText() == INTERRUPTED)
castBar.Reset()
assert(frame:GetWidth() == 150 and frame.Icon:GetWidth() == 16)
assert(not presentation.bounds:IsShown() or castBar.Get("borderStyle") == "native")
assert(frame.Border:GetAlpha() == 1 and not frame.Border:IsDesaturated())
assert(castBar.SetEnabled(false))
assert(not presentation.bounds:IsShown() and not presentation.iconBounds:IsShown() and not presentation.divider:IsShown())
assert(select(4, frame.Border:GetPoint(1)) == -2 and select(5, frame.Border:GetPoint(1)) == 2)
assert(castBar.SetEnabled(true))

-- Migration is lazy after SavedVariables load and never replaces an explicit new style.
PyresinQoLDB.castBar = { showBorder = false, texture = "alchemy", icon = "right" }
assert(castBar.Get("borderStyle") == "none" and PyresinQoLDB.castBar.showBorder == nil)
assert(castBar.Get("texture") == "alchemy" and castBar.Get("icon") == "right")
PyresinQoLDB.castBar = { showBorder = true }
assert(castBar.Get("borderStyle") == "native" and PyresinQoLDB.castBar.showBorder == nil)
PyresinQoLDB.castBar = { showBorder = false, borderStyle = "inset" }
assert(castBar.Get("borderStyle") == "inset" and PyresinQoLDB.castBar.showBorder == nil)
for _, invalid in ipairs({ { "borderStyle", "unknown" }, { "borderOpacity", 1.1 }, { "borderOpacity", secret },
    { "borderSize", 0 }, { "borderSize", 4 }, { "borderSize", 1.5 }, { "iconGap", -1 }, { "iconGap", 13 },
    { "iconGap", 2.5 }, { "borderColor", { r = 2, g = 0, b = 0 } } }) do
    assert(not castBar.Set(invalid[1], invalid[2]))
end
-- Text choices share fill geometry with the preview; content never determines layout.
do
    castBar.Reset()
    castBar.Set("layout", "compact")
    castBar.Set("icon", "inside_left")
    castBar.Set("fontSize", 14)
    StartCast(false, false)
    local width, height, scale = frame:GetWidth(), frame:GetHeight(), frame:GetScale()
    local point = { frame:GetPoint(1) }
    local originalName, originalTime = { frame.Text:GetPoint(1) }, { frame.CastTimeText:GetPoint(1) }
    for _, setting in ipairs({ { "namePosition", "above" }, { "nameAlignment", "center" }, { "nameSpacing", 8 },
        { "timePosition", "below" }, { "timeAlignment", "left" }, { "timeSpacing", 4 } }) do
        assert(castBar.Set(unpack(setting)))
    end
    assert(frame:GetWidth() == width and frame:GetHeight() == height and frame:GetScale() == scale)
    for i, value in ipairs(point) do assert(select(i, frame:GetPoint(1)) == value) end
    local boxes = frame.pyresinCastPresentation.textBounds
    assert(boxes.name.y == height / 2 + 8 and boxes.time.y + boxes.time.height == -height / 2 - 4)
    assert(frame.Text:GetJustifyH() == "CENTER" and frame.CastTimeText:GetJustifyH() == "LEFT")
    assert(select(5, frame.Selection:GetPoint(1)) >= boxes.top)
    assert(-select(5, frame.Selection:GetPoint(2)) >= boxes.bottom)
    local preview = castBar.CreatePreview(Frame())
    castBar.UpdatePreview(preview, nil, 360)
    for _, pair in ipairs({ { frame.Text, preview.name }, { frame.CastTimeText, preview.time } }) do
        Near(pair[1]:GetWidth(), pair[2]:GetWidth())
        Near(select(4, pair[1]:GetPoint(1)), select(4, pair[2]:GetPoint(1)))
        Near(select(5, pair[1]:GetPoint(1)), select(5, pair[2]:GetPoint(1)))
    end
    local timeWidth, timeX = frame.CastTimeText:GetWidth(), select(4, frame.CastTimeText:GetPoint(1))
    Advance(.07)
    assert(frame.CastTimeText:GetWidth() == timeWidth and select(4, frame.CastTimeText:GetPoint(1)) == timeX)
    castBar.Set("showSpellName", false)
    FailCast(false)
    assert(frame.Text:GetAlpha() > 0 and frame.Text:GetText() == INTERRUPTED)
    for _, prefix in ipairs({ "name", "time" }) do
        castBar.Set(prefix .. "Position", "native")
        castBar.Set(prefix .. "Alignment", "native")
        castBar.Set(prefix .. "Spacing", -1)
    end
    assert(not castBar.HasTextOverrides())
    for i, value in ipairs(originalName) do assert(select(i, frame.Text:GetPoint(1)) == value) end
    for i, value in ipairs(originalTime) do assert(select(i, frame.CastTimeText:GetPoint(1)) == value) end
    castBar.Reset()

    -- Exercise extreme dimensions, opposite insets and every text lane/alignment.
    local fill, name, time = Frame(), Region(), Region()
    name.GetText = function() error("Text content is not a layout input") end
    time.GetText = name.GetText
    for _, dims in ipairs({ { 100, 48 }, { 600, 6 }, { 240, 22 } }) do
        for _, alignment in ipairs({ "left", "center", "right" }) do
            for _, position in ipairs({ "inside", "above", "below" }) do
                for _, timePosition in ipairs({ "inside", "above", "below", "left", "right" }) do
                    for _, spacing in ipairs({ -1, 0, 24 }) do
                        local options = { width = dims[1], height = dims[2], icon = "inside_right",
                            namePosition = position, timePosition = timePosition, nameAlignment = alignment,
                            timeAlignment = alignment, nameSpacing = spacing, timeSpacing = 24 - math.max(spacing, 0),
                            timeFormat = "remainingTotal" }
                        local function get(key) return options[key] ~= nil and options[key] or castBar.Get(key) end
                        local shape = castBar.GetLayout(get)
                        fill:SetSize(shape.fillWidth, shape.height)
                        name:SetFont("native.ttf", 24); time:SetFont("native.ttf", 24)
                        local b = castBar.LayoutText(name, time, fill, shape, get, true, true)
                        local n, t = b.name, b.time
                        assert(n.width >= 0 and t.width > 0)
                        if n.width > 0 then
                            assert(n.x >= 0 and n.x + n.width <= fill:GetWidth() + .001, "Name excludes integrated icon")
                            assert(n.x + n.width <= t.x or t.x + t.width <= n.x
                                or n.y + n.height <= t.y or t.y + t.height <= n.y, "Name cannot cover time")
                        end
                        if timePosition == "right" then assert(t.x >= fill:GetWidth() + shape.right)
                        elseif timePosition == "left" then assert(t.x + t.width <= -shape.left)
                        else assert(t.x >= 0 and t.x + t.width <= fill:GetWidth() + .001) end
                    end
                end
            end
        end
    end
    for _, invalid in ipairs({ { "namePosition", "left" }, { "timePosition", "middle" },
        { "nameAlignment", "top" }, { "timeAlignment", secret }, { "nameSpacing", -2 },
        { "timeSpacing", 25 }, { "nameSpacing", 2.5 }, { "timeSpacing", secret } }) do
        assert(not castBar.Set(unpack(invalid)))
    end
end

print("PASS: cast-bar layout")
