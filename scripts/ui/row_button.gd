class_name RowButton
extends Control
## A wide board that can be clicked: an optional portrait, a title with a line of small print
## under it, and a short tag on the right (a price, a cost, or why it cannot be chosen).
## Used for event choices, shop and tavern lists and the party screen's weapon list.

signal pressed

var title := "":
	set(v):
		title = v
		queue_redraw()
## Small print under the title.
var sub := "":
	set(v):
		sub = v
		queue_redraw()
## Right-hand tag.
var detail := "":
	set(v):
		detail = v
		queue_redraw()
var detail_color := UiTheme.GOLD:
	set(v):
		detail_color = v
		queue_redraw()
## Paper rows only. Lines written under the small print, one to a line, in red-brown italics: what a
## rare weapon does that others do not. The row must be made NOTE_STEP taller for each (see
## height_with).
var notes: Array[String] = []:
	set(v):
		notes = v
		queue_redraw()
## Paper rows only. A small red diamond before the title: something out of the ordinary.
var marked := false:
	set(v):
		marked = v
		queue_redraw()
var hotkey := ""
var texture: Texture2D
var texture_focus := Vector2(0.5, 0.25)
## 1 = the usual crop; higher shows less of the art (see CompanionData.figure_scale).
var texture_zoom := 1.0
## Greyed out and not clickable; `detail` should say why.
var disabled := false:
	set(v):
		disabled = v
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
		queue_redraw()
## Drawn as chosen (e.g. the weapon in hand).
var active := false:
	set(v):
		active = v
		queue_redraw()

## Written on parchment instead of standing as a board.
var paper := false:
	set(v):
		paper = v
		queue_redraw()

const NOTE_STEP := 19.0

var _hover := false


## Height of a paper row of `base` height that carries `count` notes.
static func height_with(base: float, count: int) -> float:
	return base + (NOTE_STEP * count + 4.0 if count > 0 else 0.0)


func _init(width: float = 1100.0, height: float = 76.0) -> void:
	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not disabled:
			pressed.emit()


func _get_tooltip(_at_position: Vector2) -> String:
	if hotkey == "":
		return tooltip_text
	return ("%s\n" % tooltip_text if tooltip_text != "" else "") + "Key: %s" % hotkey


func _draw() -> void:
	if paper:
		_draw_paper()
		return
	var w := size.x
	var h := size.y
	var lit := _hover and not disabled
	var rect := Rect2(0, 0, w, h)
	var fill := Color(UiTheme.PANEL, 0.95)
	var edge := UiTheme.EDGE
	var ink := UiTheme.TEXT
	var small := UiTheme.MUTED
	if disabled:
		fill = Color(UiTheme.INK, 0.9)
		edge = Color(UiTheme.EDGE, 0.5)
		ink = Color(UiTheme.MUTED, 0.75)
		small = Color(UiTheme.MUTED, 0.6)
	elif active:
		fill = Color(UiTheme.PANEL_HI, 0.98)
		edge = UiTheme.GOLD
	if lit:
		fill = Color(UiTheme.PANEL_HI, 0.98)
		edge = UiTheme.GOLD
		ink = ActionButton.LIT_INK
		small = UiTheme.TEXT.lerp(UiTheme.MUTED, 0.4)
	UiTheme.draw_frame(self, rect, fill, edge, 2.5 if lit or active else 2.0, false)
	if lit:
		draw_polygon(PackedVector2Array([Vector2(3, 3), Vector2(200, 3), Vector2(200, h - 3.0), Vector2(3, h - 3.0)]),
			PackedColorArray([Color(UiTheme.GOLD, 0.2), Color(UiTheme.GOLD, 0.0), Color(UiTheme.GOLD, 0.0), Color(UiTheme.GOLD, 0.2)]))
	var x := 22.0
	if texture != null:
		var pw := h * 1.3
		var box := Rect2(5, 5, pw, h - 10.0)
		var pts := UiTheme.para(box, 0.0)
		var uvs := PackedVector2Array()
		var tex := texture.get_size()
		var span := 0.34 / maxf(0.1, texture_zoom)
		var region := Vector2(span, span * box.size.y / box.size.x * tex.x / maxf(1.0, tex.y))
		var origin := texture_focus - region * 0.5
		for p in pts:
			uvs.append(origin + Vector2((p.x - box.position.x) / box.size.x, (p.y - box.position.y) / box.size.y) * region)
		var dim := Color.WHITE if not disabled else Color(0.5, 0.48, 0.45)
		draw_polygon(pts, PackedColorArray([UiTheme.PORTRAIT_BACK * dim, UiTheme.PORTRAIT_BACK * dim, UiTheme.PORTRAIT_BACK_LOW * dim,
			UiTheme.PORTRAIT_BACK_LOW * dim]))
		draw_colored_polygon(pts, dim, uvs, texture)
		draw_rect(box, Color(UiTheme.INK, 0.9), false, 2.0)
		x = pw + 22.0

	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var right := w - 24.0
	var room := right - x
	if detail != "":
		var dw := minf(display.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, w * 0.42)
		room -= dw + 20.0
		var dc := detail_color
		if disabled:
			dc = Color(UiTheme.RECOVERING, 0.85)
		UiTheme.draw_text(self, display, Vector2(right - dw, (h - display.get_height(20)) * 0.5), detail, 20, dc, 0, dw,
			HORIZONTAL_ALIGNMENT_RIGHT)
	var title_size := 25
	while title_size > 16 and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	var title_y := (h - display.get_height(title_size)) * 0.5
	if sub != "":
		title_y = h * 0.5 - display.get_height(title_size) + 4.0
		UiTheme.draw_text(self, body, Vector2(x + 2.0, h * 0.5 + 4.0), sub, 16, small, 0, room)
	UiTheme.draw_text(self, display, Vector2(x, title_y), title, title_size, ink, 0, room)


## A line in a ledger: the entry in ink with small print under it, and a note on the right.
func _draw_paper() -> void:
	var w := size.x
	var h := size.y
	var lit := _hover and not disabled
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	if active:
		draw_rect(Rect2(0, 1, w, h - 2.0), Color(UiTheme.WAX, 0.12))
	elif lit:
		draw_rect(Rect2(0, 1, w, h - 2.0), Color(UiTheme.PARCHMENT_INK, 0.09))
	draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(UiTheme.PARCHMENT_INK, 0.2), 1.0)
	var ink := Color(UiTheme.PARCHMENT_MUTED, 0.8) if disabled else (UiTheme.WAX.darkened(0.25) if lit else UiTheme.PARCHMENT_INK)
	var small := Color(UiTheme.PARCHMENT_MUTED, 0.75 if disabled else 1.0)
	var x := 12.0
	var right := w - 10.0
	var room := right - x
	if detail != "":
		var dw := minf(italic.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, w * 0.45)
		room -= dw + 14.0
		var dc := UiTheme.WAX if (disabled or active) else UiTheme.PARCHMENT_MUTED
		if lit:
			dc = UiTheme.WAX.darkened(0.2)
		UiTheme.draw_text(self, italic, Vector2(right - dw, (h - italic.get_height(16)) * 0.5), detail, 16, dc, 0, dw,
			HORIZONTAL_ALIGNMENT_RIGHT)
	if marked:
		UiIcons.diamond(self, Vector2(x + 6.0, (h * 0.5 - 10.0) if notes.is_empty() else 21.0), 6.0, Color(UiTheme.WAX, 0.6 if disabled else 1.0))
		x += 20.0
		room -= 20.0
	var title_size := 21
	while title_size > 15 and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	if not notes.is_empty():
		# Title, small print, then the notes; the tag on the right keeps to the middle.
		UiTheme.draw_text(self, display, Vector2(x, 7.0), title, title_size, ink, 0, room)
		UiTheme.draw_text(self, body, Vector2(x + 1.0, 35.0), sub, 14, small, 0, room)
		var note_ink := Color(UiTheme.WAX.darkened(0.25), 0.7 if disabled else 1.0)
		for i in notes.size():
			UiTheme.draw_text(self, italic, Vector2(x + 1.0, 55.0 + i * NOTE_STEP), notes[i], 15, note_ink, 0, room)
	elif sub != "":
		UiTheme.draw_text(self, display, Vector2(x, h * 0.5 - display.get_height(title_size) + 3.0), title, title_size, ink, 0, room)
		UiTheme.draw_text(self, body, Vector2(x + 1.0, h * 0.5 + 3.0), sub, 14, small, 0, room)
	else:
		UiTheme.draw_text(self, display, Vector2(x, (h - display.get_height(title_size)) * 0.5), title, title_size, ink, 0, room)
