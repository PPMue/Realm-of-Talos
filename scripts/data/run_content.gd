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
@export var shop: Array[ShopItemData] = []


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


func shop_stock(day: int) -> Array[ShopItemData]:
	var out: Array[ShopItemData] = []
	for s in shop:
		if s.min_day <= day:
			out.append(s)
	return out
