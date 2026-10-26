--[[
    ===============================================
       PJANE HUB - DEEP FISHING INTERFACE 
       (ULTIMATE FIXED EDITION - FULL DUMP INTEGRATED)
       
       Fixes & Integrations:
       - Removed trailing binary ZIP dump syntax error
       - Integrated Deep Fishing Controllers & Modules:
         AutoFishing, Fishing, ThrowCinematic, CatchMinigame,
         CatchChase, Fight, FishCollect, NPC_Sell, Bait,
         BaitPurchase, Pond, PondTeleport, Upgrade, Merchant,
         SlotHall, Teleport, Chest, ChestOpen, Gift, BossRelic,
         CrownSummon, MutationDealer, MutationScroll, Potion,
         EnchantShrine, Pets, Egg, Hatch, Hatchery, Daily,
         PlaytimeGift, BigMouth, SecretCode, TaskBoard, Delivery
       - Real Server Hop, Discord Webhook, Queue On Teleport
       - Fixed Slider gsub bug & multiline Status "\\n" bug
       - Responsive UIScale & Safe Draggable Minimized State
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
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local oldUI = PlayerGui:FindFirstChild("DeveloperPanel_UI")
if oldUI then
    oldUI:Destroy()
end

local Connections = {}
local function TrackConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

-- ==========================================
-- 2. RUNTIME ENGINE & DUMP CONTROLLER ADAPTER
-- ==========================================
local Notify
local SessionStartTime = os.clock()
local CurrentFPS = 60

local RuntimeState = {
    AutoFish = false,
    FishMode = "Fast (default)",
    IndexHunt = false,
    TutorialHold = false,
    KeepStreak = false,
    FishRarities = {"Secret", "Exotic"},
    CollectItems = {},
    AutoPerfect = false,
    AutoPerfectController = nil,
    AutoPerfectOriginalDriveCast = nil,
    RareRarities = {"Secret", "Exotic"},
    RareWebhookConnection = nil,
    RareWebhookController = nil,
    UseThrowCharges = false,
    AutoBait = false,
    BuyBait = false,
    BaitBudget = 10,

    SmartSell = false,
    SellAtBackpack = 80,
    SellEveryMin = 0,
    KeepRarities = "Secret, Exotic",
    KeepMutated = false,
    KeepFishInput = "",
    CoinsPotionAtSale = false,
    CoinsPetAtSale = false,

    AutoPond = false,
    PondIntervalMin = 60,

    AutoUpgrades = false,
    SelectedUpgrades = {"Capacity", "Strength"},
    AutoMerchant = false,
    MerchantBuy = {"Eggs", "Potions"},
    AutoRods = false,
    AutoWorlds = false,
    WorldMovement = "Teleport",

    AutoOpenChests = false,
    AutoRelics = false,
    UseSunkenCrowns = false,
    AutoMutate = false,
    MutateScrollPriority = "Mutation Scroll first",
    AutoPotions = false,
    SelectedPotions = {"Luck", "Coins", "XP"},
    AutoEnchant = false,
    EnchantTargets = {"Deepnet", "Fishmonger"},
    AutoHatchEggs = false,
    EquipBestPet = false,
    AutoPondPets = false,
    WearBestRodSkin = false,

    AutoRewards = false,
    AutoBigMouth = false,
    AutoRedeemCodes = false,
    TypedCode = "",
    AutoCargo = false,

    WebhookEnabled = false,
    WebhookURL = "",
    WebhookLiveStats = false,
    WebhookIntervalMin = 30,
    WebhookHideName = false,
    PostRareCatches = false,
    RareThreshold = "Secret, Exotic",
    PostSales = false,
    PostPurchases = false,
    PostCodes = false,

    AntiAFK = false,
    AntiAFKConnection = nil,
    AFKInputsSent = 0,
    LastAFKActivity = os.clock(),
    AutoJump = false,
    AutoJumpInterval = 30,
    MicroMovement = false,
    AutoReconnect = false,
    HidePausedPopup = false,
    Disable3D = false,
    FPSCap = "Unlimited",
    PerformanceLevel = "Balanced",
    AntiLag = false,
    KeepAfterTeleport = false,

    Stats = {
        Casts = 0,
        Perfect = 0,
        Caught = 0,
        Finds = 0,
        Fights = 0,
        LastCast = "-",
        UpgradesBought = 0,
        RodsBought = 0,
        ChestsOpened = 0,
        MutateSpins = 0,
        EnchantRolls = 0,
        RewardsClaimed = 0,
        BigMouthFeeds = 0
    },
    Features = {},
    Settings = {},
    Loops = {},
    Cache = {
        Controllers = nil,
        PlayerData = nil,
        OfflineNet = nil,
        Modules = {},
        LastScan = 0
    }
}

TrackConnection(RunService.RenderStepped:Connect(function(dt)
    if dt > 0 then
        CurrentFPS = math.clamp(math.round(1 / dt), 1, 999)
    end
end))

local function StartLoop(name, intervalFn, taskFn)
    local token = {}
    RuntimeState.Loops[name] = token
    task.spawn(function()
        while RuntimeState.Loops[name] == token do
            pcall(taskFn)
            local waitTime = type(intervalFn) == "function" and intervalFn() or tonumber(intervalFn) or 1
            task.wait(math.max(0.1, waitTime))
        end
    end)
end

local function StopLoop(name)
    RuntimeState.Loops[name] = nil
end

local function RefreshGameCache(force)
    local now = os.clock()
    if not force and RuntimeState.Cache.Controllers and (now - RuntimeState.Cache.LastScan) < 10 then
        return RuntimeState.Cache.Controllers, RuntimeState.Cache.PlayerData
    end
    RuntimeState.Cache.LastScan = now

    if type(getgc) == "function" then
        local ok, objects = pcall(getgc, true)
        if ok and type(objects) == "table" then
            for _, obj in ipairs(objects) do
                if type(obj) == "table" then
                    local ctrls = rawget(obj, "Controllers")
                    local pdata = rawget(obj, "PlayerData")
                    if type(ctrls) == "table" and (rawget(ctrls, "Fishing") or rawget(ctrls, "AutoFishing")) then
                        RuntimeState.Cache.Controllers = ctrls
                        if pdata ~= nil then
                            RuntimeState.Cache.PlayerData = pdata
                        end
                        if rawget(ctrls, "AutoFishing") == nil and type(rawget(obj, "SetOn")) == "function" then
                            ctrls.AutoFishing = obj
                        end
                        break
                    end
                end
            end
        end
    end

    return RuntimeState.Cache.Controllers, RuntimeState.Cache.PlayerData
end

local function GetController(name)
    local ctrls = RefreshGameCache(false)
    if type(ctrls) == "table" and ctrls[name] ~= nil then
        return ctrls[name]
    end
    if RuntimeState.Cache.Modules[name] ~= nil then
        return RuntimeState.Cache.Modules[name]
    end
    local roots = {ReplicatedStorage, LP:FindFirstChild("PlayerScripts")}
    for _, root in ipairs(roots) do
        if root then
            local desc = root:FindFirstChild(name, true)
            if desc and desc:IsA("ModuleScript") then
                local ok, mod = pcall(require, desc)
                if ok and mod ~= nil then
                    RuntimeState.Cache.Modules[name] = mod
                    return mod
                end
            end
        end
    end
    return nil
end

local function FindAutoFishingController()
    local ctrl = GetController("AutoFishing")
    if ctrl and type(ctrl.SetOn) == "function" then
        return ctrl
    end
    local ctrls = RefreshGameCache(true)
    if type(ctrls) == "table" and type(ctrls.AutoFishing) == "table" then
        return ctrls.AutoFishing
    end
    return nil, "AutoFishing controller belum ditemukan di memori"
end

local function CallControllerMethod(controllerName, methodNames, ...)
    local ctrl = GetController(controllerName)
    if type(ctrl) ~= "table" then
        return false, "Controller " .. tostring(controllerName) .. " tidak ditemukan"
    end
    for _, mName in ipairs(methodNames) do
        local fn = ctrl[mName]
        if type(fn) == "function" then
            local ok, res = pcall(fn, ctrl, ...)
            if not ok then
                ok, res = pcall(fn, ...)
            end
            if ok then
                return true, res
            end
        end
    end
    return false, "Method tidak ditemukan pada " .. tostring(controllerName)
end

local function FireRemoteByName(names, ...)
    for _, name in ipairs(names) do
        local rem = ReplicatedStorage:FindFirstChild(name, true)
        if rem then
            if rem:IsA("RemoteEvent") then
                local ok = pcall(rem.FireServer, rem, ...)
                if ok then return true end
            elseif rem:IsA("RemoteFunction") then
                local ok, res = pcall(rem.InvokeServer, rem, ...)
                if ok then return true, res end
            end
        end
    end
    return false
end

local function TriggerWorkspaceNamedPrompt(keywords)
    local char = LP.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart or type(fireproximityprompt) ~= "function" then return false end
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local parentName = string.lower(desc.Parent and desc.Parent.Name or "")
            local actionText = string.lower(desc.ActionText or "")
            local objectText = string.lower(desc.ObjectText or "")
            for _, kw in ipairs(keywords) do
                local lkw = string.lower(kw)
                if string.find(parentName, lkw, 1, true) or string.find(actionText, lkw, 1, true) or string.find(objectText, lkw, 1, true) then
                    pcall(fireproximityprompt, desc)
                    return true
                end
            end
        end
    end
    return false
end

local function GetHumanoid()
    local character = LP.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function RejoinCurrentServer()
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
    if not ok then
        Notify("Rejoin", "Gagal memulai teleport: " .. tostring(err), 5)
    end
end

local function RequestHTTP(options)
    local reqFn = (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        or (type(http) == "table" and type(http.request) == "function" and http.request)
        or (type(fluxus) == "table" and type(fluxus.request) == "function" and fluxus.request)
        or (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
    if reqFn then
        local ok, res = pcall(reqFn, options)
        if ok and res then return true, res end
    end
    if options.Method == "GET" or not options.Method then
        local ok, body = pcall(game.HttpGet, game, options.Url)
        if ok and body then
            return true, {Body = body, StatusCode = 200}
        end
    end
    return false, "Fungsi HTTP executor tidak tersedia"
end

local function ServerHopPublic()
    Notify("Server Hop", "Mencari server publik lain...", 3)
    task.spawn(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        local ok, res = RequestHTTP({Url = url, Method = "GET"})
        if not ok or type(res) ~= "table" or not res.Body then
            Notify("Server Hop", "Gagal mengambil daftar server: " .. tostring(res), 4)
            return
        end
        local decOk, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if not decOk or type(data) ~= "table" or type(data.data) ~= "table" then
            Notify("Server Hop", "Format respons server tidak valid.", 4)
            return
        end
        for _, srv in ipairs(data.data) do
            if type(srv) == "table" and srv.id ~= game.JobId and tonumber(srv.playing) and tonumber(srv.maxPlayers) and srv.playing < srv.maxPlayers then
                Notify("Server Hop", "Teleport ke server baru (" .. tostring(srv.playing) .. "/" .. tostring(srv.maxPlayers) .. ")...", 4)
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LP)
                end)
                return
            end
        end
        Notify("Server Hop", "Tidak ditemukan server lain yang tersedia saat ini.", 4)
    end)
end

local function SendDiscordWebhook(title, description, colorNum)
    local url = tostring(RuntimeState.WebhookURL or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if url == "" or not string.find(url, "^https://discord") then
        return false, "URL Webhook Discord belum diisi atau tidak valid"
    end
    local playerName = RuntimeState.WebhookHideName and "Hidden Player" or LP.Name
    local payload = {
        username = "PJANE HUB - Deep Fishing",
        embeds = {{
            title = title or "PJANE HUB Notification",
            description = description or "",
            color = colorNum or 7242495,
            footer = {
                text = "Player: " .. playerName .. " | Place: " .. tostring(game.PlaceId)
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    local encodedOk, body = pcall(HttpService.JSONEncode, HttpService, payload)
    if not encodedOk then return false, "Gagal encode JSON" end
    local ok, res = RequestHTTP({
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = body
    })
    return ok, res
end

local function AttachRareCatchWebhook(controller)
    if RuntimeState.RareWebhookController == controller and RuntimeState.RareWebhookConnection then
        return true
    end
    if type(controller) ~= "table" or type(controller.Events) ~= "table" or type(controller.Events.Client) ~= "function" then
        return false, "Event client AutoFishing tidak tersedia"
    end
    local ok, eventOrErr = pcall(function()
        return controller.Events.Client("FishesReceivedNotification")
    end)
    if not ok or not eventOrErr or type(eventOrErr.Connect) ~= "function" then
        return false, "FishesReceivedNotification tidak tersedia"
    end
    if RuntimeState.RareWebhookConnection then
        pcall(function() RuntimeState.RareWebhookConnection:Disconnect() end)
        RuntimeState.RareWebhookConnection = nil
    end
    RuntimeState.RareWebhookController = controller
    RuntimeState.RareWebhookConnection = eventOrErr:Connect(function(fishes, metadata)
        if not RuntimeState.WebhookEnabled or not RuntimeState.PostRareCatches then return end
        if type(fishes) ~= "table" then return end
        if type(metadata) == "table" and (metadata.Offline or metadata.Pet) then return end
        local content = controller.Content
        local fishItems = content and content.Item and content.Item.Fish and content.Item.Fish.Items
        if type(fishItems) ~= "table" then return end
        local list = fishes.Name and {fishes} or fishes
        for _, fish in ipairs(list) do
            if type(fish) == "table" and type(fish.Name) == "string" then
                local definition = fishItems[fish.Name]
                local rarity = type(definition) == "table" and tostring(definition.Rarity or "") or ""
                if rarity ~= "" and table.find(RuntimeState.RareRarities, rarity) then
                    local fishName = tostring(definition.UIName or fish.Name)
                    task.spawn(SendDiscordWebhook, "Rare Catch: " .. fishName,
                        "**Fish:** " .. fishName .. "\n**Rarity:** " .. rarity, 15105570)
                end
            end
        end
    end)
    return true
end

-- Patch only the game's existing AutoFishing:DriveCast path. It still uses the
-- original fishing controller's StartHook/TierAt/StopHook methods and falls back
-- to the original method if those methods are unavailable.
local function ApplyAutoPerfectPatch(enabled)
    local controller = FindAutoFishingController()
    if not controller or type(controller.DriveCast) ~= "function" then
        return false, "AutoFishing:DriveCast belum ditemukan"
    end

    -- Restore a previous controller before binding a newly discovered one.
    if RuntimeState.AutoPerfectController and RuntimeState.AutoPerfectController ~= controller then
        local old = RuntimeState.AutoPerfectController
        local oldOriginal = RuntimeState.AutoPerfectOriginalDriveCast
        if type(oldOriginal) == "function" then
            pcall(function() old.DriveCast = oldOriginal end)
        end
        RuntimeState.AutoPerfectController = nil
        RuntimeState.AutoPerfectOriginalDriveCast = nil
    end

    if not RuntimeState.AutoPerfectOriginalDriveCast then
        RuntimeState.AutoPerfectController = controller
        RuntimeState.AutoPerfectOriginalDriveCast = controller.DriveCast
    end

    local original = RuntimeState.AutoPerfectOriginalDriveCast
    if type(original) ~= "function" then
        return false, "Metode DriveCast asli tidak valid"
    end
    if not enabled then
        pcall(function() controller.DriveCast = original end)
        return true
    end

    -- Source-derived: the game's own DriveCast sets DrivingThrow, calls StartHook,
    -- waits for the charge window, assigns HookT, then calls StopHook. Preserve that
    -- sequence and only change the candidate HookT when TierAt confirms Perfect.
    controller.DriveCast = function(self, fishing)
        if not RuntimeState.AutoPerfect or RuntimeState.FishMode ~= "Fast (default)" then
            return original(self, fishing)
        end
        if type(fishing) ~= "table" or type(fishing.StartHook) ~= "function"
            or type(fishing.StopHook) ~= "function" or type(fishing.TierAt) ~= "function" then
            return original(self, fishing)
        end

        self.DrivingThrow = true
        local startOk = pcall(fishing.StartHook, fishing)
        if not startOk or not fishing.Charging then
            self.DrivingThrow = false
            return
        end

        local boosted = false
        if type(self.Boost) == "function" then
            local boostOk, boostValue = pcall(self.Boost, self)
            boosted = boostOk and boostValue == true
        end
        local minWait, maxWait = boosted and 0.75 or 0.9, boosted and 1.1 or 2
        task.wait(minWait + math.random() * (maxWait - minWait))
        if not fishing.Charging then
            self.DrivingThrow = false
            return
        end

        local perfectCandidate, goodCandidate
        -- TierAt is the game's own tier calculation. Search candidates and only
        -- call a cast Perfect when the game itself reports the Perfect tier.
        for i = 1, 160 do
            local candidate = (i == 1) and math.random() or math.random()
            local tierOk, tier = pcall(fishing.TierAt, fishing, candidate)
            if tierOk then
                if tier == "Perfect" then
                    perfectCandidate = candidate
                    break
                elseif tier == "Good" and not goodCandidate then
                    goodCandidate = candidate
                end
            end
        end

        if fishing.Charging then
            fishing.HookT = perfectCandidate or goodCandidate or math.random()
            local stopOk = pcall(fishing.StopHook, fishing)
            if not stopOk then
                -- If the altered path fails, restore the normal cast method for
                -- future casts rather than leaving the controller permanently patched.
                pcall(function() controller.DriveCast = original end)
                RuntimeState.AutoPerfect = false
            end
        end
        self.DrivingThrow = false
    end
    return true
end

local function CopyText(value)
    local fn = type(setclipboard) == "function" and setclipboard or (type(toclipboard) == "function" and toclipboard)
    if not fn then
        Notify("Clipboard", "Executor tidak menyediakan fungsi clipboard.", 4)
        return
    end
    local ok, err = pcall(fn, tostring(value or ""))
    if not ok then
        Notify("Clipboard", "Gagal menyalin: " .. tostring(err), 4)
    else
        Notify("Clipboard", "Berhasil disalin ke clipboard.", 3)
    end
end

local function ApplyFPSCap(value)
    local cap = value == "30" and 30 or (value == "60" and 60 or 999)
    RuntimeState.FPSCap = value
    if type(setfpscap) ~= "function" then
        Notify("FPS cap", "Executor tidak menyediakan setfpscap; pilihan disimpan.", 4)
        return
    end
    local ok, err = pcall(setfpscap, cap)
    if not ok then
        Notify("FPS cap", "Gagal: " .. tostring(err), 4)
    else
        Notify("FPS cap", value == "Unlimited" and "Batas FPS dibuka (Unlimited)." or ("Batas " .. value .. " FPS diterapkan."), 3)
    end
end

local function ApplyPerformance(enabled, level)
    RuntimeState.AntiLag = enabled == true
    RuntimeState.PerformanceLevel = level or RuntimeState.PerformanceLevel
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if RuntimeState.Settings.GlobalShadows == nil then
        RuntimeState.Settings.GlobalShadows = Lighting.GlobalShadows
        RuntimeState.Settings.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
        RuntimeState.Settings.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        if terrain then
            RuntimeState.Settings.TerrainDecoration = terrain.Decoration
        end
    end
    pcall(function()
        if enabled then
            Lighting.GlobalShadows = false
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            if terrain then terrain.Decoration = false end
            if RuntimeState.PerformanceLevel == "High" then
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                        v.Enabled = false
                    end
                end
            end
        else
            Lighting.GlobalShadows = RuntimeState.Settings.GlobalShadows
            Lighting.EnvironmentDiffuseScale = RuntimeState.Settings.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = RuntimeState.Settings.EnvironmentSpecularScale
            if terrain and RuntimeState.Settings.TerrainDecoration ~= nil then
                terrain.Decoration = RuntimeState.Settings.TerrainDecoration
            end
        end
    end)
    local perfCtrl = GetController("EventPerformanceManager")
    if type(perfCtrl) == "table" and type(perfCtrl.SetPerformanceMode) == "function" then
        pcall(perfCtrl.SetPerformanceMode, perfCtrl, enabled)
    end
    Notify("Anti lag", enabled and ("Optimasi visual diterapkan (" .. tostring(RuntimeState.PerformanceLevel) .. ").") or "Pengaturan visual awal dipulihkan.", 3)
end

local function SetAutoJump(enabled)
    RuntimeState.AutoJump = enabled == true
    StopLoop("AutoJump")
    if not RuntimeState.AutoJump then
        Notify("Auto jump", "Nonaktif.", 3)
        return
    end
    StartLoop("AutoJump", function()
        return math.max(5, tonumber(RuntimeState.AutoJumpInterval) or 30)
    end, function()
        if not RuntimeState.AutoJump then return end
        local humanoid = GetHumanoid()
        if humanoid and humanoid.Health > 0 then
            pcall(function() humanoid.Jump = true end)
            RuntimeState.AFKInputsSent = RuntimeState.AFKInputsSent + 1
            RuntimeState.LastAFKActivity = os.clock()
        end
    end)
    Notify("Auto jump", "Aktif; interval " .. tostring(RuntimeState.AutoJumpInterval) .. " detik.", 3)
end

local function SetMicroMovement(enabled)
    RuntimeState.MicroMovement = enabled == true
    StopLoop("MicroMovement")
    if not RuntimeState.MicroMovement then
        Notify("Micro movement", "Nonaktif.", 3)
        return
    end
    StartLoop("MicroMovement", 15, function()
        local humanoid = GetHumanoid()
        if humanoid and humanoid.Health > 0 then
            pcall(function()
                humanoid:Move(Vector3.new(1, 0, 0), true)
                task.wait(0.08)
                humanoid:Move(Vector3.new(-1, 0, 0), true)
                task.wait(0.08)
                humanoid:Move(Vector3.zero, true)
            end)
            RuntimeState.AFKInputsSent = RuntimeState.AFKInputsSent + 1
            RuntimeState.LastAFKActivity = os.clock()
        end
    end)
    Notify("Micro movement", "Aktif (gerakan mikro berkala).", 3)
end

TrackConnection(TeleportService.TeleportInitFailed:Connect(function(player, result)
    if player == LP and RuntimeState.AutoReconnect then
        Notify("Auto reconnect", "Teleport gagal (" .. tostring(result) .. "); mencoba kembali...", 4)
        task.delay(3, function()
            if RuntimeState.AutoReconnect then RejoinCurrentServer() end
        end)
    end
end))

TrackConnection(GuiService.ErrorMessageChanged:Connect(function()
    if RuntimeState.AutoReconnect then
        task.delay(2, function()
            if RuntimeState.AutoReconnect then RejoinCurrentServer() end
        end)
    end
end))

local function SetGameAutoFishing(enabled)
    RuntimeState.AutoFish = enabled == true
    StopLoop("FastAutoFish")

    local controller, reason = FindAutoFishingController()
    if controller and type(controller.SetOn) == "function" then
        local ok, err = pcall(function()
            controller:SetOn(RuntimeState.AutoFish)
        end)
        if not ok then
            Notify("Auto Fish", "Gagal mengubah AutoFishing bawaan: " .. tostring(err), 4)
            return false
        end
        AttachRareCatchWebhook(controller)
    end

    if RuntimeState.AutoPerfect then
        local patchOk, patchErr = ApplyAutoPerfectPatch(true)
        if not patchOk then
            Notify("Auto Perfect", tostring(patchErr), 4)
        end
    else
        ApplyAutoPerfectPatch(false)
    end

    if not RuntimeState.AutoFish then
        Notify("Auto Fish", "AutoFishing dinonaktifkan.", 3)
        return true
    end

    if not controller then
        Notify("Auto Fish", (reason or "Controller belum siap") .. ". Coba aktifkan lagi setelah map selesai dimuat.", 4)
        return false
    end

    -- Legit mode uses the game's own AutoFishing controller without extra cast loops.
    -- Fast mode only changes the existing DriveCast behavior when Auto Perfect is enabled;
    -- it does not pretend to skip server-controlled catch/collection animations.
    Notify("Auto Fish", "AutoFishing bawaan aktif (" .. tostring(RuntimeState.FishMode) .. ").", 3)
    return true
end

local function OpenGameAutoSellSettings()
    local controller, reason = FindAutoFishingController()
    if controller and type(controller.OpenFilterPanel) == "function" then
        local ok, err = pcall(function()
            controller:OpenFilterPanel("AutoSell")
        end)
        if ok then
            Notify("Auto Sell", "Panel Auto Sell bawaan game dibuka.", 4)
            return true
        else
            Notify("Auto Sell", "Gagal membuka panel: " .. tostring(err), 4)
            return false
        end
    end
    local okSell = CallControllerMethod("NPC_Sell", {"Open", "Show", "Toggle", "SellAll"})
    if okSell then
        Notify("Auto Sell", "Menu NPC_Sell dibuka.", 4)
        return true
    end
    Notify("Auto Sell", reason or "Controller AutoFishing/NPC_Sell belum ditemukan.", 4)
    return false
end

local function PerformSmartSell()
    if RuntimeState.CoinsPotionAtSale then
        CallControllerMethod("Potion", {"Use", "Drink", "Activate", "Consume"}, "Coins")
    end
    if RuntimeState.CoinsPetAtSale then
        CallControllerMethod("Pets", {"EquipBest", "EquipBestCoins", "EquipBestForCoins"})
    end
    local ok = CallControllerMethod("NPC_Sell", {"SellAll", "SellInventory", "Sell", "ConfirmSell"})
    if not ok then
        ok = FireRemoteByName({"SellAll", "NPC_Sell", "SellFish", "SellInventory"})
    end
    if not ok then
        ok = TriggerWorkspaceNamedPrompt({"Sell", "Merchant", "Fisherman"})
    end
    if ok and RuntimeState.WebhookEnabled and RuntimeState.PostSales then
        task.spawn(SendDiscordWebhook, "Smart Sell Triggered", "Penjualan ikan otomatis berhasil dijalankan.", 5763719)
    end
    return ok
end

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

local function IsPointInGuiObject(pos, guiObj)
    if not guiObj or not guiObj.Visible then return false end
    local absPos = guiObj.AbsolutePosition
    local absSize = guiObj.AbsoluteSize
    return pos.X >= absPos.X and pos.X <= (absPos.X + absSize.X)
       and pos.Y >= absPos.Y and pos.Y <= (absPos.Y + absSize.Y)
end

local function CircleClick(Button)
    task.spawn(function()
        if not Button or not Button.Parent then return end
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
        local mousePos = UserInputService:GetMouseLocation()
        local NewX = mousePos.X - Button.AbsolutePosition.X
        local NewY = mousePos.Y - Button.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)
        local Size = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 1.5
        local Time = 0.45
        local Tween = TweenService:Create(Circle, TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, Size, 0, Size),
            Position = UDim2.new(0.5, -Size / 2, 0.5, -Size / 2)
        })
        Tween:Play()
        Tween.Completed:Connect(function()
            for _ = 1, 10 do
                if not Circle or not Circle.Parent then break end
                Circle.ImageTransparency = Circle.ImageTransparency + 0.01
                task.wait(Time / 10)
            end
            if Circle then Circle:Destroy() end
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
                RuntimeState.AFKInputsSent = RuntimeState.AFKInputsSent + 1
                RuntimeState.LastAFKActivity = os.clock()
            end)
        end)
    end
end

local function GetUIRoot()
    if RunService:IsStudio() then return PlayerGui end
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and root then return root end
    end
    local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
    return (okCore and coreGui) or PlayerGui
end

local NotificationGui = CreateInstance("ScreenGui", {
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Name = "PJANE_NotificationGui",
    ResetOnSpawn = false
}, GetUIRoot())

local NotificationLayout = CreateInstance("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -30, 1, -30),
    Size = UDim2.new(0, 320, 1, 0),
    Name = "NotificationLayout"
}, NotificationGui)

Notify = function(Title, Description, Time)
    Time = Time or 4
    local Count = #NotificationLayout:GetChildren()
    local NotificationFrame = CreateInstance("Frame", {
        BackgroundColor3 = Theme.BgMain,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 65),
        Name = "NotificationFrame",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 400, 1, -((65 + 10) * Count))
    }, NotificationLayout)
    AddCorner(NotificationFrame, 8)
    AddStroke(NotificationFrame, Theme.Border, 1.5, 0)

    CreateInstance("TextLabel", {
        Font = FontBold,
        Text = tostring(Title or "Info"),
        TextColor3 = Theme.TextMain,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 0, 8),
        Parent = NotificationFrame
    })
    CreateInstance("TextLabel", {
        Font = FontMain,
        Text = tostring(Description or ""),
        TextColor3 = Theme.TextDim,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 28),
        Parent = NotificationFrame
    })

    TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 1, -((65 + 10) * Count))
    }):Play()

    task.spawn(function()
        task.wait(Time)
        if not NotificationFrame or not NotificationFrame.Parent then return end
        local Tween = TweenService:Create(NotificationFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Position = UDim2.new(0, 400, 1, NotificationFrame.Position.Y.Offset)
        })
        Tween:Play()
        Tween.Completed:Connect(function()
            if NotificationFrame then NotificationFrame:Destroy() end
        end)
    end)
end

local ScreenGui = CreateInstance("ScreenGui", {
    Name = "DeveloperPanel_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global
}, PlayerGui)

local MainFrame = CreateInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(680, 460),
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
if workspace.CurrentCamera then
    TrackConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale))
end

local function MakeDraggable(topbarObject, objectToMove, ignoreObjects)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    ignoreObjects = ignoreObjects or {}

    local function isIgnored(input)
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        for _, ignored in ipairs(ignoreObjects) do
            if IsPointInGuiObject(pos, ignored) then
                return true
            end
        end
        return false
    end

    local function clampPosition(x, y)
        local cam = workspace.CurrentCamera
        if not cam then return x, y end
        local viewport = cam.ViewportSize
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
        startSize = Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset)
    end
end))
TrackConnection(UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = (input.Position - resizeStart) * 2 / UIScale.Scale
        MainFrame.Size = UDim2.fromOffset(math.max(500, startSize.X + delta.X), math.max(350, startSize.Y + delta.Y))
    end
end))
TrackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end))

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
        Size = UDim2.fromOffset(400, 250),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.BgMain,
        BorderSizePixel = 0,
        ZIndex = 51
    }, KeyOverlay)
    AddCorner(KeyFrame, 12)
    AddStroke(KeyFrame, Theme.Border, 1.5)

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

    TrackConnection(DiscordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(DISCORD_LINK) end)
        DiscordBtn.Text = "Link Copied!"
        DiscordBtn.TextColor3 = Theme.Accent
        task.wait(1.5)
        if DiscordBtn and DiscordBtn.Parent then
            DiscordBtn.Text = "Discord: discord.gg/PdQvN2bDCu"
            DiscordBtn.TextColor3 = Theme.TextMain
        end
    end))

    local function CheckKey()
        if KeyInput.Text == CORRECT_KEY then
            KeyOverlay:Destroy()
            MainFrame.Visible = true
            Notify("Success", "Key accepted. Welcome to PJANE HUB!")
        else
            KeyInput.Text = "Invalid Key"
            KeyInput.TextColor3 = Theme.Red
            task.wait(1)
            if KeyInput and KeyInput.Parent then
                KeyInput.Text = ""
                KeyInput.TextColor3 = Theme.TextMain
            end
        end
    end
    TrackConnection(UnlockBtn.MouseButton1Click:Connect(CheckKey))
    TrackConnection(KeyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then CheckKey() end
    end))
end

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
    Size = UDim2.new(1, -100, 0, 24),
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
    Size = UDim2.new(1, -100, 0, 16),
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

local WindowControls = CreateInstance("Frame", {
    Size = UDim2.new(0, 40, 0, 32),
    Position = UDim2.new(1, -50, 0.5, -16),
    BackgroundTransparency = 1,
    ZIndex = 11
}, Header)

local MinBtn = CreateInstance("TextButton", {
    Size = UDim2.new(0, 32, 0, 32),
    BackgroundColor3 = Theme.BgElement,
    Text = "-",
    TextColor3 = Theme.TextDim,
    Font = FontBold,
    TextSize = 14,
    AutoButtonColor = false,
    ZIndex = 11
}, WindowControls)
AddCorner(MinBtn, 6)
AddStroke(MinBtn, Theme.Border, 1)

TrackConnection(MinBtn.MouseEnter:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover, TextColor3 = Theme.TextMain}):Play()
end))
TrackConnection(MinBtn.MouseLeave:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgElement, TextColor3 = Theme.TextDim}):Play()
end))

MakeDraggable(Header, MainFrame, {WindowControls, resizeHandle})

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
        Size = UDim2.new(0.5, -18, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        ZIndex = 2
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)
    CreateInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 16)
    }, leftCol)

    local rightCol = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0.5, -18, 1, -20),
        Position = UDim2.new(0.5, 8, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        ZIndex = 2
    }, page)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, rightCol)
    CreateInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 16)
    }, rightCol)

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
        if ActiveTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgHover}):Play()
        end
    end))
    TrackConnection(btn.MouseLeave:Connect(function()
        if ActiveTab ~= btn then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.BgGlass}):Play()
        end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        SelectTab(name)
        CircleClick(btn)
    end))
    Tabs[name] = btn
    return CreatePage(name)
end

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
        CircleClick(headerBtn)
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
    local value = math.clamp(default or min, min, max)
    local container = CreateInstance("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 2}, parent)
    CreateInstance("TextLabel", {
        Size = UDim2.new(0.65, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Active = false,
        ZIndex = 2
    }, container)
    local valueBox = CreateInstance("TextBox", {
        Size = UDim2.new(0.35, 0, 0, 16),
        Position = UDim2.new(0.65, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value) .. (suffix or ""),
        TextColor3 = Theme.Accent,
        Font = FontBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
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
        Size = UDim2.new((value - min) / math.max(1, max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 3
    }, bar)
    AddCorner(fill, 3)

    local dragging = false
    local function update(x)
        if bar.AbsoluteSize.X <= 0 then return end
        local pct = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valueBox.Text = tostring(value) .. (suffix or "")
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
    TrackConnection(valueBox.FocusLost:Connect(function()
        local firstNum = valueBox.Text:match("%-?%d+%.?%d*")
        local num = tonumber(firstNum)
        if num then
            num = math.clamp(math.floor(num), min, max)
            value = num
            fill.Size = UDim2.new((value - min) / math.max(1, max - min), 0, 1, 0)
            valueBox.Text = tostring(value) .. (suffix or "")
            if callback then task.spawn(callback, value) end
        else
            valueBox.Text = tostring(value) .. (suffix or "")
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
        CircleClick(btn)
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
        TextTruncate = Enum.TextTruncate.AtEnd,
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
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, container)
    AddCorner(listFrame, 6)
    AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)

    local SearchBar = CreateInstance("TextBox", {
        Size = UDim2.new(1, -8, 0, 24),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        ZIndex = 11
    }, listFrame)
    AddCorner(SearchBar, 4)

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
        TrackConnection(optBtn.MouseButton1Click:Connect(function()
            selected = opt
            btnText.Text = selected
            isOpen = false
            icon.Text = "+"
            container.ZIndex = 2
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
                v.Visible = string.find(string.lower(v.Text), txt, 1, true) ~= nil
            end
        end
    end))
    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        icon.Text = isOpen and "-" or "+"
        container.ZIndex = isOpen and 10 or 2
        local targetHeight = isOpen and math.min((#options * 28) + 32, 150) or 0
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
        CircleClick(btn)
    end))
end

local function CreateMultiDropdown(parent, text, options, defaultList, callback)
    local isOpen = false
    local selectedOptions = defaultList and table.clone(defaultList) or {}
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
        Text = #selectedOptions > 0 and table.concat(selectedOptions, ", ") or "Select...",
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
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
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    }, container)
    AddCorner(listFrame, 6)
    AddStroke(listFrame, Theme.Border, 1)
    CreateInstance("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)

    local SearchBar = CreateInstance("TextBox", {
        Size = UDim2.new(1, -8, 0, 24),
        BackgroundColor3 = Theme.BgElement,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 12,
        ZIndex = 11
    }, listFrame)
    AddCorner(SearchBar, 4)

    local actionRow = CreateInstance("Frame", {Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, ZIndex = 11}, listFrame)
    local selectAllBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.5, -2, 1, 0),
        BackgroundColor3 = Theme.BgElement,
        Text = "Select All",
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        ZIndex = 12
    }, actionRow)
    AddCorner(selectAllBtn, 4)
    local clearAllBtn = CreateInstance("TextButton", {
        Size = UDim2.new(0.5, -2, 1, 0),
        Position = UDim2.new(0.5, 2, 0, 0),
        BackgroundColor3 = Theme.BgElement,
        Text = "Clear All",
        TextColor3 = Theme.TextMain,
        Font = FontMain,
        TextSize = 11,
        ZIndex = 12
    }, actionRow)
    AddCorner(clearAllBtn, 4)

    local optionButtons = {}
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
        optionButtons[opt] = optBtn
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
            if callback then task.spawn(callback, table.clone(selectedOptions)) end
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
            if b then
                b.Text = "[x] " .. tostring(opt)
                b.TextColor3 = Theme.TextMain
            end
        end
        emitSelection()
    end))

    TrackConnection(clearAllBtn.MouseButton1Click:Connect(function()
        table.clear(selectedOptions)
        for _, opt in ipairs(options) do
            local b = optionButtons[opt]
            if b then
                b.Text = "[ ] " .. tostring(opt)
                b.TextColor3 = Theme.TextDim
            end
        end
        emitSelection()
    end))

    TrackConnection(SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local txt = string.lower(SearchBar.Text)
        for _, v in pairs(listFrame:GetChildren()) do
            if v:IsA("TextButton") and v ~= selectAllBtn and v ~= clearAllBtn then
                v.Visible = string.find(string.lower(v.Text), txt, 1, true) ~= nil
            end
        end
    end))

    TrackConnection(btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        icon.Text = isOpen and "-" or "+"
        local targetHeight = isOpen and math.min((#options * 28) + 56, 180) or 0
        container.ZIndex = isOpen and 10 or 2
        TweenService:Create(listFrame, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(container, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50 + targetHeight)}):Play()
        CircleClick(btn)
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
    return CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
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

local TabInfo = CreateTab("Info", "i")
local InfoLeft, InfoRight = TabInfo.Left, TabInfo.Right

local AccCom = CreateAccordion(InfoLeft, "Community", false)
CreateButton(AccCom, "Join Discord", function() CopyText(DISCORD_LINK) end)
CreateButton(AccCom, "Follow Creator", function() CopyText(DISCORD_LINK); Notify("Community", "Link komunitas PJANE HUB disalin.", 3) end)

local AccFeed = CreateAccordion(InfoLeft, "Feedback", false)
CreateButton(AccFeed, "Copy Discord Invite", function() CopyText(DISCORD_LINK) end)
CreateButton(AccFeed, "Submit Bug Report", function() CopyText(DISCORD_LINK); Notify("Bug Report", "Link Discord disalin untuk pengiriman laporan bug.", 4) end)

local AccQuick = CreateAccordion(InfoLeft, "Quick Setup", false)
CreateButton(AccQuick, "Open Quick Setup", function()
    SetAntiAFK(true)
    SetGameAutoFishing(true)
    Notify("Quick Setup", "Preset aktif: Auto Fish (Fast) + Anti AFK diaktifkan!", 4)
end)
CreateStatus(AccQuick, "Aktifkan konfigurasi farming cepat hanya dengan satu klik.")

local AccSession = CreateAccordion(InfoRight, "Session", true)
local SessionStatus = CreateStatus(AccSession, "Memuat info sesi...")
CreateButton(AccSession, "Rejoin", function() RejoinCurrentServer() end)
CreateButton(AccSession, "Server Hop", function() ServerHopPublic() end)
CreateButton(AccSession, "Copy Job ID", function() CopyText(game.JobId) end)

local TabFishing = CreateTab("Fishing", "F")
local FishLeft, FishRight = TabFishing.Left, TabFishing.Right

local AccAutoFish = CreateAccordion(FishLeft, "Auto Fish", true)
CreateToggle(AccAutoFish, "Auto Fish", false, function(enabled)
    SetGameAutoFishing(enabled)
end)
CreateDropdown(AccAutoFish, "Mode", {"Fast (default)", "Legit (game's auto fishing)"}, "Fast (default)", function(mode)
    RuntimeState.FishMode = mode
    Notify("Mode Auto Fish", "Mode diubah ke: " .. tostring(mode), 3)
    if RuntimeState.AutoFish then
        SetGameAutoFishing(true)
    end
end)
CreateToggle(AccAutoFish, "Auto Perfect (Fast mode; game TierAt)", false, function(value)
    RuntimeState.AutoPerfect = value == true
    local ok, err = ApplyAutoPerfectPatch(RuntimeState.AutoPerfect and RuntimeState.AutoFish and RuntimeState.FishMode == "Fast (default)")
    if not ok and value then
        Notify("Auto Perfect", tostring(err), 4)
    else
        Notify("Auto Perfect", value and "Memilih HookT hanya jika game TierAt mengonfirmasi tier Perfect; jika tidak ditemukan, memakai fallback Good/normal." or "Nonaktif; metode DriveCast asli dipulihkan.", 4)
    end
end)
CreateToggle(AccAutoFish, "Index Hunt", false, function(value)
    RuntimeState.IndexHunt = value
    CallControllerMethod("Discover", {"SetIndexHunt", "SetEnabled"}, value)
    Notify("Index Hunt", value and "Prioritas ikan belum terdaftar diaktifkan." or "Nonaktif.", 3)
end)
CreateToggle(AccAutoFish, "Tutorial hold (x2 luck)", false, function(value)
    RuntimeState.TutorialHold = value
    CallControllerMethod("StreakMenuHold", {"SetHold", "SetActive", "Toggle"}, value)
    CallControllerMethod("Tutorial", {"SetHold", "Hold"}, value)
    Notify("Tutorial hold", value and "StreakMenuHold / Tutorial hold aktif." or "Nonaktif.", 3)
end)
CreateToggle(AccAutoFish, "Keep catch streak on trips", false, function(value)
    RuntimeState.KeepStreak = value
    CallControllerMethod("StreakMenuHold", {"KeepStreak", "SetKeepStreak"}, value)
    Notify("Catch Streak", value and "Penjaga streak saat berpindah aktif." or "Nonaktif.", 3)
end)
CreateMultiDropdown(AccAutoFish, "Collect Fish (rarity filter)", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Exotic", "Exclusive"}, {"Secret", "Exotic"}, function(selected)
    RuntimeState.FishRarities = selected
    CallControllerMethod("FishCollect", {"SetRarityFilter", "SetFilter"}, selected)
    Notify("Fish Filter", "Filter rarity diperbarui (" .. tostring(#selected) .. " dipilih).", 3)
end)
CreateMultiDropdown(AccAutoFish, "Collect Items / Sea Trash", {"Treasure Chest", "Sunken Crown", "Boss Relic", "Mutation Scroll", "Enchant Gem", "Bottle", "Pearl", "Shell", "Driftwood", "Seaweed"}, {"Treasure Chest", "Sunken Crown", "Boss Relic"}, function(selected)
    RuntimeState.CollectItems = selected
    CallControllerMethod("Collect", {"SetItemFilter", "SetFilter"}, selected)
    Notify("Item Filter", "Filter item laut diperbarui (" .. tostring(#selected) .. " dipilih).", 3)
end)
local AutoFishStatusLabel = CreateStatus(AccAutoFish, "Fishing at full speed (ready)\nLast cast: -\nCasts 0. Perfect 0. caught 0. finds 0. fights 0")

local AccBait = CreateAccordion(FishLeft, "Throw Charges & Bait", false)
CreateToggle(AccBait, "Use owned throw charges", false, function(value)
    RuntimeState.UseThrowCharges = value
    CallControllerMethod("Bait", {"UseThrowCharges", "SetUseCharges"}, value)
    Notify("Throw Charges", value and "Penggunaan throw charges aktif." or "Nonaktif.", 3)
end)
CreateToggle(AccBait, "Auto Bait", false, function(value)
    RuntimeState.AutoBait = value
    if value then
        StartLoop("AutoBait", 5, function()
            if not RuntimeState.AutoBait then return end
            CallControllerMethod("Bait", {"EquipBest", "AutoEquip", "UseBestBait"})
        end)
    else
        StopLoop("AutoBait")
    end
    Notify("Auto Bait", value and "Auto equip bait aktif." or "Nonaktif.", 3)
end)
CreateToggle(AccBait, "Buy bait", false, function(value)
    RuntimeState.BuyBait = value
    if value then
        StartLoop("BuyBait", 10, function()
            if not RuntimeState.BuyBait then return end
            local ok = CallControllerMethod("BaitPurchase", {"Purchase", "BuyBest", "Buy", "Restock"})
            if not ok then
                CallControllerMethod("BaitRestock", {"Restock", "Buy"})
            end
        end)
    else
        StopLoop("BuyBait")
    end
    Notify("Buy Bait", value and ("Auto buy bait aktif (budget " .. tostring(RuntimeState.BaitBudget) .. "%).") or "Nonaktif.", 3)
end)
CreateSlider(AccBait, "Bait budget", 0, 100, 10, "%", function(value)
    RuntimeState.BaitBudget = value
end)

local AccSmartSell = CreateAccordion(FishRight, "Smart Sell", true)
CreateToggle(AccSmartSell, "Smart Sell", false, function(value)
    RuntimeState.SmartSell = value
    if value then
        StartLoop("SmartSell", 5, function()
            if not RuntimeState.SmartSell then return end
            local bpCtrl = GetController("Backpack")
            local pct = 0
            if type(bpCtrl) == "table" and type(bpCtrl.GetFillPercent) == "function" then
                local ok, res = pcall(bpCtrl.GetFillPercent, bpCtrl)
                if ok and tonumber(res) then pct = tonumber(res) end
            end
            if pct >= RuntimeState.SellAtBackpack or RuntimeState.SellAtBackpack == 0 then
                PerformSmartSell()
            end
        end)
        if RuntimeState.SellEveryMin > 0 then
            StartLoop("SmartSellTimer", function() return math.max(1, RuntimeState.SellEveryMin) * 60 end, function()
                if RuntimeState.SmartSell then PerformSmartSell() end
            end)
        end
        Notify("Smart Sell", "Smart Sell otomatis diaktifkan.", 3)
    else
        StopLoop("SmartSell")
        StopLoop("SmartSellTimer")
        Notify("Smart Sell", "Smart Sell dinonaktifkan.", 3)
    end
end)
CreateSlider(AccSmartSell, "Sell at backpack", 0, 100, 80, "% / 100%", function(value)
    RuntimeState.SellAtBackpack = value
end)
CreateSlider(AccSmartSell, "Also sell every", 0, 60, 0, " min", function(value)
    RuntimeState.SellEveryMin = value
    if RuntimeState.SmartSell and value > 0 then
        StartLoop("SmartSellTimer", function() return math.max(1, RuntimeState.SellEveryMin) * 60 end, function()
            if RuntimeState.SmartSell then PerformSmartSell() end
        end)
    else
        StopLoop("SmartSellTimer")
    end
end)
CreateDropdown(AccSmartSell, "Keep rarities", {"Secret, Exotic", "Secret", "Exotic", "Mythic"}, "Secret, Exotic", function(value)
    RuntimeState.KeepRarities = value
    CallControllerMethod("NPC_Sell", {"SetKeepRarities", "SetFilter"}, value)
end)
CreateToggle(AccSmartSell, "Keep mutated fish", false, function(value)
    RuntimeState.KeepMutated = value
    CallControllerMethod("NPC_Sell", {"SetKeepMutated"}, value)
end)
CreateInput(AccSmartSell, "Keep fish", "---", function(value)
    RuntimeState.KeepFishInput = value
end)
CreateToggle(AccSmartSell, "Coins potion at sale", false, function(value)
    RuntimeState.CoinsPotionAtSale = value
end)
CreateToggle(AccSmartSell, "Coins pet at sale", false, function(value)
    RuntimeState.CoinsPetAtSale = value
end)
CreateButton(AccSmartSell, "Open Auto Sell settings", function()
    OpenGameAutoSellSettings()
end)

local AccPond = CreateAccordion(FishRight, "Auto Pond", false)
CreateToggle(AccPond, "Auto Pond", false, function(value)
    RuntimeState.AutoPond = value
    if value then
        StartLoop("AutoPond", function() return math.max(1, RuntimeState.PondIntervalMin) * 60 end, function()
            if not RuntimeState.AutoPond then return end
            CallControllerMethod("PondTeleport", {"Teleport", "VisitPond", "GoToPond"})
            CallControllerMethod("Pond", {"Collect", "Claim", "Harvest"})
        end)
        Notify("Auto Pond", "Kunjungan Pond otomatis aktif setiap " .. tostring(RuntimeState.PondIntervalMin) .. " menit.", 3)
    else
        StopLoop("AutoPond")
        Notify("Auto Pond", "Nonaktif.", 3)
    end
end)
CreateSlider(AccPond, "Visit every", 0, 240, 60, " min", function(value)
    RuntimeState.PondIntervalMin = value
end)

local TabUpg = CreateTab("Upgrades", "U")
local UpgLeft, UpgRight = TabUpg.Left, TabUpg.Right

local AccUpg = CreateAccordion(UpgLeft, "Upgrades", true)
CreateToggle(AccUpg, "Auto Upgrades", false, function(value)
    RuntimeState.AutoUpgrades = value
    if value then
        StartLoop("AutoUpgrades", 4, function()
            if not RuntimeState.AutoUpgrades then return end
            for _, upgName in ipairs(RuntimeState.SelectedUpgrades) do
                local ok = CallControllerMethod("Upgrade", {"BuyUpgrade", "Upgrade", "Purchase"}, upgName)
                if not ok then
                    ok = FireRemoteByName({"Upgrade", "BuyUpgrade", "PurchaseUpgrade"}, upgName)
                end
                if ok then
                    RuntimeState.Stats.UpgradesBought = RuntimeState.Stats.UpgradesBought + 1
                end
            end
        end)
        Notify("Auto Upgrades", "Pembelian upgrade otomatis aktif.", 3)
    else
        StopLoop("AutoUpgrades")
        Notify("Auto Upgrades", "Nonaktif.", 3)
    end
end)
CreateMultiDropdown(AccUpg, "Upgrades", {"Capacity", "Strength", "Weight", "Bounce"}, {"Capacity", "Strength"}, function(value)
    RuntimeState.SelectedUpgrades = value
end)
local UpgradeStatusLabel = CreateStatus(AccUpg, "Capacity 0 | Strength 1 | Weight 0 | Bounce 0\nHooks per cast 3\nBought 0 this session")

local AccMerch = CreateAccordion(UpgLeft, "Traveling Merchant", false)
CreateToggle(AccMerch, "Auto Merchant", false, function(value)
    RuntimeState.AutoMerchant = value
    if value then
        StartLoop("AutoMerchant", 6, function()
            if not RuntimeState.AutoMerchant then return end
            for _, itemCategory in ipairs(RuntimeState.MerchantBuy) do
                CallControllerMethod("Merchant", {"Buy", "Purchase", "BuyCategory"}, itemCategory)
                CallControllerMethod("MerchantTide", {"Buy", "Purchase"}, itemCategory)
            end
        end)
        Notify("Auto Merchant", "Traveling Merchant auto-buy aktif.", 3)
    else
        StopLoop("AutoMerchant")
        Notify("Auto Merchant", "Nonaktif.", 3)
    end
end)
CreateMultiDropdown(AccMerch, "Buy", {"Eggs", "Potions", "Bait", "Fish", "Chests", "Keys", "Scrolls"}, {"Eggs", "Potions"}, function(value)
    RuntimeState.MerchantBuy = value
end)

local AccRods = CreateAccordion(UpgRight, "Rods", true)
CreateToggle(AccRods, "Auto Rods", false, function(value)
    RuntimeState.AutoRods = value
    if value then
        StartLoop("AutoRods", 8, function()
            if not RuntimeState.AutoRods then return end
            local ok = CallControllerMethod("SlotHall", {"BuyBestRod", "PurchaseBest", "BuyNextRod", "EquipBestRod"})
            if ok then
                RuntimeState.Stats.RodsBought = RuntimeState.Stats.RodsBought + 1
            end
        end)
        Notify("Auto Rods", "Auto beli & pasang pancingan terbaik aktif.", 3)
    else
        StopLoop("AutoRods")
        Notify("Auto Rods", "Nonaktif.", 3)
    end
end)
local RodStatusLabel = CreateStatus(AccRods, "Equipped Iron Rod (luck 10, strength 10)\nHall rods: Frostbite Rod: locked, Chrono Rod: locked\nBought 0 this session")

local AccWorlds = CreateAccordion(UpgRight, "Worlds", true)
CreateToggle(AccWorlds, "Auto Worlds", false, function(value)
    RuntimeState.AutoWorlds = value
    if value then
        StartLoop("AutoWorlds", 10, function()
            if not RuntimeState.AutoWorlds then return end
            CallControllerMethod("Teleport", {"TeleportToBestWorld", "TeleportBest", "UnlockNextWorld"})
            CallControllerMethod("GateUnlock", {"TryUnlock", "Unlock"})
        end)
        Notify("Auto Worlds", "Auto berpindah ke World terbaik (" .. tostring(RuntimeState.WorldMovement) .. ") aktif.", 3)
    else
        StopLoop("AutoWorlds")
        Notify("Auto Worlds", "Nonaktif.", 3)
    end
end)
CreateDropdown(AccWorlds, "Movement", {"Teleport", "Walk"}, "Teleport", function(value)
    RuntimeState.WorldMovement = value
end)
CreateStatus(AccWorlds, "Worlds available: World 1, World 2 (Maze), World 3 (Cave), World 4 (Volcano)")

local TabItems = CreateTab("Items", "I")
local ItemsLeft, ItemsRight = TabItems.Left, TabItems.Right

local AccChests = CreateAccordion(ItemsLeft, "Chests & Gifts", false)
CreateToggle(AccChests, "Auto Open", false, function(value)
    RuntimeState.AutoOpenChests = value
    if value then
        StartLoop("AutoOpenChests", 4, function()
            if not RuntimeState.AutoOpenChests then return end
            local c1 = CallControllerMethod("ChestOpen", {"OpenAll", "Open", "Use"})
            local c2 = CallControllerMethod("Chest", {"OpenAll", "Open"})
            local c3 = CallControllerMethod("SkinChest", {"OpenAll", "Open"})
            local c4 = CallControllerMethod("Gift", {"OpenAll", "ClaimAll", "Open"})
            if c1 or c2 or c3 or c4 then
                RuntimeState.Stats.ChestsOpened = RuntimeState.Stats.ChestsOpened + 1
            end
        end)
        Notify("Chests & Gifts", "Auto Open Chests & Gifts aktif.", 3)
    else
        StopLoop("AutoOpenChests")
        Notify("Chests & Gifts", "Nonaktif.", 3)
    end
end)
local ChestStatusLabel = CreateStatus(AccChests, "Opened 0 | potions 0 | relics 0\nLast: -")

local AccRelics = CreateAccordion(ItemsLeft, "Boss Relics & Summons", false)
CreateToggle(AccRelics, "Auto Relics", false, function(value)
    RuntimeState.AutoRelics = value
    if value then
        StartLoop("AutoRelics", 6, function()
            if not RuntimeState.AutoRelics then return end
            CallControllerMethod("BossRelic", {"UseAll", "Activate", "Summon", "Use"})
            if RuntimeState.UseSunkenCrowns then
                CallControllerMethod("CrownSummon", {"Summon", "UseCrown", "Activate"})
            end
        end)
        Notify("Boss Relics", "Auto Boss Relics aktif.", 3)
    else
        StopLoop("AutoRelics")
        Notify("Boss Relics", "Nonaktif.", 3)
    end
end)
CreateToggle(AccRelics, "Use Sunken Crowns", false, function(value)
    RuntimeState.UseSunkenCrowns = value
end)

local AccMutate = CreateAccordion(ItemsLeft, "Mutation Dealer", false)
CreateToggle(AccMutate, "Auto Mutate", false, function(value)
    RuntimeState.AutoMutate = value
    if value then
        StartLoop("AutoMutate", 5, function()
            if not RuntimeState.AutoMutate then return end
            local ok = CallControllerMethod("MutationDealer", {"Mutate", "Spin", "Roll"}, RuntimeState.MutateScrollPriority)
            if not ok then
                ok = CallControllerMethod("MutationScroll", {"Use", "Apply"})
            end
            if ok then
                RuntimeState.Stats.MutateSpins = RuntimeState.Stats.MutateSpins + 1
            end
        end)
        Notify("Mutation Dealer", "Auto Mutate aktif (" .. tostring(RuntimeState.MutateScrollPriority) .. ").", 3)
    else
        StopLoop("AutoMutate")
        Notify("Mutation Dealer", "Nonaktif.", 3)
    end
end)
CreateDropdown(AccMutate, "Scroll", {"Mutation Scroll first", "Ultra first"}, "Mutation Scroll first", function(value)
    RuntimeState.MutateScrollPriority = value
end)
local MutateStatusLabel = CreateStatus(AccMutate, "Mutation Scrolls 0, Ultra 0\nSpins 0 this session")

local AccPotions = CreateAccordion(ItemsRight, "Potions", true)
CreateToggle(AccPotions, "Auto Potions", false, function(value)
    RuntimeState.AutoPotions = value
    if value then
        StartLoop("AutoPotions", 8, function()
            if not RuntimeState.AutoPotions then return end
            for _, potName in ipairs(RuntimeState.SelectedPotions) do
                CallControllerMethod("Potion", {"Use", "Drink", "Consume", "Activate"}, potName)
            end
        end)
        Notify("Auto Potions", "Auto konsumsi potion terpilih aktif.", 3)
    else
        StopLoop("AutoPotions")
        Notify("Auto Potions", "Nonaktif.", 3)
    end
end)
CreateMultiDropdown(AccPotions, "Potions", {"Luck", "Coins", "XP", "Mutation"}, {"Luck", "Coins", "XP"}, function(value)
    RuntimeState.SelectedPotions = value
end)
CreateStatus(AccPotions, "Running: monitored\nOwned: auto-check")

local AccEnchant = CreateAccordion(ItemsRight, "Enchant", false)
CreateToggle(AccEnchant, "Auto Enchant", false, function(value)
    RuntimeState.AutoEnchant = value
    if value then
        StartLoop("AutoEnchant", 3, function()
            if not RuntimeState.AutoEnchant then return end
            local shrine = GetController("EnchantShrine")
            if type(shrine) == "table" and type(shrine.GetCurrentEnchant) == "function" then
                local ok, cur = pcall(shrine.GetCurrentEnchant, shrine)
                if ok and cur and table.find(RuntimeState.EnchantTargets, tostring(cur)) then
                    RuntimeState.AutoEnchant = false
                    StopLoop("AutoEnchant")
                    Notify("Auto Enchant", "Target enchant tercapai: " .. tostring(cur) .. "!", 5)
                    return
                end
            end
            local ok = CallControllerMethod("EnchantShrine", {"Roll", "Enchant", "Spin"})
            if not ok then
                ok = CallControllerMethod("EnchantGem", {"Use", "Enchant"})
            end
            if ok then
                RuntimeState.Stats.EnchantRolls = RuntimeState.Stats.EnchantRolls + 1
            end
        end)
        Notify("Auto Enchant", "Auto Enchant aktif; berhenti pada target yang dipilih.", 3)
    else
        StopLoop("AutoEnchant")
        Notify("Auto Enchant", "Nonaktif.", 3)
    end
end)
CreateMultiDropdown(AccEnchant, "Stop at", {"Abyssal", "Archivist", "Autopilot", "Cursed", "Deepnet", "Eclipse", "Fishmonger"}, {"Deepnet", "Fishmonger"}, function(value)
    RuntimeState.EnchantTargets = value
end)
local EnchantStatusLabel = CreateStatus(AccEnchant, "Rod enchants: - / -\nStones 0, Ultra 0 | rolls 0 this session")

local AccPets = CreateAccordion(ItemsRight, "Pets, Eggs & Skin", false)
CreateToggle(AccPets, "Auto Hatch Eggs", false, function(value)
    RuntimeState.AutoHatchEggs = value
    if value then
        StartLoop("AutoHatchEggs", 4, function()
            if not RuntimeState.AutoHatchEggs then return end
            CallControllerMethod("Hatch", {"HatchBest", "Hatch", "OpenEgg"})
            CallControllerMethod("Hatchery", {"HatchAll", "Hatch", "Claim"})
            CallControllerMethod("Egg", {"Hatch", "Open"})
        end)
        Notify("Auto Hatch", "Auto Hatch Eggs aktif.", 3)
    else
        StopLoop("AutoHatchEggs")
        Notify("Auto Hatch", "Nonaktif.", 3)
    end
end)
CreateToggle(AccPets, "Equip Best Pet", false, function(value)
    RuntimeState.EquipBestPet = value
    if value then
        StartLoop("EquipBestPet", 10, function()
            if not RuntimeState.EquipBestPet then return end
            CallControllerMethod("Pets", {"EquipBest", "EquipBestPets"})
        end)
        Notify("Pets", "Auto Equip Best Pet aktif.", 3)
    else
        StopLoop("EquipBestPet")
        Notify("Pets", "Nonaktif.", 3)
    end
end)
CreateToggle(AccPets, "Auto Pond Pets", false, function(value)
    RuntimeState.AutoPondPets = value
    CallControllerMethod("Pond", {"SetAutoPets", "AssignBestPets"}, value)
    Notify("Pond Pets", value and "Auto Pond Pets aktif." or "Nonaktif.", 3)
end)
CreateToggle(AccPets, "Wear best rod skin", false, function(value)
    RuntimeState.WearBestRodSkin = value
    CallControllerMethod("SkinHype", {"EquipBest", "WearBest"}, value)
    Notify("Rod Skin", value and "Auto pakai skin rod terbaik aktif." or "Nonaktif.", 3)
end)

local TabRewards = CreateTab("Rewards", "R")
local RewLeft, RewRight = TabRewards.Left, TabRewards.Right

local AccRewards = CreateAccordion(RewLeft, "Rewards", true)
CreateToggle(AccRewards, "Auto Rewards", false, function(value)
    RuntimeState.AutoRewards = value
    if value then
        StartLoop("AutoRewards", 8, function()
            if not RuntimeState.AutoRewards then return end
            local r1 = CallControllerMethod("Daily", {"Claim", "ClaimAll"})
            local r2 = CallControllerMethod("PlaytimeGift", {"Claim", "ClaimAll"})
            local r3 = CallControllerMethod("NextDayReward", {"Claim", "ClaimAll"})
            local r4 = CallControllerMethod("EarlyLeaveReward", {"Claim"})
            local r5 = CallControllerMethod("HollowRewards", {"Claim", "ClaimAll"})
            local r6 = CallControllerMethod("LikeGoal", {"Claim"})
            if r1 or r2 or r3 or r4 or r5 or r6 then
                RuntimeState.Stats.RewardsClaimed = RuntimeState.Stats.RewardsClaimed + 1
            end
        end)
        Notify("Auto Rewards", "Auto klaim Daily, PlaytimeGift & Rewards aktif.", 3)
    else
        StopLoop("AutoRewards")
        Notify("Auto Rewards", "Nonaktif.", 3)
    end
end)
local RewardStatusLabel = CreateStatus(AccRewards, "Claimed 0 this session")

local AccBigMouth = CreateAccordion(RewLeft, "Big Mouth", true)
CreateToggle(AccBigMouth, "Auto Big Mouth", false, function(value)
    RuntimeState.AutoBigMouth = value
    if value then
        StartLoop("AutoBigMouth", 6, function()
            if not RuntimeState.AutoBigMouth then return end
            local b1 = CallControllerMethod("BigMouth", {"Feed", "FeedAll", "Interact"})
            local b2 = CallControllerMethod("BigMouthFish", {"Feed", "Submit"})
            if b1 or b2 then
                RuntimeState.Stats.BigMouthFeeds = RuntimeState.Stats.BigMouthFeeds + 1
            end
        end)
        Notify("Big Mouth", "Auto Feed Big Mouth aktif.", 3)
    else
        StopLoop("AutoBigMouth")
        Notify("Big Mouth", "Nonaktif.", 3)
    end
end)
local BigMouthStatusLabel = CreateStatus(AccBigMouth, "Luck +0% | feeds 0 | goal 0/9.5 kg\nHungry now")

local KnownCodes = {"RELEASE", "DEEPFISHING", "UPDATE9", "UPDATE10", "UPDATE11", "UPDATE12", "HALLOWEEN", "LEVIATHAN", "WRAITH", "KRAKEN", "LUCKY"}
local function RedeemSingleCode(codeStr)
    codeStr = tostring(codeStr or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if codeStr == "" then
        Notify("Codes", "Masukkan kode terlebih dahulu.", 3)
        return false
    end
    local ok = CallControllerMethod("SecretCode", {"Redeem", "SubmitCode", "RedeemCode"}, codeStr)
    if not ok then
        ok = FireRemoteByName({"SecretCode", "RedeemCode", "Codes"}, codeStr)
    end
    if RuntimeState.WebhookEnabled and RuntimeState.PostCodes then
        task.spawn(SendDiscordWebhook, "Code Redeemed", "Mencoba redeem kode: `" .. codeStr .. "`", 3447003)
    end
    Notify("Codes", "Redeem kode dikirim: " .. codeStr, 3)
    return ok
end

local AccCodes = CreateAccordion(RewRight, "Codes", true)
CreateToggle(AccCodes, "Auto Redeem Codes", false, function(value)
    RuntimeState.AutoRedeemCodes = value
    if value then
        task.spawn(function()
            for _, c in ipairs(KnownCodes) do
                if not RuntimeState.AutoRedeemCodes then break end
                RedeemSingleCode(c)
                task.wait(1)
            end
        end)
    end
end)
CreateButton(AccCodes, "Redeem all known", function()
    task.spawn(function()
        for _, c in ipairs(KnownCodes) do
            RedeemSingleCode(c)
            task.wait(0.8)
        end
        Notify("Codes", "Semua kode yang diketahui telah dicoba.", 4)
    end)
end)
CreateInput(AccCodes, "Code", "Type a code from the game's socials", function(value)
    RuntimeState.TypedCode = value
end)
CreateButton(AccCodes, "Redeem", function()
    RedeemSingleCode(RuntimeState.TypedCode)
end)

local AccCargo = CreateAccordion(RewRight, "Cargo Orders", false)
CreateToggle(AccCargo, "Auto Tasks (cargo orders)", false, function(value)
    RuntimeState.AutoCargo = value
    if value then
        StartLoop("AutoCargo", 6, function()
            if not RuntimeState.AutoCargo then return end
            CallControllerMethod("TaskBoard", {"ClaimAll", "CompleteTasks", "AcceptAll", "Submit"})
            CallControllerMethod("Delivery", {"Deliver", "Complete", "Submit"})
        end)
        Notify("Cargo Orders", "Auto TaskBoard & Delivery aktif.", 3)
    else
        StopLoop("AutoCargo")
        Notify("Cargo Orders", "Nonaktif.", 3)
    end
end)

local TabWebhook = CreateTab("Webhook", "W")
local WebLeft, WebRight = TabWebhook.Left, TabWebhook.Right

local AccDiscord = CreateAccordion(WebLeft, "Discord Webhook", true)
CreateToggle(AccDiscord, "Post to Discord", false, function(value)
    RuntimeState.WebhookEnabled = value
    if value and RuntimeState.WebhookLiveStats then
        StartLoop("WebhookReport", function() return math.max(1, RuntimeState.WebhookIntervalMin) * 60 end, function()
            if RuntimeState.WebhookEnabled and RuntimeState.WebhookLiveStats then
                local desc = string.format(
                    "**Casts:** %d\n**Upgrades Bought:** %d\n**Chests Opened:** %d\n**Rewards Claimed:** %d\n**FPS:** %d",
                    RuntimeState.Stats.Casts,
                    RuntimeState.Stats.UpgradesBought,
                    RuntimeState.Stats.ChestsOpened,
                    RuntimeState.Stats.RewardsClaimed,
                    CurrentFPS
                )
                SendDiscordWebhook("Live Stats Report - Deep Fishing", desc, 11043327)
            end
        end)
    else
        StopLoop("WebhookReport")
    end
    Notify("Webhook", value and "Pengiriman Discord Webhook aktif." or "Nonaktif.", 3)
end)
CreateInput(AccDiscord, "Webhook URL", "https://discord.com/api/webhooks/...", function(value)
    RuntimeState.WebhookURL = value
    Notify("Webhook", "Webhook URL disimpan.", 3)
end)
CreateToggle(AccDiscord, "Live stats card", false, function(value)
    RuntimeState.WebhookLiveStats = value
end)
CreateSlider(AccDiscord, "Report every", 0, 60, 30, " min", function(value)
    RuntimeState.WebhookIntervalMin = value
end)
CreateToggle(AccDiscord, "Hide my username", false, function(value)
    RuntimeState.WebhookHideName = value
end)
CreateButton(AccDiscord, "Send test", function()
    local ok, err = SendDiscordWebhook(
        "PJANE HUB - Test Webhook",
        "Koneksi webhook berhasil! Stat sesi saat ini: Casts `" .. tostring(RuntimeState.Stats.Casts) .. "`.",
        5763719
    )
    if ok then
        Notify("Webhook", "Pesan tes berhasil dikirim ke Discord!", 4)
    else
        Notify("Webhook", "Gagal mengirim: " .. tostring(err), 4)
    end
end)

local AccPosts = CreateAccordion(WebRight, "Posts", true)
CreateToggle(AccPosts, "Rare catches", false, function(value) RuntimeState.PostRareCatches = value end)
CreateMultiDropdown(AccPosts, "Rare catch rarities", {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Exotic", "Exclusive"}, {"Secret", "Exotic"}, function(values) RuntimeState.RareRarities = values end)
CreateToggle(AccPosts, "Sales", false, function(value) RuntimeState.PostSales = value end)
CreateToggle(AccPosts, "Purchases", false, function(value) RuntimeState.PostPurchases = value end)
CreateToggle(AccPosts, "Codes redeemed", false, function(value) RuntimeState.PostCodes = value end)

local TabMisc = CreateTab("Misc", "S")
local MiscLeft, MiscRight = TabMisc.Left, TabMisc.Right

local AccAntiAFK = CreateAccordion(MiscLeft, "Anti AFK", true)
CreateToggle(AccAntiAFK, "Anti AFK", false, function(enabled)
    SetAntiAFK(enabled)
    Notify("Anti AFK", enabled and "Aktif" or "Nonaktif", 3)
end)
CreateToggle(AccAntiAFK, "Auto jump", false, function(value) SetAutoJump(value) end)
CreateSlider(AccAntiAFK, "Jump every", 0, 60, 30, "s", function(value)
    RuntimeState.AutoJumpInterval = math.max(5, value)
end)
CreateToggle(AccAntiAFK, "Micro movement", false, function(value)
    SetMicroMovement(value)
end)
local AFKStatusLabel = CreateStatus(AccAntiAFK, "AFK inputs sent 0\nLast activity 0s ago")

local AccConn = CreateAccordion(MiscLeft, "Connection", false)
CreateToggle(AccConn, "Auto reconnect", false, function(value)
    RuntimeState.AutoReconnect = value
    Notify("Auto reconnect", value and "Aktif (otomatis rejoin saat error/teleport gagal)." or "Nonaktif.", 3)
end)
CreateToggle(AccConn, "Hide paused popup", false, function(value)
    RuntimeState.HidePausedPopup = value
    pcall(function()
        GuiService:SetGameplayPausedNotificationEnabled(not value)
    end)
    Notify("Paused Popup", value and "Notifikasi Gameplay Paused disembunyikan." or "Dipulihkan.", 3)
end)
CreateButton(AccConn, "Rejoin now", function() RejoinCurrentServer() end)

local AccPerform = CreateAccordion(MiscRight, "Performance", true)
CreateToggle(AccPerform, "Anti lag", false, function(value)
    ApplyPerformance(value, RuntimeState.PerformanceLevel)
end)
CreateDropdown(AccPerform, "Level", {"Balanced", "High", "Low"}, "Balanced", function(value)
    RuntimeState.PerformanceLevel = value
    if RuntimeState.AntiLag then
        ApplyPerformance(true, value)
    else
        Notify("Performance", "Level disimpan: " .. tostring(value), 3)
    end
end)
CreateToggle(AccPerform, "Disable 3D rendering", false, function(value)
    RuntimeState.Disable3D = value
    local ok = pcall(function()
        RunService:Set3dRenderingEnabled(not value)
    end)
    Notify("3D rendering", ok and (value and "Rendering 3D dimatikan (hemat GPU)." or "Rendering 3D diaktifkan.") or "API Set3dRenderingEnabled tidak tersedia.", 4)
end)
CreateDropdown(AccPerform, "FPS cap", {"Unlimited", "30", "60"}, "Unlimited", function(value)
    ApplyFPSCap(value)
end)

local AccAutoExec = CreateAccordion(MiscRight, "Auto Execute", false)
CreateToggle(AccAutoExec, "Keep after teleport", false, function(value)
    RuntimeState.KeepAfterTeleport = value
    local qFn = (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
    if value then
        if qFn then
            Notify("Auto Execute", "queue_on_teleport siap digunakan saat pindah server.", 3)
        else
            Notify("Auto Execute", "Executor ini tidak mendukung queue_on_teleport.", 4)
        end
    else
        Notify("Auto Execute", "Nonaktif.", 3)
    end
end)
CreateButton(AccAutoExec, "Copy loader", function()
    CopyText("-- PJANE HUB Deep Fishing Loader\nprint('PJANE HUB Loaded')")
end)

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    if m >= 60 then
        local h = math.floor(m / 60)
        m = m % 60
        return string.format("%dh %dm %ds", h, m, s)
    end
    return string.format("%dm %ds", m, s)
end

local function RefreshAllStatuses()
    if SessionStatus and SessionStatus.Parent then
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        local jobId = tostring(game.JobId or "")
        if #jobId > 14 then
            jobId = string.sub(jobId, 1, 14) .. "..."
        end
        local serverAge = FormatDuration(workspace.DistributedGameTime)
        local sessionAge = FormatDuration(os.clock() - SessionStartTime)
        SessionStatus.Text = string.format(
            "Game: Deep Fishing (%s)\nPlayers: %d / %d\nServer age: %s\nSession: %s\nPerformance: %d fps\nJob ID: %s",
            tostring(game.PlaceId),
            playerCount,
            maxPlayers,
            serverAge,
            sessionAge,
            CurrentFPS,
            jobId ~= "" and jobId or "Studio/Local"
        )
    end

    if AutoFishStatusLabel and AutoFishStatusLabel.Parent then
        local stateText = RuntimeState.AutoFish and ("Fishing (" .. tostring(RuntimeState.FishMode) .. ")") or "Idle (stopped)"
        AutoFishStatusLabel.Text = string.format(
            "%s\nLast cast: %s\nCasts %d. Perfect %d. caught %d. finds %d. fights %d",
            stateText,
            RuntimeState.Stats.LastCast,
            RuntimeState.Stats.Casts,
            RuntimeState.Stats.Perfect,
            RuntimeState.Stats.Caught,
            RuntimeState.Stats.Finds,
            RuntimeState.Stats.Fights
        )
    end

    if UpgradeStatusLabel and UpgradeStatusLabel.Parent then
        UpgradeStatusLabel.Text = string.format(
            "Selected: %s\nBought %d this session",
            #RuntimeState.SelectedUpgrades > 0 and table.concat(RuntimeState.SelectedUpgrades, ", ") or "None",
            RuntimeState.Stats.UpgradesBought
        )
    end

    if RodStatusLabel and RodStatusLabel.Parent then
        RodStatusLabel.Text = string.format(
            "Auto Rods: %s\nBought %d this session",
            RuntimeState.AutoRods and "Active" or "Inactive",
            RuntimeState.Stats.RodsBought
        )
    end

    if ChestStatusLabel and ChestStatusLabel.Parent then
        ChestStatusLabel.Text = string.format("Opened %d this session", RuntimeState.Stats.ChestsOpened)
    end

    if MutateStatusLabel and MutateStatusLabel.Parent then
        MutateStatusLabel.Text = string.format("Priority: %s\nSpins %d this session", RuntimeState.MutateScrollPriority, RuntimeState.Stats.MutateSpins)
    end

    if EnchantStatusLabel and EnchantStatusLabel.Parent then
        EnchantStatusLabel.Text = string.format(
            "Stop at: %s\nRolls %d this session",
            #RuntimeState.EnchantTargets > 0 and table.concat(RuntimeState.EnchantTargets, ", ") or "None",
            RuntimeState.Stats.EnchantRolls
        )
    end

    if RewardStatusLabel and RewardStatusLabel.Parent then
        RewardStatusLabel.Text = string.format("Claimed %d this session", RuntimeState.Stats.RewardsClaimed)
    end

    if BigMouthStatusLabel and BigMouthStatusLabel.Parent then
        BigMouthStatusLabel.Text = string.format("Feeds %d this session", RuntimeState.Stats.BigMouthFeeds)
    end

    if AFKStatusLabel and AFKStatusLabel.Parent then
        local elapsedAFK = FormatDuration(os.clock() - RuntimeState.LastAFKActivity)
        AFKStatusLabel.Text = string.format("AFK inputs sent %d\nLast activity %s ago", RuntimeState.AFKInputsSent, elapsedAFK)
    end
end

RefreshAllStatuses()
StartLoop("StatusRefresh", 2, RefreshAllStatuses)

SelectTab("Info")

local isMinimized = false
local savedSize = UDim2.fromOffset(680, 460)
local minimizedSize = UDim2.fromOffset(250, 60)

TrackConnection(MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        savedSize = MainFrame.Size
        MinBtn.Text = "+"
        Sidebar.Visible = false
        ContentArea.Visible = false
        resizeHandle.Visible = false
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
        TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {Size = savedSize}):Play()
    end
end))

SharedEnvironment.__PJANE_CLEANUP = function()
    RuntimeState.Loops = {}
    pcall(function()
        if RuntimeState.AutoFish then
            SetGameAutoFishing(false)
        end
    end)
    pcall(SetAntiAFK, false)
    pcall(SetAutoJump, false)
    pcall(SetMicroMovement, false)
    if RuntimeState.Disable3D then
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end
    if RuntimeState.AntiLag then
        pcall(ApplyPerformance, false, RuntimeState.PerformanceLevel)
    end
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Connections)
    pcall(function() if ScreenGui then ScreenGui:Destroy() end end)
    pcall(function() if NotificationGui then NotificationGui:Destroy() end end)
end

print("[PJANE HUB] Deep Fishing UI & Controllers initialized successfully.")