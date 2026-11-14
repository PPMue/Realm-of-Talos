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
##      day has one), then the free-day action and any errands (smithy, tavern, infirmary), then End day
##   4. ends: every companion not in the infirmary heals 20% of max HP, the run checks for its end, the
##      next day begins (and whoever's infirmary stay is over comes out)
##
## Commands return false (or "") and change nothing when not allowed; the *_block_reason queries say why.

enum Outcome { ONGOING, VICTORY, DEFEAT }
enum FreeAction { REST, SHOP, TAVERN, REPAIR, TRAIN, CURE, SCAVENGE, CRAFT }

const FREE_ACTION_NAMES: Array[String] = ["Rest", "Shop", "Tavern", "Repair", "Train", "Cure", "Scavenge", "Craft"]

## The city's facilities, each built up to two levels (see upgrade).
enum Facility { WATCHTOWER, SMITHY, TAVERN, INN, INFIRMARY, YARD, BARRACKS, MASON, GATE, JEWELER }

const FACILITY_NAMES: Array[String] = ["Watchtower", "Smithy", "Tavern", "Inn", "Infirmary", "Drill Yard", "Barracks",
	"Mason's Yard", "Gate", "Jeweler"]
## What each level does, as the design words it: [level 1, level 2] by Facility.
const FACILITY_LINES := [
	["The boss days and which boss comes are known", "Tomorrow's fronts are known a day early"],
	["Opens enchanting", "The smith offers two enchantments to choose from"],
	["One more hire offered each week", "Hires cost 25 gold less"],
	["Everyone heals 30% overnight instead of 20%", "Every spell gets one use back each night"],
	["Stays are 3 days instead of 4", "Cures cost a quarter less"],
	["Drills never come out poor", "A third drill is posted each week"],
	["The reserve gets a quarter share of a battle's XP", "The reserve heals fully overnight"],
	["Repairs mend 30 instead of 20", "The walls hold 120 instead of 100"],
	["A third scavenging site each day", "A lost front costs the walls 5 less"],
	["Opens crafting", "The jeweler shows two designs to choose from"],
]

var rng: RandomNumberGenerator
var content: RunContent
var art_pool: Array[CombatArtData] = []
var spell_pool: Array[SpellData] = []
## Every trait that can be handed out (TraitLibrary). See _roll_traits.
var trait_pool: Array[TraitData] = []
## Traits on someone in the company or on anyone offered at the tavern this run, hired or not: no
## trait twice in a run.
var _traits_taken: Array[TraitData] = []
## The traits of everyone offered at the tavern this run: CompanionData -> Array[TraitData], rolled the
## first time they are offered and theirs for the rest of the run (see offer_traits, _offer).
var _rolled_traits: Dictionary = {}
## Everyone outside the company: CompanionData -> CompanionProgress, made the first time it is needed
## (CompanionProgress.create) and never made again: it only grows, by practice at each weekly restock
## after the first (see _practise_outside). A hire joins with it (see offer_progress, hire).
var _outside: Dictionary = {}

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
## Every piece of material the run has taken in so far (battles, bosses, events, scavenging), by id;
## for the record and the balance checks.
var materials_taken: Dictionary = {}
## The company's gemstones: Gem rank (1-5) -> count. Kept like materials; nothing spends them yet.
var gems: Dictionary = {}
## Every stone taken this run, any rank.
var gems_taken: int = 0
## Every companion in the run (fielded, bench and infirmary), in the order they joined. Nobody is ever
## removed.
var roster: Array[RunCompanion] = []
## The fielded companions, left to right; the rightmost stands nearest the enemies.
var lineup: Array[RunCompanion] = []
## The infirmary, in the order they went in (see infirmary()).
var _infirmary: Array[RunCompanion] = []
## Who came out of the infirmary at the start of today (by themselves), for the day's news.
var released_today: Array[RunCompanion] = []
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
## Free days: the places beyond the walls a party can be sent to today (see scavenge_sites()).
var _scavenge_sites: Array[ScavengeSite] = []
## Facility -> level (missing: 0). See facility_level.
var facilities: Dictionary = {}
## An enchanting attempt waiting for the player's choice (see enchant), or null.
var enchant_offer: EnchantOffer
## Every accessory type the Jeweler can make (AccessoryLibrary).
var accessory_pool: Array[AccessoryTypeData] = []
## Every accessory the company owns, worn or not, in the order made (see wear, accessories_of).
var accessories: Array[Accessory] = []
## The Jeweler's designs paid for and waiting for a choice (craft, take_craft); null when none.
var craft_offer: CraftOffer
## The Watchtower level 2: the fronts of day _next_fronts_day, rolled a day early (see tomorrow_fronts).
var _next_fronts: Array[Front] = []
var _next_fronts_day: int = 0
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
	r.trait_pool = TraitLibrary.load_default().traits.duplicate()
	r.accessory_pool = AccessoryLibrary.load_default().types.duplicate()
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
		var c := r._join(pick)
		c.traits = r._roll_traits(c.progress)
		c.hp = c.max_hp()
	r._stock_wooden_armory()
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


## True if day `d` (default today) is a day the company marches out: a battle, an elite or a boss
## (RunCalendar.is_fight).
func is_fight_day(d: int = -1) -> bool:
	return RunCalendar.is_fight(day_type(d))


# ---------------------------------------------------------------- gemstones

func gem_count(rank: int) -> int:
	return int(gems.get(rank, 0))


## Every stone the company holds, any rank.
func gem_total() -> int:
	var n := 0
	for r: int in gems:
		n += int(gems[r])
	return n


## Adds one stone of `rank` (1-5; anything else does nothing). Returns the rank added, or 0.
func add_gem(rank: int) -> int:
	if not Gem.is_rank(rank):
		return 0
	gems[rank] = gem_count(rank) + 1
	gems_taken += 1
	return rank


## The stone winning the big fight of day `d` gives: the elites and the bosses before the last day, in
## order, give Topaz, Sapphire, Emerald, Ruby, Diamond (days 6, 14, 20, 28, 34). 0 on any other day and
## on the run's last day.
func gem_for_fight(d: int) -> int:
	if d >= calendar.size() or not RunCalendar.is_big_fight(day_type(d)):
		return 0
	var rank := 0
	for x in range(1, d + 1):
		if RunCalendar.is_big_fight(day_type(x)):
			rank += 1
	return mini(rank, Gem.max_rank())


## The stone other sources give today (scavenging, events): that of the last big fight whose day has
## passed, won or not; Topaz before the first.
func gem_rank_now() -> int:
	var rank := Gem.TOPAZ
	for x in range(1, mini(day, calendar.size() + 1)):
		rank = maxi(rank, gem_for_fight(x))
	return rank


## The stone `choice` gives if chosen now (EventChoiceData.gem_stone), or 0.
func choice_gem(choice: EventChoiceData) -> int:
	if choice == null:
		return 0
	match choice.gem_stone:
		EventChoiceData.GemStone.CURRENT:
			return gem_rank_now()
		EventChoiceData.GemStone.ONE_LOWER:
			return maxi(Gem.TOPAZ, gem_rank_now() - 1)
	return 0


## The boss group waiting on boss day `d`, drawn when the run began; null on other days, and for a
## day ahead while the watch does not know the bosses (boss_days_known).
func boss_on(d: int) -> EnemyGroupData:
	if d > day and not boss_days_known():
		return null
	return boss_draw.get(d)


## Boss days still ahead (today included), in order; while the watch does not know them, at most today.
func boss_days_ahead() -> Array[int]:
	var out: Array[int] = []
	for d in range(day, calendar.size() + 1):
		if calendar[d - 1] == RunCalendar.DayType.BOSS and (d == day or boss_days_known()):
			out.append(d)
	return out


## The bestiary band of `d`: 1 for days 1-14, 2 for 15-28, 3 from 29 (RunConfig.BAND_FIRST_DAY).
static func band_of_day(d: int) -> int:
	var b := 1
	for i in RunConfig.BAND_FIRST_DAY.size():
		if d >= RunConfig.BAND_FIRST_DAY[i]:
			b = i + 1
	return b


## Day types from today through `ahead` days after it (fewer near the end of the run), as the watch
## sees them (seen_day_type: a boss day ahead is a battle day until the boss days are known).
func upcoming(ahead: int = RunConfig.DAYS_SHOWN_AHEAD) -> Array[int]:
	var out: Array[int] = []
	for d in range(day, mini(day + ahead, calendar.size()) + 1):
		out.append(seen_day_type(d))
	return out


## The bench: companions not fielded and not in the infirmary.
func reserve() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	for c in roster:
		if not lineup.has(c) and c.is_available():
			out.append(c)
	return out


## Everyone who can be fielded or trained: the roster minus the infirmary, in roster order.
func available() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	for c in roster:
		if c.is_available():
			out.append(c)
	return out


## Companions in the infirmary, in the order they went in. See RunCompanion.injured, back_on_day,
## days_left().
func infirmary() -> Array[RunCompanion]:
	return _infirmary.duplicate()


## "X is in the infirmary until day N." (N: the day they come out), or "" if they are not.
func infirmary_block_reason(c: RunCompanion) -> String:
	if c == null or not c.injured:
		return ""
	return "%s is in the infirmary until day %d." % [c.display_name(), c.back_on_day]


func material(id: String) -> int:
	return int(materials.get(id, 0))


func is_fielded(c: RunCompanion) -> bool:
	return lineup.has(c)


## Party changes are free until the day's activity is committed to.
func can_change_party() -> bool:
	return not is_over() and committed_front == null


# ---------------------------------------------------------------- party

## Why `c` cannot be put in the line now, or "".
func field_block_reason(c: RunCompanion) -> String:
	if not can_change_party():
		return "Not now."
	if c == null or not roster.has(c):
		return "Not in the company."
	if c.injured:
		return infirmary_block_reason(c)
	if lineup.has(c):
		return "%s is already in the line." % c.display_name()
	if lineup.size() >= RunConfig.MAX_FIELDED:
		return "The line is full."
	return ""


## Puts a reserve companion in the line at `index` (default: the front, rightmost). Not someone in the
## infirmary.
func field(c: RunCompanion, index: int = -1) -> bool:
	if field_block_reason(c) != "":
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
	var done := inventory.equip(c, w)
	c.hp = mini(c.hp, c.max_hp())   # an enchantment that gave Health is no longer in hand
	return done


# ---------------------------------------------------------------- battle and boss days

## Why the day's battle cannot start on `front`, or "".
func battle_block_reason(front: Front) -> String:
	if is_over():
		return "The run is over."
	if committed_front != null:
		return BATTLE_BEGUN
	if not fronts.has(front):
		return "That front is not open today."
	if lineup.is_empty():
		return "Field at least one companion." if not available().is_empty() else NOBODY_TO_FIELD
	return ""


const NOBODY_TO_FIELD := "Everyone is in the infirmary: nobody can march out."


## Why today cannot be given up (yield_day), or "". Only on a battle or boss day before its battle,
## and only when nobody can be fielded (everyone is in the infirmary).
func yield_block_reason() -> String:
	if is_over():
		return "The run is over."
	if not is_fight_day():
		return "Only on a battle, elite or boss day."
	if committed_front != null:
		return BATTLE_BEGUN
	if fronts.is_empty():
		return "No front is open today."
	if not available().is_empty():
		return "Someone can still be fielded."
	return ""


## Gives the day up when nobody can be fielded: counts exactly as a lost battle at the worst front
## (the one that would cost the walls most; on a boss day the boss, and the city falls). The day ends.
## Returns the report (won false, no XP), or null if not allowed.
func yield_day() -> BattleReport:
	if yield_block_reason() != "":
		return null
	var worst: Front = fronts[0]
	for f in fronts:
		if f.city_damage > worst.city_damage or (f.city_damage == worst.city_damage and f.danger > worst.danger):
			worst = f
	var report := BattleReport.new()
	report.front = worst
	report.won = false
	report.yielded = true
	battles_lost += 1
	if worst.is_boss:
		_end(Outcome.DEFEAT, "%s broke through on day %d: nobody could march out." % [worst.group.display_name, day])
	else:
		report.city_damage = mini(worst.city_damage, city_health)
		city_health -= report.city_damage
	_end_day()
	report.run_over = is_over()
	return report


## Commits to a front and returns the battle to fight there, with the fielded companions at their
## current HP and full stamina. Report the result with finish_battle(). An enchanting offer still open
## is closed first: the weapon keeps what it has (as at the day's end).
func start_battle(front: Front) -> Battle:
	if battle_block_reason(front) != "":
		return null
	if enchant_offer != null:
		keep_enchant()
	committed_front = front
	var battle_rng := RandomNumberGenerator.new()
	battle_rng.seed = rng.randi()
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for c in lineup:
		datas.append(c.data)
		party.append(c.progress)
	var battle := Battle.new(datas, front.enemies, battle_rng, party, art_pool, spell_pool)
	battle.elite = front.is_elite
	battle.allow_retreat = not front.is_boss
	for i in lineup.size():
		battle.roster[i].hp = clampi(lineup[i].hp, 1, lineup[i].max_hp())
	return battle


## What can be said of `front` before it is chosen, for the line as it stands (BattleAccount.before): the
## hardest blow there against the line, and the scouts' word for the fight. Nothing in the run changes
## and none of its dice are rolled: the battle it looks at is a throwaway. {} when nobody is in the line.
func front_account(front: Front) -> Dictionary:
	if front == null or lineup.is_empty() or front.enemies.is_empty():
		return {}
	var datas: Array[CompanionData] = []
	var party: Array[CompanionProgress] = []
	for c in lineup:
		datas.append(c.data)
		party.append(c.progress)
	var look := RandomNumberGenerator.new()
	look.seed = 1
	var battle := Battle.new(datas, front.enemies, look, party, art_pool, spell_pool)
	battle.elite = front.is_elite
	for i in lineup.size():
		battle.roster[i].hp = clampi(lineup[i].hp, 1, lineup[i].max_hp())
	return BattleAccount.before(battle)


## Applies a finished battle from start_battle() to the run and ends the day.
func finish_battle(battle: Battle) -> BattleReport:
	var front := committed_front
	if front == null or battle == null or not battle.is_over():
		return null
	var report := BattleReport.new()
	report.front = front
	report.won = battle.outcome == Battle.Outcome.VICTORY
	report.retreated = battle.retreated
	report.account = battle.account.lines(battle)
	battle.learn_after_battle()   # the battle did it when it ended; harmless again
	report.grade_ups = battle.grade_ups.duplicate()
	var fielded := lineup.duplicate()
	var standing: Array[RunCompanion] = []
	var points: Array[int] = []
	for i in fielded.size():
		var c: RunCompanion = fielded[i]
		var unit := battle.roster[i]
		if unit.is_injured():
			report.injured.append(c.display_name())
			_to_infirmary(c)
		else:
			c.hp = clampi(unit.hp, 1, c.max_hp())
		# Everyone fielded shares the XP of a win, injured or not.
		standing.append(c)
		points.append(battle.points_of(unit))
		report.points[c.display_name()] = battle.points_of(unit)
	if report.won:
		battles_won += 1
		_grant_xp(report, front.xp_pool, standing, points)
		_grant_reserve_xp(report, front.xp_pool)
		# Weapons that pay for kills (WeaponData.gold_per_kill): only on a win.
		for i in fielded.size():
			var unit := battle.roster[i]
			var w := unit.weapon()
			if w != null and w.gold_per_kill > 0 and battle.kills_of(unit) > 0:
				var earned := battle.kills_of(unit) * w.gold_per_kill
				report.kill_gold += earned
				report.kill_gold_by[fielded[i].display_name()] = earned
		report.materials = front.reward_materials.duplicate()
		report.gem = add_gem(front.gem)
		_battle_won_traits(report, battle, fielded)
		report.gold = front.reward_gold + report.kill_gold + report.trait_gold
		gold += report.gold
		_add_materials(report.materials)
		if front.is_boss and day >= RunConfig.DAYS:
			_end(Outcome.VICTORY, "The last boss has fallen. The city stands.")
		elif front.is_boss:
			report.weapon_found = _boss_weapon()
			if report.weapon_found != null:
				inventory.add(report.weapon_found)
	else:
		battles_lost += 1
		_battle_material_traits(report, fielded)
		_add_materials(report.materials)
		if front.is_boss:
			_end(Outcome.DEFEAT, "%s broke through on day %d." % [front.group.display_name, day])
		else:
			var watch := 0
			for c in reserve():
				var less := -TraitRules.total(c.all_traits(), TraitModifier.Kind.CITY_DAMAGE)
				if less != 0:
					watch += less
					report.trait_lines.append("%s, %s: the walls lose %d less" % [c.display_name(), _trait_name(c, TraitModifier.Kind.CITY_DAMAGE), less])
			report.city_damage = mini(maxi(0, front.city_damage - watch), city_health)
			city_health -= report.city_damage
	committed_front = null
	_end_day()
	report.run_over = is_over()
	return report


# ---------------------------------------------------------------- free days

const EVENT_FIRST := "First answer the matter at the gate."
const NO_USEFUL_DRILL := "Nobody can learn anything from this week's drills."
const NOBODY_FIT := "Nobody is fit to go."
const OFFER_OPEN := "First choose what the smith offers."
const NO_JEWELER := "The jeweler cannot craft until the Jeweler is built up."
const CRAFT_OPEN := "First choose one of the jeweler's designs."
const FILL_EVERY_PLACE := "Fill every place."


## Why the free-day errands cannot be done now, or "": curing, the Mason's Yard (upgrades, swaps) and,
## through free_action_block_reason, rest, repair, drills and scavenging. Only on free days, once the
## day's event is answered. The smithy and the tavern are open on more days: see market_block_reason.
func errand_block_reason() -> String:
	if is_over() or day_type() != RunCalendar.DayType.FREE:
		return "Only on free days."
	if event_pending():
		return EVENT_FIRST
	return ""


const BATTLE_BEGUN := "Today's battle has already begun."


## Why the smithy (buying, enchanting, moving an enchantment) and the tavern (hiring) cannot be used
## now, or "". Open on any day, free, battle or boss, until the run is over: on a free day once the
## day's event is answered, on a battle or boss day until the company marches out (start_battle).
## They cost gold (and ore), never the day's action.
func market_block_reason() -> String:
	if is_over():
		return "The run is over."
	if committed_front != null:
		return BATTLE_BEGUN
	if event_pending():
		return EVENT_FIRST
	return ""


## True for the errands that cost gold but not the day's action (shop, tavern, cure).
static func is_errand(a: FreeAction) -> bool:
	return a == FreeAction.SHOP or a == FreeAction.TAVERN or a == FreeAction.CURE


## True for the smithy and the tavern, open on battle and boss days too (market_block_reason).
static func is_market(a: FreeAction) -> bool:
	return a == FreeAction.SHOP or a == FreeAction.TAVERN


## Why `a` cannot be done now, or "". Rest, repair, train and scavenge share the day's one action; shop,
## tavern and cure are errands and never use it. Shop and tavern follow market_block_reason (any day
## until the march), the rest errand_block_reason (free days).
func free_action_block_reason(a: FreeAction) -> String:
	var why := market_block_reason() if is_market(a) else errand_block_reason()
	if why != "":
		return why
	if not is_errand(a) and actions_used.has(a):
		return "Already done today."
	if not is_errand(a) and actions_left <= 0:
		return "No actions left today."
	match a:
		FreeAction.REST:
			if _everyone_at_full_hp() and not _any_spell_uses_spent():
				return "Everyone is at full health and every spell use is ready."
		FreeAction.TAVERN:
			if tavern_offers.is_empty():
				return "Nobody is looking for work."
		FreeAction.REPAIR:
			if city_health >= max_city_health():
				return "The city is at full health."
			if not _can_pay(repair_cost()):
				return "Needs %s." % cost_text(repair_cost())
		FreeAction.TRAIN:
			if gold < drill_cost():
				return "Needs %d gold." % drill_cost()
			if not _anyone_can_drill():
				return NO_USEFUL_DRILL
		FreeAction.CURE:
			if _infirmary.is_empty():
				return "Nobody is in the infirmary."
		FreeAction.SCAVENGE:
			if available().is_empty():
				return NOBODY_FIT
		FreeAction.CRAFT:
			if facility_level(Facility.JEWELER) < 1:
				return NO_JEWELER
			if gem_total() <= 0:
				return "No stones to set."
	return ""


## Why the smithy (SHOP), tavern (TAVERN) or infirmary (CURE) cannot be used now, or "". The same as
## free_action_block_reason for them: the smithy and the tavern on any day until the march
## (market_block_reason), the infirmary on free days; the event first, and their own checks (someone
## to hire, someone to cure). They never use the day's action.
func visit_block_reason(a: FreeAction) -> String:
	return free_action_block_reason(a)


## Every companion not in the infirmary recovers to full HP and every spell's uses. Besides Rest, spell
## uses come back only on leaving the infirmary (see _release) and, a use a night, with the Inn's level
## 2. Rest does nothing for anyone in the infirmary and never shortens a stay.
func rest() -> bool:
	if free_action_block_reason(FreeAction.REST) != "":
		return false
	_spend(FreeAction.REST)
	for c in available():
		c.hp = c.max_hp()
		c.progress.restore_spell_uses()
	return true


# ---------------------------------------------------------------- the infirmary: curing

## Gold to cure `c` now: days still to serve x (RunConfig.CURE_GOLD_PER_DAY_BASE +
## RunConfig.CURE_GOLD_PER_DAY_PER_LEVEL x level). 0 if they are not in the infirmary.
func cure_cost(c: RunCompanion) -> int:
	if c == null or not c.injured:
		return 0
	var cost := c.days_left(day) * (RunConfig.CURE_GOLD_PER_DAY_BASE + RunConfig.CURE_GOLD_PER_DAY_PER_LEVEL * c.level())
	var percent := TraitRules.total(c.all_traits(), TraitModifier.Kind.CURE_PERCENT)
	if facility_level(Facility.INFIRMARY) >= 2:
		percent -= RunConfig.INFIRMARY_CURE_DISCOUNT_PERCENT
	if percent != 0:
		cost = roundi(cost * maxi(0, 100 + percent) / 100.0)
	return cost


## Why `c` cannot be cured now, or "". Curing is a free-day errand (FreeAction.CURE): gold only, never
## the day's action.
func cure_block_reason(c: RunCompanion) -> String:
	var why := free_action_block_reason(FreeAction.CURE)
	if why != "" and why != "Nobody is in the infirmary.":
		return why
	if c == null or not roster.has(c) or not c.injured:
		return "%s is not in the infirmary." % (c.display_name() if c != null else "Nobody")
	if gold < cure_cost(c):
		return "Needs %d gold." % cure_cost(c)
	return ""


## Pays cure_cost(c) gold: `c` comes out of the infirmary at once, at full HP with every spell's uses
## back, onto the bench (and can be fielded the same day). Does not use the day's action; any number a day.
func cure(c: RunCompanion) -> bool:
	if cure_block_reason(c) != "":
		return false
	gold -= cure_cost(c)
	_release(c)
	return true


func repair() -> bool:
	if free_action_block_reason(FreeAction.REPAIR) != "":
		return false
	_spend(FreeAction.REPAIR)
	_pay(repair_cost())
	city_health = mini(max_city_health(), city_health + repair_amount())
	return true


## What the smithy sells this week (bought on any day until the march; see market_block_reason).
func shop_stock() -> Array[ShopItemData]:
	return shop_week


func buy_block_reason(item: ShopItemData) -> String:
	var why := visit_block_reason(FreeAction.SHOP)
	if why != "":
		return why
	if item == null or not shop_stock().has(item):
		return "Not for sale this week."
	if gold < shop_price(item):
		return "Needs %d gold." % shop_price(item)
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
## next week. Costs gold only, never the day's action.
func buy(item: ShopItemData) -> OwnedWeapon:
	if buy_block_reason(item) != "":
		return null
	gold -= shop_price(item)
	shop_week.erase(item)
	return inventory.add(item.weapon)


func hire_block_reason(data: CompanionData) -> String:
	var why := visit_block_reason(FreeAction.TAVERN)
	if why != "":
		return why
	if not tavern_offers.has(data):
		return "Not at the tavern this week."
	if gold < hire_cost():
		return "Needs %d gold." % hire_cost()
	return ""


## Hires a companion offered at the tavern. They join with what they have practised outside the
## company (offer_progress: proficiency, arts, spells) and their traits, at the roster's average level
## (rounded down) with the stat gains for those levels rolled now, at full HP, with their own weapon,
## and are fielded if the line has room (on a battle or boss day they march out with it). Costs gold
## only, never the day's action.
func hire(data: CompanionData) -> RunCompanion:
	if hire_block_reason(data) != "":
		return null
	gold -= hire_cost()
	var traits := offer_traits(data)
	var practised := _outside_progress(data)
	tavern_offers.erase(data)
	var level := hire_level()
	var c := _join(data, practised)
	c.traits = traits
	_outside.erase(data)
	while c.level() < level:
		Levels.level_up(c.progress, rng)
	c.hp = c.max_hp()
	return c


# ---------------------------------------------------------------- the training ground

## Why `c` cannot take `drill` today, or "". Not someone in the infirmary. A drill uses the day's free
## action (FreeAction.TRAIN)
## and RunConfig.DRILL_COST gold. A proficiency drill needs a grade below S in its weapon type or
## school (from E it opens a new one: a fighter can become a caster this way); Sparring needs a level
## below the top. Anyone in the
## roster can train, fielded or not.
func drill_block_reason(drill: Drill, c: RunCompanion) -> String:
	var why := free_action_block_reason(FreeAction.TRAIN)
	if why != "" and why != NO_USEFUL_DRILL:
		return why
	if drill == null or not drills.has(drill):
		return "Not posted this week."
	if c == null or not roster.has(c):
		return "Not in the company."
	if c.injured:
		return infirmary_block_reason(c)
	return _drill_unfit_reason(drill, c)


## Takes `drill` with `c`: spends the free action and RunConfig.DRILL_COST gold and rolls the quality
## (RunConfig.DRILL_QUALITY_WEIGHTS). A proficiency drill adds RunConfig.DRILL_POINTS[quality] points
## (every grade reached teaches an art or a spell as in battle); Sparring grants drill_xp(quality) XP
## (level-ups as in battle). The drill stays posted. Returns what happened, or null if not allowed.
func train(drill: Drill, c: RunCompanion) -> DrillResult:
	if drill_block_reason(drill, c) != "":
		return null
	_spend(FreeAction.TRAIN)
	var paid := drill_cost()
	gold -= paid
	var r := DrillResult.new()
	r.drill = drill
	r.companion = c
	r.gold_spent = paid
	r.quality = _roll_drill_quality(c)
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
		# From E a drill opens a new weapon type or school; only S is the end.
		var g := drill.grade_of(c.progress)
		if g >= Proficiency.max_grade():
			return "%s is already at %s in %s." % [c.display_name(), Proficiency.grade_name(g), drill.subject_name()]
	elif c.level() >= RunConfig.MAX_LEVEL:
		return "%s is already at the top level." % c.display_name()
	return ""


func _anyone_can_drill() -> bool:
	for d in drills:
		for c in available():
			if _drill_unfit_reason(d, c) == "":
				return true
	return false


## A drill's quality by RunConfig.DRILL_QUALITY_WEIGHTS; poor comes out good with the Drill Yard's level
## 1 or for `c` with a trait that says so (Yard Rat).
func _roll_drill_quality(c: RunCompanion = null) -> DrillResult.Quality:
	var total := 0
	for w in RunConfig.DRILL_QUALITY_WEIGHTS:
		total += w
	var r := rng.randi_range(1, total)
	for q in RunConfig.DRILL_QUALITY_WEIGHTS.size():
		r -= RunConfig.DRILL_QUALITY_WEIGHTS[q]
		if r <= 0:
			if q == DrillResult.Quality.POOR and (facility_level(Facility.YARD) >= 1
					or (c != null and TraitRules.has(c.all_traits(), TraitModifier.Kind.DRILL_NEVER_POOR))):
				return DrillResult.Quality.GOOD   # the Drill Yard level 1: never poor
			return q as DrillResult.Quality
	return DrillResult.Quality.GOOD


func _drill_proficiency(r: DrillResult) -> void:
	var p := r.companion.progress
	var drill := r.drill
	r.grade_before = drill.grade_of(p)
	r.points_gained = drill.add_points(p, drill_points(drill, r.companion, r.quality))
	r.grade_after = drill.grade_of(p)
	# Every grade reached teaches as in battle (Battle._gain_proficiency, Battle._gain_magic).
	for g in range(r.grade_before + 1, r.grade_after + 1):
		var up := _teach(p, drill, g)
		up["actor"] = r.companion
		r.grade_ups.append(up)


## XP and level-ups as a won battle grants them (see _grant_xp).
func _drill_sparring(r: DrillResult) -> void:
	var c := r.companion
	r.level_before = c.level()
	r.stats_before = c.progress.stats()
	r.xp_gained = Levels.with_traits(c.progress, drill_xp(r.quality))
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
	# Mentor (TraitModifier.Who.LOWEST): the lowest-level companion in the line (the first of them in
	# line order) gets more, from everyone else's Mentor.
	var lowest: RunCompanion = null
	for c in standing:
		if lowest == null or c.level() < lowest.level():
			lowest = c
	var mentored := 0
	for c in standing:
		if c != lowest:
			mentored += TraitRules.total(c.all_traits(), TraitModifier.Kind.XP_PERCENT, -1, -1, 0, 0, "", TraitModifier.Who.LOWEST)
	for i in standing.size():
		var c := standing[i]
		var xp := Levels.with_traits(c.progress, shares[i], mentored if c == lowest else 0)
		report.xp_gained[c.display_name()] = xp
		for up in Levels.add_xp(c.progress, xp, rng):
			c.hp += int(up.gains.get(Stat.HP, 0))
			report.level_ups.append({"name": c.display_name(), "level": up.level, "gains": up.gains})


# ---------------------------------------------------------------- scavenging

## Today's places beyond the walls (RunConfig.SCAVENGE_SITES_PER_DAY, rolled when the day begins);
## empty on battle and boss days and once the run is over. At least one can be filled by everyone
## available when the day began (if anyone was).
func scavenge_sites() -> Array[ScavengeSite]:
	if is_over() or day_type() != RunCalendar.DayType.FREE:
		return []
	return _scavenge_sites.duplicate()


## The target of a place testing `stat` at `risk` on day `d`: the typical companion's stat that day
## (RunConfig.SCAVENGE_STAT_BASE + GROWTH x (the typical level - 1), the typical level being
## 1 + SCAVENGE_LEVEL_PER_DAY x (d - 1)), rounded, plus the risk's shift.
static func scavenge_target(stat: String, risk: int, d: int) -> int:
	var level := 1.0 + RunConfig.SCAVENGE_LEVEL_PER_DAY * (d - 1)
	var typical := float(RunConfig.SCAVENGE_STAT_BASE.get(stat, 0.0)) \
		+ float(RunConfig.SCAVENGE_STAT_GROWTH.get(stat, 0.0)) * (level - 1.0)
	return roundi(typical) + RunConfig.SCAVENGE_RISK_TARGET_SHIFT[risk]


## A full haul's gold for a site of `size` and `risk` on day `d` (see RunConfig.SCAVENGE_GOLD_SHARE).
static func scavenge_gold(size: int, risk: int, d: int) -> int:
	var growth := 1.0 + RunConfig.REWARD_GROWTH_PER_DAY * (d - 1)
	return roundi(RunConfig.REWARD_GOLD_BY_DANGER[0] * growth * RunConfig.SCAVENGE_GOLD_SHARE
		* RunConfig.SCAVENGE_GOLD_SIZE_MULT[size - 1] * RunConfig.SCAVENGE_GOLD_RISK_MULT[risk])


## XP each companion sent gets from a full haul on day `d` (see RunConfig.SCAVENGE_XP_SHARE).
static func scavenge_xp(d: int) -> int:
	return roundi(float(xp_pool(1, d)) / RunConfig.MAX_FIELDED * RunConfig.SCAVENGE_XP_SHARE)


## How `c` in place `index` of `site` adds to the chance: they meet the target: RunConfig.SCAVENGE_MEET
## + SCAVENGE_PER_POINT_ABOVE a point above (at most SCAVENGE_SLOT_MAX); short of it:
## -SCAVENGE_PER_POINT_SHORT a point (at least SCAVENGE_SLOT_MIN). Nobody there: SCAVENGE_EMPTY.
func scavenge_slot_score(site: ScavengeSite, index: int, c: RunCompanion) -> int:
	if site == null or index < 0 or index >= site.slots.size() or c == null:
		return RunConfig.SCAVENGE_EMPTY
	var slot := site.slots[index]
	var have := scavenge_stat(c, slot.stat)
	if have >= slot.target:
		return mini(RunConfig.SCAVENGE_SLOT_MAX, RunConfig.SCAVENGE_MEET + RunConfig.SCAVENGE_PER_POINT_ABOVE * (have - slot.target))
	return maxi(RunConfig.SCAVENGE_SLOT_MIN, -RunConfig.SCAVENGE_PER_POINT_SHORT * (slot.target - have))


## What `c` counts as in `stat` when scavenging: the stat (CompanionProgress.stats) plus what their traits
## add (Pathfinder).
func scavenge_stat(c: RunCompanion, stat: String) -> int:
	return int(c.progress.stats().get(stat, 0)) + TraitRules.total(c.all_traits(), TraitModifier.Kind.SCAVENGE_STAT)


## The chance (percent) of a full haul at `site` with `party` (indexed by slot; nulls and missing
## entries are empty places): RunConfig.SCAVENGE_BASE_CHANCE by risk + the average slot score,
## rounded, clamped to SCAVENGE_CHANCE_MIN..MAX.
func scavenge_chance(site: ScavengeSite, party: Array) -> int:
	if site == null or site.slots.is_empty():
		return 0
	var total := 0
	for i in site.slots.size():
		total += scavenge_slot_score(site, i, party[i] if i < party.size() else null)
	var chance: int = RunConfig.SCAVENGE_BASE_CHANCE[site.risk] + roundi(float(total) / site.slots.size())
	return clampi(chance, RunConfig.SCAVENGE_CHANCE_MIN, RunConfig.SCAVENGE_CHANCE_MAX)


## Why `party` (indexed by slot, may hold nulls) cannot be sent to `site` now, or "". The day's one
## action (FreeAction.SCAVENGE): free days, after the event, not once the action is spent. Every place
## filled, each by a different companion of the roster who is not in the infirmary.
func scavenge_block_reason(site: ScavengeSite, party: Array) -> String:
	var why := free_action_block_reason(FreeAction.SCAVENGE)
	if why != "":
		return why
	if site == null or not _scavenge_sites.has(site):
		return "That place is not on today's map."
	if party.size() > site.slots.size():
		return "Only %d can go." % site.slots.size()
	var seen: Array[RunCompanion] = []
	for i in site.slots.size():
		var c: RunCompanion = party[i] if i < party.size() else null
		if c == null:
			continue
		if not roster.has(c):
			return "%s is not in the company." % c.display_name()
		if c.injured:
			return infirmary_block_reason(c)
		if seen.has(c):
			return "%s cannot fill two places." % c.display_name()
		seen.append(c)
	if seen.size() < site.slots.size():
		return FILL_EVERY_PLACE
	return ""


## Sends `party` (indexed by slot) to `site`: spends the day's action and rolls once against
## scavenge_chance. At or under it, a full haul: the site's gold, materials and XP to each, and with
## its weapon_chance a weapon (see _draw_found_weapon). Otherwise, RunConfig.SCAVENGE_HALF_CHANCE of
## the time half a haul (half the gold, materials rounded down, half the XP, no weapon), else nothing.
## Low risk: nothing else. Medium: on nothing everyone sent loses RunConfig.SCAVENGE_HP_LOSS_FRACTION of
## max HP (never below 1). High: on half a haul everyone sent loses it; on nothing the one furthest
## short of their place's target (ties, or nobody short: at random) is injured and goes to the
## infirmary as after a battle, and the others lose it. XP and level-ups as in battle. Returns what
## happened, or null if not allowed.
func scavenge(site: ScavengeSite, party: Array) -> ScavengeResult:
	if scavenge_block_reason(site, party) != "":
		return null
	_spend(FreeAction.SCAVENGE)
	var r := ScavengeResult.new()
	r.site = site
	for i in site.slots.size():
		r.party.append(party[i])
	r.chance = scavenge_chance(site, party)
	r.roll = rng.randi_range(1, 100)
	if r.roll <= r.chance:
		r.outcome = ScavengeResult.Outcome.FULL
	elif rng.randi_range(1, 100) <= RunConfig.SCAVENGE_HALF_CHANCE:
		r.outcome = ScavengeResult.Outcome.HALF
	else:
		r.outcome = ScavengeResult.Outcome.NOTHING
	var xp := 0
	match r.outcome:
		ScavengeResult.Outcome.FULL:
			r.gold = site.gold
			r.materials = site.materials.duplicate()
			xp = site.xp_each
			if site.weapon_chance > 0 and rng.randi_range(1, 100) <= site.weapon_chance:
				r.weapon_found = _draw_found_weapon()
				if r.weapon_found != null:
					inventory.add(r.weapon_found)
			if rng.randi_range(1, 100) <= RunConfig.SCAVENGE_GEM_PERCENT:
				r.gem = add_gem(gem_rank_now())
		ScavengeResult.Outcome.HALF:
			r.gold = site.gold / 2
			for m: String in site.materials:
				if int(site.materials[m]) / 2 > 0:
					r.materials[m] = int(site.materials[m]) / 2
			xp = site.xp_each / 2
	var more := 0
	for c in r.party:
		more += TraitRules.total(c.all_traits(), TraitModifier.Kind.SCAVENGE_HAUL_PERCENT)
	if more != 0:
		r.gold = roundi(r.gold * (100 + more) / 100.0)
		for m: String in r.materials:
			r.materials[m] = roundi(int(r.materials[m]) * (100 + more) / 100.0)
	gold += r.gold
	_add_materials(r.materials)
	var hurt := (site.risk == ScavengeSite.Risk.MEDIUM and r.outcome == ScavengeResult.Outcome.NOTHING) \
		or (site.risk == ScavengeSite.Risk.HIGH and r.outcome != ScavengeResult.Outcome.FULL)
	if site.risk == ScavengeSite.Risk.HIGH and r.outcome == ScavengeResult.Outcome.NOTHING:
		r.injured = _furthest_short(site, r.party)
	for i in r.party.size():
		var c := r.party[i]
		var m := ScavengeResult.Member.new()
		m.companion = c
		m.slot = i
		m.level_before = c.level()
		m.stats_before = c.progress.stats()
		r.members.append(m)
		if c == r.injured:
			m.hp_lost = c.hp
			_to_infirmary(c)
		elif hurt:
			var before := c.hp
			c.hp = maxi(1, c.hp - ceili(c.max_hp() * RunConfig.SCAVENGE_HP_LOSS_FRACTION))
			m.hp_lost = before - c.hp
		if xp > 0:
			_scavenge_xp(m, xp)
	return r


## The one sent who is furthest short of their place's target; ties (and nobody short) at random.
func _furthest_short(site: ScavengeSite, party: Array[RunCompanion]) -> RunCompanion:
	var worst := 0
	var picks: Array[RunCompanion] = []
	for i in party.size():
		if TraitRules.has(party[i].all_traits(), TraitModifier.Kind.SCAVENGE_NO_INJURY):
			continue   # Sure-Footed: never comes back injured
		var short := maxi(0, site.slots[i].target - scavenge_stat(party[i], site.slots[i].stat))
		if picks.is_empty() or short > worst:
			worst = short
			picks = [party[i]]
		elif short == worst:
			picks.append(party[i])
	if picks.is_empty():
		return null
	return picks[rng.randi_range(0, picks.size() - 1)]


## XP and level-ups as a won battle grants them, recorded like Sparring (see _drill_sparring).
func _scavenge_xp(m: ScavengeResult.Member, amount: int) -> void:
	var c := m.companion
	amount = Levels.with_traits(c.progress, amount)
	m.xp_gained = amount
	var stats := m.stats_before.duplicate()
	var from := c.level()
	for up in Levels.add_xp(c.progress, amount, rng):
		c.hp += int(up.gains.get(Stat.HP, 0))
		m.level_ups.append({"name": c.display_name(), "level": up.level, "gains": up.gains, "level_from": from,
			"before": stats.duplicate()})
		for key: String in up.gains:
			stats[key] = int(stats.get(key, 0)) + int(up.gains[key])
		from = up.level


## Rolls today's sites. If nobody available could fill either, the first is rolled again with a size
## that fits.
func _roll_scavenge_sites() -> void:
	_scavenge_sites.clear()
	var names: Array[String] = ScavengeSite.NAMES.duplicate()
	var count := RunConfig.SCAVENGE_SITES_PER_DAY + (RunConfig.GATE_EXTRA_SITES if facility_level(Facility.GATE) >= 1 else 0)
	for i in count:
		var site_name: String = names.pop_at(rng.randi_range(0, names.size() - 1)) if not names.is_empty() else "The Wilds"
		_scavenge_sites.append(_roll_site(site_name, 3))
	var fit := available().size()
	if fit > 0 and not _scavenge_sites.is_empty() \
			and _scavenge_sites.all(func(s: ScavengeSite) -> bool: return s.size > fit):
		_scavenge_sites[0] = _roll_site(_scavenge_sites[0].display_name, fit)


## One site called `site_name` of size at most `max_size`: size and risk by
## RunConfig.SCAVENGE_SIZE_WEIGHTS and SCAVENGE_RISK_WEIGHTS, one place per size point with different
## stats, and the haul.
func _roll_site(site_name: String, max_size: int) -> ScavengeSite:
	var site := ScavengeSite.new()
	site.display_name = site_name
	var size_weights: Array = RunConfig.SCAVENGE_SIZE_WEIGHTS.slice(0, clampi(max_size, 1, RunConfig.SCAVENGE_SIZE_WEIGHTS.size()))
	site.size = _roll_weighted(size_weights) + 1
	site.risk = _roll_weighted(RunConfig.SCAVENGE_RISK_WEIGHTS) as ScavengeSite.Risk
	var stats: Array[String] = ScavengeSite.ROLE_STATS.duplicate()
	for i in site.size:
		var slot := ScavengeSite.Slot.new()
		slot.stat = stats.pop_at(rng.randi_range(0, stats.size() - 1))
		slot.target = scavenge_target(slot.stat, site.risk, day)
		slot.role = ScavengeSite.ROLES[slot.stat]
		site.slots.append(slot)
	site.gold = scavenge_gold(site.size, site.risk, day)
	var span: Array = RunConfig.SCAVENGE_MATERIALS_BY_SIZE[site.size - 1]
	for p in rng.randi_range(int(span[0]), int(span[1])):
		var m: String = RunConfig.MATERIAL_ORDER[rng.randi_range(0, RunConfig.MATERIAL_ORDER.size() - 1)]
		site.materials[m] = int(site.materials.get(m, 0)) + 1
	site.weapon_chance = RunConfig.SCAVENGE_WEAPON_CHANCE[site.risk]
	site.xp_each = scavenge_xp(day)
	return site


## An index into `weights`, drawn by weight (the last with any weight if the draw falls off the end).
func _roll_weighted(weights: Array) -> int:
	var total := 0
	var last := 0
	for i in weights.size():
		total += int(weights[i])
		if int(weights[i]) > 0:
			last = i
	var r := rng.randi_range(1, maxi(1, total))
	for i in weights.size():
		r -= int(weights[i])
		if r <= 0 and int(weights[i]) > 0:
			return i
	return last


# ---------------------------------------------------------------- the city's facilities

## The level of facility `f` (0: not built; at most facility_max_level()).
func facility_level(f: Facility) -> int:
	return int(facilities.get(f, 0))


static func facility_max_level() -> int:
	return RunConfig.FACILITY_MAX_LEVEL


static func facility_name(f: Facility) -> String:
	return FACILITY_NAMES[f]


## What level `level` (1 or 2) of facility `f` does, one short line ("" for other levels).
static func facility_lines(f: Facility, level: int) -> String:
	if level < 1 or level > FACILITY_LINES[f].size():
		return ""
	return FACILITY_LINES[f][level - 1]


## What the next level of `f` costs (material id -> amount); empty when it is built to the full.
func upgrade_cost(f: Facility) -> Dictionary:
	var level := facility_level(f)
	if level >= RunConfig.FACILITY_MAX_LEVEL:
		return {}
	return {RunConfig.FACILITY_MATERIAL[f]: RunConfig.UPGRADE_COST[level]}


## Why `f` cannot be built up now, or "". An errand: free days once the event is answered, never the
## day's action; one level at a time, level 1 before level 2.
func upgrade_block_reason(f: Facility) -> String:
	var why := errand_block_reason()
	if why != "":
		return why
	if facility_level(f) >= RunConfig.FACILITY_MAX_LEVEL:
		return "The %s is built to the full." % FACILITY_NAMES[f]
	var cost := upgrade_cost(f)
	if not _can_pay(cost):
		return "Needs %s." % cost_text(cost)
	return ""


## Pays upgrade_cost(f) and raises `f` one level. It works at once (see _on_upgrade).
func upgrade(f: Facility) -> bool:
	if upgrade_block_reason(f) != "":
		return false
	_pay(upgrade_cost(f))
	facilities[f] = facility_level(f) + 1
	_on_upgrade(f, facility_level(f))
	return true


## What an upgrade changes the moment it is paid for: a Tavern offer, a drill or a scavenging site
## more today, Infirmary stays already running a day shorter, tomorrow's fronts read from the
## Watchtower, the lost-front cost of fronts already rolled.
func _on_upgrade(f: Facility, level: int) -> void:
	match [f, level]:
		[Facility.WATCHTOWER, 2]:
			_roll_tomorrow()
		[Facility.TAVERN, 1]:
			_offer_more(RunConfig.TAVERN_EXTRA_OFFERS)
		[Facility.INFIRMARY, 1]:
			var less := RunConfig.INFIRMARY_DAYS - RunConfig.INFIRMARY_UPGRADED_DAYS
			for c in _infirmary:
				c.back_on_day = maxi(day + 1, c.back_on_day - less)
		[Facility.YARD, 2]:
			_post_more_drills(RunConfig.YARD_EXTRA_DRILLS)
		[Facility.GATE, 1]:
			if day_type() == RunCalendar.DayType.FREE and not is_over():
				var names: Array[String] = []
				for n in ScavengeSite.NAMES:
					if not _scavenge_sites.any(func(s: ScavengeSite) -> bool: return s.display_name == n):
						names.append(n)
				for i in RunConfig.GATE_EXTRA_SITES:
					var site_name: String = names.pop_at(rng.randi_range(0, names.size() - 1)) if not names.is_empty() else "The Wilds"
					_scavenge_sites.append(_roll_site(site_name, 3))
		[Facility.GATE, 2]:
			for fr in _next_fronts:
				if not fr.is_boss:
					fr.city_damage = front_city_damage(fr.danger)


## The most city health the walls hold (the Mason's Yard level 2 raises it).
func max_city_health() -> int:
	return RunConfig.MASON_CITY_MAX_HEALTH if facility_level(Facility.MASON) >= 2 else RunConfig.CITY_MAX_HEALTH


## What mending the walls costs (material id -> amount).
func repair_cost() -> Dictionary:
	return RunConfig.REPAIR_COST.duplicate()


## City health one repair mends (the Mason's Yard level 1 raises it).
func repair_amount() -> int:
	return (RunConfig.MASON_REPAIR_AMOUNT if facility_level(Facility.MASON) >= 1 else RunConfig.REPAIR_AMOUNT) \
		+ company_total(TraitModifier.Kind.REPAIR_AMOUNT)


## Gold a hire costs this week: RunConfig.HIRE_COST + RunConfig.HIRE_COST_PER_WEEK x (week - 1) (week 1:
## 100, week 6: 150), then the Tavern's level 2 and the company's traits (Well-Liked) lower it, never
## below 0. One price for everyone that week.
func hire_cost() -> int:
	var base := RunConfig.HIRE_COST + RunConfig.HIRE_COST_PER_WEEK * (RunCalendar.week_of(day) - 1)
	return maxi(0, base - (RunConfig.TAVERN_HIRE_DISCOUNT if facility_level(Facility.TAVERN) >= 2 else 0)
		+ company_total(TraitModifier.Kind.HIRE_COST))


## Gold a drill costs: RunConfig.DRILL_COST and the company's traits (Drillmaster), never below 0.
func drill_cost() -> int:
	return maxi(0, RunConfig.DRILL_COST + company_total(TraitModifier.Kind.DRILL_COST))


## What the smithy asks for `item`: its price, changed by the company's traits (Haggler), rounded.
func shop_price(item: ShopItemData) -> int:
	if item == null:
		return 0
	var percent := company_total(TraitModifier.Kind.SHOP_PERCENT)
	return item.price if percent == 0 else maxi(0, roundi(item.price * (100 + percent) / 100.0))


## Gold `choice` changes: as written, but a cost is changed by the company's traits (Silver Tongue),
## rounded, never past 0.
func choice_gold(choice: EventChoiceData) -> int:
	if choice == null:
		return 0
	if choice.gold >= 0:
		return choice.gold
	var percent := company_total(TraitModifier.Kind.EVENT_GOLD_PERCENT)
	return -maxi(0, roundi(-choice.gold * (100 + percent) / 100.0))


## City health a lost front of `danger` costs (the Gate level 2 lowers it).
func front_city_damage(danger: int) -> int:
	var less := RunConfig.GATE_CITY_DAMAGE_LESS if facility_level(Facility.GATE) >= 2 else 0
	return maxi(0, RunConfig.CITY_DAMAGE_BY_DANGER[danger - 1] - less)


## Why `from_id` cannot be swapped for `to_id` at the Mason's Yard now, or "". An errand.
func swap_block_reason(from_id: String, to_id: String) -> String:
	var why := errand_block_reason()
	if why != "":
		return why
	if not RunConfig.MATERIAL_ORDER.has(from_id) or not RunConfig.MATERIAL_ORDER.has(to_id) or from_id == to_id:
		return "Choose two different materials."
	if material(from_id) < RunConfig.SWAP_GIVE:
		return "Needs %d %s." % [RunConfig.SWAP_GIVE, RunConfig.MATERIAL_NAMES[from_id]]
	return ""


## RunConfig.SWAP_GIVE of `from_id` for RunConfig.SWAP_GET of `to_id`; any number of times.
func swap(from_id: String, to_id: String) -> bool:
	if swap_block_reason(from_id, to_id) != "":
		return false
	materials[from_id] = material(from_id) - RunConfig.SWAP_GIVE
	materials[to_id] = material(to_id) + RunConfig.SWAP_GET
	return true


# ---------------------------------------------------------------- the watch

## What the watch knows: true once the Watchtower has its level 1. Until then the boss days ahead are
## not marked (upcoming shows them as battle days) and the bosses are not named (boss_on is null for a
## day ahead, boss_days_ahead holds at most today).
func boss_days_known() -> bool:
	return facility_level(Facility.WATCHTOWER) >= 1


## The type of day `d` (default today) as the watch sees it: a boss day ahead shows as a battle day
## until the Watchtower knows the boss days. Today, and the past, as they are.
func seen_day_type(d: int = -1) -> int:
	var at := day if d < 0 else d
	var t := day_type(at)
	if t == RunCalendar.DayType.BOSS and at > day and not boss_days_known():
		return RunCalendar.DayType.BATTLE
	return t


## Tomorrow's fronts, rolled a day early once the Watchtower has its level 2 (they are the fronts
## tomorrow brings); empty otherwise, or when tomorrow is not a battle, elite or boss day.
func tomorrow_fronts() -> Array[Front]:
	if facility_level(Facility.WATCHTOWER) < 2 or _next_fronts_day != day + 1 or is_over():
		return []
	return _next_fronts.duplicate()


## Rolls tomorrow's fronts now, when the Watchtower has its level 2.
func _roll_tomorrow() -> void:
	var d := day + 1
	if facility_level(Facility.WATCHTOWER) < 2 or is_over() or d > calendar.size() or _next_fronts_day == d:
		return
	_next_fronts.clear()
	_next_fronts_day = 0
	match day_type(d):
		RunCalendar.DayType.BATTLE:
			_next_fronts = _roll_fronts(d)
			_next_fronts_day = d
		RunCalendar.DayType.ELITE:
			_next_fronts = _roll_elite_fronts(d)
			_next_fronts_day = d
		RunCalendar.DayType.BOSS:
			_next_fronts = [_make_boss_front(d)]
			_next_fronts_day = d


# ---------------------------------------------------------------- the Jeweler: crafting

## What crafting with a stone of `rank` costs: the stone ("gem": its rank) and
## RunConfig.CRAFT_GOLD_PER_RANK x the rank in "gold".
func craft_cost(rank: int) -> Dictionary:
	return {"gem": rank, "gold": RunConfig.CRAFT_GOLD_PER_RANK * rank}


## Why a stone of `rank` cannot be set now, or "". The day's free action (FreeAction.CRAFT) at the Jeweler
## once it has its level 1: a free day, the event answered, the action not used; a stone of that rank and
## the gold; not while designs wait for a choice.
func craft_block_reason(rank: int) -> String:
	if craft_offer != null:
		return CRAFT_OPEN
	var why := free_action_block_reason(FreeAction.CRAFT)
	if why != "":
		return why
	if not Gem.is_rank(rank):
		return "No such stone."
	if gem_count(rank) <= 0:
		return "No %s to set." % Gem.name_of(rank)
	var g := int(craft_cost(rank)["gold"])
	if gold < g:
		return "Needs %d gold." % g
	return ""


## Pays craft_cost(rank) and the day's action and shows the designs: one type drawn evenly from every
## type (RunConfig.CRAFT_DESIGNS_BY_JEWELER: two different ones with the Jeweler's level 2), kept in
## craft_offer until one is taken (take_craft). The same type can come up again in a run. Returns the
## offer, or null if not allowed.
func craft(rank: int) -> CraftOffer:
	if craft_block_reason(rank) != "":
		return null
	var offer := CraftOffer.new()
	offer.rank = rank
	offer.cost = craft_cost(rank)
	gold -= int(offer.cost["gold"])
	gems[rank] = gem_count(rank) - 1
	_spend(FreeAction.CRAFT)
	var count: int = RunConfig.CRAFT_DESIGNS_BY_JEWELER[clampi(facility_level(Facility.JEWELER) - 1, 0,
		RunConfig.CRAFT_DESIGNS_BY_JEWELER.size() - 1)]
	var pool := accessory_pool.duplicate()
	for i in mini(count, pool.size()):
		offer.designs.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	craft_offer = offer
	return offer


## Makes design `index` of the open offer with its stone: the accessory goes into the company's keeping,
## unworn (accessories). Returns it, or null if there is no such offer or design.
func take_craft(index: int) -> Accessory:
	if craft_offer == null or index < 0 or index >= craft_offer.designs.size():
		return null
	var a := Accessory.new(craft_offer.designs[index], craft_offer.rank)
	accessories.append(a)
	craft_offer = null
	return a


# ---------------------------------------------------------------- accessories: wearing

## What `c` wears, in the order put on.
func accessories_of(c: RunCompanion) -> Array[Accessory]:
	var out: Array[Accessory] = []
	if c != null:
		out.assign(c.progress.accessories)
	return out


## Who wears `a`, or null (unworn). Anyone in the company, in the Infirmary or not.
func wearer_of(a: Accessory) -> RunCompanion:
	for c in roster:
		if c.progress.accessories.has(a):
			return c
	return null


## The accessories nobody wears.
func unworn_accessories() -> Array[Accessory]:
	var out: Array[Accessory] = []
	for a in accessories:
		if wearer_of(a) == null:
			out.append(a)
	return out


## Why `c` cannot put `a` on now, or "". Free, any number of times, whenever the party can be changed
## (not once the day's front is committed); at most RunConfig.MAX_ACCESSORIES each, never two of one
## type. Whoever wears it now gives it up.
func wear_block_reason(c: RunCompanion, a: Accessory) -> String:
	if not can_change_party():
		return "Not now."
	if c == null or not roster.has(c):
		return "Not in the company."
	if a == null or not accessories.has(a):
		return "Not the company's."
	var worn := c.progress.accessories
	if worn.has(a):
		return "%s already wears it." % c.display_name()
	for b in worn:
		if b.type == a.type:
			return "%s already wears a %s." % [c.display_name(), a.type.display_name]
	if worn.size() >= RunConfig.MAX_ACCESSORIES:
		return "%s already wears two." % c.display_name()
	return ""


## Puts `a` on `c`, taking it from whoever wore it. HP rises by any Health it adds (and spell uses by any
## it adds), as with an enchantment.
func wear(c: RunCompanion, a: Accessory) -> bool:
	if wear_block_reason(c, a) != "":
		return false
	var from := wearer_of(a)
	if from != null:
		_remove_accessory(from, a)
	var hp_before := c.max_hp()
	var uses_before := _max_uses_of(c)
	c.progress.accessories.append(a)
	if not c.injured:
		c.hp = clampi(c.hp + maxi(0, c.max_hp() - hp_before), 1, c.max_hp())
	for sp: SpellData in uses_before:
		var more := c.progress.max_uses(sp) - int(uses_before[sp])
		if more > 0:
			c.progress.spell_uses[sp] = c.progress.uses_left(sp) + more
	return true


## Why `a` cannot be taken off now, or "": not worn, or the party cannot be changed.
func take_off_block_reason(a: Accessory) -> String:
	if not can_change_party():
		return "Not now."
	if wearer_of(a) == null:
		return "Nobody wears it."
	return ""


## Takes `a` off whoever wears it (in the Infirmary too); it stays the company's. HP and spell uses are
## held to the new most.
func take_off(a: Accessory) -> bool:
	if take_off_block_reason(a) != "":
		return false
	_remove_accessory(wearer_of(a), a)
	return true


func _remove_accessory(c: RunCompanion, a: Accessory) -> void:
	c.progress.accessories.erase(a)
	if not c.injured:
		c.hp = clampi(c.hp, 1, c.max_hp())
	for sp in c.progress.known_spells:
		c.progress.spell_uses[sp] = mini(c.progress.uses_left(sp), c.progress.max_uses(sp))


func _max_uses_of(c: RunCompanion) -> Dictionary:
	var out := {}
	for sp in c.progress.known_spells:
		out[sp] = c.progress.max_uses(sp)
	return out


# ---------------------------------------------------------------- enchanting

## The stat points an enchantment of `w` adds up to (net): by tier (RunConfig.ENCHANT_BUDGET_BY_TIER,
## wooden 1 .. platinum 6), a rare weapon RunConfig.ENCHANT_RARE_BUDGET.
static func enchant_budget(w: OwnedWeapon) -> int:
	if w == null or w.data == null:
		return 0
	if w.data.is_rare():
		return RunConfig.ENCHANT_RARE_BUDGET
	return RunConfig.ENCHANT_BUDGET_BY_TIER[clampi(w.data.tier, 0, RunConfig.ENCHANT_BUDGET_BY_TIER.size() - 1)]


## What one attempt on `w` costs, first or again: RunConfig.ENCHANT_ORE iron ore and
## RunConfig.ENCHANT_GOLD_PER_TIER x the tier (at least 1) gold; a rare weapon RunConfig.ENCHANT_RARE_GOLD
## ("gold").
func enchant_cost(w: OwnedWeapon) -> Dictionary:
	var g := RunConfig.ENCHANT_GOLD_PER_TIER
	if w != null and w.data != null:
		g = RunConfig.ENCHANT_RARE_GOLD if w.data.is_rare() else RunConfig.ENCHANT_GOLD_PER_TIER * maxi(1, w.data.tier)
	return {RunConfig.IRON_ORE: RunConfig.ENCHANT_ORE, "gold": g}


## Why `w` cannot be enchanted now, or "". At the Smithy once it has its level 1, on any day until the
## march (market_block_reason); any weapon the company owns, in hand or in the armory, plain or
## enchanted (then it is tried again); not while an offer waits for a choice.
func enchant_block_reason(w: OwnedWeapon) -> String:
	var why := market_block_reason()
	if why != "":
		return why
	if facility_level(Facility.SMITHY) < 1:
		return "The smithy cannot enchant until it is built up."
	if enchant_offer != null:
		return OFFER_OPEN
	if w == null or not inventory.weapons.has(w):
		return "That weapon is not the company's."
	var cost := enchant_cost(w)
	if not _can_afford(cost):
		return "Needs %s." % _cost_with_gold(cost)
	return ""


## One attempt: pays enchant_cost(w) and makes an offer of new rolls (one; two with the Smithy's level
## 2; see roll_enchant), kept in `enchant_offer` until the player takes one (take_enchant) or keeps what
## the weapon has (keep_enchant). Returns the offer, or null if not allowed.
func enchant(w: OwnedWeapon) -> EnchantOffer:
	if enchant_block_reason(w) != "":
		return null
	var offer := EnchantOffer.new()
	offer.weapon = w
	offer.current = w.enchant_stats.duplicate()
	offer.cost = enchant_cost(w)
	_pay_with_gold(offer.cost)
	var count: int = RunConfig.ENCHANT_ROLLS_BY_SMITHY[clampi(facility_level(Facility.SMITHY) - 1, 0, RunConfig.ENCHANT_ROLLS_BY_SMITHY.size() - 1)]
	for i in count:
		offer.rolls.append(roll_enchant(enchant_budget(w)))
	enchant_offer = offer
	return offer


## The weapon of the open offer takes its roll `index`. Returns false if there is no such offer or roll.
func take_enchant(index: int) -> bool:
	if enchant_offer == null or index < 0 or index >= enchant_offer.rolls.size():
		return false
	_set_enchant(enchant_offer.weapon, enchant_offer.rolls[index])
	enchant_offer = null
	return true


## The weapon of the open offer keeps what it has (plain stays plain; the cost is spent). False if no
## offer is open.
func keep_enchant() -> bool:
	if enchant_offer == null:
		return false
	enchant_offer = null
	return true


## A new enchantment of `budget` net points: each point +1 to a stat drawn at random from all eleven
## (the same can come up again). With RunConfig.ENCHANT_TWO_EDGED_PERCENT, and only when the budget is 2
## or more, it is two-edged: one stat drawn at random takes -k (k drawn evenly from 1 to budget / 2,
## rounded down) and k more points are rolled, none of them on that stat. The net is always the budget;
## at most one stat is negative.
func roll_enchant(budget: int) -> Dictionary:
	var out := {}
	var keys: Array[String] = Stat.COMPANION_KEYS.duplicate()
	var k := 0
	if budget >= 2 and rng.randi_range(1, 100) <= RunConfig.ENCHANT_TWO_EDGED_PERCENT:
		var bad: String = keys.pop_at(rng.randi_range(0, keys.size() - 1))
		k = rng.randi_range(1, budget / 2)
		out[bad] = -k
	for i in budget + k:
		var key: String = keys[rng.randi_range(0, keys.size() - 1)]
		out[key] = int(out.get(key, 0)) + 1
	return out


## Puts `stats` on `w` (empty: plain) and passes it to the holder: HP rises by any Health it adds over
## what the weapon gave, and is held to the new max.
func _set_enchant(w: OwnedWeapon, stats: Dictionary) -> void:
	var before := int(w.enchant_stats.get(Stat.HP, 0))
	w.enchant_stats = stats.duplicate()
	inventory.refresh(w)
	if w.holder != null:
		var gained := maxi(0, int(stats.get(Stat.HP, 0)) - before)
		w.holder.hp = clampi(w.holder.hp + gained, 1, w.holder.max_hp())


## What moving an enchantment costs (material id -> amount).
func move_enchant_cost() -> Dictionary:
	return RunConfig.MOVE_ENCHANT_COST.duplicate()


## Why `from`'s enchantment cannot be moved to `to` now, or "". At the Smithy (level 1), on any day
## until the march (market_block_reason): both the company's, the same weapon type, `from` enchanted,
## `to` plain with at least `from`'s budget.
func move_enchant_block_reason(from: OwnedWeapon, to: OwnedWeapon) -> String:
	var why := market_block_reason()
	if why != "":
		return why
	if facility_level(Facility.SMITHY) < 1:
		return "The smithy cannot enchant until it is built up."
	if enchant_offer != null:
		return OFFER_OPEN
	if from == null or to == null or not inventory.weapons.has(from) or not inventory.weapons.has(to):
		return "That weapon is not the company's."
	if from == to:
		return "Choose another weapon to move it to."
	if not from.is_enchanted():
		return "%s has no enchantment." % from.data.display_name
	if to.is_enchanted():
		return "%s is already enchanted." % to.title()
	if from.data.weapon_type != to.data.weapon_type:
		return "Only to a weapon of the same type (%s)." % WeaponData.type_name(from.data.weapon_type).to_lower()
	if enchant_budget(to) < enchant_budget(from):
		return "%s cannot hold an enchantment that strong." % to.data.display_name
	if not _can_pay(move_enchant_cost()):
		return "Needs %s." % cost_text(move_enchant_cost())
	return ""


## Moves `from`'s whole enchantment to `to` for move_enchant_cost().
func move_enchant(from: OwnedWeapon, to: OwnedWeapon) -> bool:
	if move_enchant_block_reason(from, to) != "":
		return false
	_pay(move_enchant_cost())
	var stats := from.enchant_stats.duplicate()
	_set_enchant(from, {})
	_set_enchant(to, stats)
	return true


func _can_afford(cost: Dictionary) -> bool:
	if gold < int(cost.get("gold", 0)):
		return false
	for m in RunConfig.MATERIAL_ORDER:
		if material(m) < int(cost.get(m, 0)):
			return false
	return true


func _pay_with_gold(cost: Dictionary) -> void:
	gold -= int(cost.get("gold", 0))
	for m in RunConfig.MATERIAL_ORDER:
		if cost.has(m):
			materials[m] = material(m) - int(cost[m])


## "2 Iron Ore and 40 gold".
static func _cost_with_gold(cost: Dictionary) -> String:
	var text := cost_text(cost)
	var g := int(cost.get("gold", 0))
	if g > 0:
		text = ("%s and %d gold" % [text, g]) if text != "" else "%d gold" % g
	return text


# ---------------------------------------------------------------- traits

## The traits of `data` standing in the tavern this week (shown before hiring): rolled the first time
## they were offered this run and the same every week after. Empty if they are not offered now.
func offer_traits(data: CompanionData) -> Array[TraitData]:
	var out: Array[TraitData] = []
	if tavern_offers.has(data):
		out.assign(_rolled_traits.get(data, []))
	return out


## What `data`, offered at the tavern this week, would join with before the hire's level-ups: their
## proficiency, arts and spells as practised outside the company, and their traits. Null if they are
## not offered now. Read it only; it is the run's own copy.
func offer_progress(data: CompanionData) -> CompanionProgress:
	if data == null or not tavern_offers.has(data):
		return null
	return _outside_progress(data)


## The one state of `d` outside the company (see _outside).
func _outside_progress(d: CompanionData) -> CompanionProgress:
	if not _outside.has(d):
		_outside[d] = CompanionProgress.create(d)
	return _outside[d]


## At each weekly restock after the first, everyone outside the company practises (see _practise), in
## the order of the companions in the content, offered or not.
func _practise_outside() -> void:
	for d in content.companions:
		if not _in_roster(d):
			_practise(_outside_progress(d))


## One week's practice for `p`: RunConfig.TAVERN_PRACTICE_MIN..MAX points, RunConfig.TAVERN_PRACTICE_MAIN_PERCENT
## of them (rounded up) in what they fight with (a caster: the school of their own spell; others: the
## type of the weapon they carry), the rest in one other weapon type or school they already have above
## E, drawn at random (all of it in the main one if there is none). Each grade reached teaches an art
## or a spell as in battle; an art learned with every slot full goes into a slot in place of a random
## equipped one, or stays unequipped, by chance (one of slots + 1). Returns the grade-ups, shaped like
## DrillResult.grade_ups but without "actor".
func _practise(p: CompanionProgress) -> Array[Dictionary]:
	var ups: Array[Dictionary] = []
	var n := rng.randi_range(RunConfig.TAVERN_PRACTICE_MIN, RunConfig.TAVERN_PRACTICE_MAX)
	var main := Drill.magic(p.data.signature_spell.school) if p.data.is_mage() else Drill.weapon(p.weapon.weapon_type)
	var others: Array[Drill] = []
	for wt: int in WeaponData.WeaponType.values():
		if p.grade(wt) > Proficiency.Grade.E and not (main.kind == Drill.Kind.WEAPON and main.weapon_type == wt):
			others.append(Drill.weapon(wt))
	for s: int in SpellData.School.values():
		if p.magic_grade(s) > Proficiency.Grade.E and not (main.kind == Drill.Kind.MAGIC and main.school == s):
			others.append(Drill.magic(s))
	var main_n := n if others.is_empty() else ceili(n * RunConfig.TAVERN_PRACTICE_MAIN_PERCENT / 100.0)
	ups.append_array(_practise_in(p, main, main_n))
	if main_n < n:
		ups.append_array(_practise_in(p, others[rng.randi_range(0, others.size() - 1)], n - main_n))
	return ups


func _practise_in(p: CompanionProgress, subject: Drill, amount: int) -> Array[Dictionary]:
	var ups: Array[Dictionary] = []
	var before := subject.grade_of(p)
	subject.add_points(p, amount)
	for g in range(before + 1, subject.grade_of(p) + 1):
		var up := _teach(p, subject, g)
		if up.get("art") != null and not up["equipped"]:
			var k := rng.randi_range(0, p.equipped_arts.size())
			if k < p.equipped_arts.size():
				up["equipped"] = p.swap(p.equipped_arts[k], up["art"])
		ups.append(up)
	return ups


## What reaching grade `g` in `subject` teaches `p`, as in battle (Battle._gain_proficiency,
## Battle._gain_magic): a weapon type an art (equipped if a slot is free), a school a spell. Learns it
## and returns the grade-up entry without "actor".
func _teach(p: CompanionProgress, subject: Drill, g: int) -> Dictionary:
	if subject.kind == Drill.Kind.WEAPON:
		var art := ArtLearning.pick_art(rng, p, subject.weapon_type, g, art_pool)
		var equipped := p.learn(art) if art != null else false
		return {"magic": false, "weapon_type": subject.weapon_type, "grade": g, "art": art, "equipped": equipped}
	var spell := SpellLearning.pick_spell(rng, p, subject.school, g, spell_pool)
	if spell != null:
		p.learn_spell(spell)
	return {"magic": true, "school": subject.school, "grade": g, "spell": spell}


## Days `c` stays in the Infirmary when injured: RunConfig.INFIRMARY_DAYS plus what their traits add.
func infirmary_days(c: RunCompanion) -> int:
	var base := RunConfig.INFIRMARY_UPGRADED_DAYS if facility_level(Facility.INFIRMARY) >= 1 else RunConfig.INFIRMARY_DAYS
	return maxi(1, base + TraitRules.total(c.all_traits(), TraitModifier.Kind.INFIRMARY_DAYS))


## HP `c` heals at the end of the day: RunConfig.DAILY_HEAL_FRACTION of max HP, changed by their traits
## (TraitModifier.Kind.DAY_HEAL_PERCENT), rounded up.
func day_heal(c: RunCompanion) -> int:
	var percent := TraitRules.total(c.all_traits(), TraitModifier.Kind.DAY_HEAL_PERCENT)
	var fraction := RunConfig.INN_DAILY_HEAL_FRACTION if facility_level(Facility.INN) >= 1 else RunConfig.DAILY_HEAL_FRACTION
	var points := TraitRules.total(c.all_traits(), TraitModifier.Kind.DAY_HEAL_SHARE) \
		+ company_total(TraitModifier.Kind.DAY_HEAL_SHARE, TraitModifier.Who.COMPANY)
	fraction += points / 100.0
	return maxi(0, ceili(c.max_hp() * fraction * (100 + percent) / 100.0))


## The sum of `kind` over everyone in the company not in the Infirmary (the city's traits, and those
## meant for the whole company: `who` TraitModifier.Who.COMPANY).
func company_total(kind: int, who: int = TraitModifier.Who.SELF) -> int:
	var total := 0
	for c in available():
		total += TraitRules.total(c.all_traits(), kind, -1, -1, 0, 0, "", who)
	return total


## Points a proficiency drill of `quality` gives `c`: RunConfig.DRILL_POINTS, changed by their traits
## for that weapon type or school (TraitModifier.Kind.PROFICIENCY_PERCENT), rounded.
func drill_points(drill: Drill, c: RunCompanion, quality: int) -> int:
	var base: int = RunConfig.DRILL_POINTS[quality]
	if drill == null or c == null or not drill.is_proficiency():
		return base
	var percent := TraitRules.total(c.all_traits(), TraitModifier.Kind.PROFICIENCY_PERCENT,
		drill.weapon_type if drill.kind == Drill.Kind.WEAPON else -1, drill.school if drill.kind == Drill.Kind.MAGIC else -1,
		0, 0, "", TraitModifier.Who.SELF, c.progress)
	return roundi(base * (100 + percent) / 100.0)


## XP Sparring of `quality` gives `c` today: drill_xp, changed by their traits (Levels.with_traits).
func drill_xp_for(c: RunCompanion, quality: int) -> int:
	return Levels.with_traits(c.progress, drill_xp(quality)) if c != null else drill_xp(quality)


## 1 to 3 traits for a companion joining (or offered at the tavern) whose progress is `p`, by
## RunConfig.TRAIT_COUNT_WEIGHTS; each drawn by rarity (RunConfig.TRAIT_RARITY_WEIGHTS) from those
## nobody in the run has, never two of the same line of a family, never two two-edged ones. A trait
## tied to a weapon type or school is, RunConfig.TRAIT_FIT_PERCENT of the time, one they can already
## use (see _trait_fits): drawn one they cannot, it is swapped for one of the same line they can (or any
## tied one they can). The traits are taken from the pool.
func _roll_traits(p: CompanionProgress) -> Array[TraitData]:
	var out: Array[TraitData] = []
	var n := _roll_weighted(RunConfig.TRAIT_COUNT_WEIGHTS) + 1
	for i in n:
		var t := _draw_trait(p, out)
		if t == null:
			break
		out.append(t)
		_traits_taken.append(t)
	return out


func _draw_trait(p: CompanionProgress, have: Array[TraitData]) -> TraitData:
	var pool: Array[TraitData] = []
	var lines := {}
	var two_edged := false
	for t in have:
		lines[t.line_key()] = true
		two_edged = two_edged or t.is_two_edged()
	for t in trait_pool:
		if _traits_taken.has(t) or have.has(t) or lines.has(t.line_key()) or (two_edged and t.is_two_edged()):
			continue
		pool.append(t)
	if pool.is_empty():
		return null
	var pick := _pick_by_rarity(pool)
	if pick.is_tied() and rng.randi_range(1, 100) <= RunConfig.TRAIT_FIT_PERCENT and not _trait_fits(pick, p):
		var same_line := pool.filter(func(t: TraitData) -> bool:
			return t.is_tied() and t.line_key() == pick.line_key() and _trait_fits(t, p))
		var any_fit := pool.filter(func(t: TraitData) -> bool: return t.is_tied() and _trait_fits(t, p))
		var options: Array = same_line if not same_line.is_empty() else any_fit
		if not options.is_empty():
			var typed: Array[TraitData] = []
			typed.assign(options)
			pick = _pick_by_rarity(typed)
	return pick


func _pick_by_rarity(pool: Array[TraitData]) -> TraitData:
	var weights: Array = []
	for t in pool:
		weights.append(RunConfig.TRAIT_RARITY_WEIGHTS[t.rarity])
	return pool[_roll_weighted(weights)]


## True if `p` can already use what `t` is tied to: a grade above E in its weapon type or school.
## Untied traits always fit.
static func _trait_fits(t: TraitData, p: CompanionProgress) -> bool:
	if t.weapon_type >= 0:
		return p.grade(t.weapon_type) > Proficiency.Grade.E
	if t.school >= 0:
		return p.magic_grade(t.school) > Proficiency.Grade.E
	return true


## After a won battle: what the fielded companions' traits bring (TraitModifier.Kind.BATTLE_WON_GOLD for
## each who fought, KILL_GOLD for each enemy they felled, BATTLE_MATERIAL, BATTLE_WON_HEAL_PERCENT for
## those still standing), into the report.
func _battle_won_traits(report: BattleReport, battle: Battle, fielded: Array) -> void:
	for i in fielded.size():
		var c: RunCompanion = fielded[i]
		var g := TraitRules.total(c.all_traits(), TraitModifier.Kind.BATTLE_WON_GOLD)
		if g != 0:
			report.trait_gold += g
			report.trait_lines.append("%s, %s: +%d gold" % [c.display_name(), _trait_name(c, TraitModifier.Kind.BATTLE_WON_GOLD), g])
		var per := TraitRules.total(c.all_traits(), TraitModifier.Kind.KILL_GOLD)
		var k := battle.kills_of(battle.roster[i])
		if per != 0 and k > 0:
			report.trait_gold += per * k
			report.trait_lines.append("%s, %s: +%d gold" % [c.display_name(), _trait_name(c, TraitModifier.Kind.KILL_GOLD), per * k])
		var mend := TraitRules.total(c.all_traits(), TraitModifier.Kind.BATTLE_WON_HEAL_PERCENT)
		if mend > 0 and not c.injured:
			var healed := c.heal(ceili(c.max_hp() * mend / 100.0))
			if healed > 0:
				report.trait_lines.append("%s, %s: +%d HP" % [c.display_name(), _trait_name(c, TraitModifier.Kind.BATTLE_WON_HEAL_PERCENT), healed])
	_battle_material_traits(report, fielded)


## After a battle, won or lost: materials the fielded companions' traits bring (BATTLE_MATERIAL).
func _battle_material_traits(report: BattleReport, fielded: Array) -> void:
	for c: RunCompanion in fielded:
		for t in c.all_traits():
			for m in t.modifiers:
				if m.kind == TraitModifier.Kind.BATTLE_MATERIAL and m.who == TraitModifier.Who.SELF and m.material != "" and m.amount > 0:
					report.materials[m.material] = int(report.materials.get(m.material, 0)) + m.amount
					report.trait_lines.append("%s, %s: +%d %s" % [c.display_name(), t.display_name, m.amount,
						RunConfig.MATERIAL_NAMES.get(m.material, m.material)])


## The name of `c`'s first trait with a modifier of `kind` ("" if none).
static func _trait_name(c: RunCompanion, kind: int) -> String:
	for t in c.all_traits():
		for m in t.modifiers:
			if m.kind == kind:
				return t.display_name
	return ""


## The Barracks level 1: everyone on the bench (not fielded, not in the infirmary) gets a share of a won
## battle's XP: RunConfig.BARRACKS_RESERVE_XP_SHARE of an even share (pool / MAX_FIELDED), rounded,
## changed by their traits. In report.reserve_xp; level-ups in report.level_ups.
## Bench Learner (TraitModifier.Kind.RESERVE_XP_SHARE) adds its share to the Barracks' (or gives one
## without it).
func _grant_reserve_xp(report: BattleReport, pool: int) -> void:
	for c in reserve():
		var share := (RunConfig.BARRACKS_RESERVE_XP_SHARE if facility_level(Facility.BARRACKS) >= 1 else 0.0) \
			+ TraitRules.total(c.all_traits(), TraitModifier.Kind.RESERVE_XP_SHARE) / 100.0
		if share <= 0.0:
			continue
		var xp := Levels.with_traits(c.progress, roundi(float(pool) / RunConfig.MAX_FIELDED * share))
		if xp <= 0:
			continue
		report.reserve_xp[c.display_name()] = xp
		for up in Levels.add_xp(c.progress, xp, rng):
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
	if choice_gold(choice) < 0 and gold < -choice_gold(choice):
		return "Needs %d gold." % -choice_gold(choice)
	var cost := {}
	for m: String in choice.materials:
		if int(choice.materials[m]) < 0:
			cost[m] = -int(choice.materials[m])
	if not _can_pay(cost):
		return "Needs %s." % cost_text(cost)
	return ""


## Applies an event choice; the free day then goes on. Returns the result text, or "" if not allowed.
func choose(choice: EventChoiceData) -> String:
	if choice_block_reason(choice) != "":
		return ""
	gold += choice_gold(choice)
	_add_materials(choice.materials)
	city_health = clampi(city_health + choice.city_health, 0, max_city_health())
	if choice.companion_hp != 0:
		for c in hp_targets(choice):
			c.heal(choice.companion_hp)
	var gained := choice_weapon(choice)
	if gained != null:
		inventory.add(gained)
	var stone := add_gem(choice_gem(choice))
	event = null
	event_weapons.clear()
	if city_health <= 0:
		_end(Outcome.DEFEAT, "The city fell on day %d." % day)
	var text := choice.result_text if choice.result_text != "" else choice.label
	return text.replace("{weapon}", gained.display_name if gained != null else "weapon") \
		.replace("{gem}", Gem.name_of(stone) if stone > 0 else "stone")


## The companions a choice's HP change would apply to.
## Never anyone in the infirmary.
func hp_targets(choice: EventChoiceData) -> Array[RunCompanion]:
	if choice.hp_target == EventChoiceData.HpTarget.ALL:
		return available()
	var best: RunCompanion = null
	for c in available():
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
	released_today.clear()
	for c in _infirmary.duplicate():
		if c.back_on_day <= day:
			_release(c)
			released_today.append(c)
	fronts.clear()
	committed_front = null
	event = null
	event_weapons.clear()
	actions_left = 0
	actions_used.clear()
	_scavenge_sites.clear()
	if RunCalendar.is_week_start(day):
		_restock_week()
	var early := _next_fronts.duplicate() if _next_fronts_day == day else []
	_next_fronts.clear()
	_next_fronts_day = 0
	match day_type():
		RunCalendar.DayType.BATTLE:
			fronts.assign(early if not early.is_empty() else _roll_fronts(day))
		RunCalendar.DayType.ELITE:
			fronts.assign(early if not early.is_empty() else _roll_elite_fronts(day))
		RunCalendar.DayType.BOSS:
			fronts.assign(early if not early.is_empty() else [_make_boss_front(day)])
		RunCalendar.DayType.FREE:
			actions_left = RunConfig.FREE_DAY_ACTIONS
			if has_event_day():
				event = _pick_event()
				_draw_event_weapons()
			_roll_scavenge_sites()
	_roll_tomorrow()


func _end_day() -> void:
	if enchant_offer != null:
		keep_enchant()   # the day ends: the weapon keeps what it has
	if craft_offer != null:
		take_craft(0)   # the day ends: the first design is made
	for c in available():
		c.heal(day_heal(c))
		if facility_level(Facility.INN) >= 2:
			for sp in c.progress.known_spells:
				c.progress.spell_uses[sp] = mini(c.progress.max_uses(sp), c.progress.uses_left(sp) + RunConfig.INN_USES_PER_NIGHT)
	if facility_level(Facility.BARRACKS) >= 2:
		for c in reserve():
			c.hp = c.max_hp()
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


## Two or three fronts of different danger for day `d`. Three fronts are always danger 1, 2 and 3; two
## are two different dangers.
func _roll_fronts(d: int) -> Array[Front]:
	var out: Array[Front] = []
	var dangers: Array[int] = [1, 2, 3]
	if rng.randf() >= RunConfig.THREE_FRONTS_CHANCE:
		dangers.remove_at(rng.randi_range(0, 2))
	var sites := content.sites.duplicate()
	for danger in dangers:
		var options := content.groups_for(danger, d)
		if options.is_empty():
			continue
		out.append(_make_front(danger, _pick_group(options, d), d, sites))
	return out


## An elite day's fronts: exactly two, both of the highest danger (3), of two different groups where
## the day has two, each giving the day's gemstone when won (gem_for_fight).
func _roll_elite_fronts(d: int) -> Array[Front]:
	var out: Array[Front] = []
	var sites := content.sites.duplicate()
	var options := content.groups_for(3, d)
	for i in 2:
		if options.is_empty():
			break
		var group := _pick_group(options, d)
		if options.size() > 1:
			options.erase(group)
		var f := _make_front(3, group, d, sites)
		for j in f.enemies.size():
			f.enemies[j] = elite_enemy(f.enemies[j], RunCalendar.elite_index(d))
		f.is_elite = true
		f.gem = gem_for_fight(d)
		out.append(f)
	return out


## One front of `danger` against `group` on day `d`, at a site taken from `sites`: its enemies grown
## for the day, its gold, material odds, cost to the walls and XP by danger.
func _make_front(danger: int, group: EnemyGroupData, d: int, sites: Array) -> Front:
	var f := Front.new()
	f.danger = danger
	f.group = group
	f.site = sites.pop_at(rng.randi_range(0, sites.size() - 1)) if not sites.is_empty() else null
	for e in f.group.enemies:
		f.enemies.append(scaled_enemy(e, d))
	var growth := 1.0 + RunConfig.REWARD_GROWTH_PER_DAY * (d - 1)
	var spread := rng.randf_range(1.0 - RunConfig.REWARD_GOLD_SPREAD, 1.0 + RunConfig.REWARD_GOLD_SPREAD)
	f.reward_gold = roundi(RunConfig.REWARD_GOLD_BY_DANGER[danger - 1] * growth * spread)
	if rng.randf() < RunConfig.REWARD_MATERIAL_CHANCE[danger - 1]:
		var m: String = RunConfig.MATERIAL_ORDER[rng.randi_range(0, RunConfig.MATERIAL_ORDER.size() - 1)]
		f.reward_materials[m] = RunConfig.REWARD_MATERIAL_AMOUNT[danger - 1]
	f.city_damage = front_city_damage(danger)
	f.xp_pool = xp_pool(danger, d)
	return f


## A group for a front, favouring the band of the day: a group from an older band is less likely
## (RunConfig.BAND_AGE_WEIGHT), one from a later band never appears (groups' days rule it out).
func _pick_group(options: Array[EnemyGroupData], d: int) -> EnemyGroupData:
	var now := band_of_day(d)
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


func _make_boss_front(d: int) -> Front:
	var index := maxi(0, RunCalendar.boss_index(d))
	var f := Front.new()
	f.is_boss = true
	f.danger = 3
	f.group = boss_draw.get(d)
	if f.group == null:
		_draw_boss(d)
		f.group = boss_draw.get(d)
	# The first enemy is the boss, built for its day; any escorts grow with the day like other enemies.
	for i in f.group.enemies.size():
		var e := f.group.enemies[i]
		f.enemies.append(sized_boss(e) if i == 0 else scaled_enemy(e, d))
	f.reward_gold = RunConfig.BOSS_REWARD_GOLD[clampi(index, 0, RunConfig.BOSS_REWARD_GOLD.size() - 1)]
	if d < RunConfig.DAYS:
		for m in RunConfig.MATERIAL_ORDER:
			f.reward_materials[m] = RunConfig.BOSS_REWARD_MATERIALS
	f.city_damage = 0
	f.xp_pool = RunConfig.BOSS_XP_POOL[clampi(index, 0, RunConfig.BOSS_XP_POOL.size() - 1)]
	f.gem = gem_for_fight(d)
	return f


## A boss as it is fielded: a copy with its Health times RunConfig.BOSS_HP_MULT. Nothing else changes
## (a boss is built for its day).
static func sized_boss(e: EnemyData) -> EnemyData:
	var s := e.duplicate() as EnemyData
	s.max_hp = roundi(e.max_hp * RunConfig.BOSS_HP_MULT)
	return s


## A copy of `e` grown for `day` (see RunConfig enemy scaling): Health times RunConfig.ENEMY_HP_MULT on
## any day, then the day's growth. On day 1 the other stats are unchanged.
static func scaled_enemy(e: EnemyData, on_day: int) -> EnemyData:
	var s := e.duplicate() as EnemyData
	var d := maxi(0, on_day - 1)
	s.max_hp = roundi(e.max_hp * RunConfig.ENEMY_HP_MULT * (1.0 + RunConfig.ENEMY_HP_GROWTH_PER_DAY * d))
	s.strength = e.strength + floori(float(d) / RunConfig.ENEMY_STR_EVERY_DAYS)
	s.magic = e.magic + floori(float(d) / RunConfig.ENEMY_STR_EVERY_DAYS)
	s.defense = e.defense + floori(float(d) / RunConfig.ENEMY_DEF_EVERY_DAYS)
	s.speed = e.speed + floori(float(d) / RunConfig.ENEMY_SPD_EVERY_DAYS)
	s.dexterity = e.dexterity + floori(float(d) / RunConfig.ENEMY_SPD_EVERY_DAYS)
	return s


## An enemy already grown for its day, as an elite fight fields it: tougher by which elite it is
## (RunConfig.ELITE_HP_MULT, ELITE_STR_BONUS; `index` 0 for day 6, 1 for day 20, 2 for day 34).
static func elite_enemy(e: EnemyData, index: int) -> EnemyData:
	var i := clampi(index, 0, RunConfig.ELITE_HP_MULT.size() - 1)
	var s := e.duplicate() as EnemyData
	s.max_hp = roundi(e.max_hp * RunConfig.ELITE_HP_MULT[i])
	s.strength = e.strength + RunConfig.ELITE_STR_BONUS[i]
	s.magic = e.magic + RunConfig.ELITE_STR_BONUS[i]
	return s


## The weekly refresh: the tavern's offers and the smithy's stock for the week that begins today.
func _restock_week() -> void:
	# Unhired offers keep their traits (in _rolled_traits) for when they are offered again.
	tavern_offers.clear()
	if RunCalendar.week_of(day) > 1:
		_practise_outside()
	shop_week.clear()
	_make_tavern_offers()
	_stock_shop()
	_post_drills()


## The week's drills: Sparring, then RunConfig.DRILLS_PROFICIENCY_PER_WEEK different weapon types or
## magic schools drawn at random from the seven subjects, skipping one in which the whole roster is
## already at S (fewer if fewer are left). Listed weapon types first, then schools, each in enum order.
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
	var want := RunConfig.DRILLS_PROFICIENCY_PER_WEEK + (RunConfig.YARD_EXTRA_DRILLS if facility_level(Facility.YARD) >= 2 else 0)
	while picked.size() < want and picked.size() < useful.size():
		var i := rng.randi_range(0, useful.size() - 1)
		if not picked.has(i):
			picked.append(i)
	picked.sort()
	for i in picked:
		drills.append(useful[i])


## `n` more proficiency drills this week (the Drill Yard's level 2, bought mid-week), from the useful
## ones not posted yet; the list stays weapon types first, then schools.
func _post_more_drills(n: int) -> void:
	var options: Array[Drill] = []
	for wt: int in WeaponData.WeaponType.values():
		options.append(Drill.weapon(wt))
	for s: int in SpellData.School.values():
		options.append(Drill.magic(s))
	var fresh: Array[Drill] = []
	for d in options:
		if drills.any(func(x: Drill) -> bool: return x.kind == d.kind and x.weapon_type == d.weapon_type and x.school == d.school):
			continue
		for c in roster:
			if _drill_unfit_reason(d, c) == "":
				fresh.append(d)
				break
	for i in mini(n, fresh.size()):
		drills.append(fresh.pop_at(rng.randi_range(0, fresh.size() - 1)))
	var sparring := drills.filter(func(x: Drill) -> bool: return not x.is_proficiency())
	var rest := drills.filter(func(x: Drill) -> bool: return x.is_proficiency())
	rest.sort_custom(func(a: Drill, b: Drill) -> bool:
		return [a.kind, a.weapon_type, a.school] < [b.kind, b.weapon_type, b.school])
	drills.assign(sparring + rest)


func _make_tavern_offers() -> void:
	var pool: Array[CompanionData] = []
	for d in content.companions:
		if not _in_roster(d):
			pool.append(d)
	var extra := RunConfig.TAVERN_EXTRA_OFFERS if facility_level(Facility.TAVERN) >= 1 else 0
	var count := mini(rng.randi_range(RunConfig.TAVERN_OFFERS_MIN, RunConfig.TAVERN_OFFERS_MAX) + extra, pool.size())
	for i in count:
		_offer(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


## Puts `d` among this week's tavern offers. Their traits are rolled the first time they are offered
## in the run (from CompanionProgress.create(d)); offered again, they keep them and nothing is rolled.
func _offer(d: CompanionData) -> void:
	tavern_offers.append(d)
	if not _rolled_traits.has(d):
		_rolled_traits[d] = _roll_traits(CompanionProgress.create(d))
		_outside_progress(d).traits = _rolled_traits[d]


## When the run begins: one wooden weapon (the ladder's tier 0) of every weapon type the starters'
## own weapons do not already cover goes into the armory, unheld. Hires later add nothing.
func _stock_wooden_armory() -> void:
	for wt: int in WeaponData.WeaponType.values():
		if inventory.weapons.any(func(w: OwnedWeapon) -> bool:
				return w.data.weapon_type == wt and w.data.tier == WeaponData.Tier.WOODEN):
			continue
		var wooden := content.ladder_weapon(WeaponData.Tier.WOODEN, wt)
		if wooden != null:
			inventory.add(wooden)


## `n` more tavern offers this week (the Tavern's level 1, bought mid-week), if anyone is left.
func _offer_more(n: int) -> void:
	var pool: Array[CompanionData] = []
	for d in content.companions:
		if not _in_roster(d) and not tavern_offers.has(d):
			pool.append(d)
	for i in mini(n, pool.size()):
		_offer(pool.pop_at(rng.randi_range(0, pool.size() - 1)))


## The week's stock: with RunConfig.SHOP_RARE_CHANCE one rare weapon whose grade fits the week
## (rare_max_grade), first; then RunConfig.SHOP_WEAPONS_PER_WEEK different weapons, each a tier drawn by the week's weights and then
## (see _random_weapon) a two-proficiency weapon of that tier with RunConfig.SHOP_HYBRID_CHANCE, else
## a ladder weapon of a random type; priced by weapon_price, in order of tier and type.
func _stock_shop() -> void:
	if rng.randf() < RunConfig.SHOP_RARE_CHANCE:
		var rare := _random_rare(rare_max_grade(day))
		if rare != null:
			var item := ShopItemData.new()
			item.weapon = rare
			item.price = weapon_price(rare)
			item.min_day = day
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


## The smithy's price of `w`: a rare weapon's own price; else its tier's price, a two-proficiency weapon
## x RunConfig.HYBRID_PRICE_MULT rounded to the nearest RunConfig.PRICE_ROUND_TO.
static func weapon_price(w: WeaponData) -> int:
	if w.rare and w.price > 0:
		return w.price
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
## maybe a two-proficiency weapon of that tier and type (see _random_weapon); and with
## RunConfig.EVENT_RARE_CHANCE a rare weapon of that type whose grade fits the week instead.
func _draw_event_weapons() -> void:
	event_weapons.clear()
	if event == null:
		return
	for choice in event.choices:
		if not choice.random_weapon:
			continue
		var w := _draw_found_weapon(choice.random_weapon_type)
		if w != null:
			event_weapons[choice] = w


## A weapon found today (an event's random weapon, a scavenging find), of type `type` or any with -1:
## a tier drawn like the week's stock, or with RunConfig.EVENT_WEAPON_TIER_UP_CHANCE one above the best
## the smithy sells; maybe a two-proficiency weapon of that tier and type (see _random_weapon); and with
## RunConfig.EVENT_RARE_CHANCE a rare weapon of that type whose grade fits the week instead. May be null.
func _draw_found_weapon(type: int = -1) -> WeaponData:
	var tier := _roll_tier(shop_tier_weights(day))
	if rng.randf() < RunConfig.EVENT_WEAPON_TIER_UP_CHANCE:
		tier = mini(smithy_top_tier(day) + 1, WeaponData.top_tier())
	var w := _random_weapon(tier, type)
	if rng.randf() < RunConfig.EVENT_RARE_CHANCE:
		var rare := _random_rare(rare_max_grade(day), type)
		if rare != null:
			w = rare
	return w


## The weapon a beaten boss drops (see boss_weapon_tier): any type, at random, maybe a two-proficiency
## one (see _random_weapon); with RunConfig.BOSS_RARE_CHANCE a rare weapon in its place (day 14: one
## needing at most D; day 28: any). Null for the last boss.
func _boss_weapon() -> WeaponData:
	var tier := boss_weapon_tier(day)
	if tier < 0:
		return null
	var w := _random_weapon(tier)
	if rng.randf() < RunConfig.BOSS_RARE_CHANCE:
		var cap: int = RunConfig.BOSS_RARE_MAX_GRADE[clampi(RunCalendar.boss_index(day), 0, RunConfig.BOSS_RARE_MAX_GRADE.size() - 1)]
		var rare := _random_rare(cap)
		if rare != null:
			w = rare
	return w


## The highest grade a rare weapon may need to be sold or given in the week of day `d`
## (RunConfig.RARE_GRADE_BY_WEEK); -1: none that week.
static func rare_max_grade(d: int) -> int:
	var weeks: Array[int] = RunConfig.RARE_GRADE_BY_WEEK
	return weeks[clampi(RunCalendar.week_of(d) - 1, 0, weeks.size() - 1)]


## A random rare weapon needing at most `max_grade` (of type `type`, or any with -1), or null.
func _random_rare(max_grade: int, type: int = -1) -> WeaponData:
	if max_grade < 0:
		return null
	var pool := content.rare_pool(max_grade, type)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


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

func _join(data: CompanionData, progress: CompanionProgress = null) -> RunCompanion:
	var c := RunCompanion.create(data)
	if progress != null:
		c.progress = progress
		c.hp = c.max_hp()
	roster.append(c)
	inventory.add(data.weapon, c)
	if lineup.size() < RunConfig.MAX_FIELDED:
		lineup.append(c)
	return c


## Injured in today's battle: to the infirmary until the start of day + INFIRMARY_DAYS + 1. They leave
## the line; weapon and progress stay.
func _to_infirmary(c: RunCompanion) -> void:
	c.injured = true
	c.hp = 0
	c.back_on_day = day + infirmary_days(c) + 1
	lineup.erase(c)
	if not _infirmary.has(c):
		_infirmary.append(c)


## Out of the infirmary (the stay served, or cured): full HP and every spell's uses back, onto the bench.
func _release(c: RunCompanion) -> void:
	c.injured = false
	c.back_on_day = 0
	c.hp = c.max_hp()
	c.progress.restore_spell_uses()
	_infirmary.erase(c)


func _in_roster(data: CompanionData) -> bool:
	for c in roster:
		if c.data == data:
			return true
	return false


func _any_spell_uses_spent() -> bool:
	for c in available():
		if c.progress.has_spent_uses():
			return true
	return false


func _everyone_at_full_hp() -> bool:
	for c in available():
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
		if int(gain[m]) > 0:
			materials_taken[m] = int(materials_taken.get(m, 0)) + int(gain[m])
