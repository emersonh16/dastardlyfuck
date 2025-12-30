# Beam Clearing Implementation Plan

## Current State
- ✅ MiasmaManager has `clear_area()` function (lines 86-108)
- ✅ Takes world position, radius, returns cleared count
- ❌ No beam system yet
- ❌ No way to trigger clearing

## From JS Implementation

### clearArea() Logic (JS):
1. Takes: `(wx, wy, r, budget)`
2. Converts world pos to tile coordinates
3. Loops through tiles in radius
4. Checks if tile center is within circle (distance check)
5. Removes from `clearedMap` (marks as cleared)
6. Has budget system (limits tiles per call)
7. Returns count of cleared tiles

### Beam System (JS):
- **Laser mode:** Clears along beam path with multiple stamps
- **Cone mode:** Clears in cone shape (multiple circles along path)
- **Bubble modes:** Clears circular area around player
- Calls `clearArea()` multiple times per frame
- Uses budget system to limit performance impact

## Implementation Plan

### Phase 1: Basic Beam Clearing (Simple Test)
1. **Create simple beam system:**
   - Mouse click = fire beam
   - Beam clears circular area at mouse position
   - Visual feedback (beam line or effect)

2. **Test clearing:**
   - Click to clear miasma
   - See gaps appear
   - Verify blocks are actually removed

### Phase 2: Beam Modes (Like JS)
1. **Bubble mode:** Clear around player
2. **Cone mode:** Clear in cone direction
3. **Laser mode:** Clear along beam path

### Phase 3: Integration
1. Connect to player controls
2. Add visual beam rendering
3. Add energy/cooldown system

## Questions to Answer

1. **How to trigger beam?**
   - Mouse click?
   - Key press?
   - Always active?

2. **Beam direction?**
   - Mouse direction?
   - Player facing direction?
   - Fixed direction?

3. **Visual feedback?**
   - Beam line?
   - Particle effect?
   - Just clearing (no visual)?

4. **Budget system?**
   - Limit tiles cleared per frame?
   - Or clear all instantly?

## Next Steps

1. Start with simplest possible: Click to clear at mouse position
2. Verify clearing works visually
3. Then add beam modes and complexity
