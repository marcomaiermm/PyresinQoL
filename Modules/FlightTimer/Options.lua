local _, ns = ...
local L = ns.L

-- Every option, for the settings page (Settings.lua) and the Edit Mode dialog alike: the saved key, whose
-- setting is PyresinQoL_<Key>, and choices as { value, label } pairs, a slider range (step 1 unless set) with
-- its value format (scaled: shown at the timer's scale), or neither for a checkbox.
-- A parent option greys this one out while it is off (false or "off"), or, with parentValue, while it is
-- anything else; section starts a group, set apart in the dialog.
local module = ns.GetModule("flightTimer")
module.flightTimerOptions = {
    { key = "flightTimerStyle", label = L.flightTimerStyle, default = "castbar", choices = {
        { "castbar", L.flightStyleCastBar }, { "swing", L.flightStyleSwing }, { "breath", L.flightStyleBreath },
        { "minimal", L.flightStyleMinimal } } },
    { key = "flightTimerMarker", label = L.flightTimerMarker, default = "pointed", choices = {
        { "pointed", L.flightMarkerPointed }, { "round", L.flightMarkerRound }, { "mount", L.flightMarkerMount }, { "name", L.flightMarkerName },
        { "none", L.flightMarkerNone } } },
    { key = "flightTimerTime", label = L.flightTimerTime, default = "left", choices = {
        { "off", L.flightTimeOff }, { "left", L.flightTimeLeft }, { "total", L.flightTimeTotal } } },
    { key = "flightTimerFlags", section = true, label = L.flightTimerFlags, default = "destination", choices = {
        { "both", L.flightFlagsBoth }, { "departure", L.flightFlagsDeparture },
        { "destination", L.flightFlagsDestination }, { "none", L.flightFlagsNone } } },
    { key = "flightTimerOverlap", label = L.flightTimerOverlap, default = "ends", choices = {
        { "ends", L.flightOverlapEnds }, { "marker", L.flightOverlapMarker }, { "both", L.flightOverlapBoth },
        { "none", L.flightOverlapNone } } },
    { key = "flightTimerZones", label = L.flightTimerZones, default = true },
    { key = "flightTimerScrollNames", label = L.flightTimerScrollNames, default = true },
    { key = "flightTimerStops", label = L.flightTimerStops, default = "scroll", section = true, choices = {
        { "off", L.flightStopsOff }, { "scroll", L.flightStopsScroll }, { "fixed", L.flightStopsFixed } } },
    { key = "flightTimerStopArrows", label = L.flightTimerStopArrows, default = true, parent = "flightTimerStops" },
    { key = "flightTimerShowPost", label = L.flightTimerShowPost, default = true, parent = "flightTimerStops",
        parentValue = "scroll" },
    { key = "flightTimerWidth", label = L.flightTimerWidth, default = 300, section = true, min = 100, max = 600, format = "%d px", scaled = true },
    { key = "flightTimerScale", label = L.flightTimerScale, default = 100, min = 50, max = 200, step = 10, format = "%d%%" },
}

-- Whether option's parent leaves it enabled, with get reading a saved value.
function module.FlightTimerOptionEnabled(option, get)
    local value = get(option.parent)
    if option.parentValue then return value == option.parentValue end
    return value ~= false and value ~= "off"
end

-- A slider's value text, also for the settings page of a disabled module; a scaled one reads what it
-- measures on screen.
function module.FormatFlightTimerOption(option, value)
    if option.scaled then
        for _, scale in ipairs(module.flightTimerOptions) do
            if scale.key == "flightTimerScale" then value = value * (PyresinQoLDB[scale.key] or scale.default) / 100 end
        end
    end
    return option.format:format(math.floor(value + 0.5))
end
