extends SceneTree
## Writes every trait built so far (design/traits.md, waves up to BUILT_WAVE) as a .tres under
## res://data/traits/ and the library listing them (res://data/traits/trait_library.tres). A trait whose
## file already exists is left as it is (its sub-resource ids would change for nothing) unless
## REWRITE_ALL is set; a trait can also be written as a .tres by hand and added to the library.
##
##   godot --headless --path . -s res://tools/generate_traits.gd

## Waves built: 1 numbers with a condition, 2 single moments, 3 other people and scavenging.
const BUILT_WAVE := 3
const REWRITE_ALL := false
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
	if BUILT_WAVE >= 2:
		_wave_two()
	if BUILT_WAVE >= 3:
		_wave_three()
	var lib := TraitLibrary.new()
	var written := 0
	for t in _all:
		var dir := "%s/%s" % [OUT, FAMILY_DIRS[t.family]]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var path := "%s/%s.tres" % [dir, t.id]
		if REWRITE_ALL or not FileAccess.file_exists(path):
			var err := ResourceSaver.save(t, path)
			if err != OK:
				printerr("could not save %s: %d" % [path, err])
			written += 1
		lib.traits.append(load(path) as TraitData)
	print("%d traits written of %d" % [written, _all.size()])
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


# ---------------------------------------------------------------- wave 2: single moments

func _wave_two() -> void:
	var K := TraitModifier.Kind
	var U := TraitData.Rarity.UNCOMMON
	var R := TraitData.Rarity.RARE
	var T := TraitData.Family.TEMPO
	add("second_wind", "Second Wind", T, U, ["The first time they fall below half Health, their stamina is full again"], [],
		[mod(K.HALF_HEALTH_STAMINA, 1)])
	add("steady_breath", "Steady Breath", T, U, ["Focus restores 3 more stamina"], [], [mod(K.FOCUS_RESTORE, 3)])
	add("tireless", "Tireless", T, U, ["+1 stamina after each of their actions"], [], [mod(K.ACTION_STAMINA, 1)])
	add("quick_hands", "Quick Hands", T, U, ["The first art they use each battle has 1 less recovery"], [],
		[mod(K.RECOVERY, -1, {"action": TraitModifier.Action.ART, "first_art": true})])
	add("relentless", "Relentless", T, U, ["An action that fells an enemy has no recovery"], [], [mod(K.KILL_NO_RECOVERY, 1)])
	add("bloodrush", "Bloodrush", T, U, ["+4 stamina when they fell an enemy"], [], [mod(K.KILL_STAMINA, 4)])
	add("blood_drinker", "Blood-Drinker", T, U, ["+2 Health when they fell an enemy"], [], [mod(K.KILL_HP, 2)])
	add("staggering_blow", "Staggering Blow", T, R,
		["Their critical hits push the target's next action back 1 turn (once per action, as spells do)"], [], [mod(K.CRIT_DELAY, 1)])
	var S := TraitData.Family.STAYING_ALIVE
	add("thick_hide", "Thick Hide", S, U, ["Physical blows deal 1 less"], [],
		[mod(K.DAMAGE_TAKEN, -1, {"blow": TraitModifier.Blow.PHYSICAL})])
	add("spell_scarred", "Spell-Scarred", S, U, ["Magic deals 1 less"], [],
		[mod(K.DAMAGE_TAKEN, -1, {"blow": TraitModifier.Blow.MAGIC})])
	add("brace", "Brace", S, U, ["The first blow that lands on them each battle deals half"], [],
		[mod(K.DAMAGE_TAKEN_PERCENT, -50, {"first_blow_taken": true})])
	add("stubborn", "Stubborn", S, U, ["At 5 Health or less: Avoid +15"], [], [mod(K.AVOID, 15, {"self_hp_at_most": 5})])
	add("clean_blood", "Clean Blood", S, U, ["Damage over time cannot touch them"], [], [mod(K.DOT_IMMUNE, 1)])
	add("calm", "Calm", S, U, ["Curses on them end 1 turn sooner"], [], [mod(K.CURSE_TURNS, -1)])
	add("good_patient", "Good Patient", S, U, ["White magic heals them 3 more"], [], [mod(K.HEAL_RECEIVED, 3)])
	add("fast_healer", "Fast Healer", S, U, ["Heals 35% at day's end instead of 20%"], [], [mod(K.DAY_HEAL_SHARE, 15)])
	add("field_dresser", "Field Dresser", S, U, ["Heals 15% after a battle won"], [], [mod(K.BATTLE_WON_HEAL_PERCENT, 15)])
	add("quick_to_mend", "Quick to Mend", S, U, ["Infirmary stays are 1 day shorter"], [], [mod(K.INFIRMARY_DAYS, -1)])
	add("healers_favourite", "Healer's Favourite", S, U, ["The healer charges half for them"], [], [mod(K.CURE_PERCENT, -50)])
	add("clings_to_life", "Clings to Life", S, R, ["Once a battle, a blow that would fell them leaves them at 1 Health"], [],
		[mod(K.SURVIVE_ONCE, 1)])
	var L := TraitData.Family.LEARNING
	add("quick_study", "Quick Study", L, U, ["+10% XP"], [], [mod(K.XP_PERCENT, 10)])
	add("glory_hound", "Glory-Hound", L, U, ["Enemies they fell count double towards their share of XP"], [],
		[mod(K.KILL_POINTS_PERCENT, 100)])
	add("bench_learner", "Bench Learner", L, U, ["Gets a quarter share of XP from the bench"], [], [mod(K.RESERVE_XP_SHARE, 25)])
	add("yard_rat", "Yard Rat", L, U, ["Drills never come out poor for them"], [], [mod(K.DRILL_NEVER_POOR, 1)])
	add("second_trade", "Second Trade", L, U, ["Their second-best weapon grade earns +50% points"], [],
		[mod(K.PROFICIENCY_PERCENT, 50, {"second_best_weapon": true})])
	add("apprentice", "Apprentice", L, U, ["Arts and spells they learn lean a tier higher"], [], [mod(K.LEARN_GRADE_STEPS, 2)])
	add("deep_well", "Deep Well", L, R, ["+1 use of every spell"], [], [mod(K.SPELL_USES, 1)])
	var C := TraitData.Family.THE_CITY
	add("haggler", "Haggler", C, U, ["The Smithy charges 10% less"], [], [mod(K.SHOP_PERCENT, -10)])
	add("well_liked", "Well-Liked", C, U, ["Hires cost 20 gold less"], [], [mod(K.HIRE_COST, -20)])
	add("drillmaster", "Drillmaster", C, U, ["Drills cost 10 gold less"], [], [mod(K.DRILL_COST, -10)])
	add("masons_kin", "Mason's Kin", C, U, ["Repairs mend 5 more"], [], [mod(K.REPAIR_AMOUNT, 5)])
	add("looter", "Looter", C, U, ["+10 gold after a battle won in which they fought"], [], [mod(K.BATTLE_WON_GOLD, 10)])
	add("bounty_hunter", "Bounty Hunter", C, U, ["+4 gold for each enemy they fell"], [], [mod(K.KILL_GOLD, 4)])
	add("woodsman", "Woodsman", C, U, ["+1 timber after a battle in which they fought"], [],
		[mod(K.BATTLE_MATERIAL, 1, {"material": RunConfig.TIMBER})])
	add("prospector", "Prospector", C, U, ["+1 iron ore after a battle in which they fought"], [],
		[mod(K.BATTLE_MATERIAL, 1, {"material": RunConfig.IRON_ORE})])
	add("camp_cook", "Camp Cook", C, U, ["Everyone heals 5% more at day's end"], [],
		[mod(K.DAY_HEAL_SHARE, 5, {"who": TraitModifier.Who.COMPANY})])
	add("night_watch", "Night Watch", C, U, ["From the bench: a lost battle costs the walls 3 less"], [], [mod(K.CITY_DAMAGE, -3)])
	add("silver_tongue", "Silver Tongue", C, U, ["Event choices that cost gold cost 20% less"], [], [mod(K.EVENT_GOLD_PERCENT, -20)])


# ---------------------------------------------------------------- wave 3: other people, scavenging

func _wave_three() -> void:
	var K := TraitModifier.Kind
	var U := TraitData.Rarity.UNCOMMON
	var F := TraitData.Family.THE_COMPANY
	var near := {"who": TraitModifier.Who.NEIGHBOURS}
	add("inspiring", "Inspiring", F, U, ["Neighbours have +5 Hit"], [], [mod(K.HIT, 5, near)])
	add("watchful", "Watchful", F, U, ["Neighbours have Avoid +10"], [], [mod(K.AVOID, 10, near)])
	add("avenger", "Avenger", F, U, ["+3 damage for the rest of the battle once an ally is injured"], [],
		[mod(K.DAMAGE, 3, {"ally_injured": true})])
	add("rival", "Rival", F, U, ["+10 Crit while another companion has felled more enemies this battle"], [],
		[mod(K.CRIT, 10, {"rival_ahead": true})])
	add("lead_by_example", "Lead by Example", F, U, ["After they fell an enemy, the next ally to act has +15 Hit"], [],
		[mod(K.KILL_NEXT_ALLY_HIT, 15)])
	add("mentor", "Mentor", F, U, ["The lowest-level companion in the line gets +20% XP"], [],
		[mod(K.XP_PERCENT, 20, {"who": TraitModifier.Who.LOWEST})])
	add("martyr", "Martyr", F, U, ["When they are injured, every ally heals 5"], [], [mod(K.INJURED_HEAL_ALLIES, 5)])
	add("battle_kin", "Battle-Sister / Battle-Brother", F, U, ["+1 Strength and Defence for each neighbour"], [],
		[stat(Stat.STR, 1, {"per_neighbour": true}), stat(Stat.DEF, 1, {"per_neighbour": true})])
	add("envied", "Envied", F, U, ["Neighbours earn +25% proficiency points"], [], [mod(K.PROFICIENCY_PERCENT, 25, near)])
	add("standard_bearer", "Standard-Bearer", F, TraitData.Rarity.RARE, ["Every ally has +3 Hit"], [],
		[mod(K.HIT, 3, {"who": TraitModifier.Who.ALLIES})])
	var C := TraitData.Family.THE_CITY
	add("pathfinder", "Pathfinder", C, U, ["Scavenging: counts as 3 higher in whatever is asked of them"], [],
		[mod(K.SCAVENGE_STAT, 3)])
	add("sure_footed", "Sure-Footed", C, U, ["Scavenging: never comes back injured"], [], [mod(K.SCAVENGE_NO_INJURY, 1)])
	add("pack_mule", "Pack Mule", C, U, ["Scavenging: the party brings back 25% more"], [], [mod(K.SCAVENGE_HAUL_PERCENT, 25)])


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
