local _, ns = ...
local L = ns.L
local module = ns.GetModule("flyouts")

-- Blizzard's icon picker, as for macros and equipment sets, to name a flyout menu and choose its icon. The
-- question mark, first in its list, stands for no icon of its own, as it does for macros.
local QUESTION_MARK = 134400 -- INV_Misc_QuestionMark
local picker
-- The menu being edited, kept off Blizzard's frame: { name, icon, OnDone }.
local current

local function Create()
    picker = CreateFrame("Frame", "PyresinQoLFlyoutIconPicker", UIParent, "IconSelectorPopupFrameTemplate")
    picker:ClearAllPoints()
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:EnableMouse(true)
    picker:Hide()
    local box = picker.BorderBox
    local editBox, selected = box.IconSelectorEditBox, box.SelectedIconArea.SelectedIconButton
    local description = box.SelectedIconArea.SelectedIconText.SelectedIconDescription
    box.EditBoxHeaderText:SetText(L.flyoutsNamePrompt)
    picker.IconSelector:SetSelectedCallback(function(_, chosen)
        selected:SetIconTexture(chosen)
        description:SetText(ICON_SELECTION_CLICK)
        description:SetFontObject(GameFontHighlightSmall)
    end)
    picker:SetScript("OnShow", function(self)
        IconSelectorPopupFrameTemplateMixin.OnShow(self)
        self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
        self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
        editBox:SetText(current.name)
        editBox:HighlightText()
        editBox:SetFocus()
        self.IconSelector:SetSelectedIndex(current.icon and self:GetIndexOfIcon(current.icon) or 1)
        selected:SetIconTexture(current.icon or QUESTION_MARK)
        -- Lists the new data provider's icons; it is made on each show and released on hide.
        self.IconSelector:SetSelectionsDataProvider(GenerateClosure(self.GetIconByIndex, self),
            GenerateClosure(self.GetNumIcons, self))
        self.IconSelector:ScrollToSelectedIndex()
        self:SetSelectedIconText()
    end)
    picker:SetScript("OnHide", function(self)
        IconSelectorPopupFrameTemplateMixin.OnHide(self)
        self.iconDataProvider:Release()
        self.iconDataProvider = nil
    end)
    function picker:OkayButton_OnClick()
        local icon = selected:GetIconTexture()
        self:Hide()
        current.OnDone(editBox:GetText(), icon ~= QUESTION_MARK and icon or nil)
    end
end

-- Opens the picker on a menu's name and icon (nil for none); OK passes the chosen ones to OnDone(name, icon).
function module.OpenFlyoutEditor(name, icon, OnDone)
    if not picker then Create() end
    picker:Hide()
    current = { name = name, icon = icon, OnDone = OnDone }
    picker:Show()
end
