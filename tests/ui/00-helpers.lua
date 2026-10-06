-- The simulator loads test files alphabetically; helpers stay alive between files.
-- The pinned simulator omits this constant used on native Edit Mode exit.
-- Forever's LossOfControlConstantsDocumentation.lua defines the active index as 1.
if Constants.LossOfControlConsts.LOSS_OF_CONTROL_ACTIVE_INDEX == nil then
    Constants.LossOfControlConsts.LOSS_OF_CONTROL_ACTIVE_INDEX = 1
end
-- Edit Mode shows the native archaeology bar; its half-second poll uses this
-- omitted game-state API. This fixture places the player outside a digsite.
if CanScanResearchSite == nil then
    function CanScanResearchSite() return false end
end

-- The pinned simulator omits the loot-effect CVar. Seed it only for UI scenarios;
-- production must skip unavailable CVars, as covered by the Lua integration suite.
if C_CVar.GetCVar("outlineModeShowLootEffectWhenDisabled") == nil then
    C_CVar.SetCVar("outlineModeShowLootEffectWhenDisabled", "0")
    Settings.GetSetting("PyresinQoL_QuestItemSparkles"):NotifyUpdate()
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
        local finishing = false
        local function AfterTicks(callback)
            local ticks = 0
            driver:SetScript("OnUpdate", function()
                ticks = ticks + 1
                if ticks < 2 then return end
                driver:SetScript("OnUpdate", nil)
                C_Timer.After(0, callback)
            end)
        end
        local function Finish(reason)
            if finishing then return end
            finishing = true
            driver:SetScript("OnUpdate", nil)
            if reason then errors[#errors + 1] = reason end
            local ok, cleanupError = pcall(function()
                if restore then restore() end
            end)
            if not ok then errors[#errors + 1] = cleanupError end
            local hidden, hideError = pcall(canvas.Hide, canvas)
            if not hidden then errors[#errors + 1] = hideError end
            -- Cleanup can schedule native callbacks too. Keep the scoped handler
            -- installed until those callbacks have had the same two-tick window.
            AfterTicks(function()
                driver:Hide()
                seterrorhandler(previousHandler)
                done(function() assert(#errors == 0, table.concat(errors, "\n")) end)
            end)
        end
        local phase = 1
        local function Advance()
            if finishing then return end
            local ok, reason = pcall(function()
                assert(#errors == 0, table.concat(errors, "\n"))
                if phase == 1 then SlashCmdList.PQOL() end
                steps[phase](canvas, sidebar, list)
                assert(#errors == 0, table.concat(errors, "\n"))
            end)
            if not ok then Finish("Step " .. phase .. ": " .. tostring(reason)); return end
            phase = phase + 1
            AfterTicks(function()
                if phase > #steps then Finish()
                else Advance() end
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

local UI = PyresinQoLUITest
function UI.Find(frame, predicate)
    if predicate(frame) then return frame end
    for _, child in ipairs({ frame:GetChildren() }) do
        local found = UI.Find(child, predicate)
        if found then return found end
    end
end

function UI.Button(frame, text)
    return assert(UI.Find(frame, function(child)
        return child:IsVisible() and child:IsObjectType("Button") and child.GetText and child:GetText() == text
    end), "Missing visible button: " .. text)
end

function UI.Checkbox(frame, text)
    local row = assert(UI.Find(frame, function(child)
        return child:IsVisible() and child.Label and child.Button and child.Label:GetText() == text
    end), "Missing visible checkbox: " .. text)
    return row.Button, row
end

function UI.Click(control, bounds, name)
    assertTrue(control:IsVisible())
    assertTrue(control:IsEnabled())
    assertTrue(control:IsMouseEnabled())
    AssertInside(control:IsObjectType("CheckButton") and control:GetParent() or control,
        bounds or UIParent, name or "Control")
    control:Click()
end

function UI.ScrollTo(scroll, control)
    local content = scroll:GetScrollChild()
    local offset = content:GetTop() - control:GetTop()
    -- The pinned simulator omits anchor-derived viewport sizes in its range query.
    local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
    scroll.ScrollBar:SetValue(math.max(0, math.min(offset, maximum)))
end

function UI.VisibleSetting(list, setting)
    for _, row in list.ScrollBox:EnumerateFrames() do
        if row.GetSetting and row:GetSetting() == setting then
            assertTrue(row:IsVisible())
            AssertInside(row, list.ScrollBox, "Setting row: " .. setting:GetName())
            return row
        end
    end
    error("No rendered setting: " .. setting:GetVariable())
end

function UI.OpenMenu(dropdown)
    assertTrue(dropdown:IsVisible())
    assertTrue(dropdown:IsEnabled())
    AssertInside(dropdown, UIParent, "Dropdown")
    -- The simulator's Click does not dispatch DropdownButton's intrinsic mouse-down.
    -- Open its native menu, then select an actual rendered option below.
    dropdown:OpenMenu()
    assertTrue(dropdown:IsMenuOpen())
end

function UI.MenuItem(dropdown, text)
    assertTrue(dropdown:IsMenuOpen())
    local menu = assert(dropdown.menu)
    assertEquals(dropdown, menu:GetOwnerRegion())
    return assert(UI.Find(menu, function(frame)
        local label = frame.fontString or frame.Text
        return frame:IsVisible() and frame.GetElementDescription and label and label.GetText
            and (not text or label:GetText() == text)
    end), "Missing rendered menu option: " .. (text or "first option"))
end

function UI.SelectMenu(dropdown, text)
    local item = UI.MenuItem(dropdown, text)
    UI.Click(item, UIParent, "Menu option: " .. text)
end

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
    -- This fixed-pixel template characterization is independent of the scenario's UI scale.
    scroll:SetScale(1 / UIParent:GetEffectiveScale())
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
