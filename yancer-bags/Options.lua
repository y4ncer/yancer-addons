local _, ns = ...
local YG, YB = ns.YG, ns.YB

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

function YG:SetupOptions()
	local function off()
		return not YG.db.profile.enabled
	end
	local group = {
		type = "group", name = "Bags", order = 40, childGroups = "tab",
		args = {
			general = {
				type = "group", name = "General", order = 1,
				get = function(info) return YG.db.profile[info[#info]] end,
				set = function(info, value)
					YG.db.profile[info[#info]] = value
					YG:Refresh()
				end,
				args = {
					note = {
						type = "description", order = 1, fontSize = "medium",
						name = "The backpack and your four bags in one window (B, the bag buttons, merchants "
							.. "and mail all open it). Move it with /yb move. The bank and keyring keep "
							.. "Blizzard's windows.\n",
					},
					enabled = { type = "toggle", name = "One Bag", order = 2, width = "full",
						desc = "Replaces Blizzard's bag windows. Changing this needs a /reload.",
					},
					layoutHeader = header("Layout", 10),
					columns = range("Columns", 11, 4, 30, 1, { disabled = off }),
					buttonSize = range("Slot Size", 12, 20, 60, 1, { disabled = off }),
					spacing = range("Spacing", 13, 0, 10, 1, { disabled = off }),
					scale = range("Scale", 14, 0.5, 2, 0.05, { isPercent = true, disabled = off }),
					lookHeader = header("Look", 20),
					bgAlpha = range("Background Opacity", 21, 0, 1, 0.05, { isPercent = true, disabled = off }),
					qualityBorders = { type = "toggle", name = "Quality Borders", order = 22, disabled = off,
						desc = "Item borders in the item's quality colour (green, blue, purple, ...). "
							.. "Quest items always get a yellow border.",
					},
					resetPosition = { type = "execute", name = "Reset Position", order = 30, disabled = off,
						func = function()
							local db = YG.db.profile
							db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil -- falls back to the defaults
							YG:Refresh()
						end,
					},
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("bags", group)
end
