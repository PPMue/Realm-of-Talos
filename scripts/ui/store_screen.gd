class_name StoreScreen
extends Control
## The tavern and the smithy, from inside.
## Tavern: whoever is looking for work stands at the counter, with their paper laid on it: who they
## are, their stats and how they grow, what they bring, and the price. The seal on the paper hires them.
## Beside each, in light on a soft shadow, their traits: known before the hire is made.
## Smithy: the smith's price list on the right, and the company down the left. Pointing at a weapon
## shows, beside each companion, whether they could hold it and what their Attack would become
## (attack power for that kind of weapon plus its might; see RunCompanion.attack). A weapon just
## bought lies on the counter over the company: click whoever should take it (what they held goes
## back to the armory), or send it to the armory.
## Hiring and buying cost gold only, never the day's action; the rules decide (see Run).

signal closed

enum Mode { SHOP, TAVERN }

## Tavern: the counter the hires stand behind, and their papers on it.
const COUNTER_Y := 560.0
const COUNTER_H := 56.0
const HIRE_ART := 600.0
const HIRE_FACE_Y := 230.0
const HIRE_STEP := 700.0
const PAPER := Vector2(640, 406)
const PAPER_Y := 628.0
const PAPER_PAD := 28.0
## A hire's stats and growth rates stand side by side on the paper, from here down.
const PAPER_STATS_Y := 136.0
const PAPER_STAT_ROW := 25.0
const PAPER_GROWTH_ROW := 30.0
## What is said of a hire (their traits), written in light beside them.
const SAID_X := 214.0
const SAID_Y := 250.0
const SAID_W := 240.0
## Smithy: the price list, and the company beside it.
const PAGE := Rect2(770, 110, 1110, 946)
const PAGE_PAD := 36.0
const CREW_X := 60.0
const CREW_Y := 156.0
const CREW_W := 660.0
const CREW_ROW := 84.0
## The slip over the company for a weapon just bought.
const COUNTER := Vector2(660, 96)

var run: Run
var mode := Mode.SHOP
var _title: Label
var _hint: Label
var _note: Label
var _purse := Control.new()
var _backdrop := InteriorBackdrop.new()
var _tavern := Control.new()
var _papers := Control.new()
var _smithy := Control.new()
var _page := Control.new()
var _list := VBoxContainer.new()
var _crew := Control.new()
var _stock_head: Label
## The weapon under the pointer on the price list, if any.
var _pointed: WeaponData
## The weapon just bought, on the counter until someone takes it or it is sent to the armory. It is
## in the armory by the rules all along; this only says what the company is being offered.
var _bought: OwnedWeapon
var _counter := Control.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open_shop(p_run: Run) -> void:
	_open(p_run, Mode.SHOP)


func open_tavern(p_run: Run) -> void:
	_open(p_run, Mode.TAVERN)


func close() -> void:
	visible = false
	closed.emit()


func buy(item: ShopItemData) -> void:
	var w := run.buy(item)
	if w != null:
		_bought = w
		_pointed = null
		_note.text = ""
		refresh()


## Hands the weapon just bought to `c`; what they held goes back to the armory.
func give(c: RunCompanion) -> void:
	if _bought == null:
		return
	var w := _bought
	var old := c.weapon()
	if run.equip_weapon(c, w):
		_bought = null
		_note.text = "%s takes the %s.%s" % [c.display_name(), w.data.display_name.to_lower(),
			"  The %s goes to the armory." % old.display_name.to_lower() if old != null else ""]
		refresh()


## Sends the weapon just bought to the armory, to be handed out at the barracks.
func put_away() -> void:
	if _bought == null:
		return
	_note.text = "The %s waits in the armory." % _bought.data.display_name.to_lower()
	_bought = null
	refresh()


## The weapon the company is shown against: the one pointed at on the racks, else the one just bought.
func _shown() -> WeaponData:
	if _pointed != null:
		return _pointed
	return _bought.data if _bought != null else null


func hire(data: CompanionData) -> void:
	var c := run.hire(data)
	if c != null:
		_note.text = "%s joins the company, %s." % [c.display_name(), "in the line" if run.is_fielded(c) else "on the bench"]
		refresh()


func _open(p_run: Run, p_mode: Mode) -> void:
	run = p_run
	mode = p_mode
	_note.text = ""
	_pointed = null
	_bought = null
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func refresh() -> void:
	_purse.queue_redraw()
	_tavern.visible = mode == Mode.TAVERN
	_smithy.visible = mode == Mode.SHOP
	if mode == Mode.SHOP:
		_title.text = "THE SMITHY"
		_backdrop.kind = InteriorBackdrop.Kind.SMITHY
		_hint.text = "\"Mind the grade, Commander: a blade is no use to a hand that cannot hold it.\""
		_refresh_smithy()
	else:
		_title.text = "THE TAVERN"
		_backdrop.kind = InteriorBackdrop.Kind.TAVERN
		_hint.text = "\"These are the ones looking for work. They bring their own steel.\""
		_refresh_tavern()


# ---------------------------------------------------------------- the tavern

func _refresh_tavern() -> void:
	for child in _papers.get_children():
		_papers.remove_child(child)
		child.queue_free()
	_tavern.queue_redraw()
	var offers := run.tavern_offers
	for i in offers.size():
		_papers.add_child(_paper_for(offers[i], _hire_x(i, offers.size())))
	if offers.is_empty():
		var nobody := UiTheme.label("Nobody else is looking for work.", 26, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.4), false, 5)
		nobody.add_theme_font_override("font", UiTheme.italic_font())
		nobody.position = Vector2(0, COUNTER_Y - 120.0)
		nobody.size = Vector2(1920, 40)
		nobody.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_papers.add_child(nobody)


## Where hire `i` of `n` stands: spread about the middle of the room.
func _hire_x(i: int, n: int) -> float:
	var step := minf(HIRE_STEP, 1700.0 / maxi(1, n))
	return 960.0 + (i - (n - 1) * 0.5) * step


## The room behind the papers: light on the wall, the hires as cut-outs, and the counter in front.
func _draw_tavern() -> void:
	if run == null:
		return
	var offers := run.tavern_offers
	var lit := Color("7a6046")
	for i in offers.size():
		var x := _hire_x(i, offers.size())
		for k in 12:
			var f := 1.0 - k / 12.0
			var pts := PackedVector2Array()
			for a in 32:
				pts.append(Vector2(x, COUNTER_Y - 190.0) + Vector2.from_angle(TAU * a / 32.0) * Vector2(300.0, 330.0) * f)
			_tavern.draw_colored_polygon(pts, Color(lit, 0.07))
	for i in offers.size():
		var data := offers[i]
		var tex := data.portrait
		if tex == null:
			continue
		var ts := tex.get_size()
		var h := HIRE_ART * data.figure_scale
		var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
		var top_left := Vector2(_hire_x(i, offers.size()), HIRE_FACE_Y) - data.portrait_focus * art
		top_left.y = maxf(top_left.y, COUNTER_Y - art.y)
		var shown := clampf((COUNTER_Y - top_left.y) / art.y, 0.0, 1.0)
		_tavern.draw_texture_rect_region(tex, Rect2(top_left, Vector2(art.x, art.y * shown)), Rect2(0, 0, ts.x, ts.y * shown))
	# What is said of each: their traits, in light on a soft shadow beside them.
	for i in offers.size():
		var traits := run.offer_traits(offers[i])
		if traits.is_empty():
			continue
		var at := Vector2(_hire_x(i, offers.size()) + SAID_X, SAID_Y)
		var tall := ArtFacts.traits_height(SAID_W, traits, 1.1) + 34.0
		for g in 12:
			_tavern.draw_rect(Rect2(at - Vector2(10.0, 6.0), Vector2(SAID_W + 20.0, tall + 10.0)).grow(g * 4.0), Color(0, 0, 0, 0.055))
		UiTheme.draw_text(_tavern, UiTheme.display_font(), at, "TRAITS" if traits.size() > 1 else "TRAIT", 15, UiTheme.MUTED, 4)
		_tavern.draw_line(at + Vector2(0, 24.0), at + Vector2(SAID_W, 24.0), Color(UiTheme.GOLD_DEEP, 0.7), 1.0)
		ArtFacts.draw_traits(_tavern, at + Vector2(0, 32.0), SAID_W, traits, UiTheme.GOLD, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.25),
			UiTheme.INJURED.lightened(0.15), 1.1, 4)
	# The counter: a long board across the room.
	var w := maxf(size.x, 1920.0)
	var board := Rect2(0, COUNTER_Y, w, COUNTER_H)
	_tavern.draw_rect(Rect2(0, COUNTER_Y - 10.0, w, 10.0), Color(0, 0, 0, 0.22))
	_tavern.draw_rect(board, Color("3a2819"))
	UiTheme.draw_grain(_tavern, board, 0.22)
	_tavern.draw_rect(Rect2(0, COUNTER_Y, w, 4.0), Color("7a5a3c"))
	_tavern.draw_rect(Rect2(0, COUNTER_Y + 4.0, w, 2.0), Color(0, 0, 0, 0.3))
	_tavern.draw_rect(Rect2(0, COUNTER_Y + COUNTER_H - 5.0, w, 5.0), Color(0, 0, 0, 0.45))
	_tavern.draw_rect(Rect2(0, COUNTER_Y + COUNTER_H, w, 500.0), Color(0.07, 0.05, 0.04, 0.55))


## Where the two stat tables on a hire's paper end.
static func _paper_stats_end() -> float:
	return PAPER_STATS_Y + StatTable.HEAD_H + maxf(StatTable.values_height(2, PAPER_STAT_ROW), StatTable.growth_height(2, PAPER_GROWTH_ROW))


## A hire's paper, laid on the counter under them.
func _paper_for(data: CompanionData, x: float) -> Control:
	var paper := Control.new()
	paper.position = Vector2(x - PAPER.x * 0.5, PAPER_Y)
	paper.size = PAPER
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.tooltip_text = _skills_text(data)
	var inner := PAPER.x - PAPER_PAD * 2.0
	var level := run.hire_level()
	# Their numbers with their traits counted, as they will be once hired.
	var traits := run.offer_traits(data)
	var values := data.base_stats()
	var from_traits := {}
	var rates := {}
	for key: String in values:
		from_traits[key] = TraitRules.plain_stat(traits, key)
		values[key] = maxi(1 if key == Stat.HP else 0, int(values[key]) + int(from_traits[key]))
	for key in Levels.GROWTH_STATS:
		rates[key] = clampi(Levels.growth_rate(data, key) + TraitRules.total(traits, TraitModifier.Kind.GROWTH, -1, -1, 0, level + 1, key), 0, 100)
	paper.draw.connect(func() -> void:
		UiTheme.draw_parchment(paper, Rect2(Vector2.ZERO, PAPER), 0.45)
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var italic := UiTheme.italic_font()
		var ink := UiTheme.PARCHMENT_INK
		var muted := UiTheme.PARCHMENT_MUTED
		UiTheme.draw_text(paper, display, Vector2(PAPER_PAD, 16.0), data.display_name, 40, ink)
		UiTheme.draw_text(paper, italic, Vector2(PAPER_PAD, 34.0), "joins at level %d" % level, 17, muted, 0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
		paper.draw_line(Vector2(PAPER_PAD, 74.0), Vector2(PAPER_PAD + inner, 74.0), Color(ink, 0.45), 1.0)
		var sx := PAPER_PAD
		for skill: Array in _skills(data):
			sx += UiIcons.proficiency(paper, Vector2(sx, 78.0), skill[1], skill[2], skill[3], 20, Color(ink, 0.85), ink) + 22.0
		UiTheme.draw_text(paper, italic, Vector2(PAPER_PAD, 110.0), _brings_text(data), 15, muted)
		var half := (inner - 30.0) * 0.5
		var top := PAPER_STATS_Y + StatTable.HEAD_H
		StatTable.head(paper, Vector2(PAPER_PAD, PAPER_STATS_Y), half, "STATS")
		StatTable.draw_values(paper, Vector2(PAPER_PAD, top), half, 2, values, "", PAPER_STAT_ROW, from_traits)
		StatTable.head(paper, Vector2(PAPER_PAD + half + 30.0, PAPER_STATS_Y), half, "GROWTH", "chance to rise")
		StatTable.draw_growth(paper, Vector2(PAPER_PAD + half + 30.0, top), half, 2, data, PAPER_GROWTH_ROW, rates)
		paper.draw_line(Vector2(PAPER_PAD, _paper_stats_end() + 6.0), Vector2(PAPER_PAD + inner, _paper_stats_end() + 6.0), Color(ink, 0.45), 1.0))
	var seal := ActionButton.new()
	seal.paper = true
	seal.title = "Hire"
	seal.h = 50.0
	seal.position = Vector2(PAPER_PAD - 6.0, _paper_stats_end() + 12.0)
	var why := run.hire_block_reason(data)
	seal.disabled = why != ""
	seal.detail = "%d gold" % RunConfig.HIRE_COST if why == "" else why.trim_suffix(".").to_lower()
	seal.tooltip_text = why if why != "" else "%s joins the company for %d gold, in the line if there is room, else on the bench." % [
		data.display_name, RunConfig.HIRE_COST]
	seal.pressed.connect(hire.bind(data))
	paper.add_child(seal)
	return paper


## Every skill above the lowest grade, best first, magic before weapons:
## [[sort key, weapon type or -1, school or -1, grade name], ...].
static func _skills(data: CompanionData) -> Array:
	var parts: Array = []
	for s: int in SpellData.School.values():
		var g := data.starting_magic_grade(s)
		if g > 0 or (data.signature_spell != null and data.signature_spell.school == s):
			parts.append([g + 100, -1, s, Proficiency.grade_name(g)])
	for t: int in WeaponData.WeaponType.values():
		var g := data.starting_grade(t)
		if g > 0 or (data.weapon != null and data.weapon.weapon_type == t):
			parts.append([g, t, -1, Proficiency.grade_name(g)])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return parts


## The same in words, for a tooltip: "White magic D+, Dagger E".
static func _skills_text(data: CompanionData) -> String:
	var words: Array[String] = []
	for skill: Array in _skills(data):
		words.append("%s %s" % [WeaponData.type_name(skill[1]) if skill[1] >= 0 else SpellData.school_name(skill[2]), skill[3]])
	return ",  ".join(words)


## What they walk in with: the weapon, and the art or spell they already know.
static func _brings_text(data: CompanionData) -> String:
	var text := "Brings %s" % data.weapon.display_name.to_lower() if data.weapon != null else "Brings nothing"
	if data.signature_spell != null:
		text += " and the spell %s" % data.signature_spell.display_name
	elif data.signature_art != null:
		text += " and the art %s" % data.signature_art.display_name
	return text + "."


# ---------------------------------------------------------------- the smithy

func _refresh_smithy() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var stock := run.shop_stock()
	_stock_head.text = "ON THE RACKS  ·  %d" % stock.size()
	for item in stock:
		_list.add_child(_shop_row(item))
	if stock.is_empty():
		var none := UiTheme.label("Nothing on the racks today.", 18, UiTheme.PARCHMENT_MUTED)
		none.add_theme_font_override("font", UiTheme.italic_font())
		_list.add_child(none)
	_refresh_crew()


func _shop_row(item: ShopItemData) -> RowButton:
	var w := item.weapon
	var notes := weapon_notes(w)
	var row := RowButton.new(PAGE.size.x - PAGE_PAD * 2.0 - 14.0, RowButton.height_with(64.0, notes.size()))
	row.paper = true
	row.title = w.display_name
	row.marked = w.is_rare()
	row.notes = notes
	# What kind it is and what it needs are signs: the kind before the name, the grades after the small print.
	row.type_icon = w.weapon_type
	row.needs = weapon_needs(w)
	# A blade whose Might is the wielder's grade has no one number on the rack.
	var might := "Mt by grade" if w.might_by_grade else "Mt %d" % w.might
	row.sub = "%s%s  ·  Hit %d  ·  weight %d" % ["rare  ·  " if w.is_rare() else "", might, w.hit, w.weight]
	row.tooltip_text = "%s. Needs %s." % [WeaponData.type_name(w.weapon_type), w.requirement_text().replace(" · ", " and ")]
	if not w.effective_against.is_empty():
		row.sub += "  ·  effective against %s" % ", ".join(w.effective_against).to_lower()
	var why := run.buy_block_reason(item)
	row.disabled = why != ""
	row.detail = "%d gold" % item.price if why == "" else "%d gold  ·  %s" % [item.price, why.trim_suffix(".").to_lower()]
	row.pressed.connect(buy.bind(item))
	row.mouse_entered.connect(func() -> void:
		_pointed = w
		_refresh_crew())
	row.mouse_exited.connect(func() -> void:
		if _pointed == w:
			_pointed = null
			_refresh_crew())
	return row


## What holding `w` needs, as RowButton.needs wants it: the sign and grade of its weapon type and,
## for a two-proficiency weapon, of the second. With `p` given, what they lack is marked short.
static func weapon_needs(w: WeaponData, p: CompanionProgress = null) -> Array:
	var out: Array = [{"weapon": w.weapon_type, "grade": Proficiency.grade_name(w.required_grade),
		"short": p != null and p.grade(w.weapon_type) < w.required_grade}]
	if w.has_second_requirement():
		var second := {"grade": Proficiency.grade_name(w.second_grade)}
		if w.second_type >= 0:
			second["weapon"] = w.second_type
			second["short"] = p != null and p.grade(w.second_type) < w.second_grade
		else:
			second["school"] = w.second_school
			second["short"] = p != null and p.magic_grade(w.second_school) < w.second_grade
		out.append(second)
	return out


## What a weapon does that others of its kind do not, one short line each (WeaponData.trait_lines,
## with "Mt" written out). Empty for an ordinary weapon. Shared with the barracks.
static func weapon_notes(w: WeaponData) -> Array[String]:
	var out: Array[String] = []
	for line in w.trait_lines():
		out.append(line.replace("Mt ", "Might ").replace("MAG", "Magic").replace("RES", "Resistance").replace("DEF", "Defence")
			.replace("SPD", "Speed").replace("STR", "Strength").replace("DEX", "Dexterity"))
	return out


## The company beside the price list: what each holds, or what the weapon pointed at would mean for them.
func _refresh_crew() -> void:
	for child in _crew.get_children():
		_crew.remove_child(child)
		child.queue_free()
	var n := run.roster.size()
	var drop := COUNTER.y + 14.0 if _bought != null else 0.0
	_counter.visible = _bought != null
	_counter.queue_redraw()
	_crew.position.y = CREW_Y + drop
	var step := minf(CREW_ROW, (880.0 - drop) / maxi(1, n))
	for i in n:
		var row := _crew_row(run.roster[i], step - 8.0)
		row.position = Vector2(0, i * step)
		_crew.add_child(row)


func _crew_row(c: RunCompanion, h: float) -> Control:
	var row := Control.new()
	row.size = Vector2(CREW_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var held := c.weapon()
	var shown := _shown()
	# Offered: the weapon just bought is on the counter, and nothing on the racks is pointed at.
	var offered := _pointed == null and _bought != null
	var able := shown != null and c.progress.can_equip_weapon(shown)
	var line := ""
	var ink := UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45)
	if shown == null:
		line = "%s  ·  Attack %d  ·  " % [held.display_name, c.attack()]
	elif able:
		var heavy := shown.weight - c.data.build
		line = "%s  ·  Attack %d → %d%s" % ["hand it over" if offered else "can hold it", c.attack(), c.attack(shown),
			"  ·  too heavy: -%d DEX and SPD" % heavy if heavy > 0 else ""]
		ink = UiTheme.GOLD
	else:
		# The rules name the grade that is missing: "Needs axe D; Elena is E."
		var why := c.progress.weapon_block_reason(shown).trim_suffix(".")
		line = "cannot: " + why.left(1).to_lower() + why.substr(1)
		ink = Color(UiTheme.MUTED, 0.75)
	var dim := shown != null and not able
	# Someone who can take the weapon on the counter is a button.
	var takes := offered and run.equip_block_reason(c, _bought) == ""
	var over := [false]
	if takes:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.tooltip_text = "%s takes the %s; the %s goes back to the armory." % [c.display_name(), shown.display_name.to_lower(),
			held.display_name.to_lower()]
		row.mouse_entered.connect(func() -> void:
			over[0] = true
			row.queue_redraw())
		row.mouse_exited.connect(func() -> void:
			over[0] = false
			row.queue_redraw())
		row.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				row.accept_event()
				give.call_deferred(c))
	row.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var r := minf(32.0, h * 0.5 - 4.0)
		var center := Vector2(r + 10.0, h * 0.5)
		if able:
			var glow := 0.38 if over[0] else 0.2
			var clear := Color(UiTheme.GOLD, 0.08 if over[0] else 0.0)
			row.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(CREW_W, 0), Vector2(CREW_W, h), Vector2(0, h)]),
				PackedColorArray([Color(UiTheme.GOLD, glow), clear, clear, Color(UiTheme.GOLD, glow)]))
			row.draw_rect(Rect2(0, 0, 5 if over[0] else 3, h), UiTheme.GOLD)
		row.draw_circle(center + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
		row.draw_circle(center, r + 3.0, UiTheme.INK)
		UiIcons.portrait(row, center, r, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color(0.5, 0.49, 0.48) if dim else Color.WHITE)
		row.draw_arc(center, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if able else UiTheme.GOLD_DEEP, 2.0, true)
		var x := center.x + r + 18.0
		UiTheme.draw_text(row, display, Vector2(x, h * 0.5 - 27.0), c.display_name(), 25,
			Color(UiTheme.MUTED, 0.8) if dim else (ActionButton.LIT_INK if over[0] else UiTheme.TEXT), 4)
		UiTheme.draw_text(row, body, Vector2(x, h * 0.5 + 5.0), line, 17, ActionButton.LIT_INK if over[0] else ink, 4)
		if shown == null:
			# Their grade with what they hold: its sign and the letter.
			UiIcons.proficiency(row, Vector2(x + body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, h * 0.5 + 3.0), held.weapon_type, -1,
				Proficiency.grade_name(c.progress.grade(held.weapon_type)), 18, ink, UiTheme.TEXT, 4))
	return row


## The slip over the company: the weapon just bought, and the question.
func _draw_counter() -> void:
	if _bought == null:
		return
	var w := _bought.data
	_counter.draw_rect(Rect2(Vector2(5, 5), COUNTER), Color(0, 0, 0, 0.3))
	UiTheme.draw_parchment(_counter, Rect2(Vector2.ZERO, COUNTER), 0.4)
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var x := 22.0
	UiTheme.draw_text(_counter, display, Vector2(x, 10.0), "BOUGHT", 15, UiTheme.PARCHMENT_MUTED)
	if w.is_rare():
		UiIcons.diamond(_counter, Vector2(x + 7.0, 47.0), 6.0, UiTheme.WAX)
		x += 20.0
	UiTheme.draw_text(_counter, display, Vector2(x, 28.0), w.display_name, 28, UiTheme.PARCHMENT_INK, 0, COUNTER.x - 250.0 - x)
	UiTheme.draw_text(_counter, italic, Vector2(22.0, 64.0), "Who takes it?", 18, UiTheme.PARCHMENT_MUTED)


func _draw_page() -> void:
	UiTheme.draw_parchment(_page, Rect2(Vector2.ZERO, _page.size))
	var w := _page.size.x - PAGE_PAD * 2.0
	_page.draw_line(Vector2(PAGE_PAD, 70.0), Vector2(PAGE_PAD + w, 70.0), Color(UiTheme.PARCHMENT_INK, 0.45), 1.0)


## The company's gold, as a coin and a number.
func _draw_purse() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var text := str(run.gold)
	var tw := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var right := _purse.size.x
	UiTheme.draw_text(_purse, display, Vector2(right - tw, (_purse.size.y - display.get_height(36)) * 0.5), text, 36, UiTheme.GOLD, 6)
	UiIcons.coin(_purse, Vector2(right - tw - 30.0, _purse.size.y * 0.5 + 2.0), 30.0, UiTheme.GOLD)


func _build() -> void:
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# The tavern: the room and the hires, then their papers on top.
	_tavern.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tavern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tavern.draw.connect(_draw_tavern)
	add_child(_tavern)
	_papers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_papers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tavern.add_child(_papers)

	# The smithy: the company on the left, the price list on the right.
	_smithy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_smithy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_smithy)
	_counter.position = Vector2(CREW_X, CREW_Y - 6.0)
	_counter.size = COUNTER
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.visible = false
	_counter.draw.connect(_draw_counter)
	_smithy.add_child(_counter)
	var away := Button.new()
	away.text = "To the armory"
	away.tooltip_text = "Nobody takes it now. It waits in the armory and can be handed out at the barracks."
	away.focus_mode = Control.FOCUS_NONE
	away.add_theme_font_size_override("font_size", 20)
	away.position = Vector2(COUNTER.x - 222.0, 26.0)
	away.size = Vector2(200, 44)
	away.pressed.connect(put_away)
	_counter.add_child(away)
	_crew.position = Vector2(CREW_X, CREW_Y)
	_crew.size = Vector2(CREW_W, 880)
	_crew.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smithy.add_child(_crew)
	_page.position = PAGE.position
	_page.size = PAGE.size
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.draw.connect(_draw_page)
	_smithy.add_child(_page)
	_stock_head = UiTheme.label("", 18, UiTheme.PARCHMENT_MUTED, true)
	_stock_head.position = Vector2(PAGE_PAD, 34.0)
	_page.add_child(_stock_head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAGE_PAD, 82.0)
	scroll.size = Vector2(PAGE.size.x - PAGE_PAD * 2.0, PAGE.size.y - 82.0 - 30.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroll)
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)

	_title = UiTheme.label("", 44, UiTheme.GOLD, true, 8)
	_title.position = Vector2(60, 20)
	add_child(_title)
	_hint = UiTheme.label("", 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.position = Vector2(64, 78)
	add_child(_hint)
	_note = UiTheme.label("", 20, UiTheme.READY, false, 5)
	_note.add_theme_font_override("font", UiTheme.italic_font())
	_note.position = Vector2(64, 106)
	add_child(_note)

	_purse.position = Vector2(1250, 28)
	_purse.size = Vector2(300, 58)
	_purse.mouse_filter = Control.MOUSE_FILTER_STOP
	_purse.tooltip_text = "The company's gold."
	_purse.draw.connect(_draw_purse)
	add_child(_purse)

	var back := Button.new()
	back.text = "Leave"
	back.tooltip_text = "Back to the city.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
