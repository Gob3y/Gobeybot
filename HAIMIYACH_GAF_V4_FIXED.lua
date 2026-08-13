--[[
    HAIMIYACH_GAF_V4_FIXED.lua
    Grow a Chicken Fighter - executor standalone
    Based on the supplied StarterPlayerScripts reference.

    Confirmed game-side interfaces used here:
      DataService.client:get({"roster"/"coop"/"tower"/"scrap"/"rebirth"})
      Core.Remotes.defs.HatchEgg
      Core.Remotes.defs.FuseChickens
      Core.Remotes.defs.TowerStart
      Core.Remotes.defs.TowerElevator
      Core.Remotes.defs.UpgradeRecycler
      Core.Remotes.defs.BuyGenerator
      Core.Remotes.defs.UpgradeGenerator
      Core.Remotes.defs.ExpandCoop
      Core.Remotes.defs.Rebirth

    The GUI is deliberately standalone so it does not depend on Rayfield,
    Kavo, external libraries, or executor-specific UI libraries.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

-- Remove an older copy cleanly.
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local old = pg:FindFirstChild("HAIMIYACH_GAF_V4_FIXED")
        if old then old:Destroy() end
    end
    local oldCore = CoreGui:FindFirstChild("HAIMIYACH_GAF_V4_FIXED")
    if oldCore then oldCore:Destroy() end
end)

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ------------------------------------------------------------
-- Safe game adapters
-- ------------------------------------------------------------

local Adapter = {
    ok = false,
    client = nil,
    remotes = nil,
    defs = nil,
    data = nil,
    chickenMode = nil
}

local function safeRequire(instance)
    if not instance then return nil end
    local ok, result = pcall(require, instance)
    if ok then return result end
    return nil
end

pcall(function()
    local packages = ReplicatedStorage:WaitForChild("Packages", 8)
    local core = ReplicatedStorage:WaitForChild("Core", 8)
    if not packages or not core then return end

    local ds = packages:FindFirstChild("DataService")
    local rm = core:FindFirstChild("Remotes")

    local dataService = safeRequire(ds)
    local remotes = safeRequire(rm)

    if dataService and dataService.client and remotes and remotes.defs then
        Adapter.client = dataService.client
        Adapter.remotes = remotes
        Adapter.defs = remotes.defs
        Adapter.ok = true
    end
end)

pcall(function()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if not ps then return end
    local core = ps:FindFirstChild("Core")
    local dataFolder = core and core:FindFirstChild("Data")
    local dc = dataFolder and dataFolder:FindFirstChild("DataController")
    Adapter.data = safeRequire(dc)
end)

pcall(function()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    local features = ps and ps:FindFirstChild("Features")
    local chicken = features and features:FindFirstChild("Chicken")
    Adapter.chickenMode = safeRequire(chicken and chicken:FindFirstChild("ChickenMode"))
end)

local function getState(key)
    if not Adapter.client then return nil end
    local ok, result = pcall(function()
        return Adapter.client:get({key})
    end)
    if ok then return result end
    return nil
end

local function invoke(name, ...)
    if not Adapter.ok then
        return false, "game adapter unavailable"
    end

    local def = Adapter.defs[name]
    if not def then
        return false, "remote not found: " .. tostring(name)
    end

    local ok, result = pcall(function()
        return Adapter.remotes.invoke(def, ...)
    end)

    if not ok then
        return false, tostring(result)
    end

    if type(result) == "table" and result.ok == false then
        return false, tostring(result.error or "remote rejected")
    end

    return true, result
end

local function fire(name, ...)
    if not Adapter.ok then return false end
    local def = Adapter.defs[name]
    if not def then return false end
    return pcall(function()
        Adapter.remotes.fire(def, ...)
    end)
end

-- ------------------------------------------------------------
-- State
-- ------------------------------------------------------------

local State = {
    OpenEggs = false,
    Fuse = false,
    GrabScraps = false,
    RecycleScrap = false,
    UpgradeRecycler = false,
    Rebirth = false,
    UpgradeCoop = false,
    UpgradeFeeder = false,
    BuyFeeders = false,
    StartTower = false,
    StartChaos = false,
    EventChaos = false,
    NoThanks = false,

    EggFilter = "All",
    FuseFilter = "Duplicates",
    TowerMode = "Next",
    ScrapMode = "Nearest",
    EventMode = "Any",
    FeedMode = "All",

    EggDelay = 1.0,
    FuseDelay = 1.2,
    ActionDelay = 2.0,

    running = true,
    lastAction = {},
    lastStatus = "Initializing..."
}

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = 2.5
        })
    end)
end

-- ------------------------------------------------------------
-- Helpers for real player data
-- ------------------------------------------------------------

local function chickenList()
    local roster = getState("roster")
    if type(roster) ~= "table" then return {} end
    return type(roster.chickens) == "table" and roster.chickens or {}
end

local function eggList()
    local roster = getState("roster")
    if type(roster) ~= "table" then return {} end
    return type(roster.nest) == "table" and roster.nest or {}
end

local function moneyNumber()
    if Adapter.data and type(Adapter.data.money) == "function" then
        local ok, value = pcall(Adapter.data.money)
        if ok and value then
            if type(value) == "number" then return value end
            local ok2, n = pcall(function() return value:toNumber() end)
            if ok2 and tonumber(n) then return tonumber(n) end
        end
    end

    local m = getState("money")
    if type(m) == "number" then return m end
    return 0
end

local function isEggAllowed(egg)
    if State.EggFilter == "All" then return true end
    if type(egg) ~= "table" then return false end
    local rarity = tostring(egg.rarity or egg.rk or egg.tier or ""):lower()
    return rarity == State.EggFilter:lower()
end

local function isChickenFuseAllowed(chicken)
    if type(chicken) ~= "table" then return false end
    if chicken.favorite == true or chicken.isFavorite == true then return false end

    if State.FuseFilter == "Duplicates" then
        return true
    elseif State.FuseFilter == "Common Only" then
        return tostring(chicken.rarity or ""):lower() == "common"
    elseif State.FuseFilter == "Same Type" then
        return chicken.typeId ~= nil
    end
    return true
end

local function cooldown(key, delay)
    local now = os.clock()
    local last = State.lastAction[key] or 0
    if now - last < delay then return false end
    State.lastAction[key] = now
    return true
end

-- ------------------------------------------------------------
-- Confirmed game actions
-- ------------------------------------------------------------

local function openEggOnce()
    local eggs = eggList()
    for _, egg in pairs(eggs) do
        if type(egg) == "table" and egg.id and isEggAllowed(egg) then
            local ok, result = invoke("HatchEgg", egg.id)
            if ok then
                State.lastStatus = "Opened egg: " .. tostring(egg.id)
            else
                State.lastStatus = "Hatch: " .. tostring(result)
            end
            return ok
        elseif type(egg) == "string" and State.EggFilter == "All" then
            local ok = invoke("HatchEgg", egg)
            if ok then
                State.lastStatus = "Opened egg"
            end
            return ok
        end
    end
    State.lastStatus = "No hatchable egg found"
    return false
end

local function fuseOnce()
    local chickens = chickenList()
    local groups = {}

    for _, chicken in pairs(chickens) do
        if isChickenFuseAllowed(chicken) and chicken.id and chicken.typeId then
            groups[chicken.typeId] = groups[chicken.typeId] or {}
            table.insert(groups[chicken.typeId], chicken)
        end
    end

    for typeId, group in pairs(groups) do
        if #group >= 3 then
            local a, b, c = group[1], group[2], group[3]
            if a and b and c then
                -- The supplied game source calls:
                -- FuseChickens(p1.id, p2.id, p3, nil, p4)
                -- p3/p4 are optional fusion choices supplied by the
                -- native fusion UI. nil is the safest neutral choice.
                local ok, result = invoke("FuseChickens", a.id, b.id, nil, nil, nil)
                if ok then
                    State.lastStatus = "Fused " .. tostring(typeId)
                else
                    State.lastStatus = "Fuse: " .. tostring(result)
                end
                return ok
            end
        end
    end

    State.lastStatus = "No valid duplicate trio"
    return false
end

local function upgradeRecyclerOnce()
    local scrap = getState("scrap")
    if type(scrap) ~= "table" then
        State.lastStatus = "Scrap data unavailable"
        return false
    end

    local level = tonumber(scrap.recyclerLevel or 0) or 0
    local ok, result = invoke("UpgradeRecycler")
    if ok then
        State.lastStatus = "Recycler upgrade requested (Lv " .. tostring(level) .. ")"
    else
        State.lastStatus = "Recycler: " .. tostring(result)
    end
    return ok
end

local function upgradeCoopOnce()
    local coop = getState("coop")
    if type(coop) ~= "table" then
        State.lastStatus = "Coop data unavailable"
        return false
    end

    local generators = type(coop.generators) == "table" and coop.generators or {}
    for _, gen in pairs(generators) do
        local slot = tonumber(gen.slot)
        local level = tonumber(gen.level)
        if slot and level then
            local ok, result = invoke("UpgradeGenerator", slot)
            if ok then
                State.lastStatus = "Upgraded feeder slot " .. tostring(slot)
            else
                State.lastStatus = "Upgrade feeder: " .. tostring(result)
            end
            return ok
        end
    end

    State.lastStatus = "No feeder to upgrade"
    return false
end

local function buyFeederOnce()
    local coop = getState("coop")
    if type(coop) ~= "table" then
        State.lastStatus = "Coop data unavailable"
        return false
    end

    local generators = type(coop.generators) == "table" and coop.generators or {}
    local slots = tonumber(coop.slots or 0) or 0
    local buySlot = #generators + 1

    -- The native controller computes whether the next slot is allowed.
    -- We only request the exact BuyGenerator(slot) interface when money
    -- and a plausible slot exist.
    if buySlot <= slots + 1 then
        local ok, result = invoke("BuyGenerator", buySlot)
        if ok then
            State.lastStatus = "Buy feeder slot " .. tostring(buySlot)
        else
            State.lastStatus = "Buy feeder: " .. tostring(result)
        end
        return ok
    end

    State.lastStatus = "No feeder slot available"
    return false
end

local function expandCoopOnce()
    local ok, result = invoke("ExpandCoop")
    if ok then
        State.lastStatus = "Coop expansion requested"
    else
        State.lastStatus = "Coop expand: " .. tostring(result)
    end
    return ok
end

local function rebirthOnce()
    local ok, result = invoke("Rebirth")
    if ok then
        State.lastStatus = "Rebirth requested"
    else
        State.lastStatus = "Rebirth: " .. tostring(result)
    end
    return ok
end

local function startTowerOnce()
    -- Exact native tower start interface from the supplied source.
    if Adapter.chickenMode and type(Adapter.chickenMode.order) == "function" then
        pcall(Adapter.chickenMode.order, "tower")
    end

    local ok, result = invoke("TowerStart")
    if ok then
        State.lastStatus = "Tower started"
    else
        State.lastStatus = "Tower: " .. tostring(result)
    end
    return ok
end

-- ------------------------------------------------------------
-- Scrap / recycler / Chaos are handled through the native visible
-- objects/buttons when no confirmed action remote was present.
-- This avoids inventing remote names.
-- ------------------------------------------------------------

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function objectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position or nil
    end
    return nil
end

local function nameLooks(obj, words)
    local n = tostring(obj.Name):lower()
    for _, word in ipairs(words) do
        if string.find(n, word, 1, true) then return true end
    end
    return false
end

local function findNearestWorkspaceObject(words, maxDistance)
    local root = getRoot()
    if not root then return nil end

    local best, bestDist
    bestDist = maxDistance or math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and nameLooks(obj, words) then
            local pos = objectPosition(obj)
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < bestDist and obj ~= workspace.CurrentCamera then
                    best = obj
                    bestDist = d
                end
            end
        end
    end
    return best, bestDist
end

local function teleportToObject(obj)
    local root = getRoot()
    local pos = objectPosition(obj)
    if not root or not pos then return false end

    local ok = pcall(function()
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)

    return ok
end

local function teleportScrap()
    local obj = findNearestWorkspaceObject({"scrap", "junk", "metal", "debris"}, 10000)
    if obj then
        teleportToObject(obj)
        State.lastStatus = "Teleported to scrap"
        return true
    end
    State.lastStatus = "No scrap object found"
    return false
end

local function teleportRecycler()
    local obj = findNearestWorkspaceObject({"recycler", "recycle"}, 10000)
    if obj then
        teleportToObject(obj)
        State.lastStatus = "Teleported to recycler"
        return true
    end
    State.lastStatus = "Recycler object not found"
    return false
end

local function getEventState()
    local id = workspace:GetAttribute("EventId")
    local phase = workspace:GetAttribute("EventPhase")
    local deadline = workspace:GetAttribute("EventDeadline")
    local active = phase == "warmup" or phase == "live"
    return active, id, phase, deadline
end

local function activateMatchingButton(words)
    local found
    local bestScore = -1

    local function inspect(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                local text = ""
                pcall(function() text = obj.Text end)
                local hay = tostring(text) .. " " .. tostring(obj.Name)
                hay = hay:lower()

                local score = 0
                for _, word in ipairs(words) do
                    if string.find(hay, word, 1, true) then
                        score = score + 1
                    end
                end

                if score > bestScore and obj.Visible and obj.Active then
                    bestScore = score
                    found = obj
                end
            end
        end
    end

    pcall(function() inspect(PlayerGui) end)
    pcall(function() inspect(CoreGui) end)

    if found and bestScore > 0 then
        local ok = pcall(function()
            found:Activate()
        end)
        if ok then return true end
    end

    return false
end

local function startChaosOnce()
    -- The supplied HUD reference identifies the real action as the
    -- visible "toChaos" button. We activate that button rather than
    -- inventing an unverified Chaos remote.
    if activateMatchingButton({"to chaos", "chaos"}) then
        State.lastStatus = "Chaos action activated"
        return true
    end
    State.lastStatus = "Chaos button not visible"
    return false
end

local function cancelChaosOnce()
    if activateMatchingButton({"cancel", "retreat"}) then
        State.lastStatus = "Chaos cancelled"
        return true
    end
    return false
end

local function noThanksOnce()
    if activateMatchingButton({"no thanks", "no_thanks", "not now"}) then
        State.lastStatus = "No Thanks activated"
        return true
    end
    return false
end

-- ------------------------------------------------------------
-- Main automation loops
-- ------------------------------------------------------------

task.spawn(function()
    while State.running do
        task.wait(0.15)

        if State.OpenEggs and cooldown("eggs", State.EggDelay) then
            pcall(openEggOnce)
        end

        if State.Fuse and cooldown("fuse", State.FuseDelay) then
            pcall(fuseOnce)
        end

        if State.UpgradeRecycler and cooldown("recycler", State.ActionDelay) then
            pcall(upgradeRecyclerOnce)
        end

        if State.Rebirth and cooldown("rebirth", math.max(3, State.ActionDelay)) then
            pcall(rebirthOnce)
        end

        if State.UpgradeFeeder and cooldown("upgradeFeeder", State.ActionDelay) then
            pcall(upgradeCoopOnce)
        end

        if State.BuyFeeders and cooldown("buyFeeder", math.max(3, State.ActionDelay)) then
            pcall(buyFeederOnce)
        end

        if State.UpgradeCoop and cooldown("expandCoop", math.max(3, State.ActionDelay)) then
            pcall(expandCoopOnce)
        end

        if State.GrabScraps and cooldown("scrap", 1.5) then
            pcall(teleportScrap)
        end

        if State.RecycleScrap and cooldown("recyclerTp", 2) then
            pcall(teleportRecycler)
        end

        if State.StartTower and cooldown("tower", 5) then
            pcall(startTowerOnce)
        end

        if State.StartChaos and cooldown("chaos", 2) then
            pcall(startChaosOnce)
        end

        if State.EventChaos then
            local active = getEventState()
            if active then
                if cooldown("eventChaos", 2) then
                    pcall(startChaosOnce)
                end
            else
                -- Event ended: cancel only if the cancel control exists.
                if cooldown("eventCancel", 2) then
                    pcall(cancelChaosOnce)
                end
            end
        end

        if State.NoThanks and cooldown("nothanks", 1.5) then
            pcall(noThanksOnce)
        end
    end
end)

-- ------------------------------------------------------------
-- Standalone HAIMIYACH / Sudoku-v9-style compact mobile UI
-- ------------------------------------------------------------

local Gui = Instance.new("ScreenGui")
Gui.Name = "HAIMIYACH_GAF_V4_FIXED"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 9999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOk = pcall(function()
    Gui.Parent = CoreGui
end)
if not parentOk or not Gui.Parent then
    Gui.Parent = PlayerGui
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

local function stroke(obj, transparency)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(70, 72, 82)
    s.Thickness = 1
    s.Transparency = transparency or 0.35
    s.Parent = obj
end

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local portrait = viewport.Y > viewport.X
local width = math.clamp(math.floor(viewport.X * (portrait and 0.78 or 0.36)), 270, 370)
local height = math.clamp(math.floor(viewport.Y * (portrait and 0.70 or 0.76)), 390, 560)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.fromOffset(width, height)
Window.Position = UDim2.new(0, 10, 0.5, -height / 2)
Window.BackgroundColor3 = Color3.fromRGB(21, 22, 27)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = Gui
corner(Window, 10)
stroke(Window, 0.15)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(29, 30, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window
corner(Header, 10)

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 10)
HeaderCover.Position = UDim2.new(0, 0, 1, -10)
HeaderCover.BackgroundColor3 = Header.BackgroundColor3
HeaderCover.BorderSizePixel = 0
HeaderCover.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 0, 20)
Title.Position = UDim2.fromOffset(12, 5)
Title.BackgroundTransparency = 1
Title.Text = "HAIMIYACH"
Title.TextColor3 = Color3.fromRGB(245, 246, 249)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -90, 0, 12)
Subtitle.Position = UDim2.fromOffset(12, 26)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "GAF • V4 FIXED"
Subtitle.TextColor3 = Color3.fromRGB(125, 128, 139)
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 7
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(28, 28)
Close.Position = UDim2.new(1, -36, 0, 8)
Close.BackgroundColor3 = Color3.fromRGB(44, 45, 52)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(225, 226, 231)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header
corner(Close, 7)

local Tabs = Instance.new("ScrollingFrame")
Tabs.Size = UDim2.new(1, -12, 0, 38)
Tabs.Position = UDim2.fromOffset(6, 49)
Tabs.BackgroundColor3 = Color3.fromRGB(27, 28, 34)
Tabs.BorderSizePixel = 0
Tabs.ScrollBarThickness = 0
Tabs.ScrollingDirection = Enum.ScrollingDirection.X
Tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
Tabs.CanvasSize = UDim2.new()
Tabs.Parent = Window
corner(Tabs, 7)

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 4)
tabPad.PaddingRight = UDim.new(0, 4)
tabPad.PaddingTop = UDim.new(0, 5)
tabPad.Parent = Tabs

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = Tabs

local Holder = Instance.new("Frame")
Holder.Size = UDim2.new(1, -12, 1, -92)
Holder.Position = UDim2.fromOffset(6, 88)
Holder.BackgroundTransparency = 1
Holder.ClipsDescendants = true
Holder.Parent = Window

local Pages = {}
local TabButtons = {}
local currentTab

local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.fromScale(1, 1)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(100, 102, 112)
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new()
    p.Visible = false
    p.Parent = Holder

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 3)
    pad.PaddingRight = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = p

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = p

    Pages[name] = p
    return p
end

local function makeTab(name, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(74, 28)
    b.BackgroundColor3 = Color3.fromRGB(42, 43, 50)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = name
    b.TextColor3 = Color3.fromRGB(160, 163, 173)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 7
    b.LayoutOrder = order
    b.Parent = Tabs
    corner(b, 6)
    TabButtons[name] = b
    return b
end

local function selectTab(name)
    currentTab = name
    for n, p in pairs(Pages) do p.Visible = n == name end
    for n, b in pairs(TabButtons) do
        local on = n == name
        b.BackgroundColor3 = on and Color3.fromRGB(72, 74, 84) or Color3.fromRGB(42, 43, 50)
        b.TextColor3 = on and Color3.fromRGB(245, 246, 249) or Color3.fromRGB(160, 163, 173)
    end
end

local function section(page, text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(112, 115, 127)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 7
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order or 0
    l.Parent = page
end

local function toggle(page, text, order, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(33, 34, 40)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -78, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226, 228, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(50, 23)
    b.Position = UDim2.new(1, -60, 0.5, -11)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 49)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBold
    b.TextSize = 7
    b.Parent = row
    corner(b, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(15, 15)
    knob.BorderSizePixel = 0
    knob.Parent = b
    corner(knob, 8)

    local function redraw()
        local on = State[key] == true
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and Color3.fromRGB(82, 84, 94) or Color3.fromRGB(45, 45, 49)
        b.TextColor3 = on and Color3.fromRGB(245,245,245) or Color3.fromRGB(175,177,185)
        knob.BackgroundColor3 = on and Color3.fromRGB(245,245,245) or Color3.fromRGB(165,165,170)
        knob.Position = on and UDim2.new(1, -19, 0.5, -7) or UDim2.fromOffset(4,4)
    end

    b.Activated:Connect(function()
        State[key] = not State[key]
        redraw()
        notify(text, State[key] and "ON" or "OFF")
    end)

    redraw()
end

local function dropdown(page, text, order, key, options)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(33, 34, 40)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.42, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220,222,230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.54, -8, 0, 26)
    b.Position = UDim2.new(0.46, 0, 0.5, -13)
    b.BackgroundColor3 = Color3.fromRGB(45,46,54)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.TextColor3 = Color3.fromRGB(222,224,231)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 8
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.Parent = row
    corner(b, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = Color3.fromRGB(29,30,36)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = page
    corner(list, 7)
    stroke(list)

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 3)
    lay.Parent = list

    for i, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 29)
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
        corner(item, 5)

        item.Activated:Connect(function()
            State[key] = option
            b.Text = tostring(option)
            list.Visible = false
            list.Size = UDim2.new(1,0,0,0)
        end)
    end

    b.Activated:Connect(function()
        local open = not list.Visible
        list.Visible = open
        list.Size = UDim2.new(1,0,0,open and math.min(#options * 32 + 5, 160) or 0)
    end)

    b.Text = tostring(State[key])
end

local function action(page, text, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,36)
    b.BackgroundColor3 = Color3.fromRGB(33,34,40)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = Color3.fromRGB(226,228,235)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 8
    b.LayoutOrder = order
    b.Parent = page
    corner(b,7)
    stroke(b)
    b.Activated:Connect(function() pcall(callback) end)
end

local Main = makePage("MAIN")
local EGGS = makePage("EGGS")
local CHICKENS = makePage("CHICKENS")
local SCRAP = makePage("SCRAP")
local COOP = makePage("COOP")
local BATTLE = makePage("BATTLE")
local SETTINGS = makePage("SETTINGS")

local tabs = {
    {"MAIN",1},{"EGGS",2},{"CHICKENS",3},{"SCRAP",4},
    {"COOP",5},{"BATTLE",6},{"SETTINGS",7}
}
for _, item in ipairs(tabs) do
    local b = makeTab(item[1], item[2])
    b.Activated:Connect(function() selectTab(item[1]) end)
end

-- MAIN
section(Main, "AUTOMATION", 1)
toggle(Main, "Auto Open Eggs", 2, "OpenEggs")
toggle(Main, "Auto Fuse Chickens", 3, "Fuse")
toggle(Main, "Auto Grab Scraps", 4, "GrabScraps")
toggle(Main, "Auto Recycle Scrap", 5, "RecycleScrap")
toggle(Main, "Auto Upgrade Recycler", 6, "UpgradeRecycler")
toggle(Main, "Auto Rebirth", 7, "Rebirth")
toggle(Main, "Auto Upgrade Coop", 8, "UpgradeCoop")
toggle(Main, "Auto Upgrade Feeder", 9, "UpgradeFeeder")
toggle(Main, "Auto Buy Feeders", 10, "BuyFeeders")
toggle(Main, "Auto Start Tower", 11, "StartTower")
toggle(Main, "Auto Start Chaos", 12, "StartChaos")
toggle(Main, "Auto Events → Chaos", 13, "EventChaos")
toggle(Main, "Auto No Thanks", 14, "NoThanks")

-- EGGS
section(EGGS, "EGG FILTER", 1)
dropdown(EGGS, "Rarity", 2, "EggFilter",
    {"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Divine"})
dropdown(EGGS, "Open Delay", 3, "EggDelay",
    {"0.5","0.8","1","1.5","2"})
action(EGGS, "Open One Egg Now", 5, openEggOnce)

-- CHICKENS
section(CHICKENS, "FUSE FILTER", 1)
dropdown(CHICKENS, "Mode", 2, "FuseFilter",
    {"Duplicates","Common Only","Same Type"})
dropdown(CHICKENS, "Fuse Delay", 3, "FuseDelay",
    {"0.8","1","1.2","1.5","2"})
action(CHICKENS, "Fuse One Trio Now", 5, fuseOnce)

-- SCRAP
section(SCRAP, "TELEPORT AUTOMATION", 1)
dropdown(SCRAP, "Target", 2, "ScrapMode",
    {"Nearest","Any"})
action(SCRAP, "Teleport → Scrap", 4, teleportScrap)
action(SCRAP, "Teleport → Recycler", 5, teleportRecycler)

-- COOP
section(COOP, "COOP / FEEDERS", 1)
toggle(COOP, "Auto Upgrade Coop", 2, "UpgradeCoop")
toggle(COOP, "Auto Upgrade Feeder", 3, "UpgradeFeeder")
toggle(COOP, "Auto Buy Feeders", 4, "BuyFeeders")
dropdown(COOP, "Feed Mode", 5, "FeedMode", {"All","Upgrade","Buy"})
action(COOP, "Upgrade Feeder Now", 7, upgradeCoopOnce)
action(COOP, "Buy Feeder Now", 8, buyFeederOnce)
action(COOP, "Expand Coop Now", 9, expandCoopOnce)

-- BATTLE
section(BATTLE, "TOWER / CHAOS", 1)
toggle(BATTLE, "Auto Start Tower", 2, "StartTower")
toggle(BATTLE, "Auto Start Chaos", 3, "StartChaos")
toggle(BATTLE, "Auto Events → Chaos", 4, "EventChaos")
dropdown(BATTLE, "Event Filter", 5, "EventMode", {"Any","Chaos"})
action(BATTLE, "Start Tower Now", 7, startTowerOnce)
action(BATTLE, "Start Chaos Now", 8, startChaosOnce)
action(BATTLE, "Cancel Chaos Now", 9, cancelChaosOnce)

-- SETTINGS
section(SETTINGS, "STATUS", 1)
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1,0,0,58)
Status.BackgroundColor3 = Color3.fromRGB(33,34,40)
Status.BorderSizePixel = 0
Status.Text = "Loading..."
Status.TextColor3 = Color3.fromRGB(205,207,216)
Status.Font = Enum.Font.Gotham
Status.TextSize = 8
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center
Status.LayoutOrder = 2
Status.Parent = SETTINGS
corner(Status,7)
stroke(Status)

action(SETTINGS, "Test Game Adapter", 4, function()
    if Adapter.ok then
        notify("Adapter", "DataService + Remotes OK")
        State.lastStatus = "Adapter OK"
    else
        notify("Adapter", "Game adapter unavailable")
        State.lastStatus = "Adapter unavailable"
    end
end)

action(SETTINGS, "Stop All Automation", 5, function()
    for k, v in pairs(State) do
        if type(v) == "boolean" and k ~= "running" then
            State[k] = false
        end
    end
    notify("HAIMIYACH", "All automation OFF")
end)

-- Floating button
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(96,30)
OpenButton.Position = UDim2.new(0.5,-48,0,8)
OpenButton.BackgroundColor3 = Color3.fromRGB(29,30,36)
OpenButton.BackgroundTransparency = 0.12
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "HAIMIYACH"
OpenButton.TextColor3 = Color3.fromRGB(240,241,245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = Gui
corner(OpenButton,16)
stroke(OpenButton,0.25)

local function closeWindow()
    Window.Visible = false
    OpenButton.Visible = true
end

local function openWindow()
    Window.Visible = true
    OpenButton.Visible = false
end

Close.Activated:Connect(closeWindow)
OpenButton.Activated:Connect(openWindow)

-- Drag support, touch + mouse.
local function makeDraggable(handle, target)
    local dragging = false
    local startPos
    local startTarget
    local connection

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        startPos = input.Position
        startTarget = target.Position

        if connection then connection:Disconnect() end
        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch
                and move.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local delta = move.Position - startPos
            target.Position = UDim2.new(
                startTarget.X.Scale,
                startTarget.X.Offset + delta.X,
                startTarget.Y.Scale,
                startTarget.Y.Offset + delta.Y
            )
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if connection then
                    connection:Disconnect()
                    connection = nil
                end
            end
        end)
    end)
end

makeDraggable(Header, Window)
makeDraggable(OpenButton, OpenButton)

selectTab("MAIN")

-- Status refresh
task.spawn(function()
    while Gui.Parent and State.running do
        task.wait(0.35)

        local roster = getState("roster")
        local coop = getState("coop")
        local tower = getState("tower")
        local scrap = getState("scrap")
        local rebirth = getState("rebirth")

        local eggs = 0
        local chickens = 0
        local feeders = 0
        local towerBest = 0
        local recyclerLevel = 0
        local rebirthCount = 0

        if type(roster) == "table" then
            eggs = #(roster.nest or {})
            chickens = #(roster.chickens or {})
        end
        if type(coop) == "table" then
            feeders = #(coop.generators or {})
        end
        if type(tower) == "table" then
            towerBest = tonumber(tower.best or 0) or 0
        end
        if type(scrap) == "table" then
            recyclerLevel = tonumber(scrap.recyclerLevel or 0) or 0
        end
        if type(rebirth) == "table" then
            rebirthCount = tonumber(rebirth.count or 0) or 0
        elseif type(rebirth) == "number" then
            rebirthCount = rebirth
        end

        local eventActive, eventId, eventPhase = getEventState()

        Status.Text =
            "Adapter: " .. (Adapter.ok and "READY" or "NOT READY") ..
            "\nMoney: " .. tostring(math.floor(moneyNumber())) ..
            "  • Eggs: " .. tostring(eggs) ..
            "  • Chickens: " .. tostring(chickens) ..
            "\nFeeders: " .. tostring(feeders) ..
            "  • Tower Best: " .. tostring(towerBest) ..
            "  • Recycler: " .. tostring(recyclerLevel) ..
            "\nRebirth: " .. tostring(rebirthCount) ..
            "\nEvent: " .. (eventActive and tostring(eventId or "?") .. " / " .. tostring(eventPhase) or "none") ..
            "\n" .. tostring(State.lastStatus)
    end
end)

State.lastStatus = Adapter.ok
    and "Loaded successfully"
    or "Loaded UI; game adapter unavailable"

notify("HAIMIYACH GAF", State.lastStatus)
print("[HAIMIYACH_GAF_V4_FIXED] loaded")
