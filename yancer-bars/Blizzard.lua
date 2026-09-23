local _, ns = ...
local YB = ns.YB

-- Hides Blizzard's default action bars. MainMenuBar itself stays, because the
-- XP bar, bags, micro menu, and the stance/pet/possess/totem bars live in it.
-- The default keybinds (1-=, bottom/side bar binds) are moved onto our buttons,
-- see UpdateBlizzardBindings below.

local hidden = CreateFrame("Frame")
hidden:Hide()

local REPARENT = {
	"BonusActionBarFrame",
	"MultiBarBottomLeft",
	"MultiBarBottomRight",
	"MultiBarLeft",
	"MultiBarRight",
	"ActionBarUpButton",
	"ActionBarDownButton",
}

local ART = {
	"MainMenuBarTexture0",
	"MainMenuBarTexture1",
	"MainMenuBarTexture2",
	"MainMenuBarTexture3",
	"MainMenuBarLeftEndCap",
	"MainMenuBarRightEndCap",
	"MainMenuBarPageNumber",
}

-- Must run out of combat. Undoing it needs a /reload.
function YB:HideBlizzardBars()
	if self.blizzardHidden then
		return
	end
	for i = 1, 12 do
		_G["ActionButton" .. i]:SetParent(hidden)
	end
	for _, name in ipairs(REPARENT) do
		_G[name]:SetParent(hidden)
	end
	for _, name in ipairs(ART) do
		_G[name]:SetAlpha(0)
	end
	-- The now-empty strip would otherwise swallow clicks meant for our bars.
	MainMenuBar:EnableMouse(false)
	self.blizzardHidden = true
end

-- Blizzard keybinds for each action page's default bar.
YB.BLIZZARD_BINDINGS = {
	[1] = "ACTIONBUTTON",
	[3] = "MULTIACTIONBAR3BUTTON", -- right bar
	[4] = "MULTIACTIONBAR4BUTTON", -- right bar 2
	[5] = "MULTIACTIONBAR2BUTTON", -- bottom right
	[6] = "MULTIACTIONBAR1BUTTON", -- bottom left
}

-- While the default bars are hidden, the keys bound to them (1-=, the side and
-- bottom bar binds) are redirected to our buttons on the same page with override
-- bindings, so a key press clicks our secure button directly instead of going
-- through Blizzard's hidden buttons. If several bars share a page, the lowest
-- numbered bar gets the keys. Overrides can't change in combat.

local bindOwner = CreateFrame("Frame")
local appliedSignature

function YB:UpdateBlizzardBindings()
	if InCombatLockdown() then
		self.refreshPending = true
		return
	end
	local wanted = {} -- key -> button name
	if self.blizzardHidden then
		local nums = {}
		for num, header in pairs(self.barFrames) do
			if header.active then
				nums[#nums + 1] = num
			end
		end
		table.sort(nums)
		local claimed = {}
		for _, num in ipairs(nums) do
			local header = self.barFrames[num]
			local page = header.db.page
			local prefix = self.BLIZZARD_BINDINGS[page]
			if prefix and not claimed[page] then
				claimed[page] = true
				for i, button in pairs(header.buttons) do
					for _, key in ipairs({ GetBindingKey(prefix .. i) }) do
						wanted[key] = button:GetName()
					end
				end
			end
		end
	end

	-- Only touch bindings when something changed: changing them fires
	-- UPDATE_BINDINGS, which calls back into this function.
	local keys = {}
	for key in pairs(wanted) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = key .. "=" .. wanted[key]
	end
	local signature = table.concat(parts, ";")
	if signature == appliedSignature then
		return
	end
	appliedSignature = signature

	ClearOverrideBindings(bindOwner)
	for key, buttonName in pairs(wanted) do
		SetOverrideBindingClick(bindOwner, false, key, buttonName)
	end
end
