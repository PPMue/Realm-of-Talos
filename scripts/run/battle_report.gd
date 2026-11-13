class_name BattleReport
extends RefCounted
## What a finished battle did to the run, for the result screen.

var front: Front
var won: bool = false
var gold: int = 0
## Material id -> amount gained.
var materials: Dictionary = {}
var city_damage: int = 0
## Names of companions who were injured at the end (back at 1 HP) and who were removed for good.
var injured: Array[String] = []
var removed: Array[String] = []
## Battle.grade_ups entries: {"actor", "weapon_type", "grade", "art", "equipped"}.
var grade_ups: Array[Dictionary] = []
## XP each companion in `xp_to` received (0 on a loss).
var xp_each: int = 0
var xp_to: Array[String] = []
## One entry per level reached: {"name", "level", "gains"} (gains: stat key -> amount).
var level_ups: Array[Dictionary] = []
## True if this battle ended the run (won or lost).
var run_over: bool = false
