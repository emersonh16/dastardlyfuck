extends Node3D

# GroundRenderer - Renders ground tiles (green squares with borders)
# Foundation for the 12-biome seeded world

# Ground tile size (matches miasma grid for alignment)
const GROUND_TILE_SIZE = 64.0  # World units (from design doc: 64x32 for isometric)
const GROUND_TILE_HEIGHT = 0.1  # Very thin ground plane

var ground_mesh_instance: MultiMeshInstance3D = null
var ground_mesh: QuadMesh = null
var ground_material: StandardMaterial3D = null

# Viewport + buffer size (in tiles)
var viewport_tiles_x: int = 0
var viewport_tiles_z: int = 0
var buffer_tiles: int = 2  # Small buffer around viewport

func _ready():
	# Get viewport size
	var viewport = get_viewport()
	if viewport:
		var size = viewport.get_visible_rect().size
		print("GroundRenderer: Viewport size: ", size)
		_create_ground(size.x, size.y)
	else:
		push_error("GroundRenderer: No viewport found!")

func _create_ground(viewport_width: float, viewport_height: float):
	# Calculate viewport size in tiles
	# For isometric, we need to account for the camera's orthographic size
	# The viewport size is in pixels, but we need world units
	# Camera size is 200.0, so viewport covers about 200 world units
	var camera = get_viewport().get_camera_3d()
	var world_width = 200.0  # Default camera size
	var world_height = 200.0
	
	if camera and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		world_width = camera.size
		world_height = camera.size * (viewport_height / viewport_width)
	
	# Make ground cover a larger area to ensure visibility
	viewport_tiles_x = int(world_width / GROUND_TILE_SIZE) + buffer_tiles * 4
	viewport_tiles_z = int(world_height / GROUND_TILE_SIZE) + buffer_tiles * 4
	
	print("GroundRenderer: World size: ", world_width, "x", world_height)
	print("GroundRenderer: Tiles: ", viewport_tiles_x, "x", viewport_tiles_z)
	
	# Create ground tile mesh (square)
	# For isometric, we want square tiles that appear square in isometric view
	ground_mesh = QuadMesh.new()
	# Make tiles full size (no gap) for now to ensure visibility
	ground_mesh.size = Vector2(GROUND_TILE_SIZE, GROUND_TILE_SIZE)
	
	# Create material (bright green for visibility)
	ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.8, 0.4, 1.0)  # Bright green
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show from both sides
	
	# Create MultiMeshInstance3D
	ground_mesh_instance = MultiMeshInstance3D.new()
	var multimesh = MultiMesh.new()
	multimesh.mesh = ground_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	
	ground_mesh_instance.multimesh = multimesh
	ground_mesh_instance.material_override = ground_material
	
	add_child(ground_mesh_instance)
	
	print("GroundRenderer: Created ground mesh instance")
	
	# Fill area with ground tiles
	call_deferred("_fill_ground_tiles")

func _fill_ground_tiles():
	# Fill viewport area with ground tiles
	var half_x = viewport_tiles_x / 2.0
	var half_z = viewport_tiles_z / 2.0
	
	var tile_count = 0
	var tiles_to_render = []
	
	# Create tiles in a grid
	for x in range(-half_x, half_x):
		for z in range(-half_z, half_z):
			var world_x = x * GROUND_TILE_SIZE
			var world_z = z * GROUND_TILE_SIZE
			var world_y = -0.5  # Slightly below ground level so it's definitely visible
			
			tiles_to_render.append({
				"pos": Vector3(world_x, world_y, world_z),
				"rot": 0.0
			})
			tile_count += 1
	
	# Set up multimesh
	if not ground_mesh_instance or not ground_mesh_instance.multimesh:
		push_error("GroundRenderer: mesh_instance or multimesh is null!")
		return
		
	ground_mesh_instance.multimesh.instance_count = tile_count
	
	# Position each tile
	for i in range(tile_count):
		var tile_data = tiles_to_render[i]
		# QuadMesh is vertical by default, rotate 90° around X to make it horizontal
		# Make sure ground is definitely below miasma blocks (which are at Y=8)
		var pos = tile_data.pos
		pos.y = -1.0  # Well below miasma blocks
		var tile_transform = Transform3D(
			Basis().rotated(Vector3(1, 0, 0), deg_to_rad(90)),  # Rotate to lie flat
			pos
		)
		ground_mesh_instance.multimesh.set_instance_transform(i, tile_transform)
	
	print("Ground rendered: ", tile_count, " tiles at Y=-1.0")
	if tiles_to_render.size() > 0:
		print("GroundRenderer: First tile at: ", tiles_to_render[0].pos)
		print("GroundRenderer: Last tile at: ", tiles_to_render[-1].pos)
	print("GroundRenderer: Material color: ", ground_material.albedo_color)
	print("GroundRenderer: Mesh size: ", ground_mesh.size)
