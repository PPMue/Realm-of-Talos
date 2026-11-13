class_name CombatMath
extends RefCounted
## Pure combat formulas. No state, no randomness.
##
## Two kinds of damage: physical (attack power + Mt - DEF) and magic (attack power + Mt - RES). A
## companion's attack power depends on the weapon type (see attack_power); an enemy's, and a spell's
## caster's, is plain STR or MAG. Guard and other damage-taken multipliers apply to both. An effective
## strike or spell deals half as much again (BattleConfig.EFFECTIVE_DAMAGE_BONUS_PERCENT): added to the
## damage left after DEF or RES, before a critical's multiplier.

enum DamageType { PHYSICAL, MAGIC }


static func physical_damage(strength: int, might: int, defense: int) -> int:
	return maxi(BattleConfig.MIN_DAMAGE, strength + might - defense)


## MAG + Mt - RES, at least MIN_DAMAGE. Same shape as physical damage.
static func magic_damage(magic: int, might: int, resistance: int) -> int:
	return maxi(BattleConfig.MIN_DAMAGE, magic + might - resistance)


## The attacker's part of a weapon strike's damage, before the weapon's Mt. By weapon type:
## sword and spear STR, axe STR + BLD / 2, bow (STR + DEX) / 2, dagger (STR + SPD) / 2, every half
## rounded down. A magic weapon uses MAG in place of STR (a magic bow is (MAG + DEX) / 2).
## Pass the stats as they stand in battle: after the weight penalty and any effects.
static func attack_power_from(weapon: WeaponData, strength: int, magic: int, dexterity: int, speed: int,
		build: int) -> int:
	if weapon == null:
		return strength
	var main := magic if weapon.is_magic() else strength
	match weapon.weapon_type:
		WeaponData.WeaponType.AXE:
			return main + floori(build / 2.0)
		WeaponData.WeaponType.BOW:
			return floori((main + dexterity) / 2.0)
		WeaponData.WeaponType.DAGGER:
			return floori((main + speed) / 2.0)
	return main


## `unit`'s attack power with `weapon` (see attack_power_from), from its current stats.
static func attack_power(unit: Combatant, weapon: WeaponData) -> int:
	return attack_power_from(weapon, unit.stat(Stat.STR), unit.stat(Stat.MAG), unit.stat(Stat.DEX),
		unit.stat(Stat.SPD), unit.stat(Stat.BLD))


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


## Damage after DEF or RES, raised by half (rounded down) if the strike is effective; otherwise unchanged.
## Applied before the critical multiplier and the target's damage-taken multiplier.
static func effective_damage(base_damage: int, effective: bool) -> int:
	if not effective:
		return base_damage
	return base_damage + floori(base_damage * BattleConfig.EFFECTIVE_DAMAGE_BONUS_PERCENT / 100.0)


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
## `ignore_percent` is the share of DEF (physical) or RES (magic) ignored. `effective` adds half the
## damage left after DEF or RES. `power` is the attacker's part (a companion's attack_power); -1 uses
## the attacker's STR (physical) or MAG (magic), as enemies and spells do.
## `bonus_damage` is added to each blow after DEF or RES (and effectiveness), never below MIN_DAMAGE,
## then `damage_percent` changes it; `extra_taken_mult` multiplies the target's damage-taken multiplier
## and `taken_flat` is added at the very end (never below MIN_DAMAGE): traits' numbers (see Battle).
static func forecast(attacker: Combatant, might: int, hit: int, crit_bonus: int, target: Combatant,
		ignore_percent: int = 0, damage_type: DamageType = DamageType.PHYSICAL, effective: bool = false,
		power: int = -1, bonus_damage: int = 0, damage_percent: int = 0, extra_taken_mult: float = 1.0,
		taken_flat: int = 0) -> AttackForecast:
	var f := AttackForecast.new()
	f.magic = damage_type == DamageType.MAGIC
	f.effective = effective
	f.hit = hit_chance(hit, attacker.stat(Stat.DEX), target.stat(Stat.SPD), target.stat(Stat.LCK))
	f.crit = crit_chance(attacker.stat(Stat.CRT), target.stat(Stat.LCK), crit_bonus)
	var base := 0
	if f.magic:
		var mag := power if power >= 0 else attacker.stat(Stat.MAG)
		base = magic_damage(mag, might, defense_after_ignore(target.stat(Stat.RES), ignore_percent))
	else:
		var strength := power if power >= 0 else attacker.stat(Stat.STR)
		base = physical_damage(strength, might, defense_after_ignore(target.stat(Stat.DEF), ignore_percent))
	base = effective_damage(base, effective)
	if bonus_damage != 0:
		base = maxi(BattleConfig.MIN_DAMAGE, base + bonus_damage)
	if damage_percent != 0:
		base = maxi(BattleConfig.MIN_DAMAGE, floori(base * (100 + damage_percent) / 100.0))
	var mult := target.damage_taken_mult() * extra_taken_mult
	f.damage = maxi(BattleConfig.MIN_DAMAGE, final_damage(base, false, mult) + taken_flat)
	f.crit_damage = maxi(BattleConfig.MIN_DAMAGE, final_damage(base, true, mult) + taken_flat)
	return f
