extends Node3D

# SimpleBeam - Handles beam clearing logic for all modes
# Auto-clears for bubble modes, click-to-fire for cone/laser
# TODO: Eventually move this logic into DerelictManager or BeamManager

var beam_manager: Node = null
var derelict: Node3D = null
var camera: Camera3D = null

var _last_clear_pos: Vector3 = Vector3.ZERO
var _clear_threshold: float = 2.0  # Only clear if derelict moved this far

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
	
	print("SimpleBeam initialized - Using BeamManager for clearing")

func _process(_delta):
	if not derelict or not beam_manager:
		return
	
	var current_mode = beam_manager.get_mode()
	
	# Handle different modes
	match current_mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Auto-clear around player (bubble modes)
			_process_bubble_mode()
		BeamManager.BeamMode.CONE, BeamManager.BeamMode.LASER:
			# Click-to-fire (cone/laser modes)
			_process_aimed_mode()
		BeamManager.BeamMode.OFF:
			# No clearing
			pass

func _process_bubble_mode():
	# Only clear if beam has energy
	if not beam_manager.can_fire():
		return
	
	var derelict_pos = derelict.global_position
	var derelict_pos_ground = Vector3(derelict_pos.x, 0, derelict_pos.z)  # Ground level
	
	# Only clear if derelict moved significantly (performance optimization)
	if derelict_pos_ground.distance_to(_last_clear_pos) >= _clear_threshold:
		_clear_bubble(derelict_pos_ground)
		_last_clear_pos = derelict_pos_ground

func _process_aimed_mode():
	# Only fire if beam has energy
	if not beam_manager.can_fire():
		return
	
	# Click to fire cone/laser
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Get mouse position in world space
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			_fire_aimed_beam(mouse_pos)

func _clear_bubble(world_pos: Vector3):
	if not beam_manager:
		return
	
	# Get clearing params from BeamManager
	var params = beam_manager.get_clearing_params()
	var radius = params.get("radius", 48.0)
	
	# Use BeamManager to clear (it will call MiasmaManager)
	beam_manager.clear_at_position(world_pos, radius)

func _fire_aimed_beam(target_pos: Vector3):
	# TODO: Implement cone/laser clearing
	# For now, just clear at target position with bubble radius
	var params = beam_manager.get_clearing_params()
	var current_mode = beam_manager.get_mode()
	
	match current_mode:
		BeamManager.BeamMode.CONE:
			# TODO: Clear cone shape from derelict to target
			_clear_cone(derelict.global_position, target_pos)
		BeamManager.BeamMode.LASER:
			# TODO: Clear line from derelict to target
			_clear_laser(derelict.global_position, target_pos)
		_:
			# Fallback: clear bubble at target
			var radius = params.get("radius", 48.0)
			beam_manager.clear_at_position(target_pos, radius)

func _clear_cone(origin: Vector3, target: Vector3):
	# TODO: Implement cone clearing
	# For now, just clear a bubble at target
	var params = beam_manager.get_clearing_params()
	var radius = params.get("length", 48.0) * 0.5  # Use half of cone length as radius for now
	beam_manager.clear_at_position(target, radius)

func _clear_laser(origin: Vector3, target: Vector3):
	# TODO: Implement laser clearing (line with multiple stamps)
	# For now, just clear a bubble at target
	var params = beam_manager.get_clearing_params()
	var radius = params.get("thickness", 4.0)
	beam_manager.clear_at_position(target, radius)

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
