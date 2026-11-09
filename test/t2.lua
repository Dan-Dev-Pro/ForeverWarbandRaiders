local R=FWR
local errs=0
for _,t in ipairs(R.TABS) do
  R.tab=t.name; R:Refresh()
  for i=1,#ALL do local o=ALL[i]
    if o._shown then
      for _,e in ipairs({"_OnEnter","_OnClick","_OnEnterPressed"}) do
        local f=o[e]
        if f then local ok,err=pcall(f,o); if not ok then errs=errs+1; print("ERR",t.name,e,err) end end
      end
    end
  end
  R.tab=t.name; R:Refresh()
end
print("click errors", errs)
