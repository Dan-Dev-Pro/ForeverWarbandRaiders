-- Forever Warband Raiders: reads the logged-in character and saves it for the whole warband
local R = FWR

local function containerSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function containerItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if i then return i.itemID, i.stackCount or 1 end
    return
  end
  if GetContainerItemInfo then
    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    local id = (GetContainerItemID and GetContainerItemID(bag, slot)) or R:ItemID(link)
    if id then return id, count or 1 end
  end
end

local function scanBags(list)
  local out = {}
  for _, bag in ipairs(list) do
    for slot = 1, containerSlots(bag) do
      local id, n = containerItem(bag, slot)
      if id then out[id] = (out[id] or 0) + n end
    end
  end
  return out
end

function R:ScanBasics()
  local c = self:Char()
  c.name = UnitName("player")
  local _, cls = UnitClass("player")
  c.class = cls
  c.level = UnitLevel("player")
  c.gold = GetMoney()
  c.updated = time()
end

function R:ScanEquip()
  local c = self:Char()
  c.equip = {}
  local worst
  for _, s in ipairs(self.SLOTS) do
    local slot = s[1]
    local link = GetInventoryItemLink("player", slot)
    if link then
      local id, ench = link:match("item:(%d+):(%d*)")
      local e = { id = tonumber(id), ench = (ench and ench ~= "" and ench ~= "0") and tonumber(ench) or nil }
      local info = self:ItemInfo(e.id)
      if info then e.loc = info.loc end
      local cur, max = GetInventoryItemDurability(slot)
      if cur and max and max > 0 then
        e.dur = math.floor(cur / max * 100)
        if not worst or e.dur < worst then worst = e.dur end
      end
      c.equip[slot] = e
    end
  end
  c.durability = worst
end

function R:ScanBags()
  local c = self:Char()
  c.bags = scanBags({ 0, 1, 2, 3, 4 })
  c.mount = self:HasMount(c.bags)
end

function R:ScanBank()
  local c = self:Char()
  local list = { -1 }
  local first = (NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = b end
  c.bank = scanBags(list)
  c.bankSeen = time()
end

-- Mount: the mount journal if Forever has one, otherwise a mount item in the bags
function R:HasMount(bags)
  if C_MountJournal and C_MountJournal.GetMountIDs then
    for _, mid in ipairs(C_MountJournal.GetMountIDs() or {}) do
      local _, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(mid)
      if collected then return true end
    end
  end
  for id in pairs(bags or {}) do
    local i = self:ItemInfo(id)
    if i and i.cls == 15 and i.sub == 5 then return true end
  end
  return false
end

function R:ScanSaved()
  if not GetNumSavedInstances then return end
  local c = self:Char()
  c.saved = {}
  local now = time()
  for i = 1, GetNumSavedInstances() do
    local name, _, reset, _, locked, extended, _, isRaid, maxPlayers, diffName, numEnc, encProg = GetSavedInstanceInfo(i)
    if name and (locked or extended) and reset and reset > 0 then
      c.saved[#c.saved + 1] = {
        name = name, raid = isRaid and true or false, size = maxPlayers, diff = diffName,
        resetAt = now + reset, bosses = numEnc, killed = encProg,
      }
    end
  end
  c.savedSeen = now
end

function R:ScanAll()
  self:ScanBasics()
  self:ScanEquip()
  self:ScanBags()
  self:ScanSaved()
  if self.Refresh then self:Refresh() end
end

R:On("PLAYER_MONEY", function(self) self:ScanBasics(); self:Refresh() end)
R:On("PLAYER_LEVEL_UP", function(self) self:ScanBasics(); self:Refresh() end)
R:On("PLAYER_EQUIPMENT_CHANGED", function(self) self:ScanEquip(); self:Refresh() end)
R:On("UPDATE_INVENTORY_DURABILITY", function(self) self:ScanEquip(); self:Refresh() end)
R:On("BAG_UPDATE_DELAYED", function(self) self:ScanBags(); if self.bankOpen then self:ScanBank() end; self:Refresh() end)
R:On("BANKFRAME_OPENED", function(self) self.bankOpen = true; self:ScanBank(); self:Refresh() end)
R:On("BANKFRAME_CLOSED", function(self) self.bankOpen = false end)
R:On("PLAYERBANKSLOTS_CHANGED", function(self) if self.bankOpen then self:ScanBank(); self:Refresh() end end)
R:On("UPDATE_INSTANCE_INFO", function(self) self:ScanSaved(); self:Refresh() end)
R:On("BOSS_KILL", function(self) if RequestRaidInfo then RequestRaidInfo() end end)
