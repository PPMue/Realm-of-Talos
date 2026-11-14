extends SceneTree
## Measures how battles play out, for judging the battle rules (not a test: nothing is asserted).
## Run:  godot --headless --path . -s res://tools/battle_probe.gd
## PROBE_RUNS (default 12) whole runs are played by the automated player (tests/run_policy.gd). Every
## battle it meets is also replayed PROBE_REPLAYS (default 6) times from the same starting state, with
## fresh dice, by each of four players:
##   greedy    the automated player's battle play: the first ready companion acts
##   strongest the same, but whoever of the ready would deal the most acts (a healer when someone is hurt)
##   random    a random ready companion makes a plain Attack on a random enemy
##   reader    strongest, but it reads the enemy's hand (Battle.incoming, falls_on_turn): when someone
##             would fall this turn it fells an enemy whose blow lands on them if it can, else has a
##             free neighbour shield them (Battle.guard_preview), pushes the blow back with a
##             staggering art, or has them guard, if that saves them
## Every player but the random one sounds the retreat as the automated player does (should_retreat),
## and a retreat counts as a battle lost.
## It prints: how long battles are, how the actions are shared along the line, how hard single enemy
## blows are, how often the same battle is won on a replay, and how the three players compare.

const RunPolicyScript := preload("res://tests/run_policy.gd")

enum Mode { GREEDY, STRONGEST, RANDOM, READER }
const MODE_NAMES := ["greedy", "strongest", "random", "reader"]
const MODES := 4

var _replays := 6
var _held: Array[Resource] = []
## One row per battle met: {"day", "kind", "size", "p": [win share by mode], ...}.
var _rows: Array[Dictionary] = []
## Sums over every replay, by mode.
var _stats: Array[Dictionary] = []


class Probe extends RunPolicyScript:
	var owner_tree: SceneTree
	var run_ref: Run

	func play(run: Run) -> int:
		run_ref = run
		return super.play(run)

	func play_battle(b: Battle) -> void:
		owner_tree.call("measure", run_ref, b)
		super.play_battle(b)


func _init() -> void:
	var runs := int(OS.get_environment("PROBE_RUNS")) if OS.get_environment("PROBE_RUNS") != "" else 12
	if OS.get_environment("PROBE_REPLAYS") != "":
		_replays = int(OS.get_environment("PROBE_REPLAYS"))
	_hold("res://data")
	for m in MODES:
		_stats.append({"battles": 0, "ticks": 0, "actions": 0, "waits": 0, "guards": 0, "top1": 0.0, "top2": 0.0,
			"blows": 0, "blows_half": 0, "blows_fell": 0, "blows_fell_full": 0, "misses": 0, "strikes": 0,
			"injured": 0, "fielded": 0, "idle": 0, "attacks": 0, "arts": 0, "spells": 0, "focuses": 0,
			"covers": 0, "retreats": 0, "staggers": 0, "four": 0, "top2_four": 0.0, "won": 0, "injured_won": 0})
	var started := Time.get_ticks_msec()
	for s in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + s
		var run := Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts,
			SpellLibrary.load_default().spells)
		var prng := RandomNumberGenerator.new()
		prng.seed = 5000 + s
		var policy := Probe.new(prng)
		policy.owner_tree = self
		policy.play(run)
		print("run %d: ended day %d, %s (%.0f s)" % [s + 1, run.day, "won" if run.outcome == Run.Outcome.VICTORY else "lost",
			(Time.get_ticks_msec() - started) / 1000.0])
	_report()
	quit(0)


func _hold(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			_held.append(load(dir + "/" + f))
	for d in DirAccess.get_directories_at(dir):
		_hold(dir + "/" + d)


## Replays the battle `b` (not yet begun) from copies of its starting state.
func measure(run: Run, b: Battle) -> void:
	var front := run.committed_front
	var kind := "boss" if front.is_boss else ("elite" if front.is_elite else "battle")
	var row := {"day": run.day, "kind": kind, "size": b.roster.size(), "p": [0.0, 0.0, 0.0, 0.0]}
	for mode in MODES:
		var wins := 0
		for k in _replays:
			var datas: Array[CompanionData] = []
			var party: Array[CompanionProgress] = []
			for c in b.roster:
				datas.append(c.data)
				party.append(c.progress.copy())
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([run.day, mode, k, _rows.size()])
			var copy := Battle.new(datas, front.enemies, rng, party, b.art_pool, b.spell_pool)
			copy.elite = b.elite
			copy.allow_retreat = b.allow_retreat
			for i in b.roster.size():
				copy.roster[i].hp = b.roster[i].hp
			var prng := RandomNumberGenerator.new()
			prng.seed = rng.seed + 7
			if _play(copy, mode, RunPolicyScript.new(prng)):
				wins += 1
		row.p[mode] = float(wins) / _replays
	_rows.append(row)


## Plays `b` to its end as `mode` would. Returns true if it was won.
func _play(b: Battle, mode: int, policy: RefCounted) -> bool:
	var st: Dictionary = _stats[mode]
	var rng: RandomNumberGenerator = policy.rng
	var ticks := 0
	while not b.is_over() and ticks < 1000:
		ticks += 1
		if b.can_wait():
			b.wait()
			st.waits += 1
			_scan(b, st)
			continue
		var ready := b.ready_companions()
		if mode == Mode.RANDOM:
			var foes := b.living_enemies()
			b.attack(ready[rng.randi_range(0, ready.size() - 1)], foes[rng.randi_range(0, foes.size() - 1)])
			st.attacks += 1
			_scan(b, st)
			continue
		# Every player but the random one falls back as the automated player does.
		if mode != Mode.RANDOM and policy.should_retreat(b):
			b.retreat()
			st.retreats += 1
			break
		if mode == Mode.READER and _read(b, ready, st, policy):
			_scan(b, st)
			continue
		var c: CompanionUnit = ready[0]
		if mode == Mode.STRONGEST or mode == Mode.READER:
			c = _strongest(b, ready)
		if policy.cast_spell(b, c):
			st.spells += 1
			_scan(b, st)
			continue
		var ward: CompanionUnit = policy.cover_ward(b, c)
		if ward != null:
			b.guard(c, ward)
			st.guards += 1
			st.covers += 1
			_scan(b, st)
			continue
		var answer: Array = policy.stagger_answer(b, c)
		if not answer.is_empty():
			b.use_art(c, answer[0], answer[1])
			st.arts += 1
			st.staggers += 1
			_scan(b, st)
			continue
		if policy.should_guard(b, c):
			b.guard(c)
			st.guards += 1
			_scan(b, st)
			continue
		var foes: Array[EnemyUnit] = []
		for e in b.living_enemies():
			if e.reflect_percent() <= 0:
				foes.append(e)
		if foes.is_empty():
			if c.stamina < c.max_stamina():
				b.focus(c)
				st.focuses += 1
			else:
				b.guard(c)
				st.guards += 1
			_scan(b, st)
			continue
		var reflecting := foes.size() < b.living_enemies().size()
		var target := foes[0]
		for e in foes:
			if e.hp < target.hp:
				target = e
		var done := false
		for art in c.arts():
			if b.can_use_art(c, art) and rng.randf() < 0.6:
				if art.hits_all_enemies and reflecting:
					break
				done = b.use_art(c, art, target)
				break
		if done:
			st.arts += 1
		else:
			b.attack(c, target)
			st.attacks += 1
		_scan(b, st)
	# Who did the acting.
	var counts: Array[int] = []
	var total := 0
	for c in b.roster:
		counts.append(c.actions_taken)
		total += c.actions_taken
		if c.actions_taken == 0:
			st.idle += 1
		if c.is_injured():
			st.injured += 1
	counts.sort()
	counts.reverse()
	st.battles += 1
	st.ticks += b.tick
	st.actions += total
	st.fielded += b.roster.size()
	if total > 0:
		st.top1 += float(counts[0]) / total
		st.top2 += float(counts[0] + (counts[1] if counts.size() > 1 else 0)) / total
		if counts.size() >= 4:
			st.four += 1
			st.top2_four += float(counts[0] + counts[1]) / total
	var won := b.outcome == Battle.Outcome.VICTORY
	if won:
		st.won += 1
		for c in b.roster:
			if c.is_injured():
				st.injured_won += 1
	return won


## The reader's answer to a blow on the table: for whoever would fall this turn if everything lands,
## fell an enemy whose blow lands on them now (a sure enough strike that kills), else have them guard
## if they are free and half the damage leaves them standing. Returns true if it gave an order.
func _read(b: Battle, ready: Array[CompanionUnit], st: Dictionary, policy: RefCounted) -> bool:
	for victim in b.active_companions():
		if b.falls_on_turn(victim) != 1:
			continue
		var due := 0
		for m in b.incoming(victim):
			if int(m.turns) > 1 or not m.action.deals_damage:
				continue
			due += int(m.forecast.damage)
			var e: EnemyUnit = m.enemy
			if e.reflect_percent() > 0:
				continue
			for c in ready:
				var f := b.forecast(c, e)
				if f.damage * f.strikes >= e.hp and f.hit >= 75:
					b.attack(c, e)
					st.attacks += 1
					return true
		# A neighbour who is free steps in, if that leaves both standing and the guard with half their Health.
		var last_resort: CompanionUnit = null
		for g in ready:
			if g == victim or not b.guard_wards(g).has(victim):
				continue
			var p: Dictionary = b.guard_preview(g, victim)
			if bool(p.falls) or bool(p.ward_falls):
				continue
			if (g.hp - int(p.damage)) * 2 >= g.max_hp():
				b.guard(g, victim)
				st.guards += 1
				st.covers += 1
				return true
			last_resort = g
		# Or the blow is pushed back a turn by whoever has a staggering art to hand.
		for c in ready:
			var answer: Array = policy.stagger_answer(b, c)
			if not answer.is_empty():
				b.use_art(c, answer[0], answer[1])
				st.arts += 1
				st.staggers += 1
				return true
		if ready.has(victim) and b.active_companions().size() > 1 and not victim.has_effect("Guard"):
			var own: Dictionary = b.guard_preview(victim, victim)
			if not bool(own.falls):
				b.guard(victim)
				st.guards += 1
				return true
		if last_resort != null:
			b.guard(last_resort, victim)
			st.guards += 1
			st.covers += 1
			return true
	return false


## Of the ready, a healer when someone is below half and they can heal; else whoever's plain Attack on
## the weakest enemy is worth most.
func _strongest(b: Battle, ready: Array[CompanionUnit]) -> CompanionUnit:
	var hurt := false
	for a in b.active_companions():
		if a.hp * 2 < a.max_hp():
			hurt = true
	if hurt:
		for c in ready:
			for sp in c.spells():
				if sp.heals and b.can_cast(c, sp):
					return c
	var target: EnemyUnit = null
	for e in b.living_enemies():
		if e.reflect_percent() <= 0 and (target == null or e.hp < target.hp):
			target = e
	if target == null:
		return ready[0]
	var best: CompanionUnit = ready[0]
	var best_value := -1.0
	for c in ready:
		var f := b.forecast(c, target)
		var value := f.damage * f.strikes * f.hit / 100.0
		for sp in c.spells():
			if sp.deals_damage() and b.can_cast(c, sp):
				var sf := b.spell_forecast(c, sp, target)
				value = maxf(value, sf.damage * sf.hit / 100.0)
		if value > best_value:
			best_value = value
			best = c
	return best


## Reads the last action's events: enemy blows on companions and how hard they were, and misses.
func _scan(b: Battle, st: Dictionary) -> void:
	for ev in b.events:
		match ev.type:
			"damage":
				if ev.target is CompanionUnit:
					var c := ev.target as CompanionUnit
					var before: int = int(ev.hp) + int(ev.amount)
					st.blows += 1
					if int(ev.amount) * 2 >= c.max_hp():
						st.blows_half += 1
					if int(ev.hp) <= 0:
						st.blows_fell += 1
						if before * 10 >= c.max_hp() * 8:
							st.blows_fell_full += 1
				else:
					st.strikes += 1
			"miss":
				if not (ev.target is CompanionUnit):
					st.misses += 1
					st.strikes += 1


func _report() -> void:
	print("")
	print("=== %d battles met, each replayed %d times by each player ===" % [_rows.size(), _replays])
	for m in MODES:
		var st: Dictionary = _stats[m]
		var n := maxi(1, int(st.battles))
		print("")
		print("%s:" % MODE_NAMES[m])
		print("  turns a battle %.1f; waits %.1f; guards %.2f; fielded %.2f" % [float(st.ticks) / n, float(st.waits) / n,
			float(st.guards) / n, float(st.fielded) / n])
		print("  actions by the busiest companion %.0f%%, by the busiest two %.0f%%; fielded who never acted %.2f a battle" % [
			100.0 * st.top1 / n, 100.0 * st.top2 / n, float(st.idle) / n])
		var acts := maxi(1, int(st.attacks) + int(st.arts) + int(st.spells) + int(st.guards) + int(st.focuses))
		print("  of the actions: Attack %.0f%%, arts %.0f%%, spells %.0f%%, Guard %.0f%%, Focus %.0f%%" % [100.0 * st.attacks / acts,
			100.0 * st.arts / acts, 100.0 * st.spells / acts, 100.0 * st.guards / acts, 100.0 * st.focuses / acts])
		print("  companion strikes that missed %.0f%%" % (100.0 * st.misses / maxi(1, int(st.strikes))))
		print("  enemy blows landed %.1f a battle; taking half of max HP or more %.0f%%; felling %.0f%%; felling from 80%% HP or more %.1f%%" % [
			float(st.blows) / n, 100.0 * st.blows_half / maxi(1, int(st.blows)), 100.0 * st.blows_fell / maxi(1, int(st.blows)),
			100.0 * st.blows_fell_full / maxi(1, int(st.blows))])
		print("  injured a battle %.2f; in battles won %.2f" % [float(st.injured) / n, float(st.injured_won) / maxi(1, int(st.won))])
		print("  with four in the line (%d): actions by the busiest two %.0f%%" % [int(st.four), 100.0 * st.top2_four / maxi(1, int(st.four))])
		print("  guards that shielded a neighbour %.2f a battle; blows staggered to save someone %.2f a battle; retreats %.1f%% of battles" % [
			float(st.covers) / n, float(st.staggers) / n, 100.0 * st.retreats / n])
	print("")
	print("Win share over the replays, all battles: greedy %.0f%%, strongest %.0f%%, random %.0f%%, reader %.0f%%" % [
		100.0 * _mean(0, ""), 100.0 * _mean(1, ""), 100.0 * _mean(2, ""), 100.0 * _mean(3, "")])
	for kind in ["battle", "elite", "boss"]:
		print("  %s (%d): greedy %.0f%%, strongest %.0f%%, random %.0f%%, reader %.0f%%" % [kind, _count(kind), 100.0 * _mean(0, kind),
			100.0 * _mean(1, kind), 100.0 * _mean(2, kind), 100.0 * _mean(3, kind)])
	for week in range(1, 7):
		var n := 0
		var sums := [0.0, 0.0, 0.0, 0.0]
		for r in _rows:
			if (int(r.day) - 1) / 7 + 1 == week:
				n += 1
				for m in MODES:
					sums[m] += float(r.p[m])
		if n > 0:
			print("  week %d (%d): greedy %.0f%%, strongest %.0f%%, random %.0f%%, reader %.0f%%" % [week, n, 100.0 * sums[0] / n,
				100.0 * sums[1] / n, 100.0 * sums[2] / n, 100.0 * sums[3] / n])
	print("")
	print("How settled a battle is before it begins (greedy, share of battles by win share over the replays):")
	var sure_win := 0
	var sure_loss := 0
	var open := 0
	for r in _rows:
		var p := float(r.p[0])
		if p >= 0.9:
			sure_win += 1
		elif p <= 0.1:
			sure_loss += 1
		else:
			open += 1
	var total := maxi(1, _rows.size())
	print("  won 9 times in 10 or more %.0f%%, lost 9 times in 10 or more %.0f%%, in between %.0f%%" % [100.0 * sure_win / total, 100.0 * sure_loss / total,
		100.0 * open / total])
	var by_size := {}
	for r in _rows:
		var e: Array = by_size.get(r.size, [0, 0.0])
		by_size[r.size] = [int(e[0]) + 1, float(e[1]) + float(r.p[0])]
	for size in [1, 2, 3, 4]:
		if by_size.has(size):
			print("  %d in the line: %d battles, greedy wins %.0f%%" % [size, by_size[size][0],
				100.0 * float(by_size[size][1]) / int(by_size[size][0])])


func _mean(mode: int, kind: String) -> float:
	var n := 0
	var sum := 0.0
	for r in _rows:
		if kind == "" or r.kind == kind:
			n += 1
			sum += float(r.p[mode])
	return sum / maxi(1, n)


func _count(kind: String) -> int:
	var n := 0
	for r in _rows:
		if r.kind == kind:
			n += 1
	return n
