# Debugging Plan - Miasma Jittering

## Problem
- Miasma blocks jitter when player moves
- Player stays locked at center (good)
- Only happens when moving
- Miasma renders more when moving (expected, but might be too frequent)

## Debug Tools Added

### 1. Player Trail (Red Line)
- Shows player's path through world
- Red line follows player movement
- Helps visualize:
  - Is player actually moving smoothly?
  - What path is player taking?
  - Are there micro-movements causing jitter?

### 2. What to Look For

**When moving:**
- Does the red trail show smooth movement?
- Or does it show jittery/stuttering movement?
- Does trail update smoothly or in jumps?

**Miasma behavior:**
- Watch when miasma blocks regenerate
- Do they regenerate smoothly or in jumps?
- Do blocks appear to "snap" to new positions?

## Next Debug Steps (If Needed)

1. **Add position debug text:**
   - Show player world position on screen
   - Show current tile coordinates
   - Show when miasma regenerates

2. **Add frame timing:**
   - Show delta time
   - Show if frames are consistent

3. **Add miasma update counter:**
   - Count how many times miasma regenerates per second
   - Should be low (only on tile boundary crossings)

## Expected Behavior

**Smooth movement:**
- Red trail should be smooth, continuous line
- No gaps or jumps in trail
- Trail follows player smoothly

**Miasma updates:**
- Should only regenerate when crossing tile boundaries
- Blocks should appear/disappear smoothly
- No visible "snapping" or jittering
