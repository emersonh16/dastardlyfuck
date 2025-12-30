extends Node3D

# MountainRenderer - Renders mountains as blocky meshes
# Mountains block miasma (tall cells)

var mountain_manager: Node = null
var mountain_mesh_instances: Dictionary = {}  # mountain_id -> MeshInstance3D

# Materials per biome
var mountain_materials: Dictionary = {}

func _ready():
	mountain_manager = get_node_or_null("/root/MountainManager")
	if not mountain_manager:
		push_error("MountainRenderer: MountainManager not found!")
		return
	
	# Create materials for each biome
	_create_biome_materials()
	
	# Connect to mountain manager signals
	if mountain_manager.has_signal("mountains_changed"):
		mountain_manager.mountains_changed.connect(_on_mountains_changed)
	
	# Initial render
	call_deferred("_update_mountains")

func _create_biome_materials():
	var world_manager = get_node_or_null("/root/WorldManager")
	if not world_manager:
		return
	
	# Create materials for each biome type
	for biome_type in WorldManager.BiomeType.values():
		var material = StandardMaterial3D.new()
		
		# Get biome color and darken it for mountains
		var biome_color = world_manager.get_biome_color(biome_type)
		var mountain_color = biome_color.darkened(0.3)  # Darker than ground
		
		material.albedo_color = mountain_color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		
		mountain_materials[biome_type] = material

func _process(_delta):
	# Update mountains in viewport
	_update_mountains()

func _update_mountains():
	if not mountain_manager:
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
	
	# Get mountains in area
	var mountains = mountain_manager.get_mountains_in_area(min_x, max_x, min_z, max_z)
	
	# Track which mountains we've rendered
	var rendered_ids = {}
	
	# Render mountains
	for mountain in mountains:
		var mountain_id = mountain.id
		rendered_ids[mountain_id] = true
		
		# Create or update mesh instance
		if not mountain_mesh_instances.has(mountain_id):
			_create_mountain_mesh(mountain)
	
	# Remove mountains that are no longer visible
	var to_remove = []
	for mountain_id in mountain_mesh_instances:
		if not rendered_ids.has(mountain_id):
			to_remove.append(mountain_id)
	
	for mountain_id in to_remove:
		var mesh_instance = mountain_mesh_instances[mountain_id]
		if mesh_instance:
			mesh_instance.queue_free()
		mountain_mesh_instances.erase(mountain_id)

func _create_mountain_mesh(mountain: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	mountain_mesh_instances[mountain.id] = mesh_instance
	
	# Position
	mesh_instance.global_position = Vector3(mountain.x, 0, mountain.z)
	
	# Get biome material
	var biome_id = mountain.biome_id
	var material = mountain_materials.get(biome_id, mountain_materials.values()[0])
	
	# Build mesh from cells
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var colors = PackedColorArray()
	
	var cells = mountain.cells
	var tall_cells = mountain.tall
	var cell_size = 2.0  # CELL_SIZE
	
	var base_color = material.albedo_color
	var tall_color = base_color.lightened(0.2)
	
	for cell in cells:
		var dx = cell.dx
		var dz = cell.dy  # Note: cell uses dy for Z
		
		var is_tall = tall_cells.has("%d,%d" % [int(dx), int(dz)])
		var height = 8.0 if is_tall else 2.0
		var color = tall_color if is_tall else base_color
		
		# Create box for this cell
		var half_size = cell_size * 0.5
		var x = dx
		var z = dz
		var _y = height * 0.5
		
		# Box vertices (bottom face, then top face)
		var v0 = Vector3(x - half_size, 0, z - half_size)
		var v1 = Vector3(x + half_size, 0, z - half_size)
		var v2 = Vector3(x + half_size, 0, z + half_size)
		var v3 = Vector3(x - half_size, 0, z + half_size)
		var v4 = Vector3(x - half_size, height, z - half_size)
		var v5 = Vector3(x + half_size, height, z - half_size)
		var v6 = Vector3(x + half_size, height, z + half_size)
		var v7 = Vector3(x - half_size, height, z + half_size)
		
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

func _on_mountains_changed():
	# Re-render when mountains change
	_update_mountains()
