import lupa.lua51 as L, sys, json
rt=L.LuaRuntime(unpack_returned_tuples=True)
rt.execute(open('mock.lua').read())
import os
FD='/mnt/user-data/uploads/_forever_/Interface/AddOns/ForeverDungeonJournal/'
if os.environ.get('FDJ'):
    rt.execute('_G=_G or getfenv(0); NS={}; UnitFactionGroup=function() return "Horde" end; issecretvalue=nil')
    for f in ['Core/Bootstrap.lua','Data/Dungeons.lua','Data/SharedLoot.lua','Systems/ItemSource.lua']:
        fn=rt.eval('function(src,name) local f,err=loadstring(src,name); if not f then error(err) end; return f("ForeverDungeonJournal", NS) end')
        fn(open(FD+f,encoding='utf-8').read(), f)
for f in ['Core','Scan','Ready','Plans','Journal','UI','Panel']:
    rt.execute(open('../ForeverWarbandRaiders/%s.lua'%f).read())
for s in sys.argv[1:]: rt.execute(open(s).read())
