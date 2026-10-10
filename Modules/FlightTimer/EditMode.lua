local _, ns = ...
local L = ns.L

-- The flight timer in Edit Mode: a draggable mover like the FPS / MS display, a preview flight, and the
-- options dialog of the selected timer.
ns.RegisterModule("flightTimer", function(module)
    local display, Get = module.flightTimerDisplay, module.GetFlightTimerOption
    local name = "PyresinQoL · " .. L.flightTimer
    local OpenDialog

    local widthOption
    for _, option in ipairs(module.flightTimerOptions) do
        if option.key == "flightTimerWidth" then widthOption = option end
    end
    local entry = ns.CreateEditModeDisplay(display, {
        name = name, positionKey = "flightTimerPosition", default = { "CENTER", UIParent, "CENTER", 0, 250 },
        OnSelect = function() OpenDialog() end,
        width = { Get = function() return Get(widthOption.key) end, min = widthOption.min, max = widthOption.max,
            Set = function(value) widthOption.setting:SetValue(value); if display.Dialog then display.Dialog:Refresh() end end,
            Scale = function() return Get("flightTimerScale") / 100 end },
        OnEnter = function() module.SetFlightTimerPreview(true) end,
        OnExit = function() module.SetFlightTimerPreview(false) end,
    })
    OpenDialog = ns.CreateEditModeOptionsDialog(display, {
        name = name, options = module.flightTimerOptions, Get = Get, Format = module.FormatFlightTimerOption,
        IsEnabled = function(option) return module.FlightTimerOptionEnabled(option, Get) end,
    })
    entry.Restore()
end)
