# Beam Hitbox & Visual Design

## Problem
- Visual ellipse is partially occluded (bottom half goes below ground)
- Hitbox (clearing circle) and visual (ellipse) need to match perfectly
- Currently they're calculated separately

## Solution: Shared Parameter System

### Design Principles
1. **Single Source of Truth:** BeamManager defines all beam parameters
2. **Visual Matches Hitbox:** Visual ellipse must represent the actual clearing circle in isometric view
3. **Shared Calculations:** Both hitbox and visual use the same radius/shape calculations

### Current State

**Hitbox (Clearing):**
- Uses `BUBBLE_MIN_RADIUS = 48.0` (world units)
- Circle in world space (XZ plane)
- Clears all miasma tiles within radius

**Visual:**
- Uses same radius (48.0)
- Ellipse to represent circle in isometric projection
- Positioned at Y=1.0 (above ground at Y=-0.5)
- But bottom half still goes below ground

### Issues to Fix

1. **Y Position:** Ground is at Y=-0.5, beam at Y=1.0, but ellipse extends below
2. **Ellipse Calculation:** Need to ensure ellipse correctly represents the circle
3. **Hitbox/Visual Sync:** Both must use exact same radius from BeamManager

### Proposed Solution

1. **Fix Y Position:**
   - Ground is at Y=-0.5
   - Position beam visual at Y=0.5 (just above ground)
   - Or use render priority to ensure it's always visible

2. **Shared Radius Function:**
   - BeamManager.get_clearing_radius() returns exact radius
   - Both BeamRenderer and clearing logic use this
   - No hardcoded values

3. **Visual Ellipse Math:**
   - Circle radius in world space = R
   - In isometric view (30° elevation, 45° azimuth):
     - Ellipse major axis = R
     - Ellipse minor axis = R * cos(30°) ≈ R * 0.866
   - Visual must match this exactly

4. **Hitbox Verification:**
   - Clearing uses circle (radius R)
   - Visual shows ellipse (R × 0.866)
   - They match in isometric projection

## Implementation Plan

1. Fix beam visual Y position (above ground, not occluded)
2. Create shared radius getter in BeamManager
3. Ensure visual ellipse math matches isometric projection
4. Add debug visualization to verify hitbox matches visual
5. Test that clearing area matches visual exactly
