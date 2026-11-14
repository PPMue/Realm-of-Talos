extends RefCounted
## Headless tests for the run rules (calendar, fronts, battles in a run, city, party, free days,
## events) and the automated playthrough. Called from run_tests.gd, which owns check() and eq().

const RunPolicy := preload("res://tests/run_policy.gd")

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_calendar_shape,
		test_event_days,
		test_same_seed_same_run,
		test_upcoming_days,
		test_run_start,
		test_front_generation_by_danger,
		test_enemy_scaling,
		test_battle_uses_run_hp_and_weapon,
		test_win_grants_reward,
		test_loss_costs_city_and_run_continues,
		test_lost_boss_ends_run,
		test_day_42_win,
		test_city_health_zero_ends_run,
		test_nobody_is_ever_removed,
		test_daily_heal,
		test_injured_go_to_infirmary,
		test_fielded_limit_and_order,
		test_party_locked_after_commit,
		test_free_day_action_limits,
		test_event_opens_free_day,
		test_weekly_refresh,
		test_rest,
		test_shop_and_equip_requirement,
		test_weapon_held_by_one,
		test_tavern_hiring,
		test_repair,
		test_event_choices,
		test_run_content,
		test_level_thresholds,
		test_growth_rates,
		test_bld_never_rises,
		test_minimum_stat_gains,
		test_level_gains_reach_battle,
		test_split_xp,
		test_xp_split_among_fielded,
		test_xp_follows_battle_points,
		test_no_xp_on_loss,
		test_max_hp_gain_raises_hp,
		test_tavern_hire_level,
		test_level_pace,
		test_playthrough,
	]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


## Turns today into a day of `type` and prepares it again.
func force_day(run: Run, type: int) -> void:
	run.calendar[run.day - 1] = type
	run._begin_day()


## Turns today into a free day that begins with an event (`ev`, or one drawn as the run would).
func force_event(run: Run, ev: EventData = null) -> void:
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	if ev != null:
		run.event = ev
		run._draw_event_weapons()


## Plays today the plainest way: a battle is won on the first front; a free day answers its event
## with the first choice it can afford and then ends.
func advance(run: Run) -> void:
	match run.day_type():
		RunCalendar.DayType.BATTLE, RunCalendar.DayType.ELITE, RunCalendar.DayType.BOSS:
			fight(run, true)
		RunCalendar.DayType.FREE:
			if run.event_pending():
				for ch in run.event.choices:
					if run.choice_block_reason(ch) == "":
						run.choose(ch)
						break
			run.end_free_day()


func content() -> RunContent:
	return RunContent.load_default()


func companion(n: String) -> CompanionData:
	return load("res://data/companions/%s.tres" % n)


## Starts today's battle on the first front and ends it at once: every enemy falls, or every
## fielded companion is injured. `before_end` may change the battle first.
func fight(run: Run, win: bool, front: Front = null, before_end: Callable = Callable()) -> BattleReport:
	var f := front if front != null else run.fronts[0]
	var b := run.start_battle(f)
	t.check(b != null, "battle starts")
	if before_end.is_valid():
		before_end.call(b)
	if win:
		for e in b.enemies:
			e.hp = 0
	else:
		for c in b.line():
			c.hp = 0
			c.state = CompanionUnit.State.INJURED
	b._check_end()
	return run.finish_battle(b)


func heal_amount(c: RunCompanion) -> int:
	return ceili(c.max_hp() * RunConfig.DAILY_HEAL_FRACTION)


func names(cs: Array[RunCompanion]) -> Array[String]:
	var out: Array[String] = []
	for c in cs:
		out.append(c.display_name())
	return out


# ---------------------------------------------------------------- calendar

## Six weeks of seven days. Week 1: battle, free, battle, free, free, elite, free. The boss weeks:
## battle, free, battle, free, battle, free, boss (days 14, 28, 42). The week after a boss: free, battle,
## free, battle, free, elite, free. Elites on days 6, 20, 34.
func test_calendar_shape() -> void:
	var D := RunCalendar.DayType
	var cal := RunCalendar.generate()
	t.eq(cal.size(), 42, "42 days")
	t.eq(RunConfig.DAYS, 42, "a run is 42 days")
	t.eq(cal.size() % RunConfig.WEEK_DAYS, 0, "whole weeks")
	t.eq(cal[0], D.BATTLE, "day 1 is a battle")
	var counts := [0, 0, 0, 0]
	for d in range(1, cal.size() + 1):
		counts[cal[d - 1]] += 1
		var boss := d == 14 or d == 28 or d == 42
		t.check((cal[d - 1] == D.BOSS) == boss, "boss only on days 14, 28, 42 (day %d)" % d)
		t.eq(RunCalendar.is_boss_day(d), boss, "is_boss_day(%d)" % d)
		if boss:
			t.eq(cal[d - 2], D.FREE, "day %d before a boss is free" % (d - 1))
			t.eq(RunCalendar.boss_index(d), d / 14 - 1, "boss index on day %d" % d)
		var in_week := (d - 1) % 7 + 1
		var week := (d - 1) / 7 + 1
		var shape: String = ["BFBFFEF", "BFBFBFX", "FBFBFEF", "BFBFBFX", "FBFBFEF", "BFBFBFX"][week - 1]
		var want: int = {"B": D.BATTLE, "F": D.FREE, "X": D.BOSS, "E": D.ELITE}[shape[in_week - 1]]
		t.eq(cal[d - 1], want, "day %d (week %d, day %d of the week)" % [d, week, in_week])
		t.eq(RunCalendar.type_on(d), want, "type_on(%d)" % d)
		t.eq(RunCalendar.after_boss_week(d), week == 3 or week == 5, "after_boss_week(%d)" % d)
		if boss and d < cal.size():
			t.eq(cal[d], D.FREE, "the day after the boss of day %d is free" % d)
		var elite := d == 6 or d == 20 or d == 34
		t.eq(RunCalendar.is_elite_day(d), elite, "is_elite_day(%d)" % d)
		if elite:
			t.eq(cal[d - 2], D.FREE, "day %d before an elite is free" % (d - 1))
		t.eq(RunCalendar.is_fight(cal[d - 1]), cal[d - 1] != D.FREE, "is_fight on day %d" % d)
		t.eq(RunCalendar.is_big_fight(cal[d - 1]), boss or elite, "is_big_fight on day %d" % d)
		# Alternation: never two fights in a row; two free days in a row only on days 4 and 5.
		if d < cal.size():
			var fight_today: bool = cal[d - 1] != D.FREE
			var fight_next: bool = cal[d] != D.FREE
			t.check(not (fight_today and fight_next), "never two fights in a row (day %d)" % d)
			if not fight_today and not fight_next:
				t.eq(d, 4, "two free days in a row only on days 4 and 5 (day %d)" % d)
	t.eq(counts[D.BATTLE], 15, "15 battles")
	t.eq(counts[D.ELITE], 3, "3 elites")
	t.eq(counts[D.FREE], 21, "21 free days")
	t.eq(counts[D.BOSS], 3, "3 bosses")
	t.eq(RunCalendar.NAMES[D.ELITE], "ELITE", "its name")
	t.eq([D.BATTLE, D.FREE, D.BOSS, D.ELITE], [0, 1, 2, 3], "the older values keep their numbers")
	t.eq(RunCalendar.week_of(1), 1, "day 1 is week 1")
	t.eq(RunCalendar.week_of(7), 1, "day 7 is week 1")
	t.eq(RunCalendar.week_of(8), 2, "day 8 is week 2")
	t.eq(RunCalendar.week_of(42), 6, "day 42 is week 6")
	for d in range(1, 43):
		t.eq(RunCalendar.is_week_start(d), [1, 8, 15, 22, 29, 36].has(d), "week start on day %d" % d)
	# Days until the next restock: within the run only.
	t.eq(RunCalendar.days_until_restock(1), 7, "day 1: 7 days")
	t.eq(RunCalendar.days_until_restock(7), 1, "day 7: tomorrow")
	t.eq(RunCalendar.days_until_restock(8), 7, "day 8: 7 again")
	t.eq(RunCalendar.days_until_restock(30), 6, "day 30: 6 (day 36)")
	t.eq(RunCalendar.days_until_restock(35), 1, "day 35: 1")
	for d in range(36, 43):
		t.eq(RunCalendar.days_until_restock(d), -1, "day %d: no restock left" % d)
	for d in range(1, 36):
		t.check(RunCalendar.is_week_start(d + RunCalendar.days_until_restock(d)), "day %d: lands on a week start" % d)


## One event in every week, on a free day that is not the day before a boss (so never on an elite).
func test_event_days() -> void:
	var D := RunCalendar.DayType
	var cal := RunCalendar.generate()
	var used := {}
	for s in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var days := RunCalendar.pick_event_days(cal, rng)
		t.eq(days.size(), 6, "seed %d: six events in a run" % s)
		var per_week := {}
		for d in days:
			t.eq(cal[d - 1], D.FREE, "seed %d: event on a free day (day %d)" % [s, d])
			t.check(d >= cal.size() or cal[d] != D.BOSS, "seed %d: never the day before a boss (day %d)" % [s, d])
			per_week[RunCalendar.week_of(d)] = per_week.get(RunCalendar.week_of(d), 0) + 1
			used[d] = true
		for w in range(1, 7):
			t.eq(per_week.get(w, 0), 1, "seed %d: one event in week %d" % [s, w])
	for d in [13, 27, 41]:
		t.check(not used.has(d), "day %d (before a boss) never has an event" % d)
	t.check(used.size() >= 12, "events land on many different free days (%d)" % used.size())
	var a := make_run(5)
	var b := make_run(5)
	t.eq(a.event_days, b.event_days, "same seed, same event days")


func test_same_seed_same_run() -> void:
	var a := make_run(42)
	var b := make_run(42)
	t.eq(a.calendar, b.calendar, "same calendar")
	t.eq(names(a.roster), names(b.roster), "same starting companions")
	t.eq(a.fronts.size(), b.fronts.size(), "same number of fronts")
	for i in a.fronts.size():
		t.eq(a.fronts[i].group, b.fronts[i].group, "same enemy group on front %d" % i)
		t.eq(a.fronts[i].reward_gold, b.fronts[i].reward_gold, "same reward on front %d" % i)
		t.eq(a.fronts[i].site, b.fronts[i].site, "same site on front %d" % i)
	var pa := RunPolicy.new(_seeded(7))
	var pb := RunPolicy.new(_seeded(7))
	pa.play(a)
	pb.play(b)
	t.eq(a.outcome, b.outcome, "same outcome")
	t.eq(a.day, b.day, "same last day")
	t.eq(a.gold, b.gold, "same gold")
	t.eq(a.city_health, b.city_health, "same city health")
	t.eq(names(a.roster), names(b.roster), "same survivors")
	var c := make_run(43)
	var differs := c.calendar != a.calendar or names(c.roster) != names(make_run(42).roster)
	t.check(differs, "another seed gives another run")


func _seeded(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


func test_upcoming_days() -> void:
	var run := make_run(3)
	var up := run.upcoming()
	t.eq(up.size(), 8, "today and the next 7 days")
	t.eq(up[0], run.day_type(), "starts with today")
	for i in up.size():
		t.eq(up[i], run.calendar[i], "day %d type" % (i + 1))
	run.day = 38
	t.eq(run.upcoming().size(), 5, "near the end only the days left (38-42)")


func test_run_start() -> void:
	var seen := {}
	for s in 60:
		var run := make_run(s)
		t.eq(run.roster.size(), 2, "starts with 2 companions")
		t.check(run.roster[0].data != run.roster[1].data, "two different companions")
		t.eq(run.lineup.size(), 2, "both fielded")
		t.eq(run.city_health, 100, "city at 100")
		t.eq(run.day, 1, "day 1")
		t.eq(run.day_type(), RunCalendar.DayType.BATTLE, "day 1 battle")
		for c in run.roster:
			t.eq(c.hp, c.max_hp(), "full HP")
			t.eq(run.inventory.held_by(c).data, c.data.weapon, "holds their own weapon")
			seen[c.display_name()] = true
		# The armory: one wooden weapon of every type, the starters' own counted.
		var by_type := {}
		for w in run.inventory.weapons:
			t.eq(w.data.tier, WeaponData.Tier.WOODEN, "seed %d: only wooden weapons at the start" % s)
			by_type[w.data.weapon_type] = int(by_type.get(w.data.weapon_type, 0)) + 1
		for wt: int in WeaponData.WeaponType.values():
			var starters := run.roster.filter(func(c: RunCompanion) -> bool: return c.data.weapon.weapon_type == wt).size()
			t.eq(by_type.get(wt, 0), maxi(1, starters), "seed %d: %s: the starters' own, or one added" % [s, WeaponData.type_name(wt)])
		var shared := run.roster[0].data.weapon.weapon_type == run.roster[1].data.weapon.weapon_type
		t.eq(run.inventory.weapons.size(), 6 if shared else 5, "seed %d: %d weapons" % [s, 6 if shared else 5])
		t.eq(run.inventory.unheld().size(), run.inventory.weapons.size() - 2, "the added ones are unheld")
	t.eq(seen.size(), content().companions.size(), "every companion can start a run")
	# A hire later brings only their own weapon.
	var run := make_run(3)
	run.day = 2
	run.calendar[1] = RunCalendar.DayType.FREE
	run.event_days.erase(2)
	run._begin_day()
	run.gold = 1000
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	var count := run.inventory.weapons.size()
	t.check(run.hire(run.tavern_offers[0]) != null, "hired")
	t.eq(run.inventory.weapons.size(), count + 1, "a hire adds only their own weapon")


# ---------------------------------------------------------------- fronts and enemies

func test_front_generation_by_danger() -> void:
	var counts := {2: 0, 3: 0}
	var hp_by_danger := [0.0, 0.0, 0.0]
	var n_by_danger := [0, 0, 0]
	var materials_by_danger := [0, 0, 0]
	for s in 40:
		var run := make_run(s)
		for d in range(1, RunConfig.DAYS + 1):
			if RunCalendar.is_boss_day(d):
				continue
			run.day = d
			force_day(run, RunCalendar.DayType.BATTLE)
			var fs := run.fronts
			t.check(fs.size() == 2 or fs.size() == 3, "2 or 3 fronts")
			counts[fs.size()] = counts.get(fs.size(), 0) + 1
			var last := 0
			var last_gold := -1
			var sites := {}
			for f in fs:
				t.check(f.danger > last, "dangers differ and rise (day %d)" % d)
				last = f.danger
				t.check(f.reward_gold > last_gold, "higher danger pays more (day %d)" % d)
				last_gold = f.reward_gold
				t.eq(f.city_damage, RunConfig.CITY_DAMAGE_BY_DANGER[f.danger - 1], "city damage by danger")
				t.check(f.group.appears_on(d) and f.group.danger == f.danger, "group fits day and danger")
				t.check(not f.enemies.is_empty(), "front has enemies")
				t.check(f.site != null and not sites.has(f.site), "each front its own site")
				sites[f.site] = true
				var hp := 0
				for e in f.enemies:
					hp += e.max_hp
				hp_by_danger[f.danger - 1] += hp
				n_by_danger[f.danger - 1] += 1
				if not f.reward_materials.is_empty():
					materials_by_danger[f.danger - 1] += 1
	t.check(counts[2] > 0 and counts[3] > 0, "both 2 and 3 fronts happen")
	var avg := []
	for i in 3:
		avg.append(hp_by_danger[i] / maxf(1, n_by_danger[i]))
	t.check(avg[0] < avg[1] and avg[1] < avg[2], "average enemy HP rises with danger %s" % str(avg))
	var mat := []
	for i in 3:
		mat.append(float(materials_by_danger[i]) / maxf(1, n_by_danger[i]))
	t.check(mat[0] < mat[1] and mat[1] < mat[2], "materials more likely with danger %s" % str(mat))
	t.eq(mat[2], 1.0, "danger 3 always gives materials")
	print("  fronts: %d days with 2, %d with 3; avg enemy HP by danger %s" % [counts[2], counts[3], str(avg)])


func test_enemy_scaling() -> void:
	var orc: EnemyData = load("res://data/enemies/orc.tres")
	var d1 := Run.scaled_enemy(orc, 1)
	t.eq(d1.max_hp, roundi(orc.max_hp * RunConfig.ENEMY_HP_MULT), "day 1: the base HP times the multiplier")
	t.eq(d1.strength, orc.strength, "day 1 unchanged STR")
	t.check(d1 != orc, "a copy, not the data itself")
	var d42 := Run.scaled_enemy(orc, 42)
	t.eq(d42.max_hp, roundi(orc.max_hp * RunConfig.ENEMY_HP_MULT * (1.0 + RunConfig.ENEMY_HP_GROWTH_PER_DAY * 41)), "day 42 HP")
	var tyrant: EnemyData = load("res://data/enemies/bosses/horned_tyrant.tres")
	t.eq(Run.sized_boss(tyrant).max_hp, roundi(tyrant.max_hp * RunConfig.BOSS_HP_MULT), "a boss: its HP times the boss multiplier")
	t.check(Run.sized_boss(tyrant) != tyrant, "a copy too")
	t.eq(d42.strength, orc.strength + floori(41.0 / RunConfig.ENEMY_STR_EVERY_DAYS), "day 42 STR")
	t.eq(d42.defense, orc.defense + floori(41.0 / RunConfig.ENEMY_DEF_EVERY_DAYS), "day 42 DEF")
	t.eq(d42.speed, orc.speed + floori(41.0 / RunConfig.ENEMY_SPD_EVERY_DAYS), "day 42 SPD")
	t.check(d42.strength > orc.strength and d42.defense > orc.defense, "day 42 enemies are stronger")
	# An enemy grows little by the day (design/growth.md): what a companion gains is not taken back. By
	# day 42: Health x2.15, +2 STR and MAG, +1 DEF, +1 SPD and DEX, on top of the multiplier every enemy
	# has since companions' Health went up by half (battle step 3).
	t.check(absf(d42.max_hp / (orc.max_hp * RunConfig.ENEMY_HP_MULT) - 2.15) < 0.05, "day 42 HP is about x2.15 of the base (%d)" % d42.max_hp)
	t.eq(d42.strength - orc.strength, 2, "day 42: +2 STR")
	t.eq(d42.defense - orc.defense, 1, "day 42: +1 DEF")
	t.eq(d42.speed - orc.speed, 1, "day 42: +1 SPD")
	t.eq(orc.max_hp, 28, "the data is not changed")
	var run := make_run(5)
	run.day = 15
	force_day(run, RunCalendar.DayType.BATTLE)
	for f in run.fronts:
		for i in f.enemies.size():
			t.check(f.enemies[i].max_hp > f.group.enemies[i].max_hp, "day 15 enemies are tougher")
	run.day = 28
	force_day(run, RunCalendar.DayType.BOSS)
	t.eq(run.fronts.size(), 1, "one boss front")
	var boss := run.fronts[0]
	t.check(boss.is_boss, "boss front")
	var lord: EnemyData = boss.enemies[0]
	var lord_data: EnemyData = boss.group.enemies[0]
	t.eq(lord.max_hp, roundi(lord_data.max_hp * RunConfig.BOSS_HP_MULT), "the boss itself: only its HP, by the boss multiplier")
	t.eq(lord.strength, lord_data.strength, "its STR is as built")
	t.eq(lord.display_name, lord_data.display_name, "and it is the same boss")
	t.check(boss.enemies.size() < 2 or boss.enemies[1].max_hp > boss.group.enemies[1].max_hp, "escorts are scaled")


func test_battle_uses_run_hp_and_weapon() -> void:
	var run := make_run(2)
	var c := run.roster[0]
	c.hp = 7
	var b := run.start_battle(run.fronts[0])
	t.eq(b.roster.size(), run.lineup.size(), "fields the line")
	t.eq(b.roster[0].hp, 7, "starts at the run HP")
	t.eq(b.roster[0].stamina, b.roster[0].max_stamina(), "stamina full")
	t.eq(b.roster[0].weapon(), c.weapon(), "holds the run weapon")
	t.eq(b.roster[0].progress, c.progress, "shares the run progress")
	t.eq(b.enemies.size(), run.fronts[0].enemies.size(), "fights the front's enemies")
	t.check(run.start_battle(run.fronts[0]) == null, "cannot start a second battle the same day")


# ---------------------------------------------------------------- battle outcomes

func test_win_grants_reward() -> void:
	var run := make_run(11)
	var f := run.fronts[run.fronts.size() - 1]
	var gold := run.gold
	var mats := run.materials.duplicate()
	var r := fight(run, true, f)
	t.check(r.won, "won")
	t.eq(r.gold, f.reward_gold, "report gold")
	t.eq(run.gold, gold + f.reward_gold, "gold added")
	for m in RunConfig.MATERIAL_ORDER:
		t.eq(run.material(m), int(mats[m]) + int(f.reward_materials.get(m, 0)), "%s added" % m)
	t.eq(run.city_health, 100, "no city damage on a win")
	t.eq(run.day, 2, "next day")
	t.eq(run.battles_won, 1, "counted")


func test_loss_costs_city_and_run_continues() -> void:
	for danger in [1, 2, 3]:
		var run := make_run(20 + danger)
		run.fronts.clear()
		while run.fronts.is_empty() or run.fronts.filter(func(f: Front) -> bool: return f.danger == danger).is_empty():
			force_day(run, RunCalendar.DayType.BATTLE)
		var f: Front = run.fronts.filter(func(x: Front) -> bool: return x.danger == danger)[0]
		var r := fight(run, false, f)
		t.check(not r.won, "lost")
		t.eq(r.city_damage, [15, 20, 25][danger - 1], "danger %d costs the right city health" % danger)
		t.eq(run.city_health, 100 - r.city_damage, "city damaged")
		t.eq(r.gold, 0, "no reward")
		t.eq(run.outcome, Run.Outcome.ONGOING, "the run goes on")
		t.eq(run.day, 2, "next day")
		t.check(not r.run_over, "report says the run goes on")


func test_lost_boss_ends_run() -> void:
	var run := make_run(4)
	run.day = 14
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.BOSS, "day 14 is the boss")
	t.eq(run.fronts.size(), 1, "one front")
	var r := fight(run, false)
	t.eq(run.outcome, Run.Outcome.DEFEAT, "losing a boss ends the run")
	t.check(r.run_over, "report says so")
	t.eq(run.day, 14, "stays on the boss day")
	t.eq(run.city_health, 100, "no separate city damage")
	t.check(run.start_battle(run.fronts[0] if not run.fronts.is_empty() else null) == null, "nothing more to fight")

	var won := make_run(4)
	won.day = 14
	won._begin_day()
	fight(won, true)
	t.eq(won.outcome, Run.Outcome.ONGOING, "winning the day 14 boss goes on")
	t.eq(won.day, 15, "to day 15")
	won.day = 28
	won._begin_day()
	var r28 := fight(won, false)
	t.eq(won.outcome, Run.Outcome.DEFEAT, "losing the day 28 boss ends the run")
	t.check(r28.run_over, "report says so")


func test_day_42_win() -> void:
	var run := make_run(6)
	run.day = 42
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.BOSS, "day 42 is the boss")
	var r := fight(run, true)
	t.eq(run.outcome, Run.Outcome.VICTORY, "winning day 42 wins the run")
	t.check(r.run_over, "report says so")
	t.eq(run.day, 42, "stays on day 42")
	# Played from day 1, the plainest way, a run that wins every battle ends with that boss.
	var full := make_run(7)
	var days := 0
	while not full.is_over() and days < 100:
		advance(full)
		days += 1
	t.eq(full.outcome, Run.Outcome.VICTORY, "winning every battle wins the run")
	t.eq(full.day, 42, "on day 42")
	t.eq(days, 42, "after 42 days")
	t.eq(full.battles_won, 21, "18 battles and 3 bosses")


func test_city_health_zero_ends_run() -> void:
	var run := make_run(8)
	run.city_health = 10
	var r := fight(run, false)
	t.eq(run.city_health, 0, "city at 0")
	t.eq(r.city_damage, 10, "damage reported up to what was left")
	t.eq(run.outcome, Run.Outcome.DEFEAT, "the city falls")
	t.check(r.run_over, "run over")

	var by_event := make_run(8)
	var ch := EventChoiceData.new()
	ch.label = "Open the gates"
	ch.city_health = -200
	force_event(by_event, EventData.new())
	by_event.event.choices.append(ch)
	t.check(by_event.choose(ch) != "", "chosen")
	t.eq(by_event.outcome, Run.Outcome.DEFEAT, "an event can also bring the city down, at once")
	t.check(not by_event.end_free_day(), "nothing more to do that day")


## However often the party is beaten, nobody leaves the roster.
func test_nobody_is_ever_removed() -> void:
	var run := make_run(9)
	var size := run.roster.size()
	var guard := 0
	while not run.is_over() and guard < 60:
		guard += 1
		match run.day_type():
			RunCalendar.DayType.BATTLE, RunCalendar.DayType.ELITE, RunCalendar.DayType.BOSS:
				if run.lineup.is_empty():
					for c in run.reserve():
						run.field(c)
				if run.lineup.is_empty():
					t.check(run.yield_day() != null, "day %d: given up with nobody to field" % run.day)
				else:
					fight(run, false, null, func(b: Battle) -> void:
						for c in b.roster:
							b._damage_companion(c, 999, false)
							b._damage_companion(c, 999, false))
			_:
				advance(run)
		t.eq(run.roster.size(), size, "day %d: nobody removed" % run.day)
	t.check(run.is_over(), "the run ends (the walls or a boss)")


func test_daily_heal() -> void:
	var run := make_run(10)
	force_day(run, RunCalendar.DayType.FREE)
	var a := run.roster[0]
	var b := run.roster[1]
	a.hp = 3
	b.hp = b.max_hp() - 1
	run.end_free_day()
	t.eq(a.hp, 3 + heal_amount(a), "heals 20% of max HP (rounded up)")
	t.eq(b.hp, b.max_hp(), "never above max")
	t.eq(run.day, 2, "next day")


## Injured in a battle, won or lost: off to the infirmary (out of the line, weapon kept).
func test_injured_go_to_infirmary() -> void:
	for win in [true, false]:
		var run := make_run(12)
		var first := run.lineup[0]
		var weapon := run.inventory.held_by(first)
		var injured_on := run.day
		var r := fight(run, win, null, func(b: Battle) -> void:
			b._damage_companion(b.roster[0], 999, false))
		t.check(r.injured.has(first.display_name()), "reported injured (won: %s)" % win)
		t.check(first.injured and run.infirmary().has(first), "in the infirmary (won: %s)" % win)
		t.eq(first.back_on_day, injured_on + RunConfig.INFIRMARY_DAYS + 1, "back on day D + INFIRMARY_DAYS + 1")
		t.check(not run.lineup.has(first) and not run.reserve().has(first), "neither fielded nor on the bench")
		t.check(run.roster.has(first), "still in the roster")
		t.eq(run.inventory.held_by(first), weapon, "the weapon stays in their hand")


func test_fielded_limit_and_order() -> void:
	var run := make_run(14)
	run.gold = 10000
	force_day(run, RunCalendar.DayType.FREE)
	var hired := 0
	while run.roster.size() < RunConfig.MAX_FIELDED:
		run.actions_left = RunConfig.FREE_DAY_ACTIONS
		run.actions_used.clear()
		run.tavern_offers.clear()
		run._make_tavern_offers()
		if run.tavern_offers.is_empty():
			break
		t.check(run.hire(run.tavern_offers[0]) != null, "hired")
		hired += 1
	t.eq(run.roster.size(), RunConfig.MAX_FIELDED, "a full line of companions")
	t.eq(run.lineup.size(), RunConfig.MAX_FIELDED, "all of them fielded")
	t.check(run.reserve().is_empty(), "no reserve")
	var last := RunConfig.MAX_FIELDED - 1
	var sixth := RunCompanion.create(companion("aina"))
	run.roster.append(sixth)
	t.check(not run.field(sixth), "one more cannot be fielded")
	t.eq(run.reserve(), [sixth] as Array[RunCompanion], "the extra one waits in reserve")
	var front_most := run.lineup[last]
	t.check(run.bench(front_most), "bench one")
	t.eq(run.lineup.size(), last, "one fewer fielded")
	t.check(run.field(sixth, 0), "now the extra one fits, at the back")
	t.eq(run.lineup[0], sixth, "leftmost")
	t.check(run.move_in_line(sixth, last), "move to the front")
	t.eq(run.lineup[last], sixth, "rightmost")
	t.check(not run.field(front_most), "full again")
	# The battle line follows the order.
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	var b := run.start_battle(run.fronts[0])
	for i in run.lineup.size():
		t.eq(b.roster[i].data, run.lineup[i].data, "battle line order slot %d" % i)
	# Nobody fielded: no battle.
	var empty := make_run(14)
	for c in empty.lineup.duplicate():
		empty.bench(c)
	t.check(empty.battle_block_reason(empty.fronts[0]) != "", "needs someone fielded")
	t.check(empty.start_battle(empty.fronts[0]) == null, "refused")


func test_party_locked_after_commit() -> void:
	var run := make_run(15)
	var c := run.lineup[0]
	run.start_battle(run.fronts[0])
	t.check(not run.can_change_party(), "locked during the battle")
	t.check(not run.bench(c), "cannot bench")
	t.check(not run.move_in_line(c, 1), "cannot reorder")


func test_free_day_action_limits() -> void:
	var run := make_run(16)
	force_day(run, RunCalendar.DayType.FREE)
	run.gold = 1000
	run.materials = {RunConfig.IRON_ORE: 10, RunConfig.TIMBER: 10}
	run.city_health = 50
	run.roster[0].hp = 1
	t.eq(RunConfig.FREE_DAY_ACTIONS, 1, "a free day has one action")
	t.eq(run.actions_left, 1, "one action")
	t.check(run.repair(), "repair")
	t.eq(run.actions_left, 0, "none left")
	t.check(not run.repair(), "repair only once a day")
	t.check(run.free_action_block_reason(Run.FreeAction.REPAIR).contains("Already"), "says why")
	t.check(not run.rest(), "no time left to rest")
	t.check(run.free_action_block_reason(Run.FreeAction.REST).contains("No actions"), "says why")
	# Buying and hiring cost gold, never the action: still open after it is spent.
	var item := run.shop_stock()[0]
	t.eq(run.buy_block_reason(item), "", "the smithy is open after the action")
	t.check(run.buy(item) != null, "bought after the action")
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	t.check(run.hire(run.tavern_offers[0]) != null, "hired after the action")
	t.eq(run.actions_left, 0, "neither gives the action back or takes another")
	t.eq(run.actions_used, [Run.FreeAction.REPAIR] as Array[int], "only the repair is recorded as the action")
	t.check(run.end_free_day(), "end the day")
	t.eq(run.day, 2, "next day")
	# Shop and tavern first: the action is still there for rest, repair or train.
	force_day(run, RunCalendar.DayType.FREE)
	run.gold = 1000
	run.roster[0].hp = 1
	run.city_health = 50
	t.check(run.buy(run.shop_stock()[0]) != null, "buy")
	t.check(run.buy(run.shop_stock()[0]) != null, "buy again")
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	t.check(run.hire(run.tavern_offers[0]) != null, "hire")
	t.eq(run.actions_left, 1, "the day's action is untouched")
	t.eq(run.errand_block_reason(), "", "errands are open")
	t.check(run.rest(), "and the day's action: rest")
	t.eq(run.actions_left, 0, "rest uses it")
	t.check(not run.repair(), "and nothing else after it")
	# Unused actions are lost.
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.actions_left, 1, "a fresh free day has one again")
	run.end_free_day()
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.actions_left, 1, "never more than one")
	t.eq(run.actions_used.size(), 0, "nothing used yet")
	# Not on other days, but for the smithy and the tavern (until the march).
	force_day(run, RunCalendar.DayType.BATTLE)
	t.check(not run.rest(), "no rest on a battle day")
	t.eq(run.errand_block_reason(), "Only on free days.", "no free-day errands on a battle day")
	run.gold = 1000
	t.check(run.buy(run.shop_stock()[0]) != null, "but buying on a battle day")
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	t.check(run.hire(run.tavern_offers[0]) != null, "and hiring")
	t.check(not run.end_free_day(), "no ending a battle day without the battle")


## An event day is a free day that begins with the event: until it is answered nothing else can be
## done in the city and the day cannot end; afterwards the free day goes on as usual.
func test_event_opens_free_day() -> void:
	var run := make_run(40)
	var first: int = run.event_days[0]
	while run.day < first:
		advance(run)
	t.eq(run.day, first, "reached the first event day")
	t.eq(run.day_type(), RunCalendar.DayType.FREE, "an event day is a free day")
	t.check(run.has_event_day(), "today begins with an event")
	t.check(run.event_pending() and run.event != null, "the event waits")
	t.eq(run.actions_left, 1, "the day's action is there")
	run.gold = 1000
	run.city_health = 50
	run.materials = {RunConfig.IRON_ORE: 5, RunConfig.TIMBER: 5}
	run.roster[0].hp = 1
	for a in [Run.FreeAction.REST, Run.FreeAction.REPAIR, Run.FreeAction.SHOP, Run.FreeAction.TAVERN, Run.FreeAction.CURE]:
		t.eq(run.free_action_block_reason(a), Run.EVENT_FIRST, "%s waits for the event" % Run.FREE_ACTION_NAMES[a])
		t.eq(run.visit_block_reason(a), Run.EVENT_FIRST, "%s cannot be visited yet" % Run.FREE_ACTION_NAMES[a])
	t.eq(run.errand_block_reason(), Run.EVENT_FIRST, "errands wait for the event too")
	t.check(not run.rest() and not run.repair(), "nothing done yet")
	t.check(run.buy(run.shop_stock()[0]) == null, "nothing bought yet")
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	t.check(run.hire(run.tavern_offers[0]) == null, "nobody hired yet")
	t.eq(run.hire_block_reason(run.tavern_offers[0]), Run.EVENT_FIRST, "says why")
	t.check(not run.end_free_day(), "the day cannot end before the event is answered")
	t.eq(run.day, first, "still the same day")
	t.check(run.can_change_party(), "the party can still be changed")
	var pick: EventChoiceData = null
	for ch in run.event.choices:
		if run.choice_block_reason(ch) == "":
			pick = ch
			break
	t.check(run.choose(pick) != "", "answered")
	t.eq(run.day, first, "the day goes on")
	t.check(not run.event_pending(), "no event waiting")
	t.eq(run.choose(pick), "", "an event is answered once")
	t.check(run.rest(), "then the free day's action")
	t.eq(run.actions_left, 0, "spent")
	t.check(run.end_free_day(), "and the day ends")
	# A free day without an event has none.
	while run.day_type() != RunCalendar.DayType.FREE or run.has_event_day():
		advance(run)
	t.check(run.event == null and not run.event_pending(), "a plain free day has no event")
	t.eq(run.free_action_block_reason(Run.FreeAction.SHOP), "", "and the city is open at once")
	# Battle and boss days never carry an event.
	for d in run.event_days:
		t.eq(run.day_type(d), RunCalendar.DayType.FREE, "event day %d is a free day" % d)


## The tavern and the smithy restock on the first day of each week and keep the same offers and stock
## all week; what was hired or bought is gone until the next week.
func test_weekly_refresh() -> void:
	var changed_offers := 0
	for s in 20:
		var run := make_run(500 + s)
		run.gold = 100000
		var offers := run.tavern_offers.duplicate()
		var stock := run.shop_stock().duplicate()
		t.check(not stock.is_empty(), "seed %d: the smithy has stock in week 1" % s)
		var bought: ShopItemData = null
		var hired: CompanionData = null
		while run.day < 8:
			t.eq(run.tavern_offers, offers, "seed %d day %d: the same offers all week" % [s, run.day])
			t.eq(run.shop_stock(), stock, "seed %d day %d: the same stock all week" % [s, run.day])
			if run.day_type() == RunCalendar.DayType.FREE and not run.has_event_day():
				if bought == null:
					bought = stock[0]
					t.check(run.buy(bought) != null, "seed %d: bought on day %d" % [s, run.day])
					stock.erase(bought)
					t.check(not run.shop_stock().has(bought), "seed %d: the bought item leaves the stock" % s)
				elif hired == null and not offers.is_empty():
					hired = offers[0]
					t.check(run.hire(hired) != null, "seed %d: hired on day %d" % [s, run.day])
					offers.erase(hired)
					t.check(not run.tavern_offers.has(hired), "seed %d: the hire leaves the tavern" % s)
			advance(run)
		t.check(bought != null, "seed %d: something was bought in week 1" % s)
		# Day 8: a new week, a new roll.
		t.eq(run.day, 8, "seed %d: week 2" % s)
		# A new stock is rolled: none of last week's ladder items is left over.
		var ladder := run.shop_stock().filter(func(i: ShopItemData) -> bool: return not i.weapon.rare)
		t.eq(ladder.size(), RunConfig.SHOP_WEAPONS_PER_WEEK, "seed %d: a new week's ladder weapons" % s)
		for item: ShopItemData in ladder:
			t.check(not stock.has(item) and item != bought and item.min_day == 8, "seed %d: rolled for week 2" % s)
		for d in run.tavern_offers:
			t.check(not run._in_roster(d), "seed %d: only companions who can join" % s)
		if hired != null:
			t.check(not run.tavern_offers.has(hired), "seed %d: someone hired is never offered again" % s)
		var week2 := run.tavern_offers.duplicate()
		var full := offers.duplicate()
		if hired != null:
			full.append(hired)
		if week2 != full:
			changed_offers += 1
	t.check(changed_offers >= 10, "the tavern's offers change between weeks (%d of 20)" % changed_offers)


func test_rest() -> void:
	var run := make_run(17)
	force_day(run, RunCalendar.DayType.FREE)
	t.check(run.free_action_block_reason(Run.FreeAction.REST) != "", "nothing to rest from")
	for c in run.roster:
		c.hp = 2
	t.check(run.rest(), "rest")
	for c in run.roster:
		t.eq(c.hp, c.max_hp(), "everyone to full")


func test_shop_and_equip_requirement() -> void:
	var run := make_run(18)
	force_day(run, RunCalendar.DayType.FREE)
	# A fighter: the mages start below D in their weapon.
	var c := run.roster[0] if not run.roster[0].data.is_mage() else run.roster[1]
	var kind := c.weapon().weapon_type
	t.eq(c.weapon().tier, WeaponData.Tier.WOODEN, "starts with a wooden weapon")
	# An iron weapon of their type, put into this week's stock for the test (week 1 never rolls iron).
	var steel := ShopItemData.new()
	steel.weapon = content().ladder_weapon(WeaponData.Tier.IRON, kind)
	steel.price = RunConfig.WEAPON_PRICE_BY_TIER[WeaponData.Tier.IRON]
	run.shop_week.append(steel)
	t.check(steel.weapon != null and steel.weapon.required_grade == Proficiency.Grade.C, "iron needs C")
	run.gold = steel.price - 1
	t.check(run.buy(steel) == null, "cannot afford")
	t.check(run.buy_block_reason(steel).contains("gold"), "says gold")
	t.eq(run.actions_left, 1, "no action spent")
	run.gold = 1000
	var owned := run.buy(steel)
	t.check(owned != null, "bought")
	t.eq(run.gold, 1000 - steel.price, "paid")
	t.eq(run.actions_left, 1, "the shop never uses the day's action")
	t.check(owned.holder == null, "goes to the armory")
	t.check(not run.shop_stock().has(steel), "one of each: the iron weapon is gone for the week")
	t.check(run.buy(steel) == null and run.buy_block_reason(steel).contains("this week"), "and cannot be bought again")
	var other := run.shop_stock()[0]
	t.check(run.buy(other) != null, "a second purchase the same visit")
	t.eq(run.actions_left, 1, "still no action used")
	# Equip requirement: companions start at D, iron needs C.
	t.eq(c.progress.grade(kind), Proficiency.Grade.D, "starts at D")
	var old := run.inventory.held_by(c)
	t.check(not run.equip_weapon(c, owned), "C weapon refused at D")
	t.check(run.equip_block_reason(c, owned).contains("%s C" % WeaponData.type_name(kind).to_lower()), "says which grade: %s" % run.equip_block_reason(c, owned))
	c.progress.points[kind] = Proficiency.points_for(Proficiency.Grade.C)
	t.check(run.equip_weapon(c, owned), "allowed at C")
	t.eq(c.weapon(), steel.weapon, "now holds it")
	t.check(old.holder == null, "the old weapon goes back to the armory")


func test_weapon_held_by_one() -> void:
	var run := make_run(19)
	var a := run.roster[0]
	var b := run.roster[1]
	var a_weapon := run.inventory.held_by(a)
	# Same type for both so only the holder rule can refuse it.
	b.progress.points[a_weapon.data.weapon_type] = 999
	t.check(not run.equip_weapon(b, a_weapon), "cannot take a weapon another holds")
	t.check(run.equip_block_reason(b, a_weapon).contains("holding"), "says who holds it")
	t.eq(a_weapon.holder, a, "still with the holder")
	var spare := run.inventory.add(a_weapon.data)
	t.check(run.equip_weapon(b, spare), "a second copy of the same weapon is fine")
	var holders := {}
	for w in run.inventory.weapons:
		if w.holder != null:
			t.check(not holders.has(w.holder), "one weapon per companion")
			holders[w.holder] = true
	t.eq(holders.size(), run.roster.size(), "every companion holds one")


func test_tavern_hiring() -> void:
	var sizes := {}
	for s in 40:
		var run := make_run(100 + s)
		force_day(run, RunCalendar.DayType.FREE)
		var n := run.tavern_offers.size()
		sizes[n] = true
		t.check(n >= 1 and n <= 2, "1 or 2 offers")
		for d in run.tavern_offers:
			t.check(not run._in_roster(d), "only companions not in the roster")
	t.check(sizes.has(1) and sizes.has(2), "both 1 and 2 offers happen")
	var run := make_run(77)
	force_day(run, RunCalendar.DayType.FREE)
	run.gold = RunConfig.HIRE_COST - 1
	var pick := run.tavern_offers[0]
	t.check(run.hire(pick) == null, "cannot afford")
	run.gold = RunConfig.HIRE_COST
	var c := run.hire(pick)
	t.check(c != null, "hired")
	t.eq(run.gold, 0, "paid")
	t.eq(run.roster.size(), 3, "joins the roster")
	t.check(run.lineup.has(c), "fielded, the line has room")
	t.eq(c.hp, c.max_hp(), "full HP")
	t.eq(run.inventory.held_by(c).data, pick.weapon, "brings their weapon")
	t.check(not run.tavern_offers.has(pick), "no longer offered")
	t.eq(run.actions_left, 1, "the tavern never uses the day's action")


func test_repair() -> void:
	var run := make_run(21)
	force_day(run, RunCalendar.DayType.FREE)
	run.materials = {RunConfig.IRON_ORE: 1, RunConfig.TIMBER: 3}
	t.eq(RunConfig.REPAIR_COST, {RunConfig.TIMBER: 3}, "3 timber, no ore")
	t.check(not run.repair(), "nothing to repair at full health")
	run.city_health = 90
	t.check(run.repair(), "repair")
	t.eq(run.city_health, 100, "capped at 100")
	t.eq(run.material(RunConfig.TIMBER), 0, "timber spent")
	t.eq(run.material(RunConfig.IRON_ORE), 1, "no iron")
	t.eq(run.actions_left, 0, "the masons use the day's action")
	force_day(run, RunCalendar.DayType.FREE)
	run.city_health = 50
	t.check(not run.repair(), "no materials, no repair")
	t.check(run.free_action_block_reason(Run.FreeAction.REPAIR).contains("Needs"), "says what it needs")
	run.materials = {RunConfig.IRON_ORE: 5, RunConfig.TIMBER: 5}
	t.check(run.repair(), "repair")
	t.eq(run.city_health, 50 + RunConfig.REPAIR_AMOUNT, "+%d" % RunConfig.REPAIR_AMOUNT)


func test_event_choices() -> void:
	t.check(content().events.size() >= 5, "at least 5 events")
	for ev in content().events:
		t.check(ev.choices.size() >= 2 and ev.choices.size() <= 3, "%s: 2 or 3 choices" % ev.title)
		var free_choice := false
		for ch in ev.choices:
			var costs := ch.gold < 0
			for m: String in ch.materials:
				costs = costs or int(ch.materials[m]) < 0
			free_choice = free_choice or not costs
		t.check(free_choice, "%s: one choice is always affordable" % ev.title)
		for ch in ev.choices:
			var run := make_run(31)
			fight(run, true)
			force_event(run, ev)
			run.gold = 500
			run.materials = {RunConfig.IRON_ORE: 5, RunConfig.TIMBER: 5}
			run.city_health = 80
			for c in run.roster:
				c.hp = c.max_hp() - 10
			var targets := run.hp_targets(ch)
			var hp_before := {}
			for c in run.roster:
				hp_before[c] = c.hp
			var weapons := run.inventory.weapons.size()
			var gives := run.choice_weapon(ch)
			var text := run.choose(ch)
			t.check(text != "", "%s / %s: chosen" % [ev.title, ch.label])
			t.eq(run.gold, 500 + ch.gold, "%s / %s: gold" % [ev.title, ch.label])
			for m in RunConfig.MATERIAL_ORDER:
				t.eq(run.material(m), 5 + int(ch.materials.get(m, 0)), "%s / %s: %s" % [ev.title, ch.label, m])
			t.eq(run.city_health, clampi(80 + ch.city_health, 0, 100), "%s / %s: city" % [ev.title, ch.label])
			for c in run.roster:
				var expected: int = hp_before[c]
				if targets.has(c):
					expected = clampi(expected + ch.companion_hp, 1, c.max_hp())
				t.eq(c.hp, expected, "%s / %s: %s HP" % [ev.title, ch.label, c.display_name()])
			t.eq(gives != null, ch.weapon != null or ch.random_weapon, "%s / %s: says what weapon it gives" % [ev.title, ch.label])
			t.eq(run.inventory.weapons.size(), weapons + (1 if gives != null else 0), "%s / %s: weapon" % [ev.title, ch.label])
			if gives != null:
				t.eq(run.inventory.weapons[-1].data, gives, "the weapon is in the armory")
				t.check(not text.contains("{weapon}") and (text.contains(gives.display_name) or not ch.result_text.contains("{weapon}")), "the result names it")
			t.eq(run.day, 2, "the free day goes on after the event")
			t.check(run.event == null and not run.event_pending(), "the event is answered")
			t.eq(run.actions_left, 1, "the day's action is still there")
			# Unaffordable choices are refused.
			if ch.gold < 0:
				var poor := make_run(31)
				force_event(poor, ev)
				poor.gold = -ch.gold - 1
				t.check(poor.choose(ch) == "", "%s / %s: refused without the gold" % [ev.title, ch.label])
				t.check(poor.event_pending(), "and the event still waits")
	# HP losses never take a companion below 1.
	var run := make_run(32)
	var hurt := EventChoiceData.new()
	hurt.companion_hp = -500
	hurt.hp_target = EventChoiceData.HpTarget.ALL
	force_event(run, EventData.new())
	run.event.choices.append(hurt)
	run.choose(hurt)
	for c in run.roster:
		t.eq(c.hp, 1, "HP loss stops at 1")
	# Events do not repeat while unseen ones remain; after that they may.
	var seen := {}
	var r2 := make_run(33)
	for i in content().events.size():
		force_event(r2)
		t.check(r2.event != null, "an event is drawn")
		t.check(not seen.has(r2.event), "no repeat while unseen events remain")
		seen[r2.event] = true
	force_event(r2)
	t.check(r2.event != null, "with every event seen, one is drawn again")
	# In a run, the event days each draw a different event (a run has fewer event days than events).
	t.check(content().events.size() >= RunConfig.EVENTS_PER_WEEK * 6, "enough events for a run without repeats")
	for s in 20:
		var r3 := make_run(300 + s)
		var drawn := {}
		for d in r3.event_days:
			r3.day = d
			r3._begin_day()
			t.check(r3.event != null and not drawn.has(r3.event), "seed %d: a new event on day %d" % [300 + s, d])
			drawn[r3.event] = true


func test_run_content() -> void:
	var rc := content()
	t.eq(rc.companions.size(), 14, "ten fighters and four mages")
	t.eq(rc.bosses.size(), 9, "nine bosses, three for each boss day")
	for d in range(1, RunConfig.DAYS + 1):
		for danger in [1, 2, 3]:
			t.check(not rc.groups_for(danger, d).is_empty(), "a danger %d group exists on day %d" % [danger, d])
	t.check(rc.sites.size() >= 3, "enough sites for three fronts")
	var by_name := {}
	for g in rc.groups:
		for e in g.enemies:
			by_name[e.display_name] = e
	for n in ["Goblin Wizard", "Stalker", "Cursed Warrior", "Armored Beast", "Minotaur", "Orc", "Goblin Thief"]:
		t.check(by_name.has(n), "%s fights on some front" % n)
	for e: EnemyData in by_name.values():
		t.check(e.actions.size() >= 3, "%s has an action list" % e.display_name)
		t.check(e.portrait != null, "%s has art" % e.display_name)
	for b in rc.bosses:
		t.check(b.enemies[0].portrait != null and b.enemies[0].stage_scale > 1.3, "%s is a big boss" % b.display_name)
	# Every weapon type has six tiers, each needing a higher grade and (from bronze on) giving more Mt.
	for t_kind: int in WeaponData.WeaponType.values():
		var last_grade := -1
		var last_might := -1
		for tier: int in WeaponData.Tier.values():
			var w := rc.ladder_weapon(tier, t_kind)
			t.check(w != null, "%s: a %s one" % [WeaponData.type_name(t_kind), WeaponData.tier_name(tier)])
			if w == null:
				continue
			t.check(w.required_grade > last_grade, "%s %s: a higher grade" % [WeaponData.type_name(t_kind), WeaponData.tier_name(tier)])
			t.check(w.might > last_might or (tier == WeaponData.Tier.BRONZE and w.might >= last_might),
				"%s %s: more might" % [WeaponData.type_name(t_kind), WeaponData.tier_name(tier)])
			last_grade = w.required_grade
			last_might = w.might
	# The magic weapons are among the rare weapons.
	for w in rc.rare_weapons:
		t.check(w.rare, "%s is marked rare" % w.display_name)


# ---------------------------------------------------------------- levels

func growth_companion(rates: Dictionary) -> CompanionData:
	var c := companion("aina").duplicate() as CompanionData
	c.growths = rates
	return c


func test_level_thresholds() -> void:
	t.eq(Levels.xp_to_next(1), RunConfig.XP_PER_LEVEL_BASE, "level 1 -> 2")
	t.eq(Levels.xp_to_next(5), RunConfig.XP_PER_LEVEL_BASE + 4 * RunConfig.XP_PER_LEVEL_STEP, "level 5 -> 6")
	t.eq(Levels.xp_to_next(RunConfig.MAX_LEVEL), 0, "nothing past the top level")
	var p := CompanionProgress.create(companion("erik"))
	var rng := _seeded(1)
	t.eq(p.level, 1, "starts at level 1")
	t.eq(p.xp, 0, "with no XP")
	t.check(Levels.add_xp(p, Levels.xp_to_next(1) - 1, rng).is_empty(), "one short: no level")
	t.eq(p.level, 1, "still 1")
	var ups := Levels.add_xp(p, 1, rng)
	t.eq(ups.size(), 1, "exactly the threshold: one level")
	t.eq(p.level, 2, "level 2")
	t.eq(p.xp, 0, "XP starts over")
	ups = Levels.add_xp(p, Levels.xp_to_next(2) + Levels.xp_to_next(3) + 7, rng)
	t.eq(ups.size(), 2, "a big gain can give two levels")
	t.eq(p.level, 4, "level 4")
	t.eq(p.xp, 7, "the rest carries over")
	t.eq(ups[0].level, 3, "levels reported in order")
	Levels.add_xp(p, 100000, rng)
	t.eq(p.level, RunConfig.MAX_LEVEL, "stops at the top level")
	t.eq(p.xp, 0, "no XP kept at the top")
	t.eq(Levels.total_xp_for(3), Levels.xp_to_next(1) + Levels.xp_to_next(2), "total XP to a level")


func test_growth_rates() -> void:
	# Raw rolls match each rate.
	for n in ["elena", "aina", "erik", "ingrid", "yuzu"]:
		var d := companion(n)
		var rng := _seeded(n.hash())
		var counts := {}
		var rolls := 4000
		for i in rolls:
			for key: String in Levels.roll_raw(d, rng):
				counts[key] = counts.get(key, 0) + 1
		var sum := 0.0
		for key in Levels.GROWTH_STATS:
			var rate := Levels.growth_rate(d, key)
			sum += rate
			var seen: float = 100.0 * int(counts.get(key, 0)) / rolls
			t.check(absf(seen - rate) < 3.0, "%s %s: rolled %.1f%% against a %d%% rate" % [n, key, seen, rate])
		var avg := sum / Levels.GROWTH_STATS.size()
		t.check(avg >= 27.0 and avg <= 36.0, "%s averages about 31%% (%.1f)" % [n, avg])
		t.eq(d.growths.size(), Levels.GROWTH_STATS.size(), "%s has a rate for every stat but BLD" % n)
	# Character: the axe user is high in HP and STR, the archer in DEX.
	var elena := companion("elena")
	var erik := companion("erik")
	t.check(Levels.growth_rate(elena, Stat.HP) >= 70 and Levels.growth_rate(elena, Stat.STR) >= 45, "Elena: HP and STR")
	t.check(Levels.growth_rate(erik, Stat.DEX) >= 50, "Erik: DEX")
	# The same seed gives the same level-ups.
	var a := CompanionProgress.create(elena)
	var b := CompanionProgress.create(elena)
	Levels.add_xp(a, 2000, _seeded(9))
	Levels.add_xp(b, 2000, _seeded(9))
	t.eq(a.stat_gains, b.stat_gains, "seeded level-ups repeat")


func test_bld_never_rises() -> void:
	var d := growth_companion({"BLD": 100, "HP": 100, "STR": 100})
	t.eq(Levels.growth_rate(d, Stat.BLD), 0, "BLD has no growth rate")
	var p := CompanionProgress.create(d)
	var rng := _seeded(3)
	for i in 200:
		Levels.level_up(p, rng)
	t.eq(p.stat_gain(Stat.BLD), 0, "BLD never rises")
	t.eq(p.stats()[Stat.BLD], d.build, "BLD stays at its base")


func test_minimum_stat_gains() -> void:
	var none := growth_companion({})
	var rng := _seeded(4)
	var picked := {}
	for i in 500:
		var g := Levels.roll_gains(none, rng)
		t.eq(g.size(), RunConfig.MIN_STAT_GAINS, "with no growth rates, exactly the minimum rises")
		for key: String in g:
			t.check(key != Stat.BLD, "never BLD")
			picked[key] = true
	t.eq(picked.size(), Levels.GROWTH_STATS.size(), "any stat can be picked when rates are all 0")
	var weighted := growth_companion({"STR": 50, "DEF": 1})
	var str_rose := 0
	for i in 2000:
		var g := Levels.roll_gains(weighted, rng)
		t.check(g.size() >= RunConfig.MIN_STAT_GAINS, "at least the minimum")
		if g.has(Stat.STR):
			str_rose += 1
	t.check(str_rose > 1900, "extra gains are weighted by rate (STR rose %d / 2000)" % str_rose)
	var all := growth_companion({"HP": 100, "STA": 100, "STR": 100, "MAG": 100, "CRT": 100, "DEX": 100, "SPD": 100,
		"DEF": 100, "RES": 100, "LCK": 100})
	t.eq(Levels.roll_gains(all, rng).size(), 10, "all at 100%: every stat but BLD rises")
	for n in ["elena", "aina", "erik", "ingrid", "yuzu"]:
		for i in 300:
			t.check(Levels.roll_gains(companion(n), rng).size() >= RunConfig.MIN_STAT_GAINS, "%s: minimum gains" % n)


func test_level_gains_reach_battle() -> void:
	var p := CompanionProgress.create(companion("aina"))
	p.stat_gains = {Stat.STR: 3, Stat.HP: 4, Stat.STA: 2}
	var unit := CompanionUnit.new(p.data, p)
	t.eq(unit.stat(Stat.STR), p.data.strength + 3, "STR gains count in battle")
	t.eq(unit.max_hp(), p.data.max_hp + 4, "max HP gains count in battle")
	t.eq(unit.max_stamina(), p.data.max_sta + 2, "STA gains count in battle")
	var run := make_run(40)
	var c := run.roster[0]
	c.progress.stat_gains = {Stat.HP: 5}
	c.hp = c.max_hp()
	var b := run.start_battle(run.fronts[0])
	t.eq(b.roster[0].max_hp(), c.data.max_hp + 5, "a run battle uses the gains")
	t.eq(b.roster[0].hp, c.max_hp(), "at the run HP")


func total_xp(c: RunCompanion) -> int:
	return Levels.total_xp_for(c.level()) + c.progress.xp


## The XP split: 25% evenly, 75% by contribution points; all even when nobody scored; rounded down with
## the leftover going to the highest scorers first, so the shares always add up to the pool.
func test_split_xp() -> void:
	t.eq(RunConfig.XP_EVEN_SHARE_PERCENT, 25, "a quarter is shared evenly")
	t.eq(Levels.split_xp(100, [0, 0, 0, 0] as Array[int]), [25, 25, 25, 25] as Array[int], "nobody scored: all even")
	t.eq(Levels.split_xp(10, [0, 0, 0] as Array[int]), [4, 3, 3] as Array[int], "nobody scored: the leftover goes in line order")
	# 100: 25 evenly (6.25 each) and 75 by points; 10 of 10 points to the first.
	t.eq(Levels.split_xp(100, [10, 0, 0, 0] as Array[int]), [82, 6, 6, 6] as Array[int], "81.25 + leftover, 6.25 for the idle")
	# 200 among 2: 25 each evenly, then 150 split 3:1.
	t.eq(Levels.split_xp(200, [30, 10] as Array[int]), [138, 62] as Array[int], "137.5 and 62.5: the leftover goes to the higher scorer")
	t.eq(Levels.split_xp(90, [6, 6, 6] as Array[int]), [30, 30, 30] as Array[int], "equal points: equal shares")
	t.eq(Levels.split_xp(101, [5, 5, 5] as Array[int]), [34, 34, 33] as Array[int], "equal points: the leftover in line order")
	t.eq(Levels.split_xp(50, [0, 3, 9] as Array[int]), [4, 13, 33] as Array[int], "4.17, 13.54, 32.29: the highest scorer gets the leftover")
	t.eq(Levels.split_xp(77, [] as Array[int]), [] as Array[int], "nobody: nothing")
	t.eq(Levels.split_xp(77, [4] as Array[int]), [77] as Array[int], "one companion: all of it")
	# Random cases: never created or lost, never below the even floor, more points never less XP.
	var rng := _seeded(77)
	for i in 500:
		var n := rng.randi_range(1, 4)
		var pool := rng.randi_range(0, 1000)
		var pts: Array[int] = []
		for k in n:
			pts.append(rng.randi_range(0, 40) if rng.randf() < 0.8 else 0)
		var shares := Levels.split_xp(pool, pts)
		var total := 0
		for s in shares:
			total += s
		t.eq(total, pool, "case %d: the shares add up to the pool" % i)
		for a in n:
			t.check(shares[a] >= floori(pool * RunConfig.XP_EVEN_SHARE_PERCENT / 100.0 / n), "case %d: at least the even part" % i)
			for b in n:
				if pts[a] > pts[b]:
					t.check(shares[a] >= shares[b], "case %d: more points, no less XP" % i)


func test_xp_split_among_fielded() -> void:
	var run := make_run(41)
	run.gold = 10000
	force_day(run, RunCalendar.DayType.FREE)
	while run.roster.size() < 5:
		run.actions_left = 2
		run.actions_used.clear()
		run.tavern_offers.clear()
		run._make_tavern_offers()
		run.hire(run.tavern_offers[0])
	t.eq(run.lineup.size(), RunConfig.MAX_FIELDED, "four fielded")
	for c in run.roster:
		c.traits = []   # the split itself; traits that change XP are tested in trait_tests.gd
	var benched: RunCompanion = run.roster.filter(func(c: RunCompanion) -> bool: return not run.lineup.has(c))[0]
	var gone := run.lineup[0]
	var injured := run.lineup[1]
	var fine := run.lineup[2]
	var idle := run.lineup[3]
	run.day = 3
	force_day(run, RunCalendar.DayType.BATTLE)
	var f := run.fronts[0]
	var before := {}
	for c in run.roster:
		before[c] = total_xp(c)
	var r := fight(run, true, f, func(b: Battle) -> void:
		b.points[b.roster[0]] = 10   # injured twice over: nothing worse, and a share all the same
		b.points[b.roster[1]] = 30
		b.points[b.roster[2]] = 10
		b._damage_companion(b.roster[0], 999, false)
		b._damage_companion(b.roster[0], 1, false)
		b._damage_companion(b.roster[1], 999, false))
	t.check(r.injured.has(gone.display_name()) and r.injured.has(injured.display_name()), "two injured")
	var all4 := Levels.split_xp(f.xp_pool, [10, 30, 10, 0] as Array[int])
	t.eq(r.xp_gained.keys(), [gone.display_name(), injured.display_name(), fine.display_name(), idle.display_name()], "a share for everyone fielded, in line order")
	t.eq(r.xp_of(gone.display_name()), all4[0], "the twice-hit one gets their share")
	var expected: Array[int] = all4.slice(1)
	t.eq(r.xp_total(), f.xp_pool, "the whole pool is handed out")
	var pool := float(f.xp_pool)
	t.check(absf(r.xp_of(injured.display_name()) - (pool * 0.25 / 4 + pool * 0.75 * 30 / 50)) < 1.01, "injured: a quarter of the quarter, 30/50 of the rest")
	t.check(absf(r.xp_of(fine.display_name()) - (pool * 0.25 / 4 + pool * 0.75 * 10 / 50)) < 1.01, "fine: a quarter of the quarter, 10/50 of the rest")
	t.check(absf(r.xp_of(idle.display_name()) - pool * 0.25 / 4) < 1.01, "idle: only a quarter of the quarter")
	for i in 3:
		var c: RunCompanion = [injured, fine, idle][i]
		t.eq(r.xp_of(c.display_name()), expected[i], "%s: the split's share" % c.display_name())
		t.eq(total_xp(c) - int(before[c]), expected[i], "%s gets that XP (injured or not)" % c.display_name())
	t.eq(r.points, {gone.display_name(): 10, injured.display_name(): 30, fine.display_name(): 10, idle.display_name(): 0}, "the report gives each one's points")
	t.eq(r.points_of(injured.display_name()), 30, "points by name")
	t.eq(total_xp(benched), int(before[benched]), "reserve gets nothing")
	t.check(not r.xp_gained.has(benched.display_name()), "no share for the reserve")
	t.check(f.xp_pool > 0, "fronts carry an XP pool")
	t.check(RunConfig.XP_POOL_BY_DANGER[0] < RunConfig.XP_POOL_BY_DANGER[1] and RunConfig.XP_POOL_BY_DANGER[1] < RunConfig.XP_POOL_BY_DANGER[2],
		"higher danger, more XP")
	# Nobody scored: an even split of the whole pool.
	var run2 := make_run(46)
	for c in run2.roster:
		c.traits = []
	var f2 := run2.fronts[0]
	var r2 := fight(run2, true, f2)
	t.eq(r2.xp_gained.values(), Array(Levels.split_xp(f2.xp_pool, [0, 0] as Array[int])), "nobody scored: even")
	t.eq(r2.xp_total(), f2.xp_pool, "and nothing lost to rounding")
	run.day = 25
	force_day(run, RunCalendar.DayType.BATTLE)
	for fr in run.fronts:
		t.check(fr.xp_pool > RunConfig.XP_POOL_BY_DANGER[fr.danger - 1], "the pool grows with the day")


## Contribution points come from a real battle into the report and the split.
func test_xp_follows_battle_points() -> void:
	var run := make_run(47)
	var f := run.fronts[0]
	var b := run.start_battle(f)
	var first := b.roster[0]
	var target := b.enemies[0]
	first.recovery = 0
	t.check(b.attack(first, target), "an attack")
	var pts := b.points_of(first)
	t.check(pts >= BattleConfig.POINTS_ATTACK_MISS, "points earned (%d)" % pts)
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	var r := run.finish_battle(b)
	var names_in := run.lineup.map(func(c: RunCompanion) -> String: return c.display_name())
	t.eq(r.points_of(names_in[0]), pts, "the report carries the battle's points")
	var all_pts: Array[int] = []
	for n: String in names_in:
		all_pts.append(r.points_of(n))
	var shares := Levels.split_xp(f.xp_pool, all_pts)
	for i in names_in.size():
		t.eq(r.xp_of(names_in[i]), shares[i], "%s: XP by points" % names_in[i])


func test_no_xp_on_loss() -> void:
	var run := make_run(42)
	var c := run.lineup[0]
	var kind := c.weapon().weapon_type
	var points := c.progress.points_in(kind)
	var r := fight(run, false, null, func(b: Battle) -> void:
		b._gain_proficiency(b.roster[0], 3))
	t.check(r.xp_gained.is_empty() and r.xp_total() == 0, "no XP on a loss")
	t.eq(r.points.size(), r.injured.size(), "points are still reported (everyone fielded, now in the infirmary)")
	t.check(r.level_ups.is_empty(), "no level-ups")
	for x in run.roster:
		t.eq(x.progress.xp, 0, "no XP for %s" % x.display_name())
		t.eq(x.level(), 1, "still level 1")
	t.eq(c.progress.points_in(kind), points + 3, "proficiency from the lost battle is kept")


func test_max_hp_gain_raises_hp() -> void:
	var run := make_run(43)
	for c in run.roster:
		c.data = growth_companion({"HP": 100})
		c.progress.data = c.data
		c.hp = 10
	var f := run.fronts[0]
	f.xp_pool = Levels.xp_to_next(1) * run.lineup.size()
	var r := fight(run, true, f)
	t.eq(r.level_ups.size(), run.lineup.size(), "everyone levels once")
	for c in run.roster:
		t.eq(c.progress.stat_gain(Stat.HP), 1, "max HP +1")
		t.eq(c.max_hp(), c.data.max_hp + 1, "max HP raised")
		t.eq(c.hp, mini(c.max_hp(), 10 + 1 + heal_amount(c)), "current HP raised by the same, then the daily heal")
	t.check(Levels.gains_text(r.level_ups[0].gains).contains("HP +1"), "the report lists the stats that rose")


func test_tavern_hire_level() -> void:
	var run := make_run(44)
	run.roster[0].progress.level = 3
	run.roster[1].progress.level = 6
	t.eq(run.hire_level(), 4, "average 4.5 rounds down to 4")
	run.gold = 1000
	force_day(run, RunCalendar.DayType.FREE)
	var c := run.hire(run.tavern_offers[0])
	t.eq(c.level(), 4, "joins at level 4")
	var total := 0
	for key: String in c.progress.stat_gains:
		total += int(c.progress.stat_gains[key])
	t.check(total >= 3 * RunConfig.MIN_STAT_GAINS, "with the gains of 3 level-ups rolled (%d)" % total)
	t.eq(c.hp, c.max_hp(), "at full HP, max HP included")
	t.eq(c.progress.xp, 0, "no XP toward the next level")
	var fresh := make_run(45)
	force_day(fresh, RunCalendar.DayType.FREE)
	fresh.gold = 1000
	t.eq(fresh.hire(fresh.tavern_offers[0]).level(), 1, "a level 1 roster hires at level 1")


## The pace target: fielded in every battle in a party of four with an average share of the points, a
## companion ends around level 12-15. Battles here end at once with nobody scoring, so every share is
## exactly the average one (the pool split evenly).
## Battles are won outright (this measures XP, not survival) on the front nearest danger 2.
func test_level_pace() -> void:
	var levels: Array[int] = []
	var runs := 40
	for s in runs:
		var run := make_run(2000 + s)
		var extra: Array[CompanionData] = []
		for d in content().companions:
			if not run._in_roster(d):
				extra.append(d)
		for i in 2:
			run._join(extra[i])
		while not run.is_over():
			match run.day_type():
				RunCalendar.DayType.BATTLE, RunCalendar.DayType.ELITE, RunCalendar.DayType.BOSS:
					var best: Front = run.fronts[0]
					for f in run.fronts:
						if absi(f.danger - 2) < absi(best.danger - 2):
							best = f
					fight(run, true, best)
				RunCalendar.DayType.FREE:
					advance(run)
		t.eq(run.outcome, Run.Outcome.VICTORY, "seed %d: every battle won reaches the end" % s)
		for c in run.roster:
			levels.append(c.level())
	var total := 0
	for l in levels:
		total += l
	var avg := float(total) / levels.size()
	levels.sort()
	print("  level pace (party of 4, every battle won, front nearest danger 2): average final level %.1f, range %d-%d" % [
		avg, levels[0], levels[-1]])
	t.check(avg >= 12.0 and avg <= 15.0, "average final level %.1f is within 12-15" % avg)


# ---------------------------------------------------------------- playthrough

## A simple policy plays whole runs through the rule classes. Proves a run can be completed and
## reports the numbers to tune against. Balance is not checked.
func test_playthrough() -> void:
	var runs := 200
	var wins := 0
	var end_days := {}
	var causes := {}
	var total_won := 0
	var total_lost := 0
	var roster_sizes := 0
	var city_left := 0
	var gold_left := 0
	var reached := [0, 0, 0]   # boss 1, 2, 3 reached
	var final_levels := 0
	var final_count := 0
	var spread_total := 0   # highest minus lowest level in the company at the end, over runs with 2+
	var spread_runs := 0
	var spread_widest := 0
	var faced := {}    # boss group -> times faced
	var sparred := 0
	var drilled := 0
	var cured := 0
	var yielded := 0
	var scavenged: Array[int] = [0, 0, 0]
	var scavenge_injured := 0
	var upgrades := {}
	var upgrades_total := 0
	var enchants := [0, 0, 0, 0]   # attempts, second tries, rolls taken, taken on second tries
	var moves := 0
	var swaps := 0
	var taken := {RunConfig.TIMBER: 0, RunConfig.IRON_ORE: 0}
	var walls_after_empty := 0   # runs lost by the walls after a day given up for want of anyone
	var beaten := {}   # boss group -> times beaten
	var elites := {}   # elite day -> [faced, won]
	var crafted := {}   # accessory type id -> made
	var crafted_total := 0
	var worn_changes := 0
	var covers := 0
	var retreats := 0
	var staggers := 0
	var by_busiest := [0, 0, 0, 0]
	var by_rank := [0, 0, 0, 0, 0]
	var stones := 0
	var stones_by_rank := [0, 0, 0, 0, 0]
	var call_offered := {}    # calling id -> times among the open choices
	var call_taken := {}      # calling id -> times taken
	var call_battles := {}    # calling id -> [fought, won] with it in the line
	var all_battles := [0, 0]
	var call_by_name := {}    # companion -> {calling id -> runs}
	var rouses := 0
	var raises := 0
	for s in runs:
		var run := make_run(1000 + s)
		var policy := RunPolicy.new(_seeded(5000 + s))
		policy.play(run)
		sparred += policy.sparred
		drilled += policy.drilled
		cured += policy.cured
		for k in 3:
			scavenged[k] += policy.scavenged[k]
		scavenge_injured += policy.scavenge_injured
		for f: int in policy.upgrades:
			upgrades[f] = int(upgrades.get(f, 0)) + int(policy.upgrades[f])
			upgrades_total += int(policy.upgrades[f])
		enchants[0] += policy.enchant_attempts
		enchants[1] += policy.enchant_retries
		enchants[2] += policy.enchant_taken
		enchants[3] += policy.enchant_taken_retry
		moves += policy.moves
		swaps += policy.swaps
		for m: String in taken:
			taken[m] += int(run.materials_taken.get(m, 0))
		yielded += policy.yielded
		for d: int in policy.elites:
			var e: Array = elites.get(d, [0, 0])
			elites[d] = [int(e[0]) + int(policy.elites[d][0]), int(e[1]) + int(policy.elites[d][1])]
		stones += run.gems_taken
		for id: String in policy.crafted:
			crafted[id] = int(crafted.get(id, 0)) + int(policy.crafted[id])
			crafted_total += int(policy.crafted[id])
		worn_changes += policy.worn_changes
		covers += policy.covers
		retreats += policy.retreats
		staggers += policy.staggers
		for i in 4:
			by_busiest[i] += policy.actions_by_rank[i]
		for id: String in policy.callings_offered:
			call_offered[id] = int(call_offered.get(id, 0)) + int(policy.callings_offered[id])
		for id: String in policy.callings_taken:
			call_taken[id] = int(call_taken.get(id, 0)) + int(policy.callings_taken[id])
		for id: String in policy.calling_battles:
			var cb: Array = call_battles.get(id, [0, 0])
			call_battles[id] = [int(cb[0]) + int(policy.calling_battles[id][0]), int(cb[1]) + int(policy.calling_battles[id][1])]
		all_battles[0] += policy.battles[0]
		all_battles[1] += policy.battles[1]
		for who: String in policy.calling_of:
			if not call_by_name.has(who):
				call_by_name[who] = {}
			var mine: Dictionary = call_by_name[who]
			mine[policy.calling_of[who]] = int(mine.get(policy.calling_of[who], 0)) + 1
		rouses += policy.rouses
		raises += policy.raises
		for a in run.accessories:
			by_rank[a.rank - 1] += 1
		for r in range(1, 6):
			stones_by_rank[r - 1] += run.gem_count(r)
		if run.outcome == Run.Outcome.DEFEAT and run.city_health <= 0 and policy.yielded > 0:
			walls_after_empty += 1
		for d: int in run.boss_draw:
			var g: EnemyGroupData = run.boss_draw[d]
			if run.day < d:
				continue
			faced[g] = faced.get(g, 0) + 1
			if run.day > d or run.outcome == Run.Outcome.VICTORY:
				beaten[g] = beaten.get(g, 0) + 1
		t.check(run.is_over(), "seed %d: the run ends" % s)
		t.check(run.day >= 1 and run.day <= RunConfig.DAYS, "seed %d: within 42 days" % s)
		if run.outcome == Run.Outcome.VICTORY:
			wins += 1
			t.eq(run.day, RunConfig.DAYS, "a win ends on day 42")
		end_days[run.day] = end_days.get(run.day, 0) + 1
		var cause := "won"
		if run.outcome == Run.Outcome.DEFEAT:
			cause = "boss" if RunCalendar.is_boss_day(run.day) else ("city" if run.city_health <= 0 else "roster")
		causes[cause] = causes.get(cause, 0) + 1
		total_won += run.battles_won
		total_lost += run.battles_lost
		roster_sizes += run.roster.size()
		var low := RunConfig.MAX_LEVEL
		var high := 0
		for c in run.roster:
			final_levels += c.level()
			final_count += 1
			low = mini(low, c.level())
			high = maxi(high, c.level())
		if run.roster.size() >= 2:
			spread_total += high - low
			spread_runs += 1
			spread_widest = maxi(spread_widest, high - low)
		city_left += run.city_health
		gold_left += run.gold
		for i in 3:
			if run.day >= (i + 1) * RunConfig.BOSS_EVERY_DAYS:
				reached[i] += 1
	var days := end_days.keys()
	days.sort()
	var spread: Array[String] = []
	for d in days:
		spread.append("%d:%d" % [d, end_days[d]])
	var median_day := 0
	var seen := 0
	for d in days:
		seen += end_days[d]
		if seen * 2 >= runs:
			median_day = d
			break
	print("  playthrough (%d runs, simple policy): %d wins (%d%%), median end day %d" % [runs, wins, roundi(100.0 * wins / runs), median_day])
	print("    reached boss 1 / 2 / 3: %d / %d / %d" % reached)
	print("    ended by: %s" % str(causes))
	print("    end day counts: %s" % ", ".join(spread))
	print("    average final level of the companions still in the run: %.1f" % (float(final_levels) / maxf(1, final_count)))
	print("    level spread in the company at the end (highest - lowest): average %.1f, widest %d (%d runs with 2+)" % [
		float(spread_total) / maxf(1, spread_runs), spread_widest, spread_runs])
	print("    per run: %.1f battles won, %.1f lost; %.1f companions, %.0f city health, %.0f gold at the end" % [
		float(total_won) / runs, float(total_lost) / runs, float(roster_sizes) / runs, float(city_left) / runs, float(gold_left) / runs])
	print("    training ground per run: %.1f sparring, %.1f proficiency drills" % [float(sparred) / runs, float(drilled) / runs])
	print("    infirmary: %.1f cures per run; %d days given up with nobody to field; %d runs lost by the walls after such a day" % [
		float(cured) / runs, yielded, walls_after_empty])
	var elite_days := elites.keys()
	elite_days.sort()
	var elite_text: Array[String] = []
	for d: int in elite_days:
		elite_text.append("day %d %d / %d (%d%%)" % [d, elites[d][0], elites[d][1], roundi(100.0 * elites[d][1] / maxf(1, elites[d][0]))])
	print("    elites (reached / won): %s" % ", ".join(elite_text))
	print("    gemstones per run: %.2f (Topaz..Diamond %s)" % [float(stones) / runs, str(stones_by_rank)])
	var made := crafted.keys()
	made.sort_custom(func(a: String, b: String) -> bool: return crafted[a] > crafted[b] or (crafted[a] == crafted[b] and a < b))
	var made_text: Array[String] = []
	for id: String in made:
		made_text.append("%s %d" % [id, crafted[id]])
	print("    accessories per run: %.2f made (Topaz..Diamond %s), %.2f put on; %d types seen: %s" % [
		float(crafted_total) / runs, str(by_rank), float(worn_changes) / runs, made.size(), ", ".join(made_text)])
	var acts: int = by_busiest[0] + by_busiest[1] + by_busiest[2] + by_busiest[3]
	print("    battles: %.2f covers, %.2f blows staggered and %.2f retreats per run; with four in the line, actions busiest first %d%% / %d%% / %d%% / %d%%" % [
		float(covers) / runs, float(staggers) / runs, float(retreats) / runs, roundi(100.0 * by_busiest[0] / maxi(1, acts)), roundi(100.0 * by_busiest[1] / maxi(1, acts)),
		roundi(100.0 * by_busiest[2] / maxi(1, acts)), roundi(100.0 * by_busiest[3] / maxi(1, acts))])
	var trips: int = scavenged[0] + scavenged[1] + scavenged[2]
	print("    scavenging: %.1f trips per run (full %d%%, half %d%%, nothing %d%%); %.2f injured per run" % [
		float(trips) / runs, roundi(100.0 * scavenged[0] / maxf(1, trips)), roundi(100.0 * scavenged[1] / maxf(1, trips)),
		roundi(100.0 * scavenged[2] / maxf(1, trips)), float(scavenge_injured) / runs])
	var built: Array[String] = []
	for f: int in Run.Facility.values():
		built.append("%s %.2f" % [Run.FACILITY_NAMES[f], float(upgrades.get(f, 0)) / runs])
	print("    city: %.1f upgrades per run (%s); %.2f moves, %.1f swaps per run" % [
		float(upgrades_total) / runs, ", ".join(built), float(moves) / runs, float(swaps) / runs])
	print("    enchanting per run: %.1f attempts, %.1f of them second tries; new rolls taken %.1f (%.1f on second tries, %d%% of them)" % [
		float(enchants[0]) / runs, float(enchants[1]) / runs, float(enchants[2]) / runs, float(enchants[3]) / runs,
		roundi(100.0 * enchants[3] / maxf(1, enchants[1]))])
	print("    materials taken in per run: %.1f timber, %.1f iron ore" % [float(taken[RunConfig.TIMBER]) / runs, float(taken[RunConfig.IRON_ORE]) / runs])
	if not call_taken.is_empty():
		print("    callings (taken / offered when someone chose; battles with it in the line won; all battles won %d%%):" % roundi(
			100.0 * all_battles[1] / maxf(1, all_battles[0])))
		for calling in CallingLibrary.load_default().callings:
			var cb: Array = call_battles.get(calling.id, [0, 0])
			print("      %-12s %4d / %4d  %3d%%    %5d battles  %3d%%" % [calling.display_name, int(call_taken.get(calling.id, 0)),
				int(call_offered.get(calling.id, 0)), roundi(100.0 * int(call_taken.get(calling.id, 0)) / maxf(1, int(call_offered.get(calling.id, 0)))),
				int(cb[0]), roundi(100.0 * int(cb[1]) / maxf(1, int(cb[0])))])
		var most: Array[String] = []
		for who: String in call_by_name:
			var mine: Dictionary = call_by_name[who]
			var total := 0
			var top := ""
			for id: String in mine:
				total += int(mine[id])
				if top == "" or int(mine[id]) > int(mine[top]):
					top = id
			if total >= 20:
				most.append("%s %s %d%% of %d" % [who, top, roundi(100.0 * int(mine[top]) / total), total])
		most.sort()
		print("    each companion's most-taken calling: %s" % "; ".join(most))
		print("    per run: %.2f rouses, %.2f raised" % [float(rouses) / runs, float(raises) / runs])
	print("    bosses (faced / beaten / beaten %):")
	for g in content().bosses:
		var f: int = faced.get(g, 0)
		var w: int = beaten.get(g, 0)
		print("      day %d  %-24s %4d / %4d  %3d%%" % [g.min_day, g.display_name, f, w, roundi(100.0 * w / maxf(1, f))])
		t.check(f > 0, "%s was faced at least once" % g.display_name)
