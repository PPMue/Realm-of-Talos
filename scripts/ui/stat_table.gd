class_name StatTable
extends RefCounted
## A companion's stats written on parchment as two small tables that stand side by side or one over
## the other, each under its own heading, so the numbers and the growth rates are never read as one:
##   values: the name in grey and the number in ink (Health as "18 / 27").
##   growth: the name, the stat's growth rate (its chance to rise by 1 on a level-up) as a figure, and
##           under them a line as long as the rate. Strong growths are drawn dark and weak ones faint.
##           Build never grows and is left out.
## Used on the barracks sheet and on a hire's paper at the tavern.

const NAMES := {Stat.HP: "Health", Stat.STA: "Stamina", Stat.STR: "Strength", Stat.MAG: "Magic", Stat.DEX: "Dexterity",
	Stat.SPD: "Speed", Stat.DEF: "Defence", Stat.RES: "Resistance", Stat.CRT: "Critical", Stat.LCK: "Luck", Stat.BLD: "Build"}
const KEYS: Array[String] = [Stat.HP, Stat.STA, Stat.STR, Stat.MAG, Stat.DEX, Stat.SPD, Stat.DEF, Stat.RES, Stat.CRT, Stat.LCK, Stat.BLD]
const VALUE_ROW := 30.0
const GROWTH_ROW := 36.0
## Height of a heading (see head).
const HEAD_H := 30.0
## Room left between two columns.
const GUTTER := 22.0


static func values_height(cols: int, row: float = VALUE_ROW) -> float:
	return ceilf(float(KEYS.size()) / cols) * row


static func growth_height(cols: int, row: float = GROWTH_ROW) -> float:
	return ceilf(float(KEYS.size() - 1) / cols) * row


## A heading on parchment: small capitals, a word or two at the right in italics, and a line under
## them. HEAD_H tall.
static func head(ci: CanvasItem, origin: Vector2, width: float, text: String, aside: String = "") -> void:
	UiTheme.draw_text(ci, UiTheme.display_font(), origin, text, 17, UiTheme.PARCHMENT_MUTED)
	if aside != "":
		UiTheme.draw_text(ci, UiTheme.italic_font(), origin + Vector2(0, 3.0), aside, 14, Color(UiTheme.PARCHMENT_MUTED, 0.95), 0, width,
			HORIZONTAL_ALIGNMENT_RIGHT)
	ci.draw_line(origin + Vector2(0, HEAD_H - 6.0), origin + Vector2(width, HEAD_H - 6.0), Color(UiTheme.PARCHMENT_INK, 0.45), 1.0)


## The numbers, at `origin`, `width` wide. `values` is stat key -> number (Build included);
## `hp_text` replaces the Health number (e.g. "18 / 27"). `bonus` is stat key -> how much of the
## number comes from traits and the like: written small before the number ("+2").
static func draw_values(ci: CanvasItem, origin: Vector2, width: float, cols: int, values: Dictionary, hp_text: String = "",
		row: float = VALUE_ROW, bonus: Dictionary = {}) -> void:
	var cw := (width + GUTTER) / cols
	var span := cw - GUTTER
	var body := UiTheme.body_font()
	var display := UiTheme.display_font()
	for i in KEYS.size():
		var key := KEYS[i]
		var x := origin.x + (i % cols) * cw
		var y := origin.y + floorf(float(i) / cols) * row
		var value := hp_text if key == Stat.HP and hp_text != "" else str(int(values.get(key, 0)))
		UiTheme.draw_text(ci, body, Vector2(x, y + 3.0), NAMES[key], 16, UiTheme.PARCHMENT_MUTED)
		UiTheme.draw_text(ci, display, Vector2(x, y), value, 21, UiTheme.PARCHMENT_INK, 0, span, HORIZONTAL_ALIGNMENT_RIGHT)
		var extra := int(bonus.get(key, 0))
		if extra != 0:
			var vw := display.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			UiTheme.draw_text(ci, UiTheme.italic_font(), Vector2(x, y + 6.0), "%+d" % extra, 14,
				UiTheme.WAX if extra < 0 else UiTheme.GOLD_DEEP.darkened(0.25), 0, span - vw - 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
		ci.draw_line(Vector2(x, y + row - 3.5), Vector2(x + span, y + row - 3.5), Color(UiTheme.PARCHMENT_INK, 0.12), 1.0)


## The growth rates of `data`, at `origin`, `width` wide: a figure and a line for each stat but Build.
## `rates` (stat key -> rate), when given, are used in place of the companion's own: the rates with
## their traits counted (Levels.rates).
static func draw_growth(ci: CanvasItem, origin: Vector2, width: float, cols: int, data: CompanionData, row: float = GROWTH_ROW,
		rates: Dictionary = {}) -> void:
	var cw := (width + GUTTER) / cols
	var span := cw - GUTTER
	var body := UiTheme.body_font()
	var display := UiTheme.display_font()
	var i := 0
	for key in KEYS:
		if key == Stat.BLD:
			continue
		var x := origin.x + (i % cols) * cw
		var y := origin.y + floorf(float(i) / cols) * row
		i += 1
		var rate := int(rates[key]) if rates.has(key) else Levels.growth_rate(data, key)
		var strength := 0.9 if rate >= 50 else (0.62 if rate >= 30 else 0.38)
		UiTheme.draw_text(ci, body, Vector2(x, y + 1.0), NAMES[key], 16, UiTheme.PARCHMENT_MUTED)
		UiTheme.draw_text(ci, display, Vector2(x, y), "%d%%" % rate, 19, Color(UiTheme.PARCHMENT_INK, minf(1.0, strength + 0.25)), 0, span,
			HORIZONTAL_ALIGNMENT_RIGHT)
		var track := Rect2(x, y + row - 8.0, span, 4.0)
		ci.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		ci.draw_rect(Rect2(track.position, Vector2(track.size.x * rate / 100.0, track.size.y)), Color(UiTheme.PARCHMENT_INK, strength))
