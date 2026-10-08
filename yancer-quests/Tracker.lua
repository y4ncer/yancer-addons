local _, ns = ...
local YQ, YB = ns.YQ, ns.YB

-- Restyles Blizzard's objective tracker (WatchFrame) instead of replacing it, so
-- Blizzard's logic, quest item buttons, clicks and menus keep working. It gets a
-- holder with a mover (/yb move), our width/height/scale/font, a square background
-- that fits its content, coloured titles and objectives, and auto-collapse.
--
-- Blizzard re-anchors the WatchFrame from UIParent_ManageFramePositions and resets
-- its width from WatchFrame_SetWidth / WatchFrame_Expand, so those are hooked.

local holder, bg, toggle
local placing

local function db()
	return YQ.db.profile
end

local function place()
	if not holder then
		return
	end
	placing = true
	WatchFrame:ClearAllPoints()
	WatchFrame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
	WatchFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
	placing = nil
end

-- Our width, as Blizzard's globals for the expanded width and the line width.
local function applyWidth()
	local width = db().width
	WATCHFRAME_EXPANDEDWIDTH = width
	WATCHFRAME_MAXLINEWIDTH = width - 12
	if not WatchFrame.collapsed and math.abs(WatchFrame:GetWidth() - width) > 0.5 then
		WatchFrame:SetWidth(width) -- OnSizeChanged redraws it
	end
end

-- Line heights for the font size. Blizzard sizes lines from these globals.
local function applyFontMetrics()
	local size = db().fontSize
	WATCHFRAME_LINEHEIGHT = math.max(16, size + 4)
	WATCHFRAME_MULTIPLE_LINEHEIGHT = size * 2 + 5
	WATCHFRAMELINES_FONTHEIGHT = size
	WATCHFRAMELINES_FONTSPACING = (WATCHFRAME_LINEHEIGHT - size) / 2
end

-- Sets the font size on lines that don't have it yet. Returns true if any changed,
-- because their heights were measured with the old font and need a redraw.
local function fixFonts(lines, size)
	local changed
	for _, line in pairs(lines) do
		if line.yFontSize ~= size then
			line.yFontSize = size
			for _, fs in ipairs({ line.text, line.dash }) do
				local font, _, flags = fs:GetFont()
				fs:SetFont(font, size, flags)
			end
			changed = true
		end
	end
	return changed
end

local redraw = CreateFrame("Frame")
redraw:Hide()
redraw:SetScript("OnUpdate", function(self)
	self:Hide()
	WatchFrame_Update(WatchFrame)
end)

-- Colours a quest's lines: the title by difficulty (with a [level] tag), the
-- objectives by progress. Called after every update and after the hover
-- highlight, which resets the colours.
local function colorQuest(button)
	if button.type ~= "QUEST" or not button.lines then
		return
	end
	local p = db()
	local questIndex = GetQuestIndexForWatch(button.index)
	if not questIndex then
		return
	end
	local title, level, questTag, _, _, _, isComplete, isDaily = GetQuestLogTitle(questIndex)
	for i = button.startLine, button.lastLine do
		local line = button.lines[i]
		if line then
			if i == button.startLine then
				if p.levelTags and title then
					local c = GetQuestDifficultyColor(level)
					line.text:SetText(YQ:LevelTag(level, questTag, isDaily) .. " " .. title)
					line.text:SetTextColor(c.r, c.g, c.b)
				end
			elseif p.colorObjectives then
				local have, need = (line.text:GetText() or ""):match("(%d+)/(%d+)")
				if isComplete and isComplete > 0 then
					line.text:SetTextColor(0.25, 1, 0.25)
				elseif have then
					line.text:SetTextColor(YQ:ProgressColor(tonumber(have), tonumber(need)))
				end
			end
		end
	end
end

local function hookLinkButton(button)
	if button.yHooked then
		return
	end
	button.yHooked = true
	button:HookScript("OnEnter", function(self)
		YQ:ShowTrackerTooltip(self)
	end)
	button:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function skinItemButton(button)
	if button.ySkinned then
		return
	end
	YB:SkinIconButton(button, _G[button:GetName() .. "IconTexture"])
	local hotkey = _G[button:GetName() .. "HotKey"]
	if hotkey then
		hotkey:ClearAllPoints()
		hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -2)
	end
end

-- The background covers what is shown: the header, plus the lines when expanded.
local function updateBackground()
	if not bg then
		return
	end
	local p = db()
	if p.bgAlpha <= 0 or not WatchFrameHeader:IsShown() then
		bg:Hide()
		return
	end
	local height = 26
	if not WatchFrame.collapsed and WatchFrame.nextOffset and WatchFrame.nextOffset < 0 then
		height = 30 - WatchFrame.nextOffset + 4
	end
	bg:SetHeight(math.min(height, WatchFrame:GetHeight()))
	bg:SetBackdropColor(0, 0, 0, p.bgAlpha)
	bg:Show()
end

local function onUpdate()
	local p = db()
	applyWidth()
	local size = p.fontSize
	local a = fixFonts(WATCHFRAME_QUESTLINES, size)
	local b = fixFonts(WATCHFRAME_ACHIEVEMENTLINES, size)
	local c = fixFonts(WATCHFRAME_TIMERLINES, size)
	if a or b or c then
		redraw:Show()
	end
	for i = 1, WATCHFRAME_NUM_ITEMS do
		local button = _G["WatchFrameItem" .. i]
		if button then
			skinItemButton(button)
		end
	end
	for _, button in pairs(WATCHFRAME_LINKBUTTONS) do
		hookLinkButton(button)
		if button:IsShown() then
			colorQuest(button)
		end
	end
	updateBackground()
end

local function updateToggle()
	if not toggle then
		return
	end
	toggle.text:SetText(WatchFrame.collapsed and "+" or "-")
	if WatchFrameCollapseExpandButton:IsEnabled() == 1 then
		toggle.text:SetTextColor(1, 0.82, 0)
	else
		toggle.text:SetTextColor(0.5, 0.5, 0.5)
	end
	updateBackground()
end

-- Flat look for the header's collapse button. Blizzard keeps setting tex coords on
-- its textures, so they stay (invisible) and a +/- label is drawn instead.
local function styleHeader()
	local button = WatchFrameCollapseExpandButton
	for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(),
		button:GetDisabledTexture(), button:GetHighlightTexture() }) do
		tex:SetAlpha(0)
	end
	toggle = CreateFrame("Frame", nil, button)
	toggle:SetAllPoints(button)
	YB:SquareBackdrop(toggle, 0.5)
	toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toggle.text:SetPoint("CENTER", 1, 0)
	button:HookScript("OnEnter", function()
		toggle:SetBackdropBorderColor(1, 0.82, 0, 1)
	end)
	button:HookScript("OnLeave", function()
		toggle:SetBackdropBorderColor(0, 0, 0, 1)
	end)
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", WatchFrame, "TOPRIGHT", -4, -5)
	button:SetWidth(14)
	button:SetHeight(14)
	updateToggle()
end

-- Auto-collapse in combat and in instances. While we hold it collapsed it is marked
-- as collapsed by the user, otherwise Blizzard's next update expands it again.
local auto = { active = false, userCollapsed = nil }

function YQ:UpdateAutoCollapse()
	if not holder then
		return
	end
	local p = db()
	local _, instanceType = IsInInstance()
	local want = (p.collapseCombat and (InCombatLockdown() or UnitAffectingCombat("player")))
		or (p.collapseDungeon and instanceType == "party")
		or (p.collapseRaid and instanceType == "raid")
		or (p.collapsePvP and (instanceType == "pvp" or instanceType == "arena"))
	if want and not auto.active then
		if not WatchFrame.collapsed then
			auto.active = true
			auto.userCollapsed = WatchFrame.userCollapsed
			WatchFrame.userCollapsed = true
			WatchFrame_Collapse(WatchFrame)
		end
	elseif not want and auto.active then
		auto.active = false
		WatchFrame.userCollapsed = auto.userCollapsed
		if WatchFrame.collapsed and not WatchFrame.userCollapsed then
			WatchFrame_Expand(WatchFrame)
		end
	end
end

function YQ:EnableTracker()
	holder = CreateFrame("Frame", "yancerQuestsTracker", UIParent)
	holder:SetFrameStrata("LOW")
	YB:CreateMover(holder, "Quest Tracker", function(point, relPoint, x, y)
		local p = db()
		p.point, p.relPoint, p.x, p.y = point, relPoint, x, y
		YQ:UpdateTracker()
	end, function()
		YB:OpenOptions("quests", "tracker")
	end)

	bg = CreateFrame("Frame", nil, WatchFrame)
	bg:SetFrameLevel(WatchFrame:GetFrameLevel())
	bg:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", -6, 0)
	bg:SetPoint("TOPRIGHT", WatchFrame, "TOPRIGHT", 0, 0)
	YB:SquareBackdrop(bg, db().bgAlpha)
	YB:Outline(bg)
	bg:Hide()

	-- Blizzard only skips its own placement for user-placed frames, and still sets a
	-- BOTTOMRIGHT point afterwards, so every foreign SetPoint is undone.
	WatchFrame:SetMovable(true)
	WatchFrame:SetUserPlaced(true)
	WatchFrame:SetClampedToScreen(false)
	hooksecurefunc(WatchFrame, "SetPoint", function()
		if not placing then
			place()
		end
	end)
	hooksecurefunc("WatchFrame_SetWidth", applyWidth)
	hooksecurefunc("WatchFrame_Update", onUpdate)
	hooksecurefunc("WatchFrame_Collapse", updateToggle)
	hooksecurefunc("WatchFrame_Expand", updateToggle)
	hooksecurefunc("WatchFrameLinkButtonTemplate_Highlight", function(button, onEnter)
		if not onEnter then
			colorQuest(button)
		end
	end)
	-- The user clicked the button: their choice wins over auto-collapse.
	hooksecurefunc("WatchFrame_CollapseExpandButton_OnClick", function()
		auto.active = false
		updateToggle()
	end)
	styleHeader()

	self:RegisterEvent("PLAYER_REGEN_DISABLED", "UpdateAutoCollapse")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateAutoCollapse")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateAutoCollapse")
	self:UpdateTracker()
end

function YQ:UpdateTracker()
	if not holder then
		return
	end
	local p = db()
	local d = YQ.db.defaults.profile
	holder:SetScale(p.scale)
	WatchFrame:SetScale(p.scale)
	holder:SetWidth(p.width)
	holder:SetHeight(p.height)
	holder:ClearAllPoints()
	holder:SetPoint(p.point or d.point, UIParent, p.relPoint or d.relPoint, p.x or d.x, p.y or d.y)
	place()
	applyFontMetrics()
	applyWidth()
	WatchFrame_Update(WatchFrame)
	self:UpdateAutoCollapse()
end
