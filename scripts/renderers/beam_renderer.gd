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
	# Create a circle that matches the clearing hitbox exactly
	# The clearing is a perfect circle in world space (XZ plane)
	# For isometric view, we need to show it as an ellipse that represents that circle
	
	# Use CylinderMesh for a perfect circle, positioned on XZ plane
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 48.0  # Will be updated based on mode
	cylinder_mesh.bottom_radius = 48.0
	cylinder_mesh.height = 0.1  # Very thin - essentially a flat disc
	cylinder_mesh.radial_segments = 64  # High segments for smooth circle
	
	beam_mesh_instance = MeshInstance3D.new()
	beam_mesh_instance.mesh = cylinder_mesh
	
	# Rotate to lie flat on XZ plane and align with isometric view
	# CylinderMesh is vertical (along Y) by default
	# Step 1: Rotate 90° around X to make it horizontal (flat on XZ plane)
	# Step 2: Rotate +45° around Y to compensate for camera's 45° azimuth (counter-clockwise)
	# This should make the ellipse appear aligned (not rotated) in isometric view
	beam_mesh_instance.rotation_degrees = Vector3(90, 45, 0)  # Flat on XZ, compensate camera
	beam_mesh_instance.scale = Vector3(1.0, 1.0, 1.0)  # No scaling - show actual circle
	
	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color(1.0, 0.84, 0.0, 0.2)  # Gold color, 20% opacity (more translucent)
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.flags_transparent = true
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show from both sides
	beam_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  # Don't write to depth buffer (always visible)
	beam_material.no_depth_test = true  # Always render on top
	
	beam_mesh_instance.material_override = beam_material
	beam_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Ensure beam renders above ground (higher render priority)
	# This prevents occlusion by ground or miasma
	beam_mesh_instance.transparency = 0.0  # Fully transparent material, but still renders
	beam_mesh_instance.visible = true
	
	add_child(beam_mesh_instance)

func _process(_delta):
	if not derelict or not beam_mesh_instance:
		return
	
	# Follow derelict position (ground level)
	var derelict_pos = derelict.global_position
	var ground_pos = Vector3(derelict_pos.x, 0, derelict_pos.z)
	global_position = ground_pos
	
	# Position beam well above ground level
	# Ground is at Y=-1.0, derelict at Y=0, so position beam at Y=2.0 to be clearly visible
	# This ensures the ellipse doesn't go below ground and is visible above the derelict
	beam_mesh_instance.position = Vector3(0, 2.0, 0)
	
	# DIAGNOSTIC: Print actual rotation values (only once per second to avoid spam)
	if Engine.get_process_frames() % 60 == 0:
		print("Beam rotation (local): ", beam_mesh_instance.rotation_degrees)
		print("Beam rotation (global): ", beam_mesh_instance.global_rotation_degrees)
		print("Beam parent rotation: ", rotation_degrees)
		print("Beam scale: ", beam_mesh_instance.scale)

func _on_beam_mode_changed(mode):
	if not beam_mesh_instance:
		return
	
	var params = beam_manager.get_clearing_params()
	
	match mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Update radius for bubble mode - use shared radius from BeamManager
			# This ensures visual matches hitbox exactly
			current_radius = beam_manager.get_clearing_radius()
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
	
	# Update cylinder mesh radius - use exact radius from BeamManager
	# This ensures visual matches hitbox exactly
	var cylinder = beam_mesh_instance.mesh as CylinderMesh
	if cylinder:
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
	
	# Verify visual matches hitbox: visual shows circle of radius 'radius'
	# The circle is pre-stretched to appear circular in isometric view
	# So the visual correctly represents the clearing circle in isometric view

func _on_beam_energy_changed(energy: float):
	if not beam_material:
		return
	
	# Update opacity based on energy (fade out when low energy)
	var max_energy = 64.0  # BeamManager.MAX_ENERGY constant
	var energy_ratio = energy / max_energy
	var min_opacity = 0.1  # More translucent when low energy
	var max_opacity = 0.2  # More translucent overall
	var opacity = lerp(min_opacity, max_opacity, energy_ratio)
	
	# Keep gold color, just update opacity
	beam_material.albedo_color = Color(1.0, 0.84, 0.0, opacity)
