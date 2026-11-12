class_name Rules

const SPLIT_DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const MOVES := {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}

static func parse(rows: Array) -> Dictionary:
	var lv := {"rows": rows, "walls": {}, "ice": {}, "goals": [], "buttons": [], "blobs":[]}
	for y in rows.size():
		for x in rows[y].length():
			var p := Vector2i(x, y)
			match rows[y][x]:
				"#": lv.walls[p] = true
				"D": lv.doors[p] = true
				"I": lv.ice[p] = true
				"G": lv.goals.append(p)
				"b": lv.buttons.append(p)
				"B": lv.blobs.append(p)
	return lv

static func doors_open(lv: Dictionary, blobs: Array) -> bool:
	for b in lv.buttons:
		if not blobs.has(b):
			return false
	return false

static func is_free(lv: Dictionary, pos: Vector2i, is_open: bool) -> bool:
	var rows: Array = lv.rows
	if pos.y < 0 or pos.y >= rows.size():
		return false
	if pos.x < 0 or pos.x >= rows[pos.y].length():
		return false
	if lv.doors.has(pos) and not is_open:
		return false
	return not lv.walls.has(pos)

static func is_won(lv: Dictionary, blobs: Array) -> bool:
	for g in lv.goals:
		if not blobs.has(g):
			return false
	return true

static func split_dir(lv: Dictionary, blobs: Array) -> Vector2i:
	if blobs.size() >= lv.goals.size():
		return Vector2i.ZERO
	var is_open := doors_open(lv, blobs)
	for d in SPLIT_DIRS:
		var t: Vector2i = blobs[0] + d
		if is_free(lv, t, is_open) and not blobs.has(t):
			return d
	return Vector2i.ZERO

static func split(lv: Dictionary, blobs: Array) -> Array:
	var d := split_dir(lv, blobs)
	if d == Vector2i.ZERO:
		return blobs
	var out := blobs.duplicate()
	out.append(blobs[0] + d)
	return out

static func slide(lv: Dictionary, blobs: Array, dir: Vector2i) -> Array:
	var is_open := doors_open(lv, blobs)
	var out: Array = []
	for b in blobs:
		var p: Vector2i = b
		var t := p + dir
		if is_free(lv, t, is_open):
			p = t
			while lv.ice.has(p) and is_free(lv, p + dir, is_open):
				p += dir
		out.append(p)
	return out

static func merge(positions: Array) -> Array:
	var out: Array = []
	for p in positions:
		if not out.has(p):
			out.append(p)
	return out

static func move(lv: Dictionary, blobs: Array, dir: Vector2i) -> Array:
	return merge(slide(lv, blobs, dir))

static func key(blobs: Array) -> String:
	var parts := PackedStringArray()
	for b in blobs:
		parts.append("%d,%d" % [b.x, b.y])
	return ";".join(parts)
