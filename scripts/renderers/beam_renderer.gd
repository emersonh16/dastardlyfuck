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
	# Architecture: Custom Flat Circle Mesh (Option 3)
	# - Create a flat circle mesh directly on XZ plane (Y=0)
	# - No rotation needed - already flat!
	# - Hitbox: Circle in world space (XZ plane)
	# - Visual: Circle in world space (XZ plane)
	# - Result: Circle appears as ellipse in isometric view (natural projection)
	
	# Create custom flat circle mesh
	# Initial radius will be updated based on mode via BeamManager
	var circle_mesh = _create_circle_mesh(48.0)
	
	beam_mesh_instance = MeshInstance3D.new()
	beam_mesh_instance.mesh = circle_mesh
	
	# NO ROTATION NEEDED - mesh is already flat on XZ plane!
	beam_mesh_instance.rotation_degrees = Vector3(0, 0, 0)  # Already flat, no rotation
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

func _create_circle_mesh(radius: float) -> ArrayMesh:
	# Create a flat circle mesh on XZ plane (Y=0)
	# This is naturally flat, so no rotation needed!
	
	var segments = 64  # High segments for smooth circle
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Center vertex (at origin, Y=0)
	vertices.append(Vector3(0, 0, 0))
	
	# Generate circle vertices on XZ plane
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var x = cos(angle) * radius
		var z = sin(angle) * radius
		vertices.append(Vector3(x, 0, z))
	
	# Create triangles from center to edge
	for i in range(segments):
		indices.append(0)  # Center vertex
		indices.append(i + 1)  # Current edge vertex
		indices.append(i + 2 if i < segments else 1)  # Next edge vertex (wrap around)
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return array_mesh

func _process(_delta):
	if not derelict or not beam_mesh_instance:
		return
	
	# Follow derelict position (ground level) - EXACTLY match clearing position
	# This must match SimpleBeam._clear_bubble() position calculation
	var derelict_pos = derelict.global_position
	var ground_pos = Vector3(derelict_pos.x, 0, derelict_pos.z)  # Ground level - matches clearing
	global_position = ground_pos
	
	# Position beam well above ground level
	# Ground is at Y=-1.0, derelict at Y=0, so position beam at Y=2.0 to be clearly visible
	# This ensures the ellipse doesn't go below ground and is visible above the derelict
	beam_mesh_instance.position = Vector3(0, 2.0, 0)
	
	# DEBUG: Print visual position and radius (only once per second to avoid spam)
	if Engine.get_process_frames() % 60 == 0:
		print("VISUAL: pos=", ground_pos, " radius=", current_radius, " mesh_pos=", beam_mesh_instance.position, " rotation=", beam_mesh_instance.rotation_degrees)

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
	# Architecture: Single Source of Truth
	# - BeamManager.get_clearing_radius() defines the hitbox radius
	# - BeamRenderer uses that exact radius for visual
	# - Both are circles in world space, so they match exactly
	# - Isometric projection makes both appear as ellipses (natural, correct)
	
	if not beam_mesh_instance:
		return
	
	# DEBUG: Print when visual radius is updated
	print("VISUAL UPDATE: Setting radius to ", radius)
	
	# Recreate circle mesh with new radius
	# ArrayMesh doesn't support dynamic radius updates, so we recreate it
	var new_circle_mesh = _create_circle_mesh(radius)
	beam_mesh_instance.mesh = new_circle_mesh
	current_radius = radius

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
