class_name TraitModifier
extends Resource
## One number a trait changes, and when (TraitData.modifiers). Every condition left at its default is
## no condition; all the conditions set must hold. Evaluated by TraitRules.
##
## Battle conditions (place, line, health, target, action count...) only ever hold in a battle; a
## modifier with none of them (a "plain" one, see is_plain) also counts outside: in the stats the
## barracks shows, growth rates, XP, the Infirmary, spell uses.

enum Kind {
	STAT,                 ## `stat` + amount
	HIT,                  ## percentage points on the chance to hit
	CRIT,                 ## percentage points on the chance of a critical
	AVOID,                ## enemies have `amount` less Hit against them
	DAMAGE,               ## added to each blow (after DEF or RES, before a critical), never below 1
	DAMAGE_PERCENT,       ## each blow's damage changed by `amount` percent
	SURE_HIT,             ## the strike cannot miss
	ART_STAMINA,          ## arts cost `amount` more stamina (negative: less), never below 0
	PROFICIENCY_PERCENT,  ## weapon or magic points earned changed by `amount` percent (and the battle's cap)
	SPELL_USES,           ## uses of a spell
	HEAL_GIVEN,           ## heals they cast restore `amount` more
	HEAL_RECEIVED,        ## white magic heals them `amount` more
	BLESSING_TURNS,       ## a white spell's buff they cast lasts `amount` turns longer
	AIM,                  ## how often enemies aim at them: x `mult`
	GROWTH,               ## growth rate (percent) of `stat`, or of every stat with ""
	XP_PERCENT,           ## XP gained changed by `amount` percent
	INFIRMARY_DAYS,       ## days added to an Infirmary stay
	DAY_HEAL_PERCENT,     ## the day's-end heal changed by `amount` percent
	DAMAGE_TAKEN,         ## enemy blows deal `amount` more (negative: less), never below 1
	DAMAGE_TAKEN_PERCENT, ## enemy blows deal `amount` percent more (negative: less)
	GUARD_PERCENT,        ## Guard takes `amount` percent off a blow instead of the usual
}

## Where in the line the holder stands, counted as in the barracks (rear to front).
enum Place { ANY, FRONT, REAR, MIDDLE, NOT_FRONT }
## What kind of action the number is for.
enum Action { ANY, ATTACK, ART, SPELL }
## Who the number is for: the holder, the companions either side of them, the one behind them.
enum Who { SELF, NEIGHBOURS, BEHIND }
enum Health { ANY, BELOW_HALF, FULL }
## Against which enemy: the one they struck last, any other, the one who hit them last, one that has
## struck them since their last action.
enum Struck { ANY, LAST_STRUCK, NOT_LAST_STRUCK, HIT_ME_LAST, STRUCK_ME_SINCE }

@export var kind: Kind = Kind.STAT
@export var amount: int = 0
@export var mult: float = 1.0
## STAT and GROWTH: a Stat key ("" in GROWTH: every growing stat).
@export var stat: String = ""
@export var who: Who = Who.SELF

@export_group("Conditions")
## A weapon type (WeaponData.WeaponType) in hand for the action or points; -1 any.
@export var weapon_type: int = -1
## A school (SpellData.School) of the spell cast or points earned; -1 any.
@export var school: int = -1
## SPELL_USES: spells of this tier only; 0 every tier.
@export var spell_tier: int = 0
@export var action: Action = Action.ANY
## GROWTH: level-ups reaching at most / at least this level (0: no limit).
@export var level_to: int = 0
@export var level_from: int = 0
## DAMAGE_TAKEN_PERCENT: only from blows that strike the whole line.
@export var whole_line_blows: bool = false

@export_group("Battle conditions")
@export var place: Place = Place.ANY
## The line holds at most this many (0: no limit).
@export var line_at_most: int = 0
## The line is full (RunConfig.MAX_FIELDED).
@export var line_full: bool = false
## The holder is the only one standing.
@export var only_standing: bool = false
@export var self_health: Health = Health.ANY
@export var target_health: Health = Health.ANY
## The enemy has this trait ("Large", "Flying").
@export var target_trait: String = ""
@export var target_boss: bool = false
## The enemy's next action is magic.
@export var target_next_magic: bool = false
@export var struck: Struck = Struck.ANY
## The holder's own actions this battle, 1-based, counting the one being taken: from / up to (0: no limit).
@export var action_from: int = 0
@export var action_to: int = 0
## The holder's last action was Guard or Focus.
@export var after_guard_or_focus: bool = false
## The holder has not yet acted from the front place this battle.
@export var first_front_action: bool = false


## True if no battle condition is set: the modifier also counts outside a battle.
func is_battle_only() -> bool:
	return place != Place.ANY or line_at_most > 0 or line_full or only_standing or self_health != Health.ANY \
		or target_health != Health.ANY or target_trait != "" or target_boss or target_next_magic \
		or struck != Struck.ANY or action_from > 0 or action_to > 0 or after_guard_or_focus or first_front_action


## True if nothing at all limits it: it always counts (a plain stat bonus, a growth rate for every level).
func is_plain() -> bool:
	return not is_battle_only() and who == Who.SELF and weapon_type < 0 and school < 0 and spell_tier == 0 \
		and action == Action.ANY and level_to == 0 and level_from == 0 and not whole_line_blows
