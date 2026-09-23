local _, ns = ...
local YUI = ns.YUI

-- Buttons are Blizzard's ActionBarButtonTemplate, so casting, drag & drop,
-- cooldowns, range colouring and tooltips all behave like the default UI.
-- The ID stays 0 so Blizzard's paging code leaves them alone; the "action"
-- attribute is set by the bar's secure paging snippet instead.

-- Runs in the restricted environment when the bar's page state changes.
local CHILD_UPDATE_PAGE = [[
	local page = tonumber(message) or 1
	self:SetAttribute("action", (page - 1) * 12 + self:GetAttribute("index"))
]]

-- Unused buttons are parked here: hidden, and out of reach of the bar's paging.
local parking = CreateFrame("Frame")
parking:Hide()
YUI.buttonParking = parking

function YUI:GetButtonName(barNum, index)
	return "yancerUIBar" .. barNum .. "Button" .. index
end

-- Key binding labels shown in Esc > Key Bindings (the bindings are declared in Bindings.xml).
for bar = 1, YUI.MAX_BARS do
	_G["BINDING_HEADER_YANCERUIBAR" .. bar] = "yancer-ui Bar " .. bar
	for i = 1, YUI.MAX_BUTTONS do
		_G["BINDING_NAME_CLICK " .. YUI:GetButtonName(bar, i) .. ":LeftButton"] = "Bar " .. bar .. " Button " .. i
	end
end

-- Returns the button, creating it on first use. Must not be called in combat.
function YUI:GetButton(barNum, index)
	local name = self:GetButtonName(barNum, index)
	local button = _G[name]
	if button then
		return button
	end
	button = CreateFrame("CheckButton", name, parking, "ActionBarButtonTemplate")
	button:SetID(0)
	button:SetAttribute("index", index)
	button:SetAttribute("showgrid", 0)
	button:SetAttribute("_childupdate-page", CHILD_UPDATE_PAGE)
	button.yancer = true

	local floatingBG = _G[name .. "FloatingBG"]
	if floatingBG then
		floatingBG:Hide()
	end
	return button
end

-- Grid = show the button even when its slot is empty.
function YUI:SetButtonGrid(button, show)
	button:SetAttribute("showgrid", show and 1 or 0)
	if show then
		ActionButton_ShowGrid(button)
	else
		ActionButton_HideGrid(button)
	end
end

function YUI:StyleButton(button, db)
	local name = button:GetName()
	local size = db.buttonSize
	local icon = _G[name .. "Icon"]
	local normal = _G[name .. "NormalTexture"]
	local cooldown = _G[name .. "Cooldown"]
	local border = _G[name .. "Border"]

	button:SetWidth(size)
	button:SetHeight(size)
	icon:ClearAllPoints()

	if self.db.profile.style == "clean" then
		button:SetBackdrop({ bgFile = self.WHITE, edgeFile = self.WHITE, edgeSize = 1 })
		button:SetBackdropColor(0, 0, 0, 0.5)
		button:SetBackdropBorderColor(0, 0, 0, 1)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		normal:SetAlpha(0)
	else
		button:SetBackdrop(nil)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetAllPoints(button)
		normal:SetAlpha(1)
		-- The template's art is sized for a 36px button.
		normal:SetWidth(size * 66 / 36)
		normal:SetHeight(size * 66 / 36)
	end

	border:SetWidth(size * 62 / 36)
	border:SetHeight(size * 62 / 36)
	cooldown:ClearAllPoints()
	cooldown:SetAllPoints(icon)

	self:UpdateShadow(button, db.buttonShadow and db.buttonShadowSize or 0, db.shadow.color)
	self:UpdateHotkey(button)
end

-- Hotkey text

local function shortKey(key)
	key = key:upper()
	key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
	key = key:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
	key = key:gsub("MIDDLEMOUSE", "M3"):gsub("BUTTON", "M"):gsub("NUMPAD", "N")
	return key
end

function YUI:UpdateHotkey(button)
	local hotkey = _G[button:GetName() .. "HotKey"]
	local key = GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
	if key then
		hotkey:SetText(shortKey(key))
		hotkey:Show()
	else
		-- Blizzard's convention: RANGE_INDICATOR text, hidden until out of range.
		hotkey:SetText(RANGE_INDICATOR)
		hotkey:Hide()
	end
end

-- Blizzard's version looks up ACTIONBUTTON<id> bindings, which don't apply to ours.
hooksecurefunc("ActionButton_UpdateHotkeys", function(button)
	if button.yancer then
		YUI:UpdateHotkey(button)
	end
end)
