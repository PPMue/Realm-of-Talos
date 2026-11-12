class_name WeaponData
extends EquipmentData
## A weapon. Physical damage = STR + might - target DEF.

enum WeaponType { SWORD, AXE, SPEAR, BOW, DAGGER }

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var might: int = 5
@export var hit: int = 80
## Stamina skill usable while this weapon is equipped.
@export var skill: SkillData
## Reserved for weapon durability (-1 = unbreakable). Not used yet.
@export var max_uses: int = -1
