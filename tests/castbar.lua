-- luajit tests/castbar.lua [path/to/pinned/CastingBarFrame.lua]
-- Separate processes keep settings, hooks and frame state isolated between scenarios.
local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end
for _, scenario in ipairs({ "config", "textures", "models", "layout", "ui" }) do
    local command = "luajit tests/castbar/" .. scenario .. ".lua"
    if arg[1] then command = command .. " " .. quote(arg[1]) end
    if os.execute(command) ~= 0 then os.exit(1) end
end
