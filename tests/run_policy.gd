extends RefCounted
## A simple automated player for whole runs, used by the playthrough test. Plays through the rule
## classes only (Run and Battle), never the UI. Not clever; it exists to prove a run can be completed
## and to give numbers to tune against.

var rng: RandomNumberGenerator
## Drills taken at the training ground: Sparring, and proficiency drills.
var sparred := 0
var drilled := 0
## Companions cured in the infirmary, and days given up because nobody could be fielded.
var cured := 0
var yielded := 0
## Scavenging trips by outcome (ScavengeResult.Outcome: full, half, nothing), and companions injured on them.
var scavenged: Array[int] = [0, 0, 0]
var scavenge_injured := 0
## City errands: upgrades bought (Run.Facility -> levels), enchantment levels gained, enchantments
## moved, material swaps.
var upgrades: Dictionary = {}
var enchant_levels := 0
var moves := 0
var swaps := 0

## The order the city is built up in, timber facilities: what helps the company stay in the fight
## first (shorter stays, better overnight heal, stronger walls, XP for the bench), then the rest.
const TIMBER_ORDER := [
	[Run.Facility.INFIRMARY, 1], [Run.Facility.INN, 1], [Run.Facility.MASON, 1], [Run.Facility.BARRACKS, 1],
	[Run.Facility.TAVERN, 1], [Run.Facility.YARD, 1], [Run.Facility.INFIRMARY, 2], [Run.Facility.INN, 2],
	[Run.Facility.WATCHTOWER, 1], [Run.Facility.MASON, 2], [Run.Facility.BARRACKS, 2], [Run.Facility.TAVERN, 2],
	[Run.Facility.YARD, 2], [Run.Facility.WATCHTOWER, 2],
]


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
				if run.lineup.is_empty() and run.yield_block_reason() == "":
					run.yield_day()   # forced: everyone is in the infirmary
					yielded += 1
				else:
					var battle := run.start_battle(pick_front(run))
					play_battle(battle)
					run.finish_battle(battle)
			RunCalendar.DayType.FREE:
				if run.event_pending():
					run.choose(pick_choice(run))
				free_day(run)
	return run.day


## Fields up to four of those not in the infirmary, healthiest at the front (rightmost), and hands out
## the best weapons it can.
## Against a boss that aims at the far end of the line (reversed targeting), the healthiest stand on
## the left instead.
func prepare_party(run: Run) -> void:
	for c in run.roster:
		_equip_best(run, c)
	var by_hp := run.available()
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
	if run.day_type() == RunCalendar.DayType.BOSS and not run.fronts.is_empty() and faces_reversed(run.fronts[0].enemies):
		mirror_line(run)


## True if the enemies' single-target attacks mostly aim reversed (every enemy that has any).
static func faces_reversed(enemies: Array[EnemyData]) -> bool:
	for e in enemies:
		if e.ever_reversed():
			return true
	return false


## Reverses the order of the fielded line.
static func mirror_line(run: Run) -> void:
	var order := run.lineup.duplicate()
	order.reverse()
	for i in order.size():
		run.move_in_line(order[i], i)


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


## One action a day (rest, repair, train or scavenge), so the first that applies: rest before a boss
## if anything is spent, mend badly damaged walls, rest a hurt company, rest a lightly hurt one, mend
## the walls, then with the action still unused scavenge when short of gold (under two drills' worth),
## else train (see train), else scavenge (see scavenge). Every one after the first that succeeds is
## refused, so trying them in order is enough. Between them, the errands that cost gold but never the action: cure (see cure_best), fill
## the line at the tavern, buy upgrades; they are done whether or not the action is spent.
func free_day(run: Run) -> void:
	if run.is_over():
		return
	if run.day_type(run.day + 1) == RunCalendar.DayType.BOSS and (hp_fraction(run) < 1.0 or spell_fraction(run) < 1.0):
		run.rest()
	if run.city_health <= 40:
		run.repair()
	cure_best(run)
	if run.available().size() < RunConfig.MAX_FIELDED and not run.tavern_offers.is_empty():
		run.hire(run.tavern_offers[0])
	if hp_fraction(run) < 0.6 or spell_fraction(run) < 0.5:
		run.rest()
	for c in run.roster:
		var item := _upgrade_for(run, c)
		if item != null and run.buy(item) != null:
			_equip_best(run, c)
	if hp_fraction(run) < 0.8:
		run.rest()
	run.repair()
	if run.gold < 2 * RunConfig.DRILL_COST:
		scavenge(run)
	train(run)
	scavenge(run)
	city_errands(run)
	run.end_free_day()


## At the day's end, with what the action and the repairs left: swap a pile of one material, build up
## the city (timber in TIMBER_ORDER, only while the walls are down 20 or less, keeping a repair's worth then),
## and spend iron ore: the Smithy first, then the line's weapons up to +2, the Gate, the Smithy's
## second level, the line's weapons to their caps, the Gate's second level. Each list stops at the
## first thing it cannot pay for, to save up for it. Enchanting keeps 60 gold back.
func city_errands(run: Run) -> void:
	if run.errand_block_reason() != "":
		return
	_swap_piles(run)
	var missing := run.max_city_health() - run.city_health
	var reserve: int = int(RunConfig.REPAIR_COST.get(RunConfig.TIMBER, 0)) * mini(2, missing / run.repair_amount())
	if missing > 20:
		reserve = 1000   # the walls first: no timber facility while they are down more than 20
	for step: Array in TIMBER_ORDER:
		var f: Run.Facility = step[0]
		if run.facility_level(f) >= step[1]:
			continue
		var cost := run.upgrade_cost(f)
		if run.material(RunConfig.TIMBER) - int(cost.get(RunConfig.TIMBER, 0)) < reserve or not _upgrade(run, f):
			break
	for step: Array in [["up", Run.Facility.SMITHY, 1], ["enchant", 2], ["up", Run.Facility.GATE, 1], ["up", Run.Facility.SMITHY, 2],
			["enchant", 99], ["up", Run.Facility.GATE, 2]]:
		if step[0] == "up":
			if run.facility_level(step[1]) >= step[2]:
				continue
			if not _upgrade(run, step[1]):
				break
		elif not _enchant_line(run, step[1]):
			break


func _upgrade(run: Run, f: Run.Facility) -> bool:
	if not run.upgrade(f):
		return false
	upgrades[f] = int(upgrades.get(f, 0)) + 1
	return true


## Enchants the weapons in the line's hands up to +`up_to` (their caps at most), the least enchanted
## first. False if one was left short for want of ore or gold (to save up), true if all are there.
func _enchant_line(run: Run, up_to: int) -> bool:
	if run.facility_level(Run.Facility.SMITHY) < 1:
		return false
	while true:
		var pick: OwnedWeapon = null
		for c in run.lineup:
			var w := run.inventory.held_by(c)
			if w == null or w.enchant_level >= mini(up_to, Run.enchant_cap(w)):
				continue
			if pick == null or w.enchant_level < pick.enchant_level:
				pick = w
		if pick == null:
			return true
		if run.gold - int(run.enchant_cost(pick).get("gold", 0)) < 60 or run.enchant_block_reason(pick) != "":
			return false
		var r := run.enchant(pick)
		enchant_levels += r.levels_gained
	return true


## A pile: while one material is 8 or more and at least 4 above the other, 2 of it become 1 of the other.
## And while the walls are down 20 or more and the timber is short of a repair, ore becomes timber.
func _swap_piles(run: Run) -> void:
	var need := int(RunConfig.REPAIR_COST.get(RunConfig.TIMBER, 0))
	while run.max_city_health() - run.city_health >= run.repair_amount() and run.material(RunConfig.TIMBER) < need 			and run.swap(RunConfig.IRON_ORE, RunConfig.TIMBER):
		swaps += 1
	for pair in [[RunConfig.IRON_ORE, RunConfig.TIMBER], [RunConfig.TIMBER, RunConfig.IRON_ORE]]:
		while run.material(pair[0]) >= 8 and run.material(pair[0]) >= run.material(pair[1]) + 4:
			if not run.swap(pair[0], pair[1]):
				break
			swaps += 1


## Sends a party to the site with the best expected haul: for each site the party that gives the best
## chance (see best_scavenge_party), the haul valued (gold, 15 a piece of material, half the XP of
## everyone sent) at a full haul's chance plus half of a miss's half haul, less the cost of an injury
## (60 a time) on a high-risk miss. Never high risk the day before a boss, never when nothing is worth it.
func scavenge(run: Run) -> void:
	if run.free_action_block_reason(Run.FreeAction.SCAVENGE) != "":
		return
	var boss_next := run.day_type(run.day + 1) == RunCalendar.DayType.BOSS
	var best: ScavengeSite = null
	var best_party: Array = []
	var best_value := 0.0
	for site in run.scavenge_sites():
		if site.size > run.available().size() or (boss_next and site.risk == ScavengeSite.Risk.HIGH):
			continue
		var party := best_scavenge_party(run, site)
		var p := run.scavenge_chance(site, party) / 100.0
		var haul := site.gold + 15.0 * site.material_count() + 0.5 * site.xp_each * site.size
		var value := haul * (p + (1.0 - p) * RunConfig.SCAVENGE_HALF_CHANCE / 100.0 * 0.5)
		if site.risk == ScavengeSite.Risk.HIGH:
			value -= (1.0 - p) * (1.0 - RunConfig.SCAVENGE_HALF_CHANCE / 100.0) * 60.0
		if value > best_value:
			best_value = value
			best = site
			best_party = party
	if best == null:
		return
	var r := run.scavenge(best, best_party)
	if r != null:
		scavenged[r.outcome] += 1
		if r.injured != null:
			scavenge_injured += 1


## The companions available who give `site` its best chance, one per place (every assignment tried).
func best_scavenge_party(run: Run, site: ScavengeSite) -> Array:
	var best: Array = []
	var best_score := -INF
	for party in _assignments(run.available(), site.size):
		var score := 0
		for i in party.size():
			score += run.scavenge_slot_score(site, i, party[i])
		if score > best_score:
			best_score = score
			best = party
	return best


## Every ordered pick of `n` different companions from `pool`.
func _assignments(pool: Array[RunCompanion], n: int) -> Array:
	if n == 0:
		return [[]]
	var out: Array = []
	for c in pool:
		var rest: Array[RunCompanion] = pool.duplicate()
		rest.erase(c)
		for tail: Array in _assignments(rest, n - 1):
			out.append([c] + tail)
	return out


## With nothing better to do: a proficiency drill in the type of the weapon held by a fielded
## companion who can take it (the lowest grade first), else Sparring for the lowest-level fielded one.
## Refused (and nothing happens) when the day's action is spent or the gold is short.
func train(run: Run) -> void:
	if run.free_action_block_reason(Run.FreeAction.TRAIN) != "":
		return
	var best_drill: Drill = null
	var best_c: RunCompanion = null
	var best_grade := 99
	# A drill in the second type of a two-proficiency weapon the company owns or the smithy stocks,
	# when a fielded companion is short only of that grade and the weapon would raise their Attack.
	# This is the only time it opens a new weapon type or school (a drill from E).
	for d in run.drills:
		if not d.is_proficiency():
			continue
		for c in run.lineup:
			if run.drill_block_reason(d, c) == "" and _hybrid_wants(run, c, d):
				best_drill = d
				best_c = c
				break
		if best_drill != null:
			break
	for d in run.drills:
		if best_drill != null:
			break
		if d.kind != Drill.Kind.WEAPON:
			continue
		for c in run.lineup:
			if c.weapon() == null or c.weapon().weapon_type != d.weapon_type or run.drill_block_reason(d, c) != "":
				continue
			if d.grade_of(c.progress) <= Proficiency.Grade.E:
				continue   # never opens a type except for a two-proficiency weapon (above)
			if d.grade_of(c.progress) < best_grade:
				best_grade = d.grade_of(c.progress)
				best_drill = d
				best_c = c
	if best_drill == null:
		for c in run.lineup:
			if run.drill_block_reason(run.drills[0], c) == "" and (best_c == null or c.level() < best_c.level()):
				best_c = c
		best_drill = run.drills[0] if best_c != null else null
	if best_drill != null and run.train(best_drill, best_c) != null:
		if best_drill.is_proficiency():
			drilled += 1
		else:
			sparred += 1


## True if a two-proficiency weapon of `c`'s type, owned and unheld or in the smithy's stock, needs a
## second grade in what `drill` trains that `c` lacks, `c` meets its main grade, and it would raise
## `c`'s Attack.
func _hybrid_wants(run: Run, c: RunCompanion, drill: Drill) -> bool:
	var options: Array[WeaponData] = []
	for w in run.inventory.unheld():
		options.append(w.data)
	for item in run.shop_stock():
		options.append(item.weapon)
	for w in options:
		var second := w.second_type == drill.weapon_type if drill.kind == Drill.Kind.WEAPON else w.second_school == drill.school
		if not w.has_second_requirement() or not second or w.weapon_type != c.weapon().weapon_type:
			continue
		if c.progress.grade(w.weapon_type) < w.required_grade or drill.grade_of(c.progress) >= w.second_grade:
			continue
		if _power(c, w) > _power(c, c.weapon()):
			return true
	return false


## While the line is short, cures companions from the infirmary when the gold is there and they are
## among the company's best (the four highest levels) and would otherwise miss a battle or boss day
## before coming out by themselves. The highest level first.
func cure_best(run: Run) -> void:
	while _cure_one(run):
		pass


func _cure_one(run: Run) -> bool:
	if run.free_action_block_reason(Run.FreeAction.CURE) != "" or run.available().size() >= RunConfig.MAX_FIELDED:
		return false
	var by_level := run.roster.duplicate()
	by_level.sort_custom(func(a: RunCompanion, b: RunCompanion) -> bool: return a.level() > b.level())
	var best := by_level.slice(0, RunConfig.MAX_FIELDED)
	var pick: RunCompanion = null
	for c in run.infirmary():
		if not best.has(c) or run.cure_block_reason(c) != "":
			continue
		var misses := false
		for d in range(run.day + 1, c.back_on_day):
			misses = misses or run.day_type(d) == RunCalendar.DayType.BATTLE or run.day_type(d) == RunCalendar.DayType.BOSS
		if not misses:
			continue
		if pick == null or c.level() > pick.level():
			pick = c
	if pick != null and run.cure(pick):
		cured += 1
		return true
	return false


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


## Greedy battle play: each ready companion casts a sensible spell if it has one (see cast_spell),
## else uses an affordable art if it has one, otherwise attacks, always at the enemy with the least HP.
## It answers the mechanics in obvious ways: it never strikes an enemy whose reflecting stance is up
## (it hits another, or guards or focuses instead), and it guards when a heavy blow it is the likely
## target of lands next tick.
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
		if should_guard(b, c):
			b.guard(c)
			continue
		var foes: Array[EnemyUnit] = []
		for e in b.living_enemies():
			if e.reflect_percent() <= 0:
				foes.append(e)
		if foes.is_empty():
			# Every enemy left is behind a reflecting stance: wait it out.
			if c.stamina < c.max_stamina():
				b.focus(c)
			else:
				b.guard(c)
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
		if not done:
			b.attack(c, target)


## Guard when an enemy acts next tick with a heavy single blow, this companion is its most likely
## target (at least half the weight), and the blow would take at least 40% of its HP.
func should_guard(b: Battle, c: CompanionUnit) -> bool:
	if b.is_lone_companion(c):
		return false
	for e in b.living_enemies():
		var a := e.pending_action
		if a == null or e.countdown != 1 or not a.deals_damage or a.targeting != EnemyActionData.Targeting.SINGLE:
			continue
		var weights := b.target_weights(e.aims_reversed(a))
		var total := 0.0
		for w in weights:
			total += w
		var i := b.line().find(c)
		if i < 0 or total <= 0.0 or weights[i] / total < 0.5:
			continue
		var f := CombatMath.forecast(e, a.might, a.hit, 0, c, 0, a.damage_type)
		if f.damage * 5 >= c.hp * 2:
			return true
	return false


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
				if e.delayed or e.pending_action == null or not e.pending_action.deals_damage:
					continue
				# A long charged attack on everyone: delay it as it comes due. Anything else: just before it lands.
				var charged := e.pending_action.targeting == EnemyActionData.Targeting.ALL_COMPANIONS \
					and e.pending_action.countdown >= 6
				if e.countdown <= 1 or (charged and e.countdown <= 2):
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


## How hard `c` hits with `w`: attack power by weapon type + Mt (RunCompanion.attack).
func _power(c: RunCompanion, w: WeaponData) -> int:
	return c.attack(w)


func _equip_best(run: Run, c: RunCompanion) -> void:
	var best := run.inventory.held_by(c)
	for w in run.inventory.unheld():
		if w.data.weapon_type == c.weapon().weapon_type and _power(c, w.data) > _power(c, best.data) \
				and run.inventory.equip_block_reason(c, w) == "":
			best = w
	var old := run.inventory.held_by(c)
	if best != old:
		if old.enchant_level > 0 and run.move_enchant_block_reason(old, best) == "":
			run.move_enchant(old, best)   # the enchantment goes with them to the better weapon
			moves += 1
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
