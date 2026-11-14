extends RefCounted
## Headless tests for the rare weapons (RunContent.rare_weapons, WeaponData.rare and its property
## fields): each property in battle and in the forecast, the holding rule, and where they come from.
## Called from run_tests.gd, which owns check(), eq() and the battle helpers.

var t   # the runner (run_tests.gd)

## name -> [file, type, grade, Mt, Hit, weight, price]
const TEN := {
	"Oathkeeper": ["oathkeeper", 0, 2, 1, 90, 3, 300],
	"Twinfang Sabre": ["twinfang_sabre", 0, 4, 1, 80, 4, 280],
	"Headsman": ["headsman", 1, 4, 5, 60, 9, 280],
	"Bloodletter": ["bloodletter", 1, 2, 2, 70, 6, 180],
	"Wallbreaker": ["wallbreaker", 2, 4, 2, 75, 7, 280],
	"Sentinel's Pike": ["sentinels_pike", 2, 2, 2, 80, 6, 180],
	"Galewing Bow": ["galewing_bow", 3, 2, 1, 90, 2, 180],
	"Longwatch": ["longwatch", 3, 4, 3, 110, 5, 280],
	"Viper's Kiss": ["vipers_kiss", 4, 2, 1, 95, 1, 180],
	"Magpie": ["magpie", 4, 4, 2, 90, 2, 280],
}


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_rare_list,
		test_rare_holding_rule,
		test_oathkeeper_might,
		test_twinfang_strikes_twice,
		test_crit_bonus,
		test_bloodletter_lifesteal,
		test_wallbreaker_ignores_def,
		test_held_stats_and_aim,
		test_vipers_kiss_poisons,
		test_magpie_gold,
		test_rare_in_the_smithy,
		test_rare_from_bosses_and_events,
	]


# ---------------------------------------------------------------- helpers

func rare(file: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % file)


## A test companion with `w` in hand: STR `strength`, DEX 20 (so every strike lands), no CRT, BLD 30.
func fighter(w: WeaponData, strength: int = 10, hp: int = 50) -> CompanionData:
	var d: CompanionData = t.make_companion("Tester", hp, 0, w)
	d.strength = strength
	d.dexterity = 20
	d.speed = 5
	d.build = 30
	d.crit = 0
	d.luck = 0
	return d


func target(def: int = 0, hp: int = 500) -> EnemyData:
	var e: EnemyData = t.idle_enemy(hp)
	e.defense = def
	e.resistance = 0
	e.speed = 0
	e.luck = 0
	e.dexterity = 0
	return e


func one(e: EnemyData) -> Array[EnemyData]:
	var es: Array[EnemyData] = [e]
	return es


func cs1(d: CompanionData) -> Array[CompanionData]:
	var cs: Array[CompanionData] = [d]
	return cs


func make_run(seed_value: int) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


# ---------------------------------------------------------------- the list

func test_rare_list() -> void:
	var rc := RunContent.load_default()
	t.eq(rc.rare_weapons.size(), 14, "fourteen rare weapons: the ten and the four magic")
	for n: String in TEN:
		var row: Array = TEN[n]
		var w := rare(row[0])
		t.check(w != null and rc.rare_weapons.has(w), "%s is in the rare pool" % n)
		if w == null:
			continue
		t.eq(w.display_name, n, "%s: name" % n)
		t.check(w.rare and w.is_rare(), "%s: rare" % n)
		t.eq(w.weapon_type, row[1], "%s: type" % n)
		t.eq(w.required_grade, row[2], "%s: grade" % n)
		t.eq(w.might, row[3], "%s: Mt" % n)
		t.eq(w.hit, row[4], "%s: Hit" % n)
		t.eq(w.weight, row[5], "%s: weight" % n)
		t.eq(Run.weapon_price(w), row[6], "%s: price" % n)
		t.check(not w.trait_lines().is_empty(), "%s: a trait line: %s" % [n, str(w.trait_lines())])
		t.eq(w.effective_against.has(EnemyTraits.LARGE), w.weapon_type == WeaponData.WeaponType.SPEAR, "%s: Large if a spear" % n)
		t.eq(w.effective_against.has(EnemyTraits.FLYING), w.weapon_type == WeaponData.WeaponType.BOW, "%s: Flying if a bow" % n)
		t.check(not w.has_second_requirement(), "%s: one grade only" % n)
	for w in rc.weapons:
		t.check(not w.rare and w.trait_lines().is_empty(), "%s: a ladder weapon is not rare and has no trait lines" % w.display_name)
	for w in rc.hybrid_weapons:
		t.check(not w.rare, "%s is not rare" % w.display_name)
	t.eq(rare("twinfang_sabre").trait_lines(), ["An Attack strikes twice"] as Array[String], "Twinfang's line")
	t.eq(rare("headsman").trait_lines(), ["Crit +25"] as Array[String], "Headsman's line")
	t.eq(rare("bloodletter").trait_lines(), ["Heals the wielder for half the damage dealt"] as Array[String], "Bloodletter's line")
	t.check(rare("magpie").trait_lines()[0].contains("+10 gold"), "Magpie's line")


func test_rare_holding_rule() -> void:
	var p := CompanionProgress.create(load("res://data/companions/aina.tres"))   # sword D
	t.eq(p.weapon_block_reason(rare("oathkeeper")), "", "D holds Oathkeeper (D)")
	t.eq(p.weapon_block_reason(rare("twinfang_sabre")), "Needs sword C; Aina is D.", "not Twinfang (C)")
	p.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.C)
	t.eq(p.weapon_block_reason(rare("twinfang_sabre")), "", "the grade is all it needs")
	t.check(not p.can_equip_weapon(rare("headsman")), "an axe needs an axe grade")


# ---------------------------------------------------------------- properties

func test_oathkeeper_might() -> void:
	var oath := rare("oathkeeper")
	var expected := {Proficiency.Grade.D: 1, Proficiency.Grade.D_PLUS: 1, Proficiency.Grade.C: 2, Proficiency.Grade.B: 3,
		Proficiency.Grade.A: 4, Proficiency.Grade.A_PLUS: 4, Proficiency.Grade.S: 5}
	t.eq(oath.trait_lines()[0], "Mt grows with the wielder's sword grade (1 at D up to 5 at S)", "its line")
	var c := RunCompanion.create(fighter(oath))
	for g: int in expected:
		c.progress.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(g)
		t.eq(oath.might_for(c.progress), expected[g], "Mt at %s" % Proficiency.grade_name(g))
		t.eq(c.attack(oath), c.attack_power(oath) + int(expected[g]), "Attack at %s uses it" % Proficiency.grade_name(g))
		var b: Battle = Battle.new(cs1(c.data), one(target(2)), t.make_rng(1), [c.progress] as Array[CompanionProgress])
		t.eq(b.forecast(b.roster[0], b.enemies[0]).damage, 10 + int(expected[g]) - 2, "forecast at %s" % Proficiency.grade_name(g))
	t.eq(oath.might_for(null), oath.might, "with nobody holding it: the listed Mt")


func test_twinfang_strikes_twice() -> void:
	var tw := rare("twinfang_sabre")
	var b: Battle = t.make_battle(cs1(fighter(tw)), one(target(0)))
	var c := b.roster[0]
	var f := b.forecast(c, b.enemies[0])
	t.eq(f.strikes, 2, "the forecast shows two strikes")
	t.eq(f.hit, 100, "every strike lands here")
	t.check(b.attack(c, b.enemies[0]), "attack")
	t.eq(b.enemies[0].hp, 500 - 2 * f.damage, "two strikes of %d" % f.damage)
	t.eq(c.proficiency_gained, 1, "one Attack's proficiency")
	# An art keeps its own count.
	var art: CombatArtData = t.make_art("Cut", 1, 1, 1, 0)
	t.give_art(c, art)
	t.eq(b.forecast(c, b.enemies[0], art).strikes, 1, "an art strikes as often as it says")
	# A plain weapon: one.
	var b2: Battle = t.make_battle(cs1(fighter(t.make_weapon(3))), one(target(0)))
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0]).strikes, 1, "one strike with a plain weapon")


func test_crit_bonus() -> void:
	for pair: Array in [["headsman", 25], ["longwatch", 15]]:
		var w := rare(pair[0])
		var d := fighter(w)
		d.crit = 5
		var b: Battle = t.make_battle(cs1(d), one(target(0)))
		var c := b.roster[0]
		t.eq(b.forecast(c, b.enemies[0]).crit, BattleConfig.CRIT_CRT_FACTOR * 5 + int(pair[1]), "%s: Crit +%d on Attack" % [w.display_name, pair[1]])
		var art: CombatArtData = t.make_art("Art", 1, 1, 1, 0, w.weapon_type)
		art.crit_bonus = 5
		t.give_art(c, art)
		t.eq(b.forecast(c, b.enemies[0], art).crit, BattleConfig.CRIT_CRT_FACTOR * 5 + 5 + int(pair[1]), "%s: and on its arts" % w.display_name)


func test_bloodletter_lifesteal() -> void:
	var bl := rare("bloodletter")
	var b: Battle = t.make_battle(cs1(fighter(bl, 10, 60)), one(target(0)))
	var c := b.roster[0]
	c.hp = 20
	var dmg := b.forecast(c, b.enemies[0]).damage
	t.check(b.attack(c, b.enemies[0]), "attack")
	t.eq(c.hp, 20 + floori(dmg / 2.0), "heals half the damage dealt (%d)" % dmg)
	c.hp = c.max_hp() - 1
	c.recovery = 0
	b.attack(c, b.enemies[0])
	t.eq(c.hp, c.max_hp(), "never above max HP")


func test_wallbreaker_ignores_def() -> void:
	var wb := rare("wallbreaker")
	var b: Battle = t.make_battle(cs1(fighter(wb)), one(target(10)))
	var c := b.roster[0]
	t.eq(b.forecast(c, b.enemies[0]).damage, 10 + 2 - 5, "half of DEF 10 ignored")
	var small: CombatArtData = t.make_art("Pierce", 1, 1, 1, 0, WeaponData.WeaponType.SPEAR)
	small.ignore_def_percent = 20
	t.give_art(c, small)
	t.eq(b.forecast(c, b.enemies[0], small).damage, 10 + 2 - 5, "an art ignoring less: the weapon's half counts")
	var big: CombatArtData = t.make_art("Skewer", 1, 1, 1, 0, WeaponData.WeaponType.SPEAR)
	big.ignore_def_percent = 100
	t.give_art(c, big)
	t.eq(b.forecast(c, b.enemies[0], big).damage, 10 + 2 - 0, "an art ignoring more: the art's counts, no stacking")
	var b2: Battle = t.make_battle(cs1(fighter(t.make_weapon(5, 999, 0, WeaponData.WeaponType.SPEAR))), one(target(10)))
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0]).damage, 10 + 5 - 10, "a plain spear: all of DEF")


func test_held_stats_and_aim() -> void:
	var pike := rare("sentinels_pike")
	var plain: WeaponData = t.make_weapon(5, 999, 0, WeaponData.WeaponType.SPEAR)
	var d1 := fighter(pike)
	d1.defense = 4
	var d2 := fighter(plain)
	d2.defense = 4
	var cs: Array[CompanionData] = [d1, d2]
	var b: Battle = t.make_battle(cs, one(target(0)))
	t.eq(b.roster[0].stat(Stat.DEF), 6, "DEF +2 while held")
	t.eq(b.roster[1].stat(Stat.DEF), 4, "not for the other")
	t.eq(b.target_weights(), [1.5, 2.0] as Array[float], "1.5x as likely to be aimed at")
	var gw := rare("galewing_bow")
	var b3: Battle = t.make_battle(cs1(fighter(gw)), one(target(0)))
	t.eq(b3.roster[0].stat(Stat.SPD), 5 + 2, "SPD +2 while held")
	# Between battles the Attack figure sees the held bonuses too.
	var dg := fighter(gw)
	var rc := RunCompanion.create(dg)
	t.eq(rc.attack_power(gw), floori((dg.strength + dg.dexterity) / 2.0), "a bow's power is STR and DEX: SPD does not count")


func test_vipers_kiss_poisons() -> void:
	var vk := rare("vipers_kiss")
	var b: Battle = t.make_battle(cs1(fighter(vk)), one(target(0, 30)))
	var c := b.roster[0]
	var e := b.enemies[0]
	t.check(b.attack(c, e), "attack")
	var venom := e.get_effect("Venom")
	t.check(venom != null and venom.damage_per_tick == 1, "poisoned: 1 a turn")
	if venom != null:
		t.eq(venom.ticks_left, 2, "for 3 turns, counting the one it landed in")
	# The poison finishes it: the kill is the wielder's.
	e.hp = 1
	b._damage_over_time(e)
	t.check(not e.is_alive(), "felled by the venom")
	t.eq(b.kills_of(c), 1, "credited to the wielder")


func test_magpie_gold() -> void:
	var magpie := rare("magpie")
	for win in [true, false]:
		var run := make_run(71)
		var c := run.lineup[0]
		var owned := run.inventory.add(magpie)
		c.progress.points[WeaponData.WeaponType.DAGGER] = Proficiency.points_for(Proficiency.Grade.C)
		var old := run.inventory.held_by(c)
		owned.holder = c
		old.holder = null
		c.progress.weapon = magpie
		var f := run.fronts[0]
		var gold := run.gold
		var b := run.start_battle(f)
		b.kills[b.roster[0]] = 2
		if win:
			for e in b.enemies:
				e.hp = 0
		else:
			for u in b.roster:
				b._damage_companion(u, 9999, false)
		b._check_end()
		var r := run.finish_battle(b)
		if win:
			t.eq(r.kill_gold, 20, "two kills: 20 gold")
			t.eq(r.kill_gold_by.get(c.display_name(), 0), 20, "by the wielder")
			t.eq(r.gold, f.reward_gold + 20, "in the battle's gold")
			t.eq(run.gold, gold + f.reward_gold + 20, "paid")
		else:
			t.eq(r.kill_gold, 0, "nothing on a loss")
			t.eq(run.gold, gold, "no gold")


# ---------------------------------------------------------------- where they come from

func test_rare_in_the_smithy() -> void:
	var weeks_with := [0, 0, 0, 0, 0, 0]
	var runs := 200
	for s in runs:
		var run := make_run(7100 + s)
		for week in 6:
			run.day = week * RunConfig.WEEK_DAYS + 1
			run.shop_week.clear()
			run._stock_shop()
			var rares := run.shop_stock().filter(func(i: ShopItemData) -> bool: return i.weapon.rare)
			t.check(rares.size() <= 1, "at most one rare a week")
			t.eq(run.shop_stock().size() - rares.size(), RunConfig.SHOP_WEAPONS_PER_WEEK, "on top of the five")
			if rares.is_empty():
				continue
			weeks_with[week] += 1
			var w: WeaponData = rares[0].weapon
			t.check(w.required_grade <= Run.rare_max_grade(run.day), "week %d: %s fits the grade gate" % [week + 1, w.display_name])
			t.eq(rares[0].price, Run.weapon_price(w), "%s: its price" % w.display_name)
			t.eq(run.shop_stock()[0], rares[0], "the rare comes first")
	print("  rare weapons in the smithy by week (%d runs): %s" % [runs, str(weeks_with)])
	t.eq(weeks_with[0], 0, "none in week 1")
	for week in range(1, 6):
		var share: float = weeks_with[week] / float(runs)
		t.check(absf(share - RunConfig.SHOP_RARE_CHANCE) < 0.08, "week %d: about 35%% (%.2f)" % [week + 1, share])
	t.eq(Run.rare_max_grade(8), Proficiency.Grade.D, "week 2: grade D")
	t.eq(Run.rare_max_grade(15), Proficiency.Grade.C, "week 3: grade C")
	t.eq(RunContent.load_default().rare_pool(Proficiency.Grade.D).size(), 9, "nine rare weapons need D or less")


func test_rare_from_bosses_and_events() -> void:
	var rare14 := 0
	var rare28 := 0
	var c_at_28 := false
	var n := 120
	for s in n:
		for boss_day in [14, 28]:
			var run := make_run(7500 + s)
			run.day = boss_day
			run._begin_day()
			var b := run.start_battle(run.fronts[0])
			for e in b.enemies:
				e.hp = 0
			b._check_end()
			var w := run.finish_battle(b).weapon_found
			if w == null or not w.rare:
				continue
			if boss_day == 14:
				rare14 += 1
				t.check(w.required_grade <= Proficiency.Grade.D, "day 14: grade D or below (%s)" % w.display_name)
			else:
				rare28 += 1
				c_at_28 = c_at_28 or w.required_grade == Proficiency.Grade.C
	print("  rare boss drops: day 14 %d of %d, day 28 %d of %d" % [rare14, n, rare28, n])
	t.check(absf(rare14 / float(n) - 0.5) < 0.13 and absf(rare28 / float(n) - 0.5) < 0.13, "about half")
	t.check(c_at_28, "day 28 can drop a grade C rare")
	var armory: EventData = load("res://data/run/events/armory.tres")
	var knight: EventData = load("res://data/run/events/knight.tres")
	var rares := 0
	var tries := 0
	for s in 400:
		var run := make_run(7700 + s)
		run.day = [9, 16, 23, 30, 37][s % 5]
		run.event = armory if s % 2 == 0 else knight
		run._draw_event_weapons()
		for ch in run.event.choices:
			var w := run.choice_weapon(ch)
			if w == null or not ch.random_weapon:
				continue
			tries += 1
			if w.rare:
				rares += 1
				t.check(w.required_grade <= Run.rare_max_grade(run.day), "event rare fits the week")
				if ch.random_weapon_type >= 0:
					t.eq(w.weapon_type, ch.random_weapon_type, "and the event's type")
	print("  rare event weapons: %d of %d" % [rares, tries])
	t.check(absf(rares / float(tries) - RunConfig.EVENT_RARE_CHANCE) < 0.06, "about 15%")
	# Week 1: never.
	var early := make_run(7999)
	early.day = 2
	early.event = armory
	for i in 50:
		early._draw_event_weapons()
		for ch in early.event.choices:
			var w := early.choice_weapon(ch)
			t.check(w == null or not w.rare, "no rare from an event in week 1")
