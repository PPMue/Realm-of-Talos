class_name PartyScreen
extends Control
## Between battles: who is fielded and in what order, who waits in reserve, and which weapon each
## companion holds (with the reason when one cannot be held). Opens the arts screen for combat arts.
## Every change is a Run command; the screen only reads the run and redraws.

signal closed

const DETAIL_TOP := 600.0

var run: Run
var _selected: RunCompanion
var _line_row := HBoxContainer.new()
var _reserve_row := HBoxContainer.new()
var _reserve_empty: Label
var _name: Label
var _info: Label
var _level: Label
var _xp := SlantBar.new()
var _buttons := VBoxContainer.new()
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
	_cast_hint.text = "%s: click who %s heals (+%d HP)%s. Esc to cancel." % [spell.display_name.to_upper(), _caster.display_name(),
		run.heal_amount(_caster, spell), ", or anyone to heal the whole roster" if spell.targeting == SpellData.Targeting.ALL_ALLIES else ""]
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
	_cast_hint.text = "%s casts %s on %s: +%d HP. %d / %d uses left." % [caster.display_name(), spell.display_name, who, healed,
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
	_clear(_line_row)
	_clear(_reserve_row)
	_line_row.add_child(_marker("‹ BACK"))
	for i in RunConfig.MAX_FIELDED:
		if i < run.lineup.size():
			_line_row.add_child(_chip(run.lineup[i], i + 1, i == run.lineup.size() - 1))
		else:
			_line_row.add_child(_empty_slot())
	_line_row.add_child(_marker("FRONT ›"))
	for c in run.reserve():
		_reserve_row.add_child(_chip(c, 0, false))
	_reserve_empty.visible = run.reserve().is_empty()
	_refresh_detail()


func _chip(c: RunCompanion, slot: int, front: bool) -> CompanionChip:
	var chip := CompanionChip.new()
	chip.setup(c, slot, true)
	if front:
		chip.set_tag("FRONT")
	chip.set_selected(c == _selected)
	if _casting != null and (_casting.targeting == SpellData.Targeting.ALL_ALLIES or c.hp < c.max_hp()):
		chip.set_heal_preview(mini(c.max_hp(), c.hp + run.heal_amount(_caster, _casting)))
	chip.pressed.connect(select.bind(c))
	return chip


func _empty_slot() -> Control:
	var p := SlantPanel.new()
	p.custom_minimum_size = Vector2(CompanionChip.W, CompanionChip.H)
	p.fill = Color(UiTheme.INK, 0.6)
	p.border = Color(UiTheme.EDGE, 0.6)
	var l := UiTheme.label("EMPTY", 26, Color(UiTheme.MUTED, 0.6), true)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _refresh_detail() -> void:
	_clear(_buttons)
	_clear(_weapons)
	var c := _selected
	if c == null:
		_name.text = ""
		_info.text = "Nobody left in the roster."
		_level.text = ""
		return
	var fielded := run.is_fielded(c)
	var index := run.lineup.find(c)
	_name.text = c.display_name().to_upper()
	var w := c.weapon()
	var t := w.weapon_type
	var place := "Reserve: does not fight." if not fielded else ("Line %d of %d%s" % [index + 1, run.lineup.size(),
		", the front: nearest the enemies, aimed at most." if index == run.lineup.size() - 1 else "."])
	var heavy := w.weight - c.data.build
	var st := c.progress.stats()
	var stat_line: Array[String] = []
	for key in [Stat.STR, Stat.MAG, Stat.DEX, Stat.SPD, Stat.DEF, Stat.RES, Stat.CRT, Stat.LCK, Stat.STA]:
		stat_line.append("%s %d" % [key, int(st[key])])
	_info.text = "HP %d / %d     %s\nHolds %s  ·  %s grade %s%s\n%s" % [c.hp, c.max_hp(), place, w.display_name,
		WeaponData.type_name(t).to_lower(), Proficiency.grade_name(c.progress.grade(t)),
		"  ·  too heavy: -%d DEX, -%d SPD" % [heavy, heavy] if heavy > 0 else "", "   ".join(stat_line)]
	var gains: Array[String] = []
	for key in Levels.GROWTH_STATS:
		gains.append("%s %d%%%s" % [key, Levels.growth_rate(c.data, key),
			" (+%d)" % c.progress.stat_gain(key) if c.progress.stat_gain(key) > 0 else ""])
	_info.tooltip_text = "Growth rates: the chance each stat rises on a level-up (gained so far in brackets).\n" + ", ".join(gains)
	_level.text = "LV %d" % c.level()
	var need := Levels.xp_to_next(c.level())
	_xp.label_prefix = "XP " if need > 0 else "MAX LEVEL  "
	_xp.set_values(c.progress.xp if need > 0 else 1, need if need > 0 else 1, false)

	var left := _button("MOVE BACK", "←", "Move one place to the left, away from the enemies.", move.bind(-1))
	left.disabled = not fielded or index <= 0
	var right := _button("MOVE FORWARD", "→", "Move one place to the right, nearer the enemies.", move.bind(1))
	right.disabled = not fielded or index >= run.lineup.size() - 1
	var field_tip := "Take out of the line; they wait in reserve and do not fight." if fielded else \
		"Put in the line, at the front." if run.lineup.size() < RunConfig.MAX_FIELDED else \
		"The line is full (%d). Move someone to reserve first." % RunConfig.MAX_FIELDED
	var f := _button("TO RESERVE" if fielded else "FIELD", "F", field_tip, toggle_fielded)
	f.disabled = not fielded and run.lineup.size() >= RunConfig.MAX_FIELDED
	if f.disabled:
		f.detail = "LINE FULL"
	_button("ARTS AND MAGIC", "A", "See every companion's weapon and magic grades, arts and spells, and choose which arts are equipped.", open_arts)

	_weapons_head.text = "WEAPONS  ·  %d OWNED" % run.inventory.weapons.size()
	if not c.progress.known_spells.is_empty():
		_weapons_head.text = "SPELLS AND WEAPONS"
		_weapons.add_child(_section("SPELLS  ·  uses come back with Rest on a free day; healing spells can be cast here"))
		for sp in c.progress.known_spells:
			_weapons.add_child(_spell_row(c, sp))
		_weapons.add_child(_section("WEAPONS  ·  %d OWNED" % run.inventory.weapons.size()))
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
		var row := RowButton.new(1060.0, 70.0)
		row.title = d.display_name.to_upper()
		var too_heavy := d.weight - c.data.build
		row.sub = "%s  ·  Mt %d  ·  Hit %d  ·  Weight %d  ·  needs grade %s%s" % [WeaponData.type_name(d.weapon_type).to_upper(),
			d.might, d.hit, d.weight, Proficiency.grade_name(d.required_grade),
			"  ·  too heavy for %s: -%d DEX/SPD" % [c.display_name(), too_heavy] if too_heavy > 0 else ""]
		var why := run.equip_block_reason(c, item)
		if item.holder == c:
			row.active = true
			row.detail = "IN HAND"
			row.disabled = false
			row.mouse_default_cursor_shape = Control.CURSOR_ARROW
		elif why != "":
			row.disabled = true
			row.detail = ("HELD BY %s" % item.holder.display_name().to_upper()) if item.holder != null else why
		else:
			row.detail = "EQUIP"
			row.pressed.connect(equip.bind(item))
		row.tooltip_text = why if why != "" and item.holder != c else ""
		_weapons.add_child(row)


func _spell_row(c: RunCompanion, sp: SpellData) -> RowButton:
	var row := RowButton.new(1060.0, 70.0)
	row.title = sp.display_name.to_upper()
	row.sub = "%s  ·  tier %s  ·  %s" % [sp.school_text().to_upper(), CombatArtData.tier_numeral(sp.tier), sp.effect_summary()]
	row.tooltip_text = sp.description + "\n" + sp.effect_summary()
	var left := c.progress.uses_left(sp)
	var uses := "%d / %d USES" % [left, sp.uses]
	if not sp.heals:
		row.disabled = true
		row.detail = "%s  ·  IN BATTLE" % uses
		return row
	if _casting == sp and _caster == c:
		row.active = true
		row.detail = "CHOOSE WHO"
		row.pressed.connect(cancel_cast)
		return row
	var why := run.heal_block_reason(c, sp, c) if sp.targeting == SpellData.Targeting.ALL_ALLIES else ""
	if why == "" and left <= 0:
		why = "No uses left"
	if why == "" and not run.can_change_party():
		why = "Not now"
	if why != "":
		row.disabled = true
		row.detail = "%s  ·  %s" % [uses, why.trim_suffix(".").to_upper()]
		return row
	row.detail = "CAST  ·  %s" % uses
	row.detail_color = UiTheme.HEAL
	row.pressed.connect(begin_cast.bind(sp))
	return row


func _section(text: String) -> Label:
	var l := UiTheme.label(text, 18, UiTheme.GOLD, true, 4)
	l.custom_minimum_size = Vector2(1000, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _button(title: String, hotkey: String, tip: String, action: Callable) -> ActionButton:
	var b := ActionButton.new()
	b.title = title
	b.hotkey = hotkey
	b.tooltip_text = tip
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


func _marker(text: String) -> Label:
	var l := UiTheme.label(text, 22, Color(UiTheme.MUTED, 0.8), true, 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(110, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.BARRACKS
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := UiTheme.label("THE BARRACKS", 56, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 24)
	add_child(title)
	var hint := UiTheme.label("Up to %d stand in the line. Whoever is on the right stands nearest the enemy and is struck most often." % RunConfig.MAX_FIELDED,
		20, UiTheme.MUTED)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 100)
	add_child(hint)

	var line_head := UiTheme.label("THE LINE", 24, UiTheme.GOLD, true, 6)
	line_head.position = Vector2(64, 150)
	add_child(line_head)
	_line_row.position = Vector2(20, 188)
	_line_row.size = Vector2(1880, CompanionChip.H)
	_line_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_line_row.add_theme_constant_override("separation", -14)
	_line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line_row)

	var reserve_head := UiTheme.label("RESERVE", 24, UiTheme.GOLD, true, 6)
	reserve_head.position = Vector2(64, 372)
	add_child(reserve_head)
	_reserve_row.position = Vector2(150, 410)
	_reserve_row.size = Vector2(1700, CompanionChip.H)
	_reserve_row.add_theme_constant_override("separation", -14)
	_reserve_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reserve_row)
	_reserve_empty = UiTheme.label("Nobody in reserve. Hire companions at the tavern on free days; anyone beyond %d waits here." % RunConfig.MAX_FIELDED,
		19, UiTheme.MUTED)
	_reserve_empty.position = Vector2(70, 470)
	add_child(_reserve_empty)
	_cast_hint = UiTheme.label("", 20, UiTheme.HEAL, true, 6)
	_cast_hint.position = Vector2(300, 148)
	_cast_hint.size = Vector2(1560, 30)
	add_child(_cast_hint)

	var detail := SlantPanel.new()
	detail.fill = Color(UiTheme.PANEL, 0.9)
	detail.position = Vector2(40, DETAIL_TOP)
	detail.size = Vector2(1840, 440)
	add_child(detail)
	_name = UiTheme.label("", 56, UiTheme.TEXT, true, 10)
	_name.position = Vector2(190, DETAIL_TOP + 16.0)
	add_child(_name)
	_info = UiTheme.label("", 19, UiTheme.TEXT, false, 4)
	_info.position = Vector2(176, DETAIL_TOP + 86.0)
	_info.size = Vector2(560, 112)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	_level = UiTheme.label("", 30, UiTheme.GOLD, true, 6)
	_level.position = Vector2(470, DETAIL_TOP + 22.0)
	add_child(_level)
	_xp.fill_color = UiTheme.READY
	_xp.font_size = 15
	_xp.position = Vector2(470, DETAIL_TOP + 60.0)
	_xp.size = Vector2(230, 22)
	add_child(_xp)
	_buttons.position = Vector2(124, DETAIL_TOP + 208.0)
	_buttons.add_theme_constant_override("separation", 2)
	add_child(_buttons)

	_weapons_head = UiTheme.label("WEAPONS", 24, UiTheme.GOLD, true, 6)
	_weapons_head.position = Vector2(760, DETAIL_TOP + 20.0)
	add_child(_weapons_head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(740, DETAIL_TOP + 60.0)
	scroll.size = Vector2(1110, 366)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_weapons.add_theme_constant_override("separation", 8)
	scroll.add_child(_weapons)

	var back := Button.new()
	back.text = "Leave"
	back.tooltip_text = "Back to the city."
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 32)
	back.position = Vector2(1540, 22)
	back.size = Vector2(320, 62)
	back.pressed.connect(close)
	add_child(back)

	_arts_screen.visible = false
	_arts_screen.z_index = 2
	_arts_screen.closed.connect(refresh)
	add_child(_arts_screen)


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
