local _, ns = ...
local YB = ns.YB

-- One shared ticker drives mouseover fading and range/usability colouring.
-- It only runs while some bar fades on mouseover or range colouring is on.
-- (SetAlpha isn't a protected call, so this works in combat too.)

local ticker = CreateFrame("Frame")
ticker:Hide()

local FADE_INTERVAL, RANGE_INTERVAL = 0.1, 0.2
local fadeElapsed, rangeElapsed = 0, 0

function YB:UpdateFade(header)
	local db = header.db
	if not header.active or not db then
		return
	end
	local alpha = db.alpha
	-- Faded bars come back while moving bars or while holding a spell/item to drop.
	local forceShow = not self.db.profile.locked or GetCursorInfo()
	if db.mouseover and not forceShow and not MouseIsOver(header) then
		alpha = db.fadeAlpha
	end
	header:SetAlpha(alpha)
end

function YB:UpdateAllFades()
	for _, header in pairs(self.barFrames) do
		if header.active and header.db.mouseover then
			self:UpdateFade(header)
		end
	end
end

-- Icon tint: red out of range, blue without enough mana, grey when unusable.
local function colorButton(button)
	local action = button.action
	if not action or not HasAction(action) then
		return
	end
	local icon = _G[button:GetName() .. "Icon"]
	local usable, noMana = IsUsableAction(action)
	if IsActionInRange(action) == 0 then
		icon:SetVertexColor(0.9, 0.15, 0.15)
	elseif usable then
		icon:SetVertexColor(1, 1, 1)
	elseif noMana then
		icon:SetVertexColor(0.35, 0.45, 1)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
	end
end

function YB:UpdateAllRangeColors()
	for _, header in pairs(self.barFrames) do
		if header.active and header:IsVisible() then
			for _, button in pairs(header.buttons) do
				colorButton(button)
			end
		end
	end
end

-- Blizzard recolours the icon on usability events; re-apply ours straight away.
hooksecurefunc("ActionButton_UpdateUsable", function(button)
	if button.yancer and YB.db.profile.rangeColoring then
		colorButton(button)
	end
end)

ticker:SetScript("OnUpdate", function(_, elapsed)
	fadeElapsed = fadeElapsed + elapsed
	if fadeElapsed >= FADE_INTERVAL then
		fadeElapsed = 0
		YB:UpdateAllFades()
	end
	rangeElapsed = rangeElapsed + elapsed
	if rangeElapsed >= RANGE_INTERVAL and YB.db.profile.rangeColoring then
		rangeElapsed = 0
		YB:UpdateAllRangeColors()
	end
end)

function YB:UpdateTicker()
	local needed = self.db.profile.rangeColoring
	for _, header in pairs(self.barFrames) do
		if header.active and header.db.mouseover then
			needed = true
		end
	end
	if needed then
		ticker:Show()
	else
		ticker:Hide()
	end
end

-- Runs func once after `seconds`.
function YB:After(seconds, func)
	local f = CreateFrame("Frame")
	local left = seconds
	f:SetScript("OnUpdate", function(frame, elapsed)
		left = left - elapsed
		if left <= 0 then
			frame:SetScript("OnUpdate", nil)
			func()
		end
	end)
end
