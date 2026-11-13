extends RefCounted
## Headless tests for scavenging (Run.scavenge_sites, scavenge_block_reason, scavenge_chance,
## scavenge): the day's sites, their targets and hauls, the chance arithmetic, who can go, the action,
## and each outcome's consequences by risk. Called from run_tests.gd, which owns check() and eq().

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_scavenge_sites_only_on_free_days,
		test_scavenge_site_shape,
		test_scavenge_one_site_fillable,
		test_scavenge_targets,
		test_scavenge_chance_arithmetic,
		test_scavenge_block_reasons,
		test_scavenge_spends_the_action,
		test_scavenge_full_haul,
		test_scavenge_low_risk_outcomes,
		test_scavenge_medium_risk_outcomes,
		test_scavenge_high_risk_outcomes,
		test_scavenge_level_ups,
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


## A free run on day 2 with three companions (one hired straight in).
func free_run(seed_value: int = 1) -> Run:
	var run := make_run(seed_value)
	run.day = 2
	for d in run.content.companions:
		if run.roster.size() >= 3:
			break
		if not run._in_roster(d):
			run._join(d)
	force_day(run, RunCalendar.DayType.FREE)
	return run


## Sets `c`'s stat `key` (base + gains) to `value`.
func set_stat(c: RunCompanion, key: String, value: int) -> void:
	c.progress.stat_gains[key] = value - int(c.data.base_stats()[key])


func stat(c: RunCompanion, key: String) -> int:
	return int(c.progress.stats()[key])


## A site of `risk` with places testing `stats` (targets as given), added to today's map.
func make_site(run: Run, risk: int, stats: Array[String], targets: Array[int]) -> ScavengeSite:
	var site := ScavengeSite.new()
	site.display_name = "Test Ruin"
	site.size = stats.size()
	site.risk = risk as ScavengeSite.Risk
	for i in stats.size():
		var slot := ScavengeSite.Slot.new()
		slot.stat = stats[i]
		slot.target = targets[i]
		slot.role = ScavengeSite.ROLES[stats[i]]
		site.slots.append(slot)
	site.gold = 101
	site.materials = {RunConfig.TIMBER: 3, RunConfig.IRON_ORE: 1}
	site.weapon_chance = 0
	site.xp_each = 9
	run._scavenge_sites.append(site)
	return site


## Sends the first companions to a fresh two-place site of `risk` (SPD 10, STR 10; the first meets
## SPD, the second is 3 short of STR), with the run's generator seeded with `s`. Returns
## [run, site, party, result, gold before, materials before, hp before].
func trip(risk: int, s: int) -> Array:
	var run := free_run(77)
	var site := make_site(run, risk, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	var party: Array = [run.roster[0], run.roster[1]]
	set_stat(party[0], Stat.SPD, 10)
	set_stat(party[1], Stat.STR, 7)
	var hp_before: Array[int] = []
	for c: RunCompanion in party:
		c.hp = c.max_hp()
		hp_before.append(c.hp)
	run.gold = 50
	var mats := run.materials.duplicate()
	run.rng.seed = s
	var r := run.scavenge(site, party)
	return [run, site, party, r, 50, mats, hp_before]


## The first seed (from 0) whose trip of `risk` ends in `outcome`, or -1.
func seed_for(risk: int, outcome: int) -> int:
	for s in 400:
		var r: ScavengeResult = trip(risk, s)[3]
		if r != null and r.outcome == outcome:
			return s
	return -1


func loss(c: RunCompanion) -> int:
	return ceili(c.max_hp() * RunConfig.SCAVENGE_HP_LOSS_FRACTION)


# ---------------------------------------------------------------- tests

func test_scavenge_sites_only_on_free_days() -> void:
	var run := make_run(3)
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.scavenge_sites().size(), RunConfig.SCAVENGE_SITES_PER_DAY, "a free day offers its sites")
	t.eq(RunConfig.SCAVENGE_SITES_PER_DAY, 2, "two of them")
	t.check(run.scavenge_sites()[0].display_name != run.scavenge_sites()[1].display_name, "with different names")
	t.eq(Run.FREE_ACTION_NAMES[Run.FreeAction.SCAVENGE], "Scavenge", "named Scavenge")
	force_day(run, RunCalendar.DayType.BATTLE)
	t.check(run.scavenge_sites().is_empty(), "none on a battle day")
	force_day(run, RunCalendar.DayType.BOSS)
	t.check(run.scavenge_sites().is_empty(), "none on a boss day")
	# Every free day of a whole run has its own.
	var played := make_run(4)
	var seen := 0
	var last: Array[ScavengeSite] = []
	while not played.is_over() and played.day < 20:
		if played.day_type() == RunCalendar.DayType.FREE:
			var today := played.scavenge_sites()
			t.eq(today.size(), 2, "day %d has two sites" % played.day)
			t.check(not last.has(today[0]), "rolled again on day %d" % played.day)
			last = today
			seen += 1
			if played.event_pending():
				for ch in played.event.choices:
					if played.choice_block_reason(ch) == "":
						played.choose(ch)
						break
			played.end_free_day()
		else:
			t.check(played.scavenge_sites().is_empty(), "day %d is not free: no sites" % played.day)
			var b := played.start_battle(played.fronts[0])
			for e in b.enemies:
				e.hp = 0
			b._check_end()
			played.finish_battle(b)
	t.check(seen > 3, "several free days seen")


func test_scavenge_site_shape() -> void:
	var sizes := {}
	var risks := {}
	for s in 60:
		var run := make_run(100 + s)
		run.day = 1 + s % 40
		force_day(run, RunCalendar.DayType.FREE)
		for site in run.scavenge_sites():
			sizes[site.size] = true
			risks[site.risk] = true
			t.check(site.size >= 1 and site.size <= 3, "size 1-3")
			t.eq(site.slots.size(), site.size, "one place per size point")
			var stats := {}
			for slot in site.slots:
				t.check(ScavengeSite.ROLE_STATS.has(slot.stat), "a stat of the list")
				t.eq(slot.role, ScavengeSite.ROLES[slot.stat], "the role of its stat")
				t.eq(slot.target, Run.scavenge_target(slot.stat, site.risk, run.day), "the target of the day and risk")
				stats[slot.stat] = true
			t.eq(stats.size(), site.size, "every stat on a site different")
			t.eq(site.gold, Run.scavenge_gold(site.size, site.risk, run.day), "the gold of its size, risk and day")
			t.eq(site.xp_each, Run.scavenge_xp(run.day), "the day's XP")
			t.eq(site.weapon_chance, RunConfig.SCAVENGE_WEAPON_CHANCE[site.risk], "weapon chance by risk")
			var span: Array = RunConfig.SCAVENGE_MATERIALS_BY_SIZE[site.size - 1]
			t.check(site.material_count() >= int(span[0]) and site.material_count() <= int(span[1]), "materials by size")
			for m: String in site.materials:
				t.check(RunConfig.MATERIAL_ORDER.has(m), "timber or iron ore")
			t.check(site.size_name() != "" and site.risk_name() != "", "names")
	t.eq(sizes.size(), 3, "every size turns up")
	t.eq(risks.size(), 3, "every risk turns up")
	# The numbers asked for: small low-risk gold is 40% of a danger-1 battle that day, and so on.
	t.eq(Run.scavenge_gold(1, ScavengeSite.Risk.LOW, 1), 16, "small, low risk, day 1: 16 (40% of 40)")
	t.eq(Run.scavenge_gold(3, ScavengeSite.Risk.HIGH, 1), roundi(16 * 2.6 * 2.2), "large, high risk: x2.6 x2.2")
	t.check(Run.scavenge_gold(1, ScavengeSite.Risk.LOW, 42) > Run.scavenge_gold(1, ScavengeSite.Risk.LOW, 1), "grows with the day")
	t.eq(Run.scavenge_xp(1), roundi(57 / 4.0 * 0.3), "XP: 30% of an even share of a danger-1 pool")


func test_scavenge_one_site_fillable() -> void:
	for s in 200:
		var run := make_run(300 + s)
		run.day = 2 + s % 38
		# Only one companion fit.
		for c in run.roster.slice(1):
			run._to_infirmary(c)
		force_day(run, RunCalendar.DayType.FREE)
		t.eq(run.available().size(), 1, "one fit (seed %d)" % s)
		var fits := run.scavenge_sites().any(func(site: ScavengeSite) -> bool: return site.size <= 1)
		t.check(fits, "seed %d: one site can be filled by one" % s)
	# Nobody fit: sites are shown but nobody can go.
	var run := make_run(9)
	run.day = 2
	for c in run.roster:
		run._to_infirmary(c)
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.free_action_block_reason(Run.FreeAction.SCAVENGE), "Nobody is fit to go.", "nobody fit")
	var site := run.scavenge_sites()[0]
	t.eq(run.scavenge_block_reason(site, []), "Nobody is fit to go.", "says so for a site too")


func test_scavenge_targets() -> void:
	# Day 1: the fourteen companions' average base stat, rounded; medium risk is no shift.
	t.eq(Run.scavenge_target(Stat.SPD, ScavengeSite.Risk.MEDIUM, 1), 8, "SPD day 1")
	t.eq(Run.scavenge_target(Stat.DEX, ScavengeSite.Risk.MEDIUM, 1), 9, "DEX day 1")
	t.eq(Run.scavenge_target(Stat.MAG, ScavengeSite.Risk.MEDIUM, 1), 4, "MAG day 1")
	t.eq(Run.scavenge_target(Stat.SPD, ScavengeSite.Risk.LOW, 1), 7, "low risk -1")
	t.eq(Run.scavenge_target(Stat.SPD, ScavengeSite.Risk.HIGH, 1), 10, "high risk +2")
	for key in ScavengeSite.ROLE_STATS:
		var prev := -99
		for d in range(1, 43):
			var v := Run.scavenge_target(key, ScavengeSite.Risk.MEDIUM, d)
			t.check(v >= prev, "%s never falls (day %d)" % [key, d])
			prev = v
	t.eq(Run.scavenge_target(Stat.BLD, ScavengeSite.Risk.MEDIUM, 42), Run.scavenge_target(Stat.BLD, ScavengeSite.Risk.MEDIUM, 1),
		"BLD never grows")
	t.check(Run.scavenge_target(Stat.STR, ScavengeSite.Risk.MEDIUM, 42) > Run.scavenge_target(Stat.STR, ScavengeSite.Risk.MEDIUM, 1) + 2,
		"STR climbs with the day")
	# The base and growth are the companions' averages.
	var content := RunContent.load_default()
	for key in ScavengeSite.ROLE_STATS:
		var base := 0.0
		var growth := 0.0
		for d: CompanionData in content.companions:
			base += int(d.base_stats()[key])
			growth += Levels.growth_rate(d, key)
		base /= content.companions.size()
		growth /= content.companions.size() * 100.0
		t.check(absf(base - float(RunConfig.SCAVENGE_STAT_BASE[key])) < 0.1, "%s base is the average (%.2f)" % [key, base])
		t.check(absf(growth - float(RunConfig.SCAVENGE_STAT_GROWTH[key])) < 0.01, "%s growth is the average (%.3f)" % [key, growth])


func test_scavenge_chance_arithmetic() -> void:
	var run := free_run(5)
	var a := run.roster[0]
	var b := run.roster[1]
	var site := make_site(run, ScavengeSite.Risk.LOW, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	# Slot scores.
	for case in [[10, 15], [11, 18], [15, 30], [20, 30], [9, -6], [7, -18], [5, -30], [1, -30]]:
		set_stat(a, Stat.SPD, case[0])
		t.eq(run.scavenge_slot_score(site, 0, a), case[1], "SPD %d against 10 scores %d" % case)
	t.eq(run.scavenge_slot_score(site, 0, null), -30, "an empty place -30")
	# Low risk: 75 + the average.
	set_stat(a, Stat.SPD, 10)   # +15
	set_stat(b, Stat.STR, 9)    # -6
	t.eq(run.scavenge_chance(site, [a, b]), 75 + roundi(4.5), "75 + (15 - 6) / 2, rounded")
	t.eq(run.scavenge_chance(site, [a]), 75 + roundi(-7.5), "a missing place counts as empty")
	t.eq(run.scavenge_chance(site, [a, null]), 75 + roundi(-7.5), "and so does a null")
	set_stat(a, Stat.SPD, 20)
	set_stat(b, Stat.STR, 20)
	t.eq(run.scavenge_chance(site, [a, b]), 95, "75 + 30 clamped to 95")
	# High risk: 45 + the average, at least 25.
	var high := make_site(run, ScavengeSite.Risk.HIGH, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	t.eq(run.scavenge_chance(high, [a, b]), 75, "45 + 30")
	t.eq(run.scavenge_chance(high, []), 25, "45 - 30 clamped to 25")
	set_stat(a, Stat.SPD, 10)
	set_stat(b, Stat.STR, 10)
	t.eq(run.scavenge_chance(high, [a, b]), 60, "45 + 15")
	var medium := make_site(run, ScavengeSite.Risk.MEDIUM, [Stat.SPD] as Array[String], [10] as Array[int])
	t.eq(run.scavenge_chance(medium, [a]), 75, "medium: 60 + 15")
	t.eq(RunConfig.SCAVENGE_BASE_CHANCE, [75, 60, 45] as Array[int], "bases 75 / 60 / 45")


func test_scavenge_block_reasons() -> void:
	var run := free_run(6)
	var a := run.roster[0]
	var b := run.roster[1]
	var site := make_site(run, ScavengeSite.Risk.LOW, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	t.eq(run.free_action_block_reason(Run.FreeAction.SCAVENGE), "", "open")
	t.eq(run.scavenge_block_reason(site, [a, null]), "Fill every place.", "every place filled")
	t.eq(run.scavenge_block_reason(site, [a]), "Fill every place.", "a short party too")
	t.check(run.scavenge(site, [a]) == null, "refused")
	t.check(run.scavenge_block_reason(site, [a, a]).contains("two places"), "nobody twice")
	t.check(run.scavenge_block_reason(site, [a, b, run.roster[2]]).contains("Only 2"), "no more than the places")
	var stranger := RunCompanion.create(run.content.companions[0])
	t.check(run.scavenge_block_reason(site, [a, stranger]).contains("not in the company"), "only the company")
	run._to_infirmary(b)
	t.eq(run.scavenge_block_reason(site, [a, b]), run.infirmary_block_reason(b), "nobody from the infirmary")
	run._release(b)
	var other := ScavengeSite.new()
	other.size = 1
	other.slots.append(site.slots[0])
	t.check(run.scavenge_block_reason(other, [a]).contains("not on today's map"), "only today's sites")
	t.eq(run.scavenge_block_reason(site, [b, a]), "", "a full party of two may go")
	t.eq(run.actions_left, 1, "asking spends nothing")
	# Not on battle days, not before the event.
	force_day(run, RunCalendar.DayType.BATTLE)
	t.eq(run.free_action_block_reason(Run.FreeAction.SCAVENGE), "Only on free days.", "not on a battle day")
	t.check(run.scavenge(site, [a, b]) == null, "refused on a battle day")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	t.check(run.event_pending(), "an event waits")
	var today := run.scavenge_sites()[0]
	var party: Array = run.available().slice(0, today.size)
	t.eq(run.scavenge_block_reason(today, party), Run.EVENT_FIRST, "the gate's matter first")
	t.check(run.scavenge(today, party) == null, "refused before the event")


func test_scavenge_spends_the_action() -> void:
	var run := free_run(7)
	var site := make_site(run, ScavengeSite.Risk.LOW, [Stat.SPD] as Array[String], [1] as Array[int])
	run.gold = 1000
	run.roster[0].hp = 1
	var r := run.scavenge(site, [run.roster[1]])
	t.check(r != null, "sent")
	t.eq(run.actions_left, 0, "the day's action is spent")
	t.eq(run.actions_used, [Run.FreeAction.SCAVENGE] as Array[int], "as Scavenge")
	t.check(not run.rest(), "no rest after it")
	t.eq(run.free_action_block_reason(Run.FreeAction.REST), "No actions left today.", "says why")
	t.check(run.free_action_block_reason(Run.FreeAction.TRAIN) != "", "no training")
	t.check(run.train(run.drills[0], run.roster[0]) == null, "refused")
	t.check(run.scavenge(site, [run.roster[1]]) == null, "and no second trip")
	t.eq(run.scavenge_block_reason(site, [run.roster[1]]), "Already done today.", "says why")
	t.eq(run.buy_block_reason(run.shop_stock()[0]), "", "errands are still open")
	# And the other way: rest first, then no trip.
	var run2 := free_run(8)
	run2.roster[0].hp = 1
	t.check(run2.rest(), "rest")
	var s2 := run2.scavenge_sites()[0]
	t.eq(run2.scavenge_block_reason(s2, run2.available().slice(0, s2.size)), "No actions left today.", "rest uses the action")


func test_scavenge_full_haul() -> void:
	var s := seed_for(ScavengeSite.Risk.HIGH, ScavengeResult.Outcome.FULL)
	t.check(s >= 0, "a seed with a full haul")
	var got := trip(ScavengeSite.Risk.HIGH, s)
	var run: Run = got[0]
	var site: ScavengeSite = got[1]
	var r: ScavengeResult = got[3]
	t.eq(r.chance, 45 + roundi((15 - 18) / 2.0), "the chance shown")
	t.check(r.roll <= r.chance, "the roll is under it")
	t.eq(run.gold, 50 + 101, "the whole gold")
	t.eq(r.gold, 101, "reported")
	var mats: Dictionary = got[5]
	t.eq(run.material(RunConfig.TIMBER), int(mats.get(RunConfig.TIMBER, 0)) + 3, "the timber")
	t.eq(run.material(RunConfig.IRON_ORE), int(mats.get(RunConfig.IRON_ORE, 0)) + 1, "the ore")
	for m in r.members:
		t.eq(m.xp_gained, 9, "XP to each")
		t.eq(m.hp_lost, 0, "nobody hurt")
	t.check(r.injured == null, "nobody injured")
	t.eq(r.outcome_name(), "Full haul", "named")
	# A weapon: with a weapon chance of 100 a full haul always finds one, into the armory.
	var found := 0
	for k in 40:
		var run2 := free_run(77)
		var site2 := make_site(run2, ScavengeSite.Risk.LOW, [Stat.SPD] as Array[String], [1] as Array[int])
		site2.weapon_chance = 100
		run2.rng.seed = k
		var before := run2.inventory.unheld().size()
		var r2 := run2.scavenge(site2, [run2.roster[0]])
		if r2.outcome != ScavengeResult.Outcome.FULL:
			t.check(r2.weapon_found == null, "no weapon without a full haul")
			continue
		t.check(r2.weapon_found != null, "a weapon found")
		t.eq(run2.inventory.unheld().size(), before + 1, "into the armory")
		found += 1
	t.check(found > 20, "most of 40 at 95%% found one (%d)" % found)
	# No weapon at weapon chance 0.
	t.check(r.weapon_found == null, "none at 0%")


func test_scavenge_low_risk_outcomes() -> void:
	for outcome in [ScavengeResult.Outcome.HALF, ScavengeResult.Outcome.NOTHING]:
		var s := seed_for(ScavengeSite.Risk.LOW, outcome)
		t.check(s >= 0, "a seed for %s" % ScavengeResult.OUTCOME_NAMES[outcome])
		var got := trip(ScavengeSite.Risk.LOW, s)
		var run: Run = got[0]
		var r: ScavengeResult = got[3]
		t.check(r.roll > r.chance, "the roll missed")
		var party: Array = got[2]
		var hp_before: Array[int] = got[6]
		for i in party.size():
			t.eq(party[i].hp, hp_before[i], "low risk: nobody hurt (%s)" % r.outcome_name())
		t.check(r.injured == null and run.infirmary().is_empty(), "nobody injured")
		if outcome == ScavengeResult.Outcome.HALF:
			t.eq(run.gold, 50 + 50, "half the gold, rounded down")
			var mats: Dictionary = got[5]
			t.eq(run.material(RunConfig.TIMBER), int(mats.get(RunConfig.TIMBER, 0)) + 1, "half the timber, rounded down")
			t.eq(run.material(RunConfig.IRON_ORE), int(mats.get(RunConfig.IRON_ORE, 0)), "half of one ore is none")
			for m in r.members:
				t.eq(m.xp_gained, 4, "half the XP, rounded down")
			t.check(r.weapon_found == null, "no weapon")
		else:
			t.eq(run.gold, 50, "nothing")
			t.check(r.materials.is_empty(), "no materials")
			for m in r.members:
				t.eq(m.xp_gained, 0, "no XP")


func test_scavenge_medium_risk_outcomes() -> void:
	var s := seed_for(ScavengeSite.Risk.MEDIUM, ScavengeResult.Outcome.HALF)
	var got := trip(ScavengeSite.Risk.MEDIUM, s)
	var party: Array = got[2]
	var hp_before: Array[int] = got[6]
	for i in party.size():
		t.eq(party[i].hp, hp_before[i], "medium risk, half a haul: nobody hurt")
	s = seed_for(ScavengeSite.Risk.MEDIUM, ScavengeResult.Outcome.NOTHING)
	got = trip(ScavengeSite.Risk.MEDIUM, s)
	var run: Run = got[0]
	var r: ScavengeResult = got[3]
	party = got[2]
	hp_before = got[6]
	for i in party.size():
		var c: RunCompanion = party[i]
		t.eq(c.hp, hp_before[i] - loss(c), "medium risk, nothing: %s loses 25%% of max HP" % c.display_name())
		t.eq(r.members[i].hp_lost, loss(c), "reported")
	t.check(r.injured == null and run.infirmary().is_empty(), "nobody injured")
	# Never below 1.
	var run2 := free_run(77)
	var site2 := make_site(run2, ScavengeSite.Risk.MEDIUM, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	set_stat(run2.roster[0], Stat.SPD, 10)
	set_stat(run2.roster[1], Stat.STR, 7)
	run2.roster[0].hp = 2
	run2.roster[1].hp = 1
	run2.rng.seed = s
	var r2 := run2.scavenge(site2, [run2.roster[0], run2.roster[1]])
	t.eq(r2.outcome, ScavengeResult.Outcome.NOTHING, "the same roll")
	t.eq(run2.roster[0].hp, 1, "never below 1")
	t.eq(run2.roster[1].hp, 1, "and 1 stays 1")
	t.eq(r2.members[1].hp_lost, 0, "losing nothing")


func test_scavenge_high_risk_outcomes() -> void:
	var s := seed_for(ScavengeSite.Risk.HIGH, ScavengeResult.Outcome.HALF)
	var got := trip(ScavengeSite.Risk.HIGH, s)
	var run: Run = got[0]
	var r: ScavengeResult = got[3]
	var party: Array = got[2]
	var hp_before: Array[int] = got[6]
	t.eq(run.gold, 100, "half the gold")
	for i in party.size():
		t.eq(party[i].hp, hp_before[i] - loss(party[i]), "high risk, half a haul: everyone loses 25%")
	t.check(r.injured == null and run.infirmary().is_empty(), "nobody injured")
	s = seed_for(ScavengeSite.Risk.HIGH, ScavengeResult.Outcome.NOTHING)
	got = trip(ScavengeSite.Risk.HIGH, s)
	run = got[0]
	r = got[3]
	party = got[2]
	hp_before = got[6]
	var short: RunCompanion = party[1]   # 3 short of STR; the other meets SPD
	t.eq(r.injured, short, "the one furthest short is injured")
	t.check(short.injured and run.infirmary().has(short), "and is in the infirmary")
	t.eq(short.back_on_day, run.day + RunConfig.INFIRMARY_DAYS + 1, "for the usual stay")
	t.check(not run.lineup.has(short) and not run.available().has(short), "out of the line")
	t.eq(short.hp, 0, "as after a battle")
	t.eq(r.members[1].hp_lost, hp_before[1], "lost all of it")
	t.eq(party[0].hp, hp_before[0] - loss(party[0]), "the other loses 25%")
	t.eq(run.gold, 50, "nothing found")
	# Nobody short: one of them at random, but always someone.
	var hit := {}
	for k in 300:
		var run2 := free_run(77)
		var site2 := make_site(run2, ScavengeSite.Risk.HIGH, [Stat.SPD, Stat.STR] as Array[String], [30, 30] as Array[int])
		set_stat(run2.roster[0], Stat.SPD, 25)
		set_stat(run2.roster[1], Stat.STR, 25)   # both 5 short: a tie
		run2.rng.seed = k
		var r2 := run2.scavenge(site2, [run2.roster[0], run2.roster[1]])
		if r2.outcome == ScavengeResult.Outcome.NOTHING:
			t.check(r2.injured != null, "someone is injured")
			hit[r2.party.find(r2.injured)] = true
	t.eq(hit.size(), 2, "a tie goes either way")


func test_scavenge_level_ups() -> void:
	var s := seed_for(ScavengeSite.Risk.LOW, ScavengeResult.Outcome.FULL)
	var run := free_run(77)
	var site := make_site(run, ScavengeSite.Risk.LOW, [Stat.SPD, Stat.STR] as Array[String], [10, 10] as Array[int])
	site.xp_each = 200
	var a := run.roster[0]
	var b := run.roster[1]
	set_stat(a, Stat.SPD, 10)
	set_stat(b, Stat.STR, 7)
	var level := a.level()
	var stats := a.progress.stats()
	run.rng.seed = s
	var r := run.scavenge(site, [a, b])
	t.eq(r.outcome, ScavengeResult.Outcome.FULL, "the same roll")
	var m := r.member_of(a)
	t.eq(m.level_before, level, "level before")
	t.eq(m.stats_before, stats, "stats before")
	t.eq(m.xp_gained, 200, "the XP")
	t.check(a.level() > level, "levelled up")
	t.eq(m.level_ups.size(), a.level() - level, "one entry per level")
	t.eq(int(m.level_ups[0].level_from), level, "from the level before")
	t.eq(m.level_ups[0].before, stats, "with the stats before")
	t.eq(m.level_ups[0].name, a.display_name(), "named")
	t.eq(r.level_ups().size(), r.members[0].level_ups.size() + r.members[1].level_ups.size(), "all of the trip's")
