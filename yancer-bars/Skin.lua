local _, ns = ...
local YB = ns.YB

-- Gives Blizzard's other UI pieces the same square look as our bars: square
-- cropped icons with a thin border and flat highlights (stance, pet, possess and
-- totem buttons, bags, buffs/debuffs), and flat status bars with a border (XP,
-- reputation, cast bar), plus the micro menu. All of them get the shared outline.
-- Undoing it needs a /reload.

local outlined = {} -- frames carrying the shared outline, re-drawn when its settings change

local function outline(frame)
	outlined[frame] = true
	local p = YB.db.profile
	YB:UpdateShadow(frame, p.skinOutlineSize, p.skinOutlineColor, p.skinOutlineStyle)
end

function YB:UpdateSkinOutlines()
	for frame in pairs(outlined) do
		outline(frame)
	end
end

local function squareBackdrop(frame)
	frame:SetBackdrop({ bgFile = YB.WHITE, edgeFile = YB.WHITE, edgeSize = 1 })
	frame:SetBackdropColor(0, 0, 0, 0.5)
	frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function hide(name)
	local region = _G[name]
	if region then
		region:SetAlpha(0)
	end
end

-- Removes Blizzard's rounded slot art. Some Blizzard updates put it back, so
-- this is also called from hooks.
function YB:StripNormal(button)
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetTexture(nil)
	end
	local normal2 = _G[button:GetName() .. "NormalTexture2"]
	if normal2 then
		normal2:SetTexture(nil)
	end
end

-- Square icon button. icon is the button's icon texture.
function YB:SkinIconButton(button, icon)
	if not button or button.ySkinned then
		return
	end
	button.ySkinned = true
	local zoom = self.db.profile.iconZoom
	squareBackdrop(button)
	if icon then
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	end
	local area = icon or button
	if button.GetNormalTexture then
		self:StripNormal(button)
	end
	local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
	if highlight then
		highlight:SetTexture(self.WHITE)
		highlight:SetVertexColor(1, 1, 1, 0.2)
		highlight:ClearAllPoints()
		highlight:SetAllPoints(area)
	end
	local pushed = button.GetPushedTexture and button:GetPushedTexture()
	if pushed then
		pushed:SetTexture(self.WHITE)
		pushed:SetVertexColor(0, 0, 0, 0.4)
		pushed:ClearAllPoints()
		pushed:SetAllPoints(area)
	end
	local checked = button.GetCheckedTexture and button:GetCheckedTexture()
	if checked then
		checked:SetTexture(self.WHITE)
		checked:SetVertexColor(1, 0.82, 0, 0.35)
		checked:ClearAllPoints()
		checked:SetAllPoints(area)
	end
	local cooldown = _G[button:GetName() .. "Cooldown"]
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(area)
	end
	outline(button)
end

-- Flat status bar with a square border behind it; artNames are hidden.
function YB:SkinStatusBar(bar, artNames)
	if not bar or bar.ySkinned then
		return
	end
	bar.ySkinned = true
	bar:SetStatusBarTexture(self.WHITE)
	local bg = CreateFrame("Frame", nil, bar)
	bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
	bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	-- Level 0 keeps it under the fill even when Blizzard changes the bar's level (reputation bar).
	bg:SetFrameLevel(0)
	squareBackdrop(bg)
	outline(bg)
	for _, name in ipairs(artNames or {}) do
		hide(name)
	end
end

local function skinButtons(prefix, count, iconSuffix)
	for i = 1, count do
		local button = _G[prefix .. i]
		if button then
			YB:SkinIconButton(button, _G[prefix .. i .. (iconSuffix or "Icon")])
		end
	end
end

-- Aura buttons are created on demand; debuffs keep their type colour on the border.
local function skinAura(button, border, r, g, b)
	YB:SkinIconButton(button, _G[button:GetName() .. "Icon"])
	if border then
		border:SetAlpha(0)
		if not r then
			r, g, b = border:GetVertexColor()
		end
		button:SetBackdropBorderColor(r, g, b, 1)
	end
end

-- Micro menu: each button's image is 28x58 with the icon in the bottom half.
-- Crop the images to that icon area and give it a square frame.
local MICRO_BUTTONS = {
	"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton",
	"QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton", "LFDMicroButton",
	"MainMenuMicroButton", "HelpMicroButton",
}

local function skinMicroButton(button)
	local frame = CreateFrame("Frame", nil, button)
	frame:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 0)
	frame:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -28)
	frame:SetFrameLevel(math.max(button:GetFrameLevel() - 1, 0))
	squareBackdrop(frame)
	outline(frame)

	local isCharacter = button == _G.CharacterMicroButton
	for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture() }) do
		if isCharacter then
			tex:SetAlpha(0) -- only a ring around the portrait
		else
			tex:SetTexCoord(0.17, 0.87, 0.5, 0.908)
			tex:ClearAllPoints()
			tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
			tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
		end
	end
	local highlight = button:GetHighlightTexture()
	highlight:SetTexture(YB.WHITE)
	highlight:SetVertexColor(1, 1, 1, 0.2)
	highlight:ClearAllPoints()
	highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	highlight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	button.yInner = frame
end

local function skinMicroMenu()
	for _, name in ipairs(MICRO_BUTTONS) do
		if _G[name] then
			skinMicroButton(_G[name])
		end
	end
	local portrait = _G.MicroButtonPortrait
	portrait:ClearAllPoints()
	portrait:SetPoint("TOPLEFT", _G.CharacterMicroButton.yInner, "TOPLEFT", 1, -1)
	portrait:SetPoint("BOTTOMRIGHT", _G.CharacterMicroButton.yInner, "BOTTOMRIGHT", -1, 1)

	local emblem = _G.PVPMicroButtonTexture
	if emblem then
		emblem:ClearAllPoints()
		emblem:SetPoint("CENTER", _G.PVPMicroButton.yInner, "CENTER", 0, 0)
		emblem:SetWidth(28)
		emblem:SetHeight(28)
	end

	-- Latency: a thin coloured stripe along the bottom of the menu button.
	local latency = _G.MainMenuBarPerformanceBar
	if latency then
		latency:SetTexture(YB.WHITE)
		latency:ClearAllPoints()
		latency:SetPoint("BOTTOMLEFT", _G.MainMenuMicroButton.yInner, "BOTTOMLEFT", 1, 1)
		latency:SetPoint("BOTTOMRIGHT", _G.MainMenuMicroButton.yInner, "BOTTOMRIGHT", -1, 1)
		latency:SetHeight(2)
	end
end

function YB:SkinElements()
	if self.elementsSkinned or not self.db.profile.skinElements then
		return
	end
	self.elementsSkinned = true

	skinButtons("ShapeshiftButton", 10)
	skinButtons("PetActionButton", 10)
	skinButtons("PossessButton", 2)
	skinButtons("MultiCastActionButton", 12)
	self:SkinIconButton(_G.MultiCastSummonSpellButton, _G.MultiCastSummonSpellButtonIcon)
	self:SkinIconButton(_G.MultiCastRecallSpellButton, _G.MultiCastRecallSpellButtonIcon)

	self:SkinIconButton(_G.MainMenuBarBackpackButton, _G.MainMenuBarBackpackButtonIconTexture)
	for i = 0, 3 do
		self:SkinIconButton(_G["CharacterBag" .. i .. "Slot"], _G["CharacterBag" .. i .. "SlotIconTexture"])
	end

	for i = 1, 3 do
		local button = _G["TempEnchant" .. i]
		if button then
			skinAura(button, _G["TempEnchant" .. i .. "Border"], 0.6, 0.2, 0.8)
		end
	end

	local xpArt = { "MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3" }
	for i = 1, 19 do
		xpArt[#xpArt + 1] = "MainMenuXPBarDiv" .. i
	end
	self:SkinStatusBar(_G.MainMenuExpBar, xpArt)
	if _G.ExhaustionLevelFillBar then
		_G.ExhaustionLevelFillBar:SetTexture(self.WHITE)
	end
	_G.MainMenuBarMaxLevelBar:SetAlpha(0)

	self:SkinStatusBar(_G.ReputationWatchStatusBar, {
		"ReputationWatchBarTexture0", "ReputationWatchBarTexture1",
		"ReputationWatchBarTexture2", "ReputationWatchBarTexture3",
		"ReputationXPBarTexture0", "ReputationXPBarTexture1",
		"ReputationXPBarTexture2", "ReputationXPBarTexture3",
	})

	skinMicroMenu()

	self:SkinStatusBar(_G.CastingBarFrame, { "CastingBarFrameBorder", "CastingBarFrameFlash", "CastingBarFrameBorderShield" })
	_G.CastingBarFrameText:ClearAllPoints()
	_G.CastingBarFrameText:SetPoint("CENTER", _G.CastingBarFrame, "CENTER", 0, 0)
end

hooksecurefunc("AuraButton_Update", function(buttonName, index)
	if not YB.elementsSkinned then
		return
	end
	local button = _G[buttonName .. index]
	if button then
		skinAura(button, _G[buttonName .. index .. "Border"])
	end
end)

-- The pet bar re-applies its rounded slot art on every update.
hooksecurefunc("PetActionBar_Update", function()
	if not YB.elementsSkinned then
		return
	end
	for i = 1, 10 do
		local button = _G["PetActionButton" .. i]
		if button and button.ySkinned then
			YB:StripNormal(button)
		end
	end
end)
