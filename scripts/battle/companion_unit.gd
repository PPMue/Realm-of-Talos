class_name CompanionUnit
extends Combatant
## A companion during battle.

enum State { ACTIVE, INJURED }

var data: CompanionData
## Proficiency and arts carried between battles. Battle updates it as the companion fights.
var progress: CompanionProgress
## Proficiency points gained this battle, for BattleConfig.PROFICIENCY_CAP_PER_BATTLE.
var proficiency_gained: int = 0
## Magic points gained this battle (all schools), for BattleConfig.MAGIC_CAP_PER_BATTLE.
var magic_gained: int = 0
var stamina: int = 0
## Number of following player actions this companion sits out.
var recovery: int = 0
var state: State = State.ACTIVE

# --- What traits need to know (see TraitRules), kept by Battle ---
## Actions this companion has finished this battle, and how many of them from the front place.
var actions_taken: int = 0
var front_actions: int = 0
## Their last action was Guard or Focus.
var after_guard_or_focus: bool = false
## Instance ids of enemies: the one they struck last, the one who last landed a blow on them, and
## those who have landed one since their last action. 0 / empty for none.
var last_struck_id: int = 0
var last_hit_by_id: int = 0
var struck_since: Array[int] = []
## Fractions of a proficiency point carried between actions (traits that raise points by a share).
var point_carry: float = 0.0
## Enemy blows that have landed on them, and arts they have used, this battle.
var blows_taken: int = 0
var arts_used: int = 0
## They felled an enemy during the action being taken (cleared when the next action begins).
var felled_this_action: bool = false
## Once-a-battle moments already used: falling below half Health, being saved at 1 Health.
var half_health_done: bool = false
var survived_once: bool = false
## True once one of their strikes or spells has hit this battle (an Hourglass waits for the first).
var first_hit_done: bool = false
## Spells they have cast this battle (a Sage's first costs no use), and injured companions they have
## raised (a Mender: once).
var spells_cast: int = 0
var raises_used: int = 0
## The battle, for traits that depend on it (weak, so the two do not keep each other alive).
var _battle: WeakRef
## True if some trait in the line can change this companion's stats during the battle.
var _battle_stats: bool = false


func _init(p_data: CompanionData, p_progress: CompanionProgress = null) -> void:
	data = p_data
	progress = p_progress if p_progress != null else CompanionProgress.create(p_data)
	display_name = p_data.display_name
	base_stats = progress.stats()
	hp = max_hp()
	stamina = max_stamina()


## What this companion is (CompanionProgress.traits).
func traits() -> Array[TraitData]:
	return progress.traits


## Their traits and what their accessories do (CompanionProgress.effects): what TraitRules reads.
func all_traits() -> Array[TraitData]:
	return progress.all_traits()


## What they have become (CompanionProgress.calling), or null.
func calling() -> CallingData:
	return progress.calling


## The battle this companion is in, or null.
func battle() -> Battle:
	return _battle.get_ref() as Battle if _battle != null else null


## A trait query for this companion in its battle (see TraitRules).
func trait_query(kind: int) -> TraitRules.Query:
	var q := TraitRules.query(kind)
	q.unit = self
	q.battle = battle()
	q.traits = all_traits()
	return q


func max_stamina() -> int:
	return int(base_stats.get(Stat.STA, 0))


func weapon() -> WeaponData:
	return progress.weapon


## Equipped combat arts, in action order.
func arts() -> Array[CombatArtData]:
	return progress.equipped_arts


## Every known spell, in the order learned. All can be cast while they have uses left.
func spells() -> Array[SpellData]:
	return progress.known_spells


## Grade in the type of the weapon held, or -1 without a weapon.
func weapon_grade() -> int:
	return progress.grade(weapon().weapon_type) if weapon() != null else -1


## The attacker's part of this companion's weapon damage with the weapon held, from their current
## stats (see CombatMath.attack_power).
func attack_power() -> int:
	return CombatMath.attack_power(self, weapon())


func total_weight() -> int:
	var total := 0
	for item: EquipmentData in [weapon(), data.armor, data.accessory]:
		if item != null:
			total += item.weight
	return total


func weight_penalty() -> int:
	return CombatMath.weight_penalty(total_weight(), stat(Stat.BLD))


## A stat as it stands in battle: with the held weapon's bonuses (WeaponData.held_stats) and what
## traits add during the battle (a place in the line, say; the plain trait bonuses are already in the
## base stats) on top.
func stat(key: String) -> int:
	var value := super(key)
	var w := weapon()
	if w != null and w.held_stats.has(key):
		value = maxi(0, value + int(w.held_stats[key]))
	if _battle_stats:
		var q := trait_query(TraitModifier.Kind.STAT)
		q.stat = key
		q.battle_only = true
		value = maxi(0, value + TraitRules.sum(q))
	return value


## Effects' aim multipliers times the held weapon's (WeaponData.target_weight_mult) times traits'
## (TraitModifier.Kind.AIM).
func target_weight_mult() -> float:
	var w := weapon()
	return super() * (w.target_weight_mult if w != null else 1.0) * TraitRules.product(trait_query(TraitModifier.Kind.AIM))


## Effects' damage-taken multipliers; a trait or accessory that changes Guard
## (TraitModifier.Kind.GUARD_PERCENT) replaces Guard's share; with more than one, the largest counts.
func damage_taken_mult() -> float:
	var mult := super()
	var guard_percent := 0
	for m in TraitRules.matching(trait_query(TraitModifier.Kind.GUARD_PERCENT)):
		guard_percent = maxi(guard_percent, m.amount)
	if guard_percent > 0 and has_effect("Guard"):
		var guard := get_effect("Guard")
		if guard.damage_taken_mult > 0.0:
			mult = mult / guard.damage_taken_mult * (100 - clampi(guard_percent, 0, 100)) / 100.0
	return mult


## Mt of the weapon held for this companion (WeaponData.might_for).
func weapon_might() -> int:
	return weapon().might_for(progress) if weapon() != null else 0


func stat_penalty(key: String) -> int:
	if key == Stat.DEX or key == Stat.SPD:
		return weight_penalty()
	return 0


func is_active() -> bool:
	return state == State.ACTIVE


func is_injured() -> bool:
	return state == State.INJURED


