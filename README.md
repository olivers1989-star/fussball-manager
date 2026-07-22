# Fussball Manager

Ein Fußball-Manager als **Windows-Spiel**, entwickelt mit der [Godot Engine 4.7](https://godotengine.org) – zwei Ligen, 36 Vereine, eine feste Datenbank mit 900 Profispielern und eine Match-Engine, in der jedes der 23 Spielerattribute wirklich zählt.

> **Spielen:** Den fertigen Installer gibt es unter [Releases](../../releases/latest). Updates werden einfach über die bestehende Installation installiert – Spielstände bleiben erhalten.

---

## Inhalt

- [Die Grundidee](#die-grundidee)
- [Features im Überblick](#features-im-überblick)
- [Für Entwickler](#für-entwickler)
- [Eigene Daten anpassen](#eigene-daten-anpassen)
- [Roadmap](#roadmap)

---

## Die Grundidee

Drei Prinzipien tragen das ganze Spiel:

1. **Kein Ergebnis steht beim Anpfiff fest.** Jedes Spiel wird Minute für Minute berechnet – aus Taktik, Aufstellung, Attributen, Frische, Form und Tagesform. Der Stärkste gewinnt *nicht* automatisch.
2. **Jedes Attribut hat eine konkrete Wirkung.** Kein Wert ist Dekoration – von Abschluss über Konzentration bis Robustheit greift jeder Wert an einer nachweisbaren Stelle in die Engine ein (belegt durch automatisierte Mechanik-Tests).
3. **Das Stärkesystem ist dynamisch.** Ein 14-Jähriger mit Stärke 17 kann zum Superstar reifen – Talent (1–5★) und Potenzial entscheiden über den Weg, nicht der Startwert.

## Features im Überblick

<details open>
<summary><b>Karrierestart</b></summary>

- **Spielstart-Assistent in 3 Schritten** mit Fortschrittsanzeige: Trainerprofil (Name, Geburtsdatum, Herkunft, Nationalität mit Flagge, Fähigkeiten-Verteilung) → Spielmodus → Verein & Vertrag
- **Zwei Spielmodi:** *Echte Karriere* (Start bei kleinen Zweitligisten, mit wachsendem Ruf melden sich größere Vereine) und *Vereinsauswahl* (freie Wahl), je mit Schwierigkeit Leicht/Normal/Schwer
- **Trainer-Fähigkeiten mit Spielwirkung:** Taktik (Teamstärke), Training (Formaufbau), Motivation (fängt Niederlagen ab, entscheidet über die Ansprache), Verhandlung (Transferpreise), Jugendarbeit (stärkerer Nachwuchs)
- **Vereinsspezifische Angebote:** Jeder Verein hat einen Charakter (schlafender Riese / Abstiegskampf / Ausbildungsverein), der Vorstandsbotschaft, Laufzeit und Ton prägt
- **Echte Vertragsverhandlung** mit dem Vorstandsvorsitzenden: Laufzeit, Gehalt, Erfolgsprämie, Siegprämie und **Ausstiegsklausel** – mit Gesprächsklima, Gegenangeboten, Abbruchrisiko und handschriftlicher Unterschrift auf dem Vertragsdokument
</details>

<details open>
<summary><b>Spieler & Kader</b></summary>

- **Feste Spielerdatenbank:** 900 Profis in `data/players.json` – jeder neue Spielstand startet mit identischen Kadern (nur Jugendspieler werden gewürfelt). Vollständig editierbar
- **23 Attribute** in vier Kategorien (Technisch, Mental, Physisch, Torwart), positionsabhängig gewichtet zur Gesamtstärke
- **Talent (1–5★) und Potenzial:** 5★-Talente sind eine Rarität (~2 %); die Entwicklung folgt Alterskurve, Einsatzzeit, Noten und Entschlossenheit
- **20 Spielereigenschaften mit echter Spielwirkung:** Trainingsweltmeister/-muffel, Joker, Dauerbrenner, Eisenmann/Verletzungsanfällig, Elfmeterspezialist/-killer, Freistoßspezialist, Kopfballungeheuer, Knipser, Spielmacher, Führungsspieler, Eiskalt/Nervenbündel, Heimspielheld/Auswärtskämpfer, Spätzünder, Fairplay/Hitzkopf
- **Nationalitäten** mit gezeichneten Flaggen (20 Nationen) – Grundlage für spätere Nationalmannschaften
- **Nebenpositionen:** Jeder darf überall spielen (naheliegende Rollen mit kleinem, gruppenfremde mit deutlichem Abzug) – und **erlernt fremde Positionen durch Einsätze** bis zur Meisterschaft
- **FM-artige Spielerprofile** (Rechtsklick) mit allen Attributen als Balken, Positionen, Eigenschaften, Zustand und Saisonstatistik
</details>

<details open>
<summary><b>Aufstellung & Taktik</b></summary>

- **Aufstellungsbildschirm im Manager-Stil:** links die detaillierte Spielerliste (Position, gespielte Zone, Flagge, Alter, Talent, Stärke, Frische, Form), gruppiert in Startelf / Ersatzbank / Reserve – rechts das 2D-Spielfeld
- **Freies Positionieren:** Spieler irgendwo aufs Feld ziehen – wo du ihn ablegst, spielt er. Das Feld ist in **Zonen** geteilt (TW · LV/IV/RV · DM/ZM/OM mit LM/RM außen · LA/MS/RA); auch extreme Ausrichtungen wie 5 Stürmer sind möglich, die Ausrichtungs-Anzeige rechnet live mit
- **16 Formations-Presets:** 4-4-2, 4-4-2 Raute, 4-3-3, 4-2-3-1, 4-5-1, 3-5-2, 5-3-2, 4-4-1-1, 4-3-2-1 (Tannenbaum), 4-1-3-2, 4-1-4-1, 5-4-1, 3-4-3, 4-2-4 u. a.
- **Aufgewertete Spielerkarten** mit farbiger Positions-Pille, farbcodierter Stärkezahl, Frische in Prozent und Frische-Balken
- **Ersatzbank (max. 7):** Im Spiel darf nur von der nominierten Bank gewechselt werden
- **Auswahl-Kriterien:** Schieberegler für Stärke / Frische / Form bestimmen, wonach „Beste Elf & Bank" aufstellt
- Tauschen per Drag & Drop auf dem Feld **und** in der Liste
</details>

<details open>
<summary><b>Spieltag</b></summary>

- **Spieltagsankündigung** mit Wappen, Tabellenplätzen, Fakten-Vergleich (Kaderstärke, Saison, Form als Sterne, Hinspiel) und der **Ansprache vor dem Spiel** (4 Stufen – mutiger heißt mehr Wirkung *und* mehr Risiko)
- **Live-Simulation Minute für Minute** mit Liveticker (Tore, Großchancen, Karten, Platzverweise, Wechsel, Verletzungen, Spielfluss-Kommentar) in wählbarer Geschwindigkeit
- **Beide Mannschaften im Blick:** Aufstellungen mit gespielter Position, Stärke, Frische, Live-Note und Toren; dazu Statistik (Ballbesitz, Chancen, Ecken, Freistöße, Elfmeter, Karten) und die **Konferenz** der anderen Spiele
- **Eingriffe:** Spielweise (defensiv/ausgewogen/offensiv), Aufstellungs-Overlay mit beiden Elfen – Positionen live umstellen und per Drag & Drop wechseln (max. 5)
- **Ausführlicher Spielbericht:** Endstand mit Halbzeitstand und Spielanteilen, Torschützen-Timeline, Spieler des Spiels, komplette Statistik, Noten und alle weiteren Ergebnisse
- **KI mit Handschrift:** Jeder Verein wählt vor dem Spieltag die Formation, die zu seinem verfügbaren Kader passt, und eine Grundausrichtung nach Kräfteverhältnis
</details>

<details open>
<summary><b>Saison & Verwaltung</b></summary>

- 2 Ligen à 18 fiktive Vereine nach dem Vorbild der echten deutschen Ligen, 34 Spieltage, Hin-/Rückrunde, Auf- und Abstieg (je 3)
- **Kalender & Tagesrhythmus** mit Wochensimulation, Trainingsschwerpunkt und Spielvorbereitung am Vortag (Matchplan mit Gegneranalyse)
- **Kondition, Form und Tagesform:** Rotation ist Pflicht – Frische regeneriert nur teilweise
- **Verletzungen** (Zwangswechsel, 1–5 Spieltage) und **Sperren** (jede 5. Gelbe, Rot = 2 Spiele)
- **Transfermarkt** mit realistischen Marktwerten (Zweitliga-Stammspieler unter 1 Mio, Bundesliga 5–12 Mio, Weltklasse 80–150 Mio)
- **Finanzen** auf realistischer Skala: Budget, Ticketeinnahmen, Sponsor-/TV-Gelder und Gehälter aus dem tatsächlichen Kader abgeleitet
- **Saisonwechsel:** Meister, Auf-/Absteiger, Alterung und Entwicklung, **individuelle Karriereenden** (Feldspieler 33–37, Torhüter bis ~40, Stars länger) mit dauerhaftem Archiv, nachrückende Jugendspieler
- **Speichersystem** mit benannten Slots, Karten-Übersicht (Wappen, Tabellenplatz, Saison, Zeitstempel), Überschreiben, Löschen und Schnellspeichern
</details>

## Für Entwickler

```
autoload/        Singletons: Data (Stammdaten & Weltgenerierung), Game (Spielstand & Regeln)
data/            Editierbare Stammdaten (JSON)
scenes/          Godot-Szenen (Hauptmenü, Spielstart, Zentrale, Match)
scripts/core/    Spiellogik: Spieler, Verein, Liga, Spielplan, Match-Engine
scripts/ui/      Bildschirme und Tabs der Manager-Zentrale
tests/           Automatisierte Tests und Werkzeuge (headless ausführbar)
installer/       Inno-Setup-Skript für den Windows-Installer
```

- **Spiel starten:** `start_spiel.bat` · **Editor öffnen:** `start_editor.bat` (Godot liegt unter `C:\Tools\Godot`)
- **Tests headless ausführen:**
  ```bat
  Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/smoke_test.tscn
  ```
  Verfügbar sind u. a. `smoke_test` (Gesamtdurchlauf), `ui_test` (alle Bildschirme), `mechanik_test` (Wirkungsnachweis je Attribut), `aufstellung_test` (Zonen & Slot-System), `nebenpositionen_test`, `traits_test`, `finanz_test`, `migration_test`, `speichern_test`, `balance_test` und `saison_report` (5-Saisons-Auswertung als JSON)
- **Design:** Das komplette Erscheinungsbild steckt zentral in [scripts/ui/ui_theme.gd](scripts/ui/ui_theme.gd)

## Eigene Daten anpassen

Alle Stammdaten liegen als editierbare JSON-Dateien in [data/](data/):

| Datei | Inhalt |
|---|---|
| `clubs.json` | Vereine: Name, Kürzel, Stadt, Stadion, Kapazität, Stärke, Liga, Vereinsfarbe, Vorstandsvorsitzender |
| `players.json` | Die feste Spielerdatenbank: 900 Profis mit Name, Position, Alter, allen 23 Attributen, Talent, Potenzial, Ausdauer, Vertrag, Nationalität, Eigenschaften und Nebenpositionen |
| `names.json` | Vor-/Nachnamen für generierte Spieler (Jugend) sowie Sponsorennamen |

Spielerdatenbank neu würfeln: `players.json` löschen und `tests/generate_database.tscn` ausführen.
Wer echte Vereins- und Spielernamen möchte, trägt sie dort ein (nur für den Privatgebrauch!).

## Roadmap

**Als Nächstes**

1. **Kalender & Tagesereignisse** – realistische Sommervorbereitung, planbare Testspiele, echte Spielergespräche
2. **Pokalwettbewerb** über beide Ligen (K.-o.-Runden)
3. **Jugendakademie** mit fester Nachwuchsdatenbank und gezielter Förderung

**Danach angedacht**

4. **Editor** für Vereine, Spieler und Ligen-Grundlagen (Bankgröße, Auf-/Absteiger)
5. **Moral & Mannschaftsklima** als eigener Faktor
6. **Nationalmannschaften** auf Basis der Nationalitäten
7. **Sponsorenverhandlungen & Stadionausbau**
8. **Hall of Fame** aus dem Karriereenden-Archiv, Rekordlisten
9. **KI-Transfers** zwischen den Vereinen, Ablösepoker
