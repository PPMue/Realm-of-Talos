extends RefCounted
## Headless tests for the masteries (design/callings.md, step 2): the twenty-four as data, each one's
## rule in a battle, and the run's side (due at RunConfig.MASTERY_LEVEL with a calling, taking one of
## the calling's two). Called from run_tests.gd, which owns check() and eq().

const RunRuleTests := preload("res://tests/run_rule_tests.gd")

var t   # the runner (run_tests.gd)
var rr: RunRuleTests
var lib: CallingLibrary


func _init(runner: Object) -> void:
	t = runner
	rr = RunRuleTests.new(runner)
	lib = CallingLibrary.load_default()


func tests() -> Array[Callable]:
	return [
		test_mastery_library,
		test_mastery_on_progress,
		test_mastery_warden,
		test_mastery_champion,
		test_mastery_executioner,
		test_mastery_skirmisher,
		test_mastery_captain,
		test_mastery_harrier,
		test_mastery_hunter,
		test_mastery_berserker,
		test_mastery_mender,
		test_mastery_hexer,
		test_mastery_sage,
		test_mastery_spellblade,
		test_mastery_in_a_run,
	]


# ---------------------------------------------------------------- helpers

func calling(id: String) -> CallingData:
	return lib.find(id)


## The mastery "warden:wide_shield" names.
func mastery(spec: String) -> MasteryData:
	var parts := spec.split(":")
	for m in calling(parts[0]).masteries:
		if m.id == "%s_%s" % [parts[0], parts[1]]:
			return m
	return null


## A battle of test companions (STR 10, DEX 10, a sword of Mt 5 that always hits, 30 stamina, a tier I
## art of Recovery 2), each holding what `specs` names: "" nothing, "warden" the calling alone,
## "warden:wide_shield" the calling with that mastery.
func battle(specs: Array, enemies: Array[EnemyData], hp: int = 40) -> Battle:
	var cs: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for i in specs.size():
		var d: CompanionData = t.make_companion("C%d" % i, hp)
		cs.append(d)
		var p := CompanionProgress.create(d)
		var spec: String = specs[i]
		if spec != "":
			p.calling = calling(spec.split(":")[0])
			p.calling_lead = Stat.STR
			if spec.contains(":"):
				t.check(p.take_mastery(mastery(spec)), "%s is taken" % spec)
		party.append(p)
	return t.make_battle(cs, enemies, 1, party)


## An enemy with one single blow that comes in `cd` turns (STR 10 + 5 against DEF 0: 15).
func foe(cd: int = 9, hp: int = 100) -> EnemyData:
	var acts: Array[EnemyActionData] = [t.make_action("Strike", cd, EnemyActionData.Targeting.SINGLE, 5)]
	return t.make_enemy("Foe", acts, hp)


func foes(n: int, cd: int = 9, hp: int = 100) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for i in n:
		out.append(foe(cd, hp))
	return out


func events_of(b: Battle, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in b.events:
		if ev.type == type:
			out.append(ev)
	return out


func spell(path: String) -> SpellData:
	return load("res://data/spells/%s.tres" % path) as SpellData


func level_to(run: Run, c: RunCompanion, level: int) -> void:
	while c.level() < level:
		Levels.level_up(c.progress, run.rng)


# ---------------------------------------------------------------- the data

func test_mastery_library() -> void:
	var ids := {}
	for c in lib.callings:
		t.eq(c.masteries.size(), 2, "%s: two masteries" % c.id)
		for m in c.masteries:
			ids[m.id] = true
			t.check(m.id.begins_with(c.id + "_"), "%s: named for its calling" % m.id)
			t.check(m.display_name != "" and m.rule != "", "%s: a name and a rule" % m.id)
			t.check(not m.rule.contains("\n") and m.rule.length() <= 80, "%s: the rule is one short line" % m.id)
			t.check(not m.modifiers.is_empty(), "%s: a rule the battle reads" % m.id)
	t.eq(ids.size(), 24, "twenty-four, no two sharing an id")
	t.eq(RunConfig.MASTERY_LEVEL, 8, "at level 8")


func test_mastery_on_progress() -> void:
	var p := CompanionProgress.create(rr.companion("elena"))
	var wide := mastery("warden:wide_shield")
	t.check(not p.take_mastery(wide), "no mastery without a calling")
	p.take_calling(calling("warden"))
	var alone := p.calling_effect().modifiers.size()
	t.check(not p.take_mastery(mastery("hunter:sure_shot")), "not another calling's")
	t.check(p.take_mastery(wide), "one of the Warden's two")
	t.eq(p.mastery, wide, "kept")
	t.check(not p.take_mastery(mastery("warden:answering_blow")), "only one")
	t.eq(p.calling_effect().modifiers.size(), alone + wide.modifiers.size(), "the rules read its line with the calling's")
	t.eq(p.calling_effect().gives.size(), 2, "two lines to show")
	t.check(TraitRules.has(p.all_traits(), TraitModifier.Kind.GUARD_ANYONE), "and find it among the traits")
	t.eq(p.copy().mastery, wide, "a copy keeps it")


# ---------------------------------------------------------------- the rules, one by one

func test_mastery_warden() -> void:
	# Wide Shield: anyone standing in the line, not only a neighbour.
	var b := battle(["warden:wide_shield", "", "", ""], foes(1, 1))
	var w := b.roster[0]
	var far := b.roster[3]
	t.eq(b.guard_wards(w).size(), 4, "themselves and all three others")
	t.eq(b.guard_wards(b.roster[1]).size(), 3, "anyone else: themselves and their neighbours")
	t.set_injured(b.roster[2])
	t.check(not b.guard_wards(w).has(b.roster[2]), "not someone injured")
	b.enemies[0].pending_target = far
	var hp := far.hp
	t.check(b.guard(w, far), "guards the far end of the line")
	t.eq(far.hp, hp, "the blow never reaches them")
	t.check(w.hp < w.max_hp(), "it lands on the Warden")
	t.eq(b.enemies[0].hp, 100, "and is not answered")
	var plain := battle(["warden", "", "", ""], foes(1, 1))
	t.eq(plain.guard_wards(plain.roster[0]).size(), 2, "without the mastery: themselves and one neighbour")
	t.check(not plain.guard(plain.roster[0], plain.roster[3]), "the far end is refused")
	# Answering Blow: a blow caught for another is answered with their Attack.
	var b2 := battle(["warden:answering_blow", ""], foes(1, 1))
	var w2 := b2.roster[0]
	var e := b2.enemies[0]
	e.pending_target = b2.roster[1]
	t.check(b2.guard(w2, b2.roster[1]), "guards their neighbour")
	t.eq(e.hp, 100 - 15, "the blow caught is answered: 15")
	t.eq(w2.recovery, 0, "it is no action of theirs")
	var answers := events_of(b2, "strike").filter(func(ev: Dictionary) -> bool: return bool(ev.get("answer", false)))
	t.eq(answers.size(), 1, "one answer shown")
	# A blow on the Warden themselves is not caught, so not answered.
	t.rest(b2)
	e.countdown = 1
	e.pending_target = w2
	b2.guard(w2)
	t.eq(e.hp, 85, "a blow aimed at them is not answered")
	# An answer can fell the enemy.
	var b3 := battle(["warden:answering_blow", ""], foes(2, 1))
	b3.enemies[0].hp = 10
	b3.enemies[0].pending_target = b3.roster[1]
	b3.enemies[1].pending_target = b3.roster[1]
	b3.guard(b3.roster[0], b3.roster[1])
	t.check(not b3.enemies[0].is_alive(), "the answer fells an enemy at 10")
	t.eq(b3.kills_of(b3.roster[0]), 1, "the kill is the Warden's")
	t.eq(b3.enemies[1].hp, 85, "and the second blow caught is answered too")


func test_mastery_champion() -> void:
	# Iron Stance: a quarter less from a blow they turned.
	var b := battle(["champion:iron_stance", "", ""], foes(2))
	var champ := b.roster[0]
	var e := b.enemies[0]
	var blow := e.pending_action
	e.pending_target = b.roster[2]
	b.enemies[1].pending_target = champ
	t.eq(b.enemy_forecast(e, blow, champ).damage, 15, "before it is turned: the whole blow")
	b.attack(champ, e)
	t.eq(e.pending_target, champ, "turned")
	t.eq(b.enemy_forecast(e, blow, champ).damage, 11, "a quarter less: 15 to 11")
	t.eq(b.enemy_forecast(b.enemies[1], b.enemies[1].pending_action, champ).damage, 15, "a blow they did not turn lands whole")
	t.eq(b.enemy_forecast(e, blow, b.roster[1]).damage, 15, "and it is theirs alone")
	t.eq(b.incoming(champ)[0].forecast.damage, 11, "what is coming says the same")
	b.pick_next_action(e)
	e.pending_target = champ
	t.eq(b.enemy_forecast(e, e.pending_action, champ).damage, 15, "the next blow is a new one")
	# A blow already on them that they strike counts as turned.
	t.rest(b)
	b.attack(champ, e)
	t.eq(b.enemy_forecast(e, e.pending_action, champ).damage, 11, "struck while already aimed at them: theirs")
	var plain := battle(["champion", ""], foes(1))
	plain.enemies[0].pending_target = plain.roster[1]
	plain.attack(plain.roster[0], plain.enemies[0])
	t.eq(plain.enemy_forecast(plain.enemies[0], plain.enemies[0].pending_action, plain.roster[0]).damage, 15, "without the mastery: whole")
	# First Challenge: when the battle begins, every blow already aimed is aimed at them.
	for s in 6:
		var cs: Array[CompanionData] = []
		var party: Array[CompanionProgress] = []
		for i in 4:
			cs.append(t.make_companion("C%d" % i, 40))
			party.append(CompanionProgress.create(cs[i]))
		party[1].calling = calling("champion")
		party[1].calling_lead = Stat.STR
		party[1].take_mastery(mastery("champion:first_challenge"))
		var b2: Battle = t.make_battle(cs, foes(3), 100 + s, party)
		for foe_unit in b2.enemies:
			t.eq(foe_unit.pending_target, b2.roster[1], "seed %d: aimed at the Champion from the start" % s)
	var sweep: Array[EnemyActionData] = [t.make_action("Sweep", 9, EnemyActionData.Targeting.ALL_COMPANIONS, 5)]
	var b3 := battle(["champion:first_challenge", ""], t.one_enemy(t.make_enemy("Sweeper", sweep)))
	t.eq(b3.enemies[0].pending_target, null, "a blow on the whole line has no aim")


func test_mastery_executioner() -> void:
	# Deep Cut: a quarter, a boss an eighth.
	var b := battle(["executioner:deep_cut", "executioner"], foes(1))
	t.eq(b.execute_hp(b.roster[0], b.enemies[0]), 25, "a quarter of 100")
	t.eq(b.execute_hp(b.roster[1], b.enemies[0]), 20, "without the mastery: a fifth")
	var boss := foe()
	boss.band = 0
	var b2 := battle(["executioner:deep_cut"], t.one_enemy(boss))
	t.eq(b2.execute_hp(b2.roster[0], b2.enemies[0]), 12, "a boss: an eighth, rounded down")
	b.enemies[0].hp = 40
	b.attack(b.roster[0], b.enemies[0])
	t.check(not b.enemies[0].is_alive(), "40 - 15 = 25: felled")
	# The Next One: felling an enemy, they are ready at once.
	var b3 := battle(["executioner:next_one", "executioner"], foes(3))
	var ex := b3.roster[0]
	b3.enemies[0].hp = 10
	b3.attack(ex, b3.enemies[0])
	t.eq(ex.recovery, 0, "felled one: ready at once")
	b3.attack(ex, b3.enemies[1])
	t.eq(ex.recovery, BattleConfig.RECOVERY_ATTACK, "felled nobody: the usual recovery")
	b3.enemies[2].hp = 10
	b3.attack(b3.roster[1], b3.enemies[2])
	t.eq(b3.roster[1].recovery, BattleConfig.RECOVERY_ATTACK, "without the mastery: the usual")


func test_mastery_skirmisher() -> void:
	# Light Hands: tier I arts have Recovery 1 too.
	var b := battle(["skirmisher:light_hands", "skirmisher"], foes(1, 9, 500))
	var s := b.roster[0]
	var art := s.arts()[0]
	t.eq(art.recovery, 2, "the test art: tier I, Recovery 2")
	t.eq(b.art_recovery(s, art), 1, "theirs: 1")
	t.eq(b.art_recovery(b.roster[1], art), 2, "without the mastery: its own")
	var heavy: CombatArtData = t.make_art("Heavy", 2, 5, 3)
	t.eq(b.art_recovery(s, heavy), 3, "a tier II art keeps its own")
	b.use_art(s, art, b.enemies[0])
	t.eq(s.recovery, 1, "after the art: 1")
	# First In: their first action of a battle has no recovery.
	var b2 := battle(["skirmisher:first_in", ""], foes(1, 9, 500))
	var f := b2.roster[0]
	t.eq(b2.action_recovery(f, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), 0, "the first Attack: none")
	t.eq(b2.art_recovery(f, f.arts()[0]), 0, "or the first art")
	t.eq(b2.guard_recovery(f), 0, "or a first Guard")
	b2.attack(f, b2.enemies[0])
	t.eq(f.recovery, 0, "ready again at once")
	t.eq(b2.action_recovery(f, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), 1, "the second: a Skirmisher's 1")
	b2.attack(f, b2.enemies[0])
	t.eq(f.recovery, 1, "and it is")
	t.eq(b2.action_recovery(b2.roster[1], BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "nobody else")


func test_mastery_captain() -> void:
	# Clear Order: the one roused cannot miss with their next action.
	var b := battle(["captain:clear_order", "", ""], foes(1, 9, 500))
	var cap := b.roster[0]
	var other := b.roster[1]
	other.progress.weapon = t.make_weapon(5, -999)
	var e := b.enemies[0]
	t.eq(b.forecast(other, e).hit, BattleConfig.ACCURACY_MIN, "a weapon that barely hits")
	b.attack(other, e)
	t.check(b.rouse(cap, other), "roused")
	t.check(other.roused_sure, "sure of their next")
	t.eq(b.forecast(other, e).hit, 100, "it cannot miss")
	t.eq(b.forecast(other, e, other.arts()[0]).hit, 100, "an art neither")
	t.eq(b.forecast(b.roster[2], e).hit, 100, "(the others hit as they did)")
	var hp := e.hp
	b.attack(other, e)
	t.check(e.hp < hp, "and it lands")
	t.eq(b.forecast(other, e).hit, BattleConfig.ACCURACY_MIN, "only the next action")
	var plain := battle(["captain", ""], foes(1, 9, 500))
	plain.roster[1].progress.weapon = t.make_weapon(5, -999)
	plain.attack(plain.roster[1], plain.enemies[0])
	plain.rouse(plain.roster[0], plain.roster[1])
	t.eq(plain.forecast(plain.roster[1], plain.enemies[0]).hit, BattleConfig.ACCURACY_MIN, "without the mastery: as before")
	# Quick Word: Rouse has Recovery 1.
	var b2 := battle(["captain:quick_word", ""], foes(1, 9, 500))
	var quick := b2.roster[0]
	t.eq(b2.rouse_recovery(quick), 1, "Rouse: Recovery 1")
	t.eq(b2.guard_recovery(quick), BattleConfig.RECOVERY_GUARD, "Guard as it was")
	t.eq(b2.action_recovery(quick, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "and the Attack")
	b2.attack(b2.roster[1], b2.enemies[0])
	b2.rouse(quick, b2.roster[1])
	t.eq(quick.recovery, 1, "after a Rouse: 1")
	t.eq(plain.rouse_recovery(plain.roster[0]), BattleConfig.RECOVERY_ROUSE, "without the mastery: the usual")


func test_mastery_harrier() -> void:
	# No Rest: an action already pushed back can be pushed back once more.
	var b := battle(["harrier:no_rest", ""], foes(1, 5, 500))
	var h := b.roster[0]
	var e := b.enemies[0]
	b.attack(h, e)
	t.eq(e.countdown, 5, "5, pushed to 6, then the turn: 5")
	t.eq(b.forecast(h, e).staggers, 1, "the forecast: once more")
	t.eq(b.forecast(b.roster[1], e).staggers, 0, "nobody else")
	t.rest(b)
	b.attack(h, e)
	t.eq(e.countdown, 5, "pushed again: 6, then the turn: 5")
	t.check(e.delayed_again, "and that is all")
	var again := events_of(b, "delay")
	t.check(again.size() == 1 and bool(again[0].get("again", false)), "a delay event that says again")
	t.eq(b.forecast(h, e).staggers, 0, "the forecast says nothing more")
	t.rest(b)
	b.attack(h, e)
	t.eq(e.countdown, 4, "not a third time")
	# With an art that staggers by itself: the art's push, then theirs.
	var b2 := battle(["harrier:no_rest"], foes(1, 5, 500))
	var art: CombatArtData = t.make_art("Shove")
	art.stagger_ticks = 2
	t.give_art(b2.roster[0], art)
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0], art).staggers, 1, "on top of the art's own")
	b2.use_art(b2.roster[0], art, b2.enemies[0])
	t.eq(b2.enemies[0].countdown, 7, "5 + 2 + 1, then the turn: 7")
	# Off Balance: a staggered enemy takes a quarter more until it acts.
	var b3 := battle(["harrier:off_balance", ""], foes(2, 5, 500))
	var h3 := b3.roster[0]
	var other := b3.roster[1]
	var e3 := b3.enemies[0]
	t.eq(b3.forecast(other, e3).damage, 15, "before: 15")
	t.eq(b3.staggered_bonus(e3), 0, "not staggered yet")
	b3.attack(h3, e3)
	t.eq(e3.hp, 500 - 15, "the blow that staggers lands as it was")
	t.eq(b3.staggered_bonus(e3), 25, "staggered: a quarter more")
	t.eq(b3.forecast(other, e3).damage, 18, "15 to 18, from anyone")
	t.eq(b3.forecast(h3, e3).damage, 18, "the Harrier too")
	t.eq(b3.forecast(other, b3.enemies[1]).damage, 15, "not the enemy beside it")
	var bolt := spell("black/shadow_bolt")
	other.progress.learn_spell(bolt)
	var whole := b3.spell_forecast(other, bolt, b3.enemies[1]).damage
	t.eq(b3.spell_forecast(other, bolt, e3).damage, floori(whole * 1.25), "a spell too")
	b3.pick_next_action(e3)
	t.eq(b3.forecast(other, e3).damage, 15, "until it acts")
	b3.delay_action(e3, 1)
	t.set_injured(h3)
	t.eq(b3.forecast(other, e3).damage, 15, "and only while the Harrier stands")


func test_mastery_hunter() -> void:
	# Long Watch: with 2 turns left or fewer.
	var b := battle(["hunter:long_watch", "hunter"], foes(1, 3, 500))
	var h := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.forecast(h, e).crit, 0, "3 turns left: no critical")
	e.countdown = 2
	t.eq(b.forecast(h, e).crit, 100, "2 turns left: critical")
	t.eq(b.forecast(b.roster[1], e).crit, 0, "without the mastery: not yet")
	e.countdown = 1
	t.eq(b.forecast(h, e).crit, 100, "and with 1")
	# Sure Shot: such a blow cannot miss.
	var b2 := battle(["hunter:sure_shot", "hunter"], foes(1, 3, 500))
	var s := b2.roster[0]
	for c in b2.roster:
		c.progress.weapon = t.make_weapon(5, -999)
	var e2 := b2.enemies[0]
	t.eq(b2.forecast(s, e2).hit, BattleConfig.ACCURACY_MIN, "3 turns left: it may well miss")
	e2.countdown = 1
	t.eq(b2.forecast(s, e2).hit, 100, "1 turn left: it cannot")
	t.eq(b2.forecast(s, e2).crit, 100, "and is critical")
	t.eq(b2.forecast(b2.roster[1], e2).hit, BattleConfig.ACCURACY_MIN, "without the mastery: it can")


func test_mastery_berserker() -> void:
	# Red Mist: below half Health, a quarter more damage.
	var b := battle(["berserker:red_mist", "berserker"], foes(1, 9, 500))
	var z := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.forecast(z, e).damage, 15, "at full Health: 15")
	z.hp = 20
	t.eq(b.forecast(z, e).damage, 15, "at half: 15")
	z.hp = 19
	t.eq(b.forecast(z, e).damage, 18, "below half: 18")
	t.eq(b.forecast(z, e, z.arts()[0]).damage, 22, "an art too: 18 to 22")
	b.roster[1].hp = 5
	t.eq(b.forecast(b.roster[1], e).damage, 15, "without the mastery: 15")
	# Blood Price: felling an enemy heals a fifth of their Health.
	var b2 := battle(["berserker:blood_price", "berserker"], foes(2))
	var p := b2.roster[0]
	p.hp = 10
	b2.enemies[0].hp = 5
	b2.attack(p, b2.enemies[0])
	t.eq(p.hp, 18, "10 and a fifth of 40")
	b2.roster[1].hp = 10
	b2.enemies[1].hp = 5
	b2.attack(b2.roster[1], b2.enemies[1])
	t.eq(b2.roster[1].hp, 10, "without the mastery: nothing")


func test_mastery_mender() -> void:
	var mend := spell("white/mend")
	# Open Hands: a heal on one ally reaches that ally's neighbours, at half.
	var b := battle(["mender:open_hands", "", "", ""], foes(1, 9, 500), 60)
	var m := b.roster[0]
	m.progress.learn_spell(mend)
	b.roster[3].progress.learn_spell(mend)
	for c in b.roster:
		c.hp = 10
	var target := b.roster[2]
	var full := b.heal_amount_on(m, mend, target)
	t.eq(b.heal_spread(m, mend, target), [b.roster[1], b.roster[3]] as Array[CompanionUnit], "the two beside the one healed")
	t.eq(b.heal_spread_amount(m, mend, b.roster[1]), floori(full / 2.0), "half as much")
	t.eq(b.heal_spread(b.roster[3], mend, target).size(), 0, "another caster's does not spread")
	b.cast(m, mend, target)
	t.eq(target.hp, 10 + full, "the one healed, in full")
	t.eq(b.roster[1].hp, 10 + floori(full / 2.0), "a neighbour, at half")
	t.eq(b.roster[3].hp, 10 + floori(full / 2.0), "and the other")
	t.eq(m.hp, 10, "nobody further off")
	t.rest(b)
	t.set_injured(b.roster[1])
	t.eq(b.heal_spread(m, mend, target), [b.roster[3]] as Array[CompanionUnit], "not someone injured")
	t.eq(b.heal_spread(m, mend, m).size(), 0, "at the end of the line with an injured neighbour: nobody")
	# Second Breath: twice a battle.
	var b2 := battle(["mender:second_breath", "", ""], foes(1, 9, 500))
	var m2 := b2.roster[0]
	m2.progress.learn_spell(mend)
	t.eq(b2.raises_left(m2), 2, "two raisings")
	t.eq(b2.raises_left(b2.roster[1]), 0, "none for anyone else")
	for i in 2:
		t.set_injured(b2.roster[2])
		t.check(b2.can_raise(m2, mend, b2.roster[2]), "raising %d is allowed" % (i + 1))
		t.check(b2.cast(m2, mend, b2.roster[2]), "and cast")
		t.check(b2.roster[2].is_active(), "standing again")
		t.rest(b2)
	t.set_injured(b2.roster[2])
	t.check(not b2.can_raise(m2, mend, b2.roster[2]), "not a third")
	t.eq(b2.raises_left(m2), 0, "none left")


func test_mastery_hexer() -> void:
	var poison: StatusEffectData = t.make_effect("Poison", {}, 4)
	poison.damage_per_tick = 2
	var curse: StatusEffectData = t.make_effect("Weakened", {Stat.DEF: -2}, 5)
	var ward: StatusEffectData = t.make_effect("Ward", {Stat.DEF: 2}, 3)
	# Long Curse: their effects on enemies last 2 turns longer.
	var b := battle(["hexer:long_curse", "hexer"], foes(2, 9, 500))
	var hx := b.roster[0]
	b._apply_effect(b.enemies[0], poison, false, hx)
	b._apply_effect(b.enemies[0], curse, false, hx)
	t.eq(b.enemies[0].get_effect("Poison").ticks_left, 6, "poison: 4 turns and 2")
	t.eq(b.enemies[0].get_effect("Weakened").ticks_left, 7, "a curse: 5 and 2")
	b._apply_effect(b.enemies[1], poison, false, b.roster[1])
	t.eq(b.enemies[1].get_effect("Poison").ticks_left, 4, "without the mastery: its own")
	b._apply_effect(hx, ward, true, hx)
	t.eq(hx.get_effect("Ward").ticks_left, 3, "not what they lay on a companion")
	# Clouded Eyes: enemies under their effects have 20 less Hit.
	var dim := foe()
	dim.dexterity = 0
	dim.actions[0].hit = 60
	var two: Array[EnemyData] = [dim, dim]
	var b2 := battle(["hexer:clouded_eyes", "hexer"], two)
	var cl := b2.roster[0]
	var e := b2.enemies[0]
	t.eq(b2.enemy_forecast(e, e.pending_action, cl).hit, 60, "before: 60 to hit")
	b2._apply_effect(e, curse, false, cl)
	t.eq(b2.hexed_hit(e), 20, "under their curse")
	t.eq(b2.enemy_forecast(e, e.pending_action, cl).hit, 40, "20 less")
	t.eq(b2.enemy_forecast(e, e.pending_action, b2.roster[1]).hit, 40, "against anyone")
	b2._apply_effect(b2.enemies[1], curse, false, b2.roster[1])
	t.eq(b2.enemy_forecast(b2.enemies[1], b2.enemies[1].pending_action, cl).hit, 60, "another's curse does not cloud")
	t.set_injured(cl)
	t.eq(b2.hexed_hit(e), 0, "only while the Hexer stands")


func test_mastery_sage() -> void:
	var bolt := spell("black/shadow_bolt")
	# Ready Word: the first spell of a battle has no recovery either.
	var b := battle(["sage:ready_word", "sage"], foes(1, 9, 500))
	var s := b.roster[0]
	for c in b.roster:
		c.progress.learn_spell(bolt)
	t.check(bolt.recovery > 0, "the spell has a recovery of its own")
	t.eq(b.spell_recovery(s, bolt), 0, "the first: none")
	t.eq(b.spell_recovery(b.roster[1], bolt), bolt.recovery, "without the mastery: its own")
	b.cast(s, bolt, b.enemies[0])
	t.eq(s.recovery, 0, "ready again at once")
	t.eq(b.spell_recovery(s, bolt), bolt.recovery, "the second: its own")
	b.cast(s, bolt, b.enemies[0])
	t.eq(s.recovery, bolt.recovery, "and it is")
	# Quick Tongue: every spell has 1 less recovery.
	var b2 := battle(["sage:quick_tongue", ""], foes(1, 9, 500))
	var q := b2.roster[0]
	q.progress.learn_spell(bolt)
	t.eq(b2.spell_recovery(q, bolt), bolt.recovery - 1, "1 less")
	b2.cast(q, bolt, b2.enemies[0])
	t.eq(q.recovery, bolt.recovery - 1, "after the first")
	t.rest(b2)
	b2.cast(q, bolt, b2.enemies[0])
	t.eq(q.recovery, bolt.recovery - 1, "and every one after")
	t.eq(b2.action_recovery(q, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "their Attack as it was")


func test_mastery_spellblade() -> void:
	var bolt := spell("black/shadow_bolt")
	# Spell into Steel: a weapon strike right after a spell has no recovery.
	var b := battle(["spellblade:spell_into_steel", "spellblade"], foes(1, 9, 900))
	var sb := b.roster[0]
	var e := b.enemies[0]
	for c in b.roster:
		c.progress.learn_spell(bolt)
	t.eq(b.action_recovery(sb, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "before any spell: the usual")
	b.cast(sb, bolt, e)
	t.eq(sb.recovery, bolt.recovery, "the spell keeps its recovery")
	t.rest(b)
	t.eq(b.action_recovery(sb, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), 0, "the Attack after it: none")
	t.eq(b.art_recovery(sb, sb.arts()[0]), 0, "or an art")
	t.eq(b.spell_recovery(sb, bolt), bolt.recovery, "another spell keeps its own")
	t.eq(b.guard_recovery(sb), BattleConfig.RECOVERY_GUARD, "and Guard")
	b.attack(sb, e)
	t.eq(sb.recovery, 0, "ready at once")
	b.attack(sb, e)
	t.eq(sb.recovery, BattleConfig.RECOVERY_ATTACK, "only the strike right after")
	b.cast(b.roster[1], bolt, e)
	t.rest(b)
	t.eq(b.action_recovery(b.roster[1], BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "without the mastery: the usual")
	# Steel into Spell: a weapon strike that fells an enemy gives one spell use back.
	var b2 := battle(["spellblade:steel_into_spell", "spellblade"], foes(4))
	var st := b2.roster[0]
	for c in b2.roster:
		c.progress.learn_spell(bolt)
	var full := st.progress.max_uses(bolt)
	st.progress.spell_uses[bolt] = full - 2
	b2.enemies[0].hp = 5
	b2.attack(st, b2.enemies[0])
	t.eq(st.progress.uses_left(bolt), full - 1, "one use back")
	t.eq(events_of(b2, "spell_use").size(), 1, "and an event for it")
	t.rest(b2)
	b2.enemies[1].hp = 1
	b2.cast(st, bolt, b2.enemies[1])
	t.eq(st.progress.uses_left(bolt), full - 2, "a spell's kill gives none back (and costs its use)")
	t.rest(b2)
	st.progress.spell_uses[bolt] = full
	b2.enemies[2].hp = 5
	b2.attack(st, b2.enemies[2])
	t.eq(st.progress.uses_left(bolt), full, "never past full")
	b2.roster[1].progress.spell_uses[bolt] = 0
	b2.enemies[3].hp = 5
	b2.attack(b2.roster[1], b2.enemies[3])
	t.eq(b2.roster[1].progress.uses_left(bolt), 0, "without the mastery: nothing")


# ---------------------------------------------------------------- in a run

func test_mastery_in_a_run() -> void:
	var run := rr.make_run(8600)
	var a := run.roster[0]
	var b := run.roster[1]
	var warden := calling("warden")
	var wide := mastery("warden:wide_shield")
	var answer := mastery("warden:answering_blow")
	a.progress.calling_offers.assign([warden, calling("hunter"), calling("champion")])
	level_to(run, a, RunConfig.MASTERY_LEVEL)
	t.check(run.calling_due(a), "at level 8 with no calling: the calling first")
	t.check(not run.mastery_due(a), "no mastery before a calling")
	t.check(run.mastery_block_reason(a, wide).contains("calling"), "the reason: %s" % run.mastery_block_reason(a, wide))
	t.check(not run.take_calling(a, warden).is_empty(), "takes the calling")
	t.check(run.mastery_due(a), "then the mastery is due")
	t.eq(run.masteries_due(), [a] as Array[RunCompanion], "theirs alone")
	t.check(run.mastery_block_reason(a, mastery("hunter:sure_shot")).contains("Warden"), "not another calling's: %s" % run.mastery_block_reason(a, mastery("hunter:sure_shot")))
	t.check(not run.take_mastery(a, mastery("hunter:sure_shot")), "refused")
	t.eq(run.mastery_block_reason(a, wide), "", "either of the Warden's is open")
	t.eq(run.mastery_block_reason(a, answer), "", "both")
	t.check(run.take_mastery(a, answer), "takes one")
	t.eq(a.progress.mastery, answer, "kept")
	t.check(not run.mastery_due(a), "no longer due")
	t.check(run.mastery_block_reason(a, wide).contains("already"), "the other is closed for good: %s" % run.mastery_block_reason(a, wide))
	t.check(not run.take_mastery(a, wide), "refused")
	# Below level 8 with a calling: not yet.
	b.progress.calling_offers.assign([calling("hunter"), calling("sage"), calling("captain")])
	level_to(run, b, RunConfig.CALLING_LEVEL)
	run.take_calling(b, calling("hunter"))
	t.check(not run.mastery_due(b), "not at level 4")
	t.check(run.mastery_block_reason(b, mastery("hunter:sure_shot")).contains("level"), "the reason: %s" % run.mastery_block_reason(b, mastery("hunter:sure_shot")))
	level_to(run, b, RunConfig.MASTERY_LEVEL)
	t.check(run.mastery_due(b), "due at level 8")
	# It fights with the mastery from the next battle.
	t.check(TraitRules.has(a.all_traits(), TraitModifier.Kind.COVER_ANSWERS), "the run's companion carries its rule")
