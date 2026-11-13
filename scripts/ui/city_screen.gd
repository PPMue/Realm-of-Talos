class_name CityScreen
extends Control
## The city: the main scene and the hub of a run. Shows the day, the days ahead, the city's health and
## stores, the party at a glance, and today's activity, which is the focus of the screen:
##   battle day: the fronts as cards;  boss day: the boss card;
##   free day: the four actions and how many remain;  event day: the text and the choices.
## The party, shop, tavern, battle and run-end screens open over it.
## No rules live here: it reads the Run and calls its commands.

const ACTIVITY_TOP := 214.0
const CARDS_TOP := 304.0
const ROSTER_TOP := 846.0

## 0 = a random seed for each new run.
@export var run_seed: int = 0

var run: Run

var _art_pool: Array[CombatArtData] = []
var _spell_pool: Array[SpellData] = []
var _day_label: Label
var _city_bar := SlantBar.new()
var _gold_label: Label
var _iron_label: Label
var _timber_label: Label
var _strip := DayStrip.new()
var _activity := Control.new()
var _roster_row := HBoxContainer.new()
var _roster_head: Label
var _notice := SlantPanel.new()
var _notice_title: Label
var _notice_text: Label
var _notice_tween: Tween
## Number-key shortcuts for today's activity: index 0 = key 1.
var _shortcuts: Array[Callable] = []

var _party_screen := PartyScreen.new()
var _store_screen := StoreScreen.new()
var _battle_screen := BattleScreen.new()
var _end_screen := RunEndScreen.new()


func _ready() -> void:
	theme = UiTheme.theme()
	var library := ArtLibrary.load_default()
	if library != null:
		_art_pool = library.arts
	var spells := SpellLibrary.load_default()
	if spells != null:
		_spell_pool = spells.spells
	_build()
	new_run(run_seed)


## Starts a new run. `seed_value` 0 picks a random seed.
func new_run(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	run = Run.create(rng, RunContent.load_default(), _art_pool, _spell_pool)
	_end_screen.visible = false
	_battle_screen.visible = false
	_party_screen.visible = false
	_store_screen.visible = false
	refresh()
	_show_notice("DAY 1 BEGINS", "Monsters are gathering outside the walls. You have %s. Hold the city for %d days." % [
		" and ".join(_names(run.roster)), RunConfig.DAYS])


func refresh() -> void:
	_day_label.text = "DAY %d / %d" % [run.day, RunConfig.DAYS]
	_city_bar.set_values(run.city_health, RunConfig.CITY_MAX_HEALTH)
	_city_bar.fill_color = UiTheme.HP if run.city_health > 30 else UiTheme.INJURED
	_gold_label.text = str(run.gold)
	_iron_label.text = str(run.material(RunConfig.IRON_ORE))
	_timber_label.text = str(run.material(RunConfig.TIMBER))
	_strip.set_days(run.day, run.upcoming())
	_strip.position.x = (size.x - _strip.size.x) * 0.5 if size.x > 0 else (1920.0 - _strip.size.x) * 0.5
	_build_activity()
	_build_roster()


# ---------------------------------------------------------------- commands (also used by tests and tools)

func open_party(select: RunCompanion = null) -> void:
	if run.is_over():
		return
	_party_screen.open(run, select)


func open_shop() -> void:
	if run.visit_block_reason(Run.FreeAction.SHOP) == "":
		_store_screen.open_shop(run)


func open_tavern() -> void:
	if run.visit_block_reason(Run.FreeAction.TAVERN) == "":
		_store_screen.open_tavern(run)


func defend(front: Front) -> void:
	var battle := run.start_battle(front)
	if battle == null:
		_show_notice("NOT YET", run.battle_block_reason(front))
		return
	_hide_notice()
	_battle_screen.visible = true
	_battle_screen.start(battle, "DAY %d  ·  %s" % [run.day, front.title()])


func rest() -> void:
	if run.rest():
		_show_notice("REST", "Everyone recovers to full health, and every spell's uses come back.")
		refresh()


func repair() -> void:
	if run.repair():
		_show_notice("REPAIR", "Masons patch the walls: city health +%d." % RunConfig.REPAIR_AMOUNT)
		refresh()


func end_day() -> void:
	if run.end_free_day():
		_after_day()


func choose(choice: EventChoiceData) -> void:
	var title := run.event.title
	var text := run.choose(choice)
	if text == "":
		return
	_after_day(title.to_upper(), "%s  (%s)" % [text, choice_effects(run, choice, false)])


# ---------------------------------------------------------------- day flow

func _after_day(title: String = "", text: String = "") -> void:
	refresh()
	if run.is_over():
		_end_screen.open(run)
		return
	var heal := "Overnight every companion recovered %d%% of their health." % roundi(RunConfig.DAILY_HEAL_FRACTION * 100.0)
	if title == "":
		_show_notice("DAY %d BEGINS" % run.day, heal)
	else:
		_show_notice(title, text)


func _on_battle_finished(battle: Battle) -> void:
	var report := run.finish_battle(battle)
	if report != null:
		_battle_screen.show_report(report)


func _on_battle_closed() -> void:
	_battle_screen.visible = false
	_after_day()


# ---------------------------------------------------------------- today's activity

func _build_activity() -> void:
	for child in _activity.get_children():
		_activity.remove_child(child)
		child.queue_free()
	_shortcuts.clear()
	if run.is_over():
		return
	var t := run.day_type()
	var kicker := "%s DAY" % RunCalendar.type_name(t)
	match t:
		RunCalendar.DayType.BATTLE:
			_heading(kicker, "CHOOSE A FRONT TO DEFEND",
				"Your fielded party fights where you send it. Fronts you do not choose have no consequence. Change the party before you commit.")
			_front_cards()
		RunCalendar.DayType.BOSS:
			_heading(kicker, "THE BOSS IS AT THE GATES",
				"No choice today. Win and the run goes on; lose and the city falls.")
			_front_cards()
		RunCalendar.DayType.FREE:
			_heading(kicker, "%d %s LEFT" % [run.actions_left, "ACTION" if run.actions_left == 1 else "ACTIONS"],
				"Each action can be taken once today. Unused actions are lost when the day ends.")
			_free_day()
		RunCalendar.DayType.EVENT:
			_heading(kicker, run.event.title.to_upper() if run.event != null else "A QUIET DAY", "")
			_event()


func _heading(kicker: String, title: String, hint: String) -> void:
	var k := UiTheme.label(kicker, 22, UiTheme.GOLD, true, 6)
	k.position = Vector2(64, ACTIVITY_TOP)
	_activity.add_child(k)
	var l := UiTheme.label(title, 50, UiTheme.TEXT, true, 10)
	l.position = Vector2(56, ACTIVITY_TOP + 22.0)
	_activity.add_child(l)
	if hint != "":
		var h := UiTheme.label(hint, 18, UiTheme.MUTED, false, 4)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var x := 64.0 + l.get_minimum_size().x + 30.0
		h.position = Vector2(x, ACTIVITY_TOP + 30.0)
		# Leave room for the END DAY button on free days.
		h.size = Vector2(minf(720.0, 1920.0 - x - 460.0), 60.0)
		h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_activity.add_child(h)


func _front_cards() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, CARDS_TOP)
	row.size = Vector2(size.x if size.x > 0 else 1920.0, FrontCard.H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activity.add_child(row)
	for i in run.fronts.size():
		var f := run.fronts[i]
		var card := FrontCard.new()
		var why := run.battle_block_reason(f)
		card.setup(f, str(i + 1), why)
		card.chosen.connect(defend.bind(f))
		row.add_child(card)
		_shortcuts.append(defend.bind(f))


func _free_day() -> void:
	var end := ActionButton.new()
	end.title = "END DAY"
	end.hotkey = "E"
	end.detail = "lose %d" % run.actions_left if run.actions_left > 0 else ""
	end.position = Vector2(1920.0 - ActionButton.W - 90.0, ACTIVITY_TOP + 20.0)
	end.tooltip_text = "End the free day and move on to day %d." % (run.day + 1)
	end.pressed.connect(end_day)
	_activity.add_child(end)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, CARDS_TOP + 20.0)
	row.size = Vector2(1920.0, ActivityCard.H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activity.add_child(row)
	var A := Run.FreeAction
	var hurt := 0
	var spent := 0
	for c in run.roster:
		if c.hp < c.max_hp():
			hurt += 1
		if c.progress.has_spent_uses():
			spent += 1
	var rest_status := "%d of %d hurt" % [hurt, run.roster.size()]
	if spent > 0:
		rest_status += "  ·  %d low on spells" % spent
	var specs := [
		[A.REST, "REST", "Every companion recovers to full health and every spell's uses. Nothing else restores spell uses.",
			rest_status, "REST", rest, run.free_action_block_reason(A.REST)],
		[A.SHOP, "SHOP", "Buy weapons with gold. Any number of purchases in one visit is one action.",
			"Spent on the first purchase", "VISIT SHOP", open_shop, run.visit_block_reason(A.SHOP)],
		[A.TAVERN, "TAVERN", "Hire a companion for %d gold. %d looking for work today." % [RunConfig.HIRE_COST, run.tavern_offers.size()],
			"Spent on the first hire", "VISIT TAVERN", open_tavern, run.visit_block_reason(A.TAVERN)],
		[A.REPAIR, "REPAIR", "Spend %s to restore %d city health." % [Run.cost_text(RunConfig.REPAIR_COST), RunConfig.REPAIR_AMOUNT],
			"City %d / %d" % [run.city_health, RunConfig.CITY_MAX_HEALTH], "REPAIR", repair, run.free_action_block_reason(A.REPAIR)],
	]
	for i in specs.size():
		var s: Array = specs[i]
		var done: bool = run.actions_used.has(s[0])
		var why: String = s[6]
		# The shop and tavern stay open for more after their first purchase.
		var reopen: bool = done and (s[0] == A.SHOP or s[0] == A.TAVERN)
		var card := ActivityCard.new()
		card.setup(s[1], s[2], s[3], s[4], str(i + 1), "" if reopen else (why if not done else "Already done today."), done)
		card.chosen.connect(s[5])
		row.add_child(card)
		_shortcuts.append(s[5])


func _event() -> void:
	if run.event == null:
		return
	var panel := SlantPanel.new()
	panel.fill = Color(UiTheme.INK, 0.93)
	panel.border = DayStrip.type_color(RunCalendar.DayType.EVENT)
	panel.border_width = 3.0
	panel.position = Vector2(150, CARDS_TOP)
	panel.size = Vector2(1620, 520)
	_activity.add_child(panel)
	var text := UiTheme.label(run.event.text, 26, UiTheme.TEXT, false, 4)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(220, 34)
	text.size = Vector2(1240, 110)
	panel.add_child(text)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(170, 170)
	panel.add_child(box)
	for i in run.event.choices.size():
		var ch := run.event.choices[i]
		var b := RowButton.new(1280.0, 92.0)
		b.title = ch.label.to_upper()
		b.sub = choice_effects(run, ch, true)
		b.hotkey = str(i + 1)
		var why := run.choice_block_reason(ch)
		b.disabled = why != ""
		b.detail = why.to_upper()
		b.pressed.connect(choose.bind(ch))
		box.add_child(b)
		_shortcuts.append(choose.bind(ch))


## What an event choice changes, in one line. `ahead`: phrased before choosing (names who would be hurt).
static func choice_effects(r: Run, ch: EventChoiceData, ahead: bool) -> String:
	var parts: Array[String] = []
	if ch.gold != 0:
		parts.append("%+d gold" % ch.gold)
	for m in RunConfig.MATERIAL_ORDER:
		var n := int(ch.materials.get(m, 0))
		if n != 0:
			parts.append("%+d %s" % [n, String(RunConfig.MATERIAL_NAMES[m]).to_lower()])
	if ch.city_health != 0:
		parts.append("%+d city health" % ch.city_health)
	if ch.companion_hp != 0:
		if ch.hp_target == EventChoiceData.HpTarget.ALL:
			parts.append("%+d HP to every companion" % ch.companion_hp)
		else:
			var who := r.hp_targets(ch)
			var name := who[0].display_name() if ahead and not who.is_empty() else "your healthiest companion"
			parts.append("%+d HP to %s" % [ch.companion_hp, name])
	if ch.weapon != null:
		parts.append("gain a %s" % ch.weapon.display_name)
	return "nothing changes" if parts.is_empty() else "   ·   ".join(parts)


# ---------------------------------------------------------------- roster at a glance

func _build_roster() -> void:
	for child in _roster_row.get_children():
		_roster_row.remove_child(child)
		child.queue_free()
	_roster_head.text = "PARTY   ·   %d FIELDED%s" % [run.lineup.size(),
		"   ·   %d IN RESERVE" % run.reserve().size() if not run.reserve().is_empty() else ""]
	_roster_row.add_child(_marker("‹ BACK"))
	for i in run.lineup.size():
		var chip := CompanionChip.new()
		chip.setup(run.lineup[i], i + 1, true)
		if i == run.lineup.size() - 1:
			chip.set_tag("FRONT")
		chip.pressed.connect(open_party.bind(run.lineup[i]))
		_roster_row.add_child(chip)
	_roster_row.add_child(_marker("FRONT ›"))
	for c in run.reserve():
		var chip := CompanionChip.new()
		chip.setup(c, 0, true)
		chip.pressed.connect(open_party.bind(c))
		_roster_row.add_child(chip)


func _marker(text: String) -> Label:
	var l := UiTheme.label(text, 22, Color(UiTheme.MUTED, 0.8), true, 6)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(110, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- notices

## The day's news: stays until something else happens.
func _show_notice(title: String, text: String) -> void:
	_notice_title.text = title
	_notice_text.text = text
	_notice.tooltip_text = "%s
%s" % [title, text]
	_notice.visible = true
	_notice.modulate.a = 0.0
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, 0.25)


func _hide_notice() -> void:
	if _notice_tween != null:
		_notice_tween.kill()
	_notice.visible = false


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or run == null or run.is_over():
		return
	if _battle_screen.visible or _party_screen.visible or _store_screen.visible or _end_screen.visible:
		return
	var n := -1
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		n = key.keycode - KEY_1
	elif key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_9:
		n = key.keycode - KEY_KP_1
	if n >= 0 and n < _shortcuts.size():
		get_viewport().set_input_as_handled()
		_shortcuts[n].call()
	elif key.keycode == KEY_P:
		get_viewport().set_input_as_handled()
		open_party()
	elif key.keycode == KEY_E and run.day_type() == RunCalendar.DayType.FREE:
		get_viewport().set_input_as_handled()
		end_day()


# ---------------------------------------------------------------- layout

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := CityBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Top bar: title, the day, the city's health and stores.
	var title := UiTheme.label("REALM OF TALOS", 26, Color(UiTheme.GOLD, 0.85), true, 6)
	title.position = Vector2(38, 20)
	add_child(title)
	var sub := UiTheme.label("THE LAST CITY", 18, UiTheme.MUTED, true, 4)
	sub.position = Vector2(42, 52)
	add_child(sub)

	var pennant := SlantPanel.new()
	pennant.fill = Color(UiTheme.INK, 0.9)
	pennant.border = UiTheme.GOLD
	pennant.border_width = 3.0
	pennant.position = Vector2(960 - 170, 12)
	pennant.size = Vector2(340, 70)
	add_child(pennant)
	_day_label = UiTheme.label("", 44, UiTheme.GOLD, true)
	_day_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pennant.add_child(_day_label)

	var city := UiTheme.label("CITY", 22, UiTheme.MUTED, true, 4)
	city.position = Vector2(1188, 30)
	add_child(city)
	_city_bar.position = Vector2(1248, 26)
	_city_bar.size = Vector2(300, 34)
	_city_bar.font_size = 20
	_city_bar.tooltip_text = "City health. Lost when a battle is lost (%d / %d / %d by danger). At 0 the run ends." % RunConfig.CITY_DAMAGE_BY_DANGER
	_city_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_city_bar)
	_gold_label = _resource(1572, "GOLD", UiTheme.GOLD, "Gold: pays for weapons, hires and some event choices.")
	_iron_label = _resource(1680, "IRON", UiTheme.TEXT, "Iron ore: used to repair the walls and traded in events.")
	_timber_label = _resource(1788, "TIMBER", UiTheme.TEXT, "Timber: used to repair the walls.")

	_strip.position = Vector2(0, 100)
	add_child(_strip)

	_activity.set_anchors_preset(Control.PRESET_FULL_RECT)
	_activity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_activity)

	# The party at a glance.
	_roster_head = UiTheme.label("", 22, UiTheme.GOLD, true, 6)
	_roster_head.position = Vector2(64, ROSTER_TOP)
	add_child(_roster_head)
	var manage := ActionButton.new()
	manage.title = "MANAGE PARTY"
	manage.hotkey = "P"
	manage.position = Vector2(1920.0 - ActionButton.W - 90.0, ROSTER_TOP - 18.0)
	manage.tooltip_text = "Choose who is fielded and in what order, change weapons and combat arts. Free, any day."
	manage.pressed.connect(func() -> void: open_party())
	add_child(manage)
	_roster_row.position = Vector2(40, ROSTER_TOP + 44.0)
	_roster_row.size = Vector2(1840, CompanionChip.H)
	_roster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_roster_row.add_theme_constant_override("separation", -12)
	_roster_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_roster_row)

	# What just happened (the day's news), on the party header line, out of the way of today's activity.
	_notice.fill = Color(UiTheme.INK, 0.92)
	_notice.border = Color(UiTheme.GOLD, 0.8)
	_notice.border_width = 2.0
	_notice.position = Vector2(520, ROSTER_TOP - 22.0)
	_notice.size = Vector2(950, 62)
	_notice.visible = false
	_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_notice)
	_notice_title = UiTheme.label("", 20, UiTheme.GOLD, true, 4)
	_notice_title.position = Vector2(30, 4)
	_notice.add_child(_notice_title)
	_notice_text = UiTheme.label("", 15, UiTheme.TEXT, false, 3)
	_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_text.max_lines_visible = 2
	_notice_text.clip_text = true
	_notice_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice_text.position = Vector2(24, 26)
	_notice_text.size = Vector2(900, 40)
	_notice.add_child(_notice_text)

	# Screens that open over the city.
	for screen: Control in [_party_screen, _store_screen, _battle_screen, _end_screen]:
		screen.visible = false
		screen.z_index = 10
		add_child(screen)
	_party_screen.closed.connect(refresh)
	_store_screen.closed.connect(refresh)
	_battle_screen.finished.connect(_on_battle_finished)
	_battle_screen.closed.connect(_on_battle_closed)
	_end_screen.new_run_pressed.connect(func() -> void: new_run(0))


func _resource(x: float, head: String, color: Color, tip: String) -> Label:
	var box := SlantPanel.new()
	box.fill = Color(UiTheme.INK, 0.85)
	box.position = Vector2(x, 20)
	box.size = Vector2(100, 50)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tip
	add_child(box)
	var h := UiTheme.label(head, 13, UiTheme.MUTED, true)
	h.position = Vector2(18, 3)
	box.add_child(h)
	var v := UiTheme.label("0", 26, color, true, 4)
	v.position = Vector2(14, 16)
	box.add_child(v)
	return v


static func _names(cs: Array[RunCompanion]) -> Array[String]:
	var out: Array[String] = []
	for c in cs:
		out.append(c.display_name())
	return out
