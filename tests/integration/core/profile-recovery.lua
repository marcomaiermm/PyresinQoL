-- Malformed SavedVariables must not prevent startup or erase recoverable profiles.
function GetLocale() return "enUS" end
function UnitGUID() return "Player-recovery" end
function InCombatLockdown() return false end
function CopyTable(value)
    local copy = {}
    for key, item in pairs(value) do copy[key] = type(item) == "table" and CopyTable(item) or item end
    return copy
end
local function Namespace()
    local ns = {}
    for _, file in ipairs({ "Localization", "Modules", "Database", "Profiles" }) do
        assert(loadfile("Core/" .. file .. ".lua"))("PyresinQoL", ns)
    end
    return ns
end
local cases = {
    { name = "non-table root", saved = true },
    { name = "non-table registry", saved = { profileStore = 42 } },
    { name = "missing registry fields", saved = { profileStore = {} } },
    { name = "invalid profile collection", saved = { profileStore = { active = "Raid", profiles = false } } },
    { name = "invalid active name", saved = { profileStore = { active = {}, profiles = { Raid = { custom = "raid" } } } } },
    { name = "missing active profile", saved = { profileStore = { active = "Missing", profiles = { Raid = { custom = "raid" } } } } },
    { name = "fallback preserves existing snapshots", saved = { profileStore = { active = "Missing", futureRegistry = "keep",
        profiles = { Default = { custom = "saved default", futureSetting = { keep = 71 } }, Raid = { custom = "raid" } },
    } } },
    { name = "invalid profile entries", saved = { profileStore = { active = "Raid", profiles = {
        Raid = { custom = "raid" }, broken = true, [3] = {}, [""] = {},
    } } }, active = "Raid" },
    { name = "stale pending", saved = { profileStore = { active = "Raid", pending = "Deleted", profiles = { Raid = {} } } }, active = "Raid" },
    { name = "wrong-type pending", saved = { profileStore = { active = "Raid", pending = {}, profiles = { Raid = {} } } }, active = "Raid" },
    { name = "wrong-type modules", saved = { modules = "bad", profileStore = {
        active = "Default", pending = "Raid", profiles = { Default = {}, Raid = { modules = 42, custom = "incoming" } },
    } }, active = "Raid", custom = "incoming" },
    { name = "reserved registry in pending snapshot", saved = { profileStore = {
        active = "Default", pending = "Raid", profiles = { Default = {}, Raid = {
            custom = "incoming", profileStore = false, futureSetting = { keep = 27 },
        } },
    } }, active = "Raid", custom = "incoming" },
    { name = "invalid known module flags", saved = { modules = { performance = "false", unitFrames = 0, customModule = "preserve" } } },
    { name = "malformed mapping containers", saved = { profileStore = {
        active = "Default", profiles = { Default = {} }, characterBindings = true, profileLayouts = 42, layoutBindings = false,
    } } },
    { name = "malformed nested mappings", saved = { profileStore = {
        active = "Default", profiles = { Default = {}, Raid = { custom = "raid" } },
        characterBindings = { bad = true, [7] = {}, ["Player-recovery"] = {
            ["preset:1"] = "Raid", ["preset:2"] = "Missing", ["preset:3"] = false, [4] = "Raid",
        } },
        profileLayouts = { bad = false, ["Player-recovery"] = { Raid = "preset:1", Missing = "preset:2", Default = {} } },
        layoutBindings = { ["preset:2"] = "Default", broken = "Missing" },
    } } },
}
for _, case in ipairs(cases) do
    PyresinQoLDB = CopyTable({ saved = case.saved }).saved
    if type(PyresinQoLDB) == "table" then PyresinQoLDB.custom = "root"; PyresinQoLDB.futureSetting = { keep = 19 } end
    local ns = Namespace()
    local ok, reason = pcall(function()
        ns.InitializeProfiles()
        ns.InitializeDatabase()
        ns.InitializeModules()
        local store = PyresinQoLDB.profileStore
        assert(store.active == (case.active or "Default"), "Fallback active profile")
        assert(type(store.profiles[store.active]) == "table" and not store.pending)
        for name, profile in pairs(store.profiles) do
            assert(type(name) == "string" and name ~= "" and type(profile) == "table")
        end
        assert(type(PyresinQoLDB.modules) == "table")
        for _, module in ipairs(ns.modules) do assert(type(PyresinQoLDB.modules[module.id]) == "boolean") end
        if type(case.saved) == "table" then
            assert(PyresinQoLDB.custom == (case.custom or "root"), "Preserve valid root settings unless completing a valid pending switch")
            if case.custom then
                assert(store.profiles.Default.custom == "root" and store.profiles.Default.futureSetting.keep == 19,
                    "Preserve outgoing root settings when completing a valid pending switch")
            else
                assert(PyresinQoLDB.futureSetting.keep == 19, "Preserve unknown settings")
            end
        end
        if case.name == "invalid known module flags" then assert(PyresinQoLDB.modules.customModule == "preserve") end
        if case.name == "reserved registry in pending snapshot" then
            assert(PyresinQoLDB.futureSetting.keep == 27, "Only the reserved registry key is excluded from restore")
        end
        if case.name == "fallback preserves existing snapshots" then
            assert(store.profiles.Default.custom == "saved default" and store.profiles.Default.futureSetting.keep == 71)
            assert(store.futureRegistry == "keep", "Preserve unknown registry fields")
        end
        if type(case.saved) == "table" and type(case.saved.profileStore) == "table"
            and type(case.saved.profileStore.profiles) == "table" and case.saved.profileStore.profiles.Raid
            and case.saved.profileStore.profiles.Raid.custom == "raid" then
            assert(store.profiles.Raid.custom == "raid", "Preserve recoverable inactive profiles")
        end
        ns.GetLinkedProfileLayout() -- Migrates valid legacy bindings after recovery.
        for _, field in ipairs({ "characterBindings", "profileLayouts" }) do
            for character, mappings in pairs(store[field]) do
                assert(type(character) == "string" and type(mappings) == "table")
                for key, value in pairs(mappings) do assert(type(key) == "string" and type(value) == "string") end
            end
        end
        if case.name == "malformed nested mappings" then
            assert(store.characterBindings["Player-recovery"]["preset:1"] == "Raid")
            assert(store.characterBindings["Player-recovery"]["preset:2"] == "Default")
            assert(store.profileLayouts["Player-recovery"].Raid == "preset:1")
            assert(not store.profileLayouts["Player-recovery"].Missing)
        end
        local registry, profiles = store, store.profiles
        ns.InitializeProfiles()
        assert(PyresinQoLDB.profileStore == registry and registry.profiles == profiles, "Recovery is idempotent")
    end)
    assert(ok, case.name .. ": " .. tostring(reason))
end
print("PASS: malformed profile registries, module values and character mappings recover without losing valid settings")
