# Camera Rotation Issue - To Fix Later

## Problem
Camera rotates slightly when player moves, then stops. This is caused by `look_at()` recalculating rotation every frame.

## Root Cause
- `look_at()` in `_process()` recalculates rotation based on target position
- Even with fixed up vector, slight numerical drift occurs
- Camera should have zero rotation - only position should change

## Solution (Not Implemented Yet)
- Calculate rotation once in `_ready()` based on elevation/azimuth
- Store as fixed Basis
- Never call `look_at()` - only update position
- Set `transform.basis = _fixed_basis` every frame

## Status
- Issue identified
- Solution known
- Implementation deferred (focusing on architecture first)
