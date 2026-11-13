class_name EventChoiceData
extends Resource
## One answer to an event: what it costs and what it gives. Every field is a change applied when chosen.
## A choice that would take more gold or materials than the player has cannot be picked.

enum HpTarget { ALL, HEALTHIEST }

@export var label: String = ""
## What happens, shown after choosing.
@export_multiline var result_text: String = ""

@export var gold: int = 0
## Material id (RunConfig.IRON_ORE, RunConfig.TIMBER) -> change.
@export var materials: Dictionary = {}
@export var city_health: int = 0
## HP change for the companions chosen by `hp_target`. Losses never take a companion below 1 HP.
@export var companion_hp: int = 0
@export var hp_target: HpTarget = HpTarget.HEALTHIEST
## A weapon added to the run inventory.
@export var weapon: WeaponData
