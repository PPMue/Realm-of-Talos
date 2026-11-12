class_name UnitCard
extends PanelContainer
## Clickable card showing one companion or enemy. Display only: it holds no rules.

signal clicked

enum Highlight { NONE, SELECTED, TARGETABLE, TARGETED }

const PORTRAIT_SIZE := Vector2(150, 150)
const COLOR_PANEL := Color(0.14, 0.15, 0.19)
const COLOR_BORDER := Color(0.25, 0.27, 0.33)
const HIGHLIGHT_COLORS := {
	Highlight.NONE: Color(0.25, 0.27, 0.33),
	Highlight.SELECTED: Color(0.95, 0.8, 0.25),
	Highlight.TARGETABLE: Color(0.85, 0.35, 0.3),
	Highlight.TARGETED: Color(1.0, 0.55, 0.2),
}

var _style := StyleBoxFlat.new()
var _portrait_box := Control.new()
var _portrait := TextureRect.new()
var _fallback := ColorRect.new()
var _name_label := Label.new()
var _hp_bar := ProgressBar.new()
var _hp_label := Label.new()
var _sta_bar := ProgressBar.new()
var _sta_label := Label.new()
var _status_label := Label.new()
var _detail_label := Label.new()


func _init() -> void:
	custom_minimum_size = Vector2(176, 0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style.bg_color = COLOR_PANEL
	_style.set_border_width_all(3)
	_style.border_color = COLOR_BORDER
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_portrait_box.custom_minimum_size = PORTRAIT_SIZE
	_portrait_box.clip_contents = true
	box.add_child(_portrait_box)
	_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_box.add_child(_fallback)
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_box.add_child(_portrait)

	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)

	box.add_child(_make_bar(_hp_bar, _hp_label, Color(0.75, 0.2, 0.2)))
	box.add_child(_make_bar(_sta_bar, _sta_label, Color(0.25, 0.55, 0.85)))

	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)

	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail_label)

	_ignore_mouse(box)


func setup(display_name: String, portrait: Texture2D, fallback_color: Color, show_stamina: bool) -> void:
	_name_label.text = display_name
	_portrait.texture = portrait
	_fallback.color = fallback_color
	_sta_bar.visible = show_stamina


func set_hp(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = clampi(current, 0, maximum)
	_hp_label.text = "HP %d / %d" % [current, maximum]


func set_stamina(current: int, maximum: int) -> void:
	_sta_bar.max_value = maxi(1, maximum)
	_sta_bar.value = current
	_sta_label.text = "STA %d / %d" % [current, maximum]


func set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_detail(text: String) -> void:
	_detail_label.text = text


func set_highlight(h: Highlight) -> void:
	_style.border_color = HIGHLIGHT_COLORS[h]
	_style.set_border_width_all(5 if h != Highlight.NONE else 3)


## Darkens the portrait (injured, recovering, defeated).
func set_portrait_tint(color: Color) -> void:
	_portrait_box.modulate = color


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


func _make_bar(bar: ProgressBar, label: Label, fill: Color) -> Control:
	bar.custom_minimum_size = Vector2(0, 20)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.08)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	bar.add_child(label)
	return bar


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
