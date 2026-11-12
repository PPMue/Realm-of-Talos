class_name SlantBar
extends Control
## A leaning HP / stamina bar. The fill glides to new values, a pale trail shows what was just lost,
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
	set_process(_preview > 0.0)
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
	var s := UiTheme.slant_for(size.y)
	var span := size.x - s
	if span <= 2.0:
		return
	UiTheme.fill_para(self, Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.85))
	var shown := clampf(_shown / _max, 0.0, 1.0)
	var trail := clampf(_trail / _max, 0.0, 1.0)
	if trail > shown:
		_segment(shown, trail, Color(1, 1, 1, 0.75), s, span)
	if shown > 0.0:
		_segment(0.0, shown, fill_color, s, span)
		# Lighter band along the top for a little depth.
		var top := PackedVector2Array([
			Vector2(s, 0), Vector2(s + span * shown, 0),
			Vector2(s * 0.6 + span * shown, size.y * 0.4), Vector2(s * 0.6, size.y * 0.4)])
		if span * shown > 2.0:
			draw_colored_polygon(top, Color(1, 1, 1, 0.16))
	if _preview > 0.0 and shown > 0.0:
		var from := clampf((_shown - _preview) / _max, 0.0, 1.0)
		var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 110.0)
		_segment(from, shown, Color(1, 0.95, 0.7, pulse), s, span)
	UiTheme.stroke_para(self, Rect2(Vector2.ZERO, size), Color(UiTheme.INK, 0.9), 2.0)
	if show_text:
		var text := "%s%d / %d" % [label_prefix, roundi(_value), roundi(_max)]
		var font := UiTheme.body_font()
		var top_y := (size.y - font.get_height(font_size)) * 0.5
		UiTheme.draw_text(self, font, Vector2(0, top_y), text, font_size, UiTheme.TEXT, 5, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _segment(from: float, to: float, color: Color, s: float, span: float) -> void:
	if (to - from) * span < 1.0:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(s + span * from, 0), Vector2(s + span * to, 0),
		Vector2(span * to, size.y), Vector2(span * from, size.y)]), color)
