--[[
    DigCleanTools_EXTENDED_FIXED.lua
    HAIMIYACH TAB UI
    UI-only controller / adapter for Dig & Clean.

    IMPORTANT:
    - Feature names are based on the supplied Dig&Clean client reference.
    - This UI never invents RemoteEvent paths; actions use explicit core hooks.
    - A button reports unavailable instead of pretending a missing feature worked.
    - If your 40K-line core uses local functions, expose thin global adapters
      from the core, e.g. _G.toggleAutoDig = toggleAutoDig.
    - No duplicated pages/tabs.
    - Dropdowns are overlay popups and do not participate in page UIListLayout.
    - Designed for touch + mouse and portrait/landscape Android screens.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEAN OLD INSTANCE
-- ============================================================

pcall(function()
    local old = PlayerGui:FindFirstChild("DigCleanTools_EXTENDED")
    if old then old:Destroy() end
end)

-- ============================================================
-- STATE
-- ============================================================

local State = {
    AutoDig = rawget(_G, "autoDigActive") == true,
    AutoClean = rawget(_G, "autoCleanActive") == true,
    AutoPolish = rawget(_G, "autoPolishActive") == true,
    AutoCollect = rawget(_G, "autoCollectActive") == true,
    AutoSell = rawget(_G, "autoSellActive") == true,
    AutoAppraise = rawget(_G, "autoAppraiseActive") == true,
    AutoClaim = rawget(_G, "autoClaimActive") == true,
    AutoDeleteSpot = rawget(_G, "autoDeleteSpotActive") == true,
    AutoBuy = rawget(_G, "autoBuyActive") == true,
    AutoEquip = rawget(_G, "autoEquipActive") == true,
    AutoPolishCollect = rawget(_G, "autoPolishCollectActive") == true,
    AutoPolisherUpgrade = rawget(_G, "autoPolisherUpgradeActive") == true,
    AutoPolisherUnlock = rawget(_G, "autoPolisherUnlockActive") == true,

    AntiAFK = rawget(_G, "antiAFKActive"),
    DigMode = rawget(_G, "digMode") or "Normal",
    DigTarget = rawget(_G, "digTargetMode") or "Nearest",
    CleanTarget = rawget(_G, "cleanTargetMode") or "Nearest",

    SellRarity = rawget(_G, "sellRarityFilter") or "common",
    SellMode = rawget(_G, "sellTargetMode") or "All",
    NonFavorited = rawget(_G, "sellOnlyNonFavorited"),
    AppraiseRarity = rawget(_G, "appraiseRarityFilter") or "common",

    BuyPriority = rawget(_G, "buyPriority") or "Shovel",
    BuyMode = rawget(_G, "buyMode") or "Best",
    BuyThreshold = tonumber(rawget(_G, "buyThreshold")) or 1000,

    EquipPriority = rawget(_G, "equipPriority") or "Power",

    Detector = rawget(_G, "detectorType") or "Auto",
    ESPMode = rawget(_G, "espTargetMode") or "All",
    ESPDistance = tonumber(rawget(_G, "espDistance")) or 500,

    TravelIsland = rawget(_G, "selectedIsland") or "Starter Island",
    ClaimType = rawget(_G, "claimType") or "All",

    SelectedTargetId = rawget(_G, "selectedTargetId"),
    SelectedTargetName = rawget(_G, "selectedTargetName") or "None",

    DropdownOpen = nil,
}

if State.AntiAFK == nil then State.AntiAFK = true end
if State.NonFavorited == nil then State.NonFavorited = true end

local function sync(name, value)
    rawset(_G, name, value)
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "DigClean"),
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

local function call(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then
        return false, "missing"
    end
    return pcall(fn, ...)
end

local function callAny(names, ...)
    for _, name in ipairs(names) do
        local ok, result = call(name, ...)
        if ok then return true, result, name end
    end
    return false, nil, nil
end

local function setState(key, value, globalName)
    State[key] = value == true
    if globalName then sync(globalName, State[key]) end
end

-- ============================================================
-- ADAPTER MAP
-- These names cover the feature families found in the reference.
-- The core remains responsible for the actual game/network calls.
-- ============================================================

local Adapter = {}

function Adapter.toggleAutoDig(v)
    setState("AutoDig", v, "autoDigActive")
    return callAny({"toggleAutoDig"}, v)
end

function Adapter.toggleAutoClean(v)
    setState("AutoClean", v, "autoCleanActive")
    return callAny({"toggleAutoClean"}, v)
end

function Adapter.toggleAutoPolish(v)
    setState("AutoPolish", v, "autoPolishActive")
    return callAny({"toggleAutoPolish"}, v)
end

function Adapter.toggleAutoCollect(v)
    setState("AutoCollect", v, "autoCollectActive")
    return callAny({"toggleAutoCollect", "toggleAutoCollectItems"}, v)
end

function Adapter.toggleAutoSell(v)
    setState("AutoSell", v, "autoSellActive")
    return callAny({"toggleAutoSell"}, v)
end

function Adapter.toggleAutoAppraise(v)
    setState("AutoAppraise", v, "autoAppraiseActive")
    return callAny({"toggleAutoAppraise"}, v)
end

function Adapter.toggleAutoClaim(v)
    setState("AutoClaim", v, "autoClaimActive")
    return callAny({"toggleAutoClaim"}, v)
end

function Adapter.toggleAutoDeleteSpot(v)
    setState("AutoDeleteSpot", v, "autoDeleteSpotActive")
    return callAny({"toggleAutoDeleteSpot"}, v)
end

function Adapter.toggleAutoBuy(v)
    setState("AutoBuy", v, "autoBuyActive")
    return callAny({"toggleAutoBuy"}, v)
end

function Adapter.toggleAutoEquip(v)
    setState("AutoEquip", v, "autoEquipActive")
    return callAny({"toggleAutoEquip"}, v)
end

function Adapter.toggleAutoPolishCollect(v)
    setState("AutoPolishCollect", v, "autoPolishCollectActive")
    return callAny({"toggleAutoPolishCollect", "toggleAutoCollectPolish"}, v)
end

function Adapter.togglePolisherUpgrade(v)
    setState("AutoPolisherUpgrade", v, "autoPolisherUpgradeActive")
    return callAny({"toggleAutoPolisherUpgrade", "toggleAutoUpgradePolisher"}, v)
end

function Adapter.togglePolisherUnlock(v)
    setState("AutoPolisherUnlock", v, "autoPolisherUnlockActive")
    return callAny({"toggleAutoPolisherUnlock", "toggleAutoUnlockPolisher"}, v)
end

function Adapter.toggleAntiAFK(v)
    setState("AntiAFK", v, "antiAFKActive")
    return callAny({"toggleAntiAFK"}, v)
end

function Adapter.setDigMode(v)
    State.DigMode = v
    sync("digMode", v)
    return callAny({"setDigMode"}, v)
end

function Adapter.setDigTarget(v)
    State.DigTarget = v
    sync("digTargetMode", v)
    return callAny({"setDigTargetMode"}, v)
end

function Adapter.setCleanTarget(v)
    State.CleanTarget = v
    sync("cleanTargetMode", v)
    return callAny({"setCleanTargetMode"}, v)
end

function Adapter.setSellRarity(v)
    State.SellRarity = v
    sync("sellRarityFilter", v)
    return callAny({"setSellRarity"}, v)
end

function Adapter.setSellMode(v)
    State.SellMode = v
    sync("sellTargetMode", v)
    return callAny({"setSellTargetMode"}, v)
end

function Adapter.setNonFavorited(v)
    State.NonFavorited = v == true
    sync("sellOnlyNonFavorited", State.NonFavorited)
    return callAny({"setSellOnlyNonFavorited"}, State.NonFavorited)
end

function Adapter.setAppraiseRarity(v)
    State.AppraiseRarity = v
    sync("appraiseRarityFilter", v)
    return callAny({"setAppraiseRarity"}, v)
end

function Adapter.setBuyPriority(v)
    State.BuyPriority = v
    sync("buyPriority", v)
    return callAny({"setBuyPriority"}, v)
end

function Adapter.setBuyMode(v)
    State.BuyMode = v
    sync("buyMode", v)
    return callAny({"setBuyMode"}, v)
end

function Adapter.setEquipPriority(v)
    State.EquipPriority = v
    sync("equipPriority", v)
    return callAny({"setEquipPriority"}, v)
end

function Adapter.setDetector(v)
    State.Detector = v
    sync("detectorType", v)
    return callAny({"setDetector", "setDetectorType"}, v)
end

function Adapter.setESPMode(v)
    State.ESPMode = v
    sync("espTargetMode", v)
    return callAny({"setESPTargetMode"}, v)
end

function Adapter.setESPDistance(v)
    State.ESPDistance = tonumber(v) or State.ESPDistance
    sync("espDistance", State.ESPDistance)
    return callAny({"setESPDistance"}, State.ESPDistance)
end

function Adapter.setClaimType(v)
    State.ClaimType = v
    sync("claimType", v)
    return callAny({"setClaimType"}, v)
end

function Adapter.setIsland(v)
    State.TravelIsland = v
    sync("selectedIsland", v)
    return callAny({"setTravelIsland", "setSelectedIsland"}, v)
end

function Adapter.selectTarget(player)
    State.SelectedTargetId = player.UserId
    State.SelectedTargetName = player.DisplayName
    sync("selectedTargetId", player.UserId)
    sync("selectedTargetName", player.DisplayName)

    callAny({"setSelectedTarget", "setDigTargetUserId"}, player.UserId)
end

function Adapter.action(actionName, ...)
    local aliases = {
        TeleportPlot = {"teleportToPlot"},
        TeleportTarget = {"teleportToTarget"},
        TeleportSeller = {"teleportToSeller"},
        TeleportHome = {"teleportToHome", "TeleportHome"},
        TeleportHub = {"teleportToHub", "TeleportHub"},
        Travel = {"travelToIsland", "travelIsland", "travel"},
        ShowInfo = {"showInfo"},
        SellHeld = {"sellHeldItem", "sellHeld"},
        SellInventory = {"sellInventory"},
        CollectPolish = {"collectPolish"},
        StartPolish = {"startPolish"},
        UpgradePolisher = {"upgradePolisher"},
        UnlockPolisher = {"unlockPolisher"},
        ClaimRewards = {"ClaimAvailableRewards", "claimRewards"},
        AppraiseAll = {"appraiseAll", "performAppraise"},
        BuyBest = {"buyBestGear", "performBuy"},
        EquipBest = {"equipBestGear", "performEquip"},
        DeleteSpots = {"DeleteCompletedDigSpots", "deleteCompletedDigSpots"},
    }

    local list = aliases[actionName]
    if not list then return false, "unknown" end
    return callAny(list, ...)
end

-- ============================================================
-- GUI
-- ============================================================

local Gui = Instance.new("ScreenGui")
Gui.Name = "DigCleanTools_EXTENDED"
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
Window.Position = UDim2.new(0.5, -guiW / 2, 0.5, -guiH / 2)
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
Subtitle.Text = "TOOLS • EXTENDED FIXED"
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
        b.BackgroundColor3 = active
            and Color3.fromRGB(72, 74, 84)
            or Color3.fromRGB(43, 44, 51)
        b.TextColor3 = active
            and Color3.fromRGB(245, 246, 249)
            or Color3.fromRGB(164, 166, 175)
    end

    State.DropdownOpen = nil
end

-- ============================================================
-- OVERLAY POPUP LAYER
-- This prevents dropdowns from breaking UIListLayout.
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
    State.DropdownOpen = nil
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

    b.Activated:Connect(function()
        if callback then pcall(callback) end
    end)

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
        local enabled = false
        pcall(function() enabled = getter() == true end)

        b.Text = enabled and "ON" or "OFF"
        b.BackgroundColor3 = enabled
            and Color3.fromRGB(82, 84, 94)
            or Color3.fromRGB(45, 45, 48)
        b.TextColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(175, 177, 185)
        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(165, 165, 170)
        knob.Position = enabled
            and UDim2.new(1, -19, 0.5, -7)
            or UDim2.fromOffset(4, 4)
    end

    b.Activated:Connect(function()
        local current = false
        pcall(function() current = getter() == true end)

        local ok = pcall(function()
            setter(not current)
        end)

        if not ok then
            notify("DigClean", "Toggle error: " .. text, 2)
        end

        task.defer(redraw)
    end)

    redraw()
    return row, redraw
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

    local function currentValue()
        local value = "?"
        pcall(function() value = getter() end)
        return tostring(value)
    end

    local function redraw()
        b.Text = currentValue()
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
                pcall(function() setter(option) end)
                redraw()
                closePopups()
            end)
        end

        State.DropdownOpen = popup
    end

    b.Activated:Connect(function()
        if State.DropdownOpen then
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

-- Forward declaration: Settings callbacks are created before the floating button.
local OpenButton

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
-- MAIN
-- ============================================================

section(MainPage, "AUTOMATION", 1)

toggleRow(MainPage, "Auto Dig", 2,
    function() return State.AutoDig end,
    Adapter.toggleAutoDig)

toggleRow(MainPage, "Auto Clean", 3,
    function() return State.AutoClean end,
    Adapter.toggleAutoClean)

toggleRow(MainPage, "Auto Collect Items", 4,
    function() return State.AutoCollect end,
    Adapter.toggleAutoCollect)

toggleRow(MainPage, "Auto Polish", 5,
    function() return State.AutoPolish end,
    Adapter.toggleAutoPolish)

dropdownRow(MainPage, "Dig Speed", 6,
    {"Normal", "Fast"},
    function() return State.DigMode end,
    Adapter.setDigMode)

dropdownRow(MainPage, "Dig Target", 7,
    {"Nearest", "Target", "All"},
    function() return State.DigTarget end,
    Adapter.setDigTarget)

dropdownRow(MainPage, "Clean Target", 8,
    {"Nearest", "Target"},
    function() return State.CleanTarget end,
    Adapter.setCleanTarget)

section(MainPage, "ITEM", 10)

toggleRow(MainPage, "Auto Appraise", 11,
    function() return State.AutoAppraise end,
    Adapter.toggleAutoAppraise)

dropdownRow(MainPage, "Appraise Rarity", 12,
    {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},
    function() return State.AppraiseRarity end,
    Adapter.setAppraiseRarity)

toggleRow(MainPage, "Auto Claim", 13,
    function() return State.AutoClaim end,
    Adapter.toggleAutoClaim)

dropdownRow(MainPage, "Claim Type", 14,
    {"All", "Quest", "Journal", "Daily"},
    function() return State.ClaimType end,
    Adapter.setClaimType)

toggleRow(MainPage, "Auto Delete Dig Spot", 15,
    function() return State.AutoDeleteSpot end,
    Adapter.toggleAutoDeleteSpot)

-- ============================================================
-- TARGET
-- ============================================================

section(TargetPage, "PLAYER TARGET", 1)

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
targetButton.Text = "Target: " .. tostring(State.SelectedTargetName)
targetButton.Parent = targetRow
corner(targetButton, 6)

local function refreshTargetButton()
    if State.SelectedTargetId then
        local p = Players:GetPlayerByUserId(State.SelectedTargetId)
        targetButton.Text = "Target: " .. (p and p.DisplayName or "Unavailable")
    else
        targetButton.Text = "Target: None"
    end
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

    local playersFound = 0

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            playersFound += 1

            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 29)
            item.BackgroundColor3 =
                State.SelectedTargetId == player.UserId
                and Color3.fromRGB(55, 65, 57)
                or Color3.fromRGB(40, 41, 48)
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = "  " .. player.DisplayName
            item.TextColor3 = Color3.fromRGB(222, 224, 231)
            item.Font = Enum.Font.Gotham
            item.TextSize = 8
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.ZIndex = 112
            item.Parent = list
            corner(item, 5)

            item.Activated:Connect(function()
                Adapter.selectTarget(player)
                refreshTargetButton()
                closePopups()
                notify("Target", player.DisplayName .. " selected", 2)
            end)
        end
    end

    if playersFound == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Text = "No other players"
        empty.TextColor3 = Color3.fromRGB(135, 138, 149)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 8
        empty.ZIndex = 112
        empty.Parent = list
    end

    State.DropdownOpen = popup
end

targetButton.Activated:Connect(function()
    if State.DropdownOpen then
        closePopups()
    else
        openTargetPopup()
    end
end)

section(TargetPage, "TARGET MODE", 4)

dropdownRow(TargetPage, "Dig", 5,
    {"Nearest", "Target", "All"},
    function() return State.DigTarget end,
    Adapter.setDigTarget)

dropdownRow(TargetPage, "Clean", 6,
    {"Nearest", "Target"},
    function() return State.CleanTarget end,
    Adapter.setCleanTarget)

action(TargetPage, "Teleport to Target", "↗", 8, function()
    local ok = Adapter.action("TeleportTarget")
    if not ok then notify("Target", "Teleport adapter unavailable", 2) end
end)

-- ============================================================
-- SELL
-- ============================================================

section(SellPage, "AUTO SELL", 1)

toggleRow(SellPage, "Auto Sell", 2,
    function() return State.AutoSell end,
    Adapter.toggleAutoSell)

dropdownRow(SellPage, "Rarity Filter", 3,
    {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},
    function() return State.SellRarity end,
    Adapter.setSellRarity)

dropdownRow(SellPage, "Sell Mode", 4,
    {"All", "Held", "Filtered"},
    function() return State.SellMode end,
    Adapter.setSellMode)

toggleRow(SellPage, "Only Non-Favorited", 5,
    function() return State.NonFavorited end,
    Adapter.setNonFavorited)

action(SellPage, "Sell Held Item", "$", 7, function()
    local ok = Adapter.action("SellHeld")
    if not ok then notify("Sell", "sellHeldItem adapter unavailable", 2) end
end)

action(SellPage, "Sell Inventory", "$", 8, function()
    local ok = Adapter.action("SellInventory")
    if not ok then notify("Sell", "sellInventory adapter unavailable", 2) end
end)

-- ============================================================
-- ESP / DETECTOR
-- ============================================================

section(ESPPage, "DETECTOR", 1)

toggleRow(ESPPage, "Detector ESP", 2,
    function() return rawget(_G, "detectorESPActive") == true end,
    function(v)
        sync("detectorESPActive", v)
        local ok = callAny({"toggleDetectorESP"}, v)
        if not ok then notify("Detector ESP", "Core adapter unavailable", 2) end
    end)

dropdownRow(ESPPage, "Detector", 3,
    {"Auto", "Copper", "Iron", "Silver", "Gold", "Diamond", "Emerald", "Ruby", "Aquamarine"},
    function() return State.Detector end,
    Adapter.setDetector)

section(ESPPage, "BURIED / DIG SPOT", 5)

toggleRow(ESPPage, "ESP Dig Spot", 6,
    function() return rawget(_G, "espActive") == true end,
    function(v)
        sync("espActive", v)
        local ok = callAny({"toggleESP"}, v)
        if not ok then notify("ESP", "toggleESP adapter unavailable", 2) end
    end)

dropdownRow(ESPPage, "ESP Mode", 7,
    {"All", "Nearest", "Target"},
    function() return State.ESPMode end,
    Adapter.setESPMode)

dropdownRow(ESPPage, "Distance", 8,
    {"100", "250", "500", "1000", "2500"},
    function() return tostring(State.ESPDistance) end,
    Adapter.setESPDistance)

-- ============================================================
-- GEAR
-- ============================================================

section(GearPage, "SHOP / BUY", 1)

toggleRow(GearPage, "Auto Buy", 2,
    function() return State.AutoBuy end,
    Adapter.toggleAutoBuy)

dropdownRow(GearPage, "Buy Priority", 3,
    {"Shovel", "Detector", "Spray"},
    function() return State.BuyPriority end,
    Adapter.setBuyPriority)

dropdownRow(GearPage, "Buy Mode", 4,
    {"Best", "Next", "All"},
    function() return State.BuyMode end,
    Adapter.setBuyMode)

action(GearPage, "Buy Best Now", "＋", 5, function()
    local ok = Adapter.action("BuyBest")
    if not ok then notify("Shop", "Buy adapter unavailable", 2) end
end)

section(GearPage, "EQUIP", 7)

toggleRow(GearPage, "Auto Equip", 8,
    function() return State.AutoEquip end,
    Adapter.toggleAutoEquip)

dropdownRow(GearPage, "Equip Priority", 9,
    {"Power", "Luck", "Speed"},
    function() return State.EquipPriority end,
    Adapter.setEquipPriority)

action(GearPage, "Equip Best Now", "✓", 10, function()
    local ok = Adapter.action("EquipBest")
    if not ok then notify("Gear", "Equip adapter unavailable", 2) end
end)

-- ============================================================
-- POLISH
-- ============================================================

section(PolishPage, "POLISHER", 1)

toggleRow(PolishPage, "Auto Start Polish", 2,
    function() return State.AutoPolish end,
    Adapter.toggleAutoPolish)

toggleRow(PolishPage, "Auto Collect Polish", 3,
    function() return State.AutoPolishCollect end,
    Adapter.toggleAutoPolishCollect)

toggleRow(PolishPage, "Auto Upgrade Polisher", 4,
    function() return State.AutoPolisherUpgrade end,
    Adapter.togglePolisherUpgrade)

toggleRow(PolishPage, "Auto Unlock Polisher", 5,
    function() return State.AutoPolisherUnlock end,
    Adapter.togglePolisherUnlock)

action(PolishPage, "Start Polish Now", "▶", 7, function()
    local ok = Adapter.action("StartPolish")
    if not ok then notify("Polisher", "startPolish adapter unavailable", 2) end
end)

action(PolishPage, "Collect Polish Now", "↓", 8, function()
    local ok = Adapter.action("CollectPolish")
    if not ok then notify("Polisher", "collectPolish adapter unavailable", 2) end
end)

action(PolishPage, "Upgrade Polisher Now", "↑", 9, function()
    local ok = Adapter.action("UpgradePolisher")
    if not ok then notify("Polisher", "upgradePolisher adapter unavailable", 2) end
end)

action(PolishPage, "Unlock Polisher Now", "🔓", 10, function()
    local ok = Adapter.action("UnlockPolisher")
    if not ok then notify("Polisher", "unlockPolisher adapter unavailable", 2) end
end)

-- ============================================================
-- TRAVEL
-- ============================================================

section(TravelPage, "ISLAND", 1)

dropdownRow(TravelPage, "Island", 2,
    {"Starter Island", "Island 2", "Island 3"},
    function() return State.TravelIsland end,
    Adapter.setIsland)

action(TravelPage, "Travel", "↗", 3, function()
    local ok = Adapter.action("Travel", State.TravelIsland)
    if not ok then notify("Travel", "Travel adapter unavailable", 2) end
end)

action(TravelPage, "Teleport Home", "⌂", 4, function()
    local ok = Adapter.action("TeleportHome")
    if not ok then notify("Travel", "Home teleport adapter unavailable", 2) end
end)

action(TravelPage, "Teleport Hub", "H", 5, function()
    local ok = Adapter.action("TeleportHub")
    if not ok then notify("Travel", "Hub teleport adapter unavailable", 2) end
end)

action(TravelPage, "Teleport to Plot", "⌂", 5, function()
    local ok = Adapter.action("TeleportPlot")
    if not ok then notify("Travel", "Teleport adapter unavailable", 2) end
end)

action(TravelPage, "Teleport to Seller", "$", 6, function()
    local ok = Adapter.action("TeleportSeller")
    if not ok then notify("Travel", "Seller teleport unavailable", 2) end
end)

-- ============================================================
-- INFO / LUCK
-- ============================================================

section(InfoPage, "GAME DATA", 1)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 110)
infoLabel.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
infoLabel.BorderSizePixel = 0
infoLabel.Text = "Loading info..."
infoLabel.TextColor3 = Color3.fromRGB(220, 222, 230)
infoLabel.Font = Enum.Font.GothamMedium
infoLabel.TextSize = 8
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.LayoutOrder = 2
infoLabel.Parent = InfoPage
corner(infoLabel, 7)
stroke(infoLabel)

local function getValue(names, ...)
    for _, name in ipairs(names) do
        local ok, result = call(name, ...)
        if ok then return result, name end
    end
    return nil, nil
end

local function updateInfo()
    local lines = {}

    local serverLuck = getValue({"getServerLuck", "GetServerLuck"})
    local globalLuck = getValue({"getGlobalLuck", "GetGlobalLuck"})
    local gold = getValue({"getGold", "GetGold"})
    local inventory = getValue({"getInventoryData", "GetInventoryData"})
    local capacity = getValue({"getBackpackCapacity", "GetBackpackCapacity", "getInventoryCapacity", "GetInventoryCapacity"})

    table.insert(lines, "Dig Mode: " .. tostring(State.DigMode))
    table.insert(lines, "Target: " .. tostring(State.SelectedTargetName))
    table.insert(lines, "Gold: " .. tostring(gold or "N/A"))

    if type(serverLuck) == "table" then
        table.insert(lines, "Server Luck: " .. tostring(serverLuck.multiplier or serverLuck.Multiplier or "N/A"))
        table.insert(lines, "Server Luck Expiry: " .. tostring(serverLuck.expiresAt or serverLuck.ExpiresAt or "N/A"))
    else
        table.insert(lines, "Server Luck: " .. tostring(serverLuck or "N/A"))
    end

    if type(globalLuck) == "table" then
        table.insert(lines, "Global Luck: " .. tostring(globalLuck.multiplier or globalLuck.Multiplier or "N/A"))
        table.insert(lines, "Global Luck Expiry: " .. tostring(globalLuck.expiresAt or globalLuck.ExpiresAt or "N/A"))
    else
        table.insert(lines, "Global Luck: " .. tostring(globalLuck or "N/A"))
    end

    table.insert(lines, "Inventory: " .. (type(inventory) == "table" and "Available" or "N/A"))
    if capacity ~= nil then
        table.insert(lines, "Backpack Capacity: " .. tostring(capacity))
    end

    infoLabel.Text = table.concat(lines, "\n")
end

action(InfoPage, "Refresh Info", "↻", 4, updateInfo)

action(InfoPage, "Show Core Info", "i", 5, function()
    local ok = Adapter.action("ShowInfo")
    if not ok then
        updateInfo()
        notify("Info", "Core info adapter unavailable", 2)
    end
end)

-- ============================================================
-- SETTINGS
-- ============================================================

section(SettingsPage, "GENERAL", 1)

toggleRow(SettingsPage, "Anti AFK", 2,
    function() return State.AntiAFK end,
    Adapter.toggleAntiAFK)

action(SettingsPage, "Stop Extended Loops", "■", 4, function()
    local keys = {
        "AutoDig", "AutoClean", "AutoPolish", "AutoCollect",
        "AutoSell", "AutoAppraise", "AutoClaim", "AutoDeleteSpot",
        "AutoBuy", "AutoEquip", "AutoPolishCollect",
        "AutoPolisherUpgrade", "AutoPolisherUnlock"
    }

    local funcs = {
        Adapter.toggleAutoDig,
        Adapter.toggleAutoClean,
        Adapter.toggleAutoPolish,
        Adapter.toggleAutoCollect,
        Adapter.toggleAutoSell,
        Adapter.toggleAutoAppraise,
        Adapter.toggleAutoClaim,
        Adapter.toggleAutoDeleteSpot,
        Adapter.toggleAutoBuy,
        Adapter.toggleAutoEquip,
        Adapter.toggleAutoPolishCollect,
        Adapter.togglePolisherUpgrade,
        Adapter.togglePolisherUnlock
    }

    for i, key in ipairs(keys) do
        pcall(funcs[i], false)
    end

    notify("DigClean", "Extended loops stopped.", 2)
end)

action(SettingsPage, "Close Menu", "×", 5, function()
    Window.Visible = false
    OpenButton.Visible = true
    closePopups()
end)

-- ============================================================
-- FLOATING OPEN BUTTON
-- ============================================================

OpenButton = Instance.new("TextButton")
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
-- TOUCH/MOUSE DRAG HELPER
-- ============================================================

local function makeDraggable(handle, object)
    local dragging = false
    local moved = false
    local startInput
    local startPos
    local connection

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        moved = false
        startInput = input.Position
        startPos = object.Position

        if connection then connection:Disconnect() end

        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch
                and move.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local delta = move.Position - startInput

            if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
                moved = true
            end

            object.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
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

    return function()
        return moved
    end
end

makeDraggable(Header, Window)

do
    local dragging = false
    local moved = false
    local startInput
    local startPos
    local connection

    OpenButton.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        moved = false
        startInput = input.Position
        startPos = OpenButton.Position

        if connection then connection:Disconnect() end
        connection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end
            if move.UserInputType ~= Enum.UserInputType.Touch
                and move.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end
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
-- CLOSE POPUP WHEN TABS CHANGE / WINDOW MOVES
-- ============================================================

for _, tab in pairs(Tabs) do
    tab.Activated:Connect(function()
        closePopups()
    end)
end

-- ============================================================
-- PLAYER LIST MAINTENANCE
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    if State.SelectedTargetId == player.UserId then
        State.SelectedTargetId = nil
        State.SelectedTargetName = "None"
        sync("selectedTargetId", nil)
        sync("selectedTargetName", "None")
        refreshTargetButton()
    end
end)

-- ============================================================
-- VIEWPORT RESIZE
-- ============================================================

local viewportConnection
pcall(function()
    viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local w, h = getSize()
        if not Window.Visible then return end

        Window.Size = UDim2.fromOffset(w, h)
        Window.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
        closePopups()
    end)
end)

-- ============================================================
-- DEFAULT TAB / INFO
-- ============================================================

selectTab("MAIN")
task.defer(updateInfo)

notify("DigClean Tools", "Extended TAB UI loaded.", 3)
print("DigCleanTools_EXTENDED_FIXED loaded")
