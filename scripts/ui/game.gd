class_name Game
extends Control
## The main scene: the title screen, and the city once a run begins. A run that ends comes back here.

## 0 = a random seed for each new run.
@export var run_seed: int = 0

var title := TitleScreen.new()
var city := CityScreen.new()
var _fade := ColorRect.new()


func _ready() -> void:
	theme = UiTheme.theme()
	city.visible = false
	add_child(city)
	add_child(title)
	_fade.color = UiTheme.INK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	title.new_run_pressed.connect(func() -> void: start_run(run_seed))
	title.quit_pressed.connect(func() -> void: get_tree().quit())
	city.left_run.connect(show_title)


## Leaves the title and begins a run. `opening`: greet the commander with the opening letter.
func start_run(seed_value: int = 0, opening: bool = true) -> void:
	_cross(func() -> void:
		title.visible = false
		city.visible = true
		city.new_run(seed_value, opening))


func show_title() -> void:
	_cross(func() -> void:
		city.visible = false
		title.visible = true)


## Fades to black, swaps what is shown, and fades back.
func _cross(swap: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.35)
	t.tween_callback(swap)
	t.tween_property(_fade, "modulate:a", 0.0, 0.35)
	t.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)
