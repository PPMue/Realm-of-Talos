class_name Drill
extends RefCounted
## One drill posted at the training ground for the week (Run.drills): Sparring (XP) or a proficiency
## drill in one weapon type or one magic school. See Run.train() and RunConfig's drill numbers.

enum Kind { SPARRING, WEAPON, MAGIC }

var kind: Kind = Kind.SPARRING
## WeaponData.WeaponType for a WEAPON drill, else -1.
var weapon_type: int = -1
## SpellData.School for a MAGIC drill, else -1.
var school: int = -1
## "Sparring", "Spear drill", "Black Magic drill".
var display_name: String = ""


static func sparring() -> Drill:
	var d := Drill.new()
	d.kind = Kind.SPARRING
	d.display_name = "Sparring"
	return d


static func weapon(t: WeaponData.WeaponType) -> Drill:
	var d := Drill.new()
	d.kind = Kind.WEAPON
	d.weapon_type = t
	d.display_name = "%s drill" % WeaponData.type_name(t)
	return d


static func magic(s: SpellData.School) -> Drill:
	var d := Drill.new()
	d.kind = Kind.MAGIC
	d.school = s
	d.display_name = "%s drill" % SpellData.school_name(s)
	return d


## True for a weapon or magic drill (it trains a grade), false for Sparring.
func is_proficiency() -> bool:
	return kind != Kind.SPARRING


## "spear", "black magic"; "" for Sparring.
func subject_name() -> String:
	match kind:
		Kind.WEAPON:
			return WeaponData.type_name(weapon_type).to_lower()
		Kind.MAGIC:
			return SpellData.school_name(school).to_lower()
	return ""


## The grade `p` has in what this drill trains; -1 for Sparring.
func grade_of(p: CompanionProgress) -> int:
	match kind:
		Kind.WEAPON:
			return p.grade(weapon_type)
		Kind.MAGIC:
			return p.magic_grade(school)
	return -1


## Adds proficiency points to `p` in what this drill trains; returns how many were added.
func add_points(p: CompanionProgress, amount: int) -> int:
	match kind:
		Kind.WEAPON:
			return p.add_points(weapon_type, amount)
		Kind.MAGIC:
			return p.add_magic_points(school, amount)
	return 0
