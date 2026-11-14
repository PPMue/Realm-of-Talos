extends RefCounted
## Headless tests for traits (TraitData, TraitRules, Run._roll_traits): the library, how they are
## handed out (counts, rarity, never twice in a run, lines, two-edged, the 4-in-5 fit, offers going
## back to the pool), and a table that checks every trait in the library changes exactly the numbers
## its lines say, through the functions the screens read (the battle forecast included). Called from
## run_tests.gd, which owns check() and eq().

var t   # the runner (run_tests.gd)
var _lib: TraitLibrary

const TraitHookTests := preload("res://tests/trait_hook_tests.gd")

## The waves built (tools/generate_traits.gd BUILT_WAVE): traits by family (TraitData.Family order),
## and ids of later waves that must not be in the library yet.
const BUILT := [
	[25, 8, 11, 22, 13, 18, 12, 19, 14, 10],
	[],
]


func _init(runner: Object) -> void:
	t = runner
	_lib = TraitLibrary.load_default()


func tests() -> Array[Callable]:
	return [
		test_trait_library,
		test_traits_rolled_at_start,
		test_trait_counts_and_rarity,
		test_traits_unique_in_a_run,
		test_trait_lines_and_two_edged,
		test_trait_fit,
		test_unhired_offer_keeps_traits,
		test_hire_keeps_offer_traits,
		test_trait_table,
		test_trait_table_covers_library,
		test_apt_points_in_battle,
		test_trait_stat_bonus_shown,
	]


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


## A plain companion: HP 40, STA 30, STR 10, MAG 10, CRT 6, DEX 10, SPD 10, DEF 5, RES 5, LCK 0, BLD 10,
## every growth 40, holding a test weapon of `wt` (Mt 9, Hit 50).
func data(wt: int = WeaponData.WeaponType.SWORD) -> CompanionData:
	var c := CompanionData.new()
	c.display_name = "Tester"
	c.max_hp = 40
	c.max_sta = 30
	c.strength = 10
	c.magic = 10
	c.crit = 6
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
	w.hit = 50
	c.weapon = w
	return c


## STR 10, MAG 10, DEX 10, SPD 10, DEF 2, RES 2, LCK 0, HP 100; one action (Mt 5, Hit 50, physical
## unless `magic`) that never comes.
func enemy(traits: Array[String] = [], band: int = 1, magic: bool = false) -> EnemyData:
	var e := EnemyData.new()
	e.display_name = "Target"
	e.max_hp = 100
	e.strength = 10
	e.magic = 10
	e.crit = 0
	e.dexterity = 10
	e.speed = 10
	e.defense = 2
	e.resistance = 2
	e.luck = 0
	e.band = band
	e.traits = traits
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


func white_spell(tier: int = 1, heals: bool = true) -> SpellData:
	var s := SpellData.new()
	s.display_name = "Test Mend %d" % tier
	s.school = SpellData.School.WHITE
	s.tier = tier
	s.targeting = SpellData.Targeting.ONE_ALLY
	s.uses = 6
	s.heals = heals
	s.heal_power = 5
	var fx := StatusEffectData.new()
	fx.display_name = "Test Blessing"
	fx.stat_mods = {Stat.DEF: 1}
	fx.duration_ticks = 3
	s.effect = fx
	return s


## A battle with a line of `opts.line` (default 1) plain companions; the traits go to slot `opts.holder`
## (default: the one measured, `opts.slot`, default the front). Returns the measured value of `metric`.
func measure(traits: Array[TraitData], metric: String, opts: Dictionary) -> int:
	var line: int = opts.get("line", 1)
	var slot: int = opts.get("slot", line - 1)
	var holder: int = opts.get("holder", slot)
	var wt: int = opts.get("weapon", WeaponData.WeaponType.SWORD)
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for i in line:
		var d := data(wt)
		datas.append(d)
		var p := CompanionProgress.create(d)
		if i == holder:
			p.traits = traits
			p.accessories = opts.get("wear", [])   # accessories worn (accessory_tests.gd)
		party.append(p)
	var et: Array[String] = []
	et.assign(opts.get("enemy_traits", []))
	var es: Array[EnemyData] = [enemy(et, opts.get("band", 1), opts.get("enemy_magic", false))]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var b := Battle.new(datas, es, rng, party)
	b.elite = opts.get("elite", false)
	var u := b.roster[slot]
	var e := b.enemies[0]
	var other := EnemyUnit.new(enemy())
	u.actions_taken = opts.get("actions", 0)
	u.front_actions = opts.get("front_actions", 0)
	u.after_guard_or_focus = opts.get("after_guard", false)
	if opts.get("enemy_half", false):
		e.hp = 40
	if opts.get("self_low", false):
		u.hp = 1
	match opts.get("struck", ""):
		"this":
			u.last_struck_id = e.get_instance_id()
		"other":
			u.last_struck_id = other.get_instance_id()
		"hit_by":
			u.last_hit_by_id = e.get_instance_id()
		"since":
			u.struck_since.append(e.get_instance_id())
	if opts.get("others_injured", false):
		for c in b.roster:
			if c != u:
				c.state = CompanionUnit.State.INJURED
				c.hp = 0
	if opts.get("guarding", false):
		u.add_effect(StatusEffect.guard())
	var art := CombatArtData.new()
	art.display_name = "Test Cut"
	art.weapon_type = wt
	art.stamina_cost = 5
	art.might_bonus = 2
	u.progress.learn(art)
	var action := e.pending_action
	match metric:
		"hit":
			return b.forecast(u, e).hit
		"crit":
			return b.forecast(u, e).crit
		"damage":
			return b.forecast(u, e).damage
		"art_hit":
			return b.forecast(u, e, art).hit
		"art_damage":
			return b.forecast(u, e, art).damage
		"art_cost":
			return b.art_cost(u, art)
		"spell_hit":
			return b.spell_forecast(u, black_spell(), e).hit
		"spell_damage":
			return b.spell_forecast(u, black_spell(), e).damage
		"enemy_hit":
			return b.enemy_forecast(e, action, u).hit
		"taken":
			return b.enemy_forecast(e, action, u).damage
		"taken_all":
			return b.enemy_forecast(e, action, u, true).damage
		"aim":
			return roundi(b.target_weights()[slot] * 100.0)
		"max_sta":
			return u.max_stamina()
		"heal_given":
			return b.heal_amount(u, white_spell())
		"heal_received":
			var healer := b.roster[0] if b.roster[0] != u else b.roster[-1]
			return b.heal_amount_on(healer, white_spell(), u)
		"uses_black_1":
			return u.progress.max_uses(black_spell(1))
		"uses_black_2":
			return u.progress.max_uses(black_spell(2))
		"uses_white_1":
			return u.progress.max_uses(white_spell(1))
		"blessing":
			var s := white_spell(1, false)
			u.progress.learn_spell(s)
			b.cast(u, s, u)
			var fx := u.get_effect("Test Blessing")
			return fx.ticks_left if fx != null else -1
		"magic_black", "magic_white":
			var s := black_spell() if metric == "magic_black" else white_spell(1, false)
			var school := s.school
			u.progress.learn_spell(s)
			var before := u.progress.magic_points_in(school)
			b.cast(u, s, e if s.school == SpellData.School.BLACK else u)
			return u.progress.magic_points_in(school) - before
		"prof_cap":
			return b.proficiency_cap(u, wt)
	if metric.begins_with("stat:"):
		return u.stat(metric.substr(5))
	t.check(false, "unknown metric %s" % metric)
	return 0


## Out of a battle: `metric` for a companion of the test data with `traits`.
func measure_out(traits: Array[TraitData], metric: String, opts: Dictionary) -> int:
	var d := data(opts.get("weapon", WeaponData.WeaponType.SWORD))
	var c := RunCompanion.create(d)
	c.traits = traits
	c.progress.accessories = opts.get("wear", [])
	var run: Run = _run()
	if metric.begins_with("plain:"):
		return int(c.progress.stats()[metric.substr(6)])
	if metric.begins_with("growth:"):
		var parts := metric.split(":")
		return Levels.growth_rate_of(c.progress, parts[1], int(parts[2]))
	match metric:
		"max_hp":
			return c.max_hp()
		"xp":
			return Levels.with_traits(c.progress, 100)
		"infirmary":
			return run.infirmary_days(c)
		"day_heal":
			return run.day_heal(c)
		"drill_weapon":
			return run.drill_points(Drill.weapon(opts.get("weapon", WeaponData.WeaponType.SWORD)), c, DrillResult.Quality.GOOD)
		"drill_magic":
			return run.drill_points(Drill.magic(opts.get("school", SpellData.School.BLACK)), c, DrillResult.Quality.GOOD)
	t.check(false, "unknown metric %s" % metric)
	return 0


var _the_run: Run


func _run() -> Run:
	if _the_run == null:
		_the_run = make_run(1)
	return _the_run


const OUT_METRICS := ["max_hp", "xp", "infirmary", "day_heal", "drill_weapon", "drill_magic"]


## [trait id, metric, change, options]. Each row: the metric with the trait minus without it.
func table() -> Array:
	var rows: Array = []
	var weapons := ["sword", "axe", "spear", "bow", "dagger"]
	for wt in 5:
		var w := {"weapon": wt}
		var other := {"weapon": (wt + 1) % 5}
		var n: String = weapons[wt]
		rows.append_array([
			["%s_sure" % n, "hit", 10, w], ["%s_sure" % n, "art_hit", 10, w], ["%s_sure" % n, "hit", 0, other],
			["%s_sure" % n, "spell_hit", 0, w],
			["%s_heavy" % n, "damage", 2, w], ["%s_heavy" % n, "art_damage", 2, w], ["%s_heavy" % n, "damage", 0, other],
			["%s_keen" % n, "crit", 8, w], ["%s_keen" % n, "crit", 0, other],
			["%s_easy" % n, "art_cost", -1, w], ["%s_easy" % n, "art_cost", 0, other],
			["%s_apt" % n, "prof_cap", 4, w], ["%s_apt" % n, "prof_cap", 0, other], ["%s_apt" % n, "drill_weapon", 3, w],
			["%s_apt" % n, "drill_weapon", 0, other],
		])
	rows.append_array([
		["black_sure", "spell_hit", 10, {}], ["black_sure", "hit", 0, {}],
		["black_heavy", "spell_damage", 2, {}], ["black_heavy", "damage", 0, {}],
		["black_deep", "uses_black_1", 1, {}], ["black_deep", "uses_black_2", 0, {}], ["black_deep", "uses_white_1", 0, {}],
		["black_apt", "magic_black", 2, {}], ["black_apt", "drill_magic", 3, {"school": SpellData.School.BLACK}],
		["black_apt", "drill_magic", 0, {"school": SpellData.School.WHITE}],
		["white_kind", "heal_given", 3, {}],
		["white_lasting", "blessing", 1, {}],
		["white_deep", "uses_white_1", 1, {}], ["white_deep", "uses_black_1", 0, {}],
		["white_apt", "magic_white", 2, {}], ["white_apt", "drill_magic", 3, {"school": SpellData.School.WHITE}],
		# Body and mind: the stat in battle and on the sheet.
		["hale", "stat:HP", 4, {}], ["hale", "max_hp", 4, {}], ["hale", "plain:HP", 4, {}],
		["deep_winded", "max_sta", 3, {}], ["strong", "stat:STR", 2, {}], ["strong", "damage", 2, {}],
		["bright", "stat:MAG", 2, {}], ["bright", "spell_damage", 2, {}], ["deft", "stat:DEX", 2, {}], ["deft", "hit", 10, {}],
		["fleet", "stat:SPD", 2, {}], ["fleet", "enemy_hit", -10, {}], ["hardy", "stat:DEF", 2, {}], ["hardy", "taken", -2, {}],
		["warded", "stat:RES", 2, {}], ["sharp_eyed", "stat:CRT", 3, {}], ["sharp_eyed", "crit", 6, {}],
		["lucky", "stat:LCK", 4, {}], ["broad", "stat:BLD", 2, {}], ["broad", "plain:BLD", 2, {}],
		# Two-edged.
		["reckless", "hit", 10, {}], ["reckless", "enemy_hit", 10, {}],
		["wary", "enemy_hit", -10, {}], ["wary", "hit", -5, {}],
		["wild_swing", "crit", 15, {}], ["wild_swing", "hit", -10, {}],
		["measured", "hit", 10, {}], ["measured", "crit", -10, {}],
		["brittle_fury", "stat:STR", 3, {}], ["brittle_fury", "stat:DEF", -3, {}],
		["stone_footed", "stat:DEF", 3, {}], ["stone_footed", "stat:SPD", -2, {}],
		["scholars_frame", "stat:MAG", 3, {}], ["scholars_frame", "max_hp", -4, {}],
		["ox", "stat:STR", 2, {}], ["ox", "stat:BLD", 2, {}], ["ox", "stat:DEX", -2, {}],
		["whip_thin", "stat:SPD", 3, {}], ["whip_thin", "stat:BLD", -2, {}],
		["hothead", "damage", 3, {}], ["hothead", "art_damage", 0, {}], ["hothead", "art_cost", 1, {}],
		["thrifty", "art_cost", -1, {}], ["thrifty", "art_damage", -1, {}], ["thrifty", "damage", 0, {}],
		["proud", "stat:DEF", 2, {"line": 2, "slot": 1}], ["proud", "stat:RES", 2, {"line": 2, "slot": 1}],
		["proud", "stat:DEF", -2, {"line": 2, "slot": 0}], ["proud", "stat:RES", -2, {"line": 2, "slot": 0}],
		["proud", "plain:DEF", 0, {}],
		["shy", "hit", 10, {"line": 2, "slot": 0}], ["shy", "crit", 10, {"line": 2, "slot": 0}],
		["shy", "hit", -10, {"line": 2, "slot": 1}], ["shy", "crit", -10, {"line": 2, "slot": 1}],
		["shy", "hit", 0, {"line": 3, "slot": 1}],
		["slow_starter", "hit", -10, {"actions": 0}], ["slow_starter", "hit", 0, {"actions": 1}],
		["slow_starter", "hit", 0, {"actions": 2}], ["slow_starter", "hit", 10, {"actions": 3}], ["slow_starter", "hit", 10, {"actions": 7}],
		["sprinter", "stat:SPD", 2, {"actions": 0}], ["sprinter", "hit", 10, {"actions": 2}],
		["sprinter", "stat:SPD", 0, {"actions": 3}], ["sprinter", "hit", 0, {"actions": 3}], ["sprinter", "max_sta", -3, {}],
		["thin_blooded", "xp", 15, {}], ["thin_blooded", "infirmary", 1, {}],
		["daredevil", "crit", 20, {"self_low": true}], ["daredevil", "crit", 0, {}], ["daredevil", "day_heal", -4, {}],
		["showy", "crit", 10, {}], ["showy", "aim", 50, {}],
		["skulker", "aim", -40, {}], ["skulker", "crit", -5, {}],
		["glutton_for_blows", "max_hp", 4, {}], ["glutton_for_blows", "stat:DEF", 1, {}],
		["glutton_for_blows", "stat:SPD", -2, {}], ["glutton_for_blows", "aim", 30, {}],
		["faithless", "stat:RES", 3, {}], ["faithless", "heal_received", -3, {"line": 2, "slot": 1}],
		["single_minded", "hit", 15, {"struck": "this"}], ["single_minded", "hit", -5, {"struck": "other"}],
		["single_minded", "hit", 0, {}],
		# The line.
		["vanguard", "stat:DEF", 2, {"line": 2, "slot": 1}], ["vanguard", "stat:RES", 2, {"line": 2, "slot": 1}],
		["vanguard", "stat:DEF", 0, {"line": 2, "slot": 0}],
		["rearguard", "hit", 10, {"line": 2, "slot": 0}], ["rearguard", "hit", 0, {"line": 2, "slot": 1}],
		["anchor", "taken", -1, {"line": 3, "holder": 1, "slot": 0}], ["anchor", "taken", -1, {"line": 3, "holder": 1, "slot": 2}],
		["anchor", "taken", 0, {"line": 3, "holder": 0, "slot": 1}], ["anchor", "taken", 0, {"line": 3, "holder": 1, "slot": 1}],
		["shieldmate", "taken", -2, {"line": 2, "holder": 1, "slot": 0}], ["shieldmate", "taken", 0, {"line": 2, "holder": 0, "slot": 1}],
		["file_leader", "hit", 5, {"line": 2, "holder": 1, "slot": 0}], ["file_leader", "hit", 0, {"line": 2, "holder": 0, "slot": 1}],
		["file_leader", "hit", 0, {"line": 2, "holder": 1, "slot": 1}],
		["looming", "aim", 50, {}], ["unseen", "aim", -40, {}],
		["lone_blade", "stat:STR", 2, {"line": 2}], ["lone_blade", "stat:DEX", 2, {"line": 2}], ["lone_blade", "stat:STR", 0, {"line": 3}],
		["full_rank", "hit", 5, {"line": 4}], ["full_rank", "hit", 0, {"line": 3}],
		["last_stand", "stat:STR", 3, {"line": 2, "others_injured": true}], ["last_stand", "stat:DEF", 3, {"line": 2, "others_injured": true}],
		["last_stand", "stat:STR", 0, {"line": 2}],
		["wall", "taken", -2, {"guarding": true}], ["wall", "taken", 0, {}],
		["sidestep", "taken_all", -3, {}], ["sidestep", "taken", 0, {}],
		["front_runner", "hit", 50, {"line": 2, "slot": 1}], ["front_runner", "spell_hit", 50, {}],
		["front_runner", "hit", 0, {"line": 2, "slot": 1, "front_actions": 1}], ["front_runner", "hit", 0, {"line": 2, "slot": 0}],
		# Tempo.
		["first_blood", "hit", 20, {"actions": 0}], ["first_blood", "damage", 3, {"actions": 0}],
		["first_blood", "hit", 0, {"actions": 1}], ["first_blood", "damage", 0, {"actions": 1}],
		["patient", "hit", 15, {"after_guard": true}], ["patient", "damage", 2, {"after_guard": true}], ["patient", "hit", 0, {}],
		["closer", "damage", 3, {"enemy_half": true}], ["closer", "damage", 0, {}],
		["opener", "damage", 3, {}], ["opener", "damage", 0, {"enemy_half": true}],
		["giant_bane", "damage", 3, {"enemy_traits": [EnemyTraits.LARGE]}], ["giant_bane", "damage", 0, {}],
		["fowler", "hit", 15, {"enemy_traits": [EnemyTraits.FLYING]}], ["fowler", "hit", 0, {}],
		["spell_breaker", "damage", 3, {"enemy_magic": true}], ["spell_breaker", "damage", 0, {}],
		["grudge", "damage", 3, {"struck": "hit_by"}], ["grudge", "damage", 0, {}],
		["counter_eye", "hit", 15, {"struck": "since"}], ["counter_eye", "hit", 0, {"struck": "hit_by"}],
		["kingslayer", "damage", 1, {"band": 0}], ["kingslayer", "damage", 0, {}],
	])
	for row in [["hp", Stat.HP], ["stamina", Stat.STA], ["strength", Stat.STR], ["magic", Stat.MAG], ["dexterity", Stat.DEX],
			["speed", Stat.SPD], ["defence", Stat.DEF], ["resistance", Stat.RES], ["critical", Stat.CRT], ["luck", Stat.LCK]]:
		var id := "growing_%s" % ("health" if row[0] == "hp" else row[0])
		rows.append(["%s" % id, "growth:%s:5" % row[1], 15, {}])
		rows.append(["%s" % id, "growth:%s:5" % (Stat.STR if row[1] != Stat.STR else Stat.DEX), 0, {}])
	rows.append_array([
		["early_bloomer", "growth:STR:2", 10, {}], ["early_bloomer", "growth:LCK:8", 10, {}],
		["early_bloomer", "growth:STR:9", -5, {}], ["early_bloomer", "growth:BLD:2", 0, {}],
		["late_bloomer", "growth:STR:8", -5, {}], ["late_bloomer", "growth:STR:9", 10, {}], ["late_bloomer", "growth:HP:15", 10, {}],
	])
	return rows


# ---------------------------------------------------------------- tests

func test_trait_library() -> void:
	t.check(_lib != null, "the library loads")
	var total := 0
	for n: int in BUILT[0]:
		total += n
	t.eq(_lib.traits.size(), total, "the waves built: %d traits" % total)
	var ids := {}
	var by_family := {}
	for x in _lib.traits:
		t.check(not ids.has(x.id), "%s once" % x.id)
		ids[x.id] = true
		by_family[x.family] = by_family.get(x.family, 0) + 1
		t.check(not x.lines().is_empty(), "%s says what it gives" % x.id)
		t.eq(x.drawback_lines().is_empty(), not x.is_two_edged(), "%s: a drawback only if two-edged" % x.id)
		t.check(not x.modifiers.is_empty(), "%s does something" % x.id)
		t.check(x.rarity_name() != "" and x.display_name != "", "%s named" % x.id)
	for f in TraitData.Family.values():
		t.eq(by_family.get(f, 0), BUILT[0][f], "%s: %d" % [TraitData.FAMILY_NAMES[f], BUILT[0][f]])
	# Later waves stay out.
	for later_id: String in BUILT[1]:
		t.check(_lib.find(later_id) == null, "%s is not handed out before its wave" % later_id)
	t.eq(trait_of("axe_sure").lines(), ["+10 Hit with axes"] as Array[String], "worded as in the design")
	t.eq(trait_of("reckless").drawback_lines(), ["Avoid -10"] as Array[String], "and its drawback")
	t.eq(trait_of("kingslayer").rarity, TraitData.Rarity.RARE, "Kingslayer is rare")
	t.eq(trait_of("hale").rarity, TraitData.Rarity.COMMON, "Hale is common")
	t.eq(trait_of("ox").rarity, TraitData.Rarity.UNCOMMON, "Ox is uncommon")


func test_traits_rolled_at_start() -> void:
	for s in 30:
		var run := make_run(700 + s)
		for c in run.roster:
			t.check(c.traits.size() >= 1 and c.traits.size() <= 3, "1-3 traits")
			t.eq(c.hp, c.max_hp(), "starts at full HP, traits included")
			t.eq(c.progress.traits, c.traits, "the same list in their progress")
		for d in run.tavern_offers:
			var o := run.offer_traits(d)
			t.check(o.size() >= 1 and o.size() <= 3, "an offer shows 1-3 traits")
		t.check(run.offer_traits(CompanionData.new()).is_empty(), "nobody else has offer traits")


func test_trait_counts_and_rarity() -> void:
	var run := make_run(5)
	var d: CompanionData = run.content.companions[0]
	var counts := [0, 0, 0, 0]
	var rarity := [0, 0, 0]
	var rolls := 4000
	for i in rolls:
		run._traits_taken.clear()
		var got := run._roll_traits(CompanionProgress.create(d))
		counts[got.size()] += 1
		rarity[got[0].rarity] += 1
	t.check(absf(counts[1] / float(rolls) - 0.75) < 0.03, "one trait about 75%% (%d)" % counts[1])
	t.check(absf(counts[2] / float(rolls) - 0.22) < 0.03, "two about 22%% (%d)" % counts[2])
	t.check(absf(counts[3] / float(rolls) - 0.03) < 0.012, "three about 3%% (%d)" % counts[3])
	var n := [0, 0, 0]
	for x in run.trait_pool:
		n[x.rarity] += 1
	var total: float = 10.0 * n[0] + 5.0 * n[1] + 1.0 * n[2]
	for k in 3:
		var want: float = [10.0, 5.0, 1.0][k] * n[k] / total
		t.check(absf(rarity[k] / float(rolls) - want) < 0.03, "%s drawn as weighted (%.3f vs %.3f)" % [
			TraitData.RARITY_NAMES[k], rarity[k] / float(rolls), want])
	t.eq(RunConfig.TRAIT_COUNT_WEIGHTS, [75, 22, 3] as Array[int], "75 / 22 / 3")
	t.eq(RunConfig.TRAIT_RARITY_WEIGHTS, [10, 5, 1] as Array[int], "10 / 5 / 1")


func test_traits_unique_in_a_run() -> void:
	for s in 20:
		var run := make_run(900 + s)
		run.gold = 100000
		for week in 6:
			var seen := {}
			var people: Array = []
			for c in run.roster:
				people.append(c.traits)
			for d in run.tavern_offers:
				people.append(run.offer_traits(d))
			for list: Array in people:
				for x: TraitData in list:
					t.check(not seen.has(x), "seed %d week %d: %s only once" % [s, week, x.id])
					seen[x] = true
			for x: TraitData in seen:
				t.check(run._traits_taken.has(x), "taken from the pool")
			if not run.tavern_offers.is_empty():
				run.day = 2
				run.calendar[1] = RunCalendar.DayType.FREE
				run.event_days.erase(2)
				run._begin_day()
				run.hire(run.tavern_offers[0])
			run._restock_week()


func test_trait_lines_and_two_edged() -> void:
	var run := make_run(6)
	var d: CompanionData = run.content.companions[3]
	var threes := 0
	for i in 3000:
		run._traits_taken.clear()
		var got := run._roll_traits(CompanionProgress.create(d))
		var lines := {}
		var edged := 0
		for x in got:
			t.check(not lines.has(x.line_key()), "never two of one line (%s)" % x.id)
			lines[x.line_key()] = true
			if x.is_two_edged():
				edged += 1
		t.check(edged <= 1, "never two two-edged")
		if got.size() == 3:
			threes += 1
	t.check(threes > 0, "some had three")
	t.eq(trait_of("sword_sure").line_key(), trait_of("axe_sure").line_key(), "Sword: Sure and Axe: Sure share a line")
	t.check(trait_of("sword_sure").line_key() != trait_of("sword_heavy").line_key(), "Sword: Sure and Sword: Heavy do not")
	t.eq(trait_of("growing_strength").line_key(), trait_of("growing_speed").line_key(), "the Growing traits share one")


func test_trait_fit() -> void:
	var run := make_run(7)
	# A swordsman: only sword is above E.
	var d := data(WeaponData.WeaponType.SWORD)
	d.start_grade_sword = Proficiency.Grade.D
	var p := CompanionProgress.create(d)
	var tied := 0
	var fits := 0
	for i in 6000:
		run._traits_taken.clear()
		for x in run._roll_traits(p):
			if x.is_tied():
				tied += 1
				if Run._trait_fits(x, p):
					fits += 1
	var share := fits / float(maxi(1, tied))
	# 4 in 5 go to someone who can use it; the fifth lands anywhere (a sword trait 5 times in 33).
	t.check(share > 0.78 and share < 0.89, "about 4 in 5 tied traits fit (%.3f of %d)" % [share, tied])
	t.check(fits < tied, "and some land on someone who cannot use them yet")
	t.eq(RunConfig.TRAIT_FIT_PERCENT, 80, "4 in 5")
	t.check(Run._trait_fits(trait_of("sword_keen"), p) and not Run._trait_fits(trait_of("axe_keen"), p), "fit is a grade above E")
	t.check(not Run._trait_fits(trait_of("black_sure"), p), "a fighter does not fit a school")
	t.check(Run._trait_fits(trait_of("hale"), p), "an untied trait fits anyone")


## Traits are rolled once a run: someone offered at the tavern and not hired keeps theirs, out of the
## pool, and shows the same ones when offered again, without a new roll.
func test_unhired_offer_keeps_traits() -> void:
	var run := make_run(8)
	var first: Dictionary = {}   # CompanionData -> the traits shown the first time
	var reoffers := 0
	var taken_before := -1   # the pool's taken count when the last week ended
	for week in 12:
		var fresh := 0
		for d in run.tavern_offers:
			var shown := run.offer_traits(d)
			t.check(shown.size() >= 1 and shown.size() <= 3, "week %d: an offer shows 1-3 traits" % week)
			if first.has(d):
				t.eq(shown, first[d], "week %d: %s shows the same traits again" % [week, d.display_name])
				reoffers += 1
			else:
				first[d] = shown
				fresh += shown.size()
		for d: CompanionData in first:
			for x: TraitData in first[d]:
				t.check(run._traits_taken.has(x), "week %d: %s stays out of the pool" % [week, x.id])
				if not run.tavern_offers.has(d):
					t.check(run.offer_traits(d).is_empty(), "week %d: not offered, no offer traits" % week)
		if taken_before >= 0:
			t.eq(run._traits_taken.size(), taken_before + fresh, "week %d: only first-time offers take traits" % week)
		# Nobody else carries them meanwhile: every list seen so far, the roster's and the offers', disjoint.
		var seen := {}
		var lists: Array = first.values()
		for c in run.roster:
			lists.append(c.traits)
		for list: Array in lists:
			for x: TraitData in list:
				t.check(not seen.has(x), "week %d: %s on one person only" % [week, x.id])
				seen[x] = true
		taken_before = run._traits_taken.size()
		run._restock_week()   # the week ends, nobody hired
	t.check(reoffers > 0, "someone was offered again (%d)" % reoffers)
	# A re-offer rolls nothing: the generator is where it was.
	run = make_run(81)
	var d: CompanionData = run.tavern_offers[0]
	var shown := run.offer_traits(d)
	run.tavern_offers.erase(d)
	var state := run.rng.state
	var taken := run._traits_taken.size()
	run._offer(d)
	t.eq(run.rng.state, state, "offered again: no rolls")
	t.eq(run._traits_taken.size(), taken, "and nothing more taken")
	t.eq(run.offer_traits(d), shown, "the same traits")
	# Hired after a week unhired: they keep them.
	run.gold = 100000
	run.day = 2
	run.calendar[1] = RunCalendar.DayType.FREE
	run.event_days.erase(2)
	run._begin_day()
	run.tavern_offers.erase(d)
	run._offer(d)
	var c := run.hire(d)
	t.check(c != null, "hired")
	t.eq(c.traits, shown, "hired later, the traits first shown")
	t.check(run.offer_traits(d).is_empty(), "no longer offered")


func test_hire_keeps_offer_traits() -> void:
	var run := make_run(9)
	run.day = 2
	run.calendar[1] = RunCalendar.DayType.FREE
	run.event_days.erase(2)
	run._begin_day()
	run.gold = 1000
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	var d: CompanionData = run.tavern_offers[0]
	var shown := run.offer_traits(d)
	var c := run.hire(d)
	t.eq(c.traits, shown, "the hire has the traits shown")
	t.eq(c.hp, c.max_hp(), "at full HP")
	run._restock_week()
	for x in shown:
		t.check(run._traits_taken.has(x), "a hire's traits stay out of the pool")


func test_trait_table() -> void:
	for row: Array in table():
		var x := trait_of(row[0])
		if x == null:
			continue
		var with_it: Array[TraitData] = [x]
		var none: Array[TraitData] = []
		var metric: String = row[1]
		var opts: Dictionary = row[3]
		var out := OUT_METRICS.has(metric) or metric.begins_with("growth:") or metric.begins_with("plain:")
		var a := measure_out(with_it, metric, opts) if out else measure(with_it, metric, opts)
		var b := measure_out(none, metric, opts) if out else measure(none, metric, opts)
		t.eq(a - b, row[2], "%s: %s %s" % [row[0], metric, str(opts)])


func test_trait_table_covers_library() -> void:
	var covered := {}
	for row: Array in table():
		covered[row[0]] = true
	for id: String in TraitHookTests.covered_ids():
		covered[id] = true
	for x in _lib.traits:
		t.check(covered.has(x.id), "%s is in the table" % x.id)


func test_apt_points_in_battle() -> void:
	# +50% weapon points: two attacks give 3 points (1, then 1.5 + 0.5), the battle's cap is 12.
	for traits: Array in [[], [trait_of("sword_apt")]]:
		var d := data()
		var p := CompanionProgress.create(d)
		p.traits.assign(traits)
		var datas: Array[CompanionData] = [d]
		var party: Array[CompanionProgress] = [p]
		var es: Array[EnemyData] = [enemy()]
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var b := Battle.new(datas, es, rng, party)
		var before := p.points_in(WeaponData.WeaponType.SWORD)
		b.attack(b.roster[0], b.enemies[0])
		b.attack(b.roster[0], b.enemies[0])
		t.eq(p.points_in(WeaponData.WeaponType.SWORD) - before, 3 if not traits.is_empty() else 2, "two attacks: %d traits" % traits.size())


func test_trait_stat_bonus_shown() -> void:
	var c := RunCompanion.create(data())
	c.traits = [trait_of("ox"), trait_of("hale")] as Array[TraitData]
	t.eq(c.progress.trait_stat_bonus(Stat.STR), 2, "STR from traits")
	t.eq(c.progress.trait_stat_bonus(Stat.DEX), -2, "DEX from traits")
	t.eq(c.progress.trait_stat_bonus(Stat.HP), 4, "HP from traits")
	t.eq(c.progress.trait_stat_bonus(Stat.DEF), 0, "nothing else")
	t.eq(int(c.progress.stats()[Stat.STR]), 12, "in the stats the barracks shows")
	t.eq(c.max_hp(), 44, "and max HP")
	t.eq(c.attack(), 12 + 9, "and the Attack (STR + Mt for a sword)")
	c.traits = [trait_of("proud")] as Array[TraitData]
	t.eq(c.progress.trait_stat_bonus(Stat.DEF), 0, "a bonus that needs a place in the line is not on the sheet")
	# Art costs as the barracks would read them.
	var art := CombatArtData.new()
	art.weapon_type = WeaponData.WeaponType.SWORD
	art.stamina_cost = 5
	for row in [["sword_easy", 4], ["axe_easy", 5], ["hothead", 6], ["thrifty", 4]]:
		c.traits = [trait_of(row[0])] as Array[TraitData]
		t.eq(c.progress.art_cost(art), row[1], "%s: the art costs %d" % row)
	# Growth rates as the sheet would read them.
	c.traits = [trait_of("growing_luck")] as Array[TraitData]
	t.eq(Levels.growth_rate_of(c.progress, Stat.LCK), 55, "40 + 15")
	t.eq(Levels.growth_rate(c.data, Stat.LCK), 40, "the companion's own")
	# A level-up rolls with the traits: at 100% every roll rises.
	var d := data()
	var g := {}
	for key in Levels.GROWTH_STATS:
		g[key] = 0
	g[Stat.LCK] = 85
	d.growths = g
	var p := CompanionProgress.create(d)
	p.traits = [trait_of("growing_luck")] as Array[TraitData]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 10:
		t.check(Levels.level_up(p, rng).has(Stat.LCK), "LCK at 100% rises every time")
