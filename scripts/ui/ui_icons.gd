class_name UiIcons
extends RefCounted
## Small pictures drawn in code: the kinds of day, the city's stores, and a few marks.
## Each fits a square of side `size` centred on `c`.


static func swords(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	var w := maxf(2.0, size * 0.11)
	for dir: float in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(-dir * h * 0.7, h * 0.7), c + Vector2(dir * h * 0.78, -h * 0.78), color, w, true)
		ci.draw_line(c + Vector2(-dir * h * 0.78, h * 0.22), c + Vector2(-dir * h * 0.22, h * 0.78), color, w, true)


static func sun(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	ci.draw_circle(c, h * 0.42, color)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		ci.draw_line(c + d * h * 0.62, c + d * h * 0.95, color, maxf(1.5, size * 0.08), true)


## A rolled letter.
static func scroll(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	ci.draw_rect(Rect2(c.x - h * 0.55, c.y - h * 0.6, h * 1.1, h * 1.2), color)
	ci.draw_rect(Rect2(c.x - h * 0.75, c.y - h * 0.82, h * 1.5, h * 0.3), color.lightened(0.15))
	ci.draw_rect(Rect2(c.x - h * 0.75, c.y + h * 0.52, h * 1.5, h * 0.3), color.lightened(0.15))
	var ink := Color(0.15, 0.1, 0.08, 0.7 * color.a)
	for i in 3:
		var y := c.y - h * 0.28 + i * h * 0.28
		ci.draw_line(Vector2(c.x - h * 0.35, y), Vector2(c.x + h * 0.35, y), ink, 1.0)


## A horned skull, for a boss.
static func skull(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	var w := maxf(2.0, size * 0.1)
	ci.draw_arc(c + Vector2(-h * 0.5, -h * 0.35), h * 0.45, PI * 0.9, PI * 1.75, 8, color, w, true)
	ci.draw_arc(c + Vector2(h * 0.5, -h * 0.35), h * 0.45, PI * 1.25, PI * 2.1, 8, color, w, true)
	ci.draw_circle(c + Vector2(0, -h * 0.08), h * 0.5, color)
	ci.draw_rect(Rect2(c.x - h * 0.3, c.y + h * 0.25, h * 0.6, h * 0.4), color)
	var hole := Color(0.08, 0.05, 0.05, color.a)
	ci.draw_circle(c + Vector2(-h * 0.2, -h * 0.08), h * 0.13, hole)
	ci.draw_circle(c + Vector2(h * 0.2, -h * 0.08), h * 0.13, hole)
	ci.draw_line(c + Vector2(0, h * 0.4), c + Vector2(0, h * 0.62), hole, 1.5)


static func coin(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	ci.draw_circle(c + Vector2(1, 2), h * 0.8, Color(0, 0, 0, 0.4))
	ci.draw_circle(c, h * 0.8, color.darkened(0.25))
	ci.draw_circle(c, h * 0.62, color)
	ci.draw_arc(c, h * 0.4, PI * 0.9, PI * 1.6, 8, color.lightened(0.4), 1.5, true)


## A covered cart: what comes in when the smithy and the tavern have something new.
static func wagon(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	var wood := color.darkened(0.3)
	var cover := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		cover.append(c + Vector2(-h * 0.12, h * 0.1) + Vector2(cos(a) * h * 0.72, sin(a) * h * 0.78))
	ci.draw_colored_polygon(cover, color)
	ci.draw_rect(Rect2(c.x - h * 0.9, c.y + h * 0.1, h * 1.56, h * 0.26), wood)
	ci.draw_line(c + Vector2(h * 0.64, h * 0.22), c + Vector2(h, 0.0), wood, maxf(1.5, size * 0.08), true)
	for x: float in [-0.52, 0.28]:
		ci.draw_circle(c + Vector2(x * h, h * 0.56), h * 0.3, wood)
		ci.draw_circle(c + Vector2(x * h, h * 0.56), h * 0.11, color)


## A lump of ore.
static func ore(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.8, h * 0.5), c + Vector2(-h * 0.5, -h * 0.3), c + Vector2(-h * 0.05, -h * 0.75),
		c + Vector2(h * 0.6, -h * 0.35), c + Vector2(h * 0.85, h * 0.5)]), color.darkened(0.3))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.5, -h * 0.3), c + Vector2(-h * 0.05, -h * 0.75), c + Vector2(h * 0.1, -h * 0.05),
		c + Vector2(-h * 0.35, h * 0.2)]), color.lightened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.05, -h * 0.75), c + Vector2(h * 0.6, -h * 0.35), c + Vector2(h * 0.1, -h * 0.05)]),
		color.darkened(0.05))


## Two stacked logs.
static func timber(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	for row: Vector2 in [Vector2(-0.1, 0.38), Vector2(0.12, -0.2)]:
		var r := Rect2(c.x - h * 0.8 + row.x * h, c.y + row.y * h - h * 0.24, h * 1.5, h * 0.5)
		ci.draw_rect(r, color.darkened(0.2))
		ci.draw_circle(Vector2(r.end.x, r.get_center().y), h * 0.25, color.lightened(0.25))
		ci.draw_circle(Vector2(r.end.x, r.get_center().y), h * 0.1, color.darkened(0.2))


## A stretch of battlement, for the city's health.
static func rampart(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	ci.draw_rect(Rect2(c.x - h * 0.85, c.y - h * 0.2, h * 1.7, h * 0.9), color)
	for i in 3:
		ci.draw_rect(Rect2(c.x - h * 0.85 + i * h * 0.65, c.y - h * 0.7, h * 0.4, h * 0.55), color)


static func diamond(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r)]), color)


## A round portrait cropped from `tex` around `focus` (0-1), showing `span` (0-1) of the art's width.
static func portrait(ci: CanvasItem, c: Vector2, r: float, tex: Texture2D, focus: Vector2, span: float, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		ci.draw_circle(c, r, Color(0.2, 0.18, 0.16))
		return
	var ts := tex.get_size()
	var region := Vector2(span, span * ts.x / maxf(1.0, ts.y))
	var origin := focus - region * 0.5
	origin.x = clampf(origin.x, 0.0, 1.0 - region.x)
	origin.y = clampf(origin.y, 0.0, 1.0 - region.y)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var ground := PackedColorArray()
	for i in 36:
		var d := Vector2.from_angle(TAU * i / 36.0)
		pts.append(c + d * r)
		uvs.append(origin + (d * 0.5 + Vector2(0.5, 0.5)) * region)
		ground.append(UiTheme.PORTRAIT_BACK.lerp(UiTheme.PORTRAIT_BACK_LOW, d.y * 0.5 + 0.5) * Color(modulate.r, modulate.g, modulate.b, 1.0))
	# The art is a cut-out: give the face something to stand against.
	ci.draw_polygon(pts, ground)
	ci.draw_colored_polygon(pts, modulate, uvs, tex)


## The sign of a weapon type (WeaponData.WeaponType), bold enough to be told apart small: a long
## sword up to the right, a short broad dagger leaning the other way, a spear with a leaf head, an axe with a wide
## blade, a drawn bow with its arrow.
static func weapon(ci: CanvasItem, c: Vector2, size: float, type: int, color: Color) -> void:
	var h := size * 0.5
	var w := maxf(1.8, size * 0.1)
	var up := Vector2(0.62, -0.78)
	var side := up.orthogonal()
	match type:
		WeaponData.WeaponType.SWORD:
			var guard := c - up * h * 0.32
			ci.draw_line(guard, c + up * h * 0.78, color, w * 1.25, true)
			ci.draw_colored_polygon(PackedVector2Array([c + up * h * 1.02, c + up * h * 0.74 - side * w * 0.62, c + up * h * 0.74 + side * w * 0.62]), color)
			ci.draw_line(guard - side * h * 0.44, guard + side * h * 0.44, color, w * 1.15, true)
			ci.draw_line(guard, c - up * h * 0.82, color, w * 0.9, true)
			ci.draw_circle(c - up * h * 0.88, w * 0.85, color)
		WeaponData.WeaponType.DAGGER:
			# Short and broad, and leaning the other way from the sword: told apart by its stance.
			var lean := Vector2(-0.62, -0.78)
			var across := lean.orthogonal()
			var hilt := c - lean * h * 0.3
			ci.draw_colored_polygon(PackedVector2Array([hilt - across * h * 0.3, hilt + across * h * 0.3, c + lean * h * 0.98]), color)
			ci.draw_line(hilt - across * h * 0.46, hilt + across * h * 0.46, color, w * 1.05, true)
			ci.draw_line(hilt, c - lean * h * 0.82, color, w * 1.05, true)
			ci.draw_circle(c - lean * h * 0.88, w * 0.85, color)
		WeaponData.WeaponType.SPEAR:
			ci.draw_line(c - up * h * 0.98, c + up * h * 0.4, color, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + up * h * 1.04, c + up * h * 0.5 - side * h * 0.3, c + up * h * 0.26,
				c + up * h * 0.5 + side * h * 0.3]), color)
		WeaponData.WeaponType.AXE:
			ci.draw_line(c - up * h * 0.92, c + up * h * 0.78, color, w * 1.1, true)
			var head := c + up * h * 0.42
			ci.draw_colored_polygon(PackedVector2Array([head + up * h * 0.3, head + side * h * 0.72 + up * h * 0.5,
				head + side * h * 0.92, head + side * h * 0.72 - up * h * 0.5, head - up * h * 0.3]), color)
		_:
			# A bow: the stave, the string and an arrow on it, the whole of it centred on `c`.
			var hub := c + Vector2(-h * 0.74, 0)
			ci.draw_arc(hub, h * 0.92, -PI * 0.37, PI * 0.37, 20, color, w * 1.3, true)
			var top := hub + Vector2.from_angle(-PI * 0.37) * h * 0.92
			var foot := hub + Vector2.from_angle(PI * 0.37) * h * 0.92
			ci.draw_line(top, foot, color, w * 0.6, true)
			ci.draw_line(Vector2(c.x - h * 0.58, c.y), Vector2(c.x + h * 0.3, c.y), color, w * 0.85, true)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x + h * 0.6, c.y), Vector2(c.x + h * 0.18, c.y - h * 0.24),
				Vector2(c.x + h * 0.18, c.y + h * 0.24)]), color)


## The sign of a school of magic (SpellData.School): a sun for white, a waning moon for black.
static func school(ci: CanvasItem, c: Vector2, size: float, of: int, color: Color) -> void:
	if of == SpellData.School.WHITE:
		sun(ci, c, size, color)
		return
	var h := size * 0.5
	# The crescent lies to the right of its own circle's centre, so that centre sits a little left of `c`.
	var o := c + Vector2(-h * 0.21, 0)
	var pts := PackedVector2Array()
	for k in 21:
		pts.append(o + Vector2.from_angle(-PI * 0.5 + PI * k / 20.0) * h * 0.9)
	for k in 21:
		pts.append(o + Vector2(-h * 0.42, 0) + Vector2.from_angle(PI * 0.5 - PI * k / 20.0) * Vector2(h * 0.62, h * 0.9))
	ci.draw_colored_polygon(pts, color)


## A weapon type's sign (or, with `weapon_type` below 0, a school's) as a seal: a disc of `disc`, the
## sign cut out of it in a colour that stands against it. `size` is the disc's width.
static func seal(ci: CanvasItem, c: Vector2, size: float, weapon_type: int, of_school: int, disc: Color) -> void:
	var inner := Color(UiTheme.INK, disc.a) if disc.get_luminance() > 0.45 else Color(UiTheme.PARCHMENT.lightened(0.15), disc.a)
	ci.draw_circle(c, size * 0.5, disc)
	if weapon_type >= 0:
		weapon(ci, c, size * 0.74, weapon_type, inner)
	else:
		school(ci, c, size * 0.7, of_school, inner)


## A proficiency at a glance: the seal of the weapon type (or, with `weapon_type` below 0, of the
## school) and the grade's letter after it. `at` is the top left of a line `font_size` tall; returns
## the width used. `grade` may be "" for the seal alone.
static func proficiency(ci: CanvasItem, at: Vector2, weapon_type: int, of_school: int, grade: String, font_size: int, sign_ink: Color,
		grade_ink: Color, outline: int = 0) -> float:
	var font := UiTheme.display_font()
	var side := font_size * 1.4
	var c := at + Vector2(side * 0.5, font.get_height(font_size) * 0.5 + 1.0)
	if outline > 0:
		ci.draw_circle(c + Vector2(0, 1.5), side * 0.5 + 1.5, Color(0, 0, 0, 0.55))
	seal(ci, c, side, weapon_type, of_school, sign_ink)
	if grade == "":
		return side
	UiTheme.draw_text(ci, font, at + Vector2(side + 5.0, 0), grade, font_size, grade_ink, outline)
	return side + 5.0 + font.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Width proficiency() would use.
static func proficiency_width(grade: String, font_size: int) -> float:
	var side := font_size * 1.4
	if grade == "":
		return side
	return side + 5.0 + UiTheme.display_font().get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
