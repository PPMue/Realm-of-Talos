class_name RunConfig
extends RefCounted
## Every tuning number used by the run rules lives here.
## Content (enemy groups, front sites, events, shop stock) lives in the .tres data under res://data/run.

# --- Calendar ---
# See RunCalendar for the shape of a week: battle and free days alternate, the boss every second week.
const DAYS := 42
const WEEK_DAYS := 7                    # the tavern and the smithy restock on the first day of each week
const BOSS_EVERY_DAYS := 14             # a boss ends every second week: days 14, 28, 42
const EVENTS_PER_WEEK := 1              # free days that begin with an event, in every week
const DAYS_SHOWN_AHEAD := 7             # the player always sees the type of the next 7 days

# --- City ---
const CITY_MAX_HEALTH := 100
## City health lost when a battle on a front of danger 1, 2, 3 is lost.
const CITY_DAMAGE_BY_DANGER: Array[int] = [15, 20, 25]

# --- Party ---
const STARTING_COMPANIONS := 2
const MAX_FIELDED := 4
## At the end of every day each surviving companion heals this share of max HP (rounded up).
const DAILY_HEAL_FRACTION := 0.2
## Everyone injured in a battle (won or lost) goes to the infirmary: injured on day D, they are away
## days D+1 .. D+INFIRMARY_DAYS and come out at the start of day D+INFIRMARY_DAYS+1 at full HP.
const INFIRMARY_DAYS := 4
## Curing someone at once (the Cure free-day errand: gold only, never the day's action) costs, in gold, the days still to serve x
## (BASE + PER_LEVEL x their level): level 1 with 4 days left 24, level 10 with 4 days 96.
const CURE_GOLD_PER_DAY_BASE := 4
const CURE_GOLD_PER_DAY_PER_LEVEL := 2

# --- Fronts ---
## Chance a battle day offers three fronts (danger 1, 2 and 3) instead of two.
const THREE_FRONTS_CHANCE := 0.5
## Gold for winning, by danger, on day 1. Grows by REWARD_GROWTH_PER_DAY each day after.
const REWARD_GOLD_BY_DANGER: Array[int] = [40, 70, 110]
const REWARD_GOLD_SPREAD := 0.15        # +/- this share, rolled per front
const REWARD_GROWTH_PER_DAY := 0.021  # day 42 pays x1.86
## Chance the reward also includes materials, and how many, by danger.
const REWARD_MATERIAL_CHANCE: Array[float] = [0.3, 0.6, 1.0]
const REWARD_MATERIAL_AMOUNT: Array[int] = [1, 2, 3]
## Boss rewards, by boss (day 14, 28, 42). The last one ends the run, so it only shows.
const BOSS_REWARD_GOLD: Array[int] = [150, 250, 0]
const BOSS_REWARD_MATERIALS := 3

# --- Bestiary bands ---
# Every normal enemy belongs to a band (EnemyData.band): 1 early, 2 middle, 3 late. A band's enemies
# appear from its first day on; groups never field an enemy before its band begins.
const BAND_FIRST_DAY: Array[int] = [1, 15, 29]   # weeks 1-2, 3-4, 5-6
## How likely a group is to be picked for a front, by how many bands older than the day's band it is:
## the day's own band, one band older, two bands older. Older groups still turn up, scaled to the day.
const BAND_AGE_WEIGHT: Array[float] = [1.0, 0.3, 0.12]

# --- Enemy scaling with the day (normal fronts only; bosses are built for their day) ---
# Assumes companions level at the pace below (about level 13 by day 42, roughly +4 to +6 in each
# main stat), plus better weapons and grades.
const ENEMY_HP_GROWTH_PER_DAY := 0.035  # max HP x (1 + 0.035 x (day - 1)): day 42 is x2.44
const ENEMY_STR_EVERY_DAYS := 5.5       # +1 STR and MAG on days 7, 12, 18, 23, 29, 34, 40 (+7)
const ENEMY_DEF_EVERY_DAYS := 9         # +1 DEF on days 10, 19, 28, 37 (+4)
const ENEMY_SPD_EVERY_DAYS := 11        # +1 SPD and DEX on days 12, 23, 34 (+3)

# --- Levels and XP ---
# A won battle grants an XP pool, shared among the fielded companions still in the run at its end:
# XP_EVEN_SHARE_PERCENT of it evenly, the rest by the contribution points each earned in the battle
# (BattleConfig.POINTS_*; Levels.split_xp). Pace target: fielded in every battle in a party of about
# four with an average share, a companion ends the run around level 12-15 (the level pace test).
const XP_EVEN_SHARE_PERCENT := 25
const XP_POOL_BY_DANGER: Array[int] = [57, 86, 119]
const XP_POOL_GROWTH_PER_DAY := 0.028   # pool x (1 + 0.028 x (day - 1)): day 42 is x2.15
const BOSS_XP_POOL: Array[int] = [220, 320, 420]
## XP to go from level L to L + 1: BASE + STEP x (L - 1).
const XP_PER_LEVEL_BASE := 30
const XP_PER_LEVEL_STEP := 5
const MAX_LEVEL := 20
## At least this many stats rise on every level-up.
const MIN_STAT_GAINS := 2

# --- Materials ---
const IRON_ORE := "iron_ore"
const TIMBER := "timber"
const MATERIAL_NAMES := {IRON_ORE: "Iron Ore", TIMBER: "Timber"}
const MATERIAL_ORDER: Array[String] = [IRON_ORE, TIMBER]

# --- Weapons: the smithy, events and bosses ---
# The smithy's stock is rolled on the first day of each week: this many weapons from the ladder
# (WeaponData.Tier), each of a random type and a tier drawn by the week's weights below, no two the
# same; plus, on a roll of SHOP_RARE_CHANCE, one rare weapon (RunContent.rare_weapons) whose grade fits
# the week (RARE_GRADE_BY_WEEK).
const SHOP_WEAPONS_PER_WEEK := 5
## By week (1-6), the weight of each tier: wooden, bronze, iron, steel, silver, platinum. The highest
## tier with any weight is what the smithy is selling that week (Run.smithy_top_tier).
const SHOP_TIER_WEIGHTS := [
	[35, 65, 0, 0, 0, 0],    # week 1: wooden and bronze
	[10, 50, 40, 0, 0, 0],   # week 2: iron
	[0, 25, 50, 25, 0, 0],   # week 3: steel
	[0, 10, 42, 40, 8, 0],   # week 4: silver, rare
	[0, 0, 30, 50, 20, 0],   # week 5
	[0, 0, 20, 52, 28, 0],   # week 6: never platinum
]
## Price of a ladder weapon, by tier.
const WEAPON_PRICE_BY_TIER: Array[int] = [20, 50, 110, 200, 320, 480]
## Each of the smithy's weekly slots, an event's random weapon and a boss's drop is, with this chance, a
## two-proficiency weapon of the tier rolled (when that tier has any: bronze to silver).
const SHOP_HYBRID_CHANCE := 0.2
## Chance each weekly restock also stocks one rare weapon, drawn from those whose needed grade is at
## most RARE_GRADE_BY_WEEK for that week (-1: none). Grade D from week 2, C from week 3 (every rare).
const SHOP_RARE_CHANCE := 0.35
const RARE_GRADE_BY_WEEK: Array[int] = [-1, 2, 4, 4, 4, 4]
## Chance an event's random weapon is a rare one (with the same weekly grade gate and the event's type).
const EVENT_RARE_CHANCE := 0.15
## Chance the day 14 / day 28 boss drops a rare weapon in place of its usual one, and the highest grade
## it may need, by boss (day 14: D, day 28: any).
const BOSS_RARE_CHANCE := 0.5
const BOSS_RARE_MAX_GRADE: Array[int] = [2, 10]
## A two-proficiency weapon costs its tier's price x this, rounded to the nearest PRICE_ROUND_TO.
const HYBRID_PRICE_MULT := 1.25
const PRICE_ROUND_TO := 5
## An event that grants a weapon draws its tier like the week's stock, but with this chance it is one
## tier above the best the smithy is selling.
const EVENT_WEAPON_TIER_UP_CHANCE := 0.25
## Beating a boss that does not end the run drops one random weapon (any type), this many tiers above
## the best the smithy is selling that week, into the armory.
const BOSS_WEAPON_TIERS_ABOVE_SHOP := 1

# --- Free days ---
const FREE_DAY_ACTIONS := 1
const HIRE_COST := 100
## How many companions the tavern offers (at most; fewer if fewer are left to hire).
const TAVERN_OFFERS_MIN := 1
const TAVERN_OFFERS_MAX := 2
const REPAIR_COST := {TIMBER: 2, IRON_ORE: 1}
const REPAIR_AMOUNT := 20

# --- The training ground (a free-day action; see Run.train) ---
# Each week (with the tavern and smithy restock) three drills are posted: Sparring, and two
# proficiency drills in different weapon types or magic schools that someone in the roster has a
# grade in (above E) and has not finished (below S).
const DRILLS_PROFICIENCY_PER_WEEK := 2
const DRILL_COST := 30                  # gold, on top of the day's free action
## Chance (percent) of a poor, good and great drill (DrillResult.Quality).
const DRILL_QUALITY_WEIGHTS: Array[int] = [25, 50, 25]
## Proficiency points toward the next grade by quality. Good is about one battle's worth with a
## weapon (the battle pace check: 4.8 points a companion a battle, capped at 8).
const DRILL_POINTS: Array[int] = [3, 5, 8]
## Sparring XP: good = the day's danger-2 battle XP pool / MAX_FIELDED / 2 (half an even share);
## poor and great are these percentages of good. Rounded to the nearest point.
const DRILL_SPARRING_DANGER := 2
const DRILL_SPARRING_SHARE_DIVISOR := 2
const DRILL_XP_PERCENT: Array[int] = [60, 100, 150]

# --- Starting resources ---
const STARTING_GOLD := 60
const STARTING_MATERIALS := {IRON_ORE: 0, TIMBER: 1}
