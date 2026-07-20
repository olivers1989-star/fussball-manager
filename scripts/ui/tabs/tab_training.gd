class_name TabTraining
extends TabBase
## Training: Wochenschwerpunkt wählen und Fitnesszustand des Kaders überblicken.

var _focus_select: OptionButton
var _focus_desc: Label
var _status: Label
var _tree: Tree

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(heading("Training"))

	var focus_row := HBoxContainer.new()
	focus_row.add_theme_constant_override("separation", 12)
	box.add_child(focus_row)
	var focus_label := Label.new()
	focus_label.text = "Wochenschwerpunkt:"
	focus_label.add_theme_font_size_override("font_size", 19)
	focus_row.add_child(focus_label)
	_focus_select = OptionButton.new()
	for focus in Game.TRAINING_FOCI:
		_focus_select.add_item(focus)
	_focus_select.item_selected.connect(_on_focus_changed)
	focus_row.add_child(_focus_select)
	_focus_desc = info_label()
	focus_row.add_child(_focus_desc)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	box.add_child(_status)

	box.add_child(heading("Fitnesszustand"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_tree, ["Pos.", "Name", "Frische", "Ausdauer", "Form", "Status"], 1)
	_tree.set_column_custom_minimum_width(0, 50)
	_tree.set_column_custom_minimum_width(5, 160)
	box.add_child(_tree)

func refresh() -> void:
	for i in _focus_select.item_count:
		if _focus_select.get_item_text(i) == Game.training_focus:
			_focus_select.select(i)
			break
	_focus_desc.text = Game.TRAINING_FOCI[Game.training_focus]

	var squad := Game.my_club().players(Game.world.players)
	var cond_sum := 0.0
	var form_sum := 0.0
	var injured := 0
	var suspended := 0
	for p in squad:
		cond_sum += p.condition
		form_sum += p.form
		if p.is_injured():
			injured += 1
		if p.is_suspended():
			suspended += 1
	_status.text = "Ø Frische: %d%%    ·    Ø Form: %s    ·    Verletzte: %d    ·    Gesperrte: %d    ·    Trainer-Fähigkeit Training: %d/%d" % [
		int(cond_sum / squad.size()), Fmt.form_str(form_sum / squad.size()),
		injured, suspended, Game.skill("training"), Game.SKILL_MAX]

	_tree.clear()
	var root := _tree.create_item()
	squad.sort_custom(func(a, b): return a.condition < b.condition)
	for p in squad:
		var item := _tree.create_item(root)
		item.set_text(0, p.pos)
		item.set_text(1, p.full_name())
		item.set_text(2, "%d%%" % int(p.condition))
		item.set_text(3, str(p.stamina))
		item.set_text(4, Fmt.form_str(p.form))
		if p.is_injured():
			item.set_text(5, "Verletzt (%d Sp.)" % p.injury_matchdays)
			item.set_custom_color(5, Color("#f87171"))
		elif p.is_suspended():
			item.set_text(5, "Gesperrt (%d Sp.)" % p.suspended_matchdays)
			item.set_custom_color(5, Color("#facc15"))
		else:
			item.set_text(5, "fit")
		if p.condition <= 60:
			item.set_custom_color(2, Color("#f87171"))
		elif p.condition >= 90:
			item.set_custom_color(2, Color("#4ade80"))

func _on_focus_changed(index: int) -> void:
	Game.training_focus = _focus_select.get_item_text(index)
	_focus_desc.text = Game.TRAINING_FOCI[Game.training_focus]
