class_name ActionMenu
extends Control
## The left side of the battle screen: the chosen companion, close up, and beside them the orders
## the commander can give: Attack, up to three equipped combat arts, Magic (for anyone who knows a
## spell), Guard, Focus. Magic changes the list to the spells: every known spell with its school,
## tier and uses left, and Back. What the order under the pointer does is written under the list;
## for a combat art or a spell it is set out to be read at a glance (see ArtFacts), and stays set
## out while that art or spell waits for its target, however it was chosen (click or key).
## The orders are written in light on a veil of shadow with no edge, so the companion and the
## field show through and nothing bright sits on top of the art.
## Display only: it reports which order was pressed and the battle screen decides what happens.

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

## The companion's art runs down the left edge of the screen and fades out to the right.
const ART_SIZE := Vector2(460, 1020)
## The orders: a veil of shadow, darkest behind the words and fading to nothing all round.
const VEIL := Color("120d16")
const VEIL_ALPHA := 0.74
## How far the shadow spreads past the block of words, and how much of its width and height (0-0.5)
## is spent fading in from each side.
const VEIL_GROW_LEFT := 56.0
const VEIL_GROW_RIGHT := 64.0
const VEIL_GROW_Y := 56.0
const VEIL_FADE := 0.27
const SHEET_X := 292.0
const SHEET_Y := 44.0
const SHEET_PAD := 22.0
const SHEET_HEAD := 52.0
const BUTTON_X := SHEET_X + SHEET_PAD
const BUTTON_Y := SHEET_Y + SHEET_HEAD
const BUTTON_STEP := 50.0
## With seven entries the lines pack tighter.
const BUTTON_STEP_TIGHT := 44.0
const BUTTON_H_TIGHT := 44.0
const BUTTON_H := 50.0
const INFO_W := ActionButton.W
const INFO_H := 178.0
## Where the name block starts.
const NAME_Y := 690.0

var _art := Control.new()
var _art_texture: Texture2D
var _art_focus := Vector2(0.5, 0.3)
var _art_tint := Color.WHITE
var _sheet := Control.new()
var _sheet_title := "ORDERS"
var _name: Label
var _weapon: Label
var _grade: Label
var _grade_seal := Control.new()
var _grade_weapon := -1
var _grade_school := -1
var _grade_ink := UiTheme.GOLD
var _grade_bar := SlantBar.new()
var _penalty: Label
var _buttons: Dictionary = {}       # id -> ActionButton
var _descriptions: Dictionary = {}  # id -> String
## For an art or a spell: id -> {figures, lines, accent, note}, drawn in place of the description.
var _facts: Dictionary = {}
var _info_facts: Dictionary = {}
## The order waiting for a target ("" for none), and whether the info shows it for want of a pointer.
var _active_id := ""
var _info_is_active := false
var _order: Array[String] = []      # visible actions, top to bottom; hotkey = place + 1
var _info := Control.new()
var _info_label: Label
var _default_info := ""
var _hovered_id := ""


static var _veil_tex: ImageTexture


## A soft patch of white, opaque in the middle and clear at every edge, to be stretched and tinted.
static func _veil_texture() -> Texture2D:
	if _veil_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (x + 0.5) / n
				var v := (y + 0.5) / n
				var a := smoothstep(0.0, VEIL_FADE, minf(u, 1.0 - u)) * smoothstep(0.0, VEIL_FADE, minf(v, 1.0 - v))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_veil_tex = ImageTexture.create_from_image(img)
	return _veil_tex


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
	size = Vector2(SHEET_X + ActionButton.W + SHEET_PAD * 2.0, ART_SIZE.y)

	_art.size = ART_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	add_child(_art)

	_name = UiTheme.label("", 64, UiTheme.TEXT, true, 12)
	_name.position = Vector2(34, NAME_Y)
	add_child(_name)
	_weapon = UiTheme.label("", 17, UiTheme.TEXT, false, 6)
	_weapon.position = Vector2(38, NAME_Y + 72.0)
	add_child(_weapon)
	# Weapon grade: the seal of the weapon's kind (or of the school, in the spell list) and the letter,
	# and a bar of progress toward the next grade under them.
	_grade_seal.position = Vector2(38, NAME_Y + 124.0)
	_grade_seal.size = Vector2(34, 34)
	_grade_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_seal.draw.connect(func() -> void:
		_grade_seal.draw_circle(Vector2(17, 18.5), 18.0, Color(0, 0, 0, 0.55))
		UiIcons.seal(_grade_seal, Vector2(17, 17), 32.0, _grade_weapon, _grade_school, _grade_ink))
	add_child(_grade_seal)
	_grade = UiTheme.label("", 26, UiTheme.GOLD, true, 6)
	_grade.position = Vector2(38 + 42.0, NAME_Y + 122.0)
	_grade.size = Vector2(258, 34)
	_grade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_grade)
	_grade_bar.fill_color = UiTheme.GOLD
	_grade_bar.font_size = 13
	_grade_bar.size = Vector2(190, 18)
	_grade_bar.position = Vector2(38, NAME_Y + 158.0)
	add_child(_grade_bar)
	_penalty = UiTheme.label("", 16, UiTheme.RECOVERING, false, 6)
	_penalty.position = Vector2(38, NAME_Y + 182.0)
	add_child(_penalty)

	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.position = Vector2(SHEET_X, SHEET_Y)
	_sheet.draw.connect(_draw_sheet)
	add_child(_sheet)

	for id: String in [ATTACK, art_id(0), art_id(1), art_id(2), MAGIC, GUARD, FOCUS, WAIT, MORE, BACK]:
		_add_button(id)
	_buttons[ATTACK].title = "Attack"
	_buttons[GUARD].title = "Guard"
	_buttons[FOCUS].title = "Focus"
	_buttons[WAIT].title = "Wait"
	_buttons[MAGIC].title = "Magic"
	_buttons[MORE].title = "More spells"
	_buttons[BACK].title = "Back"

	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.size = Vector2(INFO_W, INFO_H)
	_info.draw.connect(_draw_info)
	add_child(_info)
	_info_label = UiTheme.label("", 16, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), false, 4)
	_info_label.add_theme_font_override("font", UiTheme.italic_font())
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_label.position = Vector2(4, 8)
	_info_label.size = Vector2(INFO_W - 8.0, INFO_H - 12.0)
	_info_label.clip_text = false
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
	_facts.clear()
	_active_id = active_id
	_sheet_title = "ORDERS"
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
	_descriptions[ATTACK] = "Strike one enemy with %s%s. No cost. Recovery 1." % [w.display_name,
		" (magic: MAG against RES)" if w.is_magic() else ""]
	_descriptions[GUARD] = "Until this turn ends: take half damage, and enemies are %dx as likely to aim at %s. Recovery 1." % [
		roundi(BattleConfig.GUARD_TARGET_WEIGHT_MULT), c.display_name]
	_descriptions[FOCUS] = "Gain %d stamina. Recovery 1." % battle.focus_amount(c)
	(_buttons[FOCUS] as ActionButton).detail = "+%d stamina" % battle.focus_amount(c)
	if not c.spells().is_empty():
		var ready := 0
		for sp in c.spells():
			if c.progress.uses_left(sp) > 0:
				ready += 1
		(_buttons[MAGIC] as ActionButton).detail = "%d of %d ready" % [ready, c.spells().size()]
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
		b.title = art.display_name
		var cost := battle.art_cost(c, art)
		b.detail = "%d stamina" % cost
		var rest := battle.art_recovery(c, art)
		var about := art_info(art, cost, rest)
		var why := ""
		if battle.art_block_reason(c, art) != "":
			if enabled and active_id == "":
				b.disabled = true
			if c.weapon() == null or c.weapon().weapon_type != art.weapon_type:
				b.detail = "%s ONLY" % art.type_name().to_upper()
				why = "Needs a %s in hand." % art.type_name().to_lower()
			else:
				why = "Needs %d stamina, %s has %d. Focus to recover." % [cost, c.display_name, c.stamina]
			about = "%s\n%s" % [why, about]
		_descriptions[art_id(i)] = about
		_facts[art_id(i)] = {"figures": ArtFacts.art_figures(art, cost, rest), "lines": ArtFacts.art_lines(art), "accent": UiTheme.GOLD, "note": why}

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
	_facts.clear()
	_active_id = active_id
	_sheet_title = "SPELLS"
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
		b.title = sp.display_name
		b.accent = UiTheme.school_color(sp.school)
		var left := c.progress.uses_left(sp)
		var most := c.progress.max_uses(sp)
		b.detail = "%s %s  ·  %d/%d" % ["black" if sp.school == SpellData.School.BLACK else "white",
			CombatArtData.tier_numeral(sp.tier), left, most]
		var about := spell_info(sp, c, battle)
		var why := battle.spell_block_reason(c, sp)
		if why != "":
			b.detail = "spent  ·  0/%d" % most
			about = "%s\n%s" % [why, about]
		_descriptions[id] = about
		var lines := ArtFacts.spell_lines(sp)
		if sp.heals:
			lines.append("Heals %d now" % battle.heal_amount(c, sp))
		_facts[id] = {"figures": ArtFacts.spell_figures(sp, left, most), "lines": lines, "accent": UiTheme.school_color(sp.school), "note": why}
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
## `cost` and `recovery` (when 0 or more) are what they are for whoever would use it now.
static func art_info(art: CombatArtData, cost: int = -1, recovery: int = -1) -> String:
	return "Tier %s · %d stamina · Recovery %d\n%s" % [
		CombatArtData.tier_numeral(art.tier), cost if cost >= 0 else art.stamina_cost, recovery if recovery >= 0 else art.recovery,
		art.effect_summary()]


## School, tier, uses, recovery and effect of a spell, for the info panel.
static func spell_info(sp: SpellData, c: CompanionUnit, battle: Battle) -> String:
	var text := "%s %s · %d/%d uses · Recovery %d\n%s" % [sp.school_text(), CombatArtData.tier_numeral(sp.tier),
		c.progress.uses_left(sp), c.progress.max_uses(sp), sp.recovery, sp.effect_summary()]
	if sp.heals:
		text += " Heals %d now." % battle.heal_amount(c, sp)
	return text


## Shown when nobody can act: the only option is to let a turn pass (a tick, in the rules' own word).
## `next_up` is whoever will be ready soonest; their art is shown dimmed.
func show_wait(enabled: bool, next_up: CompanionUnit) -> void:
	visible = true
	_facts.clear()
	_active_id = ""
	_sheet_title = "ORDERS"
	_art.visible = next_up != null
	_name.visible = next_up != null
	_weapon.visible = next_up != null
	_penalty.text = ""
	_grade.visible = false
	_grade_seal.visible = false
	_grade_bar.visible = false
	if next_up != null:
		_show_art(next_up, Color(0.42, 0.44, 0.52))
		_weapon.text = "Catching their breath\nReady in %d" % next_up.recovery
	_arrange([WAIT] as Array[String])
	var b: ActionButton = _buttons[WAIT]
	b.disabled = not enabled
	b.active = false
	_descriptions[WAIT] = "Let one turn pass. Enemy countdowns drop by 1 and recovering companions get closer to ready."
	_default_info = "Nobody is ready to act."
	_update_info()


func show_nothing() -> void:
	visible = false
	_order.clear()


## Writes the given orders down the sheet, numbers their keys, and hides the rest.
## Seven entries pack tighter.
func _arrange(order: Array[String]) -> void:
	_order = order
	var tight := order.size() >= 7
	var step := BUTTON_STEP_TIGHT if tight else BUTTON_STEP
	for id: String in _buttons:
		_buttons[id].visible = order.has(id)
	for i in order.size():
		var b: ActionButton = _buttons[order[i]]
		b.h = BUTTON_H_TIGHT if tight else BUTTON_H
		b.position = Vector2(BUTTON_X, BUTTON_Y + step * i)
		b.hotkey = str(i + 1)
		b.queue_redraw()
	var below := BUTTON_Y + step * order.size()
	_info.position = Vector2(BUTTON_X, below + 6.0)
	_sheet.size = Vector2(ActionButton.W + SHEET_PAD * 2.0, below + INFO_H + 48.0 - SHEET_Y)
	_sheet.queue_redraw()


func _show_weapon_lines(c: CompanionUnit) -> void:
	var w := c.weapon()
	var penalty := c.weight_penalty()
	_weapon.text = "%s  ·  Mt %d  ·  Hit %d%s\nWeight %d / Build %d" % [
		StoreScreen.held_name(w, c.progress), c.weapon_might(), w.hit, "  ·  MAGIC" if w.is_magic() else "", c.total_weight(), c.stat(Stat.BLD)]
	# What a rare weapon does is a pointer away, on the weapon's own line.
	var notes := StoreScreen.weapon_notes(w)
	_weapon.tooltip_text = "\n".join(notes)
	_weapon.mouse_filter = Control.MOUSE_FILTER_STOP if not notes.is_empty() else Control.MOUSE_FILTER_IGNORE
	_penalty.text = ("Too heavy: -%d DEX, -%d SPD" % [penalty, penalty]) if penalty > 0 else ""


func _show_grade(c: CompanionUnit) -> void:
	var w := c.weapon()
	_grade.visible = w != null
	_grade_seal.visible = w != null
	_grade_bar.visible = w != null
	if w == null:
		return
	var t := w.weapon_type
	var g := c.progress.grade(t)
	_grade.text = Proficiency.grade_name(g)
	_grade.add_theme_color_override("font_color", UiTheme.GOLD)
	_grade_weapon = t
	_grade_school = -1
	_grade_ink = UiTheme.GOLD
	_grade_seal.queue_redraw()
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
	_grade_seal.visible = true
	_grade_bar.visible = true
	var g := c.progress.magic_grade(school)
	var color := UiTheme.school_color(school)
	_grade.text = Proficiency.grade_name(g)
	_grade.add_theme_color_override("font_color", color)
	_grade_weapon = -1
	_grade_school = school
	_grade_ink = color
	_grade_seal.queue_redraw()
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
	_art_texture = c.data.portrait
	_art_focus = c.data.portrait_focus + Vector2(0.0, 0.2)
	_art_tint = tint
	_art.queue_redraw()
	_name.text = c.display_name.to_upper()


func _spell_button(index: int) -> ActionButton:
	var id := spell_id(index)
	if not _buttons.has(id):
		_add_button(id)
	return _buttons[id]


func _add_button(id: String) -> ActionButton:
	var b := ActionButton.new()
	b.veil = true
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
	_info_facts = {}
	_info_is_active = false
	if _hovered_id != "" and _buttons.has(_hovered_id) and _buttons[_hovered_id].visible and _descriptions.has(_hovered_id):
		text = _descriptions[_hovered_id]
		_info_facts = _facts.get(_hovered_id, {})
	elif _active_id != "" and _facts.has(_active_id):
		# Nothing under the pointer: the art or spell waiting for its target stays set out.
		_info_facts = _facts[_active_id]
		_info_is_active = true
	# An art or a spell is set out in figures and lines; anything else is a sentence.
	_info_label.visible = _info_facts.is_empty()
	_info.queue_redraw()
	_info_label.text = text
	var font_size := 16
	var font := UiTheme.italic_font()
	while font_size > 12 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, INFO_W - 8.0, font_size).y > INFO_H - 14.0:
		font_size -= 1
	_info_label.add_theme_font_size_override("font_size", font_size)


func _draw_info() -> void:
	if _info_facts.is_empty():
		return
	var lines: Array[String] = []
	lines.assign(_info_facts.lines)
	var note := String(_info_facts.note)
	var note_ink := UiTheme.RECOVERING
	if note == "" and _info_is_active:
		# What to do next, in a few words: "Choose an enemy to hit."
		note = _default_info.get_slice(". ", 0).trim_suffix(".") + "."
		note_ink = UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3)
	ArtFacts.draw(_info, Vector2(4, 6), INFO_W - 8.0, _info_facts.figures, lines, _info_facts.accent, UiTheme.TEXT,
		UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), 0.62, INFO_H - (104.0 if note != "" else 66.0), 4, note, note_ink, 19)


## The companion's art, cropped to the column without stretching, fading out to the right and at the
## top so it sits in the scene rather than in a frame, with shadow under the name.
func _draw_art() -> void:
	if _art_texture == null:
		return
	var tex_size := _art_texture.get_size()
	var tex_aspect := tex_size.x / maxf(1.0, tex_size.y)
	var aspect := ART_SIZE.x / ART_SIZE.y
	var region := Vector2(1.0, tex_aspect / aspect) if aspect >= tex_aspect else Vector2(aspect / tex_aspect, 1.0)
	var origin := _art_focus - region * 0.5
	origin.x = clampf(origin.x, 0.0, 1.0 - region.x)
	origin.y = clampf(origin.y, 0.0, 1.0 - region.y)
	var xs: Array[float] = [0.0, 0.5, 0.74, 1.0]
	var x_alpha: Array[float] = [1.0, 1.0, 0.6, 0.0]
	var ys: Array[float] = [0.0, 0.07, 1.0]
	var y_alpha: Array[float] = [0.0, 1.0, 1.0]
	for iy in ys.size() - 1:
		for ix in xs.size() - 1:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var cols := PackedColorArray()
			for corner: Vector2i in [Vector2i(ix, iy), Vector2i(ix + 1, iy), Vector2i(ix + 1, iy + 1), Vector2i(ix, iy + 1)]:
				var f := Vector2(xs[corner.x], ys[corner.y])
				pts.append(f * ART_SIZE)
				uvs.append(origin + f * region)
				cols.append(Color(_art_tint, minf(x_alpha[corner.x], y_alpha[corner.y])))
			_art.draw_polygon(pts, cols, uvs, _art_texture)
	var clear := Color(UiTheme.INK, 0.0)
	var dark := Color(UiTheme.INK, 0.9)
	_art.draw_polygon(PackedVector2Array([Vector2(0, NAME_Y - 150.0), Vector2(ART_SIZE.x * 0.8, NAME_Y - 150.0),
		Vector2(ART_SIZE.x * 0.8, NAME_Y + 60.0), Vector2(0, NAME_Y + 60.0)]), PackedColorArray([clear, clear, clear, dark]))
	_art.draw_polygon(PackedVector2Array([Vector2(0, NAME_Y + 60.0), Vector2(ART_SIZE.x * 0.8, NAME_Y + 60.0),
		Vector2(ART_SIZE.x * 0.8, ART_SIZE.y), Vector2(0, ART_SIZE.y)]), PackedColorArray([dark, clear, clear, dark]))


func _draw_sheet() -> void:
	var r := Rect2(Vector2.ZERO, _sheet.size)
	# Shadow with no edge or corners: full behind the words, gone before it reaches the enemies.
	var veil := Rect2(-VEIL_GROW_LEFT, -VEIL_GROW_Y, r.size.x + VEIL_GROW_LEFT + VEIL_GROW_RIGHT, r.size.y + VEIL_GROW_Y * 2.0)
	_sheet.draw_texture_rect(_veil_texture(), veil, false, Color(VEIL, VEIL_ALPHA))
	var font := UiTheme.display_font()
	UiTheme.draw_text(_sheet, font, Vector2(0, 14.0), _sheet_title, 16, Color(UiTheme.GOLD, 0.85), 4, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.draw_rule(_sheet, Vector2(r.size.x * 0.5, 42.0), r.size.x - 70.0, Color(UiTheme.GOLD, 0.45))
