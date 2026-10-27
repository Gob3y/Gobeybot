--[[
    ===================================================================
       PJANE HUB - ULTIMATE LARPER & UTILITY HUB (FIXED UI EDITION)
       (Client-Only Avatar Customizer + Movement + Potato PC Optimizer)
       
       Perbaikan Utama:
       - UI langsung muncul saat di-execute (ENABLE_KEY_SYSTEM = false default)
       - Semua fitur (Avatar, Headless, Korblox, Aksesoris, Movement, FPS)
         dalam keadaan OFF saat pertama kali dijalankan (tidak otomatis aktif)
       - Perbaikan bug Dragging Header yang sebelumnya membuat UI hilang ke pojok
       - Perbaikan Accordion (+/-) dan tombol Minimize (-)
       - Toggle ON/OFF per item & per kategori (bisa dilepas tanpa harus mati/reset)
       - Input Custom Asset ID (bisa pasang ID apapun dari Rolimons/Catalog)
       - Movement Lengkap: WalkSpeed, JumpPower, Infinite Jump, NoClip
       - Optimizer HP Kentang: Low / Balanced / Ultra Potato + Disable 3D Render
    ===================================================================
]]

-- ==========================================
-- KONFIGURASI UTAMA
-- ==========================================
local ENABLE_KEY_SYSTEM = true -- Diatur false agar UI langsung muncul saat execute
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
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
for _ = 1, 30 do
    if LP then break end
    task.wait(0.1)
    LP = Players.LocalPlayer
end
if not LP then return end

local PlayerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local SharedEnvironment = _G
if type(getgenv) == "function" then
    local envOk, env = pcall(getgenv)
    if envOk and type(env) == "table" then
        SharedEnvironment = env
    end
end
if type(SharedEnvironment.__PJANE_CLEANUP) == "function" then
    pcall(SharedEnvironment.__PJANE_CLEANUP)
    SharedEnvironment.__PJANE_CLEANUP = nil
end

local function GetUIRoot()
    if RunService:IsStudio() then return PlayerGui end
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and root then return root end
    end
    local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if okCore and coreGui then return coreGui end
    return PlayerGui
end

local UIRoot = GetUIRoot()
for _, parent in ipairs({PlayerGui, UIRoot}) do
    local old1 = parent:FindFirstChild("DeveloperPanel_UI")
    if old1 then pcall(function() old1:Destroy() end) end
    local old2 = parent:FindFirstChild("PJANE_Notif")
    if old2 then pcall(function() old2:Destroy() end) end
end

local Connections = {}
local function TrackConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

-- ==========================================
-- 2. DATABASE ASSET ID POPULER (ROLIMONS & CATALOG)
-- ==========================================
local LARP_CATALOG = {
    Dominus = {
        {Name = "Dominus Empyreus", Id = 21070012},
        {Name = "Dominus Frigidus", Id = 48545806},
        {Name = "Dominus Infernus", Id = 31101391},
        {Name = "Dominus Aureus", Id = 138932314},
        {Name = "Dominus Praefectus", Id = 527365852},
        {Name = "Dominus Messor", Id = 64444871}
    },
    CrownsAndValks = {
        {Name = "Valkyrie Helm (Original)", Id = 1365767},
        {Name = "Blackvalk (Black Valkyrie)", Id = 124730194},
        {Name = "Violet Valkyrie", Id = 1402432199},
        {Name = "Ice Valkyrie", Id = 4390891467},
        {Name = "Sparkle Time Valkyrie", Id = 1180433861},
        {Name = "Red Sparkle Time Fedora", Id = 15222384},
        {Name = "Purple Sparkle Time Fedora", Id = 63043890},
        {Name = "Domino Crown", Id = 1031429},
        {Name = "Lord of the Federation", Id = 215718515},
        {Name = "Ice Crown", Id = 12853158}
    },
    Horns = {
        {Name = "Fiery Horns of the Netherworld", Id = 215719598},
        {Name = "Frozen Horns of the Frigid Planes", Id = 74891470},
        {Name = "Poisoned Horns of the Toxic Wasteland", Id = 1744060292},
        {Name = "Darkseed The Fallen Antlers", Id = 141742418},
        {Name = "Silverthorn Antlers", Id = 439542036},
        {Name = "Demonic Greathorns", Id = 62758151},
        {Name = "Glorious Antlers of the Fae", Id = 129112260}
    },
    Face = {
        {Name = "Black Faceless Visor", Id = 13958934911},
        {Name = "Cyber Punk Visor Mask", Id = 16140956184},
        {Name = "Tactical Night Vision Goggles", Id = 14959605970},
        {Name = "Shadow Ninja Mask", Id = 115682855},
        {Name = "Clockwork Shades", Id = 11748356},
        {Name = "Orange Shades", Id = 10159600649}
    },
    NeckAndShoulders = {
        {Name = "Spiked Punk Choker", Id = 94723481},
        {Name = "Royal Winter Scarf", Id = 35678912},
        {Name = "Darkage Pauldrons (Armor Bahu)", Id = 318531109},
        {Name = "Pauldrons of Valhalla", Id = 84712940},
        {Name = "Shoulder Dragon Pet", Id = 42981305}
    },
    WingsAndBack = {
        {Name = "Archangel Wings", Id = 19398258},
        {Name = "Bone Wings", Id = 108163475},
        {Name = "Shadow Demon Wings", Id = 493214732},
        {Name = "Immortal Sword Wicked Heart", Id = 2470750640},
        {Name = "Dual Venomshanks (Back Swords)", Id = 1029025},
        {Name = "Royal Dark Cape", Id = 63892331}
    }
}

-- ==========================================
-- 3. RUNTIME STATE (SEMUA DEFAULT OFF)
-- ==========================================
local Notify
local SessionStartTime = os.clock()
local CurrentFPS = 60

local RuntimeState = {
    -- Avatar Customizer States (Default OFF)
    HeadlessEnabled = false,
    KorbloxEnabled = false,
    ActiveAssets = {}, -- [assetId] = true/false
    CustomAssetInput = "",

    -- Movement States (Default OFF)
    WalkSpeedEnabled = false,
    WalkSpeedVal = 16,
    JumpPowerEnabled = false,
    JumpPowerVal = 50,
    InfJumpEnabled = false,
    NoClipEnabled = false,

    -- Performance / HP Kentang States (Default OFF)
    AntiLag = false,
    PerformanceLevel = "Balanced", -- Low, Balanced, Ultra Potato
    Disable3D = false,
    FPSCap = "Unlimited",
    AntiAFK = false,
    AntiAFKConnection = nil,

    SavedLighting = nil,
    HeadTransparencyConn = nil,
    HeadChildConn = nil,
    LegTransparencyConns = {}
}

TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if dt > 0 then
        CurrentFPS = math.clamp(math.round(1 / dt), 1, 999)
    end
end))

local function GetHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ==========================================
-- 4. LOGIKA AVATAR CUSTOMIZER (CLIENT-ONLY & BISA ON/OFF)
-- ==========================================
local function DisconnectList(list)
    for _, c in ipairs(list) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(list)
end

local function ApplyHeadlessState(enabled)
    RuntimeState.HeadlessEnabled = enabled == true
    local char = LP.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if RuntimeState.HeadTransparencyConn then
        pcall(function() RuntimeState.HeadTransparencyConn:Disconnect() end)
        RuntimeState.HeadTransparencyConn = nil
    end
    if RuntimeState.HeadChildConn then
        pcall(function() RuntimeState.HeadChildConn:Disconnect() end)
        RuntimeState.HeadChildConn = nil
    end

    if RuntimeState.HeadlessEnabled then
        head.Transparency = 1
        pcall(function()
            head.LocalTransparencyModifier = 1
            RuntimeState.HeadTransparencyConn = head:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                if RuntimeState.HeadlessEnabled then
                    head.LocalTransparencyModifier = 1
                end
            end)
        end)
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") then
                child.Transparency = 1
            elseif child:IsA("SpecialMesh") then
                child:SetAttribute("PJANE_OrigScale", child.Scale)
                child.Scale = Vector3.new(0, 0, 0)
            elseif child:IsA("WrapLayer") then
                child.Enabled = false
            end
        end
        RuntimeState.HeadChildConn = head.ChildAdded:Connect(function(child)
            if not RuntimeState.HeadlessEnabled then return end
            task.wait()
            if child:IsA("Decal") then
                child.Transparency = 1
            elseif child:IsA("SpecialMesh") then
                child.Scale = Vector3.new(0, 0, 0)
            end
        end)
    else
        head.Transparency = 0
        pcall(function() head.LocalTransparencyModifier = 0 end)
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") then
                child.Transparency = 0
            elseif child:IsA("SpecialMesh") then
                local orig = child:GetAttribute("PJANE_OrigScale")
                child.Scale = orig or Vector3.new(1.25, 1.25, 1.25)
            elseif child:IsA("WrapLayer") then
                child.Enabled = true
            end
        end
    end
end

local function ApplyKorbloxState(enabled)
    RuntimeState.KorbloxEnabled = enabled == true
    DisconnectList(RuntimeState.LegTransparencyConns)

    local char = LP.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        local upper = char:FindFirstChild("RightUpperLeg")
        local lower = char:FindFirstChild("RightLowerLeg")
        local foot = char:FindFirstChild("RightFoot")
        if not (upper and lower and foot) then return end

        local oldVisual = upper:FindFirstChild("KorbloxVisualPart")
        if oldVisual then oldVisual:Destroy() end

        if RuntimeState.KorbloxEnabled then
            for _, part in ipairs({upper, lower, foot}) do
                part.Transparency = 1
                pcall(function()
                    part.LocalTransparencyModifier = 1
                    local c = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                        if RuntimeState.KorbloxEnabled then
                            part.LocalTransparencyModifier = 1
                        end
                    end)
                    table.insert(RuntimeState.LegTransparencyConns, c)
                end)
            end

            local korbloxPart = Instance.new("Part")
            korbloxPart.Name = "KorbloxVisualPart"
            korbloxPart.Size = Vector3.new(1, 1, 1)
            korbloxPart.CanCollide = false
            korbloxPart.CanTouch = false
            korbloxPart.CanQuery = false
            korbloxPart.Massless = true
            korbloxPart.CFrame = upper.CFrame

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://902942096"
            mesh.TextureId = "rbxassetid://902843398"
            mesh.Scale = Vector3.new(1, 1, 1)
            mesh.Parent = korbloxPart

            local weld = Instance.new("Weld")
            weld.Part0 = upper
            weld.Part1 = korbloxPart
            weld.C0 = CFrame.new(0, 0, 0)
            weld.C1 = CFrame.new(0, 0, 0)
            weld.Parent = korbloxPart

            korbloxPart.Parent = upper
        else
            for _, part in ipairs({upper, lower, foot}) do
                part.Transparency = 0
                pcall(function() part.LocalTransparencyModifier = 0 end)
            end
        end
    else
        local rightLeg = char:FindFirstChild("Right Leg")
        if not rightLeg then return end

        local oldMesh = rightLeg:FindFirstChild("PJANE_KorbloxR6Mesh")
        if oldMesh then oldMesh:Destroy() end
        local oldCharMesh = char:FindFirstChild("PJANE_KorbloxR6CharMesh")
        if oldCharMesh then oldCharMesh:Destroy() end

        if RuntimeState.KorbloxEnabled then
            pcall(function()
                local charMesh = Instance.new("CharacterMesh")
                charMesh.Name = "PJANE_KorbloxR6CharMesh"
                charMesh.MeshId = 101851696
                charMesh.BodyPart = Enum.BodyPart.RightLeg
                charMesh.Parent = char
            end)
            pcall(function()
                local specialMesh = Instance.new("SpecialMesh")
                specialMesh.Name = "PJANE_KorbloxR6Mesh"
                specialMesh.MeshType = Enum.MeshType.FileMesh
                specialMesh.MeshId = "http://www.roblox.com/asset/?id=101851696"
                specialMesh.TextureId = "http://www.roblox.com/asset/?id=101851254"
                specialMesh.Scale = Vector3.new(1, 1, 1)
                specialMesh.Parent = rightLeg
            end)
        end
    end
end

local function SetAccessoryEquipped(assetId, equip)
    assetId = tonumber(assetId)
    if not assetId then return false end

    RuntimeState.ActiveAssets[assetId] = equip and true or nil
    local char = LP.Character
    if not char then return false end

    local tag = "PJANE_CustomAcc_" .. tostring(assetId)
    local existing = char:FindFirstChild(tag)
    if existing then
        existing:Destroy()
    end

    if not equip then
        return true
    end

    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(assetId))
    end)
    if not ok or not objects or not objects[1] then
        if Notify then
            Notify("Aksesoris Gagal", "Tidak dapat memuat Asset ID: " .. tostring(assetId), 3)
        end
        return false
    end

    local asset = objects[1]
    asset.Name = tag
    local handle = asset:FindFirstChild("Handle") or asset:FindFirstChildWhichIsA("BasePart")
    local head = char:FindFirstChild("Head")
    if not handle or not head then
        pcall(function() asset:Destroy() end)
        return false
    end

    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    asset.Parent = char

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and asset:IsA("Accessory") then
        pcall(function() humanoid:AddAccessory(asset) end)
    end

    local existingWeld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("WeldConstraint") or handle:FindFirstChildOfClass("Motor6D")
    if not existingWeld then
        local handleAtt = handle:FindFirstChildOfClass("Attachment")
        local targetPart = head
        local targetAtt = nil

        if handleAtt then
            local found = char:FindFirstChild(handleAtt.Name, true)
            if found and found:IsA("Attachment") and found.Parent and found.Parent:IsA("BasePart") then
                targetPart = found.Parent
                targetAtt = found
            end
        end

        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = targetPart
        weld.Part1 = handle
        if handleAtt and targetAtt then
            weld.C0 = targetAtt.CFrame
            weld.C1 = handleAtt.CFrame
        else
            weld.C0 = CFrame.new(0, 0.5, 0)
        end
        weld.Parent = handle
    end

    return true
end

local function ReapplyActiveCosmetics()
    local char = LP.Character
    if not char then return end
    if RuntimeState.HeadlessEnabled then
        ApplyHeadlessState(true)
    end
    if RuntimeState.KorbloxEnabled then
        ApplyKorbloxState(true)
    end
    for assetId, isEquipped in pairs(RuntimeState.ActiveAssets) do
        if isEquipped then
            task.spawn(SetAccessoryEquipped, assetId, true)
        end
    end
end

local function ClearAllCustomAccessories(respawnCharacter)
    RuntimeState.HeadlessEnabled = false
    RuntimeState.KorbloxEnabled = false
    table.clear(RuntimeState.ActiveAssets)

    local char = LP.Character
    if char then
        ApplyHeadlessState(false)
        ApplyKorbloxState(false)
        for _, child in ipairs(char:GetChildren()) do
            if string.find(child.Name, "^PJANE_CustomAcc_") then
                pcall(function() child:Destroy() end)
            end
        end
        if respawnCharacter then
            pcall(function() char:BreakJoints() end)
            if Notify then
                Notify("Avatar Reset", "Karakter berhasil di-respawn ke wujud asli.", 3)
            end
        else
            if Notify then
                Notify("Avatar Bersih", "Semua aksesoris & efek lokal dilepas.", 3)
            end
        end
    end
end

TrackConnection(LP.CharacterAdded:Connect(function()
    task.wait(1)
    ReapplyActiveCosmetics()
end))

-- ==========================================
-- 5. LOGIKA MOVEMENT (SPEED, JUMP, INF JUMP, NOCLIP)
-- ==========================================
local NoClipCache = {}

local function SetNoClip(enabled)
    RuntimeState.NoClipEnabled = enabled == true
    if not RuntimeState.NoClipEnabled then
        for part, origCollide in pairs(NoClipCache) do
            if part and part.Parent then
                pcall(function() part.CanCollide = origCollide end)
            end
        end
        table.clear(NoClipCache)
    end
    if Notify then
        Notify("NoClip", RuntimeState.NoClipEnabled and "NoClip Aktif (Tembus Tembok)" or "NoClip Nonaktif", 3)
    end
end

TrackConnection(RunService.Stepped:Connect(function()
    if RuntimeState.NoClipEnabled then
        local char = LP.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if NoClipCache[part] == nil then
                        NoClipCache[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end
    end
end))

TrackConnection(UserInputService.JumpRequest:Connect(function()
    if RuntimeState.InfJumpEnabled then
        local humanoid = GetHumanoid()
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

task.spawn(function()
    while task.wait(0.2) do
        local humanoid = GetHumanoid()
        if humanoid then
            if RuntimeState.WalkSpeedEnabled then
                pcall(function() humanoid.WalkSpeed = RuntimeState.WalkSpeedVal end)
            end
            if RuntimeState.JumpPowerEnabled then
                pcall(function()
                    if humanoid.UseJumpPower then
                        humanoid.JumpPower = RuntimeState.JumpPowerVal
                    else
                        humanoid.JumpHeight = math.max(7.2, RuntimeState.JumpPowerVal * 0.15)
                    end
                end)
            end
        end
    end
end)

-- ==========================================
-- 6. LOGIKA OPTIMIZER HP KENTANG (FPS & 3D RENDER)
-- ==========================================
local function ApplyFPSCap(value)
    RuntimeState.FPSCap = value
    local cap = 999
    if value == "30 FPS" then cap = 30
    elseif value == "60 FPS" then cap = 60
    elseif value == "120 FPS" then cap = 120 end

    if type(setfpscap) == "function" then
        pcall(setfpscap, cap)
        if Notify then Notify("FPS Cap", "Batas FPS diatur ke: " .. tostring(value), 3) end
    else
        if Notify then Notify("FPS Cap", "Executor tidak mendukung setfpscap.", 3) end
    end
end

local function ApplyPerformanceMode(enabled, level)
    RuntimeState.AntiLag = enabled == true
    RuntimeState.PerformanceLevel = level or RuntimeState.PerformanceLevel
    local terrain = workspace:FindFirstChildOfClass("Terrain")

    if not RuntimeState.SavedLighting then
        RuntimeState.SavedLighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            Decoration = terrain and terrain.Decoration or false
        }
    end

    pcall(function()
        if RuntimeState.AntiLag then
            local lvl = RuntimeState.PerformanceLevel
            Lighting.GlobalShadows = false
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.Decoration = false
            end

            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Sky") then
                    if lvl == "Ultra (HP Kentang)" or obj:IsA("PostEffect") then
                        pcall(function() obj.Enabled = false end)
                    end
                end
            end

            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                    v.Enabled = false
                elseif (lvl == "Balanced" or lvl == "Ultra (HP Kentang)") and v:IsA("BasePart") then
                    v.CastShadow = false
                    if lvl == "Ultra (HP Kentang)" then
                        v.Material = Enum.Material.SmoothPlastic
                        v.Reflectance = 0
                    end
                elseif lvl == "Ultra (HP Kentang)" and (v:IsA("Decal") or v:IsA("Texture")) then
                    v.Transparency = 1
                end
            end
        else
            local s = RuntimeState.SavedLighting
            if s then
                Lighting.GlobalShadows = s.GlobalShadows
                Lighting.EnvironmentDiffuseScale = s.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = s.EnvironmentSpecularScale
                if terrain then terrain.Decoration = s.Decoration end
            end
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("PostEffect") then
                    pcall(function() obj.Enabled = true end)
                end
            end
        end
    end)

    if Notify then
        Notify("Potato Optimizer", RuntimeState.AntiLag and ("Aktif (" .. tostring(RuntimeState.PerformanceLevel) .. ")") or "Pengaturan grafik dipulihkan", 3)
    end
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
                local cam = workspace.CurrentCamera
                if cam then
                    VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
                end
            end)
        end)
    end
    if Notify then Notify("Anti-AFK", enabled and "Anti-AFK Aktif" or "Anti-AFK Nonaktif", 3) end
end

local function RejoinServer()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
end

-- ==========================================
-- 7. UI THEME & KOMPONEN (GLASSMORPHISM TEMPLATE)
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
    Red         = Color3.fromRGB(235, 85, 85)
}

local FontMain = Enum.Font.GothamMedium
local FontBold = Enum.Font.GothamBold
local FontBlack = Enum.Font.GothamBlack

local function CreateInstance(className, properties, parent)
    local obj = Instance.new(className)
    if properties then
        for k, v in pairs(properties) do
            if k ~= "Parent" then
                obj[k] = v
            end
        end
    end
    if parent then
        obj.Parent = parent
    elseif properties and properties.Parent then
        obj.Parent = properties.Parent
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

-- Notification System
local NotificationGui = CreateInstance("ScreenGui", {
    Name = "PJANE_Notif",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, UIRoot)

local NotificationLayout = CreateInstance("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -24, 1, -24),
    Size = UDim2.new(0, 300, 1, 0)
}, NotificationGui)

Notify = function(Title, Description, Time)
    Time = Time or 3
    local Count = #NotificationLayout:GetChildren()
    local Frame = CreateInstance("Frame", {
        BackgroundColor3 = Theme.BgMain,
        Size = UDim2.new(1, 0, 0, 62),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 360, 1, -((62 + 8) * Count))
    }, NotificationLayout)
    AddCorner(Frame, 8)
    AddStroke(Frame, Theme.Accent, 1.2, 0.3)

    CreateInstance("TextLabel", {
        Font = FontBold,
        Text = tostring(Title or "PJANE HUB"),
        TextColor3 = Theme.TextMain,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 0, 8)
    }, Frame)

    CreateInstance("TextLabel", {
        Font = FontMain,
        Text = tostring(Description or ""),
        TextColor3 = Theme.TextDim,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.new(0, 10, 0, 27)
    }, Frame)

    TweenService:Create(Frame, TweenInfo.new(0.28, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 1, -((62 + 8) * Count))
    }):Play()

    task.spawn(function()
        task.wait(Time)
        if not Frame or not Frame.Parent then return end
        local t = TweenService:Create(Frame, TweenInfo.new(0.25), {
            Position = UDim2.new(0, 360, 1, Frame.Position.Y.Offset)
        })
        t:Play()
        t.Completed:Connect(function()
            if Frame then Frame:Destroy() end
        end)
    end)
end

-- ScreenGui Utama
local ScreenGui = CreateInstance("ScreenGui", {
    Name = "DeveloperPanel_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, UIRoot)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(680, 460),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.BgMain,
    BorderSizePixel = 0,
    Visible = not ENABLE_KEY_SYSTEM,
    ClipsDescendants = true
}, ScreenGui)
AddCorner(MainFrame, 12)
AddStroke(MainFrame, Theme.Border, 1.5)

local UIScale = CreateInstance("UIScale", {Scale = 1}, MainFrame)
local function UpdateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    UIScale.Scale = math.clamp(math.min((vp.X - 36) / 680, (vp.Y - 36) / 460), 0.45, 1)
end
UpdateScale()
TrackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(UpdateScale))
if workspace.CurrentCamera then
    TrackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale))
end

-- Safe Dragging Function (Anti-Hilang ke Pojok Kiri Atas)
local function MakeDraggable(topbar, frame, ignoreList)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    ignoreList = ignoreList or {}

    local function isIgnored(pos)
        for _, guiObj in ipairs(ignoreList) do
            if guiObj and guiObj.Visible then
                local aPos = guiObj.AbsolutePosition
                local aSize = guiObj.AbsoluteSize
                if pos.X >= aPos.X and pos.X <= aPos.X + aSize.X and pos.Y >= aPos.Y and pos.Y <= aPos.Y + aSize.Y then
                    return true
                end
            end
        end
        return false
    end

    TrackConnection(topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isIgnored(input.Position) then return end
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
        end
    end))

    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragInput = nil
        end
    end))
end

-- Key System (Jika ENABLE_KEY_SYSTEM = true)
if ENABLE_KEY_SYSTEM then
    local KeyOverlay = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        ZIndex = 50
    }, ScreenGui)

    local KeyFrame = CreateInstance("Frame", {
        Size = UDim2.fromOffset(380, 220),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.BgMain,
        ZIndex = 51
    }, KeyOverlay)
    AddCorner(KeyFrame, 12)
    AddStroke(KeyFrame, Theme.Border, 1.5)

    CreateInstance("UIListLayout", {
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    }, KeyFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 20)}, KeyFrame)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 0, 28),
        BackgroundTransparency = 1,
        Text = "PJANE HUB",
        TextColor3 = Theme.TextMain,
        Font = FontBlack,
        TextSize = 22,
        LayoutOrder = 1,
        ZIndex = 52
    }, KeyFrame)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 0, 18),
        BackgroundTransparency = 1,
        Text = "Masukkan Key",
        TextColor3 = Theme.TextDim,
        Font = FontMain,
        TextSize = 12,
        LayoutOrder = 2,
        ZIndex = 52
    }, KeyFrame)

    local InputCont = CreateInstance("Frame", {
        Size = UDim2.new(0.88, 0, 0, 38),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        ZIndex = 52
    }, KeyFrame)
    CreateInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8)}, InputCont)

    local KeyInput = CreateInstance("TextBox", {
        Size = UDim2.new(0.62, -4, 1, 0),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        PlaceholderText = "Key...",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 13,
        ZIndex = 52
    }, InputCont)
    AddCorner(KeyInput, 8)
    AddStroke(KeyInput, Theme.Border, 1)

    local UnlockBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.38, -4, 1, 0),
        BackgroundColor3 = Theme.Accent,
        Text = "Unlock",
        TextColor3 = Color3.new(1, 1, 1),
        Font = FontBold,
        TextSize = 13,
        ZIndex = 52
    }, InputCont)
    AddCorner(UnlockBtn, 8)

    local SkipBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.88, 0, 0, 34),
        BackgroundColor3 = Theme.BgGlass,
        Text = "Copy Discord / Masuk",
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 12,
        LayoutOrder = 4,
        ZIndex = 52
    }, KeyFrame)
    AddCorner(SkipBtn, 8)
    AddStroke(SkipBtn, Theme.Border, 1)

    local function CheckKey()
        if KeyInput.Text == CORRECT_KEY then
            KeyOverlay:Destroy()
            MainFrame.Visible = true
            Notify("PJANE HUB", "Key diterima!", 4)
        else
            KeyInput.Text = "Key Salah!"
            task.wait(1)
            if KeyInput and KeyInput.Parent then KeyInput.Text = "" end
        end
    end
    UnlockBtn.MouseButton1Click:Connect(CheckKey)
    SkipBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(DISCORD_LINK) end)
        Notify("Discord", "Link Discord disalin ke clipboard!", 3)
    end)
end

-- Header & Tombol Minimize
local Header = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = Theme.BgGlass,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 10
}, MainFrame)
AddCorner(Header, 12)

CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    ZIndex = 10
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -120, 0, 22),
    Position = UDim2.new(0, 18, 0, 10),
    BackgroundTransparency = 1,
    Text = "PJANE HUB",
    TextColor3 = Theme.TextMain,
    Font = FontBlack,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 10
}, Header)

CreateInstance("TextLabel", {
    Size = UDim2.new(1, -120, 0, 16),
    Position = UDim2.new(0, 18, 0, 32),
    BackgroundTransparency = 1,
    Text = "Client Avatar Customizer (Larp) | Movement | Potato Optimizer",
    TextColor3 = Theme.TextDim,
    Font = FontMain,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 10
}, Header)

local MinBtn = CreateInstance("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -46, 0.5, -16),
    BackgroundColor3 = Theme.BgElement,
    Text = "-",
    TextColor3 = Theme.TextMain,
    Font = FontBold,
    TextSize = 16,
    AutoButtonColor = false,
    ZIndex = 12
}, Header)
AddCorner(MinBtn, 6)
AddStroke(MinBtn, Theme.Border, 1)

MakeDraggable(Header, MainFrame, {MinBtn})

-- Sidebar & Content Area
local Sidebar = CreateInstance("Frame", {
    Size = UDim2.new(0, 62, 1, -58),
    Position = UDim2.new(0, 0, 0, 58),
    BackgroundColor3 = Theme.BgGlass,
    BorderSizePixel = 0,
    ZIndex = 2
}, MainFrame)

CreateInstance("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    ZIndex = 2
}, Sidebar)

local TabListFrame = CreateInstance("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 2
}, Sidebar)
CreateInstance("UIListLayout", {
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder
}, TabListFrame)
CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 14)}, TabListFrame)

local ContentArea = CreateInstance("Frame", {
    Size = UDim2.new(1, -62, 1, -58),
    Position = UDim2.new(0, 62, 0, 58),
    BackgroundTransparency = 1,
    ZIndex = 1
}, MainFrame)

local Pages, Tabs = {}, {}
local ActiveTabBtn = nil

local function SelectTab(name)
    for tabName, page in pairs(Pages) do
        page.Visible = (tabName == name)
    end
    for tabName, btn in pairs(Tabs) do
        local isSelected = (tabName == name)
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = isSelected and Theme.Accent or Theme.BgElement,
            TextColor3 = isSelected and Color3.new(1, 1, 1) or Theme.TextDim
        }):Play()
    end
    ActiveTabBtn = Tabs[name]
end

local TabOrderCounter = 0
local function CreateTab(name, shortLabel)
    TabOrderCounter = TabOrderCounter + 1
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(0, 42, 0, 40),
        BackgroundColor3 = Theme.BgElement,
        Text = shortLabel,
        TextColor3 = Theme.TextDim,
        Font = FontBold,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = TabOrderCounter,
        ZIndex = 3
    }, TabListFrame)
    AddCorner(btn, 8)
    AddStroke(btn, Theme.Border, 1)

    btn.MouseButton1Click:Connect(function()
        SelectTab(name)
    end)
    Tabs[name] = btn

    local page = CreateInstance("Frame", {
        Name = name .. "_Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false
    }, ContentArea)

    local leftCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -14, 1, -16),
        Position = UDim2.new(0, 10, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)
    CreateInstance("UIPadding", {PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 4)}, leftCol)

    local rightCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -14, 1, -16),
        Position = UDim2.new(0.5, 4, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, rightCol)
    CreateInstance("UIPadding", {PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 4)}, rightCol)

    Pages[name] = page
    return {Left = leftCol, Right = rightCol}
end

-- ==========================================
-- 8. BUILDER KOMPONEN UI (ACCORDION, TOGGLE, SLIDER, DROPDOWN)
-- ==========================================
local ElementOrder = 0
local function NextOrder()
    ElementOrder = ElementOrder + 1
    return ElementOrder
end

local function CreateAccordion(parent, titleText, defaultOpen)
    local isOpen = defaultOpen ~= false
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgGlass,
        BorderSizePixel = 0,
        LayoutOrder = NextOrder()
    }, parent)
    AddCorner(container, 8)
    AddStroke(container, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, container)

    local headerBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 1
    }, container)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, headerBtn)

    local arrow = CreateInstance("TextLabel", {
        Size = UDim2.new(0, 28, 1, 0),
        Position = UDim2.new(1, -30, 0, 0),
        BackgroundTransparency = 1,
        Text = isOpen and "-" or "+",
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 16
    }, headerBtn)

    local content = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = isOpen,
        LayoutOrder = 2
    }, container)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, content)
    CreateInstance("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    }, content)

    headerBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        content.Visible = isOpen
        arrow.Text = isOpen and "-" or "+"
    end)

    return content
end

local ToggleResetCallbacks = {}

local function CreateToggle(parent, text, defaultState, callback, registerAsCosmetic)
    local state = defaultState == true
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder()
    }, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local switchBg = CreateInstance("Frame", {
        Size = UDim2.new(0, 34, 0, 18),
        Position = UDim2.new(1, -34, 0.5, -9),
        BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0
    }, container)
    AddCorner(switchBg, 9)

    local knob = CreateInstance("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0
    }, switchBg)
    AddCorner(knob, 7)

    local hitbox = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = ""
    }, container)

    local function setVisual(newState)
        state = newState == true
        TweenService:Create(switchBg, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        }):Play()
    end

    if registerAsCosmetic then
        table.insert(ToggleResetCallbacks, function()
            setVisual(false)
        end)
    end

    hitbox.MouseButton1Click:Connect(function()
        setVisual(not state)
        if callback then
            task.spawn(callback, state)
        end
    end)

    return setVisual
end

local function CreateSlider(parent, text, min, max, defaultVal, suffix, callback)
    local value = math.clamp(defaultVal or min, min, max)
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder()
    }, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(0.65, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local valLabel = CreateInstance("TextLabel", {
        Size = UDim2.new(0.35, 0, 0, 16),
        Position = UDim2.new(0.65, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value) .. (suffix or ""),
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right
    }, container)

    local bar = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 24),
        BackgroundColor3 = Theme.ToggleOff,
        Text = "",
        AutoButtonColor = false
    }, container)
    AddCorner(bar, 3)

    local fill = CreateInstance("Frame", {
        Size = UDim2.new((value - min) / math.max(1, max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0
    }, bar)
    AddCorner(fill, 3)

    local dragging = false
    local function updateFromX(x)
        if bar.AbsoluteSize.X <= 0 then return end
        local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLabel.Text = tostring(value) .. (suffix or "")
        if callback then task.spawn(callback, value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
    TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function CreateButton(parent, text, callback, bgColor)
    local btn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = bgColor or Theme.BgElement,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontBold,
        TextSize = 11,
        AutoButtonColor = false,
        LayoutOrder = NextOrder()
    }, parent)
    AddCorner(btn, 6)
    AddStroke(btn, Theme.Border, 1)

    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)
    return btn
end

local function CreateInput(parent, labelText, placeholder, callback)
    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder()
    }, parent)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)

    local box = CreateInstance("TextBox", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 17),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        PlaceholderText = placeholder,
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left
    }, container)
    AddCorner(box, 6)
    AddStroke(box, Theme.Border, 1)
    CreateInstance("UIPadding", {PaddingLeft = UDim.new(0, 8)}, box)

    box.FocusLost:Connect(function()
        if callback then task.spawn(callback, box.Text) end
    end)
    return box
end

local function CreateDropdown(parent, labelText, options, defaultOpt, callback)
    local isOpen = false
    local selected = defaultOpt or options[1] or ""

    local container = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder()
    }, parent)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, container)

    CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1
    }, container)

    local mainBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.BgElement,
        Text = "  " .. tostring(selected),
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = 2
    }, container)
    AddCorner(mainBtn, 6)
    AddStroke(mainBtn, Theme.Border, 1)

    local listFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.BgMain,
        Visible = false,
        LayoutOrder = 3
    }, container)
    AddCorner(listFrame, 6)
    AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    CreateInstance("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, listFrame)

    for idx, opt in ipairs(options) do
        local optBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            Text = "  " .. tostring(opt),
            TextColor3 = Theme.TextMain,
            Font = FontMain,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = idx
        }, listFrame)

        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            mainBtn.Text = "  " .. tostring(selected)
            isOpen = false
            listFrame.Visible = false
            if callback then task.spawn(callback, selected) end
        end)
    end

    mainBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        listFrame.Visible = isOpen
    end)
end

-- ==========================================
-- 9. IMPLEMENTASI TAB & FITUR
-- ==========================================

-- TAB 1: BODY & HEADS (HEADLESS, KORBLOX, DOMINUS, VALKYRIE)
local TabAvatar = CreateTab("Avatar", "AVT")
local AvLeft, AvRight = TabAvatar.Left, TabAvatar.Right

local AccBodyMods = CreateAccordion(AvLeft, "Body & Leg Mods (Client-Only)", true)
CreateToggle(AccBodyMods, "Headless Horseman (Tanpa Kepala)", false, function(state)
    ApplyHeadlessState(state)
    Notify("Headless", state and "Headless diaktifkan!" or "Kepala dipulihkan.", 2)
end, true)

CreateToggle(AccBodyMods, "Korblox Right Leg (R15 & R6)", false, function(state)
    ApplyKorbloxState(state)
    Notify("Korblox", state and "Kaki Korblox diaktifkan!" or "Kaki asli dipulihkan.", 2)
end, true)

CreateButton(AccBodyMods, "Lepas Semua Aksesoris (Tanpa Respawn)", function()
    for _, resetVis in ipairs(ToggleResetCallbacks) do
        pcall(resetVis)
    end
    ClearAllCustomAccessories(false)
end)

CreateButton(AccBodyMods, "Reset / Respawn ke Wujud Asli", function()
    for _, resetVis in ipairs(ToggleResetCallbacks) do
        pcall(resetVis)
    end
    ClearAllCustomAccessories(true)
end, Color3.fromRGB(140, 45, 45))

local AccCustomId = CreateAccordion(AvLeft, "Custom Asset ID (Rolimons / Catalog)", true)
CreateInput(AccCustomId, "Masukkan Asset ID Roblox:", "Contoh: 21070012", function(val)
    RuntimeState.CustomAssetInput = val
end)
CreateButton(AccCustomId, "Pasang Custom Asset ID", function()
    local id = tonumber(tostring(RuntimeState.CustomAssetInput):match("%d+"))
    if not id then
        Notify("Custom ID", "Masukkan angka Asset ID yang valid!", 3)
        return
    end
    local ok = SetAccessoryEquipped(id, true)
    if ok then
        Notify("Custom ID", "Asset ID " .. tostring(id) .. " berhasil dipasang!", 3)
    end
end)
CreateButton(AccCustomId, "Lepas Custom Asset ID", function()
    local id = tonumber(tostring(RuntimeState.CustomAssetInput):match("%d+"))
    if id then
        SetAccessoryEquipped(id, false)
        Notify("Custom ID", "Asset ID " .. tostring(id) .. " dilepas.", 3)
    end
end)

local AccDominus = CreateAccordion(AvRight, "Dominus Collection (Kepala)", true)
for _, item in ipairs(LARP_CATALOG.Dominus) do
    CreateToggle(AccDominus, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

local AccValks = CreateAccordion(AvRight, "Valkyrie, Fedora & Crowns", true)
for _, item in ipairs(LARP_CATALOG.CrownsAndValks) do
    CreateToggle(AccValks, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

-- TAB 2: AKSESORIS ANGGOTA TUBUH (HORNS, FACE, NECK, SHOULDERS, WINGS/BACK)
local TabGear = CreateTab("Accessories", "ACC")
local GearLeft, GearRight = TabGear.Left, TabGear.Right

local AccHorns = CreateAccordion(GearLeft, "Horns & Antlers (Tanduk)", true)
for _, item in ipairs(LARP_CATALOG.Horns) do
    CreateToggle(AccHorns, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

local AccFace = CreateAccordion(GearLeft, "Face / Wajah / Masker / Shades", true)
for _, item in ipairs(LARP_CATALOG.Face) do
    CreateToggle(AccFace, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

local AccNeck = CreateAccordion(GearRight, "Neck & Shoulders (Leher & Bahu)", true)
for _, item in ipairs(LARP_CATALOG.NeckAndShoulders) do
    CreateToggle(AccNeck, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

local AccBack = CreateAccordion(GearRight, "Wings, Capes & Back Swords (Punggung)", true)
for _, item in ipairs(LARP_CATALOG.WingsAndBack) do
    CreateToggle(AccBack, item.Name, false, function(state)
        SetAccessoryEquipped(item.Id, state)
    end, true)
end

-- TAB 3: MOVEMENT UTILITIES
local TabMove = CreateTab("Movement", "MOV")
local MoveLeft, MoveRight = TabMove.Left, TabMove.Right

local AccSpeed = CreateAccordion(MoveLeft, "WalkSpeed & JumpPower", true)
CreateToggle(AccSpeed, "Enable WalkSpeed Override", false, function(state)
    RuntimeState.WalkSpeedEnabled = state
    if not state then
        local hum = GetHumanoid()
        if hum then pcall(function() hum.WalkSpeed = 16 end) end
    end
    Notify("WalkSpeed", state and ("Speed aktif: " .. tostring(RuntimeState.WalkSpeedVal)) or "Speed kembali normal (16).", 2)
end)

CreateSlider(AccSpeed, "Atur WalkSpeed", 16, 300, 16, " spd", function(val)
    RuntimeState.WalkSpeedVal = val
    if RuntimeState.WalkSpeedEnabled then
        local hum = GetHumanoid()
        if hum then pcall(function() hum.WalkSpeed = val end) end
    end
end)

CreateToggle(AccSpeed, "Enable JumpPower Override", false, function(state)
    RuntimeState.JumpPowerEnabled = state
    if not state then
        local hum = GetHumanoid()
        if hum then
            pcall(function()
                if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
            end)
        end
    end
end)

CreateSlider(AccSpeed, "Atur JumpPower", 50, 300, 50, " jmp", function(val)
    RuntimeState.JumpPowerVal = val
end)

local AccSpecialMove = CreateAccordion(MoveRight, "NoClip & Infinite Jump", true)
CreateToggle(AccSpecialMove, "NoClip (Tembus Tembok)", false, function(state)
    SetNoClip(state)
end)

CreateToggle(AccSpecialMove, "Infinite Jump (Lompat Tanpa Batas)", false, function(state)
    RuntimeState.InfJumpEnabled = state
    Notify("Infinite Jump", state and "Aktif" or "Nonaktif", 2)
end)

-- TAB 4: POTATO PC / HP KENTANG OPTIMIZER & FPS
local TabPerf = CreateTab("Performance", "FPS")
local PerfLeft, PerfRight = TabPerf.Left, TabPerf.Right

local AccPotato = CreateAccordion(PerfLeft, "HP Kentang & FPS Optimizer", true)
CreateToggle(AccPotato, "Enable Anti-Lag / Potato Mode", false, function(state)
    ApplyPerformanceMode(state, RuntimeState.PerformanceLevel)
end)

CreateDropdown(AccPotato, "Pilih Level Optimasi Grafik", {"Low", "Balanced", "Ultra (HP Kentang)"}, "Balanced", function(level)
    RuntimeState.PerformanceLevel = level
    if RuntimeState.AntiLag then
        ApplyPerformanceMode(true, level)
    else
        Notify("Level Grafik", "Disimpan ke: " .. tostring(level) .. " (Nyalakan toggle Anti-Lag untuk menerapkan).", 3)
    end
end)

CreateToggle(AccPotato, "Delete / Disable 3D Rendering (Hemat Baterai/GPU)", false, function(state)
    RuntimeState.Disable3D = state
    local ok = pcall(function()
        RunService:Set3dRenderingEnabled(not state)
    end)
    Notify("3D Rendering", ok and (state and "3D Rendering dimatikan (Layar 3D dihentikan untuk hemat HP Kentang)." or "3D Rendering diaktifkan kembali.") or "Executor tidak mendukung Set3dRenderingEnabled.", 3)
end)

CreateDropdown(AccPotato, "Batas FPS (FPS Cap)", {"30 FPS", "60 FPS", "120 FPS", "Unlimited"}, "Unlimited", function(val)
    ApplyFPSCap(val)
end)

local AccUtility = CreateAccordion(PerfRight, "Server & Anti-AFK", true)
local StatusLabel = CreateInstance("TextLabel", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Text = "FPS: 60\nSession: 0m 0s",
    TextColor3 = Theme.TextDim,
    Font = FontMain,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = NextOrder()
}, AccUtility)

CreateToggle(AccUtility, "Anti-AFK (Cegah Disconnect 20 Menit)", false, function(state)
    SetAntiAFK(state)
end)

CreateButton(AccUtility, "Rejoin Server Saat Ini", function()
    RejoinServer()
end)

CreateButton(AccUtility, "Copy Discord PJANE HUB", function()
    pcall(function() setclipboard(DISCORD_LINK) end)
    Notify("Discord", "Link Discord disalin!", 3)
end)

-- Live FPS & Session Counter
task.spawn(function()
    while StatusLabel and StatusLabel.Parent do
        local elapsed = math.floor(os.clock() - SessionStartTime)
        local mins = math.floor(elapsed / 60)
        local secs = elapsed % 60
        StatusLabel.Text = string.format(
            "FPS Saat Ini: %d FPS\n3D Render: %s\nDurasi Sesi: %dm %ds",
            CurrentFPS,
            RuntimeState.Disable3D and "OFF (Hemat GPU)" or "ON",
            mins,
            secs
        )
        task.wait(1)
    end
end)

-- ==========================================
-- 10. TOMBOL MINIMIZE (-) & CLEANUP
-- ==========================================
local isMinimized = false
local normalSize = UDim2.fromOffset(680, 460)
local minSize = UDim2.fromOffset(260, 58)

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MinBtn.Text = "+"
        Sidebar.Visible = false
        ContentArea.Visible = false
        TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {Size = minSize}):Play()
    else
        MinBtn.Text = "-"
        Sidebar.Visible = true
        ContentArea.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {Size = normalSize}):Play()
    end
end)

SharedEnvironment.__PJANE_CLEANUP = function()
    pcall(SetNoClip, false)
    pcall(SetAntiAFK, false)
    if RuntimeState.Disable3D then
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    pcall(function() if ScreenGui then ScreenGui:Destroy() end end)
    pcall(function() if NotificationGui then NotificationGui:Destroy() end end)
end

SelectTab("Avatar")
Notify("PJANE HUB Ready", "UI berhasil dimuat! Semua fitur dalam keadaan OFF.", 4)
print("[PJANE HUB] UI Loaded Successfully (All features default OFF).")