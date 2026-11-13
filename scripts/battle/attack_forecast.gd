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
