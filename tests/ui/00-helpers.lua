-- The simulator loads test files alphabetically; helpers stay alive between files.
-- The pinned simulator omits this constant used on native Edit Mode exit.
-- Forever's LossOfControlConstantsDocumentation.lua defines the active index as 1.
if Constants.LossOfControlConsts.LOSS_OF_CONTROL_ACTIVE_INDEX == nil then
    Constants.LossOfControlConsts.LOSS_OF_CONTROL_ACTIVE_INDEX = 1
end

local function SettingsParts()
    local canvas = assert(PyresinQoLSettingsFrame, "Addon settings did not initialize")
    local sidebar, list
    for _, child in ipairs({ canvas:GetChildren() }) do
        if child.Header and child.Header.DefaultsButton then list = child end
        for _, button in ipairs({ child:GetChildren() }) do
            if button.selected and button.text then sidebar = child end
        end
    end
    return canvas, assert(sidebar, "Missing navigation"), assert(list, "Missing settings list")
end

local function PageButton(sidebar, name)
    for _, button in ipairs({ sidebar:GetChildren() }) do
        if button.selected and button.text:GetText() == name then return button end
    end
    error("Missing page: " .. name)
end

local function PhysicalRect(frame)
    local left, bottom, width, height = frame:GetRect()
    assert(left and bottom and width and height and width > 0 and height > 0,
        "Missing or empty layout rectangle")
    local scale = frame:GetEffectiveScale()
    local right, top = (left + width) * scale, (bottom + height) * scale
    left, bottom = left * scale, bottom * scale
    -- GetRect omits the renderer's ScrollFrame translation in the pinned simulator.
    local child, parent = frame, frame:GetParent()
    while parent do
        if parent:IsObjectType("ScrollFrame") and parent:GetScrollChild() == child then
            local x = parent:GetHorizontalScroll() * parent:GetEffectiveScale()
            local y = parent:GetVerticalScroll() * parent:GetEffectiveScale()
            left, right, bottom, top = left - x, right - x, bottom + y, top + y
        end
        child, parent = parent, parent:GetParent()
    end
    return left, bottom, right, top
end

local function AssertInside(frame, parent, name)
    local left, bottom, right, top = PhysicalRect(frame)
    local pLeft, pBottom, pRight, pTop = PhysicalRect(parent)
    assert(left >= pLeft - 1 and bottom >= pBottom - 1 and right <= pRight + 1 and top <= pTop + 1,
        string.format("%s is clipped: (%.1f, %.1f)-(%.1f, %.1f), available (%.1f, %.1f)-(%.1f, %.1f)",
            name, left, bottom, right, top, pLeft, pBottom, pRight, pTop))
end

-- Scope errors to one interaction flow; tick the visible UI between every action.
local function UIFlow(name, steps, restore)
    async_test(name, function(done)
        local canvas, sidebar, list = SettingsParts()
        local driver = CreateFrame("Frame")
        local errors, previousHandler = {}, geterrorhandler()
        seterrorhandler(function(message) errors[#errors + 1] = message end)
        local function Finish(reason)
            driver:SetScript("OnUpdate", nil)
            driver:Hide()
            local ok, cleanupError = pcall(function()
                if restore then restore() end
            end)
            local hidden, hideError = pcall(canvas.Hide, canvas)
            seterrorhandler(previousHandler)
            reason = reason or (not ok and cleanupError) or (not hidden and hideError)
                or (#errors > 0 and table.concat(errors, "\n"))
            done(function() assert(not reason, reason) end)
        end
        local phase = 1
        local function Advance()
            local ok, reason = pcall(function()
                assert(#errors == 0, table.concat(errors, "\n"))
                if phase == 1 then SlashCmdList.PQOL() end
                steps[phase](canvas, sidebar, list)
                assert(#errors == 0, table.concat(errors, "\n"))
            end)
            if not ok then Finish("Step " .. phase .. ": " .. tostring(reason)); return end
            phase = phase + 1
            local ticks = 0
            driver:SetScript("OnUpdate", function()
                ticks = ticks + 1
                if ticks < 2 then return end
                driver:SetScript("OnUpdate", nil)
                C_Timer.After(0, function()
                    if phase > #steps then Finish()
                    else Advance() end
                end)
            end)
        end
        Advance()
    end)
end

PyresinQoLUITest = {
    SettingsParts = SettingsParts,
    PageButton = PageButton,
    PhysicalRect = PhysicalRect,
    AssertInside = AssertInside,
    Flow = UIFlow,
}

test("native secure state snippets compile and execute exactly once", function()
    local handler = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    handler:SetAttribute("_onstate-probe", [[
        self:SetAttribute("runs", (self:GetAttribute("runs") or 0) + 1)
    ]])
    handler:SetAttribute("state-probe", "ready")
    assertEquals(1, handler:GetAttribute("runs"))
end)

test("native scroll templates load their range and offset callbacks", function()
    local scroll = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
    scroll:SetSize(100, 50)
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    content:SetSize(100, 200)
    assertType("function", scroll:GetScript("OnScrollRangeChanged"))
    assertType("function", scroll:GetScript("OnVerticalScroll"))
    local _, maximum = scroll.ScrollBar:GetMinMaxValues()
    assertEquals(150, maximum)
    scroll.ScrollBar:SetValue(20)
    assertEquals(20, scroll:GetVerticalScroll())
    scroll:Hide()
end)
