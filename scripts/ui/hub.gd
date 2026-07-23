extends Control
## Manager-Zentrale: Sidebar-Navigation, Kopfleiste mit Vereinsinfos und Inhaltsbereich.

const SCREEN_ORDER := ["Übersicht", "Trainer", "Kalender", "Tabelle", "Spielplan", "Kader", "Aufstellung", "Training", "Transfermarkt", "Finanzen"]

var _screens := {}        # Titel -> TabBase
var _nav_buttons := {}    # Titel -> Button
var _active_screen := ""

var _badge_slot: HBoxContainer
var _badge: Label
var _club_name_label: Label
var _club_league_label: Label
var _season_label: Label
var _position_label: Label
var _play_button: Button
var _budget_label: Label
var _next_match_label: Label
var _toast: Label
var _save_browser: SaveBrowser
var _talk_overlay: Control
var _talk_title: Label
var _talk_sub: Label
var _talk_says: Label
var _talk_replies: VBoxContainer
var _talk_result: Label
var _talk_close: Button
var _talk_decision := {}
var _friendly_dialog: AcceptDialog
var _menu_dialog: ConfirmationDialog
var _offers_dialog: ConfirmationDialog
var _offers_list: ItemList
var _pending_offers: Array = []
# Sichtbare Wochensimulation
var _sim_overlay: Control
var _sim_date_label: Label
var _sim_strip: HBoxContainer
var _sim_feed: ItemList
var _sim_timer: Timer
var _sim_pause_button: Button
var _sim_close_button: Button
var _sim_match_button: Button
var _decision_dialog: ConfirmationDialog
var _pending_decision := {}
var _prep_overlay: Control
var _prep_title: Label
var _prep_opp_slot: HBoxContainer
var _prep_opp_badge: Label
var _prep_opp_name: Label
var _prep_opp_sub: Label
var _prep_form_row: HBoxContainer
var _prep_details := {}
var _prep_select: OptionButton
var _prep_desc: Label
var _prep_hint: Label
var _prep_pending := false

func _ready() -> void:
	if not Game.initialized:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")
		return
	# Der 1. Juli gehört dem Saisonabschluss – der hat einen eigenen Bildschirm
	if Game.season_rollover_due():
		get_tree().change_scene_to_file.call_deferred("res://scenes/saison.tscn")
		return
	add_to_group("hub")
	_build_ui()
	update_topbar()
	show_screen("Übersicht")
	if Game.season_just_rolled:
		Game.season_just_rolled = false
		if Game.game_mode == "angebote":
			_maybe_show_offers.call_deferred()

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

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	side.add_child(save_row)
	var save_button := Button.new()
	save_button.text = "💾 Speichern"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save)
	save_row.add_child(save_button)
	var quick_button := Button.new()
	quick_button.text = "⚡"
	quick_button.tooltip_text = "Schnellspeichern (überschreibt den automatischen Spielstand)"
	quick_button.pressed.connect(_quick_save)
	save_row.add_child(quick_button)
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

	_play_button = Button.new()
	_play_button.add_theme_font_size_override("font_size", 19)
	_play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(_play_button)
	_play_button.pressed.connect(_on_play_pressed)
	top.add_child(_play_button)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content_margin.add_theme_constant_override(margin_side, 20)
	main.add_child(content_margin)

	_screens = {
		"Übersicht": TabUebersicht.new(),
		"Trainer": TabTrainer.new(),
		"Kalender": TabKalender.new(),
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

	_decision_dialog = ConfirmationDialog.new()
	_decision_dialog.min_size = Vector2i(560, 220)
	_decision_dialog.confirmed.connect(func(): _on_decision(0))
	_decision_dialog.canceled.connect(func(): _on_decision(1))
	add_child(_decision_dialog)

	_build_prep_overlay()

	_build_sim_overlay()

	_save_browser = SaveBrowser.new()
	_save_browser.saved.connect(func(save_name): _show_toast("Gespeichert: %s ✓" % save_name))
	add_child(_save_browser)

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

	_season_label.text = "%s · %s" % [Game.date_label(), Game.season_label()]
	_position_label.text = "Spieltag %d/%d · Platz %d · %s" % [
		Game.my_matchday_number(), Game.my_matchdays_total(),
		Game.my_league().position_of(Game.my_club_id), Game.my_league().name]
	_budget_label.text = Fmt.money(c.budget)

	var f := Game.next_fixture(Game.my_club_id)
	if f.is_empty():
		var left := Game.days_until_season_end()
		_next_match_label.text = "Saisonabschluss am 1. Juli" if left <= 1 \
			else "Sommerpause – noch %d Tage" % left
	else:
		var home := int(f.home) == c.id
		var opponent := Game.club(int(f.away) if home else int(f.home))
		var d := Time.get_datetime_dict_from_unix_time(Game.next_fixture_date(Game.my_club_id))
		_next_match_label.text = "%s %s (%02d.%02d.)" % ["vs" if home else "bei", opponent.name, int(d.day), int(d.month)]

	# Aktions-Button je nach Kalenderlage
	if Game.season_rollover_due():
		_play_button.text = "🏁  Saison abschließen"
	elif Game.season_over():
		_play_button.text = "☀  Sommerpause  ⏩"
	elif Game.my_match_today():
		_play_button.text = "▶  Spieltag anpfeifen"
	else:
		_play_button.text = "Weiter  ⏩"

# ------------------------------------------------------------------ Aktionen

func _on_save() -> void:
	_save_browser.open_browser("save")

## Schnellspeichern (überschreibt den automatischen Slot) – über die Zentrale.
func _quick_save() -> void:
	var save_name := Game.save_game()
	_show_toast("Gespeichert: %s ✓" % save_name if not save_name.is_empty() else "Speichern fehlgeschlagen!")

func _show_toast(text: String) -> void:
	_toast.text = text
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_toast):
			_toast.text = "")

func _on_play_pressed() -> void:
	if Game.season_rollover_due():
		get_tree().change_scene_to_file("res://scenes/saison.tscn")
		return
	if Game.my_match_today():
		get_tree().change_scene_to_file("res://scenes/match.tscn")
		return
	_start_week_sim()

# ------------------------------------------------------------------ Sichtbare Wochensimulation

func _build_sim_overlay() -> void:
	_sim_overlay = Control.new()
	_sim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sim_overlay.visible = false
	add_child(_sim_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sim_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sim_overlay.add_child(center)
	var card := UITheme.card()
	card.custom_minimum_size = Vector2(860, 540)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := Label.new()
	title.text = "Die Tage vergehen …"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(title)

	_sim_date_label = Label.new()
	_sim_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sim_date_label.add_theme_font_size_override("font_size", 34)
	_sim_date_label.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(_sim_date_label)

	_sim_strip = HBoxContainer.new()
	_sim_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_sim_strip.add_theme_constant_override("separation", 10)
	box.add_child(_sim_strip)

	_sim_feed = ItemList.new()
	_sim_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_sim_feed)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_sim_pause_button = Button.new()
	_sim_pause_button.text = "⏸ Pause"
	_sim_pause_button.pressed.connect(_on_sim_pause_toggle)
	buttons.add_child(_sim_pause_button)
	_sim_close_button = Button.new()
	_sim_close_button.text = "Anhalten & zur Zentrale"
	_sim_close_button.pressed.connect(_close_sim)
	buttons.add_child(_sim_close_button)
	_sim_match_button = Button.new()
	_sim_match_button.text = "▶  Spieltag anpfeifen"
	UITheme.make_primary(_sim_match_button)
	_sim_match_button.visible = false
	_sim_match_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/match.tscn"))
	buttons.add_child(_sim_match_button)

	_sim_timer = Timer.new()
	_sim_timer.wait_time = 0.5
	_sim_timer.timeout.connect(_sim_tick)
	add_child(_sim_timer)

func _start_week_sim() -> void:
	_sim_feed.clear()
	_sim_match_button.visible = false
	_sim_pause_button.visible = true
	_sim_pause_button.text = "⏸ Pause"
	_sim_overlay.visible = true
	_update_sim_display()
	_sim_timer.start()

func _sim_tick() -> void:
	if Game.season_rollover_due():
		_finish_sim()
		return
	if Game.is_matchday_today():
		# Englische Woche: Spielt nur die Dritte Liga bzw. Regionalliga, läuft
		# der Spieltag automatisch durch und die Woche geht weiter.
		if Game.my_match_today():
			_finish_sim()
			return
		var note := Game.simulate_matchday_without_me()
		_sim_feed.add_item("%s  –  %s" % [note.day, note.text])
		_sim_feed.ensure_current_is_visible()
		_update_sim_display()
		update_topbar()
		return
	var r: Dictionary = Game.advance_day()
	for e in r.news:
		_sim_feed.add_item("%s  –  %s" % [e.day, e.text])
		_sim_feed.ensure_current_is_visible()
	_update_sim_display()
	update_topbar()
	if not r.decision.is_empty():
		_sim_timer.stop()
		_prep_pending = r.get("prep", false)
		_pending_decision = r.decision
		# Spielergespräche laufen als echtes Gespräch mit Antwortauswahl
		if str(r.decision.get("kind", "")) == "player_talk":
			_show_talk_dialog(r.decision)
			return
		_decision_dialog.title = r.decision.title
		_decision_dialog.dialog_text = r.decision.text + "\n"
		_decision_dialog.ok_button_text = r.decision.options[0]
		_decision_dialog.cancel_button_text = r.decision.options[1]
		_decision_dialog.popup_centered()
		return
	if r.get("prep", false):
		_sim_timer.stop()
		_show_prep_dialog()
		return
	if Game.my_match_today():
		_finish_sim()

## Spielvorbereitungs-Overlay: kompakte Karte mit Gegner-Details und Matchplan-Wahl.
func _build_prep_overlay() -> void:
	_prep_overlay = Control.new()
	_prep_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prep_overlay.visible = false
	add_child(_prep_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prep_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prep_overlay.add_child(center)
	var card := UITheme.card()
	card.custom_minimum_size = Vector2(760, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	_prep_title = Label.new()
	_prep_title.add_theme_font_size_override("font_size", 24)
	_prep_title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(_prep_title)

	# Gegner-Karte
	var opp_panel := PanelContainer.new()
	opp_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 10, UITheme.BORDER, 14))
	box.add_child(opp_panel)
	var opp_box := VBoxContainer.new()
	opp_box.add_theme_constant_override("separation", 8)
	opp_panel.add_child(opp_box)
	_prep_opp_slot = HBoxContainer.new()
	_prep_opp_slot.add_theme_constant_override("separation", 12)
	opp_box.add_child(_prep_opp_slot)
	var opp_text := VBoxContainer.new()
	opp_text.add_theme_constant_override("separation", 0)
	opp_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prep_opp_slot.add_child(opp_text)
	_prep_opp_name = Label.new()
	_prep_opp_name.add_theme_font_size_override("font_size", 22)
	opp_text.add_child(_prep_opp_name)
	_prep_opp_sub = Label.new()
	_prep_opp_sub.add_theme_font_size_override("font_size", 14)
	_prep_opp_sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	opp_text.add_child(_prep_opp_sub)
	_prep_form_row = HBoxContainer.new()
	_prep_form_row.add_theme_constant_override("separation", 4)
	_prep_form_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prep_opp_slot.add_child(_prep_form_row)

	var detail_grid := GridContainer.new()
	detail_grid.columns = 2
	detail_grid.add_theme_constant_override("h_separation", 20)
	detail_grid.add_theme_constant_override("v_separation", 4)
	opp_box.add_child(detail_grid)
	for entry in [["strength", "Teamstärke"], ["scorer", "Gefährlichster Spieler"], ["stadium", "Spielstätte"]]:
		var key := Label.new()
		key.text = entry[1] + ":"
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		detail_grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 15)
		detail_grid.add_child(value)
		_prep_details[entry[0]] = value

	_prep_hint = Label.new()
	_prep_hint.add_theme_color_override("font_color", UITheme.WARN)
	_prep_hint.add_theme_font_size_override("font_size", 15)
	box.add_child(_prep_hint)

	var plan_row := HBoxContainer.new()
	plan_row.add_theme_constant_override("separation", 10)
	box.add_child(plan_row)
	var plan_label := Label.new()
	plan_label.text = "Matchplan:"
	plan_label.add_theme_font_size_override("font_size", 18)
	plan_row.add_child(plan_label)
	_prep_select = OptionButton.new()
	for plan in Game.MATCH_PLANS:
		_prep_select.add_item(plan)
	_prep_select.item_selected.connect(func(index: int):
		_prep_desc.text = Game.MATCH_PLANS[_prep_select.get_item_text(index)].desc)
	plan_row.add_child(_prep_select)
	_prep_desc = Label.new()
	_prep_desc.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_prep_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_row.add_child(_prep_desc)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(confirm_row)
	var confirm := Button.new()
	confirm.text = "✔  Einstudieren & weiter"
	confirm.custom_minimum_size = Vector2(280, 50)
	confirm.add_theme_font_size_override("font_size", 19)
	UITheme.make_primary(confirm)
	confirm.pressed.connect(_on_prep_confirmed)
	confirm_row.add_child(confirm)

func _show_prep_dialog() -> void:
	var f := Game.next_fixture(Game.my_club_id)
	if f.is_empty():
		_sim_timer.start()
		return
	var home := int(f.home) == Game.my_club_id
	var opponent := Game.club(int(f.away) if home else int(f.home))
	var lg := Game.league(opponent.league_id)
	var table_row := {}
	for row in lg.table():
		if int(row.club_id) == opponent.id:
			table_row = row
			break

	_prep_title.text = "Spielvorbereitung – morgen ist Spieltag!"
	if is_instance_valid(_prep_opp_badge):
		_prep_opp_slot.remove_child(_prep_opp_badge)
		_prep_opp_badge.free()
	_prep_opp_badge = UITheme.club_badge(opponent.short_name, Color(opponent.color), 54)
	_prep_opp_slot.add_child(_prep_opp_badge)
	_prep_opp_slot.move_child(_prep_opp_badge, 0)
	_prep_opp_name.text = "%s gegen %s" % ["HEIM" if home else "AUSWÄRTS", opponent.name]
	_prep_opp_sub.text = "Platz %d · %d Punkte · %d:%d Tore" % [
		lg.position_of(opponent.id), int(table_row.get("points", 0)),
		int(table_row.get("gf", 0)), int(table_row.get("ga", 0))]

	# Formkurve des Gegners (letzte 5)
	while _prep_form_row.get_child_count() > 0:
		var child := _prep_form_row.get_child(0)
		_prep_form_row.remove_child(child)
		child.free()
	var recent := lg.fixtures_of_club(opponent.id).filter(func(x): return x.played)
	var last5 := recent.slice(maxi(0, recent.size() - 5))
	if last5.is_empty():
		_prep_form_row.add_child(UITheme.mini_pill("Noch keine Spiele", UITheme.SURFACE2, UITheme.TEXT_DIM, 110))
	for x in last5:
		var opp_home: bool = int(x.home) == opponent.id
		var gf: int = int(x.hg) if opp_home else int(x.ag)
		var ga: int = int(x.ag) if opp_home else int(x.hg)
		if gf > ga:
			_prep_form_row.add_child(UITheme.mini_pill("S", Color("#166534")))
		elif gf == ga:
			_prep_form_row.add_child(UITheme.mini_pill("U", Color("#475569")))
		else:
			_prep_form_row.add_child(UITheme.mini_pill("N", Color("#7f1d1d")))

	var opp_overall := float(opponent.team_strength(Game.world.players))
	var my_overall := float(Game.my_club().team_strength(Game.world.players))
	_prep_details.strength.text = "Mannschaftsstärke: %d  ·  deine: %d" % [int(opp_overall), int(my_overall)]
	var opp_squad := opponent.players(Game.world.players)
	opp_squad.sort_custom(func(a, b): return a.goals_season > b.goals_season)
	if not opp_squad.is_empty():
		var danger: PlayerData = opp_squad[0]
		_prep_details.scorer.text = "%s (%s, %d Tore, Stärke %d)" % [danger.full_name(), danger.pos, danger.goals_season, danger.strength]
	_prep_details.stadium.text = Game.my_club().stadium if home else opponent.stadium

	var diff := (opp_overall - my_overall) / 11.0
	if diff >= 4.0:
		_prep_hint.text = "Empfehlung: „Konter“ oder „Defensivriegel“ – der Gegner ist deutlich stärker."
	elif diff <= -4.0:
		_prep_hint.text = "Empfehlung: „Offensivpressing“ – der Gegner ist deutlich schwächer."
	else:
		_prep_hint.text = "Empfehlung: „Mittelfeldkontrolle“ – ein Duell auf Augenhöhe."
	for i in _prep_select.item_count:
		if _prep_select.get_item_text(i) == Game.match_plan:
			_prep_select.select(i)
			break
	_prep_desc.text = Game.MATCH_PLANS[Game.match_plan].desc
	# Über dem Wochendurchlauf-Overlay anzeigen (sonst bleibt es unsichtbar dahinter)
	_prep_overlay.move_to_front()
	_prep_overlay.visible = true

func _on_prep_confirmed() -> void:
	_prep_overlay.visible = false
	Game.match_plan = _prep_select.get_item_text(_prep_select.selected)
	var entry := Game.note_prep()
	_sim_feed.add_item("%s  –  %s" % [entry.day, entry.text])
	_refresh_active_screen()
	if _sim_overlay.visible:
		_sim_timer.start()

func _on_decision(choice: int) -> void:
	if _pending_decision.is_empty():
		return
	var decision := _pending_decision
	_pending_decision = {}
	# Zugesagtes Testspiel wird jetzt wirklich ausgetragen
	if str(decision.get("kind", "")) == "friendly" and choice == 0:
		var result := Game.play_friendly(int(decision.opponent_id))
		_show_friendly_result(result)
		return
	var msg := Game.resolve_decision(decision, choice)
	if not msg.is_empty():
		_sim_feed.add_item("%s  –  %s" % [msg.day, msg.text])
	update_topbar()
	_continue_after_event()

## Nach einem Ereignis: Vorbereitung zeigen oder die Wochensimulation fortsetzen.
func _continue_after_event() -> void:
	if _prep_pending:
		_prep_pending = false
		_show_prep_dialog()
		return
	if _sim_overlay.visible:
		_sim_timer.start()

# ------------------------------------------------------------------ Spielergespräch

## Echtes Gespräch: Anliegen des Spielers und mehrere Antwortmöglichkeiten.
func _show_talk_dialog(decision: Dictionary) -> void:
	if _talk_overlay == null:
		_build_talk_overlay()
	var p := Game.get_player(int(decision.pid))
	var content := Game.talk_content(decision)
	_talk_decision = decision
	_talk_title.text = "Gespräch mit %s" % p.full_name()
	_talk_sub.text = "%s · %d Jahre · Stärke %d · %d Einsätze%s" % [
		PlayerData.POSITION_NAMES[p.pos], p.age, p.strength, p.matches_season,
		("  ·  " + ", ".join(p.traits)) if not p.traits.is_empty() else ""]
	_talk_says.text = "„%s“" % str(content.opening)
	_talk_result.text = ""
	for child in _talk_replies.get_children():
		child.queue_free()
	var replies: Array = content.replies
	for i in replies.size():
		var reply: Dictionary = replies[i]
		var b := Button.new()
		b.text = "„%s“\n%s" % [str(reply.text), str(reply.hint)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(_on_talk_reply.bind(i))
		_talk_replies.add_child(b)
	_talk_close.visible = false
	_talk_overlay.move_to_front()
	_talk_overlay.visible = true

func _build_talk_overlay() -> void:
	_talk_overlay = Control.new()
	_talk_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_overlay.visible = false
	add_child(_talk_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_talk_overlay.add_child(center)
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(720, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	_talk_title = Label.new()
	_talk_title.add_theme_font_size_override("font_size", 22)
	_talk_title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(_talk_title)
	_talk_sub = Label.new()
	_talk_sub.add_theme_font_size_override("font_size", 13)
	_talk_sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(_talk_sub)
	var says_panel := PanelContainer.new()
	says_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 10, UITheme.BORDER, 14))
	box.add_child(says_panel)
	_talk_says = Label.new()
	_talk_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_says.add_theme_font_size_override("font_size", 17)
	says_panel.add_child(_talk_says)
	var hint := Label.new()
	hint.text = "Deine Antwort (deine Fähigkeit „Motivation“ entscheidet mit, ob sie ankommt):"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(hint)
	_talk_replies = VBoxContainer.new()
	_talk_replies.add_theme_constant_override("separation", 6)
	box.add_child(_talk_replies)
	_talk_result = Label.new()
	_talk_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_result.add_theme_font_size_override("font_size", 15)
	box.add_child(_talk_result)
	_talk_close = Button.new()
	_talk_close.text = "Weiter →"
	_talk_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(_talk_close)
	_talk_close.pressed.connect(func():
		_talk_overlay.visible = false
		_continue_after_event())
	box.add_child(_talk_close)

func _on_talk_reply(index: int) -> void:
	var outcome := Game.resolve_talk(_talk_decision, index)
	for child in _talk_replies.get_children():
		child.queue_free()
	_talk_result.text = str(outcome.text)
	_talk_result.add_theme_color_override("font_color", UITheme.ACCENT if outcome.success else UITheme.DANGER)
	if not outcome.news.is_empty():
		_sim_feed.add_item("%s  –  %s" % [outcome.news.day, outcome.news.text])
	_talk_close.visible = true
	_refresh_active_screen()

# ------------------------------------------------------------------ Testspiel

## Ergebnis eines ausgetragenen Testspiels mit Torschützen.
func _show_friendly_result(result: Dictionary) -> void:
	if _friendly_dialog == null:
		_friendly_dialog = AcceptDialog.new()
		_friendly_dialog.title = "Testspiel"
		_friendly_dialog.ok_button_text = "Weiter"
		_friendly_dialog.confirmed.connect(_continue_after_event)
		_friendly_dialog.canceled.connect(_continue_after_event)
		add_child(_friendly_dialog)
	var opponent: ClubData = result.opponent
	var lines: Array = [
		"%s  %d : %d  %s" % [Game.my_club().name, int(result.hg), int(result.ag), opponent.name],
		"",
	]
	if result.goals.is_empty():
		lines.append("Torlos – aber die Belastung war das Ziel.")
	else:
		for g in result.goals:
			lines.append("%2d'  %s (%s)" % [int(g.min), str(g.name), Game.my_club().short_name if g.home else opponent.short_name])
	lines.append("")
	lines.append("Einnahmen: %s · Tore und Karten zählen nicht für die Saison." % Fmt.money(int(result.fee)))
	_friendly_dialog.dialog_text = "\n".join(lines)
	_sim_feed.add_item("Testspiel: %s %d:%d %s" % [Game.my_club().short_name, int(result.hg), int(result.ag), opponent.short_name])
	update_topbar()
	_refresh_active_screen()
	_friendly_dialog.popup_centered()

func _on_sim_pause_toggle() -> void:
	if _sim_timer.is_stopped():
		_sim_timer.start()
		_sim_pause_button.text = "⏸ Pause"
	else:
		_sim_timer.stop()
		_sim_pause_button.text = "▶ Fortsetzen"

func _finish_sim() -> void:
	_sim_timer.stop()
	_sim_overlay.visible = false
	update_topbar()
	if Game.my_match_today():
		_toast.text = "Spieltag erreicht – Anpfiff, wenn du bereit bist!"
	elif Game.season_rollover_due():
		_toast.text = "Der 1. Juli ist da – jetzt die Saison abschließen!"
	show_screen("Übersicht")

func _close_sim() -> void:
	_sim_timer.stop()
	_sim_overlay.visible = false
	update_topbar()
	_refresh_active_screen()

## Wochenstreifen: Mo–So der aktuellen Woche, heutiger Tag und Spieltag markiert.
func _update_sim_display() -> void:
	_sim_date_label.text = Game.date_label()
	while _sim_strip.get_child_count() > 0:
		var child := _sim_strip.get_child(0)
		_sim_strip.remove_child(child)
		child.free()
	var today := Game.date_unix()
	var weekday_mo: int = (int(Game.date_dict().weekday) + 6) % 7
	var monday := today - weekday_mo * Game.DAY
	var md_date := Game.matchday_date(Game.matchday()) if not Game.season_over() else -1
	for i in 7:
		var day_unix: int = monday + i * Game.DAY
		var d: Dictionary = Time.get_datetime_dict_from_unix_time(day_unix)
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(96, 64)
		var style := UITheme.box(UITheme.FIELD, 8, UITheme.BORDER, 6)
		if day_unix == md_date:
			style.bg_color = Color(Game.my_club().color).darkened(0.5)
		if day_unix == today:
			style.border_color = UITheme.ACCENT
			style.set_border_width_all(2)
		cell.add_theme_stylebox_override("panel", style)
		var cell_label := Label.new()
		cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell_label.text = "%s\n%02d.%02d." % [Game.WEEKDAYS[int(d.weekday)], int(d.day), int(d.month)]
		if day_unix == md_date:
			cell_label.text += "\n⚽"
		elif md_date > 0 and day_unix == md_date - Game.DAY:
			cell_label.text += "\n🎯"
		cell.add_child(cell_label)
		_sim_strip.add_child(cell)

## Echte Karriere: Nach dem Saisonabschluss können bessere Vereine anklopfen.
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
