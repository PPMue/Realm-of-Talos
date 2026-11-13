class_name StageBackdrop
extends Control
## The battlefield behind everything: the open ground outside the walls under a low sun, with the
## city's wall and towers small on the horizon behind the company. Drawn in code.

const SKY_TOP := Color("26315a")
const SKY_MID := Color("8f6a80")
const SKY_LOW := Color("f0a878")
const GROUND_TOP := Color("5f5a44")
const GROUND_LOW := Color("1c1a14")
const HORIZON := 0.6
const AMBIENT := Color(0.8, 0.68, 0.66)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * HORIZON
	var mid := h * 0.3
	_quad(0, 0, w, mid, SKY_TOP, SKY_MID)
	_quad(0, mid, w, horizon, SKY_MID, SKY_LOW)

	# Low sun on the enemy's side, and thin cloud across it.
	var sun := Vector2(w * 0.7, horizon - h * 0.05)
	for i in 12:
		draw_circle(sun, h * (0.04 + 0.03 * i), Color(1.0, 0.8, 0.55, 0.035))
	draw_circle(sun, h * 0.035, Color("ffe2b0"))
	for c: Vector3 in [Vector3(0.2, 0.16, 300.0), Vector3(0.52, 0.1, 240.0), Vector3(0.84, 0.2, 320.0), Vector3(0.66, 0.3, 260.0)]:
		CityArt.cloud(self, Vector2(w * c.x, h * c.y), c.z, Color(1.0, 0.8, 0.72, 0.4))

	_hills(w, horizon, h * 0.2, SKY_LOW.lerp(Color(0.36, 0.4, 0.55), 0.62), 0.6, 5.0)
	_hills(w, horizon, h * 0.11, Color("4a4658"), 2.4, 9.0)

	# The city behind the company: a strip of wall and its towers, far off on the left.
	var stone := CityArt.tint(CityArt.STONE.darkened(0.25), AMBIENT).lerp(SKY_LOW, 0.2)
	var wall_y := horizon - h * 0.045
	draw_rect(Rect2(0, wall_y, w * 0.34, horizon - wall_y + 2.0), stone)
	CityArt.crenels(self, 0, w * 0.34, wall_y, 9, 7, CityArt.STONE.darkened(0.25), AMBIENT)
	for tx: float in [0.03, 0.14, 0.26, 0.335]:
		var tw := h * 0.03
		var top := wall_y - h * 0.035
		draw_rect(Rect2(w * tx, top, tw, horizon - top + 2.0), stone.darkened(0.08))
		CityArt.crenels(self, w * tx - 2.0, w * tx + tw + 2.0, top, 8, 7, CityArt.STONE.darkened(0.32), AMBIENT)
	CityArt.cone(self, w * 0.2, wall_y - h * 0.02, h * 0.022, h * 0.05, CityArt.ROOF_SLATE.darkened(0.2), AMBIENT)

	# The field.
	_quad(0, horizon, w, h, GROUND_TOP, GROUND_LOW)
	draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(1.0, 0.8, 0.6, 0.22), 2.0)
	# A trodden road from the gate toward the enemy.
	draw_polygon(PackedVector2Array([Vector2(w * 0.1, horizon), Vector2(w * 0.16, horizon), Vector2(w * 1.02, h), Vector2(w * 0.5, h)]),
		PackedColorArray([Color(0.62, 0.55, 0.42, 0.5), Color(0.62, 0.55, 0.42, 0.5), Color(0.4, 0.35, 0.28, 0.0), Color(0.4, 0.35, 0.28, 0.0)]))
	# Tufts of grass and a few stones, larger toward the viewer.
	for i in 90:
		var fy := fposmod(i * 0.618, 1.0)
		var y := horizon + 8.0 + (h - horizon) * fy * fy
		var x := fposmod(i * 271.3 + i * i * 3.1, w)
		var k := 0.5 + 1.6 * fy
		var blade := Color(0.38, 0.42, 0.26, 0.55).lerp(Color(0.16, 0.17, 0.12, 0.7), fy)
		if i % 7 == 0:
			draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 7.0 * k, Color(0.34, 0.33, 0.32, 0.8).lerp(Color(0.1, 0.1, 0.1, 0.8), fy))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		for d: float in [-1.0, 0.0, 1.0]:
			draw_line(Vector2(x + d * 3.0 * k, y), Vector2(x + d * 7.0 * k, y - (9.0 - absf(d) * 3.0) * k), blade, 1.5, true)

	# Darken the left (behind the action menu), the foot (behind the party) and the top edge.
	var dark := Color(UiTheme.INK, 0.74)
	var clear := Color(UiTheme.INK, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.42, 0), Vector2(w * 0.42, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.62), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, Color(UiTheme.INK, 0.94), Color(UiTheme.INK, 0.94)]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.14), Vector2(0, h * 0.14)]),
		PackedColorArray([Color(UiTheme.INK, 0.6), Color(UiTheme.INK, 0.6), clear, clear]))


func _quad(x0: float, y0: float, x1: float, y1: float, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


func _hills(w: float, base_y: float, height: float, color: Color, phase: float, freq: float) -> void:
	var pts := PackedVector2Array([Vector2(0, base_y)])
	var steps := 64
	for i in steps + 1:
		var t := float(i) / steps
		var n := 0.5 + 0.28 * sin(t * freq + phase) + 0.16 * sin(t * freq * 2.7 + phase * 1.7) + 0.08 * sin(t * freq * 6.1)
		pts.append(Vector2(w * t, base_y - height * clampf(n, 0.06, 1.0)))
	pts.append(Vector2(w, base_y))
	draw_colored_polygon(pts, color)
