-- Selection to No Transparent Script
-- This script takes the current selection and sets all pixels to full alpha (1.0)
function main()
    -- Get the active sprite
    local sprite = app.activeSprite
    if not sprite then
        app.alert("No active sprite found!")
        return
    end

    -- Get the active cel and layer
    local cel = app.activeCel
    local layer = app.activeLayer
    if not cel then
        app.alert("No active cel found!")
        return
    end

    -- Get the selection bounds
    local selection = sprite.selection
    if selection.isEmpty then
        app.alert("No selection found! Please make a selection first.")
        return
    end

    -- Get the selection bounds
    local bounds = selection.bounds

    -- Check if we're working with a tilemap layer
    local isTilemap = layer.isTilemap
    local image = nil
    local tileset = nil

    if isTilemap then
        -- For tilemap layers, we need to work with the tileset
        tileset = layer.tileset
        if not tileset then
            app.alert("No tileset found for the tilemap layer!")
            return
        end
        -- We'll get the tile image later based on the selection
    else
        -- For regular layers, get the image from the cel
        image = cel.image
        if not image then
            app.alert("No image found in the active cel!")
            return
        end
    end

    -- Start transaction for undo support
    app.transaction(function()
        if isTilemap then
            -- Handle tilemap layers
            local tilemapImage = cel.image
            local processedTiles = {} -- Track which tiles we've already processed

            -- Iterate through each pixel in the selection bounds
            for y = bounds.y, bounds.y + bounds.height - 1 do
                for x = bounds.x, bounds.x + bounds.width - 1 do
                    -- Check if this pixel is actually in the selection
                    if selection:contains(x, y) then
                        -- Convert to cel-relative coordinates
                        local celX = x - cel.position.x
                        local celY = y - cel.position.y

                        -- Check if the pixel is within the tilemap bounds
                        if celX >= 0 and celX < tilemapImage.width and celY >= 0 and celY < tilemapImage.height then
                            -- Get the tile index at this position
                            local tileIndex = tilemapImage:getPixel(celX, celY)

                            -- Only process if there's a tile and we haven't processed it yet
                            if tileIndex > 0 and not processedTiles[tileIndex] then
                                processedTiles[tileIndex] = true

                                -- Get the tile from the tileset
                                local tile = tileset:tile(tileIndex)
                                if tile then
                                    local tileImage = tile.image
                                    
                                    -- Clone the tile image to work with it properly
                                    local clonedImage = tileImage:clone()
                                    
                                    -- Process all pixels in this tile
                                    for tileY = 0, clonedImage.height - 1 do
                                        for tileX = 0, clonedImage.width - 1 do
                                            local pixelColor = clonedImage:getPixel(tileX, tileY)

                                            -- Only modify if the pixel has some color (not completely transparent)
                                            if pixelColor ~= 0 then
                                                -- Create a new color with full alpha
                                                local color = Color(pixelColor)
                                                color.alpha = 255 -- Set alpha to full opacity

                                                -- Set the pixel with the new color
                                                clonedImage:putPixel(tileX, tileY, color)
                                            end
                                        end
                                    end
                                    
                                    -- Assign the modified image back to the tile
                                    tile.image = clonedImage
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Handle regular layers
            -- Iterate through each pixel in the selection bounds
            for y = bounds.y, bounds.y + bounds.height - 1 do
                for x = bounds.x, bounds.x + bounds.width - 1 do
                    -- Check if this pixel is actually in the selection
                    if selection:contains(x, y) then
                        -- Convert to cel-relative coordinates
                        local celX = x - cel.position.x
                        local celY = y - cel.position.y

                        -- Check if the pixel is within the image bounds
                        if celX >= 0 and celX < image.width and celY >= 0 and celY < image.height then
                            -- Get the current pixel color
                            local pixelColor = image:getPixel(celX, celY)

                            -- Only modify if the pixel has some color (not completely transparent)
                            if pixelColor ~= 0 then
                                -- Create a new color with full alpha
                                local color = Color(pixelColor)
                                color.alpha = 255 -- Set alpha to full opacity (255 = 1.0 in 0-255 range)

                                -- Set the pixel with the new color
                                image:putPixel(celX, celY, color)
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Refresh the sprite to show changes
    app.refresh()

    -- Show success message
    if isTilemap then
        app.alert("Tilemap tiles in selection set to full opacity!")
    else
        app.alert("Selection pixels set to full opacity!")
    end
end

-- Run the main function
main()
