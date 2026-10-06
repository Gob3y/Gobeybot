-- ============================================================
-- ANIME DICE AUTO FARM HUB
-- Fitur: Auto Buy Dice, Auto Collect Cash, Auto Place Best,
-- Auto Level, Auto Sell, Auto Fuse, Auto Roll Grades,
-- Auto Rebirth, Auto Upgrades, Auto Quest, Auto Codes,
-- Server Hop, Disable Cutscene, Auto Tower, Auto Shop,
-- Auto Equip Best, Auto Trait, Auto Grade, Auto Stat
-- Versi standalone - dynamic remote discovery
-- ============================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local TeleportService    = game:GetService("TeleportService")
local Lighting           = game:GetService("Lighting")
local LocalPlayer        = Players.LocalPlayer

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local Remotes = {}
local RemoteFunctions = {}

local function discoverRemotes()
    local folders = {
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage:FindFirstChild("RemoteFunctions"),
        ReplicatedStorage:FindFirstChild("Networking"),
        ReplicatedStorage:FindFirstChild("Packets"),
    }
    for _, folder in ipairs(folders) do
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    Remotes[obj.Name] = obj
                elseif obj:IsA("RemoteFunction") then
                    RemoteFunctions[obj.Name] = obj
                end
            end
        end
    end
    -- Also scan ReplicatedStorage directly
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and not Remotes[obj.Name] then
            Remotes[obj.Name] = obj
        elseif obj:IsA("RemoteFunction") and not RemoteFunctions[obj.Name] then
            RemoteFunctions[obj.Name] = obj
        end
    end
end

discoverRemotes()

local function findRemote(keywords)
    for name, remote in pairs(Remotes) do
        local lower = string.lower(name)
        for _, kw in ipairs(keywords) do
            if string.find(lower, string.lower(kw), 1, true) then
                return remote
            end
        end
    end
    return nil
end

local function findRemoteFunc(keywords)
    for name, remote in pairs(RemoteFunctions) do
        local lower = string.lower(name)
        for _, kw in ipairs(keywords) do
            if string.find(lower, string.lower(kw), 1, true) then
                return remote
            end
        end
    end
    return nil
end

-- ============================================================
-- GUI CONFIG
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimeDiceHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 520, 0, 420)
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.new(0.5, 0, 0.5, 0)
Window.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Parent = ScreenGui
local winCorner = Instance.new("UICorner", Window)
winCorner.CornerRadius = UDim.new(0, 12)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ANIME DICE HUB"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -70, 0.5, -15)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar

-- Minimized bar
local MiniBar = Instance.new("Frame")
MiniBar.Size = UDim2.new(0, 260, 0, 40)
MiniBar.AnchorPoint = Vector2.new(0.5, 0.5)
MiniBar.Position = Window.Position
MiniBar.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
MiniBar.BorderSizePixel = 0
MiniBar.Visible = false
MiniBar.Parent = ScreenGui
local miniCorner = Instance.new("UICorner", MiniBar)
miniCorner.CornerRadius = UDim.new(0, 16)

local MiniTitle = Instance.new("TextLabel")
MiniTitle.Size = UDim2.new(1, -70, 1, 0)
MiniTitle.Position = UDim2.new(0, 16, 0, 0)
MiniTitle.BackgroundTransparency = 1
MiniTitle.Text = "ANIME DICE HUB"
MiniTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniTitle.Font = Enum.Font.GothamBlack
MiniTitle.TextSize = 14
MiniTitle.TextXAlignment = Enum.TextXAlignment.Left
MiniTitle.Parent = MiniBar

local MiniPlus = Instance.new("TextButton")
MiniPlus.Size = UDim2.new(0, 30, 0, 30)
MiniPlus.Position = UDim2.new(1, -36, 0.5, -15)
MiniPlus.BackgroundTransparency = 1
MiniPlus.Text = "+"
MiniPlus.TextColor3 = Color3.fromRGB(200, 200, 200)
MiniPlus.Font = Enum.Font.GothamBold
MiniPlus.TextSize = 18
MiniPlus.Parent = MiniBar

-- Tabs (left sidebar)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(0, 130, 1, -50)
TabBar.Position = UDim2.new(0, 8, 0, 46)
TabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 4
TabBar.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
TabBar.ScrollingDirection = Enum.ScrollingDirection.Y
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabBar.CanvasSize = UDim2.fromOffset(0, 0)
TabBar.ClipsDescendants = true
TabBar.Parent = Window
local tabCorner = Instance.new("UICorner", TabBar)
tabCorner.CornerRadius = UDim.new(0, 8)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 6)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabBar

-- Content area
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -148, 1, -54)
Content.Position = UDim2.new(0, 144, 0, 46)
Content.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
Content.BorderSizePixel = 0
Content.ClipsDescendants = true
Content.Parent = Window
local contentCorner = Instance.new("UICorner", Content)
contentCorner.CornerRadius = UDim.new(0, 8)

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local Tabs = {}
local TabButtons = {}
local currentTab = nil

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = TabBar
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.Visible = false
    page.Parent = Content

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Tabs) do p.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTab = name
    end)

    table.insert(Tabs, page)
    TabButtons[name] = btn
    return page
end

-- ============================================================
-- UI HELPERS
-- ============================================================
local function addSection(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(140, 140, 150)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

local function addLabel(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 36)
    lbl.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
    lbl.BorderSizePixel = 0
    lbl.Text = "  " .. text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = page
    local c = Instance.new("UICorner", lbl)
    c.CornerRadius = UDim.new(0, 8)
    return lbl
end

local function addToggle(page, text, default, callback)
    local value = default and true or false
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 48, 0, 24)
    toggle.Position = UDim2.new(1, -60, 0.5, -12)
    toggle.BackgroundColor3 = value and Color3.fromRGB(0, 190, 90) or Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local tc = Instance.new("UICorner", toggle)
    tc.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = value and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local kc = Instance.new("UICorner", knob)
    kc.CornerRadius = UDim.new(1, 0)

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            value = not value
            toggle.BackgroundColor3 = value and Color3.fromRGB(0, 190, 90) or Color3.fromRGB(60, 60, 60)
            knob.Position = value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            knob.BackgroundColor3 = value and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
            if callback then task.spawn(function() pcall(callback, value) end) end
        end
    end)

    return {Set = function(v) value = v end, Get = function() return value end}
end

local function addButton(page, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = page
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(function() pcall(callback) end) end
    end)
    return btn
end

local function addSlider(page, text, min, max, default, callback)
    min = min or 0
    max = max or 100
    default = default or min
    local value = math.clamp(default, min, max)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -12, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, -12, 0, 20)
    valLbl.Position = UDim2.new(0.6, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(value)
    valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, -24, 0, 10)
    bar.Position = UDim2.new(0, 12, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.Parent = frame
    local bc = Instance.new("UICorner", bar)
    bc.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner", fill)
    fc.CornerRadius = UDim.new(1, 0)

    local dragging = false

    local function setFromX(x)
        local absX = bar.AbsolutePosition.X
        local width = math.max(1, bar.AbsoluteSize.X)
        local pct = math.clamp((x - absX) / width, 0, 1)
        value = math.floor(min + (max - min) * pct + 0.5)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLbl.Text = tostring(value)
        if callback then task.spawn(function() pcall(callback, value) end) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    return {Set = function(v) value = math.clamp(v, min, max); fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0); valLbl.Text = tostring(value) end, Get = function() return value end}
end

-- ============================================================
-- NOTIFICATION
-- ============================================================
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "Anime Dice Hub"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 3
        })
    end)
end

-- ============================================================
-- GAME DATA HELPERS
-- ============================================================
local function getPlot()
    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("PlotFolder")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.UserId or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

local function getCash()
    -- Try leaderstats first
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if string.find(string.lower(v.Name), "cash") or string.find(string.lower(v.Name), "money") then
                return tonumber(v.Value) or 0
            end
        end
    end
    -- Try attributes
    for _, attr in ipairs({"Cash", "Money", "Coins"}) do
        local v = LocalPlayer:GetAttribute(attr)
        if v then return tonumber(v) or 0 end
    end
    return 0
end

local function getUnits()
    local out = {}
    local plot = getPlot()
    if not plot then return out end
    local unitsFolder = plot:FindFirstChild("Units") or plot:FindFirstChild("PlacedUnits") or plot
    for _, u in ipairs(unitsFolder:GetChildren()) do
        if u:IsA("Model") or u:IsA("Folder") then
            local name = u:GetAttribute("UnitName") or u:GetAttribute("Name") or u.Name
            local power = tonumber(u:GetAttribute("Power")) or tonumber(u:GetAttribute("Damage")) or 0
            table.insert(out, {model = u, name = name, power = power})
        end
    end
    table.sort(out, function(a, b) return a.power > b.power end)
    return out
end

-- ============================================================
-- FEATURE FUNCTIONS
-- ============================================================

-- 1. Auto Buy Dice
local function autoBuyDice()
    local remote = findRemote({"BuyDice", "PurchaseDice", "BuyBestDice", "DiceBuy"})
    if remote then
        remote:FireServer()
        return true
    end
    -- Fallback: find GUI button
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetDescendants()) do
            if gui:IsA("TextButton") and (string.find(string.lower(gui.Text or ""), "buy") or string.find(string.lower(gui.Name or ""), "buy")) and string.find(string.lower(gui.Name or ""), "dice") then
                gui:Activate()
                return true
            end
        end
    end
    return false
end

-- 2. Auto Collect Cash
local function autoCollectCash()
    local remote = findRemote({"Collect", "ClaimCash", "CollectCash", "CollectMoney"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 3. Auto Place Best Units
local function autoPlaceBest()
    local remote = findRemote({"Place", "EquipUnit", "PlaceUnit", "EquipBest"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 4. Auto Level Units
local function autoLevelUnits()
    local remote = findRemote({"LevelUp", "UpgradeUnit", "LevelUnit"})
    if remote then
        for _, unit in ipairs(getUnits()) do
            remote:FireServer(unit.model)
            task.wait(0.1)
        end
        return true
    end
    return false
end

-- 5. Auto Sell Units
local function autoSellUnits()
    local remote = findRemote({"Sell", "SellUnit", "SellUnits"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 6. Auto Fuse Units
local function autoFuseUnits()
    local remote = findRemote({"Fuse", "FuseUnit", "FuseUnits", "Merge"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 7. Auto Roll Grades
local function autoRollGrades()
    local remote = findRemote({"RollGrade", "Grade", "RerollGrade"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 8. Auto Rebirth
local function autoRebirth()
    local remote = findRemote({"Rebirth", "Prestige"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 9. Auto Buy Upgrades
local function autoBuyUpgrades()
    local remote = findRemote({"BuyUpgrade", "PurchaseUpgrade", "Upgrade"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 10. Auto Claim Quests
local function autoClaimQuests()
    local remote = findRemote({"ClaimQuest", "QuestClaim", "ClaimDaily", "DailyReward"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 11. Auto Redeem Codes
local function autoRedeemCodes(codes)
    local remote = findRemote({"Redeem", "RedeemCode", "Code"})
    if remote then
        for _, code in ipairs(codes) do
            remote:FireServer(code)
            task.wait(0.5)
        end
        return true
    end
    return false
end

-- 12. Server Hop
local function serverHop()
    local servers = {}
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = game:HttpGet(url)
        local data = HttpService:JSONDecode(res)
        for _, server in ipairs(data.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(servers, server.id)
            end
        end
    end)
    if #servers > 0 then
        local chosen = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, LocalPlayer)
    else
        notify("Server Hop", "No servers found", 3)
    end
end

-- 13. Disable Cutscenes
local function disableCutscenes()
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("DepthOfFieldEffect") then
            obj:Destroy()
        end
    end
    pcall(function()
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
    end)
end

-- 14. Auto Tower
local function autoTower()
    local remote = findRemote({"Tower", "StartTower", "FightTower", "Battle"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 15. Auto Shop
local function autoShop()
    local remote = findRemote({"Shop", "BuyItem", "PurchaseItem"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 16. Auto Equip Best
local function autoEquipBest()
    local remote = findRemote({"EquipBest", "AutoEquip", "Equip"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 17. Auto Trait
local function autoTrait()
    local remote = findRemote({"Trait", "RollTrait", "RerollTrait"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 18. Auto Grade
local function autoGrade()
    local remote = findRemote({"Grade", "RollGrade", "UpgradeGrade"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- 19. Auto Stat
local function autoStat()
    local remote = findRemote({"Stat", "UpgradeStat", "SpendStat", "StatPoint"})
    if remote then
        remote:FireServer()
        return true
    end
    return false
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    autoBuyDice = false,
    autoCollectCash = false,
    autoPlaceBest = false,
    autoLevelUnits = false,
    autoSellUnits = false,
    autoFuseUnits = false,
    autoRollGrades = false,
    autoRebirth = false,
    autoBuyUpgrades = false,
    autoClaimQuests = false,
    autoRedeemCodes = false,
    autoTower = false,
    autoShop = false,
    autoEquipBest = false,
    autoTrait = false,
    autoGrade = false,
    autoStat = false,
    disableCutscene = false,
    loopDelay = 1,
}

local CODES = {
    "UPDATE1", "UPDATE2", "UPDATE3", "UPDATE4",
    "100KLIKES", "40KCCU", "30KCCU", "20KCCU",
    "10KCCU", "5KCCU", "RELEASE",
}

-- ============================================================
-- MAIN LOOPS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(S.loopDelay)
        if S.autoBuyDice then pcall(autoBuyDice) end
        if S.autoCollectCash then pcall(autoCollectCash) end
        if S.autoPlaceBest then pcall(autoPlaceBest) end
        if S.autoLevelUnits then pcall(autoLevelUnits) end
        if S.autoSellUnits then pcall(autoSellUnits) end
        if S.autoFuseUnits then pcall(autoFuseUnits) end
        if S.autoRollGrades then pcall(autoRollGrades) end
        if S.autoRebirth then pcall(autoRebirth) end
        if S.autoBuyUpgrades then pcall(autoBuyUpgrades) end
        if S.autoClaimQuests then pcall(autoClaimQuests) end
        if S.autoTower then pcall(autoTower) end
        if S.autoShop then pcall(autoShop) end
        if S.autoEquipBest then pcall(autoEquipBest) end
        if S.autoTrait then pcall(autoTrait) end
        if S.autoGrade then pcall(autoGrade) end
        if S.autoStat then pcall(autoStat) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.disableCutscene then pcall(disableCutscenes) end
    end
end)

-- ============================================================
-- GUI BUILD
-- ============================================================
local tabMain = createTab("MAIN")
local tabAuto = createTab("AUTO")
local tabUnits = createTab("UNITS")
local tabMisc = createTab("MISC")

-- MAIN TAB
addSection(tabMain, "FARM")
addToggle(tabMain, "Auto Collect Cash", S.autoCollectCash, function(v) S.autoCollectCash = v end)
addToggle(tabMain, "Auto Buy Dice", S.autoBuyDice, function(v) S.autoBuyDice = v end)
addToggle(tabMain, "Auto Rebirth", S.autoRebirth, function(v) S.autoRebirth = v end)
addToggle(tabMain, "Auto Buy Upgrades", S.autoBuyUpgrades, function(v) S.autoBuyUpgrades = v end)
addSlider(tabMain, "Loop Delay (s)", 0.2, 5, 1, function(v) S.loopDelay = v end)

-- AUTO TAB
addSection(tabAuto, "UNITS")
addToggle(tabAuto, "Auto Place Best Units", S.autoPlaceBest, function(v) S.autoPlaceBest = v end)
addToggle(tabAuto, "Auto Equip Best", S.autoEquipBest, function(v) S.autoEquipBest = v end)
addToggle(tabAuto, "Auto Level Units", S.autoLevelUnits, function(v) S.autoLevelUnits = v end)
addToggle(tabAuto, "Auto Sell Units", S.autoSellUnits, function(v) S.autoSellUnits = v end)
addToggle(tabAuto, "Auto Fuse Units", S.autoFuseUnits, function(v) S.autoFuseUnits = v end)

addSection(tabAuto, "GRADE & TRAIT")
addToggle(tabAuto, "Auto Roll Grades", S.autoRollGrades, function(v) S.autoRollGrades = v end)
addToggle(tabAuto, "Auto Trait", S.autoTrait, function(v) S.autoTrait = v end)
addToggle(tabAuto, "Auto Grade", S.autoGrade, function(v) S.autoGrade = v end)
addToggle(tabAuto, "Auto Stat", S.autoStat, function(v) S.autoStat = v end)

addSection(tabAuto, "TOWER & SHOP")
addToggle(tabAuto, "Auto Tower", S.autoTower, function(v) S.autoTower = v end)
addToggle(tabAuto, "Auto Shop", S.autoShop, function(v) S.autoShop = v end)

-- UNITS TAB
addSection(tabUnits, "MANUAL ACTIONS")
addButton(tabUnits, "Place Best Now", function() autoPlaceBest() end)
addButton(tabUnits, "Equip Best Now", function() autoEquipBest() end)
addButton(tabUnits, "Level Units Now", function() autoLevelUnits() end)
addButton(tabUnits, "Sell Units Now", function() autoSellUnits() end)
addButton(tabUnits, "Fuse Units Now", function() autoFuseUnits() end)
addButton(tabUnits, "Roll Grades Now", function() autoRollGrades() end)
addButton(tabUnits, "Roll Trait Now", function() autoTrait() end)
addButton(tabUnits, "Roll Grade Now", function() autoGrade() end)
addButton(tabUnits, "Spend Stat Now", function() autoStat() end)

-- MISC TAB
addSection(tabMisc, "QUEST & CODES")
addToggle(tabMisc, "Auto Claim Quests", S.autoClaimQuests, function(v) S.autoClaimQuests = v end)
addToggle(tabMisc, "Auto Redeem Codes", S.autoRedeemCodes, function(v)
    S.autoRedeemCodes = v
    if v then autoRedeemCodes(CODES) end
end)
addButton(tabMisc, "Redeem Codes Now", function() autoRedeemCodes(CODES) end)

addSection(tabMisc, "UTILITY")
addToggle(tabMisc, "Disable Cutscene", S.disableCutscene, function(v) S.disableCutscene = v end)
addButton(tabMisc, "Server Hop", function() serverHop() end)
addButton(tabMisc, "Re-scan Remotes", function()
    Remotes = {}
    RemoteFunctions = {}
    discoverRemotes()
    notify("Remotes", tostring(#Remotes + #RemoteFunctions) .. " remotes found", 3)
end)
addButton(tabMisc, "Unload Hub", function()
    ScreenGui:Destroy()
end)

-- ============================================================
-- WINDOW CONTROLS
-- ============================================================
local minimized = false

local function setMinimized(v)
    minimized = v
    Window.Visible = not v
    MiniBar.Visible = v
    MiniBar.Position = Window.Position
end

MinBtn.MouseButton1Click:Connect(function() setMinimized(true) end)
MiniPlus.MouseButton1Click:Connect(function() setMinimized(false) end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Drag main window
do
    local dragging = false
    local dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Drag mini bar
do
    local dragging = false
    local dragStart, startPos
    MiniBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MiniBar.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MiniBar.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Default tab
if #Tabs > 0 then
    Tabs[1].Visible = true
    TabButtons["MAIN"].BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    TabButtons["MAIN"].TextColor3 = Color3.fromRGB(255, 255, 255)
end

-- ============================================================
-- INIT
-- ============================================================
notify("Anime Dice Hub", "Loaded! " .. tostring(#Remotes) .. " remotes found.", 4)
print("[Anime Dice Hub] Loaded with " .. tostring(#Remotes) .. " remotes and " .. tostring(#RemoteFunctions) .. " remote functions.")