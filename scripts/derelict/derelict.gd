extends CharacterBody3D

# Derelict - The 4-legged walking tank (player character)
# Moves through world coordinates, always at screen center

# Movement speed (world units per second)
const MOVE_SPEED = 50.0

# World position (player moves through world, camera follows)
var world_position: Vector3 = Vector3.ZERO

# Debug trail
var trail: Node3D = null

func _ready():
	# Start at origin
	world_position = Vector3.ZERO
	global_position = Vector3.ZERO
	print("Derelict initialized at world position: ", world_position)
	
	# Find or create trail
	trail = get_node_or_null("../PlayerTrail")
	if not trail:
		trail = get_node_or_null("../../PlayerTrail")

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
