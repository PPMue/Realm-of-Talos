extends RefCounted
## Headless tests for battle step 1, "the enemy's hand is shown" (design/battle.md): the aim is drawn
## when an action is picked and kept (EnemyUnit.pending_target), what moves it (an injury, an effect that
## draws the eye, one that hides), Guard drawing nothing, enemy criticals only from
## EnemyActionData.crit_percent, and the screen's queries Battle.incoming and Battle.falls_on_turn.
## Called from run_tests.gd, which owns check() and eq().

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_aim_drawn_at_the_pick,
		test_aim_kept_when_weights_change,
		test_aim_redrawn_on_injury,
		test_eye_drawn_pulls_every_aim,
		test_hidden_sheds_aims,
		test_guard_draws_nothing,
		test_enemy_crit_only_from_the_action,
		test_incoming,
		test_falls_on_turn,
		test_falls_on_turn_matches_the_battle,
	]


# ---------------------------------------------------------------- helpers

## A single-target blow (STR 10 + 5 against DEF 0: 15 damage), landing every time.
func blow(cd: int = 3, n: String = "Strike") -> EnemyActionData:
	return t.make_action(n, cd, EnemyActionData.Targeting.SINGLE, 5)


func line_blow(cd: int = 3) -> EnemyActionData:
	return t.make_action("Sweep", cd, EnemyActionData.Targeting.ALL_COMPANIONS, 5)


func enemy_of(a: EnemyActionData, n: String = "Foe") -> EnemyData:
	var acts: Array[EnemyActionData] = [a]
	return t.make_enemy(n, acts, 500)


func battle(actions: Array, companions: int = 3, seed_value: int = 1, party: Array[CompanionProgress] = []) -> Battle:
	var cs: Array[CompanionData] = []
	for i in companions:
		cs.append(t.make_companion("C%d" % i))
	var es: Array[EnemyData] = []
	for i in actions.size():
		es.append(enemy_of(actions[i], "E%d" % i))
	return t.make_battle(cs, es, seed_value, party)


## Sets `e`'s pending aim and countdown directly (as if it had been drawn so).
func aim(e: EnemyUnit, c: CompanionUnit, cd: int = -1) -> void:
	e.pending_target = c
	if cd >= 0:
		e.countdown = cd


## One player action that changes nothing on the line: Focus by whoever is ready, else Wait.
func pass_turn(b: Battle) -> void:
	var ready := b.ready_companions()
	if ready.is_empty():
		b.wait()
	else:
		b.focus(ready[0])


func aim_events(b: Battle) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in b.events:
		if ev.type == "aim":
			out.append(ev)
	return out


func fx(n: String, mult: float, ticks: int = 3) -> StatusEffectData:
	var d: StatusEffectData = t.make_effect(n, {}, ticks)
	d.target_weight_mult = mult
	return d


# ---------------------------------------------------------------- tests

## A single-target action draws its target when picked (by the weights: the back most), shows it in the
## "intent" event, and any other targeting has none.
func test_aim_drawn_at_the_pick() -> void:
	var counts := [0, 0, 0]
	for s in 700:
		var b := battle([blow()], 3, s + 1)
		var e := b.enemies[0]
		t.check(e.pending_target != null and b.roster.has(e.pending_target), "seed %d: an aim is drawn" % s)
		counts[b.roster.find(e.pending_target)] += 1
		var shown := false
		for ev in b.events:
			if ev.type == "intent" and ev.enemy == e:
				shown = ev.get("target") == e.pending_target
		t.check(shown, "seed %d: the intent event carries the target" % s)
	var expected := [1.0 / 7.0, 2.0 / 7.0, 4.0 / 7.0]
	for i in 3:
		var share: float = counts[i] / 700.0
		t.check(absf(share - expected[i]) < 0.05, "slot %d aimed at %.3f ~ %.3f" % [i, share, expected[i]])
	var b2 := battle([line_blow()])
	t.check(b2.enemies[0].pending_target == null, "a blow on the whole line has no aim")
	var support: EnemyActionData = t.make_action("Brace", 3, EnemyActionData.Targeting.SELF, 0)
	support.deals_damage = false
	var b3 := battle([support])
	t.check(b3.enemies[0].pending_target == null, "an action on itself has no aim")
	# Mirrored for one that aims from the left.
	var rev := blow()
	rev.reversed_targeting = true
	var left := 0
	for s in 300:
		var b := battle([rev], 3, s + 1)
		if b.enemies[0].pending_target == b.roster[0]:
			left += 1
	t.check(left > 120, "mirrored: the leftmost aimed at most (%d of 300)" % left)


## The blow lands on the companion it was aimed at even when the weights change in between (a weight that
## is not an effect landing: the place, a weapon, a trait), and the next action draws a new aim.
func test_aim_kept_when_weights_change() -> void:
	for s in 60:
		var b := battle([blow(2)], 3, s + 1)
		var e := b.enemies[0]
		var target := e.pending_target
		# Someone else becomes far likelier to be aimed at, without an effect landing.
		var other := b.roster[(b.roster.find(target) + 1) % 3]
		var heavy := StatusEffect.new()
		heavy.display_name = "Test Weight"
		heavy.target_weight_mult = 1000.0
		heavy.ticks_left = 99
		other.add_effect(heavy)
		t.check(e.pending_target == target, "seed %d: the aim does not move with the weights" % s)
		pass_turn(b)
		pass_turn(b)
		t.eq(target.hp, target.max_hp() - 15, "seed %d: the blow lands on the one aimed at" % s)
		for c in b.roster:
			if c != target:
				t.eq(c.hp, c.max_hp(), "seed %d: %s untouched" % [s, c.display_name])
		t.check(e.pending_target != null, "seed %d: the next action is aimed" % s)
		# A delay keeps the aim.
		var kept := e.pending_target
		b.delay_action(e, 2)
		t.check(e.pending_target == kept, "seed %d: a delay keeps the aim" % s)


## The target is injured: every blow aimed at them is drawn again at once among those standing.
func test_aim_redrawn_on_injury() -> void:
	var b := battle([blow(5), blow(4), line_blow(3)])
	var down := b.roster[2]
	aim(b.enemies[0], down)
	aim(b.enemies[1], down)
	aim(b.enemies[2], null)
	var stays := battle([blow(5)])   # (a second battle for the untouched case below)
	b.events.clear()
	b._damage_companion(down, 999, false)
	t.check(down.is_injured(), "injured")
	for i in 2:
		var e := b.enemies[i]
		t.check(e.pending_target != null and e.pending_target != down and e.pending_target.is_active(),
			"enemy %d drawn again among those standing" % i)
	t.check(b.enemies[2].pending_target == null, "the whole-line blow has no aim to move")
	var evs := aim_events(b)
	t.eq(evs.size(), 2, "an aim event for each")
	for ev in evs:
		t.eq(ev.why, "injured", "why: injured")
		t.check(ev.from == down, "from the injured one")
		t.check(ev.target == (ev.enemy as EnemyUnit).pending_target, "to the new target")
	t.check(b.log_lines.any(func(l: String) -> bool: return l.contains("turns on")), "a log line")
	# Aims at someone else stay put.
	var keep := stays.roster[0]
	aim(stays.enemies[0], keep)
	stays._damage_companion(stays.roster[2], 999, false)
	t.check(stays.enemies[0].pending_target == keep, "an aim at someone else is not moved")
	# One enemy's blow injures the target of another acting later the same turn: that one strikes the
	# one it was drawn onto, not the injured.
	var b2 := battle([blow(1), blow(1)], 2, 3)
	b2.roster[0].hp = 10
	aim(b2.enemies[0], b2.roster[0])
	aim(b2.enemies[1], b2.roster[0])
	pass_turn(b2)
	t.check(b2.roster[0].is_injured(), "the first blow injures")
	t.eq(b2.roster[1].hp, b2.roster[1].max_hp() - 15, "the second lands on the other")


## Beacon, Challenge and Phalanx: every pending single blow moves to whoever they land on.
func test_eye_drawn_pulls_every_aim() -> void:
	var beacon: SpellData = load("res://data/spells/white/beacon.tres")
	var challenge: CombatArtData = load("res://data/arts/axe/challenge.tres")
	var phalanx: CombatArtData = load("res://data/arts/spear/phalanx.tres")
	var cases := [["Beacon", beacon.effect], ["Challenge", challenge.self_effect], ["Phalanx", phalanx.self_effect]]
	for row: Array in cases:
		var data: StatusEffectData = row[1]
		t.check(data.target_weight_mult > 1.0, "%s draws the eye" % row[0])
		var b := battle([blow(5), blow(4), line_blow(3)])
		aim(b.enemies[0], b.roster[2])
		aim(b.enemies[1], b.roster[1])
		var to := b.roster[0]
		b.events.clear()
		b._apply_effect(to, data, true, to)
		t.check(b.enemies[0].pending_target == to and b.enemies[1].pending_target == to, "%s: every single aim moves" % row[0])
		t.check(b.enemies[2].pending_target == null, "%s: the whole-line blow is not aimed" % row[0])
		var evs := aim_events(b)
		t.eq(evs.size(), 2, "%s: two aim events" % row[0])
		for ev in evs:
			t.eq(ev.why, "drawn", "%s: why: drawn" % row[0])
		# While it lasts, new aims are drawn with its weight.
		t.eq(b.target_weights()[0], data.target_weight_mult, "%s: its weight counts in new draws" % row[0])
	# Through the spell itself.
	var mb := battle([blow(5), blow(5)], 2)
	mb.roster[1].progress.learn_spell(beacon)
	aim(mb.enemies[0], mb.roster[1])
	aim(mb.enemies[1], mb.roster[1])
	t.check(mb.cast(mb.roster[1], beacon, mb.roster[0]), "Beacon cast")
	t.check(mb.enemies[0].pending_target == mb.roster[0] and mb.enemies[1].pending_target == mb.roster[0],
		"cast Beacon: both aims move to the one it lands on")


## Veil and Fade: blows aimed at them are drawn again among the others; they stay if nobody else stands.
func test_hidden_sheds_aims() -> void:
	var veil: SpellData = load("res://data/spells/white/veil.tres")
	var fade: CombatArtData = load("res://data/arts/dagger/fade.tres")
	for row: Array in [["Veil", veil.effect], ["Fade", fade.self_effect]]:
		var data: StatusEffectData = row[1]
		t.check(data.target_weight_mult < 1.0, "%s hides" % row[0])
		for s in 30:
			var b := battle([blow(5), blow(4)], 3, s + 1)
			var hidden := b.roster[2]
			aim(b.enemies[0], hidden)
			aim(b.enemies[1], b.roster[0])
			b.events.clear()
			b._apply_effect(hidden, data, true, hidden)
			t.check(b.enemies[0].pending_target != hidden and b.enemies[0].pending_target != null,
				"%s seed %d: drawn again among the others" % [row[0], s])
			t.check(b.enemies[1].pending_target == b.roster[0], "%s seed %d: an aim elsewhere stays" % [row[0], s])
			var evs := aim_events(b)
			t.eq(evs.size(), 1, "%s seed %d: one aim event" % [row[0], s])
			if evs.size() == 1:
				t.eq(evs[0].why, "hidden", "why: hidden")
		# Nobody else standing: the aim stays.
		var lone := battle([blow(5)], 2)
		t.set_injured(lone.roster[0])
		aim(lone.enemies[0], lone.roster[1])
		lone._apply_effect(lone.roster[1], data, true, lone.roster[1])
		t.check(lone.enemies[0].pending_target == lone.roster[1], "%s: stays when nobody else stands" % row[0])
		t.eq(aim_events(lone).size(), 0, "%s: no aim event then" % row[0])


## Guard halves the blow but no longer draws the aim: the weights stay and no aim moves.
func test_guard_draws_nothing() -> void:
	t.eq(StatusEffect.guard().target_weight_mult, 1.0, "Guard has no aim multiplier")
	var b := battle([blow(5), blow(5)], 3)
	aim(b.enemies[0], b.roster[2])
	aim(b.enemies[1], b.roster[1])
	var before := b.target_weights()
	t.check(b.guard(b.roster[0]), "guards")
	t.eq(b.enemies[0].pending_target, b.roster[2], "aim kept")
	t.eq(b.enemies[1].pending_target, b.roster[1], "aim kept")
	b.roster[0].add_effect(StatusEffect.guard())
	t.eq(b.target_weights(), before, "weights unchanged by Guard")
	t.eq(b.enemy_forecast(b.enemies[0], b.enemies[0].pending_action, b.roster[0]).damage, 7, "Guard still halves (15 -> 7)")


## No critical from an enemy unless its action has crit_percent; then that chance, shown in the forecast.
func test_enemy_crit_only_from_the_action() -> void:
	var a := blow(1)
	var d := enemy_of(a)
	d.crit = 50
	var es: Array[EnemyData] = [d]
	var b: Battle = t.make_battle(t.three_companions(999), es)
	var e := b.enemies[0]
	t.eq(b.enemy_forecast(e, a, b.roster[0]).crit, 0, "CRT 50 but no crit_percent: 0%")
	var crits := 0
	for i in 200:
		pass_turn(b)
		for ev in b.events:
			if ev.type == "damage" and ev.target is CompanionUnit and ev.crit:
				crits += 1
	t.eq(crits, 0, "no critical in 200 blows")
	a.crit_percent = 30
	t.eq(b.enemy_forecast(e, a, b.roster[0]).crit, 30, "crit_percent 30: 30%")
	a.crit_percent = 100
	var b2: Battle = t.make_battle(t.three_companions(999), es)
	pass_turn(b2)
	var crit := false
	for ev in b2.events:
		if ev.type == "damage" and ev.target is CompanionUnit:
			crit = ev.crit and ev.amount == 30
	t.check(crit, "crit_percent 100: a critical, double damage")


## Everything that will reach a companion, in the order it lands, with forecasts as things stand now.
func test_incoming() -> void:
	var silent: EnemyActionData = t.make_action("Mark", 4, EnemyActionData.Targeting.SINGLE, 0)
	silent.deals_damage = false
	var b := battle([blow(5, "A"), line_blow(), blow(5, "C"), blow(5, "D"), silent], 3)
	var es := b.enemies
	var mid := b.roster[1]
	aim(es[0], mid, 3)
	aim(es[1], null, 2)
	aim(es[2], mid, 2)
	aim(es[3], b.roster[0], 1)
	aim(es[4], mid, 4)
	var inc := b.incoming(mid)
	var order: Array = inc.map(func(x: Dictionary) -> EnemyUnit: return x.enemy)
	t.eq(order, [es[1], es[2], es[0], es[4]], "fewest turns first, then enemy order")
	t.eq(inc.map(func(x: Dictionary) -> int: return x.turns), [2, 2, 3, 4], "turns")
	t.eq(inc.map(func(x: Dictionary) -> bool: return x.whole_line), [true, false, false, false], "whole_line")
	t.check(inc[0].action == es[1].pending_action, "the action")
	t.eq((inc[0].forecast as AttackForecast).damage, 15, "the whole-line blow's damage")
	t.eq((inc[1].forecast as AttackForecast).damage, 15, "a single blow's damage")
	t.eq((inc[3].forecast as AttackForecast).damage, 0, "an action that deals no damage: 0")
	var left := b.incoming(b.roster[0])
	t.eq(left.map(func(x: Dictionary) -> EnemyUnit: return x.enemy), [es[3], es[1]], "the left one: D, then the sweep")
	# The forecast is as things stand now: Guard (on them for the turn) and a weakened enemy show at once.
	mid.add_effect(StatusEffect.guard())
	t.eq((b.incoming(mid)[1].forecast as AttackForecast).damage, 7, "guarding: halved at once")
	mid.effects.clear()
	es[2].add_effect(StatusEffect.from_data(t.make_effect("Weak", {Stat.STR: -4}, 3)))
	t.eq((b.incoming(mid)[1].forecast as AttackForecast).damage, 11, "a weakened enemy: less at once")
	# Dead enemies and injured companions.
	es[2].hp = 0
	t.eq(b.incoming(mid).size(), 3, "a dead enemy's action is gone")
	t.set_injured(mid)
	t.eq(b.incoming(mid).size(), 0, "nothing reaches someone injured")


## The first turn on which they would be felled, all blows landing without criticals, with damage over
## time and a saving trait; 0 if they would stand.
func test_falls_on_turn() -> void:
	# 20 Health, 15 a blow.
	var b := battle([blow(5), blow(5), blow(5)], 3)
	var c := b.roster[1]
	aim(b.enemies[0], c, 2)
	aim(b.enemies[1], b.roster[0], 1)
	aim(b.enemies[2], b.roster[2], 1)
	t.eq(b.falls_on_turn(c), 0, "one blow: still standing at 5")
	aim(b.enemies[1], c, 3)
	t.eq(b.falls_on_turn(c), 3, "two blows: falls on turn 3")
	aim(b.enemies[1], c, 2)
	t.eq(b.falls_on_turn(c), 2, "both on turn 2")
	# Damage over time: 2 a turn for 3 turns, after the blows each turn.
	var poison: StatusEffectData = t.make_effect("Poison", {}, 3)
	poison.damage_per_tick = 2
	var p := battle([blow(5), blow(5), blow(5)], 3)
	var pc := p.roster[1]
	p._apply_effect(pc, poison, false)
	aim(p.enemies[0], p.roster[0], 9)
	aim(p.enemies[1], p.roster[0], 9)
	aim(p.enemies[2], p.roster[0], 9)
	t.eq(p.falls_on_turn(pc), 0, "poison alone: 20 - 6, standing")
	aim(p.enemies[0], pc, 2)
	t.eq(p.falls_on_turn(pc), 3, "blow on 2 (18 -> 3, poison -> 1), poison on 3: falls on 3")
	pc.hp = 3
	aim(p.enemies[0], p.roster[0], 9)
	t.eq(p.falls_on_turn(pc), 2, "3 Health and poison alone: falls on turn 2")
	# Clings to Life: once, a blow that would fell them leaves them at 1 (above 1 Health only).
	var clings: TraitData = TraitLibrary.load_default().find("clings_to_life")
	var cs: Array[CompanionData] = [t.make_companion("C0"), t.make_companion("C1")]
	var party: Array[CompanionProgress] = [CompanionProgress.create(cs[0]), CompanionProgress.create(cs[1])]
	party[1].traits.assign([clings])
	var es: Array[EnemyData] = [enemy_of(blow(5)), enemy_of(blow(5)), enemy_of(blow(5))]
	var k: Battle = t.make_battle(cs, es, 1, party)
	var kc := k.roster[1]
	aim(k.enemies[0], kc, 2)
	aim(k.enemies[1], kc, 3)
	aim(k.enemies[2], k.roster[0], 9)
	t.eq(k.falls_on_turn(kc), 0, "Clings to Life: 20 -> 5 -> 1, standing")
	aim(k.enemies[2], kc, 4)
	t.eq(k.falls_on_turn(kc), 4, "a third blow fells them on turn 4")
	kc.survived_once = true
	t.eq(k.falls_on_turn(kc), 3, "already used: falls on turn 3")
	kc.survived_once = false
	k._apply_effect(kc, poison, false)
	aim(k.enemies[2], k.roster[0], 9)
	t.eq(k.falls_on_turn(kc), 3, "with poison: 18, 3 then 1, saved at 1 on turn 3, poison fells them")
	t.set_injured(kc)
	t.eq(k.falls_on_turn(kc), 0, "someone injured: 0")


## falls_on_turn agrees with what the battle then does, turn by turn, over many seeds (an enemy that has
## acted is set aside, so only the actions foreseen land).
func test_falls_on_turn_matches_the_battle() -> void:
	var poison: StatusEffectData = t.make_effect("Poison", {}, 4)
	poison.damage_per_tick = 3
	var fell_any := 0
	for s in 60:
		var b := battle([blow(2 + s % 3), blow(3 + s % 4), line_blow(4 + s % 2)], 3, s + 1)
		for u in b.roster:
			u.hp = 30 + s % 15
		var c := b.roster[s % 3]
		if s % 2 == 0:
			b._apply_effect(c, poison, false)
		aim(b.enemies[0], c)
		aim(b.enemies[1], c if s % 3 != 0 else b.roster[(s + 1) % 3])
		var predicted := b.falls_on_turn(c)
		var fell := 0
		for turn in range(1, 10):
			if b.is_over() or c.is_injured():
				break
			var before := {}
			for e in b.enemies:
				before[e] = e.countdown
			pass_turn(b)
			for e in b.enemies:
				if e.countdown != int(before[e]) - 1:
					e.countdown = 999   # it acted: set aside
			if c.is_injured():
				fell = turn
		t.eq(fell, predicted, "seed %d: falls on the turn foreseen" % s)
		if fell > 0:
			fell_any += 1
	t.check(fell_any > 5 and fell_any < 60, "some fall, some stand (%d of 60)" % fell_any)
