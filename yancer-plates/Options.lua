local _, ns = ...
local YP, YB = ns.YP, ns.YB

local HEALTH_TEXT = { percent = "Percent (75%)", current = "Current (12.5k)", none = "None" }

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

function YP:SetupOptions()
	local function off()
		return not YP.db.profile.enabled
	end
	local function toggle(name, order, desc)
		return { type = "toggle", name = name, order = order, desc = desc, disabled = off }
	end
	local group = {
		type = "group", name = "Nameplates", order = 45, childGroups = "tab",
		args = {
			general = {
				type = "group", name = "General", order = 1,
				get = function(info) return YP.db.profile[info[#info]] end,
				set = function(info, value)
					YP.db.profile[info[#info]] = value
					YP:Refresh()
				end,
				args = {
					note = {
						type = "description", order = 1, fontSize = "medium",
						name = "Flat square nameplates. Show them with V (enemies) and Shift+V (friends).\n",
					},
					enabled = { type = "toggle", name = "Style Nameplates", order = 2, width = "full",
						desc = "Changing this needs a /reload.",
					},
					sizeHeader = header("Size", 10),
					width = range("Width", 11, 50, 200, 1, { disabled = off }),
					height = range("Health Height", 12, 3, 30, 1, { disabled = off }),
					castHeight = range("Cast Bar Height", 13, 3, 30, 1, { disabled = off }),
					fontSize = range("Font Size", 14, 6, 20, 1, { disabled = off }),
					textHeader = header("Text & Icons", 20),
					healthText = { type = "select", name = "Health Text", order = 21, values = HEALTH_TEXT,
						disabled = off },
					showLevel = toggle("Level", 22, "The level (or a skull) right of the health bar."),
					classIcons = toggle("Class Icons", 23,
						"A class icon above player nameplates: group members by name, enemies from their class colour."),
					classIconSize = range("Class Icon Size", 24, 10, 48, 1, { disabled = off }),
					colorHeader = header("Colours & Borders", 30),
					classColors = toggle("Class-Colored Enemies", 31,
						"Blizzard's setting: enemy players' health bars in their class colour. "
						.. "Also needed for enemy class icons."),
					targetBorder = toggle("Target Border", 32, "A white border on your target's nameplate."),
					threatBorder = toggle("Threat Border", 33,
						"The border turns yellow/orange/red with threat, instead of Blizzard's glow."),
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("plates", group)
end
