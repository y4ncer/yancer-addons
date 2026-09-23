local _, ns = ...
local YF, YB = ns.YF, ns.YB

-- Aura icons in rows above the frame: debuffs first (border in the debuff type
-- colour), then buffs. Hover for the tooltip; the cooldown swipe shows the
-- time left (OmniCC adds text if installed).

local function createAura(f)
	local button = CreateFrame("Button", nil, f)
	YB:SquareBackdrop(button, 0.6)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints(button.icon)
	button.cooldown:SetReverse(true)
	button.count = button:CreateFontString(nil, "OVERLAY")
	button.count:SetFont(YB.NUMBER_FONT, 10, "OUTLINE")
	button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetUnitAura(f.unit, self.index, self.filter)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function mine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

function YF:UpdateAuras(f)
	local unit, db = f.unit, self:GetUnitDB(f.unit)
	f.auras = f.auras or {}
	local shown = 0

	if db.showAuras and UnitExists(unit) then
		local size = db.auraSize
		local perRow = math.max(math.floor((db.width + 2) / (size + 2)), 1)

		local function add(index, filter, icon, count, duration, expires, r, g, b)
			shown = shown + 1
			local button = f.auras[shown]
			if not button then
				button = createAura(f)
				f.auras[shown] = button
			end
			button.index, button.filter = index, filter
			button:SetWidth(size)
			button:SetHeight(size)
			button:ClearAllPoints()
			local col, row = (shown - 1) % perRow, math.floor((shown - 1) / perRow)
			button:SetPoint("BOTTOMLEFT", f.auraAnchor, "TOPLEFT", col * (size + 2), row * (size + 2))
			button.icon:SetTexture(icon)
			button.count:SetText(count and count > 1 and count or "")
			button:SetBackdropBorderColor(r, g, b, 1)
			if duration and duration > 0 then
				CooldownFrame_SetTimer(button.cooldown, expires - duration, duration, 1)
			else
				button.cooldown:Hide()
			end
			button:Show()
		end

		for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
			local i = 1
			while shown < db.maxAuras do
				local name, _, icon, count, debuffType, duration, expires, caster = UnitAura(unit, i, filter)
				if not name then
					break
				end
				if filter == "HELPFUL" then
					add(i, filter, icon, count, duration, expires, 0, 0, 0)
				elseif not db.onlyMyDebuffs or mine(caster) then
					local c = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor.none
					add(i, filter, icon, count, duration, expires, c.r, c.g, c.b)
				end
				i = i + 1
			end
		end
	end

	for i = shown + 1, #f.auras do
		f.auras[i]:Hide()
	end
end
