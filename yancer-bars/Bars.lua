local _, ns = ...
local YB = ns.YB

YB.barFrames = {} -- barNum -> secure header. Frames can't be destroyed, so they are reused.

-- Action pages (12 slots each) and what the default UI uses them for.
YB.PAGES = {
	[1] = "1 - Main Bar",
	[2] = "2 - Main Bar, page 2",
	[3] = "3 - Right Bar",
	[4] = "4 - Right Bar 2",
	[5] = "5 - Bottom Right Bar",
	[6] = "6 - Bottom Left Bar",
	[7] = "7 - Stance / Form 1",
	[8] = "8 - Stance / Form 2",
	[9] = "9 - Stance / Form 3",
	[10] = "10 - Stance / Form 4",
}

-- Blizzard's five action bars, recreated as the default layout. "toggle" is the
-- index of the matching Interface > ActionBars checkbox (SHOW_MULTI_ACTIONBAR_n).
YB.DEFAULT_BARS = {
	{ name = "Main Bar", page = 1, paging = true, y = 60 },
	{ name = "Bottom Left Bar", page = 6, y = 110, toggle = 1, frame = "MultiBarBottomLeft" },
	{ name = "Bottom Right Bar", page = 5, y = 160, toggle = 2, frame = "MultiBarBottomRight" },
	{ name = "Right Bar", page = 3, perRow = 1, point = "RIGHT", relPoint = "RIGHT", x = -6, y = 0,
		toggle = 3, frame = "MultiBarRight" },
	{ name = "Right Bar 2", page = 4, perRow = 1, point = "RIGHT", relPoint = "RIGHT", x = -56, y = 0,
		toggle = 4, frame = "MultiBarLeft" },
}

-- Same paging as Blizzard's main bar: possess/vehicle (page 11 = slots 121-132),
-- Shift+1-6 / Shift+wheel pages, then stance/form/stealth bonus bars.
local MAIN_PAGING = "[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
	.. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "

local function pageDriver(db)
	if not db.paging then
		return tostring(db.page)
	end
	local driver = MAIN_PAGING
	local _, class = UnitClass("player")
	if class == "ROGUE" and db.shadowDance then
		-- Shadow Dance is a rogue shapeshift form: page it like Stealth (page 7).
		driver = driver .. "[form:2/3] 7; "
	end
	return driver .. db.page
end

local function visibilityDriver(db)
	local rule
	if db.visibility == "combat" then
		rule = "[combat] show; hide"
	elseif db.visibility == "custom" and strtrim(db.visibilityCustom) ~= "" then
		rule = db.visibilityCustom
	else
		rule = "show"
	end
	if db.hideInVehicle then
		rule = "[vehicleui] hide; " .. rule
	end
	return rule
end

-- rawget avoids AceDB's "**" metatable creating an entry for an unknown id.
function YB:GetBarDB(id)
	return rawget(self.db.profile.bars, id)
end

local function barNum(id)
	return tonumber(id:match("%d+"))
end

local function getHeader(id)
	local num = barNum(id)
	local header = YB.barFrames[num]
	if header then
		return header
	end
	header = CreateFrame("Frame", "yancerBarsBar" .. num, UIParent, "SecureHandlerStateTemplate")
	header:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	header.buttons = {}
	YB:CreateMover(header, id, function(point, relPoint, x, y)
		local db = YB:GetBarDB(header.barId)
		db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
		YB:UpdateBar(header.barId)
		YB:RefreshOptions()
	end, function()
		YB:OpenOptions("bars", header.barId)
	end)
	YB.barFrames[num] = header
	return header
end

local function hideBar(header)
	UnregisterStateDriver(header, "visibility")
	UnregisterStateDriver(header, "page")
	header:Hide()
	header.active = nil
end

local function layoutButtons(header, db)
	local num = barNum(header.barId)
	local n = db.numButtons
	local perRow = math.min(db.perRow, n)
	local rows = math.ceil(n / perRow)
	local size, spacing, pad = db.buttonSize, db.spacing, db.padding
	local growUp = db.growth == "up"
	local rightToLeft = db.direction == "rtl"

	header:SetWidth(pad * 2 + perRow * size + (perRow - 1) * spacing)
	header:SetHeight(pad * 2 + rows * size + (rows - 1) * spacing)

	for i = 1, YB.MAX_BUTTONS do
		local button = header.buttons[i]
		if i <= n then
			button = button or YB:GetButton(num, i)
			header.buttons[i] = button
			button:SetParent(header)
			button:SetFrameLevel(header:GetFrameLevel() + 2)
			button:ClearAllPoints()
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			if rightToLeft then
				col = perRow - 1 - col
			end
			local x = pad + col * (size + spacing)
			local y = pad + row * (size + spacing)
			if growUp then
				button:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", x, y)
			else
				button:SetPoint("TOPLEFT", header, "TOPLEFT", x, -y)
			end
			YB:StyleButton(button, db)
			YB:SetButtonGrid(button, db.showGrid)
		elseif button then
			header.buttons[i] = nil
			button:SetParent(YB.buttonParking)
		end
	end
end

function YB:UpdateBar(id)
	if InCombatLockdown() then
		self.refreshPending = true
		return
	end
	local db = self:GetBarDB(id)
	local header = self.barFrames[barNum(id)]
	if not db or not db.enabled then
		if header then
			hideBar(header)
		end
		return
	end

	header = getHeader(id)
	header.barId = id
	header.db = db
	header.active = true
	header:ClearAllPoints()
	header:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	header:SetFrameStrata(db.strata)
	header:SetFrameLevel(db.level)

	local bs = db.borderSize
	header:SetBackdrop({
		bgFile = self.WHITE,
		edgeFile = bs > 0 and self.WHITE or nil,
		edgeSize = bs,
		insets = { left = bs, right = bs, top = bs, bottom = bs },
	})
	local bg, border = db.bgColor, db.borderColor
	header:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	header:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
	self:UpdateShadow(header, db.shadow.enabled and db.shadow.size or 0, db.shadow.color, db.shadowStyle)

	layoutButtons(header, db)

	-- Paging: the driver sets state-page, whose handler pushes the page to every button.
	local driver = pageDriver(db)
	RegisterStateDriver(header, "page", driver)
	header:SetAttribute("state-page", SecureCmdOptionParse(driver))
	header:Execute([[ control:ChildUpdate("page", self:GetAttribute("state-page")) ]])

	RegisterStateDriver(header, "visibility", visibilityDriver(db))

	local mover = header.yMover
	mover.text:SetText(db.name)
	mover:SetFrameLevel(header:GetFrameLevel() + 10)

	self:UpdateFade(header)
	self:UpdateTicker()
	self:UpdateBlizzardBindings()
end

function YB:UpdateAllBars()
	if InCombatLockdown() then
		self.refreshPending = true
		return
	end
	for _, header in pairs(self.barFrames) do
		hideBar(header)
	end
	for id in pairs(self.db.profile.bars) do
		self:UpdateBar(id)
	end
	self:UpdateTicker()
	self:UpdateBlizzardBindings()
end

-- Picks an action page no other bar uses, so a new bar doesn't mirror an existing one.
local PAGE_PREFERENCE = { 2, 7, 8, 9, 10, 1, 3, 4, 5, 6 }

local function freePage(bars)
	local used = {}
	for _, db in pairs(bars) do
		used[db.page] = true
	end
	for _, page in ipairs(PAGE_PREFERENCE) do
		if not used[page] then
			return page
		end
	end
	return 2
end

-- Returns the new bar's id, or nil if all MAX_BARS slots are used.
-- Without settings the bar gets an unused page and appears in the screen centre.
function YB:CreateBar(name, settings)
	if InCombatLockdown() then
		self:Print("Can't create bars in combat.")
		return
	end
	local bars = self.db.profile.bars
	local n = 1
	while rawget(bars, "bar" .. n) do
		n = n + 1
	end
	if n > self.MAX_BARS then
		self:Print("You can have at most " .. self.MAX_BARS .. " bars.")
		return
	end
	if not settings then
		settings = { page = freePage(bars), point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
	end
	local id = "bar" .. n
	local db = bars[id] -- indexing creates the entry filled from the "**" defaults
	name = name and strtrim(name) or ""
	db.name = name ~= "" and name or ("Bar " .. n)
	for k, v in pairs(settings) do
		db[k] = v
	end

	self:UpdateBar(id)
	if not self.db.profile.locked then
		self.barFrames[n].yMover:Show()
	end
	self:RefreshOptions()
	return id
end

function YB:DeleteBar(id)
	if InCombatLockdown() then
		self:Print("Can't delete bars in combat.")
		return
	end
	self.db.profile.bars[id] = nil
	self:UpdateBar(id)
	self:UpdateTicker()
	self:UpdateBlizzardBindings()
	self:RefreshOptions()
end

-- Creates each of Blizzard's bars whose action page no bar shows yet.
-- Returns how many were created.
function YB:CreateDefaultBars()
	local used = {}
	for _, db in pairs(self.db.profile.bars) do
		used[db.page] = true
	end
	local created = 0
	for _, def in ipairs(self.DEFAULT_BARS) do
		if not used[def.page] then
			local settings = {}
			for k, v in pairs(def) do
				if k ~= "name" and k ~= "toggle" and k ~= "frame" then
					settings[k] = v
				end
			end
			settings.blizzardToggle = def.toggle
			if self:CreateBar(def.name, settings) then
				created = created + 1
			end
		end
	end
	return created
end

local function pageHasActions(page)
	for i = 1, 12 do
		if HasAction((page - 1) * 12 + i) then
			return true
		end
	end
	return false
end

-- Run once per profile, shortly after login (action data and Blizzard's bar
-- settings are only reliable by then): default bars stay shown if Blizzard
-- showed them or they hold any spells, and are switched off otherwise.
function YB:MatchBlizzardBarVisibility()
	if InCombatLockdown() then
		return
	end
	local profile = self.db.profile
	profile.checkBlizzardBars = false
	for _, db in pairs(profile.bars) do
		local toggle = db.blizzardToggle
		if toggle then
			local def
			for _, d in ipairs(self.DEFAULT_BARS) do
				if d.toggle == toggle then
					def = d
				end
			end
			local frame = def and _G[def.frame]
			local blizzardShown = _G["SHOW_MULTI_ACTIONBAR_" .. toggle] or (frame and frame:IsShown())
			if not blizzardShown and not pageHasActions(db.page) then
				db.enabled = false
			end
		end
	end
	self:UpdateAllBars()
	self:RefreshOptions()
end
