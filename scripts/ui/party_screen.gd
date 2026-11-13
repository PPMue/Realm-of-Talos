class_name PartyScreen
extends Control
## The barracks, between battles: the whole company and everything about whoever is chosen, on one
## screen. Down the left is the company: the line from the rear to the front, the bench, and whoever
## lies in the infirmary. A row is carried to another place or to the bench to change the line (or
## the orders on the sheet do it). The rest of the screen is the muster sheet of the one chosen, in
## three columns with nothing hidden behind another page:
##   1. who they are (a portrait, level, health), their stats, how readily each stat grows, and the
##      orders that move them in the line;
##   2. the weapon in hand and the Attack it gives, the armory to choose another from (with the
##      Attack each would give, or why it cannot be held), and their grade in every weapon and both
##      schools of magic with the way to the next;
##   3. every combat art they know (click one to carry it into battle or leave it behind; three are
##      carried) and every spell with its uses left; what the one under the pointer costs and does
##      is set out at the foot (see ArtFacts).
## Every change is a Run command or goes straight into the companion's CompanionProgress; the screen
## only reads and redraws.

signal closed

const LIST_X := 40.0
const LIST_Y := 150.0
const LINE_ROW := 78.0
const LINE_STEP := 84.0
const BENCH_Y := LIST_Y + 34.0 + LINE_STEP * RunConfig.MAX_FIELDED + 44.0
const BENCH_ROW := 62.0
const BENCH_STEP := 68.0
const LIST_END := 1050.0

const SHEET := Rect2(440, 110, 1450, 946)
const PAD := 34.0
const C1_X := 34.0
const C1_W := 400.0
const C2_X := 464.0
const C2_W := 478.0
const C3_X := 972.0
const C3_W := 444.0
const TOP := 26.0
## Column 1.
const CARD_H := 208.0
const STATS_Y := TOP + CARD_H + 22.0
const GROWTH_Y := STATS_Y + StatTable.HEAD_H + 180.0 + 18.0
const ORDERS_Y := GROWTH_Y + StatTable.HEAD_H + 180.0 + 20.0
## Column 2.
const GRADE_ROW := 46.0
const GRADES_Y := SHEET.size.y - PAD - StatTable.HEAD_H - GRADE_ROW * 4.0
## Column 3.
const FOOT_H := 204.0
const FOOT_Y := SHEET.size.y - PAD - FOOT_H
const DEFAULT_FOOT := "Point at an art or a spell to read it. Click an art to carry it into battle, or to leave it behind."

var run: Run
var _selected: RunCompanion
var _rows := Control.new()
var _sheet := Control.new()
var _orders := Control.new()
var _held := Control.new()
var _armory_scroll := ScrollContainer.new()
var _armory := VBoxContainer.new()
var _grades := Control.new()
var _arts_scroll := ScrollContainer.new()
var _arts := VBoxContainer.new()
var _foot: Label
var _foot_facts := Control.new()
## The art or spell under the pointer, set out at the foot: {figures, lines}, or empty.
var _reading: Dictionary = {}
## Where the armory's heading sits (under the weapon in hand, whose row varies in height).
var _armory_y := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run, select: RunCompanion = null) -> void:
	run = p_run
	_selected = select if select != null and run.roster.has(select) else (run.lineup[-1] if not run.lineup.is_empty() else
		(run.roster[0] if not run.roster.is_empty() else null))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func select(c: RunCompanion) -> void:
	_selected = c
	refresh()


## Everyone in the order the list shows them: the line from the rear, the bench, the infirmary.
func listed() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	out.append_array(run.lineup)
	out.append_array(run.reserve())
	out.append_array(run.infirmary())
	return out


## Chooses whoever is `step` rows below (or above) the one chosen, going round at the ends.
func select_next(step: int) -> void:
	var all := listed()
	if all.is_empty():
		return
	var i := all.find(_selected)
	select(all[posmod((i if i >= 0 else 0) + step, all.size())])


# ---------------------------------------------------------------- commands

func move(step: int) -> void:
	if _selected != null and run.is_fielded(_selected):
		run.move_in_line(_selected, run.lineup.find(_selected) + step)
		refresh()


func toggle_fielded() -> void:
	if _selected == null:
		return
	if run.is_fielded(_selected):
		run.bench(_selected)
	else:
		run.field(_selected)
	refresh()


## Sets `c` down at place `index` of the line (0 = the rear), or on the bench when `index` is -1.
## Someone from the bench set down on a full line changes places with whoever stood there.
func place(c: RunCompanion, index: int) -> void:
	if c == null or not run.can_change_party():
		return
	set_down(run, c, index)
	_selected = c
	refresh()


## The rule behind place(): `c` goes to place `index` of the line (0 = the
## rear) or to the bench (-1). From the bench onto a full line they change places with whoever stood
## there. Returns whether anything changed.
static func set_down(r: Run, c: RunCompanion, index: int) -> bool:
	if c == null or not r.can_change_party():
		return false
	if index < 0:
		return r.bench(c)
	if r.is_fielded(c):
		return r.move_in_line(c, index)
	if r.lineup.size() < RunConfig.MAX_FIELDED:
		return r.field(c, index)
	if index < r.lineup.size():
		r.bench(r.lineup[index])
		return r.field(c, index)
	return false


func equip(w: OwnedWeapon) -> void:
	if _selected != null and run.equip_weapon(_selected, w):
		refresh()


## Carries the art into battle if it is known and there is room, or leaves it behind if it is carried.
func toggle_art(art: CombatArtData) -> void:
	if _selected == null:
		return
	var p := _selected.progress
	if p.is_equipped(art):
		p.unequip(art)
	else:
		p.equip(art)
	refresh()


# ---------------------------------------------------------------- the company, down the left

func refresh() -> void:
	if run == null:
		return
	_clear(_rows)
	var carry := run.can_change_party()
	for i in RunConfig.MAX_FIELDED:
		var row := _row(run.lineup[i] if i < run.lineup.size() else null, MusterRow.Kind.LINE, LINE_ROW, carry)
		row.position = Vector2(0, 34.0 + i * LINE_STEP)
		row.dropped.connect(place.bind(i))
		_rows.add_child(row)
	var bench := run.reserve()
	var beds := run.infirmary()
	# A large company packs the bench and the beds closer.
	var room := LIST_END - BENCH_Y - 30.0 - (40.0 if not beds.is_empty() else 0.0)
	var step := minf(BENCH_STEP, room / maxi(1, bench.size() + beds.size()))
	var y := BENCH_Y - LIST_Y + 30.0
	for c in bench:
		var row := _row(c, MusterRow.Kind.BENCH, step - 6.0, carry)
		row.position = Vector2(0, y)
		row.dropped.connect(place.bind(-1))
		_rows.add_child(row)
		y += step
	if bench.is_empty():
		var nobody := UiTheme.label("Nobody is waiting. Anyone beyond the %d in the line sits here." % RunConfig.MAX_FIELDED, 16,
			Color(UiTheme.MUTED, 0.85), false, 4)
		nobody.add_theme_font_override("font", UiTheme.italic_font())
		nobody.position = Vector2(4, y + 4.0)
		nobody.size = Vector2(MusterRow.W, 44)
		nobody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nobody.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(nobody)
		y += 56.0
	if not beds.is_empty():
		var head := UiTheme.label("IN THE INFIRMARY", 17, UiTheme.MUTED, true, 5)
		head.position = Vector2(4, y + 10.0)
		_rows.add_child(head)
		y += 40.0
		for c in beds:
			var left := c.days_left(run.day)
			var row := _row(c, MusterRow.Kind.INFIRMARY, step - 6.0, false)
			row.note = "up tomorrow" if left <= 1 else "%d days" % left
			row.position = Vector2(0, y)
			_rows.add_child(row)
			y += step
	_refresh_sheet()


func _row(c: RunCompanion, kind: MusterRow.Kind, h: float, carry: bool) -> MusterRow:
	var row := MusterRow.new()
	row.can_carry = carry
	row.setup(c, kind, h)
	if c != null:
		row.set_selected(c == _selected)
		row.pressed.connect(select.bind(c))
	return row


# ---------------------------------------------------------------- the sheet

func _refresh_sheet() -> void:
	_clear(_orders)
	_clear(_held)
	_clear(_armory)
	_clear(_grades)
	_clear(_arts)
	_read({})
	_sheet.queue_redraw()
	var c := _selected
	_armory_scroll.visible = c != null
	_arts_scroll.visible = c != null
	_foot.visible = c != null
	if c == null:
		return
	var p := c.progress
	var abed := c.injured
	var fielded := run.is_fielded(c)
	var index := run.lineup.find(c)
	var can := run.can_change_party() and not abed

	# Column 1: the orders that move them.
	var back := _order(0, "Step back", "←", "Move one place toward the rear, away from the enemy.", move.bind(-1))
	back.disabled = not fielded or index <= 0 or not can
	var fwd := _order(1, "Step forward", "→", "Move one place toward the front, nearer the enemy.", move.bind(1))
	fwd.disabled = not fielded or index >= run.lineup.size() - 1 or not can
	var full := not fielded and run.lineup.size() >= RunConfig.MAX_FIELDED
	var field_tip := "Leave the line and wait on the bench. Those on the bench do not fight." if fielded else \
		"Join the line, at the front." if not full else \
		"The line is full (%d). Send someone to the bench first, or carry %s onto the one to replace." % [RunConfig.MAX_FIELDED, c.display_name()]
	if abed:
		field_tip = run.infirmary_block_reason(c)
	var f := _order(2, "To the bench" if fielded else "Into the line", "F", field_tip, toggle_fielded)
	f.disabled = full or not can
	if abed:
		f.detail = "in the infirmary"
	elif full:
		f.detail = "line full"

	# Column 2: the weapon in hand, then the armory.
	var w := c.weapon()
	var t := w.weapon_type
	var held_row: RowButton = null
	var others: Array[OwnedWeapon] = []
	for item: OwnedWeapon in run.inventory.weapons:
		if item.holder == c:
			held_row = _weapon_row(c, item)
		else:
			others.append(item)
	if held_row != null:
		_held.add_child(held_row)
	_armory_y = TOP + StatTable.HEAD_H + (held_row.size.y if held_row != null else 0.0) + 16.0
	_armory_scroll.position = Vector2(C2_X, _armory_y + StatTable.HEAD_H)
	_armory_scroll.size = Vector2(C2_W, GRADES_Y - 16.0 - _armory_scroll.position.y)
	others.sort_custom(func(a: OwnedWeapon, b: OwnedWeapon) -> bool:
		# What could be taken in hand comes first, then what they cannot hold, then what others hold.
		var ka := [_armory_rank(c, a), 0 if a.data.weapon_type == t else 1, a.data.weapon_type, -a.data.might_for(p), a.data.display_name]
		var kb := [_armory_rank(c, b), 0 if b.data.weapon_type == t else 1, b.data.weapon_type, -b.data.might_for(p), b.data.display_name]
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	for item in others:
		_armory.add_child(_weapon_row(c, item))
	if others.is_empty():
		_armory.add_child(_section("Nothing else in the armory. The smithy sells weapons on quiet days.", C2_W - 14.0))

	# Column 2: grades, two to a row; the five weapons, then the two schools.
	var cells: Array = []
	for type: int in WeaponData.WeaponType.values():
		var step := p.progress_to_next(type)
		var g := p.grade(type)
		var held := type == t
		cells.append({"title": WeaponData.type_name(type), "grade": g, "step": step, "ink": UiTheme.PARCHMENT_INK, "held": held,
			"strong": held or p.points_in(type) > 0,
			"tip": "%s %s: %d points.%s\nFighting with a weapon raises its grade; every grade reached teaches a combat art." % [
				WeaponData.type_name(type), Proficiency.grade_name(g), p.points_in(type),
				"" if step.y == 0 else " %d more to reach %s." % [step.y - step.x, Proficiency.grade_name(g + 1)]]})
	var schools := p.spell_schools()
	for s: int in SpellData.School.values():
		var step := p.magic_progress_to_next(s)
		var g := p.magic_grade(s)
		var casts := schools.has(s)
		cells.append({"title": SpellData.school_name(s), "grade": g, "step": step, "ink": UiTheme.school_color(s).darkened(0.55), "held": false,
			"strong": casts or p.magic_points_in(s) > 0,
			"tip": "%s %s: %d points. Every cast gives %d; a grade reached teaches a new spell.%s" % [SpellData.school_name(s),
				Proficiency.grade_name(g), p.magic_points_in(s), BattleConfig.MAGIC_POINTS_PER_CAST,
				"" if casts else "\nOnly someone who knows a spell of this school can cast it and raise it."]})
	var cw := (C2_W + 24.0) / 2.0
	for i in cells.size():
		var cell := _grade_cell(cells[i], cw - 24.0)
		cell.position = Vector2((i % 2) * cw, floorf(i / 2.0) * GRADE_ROW)
		_grades.add_child(cell)

	# Column 3: arts, then spells.
	var arts := _sorted_arts(p)
	if arts.is_empty():
		_arts.add_child(_section("No combat arts yet. Every weapon grade reached teaches one.", C3_W - 14.0))
	for art in arts:
		_arts.add_child(_art_row(p, art))
	if not p.known_spells.is_empty():
		_arts.add_child(_section("Spells  ·  uses come back with a rest at the inn", C3_W - 14.0))
		for sp in p.known_spells:
			_arts.add_child(_spell_row(p, sp))


func _armory_rank(c: RunCompanion, item: OwnedWeapon) -> int:
	if item.holder != null:
		return 2
	return 0 if run.equip_block_reason(c, item) == "" else 1


## A weapon of the armory as it would be in `c`'s hand: the one held is marked, another says the
## Attack it would give (click to take it) or, shortly, why it cannot be taken.
func _weapon_row(c: RunCompanion, item: OwnedWeapon) -> RowButton:
	var d := item.data
	var notes := StoreScreen.weapon_notes(d)
	var too_heavy := d.weight - c.data.build
	if too_heavy > 0:
		notes.append("Too heavy for %s: -%d Dexterity and Speed" % [c.display_name(), too_heavy])
	var row := RowButton.new(C2_W - 14.0, RowButton.height_with(56.0, notes.size()))
	row.paper = true
	row.title = d.display_name
	row.marked = d.is_rare()
	row.notes = notes
	# Might as it would be in this companion's hand (a rare blade's may follow their grade).
	row.sub = "%s%s  ·  Mt %d  ·  Hit %d  ·  weight %d" % ["rare " if d.is_rare() else "", WeaponData.type_name(d.weapon_type).to_lower(),
		d.might_for(c.progress), d.hit, d.weight]
	var why := run.equip_block_reason(c, item)
	if item.holder == c:
		row.active = true
		row.sub += "  ·  needs %s" % d.requirement_text().replace(" · ", " and ")
		row.mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif item.holder != null:
		row.disabled = true
		row.detail = "held by %s" % item.holder.display_name()
		row.tooltip_text = why
	elif why != "":
		row.disabled = true
		row.detail = "needs %s" % d.requirement_text().replace(" · ", " and ") if not c.progress.can_equip_weapon(d) else why.trim_suffix(".")
		row.tooltip_text = why
	else:
		row.detail = "Attack %d" % c.attack(d)
		row.tooltip_text = "Take the %s in hand: Attack %d (now %d). Needs %s." % [d.display_name, c.attack(d), c.attack(),
			d.requirement_text().replace(" · ", " and ")]
		row.pressed.connect(equip.bind(item))
	return row


func _art_row(p: CompanionProgress, art: CombatArtData) -> RowButton:
	var row := RowButton.new(C3_W - 14.0, 56.0)
	row.paper = true
	row.title = art.display_name
	row.sub = "%s  ·  tier %s  ·  %d stamina%s" % [art.type_name().to_lower(), CombatArtData.tier_numeral(art.tier),
		art.stamina_cost, "  ·  signature" if art == p.data.signature_art else ""]
	var slot := p.equipped_arts.find(art) + 1
	var wrong := p.weapon == null or p.weapon.weapon_type != art.weapon_type
	if slot > 0:
		row.active = true
		row.detail = "carried  ·  %d" % slot
	elif not p.has_free_slot():
		row.disabled = true
		row.detail = "no room"
		row.tooltip_text = "Three arts are carried. Leave one behind first."
	else:
		row.detail = "needs a %s" % art.type_name().to_lower() if wrong else "left behind"
	row.pressed.connect(toggle_art.bind(art))
	_read_on_hover(row, {"figures": ArtFacts.art_figures(art),
		"lines": ArtFacts.art_lines(art, p.weapon.weapon_type if p.weapon != null else -1)})
	return row


func _spell_row(p: CompanionProgress, sp: SpellData) -> RowButton:
	var row := RowButton.new(C3_W - 14.0, 56.0)
	row.paper = true
	row.mouse_default_cursor_shape = Control.CURSOR_ARROW
	row.title = sp.display_name
	row.sub = "%s  ·  tier %s%s" % [sp.school_text().to_lower(), CombatArtData.tier_numeral(sp.tier),
		"  ·  signature" if sp == p.data.signature_spell else ""]
	row.detail = "%d of %d uses" % [p.uses_left(sp), sp.uses]
	_read_on_hover(row, {"figures": ArtFacts.spell_figures(sp, p.uses_left(sp)), "lines": ArtFacts.spell_lines(sp)})
	return row


## Known arts in a stable order (so lines do not jump when clicked): the weapon held first, then by tier.
func _sorted_arts(p: CompanionProgress) -> Array[CombatArtData]:
	var held := p.weapon.weapon_type if p.weapon != null else -1
	var arts := p.known_arts.duplicate()
	arts.sort_custom(func(a: CombatArtData, b: CombatArtData) -> bool:
		var ka := [0 if a.weapon_type == held else 1, a.weapon_type, 0 if a == p.data.signature_art else 1, a.tier, a.display_name]
		var kb := [0 if b.weapon_type == held else 1, b.weapon_type, 0 if b == p.data.signature_art else 1, b.tier, b.display_name]
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return arts


## While the pointer is on `row`, the foot of the third column sets out `what` ({figures, lines}).
func _read_on_hover(row: Control, what: Dictionary) -> void:
	row.mouse_entered.connect(_read.bind(what))
	row.mouse_exited.connect(func() -> void:
		if _reading == what:
			_read({}))


func _read(what: Dictionary) -> void:
	_reading = what
	_foot.visible = what.is_empty() and _selected != null
	_foot_facts.queue_redraw()


func _draw_foot() -> void:
	if _reading.is_empty():
		return
	var lines: Array[String] = []
	lines.assign(_reading.lines)
	ArtFacts.draw(_foot_facts, Vector2.ZERO, _foot_facts.size.x, _reading.figures, lines, UiTheme.WAX.darkened(0.1), UiTheme.PARCHMENT_INK,
		UiTheme.PARCHMENT_MUTED, 0.74, _foot_facts.size.y - 74.0, 0, "", Color.WHITE, 20)


## One grade: the name, the letter, and under them a line for the way to the next.
## `cell.ink` colours it (a school's own colour for magic); `cell.strong` is false for a skill never used.
func _grade_cell(cell: Dictionary, w: float) -> Control:
	var line := Control.new()
	line.size = Vector2(w, GRADE_ROW - 4.0)
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.tooltip_text = cell.tip
	var step: Vector2i = cell.step
	var ink: Color = cell.ink
	line.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var a := 1.0 if cell.strong else 0.5
		var x := 0.0
		if cell.held:
			line.draw_rect(Rect2(-6, -2, w + 12.0, GRADE_ROW - 4.0), Color(UiTheme.WAX, 0.1))
			line.draw_circle(Vector2(5, 14.0), 4.5, UiTheme.WAX)
			x = 16.0
		UiTheme.draw_text(line, display, Vector2(x, 3.0), cell.title, 19, Color(ink, a))
		UiTheme.draw_text(line, display, Vector2(0, -2.0), Proficiency.grade_name(cell.grade), 26, Color(ink, a), 0, w, HORIZONTAL_ALIGNMENT_RIGHT)
		var track := Rect2(0.0, 31.0, w, 4.0)
		line.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		var frac := 1.0 if step.y == 0 else float(step.x) / step.y
		line.draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), Color(ink, 0.85 * a)))
	return line


func _section(text: String, w: float) -> Label:
	var l := UiTheme.label(text, 15, UiTheme.PARCHMENT_MUTED)
	l.add_theme_font_override("font", UiTheme.italic_font())
	l.custom_minimum_size = Vector2(w, 32)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## One of the three orders, stacked at the foot of the first column.
func _order(slot: int, title: String, hotkey: String, tip: String, action: Callable) -> ActionButton:
	var b := ActionButton.new()
	b.paper = true
	b.h = 44.0
	b.title = title
	b.hotkey = hotkey
	b.tooltip_text = tip
	b.position = Vector2(0, slot * 44.0)
	b.pressed.connect(action)
	_orders.add_child(b)
	return b


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ---------------------------------------------------------------- what is written on the sheet itself

func _draw_sheet() -> void:
	UiTheme.draw_parchment(_sheet, Rect2(Vector2.ZERO, _sheet.size))
	var c := _selected
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var ink := UiTheme.PARCHMENT_INK
	var muted := UiTheme.PARCHMENT_MUTED
	if c == null:
		UiTheme.draw_text(_sheet, italic, Vector2(0, 420.0), "Nobody is left in the company.", 24, muted, 0, _sheet.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		return
	var p := c.progress
	# Faint lines between the columns.
	for x: float in [C2_X - 15.0, C3_X - 15.0]:
		_sheet.draw_line(Vector2(x, TOP + 4.0), Vector2(x, _sheet.size.y - PAD), Color(ink, 0.16), 1.0)

	# Column 1: the card. A framed portrait on the right; name, level and health on the left.
	var frame := Rect2(C1_X + C1_W - CARD_H, TOP, CARD_H, CARD_H)
	_sheet.draw_rect(Rect2(frame.position + Vector2(3, 4), frame.size), Color(0, 0, 0, 0.25))
	_sheet.draw_polygon(PackedVector2Array([frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]),
		PackedColorArray([UiTheme.PORTRAIT_BACK, UiTheme.PORTRAIT_BACK, UiTheme.PORTRAIT_BACK_LOW, UiTheme.PORTRAIT_BACK_LOW]))
	_draw_figure(c, frame.grow(-2.0), frame.position + Vector2(CARD_H * 0.5, 74.0), 430.0, Color(0.62, 0.5, 0.5) if c.injured else Color.WHITE)
	_sheet.draw_rect(frame, ink, false, 2.0)
	_sheet.draw_rect(frame.grow(-4.0), Color(UiTheme.GOLD_DEEP, 0.8), false, 1.0)
	var tw := C1_W - CARD_H - 16.0
	var name_size := 42
	while name_size > 24 and display.get_string_size(c.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > tw:
		name_size -= 1
	UiTheme.draw_text(_sheet, display, Vector2(C1_X, TOP - 6.0), c.display_name(), name_size, ink)
	UiTheme.draw_text(_sheet, italic, Vector2(C1_X, TOP + 44.0), _place_text(c), 15, muted, 0, tw)
	# Level, with the way to the next.
	UiTheme.draw_text(_sheet, display, Vector2(C1_X, TOP + 76.0), "Level", 17, muted)
	UiTheme.draw_text(_sheet, display, Vector2(C1_X, TOP + 68.0), str(c.level()), 28, ink, 0, tw, HORIZONTAL_ALIGNMENT_RIGHT)
	var need := Levels.xp_to_next(c.level())
	_gauge(Rect2(C1_X, TOP + 106.0, tw, 5.0), float(p.xp) / need if need > 0 else 1.0, UiTheme.GOLD_DEEP)
	UiTheme.draw_text(_sheet, italic, Vector2(C1_X, TOP + 114.0), "%d of %d to the next" % [p.xp, need] if need > 0 else "as high as a level goes",
		13, muted, 0, tw, HORIZONTAL_ALIGNMENT_RIGHT)
	# Health.
	UiTheme.draw_text(_sheet, display, Vector2(C1_X, TOP + 150.0), "Health", 17, muted)
	UiTheme.draw_text(_sheet, display, Vector2(C1_X, TOP + 142.0), "%d / %d" % [c.hp, c.max_hp()], 28, ink, 0, tw, HORIZONTAL_ALIGNMENT_RIGHT)
	_gauge(Rect2(C1_X, TOP + 180.0, tw, 6.0), float(c.hp) / maxf(1.0, c.max_hp()), UiTheme.HP if c.hp * 3 >= c.max_hp() else UiTheme.INJURED)

	# Column 1: the numbers, then how readily each grows.
	var values := p.stats()
	values[Stat.BLD] = c.data.build
	StatTable.head(_sheet, Vector2(C1_X, STATS_Y), C1_W, "STATS")
	# Health here is the most they can have; what they have now is on the card above.
	StatTable.draw_values(_sheet, Vector2(C1_X, STATS_Y + StatTable.HEAD_H), C1_W, 2, values)
	StatTable.head(_sheet, Vector2(C1_X, GROWTH_Y), C1_W, "GROWTH", "the chance to rise with a level")
	StatTable.draw_growth(_sheet, Vector2(C1_X, GROWTH_Y + StatTable.HEAD_H), C1_W, 2, c.data)
	StatTable.head(_sheet, Vector2(C1_X, ORDERS_Y), C1_W, "IN THE LINE")

	# Column 2.
	var heavy := c.weapon().weight - c.data.build
	StatTable.head(_sheet, Vector2(C2_X, TOP), C2_W, "IN HAND")
	var attack := "Attack %d" % c.attack()
	UiTheme.draw_text(_sheet, display, Vector2(C2_X, TOP - 5.0), attack, 22, UiTheme.WAX.darkened(0.2) if heavy > 0 else ink, 0, C2_W,
		HORIZONTAL_ALIGNMENT_RIGHT)
	StatTable.head(_sheet, Vector2(C2_X, _armory_y), C2_W, "THE ARMORY", "%d more  ·  click one to take it in hand" % (run.inventory.weapons.size() - 1))
	StatTable.head(_sheet, Vector2(C2_X, GRADES_Y), C2_W, "SKILL", "weapon and magic grades")

	# Column 3.
	StatTable.head(_sheet, Vector2(C3_X, TOP), C3_W, "COMBAT ARTS AND SPELLS",
		"%d of %d carried" % [p.equipped_arts.size(), BattleConfig.MAX_EQUIPPED_ARTS])
	_sheet.draw_line(Vector2(C3_X, FOOT_Y - 8.0), Vector2(C3_X + C3_W, FOOT_Y - 8.0), Color(ink, 0.45), 1.0)


## "At the front of the line", in a few words.
func _place_text(c: RunCompanion) -> String:
	if c.injured:
		var left := c.days_left(run.day)
		return "Infirmary: %s." % ("up tomorrow" if left <= 1 else "%d more days" % left)
	if not run.is_fielded(c):
		return "On the bench."
	var index := run.lineup.find(c)
	if run.lineup.size() == 1:
		return "Alone in the line."
	if index == run.lineup.size() - 1:
		return "Front of the line."
	if index == 0:
		return "Rear of the line."
	return "Place %d of %d in the line." % [index + 1, run.lineup.size()]


## A thin line filled to `frac`.
func _gauge(r: Rect2, frac: float, fill: Color) -> void:
	_sheet.draw_rect(r, Color(UiTheme.PARCHMENT_INK, 0.16))
	_sheet.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), fill)


## The companion's cut-out with the face at `face`, as much of it as falls inside `clip`.
func _draw_figure(c: RunCompanion, clip: Rect2, face: Vector2, art_h: float, tint: Color) -> void:
	var tex := c.data.portrait
	if tex == null:
		return
	var ts := tex.get_size()
	var h := art_h * c.data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var full := Rect2(face - c.data.portrait_focus * art, art)
	var shown := full.intersection(clip)
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return
	_sheet.draw_texture_rect_region(tex, shown, Rect2((shown.position - full.position) / art * ts, shown.size / art * ts), tint)


# ---------------------------------------------------------------- building

func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.BARRACKS
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var marks := Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks.bind(marks))
	add_child(marks)

	var title := UiTheme.label("THE BARRACKS", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	var hint := UiTheme.label("The company, and everything about whoever you choose. Carry someone to another place, or to the bench.", 20,
		UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 78)
	add_child(hint)

	# The bench takes anyone set down on it, not only on someone already sitting there.
	var bench_area := Control.new()
	bench_area.position = Vector2(LIST_X - 6.0, BENCH_Y - 6.0)
	bench_area.size = Vector2(MusterRow.W + 12.0, LIST_END - BENCH_Y + 6.0)
	bench_area.mouse_filter = Control.MOUSE_FILTER_PASS
	bench_area.set_drag_forwarding(Callable(), _can_bench, func(_at: Vector2, data: Variant) -> void:
		place((data as Dictionary)["companion"], -1))
	add_child(bench_area)
	_rows.position = Vector2(LIST_X, LIST_Y)
	_rows.size = Vector2(MusterRow.W, LIST_END - LIST_Y)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)

	_sheet.position = SHEET.position
	_sheet.size = SHEET.size
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)
	_orders.position = Vector2(C1_X - 6.0, ORDERS_Y + StatTable.HEAD_H - 2.0)
	_orders.size = Vector2(C1_W, 132)
	_orders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_orders)
	_held.position = Vector2(C2_X, TOP + StatTable.HEAD_H)
	_held.size = Vector2(C2_W, 60)
	_held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_held)
	_armory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(_armory_scroll)
	_armory.add_theme_constant_override("separation", 0)
	_armory_scroll.add_child(_armory)
	_grades.position = Vector2(C2_X, GRADES_Y + StatTable.HEAD_H + 2.0)
	_grades.size = Vector2(C2_W, GRADE_ROW * 4.0)
	_grades.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_grades)
	_arts_scroll.position = Vector2(C3_X, TOP + StatTable.HEAD_H)
	_arts_scroll.size = Vector2(C3_W, FOOT_Y - 18.0 - _arts_scroll.position.y)
	_arts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(_arts_scroll)
	_arts.add_theme_constant_override("separation", 0)
	_arts_scroll.add_child(_arts)
	_foot = UiTheme.label(DEFAULT_FOOT, 17, UiTheme.PARCHMENT_MUTED)
	_foot.add_theme_font_override("font", UiTheme.italic_font())
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_foot.position = Vector2(C3_X, FOOT_Y + 4.0)
	_foot.size = Vector2(C3_W, FOOT_H - 10.0)
	_sheet.add_child(_foot)
	_foot_facts.position = Vector2(C3_X, FOOT_Y)
	_foot_facts.size = Vector2(C3_W, FOOT_H)
	_foot_facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_facts.draw.connect(_draw_foot)
	_sheet.add_child(_foot_facts)

	var back := Button.new()
	back.text = "Leave"
	back.tooltip_text = "Back to the city.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)


func _can_bench(_at: Vector2, data: Variant) -> bool:
	return run != null and run.can_change_party() and data is Dictionary \
		and (data as Dictionary).get("companion") is RunCompanion and run.is_fielded((data as Dictionary)["companion"])


## Chalk on the wall beside the list: which part is the line, which end of it is which, and the bench.
func _draw_marks(marks: Control) -> void:
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var chalk := Color(UiTheme.TEXT, 0.45)
	UiTheme.draw_text(marks, display, Vector2(LIST_X + 4.0, LIST_Y), "THE LINE", 17, UiTheme.MUTED, 5)
	UiTheme.draw_text(marks, italic, Vector2(LIST_X, LIST_Y + 1.0), "the rear", 17, chalk, 4, MusterRow.W - 4.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var y := LIST_Y + 34.0 + LINE_STEP * RunConfig.MAX_FIELDED + 1.0
	UiTheme.draw_text(marks, italic, Vector2(LIST_X, y), "the front, nearest the enemy", 17, chalk, 4, MusterRow.W - 4.0, HORIZONTAL_ALIGNMENT_RIGHT)
	UiTheme.draw_text(marks, display, Vector2(LIST_X + 4.0, BENCH_Y), "ON THE BENCH", 17, UiTheme.MUTED, 5)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_P:
			close()
		KEY_UP:
			select_next(-1)
		KEY_DOWN:
			select_next(1)
		KEY_LEFT:
			move(-1)
		KEY_RIGHT:
			move(1)
		KEY_F:
			toggle_fielded()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
