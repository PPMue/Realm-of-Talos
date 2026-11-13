class_name ArtFacts
extends RefCounted
## The details of a combat art or a spell, set out to be read at a glance instead of as a sentence:
## what it costs as large figures with one word each ("5 STAMINA", "1 RECOVERY"; a spell's uses in
## place of stamina), then what it does, one thing to a line. Recovery is how many of their next
## actions the user sits out. The same drawing serves the panel for something just learned, the
## orders in a battle and the barracks sheet; `k` scales it and the inks suit the ground it is drawn on.


## The figures of an art: [[number, word], ...]. `cost` (when 0 or more) is what it costs whoever
## would use it (their traits can change it); otherwise the art's own cost.
static func art_figures(art: CombatArtData, cost: int = -1) -> Array:
	return [[str(cost if cost >= 0 else art.stamina_cost), "STAMINA"], [str(art.recovery), "RECOVERY"]]


## The figures of a spell. `uses_left` (when 0 or more) shows how many casts remain of its uses;
## `max_uses` (when above 0) is how many the caster has of it (their traits can change it).
static func spell_figures(sp: SpellData, uses_left: int = -1, max_uses: int = 0) -> Array:
	var most := max_uses if max_uses > 0 else sp.uses
	var uses := [str(most), "USES"] if uses_left < 0 else [str(uses_left), "OF %d USES" % most]
	return [uses, [str(sp.recovery), "RECOVERY"]]


## What an art does, one thing per entry. `held_type` is the weapon type in the user's hand (-1 for
## none): when it is not the art's, the last line says what it needs.
static func art_lines(art: CombatArtData, held_type: int = -2) -> Array[String]:
	var lines := _plain(art.effect_lines())
	if held_type != -2 and held_type != art.weapon_type:
		lines.append("Needs a %s in hand" % art.type_name().to_lower())
	return lines


static func spell_lines(sp: SpellData) -> Array[String]:
	return _plain(sp.effect_lines())


## "BOW  ·  TIER I"
static func art_tag(art: CombatArtData) -> String:
	return "%s  ·  TIER %s" % [art.type_name().to_upper(), CombatArtData.tier_numeral(art.tier)]


static func spell_tag(sp: SpellData) -> String:
	return "%s  ·  TIER %s" % [sp.school_text().to_upper(), CombatArtData.tier_numeral(sp.tier)]


## Draws the figures and under them the lines, from `origin`, no wider than `width`; returns the
## height used. `lines_room` (when above 0) is the most height the lines may take: they are set
## smaller to fit. `note`, when given, is written first, in `note_ink` (why it cannot be used now).
## `line_size` (when above 0) sets the size of the lines apart from `k`.
static func draw(ci: CanvasItem, origin: Vector2, width: float, figures: Array, lines: Array[String], accent: Color, ink: Color,
		muted: Color, k: float = 1.0, lines_room: float = 0.0, outline: int = 4, note: String = "", note_ink: Color = Color.WHITE,
		line_size: int = 0) -> float:
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	var y := origin.y
	if note != "":
		var note_size := maxi(13, int(round(19.0 * k))) if line_size <= 0 else line_size - 2
		for row in _wrap(italic, note, note_size, width):
			UiTheme.draw_text(ci, italic, Vector2(origin.x, y), row, note_size, note_ink, outline)
			y += italic.get_height(note_size)
		y += 2.0

	# What it costs: a large figure and a word each.
	var figure_size := int(round(58.0 * k))
	var word_size := maxi(12, int(round(19.0 * k)))
	var x := origin.x
	for f: Array in figures:
		var number := String(f[0])
		var word := String(f[1])
		UiTheme.draw_text(ci, display, Vector2(x, y), number, figure_size, accent, outline + (2 if outline > 0 else 0))
		var nw := display.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, figure_size).x
		UiTheme.draw_text(ci, display, Vector2(x + nw + 12.0 * k, y + display.get_height(figure_size) - display.get_height(word_size) - 9.0 * k),
			word, word_size, muted, outline)
		x += maxf(176.0 * k, nw + 12.0 * k + display.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x + 44.0 * k)
	y += figure_size * 1.38
	ci.draw_line(Vector2(origin.x, y), Vector2(origin.x + width, y), Color(accent, 0.3), 1.0)
	y += 12.0 * k

	# What it does: one thing to a line, set smaller when there is much to say.
	var size := maxi(14, int(round(27.0 * k))) if line_size <= 0 else line_size
	var indent := maxf(16.0, size * 1.05)
	var rows: Array = []
	while true:
		rows.clear()
		for line in lines:
			var wrapped := _wrap(body, line, size, width - indent)
			for i in wrapped.size():
				rows.append([wrapped[i], i == 0])
		if lines_room <= 0.0 or rows.size() * _step(body, size) <= lines_room or size <= 13:
			break
		size -= 1
	var step := _step(body, size)
	for row: Array in rows:
		if row[1]:
			UiIcons.diamond(ci, Vector2(origin.x + indent * 0.3, y + body.get_height(size) * 0.5 + 1.0), maxf(3.0, 4.5 * k), accent)
		UiTheme.draw_text(ci, body, Vector2(origin.x + indent, y), String(row[0]), size, ink, outline)
		y += step
	return y - origin.y


## A companion's traits written out: the name, then what each gives (and, for a two-edged one, what it
## takes, in `bad`), from `origin`, no wider than `width`. `k` scales it; returns the height used.
static func draw_traits(ci: CanvasItem, origin: Vector2, width: float, traits: Array[TraitData], ink: Color, muted: Color, bad: Color,
		k: float = 1.0, outline: int = 0) -> float:
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	var name_size := int(round(20.0 * k))
	var line_size := maxi(13, int(round(16.0 * k)))
	var y := origin.y
	for t in traits:
		UiTheme.draw_text(ci, display, Vector2(origin.x, y), t.display_name, name_size, ink, outline, width)
		if t.rarity != TraitData.Rarity.COMMON:
			UiTheme.draw_text(ci, italic, Vector2(origin.x, y + 4.0 * k), t.rarity_name().to_lower(), maxi(12, line_size - 2), muted, outline, width,
				HORIZONTAL_ALIGNMENT_RIGHT)
		y += name_size * 1.32
		for row in _wrap(body, "  ·  ".join(t.lines()), line_size, width):
			UiTheme.draw_text(ci, body, Vector2(origin.x, y), row, line_size, muted, outline)
			y += body.get_height(line_size) + 1.0
		if not t.drawback_lines().is_empty():
			for row in _wrap(body, "  ·  ".join(t.drawback_lines()), line_size, width):
				UiTheme.draw_text(ci, body, Vector2(origin.x, y), row, line_size, bad, outline)
				y += body.get_height(line_size) + 1.0
		y += 7.0 * k
	return y - origin.y


## Height draw_traits would use.
static func traits_height(width: float, traits: Array[TraitData], k: float = 1.0) -> float:
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var name_size := int(round(20.0 * k))
	var line_size := maxi(13, int(round(16.0 * k)))
	var h := 0.0
	for t in traits:
		h += name_size * 1.32 + 7.0 * k
		h += _wrap(body, "  ·  ".join(t.lines()), line_size, width).size() * (body.get_height(line_size) + 1.0)
		if not t.drawback_lines().is_empty():
			h += _wrap(body, "  ·  ".join(t.drawback_lines()), line_size, width).size() * (body.get_height(line_size) + 1.0)
	return h


static func _step(font: Font, size: int) -> float:
	return font.get_height(size) + maxf(1.0, size * 0.12)


## Written out: "Might", which "Mt" on a weapon's own line is short for.
static func _plain(lines: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for line in lines:
		out.append(line.replace("Mt ", "Might "))
	return out


## `text` broken at spaces into rows no wider than `width`.
static func _wrap(font: Font, text: String, size: int, width: float) -> Array[String]:
	var rows: Array[String] = []
	var row := ""
	for word in text.split(" "):
		var trial := word if row == "" else row + " " + word
		if row != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows
