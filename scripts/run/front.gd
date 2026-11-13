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


func title() -> String:
	return group.display_name if is_boss else site.display_name
