# Coordinate Space Reference

## World Coordinate System

**Axes:**
- **X**: East/West (positive = East)
- **Y**: Up/Down (positive = Up)
- **Z**: North/South (positive = North)

**Origin:** (0, 0, 0) at world center

## Camera System

**Camera Type:** Orthographic, Isometric
**Position:** Follows player, offset by fixed distance
**Rotation:**
- **Elevation:** 30° (looking down at 30° angle)
- **Azimuth:** 45° (rotated 45° around Y axis)
- **No roll:** 0° (camera never rotates around its view axis)

**Camera View Direction:**
- Looking from Southeast toward Northwest
- At 30° elevation angle
- Rotated 45° around Y axis

## Ground Layer

**Position:** Y = -1.0 (world units)
**Tile Size:** 64x64 world units (square)
**Orientation:** Flat on XZ plane (horizontal)

## Miasma Layer

**Position:** Y = 8.0 (center of blocks, blocks are 16 units tall, so bottom at Y=0, top at Y=16)
**Tile Size:** 2x2 world units (square in world space)
**Orientation:** Blocks aligned to XZ grid
**Grid:** Snapped to 2-unit grid in X and Z

## Derelict (Player)

**Position:** Y = 0.0 (on ground level)
**Movement:** In XZ plane (Y stays at 0)
**Collision:** CharacterBody3D with capsule shape

## Beam Visual

**Position:** Y = 2.0 (above ground, above derelict)
**Shape:** Circle in world space (XZ plane)
**Orientation:** Flat on XZ plane (no rotation needed)
**Projection:** Circle appears as ellipse in isometric view (natural projection)

## Screen Space vs World Space

**Screen Directions (what player sees):**
- **Up on screen** = Northwest in world space (-X, +Z)
- **Down on screen** = Southeast in world space (+X, -Z)
- **Left on screen** = Southwest in world space (-X, -Z)
- **Right on screen** = Northeast in world space (+X, +Z)

**Input Mapping:**
- W (up) → world: (-X, +Z) = Northwest
- S (down) → world: (+X, -Z) = Southeast
- A (left) → world: (-X, -Z) = Southwest
- D (right) → world: (+X, +Z) = Northeast

## Isometric Projection Math

**For 30° elevation, 45° azimuth:**
- A circle on XZ plane appears compressed in isometric view
- Compression factor: cos(30°) ≈ 0.866
- To make circle appear circular: stretch by 1/cos(30°) ≈ 1.155
- **BUT:** For beam visual, we show actual circle - it naturally appears as ellipse (matches clearing)

## Key Rules

1. **Y=0** = Ground level (derelict position)
2. **Y=-1.0** = Ground tiles (below derelict)
3. **Y=2.0** = Beam visual (above derelict)
4. **Y=8.0** = Miasma block centers (blocks span Y=0 to Y=16)
5. **All movement** happens in XZ plane (Y stays constant)
6. **Camera** never rotates (fixed 30°/45° angles)
7. **Beam visual** = circle on XZ plane, no rotation needed

## Simplification Strategy

**Current Focus:** Core systems only
- Miasma: Binary tiles, permanent clearing
- Beam: Bubble mode, auto-active
- Player: Movement only

**Expansion Path:** Add features incrementally
- See `DOCS/system_simplification_plan.md` for full roadmap
