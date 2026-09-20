-- Run from the addon directory: luajit tests/modules.lua
function GetLocale() return "enUS" end
local function Registry()
    local ns = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
    return ns
end

local files = {
    gameMenu = { "Modules/GameMenu/GameMenu.lua" }, editMode = { "Modules/EditMode/PixelPerfect.lua" },
    performance = { "Modules/Performance/Performance.lua" }, experience = { "Modules/Experience/Experience.lua" },
    quests = { "Modules/Quests/Quests.lua" }, unitFrames = { "Modules/UnitFrames/UnitFrames.lua", "Modules/UnitFrames/DruidMana.lua", "Modules/UnitFrames/TargetDebuffs.lua", "Modules/UnitFrames/NameplateThreat.lua", "Modules/UnitFrames/NameplateComboPoints.lua", "Modules/UnitFrames/ThreatMeter.lua" },
    tooltips = { "Modules/Tooltips/Tooltip.lua" },
}
-- Loading files or initializing a disabled module must not touch game APIs.
function CreateFrame() error("A disabled module created a frame") end
function hooksecurefunc() error("A disabled module installed a hook") end
for id, paths in pairs(files) do
    local ns = Registry()
    PyresinQoLDB = { modules = { [id] = false }, showFPS = false }
    for _, path in ipairs(paths) do assert(loadfile(path))("PyresinQoL", ns) end
    ns.InitializeModules()
    assert(not ns.ModulesNeedReload() and PyresinQoLDB.showFPS == false)
    PyresinQoLDB.modules[id] = true
    assert(ns.ModulesNeedReload(), "Enabling a module must require a reload")
    PyresinQoLDB.modules[id] = false
    assert(not ns.ModulesNeedReload(), "Reverting a toggle must cancel the reload requirement")
end

local ns = Registry()
local started = {}
PyresinQoLDB = { modules = { performance = false } }
for id, paths in pairs(files) do
    for _ = 1, #paths do
        ns.RegisterModule(id, function() started[id] = (started[id] or 0) + 1 end)
    end
end
ns.InitializeModules()
for id, paths in pairs(files) do
    assert(started[id] == (id ~= "performance" and #paths or nil))
end
assert(not ns.ModulesNeedReload())
PyresinQoLDB.modules.quests = false
assert(ns.ModulesNeedReload() and started.quests == 1, "A toggle must not reinitialize running modules")

-- Boot the actual TOC with everything disabled; only the core event frame may exist.
ns = {}
local core, frameCount = nil, 0
function CreateFrame()
    frameCount = frameCount + 1
    assert(frameCount == 1, "Disabled modules must not create any runtime frames")
    core = { events = {} }
    function core:RegisterEvent(event) self.events[event] = true end
    function core:UnregisterEvent(event) self.events[event] = nil end
    function core:SetScript(_, callback) self.callback = callback end
    return core
end
PyresinQoLDB = nil -- SavedVariables become available only after the files are loaded.
for line in io.lines("PyresinQoL.toc") do
    if line:match("%.lua$") then assert(loadfile(line))("PyresinQoL", ns) end
end
local configured = false
ns.InitializeSettings = function() configured = true end
PyresinQoLDB = { modules = {}, showPerformance = false, performancePosition = { x = 12, y = 34 } }
for id in pairs(files) do PyresinQoLDB.modules[id] = false end
core.callback(core, "ADDON_LOADED", "OtherAddon")
assert(not configured)
core.callback(core, "ADDON_LOADED", "PyresinQoL")
assert(configured and frameCount == 1 and not core.events.ADDON_LOADED)
assert(not PyresinQoLDB.showFPS and not PyresinQoLDB.showLatency and PyresinQoLDB.showPerformance == nil)
assert(PyresinQoLDB.performancePosition.x == 12 and not ns.ModulesNeedReload())
assert(not ns.GetModule("unitFrames").UpdateTargetThreat and not ns.GetModule("tooltips").UpdateTooltips and not ns.GetModule("performance").performanceDisplay)
print("PASS: deferred module startup, isolated disabling, grouped target features, reload state and saved settings")

-- Every runtime and settings file must be present exactly once in the real manifest.
local seen, count, title, savedVariables = {}, 0
for line in io.lines("PyresinQoL.toc") do
    title = line:match("^## Title: (.+)$") or title
    savedVariables = line:match("^## SavedVariables: (.+)$") or savedVariables
    if line:match("%.lua$") then
        assert(not seen[line], "Duplicate TOC entry: " .. line)
        seen[line], count = true, count + 1
        assert(loadfile(line))
    end
end
assert(title == "PyresinQoL" and savedVariables == "PyresinQoLDB")
assert(_G[savedVariables] == PyresinQoLDB, "The runtime database must match the saved variable in the TOC")
assert(count == 25, "Update the manifest expectation when adding source files")
local order = { "gameMenu", "editMode", "performance", "experience", "quests", "unitFrames", "tooltips" }
assert(#ns.modules == #order)
for index, id in ipairs(order) do
    local module = ns.GetModule(id)
    assert(module == ns.modules[index], "Module identity and startup order must be stable")
    assert(#module.initializers == #files[id], "Incomplete runtime registration: " .. id)
    assert(type(module.buildSettings) == "function", "Missing settings builder: " .. id)
    for key in pairs(module) do
        assert(not key:match("^Update"), "Disabled modules must not export runtime callbacks")
    end
end
assert(not pcall(ns.GetModule, "unknown"))
assert(not pcall(ns.RegisterModule, "unknown", function() end))
assert(not pcall(ns.RegisterModuleSettings, "unknown", function() end))
assert(not pcall(ns.RegisterModuleSettings, "gameMenu", function() end))

-- Multiple initializers share the module object, in registration order.
local registry = Registry()
local calls = {}
for _, id in ipairs(order) do
    registry.RegisterModule(id, function(module)
        assert(module == registry.GetModule(id))
        calls[#calls + 1] = id
        module.started = true
    end)
end
registry.RegisterModule("unitFrames", function(module)
    assert(module.started)
    calls[#calls + 1] = "targetDebuffs"
end)
PyresinQoLDB = {}
registry.InitializeModules()
assert(table.concat(calls, ",") == "gameMenu,editMode,performance,experience,quests,unitFrames,targetDebuffs,tooltips")

-- Legacy migration preserves explicit values, unknown keys and saved positions.
local position = { x = 10, y = -20 }
PyresinQoLDB = { showPerformance = true, showFPS = false, performancePosition = position, custom = "keep" }
ns.InitializeDatabase()
assert(PyresinQoLDB.showFPS == false and PyresinQoLDB.showLatency == true and PyresinQoLDB.showPerformance == nil)
assert(PyresinQoLDB.performancePosition == position and PyresinQoLDB.custom == "keep")
ns.InitializeDatabase()
assert(PyresinQoLDB.showFPS == false and PyresinQoLDB.showLatency == true)
print("PASS: TOC integrity, complete module/settings registration, shared interfaces, startup order and migration preservation")
