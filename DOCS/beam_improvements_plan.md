# Beam System Improvements Plan

## Current State ✅

1. **BeamManager** - Complete
   - All modes defined (BUBBLE_MIN, BUBBLE_MAX, CONE, LASER, OFF)
   - Energy system working (regen/drain)
   - Clearing API functional

2. **BeamRenderer** - Partial
   - ✅ Bubble mode visual (ellipse)
   - ❌ Cone mode visual (TODO)
   - ❌ Laser mode visual (TODO)

3. **SimpleBeam** - Basic
   - ✅ Auto-clears around player (bubble mode)
   - ❌ No input handling
   - ❌ No mode switching
   - ❌ No mouse direction

## Proposed Improvements

### Phase 1: Input & Mode Switching (Priority)
1. **Add input handling:**
   - Number keys (1-4) to switch modes
   - Or mouse wheel to cycle modes
   - Display current mode in UI

2. **Mouse direction for cone/laser:**
   - Get mouse world position
   - Calculate direction from player to mouse
   - Use for cone/laser aiming

3. **Click-to-fire:**
   - Left click = fire beam at mouse position
   - Or hold for continuous fire

### Phase 2: Visual Improvements
1. **Cone visual:**
   - Create cone mesh pointing in mouse direction
   - Show cone angle and length
   - Update in real-time as mouse moves

2. **Laser visual:**
   - Create line/beam visual
   - Show laser path from player to mouse
   - Thickness based on LASER_THICKNESS

3. **Better bubble visual:**
   - Maybe add glow/pulse effect
   - Better isometric projection

### Phase 3: Integration
1. **Move clearing logic:**
   - Move from SimpleBeam to DerelictManager or BeamManager
   - Better separation of concerns

2. **Energy UI:**
   - Display energy bar
   - Show current mode
   - Visual feedback when low energy

## Questions to Answer

1. **How should mode switching work?**
   - Number keys (1=bubble, 2=cone, 3=laser)?
   - Mouse wheel scroll?
   - Tab key to cycle?

2. **How should firing work?**
   - Click to fire once?
   - Hold to fire continuously?
   - Auto-fire in bubble mode (current)?

3. **Mouse direction:**
   - Should cone/laser always point at mouse?
   - Or use player facing direction?
   - Or WASD direction?

## Recommendation: Start with Phase 1

**Next Steps:**
1. Add number key input (1-4) for mode switching
2. Add mouse position tracking for cone/laser direction
3. Add click-to-fire for manual control
4. Test each mode works correctly

This gives you full control over the beam system before adding visuals.
