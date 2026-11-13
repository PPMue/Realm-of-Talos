class_name TrainingScreen
extends Control
## The drill yard. The company is listed down the left, the one chosen stands in the yard, and the
## sergeant's board on the right carries the week's notices: Sparring and two drills. Choose a notice
## and one of the company, then set them to it: that is the day's one thing, and it costs a few coins.
## How it went is then written up on the board: a poor, good or great drill, the line toward the next
## grade (or the next level) filling by what it gave, and after sparring every level gained shown
## stat by stat like after a battle, and an art or spell learned from a new grade written out in full
## (with the swap, if all three places are taken). Only reads the run and calls Run.train.

signal closed

enum Stage { CHOOSE, RESULT, LEVELS, LEARNED, DONE }

const LIST_X := 60.0
const LIST_Y := 156.0
const LIST_W := 340.0
const ROW_H := 78.0
## The chosen companion, standing between the list and the board.
const FIGURE_FACE := Vector2(660, 300)
const FIGURE_ART := 780.0
const FLOOR_Y := 1010.0
const BOARD := Rect2(940, 120, 920, 920)
const NOTICE := Vector2(840, 190)
const NOTICE_X := 40.0
const NOTICE_Y := 48.0
const NOTICE_STEP := 212.0
const REPORT := Rect2(40, 48, 840, 614)
const FOOT_Y := 706.0
## Seconds before the line starts to fill, and seconds it takes.
const COUNT_DELAY := 0.55
const COUNT_SECONDS := 0.9
const QUALITY_TITLES: Array[String] = ["A POOR DRILL", "A GOOD DRILL", "A GREAT DRILL"]
const BOUT_TITLES: Array[String] = ["A POOR BOUT", "A GOOD BOUT", "A GREAT BOUT"]
const QUALITY_LINES: Array[String] = [
	"\"Again tomorrow. And the day after.\"",
	"\"Solid work. That is how it is done.\"",
	"\"Now that... that I have not seen in years.\"",
]

var run: Run
var _stage := Stage.CHOOSE
var _drill: Drill
var _who: RunCompanion
var _result: DrillResult
## How much of the result's points or XP has been counted in so far.
var _shown := 0.0
var _stamp := 0.0
var _tween: Tween
var _next_level := 0
## Arts and spells the drill taught, still to show: {art, equipped} or {spell}.
var _learned: Array[Dictionary] = []
var _next_learned := 0

var _rows: Dictionary = {}          # RunCompanion -> Control
var _row_box := Control.new()
var _scene := Control.new()
var _board := Control.new()
var _notices := Control.new()
var _report := Control.new()
var _begin := ActionButton.new()
var _slip := Control.new()
var _why: Label
var _purse := Control.new()
var _hint: Label
var _dim := ColorRect.new()
var _panel := LevelUpPanel.new()
var _learn := LearnedPanel.new()
var _back := Button.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run) -> void:
	run = p_run
	_stage = Stage.CHOOSE
	_result = null
	_drill = run.drills[0] if not run.drills.is_empty() else null
	_who = null
	for child in _row_box.get_children():
		_row_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	# The line first, then the bench; a large company packs its rows closer.
	var company: Array[RunCompanion] = []
	company.append_array(run.lineup)
	company.append_array(run.reserve())
	var step := minf(ROW_H, 880.0 / maxi(1, company.size()))
	for i in company.size():
		var row := _make_row(company[i], step - 8.0)
		row.position = Vector2(0, i * step)
		_row_box.add_child(row)
		_rows[company[i]] = row
	_who = _first_able(company)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	_refresh()


func close() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false
	closed.emit()


func choose_drill(d: Drill) -> void:
	if _stage != Stage.CHOOSE:
		return
	_drill = d
	# Keep whoever is chosen if they can take it; else the first who can.
	if _who == null or run.drill_block_reason(d, _who) != "":
		var able := _first_able(_company())
		if able != null and run.drill_block_reason(d, able) == "":
			_who = able
	_refresh()


func select(c: RunCompanion) -> void:
	if _stage != Stage.CHOOSE:
		return
	_who = c
	_refresh()


## Sets the chosen companion to the chosen drill and shows how it went.
func begin() -> void:
	if _stage != Stage.CHOOSE or _drill == null or _who == null or run.drill_block_reason(_drill, _who) != "":
		return
	_result = run.train(_drill, _who)
	if _result == null:
		_refresh()
		return
	_stage = Stage.RESULT
	_shown = 0.0
	_stamp = 0.0
	_next_level = 0
	_learned.clear()
	_next_learned = 0
	for g: Dictionary in _result.grade_ups:
		if g.get("art") != null:
			_learned.append({"art": g.art, "equipped": bool(g.get("equipped", false))})
		if g.get("spell") != null:
			_learned.append({"spell": g.spell})
	_refresh()
	var total := float(_amount())
	_tween = create_tween()
	_tween.tween_method(_set_stamp, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(COUNT_DELAY - 0.22)
	_tween.tween_method(_set_shown, 0.0, total, COUNT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(0.25)
	_tween.tween_callback(_counted)


## A click, Space or Enter: ends what is still counting, or goes on to the next thing to show.
func advance() -> void:
	match _stage:
		Stage.RESULT:
			if _tween != null and _tween.is_running():
				_tween.kill()
				_set_stamp(1.0)
				_set_shown(float(_amount()))
				_counted()
			else:
				_next_beat()
		Stage.LEVELS:
			if not _panel.is_done():
				_panel.skip()
			else:
				_next_beat()
		Stage.LEARNED:
			# An art that waits for a decision has its own way on.
			if not _learn.needs_choice():
				_next_beat()


func is_done() -> bool:
	return _stage == Stage.DONE


# ---------------------------------------------------------------- what the rules say

func _company() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	out.append_array(run.lineup)
	out.append_array(run.reserve())
	return out


func _first_able(company: Array[RunCompanion]) -> RunCompanion:
	if _drill != null:
		for c in company:
			if run.drill_block_reason(_drill, c) == "":
				return c
	return company[0] if not company.is_empty() else null


## What the drill `d` gives whoever is chosen when it goes poorly, well and very well (their traits
## can change it).
func _amounts(d: Drill) -> Array[int]:
	var out: Array[int] = []
	for q in 3:
		out.append(run.drill_xp_for(_who, q) if d.kind == Drill.Kind.SPARRING else run.drill_points(d, _who, q))
	return out


## Points `c` has in what `d` trains.
static func _points(d: Drill, c: RunCompanion) -> int:
	return c.progress.points_in(d.weapon_type) if d.kind == Drill.Kind.WEAPON else c.progress.magic_points_in(d.school)


## Grade, points into it and points it needs (0 at the top grade) for a total of `points`.
static func _grade_standing(points: int) -> Vector3i:
	var g := Proficiency.grade_for_points(points)
	if g >= Proficiency.max_grade():
		return Vector3i(g, 0, 0)
	var floor_points := Proficiency.points_for(g)
	return Vector3i(g, points - floor_points, Proficiency.points_for(g + 1) - floor_points)


## Level, XP into it and XP it needs (0 at the top level) after `extra` more XP from (level, xp).
static func _level_standing(level: int, xp: int, extra: int) -> Vector3i:
	xp += extra
	while level < RunConfig.MAX_LEVEL and xp >= Levels.xp_to_next(level):
		xp -= Levels.xp_to_next(level)
		level += 1
	if level >= RunConfig.MAX_LEVEL:
		return Vector3i(level, 0, 0)
	return Vector3i(level, xp, Levels.xp_to_next(level))


## What the result gave: XP for sparring, points for a drill.
func _amount() -> int:
	if _result == null:
		return 0
	return _result.xp_gained if _result.drill.kind == Drill.Kind.SPARRING else _result.points_gained


# ---------------------------------------------------------------- the result

func _set_shown(v: float) -> void:
	_shown = v
	_report.queue_redraw()


func _set_stamp(v: float) -> void:
	_stamp = v
	_report.queue_redraw()


func _counted() -> void:
	_tween = null
	if _result.level_ups.is_empty() and _learned.is_empty():
		_finish()
	else:
		_hint.visible = true


## The next thing to show after the board: a level gained, then anything learned, then the way back.
func _next_beat() -> void:
	if _next_level < _result.level_ups.size():
		_show_next_level()
	elif _next_learned < _learned.size():
		_show_next_learned()
	else:
		_finish()


func _show_next_learned() -> void:
	var l := _learned[_next_learned]
	_next_learned += 1
	_stage = Stage.LEARNED
	_panel.visible = false
	_dim.visible = true
	_learn.visible = true
	_learn.modulate.a = 0.0
	create_tween().tween_property(_learn, "modulate:a", 1.0, 0.12)
	if l.has("art"):
		_learn.show_art(_who.progress, _who.display_name(), l.art, l.equipped)
	else:
		_learn.show_spell(_who.progress, _who.display_name(), l.spell)
	_hint.visible = not _learn.needs_choice()


func _show_next_level() -> void:
	var up: Dictionary = _result.level_ups[_next_level]
	_next_level += 1
	_stage = Stage.LEVELS
	_hint.visible = false
	_dim.visible = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.1)
	var before: Dictionary = up.before
	var gains: Dictionary = up.gains
	_panel.show_level(_who.data, _who.display_name(), int(up.level_from), before, gains)


func _on_level_shown() -> void:
	if _stage == Stage.LEVELS:
		_hint.visible = true


func _finish() -> void:
	_stage = Stage.DONE
	_dim.visible = false
	_panel.visible = false
	_learn.visible = false
	_hint.visible = false
	_back.text = "Back to the city"
	_refresh()


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	for c: RunCompanion in _rows:
		(_rows[c] as Control).queue_redraw()
	_scene.queue_redraw()
	_purse.queue_redraw()
	_board.queue_redraw()
	var choosing := _stage == Stage.CHOOSE
	_notices.visible = choosing
	_report.visible = not choosing
	_report.queue_redraw()
	_begin.visible = choosing
	_slip.visible = choosing
	_why.visible = choosing
	_dim.visible = _stage == Stage.LEVELS or _stage == Stage.LEARNED
	_panel.visible = _stage == Stage.LEVELS
	_learn.visible = _stage == Stage.LEARNED
	if _stage == Stage.CHOOSE or _stage == Stage.DONE:
		_hint.visible = false
	if choosing:
		_back.text = "Leave"
	_back.visible = choosing or _stage == Stage.DONE
	for child in _notices.get_children():
		_notices.remove_child(child)
		child.queue_free()
	if not choosing or run == null:
		return
	for i in run.drills.size():
		_notices.add_child(_notice(run.drills[i], i))
	var why := "Nobody to drill." if _who == null or _drill == null else run.drill_block_reason(_drill, _who)
	_begin.disabled = why != ""
	_begin.title = "Set them to it" if _who == null or _drill == null else "%s: %s" % [_who.display_name(), _drill.display_name.to_lower()]
	_begin.detail = "%d gold" % RunConfig.DRILL_COST
	_begin.tooltip_text = why if why != "" else "%s takes the %s. It costs %d gold and is the one thing done today." % [
		_who.display_name(), _drill.display_name.to_lower(), RunConfig.DRILL_COST]
	_why.text = why
	_begin.queue_redraw()


## One notice pinned to the board: what the drill is, and what it would do for whoever is chosen.
func _notice(d: Drill, index: int) -> Control:
	var paper := Control.new()
	paper.position = Vector2(NOTICE_X, NOTICE_Y + index * NOTICE_STEP)
	paper.size = NOTICE
	paper.pivot_offset = NOTICE * 0.5
	paper.rotation = [-0.008, 0.006, -0.004][index % 3]
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := {"hover": false}
	paper.mouse_entered.connect(func() -> void:
		state.hover = true
		paper.queue_redraw())
	paper.mouse_exited.connect(func() -> void:
		state.hover = false
		paper.queue_redraw())
	paper.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			choose_drill(d))
	var amounts := _amounts(d)
	var sparring := d.kind == Drill.Kind.SPARRING
	paper.tooltip_text = ("Sparring gives experience: %d, %d or %d XP as it goes poorly, well or very well." if sparring \
		else "A drill gives %d, %d or %d points toward the next grade as it goes poorly, well or very well.") % amounts \
		+ "\nIt can be taken again on another free day this week."
	paper.draw.connect(func() -> void:
		var chosen := d == _drill
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		var ink := UiTheme.PARCHMENT_INK
		var muted := UiTheme.PARCHMENT_MUTED
		paper.draw_rect(Rect2(5, 7, NOTICE.x, NOTICE.y), Color(0, 0, 0, 0.3))
		UiTheme.draw_parchment(paper, Rect2(Vector2.ZERO, NOTICE), 0.4)
		if chosen:
			paper.draw_rect(Rect2(Vector2.ZERO, NOTICE), Color(UiTheme.WAX, 0.07))
			paper.draw_rect(Rect2(Vector2.ZERO, NOTICE).grow(-3.0), UiTheme.WAX, false, 3.0)
		elif state.hover:
			paper.draw_rect(Rect2(Vector2.ZERO, NOTICE), Color(UiTheme.PARCHMENT_INK, 0.06))
		# The nail.
		paper.draw_circle(Vector2(NOTICE.x * 0.5 + 1.0, 13.0), 6.0, Color(0, 0, 0, 0.35))
		paper.draw_circle(Vector2(NOTICE.x * 0.5, 12.0), 5.0, Color("4a4038"))
		paper.draw_circle(Vector2(NOTICE.x * 0.5 - 1.5, 10.5), 1.8, Color("9a8f80"))
		# The picture.
		var c := Vector2(86.0, NOTICE.y * 0.5)
		paper.draw_arc(c, 52.0, 0.0, TAU, 48, Color(ink, 0.5), 1.5, true)
		paper.draw_arc(c, 46.0, 0.0, TAU, 48, Color(ink, 0.2), 1.0, true)
		draw_drill_icon(paper, c, 62.0, d, UiTheme.WAX.darkened(0.15) if chosen else ink)
		var x := 168.0
		var right := NOTICE.x - 34.0
		UiTheme.draw_text(paper, display, Vector2(x, 22.0), d.display_name, 38, ink)
		# The price, top right.
		var price := "%d" % RunConfig.DRILL_COST
		var pw := display.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		UiTheme.draw_text(paper, display, Vector2(right - pw, 28.0), price, 30, ink)
		UiIcons.coin(paper, Vector2(right - pw - 24.0, 49.0), 26.0, UiTheme.GOLD_DEEP)
		paper.draw_line(Vector2(x, 76.0), Vector2(right, 76.0), Color(ink, 0.4), 1.5, true)
		if _who == null:
			return
		var why := run.drill_block_reason(d, _who)
		var blocked := why != "" and why != _gold_reason()
		if blocked:
			UiTheme.draw_text(paper, italic, Vector2(x, 92.0), why, 19, muted)
			return
		# Where they stand now, and how far a poor, good or great drill would carry them.
		var st: Vector3i
		var head := ""
		if sparring:
			st = _level_standing(_who.progress.level, _who.progress.xp, 0)
			head = "%s  ·  level %d" % [_who.display_name(), st.x]
		else:
			st = _grade_standing(_points(d, _who))
			head = "%s  ·  " % _who.display_name()
		UiTheme.draw_text(paper, display, Vector2(x, 88.0), head, 23, ink)
		if not sparring:
			# Their grade in what the drill trains: its seal and the letter.
			UiIcons.proficiency(paper, Vector2(x + display.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x, 88.0),
				d.weapon_type if d.kind == Drill.Kind.WEAPON else -1, d.school, Proficiency.grade_name(st.x), 22, Color(ink, 0.85), ink)
		var track := Rect2(x, 132.0, right - x, 9.0)
		paper.draw_rect(track, Color(ink, 0.14))
		if st.z > 0:
			var tints: Array[float] = [0.5, 0.32, 0.18]
			for q in [2, 1, 0]:
				var f := clampf(float(st.y + amounts[q]) / st.z, 0.0, 1.0)
				paper.draw_rect(Rect2(track.position, Vector2(track.size.x * f, track.size.y)), Color(UiTheme.WAX, tints[q]))
			paper.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(st.y) / st.z, 0.0, 1.0), track.size.y)), Color(ink, 0.85))
		else:
			paper.draw_rect(track, Color(ink, 0.85))
		paper.draw_rect(track, Color(ink, 0.5), false, 1.0)
		var way := ""
		if st.z == 0:
			way = "as high as it goes"
		elif sparring:
			way = "%d of %d to level %d" % [st.y, st.z, st.x + 1]
		else:
			way = "%d of %d to %s" % [st.y, st.z, Proficiency.grade_name(st.x + 1)]
		UiTheme.draw_text(paper, italic, Vector2(x, 148.0), way, 16, muted)
		UiTheme.draw_text(paper, italic, Vector2(x, 148.0), "+%d, +%d or +%d%s" % [amounts[0], amounts[1], amounts[2], " XP" if sparring else ""],
			16, UiTheme.WAX.darkened(0.1), 0, right - x, HORIZONTAL_ALIGNMENT_RIGHT))
	return paper


## The rules' wording when the purse is short (the notice still shows what the drill would do).
func _gold_reason() -> String:
	return "Needs %d gold." % RunConfig.DRILL_COST


## One of the company in the list on the left, with where they stand in the chosen drill.
func _make_row(c: RunCompanion, h: float) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := {"hover": false}
	row.mouse_entered.connect(func() -> void:
		state.hover = true
		row.queue_redraw())
	row.mouse_exited.connect(func() -> void:
		state.hover = false
		row.queue_redraw())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select(c))
	row.draw.connect(func() -> void:
		var chosen := c == _who
		var why := "" if _drill == null else run.drill_block_reason(_drill, c)
		var dim := why != "" and why != _gold_reason() and not chosen
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var r := minf(30.0, h * 0.5 - 4.0)
		var center := Vector2(r + 10.0, h * 0.5)
		if chosen:
			var clear := Color(UiTheme.GOLD, 0.0)
			row.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(LIST_W, 0), Vector2(LIST_W, h), Vector2(0, h)]),
				PackedColorArray([Color(UiTheme.GOLD, 0.2), clear, clear, Color(UiTheme.GOLD, 0.2)]))
			row.draw_rect(Rect2(0, 0, 3, h), UiTheme.GOLD)
		row.draw_circle(center + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
		row.draw_circle(center, r + 3.0, UiTheme.INK)
		UiIcons.portrait(row, center, r, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color(0.5, 0.49, 0.48) if dim else (Color.WHITE if chosen or state.hover else Color(0.78, 0.76, 0.74)))
		row.draw_arc(center, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if chosen or state.hover else UiTheme.GOLD_DEEP, 2.0, true)
		var x := center.x + r + 16.0
		var ink := UiTheme.MUTED if dim else (ActionButton.LIT_INK if chosen or state.hover else UiTheme.TEXT)
		UiTheme.draw_text(row, display, Vector2(x, h * 0.5 - 26.0), c.display_name(), 24, ink, 4)
		var small := "level %d" % c.progress.level
		if not run.is_fielded(c):
			small += "  ·  bench"
		var small_ink := Color(UiTheme.MUTED, 0.9) if dim else UiTheme.TEXT.lerp(UiTheme.MUTED, 0.25)
		var sx := x
		if _drill != null and _drill.kind != Drill.Kind.SPARRING:
			# Where they stand in what the chosen drill trains: its sign and their grade.
			sx += UiIcons.proficiency(row, Vector2(x, h * 0.5 + 2.0), _drill.weapon_type if _drill.kind == Drill.Kind.WEAPON else -1,
				_drill.school, Proficiency.grade_name(_drill.grade_of(c.progress)), 18, small_ink, ink, 4) + 12.0
		UiTheme.draw_text(row, body, Vector2(sx, h * 0.5 + 4.0), small, 17, small_ink, 4))
	return row


# ---------------------------------------------------------------- drawing

## A small picture of what a drill trains: crossed blades for sparring, the weapon, or a school's sign.
static func draw_drill_icon(ci: CanvasItem, c: Vector2, size: float, d: Drill, color: Color) -> void:
	match d.kind:
		Drill.Kind.SPARRING:
			UiIcons.swords(ci, c, size, color)
		Drill.Kind.MAGIC:
			UiIcons.school(ci, c, size, d.school, color)
		_:
			UiIcons.weapon(ci, c, size, d.weapon_type, color)


## Behind everything: daylight on the palisade and the chosen companion standing in it.
func _draw_scene() -> void:
	var c := _who
	if c == null or c.data.portrait == null:
		return
	var lit := Color("7a6a50")
	for i in 14:
		var f := 1.0 - i / 14.0
		var pts := PackedVector2Array()
		for k in 36:
			pts.append(Vector2(FIGURE_FACE.x, 560.0) + Vector2.from_angle(TAU * k / 36.0) * Vector2(330.0, 470.0) * f)
		_scene.draw_colored_polygon(pts, Color(lit, 0.075))
	var tex := c.data.portrait
	var ts := tex.get_size()
	var h := FIGURE_ART * c.data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var top_left := FIGURE_FACE - c.data.portrait_focus * art
	# Someone short stands on the ground.
	top_left.y = maxf(top_left.y, FLOOR_Y - art.y)
	var shown := clampf((FLOOR_Y - top_left.y) / art.y, 0.0, 1.0)
	_scene.draw_texture_rect_region(tex, Rect2(top_left, Vector2(art.x, art.y * shown)), Rect2(0, 0, ts.x, ts.y * shown))


## The sergeant's board: dark planks in a frame.
func _draw_board() -> void:
	var r := Rect2(Vector2.ZERO, _board.size)
	_board.draw_rect(Rect2(8, 10, r.size.x, r.size.y), Color(0, 0, 0, 0.35))
	_board.draw_rect(r, Color("2c2118"))
	UiTheme.draw_grain(_board, r, 0.06)
	var y := 0.0
	var i := 0
	while y < r.size.y:
		var ph := 96.0 + 22.0 * ((i * 5) % 3)
		_board.draw_rect(Rect2(0, y, r.size.x, ph), Color(1.0, 0.85, 0.65, 0.014 * ((i * 3) % 4)))
		_board.draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0, 0, 0, 0.35), 2.0)
		y += ph
		i += 1
	_board.draw_rect(r, Color("5a4430"), false, 10.0)
	_board.draw_rect(r.grow(-5.0), Color(0, 0, 0, 0.45), false, 1.5)
	_board.draw_rect(r.grow(5.0), Color("1a130d"), false, 2.0)
	if _stage == Stage.CHOOSE:
		UiTheme.draw_text(_board, UiTheme.italic_font(), Vector2(NOTICE_X, FOOT_Y + 96.0),
			"New notices go up at the start of every week.", 17, Color(UiTheme.TEXT, 0.5))


## How it went, written up on the board in place of the notices.
func _draw_report() -> void:
	if _result == null:
		return
	var size_ := REPORT.size
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var ink := UiTheme.PARCHMENT_INK
	var muted := UiTheme.PARCHMENT_MUTED
	_report.draw_rect(Rect2(6, 8, size_.x, size_.y), Color(0, 0, 0, 0.3))
	UiTheme.draw_parchment(_report, Rect2(Vector2.ZERO, size_), 0.45)
	_report.draw_circle(Vector2(size_.x * 0.5 + 1.0, 15.0), 6.0, Color(0, 0, 0, 0.35))
	_report.draw_circle(Vector2(size_.x * 0.5, 14.0), 5.0, Color("4a4038"))
	var pad := 56.0
	var inner := size_.x - pad * 2.0
	var d := _result.drill
	var sparring := d.kind == Drill.Kind.SPARRING
	var q := int(_result.quality)
	UiTheme.draw_text(_report, display, Vector2(pad, 40.0), "%s  ·  %s" % [_who.display_name(), d.display_name], 30, ink)
	_report.draw_line(Vector2(pad, 88.0), Vector2(pad + inner, 88.0), Color(ink, 0.45), 1.0)
	draw_drill_icon(_report, Vector2(pad + inner - 30.0, 60.0), 44.0, d, Color(ink, 0.8))

	# The verdict, stamped.
	var stamp_ink := [muted, ink, UiTheme.WAX][q] as Color
	var font_size := int(round(lerpf(96.0, 64.0, clampf(_stamp, 0.0, 1.0))))
	if _stamp > 0.02:
		UiTheme.draw_text(_report, display, Vector2(pad, 116.0 - (font_size - 64) * 0.5), (BOUT_TITLES if sparring else QUALITY_TITLES)[q], font_size,
			Color(stamp_ink, clampf(_stamp, 0.0, 1.0)), 0, inner, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_rule(_report, Vector2(size_.x * 0.5, 206.0), 420.0, Color(stamp_ink, 0.6 * clampf(_stamp, 0.0, 1.0)))
		UiTheme.draw_text(_report, italic, Vector2(pad, 222.0), QUALITY_LINES[q], 21, Color(muted, clampf(_stamp, 0.0, 1.0)), 0, inner,
			HORIZONTAL_ALIGNMENT_CENTER)

	# Where they stood, with what the drill gave counted in so far.
	var total := _amount()
	var counted := mini(total, int(floor(_shown)))
	var st: Vector3i
	var before: Vector3i
	var big := ""
	var label := ""
	if sparring:
		before = _level_standing(_result.level_before, _xp_before(), 0)
		st = _level_standing(_result.level_before, _xp_before(), counted)
		big = "%d" % st.x
		label = "Level"
	else:
		var p0 := _points(d, _who) - total
		before = _grade_standing(p0)
		st = _grade_standing(p0 + counted)
		big = Proficiency.grade_name(st.x)
		label = d.subject_name().capitalize()
	var rose := st.x > before.x
	var y := 322.0
	UiTheme.draw_text(_report, italic, Vector2(pad, y - 34.0), label, 20, muted)
	UiTheme.draw_text(_report, display, Vector2(pad, y - 14.0), big, 76, UiTheme.WAX if rose else ink)
	var track := Rect2(pad + 150.0, y + 30.0, inner - 150.0, 16.0)
	_report.draw_rect(track, Color(ink, 0.14))
	var frac := 1.0 if st.z == 0 else clampf(float(st.y) / st.z, 0.0, 1.0)
	if not rose and before.z > 0:
		# What was there before, darker; what the drill added, in wax.
		var f0 := clampf(float(before.y) / before.z, 0.0, 1.0)
		_report.draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), UiTheme.WAX)
		_report.draw_rect(Rect2(track.position, Vector2(track.size.x * f0, track.size.y)), Color(ink, 0.85))
	else:
		_report.draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), UiTheme.WAX)
	_report.draw_rect(track, Color(ink, 0.55), false, 1.5)
	var way := ""
	if st.z == 0:
		way = "as high as it goes"
	elif sparring:
		way = "%d of %d to level %d" % [st.y, st.z, st.x + 1]
	else:
		way = "%d of %d to %s" % [st.y, st.z, Proficiency.grade_name(st.x + 1)]
	UiTheme.draw_text(_report, italic, Vector2(track.position.x, track.end.y + 8.0), way, 18, muted)
	UiTheme.draw_text(_report, display, Vector2(track.position.x, y - 22.0), "+%d%s" % [counted, " XP" if sparring else ""], 40,
		UiTheme.WAX.darkened(0.1), 0, track.size.x, HORIZONTAL_ALIGNMENT_RIGHT)

	# What came of it.
	var lines: Array[String] = []
	if rose and counted >= total:
		if sparring:
			lines.append("%s reaches level %d." % [_who.display_name(), st.x])
		else:
			lines.append("%s reaches %s grade %s." % [_who.display_name(), d.subject_name(), Proficiency.grade_name(st.x)])
			for g: Dictionary in _result.grade_ups:
				if g.get("art") != null:
					lines.append("Learned the art %s." % (g.art as CombatArtData).display_name)
				if g.get("spell") != null:
					lines.append("Learned the spell %s." % (g.spell as SpellData).display_name)
	var ly := 444.0
	for line in lines:
		UiTheme.draw_text(_report, display, Vector2(pad, ly), line, 26, UiTheme.WAX.darkened(0.1), 0, inner, HORIZONTAL_ALIGNMENT_CENTER)
		ly += 38.0
	UiTheme.draw_text(_report, italic, Vector2(pad, size_.y - 50.0), "%d gold to the sergeant. The day is spent." % _result.gold_spent, 17,
		muted, 0, inner, HORIZONTAL_ALIGNMENT_CENTER)


## XP into their level before the drill.
func _xp_before() -> int:
	var total := _who.progress.xp - _result.xp_gained
	for l in range(_result.level_before, _who.progress.level):
		total += Levels.xp_to_next(l)
	return maxi(0, total)


func _draw_purse() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var text := "%d" % run.gold
	var tw := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var right := _purse.size.x
	UiTheme.draw_text(_purse, display, Vector2(right - tw, (_purse.size.y - display.get_height(36)) * 0.5), text, 36, UiTheme.GOLD, 6)
	UiIcons.coin(_purse, Vector2(right - tw - 30.0, _purse.size.y * 0.5 + 2.0), 30.0, UiTheme.GOLD)


func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.YARD
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.draw.connect(_draw_scene)
	add_child(_scene)

	var title := UiTheme.label("THE DRILL YARD", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	var hint := UiTheme.label("The sergeant's notices for the week. One of the company can take one today.", 20,
		UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 78)
	add_child(hint)

	_row_box.position = Vector2(LIST_X, LIST_Y)
	_row_box.size = Vector2(LIST_W, 880)
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row_box)

	_board.position = BOARD.position
	_board.size = BOARD.size
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.draw.connect(_draw_board)
	add_child(_board)
	_notices.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_notices)
	_report.position = REPORT.position
	_report.size = REPORT.size
	_report.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.draw.connect(_draw_report)
	_board.add_child(_report)

	# The order, on a slip of its own at the foot of the board.
	_slip.position = Vector2(NOTICE_X, FOOT_Y)
	_slip.size = Vector2(ActionButton.W + 40.0, 74.0)
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.draw.connect(func() -> void:
		_slip.draw_rect(Rect2(4, 6, _slip.size.x, _slip.size.y), Color(0, 0, 0, 0.3))
		UiTheme.draw_parchment(_slip, Rect2(Vector2.ZERO, _slip.size), 0.4))
	_board.add_child(_slip)
	_begin.paper = true
	_begin.h = 50.0
	_begin.position = Vector2(14.0, 12.0)
	_begin.pressed.connect(begin)
	_slip.add_child(_begin)
	_why = UiTheme.label("", 19, UiTheme.INJURED, false, 4)
	_why.add_theme_font_override("font", UiTheme.italic_font())
	_why.position = Vector2(NOTICE_X + ActionButton.W + 64.0, FOOT_Y + 22.0)
	_why.size = Vector2(BOARD.size.x - NOTICE_X * 2.0 - ActionButton.W - 64.0, 60)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board.add_child(_why)

	_purse.position = Vector2(1250, 28)
	_purse.size = Vector2(300, 58)
	_purse.mouse_filter = Control.MOUSE_FILTER_STOP
	_purse.tooltip_text = "The company's gold."
	_purse.draw.connect(_draw_purse)
	add_child(_purse)

	_back.text = "Leave"
	_back.tooltip_text = "Back to the city.\nKey: Esc"
	_back.focus_mode = Control.FOCUS_NONE
	_back.add_theme_font_size_override("font_size", 28)
	_back.position = Vector2(1590, 28)
	_back.size = Vector2(300, 58)
	_back.pressed.connect(close)
	add_child(_back)

	# A level gained from sparring is shown over everything, as after a battle.
	_dim.color = Color(UiTheme.INK, 0.88)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_panel.position = Vector2((1920.0 - LevelUpPanel.SIZE.x) * 0.5, 230.0)
	_panel.visible = false
	_panel.finished.connect(_on_level_shown)
	add_child(_panel)
	_learn.position = _panel.position
	_learn.visible = false
	_learn.finished.connect(_next_beat)
	add_child(_learn)
	_hint = UiTheme.label("Click to go on", 22, UiTheme.MUTED, false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(BOARD.position.x, BOARD.position.y + FOOT_Y + 20.0)
	_hint.size = Vector2(BOARD.size.x, 32)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)


## While the result is being shown, a click anywhere moves it on.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if is_visible_in_tree() and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
			and (_stage == Stage.RESULT or _stage == Stage.LEVELS or (_stage == Stage.LEARNED and not _learn.needs_choice())):
		get_viewport().set_input_as_handled()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _stage == Stage.RESULT or _stage == Stage.LEVELS or _stage == Stage.LEARNED:
				advance()
			else:
				close()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if _stage == Stage.RESULT or _stage == Stage.LEVELS or _stage == Stage.LEARNED:
				get_viewport().set_input_as_handled()
				advance()
