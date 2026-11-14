class_name BattleAccount
extends RefCounted
## The account of a battle: what can be said of it before it begins (`before`: the hardest blow the
## enemy has against the line as it stands, and how the two sides' numbers compare), and what happened
## in it (a record the Battle keeps as it goes: every fall, the misses on both sides, who dealt and
## took the most; `lines` writes it out for the result screen).
## Plain rules: no nodes. Battle owns one (Battle.account) and calls the note_* methods.

## The scouts' word for a fight, from `before`'s ratio (BattleConfig.ACCOUNT_*_RATIO).
enum Word { SURE, CLOSE, GRIM }

## One entry per companion who fell: {"who": String, "by": String (the enemy, "" for damage over time),
## "blow": String (the action or the effect), "damage": int, "had": int (Health before it), "turn": int,
## "crit": bool}.
var falls: Array[Dictionary] = []
## Strikes and damaging spells by companions, and how many of them missed.
var strikes := 0
var strikes_missed := 0
## Enemy blows at companions, and how many of them missed.
var blows := 0
var blows_missed := 0
## Damage dealt and taken, by companion name.
var dealt: Dictionary = {}
var taken: Dictionary = {}


func note_strike(landed: bool) -> void:
	strikes += 1
	if not landed:
		strikes_missed += 1


func note_blow(landed: bool) -> void:
	blows += 1
	if not landed:
		blows_missed += 1


func note_dealt(who: String, amount: int) -> void:
	if who != "" and amount > 0:
		dealt[who] = int(dealt.get(who, 0)) + amount


func note_taken(who: String, amount: int) -> void:
	if amount > 0:
		taken[who] = int(taken.get(who, 0)) + amount


func note_fall(who: String, by: String, blow: String, damage: int, had: int, turn: int, crit: bool) -> void:
	falls.append({"who": who, "by": by, "blow": blow, "damage": damage, "had": had, "turn": turn, "crit": crit})


## How it went, in at most five short lines: the falls (the first in full, the rest together), what the
## enemy had left if the battle was lost, the misses on both sides, and who dealt and took the most.
func lines(battle: Battle) -> Array[String]:
	var out: Array[String] = []
	if not falls.is_empty():
		out.append(_fall_line(falls[0]))
		if falls.size() == 2:
			out.append(_fall_line(falls[1]))
		elif falls.size() > 2:
			var rest: Array[String] = []
			for i in range(1, falls.size()):
				rest.append("%s on turn %d" % [falls[i].who, falls[i].turn])
			out.append("Then %s." % _join(rest))
	if battle.outcome == Battle.Outcome.DEFEAT:
		var left := 0
		var full := 0
		for e in battle.enemies:
			left += maxi(0, e.hp)
			full += e.max_hp()
		if full > 0:
			out.append("The enemy had %d of %d Health left." % [left, full])
	if strikes > 0 or blows > 0:
		out.append("Our strikes missed %d of %d; theirs missed %d of %d." % [strikes_missed, strikes, blows_missed, blows])
	var most_dealt := _most(dealt)
	var most_taken := _most(taken)
	if most_dealt != "" and most_taken != "":
		out.append("%s dealt the most (%d); %s took the most (%d)." % [most_dealt, int(dealt[most_dealt]), most_taken, int(taken[most_taken])])
	elif most_dealt != "":
		out.append("%s dealt the most (%d); nobody was hurt." % [most_dealt, int(dealt[most_dealt])])
	elif most_taken != "":
		out.append("%s took the most (%d)." % [most_taken, int(taken[most_taken])])
	return out


func _fall_line(f: Dictionary) -> String:
	var blow := String(f.blow) if String(f.by) == "" else "%s's %s" % [f.by, f.blow]
	return "%s fell on turn %d to %s: %d damage%s, with %d Health left." % [f.who, f.turn, blow, f.damage,
		" on a critical" if bool(f.crit) else "", f.had]


static func _join(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]


## The name with the largest figure (the first of equals, in the order they were noted), or "".
static func _most(by_name: Dictionary) -> String:
	var best := ""
	for who: String in by_name:
		if best == "" or int(by_name[who]) > int(by_name[best]):
			best = who
	return best


# ---------------------------------------------------------------- before the battle

## What can be said of `b` as it stands now (meant for a battle that has not begun):
## {"blow": the hardest blow the enemy has against the line, or {} if it has none:
##     {"enemy": EnemyUnit, "action": EnemyActionData, "target": CompanionUnit, "damage": int,
##      "whole_line": bool, "fells": bool},
##  "turns_to_win": turns the line needs to bring every enemy down, "turns_to_fall": turns the enemies
##  need to bring the whole line down, "ratio": turns_to_fall / turns_to_win (more is better),
##  "word": Word}.
## The hardest blow is the one that takes the largest share of its target's Health as they stand, over
## every damaging action of every enemy (second phases included) and every companion it could land on,
## not critical. The turns are plain averages: each companion's best ordinary answer (an Attack, or a
## damaging spell they can cast) against each enemy with its chance to hit, at the pace the line can
## act (one action a turn with three or more standing, two in three with two, one in three alone);
## each enemy's actions by how often it picks them and how long they take, with their chance to hit,
## single blows spread over the line as it draws them. Nothing here is rolled.
static func before(b: Battle) -> Dictionary:
	var line := b.active_companions()
	var foes := b.living_enemies()
	var out := {"blow": {}, "turns_to_win": 0.0, "turns_to_fall": 0.0, "ratio": 0.0, "word": Word.CLOSE}
	if line.is_empty() or foes.is_empty():
		return out
	# The hardest blow.
	var worst := {}
	var worst_share := -1.0
	for e in foes:
		var acts: Array[EnemyActionData] = e.data.actions.duplicate()
		acts.append_array(e.data.phase_actions)
		for a in acts:
			if not a.deals_damage or (a.targeting != EnemyActionData.Targeting.SINGLE and a.targeting != EnemyActionData.Targeting.ALL_COMPANIONS):
				continue
			var whole := a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS
			for c in line:
				var f := b.enemy_forecast(e, a, c, whole)
				var share := float(f.damage) / maxf(1.0, c.hp)
				if share > worst_share:
					worst_share = share
					worst = {"enemy": e, "action": a, "target": c, "damage": f.damage, "whole_line": whole, "fells": f.damage >= c.hp}
	out.blow = worst
	# The turns the line needs.
	var pace := 1.0 if line.size() >= 3 else (2.0 / 3.0 if line.size() == 2 else 1.0 / 3.0)
	var to_win := 0.0
	for e in foes:
		var per_action := 0.0
		for c in line:
			per_action += _answer(b, c, e)
		per_action /= line.size()
		to_win += e.hp / maxf(0.25, per_action)
	to_win /= pace
	# The turns the enemies need.
	var line_hp := 0
	for c in line:
		line_hp += c.hp
	var per_turn := 0.0
	for e in foes:
		per_turn += _threat(b, e, line)
	var to_fall := line_hp / maxf(0.05, per_turn)
	out.turns_to_win = to_win
	out.turns_to_fall = to_fall
	out.ratio = to_fall / maxf(0.01, to_win)
	out.word = word_for(out.ratio)
	return out


static func word_for(ratio: float) -> Word:
	if ratio >= BattleConfig.ACCOUNT_SURE_RATIO:
		return Word.SURE
	if ratio < BattleConfig.ACCOUNT_GRIM_RATIO:
		return Word.GRIM
	return Word.CLOSE


## The damage `c` can be counted on for with one action against `e`: an Attack, or the best damaging
## spell they have uses of, times its chance to hit.
static func _answer(b: Battle, c: CompanionUnit, e: EnemyUnit) -> float:
	var f := b.forecast(c, e)
	var best := f.damage * maxi(1, f.strikes) * f.hit / 100.0
	for sp in c.spells():
		if sp.deals_damage() and c.progress.uses_left(sp) > 0:
			var sf := b.spell_forecast(c, sp, e)
			best = maxf(best, sf.damage * sf.hit / 100.0)
	return best


## The damage `e` deals to the line in an average turn. An enemy with a second phase fights part of the
## battle with each list: by the share of its Health each covers when the phase begins at a Health mark,
## half and half when it begins once the enemy stands alone.
static func _threat(b: Battle, e: EnemyUnit, line: Array[CompanionUnit]) -> float:
	var first := _list_threat(b, e, e.data.actions, line)
	if not e.data.has_phase() or e.data.phase_actions.is_empty():
		return first
	var later := 0.5
	if e.data.phase_trigger == EnemyData.PhaseTrigger.HP_BELOW:
		later = clampf(e.data.phase_hp_percent / 100.0, 0.0, 1.0)
	return first * (1.0 - later) + _list_threat(b, e, e.data.phase_actions, line) * later


## The damage one list of `e`'s actions deals to the line in an average turn: the actions by how often
## each is picked, each over the turns it takes.
static func _list_threat(b: Battle, e: EnemyUnit, actions: Array[EnemyActionData], line: Array[CompanionUnit]) -> float:
	var weight := 0.0
	var damage := 0.0
	var turns := 0.0
	for a in actions:
		var w := maxf(0.0, a.pick_weight)
		if w <= 0.0:
			continue
		weight += w
		turns += w * maxi(1, a.countdown)
		if not a.deals_damage:
			continue
		if a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS:
			for c in line:
				var f := b.enemy_forecast(e, a, c, true)
				damage += w * f.damage * f.hit / 100.0
		elif a.targeting == EnemyActionData.Targeting.SINGLE:
			var weights := b.target_weights(e.aims_reversed(a))
			var total := 0.0
			for x in weights:
				total += x
			var all := b.line()
			for i in all.size():
				if weights[i] <= 0.0:
					continue
				var f := b.enemy_forecast(e, a, all[i])
				damage += w * (weights[i] / maxf(0.001, total)) * f.damage * f.hit / 100.0
	if weight <= 0.0 or turns <= 0.0:
		return 0.0
	return damage / turns
