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
-- GUI - COMPACT ANDROID
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SudokuTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = workspace.CurrentCamera
local vw = camera and camera.ViewportSize.X or 800
local guiWidth = math.clamp(math.floor(vw * 0.36), 205, 250)
local guiHeight = 350

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, guiWidth, 0, guiHeight)
Window.Position = UDim2.new(0, 10, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = false
Window.Parent = ScreenGui

local wc = Instance.new("UICorner")
wc.CornerRadius = UDim.new(0, 10)
wc.Parent = Window

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 0, 38)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "SUDOKU TOOLS"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Window

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 36, 0, 36)
Close.Position = UDim2.new(1, -39, 0, 1)
Close.BackgroundTransparency = 1
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(225,225,225)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 23
Close.Parent = Window

local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 68, 0, 40)
OpenButton.Position = UDim2.new(0, 10, 0.5, -20)
OpenButton.BackgroundColor3 = Color3.fromRGB(30,30,35)
OpenButton.BorderSizePixel = 0
OpenButton.Text = "OPEN"
OpenButton.TextColor3 = Color3.fromRGB(255,255,255)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 12
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui

local oc = Instance.new("UICorner")
oc.CornerRadius = UDim.new(0,9)
oc.Parent = OpenButton

local function openGUI()
    Window.Visible = true
    OpenButton.Visible = false
end

local function closeGUI()
    Window.Visible = false
    OpenButton.Visible = true
end

Close.Activated:Connect(closeGUI)
OpenButton.Activated:Connect(openGUI)

-- Drag by title, works on Android touch and mouse.
local targetList
local dragging, dragStart, startPos = false, nil, nil
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if targetList then
            targetList.Visible = false
            targetListVisible = false
            targetArrow.Text = "▼"
        end
        dragging = true
        dragStart = input.Position
        startPos = Window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)

    end
end)

local Content = Instance.new("ScrollingFrame")
Content.Name = "ContentScroll"
Content.Size = UDim2.new(1, -16, 1, -48)
Content.Position = UDim2.new(0, 8, 0, 42)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.ScrollingEnabled = true
Content.Active = true
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.Parent = Window

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = Content

local function makeButton(text, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(50,50,56)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.LayoutOrder = order
    b.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,7)
    c.Parent = b
    return b
end

local function label(text, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,20)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(155,155,165)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
    l.Parent = Content
    return l
end

local answerESPButton
local targetESPButton
local targetButton
local teleportButton

local function updateButtons()
    if answerESPButton then
        answerESPButton.Text = espActive and "●  ANSWER ESP  •  ON" or "○  ANSWER ESP  •  OFF"
    end
    if targetESPButton then
        targetESPButton.Text = targetAnswerESPActive and "●  TARGET ANSWERS  •  ON" or "○  TARGET ANSWERS  •  OFF"
    end
end

-- Core features that already work.
local solveButton = makeButton("✓  SOLVE PUZZLE  •  SERVER", 1)
solveButton.Activated:Connect(function()
    task.spawn(function()
        local board = currentBoard or refreshBoard(false)
        if not board then
            notify("Sudoku", "Board milikmu belum ditemukan.", 3)
            return
        end

        local _, solution = solveBoard(board)
        if not solution then
            notify("Sudoku", "Puzzle tidak memiliki solusi.", 3)
            return
        end

        clearESP()
        espActive = false
        updateButtons()

        local ok, count, err = serverFill(board, solution)
        if ok then
            notify("Sudoku", tostring(count) .. " sel diisi.", 3)
        else
            notify("Sudoku", tostring(err or "Gagal mengisi board."), 3)
        end
    end)
end)

answerESPButton = makeButton("○  ANSWER ESP  •  OFF", 2)
answerESPButton.Activated:Connect(function()
    task.spawn(function()
        local board = currentBoard or refreshBoard(false)
        if not board then return end

        if espActive then
            clearESP()
            espActive = false
            updateButtons()
            return
        end

        local _, solution = solveBoard(board)
        if not solution then
            notify("Sudoku", "Puzzle tidak memiliki solusi.", 3)
            return
        end

        local count = showESP(board, solution)
        espActive = count > 0
        updateButtons()
    end)
end)

local refreshButton = makeButton("↻  REFRESH MY BOARD", 3)
refreshButton.Activated:Connect(function()
    refreshBoard(true)
end)

-- ============================================================
-- SOLVE MODE DROPDOWN + CUSTOM RANDOM DELAY
-- ============================================================

local modeButton = makeButton("🧠  SOLVE MODE   •   NORMAL   •   0.35–0.85s", 4)
local modeList = Instance.new("ScrollingFrame")
modeList.Name = "SolveModeDropdown"
modeList.Size = UDim2.new(1, 0, 0, 108)
modeList.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
modeList.BorderSizePixel = 0
modeList.ScrollBarThickness = 3
modeList.ScrollingDirection = Enum.ScrollingDirection.Y
modeList.CanvasSize = UDim2.new(0, 0, 0, 0)
modeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
modeList.Visible = false
modeList.LayoutOrder = 5
modeList.Parent = Content
local mlc = Instance.new("UICorner")
mlc.CornerRadius = UDim.new(0, 7)
mlc.Parent = modeList
local mlayout = Instance.new("UIListLayout")
mlayout.Padding = UDim.new(0, 3)
mlayout.SortOrder = Enum.SortOrder.LayoutOrder
mlayout.Parent = modeList

local customPanel = Instance.new("Frame")
customPanel.Name = "CustomDelayPanel"
customPanel.Size = UDim2.new(1, 0, 0, 92)
customPanel.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
customPanel.BorderSizePixel = 0
customPanel.Visible = false
customPanel.LayoutOrder = 6
customPanel.Parent = Content
local cpc = Instance.new("UICorner")
cpc.CornerRadius = UDim.new(0, 7)
cpc.Parent = customPanel

local customTitle = Instance.new("TextLabel")
customTitle.Size = UDim2.new(1, -16, 0, 22)
customTitle.Position = UDim2.new(0, 8, 0, 5)
customTitle.BackgroundTransparency = 1
customTitle.Text = "CUSTOM DELAY  •  RANDOM PER CELL"
customTitle.TextColor3 = Color3.fromRGB(210, 210, 220)
customTitle.Font = Enum.Font.GothamBold
customTitle.TextSize = 9
customTitle.TextXAlignment = Enum.TextXAlignment.Left
customTitle.Parent = customPanel

local function makeDelayBox(parent, x, placeholder, value)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.43, 0, 0, 30)
    box.Position = UDim2.new(x, 0, 0, 34)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 57)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.PlaceholderText = placeholder
    box.Text = string.format("%.2f", value)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 11
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = parent
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 6)
    bc.Parent = box
    return box
end

local minDelayBox = makeDelayBox(customPanel, 0.02, "MIN", customMinDelay)
local maxDelayBox = makeDelayBox(customPanel, 0.55, "MAX", customMaxDelay)

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

local function updateCustomModeButton()
    readCustomDelay()
    if selectedDelayMode == "CUSTOM" then
        modeButton.Text = "⚙  DELAY: CUSTOM   •   " .. string.format("%.2f–%.2fs", customMinDelay, customMaxDelay)
    end
end

minDelayBox.FocusLost:Connect(updateCustomModeButton)
maxDelayBox.FocusLost:Connect(updateCustomModeButton)

local function modeItem(text, key, icon, order)
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -8, 0, 30)
    item.BackgroundColor3 = Color3.fromRGB(49, 49, 57)
    item.BorderSizePixel = 0
    item.Text = "  " .. icon .. "  " .. text
    item.TextColor3 = Color3.fromRGB(245, 245, 250)
    item.Font = Enum.Font.GothamBold
    item.TextSize = 10
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.LayoutOrder = order
    item.Parent = modeList
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = item
    item.Activated:Connect(function()
        selectedSolveMode = key == "CUSTOM" and selectedSolveMode or key
        selectedDelayMode = key == "CUSTOM" and "CUSTOM" or "MODE DEFAULT"
        modeList.Visible = false
        if key == "CUSTOM" then
            customPanel.Visible = true
            modeButton.Text = "⚙  DELAY: CUSTOM   •   " .. string.format("%.2f–%.2fs", customMinDelay, customMaxDelay)
        else
            customPanel.Visible = false
            local timing = getSolveTiming()
            modeButton.Text = string.format("🧠  SOLVE MODE   •   %s   •   %.2f–%.2fs", selectedSolveMode, timing.min, timing.max)
        end
    end)
    return item
end

modeItem("NOOB", "NOOB", "🐣", 1)
modeItem("NORMAL", "NORMAL", "🎮", 2)
modeItem("PRO", "PRO", "🧠", 3)
modeItem("CUSTOM DELAY", "CUSTOM", "⚙", 4)

modeButton.Activated:Connect(function()
    modeList.Visible = not modeList.Visible
    if modeList.Visible then
        customPanel.Visible = false
    elseif selectedDelayMode == "CUSTOM" then
        customPanel.Visible = true
    end
end)

label("PLAYER TARGET", 7)

targetButton = Instance.new("TextButton")
targetButton.Size = UDim2.new(1,0,0,34)
targetButton.BackgroundColor3 = Color3.fromRGB(43,43,49)
targetButton.BorderSizePixel = 0
targetButton.TextColor3 = Color3.fromRGB(255,255,255)
targetButton.Font = Enum.Font.GothamBold
targetButton.TextSize = 10
targetButton.TextXAlignment = Enum.TextXAlignment.Left
targetButton.TextTruncate = Enum.TextTruncate.AtEnd
targetButton.Text = "  TARGET: PILIH PLAYER"
targetButton.LayoutOrder = 8
targetButton.Parent = Content
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0,7)
tc.Parent = targetButton

local targetArrow = Instance.new("TextLabel")
targetArrow.Size = UDim2.new(0,30,1,0)
targetArrow.Position = UDim2.new(1,-32,0,0)
targetArrow.BackgroundTransparency = 1
targetArrow.Text = "▼"
targetArrow.TextColor3 = Color3.fromRGB(190,190,200)
targetArrow.Font = Enum.Font.GothamBold
targetArrow.TextSize = 10
targetArrow.Parent = targetButton

-- Dropdown is a floating ScrollingFrame so the main GUI stays short.
targetList = Instance.new("ScrollingFrame")
targetList.Name = "TargetList"
targetList.Size = UDim2.new(1, 0, 0, 120)
targetList.BackgroundColor3 = Color3.fromRGB(37, 37, 44)
targetList.BorderSizePixel = 0
targetList.ScrollBarThickness = 3
targetList.ScrollingDirection = Enum.ScrollingDirection.Y
targetList.ScrollingEnabled = true
targetList.Active = true
targetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
targetList.CanvasSize = UDim2.new(0, 0, 0, 0)
targetList.Visible = false
targetList.LayoutOrder = 9
targetList.Parent = Content
local tlc = Instance.new("UICorner")
tlc.CornerRadius = UDim.new(0, 7)
tlc.Parent = targetList
local tlayout = Instance.new("UIListLayout")
tlayout.Padding = UDim.new(0, 3)
tlayout.SortOrder = Enum.SortOrder.LayoutOrder
tlayout.Parent = targetList

local function updateTargetText()
    if not selectedUserId then
        targetButton.Text = "  TARGET: PILIH PLAYER"
        return
    end
    local p = Players:GetPlayerByUserId(selectedUserId)
    if p then
        targetButton.Text = "  TARGET: " .. p.DisplayName
    else
        targetButton.Text = "  TARGET: PLAYER TIDAK ADA"
    end
end

local function selectTarget(userId)
    selectedUserId = tonumber(userId)
    targetList.Visible = false
    targetArrow.Text = "▼"
    updateTargetText()
    if targetAnswerESPActive then
        refreshTargetAnswerESP()
    end
end

local function rebuildTargetList()
    for _, child in ipairs(targetList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local boards = getBoardList()
    local count = 0
    for _, entry in ipairs(boards) do
        -- This mode is specifically for another player's answer board.
        if entry.userId ~= LocalPlayer.UserId then
            count += 1
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1,-8,0,30)
            item.BackgroundColor3 = (entry.userId == selectedUserId) and Color3.fromRGB(70,65,48) or Color3.fromRGB(49,49,56)
            item.BorderSizePixel = 0
            item.TextColor3 = Color3.fromRGB(245,245,245)
            item.Font = Enum.Font.Gotham
            item.TextSize = 10
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextTruncate = Enum.TextTruncate.AtEnd
            item.Text = "  " .. entry.display
            item.LayoutOrder = count
            item.ZIndex = 301
            item.Parent = targetList
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0,5)
            c.Parent = item
            item.Activated:Connect(function()
                selectTarget(entry.userId)
            end)
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,-8,0,30)
        empty.BackgroundTransparency = 1
        empty.Text = "Tidak ada board player lain"
        empty.TextColor3 = Color3.fromRGB(160,160,170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 10
        empty.ZIndex = 301
        empty.Parent = targetList
        count = 1
    end

    targetList.CanvasSize = UDim2.new(0,0,0,count * 33 + 5)
    updateTargetText()
end

targetButton.Activated:Connect(function()
    targetListVisible = not targetListVisible
    targetList.Visible = targetListVisible
    targetArrow.Text = targetListVisible and "▲" or "▼"
    if targetListVisible then
        modeList.Visible = false
        customPanel.Visible = selectedDelayMode == "CUSTOM"
        rebuildTargetList()
    end
end)

targetESPButton = makeButton("○  TARGET ANSWERS  •  OFF", 10)
targetESPButton.Activated:Connect(function()
    task.spawn(function()
        if not selectedUserId then
            notify("Target", "Pilih player terlebih dahulu.", 2)
            return
        end

        targetAnswerESPActive = not targetAnswerESPActive
        if targetAnswerESPActive then
            local board = getSelectedBoard()
            local count = showTargetAnswerESP(board)
            if not board then
                targetAnswerESPActive = false
                notify("Target", "Board player tidak ditemukan.", 3)
            elseif count == 0 then
                notify("Target", "Tidak ada jawaban kosong pada board target.", 2)
            end
        else
            clearTargetAnswerESP()
        end
        updateButtons()
    end)
end)

teleportButton = makeButton("➤  TELEPORT TO TARGET", 11)
teleportButton.Activated:Connect(function()
    local board = getSelectedBoard()
    if board then
        local p = selectedUserId and Players:GetPlayerByUserId(selectedUserId)
        teleportToBoard(board, p and p.DisplayName or "Target")
    else
        notify("Teleport", "Board target tidak ditemukan.", 3)
    end
end)

-- Initial own board detection.
task.spawn(function()
    for _ = 1, 12 do
        task.wait(0.25)
        if refreshBoard(false) then break end
    end
end)

-- Keep target boards synchronized when players/boards appear/disappear.
task.spawn(function()
    local folder = getPlacedBoards()
    if folder then
        folder.ChildAdded:Connect(function()
            task.wait(0.2)
            rebuildTargetList()
            if targetAnswerESPActive then refreshTargetAnswerESP() end
        end)
        folder.ChildRemoved:Connect(function()
            task.wait(0.2)
            rebuildTargetList()
            if targetAnswerESPActive then refreshTargetAnswerESP() end
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
            updateButtons()
        end
        task.wait(0.1)
        rebuildTargetList()
    end)
end)

-- Keep target answer ESP synced with the actual selected board.
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.75)
        if targetAnswerESPActive and selectedUserId then
            refreshTargetAnswerESP()
        end
    end
end)

-- No information/status panel by design: the compact UI only contains
-- actions the user can actually use.

print("Sudoku Tools - Compact Target Answer ESP v3 loaded")
