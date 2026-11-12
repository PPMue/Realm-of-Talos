class_name AttackForecast
extends RefCounted
## What a strike will do if it lands. Shown to the player before confirming.

var hit: int = 0           ## percent
var crit: int = 0          ## percent
var damage: int = 0        ## damage on a normal hit, after the target's modifiers
var crit_damage: int = 0   ## damage on a critical hit
