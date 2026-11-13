class_name InteriorBackdrop
extends Control
## The inside of a building, behind its screen: a plank wall, a fire to one side (the tavern's hearth
## or the smithy's forge), a hanging lantern, and shadow in the corners. Drawn in code.

enum Kind { TAVERN, SMITHY, BARRACKS, YARD, INFIRMARY }

var kind := Kind.TAVERN:
	set(v):
		kind = v
		queue_redraw()

var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	var wall := Color("241a12")
	var glow := Color(1.0, 0.62, 0.28)
	if kind == Kind.SMITHY:
		wall = Color("1d1a19")
		glow = Color(1.0, 0.45, 0.16)
	elif kind == Kind.BARRACKS:
		wall = Color("1f1c1a")
		glow = Color(1.0, 0.7, 0.4)
	elif kind == Kind.INFIRMARY:
		# Whitewash gone grey in the lamplight.
		wall = Color("27221d")
		glow = Color(1.0, 0.74, 0.46)
	elif kind == Kind.YARD:
		# The yard's palisade, with a brazier for the fire.
		wall = Color("2b2118")
		glow = Color(1.0, 0.72, 0.42)
	draw_rect(Rect2(0, 0, w, h), wall)
	UiTheme.draw_grain(self, Rect2(0, 0, w, h), 0.14)
	# Upright boards, and a beam across the top.
	var x := 0.0
	var i := 0
	while x < w:
		var bw := 150.0 + 46.0 * ((i * 7) % 3)
		draw_rect(Rect2(x, 0, bw, h), Color(1.0, 0.85, 0.65, 0.012 * ((i * 5) % 4)))
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0, 0, 0, 0.4), 2.0)
		x += bw
		i += 1
	draw_rect(Rect2(0, 118, w, 22), wall.darkened(0.35))
	draw_line(Vector2(0, 140), Vector2(w, 140), Color(0, 0, 0, 0.5), 2.0)
	# Stone floor; in the yard, trodden sand.
	draw_rect(Rect2(0, h - 70.0, w, 70.0), Color("4a3d2a") if kind == Kind.YARD else Color("15120f"))
	draw_line(Vector2(0, h - 70.0), Vector2(w, h - 70.0), Color(0, 0, 0, 0.6), 3.0)

	# The fire, low on the left, and the light it throws.
	var fire := Vector2(92.0, h - 96.0)
	var flick := 0.88 + 0.08 * sin(_time * 8.0) + 0.04 * sin(_time * 19.0)
	for k in 10:
		draw_circle(fire + Vector2(0, -30), 90.0 + 110.0 * k, Color(glow, 0.05 * flick))
	if kind == Kind.YARD:
		# A brazier on three legs.
		var iron := Color("1c1815")
		for dx: float in [-40.0, 0.0, 40.0]:
			draw_line(fire + Vector2(dx * 0.6, 12.0), fire + Vector2(dx, 26.0 + 44.0), iron, 6.0)
		draw_colored_polygon(PackedVector2Array([fire + Vector2(-58, 4), fire + Vector2(58, 4), fire + Vector2(40, 30),
			fire + Vector2(-40, 30)]), iron)
		draw_rect(Rect2(fire.x - 62.0, fire.y, 124.0, 8.0), Color("3a332e"))
	else:
		draw_rect(Rect2(fire.x - 70.0, fire.y - 96.0, 140.0, 122.0), Color("0d0b0a"))
		draw_rect(Rect2(fire.x - 86.0, fire.y - 112.0, 172.0, 18.0), Color("3a332e"))
		draw_rect(Rect2(fire.x - 86.0, fire.y - 112.0, 18.0, 140.0), Color("3a332e"))
		draw_rect(Rect2(fire.x + 68.0, fire.y - 112.0, 18.0, 140.0), Color("2e2824"))
		draw_rect(Rect2(fire.x - 46.0, fire.y + 6.0, 92.0, 10.0), Color("2a1a10"))
	for dx: float in [-24.0, 0.0, 22.0]:
		CityArt.flame(self, fire + Vector2(dx, 8.0), 26.0 if dx == 0.0 else 18.0, _time + dx)
	if kind == Kind.SMITHY:
		for k in 6:
			var p := fposmod(_time * 0.5 + k * 0.17, 1.0)
			draw_circle(fire + Vector2(sin(k * 2.3 + p * 4.0) * 40.0, -40.0 - 220.0 * p), 2.0, Color(1.0, 0.75, 0.3, 0.9 * (1.0 - p)))

	# A lantern hanging from the beam on the right.
	var lamp := Vector2(w - 150.0, 230.0)
	draw_line(Vector2(lamp.x, 140), lamp + Vector2(0, -22), Color("15110e"), 2.0)
	for k in 7:
		draw_circle(lamp, 46.0 + 70.0 * k, Color(1.0, 0.75, 0.4, 0.022 * flick))
	draw_rect(Rect2(lamp.x - 13, lamp.y - 22, 26, 40), Color("15110e"))
	draw_rect(Rect2(lamp.x - 9, lamp.y - 16, 18, 28), Color(1.0, 0.8, 0.45, 0.95))

	# Shadow gathers in the corners.
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0, 0, 0, 0.55)
	draw_polygon(PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.55, h)]),
		PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 150), Vector2(0, 150)]), PackedColorArray([dark, dark, clear, clear]))
