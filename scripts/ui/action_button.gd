class_name ActionButton
extends Control
## A board button in the action menu: a stud, the action name, and a short cost on the right.
## Long names shrink to fit beside the cost.

signal pressed
signal hover_changed(inside: bool)

const W := 336.0
const H := 54.0
const TITLE_SIZE := 26
const TITLE_MIN_SIZE := 17
## Room kept on the right; the button once slid out when lit.
const NUDGE := 18.0
## How far a lit button moves.
const LIFT := 6.0
const LIT_INK := Color("fff3d2")

var title := "":
	set(v):
		title = v
		queue_redraw()
var detail := "":
	set(v):
		detail = v
		queue_redraw()
var hotkey := ""
## Height; the action menu shrinks it when it has to fit seven entries.
var h := H:
	set(v):
		h = v
		custom_minimum_size = Vector2(W + NUDGE, h)
		size = custom_minimum_size
		queue_redraw()
## Colour of the stud (e.g. a spell's school); transparent keeps the default.
var accent := Color(0, 0, 0, 0):
	set(v):
		accent = v
		queue_redraw()
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


## The key that also presses this button is not drawn on it; it is given with the tooltip.
func _get_tooltip(_at_position: Vector2) -> String:
	if hotkey == "":
		return tooltip_text
	return ("%s\n" % tooltip_text if tooltip_text != "" else "") + "Key: %s" % hotkey


func _draw() -> void:
	var lit := (active or _hover) and not disabled
	var rect := Rect2(LIFT if lit else 0.0, 0, W, h)
	var fill := Color(UiTheme.PANEL, 0.95)
	var edge := UiTheme.EDGE
	var ink := UiTheme.TEXT
	var sub := UiTheme.MUTED
	var mark := UiTheme.GOLD_DEEP if accent.a <= 0.0 else accent
	if disabled:
		fill = Color(UiTheme.INK, 0.88)
		edge = Color(UiTheme.EDGE, 0.5)
		ink = Color(UiTheme.MUTED, 0.55)
		sub = Color(UiTheme.MUTED, 0.45)
		mark = Color(mark, 0.35)
	elif lit:
		fill = Color(UiTheme.PANEL_HI, 0.98)
		edge = UiTheme.GOLD
		ink = LIT_INK
		sub = UiTheme.GOLD
		mark = UiTheme.GOLD if accent.a <= 0.0 else accent.lightened(0.2)
	UiTheme.draw_frame(self, rect, fill, edge, 2.5 if lit else 2.0, false)
	if lit:
		# A warm glow along the left edge, like a lamp held to the board.
		draw_polygon(PackedVector2Array([Vector2(rect.position.x + 3.0, 3.0), Vector2(rect.position.x + 120.0, 3.0),
			Vector2(rect.position.x + 120.0, h - 3.0), Vector2(rect.position.x + 3.0, h - 3.0)]),
			PackedColorArray([Color(UiTheme.GOLD, 0.22), Color(UiTheme.GOLD, 0.0), Color(UiTheme.GOLD, 0.0), Color(UiTheme.GOLD, 0.22)]))

	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	# A small diamond stud in place of a key cap; its colour carries the accent (e.g. a spell's school).
	var c := Vector2(rect.position.x + 24.0, h * 0.5)
	var r := 6.0 if h >= H else 5.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r)]), mark)
	var x := rect.position.x + 44.0
	var right := rect.end.x - 18.0
	var room := right - x
	if detail != "":
		room -= body.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 12.0
		UiTheme.draw_text(self, body, Vector2(rect.position.x, (h - body.get_height(17)) * 0.5), detail, 17, sub,
			0, right - rect.position.x, HORIZONTAL_ALIGNMENT_RIGHT)
	var title_size := TITLE_SIZE
	while title_size > TITLE_MIN_SIZE and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	UiTheme.draw_text(self, display, Vector2(x, (h - display.get_height(title_size)) * 0.5), title, title_size, ink)
