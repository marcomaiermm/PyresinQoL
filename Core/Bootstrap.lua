local addonName, ns = ...

local events = CreateFrame("Frame")
local syncQueued, loggedIn = false, false
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "PLAYER_LOGIN" and not loggedIn then
        loggedIn = true
        -- Every addon listed under PyresinQoL has loaded and added its module by now.
        ns.InitializeAddonModules()
        ns.InitializeSettings()
    end
    if event ~= "ADDON_LOADED" then
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then ns.RecordLayoutCatalog() end
        if not syncQueued then
            syncQueued = true
            C_Timer.After(0, function()
                syncQueued = false
                ns.SyncLayoutProfile()
                ns.MaybePromptProfileReload()
            end)
        end
        return
    end
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    ns.InitializeProfiles()
    ns.InitializeDatabase()

    ns.InitializeModules()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end)
