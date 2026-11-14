extends SceneTree
## Screen check: the mason's plan with ten facilities.
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
	run.day = 2
	run._begin_day()
	run.event = null
	run.materials[RunConfig.IRON_ORE] = 9
	run.materials[RunConfig.TIMBER] = 9
	city.refresh(false)
	if city._letter.is_open():
		city._letter.close()
	city.visit(CityBuilding.Kind.MASON)
	await _wait(0.6)
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("ms_plan.png"))
	print("jeweler lines: ", run.facility_lines(Run.Facility.JEWELER, 1), " | ", run.facility_lines(Run.Facility.JEWELER, 2), " cost ", run.upgrade_cost(Run.Facility.JEWELER))
	quit()
