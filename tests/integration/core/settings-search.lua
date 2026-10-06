-- Run from the addon directory: luajit tests/integration/core/settings-search.lua [disabled|de|modules-disabled]
local h = assert(loadfile("tests/support/settings.lua"))(arg[1])
local ns, settings = h.ns, h.settings
local NavigationButton = h.NavigationButton

-- Search reuses the registered controls, including deferred and disabled modules.
local search = assert(h.canvas.SearchBox)
local function SearchSetting(key)
    for _, initializer in ipairs(h.settingsList.initializers) do
        if initializer.data.setting == settings[key] then return initializer end
    end
end
local function AssertOneRefresh(action)
    local before = h.settingsList.displayCount or 0
    action()
    local count = h.settingsList.displayCount - before
    assert(count == 1, "Expected one settings list rebuild, got " .. count)
end
AssertOneRefresh(function() NavigationButton(ns.L.modules).scripts.OnClick() end)
AssertOneRefresh(function() NavigationButton(ns.L.modules).scripts.OnClick() end)
assert(search.parent == h.canvas and search.maxBytes == 64)
search:SetText("  \t  ")
assert(h.settingsList.Header.Title.value == ns.L.modules and h.settingsList.Header.DefaultsButton.shown)
search:SetText(ns.L.playerClassColor:lower())
assert(h.settingsList.Header.Title.value == SETTINGS_SEARCH_RESULTS and not h.settingsList.Header.DefaultsButton.shown)
assert(SearchSetting("playerClassColor") and SearchSetting("targetClassColor"), "Search must span pages")
assert(SearchSetting("playerClassColor").modifyPredicate() == ns.GetModule("unitFrames").active)
assert(not h.navigation[1].selected.shown)
local searchModule = settings.PyresinQoL_Module_unitFrames
local originalSearchModule = searchModule:GetValue()
searchModule:SetValue(not originalSearchModule)
assert(search:GetText() == ns.L.playerClassColor:lower() and h.settingsList.Header.Title.value == SETTINGS_SEARCH_RESULTS,
    "Module changes must refresh results without ending the search")
assert(not SearchSetting("playerClassColor").modifyPredicate())
searchModule:SetValue(originalSearchModule)
search:SetText(ns.L.nameplateThreat:lower())
assert(SearchSetting("nameplateThreat"), "Late-registered settings must be searchable")
search:SetText(ns.L.questItemSparkles:upper())
local sparkleControl = assert(SearchSetting("questItemSparkles"), "Search must accept case-insensitive localized labels")
sparkleControl:AddShownPredicate(function() return false end)
h.canvas.OnRefresh()
assert(not SearchSetting("questItemSparkles"), "Search must respect native visibility predicates")
sparkleControl.predicate = nil
search:SetText(arg[1] == "de" and "vollständigen" or "full game restart")
assert(SearchSetting("questItemSparkles"), "Help text must be searchable")
search:SetText(ns.L.castBarConfigure:lower())
local foundAction = false
for _, initializer in ipairs(h.settingsList.initializers) do
    if initializer:GetName() == ns.L.castBarConfigure then foundAction = true end
end
assert(foundAction, "Edit Mode actions must be searchable")
AssertOneRefresh(function() h.navigation[4].scripts.OnClick() end)
assert(search:GetText() == "" and h.settingsList.Header.Title.value == ns.L.performance)
search:SetText("[]%.")
assert(#h.settingsList.rendered == 1 and h.settingsList.rendered[1].Title.value == SETTINGS_SEARCH_NOTHING_FOUND,
    "Search punctuation must be literal, not a Lua pattern")
h.canvas.scripts.OnEvent()
assert(not h.settingsList.Header.DefaultsButton.shown, "Combat events must not restore Defaults during search")
AssertOneRefresh(function() search.scripts.OnEscapePressed(search) end)
assert(search:GetText() == "" and h.settingsList.Header.Title.value == ns.L.performance
    and h.settingsList.Header.DefaultsButton.shown, "Escape restores the previous page")
h.groupButtons[2].scripts.OnClick()
assert(not NavigationButton(ns.L.playerFrame).shown)
search:SetText(ns.L.playerClassColor:lower())
local playerHeader
for _, row in ipairs(h.settingsList.rendered) do
    if row.Title and row.Title.value == ns.L.unitFrames .. " > " .. ns.L.playerFrame then playerHeader = row end
end
assert(playerHeader and playerHeader.scripts.OnClick)
AssertOneRefresh(function() playerHeader.scripts.OnClick() end)
assert(search:GetText() == "" and NavigationButton(ns.L.playerFrame).shown
    and NavigationButton(ns.L.playerFrame).selected.shown, "Result links expand and select their original page")
search:SetText(ns.L.auraSize:lower())
local buffSection, debuffSection = false, false
for _, row in ipairs(h.settingsList.rendered) do
    if row.Title then
        buffSection = buffSection or row.Title.value == ns.L.buffAuras
        debuffSection = debuffSection or row.Title.value == ns.L.debuffAuras
    end
end
assert(buffSection and debuffSection, "Search results must retain section context for identical aura labels")
AssertOneRefresh(function() NavigationButton(ns.L.profiles).scripts.OnClick() end)
search:SetText(ns.L.profiles)
assert(not h.profilePanel.shown and not h.settingsList.Header.DefaultsButton.shown)
for _, row in ipairs(h.settingsList.rendered) do
    if row.Title and row.Title.value == ns.L.profiles then
        AssertOneRefresh(function() row.scripts.OnClick() end)
        break
    end
end
assert(h.profilePanel.shown and search:GetText() == "", "Profiles must be reachable from search")
search:SetText("[]%.")
h.canvas.scripts.OnHide()
assert(search:GetText() == "" and h.profilePanel.shown, "Closing clears search while retaining the selected page")
AssertOneRefresh(function() h.navigation[1].scripts.OnClick() end)
print("PASS: global localized settings search, help/actions, deferred/disabled controls, section context and result navigation")

-- Automatic profiles update the same registered result controls, without clearing the query.
function UnitGUID() return "Player-search" end
Enum = { EditModeLayoutType = { Account = 1, Character = 2 }, EditModePresetLayoutsMeta = { NumValues = 3 } }
local layoutInfo = { activeLayout = 4, layouts = {
    { layoutType = 1, layoutName = "Original layout" }, { layoutType = 1, layoutName = "Other layout" },
} }
C_EditMode = { GetLayouts = function() return CopyTable(layoutInfo) end }
ns.SyncLayoutProfile()
local root, moduleTable = PyresinQoLDB, PyresinQoLDB.modules
local originalProfile = PyresinQoLDB.profileStore.active
local originalFPS = settings.showFPS:GetValue()
local originalModule = settings.PyresinQoL_Module_performance:GetValue()
search:SetText("FPS")
local fpsControl = assert(SearchSetting("showFPS"))
layoutInfo.activeLayout = 5
ns.SyncLayoutProfile()
settings.showFPS:SetValue(not originalFPS)
settings.PyresinQoL_Module_performance:SetValue(not originalModule)
local beforeUpdates = h.updates.performance
layoutInfo.activeLayout = 4
ns.SyncLayoutProfile()
assert(PyresinQoLDB == root and PyresinQoLDB.modules == moduleTable)
assert(PyresinQoLDB.profileStore.active == originalProfile and settings.showFPS:GetValue() == originalFPS)
assert(search:GetText() == "FPS" and h.settingsList.Header.Title.value == SETTINGS_SEARCH_RESULTS)
assert(SearchSetting("showFPS") == fpsControl and fpsControl.data.setting:GetValue() == originalFPS)
if ns.GetModule("performance").active then
    assert(h.updates.performance > beforeUpdates, "Profile refresh must notify active modules")
else
    assert(h.updates.performance == beforeUpdates, "Profile refresh must not invoke disabled modules")
end
assert(not ns.ModulesNeedReload())
layoutInfo.activeLayout = 5
ns.SyncLayoutProfile()
assert(search:GetText() == "FPS" and SearchSetting("showFPS") == fpsControl)
assert(fpsControl.data.setting:GetValue() == not originalFPS)
assert(settings.PyresinQoL_Module_performance:GetValue() == not originalModule)
assert(ns.ModulesNeedReload() and h.reloadButton.enabled and not fpsControl.modifyPredicate())
print("PASS: active search survives profile switches, refreshes registered values/callbacks and preserves module locking")
