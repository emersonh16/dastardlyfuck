extends Node

# MiasmaManager - Autoload singleton
# Manages miasma block state and coordinates rendering

# Constants
# For isometric squares: make X and Z equal so blocks appear square in isometric view
const MIASMA_TILE_SIZE_X = 4.0  # Smaller blocks for more granular fog
const MIASMA_TILE_SIZE_Z = 4.0  # Smaller blocks for more granular fog
const MIASMA_BLOCK_HEIGHT = 16.0

# Block storage: Dictionary of Vector3i -> bool (present/absent)
# Using Vector3i for grid coordinates (x, y are 2D grid, z=0 for now)
var blocks: Dictionary = {}

# Track cleared tiles (so they don't regrow)
# Set of Vector3i coordinates that have been permanently cleared
var cleared_tiles: Dictionary = {}  # Vector3i -> true (cleared)

# Viewport + buffer size (in tiles)
var viewport_tiles_x: int = 0
var viewport_tiles_z: int = 0
var buffer_tiles: int = 8  # Buffer around viewport (reduced for performance)

# Player position (world space) - miasma moves with player
var player_position: Vector3 = Vector3.ZERO

# Signal for renderer updates
signal blocks_changed()

func _ready():
	print("MiasmaManager initialized")
	# Initialize with default viewport size (will be updated by scene)
	call_deferred("_initialize_default")

func _initialize_default():
	# Default initialization for testing
	var viewport = get_viewport()
	if viewport:
		# Use camera's orthographic size for world units, not pixel size
		var camera = viewport.get_camera_3d()
		var world_width = 200.0  # Default camera size
		var world_height = 200.0
		if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			world_width = camera.size
			var pixel_size = viewport.get_visible_rect().size
			world_height = camera.size * (pixel_size.y / pixel_size.x)
		# Pass world units - initialize_miasma will add buffer automatically
		initialize_miasma(Vector3.ZERO, world_width, world_height)

# Initialize miasma around player position
func initialize_miasma(player_pos: Vector3, viewport_width: float, viewport_height: float):
	player_position = player_pos
	
	# Calculate viewport size in tiles
	viewport_tiles_x = int(viewport_width / MIASMA_TILE_SIZE_X) + buffer_tiles * 2
	viewport_tiles_z = int(viewport_height / MIASMA_TILE_SIZE_Z) + buffer_tiles * 2
	
	# Fill area with blocks (for testing)
	fill_area_around_player()
	
	print("Miasma initialized: ", viewport_tiles_x, "x", viewport_tiles_z, " tiles")

# Fill area around player with blocks (for testing)
# Only fills tiles that aren't already cleared
func fill_area_around_player():
	# Don't clear existing blocks - only add new ones in empty areas
	var center_tile_x = int(player_position.x / MIASMA_TILE_SIZE_X)
	var center_tile_z = int(player_position.z / MIASMA_TILE_SIZE_Z)  # Using Z for isometric
	
	var half_x = viewport_tiles_x / 2.0
	var half_z = viewport_tiles_z / 2.0
	
	var added = 0
	# Fill every tile (no gaps) - completely fill the space
	# IMPORTANT: Only fill NEW areas, never refill cleared areas
	for x in range(-half_x, half_x):
		for z in range(-half_z, half_z):
			var tile_pos = Vector3i(center_tile_x + x, center_tile_z + z, 0)
			# Only add if not already present AND not cleared
			# Cleared tiles should never regrow
			if not blocks.has(tile_pos) and not cleared_tiles.has(tile_pos):
				blocks[tile_pos] = true
				added += 1
	
	# Only emit signal if blocks were actually added (performance)
	if added > 0:
		blocks_changed.emit()

# Update player position (miasma follows player)
func update_player_position(new_pos: Vector3):
	# Only update if player moved to a different tile (not every frame)
	var old_center_x = int(player_position.x / MIASMA_TILE_SIZE_X)
	var old_center_z = int(player_position.z / MIASMA_TILE_SIZE_Z)
	
	var new_center_x = int(new_pos.x / MIASMA_TILE_SIZE_X)
	var new_center_z = int(new_pos.z / MIASMA_TILE_SIZE_Z)
	
	# Only update if player crossed a tile boundary
	if new_center_x != old_center_x or new_center_z != old_center_z:
		# DIAGNOSTIC: Print player tile position
		print("Player tile: (", new_center_x, ", ", new_center_z, ") world: ", new_pos)
		player_position = new_pos
		fill_area_around_player()
	else:
		# Just update position, don't regenerate miasma
		player_position = new_pos

# Clear blocks in area (for beam clearing)
func clear_area(world_pos: Vector3, radius: float):
	var center_tile_x = int(world_pos.x / MIASMA_TILE_SIZE_X)
	var center_tile_z = int(world_pos.z / MIASMA_TILE_SIZE_Z)
	var radius_tiles = int(radius / MIASMA_TILE_SIZE_X) + 1
	var radius_sq = radius * radius
	
	var cleared = 0
	var tiles_to_remove = []
	
	# First pass: collect tiles to remove (faster than checking each time)
	for x in range(-radius_tiles, radius_tiles + 1):
		for z in range(-radius_tiles, radius_tiles + 1):
			var dx = x * MIASMA_TILE_SIZE_X
			var dz = z * MIASMA_TILE_SIZE_Z
			var dist_sq = dx * dx + dz * dz
			
			if dist_sq <= radius_sq:
				var tile_pos = Vector3i(center_tile_x + x, center_tile_z + z, 0)
				if blocks.has(tile_pos):
					tiles_to_remove.append(tile_pos)
					cleared_tiles[tile_pos] = true  # Mark as permanently cleared
					cleared += 1
	
	# Second pass: remove all at once (more efficient)
	if tiles_to_remove.size() > 0:
		for tile_pos in tiles_to_remove:
			blocks.erase(tile_pos)
		
		blocks_changed.emit()
	
	return cleared

# Get all blocks (for rendering)
func get_all_blocks() -> Dictionary:
	return blocks.duplicate()
