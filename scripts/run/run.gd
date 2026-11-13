class_name Run
extends RefCounted
## A run: forty-two days (six weeks) of defending the last city. Plain class, no nodes or UI; every
## random choice comes from the injected generator, so the same seed and the same choices give the
## same run.
##
## A day:
##   1. begins: the day's activity is prepared (fronts, the boss, or the free-day action and maybe an
##      event); on the first day of a week the tavern and the smithy restock and drills are posted
##   2. the player may change the party freely (who is fielded, their order, weapons, arts)
##   3. the player commits to the activity: a battle, or on a free day the event's choice first (if the
##      day has one), then the free-day action, then End day
##   4. ends: every surviving companion heals 20% of max HP, the run checks for its end, the next day begins
##
## Commands return false (or "") and change nothing when not allowed; the *_block_reason queries say why.

enum Outcome { ONGOING, VICTORY, DEFEAT }
enum FreeAction { REST, SHOP, TAVERN, REPAIR, TRAIN }

const FREE_ACTION_NAMES: Array[String] = ["Rest", "Shop", "Tavern", "Repair", "Train"]

var rng: RandomNumberGenerator
var content: RunContent
var art_pool: Array[CombatArtData] = []
var spell_pool: Array[SpellData] = []

## 1-based. After the run ends it stays on the last day played.
var day: int = 1
## Day types (RunCalendar.DayType) for days 1..RunConfig.DAYS; index 0 is day 1.
var calendar: Array[int] = []
## The free days that begin with an event, drawn when the run began (RunCalendar.pick_event_days).
var event_days: Array[int] = []
var city_health: int = RunConfig.CITY_MAX_HEALTH
var gold: int = 0
## Material id -> amount.
var materials: Dictionary = {}
## Companions still in the run (fielded and reserve), in the order they joined.
var roster: Array[RunCompanion] = []
## The fielded companions, left to right; the rightmost stands nearest the enemies.
var lineup: Array[RunCompanion] = []
## Companions removed in battle; they never come back.
var gone: Array[CompanionData] = []
var inventory := RunInventory.new()
var outcome: Outcome = Outcome.ONGOING
var end_reason: String = ""
var battles_won: int = 0
var battles_lost: int = 0

# --- Today's pending choice ---
## Battle and boss days: the fronts to choose from (one on a boss day).
var fronts: Array[Front] = []
## The front chosen today; set while its battle is being fought.
var committed_front: Front
## Free days that begin with an event: the event waiting for an answer. Null once it is answered.
var event: EventData
## Free days.
var actions_left: int = 0
var actions_used: Array[int] = []
## Who the tavern offers this week. Rolled on the first day of each week; a hire leaves the list.
var tavern_offers: Array[CompanionData] = []
## What the smithy sells this week: RunConfig.SHOP_WEAPONS_PER_WEEK ladder weapons whose tiers climb
## with the week, plus rare magic ones that rolled in (first). Rolled on the first day of each week; a
## bought item is gone until the next week.
var shop_week: Array[ShopItemData] = []
## The training ground's drills this week: Sparring first, then up to
## RunConfig.DRILLS_PROFICIENCY_PER_WEEK proficiency drills. Posted on the first day of each week; a
## drill is not used up (see train).
var drills: Array[Drill] = []
## Today's event: the random weapon each choice that grants one would give (choice -> WeaponData),
## drawn when the event came up.
var event_weapons: Dictionary = {}
## Events already seen this run, so they do not repeat while unseen ones remain.
var _seen_events: Array[EventData] = []
## The boss group drawn for each boss day when the run began: boss day -> EnemyGroupData.
var boss_draw: Dictionary = {}


## A new run. `p_rng` should already be seeded. Of the two starting companions, at least one is not a
## mage.
static func create(p_rng: RandomNumberGenerator, p_content: RunContent = null, p_art_pool: Array[CombatArtData] = [],
		p_spell_pool: Array[SpellData] = []) -> Run:
	var r := Run.new()
	r.rng = p_rng
	r.content = p_content if p_content != null else RunContent.load_default()
	r.art_pool = p_art_pool
	r.spell_pool = p_spell_pool
	r.gold = RunConfig.STARTING_GOLD
	for m in RunConfig.MATERIAL_ORDER:
		r.materials[m] = int(RunConfig.STARTING_MATERIALS.get(m, 0))
	r.calendar = RunCalendar.generate()
	r.event_days = RunCalendar.pick_event_days(r.calendar, r.rng)
	var pool := r.content.companions.duplicate()
	var count := mini(RunConfig.STARTING_COMPANIONS, pool.size())
	for i in count:
		# The last pick is not a mage if every pick so far was one.
		var options := pool.duplicate()
		if i == count - 1 and r.roster.all(func(c: RunCompanion) -> bool: return c.data.is_mage()):
			options = pool.filter(func(d: CompanionData) -> bool: return not d.is_mage())
			if options.is_empty():
				options = pool.duplicate()
		var pick: CompanionData = options[r.rng.randi_range(0, options.size() - 1)]
		pool.erase(pick)
		r._join(pick)
	r._draw_bosses()
	r._begin_day()
	return r


# ---------------------------------------------------------------- queries

func is_over() -> bool:
	return outcome != Outcome.ONGOING


## True if free day `d` (default today) begins with an event.
func has_event_day(d: int = -1) -> bool:
	return event_days.has(day if d < 0 else d)


## True while today's event waits for an answer; nothing else can be done in the city until then.
func event_pending() -> bool:
	return event != null and not is_over()


func day_type(d: int = -1) -> int:
	var at := day if d < 0 else d
	if at < 1 or at > calendar.size():
		return -1
	return calendar[at - 1]


## The boss group waiting on boss day `d`, drawn when the run began; null on other days.
func boss_on(d: int) -> EnemyGroupData:
	return boss_draw.get(d)


## Boss days still ahead (today included), in order.
func boss_days_ahead() -> Array[int]:
	var out: Array[int] = []
	for d in range(day, calendar.size() + 1):
		if calendar[d - 1] == RunCalendar.DayType.BOSS:
			out.append(d)
	return out


## The bestiary band of `d`: 1 for days 1-14, 2 for 15-28, 3 from 29 (RunConfig.BAND_FIRST_DAY).
static func band_of_day(d: int) -> int:
	var b := 1
	for i in RunConfig.BAND_FIRST_DAY.size():
		if d >= RunConfig.BAND_FIRST_DAY[i]:
			b = i + 1
	return b


## Day types from today through `ahead` days after it (fewer near the end of the run).
func upcoming(ahead: int = RunConfig.DAYS_SHOWN_AHEAD) -> Array[int]:
	var out: Array[int] = []
	for d in range(day, mini(day + ahead, calendar.size()) + 1):
		out.append(calendar[d - 1])
	return out


func reserve() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	for c in roster:
		if not lineup.has(c):
			out.append(c)
	return out


func material(id: String) -> int:
	return int(materials.get(id, 0))


func is_fielded(c: RunCompanion) -> bool:
	return lineup.has(c)


## Party changes are free until the day's activity is committed to.
func can_change_party() -> bool:
	return not is_over() and committed_front == null


# ---------------------------------------------------------------- party

## Puts a reserve companion in the line at `index` (default: the front, rightmost).
func field(c: RunCompanion, index: int = -1) -> bool:
	if not can_change_party() or not roster.has(c) or lineup.has(c) or lineup.size() >= RunConfig.MAX_FIELDED:
		return false
	lineup.insert(lineup.size() if index < 0 else clampi(index, 0, lineup.size()), c)
	return true


func bench(c: RunCompanion) -> bool:
	if not can_change_party() or not lineup.has(c):
		return false
	lineup.erase(c)
	return true


## Moves a fielded companion to `index` in the line (0 = leftmost, the back).
func move_in_line(c: RunCompanion, index: int) -> bool:
	if not can_change_party() or not lineup.has(c):
		return false
	var to := clampi(index, 0, lineup.size() - 1)
	lineup.erase(c)
	lineup.insert(to, c)
	return true


func equip_block_reason(c: RunCompanion, w: OwnedWeapon) -> String:
	if not can_change_party():
		return "Not now."
	if not roster.has(c):
		return "Not in the roster."
	return inventory.equip_block_reason(c, w)


func equip_weapon(c: RunCompanion, w: OwnedWeapon) -> bool:
	if equip_block_reason(c, w) != "":
		return false
	return inventory.equip(c, w)


# ---------------------------------------------------------------- battle and boss days

## Why the day's battle cannot start on `front`, or "".
func battle_block_reason(front: Front) -> String:
	if is_over():
		return "The run is over."
	if committed_front != null:
		return "Today's battle has already begun."
	if not fronts.has(front):
		return "That front is not open today."
	if lineup.is_empty():
		return "Field at least one companion."
	return ""


## Commits to a front and returns the battle to fight there, with the fielded companions at their
## current HP and full stamina. Report the result with finish_battle().
func start_battle(front: Front) -> Battle:
	if battle_block_reason(front) != "":
		return null
	committed_front = front
	var battle_rng := RandomNumberGenerator.new()
	battle_rng.seed = rng.randi()
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for c in lineup:
		datas.append(c.data)
		party.append(c.progress)
	var battle := Battle.new(datas, front.enemies, battle_rng, party, art_pool, spell_pool)
	for i in lineup.size():
		battle.roster[i].hp = clampi(lineup[i].hp, 1, lineup[i].max_hp())
	return battle


## Applies a finished battle from start_battle() to the run and ends the day.
func finish_battle(battle: Battle) -> BattleReport:
	var front := committed_front
	if front == null or battle == null or not battle.is_over():
		return null
	var report := BattleReport.new()
	report.front = front
	report.won = battle.outcome == Battle.Outcome.VICTORY
	battle.learn_after_battle()   # the battle did it when it ended; harmless again
	report.grade_ups = battle.grade_ups.duplicate()
	var fielded := lineup.duplicate()
	var standing: Array[RunCompanion] = []
	var points: Array[int] = []
	for i in fielded.size():
		var c: RunCompanion = fielded[i]
		var unit := battle.roster[i]
		if unit.is_gone():
			report.removed.append(c.display_name())
			_remove(c)
			continue
		if unit.is_injured() or battle.injured_ever.has(unit):
			report.injured.append(c.display_name())
		c.hp = RunConfig.INJURED_RETURN_HP if unit.is_injured() or unit.hp <= 0 else mini(unit.hp, c.max_hp())
		standing.append(c)
		points.append(battle.points_of(unit))
		report.points[c.display_name()] = battle.points_of(unit)
	if report.won:
		battles_won += 1
		_grant_xp(report, front.xp_pool, standing, points)
		report.gold = front.reward_gold
		report.materials = front.reward_materials.duplicate()
		gold += front.reward_gold
		_add_materials(front.reward_materials)
		if front.is_boss and day >= RunConfig.DAYS:
			_end(Outcome.VICTORY, "The last boss has fallen. The city stands.")
		elif front.is_boss:
			report.weapon_found = _boss_weapon()
			if report.weapon_found != null:
				inventory.add(report.weapon_found)
	else:
		battles_lost += 1
		if front.is_boss:
			_end(Outcome.DEFEAT, "%s broke through on day %d." % [front.group.display_name, day])
		else:
			report.city_damage = mini(front.city_damage, city_health)
			city_health -= report.city_damage
	committed_front = null
	_end_day()
	report.run_over = is_over()
	return report


# ---------------------------------------------------------------- free days

const EVENT_FIRST := "First answer the matter at the gate."
const NO_USEFUL_DRILL := "Nobody can learn anything from this week's drills."


func free_action_block_reason(a: FreeAction) -> String:
	if is_over() or day_type() != RunCalendar.DayType.FREE:
		return "Only on free days."
	if event_pending():
		return EVENT_FIRST
	if actions_used.has(a):
		return "Already done today."
	if actions_left <= 0:
		return "No actions left today."
	match a:
		FreeAction.REST:
			if _everyone_at_full_hp() and not _any_spell_uses_spent():
				return "Everyone is at full health and every spell use is ready."
		FreeAction.TAVERN:
			if tavern_offers.is_empty():
				return "Nobody is looking for work."
		FreeAction.REPAIR:
			if city_health >= RunConfig.CITY_MAX_HEALTH:
				return "The city is at full health."
			if not _can_pay(RunConfig.REPAIR_COST):
				return "Needs %s." % cost_text(RunConfig.REPAIR_COST)
		FreeAction.TRAIN:
			if gold < RunConfig.DRILL_COST:
				return "Needs %d gold." % RunConfig.DRILL_COST
			if not _anyone_can_drill():
				return NO_USEFUL_DRILL
	return ""


## Shop and tavern can be visited without spending anything; the action is spent on the first
## purchase or hire, and further ones the same day are free.
func visit_block_reason(a: FreeAction) -> String:
	if actions_used.has(a) and not is_over() and day_type() == RunCalendar.DayType.FREE and not event_pending():
		return ""
	return free_action_block_reason(a)


## Every companion recovers to full HP and every spell's uses. Nothing else restores spell uses.
func rest() -> bool:
	if free_action_block_reason(FreeAction.REST) != "":
		return false
	_spend(FreeAction.REST)
	for c in roster:
		c.hp = c.max_hp()
		c.progress.restore_spell_uses()
	return true


func repair() -> bool:
	if free_action_block_reason(FreeAction.REPAIR) != "":
		return false
	_spend(FreeAction.REPAIR)
	_pay(RunConfig.REPAIR_COST)
	city_health = mini(RunConfig.CITY_MAX_HEALTH, city_health + RunConfig.REPAIR_AMOUNT)
	return true


## What the smithy sells this week (it can only be bought on free days).
func shop_stock() -> Array[ShopItemData]:
	return shop_week


func buy_block_reason(item: ShopItemData) -> String:
	var why := visit_block_reason(FreeAction.SHOP)
	if why != "":
		return why
	if item == null or not shop_stock().has(item):
		return "Not for sale this week."
	if gold < item.price:
		return "Needs %d gold." % item.price
	return ""


## Tier weights of the smithy's stock in the week of day `d` (RunConfig.SHOP_TIER_WEIGHTS).
static func shop_tier_weights(d: int) -> Array:
	var weeks: Array = RunConfig.SHOP_TIER_WEIGHTS
	return weeks[clampi(RunCalendar.week_of(d) - 1, 0, weeks.size() - 1)]


## The best tier the smithy sells in the week of day `d`: the highest with any weight.
static func smithy_top_tier(d: int) -> int:
	var weights := shop_tier_weights(d)
	var top := 0
	for t in weights.size():
		if float(weights[t]) > 0.0:
			top = t
	return top


## The tier of the weapon the boss of day `d` drops when beaten: above what the smithy sells that week
## (RunConfig.BOSS_WEAPON_TIERS_ABOVE_SHOP), at most platinum. -1 for the last boss, which ends the run.
static func boss_weapon_tier(d: int) -> int:
	if d >= RunConfig.DAYS:
		return -1
	return mini(smithy_top_tier(d) + RunConfig.BOSS_WEAPON_TIERS_ABOVE_SHOP, WeaponData.top_tier())


## The weapon `choice` of today's event would give: its set weapon, or the random one drawn for it
## when the event came up. Null if it gives none.
func choice_weapon(choice: EventChoiceData) -> WeaponData:
	if choice == null:
		return null
	if choice.weapon != null:
		return choice.weapon
	return event_weapons.get(choice)


## Buys a weapon into the armory. Returns it, or null. The item is gone from the smithy until the
## next week.
func buy(item: ShopItemData) -> OwnedWeapon:
	if buy_block_reason(item) != "":
		return null
	if not actions_used.has(FreeAction.SHOP):
		_spend(FreeAction.SHOP)
	gold -= item.price
	shop_week.erase(item)
	return inventory.add(item.weapon)


func hire_block_reason(data: CompanionData) -> String:
	var why := visit_block_reason(FreeAction.TAVERN)
	if why != "":
		return why
	if not tavern_offers.has(data):
		return "Not at the tavern this week."
	if gold < RunConfig.HIRE_COST:
		return "Needs %d gold." % RunConfig.HIRE_COST
	return ""


## Hires a companion offered at the tavern. They join at the roster's average level (rounded down)
## with the stat gains for those levels rolled now, at full HP, with their own weapon, and are fielded
## if the line has room.
func hire(data: CompanionData) -> RunCompanion:
	if hire_block_reason(data) != "":
		return null
	if not actions_used.has(FreeAction.TAVERN):
		_spend(FreeAction.TAVERN)
	gold -= RunConfig.HIRE_COST
	tavern_offers.erase(data)
	var level := hire_level()
	var c := _join(data)
	while c.level() < level:
		Levels.level_up(c.progress, rng)
	c.hp = c.max_hp()
	return c


# ---------------------------------------------------------------- the training ground

## Why `c` cannot take `drill` today, or "". A drill uses the day's free action (FreeAction.TRAIN)
## and RunConfig.DRILL_COST gold. A weapon drill needs a grade below S in its type (from E, it opens
## a new weapon type); a magic drill needs a grade above E in its school (training never opens a
## school) and below S; Sparring needs a level below the top. Anyone in the
## roster can train, fielded or not.
func drill_block_reason(drill: Drill, c: RunCompanion) -> String:
	var why := free_action_block_reason(FreeAction.TRAIN)
	if why != "" and why != NO_USEFUL_DRILL:
		return why
	if drill == null or not drills.has(drill):
		return "Not posted this week."
	if c == null or not roster.has(c):
		return "Not in the company."
	return _drill_unfit_reason(drill, c)


## Takes `drill` with `c`: spends the free action and RunConfig.DRILL_COST gold and rolls the quality
## (RunConfig.DRILL_QUALITY_WEIGHTS). A proficiency drill adds RunConfig.DRILL_POINTS[quality] points
## (every grade reached teaches an art or a spell as in battle); Sparring grants drill_xp(quality) XP
## (level-ups as in battle). The drill stays posted. Returns what happened, or null if not allowed.
func train(drill: Drill, c: RunCompanion) -> DrillResult:
	if drill_block_reason(drill, c) != "":
		return null
	_spend(FreeAction.TRAIN)
	gold -= RunConfig.DRILL_COST
	var r := DrillResult.new()
	r.drill = drill
	r.companion = c
	r.gold_spent = RunConfig.DRILL_COST
	r.quality = _roll_drill_quality()
	r.quality_name = DrillResult.QUALITY_NAMES[r.quality]
	if drill.is_proficiency():
		_drill_proficiency(r)
	else:
		_drill_sparring(r)
	return r


## XP a Sparring drill of `quality` (DrillResult.Quality) gives on day `d` (default today): good is
## half an even share of that day's danger-2 battle pool (pool / RunConfig.MAX_FIELDED / 2); poor and
## great are RunConfig.DRILL_XP_PERCENT of good. Rounded.
func drill_xp(quality: int, d: int = -1) -> int:
	var at := day if d < 0 else d
	var good := float(xp_pool(RunConfig.DRILL_SPARRING_DANGER, at)) / RunConfig.MAX_FIELDED \
		/ RunConfig.DRILL_SPARRING_SHARE_DIVISOR
	return roundi(good * RunConfig.DRILL_XP_PERCENT[quality] / 100.0)


## The XP pool of a normal front of `danger` on day `d`.
static func xp_pool(danger: int, d: int) -> int:
	return roundi(RunConfig.XP_POOL_BY_DANGER[danger - 1] * (1.0 + RunConfig.XP_POOL_GROWTH_PER_DAY * (d - 1)))


## Why `c` could not learn from `drill` at all (whatever the day), or "".
func _drill_unfit_reason(drill: Drill, c: RunCompanion) -> String:
	if drill.is_proficiency():
		var g := drill.grade_of(c.progress)
		# A weapon drill can open a new type from E; a school must already be above E.
		if drill.kind == Drill.Kind.MAGIC and g <= Proficiency.Grade.E:
			return "%s has no grade in %s to train; drills never open a school." % [c.display_name(), drill.subject_name()]
		if g >= Proficiency.max_grade():
			return "%s is already at %s in %s." % [c.display_name(), Proficiency.grade_name(g), drill.subject_name()]
	elif c.level() >= RunConfig.MAX_LEVEL:
		return "%s is already at the top level." % c.display_name()
	return ""


func _anyone_can_drill() -> bool:
	for d in drills:
		for c in roster:
			if _drill_unfit_reason(d, c) == "":
				return true
	return false


func _roll_drill_quality() -> DrillResult.Quality:
	var total := 0
	for w in RunConfig.DRILL_QUALITY_WEIGHTS:
		total += w
	var r := rng.randi_range(1, total)
	for q in RunConfig.DRILL_QUALITY_WEIGHTS.size():
		r -= RunConfig.DRILL_QUALITY_WEIGHTS[q]
		if r <= 0:
			return q as DrillResult.Quality
	return DrillResult.Quality.GOOD


func _drill_proficiency(r: DrillResult) -> void:
	var p := r.companion.progress
	var drill := r.drill
	r.grade_before = drill.grade_of(p)
	r.points_gained = drill.add_points(p, RunConfig.DRILL_POINTS[r.quality])
	r.grade_after = drill.grade_of(p)
	# Every grade reached teaches as in battle (Battle._gain_proficiency, Battle._gain_magic).
	for g in range(r.grade_before + 1, r.grade_after + 1):
		if drill.kind == Drill.Kind.WEAPON:
			var art := ArtLearning.pick_art(rng, p, drill.weapon_type, g, art_pool)
			var equipped := p.learn(art) if art != null else false
			r.grade_ups.append({"actor": r.companion, "magic": false, "weapon_type": drill.weapon_type, "grade": g,
				"art": art, "equipped": equipped})
		else:
			var spell := SpellLearning.pick_spell(rng, p, drill.school, g, spell_pool)
			if spell != null:
				p.learn_spell(spell)
			r.grade_ups.append({"actor": r.companion, "magic": true, "school": drill.school, "grade": g, "spell": spell})


## XP and level-ups as a won battle grants them (see _grant_xp).
func _drill_sparring(r: DrillResult) -> void:
	var c := r.companion
	r.level_before = c.level()
	r.stats_before = c.progress.stats()
	r.xp_gained = drill_xp(r.quality)
	var stats := r.stats_before.duplicate()
	var from := c.level()
	for up in Levels.add_xp(c.progress, r.xp_gained, rng):
		c.hp += int(up.gains.get(Stat.HP, 0))
		r.level_ups.append({"name": c.display_name(), "level": up.level, "gains": up.gains, "level_from": from,
			"before": stats.duplicate()})
		for key: String in up.gains:
			stats[key] = int(stats.get(key, 0)) + int(up.gains[key])
		from = up.level


## Shares a won battle's XP pool among `standing` by their contribution points (`points`, in the same
## order; see Levels.split_xp) and applies level-ups. Max HP gained from a level also raises current HP
## by the same amount.
func _grant_xp(report: BattleReport, pool: int, standing: Array[RunCompanion], points: Array[int]) -> void:
	if standing.is_empty() or pool <= 0:
		return
	var shares := Levels.split_xp(pool, points)
	for i in standing.size():
		var c := standing[i]
		report.xp_gained[c.display_name()] = shares[i]
		for up in Levels.add_xp(c.progress, shares[i], rng):
			c.hp += int(up.gains.get(Stat.HP, 0))
			report.level_ups.append({"name": c.display_name(), "level": up.level, "gains": up.gains})


## Level a companion hired today joins at: the roster's average level, rounded down.
func hire_level() -> int:
	if roster.is_empty():
		return 1
	var total := 0
	for c in roster:
		total += c.level()
	return maxi(1, floori(float(total) / roster.size()))


## Ends a free day; unused actions are lost. Not while the day's event waits for an answer.
func end_free_day() -> bool:
	if is_over() or day_type() != RunCalendar.DayType.FREE or event_pending():
		return false
	_end_day()
	return true


# ---------------------------------------------------------------- events (at the start of some free days)

func choice_block_reason(choice: EventChoiceData) -> String:
	if not event_pending() or day_type() != RunCalendar.DayType.FREE or not event.choices.has(choice):
		return "Not available."
	if choice.gold < 0 and gold < -choice.gold:
		return "Needs %d gold." % -choice.gold
	var cost := {}
	for m: String in choice.materials:
		if int(choice.materials[m]) < 0:
			cost[m] = -int(choice.materials[m])
	if not _can_pay(cost):
		return "Needs %s." % cost_text(cost)
	if choice.companion_hp != 0 and roster.is_empty():
		return "Nobody to send."
	return ""


## Applies an event choice; the free day then goes on. Returns the result text, or "" if not allowed.
func choose(choice: EventChoiceData) -> String:
	if choice_block_reason(choice) != "":
		return ""
	gold += choice.gold
	_add_materials(choice.materials)
	city_health = clampi(city_health + choice.city_health, 0, RunConfig.CITY_MAX_HEALTH)
	if choice.companion_hp != 0:
		for c in hp_targets(choice):
			c.heal(choice.companion_hp)
	var gained := choice_weapon(choice)
	if gained != null:
		inventory.add(gained)
	event = null
	event_weapons.clear()
	if city_health <= 0:
		_end(Outcome.DEFEAT, "The city fell on day %d." % day)
	var text := choice.result_text if choice.result_text != "" else choice.label
	return text.replace("{weapon}", gained.display_name if gained != null else "weapon")


## The companions a choice's HP change would apply to.
func hp_targets(choice: EventChoiceData) -> Array[RunCompanion]:
	if choice.hp_target == EventChoiceData.HpTarget.ALL:
		return roster.duplicate()
	var best: RunCompanion = null
	for c in roster:
		if best == null or c.hp > best.hp:
			best = c
	var out: Array[RunCompanion] = []
	if best != null:
		out.append(best)
	return out


# ---------------------------------------------------------------- text helpers

static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for m in RunConfig.MATERIAL_ORDER:
		if int(cost.get(m, 0)) > 0:
			parts.append("%d %s" % [int(cost[m]), RunConfig.MATERIAL_NAMES[m]])
	return " and ".join(parts)


# ---------------------------------------------------------------- day flow

func _begin_day() -> void:
	fronts.clear()
	committed_front = null
	event = null
	event_weapons.clear()
	actions_left = 0
	actions_used.clear()
	if RunCalendar.is_week_start(day):
		_restock_week()
	match day_type():
		RunCalendar.DayType.BATTLE:
			_make_fronts()
		RunCalendar.DayType.BOSS:
			fronts.append(_make_boss_front())
		RunCalendar.DayType.FREE:
			actions_left = RunConfig.FREE_DAY_ACTIONS
			if has_event_day():
				event = _pick_event()
				_draw_event_weapons()


func _end_day() -> void:
	for c in roster:
		c.heal(ceili(c.max_hp() * RunConfig.DAILY_HEAL_FRACTION))
	if not is_over():
		if city_health <= 0:
			city_health = 0
			_end(Outcome.DEFEAT, "The city fell on day %d." % day)
		elif roster.is_empty():
			_end(Outcome.DEFEAT, "No companions were left to defend the city on day %d." % day)
		elif day >= calendar.size():
			_end(Outcome.VICTORY, "The city held for %d days." % calendar.size())
	if is_over():
		committed_front = null
		fronts.clear()
		event = null
		actions_left = 0
		return
	day += 1
	_begin_day()


func _end(result: Outcome, reason: String) -> void:
	if is_over():
		return
	outcome = result
	end_reason = reason


## Two or three fronts of different danger. Three fronts are always danger 1, 2 and 3; two are
## two different dangers.
func _make_fronts() -> void:
	var dangers: Array[int] = [1, 2, 3]
	if rng.randf() >= RunConfig.THREE_FRONTS_CHANCE:
		dangers.remove_at(rng.randi_range(0, 2))
	var sites := content.sites.duplicate()
	for danger in dangers:
		var options := content.groups_for(danger, day)
		if options.is_empty():
			continue
		var f := Front.new()
		f.danger = danger
		f.group = _pick_group(options)
		f.site = sites.pop_at(rng.randi_range(0, sites.size() - 1)) if not sites.is_empty() else null
		for e in f.group.enemies:
			f.enemies.append(scaled_enemy(e, day))
		var growth := 1.0 + RunConfig.REWARD_GROWTH_PER_DAY * (day - 1)
		var spread := rng.randf_range(1.0 - RunConfig.REWARD_GOLD_SPREAD, 1.0 + RunConfig.REWARD_GOLD_SPREAD)
		f.reward_gold = roundi(RunConfig.REWARD_GOLD_BY_DANGER[danger - 1] * growth * spread)
		if rng.randf() < RunConfig.REWARD_MATERIAL_CHANCE[danger - 1]:
			var m: String = RunConfig.MATERIAL_ORDER[rng.randi_range(0, RunConfig.MATERIAL_ORDER.size() - 1)]
			f.reward_materials[m] = RunConfig.REWARD_MATERIAL_AMOUNT[danger - 1]
		f.city_damage = RunConfig.CITY_DAMAGE_BY_DANGER[danger - 1]
		f.xp_pool = xp_pool(danger, day)
		fronts.append(f)


## A group for a front, favouring the band of the day: a group from an older band is less likely
## (RunConfig.BAND_AGE_WEIGHT), one from a later band never appears (groups' days rule it out).
func _pick_group(options: Array[EnemyGroupData]) -> EnemyGroupData:
	var now := band_of_day(day)
	var weights: Array[float] = []
	var total := 0.0
	for g in options:
		var age := clampi(now - maxi(1, g.band()), 0, RunConfig.BAND_AGE_WEIGHT.size() - 1)
		weights.append(RunConfig.BAND_AGE_WEIGHT[age])
		total += weights[-1]
	var r := rng.randf() * total
	for i in options.size():
		r -= weights[i]
		if r < 0.0:
			return options[i]
	return options[-1]


## One boss group for every boss day of the calendar, drawn from those whose days fit it.
func _draw_bosses() -> void:
	boss_draw.clear()
	for d in range(1, calendar.size() + 1):
		if calendar[d - 1] == RunCalendar.DayType.BOSS:
			_draw_boss(d)


func _draw_boss(d: int) -> void:
	var pool := content.bosses_for(d)
	if pool.is_empty():
		if content.bosses.is_empty():
			return
		pool = [content.bosses[clampi(RunCalendar.boss_index(d), 0, content.bosses.size() - 1)]]
	boss_draw[d] = pool[rng.randi_range(0, pool.size() - 1)]


func _make_boss_front() -> Front:
	var index := maxi(0, RunCalendar.boss_index(day))
	var f := Front.new()
	f.is_boss = true
	f.danger = 3
	f.group = boss_on(day)
	if f.group == null:
		_draw_boss(day)
		f.group = boss_on(day)
	# The first enemy is the boss, built for its day; any escorts grow with the day like other enemies.
	for i in f.group.enemies.size():
		var e := f.group.enemies[i]
		f.enemies.append(e if i == 0 else scaled_enemy(e, day))
	f.reward_gold = RunConfig.BOSS_REWARD_GOLD[clampi(index, 0, RunConfig.BOSS_REWARD_GOLD.size() - 1)]
	if day < RunConfig.DAYS:
		for m in RunConfig.MATERIAL_ORDER:
			f.reward_materials[m] = RunConfig.BOSS_REWARD_MATERIALS
	f.city_damage = 0
	f.xp_pool = RunConfig.BOSS_XP_POOL[clampi(index, 0, RunConfig.BOSS_XP_POOL.size() - 1)]
	return f


## A copy of `e` grown for `day` (see RunConfig enemy scaling). Day 1 returns an unchanged copy.
static func scaled_enemy(e: EnemyData, on_day: int) -> EnemyData:
	var s := e.duplicate() as EnemyData
	var d := maxi(0, on_day - 1)
	s.max_hp = roundi(e.max_hp * (1.0 + RunConfig.ENEMY_HP_GROWTH_PER_DAY * d))
	s.strength = e.strength + floori(float(d) / RunConfig.ENEMY_STR_EVERY_DAYS)
	s.magic = e.magic + floori(float(d) / RunConfig.ENEMY_STR_EVERY_DAYS)
	s.defense = e.defense + floori(float(d) / RunConfig.ENEMY_DEF_EVERY_DAYS)
	s.speed = e.speed + floori(float(d) / RunConfig.ENEMY_SPD_EVERY_DAYS)
	s.dexterity = e.dexterity + floori(float(d) / RunConfig.ENEMY_SPD_EVERY_DAYS)
	return s


## The weekly refresh: the tavern's offers and the smithy's stock for the week that begins today.
func _restock_week() -> void:
	tavern_offers.clear()
	shop_week.clear()
	_make_tavern_offers()
	_stock_shop()
	_post_drills()


## The week's drills: Sparring, then RunConfig.DRILLS_PROFICIENCY_PER_WEEK different weapon types or
## magic schools drawn at random from those someone in the roster could train (any weapon type someone
## is below S in; a school someone is above E and below S in), fewer if fewer exist. Listed weapon types first, then schools, each in enum order.
func _post_drills() -> void:
	drills.clear()
	drills.append(Drill.sparring())
	var useful: Array[Drill] = []
	var options: Array[Drill] = []
	for wt: int in WeaponData.WeaponType.values():
		options.append(Drill.weapon(wt))
	for s: int in SpellData.School.values():
		options.append(Drill.magic(s))
	for d in options:
		for c in roster:
			if _drill_unfit_reason(d, c) == "":
				useful.append(d)
				break
	var picked: Array[int] = []
	while picked.size() < RunConfig.DRILLS_PROFICIENCY_PER_WEEK and picked.size() < useful.size():
		var i := rng.randi_range(0, useful.size() - 1)
		if not picked.has(i):
			picked.append(i)
	picked.sort()
	for i in picked:
		drills.append(useful[i])


func _make_tavern_offers() -> void:
	var pool: Array[CompanionData] = []
	for d in content.companions:
		if not _in_roster(d) and not gone.has(d):
			pool.append(d)
	var count := mini(rng.randi_range(RunConfig.TAVERN_OFFERS_MIN, RunConfig.TAVERN_OFFERS_MAX), pool.size())
	for i in count:
		tavern_offers.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


## The week's stock: each rare item sold by today on a roll of its chance, first; then
## RunConfig.SHOP_WEAPONS_PER_WEEK different weapons, each a tier drawn by the week's weights and then
## (see _random_weapon) a two-proficiency weapon of that tier with RunConfig.SHOP_HYBRID_CHANCE, else
## a ladder weapon of a random type; priced by weapon_price, in order of tier and type.
func _stock_shop() -> void:
	for item in content.shop_stock(day):
		if item.chance >= 1.0 or rng.randf() < item.chance:
			shop_week.append(item)
	var weights := shop_tier_weights(day)
	var picked: Array[WeaponData] = []
	var tries := 0
	while picked.size() < RunConfig.SHOP_WEAPONS_PER_WEEK and tries < 200:
		tries += 1
		var w := _random_weapon(_roll_tier(weights))
		if w != null and not picked.has(w):
			picked.append(w)
	picked.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		if a.weapon_type != b.weapon_type:
			return a.weapon_type < b.weapon_type
		return not a.has_second_requirement() and b.has_second_requirement())
	for w in picked:
		var item := ShopItemData.new()
		item.weapon = w
		item.price = weapon_price(w)
		item.min_day = day
		shop_week.append(item)


## A tier drawn by `weights` (one per tier).
func _roll_tier(weights: Array) -> int:
	var total := 0.0
	for x in weights:
		total += float(x)
	var r := rng.randf() * total
	for t in weights.size():
		r -= float(weights[t])
		if r < 0.0 and float(weights[t]) > 0.0:
			return t
	return smithy_top_tier(day)


## The smithy's price of `w`: its tier's price; a two-proficiency weapon x RunConfig.HYBRID_PRICE_MULT,
## rounded to the nearest RunConfig.PRICE_ROUND_TO.
static func weapon_price(w: WeaponData) -> int:
	var base: int = RunConfig.WEAPON_PRICE_BY_TIER[w.tier]
	if not w.has_second_requirement():
		return base
	return roundi(base * RunConfig.HYBRID_PRICE_MULT / RunConfig.PRICE_ROUND_TO) * RunConfig.PRICE_ROUND_TO


## A random weapon of tier `tier` (main type `type`, or any with -1): with RunConfig.SHOP_HYBRID_CHANCE
## a two-proficiency weapon when the tier has one of that type, else a ladder weapon. Null if none.
func _random_weapon(tier: int, type: int = -1) -> WeaponData:
	var hybrids := content.hybrids_of_tier(tier, type)
	if rng.randf() < RunConfig.SHOP_HYBRID_CHANCE and not hybrids.is_empty():
		return hybrids[rng.randi_range(0, hybrids.size() - 1)]
	return _random_ladder_weapon(tier, type)


## A random ladder weapon of tier `tier` (of type `type`, or any with -1), or null.
func _random_ladder_weapon(tier: int, type: int = -1) -> WeaponData:
	var options := content.ladder_tier(tier, type)
	if options.is_empty():
		return null
	return options[rng.randi_range(0, options.size() - 1)]


## Draws the random weapon of every choice of today's event that grants one: a tier drawn like the
## week's stock, or with RunConfig.EVENT_WEAPON_TIER_UP_CHANCE one above the best the smithy sells;
## maybe a two-proficiency weapon of that tier and type (see _random_weapon).
func _draw_event_weapons() -> void:
	event_weapons.clear()
	if event == null:
		return
	for choice in event.choices:
		if not choice.random_weapon:
			continue
		var tier := _roll_tier(shop_tier_weights(day))
		if rng.randf() < RunConfig.EVENT_WEAPON_TIER_UP_CHANCE:
			tier = mini(smithy_top_tier(day) + 1, WeaponData.top_tier())
		var w := _random_weapon(tier, choice.random_weapon_type)
		if w != null:
			event_weapons[choice] = w


## The weapon a beaten boss drops (see boss_weapon_tier): any type, at random, maybe a two-proficiency
## one (see _random_weapon). Null for the last boss.
func _boss_weapon() -> WeaponData:
	var tier := boss_weapon_tier(day)
	if tier < 0:
		return null
	return _random_weapon(tier)


func _pick_event() -> EventData:
	if content.events.is_empty():
		return null
	var fresh: Array[EventData] = []
	for e in content.events:
		if not _seen_events.has(e):
			fresh.append(e)
	if fresh.is_empty():
		fresh = content.events.duplicate()
	var e := fresh[rng.randi_range(0, fresh.size() - 1)]
	_seen_events.append(e)
	return e


# ---------------------------------------------------------------- internals

func _join(data: CompanionData) -> RunCompanion:
	var c := RunCompanion.create(data)
	roster.append(c)
	inventory.add(data.weapon, c)
	if lineup.size() < RunConfig.MAX_FIELDED:
		lineup.append(c)
	return c


func _remove(c: RunCompanion) -> void:
	inventory.release(c)
	roster.erase(c)
	lineup.erase(c)
	gone.append(c.data)


func _in_roster(data: CompanionData) -> bool:
	for c in roster:
		if c.data == data:
			return true
	return false


func _any_spell_uses_spent() -> bool:
	for c in roster:
		if c.progress.has_spent_uses():
			return true
	return false


func _everyone_at_full_hp() -> bool:
	for c in roster:
		if c.hp < c.max_hp():
			return false
	return true


func _spend(a: FreeAction) -> void:
	actions_used.append(a)
	actions_left -= 1


func _can_pay(cost: Dictionary) -> bool:
	for m: String in cost:
		if material(m) < int(cost[m]):
			return false
	return true


func _pay(cost: Dictionary) -> void:
	for m: String in cost:
		materials[m] = material(m) - int(cost[m])


func _add_materials(gain: Dictionary) -> void:
	for m: String in gain:
		materials[m] = maxi(0, material(m) + int(gain[m]))
