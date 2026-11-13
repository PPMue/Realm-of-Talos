class_name DayStrip
extends Control
## The calendar strip on the city screen: today, larger, then the next days by type.

const TODAY_W := 250.0
const DAY_W := 170.0
const H := 96.0
const GAP := 10.0

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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


static func type_color(t: int) -> Color:
	return TYPE_COLORS.get(t, UiTheme.MUTED)


## `types[0]` is today (day `first_day`).
func set_days(first_day: int, types: Array[int]) -> void:
	_first_day = first_day
	_types = types
	var count := types.size()
	custom_minimum_size = Vector2(TODAY_W + maxi(0, count - 1) * (DAY_W + GAP), H)
	size = custom_minimum_size
	queue_redraw()


func _tile_rect(i: int) -> Rect2:
	if i == 0:
		return Rect2(0, 0, TODAY_W, H)
	return Rect2(TODAY_W + GAP + (i - 1) * (DAY_W + GAP), 12.0, DAY_W, H - 12.0)


func _get_tooltip(at_position: Vector2) -> String:
	for i in _types.size():
		if _tile_rect(i).has_point(at_position):
			var d := _first_day + i
			var when := "Today" if i == 0 else ("Tomorrow" if i == 1 else "In %d days" % i)
			return "Day %d (%s)\n%s" % [d, when, TYPE_HINTS.get(_types[i], "")]
	return ""


func _draw() -> void:
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	for i in _types.size():
		var r := _tile_rect(i)
		var t := _types[i]
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
		if today:
			UiTheme.draw_text(self, display, Vector2(x, r.position.y + 8.0), "TODAY  ·  DAY %d" % (_first_day + i), 20, UiTheme.GOLD)
			UiTheme.draw_text(self, display, Vector2(x - 6.0, r.position.y + 32.0), RunCalendar.type_name(t), 44, color, 8)
		else:
			UiTheme.draw_text(self, body, Vector2(x, r.position.y + 6.0), "DAY %d" % (_first_day + i), 16, UiTheme.MUTED)
			UiTheme.draw_text(self, display, Vector2(x - 4.0, r.position.y + 28.0), RunCalendar.type_name(t), 32,
				color.lerp(UiTheme.TEXT, 0.15), 6)
