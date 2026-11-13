class_name ActionMenu
extends Control
## The left side of the battle screen: the chosen companion's art, their weapon grade, and the
## actions they can take: Attack, up to three equipped combat arts, Magic (for anyone who knows a
## spell), Guard, Focus. Magic opens the spell list in the same place: every known spell with its
## school, tier and uses left, and Back.
## Display only: it reports which action was pressed and the battle screen decides what happens.

signal action_pressed(id: String)

const ATTACK := "attack"
const GUARD := "guard"
const FOCUS := "focus"
const WAIT := "wait"
const MAGIC := "magic"
const BACK := "back"
const MORE := "more"
## Combat arts are "art:0" .. "art:2", by their place in the companion's equipped list.
const ART_PREFIX := "art:"
## Spells are "spell:0" .. by their place in the companion's known spells.
const SPELL_PREFIX := "spell:"
## The spell list shows every spell when there are this many or fewer; else pages of SPELL_PAGE.
const SPELLS_ON_ONE_PAGE := 6
const SPELL_PAGE := 5

const ART_SIZE := Vector2(420, 700)
const BUTTON_X := 300.0
const BUTTON_Y := 4.0
const BUTTON_STEP := 60.0
## With seven entries the buttons pack tighter so the info panel stays clear of the name.
const BUTTON_STEP_TIGHT := 52.0
const BUTTON_H_TIGHT := 48.0
const INFO_W := 430.0
const INFO_H := 112.0
## Where the name block starts; the buttons and the info panel stay above it.
const NAME_Y := 488.0

var _art := SlantPanel.new()
var _name: Label
var _weapon: Label
var _grade: Label
var _grade_bar := SlantBar.new()
var _penalty: Label
var _buttons: Dictionary = {}       # id -> ActionButton
var _descriptions: Dictionary = {}  # id -> String
var _order: Array[String] = []      # visible actions, top to bottom; hotkey = place + 1
var _info := SlantPanel.new()
var _info_label: Label
var _default_info := ""
var _hovered_id := ""


static func art_id(index: int) -> String:
	return ART_PREFIX + str(index)


static func spell_id(index: int) -> String:
	return SPELL_PREFIX + str(index)


## Index into the companion's equipped arts, or -1 if `id` is not an art.
static func art_index(id: String) -> int:
	return int(id.substr(ART_PREFIX.length())) if id.begins_with(ART_PREFIX) else -1


## Index into the companion's known spells, or -1 if `id` is not a spell.
static func spell_index(id: String) -> int:
	return int(id.substr(SPELL_PREFIX.length())) if id.begins_with(SPELL_PREFIX) else -1


## How many pages the spell list of `count` spells has.
static func spell_pages(count: int) -> int:
	return 1 if count <= SPELLS_ON_ONE_PAGE else ceili(float(count) / SPELL_PAGE)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(700, ART_SIZE.y)

	_art.size = ART_SIZE
	_art.border = UiTheme.GOLD
	_art.border_width = 4.0
	_art.shade = 0.92
	_art.zoom = 1.25
	add_child(_art)

	_name = UiTheme.label("", 60, UiTheme.TEXT, true, 12)
	_name.position = Vector2(_edge_x(NAME_Y + 74.0) + 22.0, NAME_Y)
	add_child(_name)
	_weapon = UiTheme.label("", 17, UiTheme.TEXT, false, 6)
	_weapon.position = Vector2(_edge_x(598.0) + 22.0, 544.0)
	add_child(_weapon)
	# Weapon grade: "SWORD D", and a bar of progress toward the next grade under it.
	_grade = UiTheme.label("", 24, UiTheme.GOLD, true, 6)
	_grade.position = Vector2(_edge_x(632.0) + 22.0, 604.0)
	_grade.size = Vector2(320, 30)
	_grade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_grade)
	_grade_bar.fill_color = UiTheme.GOLD
	_grade_bar.font_size = 14
	_grade_bar.size = Vector2(196, 20)
	_grade_bar.position = Vector2(_edge_x(656.0) + 20.0, 636.0)
	add_child(_grade_bar)
	_penalty = UiTheme.label("", 16, UiTheme.RECOVERING, false, 6)
	_penalty.position = Vector2(_edge_x(684.0) + 22.0, 662.0)
	add_child(_penalty)

	for id: String in [ATTACK, art_id(0), art_id(1), art_id(2), MAGIC, GUARD, FOCUS, WAIT, MORE, BACK]:
		_add_button(id)
	_buttons[ATTACK].title = "ATTACK"
	_buttons[GUARD].title = "GUARD"
	_buttons[FOCUS].title = "FOCUS"
	_buttons[WAIT].title = "WAIT"
	_buttons[MAGIC].title = "MAGIC"
	_buttons[MORE].title = "MORE SPELLS"
	_buttons[BACK].title = "‹ BACK"

	_info.size = Vector2(INFO_W, INFO_H)
	_info.fill = Color(UiTheme.INK, 0.86)
	_info.border = UiTheme.EDGE
	add_child(_info)
	_info_label = UiTheme.label("", 17, UiTheme.TEXT)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(UiTheme.slant_for(INFO_H) + 4.0, 6)
	_info_label.size = Vector2(INFO_W - UiTheme.slant_for(INFO_H) * 2.0 - 2.0, INFO_H - 12.0)
	_info.add_child(_info_label)


## The action behind number key `n` (1-based), or "" if there is none.
func action_for_key(n: int) -> String:
	return _order[n - 1] if n >= 1 and n <= _order.size() and visible else ""


## The visible actions, top to bottom.
func visible_actions() -> Array[String]:
	return _order.duplicate()


func is_disabled(id: String) -> bool:
	return not _buttons.has(id) or (_buttons[id] as ActionButton).disabled


## The text the info panel would show when `id` is hovered.
func description(id: String) -> String:
	return _descriptions.get(id, "")


## Shows a companion's actions. `active_id` is the action currently waiting for a target ("" for none).
func show_companion(c: CompanionUnit, battle: Battle, active_id: String, enabled: bool) -> void:
	visible = true
	_show_art(c, Color.WHITE)
	_show_weapon_lines(c)
	_show_grade(c)

	var arts := c.arts()
	var order: Array[String] = [ATTACK]
	for i in arts.size():
		order.append(art_id(i))
	if not c.spells().is_empty():
		order.append(MAGIC)
	order.append_array([GUARD, FOCUS] as Array[String])
	_arrange(order)

	var w := c.weapon()
	_descriptions[ATTACK] = "Strike one enemy with %s%s. Costs nothing, then sits out the next action." % [w.display_name,
		" (magic: MAG against RES)" if w.is_magic() else ""]
	_descriptions[GUARD] = "Until this tick ends: take half damage, and enemies are %dx as likely to aim at %s. Then sits out the next action." % [
		roundi(BattleConfig.GUARD_TARGET_WEIGHT_MULT), c.display_name]
	_descriptions[FOCUS] = "Recover %d stamina. Then sits out the next action." % battle.focus_amount(c)
	(_buttons[FOCUS] as ActionButton).detail = "+%d STA" % battle.focus_amount(c)
	if not c.spells().is_empty():
		var ready := 0
		for sp in c.spells():
			if c.progress.uses_left(sp) > 0:
				ready += 1
		(_buttons[MAGIC] as ActionButton).detail = "%d / %d READY" % [ready, c.spells().size()]
		(_buttons[MAGIC] as ActionButton).accent = UiTheme.school_color(c.spells()[0].school)
		_descriptions[MAGIC] = "Open %s's spells (%d known, %d with uses left). A spell costs no stamina; its uses only come back with Rest on a free day." % [
			c.display_name, c.spells().size(), ready]

	for id in order:
		var b: ActionButton = _buttons[id]
		b.active = id == active_id
		b.disabled = not enabled or (active_id != "" and id != active_id)
	for i in arts.size():
		var art := arts[i]
		var b: ActionButton = _buttons[art_id(i)]
		b.title = art.display_name.to_upper()
		b.detail = "%d STA" % art.stamina_cost
		var about := art_info(art)
		if battle.art_block_reason(c, art) != "":
			if enabled and active_id == "":
				b.disabled = true
			var why := ""
			if c.weapon() == null or c.weapon().weapon_type != art.weapon_type:
				b.detail = "%s ONLY" % art.type_name().to_upper()
				why = "Needs a %s in hand." % art.type_name().to_lower()
			else:
				why = "Needs %d STA, %s has %d. Focus to recover." % [art.stamina_cost, c.display_name, c.stamina]
			about = "%s\n%s" % [why, about]
		_descriptions[art_id(i)] = about

	if active_id != "":
		var index := art_index(active_id)
		if index >= 0 and index < arts.size() and arts[index].hits_all_enemies:
			_default_info = "%s strikes every enemy. Click any of them to confirm. Right-click or Esc to go back." % arts[index].display_name
		else:
			_default_info = "Choose an enemy to hit. Right-click or Esc to go back."
	elif enabled:
		_default_info = "What will %s do?" % c.display_name
	else:
		_default_info = ""
	_update_info()


## Shows the companion's spells, `page` of them (0-based), with More (if there are pages) and Back.
## `active_id` is the spell waiting for a target ("" for none).
func show_spells(c: CompanionUnit, battle: Battle, active_id: String, enabled: bool, page: int) -> void:
	visible = true
	_show_art(c, Color.WHITE)
	_show_weapon_lines(c)
	var spells := c.spells()
	_show_magic_grade(c, spells[0].school if not spells.is_empty() else SpellData.School.BLACK)

	var pages := spell_pages(spells.size())
	var first := 0 if pages == 1 else clampi(page, 0, pages - 1) * SPELL_PAGE
	var last := spells.size() if pages == 1 else mini(spells.size(), first + SPELL_PAGE)
	var order: Array[String] = []
	for i in range(first, last):
		order.append(spell_id(i))
		_spell_button(i)
	if pages > 1:
		order.append(MORE)
		(_buttons[MORE] as ActionButton).detail = "%d / %d" % [clampi(page, 0, pages - 1) + 1, pages]
		_descriptions[MORE] = "Show the next page of spells."
	order.append(BACK)
	_descriptions[BACK] = "Back to %s's actions." % c.display_name
	_arrange(order)

	for i in range(first, last):
		var sp := spells[i]
		var id := spell_id(i)
		var b: ActionButton = _buttons[id]
		b.title = sp.display_name.to_upper()
		b.accent = UiTheme.school_color(sp.school)
		var left := c.progress.uses_left(sp)
		b.detail = "%s %s  ·  %d/%d" % ["BLACK" if sp.school == SpellData.School.BLACK else "WHITE",
			CombatArtData.tier_numeral(sp.tier), left, sp.uses]
		var about := spell_info(sp, c, battle)
		var why := battle.spell_block_reason(c, sp)
		if why != "":
			b.detail = "NO USES  ·  0/%d" % sp.uses
			about = "%s\n%s" % [why, about]
		_descriptions[id] = about
	for id in order:
		var b: ActionButton = _buttons[id]
		b.active = id == active_id
		var blocked := spell_index(id) >= 0 and battle.spell_block_reason(c, spells[spell_index(id)]) != ""
		b.disabled = not enabled or (active_id != "" and id != active_id) or blocked

	if active_id != "":
		var sp := spells[spell_index(active_id)]
		match sp.targeting:
			SpellData.Targeting.ONE_ENEMY:
				_default_info = "Choose an enemy for %s. Right-click or Esc to go back." % sp.display_name
			SpellData.Targeting.ALL_ENEMIES:
				_default_info = "%s strikes every enemy. Click any of them to confirm. Right-click or Esc to go back." % sp.display_name
			SpellData.Targeting.ONE_ALLY:
				_default_info = "Click a companion below to cast %s on them. Right-click or Esc to go back." % sp.display_name
			SpellData.Targeting.ALL_ALLIES:
				_default_info = "%s reaches the whole line. Click any companion to confirm. Right-click or Esc to go back." % sp.display_name
	elif enabled:
		_default_info = "Choose a spell for %s. No stamina; uses only come back with Rest. Esc or Back returns." % c.display_name
	else:
		_default_info = ""
	_update_info()


## Tier, cost, recovery and effect of an art, for the info panel.
static func art_info(art: CombatArtData) -> String:
	var rec := "the next action" if art.recovery == 1 else "%d actions" % art.recovery
	return "Tier %s · %d STA · then sits out %s.\n%s" % [
		CombatArtData.tier_numeral(art.tier), art.stamina_cost, rec, art.effect_summary()]


## School, tier, uses, recovery and effect of a spell, for the info panel.
static func spell_info(sp: SpellData, c: CompanionUnit, battle: Battle) -> String:
	var rec := "the next action" if sp.recovery == 1 else "%d actions" % sp.recovery
	var text := "%s %s · %d/%d uses · then sits out %s.\n%s" % [sp.school_text(), CombatArtData.tier_numeral(sp.tier),
		c.progress.uses_left(sp), sp.uses, rec, sp.effect_summary()]
	if sp.heals:
		text += " Heals %d now." % battle.heal_amount(c, sp)
	return text


## Shown when nobody can act: the only option is to let a tick pass.
## `next_up` is whoever will be ready soonest; their art is shown dimmed.
func show_wait(enabled: bool, next_up: CompanionUnit) -> void:
	visible = true
	_art.visible = next_up != null
	_name.visible = next_up != null
	_weapon.visible = next_up != null
	_penalty.text = ""
	_grade.visible = false
	_grade_bar.visible = false
	if next_up != null:
		_show_art(next_up, Color(0.42, 0.44, 0.52))
		_weapon.text = "Recovering\nReady in %d" % next_up.recovery
	_arrange([WAIT] as Array[String])
	var b: ActionButton = _buttons[WAIT]
	b.disabled = not enabled
	b.active = false
	_descriptions[WAIT] = "Let one tick pass. Enemy countdowns drop by 1 and recovering companions get closer to ready."
	_default_info = "Nobody is ready to act."
	_update_info()


func show_nothing() -> void:
	visible = false
	_order.clear()


## Stacks the given buttons down the lean, numbers them, and hides the rest.
## Seven entries pack tighter so the info panel stays above the name.
func _arrange(order: Array[String]) -> void:
	_order = order
	var tight := order.size() >= 7
	var step := BUTTON_STEP_TIGHT if tight else BUTTON_STEP
	for id: String in _buttons:
		_buttons[id].visible = order.has(id)
	for i in order.size():
		var b: ActionButton = _buttons[order[i]]
		b.h = BUTTON_H_TIGHT if tight else ActionButton.H
		b.position = Vector2(BUTTON_X - UiTheme.SLANT * step * i, BUTTON_Y + step * i)
		b.hotkey = str(i + 1)
		b.queue_redraw()
	var below := BUTTON_Y + step * order.size() + 4.0
	_info.position = Vector2(BUTTON_X - UiTheme.SLANT * (step * order.size() + INFO_H) - 4.0, below)


func _show_weapon_lines(c: CompanionUnit) -> void:
	var w := c.weapon()
	var penalty := c.weight_penalty()
	_weapon.text = "%s  ·  Mt %d  ·  Hit %d%s\nWeight %d / Build %d" % [
		w.display_name, w.might, w.hit, "  ·  MAGIC" if w.is_magic() else "", c.total_weight(), c.stat(Stat.BLD)]
	_penalty.text = ("Too heavy: -%d DEX, -%d SPD" % [penalty, penalty]) if penalty > 0 else ""


func _show_grade(c: CompanionUnit) -> void:
	var w := c.weapon()
	_grade.visible = w != null
	_grade_bar.visible = w != null
	if w == null:
		return
	var t := w.weapon_type
	var g := c.progress.grade(t)
	_grade.text = "%s  %s" % [WeaponData.type_name(t).to_upper(), Proficiency.grade_name(g)]
	_grade.add_theme_color_override("font_color", UiTheme.GOLD)
	var step := c.progress.progress_to_next(t)
	var capped := c.proficiency_gained >= BattleConfig.PROFICIENCY_CAP_PER_BATTLE
	_set_bar(step, g, capped, UiTheme.GOLD)
	_grade.tooltip_text = "%s proficiency %s. Attacks give %d point, combat arts %d; a grade-up teaches a new %s art.\n%s gained %d of the %d points one battle can give%s." % [
		WeaponData.type_name(t), Proficiency.grade_name(g), BattleConfig.PROFICIENCY_POINTS_ATTACK,
		BattleConfig.PROFICIENCY_POINTS_ART, WeaponData.type_name(t).to_lower(), c.display_name,
		c.proficiency_gained, BattleConfig.PROFICIENCY_CAP_PER_BATTLE, " (no more this battle)" if capped else ""]


## In the spell list, the grade line shows the school instead of the weapon.
func _show_magic_grade(c: CompanionUnit, school: SpellData.School) -> void:
	_grade.visible = true
	_grade_bar.visible = true
	var g := c.progress.magic_grade(school)
	var color := UiTheme.school_color(school)
	_grade.text = "%s  %s" % [SpellData.school_name(school).to_upper(), Proficiency.grade_name(g)]
	_grade.add_theme_color_override("font_color", color)
	var capped := c.magic_gained >= BattleConfig.MAGIC_CAP_PER_BATTLE
	_set_bar(c.progress.magic_progress_to_next(school), g, capped, color)
	_grade.tooltip_text = "%s %s. Every cast gives %d points; a grade-up teaches a new spell.\n%s gained %d of the %d magic points one battle can give%s." % [
		SpellData.school_name(school), Proficiency.grade_name(g), BattleConfig.MAGIC_POINTS_PER_CAST, c.display_name,
		c.magic_gained, BattleConfig.MAGIC_CAP_PER_BATTLE, " (no more this battle)" if capped else ""]


func _set_bar(step: Vector2i, g: int, capped: bool, color: Color) -> void:
	if step.y == 0:
		_grade_bar.label_prefix = "MAX  "
		_grade_bar.set_values(1, 1)
	else:
		_grade_bar.label_prefix = "TO %s  " % Proficiency.grade_name(g + 1)
		_grade_bar.set_values(step.x, step.y)
	_grade_bar.fill_color = Color(color, 0.45) if capped else color


func _show_art(c: CompanionUnit, tint: Color) -> void:
	_art.visible = true
	_name.visible = true
	_weapon.visible = true
	_art.texture = c.data.portrait
	_art.focus = c.data.portrait_focus + Vector2(0, 0.24)
	_art.tint = tint
	_name.text = c.display_name.to_upper()


func _spell_button(index: int) -> ActionButton:
	var id := spell_id(index)
	if not _buttons.has(id):
		_add_button(id)
	return _buttons[id]


func _add_button(id: String) -> ActionButton:
	var b := ActionButton.new()
	b.pressed.connect(func() -> void: action_pressed.emit(id))
	b.hover_changed.connect(func(inside: bool) -> void:
		if inside:
			_hovered_id = id
		elif _hovered_id == id:
			_hovered_id = ""
		_update_info())
	add_child(b)
	# Buttons stay above the info panel, which is added after the first ones.
	if _info.get_parent() == self:
		move_child(b, _info.get_index())
	_buttons[id] = b
	b.visible = false
	return b


func _update_info() -> void:
	var text := _default_info
	if _hovered_id != "" and _buttons.has(_hovered_id) and _buttons[_hovered_id].visible and _descriptions.has(_hovered_id):
		text = _descriptions[_hovered_id]
	_info_label.text = text
	_info.visible = text != ""


## Left edge of the leaning art panel at height `y`.
func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (ART_SIZE.y - y)
