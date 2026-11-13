class_name CompanionChip
extends Control
## A companion at a glance, outside battle: portrait, name, HP, weapon and grade, and their place in
## the line (or RESERVE). Used on the city screen and the party screen. Clicking emits `pressed`.

signal pressed

const W := 330.0
const H := 158.0

var companion: RunCompanion
var _art := SlantPanel.new()
var _tag := SlantPanel.new()
var _tag_label: Label
var _name: Label
var _level: Label
var _weapon: Label
var _hp := SlantBar.new()
var _selected := false
var _hover := false
var _clickable := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	_art.size = size
	_art.zoom = 2.0
	_art.shade = 0.97
	add_child(_art)

	_tag.size = Vector2(120, 30)
	_tag.position = Vector2(W - 140.0, 10)
	_tag.border = Color(UiTheme.INK, 0.9)
	add_child(_tag)
	_tag_label = UiTheme.label("", 18, UiTheme.INK, true)
	_tag_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.add_child(_tag_label)

	_name = UiTheme.label("", 34, UiTheme.TEXT, true, 8)
	_name.position = Vector2(_edge_x(102.0) + 16.0, 56.0)
	add_child(_name)
	_level = UiTheme.label("", 20, UiTheme.GOLD, true, 6)
	_level.position = Vector2(_edge_x(36.0) + 16.0, 10.0)
	add_child(_level)
	_weapon = UiTheme.label("", 16, UiTheme.GOLD, false, 5)
	_weapon.position = Vector2(_edge_x(122.0) + 18.0, 98.0)
	add_child(_weapon)
	_hp.size = Vector2(W - UiTheme.SLANT * H + UiTheme.slant_for(24.0) - 28.0, 24.0)
	_hp.position = Vector2(_edge_x(150.0) + 14.0, 126.0)
	_hp.label_prefix = "HP "
	_hp.font_size = 16
	add_child(_hp)

	mouse_entered.connect(func() -> void:
		_hover = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		_restyle())


## `slot`: 1-based place in the line, or 0 for reserve.
func setup(c: RunCompanion, slot: int, clickable: bool = false) -> void:
	companion = c
	_clickable = clickable
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	_art.texture = c.data.portrait
	_art.focus = c.data.portrait_focus + Vector2(0.08, 0.04)
	_name.text = c.display_name().to_upper()
	_level.text = "LV %d" % c.level()
	var w := c.weapon()
	var t := w.weapon_type
	_weapon.text = "%s  ·  %s %s" % [w.display_name, WeaponData.type_name(t).to_upper(), Proficiency.grade_name(c.progress.grade(t))]
	# Mages: the weapon type is dropped to make room for the school grade.
	if not c.progress.spell_schools().is_empty():
		_weapon.text = "%s %s" % [w.display_name, Proficiency.grade_name(c.progress.grade(t))]
		for s in c.progress.spell_schools():
			_weapon.text += "  ·  %s %s" % ["BLACK" if s == SpellData.School.BLACK else "WHITE", Proficiency.grade_name(c.progress.magic_grade(s))]
	_hp.fill_color = UiTheme.HP if c.hp * 3 >= c.max_hp() else UiTheme.INJURED
	_hp.set_values(c.hp, c.max_hp(), false)
	if slot > 0:
		_tag.fill = UiTheme.GOLD
		_tag_label.text = "LINE %d" % slot
		_tag_label.add_theme_color_override("font_color", UiTheme.INK)
		_art.tint = Color.WHITE
	else:
		_tag.fill = Color(UiTheme.INK, 0.9)
		_tag_label.text = "RESERVE"
		_tag_label.add_theme_color_override("font_color", UiTheme.MUTED)
		_art.tint = Color(0.6, 0.62, 0.7)
	var arts: Array[String] = []
	for a in c.progress.equipped_arts:
		arts.append(a.display_name)
	tooltip_text = "%s  ·  level %d  ·  HP %d / %d\n%s (Mt %d, Hit %d, weight %d)\n%s grade %s\nArts: %s" % [
		c.display_name(), c.level(), c.hp, c.max_hp(), w.display_name, w.might, w.hit, w.weight,
		WeaponData.type_name(t), Proficiency.grade_name(c.progress.grade(t)), ", ".join(arts) if not arts.is_empty() else "none"]
	if not c.progress.known_spells.is_empty():
		var spells: Array[String] = []
		for sp in c.progress.known_spells:
			spells.append("%s %d/%d" % [sp.display_name, c.progress.uses_left(sp), sp.uses])
		for s in c.progress.spell_schools():
			tooltip_text += "\n%s grade %s" % [SpellData.school_name(s), Proficiency.grade_name(c.progress.magic_grade(s))]
		tooltip_text += "\nSpells: " + ", ".join(spells)
	_restyle()


## The tag text, e.g. "FRONT" for the rightmost of the line.
func set_tag(text: String) -> void:
	_tag_label.text = text


## While a heal is being aimed between battles: the HP it would reach, on the tag and the bar.
func set_heal_preview(hp_after: int) -> void:
	_tag.fill = UiTheme.HEAL
	_tag.size.x = 150.0
	_tag.position.x = W - 170.0
	_tag_label.add_theme_color_override("font_color", UiTheme.INK)
	_tag_label.text = "HP %d → %d" % [companion.hp, hp_after]
	_hp.set_heal_preview(hp_after)
	_art.border = UiTheme.HEAL
	_art.border_width = 4.0


func set_selected(v: bool) -> void:
	_selected = v
	_restyle()


func _restyle() -> void:
	var lit := _hover and _clickable
	_art.border = UiTheme.GOLD if _selected else (Color(UiTheme.GOLD, 0.75) if lit else UiTheme.EDGE)
	_art.border_width = 5.0 if _selected else (3.0 if lit else 2.0)


func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (H - y)


func _has_point(point: Vector2) -> bool:
	if point.y < 0.0 or point.y > size.y:
		return false
	var lean := UiTheme.SLANT * (size.y - point.y)
	return point.x >= lean and point.x <= lean + W - UiTheme.SLANT * H


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _clickable:
		accept_event()
		pressed.emit()
