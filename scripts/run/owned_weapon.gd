class_name OwnedWeapon
extends RefCounted
## One weapon in the run inventory. Two of the same weapon are two OwnedWeapons.
## `holder` is the companion holding it, or null while it sits in the armory.
##
## It may be enchanted (Run.enchant): each level is +1 to one stat while it is held. The holder's
## progress carries the held weapon's enchantment (CompanionProgress.enchant), so their stats include it.

var data: WeaponData
var holder: RunCompanion
## The stat each enchantment level gave (Stat keys), in the order gained. Its size is the level.
var enchant_order: Array[String] = []
## Levels of enchantment (0: none).
var enchant_level: int:
	get:
		return enchant_order.size()
## Stat key -> amount it gives while held (only stats that came up).
var enchant_stats: Dictionary:
	get:
		var out := {}
		for key in enchant_order:
			out[key] = int(out.get(key, 0)) + 1
		return out


func _init(p_data: WeaponData = null) -> void:
	data = p_data


## "Iron Sword +2"; just the name without enchantment.
func title() -> String:
	if data == null:
		return ""
	return data.display_name if enchant_level == 0 else "%s +%d" % [data.display_name, enchant_level]


## What the enchantment gives, one line a stat, in stat order: "+1 Strength", "+2 Speed".
func enchant_lines() -> Array[String]:
	var out: Array[String] = []
	var s := enchant_stats
	for key in Stat.COMPANION_KEYS:
		if s.has(key):
			out.append("+%d %s" % [int(s[key]), Stat.name_of(key)])
	return out
