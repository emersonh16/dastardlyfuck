# System Architecture & Data Flow

## Overview
This document outlines the system architecture for Derelict Drifters, following Godot best practices and scalable design patterns for a large roguelike game.

## Core Principles

1. **Godot-Native:** Use Godot's built-in systems (signals, autoloads, nodes) as much as possible
2. **Separation of Concerns:** Data/Logic (Managers) separate from Rendering (Renderers)
3. **Event-Driven:** Systems communicate via signals, not direct references
4. **Single Source of Truth:** Each system owns its data, others access via public API
5. **Scalable:** Architecture supports 12 biomes, large seeded worlds, complex systems

## System Architecture

### Autoload Singletons (Managers)

These are global systems that persist across scenes and manage game state:

#### 1. **MiasmaManager** ✅ (Already exists)
- **Purpose:** Manages miasma block state, clearing, regrowth
- **Data:** Dictionary of miasma blocks (Vector3i → bool)
- **Responsibilities:**
  - Track cleared tiles (permanent clearing)
  - Handle regrowth logic
  - Provide API for clearing (beam system calls this)
  - Emit signals when blocks change
- **Signals:**
  - `blocks_changed()` - Emitted when miasma blocks are added/removed
- **Public API:**
  - `clear_area(world_pos, radius)` - Clear miasma in area
  - `get_all_blocks()` - Get all blocks for rendering
  - `update_player_position(pos)` - Update miasma around player

#### 2. **WindManager** (To be created)
- **Purpose:** Manages wind direction, speed, and advection
- **Data:** Wind velocity (vx, vy), wind state
- **Responsibilities:**
  - Calculate wind velocity based on biome/weather
  - Provide wind data to MiasmaManager for advection
  - Handle wind changes over time
- **Signals:**
  - `wind_changed(velocity)` - Emitted when wind changes
- **Public API:**
  - `get_wind_velocity()` - Get current wind (vx, vy in tiles/sec)
  - `get_wind_direction()` - Get wind direction for HUD

#### 3. **WorldManager** (To be created)
- **Purpose:** Manages world generation, biomes, chunks, terrain
- **Data:** Biome map, chunk data, world seed
- **Responsibilities:**
  - Generate seeded world
  - Manage 12 biomes
  - Handle chunk loading/unloading
  - Provide biome data to other systems
- **Signals:**
  - `chunk_loaded(chunk_pos)` - Emitted when chunk loads
  - `biome_changed(biome_id)` - Emitted when player enters new biome
- **Public API:**
  - `get_biome_at(world_pos)` - Get biome ID at position
  - `get_chunk_at(world_pos)` - Get chunk data
  - `generate_world(seed)` - Generate world from seed

#### 4. **BeamManager** ✅ (Already exists)
- **Purpose:** Manages beam system (bubble/cone/laser modes, energy)
- **Data:** Beam mode, energy level, beam state
- **Responsibilities:**
  - Handle beam mode switching (via BeamInput)
  - Manage energy/cooldown
  - Calculate beam clearing areas
  - Call MiasmaManager.clear_area() when beam fires
- **Signals:**
  - `beam_mode_changed(mode)` - Emitted when mode changes
  - `beam_energy_changed(energy)` - Emitted when energy changes
  - `beam_fired(position, radius)` - Emitted when beam clears miasma
- **Public API:**
  - `set_mode(mode)` - Set beam mode (bubble/cone/laser)
  - `get_mode()` - Get current mode
  - `get_energy()` - Get current energy
  - `can_fire()` - Check if beam can fire
  - `clear_at_position(world_pos, radius)` - Clear miasma at position
  - `clear_cone(origin, direction, length, angle)` - Clear cone shape
  - `clear_laser(origin, direction, length, thickness)` - Clear laser shape

#### 5. **DerelictManager** (To be created)
- **Purpose:** Manages derelict (player) state, systems, health
- **Data:** Derelict position, health, systems state
- **Responsibilities:**
  - Track derelict position (world coordinates)
  - Manage hull integrity (health)
  - Track system states (legs, lighthouse, etc.)
  - Coordinate with other systems
- **Signals:**
  - `derelict_position_changed(pos)` - Emitted when derelict moves
  - `health_changed(health)` - Emitted when health changes
  - `system_changed(system_id, state)` - Emitted when system state changes
- **Public API:**
  - `get_position()` - Get derelict world position
  - `get_health()` - Get current health
  - `damage(amount)` - Apply damage

### Scene Nodes (Renderers & Game Objects)

These are scene-specific nodes that handle rendering and gameplay:

#### **MiasmaRenderer** ✅ (Already exists)
- **Purpose:** Renders miasma blocks using MultiMeshInstance3D
- **Data Source:** MiasmaManager (via signals)
- **Responsibilities:**
  - Listen to MiasmaManager.blocks_changed signal
  - Update MultiMesh when blocks change
  - Handle rendering performance (throttling)

#### **GroundRenderer** ✅ (Already exists)
- **Purpose:** Renders ground tiles
- **Data Source:** WorldManager (future)
- **Responsibilities:**
  - Render ground tiles based on biome
  - Update when chunks load/unload

#### **BeamRenderer** ✅ (Already exists)
- **Purpose:** Renders beam visual (ellipse/circle)
- **Data Source:** BeamManager (via signals)
- **Responsibilities:**
  - Visualize beam clearing area (bubble mode implemented)
  - Match visual to hitbox exactly
  - Update when beam mode/position changes
  - TODO: Cone and laser visuals not yet implemented

#### **BeamInput** ✅ (Already exists)
- **Purpose:** Handles input for beam mode switching
- **Responsibilities:**
  - Number keys (1-5) for direct mode switching
  - Mouse wheel for cycling through modes
  - Connects to BeamManager.set_mode()

#### **SimpleBeam** ✅ (Already exists)
- **Purpose:** Handles continuous beam clearing logic
- **Responsibilities:**
  - Clears miasma every frame based on current mode
  - Handles bubble, cone, and laser clearing
  - Uses mouse position for cone/laser direction

#### **Derelict** ✅ (Already exists, renamed from Player)
- **Purpose:** The derelict walker (player character)
- **Type:** CharacterBody3D
- **Responsibilities:**
  - Handle input (WASD/Arrow keys)
  - Move in world coordinates
  - Update MiasmaManager with position (directly, no DerelictManager yet)
  - Visual representation of derelict

### Data Flow

#### **Initialization Order:**
1. Autoloads initialize first (MiasmaManager, WindManager, WorldManager, etc.)
2. Scene loads (Derelict, Renderers)
3. Renderers connect to manager signals
4. Managers initialize their data
5. Game starts

#### **Update Flow (Per Frame):**

```
Derelict (input) 
  → Updates global_position directly
    → Calls MiasmaManager.update_player_position() directly
      → MiasmaManager updates blocks (on tile boundary crossing)
        → Emits: blocks_changed
          → MiasmaRenderer updates mesh (throttled)
    → Camera follows derelict (smooth interpolation)

BeamInput (user input)
  → Number keys or mouse wheel
    → Calls BeamManager.set_mode()
      → Emits: beam_mode_changed
        → BeamRenderer updates visual
        → SimpleBeam switches clearing mode

SimpleBeam (every frame)
  → Checks BeamManager.can_fire()
    → Calls BeamManager.clear_at_position/clear_cone/clear_laser()
      → BeamManager calls MiasmaManager.clear_area()
        → MiasmaManager updates blocks
          → Emits: blocks_changed
            → MiasmaRenderer updates mesh

BeamManager (every frame)
  → Updates energy (regen/drain based on mode)
    → Emits: beam_energy_changed
      → BeamRenderer updates visual opacity

WindManager (future)
  → _process() updates wind over time
    → Emits: wind_changed
      → MiasmaManager.advect_miasma() (not yet implemented)
        → Miasma blocks shift with wind
          → Emits: blocks_changed
            → MiasmaRenderer updates mesh
```

#### **Communication Patterns:**

**Signals (Event-Driven):**
- Managers emit signals when state changes
- Renderers listen to signals and update visuals
- Systems react to events, don't poll

**Public API (Data Access):**
- Managers expose public methods for data access
- Other systems call methods, don't access internal data directly
- Example: `MiasmaManager.clear_area()` not `MiasmaManager.blocks.erase()`

**No Direct References:**
- Systems don't hold direct references to each other
- Use `get_node("/root/ManagerName")` or signals
- Keeps systems decoupled

## Folder Structure

```
scripts/
  ├── managers/          # Autoload singletons
  │   ├── miasma_manager.gd ✅
  │   ├── beam_manager.gd ✅
  │   ├── wind_manager.gd (future)
  │   ├── world_manager.gd (future)
  │   └── derelict_manager.gd (future)
  │
  ├── renderers/         # Visual representation
  │   ├── miasma_renderer.gd ✅
  │   ├── ground_renderer.gd ✅
  │   └── beam_renderer.gd ✅
  │
  ├── beam/              # Beam system
  │   ├── simple_beam.gd ✅
  │   └── beam_input.gd ✅
  │
  ├── derelict/          # Derelict (player) systems
  │   └── derelict.gd ✅
  │
  ├── world/             # World generation
  │   └── ground_renderer.gd ✅
  │
  ├── camera/            # Camera systems
  │   ├── camera_follower.gd ✅
  │   └── isometric_camera.gd ✅
  │
  ├── ui/                # UI systems
  │   └── fps_display.gd ✅
  │
  └── debug/             # Debug tools
      └── player_trail.gd ✅

scenes/
  ├── test/              # Test scenes
  │   └── test_miasma.tscn ✅
  │
  └── derelict/          # Derelict scenes
      └── derelict.tscn ✅
```

## System Dependencies

```
WorldManager
  └── Provides biome data to:
      ├── MiasmaManager (biome affects miasma color/behavior)
      └── GroundRenderer (biome affects ground color)

WindManager
  └── Provides wind data to:
      └── MiasmaManager (wind advects miasma)

MiasmaManager
  └── Provides miasma data to:
      └── MiasmaRenderer (renders blocks)

BeamManager
  └── Calls:
      └── MiasmaManager.clear_area() (clears miasma)

DerelictManager
  └── Provides position to:
      ├── MiasmaManager (miasma follows player)
      ├── WorldManager (chunk loading)
      └── Camera (follows player)
```

## Best Practices Applied

1. **Godot Signals:** All inter-system communication via signals
2. **Autoloads:** Managers are singletons, accessible globally
3. **Separation:** Logic (managers) separate from visuals (renderers)
4. **Event-Driven:** Systems react to events, don't poll
5. **Single Responsibility:** Each system has one clear purpose
6. **Public API:** Systems expose methods, hide internal data
7. **No Circular Dependencies:** Clear dependency hierarchy

## Implementation Status

### ✅ Completed
- **Phase 1: Reorganize Current Code** - DONE
  - ✅ Moved managers to `scripts/managers/`
  - ✅ Moved renderers to `scripts/renderers/`
  - ✅ Renamed player to derelict
  - ✅ Updated all references

- **Phase 2: Core Managers** - PARTIAL
  - ✅ Created `BeamManager` (autoload)
  - ✅ Created `BeamInput` for mode switching
  - ✅ Created `BeamRenderer` (bubble mode visual)
  - ❌ `WindManager` (autoload) - Not yet created
  - ❌ `WorldManager` (autoload) - Not yet created
  - ❌ `DerelictManager` (autoload) - Not yet created

### ⏳ Remaining Work

**Phase 3: Visual Improvements**
- ❌ Implement cone visual in BeamRenderer
- ❌ Implement laser visual in BeamRenderer
- ✅ Beam clearing logic already works for all modes

**Phase 4: New Systems**
- ❌ Create `DerelictManager` for player state management
- ❌ Move player position tracking to `DerelictManager`
- ❌ Create `WindManager` for wind advection
- ❌ Implement wind advection in MiasmaManager
- ❌ Create `WorldManager` for biome system
- ❌ Implement chunking system

## Notes

- **Test Scene:** Keep `scenes/test/` for testing individual systems
- **Main Scene:** Create `scenes/game/game_world.tscn` for full game
- **Naming:** Use descriptive names, not abbreviations
- **Documentation:** Each manager should have clear API documentation
