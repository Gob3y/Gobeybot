-- ============================================================
-- DigCleanTools.lua
-- HAIMIYACH TAB UI TEMPLATE
-- Menambahkan sistem TAB agar fitur tidak tercampur.
--
-- Struktur:
--   MAIN     : fitur utama
--   TARGET   : target player & target mode
--   SELL     : filter & Auto Sell
--   ESP      : ESP
--   ACTION   : teleport / info
--   SETTINGS : Anti AFK & pengaturan
--
-- Cara pakai:
-- 1. Letakkan script core/fungsi DigClean kamu sebelum bagian UI ini.
-- 2. Jika fungsi sudah ada (toggleAutoDig, toggleAutoSell, dst),
--    UI di bawah akan langsung memakai fungsi tersebut.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    local old = PlayerGui:FindFirstChild("DigCleanTools")
    if old then old:Destroy() end
end)

-- ============================================================
-- FALLBACK STATE
-- Dipakai agar template tetap bisa dibuka walaupun core belum
-- ditempelkan. Jika core kamu sudah punya variabel/fungsi ini,
-- bagian ini tidak perlu diubah.
-- ============================================================

autoDigActive = autoDigActive or false
autoCleanActive = autoCleanActive or false
autoSellActive = autoSellActive or false
autoPolishActive = autoPolishActive or false
espActive = espActive or false
antiAFKActive = antiAFKActive == nil and true or antiAFKActive

digMode = digMode or "Normal"
digTargetMode = digTargetMode or "Nearest"
sellRarityFilter = sellRarityFilter or "common"
sellOnlyNonFavorited = sellOnlyNonFavorited == nil and true or sellOnlyNonFavorited
sellTargetMode = sellTargetMode or "All"
espTargetMode = espTargetMode or "All"
cleanTargetMode = cleanTargetMode or "Nearest"

selectedTargetId = selectedTargetId or nil
selectedTargetName = selectedTargetName or "None"

local function callIfExists(name, ...)
    local fn = _G[name]
    if type(fn) == "function" then
        return pcall(fn, ...)
    end
    return false
end

local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "DigClean"),
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end


-- ============================================================
-- EXTENDED FEATURES / SAFE CORE ADAPTER
-- Semua fitur tambahan memakai adapter aman. Jika core game belum
-- menyediakan fungsi terkait, toggle tetap bisa dibuka tanpa error.
-- ============================================================

autoBuyActive = autoBuyActive or false
autoEquipActive = autoEquipActive or false
autoAppraiseActive = autoAppraiseActive or false
autoClaimActive = autoClaimActive or false
autoDeleteSpotActive = autoDeleteSpotActive or false

buyPriority = buyPriority or "Shovel"
buyThreshold = tonumber(buyThreshold) or 1000
buyMode = buyMode or "Best"

equipPriority = equipPriority or "Power"
appraiseDelay = tonumber(appraiseDelay) or 2
appraiseRarityFilter = appraiseRarityFilter or "common"
claimType = claimType or "All"

local featureRunIds = {
    buy = 0, equip = 0, appraise = 0, claim = 0, deleteSpot = 0
}

local function safeGlobal(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
end

local function getDataSafe()
    if type(getInventoryData) == "function" then
        local ok, data = pcall(getInventoryData)
        if ok then return data end
    end
    return {}
end

local function getGoldSafe()
    if type(getGold) == "function" then
        local ok, value = pcall(getGold)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return 0
end

-- Tidak memakai daftar harga dummy. Harga/item ID harus berasal dari
-- game/core yang sebenarnya agar Auto Buy tidak membeli item salah.
local function getBestBuyCandidate()
    local candidates = {
        {"Shovel", "shovel"},
        {"Detector", "detector"},
        {"Spray", "spray"},
    }

    local order = {}
    if buyPriority == "Detector" then
        order = {candidates[2], candidates[1], candidates[3]}
    elseif buyPriority == "Spray" then
        order = {candidates[3], candidates[1], candidates[2]}
    else
        order = {candidates[1], candidates[2], candidates[3]}
    end

    -- Hook yang bisa disediakan oleh core:
    -- GetBestBuyCandidate(category, gold, threshold, mode)
    for _, entry in ipairs(order) do
        local ok, result = safeGlobal(
            "GetBestBuyCandidate",
            entry[1],
            getGoldSafe(),
            buyThreshold,
            buyMode
        )
        if ok and type(result) == "table" and result.id then
            return result
        end
    end

    return nil
end

local function performBuySafe()
    local gold = getGoldSafe()
    if gold < buyThreshold then return end

    local candidate = getBestBuyCandidate()
    if not candidate then return end

    -- Prioritas hook:
    -- BuyGear(category, itemId)
    local ok = safeGlobal("BuyGear", candidate.category, candidate.id)
    if ok then
        notify("Auto Buy", "Bought: " .. tostring(candidate.id), 2)
    end
end

local function performEquipSafe()
    -- Hook yang diharapkan:
    -- GetBestGear(category, priority) -> itemId
    -- EquipGear(category, itemId)
    for _, category in ipairs({"Shovel", "Detector", "Spray"}) do
        local ok, itemId = safeGlobal("GetBestGear", category, equipPriority)
        if ok and itemId then
            safeGlobal("EquipGear", category, itemId)
        end
    end
end

local function performAppraiseSafe()
    -- Hook:
    -- GetUnappraisedItems() -> array
    -- AppraiseItem(uid)
    local ok, items = safeGlobal("GetUnappraisedItems")
    if not ok or type(items) ~= "table" then return end

    for _, item in ipairs(items) do
        if type(item) == "table" and item.uid then
            safeGlobal("AppraiseItem", item.uid)
            task.wait(math.max(0.1, appraiseDelay))
        end
    end
end

local function performClaimSafe()
    -- Hook:
    -- ClaimAvailableRewards(claimType)
    safeGlobal("ClaimAvailableRewards", claimType)
end

local function performDeleteSpotSafe()
    -- Jangan Destroy object client-side secara paksa karena bisa membuat
    -- state client/game tidak sinkron. Gunakan hook game/core jika tersedia.
    safeGlobal("DeleteCompletedDigSpots")
end

local function startFeatureLoop(key, activeGetter, worker, delay)
    featureRunIds[key] = featureRunIds[key] + 1
    local runId = featureRunIds[key]

    task.spawn(function()
        while true do
            local active = false
            local ok = pcall(function() active = activeGetter() end)
            if not ok or not active or runId ~= featureRunIds[key] then
                break
            end

            pcall(worker)
            task.wait(delay)
        end
    end)
end

function toggleAutoBuy(enabled)
    autoBuyActive = enabled and true or false
    featureRunIds.buy = featureRunIds.buy + 1
    if autoBuyActive then
        startFeatureLoop("buy", function() return autoBuyActive end, performBuySafe, 10)
        notify("Auto Buy", "ON • " .. tostring(buyPriority), 2)
    else
        notify("Auto Buy", "OFF", 2)
    end
end

function setBuyPriority(value)
    if value == "Shovel" or value == "Detector" or value == "Spray" then
        buyPriority = value
    end
end

function setBuyThreshold(value)
    local n = tonumber(value)
    if n then buyThreshold = math.max(0, math.floor(n)) end
end

function toggleAutoEquip(enabled)
    autoEquipActive = enabled and true or false
    featureRunIds.equip = featureRunIds.equip + 1
    if autoEquipActive then
        startFeatureLoop("equip", function() return autoEquipActive end, performEquipSafe, 30)
        notify("Auto Equip", "ON • " .. tostring(equipPriority), 2)
    else
        notify("Auto Equip", "OFF", 2)
    end
end

function setEquipPriority(value)
    if value == "Power" or value == "Luck" or value == "Speed" then
        equipPriority = value
    end
end

function toggleAutoAppraise(enabled)
    autoAppraiseActive = enabled and true or false
    featureRunIds.appraise = featureRunIds.appraise + 1
    if autoAppraiseActive then
        startFeatureLoop("appraise", function() return autoAppraiseActive end, performAppraiseSafe, 5)
        notify("Auto Appraise", "ON • " .. tostring(appraiseRarityFilter), 2)
    else
        notify("Auto Appraise", "OFF", 2)
    end
end

function setAppraiseDelay(value)
    local n = tonumber(value)
    if n then appraiseDelay = math.clamp(n, 0.1, 30) end
end

function setAppraiseRarity(value)
    appraiseRarityFilter = value
end

function toggleAutoClaim(enabled)
    autoClaimActive = enabled and true or false
    featureRunIds.claim = featureRunIds.claim + 1
    if autoClaimActive then
        startFeatureLoop("claim", function() return autoClaimActive end, performClaimSafe, 10)
        notify("Auto Claim", "ON • " .. tostring(claimType), 2)
    else
        notify("Auto Claim", "OFF", 2)
    end
end

function setClaimType(value)
    claimType = value
end

function toggleAutoDeleteSpot(enabled)
    autoDeleteSpotActive = enabled and true or false
    featureRunIds.deleteSpot = featureRunIds.deleteSpot + 1
    if autoDeleteSpotActive then
        startFeatureLoop("deleteSpot", function() return autoDeleteSpotActive end, performDeleteSpotSafe, 2)
        notify("Auto Delete Spot", "ON", 2)
    else
        notify("Auto Delete Spot", "OFF", 2)
    end
end

-- ============================================================
-- GUI ROOT
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DigCleanTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

-- Ukuran dibuat aman untuk layar Android portrait maupun landscape.
local isPortrait = viewport.Y >= viewport.X
local guiWidth = math.clamp(math.floor(viewport.X * (isPortrait and 0.78 or 0.34)), 260, 360)
local guiHeight = math.clamp(math.floor(viewport.Y * (isPortrait and 0.66 or 0.72)), 360, 540)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.fromOffset(guiWidth, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui

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

corner(Window, 9)
stroke(Window, 0.2)

-- ============================================================
-- HEADER
-- ============================================================

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 43)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window
corner(Header, 9)

local HeaderFill = Instance.new("Frame")
HeaderFill.Size = UDim2.new(1, 0, 0, 10)
HeaderFill.Position = UDim2.new(0, 0, 1, -10)
HeaderFill.BackgroundColor3 = Header.BackgroundColor3
HeaderFill.BorderSizePixel = 0
HeaderFill.Parent = Header

local Brand = Instance.new("TextLabel")
Brand.Size = UDim2.new(1, -80, 0, 20)
Brand.Position = UDim2.fromOffset(12, 5)
Brand.BackgroundTransparency = 1
Brand.Text = "DIG&CLEAN"
Brand.TextColor3 = Color3.fromRGB(245, 246, 249)
Brand.Font = Enum.Font.GothamBold
Brand.TextSize = 12
Brand.TextXAlignment = Enum.TextXAlignment.Left
Brand.Parent = Header

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -80, 0, 12)
Sub.Position = UDim2.fromOffset(12, 26)
Sub.BackgroundTransparency = 1
Sub.Text = "TOOLS v2 • TAB EDITION"
Sub.TextColor3 = Color3.fromRGB(123, 126, 137)
Sub.Font = Enum.Font.GothamMedium
Sub.TextSize = 7
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(28, 28)
Close.Position = UDim2.new(1, -35, 0, 7)
Close.BackgroundColor3 = Color3.fromRGB(44, 45, 52)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(205, 207, 214)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header
corner(Close, 7)

-- ============================================================
-- TAB BAR
-- ============================================================

local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -12, 0, 38)
TabBar.Position = UDim2.fromOffset(6, 47)
TabBar.BackgroundColor3 = Color3.fromRGB(29, 30, 35)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new()
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = Window
corner(TabBar, 7)

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 4)
TabPadding.PaddingRight = UDim.new(0, 4)
TabPadding.PaddingTop = UDim.new(0, 5)
TabPadding.PaddingBottom = UDim.new(0, 5)
TabPadding.Parent = TabBar

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 4)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Parent = TabBar

-- ============================================================
-- PAGE AREA
-- ============================================================

local PageHolder = Instance.new("Frame")
PageHolder.Name = "Pages"
PageHolder.Size = UDim2.new(1, -12, 1, -91)
PageHolder.Position = UDim2.fromOffset(6, 88)
PageHolder.BackgroundTransparency = 1
PageHolder.ClipsDescendants = true
PageHolder.Parent = Window

local Pages = {}
local TabButtons = {}
local CurrentTab = nil

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(90, 93, 104)
    page.ScrollingEnabled = true
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = PageHolder

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 3)
    pad.PaddingRight = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    Pages[name] = page
    return page
end

local function makeTab(name, icon, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.fromOffset(72, 28)
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
    TabButtons[name] = btn
    return btn
end

local function selectTab(name)
    CurrentTab = name

    for tabName, page in pairs(Pages) do
        page.Visible = (tabName == name)
    end

    for tabName, btn in pairs(TabButtons) do
        local selected = tabName == name
        btn.BackgroundColor3 = selected
            and Color3.fromRGB(72, 74, 84)
            or Color3.fromRGB(43, 44, 51)
        btn.TextColor3 = selected
            and Color3.fromRGB(245, 246, 249)
            or Color3.fromRGB(164, 166, 175)
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
    label.LayoutOrder = order or 0
    label.Parent = page
    return label
end

local function action(page, text, icon, order, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.LayoutOrder = order or 0
    button.Parent = page
    corner(button, 7)
    stroke(button)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(26, 36)
    iconLabel.Position = UDim2.fromOffset(6, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(190, 193, 202)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 11
    iconLabel.Parent = button

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.fromOffset(34, 0)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = Color3.fromRGB(226, 228, 235)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 8
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = button

    button.Activated:Connect(function()
        if callback then pcall(callback) end
    end)

    return button
end

local function toggleRow(page, text, order, getter, setter)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
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
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(50, 23)
    toggle.Position = UDim2.new(1, -60, 0.5, -11)
    toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 7
    toggle.Parent = row
    corner(toggle, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(15, 15)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    corner(knob, 8)

    local function redraw()
        local enabled = false
        pcall(function() enabled = getter() end)

        toggle.Text = enabled and "ON" or "OFF"
        toggle.BackgroundColor3 = enabled
            and Color3.fromRGB(82, 84, 94)
            or Color3.fromRGB(45, 45, 48)
        toggle.TextColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(175, 177, 185)
        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(245, 245, 245)
            or Color3.fromRGB(165, 165, 170)
        knob.Position = enabled
            and UDim2.new(1, -19, 0.5, -7)
            or UDim2.fromOffset(4, 4)
    end

    toggle.Activated:Connect(function()
        local current = false
        pcall(function() current = getter() end)
        pcall(function() setter(not current) end)
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
    row.LayoutOrder = order or 0
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

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.53, -10, 0, 26)
    button.Position = UDim2.new(0.47, 0, 0.5, -13)
    button.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.TextColor3 = Color3.fromRGB(222, 224, 231)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 8
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = row
    corner(button, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollingEnabled = true
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.LayoutOrder = (order or 0) + 0.1
    list.Parent = page
    corner(list, 7)
    stroke(list)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    local function refresh()
        local value = "?"
        pcall(function() value = getter() end)
        button.Text = tostring(value)
    end

    for i, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -8, 0, 29)
        item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Text = "  " .. tostring(option)
        item.TextColor3 = Color3.fromRGB(222, 224, 231)
        item.Font = Enum.Font.Gotham
        item.TextSize = 8
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = i
        item.Parent = list
        corner(item, 5)

        item.Activated:Connect(function()
            pcall(function() setter(option) end)
            refresh()
            list.Visible = false
            list.Size = UDim2.new(1, 0, 0, 0)
        end)
    end

    button.Activated:Connect(function()
        local open = not list.Visible
        list.Visible = open
        list.Size = UDim2.new(1, 0, 0, open and math.min(#options * 32 + 5, 160) or 0)
        if open then refresh() end
    end)

    refresh()
    return row, button, list
end

-- ============================================================
-- TARGET SELECTOR
-- ============================================================

local function targetSelector(page, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = page
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.32, 0, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = "Target"
    label.TextColor3 = Color3.fromRGB(220, 222, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.64, -8, 0, 27)
    button.Position = UDim2.new(0.36, 0, 0.5, -13)
    button.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = "Select Player"
    button.TextColor3 = Color3.fromRGB(204, 206, 214)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 8
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.Parent = row
    corner(button, 6)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
    list.BorderSizePixel = 0
    list.Visible = false
    list.Active = true
    list.ScrollingEnabled = true
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.ScrollBarThickness = 3
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Parent = page
    corner(list, 7)
    stroke(list)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.Parent = list

    local function refresh()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        local count = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                count += 1
                local item = Instance.new("TextButton")
                item.Size = UDim2.new(1, -8, 0, 29)
                item.BackgroundColor3 =
                    (selectedTargetId == player.UserId)
                    and Color3.fromRGB(55, 65, 57)
                    or Color3.fromRGB(40, 41, 48)
                item.BorderSizePixel = 0
                item.AutoButtonColor = false
                item.Text = "  " .. player.DisplayName
                item.TextColor3 = Color3.fromRGB(220, 222, 230)
                item.Font = Enum.Font.Gotham
                item.TextSize = 8
                item.TextXAlignment = Enum.TextXAlignment.Left
                item.TextTruncate = Enum.TextTruncate.AtEnd
                item.Parent = list
                corner(item, 5)

                item.Activated:Connect(function()
                    selectedTargetId = player.UserId
                    selectedTargetName = player.DisplayName

                    if type(setSelectedTarget) == "function" then
                        pcall(setSelectedTarget, player.UserId)
                    end
                    if type(setDigTargetUserId) == "function" then
                        pcall(setDigTargetUserId, player.UserId)
                    end

                    button.Text = player.DisplayName
                    list.Visible = false
                    list.Size = UDim2.new(1, 0, 0, 0)
                    notify("Target", player.DisplayName .. " selected", 2)
                end)
            end
        end

        if count == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, -8, 0, 29)
            empty.BackgroundTransparency = 1
            empty.Text = "No players found"
            empty.TextColor3 = Color3.fromRGB(135, 138, 149)
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 8
            empty.TextXAlignment = Enum.TextXAlignment.Left
            empty.Parent = list
            count = 1
        end

        list.CanvasSize = UDim2.new(0, 0, 0, count * 32 + 5)

        if selectedTargetId then
            local p = Players:GetPlayerByUserId(selectedTargetId)
            button.Text = p and p.DisplayName or "Player unavailable"
        else
            button.Text = "Select Player"
        end
    end

    button.Activated:Connect(function()
        local open = not list.Visible
        list.Visible = open
        list.Size = UDim2.new(1, 0, 0, open and 130 or 0)
        if open then refresh() end
    end)

    Players.PlayerAdded:Connect(function()
        if list.Visible then task.defer(refresh) end
    end)
    Players.PlayerRemoving:Connect(function()
        if list.Visible then task.defer(refresh) end
    end)

    return row
end

-- ============================================================
-- CREATE TABS
-- ============================================================

local MainPage = makePage("MAIN")
local TargetPage = makePage("TARGET")
local SellPage = makePage("SELL")
local ESPPage = makePage("ESP")
local ActionPage = makePage("ACTION")
local SettingsPage = makePage("SETTINGS")

local mainTab = makeTab("MAIN", "◆", 1)
local targetTab = makeTab("TARGET", "◎", 2)
local sellTab = makeTab("SELL", "$", 3)
local espTab = makeTab("ESP", "◉", 4)
local actionTab = makeTab("ACTION", "↗", 5)
local settingsTab = makeTab("SETTINGS", "⚙", 6)

mainTab.Activated:Connect(function() selectTab("MAIN") end)
targetTab.Activated:Connect(function() selectTab("TARGET") end)
sellTab.Activated:Connect(function() selectTab("SELL") end)
espTab.Activated:Connect(function() selectTab("ESP") end)
actionTab.Activated:Connect(function() selectTab("ACTION") end)
settingsTab.Activated:Connect(function() selectTab("SETTINGS") end)

-- ============================================================
-- MAIN TAB
-- ============================================================

section(MainPage, "AUTOMATION", 1)

toggleRow(MainPage, "Auto Dig", 2,
    function() return autoDigActive end,
    function(v)
        if type(toggleAutoDig) == "function" then
            toggleAutoDig(v)
        else
            autoDigActive = v
        end
    end
)

toggleRow(MainPage, "Auto Clean", 3,
    function() return autoCleanActive end,
    function(v)
        if type(toggleAutoClean) == "function" then
            toggleAutoClean(v)
        else
            autoCleanActive = v
        end
    end
)

toggleRow(MainPage, "Auto Polish", 4,
    function() return autoPolishActive end,
    function(v)
        if type(toggleAutoPolish) == "function" then
            toggleAutoPolish(v)
        else
            autoPolishActive = v
        end
    end
)

dropdownRow(MainPage, "Dig Speed", 5,
    {"Normal", "Fast"},
    function() return digMode end,
    function(v)
        digMode = v
        if type(setDigMode) == "function" then pcall(setDigMode, v) end
    end
)

dropdownRow(MainPage, "Dig Target", 6,
    {"Nearest", "Target", "All"},
    function() return digTargetMode end,
    function(v)
        digTargetMode = v
        if type(setDigTargetMode) == "function" then pcall(setDigTargetMode, v) end
    end
)

dropdownRow(MainPage, "Clean Target", 7,
    {"Nearest", "Target"},
    function() return cleanTargetMode end,
    function(v)
        cleanTargetMode = v
        if type(setCleanTargetMode) == "function" then pcall(setCleanTargetMode, v) end
    end
)

-- ============================================================
-- TARGET TAB
-- ============================================================

section(TargetPage, "PLAYER TARGET", 1)
targetSelector(TargetPage, 2)

section(TargetPage, "TARGET MODE", 4)

dropdownRow(TargetPage, "Dig", 5,
    {"Nearest", "Target", "All"},
    function() return digTargetMode end,
    function(v)
        digTargetMode = v
        if type(setDigTargetMode) == "function" then pcall(setDigTargetMode, v) end
    end
)

dropdownRow(TargetPage, "Clean", 6,
    {"Nearest", "Target"},
    function() return cleanTargetMode end,
    function(v)
        cleanTargetMode = v
        if type(setCleanTargetMode) == "function" then pcall(setCleanTargetMode, v) end
    end
)

-- ============================================================
-- SELL TAB
-- ============================================================

section(SellPage, "AUTO SELL", 1)

toggleRow(SellPage, "Auto Sell", 2,
    function() return autoSellActive end,
    function(v)
        if type(toggleAutoSell) == "function" then
            toggleAutoSell(v)
        else
            autoSellActive = v
        end
    end
)

dropdownRow(SellPage, "Rarity", 3,
    {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},
    function() return sellRarityFilter end,
    function(v)
        sellRarityFilter = v
        if type(setSellRarity) == "function" then pcall(setSellRarity, v) end
    end
)

dropdownRow(SellPage, "Sell Mode", 4,
    {"All", "Held", "Filtered"},
    function() return sellTargetMode end,
    function(v)
        sellTargetMode = v
        if type(setSellTargetMode) == "function" then pcall(setSellTargetMode, v) end
    end
)

toggleRow(SellPage, "Only non-favorited", 5,
    function() return sellOnlyNonFavorited end,
    function(v)
        sellOnlyNonFavorited = v
        if type(setSellOnlyNonFavorited) == "function" then
            pcall(setSellOnlyNonFavorited, v)
        end
    end
)

-- ============================================================
-- ESP TAB
-- ============================================================

section(ESPPage, "DIG SPOT ESP", 1)

toggleRow(ESPPage, "ESP Dig Spot", 2,
    function() return espActive end,
    function(v)
        if type(toggleESP) == "function" then
            toggleESP(v)
        else
            espActive = v
        end
    end
)

dropdownRow(ESPPage, "ESP Mode", 3,
    {"All", "Nearest", "Target"},
    function() return espTargetMode end,
    function(v)
        espTargetMode = v
        if type(setESPTargetMode) == "function" then pcall(setESPTargetMode, v) end
    end
)

-- ============================================================
-- ACTION TAB
-- ============================================================

section(ActionPage, "TELEPORT", 1)

action(ActionPage, "Teleport to Plot", "↗", 2,
    function()
        if type(teleportToPlot) == "function" then
            pcall(teleportToPlot)
        else
            notify("Teleport", "teleportToPlot belum tersedia", 2)
        end
    end
)

action(ActionPage, "Teleport to Target", "↗", 3,
    function()
        if type(teleportToTarget) == "function" then
            pcall(teleportToTarget)
        else
            notify("Teleport", "teleportToTarget belum tersedia", 2)
        end
    end
)

action(ActionPage, "Teleport to Seller", "↗", 4,
    function()
        if type(teleportToSeller) == "function" then
            pcall(teleportToSeller)
        else
            notify("Teleport", "teleportToSeller belum tersedia", 2)
        end
    end
)

section(ActionPage, "INFO", 6)

action(ActionPage, "Show Info", "i", 7,
    function()
        if type(showInfo) == "function" then
            pcall(showInfo)
        else
            notify("Info", "showInfo belum tersedia", 2)
        end
    end
)

-- ============================================================
-- SETTINGS TAB
-- ============================================================

section(SettingsPage, "SETTINGS", 1)

toggleRow(SettingsPage, "Anti AFK", 2,
    function() return antiAFKActive end,
    function(v)
        if type(toggleAntiAFK) == "function" then
            toggleAntiAFK(v)
        else
            antiAFKActive = v
        end
    end
)

action(SettingsPage, "Reload UI", "↻", 4,
    function()
        notify("DigClean", "UI sudah menggunakan sistem TAB.", 2)
    end
)

action(SettingsPage, "Close Menu", "×", 5,
    function()
        Window.Visible = false
        OpenButton.Visible = true
    end
)

-- ============================================================
-- FLOATING REOPEN BUTTON
-- ============================================================

OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(88, 30)
OpenButton.Position = UDim2.new(0.5, -44, 0, 8)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BackgroundTransparency = 0.15
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "DIG&CLEAN"
OpenButton.TextColor3 = Color3.fromRGB(240, 241, 245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 8
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui
corner(OpenButton, 16)
stroke(OpenButton, 0.25)

Close.Activated:Connect(function()
    Window.Visible = false
    OpenButton.Visible = true
end)

local floatingDragging = false
local floatingMoved = false
local floatingStart
local floatingPos
local floatingConnection

OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    floatingDragging = true
    floatingMoved = false
    floatingStart = input.Position
    floatingPos = OpenButton.Position

    if floatingConnection then
        floatingConnection:Disconnect()
    end

    floatingConnection = UserInputService.InputChanged:Connect(function(move)
        if not floatingDragging then return end
        if move.UserInputType ~= Enum.UserInputType.Touch
            and move.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = move.Position - floatingStart

        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            floatingMoved = true
        end

        OpenButton.Position = UDim2.new(
            floatingPos.X.Scale,
            floatingPos.X.Offset + delta.X,
            floatingPos.Y.Scale,
            floatingPos.Y.Offset + delta.Y
        )
    end)

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            local moved = floatingMoved
            floatingDragging = false

            if floatingConnection then
                floatingConnection:Disconnect()
                floatingConnection = nil
            end

            if not moved then
                Window.Visible = true
                OpenButton.Visible = false
            end
        end
    end)
end)

-- ============================================================
-- WINDOW DRAG
-- ============================================================

local dragging = false
local dragStart
local dragPos
local dragConnection

Header.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    dragging = true
    dragStart = input.Position
    dragPos = Window.Position

    if dragConnection then dragConnection:Disconnect() end

    dragConnection = UserInputService.InputChanged:Connect(function(move)
        if not dragging then return end
        if move.UserInputType ~= Enum.UserInputType.Touch
            and move.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = move.Position - dragStart

        Window.Position = UDim2.new(
            dragPos.X.Scale,
            dragPos.X.Offset + delta.X,
            dragPos.Y.Scale,
            dragPos.Y.Offset + delta.Y
        )
    end)

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
            if dragConnection then
                dragConnection:Disconnect()
                dragConnection = nil
            end
        end
    end)
end)


-- ============================================================
-- BUILD TABS
-- ============================================================

local MainPage    = makePage("MAIN")
local TargetPage  = makePage("TARGET")
local SellPage    = makePage("SELL")
local ESPPage     = makePage("ESP")
local ActionPage  = makePage("ACTION")
local SettingsPage= makePage("SETTINGS")

makeTab("MAIN", "⚙", 1).Activated:Connect(function() selectTab("MAIN") end)
makeTab("TARGET", "◎", 2).Activated:Connect(function() selectTab("TARGET") end)
makeTab("SELL", "◆", 3).Activated:Connect(function() selectTab("SELL") end)
makeTab("ESP", "◉", 4).Activated:Connect(function() selectTab("ESP") end)
makeTab("ACTION", "↗", 5).Activated:Connect(function() selectTab("ACTION") end)
makeTab("SETTINGS", "☰", 6).Activated:Connect(function() selectTab("SETTINGS") end)

-- MAIN
section(MainPage, "AUTOMATION", 1)
toggleRow(MainPage, "Auto Dig", 2,
    function() return autoDigActive end,
    function(v) callIfExists("toggleAutoDig", v) end)
toggleRow(MainPage, "Auto Clean", 3,
    function() return autoCleanActive end,
    function(v) callIfExists("toggleAutoClean", v) end)
toggleRow(MainPage, "Auto Polish", 4,
    function() return autoPolishActive end,
    function(v) callIfExists("toggleAutoPolish", v) end)

dropdownRow(MainPage, "Dig Speed", 5, {"Normal", "Fast"},
    function() return digMode end,
    function(v) digMode = v; callIfExists("setDigMode", v) end)

dropdownRow(MainPage, "Dig Target", 6, {"Nearest", "Target", "All"},
    function() return digTargetMode end,
    function(v) digTargetMode = v; callIfExists("setDigTargetMode", v) end)

section(MainPage, "AUTO BUY / EQUIP", 10)
toggleRow(MainPage, "Auto Buy", 11,
    function() return autoBuyActive end,
    toggleAutoBuy)
dropdownRow(MainPage, "Buy Priority", 12, {"Shovel", "Detector", "Spray"},
    function() return buyPriority end,
    setBuyPriority)
dropdownRow(MainPage, "Buy Mode", 13, {"Best", "Next", "All"},
    function() return buyMode end,
    function(v) buyMode = v end)
action(MainPage, "Set Gold Threshold", "G", 14, function()
    -- Tanpa TextBox popup yang rawan bug executor.
    -- Nilai default aman; core dapat mengubahnya lewat setBuyThreshold().
    notify("Gold Threshold", "Current: " .. tostring(buyThreshold) .. " gold", 2)
end)

toggleRow(MainPage, "Auto Equip", 15,
    function() return autoEquipActive end,
    toggleAutoEquip)
dropdownRow(MainPage, "Equip Priority", 16, {"Power", "Luck", "Speed"},
    function() return equipPriority end,
    setEquipPriority)

section(MainPage, "ITEM", 20)
toggleRow(MainPage, "Auto Appraise", 21,
    function() return autoAppraiseActive end,
    toggleAutoAppraise)
dropdownRow(MainPage, "Appraise Rarity", 22,
    {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},
    function() return appraiseRarityFilter end,
    setAppraiseRarity)
dropdownRow(MainPage, "Appraise Delay", 23,
    {"0.5","1","2","3","5"},
    function() return tostring(appraiseDelay) end,
    function(v) setAppraiseDelay(v) end)

toggleRow(MainPage, "Auto Claim", 24,
    function() return autoClaimActive end,
    toggleAutoClaim)
dropdownRow(MainPage, "Claim Type", 25, {"All", "Quest", "Journal", "Daily"},
    function() return claimType end,
    setClaimType)

toggleRow(MainPage, "Auto Delete Spot", 26,
    function() return autoDeleteSpotActive end,
    toggleAutoDeleteSpot)

-- TARGET
section(TargetPage, "TARGET PLAYER", 1)
local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(1, 0, 0, 38)
targetLabel.BackgroundColor3 = Color3.fromRGB(34,35,41)
targetLabel.BorderSizePixel = 0
targetLabel.Text = "Selected Target: " .. tostring(selectedTargetName or "None")
targetLabel.TextColor3 = Color3.fromRGB(226,228,235)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 9
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.LayoutOrder = 2
targetLabel.Parent = TargetPage
corner(targetLabel, 7)
stroke(targetLabel)

action(TargetPage, "Refresh / Select Target", "◎", 3, function()
    -- Bila core menyediakan buildTargetSelector/get target UI, panggil.
    if type(buildTargetSelector) == "function" then
        pcall(buildTargetSelector)
    else
        notify("Target", "Gunakan target selector dari core.", 2)
    end
end)

dropdownRow(TargetPage, "Clean Target", 4, {"Nearest", "Target"},
    function() return cleanTargetMode end,
    function(v) cleanTargetMode = v; callIfExists("setCleanTargetMode", v) end)

-- SELL
section(SellPage, "AUTO SELL", 1)
toggleRow(SellPage, "Auto Sell", 2,
    function() return autoSellActive end,
    function(v) callIfExists("toggleAutoSell", v) end)

dropdownRow(SellPage, "Rarity Filter", 3,
    {"common","uncommon","rare","epic","legendary","mythic","divine","eternal","transcendent","omega"},
    function() return sellRarityFilter end,
    function(v) sellRarityFilter = v; callIfExists("setSellRarity", v) end)

dropdownRow(SellPage, "Sell Mode", 4, {"All", "Held", "Filtered"},
    function() return sellTargetMode end,
    function(v) sellTargetMode = v; callIfExists("setSellTargetMode", v) end)

toggleRow(SellPage, "Only Non-Favorited", 5,
    function() return sellOnlyNonFavorited end,
    function(v) sellOnlyNonFavorited = v; callIfExists("setSellOnlyNonFavorited", v) end)

-- ESP
section(ESPPage, "VISUAL", 1)
toggleRow(ESPPage, "ESP Dig Spot", 2,
    function() return espActive end,
    function(v) callIfExists("toggleESP", v) end)
dropdownRow(ESPPage, "ESP Mode", 3, {"All", "Nearest", "Target"},
    function() return espTargetMode end,
    function(v) espTargetMode = v; callIfExists("setESPTargetMode", v) end)

-- ACTION
section(ActionPage, "TELEPORT", 1)
action(ActionPage, "Teleport to Plot", "↗", 2, function() callIfExists("teleportToPlot") end)
action(ActionPage, "Teleport to Target", "↗", 3, function() callIfExists("teleportToTarget") end)
action(ActionPage, "Teleport to Seller", "↗", 4, function() callIfExists("teleportToSeller") end)
section(ActionPage, "INFO", 10)
action(ActionPage, "Show Info", "i", 11, function() callIfExists("showInfo") end)

-- SETTINGS
section(SettingsPage, "GENERAL", 1)
toggleRow(SettingsPage, "Anti AFK", 2,
    function() return antiAFKActive end,
    function(v) callIfExists("toggleAntiAFK", v) end)

action(SettingsPage, "Reload UI", "↻", 3, function()
    notify("DigClean", "UI reload membutuhkan re-execute script.", 2)
end)

action(SettingsPage, "Stop Added Loops", "■", 4, function()
    autoBuyActive = false
    autoEquipActive = false
    autoAppraiseActive = false
    autoClaimActive = false
    autoDeleteSpotActive = false
    for k in pairs(featureRunIds) do
        featureRunIds[k] = featureRunIds[k] + 1
    end
    notify("DigClean", "Added automation loops stopped.", 2)
end)


-- ============================================================
-- DEFAULT TAB
-- ============================================================

selectTab("MAIN")

task.defer(function()
    notify("DigClean Tools", "TAB UI loaded.", 3)
end)

print("DigClean Tools - TAB UI loaded")
