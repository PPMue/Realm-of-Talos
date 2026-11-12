extends SceneTree
## Headless tests for the battle rules.
## Run:  godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures.

var _failures: Array[String] = []
var _checks := 0
var _current := ""


func _init() -> void:
	var tests: Array[Callable] = [
		test_damage_minimum,
		test_accuracy_clamps,
		test_crit_clamps_and_crit_doubles,
		test_weight_penalty,
		test_countdown_ticks_and_repicks,
		test_enemies_act_left_to_right,
		test_recovery_lengths,
		test_lone_companion_ignores_recovery,
		test_wait_only_when_nobody_can_act,
		test_guard_halves_damage_and_expires,
		test_guard_and_injured_target_weights,
		test_targeting_distribution,
		test_gone_companions_leave_line,
		test_injured_then_gone,
		test_miss_does_not_finish_injured,
		test_area_attack_finishes_injured,
		test_heal_clears_injury,
		test_victory_sets_injured_to_1hp,
		test_defeat_no_companions_left,
		test_defeat_all_injured,
		test_skill_costs_stamina_and_focus_restores,
		test_prototype_data_simulation,
	]
	for t in tests:
		_current = t.get_method()
		t.call()
	print("")
	if _failures.is_empty():
		print("ALL PASSED: %d tests, %d checks" % [tests.size(), _checks])
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL " + f)
		print("%d FAILED of %d checks" % [_failures.size(), _checks])
		quit(1)


# ---------------------------------------------------------------- helpers

## A battle in which a revive is always possible (stands in for future revive items).
class ReviveBattle extends Battle:
	func can_revive() -> bool:
		return true


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("%s: %s" % [_current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func make_weapon(might: int = 5, hit: int = 999, weight: int = 0) -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "Test Blade"
	w.might = might
	w.hit = hit
	w.weight = weight
	var s := SkillData.new()
	s.display_name = "Test Skill"
	s.stamina_cost = 10
	s.might_bonus = 3
	w.skill = s
	return w


func make_companion(n: String, hp: int = 20, def: int = 0, weapon: WeaponData = null) -> CompanionData:
	var c := CompanionData.new()
	c.display_name = n
	c.max_hp = hp
	c.max_sta = 30
	c.strength = 10
	c.crit = 0
	c.dexterity = 10
	c.speed = 0
	c.defense = def
	c.luck = 0
	c.build = 10
	c.weapon = weapon if weapon != null else make_weapon()
	return c


func make_action(n: String, cd: int, targeting: EnemyActionData.Targeting = EnemyActionData.Targeting.SINGLE,
		might: int = 5, weight: float = 1.0) -> EnemyActionData:
	var a := EnemyActionData.new()
	a.display_name = n
	a.countdown = cd
	a.targeting = targeting
	a.might = might
	a.hit = 999         # always lands (clamped to 100)
	a.pick_weight = weight
	return a


func make_enemy(n: String, actions: Array[EnemyActionData], hp: int = 100) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = n
	e.max_hp = hp
	e.strength = 10
	e.crit = 0
	e.dexterity = 10
	e.speed = 0
	e.defense = 0
	e.luck = 0
	e.actions = actions
	return e


## An enemy that never acts during a test (huge countdown).
func idle_enemy(hp: int = 100) -> EnemyData:
	var acts: Array[EnemyActionData] = [make_action("Doze", 9999)]
	return make_enemy("Dummy", acts, hp)


func make_battle(companions: Array[CompanionData], enemies: Array[EnemyData], seed_value: int = 1) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Battle.new(companions, enemies, rng)


func three_companions(hp: int = 20) -> Array[CompanionData]:
	var cs: Array[CompanionData] = [make_companion("Left", hp), make_companion("Mid", hp), make_companion("Right", hp)]
	return cs


func one_enemy(e: EnemyData) -> Array[EnemyData]:
	var es: Array[EnemyData] = [e]
	return es


func set_injured(c: CompanionUnit) -> void:
	c.hp = 0
	c.state = CompanionUnit.State.INJURED


# ---------------------------------------------------------------- formulas

func test_damage_minimum() -> void:
	eq(CombatMath.physical_damage(10, 5, 3), 12, "STR + Mt - DEF")
	eq(CombatMath.physical_damage(1, 0, 20), 1, "damage never below 1")
	eq(CombatMath.final_damage(1, false, 0.5), 1, "guarded minimum damage is still 1")


func test_accuracy_clamps() -> void:
	eq(CombatMath.hit_chance(80, 6, 4, 3), 87, "Hit + 5*(DEX-SPD) - LCK")
	eq(CombatMath.hit_chance(100, 20, 0, 0), 100, "accuracy clamps at 100")
	eq(CombatMath.hit_chance(50, 0, 20, 10), 20, "accuracy clamps at 20")


func test_crit_clamps_and_crit_doubles() -> void:
	eq(CombatMath.crit_chance(5, 3), 7, "2*CRT - LCK")
	eq(CombatMath.crit_chance(1, 10), 0, "crit clamps at 0")
	eq(CombatMath.crit_chance(80, 0), 100, "crit clamps at 100")
	eq(CombatMath.final_damage(7, true, 1.0), 14, "crit doubles damage")


func test_weight_penalty() -> void:
	var c := make_companion("Heavy", 20, 0, make_weapon(5, 80, 13))
	c.build = 10
	c.dexterity = 8
	c.speed = 7
	var armor := EquipmentData.new()
	armor.slot = EquipmentData.Slot.ARMOR
	armor.weight = 2
	c.armor = armor
	var u := CompanionUnit.new(c)
	eq(u.total_weight(), 15, "weapon + armor weight")
	eq(u.weight_penalty(), 5, "WT 15 over BLD 10")
	eq(u.stat(Stat.DEX), 3, "DEX lowered by penalty")
	eq(u.stat(Stat.SPD), 2, "SPD lowered by penalty")
	eq(u.stat(Stat.STR), 10, "other stats unaffected")
	c.armor = null
	c.weapon.weight = 6
	eq(u.weight_penalty(), 0, "no penalty at or under BLD")
	eq(u.stat(Stat.DEX), 8, "DEX restored")


# ---------------------------------------------------------------- countdowns

func test_countdown_ticks_and_repicks() -> void:
	var acts: Array[EnemyActionData] = [make_action("Poke", 3)]
	var b := make_battle(three_companions(100), one_enemy(make_enemy("E", acts)))
	var e := b.enemies[0]
	eq(e.countdown, 3, "initial countdown from action CD")
	var c := b.roster[2]
	b.guard(b.roster[0])
	eq(e.countdown, 2, "player action lowers countdown by 1")
	b.focus(b.roster[1])
	eq(e.countdown, 1, "second action")
	var hp_before := 0
	for u in b.roster:
		hp_before += u.hp
	b.focus(c)
	var hp_after := 0
	for u in b.roster:
		hp_after += u.hp
	check(hp_after < hp_before, "enemy acted at 0")
	eq(e.countdown, 3, "countdown reset to new action's CD")

	# Re-pick by weight: two actions, one with zero weight is never chosen.
	var acts2: Array[EnemyActionData] = [make_action("Never", 5, EnemyActionData.Targeting.SINGLE, 5, 0.0), make_action("Always", 1)]
	var b2 := make_battle(three_companions(500), one_enemy(make_enemy("E", acts2)))
	var e2 := b2.enemies[0]
	for i in 20:
		eq(e2.pending_action.display_name, "Always", "weighted pick respects zero weight")
		if b2.can_wait():
			b2.wait()
		else:
			b2.focus(b2.ready_companions()[0])

	# Distribution of picks roughly follows weights 3:1.
	var acts3: Array[EnemyActionData] = [make_action("A", 1, EnemyActionData.Targeting.SINGLE, 1, 3.0), make_action("B", 1, EnemyActionData.Targeting.SINGLE, 1, 1.0)]
	var b3 := make_battle(three_companions(), one_enemy(make_enemy("E", acts3)), 7)
	var count_a := 0
	for i in 4000:
		b3.pick_next_action(b3.enemies[0])
		if b3.enemies[0].pending_action.display_name == "A":
			count_a += 1
	check(absf(count_a / 4000.0 - 0.75) < 0.03, "pick distribution ~75%% for weight 3 of 4 (got %d)" % count_a)


func test_enemies_act_left_to_right() -> void:
	var a1: Array[EnemyActionData] = [make_action("First", 1)]
	var a2: Array[EnemyActionData] = [make_action("Second", 1)]
	var es: Array[EnemyData] = [make_enemy("Lefty", a1), make_enemy("Righty", a2)]
	var b := make_battle(three_companions(200), es)
	var start := b.log_lines.size()
	b.focus(b.roster[0])
	var i1 := -1
	var i2 := -1
	for i in range(start, b.log_lines.size()):
		if b.log_lines[i].begins_with("Lefty uses"):
			i1 = i
		if b.log_lines[i].begins_with("Righty uses"):
			i2 = i
	check(i1 >= 0 and i2 > i1, "left enemy acts before right enemy")


# ---------------------------------------------------------------- recovery

func test_recovery_lengths() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var l := b.roster[0]
	var m := b.roster[1]
	var r := b.roster[2]
	var e := b.enemies[0]
	check(b.attack(l, e), "attack accepted")
	check(not b.can_act(l), "attacker recovering for the next action")
	eq(l.recovery, 1, "attack recovery 1")
	check(b.guard(m), "guard accepted")
	check(b.can_act(l), "attacker ready after sitting out exactly one action")
	check(not b.can_act(m), "guard -> recovering")
	check(b.focus(r), "focus accepted")
	check(b.can_act(m), "guard recovery is 1")
	check(not b.can_act(r), "focus -> recovering")
	check(not b.attack(r, e), "recovering companion cannot attack")

	# Skill: 2 ticks.
	check(b.use_skill(l, e), "skill accepted")
	eq(l.recovery, 2, "skill recovery 2")
	b.attack(m, e)
	check(not b.can_act(l), "still recovering after one action")
	b.focus(r)
	check(b.can_act(l), "ready after sitting out two actions")


func test_lone_companion_ignores_recovery() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var e := b.enemies[0]
	set_injured(b.roster[0])
	b.roster[1].state = CompanionUnit.State.GONE
	var lone := b.roster[2]
	check(b.use_skill(lone, e), "lone companion uses skill")
	check(b.can_act(lone), "lone companion can act despite recovery")
	check(b.attack(lone, e), "and actually act")
	check(not b.can_wait(), "no Wait offered while the lone companion can act")

	# With two active companions, recovery applies again.
	var b2 := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	set_injured(b2.roster[0])
	b2.attack(b2.roster[2], b2.enemies[0])
	check(not b2.can_act(b2.roster[2]), "recovery applies when two can act")


func test_wait_only_when_nobody_can_act() -> void:
	var cs: Array[CompanionData] = [make_companion("A"), make_companion("B")]
	var b := make_battle(cs, one_enemy(idle_enemy(1000)))
	var e := b.enemies[0]
	check(not b.can_wait(), "no wait while someone is ready")
	check(not b.wait(), "wait refused")
	b.use_skill(b.roster[0], e)
	b.use_skill(b.roster[1], e)
	check(b.ready_companions().is_empty(), "both recovering")
	check(b.can_wait(), "wait offered")
	var cd := e.countdown
	check(b.wait(), "wait accepted")
	eq(e.countdown, cd - 1, "wait ticks enemies")
	check(b.can_act(b.roster[0]), "first skill user ready after wait")


# ---------------------------------------------------------------- guard and targeting

func test_guard_halves_damage_and_expires() -> void:
	# Enemy deals STR 10 + Mt 5 - DEF 0 = 15 every tick.
	var acts: Array[EnemyActionData] = [make_action("Hit All", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 5)]
	var cs: Array[CompanionData] = [make_companion("A", 100), make_companion("B", 100)]
	var b := make_battle(cs, one_enemy(make_enemy("E", acts)))
	var a := b.roster[0]
	var g := b.roster[1]
	b.guard(g)
	eq(a.hp, 85, "unguarded takes full damage")
	eq(g.hp, 93, "guarded takes 50% (15 -> 7, rounded down)")
	check(not g.has_effect("Guard"), "guard expires at end of tick")
	b.focus(a)
	eq(g.hp, 78, "full damage the next tick")


func test_guard_and_injured_target_weights() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()))
	eq(b.target_weights(), [1.0, 2.0, 4.0] as Array[float], "base weights 1, 2, 4")
	b.roster[0].add_effect(StatusEffect.guard())
	set_injured(b.roster[2])
	eq(b.target_weights(), [4.0, 2.0, 1.0] as Array[float], "guard x4, injured x0.25")
	var cs: Array[CompanionData] = []
	for i in 5:
		cs.append(make_companion("C%d" % i))
	var b5 := make_battle(cs, one_enemy(idle_enemy()))
	eq(b5.target_weights(), [1.0, 2.0, 4.0, 8.0, 16.0] as Array[float], "five slots 1, 2, 4, 8, 16")


func test_targeting_distribution() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()), 12345)
	var counts := [0, 0, 0]
	var n := 14000
	for i in n:
		counts[b.line().find(b.pick_target())] += 1
	var expected := [1.0 / 7.0, 2.0 / 7.0, 4.0 / 7.0]
	for i in 3:
		var share: float = counts[i] / float(n)
		check(absf(share - expected[i]) < 0.015, "slot %d share %.3f ~ %.3f" % [i, share, expected[i]])

	# Guarding the leftmost (x4) makes weights 4, 2, 4.
	b.roster[0].add_effect(StatusEffect.guard())
	counts = [0, 0, 0]
	for i in n:
		counts[b.line().find(b.pick_target())] += 1
	var exp2 := [0.4, 0.2, 0.4]
	for i in 3:
		var share: float = counts[i] / float(n)
		check(absf(share - exp2[i]) < 0.015, "guarded slot %d share %.3f ~ %.3f" % [i, share, exp2[i]])


func test_gone_companions_leave_line() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()))
	b.roster[1].state = CompanionUnit.State.GONE
	eq(b.line().size(), 2, "gone companion leaves the line")
	eq(b.target_weights(), [1.0, 2.0] as Array[float], "remaining companions close up")


# ---------------------------------------------------------------- injury

func test_injured_then_gone() -> void:
	# 15 damage per hit; Solo is alone in the line so the target is certain.
	var acts: Array[EnemyActionData] = [make_action("Hit", 1)]
	var cs: Array[CompanionData] = [make_companion("Solo", 20)]
	var b := make_battle(cs, one_enemy(make_enemy("E", acts)))
	var solo := b.roster[0]
	b.perform_enemy_action(b.enemies[0], acts[0])
	eq(solo.hp, 5, "first hit")
	check(solo.is_active(), "still active above 0")
	b.perform_enemy_action(b.enemies[0], acts[0])
	eq(solo.hp, -10, "HP can go negative")
	check(solo.is_injured(), "injured at 0 or below")
	check(not b.can_act(solo), "injured companion cannot act")
	eq(b.line().size(), 1, "injured companion stays in line")
	eq(b.pick_target(), solo, "injured companion can still be targeted")
	b.perform_enemy_action(b.enemies[0], acts[0])
	check(solo.is_gone(), "hit on injured companion -> gone")
	eq(b.line().size(), 0, "gone companion left the line")

func test_miss_does_not_finish_injured() -> void:
	var miss := make_action("Whiff", 1)
	miss.hit = -999   # clamps to 20%, so some rolls miss
	var cs: Array[CompanionData] = [make_companion("Solo", 20)]
	var b := make_battle(cs, one_enemy(make_enemy("E", [miss] as Array[EnemyActionData])), 3)
	var solo := b.roster[0]
	set_injured(solo)
	var landed := false
	for i in 50:
		var hp_before := solo.hp
		b.perform_enemy_action(b.enemies[0], miss)
		if solo.hp == hp_before:
			check(solo.is_injured(), "a miss leaves the injured companion injured")
		else:
			landed = true
			check(solo.is_gone(), "a landed hit finishes them")
			break
	check(landed, "eventually a hit lands")


func test_area_attack_finishes_injured() -> void:
	var acts: Array[EnemyActionData] = [make_action("Boom", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 1)]
	var b := make_battle(three_companions(50), one_enemy(make_enemy("E", acts)))
	set_injured(b.roster[0])
	b.perform_enemy_action(b.enemies[0], acts[0])
	check(b.roster[0].is_gone(), "area attack finishes the injured companion")
	check(b.roster[1].is_active() and b.roster[2].is_active(), "others merely damaged")
	eq(b.roster[1].hp, 39, "area damage 10 + 1 - 0")


func test_heal_clears_injury() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()))
	var c := b.roster[0]
	c.hp = -5
	c.state = CompanionUnit.State.INJURED
	b.heal(c, 3)
	check(c.is_injured(), "healing to 0 or below keeps the injury")
	b.heal(c, 3)
	eq(c.hp, 1, "healed above 0")
	check(c.is_active(), "injury cleared above 0 HP")
	b.heal(c, 999)
	eq(c.hp, c.max_hp(), "healing caps at max HP")


# ---------------------------------------------------------------- battle end

func test_victory_sets_injured_to_1hp() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1)))
	set_injured(b.roster[0])
	b.roster[0].hp = -7
	check(b.attack(b.roster[2], b.enemies[0]), "finishing blow")
	eq(b.outcome, Battle.Outcome.VICTORY, "victory when all enemies dead")
	eq(b.roster[0].hp, 1, "injured companion set to 1 HP")
	check(b.roster[0].is_active(), "no longer injured")
	eq(b.roster[1].hp, 20, "healthy companion HP unchanged")
	check(not b.focus(b.roster[1]), "no commands after the battle ends")


func test_defeat_no_companions_left() -> void:
	# With today's rules all-injured always ends the battle first, so "no companions left" can only
	# be reached once revives exist. Simulate that with a battle whose can_revive() is true.
	var acts: Array[EnemyActionData] = [make_action("Boom", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 100)]
	var b := ReviveBattle.new(three_companions(), one_enemy(make_enemy("E", acts)), RandomNumberGenerator.new())
	set_injured(b.roster[0])
	set_injured(b.roster[1])
	# Right acts alone; Boom finishes Left and Mid and injures Right. Revive possible -> battle goes on.
	check(b.focus(b.roster[2]), "lone companion acts")
	check(b.roster[0].is_gone() and b.roster[1].is_gone(), "injured finished by the area attack")
	check(b.roster[2].is_injured(), "right injured")
	eq(b.outcome, Battle.Outcome.ONGOING, "all-injured is not a defeat while a revive is possible")
	check(b.can_wait(), "nobody can act -> wait")
	b.wait()
	check(b.line().is_empty(), "line empty")
	eq(b.outcome, Battle.Outcome.DEFEAT, "defeat when no companions are left")
	check(b.log_lines[-1].contains("no companions left"), "reason: no companions left")

func test_defeat_all_injured() -> void:
	# A is injured; B (alone able to act) focuses; a 40-damage hit lands on someone.
	# If it hits B, everyone left is injured -> defeat. Find a seed where that happens.
	var acts: Array[EnemyActionData] = [make_action("Hit", 1, EnemyActionData.Targeting.SINGLE, 30)]
	var cs: Array[CompanionData] = [make_companion("A", 20), make_companion("B", 20)]
	var found := false
	for s in 50:
		var b := make_battle(cs, one_enemy(make_enemy("E", acts)), s)
		set_injured(b.roster[0])
		b.focus(b.roster[1])
		if b.roster[1].is_injured():
			found = true
			check(b.roster[0].is_injured(), "A still injured")
			eq(b.outcome, Battle.Outcome.DEFEAT, "all remaining companions injured -> defeat")
			check(b.log_lines[-1].contains("injured"), "reason: all injured")
			break
	check(found, "found a seed where B is hit")

# ---------------------------------------------------------------- stamina

func test_skill_costs_stamina_and_focus_restores() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	var normal := b.forecast(c, e, false)
	var skill := b.forecast(c, e, true)
	eq(skill.damage, normal.damage + 3, "skill forecast includes Mt bonus")
	b.use_skill(c, e)
	eq(c.stamina, 20, "skill costs 10 STA")
	eq(e.hp, 1000 - 18, "skill damage 10 + 5 + 3")
	c.stamina = 5
	b.attack(b.roster[1], e)
	b.attack(b.roster[2], e)
	check(not b.can_use_skill(c), "not enough stamina")
	check(not b.use_skill(c, e), "skill refused without stamina")
	eq(b.focus_amount(c), 3, "focus restores 10% of 30")
	b.focus(c)
	eq(c.stamina, 8, "stamina after focus")
	c.stamina = 29
	b.roster[1].recovery = 0
	b.roster[2].recovery = 0
	c.recovery = 0
	b.focus(c)
	eq(c.stamina, 30, "focus caps at max")


# ---------------------------------------------------------------- whole battle from the real data

func test_prototype_data_simulation() -> void:
	var setup: BattleSetup = load("res://data/battles/prototype_battle.tres")
	check(setup != null and setup.companions.size() == 3 and setup.enemies.size() == 2, "prototype setup loads 3 v 2")
	var wins := 0
	var runs := 200
	for s in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var b := Battle.new(setup.companions, setup.enemies, rng)
		var policy := RandomNumberGenerator.new()
		policy.seed = s + 1000
		var guard_ticks := 0
		while not b.is_over() and guard_ticks < 500:
			guard_ticks += 1
			if b.can_wait():
				check(b.wait(), "wait accepted")
				continue
			var ready := b.ready_companions()
			var c := ready[policy.randi_range(0, ready.size() - 1)]
			var foes := b.living_enemies()
			var target := foes[policy.randi_range(0, foes.size() - 1)]
			var roll := policy.randi_range(0, 9)
			var ok := false
			if roll < 6:
				ok = b.attack(c, target)
			elif roll < 8 and b.can_use_skill(c):
				ok = b.use_skill(c, target)
			elif roll < 9:
				ok = b.guard(c)
			else:
				ok = b.focus(c)
			if not ok:
				ok = b.attack(c, target)
			check(ok, "a legal command was accepted")
		check(b.is_over(), "seed %d battle ends" % s)
		if b.outcome == Battle.Outcome.VICTORY:
			wins += 1
			for c in b.line():
				check(not c.is_injured() and c.hp > 0, "no injured companions after victory")
	print("  random-policy simulation: %d/%d victories" % [wins, runs])
