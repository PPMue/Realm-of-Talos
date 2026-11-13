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

@export_group("Rare")
## A rare weapon (RunContent.rare_weapons): off the metal ladder, it needs a grade in its type (not a
## tier) and has a property no ladder weapon has (the fields below; see trait_lines()).
@export var rare: bool = false
## Smithy price of a rare weapon (ladder weapons are priced by tier; see Run.weapon_price).
@export var price: int = 0
## Added to the crit chance of Attack and of every art made with it.
@export var crit_bonus: int = 0
## Strikes of a plain Attack, each rolled on its own (arts keep their own count).
@export var attack_strikes: int = 1
## Share (percent) of the damage it deals that heals the wielder (rounded down, never above max HP).
@export var lifesteal_percent: int = 0
## Share (percent) of the target's DEF ignored; with an art that ignores DEF too, the larger counts.
@export var ignore_def_percent: int = 0
## Stat key -> bonus while held (e.g. {"DEF": 3}).
@export var held_stats: Dictionary = {}
## Multiplies how likely enemies are to aim at the wielder (1.0: no change).
@export var target_weight_mult: float = 1.0
## Applied to the target on every hit that lands (Attack and arts), e.g. a poison.
@export var on_hit_effect: StatusEffectData
## Gold for every enemy its wielder fells in a won battle.
@export var gold_per_kill: int = 0
## Mt is the ladder base Mt of the best tier the wielder's grade in its type can hold
## (BattleConfig.WEAPON_TIER_BASE_MIGHT; no type offset), in place of `might`. See might_for().
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


@export var might_by_grade: bool = false


func is_magic() -> bool:
	return damage_type == CombatMath.DamageType.MAGIC


func is_rare() -> bool:
	return rare


## Mt for a wielder with progress `p` (null: the listed `might`). A might_by_grade weapon uses the
## ladder base Mt of the best tier their grade in its type can hold: 3 at D, 6 at C, 9 at B, 12 at A,
## 15 at S.
func might_for(p: CompanionProgress) -> int:
	if not might_by_grade or p == null:
		return might
	return grade_might(p.grade(weapon_type))


## Ladder base Mt of the best tier `grade` can hold.
static func grade_might(grade: int) -> int:
	var tier := 0
	for t in BattleConfig.WEAPON_TIER_GRADE.size():
		if grade >= BattleConfig.WEAPON_TIER_GRADE[t]:
			tier = t
	return BattleConfig.WEAPON_TIER_BASE_MIGHT[tier]


## A rare or magic weapon's special properties in short lines for display; empty for others.
func trait_lines() -> Array[String]:
	var out: Array[String] = []
	if might_by_grade:
		out.append("Mt grows with the wielder's %s grade (3 at D up to 15 at S)" % type_name(weapon_type).to_lower())
	if is_magic():
		out.append("Strikes with MAG against RES")
	if attack_strikes > 1:
		out.append("An Attack strikes %s" % ("twice" if attack_strikes == 2 else "%d times" % attack_strikes))
	if crit_bonus != 0:
		out.append("Crit %+d" % crit_bonus)
	if lifesteal_percent > 0:
		out.append("Heals the wielder for %s the damage dealt" % ("half" if lifesteal_percent == 50 else "%d%% of" % lifesteal_percent))
	if ignore_def_percent > 0:
		out.append("Ignores %s the target's DEF" % ("half" if ignore_def_percent == 50 else "%d%% of" % ignore_def_percent))
	for key: String in held_stats:
		out.append("%s %+d while held" % [key, int(held_stats[key])])
	if target_weight_mult > 1.0:
		out.append("Enemies are %.1fx as likely to aim at the wielder" % target_weight_mult)
	elif target_weight_mult < 1.0:
		out.append("Enemies are less likely to aim at the wielder")
	if on_hit_effect != null:
		out.append("Every hit that lands: %s" % on_hit_effect.summary())
	if gold_per_kill > 0:
		out.append("+%d gold for every enemy felled in a won battle" % gold_per_kill)
	return out


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
