class_name CallingData
extends Resource
## A calling (design/callings.md): what a companion becomes at RunConfig.CALLING_LEVEL, chosen from the
## three drawn for them when they first appeared in the run (CompanionProgress.calling_offers). One
## rule that changes what its holder does in a battle (`modifiers`, read by TraitRules like a trait's)
## and a lean in how they grow from then on: points on the day it is taken and three growth rates.
## Every calling is a .tres under res://data/callings, listed in the library (CallingLibrary);
## tools/generate_callings.gd wrote them. Run draws, offers and hands them over.

## In place of a stat key: whichever of Strength and Magic is higher when the calling is taken, and the
## lower one (lead_of).
const LEAD := "LEAD"
const OTHER := "OTHER"

## "warden".
@export var id: String = ""
## "Warden".
@export var display_name: String = ""
## Its rule as it stands on a screen: one line.
@export var rule: String = ""
## A calling of magic opens a school (SpellData.School): the grade is raised to
## RunConfig.CALLING_OPEN_GRADE and one tier I spell of it is learned. -1: a calling of arms, which
## raises the grade of the weapon in hand instead. `either_school`: the holder picks the school.
@export var school: int = -1
@export var either_school: bool = false
## Its rule works through a healing spell: one is always among the spells offered on taking it.
@export var needs_heal: bool = false
## Stat keys (or LEAD / OTHER): the first rises RunConfig.CALLING_FIRST_GAIN on taking and grows
## CALLING_FIRST_GROWTH faster, the second CALLING_SECOND_GAIN and CALLING_SECOND_GROWTH; the slow one
## grows CALLING_SLOW_GROWTH slower. Health counts RunConfig.CALLING_HP_PER_POINT for one on taking.
@export var first_stat: String = ""
@export var second_stat: String = ""
@export var slow_stat: String = ""
## The rule (TraitModifier), read wherever traits are read.
@export var modifiers: Array[TraitModifier] = []
## The two masteries its holder chooses between at RunConfig.MASTERY_LEVEL (MasteryData).
@export var masteries: Array[MasteryData] = []


func is_magic() -> bool:
	return school >= 0 or either_school


## The schools it can open: none (arms), one, or both for the holder to pick from.
func schools() -> Array[int]:
	var out: Array[int] = []
	if either_school:
		out.append_array(SpellData.School.values())
	elif school >= 0:
		out.append(school)
	return out


## Whichever of Strength and Magic `p` has more of, as who they are (base stats, levels and traits; not
## what they wear or hold). A tie goes to the one that grows faster, then to Strength.
static func lead_of(p: CompanionProgress) -> String:
	var s := _own(p, Stat.STR)
	var m := _own(p, Stat.MAG)
	if s != m:
		return Stat.STR if s > m else Stat.MAG
	return Stat.MAG if int(p.data.growths.get(Stat.MAG, 0)) > int(p.data.growths.get(Stat.STR, 0)) else Stat.STR


static func _own(p: CompanionProgress, key: String) -> int:
	return int(p.data.base_stats().get(key, 0)) + p.stat_gain(key) + p.trait_stat_bonus(key)


## `token` as a stat key for a holder whose lead is `lead` (Stat.STR or Stat.MAG).
static func resolve(token: String, lead: String) -> String:
	if token == LEAD:
		return lead
	if token == OTHER:
		return Stat.MAG if lead == Stat.STR else Stat.STR
	return token


## What is gained the day it is taken: stat key -> points.
func gains_for(lead: String) -> Dictionary:
	var out := {}
	for pair in [[first_stat, RunConfig.CALLING_FIRST_GAIN], [second_stat, RunConfig.CALLING_SECOND_GAIN]]:
		var key := resolve(pair[0], lead)
		if key == "":
			continue
		var n: int = pair[1] * (RunConfig.CALLING_HP_PER_POINT if key == Stat.HP else 1)
		out[key] = int(out.get(key, 0)) + n
	return out


## The growth rates it changes: stat key -> percentage points.
func growth_for(lead: String) -> Dictionary:
	var out := {}
	for pair in [[first_stat, RunConfig.CALLING_FIRST_GROWTH], [second_stat, RunConfig.CALLING_SECOND_GROWTH],
			[slow_stat, RunConfig.CALLING_SLOW_GROWTH]]:
		var key := resolve(pair[0], lead)
		if key != "":
			out[key] = int(out.get(key, 0)) + int(pair[1])
	return out


## The calling as the rules read it for a holder whose lead is `lead`: its rule, the rule of the
## `mastery` taken (null: none yet) and its growth rates, as one list of modifiers
## (CompanionProgress.all_traits).
func effect_for(lead: String, mastery: MasteryData = null) -> TraitData:
	var t := TraitData.new()
	t.id = "calling_%s" % id
	t.display_name = display_name
	t.gives = [rule]
	t.modifiers = modifiers.duplicate()
	if mastery != null:
		t.id = "calling_%s_%s" % [id, mastery.id]
		t.gives.append(mastery.rule)
		t.modifiers.append_array(mastery.modifiers)
	var growth := growth_for(lead)
	for key: String in growth:
		var m := TraitModifier.new()
		m.kind = TraitModifier.Kind.GROWTH
		m.stat = key
		m.amount = int(growth[key])
		t.modifiers.append(m)
	return t
