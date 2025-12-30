# Onboarding Guide for New Agents

## Project Overview

**Derelict Drifters** is a 2.5D isometric roguelike game built in **Godot 4.5**. The player controls a derelict machine (walker) exploring a world covered in miasma, using a beam system to clear paths and survive.

### Core Vision
- **Isometric 2.5D view** (30° elevation, 45° azimuth camera)
- **Miasma system** - fog-like substance that covers the world
- **Beam system** - player's tool to clear miasma (bubble/cone/laser modes)
- **Cardinal movement** - WASD moves in screen-space directions (W=up, S=down, A=left, D=right)
- **Event-driven architecture** - managers communicate via signals

## Current State (Phase 1 Complete)

### ✅ Implemented Systems

1. **Miasma System**
   - Binary tile-based miasma (2x2 world units per tile)
   - Player-centric generation (fills viewport + buffer)
   - Permanent clearing (no regrowth yet)
   - Efficient MultiMeshInstance3D rendering
   - **Status:** Working, optimized for 60 FPS

2. **Beam System**
   - **BeamManager** (autoload) - manages modes, energy, clearing logic
   - **BeamRenderer** - visualizes beam (circle on XZ plane, appears as ellipse isometrically)
   - **SimpleBeam** - handles continuous clearing every frame
   - **BeamInput** - handles mode switching (mouse wheel, number keys 1-5)
   - **Modes:** OFF, BUBBLE_MIN, BUBBLE_MAX, CONE, LASER
   - **Status:** All modes working, continuous clearing implemented

3. **Player (Derelict)**
   - CharacterBody3D with WASD movement
   - Screen-space cardinal movement (W=up screen, S=down screen, etc.)
   - Position tracked at Y=0 (ground level)
   - **Status:** Working

4. **Camera System**
   - Isometric orthographic camera
   - Fixed angles: 30° elevation, 45° azimuth
   - Follows player, no rotation (perfectly stable)
   - **Status:** Working, stable

5. **Ground Renderer**
   - MultiMeshInstance3D for ground tiles (64x64 world units)
   - Positioned at Y=-1.0
   - **Status:** Working

### 🚧 Not Yet Implemented

- Wind system (advection)
- World generation (biomes, chunks)
- DerelictManager (position ownership)
- Energy UI display
- Miasma regrowth
- Beam visual for cone/laser modes (only bubble has visual)

## Architecture

### Core Principles

1. **Separation of Concerns**
   - **Managers** (autoloads) = Logic/Data
   - **Renderers** (scene nodes) = Visual representation
   - **Game Objects** (scene nodes) = Player, enemies, etc.

2. **Event-Driven Communication**
   - Systems communicate via signals
   - No direct references between systems
   - Managers emit signals, renderers listen

3. **Single Source of Truth**
   - Each manager owns its data
   - Other systems access via public API
   - Example: `MiasmaManager.clear_area()`, not direct dictionary access

### System Structure

```
Autoload Singletons (Managers):
├── MiasmaManager ✅
│   └── Manages miasma block state, clearing, player-centric updates
├── BeamManager ✅
│   └── Manages beam modes, energy, clearing parameters
├── WindManager (not yet created)
├── WorldManager (not yet created)
└── DerelictManager (not yet created)

Scene Nodes (Renderers & Game Objects):
├── MiasmaRenderer ✅
│   └── Renders miasma blocks using MultiMeshInstance3D
├── BeamRenderer ✅
│   └── Renders beam visual (currently only bubble mode)
├── GroundRenderer ✅
│   └── Renders ground tiles
├── Derelict (player) ✅
│   └── CharacterBody3D with movement
├── SimpleBeam ✅
│   └── Handles continuous clearing logic
└── BeamInput ✅
    └── Handles mode switching input
```

## File Structure

```
scripts/
├── managers/              # Autoload singletons
│   ├── miasma_manager.gd ✅
│   └── beam_manager.gd ✅
│
├── renderers/             # Visual representation
│   ├── miasma_renderer.gd ✅
│   ├── beam_renderer.gd ✅
│   └── ground_renderer.gd ✅
│
├── beam/                  # Beam system components
│   ├── simple_beam.gd ✅
│   └── beam_input.gd ✅
│
├── derelict/              # Player character
│   └── derelict.gd ✅
│
├── camera/                # Camera systems
│   ├── camera_follower.gd ✅
│   └── isometric_camera.gd ✅
│
├── world/                 # World generation
│   └── ground_renderer.gd ✅ (temporary location)
│
├── ui/                    # UI systems
│   └── fps_display.gd ✅
│
└── debug/                 # Debug tools
    └── player_trail.gd ✅

scenes/
├── test/
│   └── test_miasma.tscn ✅ (main test scene)
└── derelict/
    └── derelict.tscn ✅

DOCS/
├── ONBOARDING.md ✅ (this file)
├── coordinate_space_reference.md ✅ (critical reference)
├── system_architecture.md ✅ (full architecture docs)
└── [other design docs]
```

## Coordinate System (CRITICAL)

**Reference:** `DOCS/coordinate_space_reference.md`

### World Coordinates
- **X**: East/West (positive = East)
- **Y**: Up/Down (positive = Up)
- **Z**: North/South (positive = North)

### Layer Positions
- **Y = -1.0**: Ground tiles
- **Y = 0.0**: Derelict position (ground level)
- **Y = 2.0**: Beam visual
- **Y = 8.0**: Miasma block centers (blocks span Y=0 to Y=16)

### Camera
- **Type**: Orthographic, Isometric
- **Elevation**: 30° (looking down)
- **Azimuth**: 45° (rotated around Y axis)
- **No rotation**: Camera never rotates, only scrolls with player

### Screen Space → World Space
- **W (up screen)** → World: (-X, +Z) = Northwest
- **S (down screen)** → World: (+X, -Z) = Southeast
- **A (left screen)** → World: (-X, -Z) = Southwest
- **D (right screen)** → World: (+X, +Z) = Northeast

### Isometric Projection
- A circle on the XZ plane naturally appears as an ellipse in isometric view
- **Beam visual**: Flat circle on XZ plane, no rotation needed
- Compression factor: cos(30°) ≈ 0.866

## Key Systems Deep Dive

### MiasmaManager (Autoload)

**Purpose:** Manages miasma block state and clearing

**Key Constants:**
- `MIASMA_TILE_SIZE_X = 2.0` (world units)
- `MIASMA_TILE_SIZE_Z = 2.0` (world units)
- `buffer_tiles = 4` (buffer around viewport)

**Key Methods:**
- `clear_area(world_pos: Vector3, radius: float) -> int` - Clears miasma in area, returns count cleared
- `update_player_position(pos: Vector3)` - Updates miasma around player
- `get_all_blocks() -> Dictionary` - Returns all miasma blocks for rendering

**Signals:**
- `blocks_changed()` - Emitted when blocks are added/removed

**Data Structure:**
- `blocks: Dictionary` - `Vector3i` → `bool` (true = miasma present)

### BeamManager (Autoload)

**Purpose:** Manages beam modes, energy, and clearing parameters

**Beam Modes:**
- `OFF` - No beam
- `BUBBLE_MIN` - Small bubble around player (radius 16.0)
- `BUBBLE_MAX` - Large bubble around player (radius 32.0)
- `CONE` - Cone from player toward mouse (length 64.0, angle 32°)
- `LASER` - Laser from player toward mouse (length 128.0, thickness 4.0)

**Key Methods:**
- `get_mode() -> BeamMode` - Get current mode
- `set_mode(mode: BeamMode)` - Set mode (emits signal)
- `get_clearing_params() -> Dictionary` - Get params for current mode
- `clear_cone(origin, direction, length, angle)` - Clear cone shape
- `clear_laser(origin, direction, length, thickness)` - Clear laser shape
- `can_fire() -> bool` - Check if beam has energy

**Signals:**
- `beam_mode_changed(mode)` - Emitted when mode changes
- `beam_energy_changed(energy)` - Emitted when energy changes
- `beam_fired(position, radius)` - Emitted when beam clears miasma

**Energy System:**
- Max energy: 64.0
- Regen rates vary by mode (OFF: 0, BUBBLE_MIN: 8.0/sec, etc.)
- Laser drains 24.0/sec (no regen)

### SimpleBeam (Scene Node)

**Purpose:** Handles continuous clearing logic for all beam modes

**Behavior:**
- Clears **every frame** (no throttling)
- Clears **immediately** when mode switches (via signal)
- Bubble modes: Clear around player position
- Cone/Laser modes: Clear from player toward mouse position

**Key Methods:**
- `_process_clear()` - Main clearing logic (called every frame)
- `_get_mouse_world_position() -> Vector3` - Converts mouse screen coords to world coords on ground plane

### BeamRenderer (Scene Node)

**Purpose:** Renders beam visual

**Current Implementation:**
- Only renders bubble mode (circle on XZ plane)
- Uses custom ArrayMesh for flat circle
- Positioned at Y=2.0 (above ground)
- Gold color, translucent (albedo: (1.0, 0.84, 0.0), opacity: 0.2)
- Depth testing disabled to prevent occlusion

**TODO:** Implement cone and laser visuals

## How to Get Started

### 1. Open the Project
- Open `project.godot` in Godot 4.5
- Main scene: `scenes/test/test_miasma.tscn`

### 2. Run the Game
- Press F5 or click Play
- You should see:
  - Green ground tiles
  - Gray miasma blocks covering the viewport
  - Gold beam ellipse (bubble mode)
  - Player (derelict) in center

### 3. Controls
- **WASD** - Move derelict (cardinal screen-space directions)
- **Mouse Wheel** - Cycle beam modes (OFF → BUBBLE_MIN → BUBBLE_MAX → CONE → LASER → OFF)
- **Number Keys 1-5** - Direct mode selection (1=OFF, 2=BUBBLE_MIN, 3=BUBBLE_MAX, 4=CONE, 5=LASER)

### 4. Test Systems
- **Miasma clearing**: Move around, beam should clear miasma continuously
- **Mode switching**: Use mouse wheel or number keys
- **Camera stability**: Move around, camera should not rotate
- **Performance**: Check FPS counter (should be ~60 FPS)

## Important Gotchas

### 1. Camera Rotation
- **CRITICAL**: Camera must NEVER rotate
- Use fixed `rotation` values, not `look_at()` for orientation
- Camera only scrolls with player, never rotates

### 2. Coordinate Spaces
- Always reference `coordinate_space_reference.md` when working with positions
- Screen space ≠ World space (45° rotation)
- Y positions are critical (ground=-1, player=0, beam=2, miasma=8)

### 3. Miasma Tile Size
- Current: 2x2 world units (very small)
- Optimized for 60 FPS with viewport coverage + buffer
- Don't make tiles smaller without performance testing

### 4. Beam Visual vs Clearing
- Visual must match clearing hitbox exactly
- Circle on XZ plane = ellipse in isometric view (natural projection)
- Don't try to compensate for isometric projection in visuals

### 5. Continuous Clearing
- Beam clears **every frame** (no throttling)
- Also clears **immediately** on mode switch
- This is intentional - don't add throttling without user request

### 6. Energy System
- Energy regenerates/drains based on mode
- Laser drains energy (no regen)
- `can_fire()` checks energy before clearing

## Common Tasks

### Adding a New Beam Mode
1. Add enum value to `BeamManager.BeamMode`
2. Add parameters to `get_clearing_params()` in BeamManager
3. Add clearing logic in `SimpleBeam._process_clear()`
4. Add visual in `BeamRenderer` (if needed)
5. Update `BeamInput` to handle new mode

### Debugging Miasma
- Check `MiasmaManager.blocks` dictionary
- Verify `update_player_position()` is being called
- Check `MiasmaRenderer` is receiving `blocks_changed` signal
- Verify tile size constants match between manager and renderer

### Debugging Beam
- Check `BeamManager.current_mode`
- Verify `SimpleBeam` is calling clearing functions
- Check `BeamRenderer` is receiving `beam_fired` signal
- Verify mouse-to-world conversion in `_get_mouse_world_position()`

## Next Steps (Future Work)

1. **DerelictManager** - Track player position, health, systems
2. **WindManager** - Wind advection for miasma
3. **WorldManager** - Biome system, chunk loading
4. **Cone/Laser Visuals** - Complete beam renderer
5. **Energy UI** - Display beam energy
6. **Miasma Regrowth** - Add regrowth logic
7. **Performance** - Further optimizations if needed

## Reference Documents

- **`coordinate_space_reference.md`** - Coordinate system details (READ FIRST)
- **`system_architecture.md`** - Full architecture documentation
- **`beam_visual_architecture.md`** - Beam visual design decisions
- **`system_simplification_plan.md`** - Roadmap for future features

## Questions to Ask User

If you're unsure about:
- **Architecture decisions** → Check docs first, then ask
- **Coordinate system** → Check `coordinate_space_reference.md` first
- **Current behavior** → Test in game first, then ask
- **Code changes** → Ask before making major changes
- **Performance** → Test first, then ask if optimization needed

## Code Style Notes

- Use descriptive variable names
- Comment complex coordinate transformations
- Use signals for inter-system communication
- Keep managers focused (single responsibility)
- Renderers should only render, not manage state

---

**Last Updated:** After Phase 1 completion (continuous clearing implemented)
**Godot Version:** 4.5
**Main Test Scene:** `scenes/test/test_miasma.tscn`
