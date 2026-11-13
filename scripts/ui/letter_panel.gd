class_name LetterPanel
extends Control
## A sheet of parchment laid over the screen: something written to the commander, with the answers
## they can give. Used for visits to buildings, the watch's report, events, the opening of a run and
## anything else that is said rather than shown.
##
## `open` takes a dictionary:
##   kicker    small line above the title (who is speaking, or where)
##   title     the heading
##   body      what is said, in italics
##   facts     plain small print: what a choice costs and does
##   portraits [{texture, focus, scale, name, sub}] shown in a row under the body
##   choices   [{label, sub, why, action}]; `why` not "" greys the choice out and says why
##   leave     the words for putting the letter down; "" means it must be answered
##   width     sheet width (default 880)

signal closed

## How far the shade takes to fade out toward the window.
const WINDOW_FADE := 70.0

## A part of the screen the letter does not shade (see _draw): what the reader needs to keep an eye on
## while answering, such as the purse. An empty rect shades everything.
var window := Rect2():
	set(v):
		window = v
		queue_redraw()

const PAD := 56.0

## A line that can be chosen: a wax seal, the words, and small print under them.
class Choice extends Control:
	signal pressed
	var label := ""
	var sub := ""
	var why := ""
	## A plain closing line rather than an answer.
	var quiet := false
	var _hover := false

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func fit(width: float) -> void:
		custom_minimum_size = Vector2(width, 40.0 if quiet else (66.0 if sub != "" else 50.0))
		size = custom_minimum_size
		mouse_default_cursor_shape = Control.CURSOR_ARROW if why != "" else Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if why == "":
				pressed.emit()

	func _draw() -> void:
		var off := why != ""
		var lit := _hover and not off
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		if quiet:
			var ink := UiTheme.WAX if lit else UiTheme.PARCHMENT_MUTED
			UiTheme.draw_text(self, italic, Vector2(0, (size.y - italic.get_height(21)) * 0.5), label, 21, ink, 0, size.x,
				HORIZONTAL_ALIGNMENT_CENTER)
			return
		if lit:
			draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.PARCHMENT_INK, 0.09))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(UiTheme.PARCHMENT_INK, 0.22), 1.0)
		var seal := Vector2(24.0, size.y * 0.5)
		if off:
			draw_arc(seal, 9.0, 0.0, TAU, 20, Color(UiTheme.PARCHMENT_MUTED, 0.7), 1.5, true)
		else:
			draw_circle(seal + Vector2(1, 1.5), 10.0, Color(0, 0, 0, 0.25))
			draw_circle(seal, 10.0, UiTheme.WAX.lightened(0.12) if lit else UiTheme.WAX)
			draw_arc(seal, 6.0, 0.0, TAU, 16, Color(1, 1, 1, 0.22), 1.0, true)
		var ink := Color(UiTheme.PARCHMENT_MUTED, 0.75) if off else (UiTheme.WAX.darkened(0.2) if lit else UiTheme.PARCHMENT_INK)
		var x := 50.0
		var room := size.x - x - 16.0
		if off:
			var ww := minf(italic.get_string_size(why, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, size.x * 0.5)
			UiTheme.draw_text(self, italic, Vector2(size.x - 16.0 - ww, (size.y - italic.get_height(17)) * 0.5), why, 17,
				UiTheme.WAX, 0, ww, HORIZONTAL_ALIGNMENT_RIGHT)
			room -= ww + 18.0
		var body := UiTheme.body_font()
		if sub != "":
			UiTheme.draw_text(self, display, Vector2(x, 8.0), label, 24, ink, 0, room)
			UiTheme.draw_text(self, body, Vector2(x + 1.0, 38.0), sub, 16, Color(UiTheme.PARCHMENT_MUTED, 0.75 if off else 1.0), 0, room)
		else:
			UiTheme.draw_text(self, display, Vector2(x, (size.y - display.get_height(24)) * 0.5), label, 24, ink, 0, room)


var _sheet := Control.new()
var _spec: Dictionary = {}
var _actions: Array[Callable] = []
var _can_leave := true
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)


func is_open() -> bool:
	return visible


func open(spec: Dictionary) -> void:
	_spec = spec
	_build()
	visible = true
	modulate.a = 0.0
	var rest_y := _sheet.position.y
	_sheet.position.y = rest_y + 18.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_sheet, "position:y", rest_y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Chooses answer `index` as if it had been clicked. Returns false if it cannot be chosen.
func choose(index: int) -> bool:
	var choices: Array = _spec.get("choices", [])
	if index < 0 or index >= choices.size() or String(choices[index].get("why", "")) != "":
		return false
	_pick(index)
	return true


func _pick(index: int) -> void:
	var action := _actions[index]
	visible = false
	closed.emit()
	if action.is_valid():
		action.call()


func _build() -> void:
	for child in _sheet.get_children():
		_sheet.remove_child(child)
		child.queue_free()
	_actions.clear()
	var w := float(_spec.get("width", 880.0))
	var inner := w - PAD * 2.0
	var y := 44.0
	var kicker := String(_spec.get("kicker", ""))
	if kicker != "":
		var k := UiTheme.label(kicker.to_upper(), 16, UiTheme.PARCHMENT_MUTED, true)
		k.position = Vector2(PAD, y)
		k.size = Vector2(inner, 22.0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sheet.add_child(k)
		y += 26.0
	var title := UiTheme.label(String(_spec.get("title", "")), 44, UiTheme.PARCHMENT_INK, true)
	title.position = Vector2(PAD, y)
	title.size = Vector2(inner, 56.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet.add_child(title)
	y += 64.0
	_sheet.set_meta("rule_y", y)
	y += 22.0
	y = _paragraph(String(_spec.get("body", "")), UiTheme.italic_font(), 23, UiTheme.PARCHMENT_INK, y, inner, 16.0)
	var portraits: Array = _spec.get("portraits", [])
	if not portraits.is_empty():
		var row := Control.new()
		row.position = Vector2(PAD, y)
		row.size = Vector2(inner, 178.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.draw.connect(_draw_portraits.bind(row, portraits))
		_sheet.add_child(row)
		y += 190.0
	y = _paragraph(String(_spec.get("facts", "")), UiTheme.body_font(), 19, UiTheme.PARCHMENT_MUTED, y, inner, 14.0)
	var choices: Array = _spec.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var c := Choice.new()
		c.label = String(ch.get("label", ""))
		c.sub = String(ch.get("sub", ""))
		c.why = String(ch.get("why", ""))
		c.fit(inner)
		c.position = Vector2(PAD, y)
		c.pressed.connect(_pick.bind(i))
		_actions.append(ch.get("action", Callable()))
		_sheet.add_child(c)
		y += c.size.y
	var leave := String(_spec.get("leave", "Leave"))
	_can_leave = leave != ""
	if _can_leave:
		y += 12.0
		var l := Choice.new()
		l.quiet = true
		l.label = leave
		l.fit(inner)
		l.position = Vector2(PAD, y)
		l.pressed.connect(close)
		_sheet.add_child(l)
		y += l.size.y
	y += 34.0
	var view := size if size.x > 0.0 else Vector2(1920, 1080)
	_sheet.size = Vector2(w, y)
	_sheet.position = Vector2((view.x - w) * 0.5, maxf(40.0, (view.y - y) * 0.46))
	_sheet.queue_redraw()


func _paragraph(text: String, font: Font, font_size: int, color: Color, y: float, width: float, gap: float) -> float:
	if text == "":
		return y
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines := text.split("\n")
	var h := 0.0
	for line in lines:
		h += maxf(font.get_height(font_size), font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y)
		h += 4.0
	l.position = Vector2(PAD, y)
	l.size = Vector2(width, h)
	_sheet.add_child(l)
	return y + h + gap


## The shade over whatever lies behind the letter. With a `window` set, that part of the screen (it
## must reach the top and the right edge) is left as it is, the shade fading out toward it.
func _draw() -> void:
	var shade := Color(0.02, 0.015, 0.01, 0.6)
	if window.size.x <= 0.0 or window.size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), shade)
		return
	var clear := Color(shade, 0.0)
	var x0 := window.position.x
	var y1 := window.end.y
	var right := maxf(size.x, window.end.x)
	draw_rect(Rect2(0, 0, x0 - WINDOW_FADE, y1 + WINDOW_FADE), shade)
	draw_rect(Rect2(0, y1 + WINDOW_FADE, right, size.y - y1 - WINDOW_FADE), shade)
	_shade_quad(Rect2(x0 - WINDOW_FADE, 0, WINDOW_FADE, y1), [shade, clear, clear, shade])
	_shade_quad(Rect2(x0, y1, right - x0, WINDOW_FADE), [clear, clear, shade, shade])
	_shade_quad(Rect2(x0 - WINDOW_FADE, y1, WINDOW_FADE, WINDOW_FADE), [shade, clear, shade, shade])


## A rectangle whose corners are coloured: top left, top right, bottom right, bottom left.
func _shade_quad(r: Rect2, colors: Array) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray(colors))


func _draw_sheet() -> void:
	UiTheme.draw_parchment(_sheet, Rect2(Vector2.ZERO, _sheet.size))
	var y := float(_sheet.get_meta("rule_y", 0.0))
	UiTheme.draw_rule(_sheet, Vector2(_sheet.size.x * 0.5, y), minf(420.0, _sheet.size.x * 0.5), Color(UiTheme.PARCHMENT_INK, 0.6))


func _draw_portraits(row: Control, portraits: Array) -> void:
	var n := portraits.size()
	var step := minf(260.0, row.size.x / n)
	var x0 := (row.size.x - step * n) * 0.5
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	for i in n:
		var p: Dictionary = portraits[i]
		var c := Vector2(x0 + step * (i + 0.5), 60.0)
		row.draw_circle(c + Vector2(2, 3), 60.0, Color(0, 0, 0, 0.3))
		row.draw_circle(c, 60.0, UiTheme.PARCHMENT_INK)
		UiIcons.portrait(row, c, 56.0, p.get("texture"), p.get("focus", Vector2(0.5, 0.2)) + Vector2(0.0, 0.02),
			0.3 / float(p.get("scale", 1.0)))
		UiTheme.draw_text(row, display, Vector2(c.x - step * 0.5, 126.0), String(p.get("name", "")), 24, UiTheme.PARCHMENT_INK, 0, step,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_text(row, italic, Vector2(c.x - step * 0.5, 154.0), String(p.get("sub", "")), 16, UiTheme.PARCHMENT_MUTED, 0, step,
			HORIZONTAL_ALIGNMENT_CENTER)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _can_leave and not Rect2(_sheet.position, _sheet.size).has_point(mb.position):
			close()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and _can_leave:
		get_viewport().set_input_as_handled()
		close()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		get_viewport().set_input_as_handled()
		choose(key.keycode - KEY_1)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		var choices: Array = _spec.get("choices", [])
		if choices.size() == 1:
			get_viewport().set_input_as_handled()
			choose(0)
