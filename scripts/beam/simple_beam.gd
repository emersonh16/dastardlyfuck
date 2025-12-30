extends Node3D

# SimpleBeam - Always-active bubble mode (clears around player)
# Visual beam that matches clearing hitbox

var player: Node3D = null
var miasma_manager: Node = null

# Bubble mode parameters (from JS: bubbleMin = 32-112, bubbleMax = 64-288)
const BUBBLE_RADIUS = 48.0  # World units (medium size for testing)
const CLEAR_BUDGET = 256  # Max tiles cleared per frame

# Visual beam
var beam_mesh_instance: MeshInstance3D = null
var beam_material: StandardMaterial3D = null

func _ready():
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	
	# Get miasma manager
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	
	if not miasma_manager:
		push_error("SimpleBeam: MiasmaManager not found!")
	
	# Create visual beam (sphere for bubble mode)
	_create_beam_visual()
	
	print("SimpleBeam initialized - Bubble mode active")

func _create_beam_visual():
	# Create flat ellipse that represents a circle in isometric projection
	# For 30° elevation, 45° rotation: circle becomes ellipse
	# Use CylinderMesh flattened to a disc, then scale to create ellipse
	
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = BUBBLE_RADIUS
	cylinder_mesh.bottom_radius = BUBBLE_RADIUS
	cylinder_mesh.height = 0.1  # Very thin - essentially a flat disc
	cylinder_mesh.radial_segments = 64  # High segments for smooth circle
	
	# Create mesh instance
	beam_mesh_instance = MeshInstance3D.new()
	beam_mesh_instance.mesh = cylinder_mesh
	
	# Scale to create ellipse for isometric projection FIRST (before rotation)
	# For 30° elevation isometric view:
	# A circle on the ground becomes an ellipse
	# The compression factor is cos(elevation) = cos(30°) ≈ 0.866
	var elevation_rad = deg_to_rad(30.0)
	var scale_factor = cos(elevation_rad)  # ≈ 0.866
	
	# Scale the cylinder to create ellipse (compress along Z axis)
	# After this, we'll rotate it to be flat and match camera angle
	beam_mesh_instance.scale = Vector3(1.0, 1.0, scale_factor)
	
	# Rotate to lie flat on ground AND match isometric camera rotation
	# Rotate 90° around X to make it horizontal, then 45° around Y to match camera
	beam_mesh_instance.rotation_degrees = Vector3(90, 45, 0)
	
	# Create material (yellow/white light color, semi-transparent)
	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color(1.0, 0.94, 0.0, 0.4)  # Yellow-white, 40% opacity
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.flags_transparent = true
	beam_material.flags_use_point_size = false
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show from both sides
	
	beam_mesh_instance.material_override = beam_material
	beam_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(beam_mesh_instance)

var _last_clear_pos: Vector3 = Vector3.ZERO
var _clear_threshold: float = 2.0  # Only clear if player moved this far

func _process(_delta):
	if not player or not miasma_manager:
		return
	
	var player_pos = player.global_position
	var player_pos_ground = Vector3(player_pos.x, 0, player_pos.z)  # Ground level
	
	# Make this node follow player (so beam is centered on player)
	global_position = player_pos_ground
	
	# Update visual beam position (relative to this node)
	# Position disc flat on ground (just slightly above to avoid z-fighting)
	if beam_mesh_instance:
		beam_mesh_instance.position = Vector3(0, 0.05, 0)  # Slightly above ground
	
	# Only clear if player moved significantly (performance optimization)
	if player_pos_ground.distance_to(_last_clear_pos) >= _clear_threshold:
		_clear_bubble(player_pos_ground)
		_last_clear_pos = player_pos_ground

func _clear_bubble(world_pos: Vector3):
	if not miasma_manager:
		return
	
	# Clear circular area around player (bubble mode)
	# Radius matches visual beam exactly
	var _cleared = miasma_manager.clear_area(world_pos, BUBBLE_RADIUS)
	# Note: cleared count is logged in manager if needed
