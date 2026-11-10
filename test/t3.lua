local R=FWR
local F=R:FDJ(); print("FDJ", F and #F.ORDER)
for _,slot in ipairs({1,5,13,16,17,18,15}) do
  local l=R:Suggestions(R.key, slot, false)
  print("slot",R.SLOTNAME[slot],#l)
  for i=1,math.min(3,#l) do local s=l[i]; print("   ",s.id,s.name,s.slotText,s.boss,s.dungeon,s.stats) end
end
-- unparsed slot words across all max-level loot
local miss={}
for _,d in pairs(F.DB) do for _,b in ipairs(d.bosses or {}) do for _,it in ipairs(b.loot or {}) do
  if type(it[3])=="string" and not R.parseSlot(it[3]) then miss[it[3]]=(miss[it[3]] or 0)+1 end end end end
local t={} for k,v in pairs(miss) do t[#t+1]=k.."="..v end table.sort(t) print("unparsed:", table.concat(t," | "))
-- source of a known item
for _,d in pairs({F.DB["Scholomance"]}) do local it=d.bosses[2].loot[1]; print("src",it[1],it[2],R:JournalSource(it[1])) end
-- favourites + runs snapshot
ForeverDungeonJournalCharacterDB={favouriteItems={["13361"]={id=13361,name="Skullforge Reaver",slot="One-Hand, Sword",quality=3,dungeon="Stratholme: Undead",boss="Baron Rivendare"}},
 runLog={runs={{dungeon="Blackmaw Hold",created=NOW-3600,kills={{b="Impaan the Imprisoner"},{n=1}}},{dungeon="Shaper's Terrace",created=NOW-90000,kills={}}}}}
ITEMS[13361]={"Skullforge Reaver","INVTYPE_WEAPON"}
R:SyncJournal()
for _,r in ipairs(R:RecentRuns(R.key,7)) do print("run",r.dungeon,r.n,r.bosses) end
R.findSlot=16
for _,t in ipairs({"Gear","Lockouts"}) do R.tab=t; R:Refresh() end
print("ok")
