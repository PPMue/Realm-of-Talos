class_name StatusEffect
extends RefCounted
## A temporary effect on a combatant (Guard, enemy buffs, defends, debuffs, poison, reflection).
## Effects lose one tick at the end of every tick and are removed at 0,
## so a duration of 1 lasts until the end of the tick it was applied in.

var display_name: String = ""
## Per stack.
var stat_mods: Dictionary = {}        ## Stat key -> int
var damage_taken_mult: float = 1.0
var target_weight_mult: float = 1.0
var ticks_left: int = 1
## HP lost at the end of every tick (poison, burning).
var damage_per_tick: int = 0
## Share (percent) of a landed weapon strike's or art's damage dealt back to the striker.
var reflect_percent: int = 0
var stacks: int = 1
var max_stacks: int = 1


static func from_data(data: StatusEffectData) -> StatusEffect:
	var e := StatusEffect.new()
	e.display_name = data.display_name
	e.stat_mods = data.stat_mods.duplicate()
	e.damage_taken_mult = data.damage_taken_mult
	e.target_weight_mult = data.target_weight_mult
	e.ticks_left = maxi(1, data.duration_ticks)
	e.damage_per_tick = maxi(0, data.damage_per_tick)
	e.reflect_percent = maxi(0, data.reflect_percent)
	e.max_stacks = maxi(1, data.max_stacks)
	return e


static func guard() -> StatusEffect:
	var e := StatusEffect.new()
	e.display_name = "Guard"
	e.damage_taken_mult = BattleConfig.GUARD_DAMAGE_TAKEN_MULT
	e.target_weight_mult = BattleConfig.GUARD_TARGET_WEIGHT_MULT
	e.ticks_left = BattleConfig.GUARD_DURATION_TICKS
	return e


## A stat change with every stack counted.
func stat_mod(key: String) -> int:
	return int(stat_mods.get(key, 0)) * stacks


## A debuff: lowers a stat, raises damage taken, or deals damage over time. White magic removes these.
func is_harmful() -> bool:
	for key: String in stat_mods:
		if int(stat_mods[key]) < 0:
			return true
	return damage_taken_mult > 1.0 or damage_per_tick > 0


## "Poison 3/tick (2 left)", "Enraged x2 STR+4 (battle)".
func describe() -> String:
	var parts: Array[String] = []
	for key: String in stat_mods:
		parts.append("%s%+d" % [key, stat_mod(key)])
	if damage_taken_mult != 1.0:
		parts.append("dmg x%s" % str(damage_taken_mult))
	if target_weight_mult != 1.0:
		parts.append("aim x%s" % str(target_weight_mult))
	if damage_per_tick > 0:
		parts.append("%d/tick" % damage_per_tick)
	if reflect_percent > 0:
		parts.append("reflects %d%%" % reflect_percent)
	var detail := (" " + ", ".join(parts)) if not parts.is_empty() else ""
	var stack_text := " x%d" % stacks if stacks > 1 else ""
	var left := "battle" if ticks_left >= 99 else "%d left" % ticks_left
	return "%s%s%s (%s)" % [display_name, stack_text, detail, left]
