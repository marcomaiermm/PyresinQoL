local _, ns = ...
local L = ns.L

-- Every option, for the settings page (Settings.lua) and the Edit Mode dialog alike: the saved key, whose
-- setting is PyresinQoL_<Key>, and choices as { value, label } pairs, a slider range, or neither for a checkbox.
-- A parent option greys this one out while it is off.
ns.GetModule("flightTimer").flightTimerOptions = {
    { key = "flightTimerStyle", label = L.flightTimerStyle, default = "castbar", choices = {
        { "castbar", L.flightStyleCastBar }, { "swing", L.flightStyleSwing }, { "breath", L.flightStyleBreath },
        { "minimal", L.flightStyleMinimal } } },
    { key = "flightTimerMarker", label = L.flightTimerMarker, default = "pointed", choices = {
        { "pointed", L.flightMarkerPointed }, { "round", L.flightMarkerRound }, { "name", L.flightMarkerName },
        { "none", L.flightMarkerNone } } },
    { key = "flightTimerFlags", label = L.flightTimerFlags, default = "destination", choices = {
        { "both", L.flightFlagsBoth }, { "departure", L.flightFlagsDeparture },
        { "destination", L.flightFlagsDestination }, { "none", L.flightFlagsNone } } },
    { key = "flightTimerOverlap", label = L.flightTimerOverlap, default = "ends", choices = {
        { "ends", L.flightOverlapEnds }, { "marker", L.flightOverlapMarker }, { "both", L.flightOverlapBoth },
        { "none", L.flightOverlapNone } } },
    { key = "flightTimerShowStops", label = L.flightTimerShowStops, default = true },
    { key = "flightTimerStops", label = L.flightTimerStops, default = "scroll", parent = "flightTimerShowStops",
        choices = { { "scroll", L.flightStopsScroll }, { "fixed", L.flightStopsFixed } } },
    { key = "flightTimerStopArrows", label = L.flightTimerStopArrows, default = true, parent = "flightTimerShowStops" },
    { key = "flightTimerShowPost", label = L.flightTimerShowPost, default = true, parent = "flightTimerShowStops" },
    { key = "flightTimerShowTime", label = L.flightTimerShowTime, default = true },
    { key = "flightTimerShowTotal", label = L.showTotalTime, default = false },
    { key = "flightTimerWidth", label = L.flightTimerWidth, default = 300, min = 100, max = 600 },
}
