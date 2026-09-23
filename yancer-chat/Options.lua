local _, ns = ...
local YC, YB = ns.YC, ns.YB

local TIMESTAMPS = {
	["none"] = "None",
	["%H:%M "] = "15:04",
	["%H:%M:%S "] = "15:04:32",
	["%I:%M %p "] = "03:04 PM",
}

local function range(name, order, min, max, step, extra)
	local opt = { type = "range", name = name, order = order, min = min, max = max, step = step }
	for k, v in pairs(extra or {}) do
		opt[k] = v
	end
	return opt
end

local function header(name, order)
	return { type = "header", name = name, order = order }
end

function YC:SetupOptions()
	local function update()
		YC:Refresh()
	end
	local group = {
		type = "group", name = "Chat", order = 20, childGroups = "tab",
		get = function(info) return YC.db.profile[info[#info]] end,
		set = function(info, value)
			YC.db.profile[info[#info]] = value
			update()
		end,
		args = {
			look = {
				type = "group", name = "Look & Position", order = 1,
				args = {
					styleHeader = header("Style", 1),
					square = { type = "toggle", name = "Square Style", order = 2,
						desc = "Flat background with the shared outline instead of Blizzard's frame art. "
							.. "Turning it off needs a /reload.",
					},
					bgAlpha = range("Background Opacity", 3, 0, 1, 0.05, { isPercent = true }),
					hideButtons = { type = "toggle", name = "Hide Chat Buttons", order = 4,
						desc = "Hides the scroll, menu and friends buttons (scroll with the mouse wheel instead). "
							.. "Showing them again needs a /reload.",
					},
					editBoxTop = { type = "toggle", name = "Input Box Above Chat", order = 5 },
					positionHeader = header("Position & Size", 10),
					manage = { type = "toggle", name = "Move with yancer-chat", order = 11, width = "full",
						desc = "Place the main chat window with /yb move (windows docked to it follow). "
							.. "Blizzard's own tab dragging is locked while this is on.",
					},
					width = range("Width", 12, 200, 1000, 1, { disabled = function() return not YC.db.profile.manage end }),
					height = range("Height", 13, 80, 600, 1, { disabled = function() return not YC.db.profile.manage end }),
				},
			},
			messages = {
				type = "group", name = "Messages", order = 2,
				args = {
					classColors = { type = "toggle", name = "Class-Colored Names", order = 1, width = "full" },
					shortChannels = { type = "toggle", name = "Short Channel Names", order = 2, width = "full",
						desc = "[Guild] becomes [G], [2. Trade - City] becomes [2], and so on.",
					},
					timestamps = { type = "select", name = "Timestamps", order = 3, values = TIMESTAMPS },
					urls = { type = "toggle", name = "Clickable URLs", order = 4, width = "full",
						desc = "Web links in chat become clickable; clicking one shows it ready to copy.",
					},
					copyButton = { type = "toggle", name = "Copy Chat Button", order = 5, width = "full",
						desc = "A small C button on each chat window opens its recent lines as copyable text.",
					},
				},
			},
			scrolling = {
				type = "group", name = "Scrolling & Fading", order = 3,
				args = {
					wheelNote = {
						type = "description", order = 1, fontSize = "medium",
						name = "Mouse wheel scrolls. Hold Shift to jump to the top or bottom, Ctrl to scroll a page.\n",
					},
					scrollLines = range("Lines per Wheel Step", 2, 1, 10, 1),
					maxLines = range("History Lines", 3, 128, 2000, 1, {
						desc = "How many lines each window keeps. Changing it clears the window.",
					}),
					fading = { type = "toggle", name = "Fade Old Messages", order = 4 },
					fadeTime = range("Visible for (seconds)", 5, 5, 600, 5, {
						disabled = function() return not YC.db.profile.fading end,
					}),
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("chat", group)
end
