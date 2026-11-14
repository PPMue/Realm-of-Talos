class_name AttackForecast
extends RefCounted
## What a strike will do if it lands. Shown to the player before confirming.

var hit: int = 0           ## percent
var crit: int = 0          ## percent
var damage: int = 0        ## damage on a normal hit, after the target's modifiers
var crit_damage: int = 0   ## damage on a critical hit
## Magic damage (MAG against RES) rather than physical (STR against DEF).
var magic := false
## The strike is effective against the target (half as much damage again, before a critical).
var effective := false
## Damage the striker takes back from a reflecting target on a normal hit, and on a critical hit.
## 0 when the target reflects nothing. Spells never are.
var reflect: int = 0
var reflect_crit: int = 0
## Strikes the action makes, each rolled on its own and each doing the figures above: an art's
## `strikes`, or for a plain Attack the weapon's `attack_strikes`.
var strikes: int = 1
## What the striker's calling adds if the strike lands (design/callings.md); all 0 or false without one.
## An Executioner: the target is felled if a hit leaves it at this much Health or less.
var execute_at: int = 0
## A Champion: the target's pending single blow turns on the striker.
var turns_aim := false
## A Harrier: turns the target's next action is pushed back (0 if it has already been pushed).
var staggers: int = 0


## True if a normal hit would fell `target_hp` by the Executioner's rule (and not by the damage alone).
func fells_by_rule(target_hp: int) -> bool:
	var left := target_hp - damage
	return execute_at > 0 and left > 0 and left <= execute_at
