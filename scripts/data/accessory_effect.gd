class_name AccessoryEffect
extends Resource
## One number an accessory changes (AccessoryTypeData.effects): a TraitModifier with its conditions set,
## and the value it takes at each stone's rank. Accessory.effect turns them into a TraitData for the rank,
## so the accessory counts wherever traits do (TraitRules).

## Which field of the modifier the rank sets.
enum Field { AMOUNT, MULT, ACTION_TO }

## The modifier, with its kind, stat and conditions; its own amount or mult is used when `by_rank` is
## empty (the fixed price of a two-edged type).
@export var modifier: TraitModifier
## The value at Topaz, Sapphire, Emerald, Ruby, Diamond (5 entries), or empty for a fixed one.
@export var by_rank: Array[float] = []
@export var field: Field = Field.AMOUNT


## The modifier as it is at `rank` (1-5): a copy with the rank's value set.
func modifier_at(rank: int) -> TraitModifier:
	var m := modifier.duplicate() as TraitModifier
	if by_rank.is_empty():
		return m
	var v: float = by_rank[clampi(rank, 1, by_rank.size()) - 1]
	match field:
		Field.AMOUNT:
			m.amount = roundi(v)
		Field.MULT:
			m.mult = v
		Field.ACTION_TO:
			m.action_to = roundi(v)
	return m
