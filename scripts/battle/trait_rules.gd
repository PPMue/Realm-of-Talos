class_name TraitRules
extends RefCounted
## Works out what companions' traits (TraitData, CompanionProgress.traits) and the accessories they wear
## (each worked out as a TraitData: CompanionProgress.effects) add to a number. Pure
## functions; Battle, Run, Levels and CompanionProgress call them wherever the number is used, so what
## the screens show already includes traits.
##
## A query names the kind of number (TraitModifier.Kind) and what it is for: the stat, the action, the
## weapon type or school, the enemy aimed at, the level reached, the kind of blow. In a battle the
## companion it is for (`unit`) also collects the modifiers of the companions in the line that are
## meant for them (TraitModifier.Who: beside them, in front of them, anyone else). Out of a battle only
## the companion's own modifiers without battle conditions count; the company-wide ones (the city's)
## are summed by Run over everyone not in the Infirmary.


## What a number is for.
class Query:
	extends RefCounted
	var kind: int = TraitModifier.Kind.STAT
	var stat: String = ""
	## The companion's traits (out of a battle; in one `unit` is used).
	var traits: Array[TraitData] = []
	## Out of a battle, for conditions that read the companion (their second-best weapon).
	var progress: CompanionProgress
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
	## A blow taken: TraitModifier.Blow.
	var blow: int = TraitModifier.Blow.ANY
	## RECOVERY: the action's own recovery (for TraitModifier.recovery_at_least).
	var recovery: int = 0
	## True: only modifiers with battle conditions (the plain ones are already in the base stats).
	var battle_only: bool = false
	## Out of a battle: whose modifiers count (TraitModifier.Who; SELF the companion's own).
	var who: int = TraitModifier.Who.SELF


static func query(kind: int) -> Query:
	var q := Query.new()
	q.kind = kind
	return q


## Sum of the matching modifiers' amounts (one counting once per standing neighbour of its holder:
## TraitModifier.per_neighbour).
static func sum(q: Query) -> int:
	var total := 0
	for pair in matching_with_holders(q):
		var m: TraitModifier = pair[0]
		total += m.amount * (_standing_neighbours(q, pair[1]) if m.per_neighbour else 1)
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
	return not matching_with_holders(q).is_empty()


## Every modifier that counts for `q`.
static func matching(q: Query) -> Array[TraitModifier]:
	var out: Array[TraitModifier] = []
	for pair in matching_with_holders(q):
		out.append(pair[0])
	return out


## Every modifier that counts for `q`, each with its holder ([TraitModifier, CompanionUnit or null]).
static func matching_with_holders(q: Query) -> Array:
	var out: Array = []
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
			for other in l:
				if other != q.unit:
					holders.append([other, TraitModifier.Who.ALLIES])
		for h: Array in holders:
			var holder: CompanionUnit = h[0]
			if holder != q.unit and not holder.is_active():
				continue
			for t in holder.all_traits():
				for m in t.modifiers:
					if m.who == h[1] and _holds(m, q, holder):
						out.append([m, holder])
		return out
	var traits := q.traits if q.unit == null else q.unit.all_traits()
	for t in traits:
		for m in t.modifiers:
			if m.who == q.who and not m.is_battle_only() and _holds(m, q, null):
				out.append([m, null])
	return out


static func _standing_neighbours(q: Query, holder: CompanionUnit) -> int:
	if holder == null or q.battle == null:
		return 0
	var l := q.battle.roster
	var i := l.find(holder)
	var n := 0
	for j in [i - 1, i + 1]:
		if i >= 0 and j >= 0 and j < l.size() and l[j].is_active():
			n += 1
	return n


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
	if m.blow != TraitModifier.Blow.ANY and m.blow != q.blow:
		return false
	if m.recovery_at_least > 0 and q.recovery < m.recovery_at_least:
		return false
	if m.second_best_weapon:
		var p := holder.progress if holder != null else q.progress
		if p == null or q.weapon_type < 0 or second_best_type(p) != q.weapon_type:
			return false
	if not m.is_battle_only():
		return true
	if holder == null or q.battle == null:
		return false
	return _battle_holds(m, q, holder)


## The weapon type of `p`'s second-best grade (by points; a tie goes to the type listed first).
static func second_best_type(p: CompanionProgress) -> int:
	var types: Array = WeaponData.WeaponType.values()
	types.sort_custom(func(a: int, b: int) -> bool:
		return p.points_in(a) > p.points_in(b) or (p.points_in(a) == p.points_in(b) and a < b))
	return types[1]


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
	if m.self_hp_at_most > 0 and holder.hp > m.self_hp_at_most:
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
	if m.first_blow_taken and holder.blows_taken > 0:
		return false
	if m.first_art and holder.arts_used > 0:
		return false
	if m.first_spell and holder.spells_cast > 0:
		return false
	if m.after_spell and not holder.after_spell:
		return false
	if m.ally_injured and not b.injured_ever.any(func(c: CompanionUnit) -> bool: return c != holder):
		return false
	if m.rival_ahead and not l.any(func(c: CompanionUnit) -> bool: return c != holder and b.kills_of(c) > b.kills_of(holder)):
		return false
	if m.big_fight and not b.elite and (q.target == null or q.target.data.band != 0):
		return false
	var needs_target := m.target_health != TraitModifier.Health.ANY or m.target_trait != "" or m.target_boss \
		or m.target_next_magic or m.struck != TraitModifier.Struck.ANY or m.target_turns_at_most > 0 or m.aim_turned
	if not needs_target:
		return true
	var e := q.target
	if e == null:
		return false
	if m.target_health == TraitModifier.Health.BELOW_HALF and e.hp * 2 >= e.max_hp():
		return false
	if m.target_health == TraitModifier.Health.FULL and e.hp < e.max_hp():
		return false
	if m.target_trait != "" and not Array(m.target_trait.split("|")).any(func(x: String) -> bool: return e.traits().has(x)):
		return false
	if m.target_boss and e.data.band != 0:
		return false
	if m.target_turns_at_most > 0 and (e.pending_action == null or e.countdown > m.target_turns_at_most):
		return false
	if m.aim_turned and e.turned_by_id != holder.get_instance_id():
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


## The sum of `kind` from `traits` out of a battle, for a weapon type, school, spell tier, level or
## stat; `who`: whose modifiers (the companion's own by default); `progress` for conditions that read
## the companion.
static func total(traits: Array[TraitData], kind: int, weapon_type: int = -1, school: int = -1, spell_tier: int = 0,
		level: int = 0, stat: String = "", who: int = TraitModifier.Who.SELF, progress: CompanionProgress = null) -> int:
	var q := query(kind)
	q.traits = traits
	q.weapon_type = weapon_type
	q.school = school
	q.spell_tier = spell_tier
	q.level = level
	q.stat = stat
	q.who = who
	q.progress = progress
	return sum(q)


## True if `traits` hold a modifier of `kind` (out of a battle, the companion's own).
static func has(traits: Array[TraitData], kind: int) -> bool:
	var q := query(kind)
	q.traits = traits
	return any(q)
