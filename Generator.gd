class_name Generator

const MIN_MOVES := 8
const MAX_MOVES := 24
const MAX_ATTEMPTS := 400
const STATE_CAP := 12000

static func daily_seed() -> int:
	var d := Time.get_date_dict_from_system(true)
	return d.year * 10000 + d.month * 100 + d.day

static func daily() -> Dictionary:
	return make(daily_seed())

static func make(seed_value: int) -> Dictionary:
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 1000 + attempt
		var rows := candidate(rng)
		if rows.is_empty():
			continue
		var r := Rules.solve(Rules.parse(rows), STATE_CAP, MAX_MOVES)
		if r.solved and r.moves >= MIN_MOVES and r.moves <= MAX_MOVES:
			var pruned := prune_ice(rows, r.moves)
			var final := Rules.solve(Rules.parse(pruned), STATE_CAP)
			return {"rows": pruned, "par": final.moves, "solution": "".join(final.path), "attempt": attempt}
	return {}

static func prune_ice(rows: Array, par: int) -> Array:
	var out := rows.duplicate()
	var changed := true
	while changed:
		changed = false
		for y in out.size():
			for x in out[y].length():
				if out[y][x] != "I":
					continue
				var trial := out.duplicate()
				trial[y] = out[y].substr(0, x) + "." + out[y].substr(x + 1)
				var r := Rules.solve(Rules.parse(trial), STATE_CAP, par)
				if r.solved and r.moves == par:
					out = trial
					changed = true
	return out

static func candidate(rng: RandomNumberGenerator) -> Array:
	var w := rng.randi_range(7, 9)
	var h := rng.randi_range(6, 8)
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			row.append("#" if edge or rng.randf() < 0.18 else ".")
		grid.append(row)

	var cells: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[y][x] == ".":
				cells.append(Vector2i(x, y))
	if cells.size() < 16:
		return []

	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp

	var goal_count := rng.randi_range(2, 3)
	var use_gate := rng.randf() < 0.35

	var start: Vector2i = cells.pop_back()
	grid[start.y][start.x] = "B"
	for i in goal_count:
		var g: Vector2i = cells.pop_back()
		grid[g.y][g.x] = "G"
	if use_gate:
		var gate: Vector2i = cells.pop_back()
		var button: Vector2i = cells.pop_back()
		grid[gate.y][gate.x] = "D"
		grid[button.y][button.x] = "b"
	for i in rng.randi_range(2, 6):
		var p: Vector2i = cells.pop_back()
		grid[p.y][p.x] = "I"

	if not connected(grid, start):
		return []

	var rows: Array = []
	for row in grid:
		var s := ""
		for c in row:
			s += c
		rows.append(s)
	return rows

static func connected(grid: Array, start: Vector2i) -> bool:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for d in Rules.SPLIT_DIRS:
			var n: Vector2i = p + d
			if grid[n.y][n.x] != "#" and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] in ["G", "b", "D"] and not seen.has(Vector2i(x, y)):
				return false
	return true
