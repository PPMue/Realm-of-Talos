class_name PartyPanel
extends Control
## One companion in the party row along the bottom of the screen. Display only.
## The row is the battle line: the rightmost panel stands nearest the enemies.

signal clicked
signal hover_changed(inside: bool)

enum Status { NONE, READY, RECOVERING, INJURED }

const W := 344.0
const H := 232.0
const LIFT := 26.0
const PORTRAIT_H := 126.0
const PAD := 6.0

var _body := Control.new()
var _bg := SlantPanel.new()
var _portrait := SlantPanel.new()
var _name: Label
var _level: Label
var _tag := SlantPanel.new()
var _tag_label: Label
var _effects: Label
var _hp := SlantBar.new()
var _sta := SlantBar.new()
var _footer: Label
var _preview := SlantPanel.new()
var _preview_label: Label
var _targetable := false
var _target_hot := false
var _selected := false
var _hover := false
var _can_pick := false
var _lift_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(W, H + LIFT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.position = Vector2(0, LIFT)
	_body.size = Vector2(W, H)
	add_child(_body)

	_bg.size = Vector2(W, H)
	_bg.fill = Color(UiTheme.PANEL, 0.96)
	_body.add_child(_bg)

	_place(_portrait, PAD, PORTRAIT_H, PAD + 2.0)
	_portrait.zoom = 2.1
	_portrait.shade = 0.9
	_portrait.border_width = 0.0
	_body.add_child(_portrait)

	_name = UiTheme.label("", 30, UiTheme.TEXT, true, 8)
	_name.position = Vector2(_edge_x(PAD + PORTRAIT_H) + 18.0, PAD + PORTRAIT_H - 40.0)
	_name.size = Vector2(W - 60.0, 44)
	_body.add_child(_name)
	_level = UiTheme.label("", 18, UiTheme.GOLD, true, 6)
	_level.position = Vector2(_edge_x(PAD + PORTRAIT_H - 40.0) + 20.0, PAD + PORTRAIT_H - 60.0)
	_body.add_child(_level)

	_tag.size = Vector2(150, 32)
	_tag.position = Vector2(W - PAD - 10.0 - _tag.size.x, PAD + 8.0)
	_tag.border = Color(UiTheme.INK, 0.9)
	_body.add_child(_tag)
	_tag_label = UiTheme.label("", 20, UiTheme.INK, true)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tag.add_child(_tag_label)

	_effects = UiTheme.label("", 15, UiTheme.GOLD, false, 5)
	_effects.position = Vector2(_edge_x(PAD + 34.0) + 18.0, PAD + 8.0)
	_effects.size = Vector2(W * 0.5, 22)
	_body.add_child(_effects)

	_place(_hp, 138.0, 26.0, 12.0)
	_hp.label_prefix = "HP "
	_body.add_child(_hp)
	_place(_sta, 168.0, 20.0, 12.0)
	_sta.fill_color = UiTheme.STA
	_sta.label_prefix = "STA "
	_sta.font_size = 15
	_body.add_child(_sta)

	_footer = UiTheme.label("", 16, UiTheme.MUTED)
	_footer.position = Vector2(_edge_x(H - 8.0) + 18.0, 194.0)
	_footer.size = Vector2(W - 60.0, 26)
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_child(_footer)

	# What a spell aimed at this companion would do, over the portrait.
	_preview.size = Vector2(W - 96.0, 40)
	_preview.position = Vector2(_edge_x(88.0) + 22.0, 48.0)
	_preview.fill = Color(UiTheme.INK, 0.92)
	_preview.border = UiTheme.HEAL
	_preview.border_width = 2.0
	_preview.visible = false
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_preview)
	_preview_label = UiTheme.label("", 20, UiTheme.HEAL, true, 6)
	_preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.clip_text = true
	_preview.add_child(_preview_label)

	mouse_entered.connect(func() -> void:
		_hover = true
		hover_changed.emit(true)
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		hover_changed.emit(false)
		_restyle())


func setup(display_name: String, portrait: Texture2D, focus: Vector2) -> void:
	_name.text = display_name.to_upper()
	_portrait.texture = portrait
	# Nudged so the face sits right of centre, clear of the name.
	_portrait.focus = focus + Vector2(-0.07, 0.0)


func set_level(level: int) -> void:
	_level.text = "LV %d" % level


func set_hp(current: int, maximum: int) -> void:
	_hp.set_values(current, maximum)


func set_stamina(current: int, maximum: int) -> void:
	_sta.set_values(current, maximum)


func set_status(status: Status, recovery: int = 0) -> void:
	_tag.visible = status != Status.NONE
	match status:
		Status.READY:
			_tag.fill = UiTheme.READY
			_tag_label.text = "READY"
			_portrait.tint = Color.WHITE
		Status.RECOVERING:
			_tag.fill = UiTheme.RECOVERING
			_tag_label.text = "RECOVER %d" % recovery
			_portrait.tint = Color(0.5, 0.52, 0.6)
		Status.INJURED:
			_tag.fill = UiTheme.INJURED
			_tag_label.text = "INJURED"
			_portrait.tint = Color(0.75, 0.3, 0.3)
		Status.NONE:
			_portrait.tint = Color.WHITE


func set_effects(text: String) -> void:
	_effects.text = text


func set_footer(text: String) -> void:
	_footer.text = text


## While a spell is aimed at companions: `targetable` marks a possible target, `hot` the one (or all)
## it would reach, with `preview` saying what it would do and `heal_to` the HP it would reach (or -INF).
func set_spell_target(targetable: bool, hot: bool, preview: String = "", heal_to: float = -INF) -> void:
	_targetable = targetable
	_target_hot = hot
	_preview.visible = hot and preview != ""
	_preview_label.text = preview
	var font_size := 20
	while font_size > 13 and UiTheme.display_font().get_string_size(preview, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _preview.size.x - 30.0:
		font_size -= 1
	_preview_label.add_theme_font_size_override("font_size", font_size)
	_hp.set_heal_preview(heal_to if hot else -INF)
	if targetable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_restyle()


## `can_pick`: clicking would select this companion.
func set_selection(selected: bool, can_pick: bool) -> void:
	_can_pick = can_pick
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_pick else Control.CURSOR_ARROW
	if selected != _selected:
		_selected = selected
		if _lift_tween != null:
			_lift_tween.kill()
		if is_inside_tree():
			_lift_tween = create_tween()
			_lift_tween.tween_property(_body, "position:y", 0.0 if selected else LIFT, 0.12).set_ease(Tween.EASE_OUT)
		else:
			_body.position.y = 0.0 if selected else LIFT
	_restyle()


func popup_anchor() -> Vector2:
	return global_position + Vector2(W * 0.5, LIFT + PORTRAIT_H * 0.5)


func play_hit(crit: bool) -> void:
	var push := 20.0 if crit else 11.0
	var flash := create_tween()
	_body.modulate = Color(2.4, 1.3, 1.3)
	flash.tween_property(_body, "modulate", Color.WHITE, 0.3)
	var shake := create_tween()
	shake.tween_property(_body, "position:x", -push, 0.05)
	shake.tween_property(_body, "position:x", push * 0.6, 0.07)
	shake.tween_property(_body, "position:x", 0.0, 0.1)


func play_pulse(color: Color) -> void:
	var t := create_tween()
	_body.modulate = Color(1, 1, 1).lerp(color, 0.6) * 1.6
	t.tween_property(_body, "modulate", Color.WHITE, 0.35)


## Only the leaning shape itself counts as the panel, so neighbours that tuck under each other
## do not steal clicks.
func _has_point(point: Vector2) -> bool:
	if point.y < 0.0 or point.y > size.y:
		return false
	var lean := UiTheme.SLANT * (size.y - point.y)
	return point.x >= lean and point.x <= lean + W - UiTheme.SLANT * H


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


func _restyle() -> void:
	if _targetable:
		_bg.border = UiTheme.HEAL if _target_hot else Color(UiTheme.HEAL, 0.45)
		_bg.border_width = 5.0 if _target_hot else 3.0
		_bg.fill = Color(UiTheme.PANEL_HI, 0.98) if _target_hot else Color(UiTheme.PANEL, 0.96)
	elif _selected:
		_bg.border = UiTheme.GOLD
		_bg.border_width = 5.0
		_bg.fill = Color(UiTheme.PANEL_HI, 0.98)
	elif _hover and _can_pick:
		_bg.border = Color(UiTheme.GOLD, 0.75)
		_bg.border_width = 3.0
		_bg.fill = Color(UiTheme.PANEL_HI, 0.96)
	else:
		_bg.border = UiTheme.EDGE
		_bg.border_width = 2.0
		_bg.fill = Color(UiTheme.PANEL, 0.96)


## Left edge of the leaning body at height `y` (measured from the body's top).
func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (H - y)


## Fits a leaning child inside the body so its sides stay parallel to the body's sides.
func _place(node: Control, y: float, height: float, margin: float) -> void:
	node.position = Vector2(_edge_x(y + height) + margin, y)
	node.size = Vector2(W - UiTheme.SLANT * H + UiTheme.slant_for(height) - margin * 2.0, height)
