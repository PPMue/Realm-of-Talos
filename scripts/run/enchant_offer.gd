class_name EnchantOffer
extends RefCounted
## An enchanting attempt waiting for the player's choice (Run.enchant, Run.enchant_offer): what the
## weapon has now and the new rolls the smith offers. Run.take_enchant(index) takes a roll,
## Run.keep_enchant() keeps what it has; the cost is already paid.

var weapon: OwnedWeapon
## A copy of what the weapon holds now (empty if plain).
var current: Dictionary = {}
## The new enchantments offered (one; two with the Smithy's level 2), each stat key -> amount.
var rolls: Array[Dictionary] = []
## What the attempt cost: material id -> amount, and "gold".
var cost: Dictionary = {}
