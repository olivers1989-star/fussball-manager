class_name PlayerData
extends RefCounted
## Ein einzelner Spieler mit Attributen, Vertrag und Saisonstatistik.

const POSITIONS := ["TW", "AB", "MF", "ST"]

## Spielerattribute (1–96). Die Gesamtstärke wird daraus positionsabhängig berechnet,
## und die Match-Engine rechnet direkt mit den Attributen.
const ATTRIBUTES := {
	"tempo": "Tempo",
	"technik": "Technik",
	"passen": "Passspiel",
	"abschluss": "Abschluss",
	"zweikampf": "Zweikampf",
	"kopfball": "Kopfball",
	"stellung": "Stellungsspiel",
	"reflexe": "Reflexe",
}

## Gewichtung der Attribute für die Gesamtstärke je Position.
const STRENGTH_WEIGHTS := {
	"TW": {"reflexe": 0.6, "stellung": 0.25, "tempo": 0.1, "passen": 0.05},
	"AB": {"zweikampf": 0.3, "stellung": 0.25, "kopfball": 0.2, "tempo": 0.15, "passen": 0.05, "technik": 0.05},
	"MF": {"passen": 0.3, "technik": 0.25, "stellung": 0.15, "zweikampf": 0.15, "tempo": 0.1, "abschluss": 0.05},
	"ST": {"abschluss": 0.35, "tempo": 0.2, "technik": 0.15, "kopfball": 0.15, "stellung": 0.05, "passen": 0.05, "zweikampf": 0.05},
}

## Typisches Attributprofil je Position (Abweichung vom Zielwert).
const ATTR_OFFSETS := {
	"TW": {"reflexe": 6, "stellung": 2, "tempo": -12, "technik": -8, "passen": -6, "abschluss": -20, "zweikampf": -10, "kopfball": -8},
	"AB": {"zweikampf": 5, "stellung": 4, "kopfball": 4, "tempo": -2, "technik": -4, "passen": -2, "abschluss": -12, "reflexe": -30},
	"MF": {"passen": 5, "technik": 4, "stellung": 1, "tempo": 0, "zweikampf": 0, "abschluss": -4, "kopfball": -4, "reflexe": -30},
	"ST": {"abschluss": 6, "tempo": 3, "technik": 1, "kopfball": 2, "passen": -3, "zweikampf": -8, "stellung": -4, "reflexe": -30},
}

var id: int = 0
var first_name: String = ""
var last_name: String = ""
var pos: String = "MF"
var age: int = 25
var strength: int = 60        # Gesamtstärke, aus den Attributen berechnet
var attributes := {}          # Attribut-Schlüssel -> Wert (siehe ATTRIBUTES)
var form: float = 1.0         # ca. 0.8..1.2, verändert sich von Spiel zu Spiel
var stamina: int = 65         # Ausdauer 30..95: wie schnell die Frische im Spiel sinkt
var condition: float = 100.0  # Frische 0..100: regeneriert zwischen den Spieltagen
var injury_matchdays: int = 0 # 0 = fit, sonst verbleibende Spieltage Verletzungspause
var suspended_matchdays: int = 0 # Sperre: jede 5. Gelbe = 1 Spieltag, Rot = 2 Spieltage
var last_rating: float = 0.0  # Note des letzten Einsatzes (1,0–6,0; 0 = noch kein Einsatz)
var contract_years: int = 2
var salary: int = 10000       # Euro pro Monat
var club_id: int = -1

# Saisonstatistik
var goals_season: int = 0
var yellow_cards: int = 0
var red_cards: int = 0

func full_name() -> String:
	return "%s %s" % [first_name, last_name]

func attr(key: String) -> int:
	return int(attributes.get(key, 40))

## Erzeugt ein Attributset um einen Zielwert herum, geprägt vom Positionsprofil.
static func make_attributes(p_pos: String, target: int) -> Dictionary:
	var attrs := {}
	for key in ATTRIBUTES:
		attrs[key] = clampi(target + int(ATTR_OFFSETS[p_pos][key]) + randi_range(-6, 6), 5, 96)
	return attrs

## Berechnet die Gesamtstärke aus den Attributen (positionsabhängig gewichtet).
func recompute_strength() -> void:
	var weights: Dictionary = STRENGTH_WEIGHTS[pos]
	var total := 0.0
	for key in weights:
		total += attr(key) * weights[key]
	strength = clampi(int(round(total)), 25, 96)

## Entwicklung: verändert zufällige Attribute und aktualisiert die Stärke.
func develop(amount: int, tries: int) -> void:
	for i in tries:
		var key: String = ATTRIBUTES.keys().pick_random()
		attributes[key] = clampi(attr(key) + amount, 5, 96)
	recompute_strength()

func rating() -> float:
	return strength * form

func is_injured() -> bool:
	return injury_matchdays > 0

func is_suspended() -> bool:
	return suspended_matchdays > 0

## Einsatzbereit = weder verletzt noch gesperrt.
func is_available() -> bool:
	return not is_injured() and not is_suspended()

## Frische-Malus: volle Frische = 100 %, völlig platt = 72 % der Leistung.
func condition_factor() -> float:
	return 0.72 + 0.28 * condition / 100.0

## Bewertung inkl. Frische – Grundlage für Aufstellungsentscheidungen.
func effective_rating() -> float:
	return rating() * condition_factor()

func market_value() -> int:
	var base := 50000.0 * pow(1.135, strength - 50)
	var age_factor := 0.6
	if age <= 21:
		age_factor = 1.3
	elif age <= 28:
		age_factor = 1.2
	elif age <= 31:
		age_factor = 0.9
	return maxi(int(round(base * age_factor / 1000.0)) * 1000, 25000)

func reset_season_stats() -> void:
	goals_season = 0
	yellow_cards = 0
	red_cards = 0

func to_dict() -> Dictionary:
	return {
		"id": id, "fn": first_name, "ln": last_name, "pos": pos, "age": age,
		"str": strength, "attrs": attributes, "form": form, "sta": stamina, "cond": condition,
		"inj": injury_matchdays, "sus": suspended_matchdays, "note": last_rating, "cy": contract_years, "sal": salary,
		"club": club_id, "g": goals_season, "yc": yellow_cards, "rc": red_cards,
	}

static func from_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new()
	p.id = int(d.id)
	p.first_name = d.fn
	p.last_name = d.ln
	p.pos = d.pos
	p.age = int(d.age)
	p.strength = int(d.str)
	var saved_attrs: Dictionary = d.get("attrs", {})
	if saved_attrs.is_empty():
		# Alte Spielstände ohne Attribute: aus Stärke und Position ableiten
		p.attributes = make_attributes(p.pos, p.strength)
	else:
		for key in saved_attrs:
			p.attributes[key] = int(saved_attrs[key])
	p.recompute_strength()
	p.form = float(d.form)
	p.stamina = int(d.get("sta", 65))
	p.condition = float(d.get("cond", 100.0))
	p.injury_matchdays = int(d.get("inj", 0))
	p.suspended_matchdays = int(d.get("sus", 0))
	p.last_rating = float(d.get("note", 0.0))
	p.contract_years = int(d.cy)
	p.salary = int(d.sal)
	p.club_id = int(d.club)
	p.goals_season = int(d.get("g", 0))
	p.yellow_cards = int(d.get("yc", 0))
	p.red_cards = int(d.get("rc", 0))
	return p
