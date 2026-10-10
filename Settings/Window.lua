local _, ns = ...
local L = ns.L
local ICON = "Interface\\AddOns\\PyresinQoL\\Media\\AddonIcon"

function ns.InitializeSettings()
    local launcher = CreateFrame("Frame")
    launcher:Hide()
    local category = Settings.RegisterCanvasLayoutCategory(launcher, "PyresinQoL")
    Settings.RegisterAddOnCategory(category)

    -- Use Blizzard's native settings window frame.
    local canvas = CreateFrame("Frame", "PyresinQoLSettingsFrame", UIParent, "SettingsFrameTemplate")
    canvas:Hide()
    canvas:SetSize(920, 724)
    canvas:SetPoint("CENTER")
    canvas:SetFrameStrata("DIALOG")
    canvas:SetToplevel(true)
    canvas:SetMovable(true)
    canvas:SetClampedToScreen(true)
    canvas:EnableMouse(true)
    canvas.NineSlice.Text:SetText("PyresinQoL")
    local cornerLogo = canvas.NineSlice:CreateTexture(nil, "OVERLAY")
    cornerLogo:SetTexture(ICON)
    cornerLogo:SetSize(72, 72)
    cornerLogo:SetPoint("TOPLEFT", canvas, "TOPLEFT", -20, 24)
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
        canvas:SetScale(math.min(1, (UIParent:GetWidth() - 32) / 920, (UIParent:GetHeight() - 32) / 724))
        canvas:Show()
        canvas:Raise()
    end
    SLASH_PQOL1 = "/pqol"
    SlashCmdList.PQOL = ns.OpenSettings

    local logo = launcher:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ICON)
    logo:SetSize(48, 48)
    logo:SetPoint("TOPLEFT", 16, -16)
    local title = launcher:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("LEFT", logo, "RIGHT", 12, 0)
    title:SetText("PyresinQoL")
    local subtitle = launcher:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", 16, -80)
    subtitle:SetText(L.settingsSubtitle)
    local open = CreateFrame("Button", nil, launcher, "UIPanelButtonTemplate")
    open:SetSize(220, 28)
    open:SetPoint("TOPLEFT", 16, -112)
    open:SetText(L.openSettings)
    open:SetScript("OnClick", ns.OpenSettings)

    local search = CreateFrame("EditBox", nil, canvas, "SearchBoxTemplate")
    search:SetSize(350, 22)
    search:SetPoint("TOPRIGHT", -18, -34)
    search:SetMaxBytes(64)
    canvas.SearchBox = search

    local inner = canvas:CreateTexture(nil, "OVERLAY")
    inner:SetAtlas("Options_InnerFrame", true)
    inner:SetPoint("TOPLEFT", 17, -64)
    local sidebar = CreateFrame("Frame", nil, canvas)
    sidebar:SetPoint("TOPLEFT", 18, -76)
    sidebar:SetPoint("BOTTOMLEFT", 18, 46)
    sidebar:SetWidth(199)

    local list = CreateFrame("Frame", nil, canvas, "SettingsListTemplate")
    list:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 16, 0)
    list:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -22, 47)
    list.Header.Title:SetPoint("RIGHT", list.Header.DefaultsButton, "LEFT", -12, 0)
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
    pages[1].group = groups[1]
    for _, module in ipairs(ns.modules) do
        local featurePages = {}
        modulePages[module.id] = featurePages
        local group = assert(groupsByID[module.group], "Unknown settings group: " .. module.group)
        for _, definition in ipairs(module.pages) do
            local page = { name = definition.name, description = module.description,
                module = module, group = group, initializers = {}, settings = {} }
            pages[#pages + 1] = page
            group.pages[#group.pages + 1] = page
            featurePages[definition.id] = page
        end
    end
    local profilePage = { name = L.profiles, description = L.profileHelp, initializers = {}, settings = {} }
    pages[#pages + 1] = profilePage
    local profiles = ns.CreateProfilesPage(list)
    profiles:SetPoint("TOPLEFT", 10, -64)
    profiles:SetPoint("BOTTOMRIGHT", -20, 8)
    profiles:Hide()
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
    local LayoutNavigation
    local function GetSearchText()
        return search:GetText():match("^%s*(.-)%s*$"):upper()
    end
    local function UpdateModuleState()
        local searching = GetSearchText() ~= ""
        for _, page in ipairs(pages) do
            local enabled = not page.module or PyresinQoLDB.modules[page.module.id]
            local pending = page.module and enabled ~= page.module.active
            local selected = not searching and page == currentPage
            page.button.text:SetText(page.name .. (pending and " *" or ""))
            if not enabled then page.button.text:SetTextColor(0.5, 0.5, 0.5)
            elseif selected then page.button.text:SetTextColor(1, 1, 1)
            else page.button.text:SetTextColor(1, 0.82, 0) end
        end
        local pending = ns.ModulesNeedReload()
        local module = not searching and currentPage.module
        local enabled = not module or (module.active and PyresinQoLDB.modules[module.id])
        footer:SetText(pending and (InCombatLockdown() and L.combat or L.reloadHint)
            or not enabled and L.disabledHint or L.savedHint)
        footer:SetTextColor(pending and 1 or 0.7, pending and 0.82 or 0.7, pending and 0.3 or 0.7)
        reload:SetShown(pending)
        reload:SetEnabled(pending and not InCombatLockdown())
        list.Header.DefaultsButton:SetEnabled(enabled and not searching)
        list.Header.DefaultsButton:SetShown(not searching and currentPage ~= profilePage)
    end
    local function CollectSearchResults(text)
        local words = { text }
        for word in text:gmatch("([^,%s]+)") do words[#words + 1] = word end
        local initializers = {}
        for _, page in ipairs(pages) do
            local matches = {}
            local pageMatch = page.searchHeader:MatchesSearchTags(words)
            local section, shownSection
            for _, initializer in ipairs(page.initializers) do
                if initializer:IsTemplate("SettingsListSectionHeaderTemplate") then
                    section = initializer
                elseif initializer:ShouldShow() and (pageMatch or initializer:MatchesSearchTags(words)) then
                    if section and section ~= shownSection then
                        matches[#matches + 1] = section
                        shownSection = section
                    end
                    matches[#matches + 1] = initializer
                end
            end
            if pageMatch or #matches > 0 then
                initializers[#initializers + 1] = page.searchHeader
                for _, initializer in ipairs(matches) do initializers[#initializers + 1] = initializer end
            end
        end
        if #initializers == 0 then
            initializers[1] = CreateSettingsListSectionHeaderInitializer(SETTINGS_SEARCH_NOTHING_FOUND)
        end
        return initializers
    end
    local function RefreshView()
        local text = GetSearchText()
        local searching = text ~= ""
        local initializers = currentPage.initializers
        if searching then initializers = CollectSearchResults(text) end
        list.Header.Title:SetText(searching and SETTINGS_SEARCH_RESULTS or currentPage.name)
        list:Display(initializers)
        profiles:SetShown(not searching and currentPage == profilePage)
        for _, page in ipairs(pages) do page.button.selected:SetShown(not searching and page == currentPage) end
        UpdateModuleState()
    end
    local function SelectPage(page)
        currentPage = page
        search:ClearFocus()
        if page.group and page.group.collapsed then
            page.group.collapsed = false
            LayoutNavigation()
        end
        -- Clearing a nonempty query refreshes synchronously through OnTextChanged.
        if search:GetText() == "" then RefreshView()
        else search:SetText("") end
    end
    for _, page in ipairs(pages) do
        local header = Settings.CreateElementInitializer("SettingsListSearchCategoryTemplate", {})
        header:AddSearchTags(page.name, page.group and page.group.name, page.module and page.module.name)
        function header:InitFrame(frame)
            frame.Title:SetText(page.group and (page.group.name .. " > " .. page.name) or page.name)
            frame:SetScript("OnClick", function() SelectPage(page) end)
        end
        page.searchHeader = header
        local button = CreateFrame("Button", nil, sidebar)
        button:SetHeight(20)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAtlas("Options_List_Hover", true)
        highlight:SetPoint("CENTER")
        button:SetHighlightTexture(highlight)
        button.selected = button:CreateTexture(nil, "BACKGROUND")
        button.selected:SetAtlas("Options_List_Active", true)
        button.selected:SetPoint("CENTER")
        button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        button.text:SetPoint("LEFT", page == profilePage and 16 or 36, 1)
        button.text:SetPoint("RIGHT", -8, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetText(page.name)
        button:SetScript("OnClick", function() SelectPage(page) end)
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
    profilePage.button:SetPoint("BOTTOMLEFT", 0, 0)
    profilePage.button:SetPoint("BOTTOMRIGHT", 0, 0)
    LayoutNavigation = function()
        local y = 0
        for _, group in ipairs(groups) do
            group.button:ClearAllPoints()
            group.button:SetPoint("TOPLEFT", 0, -y)
            group.button:SetPoint("TOPRIGHT", 0, -y)
            group.button.arrow:SetAtlas(group.collapsed and "common-button-dropdown-closed" or "common-button-dropdown-open")
            y = y + 32
            for _, page in ipairs(group.pages) do
                page.button:SetShown(not group.collapsed)
                page.button:ClearAllPoints()
                page.button:SetPoint("TOPLEFT", 0, -y)
                page.button:SetPoint("TOPRIGHT", 0, -y)
                if not group.collapsed then y = y + 22 end
            end
            y = y + 20
        end
    end
    for _, group in ipairs(groups) do
        local button = CreateFrame("Button", nil, sidebar, "SettingsCategoryListHeaderTemplate")
        -- The atlas includes the fading background below the 30px header.
        button.Background:SetAtlas("Options_CategoryHeader_1", true)
        button.Label:SetText(group.name)
        button.arrow = button:CreateTexture(nil, "OVERLAY")
        button.arrow:SetSize(16, 16)
        button.arrow:SetPoint("RIGHT", -6, 0)
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
            module.id, PyresinQoLDB.modules, Settings.VarType.Boolean, module.name, module.enabledByDefault)
        setting:SetValueChangedCallback(RefreshView)
        table.insert(overview.settings, { setting = setting, default = module.enabledByDefault })
        AddControl(overview, Settings.CreateCheckboxInitializer(setting, nil, module.description .. "\n\n" .. L.moduleHelp))
    end

    for _, module in ipairs(ns.modules) do
        module.buildSettings(module, { category = category, pages = modulePages[module.id], controls = controls,
            canvas = canvas,
        })
    end

    local function ResetPage(page)
        if page.module and not (page.module.active and PyresinQoLDB.modules[page.module.id]) then return end
        for _, entry in ipairs(page.settings) do entry.setting:SetValue(entry.default) end
        if page.onReset then page.onReset() end
    end
    list.Header.DefaultsButton:SetText(DEFAULTS)
    list.Header.DefaultsButton:SetScript("OnClick", function()
        ResetPage(currentPage)
        RefreshView()
    end)
    canvas.OnDefault = function()
        for _, page in ipairs(pages) do ResetPage(page) end
        RefreshView()
    end
    launcher.OnDefault = canvas.OnDefault
    canvas.OnRefresh = RefreshView
    canvas:SetScript("OnShow", RefreshView)
    search:HookScript("OnTextChanged", RefreshView)
    search:HookScript("OnEscapePressed", function() search:SetText("") end)
    canvas:HookScript("OnHide", function()
        search:ClearFocus()
        search:SetText("")
    end)

    function ns.RefreshProfileSettings()
        for _, page in ipairs(pages) do
            if page.module then
                for _, entry in ipairs(page.settings) do
                    if entry.setting:GetValue() == nil then entry.setting:SetValue(entry.default)
                    else entry.setting:NotifyUpdate() end
                end
            end
        end
        RefreshView()
    end
    EventRegistry:RegisterCallback("EditMode.Exit", ns.MaybePromptProfileReload, ns)
end
