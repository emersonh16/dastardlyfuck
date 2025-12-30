extends Node3D

# GroundRenderer - Renders ground tiles as tilemap (green with brown borders)
# Tiles snap to 64x64 grid, camera moves smoothly

const GROUND_TILE_SIZE = 64.0  # World units (64x64 square from top-down)
const GROUND_TILE_HEIGHT = 0.1  # Very thin ground plane
const BORDER_WIDTH = 2.0  # Brown border width (visible at isometric view)

var ground_mesh_instance: MeshInstance3D = null
var green_material: StandardMaterial3D = null
var brown_material: StandardMaterial3D = null

# Track player for smooth following
var miasma_manager: Node = null
var world_manager: Node = null
var _last_visible_bounds: Dictionary = {}

func _ready():
	await get_tree().process_frame
	
	# Get managers
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	world_manager = get_node_or_null("/root/WorldManager")
	
	# Create mesh instance
	ground_mesh_instance = MeshInstance3D.new()
	add_child(ground_mesh_instance)
	
	# Create materials (green centers, brown borders)
	green_material = StandardMaterial3D.new()
	green_material.albedo_color = Color(0.3, 0.8, 0.4, 1.0)  # Green
	green_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	green_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	brown_material = StandardMaterial3D.new()
	brown_material.albedo_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown
	brown_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brown_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	brown_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Initial render
	call_deferred("_update_ground_tiles")

func _process(_delta):
	# Update every frame for smooth movement (tiles snap to grid, but update smoothly)
	_update_ground_tiles()

func _update_ground_tiles():
	if not ground_mesh_instance:
		return
	
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return
	
	# Get player position (ground follows player smoothly)
	var player_pos = Vector3.ZERO
	if miasma_manager:
		player_pos = miasma_manager.player_position
	var player_ground = Vector3(player_pos.x, 0, player_pos.z)
	
	# Calculate visible world bounds (same as miasma renderer)
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
	
	# Calculate bounds
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	
	if world_corners.size() < 3:
		# Fallback
		var world_width = camera.size
		var pixel_size = viewport.get_visible_rect().size
		var world_height = camera.size * (pixel_size.y / pixel_size.x)
		var coverage = max(world_width, world_height) * 1.5
		min_x = player_ground.x - coverage * 0.5
		max_x = player_ground.x + coverage * 0.5
		min_z = player_ground.z - coverage * 0.5
		max_z = player_ground.z + coverage * 0.5
	else:
		min_x = world_corners[0].x
		max_x = world_corners[0].x
		min_z = world_corners[0].z
		max_z = world_corners[0].z
		for corner in world_corners:
			min_x = min(min_x, corner.x)
			max_x = max(max_x, corner.x)
			min_z = min(min_z, corner.z)
			max_z = max(max_z, corner.z)
		var padding = GROUND_TILE_SIZE
		min_x -= padding
		max_x += padding
		min_z -= padding
		max_z += padding
	
	# Check if bounds changed (only rebuild if needed)
	var current_bounds = {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}
	if current_bounds.hash() == _last_visible_bounds.hash():
		# Just update position, don't rebuild mesh
		global_position = player_ground
		return
	
	_last_visible_bounds = current_bounds
	
	# Calculate tile bounds (snap to grid)
	var min_tile_x = int(min_x / GROUND_TILE_SIZE)
	var max_tile_x = int(max_x / GROUND_TILE_SIZE) + 1
	var min_tile_z = int(min_z / GROUND_TILE_SIZE)
	var max_tile_z = int(max_z / GROUND_TILE_SIZE) + 1
	
	# Build mesh: tiles with borders (multiple surfaces: biome-colored centers, brown borders)
	# We'll use a single material per tile center (or group by color for efficiency)
	var center_vertices = PackedVector3Array()
	var center_indices = PackedInt32Array()
	var center_colors = PackedColorArray()  # Per-vertex colors for centers
	var brown_vertices = PackedVector3Array()
	var brown_indices = PackedInt32Array()
	var y_pos = -1.0  # Below miasma
	var center_vertex_index = 0
	var brown_vertex_index = 0
	
	# Build each tile: biome-colored center with brown border
	for tile_x in range(min_tile_x, max_tile_x + 1):
		for tile_z in range(min_tile_z, max_tile_z + 1):
			# Calculate world position (snapped to grid)
			var world_x = tile_x * GROUND_TILE_SIZE
			var world_z = tile_z * GROUND_TILE_SIZE
			var tile_world_pos = Vector3(world_x, 0, world_z)
			
			# Get biome color for this tile
			var tile_color = Color(0.3, 0.8, 0.4)  # Default green fallback
			if world_manager:
				tile_color = world_manager.get_ground_color_at(tile_world_pos)
			
			# Position relative to player (for smooth following)
			var local_x = world_x - player_ground.x
			var local_z = world_z - player_ground.z
			
			# Create tile: biome-colored center with brown border
			# Center (biome color) - slightly smaller to show border
			var center_size = GROUND_TILE_SIZE - BORDER_WIDTH * 2
			var half_center = center_size * 0.5
			var half_tile = GROUND_TILE_SIZE * 0.5
			
			# Center quad vertices (biome color)
			var v0 = Vector3(local_x - half_center, y_pos, local_z - half_center)
			var v1 = Vector3(local_x + half_center, y_pos, local_z - half_center)
			var v2 = Vector3(local_x + half_center, y_pos, local_z + half_center)
			var v3 = Vector3(local_x - half_center, y_pos, local_z + half_center)
			
			var base = center_vertex_index
			center_vertices.append(v0)
			center_vertices.append(v1)
			center_vertices.append(v2)
			center_vertices.append(v3)
			
			# Add color for each vertex (same color for all vertices of this tile)
			center_colors.append(tile_color)
			center_colors.append(tile_color)
			center_colors.append(tile_color)
			center_colors.append(tile_color)
			
			center_indices.append(base + 0)
			center_indices.append(base + 1)
			center_indices.append(base + 2)
			center_indices.append(base + 0)
			center_indices.append(base + 2)
			center_indices.append(base + 3)
			
			center_vertex_index += 4
			
			# Border (brown) - four edge quads
			# Top border
			var bt0 = Vector3(local_x - half_tile, y_pos + 0.001, local_z - half_tile)
			var bt1 = Vector3(local_x + half_tile, y_pos + 0.001, local_z - half_tile)
			var bt2 = Vector3(local_x + half_center, y_pos + 0.001, local_z - half_center)
			var bt3 = Vector3(local_x - half_center, y_pos + 0.001, local_z - half_center)
			
			var bbase = brown_vertex_index
			brown_vertices.append(bt0)
			brown_vertices.append(bt1)
			brown_vertices.append(bt2)
			brown_vertices.append(bt3)
			
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 1)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 3)
			brown_vertex_index += 4
			
			# Right border
			var br0 = Vector3(local_x + half_center, y_pos + 0.001, local_z - half_center)
			var br1 = Vector3(local_x + half_tile, y_pos + 0.001, local_z - half_tile)
			var br2 = Vector3(local_x + half_tile, y_pos + 0.001, local_z + half_tile)
			var br3 = Vector3(local_x + half_center, y_pos + 0.001, local_z + half_center)
			
			bbase = brown_vertex_index
			brown_vertices.append(br0)
			brown_vertices.append(br1)
			brown_vertices.append(br2)
			brown_vertices.append(br3)
			
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 1)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 3)
			brown_vertex_index += 4
			
			# Bottom border
			var bb0 = Vector3(local_x - half_center, y_pos + 0.001, local_z + half_center)
			var bb1 = Vector3(local_x + half_center, y_pos + 0.001, local_z + half_center)
			var bb2 = Vector3(local_x + half_tile, y_pos + 0.001, local_z + half_tile)
			var bb3 = Vector3(local_x - half_tile, y_pos + 0.001, local_z + half_tile)
			
			bbase = brown_vertex_index
			brown_vertices.append(bb0)
			brown_vertices.append(bb1)
			brown_vertices.append(bb2)
			brown_vertices.append(bb3)
			
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 1)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 3)
			brown_vertex_index += 4
			
			# Left border
			var bl0 = Vector3(local_x - half_tile, y_pos + 0.001, local_z - half_tile)
			var bl1 = Vector3(local_x - half_center, y_pos + 0.001, local_z - half_center)
			var bl2 = Vector3(local_x - half_center, y_pos + 0.001, local_z + half_center)
			var bl3 = Vector3(local_x - half_tile, y_pos + 0.001, local_z + half_tile)
			
			bbase = brown_vertex_index
			brown_vertices.append(bl0)
			brown_vertices.append(bl1)
			brown_vertices.append(bl2)
			brown_vertices.append(bl3)
			
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 1)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 0)
			brown_indices.append(bbase + 2)
			brown_indices.append(bbase + 3)
			brown_vertex_index += 4
	
	# Create array mesh with two surfaces
	var array_mesh = ArrayMesh.new()
	
	# Surface 0: Biome-colored centers (using vertex colors)
	if center_vertices.size() > 0:
		var center_arrays = []
		center_arrays.resize(Mesh.ARRAY_MAX)
		center_arrays[Mesh.ARRAY_VERTEX] = center_vertices
		center_arrays[Mesh.ARRAY_INDEX] = center_indices
		center_arrays[Mesh.ARRAY_COLOR] = center_colors
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, center_arrays)
		# Use a material that supports vertex colors
		var center_material = StandardMaterial3D.new()
		center_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		center_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		center_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		center_material.vertex_color_use_as_albedo = true  # Use vertex colors
		array_mesh.surface_set_material(0, center_material)
	
	# Surface 1: Brown borders
	if brown_vertices.size() > 0:
		var brown_arrays = []
		brown_arrays.resize(Mesh.ARRAY_MAX)
		brown_arrays[Mesh.ARRAY_VERTEX] = brown_vertices
		brown_arrays[Mesh.ARRAY_INDEX] = brown_indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, brown_arrays)
		array_mesh.surface_set_material(1, brown_material)
	
	ground_mesh_instance.mesh = array_mesh
	
	# Position at player (smooth following)
	global_position = player_ground
