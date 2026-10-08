local addonName, ns = ...

local events = CreateFrame("Frame")
local syncQueued = false
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, loadedAddon)
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
    ns.InitializeSettings()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end)
