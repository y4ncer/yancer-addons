local _, ns = ...
local YC = ns.YC

-- Every chat window's AddMessage is wrapped to shorten channel names, turn URLs
-- into clickable links and remember recent lines for the copy window.

local HISTORY = 300 -- lines kept per window for "Copy Chat"

-- [Guild] -> [G], [2. Trade - City] -> [2], ...
local SHORT_CHANNELS = {
	["Guild"] = "G",
	["Officer"] = "O",
	["Party"] = "P",
	["Party Leader"] = "PL",
	["Dungeon Guide"] = "DG",
	["Raid"] = "R",
	["Raid Leader"] = "RL",
	["Raid Warning"] = "RW",
	["Battleground"] = "BG",
	["Battleground Leader"] = "BL",
}

local function shortChannel(link, label)
	local short = label:match("^(%d+)%.") or SHORT_CHANNELS[label]
	if not short then
		return nil -- keep the original
	end
	return "|Hchannel:" .. link .. "|h[" .. short .. "]|h"
end

local URL_PATTERNS = {
	"(%a[%w+.-]*://[^%s|]+)", -- scheme://...
	"(www%.[%w_-]+%.[^%s|]+)", -- www.example.com/...
}

local function linkURLs(text)
	for _, pattern in ipairs(URL_PATTERNS) do
		text = text:gsub(pattern, "|cff33ccff|Hurl:%1|h[%1]|h|r")
	end
	return text
end

local function addMessage(frame, text, ...)
	if type(text) == "string" then
		local db = YC.db.profile
		if db.shortChannels then
			text = text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", shortChannel)
		end
		if db.urls and not text:find("|Hurl:", 1, true) then
			text = linkURLs(text)
		end
		local history = frame.yHistory
		history[#history + 1] = text
		if #history > HISTORY then
			table.remove(history, 1)
		end
	end
	return frame.yAddMessage(frame, text, ...)
end

-- Clicking a URL opens a box with it selected, ready for Ctrl+C.
local origSetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame) -- luacheck: ignore 121
	if link:sub(1, 4) == "url:" then
		YC:ShowURL(link:sub(5))
		return
	end
	return origSetItemRef(link, text, button, chatFrame)
end

-- Chat types whose sender names are coloured by class when the option is on.
local CLASS_COLOR_TYPES = {
	"SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "ACHIEVEMENT",
	"WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"BATTLEGROUND", "BATTLEGROUND_LEADER",
}

function YC:ApplyMessages()
	local db = self.db.profile
	for _, frame in ipairs(self:ChatFrames()) do
		-- ChatFrame2 is the combat log: leave its messages alone.
		if frame ~= _G.ChatFrame2 and not frame.yAddMessage then
			frame.yAddMessage = frame.AddMessage
			frame.yHistory = {}
			frame.AddMessage = addMessage
		end
	end

	if db.classColors ~= self.appliedClassColors then
		self.appliedClassColors = db.classColors
		for _, chatType in ipairs(CLASS_COLOR_TYPES) do
			SetChatColorNameByClass(chatType, db.classColors)
		end
		for i = 1, 10 do
			SetChatColorNameByClass("CHANNEL" .. i, db.classColors)
		end
	end

	-- Blizzard reads the timestamp format from this CVar and global.
	SetCVar("showTimestamps", db.timestamps)
	_G.CHAT_TIMESTAMP_FORMAT = db.timestamps ~= "none" and db.timestamps or nil
end
