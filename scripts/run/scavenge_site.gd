class_name ScavengeSite
extends RefCounted
## A place beyond the walls offered for scavenging on a free day (Run.scavenge_sites). Two are rolled
## each free day; sending a party there is the day's one action (Run.scavenge). Everything the player
## sees before committing (places, targets, the haul) is fixed when the site is rolled.
## Numbers in RunConfig (SCAVENGE_*).

enum Risk { LOW, MEDIUM, HIGH }

const RISK_NAMES: Array[String] = ["Low", "Medium", "High"]
## By size 1, 2, 3.
const SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]

## The stats a place can test, and the word for whoever fills it.
const ROLES := {
	Stat.SPD: "Scout",
	Stat.STR: "Breaker",
	Stat.BLD: "Hauler",
	Stat.DEX: "Picker",
	Stat.LCK: "Finder",
	Stat.DEF: "Guard",
	Stat.RES: "Ward",
	Stat.MAG: "Seer",
}
## In the order above (ROLES keys), for drawing.
const ROLE_STATS: Array[String] = [Stat.SPD, Stat.STR, Stat.BLD, Stat.DEX, Stat.LCK, Stat.DEF, Stat.RES, Stat.MAG]

const NAMES: Array[String] = [
	"The Burnt Mill", "The Drowned Quarter", "The Old Toll House", "Ravens' Barrow", "The Sunken Chapel",
	"The Collapsed Mine", "The Hollow Orchard", "The Broken Aqueduct", "The Lost Caravan",
	"Ashfield Farmstead", "The Watchman's Ruin", "The Silent Kiln", "Thornwick Village",
]


## One place in the party: the stat it tests, the value that meets it, and the role's name.
class Slot:
	extends RefCounted
	## A Stat key (one of ROLE_STATS).
	var stat: String = ""
	var target: int = 0
	## "Scout", "Breaker", ...
	var role: String = ""


var display_name: String = ""
## 1 small, 2 medium, 3 large: also how many go (one per slot).
var size: int = 1
var risk: Risk = Risk.LOW
## One per place, every stat different.
var slots: Array[Slot] = []

# --- What a full haul brings ---
var gold: int = 0
## Material id -> amount (may be empty).
var materials: Dictionary = {}
## Percent: a full haul also finds a weapon (drawn like an event's).
var weapon_chance: int = 0
## XP to each companion sent.
var xp_each: int = 0


func risk_name() -> String:
	return RISK_NAMES[risk]


func size_name() -> String:
	return SIZE_NAMES[clampi(size - 1, 0, SIZE_NAMES.size() - 1)]


## Total pieces of material in a full haul.
func material_count() -> int:
	var n := 0
	for m: String in materials:
		n += int(materials[m])
	return n
