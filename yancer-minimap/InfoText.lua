local _, ns = ...
local YM, YB = ns.YM, ns.YB

-- "FPS: 60  MS: 26  Dur: 94%" on one movable line (/yb move). Hover shows the
-- addon memory use, click frees unused memory.

local frame, text

local function db()
	return YM.db.profile
end

local function colorFPS(fps)
	if fps >= 50 then
		return "|cff33ff33"
	elseif fps >= 25 then
		return "|cffffcc33"
	end
	return "|cffff3333"
end

local function colorMS(ms)
	if ms < 150 then
		return "|cff33ff33"
	elseif ms < 400 then
		return "|cffffcc33"
	end
	return "|cffff3333"
end

-- Lowest durability over the equipped items, in percent (nil when nothing can break).
local function durability()
	local lowest
	for slot = 1, 18 do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			local pct = cur / max * 100
			if not lowest or pct < lowest then
				lowest = pct
			end
		end
	end
	return lowest
end

local function update()
	local p = db()
	local parts = {}
	if p.showFPS then
		local fps = math.floor(GetFramerate() + 0.5)
		parts[#parts + 1] = "FPS: " .. colorFPS(fps) .. fps .. "|r"
	end
	if p.showLatency then
		local _, _, ms = GetNetStats()
		parts[#parts + 1] = "MS: " .. colorMS(ms) .. ms .. "|r"
	end
	if p.showDurability then
		local d = durability()
		if d then
			local r, g = d < 50 and 1 or (100 - d) / 50, d >= 50 and 1 or d / 50
			parts[#parts + 1] = format("Dur: |cff%02x%02x33%d%%|r", r * 255, g * 255, d)
		end
	end
	text:SetText(table.concat(parts, "   "))
	frame:SetWidth(math.max(text:GetStringWidth() + 10, 40))
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("Addon Memory")
	UpdateAddOnMemoryUsage()
	local list, total = {}, 0
	for i = 1, GetNumAddOns() do
		if IsAddOnLoaded(i) then
			local kb = GetAddOnMemoryUsage(i)
			total = total + kb
			list[#list + 1] = { (GetAddOnInfo(i)), kb }
		end
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	for i = 1, math.min(#list, 15) do
		local kb = list[i][2]
		GameTooltip:AddDoubleLine(list[i][1], kb >= 1024 and format("%.1f MB", kb / 1024) or format("%d KB", kb),
			1, 1, 1, 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("Total", format("%.1f MB", total / 1024), 1, 0.82, 0, 1, 0.82, 0)
	local _, _, ms = GetNetStats()
	local down, up = GetNetStats()
	GameTooltip:AddDoubleLine("Bandwidth in / out", format("%.2f / %.2f KB/s", down, up), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("Latency", ms .. " ms", 1, 1, 1, 1, 1, 1)
	GameTooltip:AddLine("Click to free unused memory", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function YM:EnableInfoText()
	frame = CreateFrame("Button", "yancerMinimapInfoText", UIParent)
	frame:SetFrameStrata("LOW")
	frame:SetHeight(20)
	text = frame:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER")
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnClick", function(button)
		local before = collectgarbage("count")
		collectgarbage("collect")
		YB:Print(format("Freed %.1f MB.", (before - collectgarbage("count")) / 1024))
		if GameTooltip:IsOwned(button) then
			showTooltip(button)
		end
	end)
	frame:SetScript("OnEnter", showTooltip)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	local elapsed = 1
	frame:SetScript("OnUpdate", function(_, e)
		elapsed = elapsed + e
		if elapsed >= 1 then
			elapsed = 0
			update()
		end
	end)
	YB:CreateMover(frame, "Info Text", function(point, relPoint, x, y)
		YM:SavePosition("info", point, relPoint, x, y)
		YM:UpdateInfoText()
	end, function()
		YB:OpenOptions("minimap", "info")
	end)
end

function YM:UpdateInfoText()
	if not frame then
		return
	end
	text:SetFont(YB.FONT, db().infoFontSize, "OUTLINE")
	frame:SetHeight(db().infoFontSize + 6)
	frame:ClearAllPoints()
	local point, relPoint, x, y = self:Position("info")
	frame:SetPoint(point, UIParent, relPoint, x, y)
	update()
end
