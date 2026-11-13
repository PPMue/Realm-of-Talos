class_name ShopItemData
extends Resource
## A weapon the shop sells on free days, from `min_day` on. Stock is unlimited.
## A rare item (chance below 1) is only in stock on some free days: rolled when the day begins.

@export var weapon: WeaponData
@export var price: int = 50
@export var min_day: int = 1
## Chance (0-1) the item is in stock on a given free day.
@export_range(0.0, 1.0) var chance: float = 1.0
