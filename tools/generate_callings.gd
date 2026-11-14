extends SceneTree
## Writes the twelve callings (design/callings.md), each with its two masteries, as .tres under
## res://data/callings/ and the library listing them (res://data/callings/calling_library.tres).
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
	var A := TraitModifier.Action
	add("warden", "Warden", "Guard has no recovery.", Stat.DEF, Stat.HP, Stat.SPD,
		[mod(K.RECOVERY, -9, {"action": A.GUARD})])
	master("wide_shield", "Wide Shield", "Can guard anyone in the line, not only a neighbour.", [mod(K.GUARD_ANYONE, 1)])
	master("answering_blow", "Answering Blow", "A blow caught for another is answered with their Attack.", [mod(K.COVER_ANSWERS, 1)])
	add("champion", "Champion", "An enemy they strike turns its coming blow on them.", Stat.HP, Stat.DEF, Stat.DEX,
		[mod(K.STRIKE_TURNS_AIM, 1)])
	master("iron_stance", "Iron Stance", "Takes a quarter less from a blow they turned.",
		[mod(K.DAMAGE_TAKEN_PERCENT, -25, {"aim_turned": true})])
	master("first_challenge", "First Challenge", "When a battle begins, every blow already aimed is aimed at them.",
		[mod(K.OPENING_AIM, 1)])
	add("executioner", "Executioner",
		"A strike or spell that leaves an enemy at a fifth of its Health or less fells it (a boss: a tenth).",
		L, Stat.CRT, Stat.DEF, [mod(K.EXECUTE_PERCENT, 20)])
	master("deep_cut", "Deep Cut", "At a quarter of its Health or less (a boss: an eighth).", [mod(K.EXECUTE_PERCENT, 5)])
	master("next_one", "The Next One", "Felling an enemy, they are ready at once.", [mod(K.KILL_NO_RECOVERY, 1)])
	add("skirmisher", "Skirmisher", "Their plain Attack has Recovery 1.", Stat.SPD, Stat.DEX, Stat.HP,
		[mod(K.RECOVERY, -1, {"action": A.ATTACK})])
	master("light_hands", "Light Hands", "Their tier I arts have Recovery 1 too.",
		[mod(K.RECOVERY_AT_MOST, 1, {"action": A.ART, "spell_tier": 1})])
	master("first_in", "First In", "Their first action of a battle has no recovery.", [mod(K.RECOVERY, -9, {"action_to": 1})])
	add("captain", "Captain", "A new order, Rouse: a companion who is recovering is ready at once.",
		Stat.RES, Stat.DEF, Stat.CRT, [mod(K.ORDER_ROUSE, 1)])
	master("clear_order", "Clear Order", "The one roused cannot miss with their next action.", [mod(K.ROUSE_SURE_HIT, 1)])
	master("quick_word", "Quick Word", "Rouse has Recovery 1.", [mod(K.RECOVERY, -1, {"action": A.ROUSE})])
	add("harrier", "Harrier", "Every strike or spell of theirs that lands staggers: the action comes 1 turn later.",
		Stat.DEX, L, Stat.RES, [mod(K.HIT_DELAY, 1)])
	master("no_rest", "No Rest", "Can push back an action already pushed back, once more.", [mod(K.DELAY_AGAIN, 1)])
	master("off_balance", "Off Balance", "A staggered enemy takes a quarter more damage until it acts.",
		[mod(K.STAGGERED_DAMAGE_PERCENT, 25)])
	add("hunter", "Hunter", "Whatever they land on an enemy with 1 turn left is critical.", L, Stat.DEX, Stat.HP,
		[mod(K.SURE_CRIT, 1, {"target_turns_at_most": 1})])
	master("long_watch", "Long Watch", "With 2 turns left or fewer.", [mod(K.SURE_CRIT, 1, {"target_turns_at_most": 2})])
	master("sure_shot", "Sure Shot", "Such a blow cannot miss.", [mod(K.SURE_HIT, 1, {"target_turns_at_most": 1})])
	add("berserker", "Berserker", "Their arts cost Health, half as much, in place of stamina.", L, Stat.HP, Stat.DEX,
		[mod(K.ART_COSTS_HEALTH, 50)])
	master("red_mist", "Red Mist", "Below half Health, they deal a quarter more damage.",
		[mod(K.DAMAGE_PERCENT, 25, {"self_health": TraitModifier.Health.BELOW_HALF})])
	master("blood_price", "Blood Price", "Felling an enemy heals a fifth of their Health.", [mod(K.KILL_HP_PERCENT, 20)])
	add("mender", "Mender", "Once a battle, their healing spell can raise an injured companion, at a quarter of their Health.",
		Stat.MAG, Stat.RES, Stat.STR, [mod(K.RAISE_ONCE, 25)], WHITE, false, true)
	master("open_hands", "Open Hands", "Their heal on one ally reaches that ally's neighbours, at half.", [mod(K.HEAL_SPREADS, 50)])
	master("second_breath", "Second Breath", "Twice a battle.", [mod(K.RAISE_MORE, 1)])
	add("hexer", "Hexer", "When an enemy carrying their poison, bleeding or curse falls, it passes to another enemy.",
		Stat.MAG, Stat.DEX, Stat.STR, [mod(K.EFFECTS_PASS_ON, 1)], BLACK)
	master("long_curse", "Long Curse", "Their effects on enemies last 2 turns longer.", [mod(K.HEX_TURNS, 2)])
	master("clouded_eyes", "Clouded Eyes", "Enemies under their effects have 20 less Hit.", [mod(K.HEXED_HIT, 20)])
	add("sage", "Sage", "Their first spell of each battle costs no use.", Stat.MAG, Stat.CRT, Stat.DEF,
		[mod(K.FIRST_SPELL_FREE, 1)], -1, true)
	master("ready_word", "Ready Word", "That first spell has no recovery either.",
		[mod(K.RECOVERY, -9, {"action": A.SPELL, "first_spell": true})])
	master("quick_tongue", "Quick Tongue", "Every spell of theirs has 1 less recovery.", [mod(K.RECOVERY, -1, {"action": A.SPELL})])
	add("spellblade", "Spellblade", "Their weapon strikes are against the lower of the target's Defence and Resistance.",
		O, L, Stat.HP, [mod(K.STRIKE_LOWER_DEFENSE, 1)], BLACK)
	master("spell_into_steel", "Spell into Steel", "A weapon strike right after a spell has no recovery.",
		[mod(K.RECOVERY, -9, {"action": A.ATTACK, "after_spell": true}), mod(K.RECOVERY, -9, {"action": A.ART, "after_spell": true})])
	master("steel_into_spell", "Steel into Spell", "A weapon strike that fells an enemy gives one spell use back.",
		[mod(K.STRIKE_KILL_SPELL_USE, 1)])
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


## A mastery of the calling added last (two each).
func master(id: String, display_name: String, rule: String, modifiers: Array) -> void:
	var c := _all[_all.size() - 1]
	var m := MasteryData.new()
	m.id = "%s_%s" % [c.id, id]
	m.display_name = display_name
	m.rule = rule
	m.modifiers.assign(modifiers)
	c.masteries.append(m)
