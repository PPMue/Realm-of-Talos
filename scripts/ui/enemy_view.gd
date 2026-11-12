class_name EnemyView
extends Control
## One enemy standing on the stage: its art, and below it name, HP, countdown and intent.
## Display only. The player never sees who an attack will hit, only the kind of action coming.

signal clicked
signal hover_changed(inside: bool)

const BASE_SIDE := 520.0
const MIN_WIDTH := 380.0
const PLATE_H := 172.0
const BAR_W := 300.0

var unit: EnemyUnit

var _side := BASE_SIDE
var _rig := Control.new()
var _sprite := TextureRect.new()
var _overlay := Control.new()
var _name: Label
var _hp := SlantBar.new()
var _effects: Label
var _forecast := SlantPanel.new()
var _forecast_label: Label

var _countdown := 0
var _intent := EnemyActionData.Intent.ATTACK
var _has_intent := false
var _targetable := false
var _hot := false
var _defeated := false
var _time := 0.0
var _phase := 0.0


func setup(p_unit: EnemyUnit, fit_scale: float) -> void:
	unit = p_unit
	_side = BASE_SIDE * unit.data.stage_scale * fit_scale
	var w := maxf(_side, MIN_WIDTH)
	custom_minimum_size = Vector2(w, _side + PLATE_H)
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_STOP
	_phase = randf() * TAU

	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.size = Vector2(w, _side)
	add_child(_rig)
	_sprite.texture = unit.data.portrait
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.position = Vector2((w - _side) * 0.5, 0)
	_sprite.size = Vector2(_side, _side)
	_sprite.pivot_offset = Vector2(_side * 0.5, _side)
	_rig.add_child(_sprite)

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = custom_minimum_size
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_name = UiTheme.label(unit.display_name.to_upper(), 32, UiTheme.TEXT, true, 8)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.position = Vector2(0, _side - 4)
	_name.size = Vector2(w, 40)
	add_child(_name)

	_hp.position = Vector2((w - BAR_W) * 0.5, _side + 40)
	_hp.size = Vector2(BAR_W, 28)
	add_child(_hp)

	_effects = UiTheme.label("", 16, UiTheme.MUTED, false, 5)
	_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effects.position = Vector2(0, _side + 134)
	_effects.size = Vector2(w, 24)
	add_child(_effects)

	_forecast.fill = Color(UiTheme.INK, 0.94)
	_forecast.border = UiTheme.GOLD
	_forecast.border_width = 3.0
	_forecast.size = Vector2(minf(w, 400.0), 62)
	_forecast.position = Vector2((w - _forecast.size.x) * 0.5, _side - 78)
	_forecast.visible = false
	add_child(_forecast)
	_forecast_label = UiTheme.label("", 26, UiTheme.TEXT, true)
	_forecast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_forecast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_forecast.add_child(_forecast_label)

	mouse_entered.connect(func() -> void: hover_changed.emit(true))
	mouse_exited.connect(func() -> void: hover_changed.emit(false))


## Redraws everything from the unit's real state.
func refresh(targetable: bool, hot: bool, tooltip: String) -> void:
	tooltip_text = tooltip
	_hp.set_values(maxi(unit.hp, 0), unit.max_hp())
	if not unit.is_alive():
		if not _defeated:
			_apply_defeated_look()
		_set_target_state(false, false)
		return
	_has_intent = unit.pending_action != null
	if _has_intent:
		_intent = unit.pending_action.intent
	_countdown = unit.countdown
	var parts: Array[String] = []
	for e in unit.effects:
		parts.append(e.describe())
	_effects.text = "   ".join(parts)
	_set_target_state(targetable, hot)
	queue_redraw()


func clear_targeting() -> void:
	_set_target_state(false, false)


func show_countdown(value: int) -> void:
	_countdown = value
	queue_redraw()


func show_hp(hp: int) -> void:
	_hp.set_values(maxi(hp, 0), unit.max_hp())


## Shows what the pending strike would do; pass null to hide.
func set_forecast(f: AttackForecast) -> void:
	_forecast.visible = f != null
	_hp.set_preview(f.damage if f != null else 0)
	if f != null:
		_forecast_label.text = "HIT %d%%    DMG %d    CRIT %d%%" % [f.hit, f.damage, f.crit]


func popup_anchor() -> Vector2:
	return global_position + Vector2(size.x * 0.5, _side * 0.42)


func play_hit(crit: bool) -> void:
	var push := 26.0 if crit else 14.0
	var t := create_tween()
	_sprite.modulate = Color(3.0, 3.0, 3.0) if not crit else Color(4.0, 3.2, 2.0)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.28)
	var shake := create_tween()
	var home := Vector2((size.x - _side) * 0.5, 0)
	shake.tween_property(_sprite, "position", home + Vector2(push, 0), 0.05)
	shake.tween_property(_sprite, "position", home + Vector2(-push * 0.6, 0), 0.07)
	shake.tween_property(_sprite, "position", home, 0.1)


## Steps toward the party when the enemy acts.
func play_lunge() -> void:
	var home := Vector2((size.x - _side) * 0.5, 0)
	var t := create_tween()
	t.tween_property(_sprite, "position", home + Vector2(-46, 0), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_sprite, "position", home, 0.22).set_ease(Tween.EASE_IN_OUT)
	var s := create_tween()
	s.tween_property(_sprite, "scale", Vector2(1.06, 1.06), 0.12)
	s.tween_property(_sprite, "scale", Vector2.ONE, 0.22)


func play_defeat() -> void:
	_defeated = true
	_set_target_state(false, false)
	set_forecast(null)
	var t := create_tween().set_parallel(true)
	t.tween_property(_rig, "modulate", Color(0.2, 0.2, 0.28, 0.0), 0.5)
	for node: Control in [_name, _hp, _effects]:
		t.tween_property(node, "modulate:a", 0.0, 0.4)
	queue_redraw()


func _apply_defeated_look() -> void:
	_defeated = true
	_rig.modulate = Color(0.2, 0.2, 0.28, 0.0)
	for node: Control in [_name, _hp, _effects]:
		node.modulate.a = 0.0
	set_forecast(null)
	queue_redraw()


func _set_target_state(targetable: bool, hot: bool) -> void:
	_targetable = targetable
	_hot = hot
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if targetable else Control.CURSOR_ARROW
	_rig.self_modulate = Color.WHITE
	if not _defeated:
		_sprite.self_modulate = Color(1.25, 1.2, 1.1) if hot else Color.WHITE
	set_process(true)
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not _defeated:
		_rig.position.y = sin(_time * 1.5 + _phase) * 4.0
	if _targetable:
		_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


func _draw() -> void:
	if _defeated:
		return
	# Shadow on the ground under the art.
	draw_set_transform(Vector2(size.x * 0.5, _side - 22.0), 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, _side * 0.36, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _has_intent:
		_draw_countdown()


## Hourglass, ticks left, and the kind of action that is coming.
func _draw_countdown() -> void:
	var font := UiTheme.display_font()
	var number := str(maxi(_countdown, 0))
	var number_size := 50
	var number_w := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	var word := EnemyActionData.intent_name(_intent)
	var word_size := 24
	var word_w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
	var chip_w := word_w + 78.0
	var chip_h := 40.0
	var total := 34.0 + 10.0 + number_w + 18.0 + chip_w
	var x := (size.x - total) * 0.5
	var y := _side + 78.0
	var urgent := _countdown <= 1
	var count_color := UiTheme.DANGER if urgent else UiTheme.GOLD

	UiTheme.draw_hourglass(self, Vector2(x + 17.0, y + 26.0), 34.0, count_color)
	x += 44.0
	UiTheme.draw_text(self, font, Vector2(x, y + 26.0 - font.get_height(number_size) * 0.5), number, number_size, count_color, 8)
	x += number_w + 18.0

	var color: Color = UiTheme.INTENT_COLORS[_intent]
	var chip := Rect2(x, y + 6.0, chip_w, chip_h)
	UiTheme.fill_para(self, chip, color)
	UiTheme.stroke_para(self, chip, Color(UiTheme.INK, 0.9), 2.0)
	UiTheme.draw_intent_icon(self, _intent, Vector2(x + 34.0, y + 26.0), 22.0, UiTheme.INK)
	UiTheme.draw_text(self, font, Vector2(x + 54.0, y + 26.0 - font.get_height(word_size) * 0.5), word, word_size, UiTheme.INK)


## Corner brackets that mark an enemy as a possible, or the current, target.
func _draw_overlay() -> void:
	if not _targetable or _defeated:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var color := UiTheme.GOLD if _hot else Color(UiTheme.DANGER, 0.45 + 0.35 * pulse)
	var grow := (6.0 if _hot else 0.0) + pulse * 5.0
	var inset := _side * 0.1
	var r := Rect2((size.x - _side) * 0.5 + inset, inset * 0.6, _side - inset * 2.0, _side - inset * 1.1).grow(grow)
	var arm := 46.0
	var w := 6.0 if _hot else 4.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var p := r.position + r.size * corner
		var dx := arm if corner.x == 0.0 else -arm
		var dy := arm if corner.y == 0.0 else -arm
		_overlay.draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), color, w, true)
