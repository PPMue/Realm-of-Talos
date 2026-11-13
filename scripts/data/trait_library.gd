class_name TraitLibrary
extends Resource
## Every trait that can be handed out (design/traits.md). Each is a .tres of its own under
## res://data/traits/<family>/; this list is res://data/traits/trait_library.tres. A trait not in the
## list is never handed out, which is how traits of a wave not yet built stay out of runs.
## tools/generate_traits.gd wrote the files; a new trait can be written as a .tres by hand and added here.

const DEFAULT_PATH := "res://data/traits/trait_library.tres"

@export var traits: Array[TraitData] = []


static func load_default() -> TraitLibrary:
	return load(DEFAULT_PATH) as TraitLibrary


## The trait with `id`, or null.
func find(id: String) -> TraitData:
	for t in traits:
		if t.id == id:
			return t
	return null
