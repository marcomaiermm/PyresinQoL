-- luajit tests/integration/core/profiles.lua
local combat, dirty, reloads = false, false, 0
function GetLocale() return arg[1] == "de" and "deDE" or "enUS" end
function InCombatLockdown() return combat end
function UnitGUID() return nil end
function UnitName() return "Test character" end
function ReloadUI() reloads = reloads + 1 end
function strlenutf8(value)
    local _, count = value:gsub("[^\128-\191]", "")
    return count
end
function CopyTable(value)
    local result = {}
    for key, item in pairs(value) do result[key] = type(item) == "table" and CopyTable(item) or item end
    return result
end
local function Namespace()
    local ns = {}
    for _, path in ipairs({ "Core/Localization.lua", "Core/Locales/deDE.lua", "Core/Profiles.lua", "Core/Database.lua", "Core/Modules.lua", "Modules/CastBar/Config.lua" }) do
        assert(loadfile(path))("PyresinQoL", ns)
    end
    return ns
end
local ns = Namespace()
local original = { modules = { performance = false }, showPerformance = false,
    targetThreat = false, performancePosition = { x = 12, y = -34 },
    castBar = { layout = "compact", customColor = { r = .1, g = .2, b = .3 } }, custom = "keep" }
PyresinQoLDB = original
ns.InitializeProfiles()
ns.InitializeDatabase()
local store = PyresinQoLDB.profileStore
assert(PyresinQoLDB == original and store.active == "Default" and store.profiles.Default)
assert(PyresinQoLDB.showFPS == false and PyresinQoLDB.targetThreat == "off")
assert(PyresinQoLDB.performancePosition.x == 12 and PyresinQoLDB.custom == "keep")
ns.InitializeProfiles()
assert(PyresinQoLDB.profileStore == store, "Startup must be idempotent")
for _, name in ipairs({ "", "  ", "Default", ns.L.profileDefault, "x|y", "x\ny", string.rep("x", 33) }) do
    assert(not ns.CreateProfile(name), "Invalid or duplicate name accepted: " .. name)
end
assert(ns.CreateProfile("  Raid  ") and store.active == "Raid" and reloads == 0)
assert(not ns.CreateProfile("Raid"))
assert(store.profiles.Raid.modules ~= store.profiles.Default.modules)
assert(store.profiles.Raid.castBar.customColor ~= store.profiles.Default.castBar.customColor)
assert(not store.profiles.Raid.profileStore, "Snapshots must never contain their own registry")
PyresinQoLDB.modules.performance = true
PyresinQoLDB.castBar.customColor.r = .9
PyresinQoLDB.performancePosition.x = 200
PyresinQoLDB.raidOnly = true
assert(store.profiles.Default.modules.performance == false and store.profiles.Default.castBar.customColor.r == .1)
assert(not ns.DeleteProfile("Raid") and not ns.DeleteProfile("Default"))
assert(not ns.RenameProfile("Default", "Other") and not ns.RenameProfile("Raid", "Default"))
assert(ns.RenameProfile("Raid", "Raid") and ns.RenameProfile("Raid", "Raids"))
assert(store.active == "Raids" and store.profiles.Raids and not store.profiles.Raid)

EditModeManagerFrame = {
    LayoutDropdown = {}, IsShown = function() return true end,
    HasActiveChanges = function() return dirty end,
}
dirty = true
assert(not ns.SwitchProfile("Default") and not store.pending and reloads == 0)
dirty, combat = false, true
assert(not ns.SwitchProfile("Default") and not ns.CreateProfile("Combat")
    and not ns.RenameProfile("Raids", "Combat") and not ns.DeleteProfile("Raids"))
combat = false
assert(not ns.SwitchProfile("missing") and ns.SwitchProfile("Raids") and reloads == 0)
assert(ns.SwitchProfile("Default") and reloads == 1 and store.pending == "Default")
assert(store.active == "Raids" and PyresinQoLDB.raidOnly,
    "A requested switch must leave running modules and registered controls on the outgoing settings")
PyresinQoLDB.performancePosition.y = 99 -- Simulate an outgoing logout write.
PyresinQoLDB = CopyTable(PyresinQoLDB) -- SavedVariables reconstructed in a new runtime.
ns = Namespace()
ns.InitializeProfiles()
ns.InitializeDatabase()
ns.InitializeModules()
store = PyresinQoLDB.profileStore
assert(store.active == "Default" and store.pending == nil and not PyresinQoLDB.raidOnly)
assert(PyresinQoLDB.modules.performance == false and not ns.GetModule("performance").active)
assert(PyresinQoLDB.performancePosition.x == 12 and PyresinQoLDB.performancePosition.y == -34)
assert(ns.CastBar.Get("layout") == "compact" and ns.CastBar.Get("customColor").r == .1)
assert(ns.SwitchProfile("Raids") and reloads == 2)
ns.InitializeProfiles()
ns.InitializeDatabase()
ns.InitializeModules()
assert(store.active == "Raids" and ns.GetModule("performance").active and PyresinQoLDB.raidOnly)
assert(PyresinQoLDB.performancePosition.x == 200 and PyresinQoLDB.performancePosition.y == 99)
assert(ns.CastBar.Get("customColor").r == .9)
assert(ns.CreateProfile("Solo") and ns.DeleteProfile("Raids"))
assert(table.concat(ns.GetProfileNames(), ",") == "Default,Solo")
assert(ns.CreateProfile(string.rep("ä", 32)), "The name limit counts characters, not bytes")
print("PASS: migration, complete isolated profiles, validation, rename/delete, guarded switching and reconstructed reloads")

-- Exercise the real dropdown generators and popup callbacks on native-shaped controls.
local callbacks, dropdowns, buttons, popup = {}, {}, {}, nil
EventRegistry = {}
function EventRegistry:RegisterCallback(event, callback)
    callbacks[event] = callbacks[event] or {}
    callbacks[event][#callbacks[event] + 1] = callback
end
function EventRegistry:TriggerEvent(event)
    for _, callback in ipairs(callbacks[event] or {}) do callback() end
end
ACCEPT, CANCEL, DELETE = "Accept", "Cancel", "Delete"
StaticPopupDialogs = {}
UIErrorsFrame = { AddMessage = function(self, message) self.message = message end }
GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end,
    Show = function() end, Hide = function() end }
local function Description(kind, text, click, selected)
    local entry = { kind = kind, text = text, click = click, selected = selected, children = {}, enabled = true }
    function entry:SetEnabled(value) self.enabled = value end
    function entry:SetScrollMode() end
    function entry:CreateTitle(value) return self:CreateButton(value) end
    function entry:CreateDivider() end
    function entry:CreateButton(value, handler)
        local child = Description("button", value, handler)
        self.children[#self.children + 1] = child
        return child
    end
    function entry:CreateRadio(value, isSelected, handler)
        local child = Description("radio", value, handler, isSelected)
        self.children[#self.children + 1] = child
        return child
    end
    return entry
end
local function Widget(parent)
    local widget = { parent = parent, scripts = {}, events = {} }
    function widget:SetWidth(value) self.width = value end
    function widget:SetSize(width, height) self.width, self.height = width, height end
    function widget:SetPoint(...) self.point = { ... } end
    function widget:ClearAllPoints() self.point = nil end
    function widget:SetJustifyH() end
    function widget:SetWordWrap() end
    function widget:SetText(value) self.text = value end
    function widget:SetDefaultText(value) self.defaultText = value end
    function widget:CreateFontString() return Widget(self) end
    function widget:SetupMenu(generator) self.generator = generator end
    function widget:GenerateMenu()
        self.menu = Description("root")
        self.generator(self, self.menu)
    end
    function widget:SetEnabled(value) self.enabled = value end
    function widget:RegisterEvent(event) self.events[event] = true end
    function widget:SetScript(event, callback) self.scripts[event] = callback end
    return widget
end
function CreateFrame(kind, _, parent, template)
    local widget = Widget(parent)
    if kind == "DropdownButton" then
        assert(template == "WowStyle1DropdownTemplate")
        for _, event in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            widget.scripts[event] = function() widget[event] = true end
        end
        dropdowns[#dropdowns + 1] = widget
    elseif kind == "Button" then
        assert(template == "UIPanelButtonTemplate")
        buttons[#buttons + 1] = widget
    else
        assert(kind == "Frame" and template == nil)
    end
    return widget
end
function StaticPopup_Show(which, _, _, data)
    local info = assert(StaticPopupDialogs[which])
    popup = { which = which, data = data, shown = true, text = {}, input = {}, button = {} }
    local dialog = popup
    function dialog:GetEditBox() return self.input end
    function dialog:GetButton1() return self.button end
    function dialog:GetTextFontString() return self.text end
    function dialog:Hide() self.shown = false end
    function dialog.text:SetText(value) self.value = value end
    function dialog.button:SetEnabled(value) self.enabled = value end
    function dialog.button:IsEnabled() return self.enabled end
    function dialog.button:Click()
        if not info.OnAccept(dialog, data) then dialog:Hide() end
    end
    function dialog.input:SetMaxLetters(value) self.maxLetters = value end
    function dialog.input:GetParent() return dialog end
    function dialog.input:GetText() return self.value end
    function dialog.input:SetText(value)
        self.value = value
        info.EditBoxOnTextChanged(self, data)
    end
    function dialog.input:HighlightText() end
    function dialog.input:SetFocus() end
    if info.OnShow then info.OnShow(dialog, data) end
    return dialog
end
local function Entry(dropdown, text)
    for _, entry in ipairs(dropdown.menu.children) do if entry.text == text then return entry end end
    error("Missing menu entry: " .. text)
end
local page = ns.CreateProfilesPage({})
local settings, layoutDropdown, deleteDropdown = dropdowns[1], dropdowns[2], dropdowns[3]
local create, rename, delete = buttons[1], buttons[2], buttons[3]
assert(#dropdowns == 3 and #buttons == 3 and settings.parent == page)
assert(create.text == ns.L.profileCreate and rename.text == ns.L.profileRenameButton)
assert(not layoutDropdown.enabled, "Layout assignment waits for native layout data")
for _, event in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
    settings.scripts[event]()
    assert(settings[event], "Preserve the template's native " .. event .. " script")
end
EventRegistry:TriggerEvent("EditMode.Enter")
assert(#dropdowns == 3, "Edit Mode must not contain QoL profile controls")
assert(not pcall(Entry, settings, ns.L.profileNew), "The profile selector only lists profiles")
create.scripts.OnClick()
assert(not popup.button.enabled and popup.input.maxLetters == 32)
popup.input:SetText("  UI copy  ")
assert(popup.button.enabled)
StaticPopupDialogs[popup.which].EditBoxOnEnterPressed(popup.input)
assert(not popup.shown and store.active == "UI copy" and Entry(settings, "UI copy").selected())
rename.scripts.OnClick()
popup.input:SetText("UI renamed")
popup.button:Click()
assert(store.active == "UI renamed" and Entry(settings, "UI renamed").selected())
local radio = Entry(settings, ns.L.profileDefault)
radio.click()
local before = reloads
popup:Hide() -- Canceling must not stage a switch.
assert(not store.pending and store.active == "UI renamed" and reloads == before)
dirty = true
settings:GenerateMenu()
assert(not Entry(settings, ns.L.profileDefault).enabled)
dirty = false
radio.click()
dirty = true -- Layout changed after the confirmation opened.
popup.button:Click()
assert(popup.shown and reloads == before and UIErrorsFrame.message == ns.L.profileUnsavedLayout)
dirty, combat = false, true
popup.button:Click()
assert(reloads == before and UIErrorsFrame.message == ns.L.combat and not store.pending)
page.scripts.OnEvent()
assert(not settings.enabled and not create.enabled and not rename.enabled and not delete.enabled)
combat = false
page.scripts.OnEvent()
assert(settings.enabled and create.enabled and rename.enabled)
popup:Hide()
assert(delete.enabled and #deleteDropdown.menu.children > 0)
assert(not pcall(Entry, deleteDropdown, ns.L.profileDefault))
assert(not pcall(Entry, deleteDropdown, "UI renamed"))
deleteDropdown.menu.children[1].click()
delete.scripts.OnClick()
local deleted = popup.data
popup.button:Click()
assert(not popup.shown and not store.profiles[deleted])
assert(Entry(settings, "UI renamed").selected())
print("PASS: profile page, separate actions, protected deletion, untouched Edit Mode and guarded dialogs")

-- Drive the actual bootstrap with native layout events and deferred refreshes.
local character, shown = "Player-1", true
function UnitGUID() return character end
Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 },
    EditModePresetLayoutsMeta = { NumValues = 3 } }
EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function()
    return { { layoutName = "Modern" }, { layoutName = "Classic" }, { layoutName = "Gamepad" } }
end }
local info = { activeLayout = 4, layouts = {
    { layoutType = 1, layoutName = "Raid UI" }, { layoutType = 1, layoutName = "Solo UI" },
    { layoutType = 2, layoutName = "Raid UI" },
} }
C_EditMode = { GetLayouts = function() return CopyTable(info) end,
    SetActiveLayout = function() error("QoL profiles must not change the native layout") end,
    SaveLayouts = function() error("QoL profiles must not write native layouts") end,
}
EditModeManagerFrame.IsShown = function() return shown end
local queued = {}
C_Timer = { After = function(delay, callback)
    assert(delay == 0)
    queued[#queued + 1] = callback
end }
local function Flush()
    local pending = queued
    queued = {}
    for _, callback in ipairs(pending) do callback() end
end
local core
local createDropdown = CreateFrame
function CreateFrame(kind, ...)
    if kind ~= "Frame" then return createDropdown(kind, ...) end
    core = { events = {} }
    function core:RegisterEvent(event) self.events[event] = true end
    function core:UnregisterEvent(event) self.events[event] = nil end
    function core:SetScript(_, callback) self.callback = callback end
    return core
end
local refreshes, positions, dragStops = 0, 0, 0
-- Every custom Edit Mode display stops its drag and takes the new profile's position.
table.insert(ns.customEditModeDisplays, { StopDragging = function() dragStops = dragStops + 1 end,
    Restore = function() positions = positions + 1 end })
function ns.InitializeSettings()
    function ns.RefreshProfileSettings() refreshes = refreshes + 1 end
end
assert(loadfile("Core/Bootstrap.lua"))("PyresinQoL", ns)
core.callback(core, "ADDON_LOADED", "PyresinQoL")
assert(core.events.EDIT_MODE_LAYOUTS_UPDATED and core.events.PLAYER_REGEN_ENABLED)
assert(not ns.currentLayoutKey, "Layouts are not guaranteed before login; startup keeps the last active profile")
core.callback(core, "PLAYER_LOGIN")
Flush()
local root, moduleTable = PyresinQoLDB, PyresinQoLDB.modules
local raidProfile = store.active
local raidKey = ns.currentLayoutKey
assert(raidKey == "account:1:Raid UI" and store.characterBindings[character][raidKey] == raidProfile)
PyresinQoLDB.custom = "raid"
ColorPickerFrame = { shown = true, IsShown = function(self) return self.shown end,
    Hide = function(self) self.shown = false end }
info.activeLayout = 5
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
core.callback(core, "PLAYER_SPECIALIZATION_CHANGED")
assert(#queued == 1 and store.active == raidProfile, "Coalesce events; never apply inside Blizzard's synchronous dispatch")
Flush()
local soloProfile = store.active
assert(soloProfile == "Solo UI" and PyresinQoLDB.custom == "raid" and dragStops == 1)
assert(not ColorPickerFrame.shown, "Close picker callbacks from the outgoing profile")
assert(store.profiles[raidProfile].custom == "raid")
PyresinQoLDB.custom = "solo"
PyresinQoLDB.castBar = { customColor = { r = .5, g = .6, b = .7 } }
PyresinQoLDB.performancePosition = { x = 1000, y = 200 }
local beforeReload = reloads
info.activeLayout = 4
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == raidProfile and PyresinQoLDB.custom == "raid" and refreshes == 1 and positions == 1)
assert(PyresinQoLDB == root and PyresinQoLDB.modules == moduleTable,
    "Keep native settings' saved-table references valid during a live switch")
assert(reloads == beforeReload and not ns.profileReloadPending and #dropdowns == 3)
info.activeLayout = 5
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(PyresinQoLDB.custom == "solo" and ns.CastBar.Get("customColor").r == .5)
assert(PyresinQoLDB.performancePosition.x == 1000)

-- Rename carries the binding; deletion shifts indices without changing it.
info.layouts[2].layoutName = "Solo renamed"
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == soloProfile and ns.currentLayoutName == "Solo renamed")
assert(store.characterBindings[character]["account:1:Solo renamed"] == soloProfile
    and not store.characterBindings[character]["account:1:Solo UI"])
table.remove(info.layouts, 1)
info.activeLayout = 4
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == soloProfile and PyresinQoLDB.custom == "solo")

-- A delete/add burst must not masquerade as a rename in the deferred refresh.
table.remove(info.layouts, 2)
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
table.insert(info.layouts, { layoutType = 1, layoutName = "Replacement" })
info.activeLayout = 5
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == "Replacement" and PyresinQoLDB.custom == "solo")
assert(store.characterBindings[character][raidKey] == raidProfile, "Deleting a Blizzard layout must not destroy its addon profile")

-- Character layouts with the same name remain independent from account layouts.
table.insert(info.layouts, { layoutType = 2, layoutName = "Raid UI" })
info.activeLayout = 6
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
local characterProfile = store.active
assert(store.characterBindings[character]["Player-1:2:Raid UI"] == characterProfile and characterProfile ~= raidProfile)
PyresinQoLDB.custom = "character one"
character = "Player-2"
core.callback(core, "PLAYER_LOGIN")
Flush()
assert(store.active ~= characterProfile and store.characterBindings[character]["Player-2:2:Raid UI"] == store.active)
PyresinQoLDB.custom = "character two"
character = "Player-1"
core.callback(core, "PLAYER_LOGIN")
Flush()
assert(store.active == characterProfile and PyresinQoLDB.custom == "character one")

info.activeLayout = 1
combat = true
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == characterProfile and PyresinQoLDB.custom == "character one")
combat = false
core.callback(core, "PLAYER_REGEN_ENABLED")
Flush()
assert(store.active == "Modern" and store.characterBindings[character]["preset:1"] == "Modern")
PyresinQoLDB.custom = "modern"
info.activeLayout = 6
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(PyresinQoLDB.custom == "character one")

-- Module changes offer a reload only after leaving Edit Mode, with a combat guard.
store.profiles.Modern.modules.performance = false
info.activeLayout = 1
local oldPopup = popup
core.callback(core, "EDIT_MODE_LAYOUTS_UPDATED")
Flush()
assert(store.active == "Modern" and ns.ModulesNeedReload() and ns.profileReloadPending and popup == oldPopup)
assert(reloads == beforeReload, "Automatic layout switching must not force a UI reload")
shown = false
ns.MaybePromptProfileReload()
assert(popup.which == "PYRESINQOL_PROFILE_RELOAD")
combat = true
popup.button:Click()
assert(popup.shown and reloads == beforeReload)
combat = false
popup.button:Click()
assert(reloads == beforeReload + 1)

assert(ns.CreateProfile("Manual binding") and store.characterBindings[character]["preset:1"] == "Manual binding")
assert(ns.RenameProfile("Manual binding", "Manual renamed") and store.characterBindings[character]["preset:1"] == "Manual renamed")
assert(ns.SwitchProfile("Default") and store.characterBindings[character]["preset:1"] == "Default")
PyresinQoLDB = CopyTable(PyresinQoLDB)
local fresh = Namespace()
fresh.InitializeProfiles()
fresh.InitializeDatabase()
fresh.InitializeModules()
fresh.SyncLayoutProfile()
assert(PyresinQoLDB.profileStore.active == "Default" and PyresinQoLDB.profileStore.characterBindings[character]["preset:1"] == "Default")
assert(not fresh.GetModule("performance").active)
assert(info.activeLayout == 1 and #info.layouts == 3, "Profile operations must never write native layout data")

-- Before login GetLayouts may still report a preset bound to another profile.
-- Startup modules must follow the last active profile, or disabling loops on reload.
local late, freshRoot, freshCore = Namespace(), PyresinQoLDB, core
local lateRoot = CopyTable(PyresinQoLDB)
lateRoot.modules.performance = false
lateRoot.profileStore.active = "Late"
lateRoot.profileStore.profiles.Late = {}
lateRoot.profileStore.profiles.Default.modules.performance = true
lateRoot.profileStore.characterBindings[character]["preset:1"] = "Default"
lateRoot.profileStore.characterBindings[character]["Player-1:2:Raid UI"] = "Late"
PyresinQoLDB = lateRoot
function late.InitializeSettings() function late.RefreshProfileSettings() end end
assert(loadfile("Core/Bootstrap.lua"))("PyresinQoL", late)
info.activeLayout = 1
core.callback(core, "ADDON_LOADED", "PyresinQoL")
assert(not late.GetModule("performance").active)
info.activeLayout = 6
core.callback(core, "PLAYER_LOGIN")
Flush()
assert(PyresinQoLDB.profileStore.active == "Late" and not late.ModulesNeedReload() and not late.profileReloadPending)
info.activeLayout, PyresinQoLDB, core = 1, freshRoot, freshCore
print("PASS: automatic layout binding, snapshots, live restore, rename/delete bursts, scopes, presets, combat and reload prompts")

-- Several profiles can share an account layout, with a separate choice per character.
ns = fresh
store = PyresinQoLDB.profileStore
CreateFrame = createDropdown
local profileButtons = #buttons
local profilePage = ns.CreateProfilesPage({})
local linkedDropdown = dropdowns[#dropdowns - 1]
assert(not buttons[profileButtons + 2].enabled, "Default cannot be renamed")
info.activeLayout = 4
ns.SyncLayoutProfile()
local sharedKey = ns.currentLayoutKey
PyresinQoLDB.custom = "one"
assert(ns.CreateProfile("Shared one") and ns.CreateProfile("Shared alternate"))
assert(store.profileLayouts[character]["Shared one"] == sharedKey
    and store.profileLayouts[character]["Shared alternate"] == sharedKey)
PyresinQoLDB.custom = "alternate"
assert(ns.SwitchProfile("Shared one") and info.activeLayout == 4)
ns.InitializeProfiles()
assert(PyresinQoLDB.custom == "one")
character = "Player-2"
ns.SyncLayoutProfile()
assert(ns.CreateProfile("Shared two"))
PyresinQoLDB.custom = "two"
character = "Player-1"
ns.SyncLayoutProfile()
assert(store.active == "Shared one" and PyresinQoLDB.custom == "one")
character = "Player-2"
ns.SyncLayoutProfile()
assert(store.active == "Shared two" and PyresinQoLDB.custom == "two")
assert(store.characterBindings["Player-1"][sharedKey] == "Shared one"
    and store.characterBindings["Player-2"][sharedKey] == "Shared two")

-- Explicit linking never selects a Blizzard layout, even during later same-layout updates.
profilePage.scripts.OnShow()
Entry(linkedDropdown, "Classic (" .. ns.L.profilePreset .. ")").click()
assert(info.activeLayout == 4)
assert(ns.GetLinkedProfileLayout() == "preset:2")
ns.SyncLayoutProfile()
assert(store.active == "Shared two" and PyresinQoLDB.custom == "two")
info.activeLayout = 2
ns.SyncLayoutProfile()
assert(store.active == "Shared two")
assert(not ns.LinkProfileToLayout("missing"))
dirty, shown = true, true
assert(not ns.LinkProfileToLayout(sharedKey))
dirty, combat = false, true
assert(not ns.LinkProfileToLayout(sharedKey))
combat = false
assert(ns.RenameProfile("Shared two", "Shared renamed"))
assert(store.characterBindings[character]["preset:2"] == "Shared renamed"
    and store.profileLayouts[character]["Shared renamed"] == "preset:2"
    and not store.profileLayouts[character]["Shared two"])

-- Existing flat bindings migrate without resetting profiles or their values.
PyresinQoLDB = { custom = "legacy", profileStore = { active = "Default", profiles = { Default = {} },
    layoutBindings = { ["preset:2"] = "Default" }, layoutsInitialized = true } }
ns = Namespace()
ns.InitializeProfiles()
ns.SyncLayoutProfile()
assert(PyresinQoLDB.custom == "legacy" and PyresinQoLDB.profileStore.active == "Default")
assert(PyresinQoLDB.profileStore.characterBindings[character]["preset:2"] == "Default"
    and ns.GetLinkedProfileLayout() == "preset:2" and not PyresinQoLDB.profileStore.layoutBindings)
print("PASS: multiple profiles per layout, character-specific choices, one-way linking and binding migration")

-- An offline character's catalog must not turn a delete/create into an account-wide rename.
local deletedKey, replacementKey = "account:1:Deleted layout", "account:1:Replacement layout"
character = "Player-A"
info = { activeLayout = 4, layouts = { { layoutType = 1, layoutName = "Deleted layout" } } }
PyresinQoLDB = { custom = "B deleted", profileStore = {
    active = "B deleted", profiles = { Default = {}, ["A deleted"] = { custom = "A deleted" },
        ["B deleted"] = { custom = "B deleted" } }, layoutsInitialized = true,
    characterBindings = { ["Player-A"] = { [deletedKey] = "A deleted" },
        ["Player-B"] = { [deletedKey] = "B deleted" } },
    profileLayouts = { ["Player-A"] = { ["A deleted"] = deletedKey },
        ["Player-B"] = { ["B deleted"] = deletedKey } },
    layoutCatalogs = { ["Player-A"] = { deletedKey }, ["Player-B"] = { deletedKey } },
} }
ns = Namespace()
ns.InitializeProfiles()
ns.SyncLayoutProfile()
info.layouts = {}
ns.RecordLayoutCatalog() -- Native deletion event while B is offline.
info.layouts = { { layoutType = 1, layoutName = "Replacement layout" } }
ns.RecordLayoutCatalog() -- Native creation event, before the deferred sync.
ns.SyncLayoutProfile()
assert(ns.CreateProfile("A replacement"))
PyresinQoLDB.custom = "A replacement"
PyresinQoLDB = CopyTable(PyresinQoLDB) -- Reload Lua/SavedVariables on B's login.
character = "Player-B"
ns = Namespace()
ns.InitializeProfiles()
ns.SyncLayoutProfile()
store = PyresinQoLDB.profileStore
assert(store.characterBindings["Player-A"][replacementKey] == "A replacement",
    "B's stale catalog must not overwrite A's replacement binding")
assert(store.active ~= "B deleted" and PyresinQoLDB.custom ~= "B deleted",
    "A replacement layout must not load B's deleted-layout profile")
assert(store.characterBindings["Player-B"][deletedKey] == "B deleted"
    and store.profileLayouts["Player-B"]["B deleted"] == deletedKey)

-- A rename actually observed in this runtime still carries every character's links.
local bReplacement = store.active
info.layouts[1].layoutName = "Replacement renamed"
ns.RecordLayoutCatalog()
ns.SyncLayoutProfile()
local renamedKey = "account:1:Replacement renamed"
assert(store.characterBindings["Player-A"][renamedKey] == "A replacement"
    and store.characterBindings["Player-B"][renamedKey] == bReplacement)
assert(store.profileLayouts["Player-A"]["A replacement"] == renamedKey
    and store.profileLayouts["Player-B"][bReplacement] == renamedKey)
character = "Player-A"
PyresinQoLDB = CopyTable(PyresinQoLDB)
ns = Namespace()
ns.InitializeProfiles()
ns.SyncLayoutProfile()
assert(PyresinQoLDB.profileStore.active == "A replacement" and PyresinQoLDB.custom == "A replacement")
print("PASS: stale offline catalogs cannot migrate replacement bindings; live account-layout renames survive relog")
