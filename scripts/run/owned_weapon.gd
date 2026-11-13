class_name OwnedWeapon
extends RefCounted
## One weapon in the run inventory. Two of the same weapon are two OwnedWeapons.
## `holder` is the companion holding it, or null while it sits in the armory.

var data: WeaponData
var holder: RunCompanion


func _init(p_data: WeaponData = null) -> void:
	data = p_data
