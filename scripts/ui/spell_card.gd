class_name SpellCard
extends Control
## One known spell on the arts screen: tier, name, school, what it does, and its uses left.
## Display only: every known spell can be cast, so there is nothing to equip.

const W := ArtCard.W
const H := 104.0
const TAG_W := 196.0

var spell: SpellData
var uses_left := 0
var signature := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size


func _draw() -> void:
	if spell == null:
		return
	var color := UiTheme.school_color(spell.school)
	var rect := Rect2(Vector2.ZERO, Vector2(W, H))
	UiTheme.fill_para(self, rect, Color(UiTheme.PANEL, 0.94))
	UiTheme.stroke_para(self, rect, Color(color, 0.7), 2.0)

	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var s := UiTheme.slant_for(H)

	# Tier badge in the school's colour.
	var badge := Rect2(s * 0.5 + 16.0, 16.0, 78.0, H - 32.0)
	UiTheme.fill_para(self, badge, Color(color, [0.35, 0.65, 1.0][clampi(spell.tier - 1, 0, 2)]))
	UiTheme.draw_text(self, display, Vector2(badge.position.x, badge.position.y + (badge.size.y - display.get_height(36)) * 0.5),
		CombatArtData.tier_numeral(spell.tier), 36, UiTheme.INK, 0, badge.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	var x := badge.end.x + 22.0
	UiTheme.draw_text(self, display, Vector2(x, 12.0), spell.display_name.to_upper(), 34, UiTheme.TEXT, 6)
	var meta := "%s  ·  TIER %d  ·  NO STAMINA  ·  RECOVERY %d" % [spell.school_text().to_upper(), spell.tier, spell.recovery]
	UiTheme.draw_text(self, body, Vector2(x, 60.0), meta, 15, color)

	var text_x := 520.0
	var text_w := W - TAG_W - 60.0 - text_x
	draw_multiline_string(body, Vector2(text_x, 14.0 + body.get_ascent(17)), spell.description, HORIZONTAL_ALIGNMENT_LEFT,
		text_w, 17, 1, UiTheme.TEXT)
	draw_multiline_string(body, Vector2(text_x, 44.0 + body.get_ascent(16)), spell.effect_summary(), HORIZONTAL_ALIGNMENT_LEFT,
		text_w, 16, 2, color)

	# Uses left on the right.
	var tag := Rect2(W - TAG_W - s * 0.5 - 20.0, 22.0, TAG_W, H - 44.0)
	var empty := uses_left <= 0
	UiTheme.fill_para(self, tag, Color(UiTheme.INK, 0.9))
	UiTheme.stroke_para(self, tag, UiTheme.INJURED if empty else color, 2.0)
	UiTheme.draw_text(self, display, Vector2(tag.position.x, tag.position.y + (tag.size.y - display.get_height(24)) * 0.5),
		"USES  %d / %d" % [uses_left, spell.uses], 24, UiTheme.INJURED if empty else color, 0, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var note := "SIGNATURE" if signature else ("REST TO RESTORE" if empty else "")
	if note != "":
		UiTheme.draw_text(self, body, Vector2(tag.position.x - 10.0, H - 21.0), note, 13,
			UiTheme.RECOVERING if empty else UiTheme.MUTED, 0, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
