--[[
    ===============================================
       GOBEY HUB  .  MY ANIME MINE  .  v1.0
       Delta-Safe  .  Custom Premium UI
    ===============================================
]]

-- =========== SAFE STARTUP ===========
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local RunService        = game:GetService("RunService")

local LP = Players.LocalPlayer
if not LP then
    local t0 = tick()
    repeat task.wait(0.1); LP = Players.LocalPlayer until LP or (tick() - t0) > 15
end
if not LP then warn("GOBEY HUB: LocalPlayer not ready. Execute after spawn."); return end

local PlayerGui = LP:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then PlayerGui = LP:WaitForChild("PlayerGui", 10) end
if not PlayerGui then warn("GOBEY HUB: PlayerGui unavailable."); return end

-- =========== STATE ===========
local S = {
    autoMine=false, autoSell=false, autoEquipBest=false,
    autoResearch=false, autoUpgrade=false, autoBuyPickaxe=false,
    autoCollect=false, autoRebirth=false, autoEnchant=false,
    autoMutation=false, autoSellRarity=false,
    antiAFK=false, autoLagFix=false, autoDeleteMap=false,
    loopDelay=1, sellDelay=3, researchDelay=5,
    sellRarityMin="Common", keepAboveValue=0, sellAtCount=0,
    autoSellFilter="ore",
    -- filters
    fSellRarity={}, fKeepItem={}, fUpgrade={}, fResearch={},
}

local CODES = {}

-- =========== SAFE REQUIRE CACHE ===========
local _requireCache = {}
local function safeRequire(path)
    if _requireCache[path] ~= nil then return _requireCache[path] or nil end
    local result = nil
    pcall(function()
        local parts = {}
        for part in string.gmatch(path, "[^%.]+") do table.insert(parts, part) end
        local cur = ReplicatedStorage
        for i = 1, #parts - 1 do
            cur = cur and cur:FindFirstChild(parts[i])
            if not cur then return end
        end
        if not cur then return end
        local mod = cur:FindFirstChild(parts[#parts])
        if mod then result = require(mod) end
    end)
    _requireCache[path] = result or false
    return result
end

-- =========== REMOTE DISCOVERY ===========
local Remotes, RemoteList, RemoteFns = {}, {}, {}

local function scan(c, prefix)
    if not c then return end
    for _, o in ipairs(c:GetDescendants()) do
        if o:IsA("RemoteEvent") then
            Remotes[o.Name] = o
            table.insert(RemoteList, {name=o.Name, path=prefix..o.Name, obj=o, type="Event"})
        elseif o:IsA("RemoteFunction") then
            RemoteFns[o.Name] = o
            table.insert(RemoteList, {name=o.Name, path=prefix..o.Name, obj=o, type="Function"})
        end
    end
end

local function discover()
    Remotes, RemoteList, RemoteFns = {}, {}, {}
    pcall(scan, ReplicatedStorage, "RS.")
    pcall(scan, Workspace, "WS.")
end

local function findRemotes(kws)
    local out = {}
    for n, r in pairs(Remotes) do
        local ln = string.lower(n)
        for _, kw in ipairs(kws) do
            if string.find(ln, string.lower(kw), 1, true) then
                table.insert(out, r); break
            end
        end
    end
    return out
end

local function fireAll(kws, ...)
    local c = findRemotes(kws)
    if #c == 0 then return false end
    local a = table.pack(...)
    for _, r in ipairs(c) do
        pcall(function() r:FireServer(table.unpack(a, 1, a.n)) end)
    end
    return true
end

-- =========== GUI FALLBACK ===========
local function clickGuiButton(nameKw, textKw)
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local n = string.lower(gui.Name or "")
            local t = gui:IsA("TextButton") and string.lower(gui.Text or "") or ""
            local match = false
            for _, kw in ipairs(nameKw or {}) do
                if string.find(n, string.lower(kw), 1, true) then match = true; break end
            end
            if not match then
                for _, kw in ipairs(textKw or {}) do
                    if string.find(t, string.lower(kw), 1, true) then match = true; break end
                end
            end
            if match then
                pcall(function() gui:Activate() end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
                return true
            end
        end
    end
    return false
end

-- =========== CONTROLLER ADAPTER ===========
local ControllerSignals = {}
local function getSignal(serviceName, signalName)
    local key = serviceName .. ":" .. signalName
    if ControllerSignals[key] then return ControllerSignals[key] end
    local network = safeRequire("Packages.Network")
    if not network or not network.ClientComm then return nil end
    local ok, result = pcall(function()
        local comm = network.ClientComm.new(ReplicatedStorage.Network, false, serviceName)
        return comm:GetSignal(signalName)
    end)
    if ok and result then ControllerSignals[key] = result; return result end
    return nil
end

local function fireSignal(serviceName, signalName, ...)
    local sig = getSignal(serviceName, signalName)
    if not sig then return false end
    return pcall(function() sig:Fire(...) end)
end

-- =========== FEATURE FUNCTIONS ===========

-- Auto Mine: fire remote untuk memulai mining otomatis
local function autoMine()
    -- Coba controller
    local ok = fireSignal("MineService", "StartAutoMine", true)
    if ok then return true end
    -- Coba remote keyword
    if fireAll({"AutoMine","StartMine","Mine","Dig","AutoDig"}, true) then return true end
    -- GUI fallback
    return clickGuiButton({"AutoMine","Mine"}, {"auto mine","mine","dig"})
end

-- Auto Collect: klaim resource otomatis
local function autoCollect()
    local ok = fireSignal("CollectService", "Collect", true)
    if ok then return true end
    if fireAll({"Collect","Claim","CollectAll","ClaimAll"}, true) then return true end
    return clickGuiButton({"Collect","Claim"}, {"collect","claim"})
end

-- Auto Equip Best: equip karakter terbaik ke crew
local function autoEquipBest()
    local ok = fireSignal("CrewService", "EquipBest", true)
    if ok then return true end
    if fireAll({"EquipBest","AutoEquip","Equip","BestEquip"}, true) then return true end
    return clickGuiButton({"EquipBest","Equip"}, {"equip best","auto equip"})
end

-- Auto Sell: jual ore/inventory
local function autoSell()
    local ok = fireSignal("SellService", "SellAll", true)
    if ok then return true end
    if fireAll({"Sell","SellAll","AutoSell","SellOres","SellItems"}, true) then return true end
    return clickGuiButton({"Sell","SellAll"}, {"sell","sell all","jual"})
end

-- Auto Sell by Rarity
local function autoSellByRarity()
    local minRarity = S.sellRarityMin or "Common"
    local ok = fireSignal("SellService", "SellByRarity", minRarity, S.keepAboveValue, S.sellAtCount)
    if ok then return true end
    -- Fallback: cari tombol sell di inventory
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") then
            local t = string.lower(gui.Text or "")
            local n = string.lower(gui.Name or "")
            if (string.find(t, "sell") or string.find(n, "sell")) and
               (string.find(t, "rarity") or string.find(n, "rarity") or string.find(t, "auto")) then
                pcall(function() gui:Activate() end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
                return true
            end
        end
    end
    return false
end

-- Auto Research: beli research otomatis
local function autoResearch()
    local ok = fireSignal("ResearchService", "AutoResearch", true)
    if ok then return true end
    if fireAll({"Research","AutoResearch","BuyResearch","UpgradeResearch"}, true) then return true end
    -- GUI: cari tombol research yang available
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") then
            local t = string.lower(gui.Text or "")
            local n = string.lower(gui.Name or "")
            if (string.find(t, "research") or string.find(n, "research")) and
               not (string.find(t, "locked") or string.find(t, "diblokir")) then
                pcall(function() gui:Activate() end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
                return true
            end
        end
    end
    return false
end

-- Auto Upgrade: beli upgrade damage/pickaxe
local function autoUpgrade()
    local ok = fireSignal("UpgradeService", "AutoUpgrade", true)
    if ok then return true end
    if fireAll({"Upgrade","AutoUpgrade","BuyUpgrade","PurchaseUpgrade"}, true) then return true end
    return clickGuiButton({"Upgrade","Upgrades"}, {"upgrade","beli"})
end

-- Auto Buy Pickaxe: beli palu terbaik yang bisa dibeli
local function autoBuyPickaxe()
    local ok = fireSignal("ShopService", "BuyBestPickaxe", true)
    if ok then return true end
    if fireAll({"BuyPickaxe","BuyPalu","PurchasePickaxe","AutoBuyPickaxe"}, true) then return true end
    -- GUI: cari tombol palu yang tidak locked
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") then
            local t = string.lower(gui.Text or "")
            if string.find(t, "palu") or string.find(t, "pickaxe") or string.find(t, "beli") then
                local isLocked = false
                local parent = gui.Parent
                if parent then
                    for _, child in ipairs(parent:GetDescendants()) do
                        if child:IsA("TextLabel") then
                            local ct = string.lower(child.Text or "")
                            if string.find(ct, "diblokir") or string.find(ct, "locked") then
                                isLocked = true; break
                            end
                        end
                    end
                end
                if not isLocked then
                    pcall(function() gui:Activate() end)
                    pcall(function() firesignal(gui.MouseButton1Click) end)
                    return true
                end
            end
        end
    end
    return false
end

-- Auto Rebirth / Prestige
local function autoRebirth()
    local ok = fireSignal("RebirthService", "Rebirth", true)
    if ok then return true end
    if fireAll({"Rebirth","Prestige","AutoRebirth"}, true) then return true end
    return clickGuiButton({"Rebirth","Prestige"}, {"rebirth","prestige"})
end

-- Auto Enchant
local function autoEnchant()
    local ok = fireSignal("EnchantService", "AutoEnchant", true)
    if ok then return true end
    if fireAll({"Enchant","AutoEnchant","EnchantPickaxe"}, true) then return true end
    return clickGuiButton({"Enchant"}, {"enchant","pesona"})
end

-- Auto Mutation
local function autoMutation()
    local ok = fireSignal("MutationService", "AutoMutation", true)
    if ok then return true end
    if fireAll({"Mutation","AutoMutation","Mutate"}, true) then return true end
    return clickGuiButton({"Mutation"}, {"mutation","mutasi"})
end

-- Redeem Codes
local function redeemCodes()
    if #CODES == 0 then return false end
    local rem = findRemotes({"Redeem","Code","Promo","Gift"})
    if #rem > 0 then
        for _, c in ipairs(CODES) do
            for _, r in ipairs(rem) do pcall(function() r:FireServer(c) end) end
            task.wait(0.5)
        end
        return true
    end
    -- GUI fallback: isi textbox kode
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("TextBox") then
            local ph = string.lower(gui.PlaceholderText or "")
            if string.find(ph, "code") or string.find(ph, "kode") then
                for _, c in ipairs(CODES) do
                    gui.Text = c
                    task.wait(0.2)
                    -- cari tombol confirm
                    for _, btn in ipairs(PlayerGui:GetDescendants()) do
                        if btn:IsA("TextButton") then
                            local t = string.lower(btn.Text or "")
                            if string.find(t, "confirm") or string.find(t, "claim") or string.find(t, "redeem") then
                                pcall(function() btn:Activate() end)
                                pcall(function() firesignal(btn.MouseButton1Click) end)
                                break
                            end
                        end
                    end
                    task.wait(0.5)
                end
                return true
            end
        end
    end
    return false
end

-- Anti AFK
local antiAFKConn = nil
local function startAntiAFK()
    if antiAFKConn then return end
    antiAFKConn = LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end
local function stopAntiAFK()
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
end

-- Server Hop
local function serverHop()
    local servers = {}
    pcall(function()
        local res = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(res)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end
        end
    end)
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1,#servers)], LP)
    else
        notify("Server Hop", "Tidak ada server kosong", 3)
    end
end

-- Performance
local function deleteDeco()
    local deco = {"grass","tree","flower","bush","rock","stone","decor","prop","fence","crate","barrel"}
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if (o:IsA("BasePart") or o:IsA("Model")) and not o:FindFirstChildOfClass("Humanoid") then
            local nm = string.lower(o.Name)
            for _, kw in ipairs(deco) do
                if string.find(nm, kw, 1, true) then
                    pcall(function() o:Destroy(); n = n + 1 end)
                    break
                end
            end
        end
    end
    return n
end

local function disableLighting()
    local n = 0
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("BlurEffect") or o:IsA("BloomEffect") or o:IsA("SunRaysEffect") or
           o:IsA("DepthOfFieldEffect") or o:IsA("Atmosphere") then
            pcall(function() o.Enabled = false; n = n + 1 end)
        end
    end
    return n
end

local function deleteFX()
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or
           o:IsA("Sparkles") or o:IsA("Beam") or o:IsA("Trail") then
            pcall(function() o:Destroy(); n = n + 1 end)
        end
    end
    return n
end

-- =========== NOTIFY ===========
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "GOBEY HUB"),
            Text = tostring(text or ""),
            Duration = tonumber(dur) or 3,
        })
    end)
end

-- ===============================================
--                    UI
-- ===============================================
local ACCENT = Color3.fromRGB(255, 165, 0)  -- Orange (tema mining)
local ACCENT_DARK = Color3.fromRGB(180, 100, 0)
local BG = Color3.fromRGB(12, 13, 18)
local PANEL = Color3.fromRGB(20, 21, 29)
local ITEM = Color3.fromRGB(28, 29, 40)
local TEXT = Color3.fromRGB(240, 240, 248)
local DIM = Color3.fromRGB(150, 151, 170)

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(o,r) return mk("UICorner",{CornerRadius=UDim.new(0,r or 8)},o) end
local function line(o,c,t) return mk("UIStroke",{Color=c or Color3.fromRGB(55,56,72),Thickness=t or 1},o) end

pcall(function()
    local old = PlayerGui:FindFirstChild("GOBEY_HUB_MAM")
    if old then old:Destroy() end
end)

local GUI = mk("ScreenGui",{
    Name="GOBEY_HUB_MAM",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PlayerGui)

local W = mk("Frame",{
    Name="Window",
    Size=UDim2.new(0,540,0,440),
    Position=UDim2.new(0.5,-270,0.5,-220),
    BackgroundColor3=BG,
    BorderSizePixel=0,
},GUI)
corner(W,16); line(W,Color3.fromRGB(55,56,72),1)
local SCALE=mk("UIScale",{Scale=1},W)
local function fitUI()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local v=cam.ViewportSize
    SCALE.Scale=math.clamp(math.min((v.X-10)/540,(v.Y-10)/440),0.62,1)
end
pcall(fitUI)
task.spawn(function()
    while GUI and GUI.Parent do
        task.wait(2)
        pcall(fitUI)
    end
end)

-- Title Bar
local TOP=mk("Frame",{
    Size=UDim2.new(1,0,0,54),BackgroundColor3=PANEL,BorderSizePixel=0,
},W)
corner(TOP,16)
mk("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=ACCENT,BorderSizePixel=0},TOP)
mk("TextLabel",{
    Size=UDim2.new(1,-120,0,23),Position=UDim2.new(0,16,0,7),
    BackgroundTransparency=1,Text="GOBEY HUB",TextColor3=TEXT,
    Font=Enum.Font.GothamBlack,TextSize=17,TextXAlignment=Enum.TextXAlignment.Left,
},TOP)
mk("TextLabel",{
    Size=UDim2.new(1,-120,0,15),Position=UDim2.new(0,17,0,31),
    BackgroundTransparency=1,Text="MY ANIME MINE  |  AUTO FARM",TextColor3=ACCENT,
    Font=Enum.Font.GothamBold,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left,
},TOP)

local function topButton(text,x,color,cb)
    local b=mk("TextButton",{
        Size=UDim2.new(0,32,0,32),Position=UDim2.new(1,x,0.5,-16),
        BackgroundColor3=ITEM,BorderSizePixel=0,Text=text,TextColor3=color,
        Font=Enum.Font.GothamBold,TextSize=13,AutoButtonColor=false,
    },TOP)
    corner(b,9); b.MouseButton1Click:Connect(cb); return b
end

local reopen=mk("TextButton",{
    Name="Reopen",Size=UDim2.new(0,42,0,30),
    Position=UDim2.new(0.5,-21,0,8),BackgroundColor3=ACCENT_DARK,
    BorderSizePixel=0,Text="G",TextColor3=TEXT,Font=Enum.Font.GothamBlack,TextSize=13,
    Visible=false,AutoButtonColor=false,
},GUI)
corner(reopen,10)

topButton("_",-76,Color3.fromRGB(245,205,90),function()
    W.Visible=false; reopen.Visible=true
end)
topButton("X",-38,Color3.fromRGB(255,95,105),function() GUI:Destroy() end)
reopen.MouseButton1Click:Connect(function() W.Visible=true; reopen.Visible=false end)

-- Sidebar
local RAIL=mk("ScrollingFrame",{
    Size=UDim2.new(0,118,1,-70),Position=UDim2.new(0,10,0,62),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,
    ScrollBarImageColor3=ACCENT,CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
},W)
mk("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},RAIL)

local BODY=mk("Frame",{
    Size=UDim2.new(1,-140,1,-70),Position=UDim2.new(0,130,0,62),
    BackgroundColor3=PANEL,BorderSizePixel=0,
},W)
corner(BODY,12); line(BODY,Color3.fromRGB(48,49,64),1)

local Pages,TabBtns={},{}
local function createTab(name)
    local b=mk("TextButton",{
        Size=UDim2.new(1,-2,0,38),BackgroundColor3=ITEM,
        BorderSizePixel=0,Text=name,TextColor3=DIM,
        Font=Enum.Font.GothamBold,TextSize=10,AutoButtonColor=false,
    },RAIL)
    corner(b,9)
    local p=mk("ScrollingFrame",{
        Size=UDim2.new(1,-14,1,-14),Position=UDim2.new(0,7,0,7),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        ScrollBarImageColor3=ACCENT,CanvasSize=UDim2.new(0,0,0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false,
    },BODY)
    mk("UIListLayout",{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},p)
    mk("UIPadding",{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,4)},p)
    b.MouseButton1Click:Connect(function()
        for _,pg in pairs(Pages) do pg.Visible=false end
        for _,tb in pairs(TabBtns) do tb.BackgroundColor3=ITEM; tb.TextColor3=DIM end
        p.Visible=true; b.BackgroundColor3=ACCENT_DARK; b.TextColor3=TEXT
    end)
    Pages[name]=p; TabBtns[name]=b
    return p
end

-- Components
local function section(page,title)
    local f=mk("Frame",{Size=UDim2.new(1,0,0,27),BackgroundTransparency=1},page)
    mk("Frame",{Size=UDim2.new(0,3,0,14),Position=UDim2.new(0,3,0.5,-7),BackgroundColor3=ACCENT,BorderSizePixel=0},f)
    mk("TextLabel",{Size=UDim2.new(1,-14,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=title,TextColor3=ACCENT,Font=Enum.Font.GothamBlack,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},f)
end

local function label(page,text,h)
    local l=mk("TextLabel",{Size=UDim2.new(1,0,0,h or 42),BackgroundColor3=ITEM,BorderSizePixel=0,Text=text,TextColor3=DIM,Font=Enum.Font.Gotham,TextSize=9,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},page)
    corner(l,9); mk("UIPadding",{PaddingLeft=UDim.new(0,11),PaddingRight=UDim.new(0,11)},l); return l
end

local function button(page,text,cb)
    local b=mk("TextButton",{Size=UDim2.new(1,0,0,39),BackgroundColor3=ITEM,BorderSizePixel=0,Text=text,TextColor3=TEXT,Font=Enum.Font.GothamBold,TextSize=10,AutoButtonColor=false},page)
    corner(b,9); line(b,Color3.fromRGB(49,50,66),1)
    b.MouseButton1Click:Connect(function() if cb then task.spawn(function() pcall(cb) end) end end)
    return b
end

local function toggle(page,text,default,cb)
    local v=default and true or false
    local row=mk("Frame",{Size=UDim2.new(1,0,0,43),BackgroundColor3=ITEM,BorderSizePixel=0},page)
    corner(row,9)
    mk("TextLabel",{Size=UDim2.new(1,-72,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text=text,TextColor3=TEXT,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left},row)
    local hit=mk("TextButton",{Size=UDim2.new(0,48,0,25),Position=UDim2.new(1,-59,0.5,-12),BackgroundColor3=v and ACCENT or Color3.fromRGB(52,53,68),BorderSizePixel=0,Text="",AutoButtonColor=false},row)
    corner(hit,14)
    local knob=mk("Frame",{Size=UDim2.new(0,19,0,19),Position=v and UDim2.new(1,-22,0.5,-9) or UDim2.new(0,3,0.5,-9),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},hit); corner(knob,10)
    local function set(n)
        v=not not n; hit.BackgroundColor3=v and ACCENT or Color3.fromRGB(52,53,68)
        knob.Position=v and UDim2.new(1,-22,0.5,-9) or UDim2.new(0,3,0.5,-9)
    end
    hit.MouseButton1Click:Connect(function() set(not v); if cb then task.spawn(function() pcall(cb,v) end) end end)
    return {Set=set,Get=function() return v end}
end

local function slider(page,title,min,max,default,cb)
    min=min or 0; max=max or 100; local value=math.clamp(default or min,min,max)
    local row=mk("Frame",{Size=UDim2.new(1,0,0,54),BackgroundColor3=ITEM,BorderSizePixel=0},page); corner(row,9)
    mk("TextLabel",{Size=UDim2.new(.72,0,0,20),Position=UDim2.new(0,11,0,6),BackgroundTransparency=1,Text=title,TextColor3=TEXT,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left},row)
    local val=mk("TextLabel",{Size=UDim2.new(.25,0,0,20),Position=UDim2.new(.72,-6,0,6),BackgroundTransparency=1,Text=string.format("%.2f",value),TextColor3=ACCENT,Font=Enum.Font.GothamBold,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right},row)
    local bar=mk("TextButton",{Size=UDim2.new(1,-22,0,7),Position=UDim2.new(0,11,0,36),BackgroundColor3=Color3.fromRGB(16,17,24),BorderSizePixel=0,Text="",AutoButtonColor=false},row); corner(bar,6)
    local fill=mk("Frame",{Size=UDim2.new((value-min)/(max-min),0,1,0),BackgroundColor3=ACCENT,BorderSizePixel=0},bar); corner(fill,6)
    local dragging=false
    local function setX(x)
        local w=math.max(1,bar.AbsoluteSize.X); local pct=math.clamp((x-bar.AbsolutePosition.X)/w,0,1)
        value=min+(max-min)*pct
        if max-min>=5 then value=math.floor(value+.5) end
        fill.Size=UDim2.new(pct,0,1,0); val.Text=string.format("%.2f",value)
        if cb then task.spawn(function() pcall(cb,value) end) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setX(input.Position.X)
            input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then setX(input.Position.X) end
    end)
    return {Set=function(v) value=math.clamp(v,min,max); fill.Size=UDim2.new((value-min)/(max-min),0,1,0); val.Text=string.format("%.2f",value) end,Get=function() return value end}
end

local ddCounter=0
local OpenPopup=nil
local function closePopup()
    if OpenPopup then pcall(function() OpenPopup:Destroy() end); OpenPopup=nil end
end
local function dropdown(page,title,options,default,multi,cb)
    options=options or {}
    local selected={}; local current=default
    if multi and type(default)=="table" then
        for k,v in pairs(default) do if v==true then selected[k]=true elseif type(v)=="string" then selected[v]=true end end
    elseif not multi and default then current=default end
    local row=mk("Frame",{Size=UDim2.new(1,0,0,45),BackgroundColor3=ITEM,BorderSizePixel=0},page); corner(row,9)
    mk("TextLabel",{Size=UDim2.new(.43,-8,1,0),Position=UDim2.new(0,11,0,0),BackgroundTransparency=1,Text=title,TextColor3=TEXT,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left},row)
    local btn=mk("TextButton",{Size=UDim2.new(.57,-12,0,29),Position=UDim2.new(.43,3,.5,-14),BackgroundColor3=Color3.fromRGB(19,20,27),BorderSizePixel=0,Text="",AutoButtonColor=false},row); corner(btn,7)
    local txt=mk("TextLabel",{Size=UDim2.new(1,-26,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,TextColor3=DIM,Text="-",Font=Enum.Font.GothamBold,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},btn)
    mk("TextLabel",{Size=UDim2.new(0,18,1,0),Position=UDim2.new(1,-19,0,0),BackgroundTransparency=1,Text="+",TextColor3=ACCENT,Font=Enum.Font.GothamBold,TextSize=12},btn)
    local function summary()
        if multi then
            local a={}; for k,on in pairs(selected) do if on then table.insert(a,k) end end
            table.sort(a); txt.Text=(#a==0 and "None" or (#a==1 and a[1] or tostring(#a).." selected"))
        else txt.Text=tostring(current or "None") end
    end
    local function refresh(newOptions,keep)
        options=newOptions or {}; if not keep then selected={}; current=nil end; summary()
    end
    btn.MouseButton1Click:Connect(function()
        closePopup()
        local popup=mk("Frame",{Size=UDim2.new(0,math.max(190,math.floor(row.AbsoluteSize.X*.57)),0,180),BackgroundColor3=Color3.fromRGB(16,17,23),BorderSizePixel=0,ZIndex=8000},GUI)
        corner(popup,9); line(popup,ACCENT,1); OpenPopup=popup
        local pos=row.AbsolutePosition; local sz=row.AbsoluteSize
        popup.Position=UDim2.fromOffset(pos.X+sz.X*0.43,pos.Y+sz.Y+4)
        local list=mk("ScrollingFrame",{Size=UDim2.new(1,-8,1,-8),Position=UDim2.new(0,4,0,4),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=ACCENT,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=8001},popup)
        mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},list)
        for _,opt in ipairs(options) do
            local name=tostring(opt); local on=multi and selected[name] or current==name
            local ob=mk("TextButton",{Size=UDim2.new(1,0,0,31),BackgroundColor3=on and ACCENT_DARK or ITEM,BorderSizePixel=0,Text=(on and "[x] " or "[ ] ")..name,TextColor3=TEXT,Font=Enum.Font.Gotham,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,ZIndex=8002},list); corner(ob,7)
            ob.MouseButton1Click:Connect(function()
                if multi then selected[name]=not selected[name]; ob.BackgroundColor3=selected[name] and ACCENT_DARK or ITEM; ob.Text=(selected[name] and "[x] " or "[ ] ")..name
                else current=name; summary(); closePopup(); if cb then task.spawn(function() pcall(cb,current) end) end; return end
                summary(); if cb then task.spawn(function() pcall(cb,selected) end) end
            end)
        end
    end)
    summary()
    return {
        Refresh = function(newOptions, keep) refresh(newOptions, keep) end,
        Set = function(v) if multi then selected=type(v)=="table" and v or {} else current=v end; summary() end,
        Get = function() return multi and selected or current end,
    }
end

-- ===============================================
--                    TABS
-- ===============================================
local tabMain=createTab("MAIN")
local tabAuto=createTab("AUTO")
local tabSell=createTab("SELL")
local tabResearch=createTab("RESEARCH")
local tabMisc=createTab("MISC")
local tabPerf=createTab("PERF")
local tabDebug=createTab("DEBUG")

-- MAIN TAB
section(tabMain,"AUTO MINE")
toggle(tabMain,"Auto Mine",S.autoMine,function(v) S.autoMine=v; if v then autoMine() end end)
toggle(tabMain,"Auto Collect",S.autoCollect,function(v) S.autoCollect=v; if v then autoCollect() end end)
toggle(tabMain,"Auto Equip Best",S.autoEquipBest,function(v) S.autoEquipBest=v; if v then autoEquipBest() end end)
slider(tabMain,"Loop Delay",0.2,5,S.loopDelay,function(v) S.loopDelay=v end)

section(tabMain,"AUTO UPGRADE")
toggle(tabMain,"Auto Upgrade",S.autoUpgrade,function(v) S.autoUpgrade=v end)
toggle(tabMain,"Auto Buy Pickaxe",S.autoBuyPickaxe,function(v) S.autoBuyPickaxe=v end)
toggle(tabMain,"Auto Enchant",S.autoEnchant,function(v) S.autoEnchant=v end)
toggle(tabMain,"Auto Mutation",S.autoMutation,function(v) S.autoMutation=v end)
toggle(tabMain,"Auto Rebirth",S.autoRebirth,function(v) S.autoRebirth=v end)

-- AUTO TAB
section(tabAuto,"MINING")
toggle(tabAuto,"Auto Mine",S.autoMine,function(v) S.autoMine=v end)
toggle(tabAuto,"Auto Collect",S.autoCollect,function(v) S.autoCollect=v end)
toggle(tabAuto,"Auto Equip Best",S.autoEquipBest,function(v) S.autoEquipBest=v end)

section(tabAuto,"UPGRADE")
toggle(tabAuto,"Auto Upgrade",S.autoUpgrade,function(v) S.autoUpgrade=v end)
toggle(tabAuto,"Auto Buy Pickaxe",S.autoBuyPickaxe,function(v) S.autoBuyPickaxe=v end)
toggle(tabAuto,"Auto Enchant",S.autoEnchant,function(v) S.autoEnchant=v end)
toggle(tabAuto,"Auto Mutation",S.autoMutation,function(v) S.autoMutation=v end)
toggle(tabAuto,"Auto Rebirth",S.autoRebirth,function(v) S.autoRebirth=v end)

-- SELL TAB
section(tabSell,"AUTO SELL")
toggle(tabSell,"Auto Sell",S.autoSell,function(v) S.autoSell=v end)
toggle(tabSell,"Auto Sell by Rarity",S.autoSellRarity,function(v) S.autoSellRarity=v end)
slider(tabSell,"Sell Delay",1,15,S.sellDelay,function(v) S.sellDelay=v end)

section(tabSell,"SELL FILTER")
dropdown(tabSell,"Min Rarity",{"Common","Uncommon","Rare","Epic","Legendary","Mythic","Godly","Divine","Secret"},S.sellRarityMin,false,function(v) S.sellRarityMin=v end)
slider(tabSell,"Keep Above Value",0,1000000,S.keepAboveValue,function(v) S.keepAboveValue=v end)
slider(tabSell,"Sell at Item Count",0,500,S.sellAtCount,function(v) S.sellAtCount=v end)
button(tabSell,"Sell Sekarang",autoSell)
button(tabSell,"Sell by Rarity Sekarang",autoSellByRarity)

-- RESEARCH TAB
section(tabResearch,"AUTO RESEARCH")
toggle(tabResearch,"Auto Research",S.autoResearch,function(v) S.autoResearch=v end)
slider(tabResearch,"Research Delay",2,30,S.researchDelay,function(v) S.researchDelay=v end)
button(tabResearch,"Research Sekarang",autoResearch)

section(tabResearch,"RESEARCH LIST")
local researchLabel = label(tabResearch,"Research akan terdeteksi otomatis.",100)

-- MISC TAB
section(tabMisc,"QUEST & CODES")
toggle(tabMisc,"Auto Claim Quest",S.autoCollect,function(v) S.autoCollect=v end)

section(tabMisc,"CODES")
local codesBox=mk("TextBox",{Size=UDim2.new(1,0,0,38),BackgroundColor3=ITEM,BorderSizePixel=0,PlaceholderText="code1,code2,...",Text="",TextColor3=TEXT,PlaceholderColor3=DIM,Font=Enum.Font.Gotham,TextSize=10,ClearTextOnFocus=false},tabMisc); corner(codesBox,9)
codesBox.FocusLost:Connect(function()
    CODES={}
    for c in string.gmatch(codesBox.Text or "","[^,]+") do
        local t=c:gsub("^%s+",""):gsub("%s+$","")
        if t~="" then table.insert(CODES,t) end
    end
end)

button(tabMisc,"Redeem Sekarang",function()
    if #CODES>0 then redeemCodes() else notify("Codes","Isi kode dulu",2) end
end)

section(tabMisc,"UTILITY")
toggle(tabMisc,"Anti AFK",S.antiAFK,function(v)
    S.antiAFK=v
    if v then startAntiAFK() else stopAntiAFK() end
end)
button(tabMisc,"Server Hop",serverHop)

-- PERF TAB
section(tabPerf,"PERFORMANCE")
toggle(tabPerf,"Auto Lag Fix",S.autoLagFix,function(v) S.autoLagFix=v end)
button(tabPerf,"Delete Decorations",function()
    local n=deleteDeco(); notify("Clean","-"..n.." deco",2)
end)
button(tabPerf,"Delete FX / Particles",function()
    local n=deleteFX(); notify("Clean","-"..n.." FX",2)
end)
button(tabPerf,"Disable Lighting",function()
    local n=disableLighting(); notify("Clean","-"..n.." effects",2)
end)

-- DEBUG TAB
section(tabDebug,"REMOTES")
local debugLabel=label(tabDebug,"Remote list akan muncul setelah scan.",200)
local function refreshDebug()
    local lines={"Remotes: "..#RemoteList}
    for i,r in ipairs(RemoteList) do
        if i>40 then table.insert(lines,"... +"..(#RemoteList-40).." more"); break end
        table.insert(lines,"["..r.type.."] "..r.path)
    end
    debugLabel.Text=table.concat(lines,"\n")
end
button(tabDebug,"Re-scan Remotes",function() discover(); refreshDebug(); notify("Debug",#RemoteList.." remotes",2) end)
button(tabDebug,"Dump to Console",function()
    print("=== GOBEY MAM REMOTES ===")
    for i,r in ipairs(RemoteList) do print("["..i.."] ("..r.type..") "..r.path) end
    print("=== END ===")
    notify("Debug","Console dumped",2)
end)

-- Drag Window
local drag=false; local dragStart=nil; local startPos=nil
TOP.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        drag=true; dragStart=input.Position; startPos=W.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if drag and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart
        W.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag=false end
end)

Pages.MAIN.Visible=true; TabBtns.MAIN.BackgroundColor3=ACCENT_DARK; TabBtns.MAIN.TextColor3=TEXT

-- =========== DELAYED DISCOVERY ===========
task.spawn(function()
    task.wait(1)
    pcall(discover)
    pcall(refreshDebug)
end)

-- =========== MAIN LOOP ===========
task.spawn(function()
    while true do
        task.wait(S.loopDelay)
        if S.autoMine then pcall(autoMine) end
        if S.autoCollect then pcall(autoCollect) end
        if S.autoEquipBest then pcall(autoEquipBest) end
        if S.autoUpgrade then pcall(autoUpgrade) end
        if S.autoBuyPickaxe then pcall(autoBuyPickaxe) end
        if S.autoEnchant then pcall(autoEnchant) end
        if S.autoMutation then pcall(autoMutation) end
        if S.autoRebirth then pcall(autoRebirth) end
        if S.autoResearch then pcall(autoResearch) end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.sellDelay or 3)
        if S.autoSell then pcall(autoSell) end
        if S.autoSellRarity then pcall(autoSellByRarity) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.antiAFK then pcall(startAntiAFK) end
        if S.autoLagFix then
            pcall(deleteDeco); pcall(disableLighting)
            task.wait(8)
        end
    end
end)

-- =========== NOTIFY ===========
task.spawn(function()
    task.wait(1)
    notify("GOBEY HUB MAM", "Loaded! "..#RemoteList.." remotes", 5)
    print("[GOBEY HUB MAM] Loaded. Remotes: "..#RemoteList)
end)