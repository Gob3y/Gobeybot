-- ============================================================
-- DIG & CLEAN EXECUTOR - ALL IN ONE
-- Fitur lengkap berdasarkan referensi StarterPlayer
-- Support: Auto Teleport, Auto Buy, Auto Equip, Auto Appraise, dll
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- NOTIFICATION
-- ============================================================
local function notify(text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "DigClean",
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHeldTool()
    local char = getCharacter()
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child:GetAttribute("inventoryId") then
            return child
        end
    end
    return nil
end

local function getPlacedBoards()
    return Workspace:FindFirstChild("PlacedBoards")
end

local function getDigZones()
    local zones = {}
    local folder = Workspace:FindFirstChild("DigZones")
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") and part:GetAttribute("IsDigSpot") then
                table.insert(zones, part)
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "SurfacedItem" then
            local pos = pcall(obj.GetPivot, obj) and obj:GetPivot()
            if pos then
                table.insert(zones, {Position = pos.Position, IsSurfaced = true, Model = obj})
            end
        end
    end
    return zones
end

local function getNearestDigSpot()
    local root = getRoot()
    if not root then return nil end
    local zones = getDigZones()
    local best, bestDist = nil, math.huge
    for _, zone in ipairs(zones) do
        local pos = zone.Position or (zone:IsA("BasePart") and zone.Position)
        if pos then
            local dist = (pos - root.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                best = zone
            end
        end
    end
    return best
end

local function getPlayerData()
    if _G.DataController and _G.DataController.getData then
        local ok, data = pcall(_G.DataController.getData, _G.DataController)
        if ok and data then return data end
    end
    local hud = PlayerGui:FindFirstChild("HUD")
    if hud then
        local currency = hud:FindFirstChild("Currency")
        if currency then
            local gold = currency:FindFirstChild("Gold")
            if gold and gold:IsA("TextLabel") then
                local goldVal = tonumber(string.gsub(gold.Text, "[^%d]", "")) or 0
                return {Gold = goldVal}
            end
        end
    end
    return {Gold = 0}
end

-- ============================================================
-- REMOTE EVENT SCANNER
-- ============================================================
local function findRemoteEvent(name)
    local paths = {
        {"Remotes", name},
        {"Remotes", "Reliable", name},
        {"RemoteEvents", name},
        {"Remote", name},
        {"Events", name},
        {"ReplicatedStorage", name},
    }
    for _, path in ipairs(paths) do
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj and obj:FindFirstChild(part)
            if not obj then break end
        end
        if obj and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local remotes = {
    Dig = findRemoteEvent("Dig") or findRemoteEvent("StartDig") or findRemoteEvent("BeginDig"),
    Clean = findRemoteEvent("Clean") or findRemoteEvent("StartClean") or findRemoteEvent("BeginClean"),
    Sell = findRemoteEvent("Sell") or findRemoteEvent("SellItem") or findRemoteEvent("SellInventory"),
    Polish = findRemoteEvent("Polish") or findRemoteEvent("StartPolish"),
    Collect = findRemoteEvent("Collect") or findRemoteEvent("CollectItem"),
    Buy = findRemoteEvent("Buy") or findRemoteEvent("BuyGear") or findRemoteEvent("Purchase"),
    Equip = findRemoteEvent("Equip") or findRemoteEvent("EquipGear"),
    Appraise = findRemoteEvent("Appraise") or findRemoteEvent("AppraiseItem"),
    Claim = findRemoteEvent("Claim") or findRemoteEvent("ClaimReward"),
    Teleport = findRemoteEvent("Teleport") or findRemoteEvent("TeleportTo"),
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    AutoDig = false,
    AutoClean = false,
    AutoSell = false,
    AutoPolish = false,
    AutoCollect = false,
    AutoBuy = false,
    AutoEquip = false,
    AutoAppraise = false,
    AutoClaim = false,
    AutoDeleteSpot = false,
    ESP = false,
    AntiAFK = true,
    AutoTeleport = true,
    DigMode = "Normal", -- Normal / Fast / Safe
    SellRarity = "common",
    SellMode = "All",
    SellNonFavorited = true,
    BuyPriority = "Shovel",
    EquipPriority = "Power",
    ClaimType = "All",
    SelectedTarget = nil,
}

-- ============================================================
-- AUTO DIG (dengan Auto Teleport)
-- ============================================================
local function performDig()
    local root = getRoot()
    if not root then return false end

    -- Auto Teleport ke spot terdekat
    if State.AutoTeleport then
        local spot = getNearestDigSpot()
        if spot then
            local pos = spot.Position or (spot:IsA("BasePart") and spot.Position)
            if pos and (pos - root.Position).Magnitude > 8 then
                root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
                task.wait(0.2)
            end
        end
    end

    -- Method 1: RemoteEvent
    if remotes.Dig then
        pcall(remotes.Dig.FireServer, remotes.Dig)
        return true
    end

    -- Method 2: Controller
    if _G.DigController and _G.DigController.requestSession then
        pcall(_G.DigController.requestSession, _G.DigController)
        return true
    end

    -- Method 3: ProximityPrompt
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (parent.Position - root.Position).Magnitude
                if dist < 15 then
                    pcall(obj.InputHoldBegin, obj)
                    task.wait(0.3)
                    pcall(obj.InputHoldEnd, obj)
                    return true
                end
            end
        end
    end
    return false
end

local function startAutoDig()
    task.spawn(function()
        while State.AutoDig do
            local ok = performDig()
            if not ok then
                -- Jika gagal, coba teleport ke spot baru
                local spot = getNearestDigSpot()
                if spot then
                    local pos = spot.Position or (spot:IsA("BasePart") and spot.Position)
                    if pos then
                        local root = getRoot()
                        if root then
                            root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
                            task.wait(0.5)
                        end
                    end
                end
            end
            local waitTime = State.DigMode == "Fast" and 0.3 or State.DigMode == "Safe" and 1.2 or 0.7
            task.wait(waitTime)
        end
    end)
end

function toggleAutoDig(enabled)
    State.AutoDig = enabled
    if enabled then
        startAutoDig()
        notify("Auto Dig ON - Mode: " .. State.DigMode .. (State.AutoTeleport and " (Teleport)" or ""))
    else
        notify("Auto Dig OFF")
    end
end

-- ============================================================
-- AUTO CLEAN
-- ============================================================
local function performClean()
    if remotes.Clean then
        pcall(remotes.Clean.FireServer, remotes.Clean)
        return true
    end

    if _G.WorkbenchController and _G.WorkbenchController.onTriggered then
        pcall(_G.WorkbenchController.onTriggered, _G.WorkbenchController)
        return true
    end

    local root = getRoot()
    if root then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "Workbench" then
                local cf = pcall(obj.GetPivot, obj) and obj:GetPivot()
                if cf and (cf.Position - root.Position).Magnitude < 20 then
                    -- Teleport ke workbench
                    root.CFrame = cf * CFrame.new(0, 2, 3)
                    task.wait(0.3)
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("ProximityPrompt") and child.Enabled then
                            pcall(child.InputHoldBegin, child)
                            task.wait(0.5)
                            pcall(child.InputHoldEnd, child)
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function startAutoClean()
    task.spawn(function()
        while State.AutoClean do
            performClean()
            task.wait(1.5)
        end
    end)
end

function toggleAutoClean(enabled)
    State.AutoClean = enabled
    if enabled then
        startAutoClean()
        notify("Auto Clean ON")
    else
        notify("Auto Clean OFF")
    end
end

-- ============================================================
-- AUTO SELL (dengan filter rarity)
-- ============================================================
local RARITY_ORDER = {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"}

local function shouldSellItem(item)
    if State.SellNonFavorited and item.favorited then return false end
    local itemRarity = item.rarity or "common"
    local minIdx = table.find(RARITY_ORDER, State.SellRarity) or 1
    local itemIdx = table.find(RARITY_ORDER, itemRarity) or 1
    return itemIdx >= minIdx
end

local function performSell()
    if remotes.Sell then
        pcall(remotes.Sell.FireServer, remotes.Sell)
        return true
    end

    if _G.SellFunctions and _G.SellFunctions.sellInventory then
        pcall(_G.SellFunctions.sellInventory.invoke, _G.SellFunctions.sellInventory)
        return true
    end

    local root = getRoot()
    if root then
        local seller = Workspace:FindFirstChild("SellerNPC") or Workspace:FindFirstChild("BuyerBob")
        if seller then
            local cf = pcall(seller.GetPivot, seller) and seller:GetPivot()
            if cf and (cf.Position - root.Position).Magnitude < 15 then
                root.CFrame = cf * CFrame.new(0, 2, 3)
                task.wait(0.3)
                for _, child in ipairs(seller:GetDescendants()) do
                    if child:IsA("ProximityPrompt") and child.Enabled then
                        pcall(child.InputHoldBegin, child)
                        task.wait(0.5)
                        pcall(child.InputHoldEnd, child)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function startAutoSell()
    task.spawn(function()
        while State.AutoSell do
            performSell()
            task.wait(8)
        end
    end)
end

function toggleAutoSell(enabled)
    State.AutoSell = enabled
    if enabled then
        startAutoSell()
        notify("Auto Sell ON - Rarity: " .. State.SellRarity)
    else
        notify("Auto Sell OFF")
    end
end

-- ============================================================
-- AUTO POLISH
-- ============================================================
local function performPolish()
    if remotes.Polish then
        pcall(remotes.Polish.FireServer, remotes.Polish)
        return true
    end

    if _G.PolisherFunctions and _G.PolisherFunctions.startPolish then
        pcall(_G.PolisherFunctions.startPolish.invoke, _G.PolisherFunctions.startPolish, 1)
        return true
    end

    local root = getRoot()
    if root then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:GetAttribute("PolisherSlot") then
                local cf = pcall(obj.GetPivot, obj) and obj:GetPivot()
                if cf and (cf.Position - root.Position).Magnitude < 20 then
                    root.CFrame = cf * CFrame.new(0, 2, 3)
                    task.wait(0.3)
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("ProximityPrompt") and child.Enabled then
                            pcall(child.InputHoldBegin, child)
                            task.wait(0.5)
                            pcall(child.InputHoldEnd, child)
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function startAutoPolish()
    task.spawn(function()
        while State.AutoPolish do
            performPolish()
            task.wait(3)
        end
    end)
end

function toggleAutoPolish(enabled)
    State.AutoPolish = enabled
    if enabled then
        startAutoPolish()
        notify("Auto Polish ON")
    else
        notify("Auto Polish OFF")
    end
end

-- ============================================================
-- AUTO COLLECT
-- ============================================================
local function performCollect()
    if remotes.Collect then
        pcall(remotes.Collect.FireServer, remotes.Collect)
        return true
    end

    local root = getRoot()
    if root then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "SurfacedItem" or obj.Name == "Pedestal") then
                local cf = pcall(obj.GetPivot, obj) and obj:GetPivot()
                if cf and (cf.Position - root.Position).Magnitude < 10 then
                    root.CFrame = CFrame.new(cf.Position + Vector3.new(0, 2, 0))
                    task.wait(0.2)
                    for _, child in ipairs(obj:GetDescendants()) do
                        if child:IsA("ProximityPrompt") and child.Enabled then
                            pcall(child.InputHoldBegin, child)
                            task.wait(0.5)
                            pcall(child.InputHoldEnd, child)
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function startAutoCollect()
    task.spawn(function()
        while State.AutoCollect do
            performCollect()
            task.wait(1)
        end
    end)
end

function toggleAutoCollect(enabled)
    State.AutoCollect = enabled
    if enabled then
        startAutoCollect()
        notify("Auto Collect ON")
    else
        notify("Auto Collect OFF")
    end
end

-- ============================================================
-- AUTO BUY
-- ============================================================
local function performBuy()
    if remotes.Buy then
        pcall(remotes.Buy.FireServer, remotes.Buy)
        return true
    end

    if _G.ShopFunctions and _G.ShopFunctions.buyGear then
        local priority = State.BuyPriority:lower()
        pcall(_G.ShopFunctions.buyGear.invoke, _G.ShopFunctions.buyGear, priority, "best")
        return true
    end

    -- Cari UI Shop dan klik tombol beli
    local shop = PlayerGui:FindFirstChild("Main"):FindFirstChild("Shop")
    if shop then
        local buyBtn = shop:FindFirstChild("BuyButton")
        if buyBtn and buyBtn:IsA("TextButton") then
            pcall(buyBtn.Activated.Invoke, buyBtn)
            return true
        end
    end
    return false
end

local function startAutoBuy()
    task.spawn(function()
        while State.AutoBuy do
            performBuy()
            task.wait(10)
        end
    end)
end

function toggleAutoBuy(enabled)
    State.AutoBuy = enabled
    if enabled then
        startAutoBuy()
        notify("Auto Buy ON - Priority: " .. State.BuyPriority)
    else
        notify("Auto Buy OFF")
    end
end

-- ============================================================
-- AUTO EQUIP
-- ============================================================
local function performEquip()
    if remotes.Equip then
        pcall(remotes.Equip.FireServer, remotes.Equip)
        return true
    end

    if _G.ShopFunctions and _G.ShopFunctions.equipGear then
        pcall(_G.ShopFunctions.equipGear.invoke, _G.ShopFunctions.equipGear, "shovel", "best")
        pcall(_G.ShopFunctions.equipGear.invoke, _G.ShopFunctions.equipGear, "detector", "best")
        pcall(_G.ShopFunctions.equipGear.invoke, _G.ShopFunctions.equipGear, "spray", "best")
        return true
    end

    return false
end

local function startAutoEquip()
    task.spawn(function()
        while State.AutoEquip do
            performEquip()
            task.wait(30)
        end
    end)
end

function toggleAutoEquip(enabled)
    State.AutoEquip = enabled
    if enabled then
        startAutoEquip()
        notify("Auto Equip ON")
    else
        notify("Auto Equip OFF")
    end
end

-- ============================================================
-- AUTO APPRAISE
-- ============================================================
local function performAppraise()
    if remotes.Appraise then
        pcall(remotes.Appraise.FireServer, remotes.Appraise)
        return true
    end

    -- Cari UI Appraise
    local ui = PlayerGui:FindFirstChild("Main")
    if ui then
        local appraiseBtn = ui:FindFirstChild("AppraiseButton")
        if appraiseBtn and appraiseBtn:IsA("TextButton") then
            pcall(appraiseBtn.Activated.Invoke, appraiseBtn)
            return true
        end
    end
    return false
end

local function startAutoAppraise()
    task.spawn(function()
        while State.AutoAppraise do
            performAppraise()
            task.wait(5)
        end
    end)
end

function toggleAutoAppraise(enabled)
    State.AutoAppraise = enabled
    if enabled then
        startAutoAppraise()
        notify("Auto Appraise ON")
    else
        notify("Auto Appraise OFF")
    end
end

-- ============================================================
-- AUTO CLAIM
-- ============================================================
local function performClaim()
    if remotes.Claim then
        pcall(remotes.Claim.FireServer, remotes.Claim)
        return true
    end

    -- Cari UI Claim
    local ui = PlayerGui:FindFirstChild("Main")
    if ui then
        for _, obj in ipairs(ui:GetDescendants()) do
            if obj:IsA("TextButton") and string.find(obj.Name or "", "Claim") then
                pcall(obj.Activated.Invoke, obj)
                return true
            end
        end
    end
    return false
end

local function startAutoClaim()
    task.spawn(function()
        while State.AutoClaim do
            performClaim()
            task.wait(10)
        end
    end)
end

function toggleAutoClaim(enabled)
    State.AutoClaim = enabled
    if enabled then
        startAutoClaim()
        notify("Auto Claim ON")
    else
        notify("Auto Claim OFF")
    end
end

-- ============================================================
-- AUTO DELETE SPOT
-- ============================================================
local function performDeleteSpot()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "SurfacedItem" then
            local collected = obj:GetAttribute("Collected") or false
            if collected then
                pcall(obj.Destroy, obj)
            end
        end
    end
end

local function startAutoDeleteSpot()
    task.spawn(function()
        while State.AutoDeleteSpot do
            performDeleteSpot()
            task.wait(2)
        end
    end)
end

function toggleAutoDeleteSpot(enabled)
    State.AutoDeleteSpot = enabled
    if enabled then
        startAutoDeleteSpot()
        notify("Auto Delete Spot ON")
    else
        notify("Auto Delete Spot OFF")
    end
end

-- ============================================================
-- ESP
-- ============================================================
local espMarkers = {}

local function clearESP()
    for _, marker in ipairs(espMarkers) do
        pcall(marker.Destroy, marker)
    end
    table.clear(espMarkers)
end

local function updateESP()
    clearESP()
    if not State.ESP then return end

    local zones = getDigZones()
    for _, zone in ipairs(zones) do
        local pos = zone.Position or (zone:IsA("BasePart") and zone.Position)
        if pos then
            local marker = Instance.new("Part")
            marker.Size = Vector3.new(0.6, 0.1, 0.6)
            marker.Position = pos + Vector3.new(0, 0.1, 0)
            marker.Anchored = true
            marker.CanCollide = false
            marker.Transparency = 0.3
            marker.BrickColor = zone.IsSurfaced and BrickColor.Yellow() or BrickColor.Green()
            marker.Parent = Workspace
            table.insert(espMarkers, marker)

            -- Label
            local bill = Instance.new("BillboardGui")
            bill.Size = UDim2.new(0, 60, 0, 30)
            bill.StudsOffset = Vector3.new(0, 1.5, 0)
            bill.Adornee = marker
            bill.Parent = marker
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = zone.IsSurfaced and "🔶 ITEM" or "⚡ DIG"
            label.TextColor3 = zone.IsSurfaced and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(0, 255, 0)
            label.Font = Enum.Font.GothamBold
            label.TextScaled = true
            label.Parent = bill
            table.insert(espMarkers, bill)
        end
    end
end

local function startESP()
    task.spawn(function()
        while State.ESP do
            updateESP()
            task.wait(1)
        end
    end)
end

function toggleESP(enabled)
    State.ESP = enabled
    if enabled then
        startESP()
        notify("ESP ON")
    else
        clearESP()
        notify("ESP OFF")
    end
end

-- ============================================================
-- TELEPORT
-- ============================================================
function teleportToPlot()
    local root = getRoot()
    if not root then notify("Character not ready") return end
    local placedBoards = getPlacedBoards()
    if placedBoards then
        for _, board in ipairs(placedBoards:GetChildren()) do
            if board:IsA("Model") then
                local owner = board:GetAttribute("OwnerUserId")
                if owner and tonumber(owner) == LocalPlayer.UserId then
                    local cf = pcall(board.GetPivot, board) and board:GetPivot()
                    if cf then
                        root.CFrame = cf * CFrame.new(0, 5, 0)
                        notify("Teleported to plot")
                        return
                    end
                end
            end
        end
    end
    notify("Plot not found")
end

function teleportToNearestDig()
    local root = getRoot()
    if not root then return end
    local spot = getNearestDigSpot()
    if spot then
        local pos = spot.Position or (spot:IsA("BasePart") and spot.Position)
        if pos then
            root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
            notify("Teleported to dig spot")
            return
        end
    end
    notify("No dig spot found")
end

function teleportToSeller()
    local root = getRoot()
    if not root then return end
    local seller = Workspace:FindFirstChild("SellerNPC") or Workspace:FindFirstChild("BuyerBob")
    if seller then
        local cf = pcall(seller.GetPivot, seller) and seller:GetPivot()
        if cf then
            root.CFrame = cf * CFrame.new(0, 2, 3)
            notify("Teleported to seller")
            return
        end
    end
    notify("Seller not found")
end

function teleportToTarget()
    if not State.SelectedTarget then
        notify("No target selected")
        return
    end
    local root = getRoot()
    if not root then return end
    local placedBoards = getPlacedBoards()
    if placedBoards then
        for _, board in ipairs(placedBoards:GetChildren()) do
            if board:IsA("Model") then
                local owner = board:GetAttribute("OwnerUserId")
                if owner and tonumber(owner) == State.SelectedTarget then
                    local cf = pcall(board.GetPivot, board) and board:GetPivot()
                    if cf then
                        root.CFrame = cf * CFrame.new(0, 5, 0)
                        notify("Teleported to target")
                        return
                    end
                end
            end
        end
    end
    notify("Target board not found")
end

-- ============================================================
-- ANTI AFK
-- ============================================================
local function startAntiAFK()
    task.spawn(function()
        while State.AntiAFK do
            task.wait(55)
            local root = getRoot()
            if root then
                local pos = root.Position
                root.CFrame = CFrame.new(pos.X + 0.01, pos.Y, pos.Z + 0.01)
                task.wait(0.05)
                root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
            end
        end
    end)
end

function toggleAntiAFK(enabled)
    State.AntiAFK = enabled
    if enabled then
        startAntiAFK()
        notify("Anti AFK ON")
    else
        notify("Anti AFK OFF")
    end
end

startAntiAFK()

-- ============================================================
-- INFO
-- ============================================================
function showInfo()
    local data = getPlayerData()
    local gold = data.Gold or 0
    local luck = 1
    local island = "?"
    local inventory = 0

    local hud = PlayerGui:FindFirstChild("HUD")
    if hud then
        local luckLabel = hud:FindFirstChild("Luck")
        if luckLabel and luckLabel:IsA("TextLabel") then
            local luckVal = tonumber(string.match(luckLabel.Text, "([%d.]+)"))
            if luckVal then luck = luckVal end
        end
        local islandLabel = hud:FindFirstChild("Island")
        if islandLabel and islandLabel:IsA("TextLabel") then
            island = islandLabel.Text
        end
    end

    local inv = getInventoryData()
    if inv then inventory = #inv end

    notify(string.format(
        "Gold: %d | Luck: %.1fx | Island: %s | Items: %d\nAutoTeleport: %s | DigMode: %s",
        gold, luck, island, inventory,
        State.AutoTeleport and "ON" or "OFF",
        State.DigMode
    ), 5)
end

local function getInventoryData()
    if _G.DataController and _G.DataController.getData then
        local ok, data = pcall(_G.DataController.getData, _G.DataController)
        if ok and data and data.Inventory then
            return data.Inventory
        end
    end
    return {}
end

-- ============================================================
-- COMMAND SYSTEM
-- ============================================================
_G.DigClean = {
    -- Toggle
    autoDig = toggleAutoDig,
    autoClean = toggleAutoClean,
    autoSell = toggleAutoSell,
    autoPolish = toggleAutoPolish,
    autoCollect = toggleAutoCollect,
    autoBuy = toggleAutoBuy,
    autoEquip = toggleAutoEquip,
    autoAppraise = toggleAutoAppraise,
    autoClaim = toggleAutoClaim,
    autoDeleteSpot = toggleAutoDeleteSpot,
    esp = toggleESP,
    antiAFK = toggleAntiAFK,

    -- Settings
    setDigMode = function(mode)
        if mode == "Normal" or mode == "Fast" or mode == "Safe" then
            State.DigMode = mode
            notify("Dig mode: " .. mode)
        end
    end,
    setSellRarity = function(rarity)
        if table.find(RARITY_ORDER, rarity) then
            State.SellRarity = rarity
            notify("Sell rarity: " .. rarity)
        end
    end,
    setSellMode = function(mode)
        if mode == "All" or mode == "Held" or mode == "Filtered" then
            State.SellMode = mode
            notify("Sell mode: " .. mode)
        end
    end,
    setBuyPriority = function(priority)
        if priority == "Shovel" or priority == "Detector" or priority == "Spray" then
            State.BuyPriority = priority
            notify("Buy priority: " .. priority)
        end
    end,
    setEquipPriority = function(priority)
        if priority == "Power" or priority == "Luck" or priority == "Speed" then
            State.EquipPriority = priority
            notify("Equip priority: " .. priority)
        end
    end,
    setAutoTeleport = function(enabled)
        State.AutoTeleport = enabled
        notify("Auto Teleport: " .. (enabled and "ON" or "OFF"))
    end,
    setTarget = function(userId)
        State.SelectedTarget = userId
        local player = Players:GetPlayerByUserId(userId)
        notify("Target: " .. (player and player.Name or "Unknown"))
    end,

    -- Teleport
    teleportPlot = teleportToPlot,
    teleportDig = teleportToNearestDig,
    teleportSeller = teleportToSeller,
    teleportTarget = teleportToTarget,

    -- Info
    info = showInfo,
    status = function()
        notify(string.format(
            "Dig: %s | Clean: %s | Sell: %s | Polish: %s | Collect: %s | Buy: %s | Equip: %s | ESP: %s | AFK: %s\nMode: %s | Rarity: %s | AutoTeleport: %s",
            State.AutoDig and "ON" or "OFF",
            State.AutoClean and "ON" or "OFF",
            State.AutoSell and "ON" or "OFF",
            State.AutoPolish and "ON" or "OFF",
            State.AutoCollect and "ON" or "OFF",
            State.AutoBuy and "ON" or "OFF",
            State.AutoEquip and "ON" or "OFF",
            State.ESP and "ON" or "OFF",
            State.AntiAFK and "ON" or "OFF",
            State.DigMode,
            State.SellRarity,
            State.AutoTeleport and "ON" or "OFF"
        ), 5)
    end,
    stopAll = function()
        toggleAutoDig(false)
        toggleAutoClean(false)
        toggleAutoSell(false)
        toggleAutoPolish(false)
        toggleAutoCollect(false)
        toggleAutoBuy(false)
        toggleAutoEquip(false)
        toggleAutoAppraise(false)
        toggleAutoClaim(false)
        toggleAutoDeleteSpot(false)
        toggleESP(false)
        notify("All loops stopped")
    end,
}

print("DigClean All-In-One loaded!")
print("Commands: _G.DigClean.autoDig(true/false), .autoClean, .autoSell, .autoPolish, .autoCollect, .autoBuy, .autoEquip, .autoAppraise, .autoClaim, .autoDeleteSpot, .esp, .antiAFK")
print("Settings: .setDigMode('Normal'/'Fast'/'Safe'), .setSellRarity('common'/'rare'/'epic'/...), .setAutoTeleport(true/false), .setTarget(userId)")
print("Teleport: .teleportPlot(), .teleportDig(), .teleportSeller(), .teleportTarget()")
print("Info: .info(), .status(), .stopAll()")

-- ============================================================
-- UI LENGKAP
-- ============================================================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DigCleanUI"
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui

    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.fromOffset(220, 460)
    frame.Position = UDim2.new(0, 10, 0.5, -230)
    frame.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 3
    frame.ScrollingDirection = Enum.ScrollingDirection.Y
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.CanvasSize = UDim2.new()
    frame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local function makeLabel(text, color)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 25)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.Parent = frame
        return label
    end

    local function makeToggle(text, getter, setter)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
        row.BorderSizePixel = 0
        row.Parent = frame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.55, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 222, 230)
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(50, 22)
        btn.Position = UDim2.new(0.78, 0, 0.5, -11)
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
        btn.BorderSizePixel = 0
        btn.Text = "OFF"
        btn.TextColor3 = Color3.fromRGB(175, 177, 185)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8
        btn.Parent = row
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 11)
        bc.Parent = btn

        local function update()
            local enabled = getter()
            btn.Text = enabled and "ON" or "OFF"
            btn.BackgroundColor3 = enabled and Color3.fromRGB(82, 84, 94) or Color3.fromRGB(45, 45, 48)
            btn.TextColor3 = enabled and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(175, 177, 185)
        end

        btn.MouseButton1Click:Connect(function()
            setter(not getter())
            update()
        end)
        update()
        return row
    end

    local function makeButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.Parent = frame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    makeLabel("⚙️ AUTOMATION", Color3.fromRGB(100, 200, 255))
    makeToggle("Auto Dig", function() return State.AutoDig end, toggleAutoDig)
    makeToggle("Auto Clean", function() return State.AutoClean end, toggleAutoClean)
    makeToggle("Auto Sell", function() return State.AutoSell end, toggleAutoSell)
    makeToggle("Auto Polish", function() return State.AutoPolish end, toggleAutoPolish)
    makeToggle("Auto Collect", function() return State.AutoCollect end, toggleAutoCollect)

    makeLabel("🛒 SHOP", Color3.fromRGB(255, 200, 100))
    makeToggle("Auto Buy", function() return State.AutoBuy end, toggleAutoBuy)
    makeToggle("Auto Equip", function() return State.AutoEquip end, toggleAutoEquip)

    makeLabel("📦 ITEM", Color3.fromRGB(100, 255, 150))
    makeToggle("Auto Appraise", function() return State.AutoAppraise end, toggleAutoAppraise)
    makeToggle("Auto Claim", function() return State.AutoClaim end, toggleAutoClaim)
    makeToggle("Auto Delete Spot", function() return State.AutoDeleteSpot end, toggleAutoDeleteSpot)

    makeLabel("👁️ ESP", Color3.fromRGB(255, 150, 255))
    makeToggle("ESP", function() return State.ESP end, toggleESP)

    makeLabel("⚡ TELEPORT", Color3.fromRGB(255, 255, 100))
    makeButton("Teleport Plot", teleportToPlot)
    makeButton("Teleport Dig", teleportToNearestDig)
    makeButton("Teleport Seller", teleportToSeller)

    makeLabel("ℹ️ INFO", Color3.fromRGB(150, 200, 255))
    makeButton("Show Info", showInfo)
    makeButton("Stop All", function()
        _G.DigClean.stopAll()
    end)

    return gui
end

task.spawn(createUI)
notify("DigClean All-In-One loaded! UI di pojok kiri.")