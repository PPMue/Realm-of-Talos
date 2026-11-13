class_name BattleScreen
extends Control
## Battle screen. Builds the UI, reads Battle state, sends commands and plays back what happened.
## No battle rules live here; see res://scripts/battle/battle.gd.
##
## Layout: the chosen companion's art and actions on the left, enemies standing on the stage,
## the party as a row of panels along the bottom (rightmost = nearest the enemies).
##
## It plays a battle prepared by the run (Run.start_battle) and does not own the game loop: when the
## battle is over it emits `finished`; the owner applies the result to the run and hands the report
## back with show_report(), and the result screen's button emits `closed`.

signal finished(battle: Battle)
signal closed

## TARGET_SPELL: a black spell waiting for an enemy. TARGET_ALLY: a white spell waiting for a companion.
enum Mode { IDLE, TARGET_ATTACK, TARGET_ART, TARGET_SPELL, TARGET_ALLY }

## The part of the screen the enemies stand in (margins from each edge, at 1920x1080).
const STAGE_LEFT := 670.0
const STAGE_RIGHT := 24.0
const INSPECT_W := 600.0
const STAGE_TOP := 70.0
const PARTY_HEIGHT := 276.0
## With this many enemies or more, every second one stands a step back and the art may overlap.
const STAGGER_FROM := 3
## How much wider than its slot an enemy's art may be, side by side and staggered.
const ART_OVERLAP := 1.1
const ART_OVERLAP_STAGGERED := 1.45

var battle: Battle

var _selected: CompanionUnit
var _mode := Mode.IDLE
## The art waiting for a target while in TARGET_ART.
var _art: CombatArtData
## The spell waiting for a target while in TARGET_SPELL or TARGET_ALLY.
var _spell: SpellData
var _hot_enemy: EnemyUnit
var _hot_ally: CompanionUnit
## The action menu shows the selected companion's spells instead of their actions.
var _spell_menu := false
var _spell_page := 0
var _busy := false
var _skip := false
var _generation := 0
var _logged := 0

var _party_panels: Dictionary = {}   # CompanionUnit -> PartyPanel
var _enemy_views: Dictionary = {}    # EnemyUnit -> EnemyView

var _tick_label: Label
var _title: Label
var _menu := ActionMenu.new()
var _stage := Control.new()
var _party_row := HBoxContainer.new()
var _banner := SlantPanel.new()
var _banner_label: Label
var _banner_tween: Tween
var _popups := Control.new()
var _log_panel := PanelContainer.new()
var _log := RichTextLabel.new()
var _overlay := BattleResult.new()
## The sheet of what is known about one enemy or companion, shown while Shift is held over them.
var _inspect := SlantPanel.new()
var _inspect_title: Label
var _inspect_body: Label
var _inspected: Combatant
## Whether Shift is held, and where the pointer is (screen), as last heard from the input events.
var _shift := false
var _pointer := Vector2(-1, -1)
## Companion -> the text of their sheet, kept up to date by _refresh_party.
var _party_sheets: Dictionary = {}
var _grade_banner := SlantPanel.new()
var _grade_kicker: Label
var _grade_title: Label
var _grade_detail: Label
var _grade_tween: Tween


func _init() -> void:
	theme = UiTheme.theme()
	_build_ui()


## Shows `p_battle` (already set up by the run) from its first tick. `title` names the place.
func start(p_battle: Battle, title: String) -> void:
	_generation += 1
	_busy = false
	_skip = false
	battle = p_battle
	_title.text = title.to_upper()

	for child in _party_row.get_children() + _stage.get_children() + _popups.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_party_panels.clear()
	_party_sheets.clear()
	_enemy_views.clear()

	_party_row.add_child(_row_marker("the rear"))
	for c in battle.roster:
		var panel := PartyPanel.new()
		panel.setup(c.display_name, c.data.portrait, c.data.portrait_focus, c.data.figure_scale)
		panel.set_level(c.progress.level)
		panel.clicked.connect(pick_companion.bind(c))
		panel.hover_changed.connect(_on_ally_hover.bind(c))
		_party_row.add_child(panel)
		_party_panels[c] = panel
	_party_row.add_child(_row_marker("the front"))

	for e in battle.enemies:
		var view := EnemyView.new()
		view.setup(e)
		view.clicked.connect(strike_enemy.bind(e))
		view.hover_changed.connect(_on_enemy_hover.bind(e))
		_stage.add_child(view)
		_enemy_views[e] = view
	_layout_enemies()

	_log.clear()
	_logged = 0
	_selected = null
	_hot_enemy = null
	_hot_ally = null
	_spell = null
	_art = null
	_spell_menu = false
	_spell_page = 0
	_mode = Mode.IDLE
	_inspected = null
	_inspect.visible = false
	_overlay.visible = false
	_banner.visible = false
	_grade_banner.visible = false
	_layout_enemies.call_deferred()
	_after_change()


func is_busy() -> bool:
	return _busy


# ---------------------------------------------------------------- input

## Clicking a party panel: picks who acts, or, while a white spell waits for a target, casts it there.
func pick_companion(c: CompanionUnit) -> void:
	if _busy:
		return
	if _mode == Mode.TARGET_ALLY:
		cast_on_ally(c)
		return
	if not battle.can_act(c):
		return
	if c != _selected:
		_spell_menu = false
	_selected = c
	_mode = Mode.IDLE
	_hot_enemy = null
	_refresh()


## Casts the white spell waiting for a target on `c` (any companion, for spells that reach everyone).
func cast_on_ally(c: CompanionUnit) -> void:
	if _busy or _mode != Mode.TARGET_ALLY or _spell == null:
		return
	if battle.cast(_selected, _spell, c):
		_commit(_selected)


## Points at a companion while a white spell waits for a target, to see what it would do.
func point_at_ally(c: CompanionUnit) -> void:
	_hot_ally = c if (_mode == Mode.TARGET_ALLY and c != null and battle.line().has(c) and not c.is_injured()) else null
	_refresh_party()


func choose_action(id: String) -> void:
	if _busy or battle.is_over():
		return
	if id == ActionMenu.WAIT:
		if battle.wait():
			_commit(null)
		return
	var c := _selected
	if not battle.can_act(c):
		return
	match id:
		ActionMenu.MAGIC:
			if not c.spells().is_empty():
				_spell_menu = true
				_spell_page = 0
				_clear_targeting()
				_refresh()
			return
		ActionMenu.BACK:
			_spell_menu = false
			_clear_targeting()
			_refresh()
			return
		ActionMenu.MORE:
			_spell_page = (_spell_page + 1) % ActionMenu.spell_pages(c.spells().size())
			_clear_targeting()
			_refresh()
			return
	var spell_index := ActionMenu.spell_index(id)
	if spell_index >= 0:
		var spells := c.spells()
		if spell_index < spells.size() and battle.can_cast(c, spells[spell_index]):
			_toggle_spell(spells[spell_index])
		return
	var art_index := ActionMenu.art_index(id)
	if art_index >= 0:
		var arts := c.arts()
		if art_index < arts.size() and battle.can_use_art(c, arts[art_index]):
			_toggle_targeting(Mode.TARGET_ART, arts[art_index])
		return
	match id:
		ActionMenu.ATTACK:
			_toggle_targeting(Mode.TARGET_ATTACK)
		ActionMenu.GUARD:
			if battle.guard(c):
				_commit(c)
		ActionMenu.FOCUS:
			if battle.focus(c):
				_commit(c)


## Points at an enemy while choosing a target, to see the forecast. Pass null to stop pointing.
func point_at_enemy(e: EnemyUnit) -> void:
	_hot_enemy = e if (_aims_at_enemies() and e != null and e.is_alive()) else null
	_refresh_enemies()


func strike_enemy(e: EnemyUnit) -> void:
	if _busy or not _aims_at_enemies() or not e.is_alive():
		return
	var c := _selected
	var done := false
	match _mode:
		Mode.TARGET_ART:
			done = battle.use_art(c, _art, e)
		Mode.TARGET_SPELL:
			done = battle.cast(c, _spell, e)
		_:
			done = battle.attack(c, e)
	if done:
		_commit(c)


## Right-click or Esc: stop choosing a target; with no target pending, leave the spell list.
## Shows the sheet of what is known about `u`, an enemy or a companion (name, stats, and what is on
## them now): over an enemy's art, above a companion's portrait. null puts the sheet away.
func inspect(u: Combatant) -> void:
	if u != null and not _enemy_views.has(u) and not _party_panels.has(u):
		u = null
	_inspected = u
	_inspect.visible = u != null
	if u == null:
		return
	_fill_inspect()
	var node: Control = _enemy_views[u] if u is EnemyUnit else _party_panels[u]
	var r := node.get_global_rect()
	var at := r.get_center() - global_position - Vector2(_inspect.size.x * 0.5, 120.0)
	if u is CompanionUnit:
		at.y = r.position.y - global_position.y - _inspect.size.y - 12.0
	_inspect.position = Vector2(clampf(at.x, 16.0, maxf(16.0, size.x - _inspect.size.x - 16.0)),
		clampf(at.y, 16.0, maxf(16.0, size.y - _inspect.size.y - 16.0)))


## Shift held over someone shows their sheet; anything else puts it away.
func _update_inspect() -> void:
	var want: Combatant = null
	if _shift and not _overlay.visible:
		want = _unit_at(_pointer)
	if want != _inspected:
		inspect(want)


func _fill_inspect() -> void:
	var text := _enemy_tooltip(_inspected) if _inspected is EnemyUnit else String(_party_sheets.get(_inspected, ""))
	var cut := text.find("\n")
	_inspect_title.text = _inspected.display_name
	var body := text.substr(cut + 1) if cut >= 0 else ""
	_inspect_body.text = body
	var inner := INSPECT_W - 48.0
	# The label knows its own height once it has its width.
	_inspect_body.size = Vector2(inner, 0)
	var h := _inspect_body.get_minimum_size().y
	_inspect_body.size = Vector2(inner, h)
	_inspect.size = Vector2(INSPECT_W, 64.0 + h + 22.0)


## The companion or living enemy under a point of the screen (global). Where enemy art overlaps, the
## nearest one.
func _unit_at(point: Vector2) -> Combatant:
	for c: CompanionUnit in _party_panels:
		var panel: PartyPanel = _party_panels[c]
		if panel.visible and panel.get_global_rect().has_point(point):
			return c
	var best: EnemyUnit = null
	var best_d := INF
	for e: EnemyUnit in _enemy_views:
		var view: EnemyView = _enemy_views[e]
		var r := view.get_global_rect()
		if e.is_alive() and r.has_point(point):
			var d := absf(r.get_center().x - point.x)
			if d < best_d:
				best_d = d
				best = e
	return best


func cancel_targeting() -> void:
	if _busy:
		return
	if _mode != Mode.IDLE:
		_clear_targeting()
	elif _spell_menu:
		_spell_menu = false
	else:
		return
	_refresh()


func _clear_targeting() -> void:
	_mode = Mode.IDLE
	_art = null
	_spell = null
	_hot_enemy = null
	_hot_ally = null


func _toggle_targeting(mode: Mode, art: CombatArtData = null) -> void:
	var same := _mode == mode and _art == art
	_clear_targeting()
	_mode = Mode.IDLE if same else mode
	_art = null if same else art
	if _mode != Mode.IDLE and battle.living_enemies().size() == 1:
		_hot_enemy = battle.living_enemies()[0]
	_aim_at_pointer()
	_refresh()


func _toggle_spell(sp: SpellData) -> void:
	var mode := Mode.TARGET_ALLY if sp.targets_allies() else Mode.TARGET_SPELL
	var same := _mode == mode and _spell == sp
	_clear_targeting()
	if not same:
		_mode = mode
		_spell = sp
		if mode == Mode.TARGET_SPELL and battle.living_enemies().size() == 1:
			_hot_enemy = battle.living_enemies()[0]
		if mode == Mode.TARGET_ALLY and battle.line().size() == 1:
			_hot_ally = battle.line()[0]
		_aim_at_pointer()
	_refresh()


## An order given by key while the pointer already rests on an enemy (or, for a white spell, on a
## companion) aims there at once, so the forecast shows without moving the mouse off and back on.
func _aim_at_pointer() -> void:
	var u := _unit_at(_pointer)
	if _aims_at_enemies() and u is EnemyUnit:
		_hot_enemy = u
	elif _mode == Mode.TARGET_ALLY and u is CompanionUnit and battle.line().has(u) and not (u as CompanionUnit).is_injured():
		_hot_ally = u


func _aims_at_enemies() -> bool:
	return _mode == Mode.TARGET_ATTACK or _mode == Mode.TARGET_ART or _mode == Mode.TARGET_SPELL


## True while choosing a target for an art or spell that strikes every enemy: all of them are lit at once.
func _targets_all() -> bool:
	if _mode == Mode.TARGET_SPELL:
		return _spell != null and _spell.targeting == SpellData.Targeting.ALL_ENEMIES
	return _mode == Mode.TARGET_ART and _art != null and _art.hits_all_enemies


func _on_ally_hover(inside: bool, c: CompanionUnit) -> void:
	if _busy or _mode != Mode.TARGET_ALLY:
		return
	if inside:
		point_at_ally(c)
	elif _hot_ally == c and battle.line().size() > 1:
		point_at_ally(null)


func _on_enemy_hover(inside: bool, e: EnemyUnit) -> void:
	if _busy:
		return
	if inside:
		point_at_enemy(e)
	elif _hot_enemy == e and battle.living_enemies().size() > 1:
		point_at_enemy(null)


## _input rather than _unhandled_input: right-click must cancel even over an enemy or a panel.
## Holding Shift while pointing at an enemy or a companion shows what is known about them; the
## sheet goes when Shift is let go or the pointer leaves them.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or battle == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
		_shift = motion.shift_pressed
		_update_inspect()
		return
	var shift := event as InputEventKey
	if shift != null and shift.keycode == KEY_SHIFT:
		# Not an order and not a skip: only the sheet.
		_shift = shift.pressed
		_update_inspect()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if _overlay.visible:
			# A click anywhere moves the result on; the way back is its own button.
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_overlay.advance()
			return
		if _busy:
			_skip = true
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _overlay.visible:
		if key.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			if _overlay.is_done():
				close()
			else:
				_overlay.advance()
		return
	if _busy:
		_skip = true
		return
	var number := _number_key(key.keycode)
	if number > 0:
		var id := _menu.action_for_key(number)
		if id != "":
			choose_action(id)
		return
	match key.keycode:
		KEY_ESCAPE:
			cancel_targeting()
		KEY_L:
			_toggle_log()
		KEY_SPACE, KEY_ENTER:
			if battle.can_wait():
				choose_action(ActionMenu.WAIT)
			elif _targets_all() and not battle.living_enemies().is_empty():
				strike_enemy(battle.living_enemies()[0])
			elif _aims_at_enemies() and _hot_enemy != null:
				strike_enemy(_hot_enemy)
			elif _mode == Mode.TARGET_ALLY and _spell != null and _spell.targets_all():
				cast_on_ally(battle.line()[0])
			elif _mode == Mode.TARGET_ALLY and _hot_ally != null:
				cast_on_ally(_hot_ally)


## 1-9 from the top row or the keypad, else 0.
static func _number_key(code: Key) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return 0


# ---------------------------------------------------------------- playback

## A command went through: show what it did, step by step, then hand control back.
func _commit(actor: CompanionUnit) -> void:
	_clear_targeting()
	_spell_menu = false
	_busy = true
	_skip = false
	_selected = actor
	for e: EnemyUnit in _enemy_views:
		var view: EnemyView = _enemy_views[e]
		view.set_forecast(null)
		view.clear_targeting()
	for c: CompanionUnit in _party_panels:
		var panel: PartyPanel = _party_panels[c]
		panel.set_selection(false, false)
		panel.set_spell_target(false, false)
	if actor != null:
		var panel: PartyPanel = _party_panels[actor]
		panel.set_stamina(actor.stamina, actor.max_stamina())
		if actor.recovery > 0 and not battle.is_lone_companion(actor):
			panel.set_status(PartyPanel.Status.RECOVERING, actor.recovery)
	_refresh_menu()
	_tick_label.text = _turn_text()
	_draw_log()
	_play(battle.events.duplicate(), _generation)


func _play(events: Array[Dictionary], generation: int) -> void:
	for ev in events:
		var pause := _show_event(ev)
		if pause > 0.0:
			await get_tree().create_timer(pause * (0.2 if _skip else 1.0)).timeout
			if generation != _generation:
				return
	_busy = false
	_after_change()
	if battle.is_over():
		finished.emit(battle)


## Shows one event and returns how long to hold before the next.
func _show_event(ev: Dictionary) -> float:
	match ev.type:
		"strike":
			var art: CombatArtData = ev.get("art")
			if art == null:
				return 0.0
			_show_banner("%s  -  %s" % [ev.actor.display_name.to_upper(), art.display_name.to_upper()], UiTheme.GOLD)
			(_party_panels[ev.actor] as PartyPanel).play_pulse(UiTheme.GOLD)
			return 0.3
		"cast":
			var sp: SpellData = ev.spell
			var color := UiTheme.school_color(sp.school)
			_show_banner("%s  -  %s" % [ev.actor.display_name.to_upper(), sp.display_name.to_upper()], color)
			(_party_panels[ev.actor] as PartyPanel).play_pulse(color)
			return 0.35
		"heal":
			var panel: PartyPanel = _party_panels[ev.target]
			panel.set_hp(ev.hp, (ev.target as CompanionUnit).max_hp())
			panel.play_pulse(UiTheme.HEAL)
			_popup(panel.popup_anchor(), "+%d" % ev.amount, UiTheme.HEAL, 64)
			return 0.32
		"revived":
			var panel: PartyPanel = _party_panels[ev.target]
			panel.set_status(PartyPanel.Status.NONE)
			_popup(panel.popup_anchor() + Vector2(0, -56), "BACK UP", UiTheme.READY, 46)
			return 0.4
		"cleanse":
			var removed: Array = ev.removed
			if removed.is_empty():
				return 0.0
			var panel: PartyPanel = _party_panels[ev.target]
			panel.set_effects("")
			_popup(panel.popup_anchor() + Vector2(0, 40), "CLEANSED", UiTheme.HEAL, 40)
			return 0.3
		"delay":
			var view: EnemyView = _enemy_views[ev.target]
			view.show_delay(ev.countdown)
			_popup(view.popup_anchor() + Vector2(0, 60), "DELAYED +%d" % ev.ticks, UiTheme.WHITE_MAGIC, 46)
			return 0.42
		"delay_blocked":
			var view: EnemyView = _enemy_views[ev.target]
			_popup(view.popup_anchor() + Vector2(0, 60), "ALREADY DELAYED", UiTheme.MUTED, 34)
			return 0.3
		"proficiency":
			return 0.0
		"grade_up":
			_show_grade_up(ev)
			return 1.7
		"guard":
			var panel: PartyPanel = _party_panels[ev.actor]
			panel.play_pulse(UiTheme.INTENT_COLORS[EnemyActionData.Intent.DEFEND])
			_popup(panel.popup_anchor(), "GUARD", UiTheme.INTENT_COLORS[EnemyActionData.Intent.DEFEND], 44)
			return 0.3
		"focus":
			var panel: PartyPanel = _party_panels[ev.actor]
			panel.play_pulse(UiTheme.STA)
			_popup(panel.popup_anchor(), "+%d STA" % ev.amount, UiTheme.STA, 44)
			return 0.3
		"wait":
			return 0.15
		"miss":
			_popup(_anchor_of(ev.target), "MISS", UiTheme.MUTED, 46)
			return 0.32
		"damage":
			_show_damage(ev)
			if ev.get("effective", false):
				_popup(_anchor_of(ev.target) + Vector2(0, -74), "EFFECTIVE!", UiTheme.EFFECTIVE, 38)
			return 0.36 if ev.crit or ev.get("effective", false) else 0.3
		"defeated":
			var view: EnemyView = _enemy_views[ev.target]
			view.play_defeat()
			return 0.35
		"injured":
			var panel: PartyPanel = _party_panels[ev.target]
			panel.set_status(PartyPanel.Status.INJURED)
			_popup(panel.popup_anchor() + Vector2(0, -50), "INJURED", UiTheme.INJURED, 50)
			return 0.45
		"countdown":
			var countdowns: Dictionary = ev.countdowns
			for e: EnemyUnit in countdowns:
				var view: EnemyView = _enemy_views[e]
				view.show_countdown(countdowns[e])
			return 0.22
		"enemy_action":
			var view: EnemyView = _enemy_views[ev.enemy]
			var action: EnemyActionData = ev.action
			_show_banner("%s  -  %s" % [ev.enemy.display_name.to_upper(), action.display_name.to_upper()], UiTheme.INTENT_COLORS[action.intent])
			view.play_lunge()
			return 0.5
		"effect":
			var helpful: bool = ev.get("helpful", ev.target is EnemyUnit)
			_popup(_anchor_of(ev.target) + Vector2(0, 40), ev.name.to_upper(),
				UiTheme.GOLD if helpful else UiTheme.INTENT_COLORS[EnemyActionData.Intent.DEBUFF], 40)
			if ev.target is EnemyUnit:
				var view: EnemyView = _enemy_views[ev.target]
				view.refresh(false, false, view.details)
			return 0.32
		"intent":
			var view: EnemyView = _enemy_views[ev.enemy]
			view.refresh(false, false, view.details)
			return 0.0
		"dot":
			var text := "-%d %s" % [ev.amount, String(ev.name).to_upper()]
			if ev.target is EnemyUnit:
				var view: EnemyView = _enemy_views[ev.target]
				view.show_hp(ev.hp)
				view.play_hit(false)
			else:
				var c: CompanionUnit = ev.target
				var panel: PartyPanel = _party_panels[c]
				panel.set_hp(ev.hp, c.max_hp())
				panel.play_pulse(UiTheme.POISON)
			_popup(_anchor_of(ev.target), text, UiTheme.POISON, 48)
			return 0.34
		"riposte":
			# A companion's stance (Riposte, Set Spear) answering the enemy that struck them.
			var stance: PartyPanel = _party_panels[ev.source]
			stance.play_pulse(UiTheme.GOLD)
			_popup(stance.popup_anchor() + Vector2(0, -60), "STRIKES BACK", UiTheme.GOLD, 40)
			return 0.25
		"reflect":
			var panel: PartyPanel = _party_panels[ev.target]
			panel.play_pulse(UiTheme.REFLECT)
			_popup(panel.popup_anchor() + Vector2(0, -60), "REFLECTED", UiTheme.REFLECT, 44)
			_popup(_anchor_of(ev.source) + Vector2(0, 50), "REFLECTS %d" % ev.amount, UiTheme.REFLECT, 38)
			return 0.3
		"enemy_heal":
			var view: EnemyView = _enemy_views[ev.target]
			view.show_hp(ev.hp)
			_popup(view.popup_anchor(), "+%d" % ev.amount, UiTheme.HEAL, 64)
			return 0.36
		"hasten":
			var view: EnemyView = _enemy_views[ev.target]
			view.show_hasten(ev.countdown)
			_popup(view.popup_anchor() + Vector2(0, 60), "SOONER -%d" % ev.ticks, UiTheme.HASTE, 44)
			return 0.36
		"recovery":
			var c: CompanionUnit = ev.target
			var panel: PartyPanel = _party_panels[c]
			panel.set_status(PartyPanel.Status.RECOVERING, ev.recovery)
			panel.play_pulse(UiTheme.HASTE)
			_popup(panel.popup_anchor() + Vector2(0, -40), "+%d RECOVERY" % ev.ticks, UiTheme.HASTE, 40)
			return 0.3
		"phase":
			_show_phase(ev)
			return 1.8
	return 0.0


func _show_damage(ev: Dictionary) -> void:
	var text := str(ev.amount)
	var font_size := 68
	var color := UiTheme.TEXT
	if ev.crit:
		text = "CRIT %d!" % ev.amount
		font_size = 88
		color = UiTheme.GOLD
	if ev.target is EnemyUnit:
		var view: EnemyView = _enemy_views[ev.target]
		view.show_hp(ev.hp)
		view.play_hit(ev.crit)
		_popup(view.popup_anchor(), text, color, font_size)
	else:
		var c: CompanionUnit = ev.target
		var panel: PartyPanel = _party_panels[c]
		panel.set_hp(ev.hp, c.max_hp())
		panel.play_hit(ev.crit)
		_popup(panel.popup_anchor(), text, UiTheme.GOLD if ev.crit else UiTheme.INJURED, font_size)


func _anchor_of(unit: Combatant) -> Vector2:
	if unit is EnemyUnit:
		return (_enemy_views[unit] as EnemyView).popup_anchor()
	return (_party_panels[unit] as PartyPanel).popup_anchor()


## A number or word that pops out of a unit, rises and fades.
func _popup(at: Vector2, text: String, color: Color, font_size: int) -> void:
	var l := UiTheme.label(text, font_size, color, true, 14)
	_popups.add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size * 0.5
	l.position = at - global_position - l.size * 0.5 + Vector2(randf_range(-26, 26), randf_range(-10, 10))
	l.scale = Vector2(0.5, 0.5)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.09)
	t.tween_property(l, "scale", Vector2.ONE, 0.08)
	t.parallel().tween_property(l, "position:y", l.position.y - 78.0, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)


func _show_banner(text: String, color: Color) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_label.text = text
	_banner.border = color
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.08)
	_banner_tween.tween_interval(0.75)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.2)


## An enemy changed to its second action list: the big banner, in the danger colour.
func _show_phase(ev: Dictionary) -> void:
	var e: EnemyUnit = ev.enemy
	var color := UiTheme.DANGER
	_grade_kicker.text = "PHASE TWO"
	_grade_title.text = "%s  ·  %s" % [e.display_name.to_upper(), String(ev.title).to_upper()]
	_grade_title.add_theme_color_override("font_color", color)
	_grade_detail.text = String(ev.get("text", "")).to_upper()
	_grade_banner.border = color
	var view: EnemyView = _enemy_views[e]
	view.refresh(false, false, view.details)
	view.play_lunge()
	_popup(view.popup_anchor(), String(ev.title).to_upper(), color, 50)
	_play_big_banner()


## A weapon or magic grade went up: a banner over the stage naming the companion and the grade. What
## the grade teaches is learned after the battle and shown on the result (see BattleResult).
func _show_grade_up(ev: Dictionary) -> void:
	var c: CompanionUnit = ev.actor
	var grade := Proficiency.grade_name(ev.grade)
	var kind := ""
	var color := UiTheme.GOLD
	if ev.get("magic", false):
		kind = SpellData.school_name(ev.school).to_upper()
		color = UiTheme.school_color(ev.school)
		_grade_kicker.text = "MAGIC GRADE UP"
		_grade_detail.text = "A NEW SPELL AFTER THE BATTLE"
	else:
		kind = WeaponData.type_name(ev.weapon_type).to_upper()
		_grade_kicker.text = "GRADE UP"
		_grade_detail.text = "A NEW COMBAT ART AFTER THE BATTLE"
	_grade_title.text = "%s  ·  %s  %s" % [c.display_name.to_upper(), kind, grade]
	_grade_title.add_theme_color_override("font_color", color)
	_grade_banner.border = color
	var panel: PartyPanel = _party_panels[c]
	panel.play_pulse(color)
	_popup(panel.popup_anchor() + Vector2(0, -60), "%s %s" % [kind, grade], color, 46)
	_play_big_banner()


## Shows the big banner (grade-up or phase) over the stage for a moment.
func _play_big_banner() -> void:
	if _grade_tween != null:
		_grade_tween.kill()
	# Takes the place of the art-name banner, which shows in the same spot.
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.visible = false
	_grade_banner.visible = true
	_grade_banner.modulate.a = 0.0
	_grade_banner.scale = Vector2(0.9, 0.9)
	_grade_tween = create_tween()
	_grade_tween.tween_property(_grade_banner, "modulate:a", 1.0, 0.12)
	_grade_tween.parallel().tween_property(_grade_banner, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_grade_tween.tween_interval(1.4 * (0.3 if _skip else 1.0))
	_grade_tween.tween_property(_grade_banner, "modulate:a", 0.0, 0.25)
	_grade_tween.tween_callback(func() -> void: _grade_banner.visible = false)


## The result screen: won or lost and what it gave or cost, the company's XP, then every level gained
## shown stat by stat (see BattleResult).
func show_report(report: BattleReport) -> void:
	inspect(null)
	_overlay.open(report, battle.roster, battle)


## Result screen button: back to whoever started the battle.
func close() -> void:
	if battle != null and battle.is_over() and _overlay.visible:
		closed.emit()


# ---------------------------------------------------------------- drawing from state

## After any change: keep the selection if that companion can still act, else pick the next ready one.
func _after_change() -> void:
	if not battle.can_act(_selected):
		var ready := battle.ready_companions()
		_selected = ready[0] if not ready.is_empty() else null
		_clear_targeting()
		_spell_menu = false
	_refresh()


## "TURN 3": players count turns where the rules count ticks. While an order is being played out it
## is the turn that order began; while the commander is choosing, the one about to begin.
func _turn_text() -> String:
	var n := battle.tick if (_busy or battle.is_over()) else battle.tick + 1
	return "TURN %d" % maxi(1, n)


func _refresh() -> void:
	_tick_label.text = _turn_text()
	_refresh_party()
	_refresh_enemies()
	_refresh_menu()
	_draw_log()


func _refresh_party() -> void:
	var line := battle.line()
	var aim := _aim_kinds()
	var weights := battle.target_weights()
	var total := 0.0
	for w in weights:
		total += w
	var rev_weights := battle.target_weights(true)
	var rev_total := 0.0
	for w in rev_weights:
		rev_total += w
	for c: CompanionUnit in _party_panels:
		var panel: PartyPanel = _party_panels[c]
		panel.modulate.a = 1.0
		panel.set_hp(c.hp, c.max_hp())
		panel.set_stamina(c.stamina, c.max_stamina())
		if c.is_injured():
			panel.set_status(PartyPanel.Status.INJURED)
		elif battle.is_over():
			panel.set_status(PartyPanel.Status.NONE)
		elif battle.can_act(c):
			panel.set_status(PartyPanel.Status.READY)
		else:
			panel.set_status(PartyPanel.Status.RECOVERING, c.recovery)
		var effects: Array[String] = []
		var harmful := false
		for e in c.effects:
			effects.append(e.describe())
			harmful = harmful or e.damage_per_tick > 0
		panel.set_effects("  ".join(effects), harmful)
		var share := 0
		var rev_share := 0
		var index := line.find(c)
		if index >= 0 and total > 0.0:
			share = roundi(weights[index] / total * 100.0)
			rev_share = roundi(rev_weights[index] / rev_total * 100.0)
		var aim_tip := "Enemies aim at this spot %d%% of the time." % share
		# Nobody aims at someone who is down.
		if c.is_injured() or index < 0 or battle.is_over():
			panel.set_threat("")
		elif aim.y == 0:
			panel.set_threat("%d%%" % share)
		elif aim.x == 0:
			panel.set_threat("%d%%" % rev_share, true)
			aim_tip = "Every enemy here aims from the left (mirrored): its single attacks hit this spot %d%% of the time." % rev_share
		else:
			panel.set_threat("%d%% · %d%%" % [share, rev_share])
			aim_tip = ("Most enemies aim at this spot %d%% of the time; those that aim from the left (mirrored) %d%% of the time." %
				[share, rev_share])
		var kind := c.weapon().weapon_type
		var step := c.progress.progress_to_next(kind)
		var arts: Array[String] = []
		for a in c.arts():
			arts.append(a.display_name)
		var magic := ""
		for s in c.progress.spell_schools():
			magic += "\n%s %s" % [SpellData.school_name(s), Proficiency.grade_name(c.progress.magic_grade(s))]
		if not c.spells().is_empty():
			var spells: Array[String] = []
			for sp in c.spells():
				spells.append("%s %d/%d" % [sp.display_name, c.progress.uses_left(sp), c.progress.max_uses(sp)])
			magic += "\nSpells: " + ", ".join(spells)
		# What they are: each trait and what it does.
		for t in c.traits():
			magic += "%s%s: %s" % ["\n\n" if t == c.traits()[0] else "\n", t.display_name, ", ".join(t.lines())]
			if not t.drawback_lines().is_empty():
				magic += "; " + ", ".join(t.drawback_lines())
		# Not a tooltip: the battle screen shows it while Shift is held (see inspect).
		var held := c.weapon().display_name
		for note in StoreScreen.weapon_notes(c.weapon()):
			held += "\n  " + note
		_party_sheets[c] = "%s\nLevel %d  ·  %s\n%s\n\n%s %s%s\nArts: %s%s\n\n%s" % [
			c.display_name, c.progress.level, held, _stat_sheet(c, Stat.COMPANION_KEYS), WeaponData.type_name(kind),
			Proficiency.grade_name(c.progress.grade(kind)),
			"" if step.y == 0 else "  (%d / %d to %s)" % [step.x, step.y, Proficiency.grade_name(c.progress.grade(kind) + 1)],
			", ".join(arts) if not arts.is_empty() else "none", magic, aim_tip]
		if c == _inspected:
			_fill_inspect()
		panel.set_selection(c == _selected, not _busy and battle.can_act(c))
		# White magic cannot reach someone who is down.
		if _mode == Mode.TARGET_ALLY and not _busy and _spell != null and line.has(c) and not c.is_injured():
			var hot := _spell.targets_all() or c == _hot_ally
			panel.set_spell_target(true, hot, _ally_preview(c),
				float(battle.hp_after_heal(_selected, _spell, c)) if _spell.heals else -INF)
		else:
			panel.set_spell_target(false, false)


## How the living enemies aim their single-target attacks: x = enemies that aim the usual way, y = those
## that aim from the left (mirrored weights). An enemy with both kinds counts in both.
func _aim_kinds() -> Vector2i:
	var out := Vector2i.ZERO
	for e in battle.living_enemies():
		var normal := false
		var mirrored := false
		for a in e.actions():
			if a.targeting != EnemyActionData.Targeting.SINGLE:
				continue
			if e.aims_reversed(a):
				mirrored = true
			else:
				normal = true
		out += Vector2i(1 if normal else 0, 1 if mirrored else 0)
	return out


## What the white spell waiting for a target would do to `c`, for the panel preview.
func _ally_preview(c: CompanionUnit) -> String:
	var parts: Array[String] = []
	if _spell.heals:
		var after := battle.hp_after_heal(_selected, _spell, c)
		parts.append("HP %d → %d" % [c.hp, after])
	if _spell.cleanse:
		var harmful: Array[String] = []
		for e in c.effects:
			if e.is_harmful():
				harmful.append(e.display_name.to_upper())
		parts.append("CLEARS " + ", ".join(harmful) if not harmful.is_empty() else "NO DEBUFFS")
	if _spell.effect != null:
		parts.append("+ " + _spell.effect.display_name.to_upper())
	return "  ·  ".join(parts)


func _refresh_enemies() -> void:
	var targeting := _aims_at_enemies() and not _busy
	for e: EnemyUnit in _enemy_views:
		var view: EnemyView = _enemy_views[e]
		var hot := targeting and (e == _hot_enemy or (_targets_all() and e.is_alive()))
		view.refresh(targeting, hot, _enemy_tooltip(e))
		if e == _inspected:
			# The sheet follows what happens to the enemy, and goes when the enemy does.
			if e.is_alive():
				_fill_inspect()
			else:
				inspect(null)
		if hot and _selected != null and _mode == Mode.TARGET_SPELL:
			var note := ""
			if _spell.delay_ticks > 0:
				note = "ALREADY DELAYED" if e.delayed else "DELAYS +%d" % _spell.delay_ticks
			view.set_forecast(battle.spell_forecast(_selected, _spell, e), 1, note)
		elif hot and _selected != null:
			var art := _art if _mode == Mode.TARGET_ART else null
			# The forecast knows how many times it lands: an art's strikes, or a weapon that strikes twice.
			var f := battle.forecast(_selected, e, art)
			view.set_forecast(f, f.strikes if f != null else 1)
		else:
			view.set_forecast(null)


func _enemy_tooltip(e: EnemyUnit) -> String:
	var tip := "%s\n%s" % [e.display_name, _stat_sheet(e, Stat.ENEMY_KEYS)]
	if e.data.role != "":
		tip += "\n" + e.data.role
	for t in e.traits():
		tip += "\n\n" + EnemyTraits.describe(t)
	if e.ever_aims_reversed():
		tip += "\n\nAims from the left: its single-target attacks use the position weights mirrored."
	var effects: Array[String] = []
	for fx in e.effects:
		effects.append(fx.describe())
	if not effects.is_empty():
		tip += "\n\nNow: " + ", ".join(effects)
	if e.reflect_percent() > 0:
		tip += "\nWeapon strikes and arts that land on it deal %d%% of their damage back. Spells pass through." % e.reflect_percent()
	if e.delayed and e.is_alive():
		tip += "\n\nIts coming action has already been delayed once. Spells cannot delay it again until it acts."
	if e.hastened and e.is_alive():
		tip += "\n\nAn order brought its coming action forward."
	if e.data.has_phase() and e.phase == 0:
		tip += "\n\n" + ("At %d%% HP it changes." % e.data.phase_hp_percent if e.data.phase_trigger == EnemyData.PhaseTrigger.HP_BELOW
			else "When it is the last one standing, it changes.")
	return tip


func _refresh_menu() -> void:
	if battle.is_over() and not _busy:
		_menu.show_nothing()
	elif _selected != null:
		var active := ""
		if _mode == Mode.TARGET_ATTACK:
			active = ActionMenu.ATTACK
		elif _mode == Mode.TARGET_ART:
			active = ActionMenu.art_id(_selected.arts().find(_art))
		elif _mode == Mode.TARGET_SPELL or _mode == Mode.TARGET_ALLY:
			active = ActionMenu.spell_id(_selected.spells().find(_spell))
		if _spell_menu and not _selected.spells().is_empty():
			_menu.show_spells(_selected, battle, active, not _busy, _spell_page)
		else:
			_menu.show_companion(_selected, battle, active, not _busy)
	elif battle.can_wait() or _busy:
		_menu.show_wait(not _busy, _next_ready())
	else:
		_menu.show_nothing()


## The active companion with the least recovery left, or null.
func _next_ready() -> CompanionUnit:
	var best: CompanionUnit = null
	for c in battle.active_companions():
		if best == null or c.recovery < best.recovery:
			best = c
	return best


func _draw_log() -> void:
	while _logged < battle.log_lines.size():
		var line := battle.log_lines[_logged]
		_logged += 1
		var color := "#c9ccd4"
		if line.begins_with("=="):
			color = "#f4c552"
		elif line.contains("is gone") or line.contains("injured") or line.begins_with("Defeat"):
			color = "#ff5d5d"
		elif line.contains("CRITICAL"):
			color = "#ff9a45"
		elif line.contains("grade rises") or line.contains(" learns ") or line.contains("already knows every"):
			color = "#f4c552"
		elif line.contains(" recovers ") or line.contains("back on their feet") or line.contains("cleansed of"):
			color = "#8ff0a4"
		elif line.contains("delayed"):
			color = "#bfe6ff"
		elif line.contains(", effective"):
			color = "#ffd84a"
		elif line.contains("defeated") or line.begins_with("Victory"):
			color = "#86e27a"
		elif line.contains("Miss") or line.contains("dodges"):
			color = "#8890a0"
		elif not line.begins_with("  "):
			color = "#ffffff"
		_log.append_text("[color=%s]%s[/color]\n" % [color, line])


func _stat_sheet(u: Combatant, keys: Array[String]) -> String:
	var rows: Array[String] = []
	var row: Array[String] = []
	for k in keys:
		row.append("%s %d" % [k, u.max_hp() if k == Stat.HP else u.stat(k)])
		if row.size() == 4:
			rows.append("    ".join(row))
			row = []
	if not row.is_empty():
		rows.append("    ".join(row))
	return "\n".join(rows)


## Gives every enemy a column of the stage and sizes the art to fit.
## One or two enemies stand side by side at full size. From three, every second enemy stands
## a step back and the art is allowed to overlap, so it stays large instead of shrinking to fit.
func _layout_enemies() -> void:
	if battle == null or battle.enemies.is_empty():
		return
	var area := Rect2(STAGE_LEFT, STAGE_TOP, size.x - STAGE_LEFT - STAGE_RIGHT, size.y - STAGE_TOP - PARTY_HEIGHT)
	var count := battle.enemies.size()
	var staggered := count >= STAGGER_FROM
	var overlap := ART_OVERLAP_STAGGERED if staggered else ART_OVERLAP
	var largest := 0.0
	for e in battle.enemies:
		largest = maxf(largest, e.data.stage_scale)
	var tallest := area.size.y - EnemyView.PLATE_H - (EnemyView.BACK_RAISE if staggered else 0.0)
	# Art wider than its slot spills past the first and last slot; narrow the slots until it fits.
	var slot_w := minf(area.size.x / count, EnemyView.MAX_SLOT)
	var fit := 1.0
	for pass_index in 3:
		fit = minf(1.0, minf(slot_w * overlap, tallest) / (EnemyView.BASE_SIDE * largest))
		var spill := maxf(0.0, EnemyView.BASE_SIDE * largest * fit - slot_w)
		slot_w = minf((area.size.x - spill) / count, EnemyView.MAX_SLOT)
	var x := area.position.x + (area.size.x - slot_w * count) * 0.5
	for i in count:
		var e := battle.enemies[i]
		var view: EnemyView = _enemy_views[e]
		view.position = Vector2(x + slot_w * i, area.position.y)
		view.layout(Vector2(slot_w, area.size.y), EnemyView.BASE_SIDE * e.data.stage_scale * fit, staggered and i % 2 == 1)


func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := StageBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Enemies stand on the stage; _layout_enemies() places them.
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	resized.connect(_layout_enemies)

	# Chosen companion and their actions.
	_menu.position = Vector2(0, 60)
	_menu.action_pressed.connect(choose_action)
	add_child(_menu)

	# The party: the battle line, left = back, right = front.
	_party_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_party_row.offset_top = -(PartyPanel.H + PartyPanel.LIFT) - 14.0
	_party_row.offset_bottom = -14.0
	_party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_row.add_theme_constant_override("separation", 8)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_row)

	# Top bar.
	_title = UiTheme.label("", 22, Color(UiTheme.GOLD, 0.85), true, 6)
	_title.position = Vector2(30, 18)
	add_child(_title)

	var pennant := SlantPanel.new()
	pennant.fill = Color(UiTheme.INK, 0.0)
	pennant.border_width = 0.0
	pennant.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pennant.offset_left = -120.0
	pennant.offset_right = 120.0
	pennant.offset_top = 14.0
	pennant.offset_bottom = 72.0
	add_child(pennant)
	_tick_label = UiTheme.label("TURN 1", 22, Color(UiTheme.GOLD, 0.8), true, 6)
	_tick_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tick_label.tooltip_text = "One turn passes every time you give an order. Each turn, every enemy's countdown drops by 1."
	_tick_label.mouse_filter = Control.MOUSE_FILTER_STOP
	pennant.add_child(_tick_label)

	var top_right := HBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -400.0
	top_right.offset_right = -34.0
	top_right.offset_top = 20.0
	top_right.offset_bottom = 66.0
	top_right.alignment = BoxContainer.ALIGNMENT_END
	top_right.add_theme_constant_override("separation", 14)
	add_child(top_right)
	var log_btn := Button.new()
	log_btn.text = "Chronicle"
	log_btn.tooltip_text = "What has happened in this battle so far.\nKey: L"
	log_btn.focus_mode = Control.FOCUS_NONE
	log_btn.pressed.connect(_toggle_log)
	top_right.add_child(log_btn)

	# Enemy action banner, above the stage.
	_banner.fill = Color(UiTheme.INK, 0.93)
	_banner.border_width = 4.0
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -340.0 + (STAGE_LEFT - STAGE_RIGHT) * 0.5
	_banner.offset_right = 340.0 + (STAGE_LEFT - STAGE_RIGHT) * 0.5
	_banner.offset_top = 80.0
	_banner.offset_bottom = 148.0
	_banner.visible = false
	# Banners, popups, the log and the result screen draw above the enemies (whose parts use z 0-3).
	_banner.z_index = 5
	add_child(_banner)
	_banner_label = UiTheme.label("", 38, UiTheme.TEXT, true)
	_banner_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)

	# Grade-up banner, larger and lower than the enemy banner.
	_grade_banner.fill = Color(UiTheme.INK, 0.95)
	_grade_banner.border = UiTheme.GOLD
	_grade_banner.border_width = 5.0
	_grade_banner.size = Vector2(860, 132)
	_grade_banner.pivot_offset = _grade_banner.size * 0.5
	_grade_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_grade_banner.offset_left = -430.0 + (STAGE_LEFT - STAGE_RIGHT) * 0.5
	_grade_banner.offset_right = 430.0 + (STAGE_LEFT - STAGE_RIGHT) * 0.5
	_grade_banner.offset_top = 84.0
	_grade_banner.offset_bottom = 216.0
	_grade_banner.visible = false
	_grade_banner.z_index = 6
	add_child(_grade_banner)
	_grade_kicker = UiTheme.label("GRADE UP", 20, UiTheme.GOLD_DEEP, true)
	_grade_kicker.position = Vector2(80, 10)
	_grade_kicker.size = Vector2(700, 24)
	_grade_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_banner.add_child(_grade_kicker)
	_grade_title = UiTheme.label("", 48, UiTheme.GOLD, true, 8)
	_grade_title.position = Vector2(60, 30)
	_grade_title.size = Vector2(740, 56)
	_grade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_banner.add_child(_grade_title)
	_grade_detail = UiTheme.label("", 26, UiTheme.TEXT, true, 6)
	_grade_detail.position = Vector2(40, 86)
	_grade_detail.size = Vector2(760, 34)
	_grade_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_banner.add_child(_grade_detail)

	_popups.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popups.z_index = 7
	add_child(_popups)

	# Battle log drawer, hidden until asked for.
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(UiTheme.INK, 0.95)
	log_style.border_color = UiTheme.GOLD_DEEP
	log_style.set_border_width_all(2)
	log_style.set_content_margin_all(16)
	_log_panel.add_theme_stylebox_override("panel", log_style)
	_log_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_log_panel.offset_left = -560.0
	_log_panel.offset_right = -24.0
	_log_panel.offset_top = 84.0
	_log_panel.offset_bottom = -PARTY_HEIGHT - 8.0
	_log_panel.visible = false
	_log_panel.z_index = 8
	add_child(_log_panel)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log_panel.add_child(_log)

	# What is known about an enemy or a companion: shown while Shift is held over them.
	_inspect.fill = Color(UiTheme.INK, 0.95)
	_inspect.border = UiTheme.GOLD_DEEP
	_inspect.studs = false
	_inspect.visible = false
	_inspect.z_index = 7
	add_child(_inspect)
	_inspect_title = UiTheme.label("", 30, UiTheme.GOLD, true)
	_inspect_title.position = Vector2(24, 14)
	_inspect.add_child(_inspect_title)
	_inspect_body = UiTheme.label("", 19, UiTheme.TEXT)
	_inspect_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_body.position = Vector2(24, 62)
	_inspect.add_child(_inspect_body)

	# Result overlay.
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.z_index = 9
	_overlay.leave_pressed.connect(close)
	add_child(_overlay)


func _row_marker(text: String) -> Label:
	var l := UiTheme.label(text, 19, Color(UiTheme.MUTED, 0.9), false, 5)
	l.add_theme_font_override("font", UiTheme.italic_font())
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(96, 60)
	return l
