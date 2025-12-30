extends Node3D

# SimpleBeam - Legacy beam clearing logic (being phased out)
# This now acts as a bridge between old system and new BeamManager
# Handles automatic clearing around derelict (always-active bubble mode)
# TODO: Eventually move this logic into DerelictManager or BeamManager

var beam_manager: Node = null
var derelict: Node3D = null

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
	
	# Set beam to bubble mode (always active for now)
	beam_manager.set_mode(BeamManager.BeamMode.BUBBLE_MIN)
	
	print("SimpleBeam initialized - Using BeamManager for clearing")

func _process(_delta):
	if not derelict or not beam_manager:
		return
	
	# Only clear if beam has energy
	if not beam_manager.can_fire():
		return
	
	var derelict_pos = derelict.global_position
	var derelict_pos_ground = Vector3(derelict_pos.x, 0, derelict_pos.z)  # Ground level
	
	# Only clear if derelict moved significantly (performance optimization)
	if derelict_pos_ground.distance_to(_last_clear_pos) >= _clear_threshold:
		_clear_bubble(derelict_pos_ground)
		_last_clear_pos = derelict_pos_ground

func _clear_bubble(world_pos: Vector3):
	if not beam_manager:
		return
	
	# Get clearing params from BeamManager
	var params = beam_manager.get_clearing_params()
	var radius = params.get("radius", 48.0)
	
	# Use BeamManager to clear (it will call MiasmaManager)
	beam_manager.clear_at_position(world_pos, radius)
