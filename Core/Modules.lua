local _, ns = ...
local L = ns.L

ns.modules = {
    { id = "gameMenu", group = "general", name = L.gameMenu, description = L.gameMenuDescription },
    { id = "editMode", group = "general", name = L.editMode, description = L.editModeDescription },
    { id = "performance", group = "misc", name = L.performance, description = L.performanceDescription },
    { id = "dungeonMaps", group = "misc", name = L.dungeonMaps, description = L.dungeonMapsDescription },
    { id = "experience", group = "misc", name = L.experience, description = L.experienceDescription },
    { id = "flightTimer", group = "misc", name = L.flightTimer, description = L.flightTimerDescription },
    { id = "quests", group = "misc", name = L.quests, description = L.questsDescription, enabledByDefault = false },
    { id = "unitFrames", group = "unitFrames", name = L.unitFrames, description = L.unitFramesDescription,
        pages = {
            { id = "player", name = L.playerFrame },
            { id = "target", name = L.targetFrame },
            { id = "nameplates", name = L.nameplates },
            { id = "statusText", name = L.statusText },
            { id = "auras", name = L.auras },
        },
    },
    { id = "tooltips", group = "misc", name = L.tooltips, description = L.tooltipsDescription },
    { id = "actionBars", group = "actionBars", name = L.actionBars, description = L.actionBarsDescription },
    { id = "flyouts", group = "actionBars", name = L.flyouts, description = L.flyoutsDescription, enabledByDefault = false },
}

-- Our own Edit Mode displays (Modules/EditMode/CustomDisplay.lua), for the pixel-perfect editor's
-- snapping and the profile switch.
ns.customEditModeDisplays = {}

ns.settingsGroups = {
    { id = "general", name = L.general },
    { id = "unitFrames", name = L.unitFrames },
    { id = "misc", name = L.misc },
    { id = "actionBars", name = L.actionBars },
}
local function Normalize(module)
    module.pages = module.pages or { { id = "main", name = module.name } }
    module.enabledByDefault = module.enabledByDefault ~= false
end
for _, module in ipairs(ns.modules) do Normalize(module) end

-- The addons listed under PyresinQoL in the AddOns list reach this namespace through the PyresinQoL global.
PyresinQoL = ns

-- A module in its own addon, switched on and off in the AddOns list instead of the Modules page: while that
-- addon is loaded, the module is on. It starts at PLAYER_LOGIN, after every addon has loaded.
function ns.AddAddonModule(module)
    module.addon = true
    Normalize(module)
    table.insert(ns.modules, module)
    return module
end

-- The ordered list owns metadata and startup order; callers share these objects.
function ns.GetModule(id)
    for _, module in ipairs(ns.modules) do
        if module.id == id then return module end
    end
    error("Unknown PyresinQoL module: " .. id)
end

function ns.RegisterModule(id, initialize)
    local module = ns.GetModule(id)
    module.initializers = module.initializers or {}
    table.insert(module.initializers, initialize)
end

function ns.RegisterModuleSettings(id, build)
    local module = ns.GetModule(id)
    assert(not module.buildSettings, "Settings already registered for PyresinQoL module: " .. id)
    module.buildSettings = build
end

local function Start(module)
    if module.addon or PyresinQoLDB.modules[module.id] == nil then
        PyresinQoLDB.modules[module.id] = module.enabledByDefault
    end
    module.active = PyresinQoLDB.modules[module.id]
    if module.active then
        for _, initialize in ipairs(module.initializers or {}) do initialize(module) end
    end
end

function ns.InitializeModules()
    PyresinQoLDB.modules = PyresinQoLDB.modules or {}
    for _, module in ipairs(ns.modules) do Start(module) end
end

-- At PLAYER_LOGIN: the modules of the addons that loaded after this one.
function ns.InitializeAddonModules()
    local resourceBars = false
    for _, module in ipairs(ns.modules) do
        if module.active == nil then Start(module) end
        if module.id == "resourceBar" then resourceBars = true end
    end
    -- Disabled in the AddOns list, the resource bars give back the personal resource display they hid.
    local store = PyresinQoLDB.profileStore
    local saved = store and store.personalDisplay
    if not resourceBars and type(saved) == "string" and not InCombatLockdown() then
        C_CVar.SetCVar("nameplateShowSelf", saved)
        store.personalDisplay = nil
    end
end

function ns.ModulesNeedReload()
    for _, module in ipairs(ns.modules) do
        if module.active ~= PyresinQoLDB.modules[module.id] then return true end
    end
    return false
end
