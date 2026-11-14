class_name Gem
extends RefCounted
## The gemstones, weakest to strongest, by rank 1 to 5. A run keeps them like materials (Run.gems);
## they do nothing yet. Pure data, no state.
##
## The five big fights before the last boss (days 6, 14, 20, 28, 34) each give the next stone when won
## (Run.gem_for_fight); scavenging and some events give one of the current rank (Run.gem_rank_now).

const TOPAZ := 1
const SAPPHIRE := 2
const EMERALD := 3
const RUBY := 4
const DIAMOND := 5

## Index rank - 1.
const NAMES: Array[String] = ["Topaz", "Sapphire", "Emerald", "Ruby", "Diamond"]


static func max_rank() -> int:
	return NAMES.size()


static func is_rank(rank: int) -> bool:
	return rank >= 1 and rank <= max_rank()


## "Topaz" for 1 .. "Diamond" for 5; "" for anything else (0 is "no stone").
static func name_of(rank: int) -> String:
	return NAMES[rank - 1] if is_rank(rank) else ""
