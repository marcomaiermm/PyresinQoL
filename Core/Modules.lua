local _, ns = ...
local L = ns.L

ns.modules = {
    { id = "gameMenu", group = "general", name = L.gameMenu, description = L.gameMenuDescription },
    { id = "editMode", group = "general", name = L.editMode, description = L.editModeDescription },
    { id = "performance", group = "misc", name = L.performance, description = L.performanceDescription },
    { id = "experience", group = "misc", name = L.experience, description = L.experienceDescription },
    { id = "quests", group = "misc", name = L.quests, description = L.questsDescription },
    { id = "unitFrames", group = "unitFrames", name = L.unitFrames, description = L.unitFramesDescription,
        pages = {
            { id = "main", name = L.general },
            { id = "player", name = L.playerFrame },
            { id = "target", name = L.targetFrame },
            { id = "nameplates", name = L.nameplates },
        },
    },
    { id = "tooltips", group = "misc", name = L.tooltips, description = L.tooltipsDescription },
}

ns.settingsGroups = {
    { id = "general", name = L.general },
    { id = "unitFrames", name = L.unitFrames },
    { id = "misc", name = L.misc },
}
for _, module in ipairs(ns.modules) do
    module.pages = module.pages or { { id = "main", name = module.name } }
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

function ns.InitializeModules()
    PyresinQoLDB.modules = PyresinQoLDB.modules or {}
    for _, module in ipairs(ns.modules) do
        if PyresinQoLDB.modules[module.id] == nil then PyresinQoLDB.modules[module.id] = true end
        module.active = PyresinQoLDB.modules[module.id]
        if module.active then
            for _, initialize in ipairs(module.initializers or {}) do initialize(module) end
        end
    end
end

function ns.ModulesNeedReload()
    for _, module in ipairs(ns.modules) do
        if module.active ~= PyresinQoLDB.modules[module.id] then return true end
    end
    return false
end
