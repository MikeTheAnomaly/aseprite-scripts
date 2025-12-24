-- Script to combine tileset layers with room patterns into a single optimized sprite
-- This script looks for layer names with patterns like "-room1", "-room2", etc.
-- and combines them into one sprite, cutting out empty transparency while maintaining 32x32 tile boundaries
-- Each room pattern gets its own layer in the final sprite

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

-- Function to extract room pattern from layer name
function getRoomPattern(layerName)
    local pattern = layerName:match("-room(%d+)")
    return pattern and ("-room" .. pattern) or nil
end

-- Function to group layers by room pattern
function groupLayersByRoom(layers)
    local roomGroups = {}
    local unpatternedLayers = {}
    
    for _, layer in ipairs(layers) do
        local roomPattern = getRoomPattern(layer.name)
        if roomPattern then
            if not roomGroups[roomPattern] then
                roomGroups[roomPattern] = {}
            end
            table.insert(roomGroups[roomPattern], layer)
        else
            table.insert(unpatternedLayers, layer)
        end
    end
    
    return roomGroups, unpatternedLayers
end

-- Function to find the bounding box of non-transparent pixels in 32x32 tile boundaries
function findTileBounds(image, tileSize)
    local width = image.width
    local height = image.height
    local tilesX = math.ceil(width / tileSize)
    local tilesY = math.ceil(height / tileSize)
    
    local minTileX, maxTileX = tilesX, 0
    local minTileY, maxTileY = tilesY, 0
    
    -- Check each 32x32 tile for non-transparent pixels
    for tileY = 0, tilesY - 1 do
        for tileX = 0, tilesX - 1 do
            local hasContent = false
            
            -- Check pixels within this tile
            for y = tileY * tileSize, math.min((tileY + 1) * tileSize - 1, height - 1) do
                for x = tileX * tileSize, math.min((tileX + 1) * tileSize - 1, width - 1) do
                    local pixelValue = image:getPixel(x, y)
                    if app.pixelColor.rgbaA(pixelValue) > 0 then -- Non-transparent pixel
                        hasContent = true
                        break
                    end
                end
                if hasContent then break end
            end
            
            if hasContent then
                minTileX = math.min(minTileX, tileX)
                maxTileX = math.max(maxTileX, tileX)
                minTileY = math.min(minTileY, tileY)
                maxTileY = math.max(maxTileY, tileY)
            end
        end
    end
    
    -- If no content found, return nil
    if minTileX > maxTileX then
        return nil
    end
    
    -- Convert tile coordinates back to pixel coordinates
    local bounds = {
        x = minTileX * tileSize,
        y = minTileY * tileSize,
        width = (maxTileX - minTileX + 1) * tileSize,
        height = (maxTileY - minTileY + 1) * tileSize
    }
    
    return bounds
end

-- Function to render individual layers as separate islands
function renderLayerIsland(layer, originalSprite)
    local tileSize = 32
    
    -- Hide all layers except current one
    local originalVisibility = {}
    for j, spriteLayer in ipairs(originalSprite.layers) do
        originalVisibility[j] = spriteLayer.isVisible
        spriteLayer.isVisible = (spriteLayer == layer)
    end
    
    -- Render only this tileset layer
    local layerImage = Image(originalSprite)
    
    -- Restore layer visibility
    for j, spriteLayer in ipairs(originalSprite.layers) do
        spriteLayer.isVisible = originalVisibility[j]
    end
    
    -- Find bounds for this layer
    local bounds = findTileBounds(layerImage, tileSize)
    if bounds then
        return {image = layerImage, bounds = bounds, layer = layer}
    end
    
    return nil
end

-- Get all tileset layers
local tilesetLayers = getTilesetLayers(sprite)

if #tilesetLayers == 0 then
    app.alert("No tileset layers found in the current sprite.")
    return
end

-- Group layers by room pattern
local roomGroups, unpatternedLayers = groupLayersByRoom(tilesetLayers)

-- Check if we have any room patterns
if not next(roomGroups) then
    app.alert("No layers with -room[number] patterns found. Please ensure layer names contain patterns like '-room1', '-room2', etc.")
    return
end

-- Calculate the overall bounds and layout for all individual layer islands
local layerIslands = {}
local totalWidth = 0
local maxHeight = 0
local tileSize = 32
local paddingSize = 32 -- One tile of padding

-- Process each room group's layers individually
for roomPattern, layers in pairs(roomGroups) do
    for _, layer in ipairs(layers) do
        local islandData = renderLayerIsland(layer, sprite)
        if islandData then
            islandData.offsetX = totalWidth
            islandData.roomPattern = roomPattern
            table.insert(layerIslands, islandData)
            totalWidth = totalWidth + islandData.bounds.width
            -- Add padding after each island except the last one
            if totalWidth > 0 then
                totalWidth = totalWidth + paddingSize
            end
            maxHeight = math.max(maxHeight, islandData.bounds.height)
        end
    end
end

-- Remove the extra padding from the last island
if totalWidth > 0 then
    totalWidth = totalWidth - paddingSize
end

if #layerIslands == 0 then
    app.alert("No content found in any room layers.")
    return
end

-- Create the combined sprite
local combinedSprite = Sprite(totalWidth, maxHeight, sprite.colorMode)
local baseFilename = sprite.filename or "untitled"
local cleanFilename = baseFilename:gsub("%.%w+$", "") -- Remove extension
combinedSprite.filename = cleanFilename .. "_islands"

-- Copy the palette if it exists
if sprite.palettes[1] then
    combinedSprite:setPalette(sprite.palettes[1])
end

-- Create single output layer
local outputLayer = combinedSprite:newLayer()
outputLayer.name = "Combined Islands"

-- Start a transaction for undo/redo support
app.transaction(function()
    -- Create cel for the output layer
    local outputCel = combinedSprite:newCel(outputLayer, 1)
    local outputImage = outputCel.image
    
    -- Get black color for padding
    local blackColor = app.pixelColor.rgba(0, 0, 0, 255)
    
    local currentX = 0
    
    -- Place each layer island with padding
    for i, islandData in ipairs(layerIslands) do
        local srcImage = islandData.image
        local srcBounds = islandData.bounds
        
        -- Create cropped image of just the content
        local croppedImage = Image(srcBounds.width, srcBounds.height, sprite.colorMode)
        croppedImage:drawImage(srcImage, Point(-srcBounds.x, -srcBounds.y))
        
        -- Place the island at its calculated position
        outputImage:drawImage(croppedImage, Point(currentX, 0))
        
        -- Move to next position
        currentX = currentX + srcBounds.width
        
        -- Add black padding between islands (except after the last one)
        if i < #layerIslands then
            -- Fill the padding area with black
            for x = currentX, currentX + paddingSize - 1 do
                for y = 0, maxHeight - 1 do
                    if x < totalWidth and y < maxHeight then
                        outputImage:putPixel(x, y, blackColor)
                    end
                end
            end
            currentX = currentX + paddingSize
        end
    end
end)

-- Show success message
local roomCounts = {}
for _, islandData in ipairs(layerIslands) do
    local pattern = islandData.roomPattern
    roomCounts[pattern] = (roomCounts[pattern] or 0) + 1
end

local message = string.format("Successfully created %d individual layer islands:\n", #layerIslands)
for roomPattern, count in pairs(roomCounts) do
    message = message .. string.format("• %s: %d islands\n", roomPattern, count)
end

if #unpatternedLayers > 0 then
    message = message .. string.format("\nNote: %d layers without room patterns were not processed.", #unpatternedLayers)
end

message = message .. string.format("\nFinal sprite size: %dx%d\nEach layer is a separate island with 32x32 black tile padding between them.", totalWidth, maxHeight)

app.alert(message)

-- Make the new sprite active
app.activeSprite = combinedSprite