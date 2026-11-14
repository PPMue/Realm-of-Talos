class_name AccessoryLibrary
extends Resource
## Every accessory type the Jeweler can make (design/accessories.md): 54, each a .tres of its own under
## res://data/accessories/<family>/; this list is res://data/accessories/accessory_library.tres.
## tools/generate_accessories.gd wrote them.

const DEFAULT_PATH := "res://data/accessories/accessory_library.tres"

@export var types: Array[AccessoryTypeData] = []


static func load_default() -> AccessoryLibrary:
	return load(DEFAULT_PATH) as AccessoryLibrary


## The type with `id`, or null.
func find(id: String) -> AccessoryTypeData:
	for t in types:
		if t.id == id:
			return t
	return null
