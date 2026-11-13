class_name LevelUpPanel
extends Control
## One level gained, shown the way the old tactics games do it: the companion stands at the left of
## a band of shadow, their stats in two columns beside them, and a light goes down the list one stat
## at a time. Where it stops, the number goes up by one.
## Nothing is rolled here: the gains were decided when the XP was granted (Levels.roll_gains). This
## only reveals them, in stat order, so the commander watches each one come up.

signal finished

const SIZE := Vector2(1400, 620)
const NAMES := {Stat.HP: "Health", Stat.STA: "Stamina", Stat.STR: "Strength", Stat.MAG: "Magic", Stat.CRT: "Critical",
	Stat.DEX: "Dexterity", Stat.SPD: "Speed", Stat.DEF: "Defence", Stat.RES: "Resistance", Stat.LCK: "Luck"}
## Seconds before the light starts down the list, how long it rests on each stat, and how long it
## stays on one that rose.
const INTRO := 0.35
const CONSIDER := 0.08
const HOLD := 0.2
const LEVEL_AT := 0.15
const ROWS := 5
const GRID := Vector2(700, 250)
const COL_W := 350.0
const ROW_H := 66.0
## Height the figure is drawn at for a figure_scale of 1, and where their face sits.
const ART := 800.0
const FACE := Vector2(270, 176)
const BAND := Color("120d16")

var _data: CompanionData
var _name := ""
var _level_from := 1
var _before: Dictionary = {}
var _gains: Dictionary = {}
var _keys: Array[String] = []
var _starts: Array[float] = []
var _end := 0.0
var _t := 0.0
var _done := true


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Starts the reveal of one level: `stats_before` are the stats at `level_from`, `gains` what the
## next level adds (stat key -> amount).
func show_level(data: CompanionData, display_name: String, level_from: int, stats_before: Dictionary, gains: Dictionary) -> void:
	_data = data
	_name = display_name
	_level_from = level_from
	_before = stats_before
	_gains = gains
	_keys = Levels.GROWTH_STATS.duplicate()
	_starts.clear()
	var t := INTRO
	for key in _keys:
		_starts.append(t)
		t += CONSIDER
		if int(gains.get(key, 0)) > 0:
			t += HOLD
	_end = t + 0.1
	_t = 0.0
	_done = false
	set_process(true)
	queue_redraw()


func is_done() -> bool:
	return _done


## Shows every gain at once.
func skip() -> void:
	if _done:
		return
	_t = _end
	_finish()


func _process(delta: float) -> void:
	if _done:
		set_process(false)
		return
	_t += delta
	if _t >= _end:
		_finish()
	queue_redraw()


func _finish() -> void:
	_done = true
	set_process(false)
	queue_redraw()
	finished.emit()


func _draw() -> void:
	if _data == null:
		return
	# A band of shadow right across the screen, soft above and below.
	var x0 := -2400.0
	var x1 := SIZE.x + 2400.0
	var dark := Color(BAND, 0.95)
	var clear := Color(BAND, 0.0)
	var soft := 70.0
	draw_polygon(PackedVector2Array([Vector2(x0, -soft), Vector2(x1, -soft), Vector2(x1, 0), Vector2(x0, 0)]),
		PackedColorArray([clear, clear, dark, dark]))
	draw_rect(Rect2(x0, 0, x1 - x0, SIZE.y), dark)
	draw_polygon(PackedVector2Array([Vector2(x0, SIZE.y), Vector2(x1, SIZE.y), Vector2(x1, SIZE.y + soft), Vector2(x0, SIZE.y + soft)]),
		PackedColorArray([dark, dark, clear, clear]))
	UiTheme.draw_rule(self, Vector2(SIZE.x * 0.5, 0.0), SIZE.x + 300.0, Color(UiTheme.GOLD, 0.55))
	UiTheme.draw_rule(self, Vector2(SIZE.x * 0.5, SIZE.y), SIZE.x + 300.0, Color(UiTheme.GOLD, 0.55))

	_draw_figure()

	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	UiTheme.draw_text(self, display, Vector2(GRID.x, 34.0), "LEVEL UP", 24, UiTheme.GOLD, 4)
	UiTheme.draw_text(self, display, Vector2(GRID.x - 3.0, 62.0), _name.to_upper(), 76, UiTheme.TEXT, 8)
	# The level: the old number, then the new one in gold.
	var risen := _t >= LEVEL_AT
	var pop := _pop(_t - LEVEL_AT)
	UiTheme.draw_text(self, italic, Vector2(GRID.x + 2.0, 170.0), "Level", 30, UiTheme.MUTED, 4)
	var level_size := int(round(44.0 * (1.0 + 0.5 * pop))) if risen else 44
	UiTheme.draw_text(self, display, Vector2(GRID.x + 88.0, 182.0 - display.get_height(level_size) * 0.5 + 6.0),
		str(_level_from + (1 if risen else 0)), level_size, UiTheme.GOLD if risen else UiTheme.TEXT, 6)

	for i in _keys.size():
		_draw_stat(i)


## The cut-out, standing at the left with their feet below the band.
func _draw_figure() -> void:
	var tex := _data.portrait
	if tex == null:
		return
	# Lamplight behind them.
	for i in 18:
		var f := 1.0 - i / 18.0
		var pts := PackedVector2Array()
		for k in 32:
			pts.append(Vector2(FACE.x, SIZE.y * 0.55) + Vector2.from_angle(TAU * k / 32.0) * Vector2(330.0, 300.0) * f)
		draw_colored_polygon(pts, Color(UiTheme.GOLD, 0.011))
	var ts := tex.get_size()
	var h := ART * _data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var top_left := FACE - _data.portrait_focus * art
	var shown := clampf((SIZE.y - top_left.y) / art.y, 0.0, 1.0)
	draw_texture_rect_region(tex, Rect2(top_left, Vector2(art.x, art.y * shown)), Rect2(0, 0, ts.x, ts.y * shown))
	# An arm or a blade that reaches across goes into shadow before it gets to the stats.
	var dark := Color(BAND, 0.92)
	var clear := Color(BAND, 0.0)
	var x0 := GRID.x - 190.0
	var x1 := GRID.x - 30.0
	draw_polygon(PackedVector2Array([Vector2(x0, 1), Vector2(x1, 1), Vector2(x1, SIZE.y - 1.0), Vector2(x0, SIZE.y - 1.0)]),
		PackedColorArray([clear, dark, dark, clear]))
	draw_rect(Rect2(x1, 1, top_left.x + art.x - x1, SIZE.y - 2.0), dark)


func _draw_stat(i: int) -> void:
	var key := _keys[i]
	var pos := GRID + Vector2(floorf(float(i) / ROWS) * COL_W, (i % ROWS) * ROW_H)
	var gain := int(_gains.get(key, 0))
	var reveal := _starts[i] + CONSIDER
	var considering := not _done and _t >= _starts[i] and _t < reveal
	var revealed := _t >= reveal
	var rose := revealed and gain > 0
	var age := _t - reveal
	var display := UiTheme.display_font()
	var row := Rect2(pos.x - 16.0, pos.y, COL_W - 24.0, ROW_H - 6.0)

	if considering or rose:
		# The light: full while it rests on the stat, and it stays on one that rose.
		var a := 0.16
		if considering:
			a = 0.3
		elif age < 0.45:
			a = lerpf(0.5, 0.16, age / 0.45)
		var clear := Color(UiTheme.GOLD, 0.0)
		draw_polygon(PackedVector2Array([row.position, Vector2(row.end.x, row.position.y), row.end, Vector2(row.position.x, row.end.y)]),
			PackedColorArray([Color(UiTheme.GOLD, a), clear, clear, Color(UiTheme.GOLD, a)]))
		draw_rect(Rect2(row.position.x, row.position.y, 3.0, row.size.y), Color(UiTheme.GOLD, 0.9 if considering else 0.6))
	draw_line(Vector2(row.position.x, row.end.y + 2.0), Vector2(row.end.x, row.end.y + 2.0), Color(UiTheme.GOLD, 0.14), 1.0)

	var name_ink := UiTheme.MUTED
	var value_ink := UiTheme.TEXT.lerp(UiTheme.MUTED, 0.35)
	if considering:
		name_ink = ActionButton.LIT_INK
		value_ink = ActionButton.LIT_INK
	elif rose:
		name_ink = UiTheme.TEXT
		value_ink = UiTheme.GOLD
	elif revealed:
		name_ink = Color(UiTheme.MUTED, 0.75)
		value_ink = UiTheme.TEXT.lerp(UiTheme.MUTED, 0.6)
	var mid := pos.y + (ROW_H - 6.0) * 0.5
	UiTheme.draw_text(self, display, Vector2(pos.x, mid - display.get_height(28) * 0.5), NAMES[key], 28, name_ink, 4)
	var value := int(_before.get(key, 0)) + (gain if revealed else 0)
	var value_size := int(round(38.0 * (1.0 + 0.35 * _pop(age)))) if rose else 38
	UiTheme.draw_text(self, display, Vector2(pos.x + 120.0, mid - display.get_height(value_size) * 0.5), str(value), value_size, value_ink, 5,
		120.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if rose:
		var plus_size := int(round(28.0 * (1.0 + 0.8 * _pop(age))))
		UiTheme.draw_text(self, display, Vector2(pos.x + 252.0, mid - display.get_height(plus_size) * 0.5), "+%d" % gain, plus_size,
			ActionButton.LIT_INK.lerp(UiTheme.GOLD, clampf(age / 0.4, 0.0, 1.0)), 5)
	elif considering:
		# Not known yet: a diamond turning over where the gain would be written.
		var c := Vector2(pos.x + 268.0, mid)
		var w := 7.0 * absf(cos(_t * 40.0)) + 1.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w, 0), c + Vector2(0, -8), c + Vector2(w, 0), c + Vector2(0, 8)]),
			Color(UiTheme.GOLD, 0.9))


## 1 at the moment something appears, easing to 0 over a quarter of a second.
static func _pop(age: float) -> float:
	if age < 0.0 or age >= 0.25:
		return 0.0
	var f := 1.0 - age / 0.25
	return f * f
