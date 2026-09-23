local _, ns = ...
local YUI = ns.YUI

YUI.movers = {}

local function round(v)
	return math.floor(v + 0.5)
end

-- Puts a draggable overlay on `frame`, shown only while unlocked.
-- onMoved(point, relPoint, x, y) is called with the new UIParent-relative anchor.
function YUI:CreateMover(frame, label, onMoved)
	if frame.yMover then
		return frame.yMover
	end
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	local mover = CreateFrame("Frame", nil, frame)
	mover:SetAllPoints(frame)
	mover:SetBackdrop({ bgFile = self.WHITE, edgeFile = self.WHITE, edgeSize = 1 })
	mover:SetBackdropColor(0.2, 0.6, 1, 0.3)
	mover:SetBackdropBorderColor(0.2, 0.6, 1, 1)

	mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	mover.text:SetPoint("CENTER")
	mover.text:SetText(label)

	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	mover:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	mover:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		-- Our own saved variables hold the position, not layout-local.txt.
		frame:SetUserPlaced(false)
		local point, _, relPoint, x, y = frame:GetPoint()
		onMoved(point, relPoint, round(x), round(y))
	end)

	mover:Hide()
	frame.yMover = mover
	self.movers[mover] = true
	return mover
end

function YUI:SetLocked(locked)
	self.db.profile.locked = locked
	for mover in pairs(self.movers) do
		if locked then
			mover:Hide()
		else
			mover:SetFrameLevel(mover:GetParent():GetFrameLevel() + 5)
			mover:Show()
		end
	end
	self:RefreshOptions()
end
