-- ============================================================
-- AUTO FARM GUI ANDROID - VERSI LENGKAP
-- Menggunakan semua RemoteEvents yang valid dari file game
-- Ukuran kecil, font kecil, responsif sentuhan
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Ambil semua modul dan remote
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ShopData = require(Modules.ShopData)
local EggData = require(Modules.EggData)
local GearData = require(Modules.GearData)
local PlantData = require(Modules.PlantData)

-- Daftar item dari ShopData
local eggItems = ShopData.ShopOrders.EggShop or {}
local gearItems = ShopData.ShopOrders.GearShop or {}
local plantNames = PlantData.getIndexList and PlantData.getIndexList() or {}

-- ===== KONFIGURASI UI =====
local GUI_WIDTH = 310
local GUI_HEIGHT = 440
local FONT_SIZE = 11
local TOGGLE_HEIGHT = 28
local BUTTON_HEIGHT = 28
local SLIDER_HEIGHT = 38
local DROPDOWN_HEIGHT = 34

-- ===== BUAT GUI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
MainFrame.Position = UDim2.new(0.5, -GUI_WIDTH/2, 0.5, -GUI_HEIGHT/2)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
local corner = Instance.new("UICorner", MainFrame)
corner.CornerRadius = UDim.new(0, 8)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
local titleCorner = Instance.new("UICorner", TitleBar)
titleCorner.CornerRadius = UDim.new(0, 8)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Auto Farm"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = FONT_SIZE + 2
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = FONT_SIZE
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Scroll Frame
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -10, 1, -40)
ScrollFrame.Position = UDim2.new(0, 5, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
ScrollFrame.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 4)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = ScrollFrame
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollFrame.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 10)
end)

-- ===== FUNGSI UI =====

local function addToggle(text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, TOGGLE_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = ScrollFrame
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(1, -48, 0.5, -10)
    toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggle.BorderSizePixel = 0
    toggle.Parent = frame
    local tc = Instance.new("UICorner", toggle)
    tc.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    local kc = Instance.new("UICorner", knob)
    kc.CornerRadius = UDim.new(1, 0)

    local value = default
    local function update()
        if value then
            toggle.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
            knob.Position = UDim2.new(1, -18, 0.5, -8)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            knob.Position = UDim2.new(0, 2, 0.5, -8)
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

local function addButton(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = FONT_SIZE
    btn.Parent = ScrollFrame
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

local function addLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE - 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = ScrollFrame
    return lbl
end

local function addSlider(text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, SLIDER_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = ScrollFrame
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, -10, 0, 20)
    lbl.Position = UDim2.new(0, 8, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, -10, 0, 20)
    valLbl.Position = UDim2.new(0.6, 0, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLbl.Font = Enum.Font.Gotham
    valLbl.TextSize = FONT_SIZE
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 6)
    bar.Position = UDim2.new(0, 8, 0, 28)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
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

local function addDropdown(text, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, DROPDOWN_HEIGHT)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = ScrollFrame
    local c = Instance.new("UICorner", frame)
    c.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, -10, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = FONT_SIZE
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, -10, 0, 24)
    btn.Position = UDim2.new(0.45, 0, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.BorderSizePixel = 0
    btn.Text = default or options[1] or ""
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = FONT_SIZE
    btn.Parent = frame
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    local dropdown = Instance.new("ScrollingFrame")
    dropdown.Size = UDim2.new(0.55, -10, 0, 0)
    dropdown.Position = UDim2.new(0.45, 0, 0, 30)
    dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    dropdown.BorderSizePixel = 0
    dropdown.Visible = false
    dropdown.ClipsDescendants = true
    dropdown.ScrollBarThickness = 3
    dropdown.AutomaticCanvasSize = Enum.AutomaticSize.Y
    dropdown.CanvasSize = UDim2.fromOffset(0, 0)
    dropdown.Parent = frame
    local dc = Instance.new("UICorner", dropdown)
    dc.CornerRadius = UDim.new(0, 6)

    local dropLayout = Instance.new("UIListLayout")
    dropLayout.Padding = UDim.new(0, 2)
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Parent = dropdown

    local current = default or options[1] or ""
    local function rebuild()
        for _, child in ipairs(dropdown:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, -4, 0, 24)
            optBtn.Position = UDim2.new(0, 2, 0, 0)
            optBtn.BackgroundColor3 = (opt == current) and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
            optBtn.BorderSizePixel = 0
            optBtn.Text = opt
            optBtn.TextColor3 = (opt == current) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = FONT_SIZE
            optBtn.Parent = dropdown
            local oc = Instance.new("UICorner", optBtn)
            oc.CornerRadius = UDim.new(0, 4)
            optBtn.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = opt
                dropdown.Visible = false
                dropdown.Size = UDim2.new(0.55, -10, 0, 0)
                if callback then callback(current) end
                rebuild()
            end)
        end
        dropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = math.min(120, dropLayout.AbsoluteContentSize.Y + 8)
            dropdown.CanvasSize = UDim2.fromOffset(0, dropLayout.AbsoluteContentSize.Y + 8)
            if dropdown.Visible then
                dropdown.Size = UDim2.new(0.55, -10, 0, h)
            end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        dropdown.Visible = not dropdown.Visible
        if dropdown.Visible then
            local h = math.min(120, dropLayout.AbsoluteContentSize.Y + 8)
            dropdown.Size = UDim2.new(0.55, -10, 0, h)
        else
            dropdown.Size = UDim2.new(0.55, -10, 0, 0)
        end
    end)

    rebuild()
    return {Set = function(v) current = v; btn.Text = v; rebuild(); if callback then callback(v) end end, Get = function() return current end}
end

-- ===== VARIABEL STATE =====
local toggles = {}
local loopInterval = 2
local autoSellEnabled = false
local autoBuyEggEnabled = false
local autoBuyGearEnabled = false
local autoCollectEnabled = false
local autoBountyEnabled = false
local autoTurnInEnabled = false
local autoFusionEnabled = false
local autoScrollEnabled = false
local autoPotEnabled = false
local autoHatchEnabled = false
local autoEquipBestEnabled = false

-- Pilihan item
local selectedEgg = eggItems[1] or "Capybara Egg"
local selectedGear = gearItems[1] or "Hatch Hammer"
local selectedMutation = "Moonlit"
local mutationList = {"Gold", "Rainbow", "Moonlit", "Chilly", "Toasty", "Tranquil", "Shocked", "Glitched"}

-- ===== FUNGSI FITUR =====

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

local function useScroll(mutation, item)
    -- Cari item yang dipegang
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
    if tool and tool:GetAttribute("plantID") then
        Remotes.MutationScroll:FireServer(mutation, tool)
    else
        print("Tidak ada tanaman yang dipegang")
    end
end

local function potInteract(plotNumber)
    Remotes.PotInteract:FireServer(plotNumber)
end

local function hatchEgg()
    -- Cari telur yang sudah siap
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

-- Toggle functions
local function toggleAutoSell(v)
    autoSellEnabled = v
    if v then
        spawn(function()
            while autoSellEnabled and wait(loopInterval) do
                pcall(sellAll, "Plant")
            end
        end)
    end
end

local function toggleAutoBuyEgg(v)
    autoBuyEggEnabled = v
    if v then
        spawn(function()
            while autoBuyEggEnabled and wait(loopInterval * 5) do
                pcall(buyItem, selectedEgg)
            end
        end)
    end
end

local function toggleAutoBuyGear(v)
    autoBuyGearEnabled = v
    if v then
        spawn(function()
            while autoBuyGearEnabled and wait(loopInterval * 5) do
                pcall(buyItem, selectedGear)
            end
        end)
    end
end

local function toggleAutoCollect(v)
    autoCollectEnabled = v
    if v then
        spawn(function()
            while autoCollectEnabled and wait(loopInterval) do
                pcall(collectMoney)
            end
        end)
    end
end

local function toggleAutoBounty(v)
    autoBountyEnabled = v
    if v then
        spawn(function()
            while autoBountyEnabled and wait(loopInterval * 3) do
                pcall(getBounties)
            end
        end)
    end
end

local function toggleAutoTurnIn(v)
    autoTurnInEnabled = v
    if v then
        spawn(function()
            while autoTurnInEnabled and wait(loopInterval * 2) do
                pcall(turnInBounty)
            end
        end)
    end
end

local function toggleAutoFusion(v)
    autoFusionEnabled = v
    if v then
        spawn(function()
            while autoFusionEnabled and wait(loopInterval * 10) do
                pcall(fuse, "Capybara")
            end
        end)
    end
end

local function toggleAutoScroll(v)
    autoScrollEnabled = v
    if v then
        spawn(function()
            while autoScrollEnabled and wait(loopInterval * 5) do
                pcall(useScroll, selectedMutation)
            end
        end)
    end
end

local function toggleAutoPot(v)
    autoPotEnabled = v
    if v then
        spawn(function()
            while autoPotEnabled and wait(loopInterval * 3) do
                pcall(potInteract, 1) -- plot 1
            end
        end)
    end
end

local function toggleAutoHatch(v)
    autoHatchEnabled = v
    if v then
        spawn(function()
            while autoHatchEnabled and wait(loopInterval * 2) do
                pcall(hatchEgg)
            end
        end)
    end
end

local function toggleAutoEquipBest(v)
    autoEquipBestEnabled = v
    if v then
        spawn(function()
            while autoEquipBestEnabled and wait(loopInterval * 3) do
                pcall(equipBestPlants)
            end
        end)
    end
end

-- ===== UI =====

addLabel("-- Auto Sell --")
toggles["sell"] = addToggle("Sell All Plants", false, toggleAutoSell)

addLabel("-- Auto Buy --")
toggles["buyegg"] = addToggle("Buy Egg", false, toggleAutoBuyEgg)
toggles["buygear"] = addToggle("Buy Gear", false, toggleAutoBuyGear)

addLabel("-- Auto Collect --")
toggles["collect"] = addToggle("Collect Money", false, toggleAutoCollect)

addLabel("-- Bounty --")
toggles["bounty"] = addToggle("Get Bounties", false, toggleAutoBounty)
toggles["turnin"] = addToggle("Turn In Bounty", false, toggleAutoTurnIn)

addLabel("-- Fusion & Mutation --")
toggles["fusion"] = addToggle("Auto Fusion (Capybara)", false, toggleAutoFusion)
toggles["scroll"] = addToggle("Auto Mutation Scroll", false, toggleAutoScroll)

addLabel("-- Garden --")
toggles["pot"] = addToggle("Auto Pot Interact", false, toggleAutoPot)
toggles["hatch"] = addToggle("Auto Hatch Egg", false, toggleAutoHatch)
toggles["equip"] = addToggle("Equip Best Plants", false, toggleAutoEquipBest)

addLabel("-- Settings --")
local intervalSlider = addSlider("Interval (s)", 1, 30, loopInterval, function(v)
    loopInterval = v
end)

-- Dropdown untuk pilihan egg
local eggDropdown = addDropdown("Pilih Egg", eggItems, selectedEgg, function(v)
    selectedEgg = v
end)

local gearDropdown = addDropdown("Pilih Gear", gearItems, selectedGear, function(v)
    selectedGear = v
end)

local mutationDropdown = addDropdown("Pilih Mutasi", mutationList, selectedMutation, function(v)
    selectedMutation = v
end)

addLabel("-- Tombol Manual --")
addButton("Sell All Plants", function() sellAll("Plant") end)
addButton("Sell All Capybaras", function() sellAll("Capybara") end)
addButton("Collect Money", collectMoney)
addButton("Turn In Bounty", turnInBounty)
addButton("Get Bounties", getBounties)
addButton("Hatch Ready Egg", hatchEgg)
addButton("Equip Best Plants", equipBestPlants)

addLabel("Font kecil - Cocok Android")

-- ===== DRAG WINDOW =====
local dragging = false
local dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

print("Auto Farm GUI Android siap! Menggunakan remote dari data file.")