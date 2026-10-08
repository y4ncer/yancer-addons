local _, ns = ...
local YM, YB = ns.YM, ns.YB

-- Blizzard's minimap, movable (/yb move) and resizable, round or square, with
-- the zone name above it (in the PvP colour) and a clock below it. The mouse
-- wheel zooms, right-click opens the tracking menu. The tracking, mail, battleground/LFG and difficulty icons sit on
-- its corners. The whole MinimapCluster is anchored so the map centres on our
-- holder, which keeps Blizzard's own anchors inside it working.

local holder, border, zone, clock
local placing

local function db()
	return YM.db.profile
end

local function place()
	if not holder then
		return
	end
	placing = true
	MinimapCluster:ClearAllPoints()
	-- Minimap is anchored CENTER to the cluster's TOP, offset (9, -92).
	MinimapCluster:SetPoint("TOP", holder, "CENTER", -9, 92)
	placing = nil
end

local HIDE = { "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "GameTimeFrame", "MinimapToggleButton" }

local function hideButtons()
	for _, name in ipairs(HIDE) do
		local frame = _G[name]
		if frame then
			frame:Hide()
			frame:SetScript("OnShow", frame.Hide)
		end
	end
end

-- Corner icons, so they stay on the map at any size or shape.
local function placeIcons()
	local corners = {
		{ "MiniMapTracking", "TOPLEFT", -4, 4 },
		{ "MiniMapMailFrame", "TOPRIGHT", 4, 4 },
		{ "MiniMapInstanceDifficulty", "TOPRIGHT", 6, -24 },
		{ "MiniMapBattlefieldFrame", "BOTTOMLEFT", -4, -4 },
		{ "MiniMapLFGFrame", "BOTTOMLEFT", -4, -4 },
	}
	for _, c in ipairs(corners) do
		local frame = _G[c[1]]
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint(c[2], Minimap, c[2], c[3], c[4])
		end
	end
end

local ART = { "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag", "MinimapCompassTexture" }

local function applyShape()
	local square = db().shape == "square"
	if square then
		Minimap:SetMaskTexture(YB.WHITE)
		border:Show()
	else
		Minimap:SetMaskTexture("Textures\\MinimapMask")
		border:Hide()
	end
	for _, name in ipairs(ART) do
		local tex = _G[name]
		if tex then
			-- The round border only fits the default size.
			tex:SetAlpha((square or db().size ~= 140) and 0 or 1)
		end
	end
	-- Minimap button addons (LibDBIcon) ask for the shape.
	_G.GetMinimapShape = function()
		return square and "SQUARE" or "ROUND"
	end
end

local function updateZone()
	if not zone then
		return
	end
	zone:SetText(GetMinimapZoneText())
	local pvpType = GetZonePVPInfo()
	if pvpType == "sanctuary" then
		zone:SetTextColor(0.41, 0.8, 0.94)
	elseif pvpType == "arena" or pvpType == "combat" or pvpType == "hostile" then
		zone:SetTextColor(1, 0.1, 0.1)
	elseif pvpType == "friendly" then
		zone:SetTextColor(0.1, 1, 0.1)
	elseif pvpType == "contested" then
		zone:SetTextColor(1, 0.7, 0)
	else
		zone:SetTextColor(1, 0.82, 0)
	end
end

local function updateClock()
	local hour, minute
	if db().localTime then
		hour, minute = tonumber(date("%H")), tonumber(date("%M"))
	else
		hour, minute = GetGameTime()
	end
	clock.text:SetText(format("%d:%02d", hour, minute))
end

local function createClock()
	clock = CreateFrame("Button", nil, Minimap)
	clock:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	clock.text = clock:CreateFontString(nil, "OVERLAY")
	clock.text:SetFont(YB.FONT, 12, "OUTLINE")
	clock.text:SetPoint("CENTER")
	clock:SetWidth(50)
	clock:SetHeight(16)
	clock:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 2)
	clock:RegisterForClicks("AnyUp")
	clock:SetScript("OnClick", function()
		if ToggleCalendar then
			ToggleCalendar()
		end
	end)
	clock:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine("Clock")
		GameTooltip:AddDoubleLine("Local time", date("%H:%M"), 1, 1, 1, 1, 1, 1)
		local h, m = GetGameTime()
		GameTooltip:AddDoubleLine("Server time", format("%d:%02d", h, m), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddLine("Click for the calendar", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	clock:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	local elapsed = 1
	clock:SetScript("OnUpdate", function(_, e)
		elapsed = elapsed + e
		if elapsed >= 1 then
			elapsed = 0
			updateClock()
		end
	end)
end

function YM:EnableMinimap()
	holder = CreateFrame("Frame", "yancerMinimapHolder", UIParent)
	holder:SetFrameStrata("BACKGROUND")
	YB:CreateMover(holder, "Minimap", function(point, relPoint, x, y)
		YM:SavePosition(nil, point, relPoint, x, y)
		YM:UpdateMinimap()
	end, function()
		YB:OpenOptions("minimap", "minimap")
	end)

	border = CreateFrame("Frame", nil, Minimap)
	border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 1, -1)
	border:SetFrameLevel(math.max(Minimap:GetFrameLevel() - 1, 0))
	YB:SquareBackdrop(border, 0)
	YB:Outline(border)

	hooksecurefunc(MinimapCluster, "SetPoint", function()
		if not placing then
			place()
		end
	end)

	-- Zone name above the map, replacing Blizzard's zone button.
	MinimapZoneTextButton:Hide()
	MinimapZoneTextButton:SetScript("OnShow", MinimapZoneTextButton.Hide)
	zone = Minimap:CreateFontString(nil, "OVERLAY")
	zone:SetFont(YB.FONT, 13, "OUTLINE")
	zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 4)
	self:RegisterEvent("ZONE_CHANGED", updateZone)
	self:RegisterEvent("ZONE_CHANGED_INDOORS", updateZone)
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", updateZone)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", updateZone)

	createClock()
	-- Blizzard's clock (Blizzard_TimeManager) is replaced by ours.
	local function hideBlizzardClock()
		if TimeManagerClockButton then
			TimeManagerClockButton:Hide()
			TimeManagerClockButton:SetScript("OnShow", TimeManagerClockButton.Hide)
		end
	end
	hideBlizzardClock()
	self:RegisterEvent("ADDON_LOADED", function(_, name)
		if name == "Blizzard_TimeManager" then
			hideBlizzardClock()
		end
	end)

	-- Right-click anywhere on the map: the tracking menu (Repair, Food & Drink, ...)
	-- at the cursor. Left-click still pings.
	Minimap:SetScript("OnMouseUp", function(map, button)
		if button == "RightButton" then
			ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
		else
			Minimap_OnClick(map)
		end
	end)

	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", function(map, delta)
		local zoom = map:GetZoom() + (delta > 0 and 1 or -1)
		if zoom >= 0 and zoom < map:GetZoomLevels() then
			map:SetZoom(zoom)
		end
	end)
end

function YM:UpdateMinimap()
	if not holder then
		return
	end
	local p = db()
	Minimap:SetWidth(p.size)
	Minimap:SetHeight(p.size)
	MinimapCluster:SetScale(p.scale)
	holder:SetScale(p.scale)
	holder:SetWidth(p.size)
	holder:SetHeight(p.size)
	holder:ClearAllPoints()
	local point, relPoint, x, y = self:Position()
	holder:SetPoint(point, UIParent, relPoint, x, y)
	place()
	applyShape()
	placeIcons()
	if p.hideButtons then
		hideButtons()
	end
	-- The tracking button isn't needed with the right-click menu.
	if p.hideTracking then
		MiniMapTracking:Hide()
	else
		MiniMapTracking:Show()
	end
	if p.zoneText then
		zone:Show()
	else
		zone:Hide()
	end
	if p.clock then
		clock:Show()
	else
		clock:Hide()
	end
	updateZone()
	updateClock()
	-- The minimap only redraws its new size when the zoom changes.
	local zoom = Minimap:GetZoom()
	Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
	Minimap:SetZoom(zoom)
end
