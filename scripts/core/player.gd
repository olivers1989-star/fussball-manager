class_name PlayerData
extends RefCounted
## Ein einzelner Spieler mit Attributen, Vertrag und Saisonstatistik.

## Detaillierte Positionen. Für Spielmechanik (Engine, Wechselregeln) zählt die
## Positionsgruppe (TW/AB/MF/ST), fürs Profil und die Aufstellung die genaue Position.
const POSITIONS := ["TW", "LV", "IV", "RV", "DM", "ZM", "LM", "RM", "OM", "LA", "RA", "MS"]
const POSITION_NAMES := {
	"TW": "Torwart", "LV": "Linker Verteidiger", "IV": "Innenverteidiger",
	"RV": "Rechter Verteidiger", "DM": "Defensives Mittelfeld", "ZM": "Zentrales Mittelfeld",
	"LM": "Linkes Mittelfeld", "RM": "Rechtes Mittelfeld",
	"OM": "Offensives Mittelfeld", "LA": "Linksaußen", "RA": "Rechtsaußen", "MS": "Mittelstürmer",
}
const GROUP_OF := {
	"TW": "TW", "LV": "AB", "IV": "AB", "RV": "AB",
	"DM": "MF", "ZM": "MF", "LM": "MF", "RM": "MF", "OM": "MF",
	"LA": "ST", "RA": "ST", "MS": "ST",
}
const GROUPS := ["TW", "AB", "MF", "ST"]

## Spielerattribute (1–96) in drei Kategorien plus Torwart-Spezialwerte.
## Die Gesamtstärke wird daraus positionsabhängig berechnet, und JEDES Attribut
## hat eine konkrete Wirkung in der Match-Engine (siehe match_sim.gd).
const ATTRIBUTES := {
	# Technisch
	"abschluss": "Abschluss",
	"dribbling": "Dribbling",
	"passen": "Passspiel",
	"technik": "Technik",
	"flanken": "Flanken",
	"kopfball": "Kopfball",
	"zweikampf": "Zweikampf",
	"standards": "Standards",
	# Mental
	"stellung": "Stellungsspiel",
	"uebersicht": "Übersicht",
	"entschlossenheit": "Entschlossenheit",
	"nerven": "Nervenstärke",
	"aggressivitaet": "Aggressivität",
	"konzentration": "Konzentration",
	"fuehrung": "Führungsqualität",
	"einsatz": "Einsatzbereitschaft",
	# Physisch
	"tempo": "Tempo",
	"kraft": "Kraft",
	"sprung": "Sprungkraft",
	"beweglichkeit": "Beweglichkeit",
	"robust": "Robustheit",
	# Torwart
	"reflexe": "Reflexe",
	"strafraum": "Strafraumbeherrschung",
}

const CATEGORIES := {
	"Technisch": ["abschluss", "dribbling", "passen", "technik", "flanken", "kopfball", "zweikampf", "standards"],
	"Mental": ["stellung", "uebersicht", "entschlossenheit", "nerven", "aggressivitaet", "konzentration", "fuehrung", "einsatz"],
	"Physisch": ["tempo", "kraft", "sprung", "beweglichkeit", "robust"],
	"Torwart": ["reflexe", "strafraum"],
}

## Gewichtung der Attribute für die Gesamtstärke je Position (Summe = 1.0).
const STRENGTH_WEIGHTS := {
	"TW": {"reflexe": 0.4, "strafraum": 0.2, "stellung": 0.12, "konzentration": 0.1, "beweglichkeit": 0.1, "nerven": 0.08},
	"IV": {"zweikampf": 0.22, "stellung": 0.18, "kopfball": 0.14, "kraft": 0.12, "konzentration": 0.1, "sprung": 0.08, "tempo": 0.08, "passen": 0.08},
	"LV": {"tempo": 0.18, "zweikampf": 0.18, "stellung": 0.14, "flanken": 0.14, "passen": 0.1, "einsatz": 0.1, "technik": 0.08, "konzentration": 0.08},
	"RV": {"tempo": 0.18, "zweikampf": 0.18, "stellung": 0.14, "flanken": 0.14, "passen": 0.1, "einsatz": 0.1, "technik": 0.08, "konzentration": 0.08},
	"DM": {"zweikampf": 0.22, "passen": 0.16, "stellung": 0.16, "uebersicht": 0.1, "kraft": 0.1, "einsatz": 0.1, "technik": 0.08, "konzentration": 0.08},
	"ZM": {"passen": 0.2, "technik": 0.16, "uebersicht": 0.16, "zweikampf": 0.12, "einsatz": 0.12, "stellung": 0.08, "tempo": 0.08, "dribbling": 0.08},
	"LM": {"tempo": 0.18, "flanken": 0.18, "passen": 0.14, "dribbling": 0.14, "technik": 0.12, "einsatz": 0.1, "uebersicht": 0.07, "zweikampf": 0.07},
	"RM": {"tempo": 0.18, "flanken": 0.18, "passen": 0.14, "dribbling": 0.14, "technik": 0.12, "einsatz": 0.1, "uebersicht": 0.07, "zweikampf": 0.07},
	"OM": {"technik": 0.18, "passen": 0.16, "uebersicht": 0.16, "dribbling": 0.14, "abschluss": 0.12, "nerven": 0.08, "tempo": 0.08, "standards": 0.08},
	"LA": {"tempo": 0.2, "dribbling": 0.18, "flanken": 0.14, "abschluss": 0.14, "technik": 0.12, "beweglichkeit": 0.08, "passen": 0.07, "nerven": 0.07},
	"RA": {"tempo": 0.2, "dribbling": 0.18, "flanken": 0.14, "abschluss": 0.14, "technik": 0.12, "beweglichkeit": 0.08, "passen": 0.07, "nerven": 0.07},
	"MS": {"abschluss": 0.26, "kopfball": 0.14, "tempo": 0.12, "nerven": 0.12, "technik": 0.1, "dribbling": 0.08, "kraft": 0.08, "sprung": 0.05, "stellung": 0.05},
}

## Positionsprofil: nur die markanten Abweichungen vom Zielwert.
## Nicht gelistete Attribute liegen leicht darunter (siehe _offset_for).
const ATTR_OFFSETS := {
	"TW": {"reflexe": 6, "strafraum": 4, "stellung": 2, "beweglichkeit": 2, "konzentration": 2, "tempo": -10, "dribbling": -12, "abschluss": -18, "flanken": -14, "kopfball": -8, "zweikampf": -10, "standards": -8},
	"IV": {"zweikampf": 6, "kopfball": 6, "stellung": 5, "kraft": 5, "sprung": 4, "konzentration": 2, "dribbling": -8, "flanken": -8, "abschluss": -12, "standards": -4},
	"LV": {"tempo": 4, "flanken": 4, "zweikampf": 2, "einsatz": 2, "stellung": 2, "abschluss": -10, "kopfball": -3, "standards": -4},
	"RV": {"tempo": 4, "flanken": 4, "zweikampf": 2, "einsatz": 2, "stellung": 2, "abschluss": -10, "kopfball": -3, "standards": -4},
	"DM": {"zweikampf": 5, "stellung": 4, "passen": 2, "kraft": 2, "einsatz": 2, "abschluss": -8, "flanken": -6, "dribbling": -4},
	"ZM": {"passen": 5, "uebersicht": 4, "technik": 3, "einsatz": 2, "abschluss": -4, "flanken": -4, "kopfball": -4},
	"LM": {"tempo": 5, "flanken": 5, "dribbling": 3, "passen": 2, "kopfball": -5, "zweikampf": -4, "kraft": -4},
	"RM": {"tempo": 5, "flanken": 5, "dribbling": 3, "passen": 2, "kopfball": -5, "zweikampf": -4, "kraft": -4},
	"OM": {"technik": 5, "uebersicht": 5, "passen": 4, "dribbling": 3, "standards": 2, "zweikampf": -6, "kopfball": -5, "kraft": -4},
	"LA": {"tempo": 6, "dribbling": 5, "flanken": 3, "beweglichkeit": 3, "abschluss": 1, "zweikampf": -8, "kopfball": -4, "kraft": -5},
	"RA": {"tempo": 6, "dribbling": 5, "flanken": 3, "beweglichkeit": 3, "abschluss": 1, "zweikampf": -8, "kopfball": -4, "kraft": -5},
	"MS": {"abschluss": 7, "kopfball": 4, "nerven": 3, "kraft": 2, "tempo": 2, "zweikampf": -8, "flanken": -5, "stellung": -3},
}

static func _offset_for(p_pos: String, key: String) -> int:
	# Torwart-Spezialwerte sind für Feldspieler sehr niedrig – und umgekehrt
	if GROUP_OF[p_pos] != "TW" and key in ["reflexe", "strafraum"]:
		return -30
	return int(ATTR_OFFSETS[p_pos].get(key, -2))

var id: int = 0
var first_name: String = ""
var last_name: String = ""
var pos: String = "ZM"
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

## Positionsgruppe (TW/AB/MF/ST) – Grundlage für Engine und Wechselregeln.
func group() -> String:
	return GROUP_OF[pos]

## Marktgerechtes Monatsgehalt: ca. 2,5 % des Marktwerts.
func expected_salary() -> int:
	return maxi(int(market_value() / 40.0 / 1000.0) * 1000, 3000)

## Erzeugt ein Attributset um einen Zielwert herum, geprägt vom Positionsprofil.
static func make_attributes(p_pos: String, target: int) -> Dictionary:
	var attrs := {}
	for key in ATTRIBUTES:
		attrs[key] = clampi(target + _offset_for(p_pos, key) + randi_range(-6, 6), 5, 96)
	return attrs

## Kombinierter Wert zweier Attribute (z. B. Kopfball × Sprungkraft).
func combo(key_a: String, key_b: String, weight_a := 0.6) -> float:
	return attr(key_a) * weight_a + attr(key_b) * (1.0 - weight_a)

## Berechnet die Gesamtstärke aus den Attributen (positionsabhängig gewichtet).
func recompute_strength() -> void:
	var weights: Dictionary = STRENGTH_WEIGHTS[pos]
	var total := 0.0
	for key in weights:
		total += attr(key) * weights[key]
	strength = clampi(int(round(total)), 25, 96)

## Entwicklung: verändert bevorzugt positionsrelevante Attribute (70 %),
## gelegentlich beliebige – und aktualisiert die Stärke.
func develop(amount: int, tries: int) -> void:
	var relevant: Array = STRENGTH_WEIGHTS[pos].keys()
	for i in tries:
		var key: String
		if randf() < 0.7:
			key = relevant.pick_random()
		else:
			key = ATTRIBUTES.keys().pick_random()
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
	# Alte Spielstände mit Positionsgruppen auf detaillierte Positionen migrieren
	if p.pos in ["AB", "MF", "ST"]:
		p.pos = {"AB": "IV", "MF": "ZM", "ST": "MS"}[p.pos]
	p.strength = int(d.str)
	# Attribute laden; fehlende (ältere Spielstände) aus Stärke und Position ergänzen
	var saved_attrs: Dictionary = d.get("attrs", {})
	var defaults := make_attributes(p.pos, p.strength)
	for key in ATTRIBUTES:
		p.attributes[key] = int(saved_attrs.get(key, defaults[key]))
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
