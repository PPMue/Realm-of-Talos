class_name Combatant
extends RefCounted
## Runtime battle state shared by companions and enemies. No nodes, no UI.

var display_name: String = ""
var base_stats: Dictionary = {}       ## Stat key -> int
var hp: int = 0
var effects: Array[StatusEffect] = []


func max_hp() -> int:
	return int(base_stats.get(Stat.HP, 1))


## Effective stat after status effects and penalties, never below 0.
func stat(key: String) -> int:
	var value := int(base_stats.get(key, 0))
	for e in effects:
		value += e.stat_mod(key)
	value -= stat_penalty(key)
	return maxi(0, value)


## Overridden by subclasses (e.g. equipment weight).
func stat_penalty(_key: String) -> int:
	return 0


func damage_taken_mult() -> float:
	var mult := 1.0
	for e in effects:
		mult *= e.damage_taken_mult
	return mult


func target_weight_mult() -> float:
	var mult := 1.0
	for e in effects:
		mult *= e.target_weight_mult
	return mult


func has_effect(effect_name: String) -> bool:
	for e in effects:
		if e.display_name == effect_name:
			return true
	return false


## Share (percent) of weapon and art damage this unit deals back to whoever lands it.
func reflect_percent() -> int:
	var total := 0
	for e in effects:
		total += e.reflect_percent
	return total


## Adds an effect; an effect with the same name is refreshed rather than stacked, unless it stacks
## (max_stacks above 1): then it keeps its stacks, gains one up to the most, and is refreshed.
func add_effect(effect: StatusEffect) -> void:
	for e in effects.duplicate():
		if e.display_name == effect.display_name:
			if effect.max_stacks > 1:
				effect.stacks = mini(effect.max_stacks, e.stacks + 1)
			effects.erase(e)
	effects.append(effect)


func get_effect(effect_name: String) -> StatusEffect:
	for e in effects:
		if e.display_name == effect_name:
			return e
	return null


## Counts every effect down by one tick and returns the ones that expired.
func tick_effects() -> Array[StatusEffect]:
	var expired: Array[StatusEffect] = []
	for e in effects:
		e.ticks_left -= 1
		if e.ticks_left <= 0:
			expired.append(e)
	for e in expired:
		effects.erase(e)
	return expired
