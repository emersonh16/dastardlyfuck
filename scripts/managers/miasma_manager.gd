extends Node

# MiasmaManager - Autoload singleton
# Manages miasma as a 2D sheet with holes (inverse model - track cleared tiles, not existing blocks)
# Inspired by old 2D top-down implementation

# Constants
const MIASMA_TILE_SIZE = 2.0  # World units per tile (2x2 for granular fog)
const PAD = 6  # Padding around viewport (in tiles)

# Cleared tiles: Dictionary of Vector2i -> float (timestamp when cleared)
# Using Vector2i for 2D tile coordinates (x, y)
# Everything is fog by default - we only track what's been CLEARED
var cleared_tiles: Dictionary = {}  # Vector2i -> timestamp

# Frontier: Set of cleared tiles that are on the boundary (adjacent to fog)
# These are candidates for regrowth
var frontier: Dictionary = {}  # Vector2i -> true

# Viewport tracking
var viewport_tiles_x: int = 0
var viewport_tiles_z: int = 0
var player_position: Vector3 = Vector3.ZERO

# Wind advection offset (in tiles, can be fractional)
# This represents how much the miasma coordinate system has drifted due to wind
var wind_offset_x: float = 0.0
var wind_offset_z: float = 0.0

# Time tracking for regrowth
var game_time: float = 0.0

# Wind manager reference
var wind_manager: Node = null

# Mountain manager reference (for blocking checks)
var mountain_manager: Node = null

# Regrowth settings (match reference implementation)
# Key: Only boundary tiles regrow, creating gradual creep-in from edges
const REGROW_DELAY: float = 1.5  # Seconds before cleared tiles can regrow (timer delay)
const REGROW_CHANCE: float = 0.15  # Base probability of regrowth per check (15% chance - slower creep)
const REGROW_SPEED_FACTOR: float = 1.0  # Multiplier for regrowth chance (like reference)
const REGROW_BUDGET_BASE: int = 128  # Base budget (reduced for slower, more gradual regrowth)
const REGROW_SCAN_PAD: int = PAD * 4  # Padding for regrowth scan area

# Dynamic regrowth budget (updated based on viewport size, like reference)
# Reduced to keep regrowth slower and GPU efficient
var regrow_budget: int = REGROW_BUDGET_BASE

# Offscreen behavior (in tiles)
const OFFSCREEN_REG_PAD: int = PAD * 6  # Regrow this far past viewport
const OFFSCREEN_FORGET_PAD: int = PAD * 12  # Beyond this, auto-reset cleared tiles

# Performance limits
const MAX_CLEARED_CAP: int = 50000  # Max cleared tiles to track
const MAX_REGROW_SCAN_PER_FRAME: int = 4000  # Max frontier tiles to scan per frame (match reference)
const CLEARED_TTL_S: float = 0.0  # Time-to-live for cleared tiles (0 = disabled)

# Signal for renderer updates
signal cleared_changed()  # Emitted when cleared tiles change

func _ready():
	print("MiasmaManager initialized (inverse model - track cleared tiles)")
	wind_manager = get_node_or_null("/root/WindManager")
	if wind_manager:
		wind_manager.wind_changed.connect(_on_wind_changed)
	mountain_manager = get_node_or_null("/root/MountainManager")
	call_deferred("_initialize_default")

func _process(delta):
	game_time += delta
	
	# Apply wind advection (move miasma coordinate system)
	if wind_manager and wind_manager.enabled:
		var wind_vel = wind_manager.get_velocity()
		# Convert velocity (tiles/sec) to offset delta
		wind_offset_x += wind_vel.x * delta
		wind_offset_z += wind_vel.y * delta  # Note: wind_vel.y is Z in world space
	
	_process_regrowth()

func _initialize_default():
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_3d()
		var world_width = 200.0
		var world_height = 200.0
		if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			world_width = camera.size
			var pixel_size = viewport.get_visible_rect().size
			world_height = camera.size * (pixel_size.y / pixel_size.x)
		initialize_miasma(Vector3.ZERO, world_width, world_height)
	else:
		# Fallback: use default budget
		regrow_budget = REGROW_BUDGET_BASE

# Initialize miasma system
func initialize_miasma(player_pos: Vector3, viewport_width: float, viewport_height: float):
	player_position = player_pos
	
	# Account for isometric 45° rotation
	var max_dimension = max(viewport_width, viewport_height)
	var coverage_size = max_dimension * 1.414  # sqrt(2)
	
	viewport_tiles_x = int(coverage_size / MIASMA_TILE_SIZE) + PAD * 2
	viewport_tiles_z = int(coverage_size / MIASMA_TILE_SIZE) + PAD * 2
	
	# Update regrowth budget based on viewport size (like reference updateBudgets)
	_update_regrow_budget(viewport_width, viewport_height)
	
	print("Miasma initialized: ", viewport_tiles_x, "x", viewport_tiles_z, " tiles (inverse model)")

# Update regrowth budget based on viewport size (match reference updateBudgets)
func _update_regrow_budget(viewport_width: float, viewport_height: float):
	var view_cols = int(viewport_width / MIASMA_TILE_SIZE)
	var view_rows = int(viewport_height / MIASMA_TILE_SIZE)
	var screen_tiles = view_cols * view_rows
	
	# Base budget = max(screenTiles, baseBudget) - like reference
	# Scale it down to keep regrowth slower and GPU efficient
	# Use ~1/8 of screen tiles for very gradual, efficient regrowth
	regrow_budget = max(screen_tiles / 8, REGROW_BUDGET_BASE / 2)

# Update player position
func update_player_position(new_pos: Vector3):
	player_position = new_pos
	# No need to "fill" fog - it's everywhere by default

# Clear miasma in area (for beam clearing)
# Returns number of tiles cleared
# Matches reference: uses tile centers for distance calculation
func clear_area(world_pos: Vector3, radius: float) -> int:
	# Snap world position (like reference snapWorld)
	var snapped_x = world_pos.x
	var snapped_z = world_pos.z
	
	# Convert to tile coordinates (world space)
	var center_tile_x = int(snapped_x / MIASMA_TILE_SIZE)
	var center_tile_z = int(snapped_z / MIASMA_TILE_SIZE)
	
	# Convert to wind-relative coordinates (like reference: tx - S.fxTiles)
	var fx_offset = int(wind_offset_x)
	var fz_offset = int(wind_offset_z)
	var radius_tiles = int(radius / MIASMA_TILE_SIZE) + 1
	var radius_sq = radius * radius
	
	var cleared = 0
	var tiles_to_clear = []
	
	# Find all tiles in radius - use tile CENTERS for distance check (like reference)
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dz in range(-radius_tiles, radius_tiles + 1):
			var tx = center_tile_x + dx
			var tz = center_tile_z + dz
			
			# Calculate tile CENTER position (like reference: (tx + 0.5) * TILE_SIZE)
			var tile_center_x = (tx + 0.5) * MIASMA_TILE_SIZE
			var tile_center_z = (tz + 0.5) * MIASMA_TILE_SIZE
			
			# Distance from world_pos to tile center
			var dxw = tile_center_x - snapped_x
			var dzw = tile_center_z - snapped_z
			var dist_sq = dxw * dxw + dzw * dzw
			
			if dist_sq <= radius_sq:
				# Check if blocked by mountains (tall cells block miasma)
				var tile_world_pos = Vector3(tile_center_x, 0, tile_center_z)
				var is_blocked = false
				if mountain_manager and mountain_manager.has_method("is_miasma_blocked_at"):
					is_blocked = mountain_manager.is_miasma_blocked_at(tile_world_pos)
				
				# Only clear if not blocked and not already cleared
				if not is_blocked:
					# Convert to wind-relative coordinates for storage
					var fx = tx - fx_offset
					var fz = tz - fz_offset
					var tile_pos = Vector2i(fx, fz)
					if not cleared_tiles.has(tile_pos):
						tiles_to_clear.append(tile_pos)
						cleared += 1
	
	# Mark tiles as cleared with timestamp
	if tiles_to_clear.size() > 0:
		for tile_pos in tiles_to_clear:
			cleared_tiles[tile_pos] = game_time
			_update_frontier(tile_pos)
		
		cleared_changed.emit()
	
	return cleared

# Check if a tile is cleared (for rendering/sampling)
# Takes world tile coordinates, converts to wind-relative for lookup
func is_cleared(tile_x: int, tile_z: int) -> bool:
	# Convert world tile coords to wind-relative coords
	var fx_offset = int(wind_offset_x)
	var fz_offset = int(wind_offset_z)
	var fx = tile_x - fx_offset
	var fz = tile_z - fz_offset
	var tile_pos = Vector2i(fx, fz)
	return cleared_tiles.has(tile_pos)

# Get all cleared tiles in viewport area (for rendering)
# Takes world tile coordinates, converts to wind-relative for lookup
func get_cleared_tiles_in_area(center_tile_x: int, center_tile_z: int, half_x: int, half_z: int) -> Dictionary:
	var result = {}
	
	# Convert world tile coords to wind-relative coords
	var fx_offset = int(wind_offset_x)
	var fz_offset = int(wind_offset_z)
	
	for x in range(center_tile_x - half_x, center_tile_x + half_x):
		for z in range(center_tile_z - half_z, center_tile_z + half_z):
			# Convert to wind-relative
			var fx = x - fx_offset
			var fz = z - fz_offset
			var tile_pos = Vector2i(fx, fz)
			if cleared_tiles.has(tile_pos):
				# Store with world coordinates for renderer
				var world_pos = Vector2i(x, z)
				result[world_pos] = cleared_tiles[tile_pos]
	
	return result

# Update frontier when a tile is cleared
func _update_frontier(tile_pos: Vector2i):
	# Add cleared tile to frontier if it's on boundary
	if _is_boundary(tile_pos):
		frontier[tile_pos] = true
	else:
		frontier.erase(tile_pos)
	
	# Update neighbors
	_update_neighbor_frontier(Vector2i(tile_pos.x - 1, tile_pos.y))
	_update_neighbor_frontier(Vector2i(tile_pos.x + 1, tile_pos.y))
	_update_neighbor_frontier(Vector2i(tile_pos.x, tile_pos.y - 1))
	_update_neighbor_frontier(Vector2i(tile_pos.x, tile_pos.y + 1))

func _update_neighbor_frontier(tile_pos: Vector2i):
	if cleared_tiles.has(tile_pos):
		if _is_boundary(tile_pos):
			frontier[tile_pos] = true
		else:
			frontier.erase(tile_pos)

# Check if a cleared tile is on the boundary (adjacent to fog)
func _is_boundary(tile_pos: Vector2i) -> bool:
	# A cleared tile is on boundary if any neighbor is NOT cleared (i.e., has fog)
	return not cleared_tiles.has(Vector2i(tile_pos.x - 1, tile_pos.y)) or \
		   not cleared_tiles.has(Vector2i(tile_pos.x + 1, tile_pos.y)) or \
		   not cleared_tiles.has(Vector2i(tile_pos.x, tile_pos.y - 1)) or \
		   not cleared_tiles.has(Vector2i(tile_pos.x, tile_pos.y + 1))

# Get tile size (for renderer)
func get_tile_size() -> float:
	return MIASMA_TILE_SIZE

# Get viewport size in tiles
func get_viewport_tiles() -> Vector2i:
	return Vector2i(viewport_tiles_x, viewport_tiles_z)

# Handle wind changes (signal callback)
func _on_wind_changed(_velocity: Vector2):
	# Wind changed - advection is applied in _process(), so no action needed here
	pass

# Process regrowth - called every frame
func _process_regrowth():
	if frontier.is_empty():
		return
	
	# Update budget if viewport size changed (like reference calls updateBudgets in update)
	var viewport = get_viewport()
	if viewport:
		var camera = viewport.get_camera_3d()
		if camera:
			var pixel_size = viewport.get_visible_rect().size
			var world_width = camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 200.0
			var world_height = camera.size * (pixel_size.y / pixel_size.x) if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 200.0
			_update_regrow_budget(world_width, world_height)
	
	# Calculate viewport bounds in tile space (world coordinates)
	var player_tile_x = int(player_position.x / MIASMA_TILE_SIZE)
	var player_tile_z = int(player_position.z / MIASMA_TILE_SIZE)
	
	# Viewport bounds (centered on player)
	var view_cols = viewport_tiles_x
	var view_rows = viewport_tiles_z
	var base_tx = player_tile_x - view_cols / 2
	var base_tz = player_tile_z - view_rows / 2
	
	# Convert to wind-relative coordinates for frontier checks
	var fx_offset = int(wind_offset_x)
	var fz_offset = int(wind_offset_z)
	
	# Keep area (viewport + small padding)
	var keep_left = base_tx - PAD
	var keep_top = base_tz - PAD
	var keep_right = keep_left + view_cols + PAD * 2
	var keep_bottom = keep_top + view_rows + PAD * 2
	
	# Regrow area (extended beyond keep area)
	var reg_left = keep_left - OFFSCREEN_REG_PAD
	var reg_top = keep_top - OFFSCREEN_REG_PAD
	var reg_right = keep_right + OFFSCREEN_REG_PAD
	var reg_bottom = keep_bottom + OFFSCREEN_REG_PAD
	
	# Forget area (far from viewport)
	var forget_left = keep_left - max(OFFSCREEN_FORGET_PAD, OFFSCREEN_REG_PAD + PAD)
	var forget_top = keep_top - max(OFFSCREEN_FORGET_PAD, OFFSCREEN_REG_PAD + PAD)
	var forget_right = keep_right + max(OFFSCREEN_FORGET_PAD, OFFSCREEN_REG_PAD + PAD)
	var forget_bottom = keep_bottom + max(OFFSCREEN_FORGET_PAD, OFFSCREEN_REG_PAD + PAD)
	
	# Process regrowth (match reference implementation)
	var budget = regrow_budget  # Use dynamic budget
	var to_grow = []
	var to_forget = []
	var scanned = 0
	
	# Calculate regrowth chance with speed factor (like reference: chance * speedFactor)
	var chance = REGROW_CHANCE * REGROW_SPEED_FACTOR
	
	# Scan frontier for regrowth candidates
	# Match reference: process frontier in order (no shuffling - reference doesn't shuffle)
	# Frontier stores wind-relative coordinates
	var frontier_keys = frontier.keys()
	
	for tile_pos in frontier_keys:
		if budget <= 0 or scanned >= MAX_REGROW_SCAN_PER_FRAME:
			break
		scanned += 1
		
		# Get time_cleared (cache the lookup)
		# tile_pos is in wind-relative coordinates
		var time_cleared = cleared_tiles.get(tile_pos)
		if time_cleared == null:
			# Tile no longer cleared - remove from frontier
			frontier.erase(tile_pos)
			continue
		
		# Convert wind-relative coords to world coords for bounds checking
		var fx = tile_pos.x
		var fz = tile_pos.y
		var tx = fx + fx_offset
		var tz = fz + fz_offset
		
		# Forget tiles far from viewport (check first, like reference)
		if tx < forget_left or tx >= forget_right or tz < forget_top or tz >= forget_bottom:
			to_forget.append(tile_pos)
			continue
		
		# Only regrow within regrow area
		if tx < reg_left or tx >= reg_right or tz < reg_top or tz >= reg_bottom:
			continue
		
		# Check if still on boundary (match reference: check boundary before timing)
		# Reference checks isBoundary(fx, fy) using frontier coords, but we use world coords
		if not _is_boundary(tile_pos):
			frontier.erase(tile_pos)
			continue
		
		# Check if enough time has passed (match reference: delay check)
		if game_time - time_cleared < REGROW_DELAY:
			continue
		
		# Random chance to regrow (match reference: uses chance with speedFactor)
		if randf() < chance:
			to_grow.append(tile_pos)
			budget -= 1
	
	# Regrow tiles (remove from cleared_tiles)
	for tile_pos in to_grow:
		_remove_cleared_tile(tile_pos)
	
	# Forget offscreen tiles
	for tile_pos in to_forget:
		_remove_cleared_tile(tile_pos)
	
	# Cleanup: TTL-based removal (if enabled)
	if CLEARED_TTL_S > 0.0:
		var to_remove = []
		var cleared_keys = cleared_tiles.keys()
		for tile_pos in cleared_keys:
			var time_cleared = cleared_tiles[tile_pos]
			if game_time - time_cleared > CLEARED_TTL_S:
				to_remove.append(tile_pos)
		for tile_pos in to_remove:
			_remove_cleared_tile(tile_pos)
	
	# Cleanup: Cap total cleared tiles (remove oldest if over limit)
	if cleared_tiles.size() > MAX_CLEARED_CAP:
		var overflow = cleared_tiles.size() - MAX_CLEARED_CAP
		var candidates = []
		
		# Collect candidates (sample to avoid full scan)
		var scanned_count = 0
		var cleared_keys = cleared_tiles.keys()
		for tile_pos in cleared_keys:
			candidates.append({"pos": tile_pos, "time": cleared_tiles[tile_pos]})
			scanned_count += 1
			if scanned_count >= min(cleared_tiles.size(), overflow * 2):
				break
		
		# Sort by time (oldest first)
		candidates.sort_custom(func(a, b): return a.time < b.time)
		
		# Remove oldest
		var removed = 0
		for i in range(min(overflow, candidates.size())):
			_remove_cleared_tile(candidates[i].pos)
			removed += 1
			if removed >= overflow:
				break
	
	# Emit signal if changes occurred
	if to_grow.size() > 0 or to_forget.size() > 0:
		cleared_changed.emit()

# Remove a cleared tile (regrow it)
func _remove_cleared_tile(tile_pos: Vector2i):
	if not cleared_tiles.has(tile_pos):
		return
	
	# Remove from cleared tiles
	cleared_tiles.erase(tile_pos)
	
	# Remove from frontier
	frontier.erase(tile_pos)
	
	# Update neighbors (they might now be on boundary)
	_update_neighbor_frontier(Vector2i(tile_pos.x - 1, tile_pos.y))
	_update_neighbor_frontier(Vector2i(tile_pos.x + 1, tile_pos.y))
	_update_neighbor_frontier(Vector2i(tile_pos.x, tile_pos.y - 1))
	_update_neighbor_frontier(Vector2i(tile_pos.x, tile_pos.y + 1))
