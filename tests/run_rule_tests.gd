extends RefCounted
## Headless tests for the run rules (calendar, fronts, battles in a run, city, party, free days,
## events) and the automated playthrough. Called from run_tests.gd, which owns check() and eq().

const RunPolicy := preload("res://tests/run_policy.gd")

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_calendar_guarantees,
		test_same_seed_same_run,
		test_upcoming_days,
		test_run_start,
		test_front_generation_by_danger,
		test_enemy_scaling,
		test_battle_uses_run_hp_and_weapon,
		test_win_grants_reward,
		test_loss_costs_city_and_run_continues,
		test_lost_boss_ends_run,
		test_day_30_win,
		test_city_health_zero_ends_run,
		test_empty_roster_ends_run,
		test_daily_heal,
		test_injured_return_at_1hp,
		test_removed_stay_gone,
		test_fielded_limit_and_order,
		test_party_locked_after_commit,
		test_free_day_action_limits,
		test_rest,
		test_shop_and_equip_requirement,
		test_weapon_held_by_one,
		test_tavern_hiring,
		test_repair,
		test_event_choices,
		test_run_content,
		test_playthrough,
	]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts)


## Turns today into a day of `type` and prepares it again.
func force_day(run: Run, type: int) -> void:
	run.calendar[run.day - 1] = type
	run._begin_day()


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

func test_calendar_guarantees() -> void:
	var D := RunCalendar.DayType
	for s in 500:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var cal := RunCalendar.generate(rng)
		t.eq(cal.size(), RunConfig.DAYS, "seed %d: 30 days" % s)
		t.eq(cal[0], D.BATTLE, "seed %d: day 1 is a battle" % s)
		for d in range(1, cal.size() + 1):
			var boss := d % 10 == 0
			t.check((cal[d - 1] == D.BOSS) == boss, "seed %d: boss only on days 10, 20, 30 (day %d)" % [s, d])
			if boss:
				t.eq(cal[d - 2], D.FREE, "seed %d: day %d before a boss is free" % [s, d - 1])
		for b in 3:
			var counts := [0, 0, 0, 0]
			for d in range(b * 10, b * 10 + 10):
				counts[cal[d]] += 1
			t.check(counts[D.BATTLE] >= 5 and counts[D.BATTLE] <= 6, "seed %d block %d: 5-6 battles (%d)" % [s, b, counts[D.BATTLE]])
			t.eq(counts[D.FREE], 2, "seed %d block %d: 2 free days" % [s, b])
			t.check(counts[D.EVENT] >= 1 and counts[D.EVENT] <= 2, "seed %d block %d: 1-2 events" % [s, b])
			t.eq(counts[D.BOSS], 1, "seed %d block %d: one boss" % [s, b])


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
	run.day = 26
	t.eq(run.upcoming().size(), 5, "near the end only the days left (26-30)")


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
		t.eq(run.inventory.weapons.size(), 2, "each brings a weapon")
		for c in run.roster:
			t.eq(c.hp, c.max_hp(), "full HP")
			t.eq(run.inventory.held_by(c).data, c.data.weapon, "holds their own weapon")
			seen[c.display_name()] = true
	t.eq(seen.size(), 5, "every companion can start a run")


# ---------------------------------------------------------------- fronts and enemies

func test_front_generation_by_danger() -> void:
	var counts := {2: 0, 3: 0}
	var hp_by_danger := [0.0, 0.0, 0.0]
	var n_by_danger := [0, 0, 0]
	var materials_by_danger := [0, 0, 0]
	for s in 40:
		var run := make_run(s)
		for d in range(1, RunConfig.DAYS + 1):
			if d % 10 == 0:
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
	t.eq(d1.max_hp, orc.max_hp, "day 1 unchanged HP")
	t.eq(d1.strength, orc.strength, "day 1 unchanged STR")
	t.check(d1 != orc, "a copy, not the data itself")
	var d30 := Run.scaled_enemy(orc, 30)
	t.eq(d30.max_hp, roundi(60 * (1.0 + 0.03 * 29)), "day 30 HP")
	t.eq(d30.strength, orc.strength + 4, "day 30 STR +4")
	t.eq(d30.defense, orc.defense + 2, "day 30 DEF +2")
	t.eq(orc.max_hp, 60, "the data is not changed")
	var run := make_run(5)
	run.day = 15
	force_day(run, RunCalendar.DayType.BATTLE)
	for f in run.fronts:
		for i in f.enemies.size():
			t.check(f.enemies[i].max_hp > f.group.enemies[i].max_hp, "day 15 enemies are tougher")
	run.day = 20
	force_day(run, RunCalendar.DayType.BOSS)
	t.eq(run.fronts.size(), 1, "one boss front")
	var boss := run.fronts[0]
	t.check(boss.is_boss, "boss front")
	t.eq(boss.enemies[0], boss.group.enemies[0], "the boss itself is not scaled")
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
	run.day = 10
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.BOSS, "day 10 is the boss")
	t.eq(run.fronts.size(), 1, "one front")
	var r := fight(run, false)
	t.eq(run.outcome, Run.Outcome.DEFEAT, "losing a boss ends the run")
	t.check(r.run_over, "report says so")
	t.eq(run.day, 10, "stays on the boss day")
	t.eq(run.city_health, 100, "no separate city damage")
	t.check(run.start_battle(run.fronts[0] if not run.fronts.is_empty() else null) == null, "nothing more to fight")

	var won := make_run(4)
	won.day = 10
	won._begin_day()
	fight(won, true)
	t.eq(won.outcome, Run.Outcome.ONGOING, "winning the day 10 boss goes on")
	t.eq(won.day, 11, "to day 11")


func test_day_30_win() -> void:
	var run := make_run(6)
	run.day = 30
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.BOSS, "day 30 is the boss")
	var r := fight(run, true)
	t.eq(run.outcome, Run.Outcome.VICTORY, "winning day 30 wins the run")
	t.check(r.run_over, "report says so")
	t.eq(run.day, 30, "stays on day 30")


func test_city_health_zero_ends_run() -> void:
	var run := make_run(8)
	run.city_health = 10
	var r := fight(run, false)
	t.eq(run.city_health, 0, "city at 0")
	t.eq(r.city_damage, 10, "damage reported up to what was left")
	t.eq(run.outcome, Run.Outcome.DEFEAT, "the city falls")
	t.check(r.run_over, "run over")

	var by_event := make_run(8)
	force_day(by_event, RunCalendar.DayType.EVENT)
	var ch := EventChoiceData.new()
	ch.city_health = -200
	by_event.event = EventData.new()
	by_event.event.choices.append(ch)
	by_event.choose(ch)
	t.eq(by_event.outcome, Run.Outcome.DEFEAT, "an event can also bring the city down")


func test_empty_roster_ends_run() -> void:
	var run := make_run(9)
	fight(run, false, null, func(b: Battle) -> void:
		for c in b.roster:
			c.state = CompanionUnit.State.GONE)
	t.eq(run.roster.size(), 0, "everyone gone")
	t.eq(run.outcome, Run.Outcome.DEFEAT, "an empty roster ends the run")
	t.check(run.end_reason.contains("No companions"), "reason given")


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


func test_injured_return_at_1hp() -> void:
	for win in [true, false]:
		var run := make_run(12)
		var first := run.lineup[0]
		var r := fight(run, win, null, func(b: Battle) -> void:
			# The first companion is injured during the battle.
			b._damage_companion(b.roster[0], 999, false))
		t.check(r.injured.has(first.display_name()), "reported injured (won: %s)" % win)
		t.eq(first.hp, 1 + heal_amount(first), "back at 1 HP, then the daily heal (won: %s)" % win)
		t.check(run.roster.has(first), "still in the roster")


func test_removed_stay_gone() -> void:
	var run := make_run(13)
	var lost := run.lineup[0]
	var weapon := run.inventory.held_by(lost)
	var r := fight(run, true, null, func(b: Battle) -> void:
		b._damage_companion(b.roster[0], 999, false)
		b._damage_companion(b.roster[0], 1, false))
	t.check(r.removed.has(lost.display_name()), "reported removed")
	t.check(not run.roster.has(lost) and not run.lineup.has(lost), "out of the roster and line")
	t.check(run.gone.has(lost.data), "remembered as gone")
	t.check(weapon.holder == null and run.inventory.weapons.has(weapon), "their weapon goes back to the armory")
	for d in 40:
		force_day(run, RunCalendar.DayType.FREE)
		t.check(not run.tavern_offers.has(lost.data), "never offered at the tavern again")


func test_fielded_limit_and_order() -> void:
	var run := make_run(14)
	run.gold = 10000
	force_day(run, RunCalendar.DayType.FREE)
	var hired := 0
	while run.roster.size() < 5:
		run.actions_left = 2
		run.actions_used.clear()
		run.tavern_offers.clear()
		run._make_tavern_offers()
		if run.tavern_offers.is_empty():
			break
		t.check(run.hire(run.tavern_offers[0]) != null, "hired")
		hired += 1
	t.eq(run.roster.size(), 5, "five companions")
	t.eq(run.lineup.size(), 5, "all five fielded")
	t.check(run.reserve().is_empty(), "no reserve")
	var sixth := RunCompanion.create(companion("aina"))
	run.roster.append(sixth)
	t.check(not run.field(sixth), "a sixth cannot be fielded")
	t.eq(run.reserve(), [sixth] as Array[RunCompanion], "the sixth waits in reserve")
	var front_most := run.lineup[4]
	t.check(run.bench(front_most), "bench one")
	t.eq(run.lineup.size(), 4, "four fielded")
	t.check(run.field(sixth, 0), "now the sixth fits, at the back")
	t.eq(run.lineup[0], sixth, "leftmost")
	t.check(run.move_in_line(sixth, 4), "move to the front")
	t.eq(run.lineup[4], sixth, "rightmost")
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
	t.eq(run.actions_left, 2, "two actions")
	t.check(run.repair(), "repair")
	t.eq(run.actions_left, 1, "one left")
	t.check(not run.repair(), "repair only once a day")
	t.check(run.free_action_block_reason(Run.FreeAction.REPAIR).contains("Already"), "says why")
	t.check(run.rest(), "rest")
	t.eq(run.actions_left, 0, "none left")
	var item := run.shop_stock()[0]
	t.check(run.buy(item) == null, "no action left for the shop")
	t.check(run.buy_block_reason(item).contains("No actions"), "says why")
	t.check(run.hire_block_reason(run.tavern_offers[0]).contains("No actions") if not run.tavern_offers.is_empty() else true, "no tavern either")
	t.check(run.end_free_day(), "end the day")
	t.eq(run.day, 2, "next day")
	# Unused actions are lost.
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.actions_left, 2, "a fresh free day has two again")
	run.end_free_day()
	force_day(run, RunCalendar.DayType.FREE)
	t.eq(run.actions_left, 2, "never more than two")
	t.eq(run.actions_used.size(), 0, "nothing used yet")
	# Not on other days.
	force_day(run, RunCalendar.DayType.BATTLE)
	t.check(not run.rest(), "no rest on a battle day")
	t.check(not run.end_free_day(), "no ending a battle day without the battle")


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
	var c := run.roster[0]
	var kind := c.weapon().weapon_type
	var steel: ShopItemData = null
	var silver: ShopItemData = null
	for item in content().shop:
		if item.weapon.weapon_type == kind and item.weapon.required_grade == Proficiency.Grade.C:
			steel = item
		if item.weapon.weapon_type == kind and item.weapon.required_grade == Proficiency.Grade.B:
			silver = item
	t.check(steel != null and silver != null, "steel and silver of every type")
	t.check(run.shop_stock().has(steel), "steel sold from day 1")
	t.check(not run.shop_stock().has(silver), "silver not sold on day 1")
	run.gold = steel.price - 1
	t.check(run.buy(steel) == null, "cannot afford")
	t.check(run.buy_block_reason(steel).contains("gold"), "says gold")
	t.eq(run.actions_left, 2, "no action spent on a failed purchase")
	run.gold = steel.price * 3
	var owned := run.buy(steel)
	t.check(owned != null, "bought")
	t.eq(run.gold, steel.price * 2, "paid")
	t.eq(run.actions_left, 1, "the shop uses one action")
	t.check(owned.holder == null, "goes to the armory")
	t.check(run.buy(steel) != null, "a second purchase the same visit")
	t.eq(run.actions_left, 1, "is free")
	# Equip requirement: companions start at D, steel needs C.
	t.eq(c.progress.grade(kind), Proficiency.Grade.D, "starts at D")
	var old := run.inventory.held_by(c)
	t.check(not run.equip_weapon(c, owned), "C weapon refused at D")
	t.check(run.equip_block_reason(c, owned).contains("grade C"), "says which grade: %s" % run.equip_block_reason(c, owned))
	c.progress.points[kind] = Proficiency.points_for(Proficiency.Grade.C)
	t.check(run.equip_weapon(c, owned), "allowed at C")
	t.eq(c.weapon(), steel.weapon, "now holds it")
	t.check(old.holder == null, "the old weapon goes back to the armory")
	run.day = 11
	run.calendar[10] = RunCalendar.DayType.FREE
	run._begin_day()
	t.check(run.shop_stock().has(silver), "silver sold from day 11")


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
	t.eq(run.actions_left, 1, "the tavern uses one action")


func test_repair() -> void:
	var run := make_run(21)
	force_day(run, RunCalendar.DayType.FREE)
	run.materials = {RunConfig.IRON_ORE: 1, RunConfig.TIMBER: 2}
	t.check(not run.repair(), "nothing to repair at full health")
	run.city_health = 90
	t.check(run.repair(), "repair")
	t.eq(run.city_health, 100, "capped at 100")
	t.eq(run.material(RunConfig.TIMBER), 0, "timber spent")
	t.eq(run.material(RunConfig.IRON_ORE), 0, "iron spent")
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
			force_day(run, RunCalendar.DayType.EVENT)
			run.event = ev
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
				expected = mini(c.max_hp(), expected + heal_amount(c))
				t.eq(c.hp, expected, "%s / %s: %s HP" % [ev.title, ch.label, c.display_name()])
			t.eq(run.inventory.weapons.size(), weapons + (1 if ch.weapon != null else 0), "%s / %s: weapon" % [ev.title, ch.label])
			if ch.weapon != null:
				t.eq(run.inventory.weapons[-1].data, ch.weapon, "the weapon is in the armory")
			t.eq(run.day, 2, "the event ends the day")
			# Unaffordable choices are refused.
			if ch.gold < 0:
				var poor := make_run(31)
				force_day(poor, RunCalendar.DayType.EVENT)
				poor.event = ev
				poor.gold = -ch.gold - 1
				t.check(poor.choose(ch) == "", "%s / %s: refused without the gold" % [ev.title, ch.label])
				t.eq(poor.day, 1, "and the day goes on")
	# HP losses never take a companion below 1.
	var run := make_run(32)
	force_day(run, RunCalendar.DayType.EVENT)
	var hurt := EventChoiceData.new()
	hurt.companion_hp = -500
	hurt.hp_target = EventChoiceData.HpTarget.ALL
	run.event = EventData.new()
	run.event.choices.append(hurt)
	run.choose(hurt)
	for c in run.roster:
		t.eq(c.hp, 1 + heal_amount(c), "HP loss stops at 1")
	# Events do not repeat while unseen ones remain.
	var seen := {}
	var r2 := make_run(33)
	for i in content().events.size():
		force_day(r2, RunCalendar.DayType.EVENT)
		t.check(not seen.has(r2.event), "no repeat while unseen events remain")
		seen[r2.event] = true


func test_run_content() -> void:
	var rc := content()
	t.eq(rc.companions.size(), 5, "five companions")
	t.eq(rc.bosses.size(), 3, "three bosses")
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
	# Every weapon type has stronger tiers that need a higher grade.
	for t_kind: int in WeaponData.WeaponType.values():
		var grades := {}
		for item in rc.shop:
			if item.weapon.weapon_type == t_kind:
				grades[item.weapon.required_grade] = item.weapon.might
		t.check(grades.size() >= 3, "%s: three tiers" % WeaponData.type_name(t_kind))
		t.check(grades[Proficiency.Grade.C] > grades[Proficiency.Grade.E] and grades[Proficiency.Grade.B] > grades[Proficiency.Grade.C],
			"%s: higher grade, more might" % WeaponData.type_name(t_kind))


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
	for s in runs:
		var run := make_run(1000 + s)
		var policy := RunPolicy.new(_seeded(5000 + s))
		policy.play(run)
		t.check(run.is_over(), "seed %d: the run ends" % s)
		t.check(run.day >= 1 and run.day <= 30, "seed %d: within 30 days" % s)
		if run.outcome == Run.Outcome.VICTORY:
			wins += 1
			t.eq(run.day, 30, "a win ends on day 30")
		end_days[run.day] = end_days.get(run.day, 0) + 1
		var cause := "won"
		if run.outcome == Run.Outcome.DEFEAT:
			cause = "boss" if run.day % 10 == 0 else ("city" if run.city_health <= 0 else "roster")
		causes[cause] = causes.get(cause, 0) + 1
		total_won += run.battles_won
		total_lost += run.battles_lost
		roster_sizes += run.roster.size()
		city_left += run.city_health
		gold_left += run.gold
		for i in 3:
			if run.day >= (i + 1) * 10:
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
	print("    per run: %.1f battles won, %.1f lost; %.1f companions, %.0f city health, %.0f gold at the end" % [
		float(total_won) / runs, float(total_lost) / runs, float(roster_sizes) / runs, float(city_left) / runs, float(gold_left) / runs])
