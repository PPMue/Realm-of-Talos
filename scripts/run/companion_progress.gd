class_name CompanionProgress
extends RefCounted
## What a companion carries from battle to battle: weapon proficiency and combat arts.
## The seed of the run state. Plain data plus its rules, no nodes or UI.
## Battle reads and updates it; HP, stamina and injuries are per battle and do not live here.

var data: CompanionData
## WeaponData.WeaponType -> proficiency points in that type.
var points: Dictionary = {}
var known_arts: Array[CombatArtData] = []
## Arts usable in battle, in the order they appear as actions. At most BattleConfig.MAX_EQUIPPED_ARTS.
var equipped_arts: Array[CombatArtData] = []


## Fresh progress at the start of a run: starting grades, signature art known and equipped.
static func create(p_data: CompanionData) -> CompanionProgress:
	var p := CompanionProgress.new()
	p.data = p_data
	for t: int in WeaponData.WeaponType.values():
		p.points[t] = Proficiency.points_for(p_data.starting_grade(t))
	if p_data.signature_art != null:
		p.learn(p_data.signature_art)
	return p


static func create_party(companions: Array[CompanionData]) -> Array[CompanionProgress]:
	var out: Array[CompanionProgress] = []
	for d in companions:
		out.append(create(d))
	return out


func copy() -> CompanionProgress:
	var p := CompanionProgress.new()
	p.data = data
	p.points = points.duplicate()
	p.known_arts = known_arts.duplicate()
	p.equipped_arts = equipped_arts.duplicate()
	return p


# ---------------------------------------------------------------- proficiency

func points_in(t: WeaponData.WeaponType) -> int:
	return int(points.get(t, 0))


func grade(t: WeaponData.WeaponType) -> int:
	return Proficiency.grade_for_points(points_in(t))


## Adds points (never past the S threshold) and returns how many were added.
func add_points(t: WeaponData.WeaponType, amount: int) -> int:
	var before := points_in(t)
	points[t] = clampi(before + amount, 0, Proficiency.points_for(Proficiency.max_grade()))
	return points_in(t) - before


## Points earned since the current grade, and points that grade needs to reach the next.
## Vector2i(0, 0) at the top grade.
func progress_to_next(t: WeaponData.WeaponType) -> Vector2i:
	var g := grade(t)
	if g >= Proficiency.max_grade():
		return Vector2i.ZERO
	var floor_points := Proficiency.points_for(g)
	return Vector2i(points_in(t) - floor_points, Proficiency.points_for(g + 1) - floor_points)


func can_equip_weapon(weapon: WeaponData) -> bool:
	return weapon == null or Proficiency.meets_requirement(grade(weapon.weapon_type), weapon)


# ---------------------------------------------------------------- arts

func knows(art: CombatArtData) -> bool:
	return known_arts.has(art)


func is_equipped(art: CombatArtData) -> bool:
	return equipped_arts.has(art)


func has_free_slot() -> bool:
	return equipped_arts.size() < BattleConfig.MAX_EQUIPPED_ARTS


## Learns an art and equips it if a slot is free. Returns true if it was equipped.
## Learning an art already known changes nothing.
func learn(art: CombatArtData) -> bool:
	if art == null or knows(art):
		return false
	known_arts.append(art)
	return equip(art)


func equip(art: CombatArtData) -> bool:
	if not knows(art) or is_equipped(art) or not has_free_slot():
		return false
	equipped_arts.append(art)
	return true


func unequip(art: CombatArtData) -> bool:
	if not is_equipped(art):
		return false
	equipped_arts.erase(art)
	return true
