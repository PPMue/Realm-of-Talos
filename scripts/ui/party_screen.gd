class_name PartyScreen
extends Control
## The barracks, between battles. On the left the company stands in its line, rear to front, with the
## reserve on the bench below; a companion is moved by carrying them to another place or to the bench
## (or with the orders on their page). On the right is the muster roll, open at whoever is selected:
## what they are, what they hold, and the armory to choose a weapon from (with the reason when one
## cannot be held). A mage's healing spells can be cast from the page. Opens the arts screen.
## Every change is a Run command; the screen only reads the run and redraws.

signal closed

const LINE_X := 60.0
const LINE_Y := 150.0
const LINE_STEP := MusterFigure.W
## Where the wall, the rail and the bench's board stop: the muster roll lies over the rest.
const WALL_END := 1150.0
const BENCH_Y := 664.0
const PAGE := Rect2(1150, 110, 740, 946)
const PAGE_PAD := 34.0
## Height of a row of the stat table (the number, and under it how readily the stat grows), and how
## far that pushes down the rest of the page compared with rows of the numbers alone.
const STAT_ROW := StatTable.ROW
const STAT_DROP := 40.0

var run: Run
var _selected: RunCompanion
var _line := Control.new()
var _bench := Control.new()
var _bench_empty: Label
var _page := Control.new()
var _name: Label
var _level: Label
var _place: Label
var _holds: Label
var _stats := Control.new()
var _xp := SlantBar.new()
var _xp_label: Label
var _buttons := Control.new()
var _weapons := VBoxContainer.new()
var _weapons_head: Label
## A healing spell waiting for its target (clicking a companion casts it), and its caster.
var _casting: SpellData
var _caster: RunCompanion
var _cast_hint: Label
var _arts_screen := ArtsScreen.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run, select: RunCompanion = null) -> void:
	run = p_run
	_casting = null
	_caster = null
	_cast_hint.text = ""
	_selected = select if select != null and run.roster.has(select) else (run.lineup[-1] if not run.lineup.is_empty() else
		(run.roster[0] if not run.roster.is_empty() else null))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func close() -> void:
	if _arts_screen.visible:
		_arts_screen.close()
		return
	if _casting != null:
		cancel_cast()
		return
	visible = false
	closed.emit()


func select(c: RunCompanion) -> void:
	if _casting != null:
		cast_on(c)
		return
	_selected = c
	refresh()


## Starts aiming a healing spell of the selected companion; the next companion clicked receives it.
func begin_cast(spell: SpellData) -> void:
	if _selected == null or spell == null or not spell.heals or _selected.progress.uses_left(spell) <= 0 or not run.can_change_party():
		return
	_casting = spell
	_caster = _selected
	_cast_hint.text = "%s: choose who %s heals (+%d HP)%s. Esc to put it away." % [spell.display_name, _caster.display_name(),
		run.heal_amount(_caster, spell), ", or anyone to heal the whole company" if spell.targeting == SpellData.Targeting.ALL_ALLIES else ""]
	_cast_hint.add_theme_color_override("font_color", UiTheme.HEAL)
	refresh()


func cancel_cast() -> void:
	_casting = null
	_caster = null
	_cast_hint.text = ""
	refresh()


## Casts the spell being aimed on `target` (or on everyone, for spells that reach every ally).
func cast_on(target: RunCompanion) -> void:
	if _casting == null:
		return
	var spell := _casting
	var caster := _caster
	var why := run.heal_block_reason(caster, spell, target)
	if why != "":
		_cast_hint.text = why
		_cast_hint.add_theme_color_override("font_color", UiTheme.RECOVERING)
		return
	var healed := run.cast_heal(caster, spell, target)
	_casting = null
	_caster = null
	var who := "everyone" if spell.targeting == SpellData.Targeting.ALL_ALLIES else target.display_name()
	_cast_hint.text = "%s casts %s on %s: +%d HP. %d of %d uses left." % [caster.display_name(), spell.display_name, who, healed,
		caster.progress.uses_left(spell), spell.uses]
	_cast_hint.add_theme_color_override("font_color", UiTheme.HEAL)
	refresh()


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
	if c == null or not run.can_change_party() or _casting != null:
		return
	if index < 0:
		run.bench(c)
	elif run.is_fielded(c):
		run.move_in_line(c, index)
	elif run.lineup.size() < RunConfig.MAX_FIELDED:
		run.field(c, index)
	elif index < run.lineup.size():
		run.bench(run.lineup[index])
		run.field(c, index)
	_selected = c
	refresh()


func equip(w: OwnedWeapon) -> void:
	if _selected != null and run.equip_weapon(_selected, w):
		refresh()


func open_arts() -> void:
	var party: Array[CompanionProgress] = []
	for c in run.roster:
		party.append(c.progress)
	_arts_screen.open(party)
	if _selected != null:
		_arts_screen.select(_selected.progress)


# ---------------------------------------------------------------- drawing

func refresh() -> void:
	if run == null:
		return
	_clear(_line)
	_clear(_bench)
	for i in RunConfig.MAX_FIELDED:
		var f := _figure(run.lineup[i] if i < run.lineup.size() else null, false)
		f.position = Vector2(i * LINE_STEP, 0)
		f.dropped.connect(place.bind(i))
		_line.add_child(f)
	var reserve := run.reserve()
	for i in reserve.size():
		var f := _figure(reserve[i], true)
		f.position = Vector2(i * (MusterFigure.BENCH_W + 8.0), 0)
		f.dropped.connect(place.bind(-1))
		_bench.add_child(f)
	_bench_empty.visible = reserve.is_empty()
	_refresh_page()


func _figure(c: RunCompanion, bench: bool) -> MusterFigure:
	var f := MusterFigure.new()
	f.can_carry = run.can_change_party() and _casting == null
	f.setup(c, bench)
	if c == null:
		return f
	f.set_selected(c == _selected)
	if _casting != null and (_casting.targeting == SpellData.Targeting.ALL_ALLIES or c.hp < c.max_hp()):
		f.set_heal_preview(mini(c.max_hp(), c.hp + run.heal_amount(_caster, _casting)))
	f.pressed.connect(select.bind(c))
	return f


func _refresh_page() -> void:
	_clear(_buttons)
	_clear(_weapons)
	var c := _selected
	_stats.queue_redraw()
	if c == null:
		_name.text = ""
		_place.text = "Nobody is left in the company."
		_level.text = ""
		_holds.text = ""
		_xp.visible = false
		_xp_label.text = ""
		return
	var fielded := run.is_fielded(c)
	var index := run.lineup.find(c)
	_name.text = c.display_name()
	var w := c.weapon()
	var t := w.weapon_type
	if not fielded:
		_place.text = "On the bench. Does not fight."
	elif run.lineup.size() == 1:
		_place.text = "Stands alone in the line."
	elif index == run.lineup.size() - 1:
		_place.text = "At the front of the line: nearest the enemy, and struck most often."
	elif index == 0:
		_place.text = "At the rear of the line: struck least often."
	else:
		_place.text = "Place %d of %d in the line, counting from the rear." % [index + 1, run.lineup.size()]
	var heavy := w.weight - c.data.build
	_holds.text = "In hand: %s  ·  %s grade %s%s" % [w.display_name, WeaponData.type_name(t).to_lower(),
		Proficiency.grade_name(c.progress.grade(t)), "\nToo heavy: -%d DEX, -%d SPD" % [heavy, heavy] if heavy > 0 else ""]
	for s in c.progress.spell_schools():
		_holds.text += "  ·  %s grade %s" % [SpellData.school_name(s).to_lower(), Proficiency.grade_name(c.progress.magic_grade(s))]
	_level.text = "Level %d" % c.level()
	var need := Levels.xp_to_next(c.level())
	_xp.visible = true
	_xp.set_values(c.progress.xp if need > 0 else 1, need if need > 0 else 1, false)
	_xp_label.text = "%d of %d to the next level" % [c.progress.xp, need] if need > 0 else "as high as a level goes"

	var back := _order(0, "Step back", "←", "Move one place toward the rear, away from the enemy.", move.bind(-1))
	back.disabled = not fielded or index <= 0 or not run.can_change_party()
	var fwd := _order(1, "Step forward", "→", "Move one place toward the front, nearer the enemy.", move.bind(1))
	fwd.disabled = not fielded or index >= run.lineup.size() - 1 or not run.can_change_party()
	var field_tip := "Leave the line and wait on the bench. Those on the bench do not fight." if fielded else \
		"Join the line, at the front." if run.lineup.size() < RunConfig.MAX_FIELDED else \
		"The line is full (%d). Send someone to the bench first, or carry %s onto the one to replace." % [RunConfig.MAX_FIELDED, c.display_name()]
	var f := _order(2, "To the bench" if fielded else "Into the line", "F", field_tip, toggle_fielded)
	f.disabled = (not fielded and run.lineup.size() >= RunConfig.MAX_FIELDED) or not run.can_change_party()
	if not fielded and run.lineup.size() >= RunConfig.MAX_FIELDED:
		f.detail = "line full"
	_order(3, "Arts and magic", "A", "Everyone's weapon and magic grades, combat arts and spells; choose which arts are carried into battle.", open_arts)

	_weapons_head.text = "THE ARMORY  ·  %d WEAPONS" % run.inventory.weapons.size()
	if not c.progress.known_spells.is_empty():
		_weapons.add_child(_section("Spells  ·  uses come back with a rest at the inn; healing can be cast here"))
		for sp in c.progress.known_spells:
			_weapons.add_child(_spell_row(c, sp))
		_weapons.add_child(_section("Weapons"))
	var items := run.inventory.weapons.duplicate()
	items.sort_custom(func(a: OwnedWeapon, b: OwnedWeapon) -> bool:
		var ka := [0 if a.holder == c else 1, 0 if a.data.weapon_type == t else 1, a.data.weapon_type, -a.data.might]
		var kb := [0 if b.holder == c else 1, 0 if b.data.weapon_type == t else 1, b.data.weapon_type, -b.data.might]
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	for item: OwnedWeapon in items:
		var d := item.data
		var row := _row()
		row.title = d.display_name
		var too_heavy := d.weight - c.data.build
		row.sub = "%s  ·  Mt %d  ·  Hit %d  ·  weight %d  ·  needs grade %s%s" % [WeaponData.type_name(d.weapon_type).to_lower(),
			d.might, d.hit, d.weight, Proficiency.grade_name(d.required_grade),
			"  ·  too heavy: -%d DEX/SPD" % too_heavy if too_heavy > 0 else ""]
		var why := run.equip_block_reason(c, item)
		if item.holder == c:
			row.active = true
			row.detail = "in hand"
			row.mouse_default_cursor_shape = Control.CURSOR_ARROW
		elif why != "":
			row.disabled = true
			row.detail = ("held by %s" % item.holder.display_name()) if item.holder != null else why.trim_suffix(".")
		else:
			row.detail = "take in hand"
			row.pressed.connect(equip.bind(item))
		row.tooltip_text = why if why != "" and item.holder != c else ""
		_weapons.add_child(row)


func _spell_row(c: RunCompanion, sp: SpellData) -> RowButton:
	var row := _row()
	row.title = sp.display_name
	row.sub = "%s  ·  tier %s  ·  %s" % [sp.school_text().to_lower(), CombatArtData.tier_numeral(sp.tier), sp.effect_summary()]
	row.tooltip_text = sp.description + "\n" + sp.effect_summary()
	var left := c.progress.uses_left(sp)
	var uses := "%d of %d uses" % [left, sp.uses]
	if not sp.heals:
		row.disabled = true
		row.detail = "%s  ·  in battle only" % uses
		return row
	if _casting == sp and _caster == c:
		row.active = true
		row.detail = "choose who"
		row.pressed.connect(cancel_cast)
		return row
	var why := run.heal_block_reason(c, sp, c) if sp.targeting == SpellData.Targeting.ALL_ALLIES else ""
	if why == "" and left <= 0:
		why = "No uses left"
	if why == "" and not run.can_change_party():
		why = "Not now"
	if why != "":
		row.disabled = true
		row.detail = "%s  ·  %s" % [uses, why.trim_suffix(".").to_lower()]
		return row
	row.detail = "cast  ·  %s" % uses
	row.pressed.connect(begin_cast.bind(sp))
	return row


func _row() -> RowButton:
	var row := RowButton.new(PAGE.size.x - PAGE_PAD * 2.0 - 14.0, 58.0)
	row.paper = true
	return row


func _section(text: String) -> Label:
	var l := UiTheme.label(text, 15, UiTheme.PARCHMENT_MUTED)
	l.add_theme_font_override("font", UiTheme.italic_font())
	l.custom_minimum_size = Vector2(600, 26)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## One of the four orders on the page, in a two-by-two block.
func _order(slot: int, title: String, hotkey: String, tip: String, action: Callable) -> ActionButton:
	var b := ActionButton.new()
	b.paper = true
	b.h = 46.0
	b.title = title
	b.hotkey = hotkey
	b.tooltip_text = tip
	b.position = Vector2((slot % 2) * ActionButton.W, (slot >> 1) * 46.0)
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


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
	var hint := UiTheme.label("The company, as it will stand. Carry someone to another place, or to the bench.", 20,
		UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 78)
	add_child(hint)
	_cast_hint = UiTheme.label("", 20, UiTheme.HEAL, true, 6)
	_cast_hint.position = Vector2(64, 104)
	_cast_hint.size = Vector2(1060, 28)
	add_child(_cast_hint)

	_line.position = Vector2(LINE_X, LINE_Y)
	_line.size = Vector2(LINE_STEP * RunConfig.MAX_FIELDED, MusterFigure.H)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)
	# Timber posts between the places, in front of the figures: each stands in a bay of their own.
	var posts := Control.new()
	posts.set_anchors_preset(Control.PRESET_FULL_RECT)
	posts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	posts.draw.connect(_draw_posts.bind(posts))
	add_child(posts)

	# The bench takes anyone set down on it, not only on someone already sitting there.
	var bench_area := Control.new()
	bench_area.position = Vector2(LINE_X - 10.0, BENCH_Y - 34.0)
	bench_area.size = Vector2(LINE_STEP * RunConfig.MAX_FIELDED + 20.0, MusterFigure.BENCH_H + 48.0)
	bench_area.mouse_filter = Control.MOUSE_FILTER_PASS
	bench_area.set_drag_forwarding(Callable(), _can_bench, func(_at: Vector2, data: Variant) -> void:
		place((data as Dictionary)["companion"], -1))
	add_child(bench_area)
	var bench_head := UiTheme.label("ON THE BENCH", 17, UiTheme.MUTED, true, 5)
	bench_head.position = Vector2(LINE_X + 4.0, BENCH_Y - 30.0)
	add_child(bench_head)
	_bench.position = Vector2(LINE_X, BENCH_Y)
	_bench.size = Vector2(LINE_STEP * RunConfig.MAX_FIELDED, MusterFigure.BENCH_H)
	_bench.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bench)
	_bench_empty = UiTheme.label("Nobody is waiting. Hire at the tavern on a quiet day; anyone beyond the %d in the line sits here." % RunConfig.MAX_FIELDED,
		18, Color(UiTheme.MUTED, 0.85), false, 4)
	_bench_empty.add_theme_font_override("font", UiTheme.italic_font())
	_bench_empty.position = Vector2(LINE_X + 6.0, BENCH_Y + 20.0)
	add_child(_bench_empty)

	# The muster roll.
	_page.position = PAGE.position
	_page.size = PAGE.size
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.draw.connect(_draw_page)
	add_child(_page)
	var inner := PAGE.size.x - PAGE_PAD * 2.0
	_name = UiTheme.label("", 48, UiTheme.PARCHMENT_INK, true)
	_name.position = Vector2(PAGE_PAD, 22)
	_page.add_child(_name)
	_level = UiTheme.label("", 24, UiTheme.PARCHMENT_MUTED, true)
	_level.position = Vector2(PAGE_PAD, 34)
	_level.size = Vector2(inner, 30)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page.add_child(_level)
	_xp.fill_color = UiTheme.GOLD_DEEP
	_xp.show_text = false
	_xp.position = Vector2(PAGE_PAD + inner - 250.0, 70)
	_xp.size = Vector2(250, 8)
	_page.add_child(_xp)
	_xp_label = UiTheme.label("", 15, UiTheme.PARCHMENT_MUTED)
	_xp_label.add_theme_font_override("font", UiTheme.italic_font())
	_xp_label.position = Vector2(PAGE_PAD, 82)
	_xp_label.size = Vector2(inner, 20)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page.add_child(_xp_label)
	_place = UiTheme.label("", 19, UiTheme.PARCHMENT_INK)
	_place.add_theme_font_override("font", UiTheme.italic_font())
	_place.position = Vector2(PAGE_PAD, 122)
	_place.size = Vector2(inner, 26)
	_page.add_child(_place)
	_stats.position = Vector2(PAGE_PAD, 160)
	_stats.size = Vector2(inner, STAT_ROW * 3.0)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.draw.connect(_draw_stats)
	_page.add_child(_stats)
	_holds = UiTheme.label("", 18, UiTheme.PARCHMENT_INK)
	_holds.position = Vector2(PAGE_PAD, 250 + STAT_DROP)
	_holds.size = Vector2(inner, 50)
	_page.add_child(_holds)
	_buttons.position = Vector2(PAGE_PAD, 318 + STAT_DROP)
	_buttons.size = Vector2(inner, 92)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_buttons)
	_weapons_head = UiTheme.label("", 16, UiTheme.PARCHMENT_MUTED, true)
	_weapons_head.position = Vector2(PAGE_PAD, 432 + STAT_DROP)
	_weapons_head.size = Vector2(inner, 22)
	_weapons_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_weapons_head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PAGE_PAD, 474 + STAT_DROP)
	scroll.size = Vector2(inner, PAGE.size.y - 474.0 - STAT_DROP - 30.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroll)
	_weapons.add_theme_constant_override("separation", 0)
	scroll.add_child(_weapons)

	var back := Button.new()
	back.text = "Leave"
	back.tooltip_text = "Back to the city.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)

	_arts_screen.visible = false
	_arts_screen.z_index = 2
	_arts_screen.closed.connect(refresh)
	add_child(_arts_screen)


func _can_bench(_at: Vector2, data: Variant) -> bool:
	return run != null and run.can_change_party() and _casting == null and data is Dictionary \
		and (data as Dictionary).get("companion") is RunCompanion and run.is_fielded((data as Dictionary)["companion"])


## What the company stands against: a lime-washed stretch of wall, the muster rail in front of the
## line with which end is which under it, and the board the reserve sits behind.
func _draw_marks(marks: Control) -> void:
	var rail_y := LINE_Y + MusterFigure.PORTRAIT_H
	_lit_wall(marks, LINE_Y - 4.0, rail_y, 0.92)
	_board(marks, rail_y, MusterFigure.H - MusterFigure.PORTRAIT_H)
	var y := LINE_Y + MusterFigure.H + 22.0
	var x0 := LINE_X + 4.0
	var x1 := LINE_X + LINE_STEP * RunConfig.MAX_FIELDED - 18.0
	var chalk := Color(UiTheme.TEXT, 0.4)
	var italic := UiTheme.italic_font()
	UiTheme.draw_text(marks, italic, Vector2(x0, y - 13.0), "the rear", 19, chalk)
	var front := "the front, nearest the enemy"
	var fw := italic.get_string_size(front, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	UiTheme.draw_text(marks, italic, Vector2(x1 - fw - 26.0, y - 13.0), front, 19, chalk)
	marks.draw_line(Vector2(x0 + 90.0, y), Vector2(x1 - fw - 40.0, y), Color(UiTheme.TEXT, 0.18), 1.5)
	marks.draw_colored_polygon(PackedVector2Array([Vector2(x1 - 16.0, y - 7.0), Vector2(x1, y), Vector2(x1 - 16.0, y + 7.0)]), chalk)
	# The bench: the reserve sits behind a long board.
	var by := BENCH_Y + MusterFigure.BENCH_PORTRAIT_H
	_lit_wall(marks, BENCH_Y - 2.0, by, 0.55)
	_board(marks, by, MusterFigure.BENCH_H - MusterFigure.BENCH_PORTRAIT_H)


## A stretch of wall with lantern light on it, so a dark-haired figure still stands out.
func _lit_wall(marks: Control, top: float, bottom: float, strength: float) -> void:
	var lit := Color("6a5a45")
	var hi := Color(lit, strength)
	var mid := Color(lit, strength * 0.7)
	var off := Color(lit, 0.0)
	var fade := 60.0
	var xm := WALL_END * 0.45
	# Brightest low and in the middle, falling away to the corners and up into the beam.
	marks.draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(xm, top), Vector2(xm, top + fade), Vector2(0, top + fade)]),
		PackedColorArray([off, off, mid, Color(lit, strength * 0.35)]))
	marks.draw_polygon(PackedVector2Array([Vector2(xm, top), Vector2(WALL_END, top), Vector2(WALL_END, top + fade), Vector2(xm, top + fade)]),
		PackedColorArray([off, off, Color(lit, strength * 0.35), mid]))
	marks.draw_polygon(PackedVector2Array([Vector2(0, top + fade), Vector2(xm, top + fade), Vector2(xm, bottom), Vector2(0, bottom)]),
		PackedColorArray([Color(lit, strength * 0.35), mid, hi, Color(lit, strength * 0.5)]))
	marks.draw_polygon(PackedVector2Array([Vector2(xm, top + fade), Vector2(WALL_END, top + fade), Vector2(WALL_END, bottom), Vector2(xm, bottom)]),
		PackedColorArray([mid, Color(lit, strength * 0.35), Color(lit, strength * 0.5), hi]))


## A post at each edge of each place in the line, from the beam down to the rail.
func _draw_posts(posts: Control) -> void:
	var top := LINE_Y - 12.0
	var bottom := LINE_Y + MusterFigure.PORTRAIT_H
	for i in RunConfig.MAX_FIELDED + 1:
		var x := LINE_X + i * LINE_STEP
		posts.draw_rect(Rect2(x - 9.0, top, 18.0, bottom - top), Color(0, 0, 0, 0.18))
		posts.draw_rect(Rect2(x - 6.0, top, 12.0, bottom - top), Color("2e2117"))
		posts.draw_rect(Rect2(x - 6.0, top, 3.0, bottom - top), Color("5a4430"))
		posts.draw_rect(Rect2(x + 4.0, top, 2.0, bottom - top), Color(0, 0, 0, 0.4))


## A long wooden board across the room at `y`: the figures behind it are cut off at its top edge.
func _board(marks: Control, y: float, h: float) -> void:
	var r := Rect2(0, y, WALL_END, h)
	marks.draw_rect(Rect2(0, y - 10.0, WALL_END, 10.0), Color(0, 0, 0, 0.22))
	marks.draw_rect(r, Color("33251a"))
	UiTheme.draw_grain(marks, r, 0.2)
	marks.draw_rect(Rect2(0, y, WALL_END, 4.0), Color("6b5239"))
	marks.draw_rect(Rect2(0, y + 4.0, WALL_END, 2.0), Color(0, 0, 0, 0.3))
	marks.draw_rect(Rect2(0, y + h - 5.0, WALL_END, 5.0), Color(0, 0, 0, 0.45))
	marks.draw_rect(Rect2(0, y + h, WALL_END, 14.0), Color(0, 0, 0, 0.25))


func _draw_page() -> void:
	UiTheme.draw_parchment(_page, Rect2(Vector2.ZERO, _page.size))
	var ink := Color(UiTheme.PARCHMENT_INK, 0.45)
	var mid := _page.size.x * 0.5
	var w := _page.size.x - PAGE_PAD * 2.0
	_page.draw_line(Vector2(PAGE_PAD, 110), Vector2(PAGE_PAD + w, 110), ink, 1.0)
	_page.draw_line(Vector2(PAGE_PAD, 308 + STAT_DROP), Vector2(PAGE_PAD + w, 308 + STAT_DROP), ink, 1.0)
	UiTheme.draw_rule(_page, Vector2(mid, 464 + STAT_DROP), w, Color(UiTheme.PARCHMENT_INK, 0.5))


## The stats and how readily each grows, as a small table (see StatTable).
func _draw_stats() -> void:
	var c := _selected
	if c == null:
		return
	var values := c.progress.stats()
	values[Stat.BLD] = c.data.build
	StatTable.draw(_stats, Vector2.ZERO, _stats.size.x, 4, values, c.data, "%d / %d" % [c.hp, c.max_hp()])


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if _arts_screen.visible:
		return
	var handled := true
	match key.keycode:
		KEY_ESCAPE:
			close()
		KEY_P:
			if _casting != null:
				cancel_cast()
			else:
				close()
		KEY_LEFT:
			move(-1)
		KEY_RIGHT:
			move(1)
		KEY_F:
			toggle_fielded()
		KEY_A:
			open_arts()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
