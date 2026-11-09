import lupa.lua51 as L, json
rt=L.LuaRuntime(unpack_returned_tuples=True)
rt.execute(open('mock.lua').read())
for f in ['Core','Scan','Ready','Plans','UI','Panel']:
    rt.execute(open('../ForeverWarbandRaiders/%s.lua'%f).read())
rt.execute(open('t1.lua').read().split('local r=R:Readiness')[0])
def conv(x):
    if L.lua_type(x)=='table':
        keys=list(x.keys())
        if keys and all(isinstance(k,int) for k in keys):
            return [conv(x[k]) for k in sorted(keys)]
        return {str(k):conv(v) for k,v in x.items() if L.lua_type(v)!='function'}
    if L.lua_type(x)=='function': return None
    return x
R=rt.globals().FWR
out={}
for t in ['Ready','Gear','Lockouts','Prep','Settings']:
    out[t]=conv(R.BuildOps(R,t,R.key))
c=R.Char(R,R.key)
out['_who']="%s 60 Warrior"%c.name
json.dump(out,open('ops.json','w'),indent=1)
print({k:len(v) for k,v in out.items() if k[0]!='_'})
