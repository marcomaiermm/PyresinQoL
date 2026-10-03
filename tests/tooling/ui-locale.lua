-- Loaded before Core/Localization.lua only in the addon-localization fixture.
-- Blizzard's native strings have already loaded in the simulator's enUS locale.
PyresinQoLUITestNativeLocale = GetLocale()
function GetLocale() return "deDE" end
