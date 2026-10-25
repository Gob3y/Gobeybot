--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE (PREMIUM)
       - Corvus-Style Two Column Layout
       - Collapsible Accordions
       - Multi-Select Dropdowns
       - Clean UI (No Emoticons)
       - Fixed Window Controls (Minimize, Close, Open)
    ===============================================
]]

-- ==========================================
-- 1. INITIALIZATION & SERVICES
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
for _ = 1, 20 do
    task.wait(0.1)
    if LP then break end
    LP = Players.LocalPlayer
end
if not LP then return end

local PlayerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local oldUI = PlayerGui:FindFirstChild("DeveloperPanel_UI")
if oldUI then oldUI:Destroy() end

local Connections = {}
local function TrackConnection(conn)
    table.insert(Connections, conn)
    return conn
end

-- ==========================================
-- 2. THEME & CONFIGURATION
-- ==========================================
local Theme = {
    BgMain      = Color3.fromRGB(12, 12, 14),
    BgGlass     = Color3.fromRGB(20, 20, 24),
    BgElement   = Color3.fromRGB(30, 30, 35),
    BgHover     = Color3.fromRGB(45, 45, 50),
    TextMain    = Color3.fromRGB(240, 240, 240),
    TextDim     = Color3.fromRGB(150, 150, 160),
    Accent      = Color3.fromRGB(100, 120, 255),
    Border      = Color3.fromRGB(40, 40, 45),
    ToggleOff   = Color3.fromRGB(50, 50, 55),
    ToggleOn    = Color3.fromRGB(100, 120, 255)
}

local FontMain = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold
local FontBlack = Enum.Font.GothamBlack

-- ==========================================
-- 3. UTILITY FUNCTIONS
-- ==========================================
local function CreateInstance(className, properties, parent)
    local obj = Instance.new(className)
    if properties then
        for k, v in pairs(properties) do obj[k] = v end
    end
    if parent then obj.Parent = parent end
    return obj
end

local function AddCorner(parent, radius)
    return CreateInstance("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function AddStroke(parent, color, thickness, transparency)
    return CreateInstance("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, parent)
end

-- ==========================================
-- 4. MAIN WINDOW
-- ==========================================
local ScreenGui = CreateInstance("ScreenGui", {
    Name = "DeveloperPanel_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PlayerGui)

ScreenGui.Destroying:Connect(function()
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)
end)

-- TOMBOL OPEN (Muncul saat UI di-close)
local OpenBtn = CreateInstance("TextButton", {
    Name = "OpenBtn",
    Size = UDim2.new(0, 140, 0, 40),
    Position = UDim2.new(0.5, -70, 0, 20),
    BackgroundColor3 = Theme.Accent,
    Text = "BUKA PJANE HUB",
    TextColor3 = Color3.new(1, 1, 1),
    Font = FontBold,
    TextSize = 12,
    Visible = false,
    ZIndex = 10
}, ScreenGui)
AddCorner(OpenBtn, 8)
AddStroke(OpenBtn, Color3.new(1,1,1), 1, 0.5)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 680, 0, 460), -- Diperlebar untuk 2 kolom
    Position = UDim2.new(0.5, -340, 0.5, -230),
    BackgroundColor3 = Theme.BgMain,
    BorderSizePixel = 0
}, ScreenGui)
AddCorner(MainFrame, 12)
AddStroke(MainFrame, Theme.Border, 1.5, 0.2)

local UIScale = CreateInstance("UIScale", {Scale = 1}, MainFrame)
local function UpdateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scaleX = (vp.X - 40) / 680
    local scaleY = (vp.Y - 40) / 460
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.5, 1)
end
UpdateScale()
TrackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(UpdateScale))
if workspace.CurrentCamera then
    TrackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale))
end

-- ==========================================
-- 5. HEADER
-- ==========================================
local Header = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Theme.BgGlass,
    BorderSizePixel = 0
}, MainFrame)
AddCorner(Header, 12)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -250, 0, 24),
    Position = UDim2.new(0, 20, 0, 10),
    BackgroundTransparency = 1,
    Text = "PJANE HUB",
    TextColor3 = Theme.TextMain,
    Font = FontBlack,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -250, 0, 16),
    Position = UDim2.new(0, 20, 0, 34),
    BackgroundTransparency = 1,
    Text = "Deep Fishing Interface",
    TextColor3 = Theme.TextDim,
    Font = FontMain,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

-- Pseudo Search Bar
local SearchBar = CreateInstance("Frame", {
    Size = UDim2.new(0, 200, 0, 30),
    Position = UDim2.new(1, -340, 0.5, -15),
    BackgroundColor3 = Theme.BgElement,
    BorderSizePixel = 0
}, Header)
AddCorner(SearchBar, 6)
AddStroke(SearchBar, Theme.Border, 1)
CreateInstance("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Search...",
    TextColor3 = Theme.TextDim,
    Font = FontMain,
    TextSize = 12
}, SearchBar)

-- Window Controls (Tombol Minimize & Close)
local function CreateWindowBtn(text, xOffset, hoverColor)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, xOffset, 0.5, -15), -- Posisi diatur dari ujung kanan
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 16,
        AutoButtonColor = false
    }, Header)
    TrackConnection(btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = hoverColor or Theme.TextMain}):Play()
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = Theme.TextDim}):Play()
    end))
    return btn
end

-- Posisi X di -45 (tidak terlalu mepet kanan), Minimize di -85
local CloseBtn = CreateWindowBtn("X", -45, Color3.fromRGB(255, 100, 100))
local MinBtn = CreateWindowBtn("-", -85, Theme.TextMain)

-- ==========================================
-- 6. SIDEBAR (Icons)
-- ==========================================
local Sidebar = CreateInstance("Frame", {
    Size = UDim2.new(0, 60, 1, -60),
    Position = UDim2.new(0, 0, 0, 60),
    BackgroundColor3 = Theme.BgGlass,
    BorderSizePixel = 0
}, MainFrame)
CreateInstance("Frame", { -- Garis pemisah
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0
}, Sidebar)

local TabContainer = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1
}, Sidebar)
CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder
}, TabContainer)
CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 15)}, TabContainer)

-- ==========================================
-- 7. CONTENT AREA (Two Columns)
-- ==========================================
local ContentArea = CreateInstance("Frame", {
    Size = UDim2.new(1, -60, 1, -60),
    Position = UDim2.new(0, 60, 0, 60),
    BackgroundColor3 = Theme.BgMain,
    BorderSizePixel = 0
}, MainFrame)

local Pages = {}
local Tabs = {}
local ActiveTab = nil

local function SelectTab(name)
    local targetBtn = Tabs[name]
    local targetPage = Pages[name]
    if not targetBtn or not targetPage then return end
    
    for _, p in pairs(Pages) do p.Visible = false end
    for _, b in pairs(Tabs) do
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgGlass, TextColor3 = Theme.TextDim}):Play()
    end
    
    targetPage.Visible = true
    ActiveTab = targetBtn
    TweenService:Create(targetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextMain}):Play()
end

local function CreatePage(name)
    local page = CreateInstance("Frame", {
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false
    }, ContentArea)
    
    -- Kolom Kiri
    local leftCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -15, 1, 0),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)
    
    -- Kolom Kanan
    local rightCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -15, 1, 0),
        Position = UDim2.new(0.5, 5, 0, 10),
        BackgroundTransparency = 1,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, rightCol)

    Pages[name] = page
    return {Left = leftCol, Right = rightCol}
end

local function CreateTab(name, text)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 40, 0, 40),
        BackgroundColor3 = Theme.BgGlass,
        Text = text,
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 14,
        AutoButtonColor = false
    }, TabContainer)
    AddCorner(btn, 8)

    TrackConnection(btn.MouseEnter:Connect(function()
        if ActiveTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play() end
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        if ActiveTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgGlass}):Play() end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        SelectTab(name)
    end))

    Tabs[name] = btn
    return CreatePage(name)
end

-- ==========================================
-- 8. UI COMPONENTS (Tanpa Emoticon)
-- ==========================================

-- 8.1 ACCORDION (Collapsible Section)
local function CreateAccordion(parent, titleText, defaultOpen)
    local isOpen = defaultOpen ~= false
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1
    }, parent)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, container)

    -- Header
    local headerBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.BgGlass,
        Text = "",
        AutoButtonColor = false
    }, container)
    AddCorner(headerBtn, 8)
    AddStroke(headerBtn, Theme.Border, 1, 0.5)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left
    }, headerBtn)

    local arrow = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = isOpen and "v" or ">",
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 14
    }, headerBtn)

    -- Content
    local content = CreateInstance("Frame", {
        Size = UDim2.new(1, -10, 0, 0),
        Position = UDim2.new(0, 5, 0, 40),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = isOpen
    }, container)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, content)

    TrackConnection(headerBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        content.Visible = isOpen
        arrow.Text = isOpen and "v" or ">"
    end))

    return content
end

-- 8.2 TOGGLE
local function CreateToggle(parent, text, default, callback)
    local state = default or false
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1}, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local switchBg = CreateInstance("Frame", {
        Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -34, 0.5, -9), BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff, BorderSizePixel = 0
    }, container)
    AddCorner(switchBg, 9)

    local knob = CreateInstance("Frame", {
        Size = UDim2.new(0, 14, 0, 14), Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
    }, switchBg)
    AddCorner(knob, 7)

    local hitbox = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ""}, container)

    TrackConnection(hitbox.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if callback then task.spawn(callback, state) end
    end))
end

-- 8.3 SLIDER
local function CreateSlider(parent, text, min, max, default, suffix, callback)
    local value = default or min
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local valueLabel = CreateInstance("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 16), Position = UDim2.new(0.7, 0, 0, 0), BackgroundTransparency = 1, Text = tostring(value) .. (suffix or ""), TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right
    }, container)

    local bar = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 24), BackgroundColor3 = Theme.ToggleOff, Text = "", AutoButtonColor = false
    }, container)
    AddCorner(bar, 3)

    local fill = CreateInstance("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0
    }, bar)
    AddCorner(fill, 3)

    local dragging = false
    local function update(x)
        local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valueLabel.Text = tostring(value) .. (suffix or "")
        if callback then task.spawn(callback, value) end
    end

    TrackConnection(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(input.Position.X)
        end
    end))
    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end))
    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

-- 8.4 BUTTON
local function CreateButton(parent, text, callback)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.BgElement, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, AutoButtonColor = false
    }, parent)
    AddCorner(btn, 6)
    AddStroke(btn, Theme.Border, 1)

    TrackConnection(btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play() end))
    TrackConnection(btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement}):Play() end))
    TrackConnection(btn.MouseButton1Click:Connect(function() if callback then task.spawn(callback) end end))
end

-- 8.5 SINGLE DROPDOWN
local function CreateDropdown(parent, text, options, default, callback)
    local isOpen = false
    local selected = default or (options and options[1]) or "None"
    
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ClipsDescendants = true}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", AutoButtonColor = false
    }, container)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)

    local btnText = CreateInstance("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = selected, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, btn)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -25, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 12
    }, btn)

    local listFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Theme.BgElement, BorderSizePixel = 0, ZIndex = 5
    }, container)
    AddCorner(listFrame, 6); AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)

    for _, opt in ipairs(options) do
        local optBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, Text = tostring(opt), TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 12, AutoButtonColor = false, ZIndex = 6
        }, listFrame)
        
        TrackConnection(optBtn.MouseEnter:Connect(function() optBtn.TextColor3 = Theme.TextMain end))
        TrackConnection(optBtn.MouseLeave:Connect(function() optBtn.TextColor3 = Theme.TextDim end))
        
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            selected = opt
            btnText.Text = selected
            isOpen = false
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            container.Size = UDim2.new(1, 0, 0, 50)
            if callback then task.spawn(callback, selected) end
        end))
    end

    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetHeight = isOpen and (#options * 26) + 8 or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        container.Size = UDim2.new(1, 0, 0, 50 + targetHeight)
    end))
end

-- 8.6 MULTI-SELECT DROPDOWN
local function CreateMultiDropdown(parent, text, options, defaultList, callback)
    local isOpen = false
    local selectedOptions = defaultList or {}
    
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ClipsDescendants = true}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", AutoButtonColor = false
    }, container)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)

    local btnText = CreateInstance("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = table.concat(selectedOptions, ", ") .. "...", TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, btn)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -25, 0, 0), BackgroundTransparency = 1, Text = "v", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 12
    }, btn)

    local listFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Theme.BgElement, BorderSizePixel = 0, ZIndex = 5
    }, container)
    AddCorner(listFrame, 6); AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)

    local function updateText()
        if #selectedOptions > 0 then
            btnText.Text = table.concat(selectedOptions, ", ") .. "..."
        else
            btnText.Text = "Select..."
        end
    end

    for _, opt in ipairs(options) do
        local isSelected = table.find(selectedOptions, opt) ~= nil
        local optBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, Text = (isSelected and "[x] " or "[ ] ") .. tostring(opt), TextColor3 = isSelected and Theme.TextMain or Theme.TextDim, Font = FontMain, TextSize = 12, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
        }, listFrame)
        
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            local idx = table.find(selectedOptions, opt)
            if idx then
                table.remove(selectedOptions, idx)
                optBtn.Text = "[ ] " .. tostring(opt)
                optBtn.TextColor3 = Theme.TextDim
            else
                table.insert(selectedOptions, opt)
                optBtn.Text = "[x] " .. tostring(opt)
                optBtn.TextColor3 = Theme.TextMain
            end
            updateText()
            if callback then task.spawn(callback, selectedOptions) end
        end))
    end

    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetHeight = isOpen and (#options * 26) + 8 or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        container.Size = UDim2.new(1, 0, 0, 50 + targetHeight)
    end))
end

-- 8.7 INPUT
local function CreateInput(parent, text, placeholder, callback)
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local box = CreateInstance("TextBox", {
        Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false
    }, container)
    AddCorner(box, 6); AddStroke(box, Theme.Border, 1)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 8)}, box)
    
    TrackConnection(box.FocusLost:Connect(function()
        if callback then task.spawn(callback, box.Text) end
    end))
end

-- 8.8 STATUS TEXT
local function CreateStatus(parent, text)
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true
    }, parent)
end

-- ==========================================
-- 9. IMPLEMENTASI FITUR (SESUAI GAMBAR)
-- ==========================================

-- TAB INFO
local TabInfo = CreateTab("Info", "i")
local InfoLeft = TabInfo.Left
local InfoRight = TabInfo.Right

local AccCom = CreateAccordion(InfoLeft, "Community", false)
CreateButton(AccCom, "Join Discord", function() end)
local AccFeed = CreateAccordion(InfoLeft, "Feedback", false)
CreateButton(AccFeed, "Open Discord invite", function() end)
local AccQuick = CreateAccordion(InfoLeft, "Quick Setup", false)
CreateButton(AccQuick, "Open quick setup", function() end)

local AccSession = CreateAccordion(InfoRight, "Session", true)
CreateStatus(AccSession, "Game: Deep Fishing\nPlayers: 8 / 12\nServer age: 6m 47s\nSession: 6m 10s\nPerformance: 60 fps\nJob ID: 6c217fb0...")
CreateButton(AccSession, "Rejoin", function() end)
CreateButton(AccSession, "Server Hop", function() end)

-- TAB FISHING
local TabFishing = CreateTab("Fishing", "F")
local FishLeft = TabFishing.Left
local FishRight = TabFishing.Right

local AccAutoFish = CreateAccordion(FishLeft, "Auto Fish", true)
CreateToggle(AccAutoFish, "Auto Fish", false, function() end)
CreateDropdown(AccAutoFish, "Mode", {"Fast (default)", "Legit (game's auto fishing)"}, "Fast (default)", function() end)
CreateToggle(AccAutoFish, "Index Hunt", false, function() end)
CreateToggle(AccAutoFish, "Tutorial hold (x2 luck)", false, function() end)
CreateToggle(AccAutoFish, "Keep catch streak on trips", false, function() end)
CreateStatus(AccAutoFish, "Fishing at full speed (starting)\nLast cast: -\nCasts 0. Perfect 0. caught 0. finds 0. fights 0")

local AccSmartSell = CreateAccordion(FishRight, "Smart Sell", true)
CreateToggle(AccSmartSell, "Smart Sell", false, function() end)
CreateSlider(AccSmartSell, "Sell at backpack", 0, 100, 80, "% / 100%", function() end)
CreateSlider(AccSmartSell, "Also sell every", 0, 60, 0, " min", function() end)
CreateDropdown(AccSmartSell, "Keep rarities", {"Secret, Exotic", "Secret", "Exotic", "Mythic"}, "Secret, Exotic", function() end)
CreateToggle(AccSmartSell, "Keep mutated fish", false, function() end)
CreateInput(AccSmartSell, "Keep fish", "---", function() end)


-- TAB UPGRADES
local TabUpg = CreateTab("Upgrades", "U")
local UpgLeft = TabUpg.Left
local UpgRight = TabUpg.Right

local AccUpg = CreateAccordion(UpgLeft, "Upgrades", true)
CreateToggle(AccUpg, "Auto Upgrades", false, function() end)
CreateMultiDropdown(AccUpg, "Upgrades", {"Capacity", "Strength", "Weight", "Bounce"}, {"Capacity", "Strength"}, function() end)
CreateStatus(AccUpg, "Capacity 0  |  Strength 1  |  Weight 0  |  Bounce 0\nHooks per cast 3\nBought 0 this session")

local AccMerch = CreateAccordion(UpgLeft, "Traveling Merchant", false)
CreateToggle(AccMerch, "Auto Merchant", false, function() end)
CreateMultiDropdown(AccMerch, "Buy", {"Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls"}, {"Eggs", "Potions"}, function() end)

local AccRods = CreateAccordion(UpgRight, "Rods", true)
CreateToggle(AccRods, "Auto Rods", false, function() end)
CreateStatus(AccRods, "Equipped Iron Rod (luck 10, strength 10)\nHall rods: Frostbite Rod: locked, Chrono Rod: locked\nBought 0 this session")

local AccWorlds = CreateAccordion(UpgRight, "Worlds", true)
CreateToggle(AccWorlds, "Auto Worlds", false, function() end)
CreateDropdown(AccWorlds, "Movement", {"Teleport", "Walk"}, "Teleport", function() end)
CreateStatus(AccWorlds, "In World 1, best unlocked World 1\n-")


-- TAB ITEMS
local TabItems = CreateTab("Items", "I")
local ItemsLeft = TabItems.Left
local ItemsRight = TabItems.Right

local AccChests = CreateAccordion(ItemsLeft, "Chests & Gifts", false)
CreateToggle(AccChests, "Auto Open", false, function() end)
CreateStatus(AccChests, "Opened 0  |  potions 0  |  relics 0\nLast: -")

local AccRelics = CreateAccordion(ItemsLeft, "Boss Relics & Summons", false)
CreateToggle(AccRelics, "Auto Relics", false, function() end)
CreateToggle(AccRelics, "Use Sunken Crowns", false, function() end)

local AccMutate = CreateAccordion(ItemsLeft, "Mutation Dealer", false)
CreateToggle(AccMutate, "Auto Mutate", false, function() end)
CreateDropdown(AccMutate, "Scroll", {"Mutation Scroll first", "Ultra first"}, "Mutation Scroll first", function() end)
CreateStatus(AccMutate, "Mutation Scrolls 0, Ultra 0\nSpins 0 this session")

local AccPotions = CreateAccordion(ItemsRight, "Potions", true)
CreateToggle(AccPotions, "Auto Potions", false, function() end)
CreateMultiDropdown(AccPotions, "Potions", {"Luck", "Coins", "XP", "Mutation"}, {"Luck", "Coins", "XP"}, function() end)
CreateStatus(AccPotions, "Running: none\nOwned: none")

local AccEnchant = CreateAccordion(ItemsRight, "Enchant", false)
CreateToggle(AccEnchant, "Auto Enchant", false, function() end)
CreateMultiDropdown(AccEnchant, "Stop at", {"Abyssal", "Archivist", "Autopilot", "Cursed", "Deepnet", "Eclipse", "Fishmonger"}, {"Deepnet", "Fishmonger"}, function() end)
CreateStatus(AccEnchant, "Rod enchants: - / -\nStones 0, Ultra 0  |  rolls 0 this session")

local AccPets = CreateAccordion(ItemsRight, "Pets, Eggs & Skin", false)
CreateToggle(AccPets, "Auto Hatch Eggs", false, function() end)
CreateToggle(AccPets, "Equip Best Pet", false, function() end)
CreateToggle(AccPets, "Auto Pond Pets", false, function() end)
CreateToggle(AccPets, "Wear best rod skin", false, function() end)


-- TAB REWARDS
local TabRewards = CreateTab("Rewards", "R")
local RewLeft = TabRewards.Left
local RewRight = TabRewards.Right

local AccRewards = CreateAccordion(RewLeft, "Rewards", true)
CreateToggle(AccRewards, "Auto Rewards", false, function() end)
CreateStatus(AccRewards, "Claimed 0 this session")

local AccBigMouth = CreateAccordion(RewLeft, "Big Mouth", true)
CreateToggle(AccBigMouth, "Auto Big Mouth", false, function() end)
CreateStatus(AccBigMouth, "Luck +0%  |  feeds 0  |  goal 0/9.5 kg\nHungry now")

local AccCodes = CreateAccordion(RewRight, "Codes", true)
CreateToggle(AccCodes, "Auto Redeem Codes", false, function() end)
CreateButton(AccCodes, "Redeem all known", function() end)
CreateInput(AccCodes, "Code", "Type a code from the game's socials", function() end)
CreateButton(AccCodes, "Redeem", function() end)

local AccCargo = CreateAccordion(RewRight, "Cargo Orders", false)
CreateToggle(AccCargo, "Auto Tasks (cargo orders)", false, function() end)


-- TAB WEBHOOK
local TabWebhook = CreateTab("Webhook", "W")
local WebLeft = TabWebhook.Left
local WebRight = TabWebhook.Right

local AccDiscord = CreateAccordion(WebLeft, "Discord Webhook", true)
CreateToggle(AccDiscord, "Post to Discord", false, function() end)
CreateInput(AccDiscord, "Webhook URL", "https://discord.com/api/webhooks/...", function() end)
CreateToggle(AccDiscord, "Live stats card", false, function() end)
CreateSlider(AccDiscord, "Report every", 0, 60, 30, " min", function() end)
CreateToggle(AccDiscord, "Hide my username", false, function() end)
CreateButton(AccDiscord, "Send test", function() end)

local AccPosts = CreateAccordion(WebRight, "Posts", true)
CreateToggle(AccPosts, "Rare catches", false, function() end)
CreateDropdown(AccPosts, "Rare means", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}, "Secret, Exotic", function() end)
CreateToggle(AccPosts, "Sales", false, function() end)
CreateToggle(AccPosts, "Purchases", false, function() end)
CreateToggle(AccPosts, "Codes redeemed", false, function() end)


-- TAB MISC
local TabMisc = CreateTab("Misc", "S")
local MiscLeft = TabMisc.Left
local MiscRight = TabMisc.Right

local AccAntiAFK = CreateAccordion(MiscLeft, "Anti AFK", true)
CreateToggle(AccAntiAFK, "Anti AFK", false, function() end)
CreateToggle(AccAntiAFK, "Auto jump", false, function() end)
CreateSlider(AccAntiAFK, "Jump every", 0, 60, 30, "s", function() end)
CreateToggle(AccAntiAFK, "Micro movement", false, function() end)
CreateStatus(AccAntiAFK, "AFK inputs sent 0\nLast activity 1m 35s ago")

local AccConn = CreateAccordion(MiscLeft, "Connection", false)
CreateToggle(AccConn, "Auto reconnect", false, function() end)
CreateToggle(AccConn, "Hide paused popup", false, function() end)
CreateButton(AccConn, "Rejoin now", function() end)

local AccPerform = CreateAccordion(MiscRight, "Performance", true)
CreateToggle(AccPerform, "Anti lag", false, function() end)
CreateDropdown(AccPerform, "Level", {"Balanced", "High", "Low"}, "Balanced", function() end)
CreateToggle(AccPerform, "Disable 3D rendering", false, function() end)
CreateDropdown(AccPerform, "FPS cap", {"Unlimited", "30", "60"}, "Unlimited", function() end)

local AccAutoExec = CreateAccordion(MiscRight, "Auto Execute", false)
CreateToggle(AccAutoExec, "Keep after teleport", false, function() end)
CreateButton(AccAutoExec, "Copy loader", function() end)


-- Buka Tab Info secara default
SelectTab("Info")

-- ==========================================
-- 10. DRAG & WINDOW CONTROLS
-- ==========================================
local isDragging = false
local dragStart, startPos

TrackConnection(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end))

TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

-- Tombol Close (X)
TrackConnection(CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end))

-- Tombol Open
TrackConnection(OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end))

-- Tombol Minimize (-)
local isMinimized = false
TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinBtn.Text = isMinimized and "+" or "-"
    Sidebar.Visible = not isMinimized
    ContentArea.Visible = not isMinimized
    
    -- Ukuran saat di-minimize disesuaikan (320 lebar, tidak terlalu besar)
    local targetSize = isMinimized and UDim2.new(0, 320, 0, 60) or UDim2.new(0, 680, 0, 460)
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end))