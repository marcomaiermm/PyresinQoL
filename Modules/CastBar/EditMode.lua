local _, ns = ...
local L, cast = ns.L, ns.CastBar
local dialog, active

local function Install()
    if dialog or not EditModeSystemSettingsDialog then return end
    dialog = EditModeSystemSettingsDialog
    cast.InstallPositionHooks()
    local panel = CreateFrame("Frame", nil, dialog)
    panel:SetSize(343, 380)
    panel:Hide()
    local enable = CreateFrame("Frame", nil, panel, "EditModeSettingCheckboxTemplate")
    enable:SetPoint("TOPLEFT", 0, -4)
    enable:Show()
    enable.Label:SetText(L.castBarEnable)
    enable.OnCheckButtonClick = function() cast.SetEnabled(not cast.IsEnabled()) end

    local previewArea = CreateFrame("Frame", nil, panel)
    previewArea:SetPoint("TOPLEFT", 0, -34)
    previewArea:SetHeight(46)
    local preview = cast.CreatePreview(previewArea)
    preview:SetPoint("CENTER", previewArea, "CENTER", 0, 2)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    local contentTop, footerHeight = 122, 56
    scroll:SetPoint("TOPLEFT", 0, -contentTop)
    scroll:SetPoint("BOTTOMRIGHT", -24, footerHeight)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(panel:GetWidth() - 24)
    scroll:SetScrollChild(content)
    local rows, tabs, section, selected = {}, {}, "style", "style"
    local changingSlider
    local function ChoiceButton(parent, label)
        local button = CreateFrame("Button", nil, parent)
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(.04, .035, .025, .8)
        button.selected = button:CreateTexture(nil, "BORDER")
        button.selected:SetAllPoints()
        button.selected:SetAtlas("Options_List_Active")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER")
        text:SetWordWrap(false)
        button:SetFontString(text)
        button:SetText(label)
        function button:SetSelected(value)
            self.selected:SetShown(value)
            text:SetTextColor(1, value and .82 or .95, value and 0 or .9)
        end
        return button
    end
    local function Row(template, height, visible)
        local row = CreateFrame("Frame", nil, content, template)
        row.fixedWidth = content:GetWidth()
        row:SetSize(content:GetWidth(), height)
        rows[#rows + 1] = { frame = row, height = height, section = section, visible = visible }
        return row
    end
    local function Label(row, label)
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 0, -2)
        text:SetJustifyH("LEFT")
        text:SetText(label)
        return text
    end
    local function Checkbox(key, label, visible)
        local row = Row("EditModeSettingCheckboxTemplate", 34, visible)
        row.Label:SetFontObject("GameFontHighlight")
        row.Label:SetWidth(320)
        row.Label:SetText(label)
        row.OnCheckButtonClick = function() cast.Set(key, not cast.Get(key)) end
        row.Refresh = function() row.Button:SetChecked(cast.Get(key)) end
    end
    local function Dropdown(key, label, options, visible)
        local row = Row(nil, key == "texture" and 86 or 56, visible)
        Label(row, label)
        row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        row.Dropdown:SetPoint("TOPLEFT", 0, -22)
        row.Dropdown:SetWidth(content:GetWidth())
        if key == "texture" then
            row.Dropdown:SetHeight(56)
            -- The native one-line atlas distorts when stretched around two rows.
            row.Dropdown.Background:Hide()
            local border = row.Dropdown:CreateTexture(nil, "BACKGROUND", nil, -1)
            border:SetAllPoints()
            border:SetColorTexture(.34, .29, .20)
            local background = row.Dropdown:CreateTexture(nil, "BACKGROUND")
            background:SetPoint("TOPLEFT", 1, -1)
            background:SetPoint("BOTTOMRIGHT", -1, 1)
            background:SetColorTexture(.04, .035, .025)
            if row.Dropdown.Arrow then
                row.Dropdown.Arrow:ClearAllPoints()
                row.Dropdown.Arrow:SetPoint("TOPRIGHT", -5, -4)
            end
            row.Dropdown.Text:ClearAllPoints()
            row.Dropdown.Text:SetPoint("TOPLEFT", 10, -8)
            row.Dropdown.Text:SetPoint("TOPRIGHT", -34, -8)
            row.Dropdown.Text:SetHeight(14)
            row.Dropdown.Text:SetJustifyH("LEFT")
            row.preview = row.Dropdown:CreateTexture(nil, "ARTWORK")
            row.preview:SetPoint("TOPLEFT", 10, -30)
            row.preview:SetHeight(16)
        end
        row.control = row.Dropdown
        row.Dropdown:SetupMenu(function(_, root)
            if key == "texture" then root:SetScrollMode(420) end
            for _, option in ipairs(type(options) == "function" and options() or options) do
                local radio = root:CreateRadio(option[2], function(value) return cast.Get(key) == value end,
                    function(value) cast.Set(key, value) end, option[1])
                if key == "texture" then
                    radio:AddInitializer(function(button)
                        local preview = button:AttachTexture()
                        preview:SetSize(156, 18)
                        preview:SetPoint("RIGHT", -8, 0)
                        local descriptor = cast.GetTexture(option[1])
                        cast.PaintTexture(preview, descriptor)
                        cast.ApplyModelPreview(button, preview, descriptor)
                        button.fontString:SetWidth(226)
                        return 428, 30
                    end)
                    radio:AddResetter(function(button)
                        if button.pyresinCastModelPreview then button.pyresinCastModelPreview:Hide() end
                    end)
                end
            end
        end)
        row.Refresh = function()
            row.Dropdown:GenerateMenu()
            if row.preview then
                local descriptor = cast.GetTexture(cast.Get("texture"))
                row.preview:SetWidth(row.Dropdown:GetWidth() - 20)
                cast.PaintTexture(row.preview, descriptor)
                cast.ApplyModelPreview(row.Dropdown, row.preview, descriptor)
            end
        end
    end
    local function Choices(key, label, options, columns)
        local row = Row(nil, 24 + math.ceil(#options / columns) * 56)
        Label(row, label)
        row.buttons = {}
        for i, option in ipairs(options) do
            local value, name = option[1], option[2]
            local button = ChoiceButton(row, name)
            local text = button:GetFontString()
            text:ClearAllPoints()
            text:SetPoint("BOTTOM", button, "BOTTOM", 0, 6)
            local sample = cast.CreatePreview(button)
            sample:SetPoint("TOP", button, "TOP", 0, -9)
            local function get(setting)
                if setting == key then return value end
                if setting == "width" then return math.max(30, button:GetWidth() - 16) end
                if setting == "height" then return 14 end
                if key == "borderStyle" then
                    if setting == "icon" then return "off" end
                    if setting == "texture" then return "default" end
                    if setting == "colorMode" then return "original" end
                end
                return cast.Get(setting)
            end
            button:SetScript("OnClick", function() cast.Set(key, value) end)
            row.buttons[i] = { button = button, sample = sample, get = get, value = value }
        end
        row.Refresh = function()
            local width = (content:GetWidth() - 6 * (columns - 1)) / columns
            for i, item in ipairs(row.buttons) do
                local button = item.button
                button:SetSize(width, 50)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", ((i - 1) % columns) * (width + 6), -24 - math.floor((i - 1) / columns) * 56)
                button:GetFontString():SetWidth(width - 4)
                button:SetSelected(cast.Get(key) == item.value)
                cast.UpdatePreview(item.sample, item.get, width - 8, true)
            end
        end
    end
    local function Slider(key, label, max, encode, decode, format, visible)
        local row = Row(nil, 56, visible)
        Label(row, label)
        local valueLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        valueLabel:SetPoint("TOPRIGHT", 0, -2)
        local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
        slider:SetPoint("TOPLEFT", 0, -22)
        slider:SetSize(content:GetWidth(), 32)
        row.control = slider
        slider:Init(decode(cast.Get(key)), 0, max, max)
        row.handles = EventUtil.CreateCallbackHandleContainer()
        row.handles:RegisterCallback(slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if row.initializing then return end
            value = math.floor(value + .5)
            -- Relayout during a drag changes the thumb's coordinate space.
            changingSlider = true
            cast.Set(key, encode(value))
            changingSlider = nil
            cast.UpdatePreview(preview, nil, panel:GetWidth())
            valueLabel:SetText(format(value))
        end, row)
        row.Refresh = function()
            local value = decode(cast.Get(key))
            valueLabel:SetText(format(value))
            if slider.Slider:IsDraggingThumb() then return end
            row.initializing = true
            slider:SetValue(value)
            row.initializing = false
        end
    end
    local function Color(key, visible)
        local row = Row(nil, 38, visible)
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(160, 26)
        button:SetPoint("LEFT", 28, 0)
        button:SetText(L.castBarPickColor)
        local swatch = CreateFrame("Frame", nil, row, "ColorSwatchTemplate")
        swatch:SetPoint("LEFT", 0, 0)
        row.Refresh = function()
            local color = cast.Get(key)
            swatch:SetColorRGB(color.r, color.g, color.b)
        end
        button:SetScript("OnClick", function()
            local previous = cast.Get(key)
            ColorPickerFrame:SetupColorPickerAndShow({
                r = previous.r, g = previous.g, b = previous.b, hasOpacity = false,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    cast.Set(key, { r = r, g = g, b = b })
                end,
                cancelFunc = function() cast.Set(key, previous) end,
            })
        end)
    end
    local function NativeSlider(key, label, first, last)
        Slider(key, label, last - first + 1,
            function(value) return value == 0 and 0 or value + first - 1 end,
            function(value) return value == 0 and 0 or value - first + 1 end,
            function(value) return value == 0 and L.castBarAutomatic or ("%d px"):format(value + first - 1) end)
    end
    Dropdown("texture", L.castBarTexture, function()
        local options = {}
        for _, texture in ipairs(cast.GetTextures()) do options[#options + 1] = { texture.id, texture.name } end
        return options
    end)
    local animated = Row("EditModeSettingCheckboxTemplate", 34)
    animated.Label:SetText(L.castBarAnimated)
    animated.OnCheckButtonClick = function()
        if cast.GetTexture(cast.Get("texture")).flipBookRows then
            cast.Set("animated", not cast.Get("animated"))
        end
    end
    animated.Refresh = function()
        local texture = cast.GetTexture(cast.Get("texture"))
        local enabled = texture.flipBookRows ~= nil
        animated.Button:SetEnabled(enabled)
        animated.Label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
        animated.Button:SetChecked(texture.models ~= nil or (enabled and cast.Get("animated")))
    end
    Dropdown("colorMode", L.castBarColorMode, {
        { "original", L.castBarOriginal }, { "class", L.castBarClassColor }, { "custom", L.castBarCustomColor },
    })
    Color("customColor", function() return cast.Get("colorMode") == "custom" end)
    Choices("borderStyle", L.castBarBorderStyle, {
        { "native", L.castBarBorderBlizzard }, { "thin", L.castBarBorderThin },
        { "inset", L.castBarBorderInset }, { "none", L.castBarBorderNone },
    }, 4)
    local function hasBorder() return cast.Get("borderStyle") ~= "none" end
    Dropdown("borderColorMode", L.castBarBorderColor, {
        { "original", L.castBarOriginal }, { "class", L.castBarClassColor }, { "custom", L.castBarCustomColor },
    }, hasBorder)
    Color("borderColor", function() return hasBorder() and cast.Get("borderColorMode") == "custom" end)
    Slider("borderOpacity", L.castBarBorderOpacity, 20,
        function(value) return value / 20 end,
        function(value) return math.floor(value * 20 + .5) end,
        function(value) return ("%d%%"):format(value * 5) end, hasBorder)
    Slider("borderSize", L.castBarBorderSize, 2,
        function(value) return value + 1 end, function(value) return value - 1 end,
        function(value) return ("%d px"):format(value + 1) end,
        function() return cast.Get("borderStyle") == "thin" end)
    Checkbox("showSpark", L.castBarSpark)
    Slider("backgroundOpacity", L.castBarBackgroundOpacity, 21,
        function(value) return value == 0 and -1 or (value - 1) / 20 end,
        function(value) return value == -1 and 0 or math.floor(value * 20 + 1.5) end,
        function(value) return value == 0 and L.castBarAutomatic or ("%d%%"):format((value - 1) * 5) end)

    section = "layout"
    Dropdown("layout", L.castBarLayout, { { "native", L.castBarNative }, { "compact", L.castBarCompact } })
    NativeSlider("width", L.castBarWidth, 100, 600)
    NativeSlider("height", L.castBarHeight, 6, 48)
    Choices("icon", L.castBarIcon, {
        { "native", L.castBarAutomatic }, { "off", L.castBarOff },
        { "left", L.castBarIconOutsideLeft }, { "right", L.castBarIconOutsideRight },
        { "inside_left", L.castBarIconInsideLeft }, { "inside_right", L.castBarIconInsideRight },
    }, 3)
    Slider("iconGap", L.castBarIconGap, 12,
        function(value) return value end, function(value) return value end,
        function(value) return ("%d px"):format(value) end,
        function()
            local icon = cast.GetLayout().icon
            return icon == "left" or icon == "right"
        end)

    section = "details"
    NativeSlider("fontSize", L.castBarFontSize, 8, 24)
    local textTarget = "name"
    local textPicker = Row(nil, 34)
    local textButtons = {}
    for i, info in ipairs({ { "name", L.castBarNameText }, { "time", L.castBarTimeText } }) do
        local button = ChoiceButton(textPicker, info[2])
        button:SetHeight(26)
        button:SetScript("OnClick", function()
            textTarget = info[1]
            cast.RefreshControls()
        end)
        textButtons[i] = { button = button, target = info[1] }
    end
    textPicker.Refresh = function()
        local width = (content:GetWidth() - 6) / 2
        for i, item in ipairs(textButtons) do
            item.button:SetWidth(width)
            item.button:SetPoint("TOPLEFT", (i - 1) * (width + 6), 0)
            item.button:SetSelected(textTarget == item.target)
        end
    end
    local function showTime() return not cast.frame or cast.frame.showCastTimeSetting end
    Checkbox("showSpellName", L.castBarSpellName, function() return textTarget == "name" end)
    for _, prefix in ipairs({ "name", "time" }) do
        local function visible()
            return textTarget == prefix and (prefix == "name" and cast.Get("showSpellName") or prefix == "time" and showTime())
        end
        local positions = {
            { "native", L.castBarAutomatic }, { "inside", L.castBarTextInside },
            { "above", L.castBarTextAbove }, { "below", L.castBarTextBelow },
        }
        if prefix == "time" then
            positions[#positions + 1] = { "left", L.castBarIconOutsideLeft }
            positions[#positions + 1] = { "right", L.castBarIconOutsideRight }
        end
        Dropdown(prefix .. "Position", L.castBarTextPosition, positions, visible)
        Dropdown(prefix .. "Alignment", L.castBarTextAlignment, {
            { "native", L.castBarAutomatic }, { "left", L.castBarTextLeft },
            { "center", L.castBarTextCenter }, { "right", L.castBarTextRight },
        }, visible)
        Slider(prefix .. "Spacing", L.castBarTextSpacing, 25,
            function(value) return value - 1 end, function(value) return value + 1 end,
            function(value) return value == 0 and L.castBarAutomatic or ("%d px"):format(value - 1) end, visible)
    end
    Dropdown("timeFormat", L.castBarTimeFormat, {
        { "native", L.castBarNative }, { "remaining", L.castBarRemaining }, { "remainingTotal", L.castBarRemainingTotal },
    }, function() return textTarget == "time" and showTime() end)
    local timeHint = Row(nil, 44, function() return textTarget == "time" and not showTime() end)
    local hintText = Label(timeHint, L.castBarTimeHidden)
    timeHint.Refresh = function() hintText:SetWidth(content:GetWidth()) end
    Checkbox("customInterruptTexture", L.castBarCustomInterruptTexture,
        function()
            local texture = cast.GetTexture(cast.Get("texture"))
            return texture.id ~= "default" and not texture.models
        end)
    Dropdown("uninterruptible", L.castBarUninterruptible, {
        { "blizzard", L.castBarNative }, { "custom", L.castBarCustomColor },
    })
    Color("uninterruptibleColor", function() return cast.Get("uninterruptible") == "custom" end)
    Checkbox("showLatency", L.castBarLatency)
    Slider("latencyOpacity", L.castBarLatencyOpacity, 20,
        function(value) return value / 20 end,
        function(value) return math.floor(value * 20 + 0.5) end,
        function(value) return ("%d%%"):format(value * 5) end,
        function() return cast.Get("showLatency") end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetHeight(26)
    reset:SetPoint("BOTTOMLEFT", 0, 28)
    reset:SetPoint("BOTTOMRIGHT", 0, 28)
    reset:SetText(L.castBarReset)
    reset:SetScript("OnClick", cast.Reset)
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 0, 10)
    hint:SetText(L.castBarSavedImmediately)

    function cast.RefreshControls()
        if changingSlider then return end
        local width = dialog.Settings:GetWidth()
        if width <= 24 then width = 343 end -- Native Settings starts at 1px before selection.
        panel:SetWidth(width)
        content:SetWidth(width - 24)
        enable.fixedWidth = width
        enable.Label:SetWidth(width - 32)
        enable.Button:SetChecked(cast.IsEnabled())
        local enabled, y = cast.IsEnabled(), 0
        previewArea:SetWidth(width)
        previewArea:SetShown(enabled)
        if enabled then cast.UpdatePreview(preview, nil, width) end
        local tabWidth = (width - 10) / 3
        for i, tab in ipairs(tabs) do
            tab:SetWidth(tabWidth)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", (i - 1) * (tabWidth + 5), -88)
            tab:SetShown(enabled)
            tab:SetSelected(tab.section == selected)
        end
        scroll:SetShown(enabled)
        reset:SetShown(enabled)
        hint:SetShown(enabled)
        for _, entry in ipairs(rows) do
            local show = enabled and entry.section == selected and (not entry.visible or entry.visible())
            entry.frame:SetShown(show)
            if show then
                entry.frame.fixedWidth = content:GetWidth()
                entry.frame:SetWidth(content:GetWidth())
                if entry.frame.control then entry.frame.control:SetWidth(content:GetWidth()) end
                if entry.frame.Label then entry.frame.Label:SetWidth(content:GetWidth() - 32) end
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", 0, -y)
                entry.frame.Refresh()
                y = y + entry.height
            end
        end
        content:SetHeight(math.max(1, y))
        local overhead = contentTop + footerHeight
        local available = UIParent:GetHeight() * .85 - dialog.Settings:GetHeight() - dialog.Buttons:GetHeight() - overhead - 80
        panel:SetHeight(enabled and (math.min(y, math.max(150, math.min(320, available))) + overhead) or 40)
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, y - scroll:GetHeight())))
        if panel:IsShown() then dialog:Layout() end
    end
    for _, info in ipairs({ { "style", L.castBarStyle }, { "layout", L.castBarLayout }, { "details", L.castBarDetails } }) do
        local tab = ChoiceButton(panel, info[2])
        tab:SetHeight(26)
        tab.section = info[1]
        tab:SetScript("OnClick", function()
            selected = info[1]
            scroll:SetVerticalScroll(0)
            cast.RefreshControls()
        end)
        tabs[#tabs + 1] = tab
    end
    hooksecurefunc(dialog, "UpdateDialog", function(self, frame)
        if frame ~= self.attachedToSystem then return end
        if frame ~= (cast.frame or PlayerCastingBarFrame) then
            if panel:IsShown() then panel:Hide(); self:Layout() end
            return
        end
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self.Settings, "BOTTOMLEFT", 0, -12)
        self.Buttons:ClearAllPoints()
        self.Buttons:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -12)
        panel:Show()
        cast.RefreshControls()
    end)
end

function cast.Configure()
    if not active then return end
    if InCombatLockdown() then print(L.combat); return end
    if not EditModeManagerFrame then C_AddOns.LoadAddOn("Blizzard_EditMode") end
    Install()
    if not EditModeManagerFrame or not PlayerCastingBarFrame then return end
    if PyresinQoLSettingsFrame and PyresinQoLSettingsFrame:IsShown() then PyresinQoLSettingsFrame:Hide() end
    ShowUIPanel(EditModeManagerFrame)
    if EditModeManagerFrame:IsShown() then EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame) end
end

ns.RegisterModule("unitFrames", function()
    active = true
    if EditModeSystemSettingsDialog then Install(); return end
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, addon)
        if addon == "Blizzard_EditMode" then self:UnregisterEvent("ADDON_LOADED"); Install() end
    end)
end)
