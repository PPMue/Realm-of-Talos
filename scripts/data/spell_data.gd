class_name SpellData
extends Resource
## A spell of Black Magic (offence, aimed at enemies) or White Magic (support, aimed at companions).
## Casting costs one tick and no stamina, then a recovery that grows with tier. Each companion has a
## number of uses per spell that lasts between battles and days; only the Rest action restores them.
##
## Black: damage = caster MAG + Mt - target RES (minimum 1), with the normal accuracy and crit formulas
## using this spell's Hit. Allowed effects: one enemy or every enemy, ignoring part of RES, a debuff on
## each enemy hit (damage over time included), and delaying the target's pending action (once per
## pending action).
## White: always succeeds. Allowed effects: healing (caster MAG + power), a buff (stats, less damage
## taken, how likely enemies are to aim at the target, or a reflecting ward that answers physical
## blows like an art's stance), removing debuffs; one ally or every ally.

enum School { BLACK, WHITE }
enum Targeting { ONE_ENEMY, ALL_ENEMIES, ONE_ALLY, ALL_ALLIES }

const SCHOOL_NAMES: Array[String] = ["Black Magic", "White Magic"]

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var school: School = School.BLACK
## 1-3. Higher tiers are stronger, have fewer uses and a longer recovery.
@export_range(1, 3) var tier: int = 1
@export var targeting: Targeting = Targeting.ONE_ENEMY
## Casts each companion has before a Rest (about 6 at tier 1, 4 at tier 2, 2 at tier 3).
@export var uses: int = 6
## Following player actions the caster sits out afterwards.
@export var recovery: int = 2

@export_group("Black Magic")
@export var might: int = 0
@export var hit: int = 90
@export var crit_bonus: int = 0
## Share of the target's RES this spell ignores.
@export_range(0, 100) var ignore_res_percent: int = 0
## Ticks added to a hit enemy's pending action. A pending action can be delayed only once.
@export var delay_ticks: int = 0
## Enemy traits (e.g. "Flying") this spell is effective against: it deals half as much damage again.
@export var effective_against: Array[String] = []

@export_group("White Magic")
## Restores caster MAG + heal_power HP to each target.
@export var heals: bool = false
@export var heal_power: int = 0
## Removes every debuff from each target.
@export var cleanse: bool = false

@export_group("Effect")
## Black: applied to every enemy the spell lands on (a debuff). White: applied to every target (a buff).
@export var effect: StatusEffectData


static func school_name(s: School) -> String:
	return SCHOOL_NAMES[s]


func school_text() -> String:
	return school_name(school)


func targets_allies() -> bool:
	return targeting == Targeting.ONE_ALLY or targeting == Targeting.ALL_ALLIES


func targets_all() -> bool:
	return targeting == Targeting.ALL_ENEMIES or targeting == Targeting.ALL_ALLIES


func deals_damage() -> bool:
	return not targets_allies()


func target_text() -> String:
	return ["One enemy", "Every enemy", "One ally", "Every ally"][targeting]


## What the spell does, in one or two short sentences built from its numbers.
func effect_summary() -> String:
	return ". ".join(effect_lines()) + "."


## The same, one thing per entry and without full stops, for a screen that sets them out as lines.
func effect_lines() -> Array[String]:
	var parts: Array[String] = []
	if deals_damage():
		var dmg := "%s: MAG + %d Mt vs RES, Hit %d" % [target_text(), might, hit]
		if crit_bonus != 0:
			dmg += ", Crit %+d" % crit_bonus
		parts.append(dmg)
		if ignore_res_percent >= 100:
			parts.append("Ignores RES")
		elif ignore_res_percent > 0:
			parts.append("Ignores %d%% of RES" % ignore_res_percent)
		if not effective_against.is_empty():
			parts.append("Effective against %s (+%d%% damage)" % [", ".join(effective_against), BattleConfig.EFFECTIVE_DAMAGE_BONUS_PERCENT])
		if delay_ticks > 0:
			parts.append("Delays the target's action by %d turn%s (once per action)" % [delay_ticks, "" if delay_ticks == 1 else "s"])
		if effect != null:
			parts.append("On hit: %s" % effect.summary())
	else:
		var bits: Array[String] = []
		if heals:
			bits.append("heals MAG + %d HP" % heal_power)
		if cleanse:
			bits.append("removes debuffs")
		if effect != null:
			bits.append("grants " + effect.summary())
		parts.append("%s: %s" % [target_text(), ", ".join(bits)])
		parts.append("Always succeeds")
	return parts
