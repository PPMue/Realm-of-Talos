extends SceneTree
## Screen check: more to say each turn. A staggering art in the orders and on its target ("STAGGERS +1"),
## the enemy's action pushed back, the note on one already pushed back; stamina coming back turn by
## turn for those who did not act; Focus and what it gives.
## Pass the day to fight on after the folder (default 16).
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
	root.get_texture().get_image().save_png(out_dir.path_join("breath_%s.png" % name))
	print("saved ", name)
func _move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	root.push_input(mm, true)
	await _wait(0.2)
func _settle(bs: BattleScreen) -> void:
	await _wait(0.3)
	while bs.is_busy():
		await _wait(0.3)
	await _wait(0.3)
func _stamina(b: Battle) -> String:
	var parts: Array[String] = []
	for c in b.roster:
		parts.append("%s %d/%d" % [c.display_name, c.stamina, c.max_stamina()])
	return ", ".join(parts)
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
	run.gold = 2000
	run.day = 8
	run._begin_day()
	run.event = null
	while run.lineup.size() < 4 and not run.tavern_offers.is_empty() and run.hire(run.tavern_offers[0]) != null:
		pass
	# Everyone carries the staggering art of the weapon they hold, in the first place.
	var lib := ArtLibrary.load_default()
	for c in run.roster:
		for i in 9:
			Levels.level_up(c.progress, run.rng)
		c.hp = c.max_hp()
		if c.progress.weapon == null:
			continue
		for art in lib.arts:
			if art.stagger_ticks > 0 and art.weapon_type == c.progress.weapon.weapon_type:
				for old in c.progress.equipped_arts.duplicate():
					c.progress.unequip(old)
				c.progress.learn(art)
				c.progress.equip(art)
				print(c.display_name, " carries ", art.display_name)
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
	print("stamina at the start: ", _stamina(b))
	# Whoever of the ready carries a staggering art orders it and points at an enemy.
	var user: CompanionUnit = null
	var art: CombatArtData = null
	for c in b.ready_companions():
		for a in c.arts():
			if a.stagger_ticks > 0 and b.can_use_art(c, a) and not a.hits_all_enemies:
				user = c
				art = a
	if user == null:
		print("nobody carries a staggering art")
		quit()
		return
	var target: EnemyUnit = b.living_enemies()[0]
	for e in b.living_enemies():
		if e.hp > target.hp:
			target = e
	bs.pick_companion(user)
	await _wait(0.2)
	bs.choose_action(ActionMenu.art_id(user.arts().find(art)))
	await _wait(0.3)
	var view: EnemyView = bs._enemy_views[target]
	await _move(view.get_global_rect().get_center())
	bs.point_at_enemy(target)
	await _wait(0.2)
	await _shot("1_stagger_aimed")
	var before := target.countdown
	bs.strike_enemy(target)
	await _wait(0.6)
	await _shot("2_stagger_playing")
	await _settle(bs)
	print(art.display_name, " on ", target.display_name, ": countdown ", before, " -> ", target.countdown, ", delayed ", target.delayed)
	print("stamina after one turn: ", _stamina(b))
	await _move(Vector2(300, 300))
	await _shot("3_staggered")
	# The next one aims the same art at the same enemy: already pushed back.
	if target.is_alive() and target.delayed:
		for c in b.ready_companions():
			for a in c.arts():
				if a.stagger_ticks > 0 and b.can_use_art(c, a) and not a.hits_all_enemies:
					bs.pick_companion(c)
					await _wait(0.2)
					bs.choose_action(ActionMenu.art_id(c.arts().find(a)))
					await _wait(0.3)
					await _move(view.get_global_rect().get_center())
					bs.point_at_enemy(target)
					await _wait(0.2)
					await _shot("4_already_delayed")
					bs.cancel_targeting()
					await _wait(0.2)
					break
			if FileAccess.file_exists(out_dir.path_join("breath_4_already_delayed.png")):
				break
	# Two plain turns, then Focus: breath back for those who did not act, and what Focus gives.
	for turn in 5:
		if b.is_over() or (turn >= 2 and b.can_act(user)):
			break
		var ready := b.ready_companions()
		if ready.is_empty():
			b.wait()
			bs._commit(null)
		else:
			b.attack(ready[0], b.living_enemies()[0])
			bs._commit(ready[0])
		await _settle(bs)
		print("stamina after turn ", b.tick, ": ", _stamina(b))
	if not b.is_over() and user.is_active() and b.can_act(user):
		bs.pick_companion(user)
		await _wait(0.3)
		print(user.display_name, " focus gives ", b.focus_amount(user))
		await _shot("5_orders_with_focus")
		bs.choose_action(ActionMenu.FOCUS)
		await _wait(0.5)
		await _shot("6_focus_playing")
		await _settle(bs)
		print("stamina after the focus: ", _stamina(b))
		await _shot("7_after_focus")
	else:
		await _shot("5_later")
	quit()
