--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE 
       (1000+ LINES - FULL MEGA EDITION)
       
       Features:
       - Key System (Key: Pjane1) - Fixed UI Overflow
       - No Clipboard (Safe from Syntax Error)
       - Resizable Window (Corner Drag)
       - Draggable Header (Anti-Stuck)
       - Full Accordion & Dropdowns (Sesuai Corvus)
    ===============================================
]]

-- ==========================================
-- KONFIGURASI
-- ==========================================
local ENABLE_KEY_SYSTEM = true
local CORRECT_KEY = "Pjane1"

-- ==========================================
-- 1. INITIALIZATION & SERVICES
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Hapus UI lama jika ada (Mencegah tumpang tindih)
local oldUI = PlayerGui:FindFirstChild("DeveloperPanel_UI")
if oldUI then 
    oldUI:Destroy() 
end

-- Tabel untuk menyimpan koneksi (mencegah memory leak)
local Connections = {}
local function TrackConnection(conn)
    table.insert(Connections, conn)
    return conn
end

-- ==========================================
-- 2. THEME & CONFIGURATION
-- ==========================================
local Theme = {
    BgMain      = Color3.fromRGB(15, 15, 18),
    BgGlass     = Color3.fromRGB(22, 22, 26),
    BgElement   = Color3.fromRGB(32, 32, 38),
    BgHover     = Color3.fromRGB(45, 45, 52),
    TextMain    = Color3.fromRGB(245, 245, 245),
    TextDim     = Color3.fromRGB(150, 150, 160),
    Accent      = Color3.fromRGB(110, 130, 255),
    Border      = Color3.fromRGB(45, 45, 52),
    ToggleOff   = Color3.fromRGB(50, 50, 58),
    ToggleOn    = Color3.fromRGB(110, 130, 255)
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
        for k, v in pairs(properties) do 
            obj[k] = v 
        end
    end
    if parent then 
        obj.Parent = parent 
    end
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
-- 4. UNIVERSAL RESIZE HANDLE
-- ==========================================
local function MakeResizable(frame, minSize)
    local handle = CreateInstance("Frame", {
        Name = "ResizeHandle",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -16, 1, -16),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 100
    }, frame)
    AddCorner(handle, 4)

    local isResizing = false
    local resizeStartSize = Vector2.new()
    local resizeStartPos = Vector2.new()

    TrackConnection(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = true
            resizeStartSize = Vector2.new(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
            resizeStartPos = Vector2.new(input.Position.X, input.Position.Y)
        end
    end))

    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local deltaX = input.Position.X - resizeStartPos.X
            local deltaY = input.Position.Y - resizeStartPos.Y

            local newWidth = math.max(minSize.X, resizeStartSize.X + (deltaX * 2))
            local newHeight = math.max(minSize.Y, resizeStartSize.Y + (deltaY * 2))

            frame.Size = UDim2.fromOffset(newWidth, newHeight)
        end
    end))

    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = false
        end
    end))
end

-- ==========================================
-- 5. MAIN SCREEN GUI & MAIN FRAME
-- ==========================================
local ScreenGui = CreateInstance("ScreenGui", {
    Name = "DeveloperPanel_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global
}, PlayerGui)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 680, 0, 460),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5), 
    BackgroundColor3 = Theme.BgMain,
    BorderSizePixel = 0,
    ClipsDescendants = true, 
    Visible = not ENABLE_KEY_SYSTEM, 
    ZIndex = 1
}, ScreenGui)
AddCorner(MainFrame, 12)
AddStroke(MainFrame, Theme.Border, 1.5, 0)
MakeResizable(MainFrame, Vector2.new(500, 350))

-- ==========================================
-- 6. KEY SYSTEM UI (ANTI OVERFLOW)
-- ==========================================
if ENABLE_KEY_SYSTEM then
    local KeyOverlay = CreateInstance("Frame", {
        Name = "KeyOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 50
    }, ScreenGui)

    local KeyFrame = CreateInstance("Frame", {
        Name = "KeyFrame",
        Size = UDim2.new(0, 400, 0, 250),
        Position = UDim2.new(0.5, 0, 0.55, 0), 
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.BgMain,
        BorderSizePixel = 0,
        ZIndex = 51
    }, KeyOverlay)
    AddCorner(KeyFrame, 12)
    AddStroke(KeyFrame, Theme.Border, 1.5)
    MakeResizable(KeyFrame, Vector2.new(320, 250))

    -- UIListLayout Mencegah Input Meluber
    CreateInstance("UIListLayout", {
        Padding = UDim.new(0, 10), 
        HorizontalAlignment = Enum.HorizontalAlignment.Center, 
        SortOrder = Enum.SortOrder.LayoutOrder
    }, KeyFrame)
    
    CreateInstance("UIPadding", {
        PaddingTop = UDim.new(0, 20), 
        PaddingBottom = UDim.new(0, 20)
    }, KeyFrame)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 0, 30), 
        BackgroundTransparency = 1, 
        Text = "PJANE HUB", 
        TextColor3 = Theme.TextMain, 
        Font = FontBlack, 
        TextSize = 24, 
        TextXAlignment = Enum.TextXAlignment.Center, 
        LayoutOrder = 1, 
        ZIndex = 52
    }, KeyFrame)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 0, 20), 
        BackgroundTransparency = 1, 
        Text = "Enter the key to access the interface", 
        TextColor3 = Theme.TextDim, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Center, 
        LayoutOrder = 2, 
        ZIndex = 52
    }, KeyFrame)

    local InputContainer = CreateInstance("Frame", {
        Size = UDim2.new(0.9, 0, 0, 40), 
        BackgroundTransparency = 1, 
        LayoutOrder = 4, 
        ZIndex = 52
    }, KeyFrame)
    
    CreateInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, 
        Padding = UDim.new(0, 10), 
        SortOrder = Enum.SortOrder.LayoutOrder
    }, InputContainer)

    local KeyInput = CreateInstance("TextBox", {
        Size = UDim2.new(0.6, -5, 1, 0), 
        BackgroundColor3 = Theme.BgElement, 
        Text = "", 
        PlaceholderText = "Key...", 
        PlaceholderColor3 = Theme.TextDim, 
        TextColor3 = Theme.TextMain, 
        Font = FontBold, 
        TextSize = 14, 
        TextXAlignment = Enum.TextXAlignment.Center, 
        ClearTextOnFocus = false, 
        ZIndex = 52
    }, InputContainer)
    AddCorner(KeyInput, 8)
    AddStroke(KeyInput, Theme.Border, 1)

    local UnlockBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.4, -5, 1, 0), 
        BackgroundColor3 = Theme.Accent, 
        Text = "Unlock", 
        TextColor3 = Color3.new(1, 1, 1), 
        Font = FontBold, 
        TextSize = 14, 
        AutoButtonColor = false, 
        ZIndex = 52
    }, InputContainer)
    AddCorner(UnlockBtn, 8)

    -- TOMBOL DISCORD STATIS (TANPA AUTO-COPY)
    local DiscordBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.9, 0, 0, 40), 
        BackgroundColor3 = Theme.BgGlass, 
        Text = "Discord: discord.gg/PdQvN2bDCu", 
        TextColor3 = Theme.TextMain, 
        Font = FontBold, 
        TextSize = 13, 
        AutoButtonColor = false, 
        LayoutOrder = 5, 
        ZIndex = 52
    }, KeyFrame)
    AddCorner(DiscordBtn, 8)
    AddStroke(DiscordBtn, Theme.Border, 1)

    local function CheckKey()
        if KeyInput.Text == CORRECT_KEY then
            KeyOverlay:Destroy()
            MainFrame.Visible = true
        else
            KeyInput.Text = "Invalid Key"
            KeyInput.TextColor3 = Color3.fromRGB(255, 100, 100)
            task.wait(1)
            KeyInput.Text = ""
            KeyInput.TextColor3 = Theme.TextMain
        end
    end

    TrackConnection(UnlockBtn.MouseButton1Click:Connect(CheckKey))
    TrackConnection(KeyInput.FocusLost:Connect(function(enterPressed) 
        if enterPressed then CheckKey() end 
    end))
end

-- ==========================================
-- 7. HEADER & WINDOW CONTROLS
-- ==========================================
local Header = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Theme.BgGlass,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 10
}, MainFrame)
AddCorner(Header, 12)

CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 1), 
    Position = UDim2.new(0, 0, 1, 0), 
    BackgroundColor3 = Theme.Border, 
    BorderSizePixel = 0, 
    ZIndex = 10
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -250, 0, 24), 
    Position = UDim2.new(0, 20, 0, 10), 
    BackgroundTransparency = 1, 
    Text = "PJANE HUB", 
    TextColor3 = Theme.TextMain, 
    Font = FontBlack, 
    TextSize = 20, 
    TextXAlignment = Enum.TextXAlignment.Left, 
    Active = false, 
    ZIndex = 10
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -250, 0, 16), 
    Position = UDim2.new(0, 20, 0, 34), 
    BackgroundTransparency = 1, 
    Text = "Deep Fishing Interface", 
    TextColor3 = Theme.TextDim, 
    Font = FontMain, 
    TextSize = 11, 
    TextXAlignment = Enum.TextXAlignment.Left, 
    Active = false, 
    ZIndex = 10
}, Header)

local function CreateWindowBtn(text, xOffset, hoverColor)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 32, 0, 32), 
        Position = UDim2.new(1, xOffset, 0.5, -16),
        BackgroundColor3 = Theme.BgElement, 
        Text = text, 
        TextColor3 = Theme.TextDim,
        Font = FontBold, 
        TextSize = 14, 
        AutoButtonColor = false, 
        ZIndex = 11
    }, Header)
    AddCorner(btn, 6)
    AddStroke(btn, Theme.Border, 1)
    
    TrackConnection(btn.MouseEnter:Connect(function() 
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover, TextColor3 = hoverColor or Theme.TextMain}):Play() 
    end))
    TrackConnection(btn.MouseLeave:Connect(function() 
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextDim}):Play() 
    end))
    return btn
end

local CloseBtn = CreateWindowBtn("X", -120, Color3.fromRGB(255, 100, 100))
local MinBtn = CreateWindowBtn("-", -80, Theme.TextMain)

-- ==========================================
-- 8. SIDEBAR & CONTENT AREA
-- ==========================================
local Sidebar = CreateInstance("Frame", {
    Size = UDim2.new(0, 60, 1, -60), 
    Position = UDim2.new(0, 0, 0, 60),
    BackgroundColor3 = Theme.BgGlass, 
    BorderSizePixel = 0, 
    ZIndex = 2
}, MainFrame)

CreateInstance("Frame", {
    Size = UDim2.new(0, 1, 1, 0), 
    Position = UDim2.new(1, 0, 0, 0), 
    BackgroundColor3 = Theme.Border, 
    BorderSizePixel = 0, 
    ZIndex = 2
}, Sidebar)

local TabContainer = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 1, 0), 
    BackgroundTransparency = 1, 
    ZIndex = 2
}, Sidebar)

CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 5), 
    HorizontalAlignment = Enum.HorizontalAlignment.Center, 
    SortOrder = Enum.SortOrder.LayoutOrder
}, TabContainer)

CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 15)}, TabContainer)

local ContentArea = CreateInstance("Frame", {
    Size = UDim2.new(1, -60, 1, -60), 
    Position = UDim2.new(0, 60, 0, 60),
    BackgroundColor3 = Theme.BgMain, 
    BorderSizePixel = 0, 
    ZIndex = 1
}, MainFrame)

local Pages, Tabs, ActiveTab = {}, {}, nil

local function SelectTab(name)
    local targetBtn, targetPage = Tabs[name], Pages[name]
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
        Visible = false, 
        ZIndex = 1
    }, ContentArea)
    
    local leftCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -15, 1, 0), 
        Position = UDim2.new(0, 10, 0, 10), 
        BackgroundTransparency = 1, 
        ScrollBarThickness = 2, 
        ScrollBarImageColor3 = Theme.Border, 
        CanvasSize = UDim2.new(0, 0, 0, 0), 
        AutomaticCanvasSize = Enum.AutomaticSize.Y, 
        ClipsDescendants = false, 
        ZIndex = 2
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)
    
    local rightCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -15, 1, 0), 
        Position = UDim2.new(0.5, 5, 0, 10), 
        BackgroundTransparency = 1, 
        ScrollBarThickness = 2, 
        ScrollBarImageColor3 = Theme.Border, 
        CanvasSize = UDim2.new(0, 0, 0, 0), 
        AutomaticCanvasSize = Enum.AutomaticSize.Y, 
        ClipsDescendants = false, 
        ZIndex = 2
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
        AutoButtonColor = false, 
        ZIndex = 2
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
-- 9. UI COMPONENTS
-- ==========================================
local function CreateAccordion(parent, titleText, defaultOpen)
    local isOpen = defaultOpen ~= false
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0), 
        AutomaticSize = Enum.AutomaticSize.Y, 
        BackgroundTransparency = 1, 
        ZIndex = 2
    }, parent)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, container)
    
    local headerBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), 
        BackgroundColor3 = Theme.BgGlass, 
        Text = "", 
        AutoButtonColor = false, 
        ZIndex = 3
    }, container)
    AddCorner(headerBtn, 8)
    AddStroke(headerBtn, Theme.Border, 1)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0), 
        Position = UDim2.new(0, 15, 0, 0), 
        BackgroundTransparency = 1, 
        Text = titleText, 
        TextColor3 = Theme.TextMain, 
        Font = FontBold, 
        TextSize = 13, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 3
    }, headerBtn)
    
    local arrow = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 30, 1, 0), 
        Position = UDim2.new(1, -40, 0, 0), 
        BackgroundTransparency = 1, 
        Text = isOpen and "-" or "+", 
        TextColor3 = Theme.TextDim, 
        Font = FontBold, 
        TextSize = 18, 
        Active = false, 
        ZIndex = 3
    }, headerBtn)
    
    local content = CreateInstance("Frame", {
        Size = UDim2.new(1, -10, 0, 0), 
        Position = UDim2.new(0, 5, 0, 40), 
        AutomaticSize = Enum.AutomaticSize.Y, 
        BackgroundTransparency = 1, 
        Visible = isOpen, 
        ZIndex = 2
    }, container)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, content)
    
    TrackConnection(headerBtn.MouseButton1Click:Connect(function() 
        isOpen = not isOpen
        content.Visible = isOpen
        arrow.Text = isOpen and "-" or "+"
    end))
    
    return content
end

local function CreateToggle(parent, text, default, callback)
    local state = default or false
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 2}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local switchBg = CreateInstance("Frame", {
        Size = UDim2.new(0, 34, 0, 18), 
        Position = UDim2.new(1, -34, 0.5, -9), 
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff, 
        BorderSizePixel = 0, 
        ZIndex = 2
    }, container)
    AddCorner(switchBg, 9)
    
    local knob = CreateInstance("Frame", {
        Size = UDim2.new(0, 14, 0, 14), 
        Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), 
        BackgroundColor3 = Color3.new(1, 1, 1), 
        BorderSizePixel = 0, 
        ZIndex = 2
    }, switchBg)
    AddCorner(knob, 7)
    
    local hitbox = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), 
        BackgroundTransparency = 1, 
        Text = "", 
        ZIndex = 3
    }, container)
    
    TrackConnection(hitbox.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if callback then task.spawn(callback, state) end
    end))
end

local function CreateSlider(parent, text, min, max, default, suffix, callback)
    local value = default or min
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 2}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 16), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local valueLabel = CreateInstance("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 16), 
        Position = UDim2.new(0.7, 0, 0, 0), 
        BackgroundTransparency = 1, 
        Text = tostring(value) .. (suffix or ""), 
        TextColor3 = Theme.TextMain, 
        Font = FontBold, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Right, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local bar = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 6), 
        Position = UDim2.new(0, 0, 0, 24), 
        BackgroundColor3 = Theme.ToggleOff, 
        Text = "", 
        AutoButtonColor = false, 
        ZIndex = 3
    }, container)
    AddCorner(bar, 3)
    
    local fill = CreateInstance("Frame", {
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0), 
        BackgroundColor3 = Theme.Accent, 
        BorderSizePixel = 0, 
        ZIndex = 3
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            dragging = false 
        end 
    end))
end

local function CreateButton(parent, text, callback)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), 
        BackgroundColor3 = Theme.BgElement, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        AutoButtonColor = false, 
        ZIndex = 3
    }, parent)
    AddCorner(btn, 6)
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
    local isOpen, selected = false, default or (options and options[1]) or "None"
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 2}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), 
        Position = UDim2.new(0, 0, 0, 18), 
        BackgroundColor3 = Theme.BgElement, 
        Text = "", 
        AutoButtonColor = false, 
        ZIndex = 3
    }, container)
    AddCorner(btn, 6)
    AddStroke(btn, Theme.Border, 1)
    
    local btnText = CreateInstance("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0), 
        Position = UDim2.new(0, 10, 0, 0), 
        BackgroundTransparency = 1, 
        Text = selected, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 3
    }, btn)
    
    local icon = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0), 
        Position = UDim2.new(1, -25, 0, 0), 
        BackgroundTransparency = 1, 
        Text = "+", 
        TextColor3 = Theme.TextDim, 
        Font = FontBold, 
        TextSize = 14, 
        Active = false, 
        ZIndex = 3
    }, btn)
    
    local listFrame = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0), 
        Position = UDim2.new(0, 0, 0, 50), 
        BackgroundColor3 = Theme.BgGlass, 
        BorderSizePixel = 0, 
        ZIndex = 10, 
        ClipsDescendants = true, 
        ScrollBarThickness = 2, 
        CanvasSize = UDim2.new(0,0,0,0), 
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, container)
    AddCorner(listFrame, 6)
    AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)
    
    for _, opt in ipairs(options) do
        local optBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, -8, 0, 26), 
            BackgroundTransparency = 1, 
            Text = tostring(opt), 
            TextColor3 = Theme.TextDim, 
            Font = FontMain, 
            TextSize = 12, 
            AutoButtonColor = false, 
            ZIndex = 11
        }, listFrame)
        
        TrackConnection(optBtn.MouseEnter:Connect(function() optBtn.TextColor3 = Theme.TextMain end))
        TrackConnection(optBtn.MouseLeave:Connect(function() optBtn.TextColor3 = Theme.TextDim end))
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            selected = opt
            btnText.Text = selected
            isOpen = false
            icon.Text = "+"
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50)}):Play()
            if callback then task.spawn(callback, selected) end
        end))
    end
    
    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        icon.Text = isOpen and "-" or "+"
        local targetHeight = isOpen and math.min((#options * 28) + 8, 120) or 0
        container.ZIndex = isOpen and 10 or 2
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
    end))
end

local function CreateMultiDropdown(parent, text, options, defaultList, callback)
    local isOpen, selectedOptions = false, defaultList or {}
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 2}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), 
        Position = UDim2.new(0, 0, 0, 18), 
        BackgroundColor3 = Theme.BgElement, 
        Text = "", 
        AutoButtonColor = false, 
        ZIndex = 3
    }, container)
    AddCorner(btn, 6)
    AddStroke(btn, Theme.Border, 1)
    
    local btnText = CreateInstance("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0), 
        Position = UDim2.new(0, 10, 0, 0), 
        BackgroundTransparency = 1, 
        Text = table.concat(selectedOptions, ", "), 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 3
    }, btn)
    
    local icon = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 20, 1, 0), 
        Position = UDim2.new(1, -25, 0, 0), 
        BackgroundTransparency = 1, 
        Text = "+", 
        TextColor3 = Theme.TextDim, 
        Font = FontBold, 
        TextSize = 14, 
        Active = false, 
        ZIndex = 3
    }, btn)
    
    local listFrame = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0), 
        Position = UDim2.new(0, 0, 0, 50), 
        BackgroundColor3 = Theme.BgGlass, 
        BorderSizePixel = 0, 
        ZIndex = 10, 
        ClipsDescendants = true, 
        ScrollBarThickness = 2, 
        CanvasSize = UDim2.new(0,0,0,0), 
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, container)
    AddCorner(listFrame, 6)
    AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)
    
    local function updateText() 
        btnText.Text = #selectedOptions > 0 and table.concat(selectedOptions, ", ") or "Select..." 
    end
    
    for _, opt in ipairs(options) do
        local isSelected = table.find(selectedOptions, opt) ~= nil
        local optBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, -8, 0, 26), 
            BackgroundTransparency = 1, 
            Text = (isSelected and "[x] " or "[ ] ") .. tostring(opt), 
            TextColor3 = isSelected and Theme.TextMain or Theme.TextDim, 
            Font = FontMain, 
            TextSize = 12, 
            AutoButtonColor = false, 
            TextXAlignment = Enum.TextXAlignment.Left, 
            ZIndex = 11
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
        icon.Text = isOpen and "-" or "+"
        local targetHeight = isOpen and math.min((#options * 28) + 8, 120) or 0
        container.ZIndex = isOpen and 10 or 2
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
    end))
end

local function CreateInput(parent, text, placeholder, callback)
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, ZIndex = 2}, parent)
    
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        Active = false, 
        ZIndex = 2
    }, container)
    
    local box = CreateInstance("TextBox", {
        Size = UDim2.new(1, 0, 0, 26), 
        Position = UDim2.new(0, 0, 0, 18), 
        BackgroundColor3 = Theme.BgElement, 
        Text = "", 
        PlaceholderText = placeholder, 
        PlaceholderColor3 = Theme.TextDim, 
        TextColor3 = Theme.TextMain, 
        Font = FontMain, 
        TextSize = 12, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        ClearTextOnFocus = false, 
        ZIndex = 3
    }, container)
    AddCorner(box, 6)
    AddStroke(box, Theme.Border, 1)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 8)}, box)
    
    TrackConnection(box.FocusLost:Connect(function() 
        if callback then task.spawn(callback, box.Text) end 
    end))
end

local function CreateStatus(parent, text)
    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), 
        BackgroundTransparency = 1, 
        Text = text, 
        TextColor3 = Theme.TextDim, 
        Font = FontMain, 
        TextSize = 11, 
        TextXAlignment = Enum.TextXAlignment.Left, 
        TextWrapped = true, 
        Active = false, 
        ZIndex = 2
    }, parent)
end

-- ==========================================
-- 10. FITUR UI LENGKAP (CORVUS STYLE)
-- ==========================================

-- TAB INFO
local TabInfo = CreateTab("Info", "i")
local AccCom = CreateAccordion(TabInfo.Left, "Community", false)
CreateButton(AccCom, "Join Discord", function() end)
local AccFeed = CreateAccordion(TabInfo.Left, "Feedback", false)
CreateButton(AccFeed, "Open Discord invite", function() end)
local AccSession = CreateAccordion(TabInfo.Right, "Session", true)
CreateStatus(AccSession, "Game: Deep Fishing\nPlayers: 8 / 12\nServer age: 6m 47s\nSession: 6m 10s\nPerformance: 60 fps\nJob ID: 6c217fb0...")

-- TAB FISHING
local TabFishing = CreateTab("Fishing", "F")
local AccAutoFish = CreateAccordion(TabFishing.Left, "Auto Fish", true)
CreateToggle(AccAutoFish, "Auto Fish", false, function() end)
CreateDropdown(AccAutoFish, "Mode", {"Fast (default)", "Legit (game's auto fishing)"}, "Fast (default)", function() end)
CreateToggle(AccAutoFish, "Index Hunt", false, function() end)
CreateToggle(AccAutoFish, "Tutorial hold (x2 luck)", false, function() end)
CreateStatus(AccAutoFish, "Fishing at full speed (starting)\nLast cast: -\nCasts 0. Perfect 0. caught 0. finds 0. fights 0")
local AccSmartSell = CreateAccordion(TabFishing.Right, "Smart Sell", true)
CreateToggle(AccSmartSell, "Smart Sell", false, function() end)
CreateSlider(AccSmartSell, "Sell at backpack", 0, 100, 80, "% / 100%", function() end)
CreateSlider(AccSmartSell, "Also sell every", 0, 60, 0, " min", function() end)
CreateDropdown(AccSmartSell, "Keep rarities", {"Secret, Exotic", "Secret", "Exotic", "Mythic"}, "Secret, Exotic", function() end)
CreateToggle(AccSmartSell, "Keep mutated fish", false, function() end)
CreateInput(AccSmartSell, "Keep fish", "---", function() end)

-- TAB UPGRADES
local TabUpg = CreateTab("Upgrades", "U")
local AccUpg = CreateAccordion(TabUpg.Left, "Upgrades", true)
CreateToggle(AccUpg, "Auto Upgrades", false, function() end)
CreateMultiDropdown(AccUpg, "Upgrades", {"Capacity", "Strength", "Weight", "Bounce"}, {"Capacity", "Strength"}, function() end)
CreateStatus(AccUpg, "Capacity 0  |  Strength 1  |  Weight 0  |  Bounce 0\nHooks per cast 3\nBought 0 this session")
local AccMerch = CreateAccordion(TabUpg.Left, "Traveling Merchant", false)
CreateToggle(AccMerch, "Auto Merchant", false, function() end)
CreateMultiDropdown(AccMerch, "Buy", {"Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls"}, {"Eggs", "Potions"}, function() end)
local AccRods = CreateAccordion(TabUpg.Right, "Rods", true)
CreateToggle(AccRods, "Auto Rods", false, function() end)
CreateStatus(AccRods, "Equipped Iron Rod (luck 10, strength 10)\nHall rods: Frostbite Rod: locked, Chrono Rod: locked\nBought 0 this session")
local AccWorlds = CreateAccordion(TabUpg.Right, "Worlds", true)
CreateToggle(AccWorlds, "Auto Worlds", false, function() end)
CreateDropdown(AccWorlds, "Movement", {"Teleport", "Walk"}, "Teleport", function() end)
CreateStatus(AccWorlds, "In World 1, best unlocked World 1\n-")

-- TAB ITEMS
local TabItems = CreateTab("Items", "I")
local AccChests = CreateAccordion(TabItems.Left, "Chests & Gifts", false)
CreateToggle(AccChests, "Auto Open", false, function() end)
CreateStatus(AccChests, "Opened 0  |  potions 0  |  relics 0\nLast: -")
local AccRelics = CreateAccordion(TabItems.Left, "Boss Relics & Summons", false)
CreateToggle(AccRelics, "Auto Relics", false, function() end)
CreateToggle(AccRelics, "Use Sunken Crowns", false, function() end)
local AccMutate = CreateAccordion(TabItems.Left, "Mutation Dealer", false)
CreateToggle(AccMutate, "Auto Mutate", false, function() end)
CreateDropdown(AccMutate, "Scroll", {"Mutation Scroll first", "Ultra first"}, "Mutation Scroll first", function() end)
local AccPotions = CreateAccordion(TabItems.Right, "Potions", true)
CreateToggle(AccPotions, "Auto Potions", false, function() end)
CreateMultiDropdown(AccPotions, "Potions", {"Luck", "Coins", "XP", "Mutation"}, {"Luck", "Coins", "XP"}, function() end)
local AccEnchant = CreateAccordion(TabItems.Right, "Enchant", false)
CreateToggle(AccEnchant, "Auto Enchant", false, function() end)
CreateMultiDropdown(AccEnchant, "Stop at", {"Abyssal", "Archivist", "Autopilot", "Cursed", "Deepnet", "Eclipse", "Fishmonger"}, {"Deepnet", "Fishmonger"}, function() end)
local AccPets = CreateAccordion(TabItems.Right, "Pets, Eggs & Skin", false)
CreateToggle(AccPets, "Auto Hatch Eggs", false, function() end)
CreateToggle(AccPets, "Equip Best Pet", false, function() end)

-- TAB REWARDS
local TabRewards = CreateTab("Rewards", "R")
local AccRewards = CreateAccordion(TabRewards.Left, "Rewards", true)
CreateToggle(AccRewards, "Auto Rewards", false, function() end)
CreateStatus(AccRewards, "Claimed 0 this session")
local AccBigMouth = CreateAccordion(TabRewards.Left, "Big Mouth", true)
CreateToggle(AccBigMouth, "Auto Big Mouth", false, function() end)
local AccCodes = CreateAccordion(TabRewards.Right, "Codes", true)
CreateToggle(AccCodes, "Auto Redeem Codes", false, function() end)
CreateButton(AccCodes, "Redeem all known", function() end)
CreateInput(AccCodes, "Code", "Type a code...", function() end)

-- TAB WEBHOOK
local TabWebhook = CreateTab("Webhook", "W")
local AccDiscord = CreateAccordion(TabWebhook.Left, "Discord Webhook", true)
CreateToggle(AccDiscord, "Post to Discord", false, function() end)
CreateInput(AccDiscord, "Webhook URL", "https://discord.com/api/webhooks/...", function() end)
CreateSlider(AccDiscord, "Report every", 0, 60, 30, " min", function() end)
local AccPosts = CreateAccordion(TabWebhook.Right, "Posts", true)
CreateDropdown(AccPosts, "Rare means", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}, "Secret, Exotic", function() end)

-- TAB MISC
local TabMisc = CreateTab("Misc", "S")
local AccAntiAFK = CreateAccordion(TabMisc.Left, "Anti AFK", true)
CreateToggle(AccAntiAFK, "Anti AFK", false, function() end)
CreateSlider(AccAntiAFK, "Jump every", 0, 60, 30, "s", function() end)
local AccConn = CreateAccordion(TabMisc.Left, "Connection", false)
CreateToggle(AccConn, "Auto reconnect", false, function() end)
CreateButton(AccConn, "Rejoin now", function() end)
local AccPerform = CreateAccordion(TabMisc.Right, "Performance", true)
CreateToggle(AccPerform, "Anti lag", false, function() end)
CreateDropdown(AccPerform, "FPS cap", {"Unlimited", "30", "60"}, "Unlimited", function() end)

-- Buka Tab Info secara default
SelectTab("Info")

-- ==========================================
-- 11. FINAL DRAG & WINDOW CONTROLS (ANTI ERROR)
-- ==========================================
local isDragging = false
local dragStart, startPos
local dragInput = nil

TrackConnection(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- PENGECEKAN AMAN: Jika yang diklik adalah tombol Close atau Min, jangan drag
        if input.Target and (input.Target:IsDescendantOf(CloseBtn) or input.Target:IsDescendantOf(MinBtn)) then 
            return 
        end
        
        isDragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        dragInput = input
    end
end))

TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if isDragging and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

TrackConnection(UserInputService.InputEnded:Connect(function(input)
    if input == dragInput then
        isDragging = false
        dragInput = nil
    end
end))

-- Tombol Close (X)
TrackConnection(CloseBtn.MouseButton1Click:Connect(function() 
    MainFrame.Visible = false 
end))

-- Tombol Minimize (-)
local isMinimized = false
TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinBtn.Text = isMinimized and "+" or "-"
    Sidebar.Visible = not isMinimized
    ContentArea.Visible = not isMinimized
    
    local rHandle = MainFrame:FindFirstChild("ResizeHandle")
    if rHandle then rHandle.Visible = not isMinimized end
    
    local targetSize = isMinimized and UDim2.new(0, 320, 0, 60) or UDim2.new(0, 680, 0, 460)
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = targetSize}):Play()
end))

print("[PJANE HUB] Berhasil dimuat!")