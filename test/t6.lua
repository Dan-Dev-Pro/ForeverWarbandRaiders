local R=FWR
for _,m in ipairs({"Favourites","Plan","Drops"}) do
  R.tab="Gear"; R.sideMode=m; R:Refresh()
  local errs=0
  for i=1,#ALL do local o=ALL[i]
    if o._shown then for _,e in ipairs({"_OnEnter","_OnClick"}) do local f=rawget(o,e); if f then local ok,err=pcall(f,o,"LeftButton"); if not ok then errs=errs+1; print("ERR",m,err) end end end end
  end
  print(m,"errs",errs)
end
R.dropPage=99; R.sideMode="Drops"; R.findSlot=16; R:Refresh(); print("page",R.dropPage)
