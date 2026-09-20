-- lua tests/experience.lua [de] [path-to-Forever-UI-source]
local ns, module = {}, {}
function GetLocale() return arg[1] == "de" and "deDE" or "enUS" end
assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
local current, maximum, rested, nativeVisible = 7040, 10100, 5050, false
local secret = {}
function issecretvalue(value) return value == secret end
function FormatLargeNumber(value) return tostring(math.floor(value)) end
function GetXPExhaustion() return rested end
function GetRestState() return rested and 1 or 2 end
function GetCVarBool() return nativeVisible end
XPBAR_LABEL, XP_STATUS_BAR_TEXT = "Experience", "XP: %d/%d"
PyresinQoLDB = { xpTextFormat = "both", xpAlwaysShow = true, xpTooltip = true, xpQuestRewards = true }
StatusTrackingBarInfo = { BarsEnum = { Experience = 4 } }
StatusTrackingBarManager = { barContainers = {}, IsTextLocked = function() return false end }

-- Optionally verify hooks against the actual 1.60.1.69913 Blizzard mixins.
if arg[2] then
    local root = arg[2] .. "/Interface/AddOns/Blizzard_StatusTrackingBar/"
    dofile(root .. "Shared/StatusTrackingBar.lua")
    dofile(root .. "Shared/ExpBar.lua")
    dofile(root .. "Mainline/ExpBarOverrides.lua")
else
    StatusTrackingBarMixin = {
        SetBarText = function(self, text) self.OverlayFrame.Text:SetText(text) end,
        UpdateTextVisibility = function(self)
            self.OverlayFrame.Text:SetShown(nativeVisible or self.textLocked or false)
        end,
    }
    ExpBarMixin = { UpdateStatusBarTextures = function() end, UpdateCurrentText = function(self)
        self:SetBarText(XP_STATUS_BAR_TEXT:format(self.currXP, self.maxBar))
    end }
end
local function Frame()
    local frame = { scripts = {}, events = {} }
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:HookScript(name, fn)
        local old = self.scripts[name]
        self.scripts[name] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    function frame:RegisterEvent(name) self.events[name] = true end
    function frame:UnregisterEvent(name) self.events[name] = nil end
    function frame:GetWidth() return self.width or 1010 end
    function frame:SetBarTexture() end
    function frame:SetAnimationTextures() end
    function frame:CreateTexture()
        return {
            SetAtlas = function(self, atlas) self.atlas = atlas end,
            SetAlpha = function(self, alpha) self.alpha = alpha end,
            ClearAllPoints = function(self) self.points = {} end,
            SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end,
            SetWidth = function(self, width) self.width = width end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
        }
    end
    return frame
end
local timers = {}
C_Timer = { After = function(delay, callback)
    assert(delay == 0)
    timers[#timers + 1] = callback
end }
local function FlushTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
local events
local function Emit(event)
    events.scripts.OnEvent(events, event)
    FlushTimers()
end
function CreateFrame() events = Frame(); return events end
function hooksecurefunc(object, name, fn)
    local old = object[name]
    object[name] = function(...) old(...); fn(...) end
end
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    IsOwned = function(self, owner) return self.owner == owner end,
    SetText = function(self, title) self.title = title; self.lines = {} end,
    AddDoubleLine = function(self, label, value) self.lines[label] = value end,
    AddLine = function(self, text) self.lines[text] = true end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false; self.owner = nil end,
}
for index = 1, 2 do
    local bar = Frame()
    for name, fn in pairs(StatusTrackingBarMixin) do bar[name] = fn end
    bar.UpdateCurrentText = ExpBarMixin.UpdateCurrentText
    bar.UpdateStatusBarTextures = ExpBarMixin.UpdateStatusBarTextures
    bar.currXP, bar.maxBar = current, maximum
    bar.StatusBar = Frame()
    bar.OverlayFrame = { Text = {
        SetText = function(self, text) self.text = text end,
        SetShown = function(self, shown) self.shown = not not shown end,
        Hide = function(self) self.shown = false end,
    } }
    function bar:GetLevelData() return current, maximum end
    bar.ExhaustionTick = Frame()
    function bar.ExhaustionTick:ExhaustionToolTipText()
        GameTooltip:SetOwner("native")
        GameTooltip:SetText("Native tooltip")
        GameTooltip:Show()
    end
    bar:SetScript("OnEnter", function(self)
        self.textLocked = true
        self:UpdateTextVisibility()
        self.ExhaustionTick:ExhaustionToolTipText()
    end)
    bar:SetScript("OnLeave", function(self)
        self.textLocked = false
        self:UpdateTextVisibility()
        GameTooltip:Hide()
    end)
    bar.ExhaustionTick:SetScript("OnEnter", bar.ExhaustionTick.ExhaustionToolTipText)
    bar.ExhaustionTick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    StatusTrackingBarManager.barContainers[index] = { bars = { [4] = bar } }
end
local bar = StatusTrackingBarManager.barContainers[1].bars[4]
local second = StatusTrackingBarManager.barContainers[2].bars[4]
local entries = {
    { isHeader = true, isCollapsed = true },
    { questID = 1, ready = true, xp = 170 },
    { questID = 2, ready = false, xp = 1000 }, -- failed/incomplete
    { questID = 3, ready = true, xp = 4400 },
    { questID = 4, ready = true, xp = 0 },
    { questID = 5, isHidden = true, ready = true, xp = 9999 },
}
local scans = 0
C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries, 5 end,
    GetInfo = function(index) scans = scans + 1; return entries[index] end,
    ReadyForTurnIn = function(id) return entries[id + 1].ready end,
    SetSelectedQuest = function() error("Do not change quest selection") end,
}
function GetQuestLogRewardXP(id) return entries[id + 1].xp end
function ExpandQuestHeader() error("Do not change collapsed headers") end
function CollapseQuestHeader() error("Do not change collapsed headers") end
ns.RegisterModule = function(id, initialize) assert(id == "experience"); initialize(module) end
assert(loadfile("Modules/Experience/Experience.lua"))("PyresinQoL", ns)
module.UpdateExperience() -- Settings can fire before login.
events.scripts.OnEvent(events, "PLAYER_LOGIN")
assert(not events.events.PLAYER_LOGIN)
assert(bar.OverlayFrame.Text.text == "7040 / 10100 (69.7%)" and bar.OverlayFrame.Text.shown)
assert(second.OverlayFrame.Text.text == bar.OverlayFrame.Text.text)
assert(bar.PyresinQuestPreview.shown and second.PyresinQuestPreview.shown)
assert(bar.PyresinQuestPreview.atlas == "UI-HUD-ExperienceBar-Fill-Rested" and bar.PyresinQuestPreview.alpha == 0.25)
bar:UpdateStatusBarTextures(false)
assert(bar.PyresinQuestPreview.atlas == "UI-HUD-ExperienceBar-Fill-Experience" and bar.PyresinQuestPreview.alpha == 0.25)
bar:UpdateStatusBarTextures(true)
assert(bar.PyresinQuestPreview.atlas == "UI-HUD-ExperienceBar-Fill-Rested", "Preview must track native rested texture changes")
assert(math.abs(bar.PyresinQuestPreview.width - 306) < 0.001, "Quest preview must stop at the level boundary")
assert(math.abs(bar.PyresinQuestPreview.points[1][4] - 704) < 0.001, "Quest preview must start at current XP")
bar.StatusBar.width = 505
bar.StatusBar.scripts.OnSizeChanged()
assert(math.abs(bar.PyresinQuestPreview.width - 153) < 0.001)
assert(math.abs(bar.PyresinQuestPreview.points[1][4] - 352) < 0.001, "Preview must follow bar resizing")
PyresinQoLDB.xpTextFormat = "percent"
module.UpdateExperience()
assert(bar.OverlayFrame.Text.text == "69.7%")
PyresinQoLDB.xpTextFormat = "value"
PyresinQoLDB.xpAlwaysShow = false
module.UpdateExperience()
assert(bar.OverlayFrame.Text.text == "7040 / 10100" and not bar.OverlayFrame.Text.shown)
bar.scripts.OnEnter(bar)
assert(bar.OverlayFrame.Text.shown and not second.OverlayFrame.Text.shown)
assert(GameTooltip.lines[ns.L.xpCompletedQuests] == "3 / 4")
assert(GameTooltip.lines[ns.L.xpQuestXP] == "4570 (45.2%)")
assert(GameTooltip.lines[ns.L.xpRemaining] == "3060 (30.3%)")
assert(GameTooltip.lines[ns.L.xpRested] == "5050 (50.0%)")
entries[2].ready = false
entries[4].xp = 4500
Emit("QUEST_LOG_UPDATE")
assert(GameTooltip.lines[ns.L.xpCompletedQuests] == "2 / 4" and GameTooltip.lines[ns.L.xpQuestXP] == "4500 (44.6%)")
bar.scripts.OnLeave(bar)
assert(not bar.OverlayFrame.Text.shown and not GameTooltip.shown)
local before = scans
Emit("QUEST_LOG_UPDATE")
assert(scans > before and not GameTooltip.shown, "Quest updates refresh the preview with the tooltip closed")
PyresinQoLDB.xpAlwaysShow = true
bar:UpdateCurrentText()
bar:UpdateTextVisibility()
assert(bar.OverlayFrame.Text.shown, "Native updates must preserve custom text visibility")
current, maximum, rested = 0, 12000, nil
bar.currXP, bar.maxBar = current, maximum
bar:UpdateCurrentText()
assert(bar.OverlayFrame.Text.text == "0 / 12000")
assert(math.abs(bar.PyresinQuestPreview.width - 189.375) < 0.001
    and bar.PyresinQuestPreview.points[1][4] == 0, "Preview must follow XP and level changes")
second.ExhaustionTick.scripts.OnEnter(second.ExhaustionTick)
assert(GameTooltip.owner == second.ExhaustionTick and GameTooltip.lines[ns.L.xpRested] == "0 (0.0%)")
PyresinQoLDB.xpQuestRewards = false
before = scans
module.UpdateExperience()
assert(not GameTooltip.lines[ns.L.xpQuestXP] and scans == before)
assert(not bar.PyresinQuestPreview.shown and not second.PyresinQuestPreview.shown)
PyresinQoLDB.xpTooltip = false
module.UpdateExperience()
assert(GameTooltip.title == "Native tooltip")
PyresinQoLDB.xpTextFormat = "blizzard"
module.UpdateExperience()
assert(bar.OverlayFrame.Text.text == "XP: 0/12000" and not bar.OverlayFrame.Text.shown)
PyresinQoLDB.xpTextFormat = "both"
maximum = 0
module.UpdateExperience()
assert(not bar.OverlayFrame.Text.shown, "No division by zero at level cap")
PyresinQoLDB.xpQuestRewards = true
module.UpdateExperience()
assert(not bar.PyresinQuestPreview.shown, "No quest preview at zero max XP")
maximum = 12000
current = secret
module.UpdateExperience()
assert(bar.OverlayFrame.Text.text == "XP: 0/12000", "Leave native text alone for secret values")
assert(not bar.PyresinQuestPreview.shown, "Hide preview when XP is secret")
current = 0
PyresinQoLDB.xpTooltip = true
second.scripts.OnEnter(second)
second.scripts.OnHide(second)
assert(not GameTooltip.shown)
entries[4].ready = false
Emit("QUEST_LOG_UPDATE")
assert(not bar.PyresinQuestPreview.shown and not second.PyresinQuestPreview.shown, "Zero quest XP must clear both previews")
print("PASS: Forever XP bars, formats, tooltip, quest preview, resizing, overflow, toggles and live refresh")

-- One summary serves both renderers; bursts are coalesced before any scan.
entries[4].ready = true
bar.scripts.OnEnter(bar)
before = scans
for _ = 1, 100 do events.scripts.OnEvent(events, "QUEST_LOG_UPDATE") end
assert(scans == before and #timers == 1, "Quest event bursts must schedule only one refresh")
FlushTimers()
assert(scans - before == #entries, "Tooltip and both previews must share one quest scan")
assert(GameTooltip.lines[ns.L.xpQuestXP] == "4500 (37.5%)" and bar.PyresinQuestPreview.shown
    and second.PyresinQuestPreview.shown)
before = scans
Emit("UPDATE_EXHAUSTION")
Emit("PLAYER_XP_UPDATE")
module.UpdateExperience()
bar.scripts.OnLeave(bar)
bar.scripts.OnEnter(bar)
assert(scans == before, "XP, rested XP, settings and hover must reuse the quest summary")
entries[4].xp = 4200
Emit("PLAYER_LEVEL_UP")
assert(scans - before == #entries and GameTooltip.lines[ns.L.xpQuestXP] == "4200 (35.0%)",
    "Level changes must refresh scaled quest rewards")
PyresinQoLDB.xpQuestRewards = false
module.UpdateExperience()
before = scans
entries[4].xp = 3600
Emit("QUEST_LOG_UPDATE")
assert(scans == before and not bar.PyresinQuestPreview.shown, "Disabled quest rewards must not scan")
PyresinQoLDB.xpQuestRewards = true
module.UpdateExperience()
assert(scans - before == #entries and GameTooltip.lines[ns.L.xpQuestXP] == "3600 (30.0%)",
    "Re-enabling must immediately refresh the summary")
before = scans
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
GameTooltip:SetOwner("another tooltip")
FlushTimers()
assert(scans - before == #entries and GameTooltip.owner == "another tooltip",
    "A queued refresh must not steal a tooltip that changed owners")
print("PASS: shared quest summary, burst coalescing, invalidation and tooltip ownership")
