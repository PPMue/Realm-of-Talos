class_name RunCompanion
extends RefCounted
## A companion in the run's roster: who they are, their progress, and the HP they carry between days.
## Stamina is full at the start of every battle, so it does not live here.

var data: CompanionData
var progress: CompanionProgress
var hp: int = 0
## In the infirmary: injured in a battle, away until `back_on_day` (see Run.infirmary). They cannot be
## fielded or trained and are skipped by Rest, the daily heal and events; their weapon and progress stay.
var injured: bool = false
## The day they come out by themselves (at its start, at full HP, onto the bench); 0 when not injured.
var back_on_day: int = 0
## What this companion is (TraitData): kept in their progress, so a battle sees the same list.
var traits: Array[TraitData]:
	get:
		return progress.traits
	set(value):
		progress.traits = value


static func create(p_data: CompanionData) -> RunCompanion:
	var c := RunCompanion.new()
	c.data = p_data
	c.progress = CompanionProgress.create(p_data)
	c.hp = c.max_hp()
	return c


## Days still to serve on `today` (the days until they come out by themselves): RunConfig.INFIRMARY_DAYS
## on the day after the injury, 1 on the last day; 0 when not injured.
func days_left(today: int) -> int:
	return maxi(0, back_on_day - today) if injured else 0


## Not in the infirmary: can be fielded, trained and healed.
func is_available() -> bool:
	return not injured


func display_name() -> String:
	return data.display_name


## Max HP: base, level-ups and traits (see CompanionProgress.stats).
func max_hp() -> int:
	return int(progress.stats()[Stat.HP])


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
	if held != null:
		for key: String in held.held_stats:
			st[key] = int(st.get(key, 0)) + int(held.held_stats[key])
	var total_weight := 0
	for item: EquipmentData in [held, data.armor, data.accessory]:
		if item != null:
			total_weight += item.weight
	var penalty := CombatMath.weight_penalty(total_weight, int(st.get(Stat.BLD, 0)))
	return CombatMath.attack_power_from(held, int(st.get(Stat.STR, 0)), int(st.get(Stat.MAG, 0)),
		maxi(0, int(st.get(Stat.DEX, 0)) - penalty), maxi(0, int(st.get(Stat.SPD, 0)) - penalty),
		int(st.get(Stat.BLD, 0)))


## "Attack" on the barracks page: attack power with `w` (default: the weapon held) + its Mt for this
## companion (WeaponData.might_for). A strike deals this minus the target's DEF (RES for a magic
## weapon). Bonuses while held count.
func attack(w: WeaponData = null) -> int:
	var held := w if w != null else weapon()
	return attack_power(held) + (held.might_for(progress) if held != null else 0)


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 1, max_hp())
	return hp - before
