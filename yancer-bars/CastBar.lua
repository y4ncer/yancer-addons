local _, ns = ...
local YB = ns.YB

-- Blizzard's player cast bar (CastingBarFrame).
--
-- Always: the fill is computed from the cast's start/end time every frame
-- (Blizzard adds up frame times, which drifts and stutters), and channelled
-- spells get tick marks.
--
-- Square style (Quartz-like): a glossy bar in your class colour with a thin
-- spark on its edge, the spell icon on its left, "Spell (Target)" on the left,
-- "remaining/total" on the right (with the ticks left and the pushback taken),
-- and your latency as a red zone at the end of the bar: a cast is done on your
-- side once the fill reaches it.

local bar = CastingBarFrame
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Ticks per channel on 3.3.5. Haste shortens the channel but keeps the tick
-- count, so the marks are evenly spaced.
local TICKS = {}
for id, ticks in pairs({
	[15407] = 3,  -- Mind Flay
	[48045] = 5,  -- Mind Sear
	[47540] = 3,  -- Penance
	[64843] = 4,  -- Divine Hymn
	[64901] = 4,  -- Hymn of Hope
	[1120] = 5,   -- Drain Soul
	[689] = 5,    -- Drain Life
	[5138] = 5,   -- Drain Mana
	[755] = 10,   -- Health Funnel
	[1949] = 15,  -- Hellfire
	[5740] = 4,   -- Rain of Fire
	[5143] = 5,   -- Arcane Missiles
	[10] = 8,     -- Blizzard
	[12051] = 4,  -- Evocation
	[16914] = 10, -- Hurricane
	[740] = 4,    -- Tranquility
	[1510] = 6,   -- Volley
}) do
	local name = GetSpellInfo(id)
	if name then
		TICKS[name] = ticks
	end
end

-- Tick marks, the time text and the spark on their own frame above the bar's fill.
local overlay = CreateFrame("Frame", nil, bar)
overlay:SetAllPoints(bar)
overlay:SetFrameLevel(bar:GetFrameLevel() + 3)

local styled          -- square style applied
local spark, timeText, latencyZone, iconBorder
local marks = {}
local ticks = 0
local startTime, endTime -- current cast/channel, in GetTime() seconds
local castEnd, delay = 0, 0 -- original end (ms) and pushback taken (s)
local sentTime, sentTarget -- from UNIT_SPELLCAST_SENT
local lag = 0

local function cfg()
	return YB.db.profile.castBar
end

local function hideTicks()
	ticks = 0
	for _, mark in ipairs(marks) do
		mark:Hide()
	end
end

local function showTicks(count)
	ticks = count
	local width = bar:GetWidth()
	for i = 1, count - 1 do
		local mark = marks[i]
		if not mark then
			-- Dark and 2px wide, so they show on any bar colour.
			mark = overlay:CreateTexture(nil, "OVERLAY")
			mark:SetTexture(YB.WHITE)
			mark:SetVertexColor(0, 0, 0, 1)
			mark:SetWidth(2)
			marks[i] = mark
		end
		mark:ClearAllPoints()
		mark:SetPoint("TOP", bar, "TOPLEFT", width * i / count, 0)
		mark:SetPoint("BOTTOM", bar, "BOTTOMLEFT", width * i / count, 0)
		mark:Show()
	end
	for i = count, #marks do
		marks[i]:Hide()
	end
end

-- "Spell (Target)" on the left. The target comes from UNIT_SPELLCAST_SENT;
-- casts on yourself or without a target show just the spell.
local function setSpellText(name)
	local text = name or ""
	local c = cfg()
	if c.showTarget and sentTarget and sentTarget ~= "" and sentTarget ~= UnitName("player")
		and sentTime and GetTime() - sentTime < 2 then
		text = text .. " (" .. sentTarget .. ")"
	end
	CastingBarFrameText:SetText(text)
end

-- The red zone: your latency, at the end the fill moves towards (the right for
-- casts, the left for channels, which run down).
local function placeLatency(channel)
	if not latencyZone then
		return
	end
	local max = bar.maxValue
	if not cfg().showLatency or not max or max <= 0 or lag <= 0 then
		latencyZone:Hide()
		return
	end
	local width = math.min(lag / max, 1) * bar:GetWidth()
	latencyZone:ClearAllPoints()
	latencyZone:SetPoint("TOP", bar, "TOP")
	latencyZone:SetPoint("BOTTOM", bar, "BOTTOM")
	if channel then
		latencyZone:SetPoint("LEFT", bar, "LEFT")
	else
		latencyZone:SetPoint("RIGHT", bar, "RIGHT")
	end
	latencyZone:SetWidth(math.max(width, 1))
	latencyZone:Show()
end

-- Latency: the time from sending the cast to the server starting it, or the
-- world latency when that isn't known.
local function measureLag()
	if sentTime and GetTime() - sentTime < 2 then
		lag = GetTime() - sentTime
	else
		local _, _, ms = GetNetStats()
		lag = (ms or 0) / 1000
	end
	sentTime = nil
end

local sent = CreateFrame("Frame")
sent:RegisterEvent("UNIT_SPELLCAST_SENT")
sent:SetScript("OnEvent", function(_, _, unit, _, _, target)
	if unit == "player" then
		sentTime, sentTarget = GetTime(), target
	end
end)

bar:HookScript("OnEvent", function(self, event, unit)
	-- A channel already running when the UI loads arrives as PLAYER_ENTERING_WORLD.
	if unit ~= self.unit and not (event == "PLAYER_ENTERING_WORLD" and self.channeling) then
		return
	end
	local name, s, e
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
		name, _, _, _, s, e = UnitCastingInfo(self.unit)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
		or event == "PLAYER_ENTERING_WORLD" then
		name, _, _, _, s, e = UnitChannelInfo(self.unit)
	end
	if s then
		startTime, endTime = s / 1000, e / 1000
	end

	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
		or (event == "PLAYER_ENTERING_WORLD" and name) then
		castEnd, delay = e or 0, 0
		measureLag()
		-- Blizzard labels channels "Channeling" and never shows the target.
		if styled or event ~= "UNIT_SPELLCAST_START" then
			setSpellText(name)
		end
		placeLatency(event ~= "UNIT_SPELLCAST_START")
		local count = event ~= "UNIT_SPELLCAST_START" and TICKS[name or ""]
		if count then
			showTicks(count)
		else
			hideTicks()
		end
	elseif (event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE") and e and castEnd > 0 then
		-- Pushback: casts end later, channels end sooner.
		delay = math.abs(e - castEnd) / 1000
		placeLatency(event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		hideTicks()
	end
end)

local function classColor()
	local c = cfg()
	if c.classColor then
		local _, class = UnitClass("player")
		local cc = class and RAID_CLASS_COLORS[class]
		if cc then
			return cc.r, cc.g, cc.b
		end
	end
	return c.color.r, c.color.g, c.color.b
end

-- Runs after Blizzard's OnUpdate: replaces its value with the exact one for now.
bar:HookScript("OnUpdate", function(self)
	local max = self.maxValue
	local active = (self.casting or self.channeling) and endTime and max and max > 0
	if not active then
		if spark then
			spark:Hide()
		end
		if ticks > 0 then
			hideTicks()
		end
		return
	end
	local now = GetTime()
	local value
	if self.casting then
		value = math.min(math.max(now - startTime, 0), max)
	else
		value = math.max(endTime - now, 0)
	end
	self.value = value
	self:SetValue(value)
	if not styled then
		return
	end

	self:SetStatusBarColor(classColor())
	spark:SetPoint("CENTER", self, "LEFT", self:GetWidth() * value / max, 0)
	spark:Show()

	local remaining = self.casting and (max - value) or value
	local parts = {}
	if delay >= 0.05 then
		parts[#parts + 1] = format(self.channeling and "|cffff4040-%.1f|r" or "|cffff4040+%.1f|r", delay)
	end
	if ticks > 0 then
		parts[#parts + 1] = format("|cffbbbbbb%d|r", math.ceil(value / max * ticks - 0.001))
	end
	if cfg().showTime then
		parts[#parts + 1] = format("%.1f/%.1f", remaining, max)
	end
	timeText:SetText(table.concat(parts, "  "))
end)

-- Size, fonts and text positions (out of the square style there is nothing to lay out).
function YB:LayoutCastBar()
	if not styled then
		return
	end
	local c = cfg()
	local w, h = c.width, c.height
	bar:SetWidth(w)
	bar:SetHeight(h)
	local el = self.ELEMENTS_BY_KEY.cast
	el.size = { w, h }
	if self:GetElementDB("cast").enabled then
		self:UpdateElement("cast")
	end

	local icon = CastingBarFrameIcon
	icon:SetWidth(h + 2)
	icon:SetHeight(h + 2)
	if c.showIcon then
		icon:Show()
		iconBorder:Show()
	else
		icon:Hide()
		iconBorder:Hide()
	end

	local size = c.fontSize
	CastingBarFrameText:SetFont(YB.FONT, size)
	CastingBarFrameText:SetShadowOffset(1, -1)
	CastingBarFrameText:SetJustifyH("LEFT")
	CastingBarFrameText:ClearAllPoints()
	CastingBarFrameText:SetPoint("LEFT", bar, "LEFT", 5, 0)
	CastingBarFrameText:SetWidth(math.max(w - 95, 20))
	CastingBarFrameText:SetHeight(h)
	timeText:SetFont(YB.FONT, size)
	timeText:SetShadowOffset(1, -1)

	spark:SetHeight(h * 2.2)
	if ticks > 0 then
		showTicks(ticks)
	end
end

-- Square style. Blizzard fades its flash texture in when a cast ends (alpha
-- steps from 0 to 1), so alpha 0 isn't enough: the art is cleared instead.
function YB:SkinCastBar()
	self:SkinStatusBar(bar)
	bar:SetStatusBarTexture(BAR_TEXTURE)
	for _, name in ipairs({ "CastingBarFrameBorder", "CastingBarFrameFlash", "CastingBarFrameBorderShield",
		"CastingBarFrameSpark" }) do
		local tex = _G[name]
		if tex then
			tex:SetTexture(nil)
		end
	end

	-- A thin white glow on the fill's edge (our own texture: Blizzard re-anchors
	-- its spark every frame).
	spark = overlay:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	spark:SetVertexColor(1, 1, 1, 1)
	spark:SetWidth(10)
	spark:Hide()

	-- Under the fill (BORDER < the fill's ARTWORK) and the spell text: the fill covers it on arrival.
	latencyZone = bar:CreateTexture(nil, "BORDER")
	latencyZone:SetTexture(BAR_TEXTURE)
	latencyZone:SetVertexColor(0.8, 0.1, 0.1, 0.85)
	latencyZone:Hide()

	timeText = overlay:CreateFontString(nil, "OVERLAY")
	timeText:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
	timeText:SetJustifyH("RIGHT")

	-- Blizzard sets the icon's texture on every cast but hides it for the player
	-- once, on load: shown again, square, left of the bar.
	local icon = CastingBarFrameIcon
	local zoom = self.db.profile.iconZoom
	icon:ClearAllPoints()
	icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
	local border = CreateFrame("Frame", nil, bar)
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	border:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
	self:SquareBackdrop(border, 0.6)
	self:Outline(border)
	iconBorder = border

	styled = true
	self:LayoutCastBar()
end
