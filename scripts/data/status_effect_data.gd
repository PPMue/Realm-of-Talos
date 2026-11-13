class_name StatusEffectData
extends Resource
## A timed effect from an enemy action or a combat art (buff, defend, debuff).
## Duration counts the tick it is applied in.

@export var display_name: String = ""
## Stat key (see Stat) -> flat bonus, e.g. {"STR": 4} or {"DEX": -4}.
@export var stat_mods: Dictionary = {}
@export var damage_taken_mult: float = 1.0
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
	parts.append("%d tick%s" % [duration_ticks, "" if duration_ticks == 1 else "s"])
	return "%s (%s)" % [display_name, ", ".join(parts)]
