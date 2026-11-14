extends RefCounted
## Headless tests for the Jeweler, crafting and the 54 accessories (design/accessories.md). The numbers
## are table-driven like trait_tests.gd and trait_hook_tests.gd, whose measuring helpers they reuse with
## the accessory worn (opts "wear"): each row is a number with the accessory minus without it. The new
## rules (Pin, Thorn, Talisman, Locket, Hourglass, Sigil's elite half), Spur, Tiara and Crown, wearing
## and crafting have tests of their own. Called from run_tests.gd, which owns check() and eq().

const TraitTests := preload("res://tests/trait_tests.gd")
const TraitHookTests := preload("res://tests/trait_hook_tests.gd")

var t   # the runner (run_tests.gd)
var _tt: RefCounted
var _ht: RefCounted
var _lib: AccessoryLibrary


func _init(runner: Object) -> void:
	t = runner
	_tt = TraitTests.new(runner)
	_ht = TraitHookTests.new(runner)
	_lib = AccessoryLibrary.load_default()


func tests() -> Array[Callable]:
	return [
		test_accessory_library,
		test_accessory_table,
		test_table_covers_library,
		test_jeweler_and_crafting,
		test_craft_draw,
		test_wear_rules,
		test_pin,
		test_thorn,
		test_talisman,
		test_locket,
		test_hourglass,
		test_spur,
		test_sigil_in_an_elite_fight,
		test_crown_and_tiara_uses,
	]


# ---------------------------------------------------------------- helpers

func make_run(seed_value: int = 1) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


func type_of(id: String) -> AccessoryTypeData:
	var x := _lib.find(id)
	if x == null:
		t.check(false, "no accessory %s" % id)
	return x


func one(id: String, rank: int) -> Accessory:
	return Accessory.new(type_of(id), rank)


## A run on free day 2 without an event, rich.
func free_run(seed_value: int) -> Run:
	var run := make_run(seed_value)
	run.day = 2
	run.calendar[1] = RunCalendar.DayType.FREE
	run.event_days.erase(2)
	run._begin_day()
	run.gold = 10000
	run.materials = {RunConfig.TIMBER: 100, RunConfig.IRON_ORE: 100}
	return run


## A battle of `line` plain companions (trait_tests.gd's) against one plain enemy; `wear` on slot `holder`.
func battle(wear: Array, line: int = 1, holder: int = 0, traits: Array = []) -> Battle:
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for i in line:
		var d: CompanionData = _tt.data()
		d.weapon.hit = 999
		datas.append(d)
		var p := CompanionProgress.create(d)
		if i == holder:
			p.accessories = wear
			p.traits.assign(traits)
		party.append(p)
	var es: Array[EnemyData] = [_tt.enemy()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return Battle.new(datas, es, rng, party)


## The value of `metric` through helper `h` ("t"/"to": trait_tests in or out of a battle, "h"/"ho":
## trait_hook_tests) with `wear` worn.
func measure(h: String, wear: Array, metric: String, opts: Dictionary) -> int:
	var o := opts.duplicate()
	o["wear"] = wear
	var none: Array[TraitData] = []
	match h:
		"t":
			return _tt.measure(none, metric, o)
		"to":
			return _tt.measure_out(none, metric, o)
		"h":
			return _ht.measure(none, metric, o)
		"ho":
			return _ht.measure_out(none, metric, o)
	return 0


## [helper, type id, rank, metric, change (an int, or "pos" / "neg"), options].
func table() -> Array:
	var half := {"enemy_half": true}
	return [
		# Plain.
		["to", "ring", 3, "plain:STR", 3, {}], ["t", "ring", 5, "stat:STR", 5, {}],
		["to", "circlet", 2, "plain:MAG", 2, {}], ["to", "bracelet", 4, "plain:DEX", 4, {}],
		["to", "anklet", 1, "plain:SPD", 1, {}], ["to", "armlet", 5, "plain:DEF", 5, {}],
		["to", "amulet", 2, "plain:RES", 2, {}], ["to", "earring", 3, "plain:CRT", 3, {}],
		["to", "buckle", 1, "plain:BLD", 1, {}], ["to", "pendant", 2, "max_hp", 6, {}],
		["t", "girdle", 4, "max_sta", 8, {}], ["to", "charm", 5, "plain:LCK", 10, {}],
		# Striking.
		["t", "signet", 1, "hit", 5, {}], ["t", "signet", 2, "art_hit", 10, {}],
		["h", "brooch", 1, "crit", 6, {}], ["h", "brooch", 1, "crit", 0, {"self_hp": 5}],
		["t", "fang", 1, "damage", 2, half], ["t", "fang", 1, "damage", 0, {}],
		["t", "horn", 1, "damage", 2, {}], ["t", "horn", 1, "damage", 2, {"actions": 1}], ["t", "horn", 1, "damage", 0, {"actions": 2}],
		["t", "torc", 5, "damage", "pos", {"self_low": true}], ["t", "torc", 5, "damage", 0, {}],
		["t", "sigil", 5, "damage", "pos", {"band": 0}], ["t", "sigil", 5, "damage", "pos", {"elite": true}],
		["t", "sigil", 5, "damage", 0, {}],
		["t", "talon", 1, "hit", 4, {"enemy_traits": ["Flying"]}], ["t", "talon", 1, "hit", 4, {"enemy_traits": ["Large"]}],
		["t", "talon", 2, "damage", 2, {"enemy_traits": ["Large"]}], ["t", "talon", 1, "hit", 0, {}],
		["t", "pin", 5, "damage", "pos", {}], ["t", "pin", 5, "spell_damage", 0, {}],
		# Standing.
		["t", "clasp", 1, "enemy_hit", -5, {}],
		["t", "gorget", 5, "taken", "neg", {}], ["t", "gorget", 5, "taken", 0, {"enemy_magic": true}],
		["t", "cameo", 5, "taken", "neg", {"guarding": true}], ["t", "cameo", 5, "taken", 0, {}],
		["t", "bell", 1, "aim", "pos", {"line": 2}], ["t", "veil", 1, "aim", "neg", {"line": 2}],
		["ho", "scarab", 5, "won_hp", "pos", {}],
		["h", "talisman", 1, "dot_hp", 1, {}], ["h", "talisman", 5, "dot_hp", 3, {}],
		["h", "locket", 1, "survive", 1, {}], ["h", "locket", 5, "survive", 16, {}], ["h", "locket", 5, "survive_twice", 0, {}],
		# Breath and tempo.
		["h", "beads", 1, "focus", 2, {}], ["h", "medal", 2, "kill_stamina", 4, {}], ["h", "claw", 1, "kill_hp", 2, {}],
		# Magic.
		["t", "tiara", 2, "uses_black_1", 2, {}], ["t", "tiara", 2, "uses_white_1", 2, {}], ["t", "tiara", 2, "uses_black_2", 0, {}],
		["t", "lens", 1, "spell_hit", 5, {}], ["t", "lens", 1, "hit", 0, {}],
		["t", "prism", 5, "spell_damage", "pos", {}], ["t", "prism", 5, "damage", 0, {}],
		["t", "rosary", 1, "heal_given", 2, {}], ["t", "reliquary", 1, "heal_received", 2, {"line": 2, "slot": 1}],
		# The line.
		["t", "lantern", 1, "hit", 3, {"line": 2, "holder": 0, "slot": 1}], ["t", "lantern", 1, "hit", 0, {"line": 2, "holder": 1, "slot": 1}],
		["t", "chain", 5, "taken", "neg", {"line": 2, "holder": 0, "slot": 1}], ["t", "chain", 5, "taken", 0, {"line": 2, "holder": 1, "slot": 1}],
		["h", "whistle", 1, "hit", 10, {"line": 2, "holder": 1, "slot": 0, "holder_kills": true}],
		["h", "dove", 1, "martyr", 4, {"line": 2, "holder": 0, "slot": 1}],
		# The road.
		["ho", "bangle", 1, "won_gold", 5, {}], ["to", "plume", 1, "xp", 6, {}], ["to", "tassel", 1, "drill_weapon", "pos", {}],
		["to", "acorn", 1, "growth:STR:2", 3, {}], ["ho", "compass", 1, "scav_score", "pos", {}],
		["to", "poultice", 5, "day_heal", "pos", {}],
		# Two-edged: what it gives grows with the stone, what it takes does not.
		["t", "skull", 1, "damage", 2, {}], ["t", "skull", 5, "damage", 6, {}], ["t", "skull", 5, "taken", 2, {}],
		["t", "mask", 1, "crit", 10, {}], ["t", "mask", 5, "hit", -10, {}],
		["t", "monocle", 1, "hit", 10, {}], ["t", "monocle", 5, "enemy_hit", 10, {}],
		["to", "shackle", 1, "plain:DEF", 2, {}], ["to", "shackle", 5, "plain:SPD", -2, {}],
		["to", "wing", 5, "plain:SPD", 6, {}], ["to", "wing", 1, "plain:DEF", -2, {}],
		["to", "crown", 1, "plain:MAG", 2, {}], ["t", "crown", 3, "uses_black_1", -1, {}],
	]


## Types tested by a test of their own rather than the table.
const OWN_TESTS: Array[String] = ["pin", "thorn", "talisman", "locket", "hourglass", "spur", "sigil", "tiara", "crown"]


# ---------------------------------------------------------------- data

func test_accessory_library() -> void:
	t.eq(_lib.types.size(), 54, "54 types")
	var counts := [0, 0, 0, 0, 0, 0, 0, 0]
	var ids := {}
	var names := {}
	for a in _lib.types:
		counts[a.family] += 1
		t.check(not ids.has(a.id) and not names.has(a.display_name), "%s: one of each" % a.id)
		ids[a.id] = true
		names[a.display_name] = true
		t.eq(a.gives.size(), 5, "%s: a line for each stone" % a.id)
		t.check(not a.effects.is_empty(), "%s: does something" % a.id)
		t.eq(a.takes != "", a.is_two_edged(), "%s: takes something only if two-edged" % a.id)
		for rank in range(1, 6):
			t.check(a.gives_line(rank) != "", "%s: line at %d" % [a.id, rank])
			t.eq(a.lines(rank).size(), 2 if a.is_two_edged() else 1, "%s: lines" % a.id)
			t.eq(a.trait_for(rank).modifiers.size(), a.effects.size(), "%s: every effect a modifier" % a.id)
	t.eq(counts, [11, 9, 8, 5, 5, 4, 6, 6], "the eight families")
	t.eq(AccessoryTypeData.FAMILY_NAMES[AccessoryTypeData.Family.TEMPO], "Breath and tempo", "family names")
	var ring := type_of("ring")
	t.eq(ring.gives_line(3), "+3 Strength", "a Ring's line")
	t.eq(ring.takes_line(), "", "takes nothing")
	t.eq(type_of("mask").takes_line(), "-10 Hit", "a Mask takes Hit")
	t.eq(type_of("mask").lines(2), ["+15 Crit", "-10 Hit"] as Array[String], "both lines")
	t.eq(type_of("cameo").gives_line(3), "Guard takes 70% off a blow", "a Cameo's line")
	var a := one("ring", 4)
	t.eq(a.title(), "Ruby Ring", "named by the stone")
	t.eq(one("lantern", 1).title(), "Topaz Lantern", "Topaz Lantern")
	t.eq(a.lines(), ["+4 Strength"] as Array[String], "its lines")
	t.eq(a.effect().display_name, "Ruby Ring", "its effect carries its name")
	t.eq(a.effect(), a.effect(), "made once")
	# The rank's value lands in the right field.
	t.eq(one("bell", 2).effect().modifiers[0].mult, 2.0, "Bell: a multiplier")
	var spur := one("spur", 3).effect().modifiers[0]
	t.eq([spur.amount, spur.action_to], [-1, 3], "Spur: 1 less for the first 3 actions")
	t.eq(one("skull", 4).effect().modifiers[1].amount, 2, "the Skull's price is fixed")


func test_accessory_table() -> void:
	for row: Array in table():
		var with_it: Array = [one(row[1], row[2])]
		var a := measure(row[0], with_it, row[3], row[5])
		var b := measure(row[0], [], row[3], row[5])
		var label := "%s %s: %s %s" % [Gem.name_of(row[2]), row[1], row[3], str(row[5])]
		match row[4]:
			"pos":
				t.check(a > b, "%s (%d vs %d)" % [label, a, b])
			"neg":
				t.check(a < b, "%s (%d vs %d)" % [label, a, b])
			_:
				t.eq(a - b, row[4], label)


func test_table_covers_library() -> void:
	var covered := {}
	for row: Array in table():
		covered[row[1]] = true
	for id in OWN_TESTS:
		covered[id] = true
	for a in _lib.types:
		t.check(covered.has(a.id), "%s is tested" % a.id)


# ---------------------------------------------------------------- the Jeweler

func test_jeweler_and_crafting() -> void:
	var run := free_run(81)
	var J := Run.Facility.JEWELER
	t.eq(Run.FACILITY_NAMES[J], "Jeweler", "a tenth facility")
	t.eq(Run.facility_lines(J, 1), "Opens crafting", "its first line")
	t.eq(Run.facility_lines(J, 2), "The jeweler shows two designs to choose from", "its second")
	t.eq(run.upgrade_cost(J), {RunConfig.IRON_ORE: 3}, "3 iron ore")
	t.eq(Run.FREE_ACTION_NAMES[Run.FreeAction.CRAFT], "Craft", "the action")
	t.eq(run.craft_block_reason(1), Run.NO_JEWELER, "not before the Jeweler")
	t.check(run.upgrade(J), "built")
	t.eq(run.upgrade_cost(J), {RunConfig.IRON_ORE: 5}, "level 2: 5 iron ore")
	t.eq(run.craft_block_reason(1), "No stones to set.", "no stones")
	run.add_gem(Gem.TOPAZ)
	t.eq(run.craft_block_reason(2), "No Sapphire to set.", "not a stone it lacks")
	t.eq(run.craft_cost(1), {"gem": 1, "gold": 20}, "Topaz: 20 gold")
	t.eq(run.craft_cost(5), {"gem": 5, "gold": 100}, "Diamond: 100")
	t.eq(RunConfig.CRAFT_GOLD_PER_RANK, 20, "20 a rank")
	run.gold = 19
	t.eq(run.craft_block_reason(1), "Needs 20 gold.", "the gold")
	run.gold = 1000
	t.eq(run.craft_block_reason(1), "", "open")
	var offer := run.craft(1)
	t.check(offer != null and run.craft_offer == offer, "an offer, kept")
	t.eq(offer.rank, 1, "a Topaz")
	t.eq(offer.designs.size(), 1, "level 1: one design")
	t.eq(run.gem_count(Gem.TOPAZ), 0, "the stone is spent")
	t.eq(run.gold, 980, "20 gold paid")
	t.eq(run.actions_left, 0, "the day's action")
	t.check(run.actions_used.has(Run.FreeAction.CRAFT), "recorded as the action")
	run.add_gem(Gem.TOPAZ)
	t.eq(run.craft_block_reason(1), Run.CRAFT_OPEN, "nothing else while it is open")
	t.check(run.take_craft(1) == null, "no second design at level 1")
	var a := run.take_craft(0)
	t.check(a != null and a.type == offer.designs[0] and a.rank == 1, "made")
	t.check(run.accessories.has(a), "the company's")
	t.check(run.wearer_of(a) == null, "unworn")
	t.check(run.craft_offer == null, "the offer closed")
	t.check(run.craft_block_reason(1) != "", "one craft a day: it is the action")
	# Level 2: two different designs; the day ending takes the first.
	t.check(run.end_free_day() or true, "the day ends")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event_days.erase(run.day)
	run._begin_day()
	t.check(run.upgrade(J), "level 2")
	offer = run.craft(1)
	t.eq(offer.designs.size(), 2, "two designs")
	t.check(offer.designs[0] != offer.designs[1], "different")
	var before := run.accessories.size()
	var first := offer.designs[0]
	run.end_free_day()
	t.eq(run.accessories.size(), before + 1, "the day ending makes one")
	t.eq(run.accessories[-1].type, first, "the first design")
	t.check(run.craft_offer == null, "and closes the offer")
	# Not on a fight day; not before the event.
	run.add_gem(Gem.TOPAZ)
	run.calendar[run.day - 1] = RunCalendar.DayType.BATTLE
	run._begin_day()
	t.eq(run.craft_block_reason(1), "Only on free days.", "free days only")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	if not run.event_days.has(run.day):
		run.event_days.append(run.day)
	run._begin_day()
	t.eq(run.craft_block_reason(1), Run.EVENT_FIRST, "the event first")


## Every type is drawn evenly, and the same type can come up again.
func test_craft_draw() -> void:
	var run := free_run(82)
	run.facilities[Run.Facility.JEWELER] = 2
	var counts := {}
	var n := 1620
	for i in n:
		run.actions_left = 1
		run.actions_used.clear()
		run.add_gem(Gem.TOPAZ)
		run.gold = 1000
		var offer := run.craft(1)
		for d in offer.designs:
			counts[d.id] = int(counts.get(d.id, 0)) + 1
		run.take_craft(0)
	t.eq(counts.size(), 54, "every type comes up")
	var want := 2.0 * n / 54
	for id: String in counts:
		t.check(absf(counts[id] - want) < want * 0.45, "%s drawn about evenly (%d, want %.0f)" % [id, counts[id], want])
	t.eq(run.accessories.size(), n, "all made")


# ---------------------------------------------------------------- wearing

func test_wear_rules() -> void:
	var run := free_run(83)
	var c := run.roster[0]
	var d := run.roster[1]
	var ring := one("ring", 2)
	var ring2 := one("ring", 5)
	var pendant := one("pendant", 3)
	var armlet := one("armlet", 1)
	for a in [ring, ring2, pendant, armlet]:
		run.accessories.append(a)
	t.eq(RunConfig.MAX_ACCESSORIES, 2, "two each")
	t.eq(run.wear_block_reason(c, one("ring", 1)), "Not the company's.", "only the company's")
	var str_before := int(c.progress.stats()[Stat.STR])
	t.check(run.wear(c, ring), "put on")
	t.eq(run.accessories_of(c), [ring] as Array[Accessory], "worn")
	t.eq(run.wearer_of(ring), c, "by them")
	t.eq(c.progress.accessory_stat_bonus(Stat.STR), 2, "the split: 2 STR from accessories")
	t.eq(int(c.progress.stats()[Stat.STR]), str_before + 2, "in the stats")
	t.check(run.wear_block_reason(c, ring2).contains("already wears a Ring"), "never two of one type")
	c.hp = 10
	var max_before := c.max_hp()
	t.check(run.wear(c, pendant), "a Pendant")
	t.eq(c.max_hp(), max_before + 9, "+9 max Health")
	t.eq(c.hp, 19, "HP rises by it")
	t.check(run.wear_block_reason(c, armlet).contains("two"), "at most two")
	t.eq(run.accessories_of(c), [ring, pendant] as Array[Accessory], "in the order put on")
	# Handed over.
	t.check(run.wear(d, ring), "to another")
	t.eq(run.wearer_of(ring), d, "they wear it now")
	t.eq(run.accessories_of(c), [pendant] as Array[Accessory], "taken from the first")
	t.eq(run.unworn_accessories(), [ring2, armlet] as Array[Accessory], "the unworn ones")
	# Taken off: HP held to the new max.
	c.hp = c.max_hp()
	t.check(run.take_off(pendant), "taken off")
	t.eq(c.max_hp(), max_before, "max Health back")
	t.eq(c.hp, c.max_hp(), "HP held to it")
	t.eq(run.take_off_block_reason(pendant), "Nobody wears it.", "not worn")
	t.check(run.accessories.has(pendant), "still the company's")
	# In battle: the unit has it.
	run.wear(c, ring2)
	run.day = 3
	run.calendar[2] = RunCalendar.DayType.BATTLE
	run._begin_day()
	if not run.lineup.has(c):
		run.field(c)
	var b := run.start_battle(run.fronts[0])
	var u := b.roster[run.lineup.find(c)]
	t.eq(u.stat(Stat.STR), int(c.progress.stats()[Stat.STR]) + int(c.weapon().held_stats.get(Stat.STR, 0)), "in battle")
	t.eq(run.wear_block_reason(d, armlet), "Not now.", "not once a front is committed")
	t.check(not run.take_off(ring2), "nor taken off")
	# The Infirmary: they keep it; it can be taken from them.
	run = free_run(84)
	c = run.roster[0]
	var amulet := one("amulet", 1)
	run.accessories.append(amulet)
	run.wear(c, amulet)
	run._to_infirmary(c)
	t.eq(run.accessories_of(c), [amulet] as Array[Accessory], "kept on in the Infirmary")
	t.check(run.take_off(amulet), "and taken off them")
	t.eq(c.hp, 0, "still injured")
	# A hire arrives with none.
	if run.tavern_offers.is_empty():
		run._make_tavern_offers()
	var hired := run.hire(run.tavern_offers[0])
	t.check(hired != null and run.accessories_of(hired).is_empty(), "a hire wears nothing")


# ---------------------------------------------------------------- the new rules

## A Pin: strikes ignore a share of DEF, added to a weapon's or art's own, at most 100.
func test_pin() -> void:
	var b := battle([one("pin", 5)])
	var plain := battle([])
	for x in [b, plain]:
		x.enemies[0].base_stats[Stat.DEF] = 10
	var u := b.roster[0]
	var e := b.enemies[0]
	t.eq(b.trait_strike(u, e, TraitModifier.Action.ATTACK).pierce, 40, "Diamond: 40%")
	t.eq(b.forecast(u, e).damage - plain.forecast(plain.roster[0], plain.enemies[0]).damage, 4, "4 of 10 DEF ignored")
	var art := CombatArtData.new()
	art.display_name = "Piercer"
	art.weapon_type = u.weapon().weapon_type
	art.ignore_def_percent = 80
	var whole := CombatArtData.new()
	whole.display_name = "Whole"
	whole.weapon_type = art.weapon_type
	whole.ignore_def_percent = 100
	t.eq(b.forecast(u, e, art).damage, plain.forecast(plain.roster[0], plain.enemies[0], whole).damage, "80% + 40%: capped at all of it")
	t.eq(b.spell_forecast(u, _tt.black_spell(), e).damage, plain.spell_forecast(plain.roster[0], _tt.black_spell(), plain.enemies[0]).damage,
		"not spells")


## A Thorn: an enemy whose blow lands takes the damage, and can be felled by it; not blows on the line.
func test_thorn() -> void:
	var b := battle([one("thorn", 2)])
	var u := b.roster[0]
	var e := b.enemies[0]
	var act: EnemyActionData = e.pending_action.duplicate()
	act.hit = 999
	var hp := e.hp
	b._enemy_strike(e, act, u)
	t.eq(e.hp, hp - 4, "Sapphire: 4 back")
	hp = e.hp
	b._enemy_strike(e, act, u, true)
	t.eq(e.hp, hp, "not from a blow on the whole line")
	act.hit = -999
	b._enemy_strike(e, act, u)
	t.eq(e.hp, hp, "not from a miss")
	act.hit = 999
	e.hp = 3
	u.hp = u.max_hp()
	b._enemy_strike(e, act, u)
	t.check(not e.is_alive(), "it can fell the enemy")
	t.eq(b.kills_of(u), 1, "the kill is theirs")


## A Talisman: damage over time cut, rounded down; Diamond: none.
func test_talisman() -> void:
	for pair: Array in [[0, 6], [1, 4], [3, 2], [5, 0]]:
		var b := battle([one("talisman", pair[0])] if pair[0] > 0 else [])
		var u := b.roster[0]
		var fx := StatusEffectData.new()
		fx.display_name = "Test Poison"
		fx.damage_per_tick = 6
		fx.duration_ticks = 3
		b._apply_effect(u, fx, false)
		var hp := u.hp
		b._damage_over_time(u)
		t.eq(hp - u.hp, pair[1], "rank %d: %d of 6" % pair)


## A Locket: once a battle, a felling blow leaves them at 1 (Topaz) or a share of max Health rounded up;
## with the trait that survives at 1, the higher, and both are used up.
func test_locket() -> void:
	var clings: Array[TraitData] = [TraitLibrary.load_default().find("clings_to_life")]
	for row: Array in [[1, [], 1], [2, [], 4], [4, [], 12], [1, clings, 1], [3, clings, 8]]:
		var b := battle([one("locket", row[0])], 1, 0, row[1])
		var u := b.roster[0]
		u.hp = 10
		b._damage_companion(u, 999, false)
		t.eq(u.hp, row[2], "rank %d%s: left at %d" % [row[0], " with Clings to Life" if not row[1].is_empty() else "", row[2]])
		b._damage_companion(u, 999, false)
		t.check(u.is_injured(), "once a battle")
	# At 1 Health already, a Locket still works (the trait alone does not).
	var b := battle([one("locket", 5)])
	var u := b.roster[0]
	u.hp = 1
	b._damage_companion(u, 999, false)
	t.eq(u.hp, 16, "Diamond from 1 Health: 40% of 40")


## An Hourglass: their first hit of a battle pushes the target's next action back; later hits do not.
func test_hourglass() -> void:
	var b := battle([one("hourglass", 3)])
	var u := b.roster[0]
	var e := b.enemies[0]
	var before := e.countdown
	b._companion_strike(u, e, null)
	t.eq(e.countdown, before + 3, "Emerald: 3 turns")
	t.check(e.delayed, "shown as delayed")
	e.delayed = false
	before = e.countdown
	b._companion_strike(u, e, null)
	t.eq(e.countdown, before, "only the first hit")
	# A first spell that hits counts too.
	b = battle([one("hourglass", 1)])
	u = b.roster[0]
	e = b.enemies[0]
	var bolt: SpellData = _tt.black_spell()
	bolt.hit = 999
	before = e.countdown
	b._spell_strike(u, bolt, e)
	t.eq(e.countdown, before + 1, "a spell's first hit")


## A Spur: their first actions of a battle have 1 less recovery (any action), never below 0.
func test_spur() -> void:
	var b := battle([one("spur", 2)])
	var u := b.roster[0]
	for n in 4:
		u.actions_taken = n
		t.eq(b.action_recovery(u, 2, TraitModifier.Action.ATTACK), 1 if n < 2 else 2, "action %d" % (n + 1))
	u.actions_taken = 0
	t.eq(b.action_recovery(u, 0), 0, "never below 0")
	var art := CombatArtData.new()
	art.display_name = "Slow Cut"
	art.weapon_type = u.weapon().weapon_type
	art.recovery = 3
	t.eq(b.art_recovery(u, art), 2, "an art too")
	var plain := battle([])
	t.eq(plain.action_recovery(plain.roster[0], 2, TraitModifier.Action.ATTACK), 2, "without it, as before")


## Sigil: an elite day's battle counts every enemy as a boss (Run.start_battle sets Battle.elite).
func test_sigil_in_an_elite_fight() -> void:
	var run := make_run(85)
	run.day = 6
	run._begin_day()
	t.eq(run.day_type(), RunCalendar.DayType.ELITE, "day 6")
	var b := run.start_battle(run.fronts[0])
	t.check(b.elite, "the battle knows it is an elite fight")
	run = make_run(86)
	run.day = 3
	run.calendar[2] = RunCalendar.DayType.BATTLE
	run._begin_day()
	t.check(not run.start_battle(run.fronts[0]).elite, "a battle is not")


## Tiara adds uses of tier I spells; Crown takes one from every spell, never below 1. Put on, the uses
## left rise by what it adds; taken off, they are held to the new most.
func test_crown_and_tiara_uses() -> void:
	var one_use: SpellData = _tt.black_spell(2)
	one_use.uses = 1
	var p := CompanionProgress.create(_tt.data())
	p.accessories = [one("crown", 1)]
	t.eq(p.max_uses(one_use), 1, "never below 1")
	t.eq(p.max_uses(_tt.black_spell(1)), 5, "6 less 1")
	var run := free_run(87)
	var c := run.roster[0]
	var bolt: SpellData = _tt.black_spell(1)
	c.progress.learn_spell(bolt)
	t.eq(c.progress.uses_left(bolt), 6, "6 uses")
	var tiara := one("tiara", 3)
	run.accessories.append(tiara)
	run.wear(c, tiara)
	t.eq(c.progress.max_uses(bolt), 9, "Emerald Tiara: +3")
	t.eq(c.progress.uses_left(bolt), 9, "the uses rise with it")
	run.take_off(tiara)
	t.eq(c.progress.uses_left(bolt), 6, "held to the most without it")
