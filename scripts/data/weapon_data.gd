class_name WeaponData
extends EquipmentData
## A weapon. Damage = attack power + might - target DEF, where attack power depends on the weapon type
## (see CombatMath.attack_power: STR for swords and spears, STR + BLD / 2 for axes, the mean of STR and
## DEX for bows, of STR and SPD for daggers). A magic weapon (a rare variant of a normal type) uses MAG
## in place of STR and deals magic damage against RES, for Attack and every combat art made with it.
##
## Weapons come in six tiers (the ladder): every type exists in every tier, with Mt and the grade
## needed set by the tier (BattleConfig.WEAPON_TIER_BASE_MIGHT, WEAPON_TYPE_MIGHT_OFFSET,
## WEAPON_TIER_GRADE). The rare magic weapons sit beside the ladder.
##
## Two-proficiency weapons (RunContent.hybrid_weapons; Halberd, Glaive, Greatsword, Twinblades,
## Javelin, Runeblade) also need a grade in a second weapon type or magic school. They are their main
## type (`weapon_type`) for everything else: attack power, proficiency gained, arts, effectiveness.
## The second type is only a requirement. See CompanionProgress.weapon_block_reason().

enum WeaponType { SWORD, AXE, SPEAR, BOW, DAGGER }
enum Tier { WOODEN, BRONZE, IRON, STEEL, SILVER, PLATINUM }

const TIER_NAMES: Array[String] = ["Wooden", "Bronze", "Iron", "Steel", "Silver", "Platinum"]

@export var weapon_type: WeaponType = WeaponType.SWORD
@export var tier: Tier = Tier.WOODEN
@export var might: int = 5
@export var hit: int = 80
@export var damage_type: CombatMath.DamageType = CombatMath.DamageType.PHYSICAL
## Enemy traits this weapon is effective against (half as much damage again). Every bow lists
## "Flying" and every spear "Large".
@export var effective_against: Array[String] = []
## Lowest proficiency grade in this weapon's type a companion needs to equip it.
## See CompanionProgress.can_equip_weapon().
@export var required_grade: Proficiency.Grade = Proficiency.Grade.E
## A two-proficiency weapon's second requirement: a weapon type (WeaponType) or a magic school
## (SpellData.School), at most one of them set (-1 = none), and the grade needed in it.
@export var second_type: int = -1
@export var second_school: int = -1
@export var second_grade: Proficiency.Grade = Proficiency.Grade.E
## The two-proficiency family ("Halberd", ...); "" for every other weapon.
@export var family: String = ""
## A rare weapon may grant an art of its own while equipped. No weapon uses this yet.
@export var unique_art: CombatArtData
## Reserved for weapon durability (-1 = unbreakable). Not used yet.
@export var max_uses: int = -1


static func type_name(t: WeaponType) -> String:
	return String(WeaponType.keys()[t]).capitalize()


static func tier_name(t: int) -> String:
	return TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)]


## Mt of a ladder weapon of tier `t` and type `type`: the tier's base + the type's offset, at least 0.
static func ladder_might(t: int, type: WeaponType) -> int:
	return maxi(0, BattleConfig.WEAPON_TIER_BASE_MIGHT[t] + int(BattleConfig.WEAPON_TYPE_MIGHT_OFFSET[type][t]))


## Grade needed to hold a ladder weapon of tier `t`.
static func ladder_grade(t: int) -> int:
	return BattleConfig.WEAPON_TIER_GRADE[t]


static func top_tier() -> int:
	return Tier.PLATINUM


func is_magic() -> bool:
	return damage_type == CombatMath.DamageType.MAGIC


## True for a two-proficiency weapon.
func has_second_requirement() -> bool:
	return second_type >= 0 or second_school >= 0


## The second requirement's type or school in lower case ("axe", "black magic"); "" if none.
func second_name() -> String:
	if second_type >= 0:
		return type_name(second_type).to_lower()
	if second_school >= 0:
		return SpellData.school_name(second_school).to_lower()
	return ""


## What holding it needs, for display: "spear C" or, with a second requirement, "spear C · axe D".
func requirement_text() -> String:
	var text := "%s %s" % [type_name(weapon_type).to_lower(), Proficiency.grade_name(required_grade)]
	if has_second_requirement():
		text += " · %s %s" % [second_name(), Proficiency.grade_name(second_grade)]
	return text
