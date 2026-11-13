class_name DayStrip
extends Control
## The days ahead, as a row of small medallions at the top of the city: today, larger, then the next
## days, each with a picture of what it holds (swords, sun, horned skull; a free day that begins with
## an event shows a letter in the sun's place). When the next boss
## lies beyond the days shown, one more medallion after a gap marks it. Hovering one says what the day
## is; a boss day also names every boss still ahead.

const TODAY_R := 27.0
const DAY_R := 20.0
const STEP := 58.0
const H := 74.0
## Space before the extra "next boss" medallion.
const BOSS_GAP := 34.0

const TYPE_COLORS := {
	RunCalendar.DayType.BATTLE: Color("c9503f"),
	RunCalendar.DayType.FREE: Color("e6c878"),
	RunCalendar.DayType.BOSS: Color("e0914a"),
}
## A free day that begins with an event.
const EVENT_COLOR := Color("cdbb96")
const EVENT_WORDS := "A free day, and someone will ask for you"
const EVENT_HINT := "The day begins with a matter to answer at the gate; then the day is yours as usual."
const TYPE_WORDS := {
	RunCalendar.DayType.BATTLE: "A battle",
	RunCalendar.DayType.FREE: "A free day",
	RunCalendar.DayType.BOSS: "A boss",
}
const TYPE_HINTS := {
	RunCalendar.DayType.BATTLE: "The enemy attacks in two or three places. You choose one to defend.",
	RunCalendar.DayType.FREE: "Time for one thing in the city: rest, drill or mend the walls. Buying, hiring and healing take only coin.",
	RunCalendar.DayType.BOSS: "One fight, no choice of where. If it is lost, the city falls.",
}

var _first_day := 1
var _types: Array[int] = []
## Days (by number) whose free day begins with an event.
var _event_days: Array[int] = []
## Boss day -> EnemyGroupData, for every boss day still ahead.
var _bosses: Dictionary = {}
## The next boss day when it lies beyond the days shown, else 0.
var _next_boss := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


static func type_color(t: int) -> Color:
	return TYPE_COLORS.get(t, UiTheme.MUTED)


static func draw_type_icon(ci: CanvasItem, t: int, c: Vector2, size: float, color: Color) -> void:
	match t:
		RunCalendar.DayType.BATTLE:
			UiIcons.swords(ci, c, size, color)
		RunCalendar.DayType.FREE:
			UiIcons.sun(ci, c, size, color)
		_:
			UiIcons.skull(ci, c, size, color)


## `types[0]` is today (day `first_day`). `bosses`: boss day -> boss group, for the days still ahead.
## `event_days`: the free days that begin with an event.
func set_days(first_day: int, types: Array[int], bosses: Dictionary = {}, event_days: Array[int] = []) -> void:
	_first_day = first_day
	_types = types
	_event_days = event_days
	_bosses = bosses
	_next_boss = 0
	var last_shown := first_day + types.size() - 1
	var days := bosses.keys()
	days.sort()
	for d: int in days:
		if d > first_day:
			_next_boss = d if d > last_shown else 0
			break
	var w := TODAY_R * 2.0 + 14.0 + maxi(0, types.size() - 1) * STEP
	if _next_boss > 0:
		w += BOSS_GAP + STEP
	custom_minimum_size = Vector2(w, H)
	size = custom_minimum_size
	queue_redraw()


func _count() -> int:
	return _types.size() + (1 if _next_boss > 0 else 0)


func _center(i: int) -> Vector2:
	if i == 0:
		return Vector2(TODAY_R + 2.0, TODAY_R + 2.0)
	var x := TODAY_R * 2.0 + 14.0 + (i - 0.5) * STEP
	if i >= _types.size():
		x += BOSS_GAP
	return Vector2(x, TODAY_R + 2.0)


func _get_tooltip(at_position: Vector2) -> String:
	for i in _count():
		if _center(i).distance_to(at_position) <= (TODAY_R if i == 0 else DAY_R) + 6.0:
			var d := _first_day + i if i < _types.size() else _next_boss
			var ahead := d - _first_day
			var when := "Today" if ahead == 0 else ("Tomorrow" if ahead == 1 else "In %d days" % ahead)
			var t: int = _types[i] if i < _types.size() else RunCalendar.DayType.BOSS
			var event := t == RunCalendar.DayType.FREE and _event_days.has(d)
			var text := "%s, day %d: %s\n%s" % [when, d, (EVENT_WORDS if event else String(TYPE_WORDS.get(t, ""))).to_lower(),
				EVENT_HINT if event else TYPE_HINTS.get(t, "")]
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
	var font := UiTheme.display_font()
	# A thin chain linking the days.
	if _types.size() > 1:
		draw_line(_center(0) + Vector2(TODAY_R, 0), _center(_types.size() - 1), Color(UiTheme.GOLD_DEEP, 0.6), 2.0)
	for i in _count():
		var extra := i >= _types.size()
		var t: int = _types[i] if not extra else RunCalendar.DayType.BOSS
		var d := _first_day + i if not extra else _next_boss
		var c := _center(i)
		var today := i == 0
		var r := TODAY_R if today else DAY_R
		var event := t == RunCalendar.DayType.FREE and _event_days.has(d)
		var color := EVENT_COLOR if event else type_color(t)
		var boss := t == RunCalendar.DayType.BOSS
		draw_circle(c + Vector2(0, 2), r + 2.0, Color(0, 0, 0, 0.45))
		draw_circle(c, r, UiTheme.PANEL_HI if today else Color(UiTheme.INK, 0.92))
		draw_arc(c, r, 0.0, TAU, 40, UiTheme.GOLD if today else (color if boss else UiTheme.GOLD_DEEP), 3.0 if today else 2.0, true)
		var icon_color := color if today or boss else color.lerp(UiTheme.MUTED, 0.25)
		if event:
			UiIcons.scroll(self, c, r * 1.15, icon_color)
		else:
			draw_type_icon(self, t, c, r * 1.15, icon_color)
		var label := "today" if today else str(d)
		UiTheme.draw_text(self, font, Vector2(c.x - 40.0, c.y + r + 3.0), label, 13, UiTheme.GOLD if today else UiTheme.MUTED, 3, 80.0,
			HORIZONTAL_ALIGNMENT_CENTER)
	if _next_boss > 0:
		# Dots between the days shown and the boss beyond them.
		var a := _center(_types.size() - 1).x + DAY_R
		var b := _center(_types.size()).x - DAY_R
		for k in 3:
			draw_circle(Vector2(a + (b - a) * (0.25 + 0.25 * k), TODAY_R + 2.0), 2.5, Color(UiTheme.GOLD, 0.7))


## "The Faceless Princess" -> "Faceless Princess".
static func short_name(n: String) -> String:
	return n.substr(4) if n.begins_with("The ") else n
