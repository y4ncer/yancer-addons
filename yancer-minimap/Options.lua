local _, ns = ...
local YM, YB = ns.YM, ns.YB

local function range(name, order, min, max, step, extra)
	local opt = { type = "range", name = name, order = order, min = min, max = max, step = step }
	for k, v in pairs(extra or {}) do
		opt[k] = v
	end
	return opt
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

function YM:SetupOptions()
	local function get(info)
		return YM.db.profile[info[#info]]
	end
	local function set(info, value)
		YM.db.profile[info[#info]] = value
		YM:Refresh()
	end
	local function noMap()
		return not YM.db.profile.minimap
	end
	local function noInfo()
		return not YM.db.profile.info
	end
	local mapOff, infoOff = { disabled = noMap }, { disabled = noInfo }
	local group = {
		type = "group", name = "Minimap", order = 60, childGroups = "tab",
		args = {
			minimap = {
				type = "group", name = "Minimap", order = 1, get = get, set = set,
				args = {
					info = note("Move it with /yb move. The mouse wheel zooms, right-click opens the tracking "
						.. "menu, the clock opens the calendar.", 1),
					minimap = toggle("Style Minimap", 2, "Changing this needs a /reload.", { width = "full" }),
					shape = { type = "select", name = "Shape", order = 10, disabled = noMap,
						values = { round = "Round", square = "Square" } },
					size = range("Size", 11, 100, 300, 1, mapOff),
					scale = range("Scale", 12, 0.5, 2, 0.05, { isPercent = true, disabled = noMap }),
					zoneText = toggle("Zone Text", 20, "The zone above the map, in its PvP colour.", mapOff),
					clock = toggle("Clock", 21, nil, mapOff),
					localTime = toggle("Local Time", 22, "Your computer's time instead of the server's.", mapOff),
					hideButtons = toggle("Hide Buttons", 23,
						"Hide the zoom, world map and calendar buttons. Showing them again needs a /reload.", mapOff),
					hideTracking = toggle("Hide Tracking Button", 24,
						"Hide the round tracking button. Right-click the map for the tracking menu.", mapOff),
					resetPosition = { type = "execute", name = "Reset Position", order = 30, disabled = noMap,
						func = function()
							YM:SavePosition(nil, nil, nil, nil, nil)
							YM:Refresh()
						end,
					},
				},
			},
			info = {
				type = "group", name = "Info Text", order = 2, get = get, set = set,
				args = {
					info = note("FPS, latency and durability on one line. Hover it for the addon memory use, "
						.. "click it to free unused memory.", 1),
					info2 = { type = "toggle", name = "Show Info Text", order = 2, width = "full",
						desc = "Changing this needs a /reload.",
						get = function() return YM.db.profile.info end,
						set = function(_, v) YM.db.profile.info = v end,
					},
					showFPS = toggle("FPS", 10, nil, infoOff),
					showLatency = toggle("Latency (MS)", 11, nil, infoOff),
					showDurability = toggle("Durability", 12, "Your most damaged item, in percent.", infoOff),
					infoFontSize = range("Font Size", 13, 8, 30, 1, infoOff),
					resetPosition = { type = "execute", name = "Reset Position", order = 30, disabled = noInfo,
						func = function()
							YM:SavePosition("info", nil, nil, nil, nil)
							YM:Refresh()
						end,
					},
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("minimap", group)
end
