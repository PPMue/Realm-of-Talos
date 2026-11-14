extends SceneTree
## Screen check: the moment a companion takes their calling (CallingPanel). The three cards, one
## picked, a calling of magic's spells (a Sage's two schools), and the gains coming up.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("calling_%s.png" % name))
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
	a.progress.calling_offers.assign([lib.find("champion"), lib.find("executioner"), lib.find("mender")])
	b.progress.calling_offers.assign([lib.find("champion"), lib.find("sage"), lib.find("hunter")])
	for c in [a, b]:
		while c.level() < RunConfig.CALLING_LEVEL:
			Levels.level_up(c.progress, run.rng)
	city.refresh(false)
	await _wait(0.6)
	var panel: CallingPanel = city._calling
	print("open ", panel.is_open(), " who ", panel.who().display_name())
	await _shot("1_three")
	var at := panel._band.position
	await _move(at + Vector2(CallingPanel.X + 100.0, 300.0))
	await _shot("2_hover")
	await _click(at + Vector2(CallingPanel.X + 100.0, 300.0))
	await _shot("3_picked")
	await _click(panel._take.global_position + Vector2(40, 20))
	await _wait(1.6)
	await _shot("4_gains")
	print("calling of ", a.display_name(), ": ", a.progress.calling.display_name if a.progress.calling != null else "none")
	await _click(Vector2(960, 1000))
	await _wait(0.5)
	print("now ", panel.who().display_name(), " stage ", panel.stage())
	await _shot("5_second_one_closed")
	# The Sage: its spell face, both schools.
	await _click(at + Vector2(CallingPanel.X + 100.0, 300.0))   # the open ones stand first: the Sage
	await _click(panel._take.global_position + Vector2(40, 20))
	await _wait(0.3)
	await _shot("6_sage_school")
	await _click(at + Vector2(CallingPanel.X + CallingPanel.SPELL_W + CallingPanel.CARD_GAP + 100.0, CallingPanel.CARD_Y + 20.0))
	await _wait(0.2)
	await _click(at + Vector2(CallingPanel.X + 100.0, CallingPanel.SPELL_Y + 100.0))
	await _shot("7_sage_white_spell")
	await _click(panel._take.global_position + Vector2(40, 20))
	await _wait(1.6)
	await _shot("8_sage_gains")
	await _click(Vector2(960, 1000))
	await _wait(0.5)
	print("open after all ", panel.is_open(), "; ", b.display_name(), " is ", b.progress.calling.display_name if b.progress.calling != null else "none",
		" knows ", b.progress.known_spells.map(func(s: SpellData) -> String: return s.display_name))
	await _shot("9_city_again")
	quit()
