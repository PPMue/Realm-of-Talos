class_name StoreScreen
extends Control
## The tavern and the smithy, from inside.
## Tavern: whoever is looking for work stands at the counter, with their paper laid on it: who they
## are, their stats and how they grow, what they bring, and the price. The seal on the paper hires them.
## Smithy: the smith's price list on the right, and the company down the left. Pointing at a weapon
## shows, beside each companion, whether they could hold it and what it would change.
## The first hire or purchase of a day spends the day's free action; the rules decide (see Run).

signal closed

enum Mode { SHOP, TAVERN }

## Tavern: the counter the hires stand behind, and their papers on it.
const COUNTER_Y := 560.0
const COUNTER_H := 56.0
const HIRE_ART := 600.0
const HIRE_FACE_Y := 230.0
const HIRE_STEP := 560.0
const PAPER := Vector2(520, 432)
const PAPER_Y := 628.0
const PAPER_PAD := 28.0
## Smithy: the price list, and the company beside it.
const PAGE := Rect2(770, 110, 1110, 946)
const PAGE_PAD := 36.0
const CREW_X := 60.0
const CREW_Y := 156.0
const CREW_W := 660.0
const CREW_ROW := 84.0

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
		_note.text = "Bought %s. It waits in the armory: hand it out at the barracks." % w.data.display_name
		refresh()


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
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func refresh() -> void:
	_purse.queue_redraw()
	var key := Run.FreeAction.SHOP if mode == Mode.SHOP else Run.FreeAction.TAVERN
	var spent := run.actions_used.has(key)
	_tavern.visible = mode == Mode.TAVERN
	_smithy.visible = mode == Mode.SHOP
	if mode == Mode.SHOP:
		_title.text = "THE SMITHY"
		_backdrop.kind = InteriorBackdrop.Kind.SMITHY
		_hint.text = "\"Mind the grade, Commander: a blade is no use to a hand that cannot hold it.\"   " + (
			"You have already spent the time here today; anything more costs only gold." if spent else "The first purchase takes part of the day.")
		_refresh_smithy()
	else:
		_title.text = "THE TAVERN"
		_backdrop.kind = InteriorBackdrop.Kind.TAVERN
		_hint.text = "\"These are the ones looking for work. They bring their own steel.\"   " + (
			"You have already spent the time here today; anyone more costs only gold." if spent else "The first hire takes part of the day.")
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


## A hire's paper, laid on the counter under them.
func _paper_for(data: CompanionData, x: float) -> Control:
	var paper := Control.new()
	paper.position = Vector2(x - PAPER.x * 0.5, PAPER_Y)
	paper.size = PAPER
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner := PAPER.x - PAPER_PAD * 2.0
	var level := run.hire_level()
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
		UiTheme.draw_text(paper, body, Vector2(PAPER_PAD, 82.0), _skills_text(data), 17, ink)
		UiTheme.draw_text(paper, italic, Vector2(PAPER_PAD, 106.0), _brings_text(data), 15, muted)
		StatTable.draw(paper, Vector2(PAPER_PAD, 140.0), inner, 3, data.base_stats(), data)
		paper.draw_line(Vector2(PAPER_PAD, 140.0 + StatTable.height(3) + 8.0), Vector2(PAPER_PAD + inner, 140.0 + StatTable.height(3) + 8.0),
			Color(ink, 0.45), 1.0))
	var seal := ActionButton.new()
	seal.paper = true
	seal.title = "Hire"
	seal.h = 50.0
	seal.position = Vector2(PAPER_PAD - 6.0, 140.0 + StatTable.height(3) + 16.0)
	var why := run.hire_block_reason(data)
	seal.disabled = why != ""
	seal.detail = "%d gold" % RunConfig.HIRE_COST if why == "" else why.trim_suffix(".").to_lower()
	seal.tooltip_text = why if why != "" else "%s joins the company for %d gold, in the line if there is room, else on the bench." % [
		data.display_name, RunConfig.HIRE_COST]
	seal.pressed.connect(hire.bind(data))
	paper.add_child(seal)
	return paper


## "Axe D, Spear E+" or "White magic D+, Dagger E": every skill above the lowest grade, best first.
static func _skills_text(data: CompanionData) -> String:
	var parts: Array = []
	for s: int in SpellData.School.values():
		var g := data.starting_magic_grade(s)
		if g > 0 or (data.signature_spell != null and data.signature_spell.school == s):
			parts.append([g + 100, "%s %s" % [SpellData.school_name(s), Proficiency.grade_name(g)]])
	for t: int in WeaponData.WeaponType.values():
		var g := data.starting_grade(t)
		if g > 0 or (data.weapon != null and data.weapon.weapon_type == t):
			parts.append([g, "%s %s" % [WeaponData.type_name(t), Proficiency.grade_name(g)]])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var words: Array[String] = []
	for p in parts:
		words.append(p[1])
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
	var row := RowButton.new(PAGE.size.x - PAGE_PAD * 2.0 - 14.0, 64.0)
	row.paper = true
	row.title = w.display_name
	var kind := WeaponData.type_name(w.weapon_type).to_lower()
	row.sub = "%s  ·  Mt %d  ·  Hit %d  ·  weight %d  ·  needs %s grade %s" % [kind, w.might, w.hit, w.weight, kind,
		Proficiency.grade_name(w.required_grade)]
	if w.is_magic():
		row.sub += "  ·  strikes with MAG against RES"
	elif not w.effective_against.is_empty():
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


## The company beside the price list: what each holds, or what the weapon pointed at would mean for them.
func _refresh_crew() -> void:
	for child in _crew.get_children():
		_crew.remove_child(child)
		child.queue_free()
	var n := run.roster.size()
	var step := minf(CREW_ROW, 880.0 / maxi(1, n))
	for i in n:
		var row := _crew_row(run.roster[i], step - 8.0)
		row.position = Vector2(0, i * step)
		_crew.add_child(row)


func _crew_row(c: RunCompanion, h: float) -> Control:
	var row := Control.new()
	row.size = Vector2(CREW_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var held := c.weapon()
	var able := _pointed != null and c.progress.can_equip_weapon(_pointed)
	var line := ""
	var ink := UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45)
	if _pointed == null:
		line = "%s  ·  Mt %d  ·  %s %s" % [held.display_name, held.might, WeaponData.type_name(held.weapon_type).to_lower(),
			Proficiency.grade_name(c.progress.grade(held.weapon_type))]
	elif able:
		var heavy := _pointed.weight - c.data.build
		line = "can hold it  ·  Mt %d → %d%s" % [held.might, _pointed.might, "  ·  too heavy: -%d DEX and SPD" % heavy if heavy > 0 else ""]
		ink = UiTheme.GOLD
	else:
		var t := _pointed.weapon_type
		line = "cannot: %s %s, needs %s" % [WeaponData.type_name(t).to_lower(), Proficiency.grade_name(c.progress.grade(t)),
			Proficiency.grade_name(_pointed.required_grade)]
		ink = Color(UiTheme.MUTED, 0.75)
	var dim := _pointed != null and not able
	row.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var r := minf(32.0, h * 0.5 - 4.0)
		var center := Vector2(r + 10.0, h * 0.5)
		if able:
			var clear := Color(UiTheme.GOLD, 0.0)
			row.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(CREW_W, 0), Vector2(CREW_W, h), Vector2(0, h)]),
				PackedColorArray([Color(UiTheme.GOLD, 0.2), clear, clear, Color(UiTheme.GOLD, 0.2)]))
			row.draw_rect(Rect2(0, 0, 3, h), UiTheme.GOLD)
		row.draw_circle(center + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
		row.draw_circle(center, r + 3.0, UiTheme.INK)
		UiIcons.portrait(row, center, r, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color(0.5, 0.49, 0.48) if dim else Color.WHITE)
		row.draw_arc(center, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if able else UiTheme.GOLD_DEEP, 2.0, true)
		var x := center.x + r + 18.0
		UiTheme.draw_text(row, display, Vector2(x, h * 0.5 - 27.0), c.display_name(), 25, Color(UiTheme.MUTED, 0.8) if dim else UiTheme.TEXT, 4)
		UiTheme.draw_text(row, body, Vector2(x, h * 0.5 + 5.0), line, 17, ink, 4))
	return row


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
	if visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
