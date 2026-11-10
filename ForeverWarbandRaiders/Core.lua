-- Forever Warband Raiders: core (saved data, characters, helpers, events, slash commands)
FWR = FWR or {}
local R = FWR
R.NAME = "Forever Warband Raiders"
R.VERSION = "0.2.0"
R.MAXLVL = 60

-- Gear slots that matter for raiding (shirt and tabard left out)
R.SLOTS = {
  {1, "Head"}, {2, "Neck"}, {3, "Shoulder"}, {15, "Back"}, {5, "Chest"}, {9, "Wrist"},
  {10, "Hands"}, {6, "Waist"}, {7, "Legs"}, {8, "Feet"}, {11, "Ring 1"}, {12, "Ring 2"},
  {13, "Trinket 1"}, {14, "Trinket 2"}, {16, "Main hand"}, {17, "Off hand"}, {18, "Ranged"},
}
R.SLOTNAME = {}
for _, s in ipairs(R.SLOTS) do R.SLOTNAME[s[1]] = s[2] end

-- Equip location -> possible slots
R.EQUIPLOC = {
  INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
  INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10},
  INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_CLOAK = {15},
  INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
  INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
  INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}

-- Default settings (each player can change these in the Settings tab)
R.DEFAULTS = {
  enchSlots = { [5] = true, [15] = true, [9] = true, [10] = true, [8] = true, [16] = true },
  minDurability = 80,
  goldBudget = 100,       -- gold to have on hand before a raid night
  nights = 1,             -- raid nights the prep list should cover
  rangedRequired = false,
  checks = {},            -- custom account-wide checks, e.g. an attunement step: { {id=, text=} }
}

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end
R.copy = copy

function R:InitDB()
  FWRDB = FWRDB or {}
  local db = FWRDB
  db.v = 1
  db.chars = db.chars or {}
  db.set = db.set or {}
  for k, v in pairs(self.DEFAULTS) do
    if db.set[k] == nil then db.set[k] = copy(v) end
  end
  self.db = db
end

function R:Key()
  local name = UnitName("player")
  local realm = (GetRealmName and GetRealmName()) or ""
  return name .. (realm ~= "" and ("-" .. realm) or "")
end

function R:Char(key)
  key = key or self.key
  local c = self.db.chars[key]
  if not c then
    c = { equip = {}, bags = {}, bank = {}, saved = {}, sets = {}, prep = {}, ticks = {} }
    self.db.chars[key] = c
  end
  c.sets = c.sets or {}
  c.prep = c.prep or {}
  c.ticks = c.ticks or {}
  if not c.sets[1] then c.sets[1] = { name = "Main spec", slots = {} } end
  if not c.sets[2] then c.sets[2] = { name = "Off spec", slots = {} } end
  return c
end

-- Characters at the level cap, sorted: logged-in first, then by name
function R:Raiders(all)
  local out = {}
  for k, c in pairs(self.db.chars) do
    if all or (c.level or 0) >= self.MAXLVL or k == self.key then out[#out + 1] = k end
  end
  table.sort(out, function(a, b)
    if a == self.key then return true elseif b == self.key then return false end
    return a < b
  end)
  return out
end

-- Role from Forever Warband Journey, when installed
function R:JourneyRole(key)
  local j = rawget(_G, "FWJDB")
  local c = j and type(j.chars) == "table" and j.chars[key]
  if type(c) == "table" and type(c.role) == "string" then return c.role end
end

-- helpers ------------------------------------------------------------------------------------
function R:Money(copper)
  copper = copper or 0
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  if g > 0 then return string.format("%dg %02ds", g, s) end
  return string.format("%ds", s)
end

function R:Dur(sec)
  if not sec or sec < 0 then return "?" end
  local d = math.floor(sec / 86400); sec = sec % 86400
  local h = math.floor(sec / 3600); local m = math.floor((sec % 3600) / 60)
  if d > 0 then return string.format("%dd %dh", d, h) end
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

function R:ItemID(link)
  if type(link) == "number" then return link end
  if type(link) ~= "string" then return end
  local id = link:match("item:(%d+)")
  return id and tonumber(id)
end

function R:ItemInfo(id)
  local GI = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not GI or not id then return end
  local name, link, quality, _, _, _, _, _, equipLoc, icon, _, classID, subclassID = GI(id)
  if not name then
    self.pendingItems = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return
  end
  return { name = name, link = link, q = quality, loc = equipLoc, icon = icon, cls = classID, sub = subclassID }
end

function R:ItemName(id)
  local i = self:ItemInfo(id)
  return i and i.link or ("item " .. tostring(id))
end

function R:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017FWR|r " .. tostring(msg))
end

-- reset timers -------------------------------------------------------------------------------
function R:WeeklyReset()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    local s = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if s and s > 0 then return s, true end
  end
  -- Fallback: earliest known raid lockout reset across the warband
  local now, best = time(), nil
  for _, c in pairs(self.db.chars) do
    for _, s in pairs(c.saved or {}) do
      if s.raid and s.resetAt and s.resetAt > now and (not best or s.resetAt < best) then best = s.resetAt end
    end
  end
  return best and (best - now) or nil, false
end

function R:DailyReset()
  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    local s = C_DateAndTime.GetSecondsUntilDailyReset()
    if s and s > 0 then return s end
  end
  if GetQuestResetTime then
    local s = GetQuestResetTime()
    if s and s > 0 then return s end
  end
end

-- events -------------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
R.ev = ev
local handlers = {}
function R:On(event, fn)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
  ev:RegisterEvent(event)
end
ev:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    local ok, err = pcall(fn, R, ...)
    if not ok and R.db and R.db.debug then R:Print("error in " .. event .. ": " .. tostring(err)) end
  end
end)

R:On("ADDON_LOADED", function(self, name)
  if name ~= "ForeverWarbandRaiders" then return end
  self:InitDB()
  self.key = self:Key()
  self.view = self.key
  self:Char()
end)

R:On("PLAYER_LOGIN", function(self)
  if not self.db then self:InitDB(); self.key = self:Key(); self.view = self.key end
  self:ScanAll()
  if RequestRaidInfo then RequestRaidInfo() end
end)

R:On("GET_ITEM_INFO_RECEIVED", function(self)
  if self.pendingItems then
    self.pendingItems = false
    if self.Refresh then self:Refresh() end
  end
end)

-- slash commands -----------------------------------------------------------------------------
SLASH_FWR1 = "/fwr"
SLASH_FWR2 = "/raiders"
SlashCmdList.FWR = function(msg)
  msg = msg or ""
  local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    R:Toggle()
  elseif cmd == "want" then
    local ok, why = R:AddWanted(R.key, rest)
    R:Print(ok and ("Added " .. why .. " to your gear plan.") or why)
    R:Refresh()
  elseif cmd == "prep" then
    local ok, why = R:AddPrep(R.key, rest)
    R:Print(ok and ("Raid prep: " .. why) or why)
    R:Refresh()
  elseif cmd == "reset" then
    local w, exact = R:WeeklyReset()
    R:Print("Weekly reset in " .. (w and R:Dur(w) or "unknown") .. (exact and "" or " (from your lockouts)")
      .. ", daily in " .. (R:DailyReset() and R:Dur(R:DailyReset()) or "unknown") .. ".")
  elseif cmd == "ready" then
    local r = R:Readiness(R.key)
    R:Print(string.format("Raid ready: %d of %d checks done.", r.ok, r.known))
    for _, c in ipairs(r.list) do
      if c.state ~= "ok" then R:Print("  " .. c.label .. ": " .. c.text) end
    end
  elseif cmd == "debug" then
    R.db.debug = not R.db.debug
    R:Print("debug " .. (R.db.debug and "on" or "off"))
  else
    R:Print("/fwr open · /fwr ready · /fwr want [item] source · /fwr prep [item] qty · /fwr reset")
  end
end
