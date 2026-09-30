class_name CatacombMapGen
extends RefCounted
## Builds the branching room map of one descent (Inscryption / Slay the Spire
## style), bottom to top: entrance -> LAYERS_BETWEEN layers of choices -> boss.
##
## Every node is a Dictionary:
##   id: int, layer: int, type: StringName, pos: Vector2 (map-screen px),
##   next: Array[int] (ids in the layer above), visited: bool
## Rules:
##   - layer 1 is all COMBAT (the first real fight comes right after the tutorial)
##   - the layer just below the boss is all SAFE (always a rest before the boss)
##   - every middle layer has at least one COMBAT, never two SAFE side by side
##   - at least one LOOT cache on the map
##   - paths never cross, every node can be reached from the entrance

const COMBAT := &"combat"
const LOOT := &"loot"
const SAFE := &"safe"
const BOSS := &"boss"
const START := &"start"

const LAYERS_BETWEEN: int = 5              # choice layers between entrance and boss
const MAP_RECT := Rect2(340, 70, 600, 580) # where nodes are laid out on screen

static func generate(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layers: Array = []   # Array of Array[Dictionary]
	var next_id := 0
	var layer_count := LAYERS_BETWEEN + 2

	for layer in layer_count:
		var count := 1
		if layer > 0 and layer < layer_count - 1:
			count = rng.randi_range(2, 3)
		if layer == layer_count - 2:
			count = rng.randi_range(1, 2)   # the pre-boss rest
		var row: Array[Dictionary] = []
		for i in count:
			row.append({
				"id": next_id, "layer": layer, "type": _pick_type(layer, layer_count, rng, row),
				"pos": Vector2.ZERO, "next": [], "visited": false,
			})
			next_id += 1
		_ensure_combat(row, layer, layer_count)
		layers.append(row)
	_ensure_cache(layers, rng)

	_layout(layers, rng)
	for layer in layer_count - 1:
		_connect(layers[layer], layers[layer + 1], rng)

	var nodes: Array[Dictionary] = []
	for row in layers:
		nodes.append_array(row)
	return nodes

static func _pick_type(layer: int, layer_count: int, rng: RandomNumberGenerator, row: Array[Dictionary]) -> StringName:
	if layer == 0:
		return START
	if layer == layer_count - 1:
		return BOSS
	if layer == layer_count - 2:
		return SAFE
	if layer == 1:
		return COMBAT
	var roll := rng.randf()
	var t: StringName = COMBAT if roll < 0.5 else (LOOT if roll < 0.85 else SAFE)
	if t == SAFE and not row.is_empty() and row[-1]["type"] == SAFE:
		t = LOOT   # no two campfires next to each other
	return t

static func _ensure_combat(row: Array[Dictionary], layer: int, layer_count: int) -> void:
	if layer < 2 or layer > layer_count - 3:
		return
	for n in row:
		if n["type"] == COMBAT:
			return
	row[0]["type"] = COMBAT

## At least one cache per map: turn a spare middle room (not a layer's only
## fight) into one.
static func _ensure_cache(layers: Array, rng: RandomNumberGenerator) -> void:
	var spare: Array[Dictionary] = []
	for layer in range(2, layers.size() - 2):
		var row: Array = layers[layer]
		var fights := 0
		for n in row:
			if n["type"] == LOOT:
				return
			if n["type"] == COMBAT:
				fights += 1
		for n in row:
			if n["type"] != COMBAT or fights > 1:
				spare.append(n)
	if not spare.is_empty():
		spare[rng.randi_range(0, spare.size() - 1)]["type"] = LOOT

static func _layout(layers: Array, rng: RandomNumberGenerator) -> void:
	var layer_count := layers.size()
	for layer in layer_count:
		var row: Array = layers[layer]
		var y: float = MAP_RECT.end.y - MAP_RECT.size.y * layer / float(layer_count - 1)
		for i in row.size():
			var t: float = (i + 1) / float(row.size() + 1)
			var x: float = MAP_RECT.position.x + MAP_RECT.size.x * t
			if row.size() > 1:
				x += rng.randf_range(-25.0, 25.0)   # hand-drawn look, order is kept
			row[i]["pos"] = Vector2(x, y + (rng.randf_range(-10.0, 10.0) if layer > 0 and layer < layer_count - 1 else 0.0))

## Monotone (order-preserving) mapping lower -> upper, so paths never cross.
static func _connect(lower: Array, upper: Array, rng: RandomNumberGenerator) -> void:
	var n := lower.size()
	var m := upper.size()
	for k in n:
		var j: int = 0 if n == 1 else int(round(k * (m - 1) / float(n - 1)))
		if n == 1:
			# A single node fans out to every node above
			for jj in m:
				_link(lower[k], upper[jj])
			continue
		_link(lower[k], upper[j])
		# Sometimes also branch to the right neighbour (still non-crossing:
		# the next lower node maps at or right of it)
		var right := j + 1
		var next_lower_target: int = int(round((k + 1) * (m - 1) / float(n - 1))) if k + 1 < n else m
		if right < m and right <= next_lower_target and rng.randf() < 0.45:
			_link(lower[k], upper[right])
	# Every upper node needs a way in: link from the closest lower node by index
	for jj in m:
		var has_in := false
		for node in lower:
			if node["next"].has(upper[jj]["id"]):
				has_in = true
		if not has_in:
			var k: int = 0 if m == 1 else int(round(jj * (n - 1) / float(m - 1)))
			_link(lower[k], upper[jj])

static func _link(a: Dictionary, b: Dictionary) -> void:
	if not a["next"].has(b["id"]):
		a["next"].append(b["id"])
