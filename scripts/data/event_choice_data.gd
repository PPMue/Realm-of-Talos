class_name EventChoiceData
extends Resource
## One answer to an event: what it costs and what it gives. Every field is a change applied when chosen.
## A choice that would take more gold or materials than the player has cannot be picked.

enum HpTarget { ALL, HEALTHIEST }
## A gemstone the choice gives: none, one of the current rank (Run.gem_rank_now), or one rank lower
## (never below Topaz). See Run.choice_gem.
enum GemStone { NONE, CURRENT, ONE_LOWER }

@export var label: String = ""
## What happens, shown after choosing. "{weapon}" is replaced by the weapon's name.
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
## Instead of a set weapon: a random one from the ladder, its tier fitting the week (see
## RunConfig.EVENT_WEAPON_TIER_UP_CHANCE), drawn when the event comes up (Run.choice_weapon).
@export var random_weapon: bool = false
## The random weapon's type (WeaponData.WeaponType), or -1 for any.
@export var random_weapon_type: int = -1
## A gemstone added to Run.gems. "{gem}" in result_text is replaced by its name.
@export var gem_stone: GemStone = GemStone.NONE
