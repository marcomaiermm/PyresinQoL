local h = assert(loadfile("tests/support/castbar.lua"))(arg[1])
local castBar, frame = h.castBar, PlayerCastingBarFrame
local StartCast, Advance, FailCast = h.StartCast, h.Advance, h.FailCast
local state, secret, Frame, Region = h.state, h.secret, h.Frame, h.Region
local Near, usingNativeSource = h.Near, h.usingNativeSource
castBar.SetEnabled(true)
castBar.Set("colorMode", "custom")
castBar.Set("customColor", { r = .2, g = .3, b = .4 })
castBar.Set("showSpellName", false)
castBar.Set("showLatency", true)
local latency = frame.pyresinCastLatency
local available = castBar.GetTextures()
assert(available[1].id == "default" and castBar.GetTexture("alchemy").id == "alchemy")
assert(castBar.GetTexture("blacksmithing").id == "default", "Unavailable atlases must not be offered")
assert(castBar.Set("texture", "alchemy"))
StartCast(false, false)
local nativeFill = frame:GetStatusBarTexture()
local artwork = frame.pyresinCastTexture
local animation, flipbook = frame.pyresinCastAnimation, frame.pyresinCastFlipBook
assert(artwork:GetAtlas() == "Skillbar_Fill_Flipbook_Alchemy" and artwork.points[1][2] == frame)
assert(animation and animation:IsPlaying() and animation.texture == artwork and animation.looping == "REPEAT")
assert(flipbook.duration == 2 and flipbook.columns == 2 and flipbook.rows == 2 and flipbook.frames == 4,
    "Profession animation uses Blizzard's two-second cycle and atlas-derived row/frame counts")
assert(flipbook.frameWidth == 0 and flipbook.frameHeight == 0)
assert(#animation.animations == 1 and animation.animations[1].kind == "FlipBook",
    "Profession animation must use one forward pass without opacity modulation")
assert(artwork:GetBlendMode() == "BLEND" and artwork:GetAlpha() == 1)
castBar.Set("texture", "cooking")
assert(artwork:GetAtlas() == "Skillbar_Fill_Flipbook_Cooking" and flipbook.rows == 3 and flipbook.frames == 6,
    "Changing profession updates both the atlas and animation frame count")
castBar.Set("texture", "alchemy")
assert(flipbook.rows == 2 and flipbook.frames == 4 and artwork.animationGroups == 1)
do
    local alchemy = castBar.GetTexture("alchemy")
    local native = { alchemy.texture, alchemy.left, alchemy.right, alchemy.top, alchemy.bottom }
    -- Same runtime descriptor that real client atlas discovery produces below.
    alchemy.loopTexture = "Interface\\AddOns\\PyresinQoL\\Media\\CastBar\\Loop-4696956.blp"
    alchemy.loopFrames, alchemy.loopDuration = 51, 1.7
    castBar.Apply()
    assert(artwork:GetTexture() == alchemy.loopTexture and not artwork:GetAtlas())
    assert(flipbook.rows == 32 and flipbook.frames == 51 and flipbook.duration == 1.7)
    assert(animation.reverse == false and animation.offset == state.now % 1.7)
    assert(artwork:GetAlpha() == 1 and artwork:GetBlendMode() == "BLEND")
    frame:Hide(); frame.scripts.OnHide(frame)
    frame:Show(); frame.scripts.OnShow(frame)
    assert(animation:IsPlaying(), "Baked textures resume without a native atlas name")
    castBar.Set("animated", false)
    assert(not animation:IsPlaying() and not animation.duration and artwork:GetTexture() == native[1])
    castBar.Set("animated", true)
    assert(animation:IsPlaying() and artwork:GetTexture() == alchemy.loopTexture)
    for _, channel in ipairs({ false, true }) do
        StartCast(channel, false)
        assert(animation:IsPlaying() and artwork:GetTexture() == alchemy.loopTexture)
        if channel then
            frame:Hide(); frame.scripts.OnHide(frame)
            assert(not animation:IsPlaying(), "Hiding a channel stops the prepared loop")
            frame:Show(); frame.scripts.OnShow(frame)
        else
            FailCast(false)
            assert(not animation:IsPlaying() and artwork:GetTexture() == native[1])
        end
    end
    alchemy.loopTexture, alchemy.loopFrames, alchemy.loopDuration = nil, nil, nil
    StartCast(false, false)
    assert(artwork:GetAtlas() == alchemy.atlas and flipbook.frames == 4 and flipbook.duration == 2,
        "Unknown client artwork falls back to its native forward flipbook")
end

do
    local oldNow = state.now
    state.now = .837
    castBar.Apply()
    local phase = animation.offset
    assert(animation.reverse == false and phase == state.now % animation.duration)
    castBar.Set("width", 360)
    assert(animation.offset == phase, "Layout refreshes preserve animation phase")
    StartCast(false, false)
    assert(animation.offset == phase, "Consecutive casts preserve animation phase")
    castBar.Set("width", 0)
    state.now = oldNow
    castBar.Apply()
end
assert(nativeFill:GetAlpha() == 0 and artwork:IsShown())
assert(artwork:GetAlpha() == 1, "The visible animation phase must retain native fill opacity")
for _, mode in ipairs({ "original", "class", "custom" }) do
    assert(castBar.Set("colorMode", mode))
    for _ = 1, 3 do
        StartCast(false, false)
        castBar.Apply()
        assert(frame.pyresinCastAnimation == animation and animation:IsPlaying(), "Casts and settings reuse one animation")
        assert(artwork:IsShown() and artwork:GetAlpha() == 1 and nativeFill:GetAlpha() == 0,
            "Successive casts and refreshes must not copy hidden native alpha to selected art")
    end
    local r, g, b = artwork:GetVertexColor()
    local expected = mode == "original" and { r = 1, g = 1, b = 1 }
        or mode == "class" and RAID_CLASS_COLORS.MAGE or castBar.Get("customColor")
    assert(r == expected.r and g == expected.g and b == expected.b)
end
assert(castBar.SetEnabled(false))
assert(not animation:IsPlaying(), "Disable stops profession animation")
assert(artwork:GetBlendMode() == "BLEND", "Disable clears the animated blend mode")
assert(nativeFill:GetAlpha() == 1 and not artwork:IsShown(), "Disable restores visible native fill")
assert(castBar.SetEnabled(true))
assert(castBar.Set("texture", "default"))
assert(not animation:IsPlaying(), "Native texture cannot retain profession animation")
assert(nativeFill:GetAlpha() == 1 and not artwork:IsShown(), "Default texture restores visible native fill")
assert(castBar.Set("texture", "alchemy"))
assert(nativeFill:GetTexture() == CastingBarTypeInfo.standard.filling,
    "The native StatusBar keeps its own fill asset and geometry")
local function Cell()
    if animation:IsPlaying() then
        assert(artwork:GetAtlas() == "Skillbar_Fill_Flipbook_Alchemy", "FlipBook must target the full atlas, not an already cropped cell")
    else
        local left, top, _, bottom, right = artwork:GetTexCoord()
        Near(left, 0); Near(right, .5); Near(top, 0); Near(bottom, .5)
    end
    Near(artwork:GetWidth(), frame:GetHeight() * 441 / 18)
    Near(artwork:GetHeight(), frame:GetHeight())
    assert(artwork.points[1][1] == "LEFT" and artwork.points[1][2] == frame,
        "Artwork stays at the left edge throughout the cast")
    local mask = frame.pyresinCastTextureMask
    assert(mask and mask.allPoints == nativeFill and artwork.masks[mask], "Native fill clips stationary artwork")
end
for _, reverse in ipairs({ false, true }) do
    frame.reverseFill = reverse
    for _, fraction in ipairs({ 0, .01, .25, .251, .5, 1 }) do
        frame:SetValue(fraction * 5)
        Cell()
    end
end
nativeFill:SetTexCoord(0, .9, 0, 1)
Cell() -- Native UV updates cannot rescale or move the full texture.
assert(castBar.Set("width", 400) and castBar.Set("height", 32))
Cell()
assert(castBar.Set("width", 250) and castBar.Set("height", 20))
frame.reverseFill = false
do
    local descriptor = castBar.GetTexture("alchemy")
    descriptor.loopTexture = "Interface\\AddOns\\PyresinQoL\\Media\\CastBar\\Loop-4696956.blp"
    descriptor.loopFrames, descriptor.loopDuration = 51, 1.7
    local preview = castBar.CreatePreview(Frame())
    for _, dims in ipairs({ { 250, 20 }, { 100, 48 }, { 600, 6 } }) do
        castBar.Set("width", dims[1]); castBar.Set("height", dims[2])
        for _, icon in ipairs({ "off", "inside_left", "inside_right" }) do
            castBar.Set("icon", icon)
            for _, animated in ipairs({ false, true }) do
                castBar.Set("animated", animated)
                castBar.UpdatePreview(preview, nil, 400)
                local w, h = artwork:GetSize()
                Near(h, frame:GetHeight()) -- Bar width cannot zoom the texture vertically.
                Near(w, 441 * h / 18)
                assert(artwork.points[1][1] == "LEFT" and artwork.points[1][2] == frame)
                assert(artwork.masks[frame.pyresinCastTextureMask])
                assert(animation:IsPlaying() == animated)
                local left, top, _, bottom, right = preview.progress:GetTexCoord()
                local spanX = descriptor.right - descriptor.left
                Near(left, descriptor.left); Near(top, descriptor.top); Near(bottom, descriptor.bottom)
                Near(preview.progress:GetWidth(), math.min(frame:GetWidth() * .6, w))
                Near((right - left) / spanX, preview.progress:GetWidth() / w)
                assert(right <= descriptor.right, "Wide samples cannot bleed into another flipbook cell")
            end
        end
    end
    castBar.Set("texture", "elva_void")
    assert(artwork.allPoints == frame and #artwork.points == 0,
        "Model backgrounds restore full-bar stretching after profession cropping")
    descriptor.loopTexture, descriptor.loopFrames, descriptor.loopDuration = nil, nil, nil
    castBar.Set("texture", "alchemy")
    castBar.Set("width", 250); castBar.Set("height", 20); castBar.Set("icon", "native")
end
StartCast(true, false)
assert(animation:IsPlaying(), "Channeling also animates the selected profession")
Cell()
local animationStarts = animation.starts
Advance(.5)
assert(animation.starts == animationStarts, "Progress ticks must not restart the flipbook")
Cell()
frame:SetValue(secret)
Cell() -- Native clipping needs no restricted progress arithmetic.
frame:SetValue(1)
frame:Hide()
frame.scripts.OnHide(frame)
assert(not animation:IsPlaying(), "Hiding the native bar stops animation")
castBar.Apply() -- Native cast setup can paint before the frame becomes visible.
assert(not animation:IsPlaying())
frame:Show()
frame.scripts.OnShow(frame)
assert(animation:IsPlaying(), "Showing the next cast restarts the animation")
for _, failed in ipairs({ false, true }) do
    StartCast(false, false)
    FailCast(failed)
    assert(not animation:IsPlaying(), "Interrupted/failed casts keep a static red cell")
    assert(artwork:GetBlendMode() == "BLEND", "Static interruption shading uses ordinary alpha blending")
    assert(artwork:IsShown() and artwork:IsDesaturated() and artwork:GetTexture() == 4242,
        "Interrupted and failed casts keep the chosen texture")
    local low, high = artwork.gradient.low, artwork.gradient.high
    assert(high.r > low.r, "Interruption shading brightens toward the upper edge")
    for _, color in ipairs({ low, high }) do
        assert(color.r > color.g * 4 and color.r > color.b * 4, "Interruption red wins over the custom color")
    end
    local gloss = frame.pyresinCastInterruptGloss
    assert(gloss and gloss:IsShown() and gloss.layer == "ARTWORK" and gloss.sublevel == 1)
    assert(gloss.masks[frame.pyresinCastTextureMask], "Gloss follows the same native fill mask as the chosen texture")
    assert(gloss.gradient.low.a == 0 and gloss.gradient.high.a > 0 and gloss.gradient.high.a <= .3,
        "A restrained upper highlight fades out without a second pattern")
    for _, dims in ipairs({ { 100, 6 }, { 600, 48 } }) do
        castBar.Set("width", dims[1]); castBar.Set("height", dims[2])
        castBar.Set("icon", "inside_left")
        assert(gloss:GetHeight() <= 4 and gloss:GetHeight() <= frame:GetHeight() * .3)
        assert(gloss.points[1][2] == frame and gloss.points[2][2] == frame, "Gloss excludes the icon slot")
        assert(frame.pyresinCastInterruptGloss == gloss, "Settings reuse the existing highlight")
    end
    castBar.Set("width", 250); castBar.Set("height", 20); castBar.Set("icon", "native")
    frame:SetValue(5)
    Cell()
    assert(nativeFill:GetAlpha() == 0)
    assert(castBar.Set("customInterruptTexture", false))
    assert(not gloss:IsShown() and not artwork:IsShown() and nativeFill:GetAlpha() == 1)
    assert(nativeFill:GetTexture() == CastingBarTypeInfo.interrupted.full, "Toggle off uses Blizzard's interruption texture")
    StartCast(false, false)
    assert(artwork:IsShown(), "The interruption toggle does not disable the selected casting texture")
    FailCast(failed)
    assert(not artwork:IsShown() and nativeFill:GetTexture() == CastingBarTypeInfo.interrupted.full)
    assert(castBar.Set("customInterruptTexture", true) and gloss:IsShown())
    castBar.SetEnabled(false)
    assert(not gloss:IsShown() and not artwork:IsShown() and nativeFill:GetAlpha() == 1)
    castBar.SetEnabled(true)
    assert(gloss:IsShown())
    castBar.Set("texture", "default")
    assert(not gloss:IsShown() and nativeFill:GetTexture() == CastingBarTypeInfo.interrupted.full)
    castBar.Set("texture", "alchemy")
end
StartCast(false, false)
assert(not artwork:IsDesaturated(), "The next cast restores the texture's original colors")
assert(not frame.pyresinCastInterruptGloss:IsShown())
assert(not artwork.gradient, "The next cast removes interruption shading before applying the chosen uniform tint")
assert(artwork:GetVertexColor() == castBar.Get("customColor").r, "The next cast restores the selected tint")
StartCast(false, true)
assert(not animation:IsPlaying(), "Native uninterruptible art stops custom animation")
assert(not frame.pyresinCastInterruptGloss:IsShown() and not artwork:IsShown(), "Native shield art has no interruption gloss")
StartCast(false, false)
frame.maxValue = secret
castBar.Apply()
assert(not latency:IsShown(), "Restricted duration cannot size latency")
frame.maxValue = 5
state.networkMs = secret
castBar.Apply()
assert(not latency:IsShown(), "Restricted network timing cannot size latency")
state.networkMs = 200
frame:SetValue(1)
frame.barType = secret
castBar.Apply()
assert(not latency:IsShown(), "Restricted cast state must not enter branching or arithmetic")
assert(not frame.pyresinCastInterruptGloss:IsShown(), "Restricted state leaves no custom highlight behind")
if not usingNativeSource then
    -- A Lua stand-in can materialize a restricted native texture. Raw FrameXML
    -- cannot: in-game secret-returning texture APIs are provided by WoW itself.
    frame:UpdateBarFillTexture(false)
    assert(rawequal(frame:GetStatusBarTexture():GetTexture(), secret))
    assert(rawequal(frame:GetStatusBarColor(), secret))
    assert(castBar.SetEnabled(false))
    assert(rawequal(frame:GetStatusBarTexture():GetTexture(), secret)
        and rawequal(frame:GetStatusBarColor(), secret),
        "Disabling cannot restore an earlier cast's stale native fill over restricted art")
    assert(castBar.SetEnabled(true))
end
frame.barType = "channel"
frame:SetMinMaxValues(secret, 5)
castBar.Apply()
Cell()
frame:SetMinMaxValues(0, 5)
castBar.Reset()
assert(not animation:IsPlaying(), "Reset stops custom animation")

local atlasAPI = C_Texture
C_Texture = nil
local registry = { CastBar = { ModelTextures = castBar.ModelTextures }, L = { castBarNative = "Native" } }
assert(loadfile("Modules/CastBar/Textures.lua"))("PyresinQoL", registry)
assert(#registry.CastBar.GetTextures() == 11, "Custom presets do not depend on profession atlases")
C_Texture = atlasAPI
do
    for _, source in ipairs({ { 4696956, 30, 51 }, { 8176600, 30, 51 }, { 4693223, 37, 63 }, { 4693237, 22, 37 }, { 4696956, 31 }, { 4696956, 30, nil, 1700 }, { 999999, 30 } }) do
        C_Texture = { GetAtlasInfo = function(name)
            if name == "Skillbar_Fill_Flipbook_Alchemy" then
                return { file = source[1], width = source[4] or 1712, height = source[2] * 34,
                    leftTexCoord = 1 / 2048, rightTexCoord = 1713 / 2048,
                    topTexCoord = 1 / 2048, bottomTexCoord = (1 + source[2] * 34) / 2048 }
            end
        end }
        local found = { CastBar = { ModelTextures = {} }, L = { castBarNative = "Native" } }
        assert(loadfile("Modules/CastBar/Textures.lua"))("PyresinQoL", found)
        local descriptor = found.CastBar.GetTexture("alchemy")
        Near(descriptor.aspectRatio, 441 / 18)
        assert(descriptor.loopFrames == source[3])
        if source[3] then
            local path = "Media/CastBar/Loop-" .. source[1] .. ".blp"
            local asset = assert(io.open(path, "rb"), "Missing prepared loop: " .. path)
            assert(asset:read(4) == "BLP2"); asset:close()
            assert(descriptor.loopTexture == "Interface\\AddOns\\PyresinQoL\\" .. path:gsub("/", "\\"))
            Near(descriptor.loopDuration, 2 * source[3] / (source[2] * 2))
        else
            assert(not descriptor.loopTexture and not descriptor.loopDuration, "Unknown or changed artwork stays native")
        end
    end
    C_Texture = atlasAPI
end
print("PASS: cast-bar textures")
