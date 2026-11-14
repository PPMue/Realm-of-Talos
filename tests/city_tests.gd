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
		test_market_on_battle_days,
		test_offer_open_at_the_march,
		test_hire_cost_by_week,
		test_outside_practice,
		test_hire_joins_practised,
		test_practice_numbers,
		test_elite_day,
		test_gems,
		test_gem_events,
		test_scavenge_gem,
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


# ---------------------------------------------------------------- the smithy and tavern on battle days

## On a battle or boss day, until the company marches out, the smithy (buy, enchant, move) and the
## tavern (hire) work as on a free day; everything else keeps to free days.
func test_market_on_battle_days() -> void:
	for type in [RunCalendar.DayType.BATTLE, RunCalendar.DayType.BOSS]:
		var name := "battle" if type == RunCalendar.DayType.BATTLE else "boss"
		var run := rich_run(30 + type)
		build(run, F.SMITHY, 1)
		var spare := owned(run, WeaponData.Tier.IRON)
		var target := owned(run, WeaponData.Tier.STEEL)
		run.day = 3
		force_day(run, type)
		t.eq(run.day_type(), type, "a %s day" % name)
		t.check(not run.fronts.is_empty(), "%s day: a front to march to" % name)
		t.eq(run.market_block_reason(), "", "%s day: the market is open" % name)
		if run.tavern_offers.is_empty():
			run._make_tavern_offers()
		for a in [Run.FreeAction.SHOP, Run.FreeAction.TAVERN]:
			t.eq(run.visit_block_reason(a), "", "%s day: %s can be visited" % [name, Run.FREE_ACTION_NAMES[a]])
			t.eq(run.free_action_block_reason(a), run.visit_block_reason(a), "%s day: %s agrees" % [name, Run.FREE_ACTION_NAMES[a]])
		# Buy.
		var item: ShopItemData = run.shop_stock()[0]
		var gold := run.gold
		t.eq(run.buy_block_reason(item), "", "%s day: buy" % name)
		t.check(run.buy(item) != null, "%s day: bought" % name)
		t.eq(run.gold, gold - run.shop_price(item), "%s day: paid" % name)
		# Hire: into the line if there is room, and they march out with it.
		while run.lineup.size() >= RunConfig.MAX_FIELDED:
			run.bench(run.lineup[-1])
		var hired := run.hire(run.tavern_offers[0])
		t.check(hired != null, "%s day: hired" % name)
		t.check(hired != null and run.is_fielded(hired), "%s day: in the line" % name)
		# Enchant and take, then again and keep.
		var offer := run.enchant(spare)
		t.check(offer != null, "%s day: an enchanting offer" % name)
		t.check(run.take_enchant(0), "%s day: taken" % name)
		t.check(spare.is_enchanted(), "%s day: enchanted" % name)
		t.check(run.enchant(spare) != null, "%s day: tried again" % name)
		t.check(run.keep_enchant(), "%s day: kept" % name)
		# Move.
		t.eq(run.move_enchant_block_reason(spare, target), "", "%s day: a move" % name)
		t.check(run.move_enchant(spare, target), "%s day: moved" % name)
		t.check(target.is_enchanted() and not spare.is_enchanted(), "%s day: on the steel sword" % name)
		# Everything else keeps to free days.
		var free := "Only on free days."
		t.eq(run.errand_block_reason(), free, "%s day: errands keep their meaning" % name)
		t.eq(run.cure_block_reason(run.roster[0]), free, "%s day: no cure" % name)
		t.eq(run.visit_block_reason(Run.FreeAction.CURE), free, "%s day: the infirmary's visit" % name)
		t.eq(run.upgrade_block_reason(F.GATE), free, "%s day: no upgrade" % name)
		t.eq(run.swap_block_reason(RunConfig.IRON_ORE, RunConfig.TIMBER), free, "%s day: no swap" % name)
		for a in [Run.FreeAction.REST, Run.FreeAction.REPAIR, Run.FreeAction.TRAIN, Run.FreeAction.SCAVENGE]:
			t.eq(run.free_action_block_reason(a), free, "%s day: no %s" % [name, Run.FREE_ACTION_NAMES[a]])
		if not run.drills.is_empty():
			t.eq(run.drill_block_reason(run.drills[0], run.roster[0]), free, "%s day: no drill" % name)
		t.check(not run.rest(), "%s day: no rest" % name)
		# Marched out: closed.
		t.check(run.start_battle(run.fronts[0]) != null, "%s day: march out" % name)
		t.eq(run.market_block_reason(), Run.BATTLE_BEGUN, "%s day: closed once the battle has begun" % name)
		if run.tavern_offers.is_empty():
			run._make_tavern_offers()
		t.eq(run.buy_block_reason(run.shop_stock()[0]), Run.BATTLE_BEGUN, "%s day: no buying" % name)
		t.eq(run.hire_block_reason(run.tavern_offers[0]), Run.BATTLE_BEGUN, "%s day: no hiring" % name)
		t.eq(run.free_action_block_reason(Run.FreeAction.SHOP), Run.BATTLE_BEGUN, "%s day: the smithy says so" % name)
		t.eq(run.enchant_block_reason(target), Run.BATTLE_BEGUN, "%s day: no enchanting" % name)
		t.eq(run.move_enchant_block_reason(target, spare), Run.BATTLE_BEGUN, "%s day: no move" % name)
	# A free day with its event waiting: the event first, as before; the run over: closed.
	var run := rich_run(40)
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	t.eq(run.market_block_reason(), Run.EVENT_FIRST, "a free day: the event first")
	run.outcome = Run.Outcome.DEFEAT
	t.eq(run.market_block_reason(), "The run is over.", "over")


## An enchanting offer still open when the company marches out is kept as "keep".
func test_offer_open_at_the_march() -> void:
	var run := rich_run(42)
	build(run, F.SMITHY, 1)
	var w := owned(run, WeaponData.Tier.IRON)
	run._set_enchant(w, {Stat.DEF: 3})
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	t.check(run.enchant(w) != null, "an offer on a battle day")
	t.check(run.start_battle(run.fronts[0]) != null, "marching out with it open")
	t.check(run.enchant_offer == null, "the offer is closed")
	t.eq(w.enchant_stats, {Stat.DEF: 3}, "the weapon kept what it had")


# ---------------------------------------------------------------- the tavern over the weeks

func test_hire_cost_by_week() -> void:
	var run := rich_run(50)
	t.eq(RunConfig.HIRE_COST_PER_WEEK, 10, "10 more a week")
	for pair: Array in [[1, 100], [7, 100], [8, 110], [15, 120], [22, 130], [29, 140], [36, 150], [42, 150]]:
		run.day = pair[0]
		t.eq(run.hire_cost(), pair[1], "day %d: %d" % pair)
	run.day = 2
	build(run, F.TAVERN, 2)
	run.day = 36
	t.eq(run.hire_cost(), 125, "week 6 with the Tavern's level 2: 150 - 25")


## Points in every weapon type and school of `p`.
func total_points(p: CompanionProgress) -> int:
	var n := 0
	for wt: int in WeaponData.WeaponType.values():
		n += p.points_in(wt)
	for s: int in SpellData.School.values():
		n += p.magic_points_in(s)
	return n


func main_points(p: CompanionProgress) -> int:
	return p.magic_points_in(p.data.signature_spell.school) if p.data.is_mage() else p.points_in(p.weapon.weapon_type)


## Everyone outside the company has one state for the run that only grows: from the second week's
## restock on, 8-12 points a week, most in what they fight with, offered or not.
func test_outside_practice() -> void:
	t.eq([RunConfig.TAVERN_PRACTICE_MIN, RunConfig.TAVERN_PRACTICE_MAX], [8, 12], "8-12 a week")
	for s in 20:
		var run := make_run(5100 + s)
		var outside: Array[CompanionData] = []
		for d in run.content.companions:
			if not run._in_roster(d):
				outside.append(d)
		# Week 1: as they start.
		for d in outside:
			var p := run.offer_progress(d)
			if run.tavern_offers.has(d):
				t.check(p != null, "an offer has a progress")
				t.eq(total_points(p), total_points(CompanionProgress.create(d)), "week 1: as they start")
				t.eq(p.traits, run.offer_traits(d), "with the traits shown")
			else:
				t.check(p == null, "not offered: none to read")
		var states := {}
		var totals := {}
		var mains := {}
		for d in outside:
			states[d] = run._outside_progress(d)
			totals[d] = total_points(states[d])
			mains[d] = main_points(states[d])
		run._restock_week()   # still day 1: the first restock has no practice
		for d in outside:
			t.eq(total_points(run._outside_progress(d)), totals[d], "no practice in week 1")
		for week in range(2, 7):
			run.day = (week - 1) * 7 + 1
			run._restock_week()
			for d in outside:
				var p := run._outside_progress(d)
				t.check(p == states[d], "week %d: the same state, never rolled again" % week)
				var gained := total_points(p) - int(totals[d])
				var main_gained := main_points(p) - int(mains[d])
				var capped := main_points(p) >= Proficiency.points_for(Proficiency.max_grade())
				if not capped:
					t.check(gained >= 8 and gained <= 12, "week %d: %s gained %d (8-12)" % [week, d.display_name, gained])
					t.check(main_gained >= 6, "week %d: %s, most in the main (%d)" % [week, d.display_name, main_gained])
				t.check(p.equipped_arts.size() <= BattleConfig.MAX_EQUIPPED_ARTS, "slots respected")
				for a in p.known_arts:
					t.check(a.weapon_type == p.weapon.weapon_type or p.grade(a.weapon_type) > Proficiency.Grade.E, "an art of a type they use")
				if run.tavern_offers.has(d):
					t.check(run.offer_progress(d) == p, "the offer shows it")
				totals[d] = total_points(p)
				mains[d] = main_points(p)


## A hire joins with what they practised and their traits; the level-ups are rolled at the hire.
func test_hire_joins_practised() -> void:
	var learned := 0
	for s in 30:
		var run := make_run(5200 + s)
		for week in range(2, 6):
			run.day = (week - 1) * 7 + 1
			run._restock_week()
		run.calendar[run.day - 1] = RunCalendar.DayType.FREE
		run.event_days.erase(run.day)
		run.gold = 10000
		var d: CompanionData = run.tavern_offers[0]
		var p := run.offer_progress(d)
		var points := {}
		for wt: int in WeaponData.WeaponType.values():
			points[wt] = p.points_in(wt)
		var arts := p.known_arts.duplicate()
		var equipped := p.equipped_arts.duplicate()
		var spells := p.known_spells.duplicate()
		var traits := run.offer_traits(d)
		var level := run.hire_level()
		var c := run.hire(d)
		t.check(c != null, "seed %d: hired" % s)
		t.check(c.progress == p, "joins with that state")
		for wt: int in WeaponData.WeaponType.values():
			t.eq(c.progress.points_in(wt), points[wt], "the practised points")
		t.eq(c.progress.known_arts, arts, "the arts")
		t.eq(c.progress.equipped_arts, equipped, "equipped as they were")
		t.eq(c.progress.known_spells, spells, "the spells")
		t.eq(c.traits, traits, "the traits shown")
		t.eq(c.level(), level, "the roster's average level")
		t.eq(c.hp, c.max_hp(), "at full HP")
		t.check(not run._outside.has(d), "no longer outside")
		if arts.size() > CompanionProgress.create(d).known_arts.size() or spells.size() > CompanionProgress.create(d).known_spells.size():
			learned += 1
	t.check(learned > 0, "some hires learned something while outside (%d of 30)" % learned)


## Where the practice lands: a week-6 hire about 50 points ahead of a week-1 hire, against up to
## 8 a battle (3 a week) for someone fielded from week 1.
func test_practice_numbers() -> void:
	var gained := 0.0
	var main_grades := 0.0
	var arts := 0.0
	var n := 0
	for s in 60:
		var run := make_run(5300 + s)
		var start := {}
		for d in run.content.companions:
			if not run._in_roster(d):
				start[d] = [total_points(run._outside_progress(d)), run._outside_progress(d).known_arts.size() + run._outside_progress(d).known_spells.size()]
		for week in range(2, 7):
			run.day = (week - 1) * 7 + 1
			run._restock_week()
		for d: CompanionData in start:
			var p := run._outside_progress(d)
			gained += total_points(p) - int(start[d][0])
			arts += p.known_arts.size() + p.known_spells.size() - int(start[d][1])
			main_grades += p.magic_grade(d.signature_spell.school) if d.is_mage() else p.grade(p.weapon.weapon_type)
			n += 1
	var avg := gained / n
	print("  outside practice by week 6: %.1f points, main grade %.1f (E=0 .. S=10), %.2f arts or spells learned" % [avg, main_grades / n, arts / n])
	t.check(avg > 45.0 and avg < 55.0, "a week-6 hire about 50 points ahead (%.1f)" % avg)
	t.check(avg < 8 * 3 * 5, "behind someone fielded from week 1 (up to %d)" % (8 * 3 * 5))


# ---------------------------------------------------------------- elite fights and gemstones

## Walks `run` to the start of day `d`, winning every fight at the first front and answering events.
func walk_to(run: Run, d: int) -> void:
	run.gold = 100000
	while run.day < d and not run.is_over():
		if run.is_fight_day():
			if run.lineup.is_empty():
				for c in run.reserve():
					run.field(c)
			if run.lineup.is_empty():
				run.yield_day()
				continue
			win(run)
		else:
			if run.event_pending():
				for ch in run.event.choices:
					if run.choice_block_reason(ch) == "":
						run.choose(ch)
						break
			run.end_free_day()


## An elite day plays as a battle day with two danger-3 fronts that give the day's stone.
func test_elite_day() -> void:
	for s in 6:
		var run := make_run(6000 + s)
		walk_to(run, 6)
		t.eq(run.day, 6, "seed %d: day 6" % s)
		t.eq(run.day_type(), RunCalendar.DayType.ELITE, "an elite")
		t.check(run.is_fight_day(), "a fight day")
		t.eq(run.seen_day_type(), RunCalendar.DayType.ELITE, "shown as an elite")
		t.eq(run.fronts.size(), 2, "exactly two fronts")
		for f in run.fronts:
			t.eq(f.danger, 3, "danger 3")
			t.check(f.is_elite and not f.is_boss, "an elite front")
			t.eq(f.gem, Gem.TOPAZ, "gives a Topaz")
			t.eq(f.city_damage, run.front_city_damage(3), "costs the walls as danger 3")
			t.eq(f.xp_pool, run.xp_pool(3, 6), "danger 3 XP")
		t.check(run.fronts[0].site != run.fronts[1].site, "two places")
		if run.content.groups_for(3, 6).size() > 1:
			t.check(run.fronts[0].group != run.fronts[1].group, "two different groups")
		t.eq(run.market_block_reason(), "", "the smithy and tavern are open")
		t.eq(run.errand_block_reason(), "Only on free days.", "free-day errands are not")
		t.check(not run.has_event_day(), "no event")
		t.eq(run.event, null, "none waiting")
		t.eq(run.actions_left, 0, "no free action")
		t.check(not run.end_free_day(), "not a free day to end")
		var before := run.gem_count(Gem.TOPAZ)   # an event may have given one already
		var taken := run.gems_taken
		var report := win(run)
		t.check(report.won, "won")
		t.eq(report.gem, Gem.TOPAZ, "the report carries the Topaz")
		t.eq(run.gem_count(Gem.TOPAZ), before + 1, "in the company's stones")
		t.eq(run.gems_taken, taken + 1, "one more taken")
		t.eq(run.day, 7, "the day ended")
	# A lost elite: no stone, the walls pay as danger 3.
	var run := make_run(6100)
	walk_to(run, 6)
	var walls := run.city_health
	var stones := run.gem_total()
	var b := run.start_battle(run.fronts[0])
	for c in b.line():
		c.hp = 0
		c.state = CompanionUnit.State.INJURED
	b._check_end()
	var lost := run.finish_battle(b)
	t.check(not lost.won, "lost")
	t.eq(lost.gem, 0, "no stone")
	t.eq(run.gem_total(), stones, "none kept")
	t.eq(run.city_health, walls - lost.city_damage, "the walls pay")
	t.eq(lost.city_damage, run.front_city_damage(3), "as a danger-3 front")
	# Yielded: only on fight days, elites included.
	run = make_run(6101)
	walk_to(run, 6)
	t.check(run.yield_block_reason() != "Only on a battle, elite or boss day.", "an elite can be given up")
	# The Watchtower's level 2 shows tomorrow's elite fronts, and they are today's.
	run = make_run(6102)
	walk_to(run, 5)
	run.facilities[F.WATCHTOWER] = 2
	run._roll_tomorrow()
	var next := run.tomorrow_fronts()
	t.eq(next.size(), 2, "tomorrow's two elite fronts known")
	run.end_free_day()
	t.eq(run.fronts, next, "the same fronts")
	t.check(run.fronts.all(func(f: Front) -> bool: return f.gem == Gem.TOPAZ and f.danger == 3), "elite fronts")
	# The boss days are hidden without the Watchtower; the elites never are.
	run = make_run(6103)
	t.eq(run.seen_day_type(6), RunCalendar.DayType.ELITE, "day 6 seen as an elite from day 1")
	t.eq(run.seen_day_type(14), RunCalendar.DayType.BATTLE, "a boss day ahead still looks like a battle")


func test_gems() -> void:
	t.eq(Gem.NAMES, ["Topaz", "Sapphire", "Emerald", "Ruby", "Diamond"] as Array[String], "five stones")
	t.eq(Gem.name_of(1), "Topaz", "rank 1")
	t.eq(Gem.name_of(5), "Diamond", "rank 5")
	t.eq(Gem.name_of(0), "", "no stone")
	var run := make_run(6200)
	# The stone of each big fight.
	var want := {6: Gem.TOPAZ, 14: Gem.SAPPHIRE, 20: Gem.EMERALD, 28: Gem.RUBY, 34: Gem.DIAMOND, 42: 0}
	for d in range(1, 43):
		t.eq(run.gem_for_fight(d), int(want.get(d, 0)), "the fight of day %d" % d)
	# The current rank: the last big fight passed, Topaz before the first.
	for pair: Array in [[1, 1], [6, 1], [7, 1], [14, 1], [15, 2], [20, 2], [21, 3], [28, 3], [29, 4], [34, 4], [35, 5], [42, 5]]:
		run.day = pair[0]
		t.eq(run.gem_rank_now(), pair[1], "day %d: %s" % [pair[0], Gem.name_of(pair[1])])
	# Kept like materials.
	t.eq(run.gem_total(), 0, "none at the start")
	t.eq(run.add_gem(Gem.RUBY), Gem.RUBY, "added")
	t.eq(run.add_gem(Gem.RUBY), Gem.RUBY, "and another")
	t.eq(run.add_gem(0), 0, "no stone of rank 0")
	t.eq(run.add_gem(6), 0, "nor 6")
	t.eq(run.gem_count(Gem.RUBY), 2, "two rubies")
	t.eq(run.gem_count(Gem.TOPAZ), 0, "no topaz")
	t.eq(run.gems_taken, 2, "two taken")
	# Bosses: day 14 a Sapphire, the last none.
	run = make_run(6201)
	walk_to(run, 14)
	t.eq(run.fronts[0].gem, Gem.SAPPHIRE, "the day 14 boss gives a Sapphire")
	var r := win(run)
	if r.won:
		t.eq(r.gem, Gem.SAPPHIRE, "won: a Sapphire")
	run = make_run(6202)
	walk_to(run, 42)
	if run.day == 42:
		t.eq(run.fronts[0].gem, 0, "the last boss gives none")
	# A run that wins every big fight takes the five, in order.
	run = make_run(6203)
	walk_to(run, 42)
	t.eq(run.day, 42, "reached the last day")
	for rank in range(1, 6):
		t.check(run.gem_count(rank) >= 1, "a %s" % Gem.name_of(rank))


## Two events give a stone: the gem cutter's widow (gold for the current rank, iron ore for one
## lower) and the old mine (the healthiest gets hurt for the current rank).
func test_gem_events() -> void:
	var widow: EventData = load("res://data/run/events/gem_cutter.tres")
	var mine: EventData = load("res://data/run/events/old_mine.tres")
	t.check(RunContent.load_default().events.has(widow) and RunContent.load_default().events.has(mine), "both in the content")
	var run := rich_run(6300)
	run.event = widow
	t.eq(run.choice_gem(widow.choices[0]), Gem.TOPAZ, "week 1: a Topaz for gold")
	t.eq(run.choice_gem(widow.choices[1]), Gem.TOPAZ, "one lower, never below Topaz")
	t.eq(run.choice_gem(widow.choices[2]), 0, "leaving gives none")
	var gold := run.gold
	var text := run.choose(widow.choices[0])
	t.eq(run.gem_count(Gem.TOPAZ), 1, "the stone is kept")
	t.eq(run.gold, gold - 60, "for 60 gold")
	t.check(text.contains("Topaz") and not text.contains("{gem}"), "the letter names it: %s" % text)
	run.day = 30
	t.eq(run.gem_rank_now(), Gem.RUBY, "day 30: Ruby")
	t.eq(run.choice_gem(widow.choices[0]), Gem.RUBY, "a Ruby for gold")
	t.eq(run.choice_gem(widow.choices[1]), Gem.EMERALD, "an Emerald for ore")
	t.eq(run.choice_gem(mine.choices[0]), Gem.RUBY, "the mine: the current rank")
	run.day = 2
	run.event = mine
	var c: RunCompanion = run.hp_targets(mine.choices[0])[0]
	var hp := c.hp
	run.choose(mine.choices[0])
	t.eq(c.hp, maxi(1, hp - 10), "the healthiest pays in HP")
	t.eq(run.gem_count(Gem.TOPAZ), 2, "a second Topaz")
	t.eq(run.gems_taken, 2, "two taken")


## A scavenging Success sometimes brings back a stone of the current rank; nothing else does.
func test_scavenge_gem() -> void:
	t.eq(RunConfig.SCAVENGE_GEM_PERCENT, 3, "3%")
	var found := 0
	var full := 0
	for s in 600:
		var run := rich_run(6400 + s)
		run.day = 16 if s % 2 == 0 else 2
		run.calendar[run.day - 1] = RunCalendar.DayType.FREE
		run.event_days.erase(run.day)
		run._begin_day()
		var sites := run.scavenge_sites()
		if sites.is_empty():
			continue
		var site: ScavengeSite = sites[0]
		var party: Array[RunCompanion] = []
		for c in run.available():
			if party.size() < site.size:
				party.append(c)
		if party.size() < site.size:
			continue
		var r := run.scavenge(site, party)
		if r == null:
			continue
		if r.outcome == ScavengeResult.Outcome.FULL:
			full += 1
			if r.gem > 0:
				found += 1
				t.eq(r.gem, run.gem_rank_now(), "the current rank")
				t.eq(run.gem_count(r.gem), 1, "kept")
		else:
			t.eq(r.gem, 0, "only on a success")
			t.eq(run.gem_total(), 0, "nothing kept")
	t.check(full > 100, "enough successes (%d)" % full)
	t.check(found > 0 and found / float(full) < 0.08, "a stone now and then (%d of %d)" % [found, full])


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
			t.eq(not next.is_empty(), RunCalendar.is_fight(tomorrow),
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
	t.eq(run.enchant_block_reason(w), "", "a battle day too, before the march")
	run.start_battle(run.fronts[0])
	t.eq(run.enchant_block_reason(w), Run.BATTLE_BEGUN, "not once the battle has begun")


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
