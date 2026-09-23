local addonName, ns = ...

local YB = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.YB = YB
_G.YancerBars = YB -- exposed for /run debugging

YB.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
YB.WHITE = "Interface\\Buttons\\WHITE8X8"
YB.FONT = "Fonts\\FRIZQT__.TTF"
YB.NUMBER_FONT = "Fonts\\ARIALN.TTF"
YB.MAX_BARS = 10 -- Bindings.xml declares keybinds for this many bars
YB.MAX_BUTTONS = 12

local defaults = {
	profile = {
		locked = true,
		defaultsVersion = 0,       -- 2 = Blizzard's five bars have been created
		checkBlizzardBars = false, -- match new default bars to Blizzard's settings after login
		hideBlizzard = true,
		style = "clean", -- "clean" (square) or "blizzard" button look
		iconZoom = 0.08, -- square style: fraction cropped off each icon edge
		rangeColoring = true,
		cooldownMinDuration = 2, -- shorter cooldowns (the global cooldown) get no timer text
		moveGrid = true,
		snapToGrid = true,
		gridSize = 16,
		bars = {
			-- Defaults for every bar. "name" is deliberately left out: it is
			-- always set explicitly, which keeps AceDB from pruning a bar
			-- whose other values all match these defaults.
			["**"] = {
				enabled = true,
				page = 1,         -- action page 1-10 (12 slots each)
				paging = false,   -- main-bar paging: stances/forms, possess, Shift+1-6
				shadowDance = true, -- rogues: with paging, Shadow Dance uses the Stealth page
				hideInVehicle = true,
				visibility = "always", -- "always", "combat" or "custom"
				visibilityCustom = "[combat] show; hide", -- macro conditions, used with "custom"
				alpha = 1,
				mouseover = false,  -- fade to fadeAlpha unless the mouse is over the bar
				fadeAlpha = 0,
				showGrid = true,  -- show empty buttons
				growth = "down",  -- extra rows go "down" or "up"
				numButtons = 12,
				perRow = 12,
				buttonSize = 36,
				spacing = 4,
				padding = 4,
				point = "BOTTOM",
				relPoint = "BOTTOM",
				x = 0,
				y = 60,
				strata = "LOW",
				level = 1,
				bgColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.85 },
				borderColor = { r = 0, g = 0, b = 0, a = 1 },
				borderSize = 1,
				shadowStyle = "outline", -- bar and button borders: "outline" (solid) or "soft"
				shadow = {
					enabled = true,
					size = 2,
					color = { r = 0, g = 0, b = 0, a = 0.9 },
				},
				buttonShadow = true,
				buttonShadowSize = 1,
				buttonBgColor = { r = 0, g = 0, b = 0, a = 0.5 },
				buttonBorderColor = { r = 0, g = 0, b = 0, a = 1 },
				hotkeyFontSize = 12,
				macroFontSize = 10,
				countFontSize = 14,
				showHotkeys = true,
				showMacroText = true,
				showRangeDot = true, -- Blizzard's ● on unbound buttons while you have a target
				cooldownText = true,
			},
		},
	},
}

function YB:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerBarsDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")

	self:SetupOptions()

	self:RegisterChatCommand("yb", "SlashCommand")
	self:RegisterChatCommand("yancerbars", "SlashCommand")
end

function YB:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateBlizzardBindings")
	self:Refresh()
end

function YB:PLAYER_ENTERING_WORLD()
	self.enteredWorld = true
	self:ScheduleBlizzardCheck()
end

function YB:ScheduleBlizzardCheck()
	if self.enteredWorld and self.db.profile.checkBlizzardBars then
		self:After(2, function()
			YB:MatchBlizzardBarVisibility()
		end)
	end
end

-- Re-applies the whole profile. Called on login and whenever the profile changes.
-- Bars are secure frames, so this waits until combat ends if needed.
function YB:Refresh()
	if InCombatLockdown() then
		self.refreshPending = true
		return
	end
	local profile = self.db.profile
	if profile.hideBlizzard then
		self:HideBlizzardBars()
	end
	if profile.defaultsVersion < 2 then
		profile.defaultsVersion = 2
		profile.barsCreated = nil -- v0.3.0 flag
		if self:CreateDefaultBars() > 0 then
			profile.checkBlizzardBars = true
			self:ScheduleBlizzardCheck()
		end
	end
	self:UpdateAllBars()
	self:SetLocked(profile.locked)
	self:RefreshOptions()
end

function YB:PLAYER_REGEN_DISABLED()
	-- Secure bars can't be dragged in combat.
	if not self.db.profile.locked then
		self:SetLocked(true)
		self:Print("Bars locked for combat.")
	end
	self:RefreshOptions()
end

function YB:PLAYER_REGEN_ENABLED()
	if self.refreshPending then
		self.refreshPending = nil
		self:Refresh()
	else
		self:RefreshOptions()
	end
end

function YB:SlashCommand(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" or cmd == "config" then
		self:OpenOptions()
	elseif cmd == "unlock" then
		self:SetLocked(false)
	elseif cmd == "lock" then
		self:SetLocked(true)
	elseif cmd == "toggle" or cmd == "move" then
		self:SetLocked(not self.db.profile.locked)
	else
		self:Print("Commands:")
		self:Print("  /yb - open settings")
		self:Print("  /yb move - toggle moving bars")
		self:Print("  /yb lock | unlock")
	end
end
