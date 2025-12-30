extends Node3D

# BeamRenderer - Renders visual representation of beam
# Listens to BeamManager for state changes

var beam_manager: Node = null
var derelict: Node3D = null

# Visual beam mesh
var beam_mesh_instance: MeshInstance3D = null
var beam_material: StandardMaterial3D = null

# Current beam mode
var current_radius: float = 0.0

func _ready():
	# Get BeamManager
	beam_manager = get_node_or_null("/root/BeamManager")
	if not beam_manager:
		push_error("BeamRenderer: BeamManager not found!")
		return
	
	# Find derelict
	derelict = get_tree().get_first_node_in_group("player")
	if not derelict:
		derelict = get_tree().get_first_node_in_group("derelict")
	if not derelict:
		derelict = get_node_or_null("../Derelict")
	
	# Connect to BeamManager signals
	beam_manager.beam_mode_changed.connect(_on_beam_mode_changed)
	beam_manager.beam_energy_changed.connect(_on_beam_energy_changed)
	
	# Create initial beam visual
	_create_beam_visual()
	
	# Set initial mode
	_on_beam_mode_changed(beam_manager.get_mode())
	
	print("BeamRenderer initialized")

func _create_beam_visual():
	# Create flat ellipse that represents a circle in isometric projection
	# Use CylinderMesh for smooth circle, then scale to ellipse
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 48.0  # Will be updated based on mode
	cylinder_mesh.bottom_radius = 48.0
	cylinder_mesh.height = 0.1  # Very thin - essentially a flat disc
	cylinder_mesh.radial_segments = 64  # High segments for smooth circle
	
	beam_mesh_instance = MeshInstance3D.new()
	beam_mesh_instance.mesh = cylinder_mesh
	
	# For isometric view at 30° elevation, 45° azimuth:
	# A circle on the ground appears as an ellipse
	# The compression factor is cos(elevation) = cos(30°) ≈ 0.866
	# We need to compress along the axis that's perpendicular to the camera's view direction
	# Since camera is at 45° azimuth, we compress along the diagonal
	var elevation_rad = deg_to_rad(30.0)
	var azimuth_rad = deg_to_rad(45.0)
	var scale_factor = cos(elevation_rad)  # ≈ 0.866
	
	# Scale to create ellipse: compress along the axis perpendicular to camera view
	# For 45° azimuth, compress along the diagonal (1, 0, 1) direction
	# Actually, simpler: compress Z axis, then rotate to match camera
	beam_mesh_instance.scale = Vector3(1.0, 1.0, scale_factor)
	
	# Rotate to lie flat on ground (90° around X) AND match isometric camera rotation (45° around Y)
	beam_mesh_instance.rotation_degrees = Vector3(90, 45, 0)
	
	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color(1.0, 0.94, 0.0, 0.4)  # Yellow-white, 40% opacity
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.flags_transparent = true
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show from both sides
	
	beam_mesh_instance.material_override = beam_material
	beam_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(beam_mesh_instance)

func _process(_delta):
	if not derelict or not beam_mesh_instance:
		return
	
	# Follow derelict position (ground level)
	var derelict_pos = derelict.global_position
	var ground_pos = Vector3(derelict_pos.x, 0, derelict_pos.z)
	global_position = ground_pos
	
	# Position beam at ground level (ground is at Y=-1.0, derelict at Y=0)
	# The ellipse is a flat disc, position it just above ground for visibility
	# Using Y=1.0 to be clearly visible but close to ground level
	beam_mesh_instance.position = Vector3(0, 1.0, 0)

func _on_beam_mode_changed(mode):
	if not beam_mesh_instance:
		return
	
	var params = beam_manager.get_clearing_params()
	
	match mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Update radius for bubble mode
			current_radius = params.get("radius", 48.0)
			_update_bubble_visual(current_radius)
			beam_mesh_instance.visible = true
		BeamManager.BeamMode.CONE:
			# TODO: Create cone visual
			beam_mesh_instance.visible = false
		BeamManager.BeamMode.LASER:
			# TODO: Create laser visual
			beam_mesh_instance.visible = false
		BeamManager.BeamMode.OFF:
			beam_mesh_instance.visible = false

func _update_bubble_visual(radius: float):
	if not beam_mesh_instance or not beam_mesh_instance.mesh:
		return
	
	# Update cylinder mesh radius
	var cylinder = beam_mesh_instance.mesh as CylinderMesh
	if cylinder:
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius

func _on_beam_energy_changed(energy: float):
	if not beam_material:
		return
	
	# Update opacity based on energy (fade out when low energy)
	var max_energy = 64.0  # BeamManager.MAX_ENERGY constant
	var energy_ratio = energy / max_energy
	var min_opacity = 0.2
	var max_opacity = 0.4
	var opacity = lerp(min_opacity, max_opacity, energy_ratio)
	
	beam_material.albedo_color.a = opacity
