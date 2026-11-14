extends SceneTree
## Screen check: callings on the Barracks sheet (the three drawn, one read by pointing at it, then the
## one taken, with another's closed) and on the hires' papers in the Tavern.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("sheets_%s.png" % name))
	print("saved ", name)
func _move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.25)
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
	a.progress.calling_offers.assign([lib.find("champion"), lib.find("berserker"), lib.find("mender")])
	b.progress.calling_offers.assign([lib.find("champion"), lib.find("sage"), lib.find("hunter")])
	city.open_party(a)
	await _wait(0.5)
	await _shot("1_barracks_three")
	var ps: PartyScreen = city._party_screen
	var plate: Control = ps._callings.get_child(1)
	await _move(plate.global_position + plate.size * 0.5)
	await _shot("2_barracks_reading")
	ps.close()
	while a.level() < RunConfig.CALLING_LEVEL:
		Levels.level_up(a.progress, run.rng)
	run.take_calling(a, lib.find("berserker"))
	b.progress.calling_offers.assign([lib.find("berserker"), lib.find("sage"), lib.find("hunter")])
	city.open_party(a)
	await _wait(0.5)
	await _move(Vector2(1700, 400))
	await _shot("3_barracks_taken")
	ps.select(b)
	await _wait(0.3)
	await _shot("4_barracks_one_closed")
	ps.close()
	run.gold = 500
	if not run.tavern_offers.is_empty():
		run.offer_progress(run.tavern_offers[0]).calling_offers[0] = lib.find("berserker")
	city.open_tavern()
	await _wait(0.8)
	await _shot("5_tavern")
	quit()
