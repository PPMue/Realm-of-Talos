class_name CityBackdrop
extends Control
## Behind the city screens: a night sky over the last city's walls and towers, drawn in code.
## Same palette and lean as the battle stage.

const SKY_TOP := Color("070b1f")
const SKY_MID := Color("1c2150")
const SKY_LOW := Color("6a3a4a")
const WALL := Color("120f1c")
const WALL_FAR := Color("1d1a30")
const WINDOW := Color(1.0, 0.78, 0.45, 0.85)
const HORIZON := 0.7


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * HORIZON
	_quad(0, 0, w, h * 0.4, SKY_TOP, SKY_MID)
	_quad(0, h * 0.4, w, horizon, SKY_MID, SKY_LOW)
	_quad(0, horizon, w, h, Color("1a1424"), UiTheme.INK)

	# Stars, placed by a fixed pattern so they never move between redraws.
	for i in 90:
		var x := fmod(i * 233.7, 1.0 * w)
		var y := fmod(i * 97.3 + i * i * 0.61, h * 0.45)
		draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.5, Color(1, 1, 1, 0.18 + 0.12 * (i % 4)))

	# Far towers, then the near wall with its towers and lit windows.
	_skyline(w, horizon, h, WALL_FAR, 0.55, 3.1, 0.0)
	_skyline(w, horizon + h * 0.03, h, WALL, 1.0, 1.7, 1.3)

	# Leaning bands of light, the same lean as every panel.
	for band: Vector3 in [Vector3(0.18, 0.08, 0.04), Vector3(0.47, 0.05, 0.03), Vector3(0.78, 0.12, 0.035)]:
		var x := w * band.x
		var bw := w * band.y
		var lean := h * UiTheme.SLANT
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + lean, 0), Vector2(x + lean + bw, 0), Vector2(x + bw, h), Vector2(x, h)]),
			Color(1, 1, 1, band.z))

	# Keep the top bar and the lower half dark enough for text.
	var clear := Color(UiTheme.INK, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.16), Vector2(0, h * 0.16)]),
		PackedColorArray([Color(UiTheme.INK, 0.8), Color(UiTheme.INK, 0.8), clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, Color(UiTheme.INK, 0.92), Color(UiTheme.INK, 0.92)]))


func _quad(x0: float, y0: float, x1: float, y1: float, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


## A row of wall segments and towers along `base_y`. `scale` sets their height, `step` their spacing.
func _skyline(w: float, base_y: float, h: float, color: Color, scale: float, step: float, phase: float) -> void:
	var unit := h * 0.06 * scale
	var x := -unit
	var i := 0
	while x < w + unit:
		var n := 0.5 + 0.5 * sin(i * step + phase)
		var tower := i % 3 == 0
		var tw := unit * (1.6 if tower else 2.6)
		var th := unit * (2.6 + 2.2 * n if tower else 1.0 + 0.4 * n)
		var top := base_y - th
		draw_rect(Rect2(x, top, tw, h - top), color)
		# Crenellations.
		var c := 0.0
		while c < tw - 2.0:
			draw_rect(Rect2(x + c, top - unit * 0.25, unit * 0.3, unit * 0.25), color)
			c += unit * 0.55
		if tower:
			# Pointed roof and a lit window or two.
			draw_colored_polygon(PackedVector2Array([Vector2(x - unit * 0.15, top - unit * 0.25),
				Vector2(x + tw * 0.5, top - unit * 1.4), Vector2(x + tw + unit * 0.15, top - unit * 0.25)]), color)
			if scale >= 1.0:
				draw_rect(Rect2(x + tw * 0.4, top + unit * 0.6, unit * 0.22, unit * 0.36), WINDOW)
				if n > 0.5:
					draw_rect(Rect2(x + tw * 0.4, top + unit * 1.5, unit * 0.22, unit * 0.36), Color(WINDOW, 0.6))
		x += tw - 1.0
		i += 1
