local ns = PyresinQoL
local module = ns.GetModule("resourceBar")
local Get = module.GetResourceBarOption

-- Each bar in Edit Mode: a draggable mover like the flight timer's, and a dialog with all its options.
ns.RegisterModule("resourceBar", function()
    for _, bar in ipairs(module.resourceBars) do
        local view = module.resourceBarViews[bar.id]
        local display = view.frame
        local name = "PyresinQoL · " .. bar.name
        local width
        for _, option in ipairs(bar.options) do
            if option.key == bar.id .. "Width" then width = option end
        end
        local OpenDialog
        local entry = ns.CreateEditModeDisplay(display, {
            name = name, positionKey = bar.id .. "Position", default = { "CENTER", UIParent, "CENTER", 0, bar.y },
            IsAvailable = view.IsAvailable,
            OnSelect = function() OpenDialog() end,
            width = { Get = function() return Get(width.key) end, min = width.min, max = width.max,
                Set = function(value) width.setting:SetValue(value); if display.Dialog then display.Dialog:Refresh() end end,
                Scale = function() return 1 end },
            OnEnter = function() module.SetResourceBarPreview(true) end,
            OnExit = function() module.SetResourceBarPreview(false) end,
        })
        OpenDialog = ns.CreateEditModeOptionsDialog(display, {
            name = name, options = bar.playerOptions, Get = Get, Format = module.FormatResourceBarOption,
            IsEnabled = function(option) return ns.IsOptionEnabled(option, Get) end,
        })
        entry.Restore()
        EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", entry.Restore, entry)
    end
end)
