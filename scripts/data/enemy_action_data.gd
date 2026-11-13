class_name EnemyActionData
extends Resource
## One entry in an enemy's action list.

enum Intent { ATTACK, DEFEND, BUFF, DEBUFF }
enum Targeting { SINGLE, ALL_COMPANIONS, SELF }

@export var display_name: String = ""
## What the player sees while this action is pending.
@export var intent: Intent = Intent.ATTACK
@export var targeting: Targeting = Targeting.SINGLE
## Ticks until the action fires once it becomes the pending action.
@export var countdown: int = 2
## Relative chance of being picked as the next action.
@export var pick_weight: float = 1.0
@export var deals_damage: bool = true
## Physical uses the enemy's STR against DEF; magic its MAG against RES. Guard halves both.
@export var damage_type: CombatMath.DamageType = CombatMath.DamageType.PHYSICAL
@export var might: int = 0
@export var hit: int = 80
## Applied to each target the action lands on (or to the enemy itself for SELF).
@export var effect: StatusEffectData


static func intent_name(value: Intent) -> String:
	return Intent.keys()[value]
