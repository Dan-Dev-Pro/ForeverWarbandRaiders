FIRE("ADDON_LOADED","ForeverWarbandRaiders"); FIRE("PLAYER_LOGIN")
local R=FWR
-- alt 1: Kowayel
NAME="Kowayel"; CLS="PRIEST"; LVL=60; MONEY=455000; EQUIP={[1]="item:106:0"}; BAGS={[0]={{201,6},{204,20}}}
SAVED={{"Onyxia's Lair",3*86400,40,1,1}}
R.key=R:Key(); R:ScanAll()
-- alt 2 low level
NAME="Dakarth"; CLS="MAGE"; LVL=42; MONEY=90000; EQUIP={}; BAGS={[0]={{202,15}}}; SAVED={}
R.key=R:Key(); R:ScanAll()
-- back to Quail
NAME="Quail"; CLS="WARRIOR"; LVL=60; MONEY=1234567
EQUIP={[1]="item:106:0",[5]="item:108:1891",[16]="item:107:1900",[13]="item:104:0",[15]="item:999:0",[10]="item:998:0"}
BAGS={[0]={{103,1},{202,8},{301,1}},[1]={{204,10}}}
SAVED={{"Barrow Deeps",2*86400+3600*5,10,8,5},{"Hyjal Summit",2*86400+3600*5,20,13,4}}
R.key=R:Key(); R.view=R.key; R:ScanAll()
local L=function(id) return "|cffa335ee|Hitem:"..id.."::::|h[x]|h|r" end
print(R:AddWanted(R.key, L(101).." Hyjal Summit, Archimonde"))
print(R:AddWanted(R.key, L(102).." Onyxia's Lair"))
print(R:AddWanted(R.key, L(103).." Blackmaw Hold, last boss"))
print(R:AddWanted(R.key, L(104).." Shaper's Terrace"))
print(R:AddWanted(R.key, L(105).." Barrow Deeps"))
print(R:AddWanted(R.key, L(107).." Blacksmithing"))
print(R:AddWanted(R.key, L(108).." PvP rank 8"))
for s,w in pairs(R:Char().sets[1].slots) do print("slot",s,w.id,w.src) end
print(R:AddPrep(R.key, L(201).." 4"))
print(R:AddPrep(R.key, L(202).." 10"))
print(R:AddPrep(R.key, L(203).." 6"))
print(R:AddPrep(R.key, L(204).." 5"))
R:CycleCrafter(R.key,1); R:CycleCrafter(R.key,1); R:CycleCrafter(R.key,1)
print("crafter", R:Char().prep[1].crafter)
R:AddCheck("Onyxia attunement (if needed)"); R:AddCheck("Fire resistance set")
R:ToggleTick(R.key, 2)
local r=R:Readiness(R.key); print("ready",r.ok,r.known)
for _,c in ipairs(r.list) do print(" ",c.state,c.label,c.text,c.tip) end
local ex=R:Export(R.key); print(ex)
NAME="Kowayel"; R.key=R:Key()
print(R:Import(R.key, ex)); print(R:Export(R.key)==ex)
NAME="Quail"; R.key=R:Key()
SlashCmdList.FWR(""); SlashCmdList.FWR("ready"); SlashCmdList.FWR("reset"); SlashCmdList.FWR("bogus")
for _,t in ipairs(R.TABS) do R.tab=t.name; R:Refresh(); print("rendered",t.name) end
-- click every hit/button
