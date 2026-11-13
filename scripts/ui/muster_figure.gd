class_name MusterFigure
extends Control
## A companion standing in the barracks. The art is a cut-out with no background, so they stand free
## against the wall behind the muster rail, every head the same size (`CompanionData.figure_scale`),
## and their name and health are written on the rail in front of them. On the bench they are smaller
## and dimmer, head and shoulders above the board. An empty place in the line is a chalk outline.
## Each figure is kept inside its own place, so nobody's art covers a neighbour.
## A figure can be picked up and set down on another place or on the bench; whatever it is set down on
## emits `dropped` with the companion that was carried.

signal pressed
signal dropped(carried: RunCompanion)

## One place in the line (the line holds RunConfig.MAX_FIELDED of them, four).
const W := 262.0
const H := 440.0
## How far down the slot the rail starts: the art is cut off there.
const PORTRAIT_H := 372.0
const BENCH_W := 150.0
const BENCH_H := 206.0
const BENCH_PORTRAIT_H := 150.0
## Height the art is drawn at for a figure_scale of 1, and how far down the slot the face sits.
const ART := 440.0
const FACE_Y := 86.0
const BENCH_ART := 300.0
const BENCH_FACE_Y := 66.0
## How far inside its place a figure in the line stops (half a post), and how wide the fade at a cut is.
const EDGE_INSET := 6.0
const EDGE_FADE := 22.0

var companion: RunCompanion
## Whether figures may be carried right now (not once the day's battle has begun).
var can_carry := true

var _bench := false
var _selected := false
var _hover := false
var _drop_hot := false
var _heal_to := -1
var _hp := SlantBar.new()
var _over := Control.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hp.visible = false
	add_child(_hp)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above the neighbours' art, which runs over into this place.
	_over.z_index = 1
	_over.draw.connect(_draw_over)
	add_child(_over)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_drop_hot = false
		queue_redraw())


## `c` null: an empty place in the line. `bench`: drawn small, for the reserve.
func setup(c: RunCompanion, bench: bool = false) -> void:
	companion = c
	_bench = bench
	custom_minimum_size = Vector2(BENCH_W, BENCH_H) if bench else Vector2(W, H)
	size = custom_minimum_size
	_hp.visible = c != null
	if c == null:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = "An empty place in the line. Carry someone here from the bench."
		queue_redraw()
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rail := _rail_y()
	_hp.position = Vector2(14, rail + 34.0) if bench else Vector2(24, rail + 40.0)
	_hp.size = Vector2(size.x - _hp.position.x * 2.0, 16.0 if bench else 20.0)
	_hp.font_size = 12 if bench else 15
	_hp.fill_color = UiTheme.HP if c.hp * 3 >= c.max_hp() else UiTheme.INJURED
	_hp.set_values(c.hp, c.max_hp(), false)
	tooltip_text = PartyMedallion.describe(c)
	queue_redraw()


func set_selected(v: bool) -> void:
	_selected = v
	queue_redraw()


## While a heal is being aimed: the HP it would bring this companion to. -1 clears it.
func set_heal_preview(hp_after: int) -> void:
	_heal_to = hp_after
	_hp.set_heal_preview(float(hp_after) if hp_after >= 0 else -INF)
	_over.queue_redraw()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and companion != null \
			and Rect2(Vector2.ZERO, size).has_point(mb.position):
		accept_event()
		pressed.emit()


# ---------------------------------------------------------------- carrying

func _get_drag_data(_at_position: Vector2) -> Variant:
	if companion == null or not can_carry:
		return null
	var c := companion
	var preview := Control.new()
	preview.draw.connect(func() -> void:
		preview.draw_circle(Vector2(0, 2), 50.0, Color(0, 0, 0, 0.5))
		preview.draw_circle(Vector2.ZERO, 48.0, UiTheme.INK)
		UiIcons.portrait(preview, Vector2.ZERO, 44.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02),
			0.3 / c.data.figure_scale)
		preview.draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 40, UiTheme.GOLD, 2.5, true))
	set_drag_preview(preview)
	return {"companion": c}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = can_carry and data is Dictionary and (data as Dictionary).get("companion") is RunCompanion \
		and (data as Dictionary)["companion"] != companion
	if ok != _drop_hot:
		_drop_hot = ok
		queue_redraw()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_hot = false
	queue_redraw()
	dropped.emit((data as Dictionary)["companion"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_hot:
		_drop_hot = false
		queue_redraw()


# ---------------------------------------------------------------- drawing

## Where the art is cut off and the rail (or the bench's board) begins.
func _rail_y() -> float:
	return BENCH_PORTRAIT_H if _bench else PORTRAIT_H


func _draw() -> void:
	var rail := _rail_y()
	if companion == null:
		# Chalk on the wall where someone could stand.
		var chalk := Color(UiTheme.TEXT, 0.55 if _drop_hot else 0.22)
		var r := Rect2(26.0, 30.0, size.x - 52.0, rail - 44.0)
		_dashed(r, chalk)
		UiTheme.draw_text(self, UiTheme.italic_font(), Vector2(0, r.get_center().y - 12.0), "an empty place", 18, chalk, 0, size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		if _drop_hot:
			draw_rect(r, Color(UiTheme.GOLD, 0.1))
		return

	# Light on the wall behind whoever is picked out.
	var glow := Color(0, 0, 0, 0)
	if _heal_to >= 0:
		glow = UiTheme.HEAL
	elif _drop_hot:
		glow = Color("fff0c0")
	elif _selected:
		glow = UiTheme.GOLD
	if glow.a > 0.0:
		var gc := Vector2(size.x * 0.5, rail * 0.5)
		var reach := rail * 0.5
		for i in 12:
			var f := 1.0 - i / 12.0
			_ellipse(gc, Vector2(size.x * 0.66, reach) * f, Color(glow, 0.032))

	var tint := Color.WHITE
	if _bench:
		tint = Color(0.72, 0.7, 0.68) if not (_selected or _hover) else Color(0.9, 0.88, 0.86)
	elif not (_selected or _hover or _drop_hot or _heal_to >= 0):
		tint = Color(0.86, 0.85, 0.84)
	_draw_art(tint, rail)

	# The plate on the rail: lit for whoever is picked out.
	var plate := Rect2(6.0, rail + 4.0, size.x - 12.0, size.y - rail - 8.0)
	var font := UiTheme.display_font()
	var ink := UiTheme.MUTED if _bench else UiTheme.TEXT
	if glow.a > 0.0:
		UiTheme.draw_frame(self, plate, Color(UiTheme.PANEL_HI, 0.96), glow, 2.5, false)
		ink = ActionButton.LIT_INK
	elif _hover:
		UiTheme.draw_frame(self, plate, Color(UiTheme.PANEL, 0.9), Color(UiTheme.GOLD, 0.7), 2.0, false)
		ink = ActionButton.LIT_INK
	UiTheme.draw_text(self, font, Vector2(0, rail + (6.0 if _bench else 8.0)), companion.display_name(), 18 if _bench else 24, ink, 4,
		size.x, HORIZONTAL_ALIGNMENT_CENTER)


## The cut-out, with the face over the middle of the place, down to the rail. It is kept inside the
## place: whatever would run over into a neighbour's (a blade, a cloak, long hair) is cut off, fading
## out over EDGE_FADE so the cut is soft. In the line a timber post stands over each cut.
func _draw_art(tint: Color, rail: float) -> void:
	var tex := companion.data.portrait
	if tex == null:
		return
	var ts := tex.get_size()
	var h := (BENCH_ART if _bench else ART) * companion.data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var face := Vector2(size.x * 0.5, BENCH_FACE_Y if _bench else FACE_Y)
	var top_left := face - companion.data.portrait_focus * art
	# Someone short stands on the floor behind the rail, not in the air above it.
	top_left.y = maxf(top_left.y, rail - art.y)
	var inset := 0.0 if _bench else EDGE_INSET
	var left := maxf(top_left.x, inset)
	var right := minf(top_left.x + art.x, size.x - inset)
	var top := top_left.y
	var bottom := minf(top_left.y + art.y, rail)
	if right <= left or bottom <= top:
		return
	var fade := minf(EDGE_FADE, (right - left) * 0.5)
	var xs: Array[float] = [left, left + fade, right - fade, right]
	var alpha: Array[float] = [0.0, 1.0, 1.0, 0.0]
	# Where the art itself ends inside the place there is nothing to fade.
	if top_left.x >= inset:
		alpha[0] = 1.0
	if top_left.x + art.x <= size.x - inset:
		alpha[3] = 1.0
	for i in 3:
		if xs[i + 1] - xs[i] < 0.5:
			continue
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for corner: Vector2i in [Vector2i(i, 0), Vector2i(i + 1, 0), Vector2i(i + 1, 1), Vector2i(i, 1)]:
			var at := Vector2(xs[corner.x], top if corner.y == 0 else bottom)
			pts.append(at)
			uvs.append((at - top_left) / art)
			cols.append(Color(tint, alpha[corner.x]))
		draw_polygon(pts, cols, uvs, tex)


## Over the figure: what a heal being aimed would do.
func _draw_over() -> void:
	if _heal_to < 0 or companion == null:
		return
	var font := UiTheme.display_font()
	var band := Rect2(14.0, _rail_y() - 38.0, size.x - 28.0, 30.0)
	UiTheme.draw_frame(_over, band, Color(UiTheme.INK, 0.9), Color(UiTheme.HEAL, 0.8), 1.5, false)
	UiTheme.draw_text(_over, font, Vector2(band.position.x, band.position.y + (band.size.y - font.get_height(16)) * 0.5),
		"HP %d → %d" % [companion.hp, _heal_to], 16, UiTheme.HEAL, 0, band.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(c + Vector2.from_angle(TAU * i / 32.0) * r)
	draw_colored_polygon(pts, color)


func _dashed(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 10.0)
