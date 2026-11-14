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
## Room kept on the right; the button once slid out when lit. A lit button now stays where it is:
## only its frame, its ink and the glow along its edge change.
const NUDGE := 18.0
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

## Written on parchment instead of standing as a board: ink, a wax seal, no frame.
var paper := false:
	set(v):
		paper = v
		queue_redraw()

## Written in light on a veil of shadow laid over the scene (the battle's orders): no board, no
## paper; a small diamond, the words, and a warm wash under whichever line the pointer is on.
var veil := false:
	set(v):
		veil = v
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
	if veil:
		_draw_veil()
		return
	if paper:
		_draw_paper()
		return
	var lit := (active or _hover) and not disabled
	var rect := Rect2(0, 0, W, h)
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


## A line of an order sheet: a wax seal (hollow when it cannot be chosen), the words in ink, and a
## short cost on the right.
func _draw_paper() -> void:
	var lit := (active or _hover) and not disabled
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	if active and not disabled:
		draw_rect(Rect2(0, 1, W, h - 2.0), Color(UiTheme.WAX, 0.14))
	elif lit:
		draw_rect(Rect2(0, 1, W, h - 2.0), Color(UiTheme.PARCHMENT_INK, 0.09))
	draw_line(Vector2(0, h - 0.5), Vector2(W, h - 0.5), Color(UiTheme.PARCHMENT_INK, 0.2), 1.0)
	var seal := Vector2(20.0, h * 0.5)
	var wax := UiTheme.WAX if accent.a <= 0.0 else accent.darkened(0.35)
	if disabled:
		draw_arc(seal, 8.0, 0.0, TAU, 20, Color(UiTheme.PARCHMENT_MUTED, 0.7), 1.5, true)
	else:
		draw_circle(seal + Vector2(1, 1.5), 9.0, Color(0, 0, 0, 0.25))
		draw_circle(seal, 9.0, wax.lightened(0.12) if lit else wax)
		draw_arc(seal, 5.5, 0.0, TAU, 16, Color(1, 1, 1, 0.22), 1.0, true)
	var ink := Color(UiTheme.PARCHMENT_MUTED, 0.7) if disabled else (UiTheme.WAX.darkened(0.25) if lit else UiTheme.PARCHMENT_INK)
	var x := 42.0
	var right := W - 10.0
	var room := right - x
	if detail != "":
		var dw := italic.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		room -= dw + 10.0
		UiTheme.draw_text(self, italic, Vector2(right - dw, (h - italic.get_height(16)) * 0.5), detail, 16,
			Color(UiTheme.PARCHMENT_MUTED, 0.7 if disabled else 1.0))
	var title_size := 23
	while title_size > 15 and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	UiTheme.draw_text(self, display, Vector2(x, (h - display.get_height(title_size)) * 0.5), title, title_size, ink)


## A line of the orders over a battle: a diamond (hollow when it cannot be chosen; a spell's school
## colours it), the words in light, a short cost on the right, and a hairline under it.
func _draw_veil() -> void:
	var lit := (active or _hover) and not disabled
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	if lit:
		# Lamplight along the line, strongest at the diamond.
		var a := 0.3 if active else 0.2
		var clear := Color(UiTheme.GOLD, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 1), Vector2(W * 0.5, 1), Vector2(W * 0.5, h - 1.0), Vector2(0, h - 1.0)]),
			PackedColorArray([Color(UiTheme.GOLD, a), Color(UiTheme.GOLD, a * 0.35), Color(UiTheme.GOLD, a * 0.35), Color(UiTheme.GOLD, a)]))
		draw_polygon(PackedVector2Array([Vector2(W * 0.5, 1), Vector2(W, 1), Vector2(W, h - 1.0), Vector2(W * 0.5, h - 1.0)]),
			PackedColorArray([Color(UiTheme.GOLD, a * 0.35), clear, clear, Color(UiTheme.GOLD, a * 0.35)]))
		if active:
			draw_rect(Rect2(0, 1, 3, h - 2.0), UiTheme.GOLD)
	# The hairline fades out at both ends.
	var line := Color(UiTheme.GOLD, 0.2)
	var none := Color(UiTheme.GOLD, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, h - 1.0), Vector2(W * 0.3, h - 1.0), Vector2(W * 0.3, h), Vector2(0, h)]),
		PackedColorArray([none, line, line, none]))
	draw_polygon(PackedVector2Array([Vector2(W * 0.3, h - 1.0), Vector2(W, h - 1.0), Vector2(W, h), Vector2(W * 0.3, h)]),
		PackedColorArray([line, none, none, line]))

	var c := Vector2(20.0, h * 0.5)
	var r := 6.0
	var gem := PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r)])
	var mark := UiTheme.GOLD if accent.a <= 0.0 else accent
	if disabled:
		gem.append(gem[0])
		draw_polyline(gem, Color(UiTheme.MUTED, 0.5), 1.5, true)
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r - 2.0, 1.5), c + Vector2(0, -r - 0.5), c + Vector2(r + 2.0, 1.5),
			c + Vector2(0, r + 3.5)]), Color(0, 0, 0, 0.5))
		draw_colored_polygon(gem, mark.lightened(0.25) if lit else mark.darkened(0.12))

	var ink := Color(UiTheme.MUTED, 0.6) if disabled else (LIT_INK if lit else UiTheme.TEXT)
	var x := 42.0
	var right := W - 10.0
	var room := right - x
	if detail != "":
		var dw := italic.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		room -= dw + 10.0
		UiTheme.draw_text(self, italic, Vector2(right - dw, (h - italic.get_height(16)) * 0.5), detail, 16,
			Color(UiTheme.MUTED, 0.55) if disabled else (UiTheme.GOLD if lit else UiTheme.TEXT.lerp(UiTheme.MUTED, 0.55)), 4)
	var title_size := 23
	while title_size > 15 and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	UiTheme.draw_text(self, display, Vector2(x, (h - display.get_height(title_size)) * 0.5), title, title_size, ink, 5)
