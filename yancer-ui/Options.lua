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

local function panelOptions(id, order)
	local function db()
		return YUI:GetPanelDB(id)
	end
	local function update()
		YUI:UpdatePanel(id)
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

			layoutHeader = { type = "header", name = "Size & Position", order = 10 },
			width = rangeOption("Width", 11, 1, 2000, 1),
			height = rangeOption("Height", 12, 1, 2000, 1),
			point = { type = "select", name = "Anchor", order = 13, values = POINTS,
				set = function(_, value)
					local p = db()
					p.point, p.relPoint = value, value
					update()
				end,
			},
			x = rangeOption("X Offset", 14, -2000, 2000, 1),
			y = rangeOption("Y Offset", 15, -2000, 2000, 1),
			strata = { type = "select", name = "Frame Strata", order = 16, values = STRATA },
			level = rangeOption("Frame Level", 17, 1, 50, 1),

			lookHeader = { type = "header", name = "Appearance", order = 20 },
			bgColor = colorOption("Background", 21, function() return db().bgColor end, update),
			borderColor = colorOption("Border", 22, function() return db().borderColor end, update),
			borderSize = rangeOption("Border Size", 23, 0, 10, 1),

			shadowHeader = { type = "header", name = "Shadow", order = 30 },
			shadowEnabled = { type = "toggle", name = "Enable Shadow", order = 31,
				get = function() return db().shadow.enabled end,
				set = function(_, value)
					db().shadow.enabled = value
					update()
				end,
			},
			shadowSize = { type = "range", name = "Shadow Size", order = 32, min = 1, max = 40, step = 1,
				disabled = function() return not db().shadow.enabled end,
				get = function() return db().shadow.size end,
				set = function(_, value)
					db().shadow.size = value
					update()
				end,
			},
			shadowColor = colorOption("Shadow Color", 33, function() return db().shadow.color end, update),

			deleteHeader = { type = "header", name = "", order = 90 },
			delete = {
				type = "execute", name = "Delete Panel", order = 91,
				confirm = true, confirmText = "Delete this panel?",
				func = function()
					YUI:DeletePanel(id)
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
						name = "Unlock to drag panels with the left mouse button. Fine-tune them under Panels.\n",
					},
					locked = {
						type = "toggle", name = "Lock Frames", order = 2, width = "full",
						desc = "When unlocked, every panel shows a blue overlay you can drag.",
						get = function() return YUI.db.profile.locked end,
						set = function(_, value) YUI:SetLocked(value) end,
					},
					newPanel = {
						type = "input", name = "New Panel", order = 3,
						desc = "Type a name and press Enter (or Okay) to create a panel.",
						get = function() return "" end,
						set = function(_, value) YUI:CreatePanel(value) end,
					},
				},
			},
			panels = { type = "group", name = "Panels", order = 2, args = {} },
			profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
		},
	}
	options.args.profiles.order = 100

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
	AceConfigDialog:SetDefaultSize(addonName, 720, 560)
	AceConfigDialog:AddToBlizOptions(addonName, "yancer-ui")
end

-- Rebuilds the per-panel groups (panels can be added, removed or renamed)
-- and redraws any open options window.
function YUI:RefreshOptions()
	if not options then
		return
	end
	local args = options.args.panels.args
	wipe(args)
	local count = 0
	for id in pairs(self.db.profile.panels) do
		count = count + 1
		args[id] = panelOptions(id, tonumber(id:match("%d+")) or 100)
	end
	if count == 0 then
		args.none = { type = "description", name = "No panels yet. Create one under General." }
	end
	AceConfigRegistry:NotifyChange(addonName)
end

function YUI:OpenOptions()
	AceConfigDialog:Open(addonName)
end
