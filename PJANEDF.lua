--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE 
       (ULTIMATE FIXED EDITION - TOP POSITION)
       
       Fixes:
       - Notification only on Key Success
       - Moved to Top-Center (Safe margin 15%)
       - Fixed Drag Issue on Minimized State
       - Responsive UIScale (Mobile & PC)
       - Full Features (100% No Cuts)
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
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local SharedEnvironment = _G
if type(getgenv) == "function" then
    local envOk, env = pcall(getgenv)
    if envOk and type(env) == "table" then SharedEnvironment = env end
end
if type(SharedEnvironment.__PJANE_CLEANUP) == "function" then
    pcall(SharedEnvironment.__PJANE_CLEANUP)
    SharedEnvironment.__PJANE_CLEANUP = nil
end

local oldUI = PlayerGui:FindFirstChild("DeveloperPanel_UI")
if oldUI then oldUI:Destroy() end

local Connections = {}
local function TrackConnection(conn)
    table.insert(Connections, conn)
    return conn
end

-- Runtime adapter for the game's existing AutoFishing controller.
local Notify
local RuntimeState = {
    AutoFish = false, FishMode = "Fast (default)",
    FishRarities = {"Secret", "Exotic"}, CollectItems = {},
    AntiAFK = false, AntiAFKConnection = nil, Features = {},
    Settings = {}, AutoJump = false, AutoJumpInterval = 30,
    AutoReconnect = false, Disable3D = false, FPSCap = "Unlimited",
    PerformanceLevel = "Balanced", AntiLag = false, Loops = {}
}

local function FeatureNotVerified(name, value)
    if type(value) ~= "boolean" then
        RuntimeState.Settings[name] = value
        Notify(name, "Pilihan disimpan di sesi. Aksi game belum dijalankan karena API controller/argumen belum terverifikasi.", 4)
        return
    end
    RuntimeState.Features[name] = value
    if value then
        Notify(name, "Belum dijalankan: dump belum membuktikan API controller/argumen yang aman untuk fitur ini. Tidak ada remote tebakan yang dipanggil.", 5)
    else
        Notify(name, "Nonaktif.", 3)
    end
end

local function GetHumanoid()
    local character = LP.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function RejoinCurrentServer()
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
    if not ok then Notify("Rejoin", "Gagal memulai teleport: " .. tostring(err), 5) end
end

local function CopyText(value)
    local fn = type(setclipboard) == "function" and setclipboard or (type(toclipboard) == "function" and toclipboard)
    if not fn then Notify("Clipboard", "Executor tidak menyediakan fungsi clipboard.", 4); return end
    local ok, err = pcall(fn, tostring(value or ""))
    if not ok then Notify("Clipboard", "Gagal menyalin: " .. tostring(err), 4) else Notify("Clipboard", "Berhasil disalin.", 3) end
end

local function ApplyFPSCap(value)
    local cap = value == "30" and 30 or (value == "60" and 60 or 999)
    RuntimeState.FPSCap = value
    if type(setfpscap) ~= "function" then
        Notify("FPS cap", "Executor tidak menyediakan setfpscap; pilihan disimpan saja.", 4)
        return
    end
    local ok, err = pcall(setfpscap, cap)
    if not ok then Notify("FPS cap", "Gagal: " .. tostring(err), 4)
    else Notify("FPS cap", value == "Unlimited" and "Cap tinggi diminta (tergantung executor)." or ("Cap " .. value .. " FPS diterapkan."), 3) end
end

local function ApplyPerformance(enabled, level)
    RuntimeState.AntiLag = enabled == true
    RuntimeState.PerformanceLevel = level or RuntimeState.PerformanceLevel
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if RuntimeState.Settings.GlobalShadows == nil then
        RuntimeState.Settings.GlobalShadows = Lighting.GlobalShadows
        RuntimeState.Settings.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
        RuntimeState.Settings.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        if terrain then RuntimeState.Settings.TerrainDecoration = terrain.Decoration end
    end
    pcall(function()
        if enabled then
            Lighting.GlobalShadows = false
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            if terrain then terrain.Decoration = false end
        else
            Lighting.GlobalShadows = RuntimeState.Settings.GlobalShadows
            Lighting.EnvironmentDiffuseScale = RuntimeState.Settings.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = RuntimeState.Settings.EnvironmentSpecularScale
            if terrain and RuntimeState.Settings.TerrainDecoration ~= nil then terrain.Decoration = RuntimeState.Settings.TerrainDecoration end
        end
    end)
    Notify("Anti lag", enabled and ("Optimasi visual lokal diterapkan (" .. tostring(level or RuntimeState.PerformanceLevel) .. ").") or "Pengaturan visual awal dipulihkan.", 3)
end

local function SetAutoJump(enabled)
    RuntimeState.AutoJump = enabled == true
    RuntimeState.Loops.AutoJump = nil
    if not RuntimeState.AutoJump then Notify("Auto jump", "Nonaktif.", 3); return end
    local token = {}
    RuntimeState.Loops.AutoJump = token
    task.spawn(function()
        while RuntimeState.Loops.AutoJump == token and RuntimeState.AutoJump do
            task.wait(math.max(5, tonumber(RuntimeState.AutoJumpInterval) or 30))
            if RuntimeState.Loops.AutoJump ~= token or not RuntimeState.AutoJump then break end
            local humanoid = GetHumanoid()
            if humanoid and humanoid.Health > 0 then pcall(function() humanoid.Jump = true end) end
        end
    end)
    Notify("Auto jump", "Aktif; interval " .. tostring(RuntimeState.AutoJumpInterval) .. " detik.", 3)
end

TrackConnection(TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId)
    if player == LP and RuntimeState.AutoReconnect then
        Notify("Auto reconnect", "Teleport gagal (" .. tostring(result) .. "); mencoba kembali ke server ini.", 4)
        task.delay(3, function()
            if RuntimeState.AutoReconnect then RejoinCurrentServer() end
        end)
    end
end))

local function FindAutoFishingController()
    if type(getgc) ~= "function" then return nil, "getgc unavailable" end
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then return nil, "runtime object scan failed" end
    for _, object in ipairs(objects) do
        if type(object) == "table" then
            local controllers = object.Controllers
            if type(object.SetOn) == "function"
                and type(controllers) == "table"
                and type(controllers.Fishing) == "table"
                and type(controllers.ThrowCinematic) == "table"
                and object.PlayerData ~= nil then
                return object
            end
        end
    end
    return nil, "AutoFishing controller not found"
end

local function SetGameAutoFishing(enabled)
    local controller, reason = FindAutoFishingController()
    if not controller then
        RuntimeState.LastStatus = reason or "controller not found"
        Notify("Auto Fish", RuntimeState.LastStatus, 5)
        return false
    end
    local ok, err = pcall(function() controller:SetOn(enabled == true) end)
    if not ok then
        RuntimeState.LastStatus = "SetOn failed: " .. tostring(err)
        Notify("Auto Fish", RuntimeState.LastStatus, 5)
        return false
    end
    RuntimeState.AutoFish = enabled == true
    RuntimeState.LastStatus = RuntimeState.AutoFish and "Game AutoFishing enabled" or "Game AutoFishing disabled"
    Notify("Auto Fish", RuntimeState.LastStatus, 3)
    return true
end

-- Source-backed helper: the dumped AutoFishing controller exposes
-- OpenFilterPanel("AutoSell") and may prompt for the game's Auto Sell pass.
local function OpenGameAutoSellSettings()
    local controller, reason = FindAutoFishingController()
    if not controller then
        Notify("Auto Sell", reason or "AutoFishing controller not found", 5)
        return false
    end
    if type(controller.OpenFilterPanel) ~= "function" then
        Notify("Auto Sell", "Controller ditemukan, tetapi OpenFilterPanel tidak tersedia.", 5)
        return false
    end
    local ok, err = pcall(function()
        controller:OpenFilterPanel("AutoSell")
    end)
    if not ok then
        Notify("Auto Sell", "Gagal membuka pengaturan: " .. tostring(err), 5)
        return false
    end
    Notify("Auto Sell", "Panel Auto Sell bawaan game dibuka. Ini bukan penjualan instan dari hub.", 5)
    return true
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
    Red         = Color3.fromRGB(255, 100, 100)
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

local function CircleClick(Button)
    task.spawn(function()
        Button.ClipsDescendants = true
        local Circle = CreateInstance("ImageLabel", {
            Image = "rbxassetid://106471194043211", ImageColor3 = Color3.fromRGB(80, 80, 80), ImageTransparency = 0.9,
            BackgroundTransparency = 1, ZIndex = 10, Name = "Circle", Parent = Button
        })
        local NewX = UserInputService:GetMouseLocation().X - Button.AbsolutePosition.X
        local NewY = UserInputService:GetMouseLocation().Y - Button.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)
        local Size = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 1.5
        local Time = 0.5
        local Tween = TweenService:Create(Circle, TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, Size, 0, Size), Position = UDim2.new(0.5, -Size/2, 0.5, -Size/2)
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

local function SetAntiAFK(enabled)
    RuntimeState.AntiAFK = enabled == true
    if RuntimeState.AntiAFKConnection then
        RuntimeState.AntiAFKConnection:Disconnect()
        RuntimeState.AntiAFKConnection = nil
    end
    if RuntimeState.AntiAFK then
        RuntimeState.AntiAFKConnection = LP.Idled:Connect(function()
            pcall(function()
                local camera = workspace.CurrentCamera
                if not camera then return end
                VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
            end)
        end)
    end
end

-- NOTIFICATION SYSTEM
local function GetUIRoot()
    if RunService:IsStudio() then return PlayerGui end
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and root then return root end
    end
    return game:GetService("CoreGui")
end
local NotificationGui = CreateInstance("ScreenGui", {ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Name = "NotificationGui"}, GetUIRoot())
local NotificationLayout = CreateInstance("Frame", {AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Position = UDim2.new(1, -30, 1, -30), Size = UDim2.new(0, 320, 1, 0), Name = "NotificationLayout"}, NotificationGui)

Notify = function(Title, Description, Time)
    Time = Time or 5
    local Count = 0
    for _, v in ipairs(NotificationLayout:GetChildren()) do Count = Count + 1 end
    local NotificationFrame = CreateInstance("Frame", {BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 65), Name = "NotificationFrame", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 400, 1, -((65 + 10) * Count))}, NotificationLayout)
    AddCorner(NotificationFrame, 8); AddStroke(NotificationFrame, Theme.Border, 1.5, 0)
    CreateInstance("TextLabel", {Font = FontBold, Text = Title, TextColor3 = Theme.TextMain, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 10, 0, 10), Parent = NotificationFrame})
    CreateInstance("TextLabel", {Font = FontMain, Text = Description, TextColor3 = Theme.TextDim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 10, 0, 35), Parent = NotificationFrame})
    TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 0, 1, -((65 + 10) * Count))}):Play()
    task.spawn(function()
        task.wait(Time)
        local Tween = TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 400, 1, -((65 + 10) * Count))})
        Tween:Play()
        Tween.Completed:Connect(function() NotificationFrame:Destroy() end)
    end)
end

-- ==========================================
-- 4. MAIN SCREEN GUI & KEY SYSTEM
-- ==========================================
local ScreenGui = CreateInstance("ScreenGui", {Name = "DeveloperPanel_UI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Global}, PlayerGui)

-- MENGUBAH POSISI KE TENGAH ATAS (Y = 0.15 agar tidak mepet ke atas)
local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame", Size = UDim2.fromOffset(680, 460), 
    Position = UDim2.new(0.5, 0, 0.5, 0), 
    AnchorPoint = Vector2.new(0.5, 0.5), 
    BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, ClipsDescendants = true, 
    Visible = not ENABLE_KEY_SYSTEM, ZIndex = 1
}, ScreenGui)
AddCorner(MainFrame, 12); AddStroke(MainFrame, Theme.Border, 1.5, 0)

local UIScale = CreateInstance("UIScale", {Scale = 1}, MainFrame)
local function UpdateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scaleX = (vp.X - 40) / 680
    local scaleY = (vp.Y - 40) / 460
    UIScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.4, 1)
end
UpdateScale()
TrackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(UpdateScale))
if workspace.CurrentCamera then TrackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)) end

local function MakeDraggable(topbarObject, objectToMove, ignoreObjects, uiScale)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    ignoreObjects = ignoreObjects or {}

    local function isIgnored(input)
        local ok, objects = pcall(function()
            return PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
        end)
        if not ok or not objects then return false end
        for _, hit in ipairs(objects) do
            for _, ignored in ipairs(ignoreObjects) do
                if ignored and (hit == ignored or hit:IsDescendantOf(ignored)) then
                    return true
                end
            end
        end
        return false
    end

    local function clampPosition(x, y)
        local cam = workspace.CurrentCamera
        if not cam then return x, y end
        local viewport = cam.ViewportSize
        -- MainFrame's UIScale is a child, so it scales the contents, not MainFrame itself.
        -- Use the frame's actual AbsoluteSize and do not divide drag delta by UIScale.
        local absSize = objectToMove.AbsoluteSize
        local anchor = objectToMove.AnchorPoint
        local minX = 8 + anchor.X * absSize.X
        local maxX = viewport.X - 8 - (1 - anchor.X) * absSize.X
        local minY = 8 + anchor.Y * absSize.Y
        local maxY = viewport.Y - 8 - (1 - anchor.Y) * absSize.Y
        if maxX < minX then x = viewport.X / 2 else x = math.clamp(x, minX, maxX) end
        if maxY < minY then y = 8 + anchor.Y * absSize.Y else y = math.clamp(y, minY, maxY) end
        return x, y
    end

    TrackConnection(topbarObject.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if isIgnored(input) then return end
        dragging = true
        dragInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        local currentPos = objectToMove.Position
        local cam = workspace.CurrentCamera
        local viewport = cam and cam.ViewportSize or Vector2.new(800, 600)
        startPos = Vector2.new(
            currentPos.X.Scale * viewport.X + currentPos.X.Offset,
            currentPos.Y.Scale * viewport.Y + currentPos.Y.Offset
        )
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragInput = nil
            end
        end)
    end))

    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement
        local isActiveTouch = dragInput ~= nil and input == dragInput
        if not dragging or (not isMouseMove and not isActiveTouch) then return end
        local pointer = Vector2.new(input.Position.X, input.Position.Y)
        local delta = pointer - dragStart
        local x, y = clampPosition(startPos.X + delta.X, startPos.Y + delta.Y)
        objectToMove.Position = UDim2.fromOffset(x, y)
    end))

    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragInput then
            dragging = false
            dragInput = nil
        end
    end))
end

local resizeHandle = CreateInstance("Frame", {Name = "ResizeHandle", Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -16, 1, -16), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 100}, MainFrame)
AddCorner(resizeHandle, 4)
local resizing, resizeStart, startSize = false, nil, nil
TrackConnection(resizeHandle.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then resizing = true; resizeStart = input.Position; startSize = Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset) end end))
TrackConnection(UserInputService.InputChanged:Connect(function(input) if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = (input.Position - resizeStart) * 2 / UIScale.Scale; MainFrame.Size = UDim2.fromOffset(math.max(500, startSize.X + delta.X), math.max(350, startSize.Y + delta.Y)) end end))
TrackConnection(UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then resizing = false end end))

if ENABLE_KEY_SYSTEM then
    local KeyOverlay = CreateInstance("Frame", {Name = "KeyOverlay", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Visible = true, ZIndex = 50}, ScreenGui)
    local KeyFrame = CreateInstance("Frame", {Name = "KeyFrame", Size = UDim2.fromOffset(400, 250), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.BgMain, BorderSizePixel = 0, ZIndex = 51}, KeyOverlay)
    AddCorner(KeyFrame, 12); AddStroke(KeyFrame, Theme.Border, 1.5)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, KeyFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20)}, KeyFrame)
    CreateInstance("TextLabel", {Size = UDim2.new(1, -40, 0, 30), BackgroundTransparency = 1, Text = "PJANE HUB", TextColor3 = Theme.TextMain, Font = FontBlack, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 52}, KeyFrame)
    CreateInstance("TextLabel", {Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1, Text = "Enter the key to access the interface", TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 52}, KeyFrame)
    local InputContainer = CreateInstance("Frame", {Size = UDim2.new(0.9, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 52}, KeyFrame)
    CreateInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, InputContainer)
    local KeyInput = CreateInstance("TextBox", {Size = UDim2.new(0.6, -5, 1, 0), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = "Key...", PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false, ZIndex = 52}, InputContainer)
    AddCorner(KeyInput, 8); AddStroke(KeyInput, Theme.Border, 1)
    local UnlockBtn = CreateInstance("TextButton", {Size = UDim2.new(0.4, -5, 1, 0), BackgroundColor3 = Theme.Accent, Text = "Unlock", TextColor3 = Color3.new(1, 1, 1), Font = FontBold, TextSize = 14, AutoButtonColor = false, ZIndex = 52}, InputContainer)
    AddCorner(UnlockBtn, 8)
    local DiscordBtn = CreateInstance("TextButton", {Size = UDim2.new(0.9, 0, 0, 40), BackgroundColor3 = Theme.BgGlass, Text = "Discord: discord.gg/PdQvN2bDCu", TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 13, AutoButtonColor = false, LayoutOrder = 5, ZIndex = 52}, KeyFrame)
    AddCorner(DiscordBtn, 8); AddStroke(DiscordBtn, Theme.Border, 1)
    
    TrackConnection(DiscordBtn.MouseButton1Click:Connect(function() pcall(function() setclipboard(DISCORD_LINK) end); DiscordBtn.Text = "Link Copied!"; DiscordBtn.TextColor3 = Theme.Accent; task.wait(1.5); DiscordBtn.Text = "Discord: discord.gg/PdQvN2bDCu"; DiscordBtn.TextColor3 = Theme.TextMain end))
    
    local function CheckKey()
        if KeyInput.Text == CORRECT_KEY then 
            KeyOverlay:Destroy()
            MainFrame.Visible = true
            -- NOTIFIKASI HANYA MUNCUL DISINI
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
-- 5. HEADER & SINGLE CONTROL BUTTON
-- ==========================================
local Header = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, Active = true, ZIndex = 10}, MainFrame)
AddCorner(Header, 12)
CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 10}, Header)

local HeaderTitle = CreateInstance("TextLabel", {Size = UDim2.new(1, -100, 0, 24), Position = UDim2.new(0, 20, 0, 10), BackgroundTransparency = 1, Text = "PJANE HUB", TextColor3 = Theme.TextMain, Font = FontBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 10}, Header)
local HeaderSub = CreateInstance("TextLabel", {Size = UDim2.new(1, -100, 0, 16), Position = UDim2.new(0, 20, 0, 34), BackgroundTransparency = 1, Text = "Deep Fishing Interface", TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 10}, Header)

local WindowControls = CreateInstance("Frame", {Size = UDim2.new(0, 40, 0, 32), Position = UDim2.new(1, -50, 0.5, -16), BackgroundTransparency = 1, ZIndex = 11}, Header)
local MinBtn = CreateInstance("TextButton", {Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = Theme.BgElement, Text = "-", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 14, AutoButtonColor = false, ZIndex = 11}, WindowControls)
AddCorner(MinBtn, 6); AddStroke(MinBtn, Theme.Border, 1)
TrackConnection(MinBtn.MouseEnter:Connect(function() TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover, TextColor3 = Theme.TextMain}):Play() end))
TrackConnection(MinBtn.MouseLeave:Connect(function() TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextDim}):Play() end))

MakeDraggable(Header, MainFrame, {WindowControls, resizeHandle}, UIScale)

-- ==========================================
-- 6. SIDEBAR & CONTENT AREA
-- ==========================================
local Sidebar = CreateInstance("Frame", {Size = UDim2.new(0, 60, 1, -60), Position = UDim2.new(0, 0, 0, 60), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 2}, MainFrame)
CreateInstance("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, ZIndex = 2}, Sidebar)
local TabContainer = CreateInstance("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 2}, Sidebar)
CreateInstance("UIListLayout", {Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, TabContainer)
CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 15)}, TabContainer)

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

local function CreatePage(name)
    local page = CreateInstance("Frame", {Name = name .. "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 1}, ContentArea)
    local leftCol = CreateInstance("ScrollingFrame", {Size = UDim2.new(0.5, -18, 1, -20), Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 2}, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16)}, leftCol)
    local rightCol = CreateInstance("ScrollingFrame", {Size = UDim2.new(0.5, -18, 1, -20), Position = UDim2.new(0.5, 8, 0, 10), BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Border, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 2}, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, rightCol)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16)}, rightCol)
    Pages[name] = page
    return {Left = leftCol, Right = rightCol}
end

local function CreateTab(name, text)
    local btn = CreateInstance("TextButton", {Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Theme.BgGlass, Text = text, TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 14, AutoButtonColor = false, ZIndex = 2}, TabContainer)
    AddCorner(btn, 8)
    TrackConnection(btn.MouseEnter:Connect(function() if ActiveTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play() end end))
    TrackConnection(btn.MouseLeave:Connect(function() if ActiveTab ~= btn then TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgGlass}):Play() end end))
    TrackConnection(btn.MouseButton1Click:Connect(function() SelectTab(name); CircleClick(btn) end))
    Tabs[name] = btn
    return CreatePage(name)
end

-- ==========================================
-- 7. UI COMPONENTS
-- ==========================================
local function CreateAccordion(parent, titleText, defaultOpen)
    local isOpen = defaultOpen ~= false
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, container)
    local headerBtn = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.BgGlass, Text = "", AutoButtonColor = false, ZIndex = 3}, container)
    AddCorner(headerBtn, 8); AddStroke(headerBtn, Theme.Border, 1)
    CreateInstance("TextLabel", {Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 15, 0, 0), BackgroundTransparency = 1, Text = titleText, TextColor3 = Theme.TextMain, Font = FontBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 3}, headerBtn)
    local arrow = CreateInstance("TextLabel", {Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(1, -40, 0, 0), BackgroundTransparency = 1, Text = isOpen and "-" or "+", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 18, Active = false, ZIndex = 3}, headerBtn)
    local content = CreateInstance("Frame", {Size = UDim2.new(1, -10, 0, 0), Position = UDim2.new(0, 5, 0, 40), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = isOpen, ZIndex = 2}, container)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, content)
    TrackConnection(headerBtn.MouseButton1Click:Connect(function() isOpen = not isOpen; content.Visible = isOpen; arrow.Text = isOpen and "-" or "+"; CircleClick(headerBtn) end))
    return content
end

local function CreateToggle(parent, text, default, callback)
    local state = default or false
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    local switchBg = CreateInstance("Frame", {Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -34, 0.5, -9), BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff, BorderSizePixel = 0, ZIndex = 2}, container)
    AddCorner(switchBg, 9)
    local knob = CreateInstance("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2}, switchBg)
    AddCorner(knob, 7)
    local hitbox = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3}, container)
    TrackConnection(hitbox.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        CircleClick(hitbox)
        if callback then task.spawn(callback, state) end
    end))
end

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
        else valueBox.Text = tostring(value) .. (suffix or "") end
    end))
end

local function CreateButton(parent, text, callback)
    local btn = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.BgElement, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, AutoButtonColor = false, ZIndex = 3}, parent)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)
    TrackConnection(btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play() end))
    TrackConnection(btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement}):Play() end))
    TrackConnection(btn.MouseButton1Click:Connect(function() if callback then task.spawn(callback) end; CircleClick(btn) end))
end

local function CreateDropdown(parent, text, options, default, callback)
    local isOpen, selected = false, default or (options and options[1]) or "None"
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    local btn = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", AutoButtonColor = false, ZIndex = 3}, container)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)
    local btnText = CreateInstance("TextLabel", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = selected, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 3}, btn)
    local icon = CreateInstance("TextLabel", {Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -25, 0, 0), BackgroundTransparency = 1, Text = "+", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 14, Active = false, ZIndex = 3}, btn)
    local listFrame = CreateInstance("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 10, ClipsDescendants = true, ScrollBarThickness = 2, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, container)
    AddCorner(listFrame, 6); AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    
    local SearchBar = CreateInstance("TextBox", {Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, ZIndex = 11}, listFrame)
    AddCorner(SearchBar, 4)
    
    for _, opt in ipairs(options) do
        local optBtn = CreateInstance("TextButton", {Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Text = tostring(opt), TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 12, AutoButtonColor = false, ZIndex = 11}, listFrame)
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            selected = opt; btnText.Text = selected; isOpen = false; icon.Text = "+"
            TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50)}):Play()
            if callback then task.spawn(callback, selected) end
            CircleClick(btn)
        end))
    end
    TrackConnection(SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = string.lower(SearchBar.Text)
        for _, v in pairs(listFrame:GetChildren()) do if v:IsA("TextButton") then v.Visible = string.find(string.lower(v.Text), txt) ~= nil end end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen; icon.Text = isOpen and "-" or "+"
        local targetHeight = isOpen and math.min((#options * 28) + 32, 150) or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
        CircleClick(btn)
    end))
end

local function CreateMultiDropdown(parent, text, options, defaultList, callback)
    local isOpen, selectedOptions = false, defaultList or {}
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    local btn = CreateInstance("TextButton", {Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", AutoButtonColor = false, ZIndex = 3}, container)
    AddCorner(btn, 6); AddStroke(btn, Theme.Border, 1)
    local btnText = CreateInstance("TextLabel", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = table.concat(selectedOptions, ", "), TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 3}, btn)
    local icon = CreateInstance("TextLabel", {Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -25, 0, 0), BackgroundTransparency = 1, Text = "+", TextColor3 = Theme.TextDim, Font = FontBold, TextSize = 14, Active = false, ZIndex = 3}, btn)
    local listFrame = CreateInstance("ScrollingFrame", {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Theme.BgGlass, BorderSizePixel = 0, ZIndex = 10, ClipsDescendants = true, ScrollBarThickness = 2, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, container)
    AddCorner(listFrame, 6); AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    
    local SearchBar = CreateInstance("TextBox", {Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = "Search...", PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, ZIndex = 11}, listFrame)
    AddCorner(SearchBar, 4)
    local actionRow = CreateInstance("Frame", {Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, ZIndex = 11}, listFrame)
    local selectAllBtn = CreateInstance("TextButton", {Size = UDim2.new(0.5, -2, 1, 0), BackgroundColor3 = Theme.BgElement, Text = "Select All", TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 11, ZIndex = 12}, actionRow)
    AddCorner(selectAllBtn, 4)
    local clearAllBtn = CreateInstance("TextButton", {Size = UDim2.new(0.5, -2, 1, 0), Position = UDim2.new(0.5, 2, 0, 0), BackgroundColor3 = Theme.BgElement, Text = "Clear All", TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 11, ZIndex = 12}, actionRow)
    AddCorner(clearAllBtn, 4)
    local optionButtons = {}

    local function updateText() btnText.Text = #selectedOptions > 0 and table.concat(selectedOptions, ", ") or "Select..." end
    for _, opt in ipairs(options) do
        local isSelected = table.find(selectedOptions, opt) ~= nil
        local optBtn = CreateInstance("TextButton", {Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1, Text = (isSelected and "[x] " or "[ ] ") .. tostring(opt), TextColor3 = isSelected and Theme.TextMain or Theme.TextDim, Font = FontMain, TextSize = 12, AutoButtonColor = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11}, listFrame)
        optionButtons[opt] = optBtn
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            local idx = table.find(selectedOptions, opt)
            if idx then table.remove(selectedOptions, idx); optBtn.Text = "[ ] " .. tostring(opt); optBtn.TextColor3 = Theme.TextDim
            else table.insert(selectedOptions, opt); optBtn.Text = "[x] " .. tostring(opt); optBtn.TextColor3 = Theme.TextMain end
            updateText()
            if callback then task.spawn(callback, selectedOptions) end
        end))
    end
    local function emitSelection()
        updateText()
        if callback then task.spawn(callback, table.clone(selectedOptions)) end
    end
    TrackConnection(selectAllBtn.MouseButton1Click:Connect(function()
        table.clear(selectedOptions)
        for _, opt in ipairs(options) do
            table.insert(selectedOptions, opt)
            local b = optionButtons[opt]
            if b then b.Text = "[x] " .. tostring(opt); b.TextColor3 = Theme.TextMain end
        end
        emitSelection()
    end))
    TrackConnection(clearAllBtn.MouseButton1Click:Connect(function()
        table.clear(selectedOptions)
        for _, opt in ipairs(options) do
            local b = optionButtons[opt]
            if b then b.Text = "[ ] " .. tostring(opt); b.TextColor3 = Theme.TextDim end
        end
        emitSelection()
    end))
    TrackConnection(SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = string.lower(SearchBar.Text)
        for _, v in pairs(listFrame:GetChildren()) do
            if v:IsA("TextButton") and v ~= selectAllBtn and v ~= clearAllBtn then
                v.Visible = string.find(string.lower(v.Text), txt) ~= nil
            end
        end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen; icon.Text = isOpen and "-" or "+"
        local targetHeight = isOpen and math.min((#options * 28) + 56, 180) or 0
        container.ZIndex = isOpen and 10 or 2
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
        CircleClick(btn)
    end))
end

local function CreateInput(parent, text, placeholder, callback)
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 2}, container)
    local box = CreateInstance("TextBox", {Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 18), BackgroundColor3 = Theme.BgElement, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = Theme.TextDim, TextColor3 = Theme.TextMain, Font = FontMain, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 3}, container)
    AddCorner(box, 6); AddStroke(box, Theme.Border, 1)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 8)}, box)
    TrackConnection(box.FocusLost:Connect(function() if callback then task.spawn(callback, box.Text) end end))
end

local function CreateStatus(parent, text)
    return CreateInstance("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextDim, Font = FontMain, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Active = false, ZIndex = 2}, parent)
end

-- ==========================================
-- 8. 100% FULL FEATURES (NO CUTS)
-- ==========================================
local TabInfo = CreateTab("Info", "i")
local InfoLeft = TabInfo.Left; local InfoRight = TabInfo.Right
local AccCom = CreateAccordion(InfoLeft, "Community", false)
CreateButton(AccCom, "Join Discord", function() CopyText(DISCORD_LINK) end); CreateButton(AccCom, "Follow Creator", function() Notify("Creator", "Link profil kreator tidak ada di dump/template.", 4) end)
local AccFeed = CreateAccordion(InfoLeft, "Feedback", false)
CreateButton(AccFeed, "Copy Discord Invite", function() CopyText(DISCORD_LINK) end); CreateButton(AccFeed, "Submit Bug Report", function() CopyText(DISCORD_LINK); Notify("Bug report", "Link Discord disalin; kirim laporan secara manual.", 4) end)
local AccQuick = CreateAccordion(InfoLeft, "Quick Setup", false)
CreateButton(AccQuick, "Open Quick Setup", function() FeatureNotVerified("Open Quick Setup", true) end); CreateStatus(AccQuick, "Tell Corvus what to do in a few taps.")
local AccSession = CreateAccordion(InfoRight, "Session", true)
local SessionStatus = CreateStatus(AccSession, "Memuat info sesi...")
CreateButton(AccSession, "Rejoin", function() RejoinCurrentServer() end)
CreateButton(AccSession, "Server Hop", function() Notify("Server Hop", "Belum tersedia: daftar server publik/API server hop tidak ada dalam dump yang diberikan.", 5) end)
CreateButton(AccSession, "Copy Job ID", function() CopyText(game.JobId) end)

local TabFishing = CreateTab("Fishing", "F")
local FishLeft = TabFishing.Left; local FishRight = TabFishing.Right
local AccAutoFish = CreateAccordion(FishLeft, "Auto Fish", true)
CreateToggle(AccAutoFish, "Auto Fish", false, function(enabled)
    SetGameAutoFishing(enabled)
end)
CreateDropdown(AccAutoFish, "Mode", {"Fast (default)", "Legit (game's auto fishing)"}, "Fast (default)", function(mode)
    RuntimeState.FishMode = mode
    if mode == "Fast (default)" then
        Notify("Fast mode", "Menggunakan AutoFishing bawaan. Scene tangkapan belum dilewati; alur tangkapan tetap mengikuti game.", 6)
    else
        Notify("Legit mode", "Menggunakan auto fishing bawaan game.", 4)
    end
    if RuntimeState.AutoFish then
        SetGameAutoFishing(false)
        task.wait(0.15)
        SetGameAutoFishing(true)
    end
end)
CreateToggle(AccAutoFish, "Index Hunt", false, function(value) FeatureNotVerified("Index Hunt", value) end)
CreateToggle(AccAutoFish, "Tutorial hold (x2 luck)", false, function(value) FeatureNotVerified("Tutorial hold (x2 luck)", value) end)
CreateToggle(AccAutoFish, "Keep catch streak on trips", false, function(value) FeatureNotVerified("Keep catch streak on trips", value) end)
CreateMultiDropdown(AccAutoFish, "Collect Fish (rarity filter)", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Exotic", "Exclusive"}, {"Secret", "Exotic"}, function(selected)
    RuntimeState.FishRarities = selected
    Notify("Fish filter", "Pilihan tersimpan di UI; belum terhubung ke filter tangkapan game.", 4)
end)
CreateMultiDropdown(AccAutoFish, "Collect Items / Sea Trash", {"ITEM LIST NOT VERIFIED - no selectable item names"}, {}, function(selected)
    RuntimeState.CollectItems = selected
    Notify("Item filter", "Dump ini belum memberi daftar item yang bisa diverifikasi untuk filter ini.", 4)
end)
CreateStatus(AccAutoFish, "AutoFish controller: runtime lookup on toggle\nFast mode still follows game catch flow.")
local AccBait = CreateAccordion(FishLeft, "Throw Charges & Bait", false)
CreateToggle(AccBait, "Use owned throw charges", false, function(value) FeatureNotVerified("Use owned throw charges", value) end)
CreateToggle(AccBait, "Auto Bait", false, function(value) FeatureNotVerified("Auto Bait", value) end)
CreateToggle(AccBait, "Buy bait", false, function(value) FeatureNotVerified("Buy bait", value) end)
CreateSlider(AccBait, "Bait budget", 0, 100, 10, "%", function(value) FeatureNotVerified("Bait budget", value) end)
local AccSmartSell = CreateAccordion(FishRight, "Smart Sell", true)
CreateToggle(AccSmartSell, "Smart Sell settings", false, function(value)
    RuntimeState.Features.SmartSellSettings = value
    if value then OpenGameAutoSellSettings() end
end)
CreateSlider(AccSmartSell, "Sell at backpack", 0, 100, 80, "% / 100%", function(value) FeatureNotVerified("Sell at backpack", value) end)
CreateSlider(AccSmartSell, "Also sell every", 0, 60, 0, " min", function(value) FeatureNotVerified("Also sell every", value) end)
CreateDropdown(AccSmartSell, "Keep rarities", {"Secret, Exotic", "Secret", "Exotic", "Mythic"}, "Secret, Exotic", function(value) FeatureNotVerified("Keep rarities", value) end)
CreateToggle(AccSmartSell, "Keep mutated fish", false, function(value) FeatureNotVerified("Keep mutated fish", value) end)
CreateInput(AccSmartSell, "Keep fish", "---", function(value) FeatureNotVerified("Keep fish", value) end)
CreateToggle(AccSmartSell, "Coins potion at sale", false, function(value) FeatureNotVerified("Coins potion at sale", value) end)
CreateToggle(AccSmartSell, "Coins pet at sale", false, function(value) FeatureNotVerified("Coins pet at sale", value) end)
CreateButton(AccSmartSell, "Open Auto Sell settings", function() OpenGameAutoSellSettings() end)
local AccPond = CreateAccordion(FishRight, "Auto Pond", false)
CreateToggle(AccPond, "Auto Pond", false, function(value) FeatureNotVerified("Auto Pond", value) end)
CreateSlider(AccPond, "Visit every", 0, 240, 60, " min", function(value) FeatureNotVerified("Visit every", value) end)

local TabUpg = CreateTab("Upgrades", "U")
local UpgLeft = TabUpg.Left; local UpgRight = TabUpg.Right
local AccUpg = CreateAccordion(UpgLeft, "Upgrades", true)
CreateToggle(AccUpg, "Auto Upgrades", false, function(value) FeatureNotVerified("Auto Upgrades", value) end)
CreateMultiDropdown(AccUpg, "Upgrades", {"Capacity", "Strength", "Weight", "Bounce"}, {"Capacity", "Strength"}, function(value) FeatureNotVerified("Upgrades", value) end)
CreateStatus(AccUpg, "Capacity 0 | Strength 1 | Weight 0 | Bounce 0\nHooks per cast 3\nBought 0 this session")
local AccMerch = CreateAccordion(UpgLeft, "Traveling Merchant", false)
CreateToggle(AccMerch, "Auto Merchant", false, function(value) FeatureNotVerified("Auto Merchant", value) end)
CreateMultiDropdown(AccMerch, "Buy", {"Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls"}, {"Eggs", "Potions"}, function(value) FeatureNotVerified("Buy", value) end)
local AccRods = CreateAccordion(UpgRight, "Rods", true)
CreateToggle(AccRods, "Auto Rods", false, function(value) FeatureNotVerified("Auto Rods", value) end)
CreateStatus(AccRods, "Equipped Iron Rod (luck 10, strength 10)\nHall rods: Frostbite Rod: locked, Chrono Rod: locked\nBought 0 this session")
local AccWorlds = CreateAccordion(UpgRight, "Worlds", true)
CreateToggle(AccWorlds, "Auto Worlds", false, function(value) FeatureNotVerified("Auto Worlds", value) end)
CreateDropdown(AccWorlds, "Movement", {"Teleport", "Walk"}, "Teleport", function(value) FeatureNotVerified("Movement", value) end)
CreateStatus(AccWorlds, "In World 1, best unlocked World 1\n-")

local TabItems = CreateTab("Items", "I")
local ItemsLeft = TabItems.Left; local ItemsRight = TabItems.Right
local AccChests = CreateAccordion(ItemsLeft, "Chests & Gifts", false)
CreateToggle(AccChests, "Auto Open", false, function(value) FeatureNotVerified("Auto Open", value) end)
CreateStatus(AccChests, "Opened 0 | potions 0 | relics 0\nLast: -")
local AccRelics = CreateAccordion(ItemsLeft, "Boss Relics & Summons", false)
CreateToggle(AccRelics, "Auto Relics", false, function(value) FeatureNotVerified("Auto Relics", value) end)
CreateToggle(AccRelics, "Use Sunken Crowns", false, function(value) FeatureNotVerified("Use Sunken Crowns", value) end)
local AccMutate = CreateAccordion(ItemsLeft, "Mutation Dealer", false)
CreateToggle(AccMutate, "Auto Mutate", false, function(value) FeatureNotVerified("Auto Mutate", value) end)
CreateDropdown(AccMutate, "Scroll", {"Mutation Scroll first", "Ultra first"}, "Mutation Scroll first", function(value) FeatureNotVerified("Scroll", value) end)
CreateStatus(AccMutate, "Mutation Scrolls 0, Ultra 0\nSpins 0 this session")
local AccPotions = CreateAccordion(ItemsRight, "Potions", true)
CreateToggle(AccPotions, "Auto Potions", false, function(value) FeatureNotVerified("Auto Potions", value) end)
CreateMultiDropdown(AccPotions, "Potions", {"Luck", "Coins", "XP", "Mutation"}, {"Luck", "Coins", "XP"}, function(value) FeatureNotVerified("Potions", value) end)
CreateStatus(AccPotions, "Running: none\nOwned: none")
local AccEnchant = CreateAccordion(ItemsRight, "Enchant", false)
CreateToggle(AccEnchant, "Auto Enchant", false, function(value) FeatureNotVerified("Auto Enchant", value) end)
CreateMultiDropdown(AccEnchant, "Stop at", {"Abyssal", "Archivist", "Autopilot", "Cursed", "Deepnet", "Eclipse", "Fishmonger"}, {"Deepnet", "Fishmonger"}, function(value) FeatureNotVerified("Stop at", value) end)
CreateStatus(AccEnchant, "Rod enchants: - / -\nStones 0, Ultra 0 | rolls 0 this session")
local AccPets = CreateAccordion(ItemsRight, "Pets, Eggs & Skin", false)
CreateToggle(AccPets, "Auto Hatch Eggs", false, function(value) FeatureNotVerified("Auto Hatch Eggs", value) end)
CreateToggle(AccPets, "Equip Best Pet", false, function(value) FeatureNotVerified("Equip Best Pet", value) end)
CreateToggle(AccPets, "Auto Pond Pets", false, function(value) FeatureNotVerified("Auto Pond Pets", value) end)
CreateToggle(AccPets, "Wear best rod skin", false, function(value) FeatureNotVerified("Wear best rod skin", value) end)

local TabRewards = CreateTab("Rewards", "R")
local RewLeft = TabRewards.Left; local RewRight = TabRewards.Right
local AccRewards = CreateAccordion(RewLeft, "Rewards", true)
CreateToggle(AccRewards, "Auto Rewards", false, function(value) FeatureNotVerified("Auto Rewards", value) end)
CreateStatus(AccRewards, "Claimed 0 this session")
local AccBigMouth = CreateAccordion(RewLeft, "Big Mouth", true)
CreateToggle(AccBigMouth, "Auto Big Mouth", false, function(value) FeatureNotVerified("Auto Big Mouth", value) end)
CreateStatus(AccBigMouth, "Luck +0% | feeds 0 | goal 0/9.5 kg\nHungry now")
local AccCodes = CreateAccordion(RewRight, "Codes", true)
CreateToggle(AccCodes, "Auto Redeem Codes", false, function(value) FeatureNotVerified("Auto Redeem Codes", value) end)
CreateButton(AccCodes, "Redeem all known", function() FeatureNotVerified("Redeem all known", true) end)
CreateInput(AccCodes, "Code", "Type a code from the game's socials", function(value) FeatureNotVerified("Code", value) end)
CreateButton(AccCodes, "Redeem", function() FeatureNotVerified("Redeem", true) end)
local AccCargo = CreateAccordion(RewRight, "Cargo Orders", false)
CreateToggle(AccCargo, "Auto Tasks (cargo orders)", false, function(value) FeatureNotVerified("Auto Tasks (cargo orders)", value) end)

local TabWebhook = CreateTab("Webhook", "W")
local WebLeft = TabWebhook.Left; local WebRight = TabWebhook.Right
local AccDiscord = CreateAccordion(WebLeft, "Discord Webhook", true)
CreateToggle(AccDiscord, "Post to Discord", false, function(value) FeatureNotVerified("Post to Discord", value) end)
CreateInput(AccDiscord, "Webhook URL", "https://discord.com/api/webhooks/...", function(value) FeatureNotVerified("Webhook URL", value) end)
CreateToggle(AccDiscord, "Live stats card", false, function(value) FeatureNotVerified("Live stats card", value) end)
CreateSlider(AccDiscord, "Report every", 0, 60, 30, " min", function(value) FeatureNotVerified("Report every", value) end)
CreateToggle(AccDiscord, "Hide my username", false, function(value) FeatureNotVerified("Hide my username", value) end)
CreateButton(AccDiscord, "Send test", function() FeatureNotVerified("Send test", true) end)
local AccPosts = CreateAccordion(WebRight, "Posts", true)
CreateToggle(AccPosts, "Rare catches", false, function(value) FeatureNotVerified("Rare catches", value) end)
CreateDropdown(AccPosts, "Rare means", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}, "Secret, Exotic", function(value) FeatureNotVerified("Rare means", value) end)
CreateToggle(AccPosts, "Sales", false, function(value) FeatureNotVerified("Sales", value) end)
CreateToggle(AccPosts, "Purchases", false, function(value) FeatureNotVerified("Purchases", value) end)
CreateToggle(AccPosts, "Codes redeemed", false, function(value) FeatureNotVerified("Codes redeemed", value) end)

local TabMisc = CreateTab("Misc", "S")
local MiscLeft = TabMisc.Left; local MiscRight = TabMisc.Right
local AccAntiAFK = CreateAccordion(MiscLeft, "Anti AFK", true)
CreateToggle(AccAntiAFK, "Anti AFK", false, function(enabled)
    SetAntiAFK(enabled)
    Notify("Anti AFK", enabled and "Aktif" or "Nonaktif", 3)
end)
CreateToggle(AccAntiAFK, "Auto jump", false, function(value) SetAutoJump(value) end)
CreateSlider(AccAntiAFK, "Jump every", 0, 60, 30, "s", function(value) RuntimeState.AutoJumpInterval = math.max(5, value); Notify("Auto jump", "Interval: " .. tostring(RuntimeState.AutoJumpInterval) .. " detik.", 3) end)
CreateToggle(AccAntiAFK, "Micro movement", false, function(value) FeatureNotVerified("Micro movement", value) end)
CreateStatus(AccAntiAFK, "AFK inputs sent 0\nLast activity 1m 35s ago")
local AccConn = CreateAccordion(MiscLeft, "Connection", false)
CreateToggle(AccConn, "Auto reconnect", false, function(value) RuntimeState.AutoReconnect = value; Notify("Auto reconnect", value and "Aktif untuk TeleportInitFailed saja; disconnect/kick tidak bisa dijamin pulih." or "Nonaktif.", 4) end)
CreateToggle(AccConn, "Hide paused popup", false, function(value) FeatureNotVerified("Hide paused popup", value) end)
CreateButton(AccConn, "Rejoin now", function() RejoinCurrentServer() end)
local AccPerform = CreateAccordion(MiscRight, "Performance", true)
CreateToggle(AccPerform, "Anti lag", false, function(value) ApplyPerformance(value, RuntimeState.PerformanceLevel) end)
CreateDropdown(AccPerform, "Level", {"Balanced", "High", "Low"}, "Balanced", function(value) RuntimeState.PerformanceLevel = value; if RuntimeState.AntiLag then ApplyPerformance(true, value) else Notify("Performance", "Level disimpan: " .. tostring(value), 3) end end)
CreateToggle(AccPerform, "Disable 3D rendering", false, function(value) RuntimeState.Disable3D = value; local ok = pcall(function() RunService:Set3dRenderingEnabled(not value) end); Notify("3D rendering", ok and (value and "Rendering 3D dimatikan; tampilan dapat kosong." or "Rendering 3D diaktifkan.") or "API tidak tersedia.", 4) end)
CreateDropdown(AccPerform, "FPS cap", {"Unlimited", "30", "60"}, "Unlimited", function(value) ApplyFPSCap(value) end)
local AccAutoExec = CreateAccordion(MiscRight, "Auto Execute", false)
CreateToggle(AccAutoExec, "Keep after teleport", false, function(value) FeatureNotVerified("Keep after teleport", value) end)
CreateButton(AccAutoExec, "Copy loader", function() CopyText("-- Loader URL belum tersedia; ganti komentar ini dengan loader milik Anda.") end)

local function RefreshSessionStatus()
    if not SessionStatus or not SessionStatus.Parent then return end
    local playerCount = #Players:GetPlayers()
    local maxPlayers = Players.MaxPlayers
    local jobId = tostring(game.JobId or "")
    if #jobId > 18 then jobId = string.sub(jobId, 1, 18) .. "..." end
    SessionStatus.Text = string.format(
        "Place ID: %s\\nPlayers: %d / %d\\nJob ID: %s",
        tostring(game.PlaceId), playerCount, maxPlayers, jobId ~= "" and jobId or "Unavailable"
    )
end
RefreshSessionStatus()
task.spawn(function()
    while SessionStatus and SessionStatus.Parent do
        task.wait(5)
        RefreshSessionStatus()
    end
end)

SelectTab("Info")

-- ==========================================
-- 9. LOGIKA ONE-BUTTON CONTROL (MINIMIZE / MAXIMIZE)
-- ==========================================
local isMinimized = false
local originalSize = UDim2.fromOffset(680, 460)
local minimizedSize = UDim2.fromOffset(250, 60)

TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MinBtn.Text = "+"
        Sidebar.Visible = false
        ContentArea.Visible = false
        resizeHandle.Visible = false
        -- Compact bar moves to upper-center with a safe margin; header remains draggable.
        MainFrame.AnchorPoint = Vector2.new(0.5, 0)
        MainFrame.Position = UDim2.new(0.5, 0, 0, 18)
        TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {Size = minimizedSize}):Play()
    else
        MinBtn.Text = "-"
        Sidebar.Visible = true
        ContentArea.Visible = true
        resizeHandle.Visible = true
        MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {Size = originalSize}):Play()
    end
end))

SharedEnvironment.__PJANE_CLEANUP = function()
    pcall(function() if RuntimeState.AutoFish then SetGameAutoFishing(false) end end)
    pcall(SetAntiAFK, false)
    pcall(SetAutoJump, false)
    if RuntimeState.Disable3D then
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end
    if RuntimeState.AntiLag then pcall(ApplyPerformance, false, RuntimeState.PerformanceLevel) end
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    pcall(function() if MainFrame then MainFrame:Destroy() end end)
    pcall(function() if NotificationGui then NotificationGui:Destroy() end end)
end

print("[PJANE HUB] UI initialized; only source-verified integrations are enabled.")
