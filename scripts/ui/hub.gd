extends Control
## Manager-Zentrale: Sidebar-Navigation, Kopfleiste mit Vereinsinfos und Inhaltsbereich.

const SCREEN_ORDER := ["Übersicht", "Tabelle", "Spielplan", "Kader", "Aufstellung", "Training", "Transfermarkt", "Finanzen"]

var _screens := {}        # Titel -> TabBase
var _nav_buttons := {}    # Titel -> Button
var _active_screen := ""

var _badge_slot: HBoxContainer
var _badge: Label
var _club_name_label: Label
var _club_league_label: Label
var _season_label: Label
var _position_label: Label
var _budget_label: Label
var _next_match_label: Label
var _toast: Label
var _menu_dialog: ConfirmationDialog
var _season_dialog: AcceptDialog
var _offers_dialog: ConfirmationDialog
var _offers_list: ItemList
var _pending_offers: Array = []

func _ready() -> void:
	if not Game.initialized:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")
		return
	add_to_group("hub")
	_build_ui()
	update_topbar()
	show_screen("Übersicht")
	if Game.season_over():
		_show_season_end.call_deferred()

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ------------------------------------------------------------ Sidebar
	var sidebar_panel := PanelContainer.new()
	var side_style := UITheme.box(UITheme.SURFACE, 0)
	side_style.content_margin_left = 14
	side_style.content_margin_right = 14
	side_style.content_margin_top = 18
	side_style.content_margin_bottom = 18
	sidebar_panel.add_theme_stylebox_override("panel", side_style)
	sidebar_panel.custom_minimum_size = Vector2(250, 0)
	root.add_child(sidebar_panel)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	sidebar_panel.add_child(side)

	_badge_slot = HBoxContainer.new()
	_badge_slot.add_theme_constant_override("separation", 12)
	side.add_child(_badge_slot)
	var club_text := VBoxContainer.new()
	club_text.add_theme_constant_override("separation", 0)
	club_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_club_name_label = Label.new()
	_club_name_label.add_theme_font_size_override("font_size", 17)
	_club_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_club_name_label.custom_minimum_size = Vector2(160, 0)
	club_text.add_child(_club_name_label)
	_club_league_label = Label.new()
	_club_league_label.add_theme_font_size_override("font_size", 13)
	_club_league_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	club_text.add_child(_club_league_label)
	_badge_slot.add_child(club_text)

	side.add_child(_vspace(14))

	for title in SCREEN_ORDER:
		var b := Button.new()
		b.text = title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(show_screen.bind(title))
		UITheme.style_nav(b, false)
		side.add_child(b)
		_nav_buttons[title] = b

	var side_spacer := Control.new()
	side_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(side_spacer)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.add_theme_color_override("font_color", UITheme.ACCENT)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_toast)

	var save_button := Button.new()
	save_button.text = "Speichern"
	save_button.pressed.connect(_on_save)
	side.add_child(save_button)
	var menu_button := Button.new()
	menu_button.text = "Hauptmenü"
	menu_button.pressed.connect(func(): _menu_dialog.popup_centered())
	side.add_child(menu_button)

	# ------------------------------------------------------------ Hauptbereich
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 0)
	root.add_child(main)

	var topbar_panel := PanelContainer.new()
	var top_style := UITheme.box(Color("#101724"), 0)
	top_style.content_margin_left = 24
	top_style.content_margin_right = 24
	top_style.content_margin_top = 12
	top_style.content_margin_bottom = 12
	topbar_panel.add_theme_stylebox_override("panel", top_style)
	main.add_child(topbar_panel)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	topbar_panel.add_child(top)

	var season_box := VBoxContainer.new()
	season_box.add_theme_constant_override("separation", 0)
	top.add_child(season_box)
	_season_label = Label.new()
	_season_label.add_theme_font_size_override("font_size", 19)
	season_box.add_child(_season_label)
	_position_label = Label.new()
	_position_label.add_theme_font_size_override("font_size", 14)
	_position_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	season_box.add_child(_position_label)

	top.add_child(_stat_box("Budget", "_budget"))
	top.add_child(_stat_box("Nächstes Spiel", "_next"))

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)

	var play_button := Button.new()
	play_button.text = "▶  Spieltag anpfeifen"
	play_button.add_theme_font_size_override("font_size", 19)
	play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(play_button)
	play_button.pressed.connect(_on_play_matchday)
	top.add_child(play_button)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content_margin.add_theme_constant_override(margin_side, 20)
	main.add_child(content_margin)

	_screens = {
		"Übersicht": TabUebersicht.new(),
		"Tabelle": TabTabelle.new(),
		"Spielplan": TabSpielplan.new(),
		"Kader": TabKader.new(),
		"Aufstellung": TabAufstellung.new(),
		"Training": TabTraining.new(),
		"Transfermarkt": TabTransfermarkt.new(),
		"Finanzen": TabFinanzen.new(),
	}
	for title in _screens:
		_screens[title].visible = false
		content_margin.add_child(_screens[title])

	# ------------------------------------------------------------ Dialoge
	_menu_dialog = ConfirmationDialog.new()
	_menu_dialog.dialog_text = "Zurück zum Hauptmenü?\nNicht gespeicherter Fortschritt geht verloren."
	_menu_dialog.ok_button_text = "Zum Hauptmenü"
	_menu_dialog.cancel_button_text = "Abbrechen"
	_menu_dialog.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(_menu_dialog)

	_season_dialog = AcceptDialog.new()
	_season_dialog.title = "Saisonende"
	_season_dialog.ok_button_text = "Neue Saison starten"
	_season_dialog.confirmed.connect(_on_season_dialog_confirmed)
	add_child(_season_dialog)

	_offers_dialog = ConfirmationDialog.new()
	_offers_dialog.title = "Jobangebote"
	_offers_dialog.ok_button_text = "Angebot annehmen"
	_offers_dialog.cancel_button_text = "Beim Verein bleiben"
	_offers_dialog.min_size = Vector2i(700, 320)
	var offers_box := VBoxContainer.new()
	var offers_label := Label.new()
	offers_label.text = "Dein Ruf ist gewachsen – diese Vereine wollen dich als Trainer:"
	offers_box.add_child(offers_label)
	_offers_list = ItemList.new()
	_offers_list.custom_minimum_size = Vector2(650, 200)
	offers_box.add_child(_offers_list)
	_offers_dialog.add_child(offers_box)
	_offers_dialog.confirmed.connect(_on_offer_accepted)
	add_child(_offers_dialog)

func _stat_box(caption: String, kind: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(cap)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 18)
	v.add_child(value)
	if kind == "_budget":
		_budget_label = value
	else:
		_next_match_label = value
	return v

func _vspace(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

# ------------------------------------------------------------------ Navigation

func show_screen(title: String) -> void:
	if not _screens.has(title):
		return
	if _active_screen != "" and _screens.has(_active_screen):
		_screens[_active_screen].visible = false
	_active_screen = title
	var screen: TabBase = _screens[title]
	if screen is TabTabelle and screen.get_meta("initialized", false) == false:
		screen.select_my_league()
		screen.set_meta("initialized", true)
	screen.visible = true
	screen.refresh()
	for nav_title in _nav_buttons:
		UITheme.style_nav(_nav_buttons[nav_title], nav_title == title)

func _refresh_active_screen() -> void:
	if _active_screen != "":
		_screens[_active_screen].refresh()

func update_topbar() -> void:
	var c := Game.my_club()
	# Vereins-Badge neu aufbauen (kann sich durch Vereinswechsel ändern)
	if is_instance_valid(_badge):
		_badge_slot.remove_child(_badge)
		_badge.free()
	_badge = UITheme.club_badge(c.short_name, Color(c.color))
	_badge_slot.add_child(_badge)
	_badge_slot.move_child(_badge, 0)
	_club_name_label.text = c.name
	_club_league_label.text = "%s · %s" % [Game.my_league().name, Game.manager_name]

	_season_label.text = "%s · Spieltag %d/34" % [Game.season_label(), mini(Game.matchday() + 1, 34)]
	_position_label.text = "Tabellenplatz %d · %s" % [Game.my_league().position_of(Game.my_club_id), Game.my_league().name]
	_budget_label.text = Fmt.money(c.budget)

	var f := Game.next_fixture(Game.my_club_id)
	if f.is_empty():
		_next_match_label.text = "Saison beendet"
	else:
		var home := int(f.home) == c.id
		var opponent := Game.club(int(f.away) if home else int(f.home))
		_next_match_label.text = "%s %s" % ["vs" if home else "bei", opponent.name]

# ------------------------------------------------------------------ Aktionen

func _on_save() -> void:
	var save_name := Game.save_game()
	_toast.text = "Gespeichert: %s ✓" % save_name if not save_name.is_empty() else "Speichern fehlgeschlagen!"
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_toast):
			_toast.text = "")

func _on_play_matchday() -> void:
	if Game.season_over():
		_show_season_end()
		return
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_season_dialog_confirmed() -> void:
	update_topbar()
	_refresh_active_screen()
	# Echte Karriere: Nach der Saison können bessere Vereine anklopfen
	if Game.game_mode == "angebote":
		_maybe_show_offers()

func _maybe_show_offers() -> void:
	_pending_offers = Game.season_offers()
	if _pending_offers.is_empty():
		return
	_offers_list.clear()
	for cid in _pending_offers:
		var c := Game.club(cid)
		var lg := Game.league(c.league_id)
		var idx := _offers_list.add_item("%s  ·  %s  ·  Teamstärke ~%d  ·  Budget %s" % [
			c.name, lg.name, c.base_strength, Fmt.money(c.budget)])
		_offers_list.set_item_metadata(idx, cid)
	_offers_list.select(0)
	_offers_dialog.popup_centered()

func _on_offer_accepted() -> void:
	if _offers_list.get_selected_items().is_empty():
		return
	var cid: int = _offers_list.get_item_metadata(_offers_list.get_selected_items()[0])
	Game.switch_club(cid)
	_toast.text = "Neuer Trainerposten: %s ✓" % Game.my_club().name
	update_topbar()
	_refresh_active_screen()

func _show_season_end() -> void:
	var s := Game.end_season()
	var lines := [
		"%s ist beendet!" % s.season,
		"",
		"Meister Erste Liga: %s" % s.champion1,
		"Meister Zweite Liga: %s" % s.champion2,
		"Dein Ergebnis: Platz %d (%s)" % [s.my_position, s.my_league_name],
		"",
		"Absteiger: %s" % ", ".join(s.relegated),
		"Aufsteiger: %s" % ", ".join(s.promoted),
	]
	if not s.retired.is_empty():
		lines.append("")
		lines.append("Karriereende bei deinem Verein: %s" % ", ".join(s.retired))
	_season_dialog.dialog_text = "\n".join(lines)
	_season_dialog.popup_centered()
