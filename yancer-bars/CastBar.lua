local _, ns = ...
local YB = ns.YB

-- Blizzard's player cast bar (CastingBarFrame): the square style (spell icon on
-- its left, no Blizzard art), tick marks plus a ticks-left counter on
-- channelled spells, and the pushback taken ("+0.5s" on casts, "-0.8s" on channels).

local bar = CastingBarFrame

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

-- Marks and texts on their own frame above the bar's fill.
local overlay = CreateFrame("Frame", nil, bar)
overlay:SetAllPoints(bar)
overlay:SetFrameLevel(bar:GetFrameLevel() + 3)

local marks = {}
local counter = overlay:CreateFontString(nil, "OVERLAY")
counter:SetFont(YB.FONT, 11, "OUTLINE")
counter:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

local pushback = overlay:CreateFontString(nil, "OVERLAY")
pushback:SetFont(YB.FONT, 11, "OUTLINE")
pushback:SetPoint("LEFT", bar, "LEFT", 4, 0)
pushback:SetTextColor(1, 0.25, 0.25)
local castEnd, delay = 0, 0
local ticks = 0

local function hideTicks()
	ticks = 0
	for _, mark in ipairs(marks) do
		mark:Hide()
	end
	counter:SetText("")
end

local function showTicks(count)
	ticks = count
	local width = bar:GetWidth()
	for i = 1, count - 1 do
		local mark = marks[i]
		if not mark then
			-- Dark and 2px wide, so they show on Blizzard's bright green channel colour.
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

-- Pushback: how far the cast end moved since the cast started. Casts end later
-- (UNIT_SPELLCAST_DELAYED), channels end sooner (UNIT_SPELLCAST_CHANNEL_UPDATE).
local function startPushback(endMS)
	castEnd, delay = endMS or 0, 0
	pushback:SetText("")
end

local function updatePushback(endMS, channel)
	if not endMS or castEnd == 0 then
		return
	end
	delay = math.abs(endMS - castEnd) / 1000
	if delay >= 0.05 then
		pushback:SetText(format(channel and "-%.1fs" or "+%.1fs", delay))
	end
end

bar:HookScript("OnEvent", function(self, event, unit)
	-- Blizzard labels channels "Channeling": show the spell's name instead.
	if self.channeling then
		local name = UnitChannelInfo(self.unit)
		if name then
			CastingBarFrameText:SetText(name)
		end
	end
	if unit ~= self.unit then
		return
	end
	if event == "UNIT_SPELLCAST_START" then
		startPushback(select(6, UnitCastingInfo(self.unit)))
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		startPushback(select(6, UnitChannelInfo(self.unit)))
	elseif event == "UNIT_SPELLCAST_DELAYED" then
		updatePushback(select(6, UnitCastingInfo(self.unit)), false)
	elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		updatePushback(select(6, UnitChannelInfo(self.unit)), true)
	end
	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		local count = TICKS[UnitChannelInfo(self.unit) or ""]
		if count then
			showTicks(count)
		else
			hideTicks()
		end
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		hideTicks()
	end
end)

-- Ticks left: the channel bar runs down from full, one tick per 1/ticks of it.
bar:HookScript("OnUpdate", function(self)
	if ticks > 0 and self.channeling and self.maxValue and self.maxValue > 0 then
		counter:SetText(math.ceil(self.value / self.maxValue * ticks - 0.001))
	elseif ticks > 0 then
		hideTicks()
	end
end)

-- Square style. Blizzard fades its flash texture in when a cast ends (alpha
-- steps from 0 to 1), so alpha 0 isn't enough: the art is cleared instead.
function YB:SkinCastBar()
	self:SkinStatusBar(bar)
	for _, name in ipairs({ "CastingBarFrameBorder", "CastingBarFrameFlash", "CastingBarFrameBorderShield",
		"CastingBarFrameSpark" }) do
		local tex = _G[name]
		if tex then
			tex:SetTexture(nil)
		end
	end
	CastingBarFrameText:ClearAllPoints()
	CastingBarFrameText:SetPoint("CENTER", bar, "CENTER", 0, 0)

	-- Blizzard sets the icon's texture on every cast but hides it for the player
	-- once, on load: shown again, square, left of the bar.
	local icon = CastingBarFrameIcon
	local size = bar:GetHeight() + 2
	icon:ClearAllPoints()
	icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	icon:SetWidth(size)
	icon:SetHeight(size)
	icon:SetTexCoord(self.db.profile.iconZoom, 1 - self.db.profile.iconZoom,
		self.db.profile.iconZoom, 1 - self.db.profile.iconZoom)
	icon:Show()
	local border = CreateFrame("Frame", nil, bar)
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	border:SetFrameLevel(math.max(bar:GetFrameLevel() - 1, 0))
	self:SquareBackdrop(border, 0.6)
	self:Outline(border)
	-- Bar's size can change (UI Elements scale): keep the icon square to it.
	bar:HookScript("OnSizeChanged", function(b)
		local h = b:GetHeight() + 2
		icon:SetWidth(h)
		icon:SetHeight(h)
	end)
end
