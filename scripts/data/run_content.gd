class_name RunContent
extends Resource
## Everything a run is built from. One file, res://data/run/run_content.tres.

const DEFAULT_PATH := "res://data/run/run_content.tres"

## Companions a run can start with or hire.
@export var companions: Array[CompanionData] = []
@export var sites: Array[FrontSiteData] = []
## Normal front groups; picked by danger and day.
@export var groups: Array[EnemyGroupData] = []
## Every boss group. Each boss day draws one of those whose days include it (see bosses_for). The
## first enemy of each is the boss, used as is; any others are escorts and grow with the day like
## normal enemies.
@export var bosses: Array[EnemyGroupData] = []
@export var events: Array[EventData] = []
## The rare weapons (WeaponData.rare): off the ladder, each needs a grade in its type and has a
## property of its own; the four magic weapons are among them. The smithy, bosses and events may draw
## one (RunConfig.SHOP_RARE_CHANCE, BOSS_RARE_CHANCE, EVENT_RARE_CHANCE).
@export var rare_weapons: Array[WeaponData] = []
## The weapon ladder: one of every type in every tier (WeaponData.Tier), 30 in all. The smithy's
## weekly stock, events that grant a weapon and the bosses' drops are drawn from it.
@export var weapons: Array[WeaponData] = []
## The two-proficiency weapons (WeaponData.has_second_requirement): six families at bronze, iron, steel
## and silver, 24 in all. The smithy, events and bosses may draw one in place of a ladder weapon
## (RunConfig.SHOP_HYBRID_CHANCE).
@export var hybrid_weapons: Array[WeaponData] = []


static func load_default() -> RunContent:
	return load(DEFAULT_PATH) as RunContent


func groups_for(danger: int, day: int) -> Array[EnemyGroupData]:
	var out: Array[EnemyGroupData] = []
	for g in groups:
		if g.danger == danger and g.appears_on(day):
			out.append(g)
	return out


## The boss groups that can be drawn for `day`.
func bosses_for(day: int) -> Array[EnemyGroupData]:
	var out: Array[EnemyGroupData] = []
	for g in bosses:
		if g.appears_on(day):
			out.append(g)
	return out


## The ladder weapon of tier `tier` and type `type`, or null.
func ladder_weapon(tier: int, type: WeaponData.WeaponType) -> WeaponData:
	for w in weapons:
		if w.tier == tier and w.weapon_type == type and not w.is_magic():
			return w
	return null


## The ladder weapons of tier `tier`, optionally of one type only (-1: every type).
func ladder_tier(tier: int, type: int = -1) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in weapons:
		if w.tier == tier and not w.is_magic() and (type < 0 or w.weapon_type == type):
			out.append(w)
	return out


## The two-proficiency weapons of tier `tier`, optionally of one main type only (-1: every type).
func hybrids_of_tier(tier: int, type: int = -1) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in hybrid_weapons:
		if w.tier == tier and (type < 0 or w.weapon_type == type):
			out.append(w)
	return out


## The rare weapons needing at most `max_grade` in their type, optionally of one type only (-1: any).
func rare_pool(max_grade: int, type: int = -1) -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w in rare_weapons:
		if w.required_grade <= max_grade and (type < 0 or w.weapon_type == type):
			out.append(w)
	return out
