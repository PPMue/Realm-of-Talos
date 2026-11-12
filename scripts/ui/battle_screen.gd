extends Control
## Battle screen. Builds placeholder UI, reads Battle state and sends commands.
## No battle rules live here; see res://scripts/battle/battle.gd.

enum Mode { IDLE, TARGET_ATTACK, TARGET_SKILL }

const COLOR_BG := Color(0.08, 0.09, 0.12)
const COLOR_PANEL := Color(0.12, 0.13, 0.17)
const COLOR_READY := Color(0.45, 0.9, 0.45)
const COLOR_RECOVERING := Color(0.95, 0.65, 0.25)
const COLOR_INJURED := Color(0.95, 0.3, 0.3)
const COLOR_MUTED := Color(0.6, 0.62, 0.68)
const INTENT_COLORS := {
	EnemyActionData.Intent.ATTACK: Color(0.95, 0.35, 0.3),
	EnemyActionData.Intent.DEFEND: Color(0.45, 0.7, 0.95),
	EnemyActionData.Intent.BUFF: Color(0.95, 0.8, 0.3),
	EnemyActionData.Intent.DEBUFF: Color(0.75, 0.45, 0.95),
}

@export var setup: BattleSetup

var battle: Battle

var _selected: CompanionUnit
var _mode := Mode.IDLE
var _target: EnemyUnit
var _companion_cards: Dictionary = {}   # CompanionUnit -> UnitCard
var _enemy_cards: Dictionary = {}       # EnemyUnit -> UnitCard
var _logged := 0
var _seed := 0

var _tick_label := Label.new()
var _seed_label := Label.new()
var _companion_row := HBoxContainer.new()
var _enemy_row := HBoxContainer.new()
var _prompt_label := Label.new()
var _attack_btn := Button.new()
var _skill_btn := Button.new()
var _guard_btn := Button.new()
var _focus_btn := Button.new()
var _wait_btn := Button.new()
var _confirm_btn := Button.new()
var _cancel_btn := Button.new()
var _forecast_label := RichTextLabel.new()
var _log := RichTextLabel.new()
var _overlay := ColorRect.new()
var _result_label := Label.new()


func _ready() -> void:
	if setup == null:
		setup = load("res://data/battles/prototype_battle.tres")
	_build_ui()
	start_battle()


func start_battle() -> void:
	var rng := RandomNumberGenerator.new()
	if setup.rng_seed != 0:
		rng.seed = setup.rng_seed
	else:
		rng.randomize()
	_seed = rng.seed
	battle = Battle.new(setup.companions, setup.enemies, rng)

	for child in _companion_row.get_children() + _enemy_row.get_children():
		child.queue_free()
	_companion_cards.clear()
	_enemy_cards.clear()
	for c in battle.roster:
		var card := UnitCard.new()
		card.setup(c.display_name, c.data.portrait, c.data.color, true)
		card.clicked.connect(_on_companion_clicked.bind(c))
		_companion_row.add_child(card)
		_companion_cards[c] = card
	for e in battle.enemies:
		var card := UnitCard.new()
		card.setup(e.display_name, e.data.portrait, e.data.color, false)
		card.clicked.connect(_on_enemy_clicked.bind(e))
		_enemy_row.add_child(card)
		_enemy_cards[e] = card

	_log.clear()
	_logged = 0
	_selected = null
	_set_mode(Mode.IDLE)
	_overlay.visible = false
	_after_change()


# ---------------------------------------------------------------- input

func _on_companion_clicked(c: CompanionUnit) -> void:
	if battle.can_act(c):
		_selected = c
		_set_mode(Mode.IDLE)
		_refresh()


func _on_enemy_clicked(e: EnemyUnit) -> void:
	if _mode == Mode.IDLE or not e.is_alive():
		return
	if _target == e:
		_on_confirm()   # second click on the same target confirms
		return
	_target = e
	_refresh()


func _on_attack() -> void:
	_set_mode(Mode.TARGET_ATTACK)
	_refresh()


func _on_skill() -> void:
	_set_mode(Mode.TARGET_SKILL)
	_refresh()


func _on_guard() -> void:
	battle.guard(_selected)
	_after_change()


func _on_focus() -> void:
	battle.focus(_selected)
	_after_change()


func _on_wait() -> void:
	battle.wait()
	_after_change()


func _on_confirm() -> void:
	if _selected == null or _target == null:
		return
	if _mode == Mode.TARGET_ATTACK:
		battle.attack(_selected, _target)
	elif _mode == Mode.TARGET_SKILL:
		battle.use_skill(_selected, _target)
	_set_mode(Mode.IDLE)
	_after_change()


func _on_cancel() -> void:
	_set_mode(Mode.IDLE)
	_refresh()


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_target = null
	if mode != Mode.IDLE and battle != null and battle.living_enemies().size() == 1:
		_target = battle.living_enemies()[0]


## After any command: keep the selection if that companion can still act, else pick the next ready one.
func _after_change() -> void:
	if not battle.can_act(_selected):
		var ready := battle.ready_companions()
		_selected = ready[0] if not ready.is_empty() else null
		_set_mode(Mode.IDLE)
	_refresh()


# ---------------------------------------------------------------- drawing

func _refresh() -> void:
	_tick_label.text = "Tick %d" % battle.tick
	_seed_label.text = "seed %d" % _seed
	for c: CompanionUnit in _companion_cards:
		_draw_companion(c, _companion_cards[c])
	for e: EnemyUnit in _enemy_cards:
		_draw_enemy(e, _enemy_cards[e])
	_draw_actions()
	_draw_log()
	if battle.is_over():
		_overlay.visible = true
		var victory := battle.outcome == Battle.Outcome.VICTORY
		_result_label.text = "Victory!" if victory else "Defeat"
		_result_label.add_theme_color_override("font_color", COLOR_READY if victory else COLOR_INJURED)


func _draw_companion(c: CompanionUnit, card: UnitCard) -> void:
	card.visible = not c.is_gone()
	if c.is_gone():
		return
	card.set_hp(c.hp, c.max_hp())
	card.set_stamina(c.stamina, c.max_stamina())
	var tint := Color.WHITE
	if c.is_injured():
		card.set_status("INJURED", COLOR_INJURED)
		tint = Color(1, 0.45, 0.45)
	elif battle.is_over():
		card.set_status("", COLOR_MUTED)
	elif battle.can_act(c):
		card.set_status("READY (alone)" if c.recovery > 0 else "READY", COLOR_READY)
	else:
		card.set_status("RECOVERING: %d" % c.recovery, COLOR_RECOVERING)
		tint = Color(0.6, 0.6, 0.6)
	card.set_portrait_tint(tint)

	var w := c.weapon()
	var lines: Array[String] = ["%s  Mt %d  Hit %d" % [w.display_name, w.might, w.hit]]
	var pen := c.weight_penalty()
	lines.append("WT %d / BLD %d%s" % [c.total_weight(), c.stat(Stat.BLD), ("  (-%d DEX/SPD)" % pen) if pen > 0 else ""])
	for e in c.effects:
		lines.append(e.describe())
	card.set_detail("\n".join(lines))
	card.tooltip_text = _stat_sheet(c, Stat.COMPANION_KEYS)
	card.set_highlight(UnitCard.Highlight.SELECTED if c == _selected else UnitCard.Highlight.NONE)


func _draw_enemy(e: EnemyUnit, card: UnitCard) -> void:
	card.set_hp(maxi(e.hp, 0), e.max_hp())
	if not e.is_alive():
		card.set_status("DEFEATED", COLOR_MUTED)
		card.set_detail("")
		card.set_portrait_tint(Color(0.3, 0.3, 0.3))
		card.set_highlight(UnitCard.Highlight.NONE)
		return
	card.set_portrait_tint(Color.WHITE)
	var a := e.pending_action
	if a != null:
		# The player sees the intent category and countdown, never the target.
		card.set_status("%s in %d" % [EnemyActionData.intent_name(a.intent), e.countdown], INTENT_COLORS[a.intent])
	else:
		card.set_status("-", COLOR_MUTED)
	var lines: Array[String] = []
	for eff in e.effects:
		lines.append(eff.describe())
	card.set_detail("\n".join(lines))
	card.tooltip_text = _stat_sheet(e, Stat.ENEMY_KEYS)
	var h := UnitCard.Highlight.NONE
	if _mode != Mode.IDLE:
		h = UnitCard.Highlight.TARGETED if e == _target else UnitCard.Highlight.TARGETABLE
	card.set_highlight(h)


func _draw_actions() -> void:
	var c := _selected
	var has_actor := c != null and battle.can_act(c)
	var targeting := _mode != Mode.IDLE
	for b: Button in [_attack_btn, _skill_btn, _guard_btn, _focus_btn]:
		b.visible = has_actor and not targeting
		b.disabled = battle.is_over()
	_wait_btn.visible = battle.can_wait()
	_confirm_btn.visible = targeting
	_cancel_btn.visible = targeting
	_confirm_btn.disabled = _target == null

	var s := c.skill() if c != null else null
	_skill_btn.disabled = not (has_actor and battle.can_use_skill(c))
	if s != null:
		_skill_btn.text = "%s (%d STA)" % [s.display_name, s.stamina_cost]
		_skill_btn.tooltip_text = "%s\nMt %+d  Hit %+d  Crit %+d\nRecovery: sits out %d actions." % [
			s.description, s.might_bonus, s.hit_bonus, s.crit_bonus, BattleConfig.RECOVERY_SKILL]
	if has_actor:
		_focus_btn.text = "Focus (+%d STA)" % battle.focus_amount(c)

	if battle.is_over():
		_prompt_label.text = "The battle is over."
	elif battle.can_wait():
		_prompt_label.text = "Nobody is ready. Wait to let the enemies' countdowns run."
	elif c == null:
		_prompt_label.text = "Click a READY companion."
	elif not targeting:
		_prompt_label.text = "%s: choose an action." % c.display_name
	elif _target == null:
		_prompt_label.text = "%s: click an enemy to target." % c.display_name
	else:
		_prompt_label.text = "%s -> %s: Confirm (or click the target again)." % [c.display_name, _target.display_name]

	_forecast_label.text = ""
	if targeting and _target != null and c != null:
		var f := battle.forecast(c, _target, _mode == Mode.TARGET_SKILL)
		_forecast_label.text = "[b]Hit[/b] %d%%    [b]Crit[/b] %d%%    [b]Damage[/b] %d  [color=#c8a060](crit %d)[/color]    [color=#9aa0aa]%s HP %d[/color]" % [
			f.hit, f.crit, f.damage, f.crit_damage, _target.display_name, _target.hp]


func _draw_log() -> void:
	while _logged < battle.log_lines.size():
		var line := battle.log_lines[_logged]
		_logged += 1
		var color := "#c9ccd4"
		if line.begins_with("=="):
			color = "#e8c860"
		elif line.contains("is gone") or line.contains("injured") or line.begins_with("Defeat"):
			color = "#f06060"
		elif line.contains("CRITICAL"):
			color = "#ffa040"
		elif line.contains("defeated") or line.begins_with("Victory"):
			color = "#70e070"
		elif line.contains("Miss") or line.contains("dodges"):
			color = "#8890a0"
		elif not line.begins_with("  "):
			color = "#ffffff"
		_log.append_text("[color=%s]%s[/color]\n" % [color, line])


func _stat_sheet(u: Combatant, keys: Array[String]) -> String:
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s %d" % [k, u.max_hp() if k == Stat.HP else u.stat(k)])
	return "  ".join(parts)


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "Realm of Talos - battle prototype"
	title.add_theme_font_size_override("font_size", 18)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_tick_label.add_theme_font_size_override("font_size", 18)
	_tick_label.add_theme_color_override("font_color", Color(0.91, 0.78, 0.38))
	top.add_child(_tick_label)
	_seed_label.add_theme_color_override("font_color", COLOR_MUTED)
	top.add_child(_seed_label)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(start_battle)
	top.add_child(restart)

	# Battlefield: companions on the left (rightmost is nearest), enemies on the right.
	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", 12)
	root.add_child(field)
	_companion_row.add_theme_constant_override("separation", 10)
	_companion_row.alignment = BoxContainer.ALIGNMENT_END
	_companion_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enemy_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_child(_companion_row)
	var vs := Label.new()
	vs.text = "vs"
	vs.add_theme_font_size_override("font_size", 22)
	vs.add_theme_color_override("font_color", COLOR_MUTED)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_child(vs)
	_enemy_row.add_theme_constant_override("separation", 10)
	field.add_child(_enemy_row)

	# Bottom: actions + log
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 190)
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	var actions_panel := _panel()
	actions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_panel.size_flags_stretch_ratio = 1.1
	bottom.add_child(actions_panel)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions_panel.add_child(actions)
	_prompt_label.add_theme_font_size_override("font_size", 16)
	actions.add_child(_prompt_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	actions.add_child(buttons)
	_setup_button(_attack_btn, "Attack", "Strike an enemy with the equipped weapon.\nRecovery: sits out %d action." % BattleConfig.RECOVERY_ATTACK, _on_attack, buttons)
	_setup_button(_skill_btn, "Skill", "", _on_skill, buttons)
	_setup_button(_guard_btn, "Guard", "Until the end of this tick: take 50%% damage, enemies are 4x as likely to target you.\nRecovery: sits out %d action." % BattleConfig.RECOVERY_GUARD, _on_guard, buttons)
	_setup_button(_focus_btn, "Focus", "Restore 10%% of max stamina.\nRecovery: sits out %d action." % BattleConfig.RECOVERY_FOCUS, _on_focus, buttons)
	_setup_button(_wait_btn, "Wait", "Nobody can act: let one tick pass.", _on_wait, buttons)
	_setup_button(_confirm_btn, "Confirm", "", _on_confirm, buttons)
	_setup_button(_cancel_btn, "Cancel", "", _on_cancel, buttons)
	_forecast_label.bbcode_enabled = true
	_forecast_label.fit_content = true
	_forecast_label.scroll_active = false
	_forecast_label.add_theme_font_size_override("normal_font_size", 17)
	_forecast_label.add_theme_font_size_override("bold_font_size", 17)
	actions.add_child(_forecast_label)
	var legend := Label.new()
	legend.text = "RECOVERING: N = sits out the next N actions.   Enemy cards show the pending intent and its countdown.\nThe rightmost companion stands nearest the enemies and is targeted most."
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", COLOR_MUTED)
	actions.add_child(legend)

	var log_panel := _panel()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(log_panel)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(_log)

	# Result overlay
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var result_panel := _panel()
	result_panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 16)
	result_panel.add_child(result_box)
	_result_label.add_theme_font_size_override("font_size", 48)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(_result_label)
	var again := Button.new()
	again.text = "Restart"
	again.custom_minimum_size = Vector2(180, 44)
	again.pressed.connect(start_battle)
	result_box.add_child(again)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	return p


func _setup_button(b: Button, text: String, tooltip: String, handler: Callable, parent: Control) -> void:
	b.text = text
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(handler)
	parent.add_child(b)
