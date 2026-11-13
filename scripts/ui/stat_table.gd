class_name StatTable
extends RefCounted
## A companion's stats written on parchment as a small table: the name in grey, the number in ink,
## and under each a line as long as the stat's growth rate (its chance to rise by 1 on a level-up)
## with the figure beside it. Strong growths are drawn dark and weak ones faint. Build never grows
## and has no line. The table's one free cell says what the lines are.
## Used on the barracks page and on a hire's paper at the tavern.

const NAMES := {Stat.HP: "Health", Stat.STA: "Stamina", Stat.STR: "Strength", Stat.MAG: "Magic", Stat.DEX: "Dexterity",
	Stat.SPD: "Speed", Stat.DEF: "Defence", Stat.RES: "Resistance", Stat.CRT: "Critical", Stat.LCK: "Luck", Stat.BLD: "Build"}
const KEYS: Array[String] = [Stat.HP, Stat.STA, Stat.STR, Stat.MAG, Stat.DEX, Stat.SPD, Stat.DEF, Stat.RES, Stat.CRT, Stat.LCK, Stat.BLD]
const ROW := 41.0


## Height of the table with `cols` columns.
static func height(cols: int) -> float:
	return ceilf(float(KEYS.size() + 1) / cols) * ROW


## Draws the table at `origin`, `width` wide. `values` is stat key -> number (Build included);
## `hp_text` replaces the Health number (e.g. "18 / 27").
static func draw(ci: CanvasItem, origin: Vector2, width: float, cols: int, values: Dictionary, data: CompanionData, hp_text: String = "") -> void:
	var cw := width / cols
	var span := cw - 22.0
	var body := UiTheme.body_font()
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	for i in KEYS.size():
		var key := KEYS[i]
		var x := origin.x + (i % cols) * cw
		var y := origin.y + floorf(float(i) / cols) * ROW
		var value := hp_text if key == Stat.HP and hp_text != "" else str(int(values.get(key, 0)))
		UiTheme.draw_text(ci, body, Vector2(x, y + 2.0), NAMES[key], 16, UiTheme.PARCHMENT_MUTED)
		UiTheme.draw_text(ci, display, Vector2(x, y), value, 19, UiTheme.PARCHMENT_INK, 0, span, HORIZONTAL_ALIGNMENT_RIGHT)
		if key == Stat.BLD:
			continue
		var rate := Levels.growth_rate(data, key)
		var strength := 0.9 if rate >= 50 else (0.62 if rate >= 30 else 0.38)
		var ink := Color(UiTheme.PARCHMENT_INK, strength)
		var track := Rect2(x, y + 28.0, span - 46.0, 5.0)
		ci.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		ci.draw_rect(Rect2(track.position, Vector2(track.size.x * rate / 100.0, track.size.y)), ink)
		UiTheme.draw_text(ci, body, Vector2(x, y + 20.0), "%d%%" % rate, 15, Color(UiTheme.PARCHMENT_INK, minf(1.0, strength + 0.2)), 0, span,
			HORIZONTAL_ALIGNMENT_RIGHT)
	# The last cell of the table is free: say what the lines are.
	var n := KEYS.size()
	var lx := origin.x + (n % cols) * cw
	var ly := origin.y + floorf(float(n) / cols) * ROW + 2.0
	ci.draw_multiline_string(italic, Vector2(lx, ly + italic.get_ascent(13)), "Under each stat: its chance to rise with a level.",
		HORIZONTAL_ALIGNMENT_LEFT, span, 13, 3, Color(UiTheme.PARCHMENT_MUTED, 0.95))
