-- Run from the addon directory: luajit tests/unit/dungeonmaps/logic.lua
local secret = {}
function issecretvalue(value) return value == secret end

local ns = { DungeonMaps = { dungeons = {
    { id = "example", name = "Example dungeon", instanceID = 10, floors = {
        { name = "One", legacyUiMapID = 101, subzones = { "Left room" } },
        { name = "Two", worldBounds = { left = 100, right = 200, top = 300, bottom = 500, mapID = 77 } },
    } },
} } }
assert(loadfile("Modules/DungeonMaps/Logic.lua"))("PyresinQoL", ns)
local maps = ns.DungeonMaps

local dungeon = maps.FindDungeon(10)
assert(dungeon and dungeon.id == "example")
assert(maps.FindDungeon(secret) == nil)
assert(maps.FindDungeon(0 / 0) == nil)
assert(maps.FindDungeon(11) == nil)

local index, floor = maps.FindFloor(dungeon, "Left room", 2)
assert(index == 1 and floor == dungeon.floors[1])
index, floor = maps.FindFloor(dungeon, "Unknown", 2)
assert(index == 2 and floor == dungeon.floors[2])
local catalog = { DungeonMaps = {} }
assert(loadfile("Modules/DungeonMaps/Data.lua"))("PyresinQoL", catalog)
assert(loadfile("Modules/DungeonMaps/Logic.lua"))("PyresinQoL", catalog)
local deadmines = assert(catalog.DungeonMaps.FindDungeon(36))
local ironclad = assert(catalog.DungeonMaps.FindFloor(deadmines, "Ironclad Cove"))
assert(ironclad == 2 and deadmines.floors[ironclad].name == "Ironclad Cove")
local expectedInstances = {
    [33] = true, [34] = true, [36] = true, [43] = true, [47] = true,
    [48] = true, [70] = true, [90] = true, [129] = true,
    [189] = true, [209] = true, [229] = true, [230] = true, [289] = true,
    [329] = true, [349] = true, [389] = true, [429] = true,
}
local seenInstances = {}
assert(catalog.DungeonMaps.FindDungeon(109) == nil)
local lowerSpire = assert(catalog.DungeonMaps.FindDungeon(229))
assert(lowerSpire.name == "Lower Blackrock Spire")
assert(catalog.DungeonMaps.FindFloor(lowerSpire, "Hordemar City") == 3)
assert(catalog.DungeonMaps.FindFloor(lowerSpire, "The Rookery") == nil)
assert(catalog.DungeonMaps.FindFloor(lowerSpire, "Hall of Blackhand") == nil)
assert(catalog.DungeonMaps.FindFloor(lowerSpire, "Unknown shared area") == nil)
local floorCount = 0
for _, dungeonEntry in ipairs(catalog.DungeonMaps.dungeons) do
    assert(type(dungeonEntry.id) == "string" and type(dungeonEntry.instanceID) == "number")
    assert(expectedInstances[dungeonEntry.instanceID] and not seenInstances[dungeonEntry.instanceID])
    seenInstances[dungeonEntry.instanceID] = true
    for _, floorEntry in ipairs(dungeonEntry.floors) do
        floorCount = floorCount + 1
        assert(floorEntry.textures and #floorEntry.textures == 12)
        assert(floorEntry.uiMapID == nil)
        assert(floorEntry.legacyUiMapID == nil or type(floorEntry.legacyUiMapID) == "number")
    end
end
assert(#catalog.DungeonMaps.dungeons == 18 and floorCount == 50)
for instanceID in pairs(expectedInstances) do assert(seenInstances[instanceID]) end

print("PASS: single-instance dungeon lookup and floor selection without unverified coordinate projection")
