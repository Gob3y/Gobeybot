-- ============================================================
-- RAYFIELD-STYLE GUI ANDROID - MULTI-SELECT TARGET
-- Fitur Auto Sell bisa pilih beberapa rarity sekaligus
-- Fitur Buy Egg bisa pilih satu jenis atau semua
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Ambil modul dan remote
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopData = require(Modules.ShopData)
local EggData = require(Modules.EggData)
local GearData = require(Modules.GearData)
local PlantData = require(Modules.PlantData)

-- Daftar item dari ShopData
local eggItems = ShopData.ShopOrders.EggShop or {}
local gearItems = ShopData.ShopOrders.GearShop or {}
local mutationList = {"Gold", "Rainbow", "Moonlit", "Chilly", "Toasty", "Tranquil", "Shocked", "Glitched"}

-- Daftar rarity dari game
local rarityList = {"Common", "Rare", "Epic", "Legendary", "Mythic", "Divine"}

-- ============================================================
-- KONFIGURASI UI
-- ============================================================
local GUI_WIDTH = 340
local GUI_HEIGHT = 500
local FONT_SIZE = 11
local TAB_HEIGHT = 32
local TOGGLE_HEIGHT = 28
local BUTTON_HEIGHT = 28
local SLIDER_HEIGHT = 40
local DROPDOWN_HEIGHT = 36
local SMALL_TOGGLE_HEIGHT = 26

-- ============================================================
-- BUAT GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RayfieldStyleGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Window
local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
Window.Position = UDim2.new(0.5, -GUI_WIDTH/2, 0.5, -GUI_HEIGHT/2)
Window.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
Window.BorderSizePixel = 0
Window.ClipsDescendants = true
Window.Active = true
Window.Parent = ScreenGui
local winCorner = Instance.new("UICorner", Window)
winCorner.CornerRadius = UDim.new(0, 10)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Auto Farm"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = FONT_SIZE + 2
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = FONT_SIZE
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -12, 0, TAB_HEIGHT)
TabBar.Position = UDim2.new(0, 6, 0, 38)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 27)
TabBar.BorderSizePixel = 0
TabBar.Parent = Window
local tabCorner = Instance.new("UICorner", TabBar)
tabCorner.CornerRadius = UDim.new(0, 8)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.Parent = TabBar

-- Content Area
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -12, 1, -TAB_HEIGHT - 50)
Content.Position = UDim2.new(0, 6, 0, TAB_HEIGHT + 42)
Content.BackgroundTransparency = 1
Content.Parent = Window

-- ============================================================
-- SISTEM TAB
-- ============================================================
local tabs = {}
local tabButtons = {}
local currentTab = nil

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 42)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = FONT_SIZE
    btn.Parent = TabBar
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.Visible = false
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(tabs) do p.Visible = false end
        for _, b in pairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 42)
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        currentTab = name
    end)

    table.insert(tabs, page)
    tabButtons[name] = btn
    return page
end

-- ============================================================
-- FUNGSI UI ELEMEN (Gaya Rayfield)
-- ============================================================

local function addSection(page, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(140, 140, 145)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = page
    return lbl
end

local function addToggle(page, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, TOGGLE_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -74, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -54, 0.5, -11)
    toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local tc = Instance.new("UICorner", toggle)
    tc.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local kc = Instance.new("UICorner", knob)
    kc.CornerRadius = UDim.new(1, 0)

    local value = default
    local function update()
        if value then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 190, 90)
            knob.Position = UDim2.new(1, -20, 0.5, -9)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            knob.Position = UDim2.new(0, 2, 0.5, -9)
            knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
        end
        if callback then callback(value) end
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            value = not value
            update()
        end
    end)

    update()
    return {Set = function(v) value = v; update() end, Get = function() return value end}
end

local function addSmallToggle(page, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, SMALL_TOGGLE_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE - 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 38, 0, 18)
    toggle.Position = UDim2.new(1, -48, 0.5, -9)
    toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local tc = Instance.new("UICorner", toggle)
    tc.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local kc = Instance.new("UICorner", knob)
    kc.CornerRadius = UDim.new(1, 0)

    local value = default
    local function update()
        if value then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 190, 90)
            knob.Position = UDim2.new(1, -16, 0.5, -7)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            knob.Position = UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
        end
        if callback then callback(value) end
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            value = not value
            update()
        end
    end)

    update()
    return {Set = function(v) value = v; update() end, Get = function() return value end}
end

local function addButton(page, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = FONT_SIZE
    btn.Parent = page
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

local function addSlider(page, text, min, max, default, callback)
    min = min or 0
    max = max or 100
    default = default or min
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, SLIDER_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
    frame.BorderSizePixel = 0
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -10, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, -10, 0, 18)
    valLbl.Position = UDim2.new(0.6, 0, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextSize = FONT_SIZE
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 52)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    local bc = Instance.new("UICorner", bar)
    bc.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner", fill)
    fc.CornerRadius = UDim.new(1, 0)

    local value = default
    local dragging = false
    local function update(x)
        local absX = bar.AbsolutePosition.X
        local width = bar.AbsoluteSize.X
        if width <= 0 then return end
        local pct = math.clamp((x - absX) / width, 0, 1)
        value = min + (max - min) * pct
        value = math.floor(value + 0.5)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLbl.Text = tostring(value)
        if callback then callback(value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)

    local pct = (default - min) / (max - min)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    valLbl.Text = tostring(default)

    return {Set = function(v) value = math.clamp(v, min, max); local pct = (value - min) / (max - min); fill.Size = UDim2.new(pct, 0, 1, 0); valLbl.Text = tostring(value); if callback then callback(value) end end, Get = function() return value end}
end

-- DROPDOWN YANG STABIL
local function addDropdown(page, label, options, default, callback)
    options = options or {}
    local current = default or options[1] or ""
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, DROPDOWN_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = false
    frame.Parent = page
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -10, 0, 26)
    btn.Position = UDim2.new(0.45, 0, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 54)
    btn.BorderSizePixel = 0
    btn.Text = current
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = FONT_SIZE
    btn.Parent = frame
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(0.55, -10, 0, 0)
    list.Position = UDim2.new(0.45, 0, 0, DROPDOWN_HEIGHT)
    list.BackgroundColor3 = Color3.fromRGB(35, 35, 38)
    list.BorderSizePixel = 0
    list.Visible = false
    list.ClipsDescendants = true
    list.ScrollBarThickness = 3
    list.ZIndex = 10
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.Parent = frame
    local lc = Instance.new("UICorner", list)
    lc.CornerRadius = UDim.new(0, 6)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local function rebuild()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, -4, 0, 26)
            optBtn.Position = UDim2.new(0, 2, 0, 0)
            optBtn.BackgroundColor3 = (opt == current) and Color3.fromRGB(60, 60, 65) or Color3.fromRGB(40, 40, 44)
            optBtn.BorderSizePixel = 0
            optBtn.Text = opt
            optBtn.TextColor3 = (opt == current) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = FONT_SIZE
            optBtn.Parent = list
            local oc = Instance.new("UICorner", optBtn)
            oc.CornerRadius = UDim.new(0, 4)
            optBtn.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = opt
                list.Visible = false
                list.Size = UDim2.new(0.55, -10, 0, 0)
                if callback then callback(current) end
                rebuild()
            end)
        end
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = math.min(120, listLayout.AbsoluteContentSize.Y + 8)
            list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
            if list.Visible then
                list.Size = UDim2.new(0.55, -10, 0, h)
            end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        if list.Visible then
            local h = math.min(120, listLayout.AbsoluteContentSize.Y + 8)
            list.Size = UDim2.new(0.55, -10, 0, h)
        else
            list.Size = UDim2.new(0.55, -10, 0, 0)
        end
    end)

    rebuild()
    return {Set = function(v) current = v; btn.Text = v; rebuild(); if callback then callback(v) end end, Get = function() return current end}
end

-- ============================================================
-- BUAT TAB
-- ============================================================
local tabAuto = createTab("Auto")
local tabShop = createTab("Shop")
local tabBounty = createTab("Bounty")
local tabGarden = createTab("Garden")
local tabSettings = createTab("Settings")

-- ============================================================
-- VARIABEL STATE
-- ============================================================
local loopInterval = 2
local selectedEgg = eggItems[1] or "Capybara Egg"
local selectedGear = gearItems[1] or "Hatch Hammer"
local selectedMutation = "Moonlit"
local autoStates = {}

-- ============================================================
-- FUNGSI FITUR (RemoteEvents VALID)
-- ============================================================

local function sellAll(type)
    Remotes.Sell:FireServer("bulkSell", type or "Plant")
end

local function collectMoney()
    Remotes.CollectionMachine:FireServer()
end

local function turnInBounty()
    Remotes.TurnInBounty:InvokeServer()
end

local function getBounties()
    Remotes.RequestBounties:InvokeServer()
end

local function buyItem(itemName)
    Remotes.BuyItem:FireServer(itemName)
end

local function fuse(placeType)
    Remotes.FuseAction:InvokeServer("Place", placeType or "Capybara")
end

local function useScroll(mutation)
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
    if tool and tool:GetAttribute("plantID") then
        Remotes.MutationScroll:FireServer(mutation, tool)
    end
end

local function potInteract(plotNumber)
    Remotes.PotInteract:FireServer(plotNumber or 1)
end

local function hatchEgg()
    local PlacedItems = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Map") and Workspace.World.Map:FindFirstChild("PlacedItems")
    if PlacedItems then
        for _, item in ipairs(PlacedItems.Server:GetChildren()) do
            if item:GetAttribute("Owner") == LocalPlayer.UserId then
                local config = item:FindFirstChild("ServerConfiguration")
                if config and config.Type and config.Type.Value == "Egg" then
                    local hatchPct = config:FindFirstChild("HatchPercentage")
                    if hatchPct and hatchPct.Value >= 100 then
                        Remotes.Hatch:FireServer(item.Name)
                        break
                    end
                end
            end
        end
    end
end

local function equipBestPlants()
    Remotes.EquipBestPlants:FireServer()
end

-- ============================================================
-- TAB: AUTO (DENGAN MULTI-SELECT RARITY)
-- ============================================================

-- Fungsi untuk mengirim pengaturan auto sell ke server
local function setAutoSellRarity(rarity, enabled)
    pcall(function()
        Remotes.ChangeAutosellOptions:InvokeServer("AutosellRarity", {
            Rarity = rarity,
            Enabled = enabled
        })
    end)
end

-- Daftar toggle untuk setiap rarity
local rarityToggles = {}
local rarityStates = {}

-- Buat section Auto Sell
addSection(tabAuto, "Auto Sell (Multi-Rarity)")

for _, rarity in ipairs(rarityList) do
    rarityStates[rarity] = false
    local tog = addSmallToggle(tabAuto, rarity, false, function(v)
        rarityStates[rarity] = v
        setAutoSellRarity(rarity, v)
    end)
    rarityToggles[rarity] = tog
end

addSection(tabAuto, "Auto Collect & Garden")

-- Collect Money
autoStates["collect"] = false
addToggle(tabAuto, "Collect Money", false, function(v)
    autoStates["collect"] = v
    if v then
        spawn(function()
            while autoStates["collect"] and wait(loopInterval) do
                pcall(collectMoney)
            end
        end)
    end
end)

-- Auto Pot
autoStates["pot"] = false
addToggle(tabAuto, "Auto Pot Interact", false, function(v)
    autoStates["pot"] = v
    if v then
        spawn(function()
            while autoStates["pot"] and wait(loopInterval * 3) do
                pcall(potInteract, 1)
            end
        end)
    end
end)

-- Auto Hatch
autoStates["hatch"] = false
addToggle(tabAuto, "Auto Hatch Egg", false, function(v)
    autoStates["hatch"] = v
    if v then
        spawn(function()
            while autoStates["hatch"] and wait(loopInterval * 2) do
                pcall(hatchEgg)
            end
        end)
    end
end)

-- Equip Best
autoStates["equip"] = false
addToggle(tabAuto, "Equip Best Plants", false, function(v)
    autoStates["equip"] = v
    if v then
        spawn(function()
            while autoStates["equip"] and wait(loopInterval * 3) do
                pcall(equipBestPlants)
            end
        end)
    end
end)

-- ============================================================
-- TAB: SHOP (DENGAN MULTI-BUY EGG)
-- ============================================================
addSection(tabShop, "Auto Buy")

-- Pilih satu egg untuk dibeli otomatis (jika Buy All Eggs tidak aktif)
local eggDrop = addDropdown(tabShop, "Pilih Egg", eggItems, selectedEgg, function(v)
    selectedEgg = v
end)

-- Toggle "Buy All Eggs" - akan membeli semua egg secara bergantian
autoStates["buyAllEggs"] = false
addToggle(tabShop, "Buy All Eggs (Round-Robin)", false, function(v)
    autoStates["buyAllEggs"] = v
    if v then
        spawn(function()
            local eggList = eggItems
            local index = 1
            while autoStates["buyAllEggs"] and wait(loopInterval * 5) do
                if #eggList > 0 then
                    local eggName = eggList[index]
                    pcall(buyItem, eggName)
                    index = index + 1
                    if index > #eggList then index = 1 end
                end
            end
        end)
    end
end)

-- Jika buy all eggs aktif, dropdown tetap bisa diubah tapi tidak digunakan
-- Tapi kita tetap izinkan user memilih satu egg untuk mode non-all
autoStates["buyEgg"] = false
addToggle(tabShop, "Buy Selected Egg", false, function(v)
    autoStates["buyEgg"] = v
    if v and not autoStates["buyAllEggs"] then
        spawn(function()
            while autoStates["buyEgg"] and not autoStates["buyAllEggs"] and wait(loopInterval * 5) do
                pcall(buyItem, selectedEgg)
            end
        end)
    elseif v and autoStates["buyAllEggs"] then
        -- jika buy all eggs aktif, matikan buy selected egg
        autoStates["buyEgg"] = false
        -- kita perlu set toggle ke off? kita tidak punya referensi, kita gunakan pcall
        pcall(function()
            -- tidak bisa set toggle dari sini, user harus matikan sendiri
        end)
    end
end)

-- Auto Buy Gear
autoStates["buyGear"] = false
addToggle(tabShop, "Buy Selected Gear", false, function(v)
    autoStates["buyGear"] = v
    if v then
        spawn(function()
            while autoStates["buyGear"] and wait(loopInterval * 5) do
                pcall(buyItem, selectedGear)
            end
        end)
    end
end)

addSection(tabShop, "Pilihan Item")
local gearDrop = addDropdown(tabShop, "Pilih Gear", gearItems, selectedGear, function(v)
    selectedGear = v
end)

addSection(tabShop, "Fusion & Mutation")
autoStates["fusion"] = false
addToggle(tabShop, "Auto Fusion (Capybara)", false, function(v)
    autoStates["fusion"] = v
    if v then
        spawn(function()
            while autoStates["fusion"] and wait(loopInterval * 10) do
                pcall(fuse, "Capybara")
            end
        end)
    end
end)

autoStates["scroll"] = false
addToggle(tabShop, "Auto Mutation Scroll", false, function(v)
    autoStates["scroll"] = v
    if v then
        spawn(function()
            while autoStates["scroll"] and wait(loopInterval * 5) do
                pcall(useScroll, selectedMutation)
            end
        end)
    end
end)

local mutDrop = addDropdown(tabShop, "Pilih Mutasi", mutationList, selectedMutation, function(v)
    selectedMutation = v
end)

-- ============================================================
-- TAB: BOUNTY
-- ============================================================
addSection(tabBounty, "Bounty")
autoStates["bounty"] = false
addToggle(tabBounty, "Auto Get Bounties", false, function(v)
    autoStates["bounty"] = v
    if v then
        spawn(function()
            while autoStates["bounty"] and wait(loopInterval * 3) do
                pcall(getBounties)
            end
        end)
    end
end)

autoStates["turnin"] = false
addToggle(tabBounty, "Auto Turn In Bounty", false, function(v)
    autoStates["turnin"] = v
    if v then
        spawn(function()
            while autoStates["turnin"] and wait(loopInterval * 2) do
                pcall(turnInBounty)
            end
        end)
    end
end)

addSection(tabBounty, "Manual")
addButton(tabBounty, "Get Bounties", getBounties)
addButton(tabBounty, "Turn In Bounty", turnInBounty)

-- ============================================================
-- TAB: GARDEN
-- ============================================================
addSection(tabGarden, "Manual Actions")
addButton(tabGarden, "Sell All Plants", function() sellAll("Plant") end)
addButton(tabGarden, "Sell All Capybaras", function() sellAll("Capybara") end)
addButton(tabGarden, "Sell All (Both)", function() sellAll("Plant"); wait(0.2); sellAll("Capybara") end)
addButton(tabGarden, "Collect Money", collectMoney)
addButton(tabGarden, "Hatch Ready Egg", hatchEgg)
addButton(tabGarden, "Equip Best Plants", equipBestPlants)
addButton(tabGarden, "Pot Interact (Plot 1)", function() potInteract(1) end)

-- ============================================================
-- TAB: SETTINGS
-- ============================================================
addSection(tabSettings, "Interval")
local intervalSlider = addSlider(tabSettings, "Loop Interval (s)", 1, 30, loopInterval, function(v)
    loopInterval = v
end)

addSection(tabSettings, "Info")
local infoLbl = Instance.new("TextLabel")
infoLbl.Size = UDim2.new(1, 0, 0, 60)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "Auto Sell: aktifkan rarity yang diinginkan.\nBuy All Eggs: membeli semua egg bergantian."
infoLbl.TextColor3 = Color3.fromRGB(150, 150, 155)
infoLbl.Font = Enum.Font.Gotham
infoLbl.TextSize = FONT_SIZE - 1
infoLbl.TextWrapped = true
infoLbl.Parent = tabSettings

-- ============================================================
-- AKTIFKAN TAB PERTAMA
-- ============================================================
if #tabs > 0 then
    tabs[1].Visible = true
    tabButtons["Auto"].BackgroundColor3 = Color3.fromRGB(70, 70, 75)
    tabButtons["Auto"].TextColor3 = Color3.fromRGB(255, 255, 255)
    currentTab = "Auto"
end

-- ============================================================
-- DRAG WINDOW
-- ============================================================
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

print("Rayfield-style GUI Android siap! Multi-select aktif di Auto Sell dan Buy All Eggs.")