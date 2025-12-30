extends Node3D

# RockRenderer - Renders rocks
# Short rocks render below miasma (covered by miasma)
# Tall rocks render above miasma (on top of miasma)

var rock_manager: Node = null
var rock_mesh_instances: Dictionary = {}  # rock_id -> MeshInstance3D
var rock_collision_bodies: Dictionary = {}  # rock_id -> StaticBody3D

# Materials per biome
var rock_materials: Dictionary = {}

# Miasma height (rocks below this are covered, above this are on top)
# Miasma renders at Y=0.05 (sheet_thickness/2.0 where sheet_thickness=0.1)
const MIASMA_HEIGHT: float = 0.05

func _ready():
	rock_manager = get_node_or_null("/root/RockManager")
	if not rock_manager:
		push_error("RockRenderer: RockManager not found!")
		return
	
	# Create materials for each biome
	_create_biome_materials()
	
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
	# Update rocks in viewport
	_update_rocks()

func _update_rocks():
	if not rock_manager:
		return
	
	# Get viewport bounds
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
	
	# Get rocks in area
	var rocks = rock_manager.get_rocks_in_area(min_x, max_x, min_z, max_z)
	
	# Track which rocks we've rendered
	var rendered_ids = {}
	
	# Render rocks
	for rock in rocks:
		var rock_id = rock.id
		rendered_ids[rock_id] = true
		
		# Create or update mesh instance
		if not rock_mesh_instances.has(rock_id):
			_create_rock_mesh(rock)
	
	# Remove rocks that are no longer visible
	var to_remove = []
	for rock_id in rock_mesh_instances:
		if not rendered_ids.has(rock_id):
			to_remove.append(rock_id)
	
	for rock_id in to_remove:
		var mesh_instance = rock_mesh_instances.get(rock_id)
		if mesh_instance:
			mesh_instance.queue_free()
		rock_mesh_instances.erase(rock_id)
		
		var collision_body = rock_collision_bodies.get(rock_id)
		if collision_body:
			collision_body.queue_free()
		rock_collision_bodies.erase(rock_id)

func _create_rock_mesh(rock: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	rock_mesh_instances[rock.id] = mesh_instance
	
	# Position
	mesh_instance.global_position = Vector3(rock.x, 0, rock.z)
	
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
	
	mesh_instance.mesh = array_mesh
	
	# Create collision body for this rock
	_create_rock_collision(rock)

func _create_rock_collision(rock: Dictionary):
	# Create StaticBody3D for collision
	var static_body = StaticBody3D.new()
	add_child(static_body)
	rock_collision_bodies[rock.id] = static_body
	
	# Position at rock center
	static_body.global_position = Vector3(rock.x, 0, rock.z)
	
	# Create collision shapes for each cell
	var cells = rock.cells
	var tall_cells = rock.tall
	var cell_size = 2.0  # CELL_SIZE
	
	for cell in cells:
		var dx = cell.dx
		var dz = cell.dy  # Note: cell uses dy for Z
		
		# Create box collision shape for this cell
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		
		# Determine height based on whether it's a tall cell
		var cell_key = "%d,%d" % [int(dx), int(dz)]
		var is_tall = tall_cells.has(cell_key)
		var height = 4.0 if is_tall else 0.5
		var y_offset = 0.0 if is_tall else -0.25
		
		# Box size matches the cell
		box_shape.size = Vector3(cell_size, height, cell_size)
		collision_shape.shape = box_shape
		
		# Position relative to rock center
		collision_shape.position = Vector3(dx, y_offset + height * 0.5, dz)
		
		static_body.add_child(collision_shape)

func _on_rocks_changed():
	# Re-render when rocks change
	_update_rocks()
