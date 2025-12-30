extends Node3D

# BeamRenderer - Renders visual representation of beam
# Listens to BeamManager for state changes

var beam_manager: Node = null
var derelict: Node3D = null
var camera: Camera3D = null

# Visual beam mesh
var beam_mesh_instance: MeshInstance3D = null
var beam_material: StandardMaterial3D = null

# Current beam mode
var current_radius: float = 0.0
var current_mode: BeamManager.BeamMode = BeamManager.BeamMode.OFF

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
	
	# Find camera for mouse-to-world conversion
	camera = get_viewport().get_camera_3d()
	
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
	
	# Update cone/laser visuals based on mouse position
	if current_mode == BeamManager.BeamMode.CONE:
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			var direction = (mouse_pos - ground_pos)
			if direction.length() < 0.1:
				direction = Vector3(1, 0, 0)  # Default forward direction
			else:
				direction = direction.normalized()
			# Ensure direction is in XZ plane
			direction.y = 0
			direction = direction.normalized()
			_update_cone_visual(ground_pos, direction)
	elif current_mode == BeamManager.BeamMode.LASER:
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			var direction = (mouse_pos - ground_pos)
			if direction.length() < 0.1:
				direction = Vector3(1, 0, 0)  # Default forward direction
			else:
				direction = direction.normalized()
			# Ensure direction is in XZ plane
			direction.y = 0
			direction = direction.normalized()
			_update_laser_visual(ground_pos, direction)
	

func _on_beam_mode_changed(mode):
	if not beam_mesh_instance:
		return
	
	current_mode = mode
	var params = beam_manager.get_clearing_params()
	
	match mode:
		BeamManager.BeamMode.BUBBLE_MIN, BeamManager.BeamMode.BUBBLE_MAX:
			# Update radius for bubble mode - use shared radius from BeamManager
			# This ensures visual matches hitbox exactly
			current_radius = beam_manager.get_clearing_radius()
			_update_bubble_visual(current_radius)
			beam_mesh_instance.visible = true
		BeamManager.BeamMode.CONE:
			# Create cone visual with default forward direction
			var default_direction = Vector3(1, 0, 0)
			var ground_pos = Vector3(derelict.global_position.x, 0, derelict.global_position.z) if derelict else Vector3.ZERO
			_update_cone_visual(ground_pos, default_direction)
			beam_mesh_instance.visible = true
		BeamManager.BeamMode.LASER:
			# Create laser visual with default forward direction
			var default_direction = Vector3(1, 0, 0)
			var ground_pos = Vector3(derelict.global_position.x, 0, derelict.global_position.z) if derelict else Vector3.ZERO
			_update_laser_visual(ground_pos, default_direction)
			beam_mesh_instance.visible = true
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

# Helper function to get mouse world position (reused from SimpleBeam logic)
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
		# Ray is parallel to ground, return zero
		return Vector3.ZERO
	
	var t = -from.y / dir.y
	if t < 0:
		# Ray points away from ground
		return Vector3.ZERO
	
	var world_pos = from + dir * t
	return Vector3(world_pos.x, 0, world_pos.z)

# Create cone sector mesh (pie slice shape)
func _create_cone_sector_mesh(direction: Vector3, length: float, angle_deg: float) -> ArrayMesh:
	# Create a flat sector (pie slice) on XZ plane
	# Sector spans from origin, expanding outward in the given direction
	
	var angle_rad = deg_to_rad(angle_deg)
	var segments = 32  # Number of segments for smooth arc
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Ensure direction is normalized and in XZ plane
	direction.y = 0
	direction = direction.normalized()
	
	# Calculate rotation angle using atan2 (simpler and more direct)
	# atan2(z, x) gives angle from positive X axis in XZ plane
	var rotation_angle = atan2(direction.z, direction.x)
	
	# Origin vertex (at 0, 0, 0)
	vertices.append(Vector3(0, 0, 0))
	
	# Generate arc vertices in local space (pointing forward along X axis)
	# Then rotate them to match direction
	for i in range(segments + 1):
		var t = float(i) / float(segments)  # 0 to 1
		# Calculate angle from -angle_rad to +angle_rad
		var local_angle = lerp(-angle_rad, angle_rad, t)
		# Create vertex in local space (forward along X, rotated by local_angle)
		var local_vertex = Vector3(cos(local_angle), 0, sin(local_angle)) * length
		# Rotate to match direction
		var rotated_vertex = local_vertex.rotated(Vector3.UP, rotation_angle)
		vertices.append(rotated_vertex)
	
	# Create triangles from origin to arc (fan pattern)
	for i in range(segments):
		indices.append(0)  # Origin vertex
		indices.append(i + 1)  # Current arc vertex
		indices.append(i + 2)  # Next arc vertex
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return array_mesh

# Create laser rectangle mesh (flat rectangle along direction)
func _create_laser_rectangle_mesh(direction: Vector3, length: float, thickness: float) -> ArrayMesh:
	# Create a flat rectangle on XZ plane
	# Rectangle starts at origin and extends outward along direction (not centered)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Ensure direction is normalized and in XZ plane
	direction.y = 0
	direction = direction.normalized()
	
	# Calculate rotation angle using atan2 (simpler and more direct)
	# atan2(z, x) gives angle from positive X axis in XZ plane
	var rotation_angle = atan2(direction.z, direction.x)
	
	# Calculate half thickness (width perpendicular to direction)
	var half_thickness = thickness * 0.5
	
	# Create 4 vertices in local space (pointing forward along X axis)
	# Rectangle starts at origin (0, 0, 0) and extends to (length, 0, 0)
	var local_vertices = [
		Vector3(0, 0, -half_thickness),        # Origin-left
		Vector3(0, 0, half_thickness),         # Origin-right
		Vector3(length, 0, half_thickness),   # End-right
		Vector3(length, 0, -half_thickness)    # End-left
	]
	
	# Rotate all vertices to match direction
	for local_vertex in local_vertices:
		var rotated_vertex = local_vertex.rotated(Vector3.UP, rotation_angle)
		vertices.append(rotated_vertex)
	
	# Create 2 triangles forming the rectangle
	# Triangle 1: Origin-left, Origin-right, End-right
	indices.append(0)
	indices.append(1)
	indices.append(2)
	
	# Triangle 2: Origin-left, End-right, End-left
	indices.append(0)
	indices.append(2)
	indices.append(3)
	
	# Create the mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return array_mesh

# Update cone visual
func _update_cone_visual(origin: Vector3, direction: Vector3):
	if not beam_mesh_instance or not beam_manager:
		return
	
	# Get parameters from BeamManager (single source of truth)
	var params = beam_manager.get_clearing_params()
	var length = params.get("length", 64.0)
	var angle = params.get("angle", 32.0)
	
	# Ensure direction is normalized and in XZ plane
	direction.y = 0
	direction = direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3(1, 0, 0)  # Default forward
	
	# Create cone sector mesh
	var cone_mesh = _create_cone_sector_mesh(direction, length, angle)
	beam_mesh_instance.mesh = cone_mesh

# Update laser visual
func _update_laser_visual(origin: Vector3, direction: Vector3):
	if not beam_mesh_instance or not beam_manager:
		return
	
	# Get parameters from BeamManager (single source of truth)
	var params = beam_manager.get_clearing_params()
	var length = params.get("length", 128.0)
	var thickness = params.get("thickness", 4.0)
	
	# Ensure direction is normalized and in XZ plane
	direction.y = 0
	direction = direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3(1, 0, 0)  # Default forward
	
	# Create laser rectangle mesh
	var laser_mesh = _create_laser_rectangle_mesh(direction, length, thickness)
	beam_mesh_instance.mesh = laser_mesh
