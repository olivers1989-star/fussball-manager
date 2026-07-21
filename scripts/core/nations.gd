class_name Nations
extends RefCounted
## Nationalitäten: Länderliste mit Kürzeln, Namens-Heuristik für bestehende
## Spieler (feste Datenbank/alte Spielstände) und gewichtete Auslosung für
## neu generierte Spieler. Später die Basis für Nationalmannschaften.

const CODES := {
	"Deutschland": "GER", "Türkei": "TUR", "Polen": "POL", "Portugal": "POR",
	"Brasilien": "BRA", "Serbien": "SRB", "Kroatien": "CRO", "Italien": "ITA",
	"Frankreich": "FRA", "Österreich": "AUT", "Schweiz": "SUI", "Niederlande": "NED",
	"Dänemark": "DEN", "Tschechien": "CZE", "Spanien": "ESP", "Argentinien": "ARG",
	"Marokko": "MAR", "Ägypten": "EGY", "England": "ENG", "Belgien": "BEL",
}

## Herkunfts-Cluster der Namenspools (Nachname zählt stärker als Vorname).
const LAST_HINTS := {
	"Yilmaz": "Türkei", "Kaya": "Türkei", "Demir": "Türkei", "Sahin": "Türkei",
	"Celik": "Türkei", "Öztürk": "Türkei", "Aydin": "Türkei", "Arslan": "Türkei",
	"Dogan": "Türkei", "Kilic": "Türkei",
	"Kowalski": "Polen", "Nowak": "Polen", "Wisniewski": "Polen", "Zielinski": "Polen", "Kaminski": "Polen",
	"Silva": "Portugal", "Santos": "Portugal", "Oliveira": "Portugal", "Costa": "Portugal", "Pereira": "Brasilien",
	"Petrovic": "Serbien", "Jovanovic": "Serbien", "Kovac": "Kroatien", "Horvat": "Kroatien", "Novak": "Kroatien",
	"Rossi": "Italien", "Ferrari": "Italien", "Ricci": "Italien",
	"Moreau": "Frankreich", "Dubois": "Frankreich",
}

const FIRST_HINTS := {
	"Emre": "Türkei", "Deniz": "Türkei", "Mert": "Türkei", "Can": "Türkei", "Kerem": "Türkei",
	"Tomasz": "Polen", "Piotr": "Polen", "Kamil": "Polen", "Jakub": "Polen",
	"Joao": "Portugal", "Pedro": "Portugal", "Thiago": "Brasilien", "Luan": "Brasilien",
	"Rafael": "Spanien", "Diego": "Argentinien", "Mateo": "Spanien",
	"Andrej": "Serbien", "Nikola": "Serbien", "Luka": "Kroatien", "Ivan": "Kroatien",
	"Petar": "Serbien", "Milan": "Serbien", "Jaromir": "Tschechien",
	"Matteo": "Italien", "Alessandro": "Italien", "Lorenzo": "Italien", "Enzo": "Italien",
	"Yannick": "Frankreich", "Pierre": "Frankreich", "Antoine": "Frankreich", "Hugo": "Frankreich", "Louis": "Frankreich",
	"Amir": "Marokko", "Karim": "Ägypten",
	"Sven": "Dänemark", "Lars": "Dänemark", "Bjarne": "Dänemark", "Ole": "Dänemark",
}

## Ausländer-Pool für Spieler ohne Namens-Hinweis (deutsche Namen bleiben meist deutsch).
const MISC_POOL := ["Österreich", "Schweiz", "Niederlande", "Belgien", "England", "Dänemark", "Tschechien", "Spanien", "Frankreich", "Polen"]

static func code(nation: String) -> String:
	return CODES.get(nation, nation.left(3).to_upper())

## Deterministische Nationalität für einen bestehenden Spieler (Seed aus Name+ID):
## Namens-Cluster geben die Richtung vor, deutsche Namen sind meist Deutsche.
static func guess_for_name(fn: String, ln: String, seed_extra: int = 0) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [fn, ln, seed_extra])
	if LAST_HINTS.has(ln) and rng.randf() < 0.85:
		return LAST_HINTS[ln]
	if FIRST_HINTS.has(fn) and rng.randf() < 0.7:
		return FIRST_HINTS[fn]
	if rng.randf() < 0.86:
		return "Deutschland"
	return MISC_POOL[rng.randi_range(0, MISC_POOL.size() - 1)]

## Nationalität für neu generierte Spieler (Jugend ist häufiger deutsch).
static func roll(fn: String, ln: String, youth: bool = false) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if LAST_HINTS.has(ln) and rng.randf() < 0.85:
		return LAST_HINTS[ln]
	if FIRST_HINTS.has(fn) and rng.randf() < 0.7:
		return FIRST_HINTS[fn]
	if rng.randf() < (0.92 if youth else 0.86):
		return "Deutschland"
	return MISC_POOL[rng.randi_range(0, MISC_POOL.size() - 1)]
