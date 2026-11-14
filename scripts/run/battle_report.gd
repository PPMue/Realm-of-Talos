class_name BattleReport
extends RefCounted
## What a finished battle did to the run, for the result screen.

var front: Front
var won: bool = false
## Gold gained on a win: the front's reward plus kill_gold.
var gold: int = 0
## Part of `gold` paid by weapons for kills (WeaponData.gold_per_kill, e.g. Magpie), and by whom
## (name -> gold). 0 / empty when nothing was.
var kill_gold: int = 0
var kill_gold_by: Dictionary = {}
## Material id -> amount gained.
var materials: Dictionary = {}
var city_damage: int = 0
## Names of the companions injured in the battle (won or lost): they go to the infirmary.
var injured: Array[String] = []
## True if the day was given up because nobody could be fielded (Run.yield_day): a lost battle at the
## worst front, with no fighting.
var yielded: bool = false
## True if the company sounded the retreat (Battle.retreated): lost, but only those already injured went
## to the Infirmary.
var retreated: bool = false
## Battle.grade_ups entries: {"actor", "weapon_type", "grade", "art", "equipped"}.
var grade_ups: Array[Dictionary] = []
## XP each fielded companion still in the run received, by name, in line order (empty on a loss).
## The shares add up to the battle's whole XP pool; see Levels.split_xp.
var xp_gained: Dictionary = {}
## Contribution points each fielded companion still in the run earned in the battle, by name, in line
## order (won or lost). See Battle.points.
var points: Dictionary = {}
## What companions' traits brought after the battle (Looter, Bounty Hunter, Woodsman, Prospector, Field
## Dresser, Night Watch), one short line each ("Elena, Looter: +10 gold"). The gold is in `gold`
## (trait_gold of it), the materials in `materials`, the walls' saving in `city_damage`.
var trait_lines: Array[String] = []
var trait_gold: int = 0
## XP the reserve got (the Barracks level 1, Bench Learner), by name; empty otherwise.
var reserve_xp: Dictionary = {}
## One entry per level reached: {"name", "level", "gains"} (gains: stat key -> amount).
var level_ups: Array[Dictionary] = []
## The weapon a beaten boss dropped into the armory (Run.boss_weapon_tier), or null.
var weapon_found: WeaponData
## The rank of the gemstone (Gem) the win gave (front.gem), already in Run.gems; 0 for none.
var gem: int = 0
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
