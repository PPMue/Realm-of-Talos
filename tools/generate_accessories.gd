extends SceneTree
## Writes the 54 accessory types of design/accessories.md as .tres files under res://data/accessories/
## and the library listing them (res://data/accessories/accessory_library.tres). Every file is written
## again each time (they hold no hand edits).
##
##   godot --headless --path . -s res://tools/generate_accessories.gd

const OUT := "res://data/accessories"
const FAMILY_DIRS: Array[String] = ["plain", "striking", "standing", "tempo", "magic", "the_line", "the_road",
	"two_edged"]
const K := TraitModifier.Kind
const F := AccessoryTypeData.Family
const ONE_TO_FIVE := [1, 2, 3, 4, 5]
const TWO_TO_TEN := [2, 4, 6, 8, 10]
const FIVE_TO_25 := [5, 10, 15, 20, 25]
const SIX_TO_30 := [6, 12, 18, 24, 30]
const TWO_TO_SIX := [2, 3, 4, 5, 6]

var _all: Array[AccessoryTypeData] = []


func _init() -> void:
	_plain()
	_striking()
	_standing()
	_tempo()
	_magic()
	_the_line()
	_the_road()
	_two_edged()
	var lib := AccessoryLibrary.new()
	for a in _all:
		var dir := "%s/%s" % [OUT, FAMILY_DIRS[a.family]]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var path := "%s/%s.tres" % [dir, a.id]
		var err := ResourceSaver.save(a, path)
		if err != OK:
			printerr("could not save %s: %d" % [path, err])
		lib.types.append(load(path) as AccessoryTypeData)
	var err := ResourceSaver.save(lib, "%s/accessory_library.tres" % OUT)
	print("wrote %d accessory types (%s)" % [_all.size(), "ok" if err == OK else "error %d" % err])
	quit()


# ---------------------------------------------------------------- building blocks

## An effect whose `field` takes `values` (Topaz..Diamond).
func eff(kind: int, values: Array, props: Dictionary = {}, field: AccessoryEffect.Field = AccessoryEffect.Field.AMOUNT) -> AccessoryEffect:
	var e := AccessoryEffect.new()
	e.modifier = _mod(kind, 0, props)
	var by: Array[float] = []
	for v in values:
		by.append(float(v))
	e.by_rank = by
	e.field = field
	return e


## An effect fixed at `amount` whatever the stone (a two-edged type's price).
func fixed(kind: int, amount: int, props: Dictionary = {}) -> AccessoryEffect:
	var e := AccessoryEffect.new()
	e.modifier = _mod(kind, amount, props)
	return e


func _mod(kind: int, amount: int, props: Dictionary) -> TraitModifier:
	var m := TraitModifier.new()
	m.kind = kind
	m.amount = amount
	for key: String in props:
		m.set(key, props[key])
	return m


## Five lines from `fmt` and the values (each value given to `fmt` alone, or as an array of several).
func lines(fmt: String, values: Array) -> Array[String]:
	var out: Array[String] = []
	for v in values:
		out.append(fmt % v)
	return out


func add(id: String, display_name: String, family: int, gives: Array[String], effects: Array, takes: String = "") -> void:
	var a := AccessoryTypeData.new()
	a.id = id
	a.display_name = display_name
	a.family = family
	a.gives = gives
	a.takes = takes
	for e in effects:
		a.effects.append(e)
	_all.append(a)


func stat(id: String, display_name: String, key: String, values: Array) -> void:
	add(id, display_name, F.PLAIN, lines("+%d " + Stat.NAMES[key], values), [eff(K.STAT, values, {"stat": key})])


# ---------------------------------------------------------------- the eight families

func _plain() -> void:
	stat("ring", "Ring", Stat.STR, ONE_TO_FIVE)
	stat("circlet", "Circlet", Stat.MAG, ONE_TO_FIVE)
	stat("bracelet", "Bracelet", Stat.DEX, ONE_TO_FIVE)
	stat("anklet", "Anklet", Stat.SPD, ONE_TO_FIVE)
	stat("armlet", "Armlet", Stat.DEF, ONE_TO_FIVE)
	stat("amulet", "Amulet", Stat.RES, ONE_TO_FIVE)
	stat("earring", "Earring", Stat.CRT, ONE_TO_FIVE)
	stat("buckle", "Buckle", Stat.BLD, ONE_TO_FIVE)
	stat("pendant", "Pendant", Stat.HP, [3, 6, 9, 12, 15])
	stat("girdle", "Girdle", Stat.STA, TWO_TO_TEN)
	stat("charm", "Charm", Stat.LCK, TWO_TO_TEN)


func _striking() -> void:
	add("signet", "Signet", F.STRIKING, lines("+%d Hit", FIVE_TO_25), [eff(K.HIT, FIVE_TO_25)])
	add("brooch", "Brooch", F.STRIKING, lines("+%d Crit while at full Health", SIX_TO_30),
		[eff(K.CRIT, SIX_TO_30, {"self_health": TraitModifier.Health.FULL})])
	add("fang", "Fang", F.STRIKING, lines("+%d damage to enemies below half Health", TWO_TO_TEN),
		[eff(K.DAMAGE, TWO_TO_TEN, {"target_health": TraitModifier.Health.BELOW_HALF})])
	add("horn", "Horn", F.STRIKING, lines("+%d damage on their first two actions of a battle", TWO_TO_TEN),
		[eff(K.DAMAGE, TWO_TO_TEN, {"action_to": 2})])
	add("torc", "Torc", F.STRIKING, lines("+%d%% damage while below half Health", [8, 16, 24, 32, 40]),
		[eff(K.DAMAGE_PERCENT, [8, 16, 24, 32, 40], {"self_health": TraitModifier.Health.BELOW_HALF})])
	add("sigil", "Sigil", F.STRIKING, lines("+%d%% damage against a boss, and in an elite fight", SIX_TO_30),
		[eff(K.DAMAGE_PERCENT, SIX_TO_30, {"big_fight": true})])
	add("talon", "Talon", F.STRIKING,
		lines("+%d Hit and +%d damage against Flying and Large enemies", [[4, 1], [8, 2], [12, 3], [16, 4], [20, 5]]),
		[eff(K.HIT, [4, 8, 12, 16, 20], {"target_trait": "Flying|Large"}),
		eff(K.DAMAGE, ONE_TO_FIVE, {"target_trait": "Flying|Large"})])
	add("pin", "Pin", F.STRIKING, lines("Their strikes ignore %d%% of the enemy's Defence", [8, 16, 24, 32, 40]),
		[eff(K.PIERCE_PERCENT, [8, 16, 24, 32, 40])])
	add("thorn", "Thorn", F.STRIKING, lines("An enemy whose blow hits them takes %d damage", TWO_TO_TEN),
		[eff(K.THORNS, TWO_TO_TEN)])


func _standing() -> void:
	add("clasp", "Clasp", F.STANDING, lines("+%d Avoid", FIVE_TO_25), [eff(K.AVOID, FIVE_TO_25)])
	add("gorget", "Gorget", F.STANDING, lines("Physical blows deal %d%% less to them", SIX_TO_30),
		[eff(K.DAMAGE_TAKEN_PERCENT, [-6, -12, -18, -24, -30], {"blow": TraitModifier.Blow.PHYSICAL})])
	add("cameo", "Cameo", F.STANDING, lines("Guard takes %d%% off a blow", [60, 65, 70, 75, 80]),
		[eff(K.GUARD_PERCENT, [60, 65, 70, 75, 80])])
	add("bell", "Bell", F.STANDING, lines("Enemies aim at them %s times as often", ["1.5", "2", "2.5", "3", "3.5"]),
		[eff(K.AIM, [1.5, 2.0, 2.5, 3.0, 3.5], {}, AccessoryEffect.Field.MULT)])
	add("veil", "Veil", F.STANDING, lines("Enemies aim at them %s as often", ["0.8 times", "0.65 times", "half", "0.4 times", "0.3 times"]),
		[eff(K.AIM, [0.8, 0.65, 0.5, 0.4, 0.3], {}, AccessoryEffect.Field.MULT)])
	add("scarab", "Scarab", F.STANDING, lines("After a battle won, still standing: heals %d%% of their Health", [10, 20, 30, 40, 50]),
		[eff(K.BATTLE_WON_HEAL_PERCENT, [10, 20, 30, 40, 50])])
	var talisman: Array[String] = lines("Poison and burning deal %d%% less to them", [20, 40, 60, 80])
	talisman.append("Poison and burning cannot hurt them")
	add("talisman", "Talisman", F.STANDING, talisman, [eff(K.DOT_TAKEN_PERCENT, [-20, -40, -60, -80, -100])])
	var locket: Array[String] = ["Once a battle, a blow that would fell them leaves them at 1 Health"]
	locket.append_array(lines("Once a battle, a blow that would fell them leaves them at %d%% of their Health", [10, 20, 30, 40]))
	add("locket", "Locket", F.STANDING, locket, [eff(K.SURVIVE_SHARE, [0, 10, 20, 30, 40])])


func _tempo() -> void:
	add("beads", "Beads", F.TEMPO, lines("Focus restores %d more stamina", TWO_TO_TEN), [eff(K.FOCUS_RESTORE, TWO_TO_TEN)])
	add("medal", "Medal", F.TEMPO, lines("+%d stamina when they fell an enemy", TWO_TO_TEN), [eff(K.KILL_STAMINA, TWO_TO_TEN)])
	add("claw", "Claw", F.TEMPO, lines("+%d Health when they fell an enemy", TWO_TO_TEN), [eff(K.KILL_HP, TWO_TO_TEN)])
	var spur: Array[String] = ["Their first action of a battle has 1 less recovery"]
	spur.append_array(lines("Their first %d actions of a battle have 1 less recovery", [2, 3, 4, 5]))
	var spur_eff := eff(K.RECOVERY, ONE_TO_FIVE, {}, AccessoryEffect.Field.ACTION_TO)
	spur_eff.modifier.amount = -1
	add("spur", "Spur", F.TEMPO, spur, [spur_eff])
	var hourglass: Array[String] = ["Their first hit of a battle pushes the target's next action back 1 turn"]
	hourglass.append_array(lines("Their first hit of a battle pushes the target's next action back %d turns", [2, 3, 4, 5]))
	add("hourglass", "Hourglass", F.TEMPO, hourglass, [eff(K.FIRST_HIT_DELAY, ONE_TO_FIVE)])


func _magic() -> void:
	var tiara: Array[String] = ["+1 use of every tier I spell"]
	tiara.append_array(lines("+%d uses of every tier I spell", [2, 3, 4, 5]))
	add("tiara", "Tiara", F.MAGIC, tiara, [eff(K.SPELL_USES, ONE_TO_FIVE, {"spell_tier": 1})])
	add("lens", "Lens", F.MAGIC, lines("+%d Hit with spells", FIVE_TO_25),
		[eff(K.HIT, FIVE_TO_25, {"action": TraitModifier.Action.SPELL})])
	add("prism", "Prism", F.MAGIC, lines("Spells deal %d%% more damage", SIX_TO_30),
		[eff(K.DAMAGE_PERCENT, SIX_TO_30, {"action": TraitModifier.Action.SPELL})])
	add("rosary", "Rosary", F.MAGIC, lines("Heals they cast restore %d more", TWO_TO_TEN), [eff(K.HEAL_GIVEN, TWO_TO_TEN)])
	add("reliquary", "Reliquary", F.MAGIC, lines("White magic heals them %d more", TWO_TO_TEN), [eff(K.HEAL_RECEIVED, TWO_TO_TEN)])


func _the_line() -> void:
	add("lantern", "Lantern", F.THE_LINE, lines("Every other companion in the line has +%d Hit", [3, 6, 9, 12, 15]),
		[eff(K.HIT, [3, 6, 9, 12, 15], {"who": TraitModifier.Who.ALLIES})])
	add("chain", "Chain", F.THE_LINE, lines("The companions either side of them take %d%% less damage", FIVE_TO_25),
		[eff(K.DAMAGE_TAKEN_PERCENT, [-5, -10, -15, -20, -25], {"who": TraitModifier.Who.NEIGHBOURS})])
	add("whistle", "Whistle", F.THE_LINE, lines("After they fell an enemy, the next ally to act has +%d Hit", [10, 20, 30, 40, 50]),
		[eff(K.KILL_NEXT_ALLY_HIT, [10, 20, 30, 40, 50])])
	add("dove", "Dove", F.THE_LINE, lines("When they are injured, every ally standing heals %d", [4, 8, 12, 16, 20]),
		[eff(K.INJURED_HEAL_ALLIES, [4, 8, 12, 16, 20])])


func _the_road() -> void:
	add("bangle", "Bangle", F.THE_ROAD, lines("+%d gold after a battle won in which they fought", FIVE_TO_25),
		[eff(K.BATTLE_WON_GOLD, FIVE_TO_25)])
	add("plume", "Plume", F.THE_ROAD, lines("+%d%% XP", SIX_TO_30), [eff(K.XP_PERCENT, SIX_TO_30)])
	add("tassel", "Tassel", F.THE_ROAD, lines("+%d%% weapon and magic points", [20, 40, 60, 80, 100]),
		[eff(K.PROFICIENCY_PERCENT, [20, 40, 60, 80, 100])])
	add("acorn", "Acorn", F.THE_ROAD, lines("+%d to every growth rate", [3, 6, 9, 12, 15]),
		[eff(K.GROWTH, [3, 6, 9, 12, 15])])
	add("compass", "Compass", F.THE_ROAD, lines("Scavenging: counts as %d higher in whatever is asked", ONE_TO_FIVE),
		[eff(K.SCAVENGE_STAT, ONE_TO_FIVE)])
	add("poultice", "Poultice", F.THE_ROAD, lines("Heals %d%% more at the day's end", [20, 40, 60, 80, 100]),
		[eff(K.DAY_HEAL_PERCENT, [20, 40, 60, 80, 100])])


func _two_edged() -> void:
	add("skull", "Skull", F.TWO_EDGED, lines("+%d damage on every blow", TWO_TO_SIX),
		[eff(K.DAMAGE, TWO_TO_SIX), fixed(K.DAMAGE_TAKEN, 2)], "Enemy blows deal 2 more to them")
	add("mask", "Mask", F.TWO_EDGED, lines("+%d Crit", [10, 15, 20, 25, 30]),
		[eff(K.CRIT, [10, 15, 20, 25, 30]), fixed(K.HIT, -10)], "-10 Hit")
	add("monocle", "Monocle", F.TWO_EDGED, lines("+%d Hit", [10, 15, 20, 25, 30]),
		[eff(K.HIT, [10, 15, 20, 25, 30]), fixed(K.AVOID, -10)], "-10 Avoid")
	add("shackle", "Shackle", F.TWO_EDGED, lines("+%d Defence", TWO_TO_SIX),
		[eff(K.STAT, TWO_TO_SIX, {"stat": Stat.DEF}), fixed(K.STAT, -2, {"stat": Stat.SPD})], "-2 Speed")
	add("wing", "Wing", F.TWO_EDGED, lines("+%d Speed", TWO_TO_SIX),
		[eff(K.STAT, TWO_TO_SIX, {"stat": Stat.SPD}), fixed(K.STAT, -2, {"stat": Stat.DEF})], "-2 Defence")
	add("crown", "Crown", F.TWO_EDGED, lines("+%d Magic", TWO_TO_SIX),
		[eff(K.STAT, TWO_TO_SIX, {"stat": Stat.MAG}), fixed(K.SPELL_USES_LOSS, 1)],
		"Every spell has 1 fewer use (never below 1)")
