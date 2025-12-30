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
- **Ground Tiles:** 64x32 units (isometric, represents 25 feet)
- **Miasma Tiles:** 8x4 units (sub-grid of ground tiles)
  - 1 ground tile = 8 miasma tiles (8×8 = 64, 8×4 = 32)
- **Miasma Block Dimensions:** 8x × 4y × 16z units (world space)
- **Visible Blocks:** ~23,328 blocks at 1152x648 viewport

### Visual Design
- **Shape:** 3D cubes/blocks (not flat)
- **Height:** ~25 feet tall (matches ground tile height)
- **Color:** Purple (solid color for now, animation later)
- **Edges:** Sharp (no beveling)
- **Opacity:** Opaque blocks, see through gaps to world underneath
- **Style:** Blocky, arcadey, Into the Breach aesthetic

### Behavior
- **State:** Binary (present/absent, no partial states)
- **Clearing:** Instant removal when beam hits (ONLY beam clears, not walker)
- **Regrowth:** Configurable rate, gaps refill over time (independent of wind)
- **Wind Movement:** Whole sheet moves together, blocks snap instantly to grid
- **Collision:** Tall mountains block miasma, short objects get engulfed
- **Scope:** Miasma only around player (viewport + buffer), moves with player (not world-filling)

### Technical Architecture

#### Data Structure
- **Storage:** Dictionary-based (only store "present" blocks, not empty space)
  - Format: `{chunk_key: ChunkData}`
  - Chunk key: `"x,y"` (chunk coordinates)
- **Block State:** `Dictionary` of `Vector3i` → `bool` (present/absent)

#### Chunking System
- **Chunk Size:** 64x64 miasma tiles per chunk (512×256 world units)
- **Load Distance:** Viewport + buffer (miasma moves with player, not world-filling)
- **Management:** Miasma layer follows player position
- **Dirty Flagging:** Only rebuild mesh when chunks change

#### Rendering
- **Method:** `MultiMeshInstance3D` (one draw call, GPU instancing)
- **Material:** Purple, opaque
- **Updates:** Rebuild mesh only for dirty chunks
- **Performance:** Target 60fps with ~23k visible blocks

#### Wind Integration
- **Source:** Wind system provides velocity (vx, vy in tiles/sec)
- **Movement:** All blocks shift one tile per update in wind direction
- **Snapping:** Instant grid snapping (blocky, arcadey feel)
- **Visual:** Smooth appearance via shader/material (logic instant, visual smooth)

#### Beam Clearing
- **Method:** Instant removal (sets blocks to absent in affected chunks)
- **Shape:** Circular in top-down, elliptical in isometric (approximated with 8x4 grid)
- **Integration:** Marks chunks dirty for mesh rebuild

### Coordinate System
- **Logic:** 2D grid (x, y) - stored as `Vector3i(x, y, 0)`
- **Rendering:** Convert to 3D isometric positions
- **World Space:** XZ plane for logic, Y for height

## Implementation Plan

### Phase 1: Foundation (MINIMAL TEST SCENE)
1. Set up 3D project with 45-degree orthographic isometric camera
2. Create MiasmaManager (Autoload singleton)
3. Create basic block storage (viewport + buffer around player)
4. Create MiasmaRenderer with MultiMeshInstance3D
5. Render static purple blocks (test performance)
6. Camera follows player position (miasma moves with player)

### Phase 2: Core System
1. Implement block storage (Dictionary-based)
2. Create MiasmaRenderer with MultiMeshInstance3D
3. Basic rendering of static blocks
4. Chunk dirty flagging system

### Phase 3: Wind Integration
1. Connect to wind system
2. Implement block movement (whole sheet shifts)
3. Chunk boundary handling for wind movement
4. Visual smoothing

### Phase 4: Beam Integration
1. Implement clearing logic (instant removal)
2. Elliptical clearing shape (isometric projection)
3. Chunk update on clear

### Phase 5: Regrowth System
1. Configurable regrowth rate
2. Gap detection and refilling
3. Performance optimization

### Phase 6: Collision & Occlusion
1. Mountain blocking (height-based)
2. Object engulfment (short objects)
3. Visual occlusion

## Performance Targets
- **FPS:** 60fps minimum
- **Visible Blocks:** ~23,328 blocks
- **Update Budget:** Only update dirty chunks per frame
- **Memory:** Efficient chunk-based loading/unloading

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
