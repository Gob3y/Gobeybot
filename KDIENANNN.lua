--[[
    ═══════════════════════════════════════════════
       GOBEY HUB  ·  ANIME DICE  ·  v4.1
       Powered by Rayfield UI  ·  Anti-AFK Included
    ═══════════════════════════════════════════════
]]

-- ═══════════ LOAD RAYFIELD ═══════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ═══════════ SERVICES ═══════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local VirtualUser       = game:GetService("VirtualUser")
local LP                = Players.LocalPlayer

-- ═══════════ STATE ═══════════
local S = {
    -- toggles
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
    -- config
    loopDelay=1, towerRotateDelay=3, lagFixInterval=8,
    rollDelay=1, boostType="Luck",
    deleteMapInterval=15, fuseModeType="lowest_earnings", fuseIgnoreRarity="",
    deleteMapMode="safe",
    -- filters
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
discover()

-- ═══════════ GAME CONTROLLER ADAPTERS ═══════════
-- Dibuat berdasarkan controller yang diberikan di ZIP, bukan menebak nama remote.
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

local function unitOptionLabel(item, index)
    local suffix = tostring(item.key)
    if #suffix > 6 then suffix = string.sub(suffix, -6) end
    return item.name .. "  [" .. suffix .. "]"
end

local UnitOptionMap = {}
local function getUnitSelectorOptions()
    UnitOptionMap = {}
    local options = {}
    for i, item in ipairs(getInventoryUnitEntries()) do
        local label = unitOptionLabel(item, i)
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
            -- Backward compatibility if an old saved config contains a raw key.
            for _, item in ipairs(all) do
                if item.key == tostring(value) and not seen[item.key] then
                    seen[item.key] = true; table.insert(out, item.key)
                end
            end
        end
    end
    return out
end

local function isUnitSelected(filter, unit)
    if type(filter) ~= "table" or not next(filter) then return true end
    if unit.key and filter[unit.key] then return true end
    return filter[unit.name] == true or filter[unit.label] == true
end

local function getInventoryUnitByKey(key)
    local ok, dc = pcall(function() return require(ReplicatedStorage.Framework.Features.Data.DataController) end)
    if not ok or not dc then return nil end
    local ok2, item = pcall(function() return dc.Inventory[key]() end)
    return ok2 and item or nil
end

local function getUnitEntryByKey(key)
    for _, item in ipairs(getInventoryUnitEntries()) do
        if item.key == tostring(key) then return item end
    end
    return nil
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

local function refreshUnitDropdown(dropdown, flag, currentFilter)
    if not dropdown or not dropdown.Refresh then return end
    local options = getUnitSelectorOptions()
    pcall(function() dropdown:Refresh(options, true) end)
    if type(currentFilter) == "table" then
        local valid = {}
        for label in pairs(currentFilter) do
            if UnitOptionMap[label] then table.insert(valid, label) end
        end
        if dropdown.Set then pcall(function() dropdown:Set(valid) end) end
    end
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

local function findInventoryUnitKeys()
    return findInventoryKeysByKind("Unit")
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

local function getUnits()
    local out, seen = {}, {}
    local plot = getPlot()
    local roots = {}
    if plot then table.insert(roots, plot) end
    for _, n in ipairs({"Plots","PlotFolder","Units"}) do
        local f = Workspace:FindFirstChild(n)
        if f then table.insert(roots, f) end
    end
    for _, root in ipairs(roots) do
        for _, u in ipairs(root:GetDescendants()) do
            if (u:IsA("Model") or u:IsA("Folder")) and not seen[u] then
                local uName = u:GetAttribute("UnitName") or u:GetAttribute("Name")
                local uId = u:GetAttribute("UnitId") or u:GetAttribute("Id")
                local pw = tonumber(u:GetAttribute("Power")) or tonumber(u:GetAttribute("Damage")) or 0
                if (uName or uId) and u:FindFirstChildWhichIsA("BasePart", true) then
                    seen[u] = true
                    table.insert(out, {model=u, name=tostring(uName or uId or u.Name), id=uId, power=pw})
                end
            end
        end
    end
    table.sort(out, function(a,b) return a.power > b.power end)
    return out
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
    local d = scanRS({"Dice","Dices","DiceData","Rolls","Eggs"})
    if #d == 0 then d = {"Basic","Lucky","Golden"} end
    return d
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
    Rayfield:Notify({
        Title = tostring(title or "GOBEY HUB"),
        Content = tostring(text or ""),
        Duration = tonumber(dur) or 3,
    })
end

-- ═══════════ ANTI AFK ═══════════
local antiAFKConn = nil
local antiAFKJump = nil

local function startAntiAFK()
    if antiAFKConn then return end
    antiAFKConn = LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
    -- Lapisan kedua: reset idle tiap 60 detik
    antiAFKJump = task.spawn(function()
        while antiAFKConn do
            task.wait(60)
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Jump = true
                    task.wait(0.1)
                    hum.Jump = false
                end
            end)
        end
    end)
end

local function stopAntiAFK()
    if antiAFKConn then
        antiAFKConn:Disconnect()
        antiAFKConn = nil
    end
    antiAFKJump = nil
end

-- ═══════════ FEATURE FUNCTIONS ═══════════
local function tryFeature(remoteKws, guiKw, guiTextKw)
    if fireAll(remoteKws) then return true end
    pcall(function()
        for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
            if g:IsA("TextButton") or g:IsA("ImageButton") then
                local n = string.lower(g.Name or "")
                local t = g:IsA("TextButton") and string.lower(g.Text or "") or ""
                local match = false
                for _, kw in ipairs(guiKw or {}) do
                    if string.find(n, string.lower(kw), 1, true) then match = true; break end
                end
                if not match then
                    for _, kw in ipairs(guiTextKw or {}) do
                        if string.find(t, string.lower(kw), 1, true) then match = true; break end
                    end
                end
                if match then
                    pcall(function() g:Activate() end)
                    pcall(function() firesignal(g.MouseButton1Click) end)
                    return true
                end
            end
        end
    end)
    return false
end

local function autoCollect() return controllerAction("Collect") or tryFeature({"Collect","ClaimCash","CollectCash"}, {"Collect","Claim"}, {"collect","claim"}) end
local function autoRebirth() return controllerAction("Rebirth") or tryFeature({"Rebirth","Prestige"}, {"Rebirth"}, {"rebirth"}) end
local function autoPlaceBest() return tryFeature({"Place","EquipBest","PlaceUnit"}, {"Place","Equip"}, {"place","equip"}) end
local function autoEquipBest() return autoEquipBestController() or autoEquipBestDiceController() or tryFeature({"EquipBest","AutoEquip"}, {"Equip"}, {"equip"}) end
local function autoSpin() return autoUseAvailableSpins() or tryFeature({"Spin","LuckySpin"}, {"Spin"}, {"spin"}) end
local function autoDaily() return autoClaimRewardsController() or tryFeature({"Daily","Login","DailyReward"}, {"Daily","Login"}, {"daily","login"}) end
local function autoLuck()      return tryFeature({"Luck","BoostLuck"}, {"Luck"}, {"luck"}) end
local function autoPotion()    return tryFeature({"UsePotion","Potion","DrinkPotion"}, {"Potion","Use"}, {"potion","use"}) end
local function autoGear()      return tryFeature({"Gear","EquipGear"}, {"Gear"}, {"gear"}) end

local function autoBuyDice()
    local picks = {}
    for name, on in pairs(S.fDice or {}) do if on then table.insert(picks, name) end end
    if #picks == 0 then picks = getDiceList() end
    local did = false
    for _, d in ipairs(picks) do did = controllerAction("BuyDice", d) or did end
    if did then return true end
    local rem = findRemotes({"BuyDice","PurchaseDice","RollDice","BuyRoll"})
    if #rem == 0 then return false end
    for _, d in ipairs(picks) do
        for _, r in ipairs(rem) do
            pcall(function() r:FireServer(d) end)
            pcall(function() r:FireServer(d, 1) end)
        end
        task.wait(0.15)
    end
    return true
end

local function autoFuseMode()
    local entries = getInventoryUnitEntries()
    if #entries < 3 then return false end

    local candidates = {}
    for _, item in ipairs(entries) do
        local rar = getCurrentUnitAttribute(item.key, "rarity") or getCurrentUnitAttribute(item.key, "grade") or "Common"
        local rarityOrder = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Godly=7,Divine=8,Secret=9}
        local maxRank = 999
        if S.fuseIgnoreRarity ~= "" then maxRank = rarityOrder[S.fuseIgnoreRarity] or 999 end
        if (rarityOrder[tostring(rar)] or 1) <= maxRank then
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

    local keys = {candidates[1].key, candidates[2].key, candidates[3].key}
    if keys[1] == keys[2] or keys[1] == keys[3] or keys[2] == keys[3] then return false end
    if controllerAction("Fuse", keys[1], keys[2], keys[3]) then return true end

    -- Fallback hanya jika controller tidak tersedia.
    local rem = findRemotes({"Fuse","Merge","FuseUnit"})
    if #rem == 0 then return false end
    for _, r in ipairs(rem) do
        pcall(function() r:FireServer(keys[1], keys[2], keys[3]) end)
    end
    return true
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
    if did then return true end
    return false
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
            -- true = skip protected grade confirmation, sesuai controller asli.
            did = controllerAction("Grade", key, true) or did
        end
    end
    if did then return true end
    return false
end

local function autoLevelUnits()
    local keys = selectedUnitKeys(S.fLevel)
    if #keys == 0 then return false end
    local did = false
    for _, key in ipairs(keys) do
        local slot = getSlotForUnitKey(key)
        if slot then
            did = controllerAction("LevelUpSlot", slot) or did
        end
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
    -- Tidak menebak remote Tower; controller game adalah sumber yang benar.
    return false
end

local function autoTowerTeam()
    return controllerAction("TowerBest")
end

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

local function autoStatUp()
    local rem = findRemotes({"Stat","UpgradeStat","SpendStat"})
    if #rem == 0 then return false end
    local stats = {}
    for n, on in pairs(S.fStatType or {}) do if on then table.insert(stats, n) end end
    if #stats == 0 then stats = {"Damage"} end
    for _, u in ipairs(getUnits()) do
        local ok = true
        if next(S.fStat) then ok = S.fStat[u.name] == true end
        if ok then
            for _, r in ipairs(rem) do
                for _, st in ipairs(stats) do
                    pcall(function() r:FireServer(u.model, st) end)
                end
            end
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

-- ═══════════ CREATE RAYFIELD UI ═══════════
local Window = Rayfield:CreateWindow({
    Name = "GOBEY HUB  ·  Anime Dice",
    LoadingTitle = "GOBEY HUB",
    LoadingSubtitle = "Anime Dice Auto Farm",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FileName = "GOBEY_AnimeDice",
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- ═══════════ TABS ═══════════
local MainTab    = Window:CreateTab("Main", 4483362458)
local AutoTab    = Window:CreateTab("Auto", 4483362458)
local GradeTab   = Window:CreateTab("Grade/Trait", 4483362458)
local FuseTab    = Window:CreateTab("Fuse", 4483362458)
local CosmeticTab= Window:CreateTab("Cosmetic", 4483362458)
local MiscTab    = Window:CreateTab("Misc", 4483362458)
local PerfTab    = Window:CreateTab("Performance", 4483362458)
local DebugTab   = Window:CreateTab("Debug", 4483362458)

local LevelUnitDropdown, SellUnitDropdown, GradeUnitDropdown, TraitUnitDropdown, StatUnitDropdown, FuseUnitDropdown

-- ═══════════ MAIN TAB ═══════════
MainTab:CreateSection("Core Farm")

MainTab:CreateToggle({
    Name = "Auto Roll",
    CurrentValue = false,
    Flag = "AutoRoll",
    Callback = function(v) S.autoRoll = v; autoRollController(v) end,
})

MainTab:CreateSlider({
    Name = "Roll Check Delay", Range = {0.25, 5}, Increment = 0.25, Suffix = "s", CurrentValue = 1, Flag = "RollDelay",
    Callback = function(v) S.rollDelay = v end,
})

MainTab:CreateToggle({
    Name = "Equip Best Owned Dice", CurrentValue = false, Flag = "EquipBestDice",
    Callback = function(v) S.equipBestDice = v end,
})

MainTab:CreateToggle({
    Name = "Auto Use Spins", CurrentValue = false, Flag = "UseSpins",
    Callback = function(v) S.useSpins = v end,
})

MainTab:CreateToggle({
    Name = "Auto Use Luck Boost", CurrentValue = false, Flag = "UseBoosts",
    Callback = function(v) S.useBoosts = v end,
})

MainTab:CreateSection("Farming")

MainTab:CreateToggle({
    Name = "Auto Collect Cash",
    CurrentValue = false,
    Flag = "AutoCollect",
    Callback = function(v) S.collectCash = v end,
})

MainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "AutoRebirth",
    Callback = function(v) S.rebirth = v end,
})

MainTab:CreateSlider({
    Name = "Loop Delay",
    Range = {0.2, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1,
    Flag = "LoopDelay",
    Callback = function(v) S.loopDelay = v end,
})

MainTab:CreateSection("Buy Dice")

MainTab:CreateToggle({
    Name = "Auto Buy Dice",
    CurrentValue = false,
    Flag = "AutoBuyDice",
    Callback = function(v) S.buyBestDice = v end,
})

MainTab:CreateDropdown({
    Name = "Pilih Dice",
    Options = getDiceList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "DiceSelect",
    Callback = function(sel) S.fDice = sel end,
})

MainTab:CreateButton({
    Name = "Buy Dice Sekarang",
    Callback = function() autoBuyDice() end,
})

MainTab:CreateSection("Upgrades")

MainTab:CreateToggle({
    Name = "Auto Buy Upgrades",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(v) S.buyUpgrades = v end,
})

MainTab:CreateDropdown({
    Name = "Pilih Upgrade",
    Options = getUpgradeList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "UpgradeSelect",
    Callback = function(sel) S.fUpgrade = sel end,
})

-- ═══════════ AUTO TAB ═══════════
AutoTab:CreateSection("Units")

AutoTab:CreateToggle({
    Name = "Auto Place Best Units",
    CurrentValue = false,
    Flag = "AutoPlace",
    Callback = function(v) S.placeBest = v end,
})

AutoTab:CreateToggle({
    Name = "Auto Equip Best",
    CurrentValue = false,
    Flag = "AutoEquip",
    Callback = function(v) S.equipBest = v end,
})

AutoTab:CreateToggle({
    Name = "Auto Equip Tower Team",
    CurrentValue = false,
    Flag = "AutoTowerTeam",
    Callback = function(v) S.towerTeam = v end,
})

AutoTab:CreateSection("Level")

AutoTab:CreateToggle({
    Name = "Auto Level Units",
    CurrentValue = false,
    Flag = "AutoLevel",
    Callback = function(v) S.levelUnits = v end,
})

LevelUnitDropdown = AutoTab:CreateDropdown({
    Name = "Pilih Unit",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "LevelUnitSelect",
    Callback = function(sel) S.fLevel = sel end,
})

AutoTab:CreateButton({
    Name = "Refresh Unit List",
    Callback = function()
        refreshUnitDropdown(LevelUnitDropdown, "LevelUnitSelect", S.fLevel)
        refreshUnitDropdown(SellUnitDropdown, "SellUnitSelect", S.fSell)
        refreshUnitDropdown(GradeUnitDropdown, "GradeUnitSelect", S.fGrade)
        refreshUnitDropdown(TraitUnitDropdown, "TraitUnitSelect", S.fTrait)
        refreshUnitDropdown(StatUnitDropdown, "StatUnitSelect", S.fStat)
        refreshUnitDropdown(FuseUnitDropdown, "FuseUnitSelect", S.fFuse)
        notify("Refresh", #getInventoryUnitEntries().." unit di inventory", 2)
    end,
})

AutoTab:CreateSection("Sell")

AutoTab:CreateToggle({
    Name = "Auto Sell Units",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(v) S.sellUnits = v end,
})

SellUnitDropdown = AutoTab:CreateDropdown({
    Name = "Pilih Unit",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SellUnitSelect",
    Callback = function(sel) S.fSell = sel end,
})

AutoTab:CreateSection("Inventory Safety")

AutoTab:CreateToggle({
    Name = "Auto Lock Valuable Units", CurrentValue = false, Flag = "LockValuables",
    Callback = function(v) S.lockValuables = v end,
})

AutoTab:CreateSection("Tower")

AutoTab:CreateToggle({
    Name = "Auto Tower Rotate",
    CurrentValue = false,
    Flag = "AutoTower",
    Callback = function(v) S.tower = v end,
})

local TowerDropdown = AutoTab:CreateDropdown({
    Name = "Pilih Tower",
    Options = getTowerList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "TowerSelect",
    Callback = function(sel) S.fTower = sel end,
})

AutoTab:CreateButton({
    Name = "Refresh Tower List",
    Callback = function()
        local towers = getTowerList()
        if TowerDropdown and TowerDropdown.Refresh then
            pcall(function() TowerDropdown:Refresh(towers, true) end)
        end
        notify("Tower", #towers.." tower terdeteksi", 2)
    end,
})

AutoTab:CreateSlider({
    Name = "Rotate Delay",
    Range = {0.5, 15},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 3,
    Flag = "TowerDelay",
    Callback = function(v) S.towerRotateDelay = v end,
})

AutoTab:CreateSection("Shop")

AutoTab:CreateToggle({
    Name = "Auto Shop",
    CurrentValue = false,
    Flag = "AutoShop",
    Callback = function(v) S.shop = v end,
})

AutoTab:CreateDropdown({
    Name = "Pilih Shop",
    Options = getShopList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ShopSelect",
    Callback = function(sel) S.fShop = sel end,
})

-- ═══════════ GRADE/TRAIT TAB ═══════════
GradeTab:CreateSection("Grade")

GradeTab:CreateToggle({
    Name = "Auto Grade",
    CurrentValue = false,
    Flag = "AutoGrade",
    Callback = function(v) S.rollGrade = v end,
})

GradeUnitDropdown = GradeTab:CreateDropdown({
    Name = "Pilih Unit",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "GradeUnitSelect",
    Callback = function(sel) S.fGrade = sel end,
})

GradeTab:CreateDropdown({
    Name = "Target Grade",
    Options = getGradeList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "GradeTargetSelect",
    Callback = function(sel) S.fGradeTarget = sel end,
})

GradeTab:CreateButton({
    Name = "Grade Sekarang",
    Callback = function() autoGradeTarget() end,
})

GradeTab:CreateSection("Trait")

GradeTab:CreateToggle({
    Name = "Auto Trait",
    CurrentValue = false,
    Flag = "AutoTrait",
    Callback = function(v) S.traitRoll = v end,
})

TraitUnitDropdown = GradeTab:CreateDropdown({
    Name = "Pilih Unit",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "TraitUnitSelect",
    Callback = function(sel) S.fTrait = sel end,
})

GradeTab:CreateDropdown({
    Name = "Target Trait",
    Options = getTraitList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "TraitTargetSelect",
    Callback = function(sel) S.fTraitTarget = sel end,
})

GradeTab:CreateButton({
    Name = "Trait Sekarang",
    Callback = function() autoTraitTarget() end,
})

GradeTab:CreateSection("Stat")

GradeTab:CreateToggle({
    Name = "Auto Stat",
    CurrentValue = false,
    Flag = "AutoStat",
    Callback = function(v) S.statUp = v end,
})

StatUnitDropdown = GradeTab:CreateDropdown({
    Name = "Pilih Unit",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "StatUnitSelect",
    Callback = function(sel) S.fStat = sel end,
})

GradeTab:CreateDropdown({
    Name = "Stat Type",
    Options = getStatList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "StatTypeSelect",
    Callback = function(sel) S.fStatType = sel end,
})

-- ═══════════ FUSE TAB ═══════════
FuseTab:CreateSection("Fuse Mode")

FuseTab:CreateToggle({
    Name = "Auto Fuse",
    CurrentValue = false,
    Flag = "AutoFuse",
    Callback = function(v) S.fuseMode = v end,
})

FuseUnitDropdown = FuseTab:CreateDropdown({
    Name = "Pilih Unit Fuse (opsional)",
    Options = getUnitNames(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "FuseUnitSelect",
    Callback = function(sel) S.fFuse = sel end,
})

FuseTab:CreateDropdown({
    Name = "Mode",
    Options = {"lowest_earnings","lowest_drop","highest_drop"},
    CurrentOption = {"lowest_earnings"},
    MultipleOptions = false,
    Flag = "FuseModeSelect",
    Callback = function(sel)
        if #sel > 0 then S.fuseModeType = sel[1] end
    end,
})

FuseTab:CreateDropdown({
    Name = "Ignore Rarity Above",
    Options = getRarityList(),
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "FuseRaritySelect",
    Callback = function(sel)
        if #sel > 0 then S.fuseIgnoreRarity = sel[1] else S.fuseIgnoreRarity = "" end
    end,
})

FuseTab:CreateButton({
    Name = "Fuse Sekarang",
    Callback = function() autoFuseMode() end,
})

FuseTab:CreateSection("Info")
FuseTab:CreateParagraph({
    Title = "Penjelasan Mode",
    Content = "lowest_earnings = fuse unit income terendah\nlowest_drop = fuse unit drop chance terendah\nhighest_drop = fuse unit drop chance tertinggi",
})

-- ═══════════ COSMETIC TAB ═══════════
CosmeticTab:CreateSection("Spin & Reward")

CosmeticTab:CreateToggle({
    Name = "Auto Claim Offline / Group", CurrentValue = false, Flag = "ClaimRewards",
    Callback = function(v) S.claimOffline = v; S.claimGroup = v end,
})


CosmeticTab:CreateToggle({
    Name = "Auto Spin",
    CurrentValue = false,
    Flag = "AutoSpin",
    Callback = function(v) S.spin = v end,
})

CosmeticTab:CreateToggle({
    Name = "Auto Daily Reward",
    CurrentValue = false,
    Flag = "AutoDaily",
    Callback = function(v) S.dailyReward = v end,
})

CosmeticTab:CreateToggle({
    Name = "Auto Luck Boost",
    CurrentValue = false,
    Flag = "AutoLuck",
    Callback = function(v) S.luckBoost = v end,
})

CosmeticTab:CreateSection("Potion & Gear")

CosmeticTab:CreateToggle({
    Name = "Auto Potion",
    CurrentValue = false,
    Flag = "AutoPotion",
    Callback = function(v) S.potion = v end,
})

CosmeticTab:CreateToggle({
    Name = "Auto Gear",
    CurrentValue = false,
    Flag = "AutoGear",
    Callback = function(v) S.gear = v end,
})

-- ═══════════ MISC TAB ═══════════
MiscTab:CreateSection("Quest")

MiscTab:CreateToggle({
    Name = "Auto Claim Quest",
    CurrentValue = false,
    Flag = "AutoQuest",
    Callback = function(v) S.claimQuest = v end,
})

MiscTab:CreateDropdown({
    Name = "Pilih Quest",
    Options = getQuestList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "QuestSelect",
    Callback = function(sel) S.fQuest = sel end,
})

MiscTab:CreateSection("Codes")

MiscTab:CreateInput({
    Name = "Input Codes",
    CurrentValue = "",
    PlaceholderText = "code1,code2,...",
    RemoveTextAfterFocusLost = false,
    Flag = "CodesInput",
    Callback = function(text)
        CODES = {}
        for c in string.gmatch(text or "", "[^,]+") do
            local t = c:gsub("^%s+", ""):gsub("%s+$", "")
            if t ~= "" then table.insert(CODES, t) end
        end
    end,
})

MiscTab:CreateToggle({
    Name = "Auto Redeem Codes",
    CurrentValue = false,
    Flag = "AutoRedeem",
    Callback = function(v)
        S.redeemCodes = v
        if v and #CODES > 0 then redeemCodes() end
    end,
})

MiscTab:CreateButton({
    Name = "Redeem Sekarang",
    Callback = function()
        if #CODES > 0 then redeemCodes() else notify("Codes", "Isi kode dulu", 2) end
    end,
})

MiscTab:CreateSection("Utility")

MiscTab:CreateToggle({
    Name = "Disable Cutscene",
    CurrentValue = false,
    Flag = "DisableCutscene",
    Callback = function(v) S.disableCutscene = v end,
})

MiscTab:CreateToggle({
    Name = "Skip Roll Cutscene",
    CurrentValue = false,
    Flag = "SkipRollCutscene",
    Callback = function(v) S.skipRollCutscene = v end,
})

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(v)
        S.antiAFK = v
        if v then startAntiAFK() else stopAntiAFK() end
    end,
})

MiscTab:CreateButton({
    Name = "Server Hop",
    Callback = function() serverHop() end,
})

-- ═══════════ PERFORMANCE TAB ═══════════
PerfTab:CreateSection("Auto Clean")

PerfTab:CreateToggle({
    Name = "Auto Lag Fix",
    CurrentValue = false,
    Flag = "AutoLagFix",
    Callback = function(v) S.autoLagFix = v end,
})

PerfTab:CreateSlider({
    Name = "Interval Lag Fix",
    Range = {2, 30},
    Increment = 1,
    Suffix = "s",
    CurrentValue = 8,
    Flag = "LagFixInterval",
    Callback = function(v) S.lagFixInterval = v end,
})

PerfTab:CreateSection("Manual Clean")

PerfTab:CreateButton({
    Name = "Delete Decorations",
    Callback = function()
        local n = deleteDeco(); notify("Clean", "-"..n.." deco", 2)
    end,
})

PerfTab:CreateButton({
    Name = "Delete FX / Particles",
    Callback = function()
        local n = deleteFX(); notify("Clean", "-"..n.." FX", 2)
    end,
})

PerfTab:CreateButton({
    Name = "Disable Lighting",
    Callback = function()
        local n = disableLighting(); notify("Clean", "-"..n.." effects", 2)
    end,
})

PerfTab:CreateButton({
    Name = "Delete Sounds",
    Callback = function()
        local n = deleteSounds(); notify("Clean", "-"..n.." sounds", 2)
    end,
})

PerfTab:CreateButton({
    Name = "Remove Other Players",
    Callback = function()
        local n = removePlayers(); notify("Clean", "-"..n.." chars", 2)
    end,
})

PerfTab:CreateSection("Delete Map")

PerfTab:CreateToggle({
    Name = "Auto Delete Map",
    CurrentValue = false,
    Flag = "AutoDeleteMap",
    Callback = function(v) S.autoDeleteMap = v end,
})

PerfTab:CreateDropdown({
    Name = "Mode",
    Options = {"safe","aggressive","full"},
    CurrentOption = {"safe"},
    MultipleOptions = false,
    Flag = "DeleteMapMode",
    Callback = function(sel)
        if #sel > 0 then S.deleteMapMode = sel[1] end
    end,
})

PerfTab:CreateSlider({
    Name = "Interval Delete Map",
    Range = {5, 60},
    Increment = 1,
    Suffix = "s",
    CurrentValue = 15,
    Flag = "DeleteMapInterval",
    Callback = function(v) S.deleteMapInterval = v end,
})

PerfTab:CreateButton({
    Name = "Delete Map Sekarang",
    Callback = function() deleteMap(S.deleteMapMode) end,
})

-- ═══════════ DEBUG TAB ═══════════
DebugTab:CreateSection("Remotes ("..#RemoteList..")")

local debugPara = DebugTab:CreateParagraph({
    Title = "Remote List",
    Content = "Loading...",
})

local function refreshDebug()
    local lines = {}
    for i, r in ipairs(RemoteList) do
        if i > 60 then table.insert(lines, "... +"..(#RemoteList-60).." lagi"); break end
        table.insert(lines, "["..r.type.."] "..r.path)
    end
    debugPara:Set({ Content = table.concat(lines, "\n") })
end
refreshDebug()

DebugTab:CreateButton({
    Name = "Re-scan Remotes",
    Callback = function()
        discover(); refreshDebug()
        notify("Debug", #RemoteList.." remotes", 2)
    end,
})

DebugTab:CreateButton({
    Name = "Dump ke Console (F9)",
    Callback = function()
        print("=== GOBEY REMOTES ===")
        for i, r in ipairs(RemoteList) do
            print(string.format("[%d] (%s) %s", i, r.type, r.path))
        end
        print("=== END ===")
        notify("Debug", "Cek console F9", 3)
    end,
})

DebugTab:CreateButton({
    Name = "Fire 'Collect' Semua",
    Callback = function() fireAll({"Collect","Claim"}) end,
})

-- ═══════════ MAIN LOOP ═══════════
task.spawn(function()
    while true do
        task.wait(S.loopDelay)
        if S.collectCash   then pcall(autoCollect) end
        if S.rebirth       then pcall(autoRebirth) end
        if S.buyBestDice   then pcall(autoBuyDice) end
        if S.equipBestDice then pcall(autoEquipBestDiceController) end
        if S.useSpins      then pcall(autoUseAvailableSpins) end
        if S.useBoosts     then pcall(autoUseAvailableBoosts) end
        if S.claimOffline or S.claimGroup then pcall(autoClaimRewardsController) end
        if S.placeBest      then pcall(autoPlaceBest) end
        if S.equipBest      then pcall(autoEquipBest) end
        if S.towerTeam      then pcall(autoTowerTeam) end
        if S.levelUnits     then pcall(autoLevelUnits) end
        if S.sellUnits      then pcall(autoSellUnits) end
        if S.lockValuables  then pcall(autoLockValuablesController) end
        if S.fuseMode       then pcall(autoFuseMode) end
        if S.rollGrade      then pcall(autoGradeTarget) end
        if S.traitRoll      then pcall(autoTraitTarget) end
        if S.statUp         then pcall(autoStatUp) end
        if S.buyUpgrades    then pcall(autoUpgradeBuy) end
        if S.claimQuest     then pcall(autoQuestClaim) end
        if S.shop           then pcall(autoShopBuy) end
        if S.spin           then pcall(autoSpin) end
        if S.dailyReward    then pcall(autoDaily) end
        if S.luckBoost      then pcall(autoLuck) end
        if S.potion         then pcall(autoPotion) end
        if S.gear           then pcall(autoGear) end
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

-- ═══════════ AUTO START ANTI AFK ═══════════
-- Anti-AFK tidak dipaksa ON; mengikuti toggle UI agar konfigurasi user dihormati.

-- ═══════════ NOTIFY ═══════════
notify("GOBEY HUB v4.1", #RemoteList.." remotes / "..#getUnitNames().." unit", 5)
print("[GOBEY HUB v4.1] Loaded. Remotes: "..#RemoteList)