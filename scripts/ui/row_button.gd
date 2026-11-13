class_name RowButton
extends Control
## A wide leaning row that can be clicked: an optional portrait, a title with a line of small print
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
var hotkey := ""
var texture: Texture2D
var texture_focus := Vector2(0.5, 0.25)
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

var _hover := false


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


func _draw() -> void:
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
		fill = UiTheme.GOLD
		edge = UiTheme.TEXT
		ink = UiTheme.INK
		small = Color(UiTheme.INK, 0.8)
	UiTheme.fill_para(self, rect, fill)
	var s := UiTheme.slant_for(h)
	var x := s * 0.5 + 16.0
	if texture != null:
		var pw := h * 1.3
		var pts := UiTheme.para(Rect2(4, 4, pw + s, h - 8.0), UiTheme.slant_for(h - 8.0))
		var uvs := PackedVector2Array()
		var tex := texture.get_size()
		var region := Vector2(0.34, 0.34 * (h - 8.0) / (pw + s) * tex.x / maxf(1.0, tex.y))
		var origin := texture_focus - region * 0.5
		for p in pts:
			uvs.append(origin + Vector2((p.x - 4.0) / (pw + s), (p.y - 4.0) / (h - 8.0)) * region)
		draw_colored_polygon(pts, Color.WHITE if not disabled else Color(0.5, 0.5, 0.55), uvs, texture)
		x = pw + s + 14.0
	UiTheme.stroke_para(self, rect, edge, 3.0 if lit or active else 2.0)

	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	if hotkey != "":
		var chip := Rect2(x, h * 0.5 - 18.0, 44.0, 36.0)
		UiTheme.fill_para(self, chip, Color(UiTheme.INK, 0.85) if lit else Color(UiTheme.GOLD_DEEP, 0.0 if disabled else 0.9))
		UiTheme.draw_text(self, display, Vector2(chip.position.x, chip.position.y + (chip.size.y - display.get_height(22)) * 0.5),
			hotkey, 22, UiTheme.GOLD if lit else ink, 0, chip.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		x += 58.0
	var right := w - s * 0.5 - 22.0
	var room := right - x
	if detail != "":
		var dw := minf(display.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, w * 0.42)
		room -= dw + 20.0
		var dc := detail_color
		if lit:
			dc = UiTheme.INK
		elif disabled:
			dc = Color(UiTheme.RECOVERING, 0.85)
		UiTheme.draw_text(self, display, Vector2(right - dw, (h - display.get_height(22)) * 0.5), detail, 22, dc, 0, dw,
			HORIZONTAL_ALIGNMENT_RIGHT)
	var title_size := 28
	while title_size > 18 and display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > room:
		title_size -= 1
	var title_y := (h - display.get_height(title_size)) * 0.5
	if sub != "":
		title_y = h * 0.5 - display.get_height(title_size) + 4.0
		UiTheme.draw_text(self, body, Vector2(x + 2.0, h * 0.5 + 4.0), sub, 16, small, 0, room)
	UiTheme.draw_text(self, display, Vector2(x, title_y), title, title_size, ink, 0, room)
