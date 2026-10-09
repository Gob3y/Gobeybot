--[[
    MY ANIME MINE | HAIMIYACH HUB
    Dump-grounded utility UI for Roblox My Anime Mine.
    Target PlaceId: 79389059854988

    IMPORTANT:
    - This script does not fabricate RemoteEvent names or arguments.
    - Actions use existing visible game GUI controls when detected.
    - Some dump features are presentation/client modules, not server action APIs.
    - If a native control is not found, the status panel reports it instead of
      pretending the feature worked.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")

local PLACE_ID = 79389059854988
local GUI_NAME = "HAIMIYACH_MyAnimeMine"
local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local state = {
    autoSwing = false,
    autoCollect = false,
    autoSell = false,
    autoEquipBest = false,
    fpsBoost = false,
    antiAfk = false,
    focusedFirst = "Nearest",
    sellType = "Ore",
    sellRarity = "All",
    keepAboveValue = 0,
    sellAtCount = 0,
    swingDelay = 0.5,
}
local connections = {}
local statusLines = {}
local alive = true

local function addStatus(message)
    local stamp = os.date("%H:%M:%S")
    table.insert(statusLines, 1, "[" .. stamp .. "] " .. tostring(message))
    while #statusLines > 30 do table.remove(statusLines) end
end

local function safeFind(root, path)
    local node = root
    for part in string.gmatch(path, "[^%.]+") do
        if not node then return nil end
        node = node:FindFirstChild(part)
    end
    return node
end

local function findNativeControl(paths)
    for _, path in ipairs(paths) do
        local item = safeFind(playerGui, path)
        if item and (item:IsA("TextButton") or item:IsA("ImageButton")) then
            return item, path
        end
    end
    return nil
end

local function activateNative(paths, label)
    local button, path = findNativeControl(paths)
    if not button then
        addStatus(label .. ": native button not found in current UI")
        return false
    end
    local ok = pcall(function() button:Activate() end)
    if ok then
        addStatus(label .. ": activated " .. path)
        return true
    end
    addStatus(label .. ": failed to activate " .. path)
    return false
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    obj.Parent = parent
    return obj
end
local function round(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end
local function outline(obj, transparency)
    make("UIStroke", {
        Color = Color3.fromRGB(72, 75, 84),
        Transparency = transparency or 0.35,
        Thickness = 1
    }, obj)
end

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local width = math.clamp(math.floor(viewport.X * 0.82), 280, 370)
local height = math.clamp(math.floor(viewport.Y * 0.70), 350, 520)

local window = make("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(width, height),
    Position = UDim2.new(0, 12, 0.5, -height/2),
    BackgroundColor3 = Color3.fromRGB(22, 23, 27),
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true
}, gui)
round(window, 10); outline(window, 0.15)

local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = Color3.fromRGB(30, 31, 37),
    BorderSizePixel = 0,
    Active = true
}, window)
round(header, 10)
make("Frame", {
    Position = UDim2.new(0,0,1,-10),
    Size = UDim2.new(1,0,0,10),
    BackgroundColor3 = Color3.fromRGB(30,31,37),
    BorderSizePixel = 0
}, header)
make("TextLabel", {
    Position = UDim2.fromOffset(12, 6),
    Size = UDim2.new(1,-54,0,19),
    BackgroundTransparency = 1,
    Text = "HAIMIYACH",
    TextColor3 = Color3.fromRGB(245,246,249),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)
make("TextLabel", {
    Position = UDim2.fromOffset(12, 26),
    Size = UDim2.new(1,-54,0,12),
    BackgroundTransparency = 1,
    Text = "MY ANIME MINE • DUMP-BASED",
    TextColor3 = Color3.fromRGB(145,148,158),
    Font = Enum.Font.GothamMedium,
    TextSize = 7,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)
local close = make("TextButton", {
    Size = UDim2.fromOffset(28,28),
    Position = UDim2.new(1,-36,0,8),
    BackgroundColor3 = Color3.fromRGB(48,49,56),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(235,235,240),
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    AutoButtonColor = false
}, header)
round(close, 7)

local tabBar = make("ScrollingFrame", {
    Name = "Tabs",
    Position = UDim2.fromOffset(6, 51),
    Size = UDim2.new(1,-12,0,36),
    BackgroundColor3 = Color3.fromRGB(29,30,35),
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.X,
    AutomaticCanvasSize = Enum.AutomaticSize.X,
    CanvasSize = UDim2.new()
}, window)
round(tabBar, 7)
make("UIPadding", {
    PaddingLeft = UDim.new(0,4), PaddingRight = UDim.new(0,4),
    PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4)
}, tabBar)
local tabLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0,4),
    SortOrder = Enum.SortOrder.LayoutOrder
}, tabBar)

local pageHolder = make("Frame", {
    Position = UDim2.fromOffset(6, 92),
    Size = UDim2.new(1,-12,1,-98),
    BackgroundTransparency = 1,
    ClipsDescendants = true
}, window)
local pages, tabs = {}, {}
local currentPage

local function makePage(name)
    local page = make("ScrollingFrame", {
        Name = name,
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(105,108,118),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Visible = false
    }, pageHolder)
    make("UIPadding", {
        PaddingLeft = UDim.new(0,2), PaddingRight = UDim.new(0,2),
        PaddingBottom = UDim.new(0,8)
    }, page)
    make("UIListLayout", {
        Padding = UDim.new(0,5),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)
    pages[name] = page
    return page
end

local function selectPage(name)
    currentPage = name
    for n,p in pairs(pages) do p.Visible = n == name end
    for n,b in pairs(tabs) do
        b.BackgroundColor3 = n == name and Color3.fromRGB(75,77,87) or Color3.fromRGB(42,43,50)
        b.TextColor3 = n == name and Color3.fromRGB(250,250,252) or Color3.fromRGB(170,172,181)
    end
end

local function makeTab(name, order)
    local b = make("TextButton", {
        Name = name .. "Tab",
        Size = UDim2.fromOffset(name == "SETTINGS" and 76 or 66, 26),
        BackgroundColor3 = Color3.fromRGB(42,43,50),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Color3.fromRGB(170,172,181),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        LayoutOrder = order,
        AutoButtonColor = false
    }, tabBar)
    round(b, 6)
    tabs[name] = b
    b.Activated:Connect(function() selectPage(name) end)
end

local function section(page, text, order)
    make("TextLabel", {
        Size = UDim2.new(1,0,0,18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(132,135,146),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order or 0
    }, page)
end

local function rowBase(page, order, h)
    local r = make("Frame", {
        Size = UDim2.new(1,0,0,h or 36),
        BackgroundColor3 = Color3.fromRGB(34,35,41),
        BorderSizePixel = 0,
        LayoutOrder = order or 0
    }, page)
    round(r, 7); outline(r)
    return r
end

local function toggleRow(page, labelText, order, key, callback)
    local r = rowBase(page, order, 36)
    make("TextLabel", {
        Position = UDim2.fromOffset(10,0),
        Size = UDim2.new(1,-82,1,0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Color3.fromRGB(229,230,235),
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left
    }, r)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(52,23),
        Position = UDim2.new(1,-61,0.5,-11),
        BackgroundColor3 = Color3.fromRGB(47,48,55),
        BorderSizePixel = 0,
        Text = state[key] and "ON" or "OFF",
        TextColor3 = Color3.fromRGB(235,236,240),
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        AutoButtonColor = false
    }, r)
    round(b, 12)
    local function redraw()
        b.Text = state[key] and "ON" or "OFF"
        b.BackgroundColor3 = state[key] and Color3.fromRGB(83,85,96) or Color3.fromRGB(47,48,55)
    end
    b.Activated:Connect(function()
        state[key] = not state[key]
        redraw()
        if callback then
            local ok, err = pcall(callback, state[key])
            if not ok then addStatus(labelText .. " error: " .. tostring(err)) end
        end
    end)
end

local function dropdownRow(page, labelText, order, key, options, callback)
    local r = rowBase(page, order, 39)
    make("TextLabel", {
        Position = UDim2.fromOffset(10,0),
        Size = UDim2.new(0.42,0,1,0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Color3.fromRGB(225,226,232),
        Font = Enum.Font.GothamMedium,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left
    }, r)
    local b = make("TextButton", {
        Position = UDim2.new(0.43,0,0.5,-13),
        Size = UDim2.new(0.55,-8,0,26),
        BackgroundColor3 = Color3.fromRGB(48,49,57),
        BorderSizePixel = 0,
        Text = tostring(state[key]),
        TextColor3 = Color3.fromRGB(236,237,241),
        Font = Enum.Font.GothamMedium,
        TextSize = 8,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false
    }, r)
    round(b, 6)
    local popup = make("Frame", {
        Position = UDim2.new(0,0,1,3),
        Size = UDim2.new(1,0,0,0),
        BackgroundColor3 = Color3.fromRGB(28,29,34),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20
    }, r)
    round(popup, 7); outline(popup)
    local layout = make("UIListLayout", {Padding=UDim.new(0,2)}, popup)
    local open = false
    local function closePopup()
        open = false; popup.Visible = false; popup.Size = UDim2.new(1,0,0,0)
    end
    for i,opt in ipairs(options) do
        local item = make("TextButton", {
            Size = UDim2.new(1,-8,0,27),
            BackgroundColor3 = Color3.fromRGB(42,43,50),
            BorderSizePixel = 0,
            Text = "  " .. tostring(opt),
            TextColor3 = Color3.fromRGB(230,231,236),
            Font = Enum.Font.Gotham,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = i,
            ZIndex = 21,
            AutoButtonColor = false
        }, popup)
        round(item,5)
        item.Activated:Connect(function()
            state[key] = opt
            b.Text = tostring(opt)
            closePopup()
            if callback then pcall(callback, opt) end
        end)
    end
    b.Activated:Connect(function()
        open = not open
        popup.Visible = open
        popup.Size = UDim2.new(1,0,0,open and math.min(#options*29+4,145) or 0)
    end)
end

local function buttonRow(page, text, order, callback)
    local r = rowBase(page, order, 36)
    local b = make("TextButton", {
        Size = UDim2.new(1,-8,1,-8),
        Position = UDim2.fromOffset(4,4),
        BackgroundColor3 = Color3.fromRGB(45,46,53),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(235,236,241),
        Font = Enum.Font.GothamMedium,
        TextSize = 8,
        AutoButtonColor = false
    }, r)
    round(b,6)
    b.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then addStatus(text .. " error: " .. tostring(err)) end
    end)
end

local Main = makePage("MAIN")
local Mine = makePage("MINE")
local Sell = makePage("SELL")
local Gear = makePage("GEAR")
local Utility = makePage("UTILITY")
local Status = makePage("STATUS")
local Settings = makePage("SETTINGS")

for i,n in ipairs({"MAIN","MINE","SELL","GEAR","UTILITY","STATUS","SETTINGS"}) do makeTab(n,i) end

section(Main, "QUICK ACTIONS", 1)
buttonRow(Main, "Collect Chest (native control)", 2, function()
    activateNative({
        "MineGui.ChestFrame.Content.CollectButton",
        "MineGui.ChestFrame.Content.TakeAllButton",
        "MineGui.ChestFrame.CollectButton",
        "MineGui.ChestFrame.TakeAllButton"
    }, "Collect Chest")
end)
buttonRow(Main, "Open Sell UI", 3, function()
    local f = safeFind(playerGui, "MineGui.SellFrame")
    if f then f.Visible = true; addStatus("Sell UI opened")
    else addStatus("MineGui.SellFrame not found") end
end)
buttonRow(Main, "Open Auto Sell UI", 4, function()
    local f = safeFind(playerGui, "MineGui.AutoSellFrame")
    if f then f.Visible = true; addStatus("Auto Sell UI opened")
    else addStatus("MineGui.AutoSellFrame not found") end
end)
buttonRow(Main, "Open Store UI", 5, function()
    local f = safeFind(playerGui, "MineGui.StoreFrame")
    if f then f.Visible = true; addStatus("Store UI opened")
    else addStatus("MineGui.StoreFrame not found") end
end)
section(Main, "AUTOMATION", 8)
toggleRow(Main, "Auto Swing Tool", 9, "autoSwing", function(on)
    addStatus("Auto Swing " .. (on and "enabled" or "disabled") .. " (native tool activation)")
end)
toggleRow(Main, "Auto Collect Chest", 10, "autoCollect", function(on)
    addStatus("Auto Collect " .. (on and "enabled" or "disabled"))
end)
toggleRow(Main, "Auto Sell (native UI)", 11, "autoSell", function(on)
    addStatus("Auto Sell " .. (on and "enabled" or "disabled"))
end)
toggleRow(Main, "Auto Equip Best", 12, "autoEquipBest", function(on)
    addStatus("Auto Equip Best " .. (on and "enabled" or "disabled"))
end)

section(Mine, "MINE SETTINGS", 1)
dropdownRow(Mine, "Node Priority", 2, "focusedFirst", {"Nearest","Lowest HP","Highest Value","Any"}, function(v)
    addStatus("Node Priority set to " .. v .. " (selection only until node API is confirmed)")
end)
dropdownRow(Mine, "Swing Delay", 3, "swingDelay", {"0.12","0.2","0.35","0.5","0.75","1"}, function(v)
    state.swingDelay = tonumber(v) or 0.5
    addStatus("Swing delay set to " .. tostring(state.swingDelay))
end)
buttonRow(Mine, "Inspect MineWorld", 4, function()
    local root = safeFind(Workspace, "MineWorld")
    if not root then addStatus("workspace.MineWorld not found"); return end
    local count = 0
    for _,d in ipairs(root:GetDescendants()) do
        if d:IsA("BasePart") then count += 1 end
    end
    addStatus("MineWorld found; BaseParts=" .. count)
end)
buttonRow(Mine, "Find MineFX Remote (diagnostic only)", 5, function()
    local rs = game:GetService("ReplicatedStorage")
    local r = safeFind(rs, "Remotes.MineFX")
    addStatus(r and ("Remotes.MineFX found ("..r.ClassName..")") or "Remotes.MineFX not found")
end)

section(Sell, "SELL FILTERS", 1)
dropdownRow(Sell, "Item Type", 2, "sellType", {"Ore","All","Material","Tool"}, function(v)
    addStatus("Sell item filter selected: " .. v)
end)
dropdownRow(Sell, "Rarity", 3, "sellRarity", {"All","Common","Uncommon","Rare","Epic","Legendary","Mythic"}, function(v)
    addStatus("Sell rarity selected: " .. v)
end)
buttonRow(Sell, "Open Native Sell Frame", 4, function()
    local f = safeFind(playerGui, "MineGui.SellFrame")
    if f then f.Visible = true; addStatus("SellFrame visible")
    else addStatus("SellFrame not found; open the game's sell menu once first") end
end)
buttonRow(Sell, "Activate Native Sell All", 5, function()
    activateNative({
        "MineGui.SellFrame.Content.SelectAllButton",
        "MineGui.SellFrame.Content.SellButton"
    }, "Native Sell control")
end)
buttonRow(Sell, "Inspect Auto Sell Controls", 6, function()
    local f = safeFind(playerGui, "MineGui.AutoSellFrame")
    if not f then addStatus("AutoSellFrame not found"); return end
    local found = {}
    for _,d in ipairs(f:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then table.insert(found,d:GetFullName()) end
    end
    addStatus("AutoSell buttons detected: " .. tostring(#found))
    for i=1,math.min(#found,5) do addStatus(found[i]) end
end)

section(Gear, "EQUIPMENT", 1)
buttonRow(Gear, "Activate Equip Best", 2, function()
    activateNative({
        "MineGui.StoreFrame.EquipBestButton",
        "MineGui.StoreFrame.Content.EquipBestButton",
        "MineGui.EquipBestButton",
        "MineGui.PickaxesFrame.EquipBestButton"
    }, "Equip Best")
end)
buttonRow(Gear, "Open Store / Pickaxe UI", 3, function()
    local paths = {"MineGui.StoreFrame","MineGui.PickaxesFrame","MineGui.PickaxeFrame"}
    local found
    for _,p in ipairs(paths) do
        local f = safeFind(playerGui,p)
        if f then f.Visible = true; found = p; break end
    end
    addStatus(found and ("Opened "..found) or "Store/Pickaxe UI not found")
end)
buttonRow(Gear, "Inspect Store Buttons", 4, function()
    local f = safeFind(playerGui, "MineGui.StoreFrame")
    if not f then addStatus("StoreFrame not found"); return end
    local n = 0
    for _,d in ipairs(f:GetDescendants()) do
        if d:IsA("TextButton") or d:IsA("ImageButton") then
            n += 1
            if n <= 8 then addStatus("Store button: " .. d:GetFullName()) end
        end
    end
    addStatus("Store button count=" .. n)
end)

section(Utility, "CLIENT UTILITIES", 1)
toggleRow(Utility, "FPS Boost (visual only)", 2, "fpsBoost", function(on)
    local changed = 0
    for _,d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            pcall(function() d.Enabled = not on end)
            changed += 1
        elseif d:IsA("BasePart") and on then
            pcall(function()
                if d.Material == Enum.Material.Neon then d.Material = Enum.Material.SmoothPlastic end
            end)
        end
    end
    addStatus("FPS visual toggle applied to " .. changed .. " effects; some visuals may need re-enable after OFF")
end)
toggleRow(Utility, "Anti AFK (client connection)", 3, "antiAfk", function(on)
    if on then
        local ok = pcall(function()
            local vu = game:GetService("VirtualUser")
            connections.antiAfk = player.Idled:Connect(function()
                pcall(function()
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(0,0))
                end)
            end)
        end)
        addStatus(ok and "Anti AFK listener connected" or "Anti AFK could not connect")
    else
        if connections.antiAfk then connections.antiAfk:Disconnect(); connections.antiAfk = nil end
        addStatus("Anti AFK listener disconnected")
    end
end)
buttonRow(Utility, "Restore Visual Effects", 4, function()
    addStatus("Rejoin or reload the game to restore every changed visual safely")
end)

section(Status, "DUMP / RUNTIME STATUS", 1)
local statusText = make("TextLabel", {
    Name = "StatusText",
    Size = UDim2.new(1,0,0,260),
    BackgroundColor3 = Color3.fromRGB(29,30,35),
    BorderSizePixel = 0,
    Text = "Initializing diagnostics...",
    TextColor3 = Color3.fromRGB(220,222,229),
    Font = Enum.Font.Code,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    LayoutOrder = 2
}, Status)
round(statusText,7)
make("UIPadding", {
    PaddingTop = UDim.new(0,8), PaddingLeft = UDim.new(0,8),
    PaddingRight = UDim.new(0,8), PaddingBottom = UDim.new(0,8)
}, statusText)
buttonRow(Status, "Run Diagnostics", 3, function()
    local rs = game:GetService("ReplicatedStorage")
    local lines = {
        "PlaceId: " .. tostring(game.PlaceId),
        "Expected: " .. tostring(PLACE_ID),
        "PlayerGui.MineGui: " .. tostring(safeFind(playerGui,"MineGui") ~= nil),
        "ReplicatedStorage.Modules: " .. tostring(rs:FindFirstChild("Modules") ~= nil),
        "Remotes folder: " .. tostring(rs:FindFirstChild("Remotes") ~= nil),
        "Remotes.MineFX: " .. tostring(safeFind(rs,"Remotes.MineFX") ~= nil),
        "workspace.MineWorld: " .. tostring(safeFind(Workspace,"MineWorld") ~= nil),
        "MineGui.SellFrame: " .. tostring(safeFind(playerGui,"MineGui.SellFrame") ~= nil),
        "MineGui.AutoSellFrame: " .. tostring(safeFind(playerGui,"MineGui.AutoSellFrame") ~= nil),
        "MineGui.ChestFrame: " .. tostring(safeFind(playerGui,"MineGui.ChestFrame") ~= nil),
        "MineGui.StoreFrame: " .. tostring(safeFind(playerGui,"MineGui.StoreFrame") ~= nil),
        "",
        "Recent log:"
    }
    for i=1,math.min(14,#statusLines) do table.insert(lines,statusLines[i]) end
    statusText.Text = table.concat(lines,"\n")
    addStatus("Diagnostics refreshed")
end)

section(Settings, "SETTINGS", 1)
buttonRow(Settings, "Hide Menu", 2, function()
    window.Visible = false
    reopen.Visible = true
end)
buttonRow(Settings, "Stop All Toggles", 3, function()
    state.autoSwing = false
    state.autoCollect = false
    state.autoSell = false
    state.autoEquipBest = false
    addStatus("All automation toggles turned OFF")
    for _,d in ipairs(window:GetDescendants()) do
        if d:IsA("TextButton") and (d.Text == "ON") then
            d.Text = "OFF"
            d.BackgroundColor3 = Color3.fromRGB(47,48,55)
        end
    end
end)
buttonRow(Settings, "Destroy Hub", 4, function()
    alive = false
    for _,c in pairs(connections) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end)

local reopen = make("TextButton", {
    Name = "Reopen",
    Size = UDim2.fromOffset(100,30),
    Position = UDim2.new(0.5,-50,0,8),
    BackgroundColor3 = Color3.fromRGB(30,31,37),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Text = "HAIMIYACH",
    TextColor3 = Color3.fromRGB(245,246,249),
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    Visible = false,
    ZIndex = 100
}, gui)
round(reopen,15); outline(reopen,0.25)
reopen.Activated:Connect(function()
    window.Visible = true
    reopen.Visible = false
end)
close.Activated:Connect(function()
    window.Visible = false
    reopen.Visible = true
end)

-- Window dragging; touch and mouse supported.
do
    local dragging, startPos, origin, dragConn = false, nil, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true; startPos = input.Position; origin = window.Position
        if dragConn then dragConn:Disconnect() end
        dragConn = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch and move.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = move.Position - startPos
            window.Position = UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y)
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if dragConn then dragConn:Disconnect(); dragConn = nil end
            end
        end)
    end)
end

-- The dump confirms tool swing behavior is controlled by the game's own
-- ToolSwingController. Use Tool:Activate(), not guessed MineFX remote arguments.
local lastSwing = 0
local autoLoop = task.spawn(function()
    while alive and gui.Parent do
        task.wait(0.05)
        if state.autoSwing and (os.clock() - lastSwing) >= (tonumber(state.swingDelay) or 0.5) then
            lastSwing = os.clock()
            local character = player.Character
            local tool = character and character:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() tool:Activate() end)
            else
                -- Equipable tool may be in Backpack; do not force unknown equip remotes.
                local backpack = player:FindFirstChildOfClass("Backpack")
                local candidate = backpack and backpack:FindFirstChildOfClass("Tool")
                if candidate then
                    addStatus("Auto Swing: no equipped Tool; equip a pickaxe first")
                end
            end
        end
        if state.autoCollect and (os.clock() - (connections.lastCollect or 0)) >= 3 then
            connections.lastCollect = os.clock()
            activateNative({
                "MineGui.ChestFrame.Content.CollectButton",
                "MineGui.ChestFrame.Content.TakeAllButton",
                "MineGui.ChestFrame.CollectButton",
                "MineGui.ChestFrame.TakeAllButton"
            }, "Auto Collect")
        end
        if state.autoSell and (os.clock() - (connections.lastSell or 0)) >= 5 then
            connections.lastSell = os.clock()
            activateNative({
                "MineGui.AutoSellFrame.Content.Actions.SaveButton",
                "MineGui.AutoSellFrame.Content.Actions.EnableButton",
                "MineGui.AutoSellFrame.Content.Actions.ApplyButton"
            }, "Auto Sell")
        end
        if state.autoEquipBest and (os.clock() - (connections.lastEquip or 0)) >= 10 then
            connections.lastEquip = os.clock()
            activateNative({
                "MineGui.StoreFrame.EquipBestButton",
                "MineGui.StoreFrame.Content.EquipBestButton",
                "MineGui.EquipBestButton"
            }, "Auto Equip Best")
        end
    end
end)

-- Initial status
addStatus("Hub loaded. Features are grounded in the uploaded dump; unverified actions report status.")
addStatus("PlaceId=" .. tostring(game.PlaceId) .. " (expected " .. tostring(PLACE_ID) .. ")")
selectPage("MAIN")
task.defer(function()
    if statusText and statusText.Parent then
        statusText.Text = "Tap Run Diagnostics.\n\nDump-confirmed paths:\n• ReplicatedStorage.Remotes.MineFX\n• workspace.MineWorld.Plots\n• PlayerGui.MineGui.SellFrame\n• PlayerGui.MineGui.AutoSellFrame\n• PlayerGui.MineGui.ChestFrame\n• PlayerGui.MineGui.StoreFrame\n\nAutomation uses native controls; filters are UI settings until actual server-side filter API is verified."
    end
end)
print("[HAIMIYACH] My Anime Mine hub loaded")
