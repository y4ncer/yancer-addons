local addonName, ns = ...
local YUI = ns.YUI

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local POINTS = {
	TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
	LEFT = "Left", CENTER = "Center", RIGHT = "Right",
	BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
}

local STRATA = {
	BACKGROUND = "1. Background", LOW = "2. Low", MEDIUM = "3. Medium",
	HIGH = "4. High", DIALOG = "5. Dialog",
}

local STYLES = {
	clean = "Clean (square icons, thin border)",
	blizzard = "Blizzard default",
}

local options

-- Builds a color option bound to a { r, g, b, a } table returned by getTable().
local function colorOption(name, order, getTable, onChange)
	return {
		type = "color", name = name, order = order, hasAlpha = true,
		get = function()
			local c = getTable()
			return c.r, c.g, c.b, c.a
		end,
		set = function(_, r, g, b, a)
			local c = getTable()
			c.r, c.g, c.b, c.a = r, g, b, a
			onChange()
		end,
	}
end

local function rangeOption(name, order, min, max, step)
	return { type = "range", name = name, order = order, min = min, max = max, step = step }
end

local function barOptions(id, order)
	local function db()
		return YUI:GetBarDB(id)
	end
	local function update()
		YUI:UpdateBar(id)
	end

	return {
		type = "group",
		name = function()
			return db() and db().name or id
		end,
		order = order,
		get = function(info)
			return db()[info[#info]]
		end,
		set = function(info, value)
			db()[info[#info]] = value
			update()
		end,
		args = {
			name = {
				type = "input", name = "Name", order = 1,
				set = function(_, value)
					value = strtrim(value)
					if value ~= "" then
						db().name = value
						update()
						YUI:RefreshOptions()
					end
				end,
			},
			enabled = { type = "toggle", name = "Show", order = 2 },

			actionsHeader = { type = "header", name = "Actions", order = 10 },
			page = { type = "select", name = "Action Page", order = 11, values = YUI.PAGES,
				desc = "Which 12 action slots this bar shows. Bars on the same page show the same spells.",
			},
			paging = { type = "toggle", name = "Main Bar Paging", order = 12,
				desc = "Switch pages like Blizzard's main bar: stances/forms/stealth, "
					.. "possess and vehicles, and Shift+1-6 / Shift+mouse wheel.",
			},
			hideInVehicle = { type = "toggle", name = "Hide in Vehicle", order = 13 },
			showGrid = { type = "toggle", name = "Show Empty Buttons", order = 14 },

			layoutHeader = { type = "header", name = "Layout", order = 20 },
			numButtons = rangeOption("Buttons", 21, 1, YUI.MAX_BUTTONS, 1),
			perRow = rangeOption("Buttons per Row", 22, 1, YUI.MAX_BUTTONS, 1),
			buttonSize = rangeOption("Button Size", 23, 16, 64, 1),
			spacing = rangeOption("Spacing", 24, 0, 20, 1),
			padding = rangeOption("Padding", 25, 0, 20, 1),

			positionHeader = { type = "header", name = "Position", order = 30 },
			point = { type = "select", name = "Anchor", order = 31, values = POINTS,
				set = function(_, value)
					local b = db()
					b.point, b.relPoint = value, value
					update()
				end,
			},
			x = rangeOption("X Offset", 32, -2000, 2000, 1),
			y = rangeOption("Y Offset", 33, -2000, 2000, 1),
			strata = { type = "select", name = "Frame Strata", order = 34, values = STRATA },
			level = rangeOption("Frame Level", 35, 1, 50, 1),

			lookHeader = { type = "header", name = "Appearance", order = 40 },
			bgColor = colorOption("Background", 41, function() return db().bgColor end, update),
			borderColor = colorOption("Border", 42, function() return db().borderColor end, update),
			borderSize = rangeOption("Border Size", 43, 0, 10, 1),

			shadowHeader = { type = "header", name = "Shadow", order = 50 },
			shadowEnabled = { type = "toggle", name = "Bar Shadow", order = 51,
				get = function() return db().shadow.enabled end,
				set = function(_, value)
					db().shadow.enabled = value
					update()
				end,
			},
			shadowSize = { type = "range", name = "Bar Shadow Size", order = 52, min = 1, max = 40, step = 1,
				disabled = function() return not db().shadow.enabled end,
				get = function() return db().shadow.size end,
				set = function(_, value)
					db().shadow.size = value
					update()
				end,
			},
			shadowColor = colorOption("Shadow Color", 53, function() return db().shadow.color end, update),
			buttonShadow = { type = "toggle", name = "Button Shadows", order = 54 },
			buttonShadowSize = { type = "range", name = "Button Shadow Size", order = 55, min = 1, max = 20, step = 1,
				disabled = function() return not db().buttonShadow end,
			},

			deleteHeader = { type = "header", name = "", order = 90 },
			delete = {
				type = "execute", name = "Delete Bar", order = 91,
				confirm = true, confirmText = "Delete this bar?",
				func = function()
					YUI:DeleteBar(id)
				end,
			},
		},
	}
end

function YUI:SetupOptions()
	options = {
		type = "group",
		name = "yancer-ui",
		args = {
			general = {
				type = "group", name = "General", order = 1,
				args = {
					intro = {
						type = "description", order = 1, fontSize = "medium",
						name = "Unlock to drag bars with the left mouse button. Fine-tune them under Bars.\n"
							.. "Keybinds: Esc > Key Bindings > yancer-ui Bar 1-10.\n",
					},
					locked = {
						type = "toggle", name = "Lock Bars", order = 2, width = "full",
						desc = "When unlocked, every bar shows a blue overlay you can drag.",
						get = function() return YUI.db.profile.locked end,
						set = function(_, value) YUI:SetLocked(value) end,
					},
					style = {
						type = "select", name = "Button Style", order = 3, values = STYLES,
						disabled = InCombatLockdown,
						get = function() return YUI.db.profile.style end,
						set = function(_, value)
							YUI.db.profile.style = value
							YUI:UpdateAllBars()
						end,
					},
					newBar = {
						type = "input", name = "New Bar", order = 4,
						desc = "Type a name and press Enter (or Okay) to create a bar.",
						disabled = InCombatLockdown,
						get = function() return "" end,
						set = function(_, value) YUI:CreateBar(value) end,
					},
				},
			},
			bars = {
				type = "group", name = "Bars", order = 2, args = {},
				-- Bars are secure frames: they can't be changed in combat.
				disabled = InCombatLockdown,
			},
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	options.args.profiles.order = 100

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
	AceConfigDialog:SetDefaultSize(addonName, 760, 600)
	AceConfigDialog:AddToBlizOptions(addonName, "yancer-ui")
end

-- Rebuilds the per-bar groups (bars can be added, removed or renamed)
-- and redraws any open options window.
function YUI:RefreshOptions()
	if not options then
		return
	end
	local args = options.args.bars.args
	wipe(args)
	local count = 0
	for id in pairs(self.db.profile.bars) do
		count = count + 1
		args[id] = barOptions(id, tonumber(id:match("%d+")) or 100)
	end
	if count == 0 then
		args.none = { type = "description", name = "No bars yet. Create one under General." }
	end
	AceConfigRegistry:NotifyChange(addonName)
end

function YUI:OpenOptions()
	AceConfigDialog:Open(addonName)
end
