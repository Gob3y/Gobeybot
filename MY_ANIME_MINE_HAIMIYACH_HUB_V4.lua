--[[
    MY ANIME MINE | HAIMIYACH HUB V4
    Dump-grounded expanded utility UI for Roblox My Anime Mine.
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
local gameState, clientUtility, mineInventory, mineConfig, items, mineStock
pcall(function() gameState = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("GameState")) end)
pcall(function() clientUtility = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("ClientUtility")) end)
pcall(function() mineInventory = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineInventory")) end)
pcall(function() mineConfig = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineConfig")) end)
pcall(function() items = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("Items")) end)
pcall(function() mineStock = require(replicatedStorage:WaitForChild("Modules"):WaitForChild("MineStock")) end)

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
    equipDelay = 30,
    collectDelay = 10,
    autoSellTeleport = true,
    autoBuyPickaxes = false,
    autoBuyCore = false,
    autoBuySkills = false,
    autoFarm = false,
    nodePriority = "Nearest",
    pickaxeFilter = "All",
    autoSellRarityFilter = "All",
    itemTypeFilter = "Ore",
    autoAffordableUpgrades = false,
    autoBuyZones = false,
    noGameplayPaused = false,
    walkSpeedBoost = false,
    airGlide = false,
    wallPhase = false,
    endlessLeap = false,
    instantPrompt = false,
    noRender = false,
    autoReconnect = false,
    upgradeBuyDelay = 5,
    pickaxeBuyDelay = 10,
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
        local kindOk = state.itemTypeFilter == "All" or state.itemTypeFilter == "Ore" and entry.Kind == "Ore" or state.itemTypeFilter == entry.Kind
        local worth = tonumber(entry.Worth) or 0
        local keepOk = worth < (tonumber(state.keepAboveValue) or 0) or (tonumber(state.keepAboveValue) or 0) <= 0
        local rarity = entry.Rarity
        if rarity == nil and items and type(items.GetItemData) == "function" and entry.Name then
            local okItem, itemData = pcall(function() return items.GetItemData(entry.Name) end)
            if okItem and type(itemData) == "table" then rarity = itemData.Rarity or itemData.RarityName end
        end
        local rarityOk = state.autoSellRarityFilter == "All" or rarity == nil or tostring(rarity):lower() == tostring(state.autoSellRarityFilter):lower()
        if kindOk and keepOk and rarityOk and (entry.SellCount or entry.Count or 0) > 0
            and worth > 0 and entry.Key then
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
    if state.sellAtCount and tonumber(state.sellAtCount) and tonumber(state.sellAtCount) > 0 then
        local _, mine = getPlayerData()
        local bagCount = 0
        if mine and mineInventory and type(mineInventory.Collect) == "function" then
            local okCount, entries = pcall(function() return mineInventory.Collect(mine, "All", mineInventory.KindOrder.OreFirst) end)
            if okCount and type(entries) == "table" then for _, entry in ipairs(entries) do bagCount += tonumber(entry.SellCount or entry.Count or 0) or 0 end end
        end
        if bagCount < tonumber(state.sellAtCount) then addStatus(label .. ": waiting for item count threshold (" .. bagCount .. "/" .. tostring(state.sellAtCount) .. ")"); return false end
    end
    local ok = sendGameEvent("MineSellItems", keys)
    if ok then addStatus(label .. ": request sent for " .. #keys .. " ore stacks") end
    return ok
end

-- Dump-grounded purchasing helpers. These use the same config gates as native UI.
local function getPlayerData()
    if not gameState or type(gameState.GetData2) ~= "function" then return nil, nil end
    local ok, data = pcall(function() return gameState.GetData2() end)
    if not ok or type(data) ~= "table" then return nil, nil end
    return data, data.MineGame
end

local function tryBuyPickaxes()
    local data, mine = getPlayerData()
    if not data or not mine or not mineConfig or type(mineConfig.Pickaxes) ~= "table" then
        addStatus("Auto Pickaxe: game data/config unavailable"); return 0
    end
    local money = tonumber(data.Money) or 0
    local count = 0
    for index, def in ipairs(mineConfig.Pickaxes) do
        if type(def) == "table" and not (mineConfig.IsPickaxeFree and mineConfig.IsPickaxeFree(def))
            and not def.RobuxOnly and type(def.Stock) == "table"
            and (state.pickaxeFilter == "All" or string.find(string.lower(tostring(def.Name)), string.lower(tostring(state.pickaxeFilter)), 1, true))
            and (mine.UnlockedZones or {})[def.ZoneReq]
            and money >= (tonumber(def.Cost) or math.huge) then
            local stock = nil
            if mineStock and type(mineStock.GetRemaining) == "function" then
                local ok, value = pcall(function() return mineStock.GetRemaining(data, def.Name) end)
                if ok then stock = value end
            end
            if stock == nil or stock > 0 then
                if sendGameEvent("MineBuyPickaxe", index) then
                    count += 1
                    money -= tonumber(def.Cost) or 0
                    task.wait(0.35)
                end
            end
        end
    end
    addStatus("Auto Pickaxe pass finished; requests=" .. count)
    return count
end

local function tryBuyCoreUpgrades()
    local data, mine = getPlayerData()
    if not data or not mine or not mineConfig or type(mineConfig.CoreNodes) ~= "table" then
        addStatus("Core upgrades: config/data unavailable"); return 0
    end
    local money = tonumber(data.Money) or 0
    local bought = 0
    local boughtFamilies = {}
    for _, node in ipairs(mineConfig.CoreNodes) do
        local def = mineConfig.CoreUpgradeById and mineConfig.CoreUpgradeById[node.Family]
        if not boughtFamilies[node.Family] and def and mineConfig.IsCoreNodeOpen and mineConfig.IsCoreNodeMaxed
            and not mineConfig.IsCoreNodeMaxed(mine, node) and mineConfig.IsCoreNodeOpen(mine, node) then
            local level = 0
            pcall(function() level = mineConfig.GetCoreLevel(mine, node.Family) end)
            local okCost, cost = pcall(function() return def.Cost(level) end)
            if okCost and type(cost) == "number" and money >= cost and level < (tonumber(def.Max) or math.huge) then
                if sendGameEvent(def.Event) then
                    bought += 1; money -= cost
                    -- One request per family per pass; live data refreshes levels afterward.
                    boughtFamilies[node.Family] = true
                    task.wait(0.35)
                end
            end
        end
    end
    addStatus("Core upgrade pass finished; requests=" .. bought)
    return bought
end

local function tryBuyZoneSkills()
    local data, mine = getPlayerData()
    if not data or not mine or not mineConfig or type(mineConfig.ZoneKeys) ~= "table" then
        addStatus("Zone skills: config/data unavailable"); return 0
    end
    local money = tonumber(data.Money) or 0
    local bought = 0
    for _, zone in ipairs(mineConfig.ZoneKeys) do
        if (mine.UnlockedZones or {})[zone] then
            local skills = (mine.Skills or {})[zone] or {}
            local nodes = {}
            local okNodes = pcall(function() nodes = mineConfig.GetSkillNodes(zone) end)
            if okNodes and type(nodes) == "table" then
                for _, node in ipairs(nodes) do
                    local okNode, canBuy = pcall(function()
                        return not mineConfig.IsSkillNodeMaxed(skills, node) and mineConfig.IsSkillNodeOpen(skills, node)
                    end)
                    if okNode and canBuy then
                        local level = tonumber(skills[node.Family]) or 0
                        local okCost, cost = pcall(function() return mineConfig.GetSkillCost(zone, level, node.Family) end)
                        local powerAllowed = true
                        if type(mineConfig.GetSkillPowerReq) == "function" then
                            local okReq, req = pcall(function() return mineConfig.GetSkillPowerReq(zone, node.Family, level + 1) end)
                            if okReq and type(req) == "number" and type(mineConfig.GetTeamPower) == "function" and items and type(items.GetItemData) == "function" then
                                local okPower, power = pcall(function() return mineConfig.GetTeamPower(mine, items.GetItemData) end)
                                if okPower and type(power) == "number" and power < req then powerAllowed = false end
                            end
                        end
                        if okCost and type(cost) == "number" and money >= cost and powerAllowed then
                            if sendGameEvent("MineBuySkill", zone, node.Family, node.Id) then
                                bought += 1; money -= cost
                                skills[node.Family] = level + 1
                                task.wait(0.35)
                            end
                        end
                    end
                end
            end
        end
    end
    addStatus("Zone skill pass finished; requests=" .. bought)
    return bought
end

local function tryUpgradeOccupiedSlots()
    local _, mine = getPlayerData()
    if not mine or type(mine.Holders) ~= "table" then
        addStatus("Character upgrade: MineGame.Holders unavailable"); return 0
    end
    local sent = 0
    for key, holder in pairs(mine.Holders) do
        if type(holder) == "table" and holder.CharName then
            -- Native stat UI confirms these names and the (slotKey, statName) signature.
            for _, statName in ipairs({"Damage", "Speed", "MineSpeed"}) do
                if sendGameEvent("MineUpgradeCharacter", key, statName) then sent += 1; task.wait(0.25) end
            end
        end
    end
    addStatus("Character upgrade pass finished; requests=" .. sent)
    return sent
end

local function activateVisibleButtonMatching(words)
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible and not obj:GetAttribute("HAIMIYACH_SKIP") then
            local textValue = obj:IsA("TextButton") and string.lower(obj.Text or "") or ""
            local nameValue = string.lower(obj.Name or "")
            local combined = textValue .. " " .. nameValue
            for _, word in ipairs(words) do
                if string.find(combined, string.lower(word), 1, true) then
                    local ok = pcall(function() obj:Activate() end)
                    if ok then addStatus("Native action activated: " .. obj:GetFullName()); return true end
                end
            end
        end
    end
    addStatus("Native purchase control not identified; no guessed remote sent")
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
toggleRow(Main, "Auto Farm Mines", 10, "autoFarm", function(on) addStatus("Auto Farm uses equipped Tool: " .. (on and "enabled" or "disabled")) end)
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
    addStatus("Node Priority preference set to " .. v .. "; dump does not expose a verified public target-selection API")
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
    state.itemTypeFilter = v; addStatus("Sell item filter selected: " .. v)
end)
dropdownRow(Sell, "Rarity", 3, "sellRarity", {"All","Common","Uncommon","Rare","Epic","Legendary","Mythic"}, function(v)
    state.autoSellRarityFilter = v; addStatus("Sell rarity selected: " .. v)
end)
dropdownRow(Sell, "Auto Sell Delay (sec)", 4, "sellDelay", {"1","3","5","10","15","30","60","120"}, function(v)
    state.sellDelay = tonumber(v) or 60
    addStatus("Auto Sell delay set to " .. tostring(state.sellDelay) .. " seconds")
end)
dropdownRow(Sell, "Sell At Item Count", 8, "sellAtCount", {"0","10","25","50","100","250","500"}, function(v)
    state.sellAtCount = tonumber(v) or 0; addStatus("Sell count threshold set to " .. tostring(state.sellAtCount) .. " (0 = off)")
end)
dropdownRow(Sell, "Keep Above Value", 9, "keepAboveValue", {"0","100","1000","10000","100000","1000000"}, function(v)
    state.keepAboveValue = tonumber(v) or 0; addStatus("Keep Above Value set to " .. tostring(state.keepAboveValue))
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
buttonRow(Sell, "One Tap Cash Out / Sell Ores", 6, function()
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
toggleRow(Gear, "Auto Buy Pickaxes", 5, "autoBuyPickaxes", function(on) addStatus("Auto Buy Pickaxes " .. (on and "enabled" or "disabled")) end)
dropdownRow(Gear, "Pickaxe Filter", 6, "pickaxeFilter", {"All","Wood","Stone","Iron","Gold","Ruby","Diamond"}, function(v)
    state.pickaxeFilter = v; addStatus("Pickaxe filter set to " .. v)
end)
dropdownRow(Gear, "Pickaxe Buy Delay (sec)", 7, "pickaxeBuyDelay", {"3","5","10","15","30","60"}, function(v)
    state.pickaxeBuyDelay = tonumber(v) or 10; addStatus("Pickaxe buy delay set to " .. tostring(state.pickaxeBuyDelay))
end)

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
toggleRow(Upgrades, "Auto Buy Affordable Upgrades", 5, "autoAffordableUpgrades", function(on) addStatus("Auto Affordable Upgrades " .. (on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Buy Core Upgrades", 5, "autoBuyCore", function(on) addStatus("Auto Core Upgrades " .. (on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Buy Zone Skills", 6, "autoBuySkills", function(on) addStatus("Auto Zone Skills " .. (on and "enabled" or "disabled")) end)
toggleRow(Upgrades, "Auto Buy Zones (native controls)", 7, "autoBuyZones", function(on) addStatus("Auto Buy Zones " .. (on and "enabled" or "disabled") .. "; only visible native purchase buttons are considered") end)
dropdownRow(Upgrades, "Research Delay (sec)", 8, "upgradeBuyDelay", {"1","2","3","5","10","15","30","60"}, function(v)
    state.upgradeBuyDelay = tonumber(v) or 5; addStatus("Research delay set to " .. tostring(state.upgradeBuyDelay) .. " seconds")
end)
buttonRow(Upgrades, "Buy Gate Research (native UI)", 9, function() activateVisibleButtonMatching({"gate research", "research gate"}) end)
buttonRow(Upgrades, "Unlock Next Zone (native UI)", 10, function() activateVisibleButtonMatching({"unlock zone", "buy zone", "unlock next", "enter zone"}) end)
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
    connections.visualCache = connections.visualCache or {}
    local changed = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            if on then
                if not connections.visualCache[d] then connections.visualCache[d] = {} end
                if connections.visualCache[d].Enabled == nil then connections.visualCache[d].Enabled = d.Enabled end
                pcall(function() d.Enabled = false end)
            elseif connections.visualCache[d] and connections.visualCache[d].Enabled ~= nil then
                pcall(function() d.Enabled = connections.visualCache[d].Enabled end)
                connections.visualCache[d].Enabled = nil
            end
            changed += 1
        elseif d:IsA("BasePart") and on and d.Material == Enum.Material.Neon then
            if not connections.visualCache[d] then connections.visualCache[d] = {} end
            if connections.visualCache[d].Material == nil then connections.visualCache[d].Material = d.Material end
            pcall(function() d.Material = Enum.Material.SmoothPlastic end)
            changed += 1
        elseif d:IsA("BasePart") and not on and connections.visualCache[d] and connections.visualCache[d].Material ~= nil then
            pcall(function() d.Material = connections.visualCache[d].Material end)
            connections.visualCache[d].Material = nil
        end
    end
    addStatus("FPS visual toggle applied to " .. changed .. " instances; local visual optimization only")
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
buttonRow(Utility, "No Gameplay Paused (inspect only)", 4, function()
    local found = 0
    for _, d in ipairs(playerGui:GetDescendants()) do
        local n = string.lower(d.Name)
        if string.find(n, "pause", 1, true) or string.find(n, "paused", 1, true) then found += 1; addStatus("Pause-related UI: " .. d:GetFullName()) end
    end
    addStatus("Pause UI elements found=" .. found .. "; no server pause enforcement bypass guessed")
end)
buttonRow(Utility, "Restore Visual Effects", 5, function()
    for inst, props in pairs(connections.visualCache or {}) do
        if inst and inst.Parent then for prop, value in pairs(props) do pcall(function() inst[prop] = value end) end end
    end
    if connections.renderDisabled and game:GetService("RunService").Set3dRenderingEnabled then pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(true) end) end
    connections.renderDisabled = false
    addStatus("Cached visual settings restored where possible")
end)
toggleRow(Utility, "Walk Speed Boost", 5, "walkSpeedBoost", function(on)
    local char = player.Character; local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if on then connections.originalWalkSpeed = connections.originalWalkSpeed or hum.WalkSpeed; hum.WalkSpeed = 32
        elseif connections.originalWalkSpeed then hum.WalkSpeed = connections.originalWalkSpeed; connections.originalWalkSpeed = nil end
    end
    addStatus("Walk speed boost " .. (on and "enabled locally" or "disabled"))
end)
toggleRow(Utility, "Air Glide", 6, "airGlide", function(on)
    local char = player.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
    if on and root then
        if not connections.glideVelocity then
            local bv = Instance.new("BodyVelocity"); bv.Name = "HAIMIYACH_GlideVelocity"; bv.MaxForce = Vector3.new(0, 1e5, 0); bv.Velocity = Vector3.zero; bv.Parent = root; connections.glideVelocity = bv
        end
    elseif connections.glideVelocity then connections.glideVelocity:Destroy(); connections.glideVelocity = nil end
    addStatus("Air Glide " .. (on and "enabled" or "disabled"))
end)
toggleRow(Utility, "Wall Phase (local collision)", 7, "wallPhase", function(on)
    connections.collisionCache = connections.collisionCache or {}
    local char = player.Character
    if char then for _, d in ipairs(char:GetDescendants()) do if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
        if on then if connections.collisionCache[d] == nil then connections.collisionCache[d] = d.CanCollide end; d.CanCollide = false
        elseif connections.collisionCache[d] ~= nil then d.CanCollide = connections.collisionCache[d]; connections.collisionCache[d] = nil end
    end end end
    addStatus("Wall Phase changed local character collision only")
end)
toggleRow(Utility, "Endless Leap", 8, "endlessLeap", function(on)
    connections.jumpConnection = connections.jumpConnection or nil
    if connections.jumpConnection then connections.jumpConnection:Disconnect(); connections.jumpConnection = nil end
    if on then connections.jumpConnection = UserInputService.JumpRequest:Connect(function()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end) end
    addStatus("Endless Leap " .. (on and "enabled locally" or "disabled"))
end)
toggleRow(Utility, "Instant ProximityPrompt", 9, "instantPrompt", function(on)
    connections.promptCache = connections.promptCache or {}
    local service = game:GetService("ProximityPromptService")
    for _, d in ipairs(Workspace:GetDescendants()) do if d:IsA("ProximityPrompt") then
        if on then if connections.promptCache[d] == nil then connections.promptCache[d] = d.HoldDuration end; pcall(function() d.HoldDuration = 0 end)
        elseif connections.promptCache[d] ~= nil then pcall(function() d.HoldDuration = connections.promptCache[d] end); connections.promptCache[d] = nil end
    end end
    addStatus("Prompt hold duration " .. (on and "set to zero locally" or "restored where possible"))
end)
toggleRow(Utility, "Disable 3D Rendering", 10, "noRender", function(on)
    local rs = game:GetService("RunService")
    if type(rs.Set3dRenderingEnabled) == "function" then
        local ok = pcall(function() rs:Set3dRenderingEnabled(not on) end)
        connections.renderDisabled = on and ok or false
        addStatus(ok and (on and "3D rendering disabled" or "3D rendering enabled") or "Rendering API unavailable in this client")
    else addStatus("Set3dRenderingEnabled unavailable in this client") end
end)
toggleRow(Utility, "Auto Reconnect (teleport failures only)", 11, "autoReconnect", function(on)
    if connections.teleportFailed then connections.teleportFailed:Disconnect(); connections.teleportFailed = nil end
    if on then
        local TeleportService = game:GetService("TeleportService")
        connections.teleportFailed = TeleportService.TeleportInitFailed:Connect(function(plr, result, message)
            if plr == player and state.autoReconnect then
                addStatus("Teleport failed; retrying once: " .. tostring(result))
                task.wait(2); pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
            end
        end)
    end
    addStatus("Auto Reconnect " .. (on and "listening for teleport failures" or "disabled") .. "; does not detect every kick")
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
    state.autoBuyPickaxes = false
    state.autoBuyCore = false
    state.autoBuySkills = false
    state.autoAffordableUpgrades = false
    state.autoBuyZones = false
    state.autoFarm = false
    state.walkSpeedBoost = false
    state.airGlide = false
    state.wallPhase = false
    state.endlessLeap = false
    state.instantPrompt = false
    state.noRender = false
    state.autoReconnect = false
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
            tryUpgradeOccupiedSlots()
        end
        if state.autoBuyPickaxes and (os.clock() - (connections.lastPickaxeBuy or 0)) >= (tonumber(state.pickaxeBuyDelay) or 10) then
            connections.lastPickaxeBuy = os.clock(); tryBuyPickaxes()
        end
        if state.autoBuyCore and (os.clock() - (connections.lastCoreBuy or 0)) >= (tonumber(state.upgradeBuyDelay) or 5) then
            connections.lastCoreBuy = os.clock(); tryBuyCoreUpgrades()
        end
        if state.autoBuySkills and (os.clock() - (connections.lastSkillsBuy or 0)) >= (tonumber(state.upgradeBuyDelay) or 5) then
            connections.lastSkillsBuy = os.clock(); tryBuyZoneSkills()
        end
        if state.autoAffordableUpgrades and (os.clock() - (connections.lastAffordableBuy or 0)) >= (tonumber(state.upgradeBuyDelay) or 5) then
            connections.lastAffordableBuy = os.clock()
            tryBuyCoreUpgrades(); tryBuyZoneSkills(); tryUpgradeOccupiedSlots()
        end
        if state.autoBuyZones and (os.clock() - (connections.lastZoneBuy or 0)) >= 15 then
            connections.lastZoneBuy = os.clock()
            activateVisibleButtonMatching({"unlock zone", "buy zone", "unlock next zone"})
        end
        if state.autoFarm and (os.clock() - lastSwing) >= (tonumber(state.swingDelay) or 0.5) then
            lastSwing = os.clock()
            local character = player.Character
            local tool = character and character:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    end
end)

-- Initial status
addStatus("V4 loaded. Added dump-grounded pickaxe/core/zone-skill buying, affordability loops, and mobile utility controls.")
addStatus("Zone unlock/gate controls use visible native UI only; unknown remote names are not guessed.")
addStatus("PlaceId=" .. tostring(game.PlaceId) .. " (expected " .. tostring(PLACE_ID) .. ")")
if game.PlaceId ~= PLACE_ID then addStatus("WARNING: different PlaceId; game events may not match this dump") end
selectPage("MAIN")
task.defer(function()
    if statusText and statusText.Parent then
        statusText.Text = "Tap Run Diagnostics.\n\nDump-confirmed paths:\n• ReplicatedStorage.Remotes.MineFX\n• workspace.MineWorld.Plots\n• PlayerGui.MineGui.SellFrame\n• PlayerGui.MineGui.AutoSellFrame\n• PlayerGui.MineGui.ChestFrame\n• PlayerGui.MineGui.StoreFrame\n\nPickaxe/core/zone skill purchase uses MineConfig checks from dump. Node priority, advanced sell filters, gate unlock and server-validated movement may vary by live update. Runtime execution has not been tested in Delta."
    end
end)
print("[HAIMIYACH] My Anime Mine hub loaded")
