class_name CityArt
extends RefCounted
## The drawing kit for the city: walls, roofs, windows, doors and small props, all drawn in code.
## Every colour passes through `tint`, so one ambient colour sets the time of day for the whole city.
## Light comes from the upper left: right-hand faces and the undersides of roofs are darker.

const STONE := Color("8b857c")
const STONE_DARK := Color("5f5a55")
const PLASTER := Color("d8c9a3")
const TIMBER := Color("4a3424")
const ROOF_RED := Color("8a4233")
const ROOF_SLATE := Color("4c5868")
const ROOF_THATCH := Color("9c8450")
const WOOD := Color("7a5a3a")
const GLASS_DARK := Color("1a2030")
const LAMP := Color("ffc56b")
const FIRE := Color("ff8a2a")
const BANNER := Color("a8322c")


static func tint(c: Color, amb: Color) -> Color:
	return Color(c.r * amb.r, c.g * amb.g, c.b * amb.b, c.a)


## A wall face: the lit front, a shaded strip on the right, and a shadow under the eaves.
static func wall(ci: CanvasItem, rect: Rect2, color: Color, amb: Color, eave_shadow: float = 10.0) -> void:
	ci.draw_rect(rect, tint(color, amb))
	var side := minf(rect.size.x * 0.16, 34.0)
	ci.draw_rect(Rect2(rect.end.x - side, rect.position.y, side, rect.size.y), tint(color.darkened(0.2), amb))
	if eave_shadow > 0.0:
		ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y + eave_shadow), Vector2(rect.position.x, rect.position.y + eave_shadow)]),
			PackedColorArray([Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	ci.draw_rect(Rect2(rect.position.x, rect.end.y - 5.0, rect.size.x, 5.0), tint(color.darkened(0.35), amb))


## A few short courses of masonry, so stone does not read as a flat block.
static func stones(ci: CanvasItem, rect: Rect2, color: Color, amb: Color, seed_value: int = 0) -> void:
	var line := tint(color.darkened(0.22), amb)
	line.a = 0.55
	var rows := maxi(2, int(rect.size.y / 26.0))
	for r in rows:
		var y := rect.position.y + (r + 0.5) * rect.size.y / rows
		var n := 2 + (r + seed_value) % 2
		for k in n:
			var f := fposmod((k + 0.37) / n + 0.23 * r + 0.11 * seed_value, 1.0)
			var x := rect.position.x + 8.0 + f * (rect.size.x - 60.0)
			ci.draw_line(Vector2(x, y), Vector2(x + 34.0, y), line, 1.5)
			ci.draw_line(Vector2(x + 16.0, y), Vector2(x + 16.0, y + 9.0), line, 1.5)


## A roof seen from the side: a trapezoid over the wall from `x0` to `x1`, eaves at `y_eave`.
static func roof(ci: CanvasItem, x0: float, x1: float, y_eave: float, height: float, inset: float, color: Color, amb: Color,
		over: float = 12.0) -> void:
	var c := tint(color, amb)
	var pts := PackedVector2Array([Vector2(x0 - over, y_eave), Vector2(x0 + inset, y_eave - height),
		Vector2(x1 - inset, y_eave - height), Vector2(x1 + over, y_eave)])
	ci.draw_colored_polygon(pts, c)
	# Shaded right slope.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x1 - inset, y_eave - height), Vector2(x1 + over, y_eave),
		Vector2(x1 - inset * 0.2, y_eave)]), tint(color.darkened(0.22), amb))
	# Courses of tiles, the lit ridge, and the dark line of the eaves.
	var tile := tint(color.darkened(0.18), amb)
	tile.a = 0.7
	var rows := maxi(2, int(height / 16.0))
	for r in range(1, rows):
		var t := float(r) / rows
		var y := y_eave - height * t
		ci.draw_line(Vector2(x0 - over + (inset + over) * t, y), Vector2(x1 + over - (inset + over) * t, y), tile, 1.5)
	ci.draw_line(Vector2(x0 + inset, y_eave - height), Vector2(x1 - inset, y_eave - height), tint(color.lightened(0.25), amb), 2.5)
	ci.draw_line(Vector2(x0 - over, y_eave), Vector2(x1 + over, y_eave), tint(color.darkened(0.45), amb), 3.0)


## A gable seen from the front: the triangular wall and the two roof edges over it.
static func gable(ci: CanvasItem, x0: float, x1: float, y_eave: float, height: float, wall_color: Color, roof_color: Color,
		amb: Color, over: float = 16.0) -> void:
	var peak := Vector2((x0 + x1) * 0.5, y_eave - height)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y_eave), peak, Vector2(x1, y_eave)]), tint(wall_color, amb))
	var thick := 16.0
	var slope := (y_eave - peak.y) / maxf(1.0, peak.x - x0)
	var l0 := Vector2(x0 - over, y_eave + over * slope)
	var r0 := Vector2(x1 + over, y_eave + over * slope)
	ci.draw_colored_polygon(PackedVector2Array([l0, peak + Vector2(0, -thick * 0.9), peak + Vector2(0, thick * 0.4),
		l0 + Vector2(6, thick)]), tint(roof_color, amb))
	ci.draw_colored_polygon(PackedVector2Array([r0, peak + Vector2(0, -thick * 0.9), peak + Vector2(0, thick * 0.4),
		r0 + Vector2(-6, thick)]), tint(roof_color.darkened(0.22), amb))
	ci.draw_line(l0, peak + Vector2(0, -thick * 0.9), tint(roof_color.lightened(0.25), amb), 2.0)


## A window. `glow` 0-1: how strongly lamps show (night); `lit` false: shuttered and dark.
static func window(ci: CanvasItem, rect: Rect2, glow: float, amb: Color, lit: bool = true, arched: bool = false) -> void:
	var k := clampf(glow, 0.0, 1.0) if lit else 0.0
	var frame := tint(TIMBER.darkened(0.1), amb)
	var glass := tint(GLASS_DARK.lerp(Color("5a6f80"), 0.35), amb).lerp(LAMP, k * 0.92)
	if k > 0.3:
		var c := rect.get_center()
		var m := maxf(rect.size.x, rect.size.y)
		for ring: float in [1.9, 1.55, 1.25, 1.0, 0.8]:
			ci.draw_circle(c, m * ring, Color(LAMP, 0.035 * k))
	ci.draw_rect(rect.grow(3.0), frame)
	if arched:
		ci.draw_circle(Vector2(rect.get_center().x, rect.position.y), rect.size.x * 0.5 + 3.0, frame)
		ci.draw_circle(Vector2(rect.get_center().x, rect.position.y), rect.size.x * 0.5, glass)
	ci.draw_rect(rect, glass)
	if not lit:
		# Shutters closed.
		ci.draw_rect(rect, tint(WOOD.darkened(0.25), amb))
		ci.draw_line(Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), frame, 2.0)
		return
	ci.draw_line(Vector2(rect.get_center().x, rect.position.y), Vector2(rect.get_center().x, rect.end.y), frame, 2.0)
	ci.draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), frame, 2.0)
	ci.draw_rect(Rect2(rect.position.x - 5.0, rect.end.y + 2.0, rect.size.x + 10.0, 4.0), tint(STONE.darkened(0.1), amb))


static func door(ci: CanvasItem, rect: Rect2, color: Color, amb: Color, arched: bool = true) -> void:
	var c := tint(color, amb)
	var frame := tint(STONE_DARK.darkened(0.2), amb)
	ci.draw_rect(rect.grow_individual(4, 0, 4, 0), frame)
	if arched:
		ci.draw_circle(Vector2(rect.get_center().x, rect.position.y), rect.size.x * 0.5 + 4.0, frame)
		ci.draw_circle(Vector2(rect.get_center().x, rect.position.y), rect.size.x * 0.5, c)
	ci.draw_rect(rect, c)
	var plank := tint(color.darkened(0.3), amb)
	for i in range(1, 3):
		var x := rect.position.x + rect.size.x * i / 3.0
		ci.draw_line(Vector2(x, rect.position.y - (rect.size.x * 0.3 if arched else 0.0)), Vector2(x, rect.end.y), plank, 1.5)
	ci.draw_circle(Vector2(rect.end.x - rect.size.x * 0.2, rect.get_center().y + 4.0), 2.5, tint(Color("c9a85a"), amb))


static func chimney(ci: CanvasItem, rect: Rect2, color: Color, amb: Color) -> void:
	ci.draw_rect(rect, tint(color, amb))
	ci.draw_rect(Rect2(rect.end.x - rect.size.x * 0.3, rect.position.y, rect.size.x * 0.3, rect.size.y), tint(color.darkened(0.22), amb))
	ci.draw_rect(Rect2(rect.position.x - 4.0, rect.position.y - 6.0, rect.size.x + 8.0, 8.0), tint(color.darkened(0.1), amb))


## Battlements along a wall top from `x0` to `x1`; merlons rise `h` above `y`.
static func crenels(ci: CanvasItem, x0: float, x1: float, y: float, w: float, h: float, color: Color, amb: Color) -> void:
	var c := tint(color, amb)
	var x := x0
	while x < x1 - w * 0.5:
		ci.draw_rect(Rect2(x, y - h, minf(w, x1 - x), h), c)
		x += w * 1.9


## A cone roof on a round tower.
static func cone(ci: CanvasItem, center_x: float, y_base: float, half_w: float, height: float, color: Color, amb: Color) -> void:
	var peak := Vector2(center_x, y_base - height)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(center_x - half_w, y_base), peak, Vector2(center_x + half_w, y_base)]),
		tint(color, amb))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(center_x + half_w * 0.25, y_base), peak, Vector2(center_x + half_w, y_base)]),
		tint(color.darkened(0.22), amb))
	ci.draw_line(Vector2(center_x - half_w, y_base), peak, tint(color.lightened(0.22), amb), 2.0)


## A banner on a pole. `sway` (-1..1) leans the cloth.
static func banner(ci: CanvasItem, top: Vector2, pole_h: float, w: float, h: float, color: Color, amb: Color, sway: float = 0.0) -> void:
	ci.draw_line(top, top + Vector2(0, pole_h), tint(TIMBER.darkened(0.2), amb), 3.0)
	ci.draw_circle(top, 3.5, tint(Color("c9a85a"), amb))
	var s := sway * 6.0
	var pts := PackedVector2Array([top + Vector2(2, 4), top + Vector2(2 + w, 6 + s * 0.4), top + Vector2(2 + w * 0.72 + s, 4 + h * 0.5),
		top + Vector2(2 + w + s, 2 + h), top + Vector2(2, 4 + h)])
	ci.draw_colored_polygon(pts, tint(color, amb))
	ci.draw_line(top + Vector2(2, 4 + h * 0.5), top + Vector2(2 + w * 0.7 + s, 4 + h * 0.5), tint(Color("e2c477"), amb), 2.0)


## A board hanging from a bracket, for shop signs. Returns the board's centre for the caller's icon.
static func sign_board(ci: CanvasItem, anchor: Vector2, amb: Color, dir: float = 1.0, size: Vector2 = Vector2(46, 40)) -> Vector2:
	var iron := tint(Color("2b2622"), amb)
	ci.draw_line(anchor, anchor + Vector2(dir * (size.x + 10.0), 0), iron, 3.0)
	ci.draw_line(anchor + Vector2(0, 16), anchor + Vector2(dir * 18.0, 0), iron, 2.0)
	var center := anchor + Vector2(dir * (size.x * 0.5 + 8.0), 10.0 + size.y * 0.5)
	ci.draw_line(center + Vector2(-size.x * 0.3, -size.y * 0.5), center + Vector2(-size.x * 0.3, -size.y * 0.5 - 10.0), iron, 1.5)
	ci.draw_line(center + Vector2(size.x * 0.3, -size.y * 0.5), center + Vector2(size.x * 0.3, -size.y * 0.5 - 10.0), iron, 1.5)
	var r := Rect2(center - size * 0.5, size)
	ci.draw_rect(r, tint(WOOD.darkened(0.15), amb))
	ci.draw_rect(r, tint(Color("c9a85a"), amb), false, 2.0)
	return center


## A small house for the rows behind the square. `v` (0-1) varies its shape and colours.
static func house(ci: CanvasItem, base: Vector2, w: float, h: float, v: float, glow: float, amb: Color) -> void:
	var walls: Array[Color] = [PLASTER, Color("cdbb96"), STONE, Color("c4b08c")]
	var roofs: Array[Color] = [ROOF_RED, ROOF_SLATE, Color("7a5040"), Color("5c4a44")]
	var wc := walls[int(v * 97.0) % walls.size()]
	var rc := roofs[int(v * 53.0) % roofs.size()]
	var rect := Rect2(base.x, base.y - h, w, h)
	wall(ci, rect, wc, amb, 6.0)
	roof(ci, base.x, base.x + w, base.y - h, h * (0.45 + 0.25 * fposmod(v * 7.0, 1.0)), w * 0.2, rc, amb, 6.0)
	var cols := maxi(1, int(w / 44.0))
	for i in cols:
		var wx := base.x + (i + 0.5) * w / cols - 7.0
		var on := fposmod(v * 13.0 + i * 0.37, 1.0) < 0.7
		window(ci, Rect2(wx, base.y - h * 0.62, 14.0, 18.0), glow if on else glow * 0.15, amb)
	if fposmod(v * 5.0, 1.0) > 0.5:
		chimney(ci, Rect2(base.x + w * 0.66, base.y - h * 1.5, 10.0, h * 0.3), STONE_DARK, amb)


## A soft cloud: a few overlapping ellipses.
static func cloud(ci: CanvasItem, center: Vector2, w: float, color: Color) -> void:
	for blob: Vector3 in [Vector3(0.0, 0.0, 1.0), Vector3(-0.34, 0.06, 0.7), Vector3(0.36, 0.05, 0.75), Vector3(0.12, -0.12, 0.6),
			Vector3(-0.14, -0.1, 0.5)]:
		var c := center + Vector2(blob.x * w, blob.y * w)
		ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.36))
		ci.draw_circle(Vector2.ZERO, w * 0.3 * blob.z, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A flame: flickers with `t` (seconds).
static func flame(ci: CanvasItem, base: Vector2, size: float, t: float, strength: float = 1.0) -> void:
	var f := 0.85 + 0.15 * sin(t * 11.0 + base.x) + 0.08 * sin(t * 23.0 + base.y)
	ci.draw_circle(base + Vector2(0, -size * 0.4), size * 3.2 * f, Color(FIRE, 0.07 * strength))
	ci.draw_circle(base + Vector2(0, -size * 0.4), size * 1.8 * f, Color(FIRE, 0.12 * strength))
	var lean := sin(t * 7.0 + base.x * 0.3) * size * 0.18
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-size * 0.5, 0), base + Vector2(lean, -size * 1.5 * f),
		base + Vector2(size * 0.5, 0)]), Color(FIRE, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-size * 0.26, 0), base + Vector2(lean * 0.6, -size * 0.9 * f),
		base + Vector2(size * 0.26, 0)]), Color("ffe08a"))
