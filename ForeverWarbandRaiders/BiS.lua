-- Forever Warband Raiders: best in slot
-- Caps first (hit, spell hit, defense: in the order set), then stat weights. Primary stats get the
-- Blessing of Kings style % bonus. Works on whole sets, because caps depend on every item together.
local R = FWR

R.STATS = {
  { "str", "Strength", true }, { "agi", "Agility", true }, { "sta", "Stamina", true },
  { "int", "Intellect", true }, { "spi", "Spirit", true },
  { "ap", "Attack Power" }, { "rap", "Ranged Attack Power" }, { "crit", "Crit %" }, { "hit", "Hit %" },
  { "dps", "Weapon DPS" }, { "sp", "Spell power" }, { "heal", "Healing" }, { "spellcrit", "Spell crit %" },
  { "spellhit", "Spell hit %" }, { "mp5", "Mana per 5" }, { "def", "Defense" }, { "dodge", "Dodge %" },
  { "parry", "Parry %" }, { "block", "Block %" }, { "blockval", "Block value" }, { "armor", "Armor" },
}
R.PRIMARY = { str = true, agi = true, sta = true, int = true, spi = true }
R.CAPS = { { "hit", "Hit cap %" }, { "spellhit", "Spell hit cap %" }, { "def", "Defense cap" } }

-- Starter weights: rough starting points to replace with your own -------------------------------
R.TEMPLATES = {
  { id = "melee_str", name = "Melee (Strength)", style = "2H", caps = { hit = 9 },
    w = { str = 2, agi = 1, sta = 0.2, ap = 1, crit = 22, hit = 28, dps = 12 } },
  { id = "melee_agi", name = "Melee (Agility)", style = "DW", caps = { hit = 9 },
    w = { agi = 2, str = 1, sta = 0.2, ap = 1, crit = 22, hit = 28, dps = 10 } },
  { id = "ranged", name = "Ranged", style = "2H", caps = { hit = 9 },
    w = { agi = 2, ap = 1, rap = 1, crit = 22, hit = 25, dps = 10, int = 0.2, sta = 0.2 } },
  { id = "tank", name = "Tank", style = "1H+Shield", caps = { hit = 6, def = 140 },
    w = { sta = 1.5, def = 1.5, armor = 0.05, dodge = 15, parry = 12, block = 6, blockval = 0.3, str = 0.6, agi = 0.6, hit = 10, ap = 0.2 } },
  { id = "caster", name = "Caster", style = "1H+OH", caps = { spellhit = 16 },
    w = { sp = 1, int = 0.4, spi = 0.1, sta = 0.1, spellcrit = 10, spellhit = 14, mp5 = 1 } },
  { id = "healer", name = "Healer", style = "1H+OH", caps = {},
    w = { heal = 1, sp = 1, int = 0.6, spi = 0.5, mp5 = 2.5, sta = 0.1 } },
}
local CLASS_TEMPLATES = {
  WARRIOR = { "melee_str", "tank" }, PALADIN = { "melee_str", "healer" }, HUNTER = { "ranged", "melee_agi" },
  ROGUE = { "melee_agi", "melee_agi" }, PRIEST = { "caster", "healer" }, SHAMAN = { "caster", "healer" },
  MAGE = { "caster", "caster" }, WARLOCK = { "caster", "caster" }, DRUID = { "healer", "melee_agi" },
}
R.STYLES = { "2H", "DW", "1H+Shield", "1H+OH" }
R.STYLENAME = { ["2H"] = "Two-hander", DW = "Dual wield", ["1H+Shield"] = "One-hand + shield", ["1H+OH"] = "One-hand + off-hand item" }

function R:TemplateByID(id)
  for _, t in ipairs(self.TEMPLATES) do if t.id == id then return t end end
end

function R:ApplyTemplate(set, id)
  local t = self:TemplateByID(id)
  if not t then return end
  set.weights = R.copy(t.w)
  set.caps = R.copy(t.caps)
  set.capBase = set.capBase or {}
  set.style = t.style
  set.template = t.id
  set.bis = nil
end

-- Make sure a set has weights (first use: the class starter)
function R:SetWeights(key, si)
  local c = self:Char(key)
  local set = c.sets[si]
  if not set.weights then
    local pair = CLASS_TEMPLATES[c.class or ""] or { "melee_str", "caster" }
    self:ApplyTemplate(set, pair[si] or pair[1])
  end
  set.caps = set.caps or {}
  set.capBase = set.capBase or {}
  set.pins = set.pins or {}
  if set.kings == nil then set.kings = true end
  set.primaryPct = set.primaryPct or 0
  return set
end

-- Tooltip text -> stats ---------------------------------------------------------------------------
local NUM = "(%d+%.?%d*)"
local PRIMARY_NAMES = { Strength = "str", Agility = "agi", Stamina = "sta", Intellect = "int", Spirit = "spi" }
local LINE_RULES = {
  { "chance to hit with spells by " .. NUM .. "%%", "spellhit" },
  { "critical strike with spells by " .. NUM .. "%%", "spellcrit" },
  { "chance to hit by " .. NUM .. "%%", "hit" },
  { "critical strike by " .. NUM .. "%%", "crit" },
  { "%+" .. NUM .. " ranged Attack Power", "rap" },
  { "%+" .. NUM .. " Attack Power%.?$", "ap" },
  { "magical spells and effects by up to " .. NUM, "sp" },
  { "healing done by spells and effects by up to " .. NUM, "heal" },
  { "Increased Defense %+" .. NUM, "def" },
  { "dodge an attack by " .. NUM .. "%%", "dodge" },
  { "parry an attack by " .. NUM .. "%%", "parry" },
  { "block attacks with a shield by " .. NUM .. "%%", "block" },
  { "block value of your shield by " .. NUM, "blockval" },
  { NUM .. " mana per 5 sec", "mp5" },
  { "^" .. NUM .. " Armor$", "armor" },
  { "^" .. NUM .. " Block$", "blockval" },
  { "%(" .. NUM .. " damage per second%)", "dps" },
}

function R:ParseStatLines(lines)
  local st, flags = {}, {}
  for _, line in ipairs(lines) do
    if type(line) == "table" then line = table.concat(line, " ") end
    if type(line) == "string" then
      line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      local matched = false
      local n, name = line:match("^%+" .. NUM .. " (%a+)$")
      if n and PRIMARY_NAMES[name] then
        st[PRIMARY_NAMES[name]] = (st[PRIMARY_NAMES[name]] or 0) + tonumber(n); matched = true
      end
      if not matched then
        for _, rule in ipairs(LINE_RULES) do
          local v = line:match(rule[1])
          if v then st[rule[2]] = (st[rule[2]] or 0) + tonumber(v); matched = true; break end
        end
      end
      if line:match("^Unique") then flags.unique = true end
      local rl = line:match("Requires Level (%d+)")
      if rl then flags.req = tonumber(rl) end
      local cls = line:match("^Classes: (.+)$")
      if cls then flags.classes = cls end
      if not matched and (line:match("^Use:") or line:match("^Chance on hit:") or line:match("^Equip:")) then
        flags.special = (flags.special and (flags.special .. "\n") or "") .. line
      end
    end
  end
  return st, flags
end

local scanTip
local function tooltipLines(id)
  if C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if ok and data and data.lines and #data.lines > 1 then
      local out = {}
      for _, l in ipairs(data.lines) do
        if l.leftText then out[#out + 1] = l.leftText end
        if l.rightText and l.rightText ~= "" then out[#out + 1] = l.rightText end
      end
      return out
    end
  end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "FWRScanTip", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  pcall(scanTip.SetHyperlink, scanTip, "item:" .. id)
  local n = scanTip:NumLines() or 0
  if n < 2 then return end
  local out = {}
  for i = 1, n do
    local l = _G["FWRScanTipTextLeft" .. i]
    local r = _G["FWRScanTipTextRight" .. i]
    local lt = l and l:GetText()
    local rt = r and r:IsShown() and r:GetText()
    if lt then out[#out + 1] = lt end
    if rt and rt ~= "" then out[#out + 1] = rt end
  end
  return out
end

-- Stats for an item ID (cached for the session); nil while the game is still loading it
R.statCache = {}
R.statTries = {}
local GIVE_UP = 20  -- seconds before an item that never loads stops counting as "loading"
function R:ItemStats(id)
  local hit = self.statCache[id]
  if hit then return hit ~= false and hit or nil, hit == false end
  self.statTries[id] = self.statTries[id] or time()
  local info = self:ItemInfo(id)
  local lines = info and tooltipLines(id)
  if not info or not lines then
    self.pendingItems = true
    if time() - self.statTries[id] >= GIVE_UP then self.statCache[id] = false; return nil, true end
    return nil, false
  end
  local st, flags = self:ParseStatLines(lines)
  local rec = { id = id, st = st, flags = flags, loc = info.loc, cls = info.cls, sub = info.sub, q = info.q, name = info.name }
  self.statCache[id] = rec
  return rec
end

-- What each class can use (classic proficiencies at 60) -------------------------------------------
local WEAPONS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }, ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
  PRIEST = { 4, 10, 15, 19 }, SHAMAN = { 0, 1, 4, 5, 10, 13, 15 }, MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 }, DRUID = { 4, 5, 10, 13, 15 },
}
local ARMOR = {
  WARRIOR = { 0, 1, 2, 3, 4, 6 }, PALADIN = { 0, 1, 2, 3, 4, 6, 7 }, HUNTER = { 0, 1, 2, 3 }, ROGUE = { 0, 1, 2 },
  PRIEST = { 0, 1 }, SHAMAN = { 0, 1, 2, 3, 6, 9 }, MAGE = { 0, 1 }, WARLOCK = { 0, 1 }, DRUID = { 0, 1, 2, 8 },
}
local function set(list) local t = {}; for _, v in ipairs(list or {}) do t[v] = true end; return t end
local PROF = {}
for cls in pairs(WEAPONS) do PROF[cls] = { w = set(WEAPONS[cls]), a = set(ARMOR[cls]) } end

local function canUse(rec, cls)
  local p = PROF[cls or ""]
  if not p then return true end
  if rec.cls == 2 then return p.w[rec.sub] == true end
  if rec.cls == 4 then return p.a[rec.sub] == true end
  return true
end

-- Which equip locations each slot accepts for a weapon style
local function slotLocs(slot, style)
  if slot == 16 then
    if style == "2H" then return { INVTYPE_2HWEAPON = true } end
    return { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
  elseif slot == 17 then
    if style == "2H" then return {} end
    if style == "DW" then return { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true } end
    if style == "1H+Shield" then return { INVTYPE_SHIELD = true } end
    return { INVTYPE_HOLDABLE = true }
  end
  local out = {}
  for loc, slots in pairs(R.EQUIPLOC) do
    for _, s in ipairs(slots) do if s == slot then out[loc] = true end end
  end
  return out
end

-- Item pool: journal drops and quest rewards (dungeons topping out at 50+), plus everything the
-- character owns, wears, has planned or favourited ------------------------------------------------
function R:BisPool(key)
  local ids, n = {}, 0
  local function add(id) id = tonumber(id); if id and id > 0 and not ids[id] then ids[id] = true; n = n + 1 end end
  local c = self:Char(key)
  for _, e in pairs(c.equip or {}) do add(e.id) end
  for id in pairs(c.bags or {}) do add(id) end
  for id in pairs(c.bank or {}) do add(id) end
  for _, s in ipairs(c.sets or {}) do for _, w in pairs(s.slots or {}) do add(w.id) end end
  for _, f in ipairs(c.fdjFavs or {}) do add(f.id) end
  local F = self:FDJ()
  if F then
    for _, dname in ipairs(F.ORDER or {}) do
      local d = F.DB[dname]
      local hi = type(d) == "table" and tonumber(type(d.level) == "string" and d.level:match("(%d+)%s*$")) or 0
      if hi >= 50 then
        for _, boss in ipairs(d.bosses or {}) do
          for _, item in ipairs(boss.loot or {}) do if (item[4] or 2) >= 2 then add(item[1]) end end
          if F.GetBossSharedLoot then
            local ok, shared = pcall(F.GetBossSharedLoot, dname, boss)
            for _, item in ipairs(ok and shared or {}) do add(item[1]) end
          end
        end
        for _, q in ipairs(d.quests or {}) do
          for _, item in ipairs(q.rewardItems or {}) do add(item[1]) end
        end
      end
    end
  end
  return ids, n
end

-- Scoring -------------------------------------------------------------------------------------------
local function itemScore(st, w, mult)
  local s = 0
  for k, v in pairs(st) do
    local wk = w[k]
    if wk and wk ~= 0 then s = s + v * wk * (R.PRIMARY[k] and mult or 1) end
  end
  return s
end

-- Objective for a whole set: capped amounts first (in cap order), then the weighted score where
-- capped stats only count up to their cap
local function objective(totals, set, mult)
  local o = {}
  local capped = {}
  for _, cdef in ipairs(R.CAPS) do
    local k = cdef[1]
    local cap = tonumber(set.caps[k]) or 0
    if cap > 0 then
      local have = (totals[k] or 0) + (tonumber(set.capBase[k]) or 0)
      o[#o + 1] = math.min(have, cap)
      capped[k] = math.max(0, cap - (tonumber(set.capBase[k]) or 0))
    end
  end
  local s = 0
  for k, v in pairs(totals) do
    local wk = set.weights[k]
    if wk and wk ~= 0 then
      if capped[k] then v = math.min(v, capped[k]) end
      s = s + v * wk * (R.PRIMARY[k] and mult or 1)
    end
  end
  o[#o + 1] = s
  return o
end

local function better(a, b)
  for i = 1, #a do
    local x, y = a[i], b[i] or -math.huge
    if x > y + 1e-6 then return true end
    if x < y - 1e-6 then return false end
  end
  return false
end

local BIS_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function R:ComputeBis(key, si)
  local c = self:Char(key)
  local set = self:SetWeights(key, si)
  local mult = 1 + (set.kings and 0.10 or 0) + (tonumber(set.primaryPct) or 0) / 100
  local pool, total = self:BisPool(key)
  local pending = 0
  local cands = {}
  for _, slot in ipairs(BIS_SLOTS) do cands[slot] = {} end
  local locsFor = {}
  for _, slot in ipairs(BIS_SLOTS) do locsFor[slot] = slotLocs(slot, set.style) end
  local capKeys = {}
  for _, cdef in ipairs(R.CAPS) do if (tonumber(set.caps[cdef[1]]) or 0) > 0 then capKeys[cdef[1]] = true end end

  for id in pairs(pool) do
    local rec, gaveUp = self:ItemStats(id)
    if not rec then
      if not gaveUp then pending = pending + 1 end
    elseif rec.loc and canUse(rec, c.class) and (not rec.flags.req or rec.flags.req <= self.MAXLVL) then
      local sc = itemScore(rec.st, set.weights, mult)
      local capv = 0
      for k in pairs(capKeys) do capv = capv + (rec.st[k] or 0) end
      for _, slot in ipairs(BIS_SLOTS) do
        if locsFor[slot][rec.loc] then table.insert(cands[slot], { rec = rec, score = sc, capv = capv }) end
      end
    end
  end

  -- keep the strongest candidates per slot, plus anything carrying a capped stat
  for _, slot in ipairs(BIS_SLOTS) do
    local list = cands[slot]
    table.sort(list, function(a, b) return a.score > b.score end)
    local keep = {}
    for i, cnd in ipairs(list) do
      if i <= 25 or cnd.capv > 0 then keep[#keep + 1] = cnd end
    end
    cands[slot] = keep
  end

  -- pinned slots keep their planned item
  local pick = {}
  for _, slot in ipairs(BIS_SLOTS) do
    local w = set.slots[slot]
    if set.pins[slot] and w then
      local rec = self:ItemStats(w.id)
      if rec then pick[slot] = { rec = rec, score = itemScore(rec.st, set.weights, mult), pinned = true } end
    end
  end

  local totals = {}
  local function addTo(rec, sign)
    for k, v in pairs(rec.st) do totals[k] = (totals[k] or 0) + v * sign end
  end
  local function clashes(slot, rec)
    local sib = (slot == 11 and 12) or (slot == 12 and 11) or (slot == 13 and 14) or (slot == 14 and 13)
      or (slot == 16 and 17) or (slot == 17 and 16)
    return sib and pick[sib] and pick[sib].rec.id == rec.id
  end
  -- start from the best single-item score per slot
  for _, slot in ipairs(BIS_SLOTS) do
    if not pick[slot] then
      for _, cnd in ipairs(cands[slot]) do
        if not clashes(slot, cnd.rec) then pick[slot] = cnd; break end
      end
    end
    if pick[slot] then addTo(pick[slot].rec, 1) end
  end
  -- improve one slot at a time until nothing changes
  local best = objective(totals, set, mult)
  for _ = 1, 8 do
    local changed = false
    for _, slot in ipairs(BIS_SLOTS) do
      local cur = pick[slot]
      if not (cur and cur.pinned) then
        if cur then addTo(cur.rec, -1) end
        local chosen, chosenObj = cur, nil
        if cur then addTo(cur.rec, 1); chosenObj = objective(totals, set, mult); addTo(cur.rec, -1) end
        for _, cnd in ipairs(cands[slot]) do
          if cnd ~= cur and not clashes(slot, cnd.rec) then
            addTo(cnd.rec, 1)
            local o = objective(totals, set, mult)
            addTo(cnd.rec, -1)
            if not chosenObj or better(o, chosenObj) then chosen, chosenObj = cnd, o end
          end
        end
        if chosen ~= cur then changed = true end
        pick[slot] = chosen
        if chosen then addTo(chosen.rec, 1) end
        if chosenObj then best = chosenObj end
      end
    end
    if not changed then break end
  end

  -- the set as it stands (plan, else what's worn) for comparison
  local curTotals = {}
  local current = {}
  for _, slot in ipairs(BIS_SLOTS) do
    local id = (set.slots[slot] and set.slots[slot].id) or (c.equip and c.equip[slot] and c.equip[slot].id)
    local rec = id and self:ItemStats(id)
    if rec then current[slot] = rec; for k, v in pairs(rec.st) do curTotals[k] = (curTotals[k] or 0) + v end end
  end

  -- runner-up per slot (swapped in alone)
  local alts = {}
  for _, slot in ipairs(BIS_SLOTS) do
    local cur = pick[slot]
    if cur and not cur.pinned then
      addTo(cur.rec, -1)
      local list = {}
      for _, cnd in ipairs(cands[slot]) do
        if cnd ~= cur and not clashes(slot, cnd.rec) then
          addTo(cnd.rec, 1)
          list[#list + 1] = { rec = cnd.rec, obj = objective(totals, set, mult) }
          addTo(cnd.rec, -1)
        end
      end
      addTo(cur.rec, 1)
      table.sort(list, function(a, b) return better(a.obj, b.obj) end)
      alts[slot] = { list[1], list[2] }
    end
  end

  local function capReport(t)
    local out = {}
    for _, cdef in ipairs(R.CAPS) do
      local k = cdef[1]
      local cap = tonumber(set.caps[k]) or 0
      if cap > 0 then
        out[#out + 1] = { key = k, label = cdef[2], have = (t[k] or 0) + (tonumber(set.capBase[k]) or 0), cap = cap }
      end
    end
    return out
  end
  local bestObj = objective(totals, set, mult)
  local curObj = objective(curTotals, set, mult)
  local res = {
    pick = pick, alts = alts, current = current, pool = total, pending = pending,
    caps = capReport(totals), curCaps = capReport(curTotals),
    score = bestObj[#bestObj], curScore = curObj[#curObj], at = time(),
  }
  set.bisAt = res.at
  self.bisResult = self.bisResult or {}
  self.bisResult[key .. "#" .. si] = res
  return res
end

function R:BisResult(key, si, force)
  self.bisResult = self.bisResult or {}
  local r = self.bisResult[key .. "#" .. si]
  if force or not r or r.dirty then r = self:ComputeBis(key, si) end
  return r
end

function R:BisDirty()
  for _, r in pairs(self.bisResult or {}) do r.dirty = true end
end

-- Recalculate once items finish loading (debounced)
R:On("GET_ITEM_INFO_RECEIVED", function(self)
  if self.tab ~= "Gear" or self.sideMode ~= "Best" then return end
  local r = self.bisResult and self.bisResult[(self.view or "") .. "#" .. self:SetIndex(self.view)]
  if not r or r.pending == 0 or self.bisTimer then return end
  self.bisTimer = true
  local function go() self.bisTimer = nil; self:BisDirty(); self:Refresh() end
  if C_Timer and C_Timer.After then C_Timer.After(1, go) else go() end
end)

-- Put the picks into the plan
function R:UseBis(key, si, slot)
  local r = self:BisResult(key, si)
  local set = self:Char(key).sets[si]
  local slots = slot and { slot } or BIS_SLOTS
  for _, s in ipairs(slots) do
    local p = r.pick[s]
    if p and not p.pinned then set.slots[s] = { id = p.rec.id, src = set.slots[s] and set.slots[s].id == p.rec.id and set.slots[s].src or nil } end
  end
  self:BisDirty()
end
R.BIS_SLOTS = BIS_SLOTS
