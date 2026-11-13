extends RefCounted
## Headless tests for the infirmary (Run.infirmary, RunCompanion.injured / back_on_day), giving up a
## day with nobody to field (Run.yield_day) and the Cure action (Run.cure). Called from run_tests.gd,
## which owns check() and eq().

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_infirmary_timing,
		test_rest_and_daily_heal_skip_infirmary,
		test_infirmary_cannot_be_fielded_or_drilled,
		test_events_skip_infirmary,
		test_injured_from_a_battle,
		test_yield_when_nobody_can_fight,
		test_yield_on_boss_day_ends_run,
		test_cure_price,
		test_cure_action,
		test_leaving_restores_spell_uses,
		test_no_event_can_lock_the_day,
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


## Ends today whatever it is: a battle day is won at once, a free day's event answered.
func next_day(run: Run) -> void:
	match run.day_type():
		RunCalendar.DayType.BATTLE, RunCalendar.DayType.BOSS:
			if run.lineup.is_empty():
				for c in run.reserve():
					run.field(c)
			if run.lineup.is_empty():
				run.yield_day()
				return
			var b := run.start_battle(run.fronts[0])
			for e in b.enemies:
				e.hp = 0
			b._check_end()
			run.finish_battle(b)
		_:
			if run.event_pending():
				for ch in run.event.choices:
					if run.choice_block_reason(ch) == "":
						run.choose(ch)
						break
			run.end_free_day()


func companion(n: String) -> CompanionData:
	return load("res://data/companions/%s.tres" % n)


# ---------------------------------------------------------------- the stay

## Injured on day D: away D+1 .. D+N (N = RunConfig.INFIRMARY_DAYS, 4), out at the start of D+N+1 at
## full HP, on the bench.
func test_infirmary_timing() -> void:
	t.eq(RunConfig.INFIRMARY_DAYS, 4, "a stay is 4 days")
	var n := RunConfig.INFIRMARY_DAYS
	var run := make_run(301)
	var c := run.roster[0]
	var d := run.day
	run._to_infirmary(c)
	t.check(c.injured, "injured")
	t.eq(c.back_on_day, d + n + 1, "out on day D + N + 1")
	t.eq(c.days_left(d), n + 1, "N + 1 counted from the day of the injury")
	t.eq(run.infirmary(), [c] as Array[RunCompanion], "in the infirmary")
	t.check(not run.lineup.has(c), "out of the line")
	next_day(run)
	t.eq(run.day, d + 1, "the day after")
	t.eq(c.days_left(run.day), n, "N days still to serve the day after")
	while run.day < d + n:
		next_day(run)
		t.check(c.injured, "day %d: still in" % run.day)
	t.eq(c.days_left(run.day), 1, "1 on the last day")
	t.check(run.released_today.is_empty(), "nobody out yet")
	next_day(run)
	t.eq(run.day, d + n + 1, "day D + N + 1")
	t.check(not c.injured, "out")
	t.eq(c.hp, c.max_hp(), "at full HP")
	t.check(run.reserve().has(c) and not run.lineup.has(c), "on the bench, not in the line")
	t.eq(run.released_today, [c] as Array[RunCompanion], "named in the day's news")
	t.check(run.infirmary().is_empty(), "the infirmary is empty")
	next_day(run)
	t.check(run.released_today.is_empty(), "cleared the next day")
	# Order of going in.
	var run2 := make_run(302)
	run2._to_infirmary(run2.roster[1])
	run2._to_infirmary(run2.roster[0])
	t.eq(run2.infirmary(), [run2.roster[1], run2.roster[0]] as Array[RunCompanion], "in the order they went in")


func test_rest_and_daily_heal_skip_infirmary() -> void:
	var run := make_run(303)
	force_day(run, RunCalendar.DayType.FREE)
	var hurt := run.roster[0]
	var well := run.roster[1]
	run._to_infirmary(hurt)
	well.hp = 1
	t.check(run.rest(), "rest")
	t.eq(well.hp, well.max_hp(), "the others rest")
	t.eq(hurt.hp, 0, "Rest skips the infirmary")
	t.check(hurt.injured and hurt.back_on_day == run.day + RunConfig.INFIRMARY_DAYS + 1, "and never shortens the stay")
	well.hp = 1
	run.end_free_day()
	t.eq(hurt.hp, 0, "the daily heal skips them")
	t.check(well.hp > 1, "but not the others")
	# Rest with only the infirmary hurt is not needed.
	force_day(run, RunCalendar.DayType.FREE)
	well.hp = well.max_hp()
	well.progress.restore_spell_uses()
	t.check(run.free_action_block_reason(Run.FreeAction.REST) != "", "nothing to rest for: %s" % run.free_action_block_reason(Run.FreeAction.REST))


func test_infirmary_cannot_be_fielded_or_drilled() -> void:
	var run := make_run(304)
	force_day(run, RunCalendar.DayType.FREE)
	run.gold = 1000
	var c := run.roster[0]
	run._to_infirmary(c)
	var why := "%s is in the infirmary until day %d." % [c.display_name(), c.back_on_day]
	t.eq(run.field_block_reason(c), why, "cannot be fielded, says until when")
	t.check(not run.field(c), "field refused")
	t.check(not run.reserve().has(c) and not run.available().has(c), "not on the bench, not available")
	for d in run.drills:
		t.eq(run.drill_block_reason(d, c), why, "%s: cannot drill" % d.display_name)
	t.check(run.train(run.drills[0], c) == null, "train refused")
	t.check(run.hire_level() >= 1, "a hire still averages the whole roster")


func test_events_skip_infirmary() -> void:
	var run := make_run(305)
	var c := run.roster[0]
	run._to_infirmary(c)
	for target in [EventChoiceData.HpTarget.ALL, EventChoiceData.HpTarget.HEALTHIEST]:
		var ch := EventChoiceData.new()
		ch.companion_hp = -5
		ch.hp_target = target
		t.check(not run.hp_targets(ch).has(c), "events never touch the infirmary")


## From a real battle, won or lost: the injured get XP on a win and learn their grades.
func test_injured_from_a_battle() -> void:
	var run := make_run(306)
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	var c := run.lineup[0]
	var xp_before := c.progress.xp + Levels.total_xp_for(c.level())
	var b := run.start_battle(run.fronts[0])
	var unit := b.roster[0]
	var t0 := unit.weapon().weapon_type
	unit.progress.points[t0] = Proficiency.points_for(unit.progress.grade(t0) + 1) - 1
	b._gain_proficiency(unit, 1)
	b._damage_companion(unit, 9999, false)
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	var r := run.finish_battle(b)
	t.check(r.won and r.injured.has(c.display_name()), "won, with one injured")
	t.check(r.xp_of(c.display_name()) > 0, "the injured get their XP share")
	t.eq(c.progress.xp + Levels.total_xp_for(c.level()), xp_before + r.xp_of(c.display_name()), "and it is theirs")
	t.check(r.grade_ups.size() == 1 and r.grade_ups[0].art != null and c.progress.knows(r.grade_ups[0].art), "and learn what the grade teaches")
	t.check(c.injured and run.infirmary().has(c), "then the infirmary")


# ---------------------------------------------------------------- nobody to fight

func test_yield_when_nobody_can_fight() -> void:
	var run := make_run(307)
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	t.check(run.yield_block_reason() != "", "not while someone can be fielded: %s" % run.yield_block_reason())
	t.check(run.yield_day() == null, "refused")
	for c in run.roster:
		run._to_infirmary(c)
	t.eq(run.lineup.size(), 0, "the line is empty")
	t.eq(run.battle_block_reason(run.fronts[0]), Run.NOBODY_TO_FIELD, "no battle: nobody can march out")
	t.eq(run.yield_block_reason(), "", "the day can be given up")
	var worst: Front = run.fronts[0]
	for f in run.fronts:
		if f.city_damage > worst.city_damage:
			worst = f
	var city := run.city_health
	var lost := run.battles_lost
	var d := run.day
	var r := run.yield_day()
	t.check(r != null and not r.won and r.yielded, "a yielded day is a lost battle")
	t.eq(r.front, worst, "at the worst front")
	t.eq(r.city_damage, worst.city_damage, "it costs what a loss there costs")
	t.eq(run.city_health, city - worst.city_damage, "the walls")
	t.eq(run.battles_lost, lost + 1, "counted as lost")
	t.eq(r.xp_total(), 0, "no XP")
	t.eq(run.day, d + 1, "the day ends")
	# Not on a free day.
	force_day(run, RunCalendar.DayType.FREE)
	t.check(run.yield_block_reason() != "", "not on a free day")


func test_yield_on_boss_day_ends_run() -> void:
	var run := make_run(308)
	run.day = 14
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.BOSS, "a boss day")
	for c in run.roster:
		run._to_infirmary(c)
	var r := run.yield_day()
	t.check(r != null and r.run_over, "given up")
	t.eq(run.outcome, Run.Outcome.DEFEAT, "the city falls")


# ---------------------------------------------------------------- cure

func test_cure_price() -> void:
	var run := make_run(309)
	var c := run.roster[0]
	run._to_infirmary(c)
	run.day += 1   # the day after the injury: 4 to serve
	t.eq(c.days_left(run.day), 4, "4 days left")
	for case: Array in [[1, 24], [5, 56], [10, 96], [15, 136]]:
		c.progress.level = case[0]
		t.eq(run.cure_cost(c), case[1], "level %d with 4 days left: %d gold" % case)
	c.progress.level = 10
	var last := run.cure_cost(c)
	for i in RunConfig.INFIRMARY_DAYS - 2:
		run.day += 1
		t.check(run.cure_cost(c) < last, "day %d: the price falls" % run.day)
		last = run.cure_cost(c)
	t.eq(c.days_left(run.day), 2, "2 days left")
	t.eq(run.cure_cost(c), 48, "level 10 with 2 days left: 48")
	t.eq(run.cure_cost(run.roster[1]), 0, "nothing for someone not in the infirmary")


func test_cure_action() -> void:
	var run := make_run(310)
	run.day = 2
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.free_action_block_reason(Run.FreeAction.CURE), "Nobody is in the infirmary.", "nobody to cure")
	t.eq(Run.FREE_ACTION_NAMES[Run.FreeAction.CURE], "Cure", "named Cure")
	var c := run.roster[0]
	run._to_infirmary(c)
	var cost := run.cure_cost(c)
	run.gold = cost - 1
	t.eq(run.cure_block_reason(c), "Needs %d gold." % cost, "needs the gold")
	t.check(not run.cure(c), "refused")
	t.check(run.cure_block_reason(run.roster[1]).contains("not in the infirmary"), "only the infirmary")
	run.gold = cost + 5
	t.eq(run.free_action_block_reason(Run.FreeAction.CURE), "", "the building is open")
	t.check(run.cure(c), "cured")
	t.eq(run.gold, 5, "paid")
	t.eq(run.actions_left, 1, "the day's action is untouched")
	t.check(not run.actions_used.has(Run.FreeAction.CURE), "a cure is never the day's action")
	t.check(not c.injured and run.infirmary().is_empty(), "out of the infirmary")
	t.eq(c.hp, c.max_hp(), "at full HP")
	t.check(run.reserve().has(c) or run.lineup.has(c), "on the bench")
	run.bench(c)
	t.eq(run.field_block_reason(c), "", "can be fielded the same day")
	t.check(run.field(c), "fielded")
	# Another cure the same day, and after the day's action too.
	var other := run.roster[1]
	run._to_infirmary(other)
	run.gold = 10000
	run.roster[0].hp = 1
	t.check(run.rest(), "the day's action: rest")
	t.eq(run.cure_block_reason(other), "", "curing is still open after it")
	t.check(run.cure(other), "a second cure the same day")
	t.eq(run.actions_left, 0, "the cure takes no action of its own")
	t.eq(run.actions_used, [Run.FreeAction.REST] as Array[int], "only the rest is recorded as the action")
	# Two cures in a row, both before the action.
	run.end_free_day()
	force_day(run, RunCalendar.DayType.FREE)
	run._to_infirmary(run.roster[0])
	run._to_infirmary(other)
	run.gold = 10000
	t.check(run.cure(run.roster[0]) and run.cure(other), "two cures the same day")
	t.eq(run.actions_left, 1, "and the day's action is still there")
	t.check(run.infirmary().is_empty(), "both out")
	run._to_infirmary(other)
	# Not on a battle day; not before the event.
	force_day(run, RunCalendar.DayType.BATTLE)
	t.eq(run.cure_block_reason(other), "Only on free days.", "not on a battle day")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	t.eq(run.cure_block_reason(other), Run.EVENT_FIRST, "the gate's matter first")


## Both ways out of the infirmary bring every spell's uses back; Rest does nothing for someone inside.
func test_leaving_restores_spell_uses() -> void:
	var spell: SpellData = SpellLibrary.load_default().spells[0]
	# Serving the stay.
	var run := make_run(320)
	var c := run.roster[0]
	c.progress.learn_spell(spell)
	c.progress.spell_uses[spell] = 0
	var d := run.day
	run._to_infirmary(c)
	run.day = d + 1
	force_day(run, RunCalendar.DayType.FREE)
	run.roster[1].hp = 1
	t.check(run.rest(), "a rest while they are inside")
	t.eq(c.progress.uses_left(spell), 0, "does nothing for them")
	while c.injured and run.day < d + 12:
		next_day(run)
	t.check(not c.injured, "out after the stay")
	t.eq(c.progress.uses_left(spell), c.progress.max_uses(spell), "the stay served: every use back")
	# The cure.
	var run2 := make_run(321)
	run2.day = 2
	force_day(run2, RunCalendar.DayType.FREE)
	var m := run2.roster[0]
	m.progress.learn_spell(spell)
	m.progress.spell_uses[spell] = 1
	run2._to_infirmary(m)
	run2.gold = 10000
	t.eq(m.progress.uses_left(spell), 1, "spent before")
	t.check(run2.cure(m), "cured")
	t.eq(m.progress.uses_left(spell), m.progress.max_uses(spell), "cured: every use back")


## Every event in the content always has one choice that costs nothing the player might lack: with
## the whole roster in the infirmary (or with everyone fit), no gold and no materials, some choice is
## open, choosing it answers the event, and the day can then end (or the run is over).
func test_no_event_can_lock_the_day() -> void:
	var events := RunContent.load_default().events
	t.check(not events.is_empty(), "there are events")
	for ev in events:
		for everyone_away in [true, false]:
			var run := make_run(320)
			run.day = 2
			run.calendar[run.day - 1] = RunCalendar.DayType.FREE
			if not run.event_days.has(run.day):
				run.event_days.append(run.day)
			run._begin_day()
			run.event = ev
			run._draw_event_weapons()
			run.gold = 0
			run.materials = {}
			if everyone_away:
				for c in run.roster.duplicate():
					run._to_infirmary(c)
			var label := "%s (%s)" % [ev.title, "all in the infirmary" if everyone_away else "everyone fit"]
			var open: EventChoiceData = null
			for ch in ev.choices:
				if run.choice_block_reason(ch) == "":
					open = ch
					break
			t.check(open != null, "%s: a choice is open with no gold and no materials" % label)
			if open == null:
				continue
			t.check(run.choose(open) != "", "%s: choosing it answers the event" % label)
			t.check(not run.event_pending(), "%s: nothing waits" % label)
			t.check(run.is_over() or run.end_free_day(), "%s: the day can end" % label)
