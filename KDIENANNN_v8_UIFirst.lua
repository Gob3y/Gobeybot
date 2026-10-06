--[[
    ═══════════════════════════════════════════════
       GOBEY HUB  ·  ANIME DICE  ·  v5.0
       Custom Premium UI  ·  Controller Adapter
    ═══════════════════════════════════════════════
]]

-- ═══════════ EXECUTION BOOT ═══════════
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Executors can inject before LocalPlayer is assigned. Wait instead of indexing nil.
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
while not LP do
    task.wait()
    LP = Players.LocalPlayer
end

-- ═══════════ SERVICES ═══════════
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")

-- ═══════════ STATE ═══════════
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

-- ═══════════ REMOTE DISCOVERY ═══════════
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
    scan(ReplicatedStorage, "RS.")
    scan(Workspace, "WS.")
end
-- Remote discovery is intentionally deferred until after the UI is created.
-- This prevents a slow/unsupported GetDescendants() scan from blocking the HUD.

-- ═══════════ GAME CONTROLLER ADAPTERS ═══════════
local ControllerSignals = {}
local function getSignal(serviceName, signalName)
    local key = serviceName .. ":" .. signalName
    if ControllerSignals[key] then return ControllerSignals[key] end
    local ok, result = pcall(function()
        local comm = require(ReplicatedStorage.Packages.Network).ClientComm.new(ReplicatedStorage.Network, false, serviceName)
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
    local ok, result = pcall(function()
        local comm = require(ReplicatedStorage.Packages.Network).ClientComm.new(ReplicatedStorage.Network, false, serviceName)
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
    if name == "Upgrade" then return fireSignal("UpgradeService", "Buy", ...) end
    if name == "TowerBest" then return fireSignal("Towers", "EquipBestTowerTeam", ...) end
    if name == "TowerTeam" then return fireSignal("Towers", "UpdateTowerTeam", ...) end
    if name == "LevelUpSlot" then return fireSignal("PlotService", "LevelUpSlot", ...) end
    return false
end

local function findInventoryKeysByKind(kindName)
    local result = {}
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    local okReg, registry = pcall(function() return require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry) end)
    if not ok or not okReg or not dc or not registry then return result end
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
    local m = findModuleByName(name)
    if not m then return nil end
    local ok, result = pcall(require, m)
    return ok and result or nil
end

local function getInventoryUnitEntries()
    local result = {}
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    local okReg, registry = pcall(function() return require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry) end)
    if not ok or not okReg or not dc or not registry then return result end
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
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    if not ok or not dc then return nil end
    local ok2, item = pcall(function() return dc.Inventory[key]() end)
    return ok2 and item or nil
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
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    if not ok or not dc then return nil end
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
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    if not ok or not dc then return false end
    local best, bestLuck = nil, -math.huge
    pcall(function()
        local dice = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Dice.Dice)
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
    local dcOk, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    if not dcOk or not dc then return false end
    local sig = getSignal("UnitService", "SetLocked")
    if not sig then return false end
    local protected = {}
    local rarityRank = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Godly=7,Divine=8,Secret=9}
    local changed = false
    pcall(function()
        for key, item in dc.Inventory() do
            local cfg = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry).getEntryConfig(item.name)
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

-- ═══════════ UTILITIES ═══════════
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
        local dice = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Dice.Dice)
        for name in pairs(dice.GetAll()) do
            if not seen[name] then seen[name]=true; table.insert(out, name) end
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

-- ═══════════ ANTI AFK ═══════════
local antiAFKConn, antiAFKJump = nil, nil

local function startAntiAFK()
    if antiAFKConn or not LP then return end
    antiAFKConn = LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
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

-- ═══════════ FEATURE FUNCTIONS ═══════════
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
    return ok and result ~= nil
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
    local rem = findRemotes({"BuyUpgrade","PurchaseUpgrade","Upgrade"})
    if #rem == 0 then return false end
    for n, on in pairs(S.fUpgrade or {}) do
        if on then
            for _, r in ipairs(rem) do pcall(function() r:FireServer(n) end) end
        end
    end
    return true
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

-- ═══════════ PERFORMANCE ═══════════
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

-- ═══════════════════════════════════════════════
--                    PREMIUM UI
-- ═══════════════════════════════════════════════
local ACCENT = Color3.fromRGB(155, 89, 255)
local ACCENT_DARK = Color3.fromRGB(88, 40, 160)
local BG_DARK = Color3.fromRGB(14, 14, 20)
local BG_PANEL = Color3.fromRGB(22, 22, 32)
local BG_ITEM = Color3.fromRGB(30, 30, 44)
local TEXT = Color3.fromRGB(235, 235, 245)
local TEXT_DIM = Color3.fromRGB(140, 140, 160)

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t)
    return mk("UIStroke", {Color=c or ACCENT, Thickness=t or 1, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, o)
end

local PlayerGui = LP:WaitForChild("PlayerGui", 15)
if not PlayerGui then
    error("GOBEY HUB: PlayerGui belum tersedia")
end

pcall(function()
    local oldGui = PlayerGui:FindFirstChild("GOBEY_HUB_v5")
    if oldGui then oldGui:Destroy() end
end)

local GUI = mk("ScreenGui", {
    Name = "GOBEY_HUB_v5",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
}, PlayerGui)

local W = mk("Frame", {
    Name = "Window",
    Size = UDim2.new(0, 640, 0, 460),
    Position = UDim2.new(0.5, -320, 0.5, -230),
    BackgroundColor3 = BG_DARK,
    BorderSizePixel = 0,
}, GUI)
corner(W, 14)
stroke(W, Color3.fromRGB(60, 60, 90), 1)

local UIScale = mk("UIScale", {Scale = 1}, W)
local function updateUIScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scale = math.min(1, (vp.X - 12) / 640, (vp.Y - 12) / 460)
    UIScale.Scale = math.clamp(scale, 0.60, 1)
end
updateUIScale()
pcall(function()
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
end)
-- UIShadow is not a Roblox Instance class; omitted for executor compatibility.

-- Title bar
local TB = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = BG_PANEL,
    BorderSizePixel = 0,
}, W)
corner(TB, 14)
mk("Frame", {
    Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0,0,1,-1),
    BackgroundColor3 = ACCENT, BorderSizePixel = 0,
}, TB)

mk("TextLabel", {
    Size = UDim2.new(1, -180, 0, 22), Position = UDim2.new(0, 22, 0, 8),
    BackgroundTransparency = 1,
    Text = "GOBEY HUB", TextColor3 = TEXT,
    Font = Enum.Font.GothamBlack, TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TB)

mk("TextLabel", {
    Size = UDim2.new(1, -180, 0, 14), Position = UDim2.new(0, 22, 0, 30),
    BackgroundTransparency = 1,
    Text = "ANIME DICE  /  v5.0", TextColor3 = ACCENT,
    Font = Enum.Font.GothamBold, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TB)

local function makeCtrlBtn(txt, xPos, color, cb)
    local b = mk("TextButton", {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, xPos, 0.5, -15),
        BackgroundColor3 = BG_DARK,
        BorderSizePixel = 0,
        Text = txt, TextColor3 = color,
        Font = Enum.Font.GothamBold, TextSize = 14,
        AutoButtonColor = false,
    }, TB)
    corner(b, 8)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
        b.TextColor3 = Color3.new(0,0,0)
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = BG_DARK}):Play()
        b.TextColor3 = color
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

local reopen = mk("TextButton", {
    Name = "Reopen",
    Size = UDim2.fromOffset(44, 28),
    Position = UDim2.new(0.5, -22, 0, 8),
    BackgroundColor3 = BG_PANEL,
    BorderSizePixel = 0,
    Text = "G",
    TextColor3 = ACCENT,
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    Visible = false,
    AutoButtonColor = false,
}, GUI)
corner(reopen, 8)
stroke(reopen, Color3.fromRGB(60,60,90), 1)
reopen.MouseButton1Click:Connect(function()
    W.Visible = true
    reopen.Visible = false
    updateUIScale()
end)

makeCtrlBtn("_", -74, Color3.fromRGB(240, 200, 80), function()
    W.Visible = false
    reopen.Visible = true
end)
makeCtrlBtn("X", -38, Color3.fromRGB(255, 90, 90), function() GUI:Destroy() end)

-- Sidebar
local SIDEBAR = mk("ScrollingFrame", {
    Size = UDim2.new(0, 140, 1, -76),
    Position = UDim2.new(0, 14, 0, 62),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, W)
mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, SIDEBAR)

-- Content area
local CONTENT = mk("Frame", {
    Size = UDim2.new(1, -168, 1, -76),
    Position = UDim2.new(0, 154, 0, 62),
    BackgroundColor3 = BG_PANEL,
    BorderSizePixel = 0,
}, W)
corner(CONTENT, 10)
stroke(CONTENT, Color3.fromRGB(45, 45, 65), 1)

local Pages, TabBtns = {}, {}

local function createTab(name)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, -4, 0, 38),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = TEXT_DIM,
        Font = Enum.Font.GothamBold, TextSize = 11,
        AutoButtonColor = false,
    }, SIDEBAR)
    corner(btn, 8)

    local page = mk("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, CONTENT)
    local lay = mk("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    mk("UIPadding", {
        PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,4),
        PaddingLeft=UDim.new(0,4), PaddingRight=UDim.new(0,4),
    }, page)
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 12)
    end)

    btn.MouseEnter:Connect(function()
        if page.Visible then return end
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 35, 65)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        if page.Visible then return end
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = BG_ITEM}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabBtns) do
            b.BackgroundColor3 = BG_ITEM; b.TextColor3 = TEXT_DIM
        end
        page.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = ACCENT_DARK}):Play()
        btn.TextColor3 = TEXT
    end)

    Pages[name] = page
    TabBtns[name] = btn
    return page
end

-- ─── Component: Section ───
local function addSection(page, text)
    local f = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    }, page)
    local bar = mk("Frame", {
        Size = UDim2.new(0, 3, 0, 14),
        Position = UDim2.new(0, 4, 0.5, -7),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
    }, f)
    corner(bar, 2)
    mk("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = text, TextColor3 = ACCENT,
        Font = Enum.Font.GothamBlack, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, f)
end

-- ─── Component: Label ───
local function addLabel(page, text, h)
    local l = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, h or 34),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
        Text = "  "..text, TextColor3 = TEXT_DIM,
        Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, page)
    corner(l, 8)
    mk("UIPadding", {
        PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10),
        PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12),
    }, l)
    return l
end

-- ─── Component: Toggle ───
local function addToggle(page, text, default, callback)
    local value = default and true or false
    local f = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, Color3.fromRGB(45, 45, 65), 1)

    mk("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = text, TextColor3 = TEXT,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, f)

    local track = mk("Frame", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -58, 0.5, -11),
        BackgroundColor3 = value and ACCENT or Color3.fromRGB(55, 55, 70),
        BorderSizePixel = 0,
    }, f)
    corner(track, 22)

    local knob = mk("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = value and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, track)
    corner(knob, 18)

    local function setState(v)
        value = v
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(track, ti, {BackgroundColor3 = v and ACCENT or Color3.fromRGB(55, 55, 70)}):Play()
        TweenService:Create(knob, ti, {Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setState(not value)
            if callback then task.spawn(function() pcall(callback, value) end) end
        end
    end)
    return {Set=function(v) setState(v) end, Get=function() return value end}
end

-- ─── Component: Button ───
local function addButton(page, text, callback)
    local b = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
        Text = text, TextColor3 = TEXT,
        Font = Enum.Font.GothamBold, TextSize = 11,
        AutoButtonColor = false,
    }, page)
    corner(b, 8)
    stroke(b, Color3.fromRGB(60, 60, 90), 1)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = ACCENT_DARK}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = BG_ITEM}):Play()
    end)
    b.MouseButton1Click:Connect(function()
        if callback then task.spawn(function() pcall(callback) end) end
    end)
    return b
end

-- ─── Component: Slider ───
local function addSlider(page, text, min, max, default, callback)
    min, max = min or 0, max or 100
    default = math.clamp(default or min, min, max)
    local value = default

    local f = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
    }, page)
    corner(f, 8)
    stroke(f, Color3.fromRGB(45, 45, 65), 1)

    mk("TextLabel", {
        Size = UDim2.new(0.6, -16, 0, 18),
        Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1,
        Text = text, TextColor3 = TEXT,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, f)

    local vl = mk("TextLabel", {
        Size = UDim2.new(0.4, -16, 0, 18),
        Position = UDim2.new(0.6, 0, 0, 6),
        BackgroundTransparency = 1,
        Text = string.format("%.2f", value), TextColor3 = ACCENT,
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, f)

    local bar = mk("TextButton", {
        Size = UDim2.new(1, -28, 0, 8),
        Position = UDim2.new(0, 14, 0, 36),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
        BorderSizePixel = 0, Text = "",
    }, f)
    corner(bar, 8)

    local fill = mk("Frame", {
        Size = UDim2.new((value-min)/(max-min), 0, 1, 0),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
    }, bar)
    corner(fill, 8)

    local dragging = false
    local function set(x)
        local ax = bar.AbsolutePosition.X
        local w = math.max(1, bar.AbsoluteSize.X)
        local pct = math.clamp((x-ax)/w, 0, 1)
        value = min + (max-min)*pct
        if max-min >= 5 then value = math.floor(value+0.5) end
        fill.Size = UDim2.new(pct, 0, 1, 0)
        vl.Text = string.format("%.2f", value)
        if callback then task.spawn(function() pcall(callback, value) end) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; set(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            set(input.Position.X)
        end
    end)
    return {Set=function(v)
        value = math.clamp(v, min, max)
        fill.Size = UDim2.new((value-min)/(max-min), 0, 1, 0)
        vl.Text = string.format("%.2f", value)
    end, Get=function() return value end}
end

-- ─── Component: Dropdown (fixed, parent ke GUI) ───
local ddZ = 10
local function addDropdown(page, label, options, default, multi, callback)
    options = options or {}
    local selected, current = {}, default
    if multi and type(default) == "table" then
        for k, v in pairs(default) do
            if v == true then selected[k] = true elseif type(v) == "string" then selected[v] = true end
        end
    end
    ddZ = ddZ + 5

    local ROW = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = BG_ITEM,
        BorderSizePixel = 0,
        ZIndex = ddZ,
    }, page)
    corner(ROW, 8)
    stroke(ROW, Color3.fromRGB(45, 45, 65), 1)

    mk("TextLabel", {
        Size = UDim2.new(0.4, -16, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = label, TextColor3 = TEXT,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = ddZ,
    }, ROW)

    local BTN = mk("TextButton", {
        Size = UDim2.new(0.6, -20, 0, 30),
        Position = UDim2.new(0.4, 6, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(20, 20, 30),
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        ZIndex = ddZ + 1,
    }, ROW)
    corner(BTN, 6)

    local BTN_TXT = mk("TextLabel", {
        Size = UDim2.new(1, -32, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "-", TextColor3 = TEXT,
        Font = Enum.Font.GothamBold, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = ddZ + 1,
    }, BTN)

    mk("TextLabel", {
        Size = UDim2.new(0, 22, 1, 0),
        Position = UDim2.new(1, -24, 0, 0),
        BackgroundTransparency = 1,
        Text = "v", TextColor3 = ACCENT,
        Font = Enum.Font.GothamBold, TextSize = 12,
        ZIndex = ddZ + 1,
    }, BTN)

    local POPUP = mk("ScrollingFrame", {
        Size = UDim2.new(0, 200, 0, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(18, 18, 26),
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = ACCENT,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 5000,
    }, GUI)
    corner(POPUP, 8)
    stroke(POPUP, ACCENT, 1)
    local playout = mk("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, POPUP)
    mk("UIPadding", {
        PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6),
        PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6),
    }, POPUP)

    local function selText()
        if multi then
            local arr = {}
            for _, op in ipairs(options) do if selected[op] then table.insert(arr, op) end end
            if #arr == 0 then return "None" end
            if #arr == 1 then return arr[1] end
            return tostring(#arr).." selected"
        end
        return tostring(current or options[1] or "-")
    end

    local function emit()
        BTN_TXT.Text = selText()
        if callback then
            if multi then
                local c = {}
                for k, v in pairs(selected) do c[k] = v end
                task.spawn(function() pcall(callback, c) end)
            else
                task.spawn(function() pcall(callback, current) end)
            end
        end
    end

    local function closePopup() POPUP.Visible = false end

    local function openPopup()
        local ap = BTN.AbsolutePosition
        local as = BTN.AbsoluteSize
        local h = math.min(200, playout.AbsoluteContentSize.Y + 14)
        if h < 34 then h = 34 end
        local windowBottom = W.AbsolutePosition.Y + W.AbsoluteSize.Y
        local desiredY = ap.Y + as.Y + 4
        if desiredY + h > windowBottom then desiredY = ap.Y - h - 4 end
        POPUP.Position = UDim2.fromOffset(ap.X, desiredY)
        POPUP.Size = UDim2.fromOffset(as.X, h)
        POPUP.Visible = true
    end

    local function rebuild()
        for _, ch in ipairs(POPUP:GetChildren()) do
            if ch:IsA("TextButton") or (ch:IsA("TextLabel") and ch.Name == "EmptyHint") then
                ch:Destroy()
            end
        end
        if #options == 0 then
            mk("TextLabel", {
                Name = "EmptyHint",
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundTransparency = 1,
                Text = "Kosong", TextColor3 = TEXT_DIM,
                Font = Enum.Font.Gotham, TextSize = 10,
            }, POPUP)
            return
        end
        local i = 1
        for _, op in ipairs(options) do
            local active = (multi and selected[op]) or (not multi and current == op)
            local item = mk("TextButton", {
                Size = UDim2.new(1, -4, 0, 28),
                BackgroundColor3 = active and ACCENT_DARK or Color3.fromRGB(38, 38, 52),
                BorderSizePixel = 0,
                Text = tostring(op), TextColor3 = TEXT,
                Font = Enum.Font.GothamBold, TextSize = 10,
                LayoutOrder = i, AutoButtonColor = false,
                ZIndex = 5001,
            }, POPUP)
            corner(item, 6)
            i = i + 1
            item.MouseEnter:Connect(function()
                if not active then item.BackgroundColor3 = Color3.fromRGB(50, 50, 70) end
            end)
            item.MouseLeave:Connect(function()
                if not active then item.BackgroundColor3 = Color3.fromRGB(38, 38, 52) end
            end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    selected[op] = not selected[op] or nil
                    rebuild(); emit(); openPopup()
                else
                    current = op
                    rebuild(); emit(); closePopup()
                end
            end)
        end
    end

    BTN.MouseButton1Click:Connect(function()
        if POPUP.Visible then closePopup() else openPopup() end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if not POPUP.Visible then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local mx, my = input.Position.X, input.Position.Y
        local pp, ps = POPUP.AbsolutePosition, POPUP.AbsoluteSize
        local bp, bs = BTN.AbsolutePosition, BTN.AbsoluteSize
        local inP = mx >= pp.X and mx <= pp.X + ps.X and my >= pp.Y and my <= pp.Y + ps.Y
        local inB = mx >= bp.X and mx <= bp.X + bs.X and my >= bp.Y and my <= bp.Y + bs.Y
        if not inP and not inB then closePopup() end
    end)

    if not multi and not current and #options > 0 then current = options[1] end
    rebuild()
    emit()

    return {
        Refresh = function(no, keepSelection)
            options = no or {}
            if not keepSelection then
                selected = {}
                if not multi then current = options[1] end
            else
                -- Buang pilihan yang ga ada lagi di opsi baru
                local validOptions = {}
                for _, op in ipairs(options) do validOptions[op] = true end
                if multi then
                    for k in pairs(selected) do
                        if not validOptions[k] then selected[k] = nil end
                    end
                else
                    if current and not validOptions[current] then current = options[1] end
                end
            end
            rebuild(); emit()
        end,
        SetOptions = function(no) options = no or {}; rebuild(); emit() end,
        Get = function() return multi and selected or current end,
        Set = function(v, c)
            if multi then
                selected = {}
                if type(v) == "table" then
                    for k, val in pairs(v) do
                        if val == true then selected[k] = true elseif type(val) == "string" then selected[val] = true end
                    end
                end
            else current = v end
            rebuild()
            if c ~= false then emit() end
        end,
    }
end

-- ═══════════ BUILD TABS ═══════════
local tabMain     = createTab("MAIN")
local tabAuto     = createTab("AUTO")
local tabGrade    = createTab("GRADE / TRAIT")
local tabFuse     = createTab("FUSE")
local tabCosmetic = createTab("COSMETIC")
local tabMisc     = createTab("MISC")
local tabPerf     = createTab("PERFORMANCE")
local tabDebug    = createTab("DEBUG")

local LevelUnitDropdown, SellUnitDropdown, GradeUnitDropdown, TraitUnitDropdown, StatUnitDropdown, FuseUnitDropdown
local TowerDropdown

-- ═══════════════════════════════════════════════
--                    MAIN TAB
-- ═══════════════════════════════════════════════
addSection(tabMain, "CORE FARM")

addToggle(tabMain, "Auto Roll", S.autoRoll, function(v)
    S.autoRoll = v
    autoRollController(v)
end)

addSlider(tabMain, "Roll Check Delay", 0.25, 5, 1, function(v) S.rollDelay = v end)

addToggle(tabMain, "Equip Best Owned Dice", S.equipBestDice, function(v) S.equipBestDice = v end)
addToggle(tabMain, "Auto Use Spins", S.useSpins, function(v) S.useSpins = v end)
addToggle(tabMain, "Auto Use Luck Boost", S.useBoosts, function(v) S.useBoosts = v end)

addSection(tabMain, "FARMING")

addToggle(tabMain, "Auto Collect Cash", S.collectCash, function(v) S.collectCash = v end)
addToggle(tabMain, "Auto Rebirth", S.rebirth, function(v) S.rebirth = v end)
addSlider(tabMain, "Loop Delay", 0.2, 5, 1, function(v) S.loopDelay = v end)

addSection(tabMain, "BUY DICE")

addToggle(tabMain, "Auto Buy Dice", S.buyBestDice, function(v) S.buyBestDice = v end)
addDropdown(tabMain, "Pilih Dice", getDiceList(), S.fDice, true, function(sel) S.fDice = sel end)
addButton(tabMain, "Buy Dice Sekarang", function() autoBuyDice() end)

addSection(tabMain, "UPGRADES")

addToggle(tabMain, "Auto Buy Upgrades", S.buyUpgrades, function(v) S.buyUpgrades = v end)
addDropdown(tabMain, "Pilih Upgrade", getUpgradeList(), S.fUpgrade, true, function(sel) S.fUpgrade = sel end)

-- ═══════════════════════════════════════════════
--                    AUTO TAB
-- ═══════════════════════════════════════════════
addSection(tabAuto, "UNITS")

addToggle(tabAuto, "Auto Place Best Units", S.placeBest, function(v) S.placeBest = v end)
addToggle(tabAuto, "Auto Equip Best", S.equipBest, function(v) S.equipBest = v end)
addToggle(tabAuto, "Auto Equip Tower Team", S.towerTeam, function(v) S.towerTeam = v end)

addSection(tabAuto, "LEVEL")

addToggle(tabAuto, "Auto Level Units", S.levelUnits, function(v) S.levelUnits = v end)
LevelUnitDropdown = addDropdown(tabAuto, "Pilih Unit", getUnitNames(), S.fLevel, true, function(sel) S.fLevel = sel end)

addSection(tabAuto, "SELL")

addToggle(tabAuto, "Auto Sell Units", S.sellUnits, function(v) S.sellUnits = v end)
SellUnitDropdown = addDropdown(tabAuto, "Pilih Unit", getUnitNames(), S.fSell, true, function(sel) S.fSell = sel end)

addSection(tabAuto, "INVENTORY SAFETY")
addToggle(tabAuto, "Auto Lock Valuable Units", S.lockValuables, function(v) S.lockValuables = v end)

addSection(tabAuto, "TOWER")

addToggle(tabAuto, "Auto Tower Rotate", S.tower, function(v) S.tower = v end)
TowerDropdown = addDropdown(tabAuto, "Pilih Tower", getTowerList(), S.fTower, true, function(sel) S.fTower = sel end)
addSlider(tabAuto, "Rotate Delay", 0.5, 15, 3, function(v) S.towerRotateDelay = v end)

addButton(tabAuto, "Refresh Tower List", function()
    local towers = getTowerList()
    if TowerDropdown and TowerDropdown.Refresh then
        TowerDropdown:Refresh(towers, true)
    end
    notify("Tower", #towers.." tower terdeteksi", 2)
end)

addSection(tabAuto, "SHOP")

addToggle(tabAuto, "Auto Shop", S.shop, function(v) S.shop = v end)
addDropdown(tabAuto, "Pilih Shop", getShopList(), S.fShop, true, function(sel) S.fShop = sel end)

addButton(tabAuto, "Refresh Unit List", function()
    local opts = getUnitSelectorOptions()
    if LevelUnitDropdown then LevelUnitDropdown:Refresh(opts, true) end
    if SellUnitDropdown then SellUnitDropdown:Refresh(opts, true) end
    if GradeUnitDropdown then GradeUnitDropdown:Refresh(opts, true) end
    if TraitUnitDropdown then TraitUnitDropdown:Refresh(opts, true) end
    if StatUnitDropdown then StatUnitDropdown:Refresh(opts, true) end
    if FuseUnitDropdown then FuseUnitDropdown:Refresh(opts, true) end
    notify("Refresh", #getInventoryUnitEntries().." unit di inventory", 2)
end)

-- ═══════════════════════════════════════════════
--                 GRADE / TRAIT TAB
-- ═══════════════════════════════════════════════
addSection(tabGrade, "GRADE")

addToggle(tabGrade, "Auto Grade", S.rollGrade, function(v) S.rollGrade = v end)
GradeUnitDropdown = addDropdown(tabGrade, "Pilih Unit", getUnitNames(), S.fGrade, true, function(sel) S.fGrade = sel end)
addDropdown(tabGrade, "Target Grade", getGradeList(), S.fGradeTarget, true, function(sel) S.fGradeTarget = sel end)
addButton(tabGrade, "Grade Sekarang", function() autoGradeTarget() end)

addSection(tabGrade, "TRAIT")

addToggle(tabGrade, "Auto Trait", S.traitRoll, function(v) S.traitRoll = v end)
TraitUnitDropdown = addDropdown(tabGrade, "Pilih Unit", getUnitNames(), S.fTrait, true, function(sel) S.fTrait = sel end)
addDropdown(tabGrade, "Target Trait", getTraitList(), S.fTraitTarget, true, function(sel) S.fTraitTarget = sel end)
addButton(tabGrade, "Trait Sekarang", function() autoTraitTarget() end)

addSection(tabGrade, "STAT")

addToggle(tabGrade, "Auto Stat", S.statUp, function(v) S.statUp = v end)
StatUnitDropdown = addDropdown(tabGrade, "Pilih Unit", getUnitNames(), S.fStat, true, function(sel) S.fStat = sel end)
addDropdown(tabGrade, "Stat Type", getStatList(), S.fStatType, true, function(sel) S.fStatType = sel end)

-- ═══════════════════════════════════════════════
--                    FUSE TAB
-- ═══════════════════════════════════════════════
addSection(tabFuse, "FUSE MODE")

addToggle(tabFuse, "Auto Fuse", S.fuseMode, function(v) S.fuseMode = v end)
FuseUnitDropdown = addDropdown(tabFuse, "Pilih Unit (opsional)", getUnitNames(), S.fFuse, true, function(sel) S.fFuse = sel end)
addDropdown(tabFuse, "Mode", {"lowest_earnings","lowest_drop","highest_drop"}, "lowest_earnings", false, function(sel)
    S.fuseModeType = sel
end)
addDropdown(tabFuse, "Ignore Rarity Above", getRarityList(), S.fuseIgnoreRarity, false, function(sel)
    S.fuseIgnoreRarity = sel or ""
end)
addButton(tabFuse, "Fuse Sekarang", function() autoFuseMode() end)

addLabel(tabFuse,
    "lowest_earnings = fuse unit income terendah\n" ..
    "lowest_drop = fuse unit drop chance terendah\n" ..
    "highest_drop = fuse unit drop chance tertinggi",
    70)

-- ═══════════════════════════════════════════════
--                  COSMETIC TAB
-- ═══════════════════════════════════════════════
addSection(tabCosmetic, "SPIN & REWARD")

addToggle(tabCosmetic, "Auto Claim Offline / Group", S.claimOffline, function(v)
    S.claimOffline = v; S.claimGroup = v
end)
addToggle(tabCosmetic, "Auto Spin", S.spin, function(v) S.spin = v end)
addToggle(tabCosmetic, "Auto Daily Reward", S.dailyReward, function(v) S.dailyReward = v end)
addToggle(tabCosmetic, "Auto Luck Boost", S.luckBoost, function(v) S.luckBoost = v end)

addSection(tabCosmetic, "POTION & GEAR")
addToggle(tabCosmetic, "Auto Potion", S.potion, function(v) S.potion = v end)
addToggle(tabCosmetic, "Auto Gear", S.gear, function(v) S.gear = v end)

-- ═══════════════════════════════════════════════
--                    MISC TAB
-- ═══════════════════════════════════════════════
addSection(tabMisc, "QUEST")

addToggle(tabMisc, "Auto Claim Quest", S.claimQuest, function(v) S.claimQuest = v end)
addDropdown(tabMisc, "Pilih Quest", getQuestList(), S.fQuest, true, function(sel) S.fQuest = sel end)

addSection(tabMisc, "CODES")

local codesBox = mk("TextBox", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = BG_ITEM,
    BorderSizePixel = 0,
    PlaceholderText = "code1,code2,...",
    Text = "", TextColor3 = TEXT,
    PlaceholderColor3 = TEXT_DIM,
    Font = Enum.Font.Gotham, TextSize = 11,
    ClearTextOnFocus = false,
}, tabMisc)
corner(codesBox, 8)
stroke(codesBox, Color3.fromRGB(45, 45, 65), 1)

codesBox.FocusLost:Connect(function()
    CODES = {}
    for c in string.gmatch(codesBox.Text or "", "[^,]+") do
        local t = c:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then table.insert(CODES, t) end
    end
end)

addToggle(tabMisc, "Auto Redeem Codes", S.redeemCodes, function(v)
    S.redeemCodes = v
    if v and #CODES > 0 then redeemCodes() end
end)
addButton(tabMisc, "Redeem Sekarang", function()
    if #CODES > 0 then redeemCodes() else notify("Codes", "Isi kode dulu", 2) end
end)

addSection(tabMisc, "UTILITY")

addToggle(tabMisc, "Disable Cutscene", S.disableCutscene, function(v) S.disableCutscene = v end)
addToggle(tabMisc, "Skip Roll Cutscene", S.skipRollCutscene, function(v) S.skipRollCutscene = v end)
addToggle(tabMisc, "Anti AFK", S.antiAFK, function(v)
    S.antiAFK = v
    if v then startAntiAFK() else stopAntiAFK() end
end)
addButton(tabMisc, "Server Hop", function() serverHop() end)

-- ═══════════════════════════════════════════════
--                PERFORMANCE TAB
-- ═══════════════════════════════════════════════
addSection(tabPerf, "AUTO CLEAN")

addToggle(tabPerf, "Auto Lag Fix", S.autoLagFix, function(v) S.autoLagFix = v end)
addSlider(tabPerf, "Interval Lag Fix", 2, 30, 8, function(v) S.lagFixInterval = v end)

addSection(tabPerf, "MANUAL CLEAN")

addButton(tabPerf, "Delete Decorations", function()
    local n = deleteDeco(); notify("Clean", "-"..n.." deco", 2)
end)
addButton(tabPerf, "Delete FX / Particles", function()
    local n = deleteFX(); notify("Clean", "-"..n.." FX", 2)
end)
addButton(tabPerf, "Disable Lighting", function()
    local n = disableLighting(); notify("Clean", "-"..n.." effects", 2)
end)
addButton(tabPerf, "Delete Sounds", function()
    local n = deleteSounds(); notify("Clean", "-"..n.." sounds", 2)
end)
addButton(tabPerf, "Remove Other Players", function()
    local n = removePlayers(); notify("Clean", "-"..n.." chars", 2)
end)

addSection(tabPerf, "DELETE MAP")

addToggle(tabPerf, "Auto Delete Map", S.autoDeleteMap, function(v) S.autoDeleteMap = v end)
addDropdown(tabPerf, "Mode", {"safe","aggressive","full"}, "safe", false, function(sel) S.deleteMapMode = sel end)
addSlider(tabPerf, "Interval Delete Map", 5, 60, 15, function(v) S.deleteMapInterval = v end)
addButton(tabPerf, "Delete Map Sekarang", function() deleteMap(S.deleteMapMode) end)

-- ═══════════════════════════════════════════════
-- Perform remote discovery only after the main UI has already been built.
pcall(discover)

--                   DEBUG TAB
-- ═══════════════════════════════════════════════
addSection(tabDebug, "REMOTES ("..#RemoteList..")")

local debugLabel = addLabel(tabDebug, "Loading...", 260)
local function refreshDebug()
    local lines = {}
    for i, r in ipairs(RemoteList) do
        if i > 60 then table.insert(lines, "... +"..(#RemoteList-60).." lagi"); break end
        table.insert(lines, "["..r.type.."] "..r.path)
    end
    debugLabel.Text = table.concat(lines, "\n")
end
refreshDebug()

addButton(tabDebug, "Re-scan Remotes", function()
    discover(); refreshDebug()
    notify("Debug", #RemoteList.." remotes", 2)
end)
addButton(tabDebug, "Dump ke Console (F9)", function()
    print("=== GOBEY REMOTES ===")
    for i, r in ipairs(RemoteList) do
        print(string.format("[%d] (%s) %s", i, r.type, r.path))
    end
    print("=== END ===")
    notify("Debug", "Cek console F9", 3)
end)
addButton(tabDebug, "Fire 'Collect' Semua", function() fireAll({"Collect","Claim"}) end)

-- ═══════════════════════════════════════════════
--                 WINDOW DRAG
-- ═══════════════════════════════════════════════
do
    local dragging, dragStart, startPos = false, nil, nil
    TB.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = W.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            W.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

Pages["MAIN"].Visible = true
TabBtns["MAIN"].BackgroundColor3 = ACCENT_DARK
TabBtns["MAIN"].TextColor3 = TEXT

-- ═══════════════════════════════════════════════
--                  MAIN LOOP
-- ═══════════════════════════════════════════════
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
        if S.tower then
            pcall(autoTowerRotate)
            task.wait(S.towerRotateDelay or 3)
        end
        if S.autoLagFix then
            pcall(deleteDeco); pcall(deleteFX); pcall(disableLighting)
            task.wait(S.lagFixInterval or 8)
        end
        if S.autoDeleteMap then
            pcall(deleteMap, S.deleteMapMode)
            task.wait(S.deleteMapInterval or 15)
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

-- ═══════════ NOTIFY ═══════════
local __unitCount = 0
pcall(function() __unitCount = #getInventoryUnitEntries() end)
notify("GOBEY HUB v5.0", #RemoteList.." remotes / "..__unitCount.." unit", 5)
print("[GOBEY HUB v5.0] Loaded. Remotes: "..#RemoteList)