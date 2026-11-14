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
## What this companion is (TraitData), rolled when they join a run and never changed. See TraitRules.
var traits: Array[TraitData] = []
## The held weapon's enchantment (OwnedWeapon.enchant_stats): stat key -> amount; kept by RunInventory.
var enchant: Dictionary = {}
## The accessories worn (Accessory), in the order put on; at most RunConfig.MAX_ACCESSORIES. Kept by
## Run (wear, take_off).
var accessories: Array = []
## The callings drawn for them when they first appeared in the run (design/callings.md), and the one
## taken at RunConfig.CALLING_LEVEL (null until then). `calling_lead`: which of Strength and Magic led
## when it was taken (Stat.STR or Stat.MAG), for the stats a calling names by it. Kept by Run.
var calling_offers: Array[CallingData] = []
## Callings put aside at the Drill Yard (Run.redraw_calling): never drawn for them again.
var calling_aside: Array[CallingData] = []
var calling: CallingData
var calling_lead: String = ""
var _calling_effect: TraitData


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
	p.traits = traits.duplicate()
	p.enchant = enchant.duplicate()
	p.accessories = accessories.duplicate()
	p.calling_offers = calling_offers.duplicate()
	p.calling_aside = calling_aside.duplicate()
	p.calling = calling
	p.calling_lead = calling_lead
	return p


## Their traits and what the accessories they wear do (each an Accessory.effect): every list of
## modifiers the rules count (TraitRules). `traits` alone is who they are.
func all_traits() -> Array[TraitData]:
	if accessories.is_empty() and calling == null:
		return traits
	var out: Array[TraitData] = traits.duplicate()
	if calling != null:
		out.append(calling_effect())
	for a in accessories:
		out.append(a.effect())
	return out


## Their calling as the rules read it (CallingData.effect_for): its rule and its growth rates. Null
## without one.
func calling_effect() -> TraitData:
	if calling == null:
		return null
	if _calling_effect == null or _calling_effect.id != "calling_%s" % calling.id:
		_calling_effect = calling.effect_for(calling_lead if calling_lead != "" else CallingData.lead_of(self))
	return _calling_effect


## Takes `c` as their calling: the lead is fixed now, and what it gives on the day is added to their
## stats as a level-up's gains are. Returns those gains (stat key -> points). Run.take_calling does the
## rest (the school or the weapon grade it opens).
func take_calling(c: CallingData) -> Dictionary:
	calling_lead = CallingData.lead_of(self)
	calling = c
	_calling_effect = null
	var gains := c.gains_for(calling_lead)
	for key: String in gains:
		stat_gains[key] = int(stat_gains.get(key, 0)) + int(gains[key])
	return gains


## The accessories' effects alone.
func accessory_effects() -> Array[TraitData]:
	var out: Array[TraitData] = []
	for a in accessories:
		out.append(a.effect())
	return out


# ---------------------------------------------------------------- stats

## Base stats plus level-up gains plus what traits add without conditions (trait_stat_bonus) plus the
## held weapon's enchantment (enchant_stat_bonus) plus the accessories worn (accessory_stat_bonus), never
## below 0 (Health never below 1). Bonuses that depend on the battle (a place in the line, say) are
## added in battle by CompanionUnit.stat.
func stats() -> Dictionary:
	var s := data.base_stats()
	for key: String in stat_gains:
		s[key] = int(s.get(key, 0)) + int(stat_gains[key])
	if not traits.is_empty() or not enchant.is_empty() or not accessories.is_empty():
		for key: String in s:
			s[key] = maxi(1 if key == Stat.HP else 0, int(s[key]) + trait_stat_bonus(key) + enchant_stat_bonus(key)
				+ accessory_stat_bonus(key))
	return s


## What the accessories worn add to stat `key` (can be negative: a two-edged one). Included in stats().
func accessory_stat_bonus(key: String) -> int:
	if accessories.is_empty():
		return 0
	return TraitRules.plain_stat(accessory_effects(), key)


## What the held weapon's enchantment adds to stat `key`. Included in stats().
func enchant_stat_bonus(key: String) -> int:
	return int(enchant.get(key, 0))


## What traits add to stat `key` without conditions (can be negative). Included in stats().
func trait_stat_bonus(key: String) -> int:
	return TraitRules.plain_stat(traits, key)


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


## Leaves the equipped `old` behind and carries the known, unequipped `new` in its place (same slot).
## Returns false and changes nothing otherwise.
func swap(old: CombatArtData, new: CombatArtData) -> bool:
	if not is_equipped(old) or not knows(new) or is_equipped(new):
		return false
	equipped_arts[equipped_arts.find(old)] = new
	return true


## Stamina `art` costs this companion: its own cost plus what their traits add
## (TraitModifier.Kind.ART_STAMINA), never below 0. In battle Battle.art_cost says the same.
func art_cost(art: CombatArtData) -> int:
	if art == null:
		return 0
	return maxi(0, art.stamina_cost + TraitRules.total(all_traits(), TraitModifier.Kind.ART_STAMINA, art.weapon_type))


## Health `art` costs them in place of stamina (a Berserker: TraitModifier.Kind.ART_COSTS_HEALTH, that
## percent of art_cost rounded up); 0 if they pay in stamina. In battle Battle.art_health_cost.
func art_health_cost(art: CombatArtData) -> int:
	var percent := TraitRules.total(all_traits(), TraitModifier.Kind.ART_COSTS_HEALTH)
	if art == null or percent <= 0:
		return 0
	return ceili(art_cost(art) * percent / 100.0)


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
	spell_uses[spell] = max_uses(spell)
	return true


## Uses of `spell` when full: its own, plus what traits add (TraitModifier.Kind.SPELL_USES).
func max_uses(spell: SpellData) -> int:
	if spell == null:
		return 0
	var e := all_traits()
	var n := maxi(0, spell.uses + TraitRules.total(e, TraitModifier.Kind.SPELL_USES, -1, spell.school, spell.tier))
	var loss := TraitRules.total(e, TraitModifier.Kind.SPELL_USES_LOSS)
	return maxi(mini(1, n), n - loss) if loss > 0 else n


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
		spell_uses[sp] = max_uses(sp)


func has_spent_uses() -> bool:
	for sp in known_spells:
		if uses_left(sp) < max_uses(sp):
			return true
	return false
