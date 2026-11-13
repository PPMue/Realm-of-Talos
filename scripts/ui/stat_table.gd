class_name StatTable
extends RefCounted
## A companion's stats written on parchment as a small table, in one of two views that a StatToggle
## in the table's one free cell switches between:
##   values: the name in grey and the number in ink (Health as "18 / 27").
##   growth: the name, the stat's growth rate (its chance to rise by 1 on a level-up) as a figure, and
##           under them a line as long as the rate. Strong growths are drawn dark and weak ones faint.
##           Build never grows and shows a dash.
## The names stand in the same place in both views. The view is shared by every table (the barracks
## page and the hires' papers at the tavern), so what was chosen in one place holds in the other.

const NAMES := {Stat.HP: "Health", Stat.STA: "Stamina", Stat.STR: "Strength", Stat.MAG: "Magic", Stat.DEX: "Dexterity",
	Stat.SPD: "Speed", Stat.DEF: "Defence", Stat.RES: "Resistance", Stat.CRT: "Critical", Stat.LCK: "Luck", Stat.BLD: "Build"}
const KEYS: Array[String] = [Stat.HP, Stat.STA, Stat.STR, Stat.MAG, Stat.DEX, Stat.SPD, Stat.DEF, Stat.RES, Stat.CRT, Stat.LCK, Stat.BLD]
const ROW := 36.0
## Room left between two columns.
const GUTTER := 22.0

## Which view every table shows: false for the values, true for the growth rates.
static var show_growth := false


## Height of the table with `cols` columns.
static func height(cols: int) -> float:
	return ceilf(float(KEYS.size() + 1) / cols) * ROW


## The table's one free cell (the last), where the StatToggle goes; relative to `origin`.
static func free_cell(origin: Vector2, width: float, cols: int) -> Rect2:
	var cw := width / cols
	var n := KEYS.size()
	return Rect2(origin + Vector2((n % cols) * cw, floorf(float(n) / cols) * ROW), Vector2(cw - GUTTER, ROW))


## Draws the table at `origin`, `width` wide, in the view chosen. `values` is stat key -> number
## (Build included); `hp_text` replaces the Health number (e.g. "18 / 27").
static func draw(ci: CanvasItem, origin: Vector2, width: float, cols: int, values: Dictionary, data: CompanionData, hp_text: String = "") -> void:
	var cw := width / cols
	var span := cw - GUTTER
	var body := UiTheme.body_font()
	var display := UiTheme.display_font()
	for i in KEYS.size():
		var key := KEYS[i]
		var x := origin.x + (i % cols) * cw
		var y := origin.y + floorf(float(i) / cols) * ROW
		UiTheme.draw_text(ci, body, Vector2(x, y + 3.0), NAMES[key], 16, UiTheme.PARCHMENT_MUTED)
		if not show_growth:
			var value := hp_text if key == Stat.HP and hp_text != "" else str(int(values.get(key, 0)))
			UiTheme.draw_text(ci, display, Vector2(x, y), value, 21, UiTheme.PARCHMENT_INK, 0, span, HORIZONTAL_ALIGNMENT_RIGHT)
			continue
		if key == Stat.BLD:
			UiTheme.draw_text(ci, display, Vector2(x, y), "–", 21, Color(UiTheme.PARCHMENT_MUTED, 0.7), 0, span, HORIZONTAL_ALIGNMENT_RIGHT)
			continue
		var rate := Levels.growth_rate(data, key)
		var strength := 0.9 if rate >= 50 else (0.62 if rate >= 30 else 0.38)
		UiTheme.draw_text(ci, display, Vector2(x, y + 1.0), "%d%%" % rate, 19, Color(UiTheme.PARCHMENT_INK, minf(1.0, strength + 0.25)), 0, span,
			HORIZONTAL_ALIGNMENT_RIGHT)
		var track := Rect2(x, y + 27.0, span, 4.0)
		ci.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		ci.draw_rect(Rect2(track.position, Vector2(track.size.x * rate / 100.0, track.size.y)), Color(UiTheme.PARCHMENT_INK, strength))
