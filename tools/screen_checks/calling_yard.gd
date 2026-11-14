extends SceneTree
## Screen check: "a day to look elsewhere" at the Drill Yard. The chosen companion's callings at their
## feet, one picked to be put aside, and the one drawn in its place.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("yard_%s.png" % name))
	print("saved ", name)
func _click(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.2)
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
	run.day = 2
	run._begin_day()
	run.event = null
	run.gold = 200
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	print("day type ", run.day_type(), " yard: ", city._yard_block_reason())
	city.open_training()
	await _wait(0.6)
	var ts: TrainingScreen = city._training_screen
	await _shot("1_callings")
	var plate: Control = ts._callings.get_child(2)
	await _click(plate.global_position + plate.size * 0.5)
	await _shot("2_picked")
	var before := ts._who.progress.calling_offers.map(func(c: CallingData) -> String: return c.display_name)
	await _click(ts._look.global_position + Vector2(60, 20))
	await _wait(0.3)
	await _shot("3_drawn")
	print(before, " -> ", ts._who.progress.calling_offers.map(func(c: CallingData) -> String: return c.display_name), " gold ", run.gold,
		" actions ", run.actions_left)
	quit()
