extends RefCounted
## Headless tests for magic (spells, schools, uses, effects, countdown delay, enemy magic, magic
## weapons), the effectiveness rule, the two mages, and casting heals between battles.
## Called from run_tests.gd, which owns check(), eq() and the battle helpers.

var t   # the runner (run_tests.gd)


func _init(runner: Object) -> void:
	t = runner


func tests() -> Array[Callable]:
	return [
		test_magic_damage_and_minimum,
		test_spell_hit_and_crit_use_spell_hit,
		test_spell_uses_persist_block_and_rest,
		test_spell_costs_no_stamina_and_one_tick,
		test_spell_recovery_by_tier,
		test_magic_points_and_separate_cap,
		test_spell_learning_odds_duplicates_fall_through,
		test_spell_learned_on_grade_up_in_battle,
		test_heal_amounts,
		test_heal_lifts_injured_and_not_gone,
		test_white_cleanse,
		test_white_buffs_and_damage_reduction,
		test_white_veil_and_beacon,
		test_white_every_ally,
		test_black_every_enemy_ignore_res_and_debuff,
		test_countdown_delay_once_per_action,
		test_no_art_can_delay,
		test_enemy_magic_uses_res_and_guard_halves,
		test_magic_weapon_uses_mag_and_res,
		test_effective_weapon_adds_half,
		test_effective_art_and_no_stacking,
		test_effective_spell,
		test_no_effectiveness_without_trait,
		test_first_two_never_both_mages,
		test_mages_in_run,
		test_healing_only_in_battle,
		test_thornward_reflects_like_a_stance,
		test_blight_kills_and_credits_the_caster,
		test_sanctuary_heals_and_cleanses_everyone,
		test_entomb_delays_once,
		test_rare_shop_stock,
		test_magic_content,
	]


# ---------------------------------------------------------------- helpers

func make_spell(n: String, school: SpellData.School = SpellData.School.BLACK, tier: int = 1,
		targeting: SpellData.Targeting = SpellData.Targeting.ONE_ENEMY, might: int = 0, uses: int = 6) -> SpellData:
	var s := SpellData.new()
	s.display_name = n
	s.school = school
	s.tier = tier
	s.targeting = targeting
	s.might = might
	s.hit = 999
	s.uses = uses
	s.recovery = tier
	return s


func heal_spell(power: int = 4, targeting: SpellData.Targeting = SpellData.Targeting.ONE_ALLY) -> SpellData:
	var s := make_spell("Test Heal", SpellData.School.WHITE, 1, targeting)
	s.heals = true
	s.heal_power = power
	return s


## A test companion with MAG and RES set, knowing `spells`.
func caster(n: String, magic: int, spells: Array[SpellData], hp: int = 30) -> CompanionData:
	var d: CompanionData = t.make_companion(n, hp)
	d.magic = magic
	d.resistance = 0
	if not spells.is_empty():
		d.signature_spell = spells[0]
	return d


func battle_with(cs: Array[CompanionData], es: Array[EnemyData], spells: Array[SpellData] = [], seed_value: int = 1,
		pool: Array[SpellData] = []) -> Battle:
	var b := Battle.new(cs, es, t.make_rng(seed_value), [], [], pool)
	for c in b.roster:
		for sp in spells:
			c.progress.learn_spell(sp)
	return b


func enemy_with(res: int, hp: int = 200, traits: Array[String] = []) -> EnemyData:
	var e: EnemyData = t.idle_enemy(hp)
	e.resistance = res
	e.defense = 0
	e.traits = traits
	return e


func one(e: EnemyData) -> Array[EnemyData]:
	var es: Array[EnemyData] = [e]
	return es


func cs1(d: CompanionData) -> Array[CompanionData]:
	var cs: Array[CompanionData] = [d]
	return cs


func make_run(seed_value: int) -> Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Run.create(rng, RunContent.load_default(), ArtLibrary.load_default().arts, SpellLibrary.load_default().spells)


func companion(n: String) -> CompanionData:
	return load("res://data/companions/%s.tres" % n)


# ---------------------------------------------------------------- damage, hit, crit

func test_magic_damage_and_minimum() -> void:
	t.eq(CombatMath.magic_damage(10, 5, 3), 12, "MAG + Mt - RES")
	t.eq(CombatMath.magic_damage(2, 1, 30), 1, "minimum 1")
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 5)
	var d := caster("Mage", 10, [bolt])
	d.strength = 50   # STR must not matter
	var e := enemy_with(4)
	e.defense = 40    # nor DEF
	var b := battle_with(cs1(d), one(e))
	var f := b.spell_forecast(b.roster[0], bolt, b.enemies[0])
	t.eq(f.damage, 11, "10 MAG + 5 Mt - 4 RES")
	t.check(f.magic, "marked as magic")
	t.check(b.cast(b.roster[0], bolt, b.enemies[0]), "cast")
	t.eq(b.enemies[0].hp, 200 - 11, "the enemy takes it (or a crit, which test data rules out)")
	e.resistance = 99
	var b2 := battle_with(cs1(d), one(e))
	t.eq(b2.spell_forecast(b2.roster[0], bolt, b2.enemies[0]).damage, 1, "at least 1 against high RES")


func test_spell_hit_and_crit_use_spell_hit() -> void:
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 3)
	bolt.hit = 70
	bolt.crit_bonus = 10
	var d := caster("Mage", 8, [bolt])
	d.dexterity = 12
	d.crit = 6
	d.weapon = t.make_weapon(5, 10)   # a weapon Hit of 10 must not be used
	var e := enemy_with(0)
	e.speed = 10
	e.luck = 3
	var b := battle_with(cs1(d), one(e))
	var f := b.spell_forecast(b.roster[0], bolt, b.enemies[0])
	t.eq(f.hit, 70 + 5 * (12 - 10) - 3, "spell Hit + 5 x (DEX - SPD) - LCK")
	t.eq(f.crit, 2 * 6 - 3 + 10, "2 x CRT - LCK + the spell's crit bonus")
	bolt.hit = 0
	t.eq(b.spell_forecast(b.roster[0], bolt, b.enemies[0]).hit, BattleConfig.ACCURACY_MIN, "clamped like any strike")
	t.eq(f.crit_damage, f.damage * 2, "a crit doubles")
	# Misses happen: over many seeds a 50% spell lands about half the time.
	bolt.hit = 50 - 5 * 2 + 3
	var landed := 0
	for s in 200:
		var bs := battle_with(cs1(d), one(e), [], s)
		bs.cast(bs.roster[0], bolt, bs.enemies[0])
		if bs.enemies[0].hp < 200:
			landed += 1
	t.check(landed > 70 and landed < 130, "about half of 50%% casts land (%d / 200)" % landed)


# ---------------------------------------------------------------- uses, stamina, recovery

func test_spell_uses_persist_block_and_rest() -> void:
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 1, 2)
	var d := caster("Mage", 5, [bolt])
	var p := CompanionProgress.create(d)
	t.eq(p.uses_left(bolt), 2, "starts full")
	var party: Array[CompanionProgress] = [p]
	var b := Battle.new(cs1(d), one(enemy_with(0, 500)), t.make_rng(1), party)
	var c := b.roster[0]
	t.check(b.cast(c, bolt, b.enemies[0]), "first cast")
	t.eq(p.uses_left(bolt), 1, "one use spent")
	# The next battle carries the same progress.
	var b2 := Battle.new(cs1(d), one(enemy_with(0, 500)), t.make_rng(2), party)
	var c2 := b2.roster[0]
	t.eq(c2.progress.uses_left(bolt), 1, "uses persist into the next battle")
	t.check(b2.cast(c2, bolt, b2.enemies[0]), "second cast")
	t.eq(p.uses_left(bolt), 0, "none left")
	b2.wait()
	var tick := b2.tick
	t.check(not b2.can_cast(c2, bolt), "cannot cast at 0")
	t.check(b2.spell_block_reason(c2, bolt).contains("Rest"), "says Rest restores: %s" % b2.spell_block_reason(c2, bolt))
	t.check(not b2.cast(c2, bolt, b2.enemies[0]), "cast refused")
	t.eq(b2.tick, tick, "a refused cast takes no tick")
	# In a run: uses persist across days and only Rest restores them.
	var run := make_run(3)
	var mage := run._join(companion("aveline"))
	var mend := mage.data.signature_spell
	mage.progress.spend_use(mend)
	mage.progress.spend_use(mend)
	run._end_day()
	t.eq(mage.progress.uses_left(mend), mend.uses - 2, "the end of a day does not restore uses")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event_days.erase(run.day)
	run._begin_day()
	for rc in run.roster:
		rc.hp = rc.max_hp()
	t.eq(run.free_action_block_reason(Run.FreeAction.REST), "", "Rest allowed at full HP when spell uses are spent")
	t.check(run.rest(), "rest")
	t.eq(mage.progress.uses_left(mend), mend.uses, "Rest restores every use")
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.actions_used.clear()
	run.actions_left = RunConfig.FREE_DAY_ACTIONS
	t.check(run.free_action_block_reason(Run.FreeAction.REST) != "", "nothing to rest from once HP and uses are full")


func test_spell_costs_no_stamina_and_one_tick() -> void:
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 1)
	var b := battle_with(t.three_companions(), one(enemy_with(0)), [bolt])
	var c := b.roster[2]
	c.stamina = 0
	t.check(b.cast(c, bolt, b.enemies[0]), "cast at 0 stamina")
	t.eq(c.stamina, 0, "no stamina spent")
	t.eq(b.tick, 1, "one tick")
	t.eq(b.enemies[0].countdown, 9999 - 1, "the enemy countdown dropped by exactly 1")


func test_spell_recovery_by_tier() -> void:
	for tier in [1, 2, 3]:
		var sp := make_spell("S%d" % tier, SpellData.School.BLACK, tier, SpellData.Targeting.ONE_ENEMY, 1)
		var b := battle_with(t.three_companions(), one(enemy_with(0)), [sp])
		b.cast(b.roster[2], sp, b.enemies[0])
		t.eq(b.roster[2].recovery, tier, "tier %d sits out %d" % [tier, tier])
	var lib := SpellLibrary.load_default()
	for sp in lib.spells:
		t.eq(sp.recovery, sp.tier, "%s: recovery grows with tier" % sp.display_name)


# ---------------------------------------------------------------- proficiency and learning

func test_magic_points_and_separate_cap() -> void:
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 1, 99)
	var d := caster("Mage", 5, [bolt])
	var cs: Array[CompanionData] = [d]
	var b := battle_with(cs, one(enemy_with(0, 9999)))
	var c := b.roster[0]   # alone: ignores recovery
	var before := c.progress.magic_points_in(SpellData.School.BLACK)
	b.cast(c, bolt, b.enemies[0])
	t.eq(c.progress.magic_points_in(SpellData.School.BLACK) - before, BattleConfig.MAGIC_POINTS_PER_CAST, "4 points per cast")
	t.eq(c.progress.magic_points_in(SpellData.School.WHITE), 0, "only the spell's school")
	# The weapon cap is reached first; it must not stop magic.
	for i in 8:
		b.attack(c, b.enemies[0])
	t.eq(c.proficiency_gained, BattleConfig.PROFICIENCY_CAP_PER_BATTLE, "weapon cap reached")
	for i in 10:
		b.cast(c, bolt, b.enemies[0])
	t.eq(c.progress.magic_points_in(SpellData.School.BLACK) - before, BattleConfig.MAGIC_CAP_PER_BATTLE, "magic stops at its own cap")
	t.check(BattleConfig.MAGIC_CAP_PER_BATTLE > 2 * BattleConfig.MAGIC_POINTS_PER_CAST, "more than two casts count")
	t.eq(c.magic_gained, BattleConfig.MAGIC_CAP_PER_BATTLE, "tracked per battle")
	var b2 := Battle.new(cs, one(enemy_with(0, 9999)), t.make_rng(2), [c.progress] as Array[CompanionProgress])
	b2.cast(b2.roster[0], bolt, b2.enemies[0])
	t.eq(b2.roster[0].magic_gained, BattleConfig.MAGIC_POINTS_PER_CAST, "the cap starts again next battle")


## A pool of spells of one school: `per_tier[i]` spells of tier i + 1.
func make_pool(per_tier: Array[int], school: SpellData.School = SpellData.School.WHITE) -> Array[SpellData]:
	var pool: Array[SpellData] = []
	for i in per_tier.size():
		for n in per_tier[i]:
			pool.append(make_spell("T%d-%d" % [i + 1, n], school, i + 1, SpellData.Targeting.ONE_ALLY))
	return pool


func test_spell_learning_odds_duplicates_fall_through() -> void:
	var pool := make_pool([4, 4, 4])
	var p := CompanionProgress.create(caster("Mage", 5, []))
	# Tier odds by grade, as for arts.
	for grade: int in [Proficiency.Grade.D, Proficiency.Grade.C, Proficiency.Grade.B, Proficiency.Grade.S]:
		var counts := [0, 0, 0]
		var rng: RandomNumberGenerator = t.make_rng(grade)
		for i in 4000:
			counts[SpellLearning.pick_spell(rng, p, SpellData.School.WHITE, grade, pool).tier - 1] += 1
		var odds: Array = BattleConfig.ART_TIER_ODDS[grade]
		for k in 3:
			t.check(absf(counts[k] / 40.0 - float(odds[k])) < 3.0, "grade %s tier %d: %.1f%% vs %d%%" % [
				Proficiency.grade_name(grade), k + 1, counts[k] / 40.0, int(odds[k])])
	# Other schools are never picked.
	var black := make_pool([3], SpellData.School.BLACK)
	t.check(SpellLearning.pick_spell(t.make_rng(1), p, SpellData.School.WHITE, 2, black) == null, "no white spell in a black pool")
	# No duplicates: learning every spell one grade-up at a time never repeats.
	var rng2: RandomNumberGenerator = t.make_rng(7)
	var learned := {}
	for i in pool.size():
		var sp := SpellLearning.pick_spell(rng2, p, SpellData.School.WHITE, Proficiency.Grade.S, pool)
		t.check(sp != null and not learned.has(sp), "new spell %d" % i)
		learned[sp] = true
		p.learn_spell(sp)
	t.check(SpellLearning.pick_spell(rng2, p, SpellData.School.WHITE, Proficiency.Grade.S, pool) == null, "nothing once all are known")
	# Fall-through: at D (always tier 1) with every tier 1 known, the nearest tier (2) is taught.
	var p2 := CompanionProgress.create(caster("Mage", 5, []))
	var pool2 := make_pool([2, 2, 1])
	p2.learn_spell(pool2[0])
	p2.learn_spell(pool2[1])
	for s in 30:
		t.eq(SpellLearning.pick_spell(t.make_rng(s), p2, SpellData.School.WHITE, Proficiency.Grade.D, pool2).tier, 2, "falls to tier 2")
	p2.learn_spell(pool2[2])
	p2.learn_spell(pool2[3])
	t.eq(SpellLearning.pick_spell(t.make_rng(1), p2, SpellData.School.WHITE, Proficiency.Grade.D, pool2).tier, 3, "then tier 3")


func test_spell_learned_on_grade_up_in_battle() -> void:
	var pool := make_pool([3, 3, 2], SpellData.School.BLACK)
	var bolt := make_spell("Bolt", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 1, 99)
	var d := caster("Mage", 5, [bolt])
	d.start_grade_black = Proficiency.Grade.D
	var b := battle_with(cs1(d), one(enemy_with(0, 9999)), [], 3, pool)
	var c := b.roster[0]
	t.eq(c.progress.magic_grade(SpellData.School.BLACK), Proficiency.Grade.D, "starts at D")
	var known := c.spells().size()
	# D (11) -> D+ (17): two casts of 4.
	b.cast(c, bolt, b.enemies[0])
	t.eq(b.grade_ups.size(), 0, "no grade-up after one cast")
	b.cast(c, bolt, b.enemies[0])
	t.eq(c.progress.magic_grade(SpellData.School.BLACK), Proficiency.Grade.D_PLUS, "D+ after two casts")
	t.eq(b.grade_ups.size(), 1, "one grade-up recorded")
	var ev: Dictionary = b.grade_ups[0]
	t.check(ev.magic and ev.school == SpellData.School.BLACK and ev.grade == Proficiency.Grade.D_PLUS, "a magic grade-up")
	t.check(ev.spell == null, "nothing learned during the battle")
	t.eq(c.spells().size(), known, "no new spell to cast in this battle")
	b.enemies[0].hp = 0
	b._check_end()
	t.check(ev.spell != null and pool.has(ev.spell), "learned a spell from the pool when the battle ends")
	t.eq(c.spells().size(), known + 1, "the spell is known")
	t.eq(c.progress.uses_left(ev.spell), (ev.spell as SpellData).uses, "with full uses")
	t.eq((ev.spell as SpellData).tier, 1, "D+ teaches tier 1")
	var found := false
	for e in b.events:
		if e.type == "learned" and e.spell == ev.spell:
			found = true
	t.check(found, "a learned event for the screen")
	# A removed caster learns nothing.
	var d2 := caster("Mage", 5, [bolt])
	d2.start_grade_black = Proficiency.Grade.D
	var b2 := battle_with(cs1(d2), one(enemy_with(0, 9999)), [], 3, pool)
	var c2 := b2.roster[0]
	b2.cast(c2, bolt, b2.enemies[0])
	b2.cast(c2, bolt, b2.enemies[0])
	t.eq(b2.grade_ups.size(), 1, "a grade-up")
	var spells2 := c2.progress.known_spells.size()
	c2.hp = 0
	c2.state = CompanionUnit.State.GONE
	b2._check_end()
	t.check(b2.is_over() and b2.grade_ups[0].spell == null, "removed: no spell")
	t.eq(c2.progress.known_spells.size(), spells2, "nothing learned")


# ---------------------------------------------------------------- white magic

func test_heal_amounts() -> void:
	var mend := heal_spell(4)
	var d := caster("Healer", 9, [mend])
	var cs: Array[CompanionData] = [t.make_companion("Hurt", 40), d]
	var b := battle_with(cs, one(enemy_with(0)))
	var hurt := b.roster[0]
	var healer := b.roster[1]
	hurt.hp = 10
	t.eq(b.heal_amount(healer, mend), 13, "MAG 9 + power 4")
	t.eq(b.hp_after_heal(healer, mend, hurt), 23, "preview: 10 -> 23")
	t.check(b.cast(healer, mend, hurt), "cast on an ally")
	t.eq(hurt.hp, 23, "healed by 13")
	var seen := false
	for e in b.events:
		if e.type == "heal" and e.target == hurt and e.amount == 13:
			seen = true
	t.check(seen, "a heal event for playback")
	hurt.hp = 38
	b.roster[1].recovery = 0
	b.cast(healer, mend, hurt)
	t.eq(hurt.hp, 40, "capped at max HP")
	# Always succeeds, whatever the numbers.
	for s in 20:
		var bs := battle_with(cs, one(enemy_with(0)), [], s)
		bs.roster[0].hp = 1
		bs.roster[0].effects.append(StatusEffect.from_data(t.make_effect("Blind", {"LCK": 99, "SPD": 99})))
		bs.cast(bs.roster[1], mend, bs.roster[0])
		t.eq(bs.roster[0].hp, 14, "never misses (seed %d)" % s)
	# Healing yourself.
	healer.hp = 5
	healer.recovery = 0
	t.check(b.cast(healer, mend, healer), "self-heal")
	t.eq(healer.hp, 18, "healed self")


func test_heal_lifts_injured_and_not_gone() -> void:
	var mend := heal_spell(4)
	var cs: Array[CompanionData] = [t.make_companion("A", 30), t.make_companion("B", 30), caster("Healer", 6, [mend])]
	var b := battle_with(cs, one(enemy_with(0)))
	var injured := b.roster[0]
	var gone := b.roster[1]
	var healer := b.roster[2]
	injured.hp = -4
	injured.state = CompanionUnit.State.INJURED
	gone.hp = -8
	gone.state = CompanionUnit.State.GONE
	t.check(b.cast(healer, mend, injured), "an injured companion can be targeted")
	t.eq(injured.hp, 6, "-4 + 10")
	t.check(injured.is_active(), "lifted above 0: no longer injured")
	healer.recovery = 0
	t.check(not b.cast(healer, mend, gone), "a removed companion cannot be targeted")
	t.eq(gone.hp, -8, "no effect on the removed")
	t.check(gone.is_gone(), "still gone")
	var all_heal := heal_spell(4, SpellData.Targeting.ALL_ALLIES)
	healer.progress.learn_spell(all_heal)
	t.check(b.cast(healer, all_heal), "heal everyone")
	t.eq(gone.hp, -8, "every-ally heal skips the removed")
	# Healing to 0 or below keeps the injury.
	var small := heal_spell(0)
	var b2 := battle_with(cs, one(enemy_with(0)), [small])
	b2.roster[0].hp = -10
	b2.roster[0].state = CompanionUnit.State.INJURED
	b2.cast(b2.roster[2], small, b2.roster[0])
	t.eq(b2.roster[0].hp, -4, "-10 + MAG 6")
	t.check(b2.roster[0].is_injured(), "still injured at or below 0")


func test_white_cleanse() -> void:
	var purify := make_spell("Purify", SpellData.School.WHITE, 1, SpellData.Targeting.ONE_ALLY)
	purify.cleanse = true
	var b := battle_with(t.three_companions(), one(enemy_with(0)), [purify])
	var target := b.roster[0]
	target.add_effect(StatusEffect.from_data(t.make_effect("Hexed", {"DEF": -3})))
	target.add_effect(StatusEffect.from_data(t.make_effect("Marked", {}, 3, 1.25)))
	target.add_effect(StatusEffect.from_data(t.make_effect("Blessed", {"STR": 3})))
	t.check(b.cast(b.roster[2], purify, target), "cast")
	t.check(not target.has_effect("Hexed"), "stat debuff removed")
	t.check(not target.has_effect("Marked"), "more-damage-taken removed")
	t.check(target.has_effect("Blessed"), "buffs stay")


func test_white_buffs_and_damage_reduction() -> void:
	var bless := make_spell("Bless", SpellData.School.WHITE, 1, SpellData.Targeting.ONE_ALLY)
	bless.effect = t.make_effect("Blessed", {"STR": 3, "MAG": 2}, 3)
	var ward := make_spell("Ward", SpellData.School.WHITE, 1, SpellData.Targeting.ONE_ALLY)
	ward.effect = t.make_effect("Warded", {}, 3, 0.5)
	# The enemy hits everyone for STR 10 + Mt 10 = 20 every 2 ticks.
	var acts: Array[EnemyActionData] = [t.make_action("Sweep", 2, EnemyActionData.Targeting.ALL_COMPANIONS, 10)]
	var cs: Array[CompanionData] = [t.make_companion("A", 100), t.make_companion("B", 100), t.make_companion("C", 100)]
	var b := battle_with(cs, one(t.make_enemy("E", acts)), [bless, ward])
	var a := b.roster[0]
	var str_before := a.stat(Stat.STR)
	t.check(b.cast(b.roster[2], bless, a), "bless")
	t.eq(a.stat(Stat.STR), str_before + 3, "STR +3")
	t.check(b.cast(b.roster[1], ward, a), "ward (the enemy acts this tick)")
	t.eq(a.hp, 90, "warded: 20 x 0.5")
	t.eq(b.roster[1].hp, 80, "unwarded: 20")


func test_white_veil_and_beacon() -> void:
	var veil := make_spell("Veil", SpellData.School.WHITE, 1, SpellData.Targeting.ONE_ALLY)
	veil.effect = t.make_effect("Veiled", {}, 3)
	veil.effect.target_weight_mult = 0.25
	var beacon := make_spell("Beacon", SpellData.School.WHITE, 2, SpellData.Targeting.ONE_ALLY)
	beacon.effect = t.make_effect("Beacon", {}, 3)
	beacon.effect.target_weight_mult = 3.0
	var b := battle_with(t.three_companions(), one(enemy_with(0)), [veil, beacon])
	t.eq(b.target_weights(), [1.0, 2.0, 4.0] as Array[float], "base weights")
	b.cast(b.roster[1], veil, b.roster[2])
	t.eq(b.target_weights(), [1.0, 2.0, 1.0] as Array[float], "veil: the front x0.25")
	b.cast(b.roster[0], beacon, b.roster[0])
	t.eq(b.target_weights(), [3.0, 2.0, 1.0] as Array[float], "beacon: the back x3")
	t.check(veil.effect_summary().contains("less likely"), "veil described: %s" % veil.effect_summary())
	t.check(beacon.effect_summary().contains("as likely"), "beacon described: %s" % beacon.effect_summary())


func test_white_every_ally() -> void:
	var rally := make_spell("Rally", SpellData.School.WHITE, 2, SpellData.Targeting.ALL_ALLIES)
	rally.effect = t.make_effect("Rallied", {"DEX": 2}, 3)
	var b := battle_with(t.three_companions(), one(enemy_with(0)), [rally])
	b.roster[0].state = CompanionUnit.State.GONE
	t.check(b.cast(b.roster[2], rally), "no target needed")
	t.check(not b.roster[0].has_effect("Rallied"), "not the removed")
	t.check(b.roster[1].has_effect("Rallied") and b.roster[2].has_effect("Rallied"), "everyone in the line")
	t.check(not b.cast(b.roster[1], make_spell("Unknown", SpellData.School.WHITE)), "unknown spells cannot be cast")


# ---------------------------------------------------------------- black magic

func test_black_every_enemy_ignore_res_and_debuff() -> void:
	var storm := make_spell("Storm", SpellData.School.BLACK, 2, SpellData.Targeting.ALL_ENEMIES, 4)
	storm.effect = t.make_effect("Dazed", {"DEX": -3}, 3)
	var d := caster("Mage", 10, [storm])
	var es: Array[EnemyData] = [enemy_with(4), enemy_with(4), enemy_with(4)]
	var b := battle_with(cs1(d), es)
	t.check(b.cast(b.roster[0], storm), "no target needed")
	for e in b.enemies:
		t.eq(e.hp, 200 - 10, "every enemy: 10 + 4 - 4")
		t.check(e.has_effect("Dazed"), "debuffed")
	var lance := make_spell("Lance", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 4)
	lance.ignore_res_percent = 50
	var b2 := battle_with(cs1(d), one(enemy_with(9)))
	t.eq(b2.spell_forecast(b2.roster[0], lance, b2.enemies[0]).damage, 10 + 4 - 4, "half of RES 9 ignored (4 left)")
	# A miss applies nothing.
	var miss := make_spell("Miss", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 4)
	miss.hit = -500
	miss.effect = storm.effect
	var landed_debuff := 0
	for s in 60:
		var bs := battle_with(cs1(d), one(enemy_with(0)), [miss], s)
		bs.cast(bs.roster[0], miss, bs.enemies[0])
		if bs.enemies[0].hp == 200 and bs.enemies[0].has_effect("Dazed"):
			landed_debuff += 1
	t.eq(landed_debuff, 0, "a missed spell does not debuff")


func test_countdown_delay_once_per_action() -> void:
	var stasis := make_spell("Stasis", SpellData.School.BLACK, 2, SpellData.Targeting.ONE_ENEMY, 1)
	stasis.delay_ticks = 2
	var acts: Array[EnemyActionData] = [t.make_action("Slow Hit", 3, EnemyActionData.Targeting.SINGLE, 1)]
	var cs: Array[CompanionData] = [t.make_companion("A", 500), t.make_companion("B", 500), t.make_companion("C", 500)]
	var b := battle_with(cs, one(t.make_enemy("E", acts, 999)), [stasis])
	var e := b.enemies[0]
	t.eq(e.countdown, 3, "starts at 3")
	t.check(b.cast(b.roster[2], stasis, e), "cast")
	t.eq(e.countdown, 3 + 2 - 1, "delayed by 2, then the tick")
	t.check(e.delayed, "marked as delayed")
	var delay_events := b.events.filter(func(ev: Dictionary) -> bool: return ev.type == "delay")
	t.eq(delay_events.size(), 1, "a delay event for playback")
	t.check(b.cast(b.roster[1], stasis, e), "cast again on the same pending action")
	t.eq(e.countdown, 3, "not delayed again: only the tick")
	t.check(b.events.any(func(ev: Dictionary) -> bool: return ev.type == "delay_blocked"), "says it was already delayed")
	# Let the enemy act; its next action can be delayed again.
	var guard := 0
	while e.countdown > 0 and guard < 10:
		guard += 1
		var ready := b.ready_companions()
		if ready.is_empty():
			b.wait()
		else:
			b.guard(ready[0])
		if not e.delayed:
			break
	t.check(not e.delayed, "after acting and picking a new action, the mark is gone")
	var before := e.countdown
	var actor := b.ready_companions()[0] if not b.ready_companions().is_empty() else null
	if actor == null:
		b.wait()
		actor = b.ready_companions()[0]
		before = e.countdown
	t.check(b.cast(actor, stasis, e), "cast on the new action")
	t.eq(e.countdown, before + 2 - 1, "the new action is delayed")
	# No delay on a miss (accuracy never drops below 20%, so look at the casts that missed).
	var miss := make_spell("Miss", SpellData.School.BLACK, 2, SpellData.Targeting.ONE_ENEMY, 1)
	miss.hit = -500
	miss.delay_ticks = 2
	var missed := 0
	for s in 30:
		var b2 := battle_with(cs, one(t.make_enemy("E", acts, 999)), [miss], s)
		b2.cast(b2.roster[2], miss, b2.enemies[0])
		if b2.enemies[0].hp == 999:
			missed += 1
			t.eq(b2.enemies[0].countdown, 2, "a miss does not delay")
		else:
			t.eq(b2.enemies[0].countdown, 4, "a hit delays")
	t.check(missed > 10, "most of them missed (%d)" % missed)


func test_no_art_can_delay() -> void:
	var lib := ArtLibrary.load_default()
	var arts: Array[CombatArtData] = lib.arts.duplicate()
	for n: String in ["elena", "aina", "erik", "ingrid", "yuzu"]:
		arts.append(companion(n).signature_art)
	var props := []
	for p in CombatArtData.new().get_property_list():
		props.append(p.name)
	t.check(not props.has("delay_ticks"), "combat arts have no delay field")
	for art in arts:
		var acts: Array[EnemyActionData] = [t.make_action("Slow", 50)]
		var es: Array[EnemyData] = [t.make_enemy("E1", acts, 9999), t.make_enemy("E2", acts, 9999)]
		var d: CompanionData = t.make_companion("User", 100, 0, t.make_weapon(5, 999, 0, art.weapon_type))
		var b: Battle = t.make_battle(cs1(d), es)
		t.give_art(b.roster[0], art)
		b.roster[0].stamina = 99
		t.check(b.use_art(b.roster[0], art, b.enemies[0]), "%s used" % art.display_name)
		for e in b.enemies:
			t.eq(e.countdown, 49, "%s: countdown only drops by the tick" % art.display_name)
			t.check(not e.delayed, "%s: never marks a delay" % art.display_name)


# ---------------------------------------------------------------- enemy magic, magic weapons

func test_enemy_magic_uses_res_and_guard_halves() -> void:
	var bolt: EnemyActionData = t.make_action("Bolt", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 6)
	bolt.damage_type = CombatMath.DamageType.MAGIC
	var acts: Array[EnemyActionData] = [bolt]
	var e: EnemyData = t.make_enemy("Wizard", acts, 500)
	e.magic = 12
	e.strength = 50   # STR must not matter
	var a: CompanionData = t.make_companion("A", 100, 30)   # DEF 30 must not matter
	a.resistance = 4
	var g: CompanionData = t.make_companion("G", 100, 30)
	g.resistance = 4
	var cs: Array[CompanionData] = [a, g]
	var b: Battle = t.make_battle(cs, one(e))
	b.guard(b.roster[1])
	t.eq(b.roster[0].hp, 100 - 14, "MAG 12 + Mt 6 - RES 4")
	t.eq(b.roster[1].hp, 100 - 7, "Guard halves magic too")
	var phys: EnemyActionData = t.make_action("Club", 1, EnemyActionData.Targeting.ALL_COMPANIONS, 6)
	var acts2: Array[EnemyActionData] = [phys]
	var e2: EnemyData = t.make_enemy("Brute", acts2, 500)
	e2.magic = 50
	var cs2: Array[CompanionData] = [t.make_companion("A", 100, 3)]
	cs2[0].resistance = 99
	var b2: Battle = t.make_battle(cs2, one(e2))
	b2.focus(b2.roster[0])
	t.eq(b2.roster[0].hp, 100 - 13, "physical still STR 10 + 6 - DEF 3")
	var wiz: EnemyData = load("res://data/enemies/goblin_wizard.tres")
	for act in wiz.actions:
		if act.deals_damage:
			t.eq(act.damage_type, CombatMath.DamageType.MAGIC, "Goblin Wizard's %s is magic" % act.display_name)
	t.check(wiz.magic > 0, "the wizard has MAG")
	var wyvern: EnemyData = load("res://data/enemies/bosses/rimeclaw_wyvern.tres")
	for act in wyvern.actions:
		if act.display_name in ["Frost Lance", "Blizzard"]:
			t.eq(act.damage_type, CombatMath.DamageType.MAGIC, "%s is magic" % act.display_name)
	t.check(wyvern.magic > 0, "the Wyvern has MAG")
	var oath: EnemyData = load("res://data/enemies/bosses/oathbreaker.tres")
	for act in oath.actions:
		if act.display_name == "Black Tide":
			t.eq(act.damage_type, CombatMath.DamageType.MAGIC, "Black Tide is magic")
	t.eq(Run.scaled_enemy(wiz, 12).magic, wiz.magic + 2, "MAG grows with the day like STR")
	t.eq(Run.scaled_enemy(wiz, 12).magic - wiz.magic, Run.scaled_enemy(wiz, 12).strength - wiz.strength, "by the same amount")


func test_magic_weapon_uses_mag_and_res() -> void:
	var w: WeaponData = t.make_weapon(6, 999)
	w.damage_type = CombatMath.DamageType.MAGIC
	var d: CompanionData = t.make_companion("Mage", 50, 0, w)
	d.strength = 40
	d.magic = 9
	var e := enemy_with(5)
	e.defense = 30
	var b: Battle = t.make_battle(cs1(d), one(e))
	var c := b.roster[0]
	var f := b.forecast(c, b.enemies[0])
	t.eq(f.damage, 9 + 6 - 5, "attack: MAG + Mt - RES")
	t.check(f.magic, "marked magic")
	var art: CombatArtData = t.make_art("Art", 1, 1, 1, 3)
	art.ignore_def_percent = 100
	t.give_art(c, art)
	var fa := b.forecast(c, b.enemies[0], art)
	t.eq(fa.damage, 9 + 6 + 3 - 0, "an art with a magic weapon: MAG, and its ignore applies to RES")
	t.check(b.attack(c, b.enemies[0]), "attack")
	t.eq(b.enemies[0].hp, 200 - 10, "dealt 10")
	t.eq(c.proficiency_gained, 1, "still weapon proficiency")
	for path: String in ["whisper_fang", "emberglass_sword", "moonthread_bow", "stormcall_pike"]:
		var mw: WeaponData = load("res://data/weapons/%s.tres" % path)
		t.check(mw.is_magic(), "%s is magic" % mw.display_name)


# ---------------------------------------------------------------- effectiveness

func flyer(res: int = 0) -> EnemyData:
	var e := enemy_with(res, 500, ["Flying"] as Array[String])
	e.defense = 3
	return e


func test_effective_weapon_adds_half() -> void:
	var bow: WeaponData = t.make_weapon(5, 999, 0, WeaponData.WeaponType.BOW)
	bow.effective_against = ["Flying"] as Array[String]
	var d: CompanionData = t.make_companion("Archer", 50, 0, bow)
	d.strength = 7
	var b: Battle = t.make_battle(cs1(d), one(flyer()))
	var f := b.forecast(b.roster[0], b.enemies[0])
	t.check(f.effective, "effective")
	# Bow: (STR 7 + DEX 10) / 2 = 8; 8 + Mt 5 - DEF 3 = 10; effective: + 10 / 2 = 15.
	t.eq(f.damage, 15, "half as much again after DEF")
	t.eq(f.crit_damage, 30, "a critical doubles the effective damage")
	t.check(b.attack(b.roster[0], b.enemies[0]), "attack")
	t.eq(b.enemies[0].hp, 500 - 15, "dealt 15")
	t.check(b.events.any(func(ev: Dictionary) -> bool: return ev.type == "damage" and ev.get("effective", false)), "the damage event says effective")
	for path: String in ["wooden_bow", "bronze_bow", "iron_bow", "steel_bow", "silver_bow", "platinum_bow", "moonthread_bow"]:
		var w: WeaponData = load("res://data/weapons/%s.tres" % path)
		t.check(w.effective_against.has(EnemyTraits.FLYING), "%s is effective against flying" % w.display_name)


func test_effective_art_and_no_stacking() -> void:
	var sword: WeaponData = t.make_weapon(6, 999)
	var d: CompanionData = t.make_companion("Blade", 50, 0, sword)
	d.strength = 10
	var art: CombatArtData = t.make_art("Wing Cut", 1, 1, 1, 2)
	art.effective_against = ["Flying"] as Array[String]
	var b: Battle = t.make_battle(cs1(d), one(flyer()))
	var c := b.roster[0]
	t.give_art(c, art)
	var f := b.forecast(c, b.enemies[0], art)
	t.check(f.effective, "an art can be effective")
	# 10 + 6 + 2 - 3 = 15, and half of it (7, rounded down) again.
	t.eq(f.damage, 15 + 7, "the art's strike deals half as much again")
	# Both the weapon and the art effective: still only once.
	sword.effective_against = ["Flying"] as Array[String]
	t.eq(b.forecast(c, b.enemies[0], art).damage, 15 + 7, "does not stack")
	t.eq(b.forecast(c, b.enemies[0]).damage, 13 + 6, "attack with the effective weapon")


func test_effective_spell() -> void:
	var cutter := make_spell("Cutter", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 3)
	cutter.effective_against = ["Flying"] as Array[String]
	var d := caster("Mage", 10, [cutter])
	var b := battle_with(cs1(d), one(flyer(2)))
	var f := b.spell_forecast(b.roster[0], cutter, b.enemies[0])
	t.check(f.effective, "effective")
	t.eq(f.damage, 11 + 5, "the spell deals half as much again after RES (11 + 5)")
	t.eq(f.crit_damage, 32, "then a critical doubles it")


func test_no_effectiveness_without_trait() -> void:
	var bow: WeaponData = t.make_weapon(5, 999, 0, WeaponData.WeaponType.BOW)
	bow.effective_against = ["Flying"] as Array[String]
	var d: CompanionData = t.make_companion("Archer", 50, 0, bow)
	d.strength = 7
	var ground := enemy_with(0)
	ground.defense = 3
	var b: Battle = t.make_battle(cs1(d), one(ground))
	var f := b.forecast(b.roster[0], b.enemies[0])
	t.check(not f.effective, "not effective on the ground")
	t.eq(f.damage, (7 + 10) / 2 + 5 - 3, "a bow: (STR + DEX) / 2 + Mt - DEF, nothing added")
	var plain: WeaponData = t.make_weapon(5, 999)
	var d2: CompanionData = t.make_companion("Blade", 50, 0, plain)
	d2.strength = 7
	var b2: Battle = t.make_battle(cs1(d2), one(flyer()))
	t.check(not b2.forecast(b2.roster[0], b2.enemies[0]).effective, "a sword is not effective against flying")
	var cutter := make_spell("Cutter", SpellData.School.BLACK, 1, SpellData.Targeting.ONE_ENEMY, 3)
	cutter.effective_against = ["Flying"] as Array[String]
	var b3 := battle_with(cs1(caster("Mage", 10, [cutter])), one(enemy_with(2)))
	t.eq(b3.spell_forecast(b3.roster[0], cutter, b3.enemies[0]).damage, 10 + 3 - 2, "spell not effective without the trait")


# ---------------------------------------------------------------- the mages in a run

func test_first_two_never_both_mages() -> void:
	var mages_seen := 0
	var starters := {}
	for s in 400:
		var run := make_run(s)
		t.eq(run.roster.size(), 2, "two starters")
		var both := run.roster[0].data.is_mage() and run.roster[1].data.is_mage()
		t.check(not both, "seed %d: never two mages" % s)
		for c in run.roster:
			starters[c.display_name()] = true
			if c.data.is_mage():
				mages_seen += 1
	t.check(mages_seen > 0, "a mage can start a run (%d of 800 starters)" % mages_seen)
	t.check(starters.has("Aveline") and starters.has("Freya"), "both mages can start")


func test_mages_in_run() -> void:
	var offered := {}
	for s in 120:
		var run := make_run(s)
		run.calendar[0] = RunCalendar.DayType.FREE
		run._begin_day()
		for d in run.tavern_offers:
			offered[d.display_name] = true
	t.check(offered.has("Aveline") and offered.has("Freya"), "mages are offered at the tavern")
	var run := make_run(5)
	var freya := run._join(companion("freya"))
	run.lineup.clear()
	run.lineup.append(freya)
	var b := run.start_battle(run.fronts[0])
	t.eq(b.spell_pool, run.spell_pool, "the run's battles can teach spells")
	var unit := b.roster[0]
	t.check(unit.spells().has(companion("freya").signature_spell), "Freya brings her signature spell")
	t.eq(unit.progress.magic_grade(SpellData.School.BLACK), Proficiency.Grade.D, "at grade D")


## Healing spells are cast only in battle. Between battles the daily heal and Rest are how the company
## recovers, and a healer's uses are not touched.
func test_healing_only_in_battle() -> void:
	var run := make_run(11)
	for m in ["cast_heal", "heal_block_reason", "heal_targets", "heal_amount"]:
		t.check(not run.has_method(m), "Run has no %s: no spell is cast between battles" % m)
	var aveline := run._join(companion("aveline"))
	var mend := aveline.data.signature_spell
	var hurt := run.roster[0]
	run.calendar[run.day - 1] = RunCalendar.DayType.FREE
	run.event_days.erase(run.day)
	hurt.hp = 3
	t.check(run.end_free_day(), "a free day ends")
	t.eq(hurt.hp, mini(hurt.max_hp(), 3 + ceili(hurt.max_hp() * RunConfig.DAILY_HEAL_FRACTION)), "only the daily heal")
	t.eq(aveline.progress.uses_left(mend), mend.uses, "the healer's uses are untouched")


# ---------------------------------------------------------------- the spells added for twelve per school

func load_spell(path: String) -> SpellData:
	return load("res://data/spells/%s.tres" % path) as SpellData


## Thornward on an ally works like an art's reflecting stance: an enemy's physical blow that lands on
## them hurts the enemy for 40% of it, the enemy can die of it, and the kill is the bearer's.
func test_thornward_reflects_like_a_stance() -> void:
	var thorn := load_spell("white/thornward")
	t.eq([thorn.school, thorn.tier, thorn.targeting, thorn.uses, thorn.recovery],
		[SpellData.School.WHITE, 2, SpellData.Targeting.ONE_ALLY, 4, 2], "Thornward: white, tier 2, one ally, 4 uses, recovery 2")
	t.eq([thorn.effect.display_name, thorn.effect.reflect_percent, int(thorn.effect.stat_mods.get(Stat.DEF, 0)), thorn.effect.duration_ticks],
		["Thornward", 40, 2, 3], "reflects 40%, DEF +2, 3 turns")
	# The brute hits everyone, left to right, for STR 10 + Mt 20 every turn.
	var a: CompanionData = t.make_companion("A", 100)
	var mage := caster("Mage", 10, [thorn], 100)
	var cs: Array[CompanionData] = [a, mage]
	var b := battle_with(cs, one(t.brute(1000, EnemyActionData.Targeting.ALL_COMPANIONS)), [thorn])
	var bearer := b.roster[0]
	var e := b.enemies[0]
	t.check(b.cast(b.roster[1], thorn, bearer), "Thornward cast on A")
	t.eq(bearer.stat(Stat.DEF), 2, "DEF +2")
	t.eq(bearer.hp, 100 - 28, "the blow lands, less 2 for the DEF")
	t.eq(e.hp, 1000 - 11, "40% of 28 comes back")
	t.eq(t.count_events(b, "riposte"), 1, "a riposte event for playback")
	t.check(t.log_has(b, "A's Thornward strikes back at Brute!"), "the log names the ward")
	# Magic is never reflected.
	var hexer: EnemyData = t.brute(1000, EnemyActionData.Targeting.ALL_COMPANIONS)
	hexer.actions[0].damage_type = CombatMath.DamageType.MAGIC
	var b2 := battle_with(cs, one(hexer), [thorn])
	b2.cast(b2.roster[1], thorn, b2.roster[0])
	t.eq(b2.enemies[0].hp, 1000, "a magic blow is not reflected")
	# The reflection can kill, and the kill belongs to whoever carries the ward.
	var b3 := battle_with(cs, one(t.brute(11, EnemyActionData.Targeting.ALL_COMPANIONS)), [thorn])
	b3.cast(b3.roster[1], thorn, b3.roster[0])
	t.check(not b3.enemies[0].is_alive(), "struck down by its own blow")
	t.eq(b3.outcome, Battle.Outcome.VICTORY, "and the battle is won")
	t.eq(b3.kills_of(b3.roster[0]), 1, "the kill is the bearer's")
	t.eq(b3.points_of(b3.roster[0]), BattleConfig.POINTS_BLOW_TAKEN + BattleConfig.POINTS_KILL, "bearer: the blow taken and the kill")
	t.eq(b3.points_of(b3.roster[1]), BattleConfig.POINTS_SPELL, "caster: the spell only (never reached)")


## Blight: a black spell whose damage over time can kill; the kill is the caster's even when it happens
## on someone else's turn.
func test_blight_kills_and_credits_the_caster() -> void:
	var blight := load_spell("black/blight")
	t.eq([blight.school, blight.tier, blight.targeting, blight.uses, blight.recovery, blight.might, blight.hit],
		[SpellData.School.BLACK, 2, SpellData.Targeting.ONE_ENEMY, 4, 2, 3, 90], "Blight: black, tier 2, one enemy, 4 uses, recovery 2, Mt 3, Hit 90")
	t.eq([blight.effect.display_name, blight.effect.damage_per_tick, blight.effect.duration_ticks], ["Blighted", 4, 4], "Blighted: 4 a turn for 4 turns")
	var a: CompanionData = t.make_companion("A", 100)
	var mage := caster("Mage", 10, [blight], 100)
	var cs: Array[CompanionData] = [a, mage]
	# MAG 10 + Mt 3 = 13 on the cast, then 4 at the end of the turn: 17. One more turn of it kills.
	var b := battle_with(cs, one(enemy_with(0, 18)), [blight])
	var e := b.enemies[0]
	t.check(b.cast(b.roster[1], blight, e), "Blight cast")
	t.eq(e.hp, 18 - 13 - 4, "13 from the spell, 4 from the blight")
	t.check(t.log_has(b, "Dummy loses 4 HP to Blighted"), "the log names the blight")
	t.check(b.guard(b.roster[0]), "A guards")
	t.check(not e.is_alive(), "the blight kills")
	t.eq(b.outcome, Battle.Outcome.VICTORY, "and the battle is won")
	t.eq(b.kills_of(b.roster[1]), 1, "the kill is the caster's")
	t.eq(b.kills_of(b.roster[0]), 0, "not the one who acted when it fell")
	t.eq(b.points_of(b.roster[1]), BattleConfig.POINTS_SPELL + BattleConfig.POINTS_KILL, "caster: the spell and the kill")
	t.eq(b.points_of(b.roster[0]), 0, "Guard alone earns nothing")


## Sanctuary heals and cleanses every ally in the line at once; buffs stay.
func test_sanctuary_heals_and_cleanses_everyone() -> void:
	var sanctuary := load_spell("white/sanctuary")
	t.eq([sanctuary.school, sanctuary.tier, sanctuary.targeting, sanctuary.uses, sanctuary.recovery, sanctuary.heals, sanctuary.heal_power, sanctuary.cleanse],
		[SpellData.School.WHITE, 3, SpellData.Targeting.ALL_ALLIES, 2, 3, true, 3, true], "Sanctuary: white, tier 3, every ally, 2 uses, recovery 3, heals MAG + 3, cleanses")
	var cs: Array[CompanionData] = [t.make_companion("A", 50), t.make_companion("B", 50), caster("Mage", 9, [sanctuary], 50)]
	var b := battle_with(cs, one(enemy_with(0)), [sanctuary])
	for c in b.roster:
		c.hp = 10
		c.add_effect(StatusEffect.from_data(t.make_effect("Hexed", {"DEF": -3})))
		var poison: StatusEffectData = t.make_effect("Poison", {})
		poison.damage_per_tick = 3
		c.add_effect(StatusEffect.from_data(poison))
		c.add_effect(StatusEffect.from_data(t.make_effect("Blessed", {"STR": 3})))
	t.check(b.cast(b.roster[2], sanctuary), "no target needed")
	for c in b.roster:
		t.eq(c.hp, 10 + 9 + 3, "%s healed by MAG 9 + 3, and no poison afterwards" % c.display_name)
		t.check(not c.has_effect("Hexed") and not c.has_effect("Poison"), "%s cleansed" % c.display_name)
		t.check(c.has_effect("Blessed"), "%s keeps the buff" % c.display_name)
	t.eq(t.count_events(b, "cleanse"), 3, "one cleanse per ally")


## Entomb: tier 3, Mt 8, and a delay of 3 turns, once per pending action like every delay.
func test_entomb_delays_once() -> void:
	var entomb := load_spell("black/entomb")
	t.eq([entomb.school, entomb.tier, entomb.targeting, entomb.uses, entomb.recovery, entomb.might, entomb.hit, entomb.delay_ticks],
		[SpellData.School.BLACK, 3, SpellData.Targeting.ONE_ENEMY, 2, 3, 8, 90, 3], "Entomb: black, tier 3, one enemy, 2 uses, recovery 3, Mt 8, Hit 90, delay 3")
	var acts: Array[EnemyActionData] = [t.make_action("Slam", 6)]
	var foe: EnemyData = t.make_enemy("Foe", acts, 500)
	foe.resistance = 0
	var cs: Array[CompanionData] = [caster("A", 10, [entomb], 100), caster("B", 10, [entomb], 100)]
	var b := battle_with(cs, one(foe), [entomb])
	var e := b.enemies[0]
	t.check(b.cast(b.roster[0], entomb, e), "Entomb cast")
	t.eq(e.hp, 500 - 18, "MAG 10 + Mt 8")
	t.eq(e.countdown, 6 + 3 - 1, "pushed back 3, then the turn passes")
	t.check(b.cast(b.roster[1], entomb, e), "a second Entomb")
	t.eq(e.countdown, 6 + 3 - 2, "the same action cannot be delayed twice")


func test_rare_shop_stock() -> void:
	var rare := 0
	var weeks := 0
	var early_rare := 0
	for s in 300:
		var run := make_run(2000 + s)
		# Week 1's stock was rolled on day 1.
		for item in run.shop_stock():
			if (item.weapon.is_magic() and not item.weapon.has_second_requirement()):
				early_rare += 1
		run.day = 8
		run._begin_day()
		weeks += 1
		for item in run.shop_stock():
			if (item.weapon.is_magic() and not item.weapon.has_second_requirement()):
				rare += 1
	t.eq(early_rare, 0, "no magic weapons in the first week's smithy")
	var per_week := float(rare) / weeks
	t.check(per_week > 0.2 and per_week < 1.2, "rare from week 2: %.2f magic weapons per week" % per_week)
	var run2 := make_run(4)
	t.eq(run2.day_type(), RunCalendar.DayType.BATTLE, "day 1 is a battle")
	t.check(not run2.shop_stock().is_empty(), "the week's stock is there on a battle day")
	run2.gold = 1000
	t.eq(run2.buy_block_reason(run2.shop_stock()[0]), "Only on free days.", "but it is only sold on free days")
	var hermit_has_weapon := false
	for ev in RunContent.load_default().events:
		for ch in ev.choices:
			if ch.weapon != null and ch.weapon.is_magic():
				hermit_has_weapon = true
	t.check(hermit_has_weapon, "an event can give a magic weapon")


# ---------------------------------------------------------------- content

func test_magic_content() -> void:
	var lib := SpellLibrary.load_default()
	t.check(lib != null and not lib.spells.is_empty(), "spell library loads")
	var aveline := companion("aveline")
	var freya := companion("freya")
	for school: int in SpellData.School.values():
		var tiers := {1: 0, 2: 0, 3: 0}
		for sp in lib.of_school(school):
			tiers[sp.tier] += 1
			t.check(sp.description != "", "%s has a description" % sp.display_name)
			t.check(sp.targets_allies() == (school == SpellData.School.WHITE), "%s aims at the right side" % sp.display_name)
			var expected: int = [6, 4, 2][sp.tier - 1]
			t.check(sp.uses >= expected - 1 and sp.uses <= expected, "%s: %d uses for tier %d" % [sp.display_name, sp.uses, sp.tier])
		t.eq(lib.of_school(school).size(), 12, "%s: twelve spells" % SpellData.school_name(school))
		t.eq([tiers[1], tiers[2], tiers[3]], [5, 4, 3], "%s: 5 / 4 / 3 by tier" % SpellData.school_name(school))
	var names := {}
	for sp in lib.spells:
		t.check(not names.has(sp.display_name), "%s listed once" % sp.display_name)
		names[sp.display_name] = true
	for n in ["Thornward", "Sanctuary", "Blight", "Entomb"]:
		t.check(names.has(n), "%s is in the library" % n)
	# A mage's signature is simply the spell they start with: every one is in the library, so the other
	# mage of that school can learn it.
	for n in ["aveline", "elio", "freya", "sylas"]:
		var d := companion(n)
		t.check(d.signature_spell != null and lib.spells.has(d.signature_spell), "%s's signature spell %s is in the library" % [d.display_name, d.signature_spell.display_name])
	var other := CompanionProgress.create(companion("elio"))
	t.check(SpellLearning.unknown_spells(other, SpellData.School.WHITE, lib.spells).has(aveline.signature_spell),
		"Elio can learn Aveline's Mend")
	t.check(not SpellLearning.unknown_spells(CompanionProgress.create(aveline), SpellData.School.WHITE, lib.spells).has(aveline.signature_spell),
		"Aveline already knows it")
	var delay_ok := false
	var veil_or_beacon := false
	var cleanse := false
	for sp in lib.spells:
		if sp.delay_ticks > 0:
			t.check(sp.tier >= 2 and sp.uses <= 3, "%s: delay at tier 2-3 with few uses" % sp.display_name)
			delay_ok = true
		if sp.effect != null and sp.effect.target_weight_mult != 1.0 and sp.school == SpellData.School.WHITE:
			veil_or_beacon = true
		if sp.cleanse:
			cleanse = true
	t.check(delay_ok and veil_or_beacon and cleanse, "a delay spell, a veil or beacon, a cleanse")
	# The mages.
	t.eq(aveline.signature_spell.school, SpellData.School.WHITE, "Aveline is a white mage")
	t.eq(freya.signature_spell.school, SpellData.School.BLACK, "Freya is a black mage")
	t.eq(aveline.weapon.weapon_type, WeaponData.WeaponType.SWORD, "Aveline holds a sword")
	t.eq(freya.weapon.weapon_type, WeaponData.WeaponType.DAGGER, "Freya holds a dagger")
	for d in [aveline, freya]:
		var s: SpellData.School = d.signature_spell.school
		t.eq(d.starting_magic_grade(s), Proficiency.Grade.D, "%s starts at D" % d.display_name)
		t.check(d.starting_grade(d.weapon.weapon_type) <= Proficiency.Grade.E_PLUS, "%s: low weapon grade" % d.display_name)
		t.check(d.magic >= 8 and d.resistance >= 7 and d.strength <= 4 and d.defense <= 3, "%s: a caster's stats" % d.display_name)
		var total := 0
		for key in Levels.GROWTH_STATS:
			total += Levels.growth_rate(d, key)
		var avg := total / float(Levels.GROWTH_STATS.size())
		t.check(avg >= 37.0 and avg <= 43.0, "%s: growths average about 40%% (%.1f)" % [d.display_name, avg])
		t.check(Levels.growth_rate(d, Stat.MAG) >= 60 and Levels.growth_rate(d, Stat.STR) <= 20, "%s grows as a caster" % d.display_name)
		var p := CompanionProgress.create(d)
		t.check(p.knows_spell(d.signature_spell) and p.uses_left(d.signature_spell) == d.signature_spell.uses, "%s knows the signature spell" % d.display_name)
		t.check(p.can_equip_weapon(d.weapon), "%s can hold their weapon" % d.display_name)
	# Flying enemies in the early pool.
	var rc := RunContent.load_default()
	var early_flyers := {}
	for g in rc.groups:
		if g.min_day <= 3:
			for e in g.enemies:
				if e.traits.has(EnemyTraits.FLYING):
					early_flyers[e.display_name] = true
	t.check(early_flyers.has("Skeleton Bird") and early_flyers.has("Winged Zombie"), "both flyers fight early: %s" % str(early_flyers.keys()))
