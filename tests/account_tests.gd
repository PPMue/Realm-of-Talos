extends RefCounted
## Headless tests for the account of a battle (design/battle.md, "The account"): what is said before
## it (BattleAccount.before, Run.front_account) and the record kept while it is fought
## (Battle.account, BattleAccount.lines, BattleReport.account). Called from run_tests.gd, which owns
## check() and eq().

const RunRuleTests := preload("res://tests/run_rule_tests.gd")

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_hardest_blow,
		test_turns_and_ratio,
		test_word_for,
		test_front_account_changes_nothing,
		test_record_of_a_fall,
		test_record_misses_and_most,
		test_lines_at_most_five,
		test_report_carries_the_account,
	]


# ---------------------------------------------------------------- helpers

## Companions with the given Health (STR 10, a Mt 5 weapon that always hits: 15 an Attack against DEF 0).
func line_of(hp: Array) -> Array[CompanionData]:
	var cs: Array[CompanionData] = []
	for i in hp.size():
		cs.append(t.make_companion("C%d" % i, hp[i]))
	return cs


## One enemy with one action (STR 10 + might against DEF 0), landing every time.
func foe(n: String, action: EnemyActionData, hp: int = 500) -> EnemyData:
	var acts: Array[EnemyActionData] = [action]
	return t.make_enemy(n, acts, hp)


# ---------------------------------------------------------------- before

## The hardest blow is the one that takes the largest share of its target's Health as they stand.
func test_hardest_blow() -> void:
	var strike: EnemyActionData = t.make_action("Strike", 1, EnemyActionData.Targeting.SINGLE, 5)       # 15
	var sweep: EnemyActionData = t.make_action("Sweep", 3, EnemyActionData.Targeting.ALL_COMPANIONS, 2)   # 12
	var es: Array[EnemyData] = [foe("Striker", strike), foe("Sweeper", sweep)]
	var b: Battle = t.make_battle(line_of([100, 100, 40]), es)
	var a := BattleAccount.before(b)
	var blow: Dictionary = a.blow
	t.eq(blow.action.display_name, "Strike", "the single blow is the harder")
	t.eq(blow.target, b.roster[2], "on whoever has the least Health")
	t.eq(blow.damage, 15, "15")
	t.check(not blow.fells and not blow.whole_line, "it does not fell them, and is aimed at one")
	# Health as it stands, not at its fullest: a blow that would fell someone says so.
	b.roster[0].hp = 12
	blow = BattleAccount.before(b).blow
	t.eq(blow.target, b.roster[0], "now the one down to 12")
	t.check(blow.fells, "it would fell them")
	# A second phase's actions are counted too; an enemy with nothing that hurts has no blow.
	var idle: Battle = t.make_battle(line_of([100]), t.one_enemy(t.idle_enemy(100)))
	idle.enemies[0].data.actions[0].deals_damage = false
	t.check(BattleAccount.before(idle).blow.is_empty(), "nothing that hurts: no blow")
	var two_faced: EnemyData = foe("Changer", strike)
	var later: Array[EnemyActionData] = [t.make_action("Ruin", 2, EnemyActionData.Targeting.SINGLE, 30)]
	two_faced.phase_actions = later
	var pb: Battle = t.make_battle(line_of([100]), t.one_enemy(two_faced))
	t.eq(BattleAccount.before(pb).blow.action.display_name, "Ruin", "the second phase's blow is the hardest")


## Turns the enemy needs to fell the line over turns the line needs to fell the enemy, on plain averages.
func test_turns_and_ratio() -> void:
	var strike: EnemyActionData = t.make_action("Strike", 1, EnemyActionData.Targeting.SINGLE, 5)   # 15 a turn
	var b: Battle = t.make_battle(line_of([100, 100, 100]), t.one_enemy(foe("Striker", strike, 600)))
	var a := BattleAccount.before(b)
	t.check(absf(float(a.turns_to_fall) - 300.0 / 15.0) < 0.01, "300 Health at 15 a turn: 20 turns (%.2f)" % float(a.turns_to_fall))
	t.check(absf(float(a.turns_to_win) - 600.0 / 15.0) < 0.01, "600 Health at 15 an action: 40 turns (%.2f)" % float(a.turns_to_win))
	t.check(absf(float(a.ratio) - 0.5) < 0.01, "ratio 0.5 (%.3f)" % float(a.ratio))
	# A line of two acts two turns in three, one alone one in three.
	var two: Battle = t.make_battle(line_of([100, 100]), t.one_enemy(foe("Striker", strike, 600)))
	t.check(absf(float(BattleAccount.before(two).turns_to_win) - 60.0) < 0.01, "two: 60 turns")
	var one: Battle = t.make_battle(line_of([100]), t.one_enemy(foe("Striker", strike, 600)))
	t.check(absf(float(BattleAccount.before(one).turns_to_win) - 120.0) < 0.01, "one: 120 turns")
	# A slower action is that much less a turn; a blow on the whole line counts for everyone.
	var slow: EnemyActionData = t.make_action("Strike", 3, EnemyActionData.Targeting.SINGLE, 5)
	var sb: Battle = t.make_battle(line_of([100, 100, 100]), t.one_enemy(foe("Slow", slow, 600)))
	t.check(absf(float(BattleAccount.before(sb).turns_to_fall) - 60.0) < 0.01, "countdown 3: 60 turns")
	var sweep: EnemyActionData = t.make_action("Sweep", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 5)
	var wb: Battle = t.make_battle(line_of([100, 100, 100]), t.one_enemy(foe("Sweeper", sweep, 600)))
	t.check(absf(float(BattleAccount.before(wb).turns_to_fall) - 300.0 / 45.0) < 0.01, "a sweep: 45 a turn")
	# A chance to miss counts.
	var wild: EnemyActionData = t.make_action("Strike", 1, EnemyActionData.Targeting.SINGLE, 5)
	wild.hit = 50
	var mb: Battle = t.make_battle(line_of([100, 100, 100]), t.one_enemy(foe("Wild", wild, 600)))
	var hit: int = mb.enemy_forecast(mb.enemies[0], wild, mb.roster[0]).hit
	t.check(absf(float(BattleAccount.before(mb).turns_to_fall) - 300.0 / (15.0 * hit / 100.0)) < 0.01, "at %d%% to hit" % hit)
	# Nothing was rolled or changed.
	var state: int = b.rng.state
	BattleAccount.before(b)
	t.eq(b.rng.state, state, "no dice rolled")
	t.eq(b.tick, 0, "no turn passed")


func test_word_for() -> void:
	t.eq(BattleAccount.word_for(BattleConfig.ACCOUNT_SURE_RATIO), BattleAccount.Word.SURE, "at the sure ratio: sure")
	t.eq(BattleAccount.word_for(BattleConfig.ACCOUNT_SURE_RATIO - 0.001), BattleAccount.Word.CLOSE, "just under: close")
	t.eq(BattleAccount.word_for(BattleConfig.ACCOUNT_GRIM_RATIO), BattleAccount.Word.CLOSE, "at the grim ratio: close")
	t.eq(BattleAccount.word_for(BattleConfig.ACCOUNT_GRIM_RATIO - 0.001), BattleAccount.Word.GRIM, "just under: grim")
	t.check(BattleConfig.ACCOUNT_SURE_RATIO > BattleConfig.ACCOUNT_GRIM_RATIO, "sure is above grim")


## Run.front_account looks at a throwaway battle: the run's dice, Health and spell uses are untouched,
## and asking twice says the same.
func test_front_account_changes_nothing() -> void:
	var rr = RunRuleTests.new(t)
	var run: Run = rr.make_run(21)
	run.day = 3
	rr.force_day(run, RunCalendar.DayType.BATTLE)
	run.lineup[0].hp = maxi(1, run.lineup[0].hp - 5)
	var state: int = run.rng.state
	var hp: Array[int] = []
	for c in run.lineup:
		hp.append(c.hp)
	for f in run.fronts:
		var a := run.front_account(f)
		t.check(not a.is_empty() and float(a.turns_to_win) > 0.0 and float(a.turns_to_fall) > 0.0, "%s: an account" % f.title())
		t.check(not (a.blow as Dictionary).is_empty(), "%s: a hardest blow" % f.title())
		var again := run.front_account(f)
		t.check(absf(float(a.ratio) - float(again.ratio)) < 0.0001, "%s: the same when asked again" % f.title())
	t.eq(run.rng.state, state, "the run's dice were not rolled")
	for i in run.lineup.size():
		t.eq(run.lineup[i].hp, hp[i], "%s: Health untouched" % run.lineup[i].display_name())
	t.check(run.committed_front == null, "no front was committed to")
	# Health as it stands counts: the same front is a worse fight for a hurt line.
	var full := float(run.front_account(run.fronts[0]).ratio)
	for c in run.lineup:
		c.hp = maxi(1, c.hp / 2)
	t.check(float(run.front_account(run.fronts[0]).ratio) < full, "a hurt line: a lower ratio")
	var lineup := run.lineup.duplicate()
	run.lineup.clear()
	t.check(run.front_account(run.fronts[0]).is_empty(), "nobody in the line: nothing to say")
	run.lineup.assign(lineup)


# ---------------------------------------------------------------- after

## Each fall is recorded with the enemy, the blow, the damage, the Health they had and the turn.
func test_record_of_a_fall() -> void:
	var strike: EnemyActionData = t.make_action("Strike", 1, EnemyActionData.Targeting.SINGLE, 5)
	var b: Battle = t.make_battle(line_of([100, 12]), t.one_enemy(foe("Striker", strike)))
	b.enemies[0].pending_target = b.roster[1]
	b.attack(b.roster[0], b.enemies[0])
	t.eq(b.account.falls.size(), 1, "one fall")
	var f: Dictionary = b.account.falls[0]
	t.eq([f.who, f.by, f.blow, f.damage, f.had, f.turn, f.crit], ["C1", "Striker", "Strike", 15, 12, 1, false], "who, by whom, what, how much, with what, when")
	var lines := b.account.lines(b)
	t.eq(lines[0], "C1 fell on turn 1 to Striker's Strike: 15 damage, with 12 Health left.", "the line for it")
	# Damage over time fells too, with no enemy named.
	var b2: Battle = t.make_battle(line_of([100, 100]), t.one_enemy(t.idle_enemy(500)))
	var poison: StatusEffectData = t.make_effect("Poison", {}, 3)
	poison.damage_per_tick = 4
	b2._apply_effect(b2.roster[1], poison, false)
	b2.roster[1].hp = 3
	b2.attack(b2.roster[0], b2.enemies[0])
	t.eq(b2.account.falls.size(), 1, "poison: one fall")
	var p: Dictionary = b2.account.falls[0]
	t.eq([p.who, p.by, p.blow, p.had, p.turn], ["C1", "", "Poison", 3, 1], "to the poison")
	t.check(b2.account.lines(b2)[0].begins_with("C1 fell on turn 1 to Poison:"), "the line names the poison alone")


## Strikes and blows are counted with their misses; damage dealt and taken by name; a lost battle says
## what the enemy had left.
func test_record_misses_and_most() -> void:
	var strike: EnemyActionData = t.make_action("Strike", 1, EnemyActionData.Targeting.SINGLE, 5)
	var b: Battle = t.make_battle(line_of([100, 100, 100]), t.one_enemy(foe("Striker", strike)))
	b.enemies[0].pending_target = b.roster[2]
	b.attack(b.roster[0], b.enemies[0])
	b.attack(b.roster[1], b.enemies[0])
	t.eq([b.account.strikes, b.account.strikes_missed], [2, 0], "two strikes, none missed")
	t.eq([b.account.blows, b.account.blows_missed], [2, 0], "two blows, none missed")
	t.eq(int(b.account.dealt["C0"]), 15, "C0 dealt 15")
	t.eq(int(b.account.taken["C2"]), 15, "C2 took the first")
	var lines := b.account.lines(b)
	t.check(lines.has("Our strikes missed 0 of 2; theirs missed 0 of 2."), "the misses line")
	t.check(lines[lines.size() - 1].contains("dealt the most (15)") and lines[lines.size() - 1].contains("took the most"), "who did and took the most")
	# Damage past what the enemy had left is not counted; misses are.
	var weak: Battle = t.make_battle(line_of([100, 100]), t.one_enemy(t.idle_enemy(4)))
	weak.attack(weak.roster[0], weak.enemies[0])
	t.eq(int(weak.account.dealt["C0"]), 4, "only the 4 it had")
	var clumsy: Array[CompanionData] = [t.make_companion("A", 100, 0, t.make_weapon(1, 0)), t.make_companion("B", 100)]
	clumsy[0].dexterity = 0
	var fast: EnemyData = t.idle_enemy(100000)
	fast.speed = 99
	fast.luck = 99
	var mb: Battle = t.make_battle(clumsy, t.one_enemy(fast), 5)
	for i in 30:
		t.rest(mb)
		mb.attack(mb.roster[0], mb.enemies[0])
	t.eq(mb.account.strikes, 30, "thirty strikes")
	t.check(mb.account.strikes_missed > 0 and mb.account.strikes_missed < 30, "some missed (%d)" % mb.account.strikes_missed)
	# A lost battle says what the enemy had left; a retreat is one.
	var lost: Battle = t.make_battle(line_of([100, 100]), t.one_enemy(foe("Striker", strike, 200)))
	lost.allow_retreat = true
	lost.attack(lost.roster[0], lost.enemies[0])
	lost.retreat()
	t.check(lost.account.lines(lost).has("The enemy had 185 of 200 Health left."), "what the enemy had left")


## However many fell, the account is at most five lines: the first fall in full, the rest together.
func test_lines_at_most_five() -> void:
	var sweep: EnemyActionData = t.make_action("Sweep", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 5)
	var b: Battle = t.make_battle(line_of([10, 10, 10, 10]), t.one_enemy(foe("Sweeper", sweep)))
	b.attack(b.roster[0], b.enemies[0])
	t.eq(b.outcome, Battle.Outcome.DEFEAT, "all four fell")
	t.eq(b.account.falls.size(), 4, "four falls recorded")
	var lines := b.account.lines(b)
	t.check(lines.size() <= 5, "at most five lines (%d)" % lines.size())
	t.check(lines[0].begins_with("C0 fell on turn 1 to Sweeper's Sweep"), "the first in full")
	t.eq(lines[1], "Then C1 on turn 1, C2 on turn 1 and C3 on turn 1.", "the rest together")
	# Two falls: both in full.
	var b2: Battle = t.make_battle(line_of([10, 10, 100]), t.one_enemy(foe("Sweeper", sweep)))
	b2.attack(b2.roster[2], b2.enemies[0])
	var two := b2.account.lines(b2)
	t.check(two[0].begins_with("C0 fell") and two[1].begins_with("C1 fell"), "two falls: each in full")
	# Nobody fell and nothing happened: nothing to say.
	var quiet: Battle = t.make_battle(line_of([100]), t.one_enemy(t.idle_enemy(100)))
	t.eq(quiet.account.lines(quiet).size(), 0, "an untouched battle: no lines")


## Run.finish_battle hands the lines to the report.
func test_report_carries_the_account() -> void:
	var rr = RunRuleTests.new(t)
	var run: Run = rr.make_run(21)
	run.day = 3
	rr.force_day(run, RunCalendar.DayType.BATTLE)
	var b := run.start_battle(run.fronts[0])
	b._blow_by = "Someone"
	b._blow_name = "Something"
	b._damage_companion(b.roster[0], 999, false)
	b.retreat()
	var report := run.finish_battle(b)
	t.check(not report.account.is_empty(), "the report has the account")
	t.check(report.account[0].contains("fell on turn") and report.account[0].contains("Someone's Something"), "with the fall in it")
	t.check(report.account.size() <= 5, "at most five lines")
