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
	parts.append("%d tick%s" % [duration_ticks, "" if duration_ticks == 1 else "s"])
	return "%s (%s)" % [display_name, ", ".join(parts)]


## True for an effect that hurts its bearer: a stat lowered or more damage taken.
func is_harmful() -> bool:
	for key: String in stat_mods:
		if int(stat_mods[key]) < 0:
			return true
	return damage_taken_mult > 1.0


static func _mult_text(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
