class_name CityScreen
extends Control
## The city: the hub of a run. The screen is the place itself, and its buildings are the buttons:
##   the Gate        march out on battle and boss days, hear the morning's matter, end a free day
##   the Tavern      hire companions            the Smithy     buy weapons
##                   (both also open on battle and boss days, until the company marches out)
##   the Inn         rest                       Mason's Yard   mend the walls
##   the Barracks    the party (always open)    the Watchtower the days ahead (always open)
## The sky is the clock: a free day runs from morning to dusk as its actions are spent, a battle day
## opens at dawn with the enemy's fires beyond the wall, a boss day under a red sky.
## A thin strip at the top carries the day, the days ahead and the city's stores; the company stands
## along the bottom; a slip of parchment gives the day's news.
## No rules live here: the screen reads the Run and calls its commands.

signal left_run

const NUMBER_WORDS: Array[String] = ["no", "one", "two", "three", "four", "five"]

var run: Run

var _art_pool: Array[CombatArtData] = []
var _spell_pool: Array[SpellData] = []
var _city := CityBackdrop.new()
var _top := Control.new()
var _day_label: Label
var _mood_label: Label
var _city_bar := SlantBar.new()
var _gold_label: Label
var _iron_label: Label
var _timber_label: Label
var _strip := DayStrip.new()
var _gems := Control.new()
var _party_row := HBoxContainer.new()
var _news := Control.new()
var _news_title: Label
var _news_text: Label
var _news_action := Callable()
var _news_tween: Tween
var _curtain := Control.new()
var _curtain_title: Label
var _curtain_sub: Label
var _busy := false

var _letter := LetterPanel.new()
var _war_table := WarTable.new()
var _party_screen := PartyScreen.new()
var _store_screen := StoreScreen.new()
var _training_screen := TrainingScreen.new()
var _infirmary_screen := InfirmaryScreen.new()
var _scavenge_screen := ScavengeScreen.new()
var _mason_screen := MasonScreen.new()
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


## Starts a new run. `seed_value` 0 picks a random seed. `opening`: greet the commander with a letter.
func new_run(seed_value: int = 0, opening: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	run = Run.create(rng, RunContent.load_default(), _art_pool, _spell_pool)
	for screen: Control in [_end_screen, _battle_screen, _party_screen, _store_screen, _training_screen, _infirmary_screen, _scavenge_screen,
			_mason_screen, _war_table, _letter]:
		screen.visible = false
	_begin_day(_day_title(), _day_text())
	if opening:
		_open_opening()


## True while the day is changing behind the curtain.
func is_busy() -> bool:
	return _busy


func refresh(animate: bool = true) -> void:
	if run == null:
		return
	_day_label.text = "DAY %d" % run.day
	_mood_label.text = "of %d   ·   %s" % [RunConfig.DAYS, _mood()]
	_city_bar.set_values(run.city_health, run.max_city_health())
	_city_bar.fill_color = UiTheme.HP if run.city_health > 30 else UiTheme.INJURED
	_gold_label.text = str(run.gold)
	_iron_label.text = str(run.material(RunConfig.IRON_ORE))
	_timber_label.text = str(run.material(RunConfig.TIMBER))
	var bosses := {}
	for d in run.boss_days_ahead():
		bosses[d] = run.boss_on(d)
	# The stone a big fight brings is marked on its day (not on a boss day the watch has not yet seen).
	var ahead := run.upcoming()
	var stones := {}
	for i in ahead.size():
		if RunCalendar.is_big_fight(ahead[i]) and run.gem_for_fight(run.day + i) > 0:
			stones[run.day + i] = run.gem_for_fight(run.day + i)
	_strip.set_days(run.day, ahead, bosses, run.event_days, stones)
	_gems.queue_redraw()
	_gems.tooltip_text = _gems_text()
	_strip.position = Vector2((1920.0 - _strip.size.x) * 0.5, 8.0)
	_city.set_phase(_phase(), animate)
	_refresh_buildings()
	_build_party()


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


## Opens the table where the day's fight is chosen (battle and boss days).
## The drill yard opens on any free day once the gate's matter is answered, even with nothing left to
## do there today: the notices can always be read.
func open_training() -> void:
	if _yard_block_reason() == "":
		_training_screen.open(run)


func _yard_block_reason() -> String:
	var why := run.free_action_block_reason(Run.FreeAction.TRAIN)
	return "" if why == Run.NO_USEFUL_DRILL or why.begins_with("Needs ") else why


## Opens the map table where a party is sent beyond the walls (free days, the day's one thing).
func open_scavenge() -> void:
	if run.free_action_block_reason(Run.FreeAction.SCAVENGE) == "" and not run.scavenge_sites().is_empty():
		_scavenge_screen.open(run)


func open_war_table() -> void:
	var t := run.day_type()
	if not run.is_over() and RunCalendar.is_fight(t):
		_war_table.open(run)


func defend(front: Front) -> void:
	var battle := run.start_battle(front)
	if battle == null:
		_say("Not yet", run.battle_block_reason(front))
		return
	_war_table.visible = false
	_hide_news()
	_battle_screen.visible = true
	_battle_screen.start(battle, "DAY %d  ·  %s" % [run.day, front.title()])


func rest() -> void:
	if run.rest():
		refresh()
		_say("The Inn", "A hot meal and a real bed. Everyone is back to full health, and every spell is ready again.")


func repair() -> void:
	if run.repair():
		refresh()
		_say("Mason's Yard", "The masons go up on the scaffolds. The walls are stronger by %d." % run.repair_amount())


func end_day() -> void:
	if run.end_free_day():
		_after_day()


## Answers the morning's event; the free day then goes on.
func choose(choice: EventChoiceData) -> void:
	var title := run.event.title
	var text := run.choose(choice)
	if text == "":
		return
	if run.is_over():
		_after_day()
		return
	refresh()
	_say(title, "%s  (%s)" % [text, choice_effects(run, choice, false)])


## Clicks a building.
func visit(kind: CityBuilding.Kind) -> void:
	if run == null or run.is_over() or _busy:
		return
	var A := Run.FreeAction
	match kind:
		CityBuilding.Kind.BARRACKS:
			open_party()
		CityBuilding.Kind.WATCHTOWER:
			_open_watch()
		CityBuilding.Kind.GATE:
			_visit_gate()
		CityBuilding.Kind.TAVERN:
			var why := run.visit_block_reason(A.TAVERN)
			if why == "":
				open_tavern()
			else:
				_say("The Tavern", _in_world(why))
		CityBuilding.Kind.SMITHY:
			var why := run.visit_block_reason(A.SHOP)
			if why == "":
				open_shop()
			else:
				_say("The Smithy", _in_world(why))
		CityBuilding.Kind.INFIRMARY:
			# Open on any day: the beds can always be looked in on.
			_infirmary_screen.open(run)
		CityBuilding.Kind.YARD:
			var why := _yard_block_reason()
			if why == "":
				open_training()
			else:
				_say("The Drill Yard", _in_world(why))
		CityBuilding.Kind.INN:
			var why := run.free_action_block_reason(A.REST)
			if why != "":
				_say("The Inn", _in_world(why))
				return
			_letter.open({
				"kicker": "The Inn",
				"title": "A Bed and a Meal",
				"body": "\"Rooms are ready, Commander. Send them in and I will see they sleep.\"",
				"facts": "Everyone recovers to full health, and every spell's uses come back. Nothing else restores spell uses.\n%s  %s" % [
					_hurt_text(), _time_cost()],
				"choices": [{"label": "Rest the company", "action": rest}],
				"leave": "Not now",
			})
		CityBuilding.Kind.MASON:
			# Open on any day: the plan of the city's works can always be read.
			_mason_screen.open(run)
		CityBuilding.Kind.JEWELER:
			_say("The Jeweler", "The shutters are up. The masons have not built the workshop yet.")


# ---------------------------------------------------------------- the gate, the watch, events, the opening

func _visit_gate() -> void:
	match run.day_type():
		RunCalendar.DayType.BATTLE, RunCalendar.DayType.BOSS, RunCalendar.DayType.ELITE:
			if run.yield_block_reason() == "":
				_open_yield()
			else:
				open_war_table()
		RunCalendar.DayType.FREE:
			if run.event_pending():
				_open_event()
				return
			var left := run.actions_left
			var end_facts := "Ends the day and moves on to day %d.%s" % [run.day + 1,
				"" if left <= 0 else "  There is still time for %s more thing%s today; it is lost if you end the day now." % [
					NUMBER_WORDS[mini(left, 5)], "" if left == 1 else "s"]]
			if _can_scavenge():
				# With the day's action still in hand, the gate is also the way out.
				var names: Array[String] = []
				for s in run.scavenge_sites():
					names.append(s.display_name)
				_letter.open({
					"kicker": "The Gate",
					"title": "Out, or Bar the Gate?",
					"body": "\"The scouts have marked %s, Commander. A party could be out and back by dusk. Or shall we bar the gate?\"" % " and ".join(names),
					"choices": [
						{"label": "Send a party beyond the walls", "sub": "Gold, materials and a little experience, at a risk.  %s" % _time_cost(),
							"action": open_scavenge},
						{"label": "End the day", "sub": end_facts, "action": end_day},
					],
					"leave": "Not yet",
					"width": 1040.0,
				})
				return
			_letter.open({
				"kicker": "The Gate",
				"title": "Close the Gates for the Night",
				"body": "\"Shall we bar the gate, Commander?\"",
				"facts": end_facts,
				"choices": [{"label": "End the day", "action": end_day}],
				"leave": "Not yet",
			})


func _can_scavenge() -> bool:
	return run.free_action_block_reason(Run.FreeAction.SCAVENGE) == "" and not run.scavenge_sites().is_empty()


## Everyone is in the infirmary on a day the enemy comes: there is nothing to do but give the day up.
func _open_yield() -> void:
	var boss := run.day_type() == RunCalendar.DayType.BOSS
	_letter.open({
		"kicker": "The Gate",
		"title": "Nobody Can March Out",
		"body": "\"They are all in the infirmary, Commander. There is no one to send.\"",
		"facts": "The day is lost without a fight. %s" % ("%s reaches the gate, and the city falls." % _boss_name() if boss
			else "The walls take what the worst of today's fronts would have cost."),
		"choices": [{"label": "Give up the day", "action": yield_day}],
		"leave": "Not yet",
	})


func yield_day() -> void:
	var report := run.yield_day()
	if report == null:
		return
	_after_day("The Front Was Lost", "No one could march out. The walls lost %d. %s" % [report.city_damage, _day_text()])


func _open_watch() -> void:
	var lines: Array[String] = []
	var types := run.upcoming()
	for i in types.size():
		var d := run.day + i
		var when := "Today" if i == 0 else ("Tomorrow" if i == 1 else "Day %d" % d)
		var what := String(DayStrip.TYPE_WORDS.get(types[i], "")).to_lower()
		if types[i] == RunCalendar.DayType.FREE and run.has_event_day(d):
			what += ", and someone will be asking for you at the gate"
		if types[i] == RunCalendar.DayType.BOSS and run.boss_on(d) != null:
			what = "%s comes" % run.boss_on(d).display_name
		lines.append("%s:  %s." % [when, what])
	var bosses := _strip.bosses_ahead_text()
	var more := ""
	var ahead := run.tomorrow_fronts()
	if not ahead.is_empty():
		# The tower at its full height sees tomorrow's fronts a day early.
		var seen: Array[String] = []
		for fr in ahead:
			var who: Array[String] = []
			for e in fr.enemies:
				who.append(e.display_name)
			seen.append("%s: %s (%s)" % [fr.title(), ", ".join(who), "the boss" if fr.is_boss else "danger %d" % fr.danger])
		more += "\n\nTomorrow they come at:\n" + "\n".join(seen)
	if not run.boss_days_known():
		more += "\n\nThe tower is too low to see when the worst of them will come, or who. The masons could raise it."
	elif bosses != "":
		more += "\n\nStill to come:\n" + bosses
	_letter.open({
		"kicker": "The Watchtower",
		"title": "The Watch's Report",
		"body": "\"This is what we can see from up here, Commander.\"",
		"facts": "\n".join(lines) + more,
		"leave": "Climb back down",
		"width": 980.0,
	})


func _open_event() -> void:
	if not run.event_pending():
		return
	var choices: Array = []
	for ch in run.event.choices:
		choices.append({"label": ch.label, "sub": choice_effects(run, ch, true), "why": run.choice_block_reason(ch).trim_suffix("."),
			"action": choose.bind(ch)})
	_letter.open({
		"kicker": "Day %d" % run.day,
		"title": run.event.title,
		"body": run.event.text,
		"choices": choices,
		"leave": "Decide later",
		"width": 1040.0,
	})


func _open_opening() -> void:
	var portraits: Array = []
	for c in run.roster:
		var kind := WeaponData.type_name(c.weapon().weapon_type).to_lower()
		if c.data.is_mage():
			kind = "%s mage" % ("black" if c.data.signature_spell.school == SpellData.School.BLACK else "white")
		portraits.append({"texture": c.data.portrait, "focus": c.data.portrait_focus, "scale": c.data.figure_scale,
			"name": c.display_name(), "sub": kind})
	_letter.open({
		"kicker": "To the Commander",
		"title": "The Last City",
		"body": "The outer towns are gone. What is left of us stands behind these walls, and the things beyond them know it.\nHold the city for %d days.\n%s answered your call. More may be found at the tavern when there is a quiet day." % [
			RunConfig.DAYS, " and ".join(_names(run.roster))],
		"portraits": portraits,
		"choices": [{"label": "Take command", "action": _announce_day}],
		"leave": "",
		"width": 940.0,
	})


# ---------------------------------------------------------------- day flow

func _after_day(title: String = "", text: String = "") -> void:
	if run.is_over():
		refresh(false)
		_end_screen.open(run)
		return
	var heal := "Overnight the company recovered a fifth of its strength. "
	if not run.released_today.is_empty():
		var up := _names(run.released_today)
		heal = "%s %s out of the infirmary and back on the bench. %s" % [" and ".join(up), "is" if up.size() == 1 else "are", heal]
	_begin_day(_day_title() if title == "" else title, (heal + _day_text()) if title == "" else text)
	_announce_day()


## Draws the curtain over the city, changes the day behind it, and lifts it again.
func _begin_day(news_title: String, news_text: String) -> void:
	_busy = true
	_hide_news()
	_curtain_title.text = "DAY %d" % run.day
	_curtain_sub.text = _mood()
	_curtain.visible = true
	_curtain.modulate.a = 1.0
	refresh(false)
	_say(news_title, news_text)
	var t := create_tween()
	t.tween_interval(0.9)
	t.tween_property(_curtain, "modulate:a", 0.0, 0.7)
	t.tween_callback(func() -> void:
		_curtain.visible = false
		_busy = false)


## What the day opens with: a free day's event is put in front of the commander at once, before the
## buildings open.
func _announce_day() -> void:
	if run.is_over():
		return
	if run.event_pending() and not _letter.is_open():
		_open_event()


func _on_battle_finished(battle: Battle) -> void:
	var report := run.finish_battle(battle)
	if report != null:
		_battle_screen.show_report(report)


func _on_battle_closed() -> void:
	_battle_screen.visible = false
	_after_day()


# ---------------------------------------------------------------- words

func _phase() -> CityBackdrop.Phase:
	if run.is_over():
		return CityBackdrop.Phase.NIGHT
	match run.day_type():
		RunCalendar.DayType.BATTLE, RunCalendar.DayType.ELITE:
			return CityBackdrop.Phase.DAWN
		RunCalendar.DayType.BOSS:
			return CityBackdrop.Phase.DREAD
		RunCalendar.DayType.FREE:
			var used := RunConfig.FREE_DAY_ACTIONS - run.actions_left
			if run.actions_left <= 0:
				return CityBackdrop.Phase.DUSK
			return CityBackdrop.Phase.MORNING if used <= 0 else CityBackdrop.Phase.AFTERNOON
	return CityBackdrop.Phase.MORNING


## The line beside the day number.
func _mood() -> String:
	match run.day_type():
		RunCalendar.DayType.BATTLE:
			return "The horns are sounding"
		RunCalendar.DayType.ELITE:
			return "Their best are at the walls"
		RunCalendar.DayType.BOSS:
			return "%s is at the gates" % _boss_name()
	if run.event_pending():
		return "A matter awaits your answer"
	var left := run.actions_left
	if left <= 0:
		return "The day's work is done"
	if left >= RunConfig.FREE_DAY_ACTIONS:
		return "A quiet day: time for %s" % _things(left)
	return "Time for %s more thing%s" % [NUMBER_WORDS[mini(left, 5)], "" if left == 1 else "s"]


## "one thing", "two things".
func _things(n: int) -> String:
	return "%s thing%s" % [NUMBER_WORDS[clampi(n, 0, 5)], "" if n == 1 else "s"]


func _day_title() -> String:
	match run.day_type():
		RunCalendar.DayType.BATTLE:
			return "The horns are sounding"
		RunCalendar.DayType.ELITE:
			return "Their best have come"
		RunCalendar.DayType.BOSS:
			return _boss_name()
	if run.event_pending():
		return "A matter for the commander"
	return "A quiet day"


func _day_text() -> String:
	match run.day_type():
		RunCalendar.DayType.BATTLE:
			return "The enemy is moving on the walls. The smith and the tavern are still open. Go to the gate when the company is ready."
		RunCalendar.DayType.ELITE:
			return "The enemy has sent its best against two places, and whoever breaks them brings home a stone. The smith and the tavern are still open. Go to the gate when the company is ready."
		RunCalendar.DayType.BOSS:
			return "It has come to the gate itself. If the company falls today, the city falls with it."
	if run.event_pending():
		return "No horns this morning, but someone is asking for you at the gate."
	return "No horns this morning. There is time for %s, in the city or beyond the walls, before the gates close. The smith, the tavern and the healer take only coin." % _things(
		RunConfig.FREE_DAY_ACTIONS)


func _boss_name() -> String:
	var g := run.boss_on(run.day)
	return g.display_name if g != null else "The enemy"


## A free-day action's cost in time, in the city's words.
func _time_cost() -> String:
	var after := run.actions_left - 1
	if after <= 0:
		return "This takes the rest of the day's time."
	return "This takes part of the day: afterwards there is time for %s more thing%s." % [NUMBER_WORDS[clampi(after, 0, 5)],
		"" if after == 1 else "s"]


func _hurt_text() -> String:
	# Only those a rest reaches: nobody in the infirmary.
	var hurt := 0
	var spent := 0
	var fit := run.available()
	for c in fit:
		if c.hp < c.max_hp():
			hurt += 1
		if c.progress.has_spent_uses():
			spent += 1
	var text := "%d of %d are hurt." % [hurt, fit.size()]
	if spent > 0:
		text += "  %d %s low on spells." % [spent, "is" if spent == 1 else "are"]
	var abed := run.infirmary().size()
	if abed > 0:
		text += "  Rest does nothing for the %s in the infirmary." % ("one" if abed == 1 else NUMBER_WORDS[mini(abed, 5)])
	return text


## The run's reasons, said the way the city would say them.
func _in_world(reason: String) -> String:
	match reason:
		"Only on free days.":
			return "Shut and barred while the horns are sounding. Come back on a quiet day."
		Run.EVENT_FIRST:
			return "Not yet. A matter is waiting for your answer at the gate."
		"Already done today.":
			return "You have already been here today."
		"No actions left today.":
			return "There is no time left for this today. The smith, the tavern and the healer still take coin."
		"Nobody is looking for work.":
			return "Nobody is looking for work today."
		"The city is at full health.":
			return "The walls are whole. There is nothing to mend."
		"Everyone is at full health and every spell use is ready.":
			return "Everyone is rested and every spell is ready. There is no need."
	return reason


## What an event choice changes, in one line. `ahead`: phrased before choosing (names who would be hurt).
static func choice_effects(r: Run, ch: EventChoiceData, ahead: bool) -> String:
	var parts: Array[String] = []
	# Gold as the company pays or gets it (a trait can lower a price).
	var gold := r.choice_gold(ch)
	if gold != 0:
		parts.append("%+d gold" % gold)
	for m in RunConfig.MATERIAL_ORDER:
		var n := int(ch.materials.get(m, 0))
		if n != 0:
			parts.append("%+d %s" % [n, String(RunConfig.MATERIAL_NAMES[m]).to_lower()])
	if ch.city_health != 0:
		parts.append("%+d to the walls" % ch.city_health)
	if ch.companion_hp != 0:
		if ch.hp_target == EventChoiceData.HpTarget.ALL:
			parts.append("%+d HP to every companion" % ch.companion_hp)
		else:
			var who := r.hp_targets(ch)
			var name := who[0].display_name() if ahead and not who.is_empty() else "your healthiest companion"
			parts.append("%+d HP to %s" % [ch.companion_hp, name])
	if ch.weapon != null:
		parts.append("gain a %s" % ch.weapon.display_name)
	if r.choice_gem(ch) > 0:
		parts.append("gain a %s" % Gem.name_of(r.choice_gem(ch)))
	return "nothing changes" if parts.is_empty() else "   ·   ".join(parts)


# ---------------------------------------------------------------- the buildings' state

func _refresh_buildings() -> void:
	var A := Run.FreeAction
	var over := run.is_over()
	var t := run.day_type()
	var free := t == RunCalendar.DayType.FREE and not over
	for kind: CityBuilding.Kind in _city.buildings:
		var b := _city.building(kind)
		b.attention = false
		match kind:
			CityBuilding.Kind.BARRACKS:
				b.open = true
				b.status = "The company: %d in the line%s" % [run.lineup.size(),
					", %d in reserve" % run.reserve().size() if not run.reserve().is_empty() else ""]
			CityBuilding.Kind.WATCHTOWER:
				b.open = true
				b.status = "See the days ahead"
			CityBuilding.Kind.GATE:
				b.open = true
				b.attention = not over and (not free or run.actions_left <= 0 or run.event_pending())
				match t:
					RunCalendar.DayType.BATTLE:
						b.status = "The horns are sounding"
					RunCalendar.DayType.ELITE:
						b.status = "Their best are at the walls"
					RunCalendar.DayType.BOSS:
						b.status = "%s is here" % _boss_name()
					_:
						b.status = "Someone is asking for you" if run.event_pending() else (
							"Send a party out, or close the gates" if _can_scavenge() else "Close the gates for the night")
			CityBuilding.Kind.TAVERN:
				var why := run.visit_block_reason(A.TAVERN)
				b.open = why == ""
				b.status = ("%d looking for work  ·  %d gold each" % [run.tavern_offers.size(), run.hire_cost()]) if why == "" \
					else _short(why)
			CityBuilding.Kind.SMITHY:
				var why := run.visit_block_reason(A.SHOP)
				b.open = why == ""
				b.status = "Weapons for sale" if why == "" else _short(why)
			CityBuilding.Kind.INFIRMARY:
				var beds := run.infirmary()
				b.open = true
				if beds.is_empty():
					b.status = "The beds are empty"
				else:
					var soonest := beds[0]
					for c in beds:
						if c.days_left(run.day) < soonest.days_left(run.day):
							soonest = c
					var left := soonest.days_left(run.day)
					b.status = "%d in the beds  ·  %s up %s" % [beds.size(), soonest.display_name(),
						"tomorrow" if left <= 1 else "in %d days" % left]
			CityBuilding.Kind.YARD:
				var why := run.free_action_block_reason(A.TRAIN)
				b.open = why == ""
				var posted: Array[String] = []
				for d in run.drills:
					posted.append(d.display_name.trim_suffix(" drill"))
				b.status = ("%s  ·  %d gold" % [", ".join(posted), run.drill_cost()]) if why == "" else _short(why)
			CityBuilding.Kind.INN:
				var why := run.free_action_block_reason(A.REST)
				b.open = why == ""
				b.status = ("Rest the company  ·  %s" % _hurt_text().split(".")[0]) if why == "" else _short(why)
			CityBuilding.Kind.MASON:
				b.open = true
				b.status = "Mend the walls, trade, build up the city"
			CityBuilding.Kind.JEWELER:
				b.open = false
				b.status = "Not built yet"


## A building's reason for being shut, short enough for its board.
func _short(reason: String) -> String:
	match reason:
		"Only on free days.":
			return "Shut today"
		Run.EVENT_FIRST:
			return "Opens after the matter at the gate"
		"Already done today.":
			return "Already visited today"
		"No actions left today.":
			return "No time left today"
		"The city is at full health.":
			return "The walls are whole"
		"Everyone is at full health and every spell use is ready.":
			return "Everyone is rested"
	return reason.trim_suffix(".")


# ---------------------------------------------------------------- the company

func _build_party() -> void:
	for child in _party_row.get_children():
		_party_row.remove_child(child)
		child.queue_free()
	for i in run.lineup.size():
		var c := run.lineup[i]
		var where := "In the line, place %d of %d%s" % [i + 1, run.lineup.size(),
			" (the front: nearest the enemy)" if i == run.lineup.size() - 1 else (" (the back)" if i == 0 else "")]
		_party_row.add_child(_medallion(c, true, where))
	if not run.reserve().is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(26, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_row.add_child(gap)
		for c in run.reserve():
			_party_row.add_child(_medallion(c, false, "In reserve"))
	if not run.infirmary().is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(26, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_row.add_child(gap)
		for c in run.infirmary():
			var left := c.days_left(run.day)
			var m := PartyMedallion.new()
			m.setup(c, false, "In the infirmary: %s" % ("up tomorrow" if left <= 1 else "%d days to go" % left))
			m.modulate = Color(0.62, 0.5, 0.5)
			m.pressed.connect(visit.bind(CityBuilding.Kind.INFIRMARY))
			_party_row.add_child(m)


func _medallion(c: RunCompanion, fielded: bool, where: String) -> PartyMedallion:
	var m := PartyMedallion.new()
	m.setup(c, fielded, where)
	m.pressed.connect(open_party.bind(c))
	return m


# ---------------------------------------------------------------- the day's news

## Puts a slip of parchment at the foot of the screen. `action`: called when the slip is clicked.
func _say(title: String, text: String, action: Callable = Callable()) -> void:
	_news_title.text = title
	_news_text.text = text
	_news_action = action
	_news.tooltip_text = "%s\n%s" % [title, text]
	_news.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if action.is_valid() else Control.CURSOR_ARROW
	_news.visible = true
	_news.modulate.a = 0.0
	if _news_tween != null:
		_news_tween.kill()
	_news_tween = create_tween()
	_news_tween.tween_property(_news, "modulate:a", 1.0, 0.25)


func _hide_news() -> void:
	if _news_tween != null:
		_news_tween.kill()
	_news.visible = false


# ---------------------------------------------------------------- input

func _overlay_open() -> bool:
	return _battle_screen.visible or _party_screen.visible or _store_screen.visible or _training_screen.visible or _infirmary_screen.visible \
		or _scavenge_screen.visible or _mason_screen.visible \
		or _end_screen.visible \
		or _letter.visible or _war_table.visible


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or run == null or run.is_over() or _busy or _overlay_open():
		return
	match key.keycode:
		KEY_P:
			get_viewport().set_input_as_handled()
			open_party()
		KEY_G, KEY_SPACE, KEY_ENTER:
			get_viewport().set_input_as_handled()
			visit(CityBuilding.Kind.GATE)
		KEY_E:
			if run.day_type() == RunCalendar.DayType.FREE:
				get_viewport().set_input_as_handled()
				visit(CityBuilding.Kind.GATE)
		KEY_W:
			get_viewport().set_input_as_handled()
			visit(CityBuilding.Kind.WATCHTOWER)


# ---------------------------------------------------------------- layout

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	_city.interactive = true
	_city.building_pressed.connect(visit)
	add_child(_city)

	# The strip at the top: the day on the left, the days ahead in the middle, the stores on the right.
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)
	_day_label = UiTheme.label("", 38, UiTheme.GOLD, true, 8)
	_day_label.position = Vector2(40, 8)
	add_child(_day_label)
	_mood_label = UiTheme.label("", 19, UiTheme.TEXT, false, 5)
	_mood_label.add_theme_font_override("font", UiTheme.italic_font())
	_mood_label.position = Vector2(43, 54)
	add_child(_mood_label)
	add_child(_strip)

	_city_bar.position = Vector2(1392, 22)
	_city_bar.size = Vector2(190, 26)
	_city_bar.font_size = 17
	_city_bar.tooltip_text = "The walls. They suffer when a battle is lost (%d, %d or %d by how dangerous the front was). If they fall to nothing, the city is lost." % RunConfig.CITY_DAMAGE_BY_DANGER
	_city_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_city_bar)
	_gold_label = _store(1640, "Gold: pays for weapons, hires and some choices.")
	_iron_label = _store(1740, "Iron ore: the masons need it to mend the walls, and it is traded now and then.")
	_timber_label = _store(1832, "Timber: the masons need it to mend the walls.")
	# The stones in hand, under the stores: only those the company holds.
	_gems.position = Vector2(1560, 56)
	_gems.size = Vector2(330, 30)
	_gems.mouse_filter = Control.MOUSE_FILTER_PASS
	_gems.draw.connect(_draw_gems)
	add_child(_gems)

	# The company, standing in the square.
	_party_row.position = Vector2(0, 952)
	_party_row.size = Vector2(1920, PartyMedallion.H)
	_party_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_row.add_theme_constant_override("separation", 2)
	_party_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_row)

	# The day's news: a slip of parchment at the foot of the screen.
	_news.position = Vector2(34, 958)
	_news.size = Vector2(470, 104)
	_news.rotation = -0.012
	_news.visible = false
	_news.mouse_filter = Control.MOUSE_FILTER_STOP
	_news.draw.connect(func() -> void: UiTheme.draw_parchment(_news, Rect2(Vector2.ZERO, _news.size), 0.4))
	_news.gui_input.connect(_on_news_input)
	add_child(_news)
	_news_title = UiTheme.label("", 19, UiTheme.PARCHMENT_INK, true)
	_news_title.position = Vector2(18, 10)
	_news_title.size = Vector2(434, 24)
	_news_title.clip_text = true
	_news.add_child(_news_title)
	_news_text = UiTheme.label("", 16, UiTheme.PARCHMENT_INK)
	_news_text.add_theme_font_override("font", UiTheme.italic_font())
	_news_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_text.max_lines_visible = 3
	_news_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_news_text.position = Vector2(18, 34)
	_news_text.size = Vector2(436, 64)
	_news.add_child(_news_text)

	# Screens that open over the city.
	for screen: Control in [_war_table, _party_screen, _store_screen, _training_screen, _infirmary_screen, _scavenge_screen, _mason_screen,
			_letter, _battle_screen, _end_screen]:
		screen.visible = false
		screen.z_index = 10
		add_child(screen)
	# A letter leaves the walls, the gold and the materials unshaded: its choices are paid in them.
	_letter.window = Rect2(1336, 0, 584, 64)
	_war_table.chosen.connect(defend)
	_party_screen.closed.connect(refresh)
	_store_screen.closed.connect(refresh)
	_training_screen.closed.connect(refresh)
	_infirmary_screen.closed.connect(refresh)
	_scavenge_screen.closed.connect(refresh)
	_mason_screen.closed.connect(refresh)
	_battle_screen.finished.connect(_on_battle_finished)
	_battle_screen.closed.connect(_on_battle_closed)
	_end_screen.closed.connect(func() -> void: left_run.emit())

	# The curtain between days.
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_curtain.visible = false
	_curtain.z_index = 20
	_curtain.draw.connect(func() -> void:
		_curtain.draw_rect(Rect2(Vector2.ZERO, _curtain.size), UiTheme.INK)
		UiTheme.draw_rule(_curtain, Vector2(_curtain.size.x * 0.5, _curtain.size.y * 0.5 + 34.0), 420.0, UiTheme.GOLD_DEEP))
	add_child(_curtain)
	_curtain_title = UiTheme.label("", 110, UiTheme.GOLD, true)
	_curtain_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain_title.offset_bottom = -110.0
	_curtain_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curtain_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_curtain.add_child(_curtain_title)
	_curtain_sub = UiTheme.label("", 30, UiTheme.TEXT)
	_curtain_sub.add_theme_font_override("font", UiTheme.italic_font())
	_curtain_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain_sub.offset_top = 150.0
	_curtain_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curtain_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_curtain.add_child(_curtain_sub)


func _draw_top() -> void:
	UiIcons.rampart(_top, Vector2(1364, 35), 28.0, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3))
	UiIcons.coin(_top, Vector2(1622, 34), 24.0, UiTheme.GOLD)
	UiIcons.ore(_top, Vector2(1722, 35), 24.0, Color("9aa3ad"))
	UiIcons.timber(_top, Vector2(1812, 35), 26.0, Color("a0794a"))


## The gemstones in hand, weakest first, each with how many: right-aligned under the stores.
func _draw_gems() -> void:
	if run == null:
		return
	var font := UiTheme.display_font()
	var x := _gems.size.x
	for rank in range(Gem.max_rank(), 0, -1):
		var n := run.gem_count(rank)
		if n <= 0:
			continue
		var text := str(n)
		x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		UiTheme.draw_text(_gems, font, Vector2(x, 2.0), text, 20, UiTheme.TEXT, 5)
		x -= 17.0
		UiIcons.gem(_gems, Vector2(x, 15.0), 20.0, rank)
		x -= 26.0


func _gems_text() -> String:
	var held: Array[String] = []
	for rank in range(1, Gem.max_rank() + 1):
		if run.gem_count(rank) > 0:
			held.append("%d %s" % [run.gem_count(rank), Gem.name_of(rank)])
	if held.is_empty():
		return ""
	return "Gemstones: %s.\nThe jeweler sets a stone into something to wear." % ", ".join(held)


func _store(x: float, tip: String) -> Label:
	var hit := Control.new()
	hit.position = Vector2(x - 34.0, 12.0)
	hit.size = Vector2(90, 46)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.tooltip_text = tip
	add_child(hit)
	var v := UiTheme.label("0", 26, UiTheme.TEXT, true, 6)
	v.position = Vector2(x, 17)
	add_child(v)
	return v


func _on_news_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _news_action.is_valid():
			_news_action.call()
		else:
			_hide_news()


static func _names(cs: Array[RunCompanion]) -> Array[String]:
	var out: Array[String] = []
	for c in cs:
		out.append(c.display_name())
	return out
