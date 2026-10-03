-- Run from the addon directory: luajit tests/actionbars.lua [Blizzard Interface/AddOns path]
local hooks, events, handlers, stateDrivers = {}, {}, {}, {}
local inCombat, interfaceGamepad = false, false
local secureCallDepth = 0
local secretValues = setmetatable({}, { __mode = "k" })
local function Secret(value) local token = {}; secretValues[token] = value; return token end
function issecretvalue(value) return secretValues[value] ~= nil end
local function Decode(value)
    if issecretvalue(value) then return secretValues[value] end
    return value
end

local function Color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1, GetRGBA = function(self) return self.r, self.g, self.b, self.a end }
end
function CreateColor(r, g, b, a) return Color(r, g, b, a) end
ACTIONBAR_HOTKEY_FONT_COLOR = Color(1, .82, 0, 1)
C_CurveUtil = { EvaluateColorFromBoolean = function(value, yes, no)
    return Decode(value) and yes or no
end }

local function Region(font, size)
    local region = { font = font or "native.ttf", size = size or 11, flags = "OUTLINE", shown = true,
        text = "", color = { 1, 1, 1, 1 } }
    function region:GetFont() return self.font, self.size, self.flags end
    function region:SetFont(path, height, flags) self.font, self.size, self.flags = path, height, flags end
    function region:GetFontObject() return nil end
    function region:SetVertexColor(...) self.color = { ... } end
    function region:GetVertexColor() return unpack(self.color) end
    function region:SetText(value) self.text = value end
    function region:GetText() return self.text end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    return region
end

local function compile(body, arguments)
    local raw = assert(loadstring("return function(" .. arguments .. ") " .. body .. " end"))()
    setfenv(raw, _G)
    return function(...)
        secureCallDepth = secureCallDepth + 1
        local result = { pcall(raw, ...) }
        secureCallDepth = secureCallDepth - 1
        assert(result[1], result[2])
        table.remove(result, 1)
        return unpack(result)
    end
end

local function Frame(name)
    local frame = { name = name, shown = true, alpha = 1, underMouse = false,
        scripts = {}, wrappers = {}, attributes = {},
        showCalls = 0, hideCalls = 0 }
    function frame:GetName() return self.name end
    function frame:IsShown() return self.shown end
    function frame:IsUnderMouse() return self.underMouse end
    function frame:SetAttribute(key, value)
        assert(not (self.secure and inCombat and secureCallDepth == 0),
            "direct protected SetAttribute is forbidden in combat")
        self.attributes[key] = value
    end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:Show(skipAttribute)
        self.showCalls = self.showCalls + 1
        if not skipAttribute then self.attributes.statehidden = nil end
        local changed = not self.shown
        self.shown = true
        if changed then
            for _, wrapper in ipairs(self.wrappers.OnShow or {}) do wrapper.fn(self, wrapper.owner) end
        end
    end
    function frame:Hide(skipAttribute)
        self.hideCalls = self.hideCalls + 1
        if not skipAttribute then self.attributes.statehidden = true end
        local changed = self.shown
        self.shown = false
        if changed then
            for _, wrapper in ipairs(self.wrappers.OnHide or {}) do wrapper.fn(self, wrapper.owner) end
        end
    end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:RegisterEvent(event) self.registered = self.registered or {}; self.registered[event] = true end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript(script, callback)
        local old = self.scripts[script]
        self.scripts[script] = function(...) if old then old(...) end; callback(...) end
    end
    return frame
end

UIParent = Frame("UIParent")
function CreateFrame(_, _, _, template)
    local frame = Frame()
    if template == "SecureHandlerStateTemplate" then
        frame.secure = true
        frame.attributes, frame.refs = {}, {}
        handlers[#handlers + 1] = frame
        function frame:SetFrameRef(key, value)
            assert(not (inCombat and secureCallDepth == 0),
                "direct protected SetFrameRef is forbidden in combat")
            self.refs[key] = value
        end
        function frame:GetFrameRef(key) return self.refs[key] end
        function frame:SetAttribute(key, value)
            assert(not (inCombat and secureCallDepth == 0),
                "direct protected SetAttribute is forbidden in combat")
            if type(value) == "string" and (key == "applyRule" or key:match("^_onstate%-")) then
                self.attributes[key] = compile(value, "self, stateid, newstate")
            else
                self.attributes[key] = value
            end
            local state = key:match("^state%-(.+)")
            local callback = state and self.attributes["_onstate-" .. state]
            if callback then callback(self, state, value) end
        end
        function frame:GetAttribute(key) return self.attributes[key] end
        function frame:RunAttribute(key) return self.attributes[key](self) end
        function frame:Execute(body)
            assert(not (inCombat and secureCallDepth == 0),
                "direct protected Execute is forbidden in combat")
            return compile(body, "self")(self)
        end
        function frame:WrapScript(control, script, body)
            control.wrappers[script] = control.wrappers[script] or {}
            control.wrappers[script][#control.wrappers[script] + 1] = {
                owner = self, fn = compile(body, "self, control"),
            }
        end
    else
        events[#events + 1] = frame
    end
    return frame
end

-- An optional client source tree runs the same scenarios through Blizzard's driver.
-- Only macro results and frame-engine methods are stubbed in this mode.
local nativeDriver, driverValues
if arg[1] then
    driverValues = {}
    nativeDriver = setmetatable({
        strmatch = string.match,
        table = { wipe = function(values) for key in pairs(values) do values[key] = nil end end },
        SecureCmdOptionParse = function(driver) return driverValues[driver] end,
        CreateFrame = function()
            local manager = Frame("SecureStateDriverManager")
            function manager:SetAttribute(key, value)
                self.attributes[key] = value
                self.scripts.OnAttributeChanged(self, key, value)
            end
            return manager
        end,
    }, { __index = _G })
    local source = assert(loadfile(arg[1] .. "/Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua"))
    setfenv(source, nativeDriver)()
end

local function SetState(frame, state, value)
    if nativeDriver then
        driverValues[assert(frame.drivers[state], "State driver must be registered")] = value
        local manager = nativeDriver.SecureStateDriverManager
        secureCallDepth = secureCallDepth + 1
        manager.scripts.OnUpdate(manager, 1)
        secureCallDepth = secureCallDepth - 1
        return
    end
    -- Blizzard handles this reserved state by changing the registered frame itself.
    if state == "visibility" then
        if value == "show" then frame:Show()
        elseif value == "hide" then frame:Hide() end
        return
    end
    if frame.attributes["state-" .. state] ~= value then
        frame.attributes["state-" .. state] = value
        local callback = frame.attributes["_onstate-" .. state]
        if callback then callback(frame, state, value) end
    end
end
local visibilityResult = "show"
function RegisterStateDriver(frame, state, driver)
    assert(not inCombat, "RegisterStateDriver is forbidden in combat")
    assert(frame.attributes, "Visibility drivers must only be registered on addon-owned secure handlers")
    frame.drivers = frame.drivers or {}; frame.drivers[state] = driver
    stateDrivers[#stateDrivers + 1] = { frame = frame, state = state, driver = driver }
    local value = state == "alpha" and (inCombat and "combat" or "normal") or visibilityResult
    if nativeDriver then
        driverValues[driver] = value
        nativeDriver.RegisterStateDriver(frame, state, driver)
    else
        SetState(frame, state, value)
    end
end
function UnregisterStateDriver(frame, state)
    assert(not inCombat, "UnregisterStateDriver is forbidden in combat")
    if nativeDriver then nativeDriver.UnregisterStateDriver(frame, state) end
    if frame.drivers then frame.drivers[state] = nil end
end

function InCombatLockdown() return inCombat end
function GetBindingKey(action) return ({ ACTIONBUTTON1 = "CTRL-SHIFT-BUTTON4" })[action] end
function GetBindingText(key) return key end
function IsBindingForGamePad() return false end
RANGE_INDICATOR = "RANGE"

local usable, noMana, usableCalls = true, false, 0
C_ActionBar = { IsUsableAction = function(action)
    assert(not issecretvalue(action), "Secret action slots must never reach IsUsableAction")
    usableCalls = usableCalls + 1
    return usable, noMana
end }
ActionBarActionButtonMixin = {}
function ActionBarActionButtonMixin:UpdateUsable(_, isUsable, lacksMana)
    if isUsable == nil then isUsable = usable end
    if lacksMana == nil then lacksMana = noMana end
    if Decode(isUsable) then self.icon:SetVertexColor(1, 1, 1, 1)
    elseif Decode(lacksMana) then self.icon:SetVertexColor(.5, .5, 1, 1)
    else self.icon:SetVertexColor(.4, .4, .4, 1) end
end
function ActionBarActionButtonMixin:UpdateHotkeys()
    self.bindingAction = "ACTIONBUTTON" .. self:GetID()
    local key = GetBindingKey(self.bindingAction)
    self.HotKey:SetText(key and GetBindingText(key, 1) or RANGE_INDICATOR)
end
function ActionBarActionButtonMixin:Update() self:UpdateUsable(); self:UpdateHotkeys() end
function ActionBarActionButtonMixin:UpdateCount() end
function ActionButton_UpdateRangeIndicator(button, checksRange, inRange)
    if button.HotKey:GetText() ~= RANGE_INDICATOR then
        button.HotKey:SetVertexColor(1, (Decode(checksRange) and not Decode(inRange)) and 0 or .82, 0, 1)
    end
end
function hooksecurefunc(owner, method, callback)
    if type(owner) == "string" then
        callback, method, owner = method, owner, _G
    end
    local original = owner[method]
    owner[method] = function(...)
        local result = { original(...) }
        callback(...)
        return unpack(result)
    end
end

local function Button(name, id)
    local button = Frame(name)
    button.id, button.action = id, id
    button.icon, button.Icon = Region(), nil
    button.Icon = button.icon
    button.HotKey, button.Name, button.Count = Region("hotkey.ttf", 11), Region("macro.ttf", 10), Region("count.ttf", 9)
    function button:GetID() return self.id end
    for key, value in pairs(ActionBarActionButtonMixin) do button[key] = value end
    return button
end

local button = Button("ActionButton1", 1)
button.bindingAction = "ACTIONBUTTON1"
button.HotKey:SetText(GetBindingText(GetBindingKey(button.bindingAction), 1))
MainActionBar = Frame("MainActionBar")
MainActionBar.actionButtons = { button }
MainActionBar.isShownExternal = true
MainActionBar.visibility = "Always"
function MainActionBar:UpdateVisibility()
    if self.isShownExternal == false then self:Hide(true) else self:Show(true) end
end
OverrideActionBar = Frame("OverrideActionBar")
OverrideActionBar.shown = false
MultiBarBottomLeft = Frame("MultiBarBottomLeft")
GamepadMainActionBarFrame = Frame("GamepadMainActionBarFrame")
GamepadMainActionBarFrame.shown = false
local pet = Button("PetActionButton1", 1)

Enum = { InputDeviceInterfaceType = { Mkb = 1, Gamepad = 2 } }
InputUtil = { callbacks = {} }
function InputUtil.IsGamepadUIEnabled() return interfaceGamepad end
function InputUtil.RegisterForInterfaceTransitions() end
function InputUtil.RegisterGamepadInit(_, callback) InputUtil.callbacks.init = callback; if interfaceGamepad then callback() end end
function InputUtil.RegisterGamepadUninit(_, callback) InputUtil.callbacks.uninit = callback end
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(name, callback) self.callbacks[name] = callback end
EditModeManagerFrame = { IsEditModeActive = function() return false end }

local module, initializers = {}, {}
local ns = { RegisterModule = function(id, initialize) assert(id == "actionBars"); initializers[#initializers + 1] = initialize end }
PyresinQoLDB = { modules = { actionBars = true } }
assert(loadfile("Modules/ActionBars/Config.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/ActionBars/ActionBars.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/ActionBars/Visibility.lua"))("PyresinQoL", ns)
assert(#events == 0, "Runtime files must be API-free until the module starts")
for _, initialize in ipairs(initializers) do initialize(module) end
local expectedBarFrames = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
}
assert(#ns.ActionBars.bars == 8, "Action-bar scope contains exactly eight standard bars")
for index, frameName in ipairs(expectedBarFrames) do
    assert(ns.ActionBars.bars[index].frame == frameName, "Action-bar scope frame " .. index)
end

local function Fire(event)
    for _, frame in ipairs(events) do
        if frame.registered and frame.registered[event] then frame.scripts.OnEvent(frame, event, "Blizzard_ActionBar") end
    end
end
Fire("PLAYER_LOGIN")

PyresinQoLDB.actionBarColorIcons = true
PyresinQoLDB.actionBarColorHotkeys = true
PyresinQoLDB.actionBarCompactHotkeys = true
PyresinQoLDB.actionBarHotkeySize = 15
PyresinQoLDB.actionBarMacroSize = 14
PyresinQoLDB.actionBarCountSize = 13
module.UpdateActionBars()
assert(button.HotKey.text == "CSM4" and button.HotKey.size == 15 and button.Name.size == 14 and button.Count.size == 13)
button.action, usable, noMana = 2, false, true
button:UpdateUsable()
ActionButton_UpdateRangeIndicator(button, true, false)
assert(button.icon.color[3] == 1 and button.icon.color[1] > .3,
    "A new public slot refreshes usability without waiting for an event")
local callsBeforeSecret = usableCalls
button.action = Secret(3)
button:UpdateUsable()
assert(usableCalls == callsBeforeSecret, "Secret action slots are never passed to IsUsableAction")
button.action, usable, noMana = 1, true, false
button:UpdateUsable(nil, true, false)
ActionButton_UpdateRangeIndicator(button, true, false)
assert(button.icon.color[1] == 1 and button.icon.color[2] < .3,
    "Out of range colors the whole icon: " .. table.concat(button.icon.color, ","))
usable, noMana = false, false; button:UpdateUsable(nil, false, false)
assert(button.icon.color[1] < .5 and button.icon.color[2] > .3, "Unusable takes priority over range")
usable, noMana = false, Secret(true); button:UpdateUsable(nil, false, Secret(true))
assert(button.icon.color[3] == 1 and button.HotKey.color[3] == 1, "Secret no-resource state has highest priority")
button:UpdateUsable(nil, Secret(false), Secret(false))
for _, region in ipairs({ button.icon, button.HotKey }) do
    assert(region.color[1] == .4 and region.color[2] == .4 and region.color[3] == .4 and region.color[4] == 1,
        "Secret false usability flags select gray for both icons and hotkeys")
end
button:UpdateUsable(nil, Secret(true), Secret(false))
for _, region in ipairs({ button.icon, button.HotKey }) do
    assert(region.color[1] == 1 and region.color[2] == .2 and region.color[3] == .2,
        "Secret false resource flags preserve the out-of-range color for usable actions")
end
pet:UpdateUsable(nil, false, true)
assert(pet.icon.color[1] == .5, "Global hooks must not restyle unsupported action buttons")

-- Paging and empty slots must invalidate both usability and range state.  The
-- native UpdateUsable call supplies the empty-slot styling; the addon must not
-- reapply the previous action's tint from its cache.
button.action, usable, noMana = 1, false, false
button:UpdateUsable(nil, false, false)
ActionButton_UpdateRangeIndicator(button, true, false)
assert(button.icon.color[1] < .5, "A populated slot gets the configured unusable tint")
local callsBeforeEmpty = usableCalls
button.action, usable, noMana = nil, true, false
button:Update()
assert(usableCalls == callsBeforeEmpty and button.icon.color[1] == 1,
    "An empty slot clears stale usability and range tint without querying a secret slot")
button.action = 4
button:Update()
assert(usableCalls > callsBeforeEmpty, "A newly paged public slot refreshes usability")
PyresinQoLDB.actionBarColorHotkeys = false
module.UpdateActionBars()
local nativeHotkeyColor = { unpack(button.HotKey.color) }
PyresinQoLDB.actionBarColorHotkeys = true
usable, noMana = false, true
button:UpdateUsable(nil, false, true)
button:UpdateHotkeys()
assert(button.HotKey.color[3] == 1 and button.HotKey.color[1] < 1,
    "Repeated hotkey updates retain the configured tint")
PyresinQoLDB.actionBarColorHotkeys = false
module.UpdateActionBars()
assert(button.HotKey.color[1] == nativeHotkeyColor[1]
    and button.HotKey.color[2] == nativeHotkeyColor[2]
    and button.HotKey.color[3] == nativeHotkeyColor[3],
    "Disabling hotkey colors after an update restores the native color")

PyresinQoLDB.actionBarColorIcons, PyresinQoLDB.actionBarColorHotkeys = false, false
PyresinQoLDB.actionBarCompactHotkeys = false
PyresinQoLDB.actionBarHotkeySize, PyresinQoLDB.actionBarMacroSize, PyresinQoLDB.actionBarCountSize = 0, 0, 0
usable, noMana = false, true
module.UpdateActionBars()
assert(button.icon.color[1] == .5 and button.icon.color[3] == 1, "Disabling colors restores native usable styling")
assert(button.HotKey.size == 11 and button.Name.size == 10 and button.Count.size == 9, "Zero restores exact native fonts")
assert(button.HotKey.text == "CTRL-SHIFT-BUTTON4", "Disabling compact bindings regenerates native text")
GetBindingKey = function() return nil end
button:UpdateHotkeys(); module.UpdateActionBars()
assert(button.HotKey.text == RANGE_INDICATOR, "Compact bindings never rewrite the native range sentinel")

local prefix = "actionBarMain"
PyresinQoLDB[prefix .. "Enabled"] = true
PyresinQoLDB[prefix .. "HideCombat"] = true
PyresinQoLDB[prefix .. "AlphaNormal"] = .25
PyresinQoLDB[prefix .. "AlphaCombat"] = .5
PyresinQoLDB[prefix .. "Mouseover"] = true
PyresinQoLDB[prefix .. "CustomCondition"] = "[bar:2] hide; show"
module.UpdateActionBars()
local visibility
for _, handler in ipairs(handlers) do if handler:GetFrameRef("bar") == MainActionBar then visibility = handler end end
assert(visibility and visibility.drivers.barvisibility:find("%[combat%] hide")
    and visibility.drivers.barvisibility:find("%[bar:2%] hide; show"))
PyresinQoLDB[prefix .. "HideOutOfCombat"] = true
PyresinQoLDB[prefix .. "HideStealth"] = true
PyresinQoLDB[prefix .. "HideNotStealth"] = true
PyresinQoLDB[prefix .. "HideForm"] = true
PyresinQoLDB[prefix .. "HideNoForm"] = true
module.UpdateActionBars()
local visibilityDriver = visibility.drivers.barvisibility
assert(visibilityDriver:find("%[nocombat%] hide")
    and visibilityDriver:find("%[stealth%] hide")
    and visibilityDriver:find("%[nostealth%] hide")
    and visibilityDriver:find("%[stance%] hide")
    and visibilityDriver:find("%[nostance%] hide"),
    "Combat, stealth, form and custom secure clauses are all registered")
PyresinQoLDB[prefix .. "HideOutOfCombat"] = false
PyresinQoLDB[prefix .. "HideStealth"] = false
PyresinQoLDB[prefix .. "HideNotStealth"] = false
PyresinQoLDB[prefix .. "HideForm"] = false
PyresinQoLDB[prefix .. "HideNoForm"] = false
module.UpdateActionBars()
assert(MainActionBar.alpha == .25)
button.scripts.OnEnter(); assert(MainActionBar.alpha == 1, "Mouseover reveals only by alpha")
button.scripts.OnLeave(); assert(MainActionBar.alpha == .25)
SetState(visibility, "barvisibility", "hide")
assert(not MainActionBar.shown, "Conditional visibility performs a real protected hide")
assert(visibility:IsShown(), "Hide rules target the action bar, not the registered handler")
SetState(visibility, "barvisibility", "show"); assert(MainActionBar.shown)
SetState(visibility, "barvisibility", "hide")
MainActionBar:Hide(true)
MainActionBar.isShownExternal = false
MainActionBar:UpdateVisibility()
SetState(visibility, "barvisibility", "show")
assert(not MainActionBar.shown and visibility:GetAttribute("externalShown") == false,
    "Releasing a rule must preserve an OOC native hide, even if the frame was already custom-hidden")
MainActionBar.isShownExternal = true
MainActionBar:UpdateVisibility()
assert(MainActionBar.shown, "An OOC native show releases the preserved native hide")

local registrations = #stateDrivers
inCombat = true
PyresinQoLDB[prefix .. "HideCombat"] = false
module.UpdateActionBars()
assert(#stateDrivers == registrations, "Protected config updates defer in combat")

local directAttribute, directExecute, directRegister = pcall(function()
    visibility:SetAttribute("combatWrite", true)
end), pcall(function()
    visibility:Execute("return self")
end), pcall(function()
    RegisterStateDriver(visibility, "barvisibility", "show")
end)
assert(not directAttribute and not directExecute and not directRegister,
    "Protected handler mutation and driver registration reject insecure combat calls")

SetState(visibility, "barvisibility", "hide")
MainActionBar.isShownExternal = false
MainActionBar:UpdateVisibility()
module.UpdateActionBars()
assert(visibility:GetAttribute("externalShown") == true,
    "Combat native visibility updates defer while a custom hide is active")
inCombat = false; Fire("PLAYER_REGEN_ENABLED")
assert(visibility:GetAttribute("externalShown") == false,
    "Deferred OOC reconciliation captures a native hide")
SetState(visibility, "barvisibility", "show")
assert(not MainActionBar.shown, "A combat native hide remains hidden after the rule releases")
MainActionBar.isShownExternal = true
MainActionBar:UpdateVisibility()
assert(MainActionBar.shown, "A later OOC native show restores the bar")

MainActionBar.underMouse = true
button.scripts.OnEnter()
SetState(visibility, "alpha", "combat")
assert(MainActionBar.alpha == 1, "Mouseover keeps alpha visible across combat alpha transitions")
MainActionBar.underMouse = false
button.scripts.OnLeave()
SetState(visibility, "alpha", "combat")
assert(MainActionBar.alpha == .5, "Leaving hover applies combat alpha")

inCombat = true
interfaceGamepad = true; InputUtil.callbacks.init(); GamepadMainActionBarFrame:Show()
SetState(visibility, "barvisibility", "hide")
assert(MainActionBar.shown, "Controller mode suspends action-bar visibility rules")
inCombat = false; Fire("PLAYER_REGEN_ENABLED")
assert(visibility:GetAttribute("suspended"), "Deferred controller transition remains suspended")
interfaceGamepad = false; GamepadMainActionBarFrame:Hide(); InputUtil.callbacks.uninit()
MainActionBar.isShownExternal = true
MainActionBar:Show(true) -- native MainActionBar_InitializeMKB handoff
PyresinQoLDB[prefix .. "HideCombat"] = true; module.UpdateActionBars()
SetState(visibility, "barvisibility", "hide")
assert(not MainActionBar.shown, "Saved visibility resumes after controller mode")

-- Native gamepad setup can hide MainActionBar before or after the root frame
-- becomes visible.  A custom hide must survive either order.
SetState(visibility, "barvisibility", "show")
assert(MainActionBar.shown)
SetState(visibility, "barvisibility", "hide")
local showCallsBeforeController = MainActionBar.showCalls
interfaceGamepad = true; InputUtil.callbacks.init()
MainActionBar:Hide(true)
GamepadMainActionBarFrame:Show()
assert(not MainActionBar.shown and MainActionBar.showCalls == showCallsBeforeController,
    "Controller root Show cannot resurrect a custom-hidden MainActionBar")
GamepadMainActionBarFrame:Hide(); interfaceGamepad = false; InputUtil.callbacks.uninit()
MainActionBar.isShownExternal = true
MainActionBar:Show(true) -- native MainActionBar_InitializeMKB handoff
assert(not MainActionBar.shown, "MKB native show is still intercepted by the configured custom hide")

SetState(visibility, "barvisibility", "show")
assert(MainActionBar.shown)
SetState(visibility, "barvisibility", "hide")
interfaceGamepad = true; InputUtil.callbacks.init()
GamepadMainActionBarFrame:Show()
MainActionBar:Hide(true)
assert(not MainActionBar.shown,
    "MainActionBar remains hidden when controller root Show precedes native Main hide")
GamepadMainActionBarFrame:Hide(); interfaceGamepad = false; InputUtil.callbacks.uninit()
MainActionBar.isShownExternal = true
MainActionBar:Show(true) -- native MKB initialization after the opposite callback order
assert(not MainActionBar.shown, "MKB native show cannot bypass the configured custom hide")
SetState(visibility, "barvisibility", "show")
assert(MainActionBar.shown, "MKB return restores the custom visibility state")

-- A skinned override bar owns MainActionBar while it is visible.  Native
-- MainActionBar hides can be redundant because the custom rule already hid it.
SetState(visibility, "barvisibility", "hide")
assert(not MainActionBar.shown)
inCombat = true
OverrideActionBar:Show(true)
MainActionBar:Hide(true)
SetState(visibility, "barvisibility", "show")
assert(not MainActionBar.shown,
    "OverrideActionBar ownership blocks a custom show after a combat native hide")
inCombat = false
OverrideActionBar:Hide(true)
MainActionBar:Show(true) -- native non-skinned/normal transition
SetState(visibility, "barvisibility", "hide"); SetState(visibility, "barvisibility", "show")
assert(MainActionBar.shown, "MainActionBar remains available after the override bar hides")

assert(MultiBarBottomLeft.alpha == 1 and MultiBarBottomLeft.showCalls == 0
    and MultiBarBottomLeft.hideCalls == 0 and next(MultiBarBottomLeft.attributes) == nil,
    "Disabled bars have no controller or visibility side effects")

inCombat = true
local editingAttributeBefore = visibility:GetAttribute("editing")
local suspendedAttributeBefore = visibility:GetAttribute("suspended")
EventRegistry.callbacks["EditMode.Enter"]()
EventRegistry.callbacks["EditMode.Exit"]()
assert(visibility:GetAttribute("editing") == editingAttributeBefore
    and visibility:GetAttribute("suspended") == suspendedAttributeBefore,
    "Edit Mode exit defers protected attribute changes during combat")
inCombat = false; Fire("PLAYER_REGEN_ENABLED")

EventRegistry.callbacks["EditMode.Enter"](); assert(MainActionBar.alpha == 1 and visibility:GetAttribute("suspended"))
EventRegistry.callbacks["EditMode.Exit"](); assert(not visibility:GetAttribute("suspended"))

visibilityResult = "hide"
module.UpdateActionBars()
assert(not MainActionBar.shown)
EventRegistry.callbacks["EditMode.Enter"]()
assert(MainActionBar.shown, "Edit Mode previews a bar hidden by its current rule")
EventRegistry.callbacks["EditMode.Exit"]()
assert(not MainActionBar.shown, "An unchanged hide state must resume when Edit Mode closes")
visibilityResult = "show"
module.UpdateActionBars()

PyresinQoLDB[prefix .. "CustomCondition"] = "[combat] RunScript(); hide"
module.UpdateActionBars()
assert(not visibility.drivers.barvisibility:find("RunScript", 1, true), "Invalid custom conditions fall back safely")
for _, registration in ipairs(stateDrivers) do assert(registration.frame ~= MainActionBar, "Never replace native visibility drivers") end

SetState(visibility, "barvisibility", "hide")
PyresinQoLDB[prefix .. "Enabled"] = false
module.UpdateActionBars()
assert(not visibility.drivers.barvisibility and not visibility.drivers.alpha,
    "Disabling a bar unregisters both custom state drivers")
assert(MainActionBar.shown and MainActionBar.alpha == 1,
    "Disabling a hide rule restores the bar it hid and its native opacity")

print("PASS: action-bar colors, secret precedence, native restore, compact bindings and exact fonts")
print("PASS: secure hides, alpha mouseover, combat deferral, controller suspension, Edit Mode and native hidden state")
if nativeDriver then print("PASS: visibility scenarios use Blizzard's SecureStateDriver.lua") end
