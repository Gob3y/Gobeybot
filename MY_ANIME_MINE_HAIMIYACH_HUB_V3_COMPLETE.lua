--[[
    MY ANIME MINE | HAIMIYACH HUB
    Dump-grounded utility UI for Roblox My Anime Mine.
    Target PlaceId: 79389059854988

    IMPORTANT:
    - This script does not fabricate RemoteEvent names or arguments.
    - Confirmed game actions use APIs explicitly present in the uploaded dump.
    - Runtime execution still needs verification in the target Roblox client.
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
local reopen -- forward declaration: settings callbacks are created before the reopen button
local replicatedStorage = game:GetService("ReplicatedStorage")
local gameState, clientUtility, mineInventory, mineConfig, mineStock, items
pcall(function() gameState = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("GameState")) end)
pcall(function() clientUtility = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("ClientUtility")) end)
pcall(function() mineInventory = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineInventory")) end)
pcall(function() mineConfig = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineConfig")) end)
pcall(function() mineStock = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineStock")) end)
pcall(function() items = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("Items")) end)

local PLACE_ID = 79389059854988
local GUI_NAME = "HAIMIYACH_MyAnimeMine"
local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local state = {
    autoSwing = false,
    autoCollect = false,
    autoSell = false,
    autoEquipBest = false,
    autoUpgradeCharacters = false,
    autoBuyPickaxes = false,
    pickaxeFilter = "Best Affordable",
    autoUpgradeSkills = false,
    autoUpgradeCore = false,
    autoBuySlots = false,
    autoResearchZone = false,
    returnAfterBuy = true,
    fpsBoost = false,
    antiAfk = false,
    focusedFirst = "Nearest",
    sellType = "Ore",
    sellRarity = "All",
    keepAboveValue = 0,
    sellAtCount = 0,
    swingDelay = 0.5,
    sellDelay = 60,
    upgradeDelay = 10,
    researchDelay = 3,
    equipDelay = 30,
    collectDelay = 10,
    autoSellTeleport = true,
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

local function toggleNativeFrame(frameName, visible, label)
    local frame = safeFind(playerGui, "MineGui." .. frameName)
    if not frame then addStatus(label .. ": MineGui." .. frameName .. " not found"); return false end
    local ok = pcall(function()
        if clientUtility and type(clientUtility.ToggleFrame) == "function" then
            clientUtility:ToggleFrame(frame, visible)
        else
            frame.Visible = visible
        end
    end)
    if ok then addStatus(label .. (visible and ": opened" or ": closed")); return true end
    addStatus(label .. ": failed to toggle frame")
    return false
end

local function sendGameEvent(eventName, ...)
    if not gameState or type(gameState.SendEvent) ~= "function" then
        addStatus(eventName .. ": GameState.SendEvent unavailable")
        return false
    end
    local args = table.pack(...)
    local ok, err = pcall(function() gameState.SendEvent(eventName, table.unpack(args, 1, args.n)) end)
    if not ok then addStatus(eventName .. " failed: " .. tostring(err)); return false end
    addStatus(eventName .. " sent")
    return true
end


local function getSellStandCFrame()
    local stand = Workspace:FindFirstChild("SellStand")
    if not stand then return nil end
    -- Prefer the NPC's root/torso because the game checks distance to the seller.
    for _, child in ipairs(stand:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
            local part = child:FindFirstChild("HumanoidRootPart")
                or child:FindFirstChild("UpperTorso")
                or child:FindFirstChild("Torso")
                or child:FindFirstChild("Head")
            if part and part:IsA("BasePart") then return part.CFrame end
        end
    end
    local part = stand:IsA("Model") and (stand.PrimaryPart or stand:FindFirstChildWhichIsA("BasePart", true))
        or (stand:IsA("BasePart") and stand or stand:FindFirstChildWhichIsA("BasePart", true))
    return part and part.CFrame or nil
end

local function moveToSellStand()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local target = getSellStandCFrame()
    if not root or not target then
        addStatus("Sell Stand: NPC/character root not found")
        return false
    end
    if (root.Position - target.Position).Magnitude > 12 then
        local ok = pcall(function()
            character:PivotTo(target + Vector3.new(0, 0, 4))
        end)
        if not ok then
            addStatus("Sell Stand teleport failed")
            return false
        end
        task.wait(1.25) -- allow character position / server proximity state to settle
    end
    return true
end

local function collectSellableOreKeys()
    if not gameState or not mineInventory then return nil, "game modules unavailable" end
    local okData, data = pcall(function() return gameState.GetData2() end)
    local mine = okData and data and data.MineGame
    if not mine then return nil, "MineGame data not ready" end
    local okEntries, entries = pcall(function()
        return mineInventory.Collect(mine, "All", mineInventory.KindOrder.OreFirst)
    end)
    if not okEntries or type(entries) ~= "table" then return nil, "inventory entries unavailable" end
    local keys = {}
    for _, entry in ipairs(entries) do
        if entry.Kind == "Ore" and (entry.SellCount or entry.Count or 0) > 0
            and (entry.Worth or 0) > 0 and entry.Key then
            table.insert(keys, entry.Key)
        end
    end
    return keys
end

local function performSell(label)
    if state.autoSellTeleport and not moveToSellStand() then return false end
    local keys, err = collectSellableOreKeys()
    if not keys then addStatus(label .. ": " .. tostring(err)); return false end
    if #keys == 0 then addStatus(label .. ": no sellable ores; collect chest first"); return false end
    local ok = sendGameEvent("MineSellItems", keys)
    if ok then addStatus(label .. ": request sent for " .. #keys .. " ore stacks") end
    return ok
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
    Text = "MY ANIME MINE • HAIMIYACH HUB",
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
local closeDropdown

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
    closeDropdown()
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

local function buttonRow(page, labelText, order, callback)
    local r = rowBase(page, order, 36)
    local b = make("TextButton", {
        Name = "ActionButton",
        Position = UDim2.fromOffset(5, 4),
        Size = UDim2.new(1, -10, 1, -8),
        BackgroundColor3 = Color3.fromRGB(47, 48, 56),
        BorderSizePixel = 0,
        Text = labelText,
        TextColor3 = Color3.fromRGB(236, 237, 242),
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextWrapped = true,
        AutoButtonColor = false
    }, r)
    round(b, 6)
    b.Activated:Connect(function()
        if type(callback) ~= "function" then return end
        local ok, err = pcall(callback)
        if not ok then addStatus(labelText .. " error: " .. tostring(err)) end
    end)
    return b
end

local dropdownPopup
closeDropdown = function()
    if dropdownPopup then dropdownPopup:Destroy(); dropdownPopup = nil end
end

local function dropdownRow(page, labelText, order, key, options, callback)
    local r = rowBase(page, order, 39)
    make("TextLabel", {
        Position = UDim2.fromOffset(10,0), Size = UDim2.new(0.42,0,1,0),
        BackgroundTransparency = 1, Text = labelText,
        TextColor3 = Color3.fromRGB(225,226,232), Font = Enum.Font.GothamMedium,
        TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left
    }, r)
    local b = make("TextButton", {
        Position = UDim2.new(0.43,0,0.5,-13), Size = UDim2.new(0.55,-8,0,26),
        BackgroundColor3 = Color3.fromRGB(48,49,57), BorderSizePixel = 0,
        Text = tostring(state[key]), TextColor3 = Color3.fromRGB(236,237,241),
        Font = Enum.Font.GothamMedium, TextSize = 8, AutoButtonColor = false
    }, r)
    round(b,6)
    b.Activated:Connect(function()
        closeDropdown()
        local maxHeight = math.min(#options * 30 + 8, math.floor((Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y or 600) * 0.45))
        local abs = b.AbsolutePosition
        local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
        local x = math.clamp(abs.X, 4, math.max(4, view.X - 174))
        local y = abs.Y + b.AbsoluteSize.Y + 3
        if y + maxHeight > view.Y - 4 then y = math.max(4, abs.Y - maxHeight - 3) end
        dropdownPopup = make("Frame", {
            Name = "DropdownPopup", Position = UDim2.fromOffset(x,y),
            Size = UDim2.fromOffset(170,maxHeight), BackgroundColor3 = Color3.fromRGB(27,28,33),
            BorderSizePixel = 0, ZIndex = 200, Active = true
        }, gui)
        round(dropdownPopup,7); outline(dropdownPopup,0.12)
        local list = make("ScrollingFrame", {
            Position = UDim2.fromOffset(4,4), Size = UDim2.new(1,-8,1,-8),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            CanvasSize = UDim2.new(0,0,0,#options*30), AutomaticCanvasSize = Enum.AutomaticSize.None,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 201
        }, dropdownPopup)
        make("UIListLayout", {Padding = UDim.new(0,3), SortOrder = Enum.SortOrder.LayoutOrder}, list)
        for i, option in ipairs(options) do
            local item = make("TextButton", {
                Size = UDim2.new(1,-2,0,27), BackgroundColor3 = tostring(state[key]) == tostring(option) and Color3.fromRGB(73,75,86) or Color3.fromRGB(42,43,50),
                BorderSizePixel = 0, Text = tostring(option), TextColor3 = Color3.fromRGB(238,239,243),
                Font = Enum.Font.GothamMedium, TextSize = 9, LayoutOrder = i, ZIndex = 202,
                AutoButtonColor = false
            }, list)
            round(item,5)
            item.Activated:Connect(function()
                state[key] = option
                b.Text = tostring(option)
                closeDropdown()
                if callback then
                    local ok, err = pcall(callback, option)
                    if not ok then addStatus(labelText .. " error: " .. tostring(err)) end
                end
            end)
        end
    end)
end


-- Dump-grounded progression helpers. All module calls are protected so a missing
-- module/data shape cannot prevent the V3 GUI from loading.
local savedReturnCFrame = nil
local function saveReturnPoint()
    local ch = player.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if root then savedReturnCFrame = root.CFrame; addStatus("Return point saved") else addStatus("Return point: character root unavailable") end
end
local function returnToSavedPoint()
    if not state.returnAfterBuy or not savedReturnCFrame then return end
    local ch = player.Character
    if ch and ch:FindFirstChild("HumanoidRootPart") then
        pcall(function() ch:PivotTo(savedReturnCFrame) end)
    end
end
local function getMineData()
    if not gameState or type(gameState.GetData2) ~= "function" then return nil end
    local ok, data = pcall(function() return gameState.GetData2() end)
    return ok and data and data.MineGame or nil
end
local function getMoney(mine)
    if not mine then return 0 end
    return tonumber(mine.Money or mine.Cash or mine.Coins or mine.Sheckles) or 0
end
local function runAutoPickaxe()
    if not (mineConfig and mineStock) then addStatus("Auto Pickaxe: config/stock module unavailable"); return end
    local mine = getMineData(); if not mine then return end
    local unlocked = mine.UnlockedZones or {}
    local money = getMoney(mine)
    local bestIndex, bestMult = nil, -math.huge
    for i, def in ipairs(mineConfig.Pickaxes or {}) do
        local okFree, free = pcall(function() return mineConfig.IsPickaxeFree(def) end)
        local filter = string.lower(tostring(state.pickaxeFilter or "Best Affordable"))
        local name = string.lower(tostring(def.Name or ""))
        local matches = filter == "best affordable" or filter == "all" or string.find(name, filter, 1, true) ~= nil
        local zoneOK = not def.ZoneReq or unlocked[def.ZoneReq] == true
        local owned = tonumber((mine.Pickaxes or {})[def.Name]) or 0
        local stockOK = false
        pcall(function() stockOK = (mineStock.GetRemaining(mine, def.Name) or 0) > 0 end)
        local cost = tonumber(def.Cost) or math.huge
        local mult = tonumber(def.Multiplier) or 0
        if okFree and not free and not def.RobuxOnly and type(def.Stock)=="table" and matches and zoneOK and owned <= 0 and stockOK and cost <= money and mult > bestMult then
            bestIndex, bestMult = i, mult
        end
    end
    if bestIndex then
        if sendGameEvent("MineBuyPickaxe", bestIndex) then task.delay(0.8, returnToSavedPoint) end
    end
end
local function runAutoSkills()
    if not mineConfig then addStatus("Auto Skill Tree: MineConfig unavailable"); return end
    local mine = getMineData(); if not mine then return end
    local unlocked = mine.UnlockedZones or {}
    local skills = mine.Skills or {}
    local money = getMoney(mine)
    for _, zone in ipairs(mineConfig.ZoneKeys or {}) do
        local zoneKey = type(zone)=="table" and (zone.Key or zone.Id or zone.Name) or zone
        if zoneKey and unlocked[zoneKey] then
            local okNodes, nodes = pcall(function() return mineConfig.GetSkillNodes(zoneKey) end)
            if okNodes and type(nodes)=="table" then
                for _, node in ipairs(nodes) do
                    local tree = skills[zoneKey] or {}
                    local okCheck, eligible = pcall(function()
                        if mineConfig.IsSkillNodeMaxed(tree,node) or not mineConfig.IsSkillNodeOpen(tree,node) then return false end
                        local level = tonumber(tree[node.Family]) or 0
                        local maxLevel = mineConfig.GetSkillMax(zoneKey,node.Family)
                        if maxLevel and level >= maxLevel then return false end
                        local cost = mineConfig.GetSkillCost(zoneKey, level, node.Family)
                        return type(cost)=="number" and cost <= money
                    end)
                    if okCheck and eligible then
                        if sendGameEvent("MineBuySkill", zoneKey, node.Family, node.Id) then
                            addStatus("Skill upgrade requested: "..tostring(zoneKey).." / "..tostring(node.Family))
                            task.delay(0.8, returnToSavedPoint)
                            return -- one at a time; re-read server data on next cycle
                        end
                    end
                end
            end
        end
    end
end
local function runAutoCore()
    if not mineConfig then return end
    local mine = getMineData(); if not mine then return end
    local money = getMoney(mine)
    for _, node in ipairs(mineConfig.CoreNodes or {}) do
        local eligible = false
        pcall(function()
            if mineConfig.IsCoreNodeOpen(mine,node) and not mineConfig.IsCoreNodeMaxed(mine,node) then
                local def = mineConfig.CoreUpgradeById[node.Family]
                local level = mineConfig.GetCoreLevel(mine,node.Family)
                local cost = def and type(def.Cost)=="function" and def.Cost(level) or nil
                eligible = type(cost)=="number" and cost <= money
            end
        end)
        if eligible then
            local def = mineConfig.CoreUpgradeById[node.Family]
            if def and def.Event and sendGameEvent(def.Event) then task.delay(0.8, returnToSavedPoint); return end
        end
    end
end
local function runAutoSlots()
    local mine = getMineData(); if not mine then return end
    local holders = mine.Holders or {}
    -- The native game UI sends MineUpgradeCharacter(slotKey) for empty, unlocked-next slots.
    -- Only use keys explicitly listed in config; never guess slot names.
    local slots = mineConfig and (mineConfig.HolderSlots or mineConfig.CharacterSlots)
    if type(slots) ~= "table" then addStatus("Auto Slots: slot config not exposed; no guessed event sent"); return end
    for _, slot in ipairs(slots) do
        local key = type(slot)=="table" and slot.Key or slot
        local def = type(slot)=="table" and slot or nil
        if key and def and def.Unlocked and not (holders[key] and holders[key].CharName) then
            if sendGameEvent("MineUpgradeCharacter", key) then task.delay(0.8, returnToSavedPoint); return end
        end
    end
end
local function inspectZoneResearch()
    addStatus("Zone Research is quest/objective progression; dump does not expose a confirmed generic quest-complete event. Open native quest/research UI to inspect objectives.")
    local hits = 0
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local t = string.lower(tostring(obj.Name).." "..(obj:IsA("TextButton") and tostring(obj.Text) or ""))
            if string.find(t,"research",1,true) or string.find(t,"quest",1,true) or string.find(t,"zone",1,true) then
                hits += 1; if hits <= 5 then addStatus("Research control: "..obj:GetFullName()) end
            end
        end
    end
    if hits == 0 then addStatus("No visible quest/research/zone control found") end
end

local Main = makePage("MAIN")
local Mine = makePage("MINE")
local Sell = makePage("SELL")
local Gear = makePage("GEAR")
local Upgrades = makePage("UPGRADES")
local Utility = makePage("UTILITY")
local Status = makePage("STATUS")
local Settings = makePage("SETTINGS")

for i,n in ipairs({"MAIN","MINE","SELL","GEAR","UPGRADES","UTILITY","STATUS","SETTINGS"}) do makeTab(n,i) end

section(Main, "QUICK ACTIONS", 1)
buttonRow(Main, "Collect Chest", 2, function()
    sendGameEvent("MineTakeChest")
end)
buttonRow(Main, "Open Sell UI", 3, function()
    toggleNativeFrame("SellFrame", true, "Sell UI")
end)
buttonRow(Main, "Open Auto Sell UI", 4, function()
    toggleNativeFrame("AutoSellFrame", true, "Auto Sell UI")
end)
buttonRow(Main, "Open Store UI", 5, function()
    toggleNativeFrame("StoreFrame", true, "Store UI")
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
dropdownRow(Main, "Equip Best Delay (sec)", 13, "equipDelay", {"5","10","15","30","60","120"}, function(v)
    state.equipDelay = tonumber(v) or 30
    addStatus("Equip delay set to " .. tostring(state.equipDelay) .. " seconds")
end)
dropdownRow(Main, "Collect Chest Delay (sec)", 14, "collectDelay", {"3","5","10","15","30","60"}, function(v)
    state.collectDelay = tonumber(v) or 10
    addStatus("Chest collect delay set to " .. tostring(state.collectDelay) .. " seconds")
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
dropdownRow(Sell, "Auto Sell Delay (sec)", 4, "sellDelay", {"1","3","5","10","15","30","60","120"}, function(v)
    state.sellDelay = tonumber(v) or 60
    addStatus("Auto Sell delay set to " .. tostring(state.sellDelay) .. " seconds")
end)
dropdownRow(Sell, "Teleport Before Sell", 5, "autoSellTeleport", {true, false}, function(v)
    state.autoSellTeleport = v
    addStatus("Teleport before sell: " .. (v and "ON" or "OFF"))
end)
buttonRow(Sell, "Teleport to Sell Stand", 4, function()
    if moveToSellStand() then addStatus("Moved beside Sell Stand NPC") end
end)
buttonRow(Sell, "Open Native Sell Frame", 5, function()
    toggleNativeFrame("SellFrame", true, "Sell UI")
end)
buttonRow(Sell, "Sell All Ores", 6, function()
    performSell("Manual Sell")
end)
buttonRow(Sell, "Inspect Auto Sell Controls", 7, function()
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
    sendGameEvent("MineEquipBest")
end)
buttonRow(Gear, "Open Store / Pickaxe UI", 3, function()
    toggleNativeFrame("StoreFrame", true, "Store/Pickaxe UI")
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

toggleRow(Gear, "Auto Buy Pickaxes", 5, "autoBuyPickaxes", function(on) addStatus("Auto Buy Pickaxes "..(on and "enabled" or "disabled")) end)
dropdownRow(Gear, "Pickaxe Filter", 6, "pickaxeFilter", {"Best Affordable","All","stone","iron","gold","diamond","mythic"}, function(v) state.pickaxeFilter=v; addStatus("Pickaxe filter: "..tostring(v)) end)
buttonRow(Gear, "Buy Best Affordable Pickaxe Now", 7, runAutoPickaxe)

section(Upgrades, "CHARACTER UPGRADES", 1)
make("TextLabel", {
    Size = UDim2.new(1,0,0,34), BackgroundTransparency = 1,
    Text = "Auto Upgrade sends the game's confirmed MineUpgradeCharacter event for occupied slots. Costs and server acceptance are controlled by the game.",
    TextColor3 = Color3.fromRGB(166,168,177), Font = Enum.Font.Gotham,
    TextSize = 8, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 2
}, Upgrades)
toggleRow(Upgrades, "Auto Upgrade Characters", 3, "autoUpgradeCharacters", function(on)
    addStatus("Auto Upgrade Characters " .. (on and "enabled" or "disabled"))
end)
dropdownRow(Upgrades, "Upgrade Delay (sec)", 4, "upgradeDelay", {"2","5","10","15","30","60"}, function(v)
    state.upgradeDelay = tonumber(v) or 10
    addStatus("Character upgrade delay set to " .. tostring(state.upgradeDelay) .. " seconds")
end)
toggleRow(Upgrades, "Auto Upgrade Skill Tree", 6, "autoUpgradeSkills", function(on) addStatus("Auto Skill Tree "..(on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Upgrade Core", 7, "autoUpgradeCore", function(on) addStatus("Auto Core "..(on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Buy Miner Slots", 8, "autoBuySlots", function(on) addStatus("Auto Miner Slots "..(on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Research Zone (quest inspect)", 9, "autoResearchZone", function(on) addStatus(on and "Zone quest inspection enabled; no unverified quest event will be fired" or "Zone quest inspection disabled") end)
buttonRow(Upgrades, "Save Return Point Here", 10, saveReturnPoint)
toggleRow(Upgrades, "Return After Auto Buy", 11, "returnAfterBuy", function(on) addStatus("Return after action "..(on and "enabled" or "disabled")) end)
buttonRow(Upgrades, "Inspect Zone Research / Quest", 12, inspectZoneResearch)
buttonRow(Upgrades, "Open Store UI", 4, function()
    toggleNativeFrame("StoreFrame", true, "Store UI")
end)
buttonRow(Upgrades, "Open Skill Tree UI", 5, function()
    local found = false
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and string.find(string.lower(obj.Name), "skill") then
            pcall(function() obj:Activate() end)
            addStatus("Activated possible skill-tree control: " .. obj:GetFullName())
            found = true
            break
        end
    end
    if not found then addStatus("Skill Tree: native button not identified; open it in-game manually") end
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
    closeDropdown()
    window.Visible = false
    reopen.Visible = true
end)
buttonRow(Settings, "Stop All Toggles", 3, function()
    state.autoSwing = false
    state.autoCollect = false
    state.autoSell = false
    state.autoEquipBest = false
    state.autoUpgradeCharacters = false
    state.fpsBoost = false
    state.antiAfk = false
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

reopen = make("TextButton", {
    Name = "Reopen",
    Size = UDim2.fromOffset(142,42),
    Position = UDim2.new(0.5,-71,0,8),
    BackgroundColor3 = Color3.fromRGB(30,31,37),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Text = "HAIMIYACH",
    TextColor3 = Color3.fromRGB(245,246,249),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    Visible = false,
    Active = true,
    ZIndex = 100
}, gui)
round(reopen,15); outline(reopen,0.25)
reopen.Activated:Connect(function()
    window.Visible = true
    reopen.Visible = false
end)
close.Activated:Connect(function()
    closeDropdown()
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
        if state.autoCollect and (os.clock() - (connections.lastCollect or 0)) >= (tonumber(state.collectDelay) or 10) then
            connections.lastCollect = os.clock()
            sendGameEvent("MineTakeChest")
        end
        if state.autoSell and (os.clock() - (connections.lastSell or 0)) >= (tonumber(state.sellDelay) or 60) then
            connections.lastSell = os.clock()
            performSell("Auto Sell")
        end
        if state.autoEquipBest and (os.clock() - (connections.lastEquip or 0)) >= (tonumber(state.equipDelay) or 30) then
            connections.lastEquip = os.clock()
            sendGameEvent("MineEquipBest")
        end
        if state.autoUpgradeCharacters and (os.clock() - (connections.lastCharacterUpgrade or 0)) >= (tonumber(state.upgradeDelay) or 10) then
            connections.lastCharacterUpgrade = os.clock()
            if gameState and type(gameState.GetData2) == "function" then
                local okData, data = pcall(function() return gameState.GetData2() end)
                local mine = okData and data and data.MineGame
                local slots = mine and (mine.Characters or mine.CharacterSlots or mine.Holders)
                if type(slots) == "table" then
                    local sent = 0
                    for key, slot in pairs(slots) do
                        if type(slot) == "table" and (slot.CharName or slot.Character or slot.ItemName) then
                            -- The game UI uses MineUpgradeCharacter(slotKey, statName).
                            for _, statName in ipairs({"Damage", "Speed", "MineSpeed"}) do
                                if sendGameEvent("MineUpgradeCharacter", key, statName) then sent = sent + 1 end
                            end
                        end
                    end
                    if sent == 0 then addStatus("Auto Upgrade: no compatible occupied character slots found in current data") end
                else
                    addStatus("Auto Upgrade: character slot data shape not verified; no upgrade sent")
                end
            else
                addStatus("Auto Upgrade: GameState unavailable")
            end
        end
        if state.autoBuyPickaxes and (os.clock() - (connections.lastPickaxe or 0)) >= 5 then
            connections.lastPickaxe = os.clock(); pcall(runAutoPickaxe)
        end
        if state.autoUpgradeSkills and (os.clock() - (connections.lastSkills or 0)) >= (tonumber(state.researchDelay) or 3) then
            connections.lastSkills = os.clock(); pcall(runAutoSkills)
        end
        if state.autoUpgradeCore and (os.clock() - (connections.lastCore or 0)) >= (tonumber(state.researchDelay) or 3) then
            connections.lastCore = os.clock(); pcall(runAutoCore)
        end
        if state.autoBuySlots and (os.clock() - (connections.lastSlots or 0)) >= 5 then
            connections.lastSlots = os.clock(); pcall(runAutoSlots)
        end
        if state.autoResearchZone and (os.clock() - (connections.lastZoneInspect or 0)) >= 15 then
            connections.lastZoneInspect = os.clock(); pcall(inspectZoneResearch)
        end
    end
end)

-- Initial status
addStatus("V3 loaded. Auto Sell now teleports to Sell Stand before selling; delays are configurable.")
addStatus("Auto Buy Pickaxe/Skill Tree still requires live item/node identifiers; no guessed purchases are sent.")
addStatus("PlaceId=" .. tostring(game.PlaceId) .. " (expected " .. tostring(PLACE_ID) .. ")")
if game.PlaceId ~= PLACE_ID then addStatus("WARNING: different PlaceId; game events may not match this dump") end
selectPage("MAIN")
task.defer(function()
    if statusText and statusText.Parent then
        statusText.Text = "Tap Run Diagnostics.\n\nDump-confirmed paths:\n• ReplicatedStorage.Remotes.MineFX\n• workspace.MineWorld.Plots\n• PlayerGui.MineGui.SellFrame\n• PlayerGui.MineGui.AutoSellFrame\n• PlayerGui.MineGui.ChestFrame\n• PlayerGui.MineGui.StoreFrame\n\nAuto Upgrade Characters requires the live character-slot data shape to match the dump; skill-tree auto-buy and pickaxe auto-buy are not falsely marked as active without validated node/item identifiers. Filters remain UI settings until server-side filter API is verified."
    end
end)
print("[HAIMIYACH] My Anime Mine hub loaded")
