extends Camera3D

# IsometricCamera - 45-degree locked isometric camera

var target_position: Vector3 = Vector3.ZERO
var follow_distance: float = 50.0
var camera_height: float = 30.0

func _ready():
	# Set up orthographic projection
	projection = PROJECTION_ORTHOGONAL
	size = 200.0  # Much larger size to see blocks from distance
	
	# Position camera higher and further back for isometric view
	# Isometric angle: 30 degrees elevation, 45 degrees rotation
	var elevation = deg_to_rad(30.0)  # How high up
	var rotation = deg_to_rad(45.0)    # Rotation around Y axis
	
	camera_height = 150.0  # Higher up
	follow_distance = 200.0  # Further back
	
	position = Vector3(
		follow_distance * cos(rotation) * cos(elevation),
		camera_height,
		follow_distance * sin(rotation) * cos(elevation)
	)
	
	# Look at origin
	look_at(Vector3.ZERO, Vector3.UP)
	
	print("Isometric camera initialized - position: ", position)

func set_target(new_target: Vector3):
	target_position = new_target
	_update_position()

func _update_position():
	# Keep camera at fixed angle, just move it to follow target
	var angle_rad = deg_to_rad(45.0)
	position = target_position + Vector3(
		follow_distance * cos(angle_rad),
		camera_height,
		follow_distance * sin(angle_rad)
	)
	look_at(target_position, Vector3.UP)
