class_name MusterRow
extends Control
## One of the company in the barracks' list: a portrait, the name, level and weapon, and health at
## the right. Someone in the line or on the bench can be picked up and set down on another row (or on
## an empty place in the line); whatever a row is set down on emits `dropped` with who was carried.
## Someone in the infirmary is listed dimmed with the days they have left, and cannot be carried.
## An empty place in the line is a chalk outline.

signal pressed
signal dropped(carried: RunCompanion)

enum Kind { LINE, BENCH, INFIRMARY }

const W := 380.0

var companion: RunCompanion
var kind := Kind.LINE
## Whether rows may be carried right now (not once the day's battle has begun).
var can_carry := true
## Written at the right in place of health (the infirmary: "3 days").
var note := ""

var _selected := false
var _hover := false
var _drop_hot := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_drop_hot = false
		queue_redraw())


## `c` null: an empty place in the line.
func setup(c: RunCompanion, p_kind: Kind, height: float) -> void:
	companion = c
	kind = p_kind
	custom_minimum_size = Vector2(W, height)
	size = custom_minimum_size
	if c == null:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		tooltip_text = "An empty place in the line. Carry someone here from the bench."
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = PartyMedallion.describe(c)
	queue_redraw()


func set_selected(v: bool) -> void:
	_selected = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and companion != null \
			and Rect2(Vector2.ZERO, size).has_point(mb.position):
		accept_event()
		pressed.emit()


# ---------------------------------------------------------------- carrying

func _get_drag_data(_at_position: Vector2) -> Variant:
	if companion == null or not can_carry or kind == Kind.INFIRMARY:
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
	var ok: bool = can_carry and kind != Kind.INFIRMARY and data is Dictionary \
		and (data as Dictionary).get("companion") is RunCompanion and (data as Dictionary)["companion"] != companion
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
	var h := size.y
	var italic := UiTheme.italic_font()
	if companion == null:
		var chalk := Color(UiTheme.TEXT, 0.55 if _drop_hot else 0.22)
		var r := Rect2(4.0, 4.0, W - 8.0, h - 8.0)
		if _drop_hot:
			draw_rect(r, Color(UiTheme.GOLD, 0.1))
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], chalk, 2.0, 10.0)
		UiTheme.draw_text(self, italic, Vector2(0, h * 0.5 - 12.0), "an empty place", 18, chalk, 0, W, HORIZONTAL_ALIGNMENT_CENTER)
		return

	var c := companion
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var abed := kind == Kind.INFIRMARY
	var lit := _selected or _hover or _drop_hot
	# A dark plate, so the row reads against the wall; gold for whoever is picked out.
	draw_rect(Rect2(0, 0, W, h), Color(UiTheme.INK, 0.55 if kind == Kind.LINE else 0.4))
	if _selected or _drop_hot:
		var glow := Color("fff0c0") if _drop_hot else UiTheme.GOLD
		var clear := Color(glow, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, h), Vector2(0, h)]),
			PackedColorArray([Color(glow, 0.26), clear, clear, Color(glow, 0.26)]))
		draw_rect(Rect2(0, 0, 3, h), glow)
		if _drop_hot:
			draw_rect(Rect2(0.5, 0.5, W - 1.0, h - 1.0), Color(glow, 0.7), false, 1.5)
	elif _hover:
		draw_rect(Rect2(0, 0, W, h), Color(UiTheme.GOLD, 0.07))

	var r := minf(30.0, h * 0.5 - 5.0)
	var center := Vector2(r + 12.0, h * 0.5)
	var tint := Color(0.62, 0.5, 0.5) if abed else (Color.WHITE if lit or kind == Kind.LINE else Color(0.78, 0.76, 0.74))
	draw_circle(center + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
	draw_circle(center, r + 3.0, UiTheme.INK)
	UiIcons.portrait(self, center, r, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale, tint)
	draw_arc(center, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if lit else UiTheme.GOLD_DEEP, 2.0, true)

	var x := center.x + r + 14.0
	var right := W - 12.0
	var gauge := 96.0
	var ink := ActionButton.LIT_INK if lit else (UiTheme.MUTED if abed else UiTheme.TEXT)
	var name_size := 24 if kind == Kind.LINE else 21
	UiTheme.draw_text(self, display, Vector2(x, h * 0.5 - display.get_height(name_size) + 3.0), c.display_name(), name_size, ink, 4,
		right - gauge - 10.0 - x)
	var w := c.weapon()
	var small := "Level %d" % c.level() + ("  ·  %s" % w.display_name if w != null else "")
	UiTheme.draw_text(self, body, Vector2(x, h * 0.5 + 4.0), small, 15, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), 4, right - x)
	if note != "":
		UiTheme.draw_text(self, italic, Vector2(right - gauge, h * 0.5 - 22.0), note, 17, UiTheme.INJURED.lightened(0.25), 4, gauge,
			HORIZONTAL_ALIGNMENT_RIGHT)
		return
	# Health, at the right: the figure over a short line.
	UiTheme.draw_text(self, display, Vector2(right - gauge, h * 0.5 - 23.0), "%d / %d" % [c.hp, c.max_hp()], 17, ink, 4, gauge,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var track := Rect2(right - gauge, h * 0.5 - 1.0, gauge, 5.0)
	draw_rect(track.grow(1.0), Color(0, 0, 0, 0.6))
	var fill := UiTheme.HP if c.hp * 3 >= c.max_hp() else UiTheme.INJURED
	draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(c.hp) / maxf(1.0, c.max_hp()), 0.0, 1.0), track.size.y)), fill)
