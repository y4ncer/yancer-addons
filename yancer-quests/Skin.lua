local _, ns = ...
local YQ, YB = ns.YQ, ns.YB

-- Square style for the quest log, the NPC quest dialog and the gossip window:
-- Blizzard's parchment and frame art are hidden (alpha 0, because Blizzard
-- re-sets some of the textures), a square backdrop with the shared outline
-- goes behind them, and the dark quest text turns light so it reads on it.
-- Undoing it needs a /reload.

local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }

-- Hides every texture of these frames (their own regions only, not their children's).
local function strip(...)
	for i = 1, select("#", ...) do
		local frame = select(i, ...)
		frame = type(frame) == "string" and _G[frame] or frame
		if frame then
			for _, region in ipairs({ frame:GetRegions() }) do
				if region:GetObjectType() == "Texture" then
					region:SetAlpha(0)
				end
			end
		end
	end
end

-- The art has transparent margins: the backdrop goes on the visible part.
local function backdrop(frame, left, top, right, bottom)
	local bd = CreateFrame("Frame", nil, frame)
	bd:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
	bd:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
	YB:SquareBackdrop(bd, 0.85)
	YB:Outline(bd)
	return bd
end

-- UIPanelButtonTemplate: flat button. Blizzard swaps the Left/Middle/Right
-- textures on press, so they are made invisible rather than cleared.
local function skinButton(name)
	local button = _G[name]
	if not button or button.ySkinned then
		return
	end
	button.ySkinned = true
	for _, part in ipairs({ "Left", "Middle", "Right" }) do
		local tex = _G[name .. part]
		if tex then
			tex:SetAlpha(0)
		end
	end
	for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture() }) do
		tex:SetAlpha(0)
	end
	YB:SquareBackdrop(button, 0.6)
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetTexture(YB.WHITE)
		highlight:SetVertexColor(1, 1, 1, 0.15)
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", 1, -1)
		highlight:SetPoint("BOTTOMRIGHT", -1, 1)
	end
end

-- Quest reward/required item buttons (QuestItemTemplate): square cropped icon with
-- a border, no name plate.
local function skinItem(name)
	local button = _G[name]
	if not button or button.ySkinned then
		return
	end
	button.ySkinned = true
	local icon = _G[name .. "IconTexture"]
	local plate = _G[name .. "NameFrame"]
	if plate then
		plate:SetAlpha(0)
	end
	if icon then
		local zoom = YB.db.profile.iconZoom
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		local border = CreateFrame("Frame", nil, button)
		border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		YB:SquareBackdrop(border, 0)
		YB:Outline(border)
	end
end

local function color(fontString, c)
	if fontString then
		fontString:SetTextColor(c[1], c[2], c[3])
	end
end

local function skinItems()
	for i = 1, MAX_NUM_ITEMS do
		skinItem("QuestInfoItem" .. i)
	end
	for i = 1, MAX_REQUIRED_ITEMS do
		skinItem("QuestProgressItem" .. i)
	end
	skinItem("QuestInfoRewardSpell")
end

-- QuestInfo (quest log details and the NPC dialog) colours its text from the
-- parchment "material" and the objectives black/grey.
local function recolorQuestInfo()
	for _, name in ipairs({ "QuestInfoTitleHeader", "QuestInfoDescriptionHeader",
		"QuestInfoObjectivesHeader", "QuestInfoRewardsHeader" }) do
		color(_G[name], GOLD)
	end
	for _, name in ipairs({ "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoGroupSize",
		"QuestInfoRewardText", "QuestInfoItemChooseText", "QuestInfoItemReceiveText", "QuestInfoSpellLearnText",
		"QuestInfoHonorFrameReceiveText", "QuestInfoArenaPointsFrameReceiveText",
		"QuestInfoTalentFrameReceiveText", "QuestInfoXPFrameReceiveText", "QuestInfoRequiredMoneyText" }) do
		color(_G[name], WHITE)
	end
	for i = 1, MAX_OBJECTIVES do
		local objective = _G["QuestInfoObjective" .. i]
		if objective then
			local _, _, finished = GetQuestLogLeaderBoard(i)
			color(objective, finished and { 0.5, 0.5, 0.5 } or WHITE)
		end
	end
	skinItems()
end

function YQ:SkinQuestFrames()
	-- Quest log (both panes) and its detail-only window.
	strip(QuestLogFrame, QuestLogDetailFrame, QuestLogCount, EmptyQuestLogFrame,
		QuestLogDetailScrollFrame, QuestLogScrollFrame)
	backdrop(QuestLogFrame, 10, -12, -1, 6)
	backdrop(QuestLogDetailFrame, 10, -12, -1, 4)
	for _, name in ipairs({ "QuestLogFrameAbandonButton", "QuestLogFrameTrackButton",
		"QuestLogFramePushQuestButton", "QuestLogFrameCancelButton" }) do
		skinButton(name)
	end

	-- NPC quest dialog (greeting, details, progress, rewards).
	strip(QuestFrame, QuestNpcNameFrame, QuestFrameGreetingPanel, QuestFrameDetailPanel,
		QuestFrameProgressPanel, QuestFrameRewardPanel, QuestGreetingScrollFrame, QuestDetailScrollFrame,
		QuestProgressScrollFrame, QuestRewardScrollFrame)
	backdrop(QuestFrame, 12, -14, -30, 66)
	for _, name in ipairs({ "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
		"QuestFrameGoodbyeButton", "QuestFrameCompleteQuestButton", "QuestFrameCancelButton",
		"QuestFrameGreetingGoodbyeButton" }) do
		skinButton(name)
	end

	-- Gossip.
	strip(GossipFrame, GossipNpcNameFrame, GossipFrameGreetingPanel, GossipGreetingScrollFrame)
	backdrop(GossipFrame, 12, -14, -30, 66)
	skinButton("GossipFrameGreetingGoodbyeButton")

	-- Text: the quest fonts are dark brown for parchment. The font objects are
	-- changed, and the places that colour text themselves are hooked.
	for _, font in ipairs({ QuestFont, QuestFontLeft, QuestFontNormalSmall }) do
		font:SetTextColor(1, 1, 1)
	end
	QuestTitleFont:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	QuestTitleFont:SetShadowColor(0, 0, 0, 1)
	hooksecurefunc("QuestInfo_Display", recolorQuestInfo)
	hooksecurefunc("QuestFrame_SetTitleTextColor", function(fontString)
		color(fontString, GOLD)
	end)
	hooksecurefunc("QuestFrame_SetTextColor", function(fontString)
		color(fontString, WHITE)
	end)
	hooksecurefunc("QuestFrameProgressItems_Update", function()
		color(QuestProgressRequiredMoneyText, WHITE)
		skinItems()
	end)
	hooksecurefunc("GossipFrameUpdate", function()
		color(GossipGreetingText, WHITE)
	end)
	skinItems()
end
