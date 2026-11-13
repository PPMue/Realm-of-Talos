class_name RunCompanion
extends RefCounted
## A companion in the run's roster: who they are, their progress, and the HP they carry between days.
## Stamina is full at the start of every battle, so it does not live here.

var data: CompanionData
var progress: CompanionProgress
var hp: int = 0


static func create(p_data: CompanionData) -> RunCompanion:
	var c := RunCompanion.new()
	c.data = p_data
	c.progress = CompanionProgress.create(p_data)
	c.hp = c.max_hp()
	return c


func display_name() -> String:
	return data.display_name


func max_hp() -> int:
	return data.max_hp + progress.stat_gain(Stat.HP)


func level() -> int:
	return progress.level


func weapon() -> WeaponData:
	return progress.weapon


## The attacker's part of weapon damage with `w` in hand (default: the weapon held), from the stats
## the companion carries between battles, after the weight penalty `w` would bring (see
## CombatMath.attack_power_from). Effects in battle can change it.
func attack_power(w: WeaponData = null) -> int:
	var held := w if w != null else weapon()
	var st := progress.stats()
	var total_weight := 0
	for item: EquipmentData in [held, data.armor, data.accessory]:
		if item != null:
			total_weight += item.weight
	var penalty := CombatMath.weight_penalty(total_weight, int(st.get(Stat.BLD, 0)))
	return CombatMath.attack_power_from(held, int(st.get(Stat.STR, 0)), int(st.get(Stat.MAG, 0)),
		maxi(0, int(st.get(Stat.DEX, 0)) - penalty), maxi(0, int(st.get(Stat.SPD, 0)) - penalty),
		int(st.get(Stat.BLD, 0)))


## "Attack" on the barracks page: attack power with `w` (default: the weapon held) + its Mt. A strike
## deals this minus the target's DEF (RES for a magic weapon).
func attack(w: WeaponData = null) -> int:
	var held := w if w != null else weapon()
	return attack_power(held) + (held.might if held != null else 0)


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 1, max_hp())
	return hp - before
