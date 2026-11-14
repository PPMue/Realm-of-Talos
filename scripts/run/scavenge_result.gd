class_name ScavengeResult
extends RefCounted
## What one scavenging trip did (Run.scavenge), for the screen that shows it.

enum Outcome { FULL, HALF, NOTHING }

## As the player reads them: a success is the full haul, passable half of it, a failure nothing.
const OUTCOME_NAMES: Array[String] = ["Success", "Passable", "Failure"]


## What happened to one companion sent, in slot order.
class Member:
	extends RefCounted
	var companion: RunCompanion
	## The slot they filled (index into site.slots).
	var slot: int = 0
	var xp_gained: int = 0
	## Level before the trip.
	var level_before: int = 0
	## Stats (base + gains) before the trip.
	var stats_before: Dictionary = {}
	## One entry per level reached, shaped like DrillResult.level_ups ({"name", "level", "gains",
	## "level_from", "before"}), for the level-up panel.
	var level_ups: Array[Dictionary] = []
	## HP lost on the way (0 if none; the injured lose all of it and go to the infirmary).
	var hp_lost: int = 0


var site: ScavengeSite
## The companions sent, indexed by slot.
var party: Array[RunCompanion] = []
## The chance (percent) shown before committing, and the roll (1-100; under or at the chance is a
## full haul).
var chance: int = 0
var roll: int = 0
var outcome: Outcome = Outcome.NOTHING
## What was brought home (already added to the run).
var gold: int = 0
var materials: Dictionary = {}
## Already in the armory; null if none.
var weapon_found: WeaponData
## The rank of a gemstone (Gem) brought home, already in Run.gems; 0 for none. Only on a success,
## RunConfig.SCAVENGE_GEM_PERCENT of the time, of the current rank (Run.gem_rank_now).
var gem: int = 0
## One per companion sent, in slot order.
var members: Array[Member] = []
## Who was injured and went to the infirmary (high risk, nothing found), or null.
var injured: RunCompanion


func outcome_name() -> String:
	return OUTCOME_NAMES[outcome]


## The entry for `c`, or null if they were not sent.
func member_of(c: RunCompanion) -> Member:
	for m in members:
		if m.companion == c:
			return m
	return null


## Every level-up of the trip, in slot order.
func level_ups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in members:
		out.append_array(m.level_ups)
	return out
