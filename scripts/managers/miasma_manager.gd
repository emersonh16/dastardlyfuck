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

# Time tracking for regrowth
var game_time: float = 0.0

# Regrowth settings
const REGROW_DELAY: float = 1.0  # Seconds before cleared tiles can regrow
const REGROW_CHANCE: float = 0.6  # Probability of regrowth per check
const REGROW_BUDGET: int = 512  # Max tiles to check for regrowth per frame

# Signal for renderer updates
signal cleared_changed()  # Emitted when cleared tiles change

func _ready():
	print("MiasmaManager initialized (inverse model - track cleared tiles)")
	call_deferred("_initialize_default")

func _process(delta):
	game_time += delta
	# Regrowth logic can go here later

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

# Initialize miasma system
func initialize_miasma(player_pos: Vector3, viewport_width: float, viewport_height: float):
	player_position = player_pos
	
	# Account for isometric 45° rotation
	var max_dimension = max(viewport_width, viewport_height)
	var coverage_size = max_dimension * 1.414  # sqrt(2)
	
	viewport_tiles_x = int(coverage_size / MIASMA_TILE_SIZE) + PAD * 2
	viewport_tiles_z = int(coverage_size / MIASMA_TILE_SIZE) + PAD * 2
	
	print("Miasma initialized: ", viewport_tiles_x, "x", viewport_tiles_z, " tiles (inverse model)")

# Update player position
func update_player_position(new_pos: Vector3):
	player_position = new_pos
	# No need to "fill" fog - it's everywhere by default

# Clear miasma in area (for beam clearing)
# Returns number of tiles cleared
func clear_area(world_pos: Vector3, radius: float) -> int:
	var center_tile_x = int(world_pos.x / MIASMA_TILE_SIZE)
	var center_tile_z = int(world_pos.z / MIASMA_TILE_SIZE)
	var radius_tiles = int(radius / MIASMA_TILE_SIZE) + 1
	var radius_sq = radius * radius
	
	var cleared = 0
	var tiles_to_clear = []
	
	# Find all tiles in radius
	for x in range(-radius_tiles, radius_tiles + 1):
		for z in range(-radius_tiles, radius_tiles + 1):
			var dx = x * MIASMA_TILE_SIZE
			var dz = z * MIASMA_TILE_SIZE
			var dist_sq = dx * dx + dz * dz
			
			if dist_sq <= radius_sq:
				var tile_pos = Vector2i(center_tile_x + x, center_tile_z + z)
				# Only clear if not already cleared
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
func is_cleared(tile_x: int, tile_z: int) -> bool:
	var tile_pos = Vector2i(tile_x, tile_z)
	return cleared_tiles.has(tile_pos)

# Get all cleared tiles in viewport area (for rendering)
func get_cleared_tiles_in_area(center_tile_x: int, center_tile_z: int, half_x: int, half_z: int) -> Dictionary:
	var result = {}
	
	for x in range(center_tile_x - half_x, center_tile_x + half_x):
		for z in range(center_tile_z - half_z, center_tile_z + half_z):
			var tile_pos = Vector2i(x, z)
			if cleared_tiles.has(tile_pos):
				result[tile_pos] = cleared_tiles[tile_pos]
	
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
