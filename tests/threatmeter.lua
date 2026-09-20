-- luajit tests/threatmeter.lua [path-to-Blizzard-DamageMeterEntry.lua]
-- Optional upstream style mixins still run on mocked frames, not WoW's taint engine.
local nativeType, deathsType, legacyType = 0, 9, 0x5051
local states = {
    player = { percentage = 60, threat = 600, class = "MAGE" },
    party1 = { percentage = 100, threat = 1000, class = "WARRIOR" },
    party2 = { percentage = 20, threat = 200, class = "PRIEST" },
}
local targetExists, hostile, raid = true, true, false
local secrets = {}
local function Secret()
    local value = setmetatable({}, {
        __lt = function() error("Compared a restricted number") end,
        __tostring = function() error("Formatted a restricted value in Lua") end,
    })
    secrets[value] = true
    return value
end
function issecretvalue(value) return secrets[value] == true end
Enum = { DamageMeterSourceDisplayType = { Ally = 1 }, DamageMeterType = { DamageDone = nativeType, Deaths = deathsType } }
ScrollBoxConstants = { RetainScrollPosition = true, DiscardScrollPosition = false }
THREAT, UNKNOWNOBJECT = "Threat", "Unknown"
DAMAGE_METER_SOURCE_NAME = "%d. %s"
function GetClassAtlas(class) assert(not issecretvalue(class)); return "class-" .. class end
RAID_CLASS_COLORS = { MAGE = { r = 0.4, g = 0.8, b = 1 } }
local function Color(r, g, b)
    return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end }
end
RAID_CLASS_COLORS.MAGE = Color(0.4, 0.8, 1)
if arg[1] then
    Enum.DamageMeterStyle = { Default = 0, Bordered = 1, FullBackground = 2, Thin = 3 }
    Enum.DamageMeterNumbers = { Minimal = 1, Compact = 2, Complete = 3 }
    DAMAGE_METER_STATUS_BAR_DEFAULT_COLOR = Color(0.3, 0.6, 1)
    DAMAGE_METER_STATUS_BAR_ALLY_COLOR = Color(0.2, 0.8, 0.2)
    SecondsFormatter = { Abbreviation = { OneLetter = 1 }, Interval = { Seconds = 1 } }
    SecondsFormatterMixin = { Init = function() end, SetDesiredUnitCount = function() end, SetMinInterval = function() end }
    function CreateFromMixins(mixin) local result = {}; for key, value in pairs(mixin) do result[key] = value end; return result end
    dofile(arg[1])
end
local xmlHandle = assert(io.open("Modules/UnitFrames/ThreatMenu.xml", "r"))
local threatMenuXml = xmlHandle:read("*a")
xmlHandle:close()
assert(threatMenuXml:find('<Button name="PyresinQoLThreatMenuTemplate" virtual="true">', 1, true))
assert(threatMenuXml:find('<Size x="120" y="20"/>', 1, true))
assert(threatMenuXml:find('<Texture parentKey="Icon" file="Interface\\Icons\\Ability_Warrior_FocusedRage">', 1, true))
assert(threatMenuXml:find('<Size x="16" y="16"/>', 1, true))
assert(threatMenuXml:find('<ButtonText parentKey="Text"', 1, true))
assert(threatMenuXml:find('<Anchor point="LEFT" relativeKey="$parent.Icon" relativePoint="RIGHT" x="4"/>', 1, true))
local xmlLine, luaLine, tocLine = nil, nil, 0
for line in io.lines("PyresinQoL.toc") do
    tocLine = tocLine + 1
    if line == "Modules/UnitFrames/ThreatMenu.xml" then xmlLine = tocLine end
    if line == "Modules/UnitFrames/ThreatMeter.lua" then luaLine = tocLine end
end
assert(xmlLine and luaLine and xmlLine < luaLine, "ThreatMenu.xml must load before ThreatMeter.lua")
function UnitExists(unit) return unit == "target" and targetExists or states[unit] ~= nil end
function UnitCanAttack() return hostile end
function IsInRaid() return raid end
function GetNumGroupMembers() return 2 end
function GetNumSubgroupMembers() return 2 end
function UnitDetailedThreatSituation(unit, target)
    assert(target == "target")
    local state = states[unit]
    return false, 0, state.percentage, state.percentage, state.threat
end
function UnitName(unit) return states[unit].name or unit end
function UnitClass(unit) return unit, states[unit].class end
C_StringUtil = {
    TruncateWhenZero = function(value)
        if issecretvalue(value) then return value end -- Native sink can accept secret numbers.
        return value == 0 and "" or tostring(math.floor(value))
    end,
    WrapString = function(value, prefix, suffix)
        if issecretvalue(value) then return value end
        return value == "" and "" or prefix .. value .. suffix
    end,
}
local function Text()
    local text = { setTextCalls = 0, setAlphaCalls = 0, setShownCalls = 0 }
    text.SetText = function(self, value) self.text, self.setTextCalls = value, self.setTextCalls + 1 end
    function text:SetFormattedText(format, index, name)
        self.format, self.rank = format, index
        self.text = issecretvalue(name) and name or string.format(format, index, name)
    end
    function text:GetText() return self.text end
    function text:SetAlpha(value) self.alpha, self.setAlphaCalls = value, self.setAlphaCalls + 1 end
    function text:SetPoint(...)
        self.points = self.points or {}
        self.point = { ... }
        for index, point in ipairs(self.points) do
            if point[1] == self.point[1] then self.points[index] = self.point; return end
        end
        self.points[#self.points + 1] = self.point
    end
    function text:SetAllPoints() end
    function text:ClearAllPoints() self.point, self.points = nil, {} end
    function text:SetWidth() end
    function text:SetJustifyH() end
    function text:SetTextScale(value) self.scale = value end
    function text:SetShown(value) self.shown, self.setShownCalls = value, self.setShownCalls + 1 end
    function text:SetSize(width, height) self.width, self.height = width, height end
    function text:SetVertexColor(...) self.color = { ... } end
    function text:SetColorTexture() end
    function text:SetAtlas(value) self.atlas = value end
    function text:SetTexture(value) self.texture, self.atlas = value, nil end
    function text:SetDesaturated(value) self.desaturated = value end
    return text
end
local created = {}
function CreateFrame(kind, name, parent, template)
    assert(template == nil or template == "DamageMeterEntryTemplate",
        "Do not use native source entry initializers")
    local frame = { kind = kind, parent = parent, template = template, shown = true, scripts = {} }
    created[#created + 1] = frame
    function frame:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:RegisterEvent(event)
        self.events = self.events or {}
        self.events[event] = true
    end
    function frame:CreateTexture() return Text() end
    function frame:CreateFontString() return Text() end
    function frame:SetPoint(...)
        self.points = self.points or {}
        self.point = { ... }
        for index, point in ipairs(self.points) do
            if point[1] == self.point[1] then self.points[index] = self.point; return end
        end
        self.points[#self.points + 1] = self.point
    end
    function frame:ClearAllPoints() self.point, self.points = nil, {} end
    function frame:SetHeight(height) self.height = height end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:SetClipsChildren(value) self.clipsChildren = value end
    function frame:SetStatusBarTexture() end
    function frame:SetMinMaxValues(min, max) self.min, self.max = min, max end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarColor(...) self.color = { ... } end
    function frame:EnableMouse(value) self.mouse = value end
    function frame:EnableMouseWheel(value) self.mouseWheel = value end
    function frame:GetHeight() error("Do not measure restricted frame geometry") end
    function frame:GetWidth() error("Do not measure restricted frame geometry") end
    if template == "DamageMeterEntryTemplate" then
        frame.StatusBar = CreateFrame("StatusBar", nil, frame)
        frame.Name, frame.Value, frame.icon = Text(), Text(), Text()
        function frame:GetName() return self.Name end
        function frame:GetValue() return self.Value end
        function frame:GetIcon() return self.icon end
        function frame:GetStatusBar() return self.StatusBar end
        function frame:SetBarHeight(value) self:SetHeight(value) end
        function frame:SetTextScale(value) self.Name:SetTextScale(value); self.Value:SetTextScale(value) end
        function frame:SetStyle(value) self.style = value end
        function frame:SetShowBarIcons(value) self.showBarIcons = value end
        function frame:SetBackgroundAlpha(value) self.backgroundAlpha = value end
        function frame:SetUseClassColor(value) self.useClassColor = value end
        if DamageMeterEntryMixin then
            frame.Icon = { Icon = frame.icon }
            frame.StatusBar.Name, frame.StatusBar.Value = frame.Name, frame.Value
            frame.StatusBar.Background, frame.StatusBar.BackgroundEdge = Text(), Text()
            frame.StatusBar.BackgroundRegions = { frame.StatusBar.Background, frame.StatusBar.BackgroundEdge }
            frame.StatusBar.texture = Text()
            function frame.StatusBar:GetStatusBarTexture() return self.texture end
            for key, method in pairs(DamageMeterEntryMixin) do frame[key] = method end
        end
        function frame:Init() error("Do not feed threat through native data initialization") end
        function frame:UpdateName() error("Do not compare secret names in the native mixin") end
        function frame:UpdateValue() error("Do not format secret threat in the native mixin") end
    end
    return frame
end
local function Display(window)
    for _, frame in ipairs(created) do
        if frame.parent == window.container and frame.kind == "Frame" then return frame end
    end
    error("Missing independent threat display")
end
local function Watcher()
    for _, frame in ipairs(created) do if frame.scripts.OnUpdate then return frame end end
    error("Missing independent threat updater")
end
local function Emit(event) local frame = Watcher(); frame.scripts.OnEvent(frame, event) end
local function Tick() local frame = Watcher(); frame.scripts.OnUpdate(frame, 0.2) end
local function Entry()
    local frame = { label = Text(), valueText = Text(), bar = {} }
    function frame:GetName() return self.label end
    function frame:GetValue() return self.valueText end
    function frame:GetStatusBar() return self.bar end
    function frame.bar:SetValue(value) self.value = value end
    function frame.bar:SetMinMaxValues(min, max) self.min, self.max = min, max end
    function frame:SetScript(script, callback) self[script] = callback end
    function frame:UpdateName()
        assert(not issecretvalue(self.sourceName))
        if self.nameText ~= self.sourceName then
            self.nameText = self.sourceName
            self:GetName():SetText(self.sourceName)
        end
    end
    function frame:UpdateValue()
        assert(not issecretvalue(self.value), "Restricted values reached native formatter")
        self:GetValue():SetText(tostring(self.value))
    end
    function frame:UpdateStatusBar()
        self:GetStatusBar():SetMinMaxValues(0, self.maxValue)
        self:GetStatusBar():SetValue(self.value)
    end
    function frame:SetNumberDisplayType() self:UpdateValue() end
    function frame:Init(data)
        self.sourceDisplayType = data.sourceDisplayType
        self.sourceName, self.value, self.maxValue = data.name, data.totalAmount, data.maxAmount
        self:UpdateName()
        self:UpdateValue()
        self:UpdateStatusBar()
    end
    return frame
end

function hooksecurefunc(owner, method, callback)
    error("Threat must not hook native functions: " .. method)
end
local menuModifyCalls, modifier = 0, nil
local nativeSelectionHandled = false
local function Description(text, data, callback, selected, radio)
    local description = {
        text = text, data = data, callback = callback, selected = selected,
        radio = radio == true, children = {}, responses = {}, scripts = {},
    }
    function description:IsRadio() return self.radio end
    function description:IsSelected() return self.selected and self.selected(self.data) or false end
    function description:CreateRadio(label, isSelected, onSelect, value)
        local child = Description(label, value, onSelect, isSelected, true)
        child.root = self.root or self
        table.insert(self.children, child)
        return child
    end
    function description:CreateTemplate(template)
        assert(template == "PyresinQoLThreatMenuTemplate")
        local child = Description("", nil, nil, nil, false)
        child.root, child.template = self.root or self, template
        child.Icon, child.Text = Text(), Text()
        child.width, child.height = 120, 20
        child.Icon:SetTexture("Interface\\Icons\\Ability_Warrior_FocusedRage")
        child.Icon:SetSize(16, 16)
        child.Icon:SetPoint("LEFT", child, "LEFT", 0, 0)
        child.Text:SetPoint("LEFT", child.Icon, "RIGHT", 4, 0)
        child.Text:SetPoint("RIGHT", child, "RIGHT", -4, 0)
        table.insert(self.children, child)
        return child
    end
    function description:SetResponder(callback) self.responder = callback end
    function description:AddInitializer(callback)
        self.initializer = callback
        callback(self, self)
    end
    function description:SetText(value) self.text = value; self.Text:SetText(value) end
    function description:SetScript(script, callback) self.scripts[script] = callback end
    function description:Pick(context, buttonName)
        self.pickContext, self.pickButtonName = context, buttonName
        nativeSelectionHandled = false
        local result = self.responder and self.responder() or (self.callback and self.callback(self.data))
        self.response = result
        local root = self.root or self
        for _, callback in ipairs(root.responses) do callback(nil, self) end
        return result
    end
    function description:AddMenuResponseCallback(callback)
        table.insert(self.responses, function(owner, selected)
            if selected:IsRadio() then
                assert(nativeSelectionHandled, "Native selection must run before the addon response")
            end
            callback(owner, selected)
        end)
    end
    return description
end
Menu = { ModifyMenu = function(tag, callback)
    assert(tag == "MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE")
    menuModifyCalls, modifier = menuModifyCalls + 1, callback
end }
MenuInputContext = { MouseButton = "MouseButton" }
MenuResponse = { Close = "Close" }

local nativeCalls = 0
local nativeDisplayType = Secret()
DamageMeterSessionWindowMixin = {}
function DamageMeterSessionWindowMixin:GetCombatSession()
    if self:IsEditing() then return { combatSources = {}, maxAmount = 100 } end
    assert(self.damageMeterType == nativeType or self.damageMeterType == deathsType,
        "An invalid type reached the native C_DamageMeter API")
    nativeCalls = nativeCalls + 1
    return { combatSources = { { name = "Native", totalAmount = 42, sourceDisplayType = nativeDisplayType } }, maxAmount = 42 }
end
function DamageMeterSessionWindowMixin:InitEntry(frame, data)
    assert(self.InitEntry == DamageMeterSessionWindowMixin.InitEntry,
        "Native entry initializer must not be reached through an addon replacement")
    frame:Init(data)
    frame:SetScript("OnClick", function() end)
end
function DamageMeterSessionWindowMixin:SetDamageMeterType(value)
    self.damageMeterType = value
    nativeSelectionHandled = true
    self.title:SetText(value == deathsType and "Deaths" or "Damage Done")
    self:HideSourceWindow()
    self:Refresh()
end
function DamageMeterSessionWindowMixin:UpdateSessionTimerState()
    self.timerShown = true
    self.timer:SetText(self.timerText or "00:42")
end

local function Window(value)
    local window = { damageMeterType = value, title = Text(), events = {}, entries = {}, shown = true, refreshes = 0, sourceCloseCalls = 0 }
    for key, method in pairs(DamageMeterSessionWindowMixin) do window[key] = method end
    window.title:SetPoint("LEFT", window, "LEFT", 5, 0)
    local dropdown = { parent = window }
    window.dropdown = dropdown
    dropdown.menuAnchor = { relativeTo = dropdown }
    window.nativeMenuAnchor = dropdown.menuAnchor
    function dropdown:SetMenuAnchor() error("Do not replace the native popup menu anchor") end
    function dropdown:GetParent() return self.parent end
    function dropdown:SetPoint(...)
        self.points = self.points or {}
        self.point = { ... }
        for index, point in ipairs(self.points) do
            if point[1] == self.point[1] then self.points[index] = self.point; return end
        end
        self.points[#self.points + 1] = self.point
    end
    function dropdown:ClearAllPoints() self.point, self.points = nil, {} end
    function dropdown:GetWidth() error("Do not copy restricted dropdown width") end
    function dropdown:OpenMenu()
        self.opened = (self.opened or 0) + 1
        local root = Description("Root")
        root.root = root
        root.anchor = self.menuAnchor
        for _, categoryName in ipairs({ "Damage", "Healing", "Actions" }) do
            local category = Description(categoryName)
            category.root = root
            table.insert(root.children, category)
        end
        local function Select(value) DamageMeter:SetSessionWindowDamageMeterType(window, value) end
        local function IsSelected(value) return window.damageMeterType == value end
        root.children[1].damage = root.children[1]:CreateRadio("Damage Done", IsSelected, Select, nativeType)
        root.children[3].deaths = root.children[3]:CreateRadio("Deaths", IsSelected, Select, deathsType)
        modifier(self, root)
        root.damage = root.children[1].damage
        root.deaths = root.children[3].deaths
        self.root = root
        return root
    end
    window.sessionDropdown = { setShownCalls = 0 }
    function window.sessionDropdown:Show() self.shown, self.setShownCalls = true, self.setShownCalls + 1 end
    function window.sessionDropdown:Hide() self.shown, self.setShownCalls = false, self.setShownCalls + 1 end
    window.sessionDropdown.shown = true
    function window.sessionDropdown:IsShown() return self.shown end
    function window.sessionDropdown:SetShown(shown) self.shown, self.setShownCalls = shown, self.setShownCalls + 1 end
    window.container = { GetFrameLevel = function() return 1 end,
        IsVisible = function() return window.shown and not window.minimized end }
    window.timer = Text()
    window.title:SetPoint("RIGHT", window.sessionDropdown, "LEFT", -5, 0)
    -- Seed the mock with the old layout relationship. ConfigureWindow must clear
    -- this native anchor before attaching the dropdown to the header.
    dropdown:SetPoint("TOPLEFT", window.timer, "TOPRIGHT", 0, 0)
    window.source = { damageMeterType = value }
    window.title:SetText(value == deathsType and "Deaths" or "Damage Done")
    function window:GetMinimizeContainer() return self.container end
    function window:GetHeader() return self end
    function window:GetSessionTimerFontString() return self.timer end
    function window:GetSourceWindow() return self.source end
    function window:GetBarHeight() return 16 end
    function window:GetBarSpacing() return 2 end
    function window:GetTextScale() return self.textScale or 1 end
    function window:ShouldUseClassColor() return self.useClassColor ~= false end
    function window:GetStyle() return self.style or 0 end
    function window:ShouldShowBarIcons() return self.showBarIcons ~= false end
    function window:GetBackgroundAlpha() return self.backgroundAlpha or 1 end
    function window:SetStyle(value) self.style = value end
    function window:SetTextScale(value) self.textScale = value end
    function window:SetUseClassColor(value) self.useClassColor = value end
    function window:SetShowBarIcons(value) self.showBarIcons = value end
    function window:SetBackgroundAlpha(value) self.backgroundAlpha = value end
    function window:IsNonInteractive() return self.nonInteractive end
    function window:SetNonInteractive(value) self.nonInteractive = value end
    function window:SetIsEditing(value) self.editing = value; self:Refresh() end
    function window:GetDamageMeterType() return self.damageMeterType end
    function window:GetDamageMeterTypeDropdown() return self.dropdown end
    function window:GetDamageMeterTypeName() return self.title end
    function window:GetSessionDropdown() return self.sessionDropdown end
    function window:GetDamageMeterOwner() return DamageMeter end
    function window:IsEditing() return self.editing end
    function window:IsShown() return self.shown end
    function window:HideSourceWindow() self.sourceHidden, self.sourceCloseCalls = true, self.sourceCloseCalls + 1 end
    function window:ClearSessionTimer() self.timerShown = false end
    function window:RegisterEvent(event) self.events[event] = true end
    function window:HookScript(script, callback)
        error("Do not hook native frame scripts")
    end
    function window:Refresh()
        self.refreshes = self.refreshes + 1
        local session = self:GetCombatSession()
        self.session = session
        for index, data in ipairs(session.combatSources) do
            assert(not issecretvalue(data.name) and not issecretvalue(data.totalAmount))
            data.maxAmount = session.maxAmount
            self.entries[index] = self.entries[index] or Entry()
            self:InitEntry(self.entries[index], data)
        end
        self:UpdateSessionTimerState(session)
    end
    window.nativeMethods = {}
    for key, value in pairs(window) do if type(value) == "function" then window.nativeMethods[key] = value end end
    window.nativeOpenMenu = dropdown.OpenMenu
    return window
end

local window, other = Window(legacyType), Window(deathsType)
DamageMeterPerCharacterSettings = { windowDataList = {
    { damageMeterType = legacyType }, { damageMeterType = deathsType },
    [4] = { damageMeterType = nativeType }, [7] = { damageMeterType = legacyType },
} }
local dataList = {
    { damageMeterType = legacyType, sessionWindow = window },
    { damageMeterType = deathsType, sessionWindow = other },
    [4] = { damageMeterType = nativeType }, [7] = { damageMeterType = legacyType },
}
DamageMeterMixin = {}
function DamageMeterMixin:GetWindowDataList() return dataList end
function DamageMeterMixin:ForEachSessionWindow(callback)
    for _, data in pairs(dataList) do if data.sessionWindow then callback(data.sessionWindow) end end
end
function DamageMeterMixin:SetupSessionWindow(_, data)
    data.sessionWindow = data.sessionWindow or Window(data.damageMeterType)
    data.sessionWindow:SetDamageMeterType(data.damageMeterType)
end
function DamageMeterMixin:SetSessionWindowDamageMeterType(target, value)
    for index, data in pairs(dataList) do
        if data.sessionWindow == target then
            data.damageMeterType = value
            DamageMeterPerCharacterSettings.windowDataList[index].damageMeterType = value
        end
    end
    target:SetDamageMeterType(value)
end
DamageMeter = {}
for key, method in pairs(DamageMeterMixin) do DamageMeter[key] = method end
local originalMixinSession = DamageMeterSessionWindowMixin.GetCombatSession
assert(loadfile("Modules/UnitFrames/ThreatMeter.lua"))("PyresinQoL", {
    RegisterModule = function(id, initialize) assert(id == "unitFrames"); initialize() end,
})

local function AssertNativeBoundary(target)
    -- Architectural regression check, not an emulation of WoW's taint engine.
    assert(target.InitEntry == DamageMeterSessionWindowMixin.InitEntry,
        "Threat replaces native InitEntry: secret sourceDisplayType comparisons now run in addon context")
    assert(target.GetCombatSession == DamageMeterSessionWindowMixin.GetCombatSession,
        "Threat must not intercept native combat-session data")
    assert(target.UpdateSessionTimerState == DamageMeterSessionWindowMixin.UpdateSessionTimerState,
        "Threat must not replace native timer logic")
    for key, method in pairs(target.nativeMethods) do assert(target[key] == method, "Native method changed: " .. key) end
    assert(target.dropdown.OpenMenu == target.nativeOpenMenu, "Do not replace native OpenMenu")
    for _, entry in ipairs(target.entries) do
        assert(entry.sourceDisplayType == nativeDisplayType, "Native secret fields must be passed through untouched")
    end
end

local function CountChildren(target, kind)
    local count = 0
    for _, frame in ipairs(created) do
        if frame.parent == target.container and frame.kind == kind then count = count + 1 end
    end
    return count
end

local function NativeState(target)
    return {
        sessionShown = target.sessionDropdown.shown, sessionWrites = target.sessionDropdown.setShownCalls,
        timerAlpha = target.timer.alpha, timerWrites = target.timer.setAlphaCalls,
        sourceHidden = target.sourceHidden, sourceCloseCalls = target.sourceCloseCalls,
    }
end

local function AssertNativeState(target, state)
    assert(target.sessionDropdown.shown == state.sessionShown and target.sessionDropdown.setShownCalls == state.sessionWrites)
    assert(target.timer.alpha == state.timerAlpha and target.timer.setAlphaCalls == state.timerWrites)
    assert(target.sourceHidden == state.sourceHidden and target.sourceCloseCalls == state.sourceCloseCalls,
        "Addon changed native source visibility")
end

local function AssertHeaderAnchors(target, popup)
    local dropdownPoint = assert(target.dropdown.points and target.dropdown.points[1], "Missing damage meter dropdown anchor")
    assert(#target.dropdown.points == 1 and dropdownPoint[1] == "TOPLEFT" and dropdownPoint[2] == target
        and dropdownPoint[3] == "TOPLEFT" and dropdownPoint[4] == 1 and dropdownPoint[5] == -3,
        "Damage meter dropdown must be anchored to the header")
    assert(dropdownPoint[2] ~= target.timer, "Damage meter dropdown inherited the timer anchor")

    local timerPoint = assert(target.timer.points and target.timer.points[1], "Missing session timer anchor")
    assert(#target.timer.points == 1 and timerPoint[1] == "RIGHT" and timerPoint[2] == target.sessionDropdown
        and timerPoint[3] == "LEFT" and timerPoint[4] == -5 and timerPoint[5] == -3,
        "Session timer must remain on the native session dropdown")

    local titlePoints = assert(target.title.points, "Missing damage meter title anchors")
    assert(#titlePoints == 2 and titlePoints[1][1] == "LEFT" and titlePoints[1][2] == target
        and titlePoints[2][1] == "RIGHT" and titlePoints[2][2] == target.timer
        and titlePoints[2][3] == "LEFT" and titlePoints[2][4] == -5 and titlePoints[2][5] == 3,
        "Damage meter title must retain its native left anchor and new timer-relative right anchor")

    assert(target.dropdown.menuAnchor == target.nativeMenuAnchor,
        "Native popup menu anchor must remain unchanged")
    if popup then
        assert(popup.anchor == target.nativeMenuAnchor and popup.anchor.relativeTo == target.dropdown,
            "Native menu popup must stay anchored to the header-relative dropdown")
    end
end

local function AssertThreatOption(option, active)
    assert(option.template == "PyresinQoLThreatMenuTemplate" and option.width == 120 and option.height == 20)
    assert(not option.AttachTexture and not option.AttachFontString)
    assert(option.Text.text == "Threat" and option.Icon.texture == "Interface\\Icons\\Ability_Warrior_FocusedRage")
    assert(option.Icon.width == 16 and option.Icon.height == 16)
    assert(option.Icon.point[1] == "LEFT" and option.Icon.point[2] == option
        and option.Icon.point[3] == "LEFT" and option.Icon.point[4] == 0 and option.Icon.point[5] == 0)
    assert(option.Icon.desaturated == not active and option.scripts.OnClick)
end

local function ClickThreatOption(option)
    option.scripts.OnClick(option, "LeftButton")
    assert(option.pickContext == MenuInputContext.MouseButton and option.pickButtonName == "LeftButton")
    assert(option.response == MenuResponse.Close, "Threat menu selection must close the native menu")
end

AssertNativeBoundary(window)
AssertNativeBoundary(other)
AssertHeaderAnchors(window)
AssertHeaderAnchors(other)
assert(window.damageMeterType == legacyType and dataList[1].damageMeterType == legacyType,
    "Addon must not migrate the native session type")
assert(window.source.damageMeterType == legacyType)
assert(DamageMeterPerCharacterSettings.windowDataList[1].damageMeterType == legacyType)
assert(dataList[7].damageMeterType == legacyType and DamageMeterPerCharacterSettings.windowDataList[7].damageMeterType == legacyType)
assert(other.damageMeterType == deathsType)
assert(DamageMeterSessionWindowMixin.GetCombatSession == originalMixinSession)
assert(nativeCalls == 0, "Addon startup must not invoke the native renderer")

-- Simulate Blizzard changing the native session before enabling the independent overlay.
DamageMeter:SetSessionWindowDamageMeterType(window, nativeType)
local nativeEntry, nativeSession = window.entries[1], window.session
local nativeUpdateName = nativeEntry.UpdateName
local display = Display(window)
local nativeState = NativeState(window)
assert(nativeCalls == 1 and window.session == nativeSession)
assert(window.damageMeterType == nativeType and dataList[1].damageMeterType == nativeType)
assert(display.clipsChildren and not display.active and not display.shown)
assert(window.title.text == "Damage Done" and window.sessionDropdown.shown and window.timer.alpha == nil)
assert(CountChildren(window, "Frame") == 1)
assert(menuModifyCalls == 1)

-- Each open rebuilds the native menu and installs a gray threat icon while inactive.
local root = window.dropdown:OpenMenu()
local threatOption = root.children[4]
local rebuiltRoot = window.dropdown:OpenMenu()
assert(root ~= rebuiltRoot, "Native menu descriptions must be rebuilt per open")
AssertHeaderAnchors(window, rebuiltRoot)
AssertThreatOption(rebuiltRoot.children[4], false)
threatOption = rebuiltRoot.children[4]
assert(not display.active and not display.shown and window.title.text == "Damage Done")

-- Selecting the addon button enables only the independent overlay and header title.
local callsBefore = nativeCalls
ClickThreatOption(threatOption)
assert(nativeCalls == callsBefore and window.session == nativeSession)
AssertNativeState(window, nativeState)
assert(display.active and display.shown and window.title.text == "Threat")
assert(#display.rows == 3)
assert(display.rows[1].Name.text == "1. party1" and display.rows[2].Name.text == "2. player")
assert(display.rows[1].Value.text == "100%" and display.rows[1].StatusBar.value == 100)
assert(display.rows[1].template == "DamageMeterEntryTemplate" and display.rows[1].icon.atlas == "class-WARRIOR")
assert(display.rows[1].sourceDisplayType == Enum.DamageMeterSourceDisplayType.Ally)
assert(display.rows[1].value == nil and display.rows[1].sourceName == nil, "Secrets belong only in native display sinks")
assert(nativeEntry.UpdateName == nativeUpdateName and nativeEntry.label.text == "Native")
AssertNativeBoundary(window)

-- Native timer refreshes may replace the timer text, including with restricted
-- values. Header and popup anchors must stay independent of that text.
local timerWrites = window.timer.setTextCalls
local timerRefreshes = nativeCalls
local secretTimer = Secret()
window.timerText = secretTimer
window:Refresh()
assert(nativeCalls == timerRefreshes + 1 and window.timer.text == secretTimer
    and window.timer.setTextCalls == timerWrites + 1,
    "Native timer refresh must own timer text updates")
AssertHeaderAnchors(window, rebuiltRoot)
window.timerText = "09:59:59"
window:Refresh()
assert(window.timer.text == "09:59:59" and window.timer.setTextCalls == timerWrites + 2)
AssertHeaderAnchors(window, rebuiltRoot)
local timerWritesAfterNative = window.timer.setTextCalls
Tick()
assert(window.timer.setTextCalls == timerWritesAfterNative,
    "Threat overlay polling must not write the native session timer")
nativeSession = window.session

callsBefore = nativeCalls
local activeRoot = window.dropdown:OpenMenu()
local activeThreat = activeRoot.children[4]
AssertThreatOption(activeThreat, true)
ClickThreatOption(activeThreat)
assert(display.active and display.shown and window.title.text == "Threat")
AssertNativeState(window, nativeState)

-- A native radio selection exits threat mode after Blizzard has updated its title.
local sameType = activeRoot.damage
sameType:Pick()
assert(nativeCalls == callsBefore + 1 and not display.active and not display.shown)
assert(window.damageMeterType == nativeType and window.title.text == "Damage Done")
AssertNativeBoundary(window)

local reselectRoot = window.dropdown:OpenMenu()
local reselectThreat = reselectRoot.children[4]
AssertThreatOption(reselectThreat, false)
ClickThreatOption(reselectThreat)
assert(display.active and display.shown and window.title.text == "Threat")

local differentRoot = window.dropdown:OpenMenu()
differentRoot.deaths:Pick()
assert(window.damageMeterType == deathsType and not display.active and not display.shown)
assert(window.title.text == "Deaths")
AssertNativeBoundary(window)

local activeAgain = window.dropdown:OpenMenu().children[4]
ClickThreatOption(activeAgain)
assert(display.active and display.shown and window.title.text == "Threat")
for style = 0, 3 do
    window:SetStyle(style)
    window:SetShowBarIcons(style % 2 == 0)
    window:SetTextScale(1.25)
    window:SetBackgroundAlpha(0.4)
    window:SetUseClassColor(style % 2 == 0)
    Tick()
    assert(display.rows[1].style == style and display.rows[1].showBarIcons == (style % 2 == 0))
    assert(display.rows[1].Name.scale == 1.25 and display.rows[1].backgroundAlpha == 0.4)
    assert(display.rows[1].StatusBar.value == 100)
    if DamageMeterEntryMixin then
        local expectedAtlas = style == 1 and "UI-HUD-CoolDownManager-Bar-BG" or "ui-damagemeters-bar-shadowbg"
        assert(display.rows[1].StatusBar.Background.atlas == expectedAtlas)
    end
end
window:SetStyle(0)
window:SetShowBarIcons(true)
window:SetUseClassColor(true)
Tick()
nativeEntry:SetNumberDisplayType(2)
assert(display.rows[1].Value.text == "100%" and nativeEntry.valueText.text == "42")

-- Native refreshes continue on native data; the addon updates only its own bars.
window:Refresh()
assert(window.session.combatSources[1].name == "Native")
AssertNativeBoundary(window)
-- Restricted numbers/names flow only to native display sinks, never comparisons/formatters.
local secretPercent, secretThreat, secretName = Secret(), Secret(), Secret()
states.player.percentage, states.player.threat, states.player.name = secretPercent, secretThreat, secretName
states.player.class = Secret()
callsBefore = nativeCalls
Emit("UNIT_THREAT_LIST_UPDATE")
assert(nativeCalls == callsBefore, "Threat events must not call native Refresh")
assert(display.rows[1].StatusBar.value == secretPercent and display.rows[1].Name.text == secretName)
assert(display.rows[1].Name.rank == 1 and display.rows[1].value == nil)
assert(display.rows[1].classFilename == nil and display.rows[1].icon.atlas == nil)
assert(display.rows[1].Value.text == secretPercent)
assert(nativeEntry.UpdateName == nativeUpdateName)
states.player = { percentage = 60, threat = 600, class = "MAGE" }

window:SetIsEditing(true)
local editingCalls = nativeCalls
local editingState = NativeState(window)
Tick()
assert(nativeCalls == editingCalls and not display.shown and window.title.text == "Deaths")
AssertNativeState(window, editingState)
window:SetIsEditing(false)
local resumedState = NativeState(window)
Tick()
assert(display.shown and window.title.text == "Threat")
AssertNativeState(window, resumedState)
for _, event in ipairs({ "UNIT_THREAT_LIST_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED" }) do
    assert(Watcher().events[event])
    local count = window.refreshes
    Emit(event)
    assert(window.refreshes == count, "Threat events must update only the overlay")
end
display.scripts.OnMouseWheel(display, -1)
assert(display.offset == 1 and not display.rows[1].shown and display.rows[2].shown)
Emit("PLAYER_TARGET_CHANGED")
assert(display.offset == 0 and display.rows[1].shown)
display.scripts.OnMouseWheel(display, -100)
assert(display.offset == 2)
display.scripts.OnMouseWheel(display, 100)
assert(display.offset == 0)
window:SetNonInteractive(true)
Tick()
assert(not display.mouse and not display.mouseWheel)
window:SetNonInteractive(false)
Tick()
assert(display.mouse and display.mouseWheel)

window.shown = false
targetExists = false
Emit("UNIT_THREAT_LIST_UPDATE")
assert(display.rows[1].shown, "Do not rebuild rows while the window is hidden")
window.shown = true
Tick()
assert(not display.rows[1].shown)
targetExists, hostile = true, false
Emit("PLAYER_TARGET_CHANGED")
assert(not display.rows[1].shown)
hostile = true
Tick()
assert(display.rows[1].shown)
local visibleName = display.rows[1].Name.text
window.minimized = true
Tick()
assert(not display:IsVisible() and display.rows[1].Name.text == visibleName)
window.minimized = false
Tick()
assert(display:IsVisible() and display.rows[1].shown, "Maximizing must refresh the threat display")
raid = true
states.raid1, states.raid2 = states.player, states.party1
Emit("GROUP_ROSTER_UPDATE")
assert(display.rows[1].Name.text == "1. raid2" and not display.rows[3].shown)
raid = false

-- Polling exits threat mode after Blizzard changes the native type.
DamageMeter:SetSessionWindowDamageMeterType(window, nativeType)
local changedState = NativeState(window)
local changedCalls = nativeCalls
Tick()
assert(nativeCalls == changedCalls and not display.active and not display.shown and window.title.text == "Damage Done")
AssertNativeState(window, changedState)
assert(window.damageMeterType == nativeType and window.title.text == "Damage Done")
AssertNativeBoundary(window)
local postChangeRoot = window.dropdown:OpenMenu()
local postChangeThreat = postChangeRoot.children[4]
AssertThreatOption(postChangeThreat, false)
ClickThreatOption(postChangeThreat)
assert(display.active and display.shown and window.title.text == "Threat")
AssertNativeState(window, changedState)
local menu = window.dropdown:OpenMenu()
assert(type(menu) == "table" and display.active and display.shown and window.title.text == "Threat")
AssertThreatOption(menu.children[4], true)
AssertNativeState(window, changedState)
assert(window.dropdown.OpenMenu == window.nativeOpenMenu)

-- New frames are discovered by the existing 0.2s owner tick, without duplicate overlays.
DamageMeter:SetupSessionWindow(4, dataList[4])
local future = dataList[4].sessionWindow
assert(not pcall(function() return Display(future) end), "Future windows must wait for the owner tick")
Tick()
local futureDisplay = Display(future)
AssertNativeBoundary(future)
AssertHeaderAnchors(future)
local futureRoot = future.dropdown:OpenMenu()
AssertHeaderAnchors(future, futureRoot)
local futureThreat = futureRoot.children[4]
AssertThreatOption(futureThreat, false)
ClickThreatOption(futureThreat)
assert(futureDisplay.active and futureDisplay.shown and future.title.text == "Threat")
assert(not Display(other).active)
local frameCount = #created
DamageMeter:SetupSessionWindow(4, dataList[4])
Tick()
assert(futureDisplay.active and #created == frameCount, "Reusing a native window must not rebuild the overlay")
local futureReopen = future.dropdown:OpenMenu()
assert(futureReopen ~= futureRoot and futureDisplay.active and future.title.text == "Threat")
AssertThreatOption(futureReopen.children[4], true)
assert(CountChildren(future, "Frame") == 1)
DamageMeter:SetSessionWindowDamageMeterType(future, deathsType)
Tick()
assert(not futureDisplay.active and not futureDisplay.shown and future.title.text == "Deaths")
print("PASS: native boundaries, dropdown icons, title caching, secret sinks, scrolling, visibility modes and future windows")
