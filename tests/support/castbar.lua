-- Shared game API doubles; each scenario starts in a fresh Lua process.
local nativeSource = ...
local state = { now = 1, networkMs = 200, playerClass = "MAGE" }
local modelFrames, refreshModelVisibility = {}
local secret = setmetatable({}, { __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end,
    __div = function() error("secret arithmetic") end,
    __sub = function() error("secret arithmetic") end,
    __tostring = function() error("secret formatting") end })
function issecretvalue(value) return rawequal(value, secret) end
function GetTime() return state.now end
function UnitCastingInfo() if state.worldCast then return unpack(state.worldCast) end end
function UnitChannelInfo() if state.worldChannel then return unpack(state.worldChannel) end end
function GetNetStats() return 0, 0, 40, state.networkMs end
function UnitClass() return "Mage", state.playerClass end
RAID_CLASS_COLORS = { MAGE = { r = .2, g = .5, b = .9 } }
UIParent = { GetHeight = function() return 900 end }
Enum = { Profession = { Alchemy = 1, Blacksmithing = 2, Cooking = 3 } }
local function NativeAtlas(name)
    if name == "Skillbar_Fill_Flipbook_Alchemy" then
        return { file = 4242, width = 68, height = 68,
            leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
    elseif name == "Skillbar_Fill_Flipbook_Cooking" then
        return { file = 4243, width = 136, height = 102,
            leftTexCoord = .1, rightTexCoord = .9, topTexCoord = .2, bottomTexCoord = .8 }
    end
end
C_Texture = { GetAtlasInfo = NativeAtlas }
function GetCVar() return "0" end
function UnitShouldDisplaySpellTargetName() return false end
C_Secrets = { ShouldUnitSpellCastingBeSecret = function() return false end }
C_Spell = { IsSpellImportant = function() return false end }
GameRulesUtil = { ShouldShowPlayerCastBar = function() return true end }
InputUtil = { IsGamepadUIEnabled = function() return false end }
CAST_BAR_CAST_TIME, CASTBAR_CLASSIC_YELLOW, CASTBAR_CLASSIC_GREEN = "%.1f", {}, {}
CASTBAR_CLASSIC_RED, CASTBAR_CLASSIC_GRAY = {}, {}
for _, color in ipairs({ CASTBAR_CLASSIC_YELLOW, CASTBAR_CLASSIC_GREEN, CASTBAR_CLASSIC_RED, CASTBAR_CLASSIC_GRAY }) do
    function color:GetRGB() return 1, 1, 1 end
end
FAILED, INTERRUPTED = "Failed", "Interrupted"
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
function CreateVector3D(x, y, z) return { x = x, y = y, z = z } end
table.wipe = function(value) for key in pairs(value) do value[key] = nil end end
local function Region()
    local region = { shown = true, alpha = 1, points = {}, width = 0, height = 0,
        color = { 1, 1, 1, 1 }, font = "native.ttf", fontSize = 12, fontFlags = "OUTLINE" }
    function region:Show() self.shown = true; if refreshModelVisibility then refreshModelVisibility() end end
    function region:Hide() self.shown = false; if refreshModelVisibility then refreshModelVisibility() end end
    function region:SetShown(value) if value then self:Show() else self:Hide() end end
    function region:IsShown() return self.shown end
    function region:IsVisible()
        return self.shown and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible())
    end
    function region:SetAlpha(value) self.alpha = value end
    function region:GetAlpha() return self.alpha end
    function region:GetParent() return self.parent end
    function region:SetParent(parent) self.parent = parent end
    function region:GetFrameLevel() return self.level or 1 end
    function region:SetFrameLevel(level) self.level = level end
    function region:SetClipsChildren(value) self.clipsChildren = value end
    function region:SetFlattensRenderLayers(value) self.flattens = value end
    function region:SetText(value) self.text = value end
    function region:GetText() return self.text end
    function region:GetFontString() self.fontString = self.fontString or Region(); return self.fontString end
    function region:SetFontString(value) self.fontString = value end
    function region:SetHighlightTexture(value) self.highlightTexture = value end
    function region:SetTextColor(...) self.textColor = { ... } end
    function region:SetButtonState(value) self.buttonState = value end
    function region:LockHighlight() self.highlightLocked = true end
    function region:UnlockHighlight() self.highlightLocked = false end
    function region:SetJustifyH(value) self.justify = value end
    function region:GetJustifyH() return self.justify or "CENTER" end
    function region:SetEnabled(value) self.enabled = value end
    function region:SetVerticalScroll(value) self.scroll = value end
    function region:GetVerticalScroll() return self.scroll or 0 end
    function region:SetWordWrap(value) self.wordWrap = value end
    function region:CanWordWrap() return self.wordWrap ~= false end
    function region:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
    function region:CanNonSpaceWrap() return self.nonSpaceWrap ~= false end
    function region:IsDesaturated() return self.desaturated or false end
    function region:SetDesaturated(value) self.desaturated = value end
    function region:GetEffectiveScale() return self.scale or 1 end
    function region:SetAtlas(value) self.atlas, self.texture, self.texCoords = value, nil, nil end
    function region:GetAtlas() return self.atlas end
    function region:SetTexture(value, hWrap, vWrap)
        self.texture, self.atlas, self.hWrap, self.vWrap = value, nil, hWrap, vWrap
    end
    function region:AddMaskTexture(mask)
        self.masks = self.masks or {}
        assert(not self.masks[mask], "Duplicate mask attachment")
        self.masks[mask] = true
    end
    function region:RemoveMaskTexture(mask)
        assert(self.masks and self.masks[mask], "Removing a mask that was not attached")
        self.masks[mask] = nil
    end
    function region:GetNumMaskTextures()
        local count = 0
        for _ in pairs(self.masks or {}) do count = count + 1 end
        return count
    end
    function region:GetMaskTexture(index)
        for mask in pairs(self.masks or {}) do
            index = index - 1
            if index == 0 then return mask end
        end
    end
    function region:GetTexture() return self.texture end
    function region:SetColorTexture(...) self.color = { ... } end
    function region:SetGradient(orientation, low, high)
        assert(orientation == "VERTICAL" or orientation == "HORIZONTAL")
        self.gradient = { low = low, high = high }
    end
    function region:SetColorRGB(...) self.color = { ... } end
    function region:SetVertexColor(r, g, b, a)
        self.vertexColor = { r, g, b }
        -- Uniform vertex colors replace the per-corner colors of SetGradient.
        self.gradient = nil
        if a ~= nil then self:SetAlpha(a) end
    end
    function region:GetVertexColor()
        local color = self.vertexColor or { 1, 1, 1 }
        return color[1], color[2], color[3], self:GetAlpha()
    end
    function region:SetChecked(value) self.checked = value end
    function region:GetChecked() return self.checked end
    function region:SetScrollChild(child) self.scrollChild = child end
    function region:SetupMenu(generator) self.menuGenerator = generator end
    function region:GenerateMenu()
        self.options = {}
        local root = {}
        function root:SetScrollMode(height) region.menuHeight = height end
        function root:CreateRadio(name, selected, select, value)
            local option = { name = name, selected = selected, select = select, value = value }
            region.options[#region.options + 1] = option
            function option:AddInitializer(callback) self.initializer = callback end
            function option:AddResetter(callback) self.resetter = callback end
            return option
        end
        self.menuGenerator(self, root)
    end
    function region:IsDraggingThumb() return self.dragging or false end
    function region:Init(value, ...)
        self.initCount = (self.initCount or 0) + 1
        self.sliderValue = value
        for _, callback in pairs(self.callbacks or {}) do callback(value) end
    end
    function region:SetTexCoord(...) self.texCoords = { ... } end
    function region:GetTexCoord()
        local c = self.texCoords or { 0, 1, 0, 1 }
        if #c == 8 then return unpack(c) end
        return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
    end
    function region:SetBlendMode(value) self.blend = value end
    function region:GetBlendMode() return self.blend or "BLEND" end
    function region:SetAllPoints(target) self.allPoints = target end
    function region:ClearAllPoints() self.points = {}; self.allPoints = nil end
    function region:SetPoint(...)
        local point = { ... }
        for i, old in ipairs(self.points) do
            if old[1] == point[1] then self.points[i] = point; return end
        end
        self.points[#self.points + 1] = point
    end
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(index) return unpack(self.points[index or 1] or { "CENTER", nil, "CENTER", 0, 0 }) end
    function region:SetWidth(value) self.width = value end
    function region:GetWidth() return self.width end
    function region:SetHeight(value) self.height = value end
    function region:GetHeight() return self.height end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:GetSize() return self.width, self.height end
    function region:GetFont() return self.font, self.fontSize, self.fontFlags end
    function region:SetFont(font, size, flags) self.font, self.fontSize, self.fontFlags = font, size, flags end
    function region:SetFontObject(value) self.fontObject = value; self.fontSize = 12 end
    function region:GetFontObject() return self.fontObject end
    function region:CreateTexture(_, layer, _, sublevel)
        local child = Region()
        child.parent = self
        child.layer, child.sublevel = layer, sublevel
        self.children[#self.children + 1] = child
        return child
    end
    function region:CreateMaskTexture() return self:CreateTexture() end
    function region:CreateFontString() local child = Region(); self.children[#self.children + 1] = child; return child end
    function region:CreateAnimationGroup()
        self.animationGroups = (self.animationGroups or 0) + 1
        local group = { texture = self, starts = 0, animations = {} }
        function group:SetLooping(value) self.looping = value end
        function group:Play(reverse, offset)
            self.playing, self.starts = self.texture:IsVisible(), self.starts + 1
            self.reverse, self.offset, self.startedAt = reverse, offset or 0, state.now
        end
        function group:Stop() self.playing = false end
        function group:IsPlaying() return self.playing end
        function group:CreateAnimation(kind)
            assert(kind == "FlipBook" or kind == "Alpha")
            local flipbook = { kind = kind }
            function flipbook:SetDuration(value) self.duration = value end
            function flipbook:SetOrder(value) self.order = value end
            function flipbook:SetStartDelay(value) self.delay = value end
            function flipbook:SetSmoothing(value) self.smoothing = value end
            function flipbook:SetFromAlpha(value) self.fromAlpha = value end
            function flipbook:SetToAlpha(value) self.toAlpha = value end
            function flipbook:SetFlipBookColumns(value) self.columns = value end
            function flipbook:SetFlipBookRows(value) self.rows = value end
            function flipbook:SetFlipBookFrames(value) self.frames = value end
            function flipbook:SetFlipBookFrameWidth(value) self.frameWidth = value end
            function flipbook:SetFlipBookFrameHeight(value) self.frameHeight = value end
            self.animations[#self.animations + 1] = flipbook
            if kind == "FlipBook" then self.flipbook = flipbook end
            return flipbook
        end
        return group
    end
    region.children = {}
    return region
end
local function Anim()
    return { Play = function(self) self.playing = true end, Stop = function(self) self.playing = false end,
        IsPlaying = function(self) return self.playing end }
end
local function Frame()
    local frame = Region()
    frame.width, frame.height, frame.scale = 150, 10, 0.85
    frame.Text, frame.CastTimeText, frame.Icon = Region(), Region(), Region()
    frame.CastTimeText:SetPoint("LEFT", frame, "RIGHT", 10, 0)
    frame.CastTimeText.fontSize = 18
    frame.Icon:SetSize(16, 16)
    frame.Text:SetAlpha(.8)
    frame.Icon:SetPoint("CENTER", frame, "LEFT", -5, 0)
    frame.Border, frame.BarBorder, frame.BorderShield = Region(), Region(), Region()
    frame.Border:SetAtlas("ui-castingbar-frame")
    frame.Border:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    frame.Border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    frame.BorderShield:SetAtlas("ui-castingbar-shield")
    frame.BorderShield:SetSize(29, 33)
    frame.BorderShield:SetPoint("TOPLEFT", frame, "TOPLEFT", -27, 4)
    frame.Selection = Region()
    frame.Selection:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.Selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -12)
    frame.editModeSelectionBottomOffset = -12
    frame.lockedToPlayerFrame, frame.testLocked = false, false
    function frame:UpdateClampOffsets() self.clampUpdates = (self.clampUpdates or 0) + 1 end
    function frame:AnchorSelectionFrame()
        if self.lockedToPlayerFrame ~= self.testLocked then
            self.lockedToPlayerFrame = self.testLocked
            self.Selection:ClearAllPoints()
            self.Selection:SetPoint("TOPLEFT", self, "TOPLEFT", self.testLocked and -20 or 0, 0)
            self.Selection:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, -12)
        end
        self:UpdateClampOffsets()
    end
    frame.TextBorder, frame.DropShadow, frame.Spark, frame.Flash = Region(), Region(), Region(), Region()
    frame.StandardGlow, frame.CraftGlow, frame.ChannelShadow, frame.BorderMask = Region(), Region(), Region(), Region()
    frame.StandardGlow:SetSize(37, 12)
    frame.CraftGlow:SetSize(37, 12)
    frame.ChannelShadow:SetSize(11, 11)
    frame.BorderMask:SetSize(256, 13)
    frame.BorderMask:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.BorderMask:SetAtlas("cast_standard_barmask")
    for _, key in ipairs({ "StandardGlow", "CraftGlow", "ChannelShadow" }) do
        frame[key]:AddMaskTexture(frame.BorderMask)
        frame[key]:SetPoint("RIGHT", frame.Spark, "LEFT", key == "ChannelShadow" and 1 or 2, 0)
        frame[key]:SetTexCoord(.1, .3, .2, .4) -- Atlas is a subregion, not the whole file.
    end
    frame.CraftGlow:Hide()
    frame.Background, frame.BorderTexture = Region(), Region()
    frame.Background:SetAlpha(.6)
    frame.Spark:SetPoint("CENTER", frame, "LEFT", 0, 0)
    frame.Spark:SetSize(8, 20)
    frame.FadeOutAnim, frame.FlashAnim, frame.HoldFadeOutAnim = Anim(), Anim(), Anim()
    frame.FlashLoopingAnim, frame.InterruptSparkAnim = Anim(), Anim()
    frame.events = {}
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript(script, callback)
        local previous = self.scripts[script]
        self.scripts[script] = function(self, ...)
            if previous then previous(self, ...) end
            callback(self, ...)
        end
    end
    frame.scripts = {}
    function frame:GetStatusBarTexture() return self.statusTexture end
    function frame:SetStatusBarTexture(value) self.statusTexture = self.statusTexture or Region();
        self.statusTexture.parent = self
        self.statusTexture:SetTexture(value) end
    function frame:SetStatusBarColor(...) self.statusTexture:SetVertexColor(...) end
    function frame:GetStatusBarColor() return self.statusTexture:GetVertexColor() end
    function frame:SetMinMaxValues(min, max) self.minimum, self.maximum = min, max end
    function frame:GetMinMaxValues() return self.minimum, self.maximum end
    function frame:SetValue(value)
        self.currentValue = value
        if self.statusTexture then self.statusTexture:SetTexCoord(0, 1, 0, 1) end
    end
    function frame:GetValue() return self.currentValue end
    function frame:SetScale(value) self.scale = value end
    function frame:GetScale() return self.scale end
    function frame:ApplySystemAnchor()
        local anchor = EditModeManagerFrame:GetActiveLayoutSystemInfo().anchorInfo
        self:ClearAllPoints()
        self:SetPoint(anchor.point, UIParent, anchor.relativePoint, anchor.offsetX / self:GetScale(), anchor.offsetY / self:GetScale())
        self:SetScale(self:GetScale()) -- Cast-bar ApplySystemAnchor also reapplies Bar Size.
    end
    function frame:GetReverseFill() return self.reverseFill or false end
    function frame:GetOrientation() return self.orientation or "HORIZONTAL" end
    for _, region in pairs(frame) do
        if type(region) == "table" and region.SetParent then region:SetParent(frame) end
    end
    return frame
end
local eventFrames = {}
refreshModelVisibility = function()
    for _, model in ipairs(modelFrames) do
        local visible = model:IsVisible()
        if visible ~= model.visible then
            model.visible = visible
            if not visible then model.renderReady = false end
            local script = model.scripts[visible and "OnShow" or "OnHide"]
            if script then script(model) end
        end
    end
end
function CreateFrame(kind, name, parent, template)
    local frame = Frame()
    frame.kind, frame.parent, frame.template = kind, parent, template
    if kind == "PlayerModel" then
        modelFrames[#modelFrames + 1] = frame
        function frame:SetKeepModelOnHide(value) self.keepModel = value end
        function frame:SetModel(file)
            if file == -1 then error("Missing model") end
            self.modelFile, self.loads = file, (self.loads or 0) + 1
            self.renderReady = self:IsVisible()
        end
        function frame:ClearTransform() self.transform = nil; self.position = nil end
        function frame:MakeCurrentCameraCustom() self.customCamera = true end
        function frame:SetTransform(translation, rotation, scale) self.transform = { translation, rotation, scale } end
        function frame:SetPosition(...) self.position = { ... } end
        function frame:SetFacing(value) self.facing = value end
        function frame:SetModelAlpha(value) self.modelAlpha = value end
    end
    if template and template:find("^EditModeSetting") then
        frame:Hide() -- Native setting templates are hidden until explicitly shown.
        frame.Label = Region()
        if template:find("Checkbox") then frame.Button = Region() end
        if template:find("Dropdown") then frame.Dropdown = Region() end
    end
    if template == "MinimalSliderWithSteppersTemplate" then
        frame.Slider = Region()
        frame.callbacks = {}
        function frame:SetValue(value)
            self.sliderValue = value
            for _, callback in pairs(self.callbacks) do callback(value) end
        end
    end
    eventFrames[#eventFrames + 1] = frame
    return frame
end
function hooksecurefunc(owner, method, callback)
    local original = assert(owner[method], method)
    owner[method] = function(self, ...)
        local results = { original(self, ...) }
        callback(self, ...)
        return unpack(results)
    end
end
local usingNativeSource = nativeSource ~= nil
if usingNativeSource then
    assert(loadfile(nativeSource))()
else
    CastingBarType = { Standard = "standard", Channel = "channel", Uninterruptable = "uninterruptable",
        Interrupted = "interrupted", Empowered = "empowered" }
    CastingBarTypeInfo = {
        standard = { filling = "ui-castingbar-filling-standard", full = "ui-castingbar-full-standard" },
        channel = { filling = "ui-castingbar-filling-channel", full = "ui-castingbar-full-channel" },
        uninterruptable = { filling = "ui-castingbar-uninterruptable", full = "ui-castingbar-uninterruptable" },
        interrupted = { filling = "ui-castingbar-interrupted", full = "ui-castingbar-interrupted" },
    }
    CastingBarMixin = {}
    function CastingBarMixin:UpdateBarFillTexture(full)
        if issecretvalue(self.barType) then
            self:SetStatusBarTexture(secret)
            self:SetStatusBarColor(secret, 1, 1)
            return
        end
        self:SetStatusBarTexture(CastingBarTypeInfo[self.barType or "standard"][full and "full" or "filling"])
        self:SetStatusBarColor(1, 1, 1)
    end
    function CastingBarMixin:SetLook(look)
        self.look = look
        self:SetSize(look == "UNITFRAME" and 150 or 208, look == "UNITFRAME" and 10 or 11)
        self.Text:SetFontObject(look == "UNITFRAME" and "SystemFont_Shadow_Small" or "GameFontHighlightSmall")
        self.Text:ClearAllPoints()
        self.Text:SetSize(look == "UNITFRAME" and 0 or 185, 16)
        if look == "UNITFRAME" then
            self.Text:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 3)
            self.Text:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 3)
        else
            self.Text:SetPoint("TOP", self, "TOP", 0, -10)
        end
        self.Text:Show(); self:UpdateIconShown()
    end
    function CastingBarMixin:UpdateIconShown()
        self.Icon:SetShown(self.showIcon and self.look == "UNITFRAME")
        self.BarBorder:Show()
    end
    function CastingBarMixin:ShowSpark() self.Spark:Show() end
    function CastingBarMixin:UpdateCastTimeText()
        self.CastTimeText:SetText((CAST_BAR_CAST_TIME):format(self.casting and (self.maximum - self.currentValue) or self.currentValue))
    end
end
PlayerCastingBarFrame = Frame()
setmetatable(PlayerCastingBarFrame, { __index = CastingBarMixin })
PlayerCastingBarFrame.unit, PlayerCastingBarFrame.showIcon = "player", true
PlayerCastingBarFrame.showCastTimeSetting = true
PlayerCastingBarFrame:SetLook("UNITFRAME")
PlayerCastingBarFrame:UpdateBarFillTexture(false)
PlayerCastingBarFrame:SetMinMaxValues(0, 5)
PlayerCastingBarFrame:SetValue(1)
PlayerCastingBarFrame.CastTimeText:SetText("4.0")
if usingNativeSource then
    -- Preserve the native event handlers, not a test-owned replacement cast engine.
    PlayerCastingBarFrame:OnLoad("player", true, false)
    PlayerCastingBarFrame:SetLook("UNITFRAME")
end
PyresinQoLDB = { modules = { unitFrames = true } }
EditModeManagerFrame = {
    GetActiveLayoutSystemInfo = function(self) return self.info end,
    UpdateSystemAnchorInfo = function(self, target)
        local point, _, relativePoint, x, y = target:GetPoint(1)
        self.info = { anchorInfo = { point = point, relativePoint = relativePoint,
            offsetX = x * target:GetScale(), offsetY = y * target:GetScale() } }
    end,
}
function GetLocale() return "enUS" end
local function LoadAddon()
    local session = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", session)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/Config.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/Models.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/Textures.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/Presentation.lua"))("PyresinQoL", session)
    assert(loadfile("Modules/CastBar/Native.lua"))("PyresinQoL", session)
    session.InitializeModules()
    return session.CastBar
end
local castBar = LoadAddon()
assert(not castBar.IsEnabled(), "Player bar must start wholly native")
assert(castBar.frame == PlayerCastingBarFrame)

local frame = PlayerCastingBarFrame
local function StartCast(channel, shield)
    state.worldCast = { "Arcane Blast", "Arcane Blast", "spell-icon", 0, 5000, false, 321, shield, 123 }
    state.worldChannel = { "Drain Life", "Drain Life", "channel-icon", 0, 5000, false, shield, 124 }
    if usingNativeSource then
        frame:OnEvent(channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", "player")
    else
        frame.barType = shield and "uninterruptable" or channel and "channel" or "standard"
        frame.casting, frame.channeling = not channel, channel
        frame.maxValue, frame.castID = 5, 321
        frame:SetMinMaxValues(0, 5)
        frame:SetValue(channel and 4 or 1)
        frame:UpdateBarFillTexture(false)
        frame.Text:SetText(channel and "Drain Life" or "Arcane Blast")
        frame.Icon:SetTexture(channel and "channel-icon" or "spell-icon")
        frame:ShowSpark()
        frame:UpdateIconShown()
        frame:UpdateCastTimeText()
        castBar.Apply()
    end
end
local function Advance(seconds)
    if usingNativeSource then frame:OnUpdate(seconds)
    else
        frame:SetValue(frame:GetValue() + (frame.channeling and -seconds or seconds))
        frame:UpdateCastTimeText()
    end
end
local function FailCast(failed)
    if usingNativeSource then
        frame:OnEvent(failed and "UNIT_SPELLCAST_FAILED" or "UNIT_SPELLCAST_INTERRUPTED", "player", 321)
    else
        frame.barType = "interrupted"
        frame:UpdateBarFillTexture(true)
        frame.Text:SetText(failed and FAILED or INTERRUPTED)
        frame.casting, frame.channeling = nil, nil
        frame:ShowSpark()
    end
end
local function Near(actual, expected)
    assert(math.abs(actual - expected) < .00001, ("expected %.3f, got %.3f"):format(expected, actual))
end
-- These Wago layers stretch to progress; all others keep a full-bar viewport.
local stretchModels = { elva_astral = 165821, elva_celestial = 165829, elva_ember = 166112,
    elva_flux = 166784, elva_galaxy = 165829, elva_nebula = 166594, elva_sage = 166694, elva_sunset = 166594 }
local function CheckModelViewport(model, descriptor, fullRegion, fillRegion)
    local expected = stretchModels[descriptor.id] == model.modelFile and fillRegion or fullRegion
    assert(model.allPoints == expected and model:GetNumPoints() == 0,
        "Model viewport must match Wago's stretch setting, including after frame reuse")
end
return {
    castBar = castBar, state = state, secret = secret, Frame = Frame, Region = Region,
    eventFrames = eventFrames, modelFrames = modelFrames, usingNativeSource = usingNativeSource,
    StartCast = StartCast, Advance = Advance, FailCast = FailCast, Near = Near,
    CheckModelViewport = CheckModelViewport,
    LoadAddon = function()
        frame = PlayerCastingBarFrame
        castBar = LoadAddon()
        return castBar
    end,
}
