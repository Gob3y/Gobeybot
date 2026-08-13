--[[
HAIMIYACH_GAF_V2_FIXED.lua
Grow a Chicken Fighter - executor edition
UI base: HAIMIYACH Sudoku V9 compact/mobile pattern.

SOURCE-BACKED hooks used by this script:
- HatchEgg / FuseChickens / Rebirth
- ExpandCoop / BuyGenerator / UpgradeGenerator
- UpgradeRecycler
- Workspace EventId/EventPhase/EventDeadline
- HUD buttons for Tower / Chaos / No Thanks

Important:
The game source confirms the remote names and argument shapes above. Scrap pickup itself
is proximity-driven in the supplied source, so Auto Grab Scraps TELEPORTS to the nearest
scrap object rather than inventing a fake collect remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    local old = PlayerGui:FindFirstChild("HAIMIYACH_GAF_V2")
    if old then old:Destroy() end
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

-- ============================================================
-- GAME MODULE / REMOTE ADAPTER
-- ============================================================

local Remotes
local DataClient
local EventState
local ChickenMode
local Catalog
local CoopView
local RecyclerView

local function safeRequire(obj)
    if not obj or not obj:IsA("ModuleScript") then return nil end
    local ok, result = pcall(require, obj)
    return ok and result or nil
end

local function findModule(root, name)
    if not root then return nil end
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

local function loadModules()
    pcall(function()
        Remotes = safeRequire(ReplicatedStorage:FindFirstChild("Core")
            and ReplicatedStorage.Core:FindFirstChild("Remotes"))
    end)

    pcall(function()
        local ds = ReplicatedStorage:FindFirstChild("Packages")
            and ReplicatedStorage.Packages:FindFirstChild("DataService")
        local m = safeRequire(ds)
        if m and m.client then DataClient = m.client end
    end)

    pcall(function()
        local eventFolder = ReplicatedStorage:FindFirstChild("PlayerScripts")
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
        CoopView = safeRequire(findModule(ReplicatedStorage, "CoopView"))
    end)

    pcall(function()
        RecyclerView = safeRequire(findModule(ReplicatedStorage, "RecyclerView"))
    end)
end

pcall(loadModules)

local function getState(path)
    if not DataClient or type(DataClient.get) ~= "function" then return nil end
    local ok, result = pcall(function()
        return DataClient:get(path)
    end)
    return ok and result or nil
end

local function invokeDef(name, ...)
    if not Remotes or type(Remotes.invoke) ~= "function" or not Remotes.defs then
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

local function fireDef(name, ...)
    if not Remotes or type(Remotes.fire) ~= "function" or not Remotes.defs then
        return false, "Remotes unavailable"
    end
    local def = Remotes.defs[name]
    if not def then return false, "Remote definition missing: " .. tostring(name) end
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

local selectedEgg = "AUTO"

local rarityRank = {
    common=1, uncommon=2, rare=3, epic=4, legendary=5,
    mythic=6, divine=7, eternal=8, transcendent=9, omega=10
}

local function characterRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function teleportCF(cf)
    local root = characterRoot()
    if not root or not cf then return false end
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = cf
    end)
    return true
end

local function pivotOf(obj)
    if not obj then return nil end
    local ok, cf = pcall(function()
        if obj:IsA("BasePart") then return obj.CFrame end
        if obj:IsA("Model") then return obj:GetPivot() end
        return nil
    end)
    return ok and cf or nil
end

-- ============================================================
-- EGG
-- ============================================================

local function getEggCounts()
    local roster = getState({"roster"})
    local eggs = roster and roster.eggs
    return type(eggs) == "table" and eggs or {}
end

local function chooseEgg()
    if selectedEgg ~= "AUTO" then
        local count = tonumber(getEggCounts()[selectedEgg]) or 0
        if count > 0 then return selectedEgg end
    end

    local bestId, bestCount = nil, 0
    for id, count in pairs(getEggCounts()) do
        count = tonumber(count) or 0
        if count > bestCount then
            bestId, bestCount = id, count
        end
    end
    return bestId
end

local function hatchOne()
    local egg = chooseEgg()
    if not egg then return false, "No egg available" end

    local result, err = invokeDef("HatchEgg", egg)
    if resultOK(result) then
        return true
    end
    return false, (type(result) == "table" and tostring(result.error)) or err or "Hatch failed"
end

local function hatchLoop()
    local run = RunIds.autoEgg
    task.spawn(function()
        while S.autoEgg and run == RunIds.autoEgg do
            local amount = math.floor(tonumber(S.eggAmount) or 1)
            if amount < 1 then amount = 1 elseif amount > 25 then amount = 25 end
            local did = false
            for _ = 1, amount do
                if not S.autoEgg or run ~= RunIds.autoEgg then break end
                local ok = hatchOne()
                did = did or ok
                task.wait(0.35)
            end
            if not did then task.wait(1.5) end
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
    if type(chickens) ~= "table" then return out end

    for _, c in pairs(chickens) do
        if type(c) == "table" and c.id then
            table.insert(out, c)
        end
    end
    return out
end

local function isAllowedRarity(c)
    if S.fuseRarity == "Any" then return true end
    return tostring(c.rarity or "common"):lower() == S.fuseRarity:lower()
end

local function findFusePair()
    local list = chickenList()
    local groups = {}

    for _, c in ipairs(list) do
        local favorite = c.favorite == true
        local active = c.active == true
        if (not S.keepFavorite or not favorite) and not active and isAllowedRarity(c) then
            local key
            if S.fuseMode == "Same Type" then
                key = tostring(c.typeId)
            elseif S.fuseMode == "Same Rarity" then
                key = tostring(c.rarity or "common")
            else
                key = "ALL"
            end
            groups[key] = groups[key] or {}
            table.insert(groups[key], c)
        end
    end

    for _, group in pairs(groups) do
        if #group >= 2 then
            table.sort(group, function(a,b)
                return (tonumber(a.level) or 1) < (tonumber(b.level) or 1)
            end)
            return group[1], group[2]
        end
    end

    return nil, nil
end

local function fuseOne()
    local a, b = findFusePair()
    if not a or not b then return false end

    -- Exact source-backed FuseChickens signature:
    -- idA, idB, thirdArg, nil, fifthArg.
    local result = invokeDef("FuseChickens", a.id, b.id, nil, nil, nil)
    return resultOK(result)
end

local function fuseLoop()
    local run = RunIds.autoFuse
    task.spawn(function()
        while S.autoFuse and run == RunIds.autoFuse do
            local ok = fuseOne()
            task.wait(ok and 0.65 or 1.5)
        end
    end)
end

-- ============================================================
-- SCRAP TELEPORT
-- ============================================================

local function looksLikeScrap(obj)
    local n = string.lower(obj.Name or "")
    if n == "trialscrap" or n == "onbtrialscrap" then return false end
    return n:find("scrap", 1, true) ~= nil
end

local function scrapCandidates()
    local root = characterRoot()
    if not root then return {} end

    local out = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if looksLikeScrap(obj) and (obj:IsA("BasePart") or obj:IsA("Model")) then
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

    table.sort(out, function(a,b) return a.distance < b.distance end)
    return out
end

local function teleportNearestScrap()
    local list = scrapCandidates()
    if #list == 0 then return false end

    local entry = list[1]
    return teleportCF(entry.cf + Vector3.new(0, 2.5, 0))
end

local function recyclerCF()
    local plot = LocalPlayer:GetAttribute("Plot")
    if plot ~= nil then
        local recyclers = Workspace:FindFirstChild("Recyclers")
        local r = recyclers and recyclers:FindFirstChild("Recycler" .. tostring(plot))
        local cf = pivotOf(r)
        if cf then return cf end
    end

    local recyclers = Workspace:FindFirstChild("Recyclers")
    if recyclers then
        for _, r in ipairs(recyclers:GetChildren()) do
            local cf = pivotOf(r)
            if cf then return cf end
        end
    end
    return nil
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

local function recycleLoop()
    local run = RunIds.autoRecycle
    task.spawn(function()
        while S.autoRecycle and run == RunIds.autoRecycle do
            local cf = recyclerCF()
            if cf then
                teleportCF(cf + Vector3.new(0, 3, 0))
            end
            task.wait(1.0)
        end
    end)
end

-- ============================================================
-- RECYCLER / REBIRTH
-- ============================================================

local function recyclerCanUpgrade()
    local scrap = getState({"scrap"})
    if type(scrap) ~= "table" then return true end

    if RecyclerView then
        local level = tonumber(scrap.recyclerLevel) or 0
        local ok, cost = pcall(function()
            return RecyclerView.upgradeCost(level)
        end)
        if ok and tonumber(cost) then
            local money = getState({"money"})
            if tonumber(money) then
                return tonumber(money) >= tonumber(cost)
            end
        end
    end
    return true
end

local function upgradeRecycler()
    if not recyclerCanUpgrade() then return false end
    local result = invokeDef("UpgradeRecycler")
    return resultOK(result)
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
            if type(coop) == "table" and type(coop.generators) == "table" then
                for _, g in pairs(coop.generators) do
                    if S.coopMode ~= "Expand Only" and g and g.slot and g.level then
                        upgradeGenerator(g.slot)
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

                for _, g in pairs(generators) do
                    if g and g.slot then
                        count = count + 1
                        if S.feederMode ~= "Buy Only" then
                            upgradeGenerator(g.slot)
                            task.wait(0.3)
                        end
                    end
                end

                if S.feederMode ~= "Upgrade Only" and count < maxSlot then
                    buyGenerator(count + 1)
                elseif S.feederMode ~= "Upgrade Only" and count == 0 then
                    buyGenerator(1)
                end
            end

            task.wait(2)
        end
    end)
end

-- ============================================================
-- HUD BUTTON HELPERS
-- ============================================================

local function normalizeText(v)
    return string.lower(tostring(v or "")):gsub("[%p]", " ")
end

local function visibleTextButtons()
    local list = {}
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible and obj.Active then
            table.insert(list, obj)
        end
    end
    return list
end

local function clickHUDButton(words)
    for _, btn in ipairs(visibleTextButtons()) do
        local text = normalizeText(btn.Text)
        local match = true
        for _, word in ipairs(words) do
            if not text:find(string.lower(word), 1, true) then
                match = false
                break
            end
        end

        if match then
            pcall(function() btn:Activate() end)
            return true
        end
    end
    return false
end

local function currentOrder()
    if ChickenMode and type(ChickenMode.order) == "function" then
        local ok, value = pcall(ChickenMode.order)
        if ok then return value end
    end
    return nil
end

local function currentWhere()
    if ChickenMode and type(ChickenMode.where) == "function" then
        local ok, value = pcall(ChickenMode.where)
        if ok then return value end
    end
    return nil
end

local function startTowerOnce()
    if currentOrder() == "tower" then return false end
    return clickHUDButton({"tower"})
end

local function startChaosOnce()
    if currentOrder() == "chaos" then return false end
    return clickHUDButton({"chaos"})
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

local function towerLoop()
    local run = RunIds.autoTower
    task.spawn(function()
        while S.autoTower and run == RunIds.autoTower do
            startTowerOnce()
            task.wait(1.5)
        end
    end)
end

local function eventIsActive()
    local id = Workspace:GetAttribute("EventId")
    local phase = Workspace:GetAttribute("EventPhase")
    local deadline = Workspace:GetAttribute("EventDeadline")

    if not id or not phase or not deadline then return false end
    return phase == "warmup" or phase == "live"
end

local function eventChaosLoop()
    local run = RunIds.autoEventChaos
    task.spawn(function()
        local lastEvent = nil
        while S.autoEventChaos and run == RunIds.autoEventChaos do
            local id = Workspace:GetAttribute("EventId")
            local active = eventIsActive()

            if active and id ~= lastEvent then
                lastEvent = id
                startChaosOnce()
            elseif not active then
                lastEvent = nil
            end

            task.wait(0.75)
        end
    end)
end

local function noThanksOnce()
    return clickHUDButton({"no", "thanks"}) or clickHUDButton({"no thanks"})
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

local antiAFKConnection
local function setAntiAFK(enabled)
    S.antiAFK = enabled
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end

    if not enabled then return end

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

local function setFeature(key, value)
    if RunIds[key] == nil then return end

    S[key] = value and true or false
    RunIds[key] = RunIds[key] + 1

    if key == "autoEgg" and S.autoEgg then hatchLoop()
    elseif key == "autoFuse" and S.autoFuse then fuseLoop()
    elseif key == "autoScrap" and S.autoScrap then scrapLoop()
    elseif key == "autoRecycle" and S.autoRecycle then recycleLoop()
    elseif key == "autoRecycler" and S.autoRecycler then recyclerLoop()
    elseif key == "autoRebirth" and S.autoRebirth then rebirthLoop()
    elseif key == "autoCoop" and S.autoCoop then coopLoop()
    elseif key == "autoFeeders" and S.autoFeeders then feederLoop()
    elseif key == "autoTower" and S.autoTower then towerLoop()
    elseif key == "autoChaos" and S.autoChaos then chaosLoop()
    elseif key == "autoEventChaos" and S.autoEventChaos then eventChaosLoop()
    elseif key == "autoNoThanks" and S.autoNoThanks then noThanksLoop()
    end
end

local function stopAll()
    for key in pairs(RunIds) do
        S[key] = false
        RunIds[key] = RunIds[key] + 1
    end
end

-- ============================================================
-- GUI - SAME COMPACT PATTERN AS SUDOKU V9
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HAIMIYACH_GAF_V2"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local portrait = viewport.Y >= viewport.X
local function clampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local guiWidth = clampNumber(math.floor(viewport.X * (portrait and 0.78 or 0.38)), 220, 270)
local guiHeight = clampNumber(math.floor(viewport.Y * (portrait and 0.58 or 0.62)), 300, 390)

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
Header.BorderSizePixel = 0
Header.Parent = Header

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

-- tab bar
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
local currentTab

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
    currentTab = name
    for n, p in pairs(Pages) do p.Visible = n == name end
    for n, b in pairs(Tabs) do
        local on = n == name
        b.BackgroundColor3 = on and Color3.fromRGB(72, 74, 84) or Color3.fromRGB(43, 44, 51)
        b.TextColor3 = on and Color3.fromRGB(245,246,249) or Color3.fromRGB(164,166,175)
    end
end

local function section(page, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 15)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(112,115,127)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 7
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = page
end

local function action(page, text, icon, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(34,35,41)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.LayoutOrder = order
    b.Parent = page
    corner(b, 7)
    stroke(b)

    local i = Instance.new("TextLabel")
    i.Size = UDim2.fromOffset(22,34)
    i.Position = UDim2.fromOffset(6,0)
    i.BackgroundTransparency = 1
    i.Text = icon
    i.TextColor3 = Color3.fromRGB(190,193,202)
    i.Font = Enum.Font.GothamBold
    i.TextSize = 10
    i.Parent = b

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,-44,1,0)
    t.Position = UDim2.fromOffset(30,0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = Color3.fromRGB(226,228,235)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 8
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = b

    b.Activated:Connect(function()
        pcall(callback)
    end)
    return b
end

local function toggleRow(page, text, order, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = Color3.fromRGB(34,35,41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row,7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-78,1,0)
    label.Position = UDim2.fromOffset(10,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226,228,235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local t = Instance.new("TextButton")
    t.Size = UDim2.fromOffset(48,22)
    t.Position = UDim2.new(1,-58,0.5,-11)
    t.BackgroundColor3 = Color3.fromRGB(45,45,48)
    t.BorderSizePixel = 0
    t.AutoButtonColor = false
    t.Text = "OFF"
    t.Font = Enum.Font.GothamBold
    t.TextSize = 7
    t.TextColor3 = Color3.fromRGB(220,220,225)
    t.Parent = row
    corner(t,11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14,14)
    knob.BorderSizePixel = 0
    knob.Parent = t
    corner(knob,8)

    local function redraw()
        local enabled = false
        pcall(function() enabled = getter() end)
        t.Text = enabled and "ON" or "OFF"
        t.BackgroundColor3 = enabled and Color3.fromRGB(180,180,185) or Color3.fromRGB(45,45,48)
        t.TextColor3 = enabled and Color3.fromRGB(245,245,245) or Color3.fromRGB(220,220,225)
        knob.BackgroundColor3 = enabled and Color3.fromRGB(245,245,245) or Color3.fromRGB(165,165,170)
        knob.Position = enabled and UDim2.new(1,-18,0.5,-7) or UDim2.fromOffset(3,4)
    end

    t.Activated:Connect(function()
        local cur = false
        pcall(function() cur = getter() end)
        pcall(function() setter(not cur) end)
        task.defer(redraw)
    end)

    redraw()
    return row, redraw
end

local function dropdownRow(page, text, order, options, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,36)
    row.BackgroundColor3 = Color3.fromRGB(34,35,41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row,7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.42,0,1,0)
    label.Position = UDim2.fromOffset(10,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220,222,230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.54,-10,0,24)
    button.Position = UDim2.new(0.46,0,0.5,-12)
    button.BackgroundColor3 = Color3.fromRGB(45,46,54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextColor3 = Color3.fromRGB(222,224,231)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 8
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = row
    corner(button,6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1,0,0,0)
    list.BackgroundColor3 = Color3.fromRGB(30,31,37)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.LayoutOrder = order + 0.1
    list.Parent = page
    corner(list,7)
    stroke(list)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,3)
    layout.Parent = list

    local function refresh()
        local value = "?"
        pcall(function() value = getter() end)
        button.Text = tostring(value)
    end

    for i, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1,-8,0,27)
        item.BackgroundColor3 = Color3.fromRGB(40,41,48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. tostring(option)
        item.TextColor3 = Color3.fromRGB(222,224,231)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = i
        item.Parent = list
        corner(item,5)

        item.Activated:Connect(function()
            pcall(function() setter(option) end)
            refresh()
            list.Visible = false
            list.Size = UDim2.new(1,0,0,0)
        end)
    end

    button.Activated:Connect(function()
        local open = not list.Visible
        list.Visible = open
        list.Size = UDim2.new(1,0,0,open and math.min(#options*30+5,145) or 0)
        if open then refresh() end
    end)

    refresh()
    return row
end

-- pages / tabs
local Main = makePage("MAIN")
local Eggs = makePage("EGGS")
local Scrap = makePage("SCRAP")
local Coop = makePage("COOP")
local Tower = makePage("TOWER")
local Settings = makePage("SETTINGS")

makeTab("MAIN","◆",1).Activated:Connect(function() selectTab("MAIN") end)
makeTab("EGGS","◉",2).Activated:Connect(function() selectTab("EGGS") end)
makeTab("SCRAP","▣",3).Activated:Connect(function() selectTab("SCRAP") end)
makeTab("COOP","♜",4).Activated:Connect(function() selectTab("COOP") end)
makeTab("TOWER","⚔",5).Activated:Connect(function() selectTab("TOWER") end)
makeTab("SETTINGS","⚙",6).Activated:Connect(function() selectTab("SETTINGS") end)

-- MAIN
section(Main,"AUTOMATION",1)
toggleRow(Main,"Auto Rebirth",2,function() return S.autoRebirth end,function(v) setFeature("autoRebirth",v) end)
toggleRow(Main,"Auto Fuse Chickens",3,function() return S.autoFuse end,function(v) setFeature("autoFuse",v) end)
dropdownRow(Main,"Fuse Mode",4,{"Same Type","Same Rarity","Any"},function() return S.fuseMode end,function(v) S.fuseMode=v end)
dropdownRow(Main,"Fuse Rarity",5,{"Any","common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},function() return S.fuseRarity end,function(v) S.fuseRarity=v end)
toggleRow(Main,"Keep Favorite",6,function() return S.keepFavorite end,function(v) S.keepFavorite=v end)

-- EGGS
section(Eggs,"EGG AUTOMATION",1)
toggleRow(Eggs,"Auto Open Eggs",2,function() return S.autoEgg end,function(v) setFeature("autoEgg",v) end)
dropdownRow(Eggs,"Egg Selected",3,{"AUTO","barn","farm","golden","hotEgg","void"},function() return selectedEgg end,function(v) selectedEgg=v end)
dropdownRow(Eggs,"Open Amount",4,{"1","2","3","5","10","25"},function() return tostring(S.eggAmount) end,function(v) S.eggAmount=tonumber(v) or 1 end)
action(Eggs,"Open One Egg","🥚",6,function()
    local ok, err = hatchOne()
    notify("Egg",ok and "Hatched successfully." or tostring(err),2)
end)

-- SCRAP
section(Scrap,"SCRAP",1)
toggleRow(Scrap,"Auto Grab Scraps",2,function() return S.autoScrap end,function(v) setFeature("autoScrap",v) end)
dropdownRow(Scrap,"Scrap Target",3,{"Nearest"},function() return S.scrapFilter end,function(v) S.scrapFilter=v end)
action(Scrap,"Teleport to Scrap","↗",4,function()
    notify("Scrap",teleportNearestScrap() and "Teleported to nearest scrap." or "No scrap found.",2)
end)
toggleRow(Scrap,"Auto Recycle Scrap",6,function() return S.autoRecycle end,function(v) setFeature("autoRecycle",v) end)
action(Scrap,"Teleport Recycler","↗",7,function()
    local cf = recyclerCF()
    notify("Recycler",cf and (teleportCF(cf+Vector3.new(0,3,0)) and "Teleported.") or "Recycler not found.",2)
end)
toggleRow(Scrap,"Auto Upgrade Recycler",9,function() return S.autoRecycler end,function(v) setFeature("autoRecycler",v) end)
action(Scrap,"Upgrade Recycler Once","▲",10,function()
    notify("Recycler",upgradeRecycler() and "Upgrade sent." or "Upgrade unavailable.",2)
end)

-- COOP
section(Coop,"COOP / FEEDERS",1)
toggleRow(Coop,"Auto Upgrade Coop",2,function() return S.autoCoop end,function(v) setFeature("autoCoop",v) end)
dropdownRow(Coop,"Coop Mode",3,{"Upgrade All","Upgrade Only","Expand Only"},function() return S.coopMode end,function(v) S.coopMode=v end)
toggleRow(Coop,"Auto Buy Feeders",5,function() return S.autoFeeders end,function(v) setFeature("autoFeeders",v) end)
dropdownRow(Coop,"Feeder Mode",6,{"Buy + Upgrade","Buy Only","Upgrade Only"},function() return S.feederMode end,function(v) S.feederMode=v end)
action(Coop,"Buy Feeder Once","+",8,function()
    local coop=coopState()
    local count=type(coop)=="table" and type(coop.generators)=="table" and #coop.generators or 0
    notify("Feeder",buyGenerator(count+1) and "Buy request sent." or "Buy unavailable.",2)
end)
action(Coop,"Upgrade Coop Once","▲",9,function()
    notify("Coop",expandCoop() and "Expand request sent." or "Upgrade unavailable.",2)
end)

-- TOWER / CHAOS
section(Tower,"TOWER",1)
toggleRow(Tower,"Auto Start Tower",2,function() return S.autoTower end,function(v) setFeature("autoTower",v) end)
action(Tower,"Start Tower Now","⚔",3,function()
    notify("Tower",startTowerOnce() and "HUD button activated." or "Tower button not found.",2)
end)

section(Tower,"CHAOS",5)
toggleRow(Tower,"Auto Chaos",6,function() return S.autoChaos end,function(v) setFeature("autoChaos",v) end)
action(Tower,"Start Chaos Now","⚡",7,function()
    notify("Chaos",startChaosOnce() and "HUD button activated." or "Chaos button not found.",2)
end)

section(Tower,"EVENT",9)
toggleRow(Tower,"Auto Events → Chaos",10,function() return S.autoEventChaos end,function(v) setFeature("autoEventChaos",v) end)
toggleRow(Tower,"Auto No Thanks",11,function() return S.autoNoThanks end,function(v) setFeature("autoNoThanks",v) end)
action(Tower,"Event Status","i",13,function()
    local id=Workspace:GetAttribute("EventId")
    local phase=Workspace:GetAttribute("EventPhase")
    local deadline=Workspace:GetAttribute("EventDeadline")
    notify("Event",id and (tostring(id).." • "..tostring(phase).." • "..tostring(deadline)) or "No event.",3)
end)

-- Floating reopen object is declared before any callback can reference it.
local OpenButton

-- SETTINGS
section(Settings,"GENERAL",1)
toggleRow(Settings,"Anti AFK",2,function() return S.antiAFK end,function(v) setAntiAFK(v) end)
action(Settings,"Stop All Automation","■",4,function()
    stopAll()
    notify("HAIMIYACH","All automation stopped.",2)
end)
action(Settings,"Reload Modules","↻",5,function()
    loadModules()
    notify("HAIMIYACH","Game modules refreshed.",2)
end)
action(Settings,"Close Menu","×",6,function()
    Window.Visible=false
    OpenButton.Visible=true
end)

-- ============================================================
-- FLOATING REOPEN
-- ============================================================

OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(82,28)
OpenButton.AnchorPoint = Vector2.new(0.5,0)
OpenButton.Position = UDim2.new(0.5,0,0,7)
OpenButton.BackgroundColor3 = Color3.fromRGB(30,31,36)
OpenButton.BackgroundTransparency = 0.22
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "HAIMIYACH"
OpenButton.TextColor3 = Color3.fromRGB(240,241,245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui
corner(OpenButton,16)
stroke(OpenButton,0.25)

Close.Activated:Connect(function()
    Window.Visible=false
    OpenButton.Visible=true
end)

local function bindDrag(handle, target, openOnTap)
    local dragging=false
    local moved=false
    local startInput
    local startPos
    local conn

    handle.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        dragging=true
        moved=false
        startInput=input.Position
        startPos=target.Position

        if conn then conn:Disconnect() end
        conn=UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType~=Enum.UserInputType.Touch and move.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local d=move.Position-startInput
            if math.abs(d.X)>8 or math.abs(d.Y)>8 then moved=true end
            target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end)

        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                local wasMoved=moved
                dragging=false
                if conn then conn:Disconnect(); conn=nil end
                if openOnTap and not wasMoved then
                    Window.Visible=true
                    OpenButton.Visible=false
                end
            end
        end)
    end)
end

bindDrag(Header,Window,false)
bindDrag(OpenButton,OpenButton,true)

-- default
pcall(function()
    selectTab("MAIN")
end)
notify("HAIMIYACH","GAF V2 loaded.",3)
print("[HAIMIYACH_GAF_V2_FIXED] loaded")



print("[HAIMIYACH_GAF_V2_SUDOKU_UI_FIXED] loaded")
