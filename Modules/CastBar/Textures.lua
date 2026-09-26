local _, ns = ...
local castBar = ns.CastBar
local professions = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
    "Mining", "Skinning", "Tailoring", "Fishing",
}
-- Sources and reproducible loop generation: Media/CastBar/sources.json.
-- Match the source file and row count; unfamiliar client artwork stays native.
local loopRows = {
    [4683154] = 30, -- blacksmithing
    [4693223] = 37, -- enchanting
    [4693230] = 30, -- tailoring
    [4693237] = 22, -- jewelcrafting
    [4696956] = 30, -- alchemy
    [4696971] = 30, -- leatherworking
    [4872261] = 30, -- cooking
    [4881558] = 30, -- engineering
    [4872270] = 30, -- herbalism
    [4881612] = 30, -- fishing
    [4872264] = 30, -- inscription
    [4872225] = 30, -- mining
    [4872267] = 30, -- skinning
    [8176596] = 30, -- skinning_c60
    [8176598] = 37, -- enchanting_c60
    [8176600] = 30, -- alchemy_c60
}
local textures, byID

local function finite(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and value ~= math.huge and value ~= -math.huge
end

local function firstCell(info)
    if not info or not finite(info.width) or not finite(info.height)
        or info.width <= 0 or info.height < 34 or info.height % 34 ~= 0
        or not finite(info.leftTexCoord) or not finite(info.rightTexCoord)
        or not finite(info.topTexCoord) or not finite(info.bottomTexCoord)
        or info.leftTexCoord < 0 or info.rightTexCoord > 1
        or info.topTexCoord < 0 or info.bottomTexCoord > 1
        or info.leftTexCoord >= info.rightTexCoord or info.topTexCoord >= info.bottomTexCoord then
        return
    end
    local file = info.file or info.filename
    if issecretvalue and issecretvalue(file) then return end
    if (type(file) ~= "number" or not finite(file) or file <= 0)
        and (type(file) ~= "string" or file == "") then return end
    return file, info.leftTexCoord,
        info.leftTexCoord + (info.rightTexCoord - info.leftTexCoord) / 2,
        info.topTexCoord,
        info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) / (info.height / 34),
        info.height / 34
end

function castBar.GetTextures()
    if textures then return textures end
    textures = { { id = "default", name = ns.L.castBarNative, category = "default", supportsTint = true } }
    byID = { default = textures[1] }
    for _, descriptor in ipairs(castBar.ModelTextures) do
        textures[#textures + 1], byID[descriptor.id] = descriptor, descriptor
    end
    if not (C_Texture and C_Texture.GetAtlasInfo and Enum and Enum.Profession) then return textures end
    local names = ns.L.castBarProfession or {}
    for _, key in ipairs(professions) do
        if Enum.Profession[key] ~= nil then
            local atlas = "Skillbar_Fill_Flipbook_" .. key
            local info = C_Texture.GetAtlasInfo(atlas)
            local file, left, right, top, bottom, rows = firstCell(info)
            if file then
                local loopFrames = loopRows[file] == rows and info.width == 1712
                    and (rows * 2 - math.floor(rows * .3 + .5))
                local descriptor = {
                    id = key:lower(), name = "Professions: " .. (names[key] or key), category = "profession",
                    atlas = atlas, texture = file, supportsTint = true, flipBookRows = rows,
                    aspectRatio = 441 / 18, -- ProfessionsRankBarTemplate's displayed Fill size.
                    left = left, right = right, top = top, bottom = bottom,
                    loopTexture = loopFrames and ("Interface\\AddOns\\PyresinQoL\\Media\\CastBar\\Loop-" .. file .. ".blp") or nil,
                    loopFrames = loopFrames or nil,
                    loopDuration = loopFrames and (2 * loopFrames / (rows * 2)) or nil,
                }
                textures[#textures + 1] = descriptor
                byID[descriptor.id] = descriptor
            end
        end
    end
    return textures
end

function castBar.GetTexture(id)
    castBar.GetTextures()
    return byID[id] or byID.default
end

-- Static samples show the same left edge and height-scaled artwork as the live fill.
function castBar.PaintTexture(texture, descriptor, fraction, color)
    fraction = fraction or 1
    texture:SetVertexColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
    if descriptor.id == "default" then
        texture:SetAtlas("ui-castingbar-filling-standard")
        local left, top, _, bottom, right = texture:GetTexCoord()
        texture:SetTexCoord(left, left + (right - left) * fraction, top, bottom)
        return
    end
    local file = descriptor.texture
    if descriptor.media and LibStub then
        local media = LibStub("LibSharedMedia-3.0", true)
        file = media and media:HashTable("statusbar")[descriptor.media] or file
    end
    texture:SetTexture(file)
    local left, right, top, bottom = descriptor.left, descriptor.right, descriptor.top, descriptor.bottom
    if descriptor.aspectRatio and texture:GetHeight() > 0 then
        local artWidth = texture:GetHeight() * descriptor.aspectRatio
        -- Stop at the artwork's edge instead of sampling the adjacent atlas cell.
        local width = math.min(texture:GetWidth(), artWidth)
        texture:SetWidth(width)
        fraction = width / artWidth
    end
    texture:SetTexCoord(left, left + (right - left) * fraction, top, bottom)
    if descriptor.media == "Gradient" and file == descriptor.texture then
        -- Approximate the missing Fel base with native colors, including tinted samples.
        local r = color and color.r or descriptor.color[1]
        local g = color and color.g or descriptor.color[2]
        local b = color and color.b or descriptor.color[3]
        local right = .35 + .65 * fraction
        texture:SetGradient("HORIZONTAL", CreateColor(r * .35, g * .35, b * .35),
            CreateColor(r * right, g * right, b * right))
    elseif color and descriptor.media == "DGround" and file == descriptor.texture then
        texture:SetVertexColor(color.r * 175 / 255, color.g * 175 / 255, color.b * 175 / 255)
    elseif descriptor.color and not color then
        local first, last = descriptor.color, descriptor.color2 or descriptor.color
        local shade = descriptor.media == "DGround" and file == descriptor.texture and 175 / 255 or 1
        texture:SetGradient("HORIZONTAL", CreateColor(first[1] * shade, first[2] * shade, first[3] * shade),
            CreateColor((first[1] + (last[1] - first[1]) * fraction) * shade,
                (first[2] + (last[2] - first[2]) * fraction) * shade,
                (first[3] + (last[3] - first[3]) * fraction) * shade))
    end
end

function castBar.PaintBackground(texture, descriptor, opacity, nativeAlpha)
    local color = descriptor.background
    if color then
        castBar.PaintTexture(texture, descriptor, 1, { r = color[1], g = color[2], b = color[3] })
        texture:SetAlpha(opacity < 0 and color[4] or opacity)
    else
        texture:SetVertexColor(1, 1, 1)
        texture:SetAtlas("ui-castingbar-background")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAlpha(opacity < 0 and nativeAlpha or opacity)
    end
end

-- Keep the artwork stationary. The native fill reveals it through a mask;
-- stretching it to a pixel-rounded fill and recropping UVs each tick causes jitter.
local function stopTextureAnimation(frame)
    local animation = frame.pyresinCastAnimation
    if not animation then return end
    animation:Stop()
end

local function playTextureAnimation(frame)
    local texture, animation = frame.pyresinCastTexture, frame.pyresinCastAnimation
    if not texture:IsShown() or not animation.duration then return end
    -- Layout refreshes and consecutive casts retain the same forward phase.
    animation:Play(false, GetTime() % animation.duration)
end

function castBar.ClearTexture(frame)
    stopTextureAnimation(frame)
    if frame.pyresinCastAnimation then frame.pyresinCastAnimation.duration = nil end
    if frame.pyresinCastTexture then
        frame.pyresinCastTexture:Hide()
        frame.pyresinCastTexture:SetBlendMode("BLEND")
    end
    if frame.pyresinCastBackground then frame.pyresinCastBackground:Hide() end
    if frame.pyresinCastInterruptGloss then frame.pyresinCastInterruptGloss:Hide() end
    if frame.pyresinCastFill then
        frame.pyresinCastFill:SetAlpha(frame.pyresinCastFillAlpha)
        frame.pyresinCastFill = nil
    end
end

function castBar.ApplyTexture(frame, descriptor, color)
    if not descriptor or descriptor.id == "default" then return false end
    local fill = frame:GetStatusBarTexture()
    if not fill then return false end
    if not frame.pyresinCastTexture then
        local texture = frame:CreateTexture(nil, "ARTWORK")
        local mask = frame:CreateMaskTexture()
        mask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        texture:AddMaskTexture(mask)
        frame.pyresinCastTexture, frame.pyresinCastTextureMask = texture, mask
    end
    local texture = frame.pyresinCastTexture
    texture:ClearAllPoints()
    if descriptor.aspectRatio then
        -- Scale Blizzard's fixed Fill size by bar height; width only limits visibility.
        texture:SetPoint("LEFT", frame, "LEFT", 0, 0)
        texture:SetSize(frame:GetHeight() * descriptor.aspectRatio, frame:GetHeight())
    else
        texture:SetAllPoints(frame)
    end
    castBar.PaintTexture(texture, descriptor, nil, color)
    if descriptor.background then
        if not frame.pyresinCastBackground then
            frame.pyresinCastBackground = frame:CreateTexture(nil, "BACKGROUND")
            frame.pyresinCastBackground:SetAllPoints(frame)
        end
        castBar.PaintBackground(frame.pyresinCastBackground, descriptor, castBar.Get("backgroundOpacity"))
        frame.pyresinCastBackground:Show()
    end
    frame.pyresinCastTextureMask:SetAllPoints(fill)
    frame.pyresinCastFill, frame.pyresinCastFillAlpha = fill, fill:GetAlpha()
    texture:SetAlpha(frame.pyresinCastFillAlpha)
    fill:SetAlpha(0)
    texture:Show()
    return true
end

function castBar.AnimateTexture(frame, descriptor)
    if not descriptor.flipBookRows or not castBar.Get("animated") then return end
    local texture, animation = frame.pyresinCastTexture, frame.pyresinCastAnimation
    if not animation then
        animation = texture:CreateAnimationGroup()
        animation:SetLooping("REPEAT")
        local flipbook = animation:CreateAnimation("FlipBook")
        flipbook:SetOrder(1)
        flipbook:SetFlipBookColumns(2)
        flipbook:SetFlipBookFrameWidth(0)
        flipbook:SetFlipBookFrameHeight(0)
        frame.pyresinCastAnimation, frame.pyresinCastFlipBook = animation, flipbook
        frame:HookScript("OnHide", function() stopTextureAnimation(frame) end)
        frame:HookScript("OnShow", function() playTextureAnimation(frame) end)
    end
    if descriptor.loopTexture then
        texture:SetTexture(descriptor.loopTexture)
        texture:SetTexCoord(0, 1, 0, 1)
    else
        texture:SetAtlas(descriptor.atlas)
    end
    -- One ordinary BLEND pass preserves the artwork's color and coverage.
    texture:SetBlendMode("BLEND")
    texture:SetAlpha(frame.pyresinCastFillAlpha)
    animation.duration = descriptor.loopDuration or 2
    local flipbook = frame.pyresinCastFlipBook
    flipbook:SetDuration(animation.duration)
    flipbook:SetFlipBookRows(descriptor.loopTexture and 32 or descriptor.flipBookRows)
    flipbook:SetFlipBookFrames(descriptor.loopFrames or descriptor.flipBookRows * 2)
    playTextureAnimation(frame)
end

function castBar.ApplyInterruptStyle(frame)
    local texture = frame.pyresinCastTexture
    texture:SetVertexColor(1, 1, 1)
    -- Shade the existing pattern, with a dark lower edge and brighter red above.
    texture:SetGradient("VERTICAL", CreateColor(.58, .025, .045), CreateColor(1, .16, .18))
    local gloss = frame.pyresinCastInterruptGloss
    if not gloss then
        gloss = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        gloss:SetColorTexture(1, 1, 1)
        gloss:SetBlendMode("BLEND")
        gloss:SetGradient("VERTICAL", CreateColor(1, .65, .6, 0), CreateColor(1, .65, .6, .24))
        gloss:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        gloss:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        gloss:AddMaskTexture(frame.pyresinCastTextureMask)
        frame.pyresinCastInterruptGloss = gloss
    end
    gloss:SetHeight(math.min(4, frame:GetHeight() * .3))
    gloss:SetAlpha(frame.pyresinCastFillAlpha)
    gloss:Show()
end
