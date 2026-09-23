local addonName, ns = ...

-- yancer-chat builds on yancer-bars: movers, grid, lock, outlines and the /yb window.
local YB = LibStub("AceAddon-3.0"):GetAddon("yancer-bars")
local YC = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
ns.YC, ns.YB = YC, YB
_G.YancerChat = YC -- exposed for /run debugging

local defaults = {
	profile = {
		-- Style
		square = true,        -- flat square background, no Blizzard frame art
		bgAlpha = 0.5,
		hideButtons = true,   -- scroll, menu and friends buttons
		editBoxTop = false,   -- input box above the chat instead of below
		-- Position & size of the main chat window (and the windows docked to it)
		manage = true,
		point = "BOTTOMLEFT",
		relPoint = "BOTTOMLEFT",
		x = 16,
		y = 36,
		width = 430,
		height = 180,
		-- Messages
		classColors = true,
		shortChannels = true,
		timestamps = "none", -- "none" or a date() format, e.g. "%H:%M "
		urls = true,
		copyButton = true,
		-- Scrolling & fading
		scrollLines = 3,
		maxLines = 500,
		fading = true,
		fadeTime = 120,
	},
}

-- The chat windows yancer-chat works on (ChatFrame1..NUM_CHAT_WINDOWS).
function YC:ChatFrames()
	local frames = {}
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. i]
		if frame then
			frames[#frames + 1] = frame
		end
	end
	return frames
end

function YC:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("yancerChatDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
	self.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
	self.db.RegisterCallback(self, "OnProfileReset", "Refresh")
	self:SetupOptions()
end

function YC:OnEnable()
	self:Refresh()
end

function YC:Refresh()
	self:ApplyStyle()
	self:ApplyPosition()
	self:ApplyMessages()
	self:ApplyScrolling()
	self:ApplyCopyButtons()
end
