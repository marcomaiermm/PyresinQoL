local _, ns = ...
local L = ns.L

function ns.InitializeSettings()
    local launcher = CreateFrame("Frame")
    launcher:Hide()
    local category = Settings.RegisterCanvasLayoutCategory(launcher, "PyresinQoL")
    Settings.RegisterAddOnCategory(category)

    -- The same native window frame used by DragonflightUI, without an addon dependency.
    local canvas = CreateFrame("Frame", "PyresinQoLSettingsFrame", UIParent, "SettingsFrameTemplate")
    canvas:Hide()
    canvas:SetSize(960, 720)
    canvas:SetPoint("CENTER")
    canvas:SetFrameStrata("DIALOG")
    canvas:SetToplevel(true)
    canvas:SetMovable(true)
    canvas:SetClampedToScreen(true)
    canvas:EnableMouse(true)
    canvas.NineSlice.Text:SetText("PyresinQoL")
    canvas.ClosePanelButton:SetScript("OnClick", function() canvas:Hide() end)
    table.insert(UISpecialFrames, "PyresinQoLSettingsFrame")
    local drag = CreateFrame("Frame", nil, canvas)
    drag:SetPoint("TOPLEFT", 8, -4)
    drag:SetPoint("TOPRIGHT", -36, -4)
    drag:SetHeight(26)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() canvas:StartMoving() end)
    drag:SetScript("OnDragStop", function() canvas:StopMovingOrSizing() end)
    canvas:SetScript("OnHide", function() canvas:StopMovingOrSizing() end)
    function ns.OpenSettings()
        if SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        canvas:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 960, (UIParent:GetHeight() - 32) / 720))
        canvas:Show()
        canvas:Raise()
    end
    SLASH_PQOL1 = "/pqol"
    SlashCmdList.PQOL = ns.OpenSettings

    local title = launcher:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PyresinQoL")
    local subtitle = launcher:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", 16, -52)
    subtitle:SetText(L.settingsSubtitle)
    local open = CreateFrame("Button", nil, launcher, "UIPanelButtonTemplate")
    open:SetSize(220, 28)
    open:SetPoint("TOPLEFT", 16, -84)
    open:SetText(L.openSettings)
    open:SetScript("OnClick", ns.OpenSettings)

    local inner = canvas:CreateTexture(nil, "ARTWORK")
    inner:SetAtlas("Options_InnerFrame")
    inner:SetPoint("TOPLEFT", 17, -64)
    inner:SetPoint("BOTTOMRIGHT", -17, 42)
    local sidebar = CreateFrame("Frame", nil, canvas)
    sidebar:SetPoint("TOPLEFT", 22, -78)
    sidebar:SetPoint("BOTTOMLEFT", 22, 48)
    sidebar:SetWidth(202)
    local border = sidebar:CreateTexture(nil, "ARTWORK")
    border:SetPoint("TOPRIGHT", 6, 12)
    border:SetPoint("BOTTOMRIGHT", 6, -6)
    border:SetWidth(1)
    border:SetColorTexture(0.45, 0.45, 0.45, 0.6)

    local list = CreateFrame("Frame", nil, canvas, "SettingsListTemplate")
    list:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 24, 0)
    list:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -28, 48)
    list.Header:SetHeight(66)
    list.Header.Title:SetPoint("RIGHT", list.Header.DefaultsButton, "LEFT", -12, 0)
    for _, region in ipairs({ list.Header:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", 0, -58)
            region:SetPoint("TOPRIGHT", 0, -58)
            region:SetHeight(8)
        end
    end
    local pages = {
        { name = L.modules, description = L.overviewDescription, initializers = {}, settings = {} },
    }
    local groups, groupsByID, modulePages = {}, {}, {}
    for _, definition in ipairs(ns.settingsGroups) do
        local group = { name = definition.name, pages = {} }
        groups[#groups + 1] = group
        groupsByID[definition.id] = group
    end
    groups[1].pages[1] = pages[1]
    for _, module in ipairs(ns.modules) do
        local featurePages = {}
        modulePages[module.id] = featurePages
        local group = assert(groupsByID[module.group], "Unknown settings group: " .. module.group)
        for _, definition in ipairs(module.pages) do
            local page = { name = definition.name, description = module.description,
                module = module, initializers = {}, settings = {} }
            pages[#pages + 1] = page
            group.pages[#group.pages + 1] = page
            featurePages[definition.id] = page
        end
    end
    local footer = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 24, 22)
    footer:SetPoint("RIGHT", canvas, "RIGHT", -300, 0)
    footer:SetJustifyH("LEFT")
    footer:SetWordWrap(true)
    local close = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    close:SetSize(96, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 16)
    close:SetText(CLOSE)
    close:SetScript("OnClick", function() canvas:Hide() end)
    local reload = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    reload:SetSize(154, 22)
    reload:SetPoint("RIGHT", close, "LEFT", -8, 0)
    reload:SetText(L.reloadUI)
    reload:SetScript("OnClick", function()
        if ns.ModulesNeedReload() and not InCombatLockdown() then ReloadUI() end
    end)
    local currentPage = pages[1]
    local function UpdateModuleState()
        for _, page in ipairs(pages) do
            local enabled = not page.module or PyresinQoLDB.modules[page.module.id]
            local pending = page.module and enabled ~= page.module.active
            page.button.text:SetText(page.name .. (pending and " *" or ""))
            page.button.text:SetTextColor(enabled and 1 or 0.5, enabled and 0.82 or 0.5, enabled and 0 or 0.5)
        end
        local pending = ns.ModulesNeedReload()
        local module = currentPage.module
        local enabled = not module or (module.active and PyresinQoLDB.modules[module.id])
        footer:SetText(pending and (InCombatLockdown() and L.combat or L.reloadHint)
            or not enabled and L.disabledHint or L.savedHint)
        footer:SetTextColor(pending and 1 or 0.7, pending and 0.82 or 0.7, pending and 0.3 or 0.7)
        reload:SetShown(pending)
        reload:SetEnabled(pending and not InCombatLockdown())
        list.Header.DefaultsButton:SetEnabled(enabled)
    end
    local function DisplayPage(page)
        currentPage = page
        list.Header.Title:SetText(page.name)
        list:Display(page.initializers)
        for _, entry in ipairs(pages) do entry.button.selected:SetShown(entry == page) end
        UpdateModuleState()
    end
    for _, page in ipairs(pages) do
        local button = CreateFrame("Button", nil, sidebar)
        button:SetHeight(24)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.selected = button:CreateTexture(nil, "BACKGROUND")
        button.selected:SetAllPoints()
        button.selected:SetAtlas("Options_List_Active")
        button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        button.text:SetPoint("LEFT", 34, 0)
        button.text:SetPoint("RIGHT", -8, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetText(page.name)
        button:SetScript("OnClick", function() DisplayPage(page) end)
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(page.name)
            GameTooltip:AddLine(page.description, 1, 1, 1, true)
            if page.module then
                local enabled = PyresinQoLDB.modules[page.module.id]
                GameTooltip:AddLine(enabled ~= page.module.active and L.modulePending
                    or enabled and L.moduleActive or L.moduleInactive, 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page.button = button
    end
    local function LayoutNavigation()
        local y = 0
        for _, group in ipairs(groups) do
            group.button:ClearAllPoints()
            group.button:SetPoint("TOPLEFT", 0, -y)
            group.button:SetPoint("TOPRIGHT", 0, -y)
            group.button.arrow:SetRotation(group.collapsed and 0 or -math.pi / 2)
            y = y + 32
            for _, page in ipairs(group.pages) do
                page.button:SetShown(not group.collapsed)
                page.button:ClearAllPoints()
                page.button:SetPoint("TOPLEFT", 0, -y)
                page.button:SetPoint("TOPRIGHT", 0, -y)
                if not group.collapsed then y = y + 26 end
            end
            y = y + 8
        end
    end
    for _, group in ipairs(groups) do
        local button = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        button:SetHeight(30)
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetAtlas("Options_CategoryHeader_1")
        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        label:SetPoint("LEFT", 16, 0)
        label:SetText(group.name)
        button.arrow = button:CreateTexture(nil, "ARTWORK")
        button.arrow:SetSize(16, 16)
        button.arrow:SetPoint("RIGHT", -4, 0)
        button.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", function()
            group.collapsed = not group.collapsed
            LayoutNavigation()
        end)
        group.button = button
    end
    LayoutNavigation()
    canvas:RegisterEvent("PLAYER_REGEN_DISABLED")
    canvas:RegisterEvent("PLAYER_REGEN_ENABLED")
    canvas:SetScript("OnEvent", UpdateModuleState)

    local controls = ns.CreateSettingsControls(category)
    local AddControl = controls.AddControl

    local overview = pages[1]
    for _, module in ipairs(ns.modules) do
        local setting = Settings.RegisterAddOnSetting(category, "PyresinQoL_Module_" .. module.id,
            module.id, PyresinQoLDB.modules, Settings.VarType.Boolean, module.name, true)
        setting:SetValueChangedCallback(function() DisplayPage(currentPage) end)
        table.insert(overview.settings, { setting = setting, default = true })
        AddControl(overview, Settings.CreateCheckboxInitializer(setting, nil, module.description .. "\n\n" .. L.moduleHelp))
    end

    for _, module in ipairs(ns.modules) do
        module.buildSettings(module, { category = category, pages = modulePages[module.id], controls = controls })
    end

    local function ResetPage(page)
        if page.module and not (page.module.active and PyresinQoLDB.modules[page.module.id]) then return end
        for _, entry in ipairs(page.settings) do entry.setting:SetValue(entry.default) end
    end
    list.Header.DefaultsButton:SetText(DEFAULTS)
    list.Header.DefaultsButton:SetScript("OnClick", function()
        ResetPage(currentPage)
        DisplayPage(currentPage)
    end)
    canvas.OnDefault = function()
        for _, page in ipairs(pages) do ResetPage(page) end
        DisplayPage(currentPage)
    end
    launcher.OnDefault = canvas.OnDefault
    canvas.OnRefresh = function() DisplayPage(currentPage) end
    canvas:SetScript("OnShow", canvas.OnRefresh)
end
