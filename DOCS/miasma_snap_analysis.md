# Miasma Snap Analysis

## Current State

**Ground Tiles:**
- Size: 64x64 world units (square)
- Height: Not specified (probably 0.1 or flat)

**Miasma Tiles:**
- Size: 8x8 world units (X and Z) - changed from 8x4 for square appearance
- Height: 16.0 world units
- Updates: Only when player crosses tile boundary (good!)

## The Problem

The miasma blocks are positioned at **world coordinates**:
```gdscript
var world_x = tile_pos.x * MIASMA_TILE_SIZE_X  # e.g., 0 * 8.0 = 0.0
var world_z = tile_pos.y * MIASMA_TILE_SIZE_Z  # e.g., 0 * 8.0 = 0.0
```

When the player moves smoothly (not grid-snapped), the blocks appear to shift smoothly relative to the camera, creating the illusion of camera rotation.

## The Solution: Grid-Snapped Miasma

The miasma should **snap instantly** to grid positions. Currently it does this, but the visual might be shifting because:

1. **Blocks are positioned correctly** (grid-snapped)
2. **But player moves smoothly** (not grid-snapped)
3. **Camera follows player smoothly**
4. **Result:** Blocks appear to shift smoothly as camera moves

## Options

### Option A: Keep Current System (Grid-Snapped Blocks)
- Blocks are already grid-snapped
- Player moves smoothly
- Camera follows smoothly
- **Visual effect:** Blocks appear to shift (but they're actually stationary in world space)

### Option B: Make Everything Grid-Snapped
- Player movement snaps to grid
- Camera snaps to grid
- Blocks snap to grid
- **Visual effect:** Everything snaps together (more arcadey)

### Option C: Adjust Tile Sizes
- User wants: Ground 64x32y, Miasma 8x4y
- Currently: Ground 64x64, Miasma 8x8
- Need to clarify: Is "32y" and "4y" the height, or the Z dimension?

## Questions

1. **Tile Sizes:** 
   - Ground: 64x64? Or 64x32 (where 32 is height)?
   - Miasma: 8x8? Or 8x4 (where 4 is height, but we changed Z to 8 for square appearance)?

2. **Snapping:**
   - Should miasma blocks appear to "snap" instantly when player crosses boundary?
   - Or is the current behavior (smooth camera, grid-snapped blocks) acceptable?

3. **Visual Effect:**
   - Is the "rotation" actually blocks shifting smoothly?
   - Or is the camera actually rotating?

## Recommendation

The miasma is already grid-snapped correctly. The "rotation" effect is likely:
- Smooth camera movement following smooth player movement
- Grid-snapped blocks appearing to shift relative to camera
- This is normal and expected behavior

If you want everything to snap, we'd need to:
1. Snap player movement to grid
2. Snap camera to grid
3. Keep blocks grid-snapped

But this would make movement feel very arcadey/choppy.
