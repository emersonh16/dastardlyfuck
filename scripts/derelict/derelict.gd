extends CharacterBody3D

# Derelict - The 4-legged walking tank (player character)
# Moves through world coordinates, always at screen center

# Movement speed (world units per second)
const MOVE_SPEED = 50.0

# World position (player moves through world, camera follows)
var world_position: Vector3 = Vector3.ZERO

# Debug trail
var trail: Node3D = null

# Visual reference (for future sprite support)
var visual_node: Node3D = null

func _ready():
	# Get starting position from WorldManager (always in meadow)
	var world_manager = get_node_or_null("/root/WorldManager")
	if world_manager:
		# Wait a frame for WorldManager to initialize
		await get_tree().process_frame
		world_position = world_manager.get_starting_position()
		global_position = world_position
		print("Derelict initialized at world position: ", world_position)
	else:
		# Fallback: start at origin
		world_position = Vector3.ZERO
		global_position = Vector3.ZERO
		print("Derelict initialized at world position (fallback): ", world_position)
	
	# Find or create trail
	trail = get_node_or_null("../PlayerTrail")
	if not trail:
		trail = get_node_or_null("../../PlayerTrail")
	
	# Get visual node reference (for future animations/effects)
	visual_node = get_node_or_null("Visual")
	
	# Load initial chunks around starting position (reuse world_manager from above)
	world_manager = get_node_or_null("/root/WorldManager")
	if world_manager:
		# Wait a frame for WorldManager to finish initializing
		await get_tree().process_frame
		_load_chunks_around_player(world_manager, world_position)

# Load chunks around player position (with buffer)
func _load_chunks_around_player(world_manager: Node, player_pos: Vector3):
	if not world_manager:
		return
	
	# Load chunks in a 3x3 grid around the player (1 chunk buffer in each direction)
	var chunk_size_world_units = 64.0 * 64.0  # CHUNK_SIZE_TILES * GROUND_TILE_SIZE
	var chunk_x = int(player_pos.x / chunk_size_world_units)
	var chunk_z = int(player_pos.z / chunk_size_world_units)
	
	# Load 3x3 grid of chunks
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var chunk_pos = Vector3(
				(chunk_x + dx) * chunk_size_world_units + chunk_size_world_units * 0.5,
				0,
				(chunk_z + dz) * chunk_size_world_units + chunk_size_world_units * 0.5
			)
			world_manager.get_chunk_at(chunk_pos)

func _physics_process(_delta):
	# Get input - WASD relative to camera (screen space)
	var input_dir = Vector2.ZERO
	
	# WASD keys - screen space directions
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1  # W = up screen
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1  # S = down screen
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1  # D = right screen
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1  # A = left screen
	
	# Arrow keys (same as WASD)
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	
	# Convert screen-space input to world-space based on camera rotation
	# Get camera to determine forward/right directions
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d() if viewport else null
	var move_dir: Vector3
	
	if camera:
		# Get camera's forward and right vectors (projected to XZ plane)
		var camera_basis = camera.global_transform.basis
		var forward = -camera_basis.z  # Camera looks down -Z
		var right = camera_basis.x     # Camera right is +X
		
		# Project to XZ plane (ignore Y component)
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		# Convert screen-space input to world-space
		# input_dir.y = up/down screen, input_dir.x = left/right screen
		move_dir = (forward * -input_dir.y) + (right * input_dir.x)
		move_dir.y = 0  # Keep on ground plane
	else:
		# Fallback: use old isometric conversion if no camera
		var world_x = -input_dir.y + input_dir.x
		var world_z = input_dir.y + input_dir.x
		move_dir = Vector3(world_x, 0, world_z)
	
	# Set velocity for CharacterBody3D
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		velocity = move_dir * MOVE_SPEED
		
		# Rotate sprite to face movement direction (optional, for isometric view)
		# The sprite is already rotated for isometric, but we could add slight rotation
		# based on movement direction if needed
	else:
		velocity = Vector3.ZERO
	
	# Use move_and_slide for CharacterBody3D
	move_and_slide()
	
	# Update world_position from actual position after physics
	world_position = global_position
	
	# Add trail point for debugging
	if trail and trail.has_method("add_point"):
		trail.add_point(world_position)
	
	# Update MiasmaManager with player position (only when crossing tile boundaries)
	var manager = get_node_or_null("/root/MiasmaManager")
	if manager:
		manager.update_player_position(world_position)
	
	# Load chunks around player (for rock/mountain generation)
	var world_manager = get_node_or_null("/root/WorldManager")
	if world_manager:
		_load_chunks_around_player(world_manager, world_position)