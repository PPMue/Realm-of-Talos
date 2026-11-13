class_name StatToggle
extends Control
## The switch in a stat table's free cell: two words in a ruled box, "Values" and "Growth", the one
## now shown inked in. A click on either word shows that view (a click on the one already shown
## flips to the other, so the whole switch works as one button). The view is StatTable.show_growth,
## shared by every table; `changed` tells the screen to draw its tables again.

signal changed

const H := 24.0
const WORDS: Array[String] = ["Values", "Growth"]
const SIZE := 15

var _over := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Values: the stats as they stand.\nGrowth: each stat's chance to rise by 1 with a level.\nKey: G"
	mouse_exited.connect(func() -> void:
		_over = -1
		queue_redraw())


## Puts the switch in `cell` (a table's free cell), as wide as the cell allows.
func place(cell: Rect2) -> void:
	size = Vector2(minf(cell.size.x, 156.0), H)
	position = cell.position + Vector2(0.0, 5.0)


## Flips the view, from a key.
static func flip() -> void:
	StatTable.show_growth = not StatTable.show_growth


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var over := 0 if motion.position.x < size.x * 0.5 else 1
		if over != _over:
			_over = over
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var want := click.position.x >= size.x * 0.5
		StatTable.show_growth = want if want != StatTable.show_growth else not want
		accept_event()
		changed.emit()


func _draw() -> void:
	var ink := UiTheme.PARCHMENT_INK
	var half := size.x * 0.5
	var on := 1 if StatTable.show_growth else 0
	for i in 2:
		var cell := Rect2(i * half, 0.0, half, H)
		if i == on:
			draw_rect(cell, Color(ink, 0.82))
		elif i == _over:
			draw_rect(cell, Color(ink, 0.12))
		var font := UiTheme.display_font() if i == on else UiTheme.body_font()
		var color := UiTheme.PARCHMENT if i == on else Color(ink, 0.8 if i == _over else 0.6)
		UiTheme.draw_text(self, font, Vector2(cell.position.x, (H - font.get_height(SIZE)) * 0.5), WORDS[i], SIZE, color, 0, half,
			HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(Vector2.ZERO, size), Color(ink, 0.7), false, 1.0)
