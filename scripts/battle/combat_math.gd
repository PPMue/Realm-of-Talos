class_name CombatMath
extends RefCounted
## Pure combat formulas. No state, no randomness.


static func physical_damage(strength: int, might: int, defense: int) -> int:
	return maxi(BattleConfig.MIN_DAMAGE, strength + might - defense)


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


## Full forecast of one physical strike. Works for companions and enemies alike.
static func forecast(attacker: Combatant, might: int, hit: int, crit_bonus: int, target: Combatant) -> AttackForecast:
	var f := AttackForecast.new()
	f.hit = hit_chance(hit, attacker.stat(Stat.DEX), target.stat(Stat.SPD), target.stat(Stat.LCK))
	f.crit = crit_chance(attacker.stat(Stat.CRT), target.stat(Stat.LCK), crit_bonus)
	var base := physical_damage(attacker.stat(Stat.STR), might, target.stat(Stat.DEF))
	var mult := target.damage_taken_mult()
	f.damage = final_damage(base, false, mult)
	f.crit_damage = final_damage(base, true, mult)
	return f
