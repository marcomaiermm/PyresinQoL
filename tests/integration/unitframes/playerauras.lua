-- luajit tests/integration/unitframes/playerauras.lua [path/to/native/BuffFrame.lua]
local module, events, ns = {}, nil, {}
local nativeContext = false
local extraLineHeight, measurements = 0, {}
UIParent = {}
function UIParent:CreateFontString()
    local text = {}
    measurements[#measurements + 1] = text
    function text:SetText(value)
        assert(value == "0", "Measure a constant, never native aura text")
        self.text = value
    end
    function text:SetFont(font, size, flags)
        assert(font == "native-font" and flags == "OUTLINE")
        self.fontSize = size
    end
    function text:Hide() self.hidden = true end
    function text:GetStringHeight()
        assert(self.text == "0" and self.hidden, "Only the hidden owned sample may be measured")
        return self.fontSize + extraLineHeight
    end
    return text
end
PyresinQoLDB = {}
PlayerFrame = { unit = "player" }
local auraData = {
    [1] = { name = "Zeta", sourceUnit = "party1" },
    [2] = { name = "Alpha", sourceUnit = "player" },
    [3] = { name = "Beta", sourceUnit = "pet" },
    [4] = { name = "Gamma", sourceUnit = "party2" },
}
C_UnitAuras = { GetAuraDataByAuraInstanceID = function(unit, id) assert(unit == PlayerFrame.unit); return auraData[id] end }
function GetTime() return 100 end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
local function Region()
    local region = { scripts = {}, width = 30, height = 40, alpha = 1 }
    function region:SetPoint(...) self.point = { ... } end
    function region:ClearAllPoints() self.point = nil end
    function region:GetNumPoints() return self.point and 1 or 0 end
    function region:GetPoint() return unpack(self.point) end
    function region:SetSize(w, h) self.width, self.height = w, h end
    function region:GetSize() return self.width, self.height end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end
    function region:SetScale(value) self.scale = value end
    function region:SetAlpha(value) self.alpha = value end
    function region:EnableMouse(value) self.mouse = value end
    function region:SetShown(value) self.shown = value end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:SetAllPoints(target) self.allPoints = target end
    function region:GetFont() return "native-font", 13, "OUTLINE" end
    function region:SetFont(font, size, flags) self.font, self.fontSize, self.flags = font, size, flags end
    function region:HookScript(event, callback) self.scripts[event] = callback end
    return region
end
local function Button(id, duration, expiration, kind)
    local button = Region()
    button.Icon, button.Duration, button.DebuffBorder, button.TempEnchantBorder = Region(), Region(), Region(), Region()
    local function RestrictedTimerRead() error("Do not measure or read native aura timer content") end
    button.Duration.GetText = RestrictedTimerRead
    button.Duration.GetStringHeight = RestrictedTimerRead
    button.Duration.GetHeight = RestrictedTimerRead
    button.buttonInfo = { auraInstanceID = id, duration = duration, expirationTime = expiration, auraType = kind or "Buff" }
    button.hasValidInfo = true
    button.scripts.OnClick = function() return id end
    return button
end
local function Owner(private)
    local owner = Region()
    owner.AuraContainer = Region()
    local container = owner.AuraContainer
    container.iconScale, container.isHorizontal, container.iconStride, container.iconPadding = 1, true, 8, 5
    owner.auraFrames = { Button(1, 100, 200), Button(2, 30, 130), Button(3, 60, 160), Button(4, 0, 0), Button(nil, nil, 150, "TempEnchant") }
    function owner:IsEditing() return self.editing end
    function owner:UpdateAuraButtons()
        assert(nativeContext, "Addon callbacks must not invoke native aura rendering with secret stack counts")
    end
    function owner:UpdateAuraContainerAnchor() container:SetPoint("TOPRIGHT", self, "TOPRIGHT") end
    function owner:UpdateGridLayout()
        assert(nativeContext, "Addon callbacks must not invoke the native aura grid")
        for index, button in ipairs(self.auraFrames) do
            button:SetSize(container.isHorizontal and 30 or 60, container.isHorizontal and 40 or 30)
            button:SetScale(container.iconScale)
            button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -(index - 1) * 35, 0)
            button.Icon:ClearAllPoints()
            local iconPoint = container.isHorizontal and "TOP" or "RIGHT"
            button.Icon:SetPoint(iconPoint, button, iconPoint)
            button.Duration:ClearAllPoints()
            button.Duration:SetPoint(container.isHorizontal and "TOP" or "RIGHT", button.Icon,
                container.isHorizontal and "BOTTOM" or "LEFT")
        end
        self:SetSize(280, 160)
        self:UpdateAuraContainerAnchor()
    end
    if private then
        local anchor = Region()
        anchor.isAuraAnchor = true
        anchor.Icon, anchor.Duration = Region(), Region()
        owner.auraFrames[#owner.auraFrames + 1] = anchor
    end
    return owner
end
BuffFrame, DebuffFrame = Owner(), Owner(true)
function hooksecurefunc(owner, key, callback)
    local original = assert(owner[key])
    owner[key] = function(...) original(...); callback(...) end
end
function CreateFrame(kind, _, parent, template)
    local frame = Region()
    if kind == "Cooldown" then
        assert(parent and template == "CooldownFrameTemplate")
        function frame:SetReverse(value) self.reverse = value end
        function frame:SetCountdownFont(value) self.font = value end
        function frame:SetDrawSwipe(value) self.swipe = value end
        function frame:SetHideCountdownNumbers(value) self.hideNumbers = value end
        function frame:SetCooldown(start, duration, modifier) self.start, self.duration, self.modifier = start, duration, modifier end
        parent.cooldown = frame
    else
        events = frame
        function frame:RegisterEvent(event) self.event = event end
        function frame:UnregisterEvent(event) assert(self.event == event); self.event = nil end
        function frame:SetScript(event, callback) assert(event == "OnEvent"); self.callback = callback end
    end
    return frame
end
-- Optional: use the pinned client's actual grid/anchor methods for restoration.
if arg[1] then
    CVarCallbackRegistry = { SetCVarCachable = function() end }
    HelpTip = { ButtonStyle = {}, Point = {}, Alignment = {} }
    Enum = { FrameTutorialAccount = {} }
    function CreateFromMixins(...)
        local result = {}
        for _, mixin in ipairs({ ... }) do for key, value in pairs(mixin) do result[key] = value end end
        return result
    end
    function tFilter(values, predicate)
        local result = {}
        for _, value in ipairs(values) do if predicate(value) then result[#result + 1] = value end end
        return result
    end
    AnchorUtil = { CreateAnchor = function(point, relative) return { point = point, relative = relative } end }
    GridLayoutUtil = {
        CreateStandardGridLayout = function() return {} end,
        CreateVerticalGridLayout = function() return {} end,
        ApplyGridLayout = function(frames, anchor)
            for _, button in ipairs(frames) do button:SetPoint(anchor.point, anchor.relative, anchor.point, 0, 0) end
        end,
    }
    assert(loadfile(arg[1]))()
    for _, owner in ipairs({ BuffFrame, DebuffFrame }) do
        local container = owner.AuraContainer
        function container:GetParent() return owner end
        owner.maxAuras = 32
        owner.UpdateSize = AuraFrameMixin.UpdateSize
        owner.UpdateAuraContainerAnchor = BaseAuraFrameMixin.UpdateAuraContainerAnchor
        owner.UpdateGridLayout = BaseAuraFrameMixin.UpdateGridLayout
        container.UpdateGridLayout = AuraContainerMixin.UpdateGridLayout
    end
end
-- Native event dispatch initializes geometry before any addon callbacks.
nativeContext = true
for _, owner in ipairs({ BuffFrame, DebuffFrame }) do owner:UpdateGridLayout() end
nativeContext = false
-- Apply the same boundary check to the optional real native grid implementation.
for _, owner in ipairs({ BuffFrame, DebuffFrame }) do
    local nativeGrid = owner.UpdateGridLayout
    owner.UpdateGridLayout = function(...)
        assert(nativeContext, "Addon callbacks must not invoke the native aura grid")
        return nativeGrid(...)
    end
end
ns.RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize(module) end
assert(loadfile("Modules/UnitFrames/PlayerAuras.lua"))("PyresinQoL", ns)
module.UpdatePlayerAuras()
events:callback("PLAYER_LOGIN")
local first, own, pet, permanent, enchant = unpack(BuffFrame.auraFrames)
local click = own.scripts.OnClick
assert(not own.cooldown and not own.scripts.OnUpdate, "Default layout leaves native buttons alone")
PyresinQoLDB.buffLayout, PyresinQoLDB.buffOwn, PyresinQoLDB.buffOwnRow = true, "first", true
PyresinQoLDB.buffWrap, PyresinQoLDB.buffSort = 2, "name"
PyresinQoLDB.buffTimerPosition = "inside"
PyresinQoLDB.buffSize, PyresinQoLDB.buffGapX, PyresinQoLDB.buffGapY = 40, 7, 9
module.UpdatePlayerAuras()
assert(enchant.point[4] == 0 and enchant.point[5] == 0 and own.point[4] == -47)
assert(pet.point[5] == -49 and first.point[5] == -98, "Own/other boundary must start a new row")
assert(own.Duration.point[1] == "CENTER" and own.Duration.fontSize == 12)
assert(own.Icon.width == 40 and own.DebuffBorder.width == 50 and own.scripts.OnClick == click and click() == 2)
PyresinQoLDB.buffOwn, PyresinQoLDB.buffSort, PyresinQoLDB.buffSortDirection = "mixed", "time", "descending"
PyresinQoLDB.buffDirection, PyresinQoLDB.buffGrowth = "RIGHT", "UP"
PyresinQoLDB.buffTimerPosition, PyresinQoLDB.buffTimerGap = "above", 3
module.UpdatePlayerAuras()
assert(permanent.point[4] == 0 and permanent.point[5] == 0 and first.point[4] == 47)
assert(own.point[1] == "BOTTOMLEFT" and own.Duration.point[1] == "BOTTOM")
assert(own.Icon.point[5] == -15, "Above timers need space inside the selection bounds")
pet.buttonInfo.timeMod = 4
module.UpdatePlayerAuras()
assert(own.point[4] == 47 and pet.point[4] == 0, "Time sorting must match the native remaining-time modifier")
PyresinQoLDB.buffRows, PyresinQoLDB.buffSwipe, PyresinQoLDB.buffCooldownNumbers = 1, true, true
module.UpdatePlayerAuras()
assert(own.alpha == 0 and own.mouse == false)
assert(own.cooldown.swipe and not own.cooldown.hideNumbers and own.cooldown.start == 100 and own.cooldown.duration == 30)
assert(pet.cooldown.modifier == 4)
pet.buttonInfo.timeMod = nil
assert(not permanent.cooldown, "Permanent auras must not acquire a duration")
own:SetAlpha(0.5)
own.scripts.OnUpdate()
assert(own.alpha == 0, "Native warning flashes must not reveal clipped auras")
PyresinQoLDB.buffRows, PyresinQoLDB.buffTimerPosition = 4, "hidden"
module.UpdatePlayerAuras()
assert(own.alpha == 1 and own.mouse and own.Duration.alpha == 0)
local secret = setmetatable({ secret = true }, { __lt = function() error("Compared restricted data") end })
first.buttonInfo.expirationTime = secret
auraData[1].sourceUnit, auraData[1].name = secret, secret
module.UpdatePlayerAuras()
PyresinQoLDB.debuffLayout, PyresinQoLDB.debuffRows, PyresinQoLDB.debuffWrap, PyresinQoLDB.debuffSize = true, 1, 1, 16
module.UpdatePlayerAuras()
local private = DebuffFrame.auraFrames[6]
assert(private.width == 30 and private.height == 40 and private.alpha == 1 and private.point[5] == -54)
assert(not private.scripts.OnUpdate and not private.cooldown, "Never style or clip private aura contents")
PyresinQoLDB.buffLayout = false
module.UpdatePlayerAuras()
assert(own.Icon.width == 30 and own.Duration.fontSize == 13 and own.Duration.alpha == 1 and not own.cooldown.shown)
assert(own.point[1] == "TOPRIGHT" and own.Duration.point[1] == "TOP" and own.mouse and own.alpha == 1)
assert(own.scripts.OnClick == click and #BuffFrame.auraFrames == 5, "Do not replace or reorder native button arrays")
PyresinQoLDB.buffLayout = true
PyresinQoLDB.buffRows, PyresinQoLDB.buffWrap, PyresinQoLDB.buffSize = 4, 2, 40
BuffFrame.AuraContainer.iconScale = 1.5
BuffFrame.ConsolidatedBuffs = Button(nil, nil, nil)
function BuffFrame.ConsolidatedBuffs:ShouldShow() return true end
BuffFrame.CollapseAndExpandButton = Region()
BuffFrame.CollapseAndExpandButton.width = 15
function BuffFrame.CollapseAndExpandButton:UpdateOrientation() end
nativeContext = true
BuffFrame:UpdateGridLayout()
nativeContext = false
module.UpdatePlayerAuras()
assert(BuffFrame.ConsolidatedBuffs.point[4] == 0 and first.point[4] == 47)
assert(first.point[4] * first.scale == 70.5, "Offsets receive native icon scaling exactly once")
assert(BuffFrame.AuraContainer.point[4] == 22.5 and BuffFrame.CollapseAndExpandButton.expandDirection == 1)
assert(BuffFrame.width == (2 * 47 - 7 + 15) * 1.5)
for _, scale in ipairs({ 0.5, 2 }) do
    BuffFrame.AuraContainer.iconScale = scale
    nativeContext = true
    BuffFrame:UpdateGridLayout()
    nativeContext = false
    module.UpdatePlayerAuras()
    assert(first.point[4] == 47 and first.point[4] * first.scale == 47 * scale)
    assert(BuffFrame.width == (2 * 47 - 7 + 15) * scale)
end
DebuffFrame.AuraContainer.isHorizontal = false
PyresinQoLDB.debuffWrap, PyresinQoLDB.debuffSize = 2, 16
nativeContext = true
DebuffFrame:UpdateGridLayout()
nativeContext = false
module.UpdatePlayerAuras()
assert(private.width == 60 and private.height == 30, "Keep native vertical private-aura dimensions")
assert(private.Duration.point[1] == "RIGHT" and private.Duration.point[3] == "LEFT")
assert(DebuffFrame.width == 125, "Reserve the full 60px private-aura footprint in every column")
PyresinQoLDB.debuffLayout = false
module.UpdatePlayerAuras()
assert(private.width == 60 and private.height == 30 and private.Duration.point[1] == "RIGHT")
BuffFrame.editing = true
own.isExample = true
module.UpdatePlayerAuras()
assert(not own.cooldown.shown, "Edit Mode examples must not use stale live aura durations")
DebuffFrame.editing = true
module.UpdatePlayerAuras()
assert(not private.cooldown and private.alpha == 1)

-- A 12px font can occupy a 15px line. Zero row gap must still clear the timer
-- in both growth directions; inside/hidden timers must not enlarge the cell.
extraLineHeight = 3
BuffFrame.ConsolidatedBuffs = nil
BuffFrame.AuraContainer.iconScale = 1
PyresinQoLDB.buffSize, PyresinQoLDB.buffTimerSize, PyresinQoLDB.buffTimerGap = 30, 12, 0
PyresinQoLDB.buffWrap, PyresinQoLDB.buffRows, PyresinQoLDB.buffGapY = 1, 8, 0
PyresinQoLDB.buffOwn, PyresinQoLDB.buffSort, PyresinQoLDB.buffSortDirection = "mixed", "index", "ascending"
for _, case in ipairs({
    { timer = "below", growth = "DOWN", height = 45, iconY = 0 },
    { timer = "below", growth = "UP", height = 45, iconY = 0 },
    { timer = "above", growth = "DOWN", height = 45, iconY = -15 },
    { timer = "above", growth = "UP", height = 45, iconY = -15 },
    { timer = "native", growth = "DOWN", height = 45, iconY = 0 },
    { timer = "native", growth = "UP", height = 45, iconY = -15 },
    { timer = "inside", growth = "DOWN", height = 30, iconY = 0 },
    { timer = "hidden", growth = "UP", height = 30, iconY = 0 },
}) do
    PyresinQoLDB.buffTimerPosition, PyresinQoLDB.buffGrowth = case.timer, case.growth
    module.UpdatePlayerAuras()
    local label = case.timer .. "/" .. case.growth
    local step = own.point[5] - first.point[5]
    assert(step == (case.growth == "UP" and case.height or -case.height), label .. ": row spacing clears actual line height")
    assert(first.height == case.height and own.height == case.height, label .. ": selection bounds contain timer")
    assert(first.Icon.point[5] == case.iconY, label .. ": timer space belongs above/below the icon")
end
assert(#measurements == 1, "Reuse one owned font sample across frames and layout updates")
PyresinQoLDB.buffSize = 0 / 0
assert(ns.AuraNumber("buffSize", 30, 16, 64) == 30)
-- A native pool may reuse a removed middle button for a new, unique aura ID.
-- Unlike the pinned simulator's length-based IDs, real IDs do not collide with
-- an existing survivor when an insertion follows a middle removal.
local survivorA, removed, survivorB = Button(11, 20, 120), Button(12, 40, 140), Button(13, 80, 180)
for _, id in ipairs({ 11, 12, 13, 14 }) do auraData[id] = { name = "Aura " .. id, sourceUnit = "player" } end
BuffFrame.auraFrames = { survivorA, removed, survivorB }
PyresinQoLDB.buffSize, PyresinQoLDB.buffWrap, PyresinQoLDB.buffRows = 30, 8, 4
PyresinQoLDB.buffLayout, PyresinQoLDB.buffSwipe, PyresinQoLDB.buffSort = true, true, "time"
PyresinQoLDB.buffSortDirection, PyresinQoLDB.buffDirection, PyresinQoLDB.buffGrowth = "ascending", "RIGHT", "DOWN"
module.UpdatePlayerAuras()
BuffFrame.auraFrames = { survivorA, survivorB }
module.UpdatePlayerAuras()
assert(survivorB.point[4] - survivorA.point[4] == 30 + PyresinQoLDB.buffGapX, "Middle removal compacts survivors")
removed.buttonInfo = { auraInstanceID = 14, duration = 10, expirationTime = 110, auraType = "Buff" }
BuffFrame.auraFrames = { survivorA, survivorB, removed }
module.UpdatePlayerAuras()
assert(removed.point[4] == 0 and survivorA.point[4] == 30 + PyresinQoLDB.buffGapX,
    "New shortest aura sorts first despite reusing the middle button")
assert(removed.cooldown.duration == 10 and removed.cooldown.start == 100,
    "Reused swipe uses the new aura duration, not the removed aura")
print("PASS: player aura sorting, ownership, wrapping, timer geometry, cooldowns, restricted data, private anchors and native restoration")
