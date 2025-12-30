extends Node3D

# MiasmaRenderer - Renders miasma as a 2D sheet with holes (inverse model)
# Inspired by old 2D top-down "plain mode" - full sheet with holes cut out

var miasma_manager: Node
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

# Track visible bounds to only rebuild when needed
var _last_visible_bounds: Dictionary = {}
var _last_wind_offset: Vector2 = Vector2.ZERO
var _last_player_tile: Vector2i = Vector2i(0, 0)
var wind_manager: Node = null
const WIND_REBUILD_THRESHOLD: float = 1.0  # Rebuild when wind moves > 1 tile (was 0.1)
const PLAYER_TILE_THRESHOLD: int = 2  # Rebuild when player moves > 2 tiles

func _ready():
	await get_tree().process_frame
	
	# Find MiasmaManager
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	if not miasma_manager:
		push_warning("MiasmaManager autoload not found!")
		return
	
	# Find WindManager to track wind changes
	wind_manager = get_node_or_null("/root/WindManager")
	if wind_manager:
		wind_manager.wind_changed.connect(_on_wind_changed)
	
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Create material (purple fog, like old code)
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.2, 0.8, 1.0)  # Purple
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.flags_transparent = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	mesh_instance.material_override = material
	
	# Connect to manager signals
	miasma_manager.cleared_changed.connect(_on_cleared_changed)
	
	# Wait for manager and camera to initialize
	for i in range(10):
		await get_tree().process_frame
		var camera = get_viewport().get_camera_3d()
		if miasma_manager.viewport_tiles_x > 0 and camera:
			# Wait one more frame to ensure camera is fully set up
			await get_tree().process_frame
			break
	
	# Initial render
	_do_render_update()

func _on_cleared_changed():
	# Trigger immediate update when miasma changes
	_do_render_update()

func _on_wind_changed(_velocity: Vector2):
	# Wind changed - need to rebuild mesh to show advection
	_do_render_update()

func _process(_delta):
	# Update every frame for smooth movement (tiles snap to grid, but update smoothly)
	_do_render_update()

func _do_render_update():
	if not miasma_manager or not mesh_instance:
		return
	
	# Get player position (sheet follows player, not camera)
	var player_pos = miasma_manager.player_position
	var player_ground = Vector3(player_pos.x, 0, player_pos.z)
	
	# Quick early exit checks before expensive calculations
	var tile_size = miasma_manager.get_tile_size()
	var current_wind_offset = Vector2(miasma_manager.wind_offset_x, miasma_manager.wind_offset_z)
	var wind_moved = current_wind_offset.distance_to(_last_wind_offset) >= WIND_REBUILD_THRESHOLD
	
	# Check if player moved significantly (tile-based check is fast)
	var player_tile_x = int(player_pos.x / tile_size)
	var player_tile_z = int(player_pos.z / tile_size)
	var current_player_tile = Vector2i(player_tile_x, player_tile_z)
	var player_tile_delta = current_player_tile - _last_player_tile
	var player_moved = abs(player_tile_delta.x) >= PLAYER_TILE_THRESHOLD or abs(player_tile_delta.y) >= PLAYER_TILE_THRESHOLD
	
	# Early exit: if nothing significant changed, just update position
	# (Wind advection is smooth, so small movements don't need mesh rebuild)
	if not wind_moved and not player_moved:
		global_position = player_ground
		return
	
	# Get viewport info (only do expensive calculations if we need to rebuild)
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return
	
	# Calculate visible world bounds by projecting screen corners to ground plane
	# This accounts for isometric camera rotation - we only render what's actually visible
	var screen_size = viewport.get_visible_rect().size
	var corners = [
		Vector2(0, 0),  # Top-left
		Vector2(screen_size.x, 0),  # Top-right
		Vector2(screen_size.x, screen_size.y),  # Bottom-right
		Vector2(0, screen_size.y)  # Bottom-left
	]
	
	var world_corners = []
	for corner in corners:
		var from = camera.project_ray_origin(corner)
		var dir = camera.project_ray_normal(corner)
		# Intersect with ground plane (Y=0)
		if abs(dir.y) > 0.001:
			var t = -from.y / dir.y
			if t > 0:
				var world_pos = from + dir * t
				world_corners.append(Vector3(world_pos.x, 0, world_pos.z))
	
	# Find bounding box of visible world area
	var min_x: float
	var max_x: float
	var min_z: float
	var max_z: float
	
	# If corner projection failed, use fallback based on camera size
	if world_corners.size() < 3:
		# Fallback: use camera size to estimate visible area
		var world_width = camera.size
		var pixel_size = viewport.get_visible_rect().size
		var world_height = camera.size * (pixel_size.y / pixel_size.x)
		
		# Account for isometric view - need larger coverage
		var coverage = max(world_width, world_height) * 1.5
		
		min_x = player_ground.x - coverage * 0.5
		max_x = player_ground.x + coverage * 0.5
		min_z = player_ground.z - coverage * 0.5
		max_z = player_ground.z + coverage * 0.5
	else:
		# Use projected corners
		min_x = world_corners[0].x
		max_x = world_corners[0].x
		min_z = world_corners[0].z
		max_z = world_corners[0].z
		
		for corner in world_corners:
			min_x = min(min_x, corner.x)
			max_x = max(max_x, corner.x)
			min_z = min(min_z, corner.z)
			max_z = max(max_z, corner.z)
		
		# Add padding
		var padding = tile_size * 2
		min_x -= padding
		max_x += padding
		min_z -= padding
		max_z += padding
	
	# Check if bounds changed (we already checked wind/player movement above)
	var current_bounds = {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}
	var bounds_changed = current_bounds.hash() != _last_visible_bounds.hash()
	
	# Update tracking variables
	_last_visible_bounds = current_bounds
	_last_wind_offset = current_wind_offset
	_last_player_tile = current_player_tile
	
	# Calculate tile bounds
	var min_tile_x = int(min_x / tile_size)
	var max_tile_x = int(max_x / tile_size) + 1
	var min_tile_z = int(min_z / tile_size)
	var max_tile_z = int(max_z / tile_size) + 1
	
	# OPTIMIZATION: Get all cleared tiles in area ONCE (batch lookup)
	# This avoids thousands of individual dictionary lookups
	var half_x = (max_tile_x - min_tile_x) / 2.0
	var half_z = (max_tile_z - min_tile_z) / 2.0
	var center_tile_x = (min_tile_x + max_tile_x) / 2.0
	var center_tile_z = (min_tile_z + max_tile_z) / 2.0
	var cleared_in_area = miasma_manager.get_cleared_tiles_in_area(center_tile_x, center_tile_z, half_x + 1, half_z + 1)
	
	# Convert to Set for O(1) lookup (much faster than calling is_cleared() thousands of times)
	var cleared_set = {}
	for tile_pos in cleared_in_area.keys():
		cleared_set[tile_pos] = true
	
	# Build mesh: continuous sheet with holes (tiles that are cleared)
	# Build a rectangle centered on player, covering viewport
	# For each tile, check if it's cleared in WORLD space
	
	# Pre-allocate arrays with estimated size (reduces reallocations)
	var tile_count = (max_tile_x - min_tile_x + 1) * (max_tile_z - min_tile_z + 1)
	var estimated_vertices = tile_count * 4  # 4 vertices per tile
	var estimated_indices = tile_count * 6  # 6 indices per tile (2 triangles)
	
	var vertices = PackedVector3Array()
	vertices.resize(estimated_vertices)
	var indices = PackedInt32Array()
	indices.resize(estimated_indices)
	
	var sheet_thickness = 0.1
	var y_pos = sheet_thickness / 2.0
	
	var vertex_index = 0
	var index_index = 0
	
	# Build mesh tile by tile, skipping cleared tiles
	# Only render tiles that are actually visible on screen (within projected bounds)
	# For each visible tile, check if it's cleared in WORLD space (using fast Set lookup)
	
	for world_tile_x in range(min_tile_x, max_tile_x + 1):
		for world_tile_z in range(min_tile_z, max_tile_z + 1):
			# Fast O(1) lookup using Set instead of calling is_cleared()
			var tile_pos = Vector2i(world_tile_x, world_tile_z)
			if cleared_set.has(tile_pos):
				continue  # Skip cleared tiles (holes)
			
			# Calculate world position of this tile
			var world_x = world_tile_x * tile_size
			var world_z = world_tile_z * tile_size
			
			# Tile quad vertices (relative to player position, so mesh is centered on player)
			var local_x = world_x - player_ground.x
			var local_z = world_z - player_ground.z
			
			# Tile quad vertices (local to player position)
			var v0 = Vector3(local_x, y_pos, local_z)
			var v1 = Vector3(local_x + tile_size, y_pos, local_z)
			var v2 = Vector3(local_x + tile_size, y_pos, local_z + tile_size)
			var v3 = Vector3(local_x, y_pos, local_z + tile_size)
			
			var base = vertex_index
			vertices[vertex_index + 0] = v0
			vertices[vertex_index + 1] = v1
			vertices[vertex_index + 2] = v2
			vertices[vertex_index + 3] = v3
			
			# Two triangles per tile
			indices[index_index + 0] = base + 0
			indices[index_index + 1] = base + 1
			indices[index_index + 2] = base + 2
			indices[index_index + 3] = base + 0
			indices[index_index + 4] = base + 2
			indices[index_index + 5] = base + 3
			
			vertex_index += 4
			index_index += 6
	
	# Resize arrays to actual size (remove unused pre-allocated space)
	vertices.resize(vertex_index)
	indices.resize(index_index)
	
	# Create mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	if vertices.size() > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	mesh_instance.mesh = array_mesh
	
	# Position at player position (ground level) - sheet follows player
	global_position = player_ground
