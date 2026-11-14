extends SceneTree
## Screen check: a calling's mastery (design/callings.md, step 2). The moment it is chosen at level 8
## (the two cards under the calling's rule, one picked), then the Barracks sheet: the calling with its
## two masteries beside it before the choice, one read by pointing at it, and after it.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("mastery_%s.png" % name))
	print("saved ", name)
func _move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.2)
func _click(at: Vector2) -> void:
	await _move(at)
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		root.push_input(mb, true)
		await _wait(0.1)
func _run() -> void:
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var game: Game = packed.instantiate()
	root.add_child(game)
	await _wait(0.4)
	var city := game.city
	game.start_run(11, false)
	await _wait(2.4)
	var run := city.run
	if city._letter.is_open():
		city._letter.close()
	var lib := CallingLibrary.load_default()
	var a := run.roster[0]
	var b := run.roster[1]
	a.progress.calling_offers.assign([lib.find("spellblade"), lib.find("executioner"), lib.find("mender")])
	b.progress.calling_offers.assign([lib.find("hunter"), lib.find("sage"), lib.find("warden")])
	for c in [a, b]:
		while c.level() < RunConfig.CALLING_LEVEL:
			Levels.level_up(c.progress, run.rng)
	run.take_calling(a, lib.find("executioner"))
	run.take_calling(b, lib.find("hunter"))
	# Before level 8: the Barracks shows the calling with its two masteries still to come.
	city.open_party(a)
	await _wait(0.5)
	var ps: PartyScreen = city._party_screen
	await _move(Vector2(1700, 400))
	await _shot("1_barracks_to_come")
	var plate: Control = ps._callings.get_child(1)
	await _move(plate.global_position + plate.size * 0.5)
	await _shot("2_barracks_reading")
	ps.close()
	for c in [a, b]:
		while c.level() < RunConfig.MASTERY_LEVEL:
			Levels.level_up(c.progress, run.rng)
	city.refresh(false)
	await _wait(0.6)
	var panel: CallingPanel = city._calling
	print("open ", panel.is_open(), " who ", panel.who().display_name(), " stage ", panel.stage())
	await _shot("3_two_masteries")
	var at := panel._band.position
	await _move(at + Vector2(CallingPanel.X + CallingPanel.SPELL_W + CallingPanel.CARD_GAP + 100.0, CallingPanel.MASTERY_Y + 100.0))
	await _shot("4_hover")
	await _click(at + Vector2(CallingPanel.X + 100.0, CallingPanel.MASTERY_Y + 100.0))
	await _shot("5_picked")
	await _click(panel._take.global_position + Vector2(40, 20))
	await _wait(0.5)
	print("mastery of ", a.display_name(), ": ", a.progress.mastery.display_name if a.progress.mastery != null else "none")
	print("now ", panel.who().display_name(), " stage ", panel.stage())
	await _shot("6_the_next_one")
	await _click(at + Vector2(CallingPanel.X + CallingPanel.SPELL_W + CallingPanel.CARD_GAP + 100.0, CallingPanel.MASTERY_Y + 100.0))
	await _click(panel._take.global_position + Vector2(40, 20))
	await _wait(0.5)
	print("mastery of ", b.display_name(), ": ", b.progress.mastery.display_name if b.progress.mastery != null else "none", "; open ", panel.is_open())
	city.open_party(a)
	await _wait(0.5)
	await _move(Vector2(1700, 400))
	await _shot("7_barracks_taken")
	plate = ps._callings.get_child(2)
	await _move(plate.global_position + plate.size * 0.5)
	await _shot("8_barracks_the_other")
	ps.close()
	# In a battle: the mastery beside the calling over the name, and a Warden's Guard reaching the far
	# end of the line.
	run.gold = 2000
	while run.lineup.size() < 4 and not run.tavern_offers.is_empty() and run.hire(run.tavern_offers[0]) != null:
		pass
	var picks := [["warden", 0], ["spellblade", 0]]
	var bolt := load("res://data/spells/black/shadow_bolt.tres") as SpellData
	for i in range(2, run.lineup.size()):
		var c := run.lineup[i]
		while c.level() < RunConfig.MASTERY_LEVEL:
			Levels.level_up(c.progress, run.rng)
		var calling := lib.find(picks[i - 2][0])
		c.progress.calling_offers.assign([calling])
		run.take_calling(c, calling, calling.school, bolt if calling.school >= 0 else null)
		run.take_mastery(c, calling.masteries[picks[i - 2][1]])
		c.hp = c.max_hp()
	print("line: ", run.lineup.map(func(c: RunCompanion) -> String: return "%s %s / %s" % [c.display_name(),
		c.progress.calling.display_name if c.progress.calling != null else "-", c.progress.mastery.display_name if c.progress.mastery != null else "-"]))
	run.day = 9
	run._begin_day()
	run.event = null
	while not run.is_fight_day():
		run.day += 1
		run._begin_day()
		run.event = null
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	city.defend(run.fronts[run.fronts.size() - 1])
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var r := bs.battle.roster
	var warden: CompanionUnit = null
	var blade: CompanionUnit = null
	for u in r:
		if u.calling() != null and u.calling().id == "warden":
			warden = u
		if u.calling() != null and u.calling().id == "spellblade":
			blade = u
	bs.pick_companion(warden)
	bs._refresh()
	await _wait(0.3)
	await _shot("9_battle_warden")
	bs.choose_action(ActionMenu.GUARD)
	await _wait(0.3)
	await _shot("10_guard_anyone")
	print("wards ", bs.battle.guard_wards(warden).size())
	bs.cancel_targeting()
	bs.pick_companion(blade)
	bs._refresh()
	await _wait(0.3)
	await _shot("11_battle_spellblade")
	quit()
