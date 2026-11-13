class_name BattleReport
extends RefCounted
## What a finished battle did to the run, for the result screen.

var front: Front
var won: bool = false
var gold: int = 0
## Material id -> amount gained.
var materials: Dictionary = {}
var city_damage: int = 0
## Names of companions who were injured at the end (back at 1 HP) and who were removed for good.
var injured: Array[String] = []
var removed: Array[String] = []
## Battle.grade_ups entries: {"actor", "weapon_type", "grade", "art", "equipped"}.
var grade_ups: Array[Dictionary] = []
## XP each fielded companion still in the run received, by name, in line order (empty on a loss).
## The shares add up to the battle's whole XP pool; see Levels.split_xp.
var xp_gained: Dictionary = {}
## Contribution points each fielded companion still in the run earned in the battle, by name, in line
## order (won or lost). See Battle.points.
var points: Dictionary = {}
## One entry per level reached: {"name", "level", "gains"} (gains: stat key -> amount).
var level_ups: Array[Dictionary] = []
## The weapon a beaten boss dropped into the armory (Run.boss_weapon_tier), or null.
var weapon_found: WeaponData
## True if this battle ended the run (won or lost).
var run_over: bool = false


## XP the companion called `who` received (0 if none).
func xp_of(who: String) -> int:
	return int(xp_gained.get(who, 0))


## Contribution points the companion called `who` earned (0 if none).
func points_of(who: String) -> int:
	return int(points.get(who, 0))


## All the XP handed out: the battle's whole pool on a win, 0 on a loss.
func xp_total() -> int:
	var total := 0
	for who: String in xp_gained:
		total += int(xp_gained[who])
	return total
