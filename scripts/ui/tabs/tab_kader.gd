class_name TabKader
extends TabBase
## Kader als moderne Kartenliste. Rechtsklick (oder Doppelklick) öffnet das Spielerprofil.

const SORTS := ["Position", "Stärke", "Frische", "Form", "Marktwert", "Note"]

var _sort_select: OptionButton
var _list: VBoxContainer
var _profile: PlayerProfileDialog

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	top.add_child(heading("Kader"))
	var sort_label := Label.new()
	sort_label.text = "Sortieren:"
	sort_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	top.add_child(sort_label)
	_sort_select = OptionButton.new()
	for s in SORTS:
		_sort_select.add_item(s)
	_sort_select.item_selected.connect(func(_i): refresh())
	top.add_child(_sort_select)
	var hint := info_label()
	hint.text = "     Rechtsklick auf einen Spieler öffnet das Spielerprofil"
	top.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_profile = PlayerProfileDialog.new()
	add_child(_profile)

func refresh() -> void:
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()
	var c := Game.my_club()
	var squad := c.players(Game.world.players)
	match _sort_select.get_item_text(_sort_select.selected):
		"Stärke":
			squad.sort_custom(func(a, b): return a.strength > b.strength)
		"Frische":
			squad.sort_custom(func(a, b): return a.condition < b.condition)
		"Form":
			squad.sort_custom(func(a, b): return a.form > b.form)
		"Marktwert":
			squad.sort_custom(func(a, b): return a.market_value() > b.market_value())
		"Note":
			squad.sort_custom(func(a, b): return a.last_rating < b.last_rating if a.last_rating > 0 and b.last_rating > 0 else a.last_rating > b.last_rating)
		_:
			squad.sort_custom(func(a, b):
				var order_a: int = PlayerData.POSITIONS.find(a.pos)
				var order_b: int = PlayerData.POSITIONS.find(b.pos)
				if order_a != order_b:
					return order_a < order_b
				return a.strength > b.strength)
	for p in squad:
		_list.add_child(_player_row(p, c))

func _player_row(p: PlayerData, c: ClubData) -> PanelContainer:
	var is_starter: bool = c.lineup.has(p.id)
	var panel := PanelContainer.new()
	var style := UITheme.box(UITheme.FIELD, 10, UITheme.BORDER, 10)
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
				_profile.open_for(p.id))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	panel.add_child(line)

	line.add_child(UITheme.mini_pill(p.pos, PlayerProfileDialog.pos_color(p.pos), Color.WHITE, 42))

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = p.full_name()
	name_label.add_theme_font_size_override("font_size", 17)
	name_row.add_child(name_label)
	if is_starter:
		name_row.add_child(UITheme.mini_pill("Startelf", Color("#14532d"), Color("#bbf7d0"), 60))
	var sub := Label.new()
	sub.text = "%s  ·  %d Jahre  ·  Vertrag bis %s  ·  %s/Monat" % [
		PlayerData.POSITION_NAMES[p.pos], p.age, Game.contract_until(p), Fmt.money(p.salary)]
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	name_box.add_child(sub)

	# Stärke
	var strength_box := _stat_box("Stärke", str(p.strength), 60)
	line.add_child(strength_box)

	# Frische-Balken
	var cond_box := VBoxContainer.new()
	cond_box.add_theme_constant_override("separation", 2)
	cond_box.custom_minimum_size = Vector2(120, 0)
	line.add_child(cond_box)
	var cond_caption := Label.new()
	cond_caption.text = "Frische %d%%" % int(p.condition)
	cond_caption.add_theme_font_size_override("font_size", 12)
	cond_caption.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	cond_box.add_child(cond_caption)
	var cond_bar := ProgressBar.new()
	cond_bar.min_value = 0
	cond_bar.max_value = 100
	cond_bar.value = p.condition
	cond_bar.show_percentage = false
	cond_bar.custom_minimum_size = Vector2(0, 10)
	var cond_color := UITheme.ACCENT if p.condition >= 80 else (UITheme.WARN if p.condition >= 60 else UITheme.DANGER)
	cond_bar.add_theme_stylebox_override("fill", UITheme.box(cond_color, 5))
	cond_box.add_child(cond_bar)

	line.add_child(_stat_box("Form", Fmt.form_str(p.form), 56))
	line.add_child(_stat_box("Note", ("%.1f" % p.last_rating).replace(".", ",") if p.last_rating > 0.0 else "–", 50))
	line.add_child(_stat_box("Tore", str(p.goals_season), 46))
	line.add_child(_stat_box("Marktwert", Fmt.money(p.market_value()), 110))

	if p.is_injured():
		line.add_child(UITheme.mini_pill("Verletzt %d Sp." % p.injury_matchdays, Color("#7f1d1d"), Color.WHITE, 104))
	elif p.is_suspended():
		line.add_child(UITheme.mini_pill("Gesperrt %d Sp." % p.suspended_matchdays, Color("#854d0e"), Color.WHITE, 104))
	else:
		line.add_child(UITheme.mini_pill("fit", Color("#14532d"), Color("#bbf7d0"), 104))
	return panel

func _stat_box(caption: String, value: String, width: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(width, 0)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(cap)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 17)
	v.add_child(val)
	return v