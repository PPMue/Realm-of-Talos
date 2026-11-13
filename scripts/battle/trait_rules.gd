class_name TraitRules
extends RefCounted
## Works out what companions' traits (TraitData, CompanionProgress.traits) add to a number. Pure
## functions; Battle, Run, Levels and CompanionProgress call them wherever the number is used, so what
## the screens show already includes traits.
##
## A query names the kind of number (TraitModifier.Kind) and what it is for: the stat, the action, the
## weapon type or school, the enemy aimed at, the level reached. In a battle the companion it is for
## (`unit`) also collects the modifiers of the companions beside and in front of them that are meant
## for them (TraitModifier.Who). Out of a battle only the companion's own modifiers without battle
## conditions count.


## What a number is for.
class Query:
	extends RefCounted
	var kind: int = TraitModifier.Kind.STAT
	var stat: String = ""
	## The companion's traits (out of a battle; in one `unit` is used).
	var traits: Array[TraitData] = []
	## In a battle: the companion it is for, and the battle.
	var unit: CompanionUnit
	var battle: Battle
	var target: EnemyUnit
	var action: int = TraitModifier.Action.ANY
	var weapon_type: int = -1
	var school: int = -1
	var spell_tier: int = 0
	## GROWTH: the level being reached.
	var level: int = 0
	var whole_line: bool = false
	## True: only modifiers with battle conditions (the plain ones are already in the base stats).
	var battle_only: bool = false


static func query(kind: int) -> Query:
	var q := Query.new()
	q.kind = kind
	return q


## Sum of the matching modifiers' amounts.
static func sum(q: Query) -> int:
	var total := 0
	for m in matching(q):
		total += m.amount
	return total


## Product of the matching modifiers' `mult`.
static func product(q: Query) -> float:
	var total := 1.0
	for m in matching(q):
		total *= m.mult
	return total


## Product of (100 + amount) / 100 over the matching modifiers.
static func percent_product(q: Query) -> float:
	var total := 1.0
	for m in matching(q):
		total *= (100.0 + m.amount) / 100.0
	return total


## True if any modifier matches.
static func any(q: Query) -> bool:
	return not matching(q).is_empty()


## Every modifier that counts for `q`.
static func matching(q: Query) -> Array[TraitModifier]:
	var out: Array[TraitModifier] = []
	if q.unit != null and q.battle != null:
		var l := q.battle.roster
		var i := l.find(q.unit)
		var holders: Array = [[q.unit, TraitModifier.Who.SELF]]
		if i >= 0:
			if i > 0:
				holders.append([l[i - 1], TraitModifier.Who.NEIGHBOURS])
			if i < l.size() - 1:
				holders.append([l[i + 1], TraitModifier.Who.NEIGHBOURS])
				holders.append([l[i + 1], TraitModifier.Who.BEHIND])   # q.unit stands behind l[i + 1]
		for h: Array in holders:
			var holder: CompanionUnit = h[0]
			if holder != q.unit and not holder.is_active():
				continue
			for t in holder.traits():
				for m in t.modifiers:
					if m.who == h[1] and _holds(m, q, holder):
						out.append(m)
		return out
	var traits := q.traits if q.unit == null else q.unit.traits()
	for t in traits:
		for m in t.modifiers:
			if m.who == TraitModifier.Who.SELF and not m.is_battle_only() and _holds(m, q, null):
				out.append(m)
	return out


static func _holds(m: TraitModifier, q: Query, holder: CompanionUnit) -> bool:
	if m.kind != q.kind:
		return false
	if q.battle_only and not m.is_battle_only() and m.who == TraitModifier.Who.SELF:
		return false
	if (m.kind == TraitModifier.Kind.STAT or m.kind == TraitModifier.Kind.GROWTH) and m.stat != "" and m.stat != q.stat:
		return false
	if m.weapon_type >= 0 and m.weapon_type != q.weapon_type:
		return false
	if m.school >= 0 and m.school != q.school:
		return false
	if m.spell_tier > 0 and m.spell_tier != q.spell_tier:
		return false
	if m.action != TraitModifier.Action.ANY and m.action != q.action:
		return false
	if m.level_to > 0 and q.level > m.level_to:
		return false
	if m.level_from > 0 and q.level < m.level_from:
		return false
	if m.whole_line_blows and not q.whole_line:
		return false
	if not m.is_battle_only():
		return true
	if holder == null or q.battle == null:
		return false
	return _battle_holds(m, q, holder)


static func _battle_holds(m: TraitModifier, q: Query, holder: CompanionUnit) -> bool:
	var b := q.battle
	var l := b.roster
	var i := l.find(holder)
	var front := i == l.size() - 1
	var rear := i == 0
	match m.place:
		TraitModifier.Place.FRONT:
			if not front:
				return false
		TraitModifier.Place.REAR:
			if not rear:
				return false
		TraitModifier.Place.MIDDLE:
			if front or rear:
				return false
		TraitModifier.Place.NOT_FRONT:
			if front:
				return false
	if m.line_at_most > 0 and l.size() > m.line_at_most:
		return false
	if m.line_full and l.size() < RunConfig.MAX_FIELDED:
		return false
	if m.only_standing:
		var up := b.active_companions()
		if up.size() != 1 or up[0] != holder:
			return false
	if m.self_health == TraitModifier.Health.BELOW_HALF and holder.hp * 2 >= holder.max_hp():
		return false
	if m.self_health == TraitModifier.Health.FULL and holder.hp < holder.max_hp():
		return false
	var number := holder.actions_taken + 1
	if m.action_from > 0 and number < m.action_from:
		return false
	if m.action_to > 0 and number > m.action_to:
		return false
	if m.after_guard_or_focus and not holder.after_guard_or_focus:
		return false
	if m.first_front_action and holder.front_actions > 0:
		return false
	var needs_target := m.target_health != TraitModifier.Health.ANY or m.target_trait != "" or m.target_boss \
		or m.target_next_magic or m.struck != TraitModifier.Struck.ANY
	if not needs_target:
		return true
	var e := q.target
	if e == null:
		return false
	if m.target_health == TraitModifier.Health.BELOW_HALF and e.hp * 2 >= e.max_hp():
		return false
	if m.target_health == TraitModifier.Health.FULL and e.hp < e.max_hp():
		return false
	if m.target_trait != "" and not e.traits().has(m.target_trait):
		return false
	if m.target_boss and e.data.band != 0:
		return false
	if m.target_next_magic and (e.pending_action == null or not e.pending_action.deals_damage
			or e.pending_action.damage_type != CombatMath.DamageType.MAGIC):
		return false
	var id := e.get_instance_id()
	match m.struck:
		TraitModifier.Struck.LAST_STRUCK:
			if holder.last_struck_id == 0 or holder.last_struck_id != id:
				return false
		TraitModifier.Struck.NOT_LAST_STRUCK:
			if holder.last_struck_id == 0 or holder.last_struck_id == id:
				return false
		TraitModifier.Struck.HIT_ME_LAST:
			if holder.last_hit_by_id != id:
				return false
		TraitModifier.Struck.STRUCK_ME_SINCE:
			if not holder.struck_since.has(id):
				return false
	return true


# ---------------------------------------------------------------- out of a battle

## The plain bonus to stat `key` from `traits` (no conditions): what the barracks shows.
static func plain_stat(traits: Array[TraitData], key: String) -> int:
	var total := 0
	for t in traits:
		for m in t.modifiers:
			if m.kind == TraitModifier.Kind.STAT and m.stat == key and m.is_plain():
				total += m.amount
	return total


## The sum of `kind` from `traits` out of a battle, for a weapon type, school, spell tier or level.
static func total(traits: Array[TraitData], kind: int, weapon_type: int = -1, school: int = -1, spell_tier: int = 0,
		level: int = 0, stat: String = "") -> int:
	var q := query(kind)
	q.traits = traits
	q.weapon_type = weapon_type
	q.school = school
	q.spell_tier = spell_tier
	q.level = level
	q.stat = stat
	return sum(q)
