# Architecture Design Session

## Current State

### ✅ Completed Systems
1. **MiasmaManager** - Autoload singleton
   - Manages miasma block state (Dictionary)
   - Handles clearing (permanent)
   - Emits `blocks_changed` signal
   - Provides `clear_area()` API

2. **BeamManager** - Autoload singleton (just created)
   - Manages beam modes (BUBBLE_MIN, BUBBLE_MAX, CONE, LASER)
   - Handles energy system
   - Provides `clear_at_position()` API
   - Emits mode/energy/fired signals

3. **MiasmaRenderer** - Scene node
   - Renders miasma blocks via MultiMeshInstance3D
   - Listens to MiasmaManager signals
   - Throttles updates for performance

4. **GroundRenderer** - Scene node
   - Renders ground tiles
   - Currently static (no biome support yet)

5. **BeamRenderer** - Scene node
   - Renders beam visual (ellipse)
   - Listens to BeamManager signals

6. **Derelict** (Player) - CharacterBody3D
   - Handles input (WASD/Arrow keys)
   - Moves in world coordinates
   - Updates MiasmaManager directly (should use DerelictManager)

### 🔨 Systems To Design/Create

1. **DerelictManager** - Autoload singleton
   - **Purpose:** Central hub for player state
   - **Data:** Position, health, systems, crew
   - **Responsibilities:**
     - Track derelict position (world coords)
     - Manage hull integrity
     - Track 16 systems (legs, lighthouse, etc.)
     - Coordinate with other managers
   - **Signals:**
     - `derelict_position_changed(pos)`
     - `health_changed(health)`
     - `system_changed(system_id, state)`
   - **Questions:**
     - Should Derelict node send input to DerelictManager, or handle movement itself?
     - How should systems be represented? Dictionary? Array?
     - Should DerelictManager own the position, or just track it?

2. **WindManager** - Autoload singleton
   - **Purpose:** Global wind system
   - **Data:** Wind velocity (vx, vy), wind strength, direction
   - **Responsibilities:**
     - Calculate wind based on biome/weather
     - Update wind over time
     - Provide wind data to MiasmaManager
   - **Signals:**
     - `wind_changed(velocity)`
   - **Questions:**
     - Should wind be global or per-biome?
     - How often should wind change?
     - Should wind affect other systems (sound signature, etc.)?

3. **WorldManager** - Autoload singleton
   - **Purpose:** World generation, biomes, chunks
   - **Data:** Biome map, chunk data, world seed
   - **Responsibilities:**
     - Generate seeded world
     - Manage 12 biomes
     - Handle chunk loading/unloading
     - Provide biome data
   - **Signals:**
     - `chunk_loaded(chunk_pos)`
     - `biome_changed(biome_id)`
   - **Questions:**
     - How large should chunks be?
     - How should biomes be generated? Perlin noise?
     - Should chunks be persistent or regenerated?

## Architecture Questions

### 1. Derelict Position Ownership
**Option A:** Derelict node owns position, DerelictManager tracks it
- Derelict node handles input/movement
- DerelictManager listens to position changes
- Simple, but DerelictManager is passive

**Option B:** DerelictManager owns position, Derelict node displays it
- DerelictManager handles input/movement logic
- Derelict node just renders position
- More centralized, but more complex

**Recommendation:** Option A (Derelict owns, Manager tracks)
- Keeps input handling in scene node
- DerelictManager can still coordinate with other systems
- Easier to implement

### 2. System Communication Pattern
**Current:** Direct calls (Derelict → MiasmaManager)
**Proposed:** Event-driven (Derelict → DerelictManager → signals → other managers)

**Flow:**
```
Derelict (input)
  → DerelictManager.update_position()
    → Emits: derelict_position_changed
      → MiasmaManager.update_player_position()
      → WorldManager.update_player_position()
      → Camera follows
```

**Benefits:**
- Decoupled systems
- Easy to add new systems that react to position
- Clear data flow

### 3. Wind System Design
**Questions:**
- Global wind or per-biome?
- How does wind interact with miasma?
- Should wind be deterministic (seed-based) or dynamic?

**Proposed:**
- Global wind with biome modifiers
- Wind advects miasma (moves blocks)
- Deterministic based on world seed + time

### 4. Chunk System Design
**Questions:**
- Chunk size? (e.g., 64x64 tiles = 512x512 world units?)
- When to load/unload?
- Should chunks be cached or regenerated?

**Proposed:**
- Chunk size: 64x64 miasma tiles (512x512 world units)
- Load chunks within viewport + 2 chunk buffer
- Cache chunks, regenerate on seed change

## Next Steps

1. **Design DerelictManager API**
   - Define what data it owns
   - Define signals it emits
   - Define how it interacts with Derelict node

2. **Design WindManager API**
   - Define wind data structure
   - Define how wind updates
   - Define integration with MiasmaManager

3. **Design WorldManager API**
   - Define chunk system
   - Define biome system
   - Define world generation

4. **Refactor Current Code**
   - Move Derelict position tracking to DerelictManager
   - Connect systems via signals
   - Remove direct calls between systems

## Open Questions

1. Should DerelictManager handle input, or just track state?
2. How should the 16 systems be represented? (Dictionary? Array? Enum?)
3. Should wind be per-biome or global?
4. What's the chunk size and loading strategy?
5. How should biomes be generated? (Perlin noise? Voronoi? Grid-based?)
