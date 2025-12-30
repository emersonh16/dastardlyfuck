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

#### 4. **BeamManager** (To be created)
- **Purpose:** Manages beam system (bubble/cone/laser modes, energy)
- **Data:** Beam mode, energy level, beam state
- **Responsibilities:**
  - Handle beam mode switching
  - Manage energy/cooldown
  - Calculate beam clearing areas
  - Call MiasmaManager.clear_area() when beam fires
- **Signals:**
  - `beam_mode_changed(mode)` - Emitted when mode changes
  - `beam_energy_changed(energy)` - Emitted when energy changes
  - `beam_fired(position, radius)` - Emitted when beam clears miasma
- **Public API:**
  - `set_mode(mode)` - Set beam mode (bubble/cone/laser)
  - `get_energy()` - Get current energy
  - `fire_beam(position, direction)` - Fire beam at position

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

#### **BeamRenderer** (To be created)
- **Purpose:** Renders beam visual (ellipse/circle)
- **Data Source:** BeamManager (via signals)
- **Responsibilities:**
  - Visualize beam clearing area
  - Match visual to hitbox exactly
  - Update when beam mode/position changes

#### **Derelict** (Player node - rename from Player)
- **Purpose:** The derelict walker (player character)
- **Type:** CharacterBody3D
- **Responsibilities:**
  - Handle input (WASD/Arrow keys)
  - Move in world coordinates
  - Update DerelictManager with position
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
  → DerelictManager.update_position()
    → Emits: derelict_position_changed
      → MiasmaManager.update_player_position()
      → WorldManager.update_player_position()
      → Camera follows derelict

BeamManager (always active bubble mode)
  → _process() checks if should clear
    → Calls MiasmaManager.clear_area()
      → MiasmaManager updates blocks
        → Emits: blocks_changed
          → MiasmaRenderer updates mesh

WindManager
  → _process() updates wind over time
    → Emits: wind_changed
      → MiasmaManager.advect_miasma()
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
  │   ├── wind_manager.gd
  │   ├── world_manager.gd
  │   ├── beam_manager.gd
  │   └── derelict_manager.gd
  │
  ├── renderers/         # Visual representation
  │   ├── miasma_renderer.gd ✅
  │   ├── ground_renderer.gd ✅
  │   └── beam_renderer.gd
  │
  ├── derelict/          # Derelict (player) systems
  │   ├── derelict.gd (rename from player.gd)
  │   ├── derelict_systems.gd
  │   └── derelict_health.gd
  │
  ├── world/             # World generation
  │   ├── biome_manager.gd
  │   ├── chunk_manager.gd
  │   └── world_generator.gd
  │
  ├── camera/            # Camera systems
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
  ├── game/              # Main game scenes (future)
  │   └── game_world.tscn
  │
  └── derelict/          # Derelict scenes
      └── derelict.tscn (rename from player.tscn)
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

## Migration Plan

### Phase 1: Reorganize Current Code
1. Move `scripts/miasma/miasma_manager.gd` → `scripts/managers/miasma_manager.gd`
2. Move `scripts/miasma/miasma_renderer.gd` → `scripts/renderers/miasma_renderer.gd`
3. Rename `scripts/player/player.gd` → `scripts/derelict/derelict.gd`
4. Rename `scenes/player/player.tscn` → `scenes/derelict/derelict.tscn`
5. Update all references

### Phase 2: Create New Managers
1. Create `WindManager` (autoload)
2. Create `WorldManager` (autoload)
3. Create `BeamManager` (autoload)
4. Create `DerelictManager` (autoload)

### Phase 3: Refactor Existing Systems
1. Move beam logic from `SimpleBeam` to `BeamManager`
2. Move player position tracking to `DerelictManager`
3. Connect systems via signals
4. Update renderers to use new managers

### Phase 4: Add New Systems
1. Implement wind advection in MiasmaManager
2. Implement biome system in WorldManager
3. Implement chunking system
4. Add beam modes (cone/laser)

## Notes

- **Test Scene:** Keep `scenes/test/` for testing individual systems
- **Main Scene:** Create `scenes/game/game_world.tscn` for full game
- **Naming:** Use descriptive names, not abbreviations
- **Documentation:** Each manager should have clear API documentation
