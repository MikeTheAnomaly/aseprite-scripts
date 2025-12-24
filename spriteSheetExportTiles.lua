-- Export sprite sheet tiles as individual PNGs by grid size
local dlg = Dialog { title = "Export Sprite Sheet Tiles" }

-- Input options
dlg:file{
    id = "srcfile",
    label = "Sprite Sheet:",
    title = "Open Sprite Sheet…",
    open = true,
    filetypes = {"png", "ase", "bmp", "gif"}
}
dlg:number{
    id = "tileW",
    label = "Tile Width:",
    text = "32",
    decimals = 0
}
dlg:number{
    id = "tileH",
    label = "Tile Height:",
    text = "32",
    decimals = 0
}
dlg:entry{
    id = "prefix",
    label = "Name Prefix:",
    text = "tile"
}
dlg:check{
    id = "skipEmpty",
    label = "Skip Empty Tiles",
    selected = true
}
dlg:button{ id = "ok", text = "Export" }
dlg:button{ id = "cancel", text = "Cancel" }

local pressed = dlg:show()
if pressed == "cancel" then
    return app.alert("Operation aborted.")
end

local filename = dlg.data.srcfile
if not filename or filename == "" then
    return app.alert("No file selected!")
end

local tileW = tonumber(dlg.data.tileW) or 0
local tileH = tonumber(dlg.data.tileH) or 0
if tileW <= 0 or tileH <= 0 then
    return app.alert("Tile width/height must be > 0.")
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
local cols = math.floor(W / tileW)
local rows = math.floor(H / tileH)
if cols == 0 or rows == 0 then
    return app.alert("Tile size is larger than the sprite sheet.")
end

local prefix = dlg.data.prefix
if not prefix or prefix == "" then
    prefix = "tile"
end

local baseName = app.fs.fileTitle(filename)
local dirPath = app.fs.filePath(filename)
local remainderW = W % tileW
local remainderH = H % tileH
local totalExported, totalSkipped = 0, 0
local tileIndex = 0

local function copyTile(col, row)
    local tileImg = Image(tileW, tileH, sprite.colorMode)
    tileImg:clear(Color { a = 0 })

    local hasContent = false
    local startX = col * tileW
    local startY = row * tileH
    for y = 0, tileH - 1 do
        for x = 0, tileW - 1 do
            local srcX = startX + x
            local srcY = startY + y
            local c = srcImg:getPixel(srcX, srcY)
            if app.pixelColor.rgbaA(c) ~= 0 then
                hasContent = true
            end
            tileImg:putPixel(x, y, c)
        end
    end

    return tileImg, hasContent
end

for row = 0, rows - 1 do
    for col = 0, cols - 1 do
        local tileImg, hasContent = copyTile(col, row)
        if dlg.data.skipEmpty and not hasContent then
            totalSkipped = totalSkipped + 1
        else
            tileIndex = tileIndex + 1
            local outName = string.format("%s_%s_%03d.png", baseName, prefix, tileIndex)
            local outPath = app.fs.joinPath(dirPath, outName)

            -- Save via temporary sprite to preserve color mode/indexed palettes
            local tileSprite = Sprite(tileW, tileH, sprite.colorMode)
            tileSprite.cels[1].image = tileImg
            tileSprite.filename = outPath
            tileSprite:saveCopyAs(outPath)
            tileSprite:close()

            totalExported = totalExported + 1
        end
    end
end

local message = string.format(
    "Exported %d tiles to:\n%s\nSkipped %d empty tiles.",
    totalExported,
    dirPath,
    totalSkipped
)
if remainderW ~= 0 or remainderH ~= 0 then
    message = message .. string.format("\nIgnored remainder area (%d px wide, %d px tall).", remainderW, remainderH)
end
app.alert(message)
