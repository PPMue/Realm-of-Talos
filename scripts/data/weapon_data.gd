class_name WeaponData
extends EquipmentData
## A weapon. Physical damage = STR + might - target DEF.

enum WeaponType { SWORD, AXE, SPEAR, BOW, DAGGER }

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var might: int = 5
@export var hit: int = 80
## Lowest proficiency grade in this weapon's type a companion needs to equip it.
## See CompanionProgress.can_equip_weapon().
@export var required_grade: Proficiency.Grade = Proficiency.Grade.E
## A rare weapon may grant an art of its own while equipped. No weapon uses this yet.
@export var unique_art: CombatArtData
## Reserved for weapon durability (-1 = unbreakable). Not used yet.
@export var max_uses: int = -1


static func type_name(t: WeaponType) -> String:
	return String(WeaponType.keys()[t]).capitalize()
