# Beam System Improvements Plan

## Current State ✅

1. **BeamManager** - Complete ✅
   - All modes defined (BUBBLE_MIN, BUBBLE_MAX, CONE, LASER, OFF)
   - Energy system working (regen/drain)
   - Clearing API functional (bubble, cone, laser)

2. **BeamRenderer** - Partial
   - ✅ Bubble mode visual (circle on XZ plane, appears as ellipse)
   - ❌ Cone mode visual (TODO)
   - ❌ Laser mode visual (TODO)

3. **SimpleBeam** - Complete ✅
   - ✅ Continuous clearing every frame (all modes)
   - ✅ Clears immediately on mode switch
   - ✅ Bubble: clears around player
   - ✅ Cone/Laser: clears toward mouse position

4. **BeamInput** - Complete ✅
   - ✅ Mouse wheel cycles modes
   - ✅ Number keys 1-5 for direct mode selection

## Remaining Improvements

### Phase 1: Visuals (Priority)
1. **Cone visual:**
   - Create cone mesh pointing in mouse direction
   - Show cone angle and length
   - Update in real-time as mouse moves

2. **Laser visual:**
   - Create line/beam visual
   - Show laser path from player to mouse
   - Thickness based on LASER_THICKNESS

### Phase 2: UI & Integration
1. **Move clearing logic:**
   - Move from SimpleBeam to DerelictManager or BeamManager
   - Better separation of concerns

2. **Energy UI:**
   - Display energy bar
   - Show current mode
   - Visual feedback when low energy

## Next Steps

1. **Implement cone visual** in BeamRenderer
2. **Implement laser visual** in BeamRenderer
3. **Add energy UI** display
4. **Consider moving clearing logic** from SimpleBeam to DerelictManager (architectural improvement)
