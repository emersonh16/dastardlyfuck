# RockGenerator - Utility class for generating rock clusters
# Similar to mountain generation but smaller, with variants (pebble, boulder, spire)

class_name RockGenerator

const CELL_SIZE: float = 2.0  # Object cell size (matches miasma tile size)

# Generate rock cluster mask (similar to rock.buildClusterMask from JS)
# Returns Dictionary with cells array and tall Set
static func build_rock_cluster(variant: String, seed_value: int, wind_dir: float = 0.0) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	var jitter = func(min_val: float, max_val: float) -> float:
		return min_val + (max_val - min_val) * rng.randf()
	
	# Rock parameters based on variant
	var base_steps = 90 if variant == "pebble" else (160 if variant == "boulder" else 210)
	var steps = int(base_steps * jitter.call(0.9, 1.3))
	var branch_steps = 60
	var branch_prob = 0.06 if variant == "pebble" else (0.10 if variant == "boulder" else 0.14)
	var walkers = 1 if variant == "pebble" else (2 if variant == "boulder" and rng.randf() < 0.5 else 3)
	if variant == "spire":
		walkers = 3 + (1 if rng.randf() < 0.5 else 0)
	
	# Direction vectors (4 and 8 directions)
	var dirs4 = [
		Vector2(CELL_SIZE, 0),
		Vector2(-CELL_SIZE, 0),
		Vector2(0, CELL_SIZE),
		Vector2(0, -CELL_SIZE)
	]
	var dirs8 = dirs4.duplicate()
	dirs8.append_array([
		Vector2(CELL_SIZE, CELL_SIZE),
		Vector2(-CELL_SIZE, CELL_SIZE),
		Vector2(CELL_SIZE, -CELL_SIZE),
		Vector2(-CELL_SIZE, -CELL_SIZE)
	])
	
	var cell_set = {}
	
	# Walk function to generate cluster shape
	for w in range(walkers):
		_walk_cluster(cell_set, dirs4, dirs8, steps, branch_steps, branch_prob, rng)
	
	# Prune isolated cells
	var to_prune = []
	for k in cell_set:
		var parts = k.split(",")
		var dx = float(parts[0])
		var dy = float(parts[1])
		var neighbors = 0
		for d in dirs8:
			var check_key = "%d,%d" % [int(dx + d.x), int(dy + d.y)]
			if cell_set.has(check_key):
				neighbors += 1
		if neighbors <= 1 and rng.randf() < 0.60:
			to_prune.append(k)
	
	for k in to_prune:
		cell_set.erase(k)
	
	# Carve wind-facing direction (rocks eroded by wind)
	_carve_wind_direction(cell_set, dirs4, dirs8, wind_dir, rng)
	
	# Mark tall cells (these render on top of miasma and block it)
	var tall = _mark_tall_cells(cell_set, dirs4, variant, rng)
	
	# Dilate tall cells
	var dilated = _dilate_tall_cells(tall, cell_set, dirs8, wind_dir, rng)
	
	# Convert set to cells array
	var cells = []
	var max_dist2 = 0.0
	for k in cell_set:
		var parts = k.split(",")
		var dx = float(parts[0])
		var dy = float(parts[1])
		cells.append({"dx": dx, "dy": dy})
		var dist2 = dx * dx + dy * dy
		if dist2 > max_dist2:
			max_dist2 = dist2
	
	var envelope_r = max(CELL_SIZE * 2, ceil((sqrt(max_dist2) + CELL_SIZE * 1.25) / CELL_SIZE) * CELL_SIZE)
	
	return {
		"cells": cells,
		"tall": dilated,
		"envelope_r": envelope_r
	}

# Helper function to walk cluster
static func _walk_cluster(cell_set: Dictionary, dirs4: Array, dirs8: Array, steps: int, branch_steps: int, branch_prob: float, rng: RandomNumberGenerator):
	var x = 0.0
	var y = 0.0
	for i in range(steps):
		var key = "%d,%d" % [int(x), int(y)]
		cell_set[key] = true
		var pool = dirs4 if rng.randf() < 0.80 else dirs8
		var d = pool[rng.randi() % pool.size()]
		x += d.x
		y += d.y
		if i % 15 == 0:
			var j = dirs4[rng.randi() % 4]
			if rng.randf() < 0.5:
				x += j.x
			else:
				y += j.y
		if rng.randf() < branch_prob:
			var b = dirs4[rng.randi() % 4]
			var bx = x + b.x
			var by = y + b.y
			var branch_steps_count = 24 + int(rng.randf() * (branch_steps - 24))
			for k in range(0, branch_steps_count, 8):
				var branch_key = "%d,%d" % [int(bx), int(by)]
				cell_set[branch_key] = true
				var bd = dirs4[rng.randi() % 4]
				bx += bd.x
				by += bd.y

# Helper function to carve wind direction
static func _carve_wind_direction(cell_set: Dictionary, dirs4: Array, dirs8: Array, wind_dir: float, rng: RandomNumberGenerator):
	if is_nan(wind_dir):
		return
	
	var wx = cos(wind_dir)
	var wy = sin(wind_dir)
	var main_dir = dirs8[0]
	var best_dot = -INF
	for d in dirs8:
		var dot = d.x * wx + d.y * wy
		if dot > best_dot:
			best_dot = dot
			main_dir = d
	
	_carve_path(cell_set, dirs4, dirs8, main_dir, rng)
	var main_idx = dirs8.find(main_dir)
	var diag_idx = (main_idx + (1 if rng.randf() < 0.5 else -1) + dirs8.size()) % dirs8.size()
	_carve_path(cell_set, dirs4, dirs8, dirs8[diag_idx], rng)

# Helper function to carve a single path
static func _carve_path(cell_set: Dictionary, dirs4: Array, dirs8: Array, dir: Vector2, rng: RandomNumberGenerator):
	var cx = 0.0
	var cy = 0.0
	var carve_len = 22 + int(rng.randf() * 16)
	for i in range(carve_len):
		var key = "%d,%d" % [int(cx), int(cy)]
		cell_set.erase(key)
		for d in dirs4:
			var d_key = "%d,%d" % [int(cx + d.x), int(cy + d.y)]
			cell_set.erase(d_key)
		if rng.randf() < 0.8:
			cx += dir.x
			cy += dir.y
		else:
			var step = dirs8[rng.randi() % dirs8.size()]
			cx += step.x
			cy += step.y

# Helper function to mark tall cells
static func _mark_tall_cells(cell_set: Dictionary, dirs4: Array, variant: String, rng: RandomNumberGenerator) -> Dictionary:
	var tall = {}
	var tall_seeds = 6 + int(rng.randi() % 5)
	var cells_arr = []
	for k in cell_set:
		cells_arr.append(k)
	
	for s in range(tall_seeds):
		if cells_arr.is_empty():
			break
		var pick = cells_arr[rng.randi() % cells_arr.size()]
		var parts = pick.split(",")
		var sx = float(parts[0])
		var sy = float(parts[1])
		
		var queue = [[sx, sy]]
		var visited = {}
		var start_key = "%d,%d" % [int(sx), int(sy)]
		visited[start_key] = true
		
		var budget = 8 + int(rng.randi() % 6) if variant == "pebble" else (14 + int(rng.randi() % 10) if variant == "boulder" else 20 + int(rng.randi() % 14))
		
		while queue.size() > 0 and budget > 0:
			var pos = queue.pop_front()
			var ax = pos[0]
			var ay = pos[1]
			var kk = "%d,%d" % [int(ax), int(ay)]
			if cell_set.has(kk):
				tall[kk] = true
			for d in dirs4:
				var nx = ax + d.x
				var ny = ay + d.y
				var nk = "%d,%d" % [int(nx), int(ny)]
				if not visited.has(nk) and cell_set.has(nk) and rng.randf() < 0.88:
					visited[nk] = true
					queue.append([nx, ny])
			budget -= 1
	
	return tall

# Helper function to dilate tall cells
static func _dilate_tall_cells(tall: Dictionary, cell_set: Dictionary, dirs8: Array, wind_dir: float, rng: RandomNumberGenerator) -> Dictionary:
	var dilated = tall.duplicate()
	for pass_num in range(2):
		var add = {}
		for k in dilated:
			var parts = k.split(",")
			var x = float(parts[0])
			var y = float(parts[1])
			for d in dirs8:
				var nk = "%d,%d" % [int(x + d.x), int(y + d.y)]
				if cell_set.has(nk):
					add[nk] = true
		for k in add:
			dilated[k] = true
	
	# Wind-based erosion/addition (wind "catches" rocks)
	if not is_nan(wind_dir):
		var wx = cos(wind_dir)
		var wy = sin(wind_dir)
		for k in Array(dilated.keys()):
			var parts = k.split(",")
			var x = float(parts[0])
			var y = float(parts[1])
			var dot = x * wx + y * wy
			if dot > 0 and rng.randf() < 0.3:
				dilated.erase(k)
			elif dot < 0 and rng.randf() < 0.3:
				for d in dirs8:
					var nk = "%d,%d" % [int(x + d.x), int(y + d.y)]
					if cell_set.has(nk):
						dilated[nk] = true
	
	return dilated

# Check if a position is blocked by tall rock cells
static func is_position_blocked(rock_data: Dictionary, world_pos: Vector3, rock_world_pos: Vector3) -> bool:
	if not rock_data.has("tall"):
		return false
	
	var tall_cells = rock_data.tall
	var cell_size = CELL_SIZE
	
	# Convert world position to relative position from rock center
	var rel_x = world_pos.x - rock_world_pos.x
	var rel_y = world_pos.z - rock_world_pos.z
	
	# Snap to cell grid
	var cell_x = round(rel_x / cell_size) * cell_size
	var cell_y = round(rel_y / cell_size) * cell_size
	
	var key = "%d,%d" % [int(cell_x), int(cell_y)]
	return tall_cells.has(key)
