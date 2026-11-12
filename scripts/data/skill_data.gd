class_name SkillData
extends Resource
## A weapon skill: a single strike with bonuses, paid for with stamina.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stamina_cost: int = 10
@export var might_bonus: int = 0
@export var hit_bonus: int = 0
@export var crit_bonus: int = 0
