local _, ns = ...
local YC, YB = ns.YC, ns.YB

-- URL box: shown when a chat URL is clicked, with the URL selected for Ctrl+C.
StaticPopupDialogs["YANCER_CHAT_URL"] = {
	text = "Press Ctrl+C to copy the link.",
	button1 = CLOSE,
	hasEditBox = 1,
	hasWideEditBox = 1,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(self, url)
		local editBox = _G[self:GetName() .. "WideEditBox"] or _G[self:GetName() .. "EditBox"]
		editBox:SetText(url)
		editBox:SetFocus()
		editBox:HighlightText()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
}

function YC:ShowURL(url)
	StaticPopup_Show("YANCER_CHAT_URL", nil, nil, url)
end

-- Copy Chat window: the window's recent lines as plain text.

local function plain(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	return text
end

local copyFrame

local function getCopyFrame()
	if copyFrame then
		return copyFrame
	end
	local f = CreateFrame("Frame", "yancerChatCopyFrame", UIParent)
	f:SetWidth(600)
	f:SetHeight(400)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	YB:SquareBackdrop(f, 0.9)
	YB:Outline(f)
	tinsert(UISpecialFrames, "yancerChatCopyFrame") -- Escape closes it

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText("Copy Chat  |cffaaaaaa(Ctrl+A, Ctrl+C)|r")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local scroll = CreateFrame("ScrollFrame", "yancerChatCopyScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -28)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)

	local editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(555)
	editBox:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(editBox)
	f.editBox = editBox
	f.scroll = scroll

	copyFrame = f
	return f
end

function YC:ShowCopy(chatFrame)
	local f = getCopyFrame()
	local lines = {}
	for i, text in ipairs(chatFrame.yHistory or {}) do
		lines[i] = plain(text)
	end
	f.editBox:SetText(table.concat(lines, "\n"))
	f:Show()
	f.editBox:SetFocus()
	f.editBox:HighlightText()
end

-- Small copy button in each window's top-right corner, faint until hovered.
function YC:ApplyCopyButtons()
	for _, frame in ipairs(self:ChatFrames()) do
		if frame.yHistory then
			local button = frame.yCopyButton
			if not button then
				button = CreateFrame("Button", nil, frame)
				button:SetWidth(18)
				button:SetHeight(18)
				button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
				button:SetFrameLevel(frame:GetFrameLevel() + 5)
				YB:SquareBackdrop(button, 0.6)
				local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				label:SetPoint("CENTER", 1, 0)
				label:SetText("C")
				button:SetAlpha(0.3)
				button:SetScript("OnEnter", function(b)
					b:SetAlpha(1)
					GameTooltip:SetOwner(b, "ANCHOR_LEFT")
					GameTooltip:AddLine("Copy Chat")
					GameTooltip:Show()
				end)
				button:SetScript("OnLeave", function(b)
					b:SetAlpha(0.3)
					GameTooltip:Hide()
				end)
				button:SetScript("OnClick", function()
					YC:ShowCopy(frame)
				end)
				frame.yCopyButton = button
			end
			if self.db.profile.copyButton then
				button:Show()
			else
				button:Hide()
			end
		end
	end
end
