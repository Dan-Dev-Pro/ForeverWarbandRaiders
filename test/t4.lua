local R=FWR
R.tab="Gear"; R:Refresh()
-- drag Lionheart onto neck (wrong) then head
print(R:DropOnSlot(R.key,1,2,101)); print(R:DropOnSlot(R.key,1,1,101))
-- simulate click with cursor item on a slot button
local n=0
for i=1,#ALL do local o=ALL[i]; if o._shown and o._OnReceiveDrag then n=n+1 end end
print("slot buttons", n)
CURSOR=106
for i=1,#ALL do local o=ALL[i]; if o._shown and o._OnReceiveDrag then o._OnReceiveDrag(o); break end end
print("head now", R:Char().sets[1].slots[1].id)
for i=1,#ALL do local o=ALL[i]; if o._shown and o._OnReceiveDrag then o._OnClick(o,"LeftButton") end end
print("sel", R.findSlot)
