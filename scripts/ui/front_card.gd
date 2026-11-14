class_name FrontCard
extends Control
## One front to defend, as a scout's report on the war table: the enemies waiting there, the danger, what winning gives
## and what losing costs, the hardest blow they have against the line as it stands and the scouts' word
## for the fight (Run.front_account), and a button to go. Also used, wider, for the boss.

signal chosen

const W := 520.0
const BOSS_W := 980.0
const H := 560.0
const ART_H := 180.0
const PAD := 8.0
const DANGER_COLORS: Array[Color] = [Color("9fc27a"), Color("d9973f"), Color("d9584f")]
const DANGER_NAMES: Array[String] = ["LOW", "MEDIUM", "HIGH"]
## The scouts' word for the fight, by BattleAccount.Word.
const WORD_NAMES: Array[String] = ["A SURE FIGHT", "A CLOSE FIGHT", "A GRIM FIGHT"]
const WORD_COLORS: Array[Color] = [Color("9fc27a"), Color("d9973f"), Color("d9584f")]

var front: Front
## What Run.front_account says of the front ({} when nobody is in the line).
var account: Dictionary = {}
var _w := W
var _bg := SlantPanel.new()
var _button := ActionButton.new()
var _pips: Control
var _hover := false
var _over_card := false
var _over_button := false
var _enabled := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hover.bind(true, false))
	mouse_exited.connect(_set_hover.bind(false, false))
	_button.hover_changed.connect(func(inside: bool) -> void: _set_hover(inside, true))


## The card is lit while the pointer is anywhere on it, the button included: moving onto the button
## makes the card itself report the pointer gone, so the two are kept apart and either one lights it.
func _set_hover(inside: bool, on_button: bool) -> void:
	if on_button:
		_over_button = inside
	else:
		_over_card = inside
	var lit := _over_card or _over_button
	if lit == _hover:
		return
	_hover = lit
	if front != null:
		_restyle()


## `why_not`: when not "", the card cannot be chosen and says why instead. `p_account`: what
## Run.front_account says of the front for the line as it stands.
func setup(p_front: Front, hotkey: String, why_not: String = "", p_account: Dictionary = {}) -> void:
	front = p_front
	account = p_account
	_w = BOSS_W if front.is_boss else W
	custom_minimum_size = Vector2(_w, H)
	size = custom_minimum_size
	_enabled = why_not == ""

	_bg.size = size
	_bg.fill = Color(UiTheme.PANEL, 0.96)
	add_child(_bg)
	if front.is_boss:
		_setup_boss(hotkey, why_not)
		return

	_build_art()

	var y := PAD + ART_H + 14.0
	# Danger pips and word.
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.position = Vector2(_edge_x(y + 30.0) + 26.0, y)
	_pips.size = Vector2(_w - 60.0, 30)
	_pips.draw.connect(_draw_pips)
	add_child(_pips)
	y += 40.0

	var title := UiTheme.label(front.title().to_upper(), 44 if front.is_boss else 40, UiTheme.TEXT, true, 8)
	title.position = Vector2(_edge_x(y + 50.0) + 22.0, y)
	add_child(title)
	y += 54.0
	var who: Array[String] = []
	for e in front.enemies:
		who.append(e.display_name)
	var sub_text := front.group.display_name.to_upper() + "  ·  " + ", ".join(who)
	if front.is_boss:
		who.remove_at(0)
		sub_text = "BOSS" + ("  ·  with " + ", ".join(who) if not who.is_empty() else "  ·  alone")
	var sub := UiTheme.label(sub_text, 18, UiTheme.MUTED)
	sub.position = Vector2(_edge_x(y + 24.0) + 26.0, y)
	add_child(sub)
	y += 40.0

	y = _add_row(y, "REWARD", _reward_text(), UiTheme.GOLD)
	var loss := "THE CITY FALLS" if front.is_boss else "THE WALLS  -%d" % front.city_damage
	y = _add_row(y, "IF LOST", loss, UiTheme.INJURED)
	y = _add_account_rows(y)

	_button.title = "MARCH OUT" if not front.is_boss else "FACE IT"
	_button.hotkey = hotkey
	_button.detail = ""
	_button.position = Vector2(_edge_x(H - 18.0) + (_w - UiTheme.SLANT * H - ActionButton.W) * 0.5, H - 18.0 - ActionButton.H)
	_button.disabled = not _enabled
	_button.pressed.connect(func() -> void: chosen.emit())
	_button.tooltip_text = why_not if not _enabled else "Commit to this front. The party fights now; changes to the party are locked until tomorrow."
	add_child(_button)
	_restyle()


## The boss card: the boss's art large on the left; on the right its name, the one line on what makes
## it dangerous, its escorts, the reward, what losing means, and the button.
func _setup_boss(hotkey: String, why_not: String) -> void:
	var boss := front.enemies[0]
	var art := SlantPanel.new()
	var art_w := 430.0
	art.texture = boss.portrait
	art.focus = Vector2(0.5, 0.42)
	art.zoom = 1.0
	art.shade = 0.35
	art.border = Color(UiTheme.GOLD, 0.8)
	art.border_width = 3.0
	art.position = Vector2(_edge_x(H - PAD) + PAD, PAD)
	art.size = Vector2(art_w, H - PAD * 2.0)
	art.mouse_filter = Control.MOUSE_FILTER_PASS
	art.tooltip_text = enemy_info(boss)
	add_child(art)

	var x0 := art.position.x + art_w + 6.0
	var right := _w - 34.0
	var y := 26.0
	var day_text := "BOSS  ·  DAY %d" % front.group.min_day if front.group.min_day == front.group.max_day else "BOSS"
	var kicker := UiTheme.label(day_text, 20, UiTheme.GOLD, true, 6)
	kicker.position = Vector2(_edge_x(y + 24.0) + x0, y)
	add_child(kicker)
	y += 30.0
	var title := UiTheme.label(boss.display_name.to_upper(), 46, UiTheme.TEXT, true, 8)
	var size_px := 46
	while size_px > 26 and UiTheme.display_font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > right - x0 - 40.0:
		size_px -= 2
	title.add_theme_font_size_override("font_size", size_px)
	title.position = Vector2(_edge_x(y + 52.0) + x0 - 4.0, y)
	add_child(title)
	y += 58.0
	var desc := UiTheme.label(front.group.description, 19, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.35), false, 4)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(_edge_x(y + 84.0) + x0, y)
	desc.size = Vector2(right - x0 - 130.0, 84.0)
	add_child(desc)
	y += 88.0

	var escorts := front.enemies.slice(1)
	var head := UiTheme.label("ESCORTS" if not escorts.is_empty() else "ALONE  ·  NO ESCORTS", 18, UiTheme.MUTED, true)
	head.position = Vector2(_edge_x(y + 24.0) + x0, y)
	add_child(head)
	y += 28.0
	if not escorts.is_empty():
		var tile_w := 168.0
		var tile_h := 72.0
		for i in escorts.size():
			var e: EnemyData = escorts[i]
			var p := SlantPanel.new()
			p.texture = e.portrait
			p.focus = Vector2(0.5, 0.3)
			p.zoom = 1.5
			p.shade = 0.65
			p.border = Color(UiTheme.INK, 0.9)
			p.border_width = 2.0
			p.position = Vector2(_edge_x(y + tile_h) + x0 + i * (tile_w + 10.0), y)
			p.size = Vector2(tile_w, tile_h)
			p.mouse_filter = Control.MOUSE_FILTER_PASS
			p.tooltip_text = enemy_info(e)
			add_child(p)
			var n := UiTheme.label(e.display_name.to_upper(), 17, UiTheme.TEXT, true, 5)
			n.position = Vector2(UiTheme.slant_for(tile_h) * 0.2 + 10.0, tile_h - 28.0)
			p.add_child(n)
		y += tile_h + 14.0
	else:
		y += 4.0

	var rx := x0 - 22.0
	y = _add_row(y, "REWARD", _reward_text(), UiTheme.GOLD, rx, 0, 34.0)
	if front.gem > 0:
		y = _add_row(y, "STONE", "", UiTheme.GOLD, rx, front.gem, 34.0)
	y = _add_row(y, "IF LOST", "THE CITY FALLS", UiTheme.INJURED, rx, 0, 34.0)
	y = _add_account_rows(y, rx, 34.0)

	_button.title = "FACE IT"
	_button.hotkey = hotkey
	_button.detail = ""
	_button.position = Vector2(_edge_x(H - 18.0) + x0 + (right - x0 - ActionButton.W) * 0.5 - 20.0, H - 18.0 - ActionButton.H)
	_button.disabled = not _enabled
	_button.pressed.connect(func() -> void: chosen.emit())
	_button.tooltip_text = why_not if not _enabled else "Commit to the boss fight. The party fights now; losing ends the run."
	add_child(_button)
	_restyle()


func _reward_text() -> String:
	var parts: Array[String] = []
	if front.reward_gold > 0:
		parts.append("%d GOLD" % front.reward_gold)
	for m in RunConfig.MATERIAL_ORDER:
		if int(front.reward_materials.get(m, 0)) > 0:
			parts.append("%d %s" % [int(front.reward_materials[m]), String(RunConfig.MATERIAL_NAMES[m]).to_upper()])
	if front.xp_pool > 0:
		parts.append("%d XP" % front.xp_pool)
	if parts.is_empty():
		return "THE CITY IS SAVED"
	return "  ·  ".join(parts)


## The account before the fight, two lines: the hardest blow they have against the line as it stands
## ("CRUSHING BLOW  ·  21 TO FREYA", red when it would fell them), and the scouts' word.
func _add_account_rows(y: float, x: float = 0.0, pitch: float = 38.0) -> float:
	if account.is_empty():
		return y
	var blow: Dictionary = account.get("blow", {})
	if not blow.is_empty():
		var action: EnemyActionData = blow.action
		var target: CompanionUnit = blow.target
		var fells: bool = blow.fells
		var text := "%s  ·  %s %s" % [action.display_name.to_upper(), "FELLS" if fells else "%d TO" % int(blow.damage), target.display_name.to_upper()]
		y = _add_row(y, "WORST", text, UiTheme.INJURED if fells else UiTheme.TEXT, x, 0, pitch)
	var word := int(account.get("word", BattleAccount.Word.CLOSE))
	return _add_row(y, "SCOUTS", WORD_NAMES[word], WORD_COLORS[word], x, 0, pitch)


## One line of the report: a small heading and what it says. A long line shrinks to stay on the card.
## `gem`: the rank of a stone drawn in place of the text (what a win brings besides); 0 for none.
## `pitch`: the height the line takes.
func _add_row(y: float, head: String, text: String, color: Color, x: float = 0.0, gem: int = 0, pitch: float = 38.0) -> float:
	var h := UiTheme.label(head, 18, UiTheme.MUTED, true)
	h.position = Vector2(_edge_x(y + 30.0) + 26.0 + x, y + 4.0)
	add_child(h)
	var at := Vector2(_edge_x(y + 30.0) + 130.0 + x, y)
	if gem > 0:
		var font := UiTheme.display_font()
		var tag := Control.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.position = at
		tag.size = Vector2(240, 34)
		tag.draw.connect(func() -> void:
			UiIcons.gem(tag, Vector2(13.0, 18.0), 26.0, gem)
			UiTheme.draw_text(tag, font, Vector2(34.0, 2.0), Gem.name_of(gem).to_upper(), 24, UiIcons.gem_color(gem), 6))
		add_child(tag)
		return y + pitch
	var l := UiTheme.label(text, 24, color, true, 6)
	l.position = at
	var room := _w - at.x - 30.0
	add_child(l)
	# Measured once it is on the table: a label has no width to speak of before that.
	var fit := func() -> void:
		var px := 24
		while px > 15 and l.get_minimum_size().x > room:
			px -= 1
			l.add_theme_font_size_override("font_size", px)
		l.position.y = at.y + (24 - px) * 0.7
	l.ready.connect(fit)
	return y + pitch


func _build_art() -> void:
	var count := maxi(1, front.enemies.size())
	var inner := _w - UiTheme.SLANT * H + UiTheme.slant_for(ART_H) - PAD * 2.0
	var lean := UiTheme.slant_for(ART_H)
	# Neighbouring portraits share their leaning edge.
	var slot := (inner - lean) / count
	for i in front.enemies.size():
		var e := front.enemies[i]
		var p := SlantPanel.new()
		p.texture = e.portrait
		p.focus = Vector2(0.5, 0.2 if front.is_boss and i == 0 else 0.28)
		p.zoom = 1.0 if front.is_boss else (1.2 + 0.15 * (count - 1))
		p.shade = 0.7
		p.border = Color(UiTheme.INK, 0.9)
		p.border_width = 2.0
		p.position = Vector2(_edge_x(PAD + ART_H) + PAD + slot * i, PAD)
		p.size = Vector2(slot + lean, ART_H)
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.tooltip_text = enemy_info(e)
		add_child(p)
		var n := UiTheme.label(e.display_name.to_upper(), 20 if count > 2 else 24, UiTheme.TEXT, true, 6)
		n.position = Vector2(lean * 0.2 + 12.0, ART_H - 36.0)
		p.add_child(n)


## Stats and action list of an enemy, for tooltips.
static func enemy_info(e: EnemyData) -> String:
	var lines: Array[String] = [e.display_name,
		"HP %d   STR %d   MAG %d   DEF %d   RES %d   SPD %d   DEX %d   LCK %d" % [e.max_hp, e.strength, e.magic, e.defense,
			e.resistance, e.speed, e.dexterity, e.luck]]
	if e.role != "":
		lines.append(e.role)
	for t in e.traits:
		lines.append(EnemyTraits.describe(t))
	if e.ever_reversed():
		lines.append("Aims from the left: its single-target attacks use the position weights mirrored.")
	lines.append("")
	for a in e.actions:
		var what := EnemyActionData.intent_name(a.intent).capitalize()
		if a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS:
			what += ", everyone"
		if a.deals_damage:
			what += ", %s Mt %d" % ["magic" if a.damage_type == CombatMath.DamageType.MAGIC else "physical", a.might]
		if a.targeting == EnemyActionData.Targeting.ALL_ALLIES:
			what += ", every enemy"
		if a.heal_percent > 0:
			what += ", heals %d%% of max HP" % a.heal_percent
		if a.hasten_allies > 0:
			what += ", the other enemies act %d sooner" % a.hasten_allies
		if a.add_recovery > 0:
			what += ", +%d recovery" % a.add_recovery
		if a.effect != null:
			what += ", " + a.effect.summary()
		lines.append("%s  (countdown %d): %s" % [a.display_name, a.countdown, what])
	if e.has_phase():
		lines.append("")
		lines.append(("At %d%% HP: " % e.phase_hp_percent if e.phase_trigger == EnemyData.PhaseTrigger.HP_BELOW
			else "When it stands alone: ") + (e.phase_title.capitalize() if e.phase_title != "" else "it changes"))
		for a in e.phase_actions:
			lines.append("  %s  (countdown %d)" % [a.display_name, a.countdown])
	return "\n".join(lines)


func _draw_pips() -> void:
	var c := DANGER_COLORS[front.danger - 1]
	var font := UiTheme.display_font()
	UiTheme.draw_text(_pips, font, Vector2(0, 2), "DANGER", 20, UiTheme.MUTED)
	for i in 3:
		var r := Rect2(96.0 + i * 40.0, 2.0, 34.0, 24.0)
		UiTheme.fill_para(_pips, r, c if i < front.danger else Color(UiTheme.INK, 0.8))
		UiTheme.stroke_para(_pips, r, c if i < front.danger else UiTheme.EDGE, 2.0)
	UiTheme.draw_text(_pips, font, Vector2(226.0, 2), "ELITE" if front.is_elite else DANGER_NAMES[front.danger - 1], 22,
		DayStrip.type_color(RunCalendar.DayType.ELITE) if front.is_elite else c)
	if front.gem > 0:
		# The stone a win here brings, at the right end of the line.
		var stone := Gem.name_of(front.gem).to_upper()
		var sw := font.get_string_size(stone, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var right := _pips.size.x - 4.0
		UiTheme.draw_text(_pips, font, Vector2(right - sw, 3), stone, 20, UiIcons.gem_color(front.gem), 5)
		UiIcons.gem(_pips, Vector2(right - sw - 18.0, 15.0), 24.0, front.gem)


func _restyle() -> void:
	var lit := _hover and _enabled
	_bg.border = UiTheme.GOLD if lit or front.is_boss else UiTheme.EDGE
	_bg.border_width = 4.0 if lit else (3.0 if front.is_boss else 2.0)
	_bg.fill = Color(UiTheme.PANEL_HI, 0.97) if lit else Color(UiTheme.PANEL, 0.96)
	_button.active = lit


func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (H - y)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and _enabled:
		accept_event()
		chosen.emit()
