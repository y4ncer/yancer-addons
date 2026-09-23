local addonName, ns = ...

-- yancer-frames builds on yancer-bars: movers, grid, lock, outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YF = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YF, ns.YB = YF, YB
_G.YancerFrames = YF -- exposed for /run debugging

YF.UNITS = { "player", "target", "focus" }
YF.UNIT_NAMES = { player = "Player", target = "Target", focus = "Focus" }
YF.frames = {} -- unit -> frame

local defaults = {
	profile = {
		bgAlpha = 0.6,
		fontSize = 11,
		units = {
			["**"] = {
				enabled = true,
				width = 220,
				healthHeight = 30,
				powerHeight = 10,
				showPower = true,
				scale = 1,
				-- Health & power
				classColor = true,     -- players: health in their class colour
				reactionColor = true,  -- NPCs: health in their reaction colour (hostile red, ...)
				healthColor = { r = 0.25, g = 0.75, b = 0.25 },
				healthText = "both",   -- "current", "percent", "both", "deficit", "none"
				powerText = "current", -- "current", "percent", "none"
				-- Portrait
				portrait = "3d",       -- "3d", "2d" or "none"
				portraitSide = "left",
				-- Text & icons
				showName = true,
				showLevel = true,
				showPvP = true,        -- Horde/Alliance/FFA flag icon
				showRaidIcon = true,
				showLeader = true,
				showStatus = true,     -- player: combat and resting icons
				-- Auras (above the frame)
				showAuras = true,
				auraSize = 22,
				maxAuras = 16,
				onlyMyDebuffs = false,
				-- Cast bar (below the frame)
				showCastBar = true,
				castBarHeight = 16,
				-- Target: rogue/druid combo points
				showComboPoints = true,
			},
			player = {
				point = "CENTER", relPoint = "CENTER", x = -280, y = -170,
				showAuras = false,     -- Blizzard's buff frame covers the player
				showCastBar = false,   -- Blizzard's cast bar (movable under UI Elements)
			},
			target = {
				point = "CENTER", relPoint = "CENTER", x = 280, y = -170,
				portraitSide = "right",
			},
			focus = {
				point = "CENTER", relPoint = "CENTER", x = -280, y = -40,
				width = 180, healthHeight = 24, powerHeight = 8,
				portrait = "none",
			},
		},
	},
}

function YF:GetUnitDB(unit)
	return self.db.profile.units[unit]
end

function YF:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerFramesDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YF:OnEnable()
	self:RegisterEvents()
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- Frames stay visible while moving bars so Target/Focus can be placed without a target.
	hooksecurefunc(YB, "SetLocked", function(_, locked)
		YF:SetTestMode(not locked)
	end)
	self:Refresh()
end

function YF:PLAYER_REGEN_ENABLED()
	if self.pending then
		self.pending = nil
		self:Refresh()
	end
end

-- Secure frames can only be created, resized and moved out of combat.
function YF:Refresh()
	if InCombatLockdown() then
		self.pending = true
		return
	end
	for _, unit in ipairs(self.UNITS) do
		local db = self:GetUnitDB(unit)
		if db.enabled then
			self:LayoutFrame(unit)
			self:HideBlizzard(unit)
		elseif self.frames[unit] then
			UnregisterUnitWatch(self.frames[unit])
			self.frames[unit]:Hide()
		end
	end
	self:SetTestMode(not YB.db.profile.locked)
	self:UpdateAll()
end

-- Blizzard's frames for a unit we replace. Undoing this needs a /reload.
local hidden = CreateFrame("Frame")
hidden:Hide()

local BLIZZARD = {
	player = { "PlayerFrame" },
	target = { "TargetFrame", "ComboFrame", "TargetFrameToT" },
	focus = { "FocusFrame", "FocusFrameToT" },
}

function YF:HideBlizzard(unit)
	for _, name in ipairs(BLIZZARD[unit]) do
		local frame = _G[name]
		if frame and frame:GetParent() ~= hidden then
			frame:UnregisterAllEvents()
			frame:SetParent(hidden)
		end
	end
	-- The pet frame, death knight runes and shaman totem timers live in PlayerFrame:
	-- keep them, under our frame (runes/totems first, the pet frame below them).
	if unit == "player" then
		local f = self.frames.player
		for _, name in ipairs({ "RuneFrame", "TotemFrame" }) do
			local frame = _G[name]
			if frame then
				frame:SetParent(UIParent)
				frame:ClearAllPoints()
				frame:SetPoint("TOP", f, "BOTTOM", 0, -6)
			end
		end
		PetFrame:SetParent(UIParent)
		PetFrame:ClearAllPoints()
		PetFrame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -16, -30)
	end
end

-- Test mode: while bars are unlocked every enabled frame is shown (with sample
-- values when the unit doesn't exist) so it can be placed.
function YF:SetTestMode(on)
	if InCombatLockdown() then
		self.pending = true
		return
	end
	self.testMode = on
	for unit, frame in pairs(self.frames) do
		if self:GetUnitDB(unit).enabled then
			if on then
				UnregisterUnitWatch(frame)
				frame:Show()
			else
				RegisterUnitWatch(frame)
			end
		end
	end
	self:UpdateAll()
end
