extends RefCounted
## Headless tests for the city's upgrades (Run.Facility, Run.upgrade), materials (repairs, the swap)
## and enchanting (Run.enchant, Run.move_enchant, OwnedWeapon). Called from run_tests.gd, which owns
## check() and eq().

var t   # the runner (run_tests.gd)

const F := Run.Facility


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_repair_and_swap,
		test_upgrade_rules,
		test_watchtower_knowledge,
		test_watchtower_tomorrow,
		test_tavern,
		test_inn,
		test_infirmary,
		test_drill_yard,
		test_barracks,
		test_mason,
		test_gate,
		test_enchant_rules,
		test_enchant_rolls,
		test_smithy_two_rolls,
		test_enchant_stats_reach_the_holder,
		test_move_enchant,
	]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


## Turns today into a day of `type` without an event and prepares it again.
func force_day(run: Run, type: int) -> void:
	run.calendar[run.day - 1] = type
	run.event_days.erase(run.day)
	run._begin_day()


## A run on a free day 2 with plenty of everything.
func rich_run(seed_value: int = 1) -> Run:
	var run := make_run(seed_value)
	run.day = 2
	force_day(run, RunCalendar.DayType.FREE)
	run.gold = 10000
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	return run


func build(run: Run, f: int, level: int) -> void:
	while run.facility_level(f) < level:
		t.check(run.upgrade(f), "build %s" % Run.FACILITY_NAMES[f])


## Wins today's battle at the first front at once.
func win(run: Run) -> BattleReport:
	var b := run.start_battle(run.fronts[0])
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	return run.finish_battle(b)


func owned(run: Run, tier: int, type: int = WeaponData.WeaponType.SWORD) -> OwnedWeapon:
	return run.inventory.add(run.content.ladder_weapon(tier, type))


# ---------------------------------------------------------------- materials

func test_repair_and_swap() -> void:
	var run := rich_run(2)
	run.materials = {RunConfig.TIMBER: 3, RunConfig.IRON_ORE: 0}
	run.city_health = 50
	t.eq(run.repair_cost(), {RunConfig.TIMBER: 3}, "a repair costs 3 timber and no ore")
	t.check(run.repair(), "repaired with timber alone")
	t.eq(run.material(RunConfig.TIMBER), 0, "3 timber spent")
	t.eq(run.city_health, 70, "+20")
	# The swap: an errand, 2 for 1, any number of times, the action untouched.
	run.materials = {RunConfig.TIMBER: 1, RunConfig.IRON_ORE: 5}
	t.eq(run.swap_block_reason(RunConfig.TIMBER, RunConfig.IRON_ORE), "Needs 2 Timber.", "needs 2")
	t.check(run.swap_block_reason(RunConfig.TIMBER, RunConfig.TIMBER) != "", "two different materials")
	t.check(run.swap_block_reason("gold", RunConfig.TIMBER) != "", "materials only")
	t.check(run.swap(RunConfig.IRON_ORE, RunConfig.TIMBER), "2 ore for 1 timber")
	t.check(run.swap(RunConfig.IRON_ORE, RunConfig.TIMBER), "and again")
	t.eq(run.material(RunConfig.IRON_ORE), 1, "4 ore gone")
	t.eq(run.material(RunConfig.TIMBER), 3, "2 timber come")
	t.check(not run.swap(RunConfig.IRON_ORE, RunConfig.TIMBER), "not with 1")
	t.check(run.swap(RunConfig.TIMBER, RunConfig.IRON_ORE), "the other way")
	t.eq([run.material(RunConfig.TIMBER), run.material(RunConfig.IRON_ORE)], [1, 2], "2 timber for 1 ore")
	t.eq(run.actions_left, 0, "the repair took the action; the swaps took none")
	force_day(run, RunCalendar.DayType.BATTLE)
	t.eq(run.swap_block_reason(RunConfig.IRON_ORE, RunConfig.TIMBER), "Only on free days.", "free days only")


# ---------------------------------------------------------------- upgrades

func test_upgrade_rules() -> void:
	var run := rich_run(3)
	t.eq(Run.facility_max_level(), 2, "two levels")
	t.eq(Run.Facility.size(), 9, "nine facilities")
	for f: int in Run.Facility.values():
		t.eq(run.facility_level(f), 0, "%s starts unbuilt" % Run.FACILITY_NAMES[f])
		t.check(Run.facility_lines(f, 1) != "" and Run.facility_lines(f, 2) != "", "%s: a line for each level" % Run.FACILITY_NAMES[f])
		var m := RunConfig.IRON_ORE if f == F.SMITHY or f == F.GATE else RunConfig.TIMBER
		t.eq(run.upgrade_cost(f), {m: RunConfig.UPGRADE_COST[0]}, "%s level 1 cost" % Run.FACILITY_NAMES[f])
	t.eq(Run.facility_lines(F.WATCHTOWER, 1), "The boss days and which boss comes are known", "worded as in the design")
	t.eq(Run.facility_lines(F.INN, 3), "", "no third level")
	var timber := run.material(RunConfig.TIMBER)
	t.check(run.upgrade(F.INN), "built")
	t.eq(run.facility_level(F.INN), 1, "level 1")
	t.eq(run.material(RunConfig.TIMBER), timber - RunConfig.UPGRADE_COST[0], "paid in timber")
	t.eq(run.upgrade_cost(F.INN), {RunConfig.TIMBER: RunConfig.UPGRADE_COST[1]}, "level 2 costs more")
	t.check(run.upgrade(F.INN), "level 2")
	t.eq(run.upgrade_cost(F.INN), {}, "nothing more")
	t.check(run.upgrade_block_reason(F.INN).contains("full"), "built to the full")
	t.check(not run.upgrade(F.INN), "no third level")
	var ore := run.material(RunConfig.IRON_ORE)
	t.check(run.upgrade(F.SMITHY), "the Smithy")
	t.eq(run.material(RunConfig.IRON_ORE), ore - RunConfig.UPGRADE_COST[0], "paid in iron ore")
	t.eq(run.actions_left, 1, "upgrades never take the day's action")
	run.materials = {RunConfig.TIMBER: 0, RunConfig.IRON_ORE: 0}
	t.eq(run.upgrade_block_reason(F.TAVERN), "Needs %d Timber." % RunConfig.UPGRADE_COST[0], "says what it needs")
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	run.roster[0].hp = 1
	t.check(run.rest(), "the day's action")
	t.check(run.upgrade(F.TAVERN), "and an upgrade after it")
	force_day(run, RunCalendar.DayType.BATTLE)
	t.eq(run.upgrade_block_reason(F.YARD), "Only on free days.", "not on a battle day")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	t.eq(run.upgrade_block_reason(F.YARD), Run.EVENT_FIRST, "not before the event")


func test_watchtower_knowledge() -> void:
	var run := rich_run(4)
	run.day = 9
	force_day(run, RunCalendar.DayType.FREE)
	var ahead := run.upcoming()
	t.eq(run.day_type(14), RunCalendar.DayType.BOSS, "day 14 is a boss day")
	t.eq(ahead[14 - 9], RunCalendar.DayType.BATTLE, "the strip shows it as a battle day")
	t.eq(run.seen_day_type(14), RunCalendar.DayType.BATTLE, "seen as a battle day")
	t.check(not run.boss_days_known(), "the watch does not know")
	t.check(run.boss_on(14) == null, "nor which boss")
	t.check(run.boss_days_ahead().is_empty(), "no boss days ahead are told")
	build(run, F.WATCHTOWER, 1)
	t.check(run.boss_days_known(), "level 1: known")
	t.eq(run.upcoming()[14 - 9], RunCalendar.DayType.BOSS, "marked")
	t.eq(run.boss_on(14), run.boss_draw[14], "and named")
	t.eq(run.boss_days_ahead(), [14, 28, 42] as Array[int], "every boss day ahead")
	# On the boss day itself the boss is there to see.
	var plain := make_run(4)
	plain.day = 14
	plain.calendar[13] = RunCalendar.DayType.BOSS
	plain._begin_day()
	t.eq(plain.boss_on(14), plain.fronts[0].group, "today's boss is named")
	t.eq(plain.seen_day_type(), RunCalendar.DayType.BOSS, "today is a boss day")


func test_watchtower_tomorrow() -> void:
	var run := rich_run(5)
	run.calendar[2] = RunCalendar.DayType.BATTLE   # day 3
	build(run, F.WATCHTOWER, 1)
	t.check(run.tomorrow_fronts().is_empty(), "level 1 does not see the fronts")
	build(run, F.WATCHTOWER, 2)
	var early := run.tomorrow_fronts()
	t.check(not early.is_empty(), "level 2: tomorrow's fronts at once")
	var names: Array = early.map(func(fr: Front) -> String: return fr.group.display_name)
	t.check(run.end_free_day(), "the day ends")
	t.eq(run.day, 3, "tomorrow")
	t.eq(run.fronts, early, "the same fronts")
	t.eq(run.fronts.map(func(fr: Front) -> String: return fr.group.display_name), names, "the same enemies")
	# Every free day before a battle or boss day shows them from its start.
	var seen := 0
	for s in 10:
		var r := make_run(60 + s)
		r.facilities[F.WATCHTOWER] = 2
		r._begin_day()
		while not r.is_over() and r.day < 30:
			var next := r.tomorrow_fronts()
			var tomorrow := r.day_type(r.day + 1)
			t.eq(not next.is_empty(), tomorrow == RunCalendar.DayType.BATTLE or tomorrow == RunCalendar.DayType.BOSS,
				"seed %d day %d: fronts known exactly when tomorrow fights" % [s, r.day])
			if r.day_type() == RunCalendar.DayType.FREE:
				if r.event_pending():
					for ch in r.event.choices:
						if r.choice_block_reason(ch) == "":
							r.choose(ch)
							break
				r.end_free_day()
			else:
				for fr in r.fronts:
					fr.city_damage = 0   # keep the run alive
				var report := win(r)
				t.check(report != null, "won")
			if not next.is_empty() and not r.is_over():
				t.eq(r.fronts, next, "seed %d day %d: the fronts seen yesterday" % [s, r.day])
				seen += 1
	t.check(seen > 20, "checked on many days (%d)" % seen)


func test_tavern() -> void:
	var run := rich_run(6)
	var before := run.tavern_offers.size()
	build(run, F.TAVERN, 1)
	t.eq(run.tavern_offers.size(), before + 1, "level 1: one more offered at once")
	t.check(not run.offer_traits(run.tavern_offers[-1]).is_empty(), "with their traits")
	var counts := {}
	for i in 40:
		run._restock_week()
		counts[run.tavern_offers.size()] = true
	t.check(counts.has(RunConfig.TAVERN_OFFERS_MIN + 1) and counts.has(RunConfig.TAVERN_OFFERS_MAX + 1)
		and not counts.has(RunConfig.TAVERN_OFFERS_MIN), "every week %d-%d" % [RunConfig.TAVERN_OFFERS_MIN + 1, RunConfig.TAVERN_OFFERS_MAX + 1])
	t.eq(run.hire_cost(), 100, "a hire costs 100")
	build(run, F.TAVERN, 2)
	t.eq(run.hire_cost(), 75, "level 2: 25 less")
	run.gold = 75
	t.check(run.hire(run.tavern_offers[0]) != null, "hired for 75")
	t.eq(run.gold, 0, "paid 75")


func test_inn() -> void:
	var run := rich_run(7)
	var c := run.roster[0]
	var heal := run.day_heal(c)
	build(run, F.INN, 1)
	t.eq(run.day_heal(c) if c.traits.is_empty() else run.day_heal(c), ceili(c.max_hp() * 0.3 * (100 + TraitRules.total(c.traits, TraitModifier.Kind.DAY_HEAL_PERCENT)) / 100.0),
		"level 1: 30% overnight")
	t.check(run.day_heal(c) > heal, "more than before")
	var sp: SpellData = SpellLibrary.load_default().spells[0]
	c.progress.learn_spell(sp)
	c.progress.spell_uses[sp] = 0
	run.end_free_day()
	t.eq(c.progress.uses_left(sp), 0, "level 1: no uses back")
	build_on_free_day(run, F.INN, 2)
	run.end_free_day()
	t.eq(c.progress.uses_left(sp), 1, "level 2: one use back each night")
	c.progress.spell_uses[sp] = c.progress.max_uses(sp)
	build_on_free_day(run, F.INN, 2)
	run.end_free_day()
	t.eq(c.progress.uses_left(sp), c.progress.max_uses(sp), "never past full")


func build_on_free_day(run: Run, f: int, level: int) -> void:
	force_day(run, RunCalendar.DayType.FREE)
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	build(run, f, level)


func test_infirmary() -> void:
	var run := rich_run(8)
	var c := run.roster[0]
	c.traits = []
	run._to_infirmary(c)
	t.eq(c.back_on_day, run.day + 5, "4 days")
	var cost4 := run.cure_cost(c)
	build(run, F.INFIRMARY, 1)
	t.eq(c.back_on_day, run.day + 4, "level 1: a stay already running is a day shorter")
	var d := run.roster[1]
	d.traits = []
	run._to_infirmary(d)
	t.eq(d.back_on_day, run.day + 4, "and new stays are 3 days")
	t.eq(run.infirmary_days(d), 3, "3 days")
	var cost3 := run.cure_cost(c)
	t.check(cost3 < cost4, "fewer days left, a cheaper cure")
	build(run, F.INFIRMARY, 2)
	t.eq(run.cure_cost(c), roundi(cost3 * 0.75), "level 2: a quarter less")


func test_drill_yard() -> void:
	var run := rich_run(9)
	var before := run.drills.size()
	build(run, F.YARD, 1)
	var poor := 0
	for i in 300:
		if run._roll_drill_quality() == DrillResult.Quality.POOR:
			poor += 1
	t.eq(poor, 0, "level 1: never poor")
	build(run, F.YARD, 2)
	t.eq(run.drills.size(), mini(before + 1, 1 + 7), "level 2: a third drill posted at once")
	t.check(not run.drills[0].is_proficiency(), "Sparring first")
	var kinds := {}
	for dr in run.drills:
		var key := "%d/%d/%d" % [dr.kind, dr.weapon_type, dr.school]
		t.check(not kinds.has(key), "no drill twice")
		kinds[key] = true
	run._restock_week()
	t.eq(run.drills.size(), 1 + RunConfig.DRILLS_PROFICIENCY_PER_WEEK + RunConfig.YARD_EXTRA_DRILLS, "and every week")


func test_barracks() -> void:
	var run := rich_run(10)
	var spare := run._join(run.content.companions.filter(func(dd: CompanionData) -> bool: return not run._in_roster(dd))[0])
	run.bench(spare)
	t.check(run.reserve().has(spare), "on the bench")
	build(run, F.BARRACKS, 1)
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	var pool: int = run.fronts[0].xp_pool
	var xp_before := spare.progress.xp + Levels.total_xp_for(spare.progress.level)
	var report := win(run)
	var want := Levels.with_traits(spare.progress, roundi(pool / 4.0 * 0.25))
	t.eq(report.reserve_xp.get(spare.display_name(), 0), want, "level 1: a quarter of an even share")
	t.eq(spare.progress.xp + Levels.total_xp_for(spare.progress.level) - xp_before, want, "and it is theirs")
	t.check(not report.xp_gained.has(spare.display_name()), "not among the fielded shares")
	# Level 2: the bench heals fully overnight.
	force_day(run, RunCalendar.DayType.FREE)
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	build(run, F.BARRACKS, 2)
	spare.hp = 1
	var fielded := run.lineup[0]
	fielded.hp = 1
	run.end_free_day()
	t.eq(spare.hp, spare.max_hp(), "the reserve to full")
	t.check(fielded.hp < fielded.max_hp(), "the line only the usual heal")


func test_mason() -> void:
	var run := rich_run(11)
	run.city_health = 50
	build(run, F.MASON, 1)
	t.eq(run.repair_amount(), 30, "level 1: repairs mend 30")
	t.check(run.repair(), "repair")
	t.eq(run.city_health, 80, "+30")
	t.eq(run.max_city_health(), 100, "the walls still hold 100")
	build(run, F.MASON, 2)
	t.eq(run.max_city_health(), 120, "level 2: 120")
	force_day(run, RunCalendar.DayType.FREE)
	run.city_health = 100
	t.eq(run.free_action_block_reason(Run.FreeAction.REPAIR), "", "100 is no longer full")
	t.check(run.repair(), "repair")
	t.eq(run.city_health, 120, "up to 120")


func test_gate() -> void:
	var run := rich_run(12)
	t.eq(run.scavenge_sites().size(), 2, "two sites")
	build(run, F.GATE, 1)
	t.eq(run.scavenge_sites().size(), 3, "level 1: a third at once")
	var names := {}
	for s in run.scavenge_sites():
		names[s.display_name] = true
	t.eq(names.size(), 3, "three different places")
	run.end_free_day()
	while run.day_type() != RunCalendar.DayType.FREE:
		win(run)
	if run.event_pending():
		for ch in run.event.choices:
			if run.choice_block_reason(ch) == "":
				run.choose(ch)
				break
	t.eq(run.scavenge_sites().size(), 3, "and three every free day")
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	build(run, F.GATE, 2)
	for danger in [1, 2, 3]:
		t.eq(run.front_city_damage(danger), RunConfig.CITY_DAMAGE_BY_DANGER[danger - 1] - 5, "level 2: danger %d costs 5 less" % danger)
	run.calendar[run.day] = RunCalendar.DayType.BATTLE
	run.end_free_day()
	for fr in run.fronts:
		t.eq(fr.city_damage, RunConfig.CITY_DAMAGE_BY_DANGER[fr.danger - 1] - 5, "the fronts say so")


# ---------------------------------------------------------------- enchanting

func test_enchant_rules() -> void:
	var run := rich_run(13)
	var w := owned(run, WeaponData.Tier.IRON)
	t.check(run.enchant_block_reason(w).contains("smithy"), "not before the Smithy is built up")
	build(run, F.SMITHY, 1)
	t.eq(run.enchant_block_reason(w), "", "then open")
	t.eq(run.enchant_cost(w), {RunConfig.IRON_ORE: 1, "gold": 40}, "iron: 1 ore and 20 x 2 gold")
	t.eq(run.enchant_cost(owned(run, WeaponData.Tier.WOODEN)), {RunConfig.IRON_ORE: 1, "gold": 20}, "wooden: 20 gold (the tier, at least 1)")
	t.eq(run.enchant_cost(owned(run, WeaponData.Tier.PLATINUM)), {RunConfig.IRON_ORE: 1, "gold": 100}, "platinum: 100")
	t.eq(run.enchant_cost(run.inventory.add(run.content.rare_weapons[0])), {RunConfig.IRON_ORE: 1, "gold": 60}, "a rare weapon: 60")
	var ore := run.material(RunConfig.IRON_ORE)
	var gold := run.gold
	var offer := run.enchant(w)
	t.check(offer != null, "an offer")
	t.eq(run.enchant_offer, offer, "kept open")
	t.eq(offer.weapon, w, "for the weapon")
	t.eq(offer.current, {}, "it is plain now")
	t.eq(offer.rolls.size(), 1, "level 1: one new roll")
	t.eq(run.material(RunConfig.IRON_ORE), ore - 1, "1 ore paid")
	t.eq(run.gold, gold - 40, "40 gold paid")
	t.eq(offer.cost, {RunConfig.IRON_ORE: 1, "gold": 40}, "the cost on the offer")
	t.check(not w.is_enchanted(), "nothing changes before the choice")
	t.eq(run.enchant_block_reason(w), Run.OFFER_OPEN, "no new attempt while it is open")
	t.eq(run.move_enchant_block_reason(w, owned(run, WeaponData.Tier.STEEL)), Run.OFFER_OPEN, "nor a move")
	# Keep: plain stays plain, the cost is spent.
	t.check(run.keep_enchant(), "kept")
	t.check(run.enchant_offer == null and not w.is_enchanted(), "plain, the offer gone")
	t.check(not run.keep_enchant() and not run.take_enchant(0), "nothing to choose now")
	# Take.
	offer = run.enchant(w)
	var roll: Dictionary = offer.rolls[0]
	t.check(not run.take_enchant(1), "no second roll at level 1")
	t.check(run.take_enchant(0), "taken")
	t.eq(w.enchant_stats, roll, "the weapon has the roll")
	t.check(w.is_enchanted(), "enchanted")
	t.eq(w.title(), "%s+" % w.data.display_name, "named with a +")
	t.eq(w.enchant_lines(), OwnedWeapon.stat_lines(roll), "its lines")
	# Again: the current one is offered beside the new.
	offer = run.enchant(w)
	t.eq(offer.current, roll, "the enchantment it has, to keep")
	t.eq(run.enchant_cost(w), {RunConfig.IRON_ORE: 1, "gold": 40}, "a second try costs the same")
	run.keep_enchant()
	t.eq(w.enchant_stats, roll, "kept: unchanged")
	t.eq(run.actions_left, 1, "never the day's action")
	# The day ends with an offer open: the weapon keeps what it has.
	run.enchant(w)
	t.check(run.end_free_day(), "the day ends")
	t.check(run.enchant_offer == null, "the offer is gone")
	t.eq(w.enchant_stats, roll, "and the weapon kept its enchantment")
	# Short of ore or gold; not the company's; free days only.
	run = rich_run(14)
	build(run, F.SMITHY, 1)
	w = owned(run, WeaponData.Tier.IRON)
	run.materials[RunConfig.IRON_ORE] = 0
	t.check(run.enchant_block_reason(w).begins_with("Needs"), "needs the ore")
	run.materials[RunConfig.IRON_ORE] = 100
	run.gold = 0
	t.check(run.enchant_block_reason(w).contains("gold"), "and the gold")
	run.gold = 1000
	t.check(run.enchant_block_reason(OwnedWeapon.new(w.data)) != "", "only the company's weapons")
	force_day(run, RunCalendar.DayType.BATTLE)
	t.eq(run.enchant_block_reason(w), "Only on free days.", "free days only")


func test_enchant_rolls() -> void:
	var run := rich_run(15)
	t.eq(RunConfig.ENCHANT_BUDGET_BY_TIER, [1, 2, 3, 4, 5, 6] as Array[int], "budgets by tier")
	for tier in 6:
		t.eq(Run.enchant_budget(owned(run, tier)), tier + 1, "tier %d: budget %d" % [tier, tier + 1])
	t.eq(Run.enchant_budget(run.inventory.add(run.content.rare_weapons[0])), 4, "a rare weapon 4")
	var seen := {}
	for budget in [1, 2, 3, 4, 5, 6]:
		var edged := 0
		var ks := {}
		var n := 1500
		for i in n:
			var roll := run.roll_enchant(budget)
			var net := 0
			var negatives := 0
			var positive := 0
			for key: String in roll:
				t.check(Stat.COMPANION_KEYS.has(key), "a companion stat")
				var v := int(roll[key])
				t.check(v != 0, "no stat at 0")
				net += v
				if v < 0:
					negatives += 1
					ks[-v] = true
				else:
					positive += v
				seen[key] = true
			if net != budget or negatives > 1:
				t.check(false, "budget %d: net %d, %d negative (%s)" % [budget, net, negatives, str(roll)])
			if negatives == 1:
				edged += 1
				t.check(positive > budget, "the points the negative took are rolled again")
		var want := 0.25 if budget >= 2 else 0.0
		t.check(absf(edged / float(n) - want) < 0.035, "budget %d: two-edged %.3f, about %d%%" % [budget, edged / float(n), roundi(want * 100)])
		if budget >= 2:
			t.eq(ks.size(), budget / 2, "budget %d: the negative is 1 to %d" % [budget, budget / 2])
			t.check(not ks.has(budget / 2 + 1), "never more")
	t.eq(seen.size(), 11, "all eleven stats come up")
	t.eq(RunConfig.ENCHANT_TWO_EDGED_PERCENT, 25, "25%")
	# Lines: positives in stat order, the negative last.
	t.eq(OwnedWeapon.stat_lines({Stat.LCK: -1, Stat.DEX: 1, Stat.STR: 2}), ["+2 Strength", "+1 Dexterity", "-1 Luck"] as Array[String], "lines")


func test_smithy_two_rolls() -> void:
	var run := rich_run(16)
	build(run, F.SMITHY, 2)
	t.eq(Run.facility_lines(F.SMITHY, 2), "The smith offers two enchantments to choose from", "its line")
	var w := owned(run, WeaponData.Tier.STEEL)
	var offer := run.enchant(w)
	t.eq(offer.rolls.size(), 2, "level 2: two new rolls")
	for roll in offer.rolls:
		var net := 0
		for key: String in roll:
			net += int(roll[key])
		t.eq(net, 4, "each the steel budget")
	var second: Dictionary = offer.rolls[1]
	t.check(run.take_enchant(1), "the second taken")
	t.eq(w.enchant_stats, second, "the weapon has it")


func test_enchant_stats_reach_the_holder() -> void:
	var run := rich_run(17)
	build(run, F.SMITHY, 1)
	var c := run.lineup[0]
	var w := run.inventory.held_by(c)
	var before := c.progress.stats()
	var attack := c.attack()
	run._set_enchant(w, {Stat.STR: 2, Stat.DEX: 1, Stat.LCK: -1})
	t.eq(c.progress.enchant_stat_bonus(Stat.STR), 2, "the split: 2 STR from the enchantment")
	t.eq(c.progress.enchant_stat_bonus(Stat.LCK), -1, "and -1 LCK")
	t.eq(c.progress.enchant_stat_bonus(Stat.SPD), 0, "none in SPD")
	t.eq(int(c.progress.stats()[Stat.STR]), int(before[Stat.STR]) + 2, "in the stats")
	t.eq(int(c.progress.stats()[Stat.LCK]), maxi(0, int(before[Stat.LCK]) - 1), "LCK down")
	t.check(c.attack() > attack, "the Attack rises with STR")
	# In battle, the same.
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	var b := run.start_battle(run.fronts[0])
	t.eq(b.roster[0].stat(Stat.STR), int(c.progress.stats()[Stat.STR]) + int(c.weapon().held_stats.get(Stat.STR, 0)), "the unit has it")
	# Another weapon in hand: the enchantment stays with the weapon.
	run.day = 4
	force_day(run, RunCalendar.DayType.FREE)
	var spare := run.inventory.add(c.weapon())
	t.eq(c.attack_with(spare), attack, "Attack with the plain twin: as before the enchantment")
	t.eq(c.attack_with(w), c.attack(), "with the enchanted one: as now")
	run.equip_weapon(c, spare)
	t.eq(c.progress.stats(), before, "back to the stats without it")
	t.eq(c.attack(), attack, "and the Attack")
	# Health: taken in hand it raises HP by what it adds; put down, HP is held to the new max.
	run.equip_weapon(c, w)
	c.hp = c.max_hp()
	var hp := c.hp
	run._set_enchant(w, {Stat.HP: 3})
	t.eq(c.hp, hp + 3, "a new enchantment's Health is added to HP")
	run.equip_weapon(c, spare)
	t.eq(c.hp, c.max_hp(), "HP no more than the max without it")


func test_move_enchant() -> void:
	var run := rich_run(19)
	build(run, F.SMITHY, 1)
	var from := owned(run, WeaponData.Tier.IRON)
	run._set_enchant(from, {Stat.STR: 2, Stat.SPD: 1})
	t.eq(run.move_enchant_cost(), {RunConfig.IRON_ORE: 2}, "2 iron ore")
	var bronze := owned(run, WeaponData.Tier.BRONZE)
	t.check(run.move_enchant_block_reason(from, bronze).contains("strong"), "not to a weapon of a smaller budget")
	var axe := owned(run, WeaponData.Tier.STEEL, WeaponData.WeaponType.AXE)
	t.check(run.move_enchant_block_reason(from, axe).contains("same type"), "the same weapon type only")
	var other := owned(run, WeaponData.Tier.STEEL)
	run._set_enchant(other, {Stat.DEF: 4})
	t.check(run.move_enchant_block_reason(from, other).contains("already"), "not onto an enchanted weapon")
	t.check(run.move_enchant_block_reason(bronze, from) != "", "not from a plain one")
	t.check(run.move_enchant_block_reason(from, from) != "", "not onto itself")
	var iron := owned(run, WeaponData.Tier.IRON)
	t.eq(run.move_enchant_block_reason(from, iron), "", "to a plain one of the same budget")
	var steel := owned(run, WeaponData.Tier.STEEL)
	var ore := run.material(RunConfig.IRON_ORE)
	t.check(run.move_enchant(from, steel), "moved to a steel sword (a larger budget)")
	t.eq(run.material(RunConfig.IRON_ORE), ore - 2, "2 ore")
	t.eq(steel.enchant_stats, {Stat.STR: 2, Stat.SPD: 1}, "moved whole")
	t.check(not from.is_enchanted(), "the old weapon is plain")
	t.eq(run.actions_left, 1, "an errand")
	# Onto a weapon in hand: the holder carries it.
	var c := run.lineup[0]
	var held := run.inventory.held_by(c)
	var spare := run.inventory.add(held.data)
	run._set_enchant(spare, {Stat.MAG: 1})
	t.check(run.move_enchant(spare, held), "onto the weapon in hand")
	t.eq(c.progress.enchant_stat_bonus(Stat.MAG), 1, "the holder has it")
