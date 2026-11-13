class_name StoreScreen
extends Control
## The shop and the tavern on free days: a list with prices, what the player can afford, and why
## anything cannot be bought. The first purchase (or hire) of the day spends one free-day action.

signal closed

enum Mode { SHOP, TAVERN }

var run: Run
var mode := Mode.SHOP
var _title: Label
var _hint: Label
var _gold: Label
var _note: Label
var _list := VBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open_shop(p_run: Run) -> void:
	_open(p_run, Mode.SHOP)


func open_tavern(p_run: Run) -> void:
	_open(p_run, Mode.TAVERN)


func close() -> void:
	visible = false
	closed.emit()


func buy(item: ShopItemData) -> void:
	var w := run.buy(item)
	if w != null:
		_note.text = "Bought %s. It waits in the armory: hand it out on the party screen." % w.data.display_name
		refresh()


func hire(data: CompanionData) -> void:
	var c := run.hire(data)
	if c != null:
		_note.text = "%s joins the party%s." % [c.display_name(), ", fielded" if run.is_fielded(c) else ", in reserve"]
		refresh()


func _open(p_run: Run, p_mode: Mode) -> void:
	run = p_run
	mode = p_mode
	_note.text = ""
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_gold.text = "%d GOLD" % run.gold
	var key := Run.FreeAction.SHOP if mode == Mode.SHOP else Run.FreeAction.TAVERN
	var spent := run.actions_used.has(key)
	var action_note := "Already paid for today: more purchases are free." if spent else \
		"The first purchase uses one of today's actions (%d left)." % run.actions_left
	if mode == Mode.SHOP:
		_title.text = "SHOP"
		_hint.text = "Weapons go to the armory. Stronger weapons need a higher grade in their type to be held.  " + action_note
		for item in run.shop_stock():
			_list.add_child(_shop_row(item))
	else:
		_title.text = "TAVERN"
		_hint.text = ("Companions looking for work today. They join at full health with their own weapon.  " + action_note).replace("purchase", "hire")
		for data in run.tavern_offers:
			_list.add_child(_tavern_row(data))
		if run.tavern_offers.is_empty():
			_list.add_child(UiTheme.label("Nobody else is looking for work today.", 22, UiTheme.MUTED))


func _shop_row(item: ShopItemData) -> RowButton:
	var w := item.weapon
	var row := RowButton.new(1500.0, 78.0)
	row.title = w.display_name.to_upper()
	var users: Array[String] = []
	for c in run.roster:
		if c.progress.can_equip_weapon(w):
			users.append(c.display_name())
	row.sub = "%s  ·  Mt %d  ·  Hit %d  ·  Weight %d  ·  needs %s grade %s  ·  %s" % [WeaponData.type_name(w.weapon_type).to_upper(),
		w.might, w.hit, w.weight, WeaponData.type_name(w.weapon_type).to_lower(), Proficiency.grade_name(w.required_grade),
		("can be held by " + ", ".join(users)) if not users.is_empty() else "nobody in the party has the grade yet"]
	var why := run.buy_block_reason(item)
	row.disabled = why != ""
	row.detail = "%d GOLD" % item.price if why == "" else "%d GOLD  ·  %s" % [item.price, why.trim_suffix(".").to_upper()]
	row.pressed.connect(buy.bind(item))
	return row


func _tavern_row(data: CompanionData) -> RowButton:
	var row := RowButton.new(1500.0, 110.0)
	row.texture = data.portrait
	row.texture_focus = data.portrait_focus + Vector2(0.0, 0.03)
	row.title = "%s   ·   JOINS AT LEVEL %d" % [data.display_name.to_upper(), run.hire_level()]
	var w := data.weapon
	var t := w.weapon_type
	row.sub = "HP %d  ·  STR %d  ·  DEX %d  ·  SPD %d  ·  DEF %d  ·  %s, %s grade %s  ·  signature art %s" % [data.max_hp, data.strength,
		data.dexterity, data.speed, data.defense, w.display_name, WeaponData.type_name(t).to_lower(),
		Proficiency.grade_name(data.starting_grade(t)), data.signature_art.display_name if data.signature_art != null else "none"]
	var why := run.hire_block_reason(data)
	row.disabled = why != ""
	row.detail = "%d GOLD" % RunConfig.HIRE_COST if why == "" else "%d GOLD  ·  %s" % [RunConfig.HIRE_COST, why.trim_suffix(".").to_upper()]
	row.pressed.connect(hire.bind(data))
	return row


func _build() -> void:
	var backdrop := CityBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_title = UiTheme.label("", 60, UiTheme.GOLD, true, 8)
	_title.position = Vector2(60, 24)
	add_child(_title)
	_hint = UiTheme.label("", 19, UiTheme.MUTED)
	_hint.position = Vector2(64, 100)
	add_child(_hint)

	var purse := SlantPanel.new()
	purse.fill = Color(UiTheme.INK, 0.9)
	purse.border = UiTheme.GOLD
	purse.border_width = 3.0
	purse.position = Vector2(1180, 22)
	purse.size = Vector2(300, 62)
	add_child(purse)
	_gold = UiTheme.label("", 34, UiTheme.GOLD, true)
	_gold.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purse.add_child(_gold)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(170, 160)
	scroll.size = Vector2(1560, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	_note = UiTheme.label("", 22, UiTheme.READY, true, 6)
	_note.position = Vector2(180, 990)
	add_child(_note)

	var back := Button.new()
	back.text = "BACK"
	back.tooltip_text = "Back to the city."
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 32)
	back.position = Vector2(1540, 22)
	back.size = Vector2(320, 62)
	back.pressed.connect(close)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
