extends SceneTree
## Headless tests for the battle rules, plus the run rules in run_rule_tests.gd.
## Run:  godot --headless --path . -s res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = failures.

const RunRuleTests := preload("res://tests/run_rule_tests.gd")
const MagicTests := preload("res://tests/magic_tests.gd")
const BestiaryTests := preload("res://tests/bestiary_tests.gd")
const WeaponTests := preload("res://tests/weapon_tests.gd")
const TrainingTests := preload("res://tests/training_tests.gd")
const InfirmaryTests := preload("res://tests/infirmary_tests.gd")
const RareWeaponTests := preload("res://tests/rare_weapon_tests.gd")
const ScavengeTests := preload("res://tests/scavenge_tests.gd")
const TraitTests := preload("res://tests/trait_tests.gd")
const CityTests := preload("res://tests/city_tests.gd")

var _failures: Array[String] = []
var _run_rules: RefCounted   # kept alive: Callables do not hold a reference to their object
var _magic: RefCounted
var _bestiary: RefCounted
var _weapons: RefCounted
var _training: RefCounted
var _infirmary: RefCounted
var _rare: RefCounted
var _scavenge: RefCounted
var _traits: RefCounted
var _city: RefCounted
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
		test_injured_stay_in_line,
		test_injured_out_of_battle,
		test_injured_never_aimed_at,
		test_area_attack_skips_injured,
		test_heal_never_lifts_injury,
		test_victory_keeps_injured,
		test_injury_ends_effects,
		test_defeat_all_injured,
		test_art_costs_stamina_and_focus_restores,
		test_events_record_the_tick,
		test_grade_thresholds,
		test_proficiency_gain_per_action,
		test_proficiency_cap_per_battle,
		test_art_tier_odds_by_grade,
		test_learning_never_duplicates,
		test_tier_fall_through,
		test_learning_nothing_when_pool_exhausted,
		test_grade_up_in_battle_learns_and_equips,
		test_learning_after_battle_slots_and_removed,
		test_auto_equip_and_limit_of_three,
		test_art_needs_matching_weapon_type,
		test_art_costs_one_tick,
		test_art_bonuses,
		test_art_strikes_every_enemy,
		test_art_strikes_twice,
		test_art_ignores_defense,
		test_art_debuffs_target,
		test_art_buffs_user,
		test_art_reflecting_stance,
		test_art_bleed_kills_enemy,
		test_points_for_attacks,
		test_points_for_arts_and_spells,
		test_points_for_blows_taken,
		test_points_for_kills,
		test_kill_by_bleed_or_stance_is_credited,
		test_art_stances_change_aim,
		test_art_debuff_stacks,
		test_art_oath_raises_damage_taken,
		test_equip_requirement,
		test_progress_survives_into_second_battle,
		test_art_content,
		test_art_counts_and_basics,
		test_prototype_data_simulation,
		test_prototype_progression,
	]
	_run_rules = RunRuleTests.new(self)
	tests.append_array(_run_rules.tests())
	_magic = MagicTests.new(self)
	tests.append_array(_magic.tests())
	_bestiary = BestiaryTests.new(self)
	tests.append_array(_bestiary.tests())
	_weapons = WeaponTests.new(self)
	tests.append_array(_weapons.tests())
	_training = TrainingTests.new(self)
	tests.append_array(_training.tests())
	_infirmary = InfirmaryTests.new(self)
	tests.append_array(_infirmary.tests())
	_rare = RareWeaponTests.new(self)
	tests.append_array(_rare.tests())
	_scavenge = ScavengeTests.new(self)
	tests.append_array(_scavenge.tests())
	_traits = TraitTests.new(self)
	tests.append_array(_traits.tests())
	_city = CityTests.new(self)
	tests.append_array(_city.tests())
	var verbose := OS.get_environment("TEST_VERBOSE") != ""
	var only := OS.get_environment("TEST_ONLY")
	if only != "":
		var wanted := only.split(",")
		tests.assign(tests.filter(func(c: Callable) -> bool:
			return Array(wanted).any(func(w: String) -> bool: return c.get_method().contains(w))))
	var skip := OS.get_environment("TEST_SKIP")
	if skip != "":
		tests.assign(tests.filter(func(c: Callable) -> bool: return not c.get_method().contains(skip)))
	for t in tests:
		_current = t.get_method()
		if verbose:
			print("- " + _current)
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

func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("%s: %s" % [_current, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func make_weapon(might: int = 5, hit: int = 999, weight: int = 0,
		kind: WeaponData.WeaponType = WeaponData.WeaponType.SWORD) -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "Test Blade"
	w.weapon_type = kind
	w.might = might
	w.hit = hit
	w.weight = weight
	return w


## The signature art every test companion starts with: a sword art, 10 STA, Mt +3, recovery 2.
var _test_signature := make_art("Test Art", 1, 10, 2, 3)


func make_art(n: String, tier: int = 1, cost: int = 5, recovery: int = 1, might: int = 0,
		kind: WeaponData.WeaponType = WeaponData.WeaponType.SWORD) -> CombatArtData:
	var a := CombatArtData.new()
	a.display_name = n
	a.weapon_type = kind
	a.tier = tier
	a.stamina_cost = cost
	a.recovery = recovery
	a.might_bonus = might
	return a


func make_effect(n: String, mods: Dictionary, ticks: int = 3, taken_mult: float = 1.0) -> StatusEffectData:
	var fx := StatusEffectData.new()
	fx.display_name = n
	fx.stat_mods = mods
	fx.duration_ticks = ticks
	fx.damage_taken_mult = taken_mult
	return fx


## Equips `art` on companion `c` (replacing what is there) so it can be used.
func give_art(c: CompanionUnit, art: CombatArtData) -> void:
	c.progress.equipped_arts.clear()
	c.progress.learn(art)


## A pool of arts of one weapon type: `per_tier[i]` arts of tier i + 1.
func make_pool(per_tier: Array[int], kind: WeaponData.WeaponType = WeaponData.WeaponType.SWORD) -> Array[CombatArtData]:
	var pool: Array[CombatArtData] = []
	for i in per_tier.size():
		for n in per_tier[i]:
			pool.append(make_art("T%d-%d" % [i + 1, n], i + 1, 5, 1, 0, kind))
	return pool


func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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
	c.signature_art = _test_signature
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


func make_battle(companions: Array[CompanionData], enemies: Array[EnemyData], seed_value: int = 1,
		party: Array[CompanionProgress] = [], pool: Array[CombatArtData] = []) -> Battle:
	return Battle.new(companions, enemies, make_rng(seed_value), party, pool)


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

## The UI plays a tick back from Battle.events, so their order and reset matter.
func test_events_record_the_tick() -> void:
	var acts: Array[EnemyActionData] = [make_action("Poke", 1)]
	var b := make_battle(three_companions(100), one_enemy(make_enemy("E", acts)))
	b.guard(b.roster[0])
	var types: Array[String] = []
	for ev in b.events:
		types.append(str(ev.type))
	for wanted: String in ["guard", "countdown", "enemy_action", "intent"]:
		check(types.has(wanted), "tick events include %s" % wanted)
	check(types.find("guard") < types.find("countdown"), "player action comes before the countdown drop")
	check(types.find("countdown") < types.find("enemy_action"), "countdown drop comes before the enemy acts")
	check(types.find("enemy_action") < types.rfind("intent"), "the next intent is revealed after the enemy acts")
	b.focus(b.roster[1])
	types.clear()
	for ev in b.events:
		types.append(str(ev.type))
	check(types.has("focus") and not types.has("guard"), "events are cleared at the start of each tick")


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

	# Art: recovery comes from the art's data (2 for the test art).
	check(b.use_art(l, l.arts()[0], e), "art accepted")
	eq(l.recovery, 2, "art recovery 2")
	b.attack(m, e)
	check(not b.can_act(l), "still recovering after one action")
	b.focus(r)
	check(b.can_act(l), "ready after sitting out two actions")


func test_lone_companion_ignores_recovery() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var e := b.enemies[0]
	set_injured(b.roster[0])
	set_injured(b.roster[1])
	var lone := b.roster[2]
	check(b.use_art(lone, lone.arts()[0], e), "lone companion uses an art")
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
	b.use_art(b.roster[0], b.roster[0].arts()[0], e)
	b.use_art(b.roster[1], b.roster[1].arts()[0], e)
	check(b.ready_companions().is_empty(), "both recovering")
	check(b.can_wait(), "wait offered")
	var cd := e.countdown
	check(b.wait(), "wait accepted")
	eq(e.countdown, cd - 1, "wait ticks enemies")
	check(b.can_act(b.roster[0]), "first art user ready after wait")


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
	eq(b.target_weights(), [4.0, 2.0, 0.0] as Array[float], "guard x4, injured 0: never aimed at")
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


func test_injured_stay_in_line() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()))
	set_injured(b.roster[1])
	eq(b.line().size(), 3, "an injured companion stays in the line")
	eq(b.standing(), [b.roster[0], b.roster[2]] as Array[CompanionUnit], "standing() leaves them out")
	eq(b.target_weights(), [1.0, 0.0, 4.0] as Array[float], "their place keeps its count, with weight 0")


# ---------------------------------------------------------------- injury

func test_injured_out_of_battle() -> void:
	# 15 damage per hit; Solo is alone in the line so the target is certain.
	var acts: Array[EnemyActionData] = [make_action("Hit", 1)]
	var cs: Array[CompanionData] = [make_companion("Solo", 20), make_companion("Other", 200)]
	var b := make_battle(cs, one_enemy(make_enemy("E", acts)))
	var solo := b.roster[0]
	b._enemy_strike(b.enemies[0], acts[0], solo)
	eq(solo.hp, 5, "first hit")
	check(solo.is_active(), "still active above 0")
	b._enemy_strike(b.enemies[0], acts[0], solo)
	eq(solo.hp, 0, "down to 0")
	check(solo.is_injured(), "injured at 0")
	check(not b.can_act(solo), "injured companion cannot act")
	eq(b.line().size(), 2, "injured companion stays in line")
	b._enemy_strike(b.enemies[0], acts[0], solo)
	eq(solo.hp, 0, "never struck again")
	check(solo.is_injured(), "still injured, nothing worse")
	for i in 200:
		eq(b.pick_target(), b.roster[1], "only the one standing is aimed at")
	set_injured(b.roster[1])
	check(b.pick_target() == null, "nobody to aim at")


func test_injured_never_aimed_at() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()), 4321)
	set_injured(b.roster[2])
	var counts := [0, 0, 0]
	var n := 6000
	for i in n:
		counts[b.line().find(b.pick_target())] += 1
	eq(counts[2], 0, "the injured rightmost is never picked")
	check(absf(counts[0] / float(n) - 1.0 / 3.0) < 0.02 and absf(counts[1] / float(n) - 2.0 / 3.0) < 0.02,
		"the others share the weight 1 : 2 (%s)" % str(counts))
	# Single-target actions in play.
	var acts: Array[EnemyActionData] = [make_action("Hit", 1, EnemyActionData.Targeting.SINGLE, 1)]
	var b2 := make_battle(three_companions(500), one_enemy(make_enemy("E", acts)), 7)
	set_injured(b2.roster[2])
	for i in 100:
		b2.perform_enemy_action(b2.enemies[0], acts[0])
	eq(b2.roster[2].hp, 0, "never hit")


func test_area_attack_skips_injured() -> void:
	var acts: Array[EnemyActionData] = [make_action("Boom", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 1)]
	var b := make_battle(three_companions(50), one_enemy(make_enemy("E", acts)))
	set_injured(b.roster[0])
	b.events.clear()
	b.perform_enemy_action(b.enemies[0], acts[0])
	check(b.roster[0].is_injured() and b.roster[0].hp == 0, "the injured companion is skipped")
	for ev in b.events:
		check(ev.get("target") != b.roster[0], "no event touches them")
	check(b.roster[1].is_active() and b.roster[2].is_active(), "others merely damaged")
	eq(b.roster[1].hp, 39, "area damage 10 + 1 - 0")


func test_heal_never_lifts_injury() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy()))
	var c := b.roster[0]
	set_injured(c)
	b.heal(c, 30)
	check(c.is_injured() and c.hp == 0, "nothing in battle undoes an injury")
	var d := b.roster[1]
	d.hp = 5
	b.heal(d, 3)
	eq(d.hp, 8, "a standing companion is healed")
	b.heal(d, 999)
	eq(d.hp, d.max_hp(), "healing caps at max HP")


# ---------------------------------------------------------------- battle end

func test_victory_keeps_injured() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1)))
	b._damage_companion(b.roster[0], 999, false)
	check(b.attack(b.roster[2], b.enemies[0]), "finishing blow")
	eq(b.outcome, Battle.Outcome.VICTORY, "victory when all enemies dead")
	check(b.roster[0].is_injured() and b.roster[0].hp == 0, "the injured stay injured after a win")
	eq(b.injured_ever, [b.roster[0]] as Array[CompanionUnit], "recorded")
	eq(b.roster[1].hp, 20, "healthy companion HP unchanged")
	check(not b.focus(b.roster[1]), "no commands after the battle ends")


## Injury ends every effect on the companion, and nothing new lands on them.
func test_injury_ends_effects() -> void:
	var acts: Array[EnemyActionData] = [make_action("Hit", 1, EnemyActionData.Targeting.SINGLE, 100)]
	var cs: Array[CompanionData] = [make_companion("A", 20), make_companion("B", 500)]
	var b := make_battle(cs, one_enemy(make_enemy("E", acts)))
	var a := b.roster[0]
	var poison := make_effect("Poison", {}, 5)
	poison.damage_per_tick = 2
	b._apply_effect(a, poison, false)
	b._apply_effect(a, make_effect("Brave", {Stat.STR: 2}, 5), true)
	eq(a.effects.size(), 2, "two effects on A")
	b._enemy_strike(b.enemies[0], acts[0], a)
	check(a.is_injured(), "A injured")
	eq(a.effects.size(), 0, "every effect on A ends")
	b._apply_effect(a, poison, false)
	eq(a.effects.size(), 0, "nothing new lands on A")
	b._damage_over_time(a)
	eq(a.hp, 0, "no damage over time on A")


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

func test_art_costs_stamina_and_focus_restores() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	var art := c.arts()[0]
	var normal := b.forecast(c, e)
	var with_art := b.forecast(c, e, art)
	eq(with_art.damage, normal.damage + 3, "art forecast includes Mt bonus")
	b.use_art(c, art, e)
	eq(c.stamina, 20, "art costs 10 STA")
	eq(e.hp, 1000 - 18, "art damage 10 + 5 + 3")
	c.stamina = 5
	b.attack(b.roster[1], e)
	b.attack(b.roster[2], e)
	check(not b.can_use_art(c, art), "not enough stamina")
	check(b.art_block_reason(c, art).contains("stamina"), "the reason given is stamina")
	check(not b.use_art(c, art, e), "art refused without stamina")
	eq(b.focus_amount(c), BattleConfig.FOCUS_RESTORE, "focus restores a flat amount")
	eq(BattleConfig.FOCUS_RESTORE, 5, "about the cost of a tier 1 art")
	b.focus(c)
	eq(c.stamina, 10, "stamina after focus")
	c.stamina = 29
	b.roster[1].recovery = 0
	b.roster[2].recovery = 0
	c.recovery = 0
	b.focus(c)
	eq(c.stamina, 30, "focus caps at max")

# ---------------------------------------------------------------- proficiency

func test_grade_thresholds() -> void:
	var pts := BattleConfig.PROFICIENCY_GRADE_POINTS
	eq(pts.size(), Proficiency.NAMES.size(), "one threshold per grade")
	eq(BattleConfig.ART_TIER_ODDS.size(), Proficiency.NAMES.size(), "one tier-odds row per grade")
	eq(pts[0], 0, "E needs nothing")
	for g in range(1, pts.size()):
		check(pts[g] > pts[g - 1], "grade %s needs more points than the one before" % Proficiency.grade_name(g))
		if g >= 2:
			check(pts[g] - pts[g - 1] >= pts[g - 1] - pts[g - 2], "step to %s is no shorter than the step before" % Proficiency.grade_name(g))
	for row: Array in BattleConfig.ART_TIER_ODDS:
		eq(int(row[0]) + int(row[1]) + int(row[2]), 100, "tier odds add up to 100")
	eq(Proficiency.grade_for_points(0), Proficiency.Grade.E, "0 points = E")
	eq(Proficiency.grade_for_points(pts[1] - 1), Proficiency.Grade.E, "one short of E+ is still E")
	eq(Proficiency.grade_for_points(pts[1]), Proficiency.Grade.E_PLUS, "exactly the threshold = E+")
	eq(Proficiency.grade_for_points(pts[2]), Proficiency.Grade.D, "D threshold")
	eq(Proficiency.grade_for_points(pts[10] - 1), Proficiency.Grade.A_PLUS, "one short of S")
	eq(Proficiency.grade_for_points(pts[10]), Proficiency.Grade.S, "S")
	eq(Proficiency.grade_for_points(99999), Proficiency.Grade.S, "nothing above S")
	eq(Proficiency.grade_name(Proficiency.Grade.D_PLUS), "D+", "grade names")

	var p := CompanionProgress.create(make_companion("A"))
	var sword := WeaponData.WeaponType.SWORD
	p.points[sword] = pts[2] + 2
	eq(p.grade(sword), Proficiency.Grade.D, "progress grade")
	eq(p.progress_to_next(sword), Vector2i(2, pts[3] - pts[2]), "progress toward D+")
	p.add_points(sword, 99999)
	eq(p.points_in(sword), pts[10], "points stop at the S threshold")
	eq(p.progress_to_next(sword), Vector2i.ZERO, "no next grade after S")


func test_proficiency_gain_per_action() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var c0 := b.roster[0]
	var c1 := b.roster[1]
	var c2 := b.roster[2]
	var e := b.enemies[0]
	b.attack(c0, e)
	eq(c0.progress.points_in(sword), BattleConfig.PROFICIENCY_POINTS_ATTACK, "attack gives attack points")
	b.guard(c1)
	eq(c1.progress.points_in(sword), 0, "guard gives none")
	b.focus(c2)
	eq(c2.progress.points_in(sword), 0, "focus gives none")
	b.use_art(c0, c0.arts()[0], e)
	eq(c0.progress.points_in(sword), BattleConfig.PROFICIENCY_POINTS_ATTACK + BattleConfig.PROFICIENCY_POINTS_ART,
		"an art gives art points")
	check(BattleConfig.PROFICIENCY_POINTS_ART > 0 and BattleConfig.PROFICIENCY_POINTS_ATTACK > 0, "both count")

	# Wait gives nothing to anyone.
	var cs: Array[CompanionData] = [make_companion("A"), make_companion("B")]
	var b2 := make_battle(cs, one_enemy(idle_enemy(1000)))
	b2.use_art(b2.roster[0], b2.roster[0].arts()[0], b2.enemies[0])
	b2.use_art(b2.roster[1], b2.roster[1].arts()[0], b2.enemies[0])
	var before := b2.roster[0].progress.points_in(sword) + b2.roster[1].progress.points_in(sword)
	check(b2.wait(), "wait accepted")
	eq(b2.roster[0].progress.points_in(sword) + b2.roster[1].progress.points_in(sword), before, "wait gives none")

	# Points go to the type of the weapon held.
	var axe_user := make_companion("Axe", 20, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.AXE))
	var b3 := make_battle([axe_user] as Array[CompanionData], one_enemy(idle_enemy(1000)))
	b3.attack(b3.roster[0], b3.enemies[0])
	eq(b3.roster[0].progress.points_in(WeaponData.WeaponType.AXE), BattleConfig.PROFICIENCY_POINTS_ATTACK, "axe points")
	eq(b3.roster[0].progress.points_in(sword), 0, "no sword points for an axe attack")


func test_proficiency_cap_per_battle() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var cs: Array[CompanionData] = [make_companion("Solo")]
	var party := CompanionProgress.create_party(cs)
	var b := make_battle(cs, one_enemy(idle_enemy(99999)), 1, party)
	var solo := b.roster[0]
	for i in 40:
		check(b.attack(solo, b.enemies[0]), "lone companion attacks every tick")
	eq(solo.proficiency_gained, BattleConfig.PROFICIENCY_CAP_PER_BATTLE, "gain stops at the cap")
	eq(party[0].points_in(sword), BattleConfig.PROFICIENCY_CAP_PER_BATTLE, "stored points stop at the cap")
	var capped_lines := 0
	for line in b.log_lines:
		if line.contains("proficiency this battle can give"):
			capped_lines += 1
	eq(capped_lines, 1, "the cap is logged once")
	# An art that would go past the cap only adds what is left.
	var b2 := make_battle(cs, one_enemy(idle_enemy(99999)), 1, party)
	b2.roster[0].proficiency_gained = BattleConfig.PROFICIENCY_CAP_PER_BATTLE - 1
	b2.use_art(b2.roster[0], b2.roster[0].arts()[0], b2.enemies[0])
	eq(party[0].points_in(sword), BattleConfig.PROFICIENCY_CAP_PER_BATTLE + 1, "only the room left under the cap is added")
	# The next battle starts a fresh allowance.
	var b3 := make_battle(cs, one_enemy(idle_enemy(99999)), 1, party)
	eq(b3.roster[0].proficiency_gained, 0, "allowance resets each battle")
	b3.attack(b3.roster[0], b3.enemies[0])
	eq(party[0].points_in(sword), BattleConfig.PROFICIENCY_CAP_PER_BATTLE + 1 + BattleConfig.PROFICIENCY_POINTS_ATTACK,
		"gains again in the next battle")


# ---------------------------------------------------------------- learning arts

func test_art_tier_odds_by_grade() -> void:
	var rng := make_rng(4242)
	var n := 20000
	for g in range(Proficiency.Grade.E_PLUS, Proficiency.max_grade() + 1):
		var counts := [0, 0, 0]
		for i in n:
			counts[ArtLearning.roll_tier(rng, g) - 1] += 1
		var odds: Array = BattleConfig.ART_TIER_ODDS[g]
		for t in 3:
			var share: float = counts[t] / float(n)
			var want: float = int(odds[t]) / 100.0
			check(absf(share - want) < 0.015, "grade %s tier %d share %.3f ~ %.2f" % [Proficiency.grade_name(g), t + 1, share, want])
			if int(odds[t]) == 0:
				eq(counts[t], 0, "grade %s never rolls tier %d" % [Proficiency.grade_name(g), t + 1])
	# The table as specified.
	eq(BattleConfig.ART_TIER_ODDS[Proficiency.Grade.D_PLUS], [100, 0, 0], "D+ odds")
	eq(BattleConfig.ART_TIER_ODDS[Proficiency.Grade.C], [75, 25, 0], "C odds")
	eq(BattleConfig.ART_TIER_ODDS[Proficiency.Grade.B_PLUS], [50, 40, 10], "B+ odds")
	eq(BattleConfig.ART_TIER_ODDS[Proficiency.Grade.A], [25, 50, 25], "A odds")
	eq(BattleConfig.ART_TIER_ODDS[Proficiency.Grade.S], [0, 50, 50], "S odds")


func test_learning_never_duplicates() -> void:
	var sword := WeaponData.WeaponType.SWORD
	for s in 30:
		var rng := make_rng(s)
		var pool := make_pool([3, 2, 2])
		pool.append(pool[0])               # listed twice
		pool.append(_test_signature)       # already known from the start
		var p := CompanionProgress.create(make_companion("A"))
		for g in range(Proficiency.Grade.E_PLUS, Proficiency.max_grade() + 1):
			var art := ArtLearning.pick_art(rng, p, sword, g, pool)
			if art != null:
				check(not p.knows(art), "seed %d: never picks a known art" % s)
				p.learn(art)
		eq(p.known_arts.size(), 8, "seed %d: signature + all 7 distinct arts, then nothing" % s)
		var seen := {}
		for a in p.known_arts:
			check(not seen.has(a), "no art known twice")
			seen[a] = true


func test_tier_fall_through() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var pool := make_pool([2, 1, 1])
	var p := CompanionProgress.create(make_companion("A"))
	p.learn(pool[0])
	p.learn(pool[1])
	for s in 20:
		var art := ArtLearning.pick_art(make_rng(s), p, sword, Proficiency.Grade.D_PLUS, pool)
		eq(art, pool[2], "tier 1 rolled (D+ is always tier 1) but all known -> nearest tier, 2")
	p.learn(pool[2])
	for s in 20:
		eq(ArtLearning.pick_art(make_rng(s), p, sword, Proficiency.Grade.D_PLUS, pool), pool[3], "then tier 3")
	# S never rolls tier 1, but falls through to it when nothing else is left.
	var q := CompanionProgress.create(make_companion("B"))
	q.learn(pool[2])
	q.learn(pool[3])
	for s in 20:
		var art := ArtLearning.pick_art(make_rng(s), q, sword, Proficiency.Grade.S, pool)
		check(art == pool[0] or art == pool[1], "S falls back to tier 1")
	# Nearest tier, lower first on a tie.
	var t1_t3: Array[CombatArtData] = [pool[0], pool[3]]
	eq(ArtLearning.nearest_tier(t1_t3, 2), 1, "tie between 1 and 3 -> 1")
	var only_t3: Array[CombatArtData] = [pool[3]]
	eq(ArtLearning.nearest_tier(only_t3, 1), 3, "only tier 3 left")


func test_learning_nothing_when_pool_exhausted() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var pool := make_pool([1])
	var p := CompanionProgress.create(make_companion("A"))
	p.learn(pool[0])
	eq(ArtLearning.pick_art(make_rng(1), p, sword, Proficiency.Grade.B, pool), null, "nothing left to learn")
	var other_type := make_pool([2], WeaponData.WeaponType.AXE)
	eq(ArtLearning.pick_art(make_rng(1), p, sword, Proficiency.Grade.B, other_type), null, "other types' arts are never learned")

	var party: Array[CompanionProgress] = [p]
	var b := make_battle([p.data] as Array[CompanionData], one_enemy(idle_enemy(1000)), 1, party, pool)
	var c := b.roster[0]
	c.progress.points[sword] = BattleConfig.PROFICIENCY_GRADE_POINTS[1] - 1
	var known := c.progress.known_arts.size()
	b.attack(c, b.enemies[0])
	eq(c.progress.grade(sword), Proficiency.Grade.E_PLUS, "the grade still rises")
	eq(b.grade_ups.size(), 1, "one grade-up recorded")
	eq(b.grade_ups[0].art, null, "with no art")
	eq(c.progress.known_arts.size(), known, "nothing learned")
	b.enemies[0].hp = 0
	b._check_end()
	eq(b.grade_ups[0].art, null, "nothing to learn at the end either")
	eq(c.progress.known_arts.size(), known, "still nothing learned")
	var logged := false
	for line in b.log_lines:
		logged = logged or line.contains("already knows every sword art")
	check(logged, "the log says why nothing was learned")


func test_grade_up_in_battle_learns_and_equips() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var pool := make_pool([3])
	var b := make_battle(three_companions(), one_enemy(make_enemy("E", [make_action("Poke", 1)] as Array[EnemyActionData], 1000)), 1,
		[] as Array[CompanionProgress], pool)
	var c := b.roster[0]
	var arts_before := c.progress.known_arts.size()
	c.progress.points[sword] = BattleConfig.PROFICIENCY_GRADE_POINTS[1] - 1
	b.attack(c, b.enemies[0])
	eq(c.progress.grade(sword), Proficiency.Grade.E_PLUS, "grade rose")
	var types: Array[String] = []
	var ev: Dictionary = {}
	for e in b.events:
		types.append(str(e.type))
		if e.type == "grade_up":
			ev = e
	check(not ev.is_empty(), "grade_up event emitted")
	eq(ev.get("grade"), Proficiency.Grade.E_PLUS, "event names the new grade")
	eq(ev.get("actor"), c, "event names the companion")
	check(ev.get("art") == null and ev.get("equipped") == false, "nothing learned during the battle")
	eq(b.grade_ups.size(), 1, "recorded")
	eq(c.progress.known_arts.size(), arts_before, "no new art known yet")
	eq(c.arts().size(), arts_before, "and none usable in this battle")
	check(types.find("grade_up") < types.find("countdown"), "the grade-up plays before the enemies' turn")
	var logged := false
	for line in b.log_lines:
		logged = logged or line.contains("grade rises to E+")
	check(logged, "grade-up written to the log")
	b.learn_after_battle()
	check(b.grade_ups[0].art == null and not b.learned, "learn_after_battle does nothing before the end")
	# The battle ends: the art is learned and filled into the entry.
	b.enemies[0].hp = 0
	b._check_end()
	check(b.learned, "learned at the end")
	var art: CombatArtData = b.grade_ups[0].art
	check(pool.has(art), "learned an art from the pool")
	check(b.grade_ups[0].equipped, "auto-equipped into a free slot")
	check(c.progress.knows(art) and c.progress.is_equipped(art), "known and carried now")
	var learned_ev := false
	for e in b.events:
		learned_ev = learned_ev or (e.type == "learned" and e.art == art)
	check(learned_ev, "a learned event for the screen")
	# Calling it again changes nothing.
	b.learn_after_battle()
	eq(c.progress.known_arts.size(), arts_before + 1, "learned once")


## A full set of three: the art is known but not carried ("equipped" false); swap() carries it.
## Everyone learns after the battle, injured ones too (nobody is removed), on a defeat as well.
func test_learning_after_battle_slots_and_removed() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var pool := make_pool([4])
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)), 1, [] as Array[CompanionProgress], pool)
	var full := b.roster[0]
	var gone := b.roster[1]
	var hurt := b.roster[2]
	for a in make_pool([2]):
		full.progress.learn(a)
	eq(full.progress.equipped_arts.size(), BattleConfig.MAX_EQUIPPED_ARTS, "three carried")
	for u in [full, gone, hurt]:
		u.progress.points[sword] = BattleConfig.PROFICIENCY_GRADE_POINTS[1] - 1
		b._gain_proficiency(u, 1)
	eq(b.grade_ups.size(), 3, "three grade-ups recorded")
	var gone_known := gone.progress.known_arts.size()
	gone.hp = 0
	gone.state = CompanionUnit.State.INJURED
	hurt.hp = 0
	hurt.state = CompanionUnit.State.INJURED
	full.hp = 0
	full.state = CompanionUnit.State.INJURED
	b._check_end()
	eq(b.outcome, Battle.Outcome.DEFEAT, "lost")
	var e_full: Dictionary = b.grade_ups[0]
	check(e_full.art != null and full.progress.knows(e_full.art), "learned on a defeat too")
	check(not e_full.equipped and not full.progress.is_equipped(e_full.art), "no free slot: known, left behind")
	var old := full.progress.equipped_arts[1]
	check(full.progress.swap(old, e_full.art), "swap carries the new art")
	eq(full.progress.equipped_arts[1], e_full.art, "in the same slot")
	check(not full.progress.is_equipped(old) and full.progress.knows(old), "the old one is left behind, still known")
	check(not full.progress.swap(old, e_full.art), "swap refuses an art not carried")
	check(b.grade_ups[1].art != null, "an injured companion learns too")
	eq(gone.progress.known_arts.size(), gone_known + 1, "one more art known")
	check(b.grade_ups[2].art != null and b.grade_ups[2].equipped, "the injured one learns and carries it")


func test_auto_equip_and_limit_of_three() -> void:
	var p := CompanionProgress.create(make_companion("A"))
	eq(p.equipped_arts, [_test_signature] as Array[CombatArtData], "signature art known and equipped from the start")
	var arts := make_pool([4])
	check(p.learn(arts[0]), "second art auto-equipped")
	check(p.learn(arts[1]), "third art auto-equipped")
	eq(p.equipped_arts.size(), BattleConfig.MAX_EQUIPPED_ARTS, "three equipped")
	check(not p.learn(arts[2]), "fourth art is learned but not equipped")
	check(p.knows(arts[2]) and not p.is_equipped(arts[2]), "known, not equipped")
	check(not p.equip(arts[2]), "cannot equip a fourth")
	check(not p.equip(arts[3]), "cannot equip an unknown art")
	check(p.unequip(arts[0]), "unequip one")
	check(p.equip(arts[2]), "then the fourth fits")
	eq(p.equipped_arts, [_test_signature, arts[1], arts[2]] as Array[CombatArtData], "equipped order kept")
	check(not p.learn(arts[2]), "learning a known art again does nothing")
	eq(p.known_arts.size(), 4, "no duplicate known art")
	var b := make_battle([p.data] as Array[CompanionData], one_enemy(idle_enemy()), 1, [p] as Array[CompanionProgress])
	eq(b.roster[0].arts().size(), 3, "only equipped arts are actions")
	check(not b.can_use_art(b.roster[0], arts[0]), "a known but unequipped art cannot be used")


func test_art_needs_matching_weapon_type() -> void:
	var axe := make_weapon(5, 999, 0, WeaponData.WeaponType.AXE)
	var cs: Array[CompanionData] = [make_companion("Axe", 20, 0, axe)]
	var b := make_battle(cs, one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var sword_art := c.arts()[0]
	eq(sword_art.weapon_type, WeaponData.WeaponType.SWORD, "test signature is a sword art")
	check(not b.can_use_art(c, sword_art), "a sword art cannot be used with an axe")
	check(b.art_block_reason(c, sword_art).contains("sword"), "the reason names the weapon type")
	check(not b.use_art(c, sword_art, b.enemies[0]), "use refused")
	eq(b.tick, 0, "no tick passed")
	var axe_art := make_art("Chop", 1, 5, 1, 0, WeaponData.WeaponType.AXE)
	c.progress.learn(axe_art)
	check(b.can_use_art(c, axe_art), "an axe art works with an axe")
	check(b.use_art(c, axe_art, b.enemies[0]), "and is accepted")


func test_art_costs_one_tick() -> void:
	var acts: Array[EnemyActionData] = [make_action("Slow", 5)]
	var es: Array[EnemyData] = [make_enemy("A", acts, 1000), make_enemy("B", acts, 1000)]
	var b := make_battle(three_companions(), es)
	var big := make_art("Big", 3, 10, 3)
	big.hits_all_enemies = true
	big.strikes = 2
	give_art(b.roster[0], big)
	check(b.use_art(b.roster[0], big), "art striking all enemies twice")
	eq(b.tick, 1, "one tick")
	eq(b.enemies[0].countdown, 4, "countdown dropped by exactly 1")
	eq(b.enemies[1].countdown, 4, "for every enemy")


func test_art_bonuses() -> void:
	# Hit -20 + 5 x (DEX 10 - SPD 0) = 30%, well clear of both clamps.
	var cs: Array[CompanionData] = [make_companion("A", 20, 0, make_weapon(5, -20))]
	var b := make_battle(cs, one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	var art := make_art("Bonus", 1, 5, 1, 4)
	art.hit_bonus = 15
	art.crit_bonus = 20
	give_art(c, art)
	var plain := b.forecast(c, e)
	var f := b.forecast(c, e, art)
	eq(f.damage, plain.damage + 4, "Mt bonus")
	eq(f.hit, plain.hit + 15, "Hit bonus")
	eq(f.crit, plain.crit + 20, "Crit bonus")
	eq(art.effect_summary(), "Mt +4, Hit +15, Crit +20.", "summary lists the bonuses")


func test_art_strikes_every_enemy() -> void:
	var es: Array[EnemyData] = [idle_enemy(100), idle_enemy(100), idle_enemy(100)]
	var b := make_battle(three_companions(), es)
	var c := b.roster[0]
	var sweep := make_art("Sweep")
	sweep.hits_all_enemies = true
	give_art(c, sweep)
	b.enemies[1].hp = 0
	check(b.use_art(c, sweep), "needs no target")
	eq(b.enemies[0].hp, 85, "first enemy hit (10 + 5)")
	eq(b.enemies[2].hp, 85, "third enemy hit")
	eq(b.enemies[1].hp, 0, "defeated enemy skipped")
	var hit_targets := []
	for ev in b.events:
		if ev.type == "damage":
			hit_targets.append(ev.target)
	eq(hit_targets.size(), 2, "one damage event per living enemy")
	var single := make_art("Single")
	give_art(b.roster[1], single)
	check(not b.use_art(b.roster[1], single, null), "a single-target art needs a target")


func test_art_strikes_twice() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(100)))
	var c := b.roster[0]
	var twice := make_art("Twice")
	twice.strikes = 2
	give_art(c, twice)
	b.use_art(c, twice, b.enemies[0])
	eq(b.enemies[0].hp, 70, "two strikes of 15")
	var damage_events := 0
	for ev in b.events:
		if ev.type == "damage":
			damage_events += 1
	eq(damage_events, 2, "two damage events")
	# The second strike is skipped if the first one kills.
	var b2 := make_battle(three_companions(), one_enemy(idle_enemy(10)))
	give_art(b2.roster[0], twice)
	b2.use_art(b2.roster[0], twice, b2.enemies[0])
	damage_events = 0
	for ev in b2.events:
		if ev.type == "damage":
			damage_events += 1
	eq(damage_events, 1, "no second strike on a defeated enemy")


func test_art_ignores_defense() -> void:
	eq(CombatMath.defense_after_ignore(5, 50), 2, "half of DEF 5 ignored, rounded in the attacker's favour")
	eq(CombatMath.defense_after_ignore(6, 100), 0, "all DEF ignored")
	eq(CombatMath.defense_after_ignore(6, 0), 6, "none ignored")
	var armored := idle_enemy(100)
	armored.defense = 6
	var b := make_battle(three_companions(), one_enemy(armored))
	var c := b.roster[0]
	var e := b.enemies[0]
	var pierce := make_art("Pierce")
	pierce.ignore_def_percent = 50
	give_art(c, pierce)
	eq(b.forecast(c, e).damage, 9, "plain: 10 + 5 - 6")
	eq(b.forecast(c, e, pierce).damage, 12, "half DEF ignored: 10 + 5 - 3")
	b.use_art(c, pierce, e)
	eq(e.hp, 88, "dealt as forecast")


func test_art_debuffs_target() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	var sunder := make_art("Sunder")
	sunder.target_effect = make_effect("Sundered", {Stat.DEF: -3}, 3)
	give_art(c, sunder)
	e.base_stats[Stat.DEF] = 4
	b.use_art(c, sunder, e)
	check(e.has_effect("Sundered"), "debuff applied to the target")
	eq(e.stat(Stat.DEF), 1, "DEF lowered")
	check(not c.has_effect("Sundered"), "not on the user")
	b.guard(b.roster[1])
	b.guard(b.roster[2])
	check(not e.has_effect("Sundered"), "expires after 3 ticks")
	# A miss applies nothing.
	var found_miss := false
	for s in 40:
		var cs: Array[CompanionData] = [make_companion("A", 20, 0, make_weapon(5, -999))]
		var b2 := make_battle(cs, one_enemy(idle_enemy(1000)), s)
		give_art(b2.roster[0], sunder)
		b2.use_art(b2.roster[0], sunder, b2.enemies[0])
		if b2.enemies[0].hp == 1000:
			found_miss = true
			check(not b2.enemies[0].has_effect("Sundered"), "no debuff on a miss")
			break
	check(found_miss, "found a missing strike")


func test_art_buffs_user() -> void:
	var b := make_battle(three_companions(), one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	var fury := make_art("Fury")
	fury.self_effect = make_effect("Fury", {Stat.STR: 4}, 4)
	give_art(c, fury)
	var plain := b.forecast(c, e).damage
	b.use_art(c, fury, e)
	check(c.has_effect("Fury"), "buff applied to the user")
	check(not e.has_effect("Fury"), "not to the target")
	eq(c.stat(Stat.STR), 14, "STR raised")
	eq(b.forecast(c, e).damage, plain + 4, "and the next strike is stronger")
	b.guard(b.roster[1])
	b.guard(b.roster[2])
	check(c.has_effect("Fury"), "still on after 3 ticks")
	b.attack(c, e)
	check(not c.has_effect("Fury"), "gone after the 4th tick")
	# Applied even when the strike misses.
	var cs: Array[CompanionData] = [make_companion("A", 20, 0, make_weapon(5, -999))]
	for s in 40:
		var b2 := make_battle(cs, one_enemy(idle_enemy(1000)), s)
		give_art(b2.roster[0], fury)
		b2.use_art(b2.roster[0], fury, b2.enemies[0])
		if b2.enemies[0].hp == 1000:
			check(b2.roster[0].has_effect("Fury"), "buff applied on a miss too")
			break
	var taken := make_art("Parry")
	taken.self_effect = make_effect("Parry", {}, 2, 0.5)
	eq(taken.effect_summary(), "User gains Parry (takes 50% less damage, 2 turns).", "summary describes the buff")


func load_art(path: String) -> CombatArtData:
	return load("res://data/arts/%s.tres" % path) as CombatArtData


func count_events(b: Battle, type: String) -> int:
	var n := 0
	for ev in b.events:
		if ev.type == type:
			n += 1
	return n


func log_has(b: Battle, text: String) -> bool:
	for line_text in b.log_lines:
		if line_text.contains(text):
			return true
	return false


## An enemy whose single physical blow (STR 10 + Mt 20) lands every tick.
func brute(hp: int = 1000, targeting: EnemyActionData.Targeting = EnemyActionData.Targeting.SINGLE,
		countdown: int = 1) -> EnemyData:
	var acts: Array[EnemyActionData] = [make_action("Smash", countdown, targeting, 20)]
	return make_enemy("Brute", acts, hp)


## Riposte on a companion: an enemy's physical blow that lands hurts the enemy for 30% of it.
func test_art_reflecting_stance() -> void:
	var riposte := load_art("sword/riposte")
	eq(riposte.self_effect.reflect_percent, 30, "Riposte reflects 30%")
	var cs: Array[CompanionData] = [make_companion("A", 100)]
	var b := make_battle(cs, one_enemy(brute()))
	var c := b.roster[0]
	var e := b.enemies[0]
	give_art(c, riposte)
	check(b.use_art(c, riposte, e), "Riposte used")
	eq(c.hp, 100 - 30, "the Brute's blow still lands in full")
	eq(e.hp, 1000 - 18 - 9, "Riposte's strike (18), then 30% of the 30 dealt back")
	eq(count_events(b, "riposte"), 1, "a riposte event for playback")
	check(log_has(b, "A's Riposte strikes back at Brute!"), "the log says so")
	b.guard(c)
	b.guard(c)
	eq(count_events(b, "riposte"), 0, "worn off after 2 ticks: nothing reflected")
	# Magic is never reflected.
	var mage := brute()
	mage.actions[0].damage_type = CombatMath.DamageType.MAGIC
	var b2 := make_battle(cs, one_enemy(mage))
	give_art(b2.roster[0], riposte)
	b2.use_art(b2.roster[0], riposte, b2.enemies[0])
	eq(b2.enemies[0].hp, 1000 - 18, "a magic blow is not reflected")
	# At least 1 is reflected.
	var tough: Array[CompanionData] = [make_companion("A", 100, 100)]
	var b3 := make_battle(tough, one_enemy(brute()))
	give_art(b3.roster[0], riposte)
	b3.use_art(b3.roster[0], riposte, b3.enemies[0])
	eq(b3.roster[0].hp, 100 - 1, "the blow deals only 1")
	eq(b3.enemies[0].hp, 1000 - 18 - 1, "and still 1 comes back")
	# The reflected damage can defeat the enemy, which ends the battle.
	var b4 := make_battle(cs, one_enemy(brute(20)))
	give_art(b4.roster[0], riposte)
	b4.use_art(b4.roster[0], riposte, b4.enemies[0])
	check(not b4.enemies[0].is_alive(), "struck down by its own blow")
	check(log_has(b4, "Brute is defeated!"), "the defeat is logged")
	eq(b4.outcome, Battle.Outcome.VICTORY, "and the battle is won")
	# An enemy struck down partway through an attack on everyone stops there.
	var two: Array[CompanionData] = [make_companion("A", 100), make_companion("B", 100)]
	var b5 := make_battle(two, one_enemy(brute(18 + 18 + 9, EnemyActionData.Targeting.ALL_COMPANIONS, 2)))
	give_art(b5.roster[0], riposte)
	give_art(b5.roster[1], riposte)
	b5.use_art(b5.roster[0], riposte, b5.enemies[0])
	b5.use_art(b5.roster[1], riposte, b5.enemies[0])
	eq(b5.roster[0].hp, 100 - 30, "A is hit and strikes back")
	eq(b5.roster[1].hp, 100, "B is never reached")
	eq(b5.outcome, Battle.Outcome.VICTORY, "won")
	eq(load_art("spear/set_spear").self_effect.reflect_percent, 40, "Set Spear reflects 40%")


## Bleeding Cut: the enemy loses HP at the end of every tick and can die of it.
func test_art_bleed_kills_enemy() -> void:
	var cut := load_art("dagger/bleeding_cut")
	var cs: Array[CompanionData] = [make_companion("A", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.DAGGER))]
	cs[0].speed = 10   # a dagger's attack power is (STR + SPD) / 2: 10
	var b := make_battle(cs, one_enemy(idle_enemy(20)))
	var c := b.roster[0]
	var e := b.enemies[0]
	give_art(c, cut)
	check(b.use_art(c, cut, e), "Bleeding Cut used")
	eq(e.hp, 20 - 16 - 2, "16 from the cut, then 2 at the end of the tick")
	eq(count_events(b, "dot"), 1, "a dot event for playback")
	check(log_has(b, "Dummy loses 2 HP to Bleeding"), "the log names the bleeding")
	b.guard(c)
	check(not e.is_alive(), "bled out")
	check(log_has(b, "Dummy is defeated!"), "the defeat is logged")
	eq(b.outcome, Battle.Outcome.VICTORY, "and the battle is won")
	for path in ["bow/barbed_arrow", "dagger/night_venom", "spear/impale"]:
		check(load_art(path).target_effect.damage_per_tick > 0, "%s bleeds the target" % path)


# ---------------------------------------------------------------- contribution points

## A landed Attack earns 2 points, a miss 1.
func test_points_for_attacks() -> void:
	var cs: Array[CompanionData] = [make_companion("A", 100, 0, make_weapon(1, 0))]   # Hit 0: the 20% floor
	var b := make_battle(cs, one_enemy(idle_enemy(100000)))
	var c := b.roster[0]   # alone: ignores recovery
	var hits := 0
	var misses := 0
	for i in 40:
		b.attack(c, b.enemies[0])
		if count_events(b, "miss") > 0:
			misses += 1
		else:
			hits += 1
	check(hits > 0 and misses > 0, "both hits (%d) and misses (%d) happened" % [hits, misses])
	eq(b.points_of(c), hits * BattleConfig.POINTS_ATTACK_HIT + misses * BattleConfig.POINTS_ATTACK_MISS, "2 a hit, 1 a miss")
	eq([BattleConfig.POINTS_ATTACK_HIT, BattleConfig.POINTS_ATTACK_MISS], [2, 1], "the attack points")


## An art used earns 3 however many enemies it strikes; a spell cast of any kind earns 3; Focus, Guard
## and Wait earn nothing.
func test_points_for_arts_and_spells() -> void:
	var cs: Array[CompanionData] = [make_companion("A", 100), make_companion("B", 100), make_companion("C", 100)]
	cs[2].magic = 5
	var es: Array[EnemyData] = [idle_enemy(1000), idle_enemy(1000), idle_enemy(1000)]
	var b := make_battle(cs, es)
	var a := b.roster[0]
	var sweep := make_art("Sweep", 1, 5, 1, 0)
	sweep.hits_all_enemies = true
	give_art(a, sweep)
	check(b.use_art(a, sweep), "the art strikes every enemy")
	eq(b.points_of(a), BattleConfig.POINTS_ART, "3 for the art, not 3 per enemy")
	var bolt := SpellData.new()
	bolt.display_name = "Bolt"
	bolt.might = 1
	bolt.hit = 999
	var mend := SpellData.new()
	mend.display_name = "Mend"
	mend.school = SpellData.School.WHITE
	mend.targeting = SpellData.Targeting.ONE_ALLY
	mend.heals = true
	var ward := SpellData.new()
	ward.display_name = "Ward"
	ward.school = SpellData.School.WHITE
	ward.targeting = SpellData.Targeting.ALL_ALLIES
	ward.effect = make_effect("Warded", {}, 3, 0.5)
	var mage := b.roster[2]
	for sp in [bolt, mend, ward]:
		mage.progress.learn_spell(sp)
	check(b.cast(mage, bolt, b.enemies[0]), "damage spell")
	eq(b.points_of(mage), BattleConfig.POINTS_SPELL, "3 for a damage spell")
	mage.recovery = 0
	check(b.cast(mage, mend, a), "heal")
	mage.recovery = 0
	check(b.cast(mage, ward), "support on everyone")
	eq(b.points_of(mage), 3 * BattleConfig.POINTS_SPELL, "3 for each, whatever the kind")
	var other := b.roster[1]
	check(b.focus(other), "focus")
	eq(b.points_of(other), 0, "Focus earns nothing")
	a.recovery = 0
	other.recovery = 0
	b.guard(other)
	eq(b.points_of(other), 0, "Guard alone earns nothing")
	for c in b.roster:
		c.recovery = 5
	var before := b.points.duplicate()
	check(b.wait(), "wait")
	eq(b.points, before, "Wait earns nothing")


## Each enemy blow that lands on a companion earns them 1, or 2 while guarding; one on everyone counts
## for each companion it lands on.
func test_points_for_blows_taken() -> void:
	var cs: Array[CompanionData] = [make_companion("A", 1000)]
	var b := make_battle(cs, one_enemy(brute()))
	var c := b.roster[0]
	b.focus(c)
	eq(b.points_of(c), BattleConfig.POINTS_BLOW_TAKEN, "1 for a blow taken")
	b.guard(c)
	eq(b.points_of(c), BattleConfig.POINTS_BLOW_TAKEN + BattleConfig.POINTS_BLOW_TAKEN_GUARDING, "2 for one taken on Guard")
	var b2 := make_battle(three_companions(1000), one_enemy(brute(1000, EnemyActionData.Targeting.ALL_COMPANIONS)))
	b2.focus(b2.roster[0])
	for x in b2.roster:
		eq(b2.points_of(x), BattleConfig.POINTS_BLOW_TAKEN, "%s: 1 from the sweep" % x.display_name)
	# A blow that misses earns nothing: over many turns, the points are exactly the blows that landed.
	var dodgy := brute()
	dodgy.actions[0].hit = 0
	var nimble: Array[CompanionData] = [make_companion("A", 100000)]
	var b3 := make_battle(nimble, one_enemy(dodgy))
	var landed := 0
	for i in 40:
		b3.focus(b3.roster[0])
		if count_events(b3, "miss") == 0:
			landed += 1
	check(landed > 0 and landed < 40, "some blows missed (%d of 40 landed)" % landed)
	eq(b3.points_of(b3.roster[0]), landed * BattleConfig.POINTS_BLOW_TAKEN, "only landed blows count")


## The companion who lands the killing blow earns 4 more; an art that kills several earns it for each.
func test_points_for_kills() -> void:
	var cs: Array[CompanionData] = [make_companion("A", 100), make_companion("B", 100)]
	var es: Array[EnemyData] = [idle_enemy(5), idle_enemy(1000)]
	var b := make_battle(cs, es)
	var a := b.roster[0]
	check(b.attack(a, b.enemies[0]), "attack")
	check(not b.enemies[0].is_alive(), "the first enemy falls")
	eq(b.points_of(a), BattleConfig.POINTS_ATTACK_HIT + BattleConfig.POINTS_KILL, "2 for the hit, 4 for the kill")
	eq(b.kills_of(a), 1, "one kill")
	eq(BattleConfig.POINTS_KILL, 4, "the kill bonus")
	var defeated: Dictionary = {}
	for ev in b.events:
		if ev.type == "defeated":
			defeated = ev
	eq(defeated.get("by"), a, "the defeat event names who landed it")
	# An art striking every enemy, killing three of four.
	var four: Array[EnemyData] = [idle_enemy(5), idle_enemy(5), idle_enemy(1000), idle_enemy(5)]
	var b2 := make_battle(cs, four)
	var c := b2.roster[1]
	var sweep := make_art("Sweep", 1, 5, 1, 0)
	sweep.hits_all_enemies = true
	give_art(c, sweep)
	check(b2.use_art(c, sweep), "the sweep")
	eq(b2.living_enemies().size(), 1, "three fall")
	eq(b2.kills_of(c), 3, "three kills")
	eq(b2.points_of(c), BattleConfig.POINTS_ART + 3 * BattleConfig.POINTS_KILL, "3 for the art, 4 for each kill")
	eq(b2.points_of(b2.roster[0]), 0, "nothing for the other")


## A kill by bleeding goes to whoever applied it, even on someone else's turn; a kill by a reflecting
## stance goes to whoever carries it.
func test_kill_by_bleed_or_stance_is_credited() -> void:
	var cut := load_art("dagger/bleeding_cut")
	var cs: Array[CompanionData] = [make_companion("A", 100), make_companion("B", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.DAGGER))]
	cs[1].speed = 10
	var b := make_battle(cs, one_enemy(idle_enemy(20)))
	var cutter := b.roster[1]
	give_art(cutter, cut)
	check(b.use_art(cutter, cut, b.enemies[0]), "Bleeding Cut")
	eq(b.enemies[0].hp, 2, "16 and 2 of bleeding")
	b.guard(b.roster[0])
	check(not b.enemies[0].is_alive(), "it bleeds out on A's turn")
	eq(b.kills_of(cutter), 1, "the kill is the cutter's")
	eq(b.points_of(cutter), BattleConfig.POINTS_ART + BattleConfig.POINTS_KILL, "3 for the art, 4 for the kill")
	eq(b.points_of(b.roster[0]), 0, "nothing for A")
	# Riposte: the Brute's blow (1 point) is answered and kills it (4 more), after the art (3).
	var riposte := load_art("sword/riposte")
	var one: Array[CompanionData] = [make_companion("A", 100)]
	var b2 := make_battle(one, one_enemy(brute(20)))
	give_art(b2.roster[0], riposte)
	b2.use_art(b2.roster[0], riposte, b2.enemies[0])
	check(not b2.enemies[0].is_alive(), "struck down by its own blow")
	eq(b2.kills_of(b2.roster[0]), 1, "the kill is the stance's bearer's")
	eq(b2.points_of(b2.roster[0]), BattleConfig.POINTS_ART + BattleConfig.POINTS_BLOW_TAKEN + BattleConfig.POINTS_KILL, "art, blow taken and kill")


## Challenge, Phalanx and Fade change how likely enemies are to aim at the user.
func test_art_stances_change_aim() -> void:
	var cs: Array[CompanionData] = [
		make_companion("Axe", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.AXE)),
		make_companion("Spear", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.SPEAR)),
		make_companion("Dagger", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.DAGGER))]
	var b := make_battle(cs, one_enemy(idle_enemy(1000)), 777)
	var challenge := load_art("axe/challenge")
	var phalanx := load_art("spear/phalanx")
	var fade := load_art("dagger/fade")
	give_art(b.roster[0], challenge)
	give_art(b.roster[1], phalanx)
	give_art(b.roster[2], fade)
	eq(b.target_weights(), [1.0, 2.0, 4.0] as Array[float], "base weights")
	b.use_art(b.roster[0], challenge, b.enemies[0])
	eq(b.target_weights(), [3.0, 2.0, 4.0] as Array[float], "Challenging: three times as likely")
	var counts := [0, 0, 0]
	var n := 9000
	for i in n:
		counts[b.line().find(b.pick_target())] += 1
	check(absf(counts[0] / float(n) - 3.0 / 9.0) < 0.02, "the challenger draws a third of the blows (%d)" % counts[0])
	b.use_art(b.roster[1], phalanx, b.enemies[0])
	eq(b.target_weights(), [1.0, 4.0, 4.0] as Array[float], "Challenging worn off, Phalanx doubles")
	b.use_art(b.roster[2], fade, b.enemies[0])
	var w := b.target_weights()
	check(is_equal_approx(w[2], 1.6), "Faded: 60%% less likely (%s)" % str(w[2]))
	eq(w[1], 4.0, "Phalanx still up")


## Hew: every landed hit adds a stack of DEF -2, up to 3.
func test_art_debuff_stacks() -> void:
	var hew := load_art("axe/hew")
	var cs: Array[CompanionData] = [make_companion("A", 100, 0, make_weapon(5, 999, 0, WeaponData.WeaponType.AXE))]
	var b := make_battle(cs, one_enemy(idle_enemy(1000)))
	var c := b.roster[0]
	var e := b.enemies[0]
	e.base_stats[Stat.DEF] = 10
	give_art(c, hew)
	for i in 4:
		c.stamina = c.max_stamina()
		check(b.use_art(c, hew, e), "Hew %d" % (i + 1))
		eq(e.get_effect("Hewn").stacks, mini(i + 1, 3), "stacks after hit %d" % (i + 1))
		eq(e.stat(Stat.DEF), 10 - 2 * mini(i + 1, 3), "DEF after hit %d" % (i + 1))
	eq(e.effects.size(), 1, "still one effect")


## Duelist's Oath: the user hits harder but takes 25% more damage while it lasts.
func test_art_oath_raises_damage_taken() -> void:
	var oath := load_art("sword/duelists_oath")
	var cs: Array[CompanionData] = [make_companion("A", 100)]
	var b := make_battle(cs, one_enemy(brute(1000, EnemyActionData.Targeting.SINGLE, 2)))
	var c := b.roster[0]
	give_art(c, oath)
	eq(CombatMath.forecast(b.enemies[0], 20, 999, 0, c).damage, 30, "30 before the oath")
	check(b.use_art(c, oath, b.enemies[0]), "Duelist's Oath used")
	eq(c.stat(Stat.STR), 13, "STR +3")
	eq(c.damage_taken_mult(), 1.25, "takes 25% more")
	b.guard(c)   # the Brute strikes this tick, into a Guard (x0.5) and the oath (x1.25)
	eq(c.hp, 100 - floori(30 * 0.5 * 1.25), "guarded blow raised by the oath")
	b.guard(c)
	eq(c.hp, 100 - 18, "no blow this tick")
	b.attack(c, b.enemies[0])   # the Brute strikes again, no Guard this time
	eq(c.hp, 100 - 18 - floori(30 * 1.25), "a plain blow raised by the oath: 37")


func test_equip_requirement() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var fine := make_weapon()
	fine.required_grade = Proficiency.Grade.C
	var p := CompanionProgress.create(make_companion("A"))
	eq(p.grade(sword), Proficiency.Grade.E, "test companion starts at E")
	check(p.can_equip_weapon(make_weapon()), "an E weapon is always allowed")
	check(not p.can_equip_weapon(fine), "C weapon refused at E")
	p.points[sword] = Proficiency.points_for(Proficiency.Grade.C) - 1
	check(not p.can_equip_weapon(fine), "refused one point short of C")
	p.points[sword] = Proficiency.points_for(Proficiency.Grade.C)
	check(p.can_equip_weapon(fine), "allowed at C")
	var axe := make_weapon(5, 80, 0, WeaponData.WeaponType.AXE)
	axe.required_grade = Proficiency.Grade.E_PLUS
	check(not p.can_equip_weapon(axe), "the grade that counts is the weapon's own type")
	check(Proficiency.meets_requirement(Proficiency.Grade.S, fine), "S meets everything")
	check(Proficiency.meets_requirement(Proficiency.Grade.E, null), "no weapon, no requirement")


func test_progress_survives_into_second_battle() -> void:
	var sword := WeaponData.WeaponType.SWORD
	var cs := three_companions()
	var party := CompanionProgress.create_party(cs)
	var pool := make_pool([3])
	var b1 := make_battle(cs, one_enemy(idle_enemy(1000)), 5, party, pool)
	var c := b1.roster[0]
	c.progress.points[sword] = BattleConfig.PROFICIENCY_GRADE_POINTS[1] - 1
	b1.attack(c, b1.enemies[0])
	b1.enemies[0].hp = 0
	b1._check_end()
	var learned: CombatArtData = b1.grade_ups[0].art
	check(learned != null, "an art was learned in battle 1")
	var points := party[0].points_in(sword)
	c.hp = -3
	c.state = CompanionUnit.State.INJURED
	c.stamina = 0

	var b2 := make_battle(cs, one_enemy(idle_enemy(1000)), 6, party, pool)
	var c2 := b2.roster[0]
	check(c2.progress == party[0], "battle 2 uses the same progress")
	eq(c2.progress.points_in(sword), points, "points kept")
	eq(c2.progress.grade(sword), Proficiency.Grade.E_PLUS, "grade kept")
	check(c2.arts().has(learned), "learned art still equipped")
	eq(c2.hp, c2.max_hp(), "HP restored")
	eq(c2.stamina, c2.max_stamina(), "stamina restored")
	check(c2.is_active(), "injury gone")
	eq(c2.proficiency_gained, 0, "per-battle allowance reset")

	var snapshot := party[0].copy()
	party[0].unequip(learned)
	party[0].add_points(sword, 3)
	check(snapshot.is_equipped(learned), "a copy is independent of later changes")
	eq(snapshot.points_in(sword), points, "copy keeps its own points")


func test_art_content() -> void:
	var lib := ArtLibrary.load_default()
	check(lib != null and not lib.arts.is_empty(), "art library loads")
	var companions: Array[CompanionData] = []
	for n: String in ["elena", "aina", "erik", "ingrid", "yuzu"]:
		companions.append(load("res://data/companions/%s.tres" % n))
	var signatures: Array[CombatArtData] = []
	for d in companions:
		check(d.signature_art != null, "%s has a signature art" % d.display_name)
		signatures.append(d.signature_art)
		eq(d.signature_art.weapon_type, d.weapon.weapon_type, "%s's signature art fits the weapon" % d.display_name)
		var wielded := d.starting_grade(d.weapon.weapon_type)
		for t: int in WeaponData.WeaponType.values():
			if t != d.weapon.weapon_type:
				check(wielded > d.starting_grade(t), "%s starts higher in the wielded type" % d.display_name)
		eq(d.weapon.required_grade, Proficiency.Grade.E, "%s requires E" % d.weapon.display_name)
		check(CompanionProgress.create(d).can_equip_weapon(d.weapon), "%s can equip their own weapon" % d.display_name)
	var names := {}
	for a in lib.arts:
		check(not names.has(a.display_name), "art names are unique (%s)" % a.display_name)
		names[a.display_name] = true
		check(a.tier >= 1 and a.tier <= 3, "%s tier 1-3" % a.display_name)
		check(a.stamina_cost > 0 and a.recovery >= 1, "%s costs something" % a.display_name)
		check(a.description != "", "%s has a description" % a.display_name)
	for a in signatures:
		check(lib.arts.has(a), "signature %s is one of the arts of its weapon" % a.display_name)
	for t: int in WeaponData.WeaponType.values():
		var tier_count := [0, 0, 0, 0]
		var cost_min := [0, 999, 999, 999]
		var cost_max := [0, 0, 0, 0]
		var rec_min := [0, 999, 999, 999]
		var rec_max := [0, 0, 0, 0]
		for a in lib.arts:
			if a.weapon_type != t:
				continue
			if lib.arts.has(a):
				tier_count[a.tier] += 1
			cost_min[a.tier] = mini(cost_min[a.tier], a.stamina_cost)
			cost_max[a.tier] = maxi(cost_max[a.tier], a.stamina_cost)
			rec_min[a.tier] = mini(rec_min[a.tier], a.recovery)
			rec_max[a.tier] = maxi(rec_max[a.tier], a.recovery)
		var kind := WeaponData.type_name(t)
		# Twelve arts per type, 5 / 4 / 3 by tier, signatures included.
		eq(tier_count, [0, 5, 4, 3], "%s learnable arts by tier" % kind)
		for tier in [1, 2]:
			if cost_max[tier] > 0 and cost_min[tier + 1] < 999:
				check(cost_max[tier] < cost_min[tier + 1], "%s tier %d costs less stamina than tier %d" % [kind, tier, tier + 1])
				check(rec_max[tier] < rec_min[tier + 1], "%s tier %d recovers faster than tier %d" % [kind, tier, tier + 1])


## Every weapon type has exactly 12 arts in the library (every signature art is one of them),
## 5 of tier 1, 4 of tier 2 and 3 of tier 3. Every art has a name, a description, a cost and
## recovery equal to its tier.
func test_art_counts_and_basics() -> void:
	var lib := ArtLibrary.load_default()
	var every: Array[CombatArtData] = []
	for a in lib.arts:
		check(not every.has(a), "%s is listed once" % a.display_name)
		every.append(a)
	var dir := DirAccess.open("res://data/companions")
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var d: CompanionData = load("res://data/companions/" + f)
		if d.signature_art != null:
			check(every.has(d.signature_art), "%s's signature art is in the library" % d.display_name)
	var names := {}
	for a in every:
		check(a.display_name != "", "%s has a name" % a.resource_path)
		check(a.description != "", "%s has a description" % a.display_name)
		check(a.stamina_cost > 0, "%s costs stamina" % a.display_name)
		eq(a.recovery, a.tier, "%s recovery equals its tier" % a.display_name)
		check(not names.has(a.display_name), "no other art is called %s" % a.display_name)
		names[a.display_name] = true
	for t: int in WeaponData.WeaponType.values():
		var tier_count := [0, 0, 0, 0]
		for a in every:
			if a.weapon_type == t:
				tier_count[a.tier] += 1
		eq(tier_count, [0, 5, 4, 3], "%s arts by tier" % WeaponData.type_name(t))
	var sig := {"asterion": "Challenge", "kaito": "Feint", "raizen": "Long Reach", "koharu": "Barbed Arrow"}
	for n: String in sig:
		var d: CompanionData = load("res://data/companions/%s.tres" % n)
		eq(d.signature_art.display_name, sig[n], "%s's signature art" % d.display_name)


# ---------------------------------------------------------------- whole battles from the real data

## Plays one battle with a random but legal policy. Returns the number of ticks.
func play_random(b: Battle, policy: RandomNumberGenerator) -> int:
	var ticks := 0
	while not b.is_over() and ticks < 500:
		ticks += 1
		if b.can_wait():
			check(b.wait(), "wait accepted")
			continue
		var ready := b.ready_companions()
		var c := ready[policy.randi_range(0, ready.size() - 1)]
		var foes := b.living_enemies()
		var target := foes[policy.randi_range(0, foes.size() - 1)]
		var roll := policy.randi_range(0, 9)
		var ok := false
		var art: CombatArtData = c.arts()[policy.randi_range(0, c.arts().size() - 1)] if not c.arts().is_empty() else null
		if roll < 6:
			ok = b.attack(c, target)
		elif roll < 8 and b.can_use_art(c, art):
			ok = b.use_art(c, art, target)
		elif roll < 9:
			ok = b.guard(c)
		else:
			ok = b.focus(c)
		if not ok:
			ok = b.attack(c, target)
		check(ok, "a legal command was accepted")
	return ticks


## Tuning check: progress carried over several prototype battles in a row.
func test_prototype_progression() -> void:
	var setup: BattleSetup = load("res://data/battles/prototype_battle.tres")
	var pool := ArtLibrary.load_default().arts
	var runs := 100
	var battles := 5
	var first_up_by := [0, 0, 0, 0, 0, 0]   # companions whose first grade-up came in battle i (1-based)
	var never := 0
	var points_total := 0
	var battles_played := 0
	var capped := 0
	for r in runs:
		var party := CompanionProgress.create_party(setup.companions)
		var first := {}
		for n in battles:
			var b := Battle.new(setup.companions, setup.enemies, make_rng(r * 31 + n), party, pool)
			play_random(b, make_rng(r * 17 + n + 5000))
			for c in b.roster:
				points_total += c.proficiency_gained
				if c.proficiency_gained >= BattleConfig.PROFICIENCY_CAP_PER_BATTLE:
					capped += 1
			battles_played += 1
			for g in b.grade_ups:
				if not first.has(g.actor.data):
					first[g.actor.data] = n + 1
				var learned: CombatArtData = g.art
				if learned != null:
					check(g.actor.progress.knows(learned), "learned art is known")
			for p in party:
				check(p.equipped_arts.size() <= BattleConfig.MAX_EQUIPPED_ARTS, "never more than 3 equipped")
		for d in setup.companions:
			if first.has(d):
				first_up_by[first[d]] += 1
			else:
				never += 1
	var total := runs * setup.companions.size()
	var by_two: int = first_up_by[1] + first_up_by[2]
	print("  progression: first grade-up in battle 1: %d%%, by battle 2: %d%%, none in %d battles: %d%%; avg %.1f points per companion per battle; %d%% of companion-battles hit the cap" % [
		roundi(first_up_by[1] * 100.0 / total), roundi(by_two * 100.0 / total), battles, roundi(never * 100.0 / total),
		points_total / float(battles_played * setup.companions.size()), roundi(capped * 100.0 / (battles_played * setup.companions.size()))])
	check(by_two >= total * 0.75, "most companions' first grade-up comes within two battles (%d of %d)" % [by_two, total])


func test_prototype_data_simulation() -> void:
	var setup: BattleSetup = load("res://data/battles/prototype_battle.tres")
	check(setup != null and setup.companions.size() == 3 and setup.enemies.size() == 2, "prototype setup loads 3 v 2")
	var wins := 0
	var runs := 200
	for s in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var b := Battle.new(setup.companions, setup.enemies, rng, [] as Array[CompanionProgress], ArtLibrary.load_default().arts)
		var policy := RandomNumberGenerator.new()
		policy.seed = s + 1000
		play_random(b, policy)
		check(b.is_over(), "seed %d battle ends" % s)
		if b.outcome == Battle.Outcome.VICTORY:
			wins += 1
			for c in b.line():
				check(c.is_injured() == b.injured_ever.has(c) and (c.is_injured() or c.hp > 0), "after a victory the injured are exactly those who fell")
	print("  random-policy simulation: %d/%d victories" % [wins, runs])
