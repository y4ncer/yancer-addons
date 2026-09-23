local _, ns = ...
local YUI = ns.YUI

YUI.panelFrames = {} -- id -> frame. Frames can't be destroyed, so they are reused per id.

-- rawget avoids AceDB's "**" metatable creating an entry for an unknown id.
function YUI:GetPanelDB(id)
	return rawget(self.db.profile.panels, id)
end

local function getFrame(id)
	local frame = YUI.panelFrames[id]
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "yancerUIPanel_" .. id, UIParent)
	YUI:CreateMover(frame, id, function(point, relPoint, x, y)
		local db = YUI:GetPanelDB(id)
		db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
		YUI:UpdatePanel(id)
		YUI:RefreshOptions()
	end)
	YUI.panelFrames[id] = frame
	return frame
end

function YUI:UpdatePanel(id)
	local db = self:GetPanelDB(id)
	if not db then
		if self.panelFrames[id] then
			self.panelFrames[id]:Hide()
		end
		return
	end

	local frame = getFrame(id)
	frame:ClearAllPoints()
	frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	frame:SetWidth(db.width)
	frame:SetHeight(db.height)
	frame:SetFrameStrata(db.strata)
	frame:SetFrameLevel(db.level)

	local bs = db.borderSize
	frame:SetBackdrop({
		bgFile = self.WHITE,
		edgeFile = bs > 0 and self.WHITE or nil,
		edgeSize = bs,
		insets = { left = bs, right = bs, top = bs, bottom = bs },
	})
	local bg, border = db.bgColor, db.borderColor
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

	local shadow = db.shadow
	self:UpdateShadow(frame, shadow.enabled and shadow.size or 0, shadow.color)

	local mover = frame.yMover
	mover.text:SetText(db.name)
	mover:SetFrameLevel(frame:GetFrameLevel() + 5)

	if db.enabled then
		frame:Show()
	else
		frame:Hide()
	end
end

function YUI:UpdateAllPanels()
	for _, frame in pairs(self.panelFrames) do
		frame:Hide()
	end
	for id in pairs(self.db.profile.panels) do
		self:UpdatePanel(id)
	end
end

function YUI:CreatePanel(name)
	local panels = self.db.profile.panels
	local n = 1
	while rawget(panels, "panel" .. n) do
		n = n + 1
	end
	local id = "panel" .. n
	local db = panels[id] -- indexing creates the entry filled from the "**" defaults
	name = name and strtrim(name) or ""
	db.name = name ~= "" and name or ("Panel " .. n)

	self:UpdatePanel(id)
	if not self.db.profile.locked then
		self.panelFrames[id].yMover:Show()
	end
	self:RefreshOptions()
	return id
end

function YUI:DeletePanel(id)
	self.db.profile.panels[id] = nil
	self:UpdatePanel(id)
	self:RefreshOptions()
end
