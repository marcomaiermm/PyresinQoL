local ns = PyresinQoL
local module = ns.GetModule("resourceBar")
local Get = module.GetResourceBarOption

-- A resource bar's view: Blizzard status bars on a background, each with a border, and a value text.
-- A plain bar has one cell. A segmented one (combo points) has a cell per point that is full once the
-- value reaches it, so even a restricted value fills them natively. Bars.lua feeds it.
local FLAT = "Interface\\Buttons\\WHITE8X8"
local SEGMENT_GAP = 2
local BORDERS = { none = 0, thin = 1, thick = 2 } -- physical pixels
local FILLS = { right = { "HORIZONTAL", false }, left = { "HORIZONTAL", true }, up = { "VERTICAL", false },
    down = { "VERTICAL", true } }
local ALIGNS = { left = { "LEFT", 4 }, center = { "CENTER", 0 }, right = { "RIGHT", -4 } }

function module.CreateResourceBarView(id)
    local view = { cells = {}, count = 0 }
    local frame = CreateFrame("Frame", "PyresinQoL" .. id:gsub("^%l", string.upper), UIParent)
    frame:SetMovable(true) -- for the Edit Mode mover
    frame:SetClampedToScreen(true)
    frame:Hide()
    view.frame = frame
    local overlay = CreateFrame("Frame", nil, frame) -- the text, above the cells and their borders
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 4)
    local text = overlay:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    view.text = text

    local function Cell()
        local cell = CreateFrame("StatusBar", nil, frame)
        cell:SetClipsChildren(true) -- Bars.lua's overlays end at the bar's end
        cell.background = cell:CreateTexture(nil, "BACKGROUND")
        cell.background:SetAllPoints()
        cell.border = CreateFrame("Frame", nil, cell, "BackdropTemplate")
        cell.border:SetAllPoints()
        cell.border:SetFrameLevel(cell:GetFrameLevel() + 2)
        return cell
    end

    -- Applies the options to count cells, filled with texture (a file or atlas) in r, g, b and opacity a.
    function view:Layout(count, texture, r, g, b, a)
        local width, height = Get(id .. "Width"), Get(id .. "Height")
        frame:SetSize(width, height)
        local orientation, reverse = unpack(FILLS[Get(id .. "Fill")] or FILLS.right)
        local vertical = orientation == "VERTICAL"
        local length = ((vertical and height or width) - SEGMENT_GAP * (count - 1)) / count
        self.length, self.vertical, self.reverse = length, vertical, reverse
        local background = CreateColorFromHexString(Get(id .. "Background"))
        local edge = (BORDERS[Get(id .. "Border")] or 0) * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
        -- Segments run in the fill direction, from the corner the fill starts at.
        local corner = vertical and (reverse and "TOPLEFT" or "BOTTOMLEFT") or (reverse and "TOPRIGHT" or "TOPLEFT")
        local sign = reverse and -1 or 1
        for index = 1, math.max(count, #self.cells) do
            local cell = self.cells[index]
            if not cell and index <= count then
                cell = Cell()
                self.cells[index] = cell
            end
            cell:SetShown(index <= count)
            if index <= count then
                local offset = (index - 1) * (length + SEGMENT_GAP) * sign
                cell:ClearAllPoints()
                cell:SetPoint(corner, frame, corner, vertical and 0 or offset, vertical and offset or 0)
                cell:SetSize(vertical and width or length, vertical and length or height)
                cell:SetOrientation(orientation)
                cell:SetReverseFill(reverse)
                cell:SetRotatesTexture(vertical)
                cell:SetStatusBarTexture(texture)
                cell:SetStatusBarColor(r, g, b, a or 1)
                cell.background:SetColorTexture(background:GetRGBA())
                cell.border:SetShown(edge > 0)
                if edge > 0 then
                    cell.border:SetBackdrop({ edgeFile = FLAT, edgeSize = edge })
                    cell.border:SetBackdropBorderColor(0, 0, 0, 1)
                end
                if count > 1 then cell:SetMinMaxValues(index - 1, index) end
            end
        end
        self.count = count

        text:SetShown(Get(id .. "Text") == true)
        local font, _, flags = text:GetFont()
        text:SetFont(font, Get(id .. "TextSize") or 12, flags)
        local align = ALIGNS[Get(id .. "TextAlign")] or ALIGNS.center
        text:ClearAllPoints()
        text:SetPoint(align[1], overlay, align[1], align[2], 0)
        text:SetJustifyH(align[1])
    end

    -- current and maximum may be restricted, so they only reach the native bars and text.
    function view:SetValue(current, maximum)
        if self.count == 1 then
            local interpolation = Get(id .. "Smooth") and Enum.StatusBarInterpolation.ExponentialEaseOut or nil
            self.cells[1]:SetMinMaxValues(0, maximum, interpolation)
            self.cells[1]:SetValue(current, interpolation)
        else
            for index = 1, self.count do self.cells[index]:SetValue(current) end
        end
    end

    return view
end
