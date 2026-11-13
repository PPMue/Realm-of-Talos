class_name ArtsScreen
extends Control
## Between battles: each companion's weapon grades and known combat arts, and which (up to three)
## are equipped. Reached from the party screen. Changes go straight into the party's
## CompanionProgress, so the next battle uses them.

signal closed

const TAB_SIZE := Vector2(400, 150)
const DETAIL_X := 540.0
const CELL_SIZE := Vector2(250, 96)

var _party: Array[CompanionProgress] = []
var _current: CompanionProgress
var _tabs: Dictionary = {}          # CompanionProgress -> Control
var _tab_box := VBoxContainer.new()
var _name: Label
var _weapon: Label
var _grades := HBoxContainer.new()
var _slots: Label
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(party: Array[CompanionProgress]) -> void:
	_party = party
	for child in _tab_box.get_children():
		_tab_box.remove_child(child)
		child.queue_free()
	_tabs.clear()
	for p in party:
		var tab := _make_tab(p)
		_tab_box.add_child(tab)
		_tabs[p] = tab
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


## Equips the art if it is known and a slot is free, or unequips it if it is equipped.
func toggle(art: CombatArtData) -> void:
	if _current == null:
		return
	if _current.is_equipped(art):
		_current.unequip(art)
	else:
		_current.equip(art)
	_refresh()


func _refresh() -> void:
	for p: CompanionProgress in _tabs:
		_style_tab(_tabs[p], p)
	var p := _current
	var w := p.weapon
	_name.text = p.data.display_name.to_upper()
	_weapon.text = "%s  ·  %s weapon, needs grade %s" % [w.display_name, WeaponData.type_name(w.weapon_type).to_lower(),
		Proficiency.grade_name(w.required_grade)] if w != null else "No weapon"

	for child in _grades.get_children():
		_grades.remove_child(child)
		child.queue_free()
	for t: int in WeaponData.WeaponType.values():
		_grades.add_child(_make_grade_cell(p, t, w != null and w.weapon_type == t))

	_slots.text = "EQUIPPED  %d / %d" % [p.equipped_arts.size(), BattleConfig.MAX_EQUIPPED_ARTS]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for art in _sorted_arts(p):
		var card := ArtCard.new()
		card.art = art
		card.equipped_slot = p.equipped_arts.find(art) + 1
		card.signature = art == p.data.signature_art
		card.can_equip = p.is_equipped(art) or p.has_free_slot()
		card.wrong_weapon = w == null or w.weapon_type != art.weapon_type
		card.pressed.connect(toggle.bind(art))
		_list.add_child(card)


## Known arts in a stable order (so cards do not jump when toggled): the weapon held first, then by tier.
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


func _make_tab(p: CompanionProgress) -> Control:
	var tab := Control.new()
	tab.custom_minimum_size = TAB_SIZE
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var art := SlantPanel.new()
	art.name = "Art"
	art.size = TAB_SIZE
	art.texture = p.data.portrait
	art.focus = p.data.portrait_focus + Vector2(-0.06, 0.0)
	art.zoom = 2.1
	art.shade = 0.92
	tab.add_child(art)
	var label := UiTheme.label(p.data.display_name.to_upper(), 40, UiTheme.TEXT, true, 8)
	label.position = Vector2(UiTheme.slant_for(60) + 20.0, TAB_SIZE.y - 64.0)
	tab.add_child(label)
	var grade := UiTheme.label("", 22, UiTheme.GOLD, true, 6)
	grade.name = "Grade"
	grade.position = Vector2(UiTheme.slant_for(110) + 18.0, 12.0)
	tab.add_child(grade)
	tab.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select(p))
	return tab


func _style_tab(tab: Control, p: CompanionProgress) -> void:
	var art: SlantPanel = tab.get_node("Art")
	var selected := p == _current
	art.border = UiTheme.GOLD if selected else UiTheme.EDGE
	art.border_width = 5.0 if selected else 2.0
	art.tint = Color.WHITE if selected else Color(0.62, 0.64, 0.72)
	var w := p.weapon
	var grade: Label = tab.get_node("Grade")
	grade.text = "%s %s   ·   %d ARTS" % [WeaponData.type_name(w.weapon_type).to_upper(), Proficiency.grade_name(p.grade(w.weapon_type)),
		p.known_arts.size()] if w != null else ""


func _make_grade_cell(p: CompanionProgress, t: WeaponData.WeaponType, held: bool) -> Control:
	var cell := SlantPanel.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.fill = Color(UiTheme.PANEL_HI if held else UiTheme.PANEL, 0.95)
	cell.border = UiTheme.GOLD if held else UiTheme.EDGE
	cell.border_width = 3.0 if held else 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var kind := UiTheme.label(WeaponData.type_name(t).to_upper(), 22, UiTheme.GOLD if held else UiTheme.MUTED, true)
	kind.position = Vector2(UiTheme.slant_for(CELL_SIZE.y) + 8.0, 8.0)
	cell.add_child(kind)
	var g := p.grade(t)
	var letter := UiTheme.label(Proficiency.grade_name(g), 50, UiTheme.TEXT, true, 6)
	letter.position = Vector2(UiTheme.slant_for(50.0) + 14.0, 32.0)
	cell.add_child(letter)
	var bar := SlantBar.new()
	bar.fill_color = UiTheme.GOLD
	bar.font_size = 14
	bar.size = Vector2(124, 22)
	bar.position = Vector2(96, 54)
	var step := p.progress_to_next(t)
	if step.y == 0:
		bar.label_prefix = "MAX  "
		bar.set_values(1, 1, false)
	else:
		bar.label_prefix = "%s  " % Proficiency.grade_name(g + 1)
		bar.set_values(step.x, step.y, false)
	cell.add_child(bar)
	cell.tooltip_text = "%s %s: %d points.%s" % [WeaponData.type_name(t), Proficiency.grade_name(g), p.points_in(t),
		"" if step.y == 0 else " %d more to reach %s." % [step.y - step.x, Proficiency.grade_name(g + 1)]]
	return cell


func _build() -> void:
	var backdrop := StageBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := UiTheme.label("COMBAT ARTS", 60, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 28)
	add_child(title)
	var hint := UiTheme.label("Every weapon grade a companion reaches teaches a new art of that weapon. Up to %d arts can be equipped; only equipped arts can be used in battle, and only with a weapon of their type." % BattleConfig.MAX_EQUIPPED_ARTS,
		19, UiTheme.MUTED)
	hint.position = Vector2(64, 104)
	add_child(hint)

	_tab_box.position = Vector2(60, 166)
	_tab_box.add_theme_constant_override("separation", 16)
	add_child(_tab_box)

	_name = UiTheme.label("", 64, UiTheme.TEXT, true, 10)
	_name.position = Vector2(DETAIL_X, 150)
	add_child(_name)
	_weapon = UiTheme.label("", 20, UiTheme.MUTED)
	_weapon.position = Vector2(DETAIL_X + 4.0, 228)
	add_child(_weapon)

	_grades.position = Vector2(DETAIL_X, 272)
	_grades.add_theme_constant_override("separation", 14)
	add_child(_grades)

	_slots = UiTheme.label("", 30, UiTheme.GOLD, true, 6)
	_slots.position = Vector2(DETAIL_X, 394)
	add_child(_slots)
	var slots_hint := UiTheme.label("Click an art to equip or unequip it. Equipped arts appear as actions in this order.", 18, UiTheme.MUTED)
	slots_hint.position = Vector2(DETAIL_X + 260.0, 402)
	add_child(slots_hint)

	_scroll.position = Vector2(DETAIL_X, 446)
	_scroll.size = Vector2(ArtCard.W + 40.0, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_list)

	var back := Button.new()
	back.text = "BACK"
	back.tooltip_text = "Back to the party."
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 32)
	back.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	back.offset_left = -400.0
	back.offset_right = -60.0
	back.offset_top = -92.0
	back.offset_bottom = -30.0
	back.pressed.connect(close)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
