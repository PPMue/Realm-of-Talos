class_name EnchantResult
extends RefCounted
## What one enchanting attempt did (Run.enchant), for the screen that shows it.

var weapon: OwnedWeapon
var level_before: int = 0
## 1, or 2 when the attempt came out double (room allowing).
var levels_gained: int = 0
## The stat each new level gave, in order (Stat keys).
var stats: Array[String] = []
## True if the attempt rolled the double (+2), whether or not the cap let both levels in.
var double: bool = false
## What it cost: material id -> amount, and "gold".
var cost: Dictionary = {}


## "+1 Strength", one line a level gained, in order.
func lines() -> Array[String]:
	var out: Array[String] = []
	for key in stats:
		out.append("+1 %s" % Stat.name_of(key))
	return out
