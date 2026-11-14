extends SceneTree
## Screen check: the jeweler's room: the tray, setting a stone, the designs, who wears it, the case.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("jq_%s.png" % name))
	print("saved ", name)
func _click(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.15)
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
	city._letter.close()
	run.day = 2
	run._begin_day()
	run.event = null
	run.gold = 400
	run.add_gem(1)
	run.add_gem(1)
	run.add_gem(3)
	run.add_gem(5)
	run.hire(run.tavern_offers[0])
	city.refresh(false)
	await _wait(0.5)
	if city._letter.is_open():
		city._letter.close()
	city.visit(CityBuilding.Kind.JEWELER)
	await _wait(0.5)
	var jw = city._jeweler_screen
	print("not built: screen open ", jw.visible, "  news: ", city._news_text.text)
	run.facilities[Run.Facility.JEWELER] = 1
	city.refresh(false)
	await _wait(0.3)
	var b = city._city.building(CityBuilding.Kind.JEWELER)
	print("built: open ", b.open, " status ", b.status)
	# A real click on the building.
	await _click(Vector2(110, 470))
	await _wait(0.5)
	print("after click: screen open ", jw.visible, " picked ", jw._picked, " seal '", jw._seal.title, "' ", jw._seal.detail, " disabled ", jw._seal.disabled)
	await _shot("tray")
	# Pick the topaz with a click, then press the seal.
	await _click(JewelerScreen.TRAY.position + Vector2(40 + 96, 62 + 92))
	print("picked ", jw._picked, " seal '", jw._seal.title, "' ", jw._seal.detail)
	var gold := run.gold
	await _click(JewelerScreen.SEAL_AT + Vector2(120, 25))
	print("crafting: offer ", run.craft_offer != null, " gold ", gold, " -> ", run.gold, " topaz left ", run.gem_count(1), " actions ", run.actions_left)
	await _wait(0.35)
	await _shot("cut_1")
	await _wait(0.5)
	await _shot("cut_2")
	await _wait(1.2)
	await _shot("design_one")
	if run.craft_offer != null:
		print("design: ", run.craft_offer.designs[0].display_name, " | ", run.craft_offer.designs[0].lines(1))
	jw.close()
	print("leave refused while offer open: ", jw.visible)
	jw.take(0)
	await _wait(0.4)
	print("made ", jw._made.title() if jw._made != null else "none", " owned ", run.accessories.size())
	await _shot("who")
	jw.wear(run.roster[0])
	await _wait(0.3)
	print("worn by ", run.wearer_of(run.accessories[0]).display_name() if run.wearer_of(run.accessories[0]) != null else "nobody")
	await _shot("case")
	print("  seal after: disabled ", jw._seal.disabled, " why '", jw._why.text, "'")
	# The second level: two designs, a diamond, on the next free day.
	run.facilities[Run.Facility.JEWELER] = 2
	run.day = 4
	run._begin_day()
	run.event = null
	print('  day 4 type ', run.day_type(), ' block: ', run.craft_block_reason(5))
	jw.refresh()
	jw.pick(5)
	jw.set_stone()
	jw._skip()
	await _wait(0.4)
	if run.craft_offer != null:
		for d in run.craft_offer.designs:
			print("  design: ", d.display_name, " | ", d.lines(5))
	await _shot("design_two")
	jw.take(1)
	await _wait(0.3)
	await _shot("who_two")
	jw.put_away()
	await _wait(0.3)
	await _shot("case_two")
	jw.close()
	print("closed ", not jw.visible)
	quit()
