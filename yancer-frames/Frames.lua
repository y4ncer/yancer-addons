local _, ns = ...
local YF, YB = ns.YF, ns.YB

-- One custom frame per unit: a SecureUnitButton (left-click targets,
-- right-click opens Blizzard's unit menu) with health and power bars, name,
-- level and value texts, a portrait, and status icons. Auras (Auras.lua) sit
-- above it and the cast bar (CastBar.lua) below it.

local DROPDOWNS = {
	player = "PlayerFrameDropDown",
	target = "TargetFrameDropDown",
	focus = "FocusFrameDropDown",
}

local PVP_TEXCOORD = { 0, 0.6, 0, 0.6 } -- the emblem sits in the top-left of the 64x64 art
local CLASS_ICONS = "Interface\\WorldStateFrame\\Icons-Classes"

-- PvP trinket and Every Man for Himself: 2 minute cooldown, tracked on arena enemies.
-- 3.3.5's UNIT_SPELLCAST_SUCCEEDED gives the spell name, not its id.
local TRINKET_COOLDOWN = 120
local TRINKET_SPELLS = {}
for _, id in ipairs({ 42292, 59752 }) do
	local name = GetSpellInfo(id)
	if name then
		TRINKET_SPELLS[name] = true
	end
end

local function groupOf(unit)
	return unit:match("^(%a+)%d$")
end

-- Party members out of range fade (UnitInRange: about 40 yards). SetAlpha is
-- allowed on secure frames in combat.
local function rangeUpdate(f, elapsed)
	f.rangeElapsed = (f.rangeElapsed or 0) + elapsed
	if f.rangeElapsed < 0.2 then
		return
	end
	f.rangeElapsed = 0
	if YF:GetUnitDB(f.unit).rangeFade and UnitExists(f.unit) and not UnitInRange(f.unit) then
		f:SetAlpha(0.45)
	else
		f:SetAlpha(1)
	end
end

local function shortValue(v)
	if v >= 1e6 then
		return format("%.1fm", v / 1e6)
	elseif v >= 1e4 then
		return format("%.1fk", v / 1e3)
	end
	return tostring(v)
end

local function createBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(YB.WHITE)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetTexture(YB.WHITE)
	return bar
end

local function createText(parent, justify)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(YB.FONT, 11, "OUTLINE")
	text:SetJustifyH(justify)
	return text
end

local function createFrame(unit)
	local f = CreateFrame("Button", "yancerFrames" .. YF.FRAME_NAMES[unit], UIParent, "SecureUnitButtonTemplate")
	local group = groupOf(unit)
	f.unit = unit
	f.group = group
	f:SetAttribute("unit", unit)
	f:SetAttribute("*type1", "target")
	if group == "arena" then
		f:SetAttribute("*type2", "focus") -- arena enemies have no unit menu: right-click focuses
	else
		f:SetAttribute("*type2", "menu")
	end
	local dropdown = DROPDOWNS[unit] or ("PartyMemberFrame" .. (unit:match("^party(%d)$") or "") .. "DropDown")
	f.menu = function()
		if _G[dropdown] then
			ToggleDropDownMenu(1, nil, _G[dropdown], "cursor")
		end
	end
	-- Shown while the unit exists. Party frames can also hide in raids.
	function f:Watch()
		if group == "party" and YF:GetUnitDB(unit).hideInRaid then
			RegisterStateDriver(self, "visibility", "[group:raid] hide; [target=" .. unit .. ",exists] show; hide")
		else
			RegisterUnitWatch(self)
		end
	end
	function f:Unwatch()
		UnregisterUnitWatch(self)
		UnregisterStateDriver(self, "visibility")
	end
	if group == "party" then
		f:SetScript("OnUpdate", rangeUpdate)
	end
	f:RegisterForClicks("AnyUp")
	f:SetScript("OnEnter", UnitFrame_OnEnter)
	f:SetScript("OnLeave", UnitFrame_OnLeave)
	f:SetFrameStrata("LOW")
	-- Click-casting addons (e.g. Clique) pick frames up from this table.
	_G.ClickCastFrames = _G.ClickCastFrames or {}
	_G.ClickCastFrames[f] = true

	YB:Outline(f)

	f.health = createBar(f)
	f.power = createBar(f)

	f.portrait2d = f:CreateTexture(nil, "ARTWORK")
	f.portrait3d = CreateFrame("PlayerModel", nil, f)
	f.portrait3d:SetScript("OnShow", function(model)
		model:SetCamera(0)
	end)

	-- Texts and icons sit on their own layer above the bars.
	local overlay = CreateFrame("Frame", nil, f)
	overlay:SetAllPoints(f)
	overlay:SetFrameLevel(f:GetFrameLevel() + 5)
	f.overlay = overlay
	f.nameText = createText(overlay, "LEFT")
	f.healthText = createText(overlay, "RIGHT")
	f.powerText = createText(overlay, "RIGHT")

	f.pvpIcon = overlay:CreateTexture(nil, "OVERLAY")
	f.pvpIcon:SetTexCoord(unpack(PVP_TEXCOORD))
	f.raidIcon = overlay:CreateTexture(nil, "OVERLAY")
	f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	f.leaderIcon = overlay:CreateTexture(nil, "OVERLAY")
	f.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	f.statusIcon = overlay:CreateTexture(nil, "OVERLAY")
	f.statusIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")

	if group == "arena" then
		local trinket = CreateFrame("Frame", nil, f)
		YB:SquareBackdrop(trinket, 0.6)
		YB:Outline(trinket)
		trinket.icon = trinket:CreateTexture(nil, "ARTWORK")
		trinket.icon:SetPoint("TOPLEFT", 1, -1)
		trinket.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		trinket.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		trinket.cooldown = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
		trinket.cooldown:SetAllPoints(trinket.icon)
		f.trinket = trinket
	end

	if unit == "target" then
		f.combo = {}
		for i = 1, 5 do
			local point = CreateFrame("Frame", nil, f)
			YB:SquareBackdrop(point, 1)
			point:SetBackdropColor(1, 0.8, 0.1, 1)
			point:Hide()
			f.combo[i] = point
		end
	end

	-- Auras are anchored to this, above the frame (and above the combo points).
	f.auraAnchor = CreateFrame("Frame", nil, f)
	f.auraAnchor:SetHeight(1)

	YF:CreateCastBar(f)

	-- Group members are moved by their group's holder.
	if not group then
		YB:CreateMover(f, YF.UNIT_NAMES[unit], function(point, relPoint, x, y)
			local db = YF:GetUnitDB(unit)
			db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
			YF:LayoutFrame(unit)
			YB:NotifyOptionsChanged()
		end, function()
			YB:OpenOptions("frames", unit)
		end)
	end

	YF.frames[unit] = f
	return f
end

-- Size, position and the arrangement of every part. Out of combat only.
function YF:LayoutFrame(unit)
	local db = self:GetUnitDB(unit)
	local profile = self.db.profile
	local f = self.frames[unit] or createFrame(unit)

	local barsHeight = db.healthHeight + (db.showPower and (db.powerHeight + 1) or 0)
	local portraitSize = db.portrait ~= "none" and barsHeight or 0
	local portraitLeft = db.portraitSide ~= "right"

	f:SetScale(db.scale)
	f:SetWidth(db.width)
	f:SetHeight(barsHeight + 2)
	f:ClearAllPoints()
	if f.group then
		local index = tonumber(unit:match("(%d)$"))
		f:SetPoint("TOPLEFT", self.holders[f.group], "TOPLEFT", 0, -(index - 1) * (barsHeight + 2 + db.spacing))
	else
		local d = self.db.defaults.profile.units[unit]
		f:SetPoint(db.point or d.point, UIParent, db.relPoint or d.relPoint, db.x or d.x, db.y or d.y)
	end
	YB:SquareBackdrop(f, profile.bgAlpha)

	-- Bars fill the space next to the portrait (1px gaps show the dark background).
	local left, right = 1, 1
	if portraitSize > 0 then
		if portraitLeft then
			left = portraitSize + 2
		else
			right = portraitSize + 2
		end
	end
	f.health:ClearAllPoints()
	f.health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -1)
	f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, -1)
	f.health:SetHeight(db.healthHeight)
	f.power:ClearAllPoints()
	f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -1)
	f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -1)
	f.power:SetHeight(db.powerHeight)
	if db.showPower then
		f.power:Show()
	else
		f.power:Hide()
	end

	for _, portrait in ipairs({ f.portrait2d, f.portrait3d }) do
		portrait:ClearAllPoints()
		portrait:SetWidth(portraitSize)
		portrait:SetHeight(portraitSize)
		if portraitLeft then
			portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		else
			portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		end
	end
	f.portrait2d:SetTexCoord(0.15, 0.85, 0.15, 0.85)

	-- Texts
	local size = profile.fontSize
	f.nameText:SetFont(YB.FONT, size, "OUTLINE")
	f.healthText:SetFont(YB.FONT, size, "OUTLINE")
	f.powerText:SetFont(YB.FONT, math.max(size - 2, 6), "OUTLINE")
	f.nameText:ClearAllPoints()
	f.nameText:SetPoint("LEFT", f.health, "LEFT", 4, 0)
	f.nameText:SetWidth(math.max(db.width - portraitSize - 80, 30))
	f.nameText:SetHeight(size + 2)
	f.healthText:ClearAllPoints()
	f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -4, 0)
	f.powerText:ClearAllPoints()
	f.powerText:SetPoint("RIGHT", f.power, "RIGHT", -4, 0)

	-- Icons: the PvP flag on the portrait's outer corner, raid mark on top.
	f.pvpIcon:SetWidth(24)
	f.pvpIcon:SetHeight(24)
	f.pvpIcon:ClearAllPoints()
	if portraitLeft then
		f.pvpIcon:SetPoint("CENTER", f, "TOPLEFT", 0, 0)
	else
		f.pvpIcon:SetPoint("CENTER", f, "TOPRIGHT", 0, 0)
	end
	f.raidIcon:SetWidth(18)
	f.raidIcon:SetHeight(18)
	f.raidIcon:ClearAllPoints()
	f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 0)
	f.leaderIcon:SetWidth(14)
	f.leaderIcon:SetHeight(14)
	f.leaderIcon:ClearAllPoints()
	f.leaderIcon:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 2, -6)
	f.statusIcon:SetWidth(18)
	f.statusIcon:SetHeight(18)
	f.statusIcon:ClearAllPoints()
	f.statusIcon:SetPoint("CENTER", f, portraitLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)

	-- Combo points: a row of five squares just above the frame.
	local auraOffset = 4
	if f.combo then
		local gap = 2
		local w = (db.width - gap * 4) / 5
		for i, point in ipairs(f.combo) do
			point:SetWidth(w)
			point:SetHeight(6)
			point:ClearAllPoints()
			point:SetPoint("BOTTOMLEFT", f, "TOPLEFT", (i - 1) * (w + gap), 4)
		end
		if db.showComboPoints then
			auraOffset = 14
		end
	end
	f.auraAnchor:ClearAllPoints()
	f.auraAnchor:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, auraOffset)
	f.auraAnchor:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, auraOffset)

	-- Arena trinket: a square on the side away from the portrait, outside the frame.
	if f.trinket then
		local t = f.trinket
		t:SetWidth(barsHeight + 2)
		t:SetHeight(barsHeight + 2)
		t:ClearAllPoints()
		if portraitLeft then
			t:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
		else
			t:SetPoint("TOPRIGHT", f, "TOPLEFT", -3, 0)
		end
	end

	self:LayoutCastBar(f, db)
	if f.yMover then
		f.yMover:SetFrameLevel(f:GetFrameLevel() + 20)
	end
end

-- A group's holder carries the mover and covers all its members.
function YF:LayoutGroup(group)
	local db = self:GetUnitDB(group)
	local units = self.GROUP_UNITS[group]
	local holder = self.holders[group]
	if not holder then
		holder = CreateFrame("Frame", "yancerFrames" .. self.UNIT_NAMES[group], UIParent)
		holder:SetFrameStrata("LOW")
		YB:CreateMover(holder, self.UNIT_NAMES[group], function(point, relPoint, x, y)
			local d = YF:GetUnitDB(group)
			d.point, d.relPoint, d.x, d.y = point, relPoint, x, y
			YF:LayoutGroup(group)
			YB:NotifyOptionsChanged()
		end, function()
			YB:OpenOptions("frames", group)
		end)
		self.holders[group] = holder
	end
	local frameHeight = db.healthHeight + (db.showPower and (db.powerHeight + 1) or 0) + 2
	local d = self.db.defaults.profile.units[group]
	holder:SetScale(db.scale)
	holder:SetWidth(db.width)
	holder:SetHeight(#units * frameHeight + (#units - 1) * db.spacing)
	holder:ClearAllPoints()
	holder:SetPoint(db.point or d.point, UIParent, db.relPoint or d.relPoint, db.x or d.x, db.y or d.y)
	holder:Show()
	for _, unit in ipairs(units) do
		self:LayoutFrame(unit)
		if not self.testMode then
			local f = self.frames[unit]
			f:Unwatch()
			f:Watch()
		end
	end
	holder.yMover:SetFrameLevel(self.frames[units[1]]:GetFrameLevel() + 20)
end

-- Updates

local function sample(f)
	-- Test mode without a real unit: show sample values so the layout can be judged.
	return YF.testMode and not UnitExists(f.unit)
end

local function healthColor(unit, db)
	if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then
		return 0.5, 0.5, 0.5
	end
	if UnitIsPlayer(unit) then
		if db.classColor then
			local _, class = UnitClass(unit)
			local c = class and RAID_CLASS_COLORS[class]
			if c then
				return c.r, c.g, c.b
			end
		end
	else
		if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
			return 0.5, 0.5, 0.5
		end
		if db.reactionColor then
			local c = FACTION_BAR_COLORS[UnitReaction(unit, "player") or 4]
			if c then
				return c.r, c.g, c.b
			end
		end
	end
	local c = db.healthColor
	return c.r, c.g, c.b
end

function YF:UpdateHealth(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	local cur, max, r, g, b
	if sample(f) then
		cur, max = 7500, 10000
		local _, class = UnitClass("player")
		local c = RAID_CLASS_COLORS[class]
		r, g, b = c.r, c.g, c.b
	else
		cur, max = UnitHealth(unit), UnitHealthMax(unit)
		r, g, b = healthColor(unit, db)
	end
	f.health:SetMinMaxValues(0, max > 0 and max or 1)
	f.health:SetValue(cur)
	f.health:SetStatusBarColor(r, g, b)
	f.health.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 1)

	local text
	if not sample(f) and not UnitIsConnected(unit) then
		text = "Offline"
	elseif not sample(f) and UnitIsGhost(unit) then
		text = "Ghost"
	elseif not sample(f) and UnitIsDead(unit) then
		text = "Dead"
	else
		local mode = db.healthText
		local pct = max > 0 and math.floor(cur / max * 100 + 0.5) or 0
		if mode == "current" then
			text = shortValue(cur)
		elseif mode == "percent" then
			text = pct .. "%"
		elseif mode == "both" then
			text = shortValue(cur) .. " | " .. pct .. "%"
		elseif mode == "deficit" then
			text = cur < max and ("-" .. shortValue(max - cur)) or ""
		else
			text = ""
		end
	end
	f.healthText:SetText(text)
end

function YF:UpdatePower(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	if not db.showPower then
		return
	end
	local cur, max, c
	if sample(f) then
		cur, max, c = 60, 100, PowerBarColor.ENERGY
	else
		local _, token = UnitPowerType(unit)
		cur, max = UnitPower(unit), UnitPowerMax(unit)
		c = PowerBarColor[token] or PowerBarColor.MANA
	end
	f.power:SetMinMaxValues(0, max > 0 and max or 1)
	f.power:SetValue(cur)
	f.power:SetStatusBarColor(c.r, c.g, c.b)
	f.power.bg:SetVertexColor(c.r * 0.25, c.g * 0.25, c.b * 0.25, 1)

	local text = ""
	if max > 0 then
		if db.powerText == "current" then
			text = shortValue(cur)
		elseif db.powerText == "percent" then
			text = math.floor(cur / max * 100 + 0.5) .. "%"
		end
	end
	f.powerText:SetText(text)
end

local CLASSIFICATION = { elite = "+", rare = " R", rareelite = " R+", worldboss = " B" }

function YF:UpdateName(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	local name, level, classification
	if sample(f) then
		name, level = YF.UNIT_NAMES[unit], 80
	else
		name, level, classification = UnitName(unit), UnitLevel(unit), UnitClassification(unit)
	end
	local text = db.showName and (name or "") or ""
	if db.showLevel and level then
		local c = GetQuestDifficultyColor(level > 0 and level or 999)
		local levelText = level > 0 and tostring(level) or "??"
		levelText = levelText .. (CLASSIFICATION[classification] or "")
		text = format("|cff%02x%02x%02x%s|r %s", c.r * 255, c.g * 255, c.b * 255, levelText, text)
	end
	f.nameText:SetText(text)
end

function YF:UpdatePortrait(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	local model, tex = f.portrait3d, f.portrait2d
	if db.portrait == "none" then
		model:Hide()
		tex:Hide()
		return
	end
	if db.portrait == "class" then
		model:Hide()
		local _, class = UnitClass(sample(f) and "player" or unit)
		local coords = class and CLASS_ICON_TCOORDS[class]
		if coords and (sample(f) or UnitIsPlayer(unit)) then
			tex:SetTexture(CLASS_ICONS)
			tex:SetTexCoord(coords[1] + 0.015, coords[2] - 0.015, coords[3] + 0.015, coords[4] - 0.015)
		else
			SetPortraitTexture(tex, unit)
			tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end
		tex:Show()
		return
	end
	tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	if sample(f) then
		model:Hide()
		tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		tex:Show()
		return
	end
	if db.portrait == "3d" and UnitIsVisible(unit) then
		tex:Hide()
		model:Show()
		model:SetUnit(unit)
		model:SetCamera(0)
	else
		model:Hide()
		SetPortraitTexture(tex, unit)
		tex:Show()
	end
end

function YF:UpdateIcons(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	local exists = UnitExists(unit)

	local pvp
	if db.showPvP and exists then
		if UnitIsPVPFreeForAll(unit) then
			pvp = "Interface\\TargetingFrame\\UI-PVP-FFA"
		elseif UnitIsPVP(unit) then
			local faction = UnitFactionGroup(unit)
			if faction then
				pvp = "Interface\\TargetingFrame\\UI-PVP-" .. faction
			end
		end
	end
	if pvp then
		f.pvpIcon:SetTexture(pvp)
		f.pvpIcon:Show()
	else
		f.pvpIcon:Hide()
	end

	local mark = db.showRaidIcon and exists and GetRaidTargetIndex(unit)
	if mark then
		SetRaidTargetIconTexture(f.raidIcon, mark)
		f.raidIcon:Show()
	else
		f.raidIcon:Hide()
	end

	if db.showLeader and exists and UnitIsPartyLeader(unit) then
		f.leaderIcon:Show()
	else
		f.leaderIcon:Hide()
	end

	f.statusIcon:Hide()
	if unit == "player" and db.showStatus then
		if UnitAffectingCombat("player") then
			f.statusIcon:SetTexCoord(0.5, 1, 0, 0.49)
			f.statusIcon:Show()
		elseif IsResting() then
			f.statusIcon:SetTexCoord(0, 0.5, 0, 0.421875)
			f.statusIcon:Show()
		end
	end
end

function YF:UpdateCombo(f)
	if not f.combo then
		return
	end
	local db = self:GetUnitDB(f.unit)
	local points = 0
	if db.showComboPoints then
		points = sample(f) and 3 or GetComboPoints("player", "target")
	end
	for i, point in ipairs(f.combo) do
		if i <= points then
			point:Show()
		else
			point:Hide()
		end
	end
end

function YF:UpdateTrinket(f, event, spell)
	local t = f.trinket
	if not t then
		return
	end
	if not self:GetUnitDB(f.unit).showTrinket then
		t:Hide()
		return
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if TRINKET_SPELLS[spell] then
			CooldownFrame_SetTimer(t.cooldown, GetTime(), TRINKET_COOLDOWN, 1)
		end
		return
	end
	local faction = UnitExists(f.unit) and UnitFactionGroup(f.unit) or UnitFactionGroup("player")
	t.icon:SetTexture(faction == "Alliance" and "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
		or "Interface\\Icons\\INV_Jewelry_TrinketPVP_02")
	t:Show()
end

-- Entering a new arena (or leaving one) resets the trinket cooldowns.
function YF:ResetTrinkets()
	for _, unit in ipairs(self.GROUP_UNITS.arena) do
		local f = self.frames[unit]
		if f and f.trinket then
			f.trinket.cooldown:Hide()
		end
	end
end

function YF:UpdateFrame(f)
	self:UpdateHealth(f)
	self:UpdatePower(f)
	self:UpdateName(f)
	self:UpdatePortrait(f)
	self:UpdateIcons(f)
	self:UpdateCombo(f)
	self:UpdateAuras(f)
	self:UpdateCast(f)
	self:UpdateTrinket(f)
end

function YF:UpdateAll()
	for unit, f in pairs(self.frames) do
		if self:GetUnitDB(unit).enabled then
			self:UpdateFrame(f)
		end
	end
end

-- Events

local UNIT_EVENTS = {
	UNIT_HEALTH = "UpdateHealth",
	UNIT_MAXHEALTH = "UpdateHealth",
	UNIT_FLAGS = "UpdateHealth",
	UNIT_FACTION = "UpdateFrame",
	UNIT_NAME_UPDATE = "UpdateName",
	UNIT_LEVEL = "UpdateName",
	UNIT_CLASSIFICATION_CHANGED = "UpdateName",
	UNIT_PORTRAIT_UPDATE = "UpdatePortrait",
	UNIT_MODEL_CHANGED = "UpdatePortrait",
	UNIT_AURA = "UpdateAuras",
	UNIT_DISPLAYPOWER = "UpdatePower",
	UNIT_SPELLCAST_SUCCEEDED = "UpdateTrinket",
}
for _, power in ipairs({ "MANA", "RAGE", "FOCUS", "ENERGY", "HAPPINESS", "RUNIC_POWER" }) do
	UNIT_EVENTS["UNIT_" .. power] = "UpdatePower"
	UNIT_EVENTS["UNIT_MAX" .. power] = "UpdatePower"
end
for _, event in ipairs({ "START", "STOP", "FAILED", "INTERRUPTED", "DELAYED", "CHANNEL_START",
	"CHANNEL_UPDATE", "CHANNEL_STOP", "INTERRUPTIBLE", "NOT_INTERRUPTIBLE" }) do
	UNIT_EVENTS["UNIT_SPELLCAST_" .. event] = "UpdateCast"
end

-- Events that aren't about one unit: which frames to refresh, and how.
-- units = "all" means every frame, "party"/"arena" that group's frames.
local OTHER_EVENTS = {
	PLAYER_ENTERING_WORLD = { { units = "all", method = "UpdateFrame" } },
	PLAYER_TARGET_CHANGED = { { units = { "target" }, method = "UpdateFrame" } },
	PLAYER_FOCUS_CHANGED = { { units = { "focus" }, method = "UpdateFrame" } },
	RAID_TARGET_UPDATE = { { units = "all", method = "UpdateIcons" } },
	PARTY_LEADER_CHANGED = { { units = "all", method = "UpdateIcons" } },
	PARTY_MEMBERS_CHANGED = { { units = { "player", "target", "focus" }, method = "UpdateIcons" },
		{ units = "party", method = "UpdateFrame" } },
	PARTY_MEMBER_ENABLE = { { units = "party", method = "UpdateFrame" } },
	PARTY_MEMBER_DISABLE = { { units = "party", method = "UpdateFrame" } },
	ARENA_OPPONENT_UPDATE = { { units = "arena", method = "UpdateFrame" } },
	PLAYER_UPDATE_RESTING = { { units = { "player" }, method = "UpdateIcons" } },
	PLAYER_REGEN_DISABLED = { { units = { "player" }, method = "UpdateIcons" } },
	PLAYER_REGEN_ENABLED = { { units = { "player" }, method = "UpdateIcons" } },
	UNIT_COMBO_POINTS = { { units = { "target" }, method = "UpdateCombo" } },
}

local function unitsOf(units)
	if units == "all" then
		return YF:AllUnits()
	end
	return YF.GROUP_UNITS[units] or units
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, arg1, ...)
	local method = UNIT_EVENTS[event]
	if method then
		local f = YF.frames[arg1]
		if f and YF:GetUnitDB(arg1).enabled then
			YF[method](YF, f, event, ...)
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		YF:ResetTrinkets()
	end
	for _, info in ipairs(OTHER_EVENTS[event]) do
		for _, unit in ipairs(unitsOf(info.units)) do
			local f = YF.frames[unit]
			if f and YF:GetUnitDB(unit).enabled then
				YF[info.method](YF, f, event)
			end
		end
	end
end)

function YF:RegisterEvents()
	for event in pairs(UNIT_EVENTS) do
		eventFrame:RegisterEvent(event)
	end
	for event in pairs(OTHER_EVENTS) do
		eventFrame:RegisterEvent(event)
	end
end
