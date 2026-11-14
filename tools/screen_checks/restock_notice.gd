extends SceneTree
## Screen check: when the smithy and the tavern restock, on the day strip and in both rooms.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("rs_%s.png" % name))
	print("saved ", name)
func _wait(s: float) -> void:
	await create_timer(s).timeout
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
	for d in [1, 5, 7, 8, 38]:
		run.day = d
		run.calendar[d - 1] = RunCalendar.DayType.FREE
		run.event = null
		run.gold = 500
		if run.tavern_offers.is_empty():
			run._make_tavern_offers()
		city.refresh(false)
		await _wait(0.4)
		print("day ", d, ": to restock ", store._days_to_restock() if store.run != null else -99)
		await _shot("city_%02d" % d)
		print("  tooltip today: ", city._strip._get_tooltip(city._strip._center(0)).replace("\n", " | "))
		for i in range(1, city._strip._count()):
			var tip: String = city._strip._get_tooltip(city._strip._center(i))
			if tip.contains("wagon"):
				print("  tooltip ", i, ": ", tip.replace("\n", " | "))
		city.visit(CityBuilding.Kind.SMITHY)
		await _wait(0.5)
		print("  smithy open ", store.visible, "  ", store._restock_words("New stock", "The last wagon has come"))
		await _shot("smithy_%02d" % d)
		store.close()
		await _wait(0.3)
		city.visit(CityBuilding.Kind.TAVERN)
		await _wait(0.5)
		print("  tavern open ", store.visible, "  ", store._restock_words("New faces", "Nobody else is on the road"))
		await _shot("tavern_%02d" % d)
		store.close()
		await _wait(0.3)
		if city._letter.is_open():
			city._letter.close()
	quit()
