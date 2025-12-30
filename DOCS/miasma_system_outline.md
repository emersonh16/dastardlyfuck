# Miasma System - Technical Design Document

## Project Foundation
- **Engine:** Godot 4.5
- **Project Type:** 3D (with orthographic camera for isometric view)
- **Camera:** 45-degree locked angle (can swivel later, everything blocky)
- **Viewport:** 1152x648 (default)
- **Target FPS:** 60fps
- **Origin:** Center (0,0,0)

## Core Vision
- **Genre:** 2.5D Isometric Roguelike (Real-time with pause)
- **Visual Style:** Into the Breach style - clean, blocky, arcadey
- **Aesthetic:** Moebius-inspired, miniature feel
- **World:** Post-apocalyptic wasteland covered in lethal Miasma fog

## Miasma System Specifications

### Grid & Scale
- **Ground Tiles:** 64x64 units (square from top-down, isometric view)
- **Miasma Tiles:** 2x2 units (sub-grid of ground tiles)
  - 1 ground tile = 32 miasma tiles (32×2 = 64)
- **Miasma Sheet:** 2D flat sheet at Y=0.01 (flat on ground)
- **Tile Size:** 2x2 world units per miasma tile

### Visual Design
- **Shape:** 2D flat sheet (not 3D blocks)
- **Height:** 0.1 units thick (flat sheet)
- **Position:** Y=0.01 (slightly above ground to avoid z-fighting)
- **Color:** Purple (solid color for now, animation later)
- **Opacity:** Opaque sheet with holes where cleared
- **Style:** Continuous sheet with holes, not individual blocks

### Behavior
- **State:** Inverse model - miasma assumed everywhere, only cleared tiles tracked
- **Clearing:** Instant removal when beam hits (ONLY beam clears, not walker)
- **Regrowth:** Creeping pattern from borders, 1.5s delay, 15% chance, dynamic budget
- **Wind Movement:** Coordinate system shifts with wind velocity (advection)
- **Frontier System:** Tracks boundary tiles for efficient regrowth
- **Scope:** Miasma sheet follows player position, renders visible viewport + padding

### Technical Architecture

#### Data Structure
- **Storage:** Inverse model - Dictionary of cleared tiles
  - Format: `cleared_tiles: Dictionary` - `Vector2i` → `float` (timestamp)
  - Only cleared tiles are stored (miasma assumed everywhere else)
- **Frontier:** `Dictionary` of `Vector2i` → `bool` - Tracks boundary tiles for regrowth
- **Coordinates:** 2D grid (X, Z), stored as `Vector2i` (Z=0 in Vector3i for compatibility)

#### Rendering System
- **Method:** Single `ArrayMesh` built from visible tiles
- **Update Strategy:** Rebuilds only when visible bounds, wind offset, player tile, or camera rotation change significantly
- **Optimization:** Early exits, batch lookups, pre-allocated arrays
- **Performance:** 60 FPS with optimized thresholds

#### Regrowth System
- **Delay:** 1.5 seconds before regrowth can occur
- **Chance:** 15% per eligible tile per frame
- **Budget:** Dynamic (128 base + viewport scaling factor 0.125)
- **Pattern:** Creeps back from borders where miasma meets cleared areas
- **Scan Limit:** Max 4000 tiles scanned per frame
- **Offscreen Management:** Only processes visible area + padding

#### Wind Integration
- **Source:** WindManager provides velocity (vx, vz in tiles/sec)
- **Advection:** Miasma coordinate system shifts with wind velocity
- **Offset Tracking:** `wind_offset_x` and `wind_offset_z` track cumulative shift
- **Effect:** Cleared tiles appear to move with wind (coordinate system shift)
- **Independent:** Wind does not affect regrowth (regrowth uses original coordinates)

#### Beam Clearing
- **Method:** Instant removal (adds tiles to `cleared_tiles` dictionary)
- **Shape:** Circular clearing (uses tile centers for distance calculation)
- **Integration:** Updates frontier for regrowth, emits `cleared_changed` signal
- **Modes:** Bubble (circular), Cone (sector), Laser (line with thickness)

### Coordinate System
- **Logic:** 2D grid (X, Z) - stored as `Vector2i` (or `Vector3i(x, 0, z)` for compatibility)
- **Rendering:** 2D sheet at Y=0.01 (flat on ground)
- **World Space:** XZ plane for logic, Y=0.01 for rendering
- **Wind Offset:** Coordinate system shifts with wind (`wind_offset_x`, `wind_offset_z`)

## Implementation Plan

### Phase 1: Foundation ✅ COMPLETE
1. ✅ Set up 3D project with isometric camera (free rotation enabled)
2. ✅ Create MiasmaManager (Autoload singleton)
3. ✅ Create inverse model storage (cleared tiles dictionary)
4. ✅ Create MiasmaRenderer with ArrayMesh (2D sheet)
5. ✅ Render 2D purple sheet with holes (60 FPS)
6. ✅ Camera follows player position (miasma moves with player)

### Phase 2: Core System ✅ COMPLETE
1. ✅ Implement inverse model storage (Dictionary-based)
2. ✅ Create MiasmaRenderer with ArrayMesh (single mesh)
3. ✅ Basic rendering of 2D sheet with holes
4. ✅ Optimized mesh rebuilding (thresholds, early exits)

### Phase 3: Wind Integration ✅ COMPLETE
1. ✅ Connect to WindManager
2. ✅ Implement coordinate system advection (wind offset)
3. ✅ Renderer responds to wind changes
4. ✅ Wind does not affect regrowth

### Phase 4: Beam Integration ✅ COMPLETE
1. ✅ Implement clearing logic (instant removal)
2. ✅ Circular clearing shape (tile center distance)
3. ✅ Updates frontier for regrowth

### Phase 5: Regrowth System ✅ COMPLETE
1. ✅ Creeping regrowth pattern from borders
2. ✅ 1.5s delay, 15% chance, dynamic budget
3. ✅ Performance optimization (60 FPS)

### Phase 6: Collision & Occlusion 🚧 FUTURE
1. Mountain blocking (height-based)
2. Object engulfment (short objects)
3. Visual occlusion

## Performance Targets ✅ ACHIEVED
- **FPS:** 60fps (achieved)
- **Visible Tiles:** Dynamic based on viewport
- **Update Budget:** Dynamic regrowth budget (128 base + scaling)
- **Memory:** Efficient dictionary-based storage (only cleared tiles stored)
- **Optimizations:** Early exits, thresholds, batch operations, pre-allocated arrays

## Open Questions / Future Enhancements
- Animation system (color shift, opacity pulse, etc.)
- Multiple miasma types/palettes
- Advanced wind effects (gusts, turbulence)
- Particle effects for clearing/regrowth

## Notes
- Previous attempts with TileMap layers failed due to performance
- Shader-based approach failed
- Texture-based approach failed
- MultiMeshInstance3D is the chosen path for performance
