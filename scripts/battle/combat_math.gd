class_name CombatMath
extends RefCounted
## Pure combat formulas. No state, no randomness.
##
## Two kinds of damage: physical (STR + Mt - DEF) and magic (MAG + Mt - RES). Guard and other
## damage-taken multipliers apply to both. An effective strike doubles Mt before the target's DEF or
## RES is subtracted (BattleConfig.EFFECTIVE_MIGHT_MULT).

enum DamageType { PHYSICAL, MAGIC }


static func physical_damage(strength: int, might: int, defense: int) -> int:
	return maxi(BattleConfig.MIN_DAMAGE, strength + might - defense)


## MAG + Mt - RES, at least MIN_DAMAGE. Same shape as physical damage.
static func magic_damage(magic: int, might: int, resistance: int) -> int:
	return maxi(BattleConfig.MIN_DAMAGE, magic + might - resistance)


static func hit_chance(hit: int, attacker_dex: int, target_spd: int, target_lck: int) -> int:
	var value := hit + BattleConfig.ACCURACY_DEX_SPD_FACTOR * (attacker_dex - target_spd) - target_lck
	return clampi(value, BattleConfig.ACCURACY_MIN, BattleConfig.ACCURACY_MAX)


static func crit_chance(attacker_crt: int, target_lck: int, bonus: int = 0) -> int:
	var value := BattleConfig.CRIT_CRT_FACTOR * attacker_crt - target_lck + bonus
	return clampi(value, BattleConfig.CRIT_MIN, BattleConfig.CRIT_MAX)


## Applies crit and the target's damage-taken multiplier (Guard, Defend) to base damage.
## Rounds down, but never below MIN_DAMAGE.
static func final_damage(base_damage: int, is_crit: bool, damage_taken_mult: float) -> int:
	var dmg := float(base_damage)
	if is_crit:
		dmg *= BattleConfig.CRIT_DAMAGE_MULT
	dmg *= damage_taken_mult
	return maxi(BattleConfig.MIN_DAMAGE, floori(dmg))


static func weight_penalty(total_weight: int, build: int) -> int:
	return maxi(0, total_weight - build) * BattleConfig.WEIGHT_PENALTY_PER_POINT


## Mt of an effective strike (doubled), or unchanged.
static func effective_might(might: int, effective: bool) -> int:
	return might * BattleConfig.EFFECTIVE_MIGHT_MULT if effective else might


## True if `traits` (an enemy's) holds any of `against` (a weapon's, art's or spell's list).
static func is_effective(against: Array[String], traits: Array[String]) -> bool:
	for t in against:
		if traits.has(t):
			return true
	return false


## DEF (or RES) left after ignoring a share of it, rounded down.
static func defense_after_ignore(defense: int, ignore_percent: int) -> int:
	return floori(defense * (100 - clampi(ignore_percent, 0, 100)) / 100.0)


## Full forecast of one strike. Works for companions and enemies alike.
## `might` is already doubled for an effective strike. `ignore_percent` is the share of DEF (physical)
## or RES (magic) ignored.
static func forecast(attacker: Combatant, might: int, hit: int, crit_bonus: int, target: Combatant,
		ignore_percent: int = 0, damage_type: DamageType = DamageType.PHYSICAL) -> AttackForecast:
	var f := AttackForecast.new()
	f.magic = damage_type == DamageType.MAGIC
	f.hit = hit_chance(hit, attacker.stat(Stat.DEX), target.stat(Stat.SPD), target.stat(Stat.LCK))
	f.crit = crit_chance(attacker.stat(Stat.CRT), target.stat(Stat.LCK), crit_bonus)
	var base := 0
	if f.magic:
		base = magic_damage(attacker.stat(Stat.MAG), might, defense_after_ignore(target.stat(Stat.RES), ignore_percent))
	else:
		base = physical_damage(attacker.stat(Stat.STR), might, defense_after_ignore(target.stat(Stat.DEF), ignore_percent))
	var mult := target.damage_taken_mult()
	f.damage = final_damage(base, false, mult)
	f.crit_damage = final_damage(base, true, mult)
	return f
