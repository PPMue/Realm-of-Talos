extends RefCounted
## Headless tests for the bestiary and the bosses: the battle mechanics they need (damage over time,
## reflection, enemy healing, reversed aim, countdown orders, recovery pressure, phases, stacking and
## no-repeat actions), each boss's signature, the boss draw, the bands, and the content itself.
## Called from run_tests.gd, which owns check(), eq() and the battle helpers.

var t   # the runner (run_tests.gd)

const BOSS_DAYS: Array[int] = [14, 28, 42]


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_poison_damage_each_tick,
		test_poison_injures_but_never_removes,
		test_poison_cleansed_by_white_magic,
		test_reflection_on_strikes_and_arts_not_spells,
		test_enemy_self_heal_and_all_allies,
		test_reversed_targeting_distribution,
		test_countdown_orders_floor_of_one,
		test_recovery_pressure,
		test_phase_switch_on_hp,
		test_phase_switch_when_last_standing,
		test_stacking_effect,
		test_no_repeat_action,
		test_boss_horned_tyrant_grows,
		test_boss_mossback_troll_regenerates,
		test_boss_rampart_golem_armour,
		test_boss_rimeclaw_wyvern_takes_wing,
		test_boss_oathbreaker_shield,
		test_boss_fallen_commander,
		test_boss_faceless_princess,
		test_boss_forsaken_seraph,
		test_boss_eclipse_sovereign,
		test_boss_draw,
		test_bands_by_day,
		test_flying_enemies,
		test_bestiary_content,
	]


# ---------------------------------------------------------------- helpers

func fx(n: String, o: Dictionary = {}) -> StatusEffectData:
	var e := StatusEffectData.new()
	e.display_name = n
	var mods: Dictionary = o.get("mods", {})
	e.stat_mods = mods
	e.damage_taken_mult = o.get("taken", 1.0)
	e.duration_ticks = o.get("dur", 3)
	e.damage_per_tick = o.get("dot", 0)
	e.reflect_percent = o.get("reflect", 0)
	e.max_stacks = o.get("stacks", 1)
	return e


func support(n: String, cd: int, targeting: EnemyActionData.Targeting) -> EnemyActionData:
	var a: EnemyActionData = t.make_action(n, cd, targeting, 0)
	a.deals_damage = false
	a.intent = EnemyActionData.Intent.BUFF
	return a


func cs(n: int, hp: int = 100) -> Array[CompanionData]:
	var out: Array[CompanionData] = []
	for i in n:
		out.append(t.make_companion("C%d" % i, hp))
	return out


func es(list: Array) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	out.assign(list)
	return out


func boss(file: String) -> EnemyData:
	return load("res://data/enemies/bosses/%s.tres" % file)


func action_named(e: EnemyData, n: String, phase_list: bool = false) -> EnemyActionData:
	for a in (e.phase_actions if phase_list else e.actions):
		if a.display_name == n:
			return a
	return null


## Lets ticks pass (guarding when someone is ready) until `done` returns true or `limit` ticks.
func pass_ticks(b: Battle, limit: int, done: Callable = Callable()) -> void:
	for i in limit:
		if b.is_over() or (done.is_valid() and done.call()):
			return
		var ready := b.ready_companions()
		if ready.is_empty():
			b.wait()
		else:
			b.guard(ready[0])


func events_of(b: Battle, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in b.events:
		if ev.type == type:
			out.append(ev)
	return out


func make_run(seed_value: int) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


## Every normal enemy in the content, by display name.
func normal_enemies() -> Dictionary:
	var by_name := {}
	for g in RunContent.load_default().groups:
		for e in g.enemies:
			by_name[e.display_name] = e
	return by_name


# ---------------------------------------------------------------- damage over time

func test_poison_damage_each_tick() -> void:
	var poison := fx("Poison", {"dot": 3, "dur": 3})
	var b: Battle = t.make_battle(cs(2), t.one_enemy(t.idle_enemy()))
	var c := b.roster[1]
	b._apply_effect(c, poison, false)
	t.check(b.roster[0].effects.is_empty(), "only the target is poisoned")
	b.guard(b.roster[0])
	t.eq(c.hp, 100 - 3, "3 at the end of the first tick")
	t.check(not events_of(b, "dot").is_empty(), "a dot event for playback")
	b.guard(c)
	t.eq(c.hp, 100 - 6, "3 more at the end of the second tick")
	b.wait() if b.can_wait() else b.guard(b.ready_companions()[0])
	t.eq(c.hp, 100 - 9, "the third tick")
	t.check(not c.has_effect("Poison"), "worn off after its 3 ticks")
	pass_ticks(b, 2)
	t.eq(c.hp, 100 - 9, "no more damage once it wore off")
	# Guard and damage reduction do not change it; it is not doubled by stacking names.
	var b2: Battle = t.make_battle(cs(1), t.one_enemy(t.idle_enemy()))
	var c2 := b2.roster[0]
	b2._apply_effect(c2, poison, false)
	b2.guard(c2)
	t.eq(c2.hp, 100 - 3, "Guard does not halve poison")
	b2._apply_effect(c2, poison, false)
	t.eq(c2.effects.size(), 1, "re-poisoning refreshes rather than stacks")
	# Enemies can be poisoned too, and die of it.
	var b3: Battle = t.make_battle(cs(1), t.one_enemy(t.idle_enemy(5)))
	b3._apply_effect(b3.enemies[0], fx("Poison", {"dot": 5}), false)
	b3.guard(b3.roster[0])
	t.check(not b3.enemies[0].is_alive(), "poison kills an enemy")
	t.eq(b3.outcome, Battle.Outcome.VICTORY, "and that can win the battle")


func test_poison_injures_but_never_removes() -> void:
	var b: Battle = t.make_battle(cs(2, 4), t.one_enemy(t.idle_enemy()))
	var c := b.roster[1]
	b._apply_effect(c, fx("Poison", {"dot": 5, "dur": 5}), false)
	b.guard(b.roster[0])
	t.check(c.is_injured(), "poison can injure")
	t.check(b.injured_ever.has(c), "recorded as injured")
	pass_ticks(b, 3)
	t.check(c.is_injured(), "still injured, nothing worse")
	t.eq(c.hp, 0, "and takes no more HP once injured")
	t.eq(c.effects.size(), 0, "the poison ended with the injury")
	# The last active companion falling to poison loses the battle.
	var b2: Battle = t.make_battle(cs(1, 3), t.one_enemy(t.idle_enemy()))
	b2._apply_effect(b2.roster[0], fx("Poison", {"dot": 5}), false)
	b2.guard(b2.roster[0])
	t.eq(b2.outcome, Battle.Outcome.DEFEAT, "all injured by poison is a defeat")


func test_poison_cleansed_by_white_magic() -> void:
	var purify := SpellData.new()
	purify.display_name = "Purify"
	purify.school = SpellData.School.WHITE
	purify.tier = 1
	purify.targeting = SpellData.Targeting.ONE_ALLY
	purify.cleanse = true
	purify.uses = 6
	purify.recovery = 1
	var b := Battle.new(cs(2), t.one_enemy(t.idle_enemy()), t.make_rng(1))
	for c in b.roster:
		c.progress.learn_spell(purify)
	var poison := fx("Poison", {"dot": 3, "dur": 5})
	t.check(poison.is_harmful(), "poison counts as a debuff")
	b._apply_effect(b.roster[1], poison, false)
	t.check(b.cast(b.roster[0], purify, b.roster[1]), "cast Purify")
	t.check(not b.roster[1].has_effect("Poison"), "Purify clears poison")
	t.eq(b.roster[1].hp, 100, "cleared before it struck")


# ---------------------------------------------------------------- reflection

func test_reflection_on_strikes_and_arts_not_spells() -> void:
	var thorns := fx("Thorns", {"reflect": 50, "dur": 99})
	var e: EnemyData = t.idle_enemy(999)
	var b: Battle = t.make_battle(cs(3), t.one_enemy(e))
	var foe := b.enemies[0]
	b._apply_effect(foe, thorns, true)
	var c := b.roster[2]
	var f := b.forecast(c, foe)
	t.eq(f.damage, 15, "STR 10 + Mt 5")
	t.eq(f.reflect, 7, "forecast: half of 15, rounded down")
	t.eq(f.reflect_crit, 15, "forecast for a critical hit")
	t.check(b.attack(c, foe), "attack")
	t.eq(foe.hp, 999 - 15, "dealt 15")
	t.eq(c.hp, 100 - 7, "took 7 back")
	t.check(not events_of(b, "reflect").is_empty(), "a reflect event")
	# A combat art that strikes twice is reflected on every strike that lands.
	var art: CombatArtData = t.make_art("Twice", 1, 1, 1, 0)
	art.strikes = 2
	var c1 := b.roster[1]
	t.give_art(c1, art)
	t.check(b.use_art(c1, art, foe), "art")
	t.eq(c1.hp, 100 - 14, "two strikes, 7 back each")
	# Spells are never reflected.
	var bolt := SpellData.new()
	bolt.display_name = "Bolt"
	bolt.school = SpellData.School.BLACK
	bolt.targeting = SpellData.Targeting.ONE_ENEMY
	bolt.might = 10
	bolt.hit = 999
	bolt.uses = 6
	bolt.recovery = 1
	var c0 := b.roster[0]
	c0.progress.learn_spell(bolt)
	var hp_before := foe.hp
	t.check(b.cast(c0, bolt, foe), "cast")
	t.check(foe.hp < hp_before, "the spell hurt it")
	t.eq(c0.hp, 100, "a spell is not reflected")
	t.eq(events_of(b, "reflect").size(), 0, "no reflect event for a spell")
	# Nothing is reflected without the effect, and a reflected blow can injure the striker.
	var b2: Battle = t.make_battle(cs(2, 5), t.one_enemy(t.idle_enemy(999)))
	t.eq(b2.forecast(b2.roster[1], b2.enemies[0]).reflect, 0, "no reflection without the effect")
	b2._apply_effect(b2.enemies[0], fx("Mirror", {"reflect": 100, "dur": 99}), true)
	b2.attack(b2.roster[1], b2.enemies[0])
	t.check(b2.roster[1].is_injured(), "a blow reflected in full injures a 5 HP striker")


# ---------------------------------------------------------------- healing

func test_enemy_self_heal_and_all_allies() -> void:
	var regen := support("Regen", 1, EnemyActionData.Targeting.SELF)
	regen.heal_percent = 25
	var acts: Array[EnemyActionData] = [regen]
	var b: Battle = t.make_battle(cs(1), es([t.make_enemy("Troll", acts, 200), t.idle_enemy(100)]))
	var troll := b.enemies[0]
	troll.hp = 100
	b.enemies[1].hp = 50
	b.guard(b.roster[0])
	t.eq(troll.hp, 150, "heals 25% of its max HP")
	t.eq(b.enemies[1].hp, 50, "only itself")
	t.check(not events_of(b, "enemy_heal").is_empty(), "an enemy_heal event")
	troll.hp = 190
	b.wait() if b.can_wait() else b.guard(b.ready_companions()[0])
	t.eq(troll.hp, 200, "never above max HP")
	# Every ally: each heals its own share, and an effect lands on each.
	var mend := support("Mend All", 1, EnemyActionData.Targeting.ALL_ALLIES)
	mend.heal_percent = 10
	mend.effect = fx("Barkskin", {"mods": {"DEF": 3}})
	var acts2: Array[EnemyActionData] = [mend]
	var b2: Battle = t.make_battle(cs(1), es([t.make_enemy("Tree", acts2, 100), t.idle_enemy(300)]))
	b2.enemies[0].hp = 50
	b2.enemies[1].hp = 100
	b2.guard(b2.roster[0])
	t.eq(b2.enemies[0].hp, 60, "the actor heals 10 of 100")
	t.eq(b2.enemies[1].hp, 130, "its ally heals 30 of 300")
	t.eq(b2.enemies[1].stat(Stat.DEF), 3, "and gains the buff")


# ---------------------------------------------------------------- reversed targeting

func test_reversed_targeting_distribution() -> void:
	var b: Battle = t.make_battle(t.three_companions(), t.one_enemy(t.idle_enemy()), 4242)
	t.eq(b.target_weights(true), [4.0, 2.0, 1.0] as Array[float], "mirrored weights")
	var counts := [0, 0, 0]
	var n := 14000
	for i in n:
		counts[b.line().find(b.pick_target(true))] += 1
	var expected := [4.0 / 7.0, 2.0 / 7.0, 1.0 / 7.0]
	for i in 3:
		var share: float = counts[i] / float(n)
		t.check(absf(share - expected[i]) < 0.015, "reversed slot %d share %.3f ~ %.3f" % [i, share, expected[i]])
	# Guard does not draw the aim, mirrored or not.
	b.roster[2].add_effect(StatusEffect.guard())
	t.eq(b.target_weights(true), [4.0, 2.0, 1.0] as Array[float], "guarding the rightmost changes nothing")
	# An enemy with reversed targeting aims its single attacks this way, in a real battle.
	var hit: EnemyActionData = t.make_action("Stab", 1, EnemyActionData.Targeting.SINGLE, 1)
	var acts: Array[EnemyActionData] = [hit]
	var e: EnemyData = t.make_enemy("Princess", acts, 9999)
	e.reversed_targeting = true
	var hits := [0, 0, 0]
	for s in 300:
		var b2: Battle = t.make_battle(t.three_companions(9999), t.one_enemy(e), 100 + s)
		b2.wait() if b2.can_wait() else b2.guard(b2.roster[0])
		for ev in events_of(b2, "damage"):
			if ev.target is CompanionUnit:
				hits[b2.roster.find(ev.target)] += 1
	t.check(hits[0] > hits[1] and hits[1] > hits[2], "the leftmost is hit most: %s" % str(hits))
	# And an action can be reversed on its own.
	var e2: EnemyData = t.make_enemy("Assassin", [t.make_action("Rend", 1)] as Array[EnemyActionData], 9999)
	e2.actions[0].reversed_targeting = true
	var b3: Battle = t.make_battle(t.three_companions(), t.one_enemy(e2))
	t.check(b3.enemies[0].aims_reversed(e2.actions[0]), "an action marked reversed aims reversed")
	t.check(e2.ever_reversed(), "and the enemy says so")


# ---------------------------------------------------------------- countdown orders

func test_countdown_orders_floor_of_one() -> void:
	var order := support("Advance!", 1, EnemyActionData.Targeting.SELF)
	order.hasten_allies = 3
	var cmd: EnemyData = t.make_enemy("Commander", [order] as Array[EnemyActionData], 999)
	var slow: EnemyData = t.make_enemy("Slow", [t.make_action("Big", 6)] as Array[EnemyActionData], 999)
	var near: EnemyData = t.make_enemy("Near", [t.make_action("Soon", 3)] as Array[EnemyActionData], 999)
	var b: Battle = t.make_battle(cs(3, 999), es([cmd, slow, near]))
	b.guard(b.roster[0])
	# Tick: everyone -1 (6 -> 5, 3 -> 2); the commander acts: 5 -> 2, 2 -> 1 (not below 1).
	t.eq(b.enemies[1].countdown, 2, "lowered by 3")
	t.eq(b.enemies[2].countdown, 1, "never below 1")
	t.check(b.enemies[1].hastened and b.enemies[2].hastened, "marked as hastened")
	t.eq(events_of(b, "hasten").size(), 2, "a hasten event for each")
	t.eq(b.enemies[0].countdown, 1, "the commander does not order itself (it picked again)")
	b.guard(b.roster[1])
	# Now the slow one is at 1 after the tick... its countdown 2 -> 1, the order cannot lower 1.
	t.eq(b.enemies[1].countdown, 1, "an enemy at 1 stays at 1")
	t.check(not events_of(b, "hasten").any(func(ev: Dictionary) -> bool: return ev.target == b.enemies[1]),
		"no event when nothing was lowered")
	# The mark clears with the next action.
	b.guard(b.roster[2])
	t.check(not b.enemies[1].hastened or b.enemies[1].countdown < 6, "cleared when it picks again")


# ---------------------------------------------------------------- recovery pressure

func test_recovery_pressure() -> void:
	var stare := support("Stare", 1, EnemyActionData.Targeting.ALL_COMPANIONS)
	stare.intent = EnemyActionData.Intent.DEBUFF
	stare.add_recovery = 2
	var e: EnemyData = t.make_enemy("Clock", [stare] as Array[EnemyActionData], 999)
	var b: Battle = t.make_battle(cs(3, 99), t.one_enemy(e))
	var actor := b.roster[0]
	t.check(b.guard(actor), "guard (recovery 2)")
	t.eq(actor.recovery, 2 + 2, "the actor: its own recovery plus 2, uncapped")
	t.eq(b.roster[1].recovery, 2 - 1, "others: +2, then this tick's countdown")
	t.eq(b.roster[2].recovery, 1, "every companion")
	t.eq(events_of(b, "recovery").size(), 3, "a recovery event for each")
	# A landed single hit adds it too; injured companions are left alone.
	var gaze: EnemyActionData = t.make_action("Gaze", 1, EnemyActionData.Targeting.SINGLE, 1)
	gaze.add_recovery = 3
	var b2: Battle = t.make_battle(cs(2, 99), t.one_enemy(t.make_enemy("Eye", [gaze] as Array[EnemyActionData], 999)), 7)
	t.set_injured(b2.roster[0])
	b2.roster[0].state = CompanionUnit.State.INJURED
	b2.guard(b2.roster[1])
	t.eq(b2.roster[1].recovery, 2 + 3, "hit and held: 2 of its own and 3 from the enemy")
	t.eq(b2.roster[0].recovery, 0, "the injured one gains none")
	# A companion standing alone is held like any other: the party waits.
	t.check(b2.is_lone_companion(b2.roster[1]), "alone")
	t.check(not b2.can_act(b2.roster[1]), "a companion standing alone is held too")
	t.check(b2.can_wait(), "so the party waits")


# ---------------------------------------------------------------- phases

func test_phase_switch_on_hp() -> void:
	var calm: EnemyActionData = t.make_action("Calm", 5)
	var fury: EnemyActionData = t.make_action("Fury", 2)
	var e: EnemyData = t.make_enemy("Sovereign", [calm] as Array[EnemyActionData], 100)
	e.phase_trigger = EnemyData.PhaseTrigger.HP_BELOW
	e.phase_hp_percent = 50
	e.phase_actions = [fury] as Array[EnemyActionData]
	e.phase_title = "TOTAL ECLIPSE"
	e.phase_effect = fx("Totality", {"mods": {"SPD": 4}, "dur": 99})
	var weak: WeaponData = t.make_weapon(40)
	var cs1: Array[CompanionData] = [t.make_companion("A", 500, 0, weak), t.make_companion("B", 500, 0, weak)]
	var b: Battle = t.make_battle(cs1, t.one_enemy(e))
	var boss_unit := b.enemies[0]
	t.eq(boss_unit.pending_action, calm, "first list")
	b.attack(b.roster[0], boss_unit)   # 50 damage: 100 -> 50, the threshold
	t.eq(boss_unit.phase, 1, "switched at 50%")
	t.eq(boss_unit.pending_action, fury, "the pending action is replaced from the new list")
	t.eq(boss_unit.countdown, 2 - 1, "with the new action's countdown, then the tick")
	var phase_events := events_of(b, "phase")
	t.eq(phase_events.size(), 1, "announced once")
	t.eq(phase_events[0].title, "TOTAL ECLIPSE", "with its title")
	t.check(boss_unit.has_effect("Totality"), "its phase effect")
	t.eq(boss_unit.stat(Stat.SPD), 4, "SPD +4")
	b.attack(b.roster[1], boss_unit)
	t.eq(events_of(b, "phase").size(), 0, "never again")
	# Above the threshold, nothing happens.
	var b2: Battle = t.make_battle(cs(1), t.one_enemy(e))
	b2.enemies[0].hp = 100
	b2.attack(b2.roster[0], b2.enemies[0])
	t.eq(b2.enemies[0].phase, 0, "15 damage leaves it above half")


func test_phase_switch_when_last_standing() -> void:
	var order: EnemyActionData = t.make_action("Order", 5)
	var last: EnemyActionData = t.make_action("Last Stand Blow", 2)
	var cmd: EnemyData = t.make_enemy("Commander", [order] as Array[EnemyActionData], 500)
	cmd.phase_trigger = EnemyData.PhaseTrigger.LAST_STANDING
	cmd.phase_actions = [last] as Array[EnemyActionData]
	var b: Battle = t.make_battle(cs(2, 500), es([cmd, t.idle_enemy(10), t.idle_enemy(10)]))
	b.attack(b.roster[0], b.enemies[1])
	t.eq(b.enemies[0].phase, 0, "one escort left: not yet")
	b.attack(b.roster[1], b.enemies[2])
	t.eq(b.enemies[0].phase, 1, "alone: the phase begins")
	t.eq(b.enemies[0].pending_action, last, "its new list")


func test_stacking_effect() -> void:
	var b: Battle = t.make_battle(cs(1), t.one_enemy(t.idle_enemy()))
	var e := b.enemies[0]
	var rage := fx("Enraged", {"mods": {"STR": 3}, "stacks": 3, "dur": 99})
	for i in 5:
		b._apply_effect(e, rage, true)
	t.eq(e.effects.size(), 1, "one effect")
	t.eq(e.get_effect("Enraged").stacks, 3, "capped at 3 stacks")
	t.eq(e.stat(Stat.STR), 10 + 9, "STR +3 per stack")
	b._apply_effect(e, fx("Shell", {"taken": 0.5}), true)
	b._apply_effect(e, fx("Shell", {"taken": 0.5}), true)
	t.eq(e.get_effect("Shell").stacks, 1, "an effect that does not stack only refreshes")


func test_no_repeat_action() -> void:
	var stance := support("Stance", 1, EnemyActionData.Targeting.SELF)
	stance.no_repeat = true
	stance.pick_weight = 100.0
	var hit: EnemyActionData = t.make_action("Hit", 1, EnemyActionData.Targeting.SINGLE, 1, 1.0)
	var e: EnemyData = t.make_enemy("Knight", [stance, hit] as Array[EnemyActionData], 999)
	var b: Battle = t.make_battle(cs(2, 9999), t.one_enemy(e), 3)
	var u := b.enemies[0]
	var previous: EnemyActionData = null
	for i in 60:
		var acting := u.pending_action if u.countdown == 1 else null
		pass_ticks(b, 1)
		if acting != null:
			if previous == stance:
				t.check(acting != stance, "never the stance twice in a row")
			previous = acting
	# With only a no_repeat action, it still repeats rather than doing nothing.
	var b2: Battle = t.make_battle(cs(1, 9999), t.one_enemy(t.make_enemy("Solo", [stance] as Array[EnemyActionData], 999)))
	pass_ticks(b2, 3)
	t.eq(b2.enemies[0].pending_action, stance, "falls back to the only action")


# ---------------------------------------------------------------- bosses

func test_boss_horned_tyrant_grows() -> void:
	var tyrant := boss("horned_tyrant")
	var bellow := action_named(tyrant, "War Bellow")
	t.check(bellow != null and bellow.effect.max_stacks > 1 and bellow.effect.duration_ticks >= 99,
		"its bellow stacks and lasts the battle")
	var b: Battle = t.make_battle(cs(1, 999), t.one_enemy(tyrant))
	var u := b.enemies[0]
	var before := u.stat(Stat.STR)
	for i in 3:
		b._apply_effect(u, bellow.effect, true)
	t.eq(u.stat(Stat.STR), before + 3 * int(bellow.effect.stat_mods["STR"]), "three bellows, three times stronger")


func test_boss_mossback_troll_regenerates() -> void:
	var troll := boss("mossback_troll")
	var regen: EnemyActionData = null
	for a in troll.actions:
		if a.heal_percent > 0:
			regen = a
	t.check(regen != null and regen.targeting == EnemyActionData.Targeting.SELF, "a self heal")
	t.check(regen.intent == EnemyActionData.Intent.BUFF, "shown as a Buff")
	t.check(regen.heal_percent >= 15, "a large share")
	var b: Battle = t.make_battle(cs(1, 999), t.one_enemy(troll))
	var u := b.enemies[0]
	u.hp = 50
	b.perform_enemy_action(u, regen)
	t.eq(u.hp, 50 + ceili(troll.max_hp * regen.heal_percent / 100.0), "heals its share")


func test_boss_rampart_golem_armour() -> void:
	var golem := boss("rampart_golem")
	t.check(golem.defense >= boss("horned_tyrant").defense + 4 and golem.resistance <= 2, "very high DEF, low RES")
	t.check(golem.speed <= 3, "slow")
	var shortest := 99
	for a in golem.actions:
		if a.intent == EnemyActionData.Intent.ATTACK:
			shortest = mini(shortest, a.countdown)
	t.check(shortest >= 4, "long countdowns on its blows")
	var brace: EnemyActionData = null
	for a in golem.actions:
		if a.intent == EnemyActionData.Intent.DEFEND:
			brace = a
	t.check(brace != null and brace.effect.damage_taken_mult < 1.0, "a brace that cuts damage taken")
	var b: Battle = t.make_battle(cs(1), t.one_enemy(golem))
	var c := b.roster[0]
	var plain := b.forecast(c, b.enemies[0]).damage
	var art: CombatArtData = t.make_art("Pierce", 1, 1, 1, 0)
	art.ignore_def_percent = 100
	t.check(b.forecast(c, b.enemies[0], art).damage > plain + 10, "a DEF-ignoring art gets through")


func test_boss_rimeclaw_wyvern_takes_wing() -> void:
	var wyvern := boss("rimeclaw_wyvern")
	t.check(wyvern.traits.has(EnemyTraits.FLYING), "flying")
	for n in ["Frost Lance", "Blizzard", "Glacier Shell"]:
		t.check(action_named(wyvern, n) != null, "has the Frostfang move %s" % n)
	var wing := action_named(wyvern, "Take Wing")
	t.check(wing != null and wing.intent == EnemyActionData.Intent.DEFEND, "a Defend stance")
	var plain: Array[CompanionData] = [t.make_companion("Swordsman", 50, 0, t.make_weapon(5, 80))]
	var b: Battle = t.make_battle(plain, t.one_enemy(wyvern))
	var before := b.forecast(b.roster[0], b.enemies[0]).hit
	b.perform_enemy_action(b.enemies[0], wing)
	var after := b.forecast(b.roster[0], b.enemies[0]).hit
	t.check(after <= before - 30 or after == BattleConfig.ACCURACY_MIN, "much harder to hit (%d -> %d)" % [before, after])
	var bow: WeaponData = t.make_weapon(6, 90, 0, WeaponData.WeaponType.BOW)
	bow.effective_against = [EnemyTraits.FLYING] as Array[String]
	var archer: Array[CompanionData] = [t.make_companion("Archer", 50, 0, bow)]
	var b2: Battle = t.make_battle(archer, t.one_enemy(wyvern))
	t.check(b2.forecast(b2.roster[0], b2.enemies[0]).effective, "bows are effective")


func test_boss_oathbreaker_shield() -> void:
	var oath := boss("oathbreaker")
	for n in ["Oathbreaker's Cleave", "Black Tide", "Curse of Ruin", "Dark Pact"]:
		t.check(action_named(oath, n) != null, "keeps %s" % n)
	var shield := action_named(oath, "Oath of Thorns")
	t.check(shield != null and shield.intent == EnemyActionData.Intent.DEFEND, "a Defend stance")
	t.check(shield.effect.reflect_percent > 0, "that reflects")
	var b: Battle = t.make_battle(cs(2, 999), t.one_enemy(oath))
	var u := b.enemies[0]
	b.perform_enemy_action(u, shield)
	t.check(b.forecast(b.roster[1], u).reflect > 0, "the forecast warns of the cost")
	b.attack(b.roster[1], u)
	var hurt := b.roster[1].hp < 999 or events_of(b, "miss").size() > 0
	t.check(hurt, "striking into the shield hurts (or missed)")


func test_boss_fallen_commander() -> void:
	var group: EnemyGroupData = load("res://data/run/bosses/fallen_commander.tres")
	t.eq(group.escorts().size(), 2, "two escorts")
	for e in group.escorts():
		t.eq(e.band, 2, "%s is from the middle band" % e.display_name)
	var cmd := group.boss()
	var rally: EnemyActionData = null
	var press: EnemyActionData = null
	for a in cmd.actions:
		if a.targeting == EnemyActionData.Targeting.ALL_ALLIES:
			rally = a
		if a.hasten_allies > 0:
			press = a
	t.check(rally != null and rally.effect != null, "buffs every enemy")
	t.check(press != null, "orders the escorts to act sooner")
	t.eq(cmd.phase_trigger, EnemyData.PhaseTrigger.LAST_STANDING, "changes when alone")
	var run := make_run(9)
	run.day = 28
	run.boss_draw[28] = group
	run.calendar[27] = RunCalendar.DayType.BOSS
	run._begin_day()
	var f := run.fronts[0]
	t.eq(f.enemies.size(), 3, "the front fields the boss and its escorts")
	t.check(f.enemies[1].max_hp > group.enemies[1].max_hp, "escorts grow with the day")
	var b := Battle.new(cs(2, 999), f.enemies, t.make_rng(2))
	b.enemies[1].hp = 0
	b.enemies[2].hp = 1
	b._after_enemy_hurt(b.enemies[1])
	b.enemies[2].hp = 0
	b._after_enemy_hurt(b.enemies[2])
	t.eq(b.enemies[0].phase, 1, "the last stand")
	t.check(b.enemies[0].stat(Stat.STR) > cmd.strength, "more dangerous")


func test_boss_faceless_princess() -> void:
	var princess := boss("faceless_princess")
	t.check(princess.reversed_targeting, "reversed targeting")
	var poisons := false
	for a in princess.actions:
		if a.effect != null and a.effect.damage_per_tick > 0:
			poisons = true
	t.check(poisons, "poisons")
	var b: Battle = t.make_battle(t.three_companions(999), t.one_enemy(princess))
	var counts := [0, 0, 0]
	for i in 7000:
		counts[b.line().find(b.pick_target(b.enemies[0].aims_reversed(princess.actions[0])))] += 1
	t.check(counts[0] > counts[1] and counts[1] > counts[2], "the leftmost is aimed at most: %s" % str(counts))


func test_boss_forsaken_seraph() -> void:
	var seraph := boss("forsaken_seraph")
	t.check(seraph.traits.has(EnemyTraits.FLYING), "flying")
	var charge: EnemyActionData = null
	for a in seraph.actions:
		if a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS:
			charge = a
	t.check(charge != null and charge.damage_type == CombatMath.DamageType.MAGIC, "a magic strike on everyone")
	for a in seraph.actions:
		if a != charge:
			t.check(a.countdown < charge.countdown and a.might < charge.might, "%s is smaller and quicker" % a.display_name)
			t.eq(a.damage_type, CombatMath.DamageType.MAGIC, "%s is magic" % a.display_name)
	t.check(charge.countdown >= 6 and charge.no_repeat, "a long charge, never twice in a row")
	# A delay spell can push the charge back once.
	var b: Battle = t.make_battle(cs(2, 999), t.one_enemy(seraph))
	var u := b.enemies[0]
	u.pending_action = charge
	u.countdown = charge.countdown
	t.check(b.delay_action(u, 2), "the charge can be delayed")
	t.eq(u.countdown, charge.countdown + 2, "pushed back")


func test_boss_eclipse_sovereign() -> void:
	var eclipse := boss("eclipse_sovereign")
	var pressure := false
	for a in eclipse.actions:
		if a.add_recovery > 0 and a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS:
			pressure = true
	t.check(pressure, "lengthens every companion's recovery")
	t.eq(eclipse.phase_trigger, EnemyData.PhaseTrigger.HP_BELOW, "a second phase by HP")
	t.eq(eclipse.phase_hp_percent, 50, "at half health")
	var fastest_1 := 99
	var fastest_2 := 99
	for a in eclipse.actions:
		fastest_1 = mini(fastest_1, a.countdown)
	for a in eclipse.phase_actions:
		fastest_2 = mini(fastest_2, a.countdown)
	t.check(fastest_2 < fastest_1, "the second list is faster")
	var b: Battle = t.make_battle(cs(2, 999), t.one_enemy(eclipse))
	var u := b.enemies[0]
	u.hp = u.max_hp() / 2 + 1
	b.attack(b.roster[1], u)
	if u.hp * 2 <= u.max_hp():
		t.eq(u.phase, 1, "below half: the second phase")
		t.check(eclipse.phase_actions.has(u.pending_action), "acting from the second list")


# ---------------------------------------------------------------- the boss draw

func test_boss_draw() -> void:
	var rc := RunContent.load_default()
	for d in BOSS_DAYS:
		t.eq(rc.bosses_for(d).size(), 3, "three bosses can come on day %d" % d)
	t.eq(rc.bosses_for(15).size(), 0, "none on other days")
	var seen := {}
	for s in 120:
		var run := make_run(7000 + s)
		var again := make_run(7000 + s)
		for d in BOSS_DAYS:
			var g: EnemyGroupData = run.boss_draw.get(d)
			t.check(g != null and rc.bosses_for(d).has(g), "seed %d: day %d draws from its own pool" % [s, d])
			t.eq(again.boss_draw.get(d), g, "seed %d: the same seed draws the same boss" % s)
			seen[g] = true
	t.eq(seen.size(), 9, "all nine bosses are reachable")
	# The boss front fights the boss that was drawn.
	var run := make_run(31)
	run.day = 14
	run.calendar[13] = RunCalendar.DayType.BOSS
	run._begin_day()
	t.eq(run.fronts[0].group, run.boss_on(14), "the day 14 front is the drawn boss")
	t.eq(run.boss_days_ahead(), [14] as Array[int], "without the Watchtower: only today's boss")
	run.facilities[Run.Facility.WATCHTOWER] = 1
	t.eq(run.boss_days_ahead(), [14, 28, 42] as Array[int], "with it: every boss day ahead")
	t.check(not rc.bosses.any(func(g: EnemyGroupData) -> bool: return g.display_name == "Frostfang Warden"),
		"the Frostfang Warden is retired")
	for g in rc.bosses:
		t.check(g.description != "", "%s has a one-line description" % g.display_name)
		t.eq(g.boss().band, 0, "%s is a boss" % g.display_name)


# ---------------------------------------------------------------- bands

const EARLY: Array[String] = ["Orc", "Goblin Thief", "Goblin Wizard", "Stalker", "Skeleton Bird", "Winged Zombie",
	"Slime Monster", "Briarwing"]
const MIDDLE: Array[String] = ["Cursed Warrior", "Armored Beast", "Blackwing", "Poisoned Wings", "Flame Eagle",
	"Poison Spawn", "One-Eye", "Ancient Treant"]
const LATE: Array[String] = ["Stormcrest", "Void Raven", "Shadowed Wings", "Faceless Spawn", "Cursed Dweller",
	"Forgotten Guardian"]


func test_bands_by_day() -> void:
	var rc := RunContent.load_default()
	var all := normal_enemies()
	for n in EARLY:
		t.check(all.has(n) and all[n].band == 1, "%s is early" % n)
	for n in MIDDLE:
		t.check(all.has(n) and all[n].band == 2, "%s is middle" % n)
	for n in LATE:
		t.check(all.has(n) and all[n].band == 3, "%s is late" % n)
	t.eq(Run.band_of_day(1), 1, "day 1 early")
	t.eq(Run.band_of_day(14), 1, "day 14 (end of week 2) early")
	t.eq(Run.band_of_day(15), 2, "day 15 (week 3) middle")
	t.eq(Run.band_of_day(28), 2, "day 28 (end of week 4) middle")
	t.eq(Run.band_of_day(29), 3, "day 29 (week 5) late")
	t.eq(Run.band_of_day(42), 3, "day 42 late")
	# No group fields an enemy before its band begins.
	for g in rc.groups:
		t.check(g.min_day >= RunConfig.BAND_FIRST_DAY[maxi(1, g.band()) - 1], "%s waits for its band" % g.display_name)
	# What the fronts actually field, day by day, over many runs.
	var seen_by_band := [{}, {}, {}]
	var four := 0
	for s in 40:
		var run := make_run(9000 + s)
		for d in range(1, RunConfig.DAYS):
			if RunCalendar.is_boss_day(d):
				continue
			run.day = d
			run.calendar[d - 1] = RunCalendar.DayType.BATTLE
			run._begin_day()
			for f in run.fronts:
				if f.enemies.size() >= 4:
					four += 1
					t.check(d >= RunConfig.BAND_FIRST_DAY[1], "four enemies only from the middle band on (day %d)" % d)
				for e in f.group.enemies:
					t.check(e.band <= Run.band_of_day(d), "day %d: %s is not from a later band" % [d, e.display_name])
					seen_by_band[Run.band_of_day(d) - 1][e.display_name] = true
	for n in EARLY:
		t.check(seen_by_band[0].has(n), "%s fights in weeks 1-2" % n)
	for n in MIDDLE:
		t.check(seen_by_band[1].has(n), "%s fights in weeks 3-4" % n)
	for n in LATE:
		t.check(seen_by_band[2].has(n), "%s fights in weeks 5-6" % n)
	t.check(seen_by_band[2].has("Orc") or seen_by_band[2].has("Goblin Thief"), "early enemies still turn up late")
	t.check(four > 0, "four-enemy fronts appear")


func test_flying_enemies() -> void:
	var flying := ["Blackwing", "Briarwing", "Flame Eagle", "Poisoned Wings", "Stormcrest", "Void Raven",
		"Shadowed Wings", "Forgotten Guardian", "One-Eye", "Skeleton Bird", "Winged Zombie"]
	for e: EnemyData in normal_enemies().values():
		t.eq(e.traits.has(EnemyTraits.FLYING), flying.has(e.display_name), "%s flying" % e.display_name)
	t.check(boss("rimeclaw_wyvern").traits.has(EnemyTraits.FLYING), "Rimeclaw Wyvern flies")
	t.check(boss("forsaken_seraph").traits.has(EnemyTraits.FLYING), "Forsaken Seraph flies")
	for f in ["horned_tyrant", "mossback_troll", "rampart_golem", "oathbreaker", "fallen_commander",
			"faceless_princess", "eclipse_sovereign"]:
		t.check(not boss(f).traits.has(EnemyTraits.FLYING), "%s does not fly" % f)


func test_bestiary_content() -> void:
	var rc := RunContent.load_default()
	var everyone: Array[EnemyData] = []
	everyone.assign(normal_enemies().values())
	for g in rc.bosses:
		for e in g.enemies:
			if not everyone.has(e):
				everyone.append(e)
	var arts := {}
	for e in everyone:
		var n := e.display_name
		t.check(e.portrait != null, "%s has art" % n)
		if e.portrait != null:
			arts[e.portrait.resource_path] = true
		t.check(not e.actions.is_empty(), "%s has actions" % n)
		t.check(not n.to_lower().contains("wywern"), "%s: spelled wyvern" % n)
		t.check(e.max_hp >= 20 and e.max_hp <= 400, "%s HP %d" % [n, e.max_hp])
		t.check(e.strength >= 0 and e.strength <= 30 and e.magic <= 30, "%s STR/MAG sane" % n)
		t.check(e.defense >= 0 and e.defense <= 20 and e.resistance <= 20, "%s DEF/RES sane" % n)
		t.check(e.speed >= 0 and e.speed <= 25 and e.dexterity <= 25, "%s SPD/DEX sane" % n)
		t.check(e.stage_scale >= 0.8 and e.stage_scale <= 1.6, "%s stage scale" % n)
		var damaging := false
		for a in e.actions + e.phase_actions:
			t.check(a.countdown >= 1 and a.countdown <= 8, "%s: %s countdown" % [n, a.display_name])
			t.check(a.pick_weight > 0.0, "%s: %s can be picked" % [n, a.display_name])
			if a.deals_damage:
				damaging = true
				t.check(a.might > 0 and a.hit > 0, "%s: %s deals damage" % [n, a.display_name])
			else:
				t.check(a.effect != null or a.heal_percent > 0 or a.hasten_allies > 0 or a.add_recovery > 0,
					"%s: %s does something" % [n, a.display_name])
		t.check(damaging, "%s can hurt the party" % n)
		if e.band == 0:
			t.check(e.stage_scale >= 1.35, "%s stands large" % n)
	# Every enemy image is used.
	var dir := DirAccess.open("res://assets/enemy")
	for f in dir.get_files():
		if f.ends_with(".png"):
			t.check(arts.has("res://assets/enemy/" + f), "%s is used by an enemy" % f)
