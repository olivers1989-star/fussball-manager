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
var _menu_dialog: ConfirmationDialog
var _season_dialog: AcceptDialog
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

	_decision_dialog = ConfirmationDialog.new()
	_decision_dialog.min_size = Vector2i(560, 220)
	_decision_dialog.confirmed.connect(func(): _on_decision(0))
	_decision_dialog.canceled.connect(func(): _on_decision(1))
	add_child(_decision_dialog)

	_build_prep_overlay()

	_build_sim_overlay()

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
	_position_label.text = "Spieltag %d/34 · Platz %d · %s" % [
		mini(Game.matchday() + 1, 34), Game.my_league().position_of(Game.my_club_id), Game.my_league().name]
	_budget_label.text = Fmt.money(c.budget)

	var f := Game.next_fixture(Game.my_club_id)
	if f.is_empty():
		_next_match_label.text = "Saison beendet"
	else:
		var home := int(f.home) == c.id
		var opponent := Game.club(int(f.away) if home else int(f.home))
		var d := Time.get_datetime_dict_from_unix_time(Game.matchday_date(Game.matchday()))
		_next_match_label.text = "%s %s (%02d.%02d.)" % ["vs" if home else "bei", opponent.name, int(d.day), int(d.month)]

	# Aktions-Button je nach Kalenderlage
	if Game.season_over():
		_play_button.text = "🏁  Saison abschließen"
	elif Game.is_matchday_today():
		_play_button.text = "▶  Spieltag anpfeifen"
	else:
		_play_button.text = "Weiter  ⏩"

# ------------------------------------------------------------------ Aktionen

func _on_save() -> void:
	var save_name := Game.save_game()
	_toast.text = "Gespeichert: %s ✓" % save_name if not save_name.is_empty() else "Speichern fehlgeschlagen!"
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_toast):
			_toast.text = "")

func _on_play_pressed() -> void:
	if Game.season_over():
		_show_season_end()
		return
	if Game.is_matchday_today():
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
	if Game.is_matchday_today() or Game.season_over():
		_finish_sim()
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
	if Game.is_matchday_today():
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

	var opp_overall := opponent.overall_strength(Game.world.players)
	var my_overall := Game.my_club().overall_strength(Game.world.players)
	_prep_details.strength.text = "Kader gesamt: %.1f  ·  dein Kader: %.1f" % [opp_overall, my_overall]
	var opp_squad := opponent.players(Game.world.players)
	opp_squad.sort_custom(func(a, b): return a.goals_season > b.goals_season)
	if not opp_squad.is_empty():
		var danger: PlayerData = opp_squad[0]
		_prep_details.scorer.text = "%s (%s, %d Tore, Stärke %d)" % [danger.full_name(), danger.pos, danger.goals_season, danger.strength]
	_prep_details.stadium.text = Game.my_club().stadium if home else opponent.stadium

	var diff := opp_overall - my_overall
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
	var result := Game.resolve_decision(_pending_decision, choice)
	_pending_decision = {}
	if not result.is_empty():
		_sim_feed.add_item("%s  –  %s" % [result.day, result.text])
	update_topbar()
	if _prep_pending:
		_prep_pending = false
		_show_prep_dialog()
		return
	if _sim_overlay.visible:
		_sim_timer.start()

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
	if Game.is_matchday_today():
		_toast.text = "Spieltag erreicht – Anpfiff, wenn du bereit bist!"
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
	var goal_line := "Saisonziel „%s“: %s" % [s.goal_text, "ERREICHT ✓" if s.goal_achieved else "verfehlt ✗"]
	if int(s.get("bonus_paid", 0)) > 0:
		goal_line += "  –  Erfolgsprämie: %s" % Fmt.money(int(s.bonus_paid))
	var lines := [
		"%s ist beendet!" % s.season,
		"",
		"Meister Erste Liga: %s" % s.champion1,
		"Meister Zweite Liga: %s" % s.champion2,
		"Dein Ergebnis: Platz %d (%s)" % [s.my_position, s.my_league_name],
		goal_line,
		"",
		"Absteiger: %s" % ", ".join(s.relegated),
		"Aufsteiger: %s" % ", ".join(s.promoted),
	]
	if not s.retired.is_empty():
		lines.append("")
		lines.append("Karriereende bei deinem Verein: %s" % ", ".join(s.retired))
	_season_dialog.dialog_text = "\n".join(lines)
	_season_dialog.popup_centered()
