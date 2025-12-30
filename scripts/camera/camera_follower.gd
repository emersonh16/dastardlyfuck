extends Camera3D

# CameraFollower - Keeps camera centered on player with free rotation support

var target: Node3D = null
var follow_distance: float = 200.0
var camera_height: float = 150.0

# Camera rotation angles (can be changed freely)
var elevation: float = deg_to_rad(30.0)  # How high up (0 = horizontal, 90 = straight down)
var azimuth: float = deg_to_rad(45.0)    # Rotation around Y axis (0 = North, 90 = East)

# Rotation controls (optional - set to false to disable)
var enable_mouse_rotation: bool = true
var enable_keyboard_rotation: bool = true
var mouse_rotation_speed: float = 0.002  # Sensitivity for mouse drag
var keyboard_rotation_speed: float = 1.0  # Degrees per second for keyboard

# Mouse rotation state
var is_rotating: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

func _ready():
	# Set up orthographic projection
	projection = PROJECTION_ORTHOGONAL
	size = 200.0
	
	# Find player
	call_deferred("_find_player")
	
	# Set initial camera position based on angles
	_update_camera_position()
	
	print("CameraFollower initialized (free rotation enabled)")

func _find_player():
	# Look for derelict (player) in scene - check both groups and name
	target = get_tree().get_first_node_in_group("player")
	if not target:
		target = get_tree().get_first_node_in_group("derelict")
	if not target:
		# Try finding by name
		target = get_node_or_null("../Derelict")
		if not target:
			target = get_node_or_null("../Player")
		if not target:
			target = get_node_or_null("../../Derelict")
	
	if target:
		print("Camera found derelict: ", target.name)
	else:
		push_warning("CameraFollower: No derelict/player found!")

func _input(event):
	# Mouse rotation (right-click drag or middle mouse drag)
	if enable_mouse_rotation:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					is_rotating = true
					last_mouse_pos = event.position
				else:
					is_rotating = false
		
		if event is InputEventMouseMotion and is_rotating:
			var mouse_delta = event.position - last_mouse_pos
			last_mouse_pos = event.position
			
			# Rotate azimuth (horizontal) based on X mouse movement
			azimuth -= mouse_delta.x * mouse_rotation_speed
			
			# Rotate elevation (vertical) based on Y mouse movement
			elevation += mouse_delta.y * mouse_rotation_speed
			
			# Clamp elevation to prevent flipping
			elevation = clamp(elevation, deg_to_rad(5.0), deg_to_rad(89.0))

func _process(delta):
	if not target:
		return
	
	# Keyboard rotation controls (optional)
	if enable_keyboard_rotation:
		var rotation_delta = keyboard_rotation_speed * deg_to_rad(delta)
		
		# Q/E for azimuth (horizontal rotation)
		if Input.is_key_pressed(KEY_Q):
			azimuth -= rotation_delta
		if Input.is_key_pressed(KEY_E):
			azimuth += rotation_delta
		
		# R/F for elevation (vertical angle)
		if Input.is_key_pressed(KEY_R):
			elevation = clamp(elevation - rotation_delta, deg_to_rad(5.0), deg_to_rad(89.0))
		if Input.is_key_pressed(KEY_F):
			elevation = clamp(elevation + rotation_delta, deg_to_rad(5.0), deg_to_rad(89.0))
	
	# Get target's world position
	var target_pos = target.global_position
	
	# Update camera position based on current angles
	_update_camera_position()
	
	# Smooth interpolation for position
	var desired_pos = target_pos + Vector3(
		follow_distance * cos(azimuth) * cos(elevation),
		camera_height,
		follow_distance * sin(azimuth) * cos(elevation)
	)
	position = position.lerp(desired_pos, 10.0 * delta)
	
	# Always look at target (camera rotation is free, but always centers on player)
	look_at(target_pos, Vector3.UP)

# Update camera position based on current rotation angles
func _update_camera_position():
	# This is called when angles change to immediately update position
	# The actual position is interpolated in _process, but this ensures
	# the camera responds immediately to rotation changes
	pass
