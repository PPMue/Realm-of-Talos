class_name RunCalendar
extends RefCounted
## The order of days in a run. Pure functions, no state.
##
## Guarantees (see RunConfig): a boss closes every block of ten days, the day before each boss is a
## free day, day 1 is a battle. Each block also has 5-6 battle days, 2 free days in all, and events
## on the days left (1-2). Everything else is shuffled by the run's generator.

enum DayType { BATTLE, FREE, EVENT, BOSS }

const NAMES: Array[String] = ["BATTLE", "FREE", "EVENT", "BOSS"]


static func type_name(t: int) -> String:
	return NAMES[clampi(t, 0, NAMES.size() - 1)]


## Day types for days 1..RunConfig.DAYS (index 0 is day 1).
static func generate(rng: RandomNumberGenerator) -> Array[int]:
	var days: Array[int] = []
	var blocks := ceili(float(RunConfig.DAYS) / RunConfig.BLOCK_DAYS)
	for b in blocks:
		var first_day := b * RunConfig.BLOCK_DAYS + 1
		var length := mini(RunConfig.BLOCK_DAYS, RunConfig.DAYS - b * RunConfig.BLOCK_DAYS)
		# The last two days are fixed: the free day before the boss, then the boss.
		var open := length - 2
		var battles := rng.randi_range(RunConfig.BATTLES_PER_BLOCK_MIN, RunConfig.BATTLES_PER_BLOCK_MAX)
		var free := RunConfig.FREE_DAYS_PER_BLOCK - 1
		var events := maxi(0, open - battles - free)
		var pool: Array[int] = []
		for i in battles:
			pool.append(DayType.BATTLE)
		for i in free:
			pool.append(DayType.FREE)
		for i in events:
			pool.append(DayType.EVENT)
		var fixed_first := first_day == 1
		if fixed_first:
			pool.erase(DayType.BATTLE)
		_shuffle(pool, rng)
		if fixed_first:
			pool.push_front(DayType.BATTLE)
		days.append_array(pool)
		days.append(DayType.FREE)
		days.append(DayType.BOSS)
	return days


static func is_boss_day(day: int) -> bool:
	return day % RunConfig.BLOCK_DAYS == 0


## 0 for the first boss (day 10), 1 for the second, ...
static func boss_index(day: int) -> int:
	return floori(float(day) / RunConfig.BLOCK_DAYS) - 1


## Fisher-Yates with the run's generator (Array.shuffle uses the global one).
static func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
