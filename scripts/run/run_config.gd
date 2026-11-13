class_name RunConfig
extends RefCounted
## Every tuning number used by the run rules lives here.
## Content (enemy groups, front sites, events, shop stock) lives in the .tres data under res://data/run.

# --- Calendar ---
const DAYS := 30
const BLOCK_DAYS := 10                  # a boss closes every block: days 10, 20, 30
const BATTLES_PER_BLOCK_MIN := 5        # battle days in a block besides the boss
const BATTLES_PER_BLOCK_MAX := 6
const FREE_DAYS_PER_BLOCK := 2          # one of them is always the day before the boss
const DAYS_SHOWN_AHEAD := 7             # the player always sees the type of the next 7 days

# --- City ---
const CITY_MAX_HEALTH := 100
## City health lost when a battle on a front of danger 1, 2, 3 is lost.
const CITY_DAMAGE_BY_DANGER: Array[int] = [15, 20, 25]

# --- Party ---
const STARTING_COMPANIONS := 2
const MAX_FIELDED := 5
## At the end of every day each surviving companion heals this share of max HP (rounded up).
const DAILY_HEAL_FRACTION := 0.2
## HP an injured companion comes back with after a battle, won or lost.
const INJURED_RETURN_HP := 1

# --- Fronts ---
## Chance a battle day offers three fronts (danger 1, 2 and 3) instead of two.
const THREE_FRONTS_CHANCE := 0.5
## Gold for winning, by danger, on day 1. Grows by REWARD_GROWTH_PER_DAY each day after.
const REWARD_GOLD_BY_DANGER: Array[int] = [40, 70, 110]
const REWARD_GOLD_SPREAD := 0.15        # +/- this share, rolled per front
const REWARD_GROWTH_PER_DAY := 0.03
## Chance the reward also includes materials, and how many, by danger.
const REWARD_MATERIAL_CHANCE: Array[float] = [0.3, 0.6, 1.0]
const REWARD_MATERIAL_AMOUNT: Array[int] = [1, 2, 3]
## Boss rewards, by boss (day 10, 20, 30). The last one ends the run, so it only shows.
const BOSS_REWARD_GOLD: Array[int] = [150, 250, 0]
const BOSS_REWARD_MATERIALS := 3

# --- Enemy scaling with the day (normal fronts only; bosses are built for their day) ---
const ENEMY_HP_GROWTH_PER_DAY := 0.03   # max HP x (1 + 0.03 x (day - 1)): day 30 is x1.87
const ENEMY_STR_EVERY_DAYS := 6         # +1 STR on days 7, 13, 19, 25
const ENEMY_DEF_EVERY_DAYS := 10        # +1 DEF on days 11, 21

# --- Materials ---
const IRON_ORE := "iron_ore"
const TIMBER := "timber"
const MATERIAL_NAMES := {IRON_ORE: "Iron Ore", TIMBER: "Timber"}
const MATERIAL_ORDER: Array[String] = [IRON_ORE, TIMBER]

# --- Free days ---
const FREE_DAY_ACTIONS := 2
const HIRE_COST := 100
## How many companions the tavern offers (at most; fewer if fewer are left to hire).
const TAVERN_OFFERS_MIN := 1
const TAVERN_OFFERS_MAX := 2
const REPAIR_COST := {TIMBER: 2, IRON_ORE: 1}
const REPAIR_AMOUNT := 20

# --- Starting resources ---
const STARTING_GOLD := 60
const STARTING_MATERIALS := {IRON_ORE: 0, TIMBER: 1}
