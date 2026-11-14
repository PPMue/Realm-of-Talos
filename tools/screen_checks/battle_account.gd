extends SceneTree
## Screen check: the account. Before: the war table on a battle day, an elite day and a boss day, each
## report with the hardest blow against the line and the scouts' word. After: a battle played to its
## end and the result's second beat, "How it went".
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("account_%s.png" % name))
	print("saved ", name)
func _click() -> void:
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = Vector2(960, 1000)
		mb.global_position = mb.position
		root.push_input(mb, true)
		await _wait(0.1)
func _table(city: CityScreen, run: Run, day: int, name: String) -> void:
	run.day = day
	run._begin_day()
	run.event = null
	city.refresh(false)
	await _wait(0.5)
	if city._letter.is_open():
		city._letter.close()
	for f in run.fronts:
		var a := run.front_account(f)
		var blow: Dictionary = a.blow
		print("day ", day, " ", f.title(), ": ratio %.2f" % float(a.ratio), ", word ", a.word, ", worst ",
			"%s %d to %s%s" % [blow.action.display_name, blow.damage, blow.target.display_name, " (fells)" if blow.fells else ""] if not blow.is_empty() else "-")
	city.visit(CityBuilding.Kind.GATE)
	await _wait(0.7)
	await _shot(name)
func _run() -> void:
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var game: Game = packed.instantiate()
	root.add_child(game)
	await _wait(0.4)
	var city := game.city
	game.start_run(11, false)
	await _wait(2.4)
	var run := city.run
	city._letter.close()
	# A line of two, as a run begins.
	await _table(city, run, 1, "1_table_two")
	city._war_table.close()
	run.gold = 2000
	run.day = 8
	run._begin_day()
	run.event = null
	while run.lineup.size() < 4 and not run.tavern_offers.is_empty() and run.hire(run.tavern_offers[0]) != null:
		pass
	for c in run.roster:
		for i in 7:
			Levels.level_up(c.progress, run.rng)
		c.hp = c.max_hp()
	await _table(city, run, 20, "2_table_elite")
	city._war_table.close()
	await _table(city, run, 28, "3_table_boss")
	city._war_table.close()
	await _table(city, run, 30, "4_table_late")
	# March out at the last report and fight it to the end with plain Attacks.
	var front: Front = run.fronts[run.fronts.size() - 1]
	city._war_table.close()
	city.defend(front)
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var b: Battle = bs.battle
	var guard := 0
	while not b.is_over() and guard < 400:
		guard += 1
		if b.can_wait():
			b.wait()
			continue
		var target := b.living_enemies()[0]
		for e in b.living_enemies():
			if e.hp < target.hp:
				target = e
		b.attack(b.ready_companions()[0], target)
	print("battle over on turn ", b.tick, ", outcome ", b.outcome)
	for line in b.account.lines(b):
		print("  ", line)
	bs._commit(null)
	await _wait(4.0)
	await _shot("5_result_spoils")
	await _click()
	await _wait(0.6)
	await _shot("6_how_it_went")
	await _click()
	await _wait(0.8)
	await _shot("7_after")
	quit()
