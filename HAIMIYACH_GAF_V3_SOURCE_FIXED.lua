-- ============================================================
-- HAIMIYACH_GAF_V3_SOURCE_FIXED.lua
-- Grow a Chicken Fighter - Executor Edition
--
-- UI base:
--   HAIMIYACH Sudoku V9 compact/mobile pattern
--   + TAB system so the menu does not become excessively long.
--
-- SOURCE-BACKED GAME DATA:
--   DataService.client:get({"roster"})
--   DataService.client:get({"coop"})
--   DataService.client:get({"tower"})
--   DataService.client:get({"scrap"})
--   DataService.client:get({"rebirth"})
--
-- SOURCE-BACKED REMOTES:
--   HatchEgg(eggId)
--   HatchEggs(eggId, amount) [not used by default]
--   FuseChickens(idA, idB, thirdArg, nil, fifthArg)
--   UpgradeRecycler()
--   Rebirth()
--   ExpandCoop()
--   BuyGenerator(slot)
--   UpgradeGenerator(slot)
--   TowerStart([floorIndex])
--
-- Tower / Chaos / No Thanks:
--   Uses the actual visible HUD buttons instead of inventing remotes.
--
-- Scrap:
--   The supplied source exposes scrap.positions + scrap.taken.
--   No reliable client pickup remote was found in the supplied source.
--   Therefore Auto Grab Scraps teleports to an available scrap position.
--   Auto Recycle teleports to the player's Recycler origin.
--
-- Event:
--   Workspace attributes:
--      EventId
--      EventPhase
--      EventDeadline
--   Event phases are idle / warmup / live.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEAN PREVIOUS INSTANCE
-- ============================================================

pcall(function()
    local old = PlayerGui:FindFirstChild("HAIMIYACH_GAF_V3")
    if old then
        old:Destroy()
    end
end)

math.randomseed(math.floor(os.clock() * 1000000) % 2147483647)

-- ============================================================
-- SAFE HELPERS
-- ============================================================

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HAIMIYACH"),
            Text = tostring(text or ""),
            Duration = duration or 2
        })
    end)
end

local function safeRequire(module)
    if not module or not module:IsA("ModuleScript") then
        return nil
    end

    local ok, result = pcall(require, module)
    if ok then
        return result
    end

    return nil
end

local function findModule(root, name)
    if not root then
        return nil
    end

    local direct = root:FindFirstChild(name)
    if direct and direct:IsA("ModuleScript") then
        return direct
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == name and obj:IsA("ModuleScript") then
            return obj
        end
    end

    return nil
end

-- ============================================================
-- GAME MODULE ACCESS
-- ============================================================

local Remotes = nil
local DataClient = nil
local ChickenMode = nil
local RecyclerView = nil
local CoopView = nil

local function loadModules()
    -- Exact source path.
    pcall(function()
        local core = ReplicatedStorage:FindFirstChild("Core")
        local remoteModule = core and core:FindFirstChild("Remotes")
        Remotes = safeRequire(remoteModule)
    end)

    pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local dataService = packages and packages:FindFirstChild("DataService")
        local result = safeRequire(dataService)

        if result and type(result) == "table" and result.client then
            DataClient = result.client
        end
    end)

    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        ChickenMode = safeRequire(findModule(ps, "ChickenMode"))
    end)

    pcall(function()
        RecyclerView = safeRequire(findModule(ReplicatedStorage, "RecyclerView"))
    end)

    pcall(function()
        CoopView = safeRequire(findModule(ReplicatedStorage, "CoopView"))
    end)
end

loadModules()

local function getState(path)
    if not DataClient or type(DataClient.get) ~= "function" then
        return nil
    end

    local ok, result = pcall(function()
        return DataClient:get(path)
    end)

    if ok then
        return result
    end

    return nil
end

local function invokeDef(name, ...)
    if not Remotes or type(Remotes.invoke) ~= "function" then
        return nil, "Remotes unavailable"
    end

    if type(Remotes.defs) ~= "table" then
        return nil, "Remote definitions unavailable"
    end

    local def = Remotes.defs[name]
    if not def then
        return nil, "Remote definition missing: " .. tostring(name)
    end

    local ok, result = pcall(function()
        return Remotes.invoke(def, ...)
    end)

    if not ok then
        return nil, tostring(result)
    end

    return result
end

local function fireDef(name, ...)
    if not Remotes or type(Remotes.fire) ~= "function" then
        return false, "Remotes unavailable"
    end

    if type(Remotes.defs) ~= "table" then
        return false, "Remote definitions unavailable"
    end

    local def = Remotes.defs[name]
    if not def then
        return false, "Remote definition missing: " .. tostring(name)
    end

    local ok, err = pcall(function()
        Remotes.fire(def, ...)
    end)

    return ok, ok and nil or tostring(err)
end

local function resultOK(result)
    return type(result) == "table" and result.ok == true
end

-- ============================================================
-- STATE
-- ============================================================

local S = {
    autoEgg = false,
    selectedEgg = "AUTO",
    eggAmount = 1,

    autoFuse = false,
    fuseMode = "Same Type",
    fuseRarity = "Any",
    keepFavorite = true,

    autoScrap = false,
    scrapMode = "Nearest",

    autoRecycle = false,

    autoRecycler = false,
    autoRebirth = false,

    autoCoop = false,
    coopMode = "Upgrade All",

    autoFeeders = false,
    feederMode = "Buy + Upgrade",

    autoTower = false,
    autoChaos = false,
    autoEventChaos = false,
    autoNoThanks = false,

    antiAFK = true
}

local RunIds = {
    autoEgg = 0,
    autoFuse = 0,
    autoScrap = 0,
    autoRecycle = 0,
    autoRecycler = 0,
    autoRebirth = 0,
    autoCoop = 0,
    autoFeeders = 0,
    autoTower = 0,
    autoChaos = 0,
    autoEventChaos = 0,
    autoNoThanks = 0
}

-- ============================================================
-- CHARACTER / TELEPORT
-- ============================================================

local function characterRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(positionOrCFrame)
    local root = characterRoot()
    if not root or not positionOrCFrame then
        return false
    end

    local cf

    if typeof(positionOrCFrame) == "CFrame" then
        cf = positionOrCFrame
    elseif typeof(positionOrCFrame) == "Vector3" then
        cf = CFrame.new(positionOrCFrame)
    else
        return false
    end

    return pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = cf
    end)
end

local function pivotOf(obj)
    if not obj then
        return nil
    end

    local ok, result = pcall(function()
        if obj:IsA("BasePart") then
            return obj.CFrame
        end

        if obj:IsA("Model") then
            return obj:GetPivot()
        end

        return nil
    end)

    return ok and result or nil
end

-- ============================================================
-- EGG
-- ============================================================

local function getEggCounts()
    local roster = getState({"roster"})
    local eggs = roster and roster.eggs

    if type(eggs) == "table" then
        return eggs
    end

    return {}
end

local function getEggList()
    local list = {}

    for id, count in pairs(getEggCounts()) do
        if tonumber(count) and tonumber(count) > 0 then
            table.insert(list, tostring(id))
        end
    end

    table.sort(list)
    table.insert(list, 1, "AUTO")

    return list
end

local function chooseEgg()
    local counts = getEggCounts()

    if S.selectedEgg ~= "AUTO" then
        local count = tonumber(counts[S.selectedEgg]) or 0
        if count > 0 then
            return S.selectedEgg
        end
    end

    local bestId
    local bestCount = 0

    for id, count in pairs(counts) do
        count = tonumber(count) or 0

        if count > bestCount then
            bestId = id
            bestCount = count
        end
    end

    return bestId
end

local function hatchOne()
    local eggId = chooseEgg()

    if not eggId then
        return false, "No egg available"
    end

    local result, err = invokeDef("HatchEgg", eggId)

    if resultOK(result) then
        return true
    end

    local reason = type(result) == "table" and result.error
    return false, tostring(reason or err or "Hatch failed")
end

local function startEggLoop()
    RunIds.autoEgg = RunIds.autoEgg + 1
    local run = RunIds.autoEgg

    task.spawn(function()
        while S.autoEgg and run == RunIds.autoEgg do
            local amount = math.floor(tonumber(S.eggAmount) or 1)
            amount = math.clamp(amount, 1, 25)

            local success = false

            for _ = 1, amount do
                if not S.autoEgg or run ~= RunIds.autoEgg then
                    break
                end

                local ok = hatchOne()
                success = success or ok
                task.wait(0.45)
            end

            if not success then
                task.wait(1.5)
            end
        end
    end)
end

local function setAutoEgg(value)
    S.autoEgg = value == true
    RunIds.autoEgg = RunIds.autoEgg + 1

    if S.autoEgg then
        startEggLoop()
        notify("Auto Open Eggs", "ON • " .. tostring(S.selectedEgg), 2)
    else
        notify("Auto Open Eggs", "OFF", 2)
    end
end

-- ============================================================
-- FUSION
-- ============================================================

local rarityRank = {
    common = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
    mythic = 6,
    divine = 7,
    eternal = 8,
    transcendent = 9,
    omega = 10
}

local function chickenList()
    local roster = getState({"roster"})
    local chickens = roster and roster.chickens
    local list = {}

    if type(chickens) ~= "table" then
        return list
    end

    for _, chicken in pairs(chickens) do
        if type(chicken) == "table" and chicken.id then
            table.insert(list, chicken)
        end
    end

    return list
end

local function rarityAllowed(chicken)
    if S.fuseRarity == "Any" then
        return true
    end

    return string.lower(tostring(chicken.rarity or "common"))
        == string.lower(S.fuseRarity)
end

local function findFusePair()
    local groups = {}

    for _, chicken in ipairs(chickenList()) do
        local favorite = chicken.favorite == true
        local active = chicken.active == true

        if (not S.keepFavorite or not favorite)
            and not active
            and rarityAllowed(chicken) then

            local key

            if S.fuseMode == "Same Type" then
                key = tostring(chicken.typeId)
            elseif S.fuseMode == "Same Rarity" then
                key = string.lower(tostring(chicken.rarity or "common"))
            else
                key = "ALL"
            end

            groups[key] = groups[key] or {}
            table.insert(groups[key], chicken)
        end
    end

    for _, group in pairs(groups) do
        if #group >= 2 then
            table.sort(group, function(a, b)
                return (tonumber(a.level) or 1) < (tonumber(b.level) or 1)
            end)

            return group[1], group[2]
        end
    end

    return nil, nil
end

local function fuseOne()
    local a, b = findFusePair()

    if not a or not b then
        return false
    end

    local result = invokeDef(
        "FuseChickens",
        a.id,
        b.id,
        nil,
        nil,
        nil
    )

    return resultOK(result)
end

local function startFuseLoop()
    RunIds.autoFuse = RunIds.autoFuse + 1
    local run = RunIds.autoFuse

    task.spawn(function()
        while S.autoFuse and run == RunIds.autoFuse do
            local ok = fuseOne()
            task.wait(ok and 0.75 or 1.5)
        end
    end)
end

local function setAutoFuse(value)
    S.autoFuse = value == true
    RunIds.autoFuse = RunIds.autoFuse + 1

    if S.autoFuse then
        startFuseLoop()
        notify("Auto Fuse", "ON • " .. S.fuseMode, 2)
    else
        notify("Auto Fuse", "OFF", 2)
    end
end

-- ============================================================
-- SCRAP
-- ============================================================

local function getScrapState()
    local state = getState({"scrap"})
    return type(state) == "table" and state or nil
end

local function getAvailableScrap()
    local scrap = getScrapState()

    if not scrap or type(scrap.positions) ~= "table" then
        return nil
    end

    local root = characterRoot()
    local bestPosition
    local bestDistance = math.huge
    local firstPosition

    for index, position in pairs(scrap.positions) do
        if not scrap.taken or not scrap.taken[index] then
            if typeof(position) == "Vector3" then
                firstPosition = firstPosition or position

                if S.scrapMode == "First" or not root then
                    bestPosition = firstPosition
                    if S.scrapMode == "First" then
                        break
                    end
                else
                    local distance = (position - root.Position).Magnitude

                    if distance < bestDistance then
                        bestDistance = distance
                        bestPosition = position
                    end
                end
            end
        end
    end

    return bestPosition
end

local function recyclerCF()
    local plotId = LocalPlayer:GetAttribute("Plot")
    local recyclers = Workspace:FindFirstChild("Recyclers")

    if not recyclers then
        return nil
    end

    if plotId ~= nil then
        local recycler = recyclers:FindFirstChild("Recycler" .. tostring(plotId))
        local cf = pivotOf(recycler)

        if cf then
            return cf
        end
    end

    -- Safe fallback: nearest recycler.
    local root = characterRoot()
    local nearest
    local distance = math.huge

    for _, obj in ipairs(recyclers:GetChildren()) do
        local cf = pivotOf(obj)

        if cf then
            if not root then
                return cf
            end

            local d = (cf.Position - root.Position).Magnitude
            if d < distance then
                distance = d
                nearest = cf
            end
        end
    end

    return nearest
end

local function startScrapLoop()
    RunIds.autoScrap = RunIds.autoScrap + 1
    local run = RunIds.autoScrap

    task.spawn(function()
        while S.autoScrap and run == RunIds.autoScrap do
            local position = getAvailableScrap()

            if position then
                teleportTo(position + Vector3.new(0, 2.5, 0))
                task.wait(0.7)
            else
                task.wait(1)
            end
        end
    end)
end

local function setAutoScrap(value)
    S.autoScrap = value == true
    RunIds.autoScrap = RunIds.autoScrap + 1

    if S.autoScrap then
        startScrapLoop()
        notify("Auto Grab Scraps", "Teleport mode ON", 2)
    else
        notify("Auto Grab Scraps", "OFF", 2)
    end
end

local function startRecycleLoop()
    RunIds.autoRecycle = RunIds.autoRecycle + 1
    local run = RunIds.autoRecycle

    task.spawn(function()
        while S.autoRecycle and run == RunIds.autoRecycle do
            local recycler = recyclerCF()

            if recycler then
                teleportTo(recycler + Vector3.new(0, 3, 0))
            end

            task.wait(1)
        end
    end)
end

local function setAutoRecycle(value)
    S.autoRecycle = value == true
    RunIds.autoRecycle = RunIds.autoRecycle + 1

    if S.autoRecycle then
        startRecycleLoop()
        notify("Auto Recycle Scrap", "Teleport to Recycler ON", 2)
    else
        notify("Auto Recycle Scrap", "OFF", 2)
    end
end

-- ============================================================
-- RECYCLER / REBIRTH
-- ============================================================

local function upgradeRecycler()
    local result = invokeDef("UpgradeRecycler")
    return resultOK(result)
end

local function startRecyclerLoop()
    RunIds.autoRecycler = RunIds.autoRecycler + 1
    local run = RunIds.autoRecycler

    task.spawn(function()
        while S.autoRecycler and run == RunIds.autoRecycler do
            upgradeRecycler()
            task.wait(1.25)
        end
    end)
end

local function setAutoRecycler(value)
    S.autoRecycler = value == true
    RunIds.autoRecycler = RunIds.autoRecycler + 1

    if S.autoRecycler then
        startRecyclerLoop()
        notify("Auto Upgrade Recycler", "ON", 2)
    else
        notify("Auto Upgrade Recycler", "OFF", 2)
    end
end

local function rebirthOnce()
    local result = invokeDef("Rebirth")
    return resultOK(result)
end

local function startRebirthLoop()
    RunIds.autoRebirth = RunIds.autoRebirth + 1
    local run = RunIds.autoRebirth

    task.spawn(function()
        while S.autoRebirth and run == RunIds.autoRebirth do
            rebirthOnce()
            task.wait(3)
        end
    end)
end

local function setAutoRebirth(value)
    S.autoRebirth = value == true
    RunIds.autoRebirth = RunIds.autoRebirth + 1

    if S.autoRebirth then
        startRebirthLoop()
        notify("Auto Rebirth", "ON • server eligibility check", 2)
    else
        notify("Auto Rebirth", "OFF", 2)
    end
end

-- ============================================================
-- COOP / FEEDERS
-- ============================================================

local function getCoop()
    local coop = getState({"coop"})
    return type(coop) == "table" and coop or nil
end

local function expandCoop()
    local result = invokeDef("ExpandCoop")
    return resultOK(result)
end

local function buyGenerator(slot)
    local result = invokeDef("BuyGenerator", slot)
    return resultOK(result)
end

local function upgradeGenerator(slot)
    local result = invokeDef("UpgradeGenerator", slot)
    return resultOK(result)
end

local function startCoopLoop()
    RunIds.autoCoop = RunIds.autoCoop + 1
    local run = RunIds.autoCoop

    task.spawn(function()
        while S.autoCoop and run == RunIds.autoCoop do
            local coop = getCoop()

            if coop and type(coop.generators) == "table" then
                for _, generator in pairs(coop.generators) do
                    if not S.autoCoop or run ~= RunIds.autoCoop then
                        break
                    end

                    if S.coopMode ~= "Expand Only"
                        and generator
                        and generator.slot then

                        upgradeGenerator(generator.slot)
                        task.wait(0.4)
                    end
                end
            end

            if S.coopMode ~= "Upgrade Only" then
                expandCoop()
            end

            task.wait(2)
        end
    end)
end

local function setAutoCoop(value)
    S.autoCoop = value == true
    RunIds.autoCoop = RunIds.autoCoop + 1

    if S.autoCoop then
        startCoopLoop()
        notify("Auto Upgrade Coop", "ON • " .. S.coopMode, 2)
    else
        notify("Auto Upgrade Coop", "OFF", 2)
    end
end

local function startFeederLoop()
    RunIds.autoFeeders = RunIds.autoFeeders + 1
    local run = RunIds.autoFeeders

    task.spawn(function()
        while S.autoFeeders and run == RunIds.autoFeeders do
            local coop = getCoop()

            if coop and type(coop.generators) == "table" then
                local count = 0
                local maxSlots = tonumber(coop.slots) or 1

                for _, generator in pairs(coop.generators) do
                    if not S.autoFeeders or run ~= RunIds.autoFeeders then
                        break
                    end

                    if generator and generator.slot then
                        count = count + 1

                        if S.feederMode ~= "Buy Only" then
                            upgradeGenerator(generator.slot)
                            task.wait(0.35)
                        end
                    end
                end

                if S.feederMode ~= "Upgrade Only" then
                    if count < maxSlots then
                        buyGenerator(count + 1)
                    elseif count == 0 then
                        buyGenerator(1)
                    end
                end
            end

            task.wait(2)
        end
    end)
end

local function setAutoFeeders(value)
    S.autoFeeders = value == true
    RunIds.autoFeeders = RunIds.autoFeeders + 1

    if S.autoFeeders then
        startFeederLoop()
        notify("Auto Buy Feeders", "ON • " .. S.feederMode, 2)
    else
        notify("Auto Buy Feeders", "OFF", 2)
    end
end

-- ============================================================
-- HUD BUTTONS
-- ============================================================

local function normalizeText(value)
    return string.lower(tostring(value or "")):gsub("[%p]", " ")
end

local function clickHUDButton(words)
    local matches = {}

    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton")
            and obj.Visible
            and obj.Active then

            local text = normalizeText(obj.Text)
            local ok = true

            for _, word in ipairs(words) do
                if not text:find(string.lower(word), 1, true) then
                    ok = false
                    break
                end
            end

            if ok then
                table.insert(matches, obj)
            end
        end
    end

    -- Prefer the smallest matching visible button with the shortest text.
    table.sort(matches, function(a, b)
        return #tostring(a.Text) < #tostring(b.Text)
    end)

    local button = matches[1]

    if button then
        local ok = pcall(function()
            button:Activate()
        end)

        return ok
    end

    return false
end

local function currentOrder()
    if ChickenMode and type(ChickenMode.order) == "function" then
        local ok, value = pcall(ChickenMode.order)
        if ok then
            return value
        end
    end

    return nil
end

local function startTowerOnce()
    if currentOrder() == "tower" then
        return false
    end

    return clickHUDButton({"tower"})
end

local function startChaosOnce()
    if currentOrder() == "chaos" then
        return false
    end

    return clickHUDButton({"chaos"})
end

local function startTowerLoop()
    RunIds.autoTower = RunIds.autoTower + 1
    local run = RunIds.autoTower

    task.spawn(function()
        while S.autoTower and run == RunIds.autoTower do
            startTowerOnce()
            task.wait(1.5)
        end
    end)
end

local function setAutoTower(value)
    S.autoTower = value == true
    RunIds.autoTower = RunIds.autoTower + 1

    if S.autoTower then
        startTowerLoop()
        notify("Auto Start Tower", "ON", 2)
    else
        notify("Auto Start Tower", "OFF", 2)
    end
end

local function startChaosLoop()
    RunIds.autoChaos = RunIds.autoChaos + 1
    local run = RunIds.autoChaos

    task.spawn(function()
        while S.autoChaos and run == RunIds.autoChaos do
            startChaosOnce()
            task.wait(1.5)
        end
    end)
end

local function setAutoChaos(value)
    S.autoChaos = value == true
    RunIds.autoChaos = RunIds.autoChaos + 1

    if S.autoChaos then
        startChaosLoop()
        notify("Auto Start Chaos", "ON", 2)
    else
        notify("Auto Start Chaos", "OFF", 2)
    end
end

-- ============================================================
-- WORLD EVENTS
-- ============================================================

local function getEvent()
    local id = Workspace:GetAttribute("EventId")
    local phase = Workspace:GetAttribute("EventPhase")
    local deadline = Workspace:GetAttribute("EventDeadline")

    if not id or not phase or not deadline then
        return nil
    end

    if phase ~= "warmup" and phase ~= "live" then
        return nil
    end

    return {
        id = id,
        phase = phase,
        deadline = deadline
    }
end

local function eventRemaining(event)
    local deadline = tonumber(event and event.deadline)

    if not deadline then
        return 0
    end

    local ok, serverNow = pcall(function()
        return Workspace:GetServerTimeNow()
    end)

    if ok and tonumber(serverNow) then
        return math.max(0, deadline - serverNow)
    end

    return 0
end

local function cancelChaosOnce()
    if currentOrder() ~= "chaos" then
        return false
    end

    -- In the supplied HUD source, the same bottom HUD action changes
    -- to the CANCEL action while order == "chaos".
    return clickHUDButton({"cancel"})
        or clickHUDButton({"recall"})
end

local function startEventChaosLoop()
    RunIds.autoEventChaos = RunIds.autoEventChaos + 1
    local run = RunIds.autoEventChaos

    task.spawn(function()
        local lastEventId = nil
        local eventChaosStarted = false

        while S.autoEventChaos and run == RunIds.autoEventChaos do
            local event = getEvent()

            if event then
                if tostring(event.id) ~= tostring(lastEventId) then
                    lastEventId = event.id

                    if currentOrder() ~= "chaos" then
                        eventChaosStarted = startChaosOnce() or eventChaosStarted
                    end

                    notify(
                        "Auto Event Chaos",
                        "Event: " .. tostring(event.id)
                            .. " • " .. tostring(event.phase),
                        2
                    )
                end
            else
                -- Only cancel chaos if THIS feature started it.
                -- This prevents Auto Event Chaos from cancelling a
                -- manually started/normal Auto Chaos run.
                if eventChaosStarted then
                    cancelChaosOnce()
                    eventChaosStarted = false
                    notify("Auto Event Chaos", "Event ended • Chaos cancelled.", 2)
                end

                lastEventId = nil
            end

            task.wait(0.75)
        end

        -- If the toggle itself is turned off while our event-chaos run
        -- is active, cancel only the chaos that this feature started.
        if eventChaosStarted then
            cancelChaosOnce()
        end
    end)
end

local function setAutoEventChaos(value)
    S.autoEventChaos = value == true
    RunIds.autoEventChaos = RunIds.autoEventChaos + 1

    if S.autoEventChaos then
        startEventChaosLoop()
        notify("Auto Event Chaos", "Watching Workspace EventId/EventPhase", 2)
    else
        notify("Auto Event Chaos", "OFF", 2)
    end
end

-- ============================================================
-- NO THANKS
-- ============================================================

local function noThanksOnce()
    return clickHUDButton({"no", "thanks"})
        or clickHUDButton({"no thanks"})
end

local function startNoThanksLoop()
    RunIds.autoNoThanks = RunIds.autoNoThanks + 1
    local run = RunIds.autoNoThanks

    task.spawn(function()
        while S.autoNoThanks and run == RunIds.autoNoThanks do
            noThanksOnce()
            task.wait(0.8)
        end
    end)
end

local function setAutoNoThanks(value)
    S.autoNoThanks = value == true
    RunIds.autoNoThanks = RunIds.autoNoThanks + 1

    if S.autoNoThanks then
        startNoThanksLoop()
        notify("Auto No Thanks", "ON", 2)
    else
        notify("Auto No Thanks", "OFF", 2)
    end
end

-- ============================================================
-- ANTI AFK
-- ============================================================

local antiAFKConnection

local function setAntiAFK(value)
    S.antiAFK = value == true

    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end

    if not S.antiAFK then
        return
    end

    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")

        antiAFKConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end

setAntiAFK(true)

-- ============================================================
-- GUI ROOT - SAME COMPACT STYLE FAMILY AS SUDOKU V9
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HAIMIYACH_GAF_V3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

local guiWidth = math.clamp(math.floor(viewport.X * 0.38), 220, 270)
local guiHeight = math.clamp(math.floor(viewport.Y * 0.58), 320, 390)

local Window = Instance.new("Frame")
Window.Name = "HAIMIYACH"
Window.Size = UDim2.fromOffset(guiWidth, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 7)
    c.Parent = obj
end

local function stroke(obj, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(61, 63, 72)
    s.Thickness = 1
    s.Transparency = transparency or 0.4
    s.Parent = obj
end

corner(Window, 8)
stroke(Window, 0.2)

-- ============================================================
-- HEADER
-- ============================================================

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window
corner(Header, 8)

local HeaderBottomFill = Instance.new("Frame")
HeaderBottomFill.Name = "HeaderBottomFill"
HeaderBottomFill.Size = UDim2.new(1, 0, 0, 10)
HeaderBottomFill.Position = UDim2.new(0, 0, 1, -10)
HeaderBottomFill.BackgroundColor3 = Header.BackgroundColor3
HeaderBottomFill.BorderSizePixel = 0
HeaderBottomFill.Parent = Header

local Brand = Instance.new("TextLabel")
Brand.Size = UDim2.new(1, -80, 0, 20)
Brand.Position = UDim2.fromOffset(12, 4)
Brand.BackgroundTransparency = 1
Brand.Text = "HAIMIYACH"
Brand.TextColor3 = Color3.fromRGB(245, 246, 249)
Brand.Font = Enum.Font.GothamBold
Brand.TextSize = 12
Brand.TextXAlignment = Enum.TextXAlignment.Left
Brand.Parent = Header

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -80, 0, 11)
Sub.Position = UDim2.fromOffset(12, 25)
Sub.BackgroundTransparency = 1
Sub.Text = "GROW A CHICKEN FIGHTER"
Sub.TextColor3 = Color3.fromRGB(123, 126, 137)
Sub.Font = Enum.Font.GothamMedium
Sub.TextSize = 6
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(26, 26)
Close.Position = UDim2.new(1, -33, 0, 7)
Close.BackgroundColor3 = Color3.fromRGB(44, 45, 52)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(205, 207, 214)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header
corner(Close, 7)

-- ============================================================
-- WINDOW DRAG
-- ============================================================

local dragging = false
local dragStart
local dragPos
local dragConnection

Header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    dragging = true
    dragStart = input.Position
    dragPos = Window.Position

    if dragConnection then
        dragConnection:Disconnect()
    end

    dragConnection = UserInputService.InputChanged:Connect(function(move)
        if not dragging then
            return
        end

        if move.UserInputType ~= Enum.UserInputType.Touch
            and move.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = move.Position - dragStart

        Window.Position = UDim2.new(
            dragPos.X.Scale,
            dragPos.X.Offset + delta.X,
            dragPos.Y.Scale,
            dragPos.Y.Offset + delta.Y
        )
    end)

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false

            if dragConnection then
                dragConnection:Disconnect()
                dragConnection = nil
            end
        end
    end)
end)

-- ============================================================
-- FLOATING BUTTON
-- ============================================================

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(88, 30)
OpenButton.Position = UDim2.new(0.5, -44, 0, 8)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BackgroundTransparency = 0.15
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "HAIMIYACH"
OpenButton.TextColor3 = Color3.fromRGB(240, 241, 245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui
corner(OpenButton, 16)
stroke(OpenButton, 0.25)

local floatingDragging = false
local floatingMoved = false
local floatingStart
local floatingPos
local floatingConnection

OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    floatingDragging = true
    floatingMoved = false
    floatingStart = input.Position
    floatingPos = OpenButton.Position

    if floatingConnection then
        floatingConnection:Disconnect()
    end

    floatingConnection = UserInputService.InputChanged:Connect(function(move)
        if not floatingDragging then
            return
        end

        if move.UserInputType ~= Enum.UserInputType.Touch
            and move.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = move.Position - floatingStart

        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            floatingMoved = true
        end

        OpenButton.Position = UDim2.new(
            floatingPos.X.Scale,
            floatingPos.X.Offset + delta.X,
            floatingPos.Y.Scale,
            floatingPos.Y.Offset + delta.Y
        )
    end)

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            local moved = floatingMoved

            floatingDragging = false

            if floatingConnection then
                floatingConnection:Disconnect()
                floatingConnection = nil
            end

            if not moved then
                Window.Visible = true
                OpenButton.Visible = false
            end
        end
    end)
end)

local function closeWindow()
    Window.Visible = false
    OpenButton.Visible = true
end

Close.Activated:Connect(closeWindow)

-- ============================================================
-- TAB BAR
-- ============================================================

local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -12, 0, 32)
TabBar.Position = UDim2.fromOffset(6, 44)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.CanvasSize = UDim2.new()
TabBar.Active = true
TabBar.Parent = Window

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 2)
tabPad.PaddingRight = UDim.new(0, 2)
tabPad.Parent = TabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = TabBar

local PageHolder = Instance.new("Frame")
PageHolder.Name = "Pages"
PageHolder.Size = UDim2.new(1, -12, 1, -82)
PageHolder.Position = UDim2.fromOffset(6, 78)
PageHolder.BackgroundTransparency = 1
PageHolder.ClipsDescendants = true
PageHolder.Parent = Window

local Pages = {}
local Tabs = {}

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(90, 93, 104)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Active = true
    page.Parent = PageHolder

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Pages[name] = page
    return page
end

local function makeTab(name, icon, order)
    local b = Instance.new("TextButton")
    b.Name = name .. "Tab"
    b.Size = UDim2.fromOffset(72, 27)
    b.BackgroundColor3 = Color3.fromRGB(43, 44, 51)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = icon .. " " .. name
    b.TextColor3 = Color3.fromRGB(164, 166, 175)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 7
    b.LayoutOrder = order
    b.Parent = TabBar
    corner(b, 6)
    Tabs[name] = b
    return b
end

local function selectTab(name)
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end

    for tabName, button in pairs(Tabs) do
        local selected = tabName == name

        button.BackgroundColor3 = selected
            and Color3.fromRGB(72, 74, 84)
            or Color3.fromRGB(43, 44, 51)

        button.TextColor3 = selected
            and Color3.fromRGB(245, 246, 249)
            or Color3.fromRGB(164, 166, 175)
    end
end

-- ============================================================
-- UI HELPERS
-- ============================================================

local function section(page, text, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(112, 115, 127)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 7
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = page
    return label
end

local function action(page, text, icon, order, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.LayoutOrder = order
    button.Parent = page
    corner(button, 7)
    stroke(button)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(22, 34)
    iconLabel.Position = UDim2.fromOffset(6, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(190, 193, 202)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 10
    iconLabel.Parent = button

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -44, 1, 0)
    title.Position = UDim2.fromOffset(30, 0)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = Color3.fromRGB(226, 228, 235)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 8
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = button

    button.Activated:Connect(function()
        pcall(callback)
    end)

    return button
end

local function toggleRow(page, text, order, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -78, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226, 228, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(48, 22)
    toggle.Position = UDim2.new(1, -58, 0.5, -11)
    toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = "OFF"
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 7
    toggle.TextColor3 = Color3.fromRGB(220, 220, 225)
    toggle.Parent = row
    corner(toggle, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    corner(knob, 8)

    local function redraw()
        local enabled = false

        pcall(function()
            enabled = getter() == true
        end)

        toggle.Text = enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = enabled
            and Color3.fromRGB(180, 180, 185)
            or Color3.fromRGB(45, 45, 48)

        toggle.TextColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(220, 220, 225)

        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(165, 165, 170)

        knob.Position = enabled
            and UDim2.new(1, -18, 0.5, -7)
            or UDim2.fromOffset(3, 4)
    end

    toggle.Activated:Connect(function()
        local current = false

        pcall(function()
            current = getter() == true
        end)

        pcall(function()
            setter(not current)
        end)

        task.defer(redraw)
    end)

    redraw()

    return row, redraw
end

local function dropdownRow(page, text, order, options, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.42, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 222, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.54, -8, 0, 26)
    button.Position = UDim2.new(0.46, 0, 0.5, -13)
    button.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextColor3 = Color3.fromRGB(222, 224, 231)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 7
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = row
    corner(button, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollingEnabled = true
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = page
    corner(list, 7)
    stroke(list)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = list

    local function refresh()
        local value = "?"

        pcall(function()
            value = getter()
        end)

        button.Text = tostring(value)
    end

    for index, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 29)
        item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. tostring(option)
        item.TextColor3 = Color3.fromRGB(222, 224, 231)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = index
        item.Parent = list
        corner(item, 5)

        item.Activated:Connect(function()
            pcall(function()
                setter(option)
            end)

            refresh()
            list.Visible = false
            list.Size = UDim2.new(1, 0, 0, 0)
        end)
    end

    button.Activated:Connect(function()
        local open = not list.Visible

        list.Visible = open
        list.Size = UDim2.new(
            1,
            0,
            0,
            open and math.min(#options * 32 + 5, 150) or 0
        )

        if open then
            refresh()
        end
    end)

    refresh()

    return row, button, list
end

-- ============================================================
-- PAGES / TABS
-- ============================================================

local MainPage = makePage("MAIN")
local ChickensPage = makePage("CHICKENS")
local FARMPage = makePage("FARM")
local BATTLEPage = makePage("BATTLE")
local EVENTSPage = makePage("EVENTS")
local SETTINGSPage = makePage("SETTINGS")

local mainTab = makeTab("MAIN", "◆", 1)
local chickensTab = makeTab("CHICKENS", "◎", 2)
local farmTab = makeTab("FARM", "◇", 3)
local battleTab = makeTab("BATTLE", "⚔", 4)
local eventsTab = makeTab("EVENTS", "★", 5)
local settingsTab = makeTab("SETTINGS", "☰", 6)

mainTab.Activated:Connect(function()
    selectTab("MAIN")
end)

chickensTab.Activated:Connect(function()
    selectTab("CHICKENS")
end)

farmTab.Activated:Connect(function()
    selectTab("FARM")
end)

battleTab.Activated:Connect(function()
    selectTab("BATTLE")
end)

eventsTab.Activated:Connect(function()
    selectTab("EVENTS")
end)

settingsTab.Activated:Connect(function()
    selectTab("SETTINGS")
end)

-- ============================================================
-- MAIN
-- ============================================================

section(MainPage, "EGGS", 1)

toggleRow(
    MainPage,
    "Auto Open Eggs",
    2,
    function() return S.autoEgg end,
    setAutoEgg
)

dropdownRow(
    MainPage,
    "Egg",
    3,
    getEggList(),
    function() return S.selectedEgg end,
    function(value)
        S.selectedEgg = value
    end
)

dropdownRow(
    MainPage,
    "Open Amount",
    4,
    {"1", "3", "5", "10", "25"},
    function() return tostring(S.eggAmount) end,
    function(value)
        S.eggAmount = tonumber(value) or 1
    end
)

action(
    MainPage,
    "Refresh Egg List",
    "↻",
    5,
    function()
        notify(
            "Eggs",
            "Available: " .. tostring(#getEggList() - 1),
            2
        )
    end
)

section(MainPage, "RECYCLER", 10)

toggleRow(
    MainPage,
    "Auto Upgrade Recycler",
    11,
    function() return S.autoRecycler end,
    setAutoRecycler
)

toggleRow(
    MainPage,
    "Auto Rebirth",
    12,
    function() return S.autoRebirth end,
    setAutoRebirth
)

-- ============================================================
-- CHICKENS
-- ============================================================

section(ChickensPage, "FUSION", 1)

toggleRow(
    ChickensPage,
    "Auto Fuse Chickens",
    2,
    function() return S.autoFuse end,
    setAutoFuse
)

dropdownRow(
    ChickensPage,
    "Fuse Mode",
    3,
    {"Same Type", "Same Rarity", "Any"},
    function() return S.fuseMode end,
    function(value)
        S.fuseMode = value
    end
)

dropdownRow(
    ChickensPage,
    "Rarity Filter",
    4,
    {
        "Any",
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "mythic",
        "divine",
        "eternal",
        "transcendent",
        "omega"
    },
    function() return S.fuseRarity end,
    function(value)
        S.fuseRarity = value
    end
)

toggleRow(
    ChickensPage,
    "Keep Favorite",
    5,
    function() return S.keepFavorite end,
    function(value)
        S.keepFavorite = value
    end
)

-- ============================================================
-- FARM
-- ============================================================

section(FARMPage, "SCRAP", 1)

toggleRow(
    FARMPage,
    "Auto Grab Scraps",
    2,
    function() return S.autoScrap end,
    setAutoScrap
)

dropdownRow(
    FARMPage,
    "Scrap Target",
    3,
    {"Nearest", "First"},
    function() return S.scrapMode end,
    function(value)
        S.scrapMode = value
    end
)

toggleRow(
    FARMPage,
    "Auto Recycle Scrap",
    4,
    function() return S.autoRecycle end,
    setAutoRecycle
)

section(FARMPage, "COOP / FEEDERS", 8)

toggleRow(
    FARMPage,
    "Auto Upgrade Coop",
    9,
    function() return S.autoCoop end,
    setAutoCoop
)

dropdownRow(
    FARMPage,
    "Coop Mode",
    10,
    {"Upgrade All", "Upgrade Only", "Expand Only"},
    function() return S.coopMode end,
    function(value)
        S.coopMode = value
    end
)

toggleRow(
    FARMPage,
    "Auto Buy Feeders",
    11,
    function() return S.autoFeeders end,
    setAutoFeeders
)

dropdownRow(
    FARMPage,
    "Feeder Mode",
    12,
    {"Buy + Upgrade", "Buy Only", "Upgrade Only"},
    function() return S.feederMode end,
    function(value)
        S.feederMode = value
    end
)

-- ============================================================
-- BATTLE
-- ============================================================

section(BATTLEPage, "TOWER / CHAOS", 1)

toggleRow(
    BATTLEPage,
    "Auto Start Tower",
    2,
    function() return S.autoTower end,
    setAutoTower
)

toggleRow(
    BATTLEPage,
    "Auto Start Chaos",
    3,
    function() return S.autoChaos end,
    setAutoChaos
)

action(
    BATTLEPage,
    "Start Tower Now",
    "↗",
    5,
    function()
        if startTowerOnce() then
            notify("Tower", "HUD Tower button activated.", 2)
        else
            notify("Tower", "Tower button not available right now.", 2)
        end
    end
)

action(
    BATTLEPage,
    "Start Chaos Now",
    "↗",
    6,
    function()
        if startChaosOnce() then
            notify("Chaos", "HUD Chaos button activated.", 2)
        else
            notify("Chaos", "Chaos button not available right now.", 2)
        end
    end
)

action(
    BATTLEPage,
    "Show Current Mode",
    "i",
    7,
    function()
        notify(
            "Chicken Mode",
            tostring(currentOrder() or "unknown"),
            2
        )
    end
)

-- ============================================================
-- EVENTS
-- ============================================================

section(EVENTSPage, "WORLD EVENT", 1)

toggleRow(
    EVENTSPage,
    "Auto Event Chaos",
    2,
    function() return S.autoEventChaos end,
    setAutoEventChaos
)

toggleRow(
    EVENTSPage,
    "Auto No Thanks",
    3,
    function() return S.autoNoThanks end,
    setAutoNoThanks
)

action(
    EVENTSPage,
    "Check Event Now",
    "★",
    5,
    function()
        local event = getEvent()

        if not event then
            notify("Event", "No active warmup/live event.", 2)
            return
        end

        notify(
            "Event",
            tostring(event.id)
                .. " • "
                .. tostring(event.phase)
                .. " • "
                .. string.format("%.1fs", eventRemaining(event)),
            3
        )
    end
)

action(
    EVENTSPage,
    "Trigger Event Chaos Check",
    "↻",
    6,
    function()
        local event = getEvent()

        if event then
            if startChaosOnce() then
                notify("Event Chaos", "Chaos HUD activated.", 2)
            else
                notify("Event Chaos", "Chaos HUD button unavailable.", 2)
            end
        else
            notify("Event Chaos", "No active event.", 2)
        end
    end
)

-- ============================================================
-- SETTINGS
-- ============================================================

section(SETTINGSPage, "GENERAL", 1)

toggleRow(
    SETTINGSPage,
    "Anti AFK",
    2,
    function() return S.antiAFK end,
    setAntiAFK
)

action(
    SETTINGSPage,
    "Refresh Game Modules",
    "↻",
    4,
    function()
        loadModules()

        local remoteState = Remotes and "OK" or "MISSING"
        local dataState = DataClient and "OK" or "MISSING"

        notify(
            "Module Status",
            "Remotes: " .. remoteState .. " • Data: " .. dataState,
            3
        )
    end
)

action(
    SETTINGSPage,
    "Show Data Status",
    "i",
    5,
    function()
        local roster = getState({"roster"})
        local coop = getState({"coop"})
        local tower = getState({"tower"})
        local scrap = getState({"scrap"})

        notify(
            "DataService",
            "Roster "
                .. (roster and "OK" or "—")
                .. " • Coop "
                .. (coop and "OK" or "—")
                .. " • Tower "
                .. (tower and "OK" or "—")
                .. " • Scrap "
                .. (scrap and "OK" or "—"),
            4
        )
    end
)

action(
    SETTINGSPage,
    "Stop All Automation",
    "■",
    6,
    function()
        S.autoEgg = false
        S.autoFuse = false
        S.autoScrap = false
        S.autoRecycle = false
        S.autoRecycler = false
        S.autoRebirth = false
        S.autoCoop = false
        S.autoFeeders = false
        S.autoTower = false
        S.autoChaos = false
        S.autoEventChaos = false
        S.autoNoThanks = false

        for key in pairs(RunIds) do
            RunIds[key] = RunIds[key] + 1
        end

        notify("HAIMIYACH", "All automation stopped.", 2)
    end
)

action(
    SETTINGSPage,
    "Close Menu",
    "×",
    7,
    closeWindow
)

-- ============================================================
-- INITIAL TAB
-- ============================================================

selectTab("MAIN")

task.defer(function()
    local remoteState = Remotes and "READY" or "MISSING"
    local dataState = DataClient and "READY" or "MISSING"

    notify(
        "HAIMIYACH GAF V3",
        "Loaded • Remotes " .. remoteState .. " • Data " .. dataState,
        3
    )
end)

print("[HAIMIYACH GAF V3] loaded")
