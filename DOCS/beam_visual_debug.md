# Beam Visual Debug - Baby Steps

## The Problem
Visuals do not match clearing area.

## What We Need to Verify (Step by Step)

### Step 1: Verify Radius Values Match
**Question:** Are both systems using the same radius?

**Clearing system:**
- `SimpleBeam._clear_bubble()` gets radius from `beam_manager.get_clearing_params()`
- Should be `BUBBLE_MIN_RADIUS = 48.0`
- Passes this to `beam_manager.clear_at_position(world_pos, radius)`

**Visual system:**
- `BeamRenderer._update_bubble_visual()` gets radius from `beam_manager.get_clearing_radius()`
- Should also be `48.0`
- Uses this for cylinder mesh radius

**Check:** Print both values and verify they're the same.

---

### Step 2: Verify Position Values Match
**Question:** Are both systems using the same position?

**Clearing system:**
- `SimpleBeam._process()` uses `Vector3(derelict_pos.x, 0, derelict_pos.z)`
- This is derelict's ground position (Y=0)

**Visual system:**
- `BeamRenderer._process()` uses `Vector3(derelict_pos.x, 0, derelict_pos.z)`
- Sets `global_position = ground_pos`
- Then positions mesh at `Vector3(0, 2.0, 0)` relative to that

**Check:** Print both positions and verify they match (X and Z should be identical).

---

### Step 3: Verify Clearing Logic
**Question:** How does `MiasmaManager.clear_area()` work?

**Current logic:**
```gdscript
var center_tile_x = int(world_pos.x / MIASMA_TILE_SIZE_X)
var center_tile_z = int(world_pos.z / MIASMA_TILE_SIZE_Z)
var radius_tiles = int(radius / MIASMA_TILE_SIZE_X) + 1
```

**For radius 48.0:**
- `radius_tiles = int(48.0 / 2.0) + 1 = 25 tiles`
- So clearing area is 25 tiles in radius
- Each tile is 2.0 units, so that's 50 units total diameter
- But we're using radius 48.0, so diameter should be 96 units

**Issue?** The clearing uses tile-based logic, which might not match the exact circle radius.

---

### Step 4: Visual Representation
**Question:** What does the visual actually show?

**Current visual:**
- CylinderMesh with `top_radius = 48.0` and `bottom_radius = 48.0`
- Rotated 90° around X (flat on XZ plane)
- Positioned at Y=2.0 above ground
- In isometric view, appears as ellipse

**The visual should show:**
- A circle of radius 48.0 in world space
- Which appears as an ellipse in isometric view

---

## Diagnostic Steps

### Step 1: Add Debug Prints
Add prints to verify:
1. What radius is being used for clearing?
2. What radius is being used for visual?
3. What position is being used for clearing?
4. What position is being used for visual?

### Step 2: Visualize the Clearing Area
Add a debug visualization to show:
- The exact tiles being cleared
- The circle boundary (radius 48.0)
- Compare with visual ellipse

### Step 3: Check Coordinate Systems
Verify:
- Are both using world coordinates?
- Are both using the same origin?
- Is there any offset or transformation?

---

## Potential Issues

1. **Radius mismatch:** Visual and clearing using different values
2. **Position mismatch:** Visual and clearing at different positions
3. **Tile-based clearing:** Clearing uses discrete tiles, visual uses continuous circle
4. **Coordinate system:** Different coordinate spaces (world vs local)
5. **Isometric projection:** Visual appears as ellipse, but clearing is circle - might look different

---

## Next Steps

1. Add debug prints to verify radius and position match
2. Add visual debug to show clearing area
3. Compare tile-based clearing with continuous circle
4. Adjust based on findings
