local addonName, ns = ...

-- yancer-bags builds on yancer-bars: movers, grid, lock, outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YG = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YG, ns.YB = YG, YB
_G.YancerBags = YG -- exposed for /run debugging

local defaults = {
	profile = {
		enabled = true,       -- one bag instead of Blizzard's bag windows (turning it off needs a /reload)
		columns = 12,
		buttonSize = 34,
		spacing = 3,
		scale = 1,
		bgAlpha = 0.7,
		qualityBorders = true, -- border in the item quality colour (uncommon and better)
		point = "BOTTOMRIGHT",
		relPoint = "BOTTOMRIGHT",
		x = -40,
		y = 90,
	},
}

function YG:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerBagsDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YG:OnEnable()
	if not self.db.profile.enabled then
		return
	end
	self:CreateBagFrame()
	self:InstallHooks()

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN", "UpdateCooldowns")
	self:RegisterEvent("PLAYER_MONEY", "UpdateMoney")
	self:RegisterEvent("QUEST_ACCEPTED", "UpdateIfShown")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "UpdateIfShown")

	-- While bars are unlocked the bag shows, so it can be placed.
	hooksecurefunc(YB, "SetLocked", function(_, locked)
		if not locked then
			YG:Open()
		end
	end)
	self:Refresh()
end

function YG:Refresh()
	if not self.frame then
		return
	end
	self:Layout()
	self:UpdateIfShown()
end

-- Several bags change at once (e.g. looting): update once, on the next frame.
local pending = CreateFrame("Frame")
pending:Hide()
pending:SetScript("OnUpdate", function(self)
	self:Hide()
	YG:Layout()
	YG:UpdateAll()
end)

function YG:BAG_UPDATE(_, bag)
	if self.frame:IsShown() and bag and bag >= 0 and bag <= NUM_BAG_SLOTS then
		pending:Show()
	end
end

function YG:ITEM_LOCK_CHANGED(_, bag, slot)
	if self.frame:IsShown() and bag and slot then
		self:UpdateLock(bag, slot)
	end
end

function YG:UpdateIfShown()
	if self.frame and self.frame:IsShown() then
		pending:Show()
	end
end
