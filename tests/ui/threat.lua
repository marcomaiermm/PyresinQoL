local UI = PyresinQoLUITest
local mode, originalMode, dropdown, display, previousTarget, previousHealth, previousMaximum
local function ThreatDisplay()
    local native = TargetFrame.threatNumericIndicator
    for _, frame in ipairs({ native:GetParent():GetChildren() }) do
        local regions = { frame:GetRegions() }
        if frame ~= native and #regions == 4 and regions[3]:IsObjectType("FontString")
            and regions[4]:IsObjectType("FontString") then
            return frame
        end
    end
    error("Missing addon target-threat display")
end

UI.Flow("target threat dropdown shows hostile targets and hides them when turned off", {
    function(_, sidebar, list)
        if UnitExists("target") then
            previousTarget = { UnitName("target"), UnitLevel("target"), select(3, UnitClass("target")), UnitCanAttack("player", "target") }
            previousHealth, previousMaximum = UnitHealth("target"), UnitHealthMax("target")
        end
        A_Admin.SetTarget("Threat UI enemy", 80, 1, true)
        A_Admin.SetTargetHealth(100, 100)
        -- Pinned SetTarget changes data only; dispatch the documented game event separately.
        A_Admin.FireEvent("PLAYER_TARGET_CHANGED")
        mode = Settings.GetSetting("PyresinQoL_TargetThreat")
        originalMode = mode:GetValue()
        UI.PageButton(sidebar, "Target Frame"):Click()
        list:ScrollToElementByName(mode:GetName())
    end,
    function(_, _, list)
        dropdown = UI.VisibleSetting(list, mode).Control.Dropdown
        UI.OpenMenu(dropdown)
    end,
    function() UI.SelectMenu(dropdown, "Always") end,
    function()
        display = ThreatDisplay()
        assertTrue(display:IsVisible())
        assertEquals("0", GetCVar("threatShowNumeric"))
        UI.OpenMenu(dropdown)
    end,
    function() UI.SelectMenu(dropdown, "Off") end,
    function() assertFalse(display:IsShown()) end,
}, function()
    if mode then mode:SetValue(originalMode) end
    if previousTarget then
        A_Admin.SetTarget(unpack(previousTarget))
        A_Admin.SetTargetHealth(previousHealth, previousMaximum)
    else A_Admin.ClearTarget() end
    A_Admin.FireEvent("PLAYER_TARGET_CHANGED")
end)
