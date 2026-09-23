local addonName, ns = ...

local YUI = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.YUI = YUI
_G.YancerUI = YUI -- exposed for /run debugging

YUI.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
YUI.WHITE = "Interface\\Buttons\\WHITE8X8"
YUI.MAX_BARS = 10 -- Bindings.xml declares keybinds for this many bars
YUI.MAX_BUTTONS = 12

local defaults = {
	profile = {
		locked = true,
		barsCreated = false,
		style = "clean", -- "clean" or "blizzard" button look
		bars = {
			-- Defaults for every bar. "name" is deliberately left out: it is
			-- always set explicitly, which keeps AceDB from pruning a bar
			-- whose other values all match these defaults.
			["**"] = {
				enabled = true,
				page = 1,         -- action page 1-10 (12 slots each)
				paging = false,   -- main-bar paging: stances/forms, possess, Shift+1-6
				hideInVehicle = true,
				showGrid = true,  -- show empty buttons
				numButtons = 12,
				perRow = 12,
				buttonSize = 36,
				spacing = 4,
				padding = 4,
				point = "BOTTOM",
				relPoint = "BOTTOM",
				x = 0,
				y = 20,
				strata = "LOW",
				level = 1,
				bgColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.85 },
				borderColor = { r = 0, g = 0, b = 0, a = 1 },
				borderSize = 1,
				shadow = {
					enabled = true,
					size = 8,
					color = { r = 0, g = 0, b = 0, a = 0.9 },
				},
				buttonShadow = true,
				buttonShadowSize = 4,
			},
		},
	},
}

function YUI:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerUIDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")

	self:SetupOptions()

	self:RegisterChatCommand("yui", "SlashCommand")
	self:RegisterChatCommand("yancer", "SlashCommand")
end

function YUI:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:Refresh()
end

-- Re-applies the whole profile. Called on login and whenever the profile changes.
-- Bars are secure frames, so this waits until combat ends if needed.
function YUI:Refresh()
	if InCombatLockdown() then
		self.refreshPending = true
		return
	end
	local profile = self.db.profile
	-- Settings from v0.1.0 (plain panels), no longer used.
	profile.panels = nil
	profile.firstRun = nil

	if not profile.barsCreated then
		profile.barsCreated = true
		self:CreateDefaultBars()
	end
	self:UpdateAllBars()
	self:SetLocked(profile.locked)
	self:RefreshOptions()
end

function YUI:PLAYER_REGEN_DISABLED()
	-- Secure bars can't be dragged in combat.
	if not self.db.profile.locked then
		self:SetLocked(true)
		self:Print("Frames locked for combat.")
	end
	self:RefreshOptions()
end

function YUI:PLAYER_REGEN_ENABLED()
	if self.refreshPending then
		self.refreshPending = nil
		self:Refresh()
	else
		self:RefreshOptions()
	end
end

function YUI:SlashCommand(input)
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
		self:Print("  /yui - open options")
		self:Print("  /yui move - toggle moving bars")
		self:Print("  /yui lock | unlock")
	end
end
