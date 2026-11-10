-- Forever Warband Raiders: window and a small layout renderer
-- Tabs describe their content as a list of ops (cards, rows, bars, inputs); this file draws them.
local R = FWR

local W, H, PAD, ROW = 820, 600, 14, 18
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.62, 0.62 }
R.COL = {
  ok = { 0.35, 0.85, 0.35 }, warn = { 1, 0.7, 0.2 }, bad = { 0.95, 0.3, 0.3 }, unknown = GREY,
  gold = GOLD, grey = GREY, white = { 0.92, 0.92, 0.92 }, blue = { 0.45, 0.7, 1 },
}
R.ICON = { ok = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t", warn = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t",
  bad = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t", unknown = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t" }

local BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function backdrop(f, a, edge)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(0.04, 0.04, 0.05, a or 0.95)
  local e = edge or { 0.55, 0.45, 0.2 }
  f:SetBackdropBorderColor(e[1], e[2], e[3], 1)
end

local function tip(owner, text)
  if not text then return end
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if type(text) == "function" then text(GameTooltip) else GameTooltip:SetText(text, 1, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- pools ----------------------------------------------------------------------------------------
local pools = {}
local function get(kind, make)
  local p = pools[kind]
  if not p then p = { all = {}, used = 0 }; pools[kind] = p end
  p.used = p.used + 1
  local o = p.all[p.used]
  if not o then o = make(); p.all[p.used] = o end
  o:ClearAllPoints()
  o:Show()
  return o
end
local function resetPools()
  for _, p in pairs(pools) do
    for i = 1, #p.all do p.all[i]:Hide() end
    p.used = 0
  end
end

-- window ---------------------------------------------------------------------------------------
-- A standard Blizzard window (portrait, title, inset, tabs along the bottom). Falls back to a plain
-- framed panel if the client lacks the templates.
function R:BuildFrame()
  if self.frame then return self.frame end
  local f
  for _, template in ipairs({ "ButtonFrameTemplate", "PortraitFrameTemplate", "BasicFrameTemplateWithInset" }) do
    local ok, made = pcall(CreateFrame, "Frame", "FWRFrame", UIParent, template)
    if ok and made then f = made; f.fwrTemplate = template; break end
  end
  if not f then
    f = CreateFrame("Frame", "FWRFrame", UIParent, "BackdropTemplate")
    backdrop(f, 0.97)
  end
  self.frame = f
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "FWRFrame")
  f:Hide()

  -- title
  local title = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
  if not title then
    title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -6)
  end
  f.title = title
  title:SetText(self.NAME)

  -- close button: the template's own, otherwise a stock one; plain Hide so it works in combat
  local close = f.CloseButton or (f.TitleContainer and f.TitleContainer.CloseButton)
  if not close then
    close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
  end
  close:SetScript("OnClick", function() f:Hide() end)

  -- portrait: the character being viewed
  f.portrait = f.portrait or (f.PortraitContainer and f.PortraitContainer.portrait)
  if f.Inset then
    f.Inset:ClearAllPoints()
    f.Inset:SetPoint("TOPLEFT", 4, -60)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 26)
  end

  -- character picker, under the title like the default character window
  local prev = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  prev:SetSize(24, 20); prev:SetText("<"); prev:SetPoint("TOPLEFT", 70, -32)
  local who = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  who:SetPoint("LEFT", prev, "RIGHT", 6, 0); who:SetWidth(260); who:SetJustifyH("CENTER")
  local next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  next:SetSize(24, 20); next:SetText(">"); next:SetPoint("LEFT", who, "RIGHT", 6, 0)
  f.who = who
  local function step(d)
    local list = self:Raiders()
    local idx = 1
    for i, k in ipairs(list) do if k == self.view then idx = i end end
    idx = ((idx - 1 + d) % #list) + 1
    self.view = list[idx]
    self:Refresh()
  end
  prev:SetScript("OnClick", function() step(-1) end)
  next:SetScript("OnClick", function() step(1) end)

  -- tabs along the bottom (Blizzard tab buttons when available)
  f.tabs = {}
  f.Tabs = {}
  local prevTab
  for i, t in ipairs(self.TABS) do
    local ok, b = pcall(CreateFrame, "Button", "FWRFrameTab" .. i, f, "PanelTabButtonTemplate")
    if not ok or not b then
      ok, b = pcall(CreateFrame, "Button", "FWRFrameTab" .. i, f, "CharacterFrameTabButtonTemplate")
    end
    if not ok or not b then
      b = CreateFrame("Button", "FWRFrameTab" .. i, f, "UIPanelButtonTemplate")
      b:SetSize(80, 22)
    end
    b:SetID(i)
    b:SetText(t.name)
    if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 3, 0) else b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2) end
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
    b:SetScript("OnClick", function()
      self.tab = t.name
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      self:Refresh()
    end)
    f.tabs[t.name] = b
    f.Tabs[i] = b
    prevTab = b
  end
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, f, #self.TABS) end

  -- scrolling content inside the inset
  local sf = CreateFrame("ScrollFrame", "FWRScroll", f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 12, -68)
  sf:SetPoint("BOTTOMRIGHT", -30, 32)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(W - 12 - 30 - 4, 10)
  sf:SetScrollChild(child)
  f.child = child
  f.cw = W - 12 - 30 - 4
  return f
end

function R:Toggle()
  local f = self:BuildFrame()
  if f:IsShown() then f:Hide() else
    self.view = self.view or self.key
    if self.ScanAll then self:ScanAll() end
    f:Show(); self:Refresh()
  end
end

-- renderer -------------------------------------------------------------------------------------
local function fs(parent, font)
  local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  s:SetJustifyH("LEFT"); s:SetWordWrap(true)
  return s
end

function R:Render(ops)
  local f = self.frame
  local child = f.child
  resetPools()
  local y = 0

  local function text(x, yy, w, str, col, font, justify)
    local s = get("fs" .. (font or ""), function() return fs(child, font) end)
    s:SetPoint("TOPLEFT", child, "TOPLEFT", x, -yy)
    s:SetWidth(w)
    s:SetJustifyH(justify or "LEFT")
    s:SetText(str or "")
    local c = col or R.COL.white
    s:SetTextColor(c[1], c[2], c[3])
    return s
  end

  local function button(x, yy, w, label, fn, tipText)
    local b = get("btn", function() return CreateFrame("Button", nil, child, "UIPanelButtonTemplate") end)
    b:SetSize(w, ROW)
    b:SetPoint("TOPLEFT", child, "TOPLEFT", x, -yy)
    b:SetText(label)
    b:SetScript("OnClick", function() fn(); R:Refresh() end)
    b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
    tip(b, tipText)
    return b
  end

  local function draw(op, x, w)
    local t = op.t
    if t == "gap" then
      y = y + (op.h or 8)
    elseif t == "note" then
      local s = text(x, y, w, op.text, op.col or R.COL.grey)
      y = y + math.max(ROW - 4, s:GetStringHeight() or ROW) + 4
    elseif t == "row" then
      local bw = 0
      if op.btns then
        for i = #op.btns, 1, -1 do
          local b = op.btns[i]
          local bwid = b.w or 24
          button(x + w - bw - bwid, y, bwid, b[1], b[2], b.tip)
          bw = bw + bwid + 2
        end
      end
      local ix = x + (op.indent or 0)
      if op.icon then text(ix, y + 2, 18, op.icon); ix = ix + 18 end
      local rw = op.rw or 190
      text(ix, y + 3, w - (ix - x) - rw - bw - 4, op.l, op.lc)
      if op.r then text(x + w - bw - rw - 4, y + 3, rw, op.r, op.rc or R.COL.grey, nil, "RIGHT") end
      if op.click or op.tip then
        local hit = get("hit", function()
          local h = CreateFrame("Button", nil, child)
          local hl = h:CreateTexture(nil, "HIGHLIGHT")
          hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.08)
          return h
        end)
        hit:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        hit:SetSize(w - bw, ROW)
        hit:SetScript("OnClick", op.click and function() op.click(); R:Refresh() end or nil)
        hit:SetScript("OnEnter", nil); hit:SetScript("OnLeave", nil)
        tip(hit, op.tip)
      end
      y = y + ROW + 2
    elseif t == "bar" then
      local b = get("bar", function()
        local s = CreateFrame("StatusBar", nil, child)
        s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local bg = s:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        s.txt = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); s.txt:SetPoint("CENTER")
        return s
      end)
      b:SetPoint("TOPLEFT", child, "TOPLEFT", x, -(y + 2))
      b:SetSize(w, 14)
      b:SetMinMaxValues(0, math.max(1, op.max or 1)); b:SetValue(op.v or 0)
      local c = op.col or R.COL.ok
      b:SetStatusBarColor(c[1], c[2], c[3])
      b.txt:SetText(op.text or "")
      y = y + 20
    elseif t == "input" then
      if op.label then text(x, y + 3, 150, op.label, R.COL.gold) end
      local lx = op.label and 150 or 0
      local eb = get("eb", function()
        local e = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
        e:SetAutoFocus(false); e:SetHeight(ROW)
        e:SetScript("OnEscapePressed", e.ClearFocus)
        e:SetScript("OnEditFocusGained", function(self) R.focusBox = self end)
        e:SetScript("OnEditFocusLost", function(self) if R.focusBox == self then R.focusBox = nil end end)
        return e
      end)
      local bwid = op.btn and 56 or 0
      eb:SetPoint("TOPLEFT", child, "TOPLEFT", x + lx + 6, -y)
      eb:SetWidth(w - lx - bwid - 12)
      eb:SetText(op.value or "")
      eb:SetCursorPosition(0)
      local function submit()
        local v = eb:GetText()
        local ok, msg = op.fn(v)
        if msg then R:Print(msg) end
        if ok ~= false and op.clear ~= false then eb:SetText("") end
        eb:ClearFocus()
        R:Refresh()
      end
      eb:SetScript("OnEnterPressed", submit)
      eb:SetScript("OnEnter", nil); eb:SetScript("OnLeave", nil)
      tip(eb, op.tip)
      if op.btn then button(x + w - bwid, y, bwid, op.btn, submit) end
      y = y + ROW + 6
    elseif t == "btns" then
      local bx = x
      for _, b in ipairs(op.list) do
        local bwid = b.w or 110
        button(bx, y, bwid, b[1], b[2], b.tip)
        bx = bx + bwid + 4
      end
      y = y + ROW + 6
    elseif t == "cols" then
      local top = y
      local gap = 12
      local lw = math.floor((w - gap) * (op.split or 0.5))
      for _, sub in ipairs(op.left or {}) do draw(sub, x, lw) end
      local ly = y
      y = top
      for _, sub in ipairs(op.right or {}) do draw(sub, x + lw + gap, w - lw - gap) end
      y = math.max(y, ly)
    elseif t == "head" then
      y = y + 2
      local s = text(x, y, w - (op.r and 150 or 0), op.text, R.COL.gold, "GameFontNormalSmall")
      if op.r then text(x + w - 150, y, 150, op.r, R.COL.grey, nil, "RIGHT") end
      local line = get("line", function() local l = child:CreateTexture(nil, "ARTWORK"); l:SetColorTexture(1, 0.82, 0, 0.25); return l end)
      line:SetPoint("TOPLEFT", child, "TOPLEFT", x, -(y + 14)); line:SetSize(w, 1)
      y = y + 19
    elseif t == "itemrow" then
      local H2 = 32
      local ib = get("ibtn", function()
        local b = CreateFrame("Button", nil, child)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(28, 28); b.icon:SetPoint("LEFT", 0, 0)
        b.ring = b:CreateTexture(nil, "OVERLAY"); b.ring:SetTexture("Interface\\Common\\WhiteIconFrame"); b.ring:SetAllPoints(b.icon)
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.07)
        return b
      end)
      local bw = 0
      for i = #(op.btns or {}), 1, -1 do
        local bt = op.btns[i]
        local bwid = bt.w or 24
        button(x + w - bw - bwid, y + 7, bwid, bt[1], bt[2], bt.tip)
        bw = bw + bwid + 2
      end
      ib:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
      ib:SetSize(w - bw - 2, H2)
      ib.icon:SetTexture(op.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      ib.icon:SetDesaturated(op.dim and true or false)
      local q = op.qcol or { 0.6, 0.6, 0.6 }
      ib.ring:SetVertexColor(q[1], q[2], q[3])
      ib:SetScript("OnClick", op.click and function(_, button) op.click(button); R:Refresh() end or nil)
      ib:SetScript("OnEnter", nil); ib:SetScript("OnLeave", nil)
      tip(ib, op.tip)
      text(x + 34, y + 2, w - 34 - bw - 4, op.name, op.nc, "GameFontNormalSmall")
      text(x + 34, y + 17, w - 34 - bw - 4, op.sub, R.COL.grey)
      y = y + H2 + 2
    elseif t == "paperdoll" then
      local S, G = 38, 5
      local top = y + 2
      local function place(slot, bx, by)
        local b = get("slot", function()
          local s = CreateFrame("Button", nil, child)
          s:SetSize(S, S)
          s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
          s:RegisterForDrag("LeftButton")
          s.icon = s:CreateTexture(nil, "BORDER"); s.icon:SetAllPoints()
          -- the classic slot frame around the icon
          s.frame = s:CreateTexture(nil, "ARTWORK")
          s.frame:SetTexture("Interface\\Buttons\\UI-Quickslot2")
          s.frame:SetSize(S * 64 / 37, S * 64 / 37); s.frame:SetPoint("CENTER", 0, -1)
          -- status ring (green equipped, amber in bags or bank, grey wanted)
          s.edge = s:CreateTexture(nil, "OVERLAY")
          s.edge:SetTexture("Interface\\Common\\WhiteIconFrame"); s.edge:SetAllPoints()
          s.sel = s:CreateTexture(nil, "OVERLAY", nil, 2)
          s.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight"); s.sel:SetBlendMode("ADD"); s.sel:SetAllPoints()
          s:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
          return s
        end)
        b:SetPoint("TOPLEFT", child, "TOPLEFT", bx, -by)
        local d = op.slots[slot]
        if type(slot) == "string" or not d then
          -- shirt and tabard: shown for the familiar layout only
          b.icon:SetTexture(R:EmptySlotTexture(slot)); b.icon:SetDesaturated(true); b.icon:SetAlpha(0.35)
          b.edge:Hide(); b.sel:Hide()
          b:SetScript("OnClick", nil); b:SetScript("OnReceiveDrag", nil)
          b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
          return
        end
        b.icon:SetDesaturated(false)
        if d.empty then
          b.icon:SetTexture(R:EmptySlotTexture(slot)); b.icon:SetAlpha(0.8)
        else
          b.icon:SetTexture(R:ItemIcon(d.id)); b.icon:SetAlpha(1)
        end
        if d.empty then b.edge:Hide() else
          local col = R.COL[d.state] or R.COL.grey
          b.edge:SetVertexColor(col[1], col[2], col[3]); b.edge:Show()
        end
        if op.sel == slot then b.sel:Show() else b.sel:Hide() end
        local function dropped()
          local kind, id = GetCursorInfo()
          if kind == "item" and id then op.drop(slot, id); ClearCursor(); R:Refresh(); return true end
        end
        b:SetScript("OnClick", function(_, button)
          if dropped() then return end
          op.click(slot, button); R:Refresh()
        end)
        b:SetScript("OnReceiveDrag", dropped)
        b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
        tip(b, d.tip)
      end
      local LEFT = { 1, 2, 3, 15, 5, "shirt", "tabard", 9 }
      local RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }
      for i, slot in ipairs(LEFT) do place(slot, x, top + (i - 1) * (S + G)) end
      for i, slot in ipairs(RIGHT) do place(slot, x + w - S, top + (i - 1) * (S + G)) end
      local by = top + 8 * (S + G) + 6
      local bx = x + (w - (3 * S + 2 * G)) / 2
      for i, slot in ipairs({ 16, 17, 18 }) do place(slot, bx + (i - 1) * (S + G), by) end
      -- centre panel: the picked slot
      local cy = top + 4
      local cx, cw = x + S + 16, w - 2 * S - 32
      for _, line in ipairs(op.center or {}) do
        local s = text(cx, cy, cw, line[1], line[2], line[3], "CENTER")
        cy = cy + math.max(14, s:GetStringHeight() or 14) + 3
      end
      -- the logged-in character, dressed in the planned set
      if op.tryOn and CreateFrame then
        local m = get("model", function()
          local ok, f = pcall(CreateFrame, "DressUpModel", nil, child)
          if not ok or not f then ok, f = pcall(CreateFrame, "PlayerModel", nil, child) end
          return ok and f or CreateFrame("Frame", nil, child)
        end)
        local mh = by - cy - 8
        if mh > 80 then
          m:SetPoint("TOPLEFT", child, "TOPLEFT", cx, -(cy + 4))
          m:SetSize(cw, mh)
          local sig = table.concat(op.tryOn, ",")
          if m.SetUnit and m.fwrSig ~= sig then
            m.fwrSig = sig
            pcall(m.SetUnit, m, "player")
            if m.Undress then pcall(m.Undress, m) end
            if m.TryOn then for _, id in ipairs(op.tryOn) do pcall(m.TryOn, m, "item:" .. id) end end
          end
        else
          m:Hide()
        end
      end
      y = by + S + 8
    elseif t == "card" then
      local top = y
      local card = get("card", function()
        local ok, c = pcall(CreateFrame, "Frame", nil, child, "InsetFrameTemplate")
        if not ok or not c then
          c = CreateFrame("Frame", nil, child, "BackdropTemplate")
          backdrop(c, 0.6, { 0.3, 0.26, 0.15 })
        end
        c:SetFrameLevel(child:GetFrameLevel())
        return c
      end)
      y = y + 8
      if op.title then
        text(x + 10, y, w - 20 - 200, op.title, R.COL.gold, "GameFontNormal")
        if op.right then text(x + w - 210, y + 1, 200, op.right, op.rc or R.COL.grey, nil, "RIGHT") end
        y = y + 20
      end
      for _, sub in ipairs(op.items or {}) do draw(sub, x + 10, w - 20) end
      y = y + 6
      card:SetPoint("TOPLEFT", child, "TOPLEFT", x, -top)
      card:SetSize(w, y - top)
      y = y + 8
    end
  end

  for _, op in ipairs(ops) do draw(op, 0, f.cw) end
  f.child:SetHeight(math.max(10, y))
end

function R:Refresh()
  local f = self.frame
  if not f or not f:IsShown() then return end
  self.tab = self.tab or self.TABS[1].name
  for i, t in ipairs(self.TABS) do
    if t.name == self.tab then
      if PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, f, i) else f.tabs[t.name]:LockHighlight() end
    elseif not PanelTemplates_SetTab then
      f.tabs[t.name]:UnlockHighlight()
    end
  end
  if f.portrait then
    if self.view == self.key and SetPortraitTexture then
      pcall(SetPortraitTexture, f.portrait, "player")
    else
      local cls = (self:Char(self.view).class or "")
      f.portrait:SetTexture("Interface\\Icons\\ClassIcon_" .. cls:sub(1, 1) .. cls:sub(2):lower())
    end
  end
  local c = self:Char(self.view)
  local role = self:JourneyRole(self.view)
  f.who:SetText(string.format("%s |cff9d9d9d%d %s%s|r", c.name or self.view, c.level or 0,
    c.class and (c.class:sub(1, 1) .. c.class:sub(2):lower()) or "", role and (" · " .. role) or ""))
  self:Render(self:BuildOps(self.tab, self.view))
end

-- Shift-clicking an item while one of our boxes has focus puts the link in that box
if ChatEdit_InsertLink then
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    local box = R.focusBox
    if box and box:HasFocus() and link then box:Insert(link) end
  end)
end
