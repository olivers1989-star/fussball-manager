class_name WizardUI
extends RefCounted
## Gemeinsame Bausteine des Spielstart-Assistenten: Schritt-Anzeige mit
## Fortschritts-Chips, Titelkopf und Sektionskarten im Manager-Design.

const STEP_NAMES := ["Trainerprofil", "Spielmodus", "Verein & Vertrag"]

## Kopfbereich: Fortschritts-Chips (1─2─3), großer Titel, Untertitel.
static func step_header(step: int, title: String, subtitle: String, title_size := 38) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	box.add_child(chips)
	for i in STEP_NAMES.size():
		if i > 0:
			var line := Label.new()
			line.text = "─"
			line.add_theme_color_override("font_color", UITheme.BORDER)
			chips.add_child(line)
		var done := i + 1 < step
		var active := i + 1 == step
		var chip := Label.new()
		chip.text = "  %s %d · %s  " % ["✔" if done else "●" if active else "○", i + 1, STEP_NAMES[i]]
		chip.add_theme_font_size_override("font_size", 13)
		var bg := UITheme.SURFACE2 if active else UITheme.SURFACE
		var fg := UITheme.ACCENT if active else (Color("#86b89b") if done else UITheme.TEXT_DIM)
		var sb := UITheme.box(bg, 999, UITheme.ACCENT if active else UITheme.BORDER)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("normal", sb)
		chip.add_theme_color_override("font_color", fg)
		chips.add_child(chip)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", UITheme.ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(sub)
	return box

## Karte mit Überschrift; der Inhalt kommt in card.get_meta("content").
static func section_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	card.add_child(inner)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 19)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(head)
	card.set_meta("content", inner)
	return card

static func form_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l
