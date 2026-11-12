class_name CompanionUnit
extends Combatant
## A companion during battle.

enum State { ACTIVE, INJURED, GONE }

var data: CompanionData
var stamina: int = 0
## Number of following player actions this companion sits out.
var recovery: int = 0
var state: State = State.ACTIVE


func _init(p_data: CompanionData) -> void:
	data = p_data
	display_name = p_data.display_name
	base_stats = p_data.base_stats()
	hp = max_hp()
	stamina = max_stamina()


func max_stamina() -> int:
	return int(base_stats.get(Stat.STA, 0))


func weapon() -> WeaponData:
	return data.weapon


func skill() -> SkillData:
	return data.weapon.skill if data.weapon != null else null


func total_weight() -> int:
	var total := 0
	for item in data.equipment():
		total += item.weight
	return total


func weight_penalty() -> int:
	return CombatMath.weight_penalty(total_weight(), stat(Stat.BLD))


func stat_penalty(key: String) -> int:
	if key == Stat.DEX or key == Stat.SPD:
		return weight_penalty()
	return 0


func is_active() -> bool:
	return state == State.ACTIVE


func is_injured() -> bool:
	return state == State.INJURED


func is_gone() -> bool:
	return state == State.GONE
