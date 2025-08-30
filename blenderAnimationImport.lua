-- Blender Animation Import Script for Aseprite
-- This script imports Blender render manifest JSON files and creates organized sprites with layers and animation tags
-- Each object becomes a layer, each animation/rotation combination becomes a separate animation tag

-- Create dialog for user input
local dlg = Dialog { title = "Blender Animation Import" }
dlg:file{ id = "manifestFile", label = "Manifest JSON File:", open = true, 
         filetypes = {"json"} }
dlg:separator()
dlg:button{ id = "ok", text = "Import" }
dlg:button{ id = "cancel", text = "Cancel" }
dlg:show()

if dlg.data.cancel then
    return
end

-- Check if manifest file is provided
local manifestPath = dlg.data.manifestFile
if not manifestPath or manifestPath == "" then
    return app.alert("No manifest file selected!")
end

-- Function to read JSON file
local function readJsonFile(filePath)
    local file = io.open(filePath, "r")
    if not file then
        return nil, "Could not open file: " .. filePath
    end
    
    local content = file:read("*all")
    file:close()

    return content
end

-- Simple JSON parser for manifest structure
local function parseJson(jsonString)
    -- app.alert("DEBUG: Starting JSON parsing...\nJSON length: " .. #jsonString .. " characters")
    
    -- This is a completely rewritten parser that handles the actual manifest structure
    local manifest = {}
    
    -- Extract basic info
    manifest.base_folder = jsonString:match('"base_folder"%s*:%s*"([^"]*)"')
    manifest.animations = {}
    
    -- app.alert("DEBUG: Extracted base_folder: " .. (manifest.base_folder or "nil"))
    
    -- Find the animations array start and end more robustly
    local animStart = jsonString:find('"animations"%s*:%s*%[')
    if not animStart then
        -- app.alert("DEBUG: Could not find animations array start")
        return nil, "Could not find animations array"
    end
    
    -- app.alert("DEBUG: Found animations array at position: " .. animStart)
    
    -- Find the matching closing bracket for animations array
    local animArrayStart = jsonString:find('%[', animStart)
    local depth = 1
    local pos = animArrayStart + 1
    local animEnd = nil
    
    while pos <= #jsonString and depth > 0 do
        local char = jsonString:sub(pos, pos)
        if char == '[' then
            depth = depth + 1
        elseif char == ']' then
            depth = depth - 1
            if depth == 0 then
                animEnd = pos
                break
            end
        elseif char == '"' then
            -- Skip over strings to avoid matching brackets inside strings
            pos = pos + 1
            while pos <= #jsonString do
                local nextChar = jsonString:sub(pos, pos)
                if nextChar == '"' and jsonString:sub(pos-1, pos-1) ~= '\\' then
                    break
                end
                pos = pos + 1
            end
        end
        pos = pos + 1
    end
    
    if not animEnd then
        -- app.alert("DEBUG: Could not find end of animations array")
        return nil, "Could not find end of animations array"
    end
    
    local animationsSection = jsonString:sub(animArrayStart + 1, animEnd - 1)
    -- app.alert("DEBUG: Extracted animations section, length: " .. #animationsSection)
    
    -- Now parse individual animation objects using a more robust approach
    local animCount = 0
    local currentPos = 1
    
    -- Find each animation object by looking for "name" fields at the top level
    while currentPos <= #animationsSection do
        -- Find the start of the next animation object
        local objStart = animationsSection:find('{%s*"name"', currentPos)
        if not objStart then
            break
        end
        
        -- Find the matching closing brace for this animation object
        local objDepth = 1
        local objPos = objStart + 1
        local objEnd = nil
        
        while objPos <= #animationsSection and objDepth > 0 do
            local char = animationsSection:sub(objPos, objPos)
            if char == '{' then
                objDepth = objDepth + 1
            elseif char == '}' then
                objDepth = objDepth - 1
                if objDepth == 0 then
                    objEnd = objPos
                    break
                end
            elseif char == '"' then
                -- Skip over strings
                objPos = objPos + 1
                while objPos <= #animationsSection do
                    local nextChar = animationsSection:sub(objPos, objPos)
                    if nextChar == '"' and animationsSection:sub(objPos-1, objPos-1) ~= '\\' then
                        break
                    end
                    objPos = objPos + 1
                end
            end
            objPos = objPos + 1
        end
        
        if objEnd then
            animCount = animCount + 1
            local animBlock = animationsSection:sub(objStart, objEnd)
            -- app.alert("DEBUG: Processing animation " .. animCount .. ", block length: " .. #animBlock)
            
            local anim = {}
            
            -- Extract animation properties using simple string matching
            anim.name = animBlock:match('"name"%s*:%s*"([^"]*)"')
            anim.strip_frame_count = tonumber(animBlock:match('"strip_frame_count"%s*:%s*(%d+)'))
            anim.objects = {}
            
            -- app.alert("DEBUG: Animation name: " .. (anim.name or "nil") .. ", frame count: " .. (anim.strip_frame_count or "nil"))
            
            -- Find the objects array within this animation
            local objArrayStart = animBlock:find('"objects"%s*:%s*%[')
            if objArrayStart then
                local objArrayBracket = animBlock:find('%[', objArrayStart)
                local objDepth = 1
                local objArrayPos = objArrayBracket + 1
                local objArrayEnd = nil
                
                while objArrayPos <= #animBlock and objDepth > 0 do
                    local char = animBlock:sub(objArrayPos, objArrayPos)
                    if char == '[' then
                        objDepth = objDepth + 1
                    elseif char == ']' then
                        objDepth = objDepth - 1
                        if objDepth == 0 then
                            objArrayEnd = objArrayPos
                            break
                        end
                    elseif char == '"' then
                        -- Skip strings
                        objArrayPos = objArrayPos + 1
                        while objArrayPos <= #animBlock do
                            local nextChar = animBlock:sub(objArrayPos, objArrayPos)
                            if nextChar == '"' and animBlock:sub(objArrayPos-1, objArrayPos-1) ~= '\\' then
                                break
                            end
                            objArrayPos = objArrayPos + 1
                        end
                    end
                    objArrayPos = objArrayPos + 1
                end
                
                if objArrayEnd then
                    local objectsSection = animBlock:sub(objArrayBracket + 1, objArrayEnd - 1)
                    -- app.alert("DEBUG: Found objects section for animation: " .. (anim.name or "unknown") .. ", length: " .. #objectsSection)
                    
                    -- Parse objects within this animation
                    local objCurrentPos = 1
                    local objCount = 0
                    
                    while objCurrentPos <= #objectsSection do
                        local objObjStart = objectsSection:find('{%s*"name"', objCurrentPos)
                        if not objObjStart then
                            break
                        end
                        
                        -- Find matching brace for this object
                        local objObjDepth = 1
                        local objObjPos = objObjStart + 1
                        local objObjEnd = nil
                        
                        while objObjPos <= #objectsSection and objObjDepth > 0 do
                            local char = objectsSection:sub(objObjPos, objObjPos)
                            if char == '{' then
                                objObjDepth = objObjDepth + 1
                            elseif char == '}' then
                                objObjDepth = objObjDepth - 1
                                if objObjDepth == 0 then
                                    objObjEnd = objObjPos
                                    break
                                end
                            elseif char == '"' then
                                -- Skip strings
                                objObjPos = objObjPos + 1
                                while objObjPos <= #objectsSection do
                                    local nextChar = objectsSection:sub(objObjPos, objObjPos)
                                    if nextChar == '"' and objectsSection:sub(objObjPos-1, objObjPos-1) ~= '\\' then
                                        break
                                    end
                                    objObjPos = objObjPos + 1
                                end
                            end
                            objObjPos = objObjPos + 1
                        end
                        
                        if objObjEnd then
                            objCount = objCount + 1
                            local objBlock = objectsSection:sub(objObjStart, objObjEnd)
                            
                            local obj = {}
                            obj.name = objBlock:match('"name"%s*:%s*"([^"]*)"')
                            obj.rotations = {}
                            
                            -- app.alert("DEBUG: Object " .. objCount .. " name: " .. (obj.name or "nil"))
                            
                            -- Find rotations array for this object
                            local rotArrayStart = objBlock:find('"rotations"%s*:%s*%[')
                            if rotArrayStart then
                                local rotArrayBracket = objBlock:find('%[', rotArrayStart)
                                local rotDepth = 1
                                local rotArrayPos = rotArrayBracket + 1
                                local rotArrayEnd = nil
                                
                                while rotArrayPos <= #objBlock and rotDepth > 0 do
                                    local char = objBlock:sub(rotArrayPos, rotArrayPos)
                                    if char == '[' then
                                        rotDepth = rotDepth + 1
                                    elseif char == ']' then
                                        rotDepth = rotDepth - 1
                                        if rotDepth == 0 then
                                            rotArrayEnd = rotArrayPos
                                            break
                                        end
                                    elseif char == '"' then
                                        -- Skip strings
                                        rotArrayPos = rotArrayPos + 1
                                        while rotArrayPos <= #objBlock do
                                            local nextChar = objBlock:sub(rotArrayPos, rotArrayPos)
                                            if nextChar == '"' and objBlock:sub(rotArrayPos-1, rotArrayPos-1) ~= '\\' then
                                                break
                                            end
                                            rotArrayPos = rotArrayPos + 1
                                        end
                                    end
                                    rotArrayPos = rotArrayPos + 1
                                end
                                
                                if rotArrayEnd then
                                    local rotationsSection = objBlock:sub(rotArrayBracket + 1, rotArrayEnd - 1)
                                    -- app.alert("DEBUG: Found rotations for " .. (obj.name or "unknown") .. ", length: " .. #rotationsSection)
                                    
                                    -- Parse individual rotation objects
                                    local rotCurrentPos = 1
                                    local rotCount = 0
                                    
                                    while rotCurrentPos <= #rotationsSection do
                                        local rotObjStart = rotationsSection:find('{', rotCurrentPos)
                                        if not rotObjStart then
                                            break
                                        end
                                        
                                        -- Find matching brace
                                        local rotObjDepth = 1
                                        local rotObjPos = rotObjStart + 1
                                        local rotObjEnd = nil
                                        
                                        while rotObjPos <= #rotationsSection and rotObjDepth > 0 do
                                            local char = rotationsSection:sub(rotObjPos, rotObjPos)
                                            if char == '{' then
                                                rotObjDepth = rotObjDepth + 1
                                            elseif char == '}' then
                                                rotObjDepth = rotObjDepth - 1
                                                if rotObjDepth == 0 then
                                                    rotObjEnd = rotObjPos
                                                    break
                                                end
                                            elseif char == '"' then
                                                -- Skip strings
                                                rotObjPos = rotObjPos + 1
                                                while rotObjPos <= #rotationsSection do
                                                    local nextChar = rotationsSection:sub(rotObjPos, rotObjPos)
                                                    if nextChar == '"' and rotationsSection:sub(rotObjPos-1, rotObjPos-1) ~= '\\' then
                                                        break
                                                    end
                                                    rotObjPos = rotObjPos + 1
                                                end
                                            end
                                            rotObjPos = rotObjPos + 1
                                        end
                                        
                                        if rotObjEnd then
                                            rotCount = rotCount + 1
                                            local rotBlock = rotationsSection:sub(rotObjStart, rotObjEnd)
                                            
                                            local rot = {}
                                            rot.rotation_deg = tonumber(rotBlock:match('"rotation_deg"%s*:%s*(%d+)'))
                                            rot.folder = rotBlock:match('"folder"%s*:%s*"([^"]*)"')
                                            rot.frame_files_count = tonumber(rotBlock:match('"frame_files_count"%s*:%s*(%d+)'))
                                            
                                            -- Extract the frames array with actual file paths
                                            rot.frames = {}
                                            local framesArrayStart = rotBlock:find('"frames"%s*:%s*%[')
                                            if framesArrayStart then
                                                local framesArrayBracket = rotBlock:find('%[', framesArrayStart)
                                                local framesDepth = 1
                                                local framesArrayPos = framesArrayBracket + 1
                                                local framesArrayEnd = nil
                                                
                                                while framesArrayPos <= #rotBlock and framesDepth > 0 do
                                                    local char = rotBlock:sub(framesArrayPos, framesArrayPos)
                                                    if char == '[' then
                                                        framesDepth = framesDepth + 1
                                                    elseif char == ']' then
                                                        framesDepth = framesDepth - 1
                                                        if framesDepth == 0 then
                                                            framesArrayEnd = framesArrayPos
                                                            break
                                                        end
                                                    elseif char == '"' then
                                                        -- Skip strings
                                                        framesArrayPos = framesArrayPos + 1
                                                        while framesArrayPos <= #rotBlock do
                                                            local nextChar = rotBlock:sub(framesArrayPos, framesArrayPos)
                                                            if nextChar == '"' and rotBlock:sub(framesArrayPos-1, framesArrayPos-1) ~= '\\' then
                                                                break
                                                            end
                                                            framesArrayPos = framesArrayPos + 1
                                                        end
                                                    end
                                                    framesArrayPos = framesArrayPos + 1
                                                end
                                                
                                                if framesArrayEnd then
                                                    local framesSection = rotBlock:sub(framesArrayBracket + 1, framesArrayEnd - 1)
                                                    -- app.alert("DEBUG: Frames section content (first 200 chars): " .. framesSection:sub(1, 200))
                                                    
                                                    -- The frames array appears to be empty or contains metadata
                                                    -- Let's generate frame paths based on the folder and frame count
                                                    if framesSection:match("^%s*$") then
                                                        -- Empty frames array - generate paths from folder and count
                                                        -- app.alert("DEBUG: Frames array is empty, generating paths from folder")
                                                        for i = 0, rot.frame_files_count - 1 do
                                                            -- Try common naming patterns
                                                            local frameFile = rot.folder .. "/" .. string.format("%04d.png", i)
                                                            table.insert(rot.frames, frameFile)
                                                        end
                                                    else
                                                        -- Try to extract frame objects if they exist
                                                        -- app.alert("DEBUG: Trying to parse frame objects from frames array")
                                                        -- Look for frame objects with "absolute_path" or similar
                                                        for frameObj in framesSection:gmatch('{[^{}]*}') do
                                                            local framePath = frameObj:match('"absolute_path"%s*:%s*"([^"]*)"')
                                                            if not framePath then
                                                                framePath = frameObj:match('"filename"%s*:%s*"([^"]*)"')
                                                                if framePath and rot.folder then
                                                                    framePath = rot.folder .. "/" .. framePath
                                                                end
                                                            end
                                                            if framePath and framePath ~= "" then
                                                                table.insert(rot.frames, framePath)
                                                            end
                                                        end
                                                        
                                                        -- If still no frames found, fall back to folder scanning
                                                        if #rot.frames == 0 then
                                                            -- app.alert("DEBUG: No frame paths found in objects, generating from folder")
                                                            for i = 0, rot.frame_files_count - 1 do
                                                                local frameFile = rot.folder .. "/" .. string.format("%04d.png", i)
                                                                table.insert(rot.frames, frameFile)
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                -- No frames array found - generate paths from folder
                                                -- app.alert("DEBUG: No frames array found, generating paths from folder")
                                                for i = 0, rot.frame_files_count - 1 do
                                                    local frameFile = rot.folder .. "/" .. string.format("%04d.png", i)
                                                    table.insert(rot.frames, frameFile)
                                                end
                                            end
                                            
                                            if rot.rotation_deg and rot.folder and rot.frame_files_count then
                                                table.insert(obj.rotations, rot)
                                                -- app.alert("DEBUG: Added rotation " .. rot.rotation_deg .. "° with " .. rot.frame_files_count .. " frames, " .. #rot.frames .. " frame paths")
                                            end
                                            
                                            rotCurrentPos = rotObjEnd + 1
                                        else
                                            break
                                        end
                                    end
                                    
                                    -- app.alert("DEBUG: Found " .. #obj.rotations .. " valid rotations for " .. (obj.name or "unknown"))
                                end
                            end
                            
                            if obj.name and #obj.rotations > 0 then
                                table.insert(anim.objects, obj)
                            end
                            
                            objCurrentPos = objObjEnd + 1
                        else
                            break
                        end
                    end
                    
                    -- app.alert("DEBUG: Found " .. #anim.objects .. " valid objects for animation: " .. (anim.name or "unknown"))
                end
            end
            
            if anim.name and #anim.objects > 0 then
                table.insert(manifest.animations, anim)
            end
            
            currentPos = objEnd + 1
        else
            break
        end
    end
    
    app.alert("DEBUG: Total animations parsed: " .. #manifest.animations)
    
    return manifest
end

-- Function to load images from frame paths
local function loadImagesFromFramePaths(framePaths, folderPath, frameCount)
    local images = {}
    
    -- app.alert("DEBUG: Loading images - frame paths count: " .. #framePaths .. ", expected count: " .. frameCount)
    
    -- If we have direct frame paths, use them
    if #framePaths > 0 then
        for i, framePath in ipairs(framePaths) do
            -- app.alert("DEBUG: Loading frame " .. i .. ": " .. framePath)
            
            -- Try the direct path first
            local success, image = pcall(function()
                return Image{ fromFile = framePath }
            end)
            
            if success and image then
                table.insert(images, image)
                -- app.alert("DEBUG: Successfully loaded frame " .. i)
            else
                -- app.alert("DEBUG: Failed to load frame " .. i .. ": " .. framePath)
                
                -- Try alternative extensions if the direct path failed
                local basePath = framePath:match("(.+)%.[^%.]+$") or framePath
                local extensions = {".png", ".jpg", ".jpeg", ".bmp", ".tga"}
                local loaded = false
                
                for _, ext in ipairs(extensions) do
                    local altPath = basePath .. ext
                    local success2, image2 = pcall(function()
                        return Image{ fromFile = altPath }
                    end)
                    
                    if success2 and image2 then
                        table.insert(images, image2)
                        app.alert("DEBUG: Loaded with alternative extension: " .. altPath)
                        loaded = true
                        break
                    end
                end
                
                if not loaded then
                    app.alert("DEBUG: Could not load frame " .. i .. " with any known extension" .. ": " .. framePath)
                    table.insert(images, nil)
                end
            end
        end
    else
        -- Fallback to the old method if no frame paths are available
        app.alert("DEBUG: No frame paths found, falling back to folder scanning")
        
        local extensions = {".png", ".jpg", ".jpeg", ".bmp", ".tga"}
        
        for frame = 0, frameCount - 1 do
            local imageLoaded = false
            
            for _, ext in ipairs(extensions) do
                local possiblePaths = {
                    folderPath .. "/" .. string.format("%04d", frame) .. ext,
                    folderPath .. "/" .. string.format("%03d", frame) .. ext,
                    folderPath .. "/" .. string.format("%02d", frame) .. ext,
                    folderPath .. "/" .. frame .. ext,
                    folderPath .. "/frame_" .. string.format("%04d", frame) .. ext,
                }
                
                for _, imagePath in ipairs(possiblePaths) do
                    local success, image = pcall(function()
                        return Image{ fromFile = imagePath }
                    end)
                    
                    if success and image then
                        table.insert(images, image)
                        imageLoaded = true
                        break
                    end
                end
                
                if imageLoaded then break end
            end
            
            if not imageLoaded then
                table.insert(images, nil)
            end
        end
    end
    
    return images
end

-- Main import function
local function importAnimation()
    -- Read and parse manifest
    local jsonContent, err = readJsonFile(manifestPath)
    if not jsonContent then
        return app.alert("Error reading manifest file: " .. (err or "Unknown error"))
    end
    
    -- app.alert("DEBUG: Successfully read JSON file. Content length: " .. #jsonContent .. " characters")
    
    local manifest, parseErr = parseJson(jsonContent)
    if not manifest then
        return app.alert("Error parsing JSON: " .. (parseErr or "Unknown error"))
    end
    
    -- app.alert("DEBUG: JSON parsing completed. Found " .. #manifest.animations .. " animations")
    
    -- Debug: Show structure of parsed animations
    for i, anim in ipairs(manifest.animations) do
        app.alert("DEBUG: Animation " .. i .. " - Name: " .. (anim.name or "nil") .. ", Objects count: " .. (anim.objects and #anim.objects or "nil") .. ", Frame count: " .. (anim.strip_frame_count or "nil"))
        
        if anim.objects then
            for j, obj in ipairs(anim.objects) do
                app.alert("DEBUG: - Object " .. j .. " - Name: " .. (obj.name or "nil") .. ", Rotations count: " .. (obj.rotations and #obj.rotations or "nil"))
            end
        end
    end
    
    if #manifest.animations == 0 then
        return app.alert("No animations found in manifest!\n\nDebugging info:\n- Base folder: " .. (manifest.base_folder or "nil") .. "\n- Manifest structure looks incorrect or parsing failed.")
    end
    
    -- Calculate total frames needed
    local totalFrames = 0
    local allAnimData = {}
    local uniqueAnimRotations = {}
    
    app.alert("DEBUG: Starting frame calculation with " .. #manifest.animations .. " animations")
    
    -- First pass: collect unique animation+rotation combinations and calculate total frames
    for animIndex, anim in ipairs(manifest.animations) do
        -- app.alert("DEBUG: Processing animation " .. animIndex .. ": " .. (anim.name or "nil") .. " with " .. #anim.objects .. " objects")
        
        for objIndex, obj in ipairs(anim.objects) do
            -- app.alert("DEBUG: Processing object " .. objIndex .. ": " .. (obj.name or "nil") .. " with " .. #obj.rotations .. " rotations")
            
            for rotIndex, rot in ipairs(obj.rotations) do
                -- app.alert("DEBUG: Processing rotation " .. rotIndex .. ": " .. (rot.rotation_deg or "nil") .. "° with " .. (rot.frame_files_count or "nil") .. " frames")
                
                if rot.rotation_deg and rot.frame_files_count and rot.folder then
                    local animRotKey = anim.name .. "_" .. rot.rotation_deg .. "deg"
                    
                    -- Only count frames once per unique animation+rotation combination
                    if not uniqueAnimRotations[animRotKey] then
                        uniqueAnimRotations[animRotKey] = {
                            animName = anim.name,
                            rotation = rot.rotation_deg,
                            frameCount = rot.frame_files_count,
                            objects = {}
                        }
                        totalFrames = totalFrames + rot.frame_files_count
                    end
                    
                    -- Add object data to this animation+rotation combination
                    local animData = {
                        animName = anim.name,
                        objectName = obj.name,
                        rotation = rot.rotation_deg,
                        frameCount = rot.frame_files_count,
                        folder = rot.folder,
                        framePaths = rot.frames or {} -- Include the direct frame paths
                    }
                    table.insert(uniqueAnimRotations[animRotKey].objects, animData)
                    table.insert(allAnimData, animData)
                    
                    -- app.alert("DEBUG: Added animation data for " .. animRotKey)
                else
                    app.alert("DEBUG: Skipping incomplete rotation data - deg:" .. (rot.rotation_deg or "nil") .. " count:" .. (rot.frame_files_count or "nil") .. " folder:" .. (rot.folder or "nil"))
                end
            end
        end
    end
    
    -- Sort animation combinations by animation name, then by rotation
    local sortedAnimKeys = {}
    for key, _ in pairs(uniqueAnimRotations) do
        table.insert(sortedAnimKeys, key)
    end
    table.sort(sortedAnimKeys, function(a, b)
        local animA = uniqueAnimRotations[a].animName
        local animB = uniqueAnimRotations[b].animName
        local rotA = uniqueAnimRotations[a].rotation
        local rotB = uniqueAnimRotations[b].rotation
        
        if animA == animB then
            return rotA < rotB -- Sort by rotation if same animation
        else
            return animA < animB -- Sort by animation name first
        end
    end)
    
    app.alert("DEBUG: Frame calculation completed. Total frames: " .. totalFrames .. ", Total unique animation combinations: " .. #sortedAnimKeys)
    
    if totalFrames == 0 then
        return app.alert("No frames found to import!")
    end
    
    -- Ask user to select a reference image to determine sprite size
    local dlg = Dialog { title = "Select Reference Image for Sprite Size" }
    dlg:file{ 
        id = "refImage", 
        label = "Reference Image:", 
        open = true,
        filetypes = {"png", "jpg", "jpeg", "bmp", "tga"}
    }
    dlg:button{ id = "ok", text = "OK" }
    dlg:button{ id = "cancel", text = "Cancel" }
    dlg:show()
    
    if dlg.data.cancel then
        return app.alert("Import cancelled by user.")
    end
    
    local refImagePath = dlg.data.refImage
    if not refImagePath or refImagePath == "" then
        return app.alert("No reference image selected!")
    end
    
    -- Load reference image to get dimensions
    local refImage = Image{ fromFile = refImagePath }
    if not refImage then
        return app.alert("Failed to load reference image: " .. refImagePath)
    end
    
    local spriteWidth = refImage.width
    local spriteHeight = refImage.height
    
    app.alert("DEBUG: Using reference image dimensions: " .. spriteWidth .. "x" .. spriteHeight)
    
    -- Create new sprite with reference image dimensions
    local sprite = Sprite(spriteWidth, spriteHeight)
    sprite.filename = "BlenderImport_" .. os.date("%Y%m%d_%H%M%S") .. ".aseprite"
    
    -- Add frames to sprite
    for i = 2, totalFrames do
        sprite:newFrame()
    end
    
    -- Create layers for each unique object
    local objectLayers = {}
    for _, anim in ipairs(manifest.animations) do
        for _, obj in ipairs(anim.objects) do
            if not objectLayers[obj.name] then
                local layer = sprite:newLayer()
                layer.name = obj.name
                objectLayers[obj.name] = layer
            end
        end
    end
    
    -- app.alert("DEBUG: Created " .. #(function() local count = 0; for _ in pairs(objectLayers) do count = count + 1 end; return count end)() .. " layers for all objects")
    
    
    -- app.alert("DEBUG: Processing all " .. #allAnimData .. " animation combinations")
    
    -- Import images and create animation tags
    app.transaction(function()
        
        app.alert("DEBUG: Starting image loading with " .. #sortedAnimKeys .. " unique animation combinations")
        
        -- Assign frame ranges to each sorted animation combination
        local currentFrame = 1
        local animGroups = {}
        for _, animKey in ipairs(sortedAnimKeys) do
            local animRotData = uniqueAnimRotations[animKey]
            animGroups[animKey] = {
                animName = animRotData.animName,
                rotation = animRotData.rotation,
                frameCount = animRotData.frameCount,
                objects = animRotData.objects,
                startFrame = currentFrame,
                endFrame = currentFrame + animRotData.frameCount - 1
            }
            currentFrame = currentFrame + animRotData.frameCount
        end
        
        -- Load images for each animation combination in sorted order
        for _, groupKey in ipairs(sortedAnimKeys) do
            local group = animGroups[groupKey]
            
            -- app.alert("DEBUG: Processing group " .. groupKey .. " (frames " .. group.startFrame .. "-" .. group.endFrame .. ")")
            
            -- Process each object in this animation+rotation combination
            for _, animData in ipairs(group.objects) do
                -- app.alert("DEBUG: Processing " .. animData.objectName .. " for " .. groupKey .. " (frames " .. group.startFrame .. "-" .. group.endFrame .. ")")
                
                -- Load images using direct frame paths
                local images = loadImagesFromFramePaths(animData.framePaths, animData.folder, animData.frameCount)
                
                -- app.alert("DEBUG: Loaded " .. #images .. " images (expected " .. animData.frameCount .. ")")
                
                -- Add images to appropriate layer using the group's frame range
                local layer = objectLayers[animData.objectName]
                if layer and #images > 0 then
                    -- app.alert("DEBUG: Adding images to layer: " .. layer.name)
                    
                    for i, image in ipairs(images) do
                        if image then
                            -- Adjust sprite size if needed
                            if image.width > sprite.width or image.height > sprite.height then
                                sprite:resize(
                                    math.max(sprite.width, image.width),
                                    math.max(sprite.height, image.height)
                                )
                            end
                            
                            -- Calculate frame number within the group's range
                            local targetFrame = group.startFrame + i - 1
                            
                            -- Create cel and add image with error handling
                            local success, error = pcall(function()
                                local cel = sprite:newCel(layer, targetFrame)
                                cel.image = image
                            end)
                            
                            if not success then
                                app.alert("WARNING: Failed to add image " .. i .. " to frame " .. targetFrame .. " for " .. animData.objectName .. ". Error: " .. tostring(error) .. ". Skipping this frame.")
                            else
                                -- app.alert("DEBUG: Added image " .. i .. " to frame " .. targetFrame)
                            end
                        end
                    end
                end
            end
        end
        
        -- Create animation tags using the sorted groups
        -- app.alert("DEBUG: Creating " .. #sortedAnimKeys .. " animation tags")
        
        for _, groupKey in ipairs(sortedAnimKeys) do
            local group = animGroups[groupKey]
            local success, error = pcall(function()
                local tag = sprite:newTag(group.startFrame, group.endFrame)
                
                -- Create tag name without object name (since it contains all objects)
                local tagName = group.animName .. "_" .. group.rotation .. "deg"
                tag.name = tagName
                
                -- Set tag color based on animation type
                if group.animName:find("walk") or group.animName:find("run") then
                    tag.color = Color(0, 255, 0) -- Green for movement animations
                elseif group.animName:find("idle") or group.animName:find("dormit") or group.animName:find("standing") then
                    tag.color = Color(0, 150, 255) -- Blue for idle animations
                else
                    tag.color = Color(255, 255, 0) -- Yellow for other animations
                end
            end)
            
            if not success then
                app.alert("WARNING: Failed to create animation tag for " .. groupKey .. " at frames " .. group.startFrame .. "-" .. group.endFrame .. ". Error: " .. tostring(error) .. ". Skipping this tag.")
            else
                local objectNames = {}
                for _, objData in ipairs(group.objects) do
                    table.insert(objectNames, objData.objectName)
                end
                -- app.alert("DEBUG: Created tag: " .. groupKey .. " (frames " .. group.startFrame .. "-" .. group.endFrame .. ") with objects: " .. table.concat(objectNames, ", "))
            end
        end
    end)
    
    -- Show summary
    local summary = "Import completed!\n\n"
    summary = summary .. "Total animation combinations imported: " .. #sortedAnimKeys .. "\n"
    summary = summary .. "Total frames: " .. totalFrames .. "\n"
    summary = summary .. "Animation groups created: " .. #sortedAnimKeys .. "\n"
    summary = summary .. "Objects found: "
    
    local uniqueObjects = {}
    for objName, _ in pairs(objectLayers) do
        table.insert(uniqueObjects, objName)
    end
    summary = summary .. table.concat(uniqueObjects, ", ")
    
    app.alert(summary)
end

-- Execute import
importAnimation() 