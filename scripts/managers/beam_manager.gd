extends Node

# BeamManager - Autoload singleton
# Manages beam system (bubble/cone/laser modes, energy, clearing)

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
var beam_energy: float = 64.0
var beam_level: int = 1

# Beam parameters (from JS design)
const BUBBLE_MIN_RADIUS = 24.0  # World units (halved from original 48.0)
const BUBBLE_MAX_RADIUS = 48.0  # World units (halved from original 96.0)
const CONE_LENGTH = 128.0
const CONE_ANGLE_DEG = 64.0
const LASER_LENGTH = 256.0
const LASER_THICKNESS = 4.0

# Energy system
const MAX_ENERGY = 64.0
const LASER_DRAIN_PER_SEC = 24.0
const REGEN_RATES = {
	BeamMode.OFF: 0.0,
	BeamMode.BUBBLE_MIN: 8.0,
	BeamMode.BUBBLE_MAX: 6.0,
	BeamMode.CONE: 4.0,
	BeamMode.LASER: 0.0  # Drains, doesn't regen
}

# Signals
signal beam_mode_changed(mode)
signal beam_energy_changed(energy)
signal beam_fired(position, radius)

var miasma_manager: Node = null

func _ready():
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	if not miasma_manager:
		push_error("BeamManager: MiasmaManager not found!")
	
	print("BeamManager initialized")

func _process(delta):
	_update_energy(delta)

func _update_energy(delta: float):
	var old_energy = beam_energy
	
	if current_mode == BeamMode.LASER:
		# Drain energy in laser mode
		beam_energy = max(0.0, beam_energy - LASER_DRAIN_PER_SEC * delta)
	else:
		# Regen energy in other modes
		var regen_rate = REGEN_RATES.get(current_mode, 0.0)
		beam_energy = min(MAX_ENERGY, beam_energy + regen_rate * delta)
	
	if beam_energy != old_energy:
		beam_energy_changed.emit(beam_energy)

# Public API

func set_mode(mode: BeamMode):
	if mode != current_mode:
		current_mode = mode
		beam_mode_changed.emit(mode)

func get_mode() -> BeamMode:
	return current_mode

func get_energy() -> float:
	return beam_energy

func can_fire() -> bool:
	return beam_energy > 0.0

# Clear miasma at position (called by beam renderer/system)
func clear_at_position(world_pos: Vector3, radius: float) -> int:
	if not miasma_manager:
		return 0
	
	var cleared = miasma_manager.clear_area(world_pos, radius)
	if cleared > 0:
		beam_fired.emit(world_pos, radius)
	return cleared

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
