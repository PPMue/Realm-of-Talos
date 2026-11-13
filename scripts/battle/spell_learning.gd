class_name SpellLearning
extends RefCounted
## Which spell a companion learns when a magic school's grade rises. Same rules as combat arts
## (see ArtLearning): roll a tier from BattleConfig.ART_TIER_ODDS for the grade just reached, pick a
## random unknown spell of that tier and school, fall through to the nearest tier that still has one
## (lower first on a tie), and learn nothing once every spell of the school is known.
## Signature spells are in the pool like any other; a mage already knows their own.


## Spells of school `s` in `pool` that `progress` does not know yet.
static func unknown_spells(progress: CompanionProgress, s: SpellData.School, pool: Array[SpellData]) -> Array[SpellData]:
	var out: Array[SpellData] = []
	for sp in pool:
		if sp != null and sp.school == s and not progress.knows_spell(sp) and not out.has(sp):
			out.append(sp)
	return out


## The tier closest to `wanted` that has at least one of `spells`; 0 if `spells` is empty.
static func nearest_tier(spells: Array[SpellData], wanted: int) -> int:
	var tiers: Array[int] = []
	for sp in spells:
		tiers.append(sp.tier)
	return ArtLearning.nearest_of(tiers, wanted)


## The spell learned on reaching `grade` in school `s`, or null if every spell of it is known.
## Does not change `progress`.
static func pick_spell(rng: RandomNumberGenerator, progress: CompanionProgress, s: SpellData.School,
		grade: int, pool: Array[SpellData]) -> SpellData:
	var open := unknown_spells(progress, s, pool)
	if open.is_empty():
		return null
	var tier := nearest_tier(open, ArtLearning.roll_tier(rng, grade))
	var of_tier: Array[SpellData] = []
	for sp in open:
		if sp.tier == tier:
			of_tier.append(sp)
	return of_tier[rng.randi_range(0, of_tier.size() - 1)]
