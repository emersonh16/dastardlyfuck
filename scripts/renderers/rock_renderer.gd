extends Node3D

# RockRenderer - Renders rocks
# Short rocks render below miasma (covered by miasma)
# Tall rocks render above miasma (on top of miasma)

var rock_manager: Node = null
var rock_meshes: Dictionary = {}  # rock_id -> ArrayMesh (cached meshes)
var rock_collision_bodies: Dictionary = {}  # rock_id -> StaticBody3D

# MultiMeshInstance3D for batched rendering (1 draw call instead of 100+)
var multimesh_instance: MultiMeshInstance3D = null

# Materials per biome
var rock_materials: Dictionary = {}

# Miasma height (rocks below this are covered, above this are on top)
# Miasma renders at Y=0.05 (sheet_thickness/2.0 where sheet_thickness=0.1)
const MIASMA_HEIGHT: float = 0.05

# Performance optimization: only update when bounds change significantly
var _last_bounds: Dictionary = {}
const BOUNDS_UPDATE_THRESHOLD: float = 100.0  # Only update if bounds moved by this much

# Track which rocks are currently in MultiMesh
var _multimesh_rock_ids: Array = []

func _ready():
	# DISABLED: Rocks completely disabled for performance
	set_process(false)
	set_physics_process(false)
	return
	
	rock_manager = get_node_or_null("/root/RockManager")
	if not rock_manager:
		push_error("RockRenderer: RockManager not found!")
		return
	
	# Create materials for each biome
	_create_biome_materials()
	
	# Create MultiMeshInstance3D for batched rendering
	multimesh_instance = MultiMeshInstance3D.new()
	add_child(multimesh_instance)
	
	# Connect to rock manager signals
	if rock_manager.has_signal("rocks_changed"):
		rock_manager.rocks_changed.connect(_on_rocks_changed)
	
	# Initial render
	call_deferred("_update_rocks")

func _create_biome_materials():
	var world_manager = get_node_or_null("/root/WorldManager")
	if not world_manager:
		return
	
	# Create materials for each biome type
	for biome_type in WorldManager.BiomeType.values():
		var material = StandardMaterial3D.new()
		
		# Get biome color and adjust for rocks (darker than ground, lighter than mountains)
		var biome_color = world_manager.get_biome_color(biome_type)
		var rock_color = biome_color.darkened(0.2)  # Darker than ground, lighter than mountains
		
		material.albedo_color = rock_color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		
		rock_materials[biome_type] = material

func _process(_delta):
	# DISABLED: Rocks completely disabled for performance
	return
	# Only update when bounds change significantly (performance optimization)
	_update_rocks()

func _update_rocks():
	if not rock_manager:
		return
	
	# EARLY EXIT: Check bounds first before expensive viewport calculations
	# Use cached player position for quick bounds estimate
	var miasma_manager = get_node_or_null("/root/MiasmaManager")
	if miasma_manager:
		var player_pos = miasma_manager.player_position
		var estimated_min_x = player_pos.x - 500.0  # Rough estimate
		var estimated_max_x = player_pos.x + 500.0
		var estimated_min_z = player_pos.z - 500.0
		var estimated_max_z = player_pos.z + 500.0
		
		# Quick check: if bounds haven't changed much, skip expensive calculations
		if _last_bounds.has("min_x"):
			var bounds_moved = abs(_last_bounds.min_x - estimated_min_x) > BOUNDS_UPDATE_THRESHOLD or \
			                   abs(_last_bounds.max_x - estimated_max_x) > BOUNDS_UPDATE_THRESHOLD or \
			                   abs(_last_bounds.min_z - estimated_min_z) > BOUNDS_UPDATE_THRESHOLD or \
			                   abs(_last_bounds.max_z - estimated_max_z) > BOUNDS_UPDATE_THRESHOLD
			if not bounds_moved:
				return  # Skip expensive viewport calculations
	
	# Get viewport bounds (expensive - only do if bounds changed)
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return
	
	# Calculate visible world bounds
	var screen_size = viewport.get_visible_rect().size
	var corners = [
		Vector2(0, 0),
		Vector2(screen_size.x, 0),
		Vector2(screen_size.x, screen_size.y),
		Vector2(0, screen_size.y)
	]
	
	var world_corners = []
	for corner in corners:
		var from = camera.project_ray_origin(corner)
		var dir = camera.project_ray_normal(corner)
		if abs(dir.y) > 0.001:
			var t = -from.y / dir.y
			if t > 0:
				var world_pos = from + dir * t
				world_corners.append(Vector3(world_pos.x, 0, world_pos.z))
	
	if world_corners.size() < 3:
		return
	
	# Calculate bounds
	var min_x = world_corners[0].x
	var max_x = world_corners[0].x
	var min_z = world_corners[0].z
	var max_z = world_corners[0].z
	for corner in world_corners:
		min_x = min(min_x, corner.x)
		max_x = max(max_x, corner.x)
		min_z = min(min_z, corner.z)
		max_z = max(max_z, corner.z)
	
	# Add padding
	var padding = 200.0
	min_x -= padding
	max_x += padding
	min_z -= padding
	max_z += padding
	
	# Final bounds check (after expensive calculation)
	if _last_bounds.has("min_x"):
		var bounds_moved = abs(_last_bounds.min_x - min_x) > BOUNDS_UPDATE_THRESHOLD or \
		                   abs(_last_bounds.max_x - max_x) > BOUNDS_UPDATE_THRESHOLD or \
		                   abs(_last_bounds.min_z - min_z) > BOUNDS_UPDATE_THRESHOLD or \
		                   abs(_last_bounds.max_z - max_z) > BOUNDS_UPDATE_THRESHOLD
		if not bounds_moved:
			return  # Bounds haven't changed enough, skip update
	
	# Store current bounds
	_last_bounds = {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}
	
	# Get rocks in area
	var rocks = rock_manager.get_rocks_in_area(min_x, max_x, min_z, max_z)
	
	# Track which rocks should be visible
	var visible_rock_ids = {}
	var rocks_changed = false
	
	# Ensure meshes exist for visible rocks and create collision if needed
	for rock in rocks:
		var rock_id = rock.id
		visible_rock_ids[rock_id] = true
		
		# Create mesh if it doesn't exist (cache it)
		if not rock_meshes.has(rock_id):
			rock_meshes[rock_id] = _build_rock_mesh(rock)
			rocks_changed = true
		
		# Create collision if it doesn't exist
		if not rock_collision_bodies.has(rock_id):
			_create_rock_collision(rock)
	
	# Remove collision bodies for rocks that are no longer visible
	var to_remove = []
	for rock_id in rock_collision_bodies:
		if not visible_rock_ids.has(rock_id):
			to_remove.append(rock_id)
	
	for rock_id in to_remove:
		var collision_body = rock_collision_bodies.get(rock_id)
		if collision_body:
			collision_body.queue_free()
		rock_collision_bodies.erase(rock_id)
		rocks_changed = true
	
	# Rebuild MultiMesh if rocks changed
	if rocks_changed or _multimesh_rock_ids.size() != visible_rock_ids.size():
		_rebuild_multimesh(rocks)

# Build rock mesh (returns ArrayMesh, doesn't create node)
func _build_rock_mesh(rock: Dictionary) -> ArrayMesh:
	# Get biome material
	var biome_id = rock.biome_id
	var material = rock_materials.get(biome_id, rock_materials.values()[0])
	
	# Build mesh from cells
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var colors = PackedColorArray()
	
	var cells = rock.cells
	var tall_cells = rock.tall
	var cell_size = 2.0  # CELL_SIZE
	
	var base_color = material.albedo_color
	var tall_color = base_color.lightened(0.15)
	
	for cell in cells:
		var dx = cell.dx
		var dz = cell.dy  # Note: cell uses dy for Z
		
		var cell_key = "%d,%d" % [int(dx), int(dz)]
		var is_tall = tall_cells.has(cell_key)
		
		# Short rocks: height 0.5, render below miasma (Y < 0.05)
		# Tall rocks: height 4.0, render above miasma (Y >= 0.05)
		var height = 4.0 if is_tall else 0.5
		var y_offset = 0.0 if is_tall else -0.25  # Tall rocks start at ground, short rocks below miasma
		var color = tall_color if is_tall else base_color
		
		# Create box for this cell
		var half_size = cell_size * 0.5
		var x = dx
		var z = dz
		var y_base = y_offset
		
		# Box vertices (bottom face, then top face)
		var v0 = Vector3(x - half_size, y_base, z - half_size)
		var v1 = Vector3(x + half_size, y_base, z - half_size)
		var v2 = Vector3(x + half_size, y_base, z + half_size)
		var v3 = Vector3(x - half_size, y_base, z + half_size)
		var v4 = Vector3(x - half_size, y_base + height, z - half_size)
		var v5 = Vector3(x + half_size, y_base + height, z - half_size)
		var v6 = Vector3(x + half_size, y_base + height, z + half_size)
		var v7 = Vector3(x - half_size, y_base + height, z + half_size)
		
		var base_idx = vertices.size()
		vertices.append_array([v0, v1, v2, v3, v4, v5, v6, v7])
		for i in range(8):
			colors.append(color)
		
		# Bottom face
		indices.append_array([base_idx + 0, base_idx + 2, base_idx + 1])
		indices.append_array([base_idx + 0, base_idx + 3, base_idx + 2])
		# Top face
		indices.append_array([base_idx + 4, base_idx + 5, base_idx + 6])
		indices.append_array([base_idx + 4, base_idx + 6, base_idx + 7])
		# Front face
		indices.append_array([base_idx + 0, base_idx + 1, base_idx + 5])
		indices.append_array([base_idx + 0, base_idx + 5, base_idx + 4])
		# Back face
		indices.append_array([base_idx + 3, base_idx + 7, base_idx + 6])
		indices.append_array([base_idx + 3, base_idx + 6, base_idx + 2])
		# Left face
		indices.append_array([base_idx + 0, base_idx + 4, base_idx + 7])
		indices.append_array([base_idx + 0, base_idx + 7, base_idx + 3])
		# Right face
		indices.append_array([base_idx + 1, base_idx + 2, base_idx + 6])
		indices.append_array([base_idx + 1, base_idx + 6, base_idx + 5])
	
	# Create mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, material)
	
	return array_mesh

# Rebuild MultiMeshInstance3D with all visible rocks
# NOTE: MultiMesh requires same mesh for all instances
# We'll use a template mesh approach - create a representative rock mesh
# This trades some visual detail for massive performance gain (1 draw call vs 100+)
func _rebuild_multimesh(rocks: Array):
	if not multimesh_instance or rocks.is_empty():
		if multimesh_instance:
			multimesh_instance.multimesh = null
		_multimesh_rock_ids.clear()
		return
	
	# Create template mesh (representative rock shape)
	# Use a simple box that represents an average rock
	var template_mesh = _create_template_rock_mesh()
	
	# Create MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = template_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D  # Must set BEFORE instance_count
	multimesh.instance_count = rocks.size()
	# color_format not needed - we don't use per-instance colors
	
	# Set transforms for each rock
	_multimesh_rock_ids.clear()
	
	for i in range(rocks.size()):
		var rock = rocks[i]
		_multimesh_rock_ids.append(rock.id)
		
		# Create transform (position only)
		var transform = Transform3D.IDENTITY
		transform.origin = Vector3(rock.x, 0, rock.z)
		multimesh.set_instance_transform(i, transform)
	
	multimesh_instance.multimesh = multimesh

# Create a template mesh for MultiMesh (simple representative rock)
func _create_template_rock_mesh() -> ArrayMesh:
	# Create a simple box that represents an average rock
	# This is a performance trade-off: less detail but 100x faster rendering
	var material = rock_materials.values()[0] if rock_materials.size() > 0 else null
	if not material:
		# Create default material if none exists
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.5, 0.5)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Simple box mesh (representative of average rock size)
	var size = 16.0  # Average rock envelope radius
	var height = 2.0  # Average height
	
	var vertices = PackedVector3Array([
		# Bottom face
		Vector3(-size, -0.25, -size),
		Vector3(size, -0.25, -size),
		Vector3(size, -0.25, size),
		Vector3(-size, -0.25, size),
		# Top face
		Vector3(-size, height, -size),
		Vector3(size, height, -size),
		Vector3(size, height, size),
		Vector3(-size, height, size)
	])
	
	var indices = PackedInt32Array([
		# Bottom
		0, 2, 1, 0, 3, 2,
		# Top
		4, 5, 6, 4, 6, 7,
		# Front
		0, 1, 5, 0, 5, 4,
		# Back
		3, 7, 6, 3, 6, 2,
		# Left
		0, 4, 7, 0, 7, 3,
		# Right
		1, 2, 6, 1, 6, 5
	])
	
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, material)
	
	return array_mesh

func _create_rock_collision(rock: Dictionary):
	# Create StaticBody3D for collision
	var static_body = StaticBody3D.new()
	add_child(static_body)
	rock_collision_bodies[rock.id] = static_body
	
	# Position at rock center
	static_body.global_position = Vector3(rock.x, 0, rock.z)
	
	# OPTIMIZATION: Use single ConcavePolygonShape3D (trimesh) instead of per-cell shapes
	# This gives exact collision with much better performance (1 shape vs 50-200 shapes)
	var cells = rock.cells
	var tall_cells = rock.tall
	var cell_size = 2.0  # CELL_SIZE
	
	# Build collision vertices and indices from cells (reuse mesh building logic)
	var collision_vertices = PackedVector3Array()
	var collision_indices = PackedInt32Array()
	
	for cell in cells:
		var dx = cell.dx
		var dz = cell.dy  # Note: cell uses dy for Z
		
		var cell_key = "%d,%d" % [int(dx), int(dz)]
		var is_tall = tall_cells.has(cell_key)
		var height = 4.0 if is_tall else 0.5
		var y_offset = 0.0 if is_tall else -0.25
		
		# Create box vertices for this cell (same as mesh)
		var half_size = cell_size * 0.5
		var x = dx
		var z = dz
		var y_base = y_offset
		
		var v0 = Vector3(x - half_size, y_base, z - half_size)
		var v1 = Vector3(x + half_size, y_base, z - half_size)
		var v2 = Vector3(x + half_size, y_base, z + half_size)
		var v3 = Vector3(x - half_size, y_base, z + half_size)
		var v4 = Vector3(x - half_size, y_base + height, z - half_size)
		var v5 = Vector3(x + half_size, y_base + height, z - half_size)
		var v6 = Vector3(x + half_size, y_base + height, z + half_size)
		var v7 = Vector3(x - half_size, y_base + height, z + half_size)
		
		var base_idx = collision_vertices.size()
		collision_vertices.append_array([v0, v1, v2, v3, v4, v5, v6, v7])
		
		# Box faces (12 triangles = 36 indices)
		# Bottom face
		collision_indices.append_array([base_idx + 0, base_idx + 2, base_idx + 1])
		collision_indices.append_array([base_idx + 0, base_idx + 3, base_idx + 2])
		# Top face
		collision_indices.append_array([base_idx + 4, base_idx + 5, base_idx + 6])
		collision_indices.append_array([base_idx + 4, base_idx + 6, base_idx + 7])
		# Front face
		collision_indices.append_array([base_idx + 0, base_idx + 1, base_idx + 5])
		collision_indices.append_array([base_idx + 0, base_idx + 5, base_idx + 4])
		# Back face
		collision_indices.append_array([base_idx + 3, base_idx + 7, base_idx + 6])
		collision_indices.append_array([base_idx + 3, base_idx + 6, base_idx + 2])
		# Left face
		collision_indices.append_array([base_idx + 0, base_idx + 4, base_idx + 7])
		collision_indices.append_array([base_idx + 0, base_idx + 7, base_idx + 3])
		# Right face
		collision_indices.append_array([base_idx + 1, base_idx + 2, base_idx + 6])
		collision_indices.append_array([base_idx + 1, base_idx + 6, base_idx + 5])
	
	# Create single collision shape using trimesh (exact collision, much faster)
	# Convert indexed vertices to flat triangle list (every 3 vertices = 1 triangle)
	var triangle_vertices = PackedVector3Array()
	for i in range(0, collision_indices.size(), 3):
		if i + 2 < collision_indices.size():
			triangle_vertices.append(collision_vertices[collision_indices[i]])
			triangle_vertices.append(collision_vertices[collision_indices[i + 1]])
			triangle_vertices.append(collision_vertices[collision_indices[i + 2]])
	
	var collision_shape = CollisionShape3D.new()
	var trimesh_shape = ConcavePolygonShape3D.new()
	trimesh_shape.set_faces(triangle_vertices)
	collision_shape.shape = trimesh_shape
	static_body.add_child(collision_shape)

func _on_rocks_changed():
	# Signal that rocks changed - let next frame's _process() handle the update
	# Don't call _update_rocks() here to avoid expensive viewport calculations
	# The bounds check in _process() will handle it efficiently
	pass
