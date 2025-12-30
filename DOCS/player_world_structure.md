# Player & World Structure

## Design Philosophy

**World Coordinates System:**
- Player moves through **world space** (infinite/large seeded world)
- Player's world position: `Vector3(x, y, z)` in world units
- Camera **always centered on player** (player appears at screen center)
- World moves around player, not player moving on screen

## Structure

### Player
- **Type:** `CharacterBody3D`
- **Position:** World coordinates (`world_position`)
- **Movement:** WASD/Arrow keys move player in world space
- **Group:** `"player"` (for camera to find)

### Camera
- **Type:** `Camera3D` (orthographic, isometric)
- **Behavior:** Always follows player, stays centered
- **Angle:** 30° elevation, 45° rotation (isometric)
- **Distance:** Fixed distance from player

### World
- **Infinite/Large:** Seeded random generation
- **Coordinates:** World space (0,0,0 is world origin)
- **Player starts at:** World origin (0,0,0)
- **As player moves:** World generates/loads around player

## Implementation

1. **Player Script:**
   - Stores `world_position` (Vector3)
   - Moves in world space based on input
   - Updates `global_position` for rendering
   - Notifies MiasmaManager of position changes

2. **Camera Script:**
   - Finds player (by group or name)
   - Follows player's world position
   - Maintains isometric angle
   - Always looks at player

3. **Miasma (Future):**
   - Updates based on player's world position
   - Loads/unloads chunks as player moves
   - Miasma "follows" player (viewport + buffer)

## Benefits

- **Scalable:** Works with infinite worlds
- **Seeded:** World generation can use player position + seed
- **Performance:** Only render/update what's near player
- **Simple:** Player always at center, world moves around them
