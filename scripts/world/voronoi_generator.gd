# VoronoiGenerator - Utility class for Voronoi diagram generation
# Static functions for generating Voronoi points and cell lookups

class_name VoronoiGenerator

# Generate Poisson disc sampled points for Voronoi diagram
# Returns array of Vector2 points (in ground tile coordinates)
static func generate_poisson_points(
	count: int,
	min_distance: float,
	world_size: Vector2,
	rng: RandomNumberGenerator
) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var active_list: Array[int] = []
	
	# Grid for spatial hashing (speeds up distance checks)
	var cell_size: float = min_distance / sqrt(2.0)
	var grid_width: int = int(ceil(world_size.x / cell_size))
	var grid_height: int = int(ceil(world_size.y / cell_size))
	var grid: Array[Array] = []
	
	# Initialize grid
	for x in range(grid_width):
		grid.append([])
		for y in range(grid_height):
			grid[x].append([])
	
	# Helper: Get grid cell for point
	var get_grid_cell = func(pos: Vector2) -> Vector2i:
		var cell_x: int = int(pos.x / cell_size)
		var cell_y: int = int(pos.y / cell_size)
		cell_x = clamp(cell_x, 0, grid_width - 1)
		cell_y = clamp(cell_y, 0, grid_height - 1)
		return Vector2i(cell_x, cell_y)
	
	# Helper: Check if point is far enough from existing points
	var is_valid_point = func(pos: Vector2) -> bool:
		var cell = get_grid_cell.call(pos)
		var search_radius: int = 2  # Check neighboring cells
		
		for dx in range(-search_radius, search_radius + 1):
			for dy in range(-search_radius, search_radius + 1):
				var check_x: int = cell.x + dx
				var check_y: int = cell.y + dy
				
				if check_x < 0 or check_x >= grid_width:
					continue
				if check_y < 0 or check_y >= grid_height:
					continue
				
				for existing_point_index in grid[check_x][check_y]:
					var existing_point = points[existing_point_index]
					var distance = pos.distance_to(existing_point)
					
					if distance < min_distance:
						return false
		
		return true
	
	# Add first point randomly
	var first_point = Vector2(
		rng.randf() * world_size.x,
		rng.randf() * world_size.y
	)
	points.append(first_point)
	active_list.append(0)
	
	var first_cell = get_grid_cell.call(first_point)
	grid[first_cell.x][first_cell.y].append(0)
	
	# Generate remaining points using Poisson disc sampling
	var max_attempts: int = 30  # Max attempts per point before giving up
	
	while points.size() < count and active_list.size() > 0:
		# Pick random active point
		var active_index = rng.randi() % active_list.size()
		var active_point_index = active_list[active_index]
		var active_point = points[active_point_index]
		
		var found: bool = false
		
		# Try to find valid point around active point
		for attempt in range(max_attempts):
			# Random angle and distance (between min_distance and 2*min_distance)
			var angle: float = rng.randf() * TAU
			var distance: float = min_distance + rng.randf() * min_distance
			
			var new_point = active_point + Vector2(
				cos(angle) * distance,
				sin(angle) * distance
			)
			
			# Check bounds
			if new_point.x < 0 or new_point.x >= world_size.x:
				continue
			if new_point.y < 0 or new_point.y >= world_size.y:
				continue
			
			# Check if valid (far enough from existing points)
			if is_valid_point.call(new_point):
				points.append(new_point)
				active_list.append(points.size() - 1)
				
				var new_cell = get_grid_cell.call(new_point)
				grid[new_cell.x][new_cell.y].append(points.size() - 1)
				
				found = true
				break
		
		# If no valid point found, remove from active list
		if not found:
			active_list.remove_at(active_index)
	
	# If we didn't get enough points, fill with random points (less ideal, but works)
	while points.size() < count:
		var new_point = Vector2(
			rng.randf() * world_size.x,
			rng.randf() * world_size.y
		)
		
		# Check if valid
		if is_valid_point.call(new_point):
			points.append(new_point)
			var new_cell = get_grid_cell.call(new_point)
			grid[new_cell.x][new_cell.y].append(points.size() - 1)
	
	return points

# Get Voronoi cell index for a query position
# Returns index of closest Voronoi point
static func get_voronoi_cell(query_pos: Vector2, points: Array[Vector2]) -> int:
	if points.is_empty():
		return -1
	
	var closest_index: int = 0
	var closest_distance: float = query_pos.distance_to(points[0])
	
	for i in range(1, points.size()):
		var distance = query_pos.distance_to(points[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	return closest_index

# Assign biomes to Voronoi cells
# Randomly assigns biomes to cells (ensures all biomes are used, then cycles)
# Returns Dictionary: cell_index -> BiomeType
# Note: biome_enum_ref should be WorldManager.BiomeType
static func assign_biomes_to_cells(
	points: Array[Vector2],
	biome_enum_ref: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var assignments: Dictionary = {}
	
	# Get all biome types from the enum
	# For MVP, we have 3 biomes: MEADOW, DESERT, VOLCANO
	var biome_types: Array = []
	biome_types.append(biome_enum_ref.MEADOW)
	biome_types.append(biome_enum_ref.DESERT)
	biome_types.append(biome_enum_ref.VOLCANO)
	
	# Shuffle biome types
	var shuffled_biomes = biome_types.duplicate()
	for i in range(shuffled_biomes.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = shuffled_biomes[i]
		shuffled_biomes[i] = shuffled_biomes[j]
		shuffled_biomes[j] = temp
	
	# Assign biomes to cells
	# If we have more cells than biomes, cycle through biomes
	for i in range(points.size()):
		var biome_index = i % shuffled_biomes.size()
		assignments[i] = shuffled_biomes[biome_index]
	
	return assignments
