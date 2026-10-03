local _, ns = ...

ns.DungeonMaps = ns.DungeonMaps or {}

-- Blizzard's Classic clients contain the later Blizzard-drawn dungeon map
-- tiles even though the stock Classic world map does not display them. The
-- native paths and floor ordering below are cross-checked against:
--   https://www.curseforge.com/wow/addons/classicdungeonmaps (MIT, v10.2.7)
--   https://github.com/Babilounet/SimpleDungeonMap (MIT)
-- Legacy UiMap references are from the generic Classic table at:
--   https://warcraft.wiki.gg/wiki/UiMapID/Classic
-- They identify the source art but are not a coordinate calibration for
-- WoW Forever and must not be passed to live map or position APIs.
-- Forever 1.60.1.70205 has no Dungeon rows in UiMap/UiMapXMapArt and does
-- not contain these legacy IDs; the paths below are texture references only.
--
-- Forever 1.60.1.70205 includes verified original-layout texture families for
-- Ragefire Chasm and all four Scholomance floors, so those entries use the
-- client-native assets rather than bundled copies.
-- The verified Blizzard-drawn assets retained here do not match the original
-- multi-level Sunken Temple or Upper Blackrock Spire layouts. Those maps remain
-- gaps; do not substitute a schematic overview or a Lower Blackrock Spire floor.

local function nativeTiles(folder, prefix)
    local result = {}
    for index = 1, 12 do
        result[index] = "Interface\\WorldMap\\" .. folder .. "\\" .. prefix .. index
    end
    return result
end

local function floor(name, textureList, legacyUiMapID, subzones)
    return {
        name = name,
        legacyUiMapID = legacyUiMapID,
        subzones = subzones,
        textures = textureList,
        width = 1002,
        height = 668,
    }
end

ns.DungeonMaps.dungeons = {
    {
        id = "ragefire-chasm",
        name = "Ragefire Chasm",
        instanceID = 389,
        floors = {
            -- The original-layout texture has no published calibration tying
            -- its crop to UiMap 213. Keep it static until that is measured.
            floor("Ragefire Chasm", nativeTiles("Ragefire", "Ragefire1_")),
        },
    },
    {
        id = "wailing-caverns",
        name = "Wailing Caverns",
        instanceID = 43,
        floors = {
            floor("The Wailing Caverns", nativeTiles("WailingCaverns", "WailingCaverns1_"), 279),
        },
    },
    {
        id = "deadmines",
        name = "The Deadmines",
        instanceID = 36,
        floors = {
            floor("The Deadmines", nativeTiles("TheDeadmines", "TheDeadmines1_"), 291, {
                "Goblin Foundry",
            }),
            floor("Ironclad Cove", nativeTiles("TheDeadmines", "TheDeadmines2_"), 292, {
                "Ironclad Cove",
            }),
        },
    },
    {
        id = "shadowfang-keep",
        name = "Shadowfang Keep",
        instanceID = 33,
        floors = {
            floor("The Courtyard", nativeTiles("ShadowfangKeep", "ShadowfangKeep1_"), 310),
            floor("Dining Hall", nativeTiles("ShadowfangKeep", "ShadowfangKeep2_"), 311),
            floor("The Wall Walk", nativeTiles("ShadowfangKeep", "ShadowfangKeep7_"), 316),
            floor("The Vacant Den", nativeTiles("ShadowfangKeep", "ShadowfangKeep3_"), 312),
            floor("Lower Observatory", nativeTiles("ShadowfangKeep", "ShadowfangKeep4_"), 313),
            floor("Upper Observatory", nativeTiles("ShadowfangKeep", "ShadowfangKeep5_"), 314),
            floor("Lord Godfrey's Chamber", nativeTiles("ShadowfangKeep", "ShadowfangKeep6_"), 315),
        },
    },
    {
        id = "blackfathom-deeps",
        name = "Blackfathom Deeps",
        instanceID = 48,
        floors = {
            floor("The Pool of Ask'Ar", nativeTiles("BlackfathomDeeps", "BlackfathomDeeps1_"), 221, {
                "The Drowned Sacellum", "The Pool of Ask'ar",
            }),
            floor("Moonshrine Sanctum", nativeTiles("BlackfathomDeeps", "BlackfathomDeeps2_"), 222, {
                "Moonshrine Ruins", "Moonshrine Sanctum", "Aku'mai's Lair",
            }),
            floor("The Forgotten Pool", nativeTiles("BlackfathomDeeps", "BlackfathomDeeps3_"), 223, {
                "The Forgotten Pool",
            }),
        },
    },
    {
        id = "stockade",
        name = "The Stockade",
        instanceID = 34,
        floors = {
            floor("The Stockade", nativeTiles("TheStockade", "TheStockade1_"), 225),
        },
    },
    {
        id = "gnomeregan",
        name = "Gnomeregan",
        instanceID = 90,
        floors = {
            floor("The Hall of Gears", nativeTiles("Gnomeregan", "Gnomeregan1_"), 226, {
                "The Clockwerk Run", "The Clean Zone",
            }),
            floor("The Dormitory", nativeTiles("Gnomeregan", "Gnomeregan2_"), 227, {
                "The Hall of Gears", "The Dormitory",
            }),
            floor("Launch Bay", nativeTiles("Gnomeregan", "Gnomeregan3_"), 228, {
                "Engineering Labs", "Launch Bay",
            }),
            floor("Tinkers' Court", nativeTiles("Gnomeregan", "Gnomeregan4_"), 229, {
                "Tinkers' Court",
            }),
        },
    },
    {
        id = "razorfen-kraul",
        name = "Razorfen Kraul",
        instanceID = 47,
        floors = {
            floor("Razorfen Kraul", nativeTiles("RazorfenKraul", "RazorfenKraul1_"), 301),
        },
    },
    {
        id = "scarlet-monastery",
        name = "Scarlet Monastery",
        instanceID = 189,
        floors = {
            floor("Graveyard", nativeTiles("ScarletMonastery", "ScarletMonastery1_"), 302, {
                "Chamber of Atonement", "Forlorn Cloister", "Honor's Tomb",
            }),
            floor("Library", nativeTiles("ScarletMonastery", "ScarletMonastery2_"), 303, {
                "Huntsman's Cloister", "Gallery of Treasures", "Athenaeum",
            }),
            floor("Armory", nativeTiles("ScarletMonastery", "ScarletMonastery3_"), 304, {
                "Training Grounds", "Footman's Armory", "Crusader's Armory", "Hall of Champions",
            }),
            floor("Cathedral", nativeTiles("ScarletMonastery", "ScarletMonastery4_"), 305, {
                "Chapel Gardens", "Crusader's Chapel",
            }),
        },
    },
    {
        id = "razorfen-downs",
        name = "Razorfen Downs",
        instanceID = 129,
        floors = {
            floor("Razorfen Downs", nativeTiles("RazorfenDowns", "RazorfenDowns1_"), 300),
        },
    },
    {
        id = "uldaman",
        name = "Uldaman",
        instanceID = 70,
        floors = {
            floor("Hall of the Keepers", nativeTiles("Uldaman", "Uldaman1_"), 230, {
                "Hall of the Keepers", "Dig Two", "Map Chamber", "Echomok Cavern", "Dig Three",
                "Temple Hall", "The Stone Vault", "Hall of the Crafters",
            }),
            floor("Khaz'Goroth's Seat", nativeTiles("Uldaman", "Uldaman2_"), 231, {
                "Khaz'Goroth's Seat",
            }),
        },
    },
    {
        id = "zul-farrak",
        name = "Zul'Farrak",
        instanceID = 209,
        floors = {
            floor("Zul'Farrak", nativeTiles("ZulFarrak", "ZulFarrak"), 219),
        },
    },
    {
        id = "maraudon",
        name = "Maraudon",
        instanceID = 349,
        floors = {
            floor("Caverns of Maraudon", nativeTiles("Maraudon", "Maraudon1_"), 280, {
                "Foulspore Cavern", "The Noxious Hollow", "Poison Falls", "Vyletongue Seat", "The Wicked Grotto",
            }),
            floor("Zaetar's Grave", nativeTiles("Maraudon", "Maraudon2_"), 281, {
                "Earth Song Falls", "Zaetar's Grave",
            }),
        },
    },
    {
        id = "blackrock-depths",
        name = "Blackrock Depths",
        instanceID = 230,
        floors = {
            floor("Detention Block", nativeTiles("BlackrockDepths", "BlackrockDepths1_"), 242, {
                "Detention Block", "Hall of Crafting", "Dark Iron Highway", "Halls of the Law",
            }),
            floor("Shadowforge City", nativeTiles("BlackrockDepths", "BlackrockDepths2_"), 243, {
                "Shadowforge City", "The Domicile", "East Garrison", "Ring of the Law", "The Manufactory",
                "The Grim Guzzler", "The Lyceum", "Mold Foundry", "Summoners' Tomb", "The Imperial Seat",
            }),
        },
    },
    {
        id = "blackrock-spire",
        name = "Lower Blackrock Spire",
        instanceID = 229,
        requireKnownSubzone = true,
        floors = {
            floor("Tazz'Alor", nativeTiles("BlackrockSpire", "BlackrockSpire1_"), 250, {
                "Tazz'Alaor",
            }),
            floor("Skitterweb Tunnels", nativeTiles("BlackrockSpire", "BlackrockSpire2_"), 251, {
                "Skitterweb Tunnels",
            }),
            floor("Hordemar City", nativeTiles("BlackrockSpire", "BlackrockSpire3_"), 252, {
                "Hordemar City",
            }),
            -- Hall of Blackhand is not sufficient to distinguish the two
            -- original wings, so it intentionally does not auto-select.
            floor("Hall of Blackhand", nativeTiles("BlackrockSpire", "BlackrockSpire4_"), 253),
            floor("Halycon's Lair", nativeTiles("BlackrockSpire", "BlackrockSpire5_"), 254, {
                "Halycon's Lair", "The Storehouse",
            }),
            floor("Chamber of Battle", nativeTiles("BlackrockSpire", "BlackrockSpire6_"), 255, {
                "Chamber of Battle",
            }),
        },
    },
    {
        id = "dire-maul",
        name = "Dire Maul",
        instanceID = 429,
        floors = {
            floor("Gordok Commons (North)", nativeTiles("DireMaul", "DireMaul1_"), 235, {
                "Halls of Destruction", "Gordok's Seat",
            }),
            floor("Capital Gardens (West)", nativeTiles("DireMaul", "DireMaul2_"), 236, {
                "Capital Gardens",
            }),
            floor("Court of the Highborne (West)", nativeTiles("DireMaul", "DireMaul3_"), 237),
            floor("Prison of Immol'Thar (West)", nativeTiles("DireMaul", "DireMaul4_"), 238, {
                "Prison of Immol'thar", "The Athenaeum",
            }),
            floor("Warpwood Quarter (East)", nativeTiles("DireMaul", "DireMaul5_"), 239, {
                "Warpwood Quarter", "The Hidden Reach",
            }),
            floor("The Shrine of Eldretharr (East)", nativeTiles("DireMaul", "DireMaul6_"), 240, {
                "The Conservatory",
            }),
        },
    },
    {
        id = "scholomance",
        name = "Scholomance",
        instanceID = 289,
        floors = {
            -- These verified client-native textures match the original layout,
            -- but their crop still has no Forever map-domain calibration.
            -- Keep legacy UiMap references omitted so no player marker is guessed.
            floor("The Reliquary", nativeTiles("ScholomanceOLD", "ScholomanceOLD1_"), nil, {
                "The Reliquary",
            }),
            floor("Chamber of Summoning", nativeTiles("ScholomanceOLD", "ScholomanceOLD2_"), nil, {
                "Chamber of Summoning", "The Great Ossuary", "The Viewing Room",
            }),
            floor("The Great Ossuary and Headmaster's Study", nativeTiles("ScholomanceOLD", "ScholomanceOLD3_"), nil, {
                "Hall of Secrets", "Hall of the Damned", "The Coven",
            }),
            floor("The Laboratory and Vaults", nativeTiles("ScholomanceOLD", "ScholomanceOLD4_"), nil, {
                "The Laboratory", "Vault of the Ravenian", "The Shadow Vault", "Barov Family Vault",
            }),
        },
    },
    {
        id = "stratholme",
        name = "Stratholme",
        instanceID = 329,
        floors = {
            floor("Crusader's Square", nativeTiles("Stratholme", "Stratholme1_"), 317, {
                "Festival Lane", "King's Square", "Market Row", "Crusader's Square", "The Hoard",
                "The Crimson Throne", "The Scarlet Bastion", "The Hall of Lights",
            }),
            floor("The Gauntlet", nativeTiles("Stratholme", "Stratholme2_"), 318, {
                "Elders' Square", "The Gauntlet", "Slaughter Square",
            }),
        },
    },
}
