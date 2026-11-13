class_name UiTheme
extends RefCounted
## Colours, fonts and drawing helpers shared by every screen.
## The look: things from the world rather than an interface. Dark iron-bound wood for frames, brass
## trim, parchment for anything written, and a book serif for all text.

const INK := Color("120e0b")
const PANEL := Color("211913")
const PANEL_HI := Color("35281c")
const EDGE := Color("5c4a34")
const GOLD := Color("d8b46c")
const GOLD_DEEP := Color("7d6032")
const TEXT := Color("efe6d0")
const MUTED := Color("a39780")
const HP := Color("b5463f")
const STA := Color("5b9f96")
const READY := Color("9fc27a")
const RECOVERING := Color("d9973f")
const INJURED := Color("d9584f")
const DANGER := Color("d97a45")
const HEAL := Color("a5d6a0")
## Paper: letters, reports and maps are written on it in dark ink.
const PARCHMENT := Color("dccba0")
const PARCHMENT_SHADE := Color("b59f72")
const PARCHMENT_INK := Color("2e2218")
const PARCHMENT_MUTED := Color("6b5a42")
const WAX := Color("8f2f2a")
## Behind a cut-out face in a frame or a ring: lighter than the boards, so dark hair still shows.
const PORTRAIT_BACK := Color("73654f")
const PORTRAIT_BACK_LOW := Color("3c3126")
## Magic schools: Black (offence) and White (support).
const BLACK_MAGIC := Color("9c7fd6")
const WHITE_MAGIC := Color("cfe3ee")
## An effective strike (e.g. a bow against a flying enemy).
const EFFECTIVE := Color("f0cf5a")
## A reflecting stance: striking the enemy hurts the striker.
const REFLECT := Color("d35a94")
## Damage over time (poison, burning).
const POISON := Color("a9c653")
## A countdown lowered by an order, and recovery lengthened by the enemy.
const HASTE := Color("e0914a")

const INTENT_COLORS := {
	EnemyActionData.Intent.ATTACK: Color("c9503f"),
	EnemyActionData.Intent.DEFEND: Color("5e8fc0"),
	EnemyActionData.Intent.BUFF: Color("d8b46c"),
	EnemyActionData.Intent.DEBUFF: Color("9a70c2"),
}

static func school_color(school: int) -> Color:
	return BLACK_MAGIC if school == SpellData.School.BLACK else WHITE_MAGIC


## How far shapes lean: horizontal shift as a fraction of their height. The game once leaned every
## panel; it is upright now, and layouts that add `SLANT * height` simply add nothing.
const SLANT := 0.0
## Horizontal scale of the display face.
const DISPLAY_SQUEEZE := 0.92
const GRAIN_SIZE := 512

static var _display: Font
static var _body: Font
static var _italic: Font
static var _grain: Texture2D
static var _theme: Theme


## Bold book serif for names, numbers and titles, a little narrowed so long titles fit.
static func display_font() -> Font:
	if _display == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"])
		sys.font_weight = 700
		var narrowed := FontVariation.new()
		narrowed.base_font = sys
		narrowed.variation_transform = Transform2D(Vector2(DISPLAY_SQUEEZE, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
		_display = narrowed
	return _display


## The same serif, regular weight, for descriptions, bars and small print.
static func body_font() -> Font:
	if _body == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"])
		sys.font_weight = 400
		_body = sys
	return _body


## Italic, for words spoken or written by someone in the world.
static func italic_font() -> Font:
	if _italic == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman"])
		sys.font_italic = true
		_italic = sys
	return _italic


static func theme() -> Theme:
	if _theme == null:
		var t := Theme.new()
		t.default_font = body_font()
		t.default_font_size = 20

		var tip := StyleBoxFlat.new()
		tip.bg_color = Color(INK, 0.96)
		tip.border_color = GOLD_DEEP
		tip.set_border_width_all(2)
		tip.set_content_margin_all(12)
		t.set_stylebox("panel", "TooltipPanel", tip)
		t.set_color("font_color", "TooltipLabel", TEXT)
		t.set_font_size("font_size", "TooltipLabel", 18)

		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(PANEL, 0.95)
			sb.border_color = GOLD_DEEP
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(3)
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			if state == "hover" or state == "pressed":
				sb.bg_color = PANEL_HI
				sb.border_color = GOLD
			if state == "disabled":
				sb.border_color = Color(EDGE, 0.6)
			if state == "focus":
				sb.draw_center = false
				sb.border_color = Color(GOLD, 0.0)
			t.set_stylebox(state, "Button", sb)
		t.set_font("font", "Button", display_font())
		t.set_font_size("font_size", "Button", 24)
		t.set_color("font_color", "Button", TEXT)
		t.set_color("font_hover_color", "Button", GOLD)
		t.set_color("font_pressed_color", "Button", GOLD)
		t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
		_theme = t
	return _theme


static func label(text: String, font_size: int, color: Color = TEXT, display: bool = false, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", display_font() if display else body_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(INK, 0.95))
		l.add_theme_constant_override("outline_size", outline)
	return l


## The four corners of `rect`, shifted by `slant_px` at the top. Upright now that SLANT is 0.
static func para(rect: Rect2, slant_px: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + slant_px, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - slant_px, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


static func slant_for(height: float) -> float:
	return height * SLANT


## How much the corners of a plate of this size are cut.
static func cut_for(rect_size: Vector2) -> float:
	var m := minf(rect_size.x, rect_size.y)
	return 0.0 if m < 16.0 else clampf(m * 0.12, 2.0, 7.0)


## `rect` with its corners cut off, like a plate of metal or a board.
static func plate(rect: Rect2, cut: float = -1.0) -> PackedVector2Array:
	var c := cut_for(rect.size) if cut < 0.0 else cut
	if c <= 0.0:
		return para(rect, 0.0)
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([
		Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c)])


## A flat plate filling `rect`. (The name is from when panels leaned.)
static func fill_para(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var pts := plate(rect)
	ci.draw_colored_polygon(pts, color)
	stroke_points(ci, pts, color, 1.0)


static func stroke_para(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	stroke_points(ci, plate(rect), color, width)


static func stroke_points(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


## Soft mottling shared by wood, iron and paper, so no surface is a flat colour.
static func grain() -> Texture2D:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 5
		noise.fractal_gain = 0.6
		_grain = ImageTexture.create_from_image(noise.get_image(GRAIN_SIZE, GRAIN_SIZE))
	return _grain


static func draw_grain(ci: CanvasItem, rect: Rect2, strength: float, warm: Color = Color(1.0, 0.88, 0.7)) -> void:
	if strength <= 0.0 or rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	var region := Vector2(minf(rect.size.x, GRAIN_SIZE), minf(rect.size.y, GRAIN_SIZE))
	# A different patch for each place, so neighbouring panels do not share the same blotches.
	var off := Vector2(fposmod(rect.position.x * 3.7 + rect.size.x, GRAIN_SIZE - region.x + 1.0),
		fposmod(rect.position.y * 2.3 + rect.size.y, GRAIN_SIZE - region.y + 1.0))
	ci.draw_texture_rect_region(grain(), rect, Rect2(off, region), Color(warm, strength))


## A framed board: fill with grain, a lit top edge, a dark outline, the trim, and studs at the corners
## of large frames. Every panel and button in the game is one of these.
static func draw_frame(ci: CanvasItem, rect: Rect2, fill: Color, trim: Color, trim_width: float = 2.0, studs: bool = true) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var pts := plate(rect)
	var c := cut_for(rect.size)
	ci.draw_colored_polygon(pts, fill)
	draw_grain(ci, rect.grow(-c), 0.07 * fill.a)
	if rect.size.y > 30.0 and fill.a > 0.5:
		# Lit from above: a pale line under the top edge and a shadow along the bottom.
		ci.draw_line(Vector2(rect.position.x + c + 2.0, rect.position.y + 2.5), Vector2(rect.end.x - c - 2.0, rect.position.y + 2.5),
			Color(1.0, 0.92, 0.78, 0.07), 1.0)
		var sh := minf(18.0, rect.size.y * 0.25)
		ci.draw_polygon(PackedVector2Array([Vector2(rect.position.x + c, rect.end.y - sh), Vector2(rect.end.x - c, rect.end.y - sh),
			Vector2(rect.end.x - c, rect.end.y - 1.0), Vector2(rect.position.x + c, rect.end.y - 1.0)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.22 * fill.a), Color(0, 0, 0, 0.22 * fill.a)]))
	if trim_width <= 0.0:
		stroke_points(ci, pts, fill, 1.0)
		return
	stroke_points(ci, plate(rect.grow(1.0), c + 0.5), Color(0, 0, 0, 0.55 * trim.a), 2.0)
	stroke_points(ci, pts, trim, trim_width)
	if studs and rect.size.x >= 150.0 and rect.size.y >= 96.0:
		var inset := c + 7.0
		for p: Vector2 in [rect.position + Vector2(inset, inset), Vector2(rect.end.x - inset, rect.position.y + inset),
				rect.end - Vector2(inset, inset), Vector2(rect.position.x + inset, rect.end.y - inset)]:
			ci.draw_circle(p + Vector2(0.5, 1.0), 3.2, Color(0, 0, 0, 0.5 * trim.a))
			ci.draw_circle(p, 2.6, trim.darkened(0.15))
			ci.draw_circle(p + Vector2(-0.7, -0.8), 1.0, trim.lightened(0.4))


## A sheet of paper: pale in the middle, browned toward the edges, with a thin inked border.
static func draw_parchment(ci: CanvasItem, rect: Rect2, edge: float = 0.5) -> void:
	if rect.size.x <= 4.0 or rect.size.y <= 4.0:
		return
	# Shadow under the sheet.
	ci.draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(rect, PARCHMENT)
	draw_grain(ci, rect, 0.22, Color(0.45, 0.33, 0.18))
	var clear := Color(PARCHMENT_SHADE, 0.0)
	var dark := Color(PARCHMENT_SHADE.darkened(0.25), edge)
	var m := minf(90.0, minf(rect.size.x, rect.size.y) * 0.3)
	var a := rect.position
	var b := rect.end
	ci.draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), Vector2(b.x, a.y + m), Vector2(a.x, a.y + m)]),
		PackedColorArray([dark, dark, clear, clear]))
	ci.draw_polygon(PackedVector2Array([Vector2(a.x, b.y - m), Vector2(b.x, b.y - m), b, Vector2(a.x, b.y)]),
		PackedColorArray([clear, clear, dark, dark]))
	ci.draw_polygon(PackedVector2Array([a, Vector2(a.x + m, a.y), Vector2(a.x + m, b.y), Vector2(a.x, b.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	ci.draw_polygon(PackedVector2Array([Vector2(b.x - m, a.y), Vector2(b.x, a.y), b, Vector2(b.x - m, b.y)]),
		PackedColorArray([clear, dark, dark, clear]))
	ci.draw_rect(rect.grow(-7.0), Color(PARCHMENT_INK, 0.35), false, 1.0)
	ci.draw_rect(rect, Color(PARCHMENT_INK, 0.7), false, 1.5)


## A thin rule with a small diamond in the middle, to part a title from what follows.
static func draw_rule(ci: CanvasItem, center: Vector2, width: float, color: Color) -> void:
	var h := width * 0.5
	ci.draw_line(center - Vector2(h, 0), center - Vector2(9, 0), color, 1.0, true)
	ci.draw_line(center + Vector2(9, 0), center + Vector2(h, 0), color, 1.0, true)
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 0), center + Vector2(0, -5), center + Vector2(5, 0),
		center + Vector2(0, 5)]), color)


## Text drawn with a dark outline, positioned by its top-left corner.
static func draw_text(ci: CanvasItem, font: Font, top_left: Vector2, text: String, font_size: int, color: Color,
		outline: int = 0, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var pos := top_left + Vector2(0, font.get_ascent(font_size))
	if outline > 0:
		ci.draw_string_outline(font, pos, text, align, width, font_size, outline, Color(INK, 0.95))
	ci.draw_string(font, pos, text, align, width, font_size, color)


# ---------------------------------------------------------------- icons (drawn, no image files)

static func draw_hourglass(ci: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var a := size * 0.36
	var b := size * 0.5
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-a, -b), center + Vector2(a, -b), center]), color)
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-a, b), center + Vector2(a, b), center]), color)
	var cap := maxf(2.0, size * 0.12)
	ci.draw_line(center + Vector2(-a - 2, -b), center + Vector2(a + 2, -b), color, cap)
	ci.draw_line(center + Vector2(-a - 2, b), center + Vector2(a + 2, b), color, cap)


static func draw_intent_icon(ci: CanvasItem, intent: EnemyActionData.Intent, center: Vector2, size: float, color: Color) -> void:
	var h := size * 0.5
	match intent:
		EnemyActionData.Intent.ATTACK:
			# Sword: blade, crossguard, grip.
			var w := maxf(2.0, size * 0.16)
			ci.draw_line(center + Vector2(-h * 0.45, h * 0.45), center + Vector2(h * 0.9, -h * 0.9), color, w, true)
			ci.draw_line(center + Vector2(-h * 0.75, -h * 0.05), center + Vector2(h * 0.05, h * 0.75), color, w, true)
			ci.draw_line(center + Vector2(-h * 0.9, h * 0.9), center + Vector2(-h * 0.45, h * 0.45), color, w * 1.3, true)
		EnemyActionData.Intent.DEFEND:
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-h * 0.8, -h * 0.85), center + Vector2(h * 0.8, -h * 0.85),
				center + Vector2(h * 0.8, h * 0.1), center + Vector2(0, h),
				center + Vector2(-h * 0.8, h * 0.1)]), color)
		EnemyActionData.Intent.BUFF:
			_draw_chevrons(ci, center, h, color, -1.0)
		EnemyActionData.Intent.DEBUFF:
			_draw_chevrons(ci, center, h, color, 1.0)


static func _draw_chevrons(ci: CanvasItem, center: Vector2, h: float, color: Color, dir: float) -> void:
	var w := maxf(2.0, h * 0.32)
	for offset: float in [-0.35, 0.35]:
		var tip := center + Vector2(0, (offset + 0.3 * dir) * h * 1.1)
		ci.draw_polyline(PackedVector2Array([
			tip + Vector2(-h * 0.75, -dir * h * 0.6), tip, tip + Vector2(h * 0.75, -dir * h * 0.6)]), color, w, true)
