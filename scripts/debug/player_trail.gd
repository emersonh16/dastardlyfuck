extends Node3D

# PlayerTrail - Visual debug trail showing player's path

var trail_points: Array[Vector3] = []
var max_points: int = 100
var point_spacing: float = 5.0  # Only add point if player moved this far

var last_trail_pos: Vector3 = Vector3.ZERO
var trail_mesh_instance: MeshInstance3D

func _ready():
	# Create a simple mesh for trail visualization
	trail_mesh_instance = MeshInstance3D.new()
	add_child(trail_mesh_instance)
	
	# Create a simple material (bright color for visibility)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	
	trail_mesh_instance.material_override = material
	print("PlayerTrail initialized")

func add_point(player_pos: Vector3):
	# Only add point if player moved far enough
	if last_trail_pos.distance_to(player_pos) >= point_spacing:
		trail_points.append(player_pos)
		last_trail_pos = player_pos
		
		# Limit trail length
		if trail_points.size() > max_points:
			trail_points.pop_front()
		
		_update_trail_mesh()

func _update_trail_mesh():
	if trail_points.size() < 2:
		trail_mesh_instance.mesh = null
		return
	
	# Create a simple line mesh
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	for point in trail_points:
		# Draw point slightly above ground
		var draw_pos = point + Vector3(0, 1.0, 0)
		mesh.surface_add_vertex(draw_pos)
	
	mesh.surface_end()
	trail_mesh_instance.mesh = mesh

func clear_trail():
	trail_points.clear()
	last_trail_pos = Vector3.ZERO
	_update_trail_mesh()
