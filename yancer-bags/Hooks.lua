local _, ns = ...
local YG = ns.YG

-- Blizzard's bag functions (bag bar buttons, B / Shift+B and the bag keybinds,
-- merchant, mail, Escape) open our window for the backpack and bags 1-4. Bank
-- bags (5-11) and the keyring still use Blizzard's frames.

local original = {}

local function ours(id)
	return id and id >= 0 and id <= NUM_BAG_SLOTS
end

local function replace(name, func)
	original[name] = _G[name]
	_G[name] = func
end

function YG:InstallHooks()
	replace("ToggleBag", function(id)
		if ours(id) then
			YG:Toggle()
		else
			original.ToggleBag(id)
		end
	end)
	replace("OpenBag", function(id)
		if ours(id) then
			YG:Open()
		else
			original.OpenBag(id)
		end
	end)
	replace("CloseBag", function(id)
		if ours(id) then
			YG:Close()
		else
			original.CloseBag(id)
		end
	end)
	replace("ToggleBackpack", function()
		YG:Toggle()
	end)
	-- Merchant and mail open the backpack and close it again afterwards, unless
	-- it was already open: OpenBackpack returns whether it was.
	replace("OpenBackpack", function()
		local wasOpen = YG.frame:IsShown()
		YG:Open()
		YG.wasOpen = wasOpen
		return wasOpen
	end)
	replace("CloseBackpack", function()
		if not YG.wasOpen then
			YG:Close()
		end
	end)
	replace("OpenAllBags", function(forceOpen)
		if not UIParent:IsShown() then
			return
		end
		if YG.frame:IsShown() and not forceOpen then
			YG:Close()
			CloseBankBagFrames()
		else
			YG:Open()
			if BankFrame:IsShown() then
				for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
					original.OpenBag(i)
				end
			end
		end
	end)
	replace("CloseAllBags", function()
		YG:Close()
		original.CloseAllBags()
	end)
end
