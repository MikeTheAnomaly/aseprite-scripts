-- Script to combine multiple tileset layers into a single larger tileset layer in Aseprite
-- Good for unity tilemaps or similar use cases
-- This script will take each tileset layer and combine them into one larger tileset layer. 
-- by expanding the canvas and copying over the tilesets. It will expand in a grid pattern 
-- by the size as the initial canvas size. like if there is 2 tilesets the canvas would be 2x the original size.

-- Check if there's an active sprite
if not app.activeSprite then
    app.alert("No active sprite. Please open a sprite with tileset layers.")
    return
end

local sprite = app.activeSprite

-- Function to get all tileset layers
function getTilesetLayers(sprite)
    local tilesetLayers = {}
    for i, layer in ipairs(sprite.layers) do
        if layer.isTilemap and layer.tileset then
            table.insert(tilesetLayers, layer)
        end
    end
    return tilesetLayers
end

-- Get all tileset layers
local tilesetLayers = getTilesetLayers(sprite)

if #tilesetLayers == 0 then
    app.alert("No tileset layers found in the current sprite.")
    return
end

if #tilesetLayers == 1 then
    app.alert("Only one tileset layer found. Need at least 2 tileset layers to combine.")
    return
end

-- Calculate grid dimensions (try to make it as square as possible)
local numTilesets = #tilesetLayers
local gridCols = math.ceil(math.sqrt(numTilesets))
local gridRows = math.ceil(numTilesets / gridCols)

-- Get original canvas dimensions
local originalWidth = sprite.width
local originalHeight = sprite.height

-- Calculate new canvas size
local newWidth = originalWidth * gridCols
local newHeight = originalHeight * gridRows

-- Create a new sprite with the expanded canvas
local combinedSprite = Sprite(newWidth, newHeight, sprite.colorMode)
combinedSprite.filename = sprite.filename .. "_combined"

-- Copy the palette if it exists
if sprite.palettes[1] then
    combinedSprite:setPalette(sprite.palettes[1])
end

-- Create a new regular image layer for the combined result
local combinedLayer = combinedSprite:newLayer()
combinedLayer.name = "Combined Tilesets"

-- Start a transaction for undo/redo support
app.transaction(function()
    -- Create the first cel with a new image
    local combinedCel = combinedSprite:newCel(combinedLayer, 1)
    local combinedImage = combinedCel.image
    
    -- Process each tileset layer
    for i, tilesetLayer in ipairs(tilesetLayers) do
        -- Calculate grid position (0-indexed)
        local gridIndex = i - 1
        local gridCol = gridIndex % gridCols
        local gridRow = math.floor(gridIndex / gridCols)
        
        -- Calculate destination position
        local destX = gridCol * originalWidth
        local destY = gridRow * originalHeight
        
        -- Temporarily hide all other layers
        local originalVisibility = {}
        for j, layer in ipairs(sprite.layers) do
            originalVisibility[j] = layer.isVisible
            layer.isVisible = (layer == tilesetLayer)
        end
        
        -- Render only this tileset layer
        local layerImage = Image(sprite)
        
        -- Restore layer visibility
        for j, layer in ipairs(sprite.layers) do
            layer.isVisible = originalVisibility[j]
        end
        
        -- Copy the rendered layer to the combined image at the correct position
        combinedImage:drawImage(layerImage, Point(destX, destY))
    end
end)

-- Show a success message
app.alert(string.format("Successfully combined %d tileset layers into a new sprite.\nOriginal size: %dx%d\nNew size: %dx%d\nGrid: %dx%d", 
    numTilesets, originalWidth, originalHeight, newWidth, newHeight, gridCols, gridRows))

-- Make the new sprite active
app.activeSprite = combinedSprite