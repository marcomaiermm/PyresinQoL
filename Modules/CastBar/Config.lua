local _, ns = ...
local castBar = ns.CastBar or {}
ns.CastBar = castBar

local defaults = {
    layout = "native", texture = "default", colorMode = "original", customColor = { r = 1, g = 1, b = 1 },
    width = 0, height = 0, fontSize = 0, showSpellName = true,
    namePosition = "native", nameAlignment = "native", nameSpacing = -1,
    timePosition = "native", timeAlignment = "native", timeSpacing = -1,
    timeFormat = "native", icon = "native", iconGap = 5, showSpark = true,
    borderStyle = "native", borderColorMode = "original", borderColor = { r = 1, g = 1, b = 1 },
    borderOpacity = 1, borderSize = 1,
    backgroundOpacity = -1, uninterruptible = "blizzard",
    animated = true, customInterruptTexture = true,
    uninterruptibleColor = { r = .7, g = .7, b = .7 },
    showLatency = false, latencyOpacity = .35,
}
local choices = {
    layout = { native = true, compact = true },
    colorMode = { original = true, class = true, custom = true },
    timeFormat = { native = true, remaining = true, remainingTotal = true },
    namePosition = { native = true, inside = true, above = true, below = true },
    timePosition = { native = true, inside = true, above = true, below = true, left = true, right = true },
    nameAlignment = { native = true, left = true, center = true, right = true },
    timeAlignment = { native = true, left = true, center = true, right = true },
    icon = { native = true, off = true, left = true, right = true, inside_left = true, inside_right = true },
    borderStyle = { native = true, thin = true, inset = true, none = true },
    borderColorMode = { original = true, class = true, custom = true },
    uninterruptible = { blizzard = true, custom = true },
}
local bounds = { iconGap = { 0, 12 }, borderOpacity = { 0, 1 }, borderSize = { 1, 3 }, width = { 100, 600 }, height = { 6, 48 }, fontSize = { 8, 24 },
    nameSpacing = { -1, 24 }, timeSpacing = { -1, 24 },
    backgroundOpacity = { 0, 1 }, latencyOpacity = { 0, 1 } }
local booleans = { animated = true, showSpellName = true, showSpark = true, showLatency = true, customInterruptTexture = true }

local function validColor(color)
    if type(color) ~= "table" then return false end
    for _, component in ipairs({ "r", "g", "b" }) do
        local value = color[component]
        if (issecretvalue and issecretvalue(value))
            or type(value) ~= "number" or value < 0 or value > 1 or value ~= value then return false end
    end
    return true
end

local function valid(key, value)
    if issecretvalue and issecretvalue(value) then return false end
    if defaults[key] == nil then return false end
    if key == "customColor" or key == "uninterruptibleColor" or key == "borderColor" then return validColor(value) end
    if key == "texture" then
        if type(value) ~= "string" then return false end
        if value == "default" then return true end
        local descriptor = castBar.GetTexture and castBar.GetTexture(value)
        return descriptor and descriptor.id == value or false
    end
    if choices[key] then return type(value) == "string" and choices[key][value] == true end
    if booleans[key] then return type(value) == "boolean" end
    if (key == "iconGap" or key == "borderSize" or key == "nameSpacing" or key == "timeSpacing")
        and (type(value) ~= "number" or value % 1 ~= 0) then return false end
    local range = bounds[key]
    return range and type(value) == "number" and value == value
        and ((value >= range[1] and value <= range[2])
            or ((key == "width" or key == "height" or key == "fontSize") and value == 0)
            or (key == "backgroundOpacity" and value == -1)) or false
end

local function copy(value)
    if type(value) ~= "table" then return value end
    return { r = value.r, g = value.g, b = value.b }
end

local function migrate()
    local saved = PyresinQoLDB and PyresinQoLDB.castBar
    if type(saved) ~= "table" or saved.showBorder == nil then return end
    if not choices.borderStyle[saved.borderStyle] and type(saved.showBorder) == "boolean" then
        saved.borderStyle = saved.showBorder and "native" or "none"
    end
    saved.showBorder = nil
end

function castBar.Get(key)
    migrate()
    local fallback = defaults[key]
    if fallback == nil then return nil end
    local saved = PyresinQoLDB and PyresinQoLDB.castBar
    if type(saved) == "table" and valid(key, saved[key]) then return copy(saved[key]) end
    return copy(fallback)
end

local function isDefault(key, value)
    local fallback = defaults[key]
    return type(value) == "table" and value.r == fallback.r and value.g == fallback.g and value.b == fallback.b
        or type(value) ~= "table" and value == fallback
end

function castBar.HasOverrides()
    migrate()
    local saved = PyresinQoLDB and PyresinQoLDB.castBar
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if valid(key, value) and not isDefault(key, value) then return true end
        end
    end
    return false
end

function castBar.Set(key, value)
    migrate()
    if not valid(key, value) then return false end
    PyresinQoLDB = PyresinQoLDB or {}
    local saved = type(PyresinQoLDB.castBar) == "table" and PyresinQoLDB.castBar or {}
    PyresinQoLDB.castBar = saved
    if isDefault(key, value) then saved[key] = nil else saved[key] = copy(value) end
    if castBar.Apply then castBar.Apply() end
    if castBar.RefreshControls then castBar.RefreshControls() end
    return true
end

function castBar.IsEnabled()
    return PyresinQoLDB and PyresinQoLDB.castBarCustomization == true or false
end

function castBar.SetEnabled(enabled)
    if type(enabled) ~= "boolean" then return false end
    PyresinQoLDB = PyresinQoLDB or {}
    PyresinQoLDB.castBarCustomization = enabled or nil
    if castBar.Apply then castBar.Apply() end
    if castBar.RefreshControls then castBar.RefreshControls() end
    return true
end

function castBar.Reset()
    if PyresinQoLDB then PyresinQoLDB.castBar = nil end
    if castBar.Apply then castBar.Apply() end
    if castBar.RefreshControls then castBar.RefreshControls() end
end
