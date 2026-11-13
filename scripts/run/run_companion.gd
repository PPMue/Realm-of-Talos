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


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 1, max_hp())
	return hp - before
