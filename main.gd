extends Node2D

const TILE := 64
const OFFSET := Vector2(100, 100)
const TEX_WALL := preload("res://art/wall.png")
const TEX_FLOOR := preload("res://art/floor.png")
const TEX_GOAL := preload("res://art/goal.png")
const TEX_GOAL_LIT := preload("res://art/goal_lit.png")
const TEX_BLOB := preload("res://art/blob.png")

var walls := {}
var buttons: Array[Vector2i] = []
var doors := {}
var goals: Array[Vector2i] = []
var blobs: Array[Vector2i] = []
var vis: Array[Vector2] = []
var on_title := true
var title_t := 0.0
var history: Array = []
var won := false
var levels := Levels.DATA  
var current := 0
var level: Array = []

func _ready() -> void:
	load_level()

func load_level() -> void:
	level = levels[current]
	walls.clear()
	goals.clear()
	blobs.clear()
	buttons.clear()
	doors.clear()
	history.clear()
	won = false
	for y in level.size():
		for x in level[y].length():
			var pos := Vector2i(x, y)
			match level[y][x]:
				"#": walls[pos] = true
				"G": goals.append(pos)
				"B": blobs.append(pos)
				"b": buttons.append(pos)
				"D": doors[pos] = true
	sync_vis(true)
	queue_redraw()

func check_win() -> void:
	won = true
	for g in goals:
		if not blobs.has(g):
			won = false

func doors_open() -> bool:
	for b in buttons:
		if not blobs.has(b):
			return false
	return true

func is_free(pos: Vector2i, is_open: bool) -> bool:
	if pos.y < 0 or pos.y >= level.size():
		return false
	if pos.x < 0 or pos.x >= level[pos.y].length():
		return false
	if doors.has(pos) and not is_open:
		return false
	return not walls.has(pos)

func split() -> void:
	if blobs.size() >= goals.size():
		return
	var is_open := doors_open()
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for d in dirs:
		var t: Vector2i = blobs[0] + d
		if is_free(t, is_open) and not blobs.has(t):
			blobs.append(t)
			return

func _unhandled_input(event: InputEvent) -> void:
	if on_title:
		var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and start_rect().has_point(get_local_mouse_position())
		var key_hit: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE
		if clicked or key_hit:
			on_title = false
			queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			on_title = true
			queue_redraw()
			return
		if event.keycode == KEY_R:
			load_level()
			return
		if event.keycode == KEY_Z:
			if history.size() > 0:
				blobs.assign(history.pop_back())
				sync_vis()
				won = false
				queue_redraw()
			return
	if won:
		if event.is_action_pressed("ui_accept") and current < levels.size() - 1:
			current += 1
			load_level()
		return

	var before := blobs.duplicate()
	if event.is_action_pressed("ui_accept"):
		split()
	else:
		var dir := Vector2i.ZERO
		if event.is_action_pressed("ui_left"): dir = Vector2i.LEFT
		elif event.is_action_pressed("ui_right"): dir = Vector2i.RIGHT
		elif event.is_action_pressed("ui_up"): dir = Vector2i.UP
		elif event.is_action_pressed("ui_down"): dir = Vector2i.DOWN
		if dir == Vector2i.ZERO:
			return
		var is_open := doors_open()
		for i in blobs.size():
			var target := blobs[i] + dir
			if is_free(target, is_open):
				blobs[i] = target
		var unique: Array[Vector2i] = []
		var unique_vis: Array[Vector2] = []
		for i in blobs.size():
			if not unique.has(blobs[i]):
				unique.append(blobs[i])
				unique_vis.append(vis[i])
		blobs = unique
		vis = unique_vis

	if blobs == before:
		return
	sync_vis()
	history.append(before)
	check_win()
	queue_redraw()

func tile_center(p: Vector2i) -> Vector2:
	return OFFSET + Vector2(p) * TILE + Vector2(TILE, TILE) / 2

func sync_vis(snap := false) -> void:
	if snap:
		vis.clear()
	while vis.size() < blobs.size():
		vis.append(vis[0] if vis.size() > 0 else tile_center(blobs[0]))
	while vis.size() > blobs.size():
		vis.pop_back()

func _process(delta: float) -> void:
	if on_title:
		title_t += delta
		queue_redraw()
		return
	if vis.size() != blobs.size():
		return
	var changed := false
	for i in vis.size():
		var target := tile_center(blobs[i])
		if vis[i] != target:
			if vis[i].distance_to(target) < 0.5:
				vis[i] = target
			else:
				vis[i] = vis[i].lerp(target, 1.0 - exp(-delta * 18.0))
			changed = true
	if changed:
		queue_redraw()

func start_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(Vector2(vp.x / 2 - 130, vp.y * 0.7), Vector2(260, 70))

func draw_title() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color("1b1b27"))
	draw_string(ThemeDB.fallback_font, Vector2(0, vp.y * 0.55), "Twofold", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 96, Color("e8e8f0"))
	var r := start_rect()
	var hover := r.has_point(get_local_mouse_position())
	var box := StyleBoxFlat.new()
	box.bg_color = Color("7be3a3") if hover else Color("5fd38d")
	box.set_corner_radius_all(14)
	draw_style_box(box, r)
	draw_string(font, Vector2(r.position.x, r.position.y + 47), "Start", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color("1b1b27"))

func _draw() -> void:
	if on_title:
		draw_title()
		return
	var size := Vector2(TILE, TILE)
	for y in level.size():
		for x in level[y].length():
			var pos := Vector2i(x, y)
			var tex := TEX_WALL if walls.has(pos) else TEX_FLOOR
			draw_texture_rect(tex, Rect2(OFFSET + Vector2(pos) * TILE, size), false)
	for g in goals:
		var tex := TEX_GOAL_LIT if blobs.has(g) else TEX_GOAL
		draw_texture_rect(tex, Rect2(OFFSET + Vector2(g) * TILE, size), false)
	for b in buttons:
		var c:= tile_center(b)
		draw_rect(Rect2(c - Vector2(20, 20), Vector2(40, 40)), Color("ffb4a2") if blobs.has(b) else Color("e07a5f"))
	var is_open := doors_open()
	for d in doors.keys():
		var r := Rect2(OFFSET + Vector2(d) * TILE, Vector2(TILE - 2, TILE - 2))
		if is_open:
			draw_rect(r, Color("e07a5f"), false, 3.0)
		else:
			draw_rect(r, Color("e07a5f"))
	for v in vis:
		draw_texture_rect(TEX_BLOB, Rect2(v - size / 2, size), false)
	draw_string(ThemeDB.fallback_font, Vector2(100, 40), "Level %d / %d" % [current + 1, levels.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	if won:
		var msg := "Solved! Space for next level, R to replay" if current < levels.size() - 1 else "All levels done! R to replay"
		draw_string(ThemeDB.fallback_font, Vector2(100, 80), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
