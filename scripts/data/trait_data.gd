class_name TraitData
extends Resource
## A trait: something a companion is, rolled when they join and never changed (RunCompanion.traits,
## kept in CompanionProgress.traits). What it does is its list of modifiers (TraitModifier), each a
## number with optional conditions, worked out by TraitRules. The design and every trait's wording:
## design/traits.md. How they are handed out: Run (RunConfig.TRAIT_*). Every trait is a .tres in
## res://data/traits, listed in the library (TraitLibrary).

enum Family { WEAPON_HANDS, SCHOOLS, BODY_AND_MIND, TWO_EDGED, THE_LINE, TEMPO, STAYING_ALIVE, LEARNING,
	THE_CITY, THE_COMPANY }
enum Rarity { COMMON, UNCOMMON, RARE }

const FAMILY_NAMES: Array[String] = ["Weapon hands", "Schools of magic", "Body and mind", "Two-edged",
	"The line", "Tempo", "Staying alive", "Learning", "The city", "The company"]
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare"]

## "sword_sure", "reckless".
@export var id: String = ""
## "Sword: Sure", "Reckless".
@export var display_name: String = ""
@export var family: Family = Family.BODY_AND_MIND
@export var rarity: Rarity = Rarity.COMMON
## A companion never has two traits of the same family and line: the word of a weapon hand ("Sure"),
## a school's word ("Deep"), "Growing"; every other trait is a line of its own (its id).
@export var line: String = ""
## Tied to a weapon type (WeaponData.WeaponType) or a school (SpellData.School): handed mostly to
## someone who can already use it. -1 if not.
@export var weapon_type: int = -1
@export var school: int = -1
## What it gives, one short line each, as in the design ("+10 Hit with axes").
@export var gives: Array[String] = []
## What it takes (two-edged traits only).
@export var takes: Array[String] = []
@export var modifiers: Array[TraitModifier] = []


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func family_name() -> String:
	return FAMILY_NAMES[family]


func is_two_edged() -> bool:
	return family == Family.TWO_EDGED


## What it gives, one short line each.
func lines() -> Array[String]:
	return gives.duplicate()


## What it takes; empty unless two-edged.
func drawback_lines() -> Array[String]:
	return takes.duplicate()


## True if it is tied to a weapon type or a school.
func is_tied() -> bool:
	return weapon_type >= 0 or school >= 0


## The key two traits of one companion may not share.
func line_key() -> String:
	return "%d:%s" % [family, line if line != "" else id]
