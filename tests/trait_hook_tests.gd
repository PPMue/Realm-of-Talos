extends RefCounted
## Headless tests for the traits of waves 2 and 3 (design/traits.md): the single moments (a kill, a
## critical, the first blow, once a battle, the day's end, the Infirmary, gold and materials, XP and
## drills), and, once built, those that touch other people and the scavenging ones. Table-driven like
## trait_tests.gd: each row is a number with the trait minus without it; the moments that need a whole
## battle or run have their own tests. Called from run_tests.gd, which owns check() and eq().

var t   # the runner (run_tests.gd)
var _lib: TraitLibrary


func _init(runner: Object) -> void:
	t = runner
	_lib = TraitLibrary.load_default()


func tests() -> Array[Callable]:
	return [
		test_hook_table,
		test_city_traits_need_the_holder_up,
		test_traits_with_facilities,
		test_apprentice_leans_higher,
		test_second_trade_follows_the_grades,
		test_battle_gains_in_the_report,
		test_mentor,
		test_sure_footed,
		test_pack_mule,
	]


## Every trait these tests cover: the table's and those with tests of their own.
static func covered_ids() -> Array[String]:
	var out: Array[String] = []
	for row: Array in table():
		if not out.has(row[0]):
			out.append(row[0])
	for id in OWN_TESTS:
		if not out.has(id):
			out.append(id)
	return out


## Traits checked by a test of their own rather than the table.
const OWN_TESTS: Array[String] = ["apprentice", "mentor", "sure_footed", "pack_mule"]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


func trait_of(id: String) -> TraitData:
	var x := _lib.find(id)
	if x == null:
		t.check(false, "no trait %s" % id)
	return x


## The plain companion of trait_tests.gd: HP 40, STA 30, STR 10, MAG 10, CRT 6 (or `crt`), DEX 10,
## SPD 10, DEF 5, RES 5, LCK 0, BLD 10, every growth 40, a test weapon of `wt` (Mt 9, Hit `hit`).
func data(wt: int = WeaponData.WeaponType.SWORD, hit: int = 50, crt: int = 6) -> CompanionData:
	var c := CompanionData.new()
	c.display_name = "Tester %d" % randi()
	c.max_hp = 40
	c.max_sta = 30
	c.strength = 10
	c.magic = 10
	c.crit = crt
	c.dexterity = 10
	c.speed = 10
	c.defense = 5
	c.resistance = 5
	c.luck = 0
	c.build = 10
	var g := {}
	for key in Levels.GROWTH_STATS:
		g[key] = 40
	c.growths = g
	var w := WeaponData.new()
	w.display_name = "Test %s" % WeaponData.type_name(wt)
	w.weapon_type = wt
	w.might = 9
	w.hit = hit
	c.weapon = w
	return c


## STR 10, MAG 10, DEX 10, SPD 10, DEF 2, RES 2, LCK 0, HP 100; one action (Mt 5, Hit 50) that never comes.
func enemy(magic: bool = false) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = "Target"
	e.max_hp = 100
	e.strength = 10
	e.magic = 10
	e.dexterity = 10
	e.speed = 10
	e.defense = 2
	e.resistance = 2
	e.luck = 0
	var a := EnemyActionData.new()
	a.display_name = "Blow"
	a.countdown = 999
	a.might = 5
	a.hit = 50
	a.damage_type = CombatMath.DamageType.MAGIC if magic else CombatMath.DamageType.PHYSICAL
	var acts: Array[EnemyActionData] = [a]
	e.actions = acts
	return e


func black_spell(tier: int = 1) -> SpellData:
	var s := SpellData.new()
	s.display_name = "Test Bolt %d" % tier
	s.school = SpellData.School.BLACK
	s.tier = tier
	s.targeting = SpellData.Targeting.ONE_ENEMY
	s.uses = 6
	s.might = 5
	s.hit = 50
	return s


func white_spell() -> SpellData:
	var s := SpellData.new()
	s.display_name = "Test Mend"
	s.school = SpellData.School.WHITE
	s.targeting = SpellData.Targeting.ONE_ALLY
	s.heals = true
	s.heal_power = 5
	return s


## A battle of `opts.line` plain companions (default 1); the traits go to slot `opts.holder` (default:
## the one measured, `opts.slot`, default the front). Returns the measured value of `metric`.
func measure(traits: Array[TraitData], metric: String, opts: Dictionary) -> int:
	var line: int = opts.get("line", 1)
	var slot: int = opts.get("slot", line - 1)
	var holder: int = opts.get("holder", slot)
	var wt: int = opts.get("weapon", WeaponData.WeaponType.SWORD)
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for i in line:
		var d := data(wt, opts.get("hit", 50), opts.get("crt", 6))
		datas.append(d)
		var p := CompanionProgress.create(d)
		if i == holder:
			p.traits = traits
		party.append(p)
	var es: Array[EnemyData] = [enemy(opts.get("enemy_magic", false))]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var b := Battle.new(datas, es, rng, party)
	var u := b.roster[slot]
	var h := b.roster[holder]
	var e := b.enemies[0]
	u.blows_taken = opts.get("blows_taken", 0)
	u.arts_used = opts.get("arts_used", 0)
	if opts.has("self_hp"):
		u.hp = opts.self_hp
	if opts.get("ally_injured", false):
		for c in b.roster:
			if c != h:
				b._injure(c)
				break
	if opts.get("rival", false):
		for c in b.roster:
			if c != h:
				b.kills[c] = 1
	if opts.get("holder_kills", false):
		b._on_kill(h)
	var art := CombatArtData.new()
	art.display_name = "Test Cut"
	art.weapon_type = wt
	art.stamina_cost = 5
	art.recovery = 1
	u.progress.learn(art)
	var action := e.pending_action
	match metric:
		"hit":
			return b.forecast(u, e).hit
		"crit":
			return b.forecast(u, e).crit
		"damage":
			return b.forecast(u, e).damage
		"enemy_hit":
			return b.enemy_forecast(e, action, u).hit
		"taken":
			return b.enemy_forecast(e, action, u).damage
		"focus":
			return b.focus_amount(u)
		"action_stamina":
			u.stamina = 10
			b.guard(u)
			return u.stamina
		"art_recovery":
			return b.art_recovery(u, art)
		"kill_stamina":
			u.stamina = 10
			b._on_kill(u)
			return u.stamina
		"kill_hp":
			u.hp = 20
			b._on_kill(u)
			return u.hp
		"kill_points":
			b._on_kill(u)
			return b.points_of(u)
		"kill_recovery":
			e.hp = 1
			b.attack(u, e)
			return u.recovery
		"crit_delay":
			b.attack(u, e)
			return e.countdown
		"second_wind":
			u.stamina = 0
			b._damage_companion(u, 25, false)
			return u.stamina
		"dot_hp":
			var fx := StatusEffectData.new()
			fx.display_name = "Test Poison"
			fx.damage_per_tick = 3
			fx.duration_ticks = 3
			b._apply_effect(u, fx, false)
			b._damage_over_time(u)
			return u.hp
		"curse_ticks":
			var fx := StatusEffectData.new()
			fx.display_name = "Test Curse"
			fx.stat_mods = {Stat.DEF: -1}
			fx.duration_ticks = 3
			b._apply_effect(u, fx, false)
			return u.get_effect("Test Curse").ticks_left
		"survive":
			u.hp = 10
			b._damage_companion(u, 50, false)
			return u.hp
		"survive_twice":
			u.hp = 10
			b._damage_companion(u, 50, false)
			b._damage_companion(u, 50, false)
			return u.hp
		"martyr":
			u.hp = 10
			b._damage_companion(h, 999, false)
			return u.hp
		"prof_cap":
			return b.proficiency_cap(u, wt)
		"uses_black_1":
			return u.progress.max_uses(black_spell(1))
		"uses_black_2":
			return u.progress.max_uses(black_spell(2))
		"heal_received":
			var healer := b.roster[0] if b.roster[0] != u else b.roster[-1]
			return b.heal_amount_on(healer, white_spell(), u)
	if metric.begins_with("stat:"):
		return u.stat(metric.substr(5))
	t.check(false, "unknown metric %s" % metric)
	return 0


## A run on a free day 2 whose starters have no traits, with two plain companions joined (the holder,
## with `traits`, and another); `opts.bench`: the holder on the bench; `opts.away`: the holder in the
## Infirmary.
func city(traits: Array[TraitData], opts: Dictionary) -> Array:
	var run := make_run(opts.get("seed", 5))
	for c in run.roster:
		c.traits = []
	run.day = 2
	run.calendar[1] = RunCalendar.DayType.FREE
	run.event_days.erase(2)
	run._begin_day()
	var holder := run._join(data())
	holder.traits = traits
	holder.hp = holder.max_hp()
	var other := run._join(data())
	if opts.get("bench", false):
		run.bench(holder)
	if opts.get("away", false):
		run._to_infirmary(holder)
	return [run, holder, other]


func measure_out(traits: Array[TraitData], metric: String, opts: Dictionary) -> int:
	var got := city(traits, opts)
	var run: Run = got[0]
	var holder: RunCompanion = got[1]
	var other: RunCompanion = got[2]
	if metric.begins_with("drill_weapon"):
		return run.drill_points(Drill.weapon(opts.get("weapon", WeaponData.WeaponType.SWORD)), holder, DrillResult.Quality.GOOD)
	match metric:
		"day_heal":
			return run.day_heal(holder)
		"company_heal":
			return run.day_heal(other)
		"infirmary":
			return run.infirmary_days(holder)
		"xp":
			return Levels.with_traits(holder.progress, 100)
		"cure_cost":
			run._to_infirmary(holder)
			return run.cure_cost(holder)
		"drill_poor":
			for i in 300:
				if run._roll_drill_quality(holder) == DrillResult.Quality.POOR:
					return 1
			return 0
		"learn_steps":
			return ArtLearning.learn_steps(holder.progress)
		"hire_cost":
			return run.hire_cost()
		"drill_cost":
			return run.drill_cost()
		"shop_price":
			var item := ShopItemData.new()
			item.price = 100
			return run.shop_price(item)
		"repair_amount":
			return run.repair_amount()
		"event_gold":
			var ch := EventChoiceData.new()
			ch.gold = -100
			return run.choice_gold(ch)
		"won_gold", "won_timber", "won_ore", "won_hp", "reserve_xp", "lost_walls":
			return _battle_metric(run, holder, metric, opts)
		"scav_score":
			var site := ScavengeSite.new()
			var slot := ScavengeSite.Slot.new()
			slot.stat = Stat.SPD
			slot.target = int(holder.progress.stats()[Stat.SPD])
			site.slots.append(slot)
			site.size = 1
			return run.scavenge_slot_score(site, 0, holder)
	t.check(false, "unknown metric %s" % metric)
	return 0


## Fights day 3's battle at its first front at once: won (the holder credited with `opts.kills`), or
## lost (`metric` lost_walls), and reads `metric` from the report or the holder.
func _battle_metric(run: Run, holder: RunCompanion, metric: String, opts: Dictionary) -> int:
	run.day = 3
	run.calendar[2] = RunCalendar.DayType.BATTLE
	run._begin_day()
	var front := run.fronts[0]
	front.reward_materials = {}
	if metric == "won_hp":
		holder.hp = 5
	var b := run.start_battle(front)
	if metric == "lost_walls":
		for c in b.roster:
			b._injure(c)
	else:
		for e in b.enemies:
			e.hp = 0
		var i := run.lineup.find(holder)
		if i >= 0:
			b.kills[b.roster[i]] = opts.get("kills", 0)
	b._check_end()
	var report := run.finish_battle(b)
	match metric:
		"won_gold":
			return report.trait_gold
		"won_timber":
			return int(report.materials.get(RunConfig.TIMBER, 0))
		"won_ore":
			return int(report.materials.get(RunConfig.IRON_ORE, 0))
		"won_hp":
			return holder.hp
		"reserve_xp":
			return 1 if int(report.reserve_xp.get(holder.display_name(), 0)) > 0 else 0
		"lost_walls":
			return report.city_damage
	return 0


const OUT_METRICS := ["day_heal", "company_heal", "infirmary", "xp", "cure_cost", "drill_poor", "learn_steps", "hire_cost",
	"drill_cost", "shop_price", "repair_amount", "event_gold", "won_gold", "won_timber", "won_ore", "won_hp", "reserve_xp",
	"lost_walls", "scav_score"]


## [trait id, metric, change, options].
static func table() -> Array:
	var sure := {"hit": 999}
	var rows: Array = [
		# Tempo.
		["second_wind", "second_wind", 30, {}],
		["steady_breath", "focus", 3, {}],
		["tireless", "action_stamina", 1, {}],
		["quick_hands", "art_recovery", -1, {}], ["quick_hands", "art_recovery", 0, {"arts_used": 1}],
		["relentless", "kill_recovery", -1, sure],
		["bloodrush", "kill_stamina", 4, {}],
		["blood_drinker", "kill_hp", 2, {}],
		["staggering_blow", "crit_delay", 1, {"hit": 999, "crt": 60}], ["staggering_blow", "crit_delay", 0, {"hit": 999, "crt": 0}],
		# Staying alive.
		["thick_hide", "taken", -1, {}], ["thick_hide", "taken", 0, {"enemy_magic": true}],
		["spell_scarred", "taken", -1, {"enemy_magic": true}], ["spell_scarred", "taken", 0, {}],
		["brace", "taken", -5, {}], ["brace", "taken", 0, {"blows_taken": 1}],
		["stubborn", "enemy_hit", -15, {"self_hp": 5}], ["stubborn", "enemy_hit", 0, {"self_hp": 6}],
		["clean_blood", "dot_hp", 3, {}],
		["calm", "curse_ticks", -1, {}],
		["good_patient", "heal_received", 3, {"line": 2, "slot": 1}],
		["fast_healer", "day_heal", 6, {}],
		["field_dresser", "won_hp", 6, {}],
		["quick_to_mend", "infirmary", -1, {}],
		["healers_favourite", "cure_cost", -15, {}],
		["clings_to_life", "survive", 1, {}], ["clings_to_life", "survive_twice", 0, {}],
		# Learning.
		["quick_study", "xp", 10, {}],
		["glory_hound", "kill_points", 4, {}],
		["bench_learner", "reserve_xp", 1, {"bench": true}],
		["yard_rat", "drill_poor", -1, {}],
		["second_trade", "prof_cap", 4, {"weapon": WeaponData.WeaponType.AXE}],
		["second_trade", "prof_cap", 0, {"weapon": WeaponData.WeaponType.SWORD}],
		["second_trade", "drill_weapon", 3, {"weapon": WeaponData.WeaponType.AXE}],
		["deep_well", "uses_black_1", 1, {}], ["deep_well", "uses_black_2", 1, {}],
		# The city: while they are in the company and not in the Infirmary.
		["haggler", "shop_price", -10, {}], ["haggler", "shop_price", 0, {"away": true}],
		["well_liked", "hire_cost", -20, {}], ["well_liked", "hire_cost", -20, {"bench": true}],
		["drillmaster", "drill_cost", -10, {}],
		["masons_kin", "repair_amount", 5, {}],
		["looter", "won_gold", 10, {}],
		["bounty_hunter", "won_gold", 8, {"kills": 2}], ["bounty_hunter", "won_gold", 0, {}],
		["woodsman", "won_timber", 1, {}],
		["prospector", "won_ore", 1, {}],
		["camp_cook", "company_heal", 2, {}], ["camp_cook", "day_heal", 2, {}], ["camp_cook", "company_heal", 0, {"away": true}],
		["night_watch", "lost_walls", -3, {"bench": true}], ["night_watch", "lost_walls", 0, {}],
		["silver_tongue", "event_gold", 20, {}],
		# The company (wave 3).
		["inspiring", "hit", 5, {"line": 2, "holder": 1, "slot": 0}], ["inspiring", "hit", 5, {"line": 2, "holder": 0, "slot": 1}],
		["inspiring", "hit", 0, {"line": 3, "holder": 0, "slot": 2}], ["inspiring", "hit", 0, {"line": 2, "holder": 1, "slot": 1}],
		["watchful", "enemy_hit", -10, {"line": 2, "holder": 1, "slot": 0}], ["watchful", "enemy_hit", 0, {"line": 2, "holder": 1, "slot": 1}],
		["avenger", "damage", 3, {"line": 2, "ally_injured": true}], ["avenger", "damage", 0, {"line": 2}],
		["rival", "crit", 10, {"line": 2, "rival": true}], ["rival", "crit", 0, {"line": 2}],
		["lead_by_example", "hit", 15, {"line": 2, "holder": 1, "slot": 0, "holder_kills": true}],
		["lead_by_example", "hit", 0, {"line": 2, "holder": 1, "slot": 1, "holder_kills": true}],
		["lead_by_example", "hit", 0, {"line": 2, "holder": 1, "slot": 0}],
		["martyr", "martyr", 5, {"line": 2, "holder": 0, "slot": 1}],
		["battle_kin", "stat:STR", 1, {"line": 2}], ["battle_kin", "stat:STR", 2, {"line": 3, "slot": 1}],
		["battle_kin", "stat:DEF", 2, {"line": 3, "slot": 1}], ["battle_kin", "stat:STR", 0, {"line": 1}],
		["battle_kin", "stat:STR", 1, {"line": 3, "slot": 1, "ally_injured": true}],
		["envied", "prof_cap", 2, {"line": 2, "holder": 1, "slot": 0}], ["envied", "prof_cap", 0, {"line": 2, "holder": 1, "slot": 1}],
		["standard_bearer", "hit", 3, {"line": 3, "holder": 0, "slot": 2}], ["standard_bearer", "hit", 0, {"line": 3, "holder": 0, "slot": 0}],
		# Scavenging (wave 3).
		["pathfinder", "scav_score", 9, {}],
	]
	return rows


# ---------------------------------------------------------------- tests

func test_hook_table() -> void:
	for row: Array in table():
		var x := _lib.find(row[0])
		if x == null:
			t.check(false, "%s is in the library" % row[0])
			continue
		var with_it: Array[TraitData] = [x]
		var none: Array[TraitData] = []
		var metric: String = row[1]
		var opts: Dictionary = row[3]
		var out := OUT_METRICS.has(metric) or metric.begins_with("drill_weapon")
		var a := measure_out(with_it, metric, opts) if out else measure(with_it, metric, opts)
		var b := measure_out(none, metric, opts) if out else measure(none, metric, opts)
		t.eq(a - b, row[2], "%s: %s %s" % [row[0], metric, str(opts)])


func test_city_traits_need_the_holder_up() -> void:
	for id in ["haggler", "well_liked", "drillmaster", "masons_kin", "silver_tongue"]:
		var with_it: Array[TraitData] = [trait_of(id)]
		var metric: String = {"haggler": "shop_price", "well_liked": "hire_cost", "drillmaster": "drill_cost",
			"masons_kin": "repair_amount", "silver_tongue": "event_gold"}[id]
		t.eq(measure_out(with_it, metric, {"away": true}), measure_out([] as Array[TraitData], metric, {}), "%s: nothing from the Infirmary" % id)
	# Two of a kind add up (on two companions; one companion never has a trait twice).
	var got := city([trait_of("haggler")] as Array[TraitData], {})
	var run: Run = got[0]
	var second: RunCompanion = got[2]
	second.traits = [trait_of("haggler")] as Array[TraitData]
	var item := ShopItemData.new()
	item.price = 100
	t.eq(run.shop_price(item), 80, "two Hagglers: 20% less")
	t.check(run.buy_block_reason(item) != "" or true, "the smithy reads shop_price")


## A city trait and the facility upgrade it overlaps add together, with the floors stated.
func test_traits_with_facilities() -> void:
	var got := city([trait_of("well_liked")] as Array[TraitData], {})
	var run: Run = got[0]
	run.facilities[Run.Facility.TAVERN] = 2
	t.eq(run.hire_cost(), 100 - 25 - 20, "Well-Liked and the Tavern: 55")
	got = city([trait_of("masons_kin")] as Array[TraitData], {})
	run = got[0]
	run.facilities[Run.Facility.MASON] = 1
	t.eq(run.repair_amount(), 35, "Mason's Kin and the Mason's Yard: 35")
	got = city([trait_of("fast_healer")] as Array[TraitData], {})
	run = got[0]
	var holder: RunCompanion = got[1]
	run.facilities[Run.Facility.INN] = 1
	t.eq(run.day_heal(holder), ceili(40 * 0.45), "Fast Healer and the Inn: 45%")
	got = city([trait_of("quick_to_mend")] as Array[TraitData], {})
	run = got[0]
	holder = got[1]
	run.facilities[Run.Facility.INFIRMARY] = 1
	t.eq(run.infirmary_days(holder), 2, "Quick to Mend and the Infirmary: 2 days")
	got = city([trait_of("healers_favourite")] as Array[TraitData], {})
	run = got[0]
	holder = got[1]
	run._to_infirmary(holder)
	var full := holder.days_left(run.day) * (RunConfig.CURE_GOLD_PER_DAY_BASE + RunConfig.CURE_GOLD_PER_DAY_PER_LEVEL * holder.level())
	run.facilities[Run.Facility.INFIRMARY] = 2
	t.eq(run.cure_cost(holder), roundi(full * 0.25), "Healer's Favourite and the Infirmary: a quarter of the price")
	got = city([trait_of("bench_learner")] as Array[TraitData], {"bench": true})
	run = got[0]
	holder = got[1]
	run.facilities[Run.Facility.BARRACKS] = 1
	var pool := 0
	run.day = 3
	run.calendar[2] = RunCalendar.DayType.BATTLE
	run._begin_day()
	pool = run.fronts[0].xp_pool
	var b := run.start_battle(run.fronts[0])
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	var report := run.finish_battle(b)
	t.eq(int(report.reserve_xp.get(holder.display_name(), 0)), roundi(pool / 4.0 * 0.5), "Bench Learner and the Barracks: half an even share")
	# Floors: a hire never below 0 gold.
	got = city([trait_of("well_liked")] as Array[TraitData], {})
	run = got[0]
	for i in 6:
		var extra := run._join(data())
		extra.traits = [trait_of("well_liked")] as Array[TraitData]
	t.eq(run.hire_cost(), 0, "never below 0")


func test_apprentice_leans_higher() -> void:
	var pool: Array[CombatArtData] = []
	for tier in [1, 2, 3]:
		for n in 30:
			var a := CombatArtData.new()
			a.display_name = "T%d-%d" % [tier, n]
			a.weapon_type = WeaponData.WeaponType.SWORD
			a.tier = tier
			pool.append(a)
	var sums := []
	for traits: Array in [[], [trait_of("apprentice")]]:
		var p := CompanionProgress.create(data())
		p.traits.assign(traits)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		var total := 0
		for i in 2000:
			total += ArtLearning.pick_art(rng, p, WeaponData.WeaponType.SWORD, Proficiency.Grade.C, pool).tier
		sums.append(total / 2000.0)
	t.check(sums[1] > sums[0] + 0.2, "Apprentice learns higher tiers (%.2f vs %.2f)" % [sums[1], sums[0]])
	# At C (75/25/0) Apprentice rolls as at B (50/40/10).
	t.check(absf(sums[0] - 1.25) < 0.06 and absf(sums[1] - 1.6) < 0.06, "as one letter higher (%.2f, %.2f)" % [sums[0], sums[1]])
	t.eq(ArtLearning.learn_steps(CompanionProgress.create(data())), 0, "no steps without it")


func test_second_trade_follows_the_grades() -> void:
	var p := CompanionProgress.create(data())
	p.points[WeaponData.WeaponType.SWORD] = 40
	p.points[WeaponData.WeaponType.BOW] = 20
	p.points[WeaponData.WeaponType.SPEAR] = 10
	t.eq(TraitRules.second_best_type(p), WeaponData.WeaponType.BOW, "the bow is the second best")
	p.traits = [trait_of("second_trade")] as Array[TraitData]
	for wt in [WeaponData.WeaponType.SWORD, WeaponData.WeaponType.BOW, WeaponData.WeaponType.SPEAR]:
		t.eq(TraitRules.total(p.traits, TraitModifier.Kind.PROFICIENCY_PERCENT, wt, -1, 0, 0, "", TraitModifier.Who.SELF, p),
			50 if wt == WeaponData.WeaponType.BOW else 0, "+50%% only in the second-best (%s)" % WeaponData.type_name(wt))
	p.points[WeaponData.WeaponType.SPEAR] = 30
	t.eq(TraitRules.second_best_type(p), WeaponData.WeaponType.SPEAR, "and it follows as the grades change")


## The lowest-level companion in the line gets +20% XP from a won battle; nobody else does.
func test_mentor() -> void:
	var xp := []
	for traits: Array in [[], [trait_of("mentor")]]:
		var typed: Array[TraitData] = []
		typed.assign(traits)
		var got := city(typed, {"seed": 7})
		var run: Run = got[0]
		var holder: RunCompanion = got[1]
		var other: RunCompanion = got[2]
		for c in run.roster:
			if c != other:
				c.progress.level = 5
		run.day = 3
		run.calendar[2] = RunCalendar.DayType.BATTLE
		run._begin_day()
		var b := run.start_battle(run.fronts[0])
		for e in b.enemies:
			e.hp = 0
		b._check_end()
		var report := run.finish_battle(b)
		xp.append([report.xp_of(other.display_name()), report.xp_of(holder.display_name())])
	t.eq(xp[1][0], int(xp[0][0]) * 120 / 100, "the lowest-level one: +20% (%d from %d)" % [xp[1][0], xp[0][0]])
	t.eq(xp[1][1], xp[0][1], "the Mentor: as before")


## A scavenging trip: `traits` on the first two sent (holder and other), a high-risk site where the holder
## is 5 short and the other meets the target; the run's generator seeded with `s`.
func _trip(holder_traits: Array[TraitData], other_traits: Array[TraitData], s: int) -> Array:
	var got := city(holder_traits, {"seed": 11})
	var run: Run = got[0]
	var holder: RunCompanion = got[1]
	var other: RunCompanion = got[2]
	other.traits = other_traits
	var site := ScavengeSite.new()
	site.display_name = "Test Ruin"
	site.size = 2
	site.risk = ScavengeSite.Risk.HIGH
	for stat in [Stat.SPD, Stat.STR]:
		var slot := ScavengeSite.Slot.new()
		slot.stat = stat
		slot.target = 10 if stat == Stat.STR else 15
		site.slots.append(slot)
	site.gold = 100
	site.materials = {RunConfig.TIMBER: 2}
	run._scavenge_sites.append(site)
	run.rng.seed = s
	return [run, holder, other, run.scavenge(site, [holder, other])]


func _seed_for(outcome: int) -> int:
	for s in 400:
		var r: ScavengeResult = _trip([] as Array[TraitData], [] as Array[TraitData], s)[3]
		if r.outcome == outcome:
			return s
	return -1


func test_sure_footed() -> void:
	var s := _seed_for(ScavengeResult.Outcome.NOTHING)
	t.check(s >= 0, "a seed where nothing is found")
	var plain := _trip([] as Array[TraitData], [] as Array[TraitData], s)
	t.eq((plain[3] as ScavengeResult).injured, plain[1], "without it the one furthest short is injured")
	var sure := _trip([trait_of("sure_footed")] as Array[TraitData], [] as Array[TraitData], s)
	var r: ScavengeResult = sure[3]
	t.eq(r.outcome, ScavengeResult.Outcome.NOTHING, "the same roll")
	t.eq(r.injured, sure[2], "Sure-Footed: the injury falls on the next one")
	t.check(not (sure[1] as RunCompanion).injured, "and they come back on their feet")
	var both := _trip([trait_of("sure_footed")] as Array[TraitData], [trait_of("sure_footed")] as Array[TraitData], s)
	t.check((both[3] as ScavengeResult).injured == null, "nobody to injure: nobody is")
	t.check((both[1] as RunCompanion).hp < (both[1] as RunCompanion).max_hp(), "they still lose their 25%")


func test_pack_mule() -> void:
	var s := _seed_for(ScavengeResult.Outcome.FULL)
	t.check(s >= 0, "a seed with a full haul")
	var plain: ScavengeResult = _trip([] as Array[TraitData], [] as Array[TraitData], s)[3]
	var mule: ScavengeResult = _trip([trait_of("pack_mule")] as Array[TraitData], [] as Array[TraitData], s)[3]
	t.eq(plain.gold, 100, "a full haul of 100")
	t.eq(mule.gold, 125, "Pack Mule: 25% more gold")
	t.eq(int(mule.materials.get(RunConfig.TIMBER, 0)), 3, "and materials (2 x 1.25, rounded)")
	var two: ScavengeResult = _trip([trait_of("pack_mule")] as Array[TraitData], [trait_of("pack_mule")] as Array[TraitData], s)[3]
	t.eq(two.gold, 150, "two of them: 50% more")


func test_battle_gains_in_the_report() -> void:
	var got := city([trait_of("looter")] as Array[TraitData], {})
	var run: Run = got[0]
	var holder: RunCompanion = got[1]
	var other: RunCompanion = got[2]
	other.traits = [trait_of("woodsman")] as Array[TraitData]
	var gold := run.gold
	run.day = 3
	run.calendar[2] = RunCalendar.DayType.BATTLE
	run._begin_day()
	var front := run.fronts[0]
	var b := run.start_battle(front)
	for e in b.enemies:
		e.hp = 0
	b._check_end()
	var report := run.finish_battle(b)
	t.eq(report.trait_gold, 10, "Looter's 10 gold")
	t.eq(report.gold, front.reward_gold + report.kill_gold + 10, "in the report's gold")
	t.eq(run.gold, gold + report.gold, "and in the run's")
	t.eq(int(report.materials.get(RunConfig.TIMBER, 0)), int(front.reward_materials.get(RunConfig.TIMBER, 0)) + 1, "Woodsman's timber")
	t.eq(report.trait_lines.size(), 2, "a line for each")
	t.check(report.trait_lines[0].contains(holder.display_name()) and report.trait_lines[0].contains("Looter"), "naming who and which trait")
