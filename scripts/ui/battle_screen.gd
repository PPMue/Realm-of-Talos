extends Control
## Battle screen. Builds the UI, reads Battle state, sends commands and plays back what happened.
## No battle rules live here; see res://scripts/battle/battle.gd.
##
## Layout: the chosen companion's art and actions on the left, enemies standing on the stage,
## the party as a row of panels along the bottom (rightmost = nearest the enemies).
##
## The party's progress (weapon grades, known and equipped arts) lives in `party` and is carried
## from one battle to the next. Fight again keeps it; Start over makes it fresh; the Restart button
## during a battle throws away what that battle had gained.

enum Mode { IDLE, TARGET_ATTACK, TARGET_ART }

## The part of the screen the enemies stand in (margins from each edge, at 1920x1080).
const STAGE_LEFT := 670.0
const STAGE_RIGHT := 24.0
const STAGE_TOP := 70.0
const PARTY_HEIGHT := 276.0
## With this many enemies or more, every second one stands a step back and the art may overlap.
const STAGGER_FROM := 3
## How much wider than its slot an enemy's art may be, side by side and staggered.
const ART_OVERLAP := 1.1
const ART_OVERLAP_STAGGERED := 1.45

@export var setup: BattleSetup

var battle: Battle
## Each companion's run progress, in setup.companions order.
var party: Array[CompanionProgress] = []

var _party_at_start: Array[CompanionProgress] = []
var _art_pool: Array[CombatArtData] = []
var _selected: CompanionUnit
var _mode := Mode.IDLE
## The art waiting for a target while in TARGET_ART.
var _art: CombatArtData
var _hot_enemy: EnemyUnit
var _busy := false
var _skip := false
var _generation := 0
var _logged := 0
var _seed := 0

var _party_panels: Dictionary = {}   # CompanionUnit -> PartyPanel
var _enemy_views: Dictionary = {}    # EnemyUnit -> EnemyView

var _tick_label: Label
var _menu := ActionMenu.new()
var _stage := Control.new()
var _party_row := HBoxContainer.new()
var _banner := SlantPanel.new()
var _banner_label: Label
var _banner_tween: Tween
var _popups := Control.new()
var _log_panel := PanelContainer.new()
var _log := RichTextLabel.new()
var _overlay := ColorRect.new()
var _result_label: Label
var _result_summary: Label
var _grade_banner := SlantPanel.new()
var _grade_title: Label
var _grade_detail: Label
var _grade_tween: Tween
var _arts_screen := ArtsScreen.new()


func _ready() -> void:
	if setup == null:
		setup = load("res://data/battles/prototype_battle.tres")
	theme = UiTheme.theme()
	var library := ArtLibrary.load_default()
	if library != null:
		_art_pool = library.arts
	party = CompanionProgress.create_party(setup.companions)
	_build_ui()
	start_battle()


## Starts a battle with the party's current progress. HP, stamina and removed companions are restored.
func start_battle() -> void:
	_party_at_start.clear()
	for p in party:
		_party_at_start.append(p.copy())
	_generation += 1
	_busy = false
	_skip = false
	var rng := RandomNumberGenerator.new()
	if setup.rng_seed != 0:
		rng.seed = setup.rng_seed
	else:
		rng.randomize()
	_seed = rng.seed
	battle = Battle.new(setup.companions, setup.enemies, rng, party, _art_pool)

	for child in _party_row.get_children() + _stage.get_children() + _popups.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_party_panels.clear()
	_enemy_views.clear()

	_party_row.add_child(_row_marker("‹ BACK"))
	for c in battle.roster:
		var panel := PartyPanel.new()
		panel.setup(c.display_name, c.data.portrait, c.data.portrait_focus)
		panel.clicked.connect(pick_companion.bind(c))
		_party_row.add_child(panel)
		_party_panels[c] = panel
	_party_row.add_child(_row_marker("FRONT ›"))

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
	_mode = Mode.IDLE
	_overlay.visible = false
	_banner.visible = false
	_grade_banner.visible = false
	_arts_screen.visible = false
	_after_change()


## Result screen: next battle, keeping grades and arts.
func fight_again() -> void:
	start_battle()


## Result screen: a fresh party, as at the start of a run.
func start_over() -> void:
	party = CompanionProgress.create_party(setup.companions)
	start_battle()


## Top bar: replays this battle from the start, without what it had gained.
func restart_battle() -> void:
	party = _party_at_start
	start_battle()


func open_arts_screen() -> void:
	if not battle.is_over():
		return
	_arts_screen.open(party)


func is_busy() -> bool:
	return _busy


# ---------------------------------------------------------------- input

func pick_companion(c: CompanionUnit) -> void:
	if _busy or not battle.can_act(c):
		return
	_selected = c
	_mode = Mode.IDLE
	_hot_enemy = null
	_refresh()


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
	_hot_enemy = e if (_mode != Mode.IDLE and e != null and e.is_alive()) else null
	_refresh_enemies()


func strike_enemy(e: EnemyUnit) -> void:
	if _busy or _mode == Mode.IDLE or not e.is_alive():
		return
	var c := _selected
	var done := battle.use_art(c, _art, e) if _mode == Mode.TARGET_ART else battle.attack(c, e)
	if done:
		_commit(c)


func cancel_targeting() -> void:
	if _busy or _mode == Mode.IDLE:
		return
	_mode = Mode.IDLE
	_art = null
	_hot_enemy = null
	_refresh()


func _toggle_targeting(mode: Mode, art: CombatArtData = null) -> void:
	var same := _mode == mode and _art == art
	_mode = Mode.IDLE if same else mode
	_art = null if same else art
	_hot_enemy = null
	if _mode != Mode.IDLE and battle.living_enemies().size() == 1:
		_hot_enemy = battle.living_enemies()[0]
	_refresh()


## True while choosing a target for an art that strikes every enemy: all of them are lit at once.
func _targets_all() -> bool:
	return _mode == Mode.TARGET_ART and _art != null and _art.hits_all_enemies


func _on_enemy_hover(inside: bool, e: EnemyUnit) -> void:
	if _busy:
		return
	if inside:
		point_at_enemy(e)
	elif _hot_enemy == e and battle.living_enemies().size() > 1:
		point_at_enemy(null)


## _input rather than _unhandled_input: right-click must cancel even over an enemy or a panel.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if _busy:
			_skip = true
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _arts_screen.visible:
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
			elif _mode != Mode.IDLE and _hot_enemy != null:
				strike_enemy(_hot_enemy)


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
	_mode = Mode.IDLE
	_art = null
	_hot_enemy = null
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
	if actor != null:
		var panel: PartyPanel = _party_panels[actor]
		panel.set_stamina(actor.stamina, actor.max_stamina())
		if actor.recovery > 0 and not battle.is_lone_companion(actor):
			panel.set_status(PartyPanel.Status.RECOVERING, actor.recovery)
	_refresh_menu()
	_tick_label.text = "TICK %d" % battle.tick
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
		_show_result()


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
			return 0.36 if ev.crit else 0.3
		"defeated":
			var view: EnemyView = _enemy_views[ev.target]
			view.play_defeat()
			return 0.35
		"injured":
			var panel: PartyPanel = _party_panels[ev.target]
			panel.set_status(PartyPanel.Status.INJURED)
			_popup(panel.popup_anchor() + Vector2(0, -50), "INJURED", UiTheme.INJURED, 50)
			return 0.45
		"gone":
			var panel: PartyPanel = _party_panels[ev.target]
			_popup(panel.popup_anchor() + Vector2(0, -50), "GONE", UiTheme.INJURED, 56)
			var t := panel.create_tween()
			t.tween_property(panel, "modulate:a", 0.0, 0.4)
			return 0.5
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
				view.refresh(false, false, view.tooltip_text)
			return 0.32
		"intent":
			var view: EnemyView = _enemy_views[ev.enemy]
			view.refresh(false, false, view.tooltip_text)
			return 0.0
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


## A weapon grade went up: a banner over the stage naming the companion, the grade and the art learned.
func _show_grade_up(ev: Dictionary) -> void:
	var c: CompanionUnit = ev.actor
	var kind := WeaponData.type_name(ev.weapon_type).to_upper()
	var grade := Proficiency.grade_name(ev.grade)
	var art: CombatArtData = ev.art
	_grade_title.text = "%s  ·  %s  %s" % [c.display_name.to_upper(), kind, grade]
	if art == null:
		_grade_detail.text = "EVERY %s ART ALREADY KNOWN" % kind
	else:
		_grade_detail.text = "LEARNED  %s  (TIER %s)%s" % [art.display_name.to_upper(), CombatArtData.tier_numeral(art.tier),
			"  ·  EQUIPPED" if ev.equipped else "  ·  SLOTS FULL"]
	var panel: PartyPanel = _party_panels[c]
	panel.play_pulse(UiTheme.GOLD)
	_popup(panel.popup_anchor() + Vector2(0, -60), "%s %s" % [kind, grade], UiTheme.GOLD, 46)
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


func _show_result() -> void:
	var victory := battle.outcome == Battle.Outcome.VICTORY
	_result_summary.text = _progress_summary()
	_result_label.text = "VICTORY" if victory else "DEFEAT"
	_result_label.add_theme_color_override("font_color", UiTheme.GOLD if victory else UiTheme.INJURED)
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.35)


## One line per companion: grade in the weapon held, points gained, arts learned this battle.
func _progress_summary() -> String:
	var lines: Array[String] = []
	for c in battle.roster:
		var w := c.weapon()
		if w == null:
			continue
		var t := w.weapon_type
		var step := c.progress.progress_to_next(t)
		var next := "max grade" if step.y == 0 else "%d / %d to %s" % [step.x, step.y, Proficiency.grade_name(c.progress.grade(t) + 1)]
		var line := "%s   %s %s   +%d   (%s)" % [c.display_name.to_upper(), WeaponData.type_name(t), Proficiency.grade_name(c.progress.grade(t)),
			c.proficiency_gained, next]
		var learned: Array[String] = []
		for g in battle.grade_ups:
			if g.actor == c and g.art != null:
				learned.append((g.art as CombatArtData).display_name)
		if not learned.is_empty():
			line += "   learned " + ", ".join(learned)
		lines.append(line)
	return "\n".join(lines)


# ---------------------------------------------------------------- drawing from state

## After any change: keep the selection if that companion can still act, else pick the next ready one.
func _after_change() -> void:
	if not battle.can_act(_selected):
		var ready := battle.ready_companions()
		_selected = ready[0] if not ready.is_empty() else null
		_mode = Mode.IDLE
		_hot_enemy = null
	_refresh()


func _refresh() -> void:
	_tick_label.text = "TICK %d" % battle.tick
	_refresh_party()
	_refresh_enemies()
	_refresh_menu()
	_draw_log()


func _refresh_party() -> void:
	var line := battle.line()
	var weights := battle.target_weights()
	var total := 0.0
	for w in weights:
		total += w
	for c: CompanionUnit in _party_panels:
		var panel: PartyPanel = _party_panels[c]
		panel.visible = not c.is_gone()
		if c.is_gone():
			continue
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
		for e in c.effects:
			effects.append(e.describe())
		panel.set_effects("  ".join(effects))
		var share := 0
		var index := line.find(c)
		if index >= 0 and total > 0.0:
			share = roundi(weights[index] / total * 100.0)
		panel.set_footer("%s   ·   targeted %d%%" % [c.weapon().display_name, share])
		var kind := c.weapon().weapon_type
		var step := c.progress.progress_to_next(kind)
		var arts: Array[String] = []
		for a in c.arts():
			arts.append(a.display_name)
		panel.tooltip_text = "%s\n%s\n\n%s %s%s\nArts: %s\n\nEnemies aim at this spot %d%% of the time." % [
			c.display_name, _stat_sheet(c, Stat.COMPANION_KEYS), WeaponData.type_name(kind),
			Proficiency.grade_name(c.progress.grade(kind)),
			"" if step.y == 0 else "  (%d / %d to %s)" % [step.x, step.y, Proficiency.grade_name(c.progress.grade(kind) + 1)],
			", ".join(arts) if not arts.is_empty() else "none", share]
		panel.set_selection(c == _selected, not _busy and battle.can_act(c))


func _refresh_enemies() -> void:
	var targeting := _mode != Mode.IDLE and not _busy
	for e: EnemyUnit in _enemy_views:
		var view: EnemyView = _enemy_views[e]
		var hot := targeting and (e == _hot_enemy or (_targets_all() and e.is_alive()))
		view.refresh(targeting, hot, "%s\n%s" % [e.display_name, _stat_sheet(e, Stat.ENEMY_KEYS)])
		if hot and _selected != null:
			var art := _art if _mode == Mode.TARGET_ART else null
			view.set_forecast(battle.forecast(_selected, e, art), art.strikes if art != null else 1)
		else:
			view.set_forecast(null)


func _refresh_menu() -> void:
	if battle.is_over() and not _busy:
		_menu.show_nothing()
	elif _selected != null:
		var active := ""
		if _mode == Mode.TARGET_ATTACK:
			active = ActionMenu.ATTACK
		elif _mode == Mode.TARGET_ART:
			active = ActionMenu.art_id(_selected.arts().find(_art))
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
	_menu.position = Vector2(34, 92)
	_menu.action_pressed.connect(choose_action)
	add_child(_menu)

	# The party: the battle line, left = back, right = front.
	_party_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_party_row.offset_top = -(PartyPanel.H + PartyPanel.LIFT) - 14.0
	_party_row.offset_bottom = -14.0
	_party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Negative gap: the leaning panels tuck under each other, so five still fit across.
	_party_row.add_theme_constant_override("separation", -50)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_row)

	# Top bar.
	var title := UiTheme.label("REALM OF TALOS", 26, Color(UiTheme.GOLD, 0.85), true, 6)
	title.position = Vector2(38, 26)
	add_child(title)

	var pennant := SlantPanel.new()
	pennant.fill = Color(UiTheme.INK, 0.9)
	pennant.border = UiTheme.GOLD
	pennant.border_width = 3.0
	pennant.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pennant.offset_left = -120.0
	pennant.offset_right = 120.0
	pennant.offset_top = 14.0
	pennant.offset_bottom = 72.0
	add_child(pennant)
	_tick_label = UiTheme.label("TICK 0", 36, UiTheme.GOLD, true)
	_tick_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tick_label.tooltip_text = "One tick passes every time you act. Each tick, every enemy's countdown drops by 1."
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
	log_btn.text = "LOG  (L)"
	log_btn.focus_mode = Control.FOCUS_NONE
	log_btn.pressed.connect(_toggle_log)
	top_right.add_child(log_btn)
	var restart := Button.new()
	restart.text = "RESTART"
	restart.tooltip_text = "Start this battle again. Proficiency and arts gained in it are lost."
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(restart_battle)
	top_right.add_child(restart)

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
	var kicker := UiTheme.label("GRADE UP", 20, UiTheme.GOLD_DEEP, true)
	kicker.position = Vector2(80, 10)
	kicker.size = Vector2(700, 24)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_banner.add_child(kicker)
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

	# Result overlay.
	_overlay.color = Color(UiTheme.INK, 0.72)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.z_index = 9
	add_child(_overlay)
	var ribbon := SlantPanel.new()
	ribbon.fill = Color(UiTheme.INK, 0.96)
	ribbon.border = UiTheme.GOLD
	ribbon.border_width = 5.0
	ribbon.set_anchors_preset(Control.PRESET_CENTER)
	ribbon.offset_left = -520.0
	ribbon.offset_right = 520.0
	ribbon.offset_top = -150.0
	ribbon.offset_bottom = 60.0
	_overlay.add_child(ribbon)
	_result_label = UiTheme.label("", 150, UiTheme.GOLD, true)
	_result_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(_result_label)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER)
	buttons.offset_left = -520.0
	buttons.offset_right = 520.0
	buttons.offset_top = 96.0
	buttons.offset_bottom = 160.0
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	_overlay.add_child(buttons)
	for spec: Array in [
			["FIGHT AGAIN", fight_again, "Fight the same battle again. Grades and arts are kept; HP, stamina and everyone who fell are restored."],
			["ARTS", open_arts_screen, "See each companion's weapon grades and arts, and choose which arts to equip."],
			["START OVER", start_over, "Begin again with a fresh party: starting grades and signature arts only."]]:
		var b := Button.new()
		b.text = spec[0]
		b.tooltip_text = spec[2]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(300, 64)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	_result_summary = UiTheme.label("", 22, UiTheme.TEXT, false, 6)
	_result_summary.set_anchors_preset(Control.PRESET_CENTER)
	_result_summary.offset_left = -520.0
	_result_summary.offset_right = 520.0
	_result_summary.offset_top = 190.0
	_result_summary.offset_bottom = 340.0
	_result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_result_summary)

	_arts_screen.visible = false
	_arts_screen.z_index = 10
	add_child(_arts_screen)


func _row_marker(text: String) -> Label:
	var l := UiTheme.label(text, 24, Color(UiTheme.MUTED, 0.8), true, 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Wide enough to stay clear of the panels, which tuck under their neighbours.
	l.custom_minimum_size = Vector2(190, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if text.begins_with("‹") else HORIZONTAL_ALIGNMENT_RIGHT
	return l
