class_name Battle
extends RefCounted
## The battle rules. Plain script, no nodes or UI: the scene reads state and calls the command methods.
##
## One tick = one player action:
##   1. the player's action resolves
##   2. every living enemy's countdown drops by 1
##   3. enemies at 0 act, left to right, then pick their next action
##   4. companion recovery counters tick down (not the companion who just acted)
##   5. timed effects (Guard, buffs, defends, debuffs) lose a tick and expire

enum Outcome { ONGOING, VICTORY, DEFEAT }

var rng: RandomNumberGenerator
## All companions in line order, left to right. Gone companions stay in this list but leave line().
var roster: Array[CompanionUnit] = []
## Enemies, left to right.
var enemies: Array[EnemyUnit] = []
var tick: int = 0
var outcome: Outcome = Outcome.ONGOING
var log_lines: Array[String] = []


func _init(companion_data: Array[CompanionData], enemy_data: Array[EnemyData], p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	for d in companion_data:
		roster.append(CompanionUnit.new(d))
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


func can_use_skill(c: CompanionUnit) -> bool:
	var s := c.skill() if c != null else null
	return can_act(c) and s != null and c.stamina >= s.stamina_cost


func focus_amount(c: CompanionUnit) -> int:
	return maxi(1, roundi(c.max_stamina() * BattleConfig.FOCUS_RESTORE_FRACTION))


## Forecast of a companion striking an enemy, with or without the weapon skill.
func forecast(c: CompanionUnit, target: EnemyUnit, use_skill: bool = false) -> AttackForecast:
	var w := c.weapon()
	var might := w.might
	var hit := w.hit
	var crit_bonus := 0
	if use_skill and c.skill() != null:
		might += c.skill().might_bonus
		hit += c.skill().hit_bonus
		crit_bonus += c.skill().crit_bonus
	return CombatMath.forecast(c, might, hit, crit_bonus, target)


## Single-target weights for line(), left to right.
func target_weights() -> Array[float]:
	var out: Array[float] = []
	var l := line()
	for i in l.size():
		var w := BattleConfig.TARGET_WEIGHT_BASE * pow(BattleConfig.TARGET_WEIGHT_GROWTH, i)
		w *= l[i].target_weight_mult()
		if l[i].is_injured():
			w *= BattleConfig.INJURED_TARGET_WEIGHT_MULT
		out.append(w)
	return out


## Hook for revive items/skills. Nothing can revive yet, so all-injured is a defeat.
func can_revive() -> bool:
	return false


# ---------------------------------------------------------------- commands
# Each returns false (and changes nothing) if the command is not allowed right now.

func attack(c: CompanionUnit, target: EnemyUnit) -> bool:
	if not can_act(c) or not _is_valid_target(target):
		return false
	_begin_tick()
	_log("%s attacks %s with %s." % [c.display_name, target.display_name, c.weapon().display_name])
	_companion_strike(c, target, false)
	_end_player_action(c, BattleConfig.RECOVERY_ATTACK)
	return true


func use_skill(c: CompanionUnit, target: EnemyUnit) -> bool:
	if not can_use_skill(c) or not _is_valid_target(target):
		return false
	_begin_tick()
	var s := c.skill()
	c.stamina -= s.stamina_cost
	_log("%s uses %s on %s (-%d STA)." % [c.display_name, s.display_name, target.display_name, s.stamina_cost])
	_companion_strike(c, target, true)
	_end_player_action(c, BattleConfig.RECOVERY_SKILL)
	return true


func guard(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	c.add_effect(StatusEffect.guard())
	_log("%s guards." % c.display_name)
	_end_player_action(c, BattleConfig.RECOVERY_GUARD)
	return true


func focus(c: CompanionUnit) -> bool:
	if not can_act(c):
		return false
	_begin_tick()
	var before := c.stamina
	c.stamina = mini(c.max_stamina(), c.stamina + focus_amount(c))
	_log("%s focuses (+%d STA, %d/%d)." % [c.display_name, c.stamina - before, c.stamina, c.max_stamina()])
	_end_player_action(c, BattleConfig.RECOVERY_FOCUS)
	return true


func wait() -> bool:
	if not can_wait():
		return false
	_begin_tick()
	_log("The party waits.")
	_advance(null)
	return true


## Heals a companion. Healing an injured companion above 0 HP clears the injury.
## (No healing exists in the prototype yet; this is the rule for when it does.)
func heal(c: CompanionUnit, amount: int) -> void:
	if c.is_gone() or amount <= 0:
		return
	c.hp = mini(c.max_hp(), c.hp + amount)
	if c.is_injured() and c.hp > 0:
		c.state = CompanionUnit.State.ACTIVE
		_log("%s is back on their feet (%d HP)." % [c.display_name, c.hp])


# ---------------------------------------------------------------- enemy side (public for tests)

func pick_next_action(e: EnemyUnit) -> void:
	var actions := e.data.actions
	if actions.is_empty():
		e.pending_action = null
		e.countdown = 0
		return
	var weights: Array[float] = []
	for a in actions:
		weights.append(maxf(0.0, a.pick_weight))
	var action := actions[_weighted_index(weights)]
	e.pending_action = action
	e.countdown = maxi(BattleConfig.MIN_ACTION_COUNTDOWN, action.countdown)


func perform_enemy_action(e: EnemyUnit, action: EnemyActionData) -> void:
	if action == null:
		return
	_log("%s uses %s." % [e.display_name, action.display_name])
	match action.targeting:
		EnemyActionData.Targeting.SELF:
			if action.effect != null:
				_apply_effect(e, action.effect)
		EnemyActionData.Targeting.SINGLE:
			var target := pick_target()
			if target != null:
				_enemy_strike(e, action, target)
		EnemyActionData.Targeting.ALL_COMPANIONS:
			for target in line():
				_enemy_strike(e, action, target)


## Weighted random single target from the line; null if nobody is left.
func pick_target() -> CompanionUnit:
	var l := line()
	if l.is_empty():
		return null
	return l[_weighted_index(target_weights())]


# ---------------------------------------------------------------- internals

func _is_valid_target(target: EnemyUnit) -> bool:
	return target != null and target.is_alive() and enemies.has(target)


func _begin_tick() -> void:
	tick += 1
	_log("== Tick %d ==" % tick)


func _end_player_action(c: CompanionUnit, recovery: int) -> void:
	c.recovery = recovery
	_advance(c)


func _advance(acted: CompanionUnit) -> void:
	if _check_end():
		return
	for e in living_enemies():
		e.countdown -= 1
	for e in enemies:
		if e.is_alive() and e.countdown <= 0:
			perform_enemy_action(e, e.pending_action)
			pick_next_action(e)
			if _check_end():
				return
	for c in line():
		if c != acted and c.recovery > 0:
			c.recovery -= 1
	for unit: Combatant in roster + enemies:
		for expired in unit.tick_effects():
			if expired.display_name != "Guard":
				_log("%s's %s wears off." % [unit.display_name, expired.display_name])
	_check_end()


func _companion_strike(c: CompanionUnit, target: EnemyUnit, use_skill_bonus: bool) -> void:
	var f := forecast(c, target, use_skill_bonus)
	if not _roll(f.hit):
		_log("  Miss! (%d%% to hit)" % f.hit)
		return
	var crit := _roll(f.crit)
	var dmg := f.crit_damage if crit else f.damage
	target.hp -= dmg
	_log("  %s%s takes %d damage (%d/%d HP)." % ["CRITICAL! " if crit else "", target.display_name, dmg, maxi(target.hp, 0), target.max_hp()])
	if not target.is_alive():
		_log("  %s is defeated!" % target.display_name)


func _enemy_strike(e: EnemyUnit, action: EnemyActionData, target: CompanionUnit) -> void:
	if action.deals_damage:
		var f := CombatMath.forecast(e, action.might, action.hit, 0, target)
		if not _roll(f.hit):
			_log("  %s dodges. (%d%% to hit)" % [target.display_name, f.hit])
			return
		var crit := _roll(f.crit)
		_damage_companion(target, f.crit_damage if crit else f.damage, crit)
	if action.effect != null and not target.is_gone():
		_apply_effect(target, action.effect)


## A landed hit. Injured companions who are hit again are gone for good.
func _damage_companion(c: CompanionUnit, dmg: int, crit: bool) -> void:
	var was_injured := c.is_injured()
	c.hp -= dmg
	_log("  %s%s takes %d damage (%d/%d HP)." % ["CRITICAL! " if crit else "", c.display_name, dmg, c.hp, c.max_hp()])
	if was_injured:
		c.state = CompanionUnit.State.GONE
		c.effects.clear()
		_log("  %s is gone!" % c.display_name)
	elif c.hp <= 0:
		c.state = CompanionUnit.State.INJURED
		_log("  %s is injured!" % c.display_name)


func _apply_effect(unit: Combatant, data: StatusEffectData) -> void:
	var effect := StatusEffect.from_data(data)
	unit.add_effect(effect)
	_log("  %s gains %s." % [unit.display_name, effect.describe()])


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
		return true
	if line().is_empty():
		outcome = Outcome.DEFEAT
		_log("Defeat: no companions left.")
		return true
	if active_companions().is_empty() and not can_revive():
		outcome = Outcome.DEFEAT
		_log("Defeat: every remaining companion is injured.")
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
