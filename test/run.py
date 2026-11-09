import lupa.lua51 as L, sys, json
rt=L.LuaRuntime(unpack_returned_tuples=True)
rt.execute(open('mock.lua').read())
for f in ['Core','Scan','Ready','Plans','UI','Panel']:
    rt.execute(open('../ForeverWarbandRaiders/%s.lua'%f).read())
for s in sys.argv[1:]: rt.execute(open(s).read())
