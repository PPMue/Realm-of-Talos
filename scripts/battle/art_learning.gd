class_name ArtLearning
extends RefCounted
## Which art a companion learns when a weapon grade rises. Static rules; the caller passes the
## battle's seeded RandomNumberGenerator so results are reproducible.
##
## 1. Roll a tier from BattleConfig.ART_TIER_ODDS for the grade just reached.
## 2. Pick a random unknown art of that tier and weapon type.
## 3. If every art of that tier is known, use the nearest tier that still has one (lower first on a tie).
## 4. If every art of the type is known, nothing is learned.


static func roll_tier(rng: RandomNumberGenerator, grade: int) -> int:
	var odds: Array = BattleConfig.ART_TIER_ODDS[clampi(grade, 0, BattleConfig.ART_TIER_ODDS.size() - 1)]
	var r := rng.randi_range(1, 100)
	var total := 0
	for i in odds.size():
		total += int(odds[i])
		if r <= total:
			return i + 1
	return odds.size()


## Grade steps a companion's traits add when the tier of what they learn is rolled
## (TraitModifier.Kind.LEARN_GRADE_STEPS: Apprentice draws as if a letter higher).
static func learn_steps(progress: CompanionProgress) -> int:
	return TraitRules.total(progress.all_traits(), TraitModifier.Kind.LEARN_GRADE_STEPS) if progress != null else 0


## Arts of type `t` in `pool` that `progress` does not know yet.
static func unknown_arts(progress: CompanionProgress, t: WeaponData.WeaponType, pool: Array[CombatArtData]) -> Array[CombatArtData]:
	var out: Array[CombatArtData] = []
	for a in pool:
		if a != null and a.weapon_type == t and not progress.knows(a) and not out.has(a):
			out.append(a)
	return out


## The tier closest to `wanted` that has at least one of `arts`; 0 if `arts` is empty.
static func nearest_tier(arts: Array[CombatArtData], wanted: int) -> int:
	var tiers: Array[int] = []
	for a in arts:
		tiers.append(a.tier)
	return nearest_of(tiers, wanted)


## The value in `tiers` closest to `wanted` (lower first on a tie); 0 if `tiers` is empty.
static func nearest_of(tiers: Array[int], wanted: int) -> int:
	for distance in 3:
		for t: int in [wanted - distance, wanted + distance]:
			if tiers.has(t):
				return t
	return 0


## The art learned on reaching `grade` in type `t`, or null if every art of the type is known.
## Does not change `progress`.
static func pick_art(rng: RandomNumberGenerator, progress: CompanionProgress, t: WeaponData.WeaponType,
		grade: int, pool: Array[CombatArtData]) -> CombatArtData:
	var open := unknown_arts(progress, t, pool)
	if open.is_empty():
		return null
	var tier := nearest_tier(open, roll_tier(rng, grade + learn_steps(progress)))
	var of_tier: Array[CombatArtData] = []
	for a in open:
		if a.tier == tier:
			of_tier.append(a)
	return of_tier[rng.randi_range(0, of_tier.size() - 1)]
