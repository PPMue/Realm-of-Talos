class_name CraftOffer
extends RefCounted
## What the Jeweler shows after a craft is paid for (Run.craft): the stone's rank and the designs drawn,
## one (level 1) or two different ones (level 2). Kept in Run.craft_offer until one is taken
## (Run.take_craft); an offer still open when the day ends takes the first.

var rank: int = 1
var designs: Array[AccessoryTypeData] = []
## What was paid: "gold" and the stone ("gem": its rank).
var cost: Dictionary = {}
