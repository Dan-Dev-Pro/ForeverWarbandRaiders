local R=FWR
R.tab="Gear"; R.sideMode="Weights"; R:Refresh()
local boxes={}
for i=1,#ALL do local o=ALL[i]; if o._shown and rawget(o,"_OnEditFocusLost") then boxes[#boxes+1]=o end end
print("boxes",#boxes, "R.view", R.view, "R.key", R.key)
for i,b in ipairs(boxes) do io.write(i,":",tostring(b._text)," ") end print()
local o; for _,b in ipairs(boxes) do if b._text=="0.6" then o=b; break end end
o._text="1.5"; o._OnEditFocusLost(o)
local set=R:Char(R.view).sets[R:SetIndex(R.view)]
for k,v in pairs(set.weights) do io.write(k,"=",v," ") end print()
print("busy", rawget(o,"fwrBusy"), "focus fn", rawget(o,"_OnEditFocusLost")~=nil)
o._text="1.7"; local f=rawget(o,"_OnEditFocusLost"); f(o)
for k,v in pairs(set.weights) do io.write(k,"=",v," ") end print()
