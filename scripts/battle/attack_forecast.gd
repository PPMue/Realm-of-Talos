class_name AttackForecast
extends RefCounted
## What a strike will do if it lands. Shown to the player before confirming.

var hit: int = 0           ## percent
var crit: int = 0          ## percent
var damage: int = 0        ## damage on a normal hit, after the target's modifiers
var crit_damage: int = 0   ## damage on a critical hit
## Magic damage (MAG against RES) rather than physical (STR against DEF).
var magic := false
## The strike is effective against the target (Mt doubled).
var effective := false
