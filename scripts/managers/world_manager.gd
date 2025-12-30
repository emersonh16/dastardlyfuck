extends Node

# WorldManager - Autoload singleton
# Manages world generation, biome map, and chunk loading
# Uses Voronoi diagram with 16 points for biome placement

# Biome types (starting with 3 for MVP)
enum BiomeType {
	MEADOW,
	DESERT,
	VOLCANO,
	# Future: 9 more biomes will be added
}

# World generation constants
const WORLD_SIZE_TILES: int = 100  # 100x100 ground tiles (reduced for debugging)
const VORONOI_POINT_COUNT: int = 16
const VORONOI_MIN_DISTANCE_TILES: int = 8  # Minimum distance between Voronoi points (in ground tiles, reduced for smaller world)
const CHUNK_SIZE_TILES: int = 64  # 64x64 ground tiles per chunk

# Ground tile size (matches existing system)
const GROUND_TILE_SIZE: float = 64.0  # World units per ground tile

# World state
var world_seed: int = 0
var voronoi_points: Array[Vector2] = []  # Voronoi seed points (in ground tile coordinates)
var biome_assignments: Dictionary = {}  # Voronoi cell index -> BiomeType
var loaded_chunks: Dictionary = {}  # Chunk key ("x,z") -> ChunkData (for caching)

# Random number generator (for deterministic generation)
var rng: RandomNumberGenerator = null

# Signals
signal world_generated()
signal chunk_loaded(chunk_key: String)

func _ready():
	print("WorldManager initialized")
	# Initialize world with a default seed (can be changed later)
	# Using a fixed seed for now for testing
	var default_seed: int = 12345
	initialize_world(default_seed)

# Initialize world from seed
func initialize_world(seed: int):
	world_seed = seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	# Generate Voronoi points using Poisson disc sampling
	voronoi_points = VoronoiGenerator.generate_poisson_points(
		VORONOI_POINT_COUNT,
		VORONOI_MIN_DISTANCE_TILES,
		Vector2(WORLD_SIZE_TILES, WORLD_SIZE_TILES),
		rng
	)
	
	# Assign biomes to Voronoi cells (randomly, but distinct)
	biome_assignments = VoronoiGenerator.assign_biomes_to_cells(
		voronoi_points,
		BiomeType,
		rng
	)
	
	print("WorldManager: Generated world with %d Voronoi points" % voronoi_points.size())
	print("WorldManager: Assigned %d biomes" % biome_assignments.size())
	
	# Generate mountains in the world
	var mountain_manager = get_node_or_null("/root/MountainManager")
	if mountain_manager:
		var world_size_world_units = WORLD_SIZE_TILES * GROUND_TILE_SIZE
		mountain_manager.generate_mountains_in_area(
			0.0, world_size_world_units,
			0.0, world_size_world_units
		)
		print("WorldManager: Generated mountains")
	
	world_generated.emit()

# Get biome at world position
func get_biome_at(world_pos: Vector3) -> BiomeType:
	# Convert world position to ground tile coordinates
	var tile_x: int = int(world_pos.x / GROUND_TILE_SIZE)
	var tile_z: int = int(world_pos.z / GROUND_TILE_SIZE)
	
	# Find closest Voronoi point
	var cell_index = VoronoiGenerator.get_voronoi_cell(
		Vector2(tile_x, tile_z),
		voronoi_points
	)
	
	# Return assigned biome
	if biome_assignments.has(cell_index):
		return biome_assignments[cell_index]
	
	# Fallback (shouldn't happen, but safety)
	return BiomeType.MEADOW

# Get ground color at world position
func get_ground_color_at(world_pos: Vector3) -> Color:
	var biome = get_biome_at(world_pos)
	return get_biome_color(biome)

# Get color for biome type
func get_biome_color(biome: BiomeType) -> Color:
	match biome:
		BiomeType.MEADOW:
			return Color(0.4, 0.8, 0.4)  # Pastel green
		BiomeType.DESERT:
			return Color(0.9, 0.8, 0.6)  # Tan
		BiomeType.VOLCANO:
			return Color(0.3, 0.25, 0.2)  # Dark warm gray
		_:
			return Color.WHITE  # Fallback

# Get chunk key from world position
func get_chunk_key(world_pos: Vector3) -> String:
	var chunk_x: int = int(world_pos.x / (GROUND_TILE_SIZE * CHUNK_SIZE_TILES))
	var chunk_z: int = int(world_pos.z / (GROUND_TILE_SIZE * CHUNK_SIZE_TILES))
	return "%d,%d" % [chunk_x, chunk_z]

# Get chunk data at world position (generates if needed)
func get_chunk_at(world_pos: Vector3) -> Dictionary:
	var chunk_key = get_chunk_key(world_pos)
	
	# Return cached chunk if available
	if loaded_chunks.has(chunk_key):
		return loaded_chunks[chunk_key]
	
	# Generate new chunk
	var chunk_data = generate_chunk(chunk_key, world_pos)
	loaded_chunks[chunk_key] = chunk_data
	chunk_loaded.emit(chunk_key)
	
	return chunk_data

# Generate chunk data
func generate_chunk(chunk_key: String, world_pos: Vector3) -> Dictionary:
	# Parse chunk coordinates
	var parts = chunk_key.split(",")
	var chunk_x: int = int(parts[0])
	var chunk_z: int = int(parts[1])
	
	# Calculate chunk bounds in world units
	var chunk_start_x: float = chunk_x * GROUND_TILE_SIZE * CHUNK_SIZE_TILES
	var chunk_start_z: float = chunk_z * GROUND_TILE_SIZE * CHUNK_SIZE_TILES
	
	# For now, chunks just store their bounds
	# Future: Could store biome map, decorations, etc.
	return {
		"key": chunk_key,
		"chunk_x": chunk_x,
		"chunk_z": chunk_z,
		"start_x": chunk_start_x,
		"start_z": chunk_start_z,
		"size": CHUNK_SIZE_TILES
	}

# Get player starting position (always in meadow)
func get_starting_position() -> Vector3:
	# Find meadow biome Voronoi cell
	var meadow_cell_index: int = -1
	for cell_index in biome_assignments:
		if biome_assignments[cell_index] == BiomeType.MEADOW:
			meadow_cell_index = cell_index
			break
	
	if meadow_cell_index == -1:
		# Fallback: center of world
		var center = WORLD_SIZE_TILES * GROUND_TILE_SIZE / 2.0
		return Vector3(center, 0.0, center)
	
	# Get meadow Voronoi point (in ground tile coordinates)
	var meadow_point = voronoi_points[meadow_cell_index]
	
	# Convert to world coordinates (center of meadow cell)
	var world_x: float = meadow_point.x * GROUND_TILE_SIZE
	var world_z: float = meadow_point.y * GROUND_TILE_SIZE
	
	return Vector3(world_x, 0.0, world_z)

# Unload chunks far from position (cleanup)
func unload_distant_chunks(player_pos: Vector3, keep_distance_chunks: int = 5):
	var player_chunk_key = get_chunk_key(player_pos)
	var parts = player_chunk_key.split(",")
	var player_chunk_x: int = int(parts[0])
	var player_chunk_z: int = int(parts[1])
	
	var chunks_to_remove: Array[String] = []
	
	for chunk_key in loaded_chunks:
		var chunk_parts = chunk_key.split(",")
		var chunk_x: int = int(chunk_parts[0])
		var chunk_z: int = int(chunk_parts[1])
		
		var distance = max(abs(chunk_x - player_chunk_x), abs(chunk_z - player_chunk_z))
		
		if distance > keep_distance_chunks:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		loaded_chunks.erase(chunk_key)
