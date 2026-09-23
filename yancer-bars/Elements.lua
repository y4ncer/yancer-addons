local _, ns = ...
local YB = ns.YB

-- Makes Blizzard's other UI elements movable. Each element gets a holder frame
-- (with the usual blue mover while unlocked) and its Blizzard frame is anchored
-- to that holder. Blizzard re-anchors several of these (the frame position
-- manager, vehicle UI, reputation updates, the pet bar's slide-in), so after any
-- Blizzard SetPoint on them we put them back. Stance/pet/possess/totem bars hold
-- secure buttons: those can only be re-anchored out of combat.
--
-- Element fields:
--   frames      Blizzard frames anchored to the holder (by global name)
--   anchor      point on the frame and the holder that are tied together
--   offset      { x, y } from the frame's anchor corner to its first button, so
--               the buttons (not the frame's padding) line up with the holder
--   size        { width, height } of the holder at scale 1
--   scaleFrames frames that get the scale (default: frames)
--   art         textures hidden while the element is managed
--   protected   true if the frames can't be moved in combat
--   guard       re-anchor after every Blizzard SetPoint on the frames
--   default     { point, relPoint, x, y } relative to UIParent

YB.ELEMENTS = {
	{ key = "xp", name = "Experience Bar", order = 1,
		frames = { "MainMenuExpBar", "MainMenuBarMaxLevelBar" }, anchor = "BOTTOM",
		scaleFrames = { "MainMenuExpBar", "MainMenuBarMaxLevelBar", "ExhaustionTick" },
		size = { 1024, 13 }, default = { "BOTTOM", "BOTTOM", 0, 2 } },
	{ key = "rep", name = "Reputation Bar", order = 2,
		frames = { "ReputationWatchBar" }, anchor = "BOTTOM", guard = true,
		size = { 1024, 13 }, default = { "BOTTOM", "BOTTOM", 0, 16 } },
	{ key = "buffs", name = "Buffs", order = 3,
		frames = { "ConsolidatedBuffs" }, anchor = "TOPRIGHT", guard = true,
		scaleFrames = { "ConsolidatedBuffs", "BuffFrame", "TemporaryEnchantFrame" },
		size = { 280, 70 }, default = { "TOPRIGHT", "TOPRIGHT", -180, -13 } },
	{ key = "debuffs", name = "Debuffs", order = 4,
		frames = {}, anchor = "TOPRIGHT", -- positioned in the DebuffButton_UpdateAnchors hook below
		size = { 280, 35 }, default = { "TOPRIGHT", "TOPRIGHT", -180, -120 } },
	{ key = "stance", name = "Stance Bar", order = 5,
		frames = { "ShapeshiftBarFrame" }, anchor = "BOTTOMLEFT", offset = { 10, 3 },
		art = { "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight" },
		protected = true, guard = true,
		size = { 250, 32 }, default = { "BOTTOM", "BOTTOM", -250, 214 } },
	{ key = "pet", name = "Pet Bar", order = 6,
		frames = { "PetActionBarFrame" }, anchor = "BOTTOMLEFT", offset = { 36, 2 },
		art = { "SlidingActionBarTexture0", "SlidingActionBarTexture1" },
		protected = true, guard = true,
		size = { 372, 32 }, default = { "BOTTOM", "BOTTOM", 60, 214 } },
	{ key = "possess", name = "Possess Bar", order = 7,
		frames = { "PossessBarFrame" }, anchor = "BOTTOMLEFT", offset = { 10, 3 },
		art = { "PossessBackground1", "PossessBackground2" },
		protected = true, guard = true,
		size = { 70, 32 }, default = { "BOTTOM", "BOTTOM", -250, 254 } },
	{ key = "totem", name = "Totem Bar", order = 8,
		frames = { "MultiCastActionBarFrame" }, anchor = "BOTTOMLEFT", offset = { 3, 3 },
		protected = true, guard = true,
		size = { 227, 35 }, default = { "BOTTOM", "BOTTOM", -250, 214 } },
	{ key = "micro", name = "Micro Menu", order = 9,
		frames = { "CharacterMicroButton" }, anchor = "BOTTOMLEFT", -- re-anchored when leaving a vehicle
		size = { 256, 38 }, default = { "BOTTOMRIGHT", "BOTTOMRIGHT", -200, 2 } },
	{ key = "bags", name = "Bags", order = 10,
		frames = { "MainMenuBarBackpackButton" }, anchor = "BOTTOMRIGHT",
		size = { 190, 40 }, default = { "BOTTOMRIGHT", "BOTTOMRIGHT", -4, 2 } },
	{ key = "cast", name = "Cast Bar", order = 11,
		frames = { "CastingBarFrame" }, anchor = "CENTER", guard = true,
		size = { 195, 13 }, default = { "BOTTOM", "BOTTOM", 0, 270 } },
}

local byKey = {}
for _, el in ipairs(YB.ELEMENTS) do
	byKey[el.key] = el
end
YB.ELEMENTS_BY_KEY = byKey

function YB:GetElementDB(key)
	return self.db.profile.elements[key]
end

local function frameList(names)
	local list = {}
	for _, name in ipairs(names or {}) do
		if _G[name] then
			list[#list + 1] = _G[name]
		end
	end
	return list
end

-- Anchors the element's frames to its holder. Returns false if it had to wait for combat to end.
local function place(el)
	if not el.active then
		return true
	end
	if el.protected and InCombatLockdown() then
		YB.elementsPending = true
		return false
	end
	local dx, dy = 0, 0
	if el.offset then
		dx, dy = -el.offset[1], -el.offset[2]
	end
	for _, frame in ipairs(el.frameObjs) do
		frame.yPlacing = true
		frame:ClearAllPoints()
		frame:SetPoint(el.anchor, el.holder, el.anchor, dx, dy)
		frame.yPlacing = nil
	end
	return true
end

local function getHolder(el)
	if el.holder then
		return el.holder
	end
	local holder = CreateFrame("Frame", "yancerBarsHolder_" .. el.key, UIParent)
	holder:SetFrameStrata("HIGH")
	YB:CreateMover(holder, el.name, function(point, relPoint, x, y)
		local db = YB:GetElementDB(el.key)
		db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
		YB:UpdateElement(el.key)
		YB:RefreshOptions()
	end, function()
		YB:OpenOptions("elements", el.key)
	end)
	el.holder = holder
	el.frameObjs = frameList(el.frames)

	if el.guard then
		for _, frame in ipairs(el.frameObjs) do
			hooksecurefunc(frame, "SetPoint", function(f)
				if not f.yPlacing then
					place(el)
				end
			end)
		end
	end
	return holder
end

function YB:UpdateElement(key)
	local el = byKey[key]
	local db = self:GetElementDB(key)
	if not db.enabled then
		-- Handing a frame back to Blizzard needs a /reload; just stop managing it.
		el.active = nil
		if el.holder then
			el.holder:Hide()
		end
		return
	end
	if el.protected and InCombatLockdown() then
		self.elementsPending = true
		return
	end

	local holder = getHolder(el)
	el.active = true
	local point, relPoint, x, y = db.point, db.relPoint, db.x, db.y
	if not point then
		point, relPoint, x, y = el.default[1], el.default[2], el.default[3], el.default[4]
	end
	local scale = db.scale
	holder:ClearAllPoints()
	holder:SetPoint(point, UIParent, relPoint, x, y)
	holder:SetWidth(el.size[1] * scale)
	holder:SetHeight(el.size[2] * scale)
	holder:Show()
	holder.yMover.text:SetText(el.name)

	for _, frame in ipairs(frameList(el.scaleFrames or el.frames)) do
		frame:SetScale(scale)
	end
	for _, name in ipairs(el.art or {}) do
		if _G[name] then
			_G[name]:SetAlpha(0)
		end
	end
	place(el)

	if key == "debuffs" then
		self:PlaceDebuffs()
	end
end

function YB:UpdateElements()
	self.elementsPending = nil
	for _, el in ipairs(self.ELEMENTS) do
		self:UpdateElement(el.key)
	end
end

-- Debuffs: Blizzard hangs the first debuff under the buffs. Put it on its holder instead.
local function placeDebuff(index)
	local el = byKey.debuffs
	local button = _G["DebuffButton" .. index]
	if not el.active or not button then
		return
	end
	button:SetScale(YB:GetElementDB("debuffs").scale)
	if index == 1 then
		button:ClearAllPoints()
		button:SetPoint("TOPRIGHT", el.holder, "TOPRIGHT")
	end
end

function YB:PlaceDebuffs()
	local i = 1
	while _G["DebuffButton" .. i] do
		placeDebuff(i)
		i = i + 1
	end
end

hooksecurefunc("DebuffButton_UpdateAnchors", function(buttonName, index)
	if buttonName == "DebuffButton" then
		placeDebuff(index)
	end
end)

-- Micro menu: the vehicle UI moves it into the vehicle bar and back. Only take
-- it back when it returns to the normal UI (skinName is nil then).
hooksecurefunc("VehicleMenuBar_MoveMicroButtons", function(skinName)
	if not skinName then
		place(byKey.micro)
	end
end)
