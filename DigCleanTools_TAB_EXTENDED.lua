-- ============================================================
-- DIG & CLEAN FULL SCRIPT
-- Gabungan Core + UI Extended
-- Support semua fitur: Auto Dig, Clean, Sell, Polish, Buy, dll
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEAN OLD INSTANCE
-- ============================================================
pcall(function()
    local old = PlayerGui:FindFirstChild("DigClean_FULL")
    if old then old:Destroy() end
end)

-- ============================================================
-- NOTIFICATION
-- ============================================================
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "DigClean"),
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

-- ============================================================
-- LOAD GAME MODULES (dari struktur Dig&Clean)
-- ============================================================
local function findModule(root, name)
    if not root then return nil end
    local direct = root:FindFirstChild(name)
    if direct and direct:IsA("ModuleScript") then return direct end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == name and obj:IsA("ModuleScript") then return obj end
    end
    return nil
end

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

local DigController, ShovelController, DetectorController, SprayBottleController, WorkbenchController
local PlotController, DataController, IslandController, SellFunctions, PolisherFunctions, ShopFunctions, Items

local function loadGameModules()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if not ps then return end
    local ts = ps:FindFirstChild("TS")
    if not ts then return end

    local controllers = ts:FindFirstChild("controllers")
    if controllers then
        local world = controllers:FindFirstChild("world")
        if world then
            DigController = require(findModule(world, "DigController"))
            ShovelController = require(findModule(world, "ShovelController"))
            DetectorController = require(findModule(world, "DetectorController"))
            SprayBottleController = require(findModule(world, "SprayBottleController"))
            WorkbenchController = require(findModule(world, "WorkbenchController"))
        end
        local plot = controllers:FindFirstChild("plot")
        if plot then
            PlotController = require(findModule(plot, "PlotController"))
        end
        local data = controllers:FindFirstChild("data")
        if data then
            DataController = require(findModule(data, "DataController"))
        end
        local world2 = controllers:FindFirstChild("world")
        if world2 then
            IslandController = require(findModule(world2, "IslandController"))
        end
    end

    local network = ts:FindFirstChild("network")
    if network then
        local sellMod = findModule(network, "SellNetwork")
        if sellMod then
            local ok, res = pcall(require, sellMod)
            if ok and res and res.SellFunctions then
                SellFunctions = res.SellFunctions
            end
        end
        local polishMod = findModule(network, "PolisherNetwork")
        if polishMod then
            local ok, res = pcall(require, polishMod)
            if ok and res and res.PolisherFunctions then
                PolisherFunctions = res.PolisherFunctions
            end
        end
        local shopMod = findModule(network, "ShopNetwork")
        if shopMod then
            local ok, res = pcall(require, shopMod)
            if ok and res and res.ShopFunctions then
                ShopFunctions = res.ShopFunctions
            end
        end
    end

    local constants = ts:FindFirstChild("constants")
    if constants then
        local items = constants:FindFirstChild("items")
        if items then
            local itemsMod = findModule(items, "Items")
            if itemsMod then
                local ok, res = pcall(require, itemsMod)
                if ok and res then
                    Items = res
                end
            end
        end
    end
end

loadGameModules()

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

local function getInventoryData()
    if DataController and DataController.getData then
        local data = safeCall(DataController.getData, DataController)
        if data and data.Inventory then
            return data.Inventory
        end
    end
    return {}
end

local function getGold()
    if DataController and DataController.getData then
        local data = safeCall(DataController.getData, DataController)
        if data and data.Gold then
            return data.Gold
        end
    end
    return 0
end

local function getLuck()
    if DataController and DataController.getData then
        local data = safeCall(DataController.getData, DataController)
        if data and data.Luck then
            return data.Luck
        end
    end
    return 1
end

local function getCurrentIsland()
    if IslandController and IslandController.getCurrentIslandId then
        return safeCall(IslandController.getCurrentIslandId, IslandController) or "?"
    end
    return "?"
end

-- Rarity order
local RARITY_ORDER = {}
if Items and Items.RARITY_ORDER then
    RARITY_ORDER = Items.RARITY_ORDER
else
    RARITY_ORDER = {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"}
end

local function rarityIndex(rarity)
    for i, r in ipairs(RARITY_ORDER) do
        if r == rarity then return i end
    end
    return 0
end

-- ============================================================
-- TARGET SYSTEM
-- ============================================================
local selectedTargetId = nil
local selectedTargetName = "None"

local function getTargetBoard(playerId)
    if not playerId then return nil end
    local placedBoards = Workspace:FindFirstChild("PlacedBoards")
    if not placedBoards then return nil end
    for _, board in ipairs(placedBoards:GetChildren()) do
        local owner = board:GetAttribute("OwnerUserId")
        if owner and tonumber(owner) == playerId then
            return board
        end
    end
    return nil
end

local function getAvailableTargets()
    local targets = {}
    local placedBoards = Workspace:FindFirstChild("PlacedBoards")
    if not placedBoards then return targets end
    for _, board in ipairs(placedBoards:GetChildren()) do
        local owner = board:GetAttribute("OwnerUserId")
        if owner and tonumber(owner) ~= LocalPlayer.UserId then
            local player = Players:GetPlayerByUserId(owner)
            if player then
                table.insert(targets, {
                    userId = owner,
                    name = player.Name,
                    display = player.DisplayName,
                    board = board
                })
            end
        end
    end
    table.sort(targets, function(a, b) return a.display < b.display end)
    return targets
end

local function setSelectedTarget(userId)
    selectedTargetId = userId
    if userId then
        local player = Players:GetPlayerByUserId(userId)
        selectedTargetName = player and player.DisplayName or "Unknown"
    else
        selectedTargetName = "None"
    end
end

-- ============================================================
-- CORE STATE & IMPLEMENTASI FITUR
-- ============================================================

-- State variables
_G.autoDigActive = false
_G.autoCleanActive = false
_G.autoPolishActive = false
_G.autoCollectActive = false
_G.autoSellActive = false
_G.autoAppraiseActive = false
_G.autoClaimActive = false
_G.autoDeleteSpotActive = false
_G.autoBuyActive = false
_G.autoEquipActive = false
_G.autoPolishCollectActive = false
_G.autoPolisherUpgradeActive = false
_G.autoPolisherUnlockActive = false
_G.antiAFKActive = true
_G.digMode = "Normal"
_G.digTargetMode = "Nearest"
_G.cleanTargetMode = "Nearest"
_G.sellRarityFilter = "common"
_G.sellTargetMode = "All"
_G.sellOnlyNonFavorited = true
_G.appraiseRarityFilter = "common"
_G.buyPriority = "Shovel"
_G.buyMode = "Best"
_G.buyThreshold = 1000
_G.equipPriority = "Power"
_G.detectorType = "Auto"
_G.espTargetMode = "All"
_G.espDistance = 500
_G.selectedIsland = "Starter Island"
_G.claimType = "All"
_G.espActive = false
_G.detectorESPActive = false

-- ============================================================
-- IMPLEMENTASI FUNGSI
-- ============================================================

-- --- Auto Dig ---
function _G.toggleAutoDig(enabled)
    _G.autoDigActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoDigActive do
                local busy = false
                if DigController and DigController.isBusyDigging then
                    busy = safeCall(DigController.isBusyDigging, DigController) or false
                end
                if not busy and DigController and DigController.requestSession then
                    safeCall(DigController.requestSession, DigController)
                end
                local waitTime = (_G.digMode == "Fast") and 0.3 or 0.8
                task.wait(waitTime)
            end
        end)
    end
    notify("Auto Dig", enabled and "ON" or "OFF", 2)
end

-- --- Auto Clean ---
function _G.toggleAutoClean(enabled)
    _G.autoCleanActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoCleanActive do
                local cleaning = false
                if WorkbenchController and WorkbenchController.isCleaning then
                    cleaning = safeCall(WorkbenchController.isCleaning, WorkbenchController) or false
                end
                if not cleaning and WorkbenchController and WorkbenchController.onTriggered then
                    safeCall(WorkbenchController.onTriggered, WorkbenchController)
                end
                task.wait(1.5)
            end
        end)
    end
    notify("Auto Clean", enabled and "ON" or "OFF", 2)
end

-- --- Auto Sell ---
function _G.toggleAutoSell(enabled)
    _G.autoSellActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoSellActive do
                if SellFunctions and SellFunctions.sellInventory then
                    safeCall(SellFunctions.sellInventory.invoke, SellFunctions.sellInventory)
                end
                task.wait(8)
            end
        end)
    end
    notify("Auto Sell", enabled and "ON" or "OFF", 2)
end

-- --- Auto Polish ---
function _G.toggleAutoPolish(enabled)
    _G.autoPolishActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoPolishActive do
                local root = getRoot()
                if root then
                    local best = nil
                    local bestDist = math.huge
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("Model") and obj:GetAttribute("PolisherSlot") then
                            local cf = safeCall(obj.GetPivot, obj)
                            if cf then
                                local dist = (cf.Position - root.Position).Magnitude
                                if dist < bestDist and dist < 20 then
                                    bestDist = dist
                                    best = obj
                                end
                            end
                        end
                    end
                    if best and PolisherFunctions and PolisherFunctions.startPolish then
                        local slot = best:GetAttribute("PolisherSlot")
                        if slot then
                            safeCall(PolisherFunctions.startPolish.invoke, PolisherFunctions.startPolish, slot)
                        end
                    end
                end
                task.wait(3)
            end
        end)
    end
    notify("Auto Polish", enabled and "ON" or "OFF", 2)
end

-- --- Auto Collect Polish ---
function _G.toggleAutoPolishCollect(enabled)
    _G.autoPolishCollectActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoPolishCollectActive do
                if PolisherFunctions and PolisherFunctions.collectPolish then
                    safeCall(PolisherFunctions.collectPolish.invoke, PolisherFunctions.collectPolish, 1)
                end
                task.wait(5)
            end
        end)
    end
    notify("Auto Collect Polish", enabled and "ON" or "OFF", 2)
end

-- --- Auto Upgrade Polisher ---
function _G.toggleAutoPolisherUpgrade(enabled)
    _G.autoPolisherUpgradeActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoPolisherUpgradeActive do
                if PolisherFunctions and PolisherFunctions.upgradePolisher then
                    safeCall(PolisherFunctions.upgradePolisher.invoke, PolisherFunctions.upgradePolisher, 1)
                end
                task.wait(10)
            end
        end)
    end
    notify("Auto Upgrade Polisher", enabled and "ON" or "OFF", 2)
end

-- --- Auto Unlock Polisher ---
function _G.toggleAutoPolisherUnlock(enabled)
    _G.autoPolisherUnlockActive = enabled
    if enabled then
        task.spawn(function()
            while _G.autoPolisherUnlockActive do
                if PolisherFunctions and PolisherFunctions.unlockPolisher then
                    safeCall(PolisherFunctions.unlockPolisher.invoke, PolisherFunctions.unlockPolisher, 1)
                end
                task.wait(15)
            end
        end)
    end
    notify("Auto Unlock Polisher", enabled and "ON" or "OFF", 2)
end

-- --- Anti AFK ---
function _G.toggleAntiAFK(enabled)
    _G.antiAFKActive = enabled
    if enabled then
        task.spawn(function()
            while _G.antiAFKActive do
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
    notify("Anti AFK", enabled and "ON" or "OFF", 2)
end

-- --- ESP ---
function _G.toggleESP(enabled)
    _G.espActive = enabled
    if enabled then
        -- Implementasi sederhana: buat marker di setiap dig spot
        local function createMarker(pos)
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.5, 0.1, 0.5)
            part.Position = pos + Vector3.new(0, 0.1, 0)
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.3
            part.BrickColor = BrickColor.Green()
            part.Parent = Workspace
            return part
        end
        task.spawn(function()
            while _G.espActive do
                -- Hapus marker lama
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Part") and obj.Name == "ESPMarker" then
                        obj:Destroy()
                    end
                end
                -- Buat marker baru di spot dig
                local zone = Workspace:FindFirstChild("DigZones")
                if zone then
                    for _, part in ipairs(zone:GetChildren()) do
                        if part:IsA("BasePart") and part:GetAttribute("IsDigSpot") then
                            createMarker(part.Position).Name = "ESPMarker"
                        end
                    end
                end
                task.wait(1)
            end
        end)
    else
        -- Hapus semua marker
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Part") and obj.Name == "ESPMarker" then
                obj:Destroy()
            end
        end
    end
    notify("ESP", enabled and "ON" or "OFF", 2)
end

-- --- Setter mode ---
function _G.setDigMode(mode) _G.digMode = mode end
function _G.setDigTargetMode(mode) _G.digTargetMode = mode end
function _G.setCleanTargetMode(mode) _G.cleanTargetMode = mode end
function _G.setSellRarity(rarity) _G.sellRarityFilter = rarity end
function _G.setSellTargetMode(mode) _G.sellTargetMode = mode end
function _G.setSellOnlyNonFavorited(v) _G.sellOnlyNonFavorited = v end
function _G.setAppraiseRarity(rarity) _G.appraiseRarityFilter = rarity end
function _G.setBuyPriority(p) _G.buyPriority = p end
function _G.setBuyMode(m) _G.buyMode = m end
function _G.setEquipPriority(p) _G.equipPriority = p end
function _G.setESPTargetMode(m) _G.espTargetMode = m end
function _G.setESPDistance(d) _G.espDistance = d end
function _G.setSelectedTarget(id) setSelectedTarget(id) end

-- --- Aksi ---
function _G.teleportToPlot()
    local root = getRoot()
    if not root then notify("Teleport", "Character tidak siap", 3) return end
    local plot = PlotController and PlotController.getPlot and PlotController:getPlot()
    if not plot then notify("Teleport", "Plot tidak ditemukan", 3) return end
    local cf = safeCall(plot.GetPivot, plot)
    if not cf then notify("Teleport", "Posisi plot tidak valid", 3) return end
    root.CFrame = cf * CFrame.new(0, 5, 0)
    notify("Teleport", "Ke plot sendiri", 2)
end

function _G.teleportToTarget()
    if not selectedTargetId then
        notify("Teleport", "Tidak ada target dipilih", 3)
        return
    end
    local board = getTargetBoard(selectedTargetId)
    if not board then
        notify("Teleport", "Board target tidak ditemukan", 3)
        return
    end
    local cf = safeCall(board.GetPivot, board)
    if not cf then return end
    local root = getRoot()
    if not root then return end
    root.CFrame = cf * CFrame.new(0, 5, 0)
    notify("Teleport", "Ke target", 2)
end

function _G.teleportToSeller()
    local root = getRoot()
    if not root then return end
    local seller = Workspace:FindFirstChild("SellerNPC") or Workspace:FindFirstChild("BuyerBob")
    if not seller then
        notify("Teleport", "NPC Seller tidak ditemukan", 3)
        return
    end
    local cf = safeCall(seller.GetPivot, seller)
    if cf then root.CFrame = cf * CFrame.new(0, 2, 3); notify("Teleport", "Ke Seller", 2) end
end

function _G.sellHeldItem()
    if SellFunctions and SellFunctions.sellHeldItem then
        safeCall(SellFunctions.sellHeldItem.invoke, SellFunctions.sellHeldItem)
        notify("Sell", "Menjual item di tangan", 2)
    else
        notify("Sell", "Fungsi tidak tersedia", 2)
    end
end

function _G.sellInventory()
    if SellFunctions and SellFunctions.sellInventory then
        safeCall(SellFunctions.sellInventory.invoke, SellFunctions.sellInventory)
        notify("Sell", "Menjual semua inventory", 2)
    else
        notify("Sell", "Fungsi tidak tersedia", 2)
    end
end

function _G.collectPolish()
    if PolisherFunctions and PolisherFunctions.collectPolish then
        safeCall(PolisherFunctions.collectPolish.invoke, PolisherFunctions.collectPolish, 1)
        notify("Polish", "Mengambil hasil polisher", 2)
    else
        notify("Polish", "Fungsi tidak tersedia", 2)
    end
end

function _G.startPolish()
    local root = getRoot()
    if not root then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("PolisherSlot") then
            local cf = safeCall(obj.GetPivot, obj)
            if cf and (cf.Position - root.Position).Magnitude < 20 then
                local slot = obj:GetAttribute("PolisherSlot")
                if slot and PolisherFunctions and PolisherFunctions.startPolish then
                    safeCall(PolisherFunctions.startPolish.invoke, PolisherFunctions.startPolish, slot)
                    notify("Polish", "Memulai polish", 2)
                end
                break
            end
        end
    end
end

function _G.upgradePolisher()
    if PolisherFunctions and PolisherFunctions.upgradePolisher then
        safeCall(PolisherFunctions.upgradePolisher.invoke, PolisherFunctions.upgradePolisher, 1)
        notify("Polish", "Upgrade polisher", 2)
    else
        notify("Polish", "Fungsi tidak tersedia", 2)
    end
end

function _G.unlockPolisher()
    if PolisherFunctions and PolisherFunctions.unlockPolisher then
        safeCall(PolisherFunctions.unlockPolisher.invoke, PolisherFunctions.unlockPolisher, 1)
        notify("Polish", "Unlock polisher", 2)
    else
        notify("Polish", "Fungsi tidak tersedia", 2)
    end
end

function _G.showInfo()
    local gold = getGold()
    local luck = getLuck()
    local island = getCurrentIsland()
    local inv = getInventoryData()
    notify("Info", string.format("Gold: %d | Luck: %.1fx | Island: %s | Items: %d | Target: %s",
        gold, luck, island, #inv, selectedTargetName), 5)
end

-- ============================================================
-- UI EXTENDED (diadaptasi dari versi sebelumnya)
-- ============================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "DigClean_FULL"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 999
Gui.Parent = PlayerGui

local Camera = workspace.CurrentCamera
local viewport = Camera and Camera.ViewportSize or Vector2.new(800, 600)

local function getSize()
    local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or viewport
    local portrait = v.Y > v.X
    local w = portrait and math.clamp(math.floor(v.X * 0.84), 285, 370)
        or math.clamp(math.floor(v.X * 0.38), 300, 390)
    local h = portrait and math.clamp(math.floor(v.Y * 0.72), 390, 590)
        or math.clamp(math.floor(v.Y * 0.76), 400, 620)
    return w, h
end

local guiW, guiH = getSize()

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.fromOffset(guiW, guiH)
Window.Position = UDim2.new(0.5, -guiW/2, 0.5, -guiH/2)
Window.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = false
Window.Parent = Gui

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 7)
    c.Parent = obj
end

local function stroke(obj, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(70, 72, 82)
    s.Thickness = 1
    s.Transparency = transparency or 0.35
    s.Parent = obj
end

corner(Window, 10)
stroke(Window, 0.15)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window
corner(Header, 10)

local HeaderFill = Instance.new("Frame")
HeaderFill.Size = UDim2.new(1, 0, 0, 10)
HeaderFill.Position = UDim2.new(0, 0, 1, -10)
HeaderFill.BackgroundColor3 = Header.BackgroundColor3
HeaderFill.BorderSizePixel = 0
HeaderFill.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -95, 0, 20)
Title.Position = UDim2.fromOffset(12, 5)
Title.BackgroundTransparency = 1
Title.Text = "DIG&CLEAN"
Title.TextColor3 = Color3.fromRGB(245, 246, 249)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -95, 0, 12)
Subtitle.Position = UDim2.fromOffset(12, 27)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "FULL TOOLS"
Subtitle.TextColor3 = Color3.fromRGB(123, 126, 137)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 7
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(30, 30)
Close.Position = UDim2.new(1, -37, 0, 8)
Close.BackgroundColor3 = Color3.fromRGB(45, 46, 53)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(215, 217, 224)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header
corner(Close, 7)

-- ============================================================
-- TAB BAR
-- ============================================================

local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(1, -12, 0, 39)
TabBar.Position = UDim2.fromOffset(6, 50)
TabBar.BackgroundColor3 = Color3.fromRGB(29, 30, 35)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new()
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Active = true
TabBar.Parent = Window
corner(TabBar, 7)

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 4)
tabPad.PaddingRight = UDim.new(0, 4)
tabPad.PaddingTop = UDim.new(0, 5)
tabPad.Parent = TabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = TabBar

-- ============================================================
-- PAGE HOLDER
-- ============================================================

local PageHolder = Instance.new("Frame")
PageHolder.Size = UDim2.new(1, -12, 1, -96)
PageHolder.Position = UDim2.fromOffset(6, 93)
PageHolder.BackgroundTransparency = 1
PageHolder.ClipsDescendants = true
PageHolder.Parent = Window

local Pages = {}
local Tabs = {}
local CurrentTab = nil

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageTransparency = 0.2
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollingEnabled = true
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Active = true
    page.Parent = PageHolder

    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 3)
    p.PaddingRight = UDim.new(0, 3)
    p.PaddingBottom = UDim.new(0, 14)
    p.Parent = page

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 5)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = page

    Pages[name] = page
    return page
end

local function makeTab(name, icon, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.fromOffset(78, 28)
    btn.BackgroundColor3 = Color3.fromRGB(43, 44, 51)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = icon .. "  " .. name
    btn.TextColor3 = Color3.fromRGB(164, 166, 175)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 7
    btn.LayoutOrder = order
    btn.Parent = TabBar
    corner(btn, 6)
    Tabs[name] = btn
    return btn
end

local function selectTab(name)
    CurrentTab = name
    for n, p in pairs(Pages) do
        p.Visible = n == name
    end
    for n, b in pairs(Tabs) do
        local active = n == name
        b.BackgroundColor3 = active and Color3.fromRGB(72, 74, 84) or Color3.fromRGB(43, 44, 51)
        b.TextColor3 = active and Color3.fromRGB(245, 246, 249) or Color3.fromRGB(164, 166, 175)
    end
end

-- ============================================================
-- OVERLAY POPUP LAYER (untuk dropdown)
-- ============================================================

local PopupLayer = Instance.new("Frame")
PopupLayer.Name = "PopupLayer"
PopupLayer.Size = UDim2.fromScale(1, 1)
PopupLayer.BackgroundTransparency = 1
PopupLayer.BorderSizePixel = 0
PopupLayer.ZIndex = 100
PopupLayer.Parent = Gui

local function closePopups()
    for _, child in ipairs(PopupLayer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- ============================================================
-- UI HELPERS
-- ============================================================

local function section(page, text, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
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
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.LayoutOrder = order
    b.Parent = page
    corner(b, 7)
    stroke(b)

    local i = Instance.new("TextLabel")
    i.Size = UDim2.fromOffset(28, 36)
    i.Position = UDim2.fromOffset(5, 0)
    i.BackgroundTransparency = 1
    i.Text = icon
    i.TextColor3 = Color3.fromRGB(190, 193, 202)
    i.Font = Enum.Font.GothamBold
    i.TextSize = 11
    i.Parent = b

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -40, 1, 0)
    t.Position = UDim2.fromOffset(35, 0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = Color3.fromRGB(226, 228, 235)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 8
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = b

    b.Activated:Connect(callback)
    return b
end

local function toggleRow(page, text, order, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 37)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -82, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226, 228, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(51, 23)
    b.Position = UDim2.new(1, -61, 0.5, -11)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.TextSize = 7
    b.Font = Enum.Font.GothamBold
    b.Parent = row
    corner(b, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(15, 15)
    knob.BorderSizePixel = 0
    knob.Parent = b
    corner(knob, 8)

    local function redraw()
        local enabled = getter()
        b.Text = enabled and "ON" or "OFF"
        b.BackgroundColor3 = enabled and Color3.fromRGB(82, 84, 94) or Color3.fromRGB(45, 45, 48)
        b.TextColor3 = enabled and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(175, 177, 185)
        knob.BackgroundColor3 = enabled and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(165, 165, 170)
        knob.Position = enabled and UDim2.new(1, -19, 0.5, -7) or UDim2.fromOffset(4, 4)
    end

    b.Activated:Connect(function()
        setter(not getter())
        redraw()
    end)

    redraw()
    return row
end

local function dropdownRow(page, text, order, options, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.43, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 222, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.53, -10, 0, 27)
    b.Position = UDim2.new(0.47, 0, 0.5, -13)
    b.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.TextColor3 = Color3.fromRGB(222, 224, 231)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 8
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.Parent = row
    corner(b, 6)

    local function redraw()
        b.Text = tostring(getter())
    end

    local function openPopup()
        closePopups()

        local popup = Instance.new("Frame")
        popup.Name = "DropdownPopup"
        popup.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
        popup.BorderSizePixel = 0
        popup.ZIndex = 110
        popup.Parent = PopupLayer
        corner(popup, 7)
        stroke(popup)

        local abs = b.AbsolutePosition
        local size = b.AbsoluteSize
        local popupWidth = math.max(size.X, 150)
        local popupHeight = math.min(math.max(#options * 31 + 8, 39), 180)

        popup.Size = UDim2.fromOffset(popupWidth, popupHeight)
        popup.Position = UDim2.fromOffset(abs.X, abs.Y + size.Y + 3)

        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -6, 1, -6)
        list.Position = UDim2.fromOffset(3, 3)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 3
        list.ScrollingDirection = Enum.ScrollingDirection.Y
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.CanvasSize = UDim2.new()
        list.Active = true
        list.ZIndex = 111
        list.Parent = popup

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 3)
        layout.Parent = list

        for i, option in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = "  " .. tostring(option)
            item.TextColor3 = Color3.fromRGB(222, 224, 231)
            item.Font = Enum.Font.Gotham
            item.TextSize = 8
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.LayoutOrder = i
            item.ZIndex = 112
            item.Parent = list
            corner(item, 5)

            item.Activated:Connect(function()
                setter(option)
                redraw()
                closePopups()
            end)
        end
    end

    b.Activated:Connect(function()
        if PopupLayer:FindFirstChild("DropdownPopup") then
            closePopups()
        else
            openPopup()
        end
    end)

    redraw()
    return row
end

-- ============================================================
-- PAGES
-- ============================================================

local MainPage = makePage("MAIN")
local TargetPage = makePage("TARGET")
local SellPage = makePage("SELL")
local ESPPage = makePage("ESP")
local GearPage = makePage("GEAR")
local PolishPage = makePage("POLISH")
local TravelPage = makePage("TRAVEL")
local InfoPage = makePage("INFO")
local SettingsPage = makePage("SETTINGS")

local pageDefs = {
    {"MAIN", "◆"},
    {"TARGET", "◎"},
    {"SELL", "$"},
    {"ESP", "◉"},
    {"GEAR", "▣"},
    {"POLISH", "✦"},
    {"TRAVEL", "↗"},
    {"INFO", "i"},
    {"SETTINGS", "⚙"},
}

for i, def in ipairs(pageDefs) do
    local name, icon = def[1], def[2]
    local btn = makeTab(name, icon, i)
    btn.Activated:Connect(function()
        selectTab(name)
    end)
end

-- ============================================================
-- BUILD UI
-- ============================================================

-- MAIN
section(MainPage, "AUTOMATION", 1)
toggleRow(MainPage, "Auto Dig", 2, function() return _G.autoDigActive end, _G.toggleAutoDig)
toggleRow(MainPage, "Auto Clean", 3, function() return _G.autoCleanActive end, _G.toggleAutoClean)
toggleRow(MainPage, "Auto Collect", 4, function() return _G.autoCollectActive end, function(v) _G.autoCollectActive = v end)
toggleRow(MainPage, "Auto Polish", 5, function() return _G.autoPolishActive end, _G.toggleAutoPolish)
dropdownRow(MainPage, "Dig Speed", 6, {"Normal", "Fast"}, function() return _G.digMode end, _G.setDigMode)
dropdownRow(MainPage, "Dig Target", 7, {"Nearest", "Target", "All"}, function() return _G.digTargetMode end, _G.setDigTargetMode)
dropdownRow(MainPage, "Clean Target", 8, {"Nearest", "Target"}, function() return _G.cleanTargetMode end, _G.setCleanTargetMode)

section(MainPage, "ITEM", 10)
toggleRow(MainPage, "Auto Appraise", 11, function() return _G.autoAppraiseActive end, function(v) _G.autoAppraiseActive = v end)
dropdownRow(MainPage, "Appraise Rarity", 12, {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"}, function() return _G.appraiseRarityFilter end, _G.setAppraiseRarity)
toggleRow(MainPage, "Auto Claim", 13, function() return _G.autoClaimActive end, function(v) _G.autoClaimActive = v end)
dropdownRow(MainPage, "Claim Type", 14, {"All", "Quest", "Journal", "Daily"}, function() return _G.claimType end, function(v) _G.claimType = v end)
toggleRow(MainPage, "Auto Delete Spot", 15, function() return _G.autoDeleteSpotActive end, function(v) _G.autoDeleteSpotActive = v end)

-- TARGET
section(TargetPage, "SELECT TARGET", 1)
local targetRow = Instance.new("Frame")
targetRow.Size = UDim2.new(1, 0, 0, 40)
targetRow.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
targetRow.BorderSizePixel = 0
targetRow.LayoutOrder = 2
targetRow.Parent = TargetPage
corner(targetRow, 7)
stroke(targetRow)

local targetButton = Instance.new("TextButton")
targetButton.Size = UDim2.new(1, -20, 0, 27)
targetButton.Position = UDim2.fromOffset(10, 6)
targetButton.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
targetButton.BorderSizePixel = 0
targetButton.AutoButtonColor = false
targetButton.TextColor3 = Color3.fromRGB(222, 224, 231)
targetButton.Font = Enum.Font.GothamMedium
targetButton.TextSize = 8
targetButton.TextTruncate = Enum.TextTruncate.AtEnd
targetButton.Text = "Target: " .. selectedTargetName
targetButton.Parent = targetRow
corner(targetButton, 6)

local function refreshTargetButton()
    targetButton.Text = "Target: " .. selectedTargetName
end

local function openTargetPopup()
    closePopups()
    local popup = Instance.new("Frame")
    popup.Name = "TargetPopup"
    popup.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    popup.BorderSizePixel = 0
    popup.ZIndex = 110
    popup.Parent = PopupLayer
    corner(popup, 7)
    stroke(popup)

    local abs = targetButton.AbsolutePosition
    local size = targetButton.AbsoluteSize
    popup.Size = UDim2.fromOffset(size.X, 180)
    popup.Position = UDim2.fromOffset(abs.X, abs.Y + size.Y + 3)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -6, 1, -6)
    list.Position = UDim2.fromOffset(3, 3)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Active = true
    list.ZIndex = 111
    list.Parent = popup

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    local targets = getAvailableTargets()
    if #targets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Text = "No players found"
        empty.TextColor3 = Color3.fromRGB(135, 138, 149)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 8
        empty.ZIndex = 112
        empty.Parent = list
    else
        for _, entry in ipairs(targets) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 29)
            item.BackgroundColor3 = selectedTargetId == entry.userId and Color3.fromRGB(55, 65, 57) or Color3.fromRGB(40, 41, 48)
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = "  " .. entry.display
            item.TextColor3 = Color3.fromRGB(222, 224, 231)
            item.Font = Enum.Font.Gotham
            item.TextSize = 8
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.ZIndex = 112
            item.Parent = list
            corner(item, 5)

            item.Activated:Connect(function()
                setSelectedTarget(entry.userId)
                refreshTargetButton()
                closePopups()
                notify("Target", entry.display .. " selected", 2)
            end)
        end
    end
end

targetButton.Activated:Connect(function()
    if PopupLayer:FindFirstChild("TargetPopup") then
        closePopups()
    else
        openTargetPopup()
    end
end)

section(TargetPage, "TARGET ACTIONS", 4)
action(TargetPage, "Teleport to Target", "↗", 5, _G.teleportToTarget)

-- SELL
section(SellPage, "AUTO SELL", 1)
toggleRow(SellPage, "Auto Sell", 2, function() return _G.autoSellActive end, _G.toggleAutoSell)
dropdownRow(SellPage, "Rarity Filter", 3, {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"}, function() return _G.sellRarityFilter end, _G.setSellRarity)
dropdownRow(SellPage, "Sell Mode", 4, {"All", "Held", "Filtered"}, function() return _G.sellTargetMode end, _G.setSellTargetMode)
toggleRow(SellPage, "Only Non-Favorited", 5, function() return _G.sellOnlyNonFavorited end, function(v) _G.sellOnlyNonFavorited = v end)
action(SellPage, "Sell Held Item", "$", 6, _G.sellHeldItem)
action(SellPage, "Sell Inventory", "$", 7, _G.sellInventory)

-- ESP
section(ESPPage, "DETECTOR", 1)
toggleRow(ESPPage, "Detector ESP", 2, function() return _G.detectorESPActive end, function(v) _G.detectorESPActive = v end)
dropdownRow(ESPPage, "Detector", 3, {"Auto", "Copper", "Iron", "Silver", "Gold", "Diamond", "Emerald", "Ruby", "Aquamarine"}, function() return _G.detectorType end, function(v) _G.detectorType = v end)

section(ESPPage, "BURIED SPOT", 5)
toggleRow(ESPPage, "ESP Dig Spot", 6, function() return _G.espActive end, _G.toggleESP)
dropdownRow(ESPPage, "ESP Mode", 7, {"All", "Nearest", "Target"}, function() return _G.espTargetMode end, _G.setESPTargetMode)
dropdownRow(ESPPage, "Distance", 8, {"100", "250", "500", "1000", "2500"}, function() return tostring(_G.espDistance) end, _G.setESPDistance)

-- GEAR
section(GearPage, "AUTO BUY", 1)
toggleRow(GearPage, "Auto Buy", 2, function() return _G.autoBuyActive end, function(v) _G.autoBuyActive = v end)
dropdownRow(GearPage, "Buy Priority", 3, {"Shovel", "Detector", "Spray"}, function() return _G.buyPriority end, _G.setBuyPriority)
dropdownRow(GearPage, "Buy Mode", 4, {"Best", "Next", "All"}, function() return _G.buyMode end, _G.setBuyMode)

section(GearPage, "AUTO EQUIP", 6)
toggleRow(GearPage, "Auto Equip", 7, function() return _G.autoEquipActive end, function(v) _G.autoEquipActive = v end)
dropdownRow(GearPage, "Equip Priority", 8, {"Power", "Luck", "Speed"}, function() return _G.equipPriority end, _G.setEquipPriority)

-- POLISH
section(PolishPage, "POLISHER", 1)
toggleRow(PolishPage, "Auto Start Polish", 2, function() return _G.autoPolishActive end, _G.toggleAutoPolish)
toggleRow(PolishPage, "Auto Collect Polish", 3, function() return _G.autoPolishCollectActive end, _G.toggleAutoPolishCollect)
toggleRow(PolishPage, "Auto Upgrade Polisher", 4, function() return _G.autoPolisherUpgradeActive end, _G.toggleAutoPolisherUpgrade)
toggleRow(PolishPage, "Auto Unlock Polisher", 5, function() return _G.autoPolisherUnlockActive end, _G.toggleAutoPolisherUnlock)
action(PolishPage, "Start Polish Now", "▶", 6, _G.startPolish)
action(PolishPage, "Collect Polish Now", "↓", 7, _G.collectPolish)
action(PolishPage, "Upgrade Now", "↑", 8, _G.upgradePolisher)
action(PolishPage, "Unlock Now", "🔓", 9, _G.unlockPolisher)

-- TRAVEL
section(TravelPage, "TELEPORT", 1)
action(TravelPage, "Teleport to Plot", "⌂", 2, _G.teleportToPlot)
action(TravelPage, "Teleport to Seller", "$", 3, _G.teleportToSeller)
action(TravelPage, "Teleport Home", "⌂", 4, function() notify("Travel", "Home teleport not implemented", 2) end)
action(TravelPage, "Teleport Hub", "H", 5, function() notify("Travel", "Hub teleport not implemented", 2) end)

-- INFO
section(InfoPage, "GAME INFO", 1)
action(InfoPage, "Show Info", "i", 2, _G.showInfo)

-- SETTINGS
section(SettingsPage, "GENERAL", 1)
toggleRow(SettingsPage, "Anti AFK", 2, function() return _G.antiAFKActive end, _G.toggleAntiAFK)
action(SettingsPage, "Stop All Loops", "■", 3, function()
    _G.toggleAutoDig(false)
    _G.toggleAutoClean(false)
    _G.toggleAutoPolish(false)
    _G.toggleAutoSell(false)
    _G.toggleAutoPolishCollect(false)
    _G.toggleAutoPolisherUpgrade(false)
    _G.toggleAutoPolisherUnlock(false)
    _G.autoBuyActive = false
    _G.autoEquipActive = false
    _G.autoAppraiseActive = false
    _G.autoClaimActive = false
    _G.autoDeleteSpotActive = false
    _G.autoCollectActive = false
    notify("DigClean", "All loops stopped", 2)
end)
action(SettingsPage, "Close Menu", "×", 4, function()
    Window.Visible = false
    OpenButton.Visible = true
    closePopups()
end)

-- ============================================================
-- FLOATING OPEN BUTTON
-- ============================================================

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(94, 31)
OpenButton.Position = UDim2.new(0.5, -47, 0, 10)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "DIG&CLEAN"
OpenButton.TextColor3 = Color3.fromRGB(240, 241, 245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 200
OpenButton.Parent = Gui
corner(OpenButton, 16)
stroke(OpenButton, 0.25)

Close.Activated:Connect(function()
    Window.Visible = false
    OpenButton.Visible = true
    closePopups()
end)

-- ============================================================
-- DRAG SUPPORT
-- ============================================================

local function makeDraggable(handle, object)
    local dragging = false
    local moved = false
    local startInput, startPos, connection

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        moved = false
        startInput = input.Position
        startPos = object.Position
        if connection then connection:Disconnect() end
        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch and move.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = move.Position - startInput
            if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then moved = true end
            object.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if connection then connection:Disconnect(); connection = nil end
            end
        end)
    end)
end

makeDraggable(Header, Window)

do
    local dragging = false
    local moved = false
    local startInput, startPos, connection

    OpenButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        moved = false
        startInput = input.Position
        startPos = OpenButton.Position
        if connection then connection:Disconnect() end
        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch and move.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = move.Position - startInput
            if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then moved = true end
            OpenButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if connection then connection:Disconnect(); connection = nil end
                if not moved then
                    Window.Visible = true
                    OpenButton.Visible = false
                    closePopups()
                end
            end
        end)
    end)
end

-- ============================================================
-- PLAYER LIST MAINTENANCE
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    if selectedTargetId == player.UserId then
        setSelectedTarget(nil)
        refreshTargetButton()
    end
end)

-- ============================================================
-- VIEWPORT RESIZE
-- ============================================================

pcall(function()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local w, h = getSize()
        if not Window.Visible then return end
        Window.Size = UDim2.fromOffset(w, h)
        Window.Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
        closePopups()
    end)
end)

-- ============================================================
-- STARTUP
-- ============================================================

selectTab("MAIN")
notify("DigClean", "Full Tools loaded", 3)
print("DigClean_FULL loaded")