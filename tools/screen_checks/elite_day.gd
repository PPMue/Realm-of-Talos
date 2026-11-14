extends SceneTree
## Screen check: an elite day on the day strip, in the city, at the war table; stones in the header.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("el_%s.png" % name))
	print("saved ", name)
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
	await _wait(0.3)
	await _shot("day1")
	for i in city._strip._count():
		var tip: String = city._strip._get_tooltip(city._strip._center(i))
		if tip.contains("elite") or tip.contains("brings"):
			print("  tooltip ", i, ": ", tip.replace("\n", " | "))
	run.day = 6
	run._begin_day()
	run.add_gem(1)
	run.add_gem(1)
	run.add_gem(4)
	city.refresh(false)
	await _wait(0.6)
	if city._letter.is_open():
		city._letter.close()
	print("day 6 type ", run.day_type(), " fronts ", run.fronts.size(), " elite ", run.fronts[0].is_elite, " gem ", run.fronts[0].gem,
		" mood: ", city._mood(), " | ", city._day_title())
	await _shot("day6_city")
	print("  gems tip: ", city._gems.tooltip_text.replace("\n", " | "))
	city.visit(CityBuilding.Kind.GATE)
	await _wait(0.6)
	await _shot("day6_table")
	city._war_table.close()
	run.day = 14
	run._begin_day()
	city.refresh(false)
	await _wait(0.5)
	if city._letter.is_open():
		city._letter.close()
	print("day 14 type ", run.day_type(), " gem ", run.fronts[0].gem)
	city.visit(CityBuilding.Kind.GATE)
	await _wait(0.6)
	await _shot("day14_table")
	quit()
