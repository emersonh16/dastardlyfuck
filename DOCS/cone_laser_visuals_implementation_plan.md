# Cone & Laser Visuals Implementation Plan

## Overview

This document provides a detailed plan for implementing cone and laser beam visuals in `BeamRenderer`. The implementation follows the same architecture pattern as the bubble visual: **single source of truth** from `BeamManager`, visual matches hitbox exactly.

## Current State

### ✅ What's Working
- **Bubble visual**: Fully implemented with custom circle mesh
- **Cone clearing**: Logic works, clears miasma correctly
- **Laser clearing**: Logic works, clears miasma correctly
- **Mouse direction**: `SimpleBeam._get_mouse_world_position()` provides mouse world position
- **Mode switching**: BeamInput handles mode changes

### ❌ What's Missing
- **Cone visual**: No visual representation (TODO in `_on_beam_mode_changed`)
- **Laser visual**: No visual representation (TODO in `_on_beam_mode_changed`)

## Architecture Principles

Following the established pattern from bubble visual:

1. **Single Source of Truth**: All parameters come from `BeamManager`
2. **Visual Matches Hitbox**: Visual represents the exact clearing area
3. **Isometric Projection**: Shapes appear naturally in isometric view (no pre-distortion)
4. **Real-time Updates**: Visual updates every frame as mouse moves
5. **Shared Material**: Same gold translucent material for all modes

## Cone Visual Design

### Parameters (from BeamManager)
- **Origin**: Player position at ground level (Y=0)
- **Direction**: From player to mouse position (normalized)
- **Length**: `CONE_LENGTH = 64.0` world units
- **Angle**: `CONE_ANGLE_DEG = 32.0` degrees (half-angle from center)

### Visual Representation

**Option A: Sector Mesh (Recommended)**
- Create a flat sector (pie slice) on XZ plane
- Sector spans from origin, expanding outward
- Angle: 32° half-angle = 64° total angle
- Length: 64.0 units from origin
- Shape: Flat on XZ plane (Y=0), rotated to point in direction

**Option B: Multiple Circles**
- Draw expanding circles along the cone path
- Similar to how clearing works (multiple stamps)
- More complex, less clean

**Recommendation**: Option A (Sector Mesh)

### Implementation Details

#### 1. Create Sector Mesh Function
```gdscript
func _create_cone_sector_mesh(origin: Vector3, direction: Vector3, length: float, angle_deg: float) -> ArrayMesh
```

**Parameters:**
- `origin`: Starting point (Vector3 at Y=0)
- `direction`: Direction vector (normalized, in XZ plane)
- `length`: Distance from origin to tip
- `angle_deg`: Half-angle in degrees (32°)

**Mesh Generation:**
1. Calculate sector vertices:
   - Origin vertex at (0, 0, 0) in local space
   - Tip vertex at (length, 0, 0) in local space (along direction)
   - Left edge: rotate direction by -angle_deg around Y axis
   - Right edge: rotate direction by +angle_deg around Y axis
   - Create arc vertices between edges (for smooth curve)

2. Generate triangles:
   - Fan pattern from origin to arc vertices
   - Creates filled sector shape

3. Rotate mesh to match direction:
   - Calculate rotation angle from default forward (1, 0, 0) to direction
   - Apply rotation to all vertices

#### 2. Update Process Function
In `_process()`, update cone visual every frame:
- Get mouse world position (reuse `SimpleBeam._get_mouse_world_position()` logic)
- Calculate direction from player to mouse
- Recreate sector mesh with new direction
- Update mesh instance

#### 3. Integration Points
- `_on_beam_mode_changed()`: Create initial cone mesh when mode switches to CONE
- `_process()`: Update cone direction every frame
- `_update_cone_visual()`: Helper function to update cone mesh

### Code Structure

```gdscript
# In BeamRenderer

var cone_direction: Vector3 = Vector3(1, 0, 0)  # Default forward
var camera: Camera3D = null  # For mouse-to-world conversion

func _ready():
    # ... existing code ...
    camera = get_viewport().get_camera_3d()

func _create_cone_sector_mesh(origin: Vector3, direction: Vector3, length: float, angle_deg: float) -> ArrayMesh:
    # Generate sector mesh
    # Return ArrayMesh

func _update_cone_visual(origin: Vector3, direction: Vector3):
    # Get parameters from BeamManager
    # Create/update cone mesh
    # Position and rotate mesh

func _process(_delta):
    # ... existing bubble code ...
    
    if beam_manager.get_mode() == BeamManager.BeamMode.CONE:
        var mouse_pos = _get_mouse_world_position()
        if mouse_pos != Vector3.ZERO:
            var direction = (mouse_pos - global_position).normalized()
            _update_cone_visual(global_position, direction)
```

## Laser Visual Design

### Parameters (from BeamManager)
- **Origin**: Player position at ground level (Y=0)
- **Direction**: From player to mouse position (normalized)
- **Length**: `LASER_LENGTH = 128.0` world units
- **Thickness**: `LASER_THICKNESS = 4.0` world units (diameter)

### Visual Representation

**Option A: Flat Rectangle (Recommended)**
- Create a flat rectangle on XZ plane
- Width: `LASER_THICKNESS` (4.0 units)
- Length: `LASER_LENGTH` (128.0 units)
- Centered along direction vector
- Rotated to point in direction

**Option B: Cylinder**
- 3D cylinder along the laser path
- More complex, might occlude view

**Recommendation**: Option A (Flat Rectangle)

### Implementation Details

#### 1. Create Rectangle Mesh Function
```gdscript
func _create_laser_rectangle_mesh(origin: Vector3, direction: Vector3, length: float, thickness: float) -> ArrayMesh
```

**Parameters:**
- `origin`: Starting point (Vector3 at Y=0)
- `direction`: Direction vector (normalized, in XZ plane)
- `length`: Distance from origin to end
- `thickness`: Width of laser (4.0 units)

**Mesh Generation:**
1. Create rectangle vertices:
   - 4 vertices forming a rectangle
   - Width: `thickness` perpendicular to direction
   - Length: `length` along direction
   - Centered at origin, extending forward

2. Generate triangles:
   - Two triangles forming the rectangle
   - Simple quad shape

3. Rotate mesh to match direction:
   - Calculate rotation from default forward to direction
   - Apply rotation to all vertices

#### 2. Update Process Function
In `_process()`, update laser visual every frame:
- Get mouse world position
- Calculate direction from player to mouse
- Recreate rectangle mesh with new direction
- Update mesh instance

#### 3. Integration Points
- `_on_beam_mode_changed()`: Create initial laser mesh when mode switches to LASER
- `_process()`: Update laser direction every frame
- `_update_laser_visual()`: Helper function to update laser mesh

### Code Structure

```gdscript
# In BeamRenderer

func _create_laser_rectangle_mesh(origin: Vector3, direction: Vector3, length: float, thickness: float) -> ArrayMesh:
    # Generate rectangle mesh
    # Return ArrayMesh

func _update_laser_visual(origin: Vector3, direction: Vector3):
    # Get parameters from BeamManager
    # Create/update laser mesh
    # Position and rotate mesh

func _process(_delta):
    # ... existing code ...
    
    if beam_manager.get_mode() == BeamManager.BeamMode.LASER:
        var mouse_pos = _get_mouse_world_position()
        if mouse_pos != Vector3.ZERO:
            var direction = (mouse_pos - global_position).normalized()
            _update_laser_visual(global_position, direction)
```

## Shared Helper Functions

### Mouse Position Helper
Reuse the mouse-to-world conversion logic from `SimpleBeam`:

```gdscript
func _get_mouse_world_position() -> Vector3:
    # Convert mouse screen position to world position on ground plane (Y=0)
    if not camera:
        return Vector3.ZERO
    
    var mouse_pos = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse_pos)
    var dir = camera.project_ray_normal(mouse_pos)
    
    # Intersect with ground plane (Y=0)
    if abs(dir.y) < 0.001:
        return Vector3.ZERO
    
    var t = -from.y / dir.y
    if t < 0:
        return Vector3.ZERO
    
    var world_pos = from + dir * t
    return Vector3(world_pos.x, 0, world_pos.z)
```

## Step-by-Step Implementation

### Phase 1: Cone Visual

1. **Add helper variables** to `BeamRenderer`:
   - `var camera: Camera3D = null`
   - `var cone_direction: Vector3 = Vector3(1, 0, 0)`

2. **Initialize camera** in `_ready()`:
   ```gdscript
   camera = get_viewport().get_camera_3d()
   ```

3. **Create `_get_mouse_world_position()` function**:
   - Copy logic from `SimpleBeam._get_mouse_world_position()`
   - Or extract to shared utility (future refactor)

4. **Create `_create_cone_sector_mesh()` function**:
   - Generate sector vertices (origin + arc)
   - Create triangles (fan pattern)
   - Return ArrayMesh

5. **Create `_update_cone_visual()` function**:
   - Get parameters from `BeamManager.get_clearing_params()`
   - Call `_create_cone_sector_mesh()`
   - Update `beam_mesh_instance.mesh`
   - Set visibility

6. **Update `_on_beam_mode_changed()`**:
   - For CONE mode: call `_update_cone_visual()` with default direction
   - Set `beam_mesh_instance.visible = true`

7. **Update `_process()`**:
   - If mode is CONE: get mouse position, calculate direction, update visual

8. **Test cone visual**:
   - Switch to cone mode (key 4)
   - Move mouse around
   - Verify visual follows mouse
   - Verify visual matches clearing area

### Phase 2: Laser Visual

1. **Create `_create_laser_rectangle_mesh()` function**:
   - Generate rectangle vertices
   - Create triangles (2 triangles = quad)
   - Return ArrayMesh

2. **Create `_update_laser_visual()` function**:
   - Get parameters from `BeamManager.get_clearing_params()`
   - Call `_create_laser_rectangle_mesh()`
   - Update `beam_mesh_instance.mesh`
   - Set visibility

3. **Update `_on_beam_mode_changed()`**:
   - For LASER mode: call `_update_laser_visual()` with default direction
   - Set `beam_mesh_instance.visible = true`

4. **Update `_process()`**:
   - If mode is LASER: get mouse position, calculate direction, update visual

5. **Test laser visual**:
   - Switch to laser mode (key 5)
   - Move mouse around
   - Verify visual follows mouse
   - Verify visual matches clearing area

## Testing Checklist

### Cone Visual
- [ ] Visual appears when switching to cone mode (key 4)
- [ ] Visual follows mouse movement smoothly
- [ ] Visual points in correct direction (toward mouse)
- [ ] Visual length matches `CONE_LENGTH` (64.0 units)
- [ ] Visual angle matches `CONE_ANGLE_DEG` (32° half-angle)
- [ ] Visual clearing area matches visual shape
- [ ] Visual disappears when switching to other modes
- [ ] Visual opacity responds to energy level

### Laser Visual
- [ ] Visual appears when switching to laser mode (key 5)
- [ ] Visual follows mouse movement smoothly
- [ ] Visual points in correct direction (toward mouse)
- [ ] Visual length matches `LASER_LENGTH` (128.0 units)
- [ ] Visual thickness matches `LASER_THICKNESS` (4.0 units)
- [ ] Visual clearing area matches visual shape
- [ ] Visual disappears when switching to other modes
- [ ] Visual opacity responds to energy level

### Integration
- [ ] Switching between modes works correctly
- [ ] All modes use same material (gold, translucent)
- [ ] Energy-based opacity works for all modes
- [ ] No performance issues (60 FPS maintained)
- [ ] Visuals don't interfere with each other

## Technical Details

### Mesh Generation Math

#### Cone Sector
- **Origin**: (0, 0, 0) in local space
- **Tip**: (length, 0, 0) along direction
- **Left edge**: Rotate direction by -angle_deg around Y axis
  - `left = direction.rotated(Vector3.UP, -deg_to_rad(angle_deg))`
- **Right edge**: Rotate direction by +angle_deg around Y axis
  - `right = direction.rotated(Vector3.UP, deg_to_rad(angle_deg))`
- **Arc vertices**: Interpolate between left and right edges
- **Rotation**: Calculate angle from (1, 0, 0) to direction, rotate all vertices

#### Laser Rectangle
- **Center**: (0, 0, 0) in local space
- **Forward**: (length/2, 0, 0) along direction
- **Backward**: (-length/2, 0, 0) opposite direction
- **Perpendicular**: Perpendicular to direction in XZ plane
  - `perp = Vector3(-direction.z, 0, direction.x)` (90° rotation in XZ)
- **Width**: `thickness/2` along perpendicular
- **Vertices**: 4 corners of rectangle
- **Rotation**: Same as cone (rotate to match direction)

### Performance Considerations

- **Mesh Recreation**: Recreating mesh every frame is acceptable for simple shapes (cone/laser have few vertices)
- **Alternative**: Could cache meshes and only update rotation, but recreation is simpler
- **Throttling**: No throttling needed (bubble doesn't throttle, cone/laser shouldn't either)
- **Vertex Count**: Keep low (cone: ~16-32 vertices, laser: 4 vertices)

## Edge Cases

### Mouse Position Invalid
- If `_get_mouse_world_position()` returns `Vector3.ZERO`:
  - Use default direction (forward: Vector3(1, 0, 0))
  - Or hide visual until valid mouse position

### Direction Too Small
- If direction length < 0.1 (same check as `SimpleBeam`):
  - Use default direction (forward: Vector3(1, 0, 0))

### Mode Switching
- When switching modes, immediately update visual
- Don't wait for next `_process()` call
- Handle in `_on_beam_mode_changed()`

## Future Enhancements (Out of Scope)

- Animated visuals (pulsing, glowing)
- Particle effects
- Sound effects
- Visual feedback for energy drain
- Different colors for different modes
- Gradient opacity (fade at edges)

## References

- `scripts/renderers/beam_renderer.gd` - Current implementation
- `scripts/beam/simple_beam.gd` - Mouse position logic
- `scripts/managers/beam_manager.gd` - Parameter definitions
- `DOCS/beam_visual_architecture.md` - Architecture principles

## Notes

- Both visuals should use the same material as bubble (gold, translucent)
- Visuals should be positioned at Y=2.0 (same as bubble) for visibility
- Visuals should update every frame for smooth mouse following
- Visuals should match clearing hitbox exactly (same parameters from BeamManager)

