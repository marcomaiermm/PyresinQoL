local h = assert(loadfile("tests/support/castbar.lua"))(arg[1])
local castBar, frame = h.castBar, PlayerCastingBarFrame
local StartCast, Advance, FailCast = h.StartCast, h.Advance, h.FailCast
local secret, Frame, Region = h.secret, h.Frame, h.Region
local Near, CheckModelViewport = h.Near, h.CheckModelViewport
castBar.SetEnabled(true)
castBar.Set("texture", "alchemy")
StartCast(false, false)
FailCast(false) -- Model styles must also clear the profession interruption highlight.
local animation = frame.pyresinCastAnimation
castBar.Reset()
-- Model styles are a visual layer over the same native fill, never another cast engine.
castBar.Set("texture", "elva_fel")
StartCast(false, false)
assert(frame.pyresinCastTexture.gradient and frame.pyresinCastTexture.gradient.high.g == 1
    and frame.pyresinCastTexture.gradient.low.g < frame.pyresinCastTexture.gradient.high.g,
    "Fel needs a dark-to-light base even without SharedMedia's Gradient texture")
local modelPreview = castBar.CreatePreview(Frame())
castBar.UpdatePreview(modelPreview, nil, 400)
Near(modelPreview.progress.gradient.low.g, frame.pyresinCastTexture.gradient.low.g)
Near(modelPreview.progress.gradient.high.g, frame.pyresinCastTexture.gradient.low.g
    + (frame.pyresinCastTexture.gradient.high.g - frame.pyresinCastTexture.gradient.low.g) * .6)
assert(castBar.GetTexture("alchemy").name == "Professions: Alchemy")
local names = { "Astral", "Celestial", "Ember", "Fel", "Flux", "Galaxy", "Nebula", "Sage", "Sunset", "Void" }
assert(#castBar.ModelTextures == #names)
for index, descriptor in ipairs(castBar.ModelTextures) do
    assert(descriptor.name == names[index], "Style labels use their standalone names")
    assert(castBar.Set("texture", descriptor.id))
    for _, channel in ipairs({ false, true }) do
        StartCast(channel, false)
        assert(not animation:IsPlaying(), "Model styles cannot retain profession flipbook animation")
        local colors = frame.pyresinCastTexture.gradient
        local shade = descriptor.media == "DGround" and 175 / 255 or 1
        assert(colors, "Every model preset retains its colors after live styling")
        if descriptor.media == "Gradient" then assert(colors.low.g < colors.high.g)
        else Near(colors.low.r, descriptor.color[1] * shade) end
        Near(colors.high.g, (descriptor.color2 or descriptor.color)[2] * shade)
        local background = frame.pyresinCastBackground
        assert(background and background:IsShown() and background.allPoints == frame
            and frame.Background:GetAlpha() == 0, "Model styles replace the native background inside the fill area")
        Near(background:GetAlpha(), descriptor.background[4])
        assert(background:GetTexture() == frame.pyresinCastTexture:GetTexture(),
            "Foreground and background use the same preset base texture")
        castBar.UpdatePreview(modelPreview, nil, 400)
        Near(modelPreview.background:GetAlpha(), background:GetAlpha())
        assert(modelPreview.background:GetTexture() == background:GetTexture())
        local effects = frame.pyresinCastModels
        assert(effects:IsShown() and effects.clipsChildren and effects.flattens)
        assert(effects.allPoints == frame and effects.progress.allPoints == frame:GetStatusBarTexture(),
            "Background clips to the full bar; foreground clips to native cast/channel progress")
        assert(frame.Text:GetParent() == effects.foreground and frame.CastTimeText:GetParent() == effects.foreground)
        assert(frame.Selection:GetFrameLevel() > effects.foreground:GetFrameLevel())
        assert(frame.pyresinSparkMask:GetParent() == frame.Spark:GetParent(), "Spark and clipping mask stay together")
        local count, modelLoads = 0, {}
        for _, model in pairs(effects.models) do
            if model.active then
                count = count + 1
                assert(model:IsShown() and effects.foreground:GetFrameLevel() > model:GetFrameLevel())
                assert(model.renderReady, "Model must initialize after its parent becomes visible, including reuse after hiding")
                CheckModelViewport(model, descriptor, frame, frame:GetStatusBarTexture())
                assert(model:GetParent() == (model.data.background and effects or effects.progress))
                modelLoads[model] = model.loads
            else assert(not model:IsShown()) end
        end
        assert(count == #descriptor.models)
        local original = frame:GetValue()
        Advance(.1)
        assert(channel and frame:GetValue() < original or not channel and frame:GetValue() > original)
        for model, loads in pairs(modelLoads) do
            CheckModelViewport(model, descriptor, frame, frame:GetStatusBarTexture())
            assert(model.loads == loads,
                "Cast and channel ticks must update the anchored viewport without reloading the model")
        end
        for _, width in ipairs({ 0, secret }) do
            effects.progress.scripts.OnSizeChanged(effects.progress, width, 22)
            for _, model in pairs(effects.models) do
                assert(model:IsShown() == (model.active and model.data.background or false),
                    "Background particles remain visible at zero fill, without leaking foreground particles")
            end
        end
        effects.progress.scripts.OnSizeChanged(effects.progress, 100, 22)
        for _, model in pairs(effects.models) do assert(model:IsShown() == model.active) end
    end
    for _, failed in ipairs({ false, true }) do
        StartCast(false, false)
        FailCast(failed)
        assert(not frame.pyresinCastModels:IsShown() and not frame.pyresinCastTexture:IsShown()
            and not frame.pyresinCastInterruptGloss:IsShown(),
            "Model styles always use native interruption art, even with custom interruption enabled")
        assert(not frame.pyresinCastBackground:IsShown() and frame.Background:GetAlpha() == .6,
            "Native interruption restores its background as well as its fill")
        assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.interrupted.full
            and frame:GetStatusBarTexture():GetAlpha() == 1)
    end
end
castBar.Set("texture", "elva_nebula")
StartCast(false, false)
-- Nebula 1.0.3 uses the legacy API: x=0, y=-1.25, z=.85, rotation=0.
-- Its stored rx=270 belongs to the inactive transform API and must be ignored.
local nebulaModel = frame.pyresinCastModels.models["2position"]
Near(nebulaModel.position[1], .85)
Near(nebulaModel.position[2], 0)
Near(nebulaModel.position[3], -1.25)
Near(nebulaModel.facing, 0)
assert(not nebulaModel.customCamera and not nebulaModel.transform)
local posePreview, poseSwatch = Frame(), Region()
castBar.ApplyModelPreview(posePreview, poseSwatch, castBar.GetTexture("elva_nebula"))
local previewModel = posePreview.pyresinCastModelPreview.models["2position"]
for i = 1, 3 do Near(previewModel.position[i], nebulaModel.position[i]) end
Near(previewModel.facing, nebulaModel.facing)
assert(not previewModel.customCamera and not previewModel.transform)
castBar.ApplyModelPreview(posePreview, poseSwatch, castBar.GetTexture("default"))
local nr, ng, nb = frame.pyresinCastBackground:GetVertexColor()
Near(nr, 0); Near(ng, .019608 * 175 / 255); Near(nb, .270588 * 175 / 255)
for _, opacity in ipairs({ 0, .4, 1, -1 }) do
    castBar.Set("backgroundOpacity", opacity)
    castBar.UpdatePreview(modelPreview, nil, 400)
    local expected = opacity < 0 and .709204 or opacity
    Near(frame.pyresinCastBackground:GetAlpha(), expected)
    Near(modelPreview.background:GetAlpha(), expected)
    assert(frame.Background:GetAlpha() == 0)
end
castBar.Set("texture", "elva_void")
StartCast(false, false)
local effects = frame.pyresinCastModels
local model = effects.models["1transform"]
Near(model.transform[1].x, .035)
Near(model.transform[2].x, math.rad(141))
Near(model.transform[3], -.055)
assert(model.modelAlpha == .9)
local loads = model.loads
castBar.Apply()
assert(model.loads == loads and model.renderReady, "An unchanged refresh retains the active model")
for _, setting in ipairs({ { "showLatency", true }, { "showSpellName", false }, { "width", 260 }, { "fontSize", 16 } }) do
    castBar.Set(unpack(setting))
    assert(model.loads == loads and model.renderReady, "Unrelated settings cannot reload the active model")
end
StartCast(false, false)
assert(model.loads == loads, "Consecutive visible casts retain the same model")
loads = model.loads
Advance(.1)
assert(model.loads == loads, "Progress ticks must not reload the model")
model:ClearTransform() -- A streamed model can reset the camera after SetModel returned.
model.scripts.OnModelLoaded(model)
Near(model.transform[3], -.055)
frame:Hide()
assert(not model.renderReady)
frame:Show()
assert(model.renderReady and model.loads > loads, "Showing a new cast restores the effect after the native parent was hidden")
local void = castBar.GetTexture("elva_void")
castBar.ApplyModels(frame, { models = { { file = -1, position = { 0, 0, 0 } } } })
assert(not effects.models["1position"]:IsShown() and frame.pyresinCastTexture:IsShown(),
    "Missing models leave a usable base fill")
castBar.Apply()
assert(model:IsShown())
frame.barType = secret
castBar.Apply()
assert(not effects:IsShown() and frame.Text:GetParent() == frame)
StartCast(false, true)
assert(not effects:IsShown(), "Native uninterruptible art keeps its state feedback")
StartCast(false, false)
FailCast(false)
assert(not effects:IsShown() and not frame.pyresinCastTexture:IsShown(), "Model styles restore native red interruption feedback")
castBar.Set("customInterruptTexture", false)
assert(not effects:IsShown() and not frame.pyresinCastTexture:IsShown())
assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.interrupted.full)
StartCast(false, false)
castBar.SetEnabled(false)
assert(not effects:IsShown() and frame.Text:GetParent() == frame and frame.Spark:GetParent() == frame)
assert(not frame.pyresinCastBackground:IsShown() and frame.Background:GetAlpha() == .6)
castBar.SetEnabled(true)
castBar.Set("texture", "alchemy")
assert(not effects:IsShown() and frame.Border:GetParent() == frame and frame.pyresinCastLatency:GetParent() == frame)
assert(not frame.pyresinCastBackground:IsShown() and frame.Background:GetAlpha() == .6)
castBar.UpdatePreview(modelPreview, nil, 400)
assert(modelPreview.background:GetAtlas() == "ui-castingbar-background" and modelPreview.background:GetVertexColor() == 1)
Near(modelPreview.background:GetAlpha(), .6)
local sample = Region()
local sunset = castBar.GetTexture("elva_sunset")
castBar.PaintTexture(sample, sunset, .6)
Near(sample.gradient.high.r, sunset.color[1] + (sunset.color2[1] - sunset.color[1]) * .6)
castBar.PaintTexture(sample, castBar.GetTexture("default"))
assert(not sample.gradient, "Switching back clears the preset gradient")
LibStub = function(_, silent)
    assert(silent)
    return { HashTable = function(_, kind) assert(kind == "statusbar"); return { DGround = "registered-dground" } end }
end
castBar.PaintTexture(sample, void)
assert(sample:GetTexture() == "registered-dground")
Near(sample.gradient.low.r, void.color[1])
local originalMedia = Region()
castBar.PaintBackground(originalMedia, castBar.GetTexture("elva_nebula"), -1)
assert(originalMedia:GetTexture() == "registered-dground")
Near(select(3, originalMedia:GetVertexColor()), .270588)
LibStub = nil
castBar.PaintTexture(sample, void)
assert(sample:GetTexture() == "Interface\\Buttons\\WHITE8X8")
Near(sample.gradient.low.r, void.color[1] * 175 / 255)
local fel = castBar.GetTexture("elva_fel")
for _, tint in ipairs({ false, { r = .2, g = .5, b = .9 } }) do
    castBar.PaintTexture(sample, fel, nil, tint)
    local full = sample.gradient
    assert(full.low.g < full.high.g, "Tinting must preserve Fel's missing-media shading")
    Near(full.high.g, tint and tint.g or fel.color[2])
    for _, fraction in ipairs({ 0, .25, .6, 1 }) do
        castBar.PaintTexture(sample, fel, fraction, tint)
        Near(sample.gradient.low.g, full.low.g)
        Near(sample.gradient.high.g, full.low.g + (full.high.g - full.low.g) * fraction)
    end
end
LibStub = function()
    return { HashTable = function() return { Gradient = "registered-gradient" } end }
end
castBar.PaintTexture(sample, fel)
assert(sample:GetTexture() == "registered-gradient", "Installed original media wins over the fallback")
castBar.PaintBackground(originalMedia, fel, -1)
assert(originalMedia:GetTexture() == "registered-gradient" and not originalMedia.gradient)
Near(select(2, originalMedia:GetVertexColor()), .168627)
Near(originalMedia:GetAlpha(), .75)
Near(sample.gradient.low.g, fel.color[2])
Near(sample.gradient.high.g, fel.color[2])
LibStub = nil
castBar.PaintTexture(sample, fel)
castBar.PaintTexture(sample, castBar.GetTexture("alchemy"))
assert(not sample.gradient, "Leaving Fel removes its fallback shading")
assert(sample:GetTexture() == 4242 and not sample.animationGroups, "Settings samples remain static")
print("PASS: cast-bar models")
