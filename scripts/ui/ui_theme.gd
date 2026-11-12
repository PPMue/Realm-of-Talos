class_name UiTheme
extends RefCounted
## Colours, fonts and drawing helpers shared by the battle UI.
## The look: dark ink panels, gold trim, and shapes that all lean the same way.

const INK := Color("0a0e17")
const PANEL := Color("131a28")
const PANEL_HI := Color("22304a")
const EDGE := Color("3d4d70")
const GOLD := Color("f4c552")
const GOLD_DEEP := Color("a8751c")
const TEXT := Color("f6f1e4")
const MUTED := Color("9aa7bf")
const HP := Color("e8505b")
const STA := Color("45c7c2")
const READY := Color("86e27a")
const RECOVERING := Color("f2a541")
const INJURED := Color("ff5d5d")
const DANGER := Color("ff7a45")
const HEAL := Color("8ff0a4")

const INTENT_COLORS := {
	EnemyActionData.Intent.ATTACK: Color("f0564a"),
	EnemyActionData.Intent.DEFEND: Color("5aa9f2"),
	EnemyActionData.Intent.BUFF: Color("f4c552"),
	EnemyActionData.Intent.DEBUFF: Color("b678f0"),
}

## How far slanted shapes lean: horizontal shift as a fraction of their height.
const SLANT := 0.24

static var _display: Font
static var _body: Font
static var _theme: Theme


## Condensed, heavy, slanted face for names, numbers and banners.
static func display_font() -> Font:
	if _display == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
		sys.font_weight = 700
		sys.font_stretch = 80
		var slanted := FontVariation.new()
		slanted.base_font = sys
		slanted.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.18, 1.0), Vector2.ZERO)
		_display = slanted
	return _display


## Upright face for descriptions, bars and small print.
static func body_font() -> Font:
	if _body == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Segoe UI", "Arial"])
		sys.font_weight = 600
		_body = sys
	return _body


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
			sb.bg_color = Color(PANEL, 0.9)
			sb.border_color = EDGE
			sb.set_border_width_all(2)
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			sb.skew = Vector2(SLANT, 0)
			if state == "hover" or state == "pressed":
				sb.bg_color = PANEL_HI
				sb.border_color = GOLD
			if state == "focus":
				sb.draw_center = false
				sb.border_color = Color(GOLD, 0.0)
			t.set_stylebox(state, "Button", sb)
		t.set_font("font", "Button", display_font())
		t.set_font_size("font_size", "Button", 24)
		t.set_color("font_color", "Button", TEXT)
		t.set_color("font_hover_color", "Button", GOLD)
		t.set_color("font_pressed_color", "Button", GOLD)
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


## A parallelogram filling `rect`, leaning right at the top.
static func para(rect: Rect2, slant_px: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + slant_px, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - slant_px, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])


static func slant_for(height: float) -> float:
	return height * SLANT


static func fill_para(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	var s := slant_for(rect.size.y)
	if rect.size.x <= s + 1.0 or rect.size.y <= 1.0:
		return
	var pts := para(rect, s)
	ci.draw_colored_polygon(pts, color)
	stroke_points(ci, pts, color, 1.0)


static func stroke_para(ci: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var s := slant_for(rect.size.y)
	if rect.size.x <= s + 1.0 or rect.size.y <= 1.0:
		return
	stroke_points(ci, para(rect, s), color, width)


static func stroke_points(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


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
