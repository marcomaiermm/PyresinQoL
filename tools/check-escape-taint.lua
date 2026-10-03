-- Run with Elune from the addon directory, passing Blizzard's Interface/AddOns path.
assert(issecurevariable and debug.setstacktaint, "This check requires the Elune Lua runtime")
local root = assert(arg[1], "Pass the native Interface/AddOns directory") .. "/"
local function native(path) assert(loadfile(root .. path))() end
local errors = {}
seterrorhandler(function(message) errors[#errors + 1] = message end)

StaticPopupDialogs = {}
ACCEPT, CANCEL, OKAY = "Accept", "Cancel", "Okay"
HelpFrame = { IsShown = function() return false end }
UIParent = { IsShown = function() return true end }
Menu = { GetManager = function() return { HandleESC = function() return false end } end }
EventRegistry = { RegisterCallback = function() end }
function CanAutoSetGamePadCursorControl() return false end
function SpellStopCasting()
    assert(issecure(), "[ADDON_ACTION_FORBIDDEN] PyresinQoL: SpellStopCasting()")
    return false
end
function SpellStopTargeting() return false end
function GameMenuFrame_Show() end
native("Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua")
native("Blizzard_Game/Shared/Game.lua")
ToggleGameMenu()
assert(#errors == 0, table.concat(errors, "\n"))

local ns = {}
function GetLocale() return "enUS" end
Settings = { VarType = { Boolean = "boolean", String = "string", Number = "number" } }
function Settings.CreateSliderOptions() return { SetLabelFormatter = function() end } end
function Settings.CreateCheckboxInitializer() return {} end
function Settings.CreateSliderInitializer() return {} end
function Settings.CreateColorSwatchInitializer() return {} end
function CreateSettingsListSectionHeaderInitializer() return {} end
function CreateSettingsButtonInitializer() return { AddModifyPredicate = function() end } end
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
PyresinQoLDB = { modules = { actionBars = true } }
function ns.RegisterModuleSettings(_, build)
    build({ active = true, id = "actionBars" }, {
        controls = { Register = function() return {} end, AddControl = function() end },
        pages = { main = { initializers = {} }, visibility = { initializers = {} } },
    })
end
securecall(function()
    debug.setstacktaint("PyresinQoL")
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    assert(loadfile("Modules/ActionBars/Config.lua"))("PyresinQoL", ns)
    assert(loadfile("Modules/ActionBars/Settings.lua"))("PyresinQoL", ns)
end)

-- HelpFrame reads the shared popup registry before registering its ESC handler.
-- A later registration sorts that shared handler list again.
securecall(function() native("Blizzard_HelpFrame/HelpFrame.lua") end)
securecall(function()
    RegisterGameMenuEscHandler(GameMenuEscPriority.Dialog, function() return false end)
end)
ToggleGameMenu()
assert(#errors == 0, table.concat(errors, "\n"))
assert(issecurevariable(_G, "StaticPopupDialogs"), "The native popup registry must stay secure")
assert(issecurevariable(_G, "HelpFrame_EscapePressed"), "Native ESC handlers must stay secure")
assert(StaticPopupDialogs.PYRESINQOL_ACTIONBAR_CONDITION, "The addon dialog must still be registered")
print("PASS: native Escape remains secure after addon settings and later native handler registration")
