class_name CombatArtData
extends Resource
## A combat art: a strike paid for with stamina, tied to one weapon type.
## Companions learn arts as their proficiency in a weapon type rises and equip up to
## BattleConfig.MAX_EQUIPPED_ARTS of them. Using an art costs exactly one tick, like any action.
##
## Effects are data only and limited to: bonus Mt/Hit/Crit, striking every living enemy,
## striking twice, ignoring part of the target's DEF (RES with a magic weapon), effectiveness against
## enemy traits, a status effect on each enemy hit (debuff) and a status effect on the user (buff).
## Nothing here touches enemy countdowns: only spells can delay them.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.SWORD
## 1-3. Higher tiers hit harder and cost more stamina and recovery.
@export_range(1, 3) var tier: int = 1
@export var stamina_cost: int = 5
## Following player actions the user sits out afterwards.
@export var recovery: int = 1
## Reserved for weapon durability: uses this art takes from the weapon. Not used yet.
@export var durability_cost: int = 1

@export_group("Strike")
@export var might_bonus: int = 0
@export var hit_bonus: int = 0
@export var crit_bonus: int = 0
## Strike every living enemy instead of one target.
@export var hits_all_enemies: bool = false
## Strikes per target, each rolled separately.
@export_range(1, 2) var strikes: int = 1
## Share of the target's DEF this art ignores.
@export_range(0, 100) var ignore_def_percent: int = 0
## Enemy traits this art is effective against (half as much damage again). Does not stack with the
## weapon's own list.
@export var effective_against: Array[String] = []

@export_group("Effects")
## Applied to every enemy at least one strike lands on (a debuff).
@export var target_effect: StatusEffectData
## Applied to the user whether or not the strike lands (a buff).
@export var self_effect: StatusEffectData


func type_name() -> String:
	return WeaponData.type_name(weapon_type)


static func tier_numeral(value: int) -> String:
	return ["", "I", "II", "III"][clampi(value, 0, 3)]


## What the art does, in one or two short sentences built from its numbers.
func effect_summary() -> String:
	return ". ".join(effect_lines()) + "."


## The same, one thing per entry and without full stops, for a screen that sets them out as lines.
func effect_lines() -> Array[String]:
	var parts: Array[String] = []
	if hits_all_enemies:
		parts.append("Strikes every enemy")
	if strikes > 1:
		parts.append("Strikes twice" if strikes == 2 else "Strikes %d times" % strikes)
	var bonus: Array[String] = []
	if might_bonus != 0:
		bonus.append("Mt %+d" % might_bonus)
	if hit_bonus != 0:
		bonus.append("Hit %+d" % hit_bonus)
	if crit_bonus != 0:
		bonus.append("Crit %+d" % crit_bonus)
	if not bonus.is_empty():
		parts.append(", ".join(bonus))
	if ignore_def_percent >= 100:
		parts.append("Ignores DEF")
	elif ignore_def_percent > 0:
		parts.append("Ignores %d%% of DEF" % ignore_def_percent)
	if not effective_against.is_empty():
		parts.append("Effective against %s" % ", ".join(effective_against))
	if target_effect != null:
		parts.append("On hit: %s" % target_effect.summary())
	if self_effect != null:
		parts.append("User gains %s" % self_effect.summary())
	if parts.is_empty():
		parts.append("A plain strike")
	return parts
