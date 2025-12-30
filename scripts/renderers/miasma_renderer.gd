extends Node3D

# MiasmaRenderer - Renders miasma blocks using MultiMeshInstance3D

# Constants (fallback if autoload not ready)
const MIASMA_TILE_SIZE_X = 8.0
const MIASMA_TILE_SIZE_Z = 8.0  # Changed to 8.0 for square appearance
const MIASMA_BLOCK_HEIGHT = 16.0

var miasma_manager: Node
var mesh_instance: MultiMeshInstance3D
var box_mesh: BoxMesh
var material: StandardMaterial3D

# Performance: throttle render updates
var _pending_update = false
var _update_timer = 0.0
const UPDATE_INTERVAL = 0.05  # Update mesh max 20 times per second

func _ready():
	# Wait for autoload to be ready
	await get_tree().process_frame
	
	# Try accessing autoload - check root children first
	var root = get_tree().root
	print("DEBUG: Root has ", root.get_child_count(), " children")
	
	# Try multiple methods to find autoload
	miasma_manager = root.get_node_or_null("MiasmaManager")
	if not miasma_manager:
		miasma_manager = get_node_or_null("/root/MiasmaManager")
	
	if not miasma_manager:
		push_warning("MiasmaManager autoload not found! Check Project Settings > Autoload.")
		print("DEBUG: Tried /root/MiasmaManager - not found")
		print("DEBUG: Root children: ", root.get_children())
		# Continue with fallback constants - scene should still work
	
	# Create MultiMeshInstance3D
	mesh_instance = MultiMeshInstance3D.new()
	add_child(mesh_instance)
	
	# Create box mesh for miasma blocks
	box_mesh = BoxMesh.new()
	var tile_x = miasma_manager.MIASMA_TILE_SIZE_X if miasma_manager else MIASMA_TILE_SIZE_X
	var tile_z = miasma_manager.MIASMA_TILE_SIZE_Z if miasma_manager else MIASMA_TILE_SIZE_Z
	var block_h = miasma_manager.MIASMA_BLOCK_HEIGHT if miasma_manager else MIASMA_BLOCK_HEIGHT
	
	# Make blocks smaller to show edges for debugging (0.9x size = 10% gap)
	# This creates visible dark gaps between blocks
	var edge_gap = 0.9  # 10% smaller = more visible edges
	box_mesh.size = Vector3(tile_x * edge_gap, block_h, tile_z * edge_gap)
	
	# Create purple material - gaps between blocks will show as dark edges
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.2, 0.8, 1.0)  # Purple
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Blocks are 10% smaller - gaps will show dark background/edges
	
	# Create MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.mesh = box_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	
	mesh_instance.multimesh = multimesh
	mesh_instance.material_override = material
	
	# Connect to manager signals
	if miasma_manager:
		miasma_manager.blocks_changed.connect(_on_blocks_changed)
		# Wait a frame for manager to initialize
		await get_tree().process_frame
		_do_render_update()  # Initial render (bypass throttle)
	else:
		# Don't error - render test blocks manually
		print("WARNING: MiasmaManager not found - rendering test blocks")
		_render_test_blocks()

func _render_test_blocks():
	# Create test blocks if manager not found
	var test_blocks = {}
	for x in range(-50, 50):
		for y in range(-50, 50):
			test_blocks[Vector3i(x, y, 0)] = true
	
	# Render them
	if not mesh_instance:
		return
	
	mesh_instance.multimesh.instance_count = test_blocks.size()
	var index = 0
	for tile_pos in test_blocks.keys():
		var world_x = tile_pos.x * MIASMA_TILE_SIZE_X
		var world_z = tile_pos.y * MIASMA_TILE_SIZE_Z
		var world_y = MIASMA_BLOCK_HEIGHT / 2.0
		
		var block_transform = Transform3D(
			Basis(),
			Vector3(world_x, world_y, world_z)
		)
		
		mesh_instance.multimesh.set_instance_transform(index, block_transform)
		index += 1

func _on_blocks_changed():
	# Throttle updates for performance
	_pending_update = true

func _process(delta):
	if _pending_update:
		_update_timer += delta
		if _update_timer >= UPDATE_INTERVAL:
			_update_timer = 0.0
			_pending_update = false
			_do_render_update()

func _do_render_update():
	if not miasma_manager or not mesh_instance:
		return
	
	var blocks = miasma_manager.get_all_blocks()
	var block_count = blocks.size()
	
	if block_count == 0:
		mesh_instance.multimesh.instance_count = 0
		return
	
	# Resize multimesh if needed
	if mesh_instance.multimesh.instance_count != block_count:
		mesh_instance.multimesh.instance_count = block_count
	
	# Set transforms for each block
	var index = 0
	for tile_pos in blocks.keys():
		if not blocks[tile_pos]:  # Skip absent blocks
			continue
		
		# Convert tile position to world position
		var tile_x = miasma_manager.MIASMA_TILE_SIZE_X if miasma_manager else MIASMA_TILE_SIZE_X
		var tile_z = miasma_manager.MIASMA_TILE_SIZE_Z if miasma_manager else MIASMA_TILE_SIZE_Z
		var block_h = miasma_manager.MIASMA_BLOCK_HEIGHT if miasma_manager else MIASMA_BLOCK_HEIGHT
		
		var world_x = tile_pos.x * tile_x
		var world_z = tile_pos.y * tile_z
		var world_y = block_h / 2.0  # Center block on ground
		
		# DIAGNOSTIC: Print first 5 blocks
		if index < 5:
			print("Block ", index, ": tile_pos=", tile_pos, " world_pos=(", world_x, ", ", world_z, ")")
		
		var block_transform = Transform3D(
			Basis(),
			Vector3(world_x, world_y, world_z)
		)
		
		mesh_instance.multimesh.set_instance_transform(index, block_transform)
		index += 1
		
	# Update instance count to actual rendered blocks
	mesh_instance.multimesh.instance_count = index
	# Removed debug prints for performance
