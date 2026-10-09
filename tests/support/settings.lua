-- Settings-specific game API doubles; each scenario starts in a fresh Lua process.
local variant = ...
local h = {
    ns = {}, settings = {}, sections = {}, navigation = {}, profileDropdowns = {},
    groupButtons = {}, logos = {}, addonButtonCount = 0,
    updates = {
        performance = 0, dungeonMap = 0, experience = 0, quest = 0, sparkle = 0, pixelPerfect = 0,
        statusText = 0, player = 0, druidMana = 0, threat = 0, nameplate = 0, combo = 0,
        debuff = 0, aura = 0, tooltip = 0, actionBar = 0,
    },
}
local ns, settings, updates = h.ns, h.settings, h.updates
local addonContext = false
local category = {}
function CopyTable(value)
    local copy = {}
    for key, item in pairs(value) do copy[key] = type(item) == "table" and CopyTable(item) or item end
    return copy
end
function GetLocale() return variant == "de" and "deDE" or "enUS" end
function UnitGUID() return nil end
function UnitName() return "Test character" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
ns.GetModule("performance").UpdatePerformanceLayout = function() updates.performance = updates.performance + 1 end
ns.GetModule("dungeonMaps").UpdateDungeonMaps = function() updates.dungeonMap = updates.dungeonMap + 1 end
ns.GetModule("experience").UpdateExperience = function() updates.experience = updates.experience + 1 end
ns.GetModule("quests").UpdateQuestLevels = function() updates.quest = updates.quest + 1 end
ns.GetModule("quests").UpdateQuestSparkles = function() updates.sparkle = updates.sparkle + 1 end
ns.GetModule("editMode").UpdatePixelPerfectMode = function() updates.pixelPerfect = updates.pixelPerfect + 1 end
ns.GetModule("editMode").UpdateSettingsDialog = function() end
ns.GetModule("unitFrames").UpdateStatusText = function() updates.statusText = updates.statusText + 1 end
ns.GetModule("unitFrames").UpdatePlayerFrame = function() updates.player = updates.player + 1 end
ns.GetModule("unitFrames").UpdateDruidMana = function() updates.druidMana = updates.druidMana + 1 end
ns.GetModule("unitFrames").UpdateTargetThreat = function() updates.threat = updates.threat + 1 end
ns.GetModule("unitFrames").UpdateNameplateThreat = function() updates.nameplate = updates.nameplate + 1 end
ns.GetModule("unitFrames").UpdateNameplateComboPoints = function() updates.combo = updates.combo + 1 end
ns.GetModule("unitFrames").UpdateTargetDebuffs = function() updates.debuff = updates.debuff + 1 end
ns.GetModule("unitFrames").UpdatePlayerAuras = function() updates.aura = updates.aura + 1 end
ns.GetModule("tooltips").UpdateTooltips = function() updates.tooltip = updates.tooltip + 1 end
ns.GetModule("actionBars").UpdateActionBars = function() updates.actionBar = updates.actionBar + 1 end
PyresinQoLDB = variant == "disabled" and { cooldownShortcut = false, showPerformance = false } or {}
DEFAULTS, CLOSE = "Defaults", "Close"
SETTINGS_SEARCH_RESULTS, SETTINGS_SEARCH_NOTHING_FOUND = "Search Results", "No settings found"
StaticPopupDialogs = {}
EventRegistry = { RegisterCallback = function() end, TriggerEvent = function() end }
UISpecialFrames, SlashCmdList = {}, {}
UIParent = { GetWidth = function() return 1280 end, GetHeight = function() return 800 end,
    GetEffectiveScale = function() return 0.8 end }
SettingsPanel = { shown = true, IsShown = function(self) return self.shown end }
function SetCVar() error("Settings must leave Blizzard's status-text CVars alone") end
local settingsRegistrant
SettingsRegistrar = { AddRegistrant = function(_, callback) settingsRegistrant = callback end }
PyresinQoLDB.playerHPFormat = "percent"
PyresinQoLDB.playerManaFormat = "value"
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
local function Widget(kind)
    local widget = { scripts = {}, points = {}, shown = true, registered = {}, kind = kind }
    function widget:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function widget:ClearAllPoints() self.points = {} end
    function widget:SetAllPoints() end
    function widget:SetFrameStrata(value) self.strata = value end
    function widget:SetToplevel(value) self.toplevel = value end
    function widget:SetMovable(value) self.movable = value end
    function widget:SetClampedToScreen(value) self.clamped = value end
    function widget:EnableMouse() end
    function widget:RegisterForDrag() end
    function widget:StartMoving() self.moving = true end
    function widget:StopMovingOrSizing() self.moving = false end
    function widget:SetScale(value) self.scale = value end
    function widget:Raise() self.raised = true end
    function widget:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow() end end
    function widget:IsShown() return self.shown end
    function widget:SetSize(w, h) self.width, self.height = w, h end
    function widget:SetWidth(w) self.width = w end
    function widget:SetHeight(h) self.height = h end
    function widget:SetEnabled(value) self.enabled = value end
    function widget:SetupMenu(generator) self.menuGenerator = generator end
    function widget:GenerateMenu() end -- Profile menu behavior is exercised in tests/integration/core/profiles.lua.
    function widget:SetText(value)
        local changed = self.value ~= value
        self.value = value
        if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function widget:GetText() return self.value or "" end
    function widget:SetMaxBytes(value) self.maxBytes = value end
    function widget:ClearFocus() self.focused = false end
    function widget:SetDefaultText(value) self.defaultText = value end
    function widget:SetTextColor(...) self.color = { ... } end
    function widget:SetFontObject(value) self.font = value end
    function widget:SetWordWrap(value) self.wordWrap = value end
    function widget:SetMaxLines(value) self.maxLines = value end
    function widget:SetJustifyH() end
    function widget:SetColorTexture() end
    function widget:SetTexture(path)
        self.texture = path
        if path == "Interface\\AddOns\\PyresinQoL\\Media\\AddonIcon" then h.logos[#h.logos + 1] = self end
    end
    function widget:SetAtlas(atlas, useAtlasSize) self.atlas, self.useAtlasSize = atlas, useAtlasSize end
    function widget:SetRotation(value) self.rotation = value end
    function widget:SetHighlightTexture() end
    function widget:DisableDrawLayer() end
    function widget:IsObjectType(value) return self.kind == value end
    function widget:CreateTexture() return Widget("Texture") end
    function widget:CreateFontString() return Widget("FontString") end
    function widget:Hide() self.shown = false end
    function widget:SetShown(value) self.shown = value end
    function widget:SetScript(event, callback)
        self.scripts[event] = callback
        if event == "OnEvent" then self.callback = callback end
    end
    function widget:HookScript(event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(...)
            if original then original(...) end
            callback(...)
        end
    end
    function widget:RegisterEvent(event)
        self.registered[event] = true
        if event == "ADDON_LOADED" and not h.events then h.events = self end
        if event == "PLAYER_REGEN_DISABLED" and not h.combatEvents then h.combatEvents = self end
    end
    function widget:UnregisterEvent(event) self.registered[event] = nil end
    return widget
end
local function Initializer(name, kind, setting, tooltip)
    local initializer = { data = { name = name, setting = setting, tooltip = tooltip }, kind = kind }
    function initializer:GetName() return self.data.name end
    function initializer:GetTooltip() return self.data.tooltip end
    function initializer:IsTemplate(template) return self.template == template end
    function initializer:AddSearchTags(...)
        self.searchTags = self.searchTags or {}
        for index = 1, select("#", ...) do
            local tag = select(index, ...)
            if type(tag) == "string" and tag ~= "" then
                self.searchTags[#self.searchTags + 1] = tag:upper()
            end
        end
    end
    function initializer:MatchesSearchTags(words)
        for _, word in ipairs(words) do
            for _, tag in ipairs(self.searchTags or {}) do
                local first, last = tag:find(word, 1, true)
                if first then return last - first end
            end
        end
    end
    function initializer:SetParentInitializer(parent, predicate)
        assert(parent.kind ~= "section", "Expandable sections are not setting parents")
        self.parentInitializer, self.parentPredicate = parent, predicate
    end
    function initializer:AddModifyPredicate(predicate) self.modifyPredicate = predicate end
    function initializer:AddShownPredicate(predicate) self.predicate = predicate end
    function initializer:ShouldShow() return not self.predicate or self.predicate() end
    function initializer:InitFrame(frame)
        if kind == "section" then
            frame.Button = Widget(); frame.Button.Text = Widget()
        else
            frame.Text, frame.Tooltip = Widget(), Widget()
            frame.Text:SetPoint("LEFT", 37, 0)
            frame.Text:SetPoint("RIGHT", frame, "CENTER", -85, 0)
            frame[kind] = Widget()
            if kind == "Control" then frame.Control.Dropdown = Widget() end
        end
    end
    return initializer
end
function CreateSettingsButtonInitializer(name, text, callback, tooltip, addSearchTags)
    assert(addSearchTags ~= nil, "Forever requires an explicit addSearchTags argument")
    assert(name and text and type(callback) == "function" and tooltip ~= "")
    local button = Initializer(name, "Button", nil, tooltip)
    if addSearchTags then button:AddSearchTags(name, text) end
    local original = button.InitFrame
    function button:InitFrame(frame)
        original(self, frame)
        frame.Button:SetScript("OnClick", callback)
    end
    return button
end
function CreateSettingsListSectionHeaderInitializer(name)
    local header = Initializer(name)
    header.template = "SettingsListSectionHeaderTemplate"
    function header:InitFrame(frame)
        frame.Title = Widget()
        frame.Title:SetText(name)
    end
    return header
end
function CreateSettingsExpandableSectionInitializer(name)
    local section = Initializer(name, "section")
    h.sections[#h.sections + 1] = section
    return section
end
local nativeNameplates = {}
Settings = {
    CreateElementInitializer = function(template)
        assert(template == "SettingsListSearchCategoryTemplate")
        return Initializer(nil, "searchCategory")
    end,
    NAMEPLATE_OPTIONS_CATEGORY_ID = 42,
    CreateDropdown = function(owner, setting, options, tooltip)
        assert(owner == nativeNameplates and setting == settings.nameplateThreatPosition
            and #options() == 4 and tooltip == ns.L.nameplateThreatPositionHelp)
        h.nativeThreatPosition = Initializer(setting.name, "Control")
        h.nativeThreatPosition.setting = setting
        return h.nativeThreatPosition
    end,
    GetCategory = function(id) assert(id == 42); return nativeNameplates end,
    CreateCheckbox = function(owner, setting, tooltip)
        if setting == settings.nameplateComboPoints then
            assert(owner == nativeNameplates and tooltip == ns.L.nameplateComboPointsHelp)
            h.nativeComboCheckbox = Initializer(setting.name, "Checkbox")
            h.nativeComboCheckbox.setting = setting
            return h.nativeComboCheckbox
        end
        assert(owner == nativeNameplates and setting == settings.nameplateThreat and tooltip == ns.L.nameplateThreatHelp)
        h.nativeThreatCheckbox = Initializer(setting.name, "Checkbox")
        h.nativeThreatCheckbox.setting = setting
        return h.nativeThreatCheckbox
    end,
    GetSetting = function() error("Settings must leave Blizzard's native settings alone") end,
    RegisterProxySetting = function() error("Do not register a duplicate status-text setting") end,
    VarType = { Boolean = "boolean", String = "string", Number = "number" },
    RegisterCanvasLayoutCategory = function(frame, name)
        assert(not h.launcher and name == "PyresinQoL")
        h.launcher = frame
        return category
    end,
    RegisterVerticalLayoutCategory = function() error("Settings must be embedded as one canvas") end,
    RegisterVerticalLayoutSubcategory = function() error("No extra Blizzard sidebar categories") end,
    RegisterAddOnCategory = function(value) assert(value == category) end,
    RegisterAddOnSetting = function(owner, variable, key, db, valueType, name, default)
        assert(owner == category and name ~= "")
        if db[key] == nil then db[key] = default end
        local setting = { name = name, key = key, valueType = valueType }
        function setting:SetValueChangedCallback(callback) assert(callback); self.callback = callback end
        function setting:GetValue() return db[key] end
        function setting:NotifyUpdate() self.callback(self, db[key]) end
        function setting:SetValue(value)
            db[key] = value
            addonContext = true
            self.callback(self, value)
            addonContext = false
        end
        settings[variable:match("^PyresinQoL_Module_") and variable or key] = setting
        return setting
    end,
    CreateCheckboxInitializer = function(setting, options, tooltip)
        assert(setting and tooltip ~= "")
        local initializer = Initializer(setting.name, "Checkbox", setting, tooltip)
        initializer.data.options = options
        return initializer
    end,
    CreateControlTextContainer = function()
        local container = { data = {} }
        function container:Add(value, label) self.data[#self.data + 1] = { value = value, label = label } end
        function container:GetData() return self.data end
        return container
    end,
    CreateDropdownInitializer = function(setting, options, tooltip)
        local count = (setting.key == "tooltipAnchor" or setting.key == "tooltipCursorAnchor") and 3
            or setting.key:match("TimerPosition$") and 5
            or (setting.key == "flightTimerStyle" or setting.key == "flightTimerMarker" or setting.key == "flightTimerFlags" or setting.key == "flightTimerOverlap") and 4
            or (setting.key == "buffOwn" or setting.key == "debuffOwn" or setting.key == "buffSort" or setting.key == "debuffSort") and 3
            or setting.key == "tooltipAnchorPoint" and 9
            or (setting.key == "nameplateThreatPosition" or setting.key == "targetThreat") and 4 or setting.key:match("Position$") and 9
            or setting.key == "xpTextFormat" and 4 or 2
        assert(setting and #options() == count)
        for _, option in ipairs(options()) do assert(option.label and option.label ~= "") end
        if setting.key == "targetThreat" then
            assert(setting.valueType == Settings.VarType.String)
            for index, mode in ipairs({ "off", "auto", "combat", "always" }) do
                assert(options()[index].value == mode and options()[index].label == ns.L["targetThreat_" .. mode])
            end
        end
        return Initializer(setting.name, "Control", setting, tooltip)
    end,
    CreateColorSwatchInitializer = function(setting)
        assert(setting)
        return Initializer(setting.name, "ColorSwatch", setting)
    end,
    CreateSliderOptions = function(minimum, maximum, step)
        assert((minimum == 0 and maximum == 40 and step == 1)
            or (step == 1 and (minimum == 1 or minimum == 8 or minimum == 16 or minimum == 32 or minimum == 0 and (maximum == 16 or maximum == 24)))
            or (minimum == 100 and maximum == 600 and step == 1)
            or (minimum == -2500 and maximum == 2500 and step == 1)
            or (minimum == 0 and maximum == 1 and step == 0.01))
        return { SetLabelFormatter = function(_, label, formatter)
            assert(label == MinimalSliderWithSteppersMixin.Label.Right)
            assert(minimum == 0 and maximum == 1 and formatter(0.12) == "12%"
                or maximum ~= 1 and (formatter(12) == "12 px" or formatter(12) == "12"))
        end }
    end,
    CreateSliderInitializer = function(setting, options, tooltip)
        assert(setting and options)
        return Initializer(setting.name, "SliderWithSteppers", setting, tooltip)
    end,
}
GAMEMENU_OPTIONS = "Options"
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
function InCombatLockdown() return h.combat end
InputUtil = { IsGamepadUIEnabled = function() return h.controller end }
function PlaySound(value) h.sound = value end
function HideUIPanel(frame)
    h.hidden = frame
    frame.shown = false
    if frame.scripts and frame.scripts.OnHide then frame.scripts.OnHide() end
end
CooldownViewerSettings = {
    ShowUIPanel = function(_, fromEditMode)
        assert(h.hidden == GameMenuFrame and fromEditMode == false)
        h.opened = true
    end,
}
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    SetText = function(self, text) self.text = text end,
    AddLine = function(self, text) self.line = text end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false; self.owner = nil end,
    IsOwned = function(self, owner) return self.owner == owner end,
}
function GameTooltip_AddErrorLine(tooltip, text) tooltip.error = text end
function CreateFrame(kind, name, parent, template)
    if template == "GameMenuFrameButtonTemplate" then
        assert(parent == UIParent, "The shortcut must stay outside Blizzard's layout and controller navigation")
        h.addonButtonCount = h.addonButtonCount + 1
        h.addonButton = { scripts = {} }
        function h.addonButton:SetScript(event, callback) self.scripts[event] = callback end
        function h.addonButton:SetText(text) self.text = text end
        function h.addonButton:SetMotionScriptsWhileDisabled(value) assert(value) end
        function h.addonButton:SetSize(width, height) self.width, self.height = width, height end
        function h.addonButton:ClearAllPoints() self.point = nil end
        function h.addonButton:SetPoint(...) self.point = { ... } end
        function h.addonButton:SetFrameStrata(value) self.strata = value end
        function h.addonButton:SetFrameLevel(value) self.level = value end
        function h.addonButton:SetScale(value) self.scale = value end
        function h.addonButton:SetEnabled(value) self.enabled = value end
        function h.addonButton:Show() self.shown = true end
        function h.addonButton:Hide() self.shown = false end
        return h.addonButton
    end
    local frame = Widget(kind)
    frame.parent = parent
    if template == "SearchBoxTemplate" then frame.value = "" end
    if kind == "Frame" and parent == h.settingsList then h.profilePanel = frame end
    if kind == "DropdownButton" then h.profileDropdowns[#h.profileDropdowns + 1] = frame end
    if kind == "Button" and not template then h.navigation[#h.navigation + 1] = frame end
    if template == "SettingsFrameTemplate" then
        assert(parent == UIParent and name == "PyresinQoLSettingsFrame")
        h.canvas = frame
        frame.NineSlice = Widget()
        frame.NineSlice.Text = Widget()
        frame.ClosePanelButton = Widget()
    end
    if template == "SettingsCategoryListHeaderTemplate" then
        frame:SetHeight(30)
        frame.Background, frame.Label = Widget("Texture"), Widget("FontString")
        frame.Background:SetPoint("TOPLEFT")
        h.groupButtons[#h.groupButtons + 1] = frame
    end
    if template == "UIPanelButtonTemplate" then
        if parent == h.launcher then h.openButton = frame
        elseif parent == h.canvas then
            if not h.closeButton then h.closeButton = frame else h.reloadButton = frame end
        end
    end
    if template == "SettingsListTemplate" then
        h.settingsList = frame
        frame.Header = Widget()
        frame.Header.Title = Widget()
        frame.Header.DefaultsButton = Widget()
        local divider = Widget("Texture")
        function frame.Header:GetRegions() return divider end
        function frame:Display(initializers)
            self.displayCount = (self.displayCount or 0) + 1
            self.initializers, self.rendered = initializers, {}
            for _, initializer in ipairs(initializers) do
                if initializer:ShouldShow() then
                    local row = Widget()
                    if initializer.kind == "searchCategory" then row.Title = Widget() end
                    initializer:InitFrame(row)
                    self.rendered[#self.rendered + 1] = row
                end
            end
        end
    end
    return frame
end
function hooksecurefunc(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...)
        local result = original(self, ...)
        local previousContext = addonContext
        addonContext = true
        callback(self, ...)
        addonContext = previousContext
        return result
    end
end
GameMenuFrame = { shown = true, buttons = {}, builds = 0, scripts = {}, height = 174 }
function GameMenuFrame:IsShown() return self.shown end
function GameMenuFrame:GetFrameStrata() return "DIALOG" end
function GameMenuFrame:GetFrameLevel() return 5 end
function GameMenuFrame:GetEffectiveScale() return 1 end
function GameMenuFrame:GetHeight() return self.height end
function GameMenuFrame:SetHeight(value) self.height = value end
function GameMenuFrame:HookScript(event, callback) self.scripts[event] = callback end
function GameMenuFrame:Reset() self.buttons = {} end
function GameMenuFrame:MarkDirty() error("Addon settings must not dirty Blizzard's menu layout") end
function GameMenuFrame:AddButton(text, callback, disabled)
    assert(not addonContext, "Addon code must not acquire Blizzard menu buttons from its shared pool")
    local button = { text = text, scripts = { OnClick = callback }, enabled = not disabled }
    function button:SetScript(event, handler) self.scripts[event] = handler end
    function button:SetEnabled(enabled) self.enabled = enabled end
    function button:GetText() return self.text end
    function button:GetSize() return 200, 36 end
    function button:GetPoint() return unpack(self.point) end
    function button:ClearAllPoints() self.point = nil end
    function button:SetPoint(...) self.point = { ... } end
    button.layoutIndex = #self.buttons + 1
    self.buttons[#self.buttons + 1] = button
    return button
end
function GameMenuFrame:InitButtons()
    assert(not addonContext, "Addon settings must not recreate native menu callbacks")
    self.builds = self.builds + 1
    self:Reset()
    local options = GameMenuFrame:AddButton(GAMEMENU_OPTIONS, function() end)
    GameMenuFrame:AddButton("Shop", function() end)
    assert(options == GameMenuFrame.buttons[1], "Hook must preserve the Options return value")
end
function GameMenuFrame:Layout()
    assert(not addonContext, "Only Blizzard may run its native layout")
    self.height = 174
    for index, button in ipairs(self.buttons) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self, "TOPLEFT", 28, -48 - (index - 1) * 56)
    end
end
function h.BuildMenu()
    GameMenuFrame:InitButtons()
    GameMenuFrame:Layout()
    assert(#GameMenuFrame.buttons == 2, "Native button list must remain untouched")
    assert(h.addonButtonCount == 1 and h.addonButton.shown and h.addonButton.text == ns.L.cooldownMenu)
    assert(h.addonButton.width == 200 and h.addonButton.height == 36)
    assert(h.addonButton.layoutIndex == nil, "Shortcut must not participate in native layout")
    assert(h.addonButton.point[1] == "TOPLEFT" and h.addonButton.point[2] == GameMenuFrame.buttons[1]
        and h.addonButton.point[3] == "BOTTOMLEFT", "Shortcut must be a row below Options inside the menu")
    assert(GameMenuFrame.height == 210 and GameMenuFrame.buttons[2].point[5] == -140,
        "The menu and following buttons must make room for exactly one shortcut row")
    assert(h.addonButton.scale == 1.25, "The separate button must match the native menu scale")
    return h.addonButton
end

if variant == "modules-disabled" then
    PyresinQoLDB.modules = {}
    for _, module in ipairs(ns.modules) do PyresinQoLDB.modules[module.id] = false end
    for _, module in ipairs(ns.modules) do
        for name in pairs(module) do
            if name:match("^Update") then module[name] = nil end
        end
    end
end
assert(loadfile("Modules/GameMenu/GameMenu.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Database.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Profiles.lua"))("PyresinQoL", ns)
assert(loadfile("Settings/Controls.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/CastBar/Config.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/CastBar/Textures.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/CastBar/Presentation.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/CastBar/Native.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/CastBar/EditMode.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/ActionBars/Config.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/ActionBars/ActionBars.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/ActionBars/Visibility.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/GameMenu/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/EditMode/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Performance/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/DungeonMaps/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Experience/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/Options.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/FlightTimer/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Quests/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/UnitFrames/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Tooltips/Settings.lua"))("PyresinQoL", ns)
-- Addon settings may add popup definitions, but reassigning a Blizzard global
-- taints later native users of that registry, including Escape handlers.
local actionBarSettings = assert(loadfile("Modules/ActionBars/Settings.lua"))
setfenv(actionBarSettings, setmetatable({}, {
    __index = _G,
    __newindex = function(_, key)
        error("Action bar settings must not overwrite the native global " .. key)
    end,
}))("PyresinQoL", ns)
assert(loadfile("Settings/Window.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Bootstrap.lua"))("PyresinQoL", ns)
h.events.callback(h.events, "ADDON_LOADED", "OtherAddon")
GameMenuFrame.shown = false
h.events.callback(h.events, "ADDON_LOADED", "PyresinQoL")
assert(settingsRegistrant, "Native settings registration remains deferred")
settingsRegistrant()
function h.NavigationButton(name)
    for _, button in ipairs(h.navigation) do
        if button.text.value == name then return button end
    end
    error("Missing settings page: " .. name)
end

return h
