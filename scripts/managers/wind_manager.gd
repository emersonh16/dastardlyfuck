extends Node

# WindManager - Autoload singleton
# Simple global wind system: direction + speed
# Provides velocity for miasma advection

# Wind state
var enabled: bool = true
var direction_degrees: float = 270.0  # 0 = East, 90 = North, 270 = West
var speed_tiles_per_sec: float = 8.0  # Tiles per second

# Max wind strength (clamp)
const MAX_SPEED: float = 256.0

# Signal for wind changes
signal wind_changed(velocity: Vector2)

func _ready():
	print("WindManager initialized")

# Get current wind velocity in tiles per second (Vector2: x, z)
# Returns Vector2(vx, vz) in world space
func get_velocity() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	
	var dir_rad = deg_to_rad(direction_degrees)
	var vx = cos(dir_rad) * speed_tiles_per_sec
	var vz = sin(dir_rad) * speed_tiles_per_sec
	
	# Clamp to max speed
	var magnitude = Vector2(vx, vz).length()
	if magnitude > MAX_SPEED:
		var scale = MAX_SPEED / magnitude
		vx *= scale
		vz *= scale
	
	return Vector2(vx, vz)

# Set wind direction (degrees: 0 = East, 90 = North, 270 = West)
func set_direction(degrees: float):
	direction_degrees = fmod(degrees, 360.0)
	if direction_degrees < 0:
		direction_degrees += 360.0
	wind_changed.emit(get_velocity())

# Set wind speed (tiles per second)
func set_speed(speed: float):
	speed_tiles_per_sec = clamp(speed, 0.0, MAX_SPEED)
	wind_changed.emit(get_velocity())

# Set both direction and speed
func set_wind(direction: float, speed: float):
	set_direction(direction)
	set_speed(speed)

# Toggle wind on/off
func set_enabled(e: bool):
	enabled = e
	wind_changed.emit(get_velocity())

# Get current wind state (for dev HUD)
func get_state() -> Dictionary:
	var vel = get_velocity()
	return {
		"enabled": enabled,
		"direction_degrees": direction_degrees,
		"speed_tiles_per_sec": speed_tiles_per_sec,
		"velocity": vel,
		"magnitude": vel.length()
	}
