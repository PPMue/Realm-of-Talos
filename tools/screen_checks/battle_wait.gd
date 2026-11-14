extends SceneTree
## Screen check: a line of two, as a run begins. Both act in turn, then both are recovering: the orders
## show whoever is ready soonest and the one order left, Wait. Then the wait itself and the turn after.
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("wait_%s.png" % name))
	print("saved ", name)
func _key(code: Key) -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = down
		root.push_input(k, true)
		await _wait(0.1)
func _settle(bs: BattleScreen) -> void:
	await _wait(0.3)
	while bs.is_busy():
		await _wait(0.3)
	await _wait(0.3)
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
	for c in run.roster:
		for i in 6:
			Levels.level_up(c.progress, run.rng)
		c.hp = c.max_hp()
	# The first day with something at the walls.
	for d in range(1, 8):
		run.day = d
		run._begin_day()
		run.event = null
		if not run.fronts.is_empty():
			break
	print("day ", run.day, ", fronts ", run.fronts.size())
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	var front: Front = run.fronts[run.fronts.size() - 1]
	city.defend(front)
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var b: Battle = bs.battle
	print("line ", b.roster.size())
	for c in b.roster:
		print(c.display_name, " attack recovery ", b.action_recovery(c, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK))
	await _shot("1_start")
	for i in 2:
		if b.is_over() or b.ready_companions().is_empty():
			break
		var actor := b.ready_companions()[0]
		var target := b.living_enemies()[0]
		for e in b.living_enemies():
			if e.hp > target.hp:
				target = e
		b.attack(actor, target)
		bs._commit(actor)
		await _settle(bs)
		await _shot("%d_after_action" % (i + 2))
	print("may wait ", b.can_wait(), "; recovery ", b.roster.map(func(c): return c.recovery))
	await _shot("4_nobody_ready")
	await _key(KEY_SPACE)
	await _wait(0.4)
	await _shot("5_waiting")
	await _settle(bs)
	print("after the wait: ready ", b.ready_companions().size(), "; turn ", b.tick)
	await _shot("6_after_wait")
	quit()
