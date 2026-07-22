class_name SaveBrowser
extends Control
## Spielstands-Verwaltung als Overlay – wird im Hauptmenü (Laden) und in der
## Zentrale (Speichern) verwendet. Zeigt jeden Spielstand als Karte mit
## Vereinswappen, Tabellenstand, Saison/Spieltag, Budget und Zeitstempel.
## Aktionen: Laden, Überschreiben, Löschen (mit Rückfrage), neuer Spielstand.

signal loaded              ## Ein Spielstand wurde geladen
signal saved(name: String) ## Ein Spielstand wurde geschrieben

var mode := "load"         # "load" oder "save"
var _list_box: VBoxContainer
var _title: Label
var _name_edit: LineEdit
var _new_row: HBoxContainer
var _status: Label
var _confirm_delete := ""  # Pfad, für den gerade die Löschrückfrage läuft

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(860, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "✕ Schließen"
	close.pressed.connect(close_browser)
	head.add_child(close)

	# Neuer Spielstand (nur im Speicher-Modus)
	_new_row = HBoxContainer.new()
	_new_row.add_theme_constant_override("separation", 8)
	box.add_child(_new_row)
	var new_label := Label.new()
	new_label.text = "Neuer Spielstand:"
	new_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_new_row.add_child(new_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name (leer = automatisch)"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(320, 0)
	_new_row.add_child(_name_edit)
	var new_button := Button.new()
	new_button.text = "💾 Speichern"
	UITheme.make_primary(new_button)
	new_button.pressed.connect(_on_save_new)
	_new_row.add_child(new_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(_status)

## Öffnet die Verwaltung. p_mode: "load" (Hauptmenü) oder "save" (Zentrale).
func open_browser(p_mode: String) -> void:
	mode = p_mode
	_title.text = "Spielstand laden" if mode == "load" else "Spiel speichern"
	_new_row.visible = mode == "save"
	_confirm_delete = ""
	_status.text = ""
	_refresh()
	visible = true
	move_to_front()

func close_browser() -> void:
	visible = false

func _refresh() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	var saves := Game.list_saves()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Spielstände vorhanden." if mode == "load" else "Noch keine Spielstände – lege oben einen neuen an."
		empty.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list_box.add_child(empty)
		return
	for s in saves:
		_list_box.add_child(_save_card(s))

func _save_card(entry: Dictionary) -> PanelContainer:
	var m: Dictionary = entry.meta
	var path: String = entry.path
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.FIELD, 10, UITheme.BORDER)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# Wappen – ältere Spielstände ohne Wappen-Felder aus der Vereins-ID ableiten
	var short_name: String = str(m.get("club_short", ""))
	var color_hex: String = str(m.get("club_color", ""))
	if short_name == "" or color_hex == "":
		var cid := int(m.get("my_club_id", 0))
		if cid >= 1 and cid <= Data.club_defs.size():
			var def: Dictionary = Data.club_defs[cid - 1]
			short_name = str(def.short)
			color_hex = str(def.color)
	row.add_child(UITheme.club_badge(short_name if short_name != "" else "???",
		Color(color_hex) if color_hex != "" else UITheme.ACCENT, 52))

	# Beschreibung
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var line1 := Label.new()
	line1.text = str(m.get("club", "?"))
	line1.add_theme_font_size_override("font_size", 18)
	info.add_child(line1)
	var line2 := Label.new()
	var pos: int = int(m.get("position", 0))
	var pos_txt := ("Platz %d · %d Punkte · " % [pos, int(m.get("points", 0))]) if pos > 0 else ""
	line2.text = "%sSaison %d/%d · Spieltag %d" % [pos_txt, int(m.get("season_year", 0)), int(m.get("season_year", 0)) + 1, int(m.get("matchday", 0)) + 1]
	line2.add_theme_font_size_override("font_size", 13)
	line2.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	info.add_child(line2)
	var line3 := Label.new()
	var mode_txt: String = "Echte Karriere" if str(m.get("game_mode", "")) == "angebote" else "Vereinsauswahl"
	line3.text = "%s · %s · %s · gespeichert %s" % [
		str(m.get("manager", "?")), mode_txt, str(m.get("difficulty", "Normal")), str(m.get("saved_at", ""))]
	line3.add_theme_font_size_override("font_size", 12)
	line3.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	info.add_child(line3)

	# Aktionen
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	if mode == "load":
		var load_button := Button.new()
		load_button.text = "▶ Laden"
		UITheme.make_primary(load_button)
		load_button.pressed.connect(_on_load.bind(path))
		actions.add_child(load_button)
	else:
		var over := Button.new()
		over.text = "💾 Überschreiben"
		UITheme.make_primary(over)
		over.pressed.connect(_on_overwrite.bind(path))
		actions.add_child(over)
	var del := Button.new()
	del.text = "🗑 Wirklich löschen?" if _confirm_delete == path else "🗑"
	del.tooltip_text = "Spielstand löschen"
	if _confirm_delete == path:
		del.add_theme_color_override("font_color", UITheme.DANGER)
	del.pressed.connect(_on_delete.bind(path))
	actions.add_child(del)
	return card

# ------------------------------------------------------------------ Aktionen

func _on_load(path: String) -> void:
	if Game.load_game(path):
		close_browser()
		loaded.emit()
	else:
		_status.text = "Spielstand konnte nicht geladen werden."

func _on_overwrite(path: String) -> void:
	var name := path.get_file().get_basename()
	var written := Game.save_game(name)
	if written.is_empty():
		_status.text = "Speichern fehlgeschlagen."
		return
	_status.text = "Spielstand „%s“ überschrieben ✓" % written
	_refresh()
	saved.emit(written)

func _on_save_new() -> void:
	var written := Game.save_game(_name_edit.text)
	if written.is_empty():
		_status.text = "Speichern fehlgeschlagen."
		return
	_name_edit.text = ""
	_status.text = "Spielstand „%s“ gespeichert ✓" % written
	_refresh()
	saved.emit(written)

## Erster Klick fragt nach, zweiter löscht wirklich.
func _on_delete(path: String) -> void:
	if _confirm_delete != path:
		_confirm_delete = path
		_status.text = "Zum Löschen erneut auf den Papierkorb klicken."
		_refresh()
		return
	_confirm_delete = ""
	if Game.delete_save(path):
		_status.text = "Spielstand gelöscht."
	else:
		_status.text = "Spielstand konnte nicht gelöscht werden."
	_refresh()
