--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE (FIXED & EDITED)
       - Added Accordion/Dropdown for Sections
       - Fixed Minimize Size
       - Fixed Close Button (Added Open Button)
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
    BgMain      = Color3.fromRGB(16, 16, 20),
    BgGlass     = Color3.fromRGB(24, 24, 32),
    BgElement   = Color3.fromRGB(32, 32, 42),
    BgHover     = Color3.fromRGB(42, 42, 54),
    TextMain    = Color3.fromRGB(255, 255, 255),
    TextDim     = Color3.fromRGB(160, 160, 175),
    Accent      = Color3.fromRGB(130, 90, 255),
    Border      = Color3.fromRGB(50, 50, 65),
    ToggleOff   = Color3.fromRGB(50, 50, 60),
    ToggleOn    = Color3.fromRGB(130, 90, 255)
}

local FontMain = Enum.Font.Gotham
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

local function AddGradient(parent, color1, color2, rotation)
    return CreateInstance("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color1 or Theme.Accent),
            ColorSequenceKeypoint.new(1, color2 or Color3.fromRGB(90, 60, 200))
        }),
        Rotation = rotation or 90
    }, parent)
end

-- ==========================================
-- 4. MAIN WINDOW & GLASS BACKGROUND
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

-- TOMBOL BUKA UI (Muncul saat klik X)
local OpenBtn = CreateInstance("TextButton", {
    Name = "OpenBtn",
    Size = UDim2.new(0, 120, 0, 40),
    Position = UDim2.new(0.5, -60, 0, 20),
    BackgroundColor3 = Theme.Accent,
    Text = "PJANE HUB",
    TextColor3 = Color3.new(1, 1, 1),
    Font = FontBold,
    TextSize = 12,
    Visible = false
}, ScreenGui)
AddCorner(OpenBtn, 8)
AddStroke(OpenBtn, Color3.new(1,1,1), 1, 0.5)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 580, 0, 420),
    Position = UDim2.new(0.5, -290, 0.5, -210),
    BackgroundColor3 = Theme.BgMain,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0
}, ScreenGui)
AddCorner(MainFrame, 14)
AddStroke(MainFrame, Theme.Accent, 1.2, 0.7)

local Shadow = CreateInstance("ImageLabel", {
    Size = UDim2.new(1, 40, 1, 40),
    Position = UDim2.new(0, -20, 0, -20),
    BackgroundTransparency = 1,
    Image = "rbxassetid://1316045217",
    ImageColor3 = Color3.new(0, 0, 0),
    ImageTransparency = 0.6,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(10, 10, 118, 118),
    ZIndex = 0
}, MainFrame)

local UIScale = CreateInstance("UIScale", {Scale = 1}, MainFrame)
local function UpdateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scaleX = (vp.X - 20) / 580
    local scaleY = (vp.Y - 20) / 420
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.6, 1)
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
    Size = UDim2.new(1, 0, 0, 56),
    BackgroundColor3 = Theme.BgGlass,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0
}, MainFrame)
AddCorner(Header, 14)
AddGradient(Header, Color3.fromRGB(30, 30, 40), Theme.BgMain, 90)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -120, 0, 24),
    Position = UDim2.new(0, 20, 0, 10),
    BackgroundTransparency = 1,
    Text = "PJANE HUB",
    TextColor3 = Theme.TextMain,
    Font = FontBlack,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -120, 0, 16),
    Position = UDim2.new(0, 21, 0, 32),
    BackgroundTransparency = 1,
    Text = "Deep Fishing Interface",
    TextColor3 = Theme.Accent,
    Font = FontBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local HeaderDivider = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0
}, Header)

local function CreateWindowBtn(text, xOffset, hoverColor)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, xOffset, 0.5, -14),
        BackgroundColor3 = Theme.BgElement,
        Text = text,
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 14,
        AutoButtonColor = false
    }, Header)
    AddCorner(btn, 6)
    TrackConnection(btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor, TextColor3 = Theme.TextMain}):Play()
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextDim}):Play()
    end))
    return btn
end

local MinBtn = CreateWindowBtn("-", -68, Theme.BgHover)
local CloseBtn = CreateWindowBtn("X", -34, Color3.fromRGB(200, 50, 50))

-- ==========================================
-- 6. SIDEBAR (Vertical Tabs)
-- ==========================================
local Sidebar = CreateInstance("Frame", {
    Size = UDim2.new(0, 60, 1, -60),
    Position = UDim2.new(0, 0, 0, 56),
    BackgroundTransparency = 1
}, MainFrame)

local TabContainer = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1
}, Sidebar)
CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder
}, TabContainer)
CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 12)}, TabContainer)

-- ==========================================
-- 7. CONTENT AREA & PAGE CONTAINER
-- ==========================================
local ContentArea = CreateInstance("Frame", {
    Size = UDim2.new(1, -68, 1, -64),
    Position = UDim2.new(0, 60, 0, 60),
    BackgroundTransparency = 1
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
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextDim}):Play()
    end
    
    targetPage.Visible = true
    ActiveTab = targetBtn
    TweenService:Create(targetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Accent, TextColor3 = Theme.TextMain}):Play()
end

local function CreatePage(name)
    local page = CreateInstance("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.new(0, 6, 0, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false
    }, ContentArea)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    CreateInstance("UIPadding", {PaddingBottom = UDim.new(0, 16)}, page)
    Pages[name] = page
    return page
end

local function CreateTab(name, iconText)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 40, 0, 40),
        BackgroundColor3 = Theme.BgElement,
        Text = iconText,
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 16,
        AutoButtonColor = false
    }, TabContainer)
    AddCorner(btn, 10)
    AddStroke(btn, Theme.Border, 1)

    TrackConnection(btn.MouseEnter:Connect(function()
        if ActiveTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play()
        end
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        if ActiveTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement}):Play()
        end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        SelectTab(name)
    end))

    Tabs[name] = btn
    return CreatePage(name)
end

-- ==========================================
-- 8. UI COMPONENTS
-- ==========================================

-- FITUR BARU: ACCORDION (Dropdown Buka/Tutup Section)
local function CreateAccordion(parentPage, titleText, defaultOpen)
    local isOpen = defaultOpen ~= false
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1
    }, parentPage)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, container)

    -- Header Tombol
    local headerBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.BgGlass,
        Text = (isOpen and "v " or "> ") .. string.upper(titleText),
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false
    }, container)
    AddCorner(headerBtn, 8)
    AddStroke(headerBtn, Theme.Border, 1, 0.5)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 12)}, headerBtn)

    -- Konten
    local content = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgGlass,
        BackgroundTransparency = 0.5,
        Visible = isOpen,
        BorderSizePixel = 0
    }, container)
    AddCorner(content, 8)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
    CreateInstance("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12)
    }, content)

    -- Logic Klik
    TrackConnection(headerBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        content.Visible = isOpen
        headerBtn.Text = (isOpen and "v " or "> ") .. string.upper(titleText)
    end))

    return content
end

-- Fitur lama Section (Statis/Tidak bisa ditutup)
local function CreateSection(parentPage, titleText)
    local section = CreateInstance("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgGlass,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0
    }, parentPage)
    AddCorner(section, 12)
    AddStroke(section, Theme.Border, 1, 0.5)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, section)
    CreateInstance("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14)
    }, section)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = string.upper(titleText),
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, section)
    return section
end

local function CreateToggle(parent, text, default, callback)
    local state = default or false
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1
    }, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local switchBg = CreateInstance("Frame", {
        Size = UDim2.new(0, 36, 0, 20),
        Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0
    }, container)
    AddCorner(switchBg, 10)

    local knob = CreateInstance("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0
    }, switchBg)
    AddCorner(knob, 8)

    local hitbox = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = ""
    }, container)

    TrackConnection(hitbox.MouseButton1Click:Connect(function()
        state = not state
        local targetColor = state and Theme.ToggleOn or Theme.ToggleOff
        local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        if callback then task.spawn(callback, state) end
    end))
end

local function CreateSlider(parent, text, min, max, default, callback)
    local value = default or min
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1
    }, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local valueLabel = CreateInstance("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 18),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right
    }, container)

    local bar = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = Theme.ToggleOff,
        Text = "",
        AutoButtonColor = false
    }, container)
    AddCorner(bar, 3)

    local fill = CreateInstance("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0
    }, bar)
    AddCorner(fill, 3)
    AddGradient(fill, Theme.Accent, Color3.fromRGB(180, 150, 255), 90)

    local dragging = false
    local function update(x)
        local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valueLabel.Text = tostring(value)
        if callback then task.spawn(callback, value) end
    end

    TrackConnection(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end))
    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end))
    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function CreateButton(parent, text, callback)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.BgElement,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 12,
        AutoButtonColor = false
    }, parent)
    AddCorner(btn, 8)
    AddStroke(btn, Theme.Border, 1)

    TrackConnection(btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play()
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement}):Play()
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end))
end

local function CreateDropdown(parent, text, options, default, callback)
    local isOpen = false
    local selected = default or (options and options[1]) or "None"
    
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        ClipsDescendants = true
    }, parent)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, container)

    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        AutoButtonColor = false
    }, container)
    AddCorner(btn, 8)
    AddStroke(btn, Theme.Border, 1)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text .. ": " .. selected,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, btn)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -25, 0, 0),
        BackgroundTransparency = 1,
        Text = "+",
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 14,
    }, btn)

    local listFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.BgGlass,
        BorderSizePixel = 0
    }, container)
    AddCorner(listFrame, 8)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)

    local function UpdateList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(options) do
            local optBtn = CreateInstance("TextButton", {
                Size = UDim2.new(1, -8, 0, 28),
                BackgroundColor3 = Theme.BgElement,
                Text = tostring(opt),
                TextColor3 = Theme.TextDim,
                Font = FontMain,
                TextSize = 11,
                AutoButtonColor = false
            }, listFrame)
            AddCorner(optBtn, 6)
            
            TrackConnection(optBtn.MouseButton1Click:Connect(function()
                selected = opt
                btn:FindFirstChildOfClass("TextLabel").Text = text .. ": " .. selected
                isOpen = false
                TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                if callback then task.spawn(callback, selected) end
            end))
        end
    end
    UpdateList()

    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetHeight = isOpen and (#options * 30) + 8 or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
    end))
end

local function CreateInput(parent, text, placeholder, callback)
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1
    }, parent)
    
    local box = CreateInstance("TextBox", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false
    }, container)
    AddCorner(box, 8)
    AddStroke(box, Theme.Border, 1)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 10)}, box)
    
    TrackConnection(box.FocusLost:Connect(function()
        if callback then task.spawn(callback, box.Text) end
    end))
end

-- ==========================================
-- 9. IMPLEMENTASI FITUR (SESUAI GAMBAR)
-- ==========================================

-- 1. TAB MAIN (Pake Accordion biar bisa di Dropdown)
local TabMain = CreateTab("Main", "M")
local SecQuick = CreateAccordion(TabMain, "Quick Start", true) -- true = default kebuka
CreateToggle(SecQuick, "Auto Fish", false, function(s) print("Auto Fish:", s) end)
CreateToggle(SecQuick, "Smart Sell", false, function(s) print("Smart Sell:", s) end)
CreateToggle(SecQuick, "Smart Planner", false, function(s) print("Smart Planner:", s) end)
CreateToggle(SecQuick, "Auto Pond", false, function(s) print("Auto Pond:", s) end)
CreateToggle(SecQuick, "Auto Rewards", false, function(s) print("Auto Rewards:", s) end)

local SecCtrl = CreateAccordion(TabMain, "Controls", true)
CreateButton(SecCtrl, "Stop Everything", function() print("Stopped all.") end)
CreateButton(SecCtrl, "Reset Hub Options", function() print("Reset.") end)

-- 2. TAB FISHING
local TabFishing = CreateTab("Fishing", "F")
local SecAutoFish = CreateSection(TabFishing, "Auto Fish")
CreateDropdown(SecAutoFish, "Mode", {"Fast (default)", "Safe"}, "Fast (default)", function(v) end)
CreateSlider(SecAutoFish, "Perfect Rate", 0, 100, 60, function(v) end)
CreateToggle(SecAutoFish, "Index Hunt", false, function(s) end)
CreateToggle(SecAutoFish, "Tutorial hold (x2 luck)", false, function(s) end)
CreateToggle(SecAutoFish, "Keep catch streak on trips", false, function(s) end)

local SecBait = CreateSection(TabFishing, "Throw Charges & Bait")
CreateToggle(SecBait, "Use owned throw charges", false, function(s) end)
CreateToggle(SecBait, "Auto Bait", false, function(s) end)
CreateToggle(SecBait, "Buy bait", false, function(s) end)
CreateSlider(SecBait, "Bait budget (%)", 0, 100, 10, function(v) end)

local SecSell = CreateSection(TabFishing, "Smart Sell")
CreateSlider(SecSell, "Sell at backpack (%)", 0, 100, 90, function(v) end)
CreateSlider(SecSell, "Also sell every (min)", 0, 60, 0, function(v) end)
CreateDropdown(SecSell, "Keep rarities", {"Secret", "Exotic", "Mythic"}, "Secret, Exotic", function(v) end)
CreateToggle(SecSell, "Keep mutated fish", true, function(s) end)
CreateInput(SecSell, "Keep fish", "Type fish name...", function(txt) end)
CreateToggle(SecSell, "Coins potion at sale", false, function(s) end)
CreateToggle(SecSell, "Coins pet at sale", false, function(s) end)
CreateButton(SecSell, "Sell Now", function() print("Selling...") end)

local SecPond = CreateSection(TabFishing, "Auto Pond")
CreateToggle(SecPond, "Auto Pond", false, function(s) end)
CreateSlider(SecPond, "Visit every (min)", 0, 240, 60, function(v) end)

-- 3. TAB UPGRADES
local TabUpgrades = CreateTab("Upgrades", "U")
local SecUpg = CreateSection(TabUpgrades, "Upgrades")
CreateToggle(SecUpg, "Auto Upgrades", false, function(s) end)
CreateDropdown(SecUpg, "Upgrades", {"Capacity", "Strength", "Weight", "Bounce"}, "Capacity, Strength", function(v) end)
CreateToggle(SecUpg, "Auto Rods", false, function(s) end)
CreateToggle(SecUpg, "Auto Worlds", false, function(s) end)
CreateDropdown(SecUpg, "Movement", {"Teleport", "Walk"}, "Teleport", function(v) end)

local SecMerchant = CreateSection(TabUpgrades, "Traveling Merchant")
CreateToggle(SecMerchant, "Auto Merchant", false, function(s) end)
CreateDropdown(SecMerchant, "Buy", {"Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls"}, "Eggs, Potions", function(v) end)

-- 4. TAB ITEMS
local TabItems = CreateTab("Items", "I")
local SecChest = CreateSection(TabItems, "Chests & Gifts")
CreateToggle(SecChest, "Auto Open", false, function(s) end)

local SecRelic = CreateSection(TabItems, "Boss Relics & Summons")
CreateToggle(SecRelic, "Auto Relics", false, function(s) end)
CreateToggle(SecRelic, "Use Sunken Crowns", false, function(s) end)

local SecMutate = CreateSection(TabItems, "Mutation Dealer")
CreateToggle(SecMutate, "Auto Mutate", false, function(s) end)
CreateDropdown(SecMutate, "Scroll", {"Mutation Scroll first", "Ultra Mutation"}, "Mutation Scroll first", function(v) end)

local SecPotion = CreateSection(TabItems, "Potions")
CreateToggle(SecPotion, "Auto Potions", false, function(s) end)
CreateDropdown(SecPotion, "Potions", {"Luck", "Coins", "XP", "Mutation"}, "Luck, Coins, XP", function(v) end)

local SecPets = CreateSection(TabItems, "Pets, Eggs & Skin")
CreateToggle(SecPets, "Auto Hatch Eggs", false, function(s) end)
CreateToggle(SecPets, "Equip Best Pet", false, function(s) end)
CreateToggle(SecPets, "Auto Pond Pets", false, function(s) end)
CreateToggle(SecPets, "Wear best rod skin", false, function(s) end)

local SecEnchant = CreateSection(TabItems, "Enchant")
CreateToggle(SecEnchant, "Auto Enchant", false, function(s) end)

-- 5. TAB REWARDS
local TabRewards = CreateTab("Rewards", "R")
local SecRewards = CreateSection(TabRewards, "Rewards")
CreateToggle(SecRewards, "Auto Rewards", false, function(s) end)
CreateToggle(SecRewards, "Auto Big Mouth", false, function(s) end)
CreateToggle(SecRewards, "Auto Tasks (cargo orders)", false, function(s) end)

local SecCodes = CreateSection(TabRewards, "Codes")
CreateToggle(SecCodes, "Auto Redeem Codes", false, function(s) end)
CreateButton(SecCodes, "Redeem all known", function() print("Redeeming...") end)
CreateInput(SecCodes, "Code", "Type a code...", function(txt) print("Code: "..txt) end)
CreateButton(SecCodes, "Redeem", function() print("Redeem clicked") end)

-- 6. TAB WEBHOOK
local TabWebhook = CreateTab("Webhook", "W")
local SecDiscord = CreateSection(TabWebhook, "Discord Webhook")
CreateToggle(SecDiscord, "Post to Discord", false, function(s) end)
CreateInput(SecDiscord, "Webhook URL", "https://discord.com/api/webhooks/...", function(txt) end)
CreateToggle(SecDiscord, "Live stats card", false, function(s) end)
CreateSlider(SecDiscord, "Report every (min)", 0, 60, 30, function(v) end)
CreateToggle(SecDiscord, "Hide my username", false, function(s) end)

local SecPosts = CreateSection(TabWebhook, "Posts")
CreateToggle(SecPosts, "Rare catches", false, function(s) end)
CreateToggle(SecPosts, "Sales", false, function(s) end)
CreateToggle(SecPosts, "Purchases", false, function(s) end)
CreateToggle(SecPosts, "Codes redeemed", false, function(s) end)

-- 7. TAB MISC
local TabMisc = CreateTab("Misc", "S")
local SecMisc = CreateSection(TabMisc, "System & Utility")
CreateToggle(SecMisc, "Auto reconnect", false, function(s) end)
CreateToggle(SecMisc, "Hide paused popup", false, function(s) end)
CreateButton(SecMisc, "Rejoin now", function() print("Rejoining...") end)
CreateToggle(SecMisc, "Disable 3D rendering", false, function(s) end)
CreateDropdown(SecMisc, "FPS cap", {"Unlimited", "30", "60"}, "Unlimited", function(v) end)
CreateToggle(SecMisc, "Keep after teleport", false, function(s) end)
CreateButton(SecMisc, "Copy loader", function() print("Copied!") end)

-- Buka Tab Main secara default
SelectTab("Main")

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

-- FIX: Tombol X sekarang cuma nyembunyiin, munculin tombol Open
TrackConnection(CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end))

-- FIX: Tombol Open buat buka UI lagi
TrackConnection(OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end))

-- FIX: Minimize sekarang mengecil (250 width) bukan 580
local isMinimized = false
TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinBtn.Text = isMinimized and "+" or "-"
    Sidebar.Visible = not isMinimized
    ContentArea.Visible = not isMinimized
    HeaderDivider.Visible = not isMinimized
    
    -- Lebar diubah dari 580 ke 260 saat di-minimize
    local targetSize = isMinimized and UDim2.new(0, 260, 0, 56) or UDim2.new(0, 580, 0, 420)
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize}):Play()
end))