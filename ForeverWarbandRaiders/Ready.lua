-- Forever Warband Raiders: raid readiness checklist
local R = FWR

-- state: "ok", "warn", "bad" or "unknown"
local function add(list, id, label, state, text, tip)
  list[#list + 1] = { id = id, label = label, state = state, text = text, tip = tip }
end

function R:Readiness(key)
  local c = self:Char(key)
  local set = self.db.set
  local list = {}

  -- level
  local lvl = c.level or 0
  add(list, "level", "Level " .. self.MAXLVL, lvl >= self.MAXLVL and "ok" or "bad",
    lvl >= self.MAXLVL and "Done" or ("Level " .. lvl))

  -- empty slots
  local empty = {}
  local mh = c.equip and c.equip[16]
  local twoHand = mh and mh.loc == "INVTYPE_2HWEAPON"
  for _, s in ipairs(self.SLOTS) do
    local slot = s[1]
    local skip = (slot == 17 and twoHand) or (slot == 18 and not set.rangedRequired)
    if not skip and not (c.equip or {})[slot] then empty[#empty + 1] = s[2] end
  end
  add(list, "slots", "Gear slots", #empty == 0 and "ok" or "bad",
    #empty == 0 and "All filled" or (#empty .. " empty"), #empty > 0 and table.concat(empty, ", ") or nil)

  -- durability
  if c.durability then
    add(list, "dur", "Repairs", c.durability >= set.minDurability and "ok" or "warn",
      "Lowest item " .. c.durability .. "%")
  else
    add(list, "dur", "Repairs", "unknown", "Log in on this character")
  end

  -- enchants
  local missing = {}
  for _, s in ipairs(self.SLOTS) do
    local slot = s[1]
    local wantEnch = set.enchSlots[slot]
    local e = (c.equip or {})[slot]
    if slot == 17 and e and e.loc == "INVTYPE_SHIELD" and set.enchSlots[17] ~= false then wantEnch = true end
    if wantEnch and e and not e.ench then missing[#missing + 1] = s[2] end
  end
  add(list, "ench", "Enchants", #missing == 0 and "ok" or "warn",
    #missing == 0 and "All done" or (#missing .. " missing"), #missing > 0 and table.concat(missing, ", ") or nil)

  -- gear plan
  local si = self:SetIndex(key)
  local have, total = self:SetProgress(key, si)
  if total == 0 then
    add(list, "plan", "Gear plan", "unknown", "No plan yet", "Add target items on the Gear tab.")
  else
    add(list, "plan", "Gear plan", have == total and "ok" or "warn",
      string.format("%d of %d items (%s)", have, total, c.sets[si].name))
  end

  -- consumables
  local ps = self:PrepStatus(key)
  if ps.total == 0 then
    add(list, "prep", "Consumables", "unknown", "No list yet", "Add consumables on the Prep tab.")
  else
    local short = 0
    for _, r in ipairs(ps.rows) do if r.short > 0 then short = short + 1 end end
    add(list, "prep", "Consumables", short == 0 and "ok" or "warn",
      short == 0 and ("Stocked for " .. ps.nights .. (ps.nights == 1 and " night" or " nights"))
        or (short .. " of " .. #ps.rows .. " short"))
  end

  -- gold
  local g = math.floor((c.gold or 0) / 10000)
  add(list, "gold", "Gold", g >= set.goldBudget and "ok" or "warn",
    self:Money(c.gold) .. " (target " .. set.goldBudget .. "g)")

  -- mount
  if c.mount == nil then
    add(list, "mount", "Mount", "unknown", "Not checked yet")
  else
    add(list, "mount", "Mount", c.mount and "ok" or "warn", c.mount and "Yes" or "None found")
  end

  -- custom checks
  for _, ck in ipairs(set.checks) do
    local done = c.ticks[ck.id]
    add(list, "ck" .. ck.id, ck.text, done and "ok" or "bad", done and "Done" or "To do", "Click to tick", ck.id)
    list[#list].check = ck.id
  end

  local ok, known = 0, 0
  for _, x in ipairs(list) do
    if x.state ~= "unknown" then known = known + 1 end
    if x.state == "ok" then ok = ok + 1 end
  end
  return { list = list, ok = ok, known = known }
end
