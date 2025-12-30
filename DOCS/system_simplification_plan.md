# System Simplification Plan

## Current State (Simplified)

### ✅ What We Have
1. **Miasma System** - Binary tile-based fog (2x2 units)
2. **Beam System** - Bubble mode only (auto-clears around player)
3. **Ground Layer** - Basic green tiles (64x64 units)
4. **Player (Derelict)** - Basic movement (WASD, isometric)
5. **Camera** - Fixed isometric (30°/45°, no rotation)

### 🎯 Core Systems (Keep Simple)
- **Miasma**: Binary tiles, permanent clearing, follows player
- **Beam**: Single mode (bubble), auto-active, energy system
- **Player**: Movement only, no systems yet

## Full Vision Mapping

### I. Core Vision ✅ (Already Aligned)
- ✅ 2.5D Isometric - We have this
- ✅ Moebius aesthetic - Visual style (can refine later)
- ✅ Binary Miasma - We have this
- ✅ Miniature feel - Isometric camera achieves this

### II. Meta-Narrative (Future)
- **Not needed now** - Can add later
- **Simplification**: Focus on gameplay first, lore later

### III. The Derelict (Simplify → Expand)

**Current (Simple):**
- Just a moving capsule
- No systems
- No crew
- No health

**Future Expansion Path:**
```
Simple → Add Health → Add Systems → Add Crew → Add North (battery)
```

**Simplification Strategy:**
- Keep Derelict as simple CharacterBody3D
- Add health system first (single number)
- Systems can be added incrementally
- Crew can be added last

### IV. System Architecture (Simplify → Expand)

**Current (Simple):**
- Beam: Bubble mode only, auto-active
- No systems
- No HUD
- No tools

**Future Expansion Path:**
```
Bubble → Add Cone/Laser → Add Mode Switching → Add Systems → Add HUD → Add Tools
```

**Simplification Strategy:**
1. **Beam Modes (Phase 1):**
   - Keep bubble working
   - Add cone/laser visuals
   - Add mouse direction
   - Add mode switching (keys 1-4)

2. **Systems (Phase 2):**
   - Start with 1-2 systems (Legs, Lighthouse)
   - Add more incrementally
   - Use simple state (on/off, health %)

3. **HUD (Phase 3):**
   - Start simple (energy bar, health bar)
   - Add diagnostic style later

### V. Gameplay Mechanics (Simplify → Expand)

**Current (Simple):**
- Miasma clears around player
- No regrowth
- No enemies
- No stealth

**Future Expansion Path:**
```
Basic Clearing → Add Regrowth → Add Comet Tail → Add Enemies → Add Stealth
```

**Simplification Strategy:**
- **Miasma Regrowth:** Can add later (simple timer per tile)
- **Comet Tail:** Just visual effect (track cleared path)
- **Enemies:** Add after core systems work
- **Stealth:** Add after enemies exist

## Recommended Simplification

### Phase 1: Core Beam System (Current Focus)
**Keep Simple:**
- ✅ Bubble mode working
- ✅ Auto-clears around player
- ✅ Energy system
- ✅ Visual matches hitbox

**Add Next (Still Simple):**
- Mouse direction tracking
- Cone/Laser modes (visuals + clearing)
- Mode switching (number keys)

**Skip For Now:**
- Analog mouse wheel switching
- Complex HUD
- System management

### Phase 2: Basic Systems (After Beam Works)
**Add:**
- Health system (single number)
- 2-3 basic systems (Legs, Lighthouse, maybe Radar)
- Simple HUD (health bar, energy bar)

**Skip For Now:**
- All 16 systems
- Crew management
- North (battery) system
- Complex diagnostics

### Phase 3: Gameplay Loop (After Systems Work)
**Add:**
- Miasma regrowth
- Basic enemies
- Comet tail visual

**Skip For Now:**
- Stealth mechanics
- Signature management
- Complex progression

## Architecture Principles

### 1. Keep Managers Simple
- **Current:** MiasmaManager, BeamManager (working)
- **Add:** DerelictManager (health only), SystemManager (simple state)
- **Skip:** Complex crew management, resource systems

### 2. Use Signals (Already Doing This)
- ✅ Event-driven communication
- ✅ Decoupled systems
- ✅ Easy to expand

### 3. Incremental Complexity
```
Simple State → Add One Feature → Test → Add Next Feature
```

### 4. Data Structures
- **Current:** Dictionaries for blocks (simple)
- **Future:** Can add more complex data without breaking current code
- **Keep:** Simple state (bool, float, int) until needed

## What to Simplify Right Now

### Beam System (Current Task)
1. ✅ Fix visual (shape, color, position) - DONE
2. Add mouse direction (for cone/laser)
3. Add mode switching (keys 1-4)
4. Add cone/laser visuals
5. **Skip:** Analog switching, complex HUD

### Miasma System
- ✅ Already simple (binary tiles)
- **Future:** Add regrowth timer (simple addition)

### Derelict
- ✅ Keep as simple CharacterBody3D
- **Future:** Add health (single float)
- **Future:** Add systems (Dictionary of on/off states)

## Expansion Checklist

When ready to expand, follow this order:

1. ✅ Miasma system (done)
2. ✅ Beam system - bubble mode (done)
3. ⏳ Beam system - all modes (next)
4. ⏳ Health system
5. ⏳ Basic systems (2-3)
6. ⏳ Simple HUD
7. ⏳ Miasma regrowth
8. ⏳ Enemies
9. ⏳ More systems
10. ⏳ Crew system
11. ⏳ Full HUD
12. ⏳ Progression system

## Key Insight

**The current architecture (managers + signals) already supports expansion.**
- We can add features without breaking existing code
- Systems are decoupled (can add new ones easily)
- Data structures are simple (can make complex later)

**The simplification is in scope, not architecture.**
- Build one feature at a time
- Test each feature
- Don't add complexity until needed
