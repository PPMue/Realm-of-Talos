extends RefCounted
## Headless tests for the weapon rules: starting health and stamina, Focus, the six-tier weapon ladder,
## attack power by weapon type, effectiveness (+50%), the Large trait, and where weapons come from (the
## smithy's weekly stock, events, bosses). Also prints damage by weapon type and tier against typical
## enemies at levels 1, 6 and 12.
## Called from run_tests.gd, which owns check(), eq() and the battle helpers.

var t   # the runner (run_tests.gd)

const TYPES := ["sword", "axe", "spear", "bow", "dagger"]
const TIERS := ["wooden", "bronze", "iron", "steel", "silver", "platinum"]
## Mt by type (rows: sword, axe, spear, bow, dagger) and tier (wooden ... platinum), as approved.
const MIGHT_TABLE := [
	[0, 1, 2, 3, 4, 5],
	[0, 1, 2, 3, 5, 6],
	[1, 2, 3, 4, 5, 6],
	[0, 1, 2, 3, 4, 5],
	[0, 1, 2, 3, 4, 5],
]
## Hit and weight by type and tier, as approved: steel no worse than iron and silver, bows at 90.
const HIT_TABLE := [
	[90, 90, 90, 90, 90, 95],
	[80, 80, 80, 80, 85, 85],
	[85, 85, 85, 85, 85, 90],
	[90, 90, 90, 90, 90, 90],
	[95, 95, 95, 95, 95, 100],
]
const WEIGHT_TABLE := [
	[2, 3, 4, 5, 5, 5],
	[5, 6, 7, 7, 7, 7],
	[4, 5, 5, 6, 6, 6],
	[2, 3, 3, 4, 4, 4],
	[1, 2, 2, 2, 2, 2],
]
## Health before this change, to check every companion kept their standing.
const OLD_HP := {"Elena": 30, "Asterion": 29, "Ingrid": 27, "Aina": 26, "Shiro": 25, "Sylas": 24,
	"Raizen": 23, "Kaito": 22, "Erik": 22, "Aveline": 22, "Yuzu": 21, "Freya": 20, "Koharu": 19, "Elio": 17}
## Two-proficiency families: name, main type, second (["t", WeaponType] or ["s", SpellData.School]).
const FAMILIES := [
	["Halberd", 1, ["t", 2]],
	["Glaive", 2, ["t", 0]],
	["Greatsword", 0, ["t", 1]],
	["Twinblades", 4, ["t", 0]],
	["Javelin", 2, ["t", 3]],
	["Runeblade", 0, ["s", 0]],
]
## Prices of a two-proficiency weapon at bronze, iron, steel, silver: tier price x 1.25, rounded to 5.
const HYBRID_PRICES := [65, 140, 250, 400]
const LARGE_ENEMIES := ["orc", "minotaur", "ancient_treant", "armored_beast", "cursed_dweller"]
const LARGE_BOSSES := ["mossback_troll", "rampart_golem", "horned_tyrant"]


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_starting_health_and_stamina,
		test_strength_and_magic_stand_close,
		test_focus_pays_for_a_tier_one_art,
		test_weapon_ladder,
		test_rare_magic_weapons_on_the_ladder,
		test_attack_power_by_type,
		test_attack_power_after_weight_and_effects,
		test_attack_power_in_forecasts,
		test_run_companion_attack,
		test_effective_adds_half_before_crit,
		test_effective_with_guard_and_minimum,
		test_large_trait,
		test_spears_effective_against_large,
		test_weekly_stock_tiers,
		test_stock_is_five_different_weapons,
		test_event_weapon_fits_the_week,
		test_boss_drops_a_weapon,
		test_damage_by_weapon_type_table,
		test_hybrid_families,
		test_hybrid_holding,
		test_hybrid_counts_as_main_type,
		test_runeblade_uses_mag,
		test_smithy_stocks_hybrids,
		test_hybrid_reach,
		test_art_costs_by_type,
	]


# ---------------------------------------------------------------- helpers

func content() -> RunContent:
	return RunContent.load_default()


func make_run(seed_value: int) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


func target(def: int, res: int = 0, traits: Array[String] = []) -> EnemyData:
	var e: EnemyData = t.idle_enemy(500)
	e.defense = def
	e.resistance = res
	e.speed = 0
	e.luck = 0
	e.traits = traits
	return e


func one(e: EnemyData) -> Array[EnemyData]:
	var es: Array[EnemyData] = [e]
	return es


func cs1(d: CompanionData) -> Array[CompanionData]:
	var cs: Array[CompanionData] = [d]
	return cs


## A test companion with these stats and `w` in hand (BLD high enough for no weight penalty).
func fighter(w: WeaponData, strength: int, magic: int = 0, dex: int = 0, spd: int = 0, bld: int = 20) -> CompanionData:
	var d: CompanionData = t.make_companion("Tester", 50, 0, w)
	d.strength = strength
	d.magic = magic
	d.dexterity = dex
	d.speed = spd
	d.build = bld
	d.crit = 0
	return d


func weapon(kind: WeaponData.WeaponType, might: int = 0, magic: bool = false, weight: int = 0) -> WeaponData:
	var w: WeaponData = t.make_weapon(might, 999, weight, kind)
	if magic:
		w.damage_type = CombatMath.DamageType.MAGIC
	return w


# ---------------------------------------------------------------- starting stats and Focus

## Every companion's Strength and Magic stand 1 apart and grow 10 points apart, the one they are known
## for ahead: either craft is open to anyone (design/callings.md).
func test_strength_and_magic_stand_close() -> void:
	var mages := 0
	for d in content().companions:
		var gs := Levels.growth_rate(d, Stat.STR)
		var gm := Levels.growth_rate(d, Stat.MAG)
		t.eq(absi(d.strength - d.magic), 1, "%s: Strength %d and Magic %d are 1 apart" % [d.display_name, d.strength, d.magic])
		t.eq(absi(gs - gm), 10, "%s: their growth rates %d and %d are 10 apart" % [d.display_name, gs, gm])
		t.eq(d.strength > d.magic, gs > gm, "%s: the higher one grows faster" % d.display_name)
		t.eq(d.magic > d.strength, d.signature_spell != null, "%s: Magic leads for the mages and nobody else" % d.display_name)
		if d.magic > d.strength:
			mages += 1
	t.eq(mages, 4, "four mages")


func test_starting_health_and_stamina() -> void:
	var cs := content().companions
	t.eq(cs.size(), 14, "fourteen companions")
	for d in cs:
		t.check(d.max_hp >= 16 and d.max_hp <= 24, "%s: health %d in 16-24" % [d.display_name, d.max_hp])
		t.check(d.max_sta >= 12 and d.max_sta <= 20, "%s: stamina %d in 12-20" % [d.display_name, d.max_sta])
		t.check(OLD_HP.has(d.display_name), "%s: known" % d.display_name)
		t.check(d.weapon != null and d.weapon.tier == WeaponData.Tier.WOODEN and not d.weapon.is_magic(),
			"%s starts with a wooden weapon" % d.display_name)
		t.check(d.weapon != null and d.weapon.required_grade <= d.starting_grade(d.weapon.weapon_type),
			"%s can hold it" % d.display_name)
	# Standing kept: whoever had more health before has at least as much now.
	for a in cs:
		for b in cs:
			if int(OLD_HP[a.display_name]) > int(OLD_HP[b.display_name]):
				t.check(a.max_hp >= b.max_hp, "%s stays at or above %s in health" % [a.display_name, b.display_name])
	var by_name := {}
	for d in cs:
		by_name[d.display_name] = d
	for d in cs:
		t.check(d.max_hp <= by_name["Elena"].max_hp and d.max_hp >= by_name["Elio"].max_hp, "Elena the sturdiest, Elio the frailest")
	# Every fighter has more stamina than every mage.
	for a in cs:
		for b in cs:
			if not a.is_mage() and b.is_mage():
				t.check(a.max_sta > b.max_sta, "fighter %s has more stamina than mage %s" % [a.display_name, b.display_name])


func test_focus_pays_for_a_tier_one_art() -> void:
	var lo := 999
	var hi := 0
	for art in ArtLibrary.load_default().arts:
		if art.tier == 1:
			lo = mini(lo, art.stamina_cost)
			hi = maxi(hi, art.stamina_cost)
	# Half of max stamina, rounded up: for the companion with the least it still pays for any tier 1 art.
	var least := 999
	for cd in content().companions:
		least = mini(least, cd.max_sta)
	var one_focus := ceili(least * BattleConfig.FOCUS_RESTORE_PERCENT / 100.0)
	t.check(one_focus >= hi, "one Focus of the least stamina (%d of %d) pays for a tier 1 art (%d-%d)" % [one_focus, least, lo, hi])
	var d: CompanionData = t.make_companion("Frail")
	d.max_sta = 13
	var b: Battle = t.make_battle(cs1(d), one(t.idle_enemy()))
	var c := b.roster[0]
	t.eq(b.focus_amount(c), 7, "half of 13, rounded up")
	c.stamina = 10
	b.focus(c)
	t.eq(c.stamina, 13, "stops at max")


# ---------------------------------------------------------------- the ladder

func test_weapon_ladder() -> void:
	var rc := content()
	t.eq(rc.weapons.size(), 30, "thirty ladder weapons")
	var seen := {}
	for w in rc.weapons:
		var key := "%d/%d" % [w.tier, w.weapon_type]
		t.check(not seen.has(key), "%s: one per tier and type" % w.display_name)
		seen[key] = true
		t.check(not w.is_magic(), "%s is not magic" % w.display_name)
	for ti in TIERS.size():
		t.eq(WeaponData.ladder_grade(ti), [Proficiency.Grade.E, Proficiency.Grade.D, Proficiency.Grade.C,
			Proficiency.Grade.B, Proficiency.Grade.A, Proficiency.Grade.S][ti], "%s needs its grade" % TIERS[ti])
		for ki in TYPES.size():
			var w: WeaponData = load("res://data/weapons/%s_%s.tres" % [TIERS[ti], TYPES[ki]])
			var name := "%s %s" % [TIERS[ti], TYPES[ki]]
			t.check(w != null and rc.weapons.has(w), "%s is on the ladder" % name)
			if w == null:
				continue
			t.eq(w.tier, ti, "%s: tier" % name)
			t.eq(w.weapon_type, ki, "%s: type" % name)
			t.eq(w.might, MIGHT_TABLE[ki][ti], "%s: Mt" % name)
			t.eq(WeaponData.ladder_might(ti, ki), MIGHT_TABLE[ki][ti], "%s: Mt by the rule" % name)
			t.eq(w.hit, HIT_TABLE[ki][ti], "%s: Hit" % name)
			t.eq(w.weight, WEIGHT_TABLE[ki][ti], "%s: weight" % name)
			t.eq(w.required_grade, WeaponData.ladder_grade(ti), "%s: grade" % name)
			t.eq(w.display_name, "%s %s" % [TIERS[ti].capitalize(), TYPES[ki].capitalize()], "%s: name" % name)
			t.eq(w.effective_against.has(EnemyTraits.FLYING), ki == WeaponData.WeaponType.BOW, "%s: bows against Flying" % name)
			t.eq(w.effective_against.has(EnemyTraits.LARGE), ki == WeaponData.WeaponType.SPEAR, "%s: spears against Large" % name)
			t.eq(rc.ladder_weapon(ti, ki), w, "%s: found by tier and type" % name)
		# The types' character in every tier: axes least accurate and heaviest, daggers lightest,
		# bows and daggers most accurate.
		var row := rc.ladder_tier(ti)
		var axe := rc.ladder_weapon(ti, WeaponData.WeaponType.AXE)
		var dagger := rc.ladder_weapon(ti, WeaponData.WeaponType.DAGGER)
		var bow := rc.ladder_weapon(ti, WeaponData.WeaponType.BOW)
		for w in row:
			t.check(axe.hit <= w.hit and axe.weight >= w.weight, "%s: the axe is the least accurate and heaviest" % TIERS[ti])
			t.check(dagger.weight <= w.weight, "%s: the dagger is the lightest" % TIERS[ti])
			t.check(bow.hit >= w.hit or dagger.hit >= w.hit, "%s: bows and daggers are the most accurate" % TIERS[ti])
	# Wooden is the lightest tier of every type.
	for ki in TYPES.size():
		var wooden := rc.ladder_weapon(WeaponData.Tier.WOODEN, ki)
		for ti in range(1, TIERS.size()):
			t.check(wooden.weight < rc.ladder_weapon(ti, ki).weight, "the wooden %s is lighter than the %s" % [TYPES[ki], TIERS[ti]])
	# Grade gates: a D companion can hold bronze but not iron.
	var p := CompanionProgress.create(load("res://data/companions/aina.tres"))
	t.eq(p.grade(WeaponData.WeaponType.SWORD), Proficiency.Grade.D, "Aina starts at D")
	t.check(p.can_equip_weapon(rc.ladder_weapon(WeaponData.Tier.BRONZE, WeaponData.WeaponType.SWORD)), "D holds bronze")
	t.check(not p.can_equip_weapon(rc.ladder_weapon(WeaponData.Tier.IRON, WeaponData.WeaponType.SWORD)), "D cannot hold iron")
	p.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.A)
	t.check(p.can_equip_weapon(rc.ladder_weapon(WeaponData.Tier.SILVER, WeaponData.WeaponType.SWORD)), "A holds silver")
	t.check(not p.can_equip_weapon(rc.ladder_weapon(WeaponData.Tier.PLATINUM, WeaponData.WeaponType.SWORD)), "but not platinum")
	p.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.S)
	t.check(p.can_equip_weapon(rc.ladder_weapon(WeaponData.Tier.PLATINUM, WeaponData.WeaponType.SWORD)), "S holds platinum")


## The four magic weapons: rare, above bronze and at most iron of their type in Mt, needing at most D.
func test_rare_magic_weapons_on_the_ladder() -> void:
	var rc := content()
	var magic := rc.rare_weapons.filter(func(w: WeaponData) -> bool: return w.is_magic())
	t.eq(magic.size(), 4, "four magic weapons among the rare ones")
	for w: WeaponData in magic:
		t.check(w.rare, "%s is rare" % w.display_name)
		t.eq(Run.weapon_price(w), 150, "%s keeps its price" % w.display_name)
		t.check(w.trait_lines().has("Strikes with MAG against RES"), "%s: its trait line" % w.display_name)
		t.eq(w.tier, WeaponData.Tier.BRONZE, "%s sits at bronze" % w.display_name)
		var bronze := rc.ladder_weapon(WeaponData.Tier.BRONZE, w.weapon_type)
		var iron := rc.ladder_weapon(WeaponData.Tier.IRON, w.weapon_type)
		t.check(w.might > bronze.might and w.might <= iron.might, "%s: Mt %d above bronze, at most iron" % [w.display_name, w.might])
		t.check(w.required_grade <= Proficiency.Grade.D and w.required_grade > Proficiency.Grade.E,
			"%s: needs a little training, no more than bronze" % w.display_name)
		t.eq(w.effective_against.has(EnemyTraits.FLYING), w.weapon_type == WeaponData.WeaponType.BOW, "%s: Flying if a bow" % w.display_name)
		t.eq(w.effective_against.has(EnemyTraits.LARGE), w.weapon_type == WeaponData.WeaponType.SPEAR, "%s: Large if a spear" % w.display_name)


# ---------------------------------------------------------------- attack power

func test_attack_power_by_type() -> void:
	var T := WeaponData.WeaponType
	# STR 9, MAG 6, DEX 12, SPD 8, BLD 7: odd sums show the rounding down.
	var cases := [
		[T.SWORD, false, 9], [T.SPEAR, false, 9], [T.AXE, false, 9 + 3], [T.BOW, false, 10], [T.DAGGER, false, 8],
		[T.SWORD, true, 6], [T.SPEAR, true, 6], [T.AXE, true, 6 + 3], [T.BOW, true, 9], [T.DAGGER, true, 7],
	]
	for c: Array in cases:
		var w := weapon(c[0], 0, c[1])
		t.eq(CombatMath.attack_power_from(w, 9, 6, 12, 8, 7), c[2],
			"%s%s attack power" % ["magic " if c[1] else "", WeaponData.type_name(c[0])])
	t.eq(CombatMath.attack_power_from(weapon(T.BOW), 9, 0, 10, 0, 0), 9, "(9 + 10) / 2 rounds down to 9")
	t.eq(CombatMath.attack_power_from(weapon(T.DAGGER), 4, 0, 0, 11, 0), 7, "(4 + 11) / 2 rounds down to 7")
	t.eq(CombatMath.attack_power_from(weapon(T.AXE), 10, 0, 0, 0, 9), 14, "10 + 9 / 2 rounds down to 14")
	t.eq(CombatMath.attack_power_from(null, 10, 0, 0, 0, 0), 10, "no weapon: STR")


func test_attack_power_after_weight_and_effects() -> void:
	var T := WeaponData.WeaponType
	# A heavy dagger: weight 8 on BLD 5 costs 3 SPD (and DEX).
	var d := fighter(weapon(T.DAGGER, 2, false, 8), 10, 0, 10, 10, 5)
	var b: Battle = t.make_battle(cs1(d), one(target(0)))
	var c := b.roster[0]
	t.eq(c.stat(Stat.SPD), 7, "SPD after the weight penalty")
	t.eq(c.attack_power(), floori((10 + 7) / 2.0), "dagger power uses SPD after the penalty")
	t.eq(CombatMath.attack_power(c, c.weapon()), c.attack_power(), "the same through CombatMath")
	# An effect lowering SPD lowers it again.
	var slow := StatusEffect.new()
	slow.display_name = "Slowed"
	slow.stat_mods = {Stat.SPD: -4}
	slow.ticks_left = 5
	c.add_effect(slow)
	t.eq(c.attack_power(), floori((10 + 3) / 2.0), "and after effects")
	# An axe's BLD part is BLD itself, not touched by weight.
	var axe := fighter(weapon(T.AXE, 0, false, 30), 10, 0, 0, 0, 9)
	var b2: Battle = t.make_battle(cs1(axe), one(target(0)))
	t.eq(b2.roster[0].attack_power(), 10 + 4, "axe: STR + BLD / 2")


func test_attack_power_in_forecasts() -> void:
	var T := WeaponData.WeaponType
	# Each type: power + Mt - DEF, as a plain attack, with an art, and dealt.
	for kind: int in T.values():
		var d := fighter(weapon(kind, 3), 9, 0, 12, 8, 7)
		var b: Battle = t.make_battle(cs1(d), one(target(4)))
		var c := b.roster[0]
		var power := CombatMath.attack_power(c, c.weapon())
		var f := b.forecast(c, b.enemies[0])
		t.eq(f.damage, power + 3 - 4, "%s: attack power + Mt - DEF" % WeaponData.type_name(kind))
		var art: CombatArtData = t.make_art("Art", 1, 1, 1, 2, kind)
		t.give_art(c, art)
		t.eq(b.forecast(c, b.enemies[0], art).damage, power + 3 + 2 - 4, "%s: and the art's Mt bonus" % WeaponData.type_name(kind))
		t.check(b.attack(c, b.enemies[0]), "attack")
		t.eq(b.enemies[0].hp, 500 - (power + 3 - 4), "%s: dealt as forecast" % WeaponData.type_name(kind))
	# A magic bow: (MAG + DEX) / 2 + Mt against RES.
	var mb := fighter(weapon(T.BOW, 4, true), 2, 11, 10)
	var b3: Battle = t.make_battle(cs1(mb), one(target(20, 3)))
	var f3 := b3.forecast(b3.roster[0], b3.enemies[0])
	t.check(f3.magic, "magic")
	t.eq(f3.damage, (11 + 10) / 2 + 4 - 3, "magic bow: (MAG + DEX) / 2 + Mt - RES")


## The barracks' Attack number: attack power + Mt, from the stats carried between battles.
func test_run_companion_attack() -> void:
	var rc := content()
	var by_name := {}
	for d in rc.companions:
		by_name[d.display_name] = d
	var elena := RunCompanion.create(by_name["Elena"])
	t.eq(elena.attack_power(), 7 + 6 / 2, "Elena: STR 7 + BLD 6 / 2")
	t.eq(elena.attack(), 7 + 3 + 0, "with a wooden axe (Mt 0)")
	var yuzu := RunCompanion.create(by_name["Yuzu"])
	t.eq(yuzu.attack_power(), (4 + 8) / 2, "Yuzu: (STR 4 + SPD 8) / 2")
	# With another weapon in mind: Yuzu (BLD 3) with a steel dagger (weight 2): no penalty.
	var steel := rc.ladder_weapon(WeaponData.Tier.STEEL, WeaponData.WeaponType.DAGGER)
	t.eq(yuzu.attack(steel), 6 + 3, "a steel dagger's Mt")
	# Elena (BLD 6) with a steel axe (weight 7): BLD is not lowered by weight.
	var steel_axe := rc.ladder_weapon(WeaponData.Tier.STEEL, WeaponData.WeaponType.AXE)
	t.eq(elena.attack(steel_axe), 10 + 3, "steel axe")
	# Erik (BLD 3) with a heavy bow would lose DEX: steel bow weight 4 costs 1 DEX.
	var erik := RunCompanion.create(by_name["Erik"])
	var steel_bow := rc.ladder_weapon(WeaponData.Tier.STEEL, WeaponData.WeaponType.BOW)
	t.eq(erik.attack_power(steel_bow), (5 + 7 - 1) / 2, "the weight penalty lowers a bow's DEX part")
	# The same number the battle uses.
	var b := Battle.new([elena.data] as Array[CompanionData], one(target(0)), t.make_rng(1), [elena.progress] as Array[CompanionProgress])
	t.eq(b.roster[0].attack_power(), elena.attack_power(), "matches the battle's attack power")


# ---------------------------------------------------------------- effectiveness

func test_effective_adds_half_before_crit() -> void:
	var T := WeaponData.WeaponType
	var spear := weapon(T.SPEAR, 4)
	spear.effective_against = [EnemyTraits.LARGE] as Array[String]
	var d := fighter(spear, 10)
	d.crit = 50
	var big := target(3, 0, [EnemyTraits.LARGE] as Array[String])
	var b: Battle = t.make_battle(cs1(d), one(big))
	var c := b.roster[0]
	var f := b.forecast(c, b.enemies[0])
	t.check(f.effective, "effective")
	# 10 + 4 - 3 = 11; + 11 / 2 (5) = 16; a critical doubles that: 32.
	t.eq(f.damage, 16, "+50% of the damage after DEF, rounded down")
	t.eq(f.crit_damage, 32, "a critical doubles the effective damage")
	t.eq(CombatMath.effective_damage(11, true), 16, "the rule")
	t.eq(CombatMath.effective_damage(11, false), 11, "not effective: unchanged")
	t.eq(CombatMath.effective_damage(1, true), 1, "1 stays 1")
	# Through an art made for it (the weapon plain): the same, and the art's Mt counts.
	var plain := fighter(weapon(T.SPEAR, 4), 10)
	var b2: Battle = t.make_battle(cs1(plain), one(target(3, 0, [EnemyTraits.LARGE] as Array[String])))
	var art: CombatArtData = t.make_art("Giant Cut", 1, 1, 1, 2, T.SPEAR)
	art.effective_against = [EnemyTraits.LARGE] as Array[String]
	t.give_art(b2.roster[0], art)
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0], art).damage, 13 + 6, "art: (10 + 4 + 2 - 3) + 6")
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0]).damage, 11, "the plain attack is not")
	# Weapon and art both: once.
	b2.roster[0].weapon().effective_against = [EnemyTraits.LARGE] as Array[String]
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0], art).damage, 13 + 6, "does not stack")
	# A spell made for it.
	var lance := SpellData.new()
	lance.display_name = "Lance"
	lance.school = SpellData.School.BLACK
	lance.might = 3
	lance.hit = 999
	lance.effective_against = [EnemyTraits.LARGE] as Array[String]
	var mage: CompanionData = t.make_companion("Mage", 30)
	mage.magic = 10
	mage.signature_spell = lance
	var b3: Battle = Battle.new(cs1(mage), one(target(0, 4, [EnemyTraits.LARGE] as Array[String])), t.make_rng(3))
	var fs := b3.spell_forecast(b3.roster[0], lance, b3.enemies[0])
	t.check(fs.effective, "the spell is effective")
	t.eq(fs.damage, 9 + 4, "spell: (10 + 3 - 4) + 9 / 2")
	t.eq(fs.crit_damage, 26, "and a critical doubles it")


func test_effective_with_guard_and_minimum() -> void:
	var T := WeaponData.WeaponType
	var bow := weapon(T.BOW, 2)
	bow.effective_against = [EnemyTraits.FLYING] as Array[String]
	var d := fighter(bow, 6, 0, 8)
	var b: Battle = t.make_battle(cs1(d), one(target(4, 0, [EnemyTraits.FLYING] as Array[String])))
	var c := b.roster[0]
	# (6 + 8) / 2 + 2 - 4 = 5; effective 7; halved by a Defend-like effect: 3.
	var shell := StatusEffect.new()
	shell.display_name = "Shell"
	shell.damage_taken_mult = 0.5
	shell.ticks_left = 5
	b.enemies[0].add_effect(shell)
	var f := b.forecast(c, b.enemies[0])
	t.eq(f.damage, 3, "effective first, then the damage-taken multiplier")
	t.eq(f.crit_damage, 7, "critical: 7 x 2 x 0.5")
	# Against armour it cannot pierce: still at least 1.
	var b2: Battle = t.make_battle(cs1(fighter(bow, 6, 0, 8)), one(target(40, 0, [EnemyTraits.FLYING] as Array[String])))
	t.eq(b2.forecast(b2.roster[0], b2.enemies[0]).damage, 1, "minimum 1")


# ---------------------------------------------------------------- Large

func test_large_trait() -> void:
	t.check(EnemyTraits.describe(EnemyTraits.LARGE).begins_with("Large:"), "Large has its description")
	t.check(EnemyTraits.describe(EnemyTraits.LARGE).contains("Spears"), "which names spears")
	for n in LARGE_ENEMIES:
		var e: EnemyData = load("res://data/enemies/%s.tres" % n)
		t.check(e.traits.has(EnemyTraits.LARGE), "%s is Large" % e.display_name)
	for n in LARGE_BOSSES:
		var e: EnemyData = load("res://data/enemies/bosses/%s.tres" % n)
		t.check(e.traits.has(EnemyTraits.LARGE), "%s is Large" % e.display_name)
	# Nobody else.
	var named := {}
	for n in LARGE_ENEMIES + LARGE_BOSSES:
		named[n] = true
	for dir in ["res://data/enemies/", "res://data/enemies/bosses/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var e: EnemyData = load(dir + f)
			t.eq(e.traits.has(EnemyTraits.LARGE), named.has(f.get_basename()), "%s: Large only if named" % e.display_name)
	# A scaled copy keeps the trait.
	var orc: EnemyData = load("res://data/enemies/orc.tres")
	t.check(Run.scaled_enemy(orc, 30).traits.has(EnemyTraits.LARGE), "a grown orc is still Large")


func test_spears_effective_against_large() -> void:
	var rc := content()
	var orc: EnemyData = load("res://data/enemies/orc.tres")
	for kind: int in WeaponData.WeaponType.values():
		var w := rc.ladder_weapon(WeaponData.Tier.IRON, kind)
		var d := fighter(w, 10, 0, 10, 10)
		var b: Battle = t.make_battle(cs1(d), one(orc))
		var f := b.forecast(b.roster[0], b.enemies[0])
		t.eq(f.effective, kind == WeaponData.WeaponType.SPEAR, "%s against an orc" % w.display_name)
		var plain := maxi(1, CombatMath.attack_power(b.roster[0], w) + w.might - orc.defense)
		t.eq(f.damage, CombatMath.effective_damage(plain, f.effective), "%s: damage" % w.display_name)


# ---------------------------------------------------------------- where weapons come from

## Over many runs: the stock's tiers are those the week's weights allow, and they climb.
func test_weekly_stock_tiers() -> void:
	var counts := []   # by week: count per tier
	for w in 6:
		counts.append([0, 0, 0, 0, 0, 0])
	for s in 60:
		var run := make_run(9000 + s)
		for week in 6:
			run.day = week * RunConfig.WEEK_DAYS + 1
			run.shop_week.clear()
			run._stock_shop()
			var weights: Array = Run.shop_tier_weights(run.day)
			for item in run.shop_stock():
				var w := item.weapon
				if w.rare:
					t.check(week >= 1, "rare weapons from week 2")
					continue
				t.check(float(weights[w.tier]) > 0.0, "week %d sells %s only if its weights allow" % [week + 1, w.display_name])
				t.eq(item.price, Run.weapon_price(w), "%s priced by tier" % w.display_name)
				counts[week][w.tier] += 1
	var lines: Array[String] = []
	for week in 6:
		lines.append("w%d %s" % [week + 1, str(counts[week])])
	print("  smithy stock by week (wooden..platinum, 60 runs): " + ", ".join(lines))
	t.check(counts[0][0] > 0 and counts[0][1] > 0 and counts[0][2] == 0, "week 1: wooden and bronze, no iron")
	t.check(counts[1][2] > 0, "iron from week 2")
	t.check(counts[1][3] == 0 and counts[2][3] > 0, "steel from week 3")
	t.check(counts[2][4] == 0 and counts[3][4] > 0, "silver from week 4")
	t.check(counts[3][4] * 3 < counts[3][3], "silver is rare in week 4")
	for week in 6:
		t.eq(counts[week][5], 0, "the smithy never sells platinum (week %d)" % (week + 1))
	# The average tier climbs every week.
	var last := -1.0
	for week in 6:
		var total := 0
		var n := 0
		for tier in 6:
			total += tier * int(counts[week][tier])
			n += int(counts[week][tier])
		var mean := float(total) / maxi(1, n)
		t.check(mean > last, "week %d's stock is better on average than the week before" % (week + 1))
		last = mean
	t.eq(Run.smithy_top_tier(1), WeaponData.Tier.BRONZE, "week 1 tops out at bronze")
	t.eq(Run.smithy_top_tier(14), WeaponData.Tier.IRON, "week 2 at iron")
	t.eq(Run.smithy_top_tier(15), WeaponData.Tier.STEEL, "week 3 at steel")
	t.eq(Run.smithy_top_tier(28), WeaponData.Tier.SILVER, "week 4 at silver")
	t.eq(Run.smithy_top_tier(42), WeaponData.Tier.SILVER, "week 6 at silver")
	for p in RunConfig.WEAPON_PRICE_BY_TIER.size() - 1:
		t.check(RunConfig.WEAPON_PRICE_BY_TIER[p] < RunConfig.WEAPON_PRICE_BY_TIER[p + 1], "a better tier costs more")


func test_stock_is_five_different_weapons() -> void:
	for s in 30:
		var run := make_run(700 + s)
		var ladder := run.shop_stock().filter(func(i: ShopItemData) -> bool: return not i.weapon.rare)
		t.eq(ladder.size(), RunConfig.SHOP_WEAPONS_PER_WEEK, "seed %d: a handful of weapons" % s)
		var seen := {}
		var last_key := -1
		for item: ShopItemData in ladder:
			t.check(not seen.has(item.weapon), "seed %d: no two the same" % s)
			seen[item.weapon] = true
			var key: int = item.weapon.tier * 100 + item.weapon.weapon_type * 10 + (1 if item.weapon.has_second_requirement() else 0)
			t.check(key >= last_key, "seed %d: in order of tier and type" % s)   # two families can share a main type
			last_key = key
		# Rare weapons, when in stock, come first.
		var rare_done := false
		for item in run.shop_stock():
			if not item.weapon.rare:
				rare_done = true
			else:
				t.check(not rare_done, "seed %d: rare items first" % s)


func test_event_weapon_fits_the_week() -> void:
	var knight: EventData = load("res://data/run/events/knight.tres")
	var armory: EventData = load("res://data/run/events/armory.tres")
	var bow_choice: EventChoiceData = null
	for ch in knight.choices:
		if ch.random_weapon:
			bow_choice = ch
	t.check(bow_choice != null and bow_choice.random_weapon_type == WeaponData.WeaponType.BOW, "the knight leaves a bow")
	var any_choice: EventChoiceData = null
	for ch in armory.choices:
		if ch.random_weapon:
			any_choice = ch
	t.check(any_choice != null and any_choice.random_weapon_type == -1, "the armory gives any weapon")
	var above := 0
	var total := 0
	for s in 200:
		var run := make_run(3000 + s)
		run.day = [2, 9, 15, 23, 29, 37][s % 6]
		run.event = armory if s % 2 == 0 else knight
		run._draw_event_weapons()
		var ch := any_choice if s % 2 == 0 else bow_choice
		var w := run.choice_weapon(ch)
		t.check(w != null and (not w.is_magic() or w.has_second_requirement() or w.rare), "seed %d: a ladder, two-proficiency or rare weapon is drawn" % s)
		if w == null:
			continue
		if ch == bow_choice:
			t.eq(w.weapon_type, WeaponData.WeaponType.BOW, "a bow")
		var top := Run.smithy_top_tier(run.day)
		var weights: Array = Run.shop_tier_weights(run.day)
		if w.rare:
			t.check(w.required_grade <= Run.rare_max_grade(run.day), "day %d: a rare %s fits the week's grade" % [run.day, w.display_name])
		else:
			t.check(float(weights[w.tier]) > 0.0 or w.tier == mini(top + 1, WeaponData.top_tier()),
				"day %d: %s fits the week or is one above the smithy" % [run.day, w.display_name])
			total += 1
			if w.tier > top:
				above += 1
		# The same weapon until chosen, then it is in the armory and named.
		t.eq(run.choice_weapon(ch), w, "the draw holds")
		var before := run.inventory.weapons.size()
		var text := run.choose(ch)
		t.eq(run.inventory.weapons.size(), before + 1, "added to the armory")
		t.check(text.contains(w.display_name), "the letter names it: %s" % text)
	t.check(above > total * 0.12 and above < total * 0.4, "sometimes one above the smithy (%d of %d)" % [above, total])
	# A set weapon is given as before.
	var hermit: EventData = load("res://data/run/events/hermit.tres")
	var run2 := make_run(5)
	run2.event = hermit
	run2._draw_event_weapons()
	for ch in hermit.choices:
		t.eq(run2.choice_weapon(ch), ch.weapon, "the hermit's blade is a set weapon")


func test_boss_drops_a_weapon() -> void:
	t.eq(Run.boss_weapon_tier(14), WeaponData.Tier.STEEL, "day 14: steel, above the week's iron")
	t.eq(Run.boss_weapon_tier(28), WeaponData.Tier.PLATINUM, "day 28: platinum, above the week's silver")
	t.eq(Run.boss_weapon_tier(42), -1, "the last boss ends the run and drops nothing")
	var kinds := {}
	for s in 40:
		for boss_day in [14, 28, 42]:
			var run := make_run(4000 + s)
			run.day = boss_day
			run._begin_day()
			t.check(run.fronts.size() == 1 and run.fronts[0].is_boss, "a boss front")
			var before := run.inventory.weapons.size()
			var b := run.start_battle(run.fronts[0])
			for e in b.enemies:
				e.hp = 0
			b._check_end()
			var report := run.finish_battle(b)
			t.check(report.won, "won")
			if boss_day == 42:
				t.check(report.weapon_found == null, "nothing on day 42")
				t.eq(run.inventory.weapons.size(), before, "nothing added")
				continue
			var w := report.weapon_found
			t.check(w != null, "day %d: a weapon is found" % boss_day)
			if w == null:
				continue
			if w.rare:
				t.check(boss_day == 28 or w.required_grade <= Proficiency.Grade.D, "day %d: a rare %s within the boss's grade" % [boss_day, w.display_name])
			else:
				t.eq(w.tier, Run.boss_weapon_tier(boss_day), "day %d: the tier above the smithy" % boss_day)
			t.check(not w.is_magic() or w.has_second_requirement() or w.rare, "a ladder, two-proficiency or rare weapon")
			t.eq(run.inventory.weapons.size(), before + 1, "into the armory")
			t.check(run.inventory.weapons[-1].data == w and run.inventory.weapons[-1].holder == null, "unheld in the armory")
			kinds[w.weapon_type] = true
	t.eq(kinds.size(), 5, "any type can drop")
	# A lost boss drops nothing (and ends the run).
	var lost := make_run(77)
	lost.day = 14
	lost._begin_day()
	var lb := lost.start_battle(lost.fronts[0])
	for c in lb.line():
		c.hp = 0
		c.state = CompanionUnit.State.INJURED
	lb._check_end()
	t.check(lost.finish_battle(lb).weapon_found == null, "a lost boss drops nothing")
	# A normal battle drops nothing.
	var normal := make_run(78)
	var nb := normal.start_battle(normal.fronts[0])
	for e in nb.enemies:
		e.hp = 0
	nb._check_end()
	t.check(normal.finish_battle(nb).weapon_found == null, "a normal battle drops nothing")


# ---------------------------------------------------------------- damage by type

## The expected stats of `d` at `level` (base + growth x levels gained).
func stats_at(d: CompanionData, level: int) -> Dictionary:
	var s := d.base_stats()
	for k: String in s:
		if k != Stat.BLD:
			s[k] = float(s[k]) + float(d.growths.get(k, 0)) / 100.0 * (level - 1)
	return s


## Typical damage (and damage x hit chance) of every weapon type in every tier against the average
## normal enemy of the day, at levels 1, 6 and 12 (days 1, 14 and 36). Averaged over the fighters of
## each type, after the weight penalty. Prints the table and checks no type is useless or dominant
## with the tiers a company typically holds at that level.
func test_damage_by_weapon_type_table() -> void:
	var rc := content()
	var by_band := {}
	for g in rc.groups:
		for e in g.enemies:
			by_band[e.display_name] = e
	var checkpoints := [[1, 1, [0, 1]], [6, 14, [1, 2]], [12, 36, [2, 3, 4]]]
	for cp: Array in checkpoints:
		var level: int = cp[0]
		var day: int = cp[1]
		var band := Run.band_of_day(day)
		var foes: Array[EnemyData] = []
		for e: EnemyData in by_band.values():
			if e.band == band:
				foes.append(Run.scaled_enemy(e, day))
		var def := 0.0
		var spd := 0.0
		var lck := 0.0
		for e in foes:
			def += e.defense
			spd += e.speed
			lck += e.luck
		def /= foes.size()
		spd /= foes.size()
		lck /= foes.size()
		print("  damage by weapon type, level %d vs the average day %d enemy (DEF %.1f, SPD %.1f): dmg / dmg x hit" % [level, day, def, spd])
		var typical: Array = cp[2]
		var mean_by_type := {}
		for kind: int in WeaponData.WeaponType.values():
			var users: Array[CompanionData] = []
			for d in rc.companions:
				if not d.is_mage() and d.weapon.weapon_type == kind:
					users.append(d)
			var cells: Array[String] = []
			var typical_sum := 0.0
			for tier in TIERS.size():
				var w := rc.ladder_weapon(tier, kind)
				var dmg := 0.0
				var expected := 0.0
				for d in users:
					var s := stats_at(d, level)
					var pen := maxf(0.0, w.weight - float(s[Stat.BLD]))
					var power := CombatMath.attack_power_from(w, roundi(s[Stat.STR]), roundi(s[Stat.MAG]),
						roundi(maxf(0.0, s[Stat.DEX] - pen)), roundi(maxf(0.0, s[Stat.SPD] - pen)), roundi(s[Stat.BLD]))
					var hit := clampf(w.hit + 5.0 * (s[Stat.DEX] - pen - spd) - lck, 20, 100)
					var one_hit := maxf(1.0, power + w.might - def)
					dmg += one_hit
					expected += one_hit * hit / 100.0
				dmg /= users.size()
				expected /= users.size()
				cells.append("%s %4.1f/%4.1f" % [TIERS[tier].substr(0, 2), dmg, expected])
				if typical.has(tier):
					typical_sum += expected
			mean_by_type[kind] = typical_sum / typical.size()
			print("    %-6s %s" % [WeaponData.type_name(kind), "  ".join(cells)])
		var mean := 0.0
		for v: float in mean_by_type.values():
			mean += v
		mean /= mean_by_type.size()
		for kind: int in mean_by_type:
			var v: float = mean_by_type[kind]
			t.check(v >= mean * 0.6 and v <= mean * 1.5, "level %d: %s is neither useless nor dominant (%.1f against a mean of %.1f)" % [
				level, WeaponData.type_name(kind), v, mean])


# ---------------------------------------------------------------- two-proficiency weapons

func hybrid(tier: int, family: String) -> WeaponData:
	return load("res://data/weapons/%s_%s.tres" % [TIERS[tier], family.to_lower()])


## Every family at bronze, iron, steel and silver, by the formula.
func test_hybrid_families() -> void:
	var rc := content()
	t.eq(rc.hybrid_weapons.size(), 24, "six families at four tiers")
	for ti in range(WeaponData.Tier.BRONZE, WeaponData.Tier.SILVER + 1):
		for f: Array in FAMILIES:
			var fam: String = f[0]
			var main: int = f[1]
			var second: Array = f[2]
			var w := hybrid(ti, fam)
			var name := "%s %s" % [TIERS[ti], fam]
			t.check(w != null and rc.hybrid_weapons.has(w), "%s exists and is in the run content" % name)
			if w == null:
				continue
			var plain := rc.ladder_weapon(ti, main)
			t.eq(w.display_name, "%s %s" % [TIERS[ti].capitalize(), fam], "%s: name" % name)
			t.eq(w.family, fam, "%s: family" % name)
			t.eq(w.tier, ti, "%s: tier" % name)
			t.eq(w.weapon_type, main, "%s: main type" % name)
			t.eq(w.might, WeaponData.ladder_might(ti + BattleConfig.HYBRID_MIGHT_TIERS_UP, main), "%s: Mt of the main type one tier up" % name)
			t.eq(w.might, rc.ladder_weapon(ti + 1, main).might, "%s: as the next tier's %s" % [name, TYPES[main]])
			t.eq(w.weight, plain.weight + (3 if fam == "Twinblades" else 1), "%s: weight +1 (Twinblades +3)" % name)
			t.eq(w.weight, plain.weight + WeaponData.hybrid_weight_bonus(fam), "%s: weight by the rule" % name)
			t.eq(w.hit, plain.hit, "%s: Hit as the tier's %s" % [name, TYPES[main]])
			t.eq(w.required_grade, WeaponData.ladder_grade(ti), "%s: the tier's grade in the main type" % name)
			t.eq(w.second_grade, maxi(BattleConfig.HYBRID_SECOND_GRADE_MIN, WeaponData.ladder_grade(ti) - BattleConfig.HYBRID_SECOND_GRADE_STEPS_BELOW), "%s: one grade lower in the second, at least E+" % name)
			t.check(w.second_grade > Proficiency.Grade.E, "%s: the second is a real requirement" % name)
			t.check(w.has_second_requirement(), "%s: two proficiencies" % name)
			if second[0] == "t":
				t.eq(w.second_type, second[1], "%s: second type" % name)
				t.eq(w.second_school, -1, "%s: no school" % name)
			else:
				t.eq(w.second_school, second[1], "%s: second school" % name)
				t.eq(w.second_type, -1, "%s: no second weapon type" % name)
			t.eq(w.is_magic(), fam == "Runeblade", "%s: only the Runeblade is magic" % name)
			t.eq(w.effective_against.has(EnemyTraits.LARGE), main == WeaponData.WeaponType.SPEAR, "%s: Large per the main type" % name)
			t.eq(w.effective_against.has(EnemyTraits.FLYING), false, "%s: not against Flying" % name)
			t.eq(Run.weapon_price(w), HYBRID_PRICES[ti - 1], "%s: price" % name)
			t.eq(Run.weapon_price(w), roundi(RunConfig.WEAPON_PRICE_BY_TIER[ti] * 1.25 / 5.0) * 5, "%s: price by the rule" % name)
	t.eq(hybrid(WeaponData.Tier.IRON, "Halberd").requirement_text(), "axe C · spear D", "requirement text")
	t.eq(hybrid(WeaponData.Tier.BRONZE, "Runeblade").requirement_text(), "sword D · black magic E+", "a school in the text")
	var iron_spear := rc.ladder_weapon(WeaponData.Tier.IRON, WeaponData.WeaponType.SPEAR)
	t.eq(iron_spear.requirement_text(), "spear C", "an ordinary weapon")
	t.check(not iron_spear.has_second_requirement(), "ordinary: no second")
	for ti: int in [WeaponData.Tier.WOODEN, WeaponData.Tier.PLATINUM]:
		t.check(rc.hybrids_of_tier(ti).is_empty(), "no two-proficiency weapon at %s" % TIERS[ti])
	t.eq(rc.ladder_tier(WeaponData.Tier.IRON).size(), 5, "the ladder is unchanged")


func test_hybrid_holding() -> void:
	var run := make_run(81)
	run.roster.clear()
	run.lineup.clear()
	var elena := run._join(load("res://data/companions/elena.tres"))   # axe D, nothing else
	var bronze := hybrid(WeaponData.Tier.BRONZE, "Halberd")
	var iron := hybrid(WeaponData.Tier.IRON, "Halberd")
	t.eq(elena.progress.weapon_block_reason(bronze), "Needs spear E+; Elena is E.", "E in the second is not enough, even at bronze")
	elena.progress.points[WeaponData.WeaponType.SPEAR] = Proficiency.points_for(Proficiency.Grade.E_PLUS)
	t.eq(elena.progress.weapon_block_reason(bronze), "", "axe D + spear E+: a bronze halberd")
	t.check(elena.progress.can_equip_weapon(bronze), "can hold it")
	t.eq(elena.progress.weapon_block_reason(iron), "Needs axe C; Elena is D.", "the main grade first")
	elena.progress.points[WeaponData.WeaponType.AXE] = Proficiency.points_for(Proficiency.Grade.C)
	t.eq(elena.progress.weapon_block_reason(iron), "Needs spear D; Elena is E+.", "main but not second: blocked, naming it")
	t.check(not elena.progress.can_equip_weapon(iron), "cannot hold it")
	var owned := run.inventory.add(iron)
	t.eq(run.equip_block_reason(elena, owned), "Needs spear D; Elena is E+.", "the armory uses the same check")
	t.check(not run.equip_weapon(elena, owned), "refused")
	elena.progress.points[WeaponData.WeaponType.SPEAR] = Proficiency.points_for(Proficiency.Grade.D)
	t.eq(elena.progress.weapon_block_reason(iron), "", "both: allowed")
	t.check(run.equip_weapon(elena, owned), "equipped")
	t.eq(elena.weapon(), iron, "holds the halberd")
	# A school as the second requirement.
	var aina := run._join(load("res://data/companions/aina.tres"))   # sword D
	t.eq(aina.progress.weapon_block_reason(hybrid(WeaponData.Tier.BRONZE, "Runeblade")), "Needs black magic E+; Aina is E.", "a bronze runeblade needs black E+")
	aina.progress.points[WeaponData.WeaponType.SWORD] = Proficiency.points_for(Proficiency.Grade.C)
	t.eq(aina.progress.weapon_block_reason(hybrid(WeaponData.Tier.IRON, "Runeblade")), "Needs black magic D; Aina is E.", "needs black magic")
	aina.progress.magic_points[SpellData.School.BLACK] = Proficiency.points_for(Proficiency.Grade.D)
	t.check(aina.progress.can_equip_weapon(hybrid(WeaponData.Tier.IRON, "Runeblade")), "then allowed")


## Using a two-proficiency weapon raises only the main type; arts of the second type do not work with it.
func test_hybrid_counts_as_main_type() -> void:
	var halberd := hybrid(WeaponData.Tier.IRON, "Halberd")
	var d := fighter(halberd, 10)
	var b: Battle = t.make_battle(cs1(d), one(target(0)))
	var c := b.roster[0]
	var spear := c.progress.points_in(WeaponData.WeaponType.SPEAR)
	var axe := c.progress.points_in(WeaponData.WeaponType.AXE)
	t.check(b.attack(c, b.enemies[0]), "attack")
	t.check(c.progress.points_in(WeaponData.WeaponType.AXE) > axe, "axe points rise")
	t.eq(c.progress.points_in(WeaponData.WeaponType.SPEAR), spear, "spear points never do")
	t.eq(CombatMath.attack_power(c, halberd), 10 + floori(d.build / 2.0), "attack power of an axe")
	var spear_art: CombatArtData = t.make_art("Thrust", 1, 1, 1, 0, WeaponData.WeaponType.SPEAR)
	t.give_art(c, spear_art)
	t.check(b.art_block_reason(c, spear_art) != "", "spear arts do not work with a halberd")
	# Effectiveness per the main type: a glaive against Large, a halberd not.
	var g: Battle = t.make_battle(cs1(fighter(hybrid(WeaponData.Tier.IRON, "Glaive"), 10)), one(target(0, 0, [EnemyTraits.LARGE])))
	t.check(g.is_effective(g.roster[0], g.enemies[0]), "a glaive is effective against Large")
	var h: Battle = t.make_battle(cs1(fighter(halberd, 10)), one(target(0, 0, [EnemyTraits.LARGE])))
	t.check(not h.is_effective(h.roster[0], h.enemies[0]), "a halberd is not")


func test_runeblade_uses_mag() -> void:
	var rune := hybrid(WeaponData.Tier.STEEL, "Runeblade")
	t.eq(CombatMath.attack_power_from(rune, 3, 14, 0, 0, 0), 14, "MAG in place of STR")
	var b: Battle = t.make_battle(cs1(fighter(rune, 3, 14)), one(target(30, 4)))
	var f := b.forecast(b.roster[0], b.enemies[0])
	t.check(f.magic, "a magic strike")
	t.eq(f.damage, 14 + rune.might - 4, "MAG + Mt - RES")


## The smithy stocks them, at bronze to silver only, in about a fifth of the slots that could hold one.
func test_smithy_stocks_hybrids() -> void:
	var slots := 0
	var hybrids := 0
	var by_tier := [0, 0, 0, 0, 0, 0]
	for s in 60:
		var run := make_run(8100 + s)
		for week in 6:
			run.day = week * RunConfig.WEEK_DAYS + 1
			run.shop_week.clear()
			run._stock_shop()
			for item in run.shop_stock():
				if item.weapon.rare:
					continue
				var w := item.weapon
				if w.tier >= WeaponData.Tier.BRONZE and w.tier <= WeaponData.Tier.SILVER:
					slots += 1
				if w.has_second_requirement():
					hybrids += 1
					by_tier[w.tier] += 1
					t.check(w.tier >= WeaponData.Tier.BRONZE and w.tier <= WeaponData.Tier.SILVER, "%s: bronze to silver only" % w.display_name)
					t.eq(item.price, Run.weapon_price(w), "%s: priced x1.25" % w.display_name)
	var share := float(hybrids) / maxi(1, slots)
	print("  two-proficiency weapons in the smithy: %d of %d bronze-silver slots (%.0f%%), by tier %s" % [hybrids, slots, 100.0 * share, str(by_tier)])
	t.check(share > 0.13 and share < 0.27, "about a fifth of the slots (%.2f)" % share)
	t.eq(by_tier[0] + by_tier[5], 0, "never wooden or platinum")
	t.check(by_tier[1] > 0 and by_tier[4] > 0, "from bronze to silver")
	# Events can give one too.
	var seen := false
	for s in 200:
		var run := make_run(8300 + s)
		run.day = 9
		run.event = load("res://data/run/events/armory.tres")
		run._draw_event_weapons()
		for ch in run.event.choices:
			var w := run.choice_weapon(ch)
			if w != null and w.has_second_requirement():
				seen = true
	t.check(seen, "an event can give a two-proficiency weapon")


## Prints, for each companion, which families they can hold at bronze at the start of a run, and which
## they could reach at every tier by training (a drill opens any weapon type or school from E).
func test_hybrid_reach() -> void:
	print("  two-proficiency families by companion (bronze at the start / any tier by training):")
	for d in content().companions:
		var p := CompanionProgress.create(d)
		var now: Array[String] = []
		var later: Array[String] = []
		for f: Array in FAMILIES:
			var fam: String = f[0]
			if p.can_equip_weapon(hybrid(WeaponData.Tier.BRONZE, fam)):
				now.append(fam)
			later.append(fam)
		print("    %-9s start: %-36s by training: %s" % [d.display_name, ", ".join(now), ", ".join(later)])
	t.check(true, "printed")


## Dagger arts cost what the other types' do; Twin Arrows strikes twice for less.
func test_art_costs_by_type() -> void:
	var arts := ArtLibrary.load_default()
	var want := {"Quick Jab": 4, "Backstab": 5, "Bleeding Cut": 5, "Fade": 5, "Venom Edge": 5, "Flicker": 9, "Hobble": 9,
		"Nerve Strike": 9, "Shadowstep": 9, "Night Venom": 14, "Thousand Cuts": 14, "Assassinate": 15}
	for a in arts.of_type(WeaponData.WeaponType.DAGGER):
		t.eq(a.stamina_cost, want.get(a.display_name, -1), "%s costs %d" % [a.display_name, want.get(a.display_name, -1)])
	var by_tier := {}
	for a in arts.arts:
		if a.weapon_type != WeaponData.WeaponType.DAGGER:
			var span: Array = by_tier.get(a.tier, [99, 0])
			by_tier[a.tier] = [mini(span[0], a.stamina_cost), maxi(span[1], a.stamina_cost)]
	for a in arts.of_type(WeaponData.WeaponType.DAGGER):
		var span: Array = by_tier[a.tier]
		t.check(a.stamina_cost >= span[0] and a.stamina_cost <= span[1], "%s: within the other types' tier %d costs" % [a.display_name, a.tier])
	for a in arts.of_type(WeaponData.WeaponType.BOW):
		if a.display_name == "Twin Arrows":
			t.eq(a.might_bonus, -1, "Twin Arrows: Mt -1")
