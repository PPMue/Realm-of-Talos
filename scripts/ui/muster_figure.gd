class_name MusterFigure
extends Control
## A companion standing in the barracks: a tall portrait with their name and health under it, in the
## line or (smaller and dimmer) on the bench. An empty place in the line is a chalk outline.
## A figure can be picked up and set down on another place or on the bench; whatever it is set down on
## emits `dropped` with the companion that was carried.

signal pressed
signal dropped(carried: RunCompanion)

const W := 196.0
const PORTRAIT_H := 372.0
const H := 440.0
const BENCH_W := 132.0
const BENCH_PORTRAIT_H := 132.0
const BENCH_H := 190.0

var companion: RunCompanion
## Whether figures may be carried right now (not once the day's battle has begun).
var can_carry := true

var _bench := false
var _selected := false
var _hover := false
var _drop_hot := false
var _heal_to := -1
var _art := SlantPanel.new()
var _hp := SlantBar.new()
var _over := Control.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_art.border_width = 0.0
	_art.shade = 0.75
	_art.visible = false
	add_child(_art)
	_hp.visible = false
	add_child(_hp)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_art.visible = c != null
	_hp.visible = c != null
	if c == null:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = "An empty place in the line. Carry someone here from the bench."
		queue_redraw()
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ph := BENCH_PORTRAIT_H if bench else PORTRAIT_H
	_art.position = Vector2(5, 5)
	_art.size = Vector2(size.x - 10.0, ph)
	_art.texture = c.data.portrait
	# The bench shows faces; the line shows the whole figure.
	_art.zoom = 2.2 if bench else 1.0
	_art.focus = c.data.portrait_focus + (Vector2(0.0, 0.04) if bench else Vector2(0.0, 0.26))
	_art.tint = Color(0.66, 0.64, 0.62) if bench else Color.WHITE
	_hp.position = Vector2(9, ph + 40.0)
	_hp.size = Vector2(size.x - 18.0, 16.0 if bench else 20.0)
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
		UiIcons.portrait(preview, Vector2.ZERO, 44.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3)
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

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var font := UiTheme.display_font()
	if companion == null:
		# Chalk on the floor where someone could stand.
		var chalk := Color(UiTheme.TEXT, 0.5 if _drop_hot else 0.2)
		var r := rect.grow(-6.0)
		r.size.y = PORTRAIT_H
		_dashed(r, chalk)
		UiTheme.draw_text(self, UiTheme.italic_font(), Vector2(0, r.get_center().y - 12.0), "an empty place", 18, chalk, 0, size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		if _drop_hot:
			draw_rect(r, Color(UiTheme.GOLD, 0.08))
		return
	var ph := BENCH_PORTRAIT_H if _bench else PORTRAIT_H
	var trim := UiTheme.EDGE
	var width := 2.0
	if _heal_to >= 0:
		trim = UiTheme.HEAL
		width = 3.5
	elif _drop_hot:
		trim = Color("fff0c0")
		width = 4.0
	elif _selected:
		trim = UiTheme.GOLD
		width = 3.5
	elif _hover:
		trim = Color(UiTheme.GOLD, 0.8)
		width = 2.5
	if _selected:
		for i in 4:
			draw_rect(rect.grow(4.0 + 5.0 * i), Color(UiTheme.GOLD, 0.045))
	UiTheme.draw_frame(self, rect, Color(UiTheme.PANEL_HI, 0.97) if _selected else Color(UiTheme.INK, 0.94), trim, width, false)
	var ink := ActionButton.LIT_INK if (_selected or _hover) else (UiTheme.MUTED if _bench else UiTheme.TEXT)
	UiTheme.draw_text(self, font, Vector2(0, ph + 9.0), companion.display_name(), 19 if _bench else 24, ink, 4, size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


## Over the portrait: what a heal being aimed would do.
func _draw_over() -> void:
	if _heal_to < 0 or companion == null:
		return
	var font := UiTheme.display_font()
	var band := Rect2(5, 5, size.x - 10.0, 30)
	_over.draw_rect(band, Color(UiTheme.INK, 0.88))
	UiTheme.draw_text(_over, font, Vector2(band.position.x, band.position.y + (band.size.y - font.get_height(16)) * 0.5),
		"HP %d → %d" % [companion.hp, _heal_to], 16, UiTheme.HEAL, 0, band.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _dashed(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 10.0)
