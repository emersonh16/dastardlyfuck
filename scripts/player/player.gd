extends CharacterBody3D

# Player - moves through world coordinates, always at screen center

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
	print("Player initialized at world position: ", world_position)
	
	# Find or create trail
	trail = get_node_or_null("../PlayerTrail")
	if not trail:
		trail = get_node_or_null("../../PlayerTrail")

func _physics_process(delta):
	# Get input - try both arrow keys and WASD
	var input_dir = Vector2.ZERO
	
	# Arrow keys
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	
	# WASD keys
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	
	# Convert 2D input to 3D movement (XZ plane for isometric)
	var move_dir = Vector3(input_dir.x, 0, input_dir.y)
	
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
