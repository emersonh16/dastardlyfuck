extends Node3D

# MiasmaRenderer - Renders miasma as a 2D sheet with holes (inverse model)
# Inspired by old 2D top-down "plain mode" - full sheet with holes cut out

var miasma_manager: Node
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

# Performance: throttle render updates
var _pending_update = false
var _update_timer = 0.0
const UPDATE_INTERVAL = 0.1  # Update mesh max 10 times per second
var _initial_render_done = false

func _ready():
	await get_tree().process_frame
	
	# Find MiasmaManager
	miasma_manager = get_node_or_null("/root/MiasmaManager")
	if not miasma_manager:
		push_warning("MiasmaManager autoload not found!")
		return
	
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
	
	# Wait for manager to initialize
	for i in range(5):
		await get_tree().process_frame
		if miasma_manager.viewport_tiles_x > 0:
			break
	
	# Initial render
	_do_render_update()

func _on_cleared_changed():
	# Throttle updates
	_pending_update = true
	# First update renders immediately
	if not _initial_render_done:
		_initial_render_done = true
		_pending_update = false
		_update_timer = 0.0
		_do_render_update()

func _process(delta):
	# Always update position to follow player smoothly (no stuttering)
	var player_pos = miasma_manager.player_position
	var player_ground = Vector3(player_pos.x, 0, player_pos.z)
	global_position = player_ground
	
	# Throttle mesh rebuilds
	if _pending_update:
		_update_timer += delta
		if _update_timer >= UPDATE_INTERVAL:
			_update_timer = 0.0
			_pending_update = false
			_do_render_update()

func _do_render_update():
	if not miasma_manager or not mesh_instance:
		return
	
	# Get viewport info
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_3d()
	if not camera:
		return
	
	# Get player position (sheet follows player, not camera)
	var player_pos = miasma_manager.player_position
	var player_ground = Vector3(player_pos.x, 0, player_pos.z)
	
	# Calculate viewport world size from camera
	var world_width = camera.size
	var pixel_size = viewport.get_visible_rect().size
	var world_height = camera.size * (pixel_size.y / pixel_size.x)
	
	var tile_size = miasma_manager.get_tile_size()
	
	# Sheet dimensions: simple rectangle covering viewport (no rotation, no isometric factor)
	# This is a flat rectangle on the ground
	var half_size_x = world_width * 0.5
	var half_size_z = world_height * 0.5
	
	# Calculate how many tiles we need to cover the viewport
	var tiles_x = int(world_width / tile_size) + 2  # Extra padding
	var tiles_z = int(world_height / tile_size) + 2
	
	# Build mesh: continuous sheet with holes (tiles that are cleared)
	# Build a rectangle centered on player, covering viewport
	# For each tile, check if it's cleared in WORLD space
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var sheet_thickness = 0.1
	var y_pos = sheet_thickness / 2.0
	
	var vertex_index = 0
	var tiles_rendered = 0
	
	# Build mesh tile by tile, skipping cleared tiles
	# Build a rectangle centered on player, covering viewport
	# For each tile in the rectangle, check if it's cleared in WORLD space
	
	var half_tiles_x = tiles_x / 2
	var half_tiles_z = tiles_z / 2
	
	for tile_x in range(-half_tiles_x, half_tiles_x + 1):
		for tile_z in range(-half_tiles_z, half_tiles_z + 1):
			# Calculate world position of this tile (relative to player)
			var world_x = player_ground.x + (tile_x * tile_size)
			var world_z = player_ground.z + (tile_z * tile_size)
			
			# Convert to tile coordinates in world space (must match clear_area calculation)
			var world_tile_x = int(world_x / tile_size)
			var world_tile_z = int(world_z / tile_size)
			var world_tile_pos = Vector2i(world_tile_x, world_tile_z)
			
			# Check if this world position is cleared (holes stay in world space)
			if miasma_manager.is_cleared(world_tile_x, world_tile_z):
				continue  # Skip cleared tiles (holes)
			
			# Add tile quad (relative to player position, so mesh is centered on player)
			var local_x = tile_x * tile_size
			var local_z = tile_z * tile_size
			
			# Tile quad vertices (local to player position)
			var v0 = Vector3(local_x, y_pos, local_z)
			var v1 = Vector3(local_x + tile_size, y_pos, local_z)
			var v2 = Vector3(local_x + tile_size, y_pos, local_z + tile_size)
			var v3 = Vector3(local_x, y_pos, local_z + tile_size)
			
			var base = vertex_index
			vertices.append(v0)
			vertices.append(v1)
			vertices.append(v2)
			vertices.append(v3)
			
			# Two triangles per tile
			indices.append(base + 0)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 0)
			indices.append(base + 2)
			indices.append(base + 3)
			
			vertex_index += 4
			tiles_rendered += 1
	
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
	
	if not _initial_render_done:
		print("MiasmaRenderer: Rendered ", tiles_rendered, " fog tiles (sheet follows player at: ", player_ground, ")")
