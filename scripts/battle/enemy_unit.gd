class_name EnemyUnit
extends Combatant
## An enemy during battle. Always has one pending action counting down.

var data: EnemyData
var pending_action: EnemyActionData
var countdown: int = 0


func _init(p_data: EnemyData) -> void:
	data = p_data
	display_name = p_data.display_name
	base_stats = p_data.base_stats()
	hp = max_hp()


func is_alive() -> bool:
	return hp > 0
