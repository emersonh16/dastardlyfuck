extends Node

# BeamManager - Autoload singleton
# Manages beam system (bubble/cone/laser modes, clearing)

# Beam modes
enum BeamMode {
	OFF,
	BUBBLE_MIN,
	BUBBLE_MAX,
	CONE,
	LASER
}

# Current state
var current_mode: BeamMode = BeamMode.BUBBLE_MIN
var beam_level: int = 1

# Beam parameters (from JS design)
const BUBBLE_MIN_RADIUS = 16.0  # World units (halved from original 48.0)
const BUBBLE_MAX_RADIUS = 32.0  # World units (halved from original 96.0)
const CONE_LENGTH = 64.0
const CONE_ANGLE_DEG = 32.0
const LASER_LENGTH = 128.0
const LASER_THICKNESS = 4.0

# Signals
signal beam_mode_changed(mode)
signal beam_fired(position, radius)

var miasma_manager: Node = null

func _ready():
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	if not miasma_manager:
		push_error("BeamManager: MiasmaManager not found!")
	
	print("BeamManager initialized")

# Public API

func set_mode(mode: BeamMode):
	if mode != current_mode:
		current_mode = mode
		beam_mode_changed.emit(mode)

func get_mode() -> BeamMode:
	return current_mode

func can_fire() -> bool:
	return true  # Always can fire (no energy system)

# Clear miasma at position (called by beam renderer/system)
func clear_at_position(world_pos: Vector3, radius: float) -> int:
	if not miasma_manager:
		return 0
	
	var cleared = miasma_manager.clear_area(world_pos, radius)
	if cleared > 0:
		beam_fired.emit(world_pos, radius)
	return cleared

# Clear miasma in cone shape (from origin toward direction)
func clear_cone(origin: Vector3, direction: Vector3, length: float, angle_deg: float) -> int:
	if not miasma_manager:
		return 0
	
	# Normalize direction
	var dir = direction.normalized()
	var angle_rad = deg_to_rad(angle_deg)
	
	# Clear multiple circles along the cone path
	# Each circle's radius increases with distance from origin
	var num_stamps = int(length / 8.0) + 1  # One stamp every 8 units
	var total_cleared = 0
	
	for i in range(num_stamps):
		var t = float(i) / float(num_stamps - 1) if num_stamps > 1 else 0.0
		var distance = t * length
		var stamp_pos = origin + dir * distance
		
		# Calculate radius at this distance (cone expands linearly)
		var radius_at_distance = tan(angle_rad * 0.5) * distance
		
		# Minimum radius to ensure clearing at origin
		if radius_at_distance < 4.0:
			radius_at_distance = 4.0
		
		var cleared = miasma_manager.clear_area(stamp_pos, radius_at_distance)
		total_cleared += cleared
	
	if total_cleared > 0:
		beam_fired.emit(origin, length)
	
	return total_cleared

# Clear miasma in laser shape (straight line from origin toward direction)
func clear_laser(origin: Vector3, direction: Vector3, length: float, thickness: float) -> int:
	if not miasma_manager:
		return 0
	
	# Normalize direction - ensure it's valid
	var dir = direction
	if dir.length_squared() < 0.001:
		# Invalid direction, use default forward
		dir = Vector3(1, 0, 0)
	else:
		dir = dir.normalized()
	
	# Clear multiple circles along the laser path
	# Constant thickness (unlike cone which expands)
	var num_stamps = max(1, int(length / 4.0) + 1)  # One stamp every 4 units (more dense than cone)
	var total_cleared = 0
	var radius = thickness * 0.5  # Thickness is diameter, radius is half
	
	# Minimum radius to ensure clearing
	if radius < 2.0:
		radius = 2.0
	
	# Always clear at least at origin
	for i in range(num_stamps):
		var t = float(i) / float(num_stamps - 1) if num_stamps > 1 else 0.0
		var distance = t * length
		var stamp_pos = origin + dir * distance
		
		var cleared = miasma_manager.clear_area(stamp_pos, radius)
		total_cleared += cleared
	
	if total_cleared > 0:
		beam_fired.emit(origin, length)
	
	return total_cleared

# Get beam clearing parameters for current mode
func get_clearing_params() -> Dictionary:
	match current_mode:
		BeamMode.BUBBLE_MIN:
			return {"radius": BUBBLE_MIN_RADIUS, "shape": "circle"}
		BeamMode.BUBBLE_MAX:
			return {"radius": BUBBLE_MAX_RADIUS, "shape": "circle"}
		BeamMode.CONE:
			return {"length": CONE_LENGTH, "angle": CONE_ANGLE_DEG, "shape": "cone"}
		BeamMode.LASER:
			return {"length": LASER_LENGTH, "thickness": LASER_THICKNESS, "shape": "line"}
		_:
			return {"radius": 0.0, "shape": "none"}

# Get clearing radius for current mode (shared by hitbox and visual)
func get_clearing_radius() -> float:
	var params = get_clearing_params()
	return params.get("radius", 0.0)

# Get visual ellipse scale factor for isometric projection
# Returns the compression factor needed to show a circle as an ellipse
func get_isometric_scale_factor() -> float:
	# For 30° elevation: cos(30°) ≈ 0.866
	return cos(deg_to_rad(30.0))
