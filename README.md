# Aseprite Scripts Collection

This folder contains custom Lua scripts for Aseprite. Put your scripts here and restart Aseprite to see them in **File > Scripts**.

## Available Scripts

### 🎯 autoTile.lua
**Auto-Tile Generation Script**
- Opens an image file and downsample it to a specified size (default: 192x192)
- Automatically detects connected pixel regions using flood fill algorithms
- Creates separate sprite layers for each connected component/island
- Perfect for creating individual tiles from a single source image
- Supports PNG, ASE, BMP, and GIF formats

### 🔧 combineTileSet.lua
**Tileset Layer Combiner**
- Combines multiple tileset layers into a single larger tileset layer
- Arranges tilesets in an optimal grid pattern (tries to maintain square aspect ratio)
- Expands canvas size to accommodate all combined tilesets
- Ideal for Unity tilemaps or other game engines that prefer consolidated tilesets
- Requires at least 2 tileset layers to operate

### 🌫️ gussianblur.lua
**Powerful Blur Effect**
- Applies customizable blur effects to the current image layer
- Uses box blur algorithm with configurable radius and iterations
- Interactive dialog with real-time preview options
- Supports RGB and Grayscale color modes
- Great for creating soft shadows, glows, or atmospheric effects

### 🎨 selectionToNoTransparent.lua
**Selection Alpha Fixer**
- Sets all pixels in the current selection to full opacity (alpha = 1.0)
- Works with both regular image layers and tilemap layers
- Preserves original colors while removing transparency
- Useful for fixing semi-transparent pixels or cleaning up imported graphics
- Requires an active selection to operate

### 📋 spiteSheetToLayers.lua
**Sprite Sheet Separator**
- Breaks down sprite sheets into individual layers based on connected pixel regions
- Uses configurable grid size to organize the separation process
- Creates separate files/layers for each distinct sprite or element
- Employs flood fill detection to identify connected components within grid cells
- Perfect for separating character animations or tile collections from sprite sheets

## Usage

1. Place any `.lua` script in this directory
2. Restart Aseprite
3. Access scripts via **File > Scripts > [Script Name]**
4. Follow the dialog prompts for each script's specific options

## Resources

For more information about Aseprite scripting and API documentation:
- Official API Documentation: https://github.com/aseprite/api
- Aseprite Scripting Guide: https://www.aseprite.org/docs/scripting/
- Lua Language Reference: https://www.lua.org/manual/5.3/

## Contributing

Feel free to modify these scripts or add new ones. All scripts are written in Lua and use the Aseprite API.

