class_name StatTable
extends RefCounted
## A companion's stats written on parchment as a small table. Each cell: the name in grey at the top
## left, the number large at the right (it is the one thing to read), and under the name, well away
## from the number, a short line as long as the stat's growth rate (its chance to rise by 1 on a
## level-up) with the figure after it in small italics. Strong growths are drawn dark and weak ones
## faint. Build never grows and has no line. The table's one free cell says what the lines are.
## Used on the barracks page and on a hire's paper at the tavern.

const NAMES := {Stat.HP: "Health", Stat.STA: "Stamina", Stat.STR: "Strength", Stat.MAG: "Magic", Stat.DEX: "Dexterity",
	Stat.SPD: "Speed", Stat.DEF: "Defence", Stat.RES: "Resistance", Stat.CRT: "Critical", Stat.LCK: "Luck", Stat.BLD: "Build"}
const KEYS: Array[String] = [Stat.HP, Stat.STA, Stat.STR, Stat.MAG, Stat.DEX, Stat.SPD, Stat.DEF, Stat.RES, Stat.CRT, Stat.LCK, Stat.BLD]
const ROW := 41.0
const VALUE_SIZE := 27
const OF_SIZE := 15
const RATE_SIZE := 14


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
	# What is written in each cell: the number, and for Health "of how many" after it in small.
	var numbers: Array[String] = []
	var of := ""
	for key in KEYS:
		var text := str(int(values.get(key, 0)))
		if key == Stat.HP and hp_text.contains("/"):
			text = hp_text.get_slice("/", 0).strip_edges()
			of = "/ " + hp_text.get_slice("/", 1).strip_edges()
		numbers.append(text)
	var of_w := body.get_string_size(of, HORIZONTAL_ALIGNMENT_LEFT, -1, OF_SIZE).x + 5.0 if of != "" else 0.0
	# The widest number sets the room every cell keeps for it, so the growth lines are all one length.
	var room := 0.0
	for i in KEYS.size():
		var w := display.get_string_size(numbers[i], HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_SIZE).x
		room = maxf(room, w + (of_w if KEYS[i] == Stat.HP else 0.0))
	var rate_w := italic.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, RATE_SIZE).x
	var line_w := maxf(20.0, span - room - 14.0 - rate_w - 6.0)
	for i in KEYS.size():
		var key := KEYS[i]
		var x := origin.x + (i % cols) * cw
		var y := origin.y + floorf(float(i) / cols) * ROW
		UiTheme.draw_text(ci, body, Vector2(x, y + 2.0), NAMES[key], 16, UiTheme.PARCHMENT_MUTED)
		var right := x + span
		if key == Stat.HP and of != "":
			UiTheme.draw_text(ci, body, Vector2(right - of_w + 5.0, y + 3.0 + display.get_ascent(VALUE_SIZE) - body.get_ascent(OF_SIZE)), of,
				OF_SIZE, UiTheme.PARCHMENT_MUTED)
			right -= of_w
		UiTheme.draw_text(ci, display, Vector2(x, y + 3.0), numbers[i], VALUE_SIZE, UiTheme.PARCHMENT_INK, 0, right - x, HORIZONTAL_ALIGNMENT_RIGHT)
		if key == Stat.BLD:
			continue
		var rate := Levels.growth_rate(data, key)
		var strength := 0.9 if rate >= 50 else (0.62 if rate >= 30 else 0.38)
		var track := Rect2(x, y + 29.0, line_w, 4.0)
		ci.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		ci.draw_rect(Rect2(track.position, Vector2(track.size.x * rate / 100.0, track.size.y)), Color(UiTheme.PARCHMENT_INK, strength))
		UiTheme.draw_text(ci, italic, Vector2(track.end.x + 6.0, y + 21.0), "%d%%" % rate, RATE_SIZE,
			Color(UiTheme.PARCHMENT_INK, 0.45 + strength * 0.4))
	# The last cell of the table is free: say what the lines are.
	var n := KEYS.size()
	var lx := origin.x + (n % cols) * cw
	var ly := origin.y + floorf(float(n) / cols) * ROW + 2.0
	ci.draw_multiline_string(italic, Vector2(lx, ly + italic.get_ascent(13)), "The lines: the chance to rise with a level.",
		HORIZONTAL_ALIGNMENT_LEFT, span, 13, 3, Color(UiTheme.PARCHMENT_MUTED, 0.95))
