local R=FWR
-- synthetic items: id = {name, loc, class, sub, lines}
local S={}
local function it(id,name,loc,cls,sub,lines) ITEMS[id]={name,loc,cls,sub}; S[id]=lines end
it(5001,"Hit Helm","INVTYPE_HEAD",4,4,{"+10 Strength","Equip: Improves your chance to hit by 2%."})
it(5002,"Str Helm","INVTYPE_HEAD",4,4,{"+30 Strength","+10 Stamina"})
it(5003,"AP Helm","INVTYPE_HEAD",4,4,{"Equip: +64 Attack Power."})            -- 64 AP vs 30 str*2*1.1=66 -> str wins
it(5004,"Cloth Hat","INVTYPE_HEAD",4,1,{"+40 Intellect"})
it(5005,"Hit Gloves","INVTYPE_HAND",4,3,{"+8 Agility","Equip: Improves your chance to hit by 1%."})
it(5006,"Big Gloves","INVTYPE_HAND",4,4,{"+25 Strength"})
it(5007,"Hit Ring","INVTYPE_FINGER",4,0,{"Unique","Equip: Improves your chance to hit by 1%."})
it(5008,"Str Ring","INVTYPE_FINGER",4,0,{"+15 Strength"})
it(5009,"Str Ring 2","INVTYPE_FINGER",4,0,{"+12 Strength"})
it(5010,"HoJ","INVTYPE_TRINKET",4,0,{"Equip: Improves your chance to get a critical strike by 1%.","Chance on hit: extra attack"})
it(5011,"Hit Trinket","INVTYPE_TRINKET",4,0,{"Equip: Improves your chance to hit by 2%."})
it(5012,"Greatsword","INVTYPE_2HWEAPON",2,8,{"(60.5 damage per second)","+20 Strength"})
it(5013,"Big Staff","INVTYPE_2HWEAPON",2,10,{"(55.0 damage per second)","+25 Strength"})
it(5014,"Wand","INVTYPE_RANGED",2,19,{"(40 damage per second)"})
it(5015,"Hit Legs","INVTYPE_LEGS",4,4,{"+15 Strength","Equip: Improves your chance to hit by 2%."})
it(5016,"Str Legs","INVTYPE_LEGS",4,4,{"+35 Strength"})
it(5017,"Hit Cloak","INVTYPE_CLOAK",4,1,{"Equip: Improves your chance to hit by 1%."})
it(5018,"Agi Cloak","INVTYPE_CLOAK",4,1,{"+12 Agility"})
C_TooltipInfo={GetItemByID=function(id) local l=S[id]; if not l then return nil end local out={{leftText=ITEMS[id][1]}}; for _,x in ipairs(l) do out[#out+1]={leftText=x} end return {lines=out} end}
BAGS={[0]={},[1]={}}
for id in pairs(S) do table.insert(BAGS[0],{id,1}) end
R:ScanBags()
R.statCache={}
local set=R:SetWeights(R.key,1)
print("template",set.template,set.style,set.caps.hit)
local r=R:ComputeBis(R.key,1)
for _,cp in ipairs(r.caps) do print("cap",cp.key,cp.have,cp.cap) end
for _,s in ipairs(R.BIS_SLOTS) do local p=r.pick[s]; if p then print(R.SLOTNAME[s], p.rec.name, math.floor(p.score)) end end
print("score",math.floor(r.score),"cur",math.floor(r.curScore),"pending",r.pending,"pool",r.pool)
-- without cap: hit weight only
set.caps.hit=0; r=R:ComputeBis(R.key,1)
print("nocap head",r.pick[1].rec.name,"legs",r.pick[7].rec.name,"ring",r.pick[11].rec.name,r.pick[12].rec.name)
set.caps.hit=9; set.pins[1]=true; set.slots[1]={id=5003}; r=R:ComputeBis(R.key,1)
print("pinned head", r.pick[1].rec.name, r.pick[1].pinned, "hit", r.caps[1].have)
R:UseBis(R.key,1); print("plan legs", set.slots[7].id, "head", set.slots[1].id)
R.tab="Gear"; for _,m in ipairs({"Best","Weights"}) do R.sideMode=m; R:Refresh()
  local errs=0
  for i=1,#ALL do local o=ALL[i] if o._shown then for _,e in ipairs({"_OnEnter","_OnClick","_OnEnterPressed"}) do local f=rawget(o,e); if f then local ok,err=pcall(f,o,"LeftButton"); if not ok then errs=errs+1; print("ERR",m,err) end end end end end
  print(m,"errs",errs) end
