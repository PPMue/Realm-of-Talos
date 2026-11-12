class_name StatusEffectData
extends Resource
## A timed effect an enemy action applies (buff, defend, debuff).
## Duration counts the tick it is applied in.

@export var display_name: String = ""
## Stat key (see Stat) -> flat bonus, e.g. {"STR": 4} or {"DEX": -4}.
@export var stat_mods: Dictionary = {}
@export var damage_taken_mult: float = 1.0
@export var duration_ticks: int = 3
