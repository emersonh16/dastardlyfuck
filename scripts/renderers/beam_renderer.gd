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
	
	# 2D sheet - flat on XZ plane, no X or Z rotation (only Y rotation for direction)
	beam_mesh_instance.rotation_degrees = Vector3(0, 0, 0)  # Flat on ground, no tilt
	beam_mesh_instance.scale = Vector3(1.0, 1.0, 1.0)  # No scaling
	
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
	
	# Position beam flat on ground (2D sheet) - slightly above to avoid z-fighting
	beam_mesh_instance.position = Vector3(0, 0.01, 0)
	
	# Rotate cone/laser toward mouse (only Y rotation - keep it flat/2D)
	var current_mode = beam_manager.get_mode()
	if current_mode == BeamManager.BeamMode.CONE or current_mode == BeamManager.BeamMode.LASER:
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			var direction = (mouse_pos - ground_pos)
			if direction.length() > 0.1:
				var angle = atan2(direction.x, direction.z)  # Y rotation only (2D sheet)
				beam_mesh_instance.rotation = Vector3(0, angle, 0)  # Only Y rotation, X and Z stay 0
	

func _on_beam_mode_changed(mode):
	if not beam_mesh_instance:
		return
	
	var params = beam_manager.get_clearing_params()
	
	match mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Update radius for bubble mode - use shared radius from BeamManager
			current_radius = beam_manager.get_clearing_radius()
			_update_bubble_visual(current_radius)
			beam_mesh_instance.rotation.y = 0  # No rotation for bubble
			beam_mesh_instance.material_override = beam_material  # Use translucent material
			beam_mesh_instance.visible = true
		BeamManager.BeamMode.CONE:
			# Create cone visual
			_update_cone_visual(params.get("length", 64.0), params.get("angle", 32.0))
			beam_mesh_instance.material_override = beam_material  # Use translucent material
			beam_mesh_instance.visible = true
		BeamManager.BeamMode.LASER:
			# Create laser visual (opaque)
			_update_laser_visual(params.get("length", 128.0), params.get("thickness", 4.0))
			beam_mesh_instance.visible = true
			# Laser uses opaque material (set in _update_laser_visual)
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
	
	# Recreate circle mesh with new radius
	# ArrayMesh doesn't support dynamic radius updates, so we recreate it
	var new_circle_mesh = _create_circle_mesh(radius)
	beam_mesh_instance.mesh = new_circle_mesh
	current_radius = radius


func _get_mouse_world_position() -> Vector3:
	# Convert mouse screen position to world position on ground plane (Y=0)
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	
	# Intersect with ground plane (Y=0)
	if abs(dir.y) < 0.001:
		return Vector3.ZERO
	
	var t = -from.y / dir.y
	if t < 0:
		return Vector3.ZERO
	
	var world_pos = from + dir * t
	return Vector3(world_pos.x, 0, world_pos.z)

func _update_cone_visual(length: float, angle_deg: float):
	# Simple cone: triangle on XZ plane pointing forward (Z+)
	var half_angle = deg_to_rad(angle_deg * 0.5)
	var tip_radius = tan(half_angle) * length
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Tip point (at origin, pointing forward)
	vertices.append(Vector3(0, 0, 0))
	
	# Base arc (circle at distance = length)
	var segments = 32
	for i in range(segments + 1):
		var a = -half_angle + (i * 2.0 * half_angle / segments)
		var x = sin(a) * tip_radius
		var z = cos(a) * length
		vertices.append(Vector3(x, 0, z))
	
	# Create triangles from tip to base
	for i in range(segments):
		indices.append(0)  # Tip
		indices.append(i + 1)  # Current base point
		indices.append(i + 2 if i < segments else 1)  # Next base point
	
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	beam_mesh_instance.mesh = array_mesh

func _update_laser_visual(length: float, thickness: float):
	# Simple laser: rectangle on XZ plane pointing forward (Z+)
	var half_thickness = thickness * 0.5
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Rectangle vertices (centered on X, pointing forward on Z)
	vertices.append(Vector3(-half_thickness, 0, 0))  # Base left
	vertices.append(Vector3(half_thickness, 0, 0))   # Base right
	vertices.append(Vector3(-half_thickness, 0, length))  # Tip left
	vertices.append(Vector3(half_thickness, 0, length))    # Tip right
	
	# Two triangles
	indices.append(0)
	indices.append(1)
	indices.append(2)
	
	indices.append(1)
	indices.append(3)
	indices.append(2)
	
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	beam_mesh_instance.mesh = array_mesh
	
	# Laser is opaque (unlike bubble/cone)
	var laser_material = StandardMaterial3D.new()
	laser_material.albedo_color = Color(1.0, 0.94, 0.0, 1.0)  # Gold, fully opaque
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.flags_transparent = false
	laser_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	laser_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	laser_material.no_depth_test = true
	beam_mesh_instance.material_override = laser_material
