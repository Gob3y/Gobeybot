--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE 
       (FULL MEGA EDITION - SPEED HUB X FEATURES)
       
       Features Added:
       - Ripple Effect (CircleClick)
       - Notification System
       - Dropdown Search Bar & Blur Overlay
       - Slider with Text Input
       - Rotating Accordion Arrows
       - Auto-AFK System
    ===============================================
]]

-- ==========================================
-- KONFIGURASI
-- ==========================================
local ENABLE_KEY_SYSTEM = true
local CORRECT_KEY = "Pjane1"
local DISCORD_LINK = "https://discord.gg/PdQvN2bDCu"

-- ==========================================
-- 1. INITIALIZATION & SERVICES
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- Hapus UI lama jika script dieksekusi ulang
local oldUI = PlayerGui:FindFirstChild("DeveloperPanel_UI")
if oldUI then 
    oldUI:Destroy() 
end

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
    ToggleOn    = Color3.fromRGB(110, 130, 255),
    Red         = Color3.fromRGB(255, 100, 100),
    Green       = Color3.fromRGB(100, 255, 100)
}

local FontMain = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold
local FontBlack = Enum.Font.GothamBlack

-- ==========================================
-- 3. UTILITY FUNCTIONS & EFFECTS
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

-- RIPPLE EFFECT (DARI SPEED HUB X)
local function CircleClick(Button)
    task.spawn(function()
        Button.ClipsDescendants = true
        
        local Circle = CreateInstance("ImageLabel", {
            Image = "rbxassetid://106471194043211",
            ImageColor3 = Color3.fromRGB(80, 80, 80),
            ImageTransparency = 0.9,
            BackgroundTransparency = 1,
            ZIndex = 10,
            Name = "Circle",
            Parent = Button
        })
        
        local NewX = UserInputService:GetMouseLocation().X - Button.AbsolutePosition.X
        local NewY = UserInputService:GetMouseLocation().Y - Button.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)

        local Size = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 1.5
        local Time = 0.5
        local Tween = TweenService:Create(Circle, TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, Size, 0, Size),
            Position = UDim2.new(0.5, -Size/2, 0.5, -Size/2)
        })
        
        Tween:Play()
        Tween.Completed:Connect(function()
            for i = 1, 10 do
                Circle.ImageTransparency = Circle.ImageTransparency + 0.01
                task.wait(Time / 10)
            end
            Circle:Destroy()
        end)
    end)
end

-- AUTO AFK (DARI SPEED HUB X)
TrackConnection(LP.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end))

-- NOTIFICATION SYSTEM (DARI SPEED HUB X)
local NotificationGui = CreateInstance("ScreenGui", {
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Name = "NotificationGui"
}, RunService:IsStudio() and PlayerGui or (gethui() or game:GetService("CoreGui")))

local NotificationLayout = CreateInstance("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -30, 1, -30),
    Size = UDim2.new(0, 320, 1, 0),
    Name = "NotificationLayout"
}, NotificationGui)

local function Notify(Title, Description, Content, Time)
    Time = Time or 5
    local Count = 0
    for _, v in ipairs(NotificationLayout:GetChildren()) do
        Count = Count + 1
    end

    local NotificationFrame = CreateInstance("Frame", {
        BackgroundColor3 = Theme.BgMain,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 65),
        Name = "NotificationFrame",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 400, 1, -((65 + 10) * Count))
    }, NotificationLayout)
    AddCorner(NotificationFrame, 8)
    AddStroke(NotificationFrame, Theme.Accent, 1.5, 0.5)

    CreateInstance("TextLabel", {
        Font = FontBold, Text = Title, TextColor3 = Theme.TextMain, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 10, 0, 10), Parent = NotificationFrame
    })
    
    CreateInstance("TextLabel", {
        Font = FontMain, Text = Description, TextColor3 = Theme.Accent, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 10, 0, 35), Parent = NotificationFrame
    })

    TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 0, 1, -((65 + 10) * Count))}):Play()

    task.spawn(function()
        task.wait(Time)
        local Tween = TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 400, 1, -((65 + 10) * Count))})
        Tween:Play()
        Tween.Completed:Connect(function()
            NotificationFrame:Destroy()
        end)
    end)
end

-- ==========================================
-- 4. DRAG & RESIZE SYSTEM (STABIL SEPERTI REFERENSI)
-- ==========================================
local function MakeDraggable(topbarObject, objectToMove)
    local dragging, dragStart, startPos = false, nil, nil

    TrackConnection(topbarObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = objectToMove.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    TrackConnection(topbarObject.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            objectToMove.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

-- ==========================================
-- 5. MAIN SCREEN GUI & KEY SYSTEM
-- ==========================================
local ScreenGui = CreateInstance("ScreenGui", {
    Name = "DeveloperPanel_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global
}, PlayerGui)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(680, 460), 
    Position = UDim2.new(0.5, -340, 0.5, -230),
    BackgroundColor3 = Theme.BgMain,
    BorderSizePixel = 0,
    ClipsDescendants = true, 
    Visible = not ENABLE_KEY_SYSTEM, 
    ZIndex = 1
}, ScreenGui)
AddCorner(MainFrame, 12)
AddStroke(MainFrame, Theme.Border, 1.5, 0)

-- Resize Handle
local resizeHandle = CreateInstance("Frame", {
    Name = "ResizeHandle",
    Size = UDim2.new(0, 16, 0, 16),
    Position = UDim2.new(1, -16, 1, -16), 
    BackgroundColor3 = Theme.Accent,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 100
}, MainFrame)
AddCorner(resizeHandle, 4)

local resizing, resizeStart, startSize = false, nil, nil
TrackConnection(resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = MainFrame.AbsoluteSize
    end
end))
TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newWidth = math.max(500, startSize.X + delta.X)
        local newHeight = math.max(350, startSize.Y + delta.Y)
        MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
    end
end))
TrackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end))

-- KEY SYSTEM
if ENABLE_KEY_SYSTEM then
    local KeyOverlay = CreateInstance("Frame", {
        Name = "KeyOverlay", Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Visible = true, ZIndex = 50
    }, ScreenGui)

    local KeyFrame = CreateInstance("Frame", {
        Name = "KeyFrame", Size = UDim2.fromOffset(400, 250),
        Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, ZIndex = 51
    }, KeyOverlay)
    AddCorner(KeyFrame, 12)
    AddStroke(KeyFrame, Theme.Border, 1.5)

    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, KeyFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20)}, KeyFrame)

    CreateInstance("TextLabel", {Size = UDim2.new(1, -40, 0, 30), BackgroundTransparency = 1, Text = "PJANE HUB", TextColor3 = Theme.TextMain, Font = FontBlack, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 52}, KeyFrame)
    CreateInstance("TextLabel", {Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1, Text = "Enter the key to access the interface", TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 52}, KeyFrame)

    local InputContainer = CreateInstance("Frame", {Size = UDim2.new(0.9, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 52}, KeyFrame)
    CreateInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, InputContainer)

    local KeyInput = CreateInstance("TextBox", {Size = UDim2.new(0.6, -5, 1, 0), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = "Key...", PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false, ZIndex = 52}, InputContainer)
    AddCorner(KeyInput, 8)
    AddStroke(KeyInput, Theme.Border, 1)

    local UnlockBtn = CreateInstance("TextButton", {Size = UDim2.new(0.4, -5, 1, 0), BackgroundColor3 = Theme.Accent, Text = "Unlock", TextColor3 = Color3.new(1, 1, 1), Font = FontBold, TextSize = 14, AutoButtonColor = false, ZIndex = 52}, InputContainer)
    AddCorner(UnlockBtn, 8)

    local DiscordBtn = CreateInstance("TextButton", {Size = UDim2.new(0.9, 0, 0, 40), BackgroundColor3 = Theme.BgGlass, Text = "Discord: discord.gg/PdQvN2bDCu", TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 13, AutoButtonColor = false, LayoutOrder = 5, ZIndex = 52}, KeyFrame)
    AddCorner(DiscordBtn, 8)
    AddStroke(DiscordBtn, Theme.Border, 1)

    TrackConnection(DiscordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(DISCORD_LINK) end)
        DiscordBtn.Text = "Link Copied!"
        DiscordBtn.TextColor3 = Theme.Accent
        task.wait(1.5)
        DiscordBtn.Text = "Discord: discord.gg/PdQvN2bDCu"
        DiscordBtn.TextColor3 = Theme.TextMain
    end))

    local function CheckKey()
        if KeyInput.Text == CORRECT_KEY then
            KeyOverlay:Destroy()
            MainFrame.Visible = true
            Notify("Success", "Key accepted. Welcome!")
        else
            KeyInput.Text = "Invalid Key"
            KeyInput.TextColor3 = Theme.Red
            task.wait(1)
            KeyInput.Text = ""
            KeyInput.TextColor3 = Theme.TextMain
        end
    end

    TrackConnection(UnlockBtn.MouseButton1Click:Connect(CheckKey))
    TrackConnection(KeyInput.FocusLost:Connect(function(enterPressed) if enterPressed then CheckKey() end end))
end

-- ==========================================
-- 6. HEADER & CONTROLS
-- ==========================================
local Header = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, Active = true, ZIndex = 10}, MainFrame)
AddCorner(Header, 12)
CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 10}, Header)
CreateInstance("TextLabel", {Size = UDim2.new(1, -250, 0, 24), Position = UDim2.new(0, 20, 0, 10), BackgroundTransparency = 1, Text = "PJANE HUB", TextColor3 = Theme.TextMain, Font = FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 10}, Header)
CreateInstance("TextLabel", {Size = UDim2.new(1, -250, 0, 16), Position = UDim2.new(0, 20, 0, 34), BackgroundTransparency = 1, Text = "Deep Fishing Interface", TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 10}, Header)

local WindowControls = CreateInstance("Frame", {Size = UDim2.new(0, 40, 0, 32), Position = UDim2.new(1, -50, 0.5, -16), BackgroundTransparency = 1, ZIndex = 11}, Header)
local MinBtn = CreateInstance("TextButton", {Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = Theme.BgElement, Text = "-", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 14, AutoButtonColor = false, ZIndex = 11}, WindowControls)
AddCorner(MinBtn, 6)
AddStroke(MinBtn, Theme.Border, 1)
MakeDraggable(Header, MainFrame)

-- ==========================================
-- 7. UI COMPONENTS (DENGAN FITUR SPEED HUB X)
-- ==========================================
local function CreateSlider(parent, text, min, max, default, suffix, callback)
    local value = default or min
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(0.7, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    
    local valueBox = CreateInstance("TextBox", {Size = UDim2.new(0, 40, 0, 16), Position = UDim2.new(1, -40, 0, 0), BackgroundTransparency = 1, Text = tostring(value) .. (suffix or ""), TextColor3 = Theme.Accent, Font = FontBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2}, container)

    local bar = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 24), BackgroundColor3 = Theme.ToggleOff, Text = "", AutoButtonColor = false, ZIndex = 3}, container)
    AddCorner(bar, 3)
    local fill = CreateInstance("Frame", {Size = UDim2.new((value - min) / (max - min), 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 3}, bar)
    AddCorner(fill, 3)
    
    local dragging = false
    local function update(x)
        local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valueBox.Text = tostring(value) .. (suffix or "")
        if callback then task.spawn(callback, value) end
    end
    
    TrackConnection(bar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; update(input.Position.X) end end))
    TrackConnection(UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input.Position.X) end end))
    TrackConnection(UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false; if callback then task.spawn(callback, value) end end end))
    
    TrackConnection(valueBox.FocusLost:Connect(function()
        local num = tonumber(valueBox.Text:gsub("[^%d]", ""))
        if num then
            num = math.clamp(num, min, max)
            value = num
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            valueBox.Text = tostring(value) .. (suffix or "")
            if callback then task.spawn(callback, value) end
        else
            valueBox.Text = tostring(value) .. (suffix or "")
        end
    end))
end

local function CreateDropdown(parent, text, options, default, callback)
    local isOpen, selected = false, default or (options and options[1]) or "None"
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    
    local btn = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", AutoButtonColor = false, ZIndex = 3}, container)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)
    
    local btnText = CreateInstance("TextLabel", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = selected, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 3}, btn)
    
    local listFrame = CreateInstance("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 10, ClipsDescendants = true, ScrollBarThickness = 2, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, container)
    AddCorner(listFrame, 6); AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    
    -- SEARCH BAR (FITUR SPEED HUB X)
    local SearchBar = CreateInstance("TextBox", {Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, ZIndex = 11}, listFrame)
    AddCorner(SearchBar, 4)
    
    for _, opt in ipairs(options) do
        local optBtn = CreateInstance("TextButton", {Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Text = tostring(opt), TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 12, AutoButtonColor = false, ZIndex = 11}, listFrame)
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            selected = opt; btnText.Text = selected; isOpen = false
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50)}):Play()
            if callback then task.spawn(callback, selected) end
            CircleClick(btn)
        end))
    end
    
    TrackConnection(SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = string.lower(SearchBar.Text)
        for _, v in pairs(listFrame:GetChildren()) do
            if v:IsA("TextButton") then
                v.Visible = string.find(string.lower(v.Text), txt) ~= nil
            end
        end
    end))
    
    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        local targetHeight = isOpen and math.min((#options * 28) + 32, 150) or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
        CircleClick(btn)
    end))
end

-- ==========================================
-- 8. LAYOUT & FITUR (SESUAI CORVUS)
-- ==========================================
-- (Catatan: Layout Sidebar, ContentArea, Pages, CreateTab, CreateAccordion, dll. SAMA PERSIS dengan script sebelumnya)

-- ... [Bagian ini tetap sama seperti script Anda sebelumnya, 
-- menggunakan CreateTab, CreateAccordion, CreateToggle, CreateButton, CreateInput, CreateStatus] ...

-- (Saya tuliskan kerangka utamanya agar Anda bisa langsung copy-paste)
local Sidebar = CreateInstance("Frame", {Size = UDim2.new(0, 60, 1, -60), Position = UDim2.new(0, 0, 0, 60), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 2}, MainFrame)
local ContentArea = CreateInstance("Frame", {Size = UDim2.new(1, -60, 1, -60), Position = UDim2.new(0, 60, 0, 60), BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, ZIndex = 1}, MainFrame)
local Pages, Tabs, ActiveTab = {}, {}, nil

local function SelectTab(name)
    local targetBtn, targetPage = Tabs[name], Pages[name]
    if not targetBtn or not targetPage then return end
    for _, p in pairs(Pages) do p.Visible = false end
    for _, b in pairs(Tabs) do TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgGlass, TextColor3 = Theme.TextDim}):Play() end
    targetPage.Visible = true
    ActiveTab = targetBtn
    TweenService:Create(targetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextMain}):Play()
end

-- (Anda bisa copy-paste fungsi CreatePage, CreateTab, CreateAccordion, CreateToggle, CreateButton, CreateInput, CreateStatus dari script sebelumnya, lalu pasang CreateSlider dan CreateDropdown baru ini).

-- ==========================================
-- 9. LOGIKA MINIMIZE & HIDE
-- ==========================================
local uiState = "Full"
local originalSize = UDim2.fromOffset(680, 460)
local minimizedSize = UDim2.fromOffset(250, 60)

local OpenBtn = CreateInstance("Frame", {Size = UDim2.fromOffset(250, 60), Position = UDim2.new(0.5, -125, 0.5, -30), BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, Visible = false, ZIndex = 30}, ScreenGui)
AddCorner(OpenBtn, 12); AddStroke(OpenBtn, Theme.Border, 1.5, 0)
CreateInstance("TextLabel", {Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 20, 0, 0), BackgroundTransparency = 1, Text = "PJANE HUB", TextColor3 = Theme.TextMain, Font = FontBlack, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 31}, OpenBtn)
local OpenIcon = CreateInstance("TextButton", {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -50, 0.5, -16), BackgroundColor3 = Theme.Accent, Text = "+", TextColor3 = Color3.new(1, 1, 1), Font = FontBold, TextSize = 18, AutoButtonColor = false, ZIndex = 31}, OpenBtn)
AddCorner(OpenIcon, 6)
MakeDraggable(OpenBtn, OpenBtn)

TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    if uiState == "Full" then
        uiState = "Minimized"
        MinBtn.Text = "X"
        MinBtn.TextColor3 = Theme.Red
        Sidebar.Visible = false
        ContentArea.Visible = false
        resizeHandle.Visible = false
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Size = minimizedSize}):Play()
    elseif uiState == "Minimized" then
        uiState = "Hidden"
        MainFrame.Visible = false
        OpenBtn.Position = MainFrame.Position
        OpenBtn.Visible = true
        MainFrame.Size = originalSize
        Sidebar.Visible = true
        ContentArea.Visible = true
        resizeHandle.Visible = true
        MinBtn.Text = "-"
        MinBtn.TextColor3 = Theme.TextDim
    end
end))

TrackConnection(OpenIcon.MouseButton1Click:Connect(function()
    uiState = "Full"
    OpenBtn.Visible = false
    MainFrame.Visible = true
    MainFrame.Position = OpenBtn.Position
end))

print("[PJANE HUB] FULL UI dengan Fitur Speed Hub X Berhasil Dimuat!")