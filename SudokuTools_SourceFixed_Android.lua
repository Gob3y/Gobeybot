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

local function serverFill(board, solution, delayTime)
    local cells = getCells(board)

    local selectCellRemote = getRemote("SelectCell")
    local placeNumberRemote = getRemote("PlaceNumber")

    if not placeNumberRemote then
        return false, 0, "PlaceNumber remote tidak dapat diakses."
    end

    local count = 0
    local delayValue = tonumber(delayTime) or 0.08

    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]

            if cell then
                local clue = cell:FindFirstChild("ClueValue")

                if clue and tostring(clue.Text) == "" then
                    local number = solution[row][col]

                    if selectCellRemote then
                        pcall(function()
                            selectCellRemote:FireServer(cell)
                        end)
                    end

                    local ok = pcall(function()
                        placeNumberRemote:FireServer(cell, number)
                    end)

                    if ok then
                        count = count + 1
                    end

                    task.wait(delayValue)
                end
            end
        end
    end

    return true, count
end

-- ============================================================
-- RESET LOCAL DISPLAY
-- ============================================================

local function resetBoard(board)
    local snapshot = snapshots[board]

    if not snapshot then
        saveSnapshot(board)
        notify(
            "Reset",
            "Snapshot dibuat. Tekan RESET sekali lagi.",
            3
        )
        return
    end

    local cells = getCells(board)

    for row = 1, 9 do
        for col = 1, 9 do
            local cell = cells[row .. ":" .. col]

            if cell then
                local clue = cell:FindFirstChild("ClueValue")

                if clue then
                    local original = snapshot[row][col]

                    if original and original > 0 then
                        clue.Text = tostring(original)
                    else
                        clue.Text = ""
                    end

                    clue.TextColor3 =
                        Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end

    clearESP()
    espActive = false

    notify("Reset", "Tampilan board dikembalikan.", 2)
end

-- ============================================================
-- BOARD STATUS / REFRESH
-- ============================================================

local currentBoard
local statusLabel

local function setStatus(text)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = tostring(text)
    end
end

local function refreshBoard(showNotification)
    currentBoard = getMyBoard()

    if not currentBoard then
        setStatus("Board: NOT FOUND")
        if showNotification ~= false then
            notify(
                "Sudoku",
                "Board belum ditemukan. Pastikan puzzle aktif.",
                3
            )
        end
        return nil
    end

    if not getBoardFrame(currentBoard) then
        setStatus("Board: INVALID")
        notify(
            "Sudoku",
            "Board ditemukan tetapi Frame belum siap.",
            4
        )
        return nil
    end

    if not snapshots[currentBoard] then
        saveSnapshot(currentBoard)
    end

    local id = currentBoard:GetAttribute("BoardId")
    setStatus("Board: OK • " .. tostring(id or "?"))

    if showNotification ~= false then
        notify("Sudoku", "Board berhasil ditemukan.", 2)
    end

    return currentBoard
end

-- ============================================================
-- DEBUG
-- ============================================================

local function debugBoards()
    local placedBoards = getPlacedBoards()
    local currentId = getCurrentBoardId()

    print("========== SUDOKU DEBUG ==========")
    print("Player:", LocalPlayer.Name)
    print("UserId:", LocalPlayer.UserId)
    print("CurrentBoardId:", currentId)
    print("BoardState loaded:", BoardState ~= nil)
    print("RemoteHandler loaded:", RemoteHandler ~= nil)

    if not placedBoards then
        print("PlacedBoards: NOT FOUND")
        print("===================================")
        notify("DEBUG", "PlacedBoards tidak ditemukan.", 4)
        return
    end

    print("PlacedBoards:", placedBoards:GetFullName())
    print("Count:", #placedBoards:GetChildren())

    for index, board in ipairs(placedBoards:GetChildren()) do
        print(
            index,
            board:GetFullName(),
            "Class=" .. board.ClassName,
            "BoardId=" .. tostring(board:GetAttribute("BoardId")),
            "OwnerUserId=" .. tostring(board:GetAttribute("OwnerUserId")),
            "ValidStructure=" .. tostring(hasBoardStructure(board))
        )
    end

    print("===================================")
    notify("DEBUG", "Data board dicetak ke console.", 5)
end

-- ============================================================
-- GUI
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SudokuTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local camera = workspace.CurrentCamera
local viewportWidth = camera and camera.ViewportSize.X or 800
local viewportHeight = camera and camera.ViewportSize.Y or 600

-- Responsive Android size.
local guiWidth = math.clamp(math.floor(viewportWidth * 0.38), 200, 285)
-- Keep enough vertical room for every button even on short Android screens.
local guiHeight = 275

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.new(0, guiWidth, 0, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(29, 29, 34)
Window.BorderSizePixel = 0
Window.Active = true
Window.Parent = ScreenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 11)
windowCorner.Parent = Window

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -55, 0, 38)
Title.Position = UDim2.new(0, 13, 0, 2)
Title.BackgroundTransparency = 1
Title.Text = "SUDOKU TOOLS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Window

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 38, 0, 38)
Close.Position = UDim2.new(1, -42, 0, 1)
Close.BackgroundTransparency = 1
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(220, 220, 220)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 24
Close.Parent = Window

Close.Activated:Connect(function()
    clearESP()
    ScreenGui:Destroy()
end)

-- Status
statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, 37)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Board: checking..."
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = Window

-- ============================================================
-- TOUCH + MOUSE DRAG
-- ============================================================

local dragging = false
local dragStart
local startPosition

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Window.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - dragStart

        Window.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

-- ============================================================
-- BUTTON FACTORY
-- ============================================================

local function makeButton(text, y, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 37)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 57)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = Window

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b

    b.Activated:Connect(function()
        task.spawn(function()
            local ok, err = pcall(callback)

            if not ok then
                warn("[SudokuTools] Button error:", err)
                notify("Error", "Terjadi error. Cek console.", 3)
            end
        end)
    end)

    return b
end

-- ============================================================
-- BUTTONS
-- ============================================================

makeButton("SOLVE • SERVER FILL", 67, function()
    local board = currentBoard or refreshBoard(false)

    if not board then
        return
    end

    local _, solution = solveBoard(board)

    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    clearESP()
    espActive = false

    local ok, count, err = serverFill(board, solution, 0.10)

    if ok then
        notify(
            "Solved",
            tostring(count) .. " sel dikirim ke server.",
            4
        )
    else
        notify("Error", tostring(err), 4)
    end
end)

makeButton("ESP • SHOW ANSWERS", 109, function()
    local board = currentBoard or refreshBoard(false)

    if not board then
        return
    end

    if espActive then
        clearESP()
        espActive = false
        notify("ESP", "ESP dimatikan.", 2)
        return
    end

    local _, solution = solveBoard(board)

    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    local count = showESP(board, solution)

    espActive = count > 0

    notify(
        "ESP",
        espActive
            and (tostring(count) .. " jawaban ditampilkan.")
            or "Tidak ada sel kosong.",
        3
    )
end)

makeButton("FILL • LOCAL ONLY", 151, function()
    local board = currentBoard or refreshBoard(false)

    if not board then
        return
    end

    local _, solution = solveBoard(board)

    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    local count = fillLocal(board, solution)

    clearESP()
    espActive = false

    notify(
        "Local Fill",
        tostring(count) .. " sel diisi pada client.",
        3
    )
end)

makeButton("RESET", 193, function()
    local board = currentBoard or refreshBoard(false)

    if board then
        resetBoard(board)
    end
end)

makeButton("REFRESH BOARD", 235, function()
    refreshBoard(true)
end)

-- ============================================================
-- INITIAL BOARD CHECK
-- ============================================================

task.spawn(function()
    -- The game sets currentBoardId after BoardInitialising.
    -- Give it a moment before resolving the board.
    for _ = 1, 10 do
        task.wait(0.5)

        currentBoard = getMyBoard()

        if currentBoard then
            break
        end
    end

    if currentBoard then
        saveSnapshot(currentBoard)

        local id = currentBoard:GetAttribute("BoardId")
        setStatus("Board: OK • " .. tostring(id or "?"))

        notify("Sudoku Ready", "Board berhasil dideteksi.", 3)
    else
        setStatus("Board: NOT FOUND")

        notify(
            "Sudoku",
            "Board belum aktif. Tekan REFRESH BOARD.",
            4
        )
    end
end)

print("==========================================")
print(" Sudoku Tools - Source Fixed Android")
print(" CurrentBoardId + OwnerUserId detection")
print(" SurfaceGui / Frame / ClueValue verified")
print("==========================================")
