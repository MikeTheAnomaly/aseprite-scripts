-- Sprite Sheet to Layers - Separate islands into new files with layers
-- 1) Create a Dialog that asks the user to pick an image
local dlg = Dialog {
    title = "Separate Sprite Sheet to Layers"
}
dlg:file{
    id = "srcfile",
    label = "Source Sprite Sheet:",
    title = "Open Sprite Sheet…",
    open = true,
    filetypes = {"png", "ase", "bmp", "gif"}
}
-- Add grid size input
dlg:number{
    id = "gridSize",
    label = "Grid Size:",
    text = "32",
    decimals = 0
}
dlg:button{
    id = "ok",
    text = "OK"
}
dlg:button{
    id = "cancel",
    text = "Cancel"
}

-- 2) Show the dialog; if the user clicks "Cancel", bail out
local pressed = dlg:show()
if pressed == "cancel" then
    return app.alert("Operation aborted.")
end

-- 3) Retrieve the chosen filename and open it
local filename = dlg.data.srcfile
if not filename or filename == "" then
    return app.alert("No file selected!")
end

local sprite = app.open(filename)
if not sprite then
    return app.alert("Could not open:\n" .. filename)
end

local srcCel = app.activeCel
if not srcCel then
    return app.alert("No active cel!")
end
local srcImg = srcCel.image
local W, H = srcImg.width, srcImg.height
local gridSize = dlg.data.gridSize

-- Calculate grid dimensions
local gridCols = math.floor(W / gridSize)
local gridRows = math.floor(H / gridSize)

-- Helper functions
local function inBounds(x, y)
    return x >= 0 and x < W and y >= 0 and y < H
end

local function isOpaque(x, y)
    local c = srcImg:getPixel(x, y)
    return (app.pixelColor.rgbaA(c) ~= 0)
end

local function getGridCell(x, y)
    local gridX = math.floor(x / gridSize)
    local gridY = math.floor(y / gridSize)
    return gridX, gridY
end

-- Check if a grid cell has any opaque pixels
local function gridCellHasContent(gridX, gridY)
    local startX = gridX * gridSize
    local startY = gridY * gridSize
    local endX = math.min(startX + gridSize - 1, W - 1)
    local endY = math.min(startY + gridSize - 1, H - 1)

    for y = startY, endY do
        for x = startX, endX do
            if isOpaque(x, y) then
                return true
            end
        end
    end
    return false
end

-- Build grid content map
local gridContent = {}
for gridY = 0, gridRows - 1 do
    gridContent[gridY] = {}
    for gridX = 0, gridCols - 1 do
        gridContent[gridY][gridX] = gridCellHasContent(gridX, gridY)
    end
end

-- Find connected grid islands
local gridVisited = {}
for gridY = 0, gridRows - 1 do
    gridVisited[gridY] = {}
    for gridX = 0, gridCols - 1 do
        gridVisited[gridY][gridX] = false
    end
end

local gridNeighbors = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

local function floodFillGrid(startGridX, startGridY)
    local stack = {{startGridX, startGridY}}
    local gridCells = {}
    local minGridX, minGridY = startGridX, startGridY
    local maxGridX, maxGridY = startGridX, startGridY

    gridVisited[startGridY][startGridX] = true

    while #stack > 0 do
        local pt = table.remove(stack)
        local gridX, gridY = pt[1], pt[2]
        table.insert(gridCells, {gridX, gridY})

        if gridX < minGridX then
            minGridX = gridX
        end
        if gridY < minGridY then
            minGridY = gridY
        end
        if gridX > maxGridX then
            maxGridX = gridX
        end
        if gridY > maxGridY then
            maxGridY = gridY
        end

        for i = 1, #gridNeighbors do
            local dx, dy = gridNeighbors[i][1], gridNeighbors[i][2]
            local nx, ny = gridX + dx, gridY + dy

            if nx >= 0 and nx < gridCols and ny >= 0 and ny < gridRows and not gridVisited[ny][nx] and
                gridContent[ny][nx] then
                gridVisited[ny][nx] = true
                table.insert(stack, {nx, ny})
            end
        end
    end

    return {
        gridCells = gridCells,
        minGridX = minGridX,
        minGridY = minGridY,
        maxGridX = maxGridX,
        maxGridY = maxGridY
    }
end

-- Find all grid islands
local islands = {}
for gridY = 0, gridRows - 1 do
    for gridX = 0, gridCols - 1 do
        if not gridVisited[gridY][gridX] and gridContent[gridY][gridX] then
            local island = floodFillGrid(gridX, gridY)
            table.insert(islands, island)
        end
    end
end

-- Process each island
for islandIndex, island in ipairs(islands) do
    -- Calculate island dimensions in pixels
    local islandW = (island.maxGridX - island.minGridX + 1) * gridSize
    local islandH = (island.maxGridY - island.minGridY + 1) * gridSize

    -- Create new sprite for this island
    local newSprite = Sprite(islandW, islandH, sprite.colorMode)
    newSprite.filename = string.format("Island_%d.ase", islandIndex)

    -- Extract each grid cell as a separate layer
    for _, gridCell in ipairs(island.gridCells) do
        local gridX, gridY = gridCell[1], gridCell[2]

        -- Calculate source and destination positions
        local srcX = gridX * gridSize
        local srcY = gridY * gridSize
        local dstX = (gridX - island.minGridX) * gridSize
        local dstY = (gridY - island.minGridY) * gridSize

        -- Create new layer for this grid cell
        local newLayer = newSprite:newLayer()
        newLayer.name = string.format("Cell_%d_%d", gridX, gridY)

        -- Extract the grid cell content
        local cellImg = Image(gridSize, gridSize, sprite.colorMode)
        cellImg:clear(Color {
            a = 0
        })

        -- Copy pixels from source to cell image
        for y = 0, gridSize - 1 do
            for x = 0, gridSize - 1 do
                local sx = srcX + x
                local sy = srcY + y
                if inBounds(sx, sy) then
                    local c = srcImg:getPixel(sx, sy)
                    cellImg:putPixel(x, y, c)
                end
            end
        end

        -- Create cel for the new layer
        local newCel = newSprite:newCel(newLayer, 1)
        newCel.image = cellImg
        newCel.position = Point(dstX, dstY)
    end

    -- Remove the default layer if it's empty
    if #newSprite.layers > 1 and newSprite.layers[1].name == "Layer 1" then
        newSprite:deleteLayer(newSprite.layers[1])
    end
end

app.alert(string.format("Created %d island files with separate layers!", #islands))
