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
- Aufstellung & Taktik: 5 Formationen, Startelf/Bank-Verwaltung, „Beste Elf"-Automatik
- Transfermarkt: Spieler kaufen und verkaufen
- Finanzen: Budget, Ticketeinnahmen, Sponsor, Gehälter, Buchungshistorie
- Saisonwechsel: Meister, Auf-/Absteiger, Spieleralterung & -entwicklung, Karriereenden, Jugendspieler rücken nach
- Speichern & Laden (JSON-Spielstände unter `%APPDATA%\Godot\app_userdata\Fussball Manager\saves`)

## Design

Das komplette Erscheinungsbild wird zentral in [scripts/ui/ui_theme.gd](scripts/ui/ui_theme.gd) definiert (dunkles Manager-Design, Vereins-Badges, Karten-Layouts, Sidebar-Navigation). Farben und Stile dort ändern sich überall im Spiel.

## Eigene Daten (Vereine & Namen anpassen)

Alle Stammdaten liegen als editierbare JSON-Dateien in [data/](data/):

- `clubs.json` — Vereine (Name, Kürzel, Stadion, Kapazität, Stärke, Liga, Vereinsfarbe)
- `names.json` — Vor-/Nachnamen für die Spielergenerierung sowie Sponsorennamen

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
