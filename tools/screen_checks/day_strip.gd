extends SceneTree
## Screen check: the day strip around a boss with the new calendar.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
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
	var line := ""
	for d in range(1, RunConfig.DAYS + 1):
		line += "%d%s " % [d, ["B", "f", "BOSS", "E"][run.calendar[d - 1]]]
	print(line)
	print("events ", run.event_days)
	for d in [9, 13, 15, 27]:
		run.day = d
		run.event = null
		city.refresh(false)
		await _wait(0.4)
		await process_frame
		root.get_texture().get_image().save_png(out_dir.path_join("cal_%02d.png" % d))
		print("day ", d, " type ", run.day_type(), " strip: ", city._strip._types)
	quit()
