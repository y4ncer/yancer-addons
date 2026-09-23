local addonName, ns = ...

local YUI = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.YUI = YUI
_G.YancerUI = YUI -- exposed for /run debugging

YUI.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
YUI.WHITE = "Interface\\Buttons\\WHITE8X8"

local defaults = {
	profile = {
		locked = true,
		firstRun = true,
		panels = {
			-- Defaults for every panel. "name" is deliberately left out: it is
			-- always set explicitly, which keeps AceDB from pruning a panel
			-- whose other values all match these defaults.
			["**"] = {
				enabled = true,
				width = 250,
				height = 120,
				point = "CENTER",
				relPoint = "CENTER",
				x = 0,
				y = 0,
				strata = "BACKGROUND",
				level = 1,
				bgColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.85 },
				borderColor = { r = 0, g = 0, b = 0, a = 1 },
				borderSize = 1,
				shadow = {
					enabled = true,
					size = 8,
					color = { r = 0, g = 0, b = 0, a = 0.9 },
				},
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
	self:Refresh()
end

-- Re-applies the whole profile. Called on login and whenever the profile changes.
function YUI:Refresh()
	local profile = self.db.profile
	if profile.firstRun then
		profile.firstRun = false
		self:CreatePanel("Panel 1")
	end
	self:UpdateAllPanels()
	self:SetLocked(profile.locked)
	self:RefreshOptions()
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
		self:Print("  /yui move - toggle moving frames")
		self:Print("  /yui lock | unlock")
	end
end
