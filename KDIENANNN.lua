-- ============================================================
-- ANIME DICE AUTO FARM HUB - BPHUB STYLE
-- One-click automation, unit dropdown, auto-grade/trait roll
-- Dynamic remote + GUI fallback
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- REMOTE DISCOVERY (BPHUB-STYLE AGGRESSIVE SCAN)
-- ============================================================
local Remotes = {}
local RemoteList = {}
local RemoteFunctions = {}

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
    Remotes = {}; RemoteFunctions = {}; RemoteList = {}
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

-- GUI FALLBACK (klik tombol di layar)
local function clickGuiButton(nameKw, textKw)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local n = string.lower(gui.Name or "")
            local t = ""
            if gui:IsA("TextButton") then t = string.lower(gui.Text or "") end
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
-- GUI FRAMEWORK (BPHUB CLEAN STYLE)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BPHUB_AnimeDice"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 580, 0, 480)
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.new(0.5, 0, 0.5, 0)
Window.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Window.BorderSizePixel = 0
Window.ClipsDescendants = false
Window.Parent = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "BPHUB | ANIME DICE"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.Parent = TitleBar

-- Mini bar
local MiniBar = Instance.new("Frame")
MiniBar.Size = UDim2.new(0, 260, 0, 40)
MiniBar.AnchorPoint = Vector2.new(0.5, 0.5)
MiniBar.Position = Window.Position
MiniBar.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
MiniBar.BorderSizePixel = 0
MiniBar.Visible = false
MiniBar.Parent = ScreenGui
Instance.new("UICorner", MiniBar).CornerRadius = UDim.new(0, 16)

local MiniTitle = Instance.new("TextLabel")
MiniTitle.Size = UDim2.new(1, -70, 1, 0)
MiniTitle.Position = UDim2.new(0, 16, 0, 0)
MiniTitle.BackgroundTransparency = 1
MiniTitle.Text = "BPHUB | ANIME DICE"
MiniTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
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

-- Tabs
local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(0, 130, 1, -52)
TabBar.Position = UDim2.new(0, 8, 0, 48)
TabBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 4
TabBar.ScrollingDirection = Enum.ScrollingDirection.Y
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabBar.CanvasSize = UDim2.fromOffset(0, 0)
TabBar.ClipsDescendants = true
TabBar.Parent = Window
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 6)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -148, 1, -56)
Content.Position = UDim2.new(0, 144, 0, 48)
Content.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Content.BorderSizePixel = 0
Content.ClipsDescendants = false
Content.Parent = Window
Instance.new("UICorner", Content).CornerRadius = UDim.new(0, 8)

local Tabs = {}; local TabButtons = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
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
    page.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
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
            b.BackgroundColor3 = Color3.fromRGB(38, 38, 46); b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 82); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    table.insert(Tabs, page); TabButtons[name] = btn
    return page
end

-- UI Helpers
local function addSection(page, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,20); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Color3.fromRGB(130,130,145)
    l.Font = Enum.Font.GothamBold; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
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
    t.BackgroundColor3 = value and Color3.fromRGB(0,190,90) or Color3.fromRGB(60,60,60)
    t.BorderSizePixel = 0; t.Parent = f
    Instance.new("UICorner", t).CornerRadius = UDim.new(1,0)

    local k = Instance.new("Frame")
    k.Size = UDim2.new(0,20,0,20)
    k.Position = value and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
    k.BackgroundColor3 = value and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
    k.BorderSizePixel = 0; k.Parent = t
    Instance.new("UICorner", k).CornerRadius = UDim.new(1,0)

    t.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            value = not value
            t.BackgroundColor3 = value and Color3.fromRGB(0,190,90) or Color3.fromRGB(60,60,60)
            k.Position = value and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
            k.BackgroundColor3 = value and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
            if callback then task.spawn(function() pcall(callback, value) end) end
        end
    end)
    return {Set=function(v) value=v end, Get=function() return value end}
end

local function addButton(page, text, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,38); b.BackgroundColor3 = Color3.fromRGB(44,44,54)
    b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = Color3.fromRGB(215,215,215)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.Parent = page
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    b.MouseButton1Click:Connect(function()
        if callback then task.spawn(function() pcall(callback) end) end
    end)
    return b
end

local function addSlider(page, text, min, max, default, callback)
    min = min or 0; max = max or 100; default = default or min
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
    vl.BackgroundTransparency = 1; vl.Text = tostring(value); vl.TextColor3 = Color3.fromRGB(255,255,255)
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 10; vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = f

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1,-24,0,10); bar.Position = UDim2.new(0,12,0,32)
    bar.BackgroundColor3 = Color3.fromRGB(24,24,30); bar.BorderSizePixel = 0
    bar.Text = ""; bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((value-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,170,255); fill.BorderSizePixel = 0
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

-- Dropdown (BPHUB-style)
local ddZ = 10
local function addDropdown(page, label, options, default, multi, callback)
    options = options or {}
    local selected = {}; local current = default
    if multi and type(default)=="table" then
        for k,v in pairs(default) do if v==true then selected[k]=true elseif type(v)=="string" then selected[v]=true end end
    end
    ddZ = ddZ + 5

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,44); row.BackgroundColor3 = Color3.fromRGB(36,36,44)
    row.BorderSizePixel = 0; row.ClipsDescendants = false; row.ZIndex = ddZ
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
    list.Size = UDim2.new(0.6,-18,0,0); list.Position = UDim2.new(0.4,6,0,44)
    list.BackgroundColor3 = Color3.fromRGB(18,18,22); list.BorderSizePixel = 0
    list.ScrollBarThickness = 4; list.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)
    list.CanvasSize = UDim2.fromOffset(0,0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.Visible = false; list.ZIndex = ddZ+100; list.ClipsDescendants = true
    list.Parent = row
    Instance.new("UICorner", list).CornerRadius = UDim.new(0,6)

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

    local function rebuild()
        for _,ch in ipairs(list:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
        local o = 1
        for _,op in ipairs(options) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1,-4,0,26)
            item.BackgroundColor3 = (multi and selected[op] or current==op) and Color3.fromRGB(0,150,220) or Color3.fromRGB(38,38,46)
            item.BorderSizePixel = 0; item.Text = tostring(op)
            item.TextColor3 = Color3.fromRGB(215,215,215); item.Font = Enum.Font.GothamBold
            item.TextSize = 10; item.LayoutOrder = o; o=o+1; item.ZIndex = ddZ+101
            item.Parent = list
            Instance.new("UICorner", item).CornerRadius = UDim.new(0,5)
            item.MouseButton1Click:Connect(function()
                if multi then selected[op] = not selected[op] or nil
                else current = op; list.Visible = false end
                rebuild(); emit()
            end)
        end
        task.defer(function()
            local h = math.min(220, ll.AbsoluteContentSize.Y + 14)
            list.CanvasSize = UDim2.fromOffset(0, ll.AbsoluteContentSize.Y + 14)
            if list.Visible then list.Size = UDim2.new(0.6,-18,0,h) end
        end)
    end

    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        if list.Visible then
            local h = math.min(220, ll.AbsoluteContentSize.Y + 14)
            list.Size = UDim2.new(0.6,-18,0,h)
        else list.Size = UDim2.new(0.6,-18,0,0) end
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
        StarterGui:SetCore("SendNotification", {Title=tostring(title or "BPHUB"), Text=tostring(text or ""), Duration=tonumber(dur) or 3})
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
    local out = {}; local plot = getPlot()
    local roots = {}
    if plot then table.insert(roots, plot) end
    for _, name in ipairs({"Plots","PlotFolder","Units"}) do
        local f = Workspace:FindFirstChild(name)
        if f then table.insert(roots, f) end
    end
    local seen = {}
    for _, root in ipairs(roots) do
        for _, u in ipairs(root:GetDescendants()) do
            if (u:IsA("Model") or u:IsA("Folder")) and not seen[u] then
                local uName = u:GetAttribute("UnitName") or u:GetAttribute("Name")
                local uId = u:GetAttribute("UnitId") or u:GetAttribute("Id")
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
    for _, u in ipairs(getUnits()) do
        if not seen[u.name] then seen[u.name]=true; table.insert(names, u.name) end
    end
    if #names==0 then
        pcall(function()
            for _, fn in ipairs({"Units","UnitData","Dice","Assets"}) do
                local f = ReplicatedStorage:FindFirstChild(fn)
                if f then for _, c in ipairs(f:GetChildren()) do if not seen[c.Name] then seen[c.Name]=true; table.insert(names,c.Name) end end end
            end
        end)
    end
    table.sort(names); return names
end

-- ============================================================
-- FEATURE FUNCTIONS (BPHUB STYLE: remote + GUI fallback)
-- ============================================================
local function tryFeature(remoteKw, fireArgs, guiNameKw, guiTextKw, featName)
    if fireAll(remoteKw, table.unpack(fireArgs or {})) then return true end
    if clickGuiButton(guiNameKw, guiTextKw) then return true end
    if featName then notify("Feature", featName.." gagal", 2) end
    return false
end

local function autoBuyDice()
    return tryFeature({"BuyDice","PurchaseDice","RollDice","BuyRoll"}, {}, {"BuyDice","Dice"}, {"buy dice","roll"}, "Buy Dice")
end
local function autoCollectCash()
    return tryFeature({"Collect","ClaimCash","CollectCash","CollectMoney","ClaimAll"}, {}, {"Collect","Claim"}, {"collect","claim"}, "Collect")
end
local function autoPlaceBest()
    return tryFeature({"Place","EquipUnit","PlaceUnit","EquipBest","AutoPlace"}, {}, {"Place","Equip"}, {"place","equip"}, "Place Best")
end
local function autoFuse()
    return tryFeature({"Fuse","FuseUnit","FuseUnits","Merge"}, {}, {"Fuse","Merge"}, {"fuse","merge"}, "Fuse")
end
local function autoRebirth()
    return tryFeature({"Rebirth","Prestige"}, {}, {"Rebirth"}, {"rebirth"}, "Rebirth")
end
local function autoBuyUpgrades()
    return tryFeature({"BuyUpgrade","PurchaseUpgrade","Upgrade"}, {}, {"Upgrade","Buy"}, {"upgrade"}, "Upgrades")
end
local function autoClaimQuests()
    return tryFeature({"ClaimQuest","QuestClaim","ClaimDaily","DailyReward","ClaimReward"}, {}, {"Claim","Quest","Daily"}, {"claim","quest","daily"}, "Claim")
end
local function autoTower()
    return tryFeature({"Tower","StartTower","FightTower","Battle"}, {}, {"Tower","Fight"}, {"tower","fight"}, "Tower")
end
local function autoShop()
    return tryFeature({"Shop","BuyItem","PurchaseItem"}, {}, {"Shop","Buy"}, {"shop"}, "Shop")
end
local function autoEquipBest()
    return tryFeature({"EquipBest","AutoEquip","Equip"}, {}, {"Equip","Best"}, {"equip"}, "Equip Best")
end

-- Fitur dengan unit filter (BPHUB style: pilih unit dulu)
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

local function autoLevel(f) return withUnitFilter({"LevelUp","UpgradeUnit","LevelUnit"}, f, 0.15) end
local function autoSell(f) return withUnitFilter({"Sell","SellUnit"}, f, 0.15) end
local function autoRollGrade(f) return withUnitFilter({"RollGrade","RerollGrade","Grade"}, f, 0.3) end
local function autoTrait(f) return withUnitFilter({"RollTrait","RerollTrait","Trait"}, f, 0.3) end
local function autoGrade(f) return autoRollGrade(f) end
local function autoStat(f) return withUnitFilter({"Stat","UpgradeStat","SpendStat","AddStat"}, f, 0.15) end

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
    else notify("Server Hop", "No server", 3) end
end

local function disableCutscenes()
    for _, o in ipairs(Lighting:GetChildren()) do
        if o:IsA("BlurEffect") or o:IsA("ColorCorrectionEffect") then o:Destroy() end
    end
    local cam = Workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom; cam.FieldOfView = 70 end
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    buyDice=false, collectCash=false, placeBest=false, levelUnits=false,
    sellUnits=false, fuseUnits=false, rollGrades=false, rebirth=false,
    buyUpgrades=false, claimQuests=false, redeemCodes=false, tower=false,
    shop=false, equipBest=false, trait=false, grade=false, stat=false,
    disableCutscene=false, loopDelay=1,
    fLevel={}, fSell={}, fGrade={}, fTrait={}, fStat={}, fRoll={},
}

local CODES = {}

-- ============================================================
-- LOOPS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(S.loopDelay)
        if S.buyDice then pcall(autoBuyDice) end
        if S.collectCash then pcall(autoCollectCash) end
        if S.placeBest then pcall(autoPlaceBest) end
        if S.levelUnits then pcall(autoLevel, S.fLevel) end
        if S.sellUnits then pcall(autoSell, S.fSell) end
        if S.fuseUnits then pcall(autoFuse) end
        if S.rollGrades then pcall(autoRollGrade, S.fRoll) end
        if S.rebirth then pcall(autoRebirth) end
        if S.buyUpgrades then pcall(autoBuyUpgrades) end
        if S.claimQuests then pcall(autoClaimQuests) end
        if S.tower then pcall(autoTower) end
        if S.shop then pcall(autoShop) end
        if S.equipBest then pcall(autoEquipBest) end
        if S.trait then pcall(autoTrait, S.fTrait) end
        if S.grade then pcall(autoGrade, S.fGrade) end
        if S.stat then pcall(autoStat, S.fStat) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.disableCutscene then pcall(disableCutscenes) end
    end
end)

-- ============================================================
-- BUILD TABS
-- ============================================================
local tabMain = createTab("MAIN")
local tabAuto = createTab("AUTO")
local tabGrade = createTab("GRADE/TRAIT")
local tabMisc = createTab("MISC")
local tabDebug = createTab("DEBUG")

local unitNames = getUnitNames()

-- MAIN
addSection(tabMain, "FARM")
addToggle(tabMain, "Auto Collect Cash", S.collectCash, function(v) S.collectCash=v end)
addToggle(tabMain, "Auto Buy Dice", S.buyDice, function(v) S.buyDice=v end)
addToggle(tabMain, "Auto Rebirth", S.rebirth, function(v) S.rebirth=v end)
addToggle(tabMain, "Auto Buy Upgrades", S.buyUpgrades, function(v) S.buyUpgrades=v end)
addSlider(tabMain, "Loop Delay", 0.2, 5, 1, function(v) S.loopDelay=v end)

-- AUTO
addSection(tabAuto, "UNITS")
addToggle(tabAuto, "Auto Place Best", S.placeBest, function(v) S.placeBest=v end)
addToggle(tabAuto, "Auto Equip Best", S.equipBest, function(v) S.equipBest=v end)
addToggle(tabAuto, "Auto Fuse", S.fuseUnits, function(v) S.fuseUnits=v end)
addToggle(tabAuto, "Auto Tower", S.tower, function(v) S.tower=v end)
addToggle(tabAuto, "Auto Shop", S.shop, function(v) S.shop=v end)

addSection(tabAuto, "AUTO LEVEL")
addToggle(tabAuto, "Auto Level Units", S.levelUnits, function(v) S.levelUnits=v end)
local lvlDrop = addDropdown(tabAuto, "Unit", unitNames, S.fLevel, true, function(sel) S.fLevel=sel end)
addButton(tabAuto, "Refresh Units", function()
    unitNames = getUnitNames(); lvlDrop.SetOptions(unitNames)
    notify("Units", #unitNames.." unit", 2)
end)
addButton(tabAuto, "Level Now", function() autoLevel(S.fLevel) end)

addSection(tabAuto, "AUTO SELL")
addToggle(tabAuto, "Auto Sell Units", S.sellUnits, function(v) S.sellUnits=v end)
addDropdown(tabAuto, "Unit", unitNames, S.fSell, true, function(sel) S.fSell=sel end)
addButton(tabAuto, "Sell Now", function() autoSell(S.fSell) end)

-- GRADE/TRAIT
addSection(tabGrade, "GRADE")
addToggle(tabGrade, "Auto Grade", S.grade, function(v) S.grade=v end)
addDropdown(tabGrade, "Unit Grade", unitNames, S.fGrade, true, function(sel) S.fGrade=sel end)
addButton(tabGrade, "Grade Now", function() autoGrade(S.fGrade) end)

addSection(tabGrade, "TRAIT")
addToggle(tabGrade, "Auto Trait", S.trait, function(v) S.trait=v end)
addDropdown(tabGrade, "Unit Trait", unitNames, S.fTrait, true, function(sel) S.fTrait=sel end)
addButton(tabGrade, "Trait Now", function() autoTrait(S.fTrait) end)

addSection(tabGrade, "ROLL / STAT")
addToggle(tabGrade, "Auto Roll Grade", S.rollGrades, function(v) S.rollGrades=v end)
addDropdown(tabGrade, "Unit Roll", unitNames, S.fRoll, true, function(sel) S.fRoll=sel end)
addButton(tabGrade, "Roll Now", function() autoRollGrade(S.fRoll) end)

addToggle(tabGrade, "Auto Stat", S.stat, function(v) S.stat=v end)
addDropdown(tabGrade, "Unit Stat", unitNames, S.fStat, true, function(sel) S.fStat=sel end)
addButton(tabGrade, "Stat Now", function() autoStat(S.fStat) end)

-- MISC
addSection(tabMisc, "QUEST & CODES")
addToggle(tabMisc, "Auto Claim Quest", S.claimQuests, function(v) S.claimQuests=v end)
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
    if #CODES>0 then autoRedeemCodes(CODES) else notify("Codes", "Input code dulu", 3) end
end)

addSection(tabMisc, "UTILITY")
addToggle(tabMisc, "Disable Cutscene", S.disableCutscene, function(v) S.disableCutscene=v end)
addButton(tabMisc, "Server Hop", function() serverHop() end)
addButton(tabMisc, "Test Collect", function() notify("Test", autoCollectCash() and "OK" or "FAIL", 2) end)
addButton(tabMisc, "Test Place Best", function() notify("Test", autoPlaceBest() and "OK" or "FAIL", 2) end)

-- DEBUG
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
    notify("Debug", #RemoteList.." remotes", 3)
end)
addButton(tabDebug, "Fire All 'Roll'", function()
    local l = findRemoteAll({"Roll"})
    for _, r in ipairs(l) do pcall(function() r:FireServer() end) end
    notify("Test", #l.." fired", 2)
end)
addButton(tabDebug, "Fire All 'Collect'", function()
    local l = findRemoteAll({"Collect","Claim"})
    for _, r in ipairs(l) do pcall(function() r:FireServer() end) end
    notify("Test", #l.." fired", 2)
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
TabButtons["MAIN"].BackgroundColor3 = Color3.fromRGB(70,70,82)
TabButtons["MAIN"].TextColor3 = Color3.fromRGB(255,255,255)

notify("BPHUB Anime Dice", "Loaded! "..#RemoteList.." remotes, "..#unitNames.." units.", 4)
print("[BPHUB Anime Dice] Remotes: "..#RemoteList.." | Units: "..#unitNames)