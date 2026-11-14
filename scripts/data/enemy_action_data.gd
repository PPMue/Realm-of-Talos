class_name EnemyActionData
extends Resource
## One entry in an enemy's action list.

enum Intent { ATTACK, DEFEND, BUFF, DEBUFF }
## SINGLE: one companion picked by position weight. ALL_COMPANIONS: every companion in the line.
## SELF: the enemy itself. ALL_ALLIES: every living enemy, the actor included.
enum Targeting { SINGLE, ALL_COMPANIONS, SELF, ALL_ALLIES }

@export var display_name: String = ""
## What the player sees while this action is pending.
@export var intent: Intent = Intent.ATTACK
@export var targeting: Targeting = Targeting.SINGLE
## Ticks until the action fires once it becomes the pending action.
@export var countdown: int = 2
## Relative chance of being picked as the next action.
@export var pick_weight: float = 1.0
## Never picked right after itself (when the enemy has another action to pick).
@export var no_repeat: bool = false
@export var deals_damage: bool = true
## Physical uses the enemy's STR against DEF; magic its MAG against RES. Guard halves both.
@export var damage_type: CombatMath.DamageType = CombatMath.DamageType.PHYSICAL
@export var might: int = 0
@export var hit: int = 80
## Applied to each target the action lands on (or to the enemy itself for SELF).
@export var effect: StatusEffectData
## SINGLE only: aim with the position weights mirrored, so the leftmost companion is aimed at most.
## The enemy's own `reversed_targeting` does the same for all its single-target actions.
@export var reversed_targeting: bool = false
## SELF and ALL_ALLIES: each enemy reached heals this share (percent) of its own max HP.
@export var heal_percent: int = 0
## An order: every other living enemy's countdown drops by this many, never below 1
## (an enemy already at 0, about to act this tick, is left alone).
@export var hasten_allies: int = 0
## Recovery pressure: each companion reached (a landed hit, or every target of an action that deals
## no damage) gains this many ticks of recovery.
@export var add_recovery: int = 0
## The chance (percent) that a landed blow is a critical. Enemies strike critically only when an action
## says so; their CRT is not used for it.
@export var crit_percent: int = 0


static func intent_name(value: Intent) -> String:
	return Intent.keys()[value]
