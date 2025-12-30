extends Camera3D

# CameraFollower - Keeps camera centered on player with isometric angle

var target: Node3D = null
var follow_distance: float = 200.0
var camera_height: float = 150.0

# Isometric angles
var elevation: float = deg_to_rad(30.0)  # How high up
var azimuth: float = deg_to_rad(45.0)    # Rotation around Y axis

func _ready():
	# Set up orthographic projection
	projection = PROJECTION_ORTHOGONAL
	size = 200.0
	
	# Find player
	call_deferred("_find_player")
	
	print("CameraFollower initialized")

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

func _process(delta):
	if not target:
		return
	
	# Get target's world position
	var target_pos = target.global_position
	
	# Calculate fixed camera position (no rotation, just scroll)
	var desired_pos = target_pos + Vector3(
		follow_distance * cos(azimuth) * cos(elevation),
		camera_height,
		follow_distance * sin(azimuth) * cos(elevation)
	)
	
	# Smooth interpolation for position (but keep camera angle fixed)
	position = position.lerp(desired_pos, 10.0 * delta)
	
	# FIXED: Use look_at() to point at target, then lock rotation
	look_at(target_pos, Vector3.UP)
	
	# Immediately lock rotation to prevent drift
	# Calculate fixed rotation from isometric angles
	# The camera should always have the same rotation regardless of position
	var fixed_rotation_y = azimuth  # 45 degrees around Y
	var fixed_rotation_x = -elevation  # -30 degrees around X (negative because we're looking down)
	
	# Set fixed rotation (this prevents drift while maintaining correct orientation)
	rotation = Vector3(fixed_rotation_x, fixed_rotation_y, 0.0)
