class_name ActionMenu
extends Control
## The left side of the battle screen: the chosen companion's art, and the actions they can take.
## Display only: it reports which action was pressed and the battle screen decides what happens.

signal action_pressed(id: String)

const ATTACK := "attack"
const SKILL := "skill"
const GUARD := "guard"
const FOCUS := "focus"
const WAIT := "wait"

const ART_SIZE := Vector2(420, 620)
const BUTTON_X := 300.0
const BUTTON_Y := 64.0
const BUTTON_STEP := 80.0

var _art := SlantPanel.new()
var _name: Label
var _weapon: Label
var _penalty: Label
var _buttons: Dictionary = {}       # id -> ActionButton
var _descriptions: Dictionary = {}  # id -> String
var _info := SlantPanel.new()
var _info_label: Label
var _default_info := ""
var _hovered_id := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(700, 640)

	_art.size = ART_SIZE
	_art.border = UiTheme.GOLD
	_art.border_width = 4.0
	_art.shade = 0.92
	_art.zoom = 1.25
	add_child(_art)

	_name = UiTheme.label("", 66, UiTheme.TEXT, true, 12)
	_name.position = Vector2(UiTheme.SLANT * 150.0 + 24.0, ART_SIZE.y - 186.0)
	add_child(_name)
	_weapon = UiTheme.label("", 18, UiTheme.TEXT, false, 6)
	_weapon.position = Vector2(UiTheme.SLANT * 60.0 + 26.0, ART_SIZE.y - 104.0)
	add_child(_weapon)
	_penalty = UiTheme.label("", 17, UiTheme.RECOVERING, false, 6)
	_penalty.position = Vector2(UiTheme.SLANT * 20.0 + 26.0, ART_SIZE.y - 50.0)
	add_child(_penalty)

	var order: Array[String] = [ATTACK, SKILL, GUARD, FOCUS]
	for i in order.size():
		var b := _add_button(order[i], str(i + 1))
		b.position = Vector2(BUTTON_X - UiTheme.SLANT * BUTTON_STEP * i, BUTTON_Y + BUTTON_STEP * i)
	var wait := _add_button(WAIT, "1")
	wait.position = Vector2(BUTTON_X, BUTTON_Y)
	_buttons[ATTACK].title = "ATTACK"
	_buttons[GUARD].title = "GUARD"
	_buttons[FOCUS].title = "FOCUS"
	wait.title = "WAIT"

	_info.size = Vector2(404, 132)
	_info.position = Vector2(BUTTON_X - UiTheme.SLANT * BUTTON_STEP * 4.0 - 22.0, BUTTON_Y + BUTTON_STEP * 4.0 + 4.0)
	_info.fill = Color(UiTheme.INK, 0.86)
	_info.border = UiTheme.EDGE
	add_child(_info)
	_info_label = UiTheme.label("", 18, UiTheme.TEXT)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.position = Vector2(UiTheme.slant_for(132) + 6.0, 8)
	_info_label.size = Vector2(404 - UiTheme.slant_for(132) * 2.0 - 4.0, 116)
	_info.add_child(_info_label)


## Shows a companion's actions. `active_id` is the action currently waiting for a target ("" for none).
func show_companion(c: CompanionUnit, battle: Battle, active_id: String, enabled: bool) -> void:
	visible = true
	_show_art(c, Color.WHITE)
	var w := c.weapon()
	var penalty := c.weight_penalty()
	_weapon.text = "%s  ·  Mt %d  ·  Hit %d\nWeight %d / Build %d" % [
		w.display_name, w.might, w.hit, c.total_weight(), c.stat(Stat.BLD)]
	_penalty.text = ("Too heavy: -%d DEX, -%d SPD" % [penalty, penalty]) if penalty > 0 else ""

	var s := c.skill()
	var skill_btn: ActionButton = _buttons[SKILL]
	skill_btn.visible = s != null
	if s != null:
		skill_btn.title = s.display_name.to_upper()
		skill_btn.detail = "%d STA" % s.stamina_cost
		_descriptions[SKILL] = "%s\nMt %+d  Hit %+d  Crit %+d.  Costs %d stamina, then sits out the next %d actions." % [
			s.description, s.might_bonus, s.hit_bonus, s.crit_bonus, s.stamina_cost, BattleConfig.RECOVERY_SKILL]
	var focus_btn: ActionButton = _buttons[FOCUS]
	focus_btn.detail = "+%d STA" % battle.focus_amount(c)
	_descriptions[ATTACK] = "Strike one enemy with %s. Costs nothing, then sits out the next action." % w.display_name
	_descriptions[GUARD] = "Until this tick ends: take half damage, and enemies are %dx as likely to aim at %s. Then sits out the next action." % [
		roundi(BattleConfig.GUARD_TARGET_WEIGHT_MULT), c.display_name]
	_descriptions[FOCUS] = "Recover %d stamina. Then sits out the next action." % battle.focus_amount(c)

	for id: String in [ATTACK, SKILL, GUARD, FOCUS]:
		var b: ActionButton = _buttons[id]
		if id != SKILL:
			b.visible = true
		b.active = id == active_id
		b.disabled = not enabled or (active_id != "" and id != active_id)
	if enabled and active_id == "":
		skill_btn.disabled = not battle.can_use_skill(c)
		if s != null and skill_btn.disabled:
			_descriptions[SKILL] = "Not enough stamina: %s needs %d. Focus to recover some." % [s.display_name, s.stamina_cost]
	_buttons[WAIT].visible = false

	if active_id != "":
		_default_info = "Choose an enemy to hit. Right-click or Esc to go back."
	elif enabled:
		_default_info = "Choose what %s does. Every action lets the enemies' countdowns drop by 1." % c.display_name
	else:
		_default_info = ""
	_update_info()


## Shown when nobody can act: the only option is to let a tick pass.
## `next_up` is whoever will be ready soonest; their art is shown dimmed.
func show_wait(enabled: bool, next_up: CompanionUnit) -> void:
	visible = true
	_art.visible = next_up != null
	_name.visible = next_up != null
	_weapon.visible = next_up != null
	_penalty.text = ""
	if next_up != null:
		_show_art(next_up, Color(0.42, 0.44, 0.52))
		_weapon.text = "Recovering\nReady in %d" % next_up.recovery
	for id: String in [ATTACK, SKILL, GUARD, FOCUS]:
		_buttons[id].visible = false
	var b: ActionButton = _buttons[WAIT]
	b.visible = true
	b.disabled = not enabled
	_descriptions[WAIT] = "Let one tick pass. Enemy countdowns drop by 1 and recovering companions get closer to ready."
	_default_info = "Nobody is ready to act."
	_update_info()


func show_nothing() -> void:
	visible = false


func _show_art(c: CompanionUnit, tint: Color) -> void:
	_art.visible = true
	_name.visible = true
	_weapon.visible = true
	_art.texture = c.data.portrait
	_art.focus = c.data.portrait_focus + Vector2(0, 0.24)
	_art.tint = tint
	_name.text = c.display_name.to_upper()


func _add_button(id: String, hotkey: String) -> ActionButton:
	var b := ActionButton.new()
	b.hotkey = hotkey
	b.pressed.connect(func() -> void: action_pressed.emit(id))
	b.hover_changed.connect(func(inside: bool) -> void:
		if inside:
			_hovered_id = id
		elif _hovered_id == id:
			_hovered_id = ""
		_update_info())
	add_child(b)
	_buttons[id] = b
	return b


func _update_info() -> void:
	var text := _default_info
	if _hovered_id != "" and _buttons[_hovered_id].visible and _descriptions.has(_hovered_id):
		text = _descriptions[_hovered_id]
	_info_label.text = text
	_info.visible = text != ""
