class_name EnemyUnit
extends Combatant
## An enemy during battle. Always has one pending action counting down.

var data: EnemyData
var pending_action: EnemyActionData
## The companion the pending action is aimed at, drawn when it was picked (Battle.pick_next_action), for
## a single-target action; null for every other. Moved only by Battle's re-aims (the "aim" event).
var pending_target: CompanionUnit
var countdown: int = 0
## True once a spell has delayed the pending action; cleared when the next action is picked.
var delayed: bool = false
## True once an order lowered the pending action's countdown; cleared when the next action is picked.
var hastened: bool = false
## 0 until the enemy switches to its second action list (EnemyData.phase_actions), then 1.
var phase: int = 0
## The last action it performed (for EnemyActionData.no_repeat).
var last_action: EnemyActionData


func _init(p_data: EnemyData) -> void:
	data = p_data
	display_name = p_data.display_name
	base_stats = p_data.base_stats()
	hp = max_hp()


func traits() -> Array[String]:
	return data.traits


func is_alive() -> bool:
	return hp > 0


## The action list in use now.
func actions() -> Array[EnemyActionData]:
	return data.phase_actions if phase > 0 else data.actions


## Whether `action` aims single targets with the position weights mirrored.
func aims_reversed(action: EnemyActionData) -> bool:
	return data.reversed_targeting or (action != null and action.reversed_targeting)


## Whether its single-target actions (any of the current list) aim mirrored.
func ever_aims_reversed() -> bool:
	if data.reversed_targeting:
		return true
	for a in actions():
		if a.reversed_targeting and a.targeting == EnemyActionData.Targeting.SINGLE:
			return true
	return false
