local _, ns = ...
local YB = ns.YB

-- A frame border drawn outside the frame, in one of two styles:
--   "soft":    Media/Shadow.tga, a radial falloff. Its quadrants are the corners
--              and its centre row/column are stretched along the edges (a 9-slice
--              without the middle).
--   "outline": the same eight pieces as solid colour, i.e. a crisp outline.
local TEXTURE = YB.MEDIA .. "Shadow"

local PIECES = {
	-- texcoords into Shadow.tga: left, right, top, bottom
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

-- Adds the border textures to any frame (once). Returns the piece table.
function YB:CreateShadow(frame)
	if frame.yShadow then
		return frame.yShadow
	end
	local shadow = {}
	for key in pairs(PIECES) do
		shadow[key] = frame:CreateTexture(nil, "BACKGROUND")
	end
	anchor(shadow, frame)
	frame.yShadow = shadow
	return shadow
end

-- size <= 0 hides it. color is a { r, g, b, a } table; style is "soft" or "outline".
function YB:UpdateShadow(frame, size, color, style)
	local shadow = self:CreateShadow(frame)
	local show = size and size > 0
	local outline = style == "outline"
	for key, tex in pairs(shadow) do
		if show then
			if outline then
				tex:SetTexture(self.WHITE)
				tex:SetTexCoord(0, 1, 0, 1)
			else
				local c = PIECES[key]
				tex:SetTexture(TEXTURE)
				tex:SetTexCoord(c[1], c[2], c[3], c[4])
			end
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
