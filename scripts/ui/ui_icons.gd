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
	for i in 36:
		var d := Vector2.from_angle(TAU * i / 36.0)
		pts.append(c + d * r)
		uvs.append(origin + (d * 0.5 + Vector2(0.5, 0.5)) * region)
	ci.draw_colored_polygon(pts, modulate, uvs, tex)
