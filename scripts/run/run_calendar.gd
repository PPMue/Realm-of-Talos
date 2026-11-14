class_name RunCalendar
extends RefCounted
## The order of days in a run. Pure functions, no state.
##
## A run is RunConfig.DAYS days in weeks of RunConfig.WEEK_DAYS, in pairs. The first week of the run
## and every boss week (the second of a pair) go battle, free, battle, free, battle, free, and then a
## free day in week 1 or the boss (days 14, 28, 42). The week after a boss is turned round: free,
## battle, free, battle, free, battle, free, so the day after every boss is free (days 15 and 29). So
## day 1 is a battle, no two fights are ever on consecutive days, the day before every boss is free,
## and a run has 18 battles besides the three bosses, and 21 free days. Two free days run together
## only at the end of week 1 (days 6 and 7).
##
## Some free days begin with an event (RunConfig.EVENTS_PER_WEEK in every week), placed at random by
## the run's generator, never on the day before a boss (the day after one may hold one).

enum DayType { BATTLE, FREE, BOSS }

const NAMES: Array[String] = ["BATTLE", "FREE", "BOSS"]


static func type_name(t: int) -> String:
	return NAMES[clampi(t, 0, NAMES.size() - 1)]


## Day types for days 1..RunConfig.DAYS (index 0 is day 1). The same for every run.
static func generate() -> Array[int]:
	var days: Array[int] = []
	for d in range(1, RunConfig.DAYS + 1):
		days.append(type_on(d))
	return days


## The type of day `day` by the weekly pattern (see the top of this file).
static func type_on(day: int) -> int:
	if is_boss_day(day):
		return DayType.BOSS
	var in_week := day_in_week(day)
	if in_week == RunConfig.WEEK_DAYS:
		return DayType.FREE
	var battle_on_odd := not after_boss_week(day)
	return DayType.BATTLE if (in_week % 2 == 1) == battle_on_odd else DayType.FREE


## True for the days of a week that begins the day after a boss (days 15-21 and 29-35): that week
## starts with a free day and has its battles on its even days.
static func after_boss_week(day: int) -> bool:
	var start := day - day_in_week(day) + 1
	return start > 1 and is_boss_day(start - 1)


## The free days whose morning begins with an event: RunConfig.EVENTS_PER_WEEK in every week, on free
## days that are not the day before a boss. Sorted.
static func pick_event_days(calendar: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var weeks := ceili(float(calendar.size()) / RunConfig.WEEK_DAYS)
	for w in weeks:
		var options: Array[int] = []
		for d in range(w * RunConfig.WEEK_DAYS + 1, mini((w + 1) * RunConfig.WEEK_DAYS, calendar.size()) + 1):
			var before_boss := d < calendar.size() and calendar[d] == DayType.BOSS
			if calendar[d - 1] == DayType.FREE and not before_boss:
				options.append(d)
		for i in mini(RunConfig.EVENTS_PER_WEEK, options.size()):
			out.append(options.pop_at(rng.randi_range(0, options.size() - 1)))
	out.sort()
	return out


static func is_boss_day(day: int) -> bool:
	return day % RunConfig.BOSS_EVERY_DAYS == 0


## 0 for the first boss (day 14), 1 for the second, ...
static func boss_index(day: int) -> int:
	return floori(float(day) / RunConfig.BOSS_EVERY_DAYS) - 1


## 1-based week of `day`: days 1-7 are week 1.
static func week_of(day: int) -> int:
	return floori(float(day - 1) / RunConfig.WEEK_DAYS) + 1


## 1..RunConfig.WEEK_DAYS.
static func day_in_week(day: int) -> int:
	return (day - 1) % RunConfig.WEEK_DAYS + 1


## True on the first day of a week (days 1, 8, 15, ...), when the tavern and the smithy restock.
static func is_week_start(day: int) -> bool:
	return day_in_week(day) == 1


## Days from `day` until the next weekly restock within the run (the next week's first day): 7 on day
## 1, 1 on day 7; -1 when no restock is left (the run's last week).
static func days_until_restock(day: int) -> int:
	var next := day - day_in_week(day) + 1 + RunConfig.WEEK_DAYS
	return next - day if next <= RunConfig.DAYS else -1
