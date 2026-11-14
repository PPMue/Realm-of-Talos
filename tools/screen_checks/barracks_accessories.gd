extends SceneTree
## Screen check: accessories on the barracks sheet: worn, the case, putting on, taking off.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("ac_%s.png" % name))
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
	run.hire(run.tavern_offers[0])
	var lib := AccessoryLibrary.load_default()
	print("types ", lib.types.size())
	for pair in [["ring", 1], ["pendant", 3], ["skull", 4], ["locket", 2], ["ring", 5], ["tiara", 2]]:
		run.accessories.append(Accessory.new(lib.find(pair[0]), pair[1]))
	var freya: RunCompanion = run.roster[0]
	var erik: RunCompanion = run.roster[1]
	print("wear ring: ", run.wear(freya, run.accessories[0]), "  pendant on erik: ", run.wear(erik, run.accessories[1]))
	print("freya second ring blocked: '", run.wear_block_reason(freya, run.accessories[4]), "'")
	city.refresh(false)
	city.open_party(freya)
	await _wait(0.6)
	var ps = city._party_screen
	print("freya STR ", freya.progress.stats()[Stat.STR], " from accessories ", freya.progress.accessory_stat_bonus(Stat.STR), " hp ", freya.hp, "/", freya.max_hp())
	await _shot("sheet")
	# A real click on the first case row that can be put on (the skull), found by its title.
	for row in ps._case.get_children():
		if row is RowButton and row.title == "Ruby Skull":
			await _click(row.global_position + Vector2(120, 20))
			break
	await _wait(0.3)
	var worn: Array[String] = []
	for a in run.accessories_of(freya):
		worn.append(a.title())
	print("after click, freya wears ", worn)
	await _shot("sheet_two")
	# Take the pendant from Erik with a click.
	for row in ps._case.get_children():
		if row is RowButton and row.title == "Emerald Pendant":
			print("pendant row detail '", row.detail, "' disabled ", row.disabled, " tip: ", row.tooltip_text.replace("\n", " | "))
	# Take the ring off with a click on its worn row.
	for row in ps._worn.get_children():
		if row is RowButton and row.title == "Topaz Ring":
			await _click(row.global_position + Vector2(120, 20))
			break
	await _wait(0.3)
	worn.clear()
	for a in run.accessories_of(freya):
		worn.append(a.title())
	print("after taking off, freya wears ", worn, " STR ", freya.progress.stats()[Stat.STR])
	ps.select(erik)
	await _wait(0.3)
	await _shot("sheet_erik")
	ps.close()
	# The battle sheet.
	run.day = 3
	run._begin_day()
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	city.defend(run.fronts[0])
	await _wait(3.5)
	var bs = city._battle_screen
	for c in bs._party_sheets:
		print("--- battle sheet ---\n", String(bs._party_sheets[c]).substr(0, 700))
		break
	quit()
