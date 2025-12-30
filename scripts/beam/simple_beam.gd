extends Node3D

# SimpleBeam - Handles beam clearing logic for all modes
# Clears continuously every frame (no throttling)
# Clears immediately when mode switches

var beam_manager: Node = null
var derelict: Node3D = null
var camera: Camera3D = null

func _ready():
	# Get BeamManager
	beam_manager = get_node_or_null("/root/BeamManager")
	if not beam_manager:
		push_error("SimpleBeam: BeamManager not found!")
		return
	
	# Find derelict
	derelict = get_tree().get_first_node_in_group("player")
	if not derelict:
		derelict = get_tree().get_first_node_in_group("derelict")
	if not derelict:
		derelict = get_node_or_null("../Derelict")
	
	# Find camera for mouse-to-world conversion
	camera = get_viewport().get_camera_3d()
	
	# Connect to mode change signal to clear immediately on switch
	beam_manager.beam_mode_changed.connect(_on_mode_changed)
	
	print("SimpleBeam initialized - Clearing every frame")

func _on_mode_changed(_mode):
	# Clear immediately when mode switches
	_process_clear()

func _process(_delta):
	if not derelict or not beam_manager:
		return
	
	# Clear every frame (no throttling)
	_process_clear()

func _process_clear():
	var current_mode = beam_manager.get_mode()
	var derelict_pos = derelict.global_position
	var derelict_pos_ground = Vector3(derelict_pos.x, 0, derelict_pos.z)  # Ground level
	
	# Handle different modes - clear every frame
	match current_mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Continuously clear around player (bubble modes)
			_clear_bubble(derelict_pos_ground)
		BeamManager.BeamMode.CONE_MIN, BeamManager.BeamMode.CONE_MAX:
			# Continuously clear cone from player toward mouse
			var mouse_pos = _get_mouse_world_position()
			if mouse_pos != Vector3.ZERO:
				var direction = (mouse_pos - derelict_pos_ground)
				# If direction is too small, use a default direction (forward)
				if direction.length() < 0.1:
					direction = Vector3(1, 0, 0)  # Default forward direction
				else:
					direction = direction.normalized()
				_clear_cone(derelict_pos_ground, direction)
		BeamManager.BeamMode.LASER:
			# Continuously clear laser from player toward mouse
			var mouse_pos = _get_mouse_world_position()
			var direction: Vector3
			if mouse_pos != Vector3.ZERO:
				direction = (mouse_pos - derelict_pos_ground)
				# If direction is too small, use a default direction (forward)
				if direction.length() < 0.1:
					direction = Vector3(1, 0, 0)  # Default forward direction
				else:
					direction = direction.normalized()
			else:
				# Mouse position unavailable, use default forward direction
				direction = Vector3(1, 0, 0)
			_clear_laser(derelict_pos_ground, direction)
		BeamManager.BeamMode.OFF:
			# No clearing
			pass

func _clear_bubble(world_pos: Vector3):
	if not beam_manager:
		return
	
	# Get clearing params from BeamManager
	var params = beam_manager.get_clearing_params()
	var radius = params.get("radius", 48.0)
	
	# Use BeamManager to clear (it will call MiasmaManager)
	beam_manager.clear_at_position(world_pos, radius)

func _clear_cone(origin: Vector3, direction: Vector3):
	if not beam_manager:
		return
	
	# Get cone parameters from BeamManager
	var params = beam_manager.get_clearing_params()
	var length = params.get("length", 64.0)
	var angle = params.get("angle", 32.0)
	
	# Use BeamManager to clear cone
	beam_manager.clear_cone(origin, direction, length, angle)

func _clear_laser(origin: Vector3, direction: Vector3):
	if not beam_manager:
		return
	
	# Get laser parameters from BeamManager
	var params = beam_manager.get_clearing_params()
	var length = params.get("length", 128.0)
	var thickness = params.get("thickness", 4.0)
	
	# Use BeamManager to clear laser
	beam_manager.clear_laser(origin, direction, length, thickness)

func _get_mouse_world_position() -> Vector3:
	# Convert mouse screen position to world position on ground plane (Y=0)
	if not camera:
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	# Intersect with ground plane (Y=0)
	# Ray: from + t*dir, find t where Y=0
	# from.y + t*dir.y = 0
	# t = -from.y / dir.y
	
	if abs(dir.y) < 0.001:
		# Ray is parallel to ground, return null
		return Vector3.ZERO
	
	var t = -from.y / dir.y
	if t < 0:
		# Ray points away from ground
		return Vector3.ZERO
	
	var world_pos = from + dir * t
	return Vector3(world_pos.x, 0, world_pos.z)
