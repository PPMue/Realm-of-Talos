class_name EnemyGroupData
extends Resource
## A group of enemies that can hold a front: who they are, how dangerous, and on which days they appear.
## Normal groups are picked at random by danger and day; boss groups are listed in order in RunContent.

@export var display_name: String = ""
## 1-3. Higher danger: more or stronger enemies, a better reward, a bigger loss to the city.
@export_range(1, 3) var danger: int = 1
## Days this group can appear on (inclusive).
@export var min_day: int = 1
@export var max_day: int = 30
## Left to right on the stage.
@export var enemies: Array[EnemyData] = []


func appears_on(day: int) -> bool:
	return day >= min_day and day <= max_day
