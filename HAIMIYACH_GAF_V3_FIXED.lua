--[[
HAIMIYACH_GAF_V3_FIXED.lua
Grow a Chicken Fighter - executor edition
UI: HAIMIYACH Sudoku V9 compact/mobile pattern.

SOURCE-BACKED GAME HOOKS:
  HatchEgg
  FuseChickens
  UpgradeRecycler
  Rebirth
  ExpandCoop
  BuyGenerator
  UpgradeGenerator
  Workspace EventId / EventPhase / EventDeadline
  HUD buttons for Tower / Chaos / No Thanks

IMPORTANT:
  Scrap automation intentionally TELEPORTS to scrap/recycler objects.
  It does not invent a collect remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEAN OLD GUI / CONNECTIONS
-- ============================================================

pcall(function()
    local old = PlayerGui:FindFirstChild("HAIMIYACH_GAF_V3")
    if old then
        old:Destroy()
    end
end)

math.randomseed(math.floor(os.clock() * 1000000) % 2147483647)

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HAIMIYACH"),
            Text = tostring(text or ""),
            Duration = duration or 2
        })
    end)
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
end

-- ============================================================
-- GAME MODULE ADAPTER
-- ============================================================

local Remotes = nil
local DataClient = nil
local EventState = nil
local ChickenMode = nil
local Catalog = nil
local RecyclerView = nil

local function safeRequire(obj)
    if not obj or not obj:IsA("ModuleScript") then
        return nil
    end

    local ok, result = pcall(require, obj)
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

    local descendants = root:GetDescendants()
    for i = 1, #descendants do
        local obj = descendants[i]
        if obj.Name == name and obj:IsA("ModuleScript") then
            return obj
        end
    end

    return nil
end

local function loadModules()
    Remotes = nil
    DataClient = nil
    EventState = nil
    ChickenMode = nil
    Catalog = nil
    RecyclerView = nil

    pcall(function()
        local core = ReplicatedStorage:FindFirstChild("Core")
        local module = core and core:FindFirstChild("Remotes")
        Remotes = safeRequire(module)
    end)

    pcall(function()
        local packages = ReplicatedStorage:FindFirstChild("Packages")
        local module = packages and packages:FindFirstChild("DataService")
        local result = safeRequire(module)
        if type(result) == "table" and result.client then
            DataClient = result.client
        end
    end)

    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        local module = findModule(ps, "EventState")
        if not module then
            module = findModule(ReplicatedStorage, "EventState")
        end
        EventState = safeRequire(module)
    end)

    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        ChickenMode = safeRequire(findModule(ps, "ChickenMode"))
    end)

    pcall(function()
        Catalog = safeRequire(findModule(ReplicatedStorage, "Catalog"))
    end)

    pcall(function()
        RecyclerView = safeRequire(findModule(ReplicatedStorage, "RecyclerView"))
    end)
end

pcall(loadModules)

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
    if not Remotes or type(Remotes.invoke) ~= "function" or type(Remotes.defs) ~= "table" then
        return nil, "Remotes unavailable"
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

local function resultOK(result)
    return type(result) == "table" and result.ok == true
end

-- ============================================================
-- STATE
-- ============================================================

local S = {
    autoEgg = false,
    egg = "AUTO",
    eggAmount = 1,

    autoFuse = false,
    fuseMode = "Same Type",
    fuseRarity = "Any",
    keepFavorite = true,

    autoScrap = false,
    scrapFilter = "Nearest",
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

local RarityOrder = {
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

-- ============================================================
-- BASIC WORLD HELPERS
-- ============================================================

local function characterRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function pivotOf(obj)
    if not obj then
        return nil
    end

    local ok, cf = pcall(function()
        if obj:IsA("BasePart") then
            return obj.CFrame
        end

        if obj:IsA("Model") then
            return obj:GetPivot()
        end

        return nil
    end)

    if ok then
        return cf
    end

    return nil
end

local function teleportCF(cf)
    local root = characterRoot()
    if not root or not cf then
        return false
    end

    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = cf
    end)

    return ok
end

-- ============================================================
-- EGGS
-- ============================================================

local function getEggCounts()
    local roster = getState({"roster"})
    local eggs = roster and roster.eggs

    if type(eggs) == "table" then
        return eggs
    end

    return {}
end

local function chooseEgg()
    if S.egg ~= "AUTO" then
        local count = tonumber(getEggCounts()[S.egg]) or 0
        if count > 0 then
            return S.egg
        end
    end

    local bestId = nil
    local bestCount = 0
    local eggs = getEggCounts()

    for id, count in pairs(eggs) do
        count = tonumber(count) or 0
        if count > bestCount then
            bestId = id
            bestCount = count
        end
    end

    return bestId
end

local function hatchOne()
    local egg = chooseEgg()
    if not egg then
        return false, "No egg available"
    end

    local result, err = invokeDef("HatchEgg", egg)

    if resultOK(result) then
        return true
    end

    if type(result) == "table" and result.error then
        return false, tostring(result.error)
    end

    return false, err or "Hatch failed"
end

local function hatchLoop()
    local run = RunIds.autoEgg

    task.spawn(function()
        while S.autoEgg and run == RunIds.autoEgg do
            local amount = math.floor(tonumber(S.eggAmount) or 1)

            if amount < 1 then
                amount = 1
            elseif amount > 25 then
                amount = 25
            end

            local did = false

            for _ = 1, amount do
                if not S.autoEgg or run ~= RunIds.autoEgg then
                    break
                end

                local ok = hatchOne()
                if ok then
                    did = true
                end

                task.wait(0.35)
            end

            if not did then
                task.wait(1.5)
            end
        end
    end)
end

-- ============================================================
-- FUSION
-- ============================================================

local function chickenList()
    local roster = getState({"roster"})
    local chickens = roster and roster.chickens
    local out = {}

    if type(chickens) ~= "table" then
        return out
    end

    for _, chicken in pairs(chickens) do
        if type(chicken) == "table" and chicken.id then
            table.insert(out, chicken)
        end
    end

    return out
end

local function allowedFuseRarity(chicken)
    if S.fuseRarity == "Any" then
        return true
    end

    return tostring(chicken.rarity or "common"):lower()
        == tostring(S.fuseRarity):lower()
end

local function findFusePair()
    local groups = {}

    for _, chicken in ipairs(chickenList()) do
        local favorite = chicken.favorite == true
        local active = chicken.active == true

        if (not S.keepFavorite or not favorite)
            and not active
            and allowedFuseRarity(chicken) then

            local key

            if S.fuseMode == "Same Type" then
                key = tostring(chicken.typeId)
            elseif S.fuseMode == "Same Rarity" then
                key = tostring(chicken.rarity or "common")
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

local function fuseLoop()
    local run = RunIds.autoFuse

    task.spawn(function()
        while S.autoFuse and run == RunIds.autoFuse do
            local ok = fuseOne()

            if ok then
                task.wait(0.65)
            else
                task.wait(1.5)
            end
        end
    end)
end

-- ============================================================
-- SCRAP TELEPORT
-- ============================================================

local function looksLikeScrap(obj)
    local name = string.lower(tostring(obj.Name or ""))

    if name == "trialscrap" or name == "onbtrialscrap" then
        return false
    end

    return name:find("scrap", 1, true) ~= nil
end

local function scrapCandidates()
    local root = characterRoot()
    local out = {}

    if not root then
        return out
    end

    local descendants = Workspace:GetDescendants()

    for i = 1, #descendants do
        local obj = descendants[i]

        if looksLikeScrap(obj)
            and (obj:IsA("BasePart") or obj:IsA("Model")) then

            local cf = pivotOf(obj)

            if cf then
                table.insert(out, {
                    object = obj,
                    cf = cf,
                    distance = (cf.Position - root.Position).Magnitude
                })
            end
        end
    end

    table.sort(out, function(a, b)
        return a.distance < b.distance
    end)

    return out
end

local function teleportNearestScrap()
    local list = scrapCandidates()

    if #list == 0 then
        return false
    end

    return teleportCF(list[1].cf + Vector3.new(0, 2.5, 0))
end

local function scrapLoop()
    local run = RunIds.autoScrap

    task.spawn(function()
        while S.autoScrap and run == RunIds.autoScrap do
            teleportNearestScrap()
            task.wait(0.8)
        end
    end)
end

-- ============================================================
-- RECYCLER
-- ============================================================

local function recyclerCF()
    local plot = LocalPlayer:GetAttribute("Plot")
    local recyclers = Workspace:FindFirstChild("Recyclers")

    if not recyclers then
        return nil
    end

    if plot ~= nil then
        local named = recyclers:FindFirstChild("Recycler" .. tostring(plot))
        local cf = pivotOf(named)

        if cf then
            return cf
        end
    end

    for _, recycler in ipairs(recyclers:GetChildren()) do
        local cf = pivotOf(recycler)

        if cf then
            return cf
        end
    end

    return nil
end

local function teleportRecycler()
    local cf = recyclerCF()

    if not cf then
        return false
    end

    return teleportCF(cf + Vector3.new(0, 3, 0))
end

local function recyclerCanUpgrade()
    local scrap = getState({"scrap"})

    if type(scrap) ~= "table" then
        return true
    end

    if RecyclerView and type(RecyclerView.upgradeCost) == "function" then
        local level = tonumber(scrap.recyclerLevel) or 0

        local ok, cost = pcall(function()
            return RecyclerView.upgradeCost(level)
        end)

        if ok and tonumber(cost) then
            local money = tonumber(getState({"money"}))

            if money then
                return money >= tonumber(cost)
            end
        end
    end

    return true
end

local function upgradeRecycler()
    if not recyclerCanUpgrade() then
        return false
    end

    local result = invokeDef("UpgradeRecycler")
    return resultOK(result)
end

local function recycleLoop()
    local run = RunIds.autoRecycle

    task.spawn(function()
        while S.autoRecycle and run == RunIds.autoRecycle do
            teleportRecycler()
            task.wait(1)
        end
    end)
end

local function recyclerLoop()
    local run = RunIds.autoRecycler

    task.spawn(function()
        while S.autoRecycler and run == RunIds.autoRecycler do
            upgradeRecycler()
            task.wait(1.25)
        end
    end)
end

-- ============================================================
-- REBIRTH
-- ============================================================

local function rebirth()
    local result = invokeDef("Rebirth")
    return resultOK(result)
end

local function rebirthLoop()
    local run = RunIds.autoRebirth

    task.spawn(function()
        while S.autoRebirth and run == RunIds.autoRebirth do
            rebirth()
            task.wait(3)
        end
    end)
end

-- ============================================================
-- COOP / FEEDERS
-- ============================================================

local function coopState()
    return getState({"coop"})
end

local function upgradeGenerator(slot)
    local result = invokeDef("UpgradeGenerator", slot)
    return resultOK(result)
end

local function buyGenerator(slot)
    local result = invokeDef("BuyGenerator", slot)
    return resultOK(result)
end

local function expandCoop()
    local result = invokeDef("ExpandCoop")
    return resultOK(result)
end

local function coopLoop()
    local run = RunIds.autoCoop

    task.spawn(function()
        while S.autoCoop and run == RunIds.autoCoop do
            local coop = coopState()

            if type(coop) == "table"
                and type(coop.generators) == "table" then

                for _, generator in pairs(coop.generators) do
                    if S.coopMode ~= "Expand Only"
                        and generator
                        and generator.slot then

                        upgradeGenerator(generator.slot)
                        task.wait(0.35)
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

local function feederLoop()
    local run = RunIds.autoFeeders

    task.spawn(function()
        while S.autoFeeders and run == RunIds.autoFeeders do
            local coop = coopState()
            local generators = coop and coop.generators

            if type(generators) == "table" then
                local count = 0
                local maxSlot = tonumber(coop.slots) or 1

                for _, generator in pairs(generators) do
                    if generator and generator.slot then
                        count = count + 1

                        if S.feederMode ~= "Buy Only" then
                            upgradeGenerator(generator.slot)
                            task.wait(0.3)
                        end
                    end
                end

                if S.feederMode ~= "Upgrade Only" then
                    if count < maxSlot then
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

-- ============================================================
-- HUD: TOWER / CHAOS / NO THANKS
-- ============================================================

local function normalizeText(value)
    local text = string.lower(tostring(value or ""))
    return text:gsub("[%p]", " ")
end

local function visibleTextButtons()
    local result = {}
    local descendants = PlayerGui:GetDescendants()

    for i = 1, #descendants do
        local obj = descendants[i]

        if obj:IsA("TextButton")
            and obj.Visible
            and obj.Active then

            table.insert(result, obj)
        end
    end

    return result
end

local function clickHUDButton(words)
    local buttons = visibleTextButtons()

    for i = 1, #buttons do
        local button = buttons[i]
        local text = normalizeText(button.Text)
        local match = true

        for j = 1, #words do
            local word = string.lower(tostring(words[j]))

            if not text:find(word, 1, true) then
                match = false
                break
            end
        end

        if match then
            local ok = pcall(function()
                button:Activate()
            end)

            if ok then
                return true
            end
        end
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

local function towerLoop()
    local run = RunIds.autoTower

    task.spawn(function()
        while S.autoTower and run == RunIds.autoTower do
            startTowerOnce()
            task.wait(1.5)
        end
    end)
end

local function chaosLoop()
    local run = RunIds.autoChaos

    task.spawn(function()
        while S.autoChaos and run == RunIds.autoChaos do
            startChaosOnce()
            task.wait(1.5)
        end
    end)
end

-- Auto Events -> Chaos:
-- Start Chaos once for each newly detected active event.
local function eventIsActive()
    local eventId = Workspace:GetAttribute("EventId")
    local phase = Workspace:GetAttribute("EventPhase")
    local deadline = Workspace:GetAttribute("EventDeadline")

    if not eventId or not phase or not deadline then
        return false
    end

    if phase ~= "warmup" and phase ~= "live" then
        return false
    end

    local numericDeadline = tonumber(deadline)

    if numericDeadline then
        if numericDeadline <= os.time() then
            return false
        end
    end

    return true
end

local function eventChaosLoop()
    local run = RunIds.autoEventChaos
    local lastEvent = nil

    task.spawn(function()
        while S.autoEventChaos and run == RunIds.autoEventChaos do
            local eventId = Workspace:GetAttribute("EventId")
            local active = eventIsActive()

            if active and eventId ~= lastEvent then
                lastEvent = eventId
                startChaosOnce()
            elseif not active then
                lastEvent = nil
            end

            task.wait(0.75)
        end
    end)
end

local function noThanksOnce()
    return clickHUDButton({"no", "thanks"})
        or clickHUDButton({"no thanks"})
end

local function noThanksLoop()
    local run = RunIds.autoNoThanks

    task.spawn(function()
        while S.autoNoThanks and run == RunIds.autoNoThanks do
            noThanksOnce()
            task.wait(0.8)
        end
    end)
end

-- ============================================================
-- ANTI AFK
-- ============================================================

local antiAFKConnection = nil

local function setAntiAFK(enabled)
    S.antiAFK = enabled and true or false

    if antiAFKConnection then
        pcall(function()
            antiAFKConnection:Disconnect()
        end)

        antiAFKConnection = nil
    end

    if not S.antiAFK then
        return
    end

    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")

        antiAFKConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

setAntiAFK(true)

-- ============================================================
-- LOOP CONTROL
-- ============================================================

local function setFeature(key, enabled)
    if RunIds[key] == nil then
        return
    end

    S[key] = enabled and true or false
    RunIds[key] = RunIds[key] + 1

    if not S[key] then
        return
    end

    if key == "autoEgg" then
        hatchLoop()
    elseif key == "autoFuse" then
        fuseLoop()
    elseif key == "autoScrap" then
        scrapLoop()
    elseif key == "autoRecycle" then
        recycleLoop()
    elseif key == "autoRecycler" then
        recyclerLoop()
    elseif key == "autoRebirth" then
        rebirthLoop()
    elseif key == "autoCoop" then
        coopLoop()
    elseif key == "autoFeeders" then
        feederLoop()
    elseif key == "autoTower" then
        towerLoop()
    elseif key == "autoChaos" then
        chaosLoop()
    elseif key == "autoEventChaos" then
        eventChaosLoop()
    elseif key == "autoNoThanks" then
        noThanksLoop()
    end
end

local function stopAll()
    for key in pairs(RunIds) do
        S[key] = false
        RunIds[key] = RunIds[key] + 1
    end
end

-- ============================================================
-- GUI ROOT - SUDOKU V9 PATTERN
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HAIMIYACH_GAF_V3"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local portrait = viewport.Y >= viewport.X

local function clampNumber(value, minimum, maximum)
    value = tonumber(value) or minimum

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local guiWidth = clampNumber(
    math.floor(viewport.X * (portrait and 0.78 or 0.38)),
    220,
    270
)

local guiHeight = clampNumber(
    math.floor(viewport.Y * (portrait and 0.58 or 0.62)),
    300,
    390
)

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
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window
corner(Header, 8)

local HeaderFill = Instance.new("Frame")
HeaderFill.Size = UDim2.new(1, 0, 0, 10)
HeaderFill.Position = UDim2.new(0, 0, 1, -10)
HeaderFill.BackgroundColor3 = Header.BackgroundColor3
HeaderFill.BorderSizePixel = 0
HeaderFill.Parent = Header

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
-- TABS / PAGES
-- ============================================================

local TabBar = Instance.new("ScrollingFrame")
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
PageHolder.Size = UDim2.new(1, -12, 1, -82)
PageHolder.Position = UDim2.fromOffset(6, 78)
PageHolder.BackgroundTransparency = 1
PageHolder.ClipsDescendants = true
PageHolder.Parent = Window

local Pages = {}
local Tabs = {}
local currentTab = nil

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
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(72, 27)
    button.BackgroundColor3 = Color3.fromRGB(43, 44, 51)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = icon .. " " .. name
    button.TextColor3 = Color3.fromRGB(164, 166, 175)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 7
    button.LayoutOrder = order
    button.Parent = TabBar
    corner(button, 6)

    Tabs[name] = button
    return button
end

local function selectTab(name)
    currentTab = name

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

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(48, 22)
    button.Position = UDim2.new(1, -58, 0.5, -11)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = "OFF"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 7
    button.TextColor3 = Color3.fromRGB(220, 220, 225)
    button.Parent = row
    corner(button, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BorderSizePixel = 0
    knob.Parent = button
    corner(knob, 8)

    local function redraw()
        local enabled = false

        pcall(function()
            enabled = getter() and true or false
        end)

        button.Text = enabled and "ON" or "OFF"
        button.BackgroundColor3 = enabled
            and Color3.fromRGB(180, 180, 185)
            or Color3.fromRGB(45, 45, 48)

        button.TextColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(220, 220, 225)

        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(165, 165, 170)

        knob.Position = enabled
            and UDim2.new(1, -18, 0.5, -7)
            or UDim2.fromOffset(4, 4)
    end

    button.Activated:Connect(function()
        local current = false

        pcall(function()
            current = getter() and true or false
        end)

        pcall(function()
            setter(not current)
        end)

        task.defer(redraw)
    end)

    redraw()
    return row, redraw
end

-- Dropdowns are kept inside the page and their height is capped.
-- This prevents very long option lists from pushing the GUI off-screen.
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
    button.Size = UDim2.new(0.54, -10, 0, 24)
    button.Position = UDim2.new(0.46, 0, 0.5, -12)
    button.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextColor3 = Color3.fromRGB(222, 224, 231)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 8
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = row
    corner(button, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.LayoutOrder = order + 0.1
    list.Parent = page
    corner(list, 7)
    stroke(list)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    local function refresh()
        local value = "?"

        pcall(function()
            value = getter()
        end)

        button.Text = tostring(value)
    end

    for i, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 27)
        item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. tostring(option)
        item.TextColor3 = Color3.fromRGB(222, 224, 231)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = i
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
            open and math.min(#options * 30 + 5, 145) or 0
        )

        if open then
            refresh()
        end
    end)

    refresh()
    return row
end

-- ============================================================
-- BUILD TABS
-- ============================================================

local Main = makePage("MAIN")
local Eggs = makePage("EGGS")
local Scrap = makePage("SCRAP")
local Coop = makePage("COOP")
local Tower = makePage("TOWER")
local Settings = makePage("SETTINGS")

makeTab("MAIN", "◆", 1).Activated:Connect(function()
    selectTab("MAIN")
end)

makeTab("EGGS", "◉", 2).Activated:Connect(function()
    selectTab("EGGS")
end)

makeTab("SCRAP", "▣", 3).Activated:Connect(function()
    selectTab("SCRAP")
end)

makeTab("COOP", "♜", 4).Activated:Connect(function()
    selectTab("COOP")
end)

makeTab("TOWER", "⚔", 5).Activated:Connect(function()
    selectTab("TOWER")
end)

makeTab("SETTINGS", "⚙", 6).Activated:Connect(function()
    selectTab("SETTINGS")
end)

-- ============================================================
-- MAIN
-- ============================================================

section(Main, "AUTOMATION", 1)

toggleRow(
    Main,
    "Auto Rebirth",
    2,
    function()
        return S.autoRebirth
    end,
    function(v)
        setFeature("autoRebirth", v)
    end
)

toggleRow(
    Main,
    "Auto Fuse Chickens",
    3,
    function()
        return S.autoFuse
    end,
    function(v)
        setFeature("autoFuse", v)
    end
)

dropdownRow(
    Main,
    "Fuse Mode",
    4,
    {"Same Type", "Same Rarity", "Any"},
    function()
        return S.fuseMode
    end,
    function(v)
        S.fuseMode = v
    end
)

dropdownRow(
    Main,
    "Fuse Rarity",
    5,
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
    function()
        return S.fuseRarity
    end,
    function(v)
        S.fuseRarity = v
    end
)

toggleRow(
    Main,
    "Keep Favorite",
    6,
    function()
        return S.keepFavorite
    end,
    function(v)
        S.keepFavorite = v
    end
)

-- ============================================================
-- EGGS
-- ============================================================

section(Eggs, "EGG AUTOMATION", 1)

toggleRow(
    Eggs,
    "Auto Open Eggs",
    2,
    function()
        return S.autoEgg
    end,
    function(v)
        setFeature("autoEgg", v)
    end
)

dropdownRow(
    Eggs,
    "Egg Selected",
    3,
    {"AUTO", "barn", "farm", "golden", "hotEgg", "void"},
    function()
        return S.egg
    end,
    function(v)
        S.egg = v
    end
)

dropdownRow(
    Eggs,
    "Open Amount",
    4,
    {"1", "2", "3", "5", "10", "25"},
    function()
        return tostring(S.eggAmount)
    end,
    function(v)
        S.eggAmount = tonumber(v) or 1
    end
)

action(
    Eggs,
    "Open One Egg",
    "🥚",
    6,
    function()
        local ok, err = hatchOne()
        notify(
            "Egg",
            ok and "Hatched successfully." or tostring(err),
            2
        )
    end
)

-- ============================================================
-- SCRAP
-- ============================================================

section(Scrap, "SCRAP", 1)

toggleRow(
    Scrap,
    "Auto Grab Scraps",
    2,
    function()
        return S.autoScrap
    end,
    function(v)
        setFeature("autoScrap", v)
    end
)

dropdownRow(
    Scrap,
    "Scrap Target",
    3,
    {"Nearest"},
    function()
        return S.scrapFilter
    end,
    function(v)
        S.scrapFilter = v
    end
)

action(
    Scrap,
    "Teleport to Scrap",
    "↗",
    4,
    function()
        notify(
            "Scrap",
            teleportNearestScrap()
                and "Teleported to nearest scrap."
                or "No scrap found.",
            2
        )
    end
)

toggleRow(
    Scrap,
    "Auto Recycle Scrap",
    6,
    function()
        return S.autoRecycle
    end,
    function(v)
        setFeature("autoRecycle", v)
    end
)

action(
    Scrap,
    "Teleport Recycler",
    "↗",
    7,
    function()
        notify(
            "Recycler",
            teleportRecycler()
                and "Teleported."
                or "Recycler not found.",
            2
        )
    end
)

toggleRow(
    Scrap,
    "Auto Upgrade Recycler",
    9,
    function()
        return S.autoRecycler
    end,
    function(v)
        setFeature("autoRecycler", v)
    end
)

action(
    Scrap,
    "Upgrade Recycler Once",
    "▲",
    10,
    function()
        notify(
            "Recycler",
            upgradeRecycler()
                and "Upgrade request sent."
                or "Upgrade unavailable.",
            2
        )
    end
)

-- ============================================================
-- COOP
-- ============================================================

section(Coop, "COOP / FEEDERS", 1)

toggleRow(
    Coop,
    "Auto Upgrade Coop",
    2,
    function()
        return S.autoCoop
    end,
    function(v)
        setFeature("autoCoop", v)
    end
)

dropdownRow(
    Coop,
    "Coop Mode",
    3,
    {"Upgrade All", "Upgrade Only", "Expand Only"},
    function()
        return S.coopMode
    end,
    function(v)
        S.coopMode = v
    end
)

toggleRow(
    Coop,
    "Auto Buy Feeders",
    5,
    function()
        return S.autoFeeders
    end,
    function(v)
        setFeature("autoFeeders", v)
    end
)

dropdownRow(
    Coop,
    "Feeder Mode",
    6,
    {"Buy + Upgrade", "Buy Only", "Upgrade Only"},
    function()
        return S.feederMode
    end,
    function(v)
        S.feederMode = v
    end
)

action(
    Coop,
    "Buy Feeder Once",
    "+",
    8,
    function()
        local coop = coopState()
        local count = 0

        if type(coop) == "table"
            and type(coop.generators) == "table" then

            for _ in pairs(coop.generators) do
                count = count + 1
            end
        end

        notify(
            "Feeder",
            buyGenerator(count + 1)
                and "Buy request sent."
                or "Buy unavailable.",
            2
        )
    end
)

action(
    Coop,
    "Upgrade Coop Once",
    "▲",
    9,
    function()
        notify(
            "Coop",
            expandCoop()
                and "Expand request sent."
                or "Upgrade unavailable.",
            2
        )
    end
)

-- ============================================================
-- TOWER / CHAOS
-- ============================================================

section(Tower, "TOWER", 1)

toggleRow(
    Tower,
    "Auto Start Tower",
    2,
    function()
        return S.autoTower
    end,
    function(v)
        setFeature("autoTower", v)
    end
)

action(
    Tower,
    "Start Tower Now",
    "⚔",
    3,
    function()
        notify(
            "Tower",
            startTowerOnce()
                and "HUD button activated."
                or "Tower button not found / already active.",
            2
        )
    end
)

section(Tower, "CHAOS", 5)

toggleRow(
    Tower,
    "Auto Chaos",
    6,
    function()
        return S.autoChaos
    end,
    function(v)
        setFeature("autoChaos", v)
    end
)

action(
    Tower,
    "Start Chaos Now",
    "⚡",
    7,
    function()
        notify(
            "Chaos",
            startChaosOnce()
                and "HUD button activated."
                or "Chaos button not found / already active.",
            2
        )
    end
)

section(Tower, "EVENT", 9)

toggleRow(
    Tower,
    "Auto Events → Chaos",
    10,
    function()
        return S.autoEventChaos
    end,
    function(v)
        setFeature("autoEventChaos", v)
    end
)

toggleRow(
    Tower,
    "Auto No Thanks",
    11,
    function()
        return S.autoNoThanks
    end,
    function(v)
        setFeature("autoNoThanks", v)
    end
)

action(
    Tower,
    "Event Status",
    "i",
    13,
    function()
        local id = Workspace:GetAttribute("EventId")
        local phase = Workspace:GetAttribute("EventPhase")
        local deadline = Workspace:GetAttribute("EventDeadline")

        if id then
            notify(
                "Event",
                tostring(id)
                    .. " • "
                    .. tostring(phase)
                    .. " • "
                    .. tostring(deadline),
                3
            )
        else
            notify("Event", "No event.", 3)
        end
    end
)

-- ============================================================
-- SETTINGS
-- ============================================================

section(Settings, "GENERAL", 1)

toggleRow(
    Settings,
    "Anti AFK",
    2,
    function()
        return S.antiAFK
    end,
    function(v)
        setAntiAFK(v)
    end
)

action(
    Settings,
    "Stop All Automation",
    "■",
    4,
    function()
        stopAll()
        notify("HAIMIYACH", "All automation stopped.", 2)
    end
)

action(
    Settings,
    "Reload Modules",
    "↻",
    5,
    function()
        loadModules()
        notify("HAIMIYACH", "Game modules refreshed.", 2)
    end
)

-- ============================================================
-- FLOATING REOPEN
-- ============================================================

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(82, 28)
OpenButton.AnchorPoint = Vector2.new(0.5, 0)
OpenButton.Position = UDim2.new(0.5, 0, 0, 7)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BackgroundTransparency = 0.22
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

local function closeMenu()
    Window.Visible = false
    OpenButton.Visible = true
end

local function openMenu()
    Window.Visible = true
    OpenButton.Visible = false
end

Close.Activated:Connect(closeMenu)

action(Settings, "Close Menu", "×", 6, closeMenu)

-- ============================================================
-- TOUCH / MOUSE DRAG
-- ============================================================

local function bindDrag(handle, target, openOnTap)
    local dragging = false
    local moved = false
    local startInput = nil
    local startPos = nil
    local connection = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        moved = false
        startInput = input.Position
        startPos = target.Position

        if connection then
            connection:Disconnect()
            connection = nil
        end

        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then
                return
            end

            if move.UserInputType ~= Enum.UserInputType.Touch
                and move.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local delta = move.Position - startInput

            if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
                moved = true
            end

            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                local wasMoved = moved

                dragging = false

                if connection then
                    connection:Disconnect()
                    connection = nil
                end

                if openOnTap and not wasMoved then
                    openMenu()
                end
            end
        end)
    end)
end

bindDrag(Header, Window, false)
bindDrag(OpenButton, OpenButton, true)

-- ============================================================
-- DEFAULT TAB / READY
-- ============================================================

selectTab("MAIN")

task.defer(function()
    notify("HAIMIYACH", "GAF V3 loaded.", 3)
end)

print("[HAIMIYACH_GAF_V3_FIXED] loaded")
