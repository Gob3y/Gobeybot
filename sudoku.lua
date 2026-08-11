-- ============================================================
-- SUDOKU AUTO-SOLVE & ESP UNTUK GAME SUDOKU ANDROID
-- Menggunakan modul BoardStateHandlerClient dari game
-- ============================================================

-- Ambil modul-modul dari game
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Cari modul BoardStateHandlerClient
local BoardStateHandlerClient = nil
local BoardHandlerClient = nil

pcall(function()
    -- Asumsikan modul berada di ReplicatedStorage atau di script parent
    local Modules = ReplicatedStorage:WaitForChild("Modules")
    BoardStateHandlerClient = require(Modules:WaitForChild("BoardStateHandlerClient"))
    BoardHandlerClient = require(Modules:WaitForChild("BoardHandlerClient"))
end)

if not BoardStateHandlerClient then
    warn("BoardStateHandlerClient not found. Mencoba dari workspace.PlacedBoards...")
end

-- ============================================================
-- SUDOKU LOGIC (sama seperti sebelumnya)
-- ============================================================
local Sudoku = {}

function Sudoku.isValid(board, row, col, num)
    for i = 1, 9 do
        if board[row][i] == num then return false end
        if board[i][col] == num then return false end
    end
    local boxRow = (row - 1) - (row - 1) % 3 + 1
    local boxCol = (col - 1) - (col - 1) % 3 + 1
    for r = boxRow, boxRow + 2 do
        for c = boxCol, boxCol + 2 do
            if board[r][c] == num then return false end
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
                        if Sudoku.solve(board) then return true end
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
-- FUNGSI MEMBACA BOARD DARI GAME
-- ============================================================
local function getBoardFromGame()
    local boardData = {}
    for i = 1, 9 do boardData[i] = {} end

    -- Coba dari BoardStateHandlerClient
    if BoardStateHandlerClient and BoardStateHandlerClient.ActiveBoards then
        local myBoard = nil
        for boardId, boardModel in pairs(BoardStateHandlerClient.ActiveBoards) do
            local owner = boardModel:GetAttribute("OwnerUserId")
            if owner == LocalPlayer.UserId then
                myBoard = boardModel
                break
            end
        end
        if myBoard then
            local frame = myBoard:WaitForChild("SurfaceGui"):WaitForChild("Frame")
            for _, cell in ipairs(frame:GetChildren()) do
                if cell:IsA("TextButton") and cell:FindFirstChild("ClueValue") then
                    local row = cell:GetAttribute("Row")
                    local col = cell:GetAttribute("Col")
                    if row and col then
                        local text = cell.ClueValue.Text
                        local num = tonumber(text)
                        boardData[row][col] = num or 0
                    end
                end
            end
            return boardData, myBoard
        end
    end

    -- Fallback: cari dari workspace.PlacedBoards
    local placedBoards = workspace:FindFirstChild("PlacedBoards")
    if placedBoards then
        for _, boardModel in ipairs(placedBoards:GetChildren()) do
            if boardModel:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                local frame = boardModel:WaitForChild("SurfaceGui"):WaitForChild("Frame")
                for _, cell in ipairs(frame:GetChildren()) do
                    if cell:IsA("TextButton") and cell:FindFirstChild("ClueValue") then
                        local row = cell:GetAttribute("Row")
                        local col = cell:GetAttribute("Col")
                        if row and col then
                            local text = cell.ClueValue.Text
                            local num = tonumber(text)
                            boardData[row][col] = num or 0
                        end
                    end
                end
                return boardData, boardModel
            end
        end
    end

    return nil, nil
end

-- ============================================================
-- FUNGSI MENAMPILKAN SOLUSI (ESP)
-- ============================================================
local espLabels = {}
local espActive = false

function clearESP()
    for _, esp in ipairs(espLabels) do
        pcall(function() esp:Destroy() end)
    end
    espLabels = {}
end

function showESP(solutionBoard, boardModel)
    clearESP()
    if not boardModel then return end
    local frame = boardModel:WaitForChild("SurfaceGui"):WaitForChild("Frame")
    for _, cell in ipairs(frame:GetChildren()) do
        if cell:IsA("TextButton") and cell:FindFirstChild("ClueValue") then
            local row = cell:GetAttribute("Row")
            local col = cell:GetAttribute("Col")
            if row and col and cell.ClueValue.Text == "" then
                local esp = Instance.new("BillboardGui")
                esp.Name = "SudokuESP"
                esp.AlwaysOnTop = true
                esp.Size = UDim2.new(0, 40, 0, 20)
                esp.StudsOffset = Vector3.new(0, 0.8, 0)
                esp.Parent = cell

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = tostring(solutionBoard[row][col])
                label.TextColor3 = Color3.fromRGB(255, 200, 50)
                label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                label.TextStrokeTransparency = 0.3
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.Parent = esp

                espLabels[#espLabels + 1] = esp
            end
        end
    end
end

-- ============================================================
-- FITUR AUTO-SOLVE (mengisi board)
-- ============================================================
function autoSolveBoard()
    local boardData, boardModel = getBoardFromGame()
    if not boardData then
        notify("Error", "Board tidak ditemukan!", 3)
        return
    end

    -- Copy board untuk diselesaikan
    local sol = {}
    for r = 1, 9 do sol[r] = {} for c = 1, 9 do sol[r][c] = boardData[r][c] end end

    if Sudoku.solve(sol) then
        local frame = boardModel:WaitForChild("SurfaceGui"):WaitForChild("Frame")
        for _, cell in ipairs(frame:GetChildren()) do
            if cell:IsA("TextButton") and cell:FindFirstChild("ClueValue") then
                local row = cell:GetAttribute("Row")
                local col = cell:GetAttribute("Col")
                if row and col and cell.ClueValue.Text == "" then
                    cell.ClueValue.Text = tostring(sol[row][col])
                    cell.ClueValue.TextColor3 = Color3.fromRGB(100, 200, 255)
                end
            end
        end
        notify("Solved", "Board selesai!", 3)
    else
        notify("Error", "Tidak ada solusi!", 3)
    end
end

-- ============================================================
-- NOTIFIKASI
-- ============================================================
function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "Info"),
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

-- ============================================================
-- GUI KECIL UNTUK KONTROL
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SudokuAutoSolver"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, 180, 0, 200)
Window.Position = UDim2.new(0, 10, 0.5, -100)
Window.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Window.BorderSizePixel = 0
Window.Active = true
Window.Draggable = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui
local corner = Instance.new("UICorner", Window)
corner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
Title.Text = "SUDOKU TOOLS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = Window

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 3)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Window
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local buttons = {
    {text = "SOLVE", y = 40, callback = autoSolveBoard},
    {text = "ESP ON", y = 80, callback = function()
        espActive = not espActive
        if espActive then
            local boardData, boardModel = getBoardFromGame()
            if boardData then
                local sol = {}
                for r = 1, 9 do sol[r] = {} for c = 1, 9 do sol[r][c] = boardData[r][c] end end
                if Sudoku.solve(sol) then
                    showESP(sol, boardModel)
                    notify("ESP", "Menampilkan solusi", 2)
                else
                    espActive = false
                    notify("Error", "Tidak ada solusi!", 3)
                end
            else
                espActive = false
                notify("Error", "Board tidak ditemukan!", 3)
            end
        else
            clearESP()
            notify("ESP", "ESP dimatikan", 2)
        end
    end},
    {text = "RESET", y = 120, callback = function()
        clearESP()
        espActive = false
        -- Muat ulang board dari game (reset ke puzzle asli) - implementasi opsional
        notify("Reset", "Board di-reset", 2)
    end},
    {text = "NEW", y = 160, callback = function()
        notify("New", "Fitur belum diimplementasikan", 2)
    end},
}

for _, btnData in ipairs(buttons) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, btnData.y)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    btn.Text = btnData.text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = Window
    local c = Instance.new("UICorner", btn)
    c.CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(btnData.callback)
end

print("Sudoku Auto-Solver & ESP loaded! Buka GUI di pojok kiri atas.")