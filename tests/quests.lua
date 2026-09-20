-- Run from the addon directory: lua tests/quests.lua
local module = {}
local ns, events, delayed = {}, nil, nil
unpack = unpack or table.unpack
local quests = {
    { questID = 1, questLevel = 4, title = "Trivial", difficulty = "gray" },
    { questID = 2, questLevel = 10, title = "Easy", difficulty = "green" },
    { questID = 3, questLevel = 14, title = "Westfall Stew", difficulty = "yellow" },
    { questID = 4, questLevel = 17, title = "A long quest title that wraps onto another line", difficulty = "orange" },
    { questID = 5, questLevel = 20, title = "Dangerous", difficulty = "red" },
    { questID = 6, questLevel = 0, title = "Unknown level", difficulty = "yellow" },
}
local colors = {
    gray = { r = .5, g = .5, b = .5 }, green = { r = .25, g = .75, b = .25 },
    yellow = { r = 1, g = 1, b = 0 }, orange = { r = 1, g = .5, b = 0 }, red = { r = 1, g = 0, b = 0 },
}
function CreateColor(r, g, b)
    return { WrapTextInColorCode = function(_, text)
        return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
    end }
end
function GetDifficultyColor(difficulty) return assert(colors[difficulty]) end
C_PlayerInfo = { GetContentDifficultyQuestForPlayer = function(id) return quests[id].difficulty end }
C_QuestLog = { GetQuestDifficultyLevel = function(id) return quests[id].questLevel end }
function hooksecurefunc(object, method, callback)
    if type(object) == "string" then object, method, callback = _G, object, method end
    local original = assert(object[method])
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
function CreateFrame()
    events = {
        RegisterEvent = function(_, name) assert(name == "PLAYER_LEVEL_UP") end,
        SetScript = function(self, name, callback) assert(name == "OnEvent"); self.callback = callback end,
    }
    return events
end
C_Timer = { After = function(delay, callback) assert(delay == 0); delayed = callback end }
local function Font()
    local font = { color = { 0.1, 0.2, 0.3, 0.4 }, offset = { 0, 0 }, font = { "QuestFont.ttf", 14, "" },
        points = { { "TOPLEFT", "button", "TOPLEFT", 20, 0 } }, width = 275 }
    function font:GetFont() return unpack(self.font) end
    function font:SetFont(...) self.font = { ... } end
    function font:GetShadowColor() return unpack(self.color) end
    function font:GetShadowOffset() return unpack(self.offset) end
    function font:SetShadowColor(...) self.color = { ... } end
    function font:SetShadowOffset(...) self.offset = { ... } end
    function font:GetNumPoints() return #self.points end
    function font:GetPoint(index) return unpack(self.points[index]) end
    function font:ClearAllPoints() self.points = {} end
    function font:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function font:GetWidth() return self.width end
    function font:SetWidth(width) self.width = width end
    function font:SetJustifyH() end
    function font:SetText(text) self.text = text end
    function font:GetStringWidth() return #self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 7 end
    function font:Hide() self.shown = false end
    function font:Show() self.shown = true end
    return font
end
local function Button(id, active)
    local font = Font()
    return {
        id = id, isActive = active, Icon = { GetHeight = function() return 16 end },
        GetFontString = function() return font end,
        CreateFontString = function() return Font() end,
        GetID = function(self) return self.id end,
        GetText = function(self) return self.text end,
        SetText = function(self, text) self.text = text end,
        GetTextHeight = function(self) return #self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 7 > font.width and 32 or 16 end,
        SetHeight = function(self, height) self.height = height end,
    }
end
local greeting = { Button(1, 1), Button(1, 0), Button(2, 0), Button(3, 0) }
function GetActiveQuestID(index) assert(index == 1); return 2 end
function GetAvailableQuestInfo(index) return false, 0, false, false, ({ 3, 4, 6 })[index] end
QuestFrameGreetingPanel = {
    shown = true, IsShown = function(self) return self.shown end,
    titleButtonPool = { EnumerateActive = function()
        local index = 0
        return function() index = index + 1; return greeting[index] end
    end },
}
function QuestFrameGreetingPanel_OnShow()
    for _, button in ipairs(greeting) do
        local id = button.isActive == 1 and GetActiveQuestID(button.id) or select(5, GetAvailableQuestInfo(button.id))
        button:SetText(quests[id].title)
        button:SetHeight(16)
    end
end
-- XML binds the original OnShow function before the addon hooks its global name.
local greetingOnShow = QuestFrameGreetingPanel_OnShow
local greetingShowHooks = {}
function QuestFrameGreetingPanel:HookScript(event, callback)
    assert(event == "OnShow")
    greetingShowHooks[#greetingShowHooks + 1] = callback
end
local function OpenGreeting()
    QuestFrameGreetingPanel.shown = true
    greetingOnShow(QuestFrameGreetingPanel)
    for _, callback in ipairs(greetingShowHooks) do callback(QuestFrameGreetingPanel) end
end
local function Setup(button, info)
    button.id = info.questID
    button:SetText(info.title)
    button:SetHeight(math.max(button:GetTextHeight() + 2, button.Icon:GetHeight()))
end
GossipAvailableQuestButtonMixin, GossipActiveQuestButtonMixin = { Setup = Setup }, { Setup = Setup }
local available, active = Button(), Button()
GossipFrame = { shown = true, IsShown = function(self) return self.shown end, Update = function()
    GossipAvailableQuestButtonMixin.Setup(available, quests[3])
    GossipActiveQuestButtonMixin.Setup(active, quests[2])
end }
PyresinQoLDB = { questLevels = true }
local detailQuestID = 3
function GetQuestID() return detailQuestID end
QUEST_TEMPLATE_DETAIL, QUEST_TEMPLATE_REWARD, QUEST_TEMPLATE_LOG = {}, {}, { questLog = true }
QuestInfoFrame = {}
QuestFrameDetailPanel = { shown = false, IsShown = function(self) return self.shown end }
QuestFrameRewardPanel = { shown = false, IsShown = function(self) return self.shown end }
QuestInfoTitleHeader = {
    SetText = function(self, text) self.text = text end,
    GetText = function(self) return self.text end,
}
function QuestInfo_ShowTitle()
    QuestInfoTitleHeader:SetText(QuestInfoFrame.questLog and "Quest log title" or quests[detailQuestID].title)
end
function QuestInfo_Display(template)
    QuestInfoFrame.questLog = template.questLog
    QuestInfo_ShowTitle()
end
ns.RegisterModule = function(id, initialize) assert(id == "quests"); initialize(module) end
assert(loadfile("Modules/Quests/Quests.lua"))("PyresinQoL", ns)
local function Expected(info)
    return info.title
end
local function CheckLevel(button, info)
    local color = colors[info.difficulty]
    local prefix = button.PyresinQuestLevel
    assert(prefix.shown and prefix.text == CreateColor(color.r, color.g, color.b):WrapTextInColorCode(("[%d]"):format(info.questLevel)))
    assert(prefix.font[1] == "QuestFont.ttf" and prefix.font[2] == 14 and prefix.font[3] == "OUTLINE")
    local font = button:GetFontString()
    local offset = prefix:GetStringWidth() + 4
    assert(font.points[1][4] == 20 + offset and font.width == 275 - offset, "Reserve level width without accumulating padding")
    assert(prefix.points[1][2] == font and prefix.points[1][4] == -offset)
end
OpenGreeting()
assert(greeting[2].PyresinQuestLevel and greeting[2].PyresinQuestLevel.shown,
    "Opening the NPC greeting through its XML OnShow must display quest levels")
CheckLevel(greeting[1], quests[2])
CheckLevel(greeting[2], quests[3])
OpenGreeting()
CheckLevel(greeting[2], quests[3])
QuestFrameGreetingPanel_OnShow(QuestFrameGreetingPanel) -- QUEST_LOG_UPDATE rebuilds by global name.
CheckLevel(greeting[2], quests[3])
for _ = 1, 3 do
    module.UpdateQuestLevels()
    assert(greeting[1].text == Expected(quests[2]) and greeting[2].text == Expected(quests[3]))
    assert(greeting[3].text == Expected(quests[4]) and greeting[3].height == 34)
    assert(greeting[4].text == quests[6].title, "Do not invent unknown levels")
    assert(available.text == Expected(quests[3]) and active.text == Expected(quests[2]))
    CheckLevel(available, quests[3])
    CheckLevel(greeting[2], quests[3])
    local font = available:GetFontString()
    assert(font.color[4] == 0.4 and font.offset[1] == 0)
    assert(font.font[1] == "QuestFont.ttf" and font.font[2] == 14 and font.font[3] == "",
        "Preserve the native font and shadow without adding an outline")
end
-- Reused ScrollBox rows and height-measuring rows run the same Setup path.
for index = 1, 5 do
    GossipAvailableQuestButtonMixin.Setup(available, quests[index])
    assert(available.text == Expected(quests[index]) and available.id == index)
    CheckLevel(available, quests[index])
end
local reusedPrefix = available.PyresinQuestLevel
GossipAvailableQuestButtonMixin.Setup(available, quests[6])
assert(not reusedPrefix.shown and available:GetFontString().width == 275, "Unknown levels hide the reused prefix and restore spacing")
GossipAvailableQuestButtonMixin.Setup(available, quests[3])
assert(available.PyresinQuestLevel == reusedPrefix, "Reuse the level FontString")
local wrapping = { questID = 3, questLevel = 14, title = string.rep("A", 36) }
GossipAvailableQuestButtonMixin.Setup(available, wrapping)
assert(available.height == 34, "Title wraps within the space remaining beside the level")
PyresinQoLDB.questLevels = false
GossipAvailableQuestButtonMixin.Setup(available, wrapping)
assert(available.height == 18, "Disabling removes extra wrapping height as well as prefix spacing")
PyresinQoLDB.questLevels = true
local fallback = { questID = 3, questLevel = -1, title = quests[3].title }
GossipActiveQuestButtonMixin.Setup(active, fallback)
assert(active.text == Expected(quests[3]))
CheckLevel(active, quests[3])
local annotated = { questID = 1, questLevel = 4, title = "|cff808080Trivial (Ignored)|r", difficulty = "gray" }
GossipAvailableQuestButtonMixin.Setup(available, annotated)
assert(available.text == Expected(annotated), "Preserve native title colors and annotations after the colored prefix")
PyresinQoLDB.questLevels = false
module.UpdateQuestLevels()
assert(greeting[2].text == "Westfall Stew" and available.text == "Westfall Stew")
for _, button in ipairs({ greeting[2], available, active }) do
    local font = button:GetFontString()
    assert(font.color[1] == 0.1 and font.color[2] == 0.2 and font.color[3] == 0.3 and font.color[4] == 0.4)
    assert(font.offset[1] == 0 and font.offset[2] == 0 and not button.PyresinQuestStyle,
        "Original shadow remains untouched after repeated pooled-row updates")
    assert(font.font[1] == "QuestFont.ttf" and font.font[2] == 14 and font.font[3] == "",
        "Original font flags remain untouched")
    assert(not button.PyresinQuestLevel.shown and not button.PyresinQuestTitleLayout)
    assert(font.width == 275 and #font.points == 1 and font.points[1][4] == 20, "Disabling restores title layout")
end
PyresinQoLDB.questLevels = true
events.callback()
assert(delayed, "Refresh after player level has updated")
quests[3].difficulty = "green"
delayed()
assert(greeting[2].text == Expected(quests[3]) and available.text == Expected(quests[3]))
QuestFrameGreetingPanel.shown, GossipFrame.shown = false, false
greeting[2].text = "hidden"
module.UpdateQuestLevels()
assert(greeting[2].text == "hidden")
for _, template in ipairs({ QUEST_TEMPLATE_DETAIL, QUEST_TEMPLATE_REWARD }) do
    for _ = 1, 3 do
        QuestInfo_Display(template)
        assert(QuestInfoTitleHeader.text == "[14] Westfall Stew", "Add the level once to the native heading")
    end
end
QuestFrameDetailPanel.shown = true
PyresinQoLDB.questLevels = false
module.UpdateQuestLevels()
assert(QuestInfoTitleHeader.text == "Westfall Stew", "Live disable restores the native heading")
PyresinQoLDB.questLevels = true
module.UpdateQuestLevels()
assert(QuestInfoTitleHeader.text == "[14] Westfall Stew")
detailQuestID = 6
QuestInfo_Display(QUEST_TEMPLATE_DETAIL)
assert(QuestInfoTitleHeader.text == "Unknown level")
QuestInfo_Display(QUEST_TEMPLATE_LOG)
module.UpdateQuestLevels()
assert(QuestInfoTitleHeader.text == "Quest log title", "Leave shared quest-log headings alone")
print("PASS: NPC quest levels, five difficulty colors, both dialogs, wrapping, reuse, toggle and level-up refresh")
