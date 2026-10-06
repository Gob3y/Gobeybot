
-- ============================================================
-- GOBEY HUB | ANIME DICE AUTO FARM v2.1
-- Author  : GOBEY
-- Features: Buy Dice/Collect/Place/Level/Sell/Fuse(Mode)/Grade/
--           Trait/Rebirth/Upgrade/Quest/Redeem/Tower(Rotate)/
--           Shop/Equip/Stat/Potion/Gear/Spin/Daily/TowerTeam/
--           LevelEquipped/SkipCutscene/ServerHop/LagFix/DeleteMap
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local LocalPlayer       = Players.LocalPlayer

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local Remotes, RemoteFunctions, RemoteList = {}, {}, {}

local function scanContainer(container, prefix)
    if not container then return end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            Remotes[obj.Name] = obj
            table.insert(RemoteList, {name=obj.Name, path=prefix..obj.Name, obj=obj, type="Event"})
        elseif obj:IsA("RemoteFunction") then
            RemoteFunctions[obj.Name] = obj
            table.insert(RemoteList, {name=obj.Name, path=prefix..obj.Name, obj=obj, type="Function"})
        end
    end
end

local function discoverRemotes()
    Remotes, RemoteFunctions, RemoteList = {}, {}, {}
    scanContainer(ReplicatedStorage, "RS.")
    scanContainer(Workspace, "WS.")
end
discoverRemotes()

local function findRemoteAll(keywords)
    local found = {}
    for name, remote in pairs(Remotes) do
        local lower = string.lower(name)
        for _, kw in ipairs(keywords) do
            if string.find(lower, string.lower(kw), 1, true) then
                table.insert(found, remote); break
            end
        end
    end
    return found
end

local function fireAll(keywords, ...)
    local candidates = findRemoteAll(keywords)
    if #candidates == 0 then return false end
    local args = table.pack(...)
    for _, remote in ipairs(candidates) do
        pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
    end
    return true
end

local function clickGuiButton(nameKw, textKw)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local n = string.lower(gui.Name or "")
            local t = gui:IsA("TextButton") and string.lower(gui.Text or "") or ""
            local match = false
            if nameKw then for _, kw in ipairs(nameKw) do if string.find(n, string.lower(kw), 1, true) then match = true; break end end end
            if not match and textKw then for _, kw in ipairs(textKw) do if string.find(t, string.lower(kw), 1, true) then match = true; break end end end
            if match then
                pcall(function() gui:Activate() end)
                pcall(function() firesignal(gui.MouseButton1Click) end)
                return true
            end
        end
    end
    return false
end

-- ============================================================
-- UI FRAMEWORK
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GOBEY_HUB_AnimeDice"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 620, 0, 520)
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.new(0.5, 0, 0.5, 0)
Window.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Window.BorderSizePixel = 0
Window.Parent = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", Window)
stroke.Color = Color3.fromRGB(120, 60, 200)
stroke.Thickness = 1.5

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 20, 44)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "GOBEY HUB | ANIME DICE v2.1"
TitleLabel.TextColor3 = Color3.fromRGB(200, 140, 255)
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -74, 0.5, -16)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar

local MiniBar = Instance.new("Frame")
MiniBar.Size = UDim2.new(0, 260, 0, 40)
MiniBar.AnchorPoint = Vector2.new(0.5, 0.5)
MiniBar.Position = Window.Position
MiniBar.BackgroundColor3 = Color3.fromRGB(28, 20, 44)
MiniBar.BorderSizePixel = 0
MiniBar.Visible = false
MiniBar.Parent = ScreenGui
Instance.new("UICorner", MiniBar).CornerRadius = UDim.new(0, 16)
Instance.new("UIStroke", MiniBar).Color = Color3.fromRGB(120, 60, 200)

local MiniTitle = Instance.new("TextLabel")
MiniTitle.Size = UDim2.new(1, -70, 1, 0)
MiniTitle.Position = UDim2.new(0, 16, 0, 0)
MiniTitle.BackgroundTransparency = 1
MiniTitle.Text = "GOBEY HUB"
MiniTitle.TextColor3 = Color3.fromRGB(200, 140, 255)
MiniTitle.Font = Enum.Font.GothamBlack
MiniTitle.TextSize = 13
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

local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(0, 135, 1, -56)
TabBar.Position = UDim2.new(0, 8, 0, 50)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 4
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabBar.CanvasSize = UDim2.fromOffset(0, 0)
TabBar.Parent = Window
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 6)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -155, 1, -60)
Content.Position = UDim2.new(0, 150, 0, 50)
Content.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
Content.BorderSizePixel = 0
Content.Parent = Window
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 8)

local Tabs, TabButtons = {}, {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = Color3.fromRGB(120, 60, 200)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromOffset(0, 0)
    page.Visible = false
    page.Parent = Content

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5); layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Tabs) do p.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(36, 36, 46); b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(80, 40, 140); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    table.insert(Tabs, page); TabButtons[name] = btn
    return page
end

local function addSection(page, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,22); l.BackgroundTransparency = 1
    l.Text = "▸ "..text; l.TextColor3 = Color3.fromRGB(200, 140, 255)
    l.Font = Enum.Font.GothamBlack; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = page; return l
end

local function addLabel(page, text, h)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,h or 32); l.BackgroundColor3 = Color3.fromRGB(36,36,44)
    l.BorderSizePixel = 0; l.Text = "  "..text; l.TextColor3 = Color3.fromRGB(210,210,210)
    l.Font = Enum.Font.Gotham; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true; l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = page; Instance.new("UICorner", l).CornerRadius = UDim.new(0,8)
    return l
end

local function addToggle(page, text, default, callback)
    local value = default and true or false
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,40); f.BackgroundColor3 = Color3.fromRGB(36,36,44)
    f.BorderSizePixel = 0; f.Parent = page
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-70,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.fromRGB(215,215,215)
    l.Font = Enum.Font.Gotham; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local t = Instance.new("Frame")
    t.Size = UDim2.new(0,48,0,24); t.Position = UDim2.new(1,-60,0.5,-12)
    t.BackgroundColor3 = value and Color3.fromRGB(140, 70, 220) or Color3.fromRGB(60,60,60)
    t.BorderSizePixel = 0; t.Parent = f
    Instance.new("UICorner", t).CornerRadius = UDim.new(1,0)

    local k = Instance.new("Frame")
    k.Size = UDim2.new(0,20,0,20)
    k.Position = value and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
    k.BackgroundColor3 = Color3.fromRGB(255,255,255)
    k.BorderSizePixel = 0; k.Parent = t
    Instance.new("UICorner", k).CornerRadius = UDim.new(1,0)

    t.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            value = not value
            t.BackgroundColor3 = value and Color3.fromRGB(140, 70, 220) or Color3.fromRGB(60,60,60)
            k.Position = value and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
            if callback then task.spawn(function() pcall(callback, value) end) end
        end
    end)
    return {Set=function(v) value=v end, Get=function() return value end}
end

local function addButton(page, text, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,38); b.BackgroundColor3 = Color3.fromRGB(48,40,64)
    b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = Color3.fromRGB(220,200,255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.Parent = page
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(140, 70, 220); s.Thickness = 1
    b.MouseButton1Click:Connect(function()
        if callback then task.spawn(function() pcall(callback) end) end
    end)
    return b
end

local function addSlider(page, text, min, max, default, callback)
    min, max = min or 0, max or 100
    default = default or min
    local value = math.clamp(default, min, max)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,50); f.BackgroundColor3 = Color3.fromRGB(36,36,44)
    f.BorderSizePixel = 0; f.Parent = page
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6,-12,0,20); l.Position = UDim2.new(0,12,0,4)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.fromRGB(215,215,215)
    l.Font = Enum.Font.Gotham; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0.4,-12,0,20); vl.Position = UDim2.new(0.6,0,0,4)
    vl.BackgroundTransparency = 1; vl.Text = tostring(value); vl.TextColor3 = Color3.fromRGB(200,140,255)
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 10; vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = f

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1,-24,0,10); bar.Position = UDim2.new(0,12,0,32)
    bar.BackgroundColor3 = Color3.fromRGB(24,24,30); bar.BorderSizePixel = 0
    bar.Text = ""; bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(140, 70, 220); fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local dragging = false
    local function setFromX(x)
        local ax = bar.AbsolutePosition.X
        local w = math.max(1, bar.AbsoluteSize.X)
        local pct = math.clamp((x-ax)/w, 0, 1)
        value = min + (max-min)*pct
        if max-min >= 10 then value = math.floor(value+0.5) end
        fill.Size = UDim2.new(pct,0,1,0)
        vl.Text = string.format("%.2f", value)
        if callback then task.spawn(function() pcall(callback, value) end) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setFromX(input.Position.X)
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
    end)
    return {Set=function(v) value=math.clamp(v,min,max); fill.Size=UDim2.new((value-min)/(max-min),0,1,0); vl.Text=string.format("%.2f",value) end, Get=function() return value end}
end

-- ============================================================
-- DROPDOWN
-- ============================================================
local ddZ = 10
local function addDropdown(page, label, options, default, multi, callback)
    options = options or {}
    local selected, current = {}, default
    if multi and type(default)=="table" then
        for k,v in pairs(default) do if v==true then selected[k]=true elseif type(v)=="string" then selected[v]=true end end
    end
    ddZ = ddZ + 5

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,44); row.BackgroundColor3 = Color3.fromRGB(36,36,44)
    row.BorderSizePixel = 0; row.ZIndex = ddZ
    row.Parent = page
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4,-12,1,0); lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = Color3.fromRGB(215,215,215)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = ddZ; lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.6,-18,0,30); btn.Position = UDim2.new(0.4,6,0.5,-15)
    btn.BackgroundColor3 = Color3.fromRGB(24,24,30); btn.BorderSizePixel = 0
    btn.Text = ""; btn.AutoButtonColor = false; btn.ZIndex = ddZ+1; btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local btnText = Instance.new("TextLabel")
    btnText.Size = UDim2.new(1,-30,1,0); btnText.Position = UDim2.new(0,8,0,0)
    btnText.BackgroundTransparency = 1; btnText.Text = "SELECT"
    btnText.TextColor3 = Color3.fromRGB(215,215,215); btnText.Font = Enum.Font.GothamBold
    btnText.TextSize = 10; btnText.TextXAlignment = Enum.TextXAlignment.Left
    btnText.TextTruncate = Enum.TextTruncate.AtEnd; btnText.ZIndex = ddZ+1; btnText.Parent = btn

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0,24,1,0); arrow.Position = UDim2.new(1,-26,0,0)
    arrow.BackgroundTransparency = 1; arrow.Text = "v"; arrow.TextColor3 = Color3.fromRGB(160,160,160)
    arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 11; arrow.ZIndex = ddZ+1; arrow.Parent = btn

    local list = Instance.new("ScrollingFrame")
    list.BackgroundColor3 = Color3.fromRGB(18,18,22); list.BorderSizePixel = 0
    list.ScrollBarThickness = 4; list.ScrollBarImageColor3 = Color3.fromRGB(120,60,200)
    list.CanvasSize = UDim2.fromOffset(0,0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Visible = false; list.ZIndex = 5000; list.ClipsDescendants = true
    list.Size = UDim2.new(0, 200, 0, 0)
    list.Parent = ScreenGui
    Instance.new("UICorner", list).CornerRadius = UDim.new(0,6)
    local lStroke = Instance.new("UIStroke", list)
    lStroke.Color = Color3.fromRGB(120,60,200); lStroke.Thickness = 1

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0,3); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list

    local lp = Instance.new("UIPadding")
    lp.PaddingTop = UDim.new(0,5); lp.PaddingBottom = UDim.new(0,5)
    lp.PaddingLeft = UDim.new(0,5); lp.PaddingRight = UDim.new(0,5)
    lp.Parent = list

    local function selText()
        if multi then
            local arr = {}
            for _,op in ipairs(options) do if selected[op] then table.insert(arr,op) end end
            if #arr==0 then return "NONE" end
            if #arr==1 then return arr[1] end
            return tostring(#arr).." SELECTED"
        else return tostring(current or options[1] or "SELECT") end
    end

    local function emit()
        btnText.Text = selText()
        if callback then
            if multi then
                local c = {}; for k,v in pairs(selected) do c[k]=v end
                task.spawn(function() pcall(callback, c) end)
            else task.spawn(function() pcall(callback, current) end) end
        end
    end

    local function openList()
        local ap = btn.AbsolutePosition
        local as = btn.AbsoluteSize
        local h = math.min(220, ll.AbsoluteContentSize.Y + 14)
        if h < 30 then h = 30 end
        list.Position = UDim2.fromOffset(ap.X, ap.Y + as.Y + 2)
        list.Size = UDim2.fromOffset(as.X, h)
        list.Visible = true
        list.ZIndex = 5000
    end

    local function closeList() list.Visible = false end

    local function rebuild()
        for _,ch in ipairs(list:GetChildren()) do
            if ch:IsA("TextButton") or ch:IsA("TextLabel") then ch:Destroy() end
        end
        if #options == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1,-4,0,26); empty.BackgroundTransparency = 1
            empty.Text = "(kosong - refresh)"; empty.TextColor3 = Color3.fromRGB(140,140,140)
            empty.Font = Enum.Font.Gotham; empty.TextSize = 10; empty.Parent = list
            return
        end
        local o = 1
        for _,op in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1,-4,0,26)
            item.BackgroundColor3 = (multi and selected[op] or current==op) and Color3.fromRGB(140,70,220) or Color3.fromRGB(38,38,46)
            item.BorderSizePixel = 0; item.Text = tostring(op)
            item.TextColor3 = Color3.fromRGB(215,215,215); item.Font = Enum.Font.GothamBold
            item.TextSize = 10; item.LayoutOrder = o; o=o+1; item.ZIndex = 5001
            item.Parent = list
            Instance.new("UICorner", item).CornerRadius = UDim.new(0,5)
            item.MouseButton1Click:Connect(function()
                if multi then selected[op] = not selected[op] or nil
                else current = op; closeList() end
                rebuild(); emit()
                if multi and list.Visible then openList() end
            end)
        end
        task.defer(function() if list.Visible then openList() end end)
    end

    btn.MouseButton1Click:Connect(function()
        if list.Visible then closeList() else openList() end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if list.Visible then
                local mx, my = input.Position.X, input.Position.Y
                local lp2 = list.AbsolutePosition
                local ls = list.AbsoluteSize
                local bp = btn.AbsolutePosition
                local bs = btn.AbsoluteSize
                local insideList = mx >= lp2.X and mx <= lp2.X+ls.X and my >= lp2.Y and my <= lp2.Y+ls.Y
                local insideBtn  = mx >= bp.X  and mx <= bp.X+bs.X  and my >= bp.Y  and my <= bp.Y+bs.Y
                if not insideList and not insideBtn then closeList() end
            end
        end
    end)

    rebuild()
    if not multi and not current and #options>0 then current = options[1] end
    btnText.Text = selText()

    return {
        SetOptions = function(no) options = no or {}; rebuild(); emit() end,
        Get = function() return multi and selected or current end,
        Set = function(v,c)
            if multi then
                selected = {}
                if type(v)=="table" then for k,val in pairs(v) do if val==true then selected[k]=true elseif type(val)=="string" then selected[val]=true end end end
            else current = v end
            rebuild(); if c~=false then emit() end
        end,
    }
end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=tostring(title or "GOBEY HUB"), Text=tostring(text or ""), Duration=tonumber(dur) or 3})
    end)
end

-- ============================================================
-- UNIT SCAN
-- ============================================================
local function getPlot()
    for _, name in ipairs({"Plots","PlotFolder","PlotsFolder","Plot"}) do
        local p = Workspace:FindFirstChild(name)
        if p then
            for _, plot in ipairs(p:GetChildren()) do
                local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerUserId") or plot:GetAttribute("UserId")
                if owner == LocalPlayer.UserId then return plot end
            end
        end
    end
    return nil
end

local function getUnits()
    local out, seen = {}, {}
    local plot = getPlot()
    local roots = {}
    if plot then table.insert(roots, plot) end
    for _, name in ipairs({"Plots","PlotFolder","Units"}) do
        local f = Workspace:FindFirstChild(name)
        if f then table.insert(roots, f) end
    end
    for _, root in ipairs(roots) do
        for _, u in ipairs(root:GetDescendants()) do
            if (u:IsA("Model") or u:IsA("Folder")) and not seen[u] then
                local uName = u:GetAttribute("UnitName") or u:GetAttribute("Name")
                local uId   = u:GetAttribute("UnitId") or u:GetAttribute("Id")
                local power = tonumber(u:GetAttribute("Power")) or tonumber(u:GetAttribute("Damage")) or 0
                if (uName or uId) and u:FindFirstChildWhichIsA("BasePart", true) then
                    seen[u] = true
                    table.insert(out, {model=u, name=tostring(uName or uId or u.Name), id=uId, power=power})
                end
            end
        end
    end
    table.sort(out, function(a,b) return a.power > b.power end)
    return out
end

local function getUnitNames()
    local names, seen = {}, {}
    local function add(n)
        n = tostring(n)
        if n ~= "" and not seen[n] then seen[n]=true; table.insert(names,n) end
    end
    for _, u in ipairs(getUnits()) do add(u.name) end
    pcall(function()
        for _, fn in ipairs({"Units","UnitData","Dice","Assets","UnitFolder","Index","Inventory"}) do
            local f = ReplicatedStorage:FindFirstChild(fn)
            if f then
                for _, c in ipairs(f:GetChildren()) do add(c.Name) end
                for _, c in ipairs(f:GetDescendants()) do
                    if c:IsA("ModuleScript") or c:IsA("Folder") or c:IsA("Configuration") then add(c.Name) end
                end
            end
        end
    end)
    table.sort(names)
    if #names == 0 then names = {"Unit1","Unit2","Unit3","Unit4","Unit5"} end
    return names
end

-- ============================================================
-- DYNAMIC LISTS
-- ============================================================
local function scanRS(names)
    local out, seen = {}, {}
    pcall(function()
        for _, fn in ipairs(names) do
            local f = ReplicatedStorage:FindFirstChild(fn)
            if f then
                for _, c in ipairs(f:GetChildren()) do
                    if not seen[c.Name] then seen[c.Name]=true; table.insert(out, c.Name) end
                end
                for _, c in ipairs(f:GetDescendants()) do
                    if (c:IsA("ModuleScript") or c:IsA("Folder") or c:IsA("StringValue") or c:IsA("Configuration"))
                       and not seen[c.Name] then
                        seen[c.Name]=true; table.insert(out, c.Name)
                    end
                end
            end
        end
    end)
    table.sort(out)
    return out
end

local function getDiceList()
    local dice = scanRS({"Dice","Dices","DiceData","Rolls","Gacha","Eggs","Packs"})
    pcall(function()
        for _, o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("Part") or o:IsA("Model")) and string.find(string.lower(o.Name),"dice") then
                if not table.find(dice, o.Name) then table.insert(dice, o.Name) end
            end
        end
    end)
    if #dice==0 then dice = {"Basic Dice","Lucky Dice","Golden Dice","Mythic Dice","Legendary Dice"} end
    return dice
end

local function getAuraList()
    local a = scanRS({"Aura","Auras","AuraData","AuraFolder","Visuals","Effects"})
    pcall(function()
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("PointLight") and o.Name=="Aura" and o.Parent then
                if not table.find(a, o.Parent.Name) then table.insert(a, o.Parent.Name) end
            end
        end
    end)
    if #a==0 then a = {"Default","Fire","Ice","Lightning","Shadow","Divine"} end
    return a
end

local function getSkinList()
    local s = scanRS({"Skin","Skins","SkinData","SkinFolder","Cosmetics"})
    if #s==0 then s = {"Default","Cape","Hair","Face","Wings"} end
    return s
end

local function getAccessoryList()
    return {"Hair","Cape","Hat","Face","Wings","Shirt","Pants"}
end

local function getTraitList()
    local t = scanRS({"Trait","Traits","TraitData","TraitList","TraitsFolder"})
    if #t==0 then t = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Godly","Divine","Secret"} end
    return t
end

local function getGradeList()
    return {"D","C","B","A","S","S+","SS","SSS","UR","LR","Mythic"}
end

local function getStatList()
    return {"Damage","Income","Speed","Range","Luck","Health","Cooldown"}
end

local function getQuestList()
    local q = scanRS({"Quests","QuestData","DailyQuests","Missions","Tasks"})
    if #q==0 then q = {"Daily","Weekly","Main","Boss Quest","Event"} end
    return q
end

local function getShopItemList()
    local s = scanRS({"Shop","ShopItems","Store","Items","Purchases"})
    if #s==0 then s = {"Item 1","Item 2","Item 3","Item 4"} end
    return s
end

local function getUpgradeList()
    return {"Money Multiplier","Luck","Roll Speed","Auto Roll","Slot","Team Size","Rebirth Boost"}
end

local function getRarityList()
    return {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret","Exclusive","Limited"}
end

local function getTowerList()
    local t = scanRS({"Towers","TowerData","TowerFolder","Tower","TowerConfig","Modes","Stages"})
    pcall(function()
        for _, o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("Model") or o:IsA("Part")) and string.find(string.lower(o.Name),"tower") then
                if not table.find(t, o.Name) then table.insert(t, o.Name) end
            end
        end
    end)
    if #t==0 then t = {"Tower 1","Tower 2","Tower 3","Tower 4","Tower 5"} end
    return t
end

-- ============================================================
-- FEATURE FUNCTIONS
-- ============================================================
local function tryFeature(remoteKw, fireArgs, guiNameKw, guiTextKw, featName)
    if fireAll(remoteKw, table.unpack(fireArgs or {})) then return true end
    if clickGuiButton(guiNameKw, guiTextKw) then return true end
    if featName then notify("GOBEY HUB", featName.." gagal", 2) end
    return false
end

local function autoBuyDice()       return tryFeature({"BuyDice","PurchaseDice","RollDice","BuyRoll"}, {}, {"BuyDice","Dice"}, {"buy dice","roll"}, "Buy Dice") end
local function autoCollectCash()   return tryFeature({"Collect","ClaimCash","CollectCash","CollectMoney","ClaimAll"}, {}, {"Collect","Claim"}, {"collect","claim"}, "Collect") end
local function autoPlaceBest()     return tryFeature({"Place","EquipUnit","PlaceUnit","EquipBest","AutoPlace"}, {}, {"Place","Equip"}, {"place","equip"}, "Place Best") end
local function autoFuse()          return tryFeature({"Fuse","FuseUnit","FuseUnits","Merge"}, {}, {"Fuse","Merge"}, {"fuse","merge"}, "Fuse") end
local function autoRebirth()       return tryFeature({"Rebirth","Prestige"}, {}, {"Rebirth"}, {"rebirth"}, "Rebirth") end
local function autoEquipBest()     return tryFeature({"EquipBest","AutoEquip","Equip"}, {}, {"Equip","Best"}, {"equip"}, "Equip Best") end

local function withUnitFilter(keywordList, filters, delay, args)
    local remotes = findRemoteAll(keywordList)
    if #remotes == 0 then return false end
    for _, unit in ipairs(getUnits()) do
        local ok = true
        if filters and next(filters) then ok = filters[unit.name] == true end
        if ok then
            for _, r in ipairs(remotes) do
                pcall(function() r:FireServer(unit.model) end)
                pcall(function() r:FireServer(unit.model, unit.id) end)
                if args then pcall(function() r:FireServer(table.unpack(args)) end) end
            end
            task.wait(delay or 0.15)
        end
    end
    return true
end

local function autoLevel(f)    return withUnitFilter({"LevelUp","UpgradeUnit","LevelUnit"}, f, 0.15) end
local function autoSell(f)     return withUnitFilter({"Sell","SellUnit"}, f, 0.15) end
local function autoRollGrade(f) return withUnitFilter({"RollGrade","RerollGrade","Grade"}, f, 0.3) end
local function autoTrait(f)    return withUnitFilter({"RollTrait","RerollTrait","Trait"}, f, 0.3) end
local function autoGrade(f)    return autoRollGrade(f) end
local function autoStat(f)     return withUnitFilter({"Stat","UpgradeStat","SpendStat","AddStat"}, f, 0.15) end

local function autoRedeemCodes(codes)
    if #codes == 0 then return false end
    local remotes = findRemoteAll({"Redeem","RedeemCode","Code"})
    if #remotes > 0 then
        for _, code in ipairs(codes) do
            for _, r in ipairs(remotes) do pcall(function() r:FireServer(code) end) end
            task.wait(0.5)
        end
        return true
    end
    return false
end

local function serverHop()
    local servers = {}
    pcall(function()
        local res = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(res)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end
        end
    end)
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1,#servers)], LocalPlayer)
    else notify("GOBEY HUB", "No server found", 3) end
end

local function disableCutscenes()
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("BlurEffect") or o:IsA("ColorCorrectionEffect") then o:Destroy() end
    end
    local cam = Workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom; cam.FieldOfView = 70 end
    pcall(function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            local n = string.lower(g.Name)
            if string.find(n,"cutscene") or string.find(n,"cinematic") then
                if g:IsA("ScreenGui") then g.Enabled = false end
            end
        end
    end)
end

-- ---------- v2.0 EXTRAS ----------
local function autoBuyBestDice()
    local remotes = findRemoteAll({"BuyDice","PurchaseDice","BuyDie","RollDice","BuyRoll"})
    if #remotes == 0 then
        clickGuiButton({"BuyDice","Dice"}, {"buy dice","roll"})
        return false
    end
    local picks = {}
    if S.fDiceBuy and next(S.fDiceBuy) then
        for name, on in pairs(S.fDiceBuy) do if on then table.insert(picks, name) end end
    end
    if #picks == 0 then picks = getDiceList() end
    for _, diceName in ipairs(picks) do
        for _, r in ipairs(remotes) do
            pcall(function() r:FireServer(diceName) end)
            pcall(function() r:FireServer(diceName, 1) end)
        end
        task.wait(0.15)
    end
    return true
end

local function autoUpgradeDiceBest()
    local remotes = findRemoteAll({"UpgradeDice","LevelDice","DiceLevel","Upgrade"})
    if #remotes == 0 then return false end
    local picks = {}
    if S.fDiceUp and next(S.fDiceUp) then
        for name, on in pairs(S.fDiceUp) do if on then table.insert(picks, name) end end
    end
    if #picks == 0 then picks = getDiceList() end
    for _, name in ipairs(picks) do
        for _, r in ipairs(remotes) do pcall(function() r:FireServer(name) end) end
        task.wait(0.1)
    end
    return true
end

local function getUnitAttribute(unit, attrs)
    for _, a in ipairs(attrs) do
        local v = unit.model:GetAttribute(a)
        if v ~= nil then return v end
    end
    return nil
end

local function fuseByMode(mode, ignoreRarityAbove)
    local remotes = findRemoteAll({"Fuse","FuseUnit","FuseUnits","Merge"})
    if #remotes == 0 then return false end
    local units = getUnits()
    if #units == 0 then return false end
    local rarityOrder = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Godly","Divine","Secret"}
    local function rarityIndex(r)
        for i, name in ipairs(rarityOrder) do if name == r then return i end end
        return 1
    end
    local filtered = {}
    for _, u in ipairs(units) do
        local rarity = getUnitAttribute(u, {"Rarity","Grade","RarityName"}) or "Common"
        local maxIdx = 999
        if ignoreRarityAbove and ignoreRarityAbove ~= "" then maxIdx = rarityIndex(ignoreRarityAbove) end
        if rarityIndex(rarity) <= maxIdx then table.insert(filtered, u) end
    end
    if mode == "lowest_earnings" then
        table.sort(filtered, function(a, b)
            local ea = tonumber(getUnitAttribute(a, {"Earnings","Income","Cash","Money"})) or 0
            local eb = tonumber(getUnitAttribute(b, {"Earnings","Income","Cash","Money"})) or 0
            return ea < eb
        end)
    elseif mode == "lowest_drop" then
        table.sort(filtered, function(a, b)
            local da = tonumber(getUnitAttribute(a, {"DropChance","Chance","Drop"})) or 100
            local db = tonumber(getUnitAttribute(b, {"DropChance","Chance","Drop"})) or 100
            return da < db
        end)
    elseif mode == "highest_drop" then
        table.sort(filtered, function(a, b)
            local da = tonumber(getUnitAttribute(a, {"DropChance","Chance","Drop"})) or 0
            local db = tonumber(getUnitAttribute(b, {"DropChance","Chance","Drop"})) or 0
            return da > db
        end)
    end
    local batch = {}
    for i = 1, math.min(#filtered, 3) do table.insert(batch, filtered[i]) end
    if #batch < 3 then return false end
    for _, r in ipairs(remotes) do
        pcall(function() r:FireServer(table.unpack(batch)) end)
        pcall(function() r:FireServer(batch[1], batch[2], batch[3]) end)
    end
    return true
end

local function autoPotion()
    local remotes = findRemoteAll({"UsePotion","DrinkPotion","ActivatePotion","Potion"})
    if #remotes == 0 then
        pcall(function()
            for _, g in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if g:IsA("TextButton") then
                    local t = string.lower(g.Text or "")
                    if string.find(t, "potion") or string.find(t, "use") then
                        pcall(function() g:Activate() end)
                        pcall(function() firesignal(g.MouseButton1Click) end)
                    end
                end
            end
        end)
        return false
    end
    local potions = {}
    if S.fPotion and next(S.fPotion) then
        for name, on in pairs(S.fPotion) do if on then table.insert(potions, name) end end
    end
    if #potions == 0 then
        pcall(function()
            for _, fn in ipairs({"Potions","Items","Inventory","Potion"}) do
                local f = ReplicatedStorage:FindFirstChild(fn)
                if f then for _, c in ipairs(f:GetChildren()) do table.insert(potions, c.Name) end end
            end
        end)
        if #potions == 0 then potions = {"Luck Potion","Speed Potion"} end
    end
    for _, pname in ipairs(potions) do
        for _, r in ipairs(remotes) do pcall(function() r:FireServer(pname) end) end
        task.wait(0.3)
    end
    return true
end

local function autoGear()
    local remotes = findRemoteAll({"EquipGear","Gear","SetGear","AutoGear"})
    if #remotes == 0 then return false end
    local picks = {}
    if S.fGear and next(S.fGear) then
        for name, on in pairs(S.fGear) do if on then table.insert(picks, name) end end
    end
    if #picks == 0 then
        pcall(function()
            for _, fn in ipairs({"Gears","Gear","GearData","Equipment"}) do
                local f = ReplicatedStorage:FindFirstChild(fn)
                if f then for _, c in ipairs(f:GetChildren()) do table.insert(picks, c.Name) end end
            end
        end)
        if #picks == 0 then picks = {"Best Gear"} end
    end
    for _, gname in ipairs(picks) do
        for _, r in ipairs(remotes) do pcall(function() r:FireServer(gname) end) end
        task.wait(0.2)
    end
    return true
end

local function autoUseSpins()
    local remotes = findRemoteAll({"Spin","UseSpin","LuckySpin","Wheel","RollSpin"})
    if #remotes == 0 then
        clickGuiButton({"Spin"}, {"spin","lucky"})
        return false
    end
    for _, r in ipairs(remotes) do
        pcall(function() r:FireServer() end)
        pcall(function() r:FireServer("Spin") end)
    end
    return true
end

local function autoDailyReward()
    return tryFeature(
        {"Daily","Login","DailyReward","LoginReward","ClaimDaily","DailyGift"},
        {}, {"Daily","Login","Reward"}, {"daily","login","claim"}, "Daily Reward"
    )
end

local function autoEquipTowerTeam()
    local remotes = findRemoteAll({"EquipTower","TowerTeam","EquipTowerTeam","SetTowerTeam","AutoTowerTeam"})
    if #remotes == 0 then remotes = findRemoteAll({"Equip","Place"}) end
    if #remotes == 0 then return false end
    local units = getUnits()
    if #units == 0 then return false end
    table.sort(units, function(a, b) return (tonumber(a.power) or 0) > (tonumber(b.power) or 0) end)
    for i = 1, math.min(#units, 6) do
        for _, r in ipairs(remotes) do
            pcall(function() r:FireServer(units[i].model, i) end)
            pcall(function() r:FireServer(units[i].model, "Tower", i) end)
        end
        task.wait(0.15)
    end
    return true
end

local function autoLevelEquipped()
    local remotes = findRemoteAll({"LevelUp","UpgradeUnit","LevelUnit"})
    if #remotes == 0 then return false end
    local equipped = {}
    for _, u in ipairs(getUnits()) do
        local eq = u.model:GetAttribute("Equipped") or u.model:GetAttribute("IsEquipped")
                or u.model:GetAttribute("Placed") or u.model:GetAttribute("InTeam")
        if eq == true then table.insert(equipped, u) end
    end
    if #equipped == 0 then equipped = getUnits() end
    for _, u in ipairs(equipped) do
        for _, r in ipairs(remotes) do
            pcall(function() r:FireServer(u.model) end)
            pcall(function() r:FireServer(u.model, 1) end)
        end
        task.wait(0.1)
    end
    return true
end

local rollSkipConn = nil
local function setSkipRollCutscene(on)
    if on and not rollSkipConn then
        rollSkipConn = LocalPlayer.PlayerGui.ChildAdded:Connect(function(g)
            if g:IsA("ScreenGui") then
                local n = string.lower(g.Name)
                if string.find(n,"roll") or string.find(n,"cutscene") or string.find(n,"animation") or string.find(n,"cinematic") then
                    task.wait(0.1); g.Enabled = false
                end
            end
        end)
    elseif not on and rollSkipConn then
        rollSkipConn:Disconnect(); rollSkipConn = nil
    end
end

local function killRollCutscene()
    pcall(function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") then
                local n = string.lower(g.Name)
                if string.find(n,"roll") or string.find(n,"cutscene") or string.find(n,"animation") then
                    g.Enabled = false
                end
            end
        end
        for _, o in ipairs(Lighting:GetChildren()) do
            if o:IsA("BlurEffect") then o.Enabled = false end
        end
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
    end)
end

local function autoLuckBoost()
    return tryFeature(
        {"Luck","BoostLuck","ActivateLuck","UseLuck","LuckBoost"},
        {}, {"Luck","Boost"}, {"luck","boost"}, "Luck Boost"
    )
end

local function autoTraitTarget(unitFilter, targetFilter)
    local remotes = findRemoteAll({"RollTrait","RerollTrait","Trait","SetTrait"})
    if #remotes == 0 then return false end
    local targets = {}
    if targetFilter and next(targetFilter) then
        for name, on in pairs(targetFilter) do if on then table.insert(targets, name) end end
    end
    for _, unit in ipairs(getUnits()) do
        local ok = true
        if unitFilter and next(unitFilter) then ok = unitFilter[unit.name] == true end
        if ok then
            for _, r in ipairs(remotes) do
                if #targets > 0 then
                    for _, tname in ipairs(targets) do
                        pcall(function() r:FireServer(unit.model, tname) end)
                    end
                else
                    pcall(function() r:FireServer(unit.model) end)
                end
            end
            task.wait(0.3)
        end
    end
    return true
end

local function autoGradeTarget(unitFilter, targetFilter)
    local remotes = findRemoteAll({"RollGrade","RerollGrade","Grade","SetGrade"})
    if #remotes == 0 then return false end
    local targets = {}
    if targetFilter and next(targetFilter) then
        for name, on in pairs(targetFilter) do if on then table.insert(targets, name) end end
    end
    for _, unit in ipairs(getUnits()) do
        local ok = true
        if unitFilter and next(unitFilter) then ok = unitFilter[unit.name] == true end
        if ok then
            for _, r in ipairs(remotes) do
                if #targets > 0 then
                    for _, gname in ipairs(targets) do
                        pcall(function() r:FireServer(unit.model, gname) end)
                    end
                else
                    pcall(function() r:FireServer(unit.model) end)
                end
            end
            task.wait(0.3)
        end
    end
    return true
end

local function autoStatByType(unitFilter, statFilter)
    local remotes = findRemoteAll({"Stat","UpgradeStat","SpendStat","AddStat","SpendPoint"})
    if #remotes == 0 then return false end
    local stats = {}
    if statFilter and next(statFilter) then
        for name, on in pairs(statFilter) do if on then table.insert(stats, name) end end
    else
        stats = {"Damage"}
    end
    for _, unit in ipairs(getUnits()) do
        local ok = true
        if unitFilter and next(unitFilter) then ok = unitFilter[unit.name] == true end
        if ok then
            for _, r in ipairs(remotes) do
                for _, statName in ipairs(stats) do
                    pcall(function() r:FireServer(unit.model, statName) end)
                end
            end
            task.wait(0.15)
        end
    end
    return true
end

local function autoQuestByType(questFilter)
    local remotes = findRemoteAll({"ClaimQuest","QuestClaim","DoQuest","StartQuest","Quest"})
    if #remotes == 0 then return false end
    local list = {}
    if questFilter and next(questFilter) then
        for name, on in pairs(questFilter) do if on then table.insert(list, name) end end
    else
        list = getQuestList()
    end
    for _, qname in ipairs(list) do
        for _, r in ipairs(remotes) do pcall(function() r:FireServer(qname) end) end
        task.wait(0.3)
    end
    return true
end

local function autoShopByItem(itemFilter)
    local remotes = findRemoteAll({"Shop","BuyItem","PurchaseItem","BuyShop"})
    if #remotes == 0 then return false end
    local list = {}
    if itemFilter and next(itemFilter) then
        for name, on in pairs(itemFilter) do if on then table.insert(list, name) end end
    else
        list = getShopItemList()
    end
    for _, item in ipairs(list) do
        for _, r in ipairs(remotes) do
            pcall(function() r:FireServer(item) end)
            pcall(function() r:FireServer(item, 1) end)
        end
        task.wait(0.3)
    end
    return true
end

local function autoUpgradeByType(upFilter)
    local remotes = findRemoteAll({"BuyUpgrade","PurchaseUpgrade","Upgrade","BuySkill"})
    if #remotes == 0 then return false end
    local list = {}
    if upFilter and next(upFilter) then
        for name, on in pairs(upFilter) do if on then table.insert(list, name) end end
    else
        list = getUpgradeList()
    end
    for _, up in ipairs(list) do
        for _, r in ipairs(remotes) do pcall(function() r:FireServer(up) end) end
        task.wait(0.2)
    end
    return true
end

local function autoSellByRarity(rarityFilter)
    local remotes = findRemoteAll({"Sell","SellUnit","DeleteUnit","Discard"})
    if #remotes == 0 then return false end
    local sellRarities = {}
    if rarityFilter and next(rarityFilter) then
        for name, on in pairs(rarityFilter) do if on then sellRarities[name]=true end end
    end
    for _, unit in ipairs(getUnits()) do
        local rarity = unit.model:GetAttribute("Rarity") or unit.model:GetAttribute("Grade") or "Common"
        if sellRarities[rarity] then
            for _, r in ipairs(remotes) do pcall(function() r:FireServer(unit.model) end) end
            task.wait(0.15)
        end
    end
    return true
end

-- ---------- TOWER ROTATION ----------
local TowerState = { list = {}, index = 1 }

local function autoTowerSingle(towerName)
    local remotes = findRemoteAll({"Tower","StartTower","FightTower","Battle","EnterTower"})
    for _, r in ipairs(remotes) do
        pcall(function() r:FireServer(towerName) end)
        pcall(function() r:FireServer(towerName, 1) end)
    end
    pcall(function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if g:IsA("TextButton") then
                local t = string.lower(g.Text or "")
                if string.find(t, string.lower(towerName), 1, true) then
                    pcall(function() g:Activate() end)
                    pcall(function() firesignal(g.MouseButton1Click) end)
                end
            end
        end
    end)
    return true
end

local function autoTowerRotation()
    local list = TowerState.list
    if not list or #list == 0 then
        if S.fTower and next(S.fTower) then
            list = {}
            for name, on in pairs(S.fTower) do if on then table.insert(list, name) end end
        else
            list = getTowerList()
        end
    end
    if #list == 0 then return false end
    if TowerState.index > #list then TowerState.index = 1 end
    autoTowerSingle(list[TowerState.index])
    TowerState.index = TowerState.index + 1
    if TowerState.index > #list then TowerState.index = 1 end
    return true
end

-- ============================================================
-- PERFORMANCE / LAG FIX
-- ============================================================
local PerformanceState = { deletedParts=0, deletedParticles=0, deletedSounds=0, deletedOtherChars=0 }

local DECO_KEYWORDS = {
    "grass","tree","leaf","flower","bush","plant","rock","stone",
    "decor","decoration","prop","fence","bench","chair","table",
    "barrel","crate","box","trash","rubbish","sign","poster",
    "cloud","star","sparkle","glitter","dust","smoke","fog",
    "particle","beam","trail","ambient"
}

local function isDecorative(part)
    local n = string.lower(part.Name)
    for _, kw in ipairs(DECO_KEYWORDS) do
        if string.find(n, kw, 1, true) then return true end
    end
    return false
end

local function isImportant(part)
    local char = LocalPlayer.Character
    if char and part:IsDescendantOf(char) then return true end
    if part:FindFirstChildOfClass("Humanoid") then return true end
    local plot = getPlot()
    if plot and part:IsDescendantOf(plot) then return true end
    if part:GetAttribute("Owner") == LocalPlayer.UserId then return true end
    return false
end

local function deleteMapDecorations()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                if not isImportant(obj) and isDecorative(obj) then
                    pcall(function() obj:Destroy(); count = count + 1 end)
                end
            end
        end
    end)
    PerformanceState.deletedParts = PerformanceState.deletedParts + count
    return count
end

local function deleteParticles()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke")
               or obj:IsA("Sparkles") or obj:IsA("Explosion") then
                pcall(function() obj:Destroy(); count = count + 1 end)
            end
        end
    end)
    PerformanceState.deletedParticles = PerformanceState.deletedParticles + count
    return count
end

local function deleteBeamsTrails()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Highlight") then
                pcall(function() obj:Destroy(); count = count + 1 end)
            end
        end
    end)
    return count
end

local function disableLightingEffects()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Lighting:GetChildren()) do
            if obj:IsA("BlurEffect") or obj:IsA("BloomEffect") or obj:IsA("SunRaysEffect")
               or obj:IsA("DepthOfFieldEffect") or obj:IsA("ColorCorrectionEffect")
               or obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                pcall(function() obj.Enabled = false; count = count + 1 end)
            end
        end
    end)
    return count
end

local function deleteSkybox()
    local count = 0
    pcall(function()
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then sky:Destroy(); count = count + 1 end
    end)
    pcall(function()
        local sky = Instance.new("Sky")
        sky.Parent = Lighting
    end)
    return count
end

local function deleteDistantSounds()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Sound") then
                pcall(function() obj:Destroy(); count = count + 1 end)
            end
        end
    end)
    PerformanceState.deletedSounds = PerformanceState.deletedSounds + count
    return count
end

local function removeOtherPlayers()
    local count = 0
    pcall(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                pcall(function() plr.Character:Destroy(); count = count + 1 end)
            end
        end
    end)
    PerformanceState.deletedOtherChars = PerformanceState.deletedOtherChars + count
    return count
end

local function removeTerrain()
    pcall(function() Workspace.Terrain:Clear() end)
end

local function reduceTextureQuality()
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function() obj.Material = Enum.Material.SmoothPlastic end)
            end
        end
    end)
end

local function fullLagFix()
    local results = {}
    results.parts = deleteMapDecorations()
    results.particles = deleteParticles()
    results.beams = deleteBeamsTrails()
    results.lights = disableLightingEffects()
    results.sky = deleteSkybox()
    results.sounds = deleteDistantSounds()
    notify("GOBEY HUB", "LagFix: -"..results.parts.."p -"..results.particles.."fx -"..results.beams.."beam", 4)
    return results
end

-- ============================================================
-- DELETE MAP (BIG FOOT HUB STYLE)
-- ============================================================
local DeleteMapState = { deleted = 0 }

local KEEP_KEYWORDS = {
    "baseplate","spawn","spawnlocation","checkpoint","teleport",
    "portal","trigger","hitbox","damage","zone","clickdetector",
    "proximityprompt","surfacegui","billboard"
}

local function isPartImportant(obj)
    local char = LocalPlayer.Character
    if char and obj:IsDescendantOf(char) then return true end
    local plot = getPlot()
    if plot and obj:IsDescendantOf(plot) then return true end
    if obj:GetAttribute("Owner") == LocalPlayer.UserId then return true end
    if obj:GetAttribute("OwnerUserId") == LocalPlayer.UserId then return true end
    if obj:FindFirstChildOfClass("Humanoid") then return true end
    local n = string.lower(obj.Name)
    for _, kw in ipairs(KEEP_KEYWORDS) do
        if string.find(n, kw, 1, true) then return true end
    end
    return false
end

local function deleteMapSafe()
    local count = 0
    local decoKeywords = {
        "grass","tree","leaf","flower","bush","plant","rock","stone",
        "decor","prop","fence","bench","chair","table","barrel","crate",
        "trash","sign","poster","cloud","particle","beam","trail"
    }
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Model") then
                if not isPartImportant(obj) then
                    local n = string.lower(obj.Name)
                    for _, kw in ipairs(decoKeywords) do
                        if string.find(n, kw, 1, true) then
                            pcall(function() obj:Destroy(); count = count + 1 end)
                            break
                        end
                    end
                end
            end
        end
    end)
    return count
end

local function deleteMapAggressive()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not isPartImportant(obj) then
                if not (obj.Anchored and obj.CanCollide) then
                    pcall(function() obj:Destroy(); count = count + 1 end)
                end
            end
        end
    end)
    return count
end

local function deleteMapFull()
    local count = 0
    local keepList = {}
    local char = LocalPlayer.Character
    if char then table.insert(keepList, char) end
    local plot = getPlot()
    if plot then table.insert(keepList, plot) end

    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            local keep = false
            for _, k in ipairs(keepList) do
                if obj == k then keep = true; break end
            end
            if not keep then
                if obj:IsA("SpawnLocation") or obj:IsA("Terrain") or obj:IsA("Camera") then
                    keep = true
                end
                if not S.removeOtherPlayers and obj:FindFirstChildOfClass("Humanoid") then
                    keep = true
                end
            end
            if not keep then
                pcall(function() obj:Destroy(); count = count + 1 end)
            end
        end
    end)
    return count
end

local function deleteMap(mode)
    local n = 0
    if mode == "safe" then n = deleteMapSafe()
    elseif mode == "aggressive" then n = deleteMapAggressive()
    elseif mode == "full" then n = deleteMapFull()
    else n = deleteMapSafe() end
    DeleteMapState.deleted = DeleteMapState.deleted + n
    notify("GOBEY HUB", "Delete Map ["..mode.."]: -"..n.." objek", 3)
    return n
end

local function restoreMap()
    pcall(function()
        local char = LocalPlayer.Character
        if char then char:BreakJoints() end
    end)
    notify("GOBEY HUB", "Map restore via respawn", 2)
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    -- core
    buyDice=false, collectCash=false, placeBest=false, levelUnits=false,
    sellUnits=false, fuseUnits=false, rollGrades=false, rebirth=false,
    buyUpgrades=false, claimQuests=false, redeemCodes=false, tower=false,
    shop=false, equipBest=false, trait=false, grade=false, stat=false,
    disableCutscene=false, loopDelay=1,
    -- v2.0
    buyBestDice=false, upgradeDice=false, fuseMode=false, fuseModeType="lowest_earnings",
    fuseIgnoreRarity="", potion=false, gear=false, useSpins=false,
    dailyReward=false, towerTeam=false, levelEquipped=false,
    skipRollCutscene=false, luckBoost=false,
    towerRotateDelay=3,
    -- performance
    autoLagFix=false, lagFixInterval=5,
    deleteDeco=false, deleteFX=false, deleteLight=false,
    deleteSound=false, removeOtherPlayers=false, removeTerrain=false,
    reduceTextures=false, autoExecuteOnStart=true,
    -- delete map
    autoDeleteMap=false, deleteMapMode="safe", deleteMapInterval=10,
    deleteMapOnStart=true,
    -- filters
    fLevel={}, fSell={}, fGrade={}, fTrait={}, fStat={}, fRoll={},
    fDiceBuy={}, fDiceUp={}, fAura={}, fSkin={}, fAccessory={},
    fTraitTarget={}, fGradeTarget={}, fStatType={},
    fQuest={}, fShopItem={}, fUpgradeItem={}, fRarity={},
    fTower={}, fPotion={}, fGear={},
}

local CODES = {}

-- ============================================================
-- LOOPS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(S.loopDelay)
        if S.buyDice       then pcall(autoBuyDice) end
        if S.collectCash   then pcall(autoCollectCash) end
        if S.placeBest     then pcall(autoPlaceBest) end
        if S.levelUnits    then pcall(autoLevel, S.fLevel) end
        if S.sellUnits     then pcall(autoSell, S.fSell) end
        if S.fuseUnits     then pcall(autoFuse) end
        if S.rollGrades    then pcall(autoRollGrade, S.fRoll) end
        if S.rebirth       then pcall(autoRebirth) end
        if S.buyUpgrades   then pcall(autoUpgradeByType, S.fUpgradeItem) end
        if S.claimQuests   then pcall(autoQuestByType, S.fQuest) end
        if S.shop          then pcall(autoShopByItem, S.fShopItem) end
        if S.equipBest     then pcall(autoEquipBest) end
        if S.trait         then pcall(autoTraitTarget, S.fTrait, S.fTraitTarget) end
        if S.grade         then pcall(autoGradeTarget, S.fGrade, S.fGradeTarget) end
        if S.stat          then pcall(autoStatByType, S.fStat, S.fStatType) end
        -- v2.0
        if S.buyBestDice   then pcall(autoBuyBestDice) end
        if S.upgradeDice   then pcall(autoUpgradeDiceBest) end
        if S.fuseMode      then pcall(fuseByMode, S.fuseModeType, S.fuseIgnoreRarity) end
        if S.potion        then pcall(autoPotion) end
        if S.gear          then pcall(autoGear) end
        if S.useSpins      then pcall(autoUseSpins) end
        if S.dailyReward   then pcall(autoDailyReward) end
        if S.towerTeam     then pcall(autoEquipTowerTeam) end
        if S.levelEquipped then pcall(autoLevelEquipped) end
        if S.luckBoost     then pcall(autoLuckBoost) end
        if S.tower then
            pcall(autoTowerRotation)
            task.wait(S.towerRotateDelay or 3)
        end
        if S.autoLagFix then
            pcall(fullLagFix)
            task.wait(S.lagFixInterval or 5)
        end
        if S.autoDeleteMap then
            pcall(deleteMap, S.deleteMapMode)
            task.wait(S.deleteMapInterval or 10)
        end
        if S.removeOtherPlayers then pcall(removeOtherPlayers) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.disableCutscene then pcall(disableCutscenes) end
        if S.skipRollCutscene then pcall(killRollCutscene) end
    end
end)

-- ============================================================
-- TABS
-- ============================================================
local tabMain  = createTab("MAIN")
local tabAuto  = createTab("AUTO")
local tabGrade = createTab("GRADE/TRAIT")
local tabFuse  = createTab("FUSE")
local tabExtra = createTab("EXTRA")
local tabMisc  = createTab("MISC")
local tabPerf  = createTab("PERF")
local tabDelMap = createTab("DEL MAP")
local tabDebug = createTab("DEBUG")

local unitNames = getUnitNames()
local diceList  = getDiceList()

-- ==================== MAIN ====================
addSection(tabMain, "FARM")
addToggle(tabMain, "Auto Collect Cash (Fast)", S.collectCash, function(v) S.collectCash=v end)
addToggle(tabMain, "Auto Rebirth (jika cukup)", S.rebirth, function(v) S.rebirth=v end)
addSlider(tabMain, "Loop Delay", 0.1, 5, 1, function(v) S.loopDelay=v end)

addSection(tabMain, "DICE BUY")
addToggle(tabMain, "Auto Buy Best Dice", S.buyBestDice, function(v) S.buyBestDice=v end)
addDropdown(tabMain, "Dice Pilihan", diceList, S.fDiceBuy, true, function(sel) S.fDiceBuy=sel end)
addButton(tabMain, "Buy Dice Now", function() autoBuyBestDice() end)

addSection(tabMain, "DICE UPGRADE")
addToggle(tabMain, "Auto Upgrade Dice", S.upgradeDice, function(v) S.upgradeDice=v end)
addDropdown(tabMain, "Dice Upgrade", diceList, S.fDiceUp, true, function(sel) S.fDiceUp=sel end)

addSection(tabMain, "UPGRADES")
addToggle(tabMain, "Auto Buy Upgrades", S.buyUpgrades, function(v) S.buyUpgrades=v end)
addDropdown(tabMain, "Skill / Upgrade", getUpgradeList(), S.fUpgradeItem, true, function(sel) S.fUpgradeItem=sel end)

-- ==================== AUTO ====================
addSection(tabAuto, "UNITS")
addToggle(tabAuto, "Auto Place Best Units", S.placeBest, function(v) S.placeBest=v end)
addToggle(tabAuto, "Auto Equip Best", S.equipBest, function(v) S.equipBest=v end)
addToggle(tabAuto, "Auto Fuse (Basic)", S.fuseUnits, function(v) S.fuseUnits=v end)

addSection(tabAuto, "AUTO LEVEL")
addToggle(tabAuto, "Auto Level Units", S.levelUnits, function(v) S.levelUnits=v end)
addDropdown(tabAuto, "Unit", unitNames, S.fLevel, true, function(sel) S.fLevel=sel end)
addToggle(tabAuto, "Auto Level Equipped Only", S.levelEquipped, function(v) S.levelEquipped=v end)
addButton(tabAuto, "Refresh Units", function()
    unitNames = getUnitNames(); notify("GOBEY HUB", #unitNames.." unit", 2)
end)
addButton(tabAuto, "Level Now", function() autoLevel(S.fLevel) end)

addSection(tabAuto, "AUTO SELL")
addToggle(tabAuto, "Auto Sell Units", S.sellUnits, function(v) S.sellUnits=v end)
addDropdown(tabAuto, "Unit", unitNames, S.fSell, true, function(sel) S.fSell=sel end)
addDropdown(tabAuto, "Sell Rarity", getRarityList(), S.fRarity, true, function(sel) S.fRarity=sel end)
addButton(tabAuto, "Sell Now", function() autoSell(S.fSell) end)
addButton(tabAuto, "Sell By Rarity Now", function() autoSellByRarity(S.fRarity) end)

addSection(tabAuto, "AUTO TOWER")
addToggle(tabAuto, "Auto Tower (Rotation)", S.tower, function(v) S.tower=v end)
addDropdown(tabAuto, "Tower", getTowerList(), S.fTower, true, function(sel)
    S.fTower = sel
    TowerState.list = {}
    for name, on in pairs(sel) do if on then table.insert(TowerState.list, name) end end
end)
addSlider(tabAuto, "Rotate Delay", 0.5, 15, 3, function(v) S.towerRotateDelay=v end)
addButton(tabAuto, "Equip Tower Team", function() autoEquipTowerTeam() end)

addSection(tabAuto, "AUTO SHOP")
addToggle(tabAuto, "Auto Shop", S.shop, function(v) S.shop=v end)
addDropdown(tabAuto, "Item", getShopItemList(), S.fShopItem, true, function(sel) S.fShopItem=sel end)

-- ==================== GRADE/TRAIT ====================
addSection(tabGrade, "GRADE")
addToggle(tabGrade, "Auto Grade (Target)", S.grade, function(v) S.grade=v end)
addDropdown(tabGrade, "Unit", unitNames, S.fGrade, true, function(sel) S.fGrade=sel end)
addDropdown(tabGrade, "Target Grade", getGradeList(), S.fGradeTarget, true, function(sel) S.fGradeTarget=sel end)
addButton(tabGrade, "Grade Now", function() autoGradeTarget(S.fGrade, S.fGradeTarget) end)

addSection(tabGrade, "TRAIT")
addToggle(tabGrade, "Auto Trait (Target)", S.trait, function(v) S.trait=v end)
addDropdown(tabGrade, "Unit", unitNames, S.fTrait, true, function(sel) S.fTrait=sel end)
addDropdown(tabGrade, "Target Trait", getTraitList(), S.fTraitTarget, true, function(sel) S.fTraitTarget=sel end)
addButton(tabGrade, "Trait Now", function() autoTraitTarget(S.fTrait, S.fTraitTarget) end)

addSection(tabGrade, "ROLL / STAT")
addToggle(tabGrade, "Auto Roll Grade", S.rollGrades, function(v) S.rollGrades=v end)
addDropdown(tabGrade, "Unit Roll", unitNames, S.fRoll, true, function(sel) S.fRoll=sel end)
addButton(tabGrade, "Roll Now", function() autoRollGrade(S.fRoll) end)

addToggle(tabGrade, "Auto Stat", S.stat, function(v) S.stat=v end)
addDropdown(tabGrade, "Unit Stat", unitNames, S.fStat, true, function(sel) S.fStat=sel end)
addDropdown(tabGrade, "Stat Type", getStatList(), S.fStatType, true, function(sel) S.fStatType=sel end)
addButton(tabGrade, "Stat Now", function() autoStatByType(S.fStat, S.fStatType) end)

addSection(tabGrade, "COSMETIC")
addToggle(tabGrade, "Auto Equip Aura", S.aura, function(v) S.aura=v end)
addDropdown(tabGrade, "Aura", getAuraList(), S.fAura, true, function(sel) S.fAura=sel end)
addToggle(tabGrade, "Auto Equip Skin", S.skin, function(v) S.skin=v end)
addDropdown(tabGrade, "Skin", getSkinList(), S.fSkin, true, function(sel) S.fSkin=sel end)
addToggle(tabGrade, "Auto Equip Accessory", S.accessory, function(v) S.accessory=v end)
addDropdown(tabGrade, "Accessory", getAccessoryList(), S.fAccessory, true, function(sel) S.fAccessory=sel end)

-- ==================== FUSE ====================
addSection(tabFuse, "FUSE MODE")
addToggle(tabFuse, "Auto Fuse (Mode)", S.fuseMode, function(v) S.fuseMode=v end)
addDropdown(tabFuse, "Mode",
    {"lowest_earnings","lowest_drop","highest_drop"},
    "lowest_earnings", false,
    function(sel) S.fuseModeType = sel end
)
addDropdown(tabFuse, "Ignore Rarity Above", getRarityList(), S.fuseIgnoreRarity, false, function(sel)
    S.fuseIgnoreRarity = sel
end)
addButton(tabFuse, "Fuse Now (Mode)", function()
    local ok = fuseByMode(S.fuseModeType, S.fuseIgnoreRarity)
    notify("GOBEY HUB", ok and "Fuse OK" or "Fuse FAIL", 2)
end)

addSection(tabFuse, "INFO")
addLabel(tabFuse,
    "• lowest_earnings : fuse 3 unit income terendah\n"..
    "• lowest_drop     : fuse 3 unit drop chance terendah\n"..
    "• highest_drop    : fuse 3 unit drop chance tertinggi", 70)

-- ==================== EXTRA ====================
addSection(tabExtra, "POTION & GEAR")
addToggle(tabExtra, "Auto Potion", S.potion, function(v) S.potion=v end)
addDropdown(tabExtra, "Potion", {"Luck Potion","Speed Potion","Power Potion"}, S.fPotion, true, function(sel) S.fPotion=sel end)
addToggle(tabExtra, "Auto Gear", S.gear, function(v) S.gear=v end)
addDropdown(tabExtra, "Gear", {"Best Gear"}, S.fGear, true, function(sel) S.fGear=sel end)

addSection(tabExtra, "SPIN & REWARD")
addToggle(tabExtra, "Auto Use Spins", S.useSpins, function(v) S.useSpins=v end)
addToggle(tabExtra, "Auto Daily Reward", S.dailyReward, function(v) S.dailyReward=v end)
addToggle(tabExtra, "Auto Luck Boost", S.luckBoost, function(v) S.luckBoost=v end)

addSection(tabExtra, "TOWER TEAM")
addToggle(tabExtra, "Auto Equip Tower Team", S.towerTeam, function(v) S.towerTeam=v end)

addSection(tabExtra, "CUTSCENE")
addToggle(tabExtra, "Auto Skip Roll Cutscene", S.skipRollCutscene, function(v)
    S.skipRollCutscene = v
    setSkipRollCutscene(v)
end)
addButton(tabExtra, "Kill Roll Cutscene Now", function() killRollCutscene() end)

-- ==================== MISC ====================
addSection(tabMisc, "QUEST")
addToggle(tabMisc, "Auto Claim Quest", S.claimQuests, function(v) S.claimQuests=v end)
addDropdown(tabMisc, "Quest", getQuestList(), S.fQuest, true, function(sel) S.fQuest=sel end)

addSection(tabMisc, "CODES")
local codesInput = Instance.new("TextBox")
codesInput.Size = UDim2.new(1,0,0,36)
codesInput.BackgroundColor3 = Color3.fromRGB(24,24,30)
codesInput.BorderSizePixel = 0
codesInput.PlaceholderText = "code1,code2,..."
codesInput.TextColor3 = Color3.fromRGB(215,215,215)
codesInput.PlaceholderColor3 = Color3.fromRGB(120,120,120)
codesInput.Font = Enum.Font.Gotham
codesInput.TextSize = 11
codesInput.ClearTextOnFocus = false
codesInput.Parent = tabMisc
Instance.new("UICorner", codesInput).CornerRadius = UDim.new(0,8)

codesInput.FocusLost:Connect(function()
    CODES = {}
    for c in string.gmatch(codesInput.Text or "", "[^,]+") do
        local t = c:gsub("^%s+",""):gsub("%s+$","")
        if t ~= "" then table.insert(CODES, t) end
    end
end)

addToggle(tabMisc, "Auto Redeem", S.redeemCodes, function(v)
    S.redeemCodes = v
    if v and #CODES > 0 then autoRedeemCodes(CODES) end
end)
addButton(tabMisc, "Redeem Now", function()
    if #CODES>0 then autoRedeemCodes(CODES) else notify("GOBEY HUB", "Input code dulu", 3) end
end)

addSection(tabMisc, "UTILITY")
addToggle(tabMisc, "Disable Cutscenes", S.disableCutscene, function(v) S.disableCutscene=v end)
addButton(tabMisc, "Server Hop", function() serverHop() end)

-- ==================== PERFORMANCE ====================
addSection(tabPerf, "AUTO LAG FIX")
addToggle(tabPerf, "Auto Lag Fix (Loop)", S.autoLagFix, function(v) S.autoLagFix=v end)
addSlider(tabPerf, "Interval (detik)", 1, 30, 5, function(v) S.lagFixInterval=v end)
addButton(tabPerf, "Full Lag Fix Now", function() fullLagFix() end)

addSection(tabPerf, "MANUAL DELETE")
addButton(tabPerf, "Delete Deco Now", function()
    local n = deleteMapDecorations(); notify("GOBEY HUB", "Deleted "..n.." deco", 3)
end)
addButton(tabPerf, "Delete FX Now", function()
    local n = deleteParticles() + deleteBeamsTrails(); notify("GOBEY HUB", "Deleted "..n.." FX", 3)
end)
addButton(tabPerf, "Disable Lighting Now", function()
    local n = disableLightingEffects(); notify("GOBEY HUB", "Disabled "..n.." effects", 3)
end)
addButton(tabPerf, "Delete Sounds Now", function()
    local n = deleteDistantSounds(); notify("GOBEY HUB", "Deleted "..n.." sounds", 3)
end)

addSection(tabPerf, "EXTREME")
addToggle(tabPerf, "Remove Other Players", S.removeOtherPlayers, function(v) S.removeOtherPlayers=v end)
addToggle(tabPerf, "Remove Terrain", S.removeTerrain, function(v)
    S.removeTerrain = v
    if v then removeTerrain() end
end)
addToggle(tabPerf, "Reduce Texture Quality", S.reduceTextures, function(v)
    S.reduceTextures = v
    if v then reduceTextureQuality() end
end)
addButton(tabPerf, "Reset Sky (Default)", function() deleteSkybox() end)

addSection(tabPerf, "STATS")
local perfLabel = addLabel(tabPerf, "Deleted: 0 | 0 | 0", 40)
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            perfLabel.Text = string.format(
                "Parts: %d | FX: %d | Sounds: %d | Players: %d",
                PerformanceState.deletedParts,
                PerformanceState.deletedParticles,
                PerformanceState.deletedSounds,
                PerformanceState.deletedOtherChars
            )
        end)
    end
end)

-- ==================== DELETE MAP ====================
addSection(tabDelMap, "MODE DELETE MAP")
addLabel(tabDelMap,
    "• SAFE       : hapus deco saja\n"..
    "• AGGRESSIVE : hapus BasePart non-essential\n"..
    "• FULL       : hapus semua kecuali char + plot + spawn", 60)

addDropdown(tabDelMap, "Mode",
    {"safe","aggressive","full"},
    "safe", false,
    function(sel) S.deleteMapMode = sel end
)

addToggle(tabDelMap, "Auto Delete Map (Loop)", S.autoDeleteMap, function(v) S.autoDeleteMap=v end)
addSlider(tabDelMap, "Interval (detik)", 2, 60, 10, function(v) S.deleteMapInterval=v end)

addSection(tabDelMap, "EXECUTE NOW")
addButton(tabDelMap, "Delete Map (Safe)", function() deleteMap("safe") end)
addButton(tabDelMap, "Delete Map (Aggressive)", function() deleteMap("aggressive") end)
addButton(tabDelMap, "Delete Map (FULL)", function() deleteMap("full") end)

addSection(tabDelMap, "EXTRA")
addButton(tabDelMap, "Delete Terrain", function()
    removeTerrain(); notify("GOBEY HUB", "Terrain cleared", 2)
end)
addButton(tabDelMap, "Restore Map (Respawn)", function() restoreMap() end)

addSection(tabDelMap, "STATS")
local dmLabel = addLabel(tabDelMap, "Total deleted: 0", 30)
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            dmLabel.Text = "Total deleted: "..DeleteMapState.deleted
        end)
    end
end)

-- ==================== DEBUG ====================
addSection(tabDebug, "REMOTES ("..#RemoteList..")")
local debugLabel = addLabel(tabDebug, "Loading...", 260)
local function refreshDebug()
    local lines = {}
    for i, r in ipairs(RemoteList) do
        if i > 150 then table.insert(lines, "... +"..(#RemoteList-150).." more"); break end
        table.insert(lines, "["..r.type.."] "..r.path)
    end
    debugLabel.Text = table.concat(lines, "\n")
end
refreshDebug()

addButton(tabDebug, "Re-scan Remotes", function()
    discoverRemotes(); refreshDebug()
    notify("GOBEY HUB", #RemoteList.." remotes", 3)
end)
addButton(tabDebug, "Dump Remote Names", function()
    print("=== GOBEY HUB REMOTE DUMP ===")
    for i, r in ipairs(RemoteList) do
        print(string.format("[%d] (%s) %s", i, r.type, r.path))
    end
    print("=== END ===")
    notify("GOBEY HUB", "Check console (F9)", 3)
end)

-- ============================================================
-- WINDOW CONTROLS
-- ============================================================
MinBtn.MouseButton1Click:Connect(function() Window.Visible=false; MiniBar.Visible=true; MiniBar.Position=Window.Position end)
MiniPlus.MouseButton1Click:Connect(function() Window.Visible=true; MiniBar.Visible=false end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

do
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Window.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

Tabs[1].Visible = true
TabButtons["MAIN"].BackgroundColor3 = Color3.fromRGB(80,40,140)
TabButtons["MAIN"].TextColor3 = Color3.fromRGB(255,255,255)

-- ============================================================
-- AUTO EXECUTE ON START
-- ============================================================
task.spawn(function()
    task.wait(2)
    if S.autoExecuteOnStart then
        pcall(fullLagFix)
        pcall(disableCutscenes)
        pcall(killRollCutscene)
        notify("GOBEY HUB", "Auto lag fix applied", 3)
    end
    task.wait(1)
    if S.deleteMapOnStart then
        pcall(deleteMap, S.deleteMapMode or "safe")
    end
end)

notify("GOBEY HUB v2.1", "Loaded! "..#RemoteList.." remotes | "..#unitNames.." units", 4)
print("[GOBEY HUB v2.1] Loaded | Remotes: "..#RemoteList.." | Units: "..#unitNames)