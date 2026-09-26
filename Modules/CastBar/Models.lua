local _, ns = ...
local cast = ns.CastBar

-- Visual parameters from the reference collection: https://wago.io/xeJOxehA8
-- Only colors and Blizzard model IDs/transforms; no WeakAuras code or cast logic.
local styles = {
    { name = "Astral", media = "DGround", color = { .478431, .152941, .866667 }, background = { 0, 0, 0, .700985 }, models = {
        { file = 165821, alpha = .8, stretch = true, position = { 2, 0, .25 } },
        { file = 130629, alpha = .4, background = true, position = { 0, 0, 0 }, facing = 56 },
    } },
    { name = "Celestial", color = { 0, .65098, .917647 }, color2 = { 0, 0, 0 }, background = { 0, 0, 0, .700985 }, models = {
        { file = 165829, stretch = true, position = { .2, .15, -.1 } },
    } },
    { name = "Ember", color = { 1, .184314, 0 }, color2 = { 1, .909804, 0 }, background = { 0, 0, 0, .700985 }, models = {
        { file = 166112, stretch = true, position = { 4, 0, 1.3 } },
    } },
    { name = "Fel", media = "Gradient", color = { .427451, 1, 0 }, background = { .031373, .168627, 0, .75 }, models = {
        { file = 130629, background = true, transform = { 78, -72, 113, 169, 0, 0, 5 } },
        { file = 130629, alpha = .8, position = { 0, 0, 0 } },
    } },
    { name = "Flux", color = { .407843, .223529, .72549 }, color2 = { .631373, .439216, 1 }, background = { 0, 0, 0, .71 }, models = {
        { file = 166784, stretch = true, transform = { 45, 50, 0, 141, 128, 72, 81 } },
        { file = 165693, position = { 0, 0, 0 }, facing = 38.1 },
    } },
    { name = "Galaxy", color = { .47451, .301961, .92549 }, color2 = { 0, 0, 0 }, background = { 0, 0, 0, .700985 }, models = {
        { file = 165829, stretch = true, position = { .2, .15, -.1 } },
    } },
    { name = "Nebula", media = "DGround", color = { .231373, .882353, 1 }, color2 = { 0, .505882, 1 }, background = { 0, .019608, .270588, .709204 }, models = {
        { file = 130629, background = true, transform = { 78, -72, 113, 169, 0, 0, 5 } },
        { file = 166594, stretch = true, position = { .85, 0, -1.25 } },
    } },
    { name = "Sage", color = { 0, .666667, .12549 }, background = { 0, 0, 0, .709204 }, models = {
        { file = 166694, stretch = true, position = { 2.4, 0, 0 } },
    } },
    { name = "Sunset", color = { .807843, .34902, .964706 }, color2 = { 1, .909804, 0 }, background = { 0, 0, 0, .7 }, models = {
        { file = 166594, stretch = true, position = { 2.55, 0, -.6 } },
    } },
    { name = "Void", media = "DGround", color = { .67451, .47451, 1 }, color2 = { .090196, .090196, .090196 }, background = { 0, 0, 0, .700985 }, models = {
        { file = 166784, alpha = .9, transform = { 35, 50, -288, 141, 128, 72, 55 } },
    } },
}
for _, style in ipairs(styles) do
    style.id = "elva_" .. style.name:lower() -- Keep saved selections compatible.
    style.category, style.supportsTint = "model", true
    style.media = style.media or "Solid"
    style.texture = "Interface\\Buttons\\WHITE8X8"
    style.left, style.right, style.top, style.bottom = 0, 1, 0, 1
end
cast.ModelTextures = styles

local foregroundKeys = {
    "Text", "CastTimeText", "Icon", "Border", "BorderShield", "Spark", "pyresinSparkMask",
    "StandardGlow", "CraftGlow", "ChannelShadow", "BorderMask", "Flash", "ChargeFlash",
    "EnergyGlow", "EnergyMask", "Flakes01", "Flakes02", "Flakes03", "BaseGlow",
    "WispGlow", "WispMask", "Sparkles01", "Sparkles02", "Shine", "CraftingMask",
}

function cast.ClearModels(frame)
    local effects = frame.pyresinCastModels
    if not effects then return end
    effects:Hide()
    for region, parent in pairs(effects.parents) do region:SetParent(parent) end
    table.wipe(effects.parents)
    if effects.selectionLevel then
        frame.Selection:SetFrameLevel(effects.selectionLevel)
        effects.selectionLevel = nil
    end
end

local function updateModelVisibility(self, width, height)
    local visible = not (issecretvalue and (issecretvalue(width) or issecretvalue(height)))
        and width >= 1 and height >= 1
    for _, model in pairs(self.models) do
        if model:GetParent() == self then model:SetShown(visible and model.active) end
    end
end

local function positionModel(model)
    local data = model.data
    if not data or not model:IsVisible() then return end
    model:ClearTransform()
    if data.transform then
        local t = data.transform
        model:MakeCurrentCameraCustom()
        model:SetTransform(CreateVector3D(t[1] / 1000, t[2] / 1000, t[3] / 1000),
            CreateVector3D(math.rad(t[4]), math.rad(t[5]), math.rad(t[6])), -t[7] / 1000)
    else
        model:SetPosition(unpack(data.position))
        model:SetFacing(math.rad(data.facing or 0))
    end
    model:SetModelAlpha(data.alpha or 1)
end

local function showModel(model)
    if not model.data then return end
    -- Spell models need initialization while actually visible, also after reuse.
    -- Keeping a file ID across Hide/Show does not preserve their rendered state.
    if not pcall(model.SetModel, model, model.data.file) then
        model.active = false
        model:Hide()
        return
    end
    positionModel(model)
end

local function createEffects(parent)
    local effects = CreateFrame("Frame", nil, parent)
    effects.models = {}
    effects.progress = CreateFrame("Frame", nil, effects)
    effects.progress.models = effects.models
    -- Zero-sized clipping rectangles can leak model particles outside the bar.
    for _, clip in ipairs({ effects, effects.progress }) do
        clip:SetFlattensRenderLayers(true)
        clip:SetClipsChildren(true)
        clip:SetScript("OnSizeChanged", updateModelVisibility)
    end
    return effects
end

local function applyModels(effects, descriptor, fullRegion, fillRegion, alpha)
    effects:SetAllPoints(fullRegion)
    effects.progress:SetAllPoints(fillRegion)
    effects:SetFrameLevel(effects:GetParent():GetFrameLevel() + 1)
    effects.progress:SetFrameLevel(effects:GetFrameLevel())
    for _, model in pairs(effects.models) do model.active = false end
    for index, data in ipairs(descriptor.models) do
        -- Old and custom-camera models must not share camera state.
        local key = index .. (data.transform and "transform" or "position")
        local model = effects.models[key]
        local clip = data.background and effects or effects.progress
        if not model then
            model = CreateFrame("PlayerModel", nil, clip)
            model:Hide()
            model:SetKeepModelOnHide(true)
            model:SetScript("OnShow", showModel)
            model:SetScript("OnModelLoaded", positionModel)
            effects.models[key] = model
        end
        if model.data ~= data then model:Hide() end
        if model:GetParent() ~= clip then model:SetParent(clip) end
        model.data, model.active = data, true
        model:ClearAllPoints()
        -- Match WeakAuras: stretch-enabled layers use the current fill viewport.
        model:SetAllPoints(data.stretch and fillRegion or fullRegion)
        model:SetFrameLevel(effects:GetFrameLevel() + index)
    end
    effects:SetAlpha(alpha)
    updateModelVisibility(effects, effects:GetSize())
    updateModelVisibility(effects.progress, effects.progress:GetSize())
    effects:Show()
end

function cast.ApplyModels(frame, descriptor)
    if not descriptor or not descriptor.models then cast.ClearModels(frame); return end
    local effects = frame.pyresinCastModels
    if not effects then
        effects = createEffects(frame)
        effects.parents = {}
        effects.foreground = CreateFrame("Frame", nil, frame)
        effects.foreground:SetAllPoints(frame)
        frame.pyresinCastModels = effects
    end
    effects.foreground:SetFrameLevel(frame:GetFrameLevel() + 4)
    if frame.Selection then
        effects.selectionLevel = effects.selectionLevel or frame.Selection:GetFrameLevel()
        frame.Selection:SetFrameLevel(effects.foreground:GetFrameLevel() + 1)
    end
    for _, key in ipairs(foregroundKeys) do
        local region = frame[key]
        if region and not effects.parents[region] then
            effects.parents[region] = region:GetParent()
            region:SetParent(effects.foreground)
        end
    end
    if frame.pyresinCastLatency and not effects.parents[frame.pyresinCastLatency] then
        effects.parents[frame.pyresinCastLatency] = frame.pyresinCastLatency:GetParent()
        frame.pyresinCastLatency:SetParent(effects.foreground)
    end
    applyModels(effects, descriptor, frame, frame:GetStatusBarTexture(), frame.pyresinCastFillAlpha)
end

function cast.ApplyModelPreview(parent, texture, descriptor)
    local effects = parent.pyresinCastModelPreview
    if not descriptor.models then
        if effects then effects:Hide() end
        return
    end
    if not effects then
        effects = createEffects(parent)
        parent.pyresinCastModelPreview = effects
    end
    applyModels(effects, descriptor, texture, texture, 1)
end
