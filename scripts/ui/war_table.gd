class_name WarTable
extends Control
## The table in the gatehouse where the day's fight is chosen: the scouts' reports laid out side by
## side (one per front, or the single report of a boss), under candlelight, and under them the
## company as it will march: the line from the rear to the front, each place with the share of the
## enemy's blows it draws, then whoever waits in reserve and whoever lies in the infirmary. Someone
## can be carried to another place or to the reserve, or clicked and then set down with a second
## click (Left and Right move whoever is picked up), so the line can be set against what the reports
## show without leaving the table. Choosing a report marches the party out.

signal chosen(front: Front)
signal closed

const CARDS_TOP := 150.0
## The company, under the reports.
const LINE_X := 176.0
const LINE_GAP := 16.0
const LINE_LABEL_Y := 688.0
const LINE_Y := 716.0
const LINE_ROW := 92.0
const RESERVE_LABEL_Y := 828.0
const RESERVE_Y := 856.0
const RESERVE_STEP := 84.0
const TABLE_END := 1064.0

var run: Run
var _title: Label
var _words: Label
var _row := HBoxContainer.new()
var _fronts: Array[Front] = []
var _time := 0.0
var _company := Control.new()
var _marks := Control.new()
## Whoever was clicked and waits to be set down with a second click.
var _picked: RunCompanion


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = UiTheme.label("", 48, UiTheme.GOLD, true, 8)
	_title.position = Vector2(0, 22)
	_title.size = Vector2(1920, 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_words = UiTheme.label("", 21, UiTheme.TEXT, false, 4)
	_words.add_theme_font_override("font", UiTheme.italic_font())
	_words.position = Vector2(160, 102)
	_words.size = Vector2(1600, 34)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_words)
	_row.add_theme_constant_override("separation", 34)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.position = Vector2(0, CARDS_TOP)
	_row.size = Vector2(1920, FrontCard.H)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	# The company: chalk marks first, then the reserve's ground (it takes anyone set down on it), then
	# the markers themselves.
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	var reserve_ground := Control.new()
	reserve_ground.position = Vector2(LINE_X - 8.0, RESERVE_LABEL_Y - 4.0)
	reserve_ground.size = Vector2(_line_width() + 16.0, TABLE_END - RESERVE_LABEL_Y + 8.0)
	reserve_ground.mouse_filter = Control.MOUSE_FILTER_PASS
	reserve_ground.set_drag_forwarding(Callable(), _can_reserve, func(_at: Vector2, data: Variant) -> void:
		place((data as Dictionary)["companion"], -1))
	reserve_ground.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _picked != null and run.is_fielded(_picked):
			place(_picked, -1))
	add_child(reserve_ground)
	_company.set_anchors_preset(Control.PRESET_FULL_RECT)
	_company.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_company)

	var back := Button.new()
	back.text = "Return to the city"
	back.tooltip_text = "Step away from the table. Weapons and arts are changed at the barracks.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 26)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)


func open(p_run: Run) -> void:
	run = p_run
	_fronts = run.fronts.duplicate()
	_picked = null
	var boss := run.day_type() == RunCalendar.DayType.BOSS
	_title.text = "THE WAR TABLE" if not boss else "THE LAST LINE"
	_words.text = "The scouts have marked where they will strike today. We can hold only one of these; the others we leave to the walls." \
		if not boss else "There is nowhere else to stand today. If we fall here, the city falls with us."
	_build_cards()
	refresh_company()
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


## The scouts' reports. Built again whenever the line changes: an empty line cannot march.
func _build_cards() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in _fronts.size():
		var f := _fronts[i]
		var card := FrontCard.new()
		card.setup(f, str(i + 1), run.battle_block_reason(f))
		card.chosen.connect(_choose.bind(f))
		_row.add_child(card)


# ---------------------------------------------------------------- the company

## Sets `c` down at place `index` of the line (0 = the rear), or in reserve when `index` is -1 (the
## barracks' rule: PartyScreen.set_down).
func place(c: RunCompanion, index: int) -> void:
	if c == null or run == null or not run.can_change_party():
		return
	PartyScreen.set_down(run, c, index)
	_picked = null
	_changed()


## A click on one of the company: the first picks them up, the second sets whoever was picked up down
## where the click fell (two in the line change order; one in the line and one in reserve change places).
func click(c: RunCompanion) -> void:
	if run == null or not run.can_change_party() or c == null or c.injured:
		return
	if _picked == null:
		_picked = c
	elif _picked == c:
		_picked = null
	elif run.is_fielded(c):
		place(_picked, run.lineup.find(c))
		return
	elif run.is_fielded(_picked):
		# Someone in reserve takes the place of whoever was picked up.
		var at := run.lineup.find(_picked)
		run.bench(_picked)
		run.field(c, at)
		_picked = null
		_changed()
		return
	else:
		_picked = c
	refresh_company()


func _changed() -> void:
	_build_cards()
	refresh_company()


static func _line_width() -> float:
	return MusterRow.W * RunConfig.MAX_FIELDED + LINE_GAP * (RunConfig.MAX_FIELDED - 1)


static func _place_x(i: int) -> float:
	return LINE_X + i * (MusterRow.W + LINE_GAP)


## The share (percent) of the enemy's single blows each place in the line draws: each place forward
## counts BattleConfig.TARGET_WEIGHT_GROWTH times the one behind, times what the held weapon does
## to it (as Battle weighs targets when nobody is guarding or veiled).
func blow_shares() -> Array[int]:
	var weights: Array[float] = []
	var total := 0.0
	for i in run.lineup.size():
		var w := BattleConfig.TARGET_WEIGHT_BASE * pow(BattleConfig.TARGET_WEIGHT_GROWTH, i)
		var held := run.lineup[i].weapon()
		if held != null:
			w *= held.target_weight_mult
		weights.append(w)
		total += w
	var out: Array[int] = []
	for w in weights:
		out.append(roundi(100.0 * w / maxf(0.001, total)))
	return out


func refresh_company() -> void:
	for child in _company.get_children():
		_company.remove_child(child)
		child.queue_free()
	_marks.queue_redraw()
	if run == null:
		return
	var carry := run.can_change_party()
	for i in RunConfig.MAX_FIELDED:
		var c: RunCompanion = run.lineup[i] if i < run.lineup.size() else null
		var row := _marker(c, MusterRow.Kind.LINE, LINE_ROW, carry)
		row.position = Vector2(_place_x(i), LINE_Y)
		row.dropped.connect(place.bind(i))
		if c == null:
			# An empty place takes whoever was picked up.
			row.gui_input.connect(func(event: InputEvent) -> void:
				var mb := event as InputEventMouseButton
				if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _picked != null:
					place(_picked, i))
		_company.add_child(row)
	# The reserve, then the infirmary, four to a row.
	var waiting: Array = []
	for c in run.reserve():
		waiting.append([c, MusterRow.Kind.BENCH, ""])
	for c in run.infirmary():
		var left := c.days_left(run.day)
		waiting.append([c, MusterRow.Kind.INFIRMARY, "up tomorrow" if left <= 1 else "%d days" % left])
	var rows := ceili(waiting.size() / float(RunConfig.MAX_FIELDED))
	var step := minf(RESERVE_STEP, (TABLE_END - RESERVE_Y) / maxi(1, rows))
	for k in waiting.size():
		var entry: Array = waiting[k]
		var row := _marker(entry[0], entry[1], step - 8.0, carry)
		row.note = entry[2]
		row.position = Vector2(_place_x(k % RunConfig.MAX_FIELDED), RESERVE_Y + (k / RunConfig.MAX_FIELDED) * step)
		if entry[1] == MusterRow.Kind.BENCH:
			row.dropped.connect(place.bind(-1))
		_company.add_child(row)


func _marker(c: RunCompanion, kind: MusterRow.Kind, h: float, carry: bool) -> MusterRow:
	var row := MusterRow.new()
	row.can_carry = carry
	row.setup(c, kind, h)
	if c != null:
		row.set_selected(c == _picked)
		if kind != MusterRow.Kind.INFIRMARY:
			row.pressed.connect(click.bind(c))
	return row


func _can_reserve(_at: Vector2, data: Variant) -> bool:
	return run != null and run.can_change_party() and data is Dictionary \
		and (data as Dictionary).get("companion") is RunCompanion and run.is_fielded((data as Dictionary)["companion"])


## Chalk beside the company's markers: which end of the line is which, the blows each place draws,
## and the reserve.
func _draw_marks() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var chalk := Color(UiTheme.TEXT, 0.62)
	var n := run.lineup.size()
	var shares := blow_shares()
	for i in RunConfig.MAX_FIELDED:
		var x := _place_x(i)
		var word := ""
		if i == 0 and n > 1:
			word = "THE REAR"
		elif i == n - 1:
			word = "THE FRONT"
		if word != "":
			UiTheme.draw_text(_marks, display, Vector2(x + 4.0, LINE_LABEL_Y), word, 17, UiTheme.GOLD if i == n - 1 else UiTheme.MUTED, 5)
		if i < n:
			var figure := "%d%%" % shares[i]
			var tail := " of the blows"
			var tw := italic.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var fw := display.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			var right := x + MusterRow.W - 4.0
			UiTheme.draw_text(_marks, italic, Vector2(right - tw, LINE_LABEL_Y + 3.0), tail, 16, chalk, 4)
			UiTheme.draw_text(_marks, display, Vector2(right - tw - fw, LINE_LABEL_Y - 2.0), figure, 21,
				UiTheme.TEXT.lerp(UiTheme.DANGER, clampf((shares[i] - 25.0) / 40.0, 0.0, 1.0)), 5)
	# Toward the enemy.
	var end_x := LINE_X + _line_width() + 18.0
	var mid_y := LINE_Y + LINE_ROW * 0.5
	_marks.draw_line(Vector2(end_x, mid_y), Vector2(end_x + 46.0, mid_y), Color(UiTheme.GOLD_DEEP, 0.9), 3.0, true)
	_marks.draw_colored_polygon(PackedVector2Array([Vector2(end_x + 62.0, mid_y), Vector2(end_x + 42.0, mid_y - 11.0),
		Vector2(end_x + 42.0, mid_y + 11.0)]), Color(UiTheme.GOLD_DEEP, 0.9))
	UiTheme.draw_text(_marks, italic, Vector2(end_x - 6.0, mid_y + 16.0), "the enemy", 16, chalk, 4)

	var reserve := run.reserve()
	var beds := run.infirmary()
	var head := "IN RESERVE"
	if reserve.is_empty() and not beds.is_empty():
		head = "IN THE INFIRMARY"
	elif not beds.is_empty():
		head = "IN RESERVE, AND IN THE INFIRMARY"
	UiTheme.draw_text(_marks, display, Vector2(LINE_X + 4.0, RESERVE_LABEL_Y), head, 17, UiTheme.MUTED, 5)
	var aside := "Carry someone to another place or down here. Or click them, then click where they should stand."
	if _picked != null:
		aside = "%s is picked up: click where they should stand." % _picked.display_name()
	UiTheme.draw_text(_marks, italic, Vector2(LINE_X, RESERVE_LABEL_Y + 2.0), aside, 16, UiTheme.GOLD if _picked != null else chalk, 4, _line_width(),
		HORIZONTAL_ALIGNMENT_RIGHT)
	if reserve.is_empty() and beds.is_empty():
		UiTheme.draw_text(_marks, italic, Vector2(LINE_X + 4.0, RESERVE_Y + 14.0), "Nobody waits behind the line.", 18, Color(chalk, 0.45), 4)


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
	for c: Vector2 in [Vector2(96, 330), Vector2(w - 96.0, 520.0)]:
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
	# The foot of the table, where the company's markers stand, lies in shadow.
	draw_polygon(PackedVector2Array([Vector2(0, LINE_LABEL_Y - 60.0), Vector2(w, LINE_LABEL_Y - 60.0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, dark, dark]))
	UiTheme.draw_rule(self, Vector2(w * 0.5, 92.0), 520.0, Color(UiTheme.GOLD_DEEP, 0.9))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _picked != null:
			_picked = null
			refresh_company()
		else:
			close()
	elif (key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT) and _picked != null and run.is_fielded(_picked) and run.can_change_party():
		# Whoever is picked up steps toward the rear or the front.
		get_viewport().set_input_as_handled()
		run.move_in_line(_picked, run.lineup.find(_picked) + (-1 if key.keycode == KEY_LEFT else 1))
		_changed()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var i := key.keycode - KEY_1
		if i < _fronts.size():
			get_viewport().set_input_as_handled()
			_choose(_fronts[i])
