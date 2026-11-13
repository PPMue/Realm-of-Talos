class_name ArtsScreen
extends Control
## The drill book, kept in the barracks: who knows what. The company is listed down the left, the
## one chosen stands beside an open book. Its left page is their grades in every weapon and both
## schools of magic, each with a line for the way to the next grade; its right page is every combat
## art they know (click one to carry it into battle or leave it behind; three are carried) and every
## spell with its uses left. What the art or spell under the pointer does is written at the foot.
## Reached from the barracks. Changes go straight into the party's CompanionProgress.

signal closed

const LIST_X := 60.0
const LIST_Y := 156.0
const LIST_W := 300.0
const ROW_H := 78.0
## The chosen companion, standing between the list and the book.
const FIGURE_FACE := Vector2(580, 300)
const FIGURE_ART := 780.0
const FLOOR_Y := 1010.0
const BOOK := Rect2(810, 110, 1070, 946)
const PAD := 36.0
## Where the book folds, and the pages either side of it (book coordinates).
const FOLD := 466.0
const LEFT_W := FOLD - PAD * 2.0 + 10.0
const RIGHT_X := FOLD + 34.0
const RIGHT_W := BOOK.size.x - RIGHT_X - PAD
const GRADE_H := 58.0
const FOOT_H := 150.0
const DEFAULT_FOOT := "Point at an art or a spell to read it. Click an art to carry it into battle, or to leave it behind."

var _party: Array[CompanionProgress] = []
var _current: CompanionProgress
var _rows: Dictionary = {}          # CompanionProgress -> Control
var _row_box := Control.new()
var _scene := Control.new()
var _book := Control.new()
var _grades := Control.new()
var _carried: Label
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _foot: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(party: Array[CompanionProgress]) -> void:
	_party = party
	for child in _row_box.get_children():
		_row_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	# A large company packs its rows closer.
	var step := minf(ROW_H, 880.0 / maxi(1, party.size()))
	for i in party.size():
		var row := _make_row(party[i], step - 8.0)
		row.position = Vector2(0, i * step)
		_row_box.add_child(row)
		_rows[party[i]] = row
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	select(party[0] if _current == null or not party.has(_current) else _current)


func close() -> void:
	visible = false
	closed.emit()


func select(p: CompanionProgress) -> void:
	_current = p
	_refresh()


## Carries the art into battle if it is known and there is room, or leaves it behind if it is carried.
func toggle(art: CombatArtData) -> void:
	if _current == null:
		return
	if _current.is_equipped(art):
		_current.unequip(art)
	else:
		_current.equip(art)
	_refresh()


func _refresh() -> void:
	for p: CompanionProgress in _rows:
		(_rows[p] as Control).queue_redraw()
	_scene.queue_redraw()
	_book.queue_redraw()
	var p := _current
	var w := p.weapon

	# Left page: one line for each weapon, then the two schools.
	for child in _grades.get_children():
		_grades.remove_child(child)
		child.queue_free()
	var y := 0.0
	for t: int in WeaponData.WeaponType.values():
		var step := p.progress_to_next(t)
		var g := p.grade(t)
		var held := w != null and w.weapon_type == t
		var tip := "%s %s: %d points.%s" % [WeaponData.type_name(t), Proficiency.grade_name(g), p.points_in(t),
			"" if step.y == 0 else " %d more to reach %s." % [step.y - step.x, Proficiency.grade_name(g + 1)]]
		_add_grade(y, WeaponData.type_name(t), g, step, UiTheme.PARCHMENT_INK, held, held or p.points_in(t) > 0, "in hand" if held else "", tip)
		y += GRADE_H
	y += 34.0
	var schools := p.spell_schools()
	for s: int in SpellData.School.values():
		var step := p.magic_progress_to_next(s)
		var g := p.magic_grade(s)
		var casts := schools.has(s)
		var tip := "%s %s: %d points. Every cast gives %d; a grade reached teaches a new spell.%s" % [SpellData.school_name(s),
			Proficiency.grade_name(g), p.magic_points_in(s), BattleConfig.MAGIC_POINTS_PER_CAST,
			"" if casts else " Only someone who knows a spell of this school can cast it and raise it."]
		_add_grade(y, SpellData.school_name(s), g, step, UiTheme.school_color(s).darkened(0.55), false, casts or p.magic_points_in(s) > 0,
			"" if casts else "knows no spell", tip)
		y += GRADE_H

	# Right page: arts, then spells.
	_carried.text = "%d of %d" % [p.equipped_arts.size(), BattleConfig.MAX_EQUIPPED_ARTS]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var arts := _sorted_arts(p)
	if arts.is_empty():
		_list.add_child(_section("No combat arts yet. Every weapon grade reached teaches one."))
	for art in arts:
		_list.add_child(_art_row(p, art))
	if not p.known_spells.is_empty():
		_list.add_child(_section("Spells  ·  every known spell can be cast; uses come back with a rest at the inn"))
		for sp in p.known_spells:
			_list.add_child(_spell_row(p, sp))
	_foot.text = DEFAULT_FOOT


func _art_row(p: CompanionProgress, art: CombatArtData) -> RowButton:
	var row := RowButton.new(RIGHT_W - 14.0, 58.0)
	row.paper = true
	row.title = art.display_name
	var sits := "the next action" if art.recovery == 1 else "%d actions" % art.recovery
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
		row.detail = "needs a %s in hand" % art.type_name().to_lower() if wrong else "left behind"
	row.pressed.connect(toggle.bind(art))
	var about := "%s\n%s Then sits out %s.%s" % [art.description, art.effect_summary(), sits,
		"\nOnly usable with a %s in hand." % art.type_name().to_lower() if wrong else ""]
	_read_on_hover(row, about)
	return row


func _spell_row(p: CompanionProgress, sp: SpellData) -> RowButton:
	var row := RowButton.new(RIGHT_W - 14.0, 58.0)
	row.paper = true
	row.mouse_default_cursor_shape = Control.CURSOR_ARROW
	row.title = sp.display_name
	row.sub = "%s  ·  tier %s%s" % [sp.school_text().to_lower(), CombatArtData.tier_numeral(sp.tier),
		"  ·  signature" if sp == p.data.signature_spell else ""]
	row.detail = "%d of %d uses" % [p.uses_left(sp), sp.uses]
	_read_on_hover(row, "%s\n%s" % [sp.description, sp.effect_summary()])
	return row


## While the pointer is on `row`, the foot of the page reads `about`.
func _read_on_hover(row: Control, about: String) -> void:
	row.mouse_entered.connect(func() -> void: _foot.text = about)
	row.mouse_exited.connect(func() -> void:
		if _foot.text == about:
			_foot.text = DEFAULT_FOOT)


func _section(text: String) -> Label:
	var l := UiTheme.label(text, 15, UiTheme.PARCHMENT_MUTED)
	l.add_theme_font_override("font", UiTheme.italic_font())
	l.custom_minimum_size = Vector2(RIGHT_W - 14.0, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


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


## One grade on the left page: the name, the grade, and a line for the way to the next one.
## `ink` colours it (a school's own colour for magic); `strong` is false for a skill never used.
func _add_grade(y: float, title: String, g: int, step: Vector2i, ink: Color, held: bool, strong: bool, note: String, tip: String) -> void:
	var line := Control.new()
	line.position = Vector2(0, y)
	line.size = Vector2(LEFT_W, GRADE_H - 4.0)
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.tooltip_text = tip
	line.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		var w := line.size.x
		var h := line.size.y
		var a := 1.0 if strong else 0.5
		if held:
			line.draw_rect(Rect2(-8, 0, w + 16.0, h), Color(UiTheme.WAX, 0.1))
			line.draw_circle(Vector2(4, h * 0.5 - 4.0), 5.0, UiTheme.WAX)
		line.draw_line(Vector2(0, h + 1.0), Vector2(w, h + 1.0), Color(UiTheme.PARCHMENT_INK, 0.16), 1.0)
		var x := 18.0 if held else 0.0
		UiTheme.draw_text(line, display, Vector2(x, 6.0), title, 22, Color(ink, a))
		if note != "":
			UiTheme.draw_text(line, italic, Vector2(x, 32.0), note, 14, Color(UiTheme.PARCHMENT_MUTED, 0.95))
		UiTheme.draw_text(line, display, Vector2(150.0, 2.0), Proficiency.grade_name(g), 30, Color(ink, a), 0, 50.0, HORIZONTAL_ALIGNMENT_CENTER)
		var track := Rect2(214.0, 18.0, w - 214.0, 5.0)
		line.draw_rect(track, Color(UiTheme.PARCHMENT_INK, 0.13))
		var frac := 1.0 if step.y == 0 else float(step.x) / step.y
		line.draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), Color(ink, 0.85 * a))
		var way := "as high as it goes" if step.y == 0 else "%d of %d to %s" % [step.x, step.y, Proficiency.grade_name(g + 1)]
		UiTheme.draw_text(line, italic, Vector2(214.0, 28.0), way, 14, Color(UiTheme.PARCHMENT_MUTED, 0.95), 0, track.size.x,
			HORIZONTAL_ALIGNMENT_RIGHT))
	_grades.add_child(line)


## One of the company in the list on the left.
func _make_row(p: CompanionProgress, h: float) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST_W, h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := {"hover": false}
	row.mouse_entered.connect(func() -> void:
		state.hover = true
		row.queue_redraw())
	row.mouse_exited.connect(func() -> void:
		state.hover = false
		row.queue_redraw())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select(p))
	row.draw.connect(func() -> void:
		var chosen := p == _current
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var r := minf(30.0, h * 0.5 - 4.0)
		var c := Vector2(r + 10.0, h * 0.5)
		if chosen:
			var clear := Color(UiTheme.GOLD, 0.0)
			row.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(LIST_W, 0), Vector2(LIST_W, h), Vector2(0, h)]),
				PackedColorArray([Color(UiTheme.GOLD, 0.2), clear, clear, Color(UiTheme.GOLD, 0.2)]))
			row.draw_rect(Rect2(0, 0, 3, h), UiTheme.GOLD)
		row.draw_circle(c + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
		row.draw_circle(c, r + 3.0, UiTheme.INK)
		UiIcons.portrait(row, c, r, p.data.portrait, p.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / p.data.figure_scale,
			Color.WHITE if chosen or state.hover else Color(0.72, 0.7, 0.68))
		row.draw_arc(c, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if chosen or state.hover else UiTheme.GOLD_DEEP, 2.0, true)
		var x := c.x + r + 16.0
		var ink := ActionButton.LIT_INK if chosen or state.hover else UiTheme.TEXT
		UiTheme.draw_text(row, display, Vector2(x, h * 0.5 - 26.0), p.data.display_name, 24, ink, 4)
		var w := p.weapon
		var small := ""
		if w != null:
			small = "%s %s  ·  %d art%s" % [WeaponData.type_name(w.weapon_type), Proficiency.grade_name(p.grade(w.weapon_type)),
				p.known_arts.size(), "" if p.known_arts.size() == 1 else "s"]
		for s in p.spell_schools():
			small += "  ·  %s %s" % ["Black" if s == SpellData.School.BLACK else "White", Proficiency.grade_name(p.magic_grade(s))]
		UiTheme.draw_text(row, body, Vector2(x, h * 0.5 + 4.0), small, 16, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45), 4))
	return row


## Behind the book: lamplight on the wall and the chosen companion standing in it.
func _draw_scene() -> void:
	var p := _current
	if p == null or p.data.portrait == null:
		return
	var lit := Color("6a5a45")
	for i in 14:
		var f := 1.0 - i / 14.0
		var pts := PackedVector2Array()
		for k in 36:
			pts.append(Vector2(FIGURE_FACE.x, 560.0) + Vector2.from_angle(TAU * k / 36.0) * Vector2(330.0, 470.0) * f)
		_scene.draw_colored_polygon(pts, Color(lit, 0.075))
	var tex := p.data.portrait
	var ts := tex.get_size()
	var h := FIGURE_ART * p.data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var top_left := FIGURE_FACE - p.data.portrait_focus * art
	# Someone short stands on the floor.
	top_left.y = maxf(top_left.y, FLOOR_Y - art.y)
	var shown := clampf((FLOOR_Y - top_left.y) / art.y, 0.0, 1.0)
	_scene.draw_texture_rect_region(tex, Rect2(top_left, Vector2(art.x, art.y * shown)), Rect2(0, 0, ts.x, ts.y * shown))


## The open book: two pages, a fold between them, and what is written on the left one besides the
## grade lines.
func _draw_book() -> void:
	var r := Rect2(Vector2.ZERO, _book.size)
	UiTheme.draw_parchment(_book, r)
	# The fold: a shadow down the middle.
	var dark := Color(UiTheme.PARCHMENT_INK, 0.28)
	var clear := Color(UiTheme.PARCHMENT_INK, 0.0)
	_book.draw_polygon(PackedVector2Array([Vector2(FOLD - 26.0, 4), Vector2(FOLD, 4), Vector2(FOLD, r.size.y - 4.0), Vector2(FOLD - 26.0, r.size.y - 4.0)]),
		PackedColorArray([clear, dark, dark, clear]))
	_book.draw_polygon(PackedVector2Array([Vector2(FOLD, 4), Vector2(FOLD + 26.0, 4), Vector2(FOLD + 26.0, r.size.y - 4.0), Vector2(FOLD, r.size.y - 4.0)]),
		PackedColorArray([dark, clear, clear, dark]))
	var p := _current
	if p == null:
		return
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	var ink := UiTheme.PARCHMENT_INK
	var muted := UiTheme.PARCHMENT_MUTED
	var line := Color(ink, 0.45)
	# Left page.
	UiTheme.draw_text(_book, display, Vector2(PAD, 22.0), p.data.display_name, 50, ink)
	UiTheme.draw_text(_book, display, Vector2(PAD, 46.0), "Level %d" % p.level, 21, muted, 0, LEFT_W, HORIZONTAL_ALIGNMENT_RIGHT)
	_book.draw_line(Vector2(PAD, 96.0), Vector2(PAD + LEFT_W, 96.0), line, 1.0)
	var w := p.weapon
	UiTheme.draw_text(_book, body, Vector2(PAD, 108.0), "In hand: %s" % (w.display_name if w != null else "nothing"), 18, ink)
	if w != null:
		UiTheme.draw_text(_book, italic, Vector2(PAD, 132.0), "%s, needs grade %s" % [WeaponData.type_name(w.weapon_type).to_lower(),
			Proficiency.grade_name(w.required_grade)], 15, muted)
	UiTheme.draw_text(_book, italic, Vector2(PAD, 172.0), "Weapons", 15, muted)
	UiTheme.draw_text(_book, italic, Vector2(PAD, 172.0 + 26.0 + GRADE_H * 5.0 + 6.0), "Magic", 15, muted)
	var note_y := 172.0 + 26.0 + GRADE_H * 7.0 + 34.0 + 22.0
	UiTheme.draw_rule(_book, Vector2(PAD + LEFT_W * 0.5, note_y), LEFT_W, Color(ink, 0.5))
	_book.draw_multiline_string(italic, Vector2(PAD, note_y + 20.0 + italic.get_ascent(15)),
		"Every grade reached teaches an art of that weapon, or a spell of that school, chosen by chance. Fighting with a weapon raises its grade; casting raises a school's.",
		HORIZONTAL_ALIGNMENT_LEFT, LEFT_W, 15, 5, Color(muted, 0.95))
	# Right page.
	UiTheme.draw_text(_book, display, Vector2(RIGHT_X, 34.0), "CARRIED INTO BATTLE", 18, muted)
	_book.draw_line(Vector2(RIGHT_X, 70.0), Vector2(RIGHT_X + RIGHT_W, 70.0), line, 1.0)
	_book.draw_line(Vector2(RIGHT_X, r.size.y - FOOT_H - 8.0), Vector2(RIGHT_X + RIGHT_W, r.size.y - FOOT_H - 8.0), line, 1.0)


func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.BARRACKS
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.draw.connect(_draw_scene)
	add_child(_scene)

	var title := UiTheme.label("ARTS AND MAGIC", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	var hint := UiTheme.label("The drill book: what each of the company has learned, and what they carry into battle.", 20,
		UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 78)
	add_child(hint)

	_row_box.position = Vector2(LIST_X, LIST_Y)
	_row_box.size = Vector2(LIST_W, 880)
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row_box)

	_book.position = BOOK.position
	_book.size = BOOK.size
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.draw.connect(_draw_book)
	add_child(_book)
	_grades.position = Vector2(PAD, 172.0 + 26.0)
	_grades.size = Vector2(LEFT_W, GRADE_H * 7.0 + 34.0)
	_grades.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_grades)
	_carried = UiTheme.label("", 26, UiTheme.PARCHMENT_INK, true)
	_carried.position = Vector2(RIGHT_X, 26.0)
	_carried.size = Vector2(RIGHT_W, 34)
	_carried.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_book.add_child(_carried)
	_scroll.position = Vector2(RIGHT_X, 80.0)
	_scroll.size = Vector2(RIGHT_W, BOOK.size.y - 80.0 - FOOT_H - 18.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book.add_child(_scroll)
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)
	_foot = UiTheme.label(DEFAULT_FOOT, 17, UiTheme.PARCHMENT_INK)
	_foot.add_theme_font_override("font", UiTheme.italic_font())
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_foot.position = Vector2(RIGHT_X, BOOK.size.y - FOOT_H + 4.0)
	_foot.size = Vector2(RIGHT_W, FOOT_H - 30.0)
	_book.add_child(_foot)

	var back := Button.new()
	back.text = "Back"
	back.tooltip_text = "Back to the barracks.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
