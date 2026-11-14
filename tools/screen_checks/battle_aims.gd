extends SceneTree
## Screen check: the enemy's hand in a battle. Under each enemy its coming action, who it is aimed at,
## the damage and the chance to hit; on each portrait what is aimed at them; the threads; the sheets.
## Pass the day to fight on after the folder (default 16, a battle day of the middle band).
var out_dir := ""
var day := 16
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	if args.size() > 1:
		day = int(args[1])
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("aims_%s.png" % name))
	print("saved ", name)
func _move(at: Vector2, shift: bool = false) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.shift_pressed = shift
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
	city._letter.close()
	# A line of four, grown enough to stand a few turns.
	run.gold = 2000
	run.day = 8
	run._begin_day()
	run.event = null
	while run.lineup.size() < 4 and not run.tavern_offers.is_empty() and run.hire(run.tavern_offers[0]) != null:
		pass
	for c in run.roster:
		for i in 5:
			Levels.level_up(c.progress, run.rng)
		c.hp = c.max_hp()
	run.day = day
	run._begin_day()
	run.event = null
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	print("day ", run.day, " fronts ", run.fronts.size(), " line ", run.lineup.size())
	var front: Front = run.fronts[run.fronts.size() - 1]
	city.defend(front)
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var b: Battle = bs.battle
	for e in b.enemies:
		print(e.display_name, ": ", e.pending_action.display_name, " in ", e.countdown, " at ",
			e.pending_target.display_name if e.pending_target != null else "-")
	for c in b.roster:
		var lines: Array[String] = []
		for m in b.incoming(c):
			lines.append("%s %s in %d for %d" % [m.enemy.display_name, m.action.display_name, m.turns, m.forecast.damage])
		print(c.display_name, " hp ", c.hp, " falls on ", b.falls_on_turn(c), " <- ", lines)
	await _shot("1_start")
	# Point at each enemy in turn: its thread and its target's frame.
	var views: Array = bs._enemy_views.values()
	var first: EnemyView = views[0]
	await _move(first.get_global_rect().get_center())
	await _shot("2_point_at_enemy")
	# Point at whoever stands at the front: every thread that ends on them.
	var panels: Array = bs._party_panels.values()
	var front_panel: PartyPanel = panels[panels.size() - 1]
	await _move(front_panel.get_global_rect().get_center())
	await _shot("3_point_at_companion")
	# The sheets.
	await _move(first.get_global_rect().get_center(), true)
	await _shot("4_enemy_sheet")
	await _move(front_panel.get_global_rect().get_center(), true)
	await _shot("5_companion_sheet")
	await _move(Vector2(300, 300))
	# A few turns: guard with whoever is ready, and look again.
	for turn in 3:
		if b.is_over():
			break
		var ready := b.ready_companions()
		if ready.is_empty():
			b.wait()
			bs._commit(null)
		else:
			b.guard(ready[0])
			bs._commit(ready[0])
		await _wait(0.3)
		await _shot("6_turn_%d_playing" % (turn + 1))
		while bs.is_busy():
			await _wait(0.3)
		await _wait(0.3)
		await _shot("7_turn_%d_after" % (turn + 1))
	quit()
