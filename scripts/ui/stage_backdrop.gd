class_name StageBackdrop
extends Control
## The battlefield behind everything: a dusk sky, far hills and dark ground, drawn in code.

const SKY_TOP := Color("0b1230")
const SKY_MID := Color("2b2f66")
const SKY_LOW := Color("b0624f")
const GROUND_TOP := Color("2a2233")
const GROUND_LOW := Color("0a0c13")
const HORIZON := 0.64


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * HORIZON
	var mid := h * 0.36
	_quad(0, 0, w, mid, SKY_TOP, SKY_MID)
	_quad(0, mid, w, horizon, SKY_MID, SKY_LOW)

	# Low sun on the enemy side.
	var sun := Vector2(w * 0.68, horizon)
	for i in 9:
		draw_circle(sun, h * (0.06 + 0.05 * i), Color(1.0, 0.72, 0.45, 0.045))

	_hills(w, horizon, h * 0.16, Color("3a2f55"), 0.0)
	_hills(w, horizon, h * 0.09, Color("241d3a"), 2.4)

	_quad(0, horizon, w, h, GROUND_TOP, GROUND_LOW)
	draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(1.0, 0.75, 0.55, 0.25), 2.0)

	# Leaning bands of light, the same lean as every panel.
	for band: Vector3 in [Vector3(0.30, 0.10, 0.05), Vector3(0.52, 0.05, 0.035), Vector3(0.83, 0.16, 0.04)]:
		var x := w * band.x
		var bw := w * band.y
		var lean := h * UiTheme.SLANT
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + lean, 0), Vector2(x + lean + bw, 0), Vector2(x + bw, h), Vector2(x, h)]),
			Color(1, 1, 1, band.z))

	# Darken the left (behind the action menu) and the bottom (behind the party).
	var dark := Color(UiTheme.INK, 0.82)
	var clear := Color(UiTheme.INK, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.42, 0), Vector2(w * 0.42, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, Color(UiTheme.INK, 0.95), Color(UiTheme.INK, 0.95)]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.14), Vector2(0, h * 0.14)]),
		PackedColorArray([Color(UiTheme.INK, 0.7), Color(UiTheme.INK, 0.7), clear, clear]))


func _quad(x0: float, y0: float, x1: float, y1: float, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


func _hills(w: float, base_y: float, height: float, color: Color, phase: float) -> void:
	var pts := PackedVector2Array([Vector2(0, base_y)])
	var steps := 48
	for i in steps + 1:
		var t := float(i) / steps
		var n := 0.55 + 0.25 * sin(t * 9.0 + phase) + 0.2 * sin(t * 23.0 + phase * 1.7)
		pts.append(Vector2(w * t, base_y - height * clampf(n, 0.05, 1.0)))
	pts.append(Vector2(w, base_y))
	draw_colored_polygon(pts, color)
