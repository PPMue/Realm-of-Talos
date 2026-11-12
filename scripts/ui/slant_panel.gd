class_name SlantPanel
extends Control
## A leaning panel: flat fill or a cropped piece of art, with an optional border and bottom shade.

var fill := UiTheme.PANEL:
	set(v):
		fill = v
		queue_redraw()
var border := UiTheme.EDGE:
	set(v):
		border = v
		queue_redraw()
var border_width := 2.0:
	set(v):
		border_width = v
		queue_redraw()
## Art to show instead of the flat fill, cropped to cover the panel.
var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
## Point of the art (0-1) kept in the middle of the crop.
var focus := Vector2(0.5, 0.5):
	set(v):
		focus = v
		queue_redraw()
## 1 = show as much of the art as fits; higher zooms in on the focus.
var zoom := 1.0:
	set(v):
		zoom = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()
## Strength of a dark fade over the lower half, so text on top stays readable.
var shade := 0.0:
	set(v):
		shade = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var s := UiTheme.slant_for(size.y)
	if size.x <= s + 1.0 or size.y <= 1.0:
		return
	var pts := UiTheme.para(rect, s)
	if texture != null:
		draw_colored_polygon(pts, tint, _uvs(pts), texture)
	else:
		draw_colored_polygon(pts, fill)
	if shade > 0.0:
		var mid_y := size.y * 0.45
		var mid_shift := s * (1.0 - 0.45)
		var lower := PackedVector2Array([
			Vector2(mid_shift, mid_y), Vector2(size.x - s + mid_shift, mid_y),
			Vector2(size.x - s, size.y), Vector2(0, size.y)])
		var clear := Color(UiTheme.INK, 0.0)
		var dark := Color(UiTheme.INK, shade)
		draw_polygon(lower, PackedColorArray([clear, clear, dark, dark]))
	if border_width > 0.0:
		UiTheme.stroke_points(self, pts, border, border_width)
	else:
		UiTheme.stroke_points(self, pts, tint if texture != null else fill, 1.0)


## UVs that crop the art to the panel's shape without stretching it.
func _uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var tex_size := texture.get_size()
	var tex_aspect := tex_size.x / maxf(1.0, tex_size.y)
	var aspect := size.x / maxf(1.0, size.y)
	var region := Vector2.ONE
	if aspect >= tex_aspect:
		region = Vector2(1.0, tex_aspect / aspect)
	else:
		region = Vector2(aspect / tex_aspect, 1.0)
	region /= maxf(1.0, zoom)
	var origin := focus - region * 0.5
	origin.x = clampf(origin.x, 0.0, 1.0 - region.x)
	origin.y = clampf(origin.y, 0.0, 1.0 - region.y)
	var out := PackedVector2Array()
	for p in pts:
		out.append(origin + Vector2(p.x / size.x, p.y / size.y) * region)
	return out
