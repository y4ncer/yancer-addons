local addonName, ns = ...

-- yancer-minimap builds on yancer-bars: movers, grid, lock, outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YM = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YM, ns.YB = YM, YB
_G.YancerMinimap = YM -- exposed for /run debugging

local defaults = {
	profile = {
		-- Minimap (turning it off needs a /reload)
		minimap = true,
		shape = "round",     -- "round" or "square"
		size = 140,
		scale = 1,
		zoneText = true,
		clock = true,
		localTime = true,    -- local time instead of server time
		hideButtons = true,  -- zoom buttons, world map button, calendar (mouse wheel zooms instead)
		hideTracking = true, -- the tracking button (right-click the map instead)
		point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -30, y = -30,
		-- Info text: FPS, latency, durability
		info = true,
		showFPS = true,
		showLatency = true,
		showDurability = true,
		infoFontSize = 14,
		infoPoint = "TOP", infoRelPoint = "TOP", infoX = 300, infoY = -20,
	},
}

function YM:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerMinimapDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YM:OnEnable()
	if self.db.profile.minimap then
		self:EnableMinimap()
	end
	if self.db.profile.info then
		self:EnableInfoText()
	end
	self:Refresh()
end

function YM:Refresh()
	self:UpdateMinimap()
	self:UpdateInfoText()
end

-- Saved position, or the default when it was reset.
function YM:Position(prefix)
	local p, d = self.db.profile, self.db.defaults.profile
	local function get(key)
		local k = prefix and (prefix .. key:sub(1, 1):upper() .. key:sub(2)) or key
		if p[k] == nil then
			return d[k]
		end
		return p[k]
	end
	return get("point"), get("relPoint"), get("x"), get("y")
end

function YM:SavePosition(prefix, point, relPoint, x, y)
	local p = self.db.profile
	if prefix then
		p[prefix .. "Point"], p[prefix .. "RelPoint"], p[prefix .. "X"], p[prefix .. "Y"] = point, relPoint, x, y
	else
		p.point, p.relPoint, p.x, p.y = point, relPoint, x, y
	end
end
