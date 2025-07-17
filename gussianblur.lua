-- Powerful Blur Script for Aseprite
-- This script applies a strong blur effect to the current layer

-- Check if there's an active sprite
if not app.sprite then
    app.alert("No active sprite. Please open an image first.")
    return
end

-- Check if there's an active layer
if not app.layer or not app.layer.isImage then
    app.alert("Please select an image layer.")
    return
end

-- Function to apply simple box blur (fast and effective)
function applyBlur(image, radius, iterations)
    if radius <= 0 then
        return image:clone()
    end
    
    local width = image.width
    local height = image.height
    local result = image:clone()
    
    for iter = 1, iterations do
        local temp = result:clone()
        
        -- Iterate through each pixel
        for it in result:pixels() do
            local x, y = it.x, it.y
            local totalR, totalG, totalB, totalA = 0, 0, 0, 0
            local count = 0
            
            -- Sample pixels in a square around the current pixel
            for dy = -radius, radius do
                for dx = -radius, radius do
                    local sampleX = x + dx
                    local sampleY = y + dy
                    
                    -- Clamp to image boundaries
                    if sampleX >= 0 and sampleX < width and sampleY >= 0 and sampleY < height then
                        local pixelValue = temp:getPixel(sampleX, sampleY)
                        
                        if image.colorMode == ColorMode.RGB then
                            totalR = totalR + app.pixelColor.rgbaR(pixelValue)
                            totalG = totalG + app.pixelColor.rgbaG(pixelValue)
                            totalB = totalB + app.pixelColor.rgbaB(pixelValue)
                            totalA = totalA + app.pixelColor.rgbaA(pixelValue)
                        elseif image.colorMode == ColorMode.GRAYSCALE then
                            totalR = totalR + app.pixelColor.grayaV(pixelValue)
                            totalA = totalA + app.pixelColor.grayaA(pixelValue)
                        end
                        count = count + 1
                    end
                end
            end
            
            -- Calculate average and set new pixel
            if count > 0 then
                local newPixel
                if image.colorMode == ColorMode.RGB then
                    newPixel = app.pixelColor.rgba(
                        math.floor(totalR / count + 0.5),
                        math.floor(totalG / count + 0.5),
                        math.floor(totalB / count + 0.5),
                        math.floor(totalA / count + 0.5)
                    )
                elseif image.colorMode == ColorMode.GRAYSCALE then
                    newPixel = app.pixelColor.graya(
                        math.floor(totalR / count + 0.5),
                        math.floor(totalA / count + 0.5)
                    )
                else
                    newPixel = it()
                end
                it(newPixel)
            end
        end
    end
    
    return result
end

-- Create and show the dialog
local dlg = Dialog("Powerful Blur")
dlg:slider{
    id = "radius",
    label = "Blur Radius:",
    min = 1,
    max = 20,
    value = 2
}
dlg:slider{
    id = "iterations",
    label = "Blur Strength:",
    min = 1,
    max = 10,
    value = 3
}
dlg:separator()
dlg:button{
    id = "ok",
    text = "APPLY BLUR",
    focus = true
}
dlg:button{
    id = "cancel",
    text = "Cancel"
}

-- Show the dialog
dlg:show()

-- Process the result
local data = dlg.data
if data.ok then
    local radius = data.radius
    local iterations = data.iterations
    
    -- Start a transaction for undo support
    app.transaction("Powerful Blur", function()
        local cel = app.cel
        if cel and cel.image then
            local originalImage = cel.image
            local blurredImage = applyBlur(originalImage, radius, iterations)
            
            -- Replace the cel's image with the blurred version
            cel.image = blurredImage
        end
    end)
    
    app.refresh()
end
