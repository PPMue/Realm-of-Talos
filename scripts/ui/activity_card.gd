class_name ActivityCard
extends Control
## One free-day action on the city screen (rest, shop, tavern, repair): what it does, what it costs,
## and a button. Shows DONE once taken today, or why it cannot be taken.

signal chosen

const W := 420.0
const H := 430.0

var _bg := SlantPanel.new()
var _title: Label
var _text: Label
var _cost: Label
var _state := SlantPanel.new()
var _state_label: Label
var _button := ActionButton.new()
var _hover := false
var _enabled := true
var _done := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.size = size
	add_child(_bg)
	_title = UiTheme.label("", 52, UiTheme.TEXT, true, 8)
	_title.position = Vector2(_edge_x(90.0) + 26.0, 26.0)
	add_child(_title)
	_text = UiTheme.label("", 20, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(_edge_x(200.0) + 28.0, 104.0)
	_text.size = Vector2(W - UiTheme.SLANT * H - 20.0, 120.0)
	add_child(_text)
	_cost = UiTheme.label("", 22, UiTheme.GOLD, true, 6)
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cost.position = Vector2(_edge_x(300.0) + 28.0, 244.0)
	_cost.size = Vector2(W - UiTheme.SLANT * H - 10.0, 60.0)
	add_child(_cost)
	_state.size = Vector2(140, 34)
	_state.position = Vector2(W - 166.0, 18.0)
	_state.border = Color(UiTheme.INK, 0.9)
	add_child(_state)
	_state_label = UiTheme.label("", 20, UiTheme.INK, true)
	_state_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state.add_child(_state_label)
	_button.position = Vector2(_edge_x(H - 22.0) + (W - UiTheme.SLANT * H - ActionButton.W) * 0.5 - 6.0, H - 22.0 - ActionButton.H)
	_button.pressed.connect(func() -> void: chosen.emit())
	add_child(_button)
	mouse_entered.connect(func() -> void:
		_hover = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		_restyle())


## `why_not`: "" if it can be taken now, else why not. `done`: already taken today.
func setup(title: String, text: String, cost: String, button: String, hotkey: String, why_not: String, done: bool) -> void:
	_title.text = title
	_text.text = text
	_cost.text = cost
	_button.title = button
	_button.hotkey = hotkey
	_done = done
	_enabled = why_not == ""
	_button.disabled = not _enabled
	_button.tooltip_text = why_not
	_state.visible = done or not _enabled
	if done:
		_state.fill = UiTheme.READY
		_state_label.text = "DONE"
	elif not _enabled:
		_state.fill = Color(UiTheme.INK, 0.9)
		_state_label.text = "NOT NOW"
		_state_label.add_theme_color_override("font_color", UiTheme.MUTED)
		_cost.text = why_not
		_cost.add_theme_color_override("font_color", UiTheme.RECOVERING)
	_restyle()


func _restyle() -> void:
	var lit := _hover and _enabled
	_bg.fill = Color(UiTheme.PANEL_HI, 0.97) if lit else Color(UiTheme.PANEL, 0.95 if _enabled else 0.8)
	_bg.border = UiTheme.GOLD if lit else (UiTheme.READY if _done else UiTheme.EDGE)
	_bg.border_width = 4.0 if lit else 2.0
	_button.active = lit
	_title.add_theme_color_override("font_color", UiTheme.TEXT if _enabled or _done else UiTheme.MUTED)


func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (H - y)
