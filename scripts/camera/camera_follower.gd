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
	# Look for player in scene
	target = get_tree().get_first_node_in_group("player")
	if not target:
		# Try finding by name
		target = get_node_or_null("../Player")
		if not target:
			target = get_node_or_null("../../Player")
	
	if target:
		print("Camera found player: ", target.name)
	else:
		push_warning("CameraFollower: No player found!")

func _process(delta):
	if not target:
		return
	
	# Get target's world position
	var target_pos = target.global_position
	
	# Smooth camera follow (lerp to reduce jitter)
	var desired_pos = target_pos + Vector3(
		follow_distance * cos(azimuth) * cos(elevation),
		camera_height,
		follow_distance * sin(azimuth) * cos(elevation)
	)
	
	# Smooth interpolation
	position = position.lerp(desired_pos, 10.0 * delta)
	
	# Always look at target
	look_at(target_pos, Vector3.UP)
