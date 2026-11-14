class_name OwnedWeapon
extends RefCounted
## One weapon in the run inventory. Two of the same weapon are two OwnedWeapons.
## `holder` is the companion holding it, or null while it sits in the armory.
##
## It is plain or enchanted (Run.enchant): an enchantment is a set of stat changes while it is held,
## adding up to the weapon's budget (Run.enchant_budget), at most one of them negative. The holder's
## progress carries the held weapon's enchantment (CompanionProgress.enchant), so their stats include it.

var data: WeaponData
var holder: RunCompanion
## Stat key -> amount while held (one may be negative); empty: plain.
var enchant_stats: Dictionary = {}


func _init(p_data: WeaponData = null) -> void:
	data = p_data


func is_enchanted() -> bool:
	return not enchant_stats.is_empty()


## "Iron Sword+", or just the name when plain.
func title() -> String:
	if data == null:
		return ""
	return "%s+" % data.display_name if is_enchanted() else data.display_name


## What the enchantment gives, one line a stat: "+2 Strength", "-1 Luck" (positives in stat order,
## the negative last).
func enchant_lines() -> Array[String]:
	return stat_lines(enchant_stats)


## The same lines for any set of stat changes (an offered roll, say).
static func stat_lines(stats: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var minus: Array[String] = []
	for key in Stat.COMPANION_KEYS:
		var n := int(stats.get(key, 0))
		if n > 0:
			out.append("+%d %s" % [n, Stat.name_of(key)])
		elif n < 0:
			minus.append("%d %s" % [n, Stat.name_of(key)])
	out.append_array(minus)
	return out
