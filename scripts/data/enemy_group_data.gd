class_name EnemyGroupData
extends Resource
## A group of enemies that can hold a front: who they are, how dangerous, and on which days they appear.
## Normal groups are picked at random by danger and day, favouring the band of the day (see Run).
## Boss groups: the first enemy is the boss, any others are its named escorts; `min_day`..`max_day`
## holds the boss day, and each run draws one boss group per boss day from those that fit it.

@export var display_name: String = ""
## Bosses: one line on what makes it dangerous, shown on the calendar and the boss card.
@export var description: String = ""
## 1-3. Higher danger: more or stronger enemies, a better reward, a bigger loss to the city.
@export_range(1, 3) var danger: int = 1
## Days this group can appear on (inclusive).
@export var min_day: int = 1
@export var max_day: int = 30
## Left to right on the stage.
@export var enemies: Array[EnemyData] = []


func appears_on(day: int) -> bool:
	return day >= min_day and day <= max_day


## The latest band among its enemies (1 early, 2 middle, 3 late; bosses count as 0).
func band() -> int:
	var b := 0
	for e in enemies:
		b = maxi(b, e.band)
	return b


## Boss groups: the boss itself.
func boss() -> EnemyData:
	return enemies[0] if not enemies.is_empty() else null


## Boss groups: the escorts, left to right.
func escorts() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for i in range(1, enemies.size()):
		out.append(enemies[i])
	return out
