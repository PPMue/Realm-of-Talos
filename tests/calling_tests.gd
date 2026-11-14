extends RefCounted
## Headless tests for the callings (design/callings.md): the twelve as data, each one's rule in a
## battle, what a calling gives on the day and to growth, and the run's side (three drawn, taking one
## at RunConfig.CALLING_LEVEL, one holder each, the school or weapon grade it opens, the redraw at the
## Drill Yard). Called from run_tests.gd, which owns check() and eq().

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
		test_calling_library,
		test_calling_gains_and_growth,
		test_calling_warden,
		test_calling_champion,
		test_calling_executioner,
		test_calling_skirmisher,
		test_calling_captain,
		test_calling_harrier,
		test_calling_hunter,
		test_calling_berserker,
		test_calling_mender,
		test_calling_hexer,
		test_calling_sage,
		test_calling_spellblade,
		test_calling_offers_in_a_run,
		test_calling_taken_in_a_run,
		test_calling_of_magic_in_a_run,
		test_calling_redraw,
		test_calling_hire_and_raise_in_a_run,
	]


# ---------------------------------------------------------------- helpers

func calling(id: String) -> CallingData:
	return lib.find(id)


## A battle of test companions (STR 10, DEX 10, a sword of Mt 5 that always hits, 30 stamina), the
## first `ids.size()` of them holding those callings ("" for none), against `enemies`.
func battle(ids: Array, enemies: Array[EnemyData], hp: int = 40) -> Battle:
	var cs: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for i in ids.size():
		var d: CompanionData = t.make_companion("C%d" % i, hp)
		cs.append(d)
		var p := CompanionProgress.create(d)
		if ids[i] != "":
			p.calling = calling(ids[i])
			p.calling_lead = Stat.STR
		party.append(p)
	return t.make_battle(cs, enemies, 1, party)


## An enemy with one single blow that comes in `cd` turns (STR 10 + 5 against DEF 0).
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


## Raises `c` to `level` with the run's own dice.
func level_to(run: Run, c: RunCompanion, level: int) -> void:
	while c.level() < level:
		Levels.level_up(c.progress, run.rng)


# ---------------------------------------------------------------- the data

func test_calling_library() -> void:
	t.eq(lib.callings.size(), 12, "twelve callings")
	var ids := {}
	var magic := 0
	for c in lib.callings:
		ids[c.id] = true
		t.check(c.display_name != "" and c.rule != "", "%s: a name and a rule" % c.id)
		t.check(not c.rule.contains("\n") and c.rule.length() <= 120, "%s: the rule is one line" % c.id)
		t.eq(c.modifiers.size(), 1, "%s: one rule" % c.id)
		for token: String in [c.first_stat, c.second_stat, c.slow_stat]:
			t.check(token == CallingData.LEAD or token == CallingData.OTHER or Levels.GROWTH_STATS.has(token),
				"%s: %s is a stat that grows" % [c.id, token])
		var three := Run.calling_stats(c, CompanionProgress.create(rr.companion("elena")))
		t.check(three[0] != three[1] and three[0] != three[2] and three[1] != three[2], "%s: three different stats" % c.id)
		if c.is_magic():
			magic += 1
			t.check(not c.schools().is_empty(), "%s opens a school" % c.id)
		else:
			t.eq(c.schools().size(), 0, "%s: a calling of arms" % c.id)
	t.eq(ids.size(), 12, "no two share an id")
	t.eq(magic, 4, "four of magic")
	t.eq(calling("sage").schools().size(), 2, "the Sage picks either school")
	t.check(calling("mender").needs_heal, "the Mender's rule works through a heal")
	t.eq(calling("mender").school, int(SpellData.School.WHITE), "the Mender opens White Magic")
	t.eq(calling("hexer").school, int(SpellData.School.BLACK), "the Hexer Black")
	t.eq(calling("spellblade").school, int(SpellData.School.BLACK), "the Spellblade Black")


## On the day: +2 to the first stat and +1 to the second (Health three for one). After: growth +20,
## +10 and -10. "Lead" is whichever of Strength and Magic is higher when it is taken.
func test_calling_gains_and_growth() -> void:
	var elena := rr.companion("elena")
	var p := CompanionProgress.create(elena)
	t.eq(CallingData.lead_of(p), Stat.STR, "Elena leads with Strength")
	t.eq(CallingData.lead_of(CompanionProgress.create(rr.companion("freya"))), Stat.MAG, "Freya with Magic")
	p.stat_gains[Stat.MAG] = 2
	t.eq(CallingData.lead_of(p), Stat.MAG, "levels can turn it")
	p.stat_gains[Stat.MAG] = 1
	t.eq(CallingData.lead_of(p), Stat.STR, "a tie goes to the one that grows faster")
	p.stat_gains.clear()
	t.eq(calling("executioner").gains_for(Stat.STR), {Stat.STR: 2, Stat.CRT: 1}, "Executioner: lead +2, Critical +1")
	t.eq(calling("champion").gains_for(Stat.STR), {Stat.HP: 6, Stat.DEF: 1}, "Champion: Health +6, Defence +1")
	t.eq(calling("warden").gains_for(Stat.STR), {Stat.DEF: 2, Stat.HP: 3}, "Warden: Defence +2, Health +3")
	t.eq(calling("spellblade").gains_for(Stat.STR), {Stat.MAG: 2, Stat.STR: 1}, "Spellblade: the other +2, lead +1")
	t.eq(calling("spellblade").gains_for(Stat.MAG), {Stat.STR: 2, Stat.MAG: 1}, "and the other way for a mage")
	t.eq(calling("mender").growth_for(Stat.STR), {Stat.MAG: 20, Stat.RES: 10, Stat.STR: -10}, "Mender: Magic, Resistance; Strength slower")
	var before := {}
	for key in Levels.GROWTH_STATS:
		before[key] = Levels.growth_rate_of(p, key)
	var stats := p.stats()
	var gains := p.take_calling(calling("executioner"))
	t.eq(gains, {Stat.STR: 2, Stat.CRT: 1}, "taking it returns the gains")
	t.eq(p.calling, calling("executioner"), "taken")
	t.eq(p.calling_lead, Stat.STR, "the lead is fixed")
	t.eq(int(p.stats()[Stat.STR]), int(stats[Stat.STR]) + 2, "Strength +2 at once")
	t.eq(int(p.stats()[Stat.CRT]), int(stats[Stat.CRT]) + 1, "Critical +1")
	t.eq(Levels.growth_rate_of(p, Stat.STR), int(before[Stat.STR]) + 20, "Strength grows 20 faster")
	t.eq(Levels.growth_rate_of(p, Stat.CRT), int(before[Stat.CRT]) + 10, "Critical 10 faster")
	t.eq(Levels.growth_rate_of(p, Stat.DEF), int(before[Stat.DEF]) - 10, "Defence 10 slower")
	t.eq(Levels.growth_rate_of(p, Stat.SPD), int(before[Stat.SPD]), "the rest as they were")
	p.stat_gains[Stat.MAG] = 9
	t.eq(Run.calling_stats(calling("executioner"), p), [Stat.STR, Stat.CRT, Stat.DEF] as Array[String], "the lead stays what it was when taken")
	t.check(p.all_traits().has(p.calling_effect()), "the rules read it with the traits")
	t.eq(p.copy().calling, p.calling, "a copy keeps it")


# ---------------------------------------------------------------- the rules, one by one

func test_calling_warden() -> void:
	var b := battle(["warden", ""], foes(1))
	var w := b.roster[0]
	t.eq(b.guard_recovery(w), 0, "Guard has no recovery")
	t.eq(b.guard_recovery(b.roster[1]), BattleConfig.RECOVERY_GUARD, "anyone else: the usual")
	t.eq(b.action_recovery(w, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), BattleConfig.RECOVERY_ATTACK, "their Attack is as it was")
	t.eq(b.action_recovery(w, BattleConfig.RECOVERY_FOCUS), BattleConfig.RECOVERY_FOCUS, "and Focus")
	t.check(b.guard(w), "guards")
	t.eq(w.recovery, 0, "and is ready again")
	t.check(b.can_act(w), "can act next turn")
	t.check(b.guard(b.roster[1]), "the other guards")
	t.eq(b.roster[1].recovery, BattleConfig.RECOVERY_GUARD, "and recovers")


func test_calling_champion() -> void:
	var b := battle(["champion", "", ""], foes(2))
	var champ := b.roster[0]
	var e := b.enemies[0]
	e.pending_target = b.roster[2]
	b.enemies[1].pending_target = b.roster[2]
	t.check(b.forecast(champ, e).turns_aim, "the forecast says the blow will turn")
	t.check(not b.forecast(b.roster[1], e).turns_aim, "not for anyone else")
	t.check(b.attack(champ, e), "strikes")
	t.eq(e.pending_target, champ, "the enemy struck turns its blow on them")
	t.eq(b.enemies[1].pending_target, b.roster[2], "the other enemy does not")
	var aims := events_of(b, "aim")
	t.eq(aims.size(), 1, "one aim moved")
	t.eq(aims[0].why, "challenged", "and why")
	t.check(not b.forecast(champ, e).turns_aim, "already theirs: nothing to turn")
	# A miss turns nothing.
	var b2 := battle(["champion", ""], foes(1))
	b2.enemies[0].pending_target = b2.roster[1]
	b2.roster[0].progress.weapon = t.make_weapon(5, -999)
	b2.attack(b2.roster[0], b2.enemies[0])
	t.eq(b2.enemies[0].pending_target, b2.roster[1], "a miss turns nothing")
	# A blow on the whole line has no aim to turn.
	var sweep: Array[EnemyActionData] = [t.make_action("Sweep", 9, EnemyActionData.Targeting.ALL_COMPANIONS, 5)]
	var b3 := battle(["champion"], t.one_enemy(t.make_enemy("Sweeper", sweep)))
	t.check(not b3.forecast(b3.roster[0], b3.enemies[0]).turns_aim, "a blow on the whole line is not turned")


func test_calling_executioner() -> void:
	var b := battle(["executioner", ""], foes(2))
	var ex := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.execute_hp(ex, e), 20, "a fifth of 100 Health")
	t.eq(b.execute_hp(b.roster[1], e), 0, "nobody else has the rule")
	t.eq(b.forecast(ex, e).execute_at, 20, "the forecast carries it")
	e.hp = 36
	t.check(not b.forecast(ex, e).fells_by_rule(e.hp), "36 - 15 = 21: not felled")
	e.hp = 35
	t.check(b.forecast(ex, e).fells_by_rule(e.hp), "35 - 15 = 20: felled")
	t.check(not b.forecast(ex, e).fells_by_rule(15), "a blow that kills by itself is not the rule's doing")
	t.check(b.attack(ex, e), "strikes")
	t.check(not e.is_alive(), "left at a fifth: felled")
	t.eq(events_of(b, "execute").size(), 1, "an execute event")
	t.eq(b.kills_of(ex), 1, "the kill is theirs, once")
	# Left above a fifth: stands.
	t.rest(b)
	var e2 := b.enemies[1]
	e2.hp = 36
	b.attack(ex, e2)
	t.eq(e2.hp, 21, "left at 21: stands")
	# A boss: a tenth.
	var boss := foe()
	boss.band = 0
	var b2 := battle(["executioner"], t.one_enemy(boss))
	t.eq(b2.execute_hp(b2.roster[0], b2.enemies[0]), 10, "a boss: a tenth")
	b2.enemies[0].hp = 26
	b2.attack(b2.roster[0], b2.enemies[0])
	t.eq(b2.enemies[0].hp, 11, "a boss left at 11 stands")
	t.rest(b2)
	b2.enemies[0].hp = 25
	b2.attack(b2.roster[0], b2.enemies[0])
	t.check(not b2.enemies[0].is_alive(), "left at 10: felled")


func test_calling_skirmisher() -> void:
	var b := battle(["skirmisher", ""], foes(1, 9, 500))
	var s := b.roster[0]
	t.eq(b.action_recovery(s, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK), 1, "their Attack has Recovery 1")
	t.eq(b.art_recovery(s, s.arts()[0]), s.arts()[0].recovery, "an art keeps its own")
	t.eq(b.guard_recovery(s), BattleConfig.RECOVERY_GUARD, "and Guard")
	b.attack(s, b.enemies[0])
	t.eq(s.recovery, 1, "after an Attack: 1")
	b.attack(b.roster[1], b.enemies[0])
	t.check(b.can_act(s), "ready after one action of another")


func test_calling_captain() -> void:
	var b := battle(["captain", "", ""], foes(1, 9, 500))
	var cap := b.roster[0]
	var other := b.roster[1]
	t.check(b.has_rouse(cap), "the Captain has the order")
	t.check(not b.has_rouse(other), "nobody else")
	t.eq(b.rouse_targets(cap).size(), 0, "nobody is recovering yet")
	t.check(not b.rouse(cap, other), "nobody to rouse: refused")
	b.attack(other, b.enemies[0])
	t.eq(other.recovery, BattleConfig.RECOVERY_ATTACK, "the other is recovering")
	t.eq(b.rouse_targets(cap), [other] as Array[CompanionUnit], "and can be roused")
	t.check(not b.rouse(b.roster[2], other), "not by someone without the order")
	t.check(not b.rouse(cap, cap), "not themselves")
	var turn := b.tick
	t.check(b.rouse(cap, other), "rouses")
	t.eq(b.tick, turn + 1, "it is the Captain's action for the turn")
	t.eq(other.recovery, 0, "ready at once")
	t.check(b.can_act(other), "and can act")
	t.eq(cap.recovery, BattleConfig.RECOVERY_ROUSE, "the Captain recovers")
	t.eq(events_of(b, "rouse").size(), 1, "a rouse event")
	t.eq(b.points_of(cap), BattleConfig.POINTS_ROUSE, "and earns points for it")
	t.set_injured(other)
	t.rest(b)
	t.eq(b.rouse_targets(cap).size(), 0, "the injured are not roused")


func test_calling_harrier() -> void:
	var b := battle(["harrier", ""], foes(2, 5, 500))
	var h := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.forecast(h, e).staggers, 1, "the forecast: 1 turn later")
	t.eq(b.forecast(b.roster[1], e).staggers, 0, "nobody else")
	b.attack(h, e)
	t.eq(e.countdown, 5, "5, pushed to 6, then the turn passes: 5")
	t.check(e.delayed, "pushed once")
	t.eq(b.enemies[1].countdown, 4, "the other enemy is not")
	t.eq(events_of(b, "delay").size(), 1, "a delay event")
	t.eq(b.forecast(h, e).staggers, 0, "already pushed: the forecast says nothing")
	t.rest(b)
	b.attack(h, e)
	t.eq(e.countdown, 4, "not pushed twice")
	t.eq(events_of(b, "delay_blocked").size(), 0, "and nothing is said of it")
	# An art that staggers by itself pushes its own turns; the Harrier's adds nothing.
	var b2 := battle(["harrier"], foes(1, 5, 500))
	var art: CombatArtData = t.make_art("Shove")
	art.stagger_ticks = 2
	t.give_art(b2.roster[0], art)
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0], art).staggers, 0, "the art's own push stands")
	b2.use_art(b2.roster[0], art, b2.enemies[0])
	t.eq(b2.enemies[0].countdown, 6, "5 + 2, then the turn: 6")
	# A miss pushes nothing.
	var b3 := battle(["harrier"], foes(1, 5, 500))
	b3.roster[0].progress.weapon = t.make_weapon(5, -999)
	b3.attack(b3.roster[0], b3.enemies[0])
	t.eq(b3.enemies[0].countdown, 4, "a miss pushes nothing")


func test_calling_hunter() -> void:
	var b := battle(["hunter", ""], foes(1, 3, 500))
	var h := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.forecast(h, e).crit, 0, "3 turns left: no critical")
	e.countdown = 2
	t.eq(b.forecast(h, e).crit, 0, "2 turns left: none")
	e.countdown = 1
	t.eq(b.forecast(h, e).crit, 100, "1 turn left: critical")
	t.eq(b.forecast(h, e, h.arts()[0]).crit, 100, "an art too")
	t.eq(b.forecast(b.roster[1], e).crit, 0, "nobody else")
	var bolt := spell("black/shadow_bolt")
	h.progress.learn_spell(bolt)
	t.eq(b.spell_forecast(h, bolt, e).crit, 100, "and a spell")
	b.attack(h, e)
	t.eq(e.hp, 500 - 30, "15 doubled")
	var hits := events_of(b, "damage")
	t.check(not hits.is_empty() and bool(hits[0].crit), "a critical hit")


func test_calling_berserker() -> void:
	var b := battle(["berserker", ""], foes(1, 9, 500))
	var z := b.roster[0]
	var art := z.arts()[0]
	t.check(b.pays_in_health(z), "pays in Health")
	t.check(not b.pays_in_health(b.roster[1]), "nobody else")
	t.eq(b.art_cost(z, art), 10, "the art costs 10 stamina")
	t.eq(b.art_health_cost(z, art), 5, "half of it in Health")
	t.eq(b.art_health_cost(b.roster[1], art), 0, "nothing for anyone else")
	t.eq(z.progress.art_health_cost(art), 5, "the barracks says the same")
	z.stamina = 0
	t.eq(b.art_block_reason(z, art), "", "no stamina is needed")
	var hp := z.hp
	t.check(b.use_art(z, art, b.enemies[0]), "uses it")
	t.eq(z.hp, hp - 5, "5 Health")
	t.eq(z.stamina, 0, "no stamina spent")
	t.eq(events_of(b, "art_health").size(), 1, "an event for the cost")
	t.rest(b)
	z.hp = 5
	t.check(b.art_block_reason(z, art).contains("Health"), "never their last Health: %s" % b.art_block_reason(z, art))
	t.check(not b.use_art(z, art, b.enemies[0]), "refused")
	z.hp = 6
	t.check(b.use_art(z, art, b.enemies[0]), "6 Health: allowed")
	t.eq(z.hp, 1, "left at 1")
	var odd: CombatArtData = t.make_art("Odd", 1, 5)
	t.eq(z.progress.art_health_cost(odd), 3, "5 stamina: 3 Health, rounded up")


func test_calling_mender() -> void:
	var b := battle(["mender", "", ""], foes(1, 9, 500), 40)
	var m := b.roster[0]
	var mend := spell("white/mend")
	m.progress.learn_spell(mend)
	b.roster[1].progress.learn_spell(mend)
	var down := b.roster[2]
	t.check(not b.can_raise(m, mend, down), "nobody is injured")
	t.set_injured(down)
	b.injured_ever.append(down)
	t.check(b.can_raise(m, mend, down), "the Mender can raise them")
	t.check(not b.can_raise(b.roster[1], mend, down), "another caster cannot")
	t.eq(b.spell_target_block_reason(mend, down, m), "", "they are a target for the Mender's heal")
	t.check(b.spell_target_block_reason(mend, down, b.roster[1]).contains("injured"), "not for anyone else's")
	t.check(b.spell_target_block_reason(mend, down).contains("injured"), "nor with no caster named")
	t.eq(b.hp_after_heal(m, mend, down), 10, "raised at a quarter of 40")
	t.check(not b.can_raise(m, spell("white/blessing"), down), "only a healing spell raises")
	t.check(not b.cast(b.roster[1], mend, down), "the other's heal is refused")
	t.check(b.cast(m, mend, down), "the Mender casts")
	t.check(down.is_active(), "standing again")
	t.eq(down.hp, 10, "at a quarter of their Health")
	t.eq(down.recovery, 0, "ready at once")
	t.eq(events_of(b, "raise").size(), 1, "a raise event")
	t.check(b.injured_ever.has(down), "it did happen")
	t.eq(m.raises_used, 1, "used")
	# Once a battle.
	t.rest(b)
	t.set_injured(down)
	t.check(not b.can_raise(m, mend, down), "once a battle")
	t.check(not b.cast(m, mend, down), "a second raising is refused")
	t.check(b.cast(m, mend, b.roster[1]), "the heal still heals the standing")


func test_calling_hexer() -> void:
	var poison: StatusEffectData = t.make_effect("Poison", {}, 4)
	poison.damage_per_tick = 2
	var curse: StatusEffectData = t.make_effect("Weakened", {Stat.DEF: -2}, 5)
	var b := battle(["hexer", ""], foes(3, 9, 100))
	var hx := b.roster[0]
	var e := b.enemies
	e[1].hp = 60
	b._apply_effect(e[0], poison, false, hx)
	b._apply_effect(e[0], curse, false, hx)
	t.eq(e[0].get_effect("Weakened").source, hx, "a curse on an enemy remembers who laid it")
	e[0].hp = 1
	b.attack(hx, e[0])
	t.check(not e[0].is_alive(), "the carrier falls")
	t.check(e[2].has_effect("Poison") and e[2].has_effect("Weakened"), "both pass to the enemy with the most Health")
	t.check(not e[1].has_effect("Poison"), "not to the other")
	t.eq(e[2].get_effect("Poison").ticks_left, 3, "with the turns it had left (4, and this turn)")
	t.eq(e[2].hp, 98, "and it bites this turn")
	t.eq(e[2].get_effect("Poison").source, hx, "still the Hexer's")
	# It passes on again when the next carrier falls.
	t.rest(b)
	e[2].hp = 1
	b.attack(hx, e[2])
	t.check(e[1].has_effect("Poison"), "and passes on again")
	# Someone else's poison stays where it fell.
	var b2 := battle(["", "hexer"], foes(2, 9, 100))
	b2._apply_effect(b2.enemies[0], poison, false, b2.roster[0])
	b2.enemies[0].hp = 1
	b2.attack(b2.roster[1], b2.enemies[0])
	t.check(not b2.enemies[1].has_effect("Poison"), "another's poison does not pass")
	# Not onto an enemy already carrying it for as long.
	var b3 := battle(["hexer"], foes(2, 9, 100))
	b3._apply_effect(b3.enemies[0], poison, false, b3.roster[0])
	b3._apply_effect(b3.enemies[1], poison, false, b3.roster[0])
	b3.enemies[0].hp = 1
	b3.attack(b3.roster[0], b3.enemies[0])
	t.eq(events_of(b3, "effect").size(), 0, "nothing passes onto one already carrying it")


func test_calling_sage() -> void:
	var bolt := spell("black/shadow_bolt")
	var b := battle(["sage", ""], foes(1, 9, 500))
	var s := b.roster[0]
	s.progress.learn_spell(bolt)
	b.roster[1].progress.learn_spell(bolt)
	var full := s.progress.max_uses(bolt)
	t.check(b.spell_is_free(s), "the first spell costs no use")
	t.check(not b.spell_is_free(b.roster[1]), "not for anyone else")
	b.cast(s, bolt, b.enemies[0])
	t.eq(s.progress.uses_left(bolt), full, "no use spent")
	t.check(not b.spell_is_free(s), "only the first")
	t.rest(b)
	b.cast(s, bolt, b.enemies[0])
	t.eq(s.progress.uses_left(bolt), full - 1, "the second costs one")
	b.cast(b.roster[1], bolt, b.enemies[0])
	t.eq(b.roster[1].progress.uses_left(bolt), full - 1, "another caster's first costs one")
	# With no use left, the first spell of a battle can still be cast.
	var b2 := battle(["sage", ""], foes(1, 9, 500))
	for c in b2.roster:
		c.progress.learn_spell(bolt)
		c.progress.spell_uses[bolt] = 0
	t.eq(b2.spell_block_reason(b2.roster[0], bolt), "", "the Sage can cast with none left")
	t.check(b2.spell_block_reason(b2.roster[1], bolt) != "", "nobody else can")
	t.check(b2.cast(b2.roster[0], bolt, b2.enemies[0]), "cast")
	t.eq(b2.roster[0].progress.uses_left(bolt), 0, "still none")
	t.rest(b2)
	t.check(not b2.cast(b2.roster[0], bolt, b2.enemies[0]), "the second is refused")


func test_calling_spellblade() -> void:
	var hard := foe()
	hard.defense = 8
	hard.resistance = 2
	var warded := foe()
	warded.defense = 2
	warded.resistance = 8
	var even := foe()
	even.defense = 4
	even.resistance = 4
	var es: Array[EnemyData] = [hard, warded, even]
	var b := battle(["spellblade", ""], es)
	var sb := b.roster[0]
	var plain := b.roster[1]
	t.eq(b.forecast(plain, b.enemies[0]).damage, 15 - 8, "a plain sword against Defence 8: 7")
	var f := b.forecast(sb, b.enemies[0])
	t.eq(f.damage, 15 - 2, "the Spellblade against Resistance 2: 13")
	t.check(f.magic, "worked out against Resistance")
	f = b.forecast(sb, b.enemies[1])
	t.eq(f.damage, 15 - 2, "against Defence when that is lower")
	t.check(not f.magic, "and physical")
	t.eq(b.forecast(sb, b.enemies[2]).damage, 15 - 4, "equal: the weapon's own")
	t.eq(b.forecast(sb, b.enemies[0], sb.arts()[0]).damage, 18 - 2, "arts too")
	b.attack(sb, b.enemies[0])
	t.eq(b.enemies[0].hp, 100 - 13, "and it lands so")


# ---------------------------------------------------------------- in a run

func test_calling_offers_in_a_run() -> void:
	for s in 5:
		var run := rr.make_run(8100 + s)
		t.eq(run.calling_pool.size(), 12, "seed %d: the run knows the twelve" % s)
		for c in run.roster:
			var offers := c.progress.calling_offers
			t.eq(offers.size(), RunConfig.CALLINGS_OFFERED, "%s: three drawn" % c.display_name())
			t.check(offers[0] != offers[1] and offers[0] != offers[2] and offers[1] != offers[2], "all different")
			t.eq(c.progress.calling, null, "none taken")
			t.check(not run.calling_due(c), "not due at level 1")
			t.eq(run.open_callings(c).size(), 3, "all open")
		for d in run.tavern_offers:
			var p := run.offer_progress(d)
			t.eq(p.calling_offers.size(), RunConfig.CALLINGS_OFFERED, "%s at the tavern: three drawn" % d.display_name)
		var again := rr.make_run(8100 + s)
		for i in run.roster.size():
			t.eq(again.roster[i].progress.calling_offers, run.roster[i].progress.calling_offers, "the same seed draws the same")
	# What is drawn differs between runs: over 20 runs one companion sees most of the twelve.
	var seen := {}
	for s in 20:
		var run := rr.make_run(8200 + s)
		for calling in run.roster[0].progress.calling_offers:
			seen[calling.id] = true
	t.check(seen.size() >= 10, "20 runs offer at least 10 of the 12 (%d)" % seen.size())


func test_calling_taken_in_a_run() -> void:
	var run := rr.make_run(8300)
	var a := run.roster[0]
	var b := run.roster[1]
	var champ := calling("champion")
	var hunter := calling("hunter")
	var warden := calling("warden")
	a.progress.calling_offers.assign([champ, hunter, warden])
	b.progress.calling_offers.assign([champ, hunter])
	t.check(run.calling_block_reason(a, champ).contains("level"), "not before level 4: %s" % run.calling_block_reason(a, champ))
	t.eq(run.take_calling(a, champ), {}, "refused")
	level_to(run, a, RunConfig.CALLING_LEVEL)
	level_to(run, b, RunConfig.CALLING_LEVEL)
	t.check(run.calling_due(a) and run.calling_due(b), "both due at level 4")
	t.eq(run.callings_due(), [a, b] as Array[RunCompanion], "in roster order")
	t.check(run.calling_block_reason(a, calling("sage")) != "", "not one that was not drawn for them")
	a.hp = a.max_hp() - 2
	var stats := a.progress.stats()
	var hp := a.hp
	# An arms calling raises the weapon in hand to D.
	var wt := a.progress.weapon.weapon_type
	a.progress.points[wt] = 0
	var got := run.take_calling(a, champ)
	t.eq(got.calling, champ, "taken")
	t.eq(got.gains, {Stat.HP: 6, Stat.DEF: 1}, "its gains")
	t.eq(a.max_hp(), int(stats[Stat.HP]) + 6, "Health +6")
	t.eq(a.hp, hp + 6, "healed by as much")
	t.eq(int(a.progress.stats()[Stat.DEF]), int(stats[Stat.DEF]) + 1, "Defence +1")
	t.eq(int(got.weapon_type), int(wt), "the weapon in hand")
	t.eq(int(got.grade_from), int(Proficiency.Grade.E), "from E")
	t.eq(a.progress.grade(wt), int(Proficiency.Grade.D), "raised to D")
	t.eq(run.calling_holder(champ), a, "the holder")
	t.check(not run.calling_due(a), "no longer due")
	t.check(run.calling_block_reason(a, hunter).contains("already"), "cannot take another")
	# One holder each.
	t.check(not run.is_calling_open(champ), "closed to everyone else")
	t.check(run.calling_block_reason(b, champ).contains(a.display_name()), "the reason names the holder: %s" % run.calling_block_reason(b, champ))
	t.eq(run.take_calling(b, champ), {}, "refused")
	# The other was left with one open of two: one more was drawn.
	t.eq(run.open_callings(b).size(), RunConfig.CALLING_MIN_OPEN, "two open again")
	t.eq(b.progress.calling_offers.size(), 3, "one more drawn")
	t.check(b.progress.calling_offers.has(champ), "the closed one still shows")
	t.check(not b.progress.calling_offers.slice(2).has(champ), "what is drawn is open")
	# A weapon grade already above D is left alone.
	b.progress.points[b.progress.weapon.weapon_type] = Proficiency.points_for(Proficiency.Grade.C)
	var got_b := run.take_calling(b, hunter)
	t.eq(b.progress.grade(b.progress.weapon.weapon_type), int(Proficiency.Grade.C), "a higher grade stays")
	t.eq(int(got_b.grade_to), int(Proficiency.Grade.C), "and is reported as it is")
	# In a battle it is there.
	run.day = 1
	run._begin_day()
	var battle := run.start_battle(run.fronts[0])
	var unit := battle.roster[run.lineup.find(a)]
	t.eq(unit.calling(), champ, "the battle knows the calling")
	t.check(TraitRules.any(unit.trait_query(TraitModifier.Kind.STRIKE_TURNS_AIM)), "and its rule")


func test_calling_of_magic_in_a_run() -> void:
	var run := rr.make_run(8400)
	var c := run.roster[0]
	var p := c.progress
	level_to(run, c, RunConfig.CALLING_LEVEL)
	var sage := calling("sage")
	var mender := calling("mender")
	p.calling_offers.assign([sage, mender, calling("hexer")])
	p.known_spells.clear()
	p.spell_uses.clear()
	p.magic_points[SpellData.School.WHITE] = 0
	p.magic_points[SpellData.School.BLACK] = 0
	t.eq(run.calling_block_reason(c, sage), "Choose a school.", "a Sage picks a school")
	var black := run.calling_spell_choices(c, sage, SpellData.School.BLACK)
	t.eq(black.size(), RunConfig.CALLING_SPELL_CHOICES, "two spells drawn")
	t.check(black[0] != black[1], "different")
	for sp in black:
		t.eq(sp.tier, 1, "%s is tier I" % sp.display_name)
		t.eq(int(sp.school), int(SpellData.School.BLACK), "and of the school")
	t.eq(run.calling_spell_choices(c, sage, SpellData.School.BLACK), black, "asked again: the same two")
	t.eq(run.calling_spell_choices(c, mender, SpellData.School.BLACK).size(), 0, "a Mender opens no Black Magic")
	t.eq(run.calling_spell_choices(c, calling("champion"), SpellData.School.BLACK).size(), 0, "a calling of arms: no spells")
	t.eq(run.calling_block_reason(c, sage, SpellData.School.BLACK), "Choose a spell.", "and one of the two")
	t.eq(run.calling_block_reason(c, sage, SpellData.School.BLACK, spell("white/mend")), "Choose a spell.", "not another")
	# A Mender who knows no heal is always offered one.
	var white := run.calling_spell_choices(c, mender, SpellData.School.WHITE)
	t.check(white.any(func(sp: SpellData) -> bool: return sp.heals), "a healing spell is among the Mender's two")
	var mag := int(p.stats()[Stat.MAG])
	var weapon_points: int = p.points_in(p.weapon.weapon_type)
	var got := run.take_calling(c, mender, SpellData.School.WHITE, white[0])
	t.eq(got.calling, mender, "taken")
	t.eq(int(got.school), int(SpellData.School.WHITE), "White Magic")
	t.eq(p.magic_grade(SpellData.School.WHITE), int(Proficiency.Grade.D), "opened at D")
	t.eq(p.magic_grade(SpellData.School.BLACK), int(Proficiency.Grade.E), "the other school is not")
	t.eq(got.spell, white[0], "the spell chosen")
	t.check(p.knows_spell(white[0]), "is known")
	t.eq(p.uses_left(white[0]), p.max_uses(white[0]), "with full uses")
	t.check(not p.knows_spell(white[1]), "the other is not")
	t.eq(int(p.stats()[Stat.MAG]), mag + 2, "Magic +2")
	t.eq(p.points_in(p.weapon.weapon_type), weapon_points, "a calling of magic leaves the weapon grade alone")
	t.eq(int(got.weapon_type), -1, "and names no weapon")


func test_calling_redraw() -> void:
	var run := rr.make_run(8500)
	rr.force_day(run, RunCalendar.DayType.FREE)
	if run.event_pending():
		run.choose(run.event.choices[0])
	var c := run.roster[0]
	var offers := c.progress.calling_offers.duplicate()
	run.gold = RunConfig.CALLING_REDRAW_COST - 1
	t.check(run.redraw_block_reason(c, offers[1]).contains("gold"), "needs the gold: %s" % run.redraw_block_reason(c, offers[1]))
	run.gold = 100
	t.check(run.redraw_block_reason(c, calling_not_in(offers)) != "", "only one of theirs")
	var drawn := run.redraw_calling(c, offers[1])
	t.check(drawn != null, "redrawn")
	t.check(not offers.has(drawn), "a new one")
	t.eq(c.progress.calling_offers[1], drawn, "in the place of the one put aside")
	t.eq(c.progress.calling_offers[0], offers[0], "the others stay")
	t.eq(c.progress.calling_offers[2], offers[2], "both")
	t.eq(c.progress.calling_aside, [offers[1]] as Array[CallingData], "put aside for good")
	t.eq(run.gold, 100 - RunConfig.CALLING_REDRAW_COST, "30 gold")
	t.eq(run.actions_left, 0, "and the day's action")
	t.eq(run.redraw_block_reason(c, offers[0]), "Already done today.", "once a day")
	t.check(run.free_action_block_reason(Run.FreeAction.TRAIN) != "", "it was the day's drill")
	# What is put aside never comes back, however often they look elsewhere.
	for i in 9:
		run.actions_left = 1
		run.actions_used.clear()
		run.gold = 100
		var next := run.redraw_calling(c, c.progress.calling_offers[1])
		if next == null:
			break
		t.check(next != offers[1] and not c.progress.calling_aside.has(next), "never one put aside")
	t.eq(c.progress.calling_offers.size(), 3, "always three")
	run.actions_left = 1
	run.actions_used.clear()
	t.eq(run.redraw_block_reason(c, c.progress.calling_offers[1]), "No other calling is left to draw.", "until none is left")
	# Not on a battle day, and not once the calling is taken.
	var run2 := rr.make_run(8501)
	run2.gold = 100
	t.eq(run2.redraw_block_reason(run2.roster[0], run2.roster[0].progress.calling_offers[0]), "Only on free days.", "a free day's errand")
	rr.force_day(run2, RunCalendar.DayType.FREE)
	if run2.event_pending():
		run2.choose(run2.event.choices[0])
	var c2 := run2.roster[0]
	level_to(run2, c2, RunConfig.CALLING_LEVEL)
	var arms: CallingData = null
	for offered in run2.calling_pool:
		if not offered.is_magic():
			arms = offered
			break
	c2.progress.calling_offers[0] = arms
	run2.take_calling(c2, arms)
	t.check(run2.redraw_block_reason(c2, c2.progress.calling_offers[1]).contains("already"), "not after it is taken")


func calling_not_in(offers: Array) -> CallingData:
	for c in lib.callings:
		if not offers.has(c):
			return c
	return null


## A hire joins with the callings shown at the tavern; one joining at level 4 or above is due at once.
## Someone raised in a battle does not go to the Infirmary.
func test_calling_hire_and_raise_in_a_run() -> void:
	var run := rr.make_run(8600)
	for c in run.roster:
		level_to(run, c, 5)
	run.gold = 500
	t.check(not run.tavern_offers.is_empty(), "someone is at the tavern")
	var d := run.tavern_offers[0]
	var shown := run.offer_progress(d).calling_offers.duplicate()
	var hired := run.hire(d)
	t.check(hired != null, "hired")
	t.eq(hired.progress.calling_offers, shown, "they join with the callings shown")
	t.eq(hired.level(), 5, "at the company's level")
	t.check(run.calling_due(hired), "and choose on joining")
	# Raised in battle: not injured at the end.
	var m := run.roster[0]
	m.progress.calling = calling("mender")
	m.progress.calling_lead = Stat.MAG
	var mend := spell("white/mend")
	m.progress.learn_spell(mend)
	var b := run.start_battle(run.fronts[0])
	var down := b.roster[1]
	t.set_injured(down)
	b.injured_ever.append(down)
	t.check(b.cast(b.roster[0], mend, down), "raised")
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	var who := run.lineup[1]
	var report := run.finish_battle(b)
	t.check(not report.injured.has(who.display_name()), "the one raised is not among the injured")
	t.check(not who.injured, "and does not go to the Infirmary")
