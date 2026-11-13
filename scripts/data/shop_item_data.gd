class_name ShopItemData
extends Resource
## A weapon the shop sells on free days, from `min_day` on. Stock is unlimited.

@export var weapon: WeaponData
@export var price: int = 50
@export var min_day: int = 1
