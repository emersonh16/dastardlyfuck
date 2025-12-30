# Current System Status

**Last Updated:** After wind system, regrowth, and beam mode cycling implementation  
**Godot Version:** 4.5  
**Target FPS:** 60 FPS (achieved)

## ✅ Fully Implemented Systems

### 1. Miasma System
- **2D sheet** at Y=0.01 (flat on ground)
- **Inverse model** - Miasma assumed everywhere, only cleared tiles tracked
- **Regrowth system** - Creeps back from borders, 1.5s delay, 15% chance
- **Frontier tracking** - Efficient boundary tracking for regrowth
- **Wind advection** - Coordinate system shifts with wind velocity
- **Performance:** 60 FPS with optimized rendering

### 2. Beam System
- **Modes:** OFF, BUBBLE_MIN, BUBBLE_MAX, CONE_MIN, CONE_MAX, LASER
- **2D visuals** - All beam visuals are flat 2D sheets at Y=0.01
- **Continuous clearing** - Clears every frame, no energy limit
- **Input:** Mouse wheel (scroll sensitivity: 3 threshold), number keys 1-6
- **Scroll behavior:** Scroll DOWN → LASER (locks), Scroll UP → OFF (locks)

### 3. Wind System
- **Global wind** - Direction (degrees) and speed (tiles/sec)
- **Advection** - Miasma coordinate system shifts with wind
- **Toggle** - Can be enabled/disabled
- **API** - `set_direction()`, `set_speed()`, `set_enabled()`, `get_state()`

### 4. Ground Renderer
- **Tile-based** - 64x64 world units per tile
- **Visual style** - Green centers with brown borders
- **Smooth movement** - Follows player smoothly, tiles snap to grid
- **Updates every frame** - Smooth visual experience

### 5. Camera System
- **Free rotation** - Right-click drag or middle mouse drag
- **Isometric** - 30° elevation, 45° azimuth (adjustable)
- **Follows player** - Always centered on player position

### 6. Player Movement
- **WASD** - Cardinal screen-space directions (locked to camera)
- **Smooth movement** - 50 units/second
- **World coordinates** - Moves in world space, camera follows

## 📊 Performance Metrics

- **FPS:** 60 FPS (target achieved)
- **Miasma rendering:** Optimized with early exits and thresholds
- **Regrowth:** Dynamic budget, scan limits, efficient frontier tracking
- **Wind advection:** Negligible performance impact
- **Beam clearing:** Fast, no performance impact

## 🔧 Key Technical Details

### Miasma System
- **Tile size:** 2x2 world units
- **Regrowth delay:** 1.5 seconds
- **Regrowth chance:** 15%
- **Regrowth budget:** Dynamic (128 base + viewport scaling)
- **Max scan per frame:** 4000 tiles

### Beam System
- **BUBBLE_MIN radius:** 16.0 world units
- **BUBBLE_MAX radius:** 32.0 world units
- **CONE_MIN:** Length 48.0, angle 24°
- **CONE_MAX:** Length 80.0, angle 40°
- **LASER:** Length 128.0, thickness 4.0

### Wind System
- **Max speed:** 256.0 tiles/sec
- **Default direction:** 270° (west)
- **Default speed:** 8.0 tiles/sec
- **Enabled by default:** Yes

### Ground System
- **Tile size:** 64x64 world units
- **Border width:** 2.0 world units
- **Y position:** -1.0

## 🚧 Not Yet Implemented

1. **WorldManager** - Biome system, chunk loading
2. **DerelictManager** - Position ownership, health, systems
3. **Dev HUD** - Wind state, beam mode display
4. **World generation** - Seeded world, biomes

## 📝 Recent Changes

1. **Beam mode cycling** - Added CONE_MIN and CONE_MAX, scroll sensitivity, locking at ends
2. **Energy system removed** - Beam fires continuously
3. **Wind system** - Global wind with advection
4. **Miasma regrowth** - Creeping pattern from borders
5. **2D simplification** - Miasma and beam are 2D sheets
6. **Camera rotation** - Free rotation enabled
7. **Performance optimizations** - Achieved 60 FPS

## 🎮 Controls

- **WASD** - Move derelict (screen-space, locked to camera)
- **Mouse Wheel** - Cycle beam modes (3 scroll events per change)
  - Scroll DOWN → LASER (locks)
  - Scroll UP → OFF (locks)
- **Number Keys 1-6** - Direct mode selection
- **Right-Click Drag / Middle Mouse Drag** - Rotate camera

## 📚 Documentation

- **ONBOARDING.md** - Getting started guide
- **system_architecture.md** - Full architecture documentation
- **beam_visual_architecture.md** - Beam visual design
- **performance_optimizations.md** - Performance details
- **miasma_system_outline.md** - Miasma system design
