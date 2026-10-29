extends Control
## Sliding puzzle board, drawn like the web version: a top band (spare slot left, stats middle, goal thumbnail right)
## over an N×N grid, inside a rounded panel with an accent outline around the playable area.
## pieces[0..N*N-1] are grid positions; pieces[N*N] is the spare slot (row -1, column 0). Values are tile ids; -1 is empty.

signal moved
signal rejected
signal solved
signal thumb_pressed

const Palette = preload("res://scripts/palette.gd")
const EMPTY := -1
const PAD := 13.0  # Space for the panel drawn around the board.

var texture: Texture2D
var grid_size := 3
var pieces: Array[int] = []
var move_count := 0
var is_solved := false
var show_numbers := false:
	set(value):
		show_numbers = value
		queue_redraw()
var time_text := "0:00":
	set(value):
		if value != time_text:
			time_text = value
			queue_redraw()

var _shown := {}  # tile id -> drawn position in cells (column, band row); animates toward _target.
var _target := {}
var _shake := {}  # tile id -> seconds of shake left
var _solve_t := 0.0  # 0 = separate pieces, 1 = one seamless picture
var _peek := 0.0
var _peek_on := false
var _press_pos := Vector2.ZERO
var _press_cell := -1
var _pressing := false
var _dragging := false
var _drag_tile := -1
var _drag_position := Vector2.ZERO
var _drag_start_position := Vector2.ZERO
var _drag_axis := Vector2.ZERO
var _drag_path_tiles: Array[int] = []
var _drag_invalid := false
var _drag_feedback_sent := false
var _thumb_scale := 1.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = false
	resized.connect(queue_redraw)

# --- Public API ---

func setup(new_texture: Texture2D, new_grid_size: int, saved_pieces: Array = [], moves: int = 0, was_solved: bool = false) -> void:
	texture = new_texture
	grid_size = clampi(new_grid_size, 3, 6)
	if _is_valid_pieces(saved_pieces):
		pieces.assign(saved_pieces)
		move_count = maxi(0, moves)
		is_solved = was_solved and _check_solved()
		_solve_t = 1.0 if is_solved else 0.0
		_snap()
	else:
		shuffle()

func shuffle() -> void:
	_reset_solved()
	var previous := -1
	while true:
		for _step in range(grid_size * grid_size * 30):
			var gap := pieces.find(EMPTY)
			var options := _neighbors(gap).filter(func(p): return p != previous)
			if options.is_empty():
				options = _neighbors(gap)  # The spare slot has a single neighbour.
			previous = gap
			_slide(options[randi() % options.size()])
		var in_place := 0
		for i in range(grid_size * grid_size):
			if pieces[i] == i:
				in_place += 1
		if not _check_solved() and not (pieces[grid_size * grid_size] == EMPTY and in_place > grid_size * grid_size / 2.0):
			break
	move_count = 0
	is_solved = false
	_solve_t = 0.0
	_shake.clear()
	_snap()

func get_state() -> Dictionary:
	return {"grid_size": grid_size, "pieces": pieces.duplicate(), "moves": move_count, "solved": is_solved}

func set_peek(on: bool) -> void:
	_peek_on = on
	set_process(true)

## Keyboard play: move the piece next to the gap in the given direction into it.
func key_move(dr: int, dc: int) -> void:
	var gap := _coord(pieces.find(EMPTY))
	var p := _at(gap.y + dr, gap.x + dc)
	if p >= 0:
		_try_move(p)

# --- Rules ---

func _coord(p: int) -> Vector2i:
	if p == grid_size * grid_size:
		return Vector2i(0, -1)
	return Vector2i(p % grid_size, p / grid_size)

func _at(r: int, col: int) -> int:
	if col < 0 or col >= grid_size or r >= grid_size or r < -1:
		return -1
	if r == -1:
		return grid_size * grid_size if col == 0 else -1
	return r * grid_size + col

func _neighbors(p: int) -> Array:
	var c := _coord(p)
	var result := []
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n := _at(c.y + d.y, c.x + d.x)
		if n >= 0:
			result.append(n)
	return result

## Slide every piece between p and the gap, if they share a row or column.
func _slide(p: int) -> bool:
	var g := pieces.find(EMPTY)
	if p < 0 or p == g:
		return false
	var a := _coord(g)
	var b := _coord(p)
	if a.x != b.x and a.y != b.y:
		return false
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var cur := a
	while cur != b:
		if _at(cur.y + step.y, cur.x + step.x) < 0 or _at(cur.y, cur.x) < 0:
			return false
		cur += step
	cur = a
	while cur != b:
		var nxt := cur + step
		pieces[_at(cur.y, cur.x)] = pieces[_at(nxt.y, nxt.x)]
		cur = nxt
	pieces[p] = EMPTY
	return true

func _try_move(p: int) -> void:
	if is_solved or p < 0 or p >= pieces.size() or pieces[p] == EMPTY:
		return
	if not _slide(p):
		_reject(p)
		return
	move_count += 1
	_update_targets()
	is_solved = _check_solved()
	moved.emit()
	if is_solved:
		solved.emit()

func _reject(p: int, buzz: bool = true) -> void:
	var tile := pieces[p]
	if tile == EMPTY:
		return
	_shake[tile] = 0.26
	set_process(true)
	if buzz:
		rejected.emit()

func _check_solved() -> bool:
	if pieces.size() != grid_size * grid_size + 1 or pieces[grid_size * grid_size] != EMPTY:
		return false
	for i in range(grid_size * grid_size):
		if pieces[i] != i:
			return false
	return true

func _reset_solved() -> void:
	pieces.clear()
	for i in range(grid_size * grid_size):
		pieces.append(i)
	pieces.append(EMPTY)

func _is_valid_pieces(value: Array) -> bool:
	if value.size() != grid_size * grid_size + 1:
		return false
	var sorted: Array = value.duplicate()
	sorted.sort()
	if int(sorted[0]) != EMPTY:
		return false
	for i in range(1, sorted.size()):
		if int(sorted[i]) != i - 1:
			return false
	return true

# --- Animation ---

func _update_targets() -> void:
	_target.clear()
	for p in pieces.size():
		if pieces[p] != EMPTY:
			var c := _coord(p)
			_target[pieces[p]] = Vector2(c.x, c.y + 1)
	set_process(true)

func _snap() -> void:
	_update_targets()
	_shown = _target.duplicate()
	queue_redraw()

func _process(delta: float) -> void:
	var busy := false
	var k := 1.0 - exp(-delta * 32.0)
	for tile in _target:
		var shown: Vector2 = _shown.get(tile, _target[tile])
		var goal: Vector2 = _target[tile]
		if shown.distance_squared_to(goal) > 0.00001:
			_shown[tile] = shown.lerp(goal, k)
			busy = true
		else:
			_shown[tile] = goal
	for tile in _shake.keys():
		_shake[tile] -= delta
		if _shake[tile] <= 0.0:
			_shake.erase(tile)
		busy = true
	var solve_goal := 1.0 if is_solved else 0.0
	if not is_equal_approx(_solve_t, solve_goal):
		_solve_t = move_toward(_solve_t, solve_goal, delta / 0.3)
		busy = true
	var peek_goal := 1.0 if _peek_on else 0.0
	if not is_equal_approx(_peek, peek_goal):
		_peek = move_toward(_peek, peek_goal, delta / 0.18)
		busy = true
	var thumb_goal := 0.95 if _pressing and _press_cell == -3 else 1.0
	if not is_equal_approx(_thumb_scale, thumb_goal):
		_thumb_scale = move_toward(_thumb_scale, thumb_goal, delta / 0.15 * 0.05)
		busy = true
	queue_redraw()
	if not busy:
		set_process(false)

# --- Layout and drawing ---

func _metrics() -> Dictionary:
	var cell := minf((size.x - PAD * 2.0) / grid_size, (size.y - PAD * 2.0) / (grid_size + 1))
	cell = maxf(cell, 1.0)
	var board_size := Vector2(cell * grid_size, cell * (grid_size + 1))
	return {"origin": ((size - board_size) / 2.0).floor(), "cell": cell, "size": board_size}

func _thumb_rect(m: Dictionary) -> Rect2:
	var side := maxf(m.cell - 6.0, 44.0)
	return Rect2(m.origin + Vector2(m.size.x - side, 0), Vector2(side, side))

func _draw() -> void:
	if texture == null or pieces.is_empty():
		return
	var c: Dictionary = Palette.c
	var m := _metrics()
	var o: Vector2 = m.origin
	var cell: float = m.cell
	var w: float = m.size.x
	var h: float = m.size.y

	# Panel behind the board.
	var panel := Palette.box(c.panel, 22, c.line, 1)
	Palette.shadow(panel, Color(0.094, 0.239, 0.188, 0.13), 22, Vector2(0, 10))
	draw_style_box(panel, Rect2(o, m.size).grow(PAD - 3.0))

	# Wells: the grid area and the spare slot above its first column.
	var well_grid := Palette.box(c.well, 13)
	well_grid.corner_radius_top_left = 0
	draw_style_box(well_grid, Rect2(o + Vector2(0, cell), Vector2(w, h - cell)))
	var well_slot := Palette.box(c.well, 13)
	well_slot.corner_radius_bottom_left = 0
	well_slot.corner_radius_bottom_right = 0
	draw_style_box(well_slot, Rect2(o, Vector2(cell, cell + 1.0)))
	var dash := Rect2(o, Vector2(cell, cell)).grow(-7.0)
	for edge in [[dash.position, Vector2(dash.end.x, dash.position.y)], [Vector2(dash.end.x, dash.position.y), dash.end],
			[dash.end, Vector2(dash.position.x, dash.end.y)], [Vector2(dash.position.x, dash.end.y), dash.position]]:
		draw_dashed_line(edge[0], edge[1], c.line, 2.0, 6.0)

	_draw_stats(Rect2(o + Vector2(cell, 0), Vector2(w - cell * 2.0, cell)), w)
	_draw_thumb(_thumb_rect(m))

	# Pieces.
	var inset := lerpf(2.0, 0.0, _solve_t)
	var radius := lerpf(8.0, 0.0, _solve_t)
	var piece_uv := Vector2.ONE / grid_size
	var tile_order: Array = _shown.keys()
	if _dragging and tile_order.has(_drag_tile):
		tile_order.erase(_drag_tile)
		tile_order.append(_drag_tile)  # Draw the held tile over its neighbours.
	for tile in tile_order:
		var shown: Vector2 = _shown[tile]
		var tile_position: Vector2 = o + shown * cell
		if _dragging and _drag_path_tiles.has(tile):
			tile_position += _drag_position - _drag_start_position
		var rect := Rect2(tile_position, Vector2(cell, cell)).grow(-inset)
		if _shake.has(tile):
			var phase: float = 1.0 - _shake[tile] / 0.26
			rect.position.x += sin(phase * PI * 3.0) * 4.0 * (1.0 - phase)
		if _solve_t < 1.0:
			var face := Palette.box(c.well, radius)
			Palette.shadow(face, Color(0.055, 0.173, 0.141, 0.16 * (1.0 - _solve_t)), 5, Vector2(0, 2))
			draw_style_box(face, rect)
		var home := Vector2(tile % grid_size, tile / grid_size) * piece_uv
		Palette.draw_image(self, texture, rect, Rect2(home, piece_uv), [radius, radius, radius, radius])
		if show_numbers and _solve_t < 0.5:
			var num_font := Palette.font(500, true)
			var num_size := int(clampf(cell * 0.13, 12.0, 17.0))
			var label := str(tile + 1)
			var text_size := num_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, num_size)
			var badge := Rect2(rect.position + Vector2(6, 5), Vector2(text_size.x + 12.0, num_size * 1.35))
			draw_style_box(Palette.box(Color(0, 0, 0, 0.55), 5), badge)
			Palette.draw_text(self, label, badge.get_center().x, badge.position.y + (badge.size.y - num_font.get_height(num_size)) / 2.0, num_font, num_size, Color.WHITE)

	# Peek overlay: the finished picture over the grid.
	if _peek > 0.0:
		Palette.draw_image(self, texture, Rect2(o + Vector2(0, cell), Vector2(w, h - cell)), Rect2(0, 0, 1, 1), [0, 13, 13, 13], Color(1, 1, 1, _peek))

	_draw_frame(o, cell, w, h)

func _draw_stats(area: Rect2, board_width: float) -> void:
	var c: Dictionary = Palette.c
	var num_font := Palette.font(800, true)
	var label_font := Palette.font(800)
	var num_size := int(clampf(board_width * 0.06, 19.0, 27.0))
	var label_size := 11
	var stats := [[str(move_count), "MOVES"], [time_text, "TIME"]]
	var widths := []
	for s in stats:
		widths.append(maxf(num_font.get_string_size(s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x,
			label_font.get_string_size(s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x))
	var stat_h := num_font.get_height(num_size) + label_font.get_height(label_size)
	var side_by_side: bool = area.size.x - 12.0 >= widths[0] + widths[1] + 22.0
	var centers := []
	if side_by_side:
		var total: float = widths[0] + widths[1] + 22.0
		var left := area.get_center().x - total / 2.0
		centers = [Vector2(left + widths[0] / 2.0, area.get_center().y - stat_h / 2.0),
			Vector2(left + widths[0] + 22.0 + widths[1] / 2.0, area.get_center().y - stat_h / 2.0)]
	else:
		var top := area.get_center().y - (stat_h * 2.0 + 5.0) / 2.0
		centers = [Vector2(area.get_center().x, top), Vector2(area.get_center().x, top + stat_h + 5.0)]
	for i in 2:
		Palette.draw_text(self, stats[i][0], centers[i].x, centers[i].y, num_font, num_size, c.fg)
		Palette.draw_text(self, stats[i][1], centers[i].x, centers[i].y + num_font.get_height(num_size), label_font, label_size, c.muted)

func _draw_thumb(rect: Rect2) -> void:
	var c: Dictionary = Palette.c
	if _thumb_scale < 1.0:
		var scaled := rect.size * _thumb_scale
		rect = Rect2(rect.get_center() - scaled / 2.0, scaled)
	var back := Palette.box(c.panel, 13)
	Palette.shadow(back, Color(0.063, 0.176, 0.141, 0.16), 8, Vector2(0, 4))
	draw_style_box(back, rect)
	Palette.draw_image(self, texture, rect.grow(-3.0), Rect2(0, 0, 1, 1), [10, 10, 10, 10])
	var outline := Palette.box(Color.TRANSPARENT, 14, c.line, 1)
	outline.draw_center = false
	draw_style_box(outline, rect.grow(1.0))
	var badge_font := Palette.font(800)
	var badge_size := 10
	var text_w := badge_font.get_string_size("GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, badge_size).x
	var badge := Rect2(rect.position + Vector2(6, rect.size.y - 6.0 - badge_size * 1.6), Vector2(text_w + 12.0, badge_size * 1.6))
	draw_style_box(Palette.box(Color(0, 0, 0, 0.62), 6), badge)
	Palette.draw_text(self, "GOAL", badge.get_center().x, badge.position.y + (badge.size.y - badge_font.get_height(badge_size)) / 2.0, badge_font, badge_size, Color.WHITE)

## Outline around the spare slot + grid only (thumbnail excluded), matching the wells' rounded corners.
func _draw_frame(o: Vector2, cell: float, w: float, h: float) -> void:
	var r := 12.0
	var e := 1.5
	var left := o.x - e
	var top := o.y - e
	var right := o.x + w + e
	var bottom := o.y + h + e
	var slot_right := o.x + cell + e
	var band_bottom := o.y + cell - e
	var pts := PackedVector2Array()
	_arc(pts, Vector2(slot_right - r, top + r), r, -PI / 2.0, 0.0)
	pts.append(Vector2(slot_right, band_bottom))
	_arc(pts, Vector2(right - r, band_bottom + r), r, -PI / 2.0, 0.0)
	_arc(pts, Vector2(right - r, bottom - r), r, 0.0, PI / 2.0)
	_arc(pts, Vector2(left + r, bottom - r), r, PI / 2.0, PI)
	_arc(pts, Vector2(left + r, top + r), r, PI, PI * 1.5)
	pts.append(pts[0])
	draw_polyline(pts, Palette.c.accent, 3.0, true)

func _arc(pts: PackedVector2Array, center: Vector2, r: float, from: float, to: float) -> void:
	for step in 9:
		var angle := lerpf(from, to, step / 8.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)

# --- Input: tap a piece, swipe it toward the gap, or tap the goal thumbnail ---

func _cell_at(pos: Vector2) -> int:
	var m := _metrics()
	if _thumb_rect(m).has_point(pos):
		return -3
	var local: Vector2 = (pos - m.origin) / m.cell
	if local.x < 0 or local.y < 0 or local.x >= grid_size or local.y >= grid_size + 1:
		return -1
	return _at(int(local.y) - 1, int(local.x))

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_pressing = true
		_press_pos = mb.position
		_press_cell = _cell_at(mb.position)
		_dragging = false
		_drag_tile = -1
		_drag_invalid = false
		_drag_feedback_sent = false
		if _press_cell >= 0 and _press_cell < pieces.size() and pieces[_press_cell] != EMPTY:
			var m := _metrics()
			var shown: Vector2 = _shown.get(pieces[_press_cell], Vector2.ZERO)
			var tile_top_left: Vector2 = m.origin + shown * m.cell
			_drag_tile = pieces[_press_cell]
			_drag_position = tile_top_left
			_drag_start_position = tile_top_left
			var piece_coord := _coord(_press_cell)
			var gap_coord := _coord(pieces.find(EMPTY))
			if piece_coord.y == gap_coord.y:
				_drag_axis = Vector2(signi(gap_coord.x - piece_coord.x), 0)
			elif piece_coord.x == gap_coord.x:
				_drag_axis = Vector2(0, signi(gap_coord.y - piece_coord.y))
			else:
				_drag_axis = Vector2.ZERO
			_drag_path_tiles.clear()
			if _drag_axis == Vector2.ZERO:
				_drag_path_tiles.append(_drag_tile)
			else:
				var path_step := Vector2i(signi(gap_coord.x - piece_coord.x), signi(gap_coord.y - piece_coord.y))
				var path_cell := piece_coord
				while path_cell != gap_coord:
					var path_index := _at(path_cell.y, path_cell.x)
					if path_index >= 0 and pieces[path_index] != EMPTY:
						_drag_path_tiles.append(pieces[path_index])
					path_cell += path_step
		set_process(true)
		return
	if not _pressing:
		return
	if _drag_tile >= 0:
		_update_drag(mb.position)
	_pressing = false
	set_process(true)
	var d: Vector2 = mb.position - _press_pos
	if _press_cell == -3:
		_drag_tile = -1
		_dragging = false
		if _cell_at(mb.position) == -3:
			thumb_pressed.emit()
		return
	if _press_cell < 0 or _press_cell >= pieces.size() or pieces[_press_cell] == EMPTY:
		_dragging = false
		_drag_tile = -1
		return
	if maxf(absf(d.x), absf(d.y)) < 16.0:
		_dragging = false
		_drag_tile = -1
		_drag_invalid = false
		_drag_feedback_sent = false
		_try_move(_press_cell)
		queue_redraw()
		return
	if is_solved:
		_dragging = false
		_drag_tile = -1
		queue_redraw()
		return
	var ok := false
	if _dragging:
		var along := d.dot(_drag_axis)
		var perpendicular := (d - _drag_axis * along).length()
		ok = _drag_axis != Vector2.ZERO and along >= 16.0 and along >= perpendicular
	else:
		var from := _coord(_press_cell)
		var to := _coord(pieces.find(EMPTY))
		if absf(d.x) > absf(d.y):
			ok = from.y == to.y and signf(d.x) == signf(to.x - from.x)
		else:
			ok = from.x == to.x and signf(d.y) == signf(to.y - from.y)
	if ok:
		if _dragging:
			_apply_drag_preview_to_shown()
		_dragging = false
		_drag_tile = -1
		_drag_invalid = false
		_drag_feedback_sent = false
		_try_move(_press_cell)
	else:
		if _dragging:
			_apply_drag_preview_to_shown()
		_dragging = false
		_drag_tile = -1
		_drag_invalid = false
		_reject(_press_cell, not _drag_feedback_sent)
		_drag_feedback_sent = false
	queue_redraw()

func _apply_drag_preview_to_shown() -> void:
	if _drag_path_tiles.is_empty():
		return
	var m := _metrics()
	var offset: Vector2 = (_drag_position - _drag_start_position) / m.cell
	for tile in _drag_path_tiles:
		if _shown.has(tile):
			_shown[tile] = _shown[tile] + offset

func _input(event: InputEvent) -> void:
	if not _pressing:
		return
	var motion := event as InputEventMouseMotion
	var screen_drag := event as InputEventScreenDrag
	if _press_cell < 0 or _press_cell >= pieces.size() or _drag_tile < 0:
		return
	if motion != null:
		_update_drag((make_input_local(motion) as InputEventMouseMotion).position)
	elif screen_drag != null:
		_update_drag((make_input_local(screen_drag) as InputEventScreenDrag).position)

func _update_drag(pointer: Vector2) -> void:
	var movement := pointer - _press_pos
	if not _dragging and movement.length() >= 16.0:
		_dragging = true
	if not _dragging:
		return
	var along := movement.dot(_drag_axis)
	var perpendicular := movement - _drag_axis * along
	var cell: float = _metrics().cell
	var tolerance := maxf(10.0, cell * 0.12)
	var perpendicular_limit := maxf(tolerance, maxf(along, 0.0))
	var invalid := _drag_axis == Vector2.ZERO or along < -tolerance or perpendicular.length() > perpendicular_limit
	if not invalid:
		_drag_position = _drag_start_position + _drag_axis * clampf(along, 0.0, cell)
	if invalid and not _drag_invalid:
		_shake[_drag_tile] = 0.16
		set_process(true)
		if not _drag_feedback_sent:
			rejected.emit()
			_drag_feedback_sent = true
	_drag_invalid = invalid
	queue_redraw()
