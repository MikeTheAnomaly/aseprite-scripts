-- 1) Create a Dialog that asks the user to pick an image
local dlg = Dialog {
    title = "Select source image"
}
dlg:file{
    id = "srcfile", -- the name you’ll use to retrieve the path
    label = "Source Image:", -- label next to the file-picker button
    title = "Open Image…", -- title of the file dialog itself
    open = true, -- true = “Open” mode (vs. “Save” mode)
    filetypes = {"png", "ase", "bmp", "gif"} -- (optional) allowed extensions
}
-- Add number input for downsample size
dlg:number{
    id = "downsampleSize",
    label = "Downsample Size:",
    text = "192",
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

-- 2) Show the dialog; if the user clicks “Cancel”, bail out
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

-- Resize the sprite to the downsample size
app.transaction(function()
    app.command.SpriteSize {
        ui = false,
        width = dlg.data.downsampleSize,
        height = dlg.data.downsampleSize,
        method = "nearest"
    }
end)

local srcCel = app.activeCel
if not srcCel then
    return app.alert("No active cel!")
end
local srcImg = srcCel.image
local W, H = srcImg.width, srcImg.height

-- 2) Build visited[][]
local visited = {}
for y = 0, H - 1 do
    visited[y] = {}
    for x = 0, W - 1 do
        visited[y][x] = false
    end
end

local function inBounds(x, y)
    return x >= 0 and x < W and y >= 0 and y < H
end
local function isOpaque(x, y)
    local c = srcImg:getPixel(x, y)
    return (app.pixelColor.rgbaA(c) ~= 0)
end

local neighbors = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function floodFill(sx, sy)
    local stack = {{sx, sy}}
    local pixels = {}
    local minX, minY, maxX, maxY = sx, sy, sx, sy
    visited[sy][sx] = true

    while #stack > 0 do
        local pt = table.remove(stack)
        local x, y = pt[1], pt[2]
        table.insert(pixels, {x, y})
        if x < minX then
            minX = x
        end
        if y < minY then
            minY = y
        end
        if x > maxX then
            maxX = x
        end
        if y > maxY then
            maxY = y
        end

        for i = 1, #neighbors do
            local dx, dy = neighbors[i][1], neighbors[i][2]
            local nx, ny = x + dx, y + dy
            if inBounds(nx, ny) and (not visited[ny][nx]) and isOpaque(nx, ny) then
                visited[ny][nx] = true
                table.insert(stack, {nx, ny})
            end
        end
    end

    return {
        pixels = pixels,
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY
    }
end

-- 2.2 Find all regions
local regions = {}
for y = 0, H - 1 do
    for x = 0, W - 1 do
        if (not visited[y][x]) and isOpaque(x, y) then
            local reg = floodFill(x, y)
            table.insert(regions, reg)
        end
    end
end

-- 3) Extract each region into its own Image buffer
local regionImages = {}
for i, r in ipairs(regions) do
    local w = r.maxX - r.minX + 1
    local h = r.maxY - r.minY + 1
    local imgCopy = Image(w, h, sprite.colorMode)
    imgCopy:clear(Color {
        a = 0
    }) -- fully transparent

    for _, pt in ipairs(r.pixels) do
        local px, py = pt[1], pt[2]
        local c = srcImg:getPixel(px, py)
        imgCopy:putPixel(px - r.minX, py - r.minY, c)
    end
    table.insert(regionImages, {
        img = imgCopy,
        width = w,
        height = h
    })
end

-- 4) Create a new sprite for the grid sheet with padding
local N = #regionImages
local cellW, cellH = 32, 32 -- adjust to your desired cell size
local cols = 8 -- adjust number of columns

-- First pass: Calculate padding on a per-region basis
local multiplier = 3 -- adjust this value to control padding amount
for i, rinfo in ipairs(regionImages) do
    -- Calculate padding based on the specific region's dimensions
    local dimension = math.max(rinfo.width, rinfo.height)
    local regionPadding = math.floor((dimension % cellW) / cellW * multiplier)
    -- Store the padding value in the region info
    rinfo.padding = regionPadding
end

-- Calculate maximum dimensions needed for the sheet
local maxCols = {}  -- maximum padding per column
local maxRows = {}  -- maximum padding per row
for i, rinfo in ipairs(regionImages) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    
    maxCols[col] = math.max(maxCols[col] or 0, rinfo.padding)
    maxRows[row] = math.max(maxRows[row] or 0, rinfo.padding)
end

-- Calculate total padding for sheet size
local totalColPadding = 0
for col = 0, cols-1 do
    totalColPadding = totalColPadding + (maxCols[col] or 0)
end

local rows = math.ceil(N / cols)
local totalRowPadding = 0
for row = 0, rows-1 do
    totalRowPadding = totalRowPadding + (maxRows[row] or 0)
end

-- Calculate sheet dimensions with variable padding
local sheetW = cols * cellW + totalColPadding * cellW * 2 -- double padding between columns
local sheetH = rows * cellH + totalRowPadding * cellH * 2 -- double padding between rows
local sheetSprite = Sprite(sheetW, sheetH, sprite.colorMode)
local sheetImg = sheetSprite.cels[1].image
sheetImg:clear(Color {
    a = 0
}) -- clear to transparency

-- 5) Center each region inside its grid cell, offset by padding
-- Calculate cumulative column and row positions
local colPositions = {0} -- start position for each column
local rowPositions = {0} -- start position for each row

-- Calculate cumulative positions based on max padding per column/row
for col = 1, cols-1 do
    colPositions[col+1] = colPositions[col] + cellW + 2 * (maxCols[col-1] or 0) * cellW
end
for row = 1, rows-1 do
    rowPositions[row+1] = rowPositions[row] + cellH + 2 * (maxRows[row-1] or 0) * cellH
end

for i, rinfo in ipairs(regionImages) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    
    -- Use the pre-calculated positions plus padding for this specific region
    local cellX = colPositions[col+1] + (maxCols[col] or 0) * cellW
    local cellY = rowPositions[row+1] + (maxRows[row] or 0) * cellH

    local rw, rh = rinfo.width, rinfo.height
    local offX = cellX + math.floor((cellW - rw) / 2)
    local offY = cellY + math.floor((cellH - rh) / 2)

    sheetImg:drawImage(rinfo.img, offX, offY)
end


-- Resize the sprite to the downsample size
app.transaction(function()
    app.command.GridSettings {
        ui = false,
        grideBounds = Rectangle(0, 0, sheetW, sheetH),
    }
end)