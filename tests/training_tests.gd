extends RefCounted
## Headless tests for the training ground (Run.drills, Run.drill_block_reason, Run.train): the weekly
## posting, who can take which drill, cost and action, the amounts of each quality, grade-ups and
## level-ups from drills. Called from run_tests.gd, which owns check() and eq().

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_drills_posted_weekly,
		test_drills_only_useful_types,
		test_drill_block_reasons,
		test_drill_cost_and_action,
		test_drill_quality_amounts,
		test_drill_grade_up,
		test_sparring_level_up,
		test_bench_can_train,
		test_fighter_opens_a_school,
	]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


## Turns today into a free day without an event and prepares it again (drills stay as posted).
func free_day(run: Run) -> void:
	var posted := run.drills.duplicate()
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event_days.erase(run.day)
	run._begin_day()
	run.drills = posted


## Gives today's free action back, as if it were a new free day (for repeated drills in one test).
func fresh_action(run: Run) -> void:
	run.actions_used.clear()
	run.actions_left = RunConfig.FREE_DAY_ACTIONS


func answer_event(run: Run) -> void:
	if not run.event_pending():
		return
	for ch in run.event.choices:
		if run.choice_block_reason(ch) == "":
			run.choose(ch)
			return


func companion(name: String) -> CompanionData:
	return load("res://data/companions/%s.tres" % name)


## Replaces the roster with the named companions (fielded as the line allows), then posts drills.
func set_roster(run: Run, names: Array) -> void:
	run.roster.clear()
	run.lineup.clear()
	for n: String in names:
		run._join(companion(n))
	run._post_drills()


func useful_to_someone(run: Run, d: Drill) -> bool:
	for c in run.roster:
		if run._drill_unfit_reason(d, c) == "":
			return true
	return false


func drill_key(d: Drill) -> String:
	return "%d/%d/%d" % [d.kind, d.weapon_type, d.school]


# ---------------------------------------------------------------- posting

## Sparring always; two different useful proficiency drills; the same all week; a new set each week.
func test_drills_posted_weekly() -> void:
	var sets := {}
	for s in 30:
		var run := make_run(6100 + s)
		var week_drills: Array[Drill] = run.drills.duplicate()
		t.check(week_drills.size() >= 1 and week_drills.size() <= 1 + RunConfig.DRILLS_PROFICIENCY_PER_WEEK,
			"seed %d: up to three drills" % s)
		t.eq(week_drills[0].kind, Drill.Kind.SPARRING, "seed %d: Sparring is always posted, first" % s)
		t.eq(week_drills[0].display_name, "Sparring", "seed %d: named Sparring" % s)
		var keys := {}
		for d in week_drills.slice(1):
			t.check(d.is_proficiency(), "seed %d: the others are proficiency drills" % s)
			t.check(not keys.has(drill_key(d)), "seed %d: two different types" % s)
			keys[drill_key(d)] = true
			t.check(useful_to_someone(run, d), "seed %d: %s is useful to someone" % [s, d.display_name])
			t.check(d.display_name.ends_with(" drill"), "seed %d: named like 'Spear drill': %s" % [s, d.display_name])
		var names: Array[String] = []
		for d in week_drills:
			names.append(d.display_name)
		sets[", ".join(names)] = true
		# The same drills (the same objects) all week, whatever is done with them.
		while run.day < 8 and not run.is_over():
			t.eq(run.drills, week_drills, "seed %d day %d: the same drills all week" % [s, run.day])
			if run.day_type() == RunCalendar.DayType.FREE:
				if run.event_pending():
					for ch in run.event.choices:
						if run.choice_block_reason(ch) == "":
							run.choose(ch)
							break
				run.gold = 1000
				for d in run.drills:
					if run.drill_block_reason(d, run.roster[0]) == "":
						t.check(run.train(d, run.roster[0]) != null, "seed %d: trained" % s)
						break
				t.eq(run.drills, week_drills, "seed %d: a drill taken stays posted" % s)
				run.end_free_day()
			else:
				var b := run.start_battle(run.fronts[0])
				for e in b.enemies:
					e.hp = 0
				b._check_end()
				run.finish_battle(b)
		if run.is_over():
			continue
		t.eq(run.day, 8, "seed %d: week 2" % s)
		t.check(not run.drills.has(week_drills[0]) and not run.drills.has(week_drills[-1]), "seed %d: a new set is posted" % s)
		t.eq(run.drills[0].kind, Drill.Kind.SPARRING, "seed %d: Sparring again" % s)
	t.check(sets.size() > 3, "the drills vary between runs (%d different sets)" % sets.size())


## Any of the seven subjects (five weapon types, two schools) somebody is below S in: a drill opens
## one from E. Fewer when fewer are left.
func test_drills_only_useful_types() -> void:
	var run := make_run(62)
	# Elena has a grade only in axes, but every weapon type and both schools can be drilled.
	var subjects := {}
	for s in 60:
		var r := make_run(6200 + s)
		set_roster(r, ["elena"])
		t.eq(r.drills.size(), 3, "seed %d: Sparring and two proficiency drills" % s)
		for d in r.drills.slice(1):
			subjects[drill_key(d)] = true
			if d.kind == Drill.Kind.MAGIC:
				t.check(d.display_name in ["Black Magic drill", "White Magic drill"], "named: %s" % d.display_name)
	t.eq(subjects.size(), 7, "all seven subjects turn up (%d)" % subjects.size())
	# A subject at S for everyone is not posted.
	set_roster(run, ["elena"])
	var p := run.roster[0].progress
	for wt: int in WeaponData.WeaponType.values():
		if wt != WeaponData.WeaponType.BOW:
			p.points[wt] = Proficiency.points_for(Proficiency.Grade.S)
	for sc: int in SpellData.School.values():
		p.magic_points[sc] = Proficiency.points_for(Proficiency.Grade.S)
	run._post_drills()
	t.eq(run.drills.size(), 2, "only the bow is left to train")
	t.eq(run.drills[1].weapon_type, WeaponData.WeaponType.BOW, "the bow drill")
	t.eq(run.drills[1].display_name, "Bow drill", "named")
	p.magic_points[SpellData.School.WHITE] = 0
	run._post_drills()
	t.eq(run.drills.size(), 3, "white magic is back")
	t.check(run.drills[2].kind == Drill.Kind.MAGIC and run.drills[2].school == SpellData.School.WHITE, "after the weapon drill")
	p.points[WeaponData.WeaponType.BOW] = Proficiency.points_for(Proficiency.Grade.S)
	p.magic_points[SpellData.School.WHITE] = Proficiency.points_for(Proficiency.Grade.S)
	run._post_drills()
	t.eq(run.drills.size(), 1, "only Sparring when every grade is done")


## A fighter opens white magic by drills: E+ teaches a white spell, castable in the next battle, and
## Rest restores its uses.
func test_fighter_opens_a_school() -> void:
	var run := make_run(69)
	set_roster(run, ["kaito"])
	free_day(run)
	run.gold = 100
	var kaito := run.roster[0]
	var white := Drill.magic(SpellData.School.WHITE)
	run.drills = [run.drills[0], white]
	t.eq(kaito.progress.magic_grade(SpellData.School.WHITE), Proficiency.Grade.E, "Kaito starts at E in white magic")
	t.check(kaito.progress.known_spells.is_empty(), "and knows no spell")
	t.eq(run.drill_block_reason(white, kaito), "", "a white magic drill is open to him")
	kaito.progress.magic_points[SpellData.School.WHITE] = Proficiency.points_for(Proficiency.Grade.E_PLUS) - 1
	var r := run.train(white, kaito)
	t.check(r != null and r.grade_before == Proficiency.Grade.E and r.grade_after >= Proficiency.Grade.E_PLUS, "E+ reached")
	var spell: SpellData = r.grade_ups[0].spell
	t.check(spell != null and spell.school == SpellData.School.WHITE and kaito.progress.knows_spell(spell), "a white spell is learned")
	t.eq(kaito.progress.spell_schools(), [SpellData.School.WHITE] as Array[int], "he now has a school")
	# The next battle: he can cast it, weakly or not.
	run.end_free_day()
	while run.day_type() == RunCalendar.DayType.FREE:
		answer_event(run)
		run.end_free_day()
	var b := run.start_battle(run.fronts[0])
	var unit := b.roster[0]
	t.check(unit.spells().has(spell), "the spell is in his list in battle")
	t.eq(b.spell_block_reason(unit, spell), "", "and can be cast")
	var target: Combatant = unit if spell.targets_allies() else b.enemies[0]
	t.check(b.cast(unit, spell, target), "cast")
	t.eq(kaito.progress.uses_left(spell), spell.uses - 1, "a use spent")
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	run.finish_battle(b)
	# Rest restores it.
	while run.day_type() != RunCalendar.DayType.FREE or run.event_pending():
		if run.event_pending():
			answer_event(run)
			continue
		var b2 := run.start_battle(run.fronts[0])
		for e in b2.enemies:
			e.hp = 0
		b2._check_end()
		run.finish_battle(b2)
	t.check(run.rest(), "rested")
	t.eq(kaito.progress.uses_left(spell), spell.uses, "Rest restores its uses")


# ---------------------------------------------------------------- who and when

func test_drill_block_reasons() -> void:
	var run := make_run(63)
	set_roster(run, ["elena", "elio"])
	var elena := run.roster[0]
	var elio := run.roster[1]
	var sparring := run.drills[0]
	var axe := Drill.weapon(WeaponData.WeaponType.AXE)
	var white := Drill.magic(SpellData.School.WHITE)
	run.drills = [sparring, axe, white]
	# Not on a battle day (day 2: no weekly restock to post new drills).
	run.day = 2
	run.calendar[run.day - 1] = RunCalendar.DayType.BATTLE
	run._begin_day()
	t.eq(run.free_action_block_reason(Run.FreeAction.TRAIN), "Only on free days.", "not on a battle day")
	t.eq(run.drill_block_reason(sparring, elena), "Only on free days.", "the drill says so too")
	t.check(run.train(sparring, elena) == null, "no drill on a battle day")
	# The event comes first.
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	run.gold = 100
	t.check(run.event_pending(), "an event waits")
	t.eq(run.free_action_block_reason(Run.FreeAction.TRAIN), Run.EVENT_FIRST, "answer the event first")
	t.eq(run.drill_block_reason(sparring, elena), Run.EVENT_FIRST, "for every drill")
	free_day(run)
	# Gold.
	run.gold = RunConfig.DRILL_COST - 1
	t.eq(run.drill_block_reason(sparring, elena), "Needs %d gold." % RunConfig.DRILL_COST, "costs gold")
	run.gold = RunConfig.DRILL_COST
	t.eq(run.drill_block_reason(sparring, elena), "", "exactly enough")
	# Who can take which.
	t.eq(run.drill_block_reason(axe, elena), "", "Elena trains axes")
	t.eq(run.drill_block_reason(axe, elio), "", "Elio has no axe grade, but a weapon drill opens the type")
	t.eq(run.drill_block_reason(white, elena), "", "Elena has no white grade, but a drill opens the school")
	t.eq(run.drill_block_reason(white, elio), "", "Elio trains white magic")
	elena.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.S)
	t.check(run.drill_block_reason(axe, elena).contains("already at S"), "not at the highest grade")
	elena.progress.level = RunConfig.MAX_LEVEL
	t.check(run.drill_block_reason(sparring, elena).contains("top level"), "no sparring at the top level")
	t.eq(run.drill_block_reason(sparring, elio), "", "Elio can still spar")
	t.eq(run.drill_block_reason(Drill.weapon(WeaponData.WeaponType.AXE), elio), "Not posted this week.", "only posted drills")
	var stranger := RunCompanion.create(companion("kaito"))
	t.eq(run.drill_block_reason(sparring, stranger), "Not in the company.", "only the roster")
	# Nobody could learn anything: the action itself says so.
	elio.progress.level = RunConfig.MAX_LEVEL
	elio.progress.magic_points[SpellData.School.WHITE] = Proficiency.points_for(Proficiency.Grade.S)
	t.eq(run.free_action_block_reason(Run.FreeAction.TRAIN), "", "Elio can still open axes")
	elio.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.S)
	t.eq(run.free_action_block_reason(Run.FreeAction.TRAIN), "", "Elena can still open white magic")
	elena.progress.magic_points[SpellData.School.WHITE] = Proficiency.points_for(Proficiency.Grade.S)
	t.eq(run.free_action_block_reason(Run.FreeAction.TRAIN), Run.NO_USEFUL_DRILL, "nothing left to learn")
	elio.progress.level = 1
	# After another action, no drill; after a drill, nothing else.
	fresh_action(run)
	run.roster[1].hp = 1
	t.check(run.rest(), "rested")
	t.eq(run.drill_block_reason(sparring, elio), "No actions left today.", "the day's action is spent")
	fresh_action(run)
	t.check(run.train(sparring, elio) != null, "trained")
	t.eq(run.drill_block_reason(sparring, elio), "Already done today.", "one drill a day")
	run.roster[1].hp = 1
	t.check(not run.rest(), "and no rest after it")
	t.eq(run.free_action_block_reason(Run.FreeAction.REST), "No actions left today.", "says why")


func test_drill_cost_and_action() -> void:
	var run := make_run(64)
	set_roster(run, ["kaito"])
	free_day(run)
	run.gold = 100
	var c := run.roster[0]
	var drill := run.drills[0]
	t.eq(run.actions_left, 1, "one action")
	var r := run.train(drill, c)
	t.check(r != null, "trained")
	t.eq(run.gold, 100 - RunConfig.DRILL_COST, "paid %d gold" % RunConfig.DRILL_COST)
	t.eq(r.gold_spent, RunConfig.DRILL_COST, "the result says so")
	t.eq(RunConfig.DRILL_COST, 30, "a drill costs 30 gold")
	t.eq(run.actions_left, 0, "the day's action is spent")
	t.check(run.actions_used.has(Run.FreeAction.TRAIN), "as Train")
	t.eq(Run.FREE_ACTION_NAMES[Run.FreeAction.TRAIN], "Train", "named Train")
	t.check(run.drills.has(drill), "the drill stays posted")
	t.check(run.end_free_day(), "the day ends")
	# Another free day of the same week: the same drill again.
	while run.day_type() != RunCalendar.DayType.FREE or run.has_event_day():
		run.day += 1
		run._begin_day()
	t.check(run.day < 8, "still week 1 (day %d)" % run.day)
	t.check(run.train(drill, c) != null, "the same drill another day")


# ---------------------------------------------------------------- results

func test_drill_quality_amounts() -> void:
	# Sparring XP by the formula: good = day's danger-2 pool / 4 / 2; poor 60%, great 150%.
	var run := make_run(65)
	set_roster(run, ["kaito", "elena"])
	free_day(run)
	for d in [1, 20, 41]:
		var pool := Run.xp_pool(2, d)
		var good := float(pool) / RunConfig.MAX_FIELDED / 2.0
		t.eq(run.drill_xp(DrillResult.Quality.GOOD, d), roundi(good), "day %d: good sparring is half an even share of %d" % [d, pool])
		t.eq(run.drill_xp(DrillResult.Quality.POOR, d), roundi(good * 0.6), "day %d: poor is 60%%" % d)
		t.eq(run.drill_xp(DrillResult.Quality.GREAT, d), roundi(good * 1.5), "day %d: great is 150%%" % d)
	t.eq(run.drill_xp(DrillResult.Quality.GOOD, 1), 11, "day 1: 86 / 4 / 2 = 11")
	t.eq(Run.xp_pool(2, 1), RunConfig.XP_POOL_BY_DANGER[1], "the day 1 pool")
	for q in 3:
		t.eq(RunConfig.DRILL_POINTS[q], [3, 5, 8][q], "points by quality")
		t.eq(RunConfig.DRILL_QUALITY_WEIGHTS[q], [25, 50, 25][q], "poor 25%, good 50%, great 25%")
	var kaito := run.roster[0]
	var sword := Drill.weapon(WeaponData.WeaponType.SWORD)
	var sparring := run.drills[0]
	run.drills = [sparring, sword]
	var counts := [0, 0, 0]
	var n := 1200
	for i in n:
		fresh_action(run)
		run.gold = 100
		kaito.progress.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.D_PLUS)
		kaito.progress.level = 1
		kaito.progress.xp = 0
		var spar := i % 2 == 1
		var r := run.train(sparring if spar else sword, kaito)
		t.check(r != null, "trained")
		if r == null:
			continue
		counts[r.quality] += 1
		t.eq(r.quality_name, DrillResult.QUALITY_NAMES[r.quality], "the quality's word")
		t.eq(r.companion, kaito, "who")
		if spar:
			t.eq(r.xp_gained, run.drill_xp(r.quality), "sparring XP by quality")
			t.eq(r.points_gained, 0, "no points from sparring")
		else:
			t.eq(r.points_gained, RunConfig.DRILL_POINTS[r.quality], "%s drill: points by quality" % r.quality_name)
			t.eq(kaito.progress.points_in(WeaponData.WeaponType.SWORD), Proficiency.points_for(Proficiency.Grade.D_PLUS) + r.points_gained, "added")
			t.eq(r.grade_before, Proficiency.Grade.D_PLUS, "grade before")
			t.eq(r.xp_gained, 0, "no XP from a proficiency drill")
	print("  drill quality over %d drills: poor %d, good %d, great %d" % [n, counts[0], counts[1], counts[2]])
	t.check(absf(counts[0] / float(n) - 0.25) < 0.05, "poor about 25%")
	t.check(absf(counts[1] / float(n) - 0.5) < 0.05, "good about 50%")
	t.check(absf(counts[2] / float(n) - 0.25) < 0.05, "great about 25%")
	# Never past S.
	fresh_action(run)
	run.gold = 100
	kaito.progress.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.S) - 1
	var last := run.train(sword, kaito)
	t.eq(last.points_gained, 1, "points stop at S")
	t.eq(last.grade_after, Proficiency.Grade.S, "S reached")


func test_drill_grade_up() -> void:
	var run := make_run(66)
	set_roster(run, ["elena", "elio"])
	free_day(run)
	var elena := run.roster[0]
	var elio := run.roster[1]
	var axe := Drill.weapon(WeaponData.WeaponType.AXE)
	var white := Drill.magic(SpellData.School.WHITE)
	run.drills = [run.drills[0], axe, white]
	# One point short of C: any drill reaches it and teaches an axe art.
	run.gold = 100
	elena.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.C) - 1
	var arts_before := elena.progress.known_arts.size()
	var r := run.train(axe, elena)
	t.check(r != null, "trained")
	t.eq(r.grade_before, Proficiency.Grade.D_PLUS, "from D+")
	t.eq(r.grade_after, Proficiency.Grade.C, "to C")
	t.check(r.new_grade(), "a new grade")
	t.eq(r.grade_ups.size(), 1, "one grade reached")
	var up := r.grade_ups[0]
	t.eq(up.grade, Proficiency.Grade.C, "the grade")
	t.eq(up.weapon_type, WeaponData.WeaponType.AXE, "the type")
	t.eq(up.magic, false, "a weapon grade")
	t.eq(up.actor, elena, "who")
	t.check(up.art != null and up.art.weapon_type == WeaponData.WeaponType.AXE, "an axe art is learned")
	t.check(up.art != null and elena.progress.knows(up.art), "and known")
	t.eq(elena.progress.known_arts.size(), arts_before + 1, "one more art")
	# No grade reached: nothing learned.
	fresh_action(run)
	elena.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.C)
	var r2 := run.train(axe, elena)
	t.check(not r2.new_grade() and r2.grade_ups.is_empty(), "no grade, nothing learned")
	t.eq(r2.grade_before, r2.grade_after, "same grade")
	# A school grade teaches a spell.
	fresh_action(run)
	elio.progress.magic_points[SpellData.School.WHITE] = Proficiency.points_for(Proficiency.Grade.C) - 1
	var spells_before := elio.progress.known_spells.size()
	var r3 := run.train(white, elio)
	t.check(r3.new_grade(), "a white magic grade")
	t.eq(r3.grade_ups[0].magic, true, "a magic grade")
	t.eq(r3.grade_ups[0].school, SpellData.School.WHITE, "white")
	t.check(r3.grade_ups[0].spell != null and elio.progress.knows_spell(r3.grade_ups[0].spell), "a spell is learned")
	t.eq(elio.progress.known_spells.size(), spells_before + 1, "one more spell")
	# A weapon drill opens a new type from E: reaching E+ teaches an art of it.
	fresh_action(run)
	t.eq(elio.progress.grade(WeaponData.WeaponType.AXE), Proficiency.Grade.E, "Elio starts at E in axes")
	run.gold = 100
	elio.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.E_PLUS) - 1
	var r4 := run.train(axe, elio)
	t.check(r4 != null, "an axe drill from E")
	t.eq(r4.grade_before, Proficiency.Grade.E, "from E")
	t.check(r4.grade_after >= Proficiency.Grade.E_PLUS, "to E+ or beyond")
	t.eq(r4.grade_ups.size(), r4.grade_after - r4.grade_before, "one entry per grade reached")
	t.check(r4.grade_ups[0].grade == Proficiency.Grade.E_PLUS and r4.grade_ups[0].art != null and elio.progress.knows(r4.grade_ups[0].art), "E+ teaches an axe art")


func test_sparring_level_up() -> void:
	var run := make_run(67)
	set_roster(run, ["kaito"])
	free_day(run)
	run.gold = 100
	var c := run.roster[0]
	c.progress.xp = Levels.xp_to_next(1) - 1
	var stats := c.progress.stats()
	var hp_before := c.hp
	var r := run.train(run.drills[0], c)
	t.check(r != null, "sparred")
	t.check(r.xp_gained >= 1, "some XP")
	t.eq(r.level_before, 1, "level before")
	t.eq(r.stats_before, stats, "stats before")
	t.eq(c.level(), 2, "a level gained")
	t.eq(r.level_ups.size(), 1, "one level-up")
	var up := r.level_ups[0]
	t.eq(up.name, c.display_name(), "BattleReport shape: name")
	t.eq(up.level, 2, "BattleReport shape: level reached")
	t.check(up.gains is Dictionary and up.gains.size() >= RunConfig.MIN_STAT_GAINS, "BattleReport shape: gains")
	t.eq(up.level_from, 1, "level from")
	t.eq(up.before, stats, "the stats at that level")
	t.eq(c.hp, hp_before + int(up.gains.get(Stat.HP, 0)), "max HP gained raises HP")
	t.eq(c.progress.xp, r.xp_gained - 1, "the XP left over carries")
	t.eq(r.points_gained, 0, "no proficiency")
	t.eq(r.grade_before, -1, "no grade")
	# No level: no level-ups.
	fresh_action(run)
	c.progress.xp = 0
	var r2 := run.train(run.drills[0], c)
	t.check(r2.level_ups.is_empty(), "too little XP for a level")


func test_bench_can_train() -> void:
	var run := make_run(68)
	set_roster(run, ["kaito", "elena", "erik", "ingrid", "aina"])
	free_day(run)
	run.gold = 100
	var benched := run.roster[4]
	t.check(not run.is_fielded(benched), "Aina is on the bench")
	t.eq(run.drill_block_reason(run.drills[0], benched), "", "a bench companion may train")
	var xp := benched.progress.xp
	var r := run.train(run.drills[0], benched)
	t.check(r != null and r.companion == benched, "trained on the bench")
	t.eq(benched.progress.xp, xp + r.xp_gained, "XP to the bench companion")
