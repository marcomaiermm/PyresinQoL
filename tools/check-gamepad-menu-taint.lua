-- Run with Elune from the addon directory, passing Blizzard's Interface/AddOns path.
-- Optional second argument: baseline, disabled or transition (mouse/keyboard to controller).
assert(issecurevariable and debug.setstacktaint, "This check requires the Elune Lua runtime")
local root = assert(arg[1]) .. "/"
local function native(path) assert(loadfile(root .. path))() end
local function noop() end
local function no() return false end
local function yes() return true end
local errors, protectedCalls = {}, 0
local controllerMode = arg[2] ~= "transition"
seterrorhandler(function(message) errors[#errors + 1] = message end)
function Mixin(target, ...)
    for index = 1, select("#", ...) do
        for key, value in pairs(select(index, ...)) do target[key] = value end
    end
    return target
end
function CreateFromMixins(...) return Mixin({}, ...) end
native("Blizzard_SharedXMLBase/Mixin.lua")
native("Blizzard_SharedXML/LayoutFrame.lua")
function Clamp(value, minimum, maximum) return math.min(maximum, math.max(minimum, value)) end
function RoundToNearestMultiple(value) return value end
function GenerateFlatClosure(fn, ...)
    local args = { ... }
    return function() return fn(unpack(args)) end
end
GenerateClosure = GenerateFlatClosure
StaticPopupDialogs = {}
GameMenuEscPriority = { Framework = 1 }
RegisterGameMenuEscHandler = noop
CallbackRegistrantMixin = { OnShow = noop, OnHide = noop }
FrameUtil = { RegisterFrameForEvents = noop, UnregisterFrameForEvents = noop }
UpdateMicroButtons, CanAutoSetGamePadCursorControl = noop, no
NarrationUtil = { NarrateCurrentScreen = noop, MakeIndexInfo = noop }
EventRegistry = { TriggerEvent = noop }
InputUtil = { IsGamepadUIEnabled = function() return controllerMode end, RegisterForInterfaceTransitions = noop,
    RegisterGamepadInit = noop, RegisterGamepadUninit = noop }
SmartNavigation_AddBidirectionalJumpNavigationOverride = noop
SMART_NAV_INPUT_DIRECTION = { UP = 1, DOWN = 2 }
C_ExternalEventURL = { HasURL = no }
C_StorePublic, C_CatalogShop = { IsEnabled = no }, { IsShop2Enabled = no }
Kiosk, CurrentVersionHasNewUnseenSettings = { IsEnabled = no }, no
GameRulesUtil = { GetActiveAccountStore = noop, ShouldShowAddOns = no, ShouldShowSplashScreen = no }
EditModeManagerFrame = { CanEnterEditMode = no }
C_GameRules, Enum = { IsGameRuleActive = yes }, { GameRule = { MacrosDisabled = 1 } }
StaticPopup_Visible = no
GAMEMENU_OPTIONS, GAMEMENU_SUPPORT, LOG_OUT, EXIT_GAME = "Options", "Help", "Logout", "Exit"
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
Logout, Quit, ToggleHelpFrame, PlaySound = noop, noop, noop, noop
SettingsPanel = { Open = noop }
InCombatLockdown, InGlue = no, no
GameTooltip = { IsOwned = no }
GamepadSharedUtility = { BindingStack = {} }
GamepadMode = { IsTargetingModifierDown = no }
C_Spell = { GetSpellTexture = noop }
function UnitExists() return false end
UnitIsGameObject, UnitHasLootInteraction, UnitIsInInteractRange = no, no, no
function SetPreferredGamepadInteractTarget()
    protectedCalls = protectedCalls + 1
    assert(issecure(), "[ADDON_ACTION_FORBIDDEN] PyresinQoL: SetPreferredGamepadInteractTarget()")
end
native("Blizzard_GamepadSharedUtility/InputBindingStack/InputBindingManager.lua")
native("Blizzard_GamepadActionBars/MainActionBarFrame.lua")
local manager = GamepadSharedUtility.InputBindingManager
local set = { type = "InputBindingSet", BindAll = noop, Iterator = function() return next, {} end }
local actionBar = CreateFromMixins(GamepadMainActionBarFrameMixin)
actionBar.PageUnit = { actionBars = { topBar = { Right = { ActionButton1 = { SpecialActionIcon = { SetTexture = noop } } } } } }
manager:BindToCoreBindingActive(function() actionBar:UpdateInteractIcons() end)
manager.currentCoreBindingActive = false

-- Frame engine methods are stubbed; layout, menu and input binding code are native.
local frameMethods = {}
function frameMethods:SetScript(event, fn) self.scripts[event] = fn end
function frameMethods:HookScript(event, fn)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then securecallfunction(original, ...) end
        securecallfunction(fn, ...)
    end
end
function frameMethods:GetFrameStrata() return "DIALOG" end
function frameMethods:GetFrameLevel() return 1 end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:GetHeight() return self.height end
function frameMethods:SetHeight(height) self.height = height end
frameMethods.SetScale = noop
frameMethods.SetFrameStrata = noop
frameMethods.SetFrameLevel = noop
function frameMethods:SetText(text) self.text = text end
function frameMethods:GetText() return self.text end
function frameMethods:SetSize(width, height) self.width, self.height = width, height end
function frameMethods:GetSize() return self.width or 200, self.height or 36 end
function frameMethods:GetScale() return 1 end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown end
function frameMethods:GetParent() return self.parent end
function frameMethods:GetChildren() return unpack(self.children) end
frameMethods.GetRegions = noop
frameMethods.SetEnabled = noop
frameMethods.SetMotionScriptsWhileDisabled = noop
function frameMethods:ClearAllPoints() self.point = nil end
function frameMethods:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        x, y, relativeTo, relativePoint = relativeTo, relativePoint, self.parent, point
    end
    self.point = { point, relativeTo, relativePoint, x, y }
end
function frameMethods:GetPoint() return unpack(self.point) end
frameMethods.RegisterEvent = noop
local function frame(parent)
    return setmetatable({ children = {}, scripts = {}, parent = parent, shown = true }, { __index = frameMethods })
end
function CreateFrame(_, _, parent)
    local value = frame(parent)
    if parent then table.insert(parent.children, value) end
    return value
end
native("Blizzard_SharedXML/Shared/Frame/MainMenuFrameTemplates.lua")
native("Blizzard_GameMenu/Shared/GameMenuFrame.lua")
UIParent = frame()
GameMenuFrame = frame(UIParent)
Mixin(GameMenuFrame, LayoutMixin, VerticalLayoutMixin, MainMenuFrameMixin, GameMenuFrameMixin)
GameMenuFrame.NewExternalEventFrame = frame()
GameMenuFrame.NewOptionsFrame = frame()
GameMenuFrame.gamepadFooter = { ShowAndActivateBindings = function() manager:AddBindingSet(set) end }
local pooledButtons = {}
GameMenuFrame.buttonPool = {
    ReleaseAll = function()
        for _, button in ipairs(pooledButtons) do
            button:Hide()
            button:ClearAllPoints()
            button.layoutIndex = nil
        end
        pooledButtons = {}
    end,
    Acquire = function()
        local button = CreateFrame("Button", nil, GameMenuFrame)
        pooledButtons[#pooledButtons + 1] = button
        return button
    end,
}

function HideUIPanel() manager:RemoveSet(set) end
local module = {}
if arg[2] ~= "baseline" then
    securecall(function()
        debug.setstacktaint("PyresinQoL")
        PyresinQoLDB = { cooldownShortcut = arg[2] ~= "disabled" }
        local ns = { L = { cooldownMenu = "Cooldowns" }, RegisterModule = function(_, callback) callback(module) end }
        assert(loadfile("Modules/GameMenu/GameMenu.lua"))("PyresinQoL", ns)
    end)
end

securecall(function() GameMenuFrame:OnShow() end)
if arg[2] == "transition" then
    securecall(function() GameMenuFrame:Layout() end)
    controllerMode = true
    securecall(function() module.UpdateCooldownButton() end)
    securecall(function() GameMenuFrame:OnShow() end)
end
-- Simulate a fresh native click on Options, which first hides the game menu.
securecall(function() GameMenuFrame.buttons[1].scripts.OnClick() end)
assert(#errors == 0, table.concat(errors, "\n"))
for _, key in ipairs({ "buttons", "nextLayoutIndex", "buttonCount", "dirty" }) do
    assert(issecurevariable(GameMenuFrame, key), "Native menu state must stay secure: " .. key)
end
assert(protectedCalls == 1, "The native Options click must reach the protected gamepad call")
print("PASS native Options click keeps gamepad interaction secure")
