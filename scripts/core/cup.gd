class_name CupData
extends RefCounted
## Der deutsche Pokal (DFB-Pokal-Nachbau): 64 Mannschaften, sechs K.-o.-Runden
## im einfachen Ausscheidungsmodus. Bei Gleichstand nach 90 Minuten gibt es
## Verlängerung, dann Elfmeterschießen. Das Finale findet auf neutralem Platz
## statt. Zweitmannschaften sind ausgeschlossen (wie in der Realität).
##
## Diese Klasse hält nur die Daten (Turnierbaum, Termine, aktuelle Runde). Die
## Spiele werden von Game simuliert, das Zugriff auf Vereine und Spieler hat.

const ROUND_NAMES := ["1. Runde", "2. Runde", "Achtelfinale", "Viertelfinale", "Halbfinale", "Finale"]
const ROUND_COUNT := 6   # 64 → 32 → 16 → 8 → 4 → 2 → 1

var year: int = 0
var round: int = 0                 # aktuelle Runde (0..5)
var round_dates: Array = []        # 6 Unix-Termine
var pairings: Array = []           # aktuelle Runde: [{home, away, played, hg, ag, ph, pa, extra, shootout, winner}]
var history: Array = []            # abgeschlossene Runden (je eine Paarungsliste)
var champion: int = 0              # Vereins-ID des Siegers (0 = noch offen)

func round_name(r: int) -> String:
	return ROUND_NAMES[r] if r >= 0 and r < ROUND_NAMES.size() else "Pokal"

func is_finished() -> bool:
	return champion > 0

## Steht die aktuelle Runde noch aus (Termin erreicht, nicht gespielt)?
func round_played() -> bool:
	for p in pairings:
		if not bool(p.get("played", false)):
			return false
	return not pairings.is_empty()

## Die Paarung eines Vereins in der aktuellen Runde (leer, wenn nicht dabei).
func pairing_of(club_id: int) -> Dictionary:
	for p in pairings:
		if int(p.home) == club_id or int(p.away) == club_id:
			return p
	return {}

## Ist der Verein noch im Wettbewerb (in der aktuellen Runde vertreten)?
func alive(club_id: int) -> bool:
	return not pairing_of(club_id).is_empty() and not is_finished()

func to_dict() -> Dictionary:
	return {"year": year, "round": round, "dates": round_dates,
		"pairings": pairings, "history": history, "champion": champion}

static func from_dict(d: Dictionary) -> CupData:
	var c := CupData.new()
	c.year = int(d.get("year", 0))
	c.round = int(d.get("round", 0))
	c.round_dates = d.get("dates", [])
	c.pairings = d.get("pairings", [])
	c.history = d.get("history", [])
	c.champion = int(d.get("champion", 0))
	return c
