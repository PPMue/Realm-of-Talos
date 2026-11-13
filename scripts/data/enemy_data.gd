class_name EnemyData
extends Resource
## An enemy's definition: stats (no STA, no BLD) and its action list.

## When an enemy switches to its second action list (see `phase_actions`).
## HP_BELOW: when its HP falls to `phase_hp_percent` of max or lower. LAST_STANDING: when every other
## enemy has fallen.
enum PhaseTrigger { NONE, HP_BELOW, LAST_STANDING }

@export var display_name: String = ""
@export var portrait: Texture2D
@export var color: Color = Color.DARK_RED
## How large the art stands on the battle stage relative to a normal-sized enemy.
@export var stage_scale: float = 1.0
## Which days' fronts it belongs to: 1 early (weeks 1-2), 2 middle (weeks 3-4), 3 late (weeks 5-6);
## 0 a boss.
## See RunConfig.BAND_FIRST_DAY. Groups never field an enemy before its band begins.
@export_range(0, 3) var band: int = 1
## A few words on how it fights, for tooltips.
@export var role: String = ""

@export_group("Stats")
@export var max_hp: int = 20
@export var strength: int = 5
@export var magic: int = 0
@export var crit: int = 0
@export var dexterity: int = 5
@export var speed: int = 5
@export var defense: int = 3
@export var resistance: int = 1
@export var luck: int = 2

## Traits such as "Flying" (see EnemyTraits). Some weapons, arts and spells are effective against them.
@export var traits: Array[String] = []
## Every single-target action aims with the position weights mirrored: the leftmost companion most.
@export var reversed_targeting: bool = false

@export_group("Actions")
@export var actions: Array[EnemyActionData] = []

@export_group("Second phase")
@export var phase_trigger: PhaseTrigger = PhaseTrigger.NONE
## HP_BELOW: the share of max HP (percent) at or below which the phase begins.
@export var phase_hp_percent: int = 50
## The action list from the switch on. The pending action is replaced by a pick from it.
@export var phase_actions: Array[EnemyActionData] = []
## Shown in the banner when the phase begins, e.g. "TOTAL ECLIPSE".
@export var phase_title: String = ""
## One line under the banner title.
@export var phase_text: String = ""
## Applied to the enemy itself when the phase begins (e.g. a lasting STR bonus).
@export var phase_effect: StatusEffectData


func base_stats() -> Dictionary:
	return {
		Stat.HP: max_hp, Stat.STR: strength, Stat.MAG: magic, Stat.CRT: crit,
		Stat.DEX: dexterity, Stat.SPD: speed, Stat.DEF: defense,
		Stat.RES: resistance, Stat.LCK: luck,
	}


func has_phase() -> bool:
	return phase_trigger != PhaseTrigger.NONE and not phase_actions.is_empty()


## True if any single-target action of either list aims mirrored.
func ever_reversed() -> bool:
	if reversed_targeting:
		return true
	for a in actions + phase_actions:
		if a.reversed_targeting and a.targeting == EnemyActionData.Targeting.SINGLE:
			return true
	return false
