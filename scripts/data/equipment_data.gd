class_name EquipmentData
extends Resource
## Anything a companion can equip. Total equipped weight above BLD lowers DEX and SPD.

enum Slot { WEAPON, ARMOR, ACCESSORY }

@export var display_name: String = ""
@export var slot: Slot = Slot.WEAPON
@export var weight: int = 0
