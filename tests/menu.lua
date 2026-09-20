-- Run from the addon directory: lua tests/menu.lua [disabled|de|modules-disabled]
local combat, events, opened, hidden, sound
local addonContext = false
local category = {}
local settings, checkboxCount, dropdownCount, colorCount, sliderCount, performanceUpdates = {}, 0, 0, 0, 0, 0
local sections, navigation = {}, {}
local canvas, launcher, settingsList, reloadButton, combatEvents, openButton, closeButton
local groupButtons = {}
local logos = {}
local ns = {}
function GetLocale() return arg[1] == "de" and "deDE" or "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Modules.lua"))("PyresinQoL", ns)
ns.GetModule("performance").UpdatePerformanceLayout = function() performanceUpdates = performanceUpdates + 1 end
local experienceUpdates = 0
ns.GetModule("experience").UpdateExperience = function() experienceUpdates = experienceUpdates + 1 end
local questUpdates = 0
ns.GetModule("quests").UpdateQuestLevels = function() questUpdates = questUpdates + 1 end
local pixelPerfectUpdates = 0
ns.GetModule("editMode").UpdatePixelPerfectMode = function() pixelPerfectUpdates = pixelPerfectUpdates + 1 end
local statusTextUpdates = 0
ns.GetModule("unitFrames").UpdateStatusText = function() statusTextUpdates = statusTextUpdates + 1 end
local playerUpdates = 0
ns.GetModule("unitFrames").UpdatePlayerFrame = function() playerUpdates = playerUpdates + 1 end
local druidManaUpdates = 0
ns.GetModule("unitFrames").UpdateDruidMana = function() druidManaUpdates = druidManaUpdates + 1 end
local threatUpdates = 0
ns.GetModule("unitFrames").UpdateTargetThreat = function() threatUpdates = threatUpdates + 1 end
local nameplateUpdates = 0
ns.GetModule("unitFrames").UpdateNameplateThreat = function() nameplateUpdates = nameplateUpdates + 1 end
local comboUpdates = 0
ns.GetModule("unitFrames").UpdateNameplateComboPoints = function() comboUpdates = comboUpdates + 1 end
local debuffUpdates = 0
ns.GetModule("unitFrames").UpdateTargetDebuffs = function() debuffUpdates = debuffUpdates + 1 end
local tooltipUpdates = 0
ns.GetModule("tooltips").UpdateTooltips = function() tooltipUpdates = tooltipUpdates + 1 end
PyresinQoLDB = arg[1] == "disabled" and { cooldownShortcut = false, showPerformance = false } or {}
DEFAULTS, CLOSE = "Defaults", "Close"
UISpecialFrames, SlashCmdList = {}, {}
UIParent = { GetWidth = function() return 1280 end, GetHeight = function() return 800 end }
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
    function widget:SetText(value) self.value = value end
    function widget:SetTextColor(...) self.color = { ... } end
    function widget:SetFontObject(value) self.font = value end
    function widget:SetWordWrap(value) self.wordWrap = value end
    function widget:SetMaxLines(value) self.maxLines = value end
    function widget:SetJustifyH() end
    function widget:SetColorTexture() end
    function widget:SetTexture(path)
        self.texture = path
        if path == "Interface\\AddOns\\PyresinQoL\\Media\\AddonIcon" then logos[#logos + 1] = self end
    end
    function widget:SetAtlas() end
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
    function widget:RegisterEvent(event)
        self.registered[event] = true
        if event == "ADDON_LOADED" then events = self end
        if event == "PLAYER_REGEN_DISABLED" and not combatEvents then combatEvents = self end
    end
    function widget:UnregisterEvent(event) self.registered[event] = nil end
    return widget
end
local function Initializer(name, kind)
    local initializer = { data = { name = name } }
    function initializer:SetParentInitializer() error("Expandable sections are not setting parents") end
    function initializer:AddModifyPredicate(predicate) self.modifyPredicate = predicate end
    function initializer:AddShownPredicate(predicate) self.predicate = predicate end
    function initializer:ShouldShow() return not self.predicate or self.predicate() end
    function initializer:InitFrame(frame)
        if kind == "section" then
            frame.Button = Widget(); frame.Button.Text = Widget()
        else
            frame.Text, frame.Tooltip = Widget(), Widget()
            frame[kind] = Widget()
            if kind == "Control" then frame.Control.Dropdown = Widget() end
        end
    end
    return initializer
end
function CreateSettingsListSectionHeaderInitializer(name)
    local header = Initializer(name)
    function header:InitFrame(frame)
        frame.Title = Widget()
        frame.Title:SetText(name)
    end
    return header
end
function CreateSettingsExpandableSectionInitializer(name)
    local section = Initializer(name, "section")
    sections[#sections + 1] = section
    return section
end
local nativeNameplates, nativeThreatCheckbox, nativeThreatPosition = {}, nil, nil
local nativeComboCheckbox
Settings = {
    NAMEPLATE_OPTIONS_CATEGORY_ID = 42,
    CreateDropdown = function(owner, setting, options, tooltip)
        assert(owner == nativeNameplates and setting == settings.nameplateThreatPosition
            and #options() == 4 and tooltip == ns.L.nameplateThreatPositionHelp)
        nativeThreatPosition = Initializer(setting.name, "Control")
        nativeThreatPosition.setting = setting
        return nativeThreatPosition
    end,
    GetCategory = function(id) assert(id == 42); return nativeNameplates end,
    CreateCheckbox = function(owner, setting, tooltip)
        if setting == settings.nameplateComboPoints then
            assert(owner == nativeNameplates and tooltip == ns.L.nameplateComboPointsHelp)
            nativeComboCheckbox = Initializer(setting.name, "Checkbox")
            nativeComboCheckbox.setting = setting
            return nativeComboCheckbox
        end
        assert(owner == nativeNameplates and setting == settings.nameplateThreat and tooltip == ns.L.nameplateThreatHelp)
        nativeThreatCheckbox = Initializer(setting.name, "Checkbox")
        nativeThreatCheckbox.setting = setting
        return nativeThreatCheckbox
    end,
    GetSetting = function() error("Settings must leave Blizzard's native settings alone") end,
    RegisterProxySetting = function() error("Do not register a duplicate status-text setting") end,
    VarType = { Boolean = "boolean", String = "string", Number = "number" },
    RegisterCanvasLayoutCategory = function(frame, name)
        assert(not launcher and name == "PyresinQoL")
        launcher = frame
        return category
    end,
    RegisterVerticalLayoutCategory = function() error("Settings must be embedded as one canvas") end,
    RegisterVerticalLayoutSubcategory = function() error("No extra Blizzard sidebar categories") end,
    RegisterAddOnCategory = function(value) assert(value == category) end,
    RegisterAddOnSetting = function(owner, variable, key, db, valueType, name, default)
        assert(owner == category and name ~= "")
        if db[key] == nil then db[key] = default end
        local setting = { name = name, key = key }
        function setting:SetValueChangedCallback(callback) assert(callback); self.callback = callback end
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
        checkboxCount = checkboxCount + 1
        return Initializer(setting.name, "Checkbox")
    end,
    CreateControlTextContainer = function()
        local container = { data = {} }
        function container:Add(value, label) self.data[#self.data + 1] = { value = value, label = label } end
        function container:GetData() return self.data end
        return container
    end,
    CreateDropdownInitializer = function(setting, options)
        local count = setting.key == "nameplateThreatPosition" and 4 or setting.key:match("Position$") and 9
            or setting.key == "xpTextFormat" and 4 or 2
        assert(setting and #options() == count)
        for _, option in ipairs(options()) do assert(option.label and option.label ~= "") end
        dropdownCount = dropdownCount + 1
        return Initializer(setting.name, "Control")
    end,
    CreateColorSwatchInitializer = function(setting)
        assert(setting)
        colorCount = colorCount + 1
        return Initializer(setting.name, "ColorSwatch")
    end,
    CreateSliderOptions = function(minimum, maximum, step)
        assert(minimum == 0 and maximum == 40 and step == 1)
        return { SetLabelFormatter = function(_, label, formatter)
            assert(label == MinimalSliderWithSteppersMixin.Label.Right and formatter(12) == "12 px")
        end }
    end,
    CreateSliderInitializer = function(setting, options)
        assert(setting and options)
        sliderCount = sliderCount + 1
        return Initializer(setting.name, "SliderWithSteppers")
    end,
}
GAMEMENU_OPTIONS = "Options"
SOUNDKIT = { IG_MAINMENU_OPTION = 1 }
function InCombatLockdown() return combat end
function PlaySound(value) sound = value end
function HideUIPanel(frame) hidden = frame; frame.shown = false end
CooldownViewerSettings = {
    ShowUIPanel = function(_, fromEditMode)
        assert(hidden == GameMenuFrame and fromEditMode == false)
        opened = true
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
local addonButton, addonButtonCount = nil, 0
function CreateFrame(kind, name, parent, template)
    if template == "GameMenuFrameButtonTemplate" then
        assert(parent == GameMenuFrame and template == "GameMenuFrameButtonTemplate")
        addonButtonCount = addonButtonCount + 1
        addonButton = { scripts = {} }
        function addonButton:SetScript(event, callback) self.scripts[event] = callback end
        function addonButton:SetText(text) self.text = text end
        function addonButton:SetMotionScriptsWhileDisabled(value) assert(value) end
        function addonButton:SetSize(width, height) self.width, self.height = width, height end
        function addonButton:SetEnabled(value) self.enabled = value end
        function addonButton:Show() self.shown = true end
        function addonButton:Hide() self.shown = false end
        return addonButton
    end
    local frame = Widget(kind)
    if kind == "Button" and not template then navigation[#navigation + 1] = frame end
    if template == "SettingsFrameTemplate" then
        assert(parent == UIParent and name == "PyresinQoLSettingsFrame")
        canvas = frame
        frame.NineSlice = Widget()
        frame.NineSlice.Text = Widget()
        frame.ClosePanelButton = Widget()
    end
    if kind == "Button" and template == "BackdropTemplate" then groupButtons[#groupButtons + 1] = frame end
    if template == "UIPanelButtonTemplate" then
        if parent == launcher then openButton = frame
        elseif not closeButton then closeButton = frame
        else reloadButton = frame end
    end
    if template == "SettingsListTemplate" then
        settingsList = frame
        frame.Header = Widget()
        frame.Header.Title = Widget()
        frame.Header.DefaultsButton = Widget()
        local divider = Widget("Texture")
        function frame.Header:GetRegions() return divider end
        function frame:Display(initializers)
            self.initializers, self.rendered = initializers, {}
            for _, initializer in ipairs(initializers) do
                if initializer:ShouldShow() then
                    local row = Widget()
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
GameMenuFrame = { shown = true, buttons = {}, builds = 0 }
function GameMenuFrame:IsShown() return self.shown end
function GameMenuFrame:Reset() self.buttons = {} end
function GameMenuFrame:MarkDirty() self.dirty = true end
function GameMenuFrame:AddButton(text, callback, disabled)
    assert(not addonContext, "Addon code must not acquire Blizzard menu buttons from its shared pool")
    local button = { text = text, scripts = { OnClick = callback }, enabled = not disabled }
    function button:SetScript(event, handler) self.scripts[event] = handler end
    function button:SetEnabled(enabled) self.enabled = enabled end
    function button:GetText() return self.text end
    function button:GetSize() return 200, 36 end
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
local function BuildMenu()
    GameMenuFrame:InitButtons()
    assert(#GameMenuFrame.buttons == 2, "Native button list must remain untouched")
    assert(addonButtonCount == 1 and addonButton.shown and addonButton.text == ns.L.cooldownMenu)
    assert(addonButton.width == 200 and addonButton.height == 36)
    assert(addonButton.layoutIndex > GameMenuFrame.buttons[1].layoutIndex
        and addonButton.layoutIndex < GameMenuFrame.buttons[2].layoutIndex, "Shortcut must appear immediately after Options")
    return addonButton
end

if arg[1] == "modules-disabled" then
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
assert(loadfile("Settings/Controls.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/GameMenu/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/EditMode/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Performance/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Experience/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Quests/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/UnitFrames/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Modules/Tooltips/Settings.lua"))("PyresinQoL", ns)
assert(loadfile("Settings/Window.lua"))("PyresinQoL", ns)
assert(loadfile("Core/Bootstrap.lua"))("PyresinQoL", ns)
events.callback(events, "ADDON_LOADED", "OtherAddon")
assert(checkboxCount == 0)
GameMenuFrame.shown = false
events.callback(events, "ADDON_LOADED", "PyresinQoL")
assert(checkboxCount == 22 and dropdownCount == 3 and settingsRegistrant,
    "Register unit-frame controls with Blizzard's deferred settings registration")
settingsRegistrant()
assert(settings.PyresinQoL_StatusText == nil, "Status text belongs to Blizzard's options")
assert(nativeThreatCheckbox:ShouldShow() and nativeThreatPosition:ShouldShow())
assert(nativeThreatCheckbox.modifyPredicate() == ns.GetModule("unitFrames").active
    and nativeThreatPosition.modifyPredicate() == ns.GetModule("unitFrames").active,
    "Native options remain visible but disabled when the module is inactive")
local function NavigationButton(name)
    for _, button in ipairs(navigation) do
        if button.text.value == name then return button end
    end
    error("Missing settings page: " .. name)
end
if arg[1] == "modules-disabled" then
    canvas.scripts.OnShow()
    assert(addonButtonCount == 0 and not ns.ModulesNeedReload() and not reloadButton.enabled)
    assert(settingsList.Header.Title.value == ns.L.modules)
    for _, module in ipairs(ns.modules) do
        local button = NavigationButton(module.pages[1].name)
        button.scripts.OnClick()
        assert(button.text.color[1] == 0.5)
        assert(not settingsList.initializers[1].modifyPredicate())
        assert(not settingsList.Header.DefaultsButton.enabled)
    end
    navigation[1].scripts.OnClick()
    settingsList.Header.DefaultsButton.scripts.OnClick()
    assert(ns.ModulesNeedReload() and reloadButton.enabled and addonButtonCount == 0)
    print("PASS: all modules disabled, absent callbacks, locked options and unchanged Blizzard settings")
    return
end
assert(checkboxCount == 30 and dropdownCount == 8 and colorCount == 1 and sliderCount == 2 and not events.registered.ADDON_LOADED)
assert(canvas and #navigation == 11 and #sections == 0)
assert(navigation[2].text.value == ns.L.gameMenu and navigation[3].text.value == ns.L.editMode and navigation[4].text.value == ns.L.performance)
assert(not canvas.shown and canvas.width == 960 and canvas.height == 720)
assert(UISpecialFrames[1] == "PyresinQoLSettingsFrame" and canvas.clamped and canvas.movable)
assert(SLASH_PQOL1 == "/pqol" and SLASH_PYRESINQOL1 == nil and SLASH_PYRESINQOL2 == nil)
assert(canvas.NineSlice.Text.value == "PyresinQoL")
assert(#logos == 2 and logos[1].width == 72 and logos[1].height == 72)
local corner = logos[1].points[1]
assert(corner[1] == "TOPLEFT" and corner[2] == canvas and corner[3] == "TOPLEFT"
    and corner[4] == -20 and corner[5] == 24, "The logo must overlap the window's upper-left corner")
assert(logos[2].width == 48 and logos[2].height == 48)
local toc = assert(io.open("PyresinQoL.toc"))
assert(toc:read("*a"):find("## IconTexture: " .. logos[1].texture, 1, true))
toc:close()
local iconFile = assert(io.open("Media/AddonIcon.tga", "rb"))
local header = iconFile:read(18)
iconFile:close()
assert(header:byte(3) == 2 and header:byte(13) == 128 and header:byte(14) == 0
    and header:byte(15) == 128 and header:byte(16) == 0 and header:byte(17) == 32,
    "The shared icon must be an uncompressed 128x128 RGBA TGA")
openButton.scripts.OnClick()
assert(canvas.shown and not SettingsPanel.shown and canvas.scale == 1 and canvas.raised)
closeButton.scripts.OnClick()
assert(not canvas.shown)
UIParent.GetHeight = function() return 600 end
SlashCmdList.PQOL()
assert(canvas.shown and canvas.scale < 1, "The complete window must fit shorter screens")
canvas.ClosePanelButton.scripts.OnClick()
assert(not canvas.shown)
assert(#groupButtons == 3)
groupButtons[1].scripts.OnClick()
assert(not navigation[1].shown and not navigation[2].shown and not navigation[3].shown)
assert(navigation[4].shown and navigation[7].shown)
groupButtons[1].scripts.OnClick()
assert(navigation[1].shown and navigation[2].shown and navigation[3].shown)
canvas.scripts.OnShow()
assert(settingsList.Header.Title.value == ns.L.modules and #settingsList.rendered == 7)
assert(navigation[1].selected.shown and not reloadButton.enabled)
navigation[2].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.gameMenu and #settingsList.rendered == 1)
assert(navigation[2].selected.shown and not navigation[3].selected.shown)
navigation[3].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.editMode and #settingsList.rendered == 1)
assert(PyresinQoLDB.pixelPerfectEditMode == false)
settings.pixelPerfectEditMode:SetValue(true)
assert(PyresinQoLDB.pixelPerfectEditMode and pixelPerfectUpdates == 1)
settings.pixelPerfectEditMode:SetValue(false)
assert(not PyresinQoLDB.pixelPerfectEditMode and pixelPerfectUpdates == 2)
navigation[4].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.performance and #settingsList.rendered == 7)
for index = 1, 7 do
    local row = settingsList.rendered[index]
    assert(row.Text.wordWrap and row.Text.maxLines == 2 and #row.Text.points == 2)
    assert(settingsList.initializers[index]:GetExtent() == 44)
end
canvas.OnRefresh()
assert(settingsList.Header.Title.value == ns.L.performance, "Reopening preserves the internal page")
assert(PyresinQoLDB.cooldownShortcut == (arg[1] ~= "disabled"))
assert(PyresinQoLDB.showPerformance == nil)
assert(PyresinQoLDB.showFPS == (arg[1] ~= "disabled") and PyresinQoLDB.showLatency == (arg[1] ~= "disabled"))
assert(PyresinQoLDB.performanceLayout == "column" and PyresinQoLDB.performanceOrder == "fps")
assert(PyresinQoLDB.performanceRowPadding == 14 and PyresinQoLDB.performanceColumnPadding == 5)
assert(PyresinQoLDB.performanceColor == "FFFFFFFF")
navigation[5].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.experience and #settingsList.rendered == 4)
assert(PyresinQoLDB.xpTextFormat == "both" and PyresinQoLDB.xpAlwaysShow and PyresinQoLDB.xpTooltip and PyresinQoLDB.xpQuestRewards)
navigation[6].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.quests and #settingsList.rendered == 1)
assert(settings.questLevels.name == ns.L.questLevels and PyresinQoLDB.questLevels)
settings.questLevels:SetValue(false)
assert(not PyresinQoLDB.questLevels and questUpdates == 1)
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.questLevels and questUpdates == 2)
assert(PyresinQoLDB.targetThreat)
settings.targetThreat:SetValue(false)
assert(threatUpdates == 1 and not PyresinQoLDB.targetThreat)
assert(PyresinQoLDB.targetDebuffs and PyresinQoLDB.targetDebuffsOnlyMine)
settings.targetDebuffsOnlyMine:SetValue(false)
settings.targetDebuffs:SetValue(false)
assert(debuffUpdates == 2 and not PyresinQoLDB.targetDebuffsOnlyMine and not PyresinQoLDB.targetDebuffs)
assert(not PyresinQoLDB.playerClassColor and not PyresinQoLDB.targetClassColor)
settings.playerClassColor:SetValue(true)
settings.targetClassColor:SetValue(true)
settings.playerHPPosition:SetValue("TOPLEFT")
settings.playerManaPosition:SetValue("RIGHT")
settings.targetHPPosition:SetValue("BOTTOMRIGHT")
settings.targetManaPosition:SetValue("LEFT")
assert(playerUpdates == 6)
navigation[7].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.playerFrame and #settingsList.rendered == 4)
assert(PyresinQoLDB.druidMana and settings.druidMana.name == ns.L.druidMana)
settings.druidMana:SetValue(false)
assert(not PyresinQoLDB.druidMana and druidManaUpdates == 1)
assert(settings.druidManaPreview == nil, "Temporary preview control has been removed")
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.druidMana and druidManaUpdates == 2)
assert(playerUpdates == 9 and not PyresinQoLDB.playerClassColor and PyresinQoLDB.targetClassColor)
navigation[8].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.targetFrame and #settingsList.rendered == 6)
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(playerUpdates == 12 and not PyresinQoLDB.targetClassColor)
assert(threatUpdates == 2 and PyresinQoLDB.targetThreat)
assert(debuffUpdates == 4 and PyresinQoLDB.targetDebuffs and PyresinQoLDB.targetDebuffsOnlyMine)
assert(PyresinQoLDB.playerHPPosition == "CENTER"
    and PyresinQoLDB.targetHPPosition == "CENTER" and PyresinQoLDB.targetManaPosition == "CENTER")
navigation[9].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.nameplates and #settingsList.rendered == 3)
assert(PyresinQoLDB.nameplateComboPoints and nativeComboCheckbox:ShouldShow())
nativeComboCheckbox.setting:SetValue(false)
assert(comboUpdates == 1 and not PyresinQoLDB.nameplateComboPoints)
assert(PyresinQoLDB.nameplateThreat)
settings.nameplateThreat:SetValue(false)
assert(nameplateUpdates == 1 and not PyresinQoLDB.nameplateThreat)
assert(PyresinQoLDB.nameplateThreatPosition == "RIGHT")
nativeThreatPosition.setting:SetValue("LEFT")
assert(nameplateUpdates == 2 and PyresinQoLDB.nameplateThreatPosition == "LEFT")
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(nameplateUpdates == 4 and PyresinQoLDB.nameplateThreat and PyresinQoLDB.nameplateThreatPosition == "RIGHT")
assert(comboUpdates == 2 and PyresinQoLDB.nameplateComboPoints)
navigation[10].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.statusText and #settingsList.rendered == 5)
assert(settingsList.rendered[1].Title.value == ns.L.hideStatusText)
for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
    local key = unit .. "HideStatusText"
    assert(PyresinQoLDB[key] == false and settings[key].name == ns.L[key])
    settings[key]:SetValue(true)
    assert(PyresinQoLDB[key] == true)
end
assert(statusTextUpdates == 4)
settingsList.Header.DefaultsButton.scripts.OnClick()
for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
    assert(PyresinQoLDB[unit .. "HideStatusText"] == false)
end
assert(statusTextUpdates == 8)
navigation[11].scripts.OnClick()
assert(settingsList.Header.Title.value == ns.L.tooltips and #settingsList.rendered == 3)
assert(PyresinQoLDB.tooltipHealth and PyresinQoLDB.tooltipGuildRank and PyresinQoLDB.tooltipObjectCursor)
settings.tooltipHealth:SetValue(false)
settings.tooltipGuildRank:SetValue(false)
settings.tooltipObjectCursor:SetValue(false)
assert(not PyresinQoLDB.tooltipHealth and not PyresinQoLDB.tooltipGuildRank and not PyresinQoLDB.tooltipObjectCursor and tooltipUpdates == 3)
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.tooltipHealth and PyresinQoLDB.tooltipGuildRank and PyresinQoLDB.tooltipObjectCursor and tooltipUpdates == 6)
navigation[5].scripts.OnClick()
settings.xpTextFormat:SetValue("percent")
settings.xpAlwaysShow:SetValue(false)
settings.xpTooltip:SetValue(false)
settings.xpQuestRewards:SetValue(false)
assert(experienceUpdates == 4)
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.xpTextFormat == "both" and PyresinQoLDB.xpAlwaysShow and PyresinQoLDB.xpTooltip and PyresinQoLDB.xpQuestRewards)
navigation[4].scripts.OnClick()
settings.cooldownShortcut:SetValue(true)
settings.showFPS:SetValue(false)
settings.showLatency:SetValue(false)
settings.performanceLayout:SetValue("row")
settings.performanceOrder:SetValue("latency")
settings.performanceColor:SetValue("FFFF0000")
settings.performanceRowPadding:SetValue(24)
settings.performanceColumnPadding:SetValue(9)
assert(not PyresinQoLDB.showFPS and not PyresinQoLDB.showLatency and performanceUpdates == 7)
assert(PyresinQoLDB.performanceRowPadding == 24 and PyresinQoLDB.performanceColumnPadding == 9)
hidden = nil
GameMenuFrame.shown = true
assert(combatEvents.registered.PLAYER_REGEN_DISABLED and combatEvents.registered.PLAYER_REGEN_ENABLED)
combatEvents.callback() -- Combat events before the menu first opens.
local button = BuildMenu()
assert(button.enabled)
button.scripts.OnEnter(button)
assert(not GameTooltip.shown)
combat = true
combatEvents.callback()
assert(not button.enabled, "Combat must disable an already visible button")
button.scripts.OnEnter(button)
assert(GameTooltip.shown and GameTooltip.error == ns.L.combat)
button.scripts.OnClick()
assert(not opened and not hidden, "Combat guard must also protect the click handler")
button = BuildMenu()
assert(not button.enabled, "Opening the menu in combat must disable the shortcut")
button.scripts.OnEnter(button)
combat = false
combatEvents.callback()
assert(button.enabled and not GameTooltip.shown)
button.scripts.OnClick()
assert(opened and hidden == GameMenuFrame and sound == SOUNDKIT.IG_MAINMENU_OPTION)
GameMenuFrame.shown = true
local nativeButtons, builds = GameMenuFrame.buttons, GameMenuFrame.builds
local optionsCallback, shopCallback = nativeButtons[1].scripts.OnClick, nativeButtons[2].scripts.OnClick
settings.cooldownShortcut:SetValue(false)
assert(#GameMenuFrame.buttons == 2 and GameMenuFrame.buttons[2].text == "Shop")
assert(not addonButton.shown)
opened, hidden = false, nil
button.scripts.OnClick()
assert(not opened and not hidden, "A stale shortcut must not open after disabling")
combatEvents.callback()
settings.cooldownShortcut:SetValue(true)
assert(addonButton.shown and addonButtonCount == 1)
assert(GameMenuFrame.buttons == nativeButtons and GameMenuFrame.builds == builds)
assert(nativeButtons[1].scripts.OnClick == optionsCallback and nativeButtons[2].scripts.OnClick == shopCallback)
assert(nativeButtons[1].layoutIndex == 1 and nativeButtons[2].layoutIndex == 2)
for _ = 1, 10 do assert(BuildMenu() == addonButton) end
settings.cooldownShortcut:SetValue(false)
GameMenuFrame:InitButtons()
assert(not addonButton.shown and #GameMenuFrame.buttons == 2)
settings.pixelPerfectEditMode:SetValue(true)
PyresinQoLDB.performancePosition = { x = 11, y = 22 }
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.showFPS and PyresinQoLDB.showLatency and PyresinQoLDB.performanceLayout == "column")
assert(PyresinQoLDB.performanceRowPadding == 14 and PyresinQoLDB.performanceColumnPadding == 5)
assert(PyresinQoLDB.performanceColor == "FFFFFFFF" and PyresinQoLDB.performanceOrder == "fps")
assert(PyresinQoLDB.pixelPerfectEditMode and not PyresinQoLDB.cooldownShortcut, "Defaults affect only the selected page")
canvas.OnDefault()
assert(not PyresinQoLDB.pixelPerfectEditMode and PyresinQoLDB.cooldownShortcut)
assert(PyresinQoLDB.performancePosition.x == 11 and PyresinQoLDB.performancePosition.y == 22)
-- Module switches share their value across overview and detail pages.
local unitFramesModule = settings.PyresinQoL_Module_unitFrames
assert(nativeThreatCheckbox:ShouldShow() and nativeThreatPosition:ShouldShow())
unitFramesModule:SetValue(false)
assert(nativeThreatCheckbox:ShouldShow() and nativeThreatPosition:ShouldShow(),
    "Native nameplate options must stay visible when the module is disabled")
assert(not nativeThreatCheckbox.modifyPredicate() and not nativeThreatPosition.modifyPredicate())
assert(nativeComboCheckbox:ShouldShow() and not nativeComboCheckbox.modifyPredicate())
unitFramesModule:SetValue(true)
assert(nativeThreatCheckbox:ShouldShow() and nativeThreatPosition:ShouldShow())
local reloaded = 0
function ReloadUI() reloaded = reloaded + 1 end
navigation[4].scripts.OnClick()
local before = performanceUpdates
local performanceModule = settings.PyresinQoL_Module_performance
performanceModule:SetValue(false)
assert(PyresinQoLDB.showFPS and PyresinQoLDB.showLatency, "Disabling preserves individual options")
assert(reloadButton.enabled and ns.ModulesNeedReload())
assert(navigation[4].text.value == ns.L.performance .. " *")
navigation[4].scripts.OnEnter()
assert(GameTooltip.shown and GameTooltip.line == ns.L.modulePending)
navigation[4].scripts.OnLeave()
assert(not GameTooltip.shown)
assert(not settingsList.initializers[1].modifyPredicate(), "Disabled module options must be locked")
assert(not settingsList.Header.DefaultsButton.enabled)
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(performanceUpdates == before, "Defaults must not change a disabled module")
settings.performanceLayout:SetValue("row")
assert(performanceUpdates == before, "Pending disabled modules must not apply option callbacks")
combat = true
canvas.scripts.OnEvent()
assert(not reloadButton.enabled)
reloadButton.scripts.OnClick()
assert(reloaded == 0, "Reload must be guarded in combat")
combat = false
canvas.scripts.OnEvent()
reloadButton.scripts.OnClick()
assert(reloaded == 1)
performanceModule:SetValue(true)
assert(not ns.ModulesNeedReload() and not reloadButton.enabled)
assert(settingsList.initializers[1].modifyPredicate())
assert(navigation[4].text.value == ns.L.performance)
-- Simulate a startup with this module disabled, then request activation.
ns.modules[3].active = false
performanceModule:SetValue(false)
assert(not ns.ModulesNeedReload() and navigation[4].text.color[1] == 0.5)
performanceModule:SetValue(true)
assert(ns.ModulesNeedReload() and not settingsList.initializers[1].modifyPredicate())
settings.performanceLayout:SetValue("column")
assert(performanceUpdates == before, "Unloaded modules must wait for reload")
ns.modules[3].active = true
performanceModule:SetValue(false)
navigation[1].scripts.OnClick()
settingsList.Header.DefaultsButton.scripts.OnClick()
assert(PyresinQoLDB.modules.performance and not ns.ModulesNeedReload())
assert(PyresinQoLDB.performancePosition.x == 11, "Module defaults must preserve feature settings and position")
print("PASS: standalone settings/navigation, localized controls, collapse, defaults, migration, live callbacks and menu isolation")

-- A new group and multi-page module require only registration metadata.
local featureContext
local extraModule = { id = "navigationTest", name = "Navigation test", description = "Test feature",
    group = "navigationTest", active = true,
    pages = { { id = "main", name = "Test main" }, { id = "details", name = "Test details" } },
    buildSettings = function(_, context) featureContext = context end,
}
ns.modules[#ns.modules + 1] = extraModule
ns.settingsGroups[#ns.settingsGroups + 1] = { id = "navigationTest", name = "Test group" }
PyresinQoLDB.modules.navigationTest = true
launcher, closeButton = nil, nil
navigation, groupButtons = {}, {}
ns.InitializeSettings()
local detailButton = NavigationButton("Test details")
detailButton.scripts.OnClick()
assert(settingsList.Header.Title.value == "Test details"
    and settingsList.initializers == featureContext.pages.details.initializers)
assert(featureContext.pages.main.module == extraModule and featureContext.pages.details.module == extraModule)
groupButtons[4].scripts.OnClick()
assert(not detailButton.shown and not NavigationButton("Test main").shown)
assert(NavigationButton(ns.L.performance).shown, "Group collapse must preserve unrelated pages")
print("PASS: metadata-defined groups, subpages and settings-builder contexts")
