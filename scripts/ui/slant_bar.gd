class_name SlantBar
extends Control
## An HP / stamina bar set into a trough. The fill glides to new values, a pale trail shows what was just lost,
## and a pulsing segment can preview damage about to be dealt.

var fill_color := UiTheme.HP
var label_prefix := ""
var font_size := 18
var show_text := true

var _value := 0.0
var _max := 1.0
var _shown := 0.0
var _trail := 0.0
var _preview := 0.0
var _heal_to := -INF
var _started := false
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## `value` may be negative (injured companions); the fill simply stays empty.
func set_values(value: float, maximum: float, animate: bool = true) -> void:
	_max = maxf(1.0, maximum)
	if _started and is_equal_approx(value, _value):
		queue_redraw()
		return
	_value = value
	if _tween != null:
		_tween.kill()
	if not _started or not animate or not is_inside_tree():
		_started = true
		_shown = value
		_trail = value
		queue_redraw()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_shown, _shown, value, 0.18)
	_tween.tween_method(_set_trail, maxf(_trail, _shown), value, 0.45).set_delay(0.3)


## Highlights the last `amount` of the fill, as a preview of damage.
func set_preview(amount: float) -> void:
	_preview = maxf(0.0, amount)
	set_process(_preview > 0.0 or _heal_to > -INF)
	queue_redraw()


## Shows the fill a heal would reach (`to`); pass -INF to hide.
func set_heal_preview(to: float) -> void:
	_heal_to = to
	set_process(_preview > 0.0 or _heal_to > -INF)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _set_trail(v: float) -> void:
	_trail = v
	queue_redraw()


func _draw() -> void:
	var span := size.x
	if span <= 2.0:
		return
	# A trough cut into the board, the fill inside it, and a thin iron rim.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.025, 0.02, 0.9))
	var shown := clampf(_shown / _max, 0.0, 1.0)
	var trail := clampf(_trail / _max, 0.0, 1.0)
	if trail > shown:
		_segment(shown, trail, Color(1.0, 0.94, 0.8, 0.7), span)
	if shown > 0.0:
		_segment(0.0, shown, fill_color.darkened(0.12), span)
		# Lighter band along the top, darker along the bottom, for a little roundness.
		if span * shown > 2.0:
			draw_rect(Rect2(0, 0, span * shown, size.y * 0.42), Color(1, 0.95, 0.85, 0.16))
			draw_rect(Rect2(0, size.y * 0.78, span * shown, size.y * 0.22), Color(0, 0, 0, 0.18))
	if _preview > 0.0 and shown > 0.0:
		var from := clampf((_shown - _preview) / _max, 0.0, 1.0)
		var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 110.0)
		_segment(from, shown, Color(1, 0.95, 0.7, pulse), span)
	if _heal_to > _shown:
		var heal_from := clampf(_shown / _max, 0.0, 1.0)
		var heal_to := clampf(_heal_to / _max, 0.0, 1.0)
		var glow := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 110.0)
		_segment(heal_from, heal_to, Color(UiTheme.HEAL, glow), span)
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.INK, 0.95), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color(UiTheme.EDGE, 0.8), false, 1.0)
	if show_text:
		var text := "%s%d / %d" % [label_prefix, roundi(_value), roundi(_max)]
		var font := UiTheme.display_font()
		var top_y := (size.y - font.get_height(font_size)) * 0.5
		UiTheme.draw_text(self, font, Vector2(0, top_y), text, font_size, UiTheme.TEXT, 5, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _segment(from: float, to: float, color: Color, span: float) -> void:
	if (to - from) * span < 1.0:
		return
	draw_rect(Rect2(span * from, 0, span * (to - from), size.y), color)
