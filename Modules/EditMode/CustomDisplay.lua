local _, ns = ...

-- Our own displays in Edit Mode (FPS / MS, flight timer), registered in ns.customEditModeDisplays.
-- Defined at file scope: the displays stay movable with the Edit Mode module off, which is also why
-- its pixel-perfect hooks are optional.

-- Makes display a custom Edit Mode display: a Blizzard selection to drag it, the pixel-perfect editor
-- on click, and a position saved in PyresinQoLDB[info.positionKey] as an offset from the screen centre.
-- info: name, positionKey, default (SetPoint arguments without a saved position), and optional
-- IsAvailable (the mover only shows while it is true), OnSelect, OnEnter and OnExit (after the editing state
-- changed), and width = { Get, Set, min, max, Scale } for the editor's Match width: a setting that sizes the
-- display at Scale() UI units per unit. Combat hides the mover; the caller calls the returned entry's Update
-- when IsAvailable changes.

-- Blizzard's snapping on drop, per axis: the screen's sides and centre, its grid lines, and the sides of the
-- other movers in line with this one, within Blizzard's magnetism range. Returns the move in UI units and
-- the x and y it snaps to (nil for an axis that does not snap).
local function SnapOffset(display)
    local function Sides(region)
        local x, y, width, height = region:GetRect()
        if not x then return end
        local scale = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
        return { x * scale, (x + width / 2) * scale, (x + width) * scale },
            { y * scale, (y + height / 2) * scale, (y + height) * scale }
    end
    local own = { Sides(display) }
    if not own[1] then return 0, 0 end
    local range = EditModeMagnetismManager.magnetismRange / UIParent:GetEffectiveScale()
    local best, offset, target = { range, range }, { 0, 0 }, {}
    -- paired: a frame's left side takes our left or right side, its centre only our centre.
    local function Try(axis, lines, paired)
        for i, line in ipairs(lines) do
            for j, side in ipairs(own[axis]) do
                if not paired or i == j or i + j == 4 then
                    local gap = line - side
                    if math.abs(gap) < best[axis] then best[axis], offset[axis], target[axis] = math.abs(gap), gap, line end
                end
            end
        end
    end
    local screen = { Sides(UIParent) }
    Try(1, screen[1]); Try(2, screen[2])
    local grid = EditModeMagnetismManager.magneticGridLines
    for _, x in pairs(grid and grid.vertical or {}) do Try(1, { x }) end
    for _, y in pairs(grid and grid.horizontal or {}) do Try(2, { y }) end
    local function InLine(a, b) return a[1] - range <= b[3] and b[1] - range <= a[3] end
    local function Consider(frame)
        if frame == display or not frame:IsVisible() or not frame.Selection or not frame.Selection:IsShown() then return end
        local x, y = Sides(frame.Selection)
        if not x then return end
        if InLine(own[2], y) then Try(1, x, true) end
        if InLine(own[1], x) then Try(2, y, true) end
    end
    for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do Consider(frame) end
    for _, entry in ipairs(ns.customEditModeDisplays) do Consider(entry.frame) end
    return offset[1], offset[2], target[1], target[2]
end

-- Blizzard's red preview lines while dragging: its own only draw for its systems.
local previewLines
local function ShowPreviewLines(display)
    if not previewLines then
        local container = CreateFrame("Frame", nil, UIParent)
        container:SetAllPoints()
        container:SetFrameStrata("HIGH")
        previewLines = { container:CreateLine(), container:CreateLine() }
        for _, line in ipairs(previewLines) do line:SetColorTexture(1, 0, 0) end
    end
    local _, _, x, y = SnapOffset(display)
    if not EditModeManagerFrame:IsSnapEnabled() then x, y = nil, nil end
    local thickness = 1.5 * PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
    for axis, value in ipairs({ x or false, y or false }) do
        local line = previewLines[axis]
        line:SetShown(value ~= false)
        if value then
            line:SetThickness(thickness)
            if axis == 1 then
                line:SetStartPoint("BOTTOMLEFT", UIParent, value, 0)
                line:SetEndPoint("TOPLEFT", UIParent, value, 0)
            else
                line:SetStartPoint("BOTTOMLEFT", UIParent, 0, value)
                line:SetEndPoint("BOTTOMRIGHT", UIParent, 0, value)
            end
        end
    end
end

function ns.CreateEditModeDisplay(display, info)
    local editMode = ns.GetModule("editMode")
    local mover = CreateFrame("Frame", nil, display, "EditModeSystemSelectionTemplate")
    mover:SetAllPoints(display)
    mover:SetSystem({ GetSystemName = function() return info.name end })
    mover:Hide()
    display.Selection = mover
    local entry = { frame = display, editing = false, width = info.width }
    display.customEditModeEntry = entry
    -- Named like a Blizzard system, so the editor titles both alike.
    function entry:GetSystemName() return info.name end

    local function Active()
        return entry.editing and not InCombatLockdown() and (not info.IsAvailable or info.IsAvailable())
    end

    function entry.Save()
        local x, y = display:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        -- ponytail: One shared position; use per-layout positions if separate layouts are needed.
        PyresinQoLDB[info.positionKey] = { x = x - centerX, y = y - centerY }
        display:ClearAllPoints()
        display:SetPoint("CENTER", UIParent, "CENTER", x - centerX, y - centerY)
    end

    -- Moves it by dx, dy UI units, as the pixel-perfect editor's arrow keys do.
    function entry.Nudge(dx, dy)
        entry.Save()
        local position = PyresinQoLDB[info.positionKey]
        display:ClearAllPoints()
        display:SetPoint("CENTER", UIParent, "CENTER", position.x + dx, position.y + dy)
        entry.Save()
    end

    function entry.StopDragging()
        if not display.isDragging then return end
        display:StopMovingOrSizing()
        display.isDragging = false
        mover:SetScript("OnUpdate", nil)
        if previewLines then for _, line in ipairs(previewLines) do line:Hide() end end
        entry.Save()
    end

    function entry.Restore()
        local position = PyresinQoLDB[info.positionKey]
        display:ClearAllPoints()
        if position then
            display:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
        else
            display:SetPoint(unpack(info.default))
        end
    end

    function entry.Update()
        if Active() then
            if not mover:IsShown() then mover:ShowHighlighted() end
        else
            mover:Hide()
        end
    end

    mover:SetScript("OnMouseDown", function(self)
        if not Active() then return end
        self:ShowSelected()
        if editMode.TogglePixelPerfectFrame then editMode.TogglePixelPerfectFrame(display) end
        if info.OnSelect then info.OnSelect() end
    end)
    mover:SetScript("OnDragStart", function()
        if not Active() then return end
        display.isDragging = true
        display:StartMoving()
        mover:SetScript("OnUpdate", function() ShowPreviewLines(display) end)
        if editMode.OnPixelPerfectDragStart then editMode.OnPixelPerfectDragStart(display) end
    end)
    mover:SetScript("OnDragStop", function()
        if not display.isDragging then return end
        entry.StopDragging()
        if EditModeManagerFrame:IsSnapEnabled() then
            local dx, dy = SnapOffset(display)
            if dx ~= 0 or dy ~= 0 then entry.Nudge(dx, dy) end
        end
    end)
    mover:RegisterEvent("PLAYER_REGEN_DISABLED")
    mover:RegisterEvent("PLAYER_REGEN_ENABLED")
    mover:SetScript("OnEvent", entry.Update)
    mover:SetScript("OnHide", function()
        entry.StopDragging()
        if editMode.ClearPixelPerfectFrame then editMode.ClearPixelPerfectFrame(display) end
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        entry.editing = true
        entry.Update()
        if info.OnEnter then info.OnEnter() end
    end, display)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        entry.editing = false
        mover:Hide()
        if info.OnExit then info.OnExit() end
    end, display)

    table.insert(ns.customEditModeDisplays, entry)
    return entry
end
