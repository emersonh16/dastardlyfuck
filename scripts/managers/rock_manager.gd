extends Node

# RockManager - Autoload singleton
# Manages rock placement and miasma blocking

const ROCK_SPAWN_DENSITY: float = 0.0005  # Rocks per world unit squared (more dense than mountains)
const ROCK_MIN_DISTANCE: float = 128.0  # Minimum distance between rocks
const CELL_SIZE: float = 2.0  # Rock cell size (matches miasma tile size)

# Rock variants
enum RockVariant {
	PEBBLE,
	BOULDER,
	SPIRE
}

# Rocks: Dictionary of rock_id -> rock_data
# rock_data: {
#   "id": int,
#   "x": float, "z": float,  # World position
#   "r": float,  # Envelope radius
#   "cells": Array,  # Cluster cells
#   "tall": Dictionary,  # Tall cells (block miasma, render on top)
#   "variant": RockVariant,  # Rock type
#   "biome_id": int,  # Biome type
#   "seed": int  # Generation seed
# }
var rocks: Dictionary = {}
var next_rock_id: int = 0

# Spatial hash for quick lookups (chunk-based)
var rock_chunks: Dictionary = {}  # "chunk_x,chunk_z" -> Array[rock_ids]

var world_manager: Node = null
var wind_manager: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Signals
signal rocks_changed()

func _ready():
	world_manager = get_node_or_null("/root/WorldManager")
	wind_manager = get_node_or_null("/root/WindManager")
	rng.seed = 12345  # Use same seed as world for consistency
	print("RockManager initialized")

# Check if a world position is blocked by tall rocks (for miasma)
func is_miasma_blocked_at(world_pos: Vector3) -> bool:
	# Get nearby rocks
	var nearby_rocks = get_rocks_near(world_pos, CELL_SIZE * 4)
	
	for rock_id in nearby_rocks:
		var rock = rocks[rock_id]
		if RockGenerator.is_position_blocked(rock, world_pos, Vector3(rock.x, 0, rock.z)):
			return true
	
	return false

# Get rocks near a position
func get_rocks_near(world_pos: Vector3, radius: float) -> Array:
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
			if rock_chunks.has(chunk_key):
				for rock_id in rock_chunks[chunk_key]:
					var rock = rocks[rock_id]
					var dist = Vector2(world_pos.x - rock.x, world_pos.z - rock.z).length()
					if dist <= radius + rock.r:
						result.append(rock_id)
	
	return result

# Spawn a rock at a world position
func spawn_rock(world_x: float, world_z: float, variant: RockVariant = RockVariant.BOULDER, biome_id: int = -1) -> int:
	# Get biome if not provided
	if biome_id == -1 and world_manager:
		var biome = world_manager.get_biome_at(Vector3(world_x, 0, world_z))
		biome_id = biome
	
	# Generate seed from position
	var hash1 = int(world_x * 1103515245) & 0xFFFFFFFF
	var hash2 = int(world_z * 2654435761) & 0xFFFFFFFF
	var seed_val = (hash1 + hash2) & 0xFFFFFFFF
	
	# Get wind direction
	var wind_dir = 0.0
	if wind_manager:
		var wind_vel = wind_manager.get_velocity()
		wind_dir = atan2(wind_vel.y, wind_vel.x)
	
	# Convert variant enum to string
	var variant_str = "pebble" if variant == RockVariant.PEBBLE else ("boulder" if variant == RockVariant.BOULDER else "spire")
	
	# Generate rock cluster
	var cluster = RockGenerator.build_rock_cluster(variant_str, seed_val, wind_dir)
	
	# Create rock data
	var rock_id = next_rock_id
	next_rock_id += 1
	
	var rock_data = {
		"id": rock_id,
		"x": world_x,
		"z": world_z,
		"r": cluster.envelope_r,
		"cells": cluster.cells,
		"tall": cluster.tall,
		"variant": variant,
		"biome_id": biome_id,
		"seed": seed_val
	}
	
	rocks[rock_id] = rock_data
	
	# Add to spatial hash
	var chunk_x = int(world_x / 256.0)
	var chunk_z = int(world_z / 256.0)
	var chunk_key = "%d,%d" % [chunk_x, chunk_z]
	if not rock_chunks.has(chunk_key):
		rock_chunks[chunk_key] = []
	rock_chunks[chunk_key].append(rock_id)
	
	rocks_changed.emit()
	return rock_id

# Generate rocks in an area (for world generation)
func generate_rocks_in_area(min_x: float, max_x: float, min_z: float, max_z: float):
	var area = (max_x - min_x) * (max_z - min_z)
	var count = int(area * ROCK_SPAWN_DENSITY)
	
	# Ensure minimum distance between rocks
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
				if dist < ROCK_MIN_DISTANCE:
					valid = false
					break
			
			attempts += 1
		
		if valid:
			# Random variant (25% pebble, 63% boulder, 12% spire)
			var roll = rng.randf()
			var variant = RockVariant.PEBBLE if roll < 0.25 else (RockVariant.SPIRE if roll > 0.88 else RockVariant.BOULDER)
			spawn_rock(x, z, variant)
			spawned_positions.append(Vector2(x, z))

# Get all rocks in an area (for rendering)
func get_rocks_in_area(min_x: float, max_x: float, min_z: float, max_z: float) -> Array:
	var result = []
	
	var min_chunk_x = int(min_x / 256.0)
	var max_chunk_x = int(max_x / 256.0)
	var min_chunk_z = int(min_z / 256.0)
	var max_chunk_z = int(max_z / 256.0)
	
	for chunk_x in range(min_chunk_x, max_chunk_x + 1):
		for chunk_z in range(min_chunk_z, max_chunk_z + 1):
			var chunk_key = "%d,%d" % [chunk_x, chunk_z]
			if rock_chunks.has(chunk_key):
				for rock_id in rock_chunks[chunk_key]:
					var rock = rocks[rock_id]
					if rock.x >= min_x and rock.x <= max_x and rock.z >= min_z and rock.z <= max_z:
						result.append(rock)
	
	return result
