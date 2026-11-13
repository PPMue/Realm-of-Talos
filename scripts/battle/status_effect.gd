class_name StatusEffect
extends RefCounted
## A temporary effect on a combatant (Guard, enemy buffs, defends, debuffs).
## Effects lose one tick at the end of every tick and are removed at 0,
## so a duration of 1 lasts until the end of the tick it was applied in.

var display_name: String = ""
var stat_mods: Dictionary = {}        ## Stat key -> int
var damage_taken_mult: float = 1.0
var target_weight_mult: float = 1.0
var ticks_left: int = 1


static func from_data(data: StatusEffectData) -> StatusEffect:
	var e := StatusEffect.new()
	e.display_name = data.display_name
	e.stat_mods = data.stat_mods.duplicate()
	e.damage_taken_mult = data.damage_taken_mult
	e.target_weight_mult = data.target_weight_mult
	e.ticks_left = maxi(1, data.duration_ticks)
	return e


static func guard() -> StatusEffect:
	var e := StatusEffect.new()
	e.display_name = "Guard"
	e.damage_taken_mult = BattleConfig.GUARD_DAMAGE_TAKEN_MULT
	e.target_weight_mult = BattleConfig.GUARD_TARGET_WEIGHT_MULT
	e.ticks_left = BattleConfig.GUARD_DURATION_TICKS
	return e


## A debuff: lowers a stat or raises damage taken. White magic can remove these.
func is_harmful() -> bool:
	for key: String in stat_mods:
		if int(stat_mods[key]) < 0:
			return true
	return damage_taken_mult > 1.0


func describe() -> String:
	var parts: Array[String] = []
	for key: String in stat_mods:
		var v := int(stat_mods[key])
		parts.append("%s%+d" % [key, v])
	if damage_taken_mult != 1.0:
		parts.append("dmg x%s" % str(damage_taken_mult))
	if target_weight_mult != 1.0:
		parts.append("aim x%s" % str(target_weight_mult))
	var detail := (" " + ", ".join(parts)) if not parts.is_empty() else ""
	return "%s%s (%d)" % [display_name, detail, ticks_left]
