extends SceneTree
## Screen check: callings in a battle. The calling over the name, a Captain's Rouse among the orders
## and waiting for whom, an Executioner's forecast (FELLS), a Berserker's arts priced in Health, and a
## Mender's heal aimed at someone injured (RAISED).
var out_dir := ""
func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	_run()
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join("cbattle_%s.png" % name))
	print("saved ", name)
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
	var lib := CallingLibrary.load_default()
	var ids := ["captain", "executioner", "berserker", "mender"]
	var mend := load("res://data/spells/white/mend.tres") as SpellData
	for i in run.lineup.size():
		var c := run.lineup[i]
		for k in 5:
			Levels.level_up(c.progress, run.rng)
		c.progress.calling_offers.assign([lib.find(ids[i])])
		var school := lib.find(ids[i]).school
		run.take_calling(c, lib.find(ids[i]), school, mend if school >= 0 else null)
		c.hp = c.max_hp()
	print("callings: ", run.lineup.map(func(c: RunCompanion) -> String: return "%s %s" % [c.display_name(), c.progress.calling.display_name if c.progress.calling != null else "-"]))
	run.day = 9
	run._begin_day()
	run.event = null
	while not run.is_fight_day():
		run.day += 1
		run._begin_day()
		run.event = null
	city.refresh(false)
	await _wait(0.4)
	if city._letter.is_open():
		city._letter.close()
	city.defend(run.fronts[run.fronts.size() - 1])
	await _wait(3.5)
	var bs: BattleScreen = city._battle_screen
	var b: Battle = bs.battle
	var r := b.roster
	# The Captain: someone is recovering, Rouse waits for whom.
	r[1].recovery = 2
	r[2].recovery = 1
	bs.pick_companion(r[0])
	bs._refresh()
	await _wait(0.3)
	await _shot("1_captain_orders")
	bs.choose_action(ActionMenu.ROUSE)
	await _wait(0.3)
	await _shot("2_rouse_whom")
	bs.cancel_targeting()
	# The Executioner: a blow that leaves the enemy at a fifth or less.
	r[1].recovery = 0
	r[2].recovery = 0
	bs.pick_companion(r[1])
	var e := b.living_enemies()[0]
	var f := b.forecast(r[1], e)
	e.hp = f.damage + maxi(1, f.execute_at - 1)
	bs._refresh()
	bs.choose_action(ActionMenu.ATTACK)
	bs.point_at_enemy(e)
	await _wait(0.3)
	await _shot("3_executioner_fells")
	print("execute_at ", f.execute_at, " hp ", e.hp, " dmg ", f.damage)
	bs.cancel_targeting()
	# The Berserker: arts priced in Health.
	bs.pick_companion(r[2])
	bs._refresh()
	await _wait(0.3)
	await _shot("4_berserker_arts")
	# The Mender: a heal on someone injured raises them.
	b._injure(r[0])
	bs._refresh()
	bs.pick_companion(r[3])
	bs.choose_action(ActionMenu.MAGIC)
	await _wait(0.2)
	bs.choose_action(ActionMenu.spell_id(r[3].spells().find(mend)))
	bs.point_at_ally(r[0])
	await _wait(0.3)
	await _shot("5_mender_raises")
	bs.cast_on_ally(r[0])
	await _wait(2.5)
	await _shot("6_raised")
	print("raised: ", r[0].is_active(), " hp ", r[0].hp)
	quit()
