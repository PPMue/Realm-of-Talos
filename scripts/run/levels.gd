class_name Levels
extends RefCounted
## Character levels: XP needed per level and the stat growth rolled on each level-up.
## Pure functions over CompanionProgress, with the run's generator passed in. Numbers in RunConfig.
##
## On a level-up every stat except BLD rolls its own growth rate (CompanionData.growths, percent):
## that stat rises by 1 on a hit. If fewer than RunConfig.MIN_STAT_GAINS rose, more stats that did not
## rise are picked at random, weighted by growth rate, until that many have.

const GROWTH_STATS: Array[String] = [Stat.HP, Stat.STA, Stat.STR, Stat.MAG, Stat.CRT, Stat.DEX, Stat.SPD,
	Stat.DEF, Stat.RES, Stat.LCK]


## XP needed to go from `level` to the next; 0 at the top level.
static func xp_to_next(level: int) -> int:
	if level >= RunConfig.MAX_LEVEL:
		return 0
	return RunConfig.XP_PER_LEVEL_BASE + RunConfig.XP_PER_LEVEL_STEP * (level - 1)


## Total XP from level 1 to reach `level`.
static func total_xp_for(level: int) -> int:
	var total := 0
	for l in range(1, mini(level, RunConfig.MAX_LEVEL)):
		total += xp_to_next(l)
	return total


## Growth rate (0-100) of one stat. BLD never grows.
static func growth_rate(data: CompanionData, key: String) -> int:
	if key == Stat.BLD or not GROWTH_STATS.has(key):
		return 0
	return clampi(int(data.growths.get(key, 0)), 0, 100)


## One roll per stat, without the minimum. Stat key -> 1 for every stat that rose.
static func roll_raw(data: CompanionData, rng: RandomNumberGenerator) -> Dictionary:
	var gains := {}
	for key in GROWTH_STATS:
		# Always draw, so the stream does not depend on the rates.
		if rng.randi_range(1, 100) <= growth_rate(data, key):
			gains[key] = 1
	return gains


## The gains of one level-up, with the minimum applied.
static func roll_gains(data: CompanionData, rng: RandomNumberGenerator) -> Dictionary:
	var gains := roll_raw(data, rng)
	var wanted := mini(RunConfig.MIN_STAT_GAINS, GROWTH_STATS.size())
	while gains.size() < wanted:
		var left: Array[String] = []
		var weights: Array[float] = []
		var total := 0.0
		for key in GROWTH_STATS:
			if not gains.has(key):
				left.append(key)
				weights.append(float(growth_rate(data, key)))
				total += weights[-1]
		if total <= 0.0:
			for i in weights.size():
				weights[i] = 1.0
			total = weights.size()
		var r := rng.randf() * total
		var pick := left[-1]
		for i in left.size():
			r -= weights[i]
			if r < 0.0:
				pick = left[i]
				break
		gains[pick] = 1
	return gains


## Raises the level by one and applies the rolled gains. Returns the gains.
static func level_up(p: CompanionProgress, rng: RandomNumberGenerator) -> Dictionary:
	p.level += 1
	var gains := roll_gains(p.data, rng)
	for key: String in gains:
		p.stat_gains[key] = int(p.stat_gains.get(key, 0)) + int(gains[key])
	return gains


## Adds XP and levels up as often as it reaches. Returns one {"level", "gains"} per level reached.
static func add_xp(p: CompanionProgress, amount: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var ups: Array[Dictionary] = []
	if p.level >= RunConfig.MAX_LEVEL:
		return ups
	p.xp += maxi(0, amount)
	while p.level < RunConfig.MAX_LEVEL and p.xp >= xp_to_next(p.level):
		p.xp -= xp_to_next(p.level)
		ups.append({"level": p.level + 1, "gains": level_up(p, rng)})
	if p.level >= RunConfig.MAX_LEVEL:
		p.xp = 0
	return ups


## "HP +1, STR +1, DEX +1" in stat order.
static func gains_text(gains: Dictionary) -> String:
	var parts: Array[String] = []
	for key in GROWTH_STATS:
		if int(gains.get(key, 0)) > 0:
			parts.append("%s +%d" % [key, int(gains[key])])
	return ", ".join(parts)
