extends Control
## Vertragsverhandlung mit dem Vorstand – zweigeteilt:
## Links: der Vorstand (Gesprächspartner, Gesprächsverlauf, aktuelles Angebot, Geduld).
## Rechts: dein Forderungspaket (Gehalt, Laufzeit, Erfolgsprämie) zum Vortragen.
## Der Vorstand akzeptiert, macht Gegenangebote oder bricht bei Überzogenheit ab.

const OPENING_LINES := [
	"Schön, dass Sie den Weg zu uns gefunden haben. Wir trauen Ihnen einiges zu – hier ist unser Angebot.",
	"Wir haben Ihre Arbeit verfolgt und sehen Potenzial. Das hier können wir Ihnen bieten.",
	"Willkommen! Reden wir nicht lange um den heißen Brei – das ist unser Angebot.",
]
const ACCEPT_LINES := [
	"Sie verhandeln hart, aber fair. Einverstanden – so machen wir es.",
	"In Ordnung, das können wir gerade noch darstellen.",
	"Gut. Der Vorstand zieht mit – das Paket steht.",
]
const COUNTER_LINES := [
	"So weit können wir nicht gehen. Aber wir kommen Ihnen entgegen: %s.",
	"Das übersteigt unseren Rahmen. Unser letztes Wort in dieser Runde: %s.",
	"Wir treffen uns in der Mitte – %s. Mehr ist gerade nicht drin.",
]
const DECLINE_LINES := [
	"Das ist deutlich zu viel. Wir bleiben bei unserem Angebot.",
	"Bei allem Respekt – dafür fehlt uns das Budget. Unser Angebot steht.",
	"Nein. Überlegen Sie noch einmal, was hier realistisch ist.",
]
const PLEASED_LINES := [
	"Sehr vernünftig. Damit können wir arbeiten.",
	"Das nenne ich Augenmaß – einverstanden.",
]
const WARNING_LINES := [
	"Ich sage es offen: Unsere Geduld hat Grenzen.",
	"Wir drehen uns im Kreis. Kommen Sie langsam zum Punkt.",
]
const BREAKOFF_LINES := [
	"So kommen wir nicht zusammen. Der Vorstand beendet das Gespräch – alles Gute für Ihre Zukunft.",
	"Das war es dann. Wir werden uns anderweitig umsehen.",
]

var _club_id := 1
var _def: Dictionary
var _tier := 1
var _chairman := ""

# Aktuelles Angebot des Vorstands
var _offer_salary := 20000
var _offer_bonus := 0
var _years := 2

# Verhandlungszustand
var _patience := 100.0
var _broken_off := false
var _agreed := false
var _agreed_terms := {}

var _dialog_label: Label
var _offer_salary_label: Label
var _offer_bonus_label: Label
var _patience_bar: ProgressBar
var _patience_label: Label
var _salary_slider: HSlider
var _salary_value: Label
var _bonus_slider: HSlider
var _bonus_value: Label
var _year_buttons: Array = []
var _present_button: Button
var _sign_button: Button
var _agreement_label: Label
var _agreement_dialog: ConfirmationDialog
var _signature_overlay: Control
var _pad: SignaturePad
var _signature_confirm: Button

func _ready() -> void:
	_club_id = int(Game.setup.get("club_id", 1))
	_def = Data.club_defs[_club_id - 1]
	_tier = int(_def.league)
	_offer_salary = Game.board_salary(int(_def.strength))
	_offer_bonus = int(_offer_salary * 2 / 5000.0) * 5000
	_chairman = _def.get("chairman", "der Vorstand")
	_build_ui()
	_say(OPENING_LINES.pick_random())
	_refresh()

func _goal() -> Dictionary:
	var stronger := 0
	for d in Data.club_defs:
		if int(d.league) == _tier and int(d.strength) > int(_def.strength):
			stronger += 1
	return Game.goal_from_rank(stronger + 1, _tier)

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	center.add_child(columns)

	# ============================================================ Linke Hälfte: Der Vorstand
	var left_card := UITheme.card()
	left_card.custom_minimum_size = Vector2(560, 620)
	columns.add_child(left_card)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left_card.add_child(left)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	left.add_child(header)
	header.add_child(UITheme.club_badge(_def.short, Color(_def.color), 58))
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(head_text)
	var club_name := Label.new()
	club_name.text = _def.name
	club_name.add_theme_font_size_override("font_size", 24)
	head_text.add_child(club_name)
	var club_sub := Label.new()
	club_sub.text = "%s  ·  %s (%s Plätze)  ·  Teamstärke ~%d" % [
		"Erste Liga" if _tier == 1 else "Zweite Liga", _def.stadium,
		Fmt.thousands(int(_def.capacity)), int(_def.strength)]
	club_sub.add_theme_font_size_override("font_size", 13)
	club_sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	head_text.add_child(club_sub)

	var chairman_label := Label.new()
	chairman_label.text = "Am Tisch: Vorstandsvorsitzender %s" % _chairman
	chairman_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	left.add_child(chairman_label)

	# Gesprächsverlauf
	var dialog_panel := PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 10, UITheme.BORDER, 14))
	dialog_panel.custom_minimum_size = Vector2(0, 110)
	left.add_child(dialog_panel)
	_dialog_label = Label.new()
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.add_theme_font_size_override("font_size", 18)
	dialog_panel.add_child(_dialog_label)

	left.add_child(HSeparator.new())
	var offer_heading := Label.new()
	offer_heading.text = "Aktuelles Angebot des Vorstands"
	offer_heading.add_theme_font_size_override("font_size", 21)
	offer_heading.add_theme_color_override("font_color", UITheme.ACCENT)
	left.add_child(offer_heading)

	var offer_grid := GridContainer.new()
	offer_grid.columns = 2
	offer_grid.add_theme_constant_override("h_separation", 24)
	offer_grid.add_theme_constant_override("v_separation", 10)
	left.add_child(offer_grid)
	offer_grid.add_child(_dim("Trainergehalt:"))
	_offer_salary_label = _big_value("")
	offer_grid.add_child(_offer_salary_label)
	offer_grid.add_child(_dim("Erfolgsprämie:"))
	_offer_bonus_label = _big_value("")
	offer_grid.add_child(_offer_bonus_label)
	offer_grid.add_child(_dim("Saisonziel:"))
	offer_grid.add_child(_big_value(_goal().text))
	offer_grid.add_child(_dim("Vereinsbudget:"))
	offer_grid.add_child(_big_value(Fmt.money(_budget())))

	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_spacer)

	# Geduld des Vorstands
	var patience_row := HBoxContainer.new()
	patience_row.add_theme_constant_override("separation", 10)
	left.add_child(patience_row)
	patience_row.add_child(_dim("Gesprächsklima:"))
	_patience_bar = ProgressBar.new()
	_patience_bar.min_value = 0
	_patience_bar.max_value = 100
	_patience_bar.show_percentage = false
	_patience_bar.custom_minimum_size = Vector2(200, 16)
	_patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_patience_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	patience_row.add_child(_patience_bar)
	_patience_label = Label.new()
	patience_row.add_child(_patience_label)

	# ============================================================ Rechte Hälfte: Deine Forderungen
	var right_card := UITheme.card()
	right_card.custom_minimum_size = Vector2(560, 620)
	columns.add_child(right_card)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right_card.add_child(right)

	var your_heading := Label.new()
	your_heading.text = "Dein Forderungspaket"
	your_heading.add_theme_font_size_override("font_size", 24)
	your_heading.add_theme_color_override("font_color", UITheme.ACCENT)
	right.add_child(your_heading)
	var your_sub := Label.new()
	your_sub.text = "Stelle dein Paket zusammen und trage es vor. Aber Vorsicht:\nJede Runde kostet Geduld – überzogene Forderungen lassen das Gespräch platzen."
	your_sub.add_theme_font_size_override("font_size", 14)
	your_sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	right.add_child(your_sub)

	right.add_child(_vspace(4))
	right.add_child(_dim("Gehaltsforderung pro Monat:"))
	var salary_row := HBoxContainer.new()
	salary_row.add_theme_constant_override("separation", 12)
	right.add_child(salary_row)
	_salary_slider = HSlider.new()
	_salary_slider.min_value = _offer_salary
	_salary_slider.max_value = _offer_salary * 2.2
	_salary_slider.step = 1000
	_salary_slider.value = _offer_salary
	_salary_slider.custom_minimum_size = Vector2(320, 0)
	_salary_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_salary_slider.value_changed.connect(func(_v): _refresh_demands())
	salary_row.add_child(_salary_slider)
	_salary_value = _big_value("")
	_salary_value.custom_minimum_size = Vector2(130, 0)
	salary_row.add_child(_salary_value)

	right.add_child(_dim("Erfolgsprämie bei Zielerreichung:"))
	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 12)
	right.add_child(bonus_row)
	_bonus_slider = HSlider.new()
	_bonus_slider.min_value = 0
	_bonus_slider.max_value = _offer_salary * 8
	_bonus_slider.step = 5000
	_bonus_slider.value = _offer_bonus
	_bonus_slider.custom_minimum_size = Vector2(320, 0)
	_bonus_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bonus_slider.value_changed.connect(func(_v): _refresh_demands())
	bonus_row.add_child(_bonus_slider)
	_bonus_value = _big_value("")
	_bonus_value.custom_minimum_size = Vector2(130, 0)
	bonus_row.add_child(_bonus_value)

	right.add_child(_dim("Vertragslaufzeit:"))
	var years_row := HBoxContainer.new()
	years_row.add_theme_constant_override("separation", 10)
	right.add_child(years_row)
	var group := ButtonGroup.new()
	for years in [1, 2, 3, 4, 5]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%d Jahr%s" % [years, "" if years == 1 else "e"]
		b.custom_minimum_size = Vector2(88, 42)
		b.set_pressed_no_signal(years == 2)
		b.pressed.connect(func(): _years = years)
		years_row.add_child(b)
		_year_buttons.append(b)

	right.add_child(_vspace(4))
	_present_button = Button.new()
	_present_button.text = "🗣  Forderungen vortragen"
	_present_button.add_theme_font_size_override("font_size", 19)
	_present_button.pressed.connect(_on_present)
	right.add_child(_present_button)

	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_spacer)

	right.add_child(HSeparator.new())
	_agreement_label = Label.new()
	_agreement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_agreement_label.add_theme_font_size_override("font_size", 15)
	right.add_child(_agreement_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	var leave := Button.new()
	leave.text = "Gespräch verlassen"
	leave.custom_minimum_size = Vector2(180, 48)
	leave.pressed.connect(func():
		get_tree().change_scene_to_file(Game.setup.get("origin_scene", "res://scenes/vereinswahl.tscn")))
	buttons.add_child(leave)
	_sign_button = Button.new()
	_sign_button.text = "🤝  Angebot annehmen"
	_sign_button.custom_minimum_size = Vector2(260, 48)
	_sign_button.add_theme_font_size_override("font_size", 19)
	UITheme.make_primary(_sign_button)
	_sign_button.pressed.connect(func(): _reach_agreement())
	buttons.add_child(_sign_button)

	# Einigungs-Popup: friert die Konditionen ein
	_agreement_dialog = ConfirmationDialog.new()
	_agreement_dialog.title = "Einigung erzielt"
	_agreement_dialog.ok_button_text = "Vertrag unterzeichnen"
	_agreement_dialog.cancel_button_text = "Verhandlungen abbrechen"
	_agreement_dialog.confirmed.connect(_show_signature)
	_agreement_dialog.canceled.connect(func():
		get_tree().change_scene_to_file(Game.setup.get("origin_scene", "res://scenes/vereinswahl.tscn")))
	add_child(_agreement_dialog)

# ------------------------------------------------------------------ Verhandlungslogik

func _on_present() -> void:
	if _broken_off or _agreed:
		return
	var demand_salary := int(_salary_slider.value)
	var demand_bonus := int(_bonus_slider.value)
	var salary_excess := float(demand_salary - _offer_salary) / _offer_salary
	var bonus_excess := maxf(0.0, float(demand_bonus - _offer_bonus) / (_offer_salary * 6.0))
	var aggressiveness := salary_excess + bonus_excess * 0.6

	if aggressiveness <= 0.001:
		# Forderung liegt auf oder unter dem Angebot – der Vorstand schlägt sofort ein
		_offer_salary = demand_salary
		_offer_bonus = demand_bonus
		_say(PLEASED_LINES.pick_random())
		_refresh()
		_reach_agreement()
		return

	_patience -= 10.0 + aggressiveness * 45.0 + randf_range(0.0, 6.0)
	if _patience <= 0.0:
		_break_off()
		return

	var chance := 0.75 - aggressiveness * 1.6
	if Game.setup.get("mode", "") == "vereinsauswahl":
		chance += 0.10
	if randf() < clampf(chance, 0.05, 0.95):
		# Der Vorstand akzeptiert dein Paket – damit ist die Einigung da
		_offer_salary = demand_salary
		_offer_bonus = demand_bonus
		_say(ACCEPT_LINES.pick_random())
		_refresh()
		_reach_agreement()
		return
	elif randf() < 0.6:
		# Gegenangebot: der Vorstand kommt dir einen Teil des Weges entgegen
		_offer_salary = int((_offer_salary + (demand_salary - _offer_salary) * randf_range(0.3, 0.6)) / 1000.0) * 1000
		_offer_bonus = int((_offer_bonus + maxi(0, demand_bonus - _offer_bonus) * randf_range(0.3, 0.6)) / 5000.0) * 5000
		_say(COUNTER_LINES.pick_random() % ("%s plus %s Prämie" % [Fmt.money(_offer_salary), Fmt.money(_offer_bonus)]))
	else:
		_say(DECLINE_LINES.pick_random())
	if _patience <= 35.0 and not _broken_off:
		_dialog_label.text += "\n" + WARNING_LINES.pick_random()
	_refresh()

## Einigung: Konditionen einfrieren und das Bestätigungs-Popup zeigen.
func _reach_agreement() -> void:
	if _broken_off or _agreed:
		return
	_agreed = true
	_agreed_terms = {"salary": _offer_salary, "bonus": _offer_bonus, "years": _years}
	_freeze_inputs()
	_agreement_dialog.dialog_text = "\n".join([
		"Handschlag mit %s – die Konditionen stehen:" % _chairman,
		"",
		"Trainergehalt: %s pro Monat" % Fmt.money(_offer_salary),
		"Vertragslaufzeit: %d Jahr%s" % [_years, "" if _years == 1 else "e"],
		"Erfolgsprämie: %s bei „%s“" % [Fmt.money(_offer_bonus), _goal().text],
		"",
		"Nach der Einigung sind keine Änderungen mehr möglich.",
	])
	_agreement_dialog.popup_centered()

func _freeze_inputs() -> void:
	_present_button.disabled = true
	_sign_button.disabled = true
	_salary_slider.editable = false
	_bonus_slider.editable = false
	for b in _year_buttons:
		b.disabled = true

func _break_off() -> void:
	_broken_off = true
	_say(BREAKOFF_LINES.pick_random())
	_freeze_inputs()
	# Im Karrieremodus ist dieses Angebot damit vom Tisch
	if Game.setup.get("mode", "") == "angebote" and Game.setup.has("initial_offers"):
		Game.setup.initial_offers.erase(_club_id)
	_refresh()

# ------------------------------------------------------------------ Vertragsunterzeichnung

## Vertragsdokument mit Unterschriftsfeld (Maus) als Overlay.
func _show_signature() -> void:
	if _signature_overlay == null:
		_build_signature_overlay()
	_pad.clear()
	_signature_confirm.disabled = true
	_signature_overlay.visible = true

func _build_signature_overlay() -> void:
	_signature_overlay = Control.new()
	_signature_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_signature_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_signature_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_signature_overlay.add_child(center)

	# Vertragsdokument in Papier-Optik
	var paper := PanelContainer.new()
	var paper_style := UITheme.box(Color("#f4efe2"), 6, Color("#c9c1ab"))
	paper_style.content_margin_left = 40
	paper_style.content_margin_right = 40
	paper_style.content_margin_top = 30
	paper_style.content_margin_bottom = 30
	paper.add_theme_stylebox_override("panel", paper_style)
	paper.custom_minimum_size = Vector2(640, 0)
	center.add_child(paper)

	var doc := VBoxContainer.new()
	doc.add_theme_constant_override("separation", 10)
	paper.add_child(doc)

	var doc_title := Label.new()
	doc_title.text = "ARBEITSVERTRAG"
	doc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doc_title.add_theme_font_size_override("font_size", 30)
	doc_title.add_theme_color_override("font_color", Color("#1f2937"))
	doc.add_child(doc_title)

	var doc_text := Label.new()
	doc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doc_text.add_theme_font_size_override("font_size", 16)
	doc_text.add_theme_color_override("font_color", Color("#374151"))
	doc_text.text = "\n".join([
		"Zwischen dem Verein %s, vertreten durch den Vorstandsvorsitzenden %s," % [_def.name, _chairman],
		"und Trainer %s wird folgender Vertrag geschlossen:" % Game.setup.get("name", "Der Trainer"),
		"",
		"§1  Laufzeit: %d Jahr%s ab Vertragsunterzeichnung" % [int(_agreed_terms.get("years", _years)), "" if int(_agreed_terms.get("years", _years)) == 1 else "e"],
		"§2  Vergütung: %s pro Monat" % Fmt.money(int(_agreed_terms.get("salary", _offer_salary))),
		"§3  Erfolgsprämie: %s bei Erreichen des Saisonziels „%s“" % [Fmt.money(int(_agreed_terms.get("bonus", _offer_bonus))), _goal().text],
	])
	doc.add_child(doc_text)

	var sig_caption := Label.new()
	sig_caption.text = "Unterschrift (mit der Maus unterschreiben):"
	sig_caption.add_theme_font_size_override("font_size", 14)
	sig_caption.add_theme_color_override("font_color", Color("#6b7280"))
	doc.add_child(sig_caption)

	var pad_panel := PanelContainer.new()
	pad_panel.add_theme_stylebox_override("panel", UITheme.box(Color.WHITE, 4, Color("#9ca3af")))
	doc.add_child(pad_panel)
	_pad = SignaturePad.new()
	_pad.custom_minimum_size = Vector2(0, 150)
	_pad.changed.connect(func(): _signature_confirm.disabled = _pad.point_count() < 12)
	pad_panel.add_child(_pad)

	var sig_line := Label.new()
	sig_line.text = "%s, %s" % [_def.city, Game.setup.get("name", "Der Trainer")]
	sig_line.add_theme_font_size_override("font_size", 13)
	sig_line.add_theme_color_override("font_color", Color("#6b7280"))
	doc.add_child(sig_line)

	var doc_buttons := HBoxContainer.new()
	doc_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	doc_buttons.add_theme_constant_override("separation", 12)
	doc.add_child(doc_buttons)
	var clear_button := Button.new()
	clear_button.text = "Unterschrift löschen"
	clear_button.pressed.connect(func():
		_pad.clear()
		_signature_confirm.disabled = true)
	doc_buttons.add_child(clear_button)
	var cancel_button := Button.new()
	cancel_button.text = "Zurück"
	cancel_button.pressed.connect(func():
		_signature_overlay.visible = false
		_agreement_dialog.popup_centered())
	doc_buttons.add_child(cancel_button)
	_signature_confirm = Button.new()
	_signature_confirm.text = "✍  Unterzeichnen"
	_signature_confirm.disabled = true
	UITheme.make_primary(_signature_confirm)
	_signature_confirm.pressed.connect(_do_sign)
	doc_buttons.add_child(_signature_confirm)

func _do_sign() -> void:
	Game.setup["coach_salary"] = int(_agreed_terms.get("salary", _offer_salary))
	Game.setup["coach_years"] = int(_agreed_terms.get("years", _years))
	Game.setup["goal_bonus"] = int(_agreed_terms.get("bonus", _offer_bonus))
	Game.setup["season_goal"] = _goal()
	Game.new_game(_club_id)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

## Unterschriftenfeld: zeichnet Mausstriche als Tinte.
class SignaturePad:
	extends Control

	signal changed

	var _strokes: Array = []   # Array von Arrays mit Vector2-Punkten
	var _drawing := false

	func _init() -> void:
		clip_contents = true
		mouse_default_cursor_shape = Control.CURSOR_CROSS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drawing = true
				_strokes.append([event.position])
			else:
				_drawing = false
			accept_event()
		elif event is InputEventMouseMotion and _drawing:
			_strokes.back().append(event.position)
			queue_redraw()
			changed.emit()
			accept_event()

	func _draw() -> void:
		for stroke in _strokes:
			if stroke.size() >= 2:
				draw_polyline(PackedVector2Array(stroke), Color("#1e3a8a"), 3.0, true)

	func clear() -> void:
		_strokes.clear()
		queue_redraw()

	func point_count() -> int:
		var total := 0
		for stroke in _strokes:
			total += stroke.size()
		return total

# ------------------------------------------------------------------ Anzeige

func _say(text: String) -> void:
	_dialog_label.text = "„%s“" % text

func _refresh() -> void:
	_offer_salary_label.text = "%s / Monat" % Fmt.money(_offer_salary)
	_offer_bonus_label.text = Fmt.money(_offer_bonus)
	_patience_bar.value = _patience
	if _broken_off:
		_patience_label.text = "Gespräch beendet"
		_patience_label.add_theme_color_override("font_color", UITheme.DANGER)
	elif _patience > 66.0:
		_patience_label.text = "konstruktiv"
		_patience_label.add_theme_color_override("font_color", UITheme.ACCENT)
	elif _patience > 33.0:
		_patience_label.text = "angespannt"
		_patience_label.add_theme_color_override("font_color", UITheme.WARN)
	else:
		_patience_label.text = "kurz vor dem Abbruch"
		_patience_label.add_theme_color_override("font_color", UITheme.DANGER)
	_refresh_demands()

func _refresh_demands() -> void:
	_salary_value.text = Fmt.money(int(_salary_slider.value))
	_bonus_value.text = Fmt.money(int(_bonus_slider.value))
	if _broken_off:
		_agreement_label.text = "Der Vorstand hat die Verhandlung abgebrochen."
	else:
		_agreement_label.text = "Bei Unterschrift jetzt: %s/Monat  ·  %d Jahre  ·  %s Prämie bei „%s“" % [
			Fmt.money(_offer_salary), _years, Fmt.money(_offer_bonus), _goal().text]

func _budget() -> int:
	var factor: float = Game.DIFFICULTY_FACTORS.get(Game.setup.get("difficulty", "Normal"), 1.0)
	var base: int = (int(_def.strength) - 50) * 1200000 if _tier == 1 else (int(_def.strength) - 44) * 400000
	return int(base * factor)

func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l

func _big_value(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	return l

func _vspace(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
