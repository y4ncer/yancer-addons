local _, ns = ...
local YB = ns.YB

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
YB.buttonParking = parking

function YB:GetButtonName(barNum, index)
	return "yancerBarsBar" .. barNum .. "Button" .. index
end

-- Key binding labels shown in Esc > Key Bindings (the bindings are declared in Bindings.xml).
for bar = 1, YB.MAX_BARS do
	_G["BINDING_HEADER_YANCERBARS_BAR" .. bar] = "yancer-bars Bar " .. bar
	for i = 1, YB.MAX_BUTTONS do
		_G["BINDING_NAME_CLICK " .. YB:GetButtonName(bar, i) .. ":LeftButton"] = "Bar " .. bar .. " Button " .. i
	end
end

-- Returns the button, creating it on first use. Must not be called in combat.
function YB:GetButton(barNum, index)
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
	button.yIndex = index

	local floatingBG = _G[name .. "FloatingBG"]
	if floatingBG then
		floatingBG:Hide()
	end
	return button
end

-- Grid = show the button even when its slot is empty.
function YB:SetButtonGrid(button, show)
	button:SetAttribute("showgrid", show and 1 or 0)
	if show then
		ActionButton_ShowGrid(button)
	else
		ActionButton_HideGrid(button)
	end
end

-- Cooldown timer text

local function formatTime(s)
	if s >= 3600 then
		return format("%dh", math.ceil(s / 3600)), 0.8, 0.8, 0.8
	elseif s >= 60 then
		return format("%dm", math.ceil(s / 60)), 1, 1, 1
	elseif s >= 5 then
		return format("%d", math.ceil(s)), 1, 1, 0.2
	end
	return format("%d", math.ceil(s)), 1, 0.2, 0.2
end

local function timerOnUpdate(timer, elapsed)
	timer.wait = timer.wait - elapsed
	if timer.wait > 0 then
		return
	end
	timer.wait = 0.1
	local remaining = timer.start + timer.duration - GetTime()
	if remaining <= 0 then
		timer:Hide()
		return
	end
	local text, r, g, b = formatTime(remaining)
	timer.text:SetText(text)
	timer.text:SetTextColor(r, g, b)
end

local function getTimer(button)
	local timer = button.yTimer
	if not timer then
		timer = CreateFrame("Frame", nil, button)
		timer:SetAllPoints(button)
		timer.text = timer:CreateFontString(nil, "OVERLAY")
		timer.text:SetPoint("CENTER", 1, 0)
		timer:SetScript("OnUpdate", timerOnUpdate)
		timer:Hide()
		button.yTimer = timer
	end
	return timer
end

function YB:UpdateCooldownText(button)
	local timer = button.yTimer
	if not timer then
		return
	end
	local start, duration, enable = 0, 0, 0
	if button.action then
		start, duration, enable = GetActionCooldown(button.action)
	end
	if button.yCooldownText and enable == 1 and start > 0 and duration >= self.db.profile.cooldownMinDuration then
		timer.start, timer.duration, timer.wait = start, duration, 0
		timer:Show()
	else
		timer:Hide()
	end
end

hooksecurefunc("ActionButton_UpdateCooldown", function(button)
	if button.yancer then
		YB:UpdateCooldownText(button)
	end
end)

-- Hotkey text. Blizzard uses the same font string for the range dot (●):
-- buttons without a keybind show it while you have a target.

local function shortKey(key)
	key = key:upper()
	key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
	key = key:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
	key = key:gsub("MIDDLEMOUSE", "M3"):gsub("BUTTON", "M"):gsub("NUMPAD", "N")
	return key
end

-- Our own CLICK binding first; otherwise the Blizzard binding for the same slots.
local function getKey(button)
	local key = GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
	local blizzard = YB.blizzardHidden and button.yPage and YB.BLIZZARD_BINDINGS[button.yPage]
	if not key and blizzard then
		key = GetBindingKey(blizzard .. button.yIndex)
	end
	return key
end

function YB:UpdateHotkey(button)
	local hotkey = _G[button:GetName() .. "HotKey"]
	local key = button.yShowHotkeys and getKey(button)
	if key then
		hotkey:SetText(shortKey(key))
		hotkey:Show()
	elseif button.yShowRangeDot then
		-- Blizzard's convention: hidden until a target is selected.
		hotkey:SetText(RANGE_INDICATOR)
		hotkey:Hide()
	else
		-- Any other text keeps Blizzard's range code from showing the dot.
		hotkey:SetText("")
		hotkey:Hide()
	end
end

-- Blizzard's version only knows ACTIONBUTTON<id> bindings.
hooksecurefunc("ActionButton_UpdateHotkeys", function(button)
	if button.yancer then
		YB:UpdateHotkey(button)
	end
end)

-- Styling

-- Blizzard's ActionButton_Update puts its rounded art back on every change:
-- the slot frame (SetNormalTexture) and the green glow on equipped items.
-- For the square style this strips the frame again and shows equipped items
-- as a green button border instead.
function YB:UpdateButtonArt(button)
	local normal = button:GetNormalTexture()
	local size = button:GetWidth()
	if self.db.profile.style ~= "clean" then
		if not normal or not normal:GetTexture() then
			button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
			normal = button:GetNormalTexture()
		end
		-- The template's art is sized for a 36px button.
		normal:SetWidth(size * 66 / 36)
		normal:SetHeight(size * 66 / 36)
		return
	end
	if normal then
		normal:SetTexture(nil)
	end
	_G[button:GetName() .. "Border"]:Hide()
	local c = button.yBorderColor
	if button.action and IsEquippedAction(button.action) then
		button:SetBackdropBorderColor(0, 1, 0, 1)
	elseif c then
		button:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
	end
end

hooksecurefunc("ActionButton_Update", function(button)
	if button.yancer then
		YB:UpdateButtonArt(button)
	end
end)

function YB:StyleButton(button, db)
	local name = button:GetName()
	local size = db.buttonSize
	local icon = _G[name .. "Icon"]
	local cooldown = _G[name .. "Cooldown"]
	local border = _G[name .. "Border"]
	local flash = _G[name .. "Flash"]
	local macroText = _G[name .. "Name"]

	button:SetWidth(size)
	button:SetHeight(size)
	icon:ClearAllPoints()
	button.yBorderColor = db.buttonBorderColor

	local highlight = button:GetHighlightTexture()
	local pushed = button:GetPushedTexture()
	local checked = button:GetCheckedTexture()
	for _, tex in ipairs({ highlight, pushed, checked, flash }) do
		tex:ClearAllPoints()
	end

	if self.db.profile.style == "clean" then
		local bg, bc = db.buttonBgColor, db.buttonBorderColor
		button:SetBackdrop({ bgFile = self.WHITE, edgeFile = self.WHITE, edgeSize = 1 })
		button:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
		button:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
		-- Cropping the icon edges removes the rounded corners baked into the art.
		local zoom = self.db.profile.iconZoom
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
		-- Flat overlays instead of Blizzard's rounded art.
		highlight:SetTexture(self.WHITE)
		highlight:SetVertexColor(1, 1, 1, 0.2)
		pushed:SetTexture(self.WHITE)
		pushed:SetVertexColor(0, 0, 0, 0.4)
		checked:SetTexture(self.WHITE)
		checked:SetVertexColor(1, 0.82, 0, 0.35)
		flash:SetTexture(self.WHITE)
		flash:SetVertexColor(1, 0, 0, 0.35)
		for _, tex in ipairs({ highlight, pushed, checked, flash }) do
			tex:SetAllPoints(icon)
		end
	else
		button:SetBackdrop(nil)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetAllPoints(button)
		highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		pushed:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
		checked:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		flash:SetTexture("Interface\\Buttons\\UI-QuickslotRed")
		for _, tex in ipairs({ highlight, pushed, checked, flash }) do
			tex:SetVertexColor(1, 1, 1, 1)
			tex:SetAllPoints(button)
		end
	end
	highlight:SetBlendMode("ADD")
	checked:SetBlendMode("ADD")
	self:UpdateButtonArt(button)

	border:SetWidth(size * 62 / 36)
	border:SetHeight(size * 62 / 36)
	cooldown:ClearAllPoints()
	cooldown:SetAllPoints(icon)
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)

	self:UpdateShadow(button, db.buttonShadow and db.buttonShadowSize or 0, db.shadow.color, db.shadowStyle)

	-- Text
	local hotkey = _G[name .. "HotKey"]
	local count = _G[name .. "Count"]
	hotkey:SetFont(self.NUMBER_FONT, db.hotkeyFontSize, "OUTLINE")
	hotkey:SetWidth(size)
	hotkey:SetHeight(db.hotkeyFontSize + 2)
	count:SetFont(self.NUMBER_FONT, db.countFontSize, "OUTLINE")
	macroText:SetFont(self.FONT, db.macroFontSize, "OUTLINE")
	macroText:SetWidth(size)
	macroText:SetHeight(db.macroFontSize + 2)

	button.yPage = db.page
	button.yShowHotkeys = db.showHotkeys
	button.yShowRangeDot = db.showRangeDot
	self:UpdateHotkey(button)

	if db.showMacroText then
		macroText:Show()
	else
		macroText:Hide()
	end

	button.yCooldownText = db.cooldownText
	cooldown.noCooldownCount = db.cooldownText or nil -- stops OmniCC adding a second timer
	local timer = getTimer(button)
	timer:SetFrameLevel(button:GetFrameLevel() + 3)
	timer.text:SetFont(self.FONT, math.max(8, math.floor(size * 0.42)), "OUTLINE")
	self:UpdateCooldownText(button)
end
