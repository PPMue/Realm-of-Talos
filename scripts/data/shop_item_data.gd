class_name ShopItemData
extends Resource
## A weapon the smithy sells, from the first week that begins on or after `min_day`. The stock is
## rolled on the first day of each week and holds one of each item; a bought item is gone until the
## next week. A rare item (chance below 1) is only in stock in some weeks.

@export var weapon: WeaponData
@export var price: int = 50
@export var min_day: int = 1
## Chance (0-1) the item is in stock in a given week.
@export_range(0.0, 1.0) var chance: float = 1.0
