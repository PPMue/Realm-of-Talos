class_name StatusEffectData
extends Resource
## A timed effect from an enemy action or a combat art (buff, defend, debuff).
## Duration counts the tick it is applied in.

@export var display_name: String = ""
## Stat key (see Stat) -> flat bonus, e.g. {"STR": 4} or {"DEX": -4}.
@export var stat_mods: Dictionary = {}
@export var damage_taken_mult: float = 1.0
## How likely enemies are to aim at the bearer: below 1 a veil, above 1 a beacon. Companions only.
@export var target_weight_mult: float = 1.0
@export var duration_ticks: int = 3
## Damage over time (poison, burning): HP lost at the end of every tick while it lasts. Flat; Guard and
## damage-taken multipliers do not change it. It can injure a companion but never removes an injured one.
@export var damage_per_tick: int = 0
## Reflection: a weapon strike or combat art that lands on the bearer hurts the striker for this share
## (percent) of the damage it dealt, at least 1. Spells are never reflected.
@export var reflect_percent: int = 0
## Above 1, applying the effect again while it lasts adds a stack (up to this many) instead of only
## refreshing it: every stack adds `stat_mods` again.
@export var max_stacks: int = 1


## "Sundered (DEF -3, 3 ticks)"
func summary() -> String:
	var parts: Array[String] = []
	for key: String in stat_mods:
		parts.append("%s %+d" % [key, int(stat_mods[key])])
	if damage_taken_mult != 1.0:
		if damage_taken_mult < 1.0:
			parts.append("takes %d%% less damage" % roundi((1.0 - damage_taken_mult) * 100.0))
		else:
			parts.append("takes %d%% more damage" % roundi((damage_taken_mult - 1.0) * 100.0))
	if target_weight_mult < 1.0:
		parts.append("%d%% less likely to be aimed at" % roundi((1.0 - target_weight_mult) * 100.0))
	elif target_weight_mult > 1.0:
		parts.append("%sx as likely to be aimed at" % _mult_text(target_weight_mult))
	if damage_per_tick > 0:
		parts.append("loses %d HP every tick" % damage_per_tick)
	if reflect_percent > 0:
		parts.append("reflects %d%% of weapon and art damage" % reflect_percent)
	if max_stacks > 1:
		parts.append("stacks up to %d times" % max_stacks)
	parts.append("%d tick%s" % [duration_ticks, "" if duration_ticks == 1 else "s"] if duration_ticks < 99 else "until the battle ends")
	return "%s (%s)" % [display_name, ", ".join(parts)]


## True for an effect that hurts its bearer: a stat lowered, more damage taken, or damage over time.
func is_harmful() -> bool:
	for key: String in stat_mods:
		if int(stat_mods[key]) < 0:
			return true
	return damage_taken_mult > 1.0 or damage_per_tick > 0


static func _mult_text(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
