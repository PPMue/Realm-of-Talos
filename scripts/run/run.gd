class_name Run
extends RefCounted
## A run: thirty days of defending the last city. Plain class, no nodes or UI; every random choice
## comes from the injected generator, so the same seed and the same choices give the same run.
##
## A day:
##   1. begins: the day's activity is prepared (fronts, the boss, the free-day actions, or an event)
##   2. the player may change the party freely (who is fielded, their order, weapons, arts)
##   3. the player commits to the activity: a battle, free-day actions then End day, or an event choice
##   4. ends: every surviving companion heals 20% of max HP, the run checks for its end, the next day begins
##
## Commands return false (or "") and change nothing when not allowed; the *_block_reason queries say why.

enum Outcome { ONGOING, VICTORY, DEFEAT }
enum FreeAction { REST, SHOP, TAVERN, REPAIR }

const FREE_ACTION_NAMES: Array[String] = ["Rest", "Shop", "Tavern", "Repair"]

var rng: RandomNumberGenerator
var content: RunContent
var art_pool: Array[CombatArtData] = []

## 1-based. After the run ends it stays on the last day played.
var day: int = 1
## Day types (RunCalendar.DayType) for days 1..RunConfig.DAYS; index 0 is day 1.
var calendar: Array[int] = []
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
## Event days.
var event: EventData
## Free days.
var actions_left: int = 0
var actions_used: Array[int] = []
var tavern_offers: Array[CompanionData] = []
## Events already seen this run, so they do not repeat while unseen ones remain.
var _seen_events: Array[EventData] = []


## A new run. `p_rng` should already be seeded.
static func create(p_rng: RandomNumberGenerator, p_content: RunContent = null, p_art_pool: Array[CombatArtData] = []) -> Run:
	var r := Run.new()
	r.rng = p_rng
	r.content = p_content if p_content != null else RunContent.load_default()
	r.art_pool = p_art_pool
	r.gold = RunConfig.STARTING_GOLD
	for m in RunConfig.MATERIAL_ORDER:
		r.materials[m] = int(RunConfig.STARTING_MATERIALS.get(m, 0))
	r.calendar = RunCalendar.generate(r.rng)
	var pool := r.content.companions.duplicate()
	for i in mini(RunConfig.STARTING_COMPANIONS, pool.size()):
		var pick: CompanionData = pool[r.rng.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		r._join(pick)
	r._begin_day()
	return r


# ---------------------------------------------------------------- queries

func is_over() -> bool:
	return outcome != Outcome.ONGOING


func day_type(d: int = -1) -> int:
	var at := day if d < 0 else d
	if at < 1 or at > calendar.size():
		return -1
	return calendar[at - 1]


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
	var battle := Battle.new(datas, front.enemies, battle_rng, party, art_pool)
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
	report.grade_ups = battle.grade_ups.duplicate()
	var fielded := lineup.duplicate()
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
	if report.won:
		battles_won += 1
		report.gold = front.reward_gold
		report.materials = front.reward_materials.duplicate()
		gold += front.reward_gold
		_add_materials(front.reward_materials)
		if front.is_boss and day >= RunConfig.DAYS:
			_end(Outcome.VICTORY, "The last boss has fallen. The city stands.")
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

func free_action_block_reason(a: FreeAction) -> String:
	if is_over() or day_type() != RunCalendar.DayType.FREE:
		return "Only on free days."
	if actions_used.has(a):
		return "Already done today."
	if actions_left <= 0:
		return "No actions left today."
	match a:
		FreeAction.REST:
			if _everyone_at_full_hp():
				return "Everyone is at full health."
		FreeAction.TAVERN:
			if tavern_offers.is_empty():
				return "Nobody is looking for work."
		FreeAction.REPAIR:
			if city_health >= RunConfig.CITY_MAX_HEALTH:
				return "The city is at full health."
			if not _can_pay(RunConfig.REPAIR_COST):
				return "Needs %s." % cost_text(RunConfig.REPAIR_COST)
	return ""


## Shop and tavern can be visited without spending anything; the action is spent on the first
## purchase or hire, and further ones the same day are free.
func visit_block_reason(a: FreeAction) -> String:
	if actions_used.has(a) and not is_over() and day_type() == RunCalendar.DayType.FREE:
		return ""
	return free_action_block_reason(a)


## Every companion recovers to full HP.
func rest() -> bool:
	if free_action_block_reason(FreeAction.REST) != "":
		return false
	_spend(FreeAction.REST)
	for c in roster:
		c.hp = c.max_hp()
	return true


func repair() -> bool:
	if free_action_block_reason(FreeAction.REPAIR) != "":
		return false
	_spend(FreeAction.REPAIR)
	_pay(RunConfig.REPAIR_COST)
	city_health = mini(RunConfig.CITY_MAX_HEALTH, city_health + RunConfig.REPAIR_AMOUNT)
	return true


func shop_stock() -> Array[ShopItemData]:
	return content.shop_stock(day)


func buy_block_reason(item: ShopItemData) -> String:
	var why := visit_block_reason(FreeAction.SHOP)
	if why != "":
		return why
	if item == null or not shop_stock().has(item):
		return "Not for sale today."
	if gold < item.price:
		return "Needs %d gold." % item.price
	return ""


## Buys a weapon into the armory. Returns it, or null.
func buy(item: ShopItemData) -> OwnedWeapon:
	if buy_block_reason(item) != "":
		return null
	if not actions_used.has(FreeAction.SHOP):
		_spend(FreeAction.SHOP)
	gold -= item.price
	return inventory.add(item.weapon)


func hire_block_reason(data: CompanionData) -> String:
	var why := visit_block_reason(FreeAction.TAVERN)
	if why != "":
		return why
	if not tavern_offers.has(data):
		return "Not at the tavern today."
	if gold < RunConfig.HIRE_COST:
		return "Needs %d gold." % RunConfig.HIRE_COST
	return ""


## Hires a companion offered at the tavern. They join at full HP with their own weapon and are
## fielded if the line has room.
func hire(data: CompanionData) -> RunCompanion:
	if hire_block_reason(data) != "":
		return null
	if not actions_used.has(FreeAction.TAVERN):
		_spend(FreeAction.TAVERN)
	gold -= RunConfig.HIRE_COST
	tavern_offers.erase(data)
	return _join(data)


## Ends a free day; unused actions are lost.
func end_free_day() -> bool:
	if is_over() or day_type() != RunCalendar.DayType.FREE:
		return false
	_end_day()
	return true


# ---------------------------------------------------------------- event days

func choice_block_reason(choice: EventChoiceData) -> String:
	if is_over() or day_type() != RunCalendar.DayType.EVENT or event == null or not event.choices.has(choice):
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


## Applies an event choice and ends the day. Returns the result text, or "" if not allowed.
func choose(choice: EventChoiceData) -> String:
	if choice_block_reason(choice) != "":
		return ""
	gold += choice.gold
	_add_materials(choice.materials)
	city_health = clampi(city_health + choice.city_health, 0, RunConfig.CITY_MAX_HEALTH)
	if choice.companion_hp != 0:
		for c in hp_targets(choice):
			c.heal(choice.companion_hp)
	if choice.weapon != null:
		inventory.add(choice.weapon)
	var text := choice.result_text
	_end_day()
	return text if text != "" else choice.label


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
	actions_left = 0
	actions_used.clear()
	tavern_offers.clear()
	match day_type():
		RunCalendar.DayType.BATTLE:
			_make_fronts()
		RunCalendar.DayType.BOSS:
			fronts.append(_make_boss_front())
		RunCalendar.DayType.FREE:
			actions_left = RunConfig.FREE_DAY_ACTIONS
			_make_tavern_offers()
		RunCalendar.DayType.EVENT:
			event = _pick_event()


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
		f.group = options[rng.randi_range(0, options.size() - 1)]
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
		fronts.append(f)


func _make_boss_front() -> Front:
	var index := clampi(RunCalendar.boss_index(day), 0, content.bosses.size() - 1)
	var f := Front.new()
	f.is_boss = true
	f.danger = 3
	f.group = content.bosses[index]
	# The first enemy is the boss, built for its day; any escorts grow with the day like other enemies.
	for i in f.group.enemies.size():
		var e := f.group.enemies[i]
		f.enemies.append(e if i == 0 else scaled_enemy(e, day))
	f.reward_gold = RunConfig.BOSS_REWARD_GOLD[clampi(index, 0, RunConfig.BOSS_REWARD_GOLD.size() - 1)]
	if day < RunConfig.DAYS:
		for m in RunConfig.MATERIAL_ORDER:
			f.reward_materials[m] = RunConfig.BOSS_REWARD_MATERIALS
	f.city_damage = 0
	return f


## A copy of `e` grown for `day` (see RunConfig enemy scaling). Day 1 returns an unchanged copy.
static func scaled_enemy(e: EnemyData, on_day: int) -> EnemyData:
	var s := e.duplicate() as EnemyData
	var d := maxi(0, on_day - 1)
	s.max_hp = roundi(e.max_hp * (1.0 + RunConfig.ENEMY_HP_GROWTH_PER_DAY * d))
	s.strength = e.strength + floori(float(d) / RunConfig.ENEMY_STR_EVERY_DAYS)
	s.defense = e.defense + floori(float(d) / RunConfig.ENEMY_DEF_EVERY_DAYS)
	return s


func _make_tavern_offers() -> void:
	var pool: Array[CompanionData] = []
	for d in content.companions:
		if not _in_roster(d) and not gone.has(d):
			pool.append(d)
	var count := mini(rng.randi_range(RunConfig.TAVERN_OFFERS_MIN, RunConfig.TAVERN_OFFERS_MAX), pool.size())
	for i in count:
		tavern_offers.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


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
