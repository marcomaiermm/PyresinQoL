local _, ns = ...

-- Our own displays in Edit Mode (FPS / MS, flight timer), registered in ns.customEditModeDisplays.
-- Defined at file scope: the displays stay movable with the Edit Mode module off, which is also why
-- its pixel-perfect hooks are optional.

-- Makes display a custom Edit Mode display: a Blizzard selection to drag it, the pixel-perfect editor
-- on click, and a position saved in PyresinQoLDB[info.positionKey] as an offset from the screen centre.
-- info: name, positionKey, default (SetPoint arguments without a saved position), and optional
-- IsAvailable (the mover only shows while it is true), OnSelect, OnEnter and OnExit (after the editing state
-- changed). Combat hides the mover; the caller calls the returned entry's Update when IsAvailable changes.
function ns.CreateEditModeDisplay(display, info)
    local editMode = ns.GetModule("editMode")
    local mover = CreateFrame("Frame", nil, display, "EditModeSystemSelectionTemplate")
    mover:SetAllPoints(display)
    mover:SetSystem({ GetSystemName = function() return info.name end })
    mover:Hide()
    display.Selection = mover
    local entry = { frame = display, editing = false }
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
        if editMode.OnPixelPerfectDragStart then editMode.OnPixelPerfectDragStart(display) end
    end)
    mover:SetScript("OnDragStop", entry.StopDragging)
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
