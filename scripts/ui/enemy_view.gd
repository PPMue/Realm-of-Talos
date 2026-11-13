class_name EnemyView
extends Control
## One enemy standing on the stage: its art, and below it name, HP, countdown and intent.
## Display only. The player never sees who an attack will hit, only the kind of action coming.
##
## The battle screen gives each enemy a slot (a column of the stage) and calls layout().
## The art may be wider than the slot: with several enemies they overlap, every second one
## standing a step further back.

signal clicked
signal hover_changed(inside: bool)

## Art size of a normal-sized enemy when there is room.
const BASE_SIDE := 600.0
const MAX_SLOT := 640.0
const PLATE_H := 134.0
## How much higher (further away) the back row stands.
const BACK_RAISE := 58.0
const BACK_TINT := Color(0.8, 0.82, 0.9)
## Below this slot width the intent chip drops its word and shows the icon only.
const COMPACT_BELOW := 262.0

var unit: EnemyUnit

var _side := BASE_SIDE
var _home := Vector2.ZERO
var _compact := false
var _base_tint := Color.WHITE
var _rig := Control.new()
var _sprite := TextureRect.new()
var _plate := Control.new()
var _overlay := Control.new()
var _name: Label
var _hp := SlantBar.new()
var _effects: Label
var _forecast := SlantPanel.new()
var _forecast_label: Label
var _forecast_kicker: Label
## Traits (e.g. FLYING) as small tags above the name; hovering one explains it.
var _traits := HBoxContainer.new()

var _countdown := 0
var _intent := EnemyActionData.Intent.ATTACK
var _has_intent := false
var _delayed := false
var _targetable := false
var _hot := false
var _defeated := false
var _time := 0.0
var _phase := 0.0


func setup(p_unit: EnemyUnit) -> void:
	unit = p_unit
	mouse_filter = Control.MOUSE_FILTER_STOP
	_phase = randf() * TAU

	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rig)
	_sprite.texture = unit.data.portrait
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.add_child(_sprite)

	# The plate draws above every enemy's art, so a neighbour can never cover it.
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.z_index = 2
	_plate.draw.connect(_draw_plate)
	add_child(_plate)
	_name = UiTheme.label(unit.display_name.to_upper(), 32, UiTheme.TEXT, true, 8)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(_name)
	_plate.add_child(_hp)
	_effects = UiTheme.label("", 16, UiTheme.GOLD, false, 6)
	_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(_effects)

	_traits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_traits.add_theme_constant_override("separation", 6)
	_plate.add_child(_traits)
	for t in unit.traits():
		_traits.add_child(_trait_tag(t))

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 3
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_forecast.fill = Color(UiTheme.INK, 0.94)
	_forecast.border = UiTheme.GOLD
	_forecast.border_width = 3.0
	_forecast.visible = false
	_overlay.add_child(_forecast)
	_forecast_label = UiTheme.label("", 26, UiTheme.TEXT, true)
	_forecast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_forecast_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_forecast.add_child(_forecast_label)
	_forecast_kicker = UiTheme.label("", 20, UiTheme.EFFECTIVE, true, 6)
	_forecast_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast_kicker.visible = false
	_overlay.add_child(_forecast_kicker)

	mouse_entered.connect(func() -> void: hover_changed.emit(true))
	mouse_exited.connect(func() -> void: hover_changed.emit(false))


## Places everything inside a slot. `side` is the art size; `back` puts the enemy in the back row.
func layout(slot: Vector2, side: float, back: bool) -> void:
	size = slot
	_side = side
	_compact = slot.x < COMPACT_BELOW
	var raise := BACK_RAISE if back else 0.0
	_home = Vector2((slot.x - side) * 0.5, slot.y - PLATE_H - raise - side)
	_rig.size = slot
	_rig.z_index = 0 if back else 1
	_sprite.position = _home
	_sprite.size = Vector2(side, side)
	_sprite.pivot_offset = Vector2(side * 0.5, side)
	_base_tint = BACK_TINT if back else Color.WHITE
	_sprite.modulate = _base_tint

	_plate.position = Vector2(0, slot.y - PLATE_H)
	_plate.size = Vector2(slot.x, PLATE_H)
	_name.add_theme_font_size_override("font_size", 26 if slot.x < 360.0 else 32)
	_name.position = Vector2(-60, -4)
	_name.size = Vector2(slot.x + 120, 40)
	var bar_w := minf(slot.x - 18.0, 320.0)
	_hp.position = Vector2((slot.x - bar_w) * 0.5, 38)
	_hp.size = Vector2(bar_w, 28)
	_effects.position = Vector2(-60, -30)
	_effects.size = Vector2(slot.x + 120, 24)
	_traits.position = Vector2((slot.x - bar_w) * 0.5, -60)
	_traits.size = Vector2(bar_w, 26)

	_overlay.size = slot
	_forecast.size = Vector2(clampf(slot.x + 40.0, 350.0, 400.0), 62)
	_forecast.position = Vector2((slot.x - _forecast.size.x) * 0.5, slot.y - PLATE_H - 128.0)
	_forecast_kicker.position = Vector2(_forecast.position.x, _forecast.position.y - 30.0)
	_forecast_kicker.size = Vector2(_forecast.size.x, 28)
	queue_redraw()
	_plate.queue_redraw()
	_overlay.queue_redraw()


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
	_delayed = unit.delayed
	var parts: Array[String] = []
	for e in unit.effects:
		parts.append(e.describe())
	_effects.text = "   ".join(parts)
	_set_target_state(targetable, hot)
	_plate.queue_redraw()


func clear_targeting() -> void:
	_set_target_state(false, false)


func show_countdown(value: int) -> void:
	_countdown = value
	_plate.queue_redraw()


## A spell pushed the pending action back: new countdown, marked as delayed.
func show_delay(value: int) -> void:
	_countdown = value
	_delayed = true
	_plate.queue_redraw()


func show_hp(hp: int) -> void:
	_hp.set_values(maxi(hp, 0), unit.max_hp())


## Shows what the pending strike would do; pass null to hide. `strikes` > 1 shows "DMG 8x2".
## A kicker above says when the strike is magic and when it is effective (Mt doubled).
## `note` adds a line of its own (e.g. "DELAYS +2" or "ALREADY DELAYED").
func set_forecast(f: AttackForecast, strikes: int = 1, note: String = "") -> void:
	_forecast.visible = f != null
	_hp.set_preview(f.damage * strikes if f != null else 0)
	var kicker: Array[String] = []
	if f != null:
		var dmg := str(f.damage) if strikes <= 1 else "%dx%d" % [f.damage, strikes]
		_forecast_label.text = "HIT %d%%    DMG %s    CRIT %d%%" % [f.hit, dmg, f.crit]
		_forecast.border = UiTheme.EFFECTIVE if f.effective else (UiTheme.BLACK_MAGIC if f.magic else UiTheme.GOLD)
		if f.effective:
			kicker.append("EFFECTIVE  ·  MT x%d" % BattleConfig.EFFECTIVE_MIGHT_MULT)
		if f.magic:
			kicker.append("MAGIC")
		if note != "":
			kicker.append(note)
	_forecast_kicker.text = "   ·   ".join(kicker)
	_forecast_kicker.visible = not kicker.is_empty()
	_forecast_kicker.add_theme_color_override("font_color",
		UiTheme.EFFECTIVE if f != null and f.effective else (UiTheme.BLACK_MAGIC if f != null and f.magic else UiTheme.GOLD))


func popup_anchor() -> Vector2:
	return global_position + _home + Vector2(_side * 0.5, _side * 0.42)


func play_hit(crit: bool) -> void:
	var push := 26.0 if crit else 14.0
	var t := create_tween()
	_sprite.modulate = Color(3.0, 3.0, 3.0) if not crit else Color(4.0, 3.2, 2.0)
	t.tween_property(_sprite, "modulate", _base_tint, 0.28)
	var shake := create_tween()
	shake.tween_property(_sprite, "position", _home + Vector2(push, 0), 0.05)
	shake.tween_property(_sprite, "position", _home + Vector2(-push * 0.6, 0), 0.07)
	shake.tween_property(_sprite, "position", _home, 0.1)


## Steps toward the party when the enemy acts.
func play_lunge() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "position", _home + Vector2(-46, 0), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_sprite, "position", _home, 0.22).set_ease(Tween.EASE_IN_OUT)
	var s := create_tween()
	s.tween_property(_sprite, "scale", Vector2(1.06, 1.06), 0.12)
	s.tween_property(_sprite, "scale", Vector2.ONE, 0.22)


func play_defeat() -> void:
	_defeated = true
	_set_target_state(false, false)
	set_forecast(null)
	var t := create_tween().set_parallel(true)
	t.tween_property(_rig, "modulate", Color(0.2, 0.2, 0.28, 0.0), 0.5)
	t.tween_property(_plate, "modulate:a", 0.0, 0.4)
	queue_redraw()


func _apply_defeated_look() -> void:
	_defeated = true
	_rig.modulate = Color(0.2, 0.2, 0.28, 0.0)
	_plate.modulate.a = 0.0
	set_forecast(null)
	queue_redraw()


func _set_target_state(targetable: bool, hot: bool) -> void:
	_targetable = targetable
	_hot = hot
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if targetable else Control.CURSOR_ARROW
	if not _defeated:
		_sprite.self_modulate = Color(1.3, 1.25, 1.15) if hot else Color.WHITE
		# The enemy being aimed at steps in front of its neighbours.
		z_index = 1 if hot else 0
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


## Shadow on the ground under the art.
func _draw() -> void:
	if _defeated:
		return
	draw_set_transform(_home + Vector2(_side * 0.5, _side - _side * 0.045), 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, _side * 0.36, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Hourglass, ticks left, and the kind of action that is coming.
func _draw_plate() -> void:
	if not _has_intent or _defeated:
		return
	var font := UiTheme.display_font()
	var number := str(maxi(_countdown, 0))
	var number_size := 50
	var number_w := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	var word := "" if _compact else EnemyActionData.intent_name(_intent)
	var word_size := 24
	var word_w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
	var chip_w := (word_w + 78.0) if not _compact else 66.0
	var chip_h := 40.0
	# A delayed action: a "DELAYED" tag after the intent (a short bar in compact slots).
	var delay_word := "" if _compact else "DELAYED"
	var delay_w := 0.0
	if _delayed:
		delay_w = 14.0 + (font.get_string_size(delay_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 30.0 if not _compact else 22.0)
	var total := 34.0 + 10.0 + number_w + 16.0 + chip_w + delay_w
	var x := (_plate.size.x - total) * 0.5
	var mid := 100.0
	var urgent := _countdown <= 1
	var count_color := UiTheme.DANGER if urgent else UiTheme.GOLD
	if _delayed:
		count_color = UiTheme.WHITE_MAGIC

	UiTheme.draw_hourglass(_plate, Vector2(x + 17.0, mid), 34.0, count_color)
	x += 44.0
	UiTheme.draw_text(_plate, font, Vector2(x, mid - font.get_height(number_size) * 0.5), number, number_size, count_color, 8)
	x += number_w + 16.0

	var color: Color = UiTheme.INTENT_COLORS[_intent]
	var chip := Rect2(x, mid - chip_h * 0.5, chip_w, chip_h)
	UiTheme.fill_para(_plate, chip, color)
	UiTheme.stroke_para(_plate, chip, Color(UiTheme.INK, 0.9), 2.0)
	UiTheme.draw_intent_icon(_plate, _intent, Vector2(x + 34.0, mid), 22.0, UiTheme.INK)
	if not _compact:
		UiTheme.draw_text(_plate, font, Vector2(x + 54.0, mid - font.get_height(word_size) * 0.5), word, word_size, UiTheme.INK)
	if _delayed:
		var tag := Rect2(x + chip_w + 14.0, mid - 15.0, delay_w - 14.0, 30.0)
		UiTheme.fill_para(_plate, tag, Color(UiTheme.INK, 0.92))
		UiTheme.stroke_para(_plate, tag, UiTheme.WHITE_MAGIC, 2.0)
		if not _compact:
			UiTheme.draw_text(_plate, font, Vector2(tag.position.x, mid - font.get_height(18) * 0.5), delay_word, 18,
				UiTheme.WHITE_MAGIC, 0, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _trait_tag(t: String) -> Control:
	var tag := SlantPanel.new()
	var text := t.to_upper()
	var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 34.0
	tag.custom_minimum_size = Vector2(w, 26)
	tag.fill = Color(UiTheme.INK, 0.92)
	tag.border = UiTheme.EFFECTIVE
	tag.border_width = 2.0
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.tooltip_text = EnemyTraits.describe(t)
	var l := UiTheme.label(text, 17, UiTheme.EFFECTIVE, true, 4)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(l)
	return tag


## Corner brackets that mark an enemy as a possible, or the current, target.
func _draw_overlay() -> void:
	if not _targetable or _defeated:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var color := UiTheme.GOLD if _hot else Color(UiTheme.DANGER, 0.45 + 0.35 * pulse)
	var grow := (6.0 if _hot else 0.0) + pulse * 5.0
	var inset := _side * 0.12
	var r := Rect2(_home + Vector2(inset, inset * 0.6), Vector2(_side - inset * 2.0, _side - inset * 1.1)).grow(grow)
	var arm := minf(46.0, _side * 0.12)
	var w := 6.0 if _hot else 4.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var p := r.position + r.size * corner
		var dx := arm if corner.x == 0.0 else -arm
		var dy := arm if corner.y == 0.0 else -arm
		_overlay.draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p, p + Vector2(0, dy)]), color, w, true)
