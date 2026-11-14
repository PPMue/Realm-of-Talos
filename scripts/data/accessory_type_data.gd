class_name AccessoryTypeData
extends Resource
## One of the 54 accessory types (design/accessories.md): what it does at each stone's rank (Gem, 1-5).
## Every type is a .tres under res://data/accessories/<family>/, listed in AccessoryLibrary. An owned one
## is an Accessory (a type and a rank). What it does is its effects (AccessoryEffect), worked out as a
## TraitData for the rank (trait_for), so TraitRules counts it with the wearer's traits.

enum Family { PLAIN, STRIKING, STANDING, TEMPO, MAGIC, THE_LINE, THE_ROAD, TWO_EDGED }

const FAMILY_NAMES: Array[String] = ["Plain", "Striking", "Standing", "Breath and tempo", "Magic", "The line",
	"The road", "Two-edged"]

## "ring", "two_edged_mask" style ids: the file name.
@export var id: String = ""
## "Ring".
@export var display_name: String = ""
@export var family: Family = Family.PLAIN
## What it gives at each rank, one line each (Topaz first): "+3 Strength".
@export var gives: Array[String] = []
## What a two-edged type takes, the same at every rank ("-10 Hit"); "" otherwise.
@export var takes: String = ""
@export var effects: Array[AccessoryEffect] = []


func family_name() -> String:
	return FAMILY_NAMES[family]


func is_two_edged() -> bool:
	return family == Family.TWO_EDGED


## What it gives at `rank` (1-5), one short line.
func gives_line(rank: int) -> String:
	if gives.is_empty():
		return ""
	return gives[clampi(rank, 1, gives.size()) - 1]


## What it takes; "" unless two-edged.
func takes_line() -> String:
	return takes


## Every line at `rank`: what it gives, then what it takes (if anything).
func lines(rank: int) -> Array[String]:
	var out: Array[String] = [gives_line(rank)]
	if takes != "":
		out.append(takes)
	return out


## What it does at `rank` as a trait (for TraitRules): its effects' modifiers with the rank's values.
## `title` is the name the trait carries in reports ("Topaz Bangle").
func trait_for(rank: int, title: String = "") -> TraitData:
	var t := TraitData.new()
	t.id = "accessory_%s" % id
	t.display_name = title if title != "" else display_name
	t.gives.assign([gives_line(rank)])
	if takes != "":
		t.takes.assign([takes])
	for e in effects:
		t.modifiers.append(e.modifier_at(rank))
	return t
