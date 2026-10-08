local _, ns = ...
local YP, YB = ns.YP, ns.YB

-- 3.3.5 nameplates are unnamed children of WorldFrame: a frame with a health bar
-- and a cast bar (its two children) and a fixed set of regions (border, glow,
-- name, level, icons). There is no API for them, so new WorldFrame children are
-- checked for the nameplate border texture and then restyled: Blizzard's art is
-- hidden, the bars get a flat texture with a square border and are re-placed.
-- The client keeps updating the bars, texts and icons itself.

local plates = {} -- nameplate frame -> our parts
local roster = {} -- group member name -> class token

local CLASS_ICONS = "Interface\\WorldStateFrame\\Icons-Classes"

local function db()
	return YP.db.profile
end

-- The regions in a fixed order on 3.3.5, but sources disagree on some of them, so
-- the textures are told apart by their file instead.
local TEXTURES = {
	{ "Nameplate%-Border", "border" },
	{ "Nameplate%-CastBar%-Shield", "shield" },
	{ "Nameplate%-CastBar", "castBorder" },
	{ "Nameplate%-Glow", "highlight" },
	{ "TargetingFrame%-Flash", "threat" },
	{ "Skull", "boss" },
	{ "RaidTargetingIcons", "raid" },
	{ "EliteNameplateIcon", "elite" },
}

local function isNameplate(frame)
	if frame:GetName() then
		return false
	end
	local region = select(2, frame:GetRegions())
	return region and region:GetObjectType() == "Texture"
		and (region:GetTexture() or ""):find("Nameplate%-Border") ~= nil
end

local function squareBorder(bar)
	local bd = CreateFrame("Frame", nil, bar)
	bd:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	bd:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	bd:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
	YB:SquareBackdrop(bd, 0.7)
	YB:Outline(bd)
	return bd
end

local function shortValue(v)
	if v >= 1e6 then
		return format("%.1fm", v / 1e6)
	elseif v >= 1e4 then
		return format("%.1fk", v / 1e3)
	end
	return tostring(math.floor(v))
end

local function updateHealthText(p)
	local mode = db().healthText
	local hb = p.health
	local cur = hb:GetValue()
	local _, max = hb:GetMinMaxValues()
	if mode == "percent" and max > 0 then
		p.healthText:SetText(math.floor(cur / max * 100 + 0.5) .. "%")
	elseif mode == "current" then
		p.healthText:SetText(shortValue(cur))
	else
		p.healthText:SetText("")
	end
end

-- Player plates: the class from the group roster (friends), or from the health bar
-- colour when Blizzard colours enemy players by class.
local function plateClass(p)
	local name = p.name:GetText()
	if name and roster[name] then
		return roster[name]
	end
	local r, g, b = p.health:GetStatusBarColor()
	for class, c in pairs(RAID_CLASS_COLORS) do
		if math.abs(c.r - r) < 0.02 and math.abs(c.g - g) < 0.02 and math.abs(c.b - b) < 0.02 then
			return class
		end
	end
end

local function updateClassIcon(p)
	local coords = db().classIcons and CLASS_ICON_TCOORDS[plateClass(p) or ""]
	if coords then
		p.classIcon:SetTexCoord(coords[1] + 0.015, coords[2] - 0.015, coords[3] + 0.015, coords[4] - 0.015)
		p.classFrame:Show()
	else
		p.classFrame:Hide()
	end
end

local function placeCastBar(p)
	if p.placingCast then
		return
	end
	p.placingCast = true
	local s, cb = db(), p.cast
	cb:ClearAllPoints()
	cb:SetPoint("TOPLEFT", p.health, "BOTTOMLEFT", 0, -3)
	cb:SetPoint("TOPRIGHT", p.health, "BOTTOMRIGHT", 0, -3)
	cb:SetHeight(s.castHeight)
	local size = s.height + s.castHeight + 3
	p.spellIcon:ClearAllPoints()
	p.spellIcon:SetPoint("TOPRIGHT", p.health, "TOPLEFT", -3, 0)
	p.spellIcon:SetWidth(size)
	p.spellIcon:SetHeight(size)
	-- Not interruptible: grey bar (the client shows the shield region for it).
	if p.shield and p.shield:IsShown() then
		cb:SetStatusBarColor(0.6, 0.6, 0.6)
	else
		cb:SetStatusBarColor(1, 0.75, 0.1)
	end
	p.placingCast = nil
end

-- Size and position of every part. Called when a plate shows and on setting changes.
local function layout(p)
	local s = db()
	local hb = p.health
	hb:ClearAllPoints()
	hb:SetPoint("CENTER", p.frame, "CENTER", 0, 0)
	hb:SetWidth(s.width)
	hb:SetHeight(s.height)

	p.name:SetFont(YB.FONT, s.fontSize, "OUTLINE")
	p.name:ClearAllPoints()
	p.name:SetPoint("BOTTOM", hb, "TOP", 0, 3)
	p.name:SetWidth(s.width + 20)
	p.name:SetHeight(s.fontSize + 2)

	p.level:SetFont(YB.FONT, s.fontSize, "OUTLINE")
	p.level:ClearAllPoints()
	p.level:SetPoint("LEFT", hb, "RIGHT", 3, 0)
	p.level:SetAlpha(s.showLevel and 1 or 0)
	if p.boss then
		p.boss:ClearAllPoints()
		p.boss:SetPoint("LEFT", hb, "RIGHT", 3, 0)
		p.boss:SetWidth(s.height + 4)
		p.boss:SetHeight(s.height + 4)
	end
	if p.raid then
		p.raid:ClearAllPoints()
		p.raid:SetPoint("LEFT", hb, "RIGHT", 18, 0) -- past the level
		p.raid:SetWidth(18)
		p.raid:SetHeight(18)
	end

	p.healthText:SetFont(YB.FONT, math.max(s.fontSize - 1, 6), "OUTLINE")
	p.healthText:ClearAllPoints()
	p.healthText:SetPoint("RIGHT", hb, "RIGHT", -2, 0)

	p.classFrame:SetWidth(s.classIconSize)
	p.classFrame:SetHeight(s.classIconSize)
	-- Above the debuff row when it shows (Auras.lua), else above the name.
	p.classAnchor = nil
	ns.LayoutPlateAuras(p)

	placeCastBar(p)
	updateHealthText(p)
	updateClassIcon(p)
end

local function skin(frame)
	local hb, cb = frame:GetChildren()
	local p = { frame = frame, health = hb, cast = cb }
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "FontString" then
			if not p.name then
				p.name = region
			else
				p.level = region
			end
		else
			local file = region:GetTexture() or ""
			local key
			for _, t in ipairs(TEXTURES) do
				if file:find(t[1]) then
					key = t[2]
					break
				end
			end
			p[key or "spellIcon"] = p[key or "spellIcon"] or region
		end
	end
	-- Blizzard's art: invisible (the client shows some of it again, so not Hide).
	for _, key in ipairs({ "border", "castBorder", "shield", "highlight", "threat", "elite" }) do
		if p[key] then
			p[key]:SetTexture(nil)
		end
	end
	-- The shield is invisible now, but the client still shows/hides it: that tells
	-- whether the cast can be interrupted.

	hb:SetStatusBarTexture(YB.WHITE)
	cb:SetStatusBarTexture(YB.WHITE)
	p.healthBorder = squareBorder(hb)
	p.castBorderFrame = squareBorder(cb)
	if p.spellIcon then
		p.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		p.spellIcon:SetDrawLayer("OVERLAY")
		-- The icon belongs to the plate, so its border hangs off the cast bar (shown with it).
		local iconBorder = CreateFrame("Frame", nil, cb)
		iconBorder:SetPoint("TOPLEFT", p.spellIcon, "TOPLEFT", -1, 1)
		iconBorder:SetPoint("BOTTOMRIGHT", p.spellIcon, "BOTTOMRIGHT", 1, -1)
		YB:SquareBackdrop(iconBorder, 0)
		YB:Outline(iconBorder)
	end

	local overlay = CreateFrame("Frame", nil, hb)
	overlay:SetAllPoints(hb)
	overlay:SetFrameLevel(hb:GetFrameLevel() + 2)
	p.healthText = overlay:CreateFontString(nil, "OVERLAY")

	p.classFrame = CreateFrame("Frame", nil, frame)
	YB:SquareBackdrop(p.classFrame, 0.6)
	YB:Outline(p.classFrame)
	p.classIcon = p.classFrame:CreateTexture(nil, "ARTWORK")
	p.classIcon:SetPoint("TOPLEFT", 1, -1)
	p.classIcon:SetPoint("BOTTOMRIGHT", -1, 1)
	p.classIcon:SetTexture(CLASS_ICONS)
	p.classFrame:Hide()

	ns.CreatePlateAuras(p)

	frame:HookScript("OnShow", function()
		layout(p)
	end)
	-- Plates are reused for other units: forget which unit this was.
	frame:HookScript("OnHide", function()
		p.guid = nil
	end)
	hb:HookScript("OnValueChanged", function()
		updateHealthText(p)
	end)
	cb:HookScript("OnShow", function()
		placeCastBar(p)
	end)
	cb:HookScript("OnSizeChanged", function()
		placeCastBar(p)
	end)

	plates[frame] = p
	layout(p)
end

-- Border colour: white on the target, the threat colour when Blizzard would show
-- its glow, black otherwise.
local function updateBorder(p, hasTarget)
	local s = db()
	local r, g, b = 0, 0, 0
	if s.targetBorder and hasTarget and p.frame:GetAlpha() > 0.99 then
		r, g, b = 1, 1, 1
	elseif s.threatBorder and p.threat and p.threat:IsShown() then
		r, g, b = p.threat:GetVertexColor()
	end
	p.healthBorder:SetBackdropBorderColor(r, g, b, 1)
end

local numChildren = 0
local elapsedTotal = 0
local scanner = CreateFrame("Frame")

local function scan()
	local count = WorldFrame:GetNumChildren()
	if count ~= numChildren then
		for i = numChildren + 1, count do
			local child = select(i, WorldFrame:GetChildren())
			if child and not plates[child] and isNameplate(child) then
				skin(child)
			end
		end
		numChildren = count
	end
end

function YP:StartScanning()
	scanner:SetScript("OnUpdate", function(_, elapsed)
		scan()
		elapsedTotal = elapsedTotal + elapsed
		if elapsedTotal < 0.1 then
			return
		end
		elapsedTotal = 0
		local hasTarget = UnitExists("target")
		local hasMouseover = UnitExists("mouseover")
		for _, p in pairs(plates) do
			if p.frame:IsShown() then
				updateBorder(p, hasTarget)
				updateClassIcon(p)
				-- Which unit is this? Only the target's and the mouseover's plates can tell.
				local isTarget = hasTarget and p.frame:GetAlpha() > 0.99
				if isTarget then
					p.guid = UnitGUID("target")
				elseif hasMouseover and p.highlight and p.highlight:IsShown() then
					p.guid = UnitGUID("mouseover")
				end
				ns.UpdatePlateAuras(p, isTarget)
			end
		end
	end)
end

function YP:UpdateAllPlates()
	for _, p in pairs(plates) do
		layout(p)
	end
end

function YP:UpdateRoster()
	wipe(roster)
	local prefix, count = "party", GetNumPartyMembers()
	if GetNumRaidMembers() > 0 then
		prefix, count = "raid", GetNumRaidMembers()
	end
	for i = 1, count do
		local unit = prefix .. i
		local name = UnitName(unit)
		local _, class = UnitClass(unit)
		if name and class then
			roster[name] = class
		end
	end
	local _, class = UnitClass("player")
	roster[UnitName("player")] = class
	for _, p in pairs(plates) do
		if p.frame:IsShown() then
			updateClassIcon(p)
		end
	end
end
