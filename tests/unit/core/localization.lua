local localeFiles = {}
for line in io.lines("PyresinQoL.toc") do
    if line:match("^Core/Locales/") then localeFiles[#localeFiles + 1] = line end
end

local function Load(locale)
    function GetLocale() return locale end
    local ns = {}
    assert(loadfile("Core/Localization.lua"))("PyresinQoL", ns)
    for _, file in ipairs(localeFiles) do assert(loadfile(file))("PyresinQoL", ns) end
    return ns.L
end

local function Placeholders(text)
    local found = {}
    for placeholder in text:gmatch("%%[-%d.]*[sdfi]") do found[#found + 1] = placeholder end
    return table.concat(found, " ")
end

-- partial: the locale only lists overrides on top of its base locale.
local function Compare(english, translated, path, partial)
    for key, value in pairs(english) do
        local text = rawget(translated, key)
        assert(type(text) == "string" or partial and text == nil, path .. key .. ": missing")
        if text ~= nil then assert(Placeholders(text) == Placeholders(value), path .. key .. ": placeholders differ") end
    end
    for key in pairs(translated) do assert(english[key] ~= nil, path .. key .. ": unknown key") end
end

local enUS = Load("enUS")
assert(#localeFiles == 8, "every locale file is listed in the TOC")
assert(Load("enGB").editMode == "Edit Mode", "enGB falls back to English")
for _, locale in ipairs({ "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "zhCN" }) do
    Compare(enUS, Load(locale), locale .. ": ", locale == "esMX")
end
local esMX = Load("esMX")
assert(esMX.editMode == "Modo de edición" and esMX.castBarNative == Load("esES").castBarNative, "esMX overrides esES")
assert(getmetatable(enUS) == nil and getmetatable(getmetatable(Load("deDE")).__index) == nil,
    "only the client locale loads")
print("PASS: locale files, fallbacks, keys and placeholders")
