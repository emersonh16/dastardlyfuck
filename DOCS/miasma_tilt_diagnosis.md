# Miasma Tilt Diagnosis

## Problem
When moving left, miasma layer tilts down in clockwise motion (slightly).

## Possible Causes

1. **Camera Rotation Drift**
   - `look_at()` might be causing slight rotation
   - Camera rotation values changing slightly

2. **Miasma Grid Snapping**
   - Blocks not snapping correctly to grid
   - Tile position calculation rounding errors

3. **Block Update Timing**
   - Blocks updating at wrong time causing visual shift
   - Smooth interpolation vs instant snapping

## Diagnostic Steps

### 1. Check Camera Rotation
Add to `camera_follower.gd` in `_process()`:
```gdscript
print("Camera rotation: ", rotation_degrees)
print("Camera basis: ", basis)
```

### 2. Check Miasma Block Positions
Add to `miasma_renderer.gd` in `_do_render_update()`:
```gdscript
if index < 5:  # Print first 5 blocks
    print("Block ", index, ": tile_pos=", tile_pos, " world_pos=(", world_x, ", ", world_z, ")")
```

### 3. Check Player Tile Position
Add to `miasma_manager.gd` in `update_player_position()`:
```gdscript
print("Player tile: (", new_center_x, ", ", new_center_z, ") world: ", new_pos)
```

### 4. Check if Camera is Actually Rotating
In Godot inspector:
- Select Camera3D node
- Watch Transform > Rotation values while moving
- If they change, camera is rotating

## Most Likely Cause
Camera rotation drift from `look_at()` - the camera might be slightly rotating when following the player.
