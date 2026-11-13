class_name DrillResult
extends RefCounted
## What one drill at the training ground did (Run.train), for the screen that shows it.

enum Quality { POOR, GOOD, GREAT }

const QUALITY_NAMES: Array[String] = ["Poor", "Good", "Great"]

var drill: Drill
var companion: RunCompanion
var quality: Quality = Quality.GOOD
## "Poor", "Good" or "Great".
var quality_name: String = ""
## Gold paid (RunConfig.DRILL_COST).
var gold_spent: int = 0

# --- A proficiency drill (0 / -1 for Sparring) ---
## Points added toward the next grade (fewer than rolled if the S cap was reached).
var points_gained: int = 0
var grade_before: int = -1
var grade_after: int = -1
## Every grade reached, in order, shaped like Battle.grade_ups entries:
## weapons {"actor" (the RunCompanion), "magic": false, "weapon_type", "grade", "art", "equipped"},
## magic {"actor", "magic": true, "school", "grade", "spell"}. "art" / "spell" may be null.
var grade_ups: Array[Dictionary] = []

# --- Sparring (0 / empty for a proficiency drill) ---
var xp_gained: int = 0
## Level before the drill.
var level_before: int = 0
## Stats (base + gains) before the drill.
var stats_before: Dictionary = {}
## One entry per level reached, shaped like BattleReport.level_ups ({"name", "level", "gains"}) plus
## "level_from" (the level it rose from) and "before" (the stats at level_from), for the level-up panel.
var level_ups: Array[Dictionary] = []


## True if the drill reached at least one new grade.
func new_grade() -> bool:
	return not grade_ups.is_empty()
