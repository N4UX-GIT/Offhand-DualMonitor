--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/UserMedia.lua: Optional Background Studio media-package integration
--]]

local _, Offhand = ...

local UserMedia = {}
Offhand.UserMedia = UserMedia

local ADDON_NAME = "Offhand_UserMedia"
local SUPPORTED_SCHEMA = 2
local EXPECTED_TEXTURE = "Interface\\AddOns\\Offhand_UserMedia\\Textures\\Background.tga"
local VALID_FITS = { FILL = true, FIT = true, STRETCH = true }

local function BoundedNumber(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    if value < minimum or value > maximum then return nil end
    return value
end

local function PositiveInteger(value, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < 1 or value > maximum then return nil end
    return value
end

local function IsPowerOfTwo(value)
    if not value or value < 1 then return false end
    while value > 1 and value % 2 == 0 do value = value / 2 end
    return value == 1
end

local function GetMetadata(field)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if not getter then return nil end
    local ok, value = pcall(getter, ADDON_NAME, field)
    if not ok or value == nil or value == "" then return nil end
    return value
end

local function ReadPackageMetadata()
    local schema = GetMetadata("X-Offhand-Media-Schema")
    if schema == nil then return nil, "METADATA_NOT_FOUND" end
    if tonumber(schema) ~= SUPPORTED_SCHEMA then return nil, "LEGACY_OR_UNSUPPORTED_SCHEMA" end
    return {
        schema = schema,
        generatorVersion = GetMetadata("X-Offhand-Generator-Version"),
        texture = EXPECTED_TEXTURE,
        imageWidth = GetMetadata("X-Offhand-Image-Width"),
        imageHeight = GetMetadata("X-Offhand-Image-Height"),
        textureWidth = GetMetadata("X-Offhand-Texture-Width"),
        textureHeight = GetMetadata("X-Offhand-Texture-Height"),
        suggestedFit = GetMetadata("X-Offhand-Suggested-Fit"),
        zoom = GetMetadata("X-Offhand-Zoom"),
        focalX = GetMetadata("X-Offhand-Focal-X"),
        focalY = GetMetadata("X-Offhand-Focal-Y"),
        opacity = GetMetadata("X-Offhand-Opacity"),
        dim = GetMetadata("X-Offhand-Dim"),
        matte = GetMetadata("X-Offhand-Matte"),
    }
end

local function ValidatePackage(source)
    if type(source) ~= "table" then return nil, "NO_METADATA" end
    if tonumber(source.schema) ~= SUPPORTED_SCHEMA then return nil, "SCHEMA" end
    if source.texture ~= EXPECTED_TEXTURE then return nil, "TEXTURE_PATH" end

    local imageWidth = PositiveInteger(source.imageWidth, 4096)
    local imageHeight = PositiveInteger(source.imageHeight, 4096)
    local textureWidth = PositiveInteger(source.textureWidth, 4096)
    local textureHeight = PositiveInteger(source.textureHeight, 4096)
    if not imageWidth or not imageHeight or not textureWidth or not textureHeight
        or imageWidth > textureWidth or imageHeight > textureHeight
        or not IsPowerOfTwo(textureWidth) or not IsPowerOfTwo(textureHeight) then
        return nil, "DIMENSIONS"
    end

    local suggestedFit = tostring(source.suggestedFit or ""):upper()
    if not VALID_FITS[suggestedFit] then return nil, "FIT" end
    local matte = tostring(source.matte or ""):upper()
    if not matte:match("^#%x%x%x%x%x%x$") then return nil, "MATTE" end
    local generatorVersion = PositiveInteger(source.generatorVersion, 100000)
    local zoom = BoundedNumber(source.zoom, 1, 2)
    local focalX = BoundedNumber(source.focalX, 0, 1)
    local focalY = BoundedNumber(source.focalY, 0, 1)
    local opacity = BoundedNumber(source.opacity, 0.1, 1)
    local dim = BoundedNumber(source.dim, 0, 0.8)
    if not generatorVersion or not zoom or not focalX or not focalY or not opacity or not dim then
        return nil, "PRESENTATION"
    end

    return {
        schema = SUPPORTED_SCHEMA,
        generatorVersion = generatorVersion,
        texture = EXPECTED_TEXTURE,
        imageWidth = imageWidth,
        imageHeight = imageHeight,
        textureWidth = textureWidth,
        textureHeight = textureHeight,
        suggestedFit = suggestedFit,
        zoom = zoom,
        focalX = focalX,
        focalY = focalY,
        opacity = opacity,
        dim = dim,
        matte = matte,
    }
end

local function SetSolidColor(texture, r, g, b, a)
    if not texture then return end
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    elseif texture.SetTexture and texture.SetVertexColor then
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(r, g, b, a)
    end
end

local function HexColor(value)
    local hex = tostring(value or "#161922"):match("^#(%x%x%x%x%x%x)$") or "161922"
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end

function UserMedia:Refresh()
    local source, readReason = ReadPackageMetadata()
    self.installed = source ~= nil or readReason == "LEGACY_OR_UNSUPPORTED_SCHEMA"
    if not source then
        self.metadata = nil
        self.status = self.installed and "INVALID" or "MISSING"
        self.reason = readReason
        return false, self.status
    end

    local metadata, validationReason = ValidatePackage(source)
    self.metadata = metadata
    self.reason = validationReason
    self.status = metadata and "AVAILABLE" or "INVALID"
    return metadata ~= nil, self.status
end

function UserMedia:IsAvailable()
    return self.status == "AVAILABLE" and type(self.metadata) == "table"
end

function UserMedia:GetStatus()
    return self.status or "MISSING", self.reason, self.metadata
end

function UserMedia:GetFitMode()
    local configured = Offhand.db and tostring(Offhand.db.userMediaFitMode or "PACKAGE"):upper() or "PACKAGE"
    if configured ~= "PACKAGE" and VALID_FITS[configured] then return configured end
    return self.metadata and self.metadata.suggestedFit or "FILL"
end

function UserMedia:SetFitMode(mode)
    mode = tostring(mode or "PACKAGE"):upper()
    if mode ~= "PACKAGE" and not VALID_FITS[mode] then return false end
    if Offhand.db then Offhand.db.userMediaFitMode = mode end
    if Offhand.UpdateTheme then Offhand:UpdateTheme() end
    return true
end

function UserMedia:SetEnabled(enabled)
    if not Offhand.db then return false end
    if enabled and not self:IsAvailable() then self:Refresh() end
    if enabled and not self:IsAvailable() then
        Offhand.db.userMediaEnabled = false
        return false, self.status
    end
    Offhand.db.userMediaEnabled = enabled == true
    if Offhand.UpdateTheme then Offhand:UpdateTheme() end
    return Offhand.db.userMediaEnabled
end

function UserMedia:HideOnCanvas(canvas)
    if not canvas then return end
    if canvas.userMediaTexture and canvas.userMediaTexture.Hide then canvas.userMediaTexture:Hide() end
    if canvas.userMediaDimTexture and canvas.userMediaDimTexture.Hide then canvas.userMediaDimTexture:Hide() end
end

function UserMedia:ApplyToCanvas(canvas)
    if not canvas or not Offhand.db or Offhand.db.userMediaEnabled ~= true or not self:IsAvailable() then
        self:HideOnCanvas(canvas)
        return false
    end

    local media = self.metadata
    if not canvas.userMediaTexture and canvas.CreateTexture then
        canvas.userMediaTexture = canvas:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    if not canvas.userMediaDimTexture and canvas.CreateTexture then
        canvas.userMediaDimTexture = canvas:CreateTexture(nil, "BACKGROUND", nil, -6)
    end
    local texture = canvas.userMediaTexture
    local dimTexture = canvas.userMediaDimTexture
    if not texture or not dimTexture then return false end

    local matteR, matteG, matteB = HexColor(media.matte)
    SetSolidColor(canvas.bgTexture, matteR, matteG, matteB, 1)
    if texture.SetTexture then texture:SetTexture(media.texture) end
    if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
    if texture.SetAlpha then texture:SetAlpha(media.opacity) end

    local contentU = media.imageWidth / media.textureWidth
    local contentV = media.imageHeight / media.textureHeight
    local fit = self:GetFitMode()
    local canvasWidth = canvas.GetWidth and tonumber(canvas:GetWidth()) or 0
    local canvasHeight = canvas.GetHeight and tonumber(canvas:GetHeight()) or 0

    if texture.ClearAllPoints then texture:ClearAllPoints() end
    if fit == "FIT" and canvasWidth > 0 and canvasHeight > 0 then
        local scale = math.min(canvasWidth / media.imageWidth, canvasHeight / media.imageHeight)
        if texture.SetPoint then texture:SetPoint("CENTER", canvas, "CENTER", 0, 0) end
        if texture.SetSize then texture:SetSize(media.imageWidth * scale, media.imageHeight * scale) end
        if texture.SetTexCoord then texture:SetTexCoord(0, contentU, 0, contentV) end
    elseif fit == "FILL" and canvasWidth > 0 and canvasHeight > 0 then
        if texture.SetAllPoints then texture:SetAllPoints(canvas) end
        local sourceAspect = media.imageWidth / media.imageHeight
        local targetAspect = canvasWidth / canvasHeight
        local cropWidth, cropHeight = media.imageWidth, media.imageHeight
        if sourceAspect > targetAspect then cropWidth = media.imageHeight * targetAspect
        elseif sourceAspect < targetAspect then cropHeight = media.imageWidth / targetAspect end
        cropWidth = cropWidth / media.zoom
        cropHeight = cropHeight / media.zoom
        local left = (media.imageWidth - cropWidth) * media.focalX
        local top = (media.imageHeight - cropHeight) * media.focalY
        if texture.SetTexCoord then
            texture:SetTexCoord(left / media.textureWidth, (left + cropWidth) / media.textureWidth,
                top / media.textureHeight, (top + cropHeight) / media.textureHeight)
        end
    else
        if texture.SetAllPoints then texture:SetAllPoints(canvas) end
        if texture.SetTexCoord then texture:SetTexCoord(0, contentU, 0, contentV) end
    end

    if dimTexture.ClearAllPoints then dimTexture:ClearAllPoints() end
    if dimTexture.SetAllPoints then dimTexture:SetAllPoints(canvas) end
    SetSolidColor(dimTexture, 0, 0, 0, media.dim)
    if texture.Show then texture:Show() end
    if dimTexture.Show then dimTexture:Show() end
    return true
end

function UserMedia:GetDiagnostics()
    local media = self.metadata
    return {
        status = self.status or "MISSING",
        reason = self.reason,
        installed = self.installed == true,
        enabled = Offhand.db and Offhand.db.userMediaEnabled == true or false,
        schema = media and media.schema,
        generatorVersion = media and media.generatorVersion,
        fit = media and self:GetFitMode() or nil,
        imageWidth = media and media.imageWidth,
        imageHeight = media and media.imageHeight,
        textureWidth = media and media.textureWidth,
        textureHeight = media and media.textureHeight,
    }
end

function Offhand:InitializeUserMedia()
    UserMedia:Refresh()
end
