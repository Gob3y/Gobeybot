-- HAIMIYACH_GAF_V1.lua
-- Grow a Chicken Fighter | mobile-safe tab UI
-- Confirmed source interfaces: HatchEggs, FuseChickens, UpgradeRecycler, Rebirth.
-- Unknown remotes are NOT guessed; GUI fallbacks are used where possible.

local P=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local CS=game:GetService("CollectionService")
local WS=game:GetService("Workspace")
local LP=P.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")

pcall(function() local x=PG:FindFirstChild("HAIMIYACH_GAF_V1");if x then x:Destroy() end end)

local Remotes,defs
pcall(function() Remotes=require(RS:WaitForChild("Core"):WaitForChild("Remotes"));defs=Remotes.defs end)
local DC
pcall(function() DC=require(LP:WaitForChild("PlayerScripts"):WaitForChild("Core"):WaitForChild("Data"):WaitForChild("DataController")) end)

local function invoke(n,...)
 if not(Remotes and defs and defs[n]) then return false,nil end
 local ok,r=pcall(Remotes.invoke,defs[n],...)
 return ok,r
end
local function get(p)
 if not DC then return nil end
 local ok,r=pcall(function() return DC[p[1]]() end)
 return ok and r or nil
end
local function roster() return get({"roster"}) or {} end
local function eggs() return roster().eggs or {} end
local function chickens() return roster().chickens or {} end

local S={
 openEggs=false,eggTier="Any",hatchBatch="Max",hatchDelay=1.2,
 fuse=false,fuseMode="Same Rarity",fuseRarity="Any",keepFav=true,fuseDelay=1.2,
 scrap=false,scrapRadius=250,recycle=false,recycleDelay=1.5,
 recycler=false,recyclerMode="When Affordable",recyclerDelay=2,
 rebirth=false,rebirthMode="When Ready",rebirthDelay=3,
 coop=false,feederUpgrade=false,feederBuy=false,
 chaos=false,startChaos=false,eventChaos=false,cancelEvent=true,eventPhase="Any Active",
 tower=false,noThanks=false
}
local token={}
for k in pairs(S) do token[k]=0 end
local function stop(k) token[k]=(token[k] or 0)+1 end
local function loop(k,fn,delay)
 stop(k);local t=token[k]
 task.spawn(function()
  while token[k]==t and S[k] do pcall(fn);task.wait(delay or 1) end
 end)
end

-- EGG
local busyH=false
local function hatch()
 if busyH then return end
 local tier,count
 if S.eggTier~="Any" then tier=S.eggTier;count=tonumber(eggs()[tier]) or 0
 else
  for k,v in pairs(eggs()) do if tonumber(v) and v>0 then tier=k;count=v;break end end
 end
 if not tier or count<=0 then return end
 local n=S.hatchBatch=="Max" and count or math.min(count,tonumber(S.hatchBatch) or 1)
 busyH=true;invoke("HatchEggs",tier,n);task.delay(.7,function()busyH=false end)
end
local function setH(v) S.openEggs=v;if v then loop("openEggs",hatch,S.hatchDelay) else stop("openEggs") end end

-- FUSE
local busyF=false
local function fuse()
 if busyF then return end
 local groups={}
 for _,c in pairs(chickens()) do
  if type(c)=="table" and c.id and not(S.keepFav and (c.favorite==true or c.favorited==true)) then
   local r=tostring(c.rarity or "common")
   if S.fuseRarity=="Any" or r:lower()==S.fuseRarity:lower() then
    local key=S.fuseMode=="Same Type" and tostring(c.typeId or c.type or "?") or (S.fuseMode=="Same Rarity" and r or "any")
    groups[key]=groups[key] or {};table.insert(groups[key],c)
   end
  end
 end
 for _,g in pairs(groups) do
  if #g>=2 then
   busyF=true;invoke("FuseChickens",g[1].id,g[2].id,nil,nil,nil)
   task.delay(.8,function()busyF=false end);return
  end
 end
end
local function setF(v) S.fuse=v;if v then loop("fuse",fuse,S.fuseDelay) else stop("fuse") end end

-- SCRAP: teleport only, no fake collect input/button
local function pos(o)
 if type(o)=="table" and typeof(o.Position)=="Vector3" then return o.Position end
 if o:IsA("BasePart") then return o.Position end
 if o:IsA("Model") then return o:GetPivot().Position end
end
local function nearestScrap()
 local ch=LP.Character;local root=ch and ch:FindFirstChild("HumanoidRootPart");if not root then return end
 local best,bd
 for _,o in ipairs(CS:GetTagged("Scrap")) do
  local p=pos(o);if p then local d=(p-root.Position).Magnitude;if d<=S.scrapRadius and(not bd or d<bd)then best,bd=o,d end end
 end
 local d=get({"scrap"})
 if type(d)=="table" and type(d.positions)=="table" then
  for id,p in pairs(d.positions) do if not(d.taken and d.taken[id]) and typeof(p)=="Vector3" then local z=(p-root.Position).Magnitude;if z<=S.scrapRadius and(not bd or z<bd)then best={Position=p},bd=z end end end
 end
 return best
end
local function grabScrap()
 local o=nearestScrap();local p=o and pos(o);local ch=LP.Character;local r=ch and ch:FindFirstChild("HumanoidRootPart")
 if p and r then pcall(function()r.CFrame=CFrame.new(p+Vector3.new(0,3,0))end)end
end
local function setScrap(v) S.scrap=v;if v then loop("scrap",grabScrap,.8) else stop("scrap") end end

local function recycler()
 local d=get({"scrap"});if type(d)~="table" then return end
 local lvl=tonumber(d.recyclerLevel or 0) or 0
 local cost
 pcall(function()local V=require(RS.Features.Scrap.RecyclerView);cost=tonumber(V.upgradeCost(lvl))end)
 if S.recyclerMode=="When Affordable" and cost then
  local m=get({"money"});if type(m)=="table" and m.toNumber then m=m:toNumber() end
  if tonumber(m) and tonumber(m)<cost then return end
 end
 invoke("UpgradeRecycler")
end
local function setRecycler(v)S.recycler=v;if v then loop("recycler",recycler,S.recyclerDelay)else stop("recycler")end end
local function setRebirth(v)S.rebirth=v;if v then loop("rebirth",function()invoke("Rebirth")end,S.rebirthDelay)else stop("rebirth")end end

-- GUI button discovery for Chaos/Tower/No Thanks.
local function txt(o)local ok,t=pcall(function()return o.Text end);return ok and tostring(t):lower() or ""end
local function visible(o)
 if not o:IsA("GuiObject") or not o.Visible then return false end
 local p=o.Parent
 while p and p~=PG do if p:IsA("GuiObject") and not p.Visible then return false end;p=p.Parent end
 return true
end
local function find(words)
 for _,o in ipairs(PG:GetDescendants()) do
  if o:IsA("TextButton") and visible(o) then
   local t=txt(o);local yes=true
   for _,w in ipairs(words) do if not t:find(w:lower(),1,true) then yes=false;break end end
   if yes then return o end
  end
 end
end
local function act(words)local b=find(words);if b then pcall(function()b:Activate()end);return true end end
local lastChaos=0
local function chaosStart()if os.clock()-lastChaos<1.2 then return end;if find({"cancel"})then return end;if act({"chaos"})then lastChaos=os.clock()end end
local function chaosCancel()if os.clock()-lastChaos<1.2 then return end;if act({"cancel"})then lastChaos=os.clock()end end
local function setChaos(v)S.chaos=v;if v then loop("chaos",chaosStart,1.2)else stop("chaos")end end
local function setStartChaos(v)S.startChaos=v;if v then loop("startChaos",chaosStart,1.2)else stop("startChaos")end end

local E={id=nil,phase=nil,deadline=nil,active=false}
local function readEvent()
 E.id=WS:GetAttribute("EventId");E.phase=WS:GetAttribute("EventPhase");E.deadline=tonumber(WS:GetAttribute("EventDeadline"))
 E.active=E.id~=nil and(E.phase=="idle" or E.phase=="warmup" or E.phase=="live")
 if E.deadline and WS.GetServerTimeNow then local ok,r=pcall(function()return E.deadline-WS:GetServerTimeNow()end);if ok and r<=0 then E.active=false end end
end
local function eventTick()
 readEvent()
 local match=E.active and(S.eventPhase=="Any Active" or tostring(E.phase):lower()==S.eventPhase:lower())
 if match then chaosStart()elseif S.cancelEvent then chaosCancel()end
end
local function setEvent(v)S.eventChaos=v;if v then loop("eventChaos",eventTick,.7)else stop("eventChaos")end end
for _,a in ipairs({"EventId","EventPhase","EventDeadline"}) do WS:GetAttributeChangedSignal(a):Connect(function()readEvent();if S.eventChaos then task.defer(eventTick)end end)end
readEvent()

local function setTower(v)S.tower=v;if v then loop("tower",function()act({"tower"})end,2)else stop("tower")end end
local function setNoThanks(v)S.noThanks=v;if v then loop("noThanks",function()act({"no thanks"})end,1.5)else stop("noThanks")end end
local function setCoop(v)S.coop=v;if v then loop("coop",function()act({"upgrade","coop"})end,3)else stop("coop")end end
local function setFeederU(v)S.feederUpgrade=v;if v then loop("feederUpgrade",function()act({"upgrade","feeder"})end,3)else stop("feederUpgrade")end end
local function setFeederB(v)S.feederBuy=v;if v then loop("feederBuy",function()act({"buy","feeder"})end,3)else stop("feederBuy")end end
local function setRecycle(v)
 S.recycle=v
 if v then
  loop("recycle",function()
   local rs=WS:FindFirstChild("Recyclers");local idx=LP:GetAttribute("Plot");local r=idx and rs and rs:FindFirstChild("Recycler"..tostring(idx))
   if r then local o=r:GetAttribute("Origin");local p=typeof(o)=="CFrame" and o.Position or(typeof(o)=="Vector3" and o)or r:GetPivot().Position
    local ch=LP.Character;local root=ch and ch:FindFirstChild("HumanoidRootPart");if root then root.CFrame=CFrame.new(p+Vector3.new(0,3,0))end
   end
  end,S.recycleDelay)
 else stop("recycle")end
end

-- UI
local G=Instance.new("ScreenGui");G.Name="HAIMIYACH_GAF_V1";G.ResetOnSpawn=false;G.IgnoreGuiInset=true;G.DisplayOrder=999999;G.Parent=PG
local vp=WS.CurrentCamera and WS.CurrentCamera.ViewportSize or Vector2.new(800,600)
local portrait=vp.Y>=vp.X
local W=math.clamp(math.floor(vp.X*(portrait and .82 or .38)),270,365)
local H=math.clamp(math.floor(vp.Y*(portrait and .68 or .76)),390,570)
local function cr(o,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 7);c.Parent=o end
local function st(o)local s=Instance.new("UIStroke");s.Color=Color3.fromRGB(65,67,76);s.Transparency=.25;s.Parent=o end
local Win=Instance.new("Frame");Win.Size=UDim2.fromOffset(W,H);Win.Position=UDim2.new(0,10,.5,-H/2);Win.BackgroundColor3=Color3.fromRGB(23,24,28);Win.BorderSizePixel=0;Win.ClipsDescendants=true;Win.Parent=G;cr(Win,9);st(Win)
local Head=Instance.new("Frame");Head.Size=UDim2.new(1,0,0,43);Head.BackgroundColor3=Color3.fromRGB(30,31,36);Head.BorderSizePixel=0;Head.Active=true;Head.Parent=Win;cr(Head,9)
local T=Instance.new("TextLabel");T.Size=UDim2.new(1,-55,0,22);T.Position=UDim2.fromOffset(11,5);T.BackgroundTransparency=1;T.Text="GROW A CHICKEN FIGHTER";T.TextColor3=Color3.fromRGB(245,246,249);T.Font=Enum.Font.GothamBold;T.TextSize=10;T.TextXAlignment=Enum.TextXAlignment.Left;T.Parent=Head
local X=Instance.new("TextButton");X.Size=UDim2.fromOffset(28,28);X.Position=UDim2.new(1,-35,0,7);X.BackgroundColor3=Color3.fromRGB(44,45,52);X.BorderSizePixel=0;X.Text="×";X.TextColor3=Color3.fromRGB(220,221,226);X.Font=Enum.Font.GothamMedium;X.TextSize=18;X.AutoButtonColor=false;X.Parent=Head;cr(X,7)

local TB=Instance.new("ScrollingFrame");TB.Size=UDim2.new(1,-12,0,38);TB.Position=UDim2.fromOffset(6,47);TB.BackgroundColor3=Color3.fromRGB(29,30,35);TB.BorderSizePixel=0;TB.ScrollBarThickness=0;TB.ScrollingDirection=Enum.ScrollingDirection.X;TB.AutomaticCanvasSize=Enum.AutomaticSize.X;TB.Parent=Win;cr(TB,7)
local tp=Instance.new("UIPadding");tp.PaddingLeft=UDim.new(0,4);tp.PaddingTop=UDim.new(0,5);tp.Parent=TB
local tl=Instance.new("UIListLayout");tl.FillDirection=Enum.FillDirection.Horizontal;tl.Padding=UDim.new(0,4);tl.Parent=TB
local PH=Instance.new("Frame");PH.Size=UDim2.new(1,-12,1,-91);PH.Position=UDim2.fromOffset(6,88);PH.BackgroundTransparency=1;PH.ClipsDescendants=true;PH.Parent=Win
local Pages,Tabs={},{}
local function page(n)
 local p=Instance.new("ScrollingFrame");p.Name=n;p.Size=UDim2.fromScale(1,1);p.BackgroundTransparency=1;p.BorderSizePixel=0;p.ScrollBarThickness=3;p.AutomaticCanvasSize=Enum.AutomaticSize.Y;p.CanvasSize=UDim2.new();p.Visible=false;p.Parent=PH
 local q=Instance.new("UIPadding");q.PaddingLeft=UDim.new(0,3);q.PaddingRight=UDim.new(0,3);q.PaddingBottom=UDim.new(0,12);q.Parent=p
 local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,5);l.Parent=p;Pages[n]=p;return p
end
local function tab(n,i)
 local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(76,28);b.BackgroundColor3=Color3.fromRGB(43,44,51);b.BorderSizePixel=0;b.AutoButtonColor=false;b.Text=i.."  "..n;b.TextColor3=Color3.fromRGB(165,167,176);b.Font=Enum.Font.GothamBold;b.TextSize=7;b.Parent=TB;cr(b,6);Tabs[n]=b;return b
end
local function select(n)
 for k,p in pairs(Pages)do p.Visible=k==n end
 for k,b in pairs(Tabs)do local on=k==n;b.BackgroundColor3=on and Color3.fromRGB(72,74,84)or Color3.fromRGB(43,44,51);b.TextColor3=on and Color3.fromRGB(245,246,249)or Color3.fromRGB(165,167,176)end
end
local function sec(p,t,o)local l=Instance.new("TextLabel");l.Size=UDim2.new(1,0,0,18);l.BackgroundTransparency=1;l.Text=t;l.TextColor3=Color3.fromRGB(112,115,127);l.Font=Enum.Font.GothamBold;l.TextSize=7;l.TextXAlignment=Enum.TextXAlignment.Left;l.LayoutOrder=o;l.Parent=p end
local function tog(p,t,o,key,fn)
 local r=Instance.new("Frame");r.Size=UDim2.new(1,0,0,36);r.BackgroundColor3=Color3.fromRGB(34,35,41);r.BorderSizePixel=0;r.LayoutOrder=o;r.Parent=p;cr(r,7);st(r)
 local l=Instance.new("TextLabel");l.Size=UDim2.new(1,-78,1,0);l.Position=UDim2.fromOffset(10,0);l.BackgroundTransparency=1;l.Text=t;l.TextColor3=Color3.fromRGB(226,228,235);l.Font=Enum.Font.GothamMedium;l.TextSize=8;l.TextXAlignment=Enum.TextXAlignment.Left;l.Parent=r
 local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(50,23);b.Position=UDim2.new(1,-60,.5,-11);b.BackgroundColor3=Color3.fromRGB(45,45,48);b.BorderSizePixel=0;b.AutoButtonColor=false;b.TextSize=7;b.Font=Enum.Font.GothamBold;b.Parent=r;cr(b,12)
 local k=Instance.new("Frame");k.Size=UDim2.fromOffset(15,15);k.Parent=b;cr(k,8)
 local function draw()local on=S[key];b.Text=on and"ON"or"OFF";b.BackgroundColor3=on and Color3.fromRGB(82,84,94)or Color3.fromRGB(45,45,48);k.BackgroundColor3=on and Color3.fromRGB(245,245,245)or Color3.fromRGB(165,165,170);k.Position=on and UDim2.new(1,-19,.5,-7)or UDim2.fromOffset(4,4)end
 b.Activated:Connect(function()fn(not S[key]);draw()end);draw()
end
local dropdownOpen=nil
local function dd(p,t,o,key,opts)
 local h=Instance.new("Frame");h.Size=UDim2.new(1,0,0,38);h.BackgroundTransparency=1;h.LayoutOrder=o;h.Parent=p
 local r=Instance.new("Frame");r.Size=UDim2.new(1,0,0,38);r.BackgroundColor3=Color3.fromRGB(34,35,41);r.BorderSizePixel=0;r.Parent=h;cr(r,7);st(r)
 local l=Instance.new("TextLabel");l.Size=UDim2.new(.43,0,1,0);l.Position=UDim2.fromOffset(10,0);l.BackgroundTransparency=1;l.Text=t;l.TextColor3=Color3.fromRGB(220,222,230);l.Font=Enum.Font.GothamMedium;l.TextSize=8;l.TextXAlignment=Enum.TextXAlignment.Left;l.Parent=r
 local b=Instance.new("TextButton");b.Size=UDim2.new(.53,-10,0,26);b.Position=UDim2.new(.47,0,.5,-13);b.BackgroundColor3=Color3.fromRGB(45,46,54);b.BorderSizePixel=0;b.AutoButtonColor=false;b.TextColor3=Color3.fromRGB(222,224,231);b.Font=Enum.Font.GothamMedium;b.TextSize=8;b.TextTruncate=Enum.TextTruncate.AtEnd;b.Parent=r;cr(b,6)
 local list=Instance.new("ScrollingFrame");list.Position=UDim2.fromOffset(0,38);list.Size=UDim2.new(1,0,0,0);list.BackgroundColor3=Color3.fromRGB(30,31,37);list.BorderSizePixel=0;list.Visible=false;list.ScrollBarThickness=3;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.ZIndex=50;list.Parent=h;cr(list,7);st(list)
 local ly=Instance.new("UIListLayout");ly.Padding=UDim.new(0,3);ly.Parent=list
 local function draw()b.Text=tostring(S[key])end
 for i,v in ipairs(opts)do local x=Instance.new("TextButton");x.Size=UDim2.new(1,-8,0,28);x.BackgroundColor3=Color3.fromRGB(40,41,48);x.BorderSizePixel=0;x.AutoButtonColor=false;x.Text="  "..v;x.TextColor3=Color3.fromRGB(222,224,231);x.Font=Enum.Font.Gotham;x.TextSize=8;x.TextXAlignment=Enum.TextXAlignment.Left;x.LayoutOrder=i;x.ZIndex=51;x.Parent=list;cr(x,5);x.Activated:Connect(function()S[key]=v;draw();list.Visible=false;list.Size=UDim2.new(1,0,0,0);dropdownOpen=nil end)end
 b.Activated:Connect(function()if dropdownOpen and dropdownOpen~=list then dropdownOpen.Visible=false;dropdownOpen.Size=UDim2.new(1,0,0,0)end;local on=not list.Visible;list.Visible=on;list.Size=UDim2.new(1,0,0,on and math.min(#opts*31+6,155)or 0);dropdownOpen=on and list or nil;draw()end);draw()
end
local function btn(p,t,o,fn)local b=Instance.new("TextButton");b.Size=UDim2.new(1,0,0,36);b.BackgroundColor3=Color3.fromRGB(34,35,41);b.BorderSizePixel=0;b.AutoButtonColor=false;b.Text="  "..t;b.TextColor3=Color3.fromRGB(226,228,235);b.Font=Enum.Font.GothamMedium;b.TextSize=8;b.TextXAlignment=Enum.TextXAlignment.Left;b.LayoutOrder=o;b.Parent=p;cr(b,7);st(b);b.Activated:Connect(fn)end

local Main=page("MAIN");local Scr=page("SCRAP");local Coop=page("COOP");local Chaos=page("CHAOS");local Tower=page("TOWER");local Set=page("SETTINGS")
tab("MAIN","◆").Activated:Connect(function()select("MAIN")end);tab("SCRAP","◇").Activated:Connect(function()select("SCRAP")end);tab("COOP","▣").Activated:Connect(function()select("COOP")end);tab("CHAOS","⚡").Activated:Connect(function()select("CHAOS")end);tab("TOWER","▲").Activated:Connect(function()select("TOWER")end);tab("SETTINGS","⚙").Activated:Connect(function()select("SETTINGS")end)

sec(Main,"EGGS",1);tog(Main,"Auto Open Eggs",2,"openEggs",setH);dd(Main,"Egg Tier",3,"eggTier",{"Any","common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"});dd(Main,"Hatch Batch",4,"hatchBatch",{"Max","1","2","3","5","10"});dd(Main,"Hatch Delay",5,"hatchDelay",{"0.6","1","1.2","2","3"})
sec(Main,"FUSION",10);tog(Main,"Auto Fuse Chickens",11,"fuse",setF);dd(Main,"Fuse Mode",12,"fuseMode",{"Same Rarity","Same Type","Any"});dd(Main,"Fuse Rarity",13,"fuseRarity",{"Any","common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"});tog(Main,"Keep Favorite",14,"keepFav",function(v)S.keepFav=v end)
sec(Main,"REBIRTH",20);tog(Main,"Auto Rebirth",21,"rebirth",setRebirth);dd(Main,"Rebirth Mode",22,"rebirthMode",{"When Ready","Always Check"})

sec(Scr,"SCRAPS",1);tog(Scr,"Auto Grab Scraps",2,"scrap",setScrap);dd(Scr,"Scrap Radius",3,"scrapRadius",{"50","100","150","250","500"});btn(Scr,"Teleport to Nearest Scrap",4,grabScrap)
sec(Scr,"RECYCLER",9);tog(Scr,"Auto Recycle Scrap",10,"recycle",setRecycle);dd(Scr,"Recycle Delay",11,"recycleDelay",{"0.8","1.5","2","3"});tog(Scr,"Auto Upgrade Recycler",12,"recycler",setRecycler);dd(Scr,"Recycler Mode",13,"recyclerMode",{"When Affordable","Check Only"})

sec(Coop,"COOP",1);tog(Coop,"Auto Upgrade Coop",2,"coop",setCoop);dd(Coop,"Coop Mode",3,"coopMode",{"When Affordable","Next Available"})
sec(Coop,"FEEDER",9);tog(Coop,"Auto Upgrade Feeder",10,"feederUpgrade",setFeederU);dd(Coop,"Upgrade Mode",11,"feederMode",{"Next Available","When Affordable"});tog(Coop,"Auto Buy Feeders",12,"feederBuy",setFeederB);dd(Coop,"Buy Mode",13,"feederBuyMode",{"One at a Time","Keep Checking"})

sec(Chaos,"CHAOS",1);tog(Chaos,"Auto Chaos",2,"chaos",setChaos);tog(Chaos,"Auto Start Chaos",3,"startChaos",setStartChaos)
sec(Chaos,"EVENT → CHAOS",9);tog(Chaos,"Auto Events → Chaos",10,"eventChaos",setEvent);tog(Chaos,"Auto Cancel Event Chaos",11,"cancelEvent",function(v)S.cancelEvent=v end);dd(Chaos,"Event Phase",12,"eventPhase",{"Any Active","warmup","live"})
local EL=Instance.new("TextLabel");EL.Size=UDim2.new(1,0,0,44);EL.BackgroundColor3=Color3.fromRGB(34,35,41);EL.BorderSizePixel=0;EL.TextColor3=Color3.fromRGB(210,212,220);EL.Font=Enum.Font.GothamMedium;EL.TextSize=8;EL.TextXAlignment=Enum.TextXAlignment.Left;EL.LayoutOrder=13;EL.Parent=Chaos;cr(EL,7);st(EL)
task.spawn(function()while G.Parent do readEvent();local rem="--";if E.deadline and WS.GetServerTimeNow then local ok,n=pcall(function()return math.max(0,E.deadline-WS:GetServerTimeNow())end);if ok then rem=string.format("%.0fs",n)end end;EL.Text=string.format("  Event: %s\n  Phase: %s | Remaining: %s",tostring(E.id or"None"),tostring(E.phase or"idle"),rem);task.wait(.5)end end)
tog(Chaos,"Auto No Thanks",15,"noThanks",setNoThanks)

sec(Tower,"TOWER",1);tog(Tower,"Auto Start Tower",2,"tower",setTower);dd(Tower,"Tower Mode",3,"towerMode",{"Start When Available","Keep Checking"});btn(Tower,"Start Tower Now",4,function()act({"tower"})end)

sec(Set,"GENERAL",1);btn(Set,"Stop All Automation",2,function()for k in pairs(S)do if type(S[k])=="boolean"then S[k]=false end;stop(k)end end);btn(Set,"Refresh Event State",3,function()readEvent()end)

local Open=Instance.new("TextButton");Open.Size=UDim2.fromOffset(92,30);Open.Position=UDim2.new(.5,-46,0,8);Open.BackgroundColor3=Color3.fromRGB(30,31,36);Open.AutoButtonColor=false;Open.Text="HAIMIYACH";Open.TextColor3=Color3.fromRGB(242,243,246);Open.Font=Enum.Font.GothamBold;Open.TextSize=8;Open.Visible=false;Open.ZIndex=100;Open.Parent=G;cr(Open,16);st(Open)
X.Activated:Connect(function()Win.Visible=false;Open.Visible=true end);Open.Activated:Connect(function()Win.Visible=true;Open.Visible=false end)

local function drag(handle,target)
 local down=false;local start,orig;local c
 handle.InputBegan:Connect(function(i)
  if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
  down=true;start=i.Position;orig=target.Position
  if c then c:Disconnect()end
  c=UIS.InputChanged:Connect(function(m)if not down then return end;if m.UserInputType~=Enum.UserInputType.Touch and m.UserInputType~=Enum.UserInputType.MouseMovement then return end;local d=m.Position-start;target.Position=UDim2.new(orig.X.Scale,orig.X.Offset+d.X,orig.Y.Scale,orig.Y.Offset+d.Y)end)
  i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then down=false;if c then c:Disconnect();c=nil end end end)
 end)
end
drag(Head,Win);drag(Open,Open)
select("MAIN")
print("[HAIMIYACH_GAF_V1] loaded")
