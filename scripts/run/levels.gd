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


## Shares of a won battle's XP `pool`, one per companion, given their contribution points (`points`).
## RunConfig.XP_EVEN_SHARE_PERCENT of the pool is split evenly, the rest in proportion to points; if
## nobody earned a point, the whole pool is split evenly. Each share is rounded down and the XP left
## over goes 1 at a time to the highest scorers (line order on a tie), so the shares always add up to
## the pool exactly.
static func split_xp(pool: int, points: Array[int]) -> Array[int]:
	var n := points.size()
	var shares: Array[int] = []
	if n == 0:
		return shares
	var total := 0
	for p in points:
		total += maxi(0, p)
	var even := RunConfig.XP_EVEN_SHARE_PERCENT if total > 0 else 100
	# Exact share i = pool x (even x total + (100 - even) x n x points[i]) / (100 x n x total).
	var denom := 100 * n * maxi(1, total)
	var given := 0
	for p in points:
		var num := pool * (even * maxi(1, total) + (100 - even) * n * maxi(0, p))
		if total == 0:
			num = pool * 100   # every share pool / n
		var share := num / denom
		shares.append(share)
		given += share
	var order: Array[int] = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return points[a] > points[b] or (points[a] == points[b] and a < b))
	var left := pool - given
	var k := 0
	while left > 0:
		shares[order[k % n]] += 1
		left -= 1
		k += 1
	return shares


## Total XP from level 1 to reach `level`.
static func total_xp_for(level: int) -> int:
	var total := 0
	for l in range(1, mini(level, RunConfig.MAX_LEVEL)):
		total += xp_to_next(l)
	return total


## Growth rate (0-100) of one stat, the companion's own. BLD never grows. See growth_rate_of for one
## with traits.
static func growth_rate(data: CompanionData, key: String) -> int:
	if key == Stat.BLD or not GROWTH_STATS.has(key):
		return 0
	return clampi(int(data.growths.get(key, 0)), 0, 100)


## Growth rate (0-100) of one stat for `p`'s next level-up (or the one reaching `level`): their own plus
## what their traits add (TraitModifier.Kind.GROWTH). BLD never grows.
static func growth_rate_of(p: CompanionProgress, key: String, level: int = -1) -> int:
	if key == Stat.BLD or not GROWTH_STATS.has(key):
		return 0
	var reaching := level if level > 0 else p.level + 1
	var bonus := TraitRules.total(p.traits, TraitModifier.Kind.GROWTH, -1, -1, 0, reaching, key)
	return clampi(int(p.data.growths.get(key, 0)) + bonus, 0, 100)


## Every growing stat's rate: the companion's own, or with `p` given, for p's next level-up.
static func rates(data: CompanionData, p: CompanionProgress = null) -> Dictionary:
	var out := {}
	for key in GROWTH_STATS:
		out[key] = growth_rate_of(p, key) if p != null else growth_rate(data, key)
	return out


## One roll per stat, without the minimum. Stat key -> 1 for every stat that rose. With `p`, its
## traits count (see growth_rate_of).
static func roll_raw(data: CompanionData, rng: RandomNumberGenerator, p: CompanionProgress = null) -> Dictionary:
	var gains := {}
	var r := rates(data, p)
	for key in GROWTH_STATS:
		# Always draw, so the stream does not depend on the rates.
		if rng.randi_range(1, 100) <= int(r[key]):
			gains[key] = 1
	return gains


## The gains of one level-up, with the minimum applied. With `p`, its traits count.
static func roll_gains(data: CompanionData, rng: RandomNumberGenerator, p: CompanionProgress = null) -> Dictionary:
	var gains := roll_raw(data, rng, p)
	var rate := rates(data, p)
	var wanted := mini(RunConfig.MIN_STAT_GAINS, GROWTH_STATS.size())
	while gains.size() < wanted:
		var left: Array[String] = []
		var weights: Array[float] = []
		var total := 0.0
		for key in GROWTH_STATS:
			if not gains.has(key):
				left.append(key)
				weights.append(float(rate[key]))
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
	var gains := roll_gains(p.data, rng, p)   # rolled for the level being reached (p.level + 1)
	p.level += 1
	for key: String in gains:
		p.stat_gains[key] = int(p.stat_gains.get(key, 0)) + int(gains[key])
	return gains


## XP `p` gets from `amount`: changed by their traits (TraitModifier.Kind.XP_PERCENT), rounded down.
static func with_traits(p: CompanionProgress, amount: int) -> int:
	var percent := TraitRules.total(p.traits, TraitModifier.Kind.XP_PERCENT)
	return maxi(0, amount * (100 + percent) / 100) if percent != 0 else amount


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
