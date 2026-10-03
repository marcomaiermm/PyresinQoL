local _, ns = ...

local maps = ns.DungeonMaps

local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function Finite(value)
    value = Plain(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value or nil
end

function maps.FindDungeon(instanceID)
    instanceID = Finite(instanceID)
    if not instanceID then return nil end
    for _, dungeon in ipairs(maps.dungeons or {}) do
        if dungeon.instanceID == instanceID and type(dungeon.floors) == "table" and #dungeon.floors > 0 then
            return dungeon
        end
    end
end

function maps.FindFloor(dungeon, subzone, currentFloor)
    if not dungeon or not dungeon.floors then return nil, nil end
    subzone = Plain(subzone)
    if type(subzone) == "string" and subzone ~= "" then
        local match
        for index, floor in ipairs(dungeon.floors) do
            for _, name in ipairs(floor.subzones or {}) do
                if name == subzone then
                    if match then return currentFloor or 1, dungeon.floors[currentFloor or 1] end
                    match = index
                end
            end
        end
        if match then return match, dungeon.floors[match] end
    end
    if dungeon.requireKnownSubzone then return nil, nil end
    local index = currentFloor and dungeon.floors[currentFloor] and currentFloor or 1
    return index, dungeon.floors[index]
end
