-- ============================================================
-- DIG & CLEAN - HAIMIYACH UI STYLE
-- Full feature executor with HAIMIYACH UI
-- Based on the Sudoku UI pattern
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

math.randomseed(os.time())

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
-- CLEAN OLD INSTANCE
-- ============================================================
pcall(function()
    local old = PlayerGui:FindFirstChild("DigCleanHAIMIYACH")
    if old then old:Destroy() end
end)

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
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
            if pos then table.insert(zones, {Position = pos.Position, IsSurfaced = true, Model = obj}) end
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

local function getPlacedBoards()
    return Workspace:FindFirstChild("PlacedBoards")
end

local function getPlayerName(userId)
    local p = Players:GetPlayerByUserId(userId)
    return p and p.DisplayName or "Unknown"
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
    }
    for _, path in ipairs(paths) do
        local obj = ReplicatedStorage
        for _, part in ipairs(path) do
            obj = obj and obj:FindFirstChild(part)
            if not obj then break
        end
        if obj and obj:IsA("RemoteEvent") then return obj end
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
-- CORE STATE
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
    DigMode = "Normal",
    SellRarity = "common",
    SellMode = "All",
    BuyPriority = "Shovel",
    ClaimType = "All",
    SelectedTarget = nil,
    SelectedTargetName = "None",
}

-- ============================================================
-- IMPLEMENTASI FITUR
-- ============================================================

-- AUTO DIG
local function performDig()
    local root = getRoot()
    if not root then return false end

    -- Auto teleport ke spot terdekat
    local spot = getNearestDigSpot()
    if spot then
        local pos = spot.Position or (spot:IsA("BasePart") and spot.Position)
        if pos and (pos - root.Position).Magnitude > 5 then
            root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
            task.wait(0.15)
        end
    end

    -- Remote event
    if remotes.Dig then
        pcall(remotes.Dig.FireServer, remotes.Dig)
        return true
    end

    -- Proximity prompt
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

function toggleAutoDig(enabled)
    State.AutoDig = enabled
    if enabled then
        task.spawn(function()
            while State.AutoDig do
                performDig()
                local wait = State.DigMode == "Fast" and 0.3 or 0.7
                task.wait(wait)
            end
        end)
        notify("Auto Dig ON")
    else
        notify("Auto Dig OFF")
    end
end

-- AUTO CLEAN
function toggleAutoClean(enabled)
    State.AutoClean = enabled
    if enabled then
        task.spawn(function()
            while State.AutoClean do
                if remotes.Clean then
                    pcall(remotes.Clean.FireServer, remotes.Clean)
                else
                    local root = getRoot()
                    if root then
                        for _, obj in ipairs(Workspace:GetDescendants()) do
                            if obj:IsA("Model") and obj.Name == "Workbench" then
                                local cf = pcall(obj.GetPivot, obj) and obj:GetPivot()
                                if cf and (cf.Position - root.Position).Magnitude < 20 then
                                    root.CFrame = cf * CFrame.new(0, 2, 3)
                                    task.wait(0.3)
                                    for _, child in ipairs(obj:GetDescendants()) do
                                        if child:IsA("ProximityPrompt") and child.Enabled then
                                            pcall(child.InputHoldBegin, child)
                                            task.wait(0.5)
                                            pcall(child.InputHoldEnd, child)
                                            break
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                task.wait(1.5)
            end
        end)
        notify("Auto Clean ON")
    else
        notify("Auto Clean OFF")
    end
end

-- AUTO SELL
function toggleAutoSell(enabled)
    State.AutoSell = enabled
    if enabled then
        task.spawn(function()
            while State.AutoSell do
                if remotes.Sell then
                    pcall(remotes.Sell.FireServer, remotes.Sell)
                else
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
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(8)
            end
        end)
        notify("Auto Sell ON")
    else
        notify("Auto Sell OFF")
    end
end

-- AUTO POLISH
function toggleAutoPolish(enabled)
    State.AutoPolish = enabled
    if enabled then
        task.spawn(function()
            while State.AutoPolish do
                if remotes.Polish then
                    pcall(remotes.Polish.FireServer, remotes.Polish)
                else
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
                                            break
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                task.wait(3)
            end
        end)
        notify("Auto Polish ON")
    else
        notify("Auto Polish OFF")
    end
end

-- AUTO COLLECT
function toggleAutoCollect(enabled)
    State.AutoCollect = enabled
    if enabled then
        task.spawn(function()
            while State.AutoCollect do
                if remotes.Collect then
                    pcall(remotes.Collect.FireServer, remotes.Collect)
                else
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
                                            break
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                task.wait(1)
            end
        end)
        notify("Auto Collect ON")
    else
        notify("Auto Collect OFF")
    end
end

-- AUTO BUY
function toggleAutoBuy(enabled)
    State.AutoBuy = enabled
    if enabled then
        task.spawn(function()
            while State.AutoBuy do
                if remotes.Buy then
                    pcall(remotes.Buy.FireServer, remotes.Buy)
                else
                    -- Cari UI Shop
                    local main = PlayerGui:FindFirstChild("Main")
                    if main then
                        local shop = main:FindFirstChild("Shop")
                        if shop then
                            local buy = shop:FindFirstChild("BuyButton")
                            if buy and buy:IsA("TextButton") then
                                pcall(buy.Activated.Invoke, buy)
                            end
                        end
                    end
                end
                task.wait(10)
            end
        end)
        notify("Auto Buy ON")
    else
        notify("Auto Buy OFF")
    end
end

-- AUTO EQUIP
function toggleAutoEquip(enabled)
    State.AutoEquip = enabled
    if enabled then
        task.spawn(function()
            while State.AutoEquip do
                if remotes.Equip then
                    pcall(remotes.Equip.FireServer, remotes.Equip)
                end
                task.wait(30)
            end
        end)
        notify("Auto Equip ON")
    else
        notify("Auto Equip OFF")
    end
end

-- AUTO APPRAISE
function toggleAutoAppraise(enabled)
    State.AutoAppraise = enabled
    if enabled then
        task.spawn(function()
            while State.AutoAppraise do
                if remotes.Appraise then
                    pcall(remotes.Appraise.FireServer, remotes.Appraise)
                else
                    local main = PlayerGui:FindFirstChild("Main")
                    if main then
                        local appraise = main:FindFirstChild("AppraiseButton")
                        if appraise and appraise:IsA("TextButton") then
                            pcall(appraise.Activated.Invoke, appraise)
                        end
                    end
                end
                task.wait(5)
            end
        end)
        notify("Auto Appraise ON")
    else
        notify("Auto Appraise OFF")
    end
end

-- AUTO CLAIM
function toggleAutoClaim(enabled)
    State.AutoClaim = enabled
    if enabled then
        task.spawn(function()
            while State.AutoClaim do
                if remotes.Claim then
                    pcall(remotes.Claim.FireServer, remotes.Claim)
                else
                    local main = PlayerGui:FindFirstChild("Main")
                    if main then
                        for _, obj in ipairs(main:GetDescendants()) do
                            if obj:IsA("TextButton") and string.find(obj.Name or "", "Claim") then
                                pcall(obj.Activated.Invoke, obj)
                            end
                        end
                    end
                end
                task.wait(10)
            end
        end)
        notify("Auto Claim ON")
    else
        notify("Auto Claim OFF")
    end
end

-- AUTO DELETE SPOT
function toggleAutoDeleteSpot(enabled)
    State.AutoDeleteSpot = enabled
    if enabled then
        task.spawn(function()
            while State.AutoDeleteSpot do
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj.Name == "SurfacedItem" then
                        if obj:GetAttribute("Collected") then
                            pcall(obj.Destroy, obj)
                        end
                    end
                end
                task.wait(2)
            end
        end)
        notify("Auto Delete Spot ON")
    else
        notify("Auto Delete Spot OFF")
    end
end

-- ESP
local espMarkers = {}
function toggleESP(enabled)
    State.ESP = enabled
    if enabled then
        task.spawn(function()
            while State.ESP do
                for _, m in ipairs(espMarkers) do pcall(m.Destroy, m) end
                table.clear(espMarkers)
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
                    end
                end
                task.wait(1)
            end
        end)
        notify("ESP ON")
    else
        for _, m in ipairs(espMarkers) do pcall(m.Destroy, m) end
        table.clear(espMarkers)
        notify("ESP OFF")
    end
end

-- ANTI AFK
function toggleAntiAFK(enabled)
    State.AntiAFK = enabled
    if enabled then
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
        notify("Anti AFK ON")
    else
        notify("Anti AFK OFF")
    end
end
toggleAntiAFK(true)

-- TELEPORT
function teleportToPlot()
    local root = getRoot()
    if not root then notify("Character not ready") return end
    local folder = getPlacedBoards()
    if folder then
        for _, board in ipairs(folder:GetChildren()) do
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

function teleportToDig()
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
    local folder = getPlacedBoards()
    if folder then
        for _, board in ipairs(folder:GetChildren()) do
            if board:IsA("Model") then
                local owner = board:GetAttribute("OwnerUserId")
                if owner and tonumber(owner) == State.SelectedTarget then
                    local cf = pcall(board.GetPivot, board) and board:GetPivot()
                    if cf then
                        root.CFrame = cf * CFrame.new(0, 5, 0)
                        notify("Teleported to " .. getPlayerName(State.SelectedTarget))
                        return
                    end
                end
            end
        end
    end
    notify("Target board not found")
end

-- INFO
function showInfo()
    local data = {}
    local gold = 0
    local luck = 1
    local hud = PlayerGui:FindFirstChild("HUD")
    if hud then
        local currency = hud:FindFirstChild("Currency")
        if currency then
            local goldLabel = currency:FindFirstChild("Gold")
            if goldLabel and goldLabel:IsA("TextLabel") then
                gold = tonumber(string.gsub(goldLabel.Text, "[^%d]", "")) or 0
            end
        end
        local luckLabel = hud:FindFirstChild("Luck")
        if luckLabel and luckLabel:IsA("TextLabel") then
            luck = tonumber(string.match(luckLabel.Text, "([%d.]+)")) or 1
        end
    end
    notify(string.format(
        "Gold: %d | Luck: %.1fx | Target: %s\nDig: %s | Clean: %s | Sell: %s | Polish: %s | ESP: %s",
        gold, luck, State.SelectedTargetName,
        State.AutoDig and "ON" or "OFF",
        State.AutoClean and "ON" or "OFF",
        State.AutoSell and "ON" or "OFF",
        State.AutoPolish and "ON" or "OFF",
        State.ESP and "ON" or "OFF"
    ), 5)
end

-- ============================================================
-- UI - HAIMIYACH STYLE (copy dari Sudoku)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DigCleanHAIMIYACH"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local guiWidth = math.clamp(math.floor(viewport.X * 0.38), 220, 260)
local guiHeight = math.clamp(math.floor(viewport.Y * 0.52), 300, 360)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.fromOffset(guiWidth, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui

local wc = Instance.new("UICorner")
wc.CornerRadius = UDim.new(0, 8)
wc.Parent = Window

local ws = Instance.new("UIStroke")
ws.Color = Color3.fromRGB(55, 57, 64)
ws.Thickness = 1
ws.Transparency = 0.2
ws.Parent = Window

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local HeaderBottomFill = Instance.new("Frame")
HeaderBottomFill.Size = UDim2.new(1, 0, 0, 10)
HeaderBottomFill.Position = UDim2.new(0, 0, 1, -10)
HeaderBottomFill.BackgroundColor3 = Header.BackgroundColor3
HeaderBottomFill.BorderSizePixel = 0
HeaderBottomFill.Parent = Header

local Brand = Instance.new("TextLabel")
Brand.Size = UDim2.new(1, -90, 1, 0)
Brand.Position = UDim2.fromOffset(12, 0)
Brand.BackgroundTransparency = 1
Brand.ZIndex = 2
Brand.Text = "DIG&CLEAN"
Brand.TextColor3 = Color3.fromRGB(245, 246, 249)
Brand.Font = Enum.Font.GothamBold
Brand.TextSize = 12
Brand.TextXAlignment = Enum.TextXAlignment.Left
Brand.Parent = Header

local HeaderSub = Instance.new("TextLabel")
HeaderSub.Size = UDim2.new(1, -90, 0, 12)
HeaderSub.Position = UDim2.fromOffset(12, 25)
HeaderSub.BackgroundTransparency = 1
HeaderSub.ZIndex = 2
HeaderSub.Text = "TOOLS"
HeaderSub.TextColor3 = Color3.fromRGB(123, 126, 137)
HeaderSub.Font = Enum.Font.GothamMedium
HeaderSub.TextSize = 6
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.Parent = Header

local OpenButton

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(26, 26)
Close.Position = UDim2.new(1, -33, 0, 7)
Close.BackgroundColor3 = Color3.fromRGB(44, 45, 52)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.ZIndex = 3
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(205, 207, 214)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 7)
cc.Parent = Close

-- Drag
local dragging = false
local dragStart, startPos, dragConnection

local function stopDrag()
    dragging = false
    dragConnection = nil
end

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
        if dragConnection then dragConnection:Disconnect() end
        dragConnection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType == Enum.UserInputType.MouseMovement or move.UserInputType == Enum.UserInputType.Touch then
                local delta = move.Position - dragStart
                Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then stopDrag() end
        end)
    end
end)

Close.Activated:Connect(function()
    Window.Visible = false
    OpenButton.Visible = true
end)

-- Floating reopen
OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(82, 28)
OpenButton.AnchorPoint = Vector2.new(0.5, 0)
OpenButton.Position = UDim2.new(0.5, 0, 0, 7)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BackgroundTransparency = 0.22
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "DIG&CLEAN"
OpenButton.TextColor3 = Color3.fromRGB(240, 241, 245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui

local oc = Instance.new("UICorner")
oc.CornerRadius = UDim.new(0, 16)
oc.Parent = OpenButton

local os = Instance.new("UIStroke")
os.Color = Color3.fromRGB(90, 93, 104)
os.Thickness = 1
os.Transparency = 0.25
os.Parent = OpenButton

-- Floating drag
local floatingDragging = false
local floatingMoved = false
local floatingStartInput, floatingStartPos, floatingDragConnection
local FLOAT_DRAG_THRESHOLD = 8

local function stopFloatingDrag()
    floatingDragging = false
    if floatingDragConnection then floatingDragConnection:Disconnect(); floatingDragConnection = nil end
end

OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    floatingDragging = true
    floatingMoved = false
    floatingStartInput = input.Position
    floatingStartPos = OpenButton.Position
    if floatingDragConnection then floatingDragConnection:Disconnect() end
    floatingDragConnection = UserInputService.InputChanged:Connect(function(move)
        if not floatingDragging then return end
        if move.UserInputType ~= Enum.UserInputType.MouseMovement and move.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = move.Position - floatingStartInput
        if math.abs(delta.X) > FLOAT_DRAG_THRESHOLD or math.abs(delta.Y) > FLOAT_DRAG_THRESHOLD then floatingMoved = true end
        OpenButton.Position = UDim2.new(floatingStartPos.X.Scale, floatingStartPos.X.Offset + delta.X, floatingStartPos.Y.Scale, floatingStartPos.Y.Offset + delta.Y)
    end)
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            local wasMoved = floatingMoved
            stopFloatingDrag()
            if not wasMoved then
                Window.Visible = true
                OpenButton.Visible = false
            end
        end
    end)
end)

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -12, 1, -46)
Content.Position = UDim2.fromOffset(6, 44)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.Active = true
Content.ScrollingEnabled = true
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(90, 93, 104)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new()
Content.Parent = Window

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingLeft = UDim.new(0, 4)
contentPadding.PaddingRight = UDim.new(0, 4)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.Parent = Content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 4)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = Content

-- Helper UI functions (corner, stroke, section, action, toggleRow, dropdownRow)
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

local function section(text, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(112, 115, 127)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 7
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = Content
    return label
end

local function action(text, icon, order, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.LayoutOrder = order
    button.Parent = Content
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

    button.Activated:Connect(callback)
    return button
end

local function toggleRow(text, order, getState, setState)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = Content
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
    toggle.BackgroundColor3 = Color3.fromRGB(58, 59, 67)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = "OFF"
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 7
    toggle.TextColor3 = Color3.fromRGB(175, 177, 185)
    toggle.Parent = row
    corner(toggle, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.fromRGB(168, 170, 178)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    corner(knob, 8)

    local function redraw()
        local enabled = getState()
        toggle.BackgroundColor3 = enabled and Color3.fromRGB(180, 180, 185) or Color3.fromRGB(45, 45, 48)
        toggle.Text = enabled and "ON" or "OFF"
        toggle.TextColor3 = enabled and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(220, 220, 225)
        knob.BackgroundColor3 = enabled and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(165, 165, 170)
        knob.Position = enabled and UDim2.new(1, -18, 0.5, -7) or UDim2.fromOffset(3, 4)
    end

    toggle.Activated:Connect(function()
        setState(not getState())
        redraw()
    end)

    redraw()
    return row, redraw
end

local function dropdownRow(text, order, options, getValue, setValue)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = Content
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.42, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 222, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.54, -10, 0, 24)
    btn.Position = UDim2.new(0.46, 0, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = getValue()
    btn.TextColor3 = Color3.fromRGB(222, 224, 231)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 8
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.Parent = row
    corner(btn, 6)

    -- Dropdown overlay (popup)
    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    listFrame.BorderSizePixel = 0
    listFrame.Visible = false
    listFrame.LayoutOrder = order + 0.5
    listFrame.Parent = Content
    corner(listFrame, 7)
    stroke(listFrame)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listFrame

    local function closeList()
        listFrame.Visible = false
        listFrame.Size = UDim2.new(1, 0, 0, 0)
    end

    for i, opt in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 27)
        item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. opt
        item.TextColor3 = Color3.fromRGB(222, 224, 231)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = i
        item.Parent = listFrame
        corner(item, 5)

        item.Activated:Connect(function()
            setValue(opt)
            btn.Text = opt
            closeList()
        end)
    end

    btn.Activated:Connect(function()
        local visible = not listFrame.Visible
        listFrame.Visible = visible
        listFrame.Size = UDim2.new(1, 0, 0, visible and (#options * 30 + 4) or 0)
    end)

    return row, btn, listFrame
end

-- ============================================================
-- TARGET SELECTOR
-- ============================================================
local targetButton
local targetListFrame
local targetArrow

local function updateTargetText()
    if not State.SelectedTarget then
        targetButton.Text = "Select Player"
        return
    end
    local p = Players:GetPlayerByUserId(State.SelectedTarget)
    if not p then
        targetButton.Text = "Player unavailable"
        return
    end
    local name = p.DisplayName
    if #name > 18 then name = string.sub(name, 1, 17) .. "…" end
    targetButton.Text = name
    State.SelectedTargetName = p.DisplayName
end

local function rebuildTargetList()
    for _, child in ipairs(targetListFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end

    local folder = getPlacedBoards()
    local entries = {}
    if folder then
        for _, board in ipairs(folder:GetChildren()) do
            if board:IsA("Model") then
                local owner = board:GetAttribute("OwnerUserId")
                if owner and tonumber(owner) ~= LocalPlayer.UserId then
                    local p = Players:GetPlayerByUserId(owner)
                    if p then
                        table.insert(entries, {userId = owner, display = p.DisplayName})
                    end
                end
            end
        end
    end
    table.sort(entries, function(a,b) return a.display < b.display end)

    local count = 0
    for _, entry in ipairs(entries) do
        count += 1
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 27)
        item.BackgroundColor3 = entry.userId == State.SelectedTarget and Color3.fromRGB(55,65,57) or Color3.fromRGB(40,41,48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. entry.display
        item.TextColor3 = Color3.fromRGB(220,222,230)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = count
        item.Parent = targetListFrame
        corner(item, 5)

        item.Activated:Connect(function()
            State.SelectedTarget = entry.userId
            State.SelectedTargetName = entry.display
            updateTargetText()
            targetListFrame.Visible = false
            targetListFrame.Size = UDim2.new(1, 0, 0, 0)
            targetArrow.Text = "▾"
            notify("Target: " .. entry.display)
        end)
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -8, 0, 27)
        empty.BackgroundTransparency = 1
        empty.Text = "No other players"
        empty.TextColor3 = Color3.fromRGB(135,138,149)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 8
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Parent = targetListFrame
        count = 1
    end
    targetListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 30 + 4)
end

-- ============================================================
-- BUILD UI CONTENT
-- ============================================================

-- MAIN TAB
section("AUTOMATION", 1)
toggleRow("Auto Dig", 2, function() return State.AutoDig end, toggleAutoDig)
toggleRow("Auto Clean", 3, function() return State.AutoClean end, toggleAutoClean)
toggleRow("Auto Sell", 4, function() return State.AutoSell end, toggleAutoSell)
toggleRow("Auto Polish", 5, function() return State.AutoPolish end, toggleAutoPolish)
toggleRow("Auto Collect", 6, function() return State.AutoCollect end, toggleAutoCollect)

dropdownRow("Dig Speed", 7, {"Normal", "Fast"}, function() return State.DigMode end, function(v) State.DigMode = v; notify("Dig mode: " .. v) end)

section("ITEM", 8)
toggleRow("Auto Appraise", 9, function() return State.AutoAppraise end, toggleAutoAppraise)
toggleRow("Auto Claim", 10, function() return State.AutoClaim end, toggleAutoClaim)
toggleRow("Auto Delete Spot", 11, function() return State.AutoDeleteSpot end, toggleAutoDeleteSpot)

-- TARGET TAB (akan dibuat di bawah)
-- SELL TAB
section("SELL", 1)
toggleRow("Auto Sell", 2, function() return State.AutoSell end, toggleAutoSell)
dropdownRow("Rarity Filter", 3, {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"}, function() return State.SellRarity end, function(v) State.SellRarity = v; notify("Sell rarity: " .. v) end)
dropdownRow("Sell Mode", 4, {"All", "Held", "Filtered"}, function() return State.SellMode end, function(v) State.SellMode = v; notify("Sell mode: " .. v) end)

-- ESP TAB
section("ESP / DETECTOR", 1)
toggleRow("ESP Dig Spot", 2, function() return State.ESP end, toggleESP)

-- GEAR TAB
section("SHOP", 1)
toggleRow("Auto Buy", 2, function() return State.AutoBuy end, toggleAutoBuy)
dropdownRow("Buy Priority", 3, {"Shovel", "Detector", "Spray"}, function() return State.BuyPriority end, function(v) State.BuyPriority = v; notify("Buy priority: " .. v) end)
toggleRow("Auto Equip", 4, function() return State.AutoEquip end, toggleAutoEquip)

-- POLISH TAB
section("POLISHER", 1)
toggleRow("Auto Start Polish", 2, function() return State.AutoPolish end, toggleAutoPolish)

-- TRAVEL TAB
section("TELEPORT", 1)
action("Teleport to Plot", "↗", 2, teleportToPlot)
action("Teleport to Dig", "↗", 3, teleportToDig)
action("Teleport to Seller", "↗", 4, teleportToSeller)
action("Teleport to Target", "↗", 5, teleportToTarget)

-- INFO TAB
section("INFO", 1)
action("Show Info", "ℹ", 2, showInfo)

-- SETTINGS TAB
section("GENERAL", 1)
toggleRow("Anti AFK", 2, function() return State.AntiAFK end, toggleAntiAFK)
action("Stop All Loops", "■", 3, function()
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
end)

-- ============================================================
-- TARGET SELECTOR (ditempelkan di Content setelah section tertentu)
-- ============================================================
-- Kita buat target selector sebagai bagian dari Content, bukan tab terpisah
-- Karena UI Sudoku punya target selector di dalam Content juga.
-- Kita akan masukkan di awal Content.

-- Hapus content yang sudah ada? Tidak, kita sisipkan di awal.
local targetRow = Instance.new("Frame")
targetRow.Size = UDim2.new(1, 0, 0, 42)
targetRow.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
targetRow.BorderSizePixel = 0
targetRow.LayoutOrder = 0
targetRow.Parent = Content
corner(targetRow, 7)
stroke(targetRow)

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(0.34, 0, 1, 0)
targetLabel.Position = UDim2.fromOffset(10, 0)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Target"
targetLabel.TextColor3 = Color3.fromRGB(220, 222, 230)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 9
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = targetRow

targetButton = Instance.new("TextButton")
targetButton.Size = UDim2.new(0.66, -10, 0, 28)
targetButton.Position = UDim2.new(0.34, 0, 0.5, -14)
targetButton.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
targetButton.BorderSizePixel = 0
targetButton.AutoButtonColor = false
targetButton.Text = "Select Player"
targetButton.TextColor3 = Color3.fromRGB(204, 206, 214)
targetButton.Font = Enum.Font.GothamMedium
targetButton.TextSize = 8
targetButton.TextTruncate = Enum.TextTruncate.AtEnd
targetButton.Parent = targetRow
corner(targetButton, 6)

targetArrow = Instance.new("TextLabel")
targetArrow.Size = UDim2.fromOffset(18, 28)
targetArrow.Position = UDim2.new(1, -21, 0, 0)
targetArrow.BackgroundTransparency = 1
targetArrow.Text = "▾"
targetArrow.TextColor3 = Color3.fromRGB(135, 138, 149)
targetArrow.Font = Enum.Font.GothamMedium
targetArrow.TextSize = 8
targetArrow.Parent = targetButton

targetListFrame = Instance.new("ScrollingFrame")
targetListFrame.Name = "TargetDropdown"
targetListFrame.Size = UDim2.new(1, 0, 0, 0)
targetListFrame.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
targetListFrame.BorderSizePixel = 0
targetListFrame.Visible = false
targetListFrame.Active = true
targetListFrame.ScrollingEnabled = true
targetListFrame.ScrollingDirection = Enum.ScrollingDirection.Y
targetListFrame.ScrollBarThickness = 3
targetListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
targetListFrame.CanvasSize = UDim2.new()
targetListFrame.LayoutOrder = 0.5
targetListFrame.Parent = Content
corner(targetListFrame, 7)
stroke(targetListFrame)

local targetListLayout = Instance.new("UIListLayout")
targetListLayout.Padding = UDim.new(0, 3)
targetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetListLayout.Parent = targetListFrame

targetButton.Activated:Connect(function()
    local visible = not targetListFrame.Visible
    targetListFrame.Visible = visible
    targetListFrame.Size = UDim2.new(1, 0, 0, visible and 120 or 0)
    targetArrow.Text = visible and "▴" or "▾"
    if visible then rebuildTargetList() end
end)

Players.PlayerAdded:Connect(function() task.wait(0.3); if targetListFrame.Visible then rebuildTargetList() end end)
Players.PlayerRemoving:Connect(function() task.wait(0.3); if targetListFrame.Visible then rebuildTargetList() end end)

-- ============================================================
-- STARTUP
-- ============================================================
updateTargetText()
notify("DigClean HAIMIYACH UI loaded", 3)
print("DigClean HAIMIYACH UI loaded")