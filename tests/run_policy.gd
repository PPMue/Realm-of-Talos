extends RefCounted
## A simple automated player for whole runs, used by the playthrough test. Plays through the rule
## classes only (Run and Battle), never the UI. Not clever; it exists to prove a run can be completed
## and to give numbers to tune against.

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng


## Plays `run` to its end. Returns the number of days played.
func play(run: Run) -> int:
	var guard := 0
	while not run.is_over() and guard < 100:
		guard += 1
		prepare_party(run)
		match run.day_type():
			RunCalendar.DayType.BATTLE, RunCalendar.DayType.BOSS:
				var battle := run.start_battle(pick_front(run))
				play_battle(battle)
				run.finish_battle(battle)
			RunCalendar.DayType.FREE:
				free_day(run)
			RunCalendar.DayType.EVENT:
				run.choose(pick_choice(run))
	return run.day


## Fields up to five, healthiest at the front (rightmost), and hands out the best weapons it can.
func prepare_party(run: Run) -> void:
	for c in run.roster:
		_equip_best(run, c)
	var by_hp := run.roster.duplicate()
	by_hp.sort_custom(func(a: RunCompanion, b: RunCompanion) -> bool: return a.hp < b.hp)
	for c in run.lineup.duplicate():
		run.bench(c)
	var start := maxi(0, by_hp.size() - RunConfig.MAX_FIELDED)
	for i in range(start, by_hp.size()):
		# Badly hurt companions sit out while at least two others can fight.
		var c: RunCompanion = by_hp[i]
		var healthy := by_hp.size() - i - 1
		if c.hp * 3 < c.max_hp() and healthy >= 2 and run.day_type() != RunCalendar.DayType.BOSS:
			continue
		run.field(c)


func hp_fraction(run: Run) -> float:
	var hp := 0
	var total := 0
	for c in run.lineup:
		hp += c.hp
		total += c.max_hp()
	return float(hp) / maxf(1.0, total)


func pick_front(run: Run) -> Front:
	var want := 1
	var frac := hp_fraction(run)
	if run.lineup.size() >= 3 and frac >= 0.6:
		want = 2
	if run.lineup.size() >= 4 and frac >= 0.85:
		want = 3
	var best: Front = null
	for f in run.fronts:
		if f.danger <= want and (best == null or f.danger > best.danger):
			best = f
	if best == null:
		best = run.fronts[0]
		for f in run.fronts:
			if f.danger < best.danger:
				best = f
	return best


func free_day(run: Run) -> void:
	if hp_fraction(run) < 0.8:
		run.rest()
	if run.roster.size() < RunConfig.MAX_FIELDED and not run.tavern_offers.is_empty():
		run.hire(run.tavern_offers[0])
	for c in run.roster:
		var item := _upgrade_for(run, c)
		if item != null and run.buy(item) != null:
			_equip_best(run, c)
	run.repair()
	run.end_free_day()


func pick_choice(run: Run) -> EventChoiceData:
	var best: EventChoiceData = null
	var best_score := -INF
	for ch in run.event.choices:
		if run.choice_block_reason(ch) != "":
			continue
		var score := float(ch.gold) + 3.0 * ch.city_health
		for m: String in ch.materials:
			score += 25.0 * int(ch.materials[m])
		score += 2.0 * ch.companion_hp * run.hp_targets(ch).size()
		if ch.weapon != null:
			score += 80.0
		if score > best_score:
			best_score = score
			best = ch
	return best


## Greedy battle play: each ready companion uses an affordable art if it has one, otherwise attacks,
## always at the enemy with the least HP.
func play_battle(b: Battle) -> void:
	var ticks := 0
	while not b.is_over() and ticks < 1000:
		ticks += 1
		if b.can_wait():
			b.wait()
			continue
		var c := b.ready_companions()[0]
		var foes := b.living_enemies()
		var target := foes[0]
		for e in foes:
			if e.hp < target.hp:
				target = e
		var done := false
		for art in c.arts():
			if b.can_use_art(c, art) and rng.randf() < 0.6:
				done = b.use_art(c, art, target)
				break
		if not done:
			b.attack(c, target)


func _equip_best(run: Run, c: RunCompanion) -> void:
	var best := run.inventory.held_by(c)
	for w in run.inventory.unheld():
		if w.data.weapon_type == c.weapon().weapon_type and w.data.might > best.data.might \
				and run.inventory.equip_block_reason(c, w) == "":
			best = w
	if best != run.inventory.held_by(c):
		run.equip_weapon(c, best)


## The strongest weapon of the companion's type the shop sells that they can use and is better.
func _upgrade_for(run: Run, c: RunCompanion) -> ShopItemData:
	var best: ShopItemData = null
	for item in run.shop_stock():
		var w := item.weapon
		if w.weapon_type != c.weapon().weapon_type or w.might <= c.weapon().might:
			continue
		if not c.progress.can_equip_weapon(w) or item.price > run.gold:
			continue
		if best == null or w.might > best.weapon.might:
			best = item
	return best
