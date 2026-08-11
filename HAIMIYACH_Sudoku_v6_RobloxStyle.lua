-- ============================================================
-- SUDOKU TOOLS - SOURCE-FIXED / ANDROID
--
-- Based on the uploaded game source:
--   PlacedBoards -> BoardId / OwnerUserId
--   BoardStateHandlerClient.currentBoardId
--   SurfaceGui -> Frame -> TextButton -> ClueValue
--   Cell attributes: Row / Col / Id
--   Numpad Fill uses:
--       SelectCell:FireServer(cell)
--       PlaceNumber:FireServer(cell, number)
--
-- This version avoids relying only on OwnerUserId.
-- It first tries the game's currentBoardId, then OwnerUserId,
-- then a safe board-structure fallback.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
math.randomseed(math.floor(os.clock() * 1000000) % 2147483647)

-- ============================================================
-- CLEAN OLD VERSION
-- ============================================================

pcall(function()
    local old = PlayerGui:FindFirstChild("SudokuTools")
    if old then
        old:Destroy()
    end
end)

-- ============================================================
-- NOTIFICATION
-- ============================================================

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "Sudoku"),
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

-- ============================================================
-- GAME MODULE ACCESS
-- ============================================================

local BoardState
local RemoteHandler

local function findModuleByName(root, moduleName)
    if not root then
        return nil
    end

    local direct = root:FindFirstChild(moduleName)
    if direct and direct:IsA("ModuleScript") then
        return direct
    end

    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == moduleName and obj:IsA("ModuleScript") then
            return obj
        end
    end

    return nil
end

local function loadGameModules()
    -- The source requires BoardStateHandlerClient as a child
    -- of the main ClientHandler LocalScript.
    pcall(function()
        local module = findModuleByName(
            LocalPlayer:FindFirstChild("PlayerScripts"),
            "BoardStateHandlerClient"
        )

        if module then
            local ok, result = pcall(require, module)
            if ok and type(result) == "table" then
                BoardState = result
            end
        end
    end)

    -- The source uses ReplicatedStorage.Remotes.RemoteHandler.
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local module = remotes and remotes:FindFirstChild("RemoteHandler")

        if module and module:IsA("ModuleScript") then
            local ok, result = pcall(require, module)
            if ok and type(result) == "table" then
                RemoteHandler = result
            end
        end
    end)
end

loadGameModules()

-- ============================================================
-- BOARD HELPERS
-- ============================================================

local function getCurrentBoardId()
    if not BoardState then
        loadGameModules()
    end

    if not BoardState then
        return nil
    end

    -- Exact public function from the uploaded source.
    local ok, id = pcall(function()
        if type(BoardState.get) == "function" then
            return BoardState.get()
        end

        return BoardState.currentBoardId
    end)

    if ok and id ~= nil then
        return id
    end

    return nil
end

local function getPlacedBoards()
    return workspace:FindFirstChild("PlacedBoards")
end

local function hasBoardStructure(board)
    if not board then
        return false
    end

    local surface = board:FindFirstChild("SurfaceGui")
    if not surface then
        return false
    end

    local frame = surface:FindFirstChild("Frame")
    if not frame then
        return false
    end

    local template = frame:FindFirstChild("ClueTemplate")
    if not template then
        return false
    end

    return true
end

local function findBoardById(boardId)
    local placedBoards = getPlacedBoards()
    if not placedBoards or boardId == nil then
        return nil
    end

    local wanted = tostring(boardId)

    for _, board in ipairs(placedBoards:GetChildren()) do
        local id = board:GetAttribute("BoardId")

        if id ~= nil and tostring(id) == wanted then
            return board
        end
    end

    return nil
end

local function findBoardByOwner()
    local placedBoards = getPlacedBoards()
    if not placedBoards then
        return nil
    end

    for _, board in ipairs(placedBoards:GetChildren()) do
        local owner = board:GetAttribute("OwnerUserId")

        if owner ~= nil and tonumber(owner) == LocalPlayer.UserId then
            return board
        end
    end

    return nil
end

local function findBoardByStructure()
    local placedBoards = getPlacedBoards()
    if not placedBoards then
        return nil
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    local bestBoard
    local bestDistance = math.huge

    for _, board in ipairs(placedBoards:GetChildren()) do
        if hasBoardStructure(board) then
            if root and board:IsA("Model") then
                local ok, pivot = pcall(function()
                    return board:GetPivot()
                end)

                if ok then
                    local distance = (pivot.Position - root.Position).Magnitude

                    if distance < bestDistance then
                        bestDistance = distance
                        bestBoard = board
                    end
                end
            elseif not bestBoard then
                bestBoard = board
            end
        end
    end

    return bestBoard
end

-- Main board resolver:
-- 1) exact currentBoardId from the game's BoardStateHandlerClient
-- 2) OwnerUserId
-- 3) nearest valid Sudoku board
local function getMyBoard()
    local boardId = getCurrentBoardId()

    if boardId ~= nil then
        local board = findBoardById(boardId)

        if board and hasBoardStructure(board) then
            return board
        end
    end

    local ownerBoard = findBoardByOwner()

    if ownerBoard and hasBoardStructure(ownerBoard) then
        return ownerBoard
    end

    return findBoardByStructure()
end

local function getBoardFrame(board)
    if not board then
        return nil
    end

    local surface = board:FindFirstChild("SurfaceGui")
    if not surface then
        return nil
    end

    return surface:FindFirstChild("Frame")
end

-- ============================================================
-- SUDOKU
-- ============================================================

local Sudoku = {}

function Sudoku.isValid(board, row, col, number)
    for i = 1, 9 do
        if board[row][i] == number then
            return false
        end

        if board[i][col] == number then
            return false
        end
    end

    local boxRow = math.floor((row - 1) / 3) * 3 + 1
    local boxCol = math.floor((col - 1) / 3) * 3 + 1

    for r = boxRow, boxRow + 2 do
        for c = boxCol, boxCol + 2 do
            if board[r][c] == number then
                return false
            end
        end
    end

    return true
end

function Sudoku.solve(board)
    for row = 1, 9 do
        for col = 1, 9 do
            if board[row][col] == 0 then
                for number = 1, 9 do
                    if Sudoku.isValid(board, row, col, number) then
                        board[row][col] = number

                        if Sudoku.solve(board) then
                            return true
                        end

                        board[row][col] = 0
                    end
                end

                return false
            end
        end
    end

    return true
end

local function newBoard()
    local board = {}

    for row = 1, 9 do
        board[row] = {}

        for col = 1, 9 do
            board[row][col] = 0
        end
    end

    return board
end

local function cloneBoard(board)
    local result = newBoard()

    for row = 1, 9 do
        for col = 1, 9 do
            result[row][col] = board[row][col]
        end
    end

    return result
end

-- ============================================================
-- READ CELLS
-- ============================================================

local function getCells(board)
    local frame = getBoardFrame(board)
    local cells = {}

    if not frame then
        return cells
    end

    for _, cell in ipairs(frame:GetChildren()) do
        if cell:IsA("TextButton") and cell.Name ~= "ClueTemplate" then
            local clue = cell:FindFirstChild("ClueValue")

            if clue and clue:IsA("TextLabel") then
                local row = tonumber(cell:GetAttribute("Row"))
                local col = tonumber(cell:GetAttribute("Col"))

                if row and col
                    and row >= 1 and row <= 9
                    and col >= 1 and col <= 9 then

                    cells[row .. ":" .. col] = cell
                end
            end
        end
    end

    return cells
end

local function readBoard(board)
    local result = newBoard()
    local cells = getCells(board)

    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]

            if cell then
                local clue = cell:FindFirstChild("ClueValue")

                if clue then
                    local number = tonumber(tostring(clue.Text or ""))

                    if number and number >= 1 and number <= 9 then
                        result[row][col] = number
                    end
                end
            end
        end
    end

    return result
end

local function solveBoard(board)
    local source = readBoard(board)
    local solution = cloneBoard(source)

    if Sudoku.solve(solution) then
        return source, solution
    end

    return source, nil
end

-- ============================================================
-- SNAPSHOT
-- ============================================================

local snapshots = {}

local function saveSnapshot(board)
    if board then
        snapshots[board] = cloneBoard(readBoard(board))
    end
end

-- ============================================================
-- ESP
-- ============================================================

local espObjects = {}
local espActive = false

local function clearESP()
    for _, object in ipairs(espObjects) do
        pcall(function()
            object:Destroy()
        end)
    end

    table.clear(espObjects)

    -- Remove leftovers if the script was executed more than once.
    pcall(function()
        local placedBoards = getPlacedBoards()
        if not placedBoards then return end

        for _, board in ipairs(placedBoards:GetChildren()) do
            local frame = getBoardFrame(board)

            if frame then
                for _, cell in ipairs(frame:GetChildren()) do
                    local old = cell:FindFirstChild("SudokuESP")

                    if old then
                        old:Destroy()
                    end
                end
            end
        end
    end)
end

local function addESP(cell, number)
    local old = cell:FindFirstChild("SudokuESP")

    if old then
        old:Destroy()
    end

    local label = Instance.new("TextLabel")
    label.Name = "SudokuESP"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = tostring(number)
    label.TextColor3 = Color3.fromRGB(255, 200, 50)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.15
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.ZIndex = 100
    label.Active = false
    label.Parent = cell

    table.insert(espObjects, label)
end

local function showESP(board, solution)
    clearESP()

    local cells = getCells(board)
    local count = 0

    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]

            if cell then
                local clue = cell:FindFirstChild("ClueValue")

                if clue and tostring(clue.Text) == "" then
                    local value = solution[row][col]

                    if value then
                        addESP(cell, value)
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

-- ============================================================
-- LOCAL FILL
-- ============================================================

local function fillLocal(board, solution)
    local cells = getCells(board)
    local count = 0

    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]

            if cell then
                local clue = cell:FindFirstChild("ClueValue")

                if clue and tostring(clue.Text) == "" then
                    clue.Text = tostring(solution[row][col])
                    clue.TextColor3 = Color3.fromRGB(100, 200, 255)
                    count = count + 1
                end
            end
        end
    end

    return count
end

-- ============================================================
-- SERVER FILL
--
-- This mirrors the uploaded game's own Numpad flow:
--   SelectCell:FireServer(cell)
--   PlaceNumber:FireServer(cell, number)
-- ============================================================

local function getRemote(name)
    if not RemoteHandler then
        loadGameModules()
    end

    if not RemoteHandler then
        return nil
    end

    local ok, remote = pcall(function()
        return RemoteHandler.get(
            RemoteHandler.Events.Reliable[name]
        )
    end)

    if ok and remote then
        return remote
    end

    return nil
end

local solveModes = {
    NOOB = {label = "NOOB", min = 0.90, max = 1.80, pauseChance = 0.16},
    NORMAL = {label = "NORMAL", min = 0.35, max = 0.85, pauseChance = 0.10},
    PRO = {label = "PRO", min = 0.12, max = 0.32, pauseChance = 0.06},
}

local selectedSolveMode = "NORMAL"
local selectedDelayMode = "MODE DEFAULT"
local customMinDelay = 1.0
local customMaxDelay = 3.0
local readCustomDelay = function() end

local function getSolveTiming()
    if selectedDelayMode == "CUSTOM" then
        local minDelay = math.max(0.05, tonumber(customMinDelay) or 1.0)
        local maxDelay = math.max(minDelay, tonumber(customMaxDelay) or 3.0)
        return {
            label = "CUSTOM",
            min = minDelay,
            max = maxDelay,
            pauseChance = 0
        }
    end

    return solveModes[selectedSolveMode] or solveModes.NORMAL
end

local function shuffleList(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function serverFill(board, solution)
    local cells = getCells(board)
    local selectCellRemote = getRemote("SelectCell")
    local placeNumberRemote = getRemote("PlaceNumber")

    if not placeNumberRemote then
        return false, 0, "PlaceNumber remote tidak dapat diakses."
    end

    if selectedDelayMode == "CUSTOM" then
        readCustomDelay()
    end
    local timing = getSolveTiming()
    local pending = {}

    -- Randomized cell order instead of row 1 -> row 9.
    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]
            if cell then
                local clue = cell:FindFirstChild("ClueValue")
                if clue and tostring(clue.Text) == "" then
                    table.insert(pending, {cell = cell, row = row, col = col})
                end
            end
        end
    end

    shuffleList(pending)

    local count = 0
    for _, entry in ipairs(pending) do
        if not board.Parent then
            return false, count, "Board berubah saat proses berlangsung."
        end

        local number = solution[entry.row][entry.col]
        if number then
            if selectCellRemote then
                pcall(function()
                    selectCellRemote:FireServer(entry.cell)
                end)
            end

            local ok = pcall(function()
                placeNumberRemote:FireServer(entry.cell, number)
            end)

            if ok then
                count = count + 1
            end

            -- Random interval inside the selected mode.
            task.wait(timing.min + math.random() * (timing.max - timing.min))

            -- Occasional extra pause to avoid a perfectly uniform rhythm.
            if math.random() < timing.pauseChance then
                task.wait(timing.min * 1.5 + math.random() * timing.min * 2)
            end
        end
    end

    return true, count
end

-- ============================================================
-- TARGET ANSWER ESP + TELEPORT
-- ============================================================

local currentBoard
local selectedUserId = nil
local targetAnswerESPActive = false
local targetESPObjects = {}
local targetListVisible = false

local function getBoardOwnerId(board)
    if not board then return nil end
    local id = board:GetAttribute("OwnerUserId")
    return id and tonumber(id) or nil
end

local function getBoardCFrame(board)
    if not board then return nil end
    local ok, cf = pcall(function()
        if board:IsA("Model") then
            return board:GetPivot()
        elseif board:IsA("BasePart") then
            return board.CFrame
        end
        return nil
    end)
    return ok and cf or nil
end

local function getBoardList()
    local result = {}
    local folder = getPlacedBoards()
    if not folder then return result end

    for _, board in ipairs(folder:GetChildren()) do
        if hasBoardStructure(board) then
            local ownerId = getBoardOwnerId(board)
            if ownerId then
                local player = Players:GetPlayerByUserId(ownerId)
                if player then
                    table.insert(result, {
                        board = board,
                        userId = ownerId,
                        player = player,
                        name = player.Name,
                        display = player.DisplayName
                    })
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return result
end

local function findBoardForUser(userId)
    local folder = getPlacedBoards()
    if not folder then return nil end
    local wanted = tonumber(userId)
    for _, board in ipairs(folder:GetChildren()) do
        if hasBoardStructure(board) and getBoardOwnerId(board) == wanted then
            return board
        end
    end
    return nil
end

local function getSelectedBoard()
    if not selectedUserId then return nil end
    return findBoardForUser(selectedUserId)
end

-- Own-board refresh. This is deliberately lightweight and is also called
-- automatically when the game creates/finishes/fails a board.
local function refreshBoard(showNotification)
    local oldBoard = currentBoard
    currentBoard = getMyBoard()

    if oldBoard ~= currentBoard then
        clearESP()
        espActive = false
    end

    if currentBoard and not snapshots[currentBoard] then
        saveSnapshot(currentBoard)
    end

    if showNotification ~= false then
        notify(
            "My Board",
            currentBoard and "Board berhasil diperbarui." or "Board belum ditemukan.",
            2
        )
    end

    return currentBoard
end

-- ============================================================
-- TARGET ANSWER ESP
-- ============================================================

local function clearTargetAnswerESP()
    for _, obj in ipairs(targetESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(targetESPObjects)
end

local function addTargetAnswerESP(cell, number)
    -- Use the same cell-overlay method as the working own-board ESP.
    -- BillboardGui can resolve to an unexpected world position when parented to a UI cell.
    local old = cell:FindFirstChild("SudokuTargetAnswerESP")
    if old then old:Destroy() end

    local label = Instance.new("TextLabel")
    label.Name = "SudokuTargetAnswerESP"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = tostring(number)
    label.TextColor3 = Color3.fromRGB(255, 205, 60)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.15
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.ZIndex = 100
    label.Active = false
    label.Parent = cell

    table.insert(targetESPObjects, label)
end

local function showTargetAnswerESP(board)
    clearTargetAnswerESP()
    if not board then return 0 end

    local _, solution = solveBoard(board)
    if not solution then return 0 end

    local frame = getBoardFrame(board)
    if not frame then return 0 end

    local count = 0
    for _, cell in ipairs(frame:GetChildren()) do
        if cell:IsA("TextButton") and cell.Name ~= "ClueTemplate" then
            local clue = cell:FindFirstChild("ClueValue")
            local row = tonumber(cell:GetAttribute("Row"))
            local col = tonumber(cell:GetAttribute("Col"))

            if clue and row and col and tostring(clue.Text) == "" then
                local value = solution[row] and solution[row][col]
                if value then
                    addTargetAnswerESP(cell, value)
                    count += 1
                end
            end
        end
    end
    return count
end

local function refreshTargetAnswerESP()
    if not targetAnswerESPActive then
        clearTargetAnswerESP()
        return
    end

    local board = getSelectedBoard()
    if not board then
        clearTargetAnswerESP()
        return
    end

    local count = showTargetAnswerESP(board)
    if count == 0 then
        -- Keep the toggle ON; the target may simply have a completed board.
        clearTargetAnswerESP()
    end
end

local function getTargetDisplayName()
    local player = selectedUserId and Players:GetPlayerByUserId(selectedUserId)
    if not player then return "PILIH PLAYER" end
    return player.DisplayName .. "  •  @" .. player.Name
end

-- ============================================================
-- TELEPORT
-- ============================================================

local function teleportToBoard(board, label)
    if not board then
        notify("Teleport", "Board target tidak ditemukan.", 3)
        return false
    end

    local cf = getBoardCFrame(board)
    if not cf then
        notify("Teleport", "Posisi board tidak dapat dibaca.", 3)
        return false
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        notify("Teleport", "Character belum siap.", 3)
        return false
    end

    local target = cf * CFrame.new(0, 5, 0)
    root.CFrame = target
    task.delay(0.15, function()
        pcall(function()
            local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if r then r.CFrame = target end
        end)
    end)

    notify("Teleport", "Ke " .. tostring(label or "board") .. ".", 2)
    return true
end

-- ============================================================
-- AUTOMATIC BOARD REFRESH
-- Game source exposes GameWon, GameOver, CleanUpBoard and BoardInitialising.
-- These are used instead of guessing from UI text.
-- ============================================================

local function connectReliable(name, callback)
    local remote = getRemote(name)
    if not remote then return end
    pcall(function()
        remote.OnClientEvent:Connect(callback)
    end)
end

connectReliable("BoardInitialising", function(ownerUserId)
    if tonumber(ownerUserId) ~= LocalPlayer.UserId then return end
    clearESP()
    espActive = false
    task.spawn(function()
        for _ = 1, 12 do
            task.wait(0.25)
            if refreshBoard(false) then break end
        end
    end)
end)

connectReliable("GameWon", function(boardId, ownerUserId)
    if tonumber(ownerUserId) ~= LocalPlayer.UserId then return end
    clearESP()
    espActive = false
    task.delay(0.8, function()
        refreshBoard(false)
    end)
end)

connectReliable("GameOver", function(boardId, ownerUserId)
    if tonumber(ownerUserId) ~= LocalPlayer.UserId then return end
    clearESP()
    espActive = false
    task.delay(0.8, function()
        refreshBoard(false)
    end)
end)

connectReliable("CleanUpBoard", function(boardId)
    local board = currentBoard
    if board and tostring(board:GetAttribute("BoardId")) == tostring(boardId) then
        clearESP()
        espActive = false
        currentBoard = nil
        task.delay(0.4, function()
            refreshBoard(false)
        end)
    end
end)

connectReliable("CleanUpLeavingPlayerBoardOnClient", function(boardId)
    task.delay(0.2, function()
        if selectedUserId then
            refreshTargetAnswerESP()
        end
        if not currentBoard or tostring(currentBoard:GetAttribute("BoardId")) == tostring(boardId) then
            refreshBoard(false)
        end
    end)
end)

-- ============================================================

-- ============================================================
-- GUI - HAIMIYACH / COMPACT ROBLOX-STYLE MOBILE UI
-- Inspired by common Roblox script-library patterns:
-- compact window, section/group labels, bordered controls,
-- dropdowns inside the scroll area, and mobile-safe scrolling.
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SudokuTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
local guiWidth = math.clamp(math.floor(viewport.X * 0.40), 225, 270)
local guiHeight = math.clamp(math.floor(viewport.Y * 0.56), 315, 390)

local Window = Instance.new("Frame")
Window.Name = "HAIMIYACH"
Window.Size = UDim2.fromOffset(guiWidth, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui

local wc = Instance.new("UICorner")
wc.CornerRadius = UDim.new(0, 10)
wc.Parent = Window

local ws = Instance.new("UIStroke")
ws.Color = Color3.fromRGB(66, 68, 77)
ws.Thickness = 1
ws.Transparency = 0.2
ws.Parent = Window

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = Window

local Brand = Instance.new("TextLabel")
Brand.Size = UDim2.new(1, -90, 1, 0)
Brand.Position = UDim2.fromOffset(12, 0)
Brand.BackgroundTransparency = 1
Brand.Text = "HAIMIYACH"
Brand.TextColor3 = Color3.fromRGB(245, 246, 249)
Brand.Font = Enum.Font.GothamBold
Brand.TextSize = 13
Brand.TextXAlignment = Enum.TextXAlignment.Left
Brand.Parent = Header

local HeaderSub = Instance.new("TextLabel")
HeaderSub.Size = UDim2.new(1, -90, 0, 12)
HeaderSub.Position = UDim2.fromOffset(12, 25)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "SUDOKU"
HeaderSub.TextColor3 = Color3.fromRGB(123, 126, 137)
HeaderSub.Font = Enum.Font.GothamMedium
HeaderSub.TextSize = 7
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.Parent = Header

local OpenButton

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(28, 28)
Close.Position = UDim2.new(1, -36, 0, 7)
Close.BackgroundColor3 = Color3.fromRGB(44, 45, 52)
Close.BorderSizePixel = 0
Close.AutoButtonColor = false
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(205, 207, 214)
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 18
Close.Parent = Header

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 7)
cc.Parent = Close

-- Touch/mouse drag only from header.
local dragging = false
local dragStart
local startPos
local dragConnection

local function stopDrag()
    dragging = false
    dragConnection = nil
end

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPos = Window.Position

        if dragConnection then
            dragConnection:Disconnect()
        end

        dragConnection = UserInputService.InputChanged:Connect(function(move)
            if not dragging then return end

            if move.UserInputType == Enum.UserInputType.MouseMovement
                or move.UserInputType == Enum.UserInputType.Touch then

                local delta = move.Position - dragStart
                Window.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                stopDrag()
            end
        end)
    end
end)

Close.Activated:Connect(function()
    Window.Visible = false
    OpenButton.Visible = true
end)

-- Floating reopen button.
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(82, 36)
OpenButton.Position = UDim2.new(0, 12, 0.5, -18)
OpenButton.BackgroundColor3 = Color3.fromRGB(30, 31, 36)
OpenButton.BorderSizePixel = 0
OpenButton.AutoButtonColor = false
OpenButton.Text = "HAIMIYACH"
OpenButton.TextColor3 = Color3.fromRGB(240, 241, 245)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 9
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui

local oc = Instance.new("UICorner")
oc.CornerRadius = UDim.new(0, 8)
oc.Parent = OpenButton

local os = Instance.new("UIStroke")
os.Color = Color3.fromRGB(66, 68, 77)
os.Thickness = 1
os.Parent = OpenButton

OpenButton.Activated:Connect(function()
    Window.Visible = true
    OpenButton.Visible = false
end)

-- Fixed viewport; only this area scrolls.
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -12, 1, -48)
Content.Position = UDim2.fromOffset(6, 46)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.Active = true
Content.ScrollingEnabled = true
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(90, 93, 104)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new()
Content.Parent = Window

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingLeft = UDim.new(0, 4)
contentPadding.PaddingRight = UDim.new(0, 4)
contentPadding.PaddingBottom = UDim.new(0, 10)
contentPadding.Parent = Content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 5)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = Content

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

local function section(text, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(112, 115, 127)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 8
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = Content
    return label
end

local function action(text, icon, order, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.LayoutOrder = order
    button.Parent = Content
    corner(button, 7)
    stroke(button)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.fromOffset(28, 38)
    iconLabel.Position = UDim2.fromOffset(7, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextColor3 = Color3.fromRGB(190, 193, 202)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 12
    iconLabel.Parent = button

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -62, 1, 0)
    title.Position = UDim2.fromOffset(38, 0)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = Color3.fromRGB(226, 228, 235)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 9
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = button

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.fromOffset(20, 38)
    arrow.Position = UDim2.new(1, -25, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "›"
    arrow.TextColor3 = Color3.fromRGB(118, 121, 132)
    arrow.Font = Enum.Font.GothamMedium
    arrow.TextSize = 15
    arrow.Parent = button

    button.Activated:Connect(callback)

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            button.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            button.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
        end
    end)

    return button
end

local function toggleRow(text, order, getState, setState)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = Content
    corner(row, 7)
    stroke(row)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -72, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(226, 228, 235)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(44, 22)
    toggle.Position = UDim2.new(1, -54, 0.5, -11)
    toggle.BackgroundColor3 = Color3.fromRGB(58, 59, 67)
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Text = ""
    toggle.Parent = row
    corner(toggle, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = Color3.fromRGB(183, 185, 193)
    knob.BorderSizePixel = 0
    knob.Parent = toggle
    corner(knob, 8)

    local function redraw()
        local enabled = getState()
        toggle.BackgroundColor3 = enabled
            and Color3.fromRGB(68, 101, 83)
            or Color3.fromRGB(58, 59, 67)

        knob.BackgroundColor3 = enabled
            and Color3.fromRGB(231, 237, 232)
            or Color3.fromRGB(183, 185, 193)

        knob.Position = enabled
            and UDim2.new(1, -19, 0.5, -8)
            or UDim2.fromOffset(3, 3)
    end

    toggle.Activated:Connect(function()
        setState(not getState())
        redraw()
    end)

    redraw()
    return row, redraw
end

-- Variables used by the controls.
local answerToggleRedraw
local targetToggleRedraw
local targetButton
local targetList
local targetArrow
local modeButton
local modeList
local customPanel
local targetListVisible = false

local function updateToggles()
    if answerToggleRedraw then answerToggleRedraw() end
    if targetToggleRedraw then targetToggleRedraw() end
end

-- ============================================================
-- SOLVER
-- ============================================================

section("SOLVER", 1)

action("Solve Puzzle", "▶", 2, function()
    task.spawn(function()
        local board = currentBoard or refreshBoard(false)
        if not board then
            notify("HAIMIYACH", "Board milikmu belum ditemukan.", 3)
            return
        end

        local _, solution = solveBoard(board)
        if not solution then
            notify("HAIMIYACH", "Puzzle tidak memiliki solusi.", 3)
            return
        end

        clearESP()
        espActive = false
        updateToggles()

        local ok, count, err = serverFill(board, solution)
        if ok then
            notify("HAIMIYACH", tostring(count) .. " cell answered.", 3)
        else
            notify("HAIMIYACH", tostring(err or "Gagal menjawab board."), 3)
        end
    end)
end)

-- Solve mode dropdown.
local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, 0, 0, 42)
modeRow.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
modeRow.BorderSizePixel = 0
modeRow.LayoutOrder = 3
modeRow.Parent = Content
corner(modeRow, 7)
stroke(modeRow)

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(0.42, 0, 1, 0)
modeLabel.Position = UDim2.fromOffset(10, 0)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Solve Mode"
modeLabel.TextColor3 = Color3.fromRGB(220, 222, 230)
modeLabel.Font = Enum.Font.GothamMedium
modeLabel.TextSize = 9
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = modeRow

modeButton = Instance.new("TextButton")
modeButton.Size = UDim2.new(0.54, -10, 0, 28)
modeButton.Position = UDim2.new(0.46, 0, 0.5, -14)
modeButton.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
modeButton.BorderSizePixel = 0
modeButton.AutoButtonColor = false
modeButton.Text = "NORMAL"
modeButton.TextColor3 = Color3.fromRGB(222, 224, 231)
modeButton.Font = Enum.Font.GothamMedium
modeButton.TextSize = 8
modeButton.TextTruncate = Enum.TextTruncate.AtEnd
modeButton.Parent = modeRow
corner(modeButton, 6)

modeList = Instance.new("Frame")
modeList.Size = UDim2.new(1, 0, 0, 0)
modeList.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
modeList.BorderSizePixel = 0
modeList.Visible = false
modeList.LayoutOrder = 4
modeList.Parent = Content
corner(modeList, 7)
stroke(modeList)

local modeLayout = Instance.new("UIListLayout")
modeLayout.Padding = UDim.new(0, 3)
modeLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeLayout.Parent = modeList

local function closeModeList()
    modeList.Visible = false
    modeList.Size = UDim2.new(1, 0, 0, 0)
end

local function addMode(text, key, order)
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -8, 0, 27)
    item.BackgroundColor3 = Color3.fromRGB(40, 41, 48)
    item.BorderSizePixel = 0
    item.AutoButtonColor = false
    item.Text = "  " .. text
    item.TextColor3 = Color3.fromRGB(222, 224, 231)
    item.Font = Enum.Font.Gotham
    item.TextSize = 8
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = order
    item.Parent = modeList
    corner(item, 5)

    item.Activated:Connect(function()
        if key == "CUSTOM" then
            selectedDelayMode = "CUSTOM"
            customPanel.Visible = true
            modeButton.Text = "CUSTOM"
        else
            selectedSolveMode = key
            selectedDelayMode = "MODE DEFAULT"
            customPanel.Visible = false
            modeButton.Text = key
        end
        closeModeList()
    end)
end

addMode("NOOB", "NOOB", 1)
addMode("NORMAL", "NORMAL", 2)
addMode("PRO", "PRO", 3)
addMode("CUSTOM DELAY", "CUSTOM", 4)

modeButton.Activated:Connect(function()
    local visible = not modeList.Visible
    targetList.Visible = false
    targetListVisible = false
    targetArrow.Text = "▾"

    modeList.Visible = visible
    modeList.Size = UDim2.new(1, 0, 0, visible and 117 or 0)
end)

customPanel = Instance.new("Frame")
customPanel.Size = UDim2.new(1, 0, 0, 68)
customPanel.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
customPanel.BorderSizePixel = 0
customPanel.Visible = false
customPanel.LayoutOrder = 5
customPanel.Parent = Content
corner(customPanel, 7)
stroke(customPanel)

local customTitle = Instance.new("TextLabel")
customTitle.Size = UDim2.new(1, -20, 0, 15)
customTitle.Position = UDim2.fromOffset(10, 5)
customTitle.BackgroundTransparency = 1
customTitle.Text = "Random delay per cell"
customTitle.TextColor3 = Color3.fromRGB(135, 138, 149)
customTitle.Font = Enum.Font.Gotham
customTitle.TextSize = 7
customTitle.TextXAlignment = Enum.TextXAlignment.Left
customTitle.Parent = customPanel

local function delayBox(x, labelText, value)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 0, 12)
    label.Position = UDim2.new(x, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(120, 123, 134)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 6
    label.Parent = customPanel

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.45, 0, 0, 25)
    box.Position = UDim2.new(x, 0, 0, 34)
    box.BackgroundColor3 = Color3.fromRGB(46, 47, 54)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Text = string.format("%.2f", value)
    box.TextColor3 = Color3.fromRGB(231, 233, 239)
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 8
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = customPanel
    corner(box, 5)

    return box
end

local minDelayBox = delayBox(0.04, "MIN", customMinDelay)
local maxDelayBox = delayBox(0.52, "MAX", customMaxDelay)

readCustomDelay = function()
    local minValue = tonumber(minDelayBox.Text) or customMinDelay
    local maxValue = tonumber(maxDelayBox.Text) or customMaxDelay

    minValue = math.clamp(minValue, 0.05, 60)
    maxValue = math.clamp(maxValue, minValue, 60)

    customMinDelay = minValue
    customMaxDelay = maxValue

    minDelayBox.Text = string.format("%.2f", minValue)
    maxDelayBox.Text = string.format("%.2f", maxValue)
end

minDelayBox.FocusLost:Connect(readCustomDelay)
maxDelayBox.FocusLost:Connect(readCustomDelay)

-- ============================================================
-- MY BOARD
-- ============================================================

section("MY BOARD", 6)

local _, answerRedraw = toggleRow(
    "Answer ESP",
    7,
    function() return espActive end,
    function(enabled)
        task.spawn(function()
            local board = currentBoard or refreshBoard(false)
            if not board then return end

            if enabled then
                local _, solution = solveBoard(board)
                if solution then
                    espActive = showESP(board, solution) > 0
                else
                    espActive = false
                end
            else
                clearESP()
                espActive = false
            end

            updateToggles()
        end)
    end
)
answerToggleRedraw = answerRedraw

action("Refresh My Board", "↻", 8, function()
    refreshBoard(true)
end)

-- ============================================================
-- TARGET
-- ============================================================

section("TARGET BOARD", 9)

local targetRow = Instance.new("Frame")
targetRow.Size = UDim2.new(1, 0, 0, 42)
targetRow.BackgroundColor3 = Color3.fromRGB(34, 35, 41)
targetRow.BorderSizePixel = 0
targetRow.LayoutOrder = 10
targetRow.Parent = Content
corner(targetRow, 7)
stroke(targetRow)

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(0.34, 0, 1, 0)
targetLabel.Position = UDim2.fromOffset(10, 0)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Target"
targetLabel.TextColor3 = Color3.fromRGB(220, 222, 230)
targetLabel.Font = Enum.Font.GothamMedium
targetLabel.TextSize = 9
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = targetRow

targetButton = Instance.new("TextButton")
targetButton.Size = UDim2.new(0.66, -10, 0, 28)
targetButton.Position = UDim2.new(0.34, 0, 0.5, -14)
targetButton.BackgroundColor3 = Color3.fromRGB(45, 46, 54)
targetButton.BorderSizePixel = 0
targetButton.AutoButtonColor = false
targetButton.Text = "Select Player"
targetButton.TextColor3 = Color3.fromRGB(204, 206, 214)
targetButton.Font = Enum.Font.GothamMedium
targetButton.TextSize = 8
targetButton.TextTruncate = Enum.TextTruncate.AtEnd
targetButton.Parent = targetRow
corner(targetButton, 6)

targetArrow = Instance.new("TextLabel")
targetArrow.Size = UDim2.fromOffset(18, 28)
targetArrow.Position = UDim2.new(1, -21, 0, 0)
targetArrow.BackgroundTransparency = 1
targetArrow.Text = "▾"
targetArrow.TextColor3 = Color3.fromRGB(135, 138, 149)
targetArrow.Font = Enum.Font.GothamMedium
targetArrow.TextSize = 8
targetArrow.Parent = targetButton

targetList = Instance.new("ScrollingFrame")
targetList.Name = "TargetDropdown"
targetList.Size = UDim2.new(1, 0, 0, 0)
targetList.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
targetList.BorderSizePixel = 0
targetList.Visible = false
targetList.Active = true
targetList.ScrollingEnabled = true
targetList.ScrollingDirection = Enum.ScrollingDirection.Y
targetList.ScrollBarThickness = 3
targetList.ScrollBarImageColor3 = Color3.fromRGB(90, 93, 104)
targetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
targetList.CanvasSize = UDim2.new()
targetList.LayoutOrder = 11
targetList.Parent = Content
corner(targetList, 7)
stroke(targetList)

local targetLayout = Instance.new("UIListLayout")
targetLayout.Padding = UDim.new(0, 3)
targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetLayout.Parent = targetList

local function updateTargetText()
    if not selectedUserId then
        targetButton.Text = "Select Player"
        return
    end

    local p = Players:GetPlayerByUserId(selectedUserId)
    if not p then
        targetButton.Text = "Player unavailable"
        return
    end

    local name = p.DisplayName
    if #name > 18 then
        name = string.sub(name, 1, 17) .. "…"
    end

    targetButton.Text = name
end

local function rebuildTargetList()
    for _, child in ipairs(targetList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local entries = getBoardList()
    local count = 0

    for _, entry in ipairs(entries) do
        if entry.userId ~= LocalPlayer.UserId then
            count += 1

            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, -8, 0, 27)
            item.BackgroundColor3 = entry.userId == selectedUserId
                and Color3.fromRGB(55, 65, 57)
                or Color3.fromRGB(40, 41, 48)
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = "  " .. entry.display
            item.TextColor3 = Color3.fromRGB(220, 222, 230)
            item.Font = Enum.Font.Gotham
            item.TextSize = 8
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextTruncate = Enum.TextTruncate.AtEnd
            item.LayoutOrder = count
            item.Parent = targetList
            corner(item, 5)

            item.Activated:Connect(function()
                selectedUserId = entry.userId
                targetList.Visible = false
                targetList.Size = UDim2.new(1, 0, 0, 0)
                targetListVisible = false
                targetArrow.Text = "▾"
                updateTargetText()

                if targetAnswerESPActive then
                    refreshTargetAnswerESP()
                end
            end)
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -8, 0, 27)
        empty.BackgroundTransparency = 1
        empty.Text = "No player board found"
        empty.TextColor3 = Color3.fromRGB(135, 138, 149)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 8
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Parent = targetList
        count = 1
    end

    targetList.CanvasSize = UDim2.new(0, 0, 0, count * 30 + 4)
    updateTargetText()
end

targetButton.Activated:Connect(function()
    targetListVisible = not targetListVisible

    modeList.Visible = false
    modeList.Size = UDim2.new(1, 0, 0, 0)

    targetList.Visible = targetListVisible
    targetList.Size = UDim2.new(1, 0, 0, targetListVisible and 120 or 0)
    targetArrow.Text = targetListVisible and "▴" or "▾"

    if targetListVisible then
        rebuildTargetList()
    end
end)

local _, targetRedraw = toggleRow(
    "Target Answer ESP",
    12,
    function() return targetAnswerESPActive end,
    function(enabled)
        task.spawn(function()
            if not selectedUserId then
                notify("HAIMIYACH", "Select a player first.", 2)
                return
            end

            if enabled then
                local board = getSelectedBoard()
                if not board then
                    targetAnswerESPActive = false
                    notify("HAIMIYACH", "Target board not found.", 3)
                    updateToggles()
                    return
                end

                targetAnswerESPActive = showTargetAnswerESP(board) > 0
            else
                clearTargetAnswerESP()
                targetAnswerESPActive = false
            end

            updateToggles()
        end)
    end
)
targetToggleRedraw = targetRedraw

action("Teleport to Target", "↗", 13, function()
    local board = getSelectedBoard()

    if board then
        local p = selectedUserId and Players:GetPlayerByUserId(selectedUserId)
        teleportToBoard(board, p and p.DisplayName or "Target")
    else
        notify("HAIMIYACH", "Target board not found.", 3)
    end
end)

-- ============================================================
-- LIVE REFRESH
-- ============================================================

task.spawn(function()
    for _ = 1, 12 do
        task.wait(0.25)
        if refreshBoard(false) then break end
    end
end)

task.spawn(function()
    local folder = getPlacedBoards()

    if folder then
        folder.ChildAdded:Connect(function()
            task.wait(0.2)
            rebuildTargetList()
            if targetAnswerESPActive then
                refreshTargetAnswerESP()
            end
        end)

        folder.ChildRemoved:Connect(function()
            task.wait(0.2)
            rebuildTargetList()
            if targetAnswerESPActive then
                refreshTargetAnswerESP()
            end
        end)
    end

    Players.PlayerAdded:Connect(function()
        task.wait(0.2)
        rebuildTargetList()
    end)

    Players.PlayerRemoving:Connect(function(player)
        if player.UserId == selectedUserId then
            selectedUserId = nil
            clearTargetAnswerESP()
            targetAnswerESPActive = false
            updateToggles()
        end

        task.wait(0.1)
        rebuildTargetList()
    end)
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1.5)

        if targetAnswerESPActive and selectedUserId then
            refreshTargetAnswerESP()
        end
    end
end)

print("HAIMIYACH Sudoku loaded - compact Roblox-style UI")
