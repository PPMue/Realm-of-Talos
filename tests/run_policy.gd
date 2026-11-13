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
## Healers patch up anyone below half HP first, keeping a few uses for battle.
func prepare_party(run: Run) -> void:
	for c in run.roster:
		_equip_best(run, c)
	heal_between_battles(run)
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
	if hp_fraction(run) < 0.8 or spell_fraction(run) < 0.5:
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


## Share of every spell use left across the roster (1.0 with no spells at all).
func spell_fraction(run: Run) -> float:
	var left := 0
	var total := 0
	for c in run.roster:
		for sp in c.progress.known_spells:
			left += c.progress.uses_left(sp)
			total += sp.uses
	return 1.0 if total == 0 else float(left) / total


func heal_between_battles(run: Run) -> void:
	for healer in run.roster:
		for sp in healer.progress.known_spells:
			if not sp.heals or sp.targeting != SpellData.Targeting.ONE_ALLY:
				continue
			for c in run.roster:
				if c.hp * 2 < c.max_hp() and healer.progress.uses_left(sp) > 2:
					run.cast_heal(healer, sp, c)


## Greedy battle play: each ready companion casts a sensible spell if it has one (see cast_spell),
## else uses an affordable art if it has one, otherwise attacks, always at the enemy with the least HP.
func play_battle(b: Battle) -> void:
	var ticks := 0
	while not b.is_over() and ticks < 1000:
		ticks += 1
		if b.can_wait():
			b.wait()
			continue
		var c := b.ready_companions()[0]
		if cast_spell(b, c):
			continue
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


## A simple caster. White: heal whoever is injured or below half HP (an every-ally heal when several
## are hurt), lift debuffs, otherwise now and then a buff on the front. Black: delay an enemy about to
## act, hit every enemy when there are several, prefer an effective spell, else the strongest one.
## Uses are spent sparingly: the last use of each spell is kept for healing emergencies.
func cast_spell(b: Battle, c: CompanionUnit) -> bool:
	var ready: Array[SpellData] = []
	for sp in c.spells():
		if b.can_cast(c, sp):
			ready.append(sp)
	if ready.is_empty():
		return false
	var line := b.line()
	var foes := b.living_enemies()
	# White magic.
	var hurt: Array[CompanionUnit] = []
	var worst: CompanionUnit = null
	for a in line:
		if a.is_injured() or a.hp * 2 < a.max_hp():
			hurt.append(a)
			if worst == null or a.hp * worst.max_hp() < worst.hp * a.max_hp():
				worst = a
	if worst != null:
		var best: SpellData = null
		for sp in ready:
			if not sp.heals:
				continue
			if sp.targeting == SpellData.Targeting.ALL_ALLIES and hurt.size() < 2:
				continue
			if best == null or sp.heal_power > best.heal_power:
				best = sp
		if best != null:
			return b.cast(c, best, worst)
	for sp in ready:
		if sp.cleanse:
			for a in line:
				for e in a.effects:
					if e.is_harmful():
						return b.cast(c, sp, a)
	# Black magic.
	var target: EnemyUnit = null
	for e in foes:
		if target == null or e.hp < target.hp:
			target = e
	for sp in ready:
		if sp.delay_ticks > 0:
			for e in foes:
				if e.countdown <= 1 and not e.delayed and e.pending_action != null and e.pending_action.deals_damage:
					return b.cast(c, sp, e)
	var strike: SpellData = null
	var strike_score := -1.0
	for sp in ready:
		if not sp.deals_damage() or sp.delay_ticks > 0:
			continue
		var score := float(b.spell_forecast(c, sp, target).damage) * b.spell_forecast(c, sp, target).hit / 100.0
		if sp.targeting == SpellData.Targeting.ALL_ENEMIES:
			score = 0.0
			for e in foes:
				var f := b.spell_forecast(c, sp, e)
				score += f.damage * f.hit / 100.0
		if score > strike_score:
			strike_score = score
			strike = sp
	if strike != null and rng.randf() < 0.75:
		return b.cast(c, strike, target)
	# Buffs, now and then, on the front of the line.
	for sp in ready:
		if sp.targets_allies() and not sp.heals and not sp.cleanse and c.progress.uses_left(sp) > 1 and rng.randf() < 0.3:
			return b.cast(c, sp, line[-1])
	return false


## How hard `c` hits with `w`: MAG + Mt for a magic weapon, STR + Mt otherwise.
func _power(c: RunCompanion, w: WeaponData) -> int:
	var st := c.progress.stats()
	return int(st[Stat.MAG if w.is_magic() else Stat.STR]) + w.might


func _equip_best(run: Run, c: RunCompanion) -> void:
	var best := run.inventory.held_by(c)
	for w in run.inventory.unheld():
		if w.data.weapon_type == c.weapon().weapon_type and _power(c, w.data) > _power(c, best.data) \
				and run.inventory.equip_block_reason(c, w) == "":
			best = w
	if best != run.inventory.held_by(c):
		run.equip_weapon(c, best)


## The strongest weapon of the companion's type the shop sells that they can use and is better.
func _upgrade_for(run: Run, c: RunCompanion) -> ShopItemData:
	var best: ShopItemData = null
	for item in run.shop_stock():
		var w := item.weapon
		if w.weapon_type != c.weapon().weapon_type or _power(c, w) <= _power(c, c.weapon()):
			continue
		if not c.progress.can_equip_weapon(w) or item.price > run.gold:
			continue
		if best == null or _power(c, w) > _power(c, best.weapon):
			best = item
	return best
