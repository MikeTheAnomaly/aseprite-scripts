-- This script looks at a specific layer in a sprite and converts the pixel positions to Unity animation frame positions.
-- The position is found via a green dot #00FF00 pixel.
-- The rotation is found via a blue dot #0000FF pixel.
-- creates a json map of animation tag objects with frame index, position (relative to the canvas), and duration.

local LayerName = "Baked Lights"
-- Create the correct green color using app.pixelColor.rgba()
local GREEN_DOT_COLOR = app.pixelColor.rgba(0, 255, 0, 255) -- Pure green with full alpha
local BLUE_DOT_COLOR = app.pixelColor.rgba(0, 0, 255, 255) -- Pure blue with full alpha

-- Create dialog for user input
local dlg = Dialog { title = "Position to Unity Animation" }
dlg:entry{ id = "layerName", label = "Layer Name:", text = LayerName }
dlg:file{ id = "outputFile", label = "Output JSON File:", save = true, 
         filetypes = {"json"} }
dlg:separator()
dlg:button{ id = "ok", text = "Export" }
dlg:button{ id = "cancel", text = "Cancel" }
dlg:show()

if dlg.data.cancel then
    return
end

-- Get the active sprite
local sprite = app.activeSprite
if not sprite then
    return app.alert("No active sprite found!")
end

-- Get the specified layer
local targetLayer = nil
for _, layer in ipairs(sprite.layers) do
    if layer.name == dlg.data.layerName then
        targetLayer = layer
        break
    end
end

if not targetLayer then
    return app.alert("Layer '" .. dlg.data.layerName .. "' not found!")
end

-- Function to find green dot position in an image
local function findGreenDotPosition(image)
    if not image then 
        return nil
    end

    for it in image:pixels() do
        local pixelValue = it()
        -- Check if pixel matches our green color
        if pixelValue == GREEN_DOT_COLOR then
            return { x = it.x, y = it.y }
        end
        
        -- Also check for any bright green pixel (in case of slight color variations)
        local pc = app.pixelColor
        local r = pc.rgbaR(pixelValue)
        local g = pc.rgbaG(pixelValue)
        local b = pc.rgbaB(pixelValue)
        local a = pc.rgbaA(pixelValue)
        
        -- Check if it's a bright green pixel (allowing for slight variations)
        if r == 0 and g == 255 and b == 0 and a > 200 then
            return { x = it.x, y = it.y }
        end
    end
    return nil
end

-- Function to find blue dot position in an image
local function findBlueDotPosition(image)
    if not image then 
        return nil
    end

    for it in image:pixels() do
        local pixelValue = it()
        -- Check if pixel matches our blue color
        if pixelValue == BLUE_DOT_COLOR then
            return { x = it.x, y = it.y }
        end
        
        -- Also check for any bright blue pixel (in case of slight color variations)
        local pc = app.pixelColor
        local r = pc.rgbaR(pixelValue)
        local g = pc.rgbaG(pixelValue)
        local b = pc.rgbaB(pixelValue)
        local a = pc.rgbaA(pixelValue)
        
        -- Check if it's a bright blue pixel (allowing for slight variations)
        if r == 0 and g == 0 and b == 255 and a > 200 then
            return { x = it.x, y = it.y }
        end
    end
    return nil
end

-- Implement atan2 function for precision
local function atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + math.pi
        else
            return math.atan(y / x) - math.pi
        end
    else -- x == 0
        if y > 0 then
            return math.pi / 2
        elseif y < 0 then
            return -math.pi / 2
        else
            return 0 -- undefined, but we'll return 0
        end
    end
end

-- Function to calculate rotation from green dot to blue dot
-- 0° = straight up, 90° = left, 180° = down, 270° = right
local function calculateRotation(greenPos, bluePos)
    if not greenPos or not bluePos then
        return 0 -- Default rotation if dots not found
    end
    
    -- Calculate vector from green to blue
    local dx = bluePos.x - greenPos.x
    local dy = bluePos.y - greenPos.y
    
    -- Calculate angle in radians using our atan2 implementation
    -- Note: In Aseprite, Y increases downward, so we need to flip dy
    -- Also flip dx to make 90° point left instead of right
    local angleRad = atan2(-dx, -dy)
    
    -- Convert to degrees
    local angleDeg = angleRad * 180 / math.pi
    
    -- Ensure positive angle (0-360)
    if angleDeg < 0 then
        angleDeg = angleDeg + 360
    end
    
    return angleDeg
end

-- Function to get frame duration from tags
local function getFrameDuration(frameIndex, tags)
    for _, tag in ipairs(tags) do
        if frameIndex >= tag.fromFrame.frameNumber and frameIndex <= tag.toFrame.frameNumber then
            -- Calculate duration based on frame rate (default 100ms per frame)
            local frameDuration = 1.0 / 10.0 -- 100ms = 0.1 seconds
            return frameDuration
        end
    end
    return 1.0 / 10.0 -- Default duration
end

-- Build animation data
local animationData = {}
local debugInfo = {}

-- Process each frame
for frameIndex = 1, #sprite.frames do
    local frame = sprite.frames[frameIndex]
    local cel = targetLayer:cel(frameIndex)
    
    if cel then
        local greenPosition = findGreenDotPosition(cel.image)
        local bluePosition = findBlueDotPosition(cel.image)
        
        if greenPosition then
            -- Adjust position relative to cel position
            local worldPosition = {
                x = greenPosition.x + cel.position.x,
                y = greenPosition.y + cel.position.y
            }
            
            -- Calculate rotation if blue dot is found
            local rotation = 0
            if bluePosition then
                -- Adjust blue position relative to cel position for calculation
                local worldBluePosition = {
                    x = bluePosition.x + cel.position.x,
                    y = bluePosition.y + cel.position.y
                }
                rotation = calculateRotation(worldPosition, worldBluePosition)
            end
            
            local frameData = {
                frameIndex = frameIndex - 1, -- Unity uses 0-based indexing
                position = worldPosition,
                rotation = rotation,
                duration = getFrameDuration(frameIndex, sprite.tags)
            }
            
            table.insert(animationData, frameData)
        end
        
        -- Enhanced debug info
        local greenFound = greenPosition and "yes" or "no"
        local blueFound = bluePosition and "yes" or "no"
        table.insert(debugInfo, "Frame " .. frameIndex .. ": cel exists, green found: " .. greenFound .. ", blue found: " .. blueFound)
    else
        table.insert(debugInfo, "Frame " .. frameIndex .. ": no cel found")
    end
end

-- Group by animation tags
local taggedAnimations = {}
for _, tag in ipairs(sprite.tags) do
    local tagFrames = {}
    for _, frameData in ipairs(animationData) do
        local frameIndex = frameData.frameIndex + 1 -- Convert back to 1-based for comparison
        if frameIndex >= tag.fromFrame.frameNumber and frameIndex <= tag.toFrame.frameNumber then
            -- Restructure frameData to match the desired format
            local keyframe = {
                duration = frameData.duration,
                rotation = frameData.rotation,
                frameIndex = frameData.frameIndex,
                position = frameData.position
            }
            table.insert(tagFrames, keyframe)
        end
    end
    
    if #tagFrames > 0 then
        local animationSequence = {
            name = tag.name,
            keyframes = tagFrames
        }
        table.insert(taggedAnimations, animationSequence)
    end
end

-- If no tags, create a default animation
if #sprite.tags == 0 and #animationData > 0 then
    local defaultKeyframes = {}
    for _, frameData in ipairs(animationData) do
        local keyframe = {
            duration = frameData.duration,
            rotation = frameData.rotation,
            frameIndex = frameData.frameIndex,
            position = frameData.position
        }
        table.insert(defaultKeyframes, keyframe)
    end
    
    local defaultAnimation = {
        name = "Default",
        keyframes = defaultKeyframes
    }
    table.insert(taggedAnimations, defaultAnimation)
end

-- Show debug info if no animations found
if #taggedAnimations == 0 then
    local debugMsg = "No animations found!\n\n"
    debugMsg = debugMsg .. "Debug Info:\n"
    debugMsg = debugMsg .. "- Total frames: " .. #sprite.frames .. "\n"
    debugMsg = debugMsg .. "- Animation data found: " .. #animationData .. "\n"
    debugMsg = debugMsg .. "- Tags found: " .. #sprite.tags .. "\n"
    debugMsg = debugMsg .. "- Layer name: " .. dlg.data.layerName .. "\n\n"
    
    for i, info in ipairs(debugInfo) do
        debugMsg = debugMsg .. info .. "\n"
        if i > 10 then -- Limit debug output
            debugMsg = debugMsg .. "... (truncated)\n"
            break
        end
    end
    
    app.alert(debugMsg)
end

-- Convert to JSON string
local function tableToJson(t, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    local result = {}
    
    if type(t) == "table" then
        -- Check if it's an array or object
        local isArray = true
        local count = 0
        for k, v in pairs(t) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                isArray = false
                break
            end
        end
        
        if isArray then
            table.insert(result, "[")
            for i, v in ipairs(t) do
                table.insert(result, spacing .. "  " .. tableToJson(v, indent + 1))
                if i < #t then
                    table.insert(result, ",")
                end
            end
            table.insert(result, spacing .. "]")
        else
            table.insert(result, "{")
            local first = true
            for k, v in pairs(t) do
                if not first then
                    table.insert(result, ",")
                end
                first = false
                table.insert(result, spacing .. "  \"" .. tostring(k) .. "\": " .. tableToJson(v, indent + 1))
            end
            table.insert(result, spacing .. "}")
        end
    elseif type(t) == "string" then
        -- Properly escape string for JSON
        local escaped = t:gsub("\\", "\\\\")  -- Escape backslashes
        escaped = escaped:gsub("\"", "\\\"")  -- Escape quotes
        escaped = escaped:gsub("\n", "\\n")   -- Escape newlines
        escaped = escaped:gsub("\r", "\\r")   -- Escape carriage returns
        escaped = escaped:gsub("\t", "\\t")   -- Escape tabs
        return "\"" .. escaped .. "\""
    elseif type(t) == "number" then
        return tostring(t)
    elseif type(t) == "boolean" then
        return tostring(t)
    else
        return "null"
    end
    
    return table.concat(result, "\n")
end

-- Create final JSON structure
local jsonOutput = {
    spriteName = sprite.filename or "Unknown",
    layerName = dlg.data.layerName,
    spriteWidth = sprite.width,
    spriteHeight = sprite.height,
    animations = taggedAnimations,
    totalFrames = #sprite.frames,
    exportTime = os.date("%Y-%m-%d %H:%M:%S"),
    debugInfo = {
        animationDataCount = #animationData,
        tagsCount = #sprite.tags,
        layerFound = targetLayer ~= nil,
        animationsCount = #taggedAnimations
    }
}

-- Write to file
local outputPath = dlg.data.outputFile
if outputPath and outputPath ~= "" then
    local file = io.open(outputPath, "w")
    if file then
        file:write(tableToJson(jsonOutput))
        file:close()
        app.alert("Animation data exported successfully to:\n" .. outputPath)
    else
        app.alert("Failed to write to file: " .. outputPath)
    end
else
    app.alert("No output file specified!")
end