local _, ns = ...
local YQ = ns.YQ
local DB = ns.DB

-- Which mobs to kill and which mobs/objects drop each quest item. The 3.3.5 API
-- doesn't say, so it comes from the bundled database (Data/QuestDB.lua, generated
-- from pfQuest-wotlk by tools/gen_questdb.py), matched to the quest log's
-- objectives. Mobs and objects are looked up by name, which also works when a
-- server uses other NPC ids for the same mob.

local quests = {}   -- quest log index -> quest
local byUnit = {}   -- mob name -> { { quest, objective, chance }, ... }
local byObject = {} -- object name -> { { quest, objective }, ... }

local function add(map, name, quest, objective, chance)
	if not name then
		return
	end
	local list = map[name]
	if not list then
		list = {}
		map[name] = list
	end
	list[#list + 1] = { quest = quest, objective = objective, chance = chance }
end

local function unitName(id)
	local u = DB.units[id]
	return u and u[1]
end

-- Fills objective.kill / .drops / .objects from the quest's database entry.
-- Objectives are matched by name first. Whatever is left goes to the only
-- unmatched objective of that type, if there is exactly one.
local function resolve(quest, entry)
	local loose = { monster = {}, item = {}, object = {} }
	local usedUnits, usedItems, usedObjects = {}, {}, {}
	for _, o in ipairs(quest.objectives) do
		if o.type == "monster" then
			for _, id in ipairs(entry.k or {}) do
				if unitName(id) == o.name then
					o.kill = o.kill or {}
					tinsert(o.kill, id)
					usedUnits[id] = true
				end
			end
			if not o.kill then
				tinsert(loose.monster, o)
			end
		elseif o.type == "item" then
			for id, src in pairs(entry.i or {}) do
				if DB.items[id] == o.name then
					o.item, o.drops, o.objects = id, src.u, src.o
					usedItems[id] = true
				end
			end
			if not o.item then
				tinsert(loose.item, o)
			end
		elseif o.type == "object" then
			for _, id in ipairs(entry.o or {}) do
				if DB.objects[id] == o.name then
					o.use = o.use or {}
					tinsert(o.use, id)
					usedObjects[id] = true
				end
			end
			if not o.use then
				tinsert(loose.object, o)
			end
		end
	end
	if #loose.monster == 1 then
		for _, id in ipairs(entry.k or {}) do
			if not usedUnits[id] then
				local o = loose.monster[1]
				o.kill = o.kill or {}
				tinsert(o.kill, id)
			end
		end
	end
	if #loose.item == 1 then
		local left
		for id in pairs(entry.i or {}) do
			if not usedItems[id] then
				left = left and -1 or id
			end
		end
		if left and left ~= -1 then
			local o = loose.item[1]
			o.item, o.drops, o.objects = left, entry.i[left].u, entry.i[left].o
		end
	end
	if #loose.object == 1 then
		for _, id in ipairs(entry.o or {}) do
			if not usedObjects[id] then
				local o = loose.object[1]
				o.use = o.use or {}
				tinsert(o.use, id)
			end
		end
	end
end

local function index(quest)
	if quest.complete then
		return
	end
	for _, o in ipairs(quest.objectives) do
		if not o.finished then
			if o.type == "monster" then
				if o.kill then
					for _, id in ipairs(o.kill) do
						add(byUnit, unitName(id), quest, o)
					end
				end
				-- Also the name in the text ("Kobold Vermin slain: 3/10"), for quests the DB doesn't know.
				if not (o.kill and unitName(o.kill[1]) == o.name) then
					add(byUnit, o.name, quest, o)
				end
			elseif o.type == "item" then
				local drops = o.drops or {}
				for i = 1, #drops, 2 do
					add(byUnit, unitName(drops[i]), quest, o, drops[i + 1])
				end
				for _, id in ipairs(o.objects or {}) do
					add(byObject, DB.objects[id], quest, o)
				end
			elseif o.type == "object" then
				for _, id in ipairs(o.use or {}) do
					add(byObject, DB.objects[id], quest, o)
				end
				add(byObject, o.name, quest, o)
			end
		end
	end
end

function YQ:BuildQuestIndex()
	wipe(quests)
	wipe(byUnit)
	wipe(byObject)
	for i = 1, GetNumQuestLogEntries() do
		local title, level, questTag, _, isHeader, _, isComplete, isDaily, questID = GetQuestLogTitle(i)
		if title and not isHeader then
			local quest = {
				index = i, id = questID, title = title, level = level, tag = questTag, daily = isDaily,
				complete = isComplete == 1, objectives = {},
			}
			for j = 1, GetNumQuestLeaderBoards(i) do
				local text, objType, finished = GetQuestLogLeaderBoard(j, i)
				if text then
					local name = text:match("^(.-):%s") or text
					if objType == "monster" then
						name = name:gsub(" slain$", "")
					end
					local have, need = text:match("(%d+)/(%d+)")
					tinsert(quest.objectives, {
						text = text, type = objType, finished = finished, name = name,
						have = tonumber(have), need = tonumber(need),
					})
				end
			end
			local entry = questID and DB.quests[questID]
			if entry then
				resolve(quest, entry)
			end
			quest.known = entry ~= nil
			quests[i] = quest
			index(quest)
		end
	end
end

-- The quest log changes in bursts: rebuild once, on the next frame.
local pending = CreateFrame("Frame")
pending:Hide()
pending:SetScript("OnUpdate", function(self)
	self:Hide()
	YQ:BuildQuestIndex()
end)

function YQ:QUEST_LOG_UPDATE()
	pending:Show()
end

----------------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------------

local function objectiveLine(o)
	local text = o.text
	if o.have then
		text = o.have .. "/" .. o.need .. " " .. (o.text:match("^(.-):%s") or o.name)
	end
	return text
end

local function colorOf(o)
	if o.finished then
		return 0.5, 0.5, 0.5
	elseif o.have then
		return YQ:ProgressColor(o.have, o.need)
	end
	return 1, 1, 1
end

-- Adds "Quest title" and its matching objectives (once each) to the tooltip.
local function addEntries(tooltip, list)
	local shownQuest, shownObjective = {}, {}
	for _, e in ipairs(list) do
		if not shownQuest[e.quest] then
			shownQuest[e.quest] = true
			local c = GetQuestDifficultyColor(e.quest.level)
			tooltip:AddLine(e.quest.title, c.r, c.g, c.b)
		end
		if not shownObjective[e.objective] then
			shownObjective[e.objective] = true
			local text = "  - " .. objectiveLine(e.objective)
			if e.chance then
				text = text .. format(" |cffaaaaaa(%s%%)|r", e.chance >= 1 and math.floor(e.chance + 0.5) or e.chance)
			end
			tooltip:AddLine(text, colorOf(e.objective))
		end
	end
end

local function onTooltipSetUnit(tooltip)
	if not YQ.db.profile.unitTooltip then
		return
	end
	local _, unit = tooltip:GetUnit()
	if not unit or UnitIsPlayer(unit) then
		return
	end
	local list = byUnit[UnitName(unit)]
	if list then
		addEntries(tooltip, list)
		tooltip:Show()
	end
end

-- World objects (chests, plants, ...) have no API: their tooltip is a single name
-- line owned by UIParent.
local inObjectTooltip
local function onTooltipShow(tooltip)
	if inObjectTooltip or not YQ.db.profile.objectTooltip or tooltip:GetOwner() ~= UIParent
		or tooltip:GetUnit() or tooltip:GetItem() or tooltip:GetSpell() then
		return
	end
	local name = GameTooltipTextLeft1:GetText()
	local list = name and byObject[name]
	if list then
		inObjectTooltip = true
		addEntries(tooltip, list)
		tooltip:Show()
		inObjectTooltip = nil
	end
end

-- "Kobold Miner 40%, Kobold Tunneler 35%": unique names, highest chance first.
local function dropList(drops, max)
	local best, order = {}, {}
	for i = 1, #drops, 2 do
		local name = unitName(drops[i])
		if name then
			if not best[name] then
				tinsert(order, name)
				best[name] = drops[i + 1]
			elseif drops[i + 1] > best[name] then
				best[name] = drops[i + 1]
			end
		end
	end
	table.sort(order, function(a, b)
		return best[a] > best[b]
	end)
	local parts = {}
	for i = 1, math.min(#order, max) do
		local chance = best[order[i]]
		parts[i] = format("%s %s%%", order[i], chance >= 1 and math.floor(chance + 0.5) or chance)
	end
	if #order > max then
		parts[#parts + 1] = format("+%d more", #order - max)
	end
	return table.concat(parts, ", ")
end

-- "Kobold Vermin (Elwynn Forest)".
local function killList(ids, max)
	local seen, parts = {}, {}
	for _, id in ipairs(ids) do
		local u = DB.units[id]
		if u and not seen[u[1]] then
			seen[u[1]] = true
			local zone = DB.zones[u[2]]
			parts[#parts + 1] = zone and (u[1] .. " (" .. zone .. ")") or u[1]
		end
	end
	local more = #parts - max
	for i = #parts, max + 1, -1 do
		parts[i] = nil
	end
	if more > 0 then
		parts[#parts + 1] = format("+%d more", more)
	end
	return table.concat(parts, ", ")
end

local function objectList(ids, max)
	local seen, parts = {}, {}
	for _, id in ipairs(ids) do
		local name = DB.objects[id]
		if name and not seen[name] and #parts < max then
			seen[name] = true
			parts[#parts + 1] = name
		end
	end
	return table.concat(parts, ", ")
end

local function addSource(label, text)
	if text and text ~= "" then
		GameTooltip:AddLine("      " .. label .. ": |cffffffff" .. text .. "|r", 0.6, 0.6, 0.6, true)
	end
end

-- Hovering a quest in the tracker: each objective with where it comes from.
function YQ:ShowTrackerTooltip(button)
	if not self.db.profile.trackerTooltip or button.type ~= "QUEST" then
		return
	end
	local questIndex = GetQuestIndexForWatch(button.index)
	local quest = questIndex and quests[questIndex]
	if not quest then
		return
	end
	local max = self.db.profile.maxSources
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	local c = GetQuestDifficultyColor(quest.level)
	GameTooltip:AddLine(self:LevelTag(quest.level, quest.tag, quest.daily) .. " " .. quest.title, c.r, c.g, c.b)
	local any
	for _, o in ipairs(quest.objectives) do
		GameTooltip:AddLine(objectiveLine(o), colorOf(o))
		if o.kill then
			addSource("Kill", killList(o.kill, max))
			any = true
		end
		if o.drops and #o.drops > 0 then
			addSource("Drops from", dropList(o.drops, max))
			any = true
		end
		if o.objects and #o.objects > 0 then
			addSource("Found in", objectList(o.objects, max))
			any = true
		end
		if o.use then
			addSource("Use", objectList(o.use, max))
			any = true
		end
	end
	if not any and #quest.objectives > 0 then
		GameTooltip:AddLine(quest.known and "No mob or drop sources for these objectives."
			or "This quest isn't in the quest database.", 0.5, 0.5, 0.5, true)
	end
	GameTooltip:Show()
end

function YQ:EnableQuestInfo()
	self:RegisterEvent("QUEST_LOG_UPDATE")
	GameTooltip:HookScript("OnTooltipSetUnit", onTooltipSetUnit)
	GameTooltip:HookScript("OnShow", onTooltipShow)
	pending:Show()
end
