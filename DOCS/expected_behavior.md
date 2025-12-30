# Expected Behavior - Player Movement

## What You Should See

**When you press WASD/Arrow keys:**

1. **Player moves smoothly** through the world
2. **Camera follows player** - player stays centered on screen
3. **Miasma stays around player** - it regenerates only when you cross a tile boundary (not every frame)
4. **Purple blocks** should appear stationary relative to the player as you move

## Current Design

- **Miasma follows player** - viewport + buffer area around player
- **Miasma regenerates** only when player crosses a tile boundary (8x4 units)
- **Camera** smoothly follows player with isometric angle
- **Player** moves at 50 units/second

## What "Jittering" Means

If you see jittering, it could be:
- Miasma regenerating too often (should only happen when crossing tile boundaries)
- Camera snapping instead of smoothly following
- Player physics causing micro-movements

## Fixes Applied

1. ✅ Miasma only updates on tile boundary crossing
2. ✅ Camera uses smooth lerp interpolation
3. ✅ Player gravity disabled (no falling)

## Testing

Move with WASD - you should see:
- Smooth movement
- Camera follows smoothly
- Miasma updates only occasionally (when crossing tile boundaries)
- No jittering or stuttering
