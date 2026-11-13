class_name Battle
extends RefCounted
## The battle rules. Plain script, no nodes or UI: the scene reads state and calls the command methods.
##
## One tick = one player action:
##   1. the player's action resolves
##   2. every living enemy's countdown drops by 1
##   3. enemies at 0 act, left to right, then pick their next action
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
## Every companion injured at some point this battle, in order (a record only; rules do not read it).
var injured_ever: Array[CompanionUnit] = []
## Contribution points earned this battle: CompanionUnit -> int (missing = 0). See points_of().
var points: Dictionary = {}
## Enemies each companion landed the killing blow on this battle: CompanionUnit -> int (missing = 0).
var kills: Dictionary = {}


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
	for d in enemy_data:
		var e := EnemyUnit.new(d)
		enemies.append(e)
		pick_next_action(e)
	_log("Battle start.")


# ---------------------------------------------------------------- queries

## Companions still standing in the line (active or injured), left to right.
func line() -> Array[CompanionUnit]:
	var out: Array[CompanionUnit] = []
	for c in roster:
		if not c.is_gone():
			out.append(c)
	return out


## Companions who are neither injured nor gone.
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
	if c.stamina < art.stamina_cost:
		return "Not enough stamina: %s needs %d, %s has %d." % [art.display_name, art.stamina_cost, c.display_name, c.stamina]
	return ""


## Stamina one Focus restores (flat, BattleConfig.FOCUS_RESTORE), never past the companion's max.
func focus_amount(c: CompanionUnit) -> int:
	return mini(BattleConfig.FOCUS_RESTORE, c.max_stamina())


## Forecast of one strike by a companion on an enemy: a plain attack, or with `art`'s bonuses.
## For an art that strikes twice, this is each strike. Damage = attack power (by weapon type, see
## CombatMath.attack_power) + Mt (+ the art's bonus) - DEF; a magic weapon uses MAG against RES.
## Effective (weapon or art against one of the target's traits): half as much again, once.
func forecast(c: CompanionUnit, target: EnemyUnit, art: CombatArtData = null) -> AttackForecast:
	var w := c.weapon()
	var effective := is_effective(c, target, art)
	var power := CombatMath.attack_power(c, w)
	var f: AttackForecast
	if art == null:
		f = CombatMath.forecast(c, w.might, w.hit, 0, target, 0, w.damage_type, effective, power)
	else:
		f = CombatMath.forecast(c, w.might + art.might_bonus, w.hit + art.hit_bonus, art.crit_bonus, target,
			art.ignore_def_percent, w.damage_type, effective, power)
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
func spell_forecast(c: CompanionUnit, spell: SpellData, target: EnemyUnit) -> AttackForecast:
	var effective := CombatMath.is_effective(spell.effective_against, target.traits())
	return CombatMath.forecast(c, spell.might, spell.hit, spell.crit_bonus, target, spell.ignore_res_percent,
		CombatMath.DamageType.MAGIC, effective)


## HP a white spell restores to each target: caster MAG + the spell's power (0 if it does not heal).
func heal_amount(c: CompanionUnit, spell: SpellData) -> int:
	return maxi(0, c.stat(Stat.MAG) + spell.heal_power) if spell.heals else 0


## HP `target` would have after `spell` heals it (capped at max HP); its HP now if gone or no heal.
func hp_after_heal(c: CompanionUnit, spell: SpellData, target: CompanionUnit) -> int:
	if target.is_gone() or not spell.heals:
		return target.hp
	return mini(target.max_hp(), target.hp + heal_amount(c, spell))


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
			if target is CompanionUnit and line().has(target):
				out.append(target)
		SpellData.Targeting.ALL_ALLIES:
			out.append_array(line())
	return out


## Single-target weights for line(), left to right. `reversed`: the position weights mirrored, so the
## leftmost companion has the largest (Guard, veils, beacons and injury still apply the same way).
func target_weights(reversed: bool = false) -> Array[float]:
	var out: Array[float] = []
	var l := line()
	for i in l.size():
		var place := l.size() - 1 - i if reversed else i
		var w := BattleConfig.TARGET_WEIGHT_BASE * pow(BattleConfig.TARGET_WEIGHT_GROWTH, place)
		w *= l[i].target_weight_mult()
		if l[i].is_injured():
			w *= BattleConfig.INJURED_TARGET_WEIGHT_MULT
		out.append(w)
	return out


## Hook for revive items or arts. Nothing can revive yet, so all-injured is a defeat.
func can_revive() -> bool:
	return false


# ---------------------------------------------------------------- commands
# Each returns false (and changes nothing) if the command is not allowed right now.

func attack(c: CompanionUnit, target: EnemyUnit) -> bool:
	if not can_act(c) or not _is_valid_target(target):
		return false
	_begin_tick()
	_log("%s attacks %s with %s." % [c.display_name, target.display_name, c.weapon().display_name])
	_emit({"type": "strike", "actor": c, "target": target, "name": "Attack", "art": null})
	var landed := _companion_strike(c, target, null)
	_add_points(c, BattleConfig.POINTS_ATTACK_HIT if landed else BattleConfig.POINTS_ATTACK_MISS)
	_gain_proficiency(c, BattleConfig.PROFICIENCY_POINTS_ATTACK)
	_end_player_action(c, BattleConfig.RECOVERY_ATTACK)
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
	c.stamina -= art.stamina_cost
	var aim := "every enemy" if art.hits_all_enemies else target.display_name
	_log("%s uses %s on %s (-%d STA)." % [c.display_name, art.display_name, aim, art.stamina_cost])
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
	if art.self_effect != null:
		_apply_effect(c, art.self_effect, true, c)
	_add_points(c, BattleConfig.POINTS_ART)
	_gain_proficiency(c, BattleConfig.PROFICIENCY_POINTS_ART)
	_end_player_action(c, art.recovery)
	return true


## Casts a known spell with uses left. `target` is an enemy for ONE_ENEMY, a companion still in the
## line (injured ones included) for ONE_ALLY, and ignored by spells that affect everyone.
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
		c.progress.uses_left(spell), spell.uses])
	_emit({"type": "cast", "actor": c, "spell": spell, "name": spell.display_name,
		"target": null if spell.targets_all() else targets[0]})
	for t in targets:
		if spell.deals_damage():
			_spell_strike(c, spell, t as EnemyUnit)
		else:
			_white_magic(c, spell, t as CompanionUnit)
	_add_points(c, BattleConfig.POINTS_SPELL)
	_gain_magic(c, spell.school)
	_end_player_action(c, spell.recovery)
	return true


func guard(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	c.add_effect(StatusEffect.guard())
	_log("%s guards." % c.display_name)
	_emit({"type": "guard", "actor": c})
	_end_player_action(c, BattleConfig.RECOVERY_GUARD)
	return true


func focus(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	var before := c.stamina
	c.stamina = mini(c.max_stamina(), c.stamina + focus_amount(c))
	_log("%s focuses (+%d STA, %d/%d)." % [c.display_name, c.stamina - before, c.stamina, c.max_stamina()])
	_emit({"type": "focus", "actor": c, "amount": c.stamina - before})
	_end_player_action(c, BattleConfig.RECOVERY_FOCUS)
	return true


func wait() -> bool:
	if not can_wait():
		return false
	_begin_tick()
	_log("The party waits.")
	_emit({"type": "wait"})
	_advance(null)
	return true


## Heals a companion. Healing an injured companion above 0 HP clears the injury. Gone companions
## cannot be healed.
func heal(c: CompanionUnit, amount: int) -> void:
	if c.is_gone() or amount <= 0:
		return
	var before := c.hp
	c.hp = mini(c.max_hp(), c.hp + amount)
	_log("  %s recovers %d HP (%d/%d HP)." % [c.display_name, c.hp - before, c.hp, c.max_hp()])
	_emit({"type": "heal", "target": c, "amount": c.hp - before, "hp": c.hp})
	if c.is_injured() and c.hp > 0:
		c.state = CompanionUnit.State.ACTIVE
		_log("%s is back on their feet (%d HP)." % [c.display_name, c.hp])
		_emit({"type": "revived", "target": c})


# ---------------------------------------------------------------- enemy side (public for tests)

## Picks the enemy's next action from its current list by pick weight. An action marked no_repeat is
## never picked right after itself while another action could be.
func pick_next_action(e: EnemyUnit) -> void:
	var actions := e.actions()
	if actions.is_empty():
		e.pending_action = null
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
	_emit({"type": "intent", "enemy": e})


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
			var target := pick_target(e.aims_reversed(action))
			if target != null:
				_enemy_strike(e, action, target)
		EnemyActionData.Targeting.ALL_COMPANIONS:
			for target in line():
				if not e.is_alive():
					break   # struck down by a reflecting stance partway through
				_enemy_strike(e, action, target)
	if action.hasten_allies > 0 and e.is_alive():
		_hasten_others(e, action.hasten_allies)


## Weighted random single target from the line; null if nobody is left. `reversed`: mirrored weights.
func pick_target(reversed: bool = false) -> CompanionUnit:
	var l := line()
	if l.is_empty():
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


## Recovery pressure: `c` sits out `ticks` more actions. Injured and gone companions are left alone,
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
	tick += 1
	events.clear()
	_log("== Turn %d ==" % tick)


func _end_player_action(c: CompanionUnit, recovery: int) -> void:
	c.recovery = recovery
	_advance(c)


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
		var left := living_enemies()
		if left.size() == 1 and left[0].phase == 0 and left[0].data.has_phase() \
				and left[0].data.phase_trigger == EnemyData.PhaseTrigger.LAST_STANDING:
			_enter_phase(left[0])
		return
	if e.phase == 0 and e.data.has_phase() and e.data.phase_trigger == EnemyData.PhaseTrigger.HP_BELOW \
			and e.hp * 100 <= e.max_hp() * e.data.phase_hp_percent:
		_enter_phase(e)


## Switches an enemy to its second action list, announced, and replaces its pending action.
func _enter_phase(e: EnemyUnit) -> void:
	e.phase = 1
	var title := e.data.phase_title if e.data.phase_title != "" else "%s changes" % e.display_name
	_log("%s: %s!" % [e.display_name, title])
	_emit({"type": "phase", "enemy": e, "title": title, "text": e.data.phase_text})
	if e.data.phase_effect != null:
		_apply_effect(e, e.data.phase_effect, true)
	pick_next_action(e)


## Poison, burning and the like: every effect's damage per tick, added up. A companion can be injured by
## it, but one already injured (or gone) takes none, so it never removes anyone. An enemy it kills is
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
		c.hp -= total
		_log("  %s loses %d HP to %s (%d/%d HP)." % [c.display_name, total, ", ".join(names), c.hp, c.max_hp()])
		_emit({"type": "dot", "target": c, "amount": total, "hp": c.hp, "name": names[0]})
		if c.hp <= 0:
			c.state = CompanionUnit.State.INJURED
			if not injured_ever.has(c):
				injured_ever.append(c)
			_log("  %s is injured!" % c.display_name)
			_emit({"type": "injured", "target": c})
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


## A white spell on one companion still in the line: heal, then remove debuffs, then the buff.
func _white_magic(c: CompanionUnit, spell: SpellData, target: CompanionUnit) -> void:
	if target.is_gone():
		return
	if spell.heals:
		heal(target, heal_amount(c, spell))
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


## Proficiency for acting with the weapon held, up to the per-battle cap.
## Every grade reached teaches a random art of that weapon type (if any is left to learn).
func _gain_proficiency(c: CompanionUnit, amount: int) -> void:
	var w := c.weapon()
	if w == null or amount <= 0:
		return
	var t := w.weapon_type
	var room := maxi(0, BattleConfig.PROFICIENCY_CAP_PER_BATTLE - c.proficiency_gained)
	var before := c.progress.grade(t)
	var gained := c.progress.add_points(t, mini(amount, room))
	c.proficiency_gained += gained
	if gained <= 0:
		return
	var kind := WeaponData.type_name(t).to_lower()
	_emit({"type": "proficiency", "actor": c, "weapon_type": t, "gained": gained})
	if c.proficiency_gained >= BattleConfig.PROFICIENCY_CAP_PER_BATTLE:
		_log("  %s has gained all the %s proficiency this battle can give." % [c.display_name, kind])
	for g in range(before + 1, c.progress.grade(t) + 1):
		_log("  %s's %s grade rises to %s!" % [c.display_name, kind, Proficiency.grade_name(g)])
		var ev := {"type": "grade_up", "actor": c, "magic": false, "weapon_type": t, "grade": g, "art": null, "equipped": false}
		grade_ups.append(ev)
		_emit(ev)


## Magic points for casting, up to the per-battle magic cap (separate from the weapon cap).
## Every school grade reached teaches a random spell of that school (if any is left to learn).
func _gain_magic(c: CompanionUnit, s: SpellData.School) -> void:
	var room := maxi(0, BattleConfig.MAGIC_CAP_PER_BATTLE - c.magic_gained)
	var before := c.progress.magic_grade(s)
	var gained := c.progress.add_magic_points(s, mini(BattleConfig.MAGIC_POINTS_PER_CAST, room))
	c.magic_gained += gained
	if gained <= 0:
		return
	var school := SpellData.school_name(s)
	_emit({"type": "proficiency", "actor": c, "magic": true, "school": s, "gained": gained})
	if c.magic_gained >= BattleConfig.MAGIC_CAP_PER_BATTLE:
		_log("  %s has gained all the magic proficiency this battle can give." % c.display_name)
	for g in range(before + 1, c.progress.magic_grade(s) + 1):
		_log("  %s's %s grade rises to %s!" % [c.display_name, school, Proficiency.grade_name(g)])
		var ev := {"type": "grade_up", "actor": c, "magic": true, "school": s, "grade": g, "spell": null}
		grade_ups.append(ev)
		_emit(ev)


## Once the battle is over: every grade reached this battle by a companion still in the run (won or
## lost; not one removed in it) teaches its art or spell, in the order the grades were reached, with
## the same picking rules and generator. Fills "art" and "equipped" (true only if a slot was free) or
## "spell" into each grade_ups entry. Called by _check_end when the battle ends, so callers need not;
## calling it again (or before the end) does nothing.
func learn_after_battle() -> void:
	if learned or not is_over():
		return
	learned = true
	for ev in grade_ups:
		var c: CompanionUnit = ev.actor
		if c.is_gone():
			continue
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


func _enemy_strike(e: EnemyUnit, action: EnemyActionData, target: CompanionUnit) -> void:
	if action.deals_damage:
		var f := CombatMath.forecast(e, action.might, action.hit, 0, target, 0, action.damage_type)
		if not _roll(f.hit):
			_log("  %s dodges. (%d%% to hit)" % [target.display_name, f.hit])
			_emit({"type": "miss", "target": target})
			return
		var crit := _roll(f.crit)
		var dmg := f.crit_damage if crit else f.damage
		# A companion's reflecting stance (Riposte, Set Spear) answers physical blows, even one that
		# fells them. Magic is never reflected. Worked out first: a companion who is gone loses effects.
		var back := reflect_amount(e, target, dmg) if action.damage_type == CombatMath.DamageType.PHYSICAL else 0
		var stance := _reflect_name(target)
		var guarding := target.has_effect("Guard")
		_damage_companion(target, dmg, crit)
		_add_points(target, BattleConfig.POINTS_BLOW_TAKEN_GUARDING if guarding else BattleConfig.POINTS_BLOW_TAKEN)
		if back > 0 and e.is_alive():
			_reflect_on_enemy(target, stance, e, back)
	if action.effect != null and not target.is_gone():
		_apply_effect(target, action.effect, false)
	if action.add_recovery > 0:
		add_recovery(target, action.add_recovery)


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


## A landed hit. Injured companions who are hit again are gone for good.
func _damage_companion(c: CompanionUnit, dmg: int, crit: bool) -> void:
	var was_injured := c.is_injured()
	c.hp -= dmg
	_log("  %s%s takes %d damage (%d/%d HP)." % ["CRITICAL! " if crit else "", c.display_name, dmg, c.hp, c.max_hp()])
	_emit({"type": "damage", "target": c, "amount": dmg, "crit": crit, "hp": c.hp})
	if was_injured:
		c.state = CompanionUnit.State.GONE
		c.effects.clear()
		_log("  %s is gone!" % c.display_name)
		_emit({"type": "gone", "target": c})
	elif c.hp <= 0:
		c.state = CompanionUnit.State.INJURED
		if not injured_ever.has(c):
			injured_ever.append(c)
		_log("  %s is injured!" % c.display_name)
		_emit({"type": "injured", "target": c})


## `helpful`: a buff or defend (as opposed to a debuff); only changes how it is shown.
## `source`: the companion who applied it, if any. It is kept only on damage over time (which credits
## them with a kill), so a companion's own effects never hold a reference back to a companion.
func _apply_effect(unit: Combatant, data: StatusEffectData, helpful: bool, source: CompanionUnit = null) -> void:
	var effect := StatusEffect.from_data(data)
	if effect.damage_per_tick > 0 and unit != source:
		effect.source = source
	unit.add_effect(effect)
	_log("  %s gains %s." % [unit.display_name, effect.describe()])
	_emit({"type": "effect", "target": unit, "name": effect.display_name, "helpful": helpful})


func _add_points(c: CompanionUnit, amount: int) -> void:
	points[c] = points_of(c) + amount


## Returns true if the battle is over (and sets outcome on the first call that sees it).
func _check_end() -> bool:
	if is_over():
		return true
	if living_enemies().is_empty():
		outcome = Outcome.VICTORY
		for c in line():
			if c.is_injured():
				c.hp = BattleConfig.VICTORY_INJURED_HP
				c.state = CompanionUnit.State.ACTIVE
		_log("Victory!")
		learn_after_battle()
		return true
	if line().is_empty():
		outcome = Outcome.DEFEAT
		_log("Defeat: no companions left.")
		learn_after_battle()
		return true
	if active_companions().is_empty() and not can_revive():
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
