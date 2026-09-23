local _, ns = ...
local YB = ns.YB

YB.movers = {}

local function round(v)
	return math.floor(v + 0.5)
end

-- Alignment grid shown while moving bars: lines every gridSize pixels from the
-- screen centre, with the centre lines in red.

local grid

local function buildGrid(size)
	if not grid then
		grid = CreateFrame("Frame", nil, UIParent)
		grid:SetAllPoints(UIParent)
		grid:SetFrameStrata("BACKGROUND")
		grid.lines = {}
	end
	for _, line in ipairs(grid.lines) do
		line:Hide()
	end
	local n = 0
	local function addLine(vertical, offset, isCenter)
		n = n + 1
		local tex = grid.lines[n] or grid:CreateTexture(nil, "BACKGROUND")
		grid.lines[n] = tex
		tex:SetTexture(YB.WHITE)
		if isCenter then
			tex:SetVertexColor(1, 0.25, 0.25, 0.6)
		else
			tex:SetVertexColor(1, 1, 1, 0.12)
		end
		tex:ClearAllPoints()
		if vertical then
			tex:SetWidth(1)
			tex:SetPoint("TOP", grid, "TOP", offset, 0)
			tex:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
		else
			tex:SetHeight(1)
			tex:SetPoint("LEFT", grid, "LEFT", 0, offset)
			tex:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
		end
		tex:Show()
	end
	addLine(true, 0, true)
	addLine(false, 0, true)
	for offset = size, UIParent:GetWidth() / 2, size do
		addLine(true, offset)
		addLine(true, -offset)
	end
	for offset = size, UIParent:GetHeight() / 2, size do
		addLine(false, offset)
		addLine(false, -offset)
	end
	grid.size = size
end

function YB:UpdateGrid()
	local profile = self.db.profile
	if profile.locked or not profile.moveGrid then
		if grid then
			grid:Hide()
		end
		return
	end
	if not grid or grid.size ~= profile.gridSize then
		buildGrid(profile.gridSize)
	end
	grid:Show()
end

-- Returns the anchor to save after a drag: the frame's own anchor, or with
-- snapping on, its centre snapped to the grid.
local function droppedAnchor(frame)
	local profile = YB.db.profile
	if not profile.snapToGrid then
		local point, _, relPoint, x, y = frame:GetPoint()
		return point, relPoint, round(x), round(y)
	end
	-- Offsets are in the frame's own scale; convert UIParent's centre into it.
	local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	local g = profile.gridSize
	return "CENTER", "CENTER", round((cx - ux * ratio) / g) * g, round((cy - uy * ratio) / g) * g
end

-- Puts a draggable overlay on `frame`, shown only while unlocked.
-- onMoved(point, relPoint, x, y) is called with the new UIParent-relative anchor;
-- onRightClick (optional) is called when the overlay is right-clicked.
function YB:CreateMover(frame, label, onMoved, onRightClick)
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
		if not InCombatLockdown() then
			frame:StartMoving()
		end
	end)
	mover:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		-- Our own saved variables hold the position, not layout-local.txt.
		frame:SetUserPlaced(false)
		onMoved(droppedAnchor(frame))
	end)
	mover:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and onRightClick then
			onRightClick()
		end
	end)
	mover:SetScript("OnEnter", function(overlay)
		GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
		GameTooltip:AddLine(overlay.text:GetText())
		GameTooltip:AddLine("Drag to move", 1, 1, 1)
		if onRightClick then
			GameTooltip:AddLine("Right-click to open its settings", 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	mover:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	mover:Hide()
	frame.yMover = mover
	self.movers[mover] = true
	return mover
end

function YB:SetLocked(locked)
	if not locked and InCombatLockdown() then
		self:Print("Can't unlock bars in combat.")
		return
	end
	self.db.profile.locked = locked
	for mover in pairs(self.movers) do
		if locked then
			mover:Hide()
		else
			mover:SetFrameLevel(mover:GetParent():GetFrameLevel() + 10)
			mover:Show()
		end
	end
	self:UpdateGrid()
	self:UpdateAllFades()
	self:RefreshOptions()
end
