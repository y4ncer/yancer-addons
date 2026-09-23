local _, ns = ...
local YB = ns.YB

-- Hides Blizzard's default action bars. MainMenuBar itself stays, because the
-- XP bar, bags, micro menu, and the stance/pet/possess/totem bars live in it.
-- The hidden Blizzard buttons keep working, so the default keybinds
-- (1-=, and the bottom/side bar bindings) still cast their action slots.

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

-- Blizzard keybinds that click the (hidden) default buttons for each action page.
-- Used to show those keys on our buttons that share the same slots.
YB.BLIZZARD_BINDINGS = {
	[1] = "ACTIONBUTTON",
	[3] = "MULTIACTIONBAR3BUTTON", -- right bar
	[4] = "MULTIACTIONBAR4BUTTON", -- right bar 2
	[5] = "MULTIACTIONBAR2BUTTON", -- bottom right
	[6] = "MULTIACTIONBAR1BUTTON", -- bottom left
}
