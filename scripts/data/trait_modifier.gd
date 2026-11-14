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
	# --- wave 2: single moments ---
	FOCUS_RESTORE,        ## Focus restores `amount` more stamina
	ACTION_STAMINA,       ## after each of their actions: `amount` stamina
	RECOVERY,             ## the action's recovery changed by `amount` (never below 0)
	KILL_NO_RECOVERY,     ## an action that fells an enemy has no recovery
	KILL_STAMINA,         ## felling an enemy: `amount` stamina
	KILL_HP,              ## felling an enemy: `amount` HP
	CRIT_DELAY,           ## a critical hit pushes the target's next action back `amount` (once per action)
	HALF_HEALTH_STAMINA,  ## the first time they fall below half Health in a battle: stamina full
	DOT_IMMUNE,           ## damage over time cannot touch them
	CURSE_TURNS,          ## a harmful effect on them lasts `amount` turns more (negative: fewer; at least 1)
	SURVIVE_ONCE,         ## once a battle, a blow that would fell them leaves them at 1 Health
	DAY_HEAL_SHARE,       ## the day's-end heal: `amount` more percentage points of max HP
	BATTLE_WON_HEAL_PERCENT, ## after a battle won, standing: heal `amount` percent of max HP
	CURE_PERCENT,         ## their cure costs `amount` percent more (negative: less)
	KILL_POINTS_PERCENT,  ## contribution points for a kill changed by `amount` percent
	RESERVE_XP_SHARE,     ## from the bench, a won battle's XP: `amount` percent of an even share
	DRILL_NEVER_POOR,     ## a drill never comes out poor for them
	LEARN_GRADE_STEPS,    ## arts and spells learned are drawn as if the grade were `amount` steps higher
	SHOP_PERCENT,         ## the smithy's prices changed by `amount` percent (the company's)
	HIRE_COST,            ## a hire costs `amount` more gold (negative: less)
	DRILL_COST,           ## a drill costs `amount` more gold (negative: less)
	REPAIR_AMOUNT,        ## a repair mends `amount` more
	BATTLE_WON_GOLD,      ## after a battle won in which they fought: `amount` gold
	KILL_GOLD,            ## after a battle won: `amount` gold for each enemy they felled
	BATTLE_MATERIAL,      ## after a battle in which they fought: `amount` of `material`
	CITY_DAMAGE,          ## from the bench: a lost battle costs the walls `amount` more (negative: less)
	EVENT_GOLD_PERCENT,   ## event choices that cost gold cost `amount` percent more (negative: less)
	# --- wave 3: other people, scavenging ---
	INJURED_HEAL_ALLIES,  ## when they are injured, every ally standing heals `amount`
	KILL_NEXT_ALLY_HIT,   ## after they fell an enemy, the next ally to act has `amount` Hit
	SCAVENGE_STAT,        ## scavenging: counts as `amount` higher in whatever is asked of them
	SCAVENGE_NO_INJURY,   ## scavenging: never comes back injured
	SCAVENGE_HAUL_PERCENT, ## scavenging: the party brings back `amount` percent more gold and materials
	# --- accessories (design/accessories.md): new rules ---
	PIERCE_PERCENT,       ## their strikes ignore `amount` percent more of the target's DEF (RES with magic), at most 100
	THORNS,               ## an enemy whose blow lands on them takes `amount` damage (not blows on the whole line)
	DOT_TAKEN_PERCENT,    ## damage over time on them changed by `amount` percent (-100: none)
	SURVIVE_SHARE,        ## once a battle, a blow that would fell them leaves them at `amount` percent of max HP (0: 1 HP)
	FIRST_HIT_DELAY,      ## their first hit of a battle pushes the target's next action back `amount`
	SPELL_USES_LOSS,      ## every spell has `amount` fewer uses, never below 1
	# --- callings (design/callings.md): one rule each ---
	STRIKE_TURNS_AIM,     ## an enemy their strike or spell lands on turns its pending single blow on them (Champion)
	EXECUTE_PERCENT,      ## a strike or spell that leaves an enemy at `amount` percent of its Health or less fells it; a boss: half that (Executioner)
	ORDER_ROUSE,          ## the order Rouse: a companion who is recovering is ready at once (Captain)
	HIT_DELAY,            ## an action of theirs that lands pushes the target's next action back `amount`, once per action (Harrier)
	SURE_CRIT,            ## what they land is critical (Hunter, with target_turns_at_most)
	ART_COSTS_HEALTH,     ## arts cost Health in place of stamina: `amount` percent of the stamina cost, rounded up (Berserker)
	RAISE_ONCE,           ## once a battle, their healing spell on one ally can raise an injured companion at `amount` percent of max Health (Mender)
	EFFECTS_PASS_ON,      ## when an enemy carrying a harmful effect of theirs falls, it passes to another enemy (Hexer)
	FIRST_SPELL_FREE,     ## their first spell of each battle costs no use, and can be cast with none left (Sage)
	STRIKE_LOWER_DEFENSE, ## their weapon strikes are worked out against the lower of the target's DEF and RES (Spellblade)
	# --- masteries (design/callings.md, step 2): one more line each ---
	GUARD_ANYONE,         ## Guard can cover anyone standing in the line, not only a neighbour (Warden)
	COVER_ANSWERS,        ## a blow they catch for another is answered with their plain Attack (Warden)
	OPENING_AIM,          ## when the battle begins, every single blow already aimed is aimed at them (Champion)
	RECOVERY_AT_MOST,     ## the action's recovery is at most `amount` (Skirmisher: arts of `spell_tier`)
	ROUSE_SURE_HIT,       ## the one they rouse cannot miss with their next action (Captain)
	DELAY_AGAIN,          ## their HIT_DELAY push lands on an action already pushed back, once more (Harrier)
	STAGGERED_DAMAGE_PERCENT, ## while they stand, an enemy whose action has been pushed back takes `amount` percent more from every strike and spell, until it acts (Harrier)
	KILL_HP_PERCENT,      ## felling an enemy: `amount` percent of their max Health (Berserker)
	HEAL_SPREADS,         ## their heal on one ally also heals that ally's standing neighbours, `amount` percent as much (Mender)
	RAISE_MORE,           ## RAISE_ONCE can be used `amount` more times a battle (Mender)
	HEX_TURNS,            ## a harmful effect they lay on an enemy lasts `amount` turns longer (Hexer)
	HEXED_HIT,            ## an enemy carrying a harmful effect of theirs has `amount` less Hit (Hexer)
	STRIKE_KILL_SPELL_USE, ## a weapon strike of theirs that fells an enemy gives `amount` spell use back (Spellblade)
}

## Where in the line the holder stands, counted as in the barracks (rear to front).
enum Place { ANY, FRONT, REAR, MIDDLE, NOT_FRONT }
## What kind of action the number is for. GUARD, ROUSE: only where the rules ask for them by name (their recovery).
enum Action { ANY, ATTACK, ART, SPELL, GUARD, ROUSE }
## Who the number is for: the holder, the companions either side of them, the one behind them,
## everyone in the company not in the Infirmary (out of battle), every other companion in the line,
## the lowest-level companion in the line (XP).
enum Who { SELF, NEIGHBOURS, BEHIND, COMPANY, ALLIES, LOWEST }
## The kind of blow taken.
enum Blow { ANY, PHYSICAL, MAGIC }
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
## SPELL_USES: spells of this tier only; RECOVERY_AT_MOST: arts of this tier only; 0 every tier.
@export var spell_tier: int = 0
@export var action: Action = Action.ANY
## GROWTH: level-ups reaching at most / at least this level (0: no limit).
@export var level_to: int = 0
@export var level_from: int = 0
## DAMAGE_TAKEN_PERCENT: only from blows that strike the whole line.
@export var whole_line_blows: bool = false
## DAMAGE_TAKEN, DAMAGE_TAKEN_PERCENT: only from physical or magic blows.
@export var blow: Blow = Blow.ANY
## PROFICIENCY_PERCENT: only in the weapon type of their second-best weapon grade.
@export var second_best_weapon: bool = false
## BATTLE_MATERIAL: the material id.
@export var material: String = ""

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
## The enemy has this trait ("Large", "Flying"; "Flying|Large": either).
@export var target_trait: String = ""
@export var target_boss: bool = false
## The enemy is a boss, or the battle is an elite fight (then every enemy).
@export var big_fight: bool = false
## The enemy's next action is magic.
@export var target_next_magic: bool = false
@export var struck: Struck = Struck.ANY
## The holder's own actions this battle, 1-based, counting the one being taken: from / up to (0: no limit).
@export var action_from: int = 0
@export var action_to: int = 0
## RECOVERY: only for an action whose own recovery is at least this (0: any). A Spur: 2.
@export var recovery_at_least: int = 0
## The holder's last action was Guard or Focus.
@export var after_guard_or_focus: bool = false
## The holder has not yet acted from the front place this battle.
@export var first_front_action: bool = false
## No enemy blow has landed on the holder yet this battle.
@export var first_blow_taken: bool = false
## The holder has at most this much Health (0: no limit).
@export var self_hp_at_most: int = 0
## The holder has used no art yet this battle.
@export var first_art: bool = false
## Another companion in the line has been injured this battle.
@export var ally_injured: bool = false
## Another companion has felled more enemies this battle than the holder.
@export var rival_ahead: bool = false
## The amount counts once for each standing companion beside the holder.
@export var per_neighbour: bool = false
## The enemy's pending action comes in at most this many turns (0: no limit). 1: it acts after this action.
@export var target_turns_at_most: int = 0
## DAMAGE_TAKEN_PERCENT: only from an enemy whose pending single blow the holder turned on themselves
## (a Champion's strike: EnemyUnit.turned_by_id).
@export var aim_turned: bool = false
## The holder has cast no spell yet this battle.
@export var first_spell: bool = false
## The holder's last action was a spell.
@export var after_spell: bool = false


## True if no battle condition is set: the modifier also counts outside a battle.
func is_battle_only() -> bool:
	return place != Place.ANY or line_at_most > 0 or line_full or only_standing or self_health != Health.ANY \
		or target_health != Health.ANY or target_trait != "" or target_boss or big_fight or target_next_magic \
		or struck != Struck.ANY or action_from > 0 or action_to > 0 or after_guard_or_focus or first_front_action \
		or first_blow_taken or self_hp_at_most > 0 or first_art or ally_injured or rival_ahead or per_neighbour \
		or target_turns_at_most > 0 or aim_turned or first_spell or after_spell


## True if nothing at all limits it: it always counts (a plain stat bonus, a growth rate for every level).
func is_plain() -> bool:
	return not is_battle_only() and who == Who.SELF and weapon_type < 0 and school < 0 and spell_tier == 0 \
		and action == Action.ANY and level_to == 0 and level_from == 0 and not whole_line_blows and blow == Blow.ANY \
		and not second_best_weapon
