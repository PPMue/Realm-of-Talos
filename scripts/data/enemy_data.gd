class_name EnemyData
extends Resource
## An enemy's definition: stats (no STA, no BLD) and its action list.

@export var display_name: String = ""
@export var portrait: Texture2D
@export var color: Color = Color.DARK_RED

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

@export_group("Actions")
@export var actions: Array[EnemyActionData] = []


func base_stats() -> Dictionary:
	return {
		Stat.HP: max_hp, Stat.STR: strength, Stat.MAG: magic, Stat.CRT: crit,
		Stat.DEX: dexterity, Stat.SPD: speed, Stat.DEF: defense,
		Stat.RES: resistance, Stat.LCK: luck,
	}
