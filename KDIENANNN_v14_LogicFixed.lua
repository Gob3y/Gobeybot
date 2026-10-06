--[[
    ===============================================
       GOBEY HUB  .  ANIME DICE  .  v5.2 (Delta-Safe)
       Custom Premium UI  .  Controller Adapter
    ===============================================
]]

-- =========== SERVICES ===========
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- Anime Dice place guard.  Do not run the controller adapter in another game.
if game.PlaceId ~= 113290951185459 then
    warn("GOBEY HUB: Anime Dice only (PlaceId 113290951185459)")
    return
end
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")

-- =========== SAFE STARTUP ===========
local LP = Players.LocalPlayer
if not LP then
    local t0 = tick()
    repeat
        task.wait(0.1)
        LP = Players.LocalPlayer
    until LP or (tick() - t0) > 15
end
if not LP then
    warn("GOBEY HUB: LocalPlayer tidak tersedia setelah 15 detik. Execute ulang setelah spawn.")
    return
end

local PlayerGui = LP:FindFirstChildOfClass("PlayerGui")
if not PlayerGui then
    PlayerGui = LP:WaitForChild("PlayerGui", 10)
end
if not PlayerGui then
    warn("GOBEY HUB: PlayerGui tidak tersedia. Karakter mungkin belum spawn.")
    return
end

-- =========== SAFE REQUIRE CACHE ===========
local _requireCache = {}
local function safeRequire(folderPath)
    if _requireCache[folderPath] ~= nil then
        return _requireCache[folderPath] or nil
    end
    local result = nil
    pcall(function()
        local parts = {}
        for part in string.gmatch(folderPath, "[^%.]+") do
            table.insert(parts, part)
        end
        local cur = ReplicatedStorage
        for i = 1, #parts - 1 do
            cur = cur and cur:FindFirstChild(parts[i])
            if not cur then return end
        end
        if not cur then return end
        local mod = cur:FindFirstChild(parts[#parts])
        if mod then result = require(mod) end
    end)
    if result ~= nil then
        _requireCache[folderPath] = result
    end
    return result
end

-- =========== STATE ===========
local S = {
    buyBestDice=false, collectCash=false, placeBest=false,
    autoRoll=false, equipBestDice=false, useSpins=false, useBoosts=false,
    lockValuables=false, claimOffline=false, claimGroup=false,
    levelUnits=false, sellUnits=false, fuseMode=false,
    rollGrade=false, traitRoll=false, rebirth=false,
    buyUpgrades=false, claimQuest=false, redeemCodes=false,
    tower=false, shop=false, equipBest=false, statUp=false,
    potion=false, gear=false, spin=false, dailyReward=false,
    towerTeam=false, luckBoost=false,
    disableCutscene=false, skipRollCutscene=false,
    autoLagFix=false, autoDeleteMap=false, antiAFK=false,
    loopDelay=1, towerRotateDelay=3, lagFixInterval=8,
    rollDelay=1, boostType="Luck",
    deleteMapInterval=15, fuseModeType="lowest_earnings", fuseIgnoreRarity="",
    deleteMapMode="safe",
    fDice={}, fLevel={}, fSell={}, fGrade={}, fTrait={}, fStat={},
    fRoll={}, fTower={}, fQuest={}, fShop={}, fUpgrade={},
    fTraitTarget={}, fGradeTarget={}, fStatType={}, fFuse={},
}

local CODES = {}

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

-- =========== GAME CONTROLLER ADAPTERS ===========
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
    if ok and result then
        ControllerSignals[key] = result
        return result
    end
    return nil
end

local function fireSignal(serviceName, signalName, ...)
    local sig = getSignal(serviceName, signalName)
    if not sig then return false end
    return pcall(function() sig:Fire(...) end)
end

local function callControllerFunction(serviceName, functionName, ...)
    local network = safeRequire("Packages.Network")
    if not network or not network.ClientComm then return false, nil end
    local ok, result = pcall(function()
        local comm = network.ClientComm.new(ReplicatedStorage.Network, false, serviceName)
        local fn = comm:GetFunction(functionName)
        return fn(...)
    end)
    return ok, result
end

local function controllerAction(name, ...)
    if name == "AutoRoll" then return fireSignal("RollService", "SetAutoRoll", ...) end
    if name == "Collect" then return fireSignal("PlotService", "CollectBalance", ...) end
    if name == "EquipBest" then return fireSignal("PlotService", "EquipBest", ...) end
    if name == "BuyDice" then return fireSignal("DiceShopService", "BuyDice", ...) end
    if name == "EquipDice" then return fireSignal("DiceShopService", "EquipDice", ...) end
    if name == "Rebirth" then return fireSignal("RebirthService", "Rebirth", ...) end
    if name == "Daily" then return fireSignal("DailyRewardService", "Claim", ...) end
    if name == "Offline" then return fireSignal("OfflineEarningsService", "Claim", ...) end
    if name == "Group" then return fireSignal("GroupRewardService", "Claim", ...) end
    if name == "Spin" then return fireSignal("SpinService", "Use", ...) end
    if name == "Boost" then return fireSignal("BoostService", "Use", ...) end
    if name == "Grade" then return fireSignal("GradeService", "Roll", ...) end
    if name == "Trait" then return fireSignal("TraitService", "Roll", ...) end
    if name == "Fuse" then return fireSignal("FusingService", "Fuse", ...) end
    if name == "QuestClaim" then return fireSignal("QuestService", "Claim", ...) end
    if name == "TowerBest" then return fireSignal("Towers", "EquipBestTowerTeam", ...) end
    if name == "TowerTeam" then return fireSignal("Towers", "UpdateTowerTeam", ...) end
    if name == "LevelUpSlot" then return fireSignal("PlotService", "LevelUpSlot", ...) end
    return false
end

local function findInventoryKeysByKind(kindName)
    local result = {}
    local dc = safeRequire("Framework.Features.Data.DataController")
    local registry = safeRequire("Framework.Features.Inventory.EntryRegistry")
    if not dc or not registry then return result end
    pcall(function()
        for key, item in dc.Inventory() do
            local cfg = registry.getEntryConfig(item.name)
            if cfg and cfg.kind == kindName and (tonumber(item.amount) or 0) > 0 then
                table.insert(result, {key=key, name=item.name, data=item})
            end
        end
    end)
    return result
end

local function findModuleByName(name)
    local found = nil
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("ModuleScript") and obj.Name == name then
                found = obj
                break
            end
        end
    end)
    return found
end

local function requireModuleByName(name)
    local cached = _requireCache["__module:"..name]
    if cached ~= nil then return cached or nil end
    local m = findModuleByName(name)
    if not m then
            return nil
    end
    local ok, result = pcall(require, m)
    if ok and result ~= nil then
        _requireCache["__module:"..name] = result
        return result
    end
    return nil
end

local function getInventoryUnitEntries()
    local result = {}
    local dc = safeRequire("Framework.Features.Data.DataController")
    local registry = safeRequire("Framework.Features.Inventory.EntryRegistry")
    if not dc or not registry then return result end
    pcall(function()
        for key, item in dc.Inventory() do
            local cfg = registry.getEntryConfig(item.name)
            if cfg and cfg.kind == "Unit" then
                table.insert(result, {key=tostring(key), name=tostring(item.name), data=item, cfg=cfg})
            end
        end
    end)
    table.sort(result, function(a,b)
        local an, bn = string.lower(a.name), string.lower(b.name)
        if an == bn then return a.key < b.key end
        return an < bn
    end)
    return result
end

local function unitOptionLabel(item)
    local suffix = tostring(item.key)
    if #suffix > 6 then suffix = string.sub(suffix, -6) end
    return item.name .. "  [" .. suffix .. "]"
end

local UnitOptionMap = {}
local function getUnitSelectorOptions()
    UnitOptionMap = {}
    local options = {}
    for _, item in ipairs(getInventoryUnitEntries()) do
        local label = unitOptionLabel(item)
        while UnitOptionMap[label] do label = label .. " " end
        UnitOptionMap[label] = item.key
        table.insert(options, label)
    end
    if #options == 0 then options = {"(inventory unit belum terdeteksi)"} end
    return options
end

local function selectedUnitKeys(filter)
    local all = getInventoryUnitEntries()
    if type(filter) ~= "table" or not next(filter) then
        local out = {}
        for _, item in ipairs(all) do table.insert(out, item.key) end
        return out
    end
    local out, seen = {}, {}
    for value, on in pairs(filter) do
        if on and UnitOptionMap[value] then
            local key = UnitOptionMap[value]
            if not seen[key] then seen[key] = true; table.insert(out, key) end
        elseif on then
            for _, item in ipairs(all) do
                if item.key == tostring(value) and not seen[item.key] then
                    seen[item.key] = true; table.insert(out, item.key)
                end
            end
        end
    end
    return out
end

local function getInventoryUnitByKey(key)
    local dc = safeRequire("Framework.Features.Data.DataController")
    if not dc then return nil end
    local ok, item = pcall(function() return dc.Inventory[key]() end)
    return ok and item or nil
end

local function getCurrentUnitAttribute(key, attr)
    local item = getInventoryUnitByKey(key)
    if not item or not item.attributes then return nil end
    local value = item.attributes[attr]
    if type(value) == "function" then
        local ok, result = pcall(value)
        if ok then return result end
    end
    return value
end

local function getSlotForUnitKey(unitKey)
    local dc = safeRequire("Framework.Features.Data.DataController")
    if not dc then return nil end
    local found = nil
    pcall(function()
        for slot, data in dc.Slots() do
            if data and tostring(data.unitId or "") == tostring(unitKey) then
                found = tonumber(slot) or slot
                break
            end
        end
    end)
    return found
end

local function autoEquipBestDiceController()
    local dc = safeRequire("Framework.Features.Data.DataController")
    local dice = safeRequire("Framework.Features.Inventory.Kinds.Dice.Dice")
    if not dc or not dice then return false end
    local best, bestLuck = nil, -math.huge
    pcall(function()
        for name, cfg in pairs(dice.GetAll()) do
            if dc.OwnedDice[name]() and (tonumber(cfg.luck) or 0) > bestLuck then
                best, bestLuck = name, tonumber(cfg.luck) or 0
            end
        end
    end)
    if best then return controllerAction("EquipDice", best) end
    return false
end

local function autoUseAvailableSpins()
    local spins = findInventoryKeysByKind("Spin")
    local did = false
    for _, item in ipairs(spins) do
        did = controllerAction("Spin", item.key) or did
    end
    return did
end

local function autoUseAvailableBoosts()
    local boosts = findInventoryKeysByKind("Boost")
    local did = false
    for _, item in ipairs(boosts) do
        did = controllerAction("Boost", item.key) or did
    end
    return did
end

local function autoClaimRewardsController()
    local did = false
    did = controllerAction("Daily") or did
    did = controllerAction("Offline") or did
    did = controllerAction("Group") or did
    return did
end

local function autoEquipBestController()
    return controllerAction("EquipBest")
end

local function autoRollController(enabled)
    return controllerAction("AutoRoll", enabled)
end

local function autoLockValuablesController()
    local dc = safeRequire("Framework.Features.Data.DataController")
    local registry = safeRequire("Framework.Features.Inventory.EntryRegistry")
    if not dc or not registry then return false end
    local sig = getSignal("UnitService", "SetLocked")
    if not sig then return false end
    local protected = {}
    local rarityRank = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Godly=7,Divine=8,Secret=9}
    local changed = false
    pcall(function()
        for key, item in dc.Inventory() do
            local cfg = registry.getEntryConfig(item.name)
            if cfg and cfg.kind == "Unit" then
                local rarity = item.attributes and item.attributes.rarity or item.attributes and item.attributes.grade
                local rank = rarityRank[tostring(rarity or "Common")] or 1
                if rank >= 5 and not (item.attributes and item.attributes.locked) then
                    protected[key] = true
                end
            end
        end
        if next(protected) then sig:Fire(protected); changed = true end
    end)
    return changed
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

-- =========== UTILITIES ===========
local function getPlot()
    for _, name in ipairs({"Plots","PlotFolder","Plot","PlotsFolder"}) do
        local p = Workspace:FindFirstChild(name)
        if p then
            for _, plot in ipairs(p:GetChildren()) do
                local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerUserId") or plot:GetAttribute("UserId")
                if owner == LP.UserId then return plot end
            end
        end
    end
    return nil
end

local function scanRS(names)
    local out, seen = {}, {}
    pcall(function()
        for _, fn in ipairs(names) do
            local f = ReplicatedStorage:FindFirstChild(fn)
            if f then
                for _, c in ipairs(f:GetDescendants()) do
                    if not seen[c.Name] and (c:IsA("ModuleScript") or c:IsA("Folder") or c:IsA("Configuration") or c:IsA("StringValue")) then
                        seen[c.Name] = true; table.insert(out, c.Name)
                    end
                end
            end
        end
    end)
    table.sort(out)
    return out
end

local function getUnitNames()
    return getUnitSelectorOptions()
end

local function getTowerData()
    local towers = requireModuleByName("Towers")
    if towers then
        local ok, all = pcall(function() return towers.GetAll() end)
        if ok and type(all) == "table" then return all end
    end
    return {}
end

local function getTowerList()
    local all = getTowerData()
    local out = {}
    for name in pairs(all) do table.insert(out, tostring(name)) end
    table.sort(out)
    if #out == 0 then out = scanRS({"Towers","TowerData","Tower","Modes","Stages"}) end
    if #out == 0 then out = {"(tower belum terdeteksi)"} end
    return out
end

local function getDiceList()
    local out, seen = {}, {}
    pcall(function()
        local dice = safeRequire("Framework.Features.Inventory.Kinds.Dice.Dice")
        if dice then
            for name in pairs(dice.GetAll()) do
                if not seen[name] then seen[name]=true; table.insert(out, name) end
            end
        end
    end)
    if #out == 0 then out = scanRS({"Dice","Dices","DiceData"}) end
    table.sort(out)
    if #out == 0 then out = {"(dice belum terdeteksi)"} end
    return out
end

local function getRarityList()
    return {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret","Exclusive"}
end

local function getGradeList()
    return {"D","C","B","A","S","S+","SS","SSS","UR","LR"}
end

local function getTraitList()
    return {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Godly","Divine"}
end

local function getStatList()
    return {"Damage","Income","Speed","Range","Luck","Health"}
end

local function getQuestList()
    return {"Daily","Weekly","Main","Event"}
end

local function getShopList()
    return {"Shop 1","Shop 2","Shop 3"}
end

local function getUpgradeList()
    return {"Money","Luck","Speed","Slot","Team Size"}
end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "GOBEY HUB"),
            Text = tostring(text or ""),
            Duration = tonumber(dur) or 3,
        })
    end)
end

-- =========== ANTI AFK ===========
local antiAFKConn, antiAFKJump = nil, nil

local function startAntiAFK()
    if antiAFKConn then return end
    antiAFKConn = LP.Idled:Connect(function()
        pcall(function()
            if VirtualUser then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end)
    end)
    antiAFKJump = task.spawn(function()
        while antiAFKConn do
            task.wait(60)
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true; task.wait(0.1); hum.Jump = false end
            end)
        end
    end)
end

local function stopAntiAFK()
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    antiAFKJump = nil
end

-- =========== FEATURE FUNCTIONS ===========
local function autoCollect() return controllerAction("Collect") end
local function autoRebirth() return controllerAction("Rebirth") end
local function autoEquipBest() return autoEquipBestController() or autoEquipBestDiceController() end
local function autoSpin() return autoUseAvailableSpins() end
local function autoDaily() return autoClaimRewardsController() end

local function autoBuyDice()
    local picks = {}
    for name, on in pairs(S.fDice or {}) do if on then table.insert(picks, name) end end
    if #picks == 0 then picks = getDiceList() end
    local did = false
    for _, d in ipairs(picks) do
        did = controllerAction("BuyDice", d) or did
    end
    return did
end

local function autoFuseMode()
    local entries = getInventoryUnitEntries()
    if #entries < 3 then return false end
    local rarityRank = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Godly=7,Divine=8,Secret=9}
    local maxRank = 999
    if S.fuseIgnoreRarity ~= "" then maxRank = rarityRank[S.fuseIgnoreRarity] or 999 end
    local candidates = {}
    for _, item in ipairs(entries) do
        local rar = getCurrentUnitAttribute(item.key, "rarity") or getCurrentUnitAttribute(item.key, "grade") or "Common"
        if (rarityRank[tostring(rar)] or 1) <= maxRank then
            table.insert(candidates, item)
        end
    end
    local selected = selectedUnitKeys(S.fFuse)
    if #selected >= 3 then
        local selectedSet = {}
        for _, key in ipairs(selected) do selectedSet[key] = true end
        local manual = {}
        for _, item in ipairs(candidates) do
            if selectedSet[item.key] then table.insert(manual, item) end
        end
        if #manual >= 3 then candidates = manual end
    end
    local function num(key, attr, fallback)
        local v = tonumber(getCurrentUnitAttribute(key, attr))
        return v or fallback
    end
    if S.fuseModeType == "lowest_drop" then
        table.sort(candidates, function(a,b) return num(a.key,"dropChance",100) < num(b.key,"dropChance",100) end)
    elseif S.fuseModeType == "highest_drop" then
        table.sort(candidates, function(a,b) return num(a.key,"dropChance",0) > num(b.key,"dropChance",0) end)
    else
        table.sort(candidates, function(a,b)
            local ai = num(a.key,"income",num(a.key,"earnings",0))
            local bi = num(b.key,"income",num(b.key,"earnings",0))
            return ai < bi
        end)
    end
    if #candidates < 3 then return false end
    return controllerAction("Fuse", candidates[1].key, candidates[2].key, candidates[3].key)
end

local function autoTraitTarget()
    local keys = selectedUnitKeys(S.fTrait)
    if #keys == 0 then return false end
    local targets = {}
    for name, on in pairs(S.fTraitTarget or {}) do if on then table.insert(targets, name) end end
    local did = false
    for _, key in ipairs(keys) do
        local current = tostring(getCurrentUnitAttribute(key, "trait") or "")
        local done = (#targets > 0 and table.find(targets, current) ~= nil)
        if not done then
            did = controllerAction("Trait", key, true) or did
        end
    end
    return did
end

local function autoGradeTarget()
    local keys = selectedUnitKeys(S.fGrade)
    if #keys == 0 then return false end
    local targets = {}
    for name, on in pairs(S.fGradeTarget or {}) do if on then table.insert(targets, name) end end
    local did = false
    for _, key in ipairs(keys) do
        local current = tostring(getCurrentUnitAttribute(key, "grade") or "")
        local done = (#targets > 0 and table.find(targets, current) ~= nil)
        if not done then
            did = controllerAction("Grade", key, true) or did
        end
    end
    return did
end

local function autoLevelUnits()
    local keys = selectedUnitKeys(S.fLevel)
    if #keys == 0 then return false end
    local did = false
    for _, key in ipairs(keys) do
        local slot = getSlotForUnitKey(key)
        if slot then did = controllerAction("LevelUpSlot", slot) or did end
    end
    return did
end

local function autoSellUnits()
    local keys = selectedUnitKeys(S.fSell)
    if #keys == 0 then return false end
    local ok, result = callControllerFunction("SellService", "SellInventory", keys)
    return ok
end

local TowerIdx = 1
local function autoTowerRotate()
    local list = {}
    for n, on in pairs(S.fTower or {}) do if on then table.insert(list, n) end end
    if #list == 0 then list = getTowerList() end
    if #list == 0 or list[1] == "(tower belum terdeteksi)" then return false end
    table.sort(list)
    if TowerIdx > #list then TowerIdx = 1 end
    local towerName = list[TowerIdx]
    local controller = requireModuleByName("TowerController")
    if controller then
        local ok = pcall(function() controller.startTower(towerName) end)
        if ok then
            TowerIdx = TowerIdx + 1
            if TowerIdx > #list then TowerIdx = 1 end
            return true
        end
    end
    return false
end

local function autoTowerTeam() return controllerAction("TowerBest") end

local function autoQuestClaim()
    local rem = findRemotes({"ClaimQuest","QuestClaim","ClaimReward"})
    if #rem == 0 then return false end
    for n, on in pairs(S.fQuest or {}) do
        if on then
            for _, r in ipairs(rem) do pcall(function() r:FireServer(n) end) end
        end
    end
    return true
end

local function autoShopBuy()
    local rem = findRemotes({"Shop","BuyItem","PurchaseItem"})
    if #rem == 0 then return false end
    for n, on in pairs(S.fShop or {}) do
        if on then
            for _, r in ipairs(rem) do pcall(function() r:FireServer(n) end) end
        end
    end
    return true
end

local function autoUpgradeBuy()
    local sig = getSignal("UpgradeService", "BuyUpgrade")
    if not sig then
        -- Anime Dice's controller uses the network BuyUpgrade signal directly.
        local network = safeRequire("Packages.Network")
        local netFolder = ReplicatedStorage:FindFirstChild("Network")
        if network and network.Client and netFolder then
            local ok, result = pcall(function()
                local client = network.Client
                local getSignal = client.GetSignal
                if type(getSignal) == "function" then
                    return getSignal(netFolder, "BuyUpgrade")
                end
            end)
            if ok and result then sig = result end
        end
    end
    if not sig then return false end
    local did = false
    for name, on in pairs(S.fUpgrade or {}) do
        if on then
            local ok = pcall(function() sig:Fire(name) end)
            did = ok or did
        end
    end
    return did
end

local function redeemCodes()
    if #CODES == 0 then return false end
    local rem = findRemotes({"Redeem","Code","Promo"})
    if #rem == 0 then return false end
    for _, c in ipairs(CODES) do
        for _, r in ipairs(rem) do pcall(function() r:FireServer(c) end) end
        task.wait(0.4)
    end
    return true
end

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

local function disableCutscene()
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("BlurEffect") or o:IsA("ColorCorrectionEffect") then o:Destroy() end
    end
    local cam = Workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom; cam.FieldOfView = 70 end
    for _, g in ipairs(LP.PlayerGui:GetChildren()) do
        local n = string.lower(g.Name)
        if string.find(n, "cutscene") or string.find(n, "cinematic") or string.find(n, "roll") then
            if g:IsA("ScreenGui") then g.Enabled = false end
        end
    end
end

-- =========== PERFORMANCE ===========
local function isProtected(o)
    local ch = LP.Character
    if ch and o:IsDescendantOf(ch) then return true end
    if o:FindFirstChildOfClass("Humanoid") then return true end
    local plot = getPlot()
    if plot and o:IsDescendantOf(plot) then return true end
    return false
end

local function deleteDeco()
    local deco = {"grass","tree","flower","bush","rock","decor","prop","fence","barrel","crate","sign"}
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if (o:IsA("BasePart") or o:IsA("Model")) and not isProtected(o) then
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

local function deleteFX()
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") or o:IsA("Beam") or o:IsA("Trail") then
            pcall(function() o:Destroy(); n = n + 1 end)
        end
    end
    return n
end

local function disableLighting()
    local n = 0
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("BlurEffect") or o:IsA("BloomEffect") or o:IsA("SunRaysEffect") or o:IsA("DepthOfFieldEffect") or o:IsA("Atmosphere") then
            pcall(function() o.Enabled = false; n = n + 1 end)
        end
    end
    return n
end

local function deleteSounds()
    local n = 0
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Sound") then pcall(function() o:Destroy(); n = n + 1 end) end
    end
    return n
end

local function removePlayers()
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            pcall(function() p.Character:Destroy(); n = n + 1 end)
        end
    end
    return n
end

local function deleteMap(mode)
    local n = 0
    local char = LP.Character
    local plot = getPlot()
    for _, o in ipairs(Workspace:GetChildren()) do
        local keep = (o == char or o == plot or o:IsA("SpawnLocation") or o:IsA("Terrain") or o:IsA("Camera"))
        if mode == "safe" then
            if not keep then
                local nm = string.lower(o.Name)
                local deco = {"grass","tree","flower","bush","rock","decor","prop","fence","crate","barrel"}
                for _, kw in ipairs(deco) do
                    if string.find(nm, kw, 1, true) then
                        pcall(function() o:Destroy(); n = n + 1 end)
                        break
                    end
                end
            end
        elseif mode == "aggressive" then
            if not keep and not o:FindFirstChildOfClass("Humanoid") then
                pcall(function() o:Destroy(); n = n + 1 end)
            end
        elseif mode == "full" then
            if not keep then
                pcall(function() o:Destroy(); n = n + 1 end)
            end
        end
    end
    notify("Delete Map", mode..": -"..n.." objek", 3)
end

-- ===============================================
--                    UI
-- ===============================================
local ACCENT = Color3.fromRGB(155, 89, 255)
local ACCENT_DARK = Color3.fromRGB(78, 42, 125)
local BG = Color3.fromRGB(12, 13, 18)
local PANEL = Color3.fromRGB(20, 21, 29)
local ITEM = Color3.fromRGB(28, 29, 40)
local ITEM2 = Color3.fromRGB(34, 35, 48)
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
    local old = PlayerGui:FindFirstChild("GOBEY_HUB_v52")
    if old then old:Destroy() end
end)

local GUI = mk("ScreenGui",{
    Name="GOBEY_HUB_v52",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
},PlayerGui)

local W = mk("Frame",{
    Name="Window",
    Size=UDim2.new(0,520,0,430),
    Position=UDim2.new(0.5,-260,0.5,-215),
    BackgroundColor3=BG,
    BorderSizePixel=0,
},GUI)
corner(W,16); line(W,Color3.fromRGB(55,56,72),1)
local SCALE=mk("UIScale",{Scale=1},W)
local function fitUI()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local v=cam.ViewportSize
    SCALE.Scale=math.clamp(math.min((v.X-10)/520,(v.Y-10)/430),0.62,1)
end
pcall(fitUI)
-- Safely poll fitUI (hindari GetPropertyChangedSignal yang kadang error di Delta)
task.spawn(function()
    while GUI and GUI.Parent do
        task.wait(2)
        pcall(fitUI)
    end
end)

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
    BackgroundTransparency=1,Text="ANIME DICE  |  V5 FEATURES",TextColor3=ACCENT,
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

local function minimize()
    W.Visible=false
    reopen.Visible=true
end
topButton("_",-76,Color3.fromRGB(245,205,90),minimize)
topButton("X",-38,Color3.fromRGB(255,95,105),function() GUI:Destroy() end)
reopen.MouseButton1Click:Connect(function() W.Visible=true; reopen.Visible=false end)

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

local Pages,TabBtns={},{ }
local activePage=nil
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
        p.Visible=true; b.BackgroundColor3=ACCENT_DARK; b.TextColor3=TEXT; activePage=p
    end)
    Pages[name]=p; TabBtns[name]=b
    return p
end

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
local tabGrade=createTab("GRADE")
local tabFuse=createTab("FUSE")
local tabCosmetic=createTab("REWARD")
local tabMisc=createTab("MISC")
local tabPerf=createTab("PERF")
local tabDebug=createTab("DEBUG")

local LevelUnitDropdown,SellUnitDropdown,GradeUnitDropdown,TraitUnitDropdown,StatUnitDropdown,FuseUnitDropdown
local TowerDropdown

section(tabMain,"ROLL & FARM")
toggle(tabMain,"Auto Roll",S.autoRoll,function(v) S.autoRoll=v; autoRollController(v) end)
slider(tabMain,"Roll Check Delay",0.25,5,S.rollDelay,function(v) S.rollDelay=v end)
slider(tabMain,"Loop Delay",0.2,5,S.loopDelay,function(v) S.loopDelay=v end)
toggle(tabMain,"Equip Best Owned Dice",S.equipBestDice,function(v) S.equipBestDice=v end)
toggle(tabMain,"Auto Use Spins",S.useSpins,function(v) S.useSpins=v end)
toggle(tabMain,"Auto Use Luck Boost",S.useBoosts,function(v) S.useBoosts=v end)
toggle(tabMain,"Auto Collect Cash",S.collectCash,function(v) S.collectCash=v end)
toggle(tabMain,"Auto Rebirth",S.rebirth,function(v) S.rebirth=v end)
section(tabMain,"DICE")
toggle(tabMain,"Auto Buy Dice",S.buyBestDice,function(v) S.buyBestDice=v end)
dropdown(tabMain,"Pilih Dice",{"(dice loading...)"},S.fDice,true,function(v) S.fDice=v end)
button(tabMain,"Buy Dice Sekarang",autoBuyDice)
section(tabMain,"UPGRADES")
toggle(tabMain,"Auto Buy Upgrades",S.buyUpgrades,function(v) S.buyUpgrades=v end)
dropdown(tabMain,"Pilih Upgrade",getUpgradeList(),S.fUpgrade,true,function(v) S.fUpgrade=v end)

section(tabAuto,"UNITS")
toggle(tabAuto,"Auto Place Best Units",S.placeBest,function(v) S.placeBest=v end)
toggle(tabAuto,"Auto Equip Best",S.equipBest,function(v) S.equipBest=v end)
toggle(tabAuto,"Auto Equip Tower Team",S.towerTeam,function(v) S.towerTeam=v end)
section(tabAuto,"LEVEL & SELL")
toggle(tabAuto,"Auto Level Units",S.levelUnits,function(v) S.levelUnits=v end)
LevelUnitDropdown=dropdown(tabAuto,"Pilih Unit",{"(units loading...)"},S.fLevel,true,function(v) S.fLevel=v end)
toggle(tabAuto,"Auto Sell Units",S.sellUnits,function(v) S.sellUnits=v end)
SellUnitDropdown=dropdown(tabAuto,"Sell Unit",{"(units loading...)"},S.fSell,true,function(v) S.fSell=v end)
toggle(tabAuto,"Auto Lock Valuable Units",S.lockValuables,function(v) S.lockValuables=v end)
section(tabAuto,"TOWER")
toggle(tabAuto,"Auto Tower Rotate",S.tower,function(v) S.tower=v end)
slider(tabAuto,"Tower Rotate Delay",0.5,15,S.towerRotateDelay,function(v) S.towerRotateDelay=v end)
TowerDropdown=dropdown(tabAuto,"Pilih Tower",{"(tower loading...)"},S.fTower,true,function(v) S.fTower=v end)
button(tabAuto,"Refresh Tower List",function() local t=getTowerList(); if TowerDropdown then TowerDropdown.Refresh(t,true) end; notify("Tower",#t.." tower",2) end)
section(tabAuto,"SHOP")
toggle(tabAuto,"Auto Shop",S.shop,function(v) S.shop=v end)
dropdown(tabAuto,"Pilih Shop",getShopList(),S.fShop,true,function(v) S.fShop=v end)
button(tabAuto,"Refresh Unit List",function()
    local o=getUnitSelectorOptions()
    for _,d in ipairs({LevelUnitDropdown,SellUnitDropdown,GradeUnitDropdown,TraitUnitDropdown,StatUnitDropdown,FuseUnitDropdown}) do if d then d.Refresh(o,true) end end
    notify("Refresh",#getInventoryUnitEntries().." unit",2)
end)

section(tabGrade,"GRADE")
toggle(tabGrade,"Auto Grade",S.rollGrade,function(v) S.rollGrade=v end)
GradeUnitDropdown=dropdown(tabGrade,"Pilih Unit",{"(units loading...)"},S.fGrade,true,function(v) S.fGrade=v end)
dropdown(tabGrade,"Target Grade",getGradeList(),S.fGradeTarget,true,function(v) S.fGradeTarget=v end)
button(tabGrade,"Grade Sekarang",autoGradeTarget)
section(tabGrade,"TRAIT")
toggle(tabGrade,"Auto Trait",S.traitRoll,function(v) S.traitRoll=v end)
TraitUnitDropdown=dropdown(tabGrade,"Pilih Unit",{"(units loading...)"},S.fTrait,true,function(v) S.fTrait=v end)
dropdown(tabGrade,"Target Trait",getTraitList(),S.fTraitTarget,true,function(v) S.fTraitTarget=v end)
button(tabGrade,"Trait Sekarang",autoTraitTarget)
section(tabGrade,"STAT")
toggle(tabGrade,"Auto Stat",S.statUp,function(v) S.statUp=v end)
StatUnitDropdown=dropdown(tabGrade,"Pilih Unit",{"(units loading...)"},S.fStat,true,function(v) S.fStat=v end)
dropdown(tabGrade,"Stat Type",getStatList(),S.fStatType,true,function(v) S.fStatType=v end)

section(tabFuse,"FUSE")
toggle(tabFuse,"Auto Fuse",S.fuseMode,function(v) S.fuseMode=v end)
FuseUnitDropdown=dropdown(tabFuse,"Pilih Unit",{"(units loading...)"},S.fFuse,true,function(v) S.fFuse=v end)
dropdown(tabFuse,"Mode",{"lowest_earnings","lowest_drop","highest_drop"},"lowest_earnings",false,function(v) S.fuseModeType=v end)
dropdown(tabFuse,"Ignore Rarity Above",getRarityList(),S.fuseIgnoreRarity,false,function(v) S.fuseIgnoreRarity=v or "" end)
button(tabFuse,"Fuse Sekarang",autoFuseMode)
label(tabFuse,"lowest_earnings = income terendah\nlowest_drop = drop chance terendah\nhighest_drop = drop chance tertinggi",60)

section(tabCosmetic,"REWARDS")
toggle(tabCosmetic,"Auto Claim Offline / Group",S.claimOffline,function(v) S.claimOffline=v; S.claimGroup=v end)
toggle(tabCosmetic,"Auto Spin",S.spin,function(v) S.spin=v end)
toggle(tabCosmetic,"Auto Daily Reward",S.dailyReward,function(v) S.dailyReward=v end)
toggle(tabCosmetic,"Auto Luck Boost",S.luckBoost,function(v) S.luckBoost=v end)
toggle(tabCosmetic,"Auto Potion",S.potion,function(v) S.potion=v end)
toggle(tabCosmetic,"Auto Gear",S.gear,function(v) S.gear=v end)

section(tabMisc,"QUEST")
toggle(tabMisc,"Auto Claim Quest",S.claimQuest,function(v) S.claimQuest=v end)
dropdown(tabMisc,"Pilih Quest",getQuestList(),S.fQuest,true,function(v) S.fQuest=v end)
section(tabMisc,"CODES")
local codesBox=mk("TextBox",{Size=UDim2.new(1,0,0,38),BackgroundColor3=ITEM,BorderSizePixel=0,PlaceholderText="code1,code2,...",Text="",TextColor3=TEXT,PlaceholderColor3=DIM,Font=Enum.Font.Gotham,TextSize=10,ClearTextOnFocus=false},tabMisc); corner(codesBox,9)
codesBox.FocusLost:Connect(function() CODES={}; for c in string.gmatch(codesBox.Text or "","[^,]+") do local t=c:gsub("^%s+",""):gsub("%s+$",""); if t~="" then table.insert(CODES,t) end end end)
toggle(tabMisc,"Auto Redeem Codes",S.redeemCodes,function(v) S.redeemCodes=v; if v and #CODES>0 then redeemCodes() end end)
button(tabMisc,"Redeem Sekarang",function() if #CODES>0 then redeemCodes() else notify("Codes","Isi kode dulu",2) end end)
section(tabMisc,"UTILITY")
toggle(tabMisc,"Disable Cutscene",S.disableCutscene,function(v) S.disableCutscene=v end)
toggle(tabMisc,"Skip Roll Cutscene",S.skipRollCutscene,function(v) S.skipRollCutscene=v end)
toggle(tabMisc,"Anti AFK",S.antiAFK,function(v) S.antiAFK=v; if v then startAntiAFK() else stopAntiAFK() end end)
button(tabMisc,"Server Hop",serverHop)

section(tabPerf,"AUTO CLEAN")
toggle(tabPerf,"Auto Lag Fix",S.autoLagFix,function(v) S.autoLagFix=v end)
toggle(tabPerf,"Auto Delete Map",S.autoDeleteMap,function(v) S.autoDeleteMap=v end)
slider(tabPerf,"Lag Fix Interval",2,30,S.lagFixInterval,function(v) S.lagFixInterval=v end)
slider(tabPerf,"Delete Map Interval",5,60,S.deleteMapInterval,function(v) S.deleteMapInterval=v end)
dropdown(tabPerf,"Map Mode",{"safe","aggressive","full"},S.deleteMapMode,false,function(v) S.deleteMapMode=v end)
section(tabPerf,"MANUAL CLEAN")
button(tabPerf,"Delete Decorations",function() local n=deleteDeco(); notify("Clean","-"..n.." deco",2) end)
button(tabPerf,"Delete FX / Particles",function() local n=deleteFX(); notify("Clean","-"..n.." FX",2) end)
button(tabPerf,"Disable Lighting",function() local n=disableLighting(); notify("Clean","-"..n.." effects",2) end)
button(tabPerf,"Delete Sounds",function() local n=deleteSounds(); notify("Clean","-"..n.." sounds",2) end)
button(tabPerf,"Remove Other Players",function() local n=removePlayers(); notify("Clean","-"..n.." chars",2) end)
button(tabPerf,"Delete Map Sekarang",function() deleteMap(S.deleteMapMode) end)

section(tabDebug,"DEBUG")
local debugLabel=label(tabDebug,"Remote list akan muncul setelah scan.",160)
local function refreshDebug()
    local lines={"Remotes: "..#RemoteList}
    for i,r in ipairs(RemoteList) do
        if i>50 then table.insert(lines,"... +"..(#RemoteList-50).." more"); break end
        table.insert(lines,"["..r.type.."] "..r.path)
    end
    debugLabel.Text=table.concat(lines,"\n")
end
button(tabDebug,"Re-scan Remotes",function() discover(); refreshDebug(); notify("Debug",#RemoteList.." remotes",2) end)
button(tabDebug,"Dump to Console",function() print("=== GOBEY REMOTES ==="); for i,r in ipairs(RemoteList) do print("["..i.."] ("..r.type..") "..r.path) end; print("=== END ==="); notify("Debug","Console dumped",2) end)
button(tabDebug,"Fire Collect Remotes",function() fireAll({"Collect","Claim"}) end)

-- Drag window
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

Pages.MAIN.Visible=true; TabBtns.MAIN.BackgroundColor3=ACCENT_DARK; TabBtns.MAIN.TextColor3=TEXT; activePage=Pages.MAIN

-- =========== ASYNC DATA WARMUP ===========
-- Never require Anime Dice's data modules while constructing the UI.
-- Some game modules yield while the client is still initializing; doing that
-- synchronously used to make Delta look like the script never executed.
task.spawn(function()
    task.wait(1.5)
    pcall(function()
        local diceList = getDiceList()
        -- the dropdown object is intentionally not stored; its callback remains valid
        -- and the initial list is only a safe placeholder.
    end)
    pcall(function() getInventoryUnitEntries() end)
    pcall(function() getTowerList() end)
end)

-- Refresh the selectors after the client data has had time to initialize.
task.spawn(function()
    task.wait(2.5)
    pcall(function()
        local units = getUnitSelectorOptions()
        for _,d in ipairs({LevelUnitDropdown,SellUnitDropdown,GradeUnitDropdown,TraitUnitDropdown,StatUnitDropdown,FuseUnitDropdown}) do
            if d then d.Refresh(units, true) end
        end
    end)
    pcall(function()
        if TowerDropdown then TowerDropdown.Refresh(getTowerList(), true) end
    end)
end)

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
        if S.collectCash    then pcall(autoCollect) end
        if S.rebirth        then pcall(autoRebirth) end
        if S.buyBestDice    then pcall(autoBuyDice) end
        if S.equipBestDice  then pcall(autoEquipBestDiceController) end
        if S.useSpins       then pcall(autoUseAvailableSpins) end
        if S.useBoosts      then pcall(autoUseAvailableBoosts) end
        if S.claimOffline or S.claimGroup then pcall(autoClaimRewardsController) end
        if S.placeBest      then pcall(autoEquipBestController) end
        if S.equipBest      then pcall(autoEquipBest) end
        if S.towerTeam      then pcall(autoTowerTeam) end
        if S.levelUnits     then pcall(autoLevelUnits) end
        if S.sellUnits      then pcall(autoSellUnits) end
        if S.lockValuables  then pcall(autoLockValuablesController) end
        if S.fuseMode       then pcall(autoFuseMode) end
        if S.rollGrade      then pcall(autoGradeTarget) end
        if S.traitRoll      then pcall(autoTraitTarget) end
        if S.buyUpgrades    then pcall(autoUpgradeBuy) end
        if S.claimQuest     then pcall(autoQuestClaim) end
        if S.shop           then pcall(autoShopBuy) end
        if S.spin           then pcall(autoUseAvailableSpins) end
        if S.dailyReward    then pcall(autoDaily) end
        if S.redeemCodes and #CODES > 0 then pcall(redeemCodes) end
        -- These timers are independent so enabling one feature cannot stall all others.
        local now = os.clock()
        if S.tower then
            if not S.__nextTower or now >= S.__nextTower then
                pcall(autoTowerRotate)
                S.__nextTower = now + (tonumber(S.towerRotateDelay) or 3)
            end
        else
            S.__nextTower = nil
        end
        if S.autoLagFix then
            if not S.__nextLagFix or now >= S.__nextLagFix then
                pcall(deleteDeco); pcall(deleteFX); pcall(disableLighting)
                S.__nextLagFix = now + (tonumber(S.lagFixInterval) or 8)
            end
        else
            S.__nextLagFix = nil
        end
        if S.autoDeleteMap then
            if not S.__nextDeleteMap or now >= S.__nextDeleteMap then
                pcall(deleteMap, S.deleteMapMode)
                S.__nextDeleteMap = now + (tonumber(S.deleteMapInterval) or 15)
            end
        else
            S.__nextDeleteMap = nil
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.disableCutscene then pcall(disableCutscene) end
        if S.skipRollCutscene then pcall(disableCutscene) end
    end
end)

-- =========== NOTIFY ===========
task.spawn(function()
    task.wait(1)
    local __unitCount = 0
    pcall(function() __unitCount = #getInventoryUnitEntries() end)
    notify("GOBEY HUB v5.2", #RemoteList.." remotes / "..__unitCount.." unit", 5)
    print("[GOBEY HUB v5.2] Loaded. Remotes: "..#RemoteList)
end)