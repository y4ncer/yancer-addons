local _, ns = ...
local YB = ns.YB

-- Media/Shadow.tga is a radial falloff. Its quadrants are used as the corners
-- and its centre row/column are stretched along the edges (a 9-slice without
-- the middle), so the shadow only ever draws outside the frame.
local TEXTURE = YB.MEDIA .. "Shadow"

local PIECES = {
	-- texcoords: left, right, top, bottom
	TOPLEFT     = { 0, 0.5, 0, 0.5 },
	TOPRIGHT    = { 0.5, 1, 0, 0.5 },
	BOTTOMLEFT  = { 0, 0.5, 0.5, 1 },
	BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
	TOP         = { 0.49, 0.51, 0, 0.5 },
	BOTTOM      = { 0.49, 0.51, 0.5, 1 },
	LEFT        = { 0, 0.5, 0.49, 0.51 },
	RIGHT       = { 0.5, 1, 0.49, 0.51 },
}

local function anchor(shadow, frame)
	shadow.TOPLEFT:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT")
	shadow.TOPRIGHT:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT")
	shadow.BOTTOMLEFT:SetPoint("TOPRIGHT", frame, "BOTTOMLEFT")
	shadow.BOTTOMRIGHT:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT")

	shadow.TOP:SetPoint("BOTTOMLEFT", frame, "TOPLEFT")
	shadow.TOP:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT")
	shadow.BOTTOM:SetPoint("TOPLEFT", frame, "BOTTOMLEFT")
	shadow.BOTTOM:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT")
	shadow.LEFT:SetPoint("TOPRIGHT", frame, "TOPLEFT")
	shadow.LEFT:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
	shadow.RIGHT:SetPoint("TOPLEFT", frame, "TOPRIGHT")
	shadow.RIGHT:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT")
end

-- Adds shadow textures to any frame (once). Returns the piece table.
function YB:CreateShadow(frame)
	if frame.yShadow then
		return frame.yShadow
	end
	local shadow = {}
	for key, c in pairs(PIECES) do
		local tex = frame:CreateTexture(nil, "BACKGROUND")
		tex:SetTexture(TEXTURE)
		tex:SetTexCoord(c[1], c[2], c[3], c[4])
		shadow[key] = tex
	end
	anchor(shadow, frame)
	frame.yShadow = shadow
	return shadow
end

-- size <= 0 hides the shadow. color is a { r, g, b, a } table.
function YB:UpdateShadow(frame, size, color)
	local shadow = self:CreateShadow(frame)
	local show = size and size > 0
	for key, tex in pairs(shadow) do
		if show then
			if key ~= "TOP" and key ~= "BOTTOM" then
				tex:SetWidth(size)
			end
			if key ~= "LEFT" and key ~= "RIGHT" then
				tex:SetHeight(size)
			end
			tex:SetVertexColor(color.r, color.g, color.b, color.a)
			tex:Show()
		else
			tex:Hide()
		end
	end
end
