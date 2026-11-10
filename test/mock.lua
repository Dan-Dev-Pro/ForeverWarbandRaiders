NILKEYS={TitleText=1,TitleContainer=1,CloseButton=1,portrait=1,PortraitContainer=1,Inset=1,closeButton=1,fwrSig=1,fwrTemplate=1}
-- minimal WoW API mock
local function obj()
  local o = {_shown=false, _text=""}
  return setmetatable(o, {__index=function(t,k)
    if type(k)=="string" and k:sub(1,1)=="_" then return nil end
    if NILKEYS[k] then return nil end
    if k=="CreateFontString" or k=="CreateTexture" then return function() return obj() end end
    if k=="Show" then return function(s) s._shown=true end end
    if k=="Hide" then return function(s) s._shown=false end end
    if k=="IsShown" then return function(s) return s._shown end end
    if k=="SetText" then return function(s,v) s._text=v end end
    if k=="GetText" then return function(s) return s._text end end
    if k=="GetStringHeight" then return function() return 14 end end
    if k=="GetFrameLevel" then return function() return 1 end end
    if k=="HasFocus" then return function() return false end end
    if k=="SetScript" then return function(s,e,f) s["_"..e]=f end end
    if k=="StartMoving" or k=="StopMovingOrSizing" then return function() end end
    return function() end
  end})
end
ALL={}
CreateFrame=function() local o=obj(); ALL[#ALL+1]=o; return o end
UIParent=obj(); GameTooltip=obj(); UISpecialFrames={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,m) print("CHAT", (m:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""))) end}
Mixin=function(o,m) return o end; BackdropTemplateMixin={}
hooksecurefunc=function() end; ChatEdit_InsertLink=function() end
SlashCmdList={}
NOW=1765000000
time=function() return NOW end
NAME="Quail"; CLS="WARRIOR"; LVL=60; MONEY=1234567
UnitName=function() return NAME end
UnitClass=function() return "Warrior", CLS end
UnitLevel=function() return LVL end
GetRealmName=function() return "" end
GetMoney=function() return MONEY end
ITEMS={ [101]={"Lionheart Helm","INVTYPE_HEAD"}, [102]={"Onyxia Tooth Pendant","INVTYPE_NECK"}, [103]={"Blackhand's Breadth","INVTYPE_TRINKET"},
 [104]={"Hand of Justice","INVTYPE_TRINKET"}, [105]={"Don Julio's Band","INVTYPE_FINGER"}, [106]={"Crimson Felt Hat","INVTYPE_HEAD"},
 [107]={"Arcanite Reaper","INVTYPE_2HWEAPON"}, [108]={"Savage Gladiator Chain","INVTYPE_CHEST"},
 [201]={"Elixir of the Mongoose","INVTYPE_NONE_"}, [202]={"Major Healing Potion",""}, [203]={"Juju Power",""}, [204]={"Smoked Desert Dumplings",""},
 [301]={"Horn of the Frostwolf Howler","",15,5} }
GetItemInfo=function(id) local i=ITEMS[id]; if not i then return end
  return i[1], "|cffa335ee|Hitem:"..id.."::::|h["..i[1].."]|h|r", 4, 60, 60, "Armor", "", 1, i[2], 134400, 1, i[3] or 4, i[4] or 0 end
EQUIP={[1]="item:106:0",[5]="item:108:1891",[16]="item:107:1900",[13]="item:104:0",[15]="item:999:0",[10]="item:998:0"}
ITEMS[999]={"Cape of the Black Baron","INVTYPE_CLOAK"}; ITEMS[998]={"Devilsaur Gauntlets","INVTYPE_HAND"}
GetInventoryItemLink=function(_,slot) local l=EQUIP[slot]; return l and ("|cff|H"..l..":::|h[x]|h|r") end
GetInventoryItemDurability=function(slot) if EQUIP[slot] then return 70,100 end end
BAGS={[0]={{103,1},{202,8},{301,1}},[1]={{204,10}}}
C_Container={GetContainerNumSlots=function(b) return BAGS[b] and #BAGS[b] or 0 end,
  GetContainerItemInfo=function(b,s) local x=BAGS[b] and BAGS[b][s]; if x then return {itemID=x[1],stackCount=x[2]} end end}
SAVED={}
GetNumSavedInstances=function() return #SAVED end
GetSavedInstanceInfo=function(i) local s=SAVED[i]; return s[1],1,s[2],3,true,false,0,true,s[3],"Normal",s[4],s[5] end
RequestRaidInfo=function() end
C_DateAndTime={GetSecondsUntilWeeklyReset=function() return 2*86400+3600*5 end, GetSecondsUntilDailyReset=function() return 3600*7+60*12 end}
tinsert=table.insert
EVENTS={}
function FIRE(e,...) local f=FWR.ev; if f._OnEvent then f._OnEvent(f,e,...) end end
CURSOR=nil
GetCursorInfo=function() if CURSOR then return "item", CURSOR end end
ClearCursor=function() CURSOR=nil end
IsControlKeyDown=function() return false end
IsShiftKeyDown=function() return false end
GetItemIcon=function(id) return "icon"..id end
GetInventorySlotInfo=function(n) return 1, "Interface\\PaperDoll\\UI-PaperDoll-Slot-"..n end
SetPortraitTexture=function() end
