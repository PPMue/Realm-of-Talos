extends SceneTree
## Screen check: the whole line fights. Guard asking whom to shield (the guard or a neighbour), with
## what the guard would take and the threads swinging to them; the blow caught; the retreat asked
## for, sounded, and its result.
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
	root.get_texture().get_image().save_png(out_dir.path_join("line_%s.png" % name))
	print("saved ", name)
func _move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.2)
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
	# A line of four, grown enough to stand a few turns.
	run.gold = 2000
	run.day = 8
	run._begin_day()
	run.event = null
	while run.lineup.size() < 4 and not run.tavern_offers.is_empty() and run.hire(run.tavern_offers[0]) != null:
		pass
	for c in run.roster:
		for i in 9:
			Levels.level_up(c.progress, run.rng)
		c.hp = c.max_hp()
	run.day = day
	run._begin_day()
	run.event = null
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	var front: Front = run.fronts[run.fronts.size() - 1]
	city.defend(front)
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var b: Battle = bs.battle
	print("line ", b.roster.size(), " may retreat ", b.can_retreat(), " walls ", front.city_damage)
	for c in b.roster:
		print(c.display_name, " attack recovery ", b.action_recovery(c, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK))
	await _shot("1_start")
	# Play on until a single blow lands this turn on someone whose neighbour is free to step in.
	var shown := false
	for turn in 14:
		if b.is_over():
			break
		var ready := b.ready_companions()
		var guard: CompanionUnit = null
		var ward: CompanionUnit = null
		var names: Array[String] = []
		for c in ready:
			names.append(c.display_name)
		for e in b.living_enemies():
			print("  turn ", b.tick + 1, " ", e.display_name, " ", e.pending_action.display_name, " targeting ", e.pending_action.targeting, " in ", e.countdown, " at ",
				e.pending_target.display_name if e.pending_target != null else "-", "; ready ", names)
		for e in b.living_enemies():
			if e.countdown == 1 and e.pending_target != null and e.pending_action.deals_damage:
				for g in ready:
					if g != e.pending_target and b.guard_wards(g).has(e.pending_target):
						guard = g
						ward = e.pending_target
		if guard != null and not shown:
			shown = true
			print("turn ", b.tick + 1, ": ", guard.display_name, " can shield ", ward.display_name, " -> ", b.guard_preview(guard, ward))
			bs.pick_companion(guard)
			await _wait(0.2)
			await _move(Vector2(300, 300))
			bs.choose_action(ActionMenu.GUARD)
			await _wait(0.3)
			await _shot("2_guard_whom")
			var ward_panel: PartyPanel = bs._party_panels[ward]
			await _move(ward_panel.get_global_rect().get_center())
			await _shot("3_guard_neighbour")
			bs.guard_ward(ward)
			await _wait(0.5)
			await _shot("4_guard_playing")
			await _wait(0.9)
			await _shot("5_blow_caught")
			await _settle(bs)
			await _shot("6_after")
			continue
		if ready.is_empty():
			b.wait()
			bs._commit(null)
		else:
			# Whoever stands beside someone a blow is aimed at is kept free to step in.
			var actor := ready[0]
			for c in ready:
				var beside := false
				for e in b.living_enemies():
					if e.pending_target != null and e.pending_target != c and b.guard_wards(c).has(e.pending_target):
						beside = true
				if not beside:
					actor = c
					break
			# Strike the sturdiest, so the fight lasts.
			var target := b.living_enemies()[0]
			for e in b.living_enemies():
				if e.hp > target.hp:
					target = e
			b.attack(actor, target)
			bs._commit(actor)
		await _settle(bs)
		if shown and turn >= 6:
			break
	print("shielding shown: ", shown, "; turn ", b.tick, "; ready ", b.ready_companions().size(), "; outcome ", b.outcome)
	await _move(Vector2(300, 300))
	await _shot("7_line_later")
	# The retreat: asked, then sounded.
	if not b.is_over():
		await _key(KEY_R)
		await _wait(0.3)
		await _shot("8_retreat_asked")
		await _key(KEY_ENTER)
		await _wait(0.6)
		await _shot("9_retreat_sounded")
		await _wait(3.0)
		await _shot("10_retreat_result")
		print("retreated ", b.retreated, "; walls now ", run.city_health)
	quit()
