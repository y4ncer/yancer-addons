local _, ns = ...
local YF, YB = ns.YF, ns.YB

-- Cast bar below the frame: spell icon, name and time left. Yellow for casts,
-- blue for channels, grey when it can't be interrupted, red on interrupt/fail.

local HOLD = 0.6 -- seconds "Interrupted"/"Failed" stays visible

local function onUpdate(bar, elapsed)
	if bar.holdTime then
		bar.holdTime = bar.holdTime - elapsed
		if bar.holdTime <= 0 then
			bar.holdTime = nil
			bar.frame:Hide()
		end
		return
	end
	local now = GetTime()
	if now >= bar.endTime then
		bar.frame:Hide()
		return
	end
	local total = bar.endTime - bar.startTime
	if bar.channeling then
		bar:SetValue(bar.endTime - now)
	else
		bar:SetValue(now - bar.startTime)
	end
	bar.time:SetText(format("%.1f", bar.endTime - now))
	if total <= 0 then
		bar.frame:Hide()
	end
end

function YF:CreateCastBar(f)
	local frame = CreateFrame("Frame", nil, f)
	YB:SquareBackdrop(frame, 0.6)
	YB:Outline(frame)
	frame:Hide()

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local bar = CreateFrame("StatusBar", nil, frame)
	bar:SetStatusBarTexture(YB.WHITE)
	bar.frame = frame
	bar.text = bar:CreateFontString(nil, "OVERLAY")
	bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
	bar.text:SetJustifyH("LEFT")
	bar.time = bar:CreateFontString(nil, "OVERLAY")
	bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	bar:SetScript("OnUpdate", onUpdate)
	frame.bar = bar
	f.castBar = frame
end

function YF:LayoutCastBar(f, db)
	local frame = f.castBar
	local h = db.castBarHeight
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -5)
	frame:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -5)
	frame:SetHeight(h + 2)
	frame.icon:ClearAllPoints()
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	frame.icon:SetWidth(h)
	frame.icon:SetHeight(h)
	local bar = frame.bar
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 1, 0)
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	local size = math.max(self.db.profile.fontSize - 1, 6)
	bar.text:SetFont(YB.FONT, size, "OUTLINE")
	bar.text:SetWidth(math.max(db.width - h - 50, 20))
	bar.text:SetHeight(size + 2)
	bar.time:SetFont(YB.FONT, size, "OUTLINE")
	if not db.showCastBar then
		frame:Hide()
	end
end

function YF:UpdateCast(f, event)
	local frame, db = f.castBar, self:GetUnitDB(f.unit)
	local bar = frame.bar
	if not db.showCastBar then
		frame:Hide()
		return
	end
	local unit = f.unit

	-- FAILED also fires when pressing another spell mid-cast: only a cast that
	-- really ended shows "Failed"/"Interrupted".
	if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
		and frame:IsShown() and not bar.holdTime and not bar.channeling and not UnitCastingInfo(unit) then
		bar:SetStatusBarColor(0.8, 0.1, 0.1)
		bar:SetValue(select(2, bar:GetMinMaxValues()))
		bar.text:SetText(event == "UNIT_SPELLCAST_INTERRUPTED" and "Interrupted" or "Failed")
		bar.time:SetText("")
		bar.holdTime = HOLD
		return
	end

	local name, _, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
	local channeling = false
	if not name then
		name, _, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
		channeling = name ~= nil
	end
	if not name then
		-- A new unit (event == nil) drops the previous one's "Interrupted".
		if not bar.holdTime or not event then
			bar.holdTime = nil
			frame:Hide()
		end
		return
	end

	bar.holdTime = nil
	bar.channeling = channeling
	bar.startTime, bar.endTime = startMS / 1000, endMS / 1000
	bar:SetMinMaxValues(0, bar.endTime - bar.startTime)
	if notInterruptible then
		bar:SetStatusBarColor(0.6, 0.6, 0.6)
	elseif channeling then
		bar:SetStatusBarColor(0.3, 0.7, 1)
	else
		bar:SetStatusBarColor(1, 0.75, 0.2)
	end
	frame.icon:SetTexture(texture)
	bar.text:SetText(name)
	frame:Show()
end
