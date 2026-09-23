local _, ns = ...
local YF, YB = ns.YF, ns.YB

-- The "Unit Frames" section of the /yb window: shared settings, then one tab per
-- unit (Player, Target, Focus).

local HEALTH_TEXT = {
	current = "Current (12.5k)",
	percent = "Percent (75%)",
	both = "Both (12.5k | 75%)",
	deficit = "Missing (-2.5k)",
	none = "None",
}
local POWER_TEXT = { current = "Current", percent = "Percent", none = "None" }
local PORTRAIT = { ["3d"] = "3D Model", ["2d"] = "2D Picture", none = "None" }
local SIDE = { left = "Left", right = "Right" }

local function range(name, order, min, max, step, extra)
	local opt = { type = "range", name = name, order = order, min = min, max = max, step = step }
	for k, v in pairs(extra or {}) do
		opt[k] = v
	end
	return opt
end

local function toggle(name, order, desc)
	return { type = "toggle", name = name, order = order, desc = desc }
end

local function header(name, order)
	return { type = "header", name = name, order = order }
end

local function unitOptions(unit, order)
	local function db()
		return YF:GetUnitDB(unit)
	end
	local function off()
		return not db().enabled
	end

	local args = {
		enabled = { type = "toggle", name = "Enabled", order = 1, width = "full",
			desc = "Replaces Blizzard's " .. YF.UNIT_NAMES[unit] .. " frame. Getting Blizzard's back needs a /reload.",
		},

		sizeHeader = header("Size", 10),
		width = range("Width", 11, 80, 400, 1),
		healthHeight = range("Health Height", 12, 8, 80, 1),
		scale = range("Scale", 13, 0.5, 2, 0.05, { isPercent = true }),
		showPower = toggle("Show Power Bar", 14),
		powerHeight = range("Power Height", 15, 2, 40, 1, { disabled = function() return off() or not db().showPower end }),

		colorHeader = header("Health & Power", 20),
		classColor = toggle("Class-Colored Health", 21, "Players' health bars use their class colour."),
		reactionColor = toggle("Reaction-Colored Health", 22,
			"NPCs' health bars show whether they are hostile (red), neutral (yellow) or friendly (green)."),
		healthColor = { type = "color", name = "Health Color", order = 23,
			desc = "Used when the class or reaction colour doesn't apply.",
			get = function()
				local c = db().healthColor
				return c.r, c.g, c.b
			end,
			set = function(_, r, g, b)
				db().healthColor = { r = r, g = g, b = b }
				YF:UpdateAll()
			end,
		},
		healthText = { type = "select", name = "Health Text", order = 24, values = HEALTH_TEXT },
		powerText = { type = "select", name = "Power Text", order = 25, values = POWER_TEXT,
			disabled = function() return off() or not db().showPower end,
		},

		portraitHeader = header("Portrait", 30),
		portrait = { type = "select", name = "Portrait", order = 31, values = PORTRAIT },
		portraitSide = { type = "select", name = "Side", order = 32, values = SIDE,
			disabled = function() return off() or db().portrait == "none" end,
		},

		iconsHeader = header("Text & Icons", 40),
		showName = toggle("Name", 41),
		showLevel = toggle("Level", 42, "Coloured by difficulty; + for elites, R for rares, B for bosses."),
		showPvP = toggle("Horde / Alliance Icon", 43, "The PvP flag icon, shown while flagged for PvP."),
		showRaidIcon = toggle("Raid Target Icon", 44),
		showLeader = toggle("Party Leader Icon", 45),

		aurasHeader = header("Auras", 50),
		showAuras = toggle("Show Auras", 51, "Debuffs, then buffs, in rows above the frame."),
		auraSize = range("Aura Size", 52, 12, 48, 1, { disabled = function() return off() or not db().showAuras end }),
		maxAuras = range("Max Auras", 53, 1, 40, 1, { disabled = function() return off() or not db().showAuras end }),
		onlyMyDebuffs = toggle("Only My Debuffs", 54, "Hide debuffs cast by others."),

		castHeader = header("Cast Bar", 60),
		showCastBar = toggle("Show Cast Bar", 61, "A cast bar below the frame."),
		castBarHeight = range("Cast Bar Height", 62, 8, 40, 1, {
			disabled = function() return off() or not db().showCastBar end,
		}),

		positionHeader = header("Position", 90),
		resetPosition = { type = "execute", name = "Reset Position", order = 91,
			func = function()
				local d = db()
				d.point, d.relPoint, d.x, d.y = nil, nil, nil, nil -- falls back to the defaults
				YF:Refresh()
			end,
		},
	}
	if unit == "player" then
		args.showStatus = toggle("Combat / Resting Icon", 46)
		args.showAuras.desc = "Off by default: Blizzard's buff frame already shows your auras."
		args.showCastBar.desc = "Off by default: Blizzard's cast bar can be moved under UI Elements."
	end
	if unit == "target" then
		args.showComboPoints = toggle("Combo Points", 47, "Rogue and druid combo points above the frame.")
	end
	for key, opt in pairs(args) do
		if key ~= "enabled" and opt.type ~= "header" and not opt.disabled then
			opt.disabled = off
		end
	end

	return {
		type = "group", name = YF.UNIT_NAMES[unit], order = order,
		get = function(info) return db()[info[#info]] end,
		set = function(info, value)
			db()[info[#info]] = value
			YF:Refresh()
		end,
		args = args,
	}
end

function YF:SetupOptions()
	local group = {
		type = "group", name = "Unit Frames", order = 30, childGroups = "tab",
		args = {
			general = {
				type = "group", name = "General", order = 1,
				get = function(info) return YF.db.profile[info[#info]] end,
				set = function(info, value)
					YF.db.profile[info[#info]] = value
					YF:Refresh()
				end,
				args = {
					note = {
						type = "description", order = 1, fontSize = "medium",
						name = "Move the frames with /yb move (they show sample values while unlocked). "
							.. "Left-click targets, right-click opens the unit menu.\n",
					},
					bgAlpha = range("Background Opacity", 2, 0, 1, 0.05, { isPercent = true }),
					fontSize = range("Font Size", 3, 6, 24, 1),
				},
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	for i, unit in ipairs(self.UNITS) do
		group.args[unit] = unitOptions(unit, i + 1)
	end
	group.args.profiles.order = 100
	YB:RegisterModuleOptions("frames", group)
end
