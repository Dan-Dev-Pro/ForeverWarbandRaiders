import lupa.lua51 as L, json
rt=L.LuaRuntime(unpack_returned_tuples=True)
rt.execute(open('mock.lua').read())
FD='/mnt/user-data/uploads/_forever_/Interface/AddOns/ForeverDungeonJournal/'
rt.execute('NS={}; UnitFactionGroup=function() return "Horde" end')
for f in ['Core/Bootstrap.lua','Data/Dungeons.lua','Data/SharedLoot.lua','Systems/ItemSource.lua']:
    fn=rt.eval('function(src,name) local f,err=loadstring(src,name); if not f then error(err) end; return f("ForeverDungeonJournal", NS) end')
    fn(open(FD+f,encoding='utf-8').read(), f)
for f in ['Core','Scan','Ready','Plans','Journal','BiS','UI','Panel']:
    rt.execute(open('../ForeverWarbandRaiders/%s.lua'%f).read())
rt.execute(open('t1.lua').read().split('local r=R:Readiness')[0])
rt.execute('''ForeverDungeonJournalCharacterDB={favouriteItems={["13361"]={id=13361,name="Skullforge Reaver",slot="One-Hand, Sword",quality=3,dungeon="Stratholme: Undead",boss="Baron Rivendare"},["12936"]={id=12936,name="Battleborn Armbraces",slot="Wrist, Plate",quality=3,dungeon="Upper Blackrock Spire",boss="Warchief Rend Blackhand"}},
 runLog={runs={{dungeon="Blackmaw Hold",created=NOW-3600,kills={{b="Impaan the Imprisoner"},{b="Bonesnout"}}},{dungeon="Blackmaw Hold",created=NOW-7200,kills={{b="Impaan the Imprisoner"}}},{dungeon="Shaper's Terrace",created=NOW-90000,kills={{b="x"}}}}}}
ITEMS[13361]={"Skullforge Reaver","INVTYPE_WEAPON"}; ITEMS[12936]={"Battleborn Armbraces","INVTYPE_WRIST"}
FWR:SyncJournal(); FWR.findSlot=13; FWR.sideMode="Drops"''')
def conv(x):
    if L.lua_type(x)=='table':
        keys=list(x.keys())
        if keys and all(isinstance(k,int) for k in keys) and sorted(keys)==list(range(1,len(keys)+1)):
            return [conv(x[k]) for k in sorted(keys)]
        return {k if isinstance(k,int) else str(k):conv(v) for k,v in x.items() if L.lua_type(v)!='function'}
    if L.lua_type(x)=='function': return None
    return x
import os
R=rt.globals().FWR
out={}
if os.environ.get('BIS'):
    t7=open('t7.lua').read().split('-- without cap')[0]
    rt.execute(t7)
    rt.execute('FWR:Char().sets[1].pins={}; FWR:Char().sets[1].slots[1]={id=5002}; FWR:Char().sets[1].slots[13]={id=5010}; FWR:Char().sets[1].pins[13]=true; FWR:BisDirty()')
    for m in ['Best','Weights']:
        rt.execute('FWR.sideMode="%s"'%m)
        out['Gear'+m]=conv(R.BuildOps(R,'Gear',R.key))
for t in ['Ready','Gear','Lockouts','Prep','Settings']:
    out[t]=conv(R.BuildOps(R,t,R.key))
c=R.Char(R,R.key)
out['_who']="%s 60 Warrior"%c.name
json.dump(out,open('ops.json','w'),indent=1)
print({k:len(v) for k,v in out.items() if k[0]!='_'})
