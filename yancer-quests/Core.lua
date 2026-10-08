local addonName, ns = ...

-- yancer-quests builds on yancer-bars: movers, grid, lock, outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YQ = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YQ, ns.YB = YQ, YB
_G.YancerQuests = YQ -- exposed for /run debugging

local defaults = {
	profile = {
		-- Tracker (Blizzard's objective tracker, restyled; turning it off needs a /reload)
		tracker = true,
		width = 250,
		height = 500,
		scale = 1,
		fontSize = 12,
		bgAlpha = 0.35,
		levelTags = true,       -- "[12+] Title" in the quest's difficulty colour
		colorObjectives = true, -- red -> yellow -> green with progress
		collapseCombat = true,
		collapseDungeon = false,
		collapseRaid = true,
		collapsePvP = true,
		point = "TOPRIGHT",
		relPoint = "TOPRIGHT",
		x = -60,
		y = -250,
		-- Quest info (mobs to kill, mobs and objects that drop quest items)
		unitTooltip = true,
		objectTooltip = true,
		trackerTooltip = true,
		maxSources = 4,
		-- Square quest log, quest dialog and gossip window (undoing it needs a /reload)
		skin = true,
	},
}

function YQ:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerQuestsDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YQ:OnEnable()
	self:EnableQuestInfo()
	if self.db.profile.tracker then
		self:EnableTracker()
	end
	if self.db.profile.skin then
		self:SkinQuestFrames()
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function YQ:PLAYER_ENTERING_WORLD()
	self:QUEST_LOG_UPDATE()
	self:UpdateAutoCollapse()
end

function YQ:Refresh()
	self:UpdateTracker()
end

-- Progress colour: red at 0, yellow halfway, green when done.
function YQ:ProgressColor(have, need)
	local p = (need and need > 0) and math.min(have / need, 1) or 0
	if p >= 1 then
		return 0.25, 1, 0.25
	elseif p < 0.5 then
		return 1, 0.25 + p * 1.3, 0.2
	end
	return 1.9 - p * 1.8, 0.9, 0.2
end

-- "[12]", "[12+]" (elite/group), "[12D]" dungeon, "[12R]" raid, "[12H]" heroic, "[12P]" PvP,
-- with a "Y" on dailies. The tags are the English ones GetQuestLogTitle returns.
local TAGS = { Elite = "+", Group = "+", Dungeon = "D", Raid = "R", PvP = "P", Heroic = "H" }

function YQ:LevelTag(level, questTag, isDaily)
	local tag = questTag and TAGS[questTag] or ""
	if isDaily then
		tag = tag .. "Y"
	end
	return "[" .. (level or "?") .. tag .. "]"
end
