class_name Front
extends RefCounted
## One place to defend on a battle day (or the boss): who is there, how dangerous, what winning gives
## and what losing costs. Built by Run when the day begins; enemies are already scaled to the day.

var site: FrontSiteData
var group: EnemyGroupData
var danger: int = 1
var is_boss: bool = false
## Scaled copies of the group's enemies, left to right.
var enemies: Array[EnemyData] = []
var reward_gold: int = 0
## Material id -> amount.
var reward_materials: Dictionary = {}
var city_damage: int = 0
## XP shared by the fielded companions still standing if the battle is won.
var xp_pool: int = 0
## The rank of the gemstone (Gem) a win here gives, shown before the front is chosen; 0 for none.
## Set on the big fights: the elites and every boss but the last (Run.gem_for_fight).
var gem: int = 0
## True on an elite day's fronts (two, both danger 3).
var is_elite: bool = false


func title() -> String:
	return group.display_name if is_boss else site.display_name
