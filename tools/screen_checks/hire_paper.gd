extends SceneTree
## Screen check: a hire's paper in week 1 and after weeks of practice outside the company.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("hv_%s.png" % name))
	print("saved ", name)
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _say(run: Run) -> void:
	for d in run.tavern_offers:
		var p := run.offer_progress(d)
		var arts: Array[String] = []
		for a in p.known_arts:
			arts.append(a.display_name)
		var spells: Array[String] = []
		for s in p.known_spells:
			spells.append(s.display_name)
		print("  ", d.display_name, ": ", StoreScreen._skills_text(p).split("\n")[0], " | arts ", arts, " spells ", spells, " | cost ", run.hire_cost())
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
	var store = city._store_screen
	run.gold = 900
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event = null
	city.refresh(false)
	city.visit(CityBuilding.Kind.TAVERN)
	await _wait(0.5)
	print("week 1")
	_say(run)
	await _shot("week1")
	store.close()
	await _wait(0.3)
	# Weeks pass: the restock is called as the run does it, on the first day of each week.
	for week in [2, 3, 4, 5, 6]:
		run.day = (week - 1) * RunConfig.WEEK_DAYS + 1
		run._restock_week()
		if week == 3 or week == 6:
			run.calendar[run.day - 1] = RunCalendar.DayType.FREE
			run.event = null
			if week == 6:
				run._offer_more(3 - run.tavern_offers.size())
			city.refresh(false)
			city.visit(CityBuilding.Kind.TAVERN)
			await _wait(0.5)
			print("week ", week, "  offers ", run.tavern_offers.size())
			_say(run)
			await _shot("week%d" % week)
			if week == 6:
				print("  tooltip: ", store._papers.get_child(0).tooltip_text.replace("\n", " | "))
				var who := run.tavern_offers[0]
				var before := run.offer_progress(who)
				store.hire(who)
				store._skip()
				await _wait(0.3)
				var c: RunCompanion = run.roster[-1]
				print("  hired ", c.display_name(), " level ", c.level(), " same progress ", c.progress == before, " arts ", c.progress.known_arts.size(),
					" equipped ", c.progress.equipped_arts.size(), " gold left ", run.gold)
				await _shot("week6_hired")
			store.close()
			await _wait(0.3)
	quit()
