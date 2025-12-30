extends Node3D

# MiasmaRenderer - Renders miasma blocks using MultiMeshInstance3D

# Constants (fallback if autoload not ready)
const MIASMA_TILE_SIZE_X = 2.0  # Even smaller blocks for more granular fog
const MIASMA_TILE_SIZE_Z = 2.0  # Even smaller blocks for more granular fog
const MIASMA_BLOCK_HEIGHT = 16.0  # Legacy - now using thin 2D sheet (0.1 thickness)

var miasma_manager: Node
var mesh_instance: MultiMeshInstance3D
var box_mesh: BoxMesh
var material: StandardMaterial3D

# Performance: throttle render updates
var _pending_update = false
var _update_timer = 0.0
const UPDATE_INTERVAL = 0.15  # Update mesh max ~6.7 times per second (reduced for smaller blocks)
var _initial_render_done = false  # Track if initial render has completed

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
	
	# Create flat box mesh for miasma blocks (2D sheet on ground)
	box_mesh = BoxMesh.new()
	var tile_x = miasma_manager.MIASMA_TILE_SIZE_X if miasma_manager else MIASMA_TILE_SIZE_X
	var tile_z = miasma_manager.MIASMA_TILE_SIZE_Z if miasma_manager else MIASMA_TILE_SIZE_Z
	var sheet_thickness = 0.1  # Thin 2D sheet (was block_h = 16.0)
	
	# Blocks are full size - completely touching with no gaps
	var edge_gap = 1.0  # Full size = no gaps
	box_mesh.size = Vector3(tile_x * edge_gap, sheet_thickness, tile_z * edge_gap)
	
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
	
	# Connect to manager signals FIRST (before manager initializes)
	# This ensures we catch the initial blocks_changed signal
	if miasma_manager:
		miasma_manager.blocks_changed.connect(_on_blocks_changed)
		
		# Wait for manager to initialize and add blocks
		# The manager uses call_deferred, so we need to wait
		for i in range(10):  # Wait up to 10 frames
			await get_tree().process_frame
			# Check if blocks have been added
			if miasma_manager.blocks.size() > 0:
				break
		
		# Wait one more frame to ensure signal has been processed
		await get_tree().process_frame
		
		# Final safety check - render if we have blocks but haven't rendered yet
		# This catches the case where signal fired before we connected
		if not _initial_render_done and miasma_manager.blocks.size() > 0:
			_initial_render_done = true
			_do_render_update()
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
	var sheet_thickness = 0.1  # Thin 2D sheet
	for tile_pos in test_blocks.keys():
		var world_x = tile_pos.x * MIASMA_TILE_SIZE_X
		var world_z = tile_pos.y * MIASMA_TILE_SIZE_Z
		var world_y = sheet_thickness / 2.0  # Flat on ground
		
		var block_transform = Transform3D(
			Basis(),
			Vector3(world_x, world_y, world_z)
		)
		
		mesh_instance.multimesh.set_instance_transform(index, block_transform)
		index += 1


func _on_blocks_changed():
	# If this is the first signal after initialization, render immediately (no throttle)
	if not _initial_render_done:
		_pending_update = false
		_update_timer = 0.0
		_do_render_update()
		return
	
	# Throttle updates for performance (after initial render)
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
	
	if blocks.size() == 0:
		mesh_instance.multimesh.instance_count = 0
		return
	
	# First pass: collect all valid blocks (that are actually present)
	# Use an array to ensure consistent ordering
	var valid_blocks = []
	var total_blocks = blocks.size()
	
	for tile_pos in blocks.keys():
		# Check if block is present (true)
		var block_value = blocks.get(tile_pos)
		if block_value == true:
			valid_blocks.append(tile_pos)
	
	var valid_count = valid_blocks.size()
	
	# Debug: Log block counts on first render
	if not _initial_render_done:
		print("MiasmaRenderer: Total blocks in dict: ", total_blocks, " Valid blocks: ", valid_count)
		if valid_count != total_blocks:
			print("WARNING: Some blocks are not valid! This might cause rendering issues.")
		_initial_render_done = true
	
	if valid_count == 0:
		mesh_instance.multimesh.instance_count = 0
		return
	
	# Set instance count to exact number of valid blocks
	# IMPORTANT: Reset to 0 first on initial render to force full refresh (fixes checkerboard)
	var multimesh = mesh_instance.multimesh
	if not _initial_render_done:
		# On first render, reset to 0 then set to full count to force complete initialization
		multimesh.instance_count = 0
	multimesh.instance_count = valid_count
	
	# Second pass: set transforms for all valid blocks
	var tile_x = miasma_manager.MIASMA_TILE_SIZE_X if miasma_manager else MIASMA_TILE_SIZE_X
	var tile_z = miasma_manager.MIASMA_TILE_SIZE_Z if miasma_manager else MIASMA_TILE_SIZE_Z
	var sheet_thickness = 0.1  # Thin 2D sheet
	
	# Set all transforms - ensure every instance gets a valid transform
	for index in range(valid_count):
		var tile_pos = valid_blocks[index]
		
		# Convert tile position to world position (2D sheet on ground)
		var world_x = tile_pos.x * tile_x
		var world_z = tile_pos.y * tile_z
		var world_y = sheet_thickness / 2.0  # Flat on ground (slightly above to avoid z-fighting)
		
		var block_transform = Transform3D(
			Basis(),
			Vector3(world_x, world_y, world_z)
		)
		
		multimesh.set_instance_transform(index, block_transform)
	
	# Ensure mesh instance is visible
	mesh_instance.visible = true
	
	# Debug: Verify we set all transforms
	if not _initial_render_done:
		print("MiasmaRenderer: Set ", valid_count, " transforms in multimesh (instance_count: ", multimesh.instance_count, ")")
	# Removed debug prints for performance
