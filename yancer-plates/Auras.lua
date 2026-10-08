local _, ns = ...
local YP, YB = ns.YP, ns.YB

-- Debuffs on nameplates: a row of icons above the name, with the stack count,
-- and the time left on your target's plate.
--
-- 3.3.5 nameplates don't say which unit they belong to, so debuffs are kept per
-- GUID and a plate learns its GUID when it is your target or under the mouse
-- (players also by name, from the combat log). The debuffs come from reading
-- target/focus/mouseover with UnitAura, and from the combat log for your own
-- debuffs on units you can't read (applied, refreshed, stacks, removed).

local auras = {}      -- guid -> { [spell name] = { icon, count, duration, expires } }
local durations = {}  -- spell name -> duration seen with UnitAura (your debuffs)
local playerGUIDs = {} -- player name -> guid, for plates that never were target/mouseover
local myGUID

local function db()
	return YP.db.profile
end

local function mine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

local function scan(unit)
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local list = {}
	local onlyMine = db().onlyMyDebuffs
	local i = 1
	while true do
		local name, _, icon, count, _, duration, expires, caster = UnitAura(unit, i, "HARMFUL")
		if not name then
			break
		end
		if mine(caster) and duration and duration > 0 then
			durations[name] = duration
		end
		if not onlyMine or mine(caster) then
			list[name] = { icon = icon, count = count or 0, duration = duration or 0, expires = expires or 0 }
		end
		i = i + 1
	end
	auras[guid] = list
	if UnitIsPlayer(unit) then
		playerGUIDs[UnitName(unit)] = guid
	end
end

local COMBATLOG_OBJECT_TYPE_PLAYER = 0x400

local function onCombatLog(_, _, event, sourceGUID, _, _, destGUID, destName, destFlags, spellId, spellName, _,
	auraType, amount)
	if event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
		auras[destGUID] = nil
		return
	end
	if sourceGUID ~= myGUID or auraType ~= "DEBUFF" or not spellName then
		return
	end
	if destName and bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
		playerGUIDs[destName:match("^[^%-]+")] = destGUID
	end
	local list = auras[destGUID]
	if not list then
		list = {}
		auras[destGUID] = list
	end
	if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
		local duration = durations[spellName] or 0
		local old = list[spellName]
		list[spellName] = {
			icon = select(3, GetSpellInfo(spellId)) or (old and old.icon),
			count = old and old.count or 0,
			duration = duration,
			expires = duration > 0 and GetTime() + duration or 0,
		}
	elseif event == "SPELL_AURA_APPLIED_DOSE" or event == "SPELL_AURA_REMOVED_DOSE" then
		if list[spellName] then
			list[spellName].count = amount or list[spellName].count
		end
	elseif event == "SPELL_AURA_REMOVED" then
		list[spellName] = nil
	end
end

local function formatTime(left)
	if left >= 3600 then
		return format("%dh", math.ceil(left / 3600))
	elseif left >= 60 then
		return format("%dm", math.ceil(left / 60))
	elseif left >= 3 then
		return format("%d", math.floor(left + 0.5))
	end
	return format("%.1f", left)
end

local function createIcon(p)
	local f = CreateFrame("Frame", nil, p.auraRow)
	YB:SquareBackdrop(f, 1)
	YB:Outline(f)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetPoint("TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	f.count = f:CreateFontString(nil, "OVERLAY")
	f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, 0)
	f.time = f:CreateFontString(nil, "OVERLAY")
	f.time:SetPoint("CENTER", f, "CENTER", 0, 0)
	return f
end

function ns.CreatePlateAuras(p)
	-- The row needs a real size: a frame with no width may not be drawn.
	p.auraRow = CreateFrame("Frame", nil, p.frame)
	p.auraRow:SetWidth(100)
	p.auraRow:SetHeight(14)
	p.auraRow:SetFrameLevel(p.frame:GetFrameLevel() + 10)
	p.auraIcons = {}
end

-- Sizes, and where the row sits: just above the name. The class icon goes above
-- the row while it shows.
function ns.LayoutPlateAuras(p)
	local s = db()
	p.auraRow:ClearAllPoints()
	p.auraRow:SetPoint("BOTTOM", p.name, "TOP", 0, 2)
	p.auraRow:SetWidth(math.max(s.width, (s.auraWidth + 2) * s.maxAuras))
	p.auraRow:SetHeight(s.auraHeight)
	for _, f in ipairs(p.auraIcons) do
		f:SetWidth(s.auraWidth)
		f:SetHeight(s.auraHeight)
		f.count:SetFont(YB.NUMBER_FONT, s.auraFontSize, "OUTLINE")
		f.time:SetFont(YB.NUMBER_FONT, s.auraFontSize, "OUTLINE")
	end
	p.classAnchor = nil
	ns.UpdatePlateAuras(p)
end

local function sortByExpires(a, b)
	if (a.expires == 0) ~= (b.expires == 0) then
		return b.expires == 0 -- permanent ones last
	end
	return a.expires < b.expires
end

local shown = {}

function ns.UpdatePlateAuras(p)
	local s = db()
	local guid = p.guid
	if not guid then
		local name = p.name:GetText()
		guid = name and playerGUIDs[name]
	end
	local list = s.auras and guid and auras[guid]
	wipe(shown)
	if list then
		local now = GetTime()
		for name, a in pairs(list) do
			if a.expires > 0 and a.expires < now then
				list[name] = nil
			else
				shown[#shown + 1] = a
			end
		end
		table.sort(shown, sortByExpires)
	end

	local count = math.min(#shown, s.maxAuras)
	local w, gap = s.auraWidth, 2
	local total = count * w + math.max(count - 1, 0) * gap
	local zoomY = (1 - s.auraHeight / s.auraWidth) / 2 * 0.84 -- crop wide icons top and bottom
	for i = 1, count do
		local f = p.auraIcons[i]
		if not f then
			f = createIcon(p)
			f:SetWidth(s.auraWidth)
			f:SetHeight(s.auraHeight)
			f.count:SetFont(YB.NUMBER_FONT, s.auraFontSize, "OUTLINE")
			f.time:SetFont(YB.NUMBER_FONT, s.auraFontSize, "OUTLINE")
			p.auraIcons[i] = f
		end
		local a = shown[i]
		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", p.auraRow, "BOTTOM", -total / 2 + (i - 1) * (w + gap), 0)
		f.icon:SetTexture(a.icon)
		f.icon:SetTexCoord(0.08, 0.92, 0.08 + math.max(zoomY, 0), 0.92 - math.max(zoomY, 0))
		f.count:SetText(a.count > 1 and a.count or "")
		if s.timers and a.expires > 0 then
			local left = a.expires - GetTime()
			f.time:SetText(formatTime(left))
			if left < 3 then
				f.time:SetTextColor(1, 0.2, 0.2)
			else
				f.time:SetTextColor(1, 1, 1)
			end
		else
			f.time:SetText("")
		end
		f:Show()
	end
	for i = count + 1, #p.auraIcons do
		p.auraIcons[i]:Hide()
	end

	local anchor = count > 0 and p.auraRow or p.name
	if p.classAnchor ~= anchor then
		p.classAnchor = anchor
		p.classFrame:ClearAllPoints()
		p.classFrame:SetPoint("BOTTOM", anchor, "TOP", 0, count > 0 and 4 or 2)
	end
end

-- /yplates: what the addon knows about your target's plate (for bug reports).
function ns.DebugTarget(p)
	local guid = UnitGUID("target")
	local list = guid and auras[guid]
	local n = 0
	for _ in pairs(list or {}) do
		n = n + 1
	end
	YB:Print(format("target guid %s: %d debuffs known (auras %s, only mine %s)", tostring(guid), n,
		tostring(db().auras), tostring(db().onlyMyDebuffs)))
	if not p then
		YB:Print("no nameplate matched as your target (is its plate shown? V toggles them)")
		return
	end
	local first = p.auraIcons[1]
	YB:Print(format("plate guid %s, row %dx%d shown %s, icons %d, first shown %s",
		tostring(p.guid), p.auraRow:GetWidth(), p.auraRow:GetHeight(), tostring(p.auraRow:IsVisible()),
		#p.auraIcons, tostring(first and first:IsVisible())))
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		onCombatLog(event, ...)
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "target" or unit == "focus" or unit == "mouseover" or (unit and unit:find("^arena%d")) then
			scan(unit)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		scan("target")
	elseif event == "PLAYER_FOCUS_CHANGED" then
		scan("focus")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		scan("mouseover")
	elseif event == "PLAYER_ENTERING_WORLD" then
		myGUID = UnitGUID("player")
		wipe(auras)
	end
end)
for _, event in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_ENTERING_WORLD" }) do
	events:RegisterEvent(event)
end
