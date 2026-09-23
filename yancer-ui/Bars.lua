local _, ns = ...
local YUI = ns.YUI

YUI.barFrames = {} -- barNum -> secure header. Frames can't be destroyed, so they are reused.

-- Action pages (12 slots each) and what the default UI uses them for.
YUI.PAGES = {
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

-- Same paging as Blizzard's main bar: possess/vehicle (page 11 = slots 121-132),
-- Shift+1-6 / Shift+wheel pages, then stance/form/stealth bonus bars.
local MAIN_PAGING = "[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
	.. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "

local function pageDriver(db)
	if db.paging then
		return MAIN_PAGING .. db.page
	end
	return tostring(db.page)
end

-- rawget avoids AceDB's "**" metatable creating an entry for an unknown id.
function YUI:GetBarDB(id)
	return rawget(self.db.profile.bars, id)
end

local function barNum(id)
	return tonumber(id:match("%d+"))
end

local function getHeader(id)
	local num = barNum(id)
	local header = YUI.barFrames[num]
	if header then
		return header
	end
	header = CreateFrame("Frame", "yancerUIBar" .. num, UIParent, "SecureHandlerStateTemplate")
	header:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	header.buttons = {}
	YUI:CreateMover(header, id, function(point, relPoint, x, y)
		local db = YUI:GetBarDB(id)
		db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
		YUI:UpdateBar(id)
		YUI:RefreshOptions()
	end)
	YUI.barFrames[num] = header
	return header
end

local function hideBar(header)
	UnregisterStateDriver(header, "visibility")
	UnregisterStateDriver(header, "page")
	header:Hide()
end

local function layoutButtons(header, db)
	local num = barNum(header.barId)
	local n = db.numButtons
	local perRow = math.min(db.perRow, n)
	local rows = math.ceil(n / perRow)
	local size, spacing, pad = db.buttonSize, db.spacing, db.padding

	header:SetWidth(pad * 2 + perRow * size + (perRow - 1) * spacing)
	header:SetHeight(pad * 2 + rows * size + (rows - 1) * spacing)

	for i = 1, YUI.MAX_BUTTONS do
		local button = header.buttons[i]
		if i <= n then
			button = button or YUI:GetButton(num, i)
			header.buttons[i] = button
			button:SetParent(header)
			button:SetFrameLevel(header:GetFrameLevel() + 2)
			button:ClearAllPoints()
			local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
			button:SetPoint("TOPLEFT", header, "TOPLEFT", pad + col * (size + spacing), -(pad + row * (size + spacing)))
			YUI:StyleButton(button, db)
			YUI:SetButtonGrid(button, db.showGrid)
		elseif button then
			button:SetParent(YUI.buttonParking)
		end
	end
end

function YUI:UpdateBar(id)
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
	self:UpdateShadow(header, db.shadow.enabled and db.shadow.size or 0, db.shadow.color)

	layoutButtons(header, db)

	-- Paging: the driver sets state-page, whose handler pushes the page to every button.
	local driver = pageDriver(db)
	RegisterStateDriver(header, "page", driver)
	header:SetAttribute("state-page", SecureCmdOptionParse(driver))
	header:Execute([[ control:ChildUpdate("page", self:GetAttribute("state-page")) ]])

	RegisterStateDriver(header, "visibility", db.hideInVehicle and "[vehicleui] hide; show" or "show")

	local mover = header.yMover
	mover.text:SetText(db.name)
	mover:SetFrameLevel(header:GetFrameLevel() + 10)
end

function YUI:UpdateAllBars()
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
end

-- Returns the new bar's id, or nil if all MAX_BARS slots are used.
function YUI:CreateBar(name, settings)
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
	local id = "bar" .. n
	local db = bars[id] -- indexing creates the entry filled from the "**" defaults
	name = name and strtrim(name) or ""
	db.name = name ~= "" and name or ("Bar " .. n)
	if settings then
		for k, v in pairs(settings) do
			db[k] = v
		end
	end

	self:UpdateBar(id)
	if not self.db.profile.locked then
		self.barFrames[n].yMover:Show()
	end
	self:RefreshOptions()
	return id
end

function YUI:DeleteBar(id)
	if InCombatLockdown() then
		self:Print("Can't delete bars in combat.")
		return
	end
	self.db.profile.bars[id] = nil
	self:UpdateBar(id)
	self:RefreshOptions()
end

-- The three bars a new profile starts with, stacked at the bottom centre.
function YUI:CreateDefaultBars()
	self:CreateBar("Main Bar", { page = 1, paging = true, y = 20 })
	self:CreateBar("Bar 2", { page = 6, y = 70 })
	self:CreateBar("Bar 3", { page = 5, y = 120 })
end
