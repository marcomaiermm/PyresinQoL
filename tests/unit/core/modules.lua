function GetLocale() return "enUS" end
local function Registry()
    local ns = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
    return ns
end

for _, case in ipairs({
    { name = "default enabled", saved = nil, active = true },
    { name = "explicit enabled", saved = true, active = true },
    { name = "explicit disabled", saved = false, active = false },
}) do
    local ns, calls = Registry(), 0
    PyresinQoLDB = { modules = { performance = case.saved } }
    ns.RegisterModule("performance", function(module)
        assert(module == ns.GetModule("performance"), case.name .. ": shared identity")
        calls = calls + 1
    end)
    ns.InitializeModules()
    assert(calls == (case.active and 1 or 0), case.name .. ": startup")
    assert(not ns.ModulesNeedReload(), case.name .. ": initial reload state")
    PyresinQoLDB.modules.performance = not case.active
    assert(ns.ModulesNeedReload(), case.name .. ": changed state needs reload")
    PyresinQoLDB.modules.performance = case.active
    assert(not ns.ModulesNeedReload(), case.name .. ": reverting cancels reload")
    assert(calls == (case.active and 1 or 0), case.name .. ": settings never restart modules")
end

local ns = Registry()
for _, register in ipairs({ ns.GetModule, ns.RegisterModule, ns.RegisterModuleSettings }) do
    assert(not pcall(register, "unknown", function() end), "Unknown modules must be rejected")
end
ns.RegisterModuleSettings("gameMenu", function() end)
assert(not pcall(ns.RegisterModuleSettings, "gameMenu", function() end), "Reject duplicate settings")

local order = { "gameMenu", "editMode", "performance", "dungeonMaps", "experience", "quests", "unitFrames", "tooltips", "actionBars" }
local calls = {}
for _, id in ipairs(order) do
    ns.RegisterModule(id, function(module)
        assert(module == ns.GetModule(id))
        calls[#calls + 1] = id
        module.started = true
    end)
end
ns.RegisterModule("unitFrames", function(module)
    assert(module.started)
    calls[#calls + 1] = "targetDebuffs"
end)
PyresinQoLDB = {}
ns.InitializeModules()
assert(table.concat(calls, ",") == "gameMenu,editMode,performance,dungeonMaps,experience,quests,unitFrames,targetDebuffs,tooltips,actionBars")
print("PASS: module startup/reload table, registration guards and initializer ordering")
