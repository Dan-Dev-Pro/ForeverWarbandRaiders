local a,b=0,0
for i=1,#ALL do local o=ALL[i]; if o._OnReceiveDrag~=nil then a=a+1; if o._shown then b=b+1 end end end
print("withdrag",a,"shown",b, "all", #ALL)
