local _, ns = ...

-- Blizzard's StaticPopup frames are shared. Showing an addon dialog on them taints fields that native
-- code reads later (the guild window's StaticPopup_Hide then blocked C_Discord.IsUserOAuthed()), so
-- addon prompts use this frame. Definitions keep StaticPopup's shape and callback signatures.
ns.dialogs = {}

local dialog, text, input, accept, cancel

local function Call(name, owner)
    local handler = dialog.info and dialog.info[name]
    if handler then return handler(owner, dialog.data) end
end

local function Button()
    local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    button:SetSize(128, 21)
    return button
end

-- Created on first use, so disabled modules add no frames at login.
local function Create()
    dialog = CreateFrame("Frame", "PyresinQoLDialog", UIParent)
    dialog:SetSize(320, 100)
    dialog:SetPoint("TOP", 0, -135)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG") -- Above the settings window, which uses DIALOG.
    dialog:SetToplevel(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:Hide()
    CreateFrame("Frame", nil, dialog, "DialogBorderTemplate"):SetAllPoints()
    table.insert(UISpecialFrames, "PyresinQoLDialog")

    text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", 0, -16)
    text:SetWidth(290)
    input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    input:SetSize(240, 24)
    input:SetAutoFocus(false)
    accept, cancel = Button(), Button()

    function dialog:GetTextFontString() return text end
    function dialog:GetEditBox() return input end
    function dialog:GetButton1() return accept end
    function dialog:GetButton2() return cancel end

    accept:SetScript("OnClick", function()
        if not Call("OnAccept", dialog) then dialog:Hide() end
    end)
    cancel:SetScript("OnClick", function() dialog:Hide() end)
    input:SetScript("OnTextChanged", function(self) Call("EditBoxOnTextChanged", self) end)
    input:SetScript("OnEnterPressed", function(self) Call("EditBoxOnEnterPressed", self) end)
    input:SetScript("OnEscapePressed", function(self)
        if dialog.info.EditBoxOnEscapePressed then Call("EditBoxOnEscapePressed", self) else dialog:Hide() end
    end)
    dialog:SetScript("OnHide", function(self)
        input:ClearFocus()
        self.which, self.info, self.data = nil, nil, nil
    end)
end

function ns.ShowDialog(which, text1, text2, data)
    local info = assert(ns.dialogs[which], which)
    if not dialog then Create() end
    dialog:Hide()
    dialog.which, dialog.info, dialog.data = which, info, data
    text:SetText(info.text:format(text1, text2))
    accept:SetText(info.button1)
    accept:SetEnabled(true)
    cancel:SetShown(info.button2 ~= nil)
    cancel:SetText(info.button2 or "")
    input:SetShown(info.hasEditBox == true)
    input:SetMaxLetters(0)
    input:SetText("")
    dialog:Show()
    Call("OnShow", dialog)

    local y = -16 - text:GetStringHeight() - 12
    input:ClearAllPoints()
    if info.hasEditBox then
        input:SetPoint("TOP", 0, y)
        y = y - 24 - 12
    end
    accept:ClearAllPoints()
    cancel:ClearAllPoints()
    if info.button2 then
        accept:SetPoint("TOPRIGHT", dialog, "TOP", -6, y)
        cancel:SetPoint("TOPLEFT", dialog, "TOP", 6, y)
    else
        accept:SetPoint("TOP", 0, y)
    end
    dialog:SetHeight(-y + 21 + 16)
end
