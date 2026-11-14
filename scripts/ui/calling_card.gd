class_name CallingCard
extends RefCounted
## A calling written as a card (design/callings.md), the same wherever it is shown: the moment it is
## taken (CallingPanel), the Barracks sheet and a hire's paper. Its name, its one rule as one line,
## what it gives on the day as large figures with a word each ("+2 STRENGTH"), which stats grow faster
## and which slower from then on, and what it opens (a school of magic, or the weapon in hand).
## Only drawing: nothing here changes the run.

## What the card says about itself, top left: nothing chosen yet, the one picked, one someone else
## holds (`holder` names them), or the one this companion has taken.
enum State { OPEN, PICKED, CLOSED, TAKEN }


## Draws `calling` for the companion `p` inside `rect` on `ci`. `k` scales the text (1 at the moment of
## choosing). `dark`: on a dark ground (light ink); false: on parchment.
static func draw(ci: CanvasItem, rect: Rect2, calling: CallingData, p: CompanionProgress, state: int = State.OPEN,
		hover: bool = false, holder: String = "", k: float = 1.0, dark: bool = true) -> void:
	if calling == null or p == null:
		return
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var closed := state == State.CLOSED
	var lit := state == State.PICKED or state == State.TAKEN
	var tone := UiTheme.GOLD if dark else UiTheme.PARCHMENT_INK
	var ink := UiTheme.TEXT if dark else UiTheme.PARCHMENT_INK
	var muted := UiTheme.MUTED if dark else UiTheme.PARCHMENT_MUTED
	var bad := UiTheme.INJURED.lightened(0.15) if dark else UiTheme.WAX
	var outline := 4 if dark else 0
	var a := 0.4 if closed else 1.0
	# The plate.
	ci.draw_rect(rect, Color(tone, (0.16 if lit else 0.06) + (0.05 if hover and not closed else 0.0)))
	ci.draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2(1, 1)),
		Color(tone, 0.95 if lit else (0.6 if hover and not closed else 0.3) * a), false, 2.0 if lit or hover else 1.0)
	var pad := 18.0 * k
	var x := rect.position.x + pad
	var y := rect.position.y + 12.0 * k
	var inner := rect.size.x - pad * 2.0
	# The head: whose it is.
	var head := "A CALLING"
	var head_ink := Color(muted, a)
	match state:
		State.PICKED:
			head = "CHOSEN"
			head_ink = tone
		State.TAKEN:
			head = "CALLING"
			head_ink = tone
		State.CLOSED:
			head = "%s'S" % holder.to_upper() if holder != "" else "TAKEN"
			head_ink = bad
	UiTheme.draw_text(ci, display, Vector2(x, y), head, int(round(16.0 * k)), head_ink, outline)
	y += 24.0 * k
	var name_size := int(round(36.0 * k))
	while name_size > 18 and display.get_string_size(calling.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > inner:
		name_size -= 1
	UiTheme.draw_text(ci, display, Vector2(x, y), calling.display_name.to_upper(), name_size, Color(ink, a), outline + (2 if dark else 0))
	y += display.get_height(name_size) + 4.0 * k
	# The rule: one line of the rules, wrapped to the card.
	var rule_size := maxi(13, int(round(19.0 * k)))
	for row in wrap_text(italic, calling.rule, rule_size, inner):
		UiTheme.draw_text(ci, italic, Vector2(x, y), row, rule_size, Color(ink, a), outline)
		y += italic.get_height(rule_size)
	y += 10.0 * k
	ci.draw_line(Vector2(x, y), Vector2(x + inner, y), Color(tone, 0.3 * a), 1.0)
	y += 8.0 * k
	# On the day: a figure and a word each.
	var stats := Run.calling_stats(calling, p)
	var lead := p.calling_lead if p.calling == calling and p.calling_lead != "" else CallingData.lead_of(p)
	var gains := calling.gains_for(lead)
	var figure_size := int(round(40.0 * k))
	var word_size := maxi(12, int(round(17.0 * k)))
	for key: String in [stats[0], stats[1]]:
		var number := "+%d" % int(gains.get(key, 0))
		UiTheme.draw_text(ci, display, Vector2(x, y), number, figure_size, Color(tone, a), outline + (2 if dark else 0))
		var nw := display.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, figure_size).x
		UiTheme.draw_text(ci, display, Vector2(x + nw + 10.0 * k, y + display.get_height(figure_size) - display.get_height(word_size) - 6.0 * k),
			Stat.name_of(key).to_upper(), word_size, Color(ink, a), outline)
		y += figure_size * 1.16
	y += 6.0 * k
	# From then on: what grows faster, what slower.
	var small := maxi(12, int(round(16.0 * k)))
	UiTheme.draw_text(ci, display, Vector2(x, y), "GROWS", small, Color(muted, a), outline)
	var gx := x + display.get_string_size("GROWS", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 10.0 * k
	_arrow(ci, Vector2(gx + 5.0 * k, y + display.get_height(small) * 0.5), 5.0 * k, true, Color(UiTheme.READY if dark else Color("3d6b2c"), a))
	UiTheme.draw_text(ci, display, Vector2(gx + 15.0 * k, y), "%s, %s" % [Stat.name_of(stats[0]), Stat.name_of(stats[1])], small, Color(ink, a), outline)
	y += display.get_height(small) + 3.0 * k
	_arrow(ci, Vector2(gx + 5.0 * k, y + display.get_height(small) * 0.5), 5.0 * k, false, Color(bad, a))
	UiTheme.draw_text(ci, display, Vector2(gx + 15.0 * k, y), Stat.name_of(stats[2]), small, Color(ink, a), outline)
	# The foot: what it opens.
	var foot_y := rect.end.y - 34.0 * k
	var opens := opens_text(calling, p)
	if opens != "":
		ci.draw_line(Vector2(x, foot_y - 8.0 * k), Vector2(x + inner, foot_y - 8.0 * k), Color(tone, 0.22 * a), 1.0)
		var school := calling.school if not calling.either_school else -1
		var at := Vector2(x, foot_y)
		if calling.either_school:
			at.x += UiIcons.proficiency(ci, at, -1, SpellData.School.BLACK, "", small, Color(UiTheme.BLACK_MAGIC, a), ink, outline) + 4.0
			at.x += UiIcons.proficiency(ci, at, -1, SpellData.School.WHITE, "", small, Color(UiTheme.WHITE_MAGIC if dark else UiTheme.PARCHMENT_MUTED, a), ink, outline) + 8.0
		elif school >= 0:
			var sign_ink := UiTheme.school_color(school) if dark else UiTheme.PARCHMENT_MUTED
			at.x += UiIcons.proficiency(ci, at, -1, school, "", small, Color(sign_ink, a), ink, outline) + 8.0
		else:
			at.x += UiIcons.proficiency(ci, at, p.weapon.weapon_type, -1, "", small, Color(tone, a), ink, outline) + 8.0
		UiTheme.draw_text(ci, display, at, opens, small, Color(ink, a), outline)


## What `calling` opens for `p`, in a few words: "OPENS WHITE MAGIC", "OPENS A SCHOOL OF MAGIC", "AXE TO
## D" (only when the weapon in hand is below that grade), or "".
static func opens_text(calling: CallingData, p: CompanionProgress) -> String:
	if calling.either_school:
		return "OPENS A SCHOOL"
	if calling.school >= 0:
		return "OPENS %s" % SpellData.school_name(calling.school).to_upper()
	if p.weapon != null and p.grade(p.weapon.weapon_type) < RunConfig.CALLING_OPEN_GRADE:
		return "%s TO %s" % [WeaponData.type_name(p.weapon.weapon_type).to_upper(), Proficiency.grade_name(RunConfig.CALLING_OPEN_GRADE)]
	return ""


## The height a card needs at scale `k` and `width` wide, for `calling`.
static func height_for(calling: CallingData, width: float, k: float = 1.0) -> float:
	var italic := UiTheme.italic_font()
	var display := UiTheme.display_font()
	var rule_size := maxi(13, int(round(19.0 * k)))
	var rows := wrap_text(italic, calling.rule, rule_size, width - 36.0 * k).size()
	var small := maxi(12, int(round(16.0 * k)))
	return 12.0 * k + 24.0 * k + display.get_height(int(round(36.0 * k))) + 4.0 * k + rows * italic.get_height(rule_size) + 18.0 * k \
		+ 2.0 * int(round(40.0 * k)) * 1.16 + 6.0 * k + 2.0 * display.get_height(small) + 3.0 * k + 52.0 * k


## `text` broken into rows no wider than `width`.
static func wrap_text(font: Font, text: String, size: int, width: float) -> Array[String]:
	var rows: Array[String] = []
	var row := ""
	for word in text.split(" ", false):
		var trial := word if row == "" else row + " " + word
		if row != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			rows.append(row)
			row = word
		else:
			row = trial
	if row != "":
		rows.append(row)
	return rows


## A small arrowhead, up or down.
static func _arrow(ci: CanvasItem, c: Vector2, r: float, up: bool, color: Color) -> void:
	var d := -1.0 if up else 1.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -d * r * 0.6), c + Vector2(r, -d * r * 0.6), c + Vector2(0, d * r * 0.9)]), color)
