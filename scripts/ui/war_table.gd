class_name WarTable
extends Control
## The table in the gatehouse where the day's fight is chosen: the scouts' reports laid out side by
## side (one per front, or the single report of a boss), under candlelight and drawn large, since
## the enemy is what this table is for. Along the foot, small, stands the line as it will march, from
## the rear to the front, each place with the share of the enemy's blows it draws. Each report also
## says the hardest blow waiting there for the line as it stands and the scouts' word for the fight,
## written again whenever the line changes. Its order can be
## changed here: carry someone onto another's place, or click them and then the place (Left and Right
## move whoever is picked up). Who is in the line at all is the barracks' business. Choosing a report
## marches the party out.

signal chosen(front: Front)
signal closed

const CARDS_TOP := 142.0
## The reports are drawn larger than a FrontCard is made: by this much when they fit, less when
## three lie side by side.
const CARD_SCALE := 1.2
const CARDS_ROOM := 1860.0
const CARD_GAP := 34.0
## The line, along the foot of the table.
const LINE_GAP := 16.0
const LINE_LABEL_Y := 862.0
const LINE_Y := 890.0
const LINE_ROW := 84.0

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
	_row.add_theme_constant_override("separation", int(CARD_GAP))
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.position = Vector2(0, CARDS_TOP)
	_row.size = Vector2(1920, FrontCard.H)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	# The line: chalk marks, then the markers themselves.
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_company.set_anchors_preset(Control.PRESET_FULL_RECT)
	_company.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_company)

	var back := Button.new()
	back.text = "Return to the city"
	back.tooltip_text = "Step away from the table. Who marches, their weapons and their arts are changed at the barracks.\nKey: Esc"
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
	if run.day_type() == RunCalendar.DayType.ELITE:
		_words.text = "Their best stand in two places today, and neither is the easier. We can hold only one; whoever breaks them brings home a stone."
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
	var wide := 0.0
	for i in _fronts.size():
		var f := _fronts[i]
		var card := FrontCard.new()
		card.setup(f, str(i + 1), run.battle_block_reason(f), run.front_account(f))
		card.chosen.connect(_choose.bind(f))
		_row.add_child(card)
		wide += card.custom_minimum_size.x + (CARD_GAP if i > 0 else 0.0)
	# As large as the table allows.
	var k := minf(CARD_SCALE, CARDS_ROOM / maxf(1.0, wide))
	_row.scale = Vector2(k, k)
	_row.size = Vector2(1920.0 / k, FrontCard.H)


# ---------------------------------------------------------------- the company

## Moves `c` to place `index` of the line (0 = the rear).
func place(c: RunCompanion, index: int) -> void:
	if c == null or run == null or not run.can_change_party() or not run.is_fielded(c):
		return
	run.move_in_line(c, index)
	_picked = null
	_changed()


## A click on one of the line: the first picks them up, the second sets whoever was picked up down in
## the place of whoever was clicked.
func click(c: RunCompanion) -> void:
	if run == null or not run.can_change_party() or c == null or not run.is_fielded(c):
		return
	if _picked == null:
		_picked = c
	elif _picked == c:
		_picked = null
	else:
		place(_picked, run.lineup.find(c))
		return
	refresh_company()


func _changed() -> void:
	_build_cards()
	refresh_company()


## Where place `i` of a line of `n` stands: the line is centred along the foot of the table.
static func _place_x(i: int, n: int) -> float:
	var wide := MusterRow.W * n + LINE_GAP * maxi(0, n - 1)
	return (1920.0 - wide) * 0.5 + i * (MusterRow.W + LINE_GAP)


## The share (percent) of the enemy's single blows each place in the line draws: each place forward
## counts BattleConfig.TARGET_WEIGHT_GROWTH times the one behind, times what the held weapon and
## the companion's traits do to it (as Battle weighs targets when nobody is guarding or veiled).
func blow_shares() -> Array[int]:
	var weights: Array[float] = []
	var total := 0.0
	for i in run.lineup.size():
		var w := BattleConfig.TARGET_WEIGHT_BASE * pow(BattleConfig.TARGET_WEIGHT_GROWTH, i)
		var held := run.lineup[i].weapon()
		if held != null:
			w *= held.target_weight_mult
		# Traits that draw the enemy's eye or turn it away, whatever the place.
		for t in run.lineup[i].traits:
			for m in t.modifiers:
				if m.kind == TraitModifier.Kind.AIM and m.who == TraitModifier.Who.SELF and m.place == TraitModifier.Place.ANY:
					w *= m.mult
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
	var n := run.lineup.size()
	var carry := run.can_change_party() and n > 1
	for i in n:
		var row := _marker(run.lineup[i], MusterRow.Kind.LINE, LINE_ROW, carry)
		row.position = Vector2(_place_x(i, n), LINE_Y)
		row.dropped.connect(place.bind(i))
		_company.add_child(row)


func _marker(c: RunCompanion, kind: MusterRow.Kind, h: float, carry: bool) -> MusterRow:
	var row := MusterRow.new()
	row.can_carry = carry
	row.setup(c, kind, h)
	if c != null:
		row.set_selected(c == _picked)
		row.pressed.connect(click.bind(c))
		row.tooltip_text += "\n\nCarry them onto another's place to change the order of the line, or click them and then the place."
	return row


## Chalk beside the line's markers: which end is which, and the blows each place draws.
func _draw_marks() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var chalk := Color(UiTheme.TEXT, 0.5)
	var n := run.lineup.size()
	if n == 0:
		UiTheme.draw_text(_marks, italic, Vector2(0, LINE_Y + 24.0), "Nobody is in the line. Set it at the barracks.", 20, Color(UiTheme.INJURED, 0.9), 4,
			1920.0, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var shares := blow_shares()
	for i in n:
		var x := _place_x(i, n)
		var word := ""
		if i == 0 and n > 1:
			word = "THE REAR"
		elif i == n - 1:
			word = "THE FRONT"
		if word != "":
			UiTheme.draw_text(_marks, display, Vector2(x + 4.0, LINE_LABEL_Y), word, 15, UiTheme.MUTED, 5)
		var figure := "%d%%" % shares[i]
		var tail := " of the blows"
		var tw := italic.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var fw := display.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var right := x + MusterRow.W - 4.0
		UiTheme.draw_text(_marks, italic, Vector2(right - tw, LINE_LABEL_Y + 1.0), tail, 15, chalk, 4)
		UiTheme.draw_text(_marks, display, Vector2(right - tw - fw, LINE_LABEL_Y - 2.0), figure, 18,
			UiTheme.TEXT.lerp(UiTheme.DANGER, clampf((shares[i] - 25.0) / 40.0, 0.0, 1.0)), 5)
	# Toward the enemy.
	var end_x := _place_x(n - 1, n) + MusterRow.W + 18.0
	var mid_y := LINE_Y + LINE_ROW * 0.5
	_marks.draw_line(Vector2(end_x, mid_y), Vector2(end_x + 40.0, mid_y), Color(UiTheme.GOLD_DEEP, 0.8), 2.5, true)
	_marks.draw_colored_polygon(PackedVector2Array([Vector2(end_x + 54.0, mid_y), Vector2(end_x + 36.0, mid_y - 9.0),
		Vector2(end_x + 36.0, mid_y + 9.0)]), Color(UiTheme.GOLD_DEEP, 0.8))
	if _picked != null:
		UiTheme.draw_text(_marks, italic, Vector2(0, LINE_Y + LINE_ROW + 10.0), "%s is picked up: click whose place they should take." % _picked.display_name(),
			17, UiTheme.GOLD, 4, 1920.0, HORIZONTAL_ALIGNMENT_CENTER)


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
	for c: Vector2 in [Vector2(70, 900), Vector2(w - 70.0, 900.0)]:
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
	draw_polygon(PackedVector2Array([Vector2(0, LINE_LABEL_Y - 40.0), Vector2(w, LINE_LABEL_Y - 40.0), Vector2(w, h), Vector2(0, h)]),
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
