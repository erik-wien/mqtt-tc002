---
name: ui-umbau-pruefen
description: Use when reworking the user interface of mqtt-tc002 (Pixel Clock Messenger) — writing a rework brief, delegating UI work to subagents, or reviewing the result. Four checks that caught real defects only after they reached the device.
---

# Oberflächenumbau prüfen

Vier Prüfungen für Umbauten an Mac-, iPad- und iPhone-Oberfläche dieses Repos.
Sie stehen hier, weil jede von ihnen einen Fehler abgefangen hätte, der
stattdessen erst auf dem Gerät des Auftraggebers aufgefallen ist.

Gelten zusätzlich zu `CLAUDE.md`. Wer ein Papier nach
`docs/superpowers/backlog/` schreibt oder eines abarbeitet, geht sie durch.

## 1. Das Papier an beiden Rändern prüfen

Eine Entscheidung, die für den Schreibtisch richtig ist, kann auf dem Telefon
ins Leere fallen — **weil es dort den Ort nicht gibt, auf den sie verweist.**

„52 × 16-Anzeigen gehören nicht in die Iconauswahl, sondern in den Bereich
Icons" war am Mac richtig und am iPhone sinnlos: Den Bereich Icons gab es
dort nicht.

Vor dem Schreiben eines Papiers je Oberfläche fragen: Gilt die Entscheidung
hier, und **existiert der Ort, auf den sie zeigt?** Wenn nein, gehört er ins
Papier oder die Entscheidung ist eine andere.

## 2. Maße und Farben aus der Bedingung, nicht aus einer Annahme

Ein Wert, der aus einer Konstante kommt, wo eine Bedingung gilt, ist ein
Fehler — er baut, er übersetzt, jeder Test bleibt grün, und man sieht ihn
erst am Bild.

Vorgefallen, dreimal an einem Tag:

- Kantenlänge fest `6` statt aus der verfügbaren Breite: Der Geräterahmen lief
  links und rechts aus dem Sichtfeld, sichtbar blieb nur das schwarze Feld.
- Höhe aus Kantenlänge `6` gerechnet, gezeichnet wurde kleiner: eine leere
  Bahn über und unter der Uhr.
- Der Platz fürs Zubehör gar nicht abgezogen: Der Abspielknopf stand
  außerhalb des Sichtfelds.

Dasselbe für **Farbe aus Anwenderdaten auf einer Systemfläche**: Der
Verlaufstext stand in der Farbe, in der er geschickt wurde — weiß auf weißem
Grund war er unsichtbar, die Zeile sah leer aus. Anwenderfarbe gehört in ein
eigenes Element (Punkt, Kachel), nicht in die Schriftfarbe einer Liste.

Prüffrage: **Woher kommt diese Zahl, und was passiert, wenn die Bedingung
kleiner ist als sie?**

## 3. Kein Commit an einer Layoutstelle ohne Bild

Auch für einen selbst, nicht nur für Agenten. Jeder Layoutfehler dieser Runde
ist ausschließlich am Bildschirmfoto aufgefallen; keiner an einem Test.

    xcrun simctl boot <UDID>
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath .build/ios build
    xcrun simctl install <UDID> .build/ios/Build/Products/Debug-iphonesimulator/MQTT-TC002-iOS.app
    xcrun simctl launch <UDID> cloud.eriks.mqtt-tc002
    xcrun simctl io <UDID> screenshot <scratchpad>/x.png

`simctl` kann nicht tippen. Um in einen Zustand zu kommen, darf ein
Anfangswert **vorübergehend** gepatcht werden — Marke `// SCHAUBILD`, vor
jedem Commit zurücknehmen, `grep -rn SCHAUBILD Sources/` muss leer sein.

Die **Mac-App nicht starten**: Sie liest die echte Einrichtung des Rechners
und erreicht damit Uhr und Broker im Hausnetz (`CLAUDE.md`). Die
Schreibtisch-Oberfläche ist am iPad zu belegen.

Und: `ditto` tauscht das Bündel, ein **laufendes** Programm merkt davon
nichts. Nach dem Installieren gehört der Hinweis dazu, die App neu zu
starten — sonst prüft der Auftraggeber alten Code.

## 4. Reichweite nach Anliegen, nicht nach Bereich

Wird ein **Bedienmuster** ersetzt, gilt das für jede Stelle, die es trägt —
nicht nur für den Bereich, in dem es aufgefallen ist.

„Kein dauerhaftes ⊗ mehr am Slotblock" traf die beiden Sendeansichten und
ließ die Blockreihe im Icon-Editor zurück: zwei Blockreihen in derselben App,
verschieden zu bedienen.

Vor dem Schneiden eines Papiers: `grep -rn "<das Muster>" Sources/` und **alle**
Fundstellen ins Papier nehmen. Danach hält ein Wächtertest die Zusicherung
für alle Stellen, nicht für eine.

## Beim Prüfen fremder Arbeit

- **Nicht dem Bericht glauben, sondern den Bildern** — und die Abnahmepunkte
  des Papiers einzeln dagegenhalten.
- **Wächtertests sind der teuerste Ort für einen Fehler.** Je geänderten Test
  entscheiden: Prüft er die *Zusicherung* oder nur die *alte Schreibweise*?
  `git diff <basis>..HEAD -- Tests/ | grep "^-" | grep XCTAssert` zeigt jede
  entfernte Zusicherung auf einen Blick.
- **Umfang mechanisch prüfen:** `git diff --name-only`, dann auf verbotene
  Dateien und auf Patch-Reste sehen.
