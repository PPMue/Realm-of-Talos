class_name CompanionUnit
extends Combatant
## A companion during battle.

enum State { ACTIVE, INJURED, GONE }

var data: CompanionData
## Proficiency and arts carried between battles. Battle updates it as the companion fights.
var progress: CompanionProgress
## Proficiency points gained this battle, for BattleConfig.PROFICIENCY_CAP_PER_BATTLE.
var proficiency_gained: int = 0
## Magic points gained this battle (all schools), for BattleConfig.MAGIC_CAP_PER_BATTLE.
var magic_gained: int = 0
var stamina: int = 0
## Number of following player actions this companion sits out.
var recovery: int = 0
var state: State = State.ACTIVE


func _init(p_data: CompanionData, p_progress: CompanionProgress = null) -> void:
	data = p_data
	progress = p_progress if p_progress != null else CompanionProgress.create(p_data)
	display_name = p_data.display_name
	base_stats = progress.stats()
	hp = max_hp()
	stamina = max_stamina()


func max_stamina() -> int:
	return int(base_stats.get(Stat.STA, 0))


func weapon() -> WeaponData:
	return progress.weapon


## Equipped combat arts, in action order.
func arts() -> Array[CombatArtData]:
	return progress.equipped_arts


## Every known spell, in the order learned. All can be cast while they have uses left.
func spells() -> Array[SpellData]:
	return progress.known_spells


## Grade in the type of the weapon held, or -1 without a weapon.
func weapon_grade() -> int:
	return progress.grade(weapon().weapon_type) if weapon() != null else -1


func total_weight() -> int:
	var total := 0
	for item: EquipmentData in [weapon(), data.armor, data.accessory]:
		if item != null:
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
