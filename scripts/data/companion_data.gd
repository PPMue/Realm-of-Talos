class_name CompanionData
extends Resource
## A companion's definition: base stats and equipment.

@export var display_name: String = ""
@export var portrait: Texture2D
@export var color: Color = Color.GRAY

@export_group("Stats")
@export var max_hp: int = 20
@export var max_sta: int = 30
@export var strength: int = 5
@export var magic: int = 0
@export var crit: int = 0
@export var dexterity: int = 5
@export var speed: int = 5
@export var defense: int = 3
@export var resistance: int = 1
@export var luck: int = 3
@export var build: int = 5

@export_group("Equipment")
@export var weapon: WeaponData
@export var armor: EquipmentData
@export var accessory: EquipmentData

@export_group("Progression (not used yet)")
@export var level: int = 1
## Stat key -> growth percent.
@export var growths: Dictionary = {}


func base_stats() -> Dictionary:
	return {
		Stat.HP: max_hp, Stat.STA: max_sta, Stat.STR: strength, Stat.MAG: magic,
		Stat.CRT: crit, Stat.DEX: dexterity, Stat.SPD: speed, Stat.DEF: defense,
		Stat.RES: resistance, Stat.LCK: luck, Stat.BLD: build,
	}


func equipment() -> Array[EquipmentData]:
	var items: Array[EquipmentData] = []
	for item: EquipmentData in [weapon, armor, accessory]:
		if item != null:
			items.append(item)
	return items
