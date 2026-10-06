local _, ns = ...
local L = ns.L
local DEFAULT_PROFILE = "Default"
local lastCatalog, catalogCharacter

local function RepairModuleFlags(settings)
    if type(settings.modules) ~= "table" then settings.modules = nil; return end
    for _, module in ipairs(ns.modules) do
        local value = settings.modules[module.id]
        if value ~= nil and type(value) ~= "boolean" then settings.modules[module.id] = nil end
    end
end

local function CharacterMappings()
    local character = UnitGUID("player")
    if not character then return end
    local store = PyresinQoLDB.profileStore
    store.characterBindings[character] = store.characterBindings[character] or {}
    store.profileLayouts[character] = store.profileLayouts[character] or {}
    local bindings, links = store.characterBindings[character], store.profileLayouts[character]
    -- Preserve bindings from the first layout-linked version on this character.
    if store.layoutBindings then
        for key, name in pairs(store.layoutBindings) do
            bindings[key] = bindings[key] or name
            links[name] = links[name] or key
        end
        store.layoutBindings = nil
    end
    return bindings, links
end

local function BindProfile(name, key)
    key = key or ns.currentLayoutKey
    if not key then return end
    local bindings, links = CharacterMappings()
    if not bindings then return end
    local previous = links[name]
    if previous ~= key and bindings[previous] == name then bindings[previous] = nil end
    bindings[key], links[name] = name, key
end

local function Snapshot()
    local settings = {}
    for key, value in pairs(PyresinQoLDB) do
        if key ~= "profileStore" then
            settings[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    return settings
end

local function Restore(settings)
    local modules = PyresinQoLDB.modules
    for key in pairs(PyresinQoLDB) do
        if key ~= "profileStore" then PyresinQoLDB[key] = nil end
    end
    for key, value in pairs(settings) do
        if key ~= "profileStore" then
            PyresinQoLDB[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    -- Native settings retain both the root table and the module table.
    if modules then
        for key in pairs(modules) do modules[key] = nil end
        for key, value in pairs(PyresinQoLDB.modules or {}) do modules[key] = value end
        PyresinQoLDB.modules = modules
    end
    PyresinQoLDB.modules = PyresinQoLDB.modules or {}
    for _, module in ipairs(ns.modules) do
        if PyresinQoLDB.modules[module.id] == nil then PyresinQoLDB.modules[module.id] = true end
    end
end

local function CopyCurrentProfile(name)
    local store = PyresinQoLDB.profileStore
    store.profiles[store.active] = Snapshot()
    store.profiles[name] = CopyTable(store.profiles[store.active])
    store.active = name
    BindProfile(name)
end

function ns.InitializeProfiles()
    if type(PyresinQoLDB) ~= "table" then PyresinQoLDB = {} end
    RepairModuleFlags(PyresinQoLDB)
    local store = type(PyresinQoLDB.profileStore) == "table" and PyresinQoLDB.profileStore or {}
    PyresinQoLDB.profileStore = store
    if type(store.profiles) ~= "table" then store.profiles = {} end
    for name, profile in pairs(store.profiles) do
        if type(name) ~= "string" or name == "" or type(profile) ~= "table" then
            store.profiles[name] = nil
        else
            RepairModuleFlags(profile)
        end
    end
    if type(store.active) ~= "string" or not store.profiles[store.active] then store.active = DEFAULT_PROFILE end
    -- Live root settings remain authoritative; never load an unrelated snapshot
    -- merely because the registry was damaged.
    store.profiles[store.active] = store.profiles[store.active] or {}
    local function RepairMappings(mappings, reverse)
        for key, value in pairs(mappings) do
            local profile = reverse and key or value
            if type(key) ~= "string" or key == "" or type(value) ~= "string" or value == ""
                or not store.profiles[profile] then mappings[key] = nil end
        end
    end
    for _, field in ipairs({ "characterBindings", "profileLayouts" }) do
        if type(store[field]) ~= "table" then store[field] = {} end
        for character, mappings in pairs(store[field]) do
            if type(character) ~= "string" or character == "" or type(mappings) ~= "table" then
                store[field][character] = nil
            else
                RepairMappings(mappings, field == "profileLayouts")
            end
        end
    end
    if type(store.layoutBindings) == "table" then RepairMappings(store.layoutBindings)
    else store.layoutBindings = nil end
    store.layoutCatalogs = nil -- Persisted catalogs may have missed delete/create events.
    lastCatalog, catalogCharacter = nil, nil
    if type(store.pending) == "string" and store.profiles[store.pending] then
        -- Capture logout writes before applying the new profile at startup.
        store.profiles[store.active] = Snapshot()
        Restore(store.profiles[store.pending])
        store.active = store.pending
    end
    store.pending = nil
end

function ns.GetProfileNames()
    local names = {}
    for name in pairs(PyresinQoLDB.profileStore.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == DEFAULT_PROFILE then return b ~= DEFAULT_PROFILE end
        if b == DEFAULT_PROFILE then return false end
        return a < b
    end)
    return names
end

function ns.ValidateProfileName(name, previous)
    if type(name) ~= "string" then return nil, L.profileInvalidName end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or strlenutf8(name) > 32 or name:find("[%c|]") then return nil, L.profileInvalidName end
    if name ~= previous and (name == L.profileDefault or PyresinQoLDB.profileStore.profiles[name]) then
        return nil, L.profileExists
    end
    return name
end

function ns.CreateProfile(name)
    if InCombatLockdown() then return nil, L.combat end
    local valid, reason = ns.ValidateProfileName(name)
    if not valid then return nil, reason end
    CopyCurrentProfile(valid)
    return true
end

function ns.RenameProfile(previous, name)
    if InCombatLockdown() then return nil, L.combat end
    local store = PyresinQoLDB.profileStore
    if previous == DEFAULT_PROFILE or not store.profiles[previous] then return nil, L.profileUnavailable end
    local valid, reason = ns.ValidateProfileName(name, previous)
    if not valid then return nil, reason end
    if valid == previous then return true end
    store.profiles[valid], store.profiles[previous] = store.profiles[previous], nil
    if store.active == previous then store.active = valid end
    for _, bindings in pairs(store.characterBindings) do
        for key, profile in pairs(bindings) do
            if profile == previous then bindings[key] = valid end
        end
    end
    for _, links in pairs(store.profileLayouts) do
        links[valid], links[previous] = links[previous], nil
    end
    return true
end

function ns.DeleteProfile(name)
    if InCombatLockdown() then return nil, L.combat end
    local store = PyresinQoLDB.profileStore
    if name == DEFAULT_PROFILE or name == store.active or not store.profiles[name] then
        return nil, L.profileUnavailable
    end
    store.profiles[name] = nil
    for _, bindings in pairs(store.characterBindings) do
        for key, profile in pairs(bindings) do
            if profile == name then bindings[key] = nil end
        end
    end
    for _, links in pairs(store.profileLayouts) do links[name] = nil end
    return true
end

function ns.ProfileSwitchError()
    if InCombatLockdown() then return L.combat end
    local manager = EditModeManagerFrame
    if manager and manager:IsShown() and manager:HasActiveChanges() then return L.profileUnsavedLayout end
end

function ns.SwitchProfile(name)
    local reason = ns.ProfileSwitchError()
    if reason then return nil, reason end
    local store = PyresinQoLDB.profileStore
    if not store.profiles[name] then return nil, L.profileUnavailable end
    BindProfile(name)
    if name == store.active then return true end
    -- ponytail: Manual switches reload; module activation still needs a fresh runtime.
    store.profiles[store.active] = Snapshot()
    store.pending = name
    ReloadUI()
    return true
end

local function LayoutKey(layout, character)
    local scope = layout.layoutType == Enum.EditModeLayoutType.Character and character or "account"
    return scope .. ":" .. layout.layoutType .. ":" .. layout.layoutName
end

local function PresetName(index)
    local presets = EditModePresetLayoutManager and EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    return presets and presets[index] and presets[index].layoutName or L.profileLayoutName:format(index)
end

function ns.GetEditModeLayouts()
    local layouts = {}
    if not C_EditMode then return layouts end
    local character, info = UnitGUID("player"), C_EditMode.GetLayouts()
    if not character or not info then return layouts end
    local presets = Enum.EditModePresetLayoutsMeta.NumValues
    for index = 1, presets do
        layouts[#layouts + 1] = { key = "preset:" .. index, name = PresetName(index),
            scope = L.profilePreset }
    end
    for _, layout in ipairs(info.layouts) do
        layouts[#layouts + 1] = { key = LayoutKey(layout, character), name = layout.layoutName,
            scope = layout.layoutType == Enum.EditModeLayoutType.Character and L.profileCharacter or L.profileAccount }
    end
    return layouts
end

function ns.LinkProfileToLayout(key)
    local reason = ns.ProfileSwitchError()
    if reason then return nil, reason end
    for _, layout in ipairs(ns.GetEditModeLayouts()) do
        if layout.key == key then
            BindProfile(PyresinQoLDB.profileStore.active, key)
            return true
        end
    end
    return nil, L.profileLayoutUnavailable
end

function ns.GetLinkedProfileLayout()
    local _, links = CharacterMappings()
    return links and links[PyresinQoLDB.profileStore.active]
end

function ns.RecordLayoutCatalog()
    if not C_EditMode or not C_EditMode.GetLayouts then return end
    local character = UnitGUID("player")
    if not character then return end
    local info = C_EditMode.GetLayouts()
    if not info or not info.activeLayout then return end
    CharacterMappings()
    local store = PyresinQoLDB.profileStore
    local catalog = {}
    for index, layout in ipairs(info.layouts) do
        catalog[index] = LayoutKey(layout, character)
    end
    -- ponytail: One rename per live update; use stable IDs if Blizzard exposes them.
    local previous = catalogCharacter == character and lastCatalog or nil
    if previous and #previous == #catalog then
        local renamed, count = nil, 0
        for index, key in ipairs(catalog) do
            if previous[index] ~= key then renamed, count = index, count + 1 end
        end
        if count == 1 then
            local old, new = previous[renamed], catalog[renamed]
            for _, bindings in pairs(store.characterBindings) do
                if bindings[old] then bindings[new], bindings[old] = bindings[old], nil end
            end
            for _, links in pairs(store.profileLayouts) do
                for profile, key in pairs(links) do
                    if key == old then links[profile] = new end
                end
            end
        end
    end
    lastCatalog, catalogCharacter = catalog, character
    return info, catalog
end

function ns.SyncLayoutProfile()
    if not C_EditMode or InCombatLockdown() then return end
    local info, catalog = ns.RecordLayoutCatalog()
    if not info then return end
    local store = PyresinQoLDB.profileStore
    local index = info.activeLayout - Enum.EditModePresetLayoutsMeta.NumValues
    local layout = info.layouts[index]
    local key, name = catalog[index], layout and layout.layoutName
    if index <= 0 then
        key = "preset:" .. info.activeLayout
        name = PresetName(info.activeLayout)
    end
    if not key then return end
    local character = UnitGUID("player")
    if key == ns.currentLayoutKey and character == ns.currentProfileCharacter then
        ns.currentLayoutName = name
        if ns.RefreshProfileSettings then EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged") end
        return
    end
    ns.currentLayoutKey, ns.currentLayoutName = key, name
    ns.currentProfileCharacter = character
    local bindings, links = CharacterMappings()
    if not store.layoutsInitialized then
        BindProfile(store.active)
        store.layoutsInitialized = true
    end
    local profile = bindings[key]
    if not profile or not store.profiles[profile] then
        for _, candidate in ipairs(ns.GetProfileNames()) do
            if links[candidate] == key then profile = candidate; break end
        end
    end
    local performance = ns.GetModule("performance")
    if profile ~= store.active then
        -- Open editor callbacks belong to the outgoing profile.
        if ns.CastBar and ns.CastBar.CloseEditors then ns.CastBar.CloseEditors() end
        if ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        if performance.StopPerformanceDragging then performance.StopPerformanceDragging() end
    end
    if not profile or not store.profiles[profile] then
        local candidate, suffix = name, 2
        while store.profiles[candidate] or candidate == L.profileDefault do
            candidate, suffix = name .. " (" .. suffix .. ")", suffix + 1
        end
        CopyCurrentProfile(candidate)
    elseif profile ~= store.active then
        store.profiles[store.active] = Snapshot()
        Restore(store.profiles[profile])
        store.active = profile
        ns.InitializeDatabase()
        if ns.RefreshProfileSettings then
            ns.RefreshProfileSettings()
            if performance.RestorePerformancePosition then performance.RestorePerformancePosition() end
            ns.profileReloadPending = ns.ModulesNeedReload()
        end
    end
    BindProfile(store.active)
    if ns.RefreshProfileSettings then EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged") end
end

function ns.MaybePromptProfileReload()
    if not ns.profileReloadPending or ns.ProfileSwitchError() then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
    ns.profileReloadPending = nil
    if ns.ModulesNeedReload() then StaticPopup_Show("PYRESINQOL_PROFILE_RELOAD") end
end

local function ProfileLabel(name)
    return name == DEFAULT_PROFILE and L.profileDefault or name
end

local function Complete(success, reason)
    if not success then
        UIErrorsFrame:AddMessage(reason, 1, 0.2, 0.2)
        return true -- Keep the dialog open when validation fails.
    end
    EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged")
end

local function RegisterDialogs()
    StaticPopupDialogs.PYRESINQOL_PROFILE_NAME = {
        text = L.profileNewDialog, button1 = ACCEPT, button2 = CANCEL,
        hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(dialog, data)
            dialog:GetTextFontString():SetText(data.rename and L.profileRenameDialog or L.profileNewDialog)
            local input = dialog:GetEditBox()
            input:SetMaxLetters(32)
            input:SetText(data.rename or "")
            input:HighlightText()
            input:SetFocus()
        end,
        EditBoxOnTextChanged = function(input, data)
            local valid = ns.ValidateProfileName(input:GetText(), data.rename)
            input:GetParent():GetButton1():SetEnabled(valid ~= nil and not InCombatLockdown())
        end,
        EditBoxOnEnterPressed = function(input)
            local button = input:GetParent():GetButton1()
            if button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(input) input:GetParent():Hide() end,
        OnAccept = function(dialog, data)
            if data.rename then return Complete(ns.RenameProfile(data.rename, dialog:GetEditBox():GetText())) end
            return Complete(ns.CreateProfile(dialog:GetEditBox():GetText()))
        end,
    }
    StaticPopupDialogs.PYRESINQOL_PROFILE_SWITCH = {
        text = L.profileSwitchDialog, button1 = L.profileSwitchReload, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, name) return Complete(ns.SwitchProfile(name)) end,
    }
    StaticPopupDialogs.PYRESINQOL_PROFILE_DELETE = {
        text = L.profileDeleteDialog, button1 = DELETE, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, name) return Complete(ns.DeleteProfile(name)) end,
    }
    StaticPopupDialogs.PYRESINQOL_PROFILE_RELOAD = {
        text = L.profileModulesReload, button1 = L.reloadUI, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function()
            local reason = ns.ProfileSwitchError()
            if reason then return Complete(nil, reason) end
            if ns.ModulesNeedReload() then ReloadUI() end
        end,
    }
end

function ns.CreateProfilesPage(parent)
    RegisterDialogs()
    local frame = CreateFrame("Frame", nil, parent)
    local function Label(text, y, font)
        local label = frame:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", font and 7 or 37, -y)
        label:SetPoint("TOPRIGHT", frame, font and "TOPRIGHT" or "TOP", font and 0 or -85, -y)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetText(text)
        return label
    end
    local help = Label(L.profileHelp, 0, "GameFontHighlight")
    help:ClearAllPoints()
    help:SetPoint("TOPLEFT")
    help:SetPoint("TOPRIGHT")
    local linked = Label("", 76, "GameFontHighlightSmall")
    linked:ClearAllPoints()
    linked:SetPoint("TOPLEFT", 0, -76)
    linked:SetPoint("TOPRIGHT", 0, -76)
    Label(L.profileCurrent, 112, "GameFontHighlightLarge")
    Label(L.profileCurrent, 148)
    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(240)
    dropdown:SetPoint("TOPLEFT", frame, "TOP", -80, -140)
    dropdown:SetupMenu(function(_, root)
        local store = PyresinQoLDB.profileStore
        local switchError = ns.ProfileSwitchError()
        root:SetScrollMode(320)
        for _, name in ipairs(ns.GetProfileNames()) do
            local radio = root:CreateRadio(ProfileLabel(name), function() return store.active == name end, function()
                if store.active == name then return end
                local reason = ns.ProfileSwitchError()
                if reason then UIErrorsFrame:AddMessage(reason, 1, 0.2, 0.2); return end
                StaticPopup_Show("PYRESINQOL_PROFILE_SWITCH", ProfileLabel(name), nil, name)
            end)
            radio:SetEnabled(switchError == nil)
        end
    end)
    Label(L.profileLayout, 183)
    local layoutDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    layoutDropdown:SetWidth(240)
    layoutDropdown:SetPoint("TOPLEFT", frame, "TOP", -80, -175)
    layoutDropdown:SetDefaultText(L.profileLayoutNone)
    layoutDropdown:SetupMenu(function(_, root)
        root:SetScrollMode(320)
        for _, layout in ipairs(ns.GetEditModeLayouts()) do
            local radio = root:CreateRadio(layout.name .. " (" .. layout.scope .. ")",
                function() return ns.GetLinkedProfileLayout() == layout.key end,
                function() Complete(ns.LinkProfileToLayout(layout.key)) end)
            radio:SetEnabled(ns.ProfileSwitchError() == nil)
        end
    end)
    local function Button(label, text, y, callback)
        Label(label, y + 5)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(240, 24)
        button:SetPoint("TOPLEFT", frame, "TOP", -80, -y)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        return button
    end
    local create = Button(L.profileNew, L.profileCreate, 210, function()
        StaticPopup_Show("PYRESINQOL_PROFILE_NAME", nil, nil, {})
    end)
    local rename = Button(L.profileRename, L.profileRenameButton, 245, function()
        StaticPopup_Show("PYRESINQOL_PROFILE_NAME", nil, nil, { rename = PyresinQoLDB.profileStore.active })
    end)
    Label(L.profileDelete, 300, "GameFontHighlightLarge")
    Label(L.profileDeleteTarget, 340)
    local toDelete
    local deleteDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    deleteDropdown:SetWidth(240)
    deleteDropdown:SetPoint("TOPLEFT", frame, "TOP", -80, -332)
    deleteDropdown:SetDefaultText(L.profileNone)
    local delete = Button(L.profileDelete, DELETE, 367, function()
        if toDelete then StaticPopup_Show("PYRESINQOL_PROFILE_DELETE", ProfileLabel(toDelete), nil, toDelete) end
    end)
    local function Refresh()
        local store = PyresinQoLDB.profileStore
        local available = {}
        for _, name in ipairs(ns.GetProfileNames()) do
            if name ~= DEFAULT_PROFILE and name ~= store.active then available[#available + 1] = name end
        end
        if not store.profiles[toDelete] or toDelete == store.active then toDelete = available[1] end
        local enabled = not InCombatLockdown()
        dropdown:SetEnabled(enabled)
        layoutDropdown:SetEnabled(ns.ProfileSwitchError() == nil and #ns.GetEditModeLayouts() > 0)
        create:SetEnabled(enabled)
        rename:SetEnabled(enabled and store.active ~= DEFAULT_PROFILE)
        deleteDropdown:SetEnabled(enabled and toDelete ~= nil)
        delete:SetEnabled(enabled and toDelete ~= nil)
        dropdown:GenerateMenu()
        layoutDropdown:GenerateMenu()
        deleteDropdown:GenerateMenu()
        linked:SetText(L.profileCharacterLayout:format(UnitName("player") or "", ns.currentLayoutName or "—"))
    end
    deleteDropdown:SetupMenu(function(_, root)
        root:SetScrollMode(320)
        for _, name in ipairs(ns.GetProfileNames()) do
            if name ~= DEFAULT_PROFILE and name ~= PyresinQoLDB.profileStore.active then
                root:CreateRadio(ProfileLabel(name), function() return toDelete == name end, function()
                    toDelete = name
                    Refresh()
                end)
            end
        end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", Refresh)
    frame:SetScript("OnShow", Refresh)
    EventRegistry:RegisterCallback("PyresinQoL.ProfileChanged", Refresh, frame)
    Refresh()
    return frame
end
