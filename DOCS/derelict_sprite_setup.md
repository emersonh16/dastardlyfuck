# Derelict Sprite Setup Guide

## Current Setup

The derelict uses a `Sprite3D` node for the body, positioned at `Visual/Body` in the scene.

## Adding Your Pixel Art Sprite

1. **Export from Libresprite:**
   - Create your 4-legged walking tank sprite
   - Export as PNG (transparent background recommended)
   - Suggested size: 64x64 or 128x128 pixels (for isometric view)

2. **Add to project:**
   - Create folder: `sprites/derelict/`
   - Place sprite file: `sprites/derelict/derelict_body.png`

3. **Load in code:**
   - Uncomment the line in `derelict.gd`:
   ```gdscript
   body_sprite.texture = load("res://sprites/derelict/derelict_body.png")
   ```

## Sprite Requirements

- **Format:** PNG with transparency
- **Size:** 64x64 to 128x128 pixels (adjust `pixel_size` in scene if needed)
- **Orientation:** Should be drawn for isometric view (45° angle)
- **Style:** Moebius-inspired, clean lines, miniature aesthetic

## Current Visual Settings

- **Position:** Y=3 (above ground)
- **Rotation:** Already rotated for isometric view (45° on XZ plane)
- **Size:** 8x6 world units (adjustable via `size` property)
- **Pixel Size:** 0.1 (adjust if sprite looks too big/small)

## Future Enhancements

- Add walking animation (AnimatedSprite3D)
- Add separate sprites for legs (4 leg sprites)
- Add rotation based on movement direction
- Add crew members as sprites on the body
