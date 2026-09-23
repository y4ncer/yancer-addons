local _, ns = ...
local YC, YB = ns.YC, ns.YB

local hidden = CreateFrame("Frame")
hidden:Hide()

local TAB_TEXTURES = {
	"Left", "Middle", "Right",
	"SelectedLeft", "SelectedMiddle", "SelectedRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}

local EDITBOX_TEXTURES = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }

local function clearTexture(name)
	local tex = _G[name]
	if tex then
		tex:SetTexture(nil)
	end
end

-- Square style. Blizzard fades the chat textures by changing their alpha, so the
-- textures are cleared instead of hidden. Undoing this needs a /reload.
function YC:ApplyStyle()
	local db = self.db.profile
	for _, frame in ipairs(self:ChatFrames()) do
		local name = frame:GetName()
		if db.square then
			if not frame.yBackground then
				for _, tex in ipairs(CHAT_FRAME_TEXTURES) do
					clearTexture(name .. tex)
				end
				for _, tex in ipairs(TAB_TEXTURES) do
					clearTexture(name .. "Tab" .. tex)
				end
				local bg = CreateFrame("Frame", nil, frame)
				bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
				bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
				bg:SetFrameLevel(0)
				YB:Outline(bg)
				frame.yBackground = bg

				local editBox = _G[name .. "EditBox"]
				if editBox then
					for _, tex in ipairs(EDITBOX_TEXTURES) do
						clearTexture(name .. "EditBox" .. tex)
					end
					YB:SquareBackdrop(editBox, 0.8)
					YB:Outline(editBox)
				end
			end
			YB:SquareBackdrop(frame.yBackground, db.bgAlpha)
		end

		if db.hideButtons then
			local buttonFrame = _G[name .. "ButtonFrame"]
			if buttonFrame then
				buttonFrame:SetParent(hidden)
			end
		end

		local editBox = _G[name .. "EditBox"]
		if editBox then
			editBox:ClearAllPoints()
			if db.editBoxTop then
				editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -4, 26)
				editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 4, 26)
			else
				editBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -4, -6)
				editBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 4, -6)
			end
		end
	end
	if db.hideButtons then
		for _, name in ipairs({ "ChatFrameMenuButton", "FriendsMicroButton" }) do
			if _G[name] then
				_G[name]:SetParent(hidden)
			end
		end
	end
end

-- Position & size of the main chat window. Windows docked to it follow it.
-- Blizzard's frame position manager leaves user-placed frames alone, and any
-- other Blizzard SetPoint is undone.

local holder

local function place()
	local frame = _G.ChatFrame1
	if not YC.db.profile.manage or not holder then
		return
	end
	-- Blizzard restores its saved size right before its SetPoint, so re-apply ours too.
	frame.yPlacing = true
	frame:SetWidth(YC.db.profile.width)
	frame:SetHeight(YC.db.profile.height)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	frame.yPlacing = nil
end

function YC:ApplyPosition()
	local db = self.db.profile
	local frame = _G.ChatFrame1
	if not db.manage then
		if holder then
			holder:Hide()
		end
		return
	end
	if not holder then
		holder = CreateFrame("Frame", "yancerChatHolder", UIParent)
		holder:SetFrameStrata("HIGH")
		YB:CreateMover(holder, "Chat", function(point, relPoint, x, y)
			db = YC.db.profile
			db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
			YC:ApplyPosition()
			YB:NotifyOptionsChanged()
		end, function()
			YB:OpenOptions("chat")
		end)
		hooksecurefunc(frame, "SetPoint", function(f)
			if not f.yPlacing then
				place()
			end
		end)
		if not YB.db.profile.locked then
			holder.yMover:Show()
		end
	end
	holder:ClearAllPoints()
	holder:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	holder:SetWidth(db.width)
	holder:SetHeight(db.height)
	holder:Show()

	frame:SetUserPlaced(true)
	-- Moving is done with /yb move; Blizzard's own tab dragging would fight it.
	FCF_SetLocked(frame, 1)
	place()
end

-- Mouse wheel: normal = a few lines, Shift = top/bottom, Ctrl = a page.
local function onMouseWheel(frame, delta)
	if IsShiftKeyDown() then
		if delta > 0 then
			frame:ScrollToTop()
		else
			frame:ScrollToBottom()
		end
	elseif IsControlKeyDown() then
		if delta > 0 then
			frame:PageUp()
		else
			frame:PageDown()
		end
	else
		for _ = 1, YC.db.profile.scrollLines do
			if delta > 0 then
				frame:ScrollUp()
			else
				frame:ScrollDown()
			end
		end
	end
end

-- Blizzard also assigns its own wheel handler to chat windows it sets up later;
-- replacing the global makes those use ours too.
_G.FloatingChatFrame_OnMouseScroll = onMouseWheel

function YC:ApplyScrolling()
	local db = self.db.profile
	for _, frame in ipairs(self:ChatFrames()) do
		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", onMouseWheel)
		if frame:GetMaxLines() ~= db.maxLines then
			frame:SetMaxLines(db.maxLines)
		end
		frame:SetFading(db.fading)
		frame:SetTimeVisible(db.fadeTime)
	end
end
