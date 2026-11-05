-- Run from the addon directory: luajit tests/integration/editmode/dialog.lua
-- The options dialog of a custom Edit Mode display: named sections that fold, color swatches through
-- Blizzard's color picker, and greyed-out children.
local frames = {}
local function Object()
    return setmetatable({ shown = true, points = {} }, { __index = function() return function() end end })
end
local function Frame(kind, template)
    local frame = Object()
    frame.kind, frame.template, frame.scripts = kind, template, {}
    function frame:SetShown(value) self.shown = value end
    function frame:Show() self.shown = true end
    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:IsShown() return self.shown end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript(script, callback) self.scripts[script] = callback end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:CreateFontString()
        local text = Object()
        function text:SetText(value) self.text = value end
        function text:SetFontObject(value) self.font = value end
        return text
    end
    function frame:CreateTexture()
        local texture = Object()
        function texture:SetAtlas(atlas) self.atlas = atlas end
        return texture
    end
    function frame:SetColorRGB(r, g, b) self.color = { r, g, b } end
    return frame
end
function CreateFrame(kind, _, _, template)
    local frame = Frame(kind, template)
    if template == "EditModeSettingCheckboxTemplate" then
        frame.Label, frame.Button = frame:CreateFontString(), Frame("CheckButton")
        function frame.Button:SetChecked(value) self.checked = value end
    end
    frames[#frames + 1] = frame
    return frame
end
function CreateColorFromHexString(hex)
    local a, r, g, b = hex:match("(%x%x)(%x%x)(%x%x)(%x%x)")
    local function C(value) return tonumber(value, 16) / 255 end
    return { GetRGB = function() return C(r), C(g), C(b) end, GetRGBA = function() return C(r), C(g), C(b), C(a) end }
end
local picked
ColorPickerFrame = {
    SetupColorPickerAndShow = function(_, info) picked = info end,
    GetColorRGB = function() return 1, 0.5, 0 end,
    GetColorAlpha = function() return 0.25 end,
}
UIParent = {}
EventRegistry = { RegisterCallback = function() end }
EditModeManagerFrame = { ClearSelectedSystem = function() end }
EditModeSystemSettingsDialog = Frame()
MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }

local ns = { customEditModeDisplays = {} }
function ns.GetModule() return {} end
assert(loadfile("Modules/EditMode/CustomDisplay.lua"))("PyresinQoL", ns)
assert(loadfile("Settings/Controls.lua"))("PyresinQoL", ns)

local saved = { mode = "default", custom = "FF0000FF", text = true }
local options = {
    { key = "mode", label = "Mode", section = "Look", choices = { { "default", "Default" }, { "custom", "Custom" } } },
    { key = "custom", label = "Custom color", color = true, parent = "mode", parentValue = "custom" },
    { key = "text", label = "Show text", section = "Text" },
}
for _, option in ipairs(options) do
    option.setting = { SetValue = function(_, value) saved[option.key] = value end }
end
local function Get(key) return saved[key] end
local display = Frame()
display.Selection = Frame()
local Open = ns.CreateEditModeOptionsDialog(display, { name = "Test", options = options, Get = Get,
    IsEnabled = function(option) return ns.IsOptionEnabled(option, Get) end })
Open()
local dialog = display.Dialog
local headers, swatch, checkbox = {}, nil, nil
for _, frame in ipairs(frames) do
    if frame.kind == "Button" and frame.scripts.OnClick and not rawget(frame, "template") then headers[#headers + 1] = frame end
    if frame.template == "ColorSwatchTemplate" then swatch = frame end
    if frame.template == "EditModeSettingCheckboxTemplate" then checkbox = frame end
end
assert(#headers == 2 and headers[1].label.text == "Look" and headers[2].label.text == "Text")
assert(headers[1].arrow.atlas == "common-button-dropdown-open" and headers[2].arrow.atlas == "common-button-dropdown-closed",
    "The first section starts open, the others folded")
assert(not checkbox.shown, "A folded section hides its rows")
local closedHeight = dialog.height
headers[2].scripts.OnClick(headers[2])
assert(checkbox.shown and dialog.height == closedHeight + 34 and headers[2].arrow.atlas == "common-button-dropdown-open")
headers[1].scripts.OnClick(headers[1])
assert(dialog.height == closedHeight + 34 - 2 * 34, "Folding removes its rows' height")
headers[1].scripts.OnClick(headers[1])

-- Colors: the swatch shows the saved value; the picker writes "AARRGGBB" and Cancel restores it.
assert(swatch.color[3] == 1 and swatch.enabled == false, "A child of an unmet parent greys out")
saved.mode = "custom"
dialog:Refresh()
assert(swatch.enabled == true)
swatch.scripts.OnClick()
assert(picked.hasOpacity and picked.b == 1 and picked.opacity == 1)
picked.swatchFunc()
assert(saved.custom == "40FF8000", saved.custom)
picked.cancelFunc()
assert(saved.custom == "FF0000FF")
print("PASS: Edit Mode options dialog sections, folding, color swatches and greyed-out children")
