class_name WarTable
extends Control
## The table in the gatehouse where the day's fight is chosen: the scouts' reports laid out side by
## side (one per front, or the single report of a boss), under candlelight. Choosing one marches the
## party out; the commander can also step back to the city to change the party first.

signal chosen(front: Front)
signal closed

const CARDS_TOP := 300.0

var run: Run
var _title: Label
var _words: Label
var _row := HBoxContainer.new()
var _fronts: Array[Front] = []
var _time := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = UiTheme.label("", 54, UiTheme.GOLD, true, 8)
	_title.position = Vector2(0, 96)
	_title.size = Vector2(1920, 70)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_words = UiTheme.label("", 24, UiTheme.TEXT, false, 4)
	_words.add_theme_font_override("font", UiTheme.italic_font())
	_words.position = Vector2(260, 190)
	_words.size = Vector2(1400, 70)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_words)
	_row.add_theme_constant_override("separation", 34)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.position = Vector2(0, CARDS_TOP)
	_row.size = Vector2(1920, FrontCard.H)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var back := Button.new()
	back.text = "Return to the city"
	back.tooltip_text = "Step away from the table. The party can still be changed before you march.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(960 - 190, 880)
	back.size = Vector2(380, 62)
	back.pressed.connect(close)
	add_child(back)


func open(p_run: Run) -> void:
	run = p_run
	_fronts = run.fronts.duplicate()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var boss := run.day_type() == RunCalendar.DayType.BOSS
	_title.text = "THE WAR TABLE" if not boss else "THE LAST LINE"
	_words.text = "The scouts have marked where they will strike today. We can hold only one of these; the others we leave to the walls." \
		if not boss else "There is nowhere else to stand today. If we fall here, the city falls with us."
	for i in _fronts.size():
		var f := _fronts[i]
		var card := FrontCard.new()
		card.setup(f, str(i + 1), run.battle_block_reason(f))
		card.chosen.connect(_choose.bind(f))
		_row.add_child(card)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _choose(front: Front) -> void:
	if run.battle_block_reason(front) != "":
		return
	visible = false
	chosen.emit(front)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	# The table top: dark boards, lit from the candles at its corners.
	draw_rect(Rect2(0, 0, w, h), Color("1b130d"))
	UiTheme.draw_grain(self, Rect2(0, 0, w, h), 0.16)
	var seam := Color(0, 0, 0, 0.35)
	for i in range(1, 6):
		draw_line(Vector2(0, h * i / 6.0), Vector2(w, h * i / 6.0), seam, 2.0)
	# An old map under the reports: a compass rose and a few inked lines.
	var ink := Color(UiTheme.GOLD_DEEP, 0.28)
	var rose := Vector2(w - 190.0, 170.0)
	draw_arc(rose, 70.0, 0.0, TAU, 48, ink, 1.5, true)
	draw_arc(rose, 54.0, 0.0, TAU, 48, ink, 1.0, true)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 - PI * 0.5)
		var side := d.orthogonal() * (9.0 if i % 2 == 0 else 5.0)
		var tip := rose + d * (88.0 if i % 2 == 0 else 52.0)
		draw_colored_polygon(PackedVector2Array([rose + side, tip, rose - side]), ink)
	for k in 3:
		var pts := PackedVector2Array()
		for i in 40:
			var t := i / 39.0
			pts.append(Vector2(w * t, h * (0.28 + 0.26 * k) + 46.0 * sin(t * 6.0 + k * 2.1) + 18.0 * sin(t * 17.0 + k)))
		draw_polyline(pts, Color(UiTheme.GOLD_DEEP, 0.12), 1.5, true)
	# Candles.
	for c: Vector2 in [Vector2(120, 250), Vector2(w - 120.0, h - 150.0)]:
		var flick := 0.9 + 0.1 * sin(_time * 9.0 + c.x)
		for i in 6:
			draw_circle(c + Vector2(0, -40), 70.0 + 80.0 * i, Color(1.0, 0.72, 0.36, 0.03 * flick))
		draw_rect(Rect2(c.x - 9, c.y - 34, 18, 64), Color("d9c9a0"))
		draw_rect(Rect2(c.x + 2, c.y - 34, 7, 64), Color("b3a27a"))
		draw_set_transform(c + Vector2(0, 30), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 22.0, Color("7d6032"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		CityArt.flame(self, c + Vector2(0, -36), 8.0, _time)
	# Darker toward the edges.
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0, 0, 0, 0.55)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 200), Vector2(0, 200)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h - 240.0), Vector2(w, h - 240.0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, dark, dark]))
	UiTheme.draw_rule(self, Vector2(w * 0.5, 176.0), 520.0, Color(UiTheme.GOLD_DEEP, 0.9))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var i := key.keycode - KEY_1
		if i < _fronts.size():
			get_viewport().set_input_as_handled()
			_choose(_fronts[i])
