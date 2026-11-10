-- Forever Warband Raiders: tab contents (each tab returns a list of ops for UI.lua to draw)
local R = FWR
local C = R.COL

R.TABS = {
  { name = "Ready", w = 56 }, { name = "Gear", w = 50 }, { name = "Lockouts", w = 68 },
  { name = "Prep", w = 50 }, { name = "Settings", w = 66 },
}

local function cname(key)
  local c = R.db.chars[key]
  return (c and c.name) or key
end

local function ago(t)
  if not t then return "never" end
  local s = time() - t
  if s < 120 then return "just now" end
  return R:Dur(s) .. " ago"
end

local function scoreCol(ok, known)
  if known == 0 then return C.grey end
  if ok == known then return C.ok end
  if ok / known >= 0.6 then return C.warn end
  return C.bad
end

-- Ready ----------------------------------------------------------------------------------------
local function readyOps(key)
  local ops = {}
  local r = R:Readiness(key)
  local items = {
    { t = "bar", v = r.ok, max = math.max(1, r.known), col = scoreCol(r.ok, r.known),
      text = string.format("%d of %d checks done", r.ok, r.known) },
    { t = "gap", h = 4 },
  }
  for _, ck in ipairs(r.list) do
    local row = { t = "row", icon = R.ICON[ck.state], l = ck.label, r = ck.text, rc = C[ck.state], tip = ck.tip }
    if ck.check then
      local id = ck.check
      row.click = function() R:ToggleTick(key, id) end
    end
    items[#items + 1] = row
  end
  ops[#ops + 1] = { t = "card", title = "Raid readiness", right = cname(key), items = items }

  local wb = {}
  for _, k in ipairs(R:Raiders()) do
    local o = R.db.chars[k]
    local rr = R:Readiness(k)
    wb[#wb + 1] = { t = "row", l = (k == key and "|cffffd100> |r" or "") .. cname(k) .. " |cff9d9d9d" .. (o.level or 0) .. "|r",
      r = string.format("%d/%d ready · %s", rr.ok, rr.known, R:Money(o.gold)), rc = scoreCol(rr.ok, rr.known),
      click = function() R.view = k end, tip = "Updated " .. ago(o.updated) .. ". Click to view." }
  end
  ops[#ops + 1] = { t = "card", title = "Warband", right = "level " .. R.MAXLVL .. " characters", items = wb }

  local w, exact = R:WeeklyReset()
  local d = R:DailyReset()
  ops[#ops + 1] = { t = "card", title = "Resets", items = {
    { t = "row", l = "Weekly (raids)", r = w and (R:Dur(w) .. (exact and "" or " (from lockouts)")) or "Unknown" },
    { t = "row", l = "Daily", r = d and R:Dur(d) or "Unknown" },
  } }
  return ops
end

-- Gear -----------------------------------------------------------------------------------------
local WHERE = {
  equipped = { "ok", "Equipped" }, bags = { "warn", "In bags" }, bank = { "warn", "In bank" },
}

local function gearOps(key)
  local ops = {}
  local c = R:Char(key)
  local si = R:SetIndex(key)
  ops[#ops + 1] = { t = "btns", list = {
    { (si == 1 and "> " or "") .. c.sets[1].name, function() c.setIdx = 1 end, w = 150 },
    { (si == 2 and "> " or "") .. c.sets[2].name, function() c.setIdx = 2 end, w = 150 },
  } }
  local set = c.sets[si]
  local have, total = R:SetProgress(key, si)
  local items = {
    { t = "input", btn = "Add", fn = function(v) return R:AddWanted(key, v, si) end,
      tip = "Shift-click an item into this box, then type where it drops (optional) and press Enter." },
  }
  if total > 0 then
    items[#items + 1] = { t = "bar", v = have, max = total, col = have == total and C.ok or C.warn,
      text = string.format("%d of %d target items owned", have, total) }
  end
  local hidden = 0
  for _, s in ipairs(R.SLOTS) do
    local slot, sname = s[1], s[2]
    local w = set.slots[slot]
    if w then
      local where = R:Where(key, w.id)
      local st = where and WHERE[where] or { "unknown", "Wanted" }
      items[#items + 1] = { t = "row", icon = R.ICON[st[1]], l = "|cff9d9d9d" .. sname .. ":|r " .. R:ItemName(w.id),
        r = (where == "bags" or where == "bank") and st[2] or (w.src or R:JournalSource(w.id) or st[2]),
        rc = where and C[st[1]] or C.grey, rw = 190,
        click = R:FDJ() and function() R:OpenInJournal(w.id) end or nil,
        tip = function(tt)
          if GameTooltip.SetItemByID then tt:SetItemByID(w.id) else tt:SetHyperlink("item:" .. w.id) end
          tt:AddLine(" ")
          tt:AddLine("Status: " .. st[2], 1, 0.82, 0)
          local js = R:JournalSource(w.id)
          if w.src then tt:AddLine("Source: " .. w.src, 0.9, 0.9, 0.9) end
          if js then tt:AddLine("Dungeon Journal: " .. js, 0.85, 0.66, 0.24) end
          if R:FDJ() then tt:AddLine("Click to open in Dungeon Journal", 0.6, 0.6, 0.6) end
        end,
        btns = { { "x", function() R:RemoveWanted(key, si, slot) end, tip = "Remove from plan" } } }
    else
      hidden = hidden + 1
    end
  end
  if hidden > 0 then
    items[#items + 1] = { t = "note", text = hidden .. " slots not planned yet." }
  end
  ops[#ops + 1] = { t = "card", title = set.name, right = total > 0 and (have .. "/" .. total .. " owned") or "No items yet", items = items }

  if R:FDJ() then
    for _, op in ipairs(R:JournalGearOps(key, si)) do ops[#ops + 1] = op end
  end

  ops[#ops + 1] = { t = "card", title = "Share a plan", items = {
    { t = "note", text = "Export copies both gear sets and the prep list into the box. Paste a friend's string in and press Enter to import it onto this character." },
    { t = "input", value = R.exportStr, clear = true, btn = "Import",
      fn = function(v) R.exportStr = nil; return R:Import(key, v) end },
    { t = "btns", list = { { "Export", function() R.exportStr = R:Export(key) end, w = 90 } } },
  } }
  return ops
end

-- Lockouts -------------------------------------------------------------------------------------
local function lockoutOps(key)
  local ops = {}
  local now = time()
  local w, exact = R:WeeklyReset()
  ops[#ops + 1] = { t = "card", title = "Weekly reset", right = w and R:Dur(w) or "Unknown", rc = C.gold, items = {
    { t = "note", text = exact and "Raid lockouts clear at the weekly reset." or "Reset time taken from your saved lockouts." },
  } }
  if R:FDJ() then
    local runs = R:RecentRuns(key, 7)
    local items = {}
    local F = R:FDJ()
    if key == R.key and F.RunLogIsCapped then
      local ok, capped = pcall(F.RunLogIsCapped)
      if ok and capped then items[#items + 1] = { t = "row", icon = R.ICON.bad, l = "Instance cap reached", lc = C.bad, r = "wait before the next run" } end
    end
    local total = 0
    for _, r in ipairs(runs) do
      total = total + r.n
      items[#items + 1] = { t = "row", l = r.dungeon, r = r.n .. (r.n == 1 and " run" or " runs") .. " · " .. r.bosses .. " bosses · last " .. ago(r.last) }
    end
    if #runs == 0 then items[#items + 1] = { t = "row", l = "No dungeon runs in the last 7 days", lc = C.grey } end
    ops[#ops + 1] = { t = "card", title = "Dungeon runs: " .. cname(key), right = total > 0 and (total .. " this week") or "from Dungeon Journal", items = items }
  end

  for _, k in ipairs(R:Raiders()) do
    local o = R:Char(k)
    local items = {}
    for _, s in ipairs(o.saved or {}) do
      if s.resetAt and s.resetAt > now then
        local prog = (s.bosses and s.bosses > 0) and string.format("%d/%d bosses", s.killed or 0, s.bosses) or "Saved"
        items[#items + 1] = { t = "row", icon = R.ICON[(s.killed and s.bosses and s.killed >= s.bosses) and "ok" or "warn"],
          l = s.name .. (s.size and (" |cff9d9d9d(" .. s.size .. ")|r") or ""),
          r = prog .. " · resets in " .. R:Dur(s.resetAt - now) }
      end
    end
    if #items == 0 then items[1] = { t = "row", l = "No active lockouts", lc = C.ok } end
    ops[#ops + 1] = { t = "card", title = cname(k), right = k == R.key and "live" or ("as of " .. ago(o.savedSeen)), items = items }
  end
  return ops
end

-- Prep -----------------------------------------------------------------------------------------
local function prepOps(key)
  local ops = {}
  local ps = R:PrepStatus(key)
  local items = {
    { t = "input", btn = "Add", fn = function(v) return R:AddPrep(key, v) end,
      tip = "Shift-click a consumable into this box, type how many you use per raid night, then press Enter." },
  }
  if ps.total > 0 then
    items[#items + 1] = { t = "bar", v = ps.total - ps.missing, max = ps.total, col = ps.missing == 0 and C.ok or C.warn,
      text = string.format("%d of %d in bags or bank", ps.total - ps.missing, ps.total) }
  end
  for _, r in ipairs(ps.rows) do
    local state = r.short == 0 and "ok" or (r.short <= r.fromAlts + r.craft and "warn" or "bad")
    local who = r.crafter and cname(r.crafter) or "Crafter"
    items[#items + 1] = { t = "row", icon = R.ICON[state], l = R:ItemName(r.id) .. " |cff9d9d9dx" .. r.need .. "|r",
      r = r.have .. "/" .. r.need, rc = C[state], rw = 60,
      tip = function(tt)
        tt:SetText(R:ItemName(r.id))
        tt:AddDoubleLine("In bags / bank", r.bags .. " / " .. r.bank, 1, 1, 1, 1, 1, 1)
        for _, a in ipairs(r.alts) do tt:AddDoubleLine("On " .. cname(a.key), a.n, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8) end
        if r.craft > 0 then tt:AddLine(cname(r.crafter) .. " crafts " .. r.craft, 0.45, 0.7, 1) end
        if r.buy > 0 then tt:AddLine("Buy " .. r.buy .. (r.price and (" (about " .. R:Money(r.price * r.buy) .. ")") or ""), 1, 0.7, 0.2) end
      end,
      btns = { { who, function() R:CycleCrafter(key, r.i) end, w = 90, tip = "Click to choose which character crafts this." },
        { "x", function() R:RemovePrep(key, r.i) end, tip = "Remove" } } }
  end
  ops[#ops + 1] = { t = "card", title = "Raid night prep", right = "for " .. ps.nights .. (ps.nights == 1 and " night" or " nights"), items = items }

  -- to-do list
  local todo = {}
  local mail, craft, buy = {}, {}, {}
  for _, r in ipairs(ps.rows) do
    local left = r.fromAlts
    for _, a in ipairs(r.alts) do
      if left <= 0 then break end
      local n = math.min(left, a.n)
      mail[#mail + 1] = { t = "row", icon = R.ICON.warn, l = "Mail " .. n .. " " .. R:ItemName(r.id), r = "from " .. cname(a.key) }
      left = left - n
    end
    if r.craft > 0 then
      craft[#craft + 1] = { t = "row", icon = R.ICON.warn, l = "Craft " .. r.craft .. " " .. R:ItemName(r.id), r = cname(r.crafter), rc = C.blue }
    end
    if r.buy > 0 then
      buy[#buy + 1] = { t = "row", icon = R.ICON.bad, l = "Buy " .. r.buy .. " " .. R:ItemName(r.id),
        r = r.price and R:Money(r.price * r.buy) or "Auction House" }
    end
  end
  for _, l in ipairs({ mail, craft, buy }) do for _, x in ipairs(l) do todo[#todo + 1] = x end end
  if #todo == 0 then
    todo[1] = { t = "row", icon = R.ICON.ok, l = ps.total > 0 and "Nothing to do. You're stocked." or "Add consumables above to build your list.", lc = ps.total > 0 and C.ok or C.grey }
  end
  local right = ps.buyCost > 0 and ("buying ~" .. R:Money(ps.buyCost)) or nil
  ops[#ops + 1] = { t = "card", title = "To do before raid night", right = right, items = todo }
  return ops
end

-- Settings -------------------------------------------------------------------------------------
local ENCH = { 1, 3, 15, 5, 9, 10, 7, 8, 16, 17 }

local function settingsOps(key)
  local set = R.db.set
  local c = R:Char(key)
  local ops = {}
  local function num(field, lo, hi)
    return function(v)
      local n = tonumber(v)
      if not n or n < lo or n > hi then return false, "Enter a number from " .. lo .. " to " .. hi .. "." end
      set[field] = math.floor(n)
    end
  end
  ops[#ops + 1] = { t = "card", title = "Targets", items = {
    { t = "input", label = "Gold on hand (g)", value = tostring(set.goldBudget), clear = false, fn = num("goldBudget", 0, 100000) },
    { t = "input", label = "Lowest durability %", value = tostring(set.minDurability), clear = false, fn = num("minDurability", 0, 100) },
    { t = "input", label = "Raid nights to stock", value = tostring(set.nights), clear = false, fn = num("nights", 1, 7) },
    { t = "row", icon = set.rangedRequired and R.ICON.ok or R.ICON.bad, l = "Ranged slot must be filled",
      click = function() set.rangedRequired = not set.rangedRequired end, tip = "Click to switch" },
  } }

  local ench = { { t = "note", text = "Slots that should have an enchant. A shield in the off hand counts when Off hand is on." } }
  for _, slot in ipairs(ENCH) do
    local on = set.enchSlots[slot] and true or false
    ench[#ench + 1] = { t = "row", icon = on and R.ICON.ok or R.ICON.bad, l = R.SLOTNAME[slot],
      r = on and "Enchant expected" or "Ignored", click = function() set.enchSlots[slot] = not on or nil end }
  end
  ops[#ops + 1] = { t = "card", title = "Enchants", items = ench }

  local checks = {
    { t = "note", text = "Your own steps for every raider, such as an attunement quest or a resistance set. Tick them on the Ready tab." },
    { t = "input", btn = "Add", fn = function(v) R:AddCheck(v) end },
  }
  for i, ck in ipairs(set.checks) do
    checks[#checks + 1] = { t = "row", l = ck.text, btns = { { "x", function() R:RemoveCheck(i) end, tip = "Remove" } } }
  end
  ops[#ops + 1] = { t = "card", title = "Custom checks", items = checks }

  ops[#ops + 1] = { t = "card", title = "Gear set names", right = cname(key), items = {
    { t = "input", label = "Set 1", value = c.sets[1].name, clear = false, fn = function(v) if v ~= "" then c.sets[1].name = v end end },
    { t = "input", label = "Set 2", value = c.sets[2].name, clear = false, fn = function(v) if v ~= "" then c.sets[2].name = v end end },
  } }

  local chars = { { t = "note", text = "Every character you've logged in on. Remove one you've deleted." } }
  for _, k in ipairs(R:Raiders(true)) do
    local o = R.db.chars[k]
    chars[#chars + 1] = { t = "row", l = cname(k) .. " |cff9d9d9d" .. (o.level or 0) .. "|r", r = "seen " .. ago(o.updated),
      btns = k ~= R.key and { { "x", function() R.db.chars[k] = nil; if R.view == k then R.view = R.key end end, tip = "Forget this character" } } or nil }
  end
  ops[#ops + 1] = { t = "card", title = "Characters", items = chars }
  return ops
end

local BUILD = { Ready = readyOps, Gear = gearOps, Lockouts = lockoutOps, Prep = prepOps, Settings = settingsOps }

function R:BuildOps(tab, key)
  return (BUILD[tab] or readyOps)(key or self.view or self.key)
end

-- Gear tab: Dungeon Journal favourites and drop finder ---------------------------------------------
local QHEX = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }

function R:JournalGearOps(key, si)
  local ops = {}
  local c = self:Char(key)
  local set = c.sets[si]
  local inPlan = {}
  for _, w in pairs(set.slots) do inPlan[w.id] = true end

  -- favourites
  local favItems = {}
  for _, f in ipairs(c.fdjFavs or {}) do
    if not inPlan[f.id] then
      local slots = R.parseSlot(f.slot)
      local fi = R:ItemInfo(f.id)
      favItems[#favItems + 1] = { t = "row", l = (fi and fi.link) or ("|cff" .. (QHEX[f.q] or "ffffff") .. "[" .. (f.name or f.id) .. "]|r"),
        r = f.quest and ("Quest · " .. (f.dungeon or "?")) or ((f.boss or "?") .. " · " .. (f.dungeon or "?")), rw = 200,
        tip = function(tt) if tt.SetItemByID then tt:SetItemByID(f.id) else tt:SetHyperlink("item:" .. f.id) end end,
        btns = slots and { { "Add", function() local ok, m = R:AddWanted(key, tostring(f.id), si, nil); if not ok then R:Print(m) end end, w = 44, tip = "Add to " .. set.name } } or nil }
    end
  end
  if #favItems > 0 or (c.fdjFavs and #c.fdjFavs > 0) then
    if #favItems == 0 then favItems[1] = { t = "row", l = "All your favourites are in this plan.", lc = C.ok } end
    ops[#ops + 1] = { t = "card", title = "Journal favourites", right = (key == R.key) and "live" or ("as of " .. (c.fdjSeen and R:Dur(time() - c.fdjSeen) .. " ago" or "?")), items = favItems }
  end

  -- drop finder
  R.findSlot = R.findSlot or 1
  local slotIdx = 1
  for i, s in ipairs(R.SLOTS) do if s[1] == R.findSlot then slotIdx = i end end
  local function stepSlot(d)
    slotIdx = ((slotIdx - 1 + d) % #R.SLOTS) + 1
    R.findSlot = R.SLOTS[slotIdx][1]
  end
  local armor = R.CLASS_ARMOR[c.class or ""]
  local items = {
    { t = "btns", list = {
      { "<", function() stepSlot(-1) end, w = 24 },
      { R.SLOTNAME[R.findSlot], function() end, w = 110 },
      { ">", function() stepSlot(1) end, w = 24 },
      { R.allArmor and "All armour" or ((armor and (armor:sub(1, 1):upper() .. armor:sub(2))) or "All") .. " only",
        function() R.allArmor = not R.allArmor end, w = 110, tip = "Switch between your armour type and every type" },
    } },
  }
  local list = R:Suggestions(key, R.findSlot, R.allArmor)
  local planned = set.slots[R.findSlot]
  for i, s in ipairs(list) do
    if i > 30 then
      items[#items + 1] = { t = "note", text = (#list - 30) .. " more not shown." }
      break
    end
    local info = s.id and R:ItemInfo(s.id)
    local name = (info and info.link) or ("|cff" .. (QHEX[s.q] or "ffffff") .. "[" .. s.name .. "]|r")
    local mark = (planned and s.id and planned.id == s.id) and "|cffffd100> |r" or ""
    items[#items + 1] = { t = "row", l = mark .. name .. (s.stats ~= "" and (" |cff9d9d9d" .. s.stats .. "|r") or ""),
      r = s.boss .. " · " .. s.dungeon, rw = 200,
      tip = function(tt)
        if s.id then
          if tt.SetItemByID then tt:SetItemByID(s.id) else tt:SetHyperlink("item:" .. s.id) end
        else
          tt:SetText(s.name, 1, 1, 1)
          for _, line in ipairs(s.tip or {}) do
            if type(line) == "table" then tt:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
            else tt:AddLine(line, 1, 1, 1, true) end
          end
          tt:AddLine("Item ID not known yet: loot or link it once to add it.", 1, 0.5, 0.5, true)
        end
        tt:AddLine(s.boss .. " · " .. s.dungeon .. " (" .. (s.level or "?") .. ")", 0.85, 0.66, 0.24)
      end,
      click = s.id and function() R:OpenInJournal(s.id) end or nil,
      btns = s.id and { { "Add", function() local ok, m = R:AddWanted(key, tostring(s.id), si, R.findSlot); if not ok then R:Print(m) end end, w = 44, tip = "Add to " .. set.name } } or nil }
  end
  if #list == 0 then items[#items + 1] = { t = "row", l = "No level 58–60 dungeon drops listed for this slot yet.", lc = C.grey } end
  ops[#ops + 1] = { t = "card", title = "Dungeon drops", right = #list .. " from level 58–60 dungeons", items = items }
  return ops
end
