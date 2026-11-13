class_name TitleScreen
extends Control
## The first thing the player sees: the city at night, the game's name, and a short list of things
## to do. The list is plain words, not buttons in boxes.

signal new_run_pressed
signal quit_pressed

## One line of the menu.
class Item extends Control:
	signal pressed
	var text := "":
		set(v):
			text = v
			queue_redraw()
	var _hover := false

	func _init() -> void:
		custom_minimum_size = Vector2(520, 58)
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
			pressed.emit()

	func _draw() -> void:
		var font := UiTheme.display_font()
		var x := 34.0
		if _hover:
			UiIcons.diamond(self, Vector2(12, size.y * 0.5), 7.0, UiTheme.GOLD)
			draw_line(Vector2(x, size.y - 8.0), Vector2(x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x, size.y - 8.0),
				Color(UiTheme.GOLD, 0.6), 1.5)
		UiTheme.draw_text(self, font, Vector2(x, (size.y - font.get_height(34)) * 0.5), text, 34,
			UiTheme.GOLD if _hover else UiTheme.TEXT, 8)


var _city := CityBackdrop.new()
var _display: Item


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	_city.set_phase(CityBackdrop.Phase.NIGHT, false)
	add_child(_city)
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_shade.bind(shade))
	add_child(shade)

	var name_label := UiTheme.label("REALM OF TALOS", 104, UiTheme.TEXT, true, 14)
	name_label.position = Vector2(110, 240)
	add_child(name_label)
	var sub := UiTheme.label("The Last City", 40, UiTheme.GOLD, false, 8)
	sub.add_theme_font_override("font", UiTheme.italic_font())
	sub.position = Vector2(118, 388)
	add_child(sub)

	var menu := VBoxContainer.new()
	menu.position = Vector2(104, 540)
	menu.add_theme_constant_override("separation", 6)
	add_child(menu)
	var begin := Item.new()
	begin.text = "Begin a new run"
	begin.tooltip_text = "Take command of the city on day 1, with two companions."
	begin.pressed.connect(func() -> void: new_run_pressed.emit())
	menu.add_child(begin)
	_display = Item.new()
	_display.tooltip_text = "Switch between a window and the full screen."
	_display.pressed.connect(_toggle_display)
	menu.add_child(_display)
	var quit := Item.new()
	quit.text = "Leave"
	quit.tooltip_text = "Close the game."
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	menu.add_child(quit)
	_refresh_display()


func _draw_shade(shade: Control) -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	var dark := Color(UiTheme.INK, 0.95)
	var clear := Color(UiTheme.INK, 0.0)
	shade.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.78, 0), Vector2(w * 0.78, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	UiTheme.draw_rule(shade, Vector2(430, 462), 620.0, UiTheme.GOLD_DEEP)


func _full() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _toggle_display() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _full() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh_display()


func _refresh_display() -> void:
	_display.text = "Play in a window" if _full() else "Fill the screen"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		new_run_pressed.emit()
