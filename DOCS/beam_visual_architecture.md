# Beam Visual Architecture Design

## The Problem

We've been doing patch fixes (trying different rotation values) instead of designing a proper system. This is unsustainable.

## Root Cause Analysis

**Why we're struggling:**
1. **Hitbox and visual are separate** - They're calculated independently, so they can drift apart
2. **Isometric projection math is complex** - We're guessing at rotation values instead of calculating them
3. **No single source of truth** - BeamManager defines radius, but visual rotation is in BeamRenderer
4. **Trial and error approach** - We're trying different values instead of deriving them mathematically

## The Right Architecture

### Principle: Hitbox and Visual Must Share the Same Math

**Single Source of Truth:**
- BeamManager defines the clearing shape (circle, cone, laser)
- BeamRenderer visualizes that exact shape
- Both use the same mathematical representation

### Design Pattern: Shape Definition → Projection → Rendering

**Step 1: Define Shape in World Space**
- Circle: center point + radius
- Cone: origin + direction + angle + length
- Laser: origin + direction + length + thickness

**Step 2: Project to Isometric View**
- Calculate how the shape appears in isometric projection
- Use camera angles (30° elevation, 45° azimuth) to transform
- This gives us the correct visual representation

**Step 3: Render the Projected Shape**
- Visual matches the projected shape exactly
- No guessing, no patch fixes

## Proposed Architecture

### BeamManager (Data Layer)
**Responsibilities:**
- Define beam shape parameters (radius, angle, length, etc.)
- Calculate clearing hitbox (world space)
- Provide shape definition to renderer

**API:**
```gdscript
get_clearing_shape() -> Dictionary
  Returns: {
    "type": "circle" | "cone" | "laser",
    "center": Vector3,
    "radius": float,  # for circle
    "direction": Vector3,  # for cone/laser
    "angle": float,  # for cone
    "length": float  # for cone/laser
  }
```

### BeamRenderer (Visual Layer)
**Responsibilities:**
- Get shape definition from BeamManager
- Project shape to isometric view (using camera angles)
- Render the projected shape

**Projection Math:**
```gdscript
project_circle_to_isometric(center: Vector3, radius: float) -> VisualRepresentation
  # Calculate how circle appears in isometric view
  # Use camera angles: 30° elevation, 45° azimuth
  # Return: mesh transform that shows circle correctly
```

### Shared Math Module (Future)
**Purpose:**
- Centralized isometric projection calculations
- Both hitbox and visual use same functions
- No duplication, no drift

## The Real Solution

### Option A: Accept Natural Projection (Simplest)
- Circle in world space → appears as ellipse in isometric view
- This is correct! The ellipse IS the circle
- Don't try to make it look circular - it's an ellipse
- **Hitbox:** Circle in world space
- **Visual:** Show the ellipse (natural projection)

### Option B: Pre-distort to Appear Circular (Complex)
- Calculate what shape in world space appears as circle in isometric
- Pre-distort the visual to compensate
- **Hitbox:** Circle in world space (unchanged)
- **Visual:** Pre-distorted shape that appears circular

### Option C: Use Shader (Most Flexible)
- Render circle with shader that handles projection
- Shader does the math, no rotation guessing
- **Hitbox:** Circle in world space
- **Visual:** Shader renders it correctly

## Recommendation

**Go with Option A (Accept Natural Projection):**
1. **Simplest** - No complex math needed
2. **Correct** - The ellipse IS the circle in isometric view
3. **Matches hitbox** - Both are circles in world space
4. **No rotation issues** - Just show the circle, let projection handle it

**Implementation:**
- Circle on XZ plane, rotated 90° around X (flat)
- No Y rotation needed
- Let isometric camera show it as ellipse naturally
- This matches the clearing hitbox (also a circle)

## Process Question: Is This Normal?

**Short answer:** Some iteration is normal, but we should design first.

**Better process:**
1. **Design** - Define the math, the architecture, the approach
2. **Implement** - Code to the design
3. **Test** - Verify it works
4. **Iterate** - Only if design was wrong, not if implementation was wrong

**What we did wrong:**
- Started coding without designing the projection math
- Tried different values hoping one would work
- Didn't define what "correct" looks like

**What we should do:**
- Define: "A circle in world space appears as an ellipse in isometric view - this is correct"
- Design: "Visual shows the circle, projection makes it an ellipse"
- Implement: "Rotate to XZ plane, no other rotation needed"
- Test: "Does visual match hitbox? Yes = done"

## Implementation Status

**✅ IMPLEMENTED: Custom Flat Circle Mesh (Option 3)**

**What we did:**
1. **Custom mesh creation** - Created flat circle mesh directly on XZ plane using ArrayMesh
2. **No rotation needed** - Mesh is naturally flat, so `rotation_degrees = Vector3(0, 0, 0)`
3. **Single source of truth** - BeamManager.get_clearing_radius() defines both hitbox and visual
4. **Clean architecture** - No rotation guessing, just a flat circle that matches clearing

**Code changes:**
- `beam_renderer.gd`: Created `_create_circle_mesh()` function
  - Generates 64 vertices in a circle on XZ plane (Y=0)
  - Creates triangles from center to edge (fan pattern)
  - No rotation needed - already flat!
- Visual uses exact radius from `BeamManager.get_clearing_radius()`
- Both hitbox and visual are circles in world space, so they match exactly

**Result:**
- Visual matches hitbox (both are circles in world space)
- Visual appears correctly in isometric view (natural projection as ellipse)
- Clean, simple solution - no rotation complications

## Questions to Answer

1. **What should the visual look like?**
   - Ellipse (natural projection of circle) - matches hitbox
   - Circle (pre-distorted) - doesn't match hitbox but looks "right"
   - Something else?

2. **What matters more?**
   - Visual matching hitbox exactly (ellipse)
   - Visual looking "correct" to player (circle)

3. **Is the current approach sustainable?**
   - No - we're guessing at values
   - Yes - if we accept natural projection and stop trying to fix it
