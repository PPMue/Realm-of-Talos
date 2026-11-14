class_name CallingLibrary
extends Resource
## Every calling a run can offer (design/callings.md). Each is a .tres of its own under
## res://data/callings/; this list is res://data/callings/calling_library.tres.
## tools/generate_callings.gd wrote the files.

const DEFAULT_PATH := "res://data/callings/calling_library.tres"

@export var callings: Array[CallingData] = []


static func load_default() -> CallingLibrary:
	return load(DEFAULT_PATH) as CallingLibrary


## The calling with `id`, or null.
func find(id: String) -> CallingData:
	for c in callings:
		if c.id == id:
			return c
	return null
