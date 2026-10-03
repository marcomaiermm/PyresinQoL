local _, ns = ...

local actionBars = {}
local defaults = {
    actionBarColorIcons = false,
    actionBarColorHotkeys = false,
    actionBarRangeIconColor = "FFFF3333",
    actionBarManaIconColor = "FF6666FF",
    actionBarUnusableIconColor = "FF666666",
    actionBarRangeHotkeyColor = "FFFF3333",
    actionBarManaHotkeyColor = "FF6666FF",
    actionBarUnusableHotkeyColor = "FF666666",
    actionBarHotkeySize = 0,
    actionBarMacroSize = 0,
    actionBarCountSize = 0,
    actionBarCompactHotkeys = false,
}

actionBars.bars = {
    { id = "Main", frame = "MainActionBar", label = "actionBar1", prefix = "actionBarMain" },
    { id = "Bar2", frame = "MultiBarBottomLeft", label = "actionBar2", prefix = "actionBarBar2" },
    { id = "Bar3", frame = "MultiBarBottomRight", label = "actionBar3", prefix = "actionBarBar3" },
    { id = "Bar4", frame = "MultiBarRight", label = "actionBar4", prefix = "actionBarBar4" },
    { id = "Bar5", frame = "MultiBarLeft", label = "actionBar5", prefix = "actionBarBar5" },
    { id = "Bar6", frame = "MultiBar5", label = "actionBar6", prefix = "actionBarBar6" },
    { id = "Bar7", frame = "MultiBar6", label = "actionBar7", prefix = "actionBarBar7" },
    { id = "Bar8", frame = "MultiBar7", label = "actionBar8", prefix = "actionBarBar8" },
}

for _, bar in ipairs(actionBars.bars) do
    local prefix = bar.prefix
    defaults[prefix .. "Enabled"] = false
    defaults[prefix .. "HideCombat"] = false
    defaults[prefix .. "HideOutOfCombat"] = false
    defaults[prefix .. "HideStealth"] = false
    defaults[prefix .. "HideNotStealth"] = false
    defaults[prefix .. "HideForm"] = false
    defaults[prefix .. "HideNoForm"] = false
    defaults[prefix .. "AlphaNormal"] = 1
    defaults[prefix .. "AlphaCombat"] = 1
    defaults[prefix .. "Mouseover"] = false
    defaults[prefix .. "CustomCondition"] = ""
end

actionBars.defaults = defaults

local function validColor(value)
    return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") ~= nil
end

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function parseBranch(branch)
    branch = trim(branch)
    if branch == "" then return nil, "actionBarConditionBranch" end

    local position, conditions = 1, {}
    while true do
        while branch:sub(position, position) == " " do position = position + 1 end
        if branch:sub(position, position) ~= "[" then break end
        local close = branch:find("]", position + 1, true)
        if not close then return nil, "actionBarConditionBranch" end
        local condition = branch:sub(position + 1, close - 1)
        if condition:find("[%[%];]", 1) then
            return nil, "actionBarConditionBranch"
        end
        conditions[#conditions + 1] = "[" .. condition .. "]"
        position = close + 1
    end

    local result = trim(branch:sub(position))
    if result ~= "show" and result ~= "hide" then
        return nil, "actionBarConditionResult"
    end
    return (#conditions > 0 and table.concat(conditions) .. " " or "") .. result
end

function actionBars.ValidateCondition(value)
    if type(value) ~= "string" then return nil, "actionBarConditionType" end
    if #value > 1023 then return nil, "actionBarConditionLength" end
    if value:find("[%c|]", 1) then return nil, "actionBarConditionControl" end
    value = trim(value)
    if value == "" then return "" end

    local branches = {}
    for branch in (value .. ";"):gmatch("(.-);") do
        local normalized, errorKey = parseBranch(branch)
        if not normalized then return nil, errorKey end
        branches[#branches + 1] = normalized
    end
    return table.concat(branches, "; ")
end

local function valid(key, value)
    local fallback = defaults[key]
    if fallback == nil then return false end
    if key == "actionBarRangeIconColor" or key == "actionBarManaIconColor"
        or key == "actionBarUnusableIconColor" or key == "actionBarRangeHotkeyColor"
        or key == "actionBarManaHotkeyColor" or key == "actionBarUnusableHotkeyColor" then
        return validColor(value)
    end
    if key == "actionBarHotkeySize" or key == "actionBarMacroSize" or key == "actionBarCountSize" then
        return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 24
    end
    if key:match("Alpha") then return type(value) == "number" and value == value and value >= 0 and value <= 1 end
    if key:match("Enabled$") or key:match("Hide") or key:match("Mouseover$")
        or key == "actionBarColorIcons" or key == "actionBarColorHotkeys" or key == "actionBarCompactHotkeys" then
        return type(value) == "boolean"
    end
    if key:match("CustomCondition$") then return actionBars.ValidateCondition(value) ~= nil end
    return type(value) == type(fallback)
end

function actionBars.Get(key)
    local fallback = defaults[key]
    if fallback == nil then return nil end
    local value = PyresinQoLDB and PyresinQoLDB[key]
    if value ~= nil and valid(key, value) then return value end
    return fallback
end

ns.ActionBars = actionBars
