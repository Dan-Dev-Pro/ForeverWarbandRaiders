-- Forever Warband Raiders: link with ForeverDungeonJournal (optional)
-- Uses its item sources, per-character favourites, loot tables and run log when it's installed.
local R = FWR

function R:FDJ()
  local ns = rawget(_G, "ForeverDungeonJournal_NS")
  if type(ns) == "table" and type(ns.DB) == "table" then return ns end
end

-- "Boss · Dungeon", "Quest: name · Dungeon" or nil
function R:JournalSource(id)
  local F = self:FDJ()
  if not F or not F.GetItemSource or not id then return end
  local ok, s = pcall(F.GetItemSource, id)
  if not ok or type(s) ~= "table" then return end
  if F.SHARED_LOOT_IDS and F.SHARED_LOOT_IDS[id] then return "Several dungeons" end
  local d = s.dungeonName or "?"
  if s.mode == "quests" then return "Quest: " .. (s.questName or "?") .. " · " .. d end
  if s.trash then return "Trash · " .. d end
  return (s.bossName or "?") .. " · " .. d
end

function R:OpenInJournal(id)
  local F = self:FDJ()
  if F and F.OpenItemSource then
    local ok, opened = pcall(F.OpenItemSource, id)
    return ok and opened ~= false
  end
end

-- snapshots of the logged-in character (the journal keeps these per character) -------------------
function R:SyncJournal()
  if not self:FDJ() or not self.db then return end
  local c = self:Char()
  local cdb = rawget(_G, "ForeverDungeonJournalCharacterDB")
  if type(cdb) ~= "table" then return end
  local favs = {}
  for _, f in pairs(cdb.favouriteItems or {}) do
    if type(f) == "table" and tonumber(f.id) then
      favs[#favs + 1] = { id = tonumber(f.id), name = f.name, slot = f.slot, q = f.quality,
        dungeon = f.dungeon, boss = f.boss, quest = f.questName }
    end
  end
  table.sort(favs, function(a, b) return (a.name or "") < (b.name or "") end)
  c.fdjFavs = favs
  local runs = {}
  local log = cdb.runLog
  for _, run in ipairs((log and log.runs) or {}) do
    if type(run) == "table" and run.dungeon and run.created then
      local bosses = 0
      for _, k in ipairs(run.kills or {}) do if k.b then bosses = bosses + 1 end end
      runs[#runs + 1] = { dungeon = run.dungeon, t = run.created, bosses = bosses }
    end
  end
  table.sort(runs, function(a, b) return a.t > b.t end)
  while #runs > 40 do table.remove(runs) end
  c.fdjRuns = runs
  c.fdjSeen = time()
end

R:On("PLAYER_LOGIN", function(self) self:SyncJournal() end)
R:On("LOOT_CLOSED", function(self) self:SyncJournal() end)
R:On("PLAYER_ENTERING_WORLD", function(self) self:SyncJournal() end)

-- Runs in the last `days` days, grouped by dungeon
function R:RecentRuns(key, days)
  local c = self:Char(key)
  local since = time() - (days or 7) * 86400
  local by, order = {}, {}
  for _, r in ipairs(c.fdjRuns or {}) do
    if r.t >= since then
      local e = by[r.dungeon]
      if not e then e = { dungeon = r.dungeon, n = 0, bosses = 0, last = r.t }; by[r.dungeon] = e; order[#order + 1] = e end
      e.n = e.n + 1
      e.bosses = e.bosses + r.bosses
      if r.t > e.last then e.last = r.t end
    end
  end
  table.sort(order, function(a, b) return a.last > b.last end)
  return order
end

-- loot suggestions -------------------------------------------------------------------------------
local SLOTWORD = {
  head = { 1 }, neck = { 2 }, shoulder = { 3 }, back = { 15 }, chest = { 5 }, wrist = { 9 }, hands = { 10 },
  waist = { 6 }, legs = { 7 }, feet = { 8 }, finger = { 11, 12 }, trinket = { 13, 14 },
  ["two-hand"] = { 16 }, ["one-hand"] = { 16, 17 }, ["main hand"] = { 16 }, ["off hand"] = { 17 },
  ["held in off-hand"] = { 17 }, ranged = { 18 }, thrown = { 18 }, relic = { 18 }, wand = { 18 },
}
local ARMOR = { cloth = 1, leather = 2, mail = 3, plate = 4 }
local CLASS_ARMOR = { WARRIOR = "plate", PALADIN = "plate", HUNTER = "mail", SHAMAN = "mail",
  ROGUE = "leather", DRUID = "leather", PRIEST = "cloth", MAGE = "cloth", WARLOCK = "cloth" }
local ARMOR_SLOTS = { [1] = true, [3] = true, [5] = true, [9] = true, [10] = true, [6] = true, [7] = true, [8] = true }
R.CLASS_ARMOR = CLASS_ARMOR

-- "Head, Mail" -> slots, armour type
local function parseSlot(text)
  if type(text) ~= "string" then return end
  local a, b = text:match("^%s*([^,]+),?%s*(.-)%s*$")
  a = a and a:lower(); b = b and b:lower()
  local slots = SLOTWORD[a or ""]
  if not slots and b == "shield" then slots = { 17 } end
  if not slots and (b == "wand" or b == "bow" or b == "gun" or b == "crossbow") then slots = { 18 } end
  return slots, ARMOR[b or ""] and b or nil
end
R.parseSlot = parseSlot

local ABBR = { Strength = "Str", Agility = "Agi", Stamina = "Sta", Intellect = "Int", Spirit = "Spi" }
local function statLine(tip)
  local out = {}
  for _, line in ipairs(type(tip) == "table" and tip or {}) do
    if type(line) == "string" then
      local n, stat = line:match("^%+(%d+) (%a+)$")
      if n then out[#out + 1] = "+" .. n .. " " .. (ABBR[stat] or stat) end
      local ap = line:match("%+(%d+) Attack Power")
      if ap then out[#out + 1] = "+" .. ap .. " AP" end
      local hit = line:match("chance to hit by (%d+)%%")
      if hit then out[#out + 1] = hit .. "% hit" end
      local crit = line:match("critical strike by (%d+)%%")
      if crit then out[#out + 1] = crit .. "% crit" end
    end
  end
  return table.concat(out, " ")
end

local function maxLevel(levelText)
  local hi = type(levelText) == "string" and levelText:match("(%d+)%s*$")
  return tonumber(hi) or 0
end

-- Boss drops for a slot from max-level dungeons (top level 58 or more)
function R:Suggestions(key, slot, allArmor)
  local F = self:FDJ()
  if not F then return {} end
  local c = self:Char(key)
  local best = CLASS_ARMOR[c.class or ""]
  local out, seen, pos = {}, {}, {}
  for _, dname in ipairs(F.ORDER or {}) do
    local d = F.DB[dname]
    if type(d) == "table" and maxLevel(d.level) >= 58 then
      for _, boss in ipairs(d.bosses or {}) do
        if type(boss) == "table" and not boss.recipeTab then
          for _, item in ipairs(boss.loot or {}) do
            local slots, armor = parseSlot(item[3])
            local fits = false
            for _, s in ipairs(slots or {}) do if s == slot then fits = true end end
            if fits and not (armor and ARMOR_SLOTS[slot] and not allArmor and best and armor ~= best) then
              local id = tonumber(item[1])
              if id and id <= 0 then id = nil end
              local k = id or item[2]
              if not seen[k] then
                seen[k] = true
                out[#out + 1] = { id = id, name = item[2], slotText = item[3], q = item[4] or 2,
                  dungeon = dname, boss = boss.trash and "Trash" or boss.name, tip = item.tip,
                  stats = statLine(item.tip), level = d.level }
              end
            end
          end
        end
      end
    end
  end
  -- newest, highest-level dungeons first, then better quality
  for i, d in ipairs(F.ORDER or {}) do pos[d] = i end
  table.sort(out, function(a, b)
    local pa, pb = pos[a.dungeon] or 0, pos[b.dungeon] or 0
    if pa ~= pb then return pa > pb end
    if (a.q or 0) ~= (b.q or 0) then return (a.q or 0) > (b.q or 0) end
    return (a.name or "") < (b.name or "")
  end)
  return out
end
