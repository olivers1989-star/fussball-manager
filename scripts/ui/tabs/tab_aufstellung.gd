class_name TabAufstellung
extends TabBase
## Aufstellung: Formation wählen, Startelf und Bank verwalten.

var _formation_select: OptionButton
var _starters_list: ItemList
var _bench_list: ItemList
var _message: Label
var _starter_ids: Array = []
var _bench_ids: Array = []
var _profile: PlayerProfileDialog

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(heading("Aufstellung"))
	var form_label := Label.new()
	form_label.text = "Formation:"
	top.add_child(form_label)
	_formation_select = OptionButton.new()
	for key in ClubData.FORMATIONS:
		_formation_select.add_item(key)
	_formation_select.item_selected.connect(_on_formation_changed)
	top.add_child(_formation_select)
	var auto_button := Button.new()
	auto_button.text = "Beste Elf aufstellen"
	auto_button.pressed.connect(_on_best_eleven)
	top.add_child(auto_button)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 24)
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lists)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_child(left)
	left.add_child(heading("Startelf"))
	_starters_list = ItemList.new()
	_starters_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_starters_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_child(right)
	right.add_child(heading("Bank"))
	_bench_list = ItemList.new()
	_bench_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_bench_list)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)
	var swap := Button.new()
	swap.text = "↔ Ausgewählte Spieler tauschen"
	swap.pressed.connect(_on_swap)
	bottom.add_child(swap)
	_message = info_label()
	bottom.add_child(_message)

	_profile = PlayerProfileDialog.new()
	add_child(_profile)
	for list in [_starters_list, _bench_list]:
		list.allow_rmb_select = true
		list.item_clicked.connect(func(index: int, _pos: Vector2, button: int):
			if button == MOUSE_BUTTON_RIGHT:
				_profile.open_for(int(list.get_item_metadata(index))))

func refresh() -> void:
	var c := Game.my_club()
	for i in _formation_select.item_count:
		if _formation_select.get_item_text(i) == c.formation:
			_formation_select.select(i)
			break
	# Ungültige Aufstellung (z. B. Verletzte oder verkaufte Spieler) automatisch reparieren
	c.lineup = c.match_lineup(Game.world.players).duplicate()
	_starter_ids = c.lineup.duplicate()
	_bench_ids = c.player_ids.filter(func(pid): return not _starter_ids.has(pid))
	_fill_list(_starters_list, _starter_ids)
	_fill_list(_bench_list, _bench_ids)

func _fill_list(list: ItemList, ids: Array) -> void:
	list.clear()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var pa: PlayerData = Game.get_player(a)
		var pb: PlayerData = Game.get_player(b)
		var order_a: int = PlayerData.POSITIONS.find(pa.pos)
		var order_b: int = PlayerData.POSITIONS.find(pb.pos)
		if order_a != order_b:
			return order_a < order_b
		return pa.rating() > pb.rating())
	for pid in sorted:
		var p := Game.get_player(pid)
		var status_info := ""
		if p.is_injured():
			status_info = "  🚑 %d Sp." % p.injury_matchdays
		elif p.is_suspended():
			status_info = "  🟥 Gesperrt %d Sp." % p.suspended_matchdays
		var idx := list.add_item("%s  %s  (St %d · Form %s · Frische %d%%)%s" % [
			p.pos, p.full_name(), p.strength, Fmt.form_icon(p.form), int(p.condition), status_info])
		list.set_item_metadata(idx, pid)

func _on_formation_changed(index: int) -> void:
	var c := Game.my_club()
	c.formation = _formation_select.get_item_text(index)
	c.lineup = c.best_eleven(Game.world.players)
	_message.text = "Formation %s gesetzt, beste Elf automatisch aufgestellt." % c.formation
	refresh()

func _on_best_eleven() -> void:
	var c := Game.my_club()
	c.lineup = c.best_eleven(Game.world.players)
	_message.text = "Beste Elf wurde aufgestellt."
	refresh()

func _on_swap() -> void:
	var sel_start := _starters_list.get_selected_items()
	var sel_bench := _bench_list.get_selected_items()
	if sel_start.is_empty() or sel_bench.is_empty():
		_message.text = "Bitte je einen Spieler in Startelf und Bank auswählen."
		return
	var pid_out: int = _starters_list.get_item_metadata(sel_start[0])
	var pid_in: int = _bench_list.get_item_metadata(sel_bench[0])
	var p_out := Game.get_player(pid_out)
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		if p_in.is_injured():
			_message.text = "%s ist verletzt (noch %d Spieltage)." % [p_in.full_name(), p_in.injury_matchdays]
		else:
			_message.text = "%s ist gesperrt (noch %d Spieltage)." % [p_in.full_name(), p_in.suspended_matchdays]
		return
	if p_out.group() != p_in.group():
		_message.text = "Tausch nur innerhalb der Positionsgruppe möglich (%s gegen %s)." % [p_out.pos, p_in.pos]
		return
	var c := Game.my_club()
	var idx := c.lineup.find(pid_out)
	c.lineup[idx] = pid_in
	_message.text = "%s kommt für %s in die Startelf." % [p_in.full_name(), p_out.full_name()]
	refresh()
