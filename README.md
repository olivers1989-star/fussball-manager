# Fussball Manager

Ein Fußball-Manager-Spiel für den PC, entwickelt mit der [Godot Engine 4.7](https://godotengine.org).

## Spielen / Entwickeln

- **Spiel starten:** `start_spiel.bat` (führt das Projekt direkt aus)
- **Editor öffnen:** `start_editor.bat` (öffnet das Projekt im Godot-Editor)

Die Godot-Engine liegt unter `C:\Tools\Godot`.

## Features (Ausbaustufe 1)

- Spielstart-Assistent in 3 Schritten: **Trainerprofil anlegen** (Name, Geburtsdatum, Herkunftsort, Nationalität + Fähigkeiten-Verteilung) → **Spielmodus wählen** → **Verein/Angebot**
- Zwei Spielmodi: **Echte Karriere** (Start bei kleinen Zweitligisten, mit wachsendem Ruf kommen Angebote besserer Vereine) und **Vereinsauswahl** (freie Wahl), jeweils mit Schwierigkeit Leicht/Normal/Schwer
- **Trainer-Fähigkeiten** mit Spielwirkung: Taktik (Teamstärke im Spiel), Training (Formaufbau), Motivation (fängt Niederlagen ab), Verhandlung (bessere Transferpreise), Jugendarbeit (stärkerer Nachwuchs)
- 2 Ligen (Erste & Zweite Liga) mit je 18 fiktiven Vereinen, die den echten deutschen Ligen nachempfunden sind (z. B. „FC Bavaria München", „BV Westfalia Dortmund", „FC Knappen Gelsenkirchen 04"), inkl. Auf-/Abstieg (3 Vereine)
- Prozedural generierte Kader (~860 Spieler) mit Stärke, Form, Alter, Vertrag, Gehalt und Marktwert
- Saison mit 34 Spieltagen, Spielplan (Hin-/Rückrunde) und Tabellen
- **Echte Live-Simulation**: Das Spiel wird Minute für Minute berechnet – nichts steht beim Anpfiff fest. Über das Taktik-Panel greifst du jederzeit ein: **Spielweise** (defensiv/ausgewogen/offensiv) und **Auswechslungen** (max. 5) wirken ab der nächsten Minute. Pause- und Halbzeit-Stopp inklusive, KI-Gegner reagieren in Minute 60/75 auf den Spielstand
- Text-Liveticker (Tore, Großchancen, Karten, Platzverweise, Wechsel, Verletzungen) in wählbarer Geschwindigkeit, dazu die **Konferenz** der anderen Spiele deiner Liga in Echtzeit
- **Kondition & Ausdauer**: Spieler verlieren im Spiel Frische (abhängig von individueller Ausdauer und Spielweise) und regenerieren zwischen den Spieltagen nur teilweise – Rotation ist Pflicht. Die Leistung jedes Spielers ergibt sich aus Stärke × Form × **Tagesform** × Frische; der Stärkste gewinnt also nicht automatisch
- **Verletzungen** mit Zwangswechsel und Ausfallzeiten (1–5 Spieltage) sowie **Einzelnoten** (1,0–6,0) für jeden eingesetzten Spieler
- **Sperren**: jede 5. Gelbe Karte = 1 Spieltag, Rote Karte = 2 Spieltage (der Spieler fliegt sofort vom Platz)
- **Training**: Wochenschwerpunkt wählbar (Ausgewogen / Kondition / Regeneration / Leistung) mit echten Effekten auf Frische, Form, Ausdauer und die Entwicklung junger Spieler – inkl. Fitness-Übersicht des Kaders
- **Aufstellung mit freiem Positionieren**: Spieler irgendwo aufs 2D-Spielfeld ziehen – er spielt exakt dort. Das Feld ist in **Zonen** geteilt (TW · LV/IV/RV · DM/ZM/OM mit LM/RM außen · LA/MS/RA), die Zone bestimmt die gespielte Position; auch extreme Ausrichtungen (5 Stürmer!) sind möglich, die Ausrichtungs-Anzeige (z. B. „5-4-1") rechnet live mit. **16 Formations-Presets** (4-4-2, 4-4-2 Raute, 4-3-3, 4-2-3-1, 4-5-1, 3-5-2, 5-3-2, 4-4-1-1, 4-3-2-1 Tannenbaum, 4-1-3-2, 4-1-4-1, 5-4-1, 3-4-3, 4-2-4 u. a.) als Startpunkt, daneben die **Ersatzbank (max. 7 Plätze)**, rechts die detaillierte Kaderliste mit **Flaggen**, Talent, Marktwert, Ø-Note und Eigenschaften. **Slot-basiert mit Spielwirkung**: Jeder Spieler wird im Spiel auf seiner Zone bewertet. **Jeder darf überall spielen** – naheliegende Nebenrollen (RM als RV oder RA) mit kleinem Abzug, gruppenintern etwas mehr, gruppenfremd deutlich, Feldspieler im Tor als Notnagel. **Nebenpositionen werden durch Einsätze erlernt**: Spielt jemand wiederholt auf einer fremden Position, steigt seine Vertrautheit dort bis zur Meisterschaft – gelernte Positionen stehen im Spielerprofil
- **Moderne Spielansicht**: Anzeigetafel mit Vereins-Badges, Ausrichtung, Kaderstärke und Spielfortschritts-Balken; Liveticker mit Minuten-Chips und Ereignis-Symbolen (Tore fett und farbig); Taktik-Karte mit Spielweise-Schaltern, Feldliste (gespielte Position + Live-Frische) und Bank; Konferenz mit Live-Minute; Noten-Übersicht mit Torschützen nach Abpfiff
- **Nationalitäten** für alle Spieler (aus den Namen abgeleitet, in der Datenbank editierbar – später Basis für Nationalmannschaften) und **20 Spielereigenschaften** mit echter Spielwirkung: Trainingsweltmeister/-muffel (Entwicklungstempo), Joker (stärker nach Einwechslung), Dauerbrenner (Frische), Eisenmann/Verletzungsanfällig (Verletzungsrisiko), Elfmeterspezialist/-killer, Freistoßspezialist, Kopfballungeheuer, Knipser, Spielmacher, Führungsspieler, Eiskalt/Nervenbündel (Schlussphase), Heimspielheld/Auswärtskämpfer, Spätzünder, Fairplay/Hitzkopf (Karten)
- Transfermarkt: Spieler kaufen und verkaufen, mit **realistischen Marktwerten** (Zweitliga-Stammspieler unter 1 Mio, Bundesliga-Stammspieler 5–12 Mio, Weltklasse 80–150 Mio – getrieben von Stärke, Alter, Potenzial und Saisonleistung)
- Finanzen: Budget, Ticketeinnahmen, Sponsor-/TV-Gelder und Gehälter auf realistischer Skala (abgeleitet vom tatsächlichen Kader), Buchungshistorie
- Saisonwechsel: Meister, Auf-/Absteiger, Spieleralterung & -entwicklung, **individuelle Karriereenden** (Feldspieler meist 33–37, Torhüter bis ~40, Stars länger, Ausgelaugte früher) mit dauerhaftem Archiv im Spielstand, Jugendspieler rücken sichtbar nach (News + Saisonbilanz)
- Speichern & Laden (JSON-Spielstände unter `%APPDATA%\Godot\app_userdata\Fussball Manager\saves`)

## Design

Das komplette Erscheinungsbild wird zentral in [scripts/ui/ui_theme.gd](scripts/ui/ui_theme.gd) definiert (dunkles Manager-Design, Vereins-Badges, Karten-Layouts, Sidebar-Navigation). Farben und Stile dort ändern sich überall im Spiel.

## Eigene Daten (Vereine & Namen anpassen)

Alle Stammdaten liegen als editierbare JSON-Dateien in [data/](data/):

- `clubs.json` — Vereine (Name, Kürzel, Stadion, Kapazität, Stärke, Liga, Vereinsfarbe, Vorsitzender)
- `players.json` — die **feste Spielerdatenbank**: 900 Profispieler mit Namen, Position, Alter, allen 23 Attributen, Talent, Potenzial, Ausdauer und Vertragslaufzeit. Jeder neue Spielstand startet mit exakt diesen Kadern (nur Jugendspieler werden zufällig erzeugt). Grundlage für einen späteren Editor. Neu generieren: Datei löschen und `tests/generate_database.tscn` ausführen.
- `names.json` — Vor-/Nachnamen für die Spielergenerierung (Jugend) sowie Sponsorennamen

Wer echte Vereins- und Spielernamen möchte, trägt sie einfach dort ein (nur für den Privatgebrauch!).

## Projektstruktur

```
autoload/        Singletons: Data (Stammdaten & Weltgenerierung), Game (Spielstand & Regeln)
data/            Editierbare Stammdaten (JSON)
scenes/          Godot-Szenen (Hauptmenü, Spielstart, Zentrale, Match)
scripts/core/    Spiellogik: Spieler, Verein, Liga, Spielplan, Match-Engine
scripts/ui/      Bildschirme und Tabs der Manager-Zentrale
```

## Roadmap (weitere Ausbaustufen)

1. **Pokalwettbewerb** (K.-o.-Runden über beide Ligen)
2. **Training & Spielerentwicklung** unter der Saison, Verletzungen
3. **Vertragsverhandlungen** (Gehaltsforderungen, Ablösepoker, KI-Transfers)
4. **Jugendakademie** mit Talenten und Förderung
5. **Sponsorenverhandlungen & Stadionausbau**
6. **2D-Spielfeldansicht** für den Liveticker
