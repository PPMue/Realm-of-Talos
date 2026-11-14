class_name Accessory
extends RefCounted
## An accessory the company owns: a type (AccessoryTypeData) set with a stone of `rank` (Gem, 1-5). Made
## at the Jeweler (Run.craft), kept in Run.accessories, worn by at most one companion
## (CompanionProgress.accessories; Run.wear). Never re-made, upgraded, broken up or sold.

var type: AccessoryTypeData
var rank: int = 1
var _effect: TraitData


func _init(p_type: AccessoryTypeData = null, p_rank: int = 1) -> void:
	type = p_type
	rank = clampi(p_rank, 1, Gem.max_rank())


## "Topaz Ring".
func title() -> String:
	return "%s %s" % [Gem.name_of(rank), type.display_name if type != null else "?"]


## What it gives (and takes), one short line each.
func lines() -> Array[String]:
	return type.lines(rank) if type != null else ([] as Array[String])


func is_two_edged() -> bool:
	return type != null and type.is_two_edged()


## What it does, as a trait for TraitRules (made once).
func effect() -> TraitData:
	if _effect == null and type != null:
		_effect = type.trait_for(rank, title())
	return _effect
