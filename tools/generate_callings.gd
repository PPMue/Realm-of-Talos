extends SceneTree
## Writes the twelve callings (design/callings.md) as .tres under res://data/callings/ and the library
## listing them (res://data/callings/calling_library.tres).
##
##   godot --headless --path . -s res://tools/generate_callings.gd

const OUT := "res://data/callings"

var _all: Array[CallingData] = []


func _init() -> void:
	var K := TraitModifier.Kind
	var L := CallingData.LEAD
	var O := CallingData.OTHER
	var BLACK := SpellData.School.BLACK
	var WHITE := SpellData.School.WHITE
	add("warden", "Warden", "Guard has no recovery.", Stat.DEF, Stat.HP, Stat.SPD,
		[mod(K.RECOVERY, -9, {"action": TraitModifier.Action.GUARD})])
	add("champion", "Champion", "An enemy they strike turns its coming blow on them.", Stat.HP, Stat.DEF, Stat.DEX,
		[mod(K.STRIKE_TURNS_AIM, 1)])
	add("executioner", "Executioner",
		"A strike or spell that leaves an enemy at a fifth of its Health or less fells it (a boss: a tenth).",
		L, Stat.CRT, Stat.DEF, [mod(K.EXECUTE_PERCENT, 20)])
	add("skirmisher", "Skirmisher", "Their plain Attack has Recovery 1.", Stat.SPD, Stat.DEX, Stat.HP,
		[mod(K.RECOVERY, -1, {"action": TraitModifier.Action.ATTACK})])
	add("captain", "Captain", "A new order, Rouse: a companion who is recovering is ready at once.",
		Stat.RES, Stat.DEF, Stat.CRT, [mod(K.ORDER_ROUSE, 1)])
	add("harrier", "Harrier", "Every strike or spell of theirs that lands staggers: the action comes 1 turn later.",
		Stat.DEX, L, Stat.RES, [mod(K.HIT_DELAY, 1)])
	add("hunter", "Hunter", "Whatever they land on an enemy with 1 turn left is critical.", L, Stat.DEX, Stat.HP,
		[mod(K.SURE_CRIT, 1, {"target_turns_at_most": 1})])
	add("berserker", "Berserker", "Their arts cost Health, half as much, in place of stamina.", L, Stat.HP, Stat.DEX,
		[mod(K.ART_COSTS_HEALTH, 50)])
	add("mender", "Mender", "Once a battle, their healing spell can raise an injured companion, at a quarter of their Health.",
		Stat.MAG, Stat.RES, Stat.STR, [mod(K.RAISE_ONCE, 25)], WHITE, false, true)
	add("hexer", "Hexer", "When an enemy carrying their poison, bleeding or curse falls, it passes to another enemy.",
		Stat.MAG, Stat.DEX, Stat.STR, [mod(K.EFFECTS_PASS_ON, 1)], BLACK)
	add("sage", "Sage", "Their first spell of each battle costs no use.", Stat.MAG, Stat.CRT, Stat.DEF,
		[mod(K.FIRST_SPELL_FREE, 1)], -1, true)
	add("spellblade", "Spellblade", "Their weapon strikes are against the lower of the target's Defence and Resistance.",
		O, L, Stat.HP, [mod(K.STRIKE_LOWER_DEFENSE, 1)], BLACK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lib := CallingLibrary.new()
	for c in _all:
		var path := "%s/%s.tres" % [OUT, c.id]
		var err := ResourceSaver.save(c, path)
		if err != OK:
			printerr("could not save %s: %d" % [path, err])
		lib.callings.append(load(path) as CallingData)
	var err := ResourceSaver.save(lib, "%s/calling_library.tres" % OUT)
	print("wrote %d callings (%s)" % [_all.size(), "ok" if err == OK else "error %d" % err])
	quit()


func mod(kind: TraitModifier.Kind, amount: int = 0, props: Dictionary = {}) -> TraitModifier:
	var m := TraitModifier.new()
	m.kind = kind
	m.amount = amount
	for key: String in props:
		m.set(key, props[key])
	return m


func add(id: String, display_name: String, rule: String, first: String, second: String, slow: String,
		modifiers: Array, school: int = -1, either: bool = false, needs_heal: bool = false) -> void:
	var c := CallingData.new()
	c.id = id
	c.display_name = display_name
	c.rule = rule
	c.first_stat = first
	c.second_stat = second
	c.slow_stat = slow
	c.school = school
	c.either_school = either
	c.needs_heal = needs_heal
	c.modifiers.assign(modifiers)
	_all.append(c)
