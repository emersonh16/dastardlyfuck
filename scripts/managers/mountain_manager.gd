extends Node

# MountainManager - Autoload singleton
# Manages mountain placement and miasma blocking

const MOUNTAIN_SPAWN_DENSITY: float = 0.0001  # Mountains per world unit squared
const MOUNTAIN_MIN_DISTANCE: float = 512.0  # Minimum distance between mountains
const CELL_SIZE: float = 2.0  # Mountain cell size (matches miasma tile size)

# Mountains: Dictionary of mountain_id -> mountain_data
# mountain_data: {
#   "id": int,
#   "x": float, "z": float,  # World position
#   "r": float,  # Envelope radius
#   "cells": Array,  # Cluster cells
#   "tall": Dictionary,  # Tall cells (block miasma)
#   "biome_id": int,  # Biome type
#   "seed": int  # Generation seed
# }
var mountains: Dictionary = {}
var next_mountain_id: int = 0

# Spatial hash for quick lookups (chunk-based)
var mountain_chunks: Dictionary = {}  # "chunk_x,chunk_z" -> Array[mountain_ids]

var world_manager: Node = null
var wind_manager: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Signals
signal mountains_changed()

func _ready():
	world_manager = get_node_or_null("/root/WorldManager")
	wind_manager = get_node_or_null("/root/WindManager")
	rng.seed = 12345  # Use same seed as world for consistency
	print("MountainManager initialized")

# Check if a world position is blocked by mountains (for miasma)
func is_miasma_blocked_at(world_pos: Vector3) -> bool:
	# Get nearby mountains
	var nearby_mountains = get_mountains_near(world_pos, CELL_SIZE * 4)
	
	for mountain_id in nearby_mountains:
		var mountain = mountains[mountain_id]
		if MountainGenerator.is_position_blocked(mountain, world_pos, Vector3(mountain.x, 0, mountain.z)):
			return true
	
	return false

# Get mountains near a position
func get_mountains_near(world_pos: Vector3, radius: float) -> Array:
	var result = []
	var min_x = world_pos.x - radius
	var max_x = world_pos.x + radius
	var min_z = world_pos.z - radius
	var max_z = world_pos.z + radius
	
	# Check relevant chunks
	var chunk_size = 256.0  # Approximate chunk size
	var min_chunk_x = int(min_x / chunk_size)
	var max_chunk_x = int(max_x / chunk_size)
	var min_chunk_z = int(min_z / chunk_size)
	var max_chunk_z = int(max_z / chunk_size)
	
	for chunk_x in range(min_chunk_x, max_chunk_x + 1):
		for chunk_z in range(min_chunk_z, max_chunk_z + 1):
			var chunk_key = "%d,%d" % [chunk_x, chunk_z]
			if mountain_chunks.has(chunk_key):
				for mountain_id in mountain_chunks[chunk_key]:
					var mountain = mountains[mountain_id]
					var dist = Vector2(world_pos.x - mountain.x, world_pos.z - mountain.z).length()
					if dist <= radius + mountain.r:
						result.append(mountain_id)
	
	return result

# Spawn a mountain at a world position
func spawn_mountain(world_x: float, world_z: float, biome_id: int = -1) -> int:
	# Get biome if not provided
	if biome_id == -1 and world_manager:
		var biome = world_manager.get_biome_at(Vector3(world_x, 0, world_z))
		biome_id = biome
	
	# Generate seed from position (using bitwise XOR equivalent)
	var hash1 = int(world_x * 1103515245) & 0xFFFFFFFF
	var hash2 = int(world_z * 2654435761) & 0xFFFFFFFF
	var seed_val = (hash1 + hash2) & 0xFFFFFFFF  # Use addition instead of XOR for seed mixing
	
	# Get wind direction
	var wind_dir = 0.0
	if wind_manager:
		var wind_vel = wind_manager.get_velocity()
		wind_dir = atan2(wind_vel.y, wind_vel.x)
	
	# Generate mountain cluster
	var cluster = MountainGenerator.build_mountain_cluster(seed_val, wind_dir)
	
	# Create mountain data
	var mountain_id = next_mountain_id
	next_mountain_id += 1
	
	var mountain_data = {
		"id": mountain_id,
		"x": world_x,
		"z": world_z,
		"r": cluster.envelope_r,
		"cells": cluster.cells,
		"tall": cluster.tall,
		"biome_id": biome_id,
		"seed": seed_val
	}
	
	mountains[mountain_id] = mountain_data
	
	# Add to spatial hash
	var chunk_x = int(world_x / 256.0)
	var chunk_z = int(world_z / 256.0)
	var chunk_key = "%d,%d" % [chunk_x, chunk_z]
	if not mountain_chunks.has(chunk_key):
		mountain_chunks[chunk_key] = []
	mountain_chunks[chunk_key].append(mountain_id)
	
	mountains_changed.emit()
	return mountain_id

# Generate mountains in an area (for world generation)
func generate_mountains_in_area(min_x: float, max_x: float, min_z: float, max_z: float):
	var area = (max_x - min_x) * (max_z - min_z)
	var count = int(area * MOUNTAIN_SPAWN_DENSITY)
	
	# Ensure minimum distance between mountains
	var spawned_positions = []
	
	for i in range(count):
		var attempts = 0
		var valid = false
		var x = 0.0
		var z = 0.0
		
		while attempts < 50 and not valid:
			x = min_x + rng.randf() * (max_x - min_x)
			z = min_z + rng.randf() * (max_z - min_z)
			
			valid = true
			for pos in spawned_positions:
				var dist = Vector2(x - pos.x, z - pos.y).length()  # Vector2 uses x, y (z stored as y)
				if dist < MOUNTAIN_MIN_DISTANCE:
					valid = false
					break
			
			attempts += 1
		
		if valid:
			spawn_mountain(x, z)
			spawned_positions.append(Vector2(x, z))  # Vector2 uses x, y (z becomes y)

# Get all mountains in an area (for rendering)
func get_mountains_in_area(min_x: float, max_x: float, min_z: float, max_z: float) -> Array:
	var result = []
	
	var min_chunk_x = int(min_x / 256.0)
	var max_chunk_x = int(max_x / 256.0)
	var min_chunk_z = int(min_z / 256.0)
	var max_chunk_z = int(max_z / 256.0)
	
	for chunk_x in range(min_chunk_x, max_chunk_x + 1):
		for chunk_z in range(min_chunk_z, max_chunk_z + 1):
			var chunk_key = "%d,%d" % [chunk_x, chunk_z]
			if mountain_chunks.has(chunk_key):
				for mountain_id in mountain_chunks[chunk_key]:
					var mountain = mountains[mountain_id]
					if mountain.x >= min_x and mountain.x <= max_x and mountain.z >= min_z and mountain.z <= max_z:
						result.append(mountain)
	
	return result
