# World Generation Implementation Plan

## Overview
Procedurally generated world with 12 biomes using Voronoi diagram. Starting with 3 biomes (Meadow, Desert, Volcano) for MVP.

## Core Requirements

### Voronoi Generation
- **16 points** using Poisson disc sampling
- **Minimum distance:** 16 ground tiles (1024 world units)
- **World size:** 1000x1000 ground tiles
- **Biome assignment:** Random assignment of 12 biomes to Voronoi cells (distinct, no repeats)
- **Generation:** On load from seed (deterministic)

### Chunk System
- **Chunk size:** 64x64 ground tiles (4096x4096 world units)
- **Loading:** On-demand as player moves (viewport + buffer)
- **Persistence:** Via seed (regenerate deterministically when returning)
- **Multi-biome:** Chunks can contain multiple biomes (Voronoi boundaries can cross chunks)

### Biomes (MVP - 3 biomes)
1. **Meadow**
   - Color: Green and dark green pastel (use green for now)
   - RGB: (0.4, 0.8, 0.4) - pastel green
   - Player always starts here

2. **Desert**
   - Color: Tan and yellow (use tan for now)
   - RGB: (0.9, 0.8, 0.6) - tan

3. **Volcano**
   - Color: Dark warm gray and orange (use dark gray for now)
   - RGB: (0.3, 0.25, 0.2) - dark warm gray

### Ground Tiles
- **Size:** 64x64 world units (already implemented)
- **Rendering:** Solid colors based on biome
- **Texture:** Solid colors for now (can upgrade to pixel art sprites later)

## Architecture

### New Components

#### 1. **WorldManager** (Autoload Singleton)
**Purpose:** Manages world generation, biome map, chunk loading

**Responsibilities:**
- Generate Voronoi diagram on load (from seed)
- Assign biomes to Voronoi cells
- Provide biome lookup API (`get_biome_at(world_pos) -> BiomeType`)
- Manage chunk loading/unloading
- Store world seed

**Data:**
- `world_seed: int` - Seed for world generation
- `voronoi_points: Array[Vector2]` - 16 Voronoi seed points
- `biome_assignments: Dictionary` - Voronoi cell index → BiomeType
- `loaded_chunks: Dictionary` - Chunk key → ChunkData (for caching)

**Public API:**
- `initialize_world(seed: int)` - Generate world from seed
- `get_biome_at(world_pos: Vector3) -> BiomeType` - Get biome at world position
- `get_chunk_at(world_pos: Vector3) -> ChunkData` - Get chunk data (generates if needed)
- `get_ground_color_at(world_pos: Vector3) -> Color` - Get ground color at position

**Signals:**
- `world_generated()` - Emitted when world is generated
- `chunk_loaded(chunk_key: String)` - Emitted when chunk is loaded

#### 2. **BiomeType** (Enum)
```gdscript
enum BiomeType {
    MEADOW,
    DESERT,
    VOLCANO,
    # Future: 9 more biomes
}
```

#### 3. **GroundRenderer** (Update Existing)
**Changes:**
- Query `WorldManager.get_ground_color_at()` for each tile
- Use biome color instead of fixed green/brown
- Keep existing tile size and rendering logic

#### 4. **VoronoiGenerator** (Utility Class)
**Purpose:** Generate Voronoi diagram from seed

**Functions:**
- `generate_poisson_points(count: int, min_distance: float, world_size: Vector2, seed: int) -> Array[Vector2]`
- `get_voronoi_cell(point: Vector2, points: Array[Vector2], query_pos: Vector2) -> int` - Returns index of closest point
- `assign_biomes_to_cells(points: Array[Vector2], seed: int) -> Dictionary` - Randomly assigns 12 biomes

## Implementation Phases

### Phase 1: Voronoi Generation (Foundation)
**Goal:** Generate Voronoi diagram and assign biomes

**Tasks:**
1. Create `WorldManager` autoload singleton
2. Create `BiomeType` enum
3. Implement Poisson disc sampling (16 points, min distance 16 tiles)
4. Implement Voronoi cell lookup (closest point calculation)
5. Implement random biome assignment (12 biomes, distinct)
6. Test: Generate world, verify 16 points, verify biome assignments

**Files:**
- `scripts/managers/world_manager.gd` (new)
- `scripts/world/voronoi_generator.gd` (new utility)

**Testing:**
- Generate world with fixed seed, verify deterministic
- Check that all 16 points have distinct biomes
- Verify minimum distance between points

### Phase 2: Biome Lookup API
**Goal:** Query biome at any world position

**Tasks:**
1. Implement `get_biome_at(world_pos: Vector3) -> BiomeType`
   - Convert world pos to ground tile coordinates
   - Find closest Voronoi point
   - Return assigned biome
2. Implement `get_ground_color_at(world_pos: Vector3) -> Color`
   - Get biome, return corresponding color
3. Test: Query various positions, verify correct biomes

**Files:**
- `scripts/managers/world_manager.gd` (update)

**Testing:**
- Query positions in different Voronoi cells
- Verify boundaries are correct
- Test edge cases (world boundaries)

### Phase 3: Chunk System
**Goal:** Load chunks on-demand as player moves

**Tasks:**
1. Define chunk size (64x64 ground tiles)
2. Implement chunk key system (`"chunk_x,chunk_z"`)
3. Implement `get_chunk_at(world_pos: Vector3) -> ChunkData`
   - Generate chunk if not loaded
   - Cache loaded chunks
4. Implement chunk unloading (remove from cache when far away)
5. Test: Move player, verify chunks load/unload

**Files:**
- `scripts/managers/world_manager.gd` (update)
- `scripts/world/chunk_data.gd` (new, if needed)

**Testing:**
- Move player, verify chunks load
- Move far away, verify old chunks unload
- Return to area, verify chunks regenerate (deterministic)

### Phase 4: Ground Renderer Integration
**Goal:** Render ground tiles with biome colors

**Tasks:**
1. Update `GroundRenderer` to query `WorldManager.get_ground_color_at()`
2. Replace fixed green/brown with biome colors
3. Keep existing tile rendering logic (centers and borders)
4. Test: Visual verification of biome colors

**Files:**
- `scripts/renderers/ground_renderer.gd` (update)

**Testing:**
- Visual check: Different biomes show different colors
- Performance: Still maintains 60 FPS
- Boundaries: Biome boundaries visible

### Phase 5: Player Starting Position
**Goal:** Player always starts in meadow biome

**Tasks:**
1. Find meadow biome Voronoi cell
2. Set player starting position to center of meadow cell
3. Test: Player spawns in green (meadow) area

**Files:**
- `scripts/managers/world_manager.gd` (update)
- `scripts/derelict/derelict.gd` (update, or scene setup)

**Testing:**
- Verify player always starts in meadow
- Verify meadow is green

## Technical Details

### Poisson Disc Sampling
- Use Poisson disc sampling algorithm
- Minimum distance: 16 ground tiles = 1024 world units
- World size: 1000x1000 ground tiles = 64000x64000 world units
- Generate 16 points

### Voronoi Cell Lookup
- For any position, find closest Voronoi point
- Use Euclidean distance: `distance = sqrt((x1-x2)^2 + (z1-z2)^2)`
- Return index of closest point
- Use that index to look up biome assignment

### Biome Color Mapping
```gdscript
func get_biome_color(biome: BiomeType) -> Color:
    match biome:
        BiomeType.MEADOW:
            return Color(0.4, 0.8, 0.4)  # Pastel green
        BiomeType.DESERT:
            return Color(0.9, 0.8, 0.6)  # Tan
        BiomeType.VOLCANO:
            return Color(0.3, 0.25, 0.2)  # Dark warm gray
        _:
            return Color.WHITE  # Fallback
```

### Chunk Loading Strategy
- **Viewport size:** ~1152x648 pixels
- **World units visible:** ~200x112.5 (at current camera)
- **Ground tiles visible:** ~3x2 tiles
- **Chunk buffer:** Load 2-3 chunks in each direction
- **Total chunks loaded:** ~5x5 = 25 chunks max

### Seed-Based Generation
- Use `RandomNumberGenerator` with seed
- All random operations use same RNG instance
- Same seed = same world (deterministic)
- Store seed in `WorldManager` for regeneration

## Performance Considerations

### Optimization Strategies
1. **Chunk caching:** Cache generated chunks in memory
2. **Lazy generation:** Only generate chunks when needed
3. **Distance culling:** Don't generate chunks too far from player
4. **Biome lookup caching:** Cache biome lookups per chunk

### Performance Targets
- **60 FPS** maintained during chunk loading
- **Chunk generation:** < 1ms per chunk
- **Biome lookup:** < 0.1ms per lookup

## Future Enhancements (Post-MVP)

1. **Remaining 9 biomes:** Add 9 more biome types
2. **Biome variations:** Multiple colors per biome
3. **Pixel art tiles:** Replace solid colors with sprite textures
4. **Biome-specific features:**
   - Miasma behavior (future)
   - Wind behavior (future)
   - Other mechanics (future)
5. **Biome transitions:** Smooth color blending at boundaries
6. **Biome decorations:** Visual elements per biome

## Testing Strategy

### Unit Tests
- Poisson disc sampling: Verify minimum distance
- Voronoi lookup: Verify correct cell assignment
- Biome assignment: Verify all 12 biomes assigned (distinct)
- Seed determinism: Same seed = same world

### Integration Tests
- Chunk loading: Verify chunks load as player moves
- Chunk regeneration: Verify deterministic regeneration
- Ground rendering: Verify correct colors

### Visual Tests
- Biome boundaries: Visible and correct
- Colors: Distinct and recognizable
- Performance: 60 FPS maintained

## Questions to Resolve

1. **Chunk data structure:** What data should chunks store? (Just biome map, or more?)
2. **Biome boundary rendering:** Should boundaries be sharp or blended?
3. **World persistence:** Should we save generated chunks to disk, or always regenerate?
4. **Starting seed:** Should seed be random, or configurable?

## Next Steps

1. **Review this plan** - Confirm approach and details
2. **Start Phase 1** - Implement Voronoi generation
3. **Iterate** - Build and test incrementally
