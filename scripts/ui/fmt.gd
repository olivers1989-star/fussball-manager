class_name Fmt
extends RefCounted
## Formatierungs-Helfer für Geldbeträge und Anzeige-Strings.

static func money(n: int) -> String:
	var neg := n < 0
	var a: int = absi(n)
	var s: String
	if a >= 1000000:
		s = ("%.2f" % (a / 1000000.0)).replace(".", ",") + " Mio. €"
	else:
		s = thousands(a) + " €"
	return ("-" + s) if neg else s

static func thousands(a: int) -> String:
	var s := str(a)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "." + result
	return result

static func form_str(f: float) -> String:
	return ("%.2f" % f).replace(".", ",")

## Form als Symbol statt Zahl: ↑↑ Topform … ↓↓ Formloch.
static func form_icon(f: float) -> String:
	if f >= 1.10:
		return "↑↑"
	if f >= 1.03:
		return "↑"
	if f >= 0.97:
		return "→"
	if f >= 0.90:
		return "↓"
	return "↓↓"

static func form_color(f: float) -> Color:
	if f >= 1.03:
		return Color("#4ade80")
	if f >= 0.97:
		return Color("#94a3b8")
	return Color("#f87171")

## Durchschnittsnote formatiert ("–" ohne Einsätze).
static func note_str(p: PlayerData) -> String:
	if p.matches_season <= 0:
		return "–"
	return ("%.1f" % p.avg_rating()).replace(".", ",")
