-- Run from the addon directory: luajit tests/integration/core/settings.lua [disabled|de|modules-disabled]
local h = assert(loadfile("tests/support/settings.lua"))(arg[1])
local ns, settings, updates = h.ns, h.settings, h.updates
local NavigationButton, BuildMenu = h.NavigationButton, h.BuildMenu

assert(settings.PyresinQoL_StatusText == nil, "Status text belongs to Blizzard's options")
assert(h.nativeThreatCheckbox:ShouldShow() and h.nativeThreatPosition:ShouldShow())
assert(h.nativeThreatCheckbox.modifyPredicate() == ns.GetModule("unitFrames").active
    and h.nativeThreatPosition.modifyPredicate() == ns.GetModule("unitFrames").active,
    "Native options remain visible but disabled when the module is inactive")
if arg[1] == "modules-disabled" then
    h.canvas.scripts.OnShow()
    assert(h.addonButtonCount == 0 and not ns.ModulesNeedReload() and not h.reloadButton.enabled)
    assert(h.settingsList.Header.Title.value == ns.L.modules)
    for _, module in ipairs(ns.modules) do
        local button = NavigationButton(module.pages[1].name)
        button.scripts.OnClick()
        assert(button.text.color[1] == 0.5)
        local controls = 0
        for _, initializer in ipairs(h.settingsList.initializers) do
            if initializer.modifyPredicate then
                controls = controls + 1
                assert(not initializer.modifyPredicate())
            end
        end
        assert(controls > 0)
        assert(not h.settingsList.Header.DefaultsButton.enabled)
    end
    NavigationButton(ns.L.profiles).scripts.OnClick()
    assert(h.profilePanel.shown and not h.settingsList.Header.DefaultsButton.shown
        and NavigationButton(ns.L.profiles).text.color[1] == 1,
        "Profiles remains available when every module is disabled")
    h.navigation[1].scripts.OnClick()
    h.settingsList.Header.DefaultsButton.scripts.OnClick()
    assert(ns.ModulesNeedReload() and h.reloadButton.enabled and h.addonButtonCount == 0)
    print("PASS: all modules disabled, absent callbacks, locked options and unchanged Blizzard settings")
    return
end
assert(not h.events.registered.ADDON_LOADED)
assert(h.canvas and #h.navigation == 17 and #h.sections == 0)
assert(#ns.GetModule("actionBars").pages == 1,
    "Per-bar visibility controls live in Edit Mode rather than a second addon settings page")
local profileButton = NavigationButton(ns.L.profiles)
assert(profileButton == h.navigation[#h.navigation] and profileButton.points[1][1] == "BOTTOMLEFT")
assert(#h.profileDropdowns == 3 and h.profileDropdowns[1].parent == h.profilePanel
    and h.profilePanel.parent == h.settingsList, "Profile controls belong to their page, not the window header")
profileButton.scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.profiles and h.profilePanel.shown
    and profileButton.selected.shown and not h.settingsList.Header.DefaultsButton.shown)
h.canvas.OnRefresh()
assert(h.profilePanel.shown, "Reopening preserves the Profiles tab")
h.navigation[1].scripts.OnClick()
assert(not h.profilePanel.shown and h.settingsList.Header.DefaultsButton.shown)
assert(h.navigation[2].text.value == ns.L.gameMenu and h.navigation[3].text.value == ns.L.editMode and h.navigation[4].text.value == ns.L.performance)
assert(not h.canvas.shown and h.canvas.width == 920 and h.canvas.height == 724)
assert(UISpecialFrames[1] == "PyresinQoLSettingsFrame" and h.canvas.clamped and h.canvas.movable)
assert(SLASH_PQOL1 == "/pqol" and SLASH_PYRESINQOL1 == nil and SLASH_PYRESINQOL2 == nil)
assert(h.canvas.NineSlice.Text.value == "PyresinQoL")
assert(#h.logos == 2 and h.logos[1].width == 72 and h.logos[1].height == 72)
local corner = h.logos[1].points[1]
assert(corner[1] == "TOPLEFT" and corner[2] == h.canvas and corner[3] == "TOPLEFT"
    and corner[4] == -20 and corner[5] == 24, "The logo must overlap the window's upper-left corner")
assert(h.logos[2].width == 48 and h.logos[2].height == 48)
local toc = assert(io.open("PyresinQoL.toc"))
assert(toc:read("*a"):find("## IconTexture: " .. h.logos[1].texture, 1, true))
toc:close()
local iconFile = assert(io.open("Media/AddonIcon.tga", "rb"))
local header = iconFile:read(18)
iconFile:close()
assert(header:byte(3) == 2 and header:byte(13) == 128 and header:byte(14) == 0
    and header:byte(15) == 128 and header:byte(16) == 0 and header:byte(17) == 32,
    "The shared icon must be an uncompressed 128x128 RGBA TGA")
h.openButton.scripts.OnClick()
assert(h.canvas.shown and not SettingsPanel.shown and h.canvas.scale == 1 and h.canvas.raised)
h.closeButton.scripts.OnClick()
assert(not h.canvas.shown)
UIParent.GetHeight = function() return 600 end
SlashCmdList.PQOL()
assert(h.canvas.shown and h.canvas.scale < 1, "The complete window must fit shorter screens")
h.canvas.ClosePanelButton.scripts.OnClick()
assert(not h.canvas.shown)
assert(#h.groupButtons == 4)
for _, group in ipairs(h.groupButtons) do
    assert(group.height == 30 and group.Background.useAtlasSize
        and group.Background.points[1][1] == "TOPLEFT", "Category art must retain its native fading background")
end
h.groupButtons[1].scripts.OnClick()
assert(not h.navigation[1].shown and not h.navigation[2].shown and not h.navigation[3].shown)
assert(profileButton.shown and profileButton.points[1][1] == "BOTTOMLEFT", "Profiles stays outside collapsed groups")
assert(h.navigation[4].shown and h.navigation[7].shown)
h.groupButtons[1].scripts.OnClick()
assert(h.navigation[1].shown and h.navigation[2].shown and h.navigation[3].shown)
h.canvas.scripts.OnShow()
assert(h.settingsList.Header.Title.value == ns.L.modules and #h.settingsList.rendered == 11)
assert(h.navigation[1].selected.shown and not h.reloadButton.enabled)
assert(h.navigation[1].text.color[2] == 1 and h.navigation[1].text.color[3] == 1,
    "The selected page uses Blizzard's white label")
assert(h.navigation[1].selected.useAtlasSize and h.navigation[1].height == 20)
h.navigation[2].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.gameMenu and #h.settingsList.rendered == 1)
assert(h.navigation[2].selected.shown and not h.navigation[3].selected.shown)
h.navigation[3].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.editMode and #h.settingsList.rendered == 1)
assert(PyresinQoLDB.pixelPerfectEditMode == false)
settings.pixelPerfectEditMode:SetValue(true)
assert(PyresinQoLDB.pixelPerfectEditMode and updates.pixelPerfect == 1)
settings.pixelPerfectEditMode:SetValue(false)
assert(not PyresinQoLDB.pixelPerfectEditMode and updates.pixelPerfect == 2)
h.navigation[4].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.performance and #h.settingsList.rendered == 7)
for index = 1, 7 do
    local row = h.settingsList.rendered[index]
    assert(row.Text.wordWrap and row.Text.maxLines == 2 and #row.Text.points == 2)
    assert(h.settingsList.initializers[index]:GetExtent() == 44 and row.Text.height == 44,
        "Rows reserve enough space for two translated lines")
    assert(row.Text.points[1][2] == 37 and row.Text.points[2][3] == "CENTER",
        "Labels retain Blizzard's inset and center-based control column")
end
h.canvas.OnRefresh()
assert(h.settingsList.Header.Title.value == ns.L.performance, "Reopening preserves the internal page")
assert(PyresinQoLDB.cooldownShortcut == (arg[1] ~= "disabled"))
assert(PyresinQoLDB.showPerformance == nil)
assert(PyresinQoLDB.showFPS == (arg[1] ~= "disabled") and PyresinQoLDB.showLatency == (arg[1] ~= "disabled"))
assert(PyresinQoLDB.performanceLayout == "column" and PyresinQoLDB.performanceOrder == "fps")
assert(PyresinQoLDB.performanceRowPadding == 14 and PyresinQoLDB.performanceColumnPadding == 5)
assert(PyresinQoLDB.performanceColor == "FFFFFFFF")
h.navigation[5].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.dungeonMaps and #h.settingsList.rendered == 1)
assert(h.settingsList.initializers[1].data.options == nil
    and h.settingsList.initializers[1].data.tooltip == ns.L.dungeonMapsEnabledHelp)
assert(PyresinQoLDB.dungeonMapsEnabled)
settings.dungeonMapsEnabled:SetValue(false)
assert(not PyresinQoLDB.dungeonMapsEnabled and updates.dungeonMap == 1)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.dungeonMapsEnabled and updates.dungeonMap == 2)
h.navigation[6].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.experience and #h.settingsList.rendered == 4)
assert(PyresinQoLDB.xpTextFormat == "both" and PyresinQoLDB.xpAlwaysShow and PyresinQoLDB.xpTooltip and PyresinQoLDB.xpQuestRewards)
h.navigation[7].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.flightTimer and #h.settingsList.rendered == 12)
assert(PyresinQoLDB.flightTimerStyle == "castbar" and PyresinQoLDB.flightTimerMarker == "pointed"
    and PyresinQoLDB.flightTimerFlags == "destination" and PyresinQoLDB.flightTimerStops == "scroll"
    and PyresinQoLDB.flightTimerTime == "left" and PyresinQoLDB.flightTimerOverlap == "ends"
    and PyresinQoLDB.flightTimerScrollNames == true and PyresinQoLDB.flightTimerStopArrows == true
    and PyresinQoLDB.flightTimerShowPost == true
    and PyresinQoLDB.flightTimerWidth == 300 and PyresinQoLDB.flightTimerScale == 100
    and PyresinQoLDB.flightTimerZones == true)
-- A new scale reformats the width's on-screen text.
local widthRow = h.settingsList.rendered[11]
widthRow.valueCallbacks.PyresinQoL_FlightTimerScale()
assert(widthRow.SliderWithSteppers.formatted == 300)
h.navigation[8].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.quests and #h.settingsList.rendered == 2)
assert(settings.questLevels.name == ns.L.questLevels and PyresinQoLDB.questLevels)
assert(settings.questItemSparkles.name == ns.L.questItemSparkles and PyresinQoLDB.questItemSparkles == false)
assert(StaticPopupDialogs.PYRESINQOL_QUEST_SPARKLES_RESTART.text == ns.L.questItemSparklesRestart)
settings.questItemSparkles:SetValue(true)
assert(PyresinQoLDB.questItemSparkles and updates.sparkle == 1 and #h.settingsList.rendered == 2)
settings.questLevels:SetValue(false)
assert(not PyresinQoLDB.questLevels and updates.quest == 1)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.questLevels and updates.quest == 2)
assert(PyresinQoLDB.questItemSparkles == false and updates.sparkle == 2 and #h.settingsList.rendered == 2)
assert(PyresinQoLDB.targetThreat == "auto")
settings.targetThreat:SetValue("off")
assert(updates.threat == 1 and PyresinQoLDB.targetThreat == "off")
assert(PyresinQoLDB.targetDebuffs and PyresinQoLDB.targetDebuffsOnlyMine)
settings.targetDebuffsOnlyMine:SetValue(false)
settings.targetDebuffs:SetValue(false)
assert(updates.debuff == 2 and not PyresinQoLDB.targetDebuffsOnlyMine and not PyresinQoLDB.targetDebuffs)
assert(not PyresinQoLDB.playerClassColor and not PyresinQoLDB.targetClassColor)
settings.playerClassColor:SetValue(true)
settings.targetClassColor:SetValue(true)
settings.playerHPPosition:SetValue("TOPLEFT")
settings.playerManaPosition:SetValue("RIGHT")
settings.targetHPPosition:SetValue("BOTTOMRIGHT")
settings.targetManaPosition:SetValue("LEFT")
assert(updates.player == 6)
h.navigation[9].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.playerFrame)
assert(settings.castBarCustomization and not ns.CastBar.IsEnabled())
settings.castBarCustomization:SetValue(true)
assert(ns.CastBar.IsEnabled() and PyresinQoLDB.castBarCustomization)
assert(ns.CastBar.Set("width", 240) and PyresinQoLDB.castBar.width == 240)
local castReset
for index, initializer in ipairs(h.settingsList.initializers) do
    if initializer.data.name == ns.L.castBarReset then
        castReset = h.settingsList.rendered[index].Button
    end
end
assert(castReset and castReset.scripts.OnClick)
castReset.scripts.OnClick()
assert(ns.CastBar.IsEnabled() and ns.CastBar.Get("width") == 0 and PyresinQoLDB.castBar == nil)
assert(ns.CastBar.Set("width", 240))
settings.castBarCustomization:SetValue(false)
assert(not ns.CastBar.IsEnabled() and PyresinQoLDB.castBarCustomization == nil
    and ns.CastBar.Get("width") == 240)
assert(PyresinQoLDB.druidMana and settings.druidMana.name == ns.L.druidMana)
settings.druidMana:SetValue(false)
assert(not PyresinQoLDB.druidMana and updates.druidMana == 1)
assert(settings.druidManaPreview == nil, "Temporary preview control has been removed")
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(not ns.CastBar.IsEnabled() and ns.CastBar.Get("width") == 0)
assert(PyresinQoLDB.druidMana and updates.druidMana == 2)
assert(updates.player == 9 and not PyresinQoLDB.playerClassColor and PyresinQoLDB.targetClassColor)
h.navigation[10].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.targetFrame and #h.settingsList.rendered == 14)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(updates.player == 12 and not PyresinQoLDB.targetClassColor)
assert(updates.threat == 2 and PyresinQoLDB.targetThreat == "auto")
assert(updates.debuff == 11 and PyresinQoLDB.targetDebuffs and PyresinQoLDB.targetDebuffsOnlyMine)
assert(PyresinQoLDB.targetAuraLargeOwn and PyresinQoLDB.targetAuraSize == 17 and PyresinQoLDB.targetAuraOwnSize == 21)
assert(PyresinQoLDB.playerHPPosition == "CENTER"
    and PyresinQoLDB.targetHPPosition == "CENTER" and PyresinQoLDB.targetManaPosition == "CENTER")
h.navigation[11].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.nameplates and #h.settingsList.rendered == 3)
assert(PyresinQoLDB.nameplateComboPoints and h.nativeComboCheckbox:ShouldShow())
h.nativeComboCheckbox.setting:SetValue(false)
assert(updates.combo == 1 and not PyresinQoLDB.nameplateComboPoints)
assert(PyresinQoLDB.nameplateThreat)
settings.nameplateThreat:SetValue(false)
assert(updates.nameplate == 1 and not PyresinQoLDB.nameplateThreat)
assert(PyresinQoLDB.nameplateThreatPosition == "RIGHT")
h.nativeThreatPosition.setting:SetValue("LEFT")
assert(updates.nameplate == 2 and PyresinQoLDB.nameplateThreatPosition == "LEFT")
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(updates.nameplate == 4 and PyresinQoLDB.nameplateThreat and PyresinQoLDB.nameplateThreatPosition == "RIGHT")
assert(updates.combo == 2 and PyresinQoLDB.nameplateComboPoints)
h.navigation[12].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.statusText and #h.settingsList.rendered == 5)
assert(h.settingsList.rendered[1].Title.value == ns.L.hideStatusText)
for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
    local key = unit .. "HideStatusText"
    assert(PyresinQoLDB[key] == false and settings[key].name == ns.L[key])
    settings[key]:SetValue(true)
    assert(PyresinQoLDB[key] == true)
end
assert(updates.statusText == 4)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
    assert(PyresinQoLDB[unit .. "HideStatusText"] == false)
end
assert(updates.statusText == 8)
h.navigation[13].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.auras and #h.settingsList.rendered == 36)
assert(not PyresinQoLDB.buffLayout and not PyresinQoLDB.debuffLayout)
settings.buffLayout:SetValue(true)
settings.buffOwn:SetValue("first")
settings.debuffGapX:SetValue(12)
assert(updates.aura == 3 and PyresinQoLDB.buffLayout and PyresinQoLDB.buffOwn == "first")
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(updates.aura == 37 and not PyresinQoLDB.buffLayout and PyresinQoLDB.buffOwn == "mixed" and PyresinQoLDB.debuffGapX == 5)
h.navigation[14].scripts.OnClick()
assert(h.settingsList.Header.Title.value == ns.L.tooltips and #h.settingsList.rendered == 36)
assert(PyresinQoLDB.tooltipHealth and PyresinQoLDB.tooltipGuildRank and PyresinQoLDB.tooltipObjectCursor)
settings.tooltipHealth:SetValue(false)
settings.tooltipGuildRank:SetValue(false)
settings.tooltipObjectCursor:SetValue(false)
assert(not PyresinQoLDB.tooltipHealth and not PyresinQoLDB.tooltipGuildRank and not PyresinQoLDB.tooltipObjectCursor and updates.tooltip == 3)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.tooltipHealth and PyresinQoLDB.tooltipGuildRank and PyresinQoLDB.tooltipObjectCursor and updates.tooltip == 33)
local headers = {}
for _, row in ipairs(h.settingsList.rendered) do
    if row.Title then headers[#headers + 1] = row.Title.value end
end
for index, name in ipairs({ "tooltipPositionSection", "tooltipSpellSection", "tooltipItemSection",
    "tooltipUnitSection", "tooltipBackgroundSection", "tooltipBorderSection" }) do
    assert(headers[index] == ns.L[name])
end
assert(#headers == 6)
local defaults = {
    tooltipAnchor = "default", tooltipAnchorPoint = "BOTTOMRIGHT", tooltipAnchorX = -30, tooltipAnchorY = 120,
    tooltipCursorAnchor = "ANCHOR_CURSOR_RIGHT", tooltipCursorX = 16, tooltipCursorY = 8,
    tooltipAnchorCombat = false, tooltipObjectCursor = true, tooltipAnchorSpells = true,
    tooltipSpellID = true, tooltipSpellIconID = false,
    tooltipItemQualityBorder = true, tooltipItemQualityBackground = false, tooltipItemStack = false,
    tooltipItemID = false, tooltipItemIconID = false, tooltipHealth = true, tooltipGuildRank = true,
    tooltipTarget = true, tooltipUnitClassBorder = true, tooltipUnitReactionBorder = true,
    tooltipUnitClassBackground = false, tooltipUnitReactionBackground = false,
    tooltipCustomBackground = false, tooltipBackgroundColor = "FF000000", tooltipBackgroundOpacity = 0.9,
    tooltipCustomBorder = false, tooltipBorderColor = "FFB2B2B2", tooltipBorderOpacity = 1,
}
for key, value in pairs(defaults) do assert(PyresinQoLDB[key] == value, key) end
local changes = {
    tooltipItemID = true, tooltipSpellIconID = true, tooltipItemStack = true, tooltipAnchor = "fixed",
    tooltipAnchorPoint = "TOPLEFT", tooltipAnchorX = 40, tooltipCustomBackground = true,
    tooltipBackgroundColor = "FF112233", tooltipBackgroundOpacity = 0.5, tooltipBorderOpacity = 0.25,
}
for key, value in pairs(changes) do
    settings[key]:SetValue(value)
    assert(PyresinQoLDB[key] == value)
end
assert(updates.tooltip == 43, "All tooltip controls apply live")
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(updates.tooltip == 73)
for key, value in pairs(defaults) do assert(PyresinQoLDB[key] == value, key) end
h.navigation[6].scripts.OnClick()
settings.xpTextFormat:SetValue("percent")
settings.xpAlwaysShow:SetValue(false)
settings.xpTooltip:SetValue(false)
settings.xpQuestRewards:SetValue(false)
assert(updates.experience == 4)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.xpTextFormat == "both" and PyresinQoLDB.xpAlwaysShow and PyresinQoLDB.xpTooltip and PyresinQoLDB.xpQuestRewards)
h.navigation[4].scripts.OnClick()
settings.cooldownShortcut:SetValue(true)
settings.showFPS:SetValue(false)
settings.showLatency:SetValue(false)
settings.performanceLayout:SetValue("row")
settings.performanceOrder:SetValue("latency")
settings.performanceColor:SetValue("FFFF0000")
settings.performanceRowPadding:SetValue(24)
settings.performanceColumnPadding:SetValue(9)
assert(not PyresinQoLDB.showFPS and not PyresinQoLDB.showLatency and updates.performance == 7)
assert(PyresinQoLDB.performanceRowPadding == 24 and PyresinQoLDB.performanceColumnPadding == 9)
h.hidden = nil
GameMenuFrame.shown = true
assert(h.combatEvents.registered.PLAYER_REGEN_DISABLED and h.combatEvents.registered.PLAYER_REGEN_ENABLED)
h.combatEvents.callback() -- Combat events before the menu first opens.
local button = BuildMenu()
assert(button.enabled)
for _ = 1, 3 do
    settings.cooldownShortcut:SetValue(true)
    assert(GameMenuFrame.height == 210 and GameMenuFrame.buttons[2].point[5] == -140,
        "Repeated updates must not accumulate height or offsets")
end
GameMenuFrame:Layout()
assert(GameMenuFrame.height == 210 and GameMenuFrame.buttons[2].point[5] == -140,
    "A fresh native layout must reserve exactly one row again")
button.scripts.OnEnter(button)
assert(not GameTooltip.shown)
h.combat = true
h.combatEvents.callback()
assert(not button.enabled, "Combat must disable an already visible button")
button.scripts.OnEnter(button)
assert(GameTooltip.shown and GameTooltip.error == ns.L.combat)
button.scripts.OnClick()
assert(not h.opened and not h.hidden, "Combat guard must also protect the click handler")
button = BuildMenu()
assert(not button.enabled, "Opening the menu in combat must disable the shortcut")
button.scripts.OnEnter(button)
h.combat = false
h.combatEvents.callback()
assert(button.enabled and not GameTooltip.shown)
button.scripts.OnClick()
assert(h.opened and h.hidden == GameMenuFrame and h.sound == SOUNDKIT.IG_MAINMENU_OPTION)
assert(not h.addonButton.shown, "Closing the menu must also hide its separate shortcut")
GameMenuFrame.shown = true
local nativeButtons, builds = GameMenuFrame.buttons, GameMenuFrame.builds
local optionsCallback, shopCallback = nativeButtons[1].scripts.OnClick, nativeButtons[2].scripts.OnClick
settings.cooldownShortcut:SetValue(false)
assert(#GameMenuFrame.buttons == 2 and GameMenuFrame.buttons[2].text == "Shop")
assert(not h.addonButton.shown)
assert(GameMenuFrame.height == 174 and GameMenuFrame.buttons[2].point[5] == -104,
    "Disabling the shortcut must restore native height and spacing")
h.opened, h.hidden = false, nil
button.scripts.OnClick()
assert(not h.opened and not h.hidden, "A stale shortcut must not open after disabling")
h.combatEvents.callback()
settings.cooldownShortcut:SetValue(true)
assert(h.addonButton.shown and h.addonButtonCount == 1)
assert(GameMenuFrame.buttons == nativeButtons and GameMenuFrame.builds == builds)
assert(nativeButtons[1].scripts.OnClick == optionsCallback and nativeButtons[2].scripts.OnClick == shopCallback)
assert(nativeButtons[1].layoutIndex == 1 and nativeButtons[2].layoutIndex == 2)
assert(h.combatEvents.registered.INPUT_DEVICE_INTERFACE_TRANSITION)
h.controller = true
h.combatEvents.callback(h.combatEvents, "INPUT_DEVICE_INTERFACE_TRANSITION")
assert(not h.addonButton.shown, "Controller menus must not expose an insecure window shortcut")
assert(GameMenuFrame.height == 174 and GameMenuFrame.buttons[2].point[5] == -104,
    "Controller mode must restore the native menu layout")
h.opened, h.hidden = false, nil
button.scripts.OnClick()
assert(not h.opened and not h.hidden, "Controller mode must also guard a stale shortcut click")
settings.cooldownShortcut:SetValue(true)
GameMenuFrame:InitButtons()
GameMenuFrame:Layout()
assert(not h.addonButton.shown, "Rebuilding the menu or settings must preserve controller suspension")
h.controller = false
h.combatEvents.callback(h.combatEvents, "INPUT_DEVICE_INTERFACE_TRANSITION")
assert(h.addonButton.shown and h.addonButtonCount == 1, "Leaving controller mode restores the saved shortcut")
GameMenuFrame.shown = false
GameMenuFrame.scripts.OnHide()
settings.cooldownShortcut:SetValue(true)
h.combatEvents.callback()
assert(not h.addonButton.shown, "Settings and combat events must not expose a shortcut for a closed menu")
GameMenuFrame.shown = true
for _ = 1, 10 do assert(BuildMenu() == h.addonButton) end
settings.cooldownShortcut:SetValue(false)
GameMenuFrame:InitButtons()
assert(not h.addonButton.shown and #GameMenuFrame.buttons == 2)
settings.pixelPerfectEditMode:SetValue(true)
PyresinQoLDB.performancePosition = { x = 11, y = 22 }
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.showFPS and PyresinQoLDB.showLatency and PyresinQoLDB.performanceLayout == "column")
assert(PyresinQoLDB.performanceRowPadding == 14 and PyresinQoLDB.performanceColumnPadding == 5)
assert(PyresinQoLDB.performanceColor == "FFFFFFFF" and PyresinQoLDB.performanceOrder == "fps")
assert(PyresinQoLDB.pixelPerfectEditMode and not PyresinQoLDB.cooldownShortcut, "Defaults affect only the selected page")
h.canvas.OnDefault()
assert(not PyresinQoLDB.pixelPerfectEditMode and PyresinQoLDB.cooldownShortcut)
assert(PyresinQoLDB.modules.quests == false, "Defaults restore opt-in modules to off")
settings.PyresinQoL_Module_quests:SetValue(true)
assert(PyresinQoLDB.performancePosition.x == 11 and PyresinQoLDB.performancePosition.y == 22)
-- Module switches share their value across overview and detail pages.
local unitFramesModule = settings.PyresinQoL_Module_unitFrames
assert(h.nativeThreatCheckbox:ShouldShow() and h.nativeThreatPosition:ShouldShow())
unitFramesModule:SetValue(false)
assert(h.nativeThreatCheckbox:ShouldShow() and h.nativeThreatPosition:ShouldShow(),
    "Native nameplate options must stay visible when the module is disabled")
assert(not h.nativeThreatCheckbox.modifyPredicate() and not h.nativeThreatPosition.modifyPredicate())
assert(h.nativeComboCheckbox:ShouldShow() and not h.nativeComboCheckbox.modifyPredicate())
unitFramesModule:SetValue(true)
assert(h.nativeThreatCheckbox:ShouldShow() and h.nativeThreatPosition:ShouldShow())
local reloaded = 0
function ReloadUI() reloaded = reloaded + 1 end
h.navigation[4].scripts.OnClick()
local before = updates.performance
local performanceModule = settings.PyresinQoL_Module_performance
performanceModule:SetValue(false)
assert(PyresinQoLDB.showFPS and PyresinQoLDB.showLatency, "Disabling preserves individual options")
assert(h.reloadButton.enabled and ns.ModulesNeedReload())
assert(h.navigation[4].text.value == ns.L.performance .. " *")
h.navigation[4].scripts.OnEnter()
assert(GameTooltip.shown and GameTooltip.line == ns.L.modulePending)
h.navigation[4].scripts.OnLeave()
assert(not GameTooltip.shown)
assert(not h.settingsList.initializers[1].modifyPredicate(), "Disabled module options must be locked")
assert(not h.settingsList.Header.DefaultsButton.enabled)
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(updates.performance == before, "Defaults must not change a disabled module")
settings.performanceLayout:SetValue("row")
assert(updates.performance == before, "Pending disabled modules must not apply option callbacks")
h.combat = true
h.canvas.scripts.OnEvent()
assert(not h.reloadButton.enabled)
h.reloadButton.scripts.OnClick()
assert(reloaded == 0, "Reload must be guarded in combat")
h.combat = false
h.canvas.scripts.OnEvent()
h.reloadButton.scripts.OnClick()
assert(reloaded == 1)
performanceModule:SetValue(true)
assert(not ns.ModulesNeedReload() and not h.reloadButton.enabled)
assert(h.settingsList.initializers[1].modifyPredicate())
assert(h.navigation[4].text.value == ns.L.performance)
-- Simulate a startup with this module disabled, then request activation.
ns.modules[3].active = false
performanceModule:SetValue(false)
assert(not ns.ModulesNeedReload() and h.navigation[4].text.color[1] == 0.5)
performanceModule:SetValue(true)
assert(ns.ModulesNeedReload() and not h.settingsList.initializers[1].modifyPredicate())
settings.performanceLayout:SetValue("column")
assert(updates.performance == before, "Unloaded modules must wait for reload")
ns.modules[3].active = true
performanceModule:SetValue(false)
h.navigation[1].scripts.OnClick()
h.settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.modules.performance and PyresinQoLDB.modules.quests == false and ns.ModulesNeedReload(),
    "Defaults switch the running opt-in Quests module off")
assert(PyresinQoLDB.performancePosition.x == 11, "Module defaults must preserve feature settings and position")
print("PASS: standalone settings/navigation, localized controls, collapse, defaults, migration, live callbacks and menu isolation")

-- A new group and multi-page module require only registration metadata.
local featureContext
local extraModule = { id = "navigationTest", name = "Navigation test", description = "Test feature",
    group = "navigationTest", active = true,
    pages = { { id = "main", name = "Test main" }, { id = "details", name = "Test details" } },
    buildSettings = function(_, context) featureContext = context end,
}
ns.modules[#ns.modules + 1] = extraModule
ns.settingsGroups[#ns.settingsGroups + 1] = { id = "navigationTest", name = "Test group" }
PyresinQoLDB.modules.navigationTest = true
h.launcher, h.closeButton = nil, nil
h.navigation, h.groupButtons = {}, {}
ns.InitializeSettings()
local detailButton = NavigationButton("Test details")
detailButton.scripts.OnClick()
assert(h.settingsList.Header.Title.value == "Test details"
    and h.settingsList.initializers == featureContext.pages.details.initializers)
assert(featureContext.pages.main.module == extraModule and featureContext.pages.details.module == extraModule)
h.groupButtons[5].scripts.OnClick()
assert(not detailButton.shown and not NavigationButton("Test main").shown)
assert(NavigationButton(ns.L.performance).shown, "Group collapse must preserve unrelated pages")
print("PASS: metadata-defined groups, subpages and settings-builder contexts")

-- Automatic profiles must refresh real registered controls and their callbacks.
function UnitGUID() return "Player-settings" end
Enum = { EditModeLayoutType = { Account = 1, Character = 2 }, EditModePresetLayoutsMeta = { NumValues = 3 } }
local layoutInfo = { activeLayout = 4, layouts = {
    { layoutType = 1, layoutName = "Original layout" }, { layoutType = 1, layoutName = "Other layout" },
} }
C_EditMode = { GetLayouts = function() return CopyTable(layoutInfo) end }
ns.SyncLayoutProfile()
local originalProfile = PyresinQoLDB.profileStore.active
local root, moduleTable = PyresinQoLDB, PyresinQoLDB.modules
local originalFPS = settings.showFPS:GetValue()
layoutInfo.activeLayout = 5
ns.SyncLayoutProfile()
settings.showFPS:SetValue(not originalFPS)
settings.targetClassColor:SetValue(true)
settings.castBarCustomization:SetValue(true)
settings.actionBarBar2AlphaNormal:SetValue(.37)
ns.CastBar.Set("customColor", { r = .2, g = .4, b = .6 })
local beforePerformance, beforeTooltips = updates.performance, updates.tooltip
layoutInfo.activeLayout = 4
ns.SyncLayoutProfile()
assert(PyresinQoLDB == root and PyresinQoLDB.modules == moduleTable)
assert(settings.showFPS:GetValue() == originalFPS and updates.performance > beforePerformance)
assert(updates.tooltip > beforeTooltips and PyresinQoLDB.profileStore.active == originalProfile)
assert(not ns.CastBar.IsEnabled() and ns.CastBar.Get("customColor").r == 1)
assert(settings.actionBarBar2AlphaNormal:GetValue() == 1,
    "Moving per-bar controls to Edit Mode preserves default values during profile switches")
layoutInfo.activeLayout = 5
ns.SyncLayoutProfile()
assert(settings.showFPS:GetValue() == not originalFPS and settings.targetClassColor:GetValue())
assert(ns.CastBar.IsEnabled() and ns.CastBar.Get("customColor").r == .2)
assert(settings.actionBarBar2AlphaNormal:GetValue() == .37,
    "Edit Mode action-bar settings still belong to the active addon profile")
settings.PyresinQoL_Module_performance:SetValue(false)
layoutInfo.activeLayout = 4
ns.SyncLayoutProfile()
layoutInfo.activeLayout = 5
ns.SyncLayoutProfile()
assert(not settings.PyresinQoL_Module_performance:GetValue() and h.reloadButton.enabled and ns.ModulesNeedReload())
print("PASS: automatic profiles preserve registered settings, refresh callbacks/cast-bar overrides and expose pending module reloads")
