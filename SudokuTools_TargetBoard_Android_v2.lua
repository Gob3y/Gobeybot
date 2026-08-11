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
-- TARGET BOARD SYSTEM
-- ============================================================

local currentBoard
local statusLabel
local selectedUserId = LocalPlayer.UserId
local allBoardESP = false
local selectedBoardESP = false

local targetESPObjects = {}
local targetLabels = {}

-- GUI toggle updater is defined later; forward-declare it for target selection.
local updateToggleButtons

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

    if ok then return cf end
    return nil
end

local function getBoardList()
    local result = {}
    local placedBoards = getPlacedBoards()
    if not placedBoards then return result end

    for _, board in ipairs(placedBoards:GetChildren()) do
        if hasBoardStructure(board) then
            local ownerId = getBoardOwnerId(board)
            if ownerId then
                local player = Players:GetPlayerByUserId(ownerId)
                table.insert(result, {
                    board = board,
                    userId = ownerId,
                    player = player,
                    name = player and player.Name or ("User " .. tostring(ownerId)),
                    display = player and player.DisplayName or "Unknown"
                })
            end
        end
    end

    table.sort(result, function(a, b)
        if a.userId == LocalPlayer.UserId then return true end
        if b.userId == LocalPlayer.UserId then return false end
        return string.lower(a.name) < string.lower(b.name)
    end)

    return result
end

local function findBoardForUser(userId)
    local placedBoards = getPlacedBoards()
    if not placedBoards then return nil end

    for _, board in ipairs(placedBoards:GetChildren()) do
        if hasBoardStructure(board) and getBoardOwnerId(board) == tonumber(userId) then
            return board
        end
    end

    return nil
end

local function refreshBoard(showNotification)
    currentBoard = getMyBoard()

    if not currentBoard then
        if statusLabel then statusLabel.Text = "Board: NOT FOUND • tekan Refresh" end
        if showNotification ~= false then
            notify("Sudoku", "Board milikmu belum ditemukan.", 3)
        end
        return nil
    end

    if not getBoardFrame(currentBoard) then
        if statusLabel then statusLabel.Text = "Board: INVALID" end
        if showNotification ~= false then
            notify("Sudoku", "Board ditemukan tetapi belum siap.", 3)
        end
        return nil
    end

    if not snapshots[currentBoard] then
        saveSnapshot(currentBoard)
    end

    local id = currentBoard:GetAttribute("BoardId")
    if statusLabel then statusLabel.Text = "Board: OK • " .. tostring(id or "?") end

    if showNotification ~= false then
        notify("Sudoku", "Board milikmu berhasil ditemukan.", 2)
    end

    return currentBoard
end

local function getSelectedBoard()
    if selectedUserId == LocalPlayer.UserId then
        return getMyBoard()
    end
    return findBoardForUser(selectedUserId)
end

local function getPlayerName(userId)
    local p = Players:GetPlayerByUserId(tonumber(userId) or -1)
    return p and p.Name or ("User " .. tostring(userId))
end

local function clearTargetESP()
    for _, obj in ipairs(targetESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(targetESPObjects)
    table.clear(targetLabels)

    pcall(function()
        local oldFolder = workspace:FindFirstChild("SudokuBoardESP")
        if oldFolder then oldFolder:Destroy() end
    end)
end

local function createBoardMarker(entry, selected)
    local cf = getBoardCFrame(entry.board)
    if not cf then return end

    local folder = workspace:FindFirstChild("SudokuBoardESP")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "SudokuBoardESP"
        folder.Parent = workspace
    end

    local marker = Instance.new("Part")
    marker.Name = "BoardMarker_" .. tostring(entry.userId)
    marker.Size = Vector3.new(0.25, 0.25, 0.25)
    marker.Transparency = 1
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.CFrame = cf * CFrame.new(0, 4.5, 0)
    marker.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SudokuBoardLabel"
    billboard.Adornee = marker
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 180, 0, 48)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.Parent = marker

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.18
    label.BackgroundColor3 = selected and Color3.fromRGB(70, 70, 90) or Color3.fromRGB(25, 25, 30)
    label.TextColor3 = selected and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.35
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextWrapped = true
    label.Text = (selected and "★ SELECTED\n" or "") .. entry.display .. "  •  @" .. entry.name
    label.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = label

    table.insert(targetESPObjects, marker)
    table.insert(targetLabels, label)
end

local function refreshTargetESP()
    clearTargetESP()

    local boards = getBoardList()
    for _, entry in ipairs(boards) do
        local isSelected = tonumber(entry.userId) == tonumber(selectedUserId)
        if allBoardESP or (selectedBoardESP and isSelected) then
            createBoardMarker(entry, isSelected)
        end
    end

    local mode = allBoardESP and "ALL" or (selectedBoardESP and "SELECTED" or "OFF")
    if statusLabel then
        statusLabel.Text = "Board ESP: " .. mode .. "  •  " .. tostring(#boards) .. " board"
    end
end

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

    -- Give the character a second safe update on mobile/streaming games.
    task.delay(0.15, function()
        pcall(function()
            local currentRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if currentRoot then currentRoot.CFrame = target end
        end)
    end)

    notify("Teleport", "Berpindah ke " .. tostring(label or "board") .. ".", 2)
    return true
end

local function selectTarget(userId)
    selectedUserId = tonumber(userId) or LocalPlayer.UserId

    -- Selecting a target makes SELECTED ESP the active target mode.
    -- It does not enable ALL ESP.
    selectedBoardESP = true

    if updateToggleButtons then
        updateToggleButtons()
    end

    refreshTargetESP()
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
local guiWidth = math.clamp(math.floor(viewportWidth * 0.40), 220, 310)
local guiHeight = math.clamp(math.floor(viewportHeight * 0.72), 390, 520)

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.new(0, guiWidth, 0, guiHeight)
Window.Position = UDim2.new(0, 12, 0.5, -guiHeight / 2)
Window.BackgroundColor3 = Color3.fromRGB(29, 29, 34)
Window.BorderSizePixel = 0
Window.Active = true
Window.ClipsDescendants = true
Window.Parent = ScreenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 12)
windowCorner.Parent = Window

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -55, 0, 40)
Title.Position = UDim2.new(0, 14, 0, 1)
Title.BackgroundTransparency = 1
Title.Text = "SUDOKU TOOLS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Window

-- Persistent OPEN button.
-- Closing the panel only hides it; the script stays alive so it can be
-- reopened without re-executing.
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 68, 0, 42)
OpenButton.Position = UDim2.new(0, 12, 0.5, -21)
OpenButton.BackgroundColor3 = Color3.fromRGB(29, 29, 34)
OpenButton.BorderSizePixel = 0
OpenButton.Text = "OPEN"
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.Font = Enum.Font.GothamBold
OpenButton.TextSize = 13
OpenButton.Visible = false
OpenButton.ZIndex = 200
OpenButton.Parent = ScreenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 10)
openCorner.Parent = OpenButton

local openStroke = Instance.new("UIStroke")
openStroke.Thickness = 2
openStroke.Transparency = 0.25
openStroke.Parent = OpenButton

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 40, 0, 40)
Close.Position = UDim2.new(1, -44, 0, 0)
Close.BackgroundTransparency = 1
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(225, 225, 225)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 24
Close.Parent = Window

local function openGUI()
    Window.Visible = true
    OpenButton.Visible = false
end

local function closeGUI()
    -- Do not disable ESP/teleport state when the panel is closed.
    Window.Visible = false
    OpenButton.Visible = true
end

Close.Activated:Connect(closeGUI)
OpenButton.Activated:Connect(openGUI)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 25)
statusLabel.Position = UDim2.new(0, 12, 0, 39)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Board: checking..."
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = Window

-- ============================================================
-- TOUCH / MOUSE DRAG
-- ============================================================

local dragging = false
local dragStart
local startPosition

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
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
-- CONTENT SCROLL
-- ============================================================

local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -73)
Content.Position = UDim2.new(0, 8, 0, 69)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Window

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = Content

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 3)
padding.PaddingRight = UDim.new(0, 3)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = Content

local function section(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 24)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(145, 145, 155)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 1
    label.Parent = Content
    return label
end

local function makeButton(text, callback, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 57)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.LayoutOrder = order
    b.Parent = Content

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
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
-- SOLVER CONTROLS
-- ============================================================

local answerESPButton
local selectedESPButton
local allESPButton

updateToggleButtons = function()
    if answerESPButton then
        answerESPButton.Text = espActive
            and "●  ANSWER ESP  •  ON"
            or "○  ANSWER ESP  •  OFF"
    end

    if selectedESPButton then
        selectedESPButton.Text = selectedBoardESP
            and "●  SELECTED BOARD ESP  •  ON"
            or "○  SELECTED BOARD ESP  •  OFF"
    end

    if allESPButton then
        allESPButton.Text = allBoardESP
            and "●  ALL BOARD ESP  •  ON"
            or "○  ALL BOARD ESP  •  OFF"
    end
end

section("SOLVE PUZZLE")

makeButton("✓  SOLVE PUZZLE  •  SERVER", function()
    local board = currentBoard or refreshBoard(false)
    if not board then return end

    local _, solution = solveBoard(board)
    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    clearESP()
    espActive = false
    updateToggleButtons()

    local ok, count, err = serverFill(board, solution, 0.10)
    if ok then
        notify("Solved", tostring(count) .. " sel dikirim ke server.", 4)
    else
        notify("Error", tostring(err), 4)
    end
end, 2)

answerESPButton = makeButton("○  ANSWER ESP  •  OFF", function()
    local board = currentBoard or refreshBoard(false)
    if not board then return end

    if espActive then
        clearESP()
        espActive = false
        updateToggleButtons()
        notify("Answer ESP", "Dimatikan.", 2)
        return
    end

    local _, solution = solveBoard(board)
    if not solution then
        notify("Error", "Puzzle tidak memiliki solusi.", 3)
        return
    end

    local count = showESP(board, solution)
    espActive = count > 0
    updateToggleButtons()

    notify(
        "Answer ESP",
        espActive
            and (tostring(count) .. " jawaban ditampilkan.")
            or "Tidak ada sel kosong.",
        3
    )
end, 3)

makeButton("↻  REFRESH MY BOARD", function()
    refreshBoard(true)
end, 4)

-- ============================================================
-- TARGET CONTROLS
-- ============================================================

section("BOARD PLAYER LAIN")

local selectedBox = Instance.new("TextButton")
selectedBox.Size = UDim2.new(1, 0, 0, 42)
selectedBox.BackgroundColor3 = Color3.fromRGB(42, 42, 49)
selectedBox.BorderSizePixel = 0
selectedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
selectedBox.Font = Enum.Font.GothamBold
selectedBox.TextSize = 12
selectedBox.TextXAlignment = Enum.TextXAlignment.Left
selectedBox.Text = "  TARGET: Memuat..."
selectedBox.LayoutOrder = 5
selectedBox.Parent = Content

local selectedCorner = Instance.new("UICorner")
selectedCorner.CornerRadius = UDim.new(0, 8)
selectedCorner.Parent = selectedBox

local dropdownArrow = Instance.new("TextLabel")
dropdownArrow.Size = UDim2.new(0, 35, 1, 0)
dropdownArrow.Position = UDim2.new(1, -38, 0, 0)
dropdownArrow.BackgroundTransparency = 1
dropdownArrow.Text = "▼"
dropdownArrow.TextColor3 = Color3.fromRGB(190, 190, 200)
dropdownArrow.Font = Enum.Font.GothamBold
dropdownArrow.TextSize = 12
dropdownArrow.Parent = selectedBox


local TargetList = Instance.new("ScrollingFrame")
TargetList.Name = "TargetList"
TargetList.Size = UDim2.new(1, 0, 0, 150)
TargetList.BackgroundColor3 = Color3.fromRGB(35, 35, 41)
TargetList.BorderSizePixel = 0
TargetList.ScrollBarThickness = 4
TargetList.Visible = false
TargetList.LayoutOrder = 6
TargetList.Parent = Content

local targetListCorner = Instance.new("UICorner")
targetListCorner.CornerRadius = UDim.new(0, 8)
targetListCorner.Parent = TargetList

local targetLayout = Instance.new("UIListLayout")
targetLayout.Padding = UDim.new(0, 4)
targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetLayout.Parent = TargetList

local targetPadding = Instance.new("UIPadding")
targetPadding.PaddingTop = UDim.new(0, 5)
targetPadding.PaddingLeft = UDim.new(0, 5)
targetPadding.PaddingRight = UDim.new(0, 5)
targetPadding.PaddingBottom = UDim.new(0, 5)
targetPadding.Parent = TargetList

local function updateSelectedText()
    local player = Players:GetPlayerByUserId(tonumber(selectedUserId) or -1)
    if player then
        local own = player == LocalPlayer and "  (YOU)" or ""
        selectedBox.Text = "  TARGET: " .. player.DisplayName .. "  •  @" .. player.Name .. own
    else
        selectedBox.Text = "  TARGET: User " .. tostring(selectedUserId)
    end
end

local function rebuildTargetList()
    for _, child in ipairs(TargetList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local boards = getBoardList()

    for index, entry in ipairs(boards) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, 0, 0, 34)
        item.BackgroundColor3 = (entry.userId == selectedUserId)
            and Color3.fromRGB(70, 65, 48)
            or Color3.fromRGB(49, 49, 56)
        item.BorderSizePixel = 0
        item.TextColor3 = Color3.fromRGB(245, 245, 245)
        item.Font = Enum.Font.Gotham
        item.TextSize = 11
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.Text = "  " .. (entry.userId == LocalPlayer.UserId and "★ " or "• ") .. entry.display .. "  @" .. entry.name
        item.LayoutOrder = index
        item.Parent = TargetList

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = item

        item.Activated:Connect(function()
            selectTarget(entry.userId)
            updateSelectedText()
            TargetList.Visible = false
            dropdownArrow.Text = "▼"
        end)
    end

    TargetList.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #boards * 38 + 10))
    updateSelectedText()
end

selectedBox.Activated:Connect(function()
    TargetList.Visible = not TargetList.Visible
    dropdownArrow.Text = TargetList.Visible and "▲" or "▼"
    if TargetList.Visible then rebuildTargetList() end
end)

selectedESPButton = makeButton("○  SELECTED BOARD ESP  •  OFF", function()
    selectedBoardESP = not selectedBoardESP
    updateToggleButtons()
    refreshTargetESP()

    notify(
        "Selected Board ESP",
        selectedBoardESP
            and ("ON • " .. getPlayerName(selectedUserId))
            or "OFF",
        2
    )
end, 7)

allESPButton = makeButton("○  ALL BOARD ESP  •  OFF", function()
    allBoardESP = not allBoardESP
    updateToggleButtons()
    refreshTargetESP()

    notify(
        "All Board ESP",
        allBoardESP and "ON • semua board terdeteksi" or "OFF",
        2
    )
end, 8)

makeButton("➤  TELEPORT TO SELECTED", function()
    local board = getSelectedBoard()
    local name = getPlayerName(selectedUserId)
    teleportToBoard(board, name)
end, 9)

makeButton("⌂  TELEPORT TO MY BOARD", function()
    local board = getMyBoard()
    if board then
        currentBoard = board
        teleportToBoard(board, "My Board")
    else
        notify("Teleport", "Board milikmu tidak ditemukan.", 3)
    end
end, 10)

makeButton("↻  REFRESH PLAYER BOARDS", function()
    rebuildTargetList()
    refreshTargetESP()
    notify("Targets", tostring(#getBoardList()) .. " board player terdeteksi.", 2)
end, 11)

section("INFO")
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 48)
info.BackgroundTransparency = 1
info.Text = "Pilih player di TARGET lalu gunakan ESP SELECTED atau TELEPORT.\nESP ALL menampilkan semua board yang sedang terlihat."
info.TextColor3 = Color3.fromRGB(145, 145, 155)
info.Font = Enum.Font.Gotham
info.TextSize = 10
info.TextWrapped = true
info.TextXAlignment = Enum.TextXAlignment.Left
info.LayoutOrder = 12
info.Parent = Content

-- ============================================================
-- INITIAL STATE
-- ============================================================

selectedUserId = LocalPlayer.UserId
rebuildTargetList()
updateToggleButtons()

-- Initial board check. The game's currentBoardId can be populated slightly later.
task.spawn(function()
    for _ = 1, 10 do
        task.wait(0.5)
        currentBoard = getMyBoard()
        if currentBoard then break end
    end

    if currentBoard then
        saveSnapshot(currentBoard)
        local id = currentBoard:GetAttribute("BoardId")
        statusLabel.Text = "Board: OK • " .. tostring(id or "?")
        notify("Sudoku Ready", "Board berhasil dideteksi.", 3)
    else
        statusLabel.Text = "Board: NOT FOUND • tekan Refresh"
    end
end)

-- Keep the target list in sync when players join/leave or boards spawn/despawn.
task.spawn(function()
    local boardsFolder = getPlacedBoards()
    if boardsFolder then
        boardsFolder.ChildAdded:Connect(function()
            task.wait(0.2)
            rebuildTargetList()
            if allBoardESP or selectedBoardESP then refreshTargetESP() end
        end)

        boardsFolder.ChildRemoved:Connect(function()
            task.wait(0.1)
            rebuildTargetList()
            if allBoardESP or selectedBoardESP then refreshTargetESP() end
        end)
    end

    Players.PlayerAdded:Connect(function()
        task.wait(0.2)
        rebuildTargetList()
    end)

    Players.PlayerRemoving:Connect(function(player)
        if player.UserId == selectedUserId then
            selectedUserId = LocalPlayer.UserId
        end
        task.wait(0.1)
        rebuildTargetList()
        if allBoardESP or selectedBoardESP then refreshTargetESP() end
    end)
end)

print("==========================================")
print(" Sudoku Tools - Target Board Edition")
print(" Solver + Answer ESP + Player Board ESP")
print(" Selected Target + Teleport")
print("==========================================")
