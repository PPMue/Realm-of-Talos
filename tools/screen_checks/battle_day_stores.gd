extends SceneTree
## Screen check: the smithy and the tavern on a battle day.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("bd_%s.png" % name))
	print("saved ", name)
func _wait(s: float) -> void:
	await create_timer(s).timeout
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
	for kind in [RunCalendar.DayType.BATTLE, RunCalendar.DayType.BOSS]:
		run.calendar[run.day - 1] = kind
		run._begin_day()
		run.event = null
		run.gold = 500
		run.materials[RunConfig.IRON_ORE] = 10
		city.refresh(false)
		await _wait(0.4)
		var tag := "battle" if kind == RunCalendar.DayType.BATTLE else "boss"
		print(tag, ": day type ", run.day_type(), " fronts ", run.fronts.size(), "  shop '", run.visit_block_reason(Run.FreeAction.SHOP), "'  tavern '",
			run.visit_block_reason(Run.FreeAction.TAVERN), "'  cure '", run.visit_block_reason(Run.FreeAction.CURE), "'  upgrade '",
			run.upgrade_block_reason(Run.Facility.SMITHY), "'")
		await _shot("city_" + tag)
		# The buildings themselves: a real click on the smithy and on the tavern.
		for k in [CityBuilding.Kind.SMITHY, CityBuilding.Kind.TAVERN, CityBuilding.Kind.INN]:
			var bd = city._city.building(k)
			print("  building ", k, " open ", bd.open, " status '", bd.status, "'")
		city.visit(CityBuilding.Kind.SMITHY)
		var store = city._store_screen
		await _wait(0.5)
		print("  smithy screen open ", store.visible, "  hint: ", store._hint.text)
		if store.visible:
			await _shot("smithy_" + tag)
			var stock := run.shop_stock()
			var gold := run.gold
			var n := run.inventory.weapons.size()
			if not stock.is_empty():
				store.buy(stock[0])
				print("  bought: weapons ", n, " -> ", run.inventory.weapons.size(), "  gold ", gold, " -> ", run.gold)
				store.put_away()
			store.close()
		city.visit(CityBuilding.Kind.TAVERN)
		await _wait(0.5)
		print("  tavern screen open ", store.visible, "  hint: ", store._hint.text, "  offers ", run.tavern_offers.size())
		if store.visible:
			await _shot("tavern_" + tag)
			if not run.tavern_offers.is_empty():
				var size := run.roster.size()
				store.hire(run.tavern_offers[0])
				print("  hired: roster ", size, " -> ", run.roster.size(), "  line ", run.lineup.size(), "  note: ", store._note.text)
			store.close()
		if city._letter.is_open():
			city._letter.close()
	# March out: the war table shows the hire in the line, and the shops shut once the battle begins.
	city.open_war_table()
	await _wait(0.6)
	await _shot("war_table")
	city._war_table.visible = false
	var b := run.start_battle(run.fronts[0])
	print("after marching out: shop '", run.visit_block_reason(Run.FreeAction.SHOP), "'  tavern '", run.visit_block_reason(Run.FreeAction.TAVERN), "'")
	quit()
