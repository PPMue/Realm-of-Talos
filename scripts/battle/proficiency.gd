class_name Proficiency
extends RefCounted
## Weapon proficiency grades and the rules around them. Pure functions, no state.
## A companion's points per weapon type live in CompanionProgress; thresholds in BattleConfig.

enum Grade { E, E_PLUS, D, D_PLUS, C, C_PLUS, B, B_PLUS, A, A_PLUS, S }

const NAMES: Array[String] = ["E", "E+", "D", "D+", "C", "C+", "B", "B+", "A", "A+", "S"]


static func grade_name(grade: int) -> String:
	return NAMES[clampi(grade, 0, NAMES.size() - 1)]


static func max_grade() -> int:
	return Grade.S


## Total points needed to reach `grade`.
static func points_for(grade: int) -> int:
	return BattleConfig.PROFICIENCY_GRADE_POINTS[clampi(grade, 0, max_grade())]


static func grade_for_points(points: int) -> int:
	var grade := Grade.E
	for g in range(max_grade() + 1):
		if points >= points_for(g):
			grade = g
	return grade


## Whether a companion with `grade` in the weapon's type may equip `weapon`.
static func meets_requirement(grade: int, weapon: WeaponData) -> bool:
	return weapon == null or grade >= weapon.required_grade
