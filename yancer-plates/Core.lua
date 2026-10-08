local addonName, ns = ...

-- yancer-plates builds on yancer-bars: outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YP = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YP, ns.YB = YP, YB
_G.YancerPlates = YP -- exposed for /run debugging

local defaults = {
	profile = {
		enabled = true,      -- turning it off needs a /reload
		width = 110,
		height = 9,
		castHeight = 7,
		fontSize = 9,
		classColors = true,  -- Blizzard's "class colours on enemy nameplates" setting
		classIcons = true,   -- class icon above player nameplates
		classIconSize = 22,
		healthText = "percent", -- "percent", "current", "none"
		showLevel = true,
		targetBorder = true, -- white border on your target's nameplate
		threatBorder = true, -- border in the threat colour (Blizzard's glow, hidden)
	},
}

function YP:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerPlatesDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YP:OnEnable()
	if not self.db.profile.enabled then
		return
	end
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateRoster")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateRoster")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateRoster")
	self:StartScanning()
	self:Refresh()
end

function YP:Refresh()
	if not self.db.profile.enabled then
		return
	end
	SetCVar("ShowClassColorInNameplate", self.db.profile.classColors and "1" or "0")
	self:UpdateAllPlates()
end
