class_name PartyPanel
extends Control
## One companion in the battle line along the foot of the screen: a framed portrait with their name,
## health and stamina under it. The row is the line itself: the rightmost stands nearest the enemy.
## A companion's state is shown the way an enemy's is, in pictures rather than tags: someone catching
## their breath is dimmed under an hourglass and the number of actions left; someone injured is
## reddened and sunk; whoever is being commanded steps up out of the line. A small roundel gives how
## often the enemy aims at that place. Display only.

signal clicked
signal hover_changed(inside: bool)

enum Status { NONE, READY, RECOVERING, INJURED }

const W := 188.0
const H := 244.0
const LIFT := 24.0
const PORTRAIT_H := 170.0
const PAD := 5.0

var _body := Control.new()
var _portrait := SlantPanel.new()
var _marks := Control.new()
var _name: Label
var _effects: Label
var _hp := SlantBar.new()
var _sta := SlantBar.new()
var _preview: Label
var _status := Status.NONE
var _recovery := 0
var _threat := ""
var _threat_mirrored := false
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
	_body.draw.connect(_draw_frame)
	add_child(_body)

	_portrait.position = Vector2(PAD, PAD)
	_portrait.size = Vector2(W - PAD * 2.0, PORTRAIT_H)
	_portrait.zoom = 1.9
	_portrait.shade = 0.85
	_portrait.backing = true
	_portrait.border_width = 0.0
	_body.add_child(_portrait)

	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.position = _portrait.position
	_marks.size = _portrait.size
	_marks.draw.connect(_draw_marks)
	_body.add_child(_marks)

	_effects = UiTheme.label("", 13, UiTheme.GOLD, false, 5)
	_effects.position = Vector2(PAD + 6.0, PAD + PORTRAIT_H - 58.0)
	_effects.size = Vector2(W - PAD * 2.0 - 12.0, 20)
	_effects.clip_text = true
	_body.add_child(_effects)
	_name = UiTheme.label("", 25, UiTheme.TEXT, true, 8)
	_name.position = Vector2(PAD + 7.0, PAD + PORTRAIT_H - 40.0)
	_name.size = Vector2(W - PAD * 2.0 - 10.0, 36)
	_name.clip_text = true
	_body.add_child(_name)

	_hp.position = Vector2(PAD + 4.0, PAD + PORTRAIT_H + 8.0)
	_hp.size = Vector2(W - PAD * 2.0 - 8.0, 22.0)
	_hp.font_size = 15
	_body.add_child(_hp)
	_sta.position = Vector2(PAD + 4.0, PAD + PORTRAIT_H + 36.0)
	_sta.size = Vector2(W - PAD * 2.0 - 8.0, 16.0)
	_sta.fill_color = UiTheme.STA
	_sta.font_size = 12
	_body.add_child(_sta)

	# What a spell aimed at this companion would do, across the top of the portrait.
	_preview = UiTheme.label("", 16, UiTheme.HEAL, true, 6)
	_preview.position = Vector2(PAD, PAD + 6.0)
	_preview.size = Vector2(W - PAD * 2.0, 28)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview.clip_text = true
	_preview.visible = false
	_body.add_child(_preview)

	mouse_entered.connect(func() -> void:
		_hover = true
		hover_changed.emit(true)
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		hover_changed.emit(false)
		_restyle())


## `figure_scale`: CompanionData.figure_scale, so every face in the line is the same size.
func setup(display_name: String, portrait: Texture2D, focus: Vector2, figure_scale: float = 1.0) -> void:
	_name.text = display_name
	_portrait.texture = portrait
	_portrait.zoom = 1.9 * figure_scale
	_portrait.focus = focus + Vector2(0.0, 0.05)


## Kept for callers; the level is on the sheet Shift shows, not on the portrait.
func set_level(_level: int) -> void:
	pass


func set_hp(current: int, maximum: int) -> void:
	_hp.set_values(current, maximum)


func set_stamina(current: int, maximum: int) -> void:
	_sta.set_values(current, maximum)


func set_status(status: Status, recovery: int = 0) -> void:
	_status = status
	_recovery = recovery
	match status:
		Status.RECOVERING:
			_portrait.tint = Color(0.4, 0.4, 0.46)
		Status.INJURED:
			_portrait.tint = Color(0.7, 0.26, 0.24)
		_:
			_portrait.tint = Color.WHITE
	_settle()
	_marks.queue_redraw()
	_body.queue_redraw()


## `harmful`: shown in the poison colour (a debuff or damage over time is on).
func set_effects(text: String, harmful: bool = false) -> void:
	_effects.text = text
	_effects.add_theme_color_override("font_color", UiTheme.POISON if harmful else UiTheme.GOLD)


## How often the enemy aims at this place, for the roundel: "33%". `mirrored`: every enemy here aims
## from the left. "" hides the roundel.
func set_threat(text: String, mirrored: bool = false) -> void:
	_threat = text
	_threat_mirrored = mirrored
	_marks.queue_redraw()


## While a spell is aimed at companions: `targetable` marks a possible target, `hot` the one (or all)
## it would reach, with `preview` saying what it would do and `heal_to` the HP it would reach (or -INF).
func set_spell_target(targetable: bool, hot: bool, preview: String = "", heal_to: float = -INF) -> void:
	_targetable = targetable
	_target_hot = hot
	_preview.visible = hot and preview != ""
	_preview.text = preview
	var font_size := 16
	while font_size > 11 and UiTheme.display_font().get_string_size(preview, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _preview.size.x - 12.0:
		font_size -= 1
	_preview.add_theme_font_size_override("font_size", font_size)
	_hp.set_heal_preview(heal_to if hot else -INF)
	if targetable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_marks.queue_redraw()
	_restyle()


## `can_pick`: clicking would select this companion.
func set_selection(selected: bool, can_pick: bool) -> void:
	_can_pick = can_pick
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_pick else Control.CURSOR_ARROW
	if selected != _selected:
		_selected = selected
		_settle()
	_restyle()


func popup_anchor() -> Vector2:
	return global_position + Vector2(W * 0.5, LIFT + PORTRAIT_H * 0.45)


func play_hit(crit: bool) -> void:
	var push := 18.0 if crit else 10.0
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


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


## Where the body rests: stepped up when chosen, sunk when injured, in the line otherwise.
func _settle() -> void:
	var y := LIFT
	if _selected:
		y = 0.0
	elif _status == Status.INJURED:
		y = LIFT + 12.0
	if _lift_tween != null:
		_lift_tween.kill()
	if is_inside_tree():
		_lift_tween = create_tween()
		_lift_tween.tween_property(_body, "position:y", y, 0.12).set_ease(Tween.EASE_OUT)
	else:
		_body.position.y = y


func _restyle() -> void:
	_body.queue_redraw()


func _draw_frame() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(W, H))
	var trim := UiTheme.EDGE
	var width := 2.0
	var fill := Color(UiTheme.INK, 0.94)
	if _targetable:
		trim = UiTheme.HEAL if _target_hot else Color(UiTheme.HEAL, 0.45)
		width = 4.0 if _target_hot else 2.5
	elif _selected:
		trim = UiTheme.GOLD
		width = 3.5
		fill = Color(UiTheme.PANEL_HI, 0.97)
	elif _hover and _can_pick:
		trim = Color(UiTheme.GOLD, 0.8)
		width = 2.5
	elif _status == Status.INJURED:
		trim = Color(UiTheme.INJURED, 0.7)
	if _selected:
		# Lamp-light under whoever is being commanded.
		for i in 4:
			_body.draw_rect(rect.grow(4.0 + 5.0 * i), Color(UiTheme.GOLD, 0.05))
	UiTheme.draw_frame(_body, rect, fill, trim, width, false)


## Pictures over the portrait: the hourglass of someone catching their breath, the mark of someone
## injured, and the roundel of how often the enemy aims here.
func _draw_marks() -> void:
	var s := _marks.size
	var font := UiTheme.display_font()
	if _preview.visible:
		_marks.draw_rect(Rect2(0, 4, s.x, 32), Color(UiTheme.INK, 0.86))
	match _status:
		Status.RECOVERING:
			var c := Vector2(s.x * 0.5 - 22.0, s.y * 0.4)
			_marks.draw_circle(Vector2(s.x * 0.5, s.y * 0.4), 44.0, Color(UiTheme.INK, 0.55))
			UiTheme.draw_hourglass(_marks, c, 40.0, UiTheme.RECOVERING)
			UiTheme.draw_text(_marks, font, Vector2(s.x * 0.5, s.y * 0.4 - font.get_height(50) * 0.5), str(_recovery), 50,
				UiTheme.RECOVERING, 8)
		Status.INJURED:
			var band := Rect2(0, s.y * 0.34, s.x, 34.0)
			_marks.draw_rect(band, Color(UiTheme.INK, 0.8))
			_marks.draw_line(band.position, Vector2(band.end.x, band.position.y), Color(UiTheme.INJURED, 0.9), 1.5)
			_marks.draw_line(Vector2(0, band.end.y), band.end, Color(UiTheme.INJURED, 0.9), 1.5)
			UiTheme.draw_text(_marks, font, Vector2(0, band.position.y + (band.size.y - font.get_height(20)) * 0.5), "INJURED", 20,
				UiTheme.INJURED, 0, s.x, HORIZONTAL_ALIGNMENT_CENTER)
	if _threat != "" and not _preview.visible:
		var tw := font.get_string_size(_threat, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var r := Rect2(s.x - tw - 34.0, 6.0, tw + 30.0, 24.0)
		_marks.draw_rect(r, Color(UiTheme.INK, 0.78))
		UiIcons.swords(_marks, Vector2(r.position.x + 12.0, r.get_center().y), 14.0,
			UiTheme.REFLECT if _threat_mirrored else UiTheme.INTENT_COLORS[EnemyActionData.Intent.ATTACK])
		UiTheme.draw_text(_marks, font, Vector2(r.position.x + 24.0, r.position.y + (r.size.y - font.get_height(15)) * 0.5), _threat, 15,
			UiTheme.TEXT)
