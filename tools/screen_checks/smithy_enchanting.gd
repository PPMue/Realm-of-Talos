extends SceneTree
## Screen check: the smith's work, the choice and a hire, frame by frame, with real clicks.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("an_%s.png" % name))
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _click(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await process_frame
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = at
		mb.global_position = at
		root.push_input(mb, true)
		await process_frame
func _frames(tag: String, times: Array, store) -> void:
	var t0 := Time.get_ticks_msec()
	for at: float in times:
		var left := at - (Time.get_ticks_msec() - t0) / 1000.0
		if left > 0.0:
			await _wait(left)
		await _shot("%s_%03d" % [tag, roundi(at * 100.0)])
		print("  ", tag, " t=", at, " busy ", store._busy(), " forge ", snappedf(store._forge, 0.01), " hire_t ", snappedf(store._hire_t, 0.01), " slide ", snappedf(store._slide, 0.01))
func _run() -> void:
	var packed: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var game: Game = packed.instantiate()
	root.add_child(game)
	await _wait(0.4)
	var city := game.city
	game.start_run(7, false)
	await _wait(2.4)
	var run := city.run
	city._letter.close()
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run._begin_day()
	run.event = null
	run.gold = 900
	run.materials[RunConfig.TIMBER] = 20
	run.materials[RunConfig.IRON_ORE] = 30
	run.upgrade(Run.Facility.SMITHY)
	run.upgrade(Run.Facility.SMITHY)
	var fine: OwnedWeapon = run.inventory.add(load("res://data/weapons/platinum_sword.tres"))
	run.roster[0].progress.points[WeaponData.WeaponType.SWORD] = 200
	run.equip_weapon(run.roster[0], fine)
	city.refresh(false)
	city.open_shop()
	var store = city._store_screen
	await _wait(0.6)
	# The anvil row of the platinum sword: a real click.
	var row: Control = null
	for child in store._list.get_children():
		if child is RowButton and child.title.begins_with("Platinum Sword") and child.sub.contains("held by"):
			row = child
	print("row ", row.title if row != null else "none")
	await _click(row.global_position + Vector2(200, 20))
	print("clicked: offer ", run.enchant_offer != null, " busy ", store._busy(), " gold ", run.gold)
	await _frames("forge", [0.1, 0.33, 0.45, 0.7, 0.95, 1.2, 1.5, 1.8, 2.3, 3.0, 3.8], store)
	print("after forge: busy ", store._busy(), " cards ", store._bench.get_child_count())
	# Take the first of the smith's two: a real click on its seal.
	var card: Control = store._bench.get_child(1)
	await _click(card.get_child(0).global_position + Vector2(120, 25))
	print("took: offer ", run.enchant_offer != null, " ", fine.title(), " busy ", store._busy())
	await _frames("choice", [0.12, 0.35, 0.7, 0.95, 1.3], store)
	print("after choice: bench visible ", store._bench.visible, " busy ", store._busy(), " note: ", store._note.text)
	# Again, and a click while the smith is at work skips to the papers.
	for child in store._list.get_children():
		if child is RowButton and child.title.begins_with("Platinum Sword") and child.sub.contains("held by"):
			row = child
	await _click(row.global_position + Vector2(200, 20))
	await _wait(0.3)
	print("second try: busy ", store._busy(), " forge ", snappedf(store._forge, 0.01))
	await _click(Vector2(300, 800))
	print("after a click: busy ", store._busy(), " forge ", store._forge, " cards alpha ", store._bench.get_children().map(func(c): return c.modulate.a), " offer ", run.enchant_offer != null)
	await _shot("skip")
	card = store._bench.get_child(0)
	await _click(card.get_child(0).global_position + Vector2(120, 25))
	await _wait(0.2)
	await _click(Vector2(300, 800))
	print("kept and skipped: bench visible ", store._bench.visible, " busy ", store._busy(), " offer ", run.enchant_offer != null, " note: ", store._note.text)
	store.close()
	print("smithy closed ", not store.visible)
	# The tavern: three at the counter.
	run._offer_more(3 - run.tavern_offers.size())
	run.gold = 900
	city.refresh(false)
	city.open_tavern()
	await _wait(0.6)
	await _shot("hire_000")
	var paper: Control = store._papers.get_child(1)
	var seal: Control = paper.get_child(0)
	var size0 := run.roster.size()
	await _click(seal.global_position + Vector2(120, 25))
	print("hire clicked: roster ", size0, " -> ", run.roster.size(), " offers ", run.tavern_offers.size(), " busy ", store._busy(), " gold ", run.gold)
	await _frames("hire", [0.08, 0.2, 0.45, 0.75, 1.0, 1.25, 1.45, 1.6, 2.0], store)
	print("after hire: busy ", store._busy(), " papers ", store._papers.get_child_count(), " at ", store._papers.get_children().map(func(p): return roundi(p.position.x)), " note: ", store._note.text)
	# Hire another and skip it with a click.
	paper = store._papers.get_child(0)
	await _click(paper.get_child(0).global_position + Vector2(120, 25))
	await _wait(0.15)
	await _click(Vector2(960, 300))
	print("second hire skipped: busy ", store._busy(), " roster ", run.roster.size(), " papers ", store._papers.get_child_count(), " at ", store._papers.get_children().map(func(p): return roundi(p.position.x)))
	await _shot("hire_end")
	# Esc while a hire is playing leaves at once.
	paper = store._papers.get_child(0)
	await _click(paper.get_child(0).global_position + Vector2(120, 25))
	store.close()
	print("closed while playing: visible ", store.visible, " busy ", store._busy(), " roster ", run.roster.size())
	quit()
