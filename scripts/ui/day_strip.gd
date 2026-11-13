class_name DayStrip
extends Control
## The calendar strip on the city screen: today, larger, then the next days by type. Boss days name the
## boss drawn for them. When the next boss day lies beyond the days shown, one more tile after a gap
## names it, so the coming boss is always in view; its tooltip lists every boss still ahead.

const TODAY_W := 250.0
const DAY_W := 170.0
const H := 96.0
const GAP := 10.0
## Space before the extra "next boss" tile.
const BOSS_GAP := 40.0

const TYPE_COLORS := {
	RunCalendar.DayType.BATTLE: Color("f0564a"),
	RunCalendar.DayType.FREE: Color("86e27a"),
	RunCalendar.DayType.EVENT: Color("b678f0"),
	RunCalendar.DayType.BOSS: Color("f4c552"),
}
const TYPE_HINTS := {
	RunCalendar.DayType.BATTLE: "Battle: choose one of 2 or 3 fronts to defend.",
	RunCalendar.DayType.FREE: "Free day: %d actions among rest, shop, tavern and repair." % RunConfig.FREE_DAY_ACTIONS,
	RunCalendar.DayType.EVENT: "Event: something happens in the city, and you choose how to answer.",
	RunCalendar.DayType.BOSS: "Boss: one front, no choice. Losing it ends the run.",
}

var _first_day := 1
var _types: Array[int] = []
## Boss day -> EnemyGroupData, for every boss day still ahead.
var _bosses: Dictionary = {}
## The next boss day when it lies beyond the days shown, else 0.
var _next_boss := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


static func type_color(t: int) -> Color:
	return TYPE_COLORS.get(t, UiTheme.MUTED)


## `types[0]` is today (day `first_day`). `bosses`: boss day -> boss group, for the days still ahead.
func set_days(first_day: int, types: Array[int], bosses: Dictionary = {}) -> void:
	_first_day = first_day
	_types = types
	_bosses = bosses
	_next_boss = 0
	var last_shown := first_day + types.size() - 1
	var days := bosses.keys()
	days.sort()
	for d: int in days:
		if d > first_day:
			_next_boss = d if d > last_shown else 0
			break
	var count := types.size()
	var w := TODAY_W + maxi(0, count - 1) * (DAY_W + GAP)
	if _next_boss > 0:
		w += BOSS_GAP + DAY_W
	custom_minimum_size = Vector2(w, H)
	size = custom_minimum_size
	queue_redraw()


func _tile_rect(i: int) -> Rect2:
	if i == 0:
		return Rect2(0, 0, TODAY_W, H)
	if i >= _types.size():
		return Rect2(TODAY_W + GAP + (_types.size() - 1) * (DAY_W + GAP) - GAP + BOSS_GAP, 12.0, DAY_W, H - 12.0)
	return Rect2(TODAY_W + GAP + (i - 1) * (DAY_W + GAP), 12.0, DAY_W, H - 12.0)


func _get_tooltip(at_position: Vector2) -> String:
	for i in _types.size() + (1 if _next_boss > 0 else 0):
		if _tile_rect(i).has_point(at_position):
			var d := _first_day + i if i < _types.size() else _next_boss
			var ahead := d - _first_day
			var when := "Today" if ahead == 0 else ("Tomorrow" if ahead == 1 else "In %d days" % ahead)
			var t: int = _types[i] if i < _types.size() else RunCalendar.DayType.BOSS
			var text := "Day %d (%s)\n%s" % [d, when, TYPE_HINTS.get(t, "")]
			if t == RunCalendar.DayType.BOSS:
				text += "\n\n" + bosses_ahead_text(d)
			return text
	return ""


## Every boss still ahead from day `from`, one per paragraph.
func bosses_ahead_text(from: int = 0) -> String:
	var lines: Array[String] = []
	var days := _bosses.keys()
	days.sort()
	for d: int in days:
		if d < maxi(from, _first_day) and from > 0:
			continue
		var g: EnemyGroupData = _bosses[d]
		var escorts: Array[String] = []
		for e in g.escorts():
			escorts.append(e.display_name)
		lines.append("Day %d: %s%s\n%s" % [d, g.display_name, "  (with %s)" % ", ".join(escorts) if not escorts.is_empty() else "",
			g.description])
	return "\n\n".join(lines)


func _draw() -> void:
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	for i in _types.size() + (1 if _next_boss > 0 else 0):
		var extra := i >= _types.size()
		var r := _tile_rect(i)
		var t: int = _types[i] if not extra else RunCalendar.DayType.BOSS
		var d := _first_day + i if not extra else _next_boss
		var color := type_color(t)
		var today := i == 0
		UiTheme.fill_para(self, r, Color(UiTheme.PANEL_HI, 0.97) if today else Color(UiTheme.PANEL, 0.9))
		# Coloured stripe along the bottom.
		var stripe_h := 10.0 if today else 7.0
		var s := UiTheme.slant_for(r.size.y)
		var y0 := r.end.y - stripe_h
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x + UiTheme.SLANT * stripe_h, y0), Vector2(r.end.x - s + UiTheme.SLANT * stripe_h, y0),
			Vector2(r.end.x - s, r.end.y), Vector2(r.position.x, r.end.y)]), color)
		UiTheme.stroke_para(self, r, UiTheme.GOLD if today else (color if t == RunCalendar.DayType.BOSS else UiTheme.EDGE),
			4.0 if today else 2.0)
		var x := r.position.x + s * 0.55 + 12.0
		var boss: EnemyGroupData = _bosses.get(d)
		if today:
			UiTheme.draw_text(self, display, Vector2(x, r.position.y + 8.0), "TODAY  ·  DAY %d" % d, 20, UiTheme.GOLD)
			UiTheme.draw_text(self, display, Vector2(x - 6.0, r.position.y + 32.0), RunCalendar.type_name(t), 44, color, 8)
		elif t == RunCalendar.DayType.BOSS and boss != null:
			var head := "IN %d DAYS  ·  BOSS" % (d - _first_day) if extra else "DAY %d  ·  BOSS" % d
			UiTheme.draw_text(self, body, Vector2(x, r.position.y + 6.0), head, 15, color.lerp(UiTheme.TEXT, 0.3))
			_draw_name(display, short_name(boss.display_name).to_upper(), Rect2(x - 4.0, r.position.y + 26.0,
				r.size.x - s - 22.0, r.size.y - 36.0), color)
		else:
			UiTheme.draw_text(self, body, Vector2(x, r.position.y + 6.0), "DAY %d" % d, 16, UiTheme.MUTED)
			UiTheme.draw_text(self, display, Vector2(x - 4.0, r.position.y + 28.0), RunCalendar.type_name(t), 32,
				color.lerp(UiTheme.TEXT, 0.15), 6)
	if _next_boss > 0:
		# Dots between the days shown and the boss beyond them.
		var a := _tile_rect(_types.size() - 1).end.x
		var b := _tile_rect(_types.size()).position.x
		for k in 3:
			draw_circle(Vector2(a + (b - a) * (0.3 + 0.2 * k), 12.0 + (H - 12.0) * 0.5), 3.0, Color(UiTheme.GOLD, 0.7))


## "The Faceless Princess" -> "Faceless Princess": the tile has little room.
static func short_name(n: String) -> String:
	return n.substr(4) if n.begins_with("The ") else n


## A boss name in up to two lines, at the largest size that fits `box`.
func _draw_name(font: Font, text: String, box: Rect2, color: Color) -> void:
	var font_size := 28
	var lines: Array[String] = [text]
	while font_size > 14:
		lines = _wrap(font, text, font_size, box.size.x)
		var h := lines.size() * font.get_height(font_size)
		if lines.size() <= 2 and h <= box.size.y:
			var fits := true
			for l in lines:
				fits = fits and font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= box.size.x
			if fits:
				break
		font_size -= 1
	var line_h := font.get_height(font_size)
	var y := box.position.y + (box.size.y - line_h * lines.size()) * 0.5
	for l in lines:
		UiTheme.draw_text(self, font, Vector2(box.position.x, y), l, font_size, color, 5)
		y += line_h


static func _wrap(font: Font, text: String, font_size: int, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var attempt := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			out.append(line)
			line = word
		else:
			line = attempt
	out.append(line)
	return out
