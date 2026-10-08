local _, ns = ...
local YQ, YB = ns.YQ, ns.YB

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

local function toggle(name, order, desc, extra)
	local opt = { type = "toggle", name = name, order = order, desc = desc }
	for k, v in pairs(extra or {}) do
		opt[k] = v
	end
	return opt
end

local function note(text, order)
	return { type = "description", order = order, fontSize = "medium", name = text .. "\n" }
end

function YQ:SetupOptions()
	local function noTracker()
		return not YQ.db.profile.tracker
	end
	local function get(info)
		return YQ.db.profile[info[#info]]
	end
	local function set(info, value)
		YQ.db.profile[info[#info]] = value
		YQ:Refresh()
	end
	local off = { disabled = noTracker }
	local group = {
		type = "group", name = "Quests", order = 50, childGroups = "tab",
		args = {
			tracker = {
				type = "group", name = "Tracker", order = 1, get = get, set = set,
				args = {
					info = note("Blizzard's objective tracker, square and movable. Move it with /yb move. "
						.. "Hover a quest in it to see which mobs to kill and which mobs drop its items.", 1),
					tracker = toggle("Style Tracker", 2, "Restyle and move the tracker. Changing this needs a /reload.",
						{ width = "full" }),
					layoutHeader = header("Layout", 10),
					width = range("Width", 11, 150, 500, 1, off),
					height = range("Height", 12, 100, 1000, 1, off),
					scale = range("Scale", 13, 0.5, 2, 0.05, { isPercent = true, disabled = noTracker }),
					fontSize = range("Font Size", 14, 8, 20, 1, off),
					bgAlpha = range("Background Opacity", 15, 0, 1, 0.05, { isPercent = true, disabled = noTracker,
						desc = "Background behind the header while the tracker is collapsed." }),
					lookHeader = header("Colours", 20),
					levelTags = toggle("Level Tags", 21,
						"Quest titles in their difficulty colour with the level: [12], [12+] elite/group, "
						.. "[12D] dungeon, [12R] raid, [12H] heroic, Y daily.", off),
					colorObjectives = toggle("Colour Objectives", 22,
						"Objectives go from red through yellow to green as you progress.", off),
					collapseHeader = header("Collapse Automatically", 30),
					collapseCombat = toggle("In Combat", 31, nil, off),
					collapseDungeon = toggle("In Dungeons", 32, nil, off),
					collapseRaid = toggle("In Raids", 33, nil, off),
					collapsePvP = toggle("In Battlegrounds & Arenas", 34, nil, off),
					resetPosition = { type = "execute", name = "Reset Position", order = 40, disabled = noTracker,
						func = function()
							local p = YQ.db.profile
							p.point, p.relPoint, p.x, p.y = nil, nil, nil, nil -- falls back to the defaults
							YQ:Refresh()
						end,
					},
				},
			},
			info = {
				type = "group", name = "Quest Info", order = 2, get = get, set = set,
				args = {
					info = note("Which mobs to kill and which mobs or objects drop quest items, from a bundled "
						.. "quest database (pfQuest-wotlk). Only quests in your quest log are shown.", 1),
					unitTooltip = toggle("Mob Tooltips", 2,
						"Hovering a mob shows the quests it counts for, with your progress and its drop chance.",
						{ width = "full" }),
					objectTooltip = toggle("Object Tooltips", 3,
						"Hovering a chest, plant or other object shows the quests it is needed for.", { width = "full" }),
					trackerTooltip = toggle("Tracker Tooltips", 4,
						"Hovering a quest in the tracker lists the mobs to kill and where each item drops.",
						{ width = "full" }),
					maxSources = range("Sources Shown", 5, 1, 10, 1,
						{ desc = "How many mobs or objects the tracker tooltip lists per objective." }),
				},
			},
			skins = {
				type = "group", name = "Windows", order = 3, get = get, set = set,
				args = {
					info = note("Square style for the quest log, the NPC quest dialog and the gossip window.", 1),
					skin = toggle("Square Quest Windows", 2, "Changing this needs a /reload.", { width = "full" }),
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("quests", group)
end
