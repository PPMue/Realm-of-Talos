extends SceneTree
## Writes every trait built so far (design/traits.md, wave 1) as a .tres under res://data/traits/ and
## the library listing them (res://data/traits/trait_library.tres). Run it again after changing a
## trait here; a trait can also be written as a .tres by hand and added to the library.
##
##   godot --headless --path . -s res://tools/generate_traits.gd

const OUT := "res://data/traits"
const FAMILY_DIRS: Array[String] = ["weapon_hands", "schools", "body_and_mind", "two_edged", "the_line",
	"tempo", "staying_alive", "learning", "the_city", "the_company"]

var _all: Array[TraitData] = []


func _init() -> void:
	_weapon_hands()
	_schools()
	_body_and_mind()
	_two_edged()
	_the_line()
	_tempo()
	_learning()
	var lib := TraitLibrary.new()
	for t in _all:
		var dir := "%s/%s" % [OUT, FAMILY_DIRS[t.family]]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var path := "%s/%s.tres" % [dir, t.id]
		var err := ResourceSaver.save(t, path)
		if err != OK:
			printerr("could not save %s: %d" % [path, err])
		t.take_over_path(path)
		lib.traits.append(load(path) as TraitData)
	var err := ResourceSaver.save(lib, "%s/trait_library.tres" % OUT)
	print("wrote %d traits (%s)" % [_all.size(), "ok" if err == OK else "error %d" % err])
	quit()


# ---------------------------------------------------------------- building blocks

func mod(kind: TraitModifier.Kind, amount: int = 0, props: Dictionary = {}) -> TraitModifier:
	var m := TraitModifier.new()
	m.kind = kind
	m.amount = amount
	for key: String in props:
		m.set(key, props[key])
	return m


func stat(key: String, amount: int, props: Dictionary = {}) -> TraitModifier:
	var p := props.duplicate()
	p["stat"] = key
	return mod(TraitModifier.Kind.STAT, amount, p)


func aim(mult: float) -> TraitModifier:
	return mod(TraitModifier.Kind.AIM, 0, {"mult": mult})


func add(id: String, display_name: String, family: TraitData.Family, rarity: TraitData.Rarity,
		gives: Array, takes: Array, mods: Array, extra: Dictionary = {}) -> TraitData:
	var t := TraitData.new()
	t.id = id
	t.display_name = display_name
	t.family = family
	t.rarity = rarity
	t.gives.assign(gives)
	t.takes.assign(takes)
	t.modifiers.assign(mods)
	for key: String in extra:
		t.set(key, extra[key])
	_all.append(t)
	return t


# ---------------------------------------------------------------- 1. weapon hands

func _weapon_hands() -> void:
	var plural := ["swords", "axes", "spears", "bows", "daggers"]
	for wt: int in WeaponData.WeaponType.values():
		var name := WeaponData.type_name(wt)
		var low := name.to_lower()
		var w := {"weapon_type": wt}
		var tied := {"weapon_type": wt}
		var F := TraitData.Family.WEAPON_HANDS
		var C := TraitData.Rarity.COMMON
		add("%s_sure" % low, "%s: Sure" % name, F, C, ["+10 Hit with %s" % plural[wt]], [],
			[mod(TraitModifier.Kind.HIT, 10, w)], _with(tied, "line", "Sure"))
		add("%s_heavy" % low, "%s: Heavy" % name, F, C, ["+2 damage with %s" % plural[wt]], [],
			[mod(TraitModifier.Kind.DAMAGE, 2, w)], _with(tied, "line", "Heavy"))
		add("%s_keen" % low, "%s: Keen" % name, F, C, ["+8 Crit with %s" % plural[wt]], [],
			[mod(TraitModifier.Kind.CRIT, 8, w)], _with(tied, "line", "Keen"))
		add("%s_easy" % low, "%s: Easy" % name, F, C, ["%s arts cost 1 less stamina" % name], [],
			[mod(TraitModifier.Kind.ART_STAMINA, -1, w)], _with(tied, "line", "Easy"))
		add("%s_apt" % low, "%s: Apt" % name, F, C, ["+50%% proficiency points with %s" % plural[wt]], [],
			[mod(TraitModifier.Kind.PROFICIENCY_PERCENT, 50, w)], _with(tied, "line", "Apt"))


func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate()
	out[key] = value
	return out


# ---------------------------------------------------------------- 2. schools of magic

func _schools() -> void:
	var F := TraitData.Family.SCHOOLS
	var C := TraitData.Rarity.COMMON
	var B := SpellData.School.BLACK
	var W := SpellData.School.WHITE
	add("black_sure", "Black: Sure", F, C, ["+10 Hit with black spells"], [],
		[mod(TraitModifier.Kind.HIT, 10, {"school": B})], {"school": B, "line": "Sure"})
	add("black_heavy", "Black: Heavy", F, C, ["+2 damage with black spells"], [],
		[mod(TraitModifier.Kind.DAMAGE, 2, {"school": B})], {"school": B, "line": "Heavy"})
	add("black_deep", "Black: Deep", F, C, ["+1 use of every tier I black spell"], [],
		[mod(TraitModifier.Kind.SPELL_USES, 1, {"school": B, "spell_tier": 1})], {"school": B, "line": "Deep"})
	add("black_apt", "Black: Apt", F, C, ["+50% black magic points"], [],
		[mod(TraitModifier.Kind.PROFICIENCY_PERCENT, 50, {"school": B})], {"school": B, "line": "Apt"})
	add("white_kind", "White: Kind", F, C, ["Heals restore 3 more"], [],
		[mod(TraitModifier.Kind.HEAL_GIVEN, 3, {"school": W})], {"school": W, "line": "Kind"})
	add("white_lasting", "White: Lasting", F, C, ["Blessings last 1 turn longer"], [],
		[mod(TraitModifier.Kind.BLESSING_TURNS, 1, {"school": W})], {"school": W, "line": "Lasting"})
	add("white_deep", "White: Deep", F, C, ["+1 use of every tier I white spell"], [],
		[mod(TraitModifier.Kind.SPELL_USES, 1, {"school": W, "spell_tier": 1})], {"school": W, "line": "Deep"})
	add("white_apt", "White: Apt", F, C, ["+50% white magic points"], [],
		[mod(TraitModifier.Kind.PROFICIENCY_PERCENT, 50, {"school": W})], {"school": W, "line": "Apt"})


# ---------------------------------------------------------------- 3. body and mind

func _body_and_mind() -> void:
	var F := TraitData.Family.BODY_AND_MIND
	var C := TraitData.Rarity.COMMON
	for row in [
		["hale", "Hale", Stat.HP, 4, "+4 Health"],
		["deep_winded", "Deep-Winded", Stat.STA, 3, "+3 Stamina"],
		["strong", "Strong", Stat.STR, 2, "+2 Strength"],
		["bright", "Bright", Stat.MAG, 2, "+2 Magic"],
		["deft", "Deft", Stat.DEX, 2, "+2 Dexterity"],
		["fleet", "Fleet", Stat.SPD, 2, "+2 Speed"],
		["hardy", "Hardy", Stat.DEF, 2, "+2 Defence"],
		["warded", "Warded", Stat.RES, 2, "+2 Resistance"],
		["sharp_eyed", "Sharp-Eyed", Stat.CRT, 3, "+3 Critical"],
		["lucky", "Lucky", Stat.LCK, 4, "+4 Luck"],
		["broad", "Broad", Stat.BLD, 2, "+2 Build"],
	]:
		add(row[0], row[1], F, C, [row[4]], [], [stat(row[2], row[3])])


# ---------------------------------------------------------------- 4. two-edged

func _two_edged() -> void:
	var F := TraitData.Family.TWO_EDGED
	var U := TraitData.Rarity.UNCOMMON
	var front := {"place": TraitModifier.Place.FRONT}
	var rear := {"place": TraitModifier.Place.REAR}
	var not_front := {"place": TraitModifier.Place.NOT_FRONT}
	add("reckless", "Reckless", F, U, ["+10 Hit"], ["Avoid -10"], [mod(TraitModifier.Kind.HIT, 10), mod(TraitModifier.Kind.AVOID, -10)])
	add("wary", "Wary", F, U, ["Avoid +10"], ["-5 Hit"], [mod(TraitModifier.Kind.AVOID, 10), mod(TraitModifier.Kind.HIT, -5)])
	add("wild_swing", "Wild Swing", F, U, ["+15 Crit"], ["-10 Hit"], [mod(TraitModifier.Kind.CRIT, 15), mod(TraitModifier.Kind.HIT, -10)])
	add("measured", "Measured", F, U, ["+10 Hit"], ["-10 Crit"], [mod(TraitModifier.Kind.HIT, 10), mod(TraitModifier.Kind.CRIT, -10)])
	add("brittle_fury", "Brittle Fury", F, U, ["+3 Strength"], ["-3 Defence"], [stat(Stat.STR, 3), stat(Stat.DEF, -3)])
	add("stone_footed", "Stone-Footed", F, U, ["+3 Defence"], ["-2 Speed"], [stat(Stat.DEF, 3), stat(Stat.SPD, -2)])
	add("scholars_frame", "Scholar's Frame", F, U, ["+3 Magic"], ["-4 Health"], [stat(Stat.MAG, 3), stat(Stat.HP, -4)])
	add("ox", "Ox", F, U, ["+2 Strength, +2 Build"], ["-2 Dexterity"],
		[stat(Stat.STR, 2), stat(Stat.BLD, 2), stat(Stat.DEX, -2)])
	add("whip_thin", "Whip-Thin", F, U, ["+3 Speed"], ["-2 Build"], [stat(Stat.SPD, 3), stat(Stat.BLD, -2)])
	add("hothead", "Hothead", F, U, ["+3 damage with a plain Attack"], ["Arts cost 1 more stamina"],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"action": TraitModifier.Action.ATTACK}), mod(TraitModifier.Kind.ART_STAMINA, 1)])
	add("thrifty", "Thrifty", F, U, ["Arts cost 1 less stamina"], ["-1 damage with arts"],
		[mod(TraitModifier.Kind.ART_STAMINA, -1), mod(TraitModifier.Kind.DAMAGE, -1, {"action": TraitModifier.Action.ART})])
	add("proud", "Proud", F, U, ["+2 Defence and Resistance in the front place"], ["-2 of both anywhere else"],
		[stat(Stat.DEF, 2, front), stat(Stat.RES, 2, front), stat(Stat.DEF, -2, not_front), stat(Stat.RES, -2, not_front)])
	add("shy", "Shy", F, U, ["+10 Hit and Crit in the rear place"], ["-10 of both in the front place"],
		[mod(TraitModifier.Kind.HIT, 10, rear), mod(TraitModifier.Kind.CRIT, 10, rear), mod(TraitModifier.Kind.HIT, -10, front), mod(TraitModifier.Kind.CRIT, -10, front)])
	add("slow_starter", "Slow Starter", F, U, ["+10 Hit from their fourth action on"], ["-10 Hit on their first"],
		[mod(TraitModifier.Kind.HIT, 10, {"action_from": 4}), mod(TraitModifier.Kind.HIT, -10, {"action_to": 1})])
	add("sprinter", "Sprinter", F, U, ["+2 Speed and +10 Hit for their first three actions"], ["-3 Stamina"],
		[stat(Stat.SPD, 2, {"action_to": 3}), mod(TraitModifier.Kind.HIT, 10, {"action_to": 3}), stat(Stat.STA, -3)])
	add("thin_blooded", "Thin-Blooded", F, U, ["+15% XP"], ["Infirmary stays are 1 day longer"],
		[mod(TraitModifier.Kind.XP_PERCENT, 15), mod(TraitModifier.Kind.INFIRMARY_DAYS, 1)])
	add("daredevil", "Daredevil", F, U, ["+20 Crit below half Health"], ["Heals only half as much at day's end"],
		[mod(TraitModifier.Kind.CRIT, 20, {"self_health": TraitModifier.Health.BELOW_HALF}), mod(TraitModifier.Kind.DAY_HEAL_PERCENT, -50)])
	add("showy", "Showy", F, U, ["+10 Crit"], ["Drawn more (x1.5)"], [mod(TraitModifier.Kind.CRIT, 10), aim(1.5)])
	add("skulker", "Skulker", F, U, ["Drawn less (x0.6)"], ["-5 Crit"], [aim(0.6), mod(TraitModifier.Kind.CRIT, -5)])
	add("glutton_for_blows", "Glutton for Blows", F, U, ["+4 Health, +1 Defence"], ["-2 Speed, drawn more (x1.3)"],
		[stat(Stat.HP, 4), stat(Stat.DEF, 1), stat(Stat.SPD, -2), aim(1.3)])
	add("faithless", "Faithless", F, U, ["+3 Resistance"], ["White magic heals them 3 less"],
		[stat(Stat.RES, 3), mod(TraitModifier.Kind.HEAL_RECEIVED, -3)])
	add("single_minded", "Single-Minded", F, U, ["+15 Hit against the enemy they struck last"], ["-5 Hit against any other"],
		[mod(TraitModifier.Kind.HIT, 15, {"struck": TraitModifier.Struck.LAST_STRUCK}), mod(TraitModifier.Kind.HIT, -5, {"struck": TraitModifier.Struck.NOT_LAST_STRUCK})])


# ---------------------------------------------------------------- 5. the line

func _the_line() -> void:
	var F := TraitData.Family.THE_LINE
	var U := TraitData.Rarity.UNCOMMON
	var front := {"place": TraitModifier.Place.FRONT}
	add("vanguard", "Vanguard", F, U, ["+2 Defence and Resistance in the front place"], [],
		[stat(Stat.DEF, 2, front), stat(Stat.RES, 2, front)])
	add("rearguard", "Rearguard", F, U, ["+10 Hit in the rear place"], [], [mod(TraitModifier.Kind.HIT, 10, {"place": TraitModifier.Place.REAR})])
	add("anchor", "Anchor", F, U, ["In a middle place, both neighbours take 1 less damage"], [],
		[mod(TraitModifier.Kind.DAMAGE_TAKEN, -1, {"who": TraitModifier.Who.NEIGHBOURS, "place": TraitModifier.Place.MIDDLE})])
	add("shieldmate", "Shieldmate", F, U, ["The companion behind them takes 15% less damage"], [],
		[mod(TraitModifier.Kind.DAMAGE_TAKEN_PERCENT, -15, {"who": TraitModifier.Who.BEHIND})])
	add("file_leader", "File Leader", F, U, ["The companion behind them has +5 Hit"], [],
		[mod(TraitModifier.Kind.HIT, 5, {"who": TraitModifier.Who.BEHIND})])
	add("looming", "Looming", F, U, ["Drawn more (x1.5)"], [], [aim(1.5)])
	add("unseen", "Unseen", F, U, ["Drawn less (x0.6)"], [], [aim(0.6)])
	add("lone_blade", "Lone Blade", F, U, ["+2 Strength and Dexterity while the line holds two or fewer"], [],
		[stat(Stat.STR, 2, {"line_at_most": 2}), stat(Stat.DEX, 2, {"line_at_most": 2})])
	add("full_rank", "Full Rank", F, U, ["+5 Hit while the line is full"], [], [mod(TraitModifier.Kind.HIT, 5, {"line_full": true})])
	add("last_stand", "Last Stand", F, U, ["+3 Strength and Defence while they are the only one standing"], [],
		[stat(Stat.STR, 3, {"only_standing": true}), stat(Stat.DEF, 3, {"only_standing": true})])
	add("wall", "Wall", F, U, ["Guarding, they take 65% less instead of 50%"], [], [mod(TraitModifier.Kind.GUARD_PERCENT, 65)])
	add("sidestep", "Sidestep", F, U, ["Blows that strike the whole line deal 25% less to them"], [],
		[mod(TraitModifier.Kind.DAMAGE_TAKEN_PERCENT, -25, {"whole_line_blows": true})])
	add("front_runner", "Front-Runner", F, U, ["Their first action in the front place each battle cannot miss"], [],
		[mod(TraitModifier.Kind.SURE_HIT, 1, {"place": TraitModifier.Place.FRONT, "first_front_action": true})])


# ---------------------------------------------------------------- 6. tempo (the plain damage and Hit lines)

func _tempo() -> void:
	var F := TraitData.Family.TEMPO
	var U := TraitData.Rarity.UNCOMMON
	add("first_blood", "First Blood", F, U, ["Their first action of a battle: +20 Hit, +3 damage"], [],
		[mod(TraitModifier.Kind.HIT, 20, {"action_to": 1}), mod(TraitModifier.Kind.DAMAGE, 3, {"action_to": 1})])
	add("patient", "Patient", F, U, ["After Guard or Focus, their next strike: +15 Hit, +2 damage"], [],
		[mod(TraitModifier.Kind.HIT, 15, {"after_guard_or_focus": true}), mod(TraitModifier.Kind.DAMAGE, 2, {"after_guard_or_focus": true})])
	add("closer", "Closer", F, U, ["+3 damage to enemies below half Health"], [],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"target_health": TraitModifier.Health.BELOW_HALF})])
	add("opener", "Opener", F, U, ["+3 damage to enemies at full Health"], [],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"target_health": TraitModifier.Health.FULL})])
	add("giant_bane", "Giant-Bane", F, U, ["+3 damage to Large enemies"], [],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"target_trait": EnemyTraits.LARGE})])
	add("fowler", "Fowler", F, U, ["+15 Hit against Flying enemies"], [],
		[mod(TraitModifier.Kind.HIT, 15, {"target_trait": EnemyTraits.FLYING})])
	add("spell_breaker", "Spell-Breaker", F, U, ["+3 damage to an enemy whose next action is magic"], [],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"target_next_magic": true})])
	add("grudge", "Grudge", F, U, ["+3 damage to whoever hit them last"], [],
		[mod(TraitModifier.Kind.DAMAGE, 3, {"struck": TraitModifier.Struck.HIT_ME_LAST})])
	add("counter_eye", "Counter-Eye", F, U, ["+15 Hit against an enemy that has struck them since their last action"], [],
		[mod(TraitModifier.Kind.HIT, 15, {"struck": TraitModifier.Struck.STRUCK_ME_SINCE})])
	add("kingslayer", "Kingslayer", F, TraitData.Rarity.RARE, ["+10% damage to bosses"], [],
		[mod(TraitModifier.Kind.DAMAGE_PERCENT, 10, {"target_boss": true})])


# ---------------------------------------------------------------- 8. learning (the growth traits)

func _learning() -> void:
	var F := TraitData.Family.LEARNING
	for row in [
		[Stat.HP, "Health"], [Stat.STA, "Stamina"], [Stat.STR, "Strength"], [Stat.MAG, "Magic"],
		[Stat.DEX, "Dexterity"], [Stat.SPD, "Speed"], [Stat.DEF, "Defence"], [Stat.RES, "Resistance"],
		[Stat.CRT, "Critical"], [Stat.LCK, "Luck"],
	]:
		add("growing_%s" % String(row[1]).to_lower(), "Growing: %s" % row[1], F, TraitData.Rarity.COMMON,
			["+15 to %s growth" % row[1]], [], [mod(TraitModifier.Kind.GROWTH, 15, {"stat": row[0]})], {"line": "Growing"})
	var U := TraitData.Rarity.UNCOMMON
	add("early_bloomer", "Early Bloomer", F, U, ["Every growth +10 until level 8, -5 after"], [],
		[mod(TraitModifier.Kind.GROWTH, 10, {"level_to": 8}), mod(TraitModifier.Kind.GROWTH, -5, {"level_from": 9})])
	add("late_bloomer", "Late Bloomer", F, U, ["Every growth -5 until level 8, +10 after"], [],
		[mod(TraitModifier.Kind.GROWTH, -5, {"level_to": 8}), mod(TraitModifier.Kind.GROWTH, 10, {"level_from": 9})])
