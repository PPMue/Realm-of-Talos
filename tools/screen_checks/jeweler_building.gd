extends SceneTree
## Screen check: the jeweler's building in the city, shut and open, by day and by night.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("jw_%s.png" % name))
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
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event = null
	city.refresh(false)
	await _wait(1.5)
	await _shot("shut")
	var b = city._city.building(CityBuilding.Kind.JEWELER)
	b.open = true
	b.status = "Set a stone  ·  2 in hand"
	b.attention = true
	await _wait(0.5)
	await _shot("open")
	quit()
