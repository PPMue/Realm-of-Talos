class_name Battle
extends RefCounted
## The battle rules. Plain script, no nodes or UI: the scene reads state and calls the command methods.
##
## One tick = one player action:
##   1. the player's action resolves
##   2. every living enemy's countdown drops by 1
##   3. enemies at 0 act, left to right, then pick their next action (and, for one that strikes a single
##      companion, its target: the aim is fixed then and shown; see pick_next_action)
##   4. companion recovery counters tick down (not the companion who just acted)
##   5. damage over time (poison, burning) strikes every unit that carries it
##   6. timed effects (Guard, buffs, defends, debuffs) lose a tick and expire
##
## Enemy actions can also heal enemies, buff every enemy, lower the other enemies' countdowns (an
## order, never below 1), add to companions' recovery, and aim single targets with the position weights
## mirrored. An enemy with a second phase switches action lists when its HP falls to a threshold, or
## when it is the last one standing. An enemy carrying a reflecting effect hurts whoever lands a weapon
## strike or combat art on it; a companion carrying one (from an art or a spell) hurts an enemy whose
## physical action lands on them. Spells and magic are never reflected.
##
## Attacking and using combat arts raise the actor's proficiency in the weapon type held
## (stored in their CompanionProgress, which outlives the battle). Each grade reached teaches
## a random art of that type from `art_pool` (see ArtLearning), but only when the battle is over
## (learn_after_battle): nothing learned can be used in the battle it was earned in.
##
## Casting a spell spends one of its uses (no stamina) and raises the caster's grade in its school,
## with its own per-battle cap. Each school grade reached teaches a random spell from `spell_pool`
## (see SpellLearning), also when the battle is over. Black spells strike enemies with MAG against RES and may delay an enemy's
## pending action (once per action); white spells heal, buff and cleanse companions and always succeed.
##
## Every companion earns contribution points (BattleConfig.POINTS_*): for attacks, arts and spells, for
## enemy blows they take, and for the killing blow on an enemy. Run shares a won battle's XP by them.

enum Outcome { ONGOING, VICTORY, DEFEAT }

var rng: RandomNumberGenerator
## All companions in line order, left to right. Gone companions stay in this list but leave line().
var roster: Array[CompanionUnit] = []
## Enemies, left to right.
var enemies: Array[EnemyUnit] = []
var tick: int = 0
var outcome: Outcome = Outcome.ONGOING
var log_lines: Array[String] = []
## What happened during the last command, in order, for the UI to play back.
## Each entry has a "type" plus fields; see the _emit calls. Cleared at the start of every tick.
var events: Array[Dictionary] = []
## Arts that can be learned on a grade-up (normally ArtLibrary.load_default().arts).
var art_pool: Array[CombatArtData] = []
## Spells that can be learned on a school grade-up (normally SpellLibrary.load_default().spells).
var spell_pool: Array[SpellData] = []
## Every grade reached this battle, in order. Weapons: {"actor", "magic": false, "weapon_type", "grade",
## "art", "equipped"}. Magic: {"actor", "magic": true, "school", "grade", "spell"}. "art" and "spell"
## stay null ("equipped" false) until the battle is over; learn_after_battle() then fills them in.
## "equipped" is true only if the art went into a free slot.
var grade_ups: Array[Dictionary] = []
## True once learn_after_battle() has taught this battle's grade-ups.
var learned: bool = false
## Every companion injured this battle, in the order they fell. Nothing in battle undoes an injury, so
## these are also the injured at the end (they go to the run's infirmary).
var injured_ever: Array[CompanionUnit] = []
## Contribution points earned this battle: CompanionUnit -> int (missing = 0). See points_of().
var points: Dictionary = {}
## Enemies each companion landed the killing blow on this battle: CompanionUnit -> int (missing = 0).
var kills: Dictionary = {}
## Lead by Example (a trait): Hit the next companion to act gains, and who earned it (instance id).
var next_ally_hit: int = 0
var _next_ally_from: int = 0
## True for an elite fight (set by Run.start_battle): accessories that count against a boss count
## against every enemy here (TraitModifier.big_fight).
var elite: bool = false


## `party` holds each companion's progress, in the same order as `companion_data`; it is read and
## updated in place, so pass the same objects to the next battle to carry progress over.
## Companions without one start fresh.
func _init(companion_data: Array[CompanionData], enemy_data: Array[EnemyData], p_rng: RandomNumberGenerator = null,
		party: Array[CompanionProgress] = [], p_art_pool: Array[CombatArtData] = [],
		p_spell_pool: Array[SpellData] = []) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	art_pool = p_art_pool
	spell_pool = p_spell_pool
	for i in companion_data.size():
		roster.append(CompanionUnit.new(companion_data[i], party[i] if i < party.size() else null))
	_link_traits()
	for d in enemy_data:
		var e := EnemyUnit.new(d)
		enemies.append(e)
		pick_next_action(e)
	_log("Battle start.")


# ---------------------------------------------------------------- queries

## The fielded companions, left to right, injured ones included (CompanionUnit.is_injured() tells
## them apart; see standing()).
func line() -> Array[CompanionUnit]:
	return roster.duplicate()


## The companions still standing (not injured), left to right. Only they act and are aimed at.
func standing() -> Array[CompanionUnit]:
	return active_companions()


## Companions who are not injured.
func active_companions() -> Array[CompanionUnit]:
	var out: Array[CompanionUnit] = []
	for c in roster:
		if c.is_active():
			out.append(c)
	return out


func living_enemies() -> Array[EnemyUnit]:
	var out: Array[EnemyUnit] = []
	for e in enemies:
		if e.is_alive():
			out.append(e)
	return out


func is_over() -> bool:
	return outcome != Outcome.ONGOING


## Contribution points `c` has earned this battle.
func points_of(c: CompanionUnit) -> int:
	return int(points.get(c, 0))


## Enemies `c` has landed the killing blow on this battle.
func kills_of(c: CompanionUnit) -> int:
	return int(kills.get(c, 0))


## True when only one companion is able to act at all; that companion ignores recovery.
func is_lone_companion(c: CompanionUnit) -> bool:
	var active := active_companions()
	return active.size() == 1 and active[0] == c


func can_act(c: CompanionUnit) -> bool:
	if is_over() or c == null or not c.is_active():
		return false
	return c.recovery <= 0 or is_lone_companion(c)


func ready_companions() -> Array[CompanionUnit]:
	var out: Array[CompanionUnit] = []
	for c in roster:
		if can_act(c):
			out.append(c)
	return out


## Wait is only offered when nobody can act.
func can_wait() -> bool:
	return not is_over() and ready_companions().is_empty()


func can_use_art(c: CompanionUnit, art: CombatArtData) -> bool:
	return can_act(c) and art_block_reason(c, art) == ""


## Why `c` cannot use `art` right now (equipment and stamina only), or "" if nothing stops it.
func art_block_reason(c: CompanionUnit, art: CombatArtData) -> String:
	if c == null or art == null:
		return "No art chosen."
	if not c.progress.is_equipped(art):
		return "%s does not have %s equipped." % [c.display_name, art.display_name]
	var w := c.weapon()
	if w == null or w.weapon_type != art.weapon_type:
		var kind := art.type_name().to_lower()
		return "%s is a %s art: it needs a %s in hand." % [art.display_name, kind, kind]
	var cost := art_cost(c, art)
	if c.stamina < cost:
		return "Not enough stamina: %s needs %d, %s has %d." % [art.display_name, cost, c.display_name, c.stamina]
	return ""


## Actions `c` sits out after `art`: its recovery plus what traits change (TraitModifier.Kind.RECOVERY),
## never below 0.
func art_recovery(c: CompanionUnit, art: CombatArtData) -> int:
	var q := c.trait_query(TraitModifier.Kind.RECOVERY)
	q.action = TraitModifier.Action.ART
	q.weapon_type = art.weapon_type
	q.recovery = art.recovery
	return maxi(0, art.recovery + TraitRules.sum(q))


## Actions `c` sits out after an attack, a spell, Guard or Focus (`action`: TraitModifier.Action, ANY for
## Guard and Focus): `base` plus what traits and accessories change (TraitModifier.Kind.RECOVERY; a
## Spur only where `base` is 2 or more), never below 0. An art's: art_recovery.
func action_recovery(c: CompanionUnit, base: int, action: int = TraitModifier.Action.ANY, school: int = -1) -> int:
	var q := c.trait_query(TraitModifier.Kind.RECOVERY)
	q.action = action
	q.school = school
	q.weapon_type = c.weapon().weapon_type if action == TraitModifier.Action.ATTACK and c.weapon() != null else -1
	q.recovery = base
	return maxi(0, base + TraitRules.sum(q))


## Stamina `art` costs `c`: its own cost plus what traits add (TraitModifier.Kind.ART_STAMINA), never
## below 0.
func art_cost(c: CompanionUnit, art: CombatArtData) -> int:
	if art == null:
		return 0
	var q := c.trait_query(TraitModifier.Kind.ART_STAMINA)
	q.action = TraitModifier.Action.ART
	q.weapon_type = art.weapon_type
	return maxi(0, art.stamina_cost + TraitRules.sum(q))


## Stamina one Focus restores (flat, BattleConfig.FOCUS_RESTORE), never past the companion's max.
func focus_amount(c: CompanionUnit) -> int:
	return mini(BattleConfig.FOCUS_RESTORE + _trait_sum(c, TraitModifier.Kind.FOCUS_RESTORE), c.max_stamina())


## The sum of `kind` for `c` in this battle (see TraitRules).
func _trait_sum(c: CompanionUnit, kind: int) -> int:
	return TraitRules.sum(c.trait_query(kind))


func _trait_any(c: CompanionUnit, kind: int) -> bool:
	return TraitRules.any(c.trait_query(kind))


## Forecast of one strike by a companion on an enemy: a plain attack, or with `art`'s bonuses.
## For an action that strikes twice (an art's strikes, a weapon's attack_strikes), this is each strike
## and `strikes` says how many. Damage = attack power (by weapon type, see CombatMath.attack_power) +
## Mt (the weapon's for this wielder, + the art's bonus) - DEF; a magic weapon uses MAG against RES.
## The weapon's crit bonus adds to the art's; of the weapon's and the art's DEF ignored, the larger
## counts. Effective (weapon or art against one of the target's traits): half as much again, once.
## Traits add their Hit, Crit and damage (see trait_strike).
func forecast(c: CompanionUnit, target: EnemyUnit, art: CombatArtData = null) -> AttackForecast:
	var w := c.weapon()
	var effective := is_effective(c, target, art)
	var power := CombatMath.attack_power(c, w)
	var might := c.weapon_might()
	var bonus := trait_strike(c, target, TraitModifier.Action.ATTACK if art == null else TraitModifier.Action.ART)
	var f: AttackForecast
	if art == null:
		f = CombatMath.forecast(c, might, w.hit + int(bonus.hit), w.crit_bonus + int(bonus.crit), target,
			mini(100, w.ignore_def_percent + int(bonus.pierce)), w.damage_type, effective, power, int(bonus.damage),
			int(bonus.damage_percent))
		f.strikes = maxi(1, w.attack_strikes)
	else:
		f = CombatMath.forecast(c, might + art.might_bonus, w.hit + art.hit_bonus + int(bonus.hit),
			art.crit_bonus + w.crit_bonus + int(bonus.crit), target,
			mini(100, maxi(art.ignore_def_percent, w.ignore_def_percent) + int(bonus.pierce)),
			w.damage_type, effective, power, int(bonus.damage), int(bonus.damage_percent))
		f.strikes = maxi(1, art.strikes)
	if bonus.sure:
		f.hit = 100
	f.reflect = reflect_amount(c, target, f.damage)
	f.reflect_crit = reflect_amount(c, target, f.crit_damage)
	return f


## Damage a weapon strike or art dealing `dealt` to `target` would deal back to `c` (0 if the target
## reflects nothing): the target's reflect share of it, at least 1, then `c`'s damage-taken multiplier.
## Works both ways: an enemy striking a companion who reflects is hurt the same way.
func reflect_amount(c: Combatant, target: Combatant, dealt: int) -> int:
	var percent := target.reflect_percent()
	if percent <= 0 or dealt <= 0:
		return 0
	var base := maxi(BattleConfig.MIN_DAMAGE, floori(dealt * percent / 100.0))
	return CombatMath.final_damage(base, false, c.damage_taken_mult())


## Whether `c`'s weapon (or `art`) is effective against one of the target's traits.
func is_effective(c: CompanionUnit, target: EnemyUnit, art: CombatArtData = null) -> bool:
	var w := c.weapon()
	if w != null and CombatMath.is_effective(w.effective_against, target.traits()):
		return true
	return art != null and CombatMath.is_effective(art.effective_against, target.traits())


## Forecast of one black spell striking an enemy: MAG + Mt - RES (half as much again if effective),
## the spell's Hit.
## Traits add their Hit, Crit and damage (see trait_strike).
func spell_forecast(c: CompanionUnit, spell: SpellData, target: EnemyUnit) -> AttackForecast:
	var effective := CombatMath.is_effective(spell.effective_against, target.traits())
	var bonus := trait_strike(c, target, TraitModifier.Action.SPELL, spell.school)
	var f := CombatMath.forecast(c, spell.might, spell.hit + int(bonus.hit), spell.crit_bonus + int(bonus.crit), target,
		spell.ignore_res_percent, CombatMath.DamageType.MAGIC, effective, -1, int(bonus.damage), int(bonus.damage_percent))
	if bonus.sure:
		f.hit = 100
	return f


## What `c`'s traits add to one strike on `target` (`action`: TraitModifier.Action; `school` for a
## spell): {"hit", "crit" (percentage points), "damage" (to each blow), "damage_percent", "sure"
## (cannot miss), "pierce" (DEF ignored, percent: a Pin)}. Includes what the companion in front of them
## gives the one behind (File Leader).
func trait_strike(c: CompanionUnit, target: EnemyUnit, action: int, school: int = -1) -> Dictionary:
	var q := c.trait_query(TraitModifier.Kind.HIT)
	q.target = target
	q.action = action
	q.weapon_type = c.weapon().weapon_type if action != TraitModifier.Action.SPELL and c.weapon() != null else -1
	q.school = school
	var out := {"hit": TraitRules.sum(q)}
	if next_ally_hit != 0 and c.get_instance_id() != _next_ally_from:
		out.hit = int(out.hit) + next_ally_hit
	q.kind = TraitModifier.Kind.CRIT
	out.crit = TraitRules.sum(q)
	q.kind = TraitModifier.Kind.DAMAGE
	out.damage = TraitRules.sum(q)
	q.kind = TraitModifier.Kind.DAMAGE_PERCENT
	out.damage_percent = TraitRules.sum(q)
	q.kind = TraitModifier.Kind.SURE_HIT
	out.sure = TraitRules.any(q)
	q.kind = TraitModifier.Kind.PIERCE_PERCENT
	out.pierce = TraitRules.sum(q)
	return out


## HP a white spell restores to each target: caster MAG + the spell's power + what the caster's traits
## add to their heals (TraitModifier.Kind.HEAL_GIVEN); 0 if it does not heal. heal_amount_on: for one
## target.
func heal_amount(c: CompanionUnit, spell: SpellData) -> int:
	if not spell.heals:
		return 0
	var q := c.trait_query(TraitModifier.Kind.HEAL_GIVEN)
	q.action = TraitModifier.Action.SPELL
	q.school = spell.school
	return maxi(0, c.stat(Stat.MAG) + spell.heal_power + TraitRules.sum(q))


## HP `spell` cast by `c` restores to `target`: heal_amount and what the target's traits change
## (TraitModifier.Kind.HEAL_RECEIVED), never below 0.
func heal_amount_on(c: CompanionUnit, spell: SpellData, target: CompanionUnit) -> int:
	if not spell.heals:
		return 0
	var q := target.trait_query(TraitModifier.Kind.HEAL_RECEIVED)
	q.school = spell.school
	return maxi(0, heal_amount(c, spell) + TraitRules.sum(q))


## HP `target` would have after `spell` heals it (capped at max HP); its HP now if injured or no heal.
func hp_after_heal(c: CompanionUnit, spell: SpellData, target: CompanionUnit) -> int:
	if target.is_injured() or not spell.heals:
		return target.hp
	return mini(target.max_hp(), target.hp + heal_amount_on(c, spell, target))


func can_cast(c: CompanionUnit, spell: SpellData) -> bool:
	return can_act(c) and spell_block_reason(c, spell) == ""


## Why `c` cannot cast `spell` right now (knowledge and uses only), or "" if nothing stops it.
func spell_block_reason(c: CompanionUnit, spell: SpellData) -> String:
	if c == null or spell == null:
		return "No spell chosen."
	if not c.progress.knows_spell(spell):
		return "%s does not know %s." % [c.display_name, spell.display_name]
	if c.progress.uses_left(spell) <= 0:
		return "No uses left. Rest on a free day restores every spell's uses."
	return ""


## The units `spell` would affect when aimed at `target` (ignored by spells that affect everyone).
## Empty if the target is not a valid one for this spell.
func spell_targets(spell: SpellData, target: Combatant = null) -> Array[Combatant]:
	var out: Array[Combatant] = []
	match spell.targeting:
		SpellData.Targeting.ONE_ENEMY:
			if target is EnemyUnit and _is_valid_target(target):
				out.append(target)
		SpellData.Targeting.ALL_ENEMIES:
			out.append_array(living_enemies())
		SpellData.Targeting.ONE_ALLY:
			if target is CompanionUnit and roster.has(target) and (target as CompanionUnit).is_active():
				out.append(target)
		SpellData.Targeting.ALL_ALLIES:
			out.append_array(active_companions())
	return out


## Why `spell` cannot be aimed at `target`, or "". An injured companion is out of the battle: white
## magic cannot reach them (a spell on every ally skips them).
func spell_target_block_reason(spell: SpellData, target: Combatant) -> String:
	if spell == null:
		return "No spell chosen."
	if spell.targeting == SpellData.Targeting.ONE_ALLY and target is CompanionUnit and (target as CompanionUnit).is_injured():
		return "%s is injured and out of this battle." % target.display_name
	if not spell.targets_all() and spell_targets(spell, target).is_empty():
		return "Not a target for %s." % spell.display_name
	return ""


## Single-target weights for line(), left to right. `reversed`: the position weights mirrored, so the
## leftmost companion has the largest (veils and beacons apply the same way). Used when an aim is
## drawn (pick_next_action); once drawn, an aim moves only as pick_next_action says. An injured
## companion's weight is 0: enemies never aim at them, so the others share it all. Places are counted
## along the whole line, injured ones included.
func target_weights(reversed: bool = false) -> Array[float]:
	var out: Array[float] = []
	var l := line()
	for i in l.size():
		var place := l.size() - 1 - i if reversed else i
		var w := BattleConfig.TARGET_WEIGHT_BASE * pow(BattleConfig.TARGET_WEIGHT_GROWTH, place)
		w *= l[i].target_weight_mult()
		if l[i].is_injured():
			w = 0.0
		out.append(w)
	return out


# ---------------------------------------------------------------- commands
# Each returns false (and changes nothing) if the command is not allowed right now.

func attack(c: CompanionUnit, target: EnemyUnit) -> bool:
	if not can_act(c) or not _is_valid_target(target):
		return false
	_begin_tick()
	_log("%s attacks %s with %s." % [c.display_name, target.display_name, c.weapon().display_name])
	_emit({"type": "strike", "actor": c, "target": target, "name": "Attack", "art": null})
	var landed := false
	for i in maxi(1, c.weapon().attack_strikes):
		if not target.is_alive() or not c.is_active():
			break
		if _companion_strike(c, target, null):
			landed = true
	c.last_struck_id = target.get_instance_id()
	_add_points(c, BattleConfig.POINTS_ATTACK_HIT if landed else BattleConfig.POINTS_ATTACK_MISS)
	_gain_proficiency(c, BattleConfig.PROFICIENCY_POINTS_ATTACK)
	_end_player_action(c, action_recovery(c, BattleConfig.RECOVERY_ATTACK, TraitModifier.Action.ATTACK))
	return true


## Uses an equipped combat art. `target` is ignored by arts that strike every enemy.
func use_art(c: CompanionUnit, art: CombatArtData, target: EnemyUnit = null) -> bool:
	if not can_use_art(c, art):
		return false
	var targets: Array[EnemyUnit] = []
	if art.hits_all_enemies:
		targets = living_enemies()
	elif _is_valid_target(target):
		targets.append(target)
	if targets.is_empty():
		return false
	_begin_tick()
	var cost := art_cost(c, art)
	c.stamina -= cost
	var aim := "every enemy" if art.hits_all_enemies else target.display_name
	_log("%s uses %s on %s (-%d STA)." % [c.display_name, art.display_name, aim, cost])
	_emit({"type": "strike", "actor": c, "target": null if art.hits_all_enemies else target, "name": art.display_name, "art": art})
	for t in targets:
		var landed := false
		for i in art.strikes:
			if not t.is_alive() or not c.is_active():
				break
			if _companion_strike(c, t, art):
				landed = true
		if landed and art.target_effect != null and t.is_alive():
			_apply_effect(t, art.target_effect, false, c)
		c.last_struck_id = t.get_instance_id()
	if art.self_effect != null:
		_apply_effect(c, art.self_effect, true, c)
	_add_points(c, BattleConfig.POINTS_ART)
	_gain_proficiency(c, BattleConfig.PROFICIENCY_POINTS_ART)
	var rec := art_recovery(c, art)
	c.arts_used += 1
	_end_player_action(c, rec)
	return true


## Casts a known spell with uses left. `target` is an enemy for ONE_ENEMY, a companion still standing
## (not injured; see spell_target_block_reason) for ONE_ALLY, and ignored by spells that affect everyone.
func cast(c: CompanionUnit, spell: SpellData, target: Combatant = null) -> bool:
	if not can_cast(c, spell):
		return false
	var targets := spell_targets(spell, target)
	if targets.is_empty():
		return false
	_begin_tick()
	c.progress.spend_use(spell)
	var aim := ""
	match spell.targeting:
		SpellData.Targeting.ALL_ENEMIES:
			aim = "every enemy"
		SpellData.Targeting.ALL_ALLIES:
			aim = "every ally"
		_:
			aim = "themself" if targets[0] == c else targets[0].display_name
	_log("%s casts %s on %s (%d/%d uses left)." % [c.display_name, spell.display_name, aim,
		c.progress.uses_left(spell), c.progress.max_uses(spell)])
	_emit({"type": "cast", "actor": c, "spell": spell, "name": spell.display_name,
		"target": null if spell.targets_all() else targets[0]})
	for t in targets:
		if spell.deals_damage():
			_spell_strike(c, spell, t as EnemyUnit)
			c.last_struck_id = t.get_instance_id()
		else:
			_white_magic(c, spell, t as CompanionUnit)
	_add_points(c, BattleConfig.POINTS_SPELL)
	_gain_magic(c, spell.school)
	_end_player_action(c, action_recovery(c, spell.recovery, TraitModifier.Action.SPELL, spell.school))
	return true


func guard(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	c.add_effect(StatusEffect.guard())
	_log("%s guards." % c.display_name)
	_emit({"type": "guard", "actor": c})
	_end_player_action(c, action_recovery(c, BattleConfig.RECOVERY_GUARD), true)
	return true


func focus(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	var before := c.stamina
	c.stamina = mini(c.max_stamina(), c.stamina + focus_amount(c))
	_log("%s focuses (+%d STA, %d/%d)." % [c.display_name, c.stamina - before, c.stamina, c.max_stamina()])
	_emit({"type": "focus", "actor": c, "amount": c.stamina - before})
	_end_player_action(c, action_recovery(c, BattleConfig.RECOVERY_FOCUS), true)
	return true


func wait() -> bool:
	if not can_wait():
		return false
	_begin_tick()
	_log("The party waits.")
	_emit({"type": "wait"})
	_advance(null)
	return true


## Heals a companion still standing. An injured companion cannot be healed: nothing in battle undoes
## an injury.
func heal(c: CompanionUnit, amount: int) -> void:
	if c.is_injured() or amount <= 0:
		return
	var before := c.hp
	c.hp = mini(c.max_hp(), c.hp + amount)
	_log("  %s recovers %d HP (%d/%d HP)." % [c.display_name, c.hp - before, c.hp, c.max_hp()])
	_emit({"type": "heal", "target": c, "amount": c.hp - before, "hp": c.hp})


# ---------------------------------------------------------------- enemy side (public for tests)

## Picks the enemy's next action from its current list by pick weight. An action marked no_repeat is
## never picked right after itself while another action could be.
##
## A single-target action draws its target now, with target_weights as they stand (mirrored for one that
## aims from the left), and keeps it (EnemyUnit.pending_target; null for any other targeting). A delay or
## an order keeps it; a new phase picks a new action and so draws again. Once drawn, an aim moves only:
## - when its target is injured: drawn again at once among those standing (_injure; "injured");
## - when an effect that draws the eye (StatusEffect.target_weight_mult above 1: Beacon, Challenge,
##   Phalanx) lands on a companion: every pending single aim moves to them ("drawn");
## - when an effect that hides (below 1: Veil, Fade) lands on a companion: aims at them are drawn again
##   among the other standing companions, and stay if nobody else stands ("hidden").
## Each move is an "aim" event: {"enemy", "target" (the new), "from" (the old), "why"}.
func pick_next_action(e: EnemyUnit) -> void:
	var actions := e.actions()
	if actions.is_empty():
		e.pending_action = null
		e.pending_target = null
		e.countdown = 0
		return
	var weights: Array[float] = []
	var any_other := false
	for a in actions:
		var blocked := a.no_repeat and a == e.last_action
		weights.append(0.0 if blocked else maxf(0.0, a.pick_weight))
		any_other = any_other or (not blocked and a.pick_weight > 0.0)
	if not any_other:
		weights.clear()
		for a in actions:
			weights.append(maxf(0.0, a.pick_weight))
	var action := actions[_weighted_index(weights)]
	e.pending_action = action
	e.countdown = maxi(BattleConfig.MIN_ACTION_COUNTDOWN, action.countdown)
	e.delayed = false
	e.hastened = false
	e.pending_target = _draw_aim(e, action)
	_emit({"type": "intent", "enemy": e, "target": e.pending_target})


## A target for `e`'s single-target `action`, drawn with target_weights (mirrored as the action aims);
## `without` left out (null if nobody else stands). Null for any other targeting, or nobody standing.
func _draw_aim(e: EnemyUnit, action: EnemyActionData, without: CompanionUnit = null) -> CompanionUnit:
	if action == null or action.targeting != EnemyActionData.Targeting.SINGLE:
		return null
	var weights := target_weights(e.aims_reversed(action))
	var l := line()
	var total := 0.0
	for i in l.size():
		if l[i] == without:
			weights[i] = 0.0
		total += weights[i]
	if total <= 0.0:
		return null
	return l[_weighted_index(weights)]


## Enemies whose pending action is a single blow (any single-target action) aimed at `c`.
func _aimed_at(c: CompanionUnit) -> Array[EnemyUnit]:
	var out: Array[EnemyUnit] = []
	for e in living_enemies():
		if e.pending_target == c and e.pending_action != null \
				and e.pending_action.targeting == EnemyActionData.Targeting.SINGLE:
			out.append(e)
	return out


## Moves `e`'s aim to `target` (from wherever it was), with its event and log line.
func _move_aim(e: EnemyUnit, target: CompanionUnit, why: String) -> void:
	var from := e.pending_target
	if target == null or target == from:
		return
	e.pending_target = target
	_log("  %s's %s turns on %s." % [e.display_name, e.pending_action.display_name, target.display_name])
	_emit({"type": "aim", "enemy": e, "target": target, "from": from, "why": why})


## An effect with an aim multiplier has just landed on `c`: above 1 every pending single aim moves to
## them; below 1 those aimed at them are drawn again among the others (see pick_next_action).
func _aim_after_effect(c: CompanionUnit, mult: float) -> void:
	if mult > 1.0:
		for e in living_enemies():
			if e.pending_action != null and e.pending_action.targeting == EnemyActionData.Targeting.SINGLE:
				_move_aim(e, c, "drawn")
	elif mult < 1.0:
		for e in _aimed_at(c):
			_move_aim(e, _draw_aim(e, e.pending_action, c), "hidden")


func perform_enemy_action(e: EnemyUnit, action: EnemyActionData) -> void:
	if action == null:
		return
	_log("%s uses %s." % [e.display_name, action.display_name])
	_emit({"type": "enemy_action", "enemy": e, "action": action})
	e.last_action = action
	match action.targeting:
		EnemyActionData.Targeting.SELF:
			_enemy_support(e, action)
		EnemyActionData.Targeting.ALL_ALLIES:
			for ally in living_enemies():
				_enemy_support(ally, action)
		EnemyActionData.Targeting.SINGLE:
			var target := e.pending_target if action == e.pending_action else null
			if target == null or not target.is_active() or not roster.has(target):
				target = pick_target(e.aims_reversed(action))   # no aim kept: drawn as it lands
			if target != null:
				_enemy_strike(e, action, target)
		EnemyActionData.Targeting.ALL_COMPANIONS:
			for target in active_companions():
				if not e.is_alive():
					break   # struck down by a reflecting stance partway through
				_enemy_strike(e, action, target, true)
	if action.hasten_allies > 0 and e.is_alive():
		_hasten_others(e, action.hasten_allies)


## Weighted random single target among those standing; null if nobody is. `reversed`: mirrored weights.
func pick_target(reversed: bool = false) -> CompanionUnit:
	var l := line()
	if active_companions().is_empty():
		return null
	return l[_weighted_index(target_weights(reversed))]


## An order: every other living enemy's countdown drops by `ticks`, never below 1. An enemy already at
## 1 or 0 (0: about to act this tick) is left alone.
func _hasten_others(actor: EnemyUnit, ticks: int) -> void:
	for other in living_enemies():
		if other == actor or other.pending_action == null or other.countdown <= BattleConfig.MIN_ACTION_COUNTDOWN:
			continue
		var before := other.countdown
		other.countdown = maxi(BattleConfig.MIN_ACTION_COUNTDOWN, other.countdown - ticks)
		other.hastened = true
		_log("  %s's %s comes sooner: %d -> %d." % [other.display_name, other.pending_action.display_name, before, other.countdown])
		_emit({"type": "hasten", "target": other, "ticks": before - other.countdown, "countdown": other.countdown})


## A SELF or ALL_ALLIES action on one enemy: its heal, then its effect.
func _enemy_support(e: EnemyUnit, action: EnemyActionData) -> void:
	if not e.is_alive():
		return
	if action.heal_percent > 0:
		heal_enemy(e, ceili(e.max_hp() * action.heal_percent / 100.0))
	if action.effect != null:
		_apply_effect(e, action.effect, true)


## Restores an enemy's HP, up to its max.
func heal_enemy(e: EnemyUnit, amount: int) -> void:
	if not e.is_alive() or amount <= 0:
		return
	var before := e.hp
	e.hp = mini(e.max_hp(), e.hp + amount)
	_log("  %s recovers %d HP (%d/%d HP)." % [e.display_name, e.hp - before, e.hp, e.max_hp()])
	_emit({"type": "enemy_heal", "target": e, "amount": e.hp - before, "hp": e.hp})


## Recovery pressure: `c` sits out `ticks` more actions. Injured companions are left alone,
## and a lone companion still ignores recovery (see can_act).
func add_recovery(c: CompanionUnit, ticks: int) -> void:
	if not c.is_active() or ticks <= 0:
		return
	c.recovery += ticks
	_log("  %s's recovery grows by %d (%d)." % [c.display_name, ticks, c.recovery])
	_emit({"type": "recovery", "target": c, "ticks": ticks, "recovery": c.recovery})


# ---------------------------------------------------------------- internals

func _is_valid_target(target: EnemyUnit) -> bool:
	return target != null and target.is_alive() and enemies.has(target)


func _begin_tick() -> void:
	for c in roster:
		c.felled_this_action = false
	tick += 1
	events.clear()
	_log("== Turn %d ==" % tick)


## `steady`: the action was Guard or Focus (for traits that wait for one).
func _end_player_action(c: CompanionUnit, recovery: int, steady: bool = false) -> void:
	if c.felled_this_action and _trait_any(c, TraitModifier.Kind.KILL_NO_RECOVERY):
		recovery = 0
		_log("  %s presses on: no recovery." % c.display_name)
	c.recovery = recovery
	var breath := _trait_sum(c, TraitModifier.Kind.ACTION_STAMINA)
	if breath != 0 and c.is_active():
		c.stamina = clampi(c.stamina + breath, 0, c.max_stamina())
	if next_ally_hit != 0 and c.get_instance_id() != _next_ally_from:
		next_ally_hit = 0
		_next_ally_from = 0
	if roster.find(c) == roster.size() - 1:
		c.front_actions += 1
	c.actions_taken += 1
	c.after_guard_or_focus = steady
	c.struck_since.clear()
	_advance(c)


## Gives every companion its battle for trait conditions, and notes who can have a stat changed by a
## trait during the battle (a place in the line, say), so the others skip the lookup.
func _link_traits() -> void:
	var others := false
	for c in roster:
		c._battle = weakref(self)
		for t in c.all_traits():
			for m in t.modifiers:
				if m.kind == TraitModifier.Kind.STAT and m.who != TraitModifier.Who.SELF:
					others = true
	for c in roster:
		var own := false
		for t in c.all_traits():
			for m in t.modifiers:
				if m.kind == TraitModifier.Kind.STAT and m.who == TraitModifier.Who.SELF and m.is_battle_only():
					own = true
		c._battle_stats = own or others


func _advance(acted: CompanionUnit) -> void:
	if _check_end():
		return
	var countdowns := {}
	for e in living_enemies():
		e.countdown -= 1
		countdowns[e] = e.countdown
	_emit({"type": "countdown", "countdowns": countdowns})
	for e in enemies:
		if e.is_alive() and e.countdown <= 0:
			perform_enemy_action(e, e.pending_action)
			if e.is_alive():   # a reflecting stance can fell the enemy during its own action
				pick_next_action(e)
			if _check_end():
				return
	for c in line():
		if c != acted and c.recovery > 0:
			c.recovery -= 1
	for unit: Combatant in roster + enemies:
		_damage_over_time(unit)
	if _check_end():
		return
	for unit: Combatant in roster + enemies:
		for expired in unit.tick_effects():
			if expired.display_name != "Guard":
				_log("%s's %s wears off." % [unit.display_name, expired.display_name])
	_check_end()


## One strike. Returns true if it landed.
func _companion_strike(c: CompanionUnit, target: EnemyUnit, art: CombatArtData) -> bool:
	var f := forecast(c, target, art)
	if not _roll(f.hit):
		_log("  Miss on %s! (%d%% to hit)" % [target.display_name, f.hit])
		_emit({"type": "miss", "target": target})
		return false
	var crit := _roll(f.crit)
	var dmg := f.crit_damage if crit else f.damage
	target.hp -= dmg
	_log("  %s%s takes %d %sdamage%s (%d/%d HP)." % ["CRITICAL! " if crit else "", target.display_name, dmg,
		"magic " if f.magic else "", ", effective" if f.effective else "", maxi(target.hp, 0), target.max_hp()])
	_emit({"type": "damage", "target": target, "amount": dmg, "crit": crit, "hp": target.hp,
		"effective": f.effective, "magic": f.magic})
	var back := reflect_amount(c, target, dmg)
	_after_enemy_hurt(target, c)
	if crit:
		_on_crit(c, target)
	_on_first_hit(c, target)
	var w := c.weapon()
	if w.lifesteal_percent > 0 and c.is_active():
		var drained := floori(dmg * w.lifesteal_percent / 100.0)
		if drained > 0 and c.hp < c.max_hp():
			_log("  %s drinks %d HP through %s." % [c.display_name, mini(drained, c.max_hp() - c.hp), w.display_name])
			heal(c, drained)
	if w.on_hit_effect != null and target.is_alive():
		_apply_effect(target, w.on_hit_effect, false, c)
	if back > 0 and c.is_active():
		_log("  %s's %s strikes back at %s!" % [target.display_name, _reflect_name(target), c.display_name])
		_emit({"type": "reflect", "source": target, "target": c, "amount": back})
		_damage_companion(c, back, false)
	return true


func _reflect_name(unit: Combatant) -> String:
	for fx in unit.effects:
		if fx.reflect_percent > 0:
			return fx.display_name
	return "reflection"


## After an enemy lost HP: its defeat, or the start of its second phase. A defeat that leaves a
## LAST_STANDING enemy alone starts that enemy's phase. `by`: the companion credited with the blow,
## who earns the kill bonus if it was the last one.
func _after_enemy_hurt(e: EnemyUnit, by: CompanionUnit = null) -> void:
	if not e.is_alive():
		_log("  %s is defeated!" % e.display_name)
		_emit({"type": "defeated", "target": e, "by": by})
		if by != null:
			kills[by] = kills_of(by) + 1
			_add_points(by, BattleConfig.POINTS_KILL)
			_on_kill(by)
		var left := living_enemies()
		if left.size() == 1 and left[0].phase == 0 and left[0].data.has_phase() \
				and left[0].data.phase_trigger == EnemyData.PhaseTrigger.LAST_STANDING:
			_enter_phase(left[0])
		return
	if e.phase == 0 and e.data.has_phase() and e.data.phase_trigger == EnemyData.PhaseTrigger.HP_BELOW \
			and e.hp * 100 <= e.max_hp() * e.data.phase_hp_percent:
		_enter_phase(e)


## What `c`'s traits do when they fell an enemy: more contribution points for it, stamina, HP, no
## recovery for the action, and the next ally's Hit (TraitModifier.Kind.KILL_*).
func _on_kill(c: CompanionUnit) -> void:
	var extra := _trait_sum(c, TraitModifier.Kind.KILL_POINTS_PERCENT)
	if extra != 0:
		_add_points(c, BattleConfig.POINTS_KILL * extra / 100)
	if not c.is_active():
		return
	var sta := _trait_sum(c, TraitModifier.Kind.KILL_STAMINA)
	if sta > 0 and c.stamina < c.max_stamina():
		c.stamina = mini(c.max_stamina(), c.stamina + sta)
		_log("  %s's blood is up: +%d STA." % [c.display_name, sta])
	var hp := _trait_sum(c, TraitModifier.Kind.KILL_HP)
	if hp > 0:
		heal(c, hp)
	c.felled_this_action = true
	var lead := _trait_sum(c, TraitModifier.Kind.KILL_NEXT_ALLY_HIT)
	if lead > 0:
		next_ally_hit = lead
		_next_ally_from = c.get_instance_id()


## A critical hit by `c` on `target`: traits that push the target's next action back
## (TraitModifier.Kind.CRIT_DELAY), once per pending action as spells do.
func _on_crit(c: CompanionUnit, target: EnemyUnit) -> void:
	var push := _trait_sum(c, TraitModifier.Kind.CRIT_DELAY)
	if push > 0 and target.is_alive():
		delay_action(target, push)


## The first of `c`'s strikes or spells to hit this battle: what pushes the target's next action back
## then (TraitModifier.Kind.FIRST_HIT_DELAY: an Hourglass), shown as a spell's delay is.
func _on_first_hit(c: CompanionUnit, target: EnemyUnit) -> void:
	if c.first_hit_done:
		return
	c.first_hit_done = true
	var push := _trait_sum(c, TraitModifier.Kind.FIRST_HIT_DELAY)
	if push > 0 and target.is_alive():
		delay_action(target, push)


## Switches an enemy to its second action list, announced, and replaces its pending action.
func _enter_phase(e: EnemyUnit) -> void:
	e.phase = 1
	var title := e.data.phase_title if e.data.phase_title != "" else "%s changes" % e.display_name
	_log("%s: %s!" % [e.display_name, title])
	_emit({"type": "phase", "enemy": e, "title": title, "text": e.data.phase_text})
	if e.data.phase_effect != null:
		_apply_effect(e, e.data.phase_effect, true)
	pick_next_action(e)


## Poison, burning and the like: every effect's damage per tick, added up, less what a Talisman takes off
## (TraitModifier.Kind.DOT_TAKEN_PERCENT, rounded down). A companion can be injured by it (and then
## loses every effect); one already injured takes none. An enemy it kills is
## credited to the companion who applied the first of those effects (if a companion did).
func _damage_over_time(unit: Combatant) -> void:
	var total := 0
	var names: Array[String] = []
	var by: CompanionUnit = null
	for fx in unit.effects:
		if fx.damage_per_tick > 0:
			total += fx.damage_per_tick
			names.append(fx.display_name)
			if by == null and fx.source is CompanionUnit:
				by = fx.source as CompanionUnit
	if total <= 0:
		return
	if unit is CompanionUnit:
		var c := unit as CompanionUnit
		if not c.is_active():
			return
		var cut := _trait_sum(c, TraitModifier.Kind.DOT_TAKEN_PERCENT)
		if cut != 0:
			total = maxi(0, floori(total * (100 + maxi(-100, cut)) / 100.0))
		if total <= 0 or _trait_any(c, TraitModifier.Kind.DOT_IMMUNE):
			_log("  %s shrugs off %s." % [c.display_name, ", ".join(names)])
			return
		c.hp -= total
		_log("  %s loses %d HP to %s (%d/%d HP)." % [c.display_name, total, ", ".join(names), c.hp, c.max_hp()])
		_emit({"type": "dot", "target": c, "amount": total, "hp": c.hp, "name": names[0]})
		if c.hp <= 0:
			_injure(c)
		else:
			_after_companion_hurt(c)
	elif unit is EnemyUnit:
		var e := unit as EnemyUnit
		if not e.is_alive():
			return
		e.hp -= total
		_log("  %s loses %d HP to %s (%d/%d HP)." % [e.display_name, total, ", ".join(names), maxi(e.hp, 0), e.max_hp()])
		_emit({"type": "dot", "target": e, "amount": total, "hp": e.hp, "name": names[0]})
		_after_enemy_hurt(e, by)


## A black spell striking one enemy: hit roll, damage, then a countdown delay and a debuff if it landed.
func _spell_strike(c: CompanionUnit, spell: SpellData, target: EnemyUnit) -> void:
	if not target.is_alive():
		return
	var f := spell_forecast(c, spell, target)
	if not _roll(f.hit):
		_log("  Miss on %s! (%d%% to hit)" % [target.display_name, f.hit])
		_emit({"type": "miss", "target": target})
		return
	var crit := _roll(f.crit)
	var dmg := f.crit_damage if crit else f.damage
	target.hp -= dmg
	_log("  %s%s takes %d magic damage%s (%d/%d HP)." % ["CRITICAL! " if crit else "", target.display_name, dmg,
		", effective" if f.effective else "", maxi(target.hp, 0), target.max_hp()])
	_emit({"type": "damage", "target": target, "amount": dmg, "crit": crit, "hp": target.hp,
		"effective": f.effective, "magic": true})
	_after_enemy_hurt(target, c)
	if crit:
		_on_crit(c, target)
	_on_first_hit(c, target)
	if not target.is_alive():
		return
	if spell.delay_ticks > 0:
		delay_action(target, spell.delay_ticks)
	if spell.effect != null:
		_apply_effect(target, spell.effect, false, c)


## Adds `ticks` to an enemy's pending action, unless that action was already delayed. Returns true if
## it was delayed. Only spells call this; combat arts never touch countdowns.
func delay_action(target: EnemyUnit, ticks: int) -> bool:
	if not target.is_alive() or target.pending_action == null or ticks <= 0:
		return false
	if target.delayed:
		_log("  %s's %s has already been delayed once." % [target.display_name, target.pending_action.display_name])
		_emit({"type": "delay_blocked", "target": target})
		return false
	target.countdown += ticks
	target.delayed = true
	_log("  %s's %s is delayed by %d (now %d)." % [target.display_name, target.pending_action.display_name, ticks, target.countdown])
	_emit({"type": "delay", "target": target, "ticks": ticks, "countdown": target.countdown})
	return true


## A white spell on one companion still standing: heal, then remove debuffs, then the buff.
func _white_magic(c: CompanionUnit, spell: SpellData, target: CompanionUnit) -> void:
	if target.is_injured():
		return
	if spell.heals:
		heal(target, heal_amount_on(c, spell, target))
	if spell.cleanse:
		var removed: Array[String] = []
		for e in target.effects.duplicate():
			if e.is_harmful():
				target.effects.erase(e)
				removed.append(e.display_name)
		if removed.is_empty():
			_log("  %s has no debuffs to remove." % target.display_name)
		else:
			_log("  %s is cleansed of %s." % [target.display_name, ", ".join(removed)])
		_emit({"type": "cleanse", "target": target, "removed": removed})
	if spell.effect != null:
		_apply_effect(target, spell.effect, true, c)
		var q := c.trait_query(TraitModifier.Kind.BLESSING_TURNS)
		q.action = TraitModifier.Action.SPELL
		q.school = spell.school
		var longer := TraitRules.sum(q)
		var fx := target.get_effect(spell.effect.display_name)
		if longer != 0 and fx != null and target.is_active():
			fx.ticks_left = maxi(1, fx.ticks_left + longer)


## Proficiency for acting with the weapon held, up to the per-battle cap.
## Every grade reached teaches a random art of that weapon type (if any is left to learn).
func _gain_proficiency(c: CompanionUnit, amount: int) -> void:
	var w := c.weapon()
	if w == null or amount <= 0:
		return
	var t := w.weapon_type
	var percent := _points_percent(c, t, -1)
	var cap := proficiency_cap(c, t)
	var scaled := amount * (100 + percent) / 100.0 + c.point_carry
	var whole := floori(scaled)
	c.point_carry = scaled - whole
	var room := maxi(0, cap - c.proficiency_gained)
	var before := c.progress.grade(t)
	var gained := c.progress.add_points(t, mini(whole, room))
	c.proficiency_gained += gained
	if gained <= 0:
		return
	var kind := WeaponData.type_name(t).to_lower()
	_emit({"type": "proficiency", "actor": c, "weapon_type": t, "gained": gained})
	if c.proficiency_gained >= cap:
		_log("  %s has gained all the %s proficiency this battle can give." % [c.display_name, kind])
	for g in range(before + 1, c.progress.grade(t) + 1):
		_log("  %s's %s grade rises to %s!" % [c.display_name, kind, Proficiency.grade_name(g)])
		var ev := {"type": "grade_up", "actor": c, "magic": false, "weapon_type": t, "grade": g, "art": null, "equipped": false}
		grade_ups.append(ev)
		_emit(ev)


## Magic points for casting, up to the per-battle magic cap (separate from the weapon cap).
## Every school grade reached teaches a random spell of that school (if any is left to learn).
func _gain_magic(c: CompanionUnit, s: SpellData.School) -> void:
	var percent := _points_percent(c, -1, s)
	var cap := magic_cap(c, s)
	var room := maxi(0, cap - c.magic_gained)
	var before := c.progress.magic_grade(s)
	var per_cast := BattleConfig.MAGIC_POINTS_PER_CAST * (100 + percent) / 100
	var gained := c.progress.add_magic_points(s, mini(per_cast, room))
	c.magic_gained += gained
	if gained <= 0:
		return
	var school := SpellData.school_name(s)
	_emit({"type": "proficiency", "actor": c, "magic": true, "school": s, "gained": gained})
	if c.magic_gained >= cap:
		_log("  %s has gained all the magic proficiency this battle can give." % c.display_name)
	for g in range(before + 1, c.progress.magic_grade(s) + 1):
		_log("  %s's %s grade rises to %s!" % [c.display_name, school, Proficiency.grade_name(g)])
		var ev := {"type": "grade_up", "actor": c, "magic": true, "school": s, "grade": g, "spell": null}
		grade_ups.append(ev)
		_emit(ev)


## The most weapon points `c` can gain in one battle in type `t`: BattleConfig.PROFICIENCY_CAP_PER_BATTLE,
## raised by the same share as traits raise the points (TraitModifier.Kind.PROFICIENCY_PERCENT).
func proficiency_cap(c: CompanionUnit, t: int) -> int:
	return BattleConfig.PROFICIENCY_CAP_PER_BATTLE * (100 + _points_percent(c, t, -1)) / 100


## The same for magic points in school `s` (BattleConfig.MAGIC_CAP_PER_BATTLE).
func magic_cap(c: CompanionUnit, s: int) -> int:
	return BattleConfig.MAGIC_CAP_PER_BATTLE * (100 + _points_percent(c, -1, s)) / 100


## What traits add to `c`'s points (percent) in weapon type `t` or school `s`: their own (Apt, Second
## Trade) and their neighbours' (Envied).
func _points_percent(c: CompanionUnit, t: int, s: int) -> int:
	var q := c.trait_query(TraitModifier.Kind.PROFICIENCY_PERCENT)
	q.weapon_type = t
	q.school = s
	return TraitRules.sum(q)


## Once the battle is over: every grade reached this battle (won or lost, injured or not) teaches its
## art or spell, in the order the grades were reached, with
## the same picking rules and generator. Fills "art" and "equipped" (true only if a slot was free) or
## "spell" into each grade_ups entry. Called by _check_end when the battle ends, so callers need not;
## calling it again (or before the end) does nothing.
func learn_after_battle() -> void:
	if learned or not is_over():
		return
	learned = true
	for ev in grade_ups:
		var c: CompanionUnit = ev.actor
		var g: int = ev.grade
		if ev.magic:
			var school := SpellData.school_name(ev.school)
			var spell := SpellLearning.pick_spell(rng, c.progress, ev.school, g, spell_pool)
			if spell != null:
				c.progress.learn_spell(spell)
				_log("  %s learns %s (tier %d)." % [c.display_name, spell.display_name, spell.tier])
			else:
				_log("  %s already knows every %s spell." % [c.display_name, school])
			ev.spell = spell
			_emit({"type": "learned", "actor": c, "magic": true, "school": ev.school, "grade": g, "spell": spell})
		else:
			var kind := WeaponData.type_name(ev.weapon_type).to_lower()
			var art := ArtLearning.pick_art(rng, c.progress, ev.weapon_type, g, art_pool)
			var equipped := c.progress.learn(art) if art != null else false
			if art != null:
				_log("  %s learns %s (tier %d)%s." % [c.display_name, art.display_name, art.tier,
					", equipped" if equipped else "; no free slot, so it is not equipped"])
			else:
				_log("  %s already knows every %s art." % [c.display_name, kind])
			ev.art = art
			ev.equipped = equipped
			_emit({"type": "learned", "actor": c, "magic": false, "weapon_type": ev.weapon_type, "grade": g,
				"art": art, "equipped": equipped})


## Forecast of `e`'s `action` striking companion `target` (`whole_line`: the blow strikes everyone):
## the usual formulas, with the target's Avoid taken off the Hit and what traits change in the damage
## they take (TraitModifier.Kind.AVOID, DAMAGE_TAKEN, DAMAGE_TAKEN_PERCENT; Guard's share: see
## CompanionUnit.damage_taken_mult). The critical chance is the action's own (EnemyActionData.crit_percent,
## 0 for most), not worked out from CRT and LCK.
func enemy_forecast(e: EnemyUnit, action: EnemyActionData, target: CompanionUnit, whole_line: bool = false) -> AttackForecast:
	var q := target.trait_query(TraitModifier.Kind.AVOID)
	q.target = e
	q.whole_line = whole_line
	q.blow = TraitModifier.Blow.MAGIC if action.damage_type == CombatMath.DamageType.MAGIC else TraitModifier.Blow.PHYSICAL
	var avoid := TraitRules.sum(q)
	q.kind = TraitModifier.Kind.DAMAGE_TAKEN_PERCENT
	var taken_mult := TraitRules.percent_product(q)
	q.kind = TraitModifier.Kind.DAMAGE_TAKEN
	var taken_flat := TraitRules.sum(q)
	var f := CombatMath.forecast(e, action.might, action.hit - avoid, 0, target, 0, action.damage_type, false, -1, 0, 0,
		taken_mult, taken_flat)
	f.crit = clampi(action.crit_percent, 0, 100)
	return f


## Every living enemy's pending action that will reach `c`: a single action aimed at them
## (EnemyUnit.pending_target) or one on the whole line, in the order they land (fewest turns first, then
## enemy order). Each: {"enemy": EnemyUnit, "action": EnemyActionData, "turns": int (its countdown),
## "whole_line": bool, "forecast": AttackForecast} with the forecast as things stand now (enemy_forecast);
## an action that deals no damage has damage 0 (and Hit 100: it always lands). Empty for someone injured.
func incoming(c: CompanionUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or not c.is_active() or not roster.has(c):
		return out
	for e in living_enemies():
		var a := e.pending_action
		if a == null:
			continue
		var whole := a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS
		if not whole and not (a.targeting == EnemyActionData.Targeting.SINGLE and e.pending_target == c):
			continue
		var f: AttackForecast
		if a.deals_damage:
			f = enemy_forecast(e, a, c, whole)
		else:
			f = AttackForecast.new()
			f.hit = 100
			f.magic = a.damage_type == CombatMath.DamageType.MAGIC
		out.append({"enemy": e, "action": a, "turns": e.countdown, "whole_line": whole, "forecast": f})
	var order := enemies
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if int(x.turns) != int(y.turns):
			return int(x.turns) < int(y.turns)
		return order.find(x.enemy) < order.find(y.enemy))
	return out


## The first turn (1: the next) on which `c` would be at 0 Health if every blow in incoming(c) lands, none
## of them critical, with the damage over time already on them turn by turn while it lasts (less what a
## Talisman takes off), and survive_hp once if they still have it; 0 if they would be left standing.
## Within a turn the blows land first, then damage over time, as in _advance. Only the actions pending
## now are counted, not what the enemies will choose after them.
func falls_on_turn(c: CompanionUnit) -> int:
	if c == null or not c.is_active() or not roster.has(c):
		return 0
	var blows := incoming(c)
	var last := 0
	for b in blows:
		last = maxi(last, int(b.turns))
	var dots: Array[Vector2i] = []   # x: damage per turn, y: turns it lasts
	for fx in c.effects:
		if fx.damage_per_tick > 0:
			dots.append(Vector2i(fx.damage_per_tick, fx.ticks_left))
			last = maxi(last, fx.ticks_left)
	var cut := _trait_sum(c, TraitModifier.Kind.DOT_TAKEN_PERCENT)
	var dot_immune := _trait_any(c, TraitModifier.Kind.DOT_IMMUNE)
	var hp := c.hp
	var saved := c.survived_once
	var next := 0
	for turn in range(1, mini(last, StatusEffect.LASTING_TICKS * 2) + 1):
		while next < blows.size() and int(blows[next].turns) <= turn:
			var dmg := (blows[next].forecast as AttackForecast).damage
			next += 1
			if dmg >= hp and not saved:
				var stand := _survive_hp_at(c, hp)
				if stand > 0:
					saved = true
					hp = maxi(hp, stand)
					dmg = hp - stand
			hp -= dmg
			if hp <= 0:
				return turn
		var total := 0
		for d in dots:
			if d.y >= turn:
				total += d.x
		if cut != 0:
			total = maxi(0, floori(total * (100 + maxi(-100, cut)) / 100.0))
		if total > 0 and not dot_immune:
			hp -= total
			if hp <= 0:
				return turn
	return 0


func _enemy_strike(e: EnemyUnit, action: EnemyActionData, target: CompanionUnit, whole_line: bool = false) -> void:
	if target.is_injured():
		return   # out of the battle: never struck
	if action.deals_damage:
		var f := enemy_forecast(e, action, target, whole_line)
		if not _roll(f.hit):
			_log("  %s dodges. (%d%% to hit)" % [target.display_name, f.hit])
			_emit({"type": "miss", "target": target})
			return
		var crit := _roll(f.crit)
		var dmg := f.crit_damage if crit else f.damage
		# A companion's reflecting stance (Riposte, Set Spear) answers physical blows, even one that
		# fells them. Magic is never reflected. Worked out first: a companion who is injured loses effects.
		var back := reflect_amount(e, target, dmg) if action.damage_type == CombatMath.DamageType.PHYSICAL else 0
		var thorns := 0 if whole_line else _trait_sum(target, TraitModifier.Kind.THORNS)
		var stance := _reflect_name(target)
		var guarding := target.has_effect("Guard")
		target.last_hit_by_id = e.get_instance_id()
		if not target.struck_since.has(target.last_hit_by_id):
			target.struck_since.append(target.last_hit_by_id)
		target.blows_taken += 1
		_damage_companion(target, dmg, crit)
		_add_points(target, BattleConfig.POINTS_BLOW_TAKEN_GUARDING if guarding else BattleConfig.POINTS_BLOW_TAKEN)
		if back > 0 and e.is_alive():
			_reflect_on_enemy(target, stance, e, back)
		if thorns > 0 and e.is_alive():
			_thorns(target, e, thorns)
	if action.effect != null and target.is_active():
		_apply_effect(target, action.effect, false)
	if action.add_recovery > 0:
		add_recovery(target, action.add_recovery)


## A Thorn (TraitModifier.Kind.THORNS): the enemy whose blow landed on `c` takes `amount`, felled by
## it if that is all it had left (the kill is `c`'s). Not from blows on the whole line.
func _thorns(c: CompanionUnit, e: EnemyUnit, amount: int) -> void:
	_log("  %s is cut on %s's thorns!" % [e.display_name, c.display_name])
	e.hp -= amount
	_log("  %s takes %d damage (%d/%d HP)." % [e.display_name, amount, maxi(e.hp, 0), e.max_hp()])
	_emit({"type": "damage", "target": e, "amount": amount, "crit": false, "hp": e.hp,
		"effective": false, "magic": false, "thorns": true, "source": c})
	_after_enemy_hurt(e, c)


## A companion's reflecting stance (`stance`, its name) hurting the enemy that struck them for `amount`.
## The enemy can be defeated by it, and then the kill is `c`'s.
func _reflect_on_enemy(c: CompanionUnit, stance: String, e: EnemyUnit, amount: int) -> void:
	_log("  %s's %s strikes back at %s!" % [c.display_name, stance, e.display_name])
	_emit({"type": "riposte", "source": c, "target": e, "amount": amount})
	e.hp -= amount
	_log("  %s takes %d damage (%d/%d HP)." % [e.display_name, amount, maxi(e.hp, 0), e.max_hp()])
	_emit({"type": "damage", "target": e, "amount": amount, "crit": false, "hp": e.hp,
		"effective": false, "magic": false})
	_after_enemy_hurt(e, c)


## The Health a blow that would fell `c` leaves them at, or 0 if nothing saves them: the trait that
## survives at 1 (TraitModifier.Kind.SURVIVE_ONCE, only above 1 Health) and a Locket
## (TraitModifier.Kind.SURVIVE_SHARE: 1 at Topaz, else that percent of max Health rounded up); with both,
## the higher. Once a battle: either saving uses both up (CompanionUnit.survived_once).
func survive_hp(c: CompanionUnit) -> int:
	return _survive_hp_at(c, c.hp)


## survive_hp as it would be with `hp` Health (for falls_on_turn).
func _survive_hp_at(c: CompanionUnit, hp: int) -> int:
	var best := 0
	if hp > 1 and _trait_any(c, TraitModifier.Kind.SURVIVE_ONCE):
		best = 1
	var q := c.trait_query(TraitModifier.Kind.SURVIVE_SHARE)
	for m in TraitRules.matching(q):
		best = maxi(best, maxi(1, ceili(c.max_hp() * m.amount / 100.0)))
	return best


## A landed hit on a companion still standing. At 0 HP they are injured.
func _damage_companion(c: CompanionUnit, dmg: int, crit: bool) -> void:
	if c.is_injured():
		return
	if dmg >= c.hp and not c.survived_once:
		var stand := survive_hp(c)
		if stand > 0:
			c.survived_once = true
			if stand >= c.hp:
				c.hp = stand   # a Locket can leave them higher than they were
			dmg = c.hp - stand
			_log("  %s clings to life!" % c.display_name)
	c.hp -= dmg
	_log("  %s%s takes %d damage (%d/%d HP)." % ["CRITICAL! " if crit else "", c.display_name, dmg, c.hp, c.max_hp()])
	_emit({"type": "damage", "target": c, "amount": dmg, "crit": crit, "hp": c.hp})
	if c.hp <= 0:
		_injure(c)
	else:
		_after_companion_hurt(c)


## After `c` lost HP and is still standing: the first time below half Health in the battle, traits that
## wait for it (TraitModifier.Kind.HALF_HEALTH_STAMINA: stamina full).
func _after_companion_hurt(c: CompanionUnit) -> void:
	if c.half_health_done or c.hp * 2 >= c.max_hp():
		return
	c.half_health_done = true
	if _trait_any(c, TraitModifier.Kind.HALF_HEALTH_STAMINA) and c.stamina < c.max_stamina():
		c.stamina = c.max_stamina()
		_log("  %s finds a second wind: stamina full." % c.display_name)


## `c` drops to 0 HP: injured and out of this battle. They no longer act or are aimed at (every blow
## aimed at them is drawn again at once among those standing), every effect on them ends and nothing new
## lands on them; nothing in battle undoes it.
func _injure(c: CompanionUnit) -> void:
	c.hp = 0
	c.state = CompanionUnit.State.INJURED
	c.effects.clear()
	c.recovery = 0
	if not injured_ever.has(c):
		injured_ever.append(c)
	_log("  %s is injured and out of the battle!" % c.display_name)
	_emit({"type": "injured", "target": c})
	for e in _aimed_at(c):
		var to := _draw_aim(e, e.pending_action)
		if to == null:
			e.pending_target = null   # nobody left standing
		else:
			_move_aim(e, to, "injured")
	var mend := _trait_sum(c, TraitModifier.Kind.INJURED_HEAL_ALLIES)
	if mend > 0:
		for ally in active_companions():
			heal(ally, mend)


## `helpful`: a buff or defend (as opposed to a debuff); only changes how it is shown.
## `source`: the companion who applied it, if any. It is kept only on damage over time (which credits
## them with a kill), so a companion's own effects never hold a reference back to a companion.
func _apply_effect(unit: Combatant, data: StatusEffectData, helpful: bool, source: CompanionUnit = null) -> void:
	if unit is CompanionUnit and (unit as CompanionUnit).is_injured():
		return   # nothing new lands on someone out of the battle
	var effect := StatusEffect.from_data(data)
	if effect.damage_per_tick > 0 and unit != source:
		effect.source = source
	if unit is CompanionUnit and effect.is_harmful():
		var shorter := _trait_sum(unit as CompanionUnit, TraitModifier.Kind.CURSE_TURNS)
		if shorter != 0:
			effect.ticks_left = maxi(1, effect.ticks_left + shorter)
	unit.add_effect(effect)
	_log("  %s gains %s." % [unit.display_name, effect.describe()])
	_emit({"type": "effect", "target": unit, "name": effect.display_name, "helpful": helpful})
	if unit is CompanionUnit and effect.target_weight_mult != 1.0:
		_aim_after_effect(unit as CompanionUnit, effect.target_weight_mult)


func _add_points(c: CompanionUnit, amount: int) -> void:
	points[c] = points_of(c) + amount


## Returns true if the battle is over (and sets outcome on the first call that sees it).
func _check_end() -> bool:
	if is_over():
		return true
	if living_enemies().is_empty():
		outcome = Outcome.VICTORY
		_log("Victory!")
		learn_after_battle()
		return true
	if line().is_empty():
		outcome = Outcome.DEFEAT
		_log("Defeat: no companions left.")
		learn_after_battle()
		return true
	if active_companions().is_empty():
		outcome = Outcome.DEFEAT
		_log("Defeat: every remaining companion is injured.")
		learn_after_battle()
		return true
	return false


## Percent roll. Always draws one number so the RNG stream does not depend on the odds.
func _roll(percent: int) -> bool:
	return rng.randi_range(1, 100) <= percent


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0.0:
			return i
	return weights.size() - 1


func _log(text: String) -> void:
	log_lines.append(text)


func _emit(event: Dictionary) -> void:
	events.append(event)
