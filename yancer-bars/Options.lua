local addonName, ns = ...
local YB = ns.YB

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
	clean = "Clean (square icons, flat highlights)",
	blizzard = "Blizzard default",
}

local VISIBILITY = {
	always = "Always",
	combat = "In combat only",
	custom = "Custom macro conditions",
}

local GROWTH = { down = "Down", up = "Up" }

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

local function rangeOption(name, order, min, max, step, extra)
	local opt = { type = "range", name = name, order = order, min = min, max = max, step = step }
	for k, v in pairs(extra or {}) do
		opt[k] = v
	end
	return opt
end

local function header(name, order)
	return { type = "header", name = name, order = order }
end

local function barOptions(id, order)
	local function db()
		return YB:GetBarDB(id)
	end
	local function update()
		YB:UpdateBar(id)
	end
	local function shadowGetSet(key)
		return function() return db().shadow[key] end, function(_, value)
			db().shadow[key] = value
			update()
		end
	end
	local shadowEnabledGet, shadowEnabledSet = shadowGetSet("enabled")
	local shadowSizeGet, shadowSizeSet = shadowGetSet("size")

	return {
		type = "group",
		name = function()
			return db() and db().name or id
		end,
		order = order,
		childGroups = "tab",
		-- Options below read and write the bar setting named by their key.
		get = function(info)
			return db()[info[#info]]
		end,
		set = function(info, value)
			db()[info[#info]] = value
			update()
		end,
		args = {
			general = {
				type = "group", name = "General", order = 1,
				args = {
					name = {
						type = "input", name = "Name", order = 1,
						set = function(_, value)
							value = strtrim(value)
							if value ~= "" then
								db().name = value
								update()
								YB:RefreshOptions()
							end
						end,
					},
					enabled = { type = "toggle", name = "Enabled", order = 2 },
					actionsHeader = header("Actions", 10),
					page = { type = "select", name = "Action Page", order = 11, values = YB.PAGES,
						desc = "Which 12 action slots this bar shows. Bars on the same page show the same spells.",
					},
					paging = { type = "toggle", name = "Main Bar Paging", order = 12,
						desc = "Switch pages like Blizzard's main bar: stances/forms/stealth, "
							.. "possess and vehicles, and Shift+1-6 / Shift+mouse wheel.",
					},
					showGrid = { type = "toggle", name = "Show Empty Buttons", order = 13 },
					deleteHeader = header("", 90),
					delete = {
						type = "execute", name = "Delete Bar", order = 91,
						confirm = true, confirmText = "Delete this bar?",
						func = function()
							YB:DeleteBar(id)
						end,
					},
				},
			},
			layout = {
				type = "group", name = "Layout", order = 2,
				args = {
					buttonsHeader = header("Buttons", 1),
					numButtons = rangeOption("Buttons", 2, 1, YB.MAX_BUTTONS, 1),
					perRow = rangeOption("Buttons per Row", 3, 1, YB.MAX_BUTTONS, 1),
					growth = { type = "select", name = "Rows Grow", order = 4, values = GROWTH },
					buttonSize = rangeOption("Button Size", 5, 16, 64, 1),
					spacing = rangeOption("Spacing", 6, 0, 20, 1),
					padding = rangeOption("Padding", 7, 0, 20, 1),
					positionHeader = header("Position", 10),
					point = { type = "select", name = "Anchor", order = 11, values = POINTS,
						set = function(_, value)
							local b = db()
							b.point, b.relPoint = value, value
							update()
						end,
					},
					x = rangeOption("X Offset", 12, -2000, 2000, 1),
					y = rangeOption("Y Offset", 13, -2000, 2000, 1),
					strata = { type = "select", name = "Frame Strata", order = 14, values = STRATA },
					level = rangeOption("Frame Level", 15, 1, 50, 1),
				},
			},
			visibility = {
				type = "group", name = "Visibility", order = 3,
				args = {
					showHeader = header("When to Show", 1),
					visibility = { type = "select", name = "Show", order = 2, values = VISIBILITY },
					visibilityCustom = {
						type = "input", name = "Macro Conditions", order = 3, width = "full",
						desc = "Same syntax as macros, e.g. \"[combat][harm] show; hide\" or "
							.. "\"[mod:shift] show; hide\".",
						hidden = function() return db().visibility ~= "custom" end,
					},
					hideInVehicle = { type = "toggle", name = "Hide in Vehicle", order = 4 },
					fadeHeader = header("Opacity", 10),
					alpha = rangeOption("Opacity", 11, 0, 1, 0.05, { isPercent = true }),
					mouseover = { type = "toggle", name = "Fade Unless Mouseover", order = 12,
						desc = "Fade the bar out until the mouse is over it. "
							.. "Faded bars still work with keybinds and come back while you move bars "
							.. "or hold a spell on the cursor.",
					},
					fadeAlpha = rangeOption("Faded Opacity", 13, 0, 1, 0.05, {
						isPercent = true,
						disabled = function() return not db().mouseover end,
					}),
				},
			},
			appearance = {
				type = "group", name = "Appearance", order = 4,
				args = {
					barHeader = header("Bar", 1),
					bgColor = colorOption("Background", 2, function() return db().bgColor end, update),
					borderColor = colorOption("Border", 3, function() return db().borderColor end, update),
					borderSize = rangeOption("Border Size", 4, 0, 10, 1),
					shadowEnabled = { type = "toggle", name = "Bar Shadow", order = 5,
						get = shadowEnabledGet, set = shadowEnabledSet },
					shadowSize = rangeOption("Bar Shadow Size", 6, 1, 40, 1, {
						get = shadowSizeGet, set = shadowSizeSet,
						disabled = function() return not db().shadow.enabled end,
					}),
					shadowColor = colorOption("Shadow Color", 7, function() return db().shadow.color end, update),
					buttonHeader = header("Buttons", 10),
					buttonBgColor = colorOption("Button Background", 11,
						function() return db().buttonBgColor end, update),
					buttonBorderColor = colorOption("Button Border", 12,
						function() return db().buttonBorderColor end, update),
					buttonColorNote = {
						type = "description", order = 13,
						name = "Button colors apply to the Clean style.",
					},
					buttonShadow = { type = "toggle", name = "Button Shadows", order = 14 },
					buttonShadowSize = rangeOption("Button Shadow Size", 15, 1, 20, 1, {
						disabled = function() return not db().buttonShadow end,
					}),
				},
			},
			text = {
				type = "group", name = "Text", order = 5,
				args = {
					showHotkeys = { type = "toggle", name = "Show Keybinds", order = 1 },
					hotkeyFontSize = rangeOption("Keybind Size", 2, 6, 24, 1),
					showMacroText = { type = "toggle", name = "Show Macro Names", order = 3 },
					macroFontSize = rangeOption("Macro Name Size", 4, 6, 24, 1),
					countFontSize = rangeOption("Stack Count Size", 5, 6, 24, 1),
					showRangeDot = { type = "toggle", name = "Show Range Dot", order = 6,
						desc = "Blizzard's small circle on buttons without a keybind. "
							.. "It shows while you have a target and turns red when out of range.",
					},
					cooldownText = { type = "toggle", name = "Cooldown Timers", order = 7,
						desc = "Countdown text on buttons that are on cooldown.",
					},
				},
			},
		},
	}
end

function YB:SetupOptions()
	local function profileGet(info)
		return YB.db.profile[info[#info]]
	end
	local function profileSet(info, value)
		YB.db.profile[info[#info]] = value
	end

	options = {
		type = "group",
		name = "yancer-bars",
		args = {
			general = {
				type = "group", name = "General", order = 1,
				get = profileGet,
				set = profileSet,
				args = {
					intro = {
						type = "description", order = 1, fontSize = "medium",
						name = "Unlock to drag bars with the left mouse button. Fine-tune each bar under Bars.\n"
							.. "Keybinds: Esc > Key Bindings > yancer-bars Bar 1-10.\n",
					},
					moveHeader = header("Moving", 2),
					locked = {
						type = "toggle", name = "Lock Bars", order = 3,
						desc = "When unlocked, every bar shows a blue overlay you can drag.",
						set = function(_, value) YB:SetLocked(value) end,
					},
					moveGrid = {
						type = "toggle", name = "Show Grid While Moving", order = 4,
						set = function(_, value)
							YB.db.profile.moveGrid = value
							YB:UpdateGrid()
						end,
					},
					snapToGrid = { type = "toggle", name = "Snap to Grid", order = 5,
						desc = "Dropped bars snap their centre to the grid.",
					},
					gridSize = rangeOption("Grid Size", 6, 4, 64, 2, {
						set = function(_, value)
							YB.db.profile.gridSize = value
							YB:UpdateGrid()
						end,
					}),
					buttonsHeader = header("Buttons", 10),
					style = {
						type = "select", name = "Button Style", order = 11, values = STYLES,
						disabled = InCombatLockdown,
						set = function(_, value)
							YB.db.profile.style = value
							YB:UpdateAllBars()
						end,
					},
					rangeColoring = {
						type = "toggle", name = "Range & Mana Coloring", order = 12,
						desc = "Tint icons red when out of range, blue without enough mana, grey when unusable.",
						set = function(_, value)
							YB.db.profile.rangeColoring = value
							YB:UpdateTicker()
						end,
					},
					cooldownMinDuration = rangeOption("Min. Cooldown for Timer", 13, 0, 10, 0.5, {
						desc = "Cooldowns shorter than this (seconds) get no timer. 2 hides the global cooldown.",
					}),
					barsHeader = header("Bars", 20),
					newBar = {
						type = "input", name = "New Bar", order = 21,
						desc = "Type a name and press Enter (or Okay). The bar gets an unused action page "
							.. "and appears in the middle of the screen.",
						disabled = InCombatLockdown,
						get = function() return "" end,
						set = function(_, value) YB:CreateBar(value) end,
					},
					restoreDefaults = {
						type = "execute", name = "Restore Blizzard Bars", order = 22,
						desc = "Recreates any of Blizzard's five bars (main, bottom left/right, right 1/2) "
							.. "whose action page no bar shows.",
						disabled = InCombatLockdown,
						func = function()
							local created = YB:CreateDefaultBars()
							YB:Print(created > 0 and ("Restored " .. created .. " bar(s).") or "All Blizzard bars already exist.")
						end,
					},
					hideBlizzard = {
						type = "toggle", name = "Hide Blizzard Action Bars", order = 23, width = "full",
						desc = "Hides the default action buttons, side/bottom bars and bar art. "
							.. "The XP bar, bags, micro menu, and stance and pet bars stay.",
						disabled = InCombatLockdown,
						set = function(_, value)
							YB.db.profile.hideBlizzard = value
							if value then
								YB:HideBlizzardBars()
								YB:UpdateAllBars() -- picks up Blizzard keybind labels
							else
								YB:Print("Type /reload to bring the Blizzard action bars back.")
							end
						end,
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
	AceConfigDialog:SetDefaultSize(addonName, 800, 620)
	AceConfigDialog:AddToBlizOptions(addonName, "yancer-bars")
end

-- Rebuilds the per-bar groups (bars can be added, removed or renamed)
-- and redraws any open options window.
function YB:RefreshOptions()
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

function YB:OpenOptions()
	AceConfigDialog:Open(addonName)
end
