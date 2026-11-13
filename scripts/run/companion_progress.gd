class_name CompanionProgress
extends RefCounted
## What a companion carries from battle to battle: level and XP, stat gains from levels, weapon
## proficiency, combat arts, the weapon in hand, magic proficiency, known spells and their uses left.
## Plain data plus its rules, no nodes or UI. Battle reads and updates it; HP between battles lives in
## RunCompanion, and stamina and injuries are per battle.

var data: CompanionData
## WeaponData.WeaponType -> proficiency points in that type.
var points: Dictionary = {}
var known_arts: Array[CombatArtData] = []
## Arts usable in battle, in the order they appear as actions. At most BattleConfig.MAX_EQUIPPED_ARTS.
var equipped_arts: Array[CombatArtData] = []
## The weapon in hand; starts as CompanionData.weapon. In a run, RunInventory changes it.
var weapon: WeaponData
## Character level (starts at 1) and XP toward the next one. See Levels.
var level: int = 1
var xp: int = 0
## Stat key -> points gained from level-ups, added to the companion's base stats in battle.
var stat_gains: Dictionary = {}
## SpellData.School -> magic proficiency points in that school (same grades as weapons).
var magic_points: Dictionary = {}
## Every spell known, in the order learned. All of them can be cast; there are no slots.
var known_spells: Array[SpellData] = []
## SpellData -> uses left. Lasts between battles and days; Run.rest() refills it.
var spell_uses: Dictionary = {}


## Fresh progress at the start of a run: starting grades, signature art known and equipped.
static func create(p_data: CompanionData) -> CompanionProgress:
	var p := CompanionProgress.new()
	p.data = p_data
	p.weapon = p_data.weapon
	for t: int in WeaponData.WeaponType.values():
		p.points[t] = Proficiency.points_for(p_data.starting_grade(t))
	if p_data.signature_art != null:
		p.learn(p_data.signature_art)
	for s: int in SpellData.School.values():
		p.magic_points[s] = Proficiency.points_for(p_data.starting_magic_grade(s))
	if p_data.signature_spell != null:
		p.learn_spell(p_data.signature_spell)
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
	p.weapon = weapon
	p.level = level
	p.xp = xp
	p.stat_gains = stat_gains.duplicate()
	p.magic_points = magic_points.duplicate()
	p.known_spells = known_spells.duplicate()
	p.spell_uses = spell_uses.duplicate()
	return p


# ---------------------------------------------------------------- stats

## Base stats plus level-up gains.
func stats() -> Dictionary:
	var s := data.base_stats()
	for key: String in stat_gains:
		s[key] = int(s.get(key, 0)) + int(stat_gains[key])
	return s


func stat_gain(key: String) -> int:
	return int(stat_gains.get(key, 0))


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


## The one check of whether this companion may hold `weapon`: the grade in its type, and for a
## two-proficiency weapon also the grade in its second type or school. "" if allowed, else the first
## grade missing: "Needs axe D; Elena is E."
func weapon_block_reason(weapon: WeaponData) -> String:
	if weapon == null:
		return ""
	var who := data.display_name if data != null else "this companion"
	var have := grade(weapon.weapon_type)
	if not Proficiency.meets_requirement(have, weapon):
		return "Needs %s %s; %s is %s." % [WeaponData.type_name(weapon.weapon_type).to_lower(),
			Proficiency.grade_name(weapon.required_grade), who, Proficiency.grade_name(have)]
	if weapon.has_second_requirement():
		have = grade(weapon.second_type) if weapon.second_type >= 0 else magic_grade(weapon.second_school)
		if have < weapon.second_grade:
			return "Needs %s %s; %s is %s." % [weapon.second_name(), Proficiency.grade_name(weapon.second_grade),
				who, Proficiency.grade_name(have)]
	return ""


func can_equip_weapon(weapon: WeaponData) -> bool:
	return weapon_block_reason(weapon) == ""


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


# ---------------------------------------------------------------- magic

func magic_points_in(s: SpellData.School) -> int:
	return int(magic_points.get(s, 0))


func magic_grade(s: SpellData.School) -> int:
	return Proficiency.grade_for_points(magic_points_in(s))


## Adds points in a school (never past the S threshold) and returns how many were added.
func add_magic_points(s: SpellData.School, amount: int) -> int:
	var before := magic_points_in(s)
	magic_points[s] = clampi(before + amount, 0, Proficiency.points_for(Proficiency.max_grade()))
	return magic_points_in(s) - before


## Like progress_to_next(), for a magic school.
func magic_progress_to_next(s: SpellData.School) -> Vector2i:
	var g := magic_grade(s)
	if g >= Proficiency.max_grade():
		return Vector2i.ZERO
	var floor_points := Proficiency.points_for(g)
	return Vector2i(magic_points_in(s) - floor_points, Proficiency.points_for(g + 1) - floor_points)


func knows_spell(spell: SpellData) -> bool:
	return known_spells.has(spell)


## Schools this companion knows at least one spell of, in school order.
func spell_schools() -> Array[int]:
	var out: Array[int] = []
	for s: int in SpellData.School.values():
		for sp in known_spells:
			if sp.school == s:
				out.append(s)
				break
	return out


## Learns a spell with full uses. Learning a spell already known changes nothing. Returns true if new.
func learn_spell(spell: SpellData) -> bool:
	if spell == null or knows_spell(spell):
		return false
	known_spells.append(spell)
	spell_uses[spell] = spell.uses
	return true


func uses_left(spell: SpellData) -> int:
	return int(spell_uses.get(spell, 0)) if knows_spell(spell) else 0


## Spends one use. Returns false (and changes nothing) if none is left.
func spend_use(spell: SpellData) -> bool:
	if uses_left(spell) <= 0:
		return false
	spell_uses[spell] = uses_left(spell) - 1
	return true


## Every known spell back to full uses (the Rest action).
func restore_spell_uses() -> void:
	for sp in known_spells:
		spell_uses[sp] = sp.uses


func has_spent_uses() -> bool:
	for sp in known_spells:
		if uses_left(sp) < sp.uses:
			return true
	return false
