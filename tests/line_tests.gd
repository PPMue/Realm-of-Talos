extends RefCounted
## Headless tests for battle step 2, "the whole line fights" (design/battle.md): Guard covering a
## neighbour (Battle.guard with a ward, guard_wards, guard_preview) and sounding the retreat
## (Battle.retreat, Run.finish_battle). The recovery cap is tested in run_tests.gd
## (test_recovery_cap, test_recovery_cut_on_injury). Called from run_tests.gd, which owns check() and eq().

const RunRuleTests := preload("res://tests/run_rule_tests.gd")

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_guard_wards,
		test_cover_catches_and_halves,
		test_cover_effect_and_recovery_land_on_the_guard,
		test_cover_misses_the_whole_line,
		test_cover_ends,
		test_guard_preview,
		test_retreat_in_battle,
		test_retreat_in_a_run,
	]


# ---------------------------------------------------------------- helpers

## A single-target blow (STR 10 + 5 against DEF 0: 15 damage), landing every time.
func blow(cd: int = 1) -> EnemyActionData:
	return t.make_action("Strike", cd, EnemyActionData.Targeting.SINGLE, 5)


func line_blow(cd: int = 1) -> EnemyActionData:
	return t.make_action("Sweep", cd, EnemyActionData.Targeting.ALL_COMPANIONS, 5)


func battle(actions: Array, hp: Array = [100, 100, 100], defs: Array = []) -> Battle:
	var cs: Array[CompanionData] = []
	for i in hp.size():
		cs.append(t.make_companion("C%d" % i, hp[i], defs[i] if i < defs.size() else 0))
	var es: Array[EnemyData] = []
	for i in actions.size():
		var acts: Array[EnemyActionData] = [actions[i]]
		es.append(t.make_enemy("E%d" % i, acts, 500))
	return t.make_battle(cs, es)


func events_of(b: Battle, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in b.events:
		if ev.type == type:
			out.append(ev)
	return out


# ---------------------------------------------------------------- cover

## Themselves first, then the standing neighbours in the line; nobody further off, nobody injured.
func test_guard_wards() -> void:
	var b := battle([blow(9)], [100, 100, 100, 100])
	var r := b.roster
	t.eq(b.guard_wards(r[0]), [r[0], r[1]] as Array[CompanionUnit], "the leftmost: themselves and one")
	t.eq(b.guard_wards(r[1]), [r[1], r[0], r[2]] as Array[CompanionUnit], "in the middle: both sides")
	t.set_injured(r[2])
	t.eq(b.guard_wards(r[1]), [r[1], r[0]] as Array[CompanionUnit], "an injured neighbour cannot be covered")
	t.eq(b.guard_wards(r[3]), [r[3]] as Array[CompanionUnit], "and is not stepped over")
	t.eq(b.guard_wards(r[2]).size(), 0, "the injured guard nobody")
	t.check(not b.guard(r[0], r[3]), "not a neighbour: refused")
	t.eq(b.tick, 0, "no turn passed")
	t.check(b.guard(r[0], r[0]), "guarding themselves by name")
	t.eq(events_of(b, "guard")[0].get("ward"), null, "no ward")


## A single blow aimed at the ward lands on the guard: against the guard's DEF, halved, with a cover event
## before it; the ward is untouched and the guard earns the guarding points.
func test_cover_catches_and_halves() -> void:
	var b := battle([blow(1)], [100, 100, 100], [0, 4, 0])
	var guard := b.roster[1]
	var ward := b.roster[2]
	b.enemies[0].pending_target = ward
	t.check(b.guard(guard, ward), "guard the neighbour")
	t.eq(ward.hp, 100, "the ward untouched")
	t.eq(guard.hp, 100 - (15 - 4) / 2, "the guard takes it, DEF 4 and halved: 5")
	var types: Array = b.events.map(func(ev: Dictionary) -> String: return ev.type)
	var at := types.find("cover")
	t.check(at >= 0, "a cover event")
	if at >= 0:
		var ev: Dictionary = b.events[at]
		t.check(ev.guard == guard and ev.ward == ward and ev.enemy == b.enemies[0] and ev.action == b.enemies[0].last_action, "its fields")
		t.check(types.find("damage", at) > at, "before the strike's own events")
	t.check(events_of(b, "guard")[0].ward == ward, "the guard event names the ward")
	t.eq(b.points_of(guard), BattleConfig.POINTS_BLOW_TAKEN_GUARDING, "guarding points for the caught blow")
	t.eq(b.points_of(ward), 0, "none for the ward")
	t.check(b.log_lines.any(func(l: String) -> bool: return l.contains("guards C2")), "a log line")
	# A blow aimed at someone else is not caught.
	var b2 := battle([blow(1)])
	b2.enemies[0].pending_target = b2.roster[0]
	b2.guard(b2.roster[1], b2.roster[2])
	t.eq(b2.roster[0].hp, 85, "aimed elsewhere: lands there in full")
	t.eq(events_of(b2, "cover").size(), 0, "no cover")


## The caught action's effect and added recovery land on the guard, not the ward.
func test_cover_effect_and_recovery_land_on_the_guard() -> void:
	var a := blow(1)
	a.effect = t.make_effect("Dazed", {Stat.SPD: -2}, 3)
	a.add_recovery = 2
	var b := battle([a])
	var guard := b.roster[1]
	var ward := b.roster[2]
	b.enemies[0].pending_target = ward
	b.guard(guard, ward)
	t.check(guard.has_effect("Dazed") and not ward.has_effect("Dazed"), "the effect on the guard")
	t.eq(guard.recovery, 2 + 2, "the guard: its own 2 (three standing) and 2 from the blow")
	t.eq(ward.recovery, 0, "the ward: none")


## Blows on the whole line are not caught: the ward takes theirs in full, the guard theirs halved.
func test_cover_misses_the_whole_line() -> void:
	var b := battle([line_blow(1)])
	b.guard(b.roster[1], b.roster[2])
	t.eq(b.roster[2].hp, 85, "the ward in full")
	t.eq(b.roster[1].hp, 93, "the guard halved")
	t.eq(b.roster[0].hp, 85, "the other in full")
	t.eq(events_of(b, "cover").size(), 0, "nothing caught")


## The cover ends with the turn, and at once when the guard or the ward is injured.
func test_cover_ends() -> void:
	# With the turn: a blow landing the turn after lands on the ward.
	var b := battle([blow(2)])
	var ward := b.roster[2]
	b.enemies[0].pending_target = ward
	b.guard(b.roster[1], ward)
	t.eq(ward.hp, 100, "nothing yet")
	b.attack(b.roster[0], b.enemies[0])
	t.eq(ward.hp, 85, "next turn: the ward takes it")
	# The guard falls to the first caught blow: the second lands on the ward.
	var b2 := battle([blow(1), blow(1)], [100, 5, 100])
	var w2 := b2.roster[2]
	b2.enemies[0].pending_target = w2
	b2.enemies[1].pending_target = w2
	b2.guard(b2.roster[1], w2)
	t.check(b2.roster[1].is_injured(), "the guard falls catching the first")
	t.eq(w2.hp, 85, "the second reaches the ward")
	t.eq(events_of(b2, "cover").size(), 1, "one caught")
	# The ward falls to a blow on the whole line: the cover is gone, the blow aimed at them is drawn again.
	var b3 := battle([line_blow(1), blow(1)], [100, 100, 10])
	var w3 := b3.roster[2]
	b3.enemies[1].pending_target = w3
	b3.guard(b3.roster[1], w3)
	t.check(w3.is_injured(), "the ward falls to the sweep")
	t.eq(events_of(b3, "cover").size(), 0, "nothing to catch any more")
	t.check(b3._cover_ward == null and b3._cover_guard == null, "the cover is cleared")


# ---------------------------------------------------------------- preview

## What the guard and the ward would take this turn, every blow landing: only actions due this turn,
## the guard's blows halved, a caught blow on the guard, the ward's whole-line blows and damage over time.
func test_guard_preview() -> void:
	var b := battle([blow(1), line_blow(1), blow(2)], [100, 20, 10])
	var guard := b.roster[1]
	var ward := b.roster[2]
	b.enemies[0].pending_target = ward
	b.enemies[2].pending_target = guard
	var p := b.guard_preview(guard, ward)
	var who: Array = p.blows.map(func(x: Dictionary) -> EnemyUnit: return x.enemy)
	t.eq(who, [b.enemies[0], b.enemies[1]], "the caught blow and the sweep; not the one due next turn")
	t.eq(p.blows.map(func(x: Dictionary) -> bool: return x.whole_line), [false, true], "whole_line")
	t.eq(p.blows.map(func(x: Dictionary) -> int: return (x.forecast as AttackForecast).damage), [7, 7], "both halved")
	t.eq(p.damage, 14, "the guard loses 14")
	t.check(not p.falls, "and stands")
	t.eq(p.ward_damage, 15, "the ward still takes the sweep")
	t.check(p.ward_falls, "and falls to it (10 Health)")
	t.check(not guard.has_effect("Guard") and guard.effects.is_empty(), "the preview leaves no Guard behind")
	# Guarding themselves: only what is aimed at them or the whole line.
	var self_p := b.guard_preview(guard)
	t.eq(self_p.blows.size(), 1, "only the sweep")
	t.eq(self_p.damage, 7, "halved")
	t.eq([self_p.ward_damage, self_p.ward_falls], [self_p.damage, self_p.falls], "the ward's figures are their own")
	t.eq(b.guard_preview(guard, guard).damage, 7, "the same with themselves as the ward")
	# Damage over time counts after the blows.
	var poison: StatusEffectData = t.make_effect("Poison", {}, 3)
	poison.damage_per_tick = 4
	b._apply_effect(ward, poison, false)
	b._apply_effect(guard, poison, false)
	var dp := b.guard_preview(guard, ward)
	t.eq(dp.damage, 18, "the guard: 14 and 4 of poison")
	t.eq(dp.ward_damage, 15, "the ward falls to the sweep before the poison")
	# And then it happens so.
	var hp := guard.hp
	b.guard(guard, ward)
	t.eq(hp - guard.hp, dp.damage, "the battle agrees: the guard")
	t.check(ward.is_injured(), "the battle agrees: the ward")
	# A guard who would fall: falls true. With 10 they catch both and fall on the second; with 5 they fall
	# on the first and the second reaches the ward.
	for row: Array in [[10, 0], [5, 15]]:
		var b2 := battle([blow(1), blow(1)], [100, row[0], 100])
		b2.enemies[0].pending_target = b2.roster[2]
		b2.enemies[1].pending_target = b2.roster[2]
		var p2 := b2.guard_preview(b2.roster[1], b2.roster[2])
		t.check(p2.falls, "guard with %d: falls" % row[0])
		t.eq(p2.ward_damage, row[1], "guard with %d: the ward takes %d" % row)
		b2.guard(b2.roster[1], b2.roster[2])
		t.eq(100 - b2.roster[2].hp, row[1], "guard with %d: the battle agrees" % row[0])


# ---------------------------------------------------------------- retreat

## Not unless allowed; then at once: no turn passes, nothing lands, a DEFEAT with `retreated`.
func test_retreat_in_battle() -> void:
	var b := battle([blow(1)])
	t.check(not b.can_retreat(), "not allowed by default")
	t.check(not b.retreat(), "refused")
	b.allow_retreat = true
	t.check(b.can_retreat(), "allowed")
	b.attack(b.roster[0], b.enemies[0])
	var tick := b.tick
	var hps: Array = b.roster.map(func(c: CompanionUnit) -> int: return c.hp)
	var countdown := b.enemies[0].countdown
	t.check(b.retreat(), "the retreat")
	t.check(b.is_over() and b.outcome == Battle.Outcome.DEFEAT and b.retreated, "lost, retreated")
	t.eq(b.tick, tick, "no turn passed")
	t.eq(b.roster.map(func(c: CompanionUnit) -> int: return c.hp), hps, "nothing landed")
	t.eq(b.enemies[0].countdown, countdown, "the enemy did not move")
	t.eq(events_of(b, "retreat").size(), 1, "a retreat event")
	t.check(b.learned, "what was earned is learned")
	t.check(not b.can_retreat() and not b.retreat(), "once")
	# On the first turn too.
	var first := battle([blow(1)])
	first.allow_retreat = true
	t.check(first.retreat(), "before anyone acts")


## In a run: allowed in a battle and an elite fight, never a boss's; the walls pay and the battle counts
## as lost, but only those already injured go to the Infirmary, the others keep their Health.
func test_retreat_in_a_run() -> void:
	var rr = RunRuleTests.new(t)
	var run: Run = rr.make_run(21)
	run.day = 3
	rr.force_day(run, RunCalendar.DayType.BATTLE)
	var front: Front = run.fronts[0]
	var b := run.start_battle(front)
	t.check(b.allow_retreat, "a battle: may retreat")
	var hurt := b.roster[0]
	b._damage_companion(hurt, 999, false)
	b.roster[1].hp = 7
	var walls := run.city_health
	var lost := run.battles_lost
	t.check(b.retreat(), "retreat")
	var report := run.finish_battle(b)
	t.check(report.retreated and not report.won, "the report: retreated, lost")
	t.eq(run.battles_lost, lost + 1, "counted as lost")
	t.check(run.city_health < walls, "the walls pay (%d -> %d)" % [walls, run.city_health])
	t.eq(report.injured.size(), 1, "only the one already injured")
	t.eq(report.xp_gained.size(), 0, "no XP")
	for i in b.roster.size():
		var c: RunCompanion = null
		for rc in run.roster:
			if rc.data == b.roster[i].data:
				c = rc
		if i == 0:
			t.check(c.injured, "the injured one in the Infirmary")
		else:
			t.check(not c.injured and c.hp > 0, "%s not sent to the Infirmary" % c.display_name())
			if i == 1:
				t.check(c.hp >= 7 and c.hp < c.max_hp(), "the hurt one keeps their Health (7, then the day's-end heal: %d)" % c.hp)
	# An elite fight may be retreated from; a boss fight may not.
	var elite: Run = rr.make_run(22)
	elite.day = 6
	elite._begin_day()
	if elite.day_type() == RunCalendar.DayType.ELITE:
		var eb := elite.start_battle(elite.fronts[0])
		t.check(eb.allow_retreat, "an elite fight: may retreat")
	var boss: Run = rr.make_run(4)
	boss.day = 14
	boss._begin_day()
	t.eq(boss.day_type(), RunCalendar.DayType.BOSS, "day 14 is the boss")
	var bb := boss.start_battle(boss.fronts[0])
	t.check(not bb.allow_retreat and not bb.can_retreat() and not bb.retreat(), "a boss: no retreat")
