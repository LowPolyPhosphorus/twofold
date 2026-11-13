extends Node2D

const TILE := 64
const OFFSET := Vector2.ZERO
const TEX_WALL := preload("res://art/wall.png")
const TEX_FLOOR := preload("res://art/floor.png")
const TEX_GOAL := preload("res://art/goal.png")
const TEX_GOAL_LIT := preload("res://art/goal_lit.png")
const TEX_BLOB := preload("res://art/blob.png")
const TEX_GATE := preload("res://art/gate.png")
const TEX_BUTTON := preload("res://art/button.png")
const TEX_BUTTON_PRESSED := preload("res://art/button-pressed.png")
const TEX_ICE := preload("res://art/ice.png")
const TEX_LOGO := preload("res://art/logo.png")
const GOAL_FRAMES := 17
const GOAL_FPS := 30.0
const SPLIT_FRAMES := 25
const SPLIT_FPS := 30.0
const PAUSE_LABELS := ["Resume", "Restart", "Quit to title"]

var paused := false
var split_frames: Array[Texture2D] = []
var split_anim := {}
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
var goal_frames: Array[Texture2D] = []
var goal_p := {}
var ice := {}
var lv := {}
var daily_mode := false
var daily_data := {}
var best_moves := 0
var daily_best := 0
var on_levels := false
var unlocked_cache := 0
var best_cache: Array[int] = []

func _ready() -> void:
	for i in range(1, GOAL_FRAMES + 1):
		goal_frames.append(load("res://art/goal-transition/goal-transition-%d.png" % i))
	for i in range(1, SPLIT_FRAMES + 1):
		split_frames.append(load("res://art/split-transition/split-transition-%d.png" % i))
	get_viewport().size_changed.connect(queue_redraw)
	current = mini(Save.unlocked(), levels.size() - 1)
	daily_best = Save.daily_moves(Generator.daily_seed())
	load_level()

func load_level() -> void:
	level = daily_data.rows if daily_mode else levels[current]
	lv = Rules.parse(level)
	refresh_best()
	walls.clear()
	goals.clear()
	blobs.clear()
	buttons.clear()
	doors.clear()
	history.clear()
	ice.clear()
	split_anim = {}
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
				"I": ice[pos] = true
	goal_p.clear()
	for g in goals:
		goal_p[g] = 0.0
	sync_vis(true)
	queue_redraw()

func check_win() -> void:
	won = Rules.is_won(lv, blobs)

func refresh_best() -> void:
	best_moves = Save.daily_moves(daily_data.day) if daily_mode else Save.best(current)

func save_win() -> void:
	if daily_mode:
		Save.record_daily(daily_data.day, history.size())
		daily_best = Save.daily_moves(daily_data.day)
	else:
		Save.record(current, history.size())
		Save.unlock(mini(current + 1, levels.size() - 1))
	refresh_best()

func doors_open() -> bool:
	return Rules.doors_open(lv, blobs)

func split() -> void:
	var d := Rules.split_dir(lv, blobs)
	if d == Vector2i.ZERO:
		return
	blobs.append(blobs[0] + d)
	split_anim = {"pos": blobs[0], "dir": d, "idx": blobs.size() - 1, "p": 0.0}

func _unhandled_input(event: InputEvent) -> void:
	if on_title:
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var m := get_local_mouse_position()
		if on_levels:
			var esc: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
			if esc or (click and back_rect().has_point(m)):
				on_levels = false
			elif click:
				for i in levels.size():
					if i <= unlocked_cache and level_cell(i).has_point(m):
						daily_mode = false
						current = i
						load_level()
						on_levels = false
						on_title = false
						break
			queue_redraw()
			return
		var key_hit: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE
		if click and daily_rect().has_point(m):
			if daily_data.is_empty() or daily_data.day != Generator.daily_seed():
				daily_data = Generator.daily()
			if not daily_data.is_empty():
				if not daily_mode:
					daily_mode = true
					load_level()
				on_title = false
				queue_redraw()
		elif click and levels_rect().has_point(m):
			open_levels()
		elif (click and start_rect().has_point(m)) or key_hit:
			if daily_mode:
				daily_mode = false
				load_level()
			on_title = false
			queue_redraw()
		return
	if paused:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			paused = false
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pm := get_local_mouse_position()
			if pause_rect(0).has_point(pm):
				paused = false
			elif pause_rect(1).has_point(pm):
				paused = false
				load_level()
			elif pause_rect(2).has_point(pm):
				paused = false
				on_title = true
		queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			paused = true
			queue_redraw()
			return
		if event.keycode == KEY_R:
			load_level()
			return
		if event.keycode == KEY_Z:
			if history.size() > 0:
				blobs.assign(history.pop_back())
				sync_vis()
				split_anim = {}
				won = false
				queue_redraw()
			return
	if not split_anim.is_empty():
		return
	if won:
		if event.is_action_pressed("ui_accept"):
			if daily_mode:
				on_title = true
				queue_redraw()
			elif current < levels.size() - 1:
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
		blobs.assign(Rules.slide(lv, blobs, dir))
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
	if won:
		save_win()
	queue_redraw()

func tile_center(p: Vector2i) -> Vector2:
	return OFFSET + Vector2(p) * TILE + Vector2(TILE, TILE) / 2

func board_scale() -> float:
	var vp := get_viewport_rect().size
	var board := Vector2(level[0].length(), level.size()) * TILE
	return minf(vp.x * 0.75 / board.x, vp.y * 0.75 / board.y)

func board_pos() -> Vector2:
	var vp := get_viewport_rect().size
	var board := Vector2(level[0].length(), level.size()) * TILE * board_scale()
	return (vp - board) / 2

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
	if paused: 
		queue_redraw()
		return
	if not split_anim.is_empty():
		split_anim.p += SPLIT_FPS * delta
		if split_anim.p >= SPLIT_FRAMES:
			var i: int = split_anim.idx
			if i < vis.size():
				vis[i] = tile_center(blobs[i])
			split_anim = {}
		queue_redraw()
	var goal_changed := false
	for g in goals:
		var p: float = goal_p[g]
		var np := clampf(p + (GOAL_FPS if blobs.has(g) else -GOAL_FPS) * delta, 0.0, float(GOAL_FRAMES))
		if np != p:
			goal_p[g] = np
			goal_changed = true
	if goal_changed:
		queue_redraw()
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
	return Rect2(Vector2(vp.x / 2 - 130, vp.y * 0.56), Vector2(260, 70))

func daily_rect() -> Rect2:
	var r := start_rect()
	return Rect2(start_rect().position + Vector2(0, 82), Vector2(260, 70))

func levels_rect() -> Rect2:
	return Rect2(start_rect().position + Vector2(0, 164), Vector2(260, 70))

func back_rect() -> Rect2:
	return Rect2(Vector2(40, 40), Vector2(140, 50))

func level_cell(i: int) -> Rect2:
	var vp := get_viewport_rect().size
	var cols := 5
	var cell := Vector2(110, 110)
	var gap := Vector2(16, 16)
	var rows := ceili(float(levels.size()) / cols)
	var total := Vector2(cols, rows) * cell + Vector2(cols - 1, rows - 1) * gap
	var origin := (vp - total) / 2 + Vector2(0, 30)
	return Rect2(origin + Vector2(i % cols, floori(float(i) / cols)) * (cell + gap), cell)

func draw_title() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color("0a0a0a"))
	var ls := TEX_LOGO.get_size()
	var space := start_rect().position.y
	var sc := minf(vp.x * 0.6 / ls.x, (space - 60.0) / ls.y)
	var lsz := ls * sc
	draw_texture_rect(TEX_LOGO, Rect2(Vector2((vp.x - lsz.x) / 2, (space - lsz.y) / 2), lsz), false)
	var r := start_rect()
	var hover := r.has_point(get_local_mouse_position())
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a0a0a") if hover else Color("ffffff")
	box.border_color = Color("ffffff")
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	draw_style_box(box, r)
	draw_string(font, Vector2(r.position.x, r.position.y + 47), ("Start" if current == 0 else "Continue  %d" % (current + 1)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color("ffffff") if hover else Color("0a0a0a"))
	var dr := daily_rect()
	var dhover := dr.has_point(get_local_mouse_position())
	var dbox := StyleBoxFlat.new()
	dbox.bg_color = Color("ffffff") if dhover else Color("0a0a0a")
	dbox.border_color = Color("ffffff")
	dbox.set_border_width_all(3)
	dbox.set_corner_radius_all(14)
	draw_style_box(dbox, dr)
	draw_string(font, Vector2(dr.position.x, dr.position.y + 47), "Daily", HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 32, Color("0a0a0a") if dhover else Color("ffffff"))
	var lr := levels_rect()
	var lhover := lr.has_point(get_local_mouse_position())
	var lbox := StyleBoxFlat.new()
	lbox.bg_color = Color("ffffff") if lhover else Color("0a0a0a")
	lbox.border_color = Color("ffffff")
	lbox.set_border_width_all(3)
	lbox.set_corner_radius_all(14)
	draw_style_box(lbox, lr)
	draw_string(font, Vector2(lr.position.x, lr.position.y + 47), "Levels", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 32, Color("0a0a0a") if lhover else Color("ffffff"))

func open_levels() -> void:
	unlocked_cache = Save.unlocked()
	best_cache.clear()
	for i in levels.size():
		best_cache.append(Save.best(i))
	on_levels = true
	queue_redraw()

func draw_levels() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var m := get_local_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, vp), Color("0a0a0a"))
	draw_string(font, Vector2(0, vp.y * 0.14), "Levels", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 48, Color("ffffff"))
	for i in levels.size():
		var r := level_cell(i)
		var playable := i <= unlocked_cache
		var hover := playable and r.has_point(m)
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffffff") if hover else Color("0a0a0a")
		box.border_color = Color("ffffff") if playable else Color("444444")
		box.set_border_width_all(3)
		box.set_corner_radius_all(14)
		draw_style_box(box, r)
		var fg := Color("444444")
		if playable:
			fg = Color("0a0a0a") if hover else Color("ffffff")
		draw_string(font, Vector2(r.position.x, r.position.y + 55), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, fg)
		if playable and best_cache[i] > 0:
			draw_string(font, Vector2(r.position.x, r.position.y + 90), "best %d" % best_cache[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, fg)
	var br := back_rect()
	var bhover := br.has_point(m)
	var bbox := StyleBoxFlat.new()
	bbox.bg_color = Color("ffffff") if bhover else Color("0a0a0a")
	bbox.border_color = Color("ffffff")
	bbox.set_border_width_all(3)
	bbox.set_corner_radius_all(12)
	draw_style_box(bbox, br)
	draw_string(font, Vector2(br.position.x, br.position.y + 35), "Back", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 24, Color("0a0a0a") if bhover else Color("ffffff"))

func pause_rect(i: int) -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(Vector2(vp.x / 2 - 130, vp.y * 0.4 + i * 90), Vector2(260, 70))

func draw_pause() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.08, 0.08, 0.8))
	draw_string(font, Vector2(0, vp.y * 0.3), "Paused", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 64, Color("ffffff"))
	for i in PAUSE_LABELS.size():
		var r := pause_rect(i)
		var hover := r.has_point(get_local_mouse_position())
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffffff") if hover else Color("d0d0d0")
		box.set_corner_radius_all(14)
		draw_style_box(box, r)
		draw_string(font, Vector2(r.position.x, r.position.y + 47), PAUSE_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color("141414"))

func _draw() -> void:
	if on_title:
		if on_levels:
			draw_levels()
		else:
			draw_title()
		return
	draw_set_transform(board_pos(), 0.0, Vector2.ONE * board_scale())
	var size := Vector2(TILE, TILE)
	for y in level.size():
		for x in level[y].length():
			var pos := Vector2i(x, y)
			var tex := TEX_WALL if walls.has(pos) else TEX_FLOOR
			draw_texture_rect(tex, Rect2(OFFSET + Vector2(pos) * TILE, size), false)
			if ice.has(pos):
				draw_texture_rect(TEX_ICE, Rect2(OFFSET + Vector2(pos) * TILE, size), false)
	for g in goals:
		var p: float = goal_p[g]
		var tex: Texture2D = TEX_GOAL if p < 1.0 else goal_frames[int(p) - 1]
		draw_texture_rect(tex, Rect2(OFFSET + Vector2(g) * TILE, size), false)
	for b in buttons:
		var tex: Texture2D = TEX_BUTTON_PRESSED if blobs.has(b) else TEX_BUTTON
		draw_texture_rect(tex, Rect2(OFFSET + Vector2(b) * TILE, size), false)
	var is_open := doors_open()
	for d in doors.keys():
		var a := 0.25 if is_open else 1.0
		draw_texture_rect(TEX_GATE, Rect2(OFFSET + Vector2(d) * TILE, size), false, Color(1, 1, 1, a))
	var animating := not split_anim.is_empty()
	for i in vis.size():
		if animating and (i == 0 or i == split_anim.idx):
			continue
		draw_texture_rect(TEX_BLOB, Rect2(vis[i] - size / 2, size), false)
	if animating:
		var tex: Texture2D = split_frames[mini(int(split_anim.p), SPLIT_FRAMES - 1)]
		var src := tex.get_size()
		var s := TILE / src.y
		var sp: Vector2i = split_anim.pos
		var board_xf := Transform2D(0.0, Vector2.ONE * board_scale(), 0.0, board_pos())
		var local_xf := Transform2D(Vector2(split_anim.dir).angle(), Vector2(s, s), 0.0, tile_center(sp))
		draw_set_transform_matrix(board_xf * local_xf)
		draw_texture(tex, -Vector2(src.y, src.y) / 2)
		draw_set_transform_matrix(board_xf)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label := "Level %d / %d" % [current + 1, levels.size()]
	if daily_mode:
		label = "Daily par%d moves %d" % [daily_data.par, history.size()]
	if best_moves > 0:
		label += "  best %d" % best_moves
	draw_string(ThemeDB.fallback_font, Vector2(100, 40), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	if won:
		var msg := "Solved! Space for next level, R to replay" if current < levels.size() - 1 else "All levels done! R to replay"
		if daily_mode:
			msg = "Daily solved in %d (par %d)! Space for title, R to replay" % [history.size(), daily_data.par]
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(100, 80), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	if paused:
		draw_pause()
