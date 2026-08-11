-- ============================================================
-- SUDOKU TOOLS - STANDALONE / ANDROID
-- Read Board / Solver / ESP / Local Fill / Reset Snapshot
-- ============================================================

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CLEAN OLD GUI
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
-- SUDOKU SOLVER
-- ============================================================

local Sudoku = {}

function Sudoku.isValid(board, row, col, num)

    for i = 1, 9 do
        if board[row][i] == num then
            return false
        end

        if board[i][col] == num then
            return false
        end
    end

    local boxRow = math.floor((row - 1) / 3) * 3 + 1
    local boxCol = math.floor((col - 1) / 3) * 3 + 1

    for r = boxRow, boxRow + 2 do
        for c = boxCol, boxCol + 2 do
            if board[r][c] == num then
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

                for num = 1, 9 do

                    if Sudoku.isValid(board, row, col, num) then

                        board[row][col] = num

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

-- ============================================================
-- BOARD HELPERS
-- ============================================================

local function getPlacedBoards()

    return workspace:FindFirstChild("PlacedBoards")
end

local function getBoardSurface(boardModel)

    if not boardModel then
        return nil
    end

    -- Tidak harus direct child.
    local surface = boardModel:FindFirstChild("SurfaceGui", true)

    if not surface or not surface:IsA("SurfaceGui") then
        return nil
    end

    local frame = surface:FindFirstChild("Frame")

    if not frame then
        return nil
    end

    return surface, frame
end

-- ============================================================
-- FIND PLAYER BOARD
-- ============================================================

local function getMyBoard()

    local placedBoards = getPlacedBoards()

    if not placedBoards then
        return nil
    end

    for _, board in ipairs(placedBoards:GetChildren()) do

        if board:IsA("Model") then

            local owner = board:GetAttribute("OwnerUserId")

            if owner ~= nil then

                local ownerNumber = tonumber(owner)

                if ownerNumber == LocalPlayer.UserId then
                    return board
                end
            end
        end
    end

    return nil
end

-- ============================================================
-- CREATE EMPTY BOARD
-- ============================================================

local function createEmptyBoard()

    local board = {}

    for row = 1, 9 do

        board[row] = {}

        for col = 1, 9 do
            board[row][col] = 0
        end
    end

    return board
end

-- ============================================================
-- READ BOARD
-- ============================================================

local function readBoard(boardModel)

    local boardData = createEmptyBoard()

    if not boardModel then
        return boardData
    end

    local _, frame = getBoardSurface(boardModel)

    if not frame then
        return boardData
    end

    for _, cell in ipairs(frame:GetChildren()) do

        if cell:IsA("TextButton") then

            local clueValue = cell:FindFirstChild("ClueValue")

            if clueValue and clueValue:IsA("TextLabel") then

                local row = tonumber(cell:GetAttribute("Row"))
                local col = tonumber(cell:GetAttribute("Col"))

                if row and col
                    and row >= 1 and row <= 9
                    and col >= 1 and col <= 9 then

                    local text = tostring(clueValue.Text or "")
                    local num = tonumber(text)

                    if num and num >= 1 and num <= 9 then
                        boardData[row][col] = num
                    else
                        boardData[row][col] = 0
                    end
                end
            end
        end
    end

    return boardData
end

-- ============================================================
-- BOARD SNAPSHOT
-- ============================================================

local boardSnapshots = {}

local function cloneBoard(board)

    local copy = {}

    for row = 1, 9 do

        copy[row] = {}

        for col = 1, 9 do
            copy[row][col] = board[row][col]
        end
    end

    return copy
end

local function saveSnapshot(boardModel)

    if not boardModel then
        return
    end

    boardSnapshots[boardModel] = cloneBoard(readBoard(boardModel))
end

-- ============================================================
-- GET SOLUTION
-- ============================================================

local function getSolution(boardModel)

    local source = readBoard(boardModel)
    local solution = cloneBoard(source)

    if Sudoku.solve(solution) then
        return solution, source
    end

    return nil, source
end

-- ============================================================
-- ESP
-- ============================================================

local espObjects = {}
local espActive = false

local function clearESP()

    for _, object in ipairs(espObjects) do

        if object then
            pcall(function()
                object:Destroy()
            end)
        end
    end

    table.clear(espObjects)
end

local function createCellESP(cell, number)

    local old = cell:FindFirstChild("SudokuESP")

    if old then
        old:Destroy()
    end

    local overlay = Instance.new("TextLabel")

    overlay.Name = "SudokuESP"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.Position = UDim2.fromScale(0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Text = tostring(number)
    overlay.TextColor3 = Color3.fromRGB(255, 200, 50)
    overlay.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    overlay.TextStrokeTransparency = 0.2
    overlay.Font = Enum.Font.GothamBold
    overlay.TextScaled = true
    overlay.ZIndex = 50
    overlay.Active = false
    overlay.Parent = cell

    table.insert(espObjects, overlay)

    return overlay
end

local function showESP(solution, boardModel)

    clearESP()

    if not solution or not boardModel then
        return false
    end

    local _, frame = getBoardSurface(boardModel)

    if not frame then
        return false
    end

    local count = 0

    for _, cell in ipairs(frame:GetChildren()) do

        if cell:IsA("TextButton") then

            local clueValue = cell:FindFirstChild("ClueValue")

            if clueValue and clueValue:IsA("TextLabel") then

                local row = tonumber(cell:GetAttribute("Row"))
                local col = tonumber(cell:GetAttribute("Col"))

                if row and col
                    and row >= 1 and row <= 9
                    and col >= 1 and col <= 9 then

                    if tostring(clueValue.Text) == "" then

                        local number = solution[row][col]

                        if number and number >= 1 and number <= 9 then

                            createCellESP(cell, number)
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    return count > 0, count
end

-- ============================================================
-- LOCAL FILL
-- ============================================================

local function fillSolution(boardModel, solution)

    if not boardModel or not solution then
        return 0
    end

    local _, frame = getBoardSurface(boardModel)

    if not frame then
        return 0
    end

    local count = 0

    for _, cell in ipairs(frame:GetChildren()) do

        if cell:IsA("TextButton") then

            local clueValue = cell:FindFirstChild("ClueValue")

            if clueValue and clueValue:IsA("TextLabel") then

                local row = tonumber(cell:GetAttribute("Row"))
                local col = tonumber(cell:GetAttribute("Col"))

                if row and col
                    and row >= 1 and row <= 9
                    and col >= 1 and col <= 9 then

                    if tostring(clueValue.Text) == "" then

                        local value = solution[row][col]

                        if value then

                            clueValue.Text = tostring(value)
                            clueValue.TextColor3 =
                                Color3.fromRGB(100, 200, 255)

                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    return count
end

-- ============================================================
-- RESET
-- ============================================================

local function resetBoard(boardModel)

    if not boardModel then
        return false
    end

    local _, frame = getBoardSurface(boardModel)

    if not frame then
        return false
    end

    local snapshot = boardSnapshots[boardModel]

    if not snapshot then

        saveSnapshot(boardModel)

        notify(
            "Reset",
            "Snapshot puzzle dibuat. Reset lagi untuk mengembalikan.",
            3
        )

        return false
    end

    for _, cell in ipairs(frame:GetChildren()) do

        if cell:IsA("TextButton") then

            local clueValue = cell:FindFirstChild("ClueValue")

            if clueValue and clueValue:IsA("TextLabel") then

                local row = tonumber(cell:GetAttribute("Row"))
                local col = tonumber(cell:GetAttribute("Col"))

                if row and col
                    and row >= 1 and row <= 9
                    and col >= 1 and col <= 9 then

                    local original = snapshot[row][col]

                    if original and original > 0 then
                        clueValue.Text = tostring(original)
                    else
                        clueValue.Text = ""
                    end

                    clueValue.TextColor3 =
                        Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end

    clearESP()
    espActive = false

    notify("Reset", "Tampilan board dikembalikan.", 2)

    return true
end

-- ============================================================
-- REFRESH BOARD
-- ============================================================

local currentBoard = nil

local function refreshBoard()

    currentBoard = getMyBoard()

    if not currentBoard then
        notify("Sudoku", "Board milikmu tidak ditemukan.", 3)
        return nil
    end

    local _, frame = getBoardSurface(currentBoard)

    if not frame then
        notify(
            "Sudoku",
            "Board ditemukan, tetapi SurfaceGui/Frame tidak ditemukan.",
            4
        )

        return nil
    end

    if not boardSnapshots[currentBoard] then
        saveSnapshot(currentBoard)
    end

    notify("Sudoku", "Board berhasil ditemukan.", 2)

    return currentBoard
end

-- ============================================================
-- SOLVE
-- ============================================================

local function solveESP()

    local board = currentBoard or getMyBoard()

    if not board then
        notify("Error", "Board tidak ditemukan.", 3)
        return
    end

    currentBoard = board

    local solution = getSolution(board)

    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    local success, count = showESP(solution, board)

    if success then

        espActive = true

        notify(
            "ESP ON",
            tostring(count) .. " jawaban ditampilkan.",
            3
        )

    else
        notify(
            "Sudoku",
            "Tidak ada sel kosong untuk ditampilkan.",
            3
        )
    end
end

local function solveFill()

    local board = currentBoard or getMyBoard()

    if not board then
        notify("Error", "Board tidak ditemukan.", 3)
        return
    end

    currentBoard = board

    if not boardSnapshots[board] then
        saveSnapshot(board)
    end

    local solution = getSolution(board)

    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    local count = fillSolution(board, solution)

    clearESP()
    espActive = false

    notify(
        "Solved",
        tostring(count) .. " sel diisi secara lokal.",
        3
    )
end

-- ============================================================
-- GUI
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "SudokuTools"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

-- ============================================================
-- WINDOW
-- ============================================================

local Window = Instance.new("Frame")

Window.Name = "Window"
Window.AnchorPoint = Vector2.new(0, 0.5)
Window.Size = UDim2.new(
    0,
    math.clamp(math.floor(workspace.CurrentCamera.ViewportSize.X * 0.42), 190, 260),
    0,
    235
)

Window.Position = UDim2.new(0, 10, 0.5, 0)
Window.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Window.BorderSizePixel = 0
Window.Active = true
Window.Parent = ScreenGui

local WindowCorner = Instance.new("UICorner")
WindowCorner.CornerRadius = UDim.new(0, 10)
WindowCorner.Parent = Window

-- ============================================================
-- TITLE
-- ============================================================

local Title = Instance.new("TextLabel")

Title.Name = "Title"
Title.Size = UDim2.new(1, -45, 0, 38)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "SUDOKU TOOLS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Window

-- ============================================================
-- CLOSE
-- ============================================================

local CloseBtn = Instance.new("TextButton")

CloseBtn.Name = "Close"
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -38, 0, 2)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 22
CloseBtn.Parent = Window

CloseBtn.Activated:Connect(function()
    clearESP()
    ScreenGui:Destroy()
end)

-- ============================================================
-- DRAG - TOUCH + MOUSE
-- ============================================================

local dragging = false
local dragStart
local startPosition

local function updateDrag(input)

    local delta = input.Position - dragStart

    Window.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

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

    if dragging then

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            updateDrag(input)
        end
    end
end)

-- ============================================================
-- BUTTON FACTORY
-- ============================================================

local function createButton(text, y, callback)

    local button = Instance.new("TextButton")

    button.Size = UDim2.new(1, -20, 0, 36)
    button.Position = UDim2.new(0, 10, 0, y)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.AutoButtonColor = true
    button.Parent = Window

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    button.Activated:Connect(function()
        task.spawn(function()
            pcall(callback)
        end)
    end)

    return button
end

-- ============================================================
-- BUTTONS
-- ============================================================

createButton(
    "SOLVE • FILL LOCAL",
    45,
    solveFill
)

createButton(
    "ESP • SHOW ANSWERS",
    87,
    function()

        if espActive then

            clearESP()
            espActive = false

            notify("ESP", "ESP dimatikan.", 2)

        else
            solveESP()
        end
    end
)

createButton(
    "RESET",
    129,
    function()

        local board = currentBoard or getMyBoard()

        if board then
            currentBoard = board
            resetBoard(board)
        else
            notify("Error", "Board tidak ditemukan.", 3)
        end
    end
)

createButton(
    "REFRESH BOARD",
    171,
    refreshBoard
)

-- ============================================================
-- INITIAL CHECK
-- ============================================================

task.spawn(function()

    task.wait(1)

    currentBoard = getMyBoard()

    if currentBoard then

        saveSnapshot(currentBoard)

        notify(
            "Sudoku Ready",
            "Board ditemukan.",
            3
        )

    else

        notify(
            "Sudoku",
            "Tempatkan board terlebih dahulu.",
            3
        )
    end
end)

print("Sudoku Tools loaded - standalone Android version")