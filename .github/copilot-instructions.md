# Aseprite Scripts - AI Coding Instructions
Aseprite documentation can be found #fetch https://github.com/aseprite/api/tree/main
If you have not done so already, please fetch related documentation to understand the Aseprite API and scripting capabilities.

## Project Overview
This is a collection of Lua scripts for Aseprite, a pixel art editor. Scripts are placed in the user's Aseprite scripts directory and provide custom automation for pixel art workflows, game development, and Unity integration.

## Architecture & Core Patterns

### Script Structure
All scripts follow a consistent pattern:
1. **Dialog Creation**: Use `Dialog{}` with user input fields (`file`, `number`, `button`)
2. **Input Validation**: Check for active sprite, layer, selection as needed
3. **Transaction Wrapping**: Use `app.transaction()` for undoable operations
4. **Error Handling**: Return early with `app.alert()` for user-friendly error messages

```lua
-- Standard script template
local dlg = Dialog { title = "Script Name" }
dlg:file{ id = "srcfile", label = "Source:", open = true }
dlg:show()
if pressed == "cancel" then return app.alert("Operation aborted.") end
```

### Common Aseprite API Patterns
- **Sprite Access**: `app.activeSprite`, `app.open(filename)`
- **Layer Management**: `app.activeLayer`, `layer.isTilemap`, `layer.tileset`
- **Image Processing**: `cel.image`, `image:getPixel()`, `image:putPixel()`
- **Pixel Iteration**: `for it in image:pixels() do`
- **Color Operations**: `app.pixelColor.rgba()`, `app.pixelColor.rgbaR()`

## Development Workflow

### Testing Scripts
1. Place `.lua` files in Aseprite scripts directory
2. Refresh: **File > Scripts > Refresh Scripts** (no restart needed)
3. Access via **File > Scripts > [Script Name]**

### Common Debugging Patterns
- Use `app.alert()` for user feedback and debugging
- Check `app.activeSprite` and `app.activeLayer` before operations are in context of user's current work
- Validate selections with `sprite.selection.isEmpty`

### Performance Considerations
- Use `app.transaction()` to batch operations for better performance

## File Organization
- Each script is self-contained with descriptive comments
- README.md provides user-facing documentation with emoji categories
- No external dependencies - pure Lua + Aseprite API

## Key Files for Understanding Patterns
- `autoTile.lua`: Complete dialog → processing → output workflow
- `combineTileSet.lua`: Tileset layer manipulation and canvas resizing
- `selectionToNoTransparent.lua`: Selection-based operations with tilemap support
