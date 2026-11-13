class_name CityBackdrop
extends Control
## The last city, drawn in code: sky, mountains, the wall with its gate and watchtower, rows of houses,
## the square with its fountain, and the nine buildings the player can visit. The time of day is one
## setting (`set_phase`) that recolours everything; clouds drift, chimneys smoke and torches flicker.
## The hub makes the buildings clickable; other screens use the same scene as a still backdrop.

signal building_pressed(kind: CityBuilding.Kind)

enum Phase { DAWN, MORNING, AFTERNOON, DUSK, NIGHT, DREAD }

const WALL_TOP := 372.0
const GROUND_Y := 472.0
const FOUNTAIN := Vector2(960, 800)

## One time of day.
class Daylight:
	var top: Color
	var mid: Color
	var low: Color
	## Sun or moon, as a fraction of the screen.
	var sun: Vector2
	var sun_color: Color
	## Multiplied into every surface.
	var ambient: Color
	## How strongly lamps and windows show (0-1).
	var glow: float
	var stars: float
	## Fires of the enemy beyond the wall (0-1).
	var fires: float
	var cloud: Color

	func mix(o: Daylight, t: float) -> Daylight:
		var s := Daylight.new()
		s.top = top.lerp(o.top, t)
		s.mid = mid.lerp(o.mid, t)
		s.low = low.lerp(o.low, t)
		s.sun = sun.lerp(o.sun, t)
		s.sun_color = sun_color.lerp(o.sun_color, t)
		s.ambient = ambient.lerp(o.ambient, t)
		s.glow = lerpf(glow, o.glow, t)
		s.stars = lerpf(stars, o.stars, t)
		s.fires = lerpf(fires, o.fires, t)
		s.cloud = cloud.lerp(o.cloud, t)
		return s


var buildings: Dictionary = {}
## True in the hub: buildings answer the pointer and carry name boards.
var interactive := false:
	set(v):
		interactive = v
		for b: CityBuilding in buildings.values():
			b.interactive = v

var _phase := Phase.NIGHT
var _from: Daylight
var _to: Daylight
var _blend := 1.0
var _sky: Daylight
var _time := 0.0
var _clouds := Control.new()
var _ambience := Control.new()
var _tween: Tween


static func sky_for(p: Phase) -> Daylight:
	var s := Daylight.new()
	match p:
		Phase.DAWN:
			s.top = Color("2c3a63"); s.mid = Color("9a7488"); s.low = Color("f2b184")
			s.sun = Vector2(0.80, 0.37); s.sun_color = Color("ffe0b0")
			s.ambient = Color(0.88, 0.78, 0.78); s.glow = 0.55; s.stars = 0.15; s.fires = 0.55
			s.cloud = Color(1.0, 0.78, 0.7, 0.6)
		Phase.MORNING:
			s.top = Color("4c8ac0"); s.mid = Color("9fc6df"); s.low = Color("ece2c4")
			s.sun = Vector2(0.70, 0.17); s.sun_color = Color("fff6d8")
			s.ambient = Color(1.0, 0.98, 0.93); s.glow = 0.0; s.stars = 0.0; s.fires = 0.0
			s.cloud = Color(1.0, 1.0, 1.0, 0.75)
		Phase.AFTERNOON:
			s.top = Color("4577a8"); s.mid = Color("b9b79a"); s.low = Color("f3cc92")
			s.sun = Vector2(0.30, 0.25); s.sun_color = Color("ffe9b0")
			s.ambient = Color(1.0, 0.92, 0.80); s.glow = 0.12; s.stars = 0.0; s.fires = 0.0
			s.cloud = Color(1.0, 0.93, 0.8, 0.7)
		Phase.DUSK:
			s.top = Color("2a2a58"); s.mid = Color("a2516c"); s.low = Color("f28d52")
			s.sun = Vector2(0.15, 0.39); s.sun_color = Color("ffa860")
			s.ambient = Color(0.80, 0.62, 0.64); s.glow = 0.9; s.stars = 0.35; s.fires = 0.25
			s.cloud = Color(0.95, 0.6, 0.55, 0.6)
		Phase.NIGHT:
			s.top = Color("070b1f"); s.mid = Color("161d45"); s.low = Color("37345e")
			s.sun = Vector2(0.72, 0.15); s.sun_color = Color("e4eaff")
			s.ambient = Color(0.38, 0.42, 0.60); s.glow = 1.0; s.stars = 1.0; s.fires = 0.3
			s.cloud = Color(0.35, 0.38, 0.55, 0.5)
		Phase.DREAD:
			s.top = Color("180c14"); s.mid = Color("5c2026"); s.low = Color("c8562c")
			s.sun = Vector2(0.5, 0.40); s.sun_color = Color("ff7040")
			s.ambient = Color(0.66, 0.48, 0.46); s.glow = 0.75; s.stars = 0.0; s.fires = 1.0
			s.cloud = Color(0.25, 0.12, 0.14, 0.7)
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_from = sky_for(_phase)
	_to = _from
	_sky = _from
	for node: Control in [_clouds, _ambience]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clouds.draw.connect(_draw_clouds)
	_ambience.draw.connect(_draw_ambience)
	add_child(_clouds)
	# Back to front: the wall's buildings, the far side of the square, then the near side.
	for kind: CityBuilding.Kind in [CityBuilding.Kind.WATCHTOWER, CityBuilding.Kind.GATE, CityBuilding.Kind.BARRACKS,
			CityBuilding.Kind.INN, CityBuilding.Kind.MASON, CityBuilding.Kind.YARD, CityBuilding.Kind.INFIRMARY, CityBuilding.Kind.TAVERN,
			CityBuilding.Kind.SMITHY]:
		var b := CityBuilding.new(kind)
		b.pressed.connect(func() -> void: building_pressed.emit(kind))
		buildings[kind] = b
		add_child(b)
	add_child(_ambience)
	_apply()


func building(kind: CityBuilding.Kind) -> CityBuilding:
	return buildings[kind]


func phase() -> Phase:
	return _phase


## Changes the time of day; the sky and every surface glide to it.
func set_phase(p: Phase, animate: bool = true) -> void:
	if p == _phase and _blend >= 1.0:
		return
	_from = _sky
	_to = sky_for(p)
	_phase = p
	if _tween != null:
		_tween.kill()
	if not animate or not is_inside_tree():
		_set_blend(1.0)
		return
	_blend = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_blend, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)


func _set_blend(v: float) -> void:
	_blend = v
	_sky = _from.mix(_to, v)
	_apply()


func _apply() -> void:
	for b: CityBuilding in buildings.values():
		b.ambient = _sky.ambient
		b.glow = _sky.glow
		b.queue_redraw()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	_clouds.queue_redraw()
	_ambience.queue_redraw()
	for b: CityBuilding in buildings.values():
		b.time = _time
		if b.is_lively() or b.kind == CityBuilding.Kind.BARRACKS or b.kind == CityBuilding.Kind.MASON or b.kind == CityBuilding.Kind.YARD \
				or b.kind == CityBuilding.Kind.INFIRMARY:
			b.queue_redraw()


# ---------------------------------------------------------------- the still scene

func _draw() -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	var s := _sky
	var amb := s.ambient
	_quad(0, 0, w, h * 0.22, s.top, s.mid)
	_quad(0, h * 0.22, w, GROUND_Y + 10.0, s.mid, s.low)

	if s.stars > 0.02:
		for i in 120:
			var x := fmod(i * 233.7, w)
			var y := fmod(i * 97.3 + i * i * 0.61, 360.0)
			draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.5, Color(1, 1, 1, (0.2 + 0.13 * (i % 4)) * s.stars))

	# Sun or moon.
	var sun := Vector2(w * s.sun.x, h * s.sun.y)
	for i in 12:
		draw_circle(sun, 36.0 + 20.0 * i, Color(s.sun_color, 0.028))
	draw_circle(sun, 30.0, s.sun_color)
	if s.stars > 0.6:
		draw_circle(sun + Vector2(11, -7), 26.0, s.top.lerp(s.mid, 0.5))

	_ridge(w, GROUND_Y - 30.0, 210.0, s.low.lerp(Color(0.34, 0.40, 0.56), 0.6).lerp(s.mid, 0.25), 0.4, 5.0)
	_ridge(w, GROUND_Y - 10.0, 130.0, CityArt.tint(Color(0.36, 0.42, 0.50), amb).lerp(s.low, 0.25), 2.1, 8.0)

	# The enemy's fires beyond the wall.
	if s.fires > 0.02:
		var clear := Color(1.0, 0.36, 0.14, 0.0)
		var hot := Color(1.0, 0.36, 0.14, 0.42 * s.fires)
		draw_polygon(PackedVector2Array([Vector2(0, WALL_TOP - 190.0), Vector2(w, WALL_TOP - 190.0), Vector2(w, WALL_TOP + 20.0),
			Vector2(0, WALL_TOP + 20.0)]), PackedColorArray([clear, clear, hot, hot]))
		for i in 5:
			var x := w * (0.08 + 0.21 * i) + 40.0 * sin(i * 2.3)
			var top_y := WALL_TOP - 210.0 - 40.0 * (i % 2)
			draw_polygon(PackedVector2Array([Vector2(x - 12, WALL_TOP), Vector2(x + 12, WALL_TOP), Vector2(x + 90, top_y),
				Vector2(x + 30, top_y)]), PackedColorArray([Color(0.08, 0.06, 0.08, 0.5 * s.fires), Color(0.08, 0.06, 0.08, 0.5 * s.fires),
				Color(0.08, 0.06, 0.08, 0.0), Color(0.08, 0.06, 0.08, 0.0)]))

	_wall(w, amb)
	# Distance: a veil of the horizon's colour over the wall.
	_quad(0, WALL_TOP - 80.0, w, GROUND_Y + 30.0, Color(s.low, 0.0), Color(s.low, 0.2))

	# The ground of the square, and the road up to the gate.
	_quad(0, GROUND_Y, w, h, CityArt.tint(Color("8f8573"), amb), CityArt.tint(Color("5a5146"), amb))
	draw_polygon(PackedVector2Array([Vector2(912, GROUND_Y), Vector2(1008, GROUND_Y), Vector2(1470, h), Vector2(450, h)]),
		PackedColorArray([CityArt.tint(Color(0.72, 0.68, 0.58, 0.9), amb), CityArt.tint(Color(0.72, 0.68, 0.58, 0.9), amb),
		CityArt.tint(Color(0.55, 0.51, 0.44, 0.0), amb), CityArt.tint(Color(0.55, 0.51, 0.44, 0.0), amb)]))

	_houses(w, 512.0, 0.78, 96.0, 0, s.glow, amb)
	_houses(w, 572.0, 1.0, 150.0, 1, s.glow, amb)
	_cobbles(w, h, amb)
	_fountain(amb, s)

	# Keep the top edge and the foot of the screen dark enough for what is written there.
	var ink := UiTheme.INK
	_quad(0, 0, w, 130.0, Color(ink, 0.6), Color(ink, 0.0))
	_quad(0, h - 230.0, w, h, Color(ink, 0.0), Color(ink, 0.78))


func _quad(x0: float, y0: float, x1: float, y1: float, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([top, top, bottom, bottom]))


func _ridge(w: float, base_y: float, height: float, color: Color, phase_shift: float, freq: float) -> void:
	var pts := PackedVector2Array([Vector2(0, base_y)])
	var steps := 64
	for i in steps + 1:
		var t := float(i) / steps
		var n := 0.5 + 0.28 * sin(t * freq + phase_shift) + 0.16 * sin(t * freq * 2.7 + phase_shift * 1.7) + 0.08 * sin(t * freq * 6.1)
		pts.append(Vector2(w * t, base_y - height * clampf(n, 0.08, 1.0)))
	pts.append(Vector2(w, base_y))
	draw_colored_polygon(pts, color)


func _wall(w: float, amb: Color) -> void:
	var stone := CityArt.STONE.darkened(0.1)
	CityArt.crenels(self, 0, w, WALL_TOP, 16, 13, stone, amb)
	draw_rect(Rect2(0, WALL_TOP, w, GROUND_Y - WALL_TOP), CityArt.tint(stone, amb))
	draw_rect(Rect2(0, WALL_TOP, w, 5.0), CityArt.tint(stone.lightened(0.2), amb))
	draw_polygon(PackedVector2Array([Vector2(0, WALL_TOP + 40.0), Vector2(w, WALL_TOP + 40.0), Vector2(w, GROUND_Y), Vector2(0, GROUND_Y)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3)]))
	var x := 30.0
	var k := 0
	while x < w:
		CityArt.stones(self, Rect2(x, WALL_TOP + 14.0, 200.0, GROUND_Y - WALL_TOP - 20.0), stone, amb, k)
		x += 210.0
		k += 1
	# Towers along the wall.
	for tx: float in [80.0, 600.0, 1290.0, 1500.0, 1800.0]:
		var top := WALL_TOP - 44.0
		CityArt.crenels(self, tx - 4.0, tx + 82.0, top, 14, 12, stone.lightened(0.04), amb)
		CityArt.wall(self, Rect2(tx, top, 78.0, GROUND_Y - top), stone.lightened(0.04), amb, 0.0)
		draw_rect(Rect2(tx + 35.0, top + 34.0, 8.0, 26.0), Color(0.05, 0.05, 0.07))


func _houses(w: float, base_y: float, scale_k: float, road_gap: float, row: int, glow: float, amb: Color) -> void:
	var x := -30.0 - 40.0 * row
	var i := 0
	while x < w + 40.0:
		var v := fposmod(i * 0.618 + row * 0.37 + 0.11, 1.0)
		var hw := (84.0 + 56.0 * fposmod(v * 3.0, 1.0)) * scale_k
		var hh := (56.0 + 40.0 * fposmod(v * 11.0, 1.0)) * scale_k
		var center := x + hw * 0.5
		# Leave the road to the gate open.
		if absf(center - 960.0) > road_gap + hw * 0.5:
			CityArt.house(self, Vector2(x, base_y), hw, hh, v, glow, amb)
		x += hw + 6.0 * scale_k
		i += 1


func _cobbles(w: float, h: float, amb: Color) -> void:
	var line := CityArt.tint(Color(0.2, 0.18, 0.15), amb)
	var y := 610.0
	var row := 0
	while y < h:
		var step := 46.0 + (y - 600.0) * 0.12
		var x := fposmod(row * 31.0, step) - step
		while x < w:
			var f := fposmod(x * 0.37 + row * 0.61, 1.0)
			if f < 0.42:
				draw_arc(Vector2(x, y + 8.0), step * 0.26, PI * 1.15, PI * 1.85, 6, Color(line, 0.2), 1.5)
			x += step
		y += 26.0 + (y - 600.0) * 0.07
		row += 1


func _fountain(amb: Color, s: Daylight) -> void:
	var c := FOUNTAIN
	_ellipse(c + Vector2(8, 26), 150, 36, Color(0, 0, 0, 0.28))
	_ellipse(c + Vector2(0, 12), 132, 34, CityArt.tint(CityArt.STONE_DARK, amb))
	_ellipse(c, 132, 34, CityArt.tint(CityArt.STONE.lightened(0.08), amb))
	_ellipse(c, 114, 26, s.mid.lerp(Color(0.08, 0.14, 0.2), 0.55))
	_ellipse(c + Vector2(-24, -4), 50, 9, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(c.x - 11, c.y - 74, 22, 76), CityArt.tint(CityArt.STONE, amb))
	draw_rect(Rect2(c.x + 4, c.y - 74, 7, 76), CityArt.tint(CityArt.STONE.darkened(0.22), amb))
	_ellipse(c + Vector2(0, -74), 40, 10, CityArt.tint(CityArt.STONE.lightened(0.1), amb))
	_ellipse(c + Vector2(0, -78), 30, 6, s.mid.lerp(Color(0.1, 0.16, 0.22), 0.5))
	draw_rect(Rect2(c.x - 5, c.y - 104, 10, 28), CityArt.tint(CityArt.STONE.lightened(0.05), amb))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- what moves

func _draw_clouds() -> void:
	var w := maxf(size.x, 1920.0)
	for i in 6:
		var speed := 5.0 + 2.2 * i
		var cw := 200.0 + 44.0 * ((i * 7) % 5)
		var x := fposmod(i * 371.0 + _time * speed, w + cw * 2.0) - cw
		var y := 60.0 + 34.0 * ((i * 5) % 6)
		CityArt.cloud(_clouds, Vector2(x, y), cw, _sky.cloud)


func _draw_ambience() -> void:
	var s := _sky
	# Smoke from the chimneys.
	var smoke := Color(0.78, 0.76, 0.76).lerp(s.low, 0.35)
	for b: CityBuilding in buildings.values():
		for src in b.smoke_points():
			for i in 7:
				var p := fposmod(_time * 0.07 + i / 7.0 + src.x * 0.013, 1.0)
				var pos := src + Vector2(46.0 * p * p + sin(p * 7.0 + i) * 7.0, -130.0 * p)
				_ambience.draw_circle(pos, 7.0 + 26.0 * p, Color(smoke, 0.2 * (1.0 - p) * minf(1.0, p * 8.0)))
		for f in b.fire_points():
			CityArt.flame(_ambience, f, 9.0 if b.kind != CityBuilding.Kind.SMITHY else 12.0, _time, 0.5 + 0.8 * s.glow)
	# The fountain's water.
	for i in 5:
		var p := fposmod(_time * 0.9 + i * 0.2, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := FOUNTAIN + Vector2(side * (6.0 + 24.0 * p), -104.0 + 60.0 * p * p - 18.0 * p)
		_ambience.draw_circle(pos, 2.2, Color(0.85, 0.93, 1.0, 0.55 * (1.0 - p)))
	# Birds over the roofs by day.
	if s.stars < 0.3 and s.fires < 0.5:
		var w := maxf(size.x, 1920.0)
		for i in 3:
			var x := fposmod(_time * (38.0 + 9.0 * i) + i * 640.0, w + 300.0) - 150.0
			var y := 190.0 + 46.0 * i + 14.0 * sin(_time * 0.7 + i)
			var flap := sin(_time * 9.0 + i * 2.0) * 5.0
			var ink := Color(0.1, 0.1, 0.14, 0.7)
			_ambience.draw_line(Vector2(x - 9, y - flap), Vector2(x, y), ink, 2.0, true)
			_ambience.draw_line(Vector2(x, y), Vector2(x + 9, y - flap), ink, 2.0, true)
