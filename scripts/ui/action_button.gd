class_name ActionButton
extends Control
## A leaning banner button in the action menu: hotkey, action name, and a short cost on the right.

signal pressed
signal hover_changed(inside: bool)

const W := 372.0
const H := 66.0
const NUDGE := 18.0

var title := "":
	set(v):
		title = v
		queue_redraw()
var detail := "":
	set(v):
		detail = v
		queue_redraw()
var hotkey := ""
var disabled := false:
	set(v):
		disabled = v
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
		queue_redraw()
## Stays lit while the player is choosing a target for this action.
var active := false:
	set(v):
		active = v
		queue_redraw()

var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(W + NUDGE, H)
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		hover_changed.emit(true)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		hover_changed.emit(false)
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not disabled:
			pressed.emit()


func _draw() -> void:
	var lit := (active or _hover) and not disabled
	var rect := Rect2(NUDGE if lit else 0.0, 0, W, H)
	var fill := Color(UiTheme.PANEL, 0.94)
	var edge := UiTheme.EDGE
	var ink := UiTheme.TEXT
	var sub := UiTheme.MUTED
	if disabled:
		fill = Color(UiTheme.INK, 0.88)
		edge = Color(UiTheme.EDGE, 0.5)
		ink = Color(UiTheme.MUTED, 0.55)
		sub = Color(UiTheme.MUTED, 0.45)
	elif lit:
		fill = UiTheme.GOLD
		edge = UiTheme.TEXT
		ink = UiTheme.INK
		sub = Color(UiTheme.INK, 0.8)
	UiTheme.fill_para(self, rect, fill)
	UiTheme.stroke_para(self, rect, edge, 3.0 if lit else 2.0)

	var s := UiTheme.slant_for(H)
	var x := rect.position.x + s * 0.5 + 14.0
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	if hotkey != "":
		var chip := Rect2(x, 15.0, 44.0, H - 30.0)
		UiTheme.fill_para(self, chip, Color(UiTheme.INK, 0.85) if lit else Color(UiTheme.GOLD_DEEP, 0.0 if disabled else 0.9))
		UiTheme.draw_text(self, display, Vector2(chip.position.x, chip.position.y + (chip.size.y - display.get_height(22)) * 0.5),
			hotkey, 22, UiTheme.GOLD if lit else ink, 0, chip.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		x += 56.0
	UiTheme.draw_text(self, display, Vector2(x, (H - display.get_height(34)) * 0.5), title, 34, ink)
	if detail != "":
		var right := rect.end.x - s * 0.5 - 18.0
		UiTheme.draw_text(self, body, Vector2(rect.position.x, (H - body.get_height(18)) * 0.5), detail, 18, sub,
			0, right - rect.position.x, HORIZONTAL_ALIGNMENT_RIGHT)
