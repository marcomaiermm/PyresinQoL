local h = assert(loadfile("tests/support/castbar.lua"))(arg[1])
local castBar, frame = h.castBar, PlayerCastingBarFrame
local StartCast, Advance, FailCast = h.StartCast, h.Advance, h.FailCast
local state, secret, Frame = h.state, h.secret, h.Frame
local usingNativeSource, LoadAddon = h.usingNativeSource, h.LoadAddon
local nativeTexture = frame:GetStatusBarTexture():GetTexture()
local nativeWidth, nativeHeight = frame:GetSize()
local nativeIconShown = frame.Icon:IsShown()
local nativeFont, nativeSize = frame.Text:GetFont()
local function SameNative()
    assert(frame:GetStatusBarTexture():GetTexture() == nativeTexture)
    assert(frame:GetWidth() == nativeWidth and frame:GetHeight() == nativeHeight)
    assert(frame.Text:GetFont() == nativeFont and select(2, frame.Text:GetFont()) == nativeSize)
    assert(frame.Icon:IsShown() == nativeIconShown)
    assert(frame:GetScale() == .85)
end
local defaults = {
    layout = "native", texture = "default", colorMode = "original", customColor = { r = 1, g = 1, b = 1 },
    width = 0, height = 0, fontSize = 0, showSpellName = true,
    namePosition = "native", nameAlignment = "native", nameSpacing = -1,
    timePosition = "native", timeAlignment = "native", timeSpacing = -1,
    timeFormat = "native", icon = "native", iconGap = 5, showSpark = true,
    borderStyle = "native", borderColorMode = "original", borderColor = { r = 1, g = 1, b = 1 },
    borderOpacity = 1, borderSize = 1,
    backgroundOpacity = -1, uninterruptible = "blizzard", customInterruptTexture = true,
    uninterruptibleColor = { r = .7, g = .7, b = .7 },
    showLatency = false, latencyOpacity = .35,
}
for key, expected in pairs(defaults) do
    local actual = castBar.Get(key)
    if type(expected) == "table" then
        assert(actual.r == expected.r and actual.g == expected.g and actual.b == expected.b, key)
    else
        assert(actual == expected, key)
    end
end
assert(castBar.Get("showCastTime") == nil and frame.showCastTimeSetting == true)
SameNative()
for _, invalid in ipairs({
    { "layout", "unknown" }, { "width", 99 }, { "width", 601 }, { "height", 5 }, { "height", 49 },
    { "fontSize", 7 }, { "fontSize", 25 }, { "backgroundOpacity", -0.5 },
    { "latencyOpacity", 1.1 }, { "timeFormat", "elapsed" }, { "icon", "center" },
    { "animated", "false" }, { "animated", 0 }, { "animated", secret },
    { "showSpark", 1 }, { "customColor", { r = secret, g = 0, b = 0 } },
    { "customColor", { r = 2, g = 0, b = 0 } }, { "texture", "missing-asset" },
}) do
    assert(castBar.Set(invalid[1], invalid[2]) == false, invalid[1])
end
assert(not next(PyresinQoLDB.castBar or {}))
assert(castBar.Set("width", 100) and castBar.Get("width") == 100)
assert(castBar.Set("height", 48) and castBar.Get("height") == 48)
assert(castBar.Set("fontSize", 24) and castBar.Get("fontSize") == 24)
SameNative() -- Stored customizations alone never seize Blizzard's bar.
assert(castBar.Set("width", 0) and castBar.Set("height", 0) and castBar.Set("fontSize", 0))
assert(not next(PyresinQoLDB.castBar))

assert(castBar.SetEnabled(true))
assert(castBar.Set("width", 250) and castBar.Set("height", 20) and castBar.Set("fontSize", 16))
assert(castBar.Set("colorMode", "custom"))
local pickedColor = { r = .2, g = .3, b = .4 }
assert(castBar.Set("customColor", pickedColor))
pickedColor.r = 1 -- Saved colors must be copies, not mutable picker buffers.
assert(castBar.Get("customColor").r == .2)
assert(castBar.Set("showSpellName", false))
assert(castBar.Set("borderStyle", "none") and castBar.Set("showSpark", false))
assert(castBar.Set("backgroundOpacity", .25) and castBar.Set("timeFormat", "remainingTotal"))
assert(castBar.Set("showLatency", true) and castBar.Set("latencyOpacity", .5))
assert(castBar.Set("icon", "off"))
StartCast(false, false)
assert(frame.casting and not frame.channeling and frame.showIcon)
assert(frame:GetWidth() == 250 and frame:GetHeight() == 20 and frame:GetScale() == .85)
assert(select(2, frame.Text:GetFont()) == 16 and select(2, frame.CastTimeText:GetFont()) == 16)
assert(frame.Text:GetText() == "Arcane Blast" and frame.Text:GetAlpha() == 0)
assert(frame.CastTimeText:GetText() == "4.0 / 5.0")
assert(frame.Border:GetAlpha() == 0 and frame.BorderShield:GetAlpha() == 1)
assert(frame.Background:GetAlpha() == .25 and not frame.Spark:IsShown() and not frame.Icon:IsShown())
assert(frame:GetStatusBarColor() == .2)
local latency = frame.children[1]
assert(latency and latency:IsShown() and latency:GetWidth() == 10 and latency:GetAlpha() == .5)
assert(latency.points[1][1] == "TOPRIGHT")
local otherBar = Frame()
setmetatable(otherBar, { __index = CastingBarMixin })
otherBar.showIcon = true
otherBar:SetLook("UNITFRAME")
otherBar.barType = "channel"
otherBar:UpdateBarFillTexture(false)
assert(otherBar:GetWidth() == 150 and otherBar:GetStatusBarTexture():GetTexture()
    == CastingBarTypeInfo.channel.filling and otherBar:GetStatusBarColor() == 1)
assert(otherBar.Text:GetAlpha() == .8 and otherBar.Background:GetAlpha() == .6,
    "Target/overlay cast bars must keep Blizzard's native presentation")
Advance(.5)
assert(frame.CastTimeText:GetText() == "3.5 / 5.0")
assert(castBar.Set("timeFormat", "remaining"))
assert(frame.CastTimeText:GetText() == "3.5")
assert(castBar.Set("timeFormat", "native"))
frame:UpdateCastTimeText()
assert(frame.CastTimeText:GetText() == "3.5", "Native cast-time formatter stays Blizzard-owned")
assert(castBar.Set("icon", "right"))
assert(castBar.Set("height", 48))
assert(frame.Icon:IsShown() and frame.Icon.points[1][1] == "LEFT"
    and frame.Icon.points[1][2] == frame and frame.Icon.points[1][3] == "RIGHT")
assert(frame.Icon:GetWidth() == 48 and frame.Icon:GetHeight() == 48)
assert(castBar.Set("icon", "left"))
assert(frame.Icon:IsShown() and frame.Icon.points[1][1] == "RIGHT")
assert(frame.Icon:GetWidth() == 48 and frame.Icon:GetHeight() == 48)
assert(castBar.Set("icon", "off"))
assert(not frame.Icon:IsShown() and frame.Icon:GetWidth() == 16 and frame.Icon:GetHeight() == 16)
assert(castBar.Set("icon", "native"))
assert(frame.Icon.points[1][1] == "CENTER" and frame.Icon.points[1][2] == frame)
assert(frame.Icon:GetWidth() == 16 and frame.Icon:GetHeight() == 16)
assert(castBar.Set("height", 20))
assert(castBar.Set("showSpark", true))
frame:ShowSpark()
assert(frame.Spark:IsShown())
assert(castBar.Set("showSpark", false))
assert(not frame.Spark:IsShown())
-- Disable while a real cast is active; native spark, text, time, and fill return
-- without re-entering the addon through ShowSpark / UpdateCastTimeText hooks.
assert(castBar.SetEnabled(false))
assert(frame.Spark:IsShown() and frame.Text:GetAlpha() == .8)
assert(frame.CastTimeText:GetText() == "3.5" and frame:GetStatusBarColor() == 1)
assert(frame:GetWidth() == nativeWidth and frame:GetHeight() == nativeHeight)
assert(frame.Border:GetAlpha() == 1 and frame.Background:GetAlpha() == .6)
assert(not latency:IsShown() and frame.Icon.points[1][1] == "CENTER")
assert(frame.Icon:GetWidth() == 16 and frame.Icon:GetHeight() == 16)
assert(castBar.Get("width") == 250 and not castBar.IsEnabled())
assert(castBar.SetEnabled(true))
assert(frame:GetWidth() == 250 and not frame.Spark:IsShown())
frame:UpdateBarFillTexture(false)
assert(frame:GetStatusBarColor() == .2, "A native texture refresh must reapply the current tint")
assert(castBar.Set("colorMode", "class"))
assert(frame:GetStatusBarColor() == .2)
state.playerClass = "UNKNOWN"
castBar.Apply()
assert(frame:GetStatusBarColor() == 1, "Missing class colors fall back to native")
state.playerClass = "MAGE"
castBar.Apply()
assert(frame:GetStatusBarColor() == .2 and select(2, frame:GetStatusBarColor()) == .5)
assert(castBar.Set("colorMode", "original") and frame:GetStatusBarColor() == 1)
assert(castBar.Set("colorMode", "custom"))
state.worldCast[5] = 9000
if usingNativeSource then frame:OnEvent("UNIT_SPELLCAST_DELAYED", "player")
else frame.maxValue = 9; frame:SetMinMaxValues(0, 9); castBar.Apply() end
assert(math.abs(latency:GetWidth() - 250 * .2 / 9) < .00001,
    "Delayed casts recalculate latency from the new native duration")
StartCast(true, false)
assert(frame.channeling and not frame.casting)
if usingNativeSource then frame:OnUpdate(0) end -- Native onset updates time before switching to channel state.
assert(frame.CastTimeText:GetText() == "4.0")
assert(latency:IsShown() and latency.points[1][1] == "TOPLEFT" and latency:GetWidth() == 10)
Advance(.5)
assert(frame.CastTimeText:GetText() == "3.5")
state.worldChannel[5] = 9000
if usingNativeSource then frame:OnEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
else frame.maxValue = 9; frame:SetMinMaxValues(0, 9); castBar.Apply() end
assert(math.abs(latency:GetWidth() - 250 * .2 / 9) < .00001,
    "Updated channels recalculate latency while remaining start-aligned")
state.networkMs = 10000
castBar.Apply()
assert(latency:GetWidth() == 250, "Latency cannot exceed the duration of the bar")
state.networkMs = 0
castBar.Apply()
assert(not latency:IsShown())
state.networkMs = 200
castBar.Apply()
assert(latency:IsShown())
castBar.Reset()
assert(castBar.IsEnabled() and not next(PyresinQoLDB.castBar or {}))
assert(frame:GetWidth() == nativeWidth and frame:GetHeight() == nativeHeight)
assert(frame.Spark:IsShown() and frame.Text:GetAlpha() == .8 and frame.Background:GetAlpha() == .6)
assert(frame:GetStatusBarColor() == 1 and not latency:IsShown())
assert(frame.channeling, "Reset restores art, not Blizzard's cast engine")

assert(castBar.Set("colorMode", "custom") and castBar.Set("customColor", { r = .2, g = .3, b = .4 }))
assert(castBar.Set("showSpellName", false) and castBar.Set("showLatency", true))
StartCast(false, true)
assert(frame.barType == "uninterruptable")
assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.uninterruptable.filling)
assert(frame:GetStatusBarColor() == 1, "Native uninterruptible styling wins by default")
assert(castBar.Set("uninterruptible", "custom"))
assert(castBar.Set("uninterruptibleColor", { r = .6, g = .5, b = .4 }))
assert(frame:GetStatusBarColor() == .6 and select(2, frame:GetStatusBarColor()) == .5)
assert(castBar.Set("uninterruptible", "blizzard") and frame:GetStatusBarColor() == 1)
assert(castBar.Set("borderStyle", "none"))
assert(castBar.SetEnabled(false))
assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.uninterruptable.filling)
assert(frame:GetStatusBarColor() == 1 and frame.Border:GetAlpha() == 1)
assert(castBar.SetEnabled(true))
StartCast(false, false)
FailCast(false)
assert(frame.barType == "interrupted" and frame.Text:GetText() == INTERRUPTED)
assert(frame.Text:GetAlpha() == .8 and frame:GetStatusBarColor() == 1)
assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.interrupted.full)
StartCast(false, false)
FailCast(true)
assert(frame.Text:GetText() == FAILED and frame.Text:GetAlpha() == .8)
assert(frame:GetStatusBarTexture():GetTexture() == CastingBarTypeInfo.interrupted.full)

castBar.Reset()
assert(castBar.Set("width", 280) and castBar.Set("icon", "off"))
assert(castBar.Set("timeFormat", "remainingTotal"))
castBar.Set("namePosition", "above")
castBar.Set("timeAlignment", "left")
castBar.Set("timeSpacing", 9)
castBar.Set("customInterruptTexture", false)
castBar.Set("animated", false)
castBar.Set("texture", "elva_void")
local saved = PyresinQoLDB
assert(saved.castBar.width == 280 and saved.castBar.icon == "off")
assert(saved.castBarCustomization and saved.castBar.scale == nil and saved.castBar.position == nil)
PlayerCastingBarFrame = Frame()
setmetatable(PlayerCastingBarFrame, { __index = CastingBarMixin })
frame = PlayerCastingBarFrame
frame.unit, frame.showIcon, frame.showCastTimeSetting = "player", true, true
frame:SetLook("UNITFRAME")
frame:UpdateBarFillTexture(false)
frame:SetMinMaxValues(0, 5)
frame:SetValue(1)
if usingNativeSource then frame:OnLoad("player", true, false); frame:SetLook("UNITFRAME") end
castBar = LoadAddon()
assert(castBar.IsEnabled() and castBar.frame == frame and castBar.Get("width") == 280)
assert(not castBar.Get("animated") and saved.castBar.animated == false, "Flipbook playback preference survives reload")
StartCast(false, false)
assert(frame:GetWidth() == 280 and not frame.Icon:IsShown())
assert(frame.CastTimeText:GetText() == "4.0 / 5.0")
assert(not castBar.Get("customInterruptTexture"))
assert(castBar.Get("texture") == "elva_void" and frame.pyresinCastModels:IsShown())
assert(castBar.Get("namePosition") == "above" and castBar.Get("timeAlignment") == "left" and castBar.Get("timeSpacing") == 9)
castBar.Reset()
assert(frame:GetWidth() == 150 and saved.castBarCustomization)
assert(saved.castBar == nil and castBar.Get("icon") == "native" and castBar.Get("customInterruptTexture"))
assert(castBar.Get("animated"), "Reset restores animated profession textures")

print("PASS: cast-bar config")
