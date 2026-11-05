local ns = PyresinQoL -- see ns.AddAddonModule in PyresinQoL's Core/Modules.lua
local L = ns.L
local _, class = UnitClass("player")

local COMBO_POINT_CLASSES = { ROGUE = true, DRUID = true }
local pages = { { id = "healthBar", name = L.healthBar }, { id = "powerBar", name = L.powerBar } }
-- Like every class option, the page shows only on the characters it is for.
if COMBO_POINT_CLASSES[class] then pages[#pages + 1] = { id = "comboPointsBar", name = L.comboPointsBar } end
local module = ns.AddAddonModule({ id = "resourceBar", group = "unitFrames", name = L.resourceBar,
    description = L.resourceBarDescription, subMenu = true, pages = pages })
module.comboPointClasses = COMBO_POINT_CLASSES
