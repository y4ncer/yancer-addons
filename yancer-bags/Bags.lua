local _, ns = ...
local YG, YB = ns.YG, ns.YB

-- One window for the backpack and the four bags. Each bag gets a holder frame
-- whose ID is the bag number, and the slots are Blizzard's
-- ContainerFrameItemButtonTemplate buttons (ID = slot), so clicking, dragging,
-- selling, splitting and tooltips all work as in Blizzard's bags.

local PAD = 6
local HEADER = 26
local FOOTER = 22
local SEARCH_DIM = 0.2 -- alpha of items that don't match the search

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local holders = {} -- bag -> holder frame (ID = bag)
local buttons = {} -- bag -> { slot -> button }

local function flat(texture, alpha)
	texture:SetTexture(YB.WHITE)
	texture:SetVertexColor(1, 1, 1, alpha)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", texture:GetParent(), "TOPLEFT", 1, -1)
	texture:SetPoint("BOTTOMRIGHT", texture:GetParent(), "BOTTOMRIGHT", -1, 1)
end

local function createButton(bag, slot)
	local name = format("yancerBagsBag%dSlot%d", bag, slot)
	local button = CreateFrame("Button", name, holders[bag], "ContainerFrameItemButtonTemplate")
	button:SetID(slot)
	YB:StripNormal(button)
	YB:SquareBackdrop(button, 0.4)

	local icon = _G[name .. "IconTexture"]
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	_G[name .. "Cooldown"]:SetAllPoints(icon)
	_G[name .. "IconQuestTexture"]:SetAllPoints(icon)

	local count = _G[name .. "Count"]
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	count:SetFont(YB.NUMBER_FONT, 12, "OUTLINE")

	flat(button:GetPushedTexture(), 0.3)
	flat(button:GetHighlightTexture(), 0.2)

	buttons[bag][slot] = button
	return button
end

local function formatMoney(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then
		return format("%d%s %d%s %d%s", g, GOLD, s, SILVER, c, COPPER)
	elseif s > 0 then
		return format("%d%s %d%s", s, SILVER, c, COPPER)
	end
	return format("%d%s", c, COPPER)
end

function YG:CreateBagFrame()
	local f = CreateFrame("Frame", "yancerBagsFrame", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:Hide()
	tinsert(UISpecialFrames, "yancerBagsFrame") -- Escape closes it
	YB:Outline(f)
	self.frame = f

	f.title = f:CreateFontString(nil, "OVERLAY")
	f.title:SetFont(YB.FONT, 12, "OUTLINE")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, -8)
	f.title:SetText("Bags")

	local close = CreateFrame("Button", nil, f)
	close:SetWidth(18)
	close:SetHeight(18)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -4)
	YB:SquareBackdrop(close, 0.6)
	close.text = close:CreateFontString(nil, "OVERLAY")
	close.text:SetFont(YB.FONT, 11, "OUTLINE")
	close.text:SetPoint("CENTER", close, "CENTER", 1, 0)
	close.text:SetText("x")
	flat(close:CreateTexture(nil, "HIGHLIGHT"), 0.2)
	close:SetScript("OnClick", function()
		YG:Close()
	end)

	-- Search: items whose name doesn't contain the text are dimmed.
	local search = CreateFrame("EditBox", nil, f)
	search:SetHeight(18)
	search:SetWidth(140)
	search:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
	search:SetAutoFocus(false)
	search:SetFont(YB.FONT, 11, "")
	search:SetTextInsets(4, 4, 0, 0)
	YB:SquareBackdrop(search, 0.6)
	search.hint = search:CreateFontString(nil, "OVERLAY")
	search.hint:SetFont(YB.FONT, 11, "")
	search.hint:SetPoint("LEFT", search, "LEFT", 4, 0)
	search.hint:SetTextColor(0.5, 0.5, 0.5)
	search.hint:SetText("Search")
	search:SetScript("OnEscapePressed", function(box)
		box:SetText("")
		box:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", function(box)
		box:ClearFocus()
	end)
	search:SetScript("OnEditFocusGained", function(box)
		box.hint:Hide()
	end)
	search:SetScript("OnEditFocusLost", function(box)
		if box:GetText() == "" then
			box.hint:Show()
		end
	end)
	search:SetScript("OnTextChanged", function()
		YG:UpdateSearch()
	end)
	f.search = search

	f.slots = f:CreateFontString(nil, "OVERLAY")
	f.slots:SetFont(YB.FONT, 11, "OUTLINE")
	f.slots:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + 2, 7)
	f.money = f:CreateFontString(nil, "OVERLAY")
	f.money:SetFont(YB.FONT, 11, "OUTLINE")
	f.money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 2, 7)

	for bag = 0, NUM_BAG_SLOTS do
		local holder = CreateFrame("Frame", nil, f)
		holder:SetID(bag)
		holder:SetAllPoints(f)
		holders[bag] = holder
		buttons[bag] = {}
	end

	f:SetScript("OnShow", function()
		YG:Layout()
		YG:UpdateAll()
		YG:SetBagButtonsChecked(true)
		PlaySound("igBackPackOpen")
	end)
	f:SetScript("OnHide", function()
		YG.wasOpen = nil
		f.search:ClearFocus()
		YG:SetBagButtonsChecked(false)
		PlaySound("igBackPackClose")
	end)

	YB:CreateMover(f, "Bags", function(point, relPoint, x, y)
		local db = YG.db.profile
		db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
		YG:Layout()
		YB:NotifyOptionsChanged()
	end, function()
		YB:OpenOptions("bags")
	end)
end

-- The bag bar buttons light up while the bag is open, like Blizzard's.
function YG:SetBagButtonsChecked(checked)
	local state = checked and 1 or 0
	_G.MainMenuBarBackpackButton:SetChecked(state)
	for i = 0, NUM_BAG_SLOTS - 1 do
		local button = _G["CharacterBag" .. i .. "Slot"]
		if button then
			button:SetChecked(state)
		end
	end
end

-- Grid of every slot, backpack first. Bags can be swapped at any time, so this
-- runs on every update (it is cheap).
function YG:Layout()
	local f, db = self.frame, self.db.profile
	local size, gap, cols = db.buttonSize, db.spacing, db.columns
	local index = 0
	for bag = 0, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(bag)
		for slot = 1, slots do
			local button = buttons[bag][slot] or createButton(bag, slot)
			local col, row = index % cols, math.floor(index / cols)
			button:SetWidth(size)
			button:SetHeight(size)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + col * (size + gap), -HEADER - row * (size + gap))
			button:Show()
			index = index + 1
		end
		for slot = slots + 1, #buttons[bag] do
			buttons[bag][slot]:Hide()
		end
	end
	local rows = math.max(math.ceil(index / cols), 1)
	f:SetScale(db.scale)
	f:SetWidth(PAD * 2 + cols * (size + gap) - gap)
	f:SetHeight(HEADER + rows * (size + gap) - gap + FOOTER)
	f:ClearAllPoints()
	f:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	YB:SquareBackdrop(f, db.bgAlpha)
end

local function itemQuality(bag, slot, quality)
	if quality and quality >= 0 then
		return quality
	end
	local link = GetContainerItemLink(bag, slot)
	return link and select(3, GetItemInfo(link))
end

function YG:UpdateSlot(bag, slot)
	local button = buttons[bag][slot]
	local texture, count, locked, quality, readable = GetContainerItemInfo(bag, slot)
	local isQuestItem, questId, isActive = GetContainerItemQuestInfo(bag, slot)

	SetItemButtonTexture(button, texture)
	SetItemButtonCount(button, count)
	SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)

	-- Quest items: yellow border, and a "!" on items that start a quest.
	local questTexture = _G[button:GetName() .. "IconQuestTexture"]
	if questId and not isActive then
		questTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
		questTexture:Show()
	else
		questTexture:Hide()
	end

	local r, g, b = 0, 0, 0
	if questId or isQuestItem then
		r, g, b = 1, 0.82, 0
	elseif texture and self.db.profile.qualityBorders then
		quality = itemQuality(bag, slot, quality)
		if quality and quality >= 2 then
			local c = ITEM_QUALITY_COLORS[quality]
			r, g, b = c.r, c.g, c.b
		end
	end
	button:SetBackdropBorderColor(r, g, b, 1)

	if texture then
		ContainerFrame_UpdateCooldown(bag, button)
		button.hasItem = 1
	else
		_G[button:GetName() .. "Cooldown"]:Hide()
		button.hasItem = nil
	end
	button.readable = readable

	if button == GameTooltip:GetOwner() then
		button.UpdateTooltip(button)
	end
end

function YG:UpdateAll()
	local free, total = 0, 0
	for bag = 0, NUM_BAG_SLOTS do
		local slots = GetContainerNumSlots(bag)
		for slot = 1, slots do
			self:UpdateSlot(bag, slot)
		end
		local bagFree, bagType = GetContainerNumFreeSlots(bag)
		if bagType == 0 then -- only general bags; not soul, herb, ... bags
			free, total = free + bagFree, total + slots
		end
	end
	self.frame.slots:SetText(format("%d / %d free", free, total))
	self:UpdateMoney()
	self:UpdateSearch()
end

function YG:UpdateLock(bag, slot)
	local button = buttons[bag] and buttons[bag][slot]
	if button and button:IsShown() then
		local _, _, locked = GetContainerItemInfo(bag, slot)
		SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
	end
end

function YG:UpdateCooldowns()
	if not self.frame:IsShown() then
		return
	end
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local button = buttons[bag][slot]
			if button and GetContainerItemInfo(bag, slot) then
				ContainerFrame_UpdateCooldown(bag, button)
			end
		end
	end
end

function YG:UpdateMoney()
	if self.frame then
		self.frame.money:SetText(formatMoney(GetMoney()))
	end
end

function YG:UpdateSearch()
	local text = strlower(strtrim(self.frame.search:GetText()))
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local button = buttons[bag][slot]
			if button then
				local match = true
				if text ~= "" then
					local link = GetContainerItemLink(bag, slot)
					local name = link and GetItemInfo(link)
					match = name and strfind(strlower(name), text, 1, true) and true or false
				end
				button:SetAlpha(match and 1 or SEARCH_DIM)
			end
		end
	end
end

-- Opening and closing (Hooks.lua routes Blizzard's bag functions here).

function YG:Open()
	self.frame:Show()
end

function YG:Close()
	self.frame:Hide()
end

function YG:Toggle()
	if self.frame:IsShown() then
		self:Close()
	else
		self:Open()
	end
end
