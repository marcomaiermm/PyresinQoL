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
THREAT, UNKNOWNOBJECT, DAMAGE_METER_TYPE_DAMAGE_DONE = "Threat", "Unknown", "Damage Done"
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
    return {
        SetText = function(self, value) self.text = value end,
        SetFormattedText = function(self, format, index, name)
            self.format, self.rank = format, index
            self.text = issecretvalue(name) and name or string.format(format, index, name)
        end,
        GetText = function(self) return self.text end,
        SetAlpha = function(self, value) self.alpha = value end,
        SetPoint = function() end, SetAllPoints = function() end, ClearAllPoints = function() end,
        SetWidth = function() end, SetJustifyH = function() end,
        SetTextScale = function(self, value) self.scale = value end,
        SetShown = function(self, value) self.shown = value end,
        SetVertexColor = function(self, ...) self.color = { ... } end,
        SetColorTexture = function() end,
        SetAtlas = function(self, value) self.atlas = value end,
        SetTexture = function(self, value) self.texture, self.atlas = value, nil end,
    }
end
local created = {}
function CreateFrame(kind, name, parent, template)
    assert(template == nil or template == "DamageMeterEntryTemplate", "Do not use native source entry initializers")
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
    function frame:SetPoint() end
    function frame:ClearAllPoints() end
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
    if template then
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
UIParent = { GetEffectiveScale = function() return 0.5 end }
function GetCursorPosition() return 240, 180 end
AnchorUtil = { CreateAnchor = function(point, relativeTo, relativePoint, x, y)
    return { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
end }
local modifier
Menu = { ModifyMenu = function(tag, callback)
    assert(tag == "MENU_DAMAGE_METER_WINDOW_TRACKED_TYPE")
    modifier = callback
end }
local function Description(text, data, callback, selected)
    local d = { text = text, data = data, callback = callback, selected = selected, children = {} }
    function d:IsRadio() return self.selected ~= nil end
    function d:SetIsSelected() error("Do not replace native selection predicates") end
    function d:IsSelected() return self.selected and self.selected(self.data) or false end
    function d:CreateRadio(label, isSelected, onSelect, value)
        local child = Description(label, value, onSelect, isSelected)
        child.root = self.root or self
        table.insert(self.children, child)
        return child
    end
    function d:SetMinimumWidth(width) self.width = width end
    function d:AddMenuResponseCallback(callback)
        self.responses = self.responses or {}
        table.insert(self.responses, callback)
    end
    function d:Pick()
        self.callback(self.data)
        for _, callback in ipairs(self.root.responses or {}) do callback(nil, self) end
    end
    return d
end
MenuUtil = { TraverseMenu = function(root, callback)
    for _, category in ipairs(root.children) do
        callback(category)
        for _, option in ipairs(category.children) do callback(option) end
    end
end }

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
    self.title:SetText(value == deathsType and "Deaths" or "Damage Done")
    self:HideSourceWindow()
    self:Refresh()
end
function DamageMeterSessionWindowMixin:UpdateSessionTimerState() self.timerShown = true end

local function Window(value)
    local window = { damageMeterType = value, title = Text(), events = {}, entries = {}, shown = true, refreshes = 0 }
    for key, method in pairs(DamageMeterSessionWindowMixin) do window[key] = method end
    local dropdown = { parent = window }
    window.dropdown = dropdown
    function dropdown:GetParent() return self.parent end
    function dropdown:GetWidth() error("Do not copy restricted dropdown width") end
    function dropdown:SetMenuAnchor(anchor) self.anchor = anchor end
    function dropdown:OpenMenu()
        local root = Description("Root")
        for _, category in ipairs({ "Damage", "Healing", "Actions" }) do
            local description = Description(category)
            description.root = root
            table.insert(root.children, description)
        end
        local function Select(value) DamageMeter:SetSessionWindowDamageMeterType(window, value) end
        local function IsSelected(value) return window.damageMeterType == value end
        root.children[1]:CreateRadio("Damage Done", IsSelected, Select, nativeType)
        root.children[3]:CreateRadio("Deaths", IsSelected, Select, deathsType)
        modifier(self, root)
        assert(self.anchor.relativeTo == UIParent and self.anchor.x == 480 and self.anchor.y == 360)
        assert(root.width == 140, "The menu must not inherit a restricted minimum width")
        self.root = root
        return root
    end
    window.sessionDropdown = { Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end }
    window.sessionDropdown.shown = true
    function window.sessionDropdown:IsShown() return self.shown end
    function window.sessionDropdown:SetShown(shown) self.shown = shown end
    window.container = { GetFrameLevel = function() return 1 end,
        IsVisible = function() return window.shown and not window.minimized end }
    window.timer = Text()
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
    function window:HideSourceWindow() self.sourceHidden = true end
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
    { damageMeterType = legacyType }, { damageMeterType = deathsType }, [4] = { damageMeterType = legacyType },
} }
local dataList = {
    { damageMeterType = legacyType, sessionWindow = window },
    { damageMeterType = deathsType, sessionWindow = other },
    [4] = { damageMeterType = legacyType },
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
AssertNativeBoundary(window)
AssertNativeBoundary(other)
assert(window.damageMeterType == nativeType and dataList[1].damageMeterType == nativeType)
assert(window.source.damageMeterType == nativeType)
assert(DamageMeterPerCharacterSettings.windowDataList[1].damageMeterType == nativeType)
assert(dataList[4].damageMeterType == nativeType and DamageMeterPerCharacterSettings.windowDataList[4].damageMeterType == nativeType)
assert(other.damageMeterType == deathsType)
assert(DamageMeterSessionWindowMixin.GetCombatSession == originalMixinSession)
assert(nativeCalls == 0, "Migration must not invoke the native renderer from addon code")
window:Refresh()
local nativeEntry, nativeSession = window.entries[1], window.session
local nativeUpdateName = nativeEntry.UpdateName
local root = window.dropdown:OpenMenu()
assert(#root.children == 4 and root.children[3].children[1].text == "Deaths")
local threatOption = root.children[4]
assert(threatOption.text == "Threat")
local callsBefore = nativeCalls
threatOption:Pick()
local display = Display(window)
assert(nativeCalls == callsBefore and window.session == nativeSession)
assert(window.damageMeterType == nativeType and dataList[1].damageMeterType == nativeType)
assert(display.active and display.shown and display.clipsChildren)
assert(window.title.text == "Threat" and not window.sessionDropdown.shown and window.timer.alpha == 0)
assert(threatOption:IsSelected())
assert(#display.rows == 3)
assert(display.rows[1].Name.text == "1. party1" and display.rows[2].Name.text == "2. player")
assert(display.rows[1].Value.text == "100%" and display.rows[1].StatusBar.value == 100)
assert(display.rows[1].template == "DamageMeterEntryTemplate" and display.rows[1].icon.atlas == "class-WARRIOR")
assert(display.rows[1].sourceDisplayType == Enum.DamageMeterSourceDisplayType.Ally)
assert(display.rows[1].value == nil and display.rows[1].sourceName == nil, "Secrets belong only in native display sinks")
assert(nativeEntry.UpdateName == nativeUpdateName and nativeEntry.label.text == "Native")
AssertNativeBoundary(window)
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

-- Native refreshes continue on native data; post-hooks update only addon-owned bars.
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
Tick()
assert(not display.shown and window.title.text == "Damage Done" and window.sessionDropdown.shown)
assert(window.timer.alpha == 1)
window:SetIsEditing(false)
Tick()
assert(display.shown and window.title.text == "Threat" and not window.sessionDropdown.shown)
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
window.minimized = true
Emit("UNIT_THREAT_LIST_UPDATE")
assert(not display.rows[1].shown)
window.minimized = false
display.scripts.OnShow(display)
assert(display.rows[1].shown, "Maximizing must refresh the threat display")
raid = true
states.raid1, states.raid2 = states.player, states.party1
Emit("GROUP_ROSTER_UPDATE")
assert(display.rows[1].Name.text == "1. raid2" and not display.rows[3].shown)
raid = false

root.children[3].children[1]:Pick()
assert(not display.active and not display.shown and window.damageMeterType == deathsType and window.title.text == "Deaths")
assert(window.sessionDropdown.shown and window.timer.alpha == 1)
assert(window.entries[1].valueText.text == "42" and window.entries[1].OnClick)
assert(root.children[3].children[1]:IsSelected() and not threatOption:IsSelected())
AssertNativeBoundary(window)
window.dropdown:OpenMenu().children[4]:Pick()
assert(display.active)
root.children[1].children[1]:Pick()
assert(not display.active and window.title.text == "Damage Done")

-- New frames are configured through the already-created owner, not its mixin.
DamageMeter:SetupSessionWindow(4, dataList[4])
local future = dataList[4].sessionWindow
AssertNativeBoundary(future)
future.dropdown:OpenMenu().children[4]:Pick()
assert(Display(future).active and not Display(other).active)
local frameCount = #created
DamageMeter:SetupSessionWindow(4, dataList[4])
Tick()
assert(Display(future).active and #created == frameCount, "Reusing a native window must not rebuild the overlay")
assert(future.title.text == "Threat")
DamageMeter:SetSessionWindowDamageMeterType(future, deathsType)
Tick()
assert(not Display(future).active)
assert(#future.dropdown:OpenMenu().children == 4)
print("PASS: native functions untouched; Blizzard visual template/styles, secret display sinks, menus, migration, scrolling, editing and future windows")
