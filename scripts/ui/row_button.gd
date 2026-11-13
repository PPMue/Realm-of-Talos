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


func _get_tooltip(_at_position: Vector2) -> String:
	if hotkey == "":
		return tooltip_text
	return ("%s\n" % tooltip_text if tooltip_text != "" else "") + "Key: %s" % hotkey


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
		var region := Vector2(0.34, 0.34 * box.size.y / box.size.x * tex.x / maxf(1.0, tex.y))
		var origin := texture_focus - region * 0.5
		for p in pts:
			uvs.append(origin + Vector2((p.x - box.position.x) / box.size.x, (p.y - box.position.y) / box.size.y) * region)
		draw_colored_polygon(pts, Color.WHITE if not disabled else Color(0.5, 0.48, 0.45), uvs, texture)
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
