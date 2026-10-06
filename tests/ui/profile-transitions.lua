local UI = PyresinQoLUITest
local original, originalLayout, nextLayout, preview, castSetting
local profileName = "UI transition incoming"
local originalSparkleCVars = {}
local function SwitchLayout(index)
    C_EditMode.SetActiveLayout(index)
    -- The pinned simulator's native EDIT_MODE_LAYOUTS_UPDATED handler cannot
    -- rebuild layouts. Specialization changes also synchronize linked profiles,
    -- and let this flow exercise real addon callbacks/native cast-bar controls.
    A_Admin.FireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
end
local function Snapshot()
    local result = {}
    for key, value in pairs(PyresinQoLDB) do
        if key ~= "profileStore" then result[key] = type(value) == "table" and CopyTable(value) or value end
    end
    return result
end
UI.Flow("Profiles: layout-linked profile sync on specialization event refreshes active cast and native editor", {
    function(_, sidebar, list)
        preview = nil
        original = CopyTable(PyresinQoLDB)
        for _, name in ipairs({ "outlineModeShowLootEffectWhenDisabled", "graphicsOutlineMode", "OutlineEngineMode",
            "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" }) do
            originalSparkleCVars[name] = C_CVar.GetCVar(name)
        end
        Settings.GetSetting("PyresinQoL_QuestItemSparkles"):SetValue(true)
        originalLayout = C_EditMode.GetLayouts().activeLayout
        nextLayout = originalLayout == 1 and 2 or 1
        local store, character = PyresinQoLDB.profileStore, UnitGUID("player")
        assertNil(store.profiles[profileName])
        local incoming = Snapshot()
        incoming.castBarCustomization = true
        incoming.castBar = { width = 280, colorMode = "custom", customColor = { r = .3, g = .4, b = .5 } }
        incoming.showFPS = false
        incoming.questItemSparkles = false
        store.profiles[profileName] = incoming
        store.characterBindings[character]["preset:" .. nextLayout] = profileName
        store.profileLayouts[character][profileName] = "preset:" .. nextLayout
        PyresinQoLDB.castBar = { width = 220, colorMode = "custom", customColor = { r = .1, g = .2, b = .3 } }
        castSetting = Settings.GetSetting("PyresinQoL_CastBarCustomization")
        castSetting:SetValue(true)
        castSetting:NotifyUpdate()
        UI.PageButton(sidebar, "Player Frame"):Click()
        list:ScrollToElementByName("Configure in Edit Mode")
    end,
    function(_, _, list) UI.Click(UI.Button(list, "Configure in Edit Mode"), list.ScrollBox, "Configure cast bar") end,
    function()
        local _, row = UI.Checkbox(EditModeSystemSettingsDialog, "Customize cast bar")
        preview = assert(UI.Find(row:GetParent(), function(f) return f.progress and f.name and f.time end))
        assertTrue(preview:IsVisible())
        assertEquals(220, preview.fill:GetWidth())
        A_Admin.SetCasting(990051, "Profile transition cast", "Interface/Icons/Spell_Arcane_Blast", 60)
        A_Admin.FireEvent("UNIT_SPELLCAST_START", "player", "ProfileTransitionCast", 990051)
    end,
    function()
        assertTrue(PlayerCastingBarFrame:IsVisible())
        assertEquals("Profile transition cast", PlayerCastingBarFrame.Text:GetText())
        SwitchLayout(nextLayout)
    end,
    function()
        assertEquals(profileName, PyresinQoLDB.profileStore.active)
        assertEquals(false, Settings.GetSetting("PyresinQoL_ShowFPS"):GetValue())
        assertFalse(Settings.GetSetting("PyresinQoL_QuestItemSparkles"):GetValue())
        assertEquals("0", C_CVar.GetCVar("outlineModeShowLootEffectWhenDisabled"))
        assertEquals("2", C_CVar.GetCVar("graphicsOutlineMode"))
        assertEquals("2", C_CVar.GetCVar("RAIDOutlineEngineMode"))
        assertEquals(280, PlayerCastingBarFrame:GetWidth())
        assertTrue(preview:IsVisible())
        assertEquals(280, preview.fill:GetWidth())
        local r, g, b = preview.progress:GetVertexColor()
        assertAlmostEquals(.3, r); assertAlmostEquals(.4, g); assertAlmostEquals(.5, b)
        assertEquals("Profile transition cast", PlayerCastingBarFrame.Text:GetText())
        A_Admin.StopCasting()
        A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "player", "ProfileTransitionCast", 990051)
    end,
    function()
        assertEquals(profileName, PyresinQoLDB.profileStore.active)
        assertEquals(280, preview.fill:GetWidth())
    end,
}, function()
    A_Admin.StopCasting()
    A_Admin.FireEvent("UNIT_SPELLCAST_STOP", "player", "ProfileTransitionCast", 990051)
    ColorPickerFrame:Hide()
    HideUIPanel(EditModeManagerFrame)
    if original then
        local modules = PyresinQoLDB.modules
        for key in pairs(PyresinQoLDB) do PyresinQoLDB[key] = nil end
        for key, value in pairs(original) do PyresinQoLDB[key] = value end
        for key in pairs(modules) do modules[key] = nil end
        for key, value in pairs(original.modules) do modules[key] = value end
        PyresinQoLDB.modules = modules
        SwitchLayout(originalLayout)
        for _, variable in ipairs({ "CastBarCustomization", "ShowFPS", "ShowLatency", "QuestItemSparkles" }) do
            Settings.GetSetting("PyresinQoL_" .. variable):NotifyUpdate()
        end
        -- The live callback canonicalizes false to nil; preserve the exact saved
        -- representation after restoring the native presentation.
        PyresinQoLDB.castBarCustomization = original.castBarCustomization
        EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged")
    end
    PyresinQoLSettingsFrame:Hide()
    StaticPopup_Hide("PYRESINQOL_QUEST_SPARKLES_RESTART")
    for name, value in pairs(originalSparkleCVars) do C_CVar.SetCVar(name, value) end
end)
