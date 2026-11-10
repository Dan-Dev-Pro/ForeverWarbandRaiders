-- Forever Warband Raiders: gear plans, raid night prep and custom checks
local R = FWR

-- gear plan ----------------------------------------------------------------------------------
function R:SetIndex(key)
  local c = self:Char(key)
  c.setIdx = c.setIdx or 1
  return c.setIdx
end

-- "[Item Link] Blackmaw Hold, boss 3"  ->  item ID, source text
local function parseLinkText(text)
  text = text or ""
  local link = text:match("|H(item:[^|]+)|h") or text:match("(item:[%d:%-]+)")
  local id = link and R:ItemID(link) or tonumber(text:match("^%s*(%d+)"))
  if not id then return end
  local rest
  if link then
    rest = text:gsub("|c%x+|H.-|h.-|h|r", ""):gsub("|H.-|h.-|h", ""):gsub("item:[%d:%-]+", "")
  else
    rest = text:gsub("^%s*%d+", "")
  end
  rest = rest:gsub("^[%s,%-:]+", ""):gsub("%s+$", "")
  return id, rest
end
R.parseLinkText = parseLinkText

function R:AddWanted(key, text, setIdx, forceSlot)
  local id, src = parseLinkText(text)
  if not id then return false, "Shift-click an item into the box first." end
  local c = self:Char(key)
  local set = c.sets[setIdx or self:SetIndex(key)]
  local slot = forceSlot
  if not slot then
    local info = self:ItemInfo(id)
    if not info then return false, "Item not loaded yet, try again in a moment." end
    local slots = self.EQUIPLOC[info.loc or ""]
    if not slots then return false, "That item can't be equipped." end
    slot = slots[1]
    for _, s in ipairs(slots) do
      if not set.slots[s] or set.slots[s].id == id then slot = s; break end
    end
    if #slots > 1 and set.slots[slot] and set.slots[slot].id ~= id then slot = slots[2] end
  end
  if R.BisDirty then R:BisDirty() end
  set.slots[slot] = { id = id, src = (src ~= "" and src) or (set.slots[slot] and set.slots[slot].id == id and set.slots[slot].src) or nil }
  return true, self:ItemName(id)
end

-- An item dragged onto a slot: check it fits there
function R:DropOnSlot(key, setIdx, slot, id)
  local info = self:ItemInfo(id)
  if not info then return false, "Item not loaded yet, try again." end
  local fits = false
  for _, s in ipairs(self.EQUIPLOC[info.loc or ""] or {}) do if s == slot then fits = true end end
  if not fits then return false, info.link .. " doesn't go in the " .. (self.SLOTNAME[slot] or "?") .. " slot." end
  return self:AddWanted(key, tostring(id), setIdx, slot)
end

function R:RemoveWanted(key, setIdx, slot)
  local c = self:Char(key)
  if self.BisDirty then self:BisDirty() end
  c.sets[setIdx].slots[slot] = nil
end

-- Where is this item for this character? "equipped", "bags", "bank" or nil
function R:Where(key, id)
  local c = self:Char(key)
  for _, e in pairs(c.equip or {}) do if e.id == id then return "equipped" end end
  if (c.bags or {})[id] then return "bags" end
  if (c.bank or {})[id] then return "bank" end
end

function R:SetProgress(key, setIdx)
  local c = self:Char(key)
  local set = c.sets[setIdx]
  local total, have = 0, 0
  for slot, w in pairs(set.slots) do
    total = total + 1
    if self:Where(key, w.id) then have = have + 1 end
  end
  return have, total
end

-- raid night prep ----------------------------------------------------------------------------
-- "[Item Link] 5"  ->  adds or updates a consumable with 5 per raid night
function R:AddPrep(key, text)
  local id, rest = parseLinkText(text)
  if not id then return false, "Shift-click a consumable into the box first." end
  local qty = tonumber((rest or ""):match("(%d+)")) or 1
  local c = self:Char(key)
  for _, p in ipairs(c.prep) do
    if p.id == id then p.qty = qty; return true, self:ItemName(id) .. " x" .. qty end
  end
  c.prep[#c.prep + 1] = { id = id, qty = qty }
  return true, self:ItemName(id) .. " x" .. qty
end

function R:RemovePrep(key, i)
  table.remove(self:Char(key).prep, i)
end

-- Cycle who crafts this item: nobody -> each warband character -> nobody
function R:CycleCrafter(key, i)
  local p = self:Char(key).prep[i]
  local list = self:Raiders(true)
  local idx = 0
  for n, k in ipairs(list) do if k == p.crafter then idx = n end end
  p.crafter = list[idx + 1]
end

function R:Count(key, id)
  local c = self:Char(key)
  return ((c.bags or {})[id] or 0), ((c.bank or {})[id] or 0)
end

function R:Price(id)
  local A = rawget(_G, "Auctionator")
  if A and A.API and A.API.v1 and A.API.v1.GetAuctionPriceByItemID then
    local ok, p = pcall(A.API.v1.GetAuctionPriceByItemID, R.NAME, id)
    if ok and p then return p end
  end
end

-- One line per consumable: need, have, spare on alts, to craft, to buy
function R:PrepStatus(key)
  local c = self:Char(key)
  local nights = self.db.set.nights or 1
  local rows, buyCost, missing, total = {}, 0, 0, 0
  for i, p in ipairs(c.prep) do
    local need = p.qty * nights
    local bags, bank = self:Count(key, p.id)
    local have = bags + bank
    local short = math.max(0, need - have)
    local alts = {}
    local altTotal = 0
    for k, o in pairs(self.db.chars) do
      if k ~= key then
        local n = ((o.bags or {})[p.id] or 0) + ((o.bank or {})[p.id] or 0)
        if n > 0 then alts[#alts + 1] = { key = k, n = n }; altTotal = altTotal + n end
      end
    end
    table.sort(alts, function(a, b) return a.n > b.n end)
    local fromAlts = math.min(short, altTotal)
    local remain = short - fromAlts
    local craft = p.crafter and remain or 0
    local buy = remain - craft
    local price = self:Price(p.id)
    if price and buy > 0 then buyCost = buyCost + price * buy end
    total = total + need
    missing = missing + math.min(need, short)
    rows[#rows + 1] = { i = i, id = p.id, need = need, bags = bags, bank = bank, have = have, short = short,
      alts = alts, fromAlts = fromAlts, crafter = p.crafter, craft = craft, buy = buy, price = price }
  end
  return { rows = rows, buyCost = buyCost, missing = missing, total = total, nights = nights }
end

-- custom checks (account-wide list, ticked per character) -------------------------------------
function R:AddCheck(text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return end
  local set = self.db.set
  set.nextCheck = (set.nextCheck or 0) + 1
  table.insert(set.checks, { id = set.nextCheck, text = text })
end

function R:RemoveCheck(i)
  table.remove(self.db.set.checks, i)
end

function R:ToggleTick(key, id)
  local c = self:Char(key)
  c.ticks[id] = not c.ticks[id] or nil
end

-- sharing: plain-text plan strings a friend can paste in -------------------------------------
local function esc(s) return (s or ""):gsub("[|;~]", " ") end

function R:Export(key)
  local c = self:Char(key)
  local parts = { "FWR1" }
  for si = 1, 2 do
    local set = c.sets[si]
    local items = {}
    for slot, w in pairs(set.slots) do items[#items + 1] = slot .. "~" .. w.id .. "~" .. esc(w.src) end
    table.sort(items)
    parts[#parts + 1] = "S" .. si .. "~" .. esc(set.name) .. ";" .. table.concat(items, ";")
  end
  local prep = {}
  for _, p in ipairs(c.prep) do prep[#prep + 1] = p.id .. "~" .. p.qty end
  parts[#parts + 1] = "P;" .. table.concat(prep, ";")
  return table.concat(parts, "|")
end

function R:Import(key, str)
  str = (str or ""):gsub("%s+$", ""):gsub("^%s+", "")
  if str:sub(1, 5) ~= "FWR1|" then return false, "That isn't a Forever Warband Raiders plan." end
  local c = self:Char(key)
  local nItems, nPrep = 0, 0
  for part in str:sub(6):gmatch("[^|]+") do
    local head, body = part:match("^([^;]*);?(.*)$")
    local si, name = head:match("^S(%d)~(.*)$")
    if si then
      local set = { name = name ~= "" and name or c.sets[tonumber(si)].name, slots = {} }
      for item in body:gmatch("[^;]+") do
        local slot, id, src = item:match("^(%d+)~(%d+)~?(.*)$")
        if slot then
          set.slots[tonumber(slot)] = { id = tonumber(id), src = src ~= "" and src or nil }
          nItems = nItems + 1
        end
      end
      c.sets[tonumber(si)] = set
    elseif head == "P" then
      c.prep = {}
      for item in body:gmatch("[^;]+") do
        local id, qty = item:match("^(%d+)~(%d+)$")
        if id then c.prep[#c.prep + 1] = { id = tonumber(id), qty = tonumber(qty) }; nPrep = nPrep + 1 end
      end
    end
  end
  return true, string.format("Imported %d gear items and %d consumables.", nItems, nPrep)
end
