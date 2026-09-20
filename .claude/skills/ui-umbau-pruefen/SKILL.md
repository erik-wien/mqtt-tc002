---
name: ui-umbau-pruefen
description: Use whenever working on the user interface of mqtt-tc002 (Pixel Clock Messenger) — writing or changing any SwiftUI view for Mac, iPad or iPhone, writing a rework brief, delegating UI work to subagents, or reviewing the result. Holds the per-platform canon this project settled on and four checks that caught real defects only after they reached the device.
---

# Oberfläche bauen und prüfen

Gilt für jede Arbeit an einer SwiftUI-Ansicht dieses Repos — nicht nur für
große Umbauten. Zusätzlich zu `CLAUDE.md`, das die Architektur, die Sprachen
und die Kommentarregel setzt.

Zwei Teile: **der Kanon** (was auf welcher Oberfläche richtig ist) und **die
vier Prüfungen** (was schiefgeht, wenn man es nicht nachsieht).

---

## Teil 1 — Der Kanon je Plattform

Erarbeitet am Gerät, jede Zeile ist einmal falsch gewesen.

### Gemeinsam

- **Dieselbe App, überall dasselbe Können.** Ein Unterschied braucht einen
  Grund aus **Bedienung** (Finger gegen Zeiger) oder **Platz**. „Das ist eben
  das Telefon" ist keiner. Wer eine Funktion nur an einer Stelle einbaut, hat
  die Arbeit halb getan.
- **Systembausteine, keine Nachbauten** — und wo doch, steht die Begründung am
  Nachbau und in `CLAUDE.md` (dort stehen die zwei, die es gibt).
- **Gesten aus dem System, nicht selbstgebaut.** Blättern ist
  `.scrollTargetBehavior(.paging)` mit `.scrollPosition`. Eine eigene Geste,
  die erst beim Loslassen überblendet, klebt nicht am Finger — wörtlich
  beanstandet, und das Gefühl war der ganze Punkt.
- **Alles, was neben Text sitzt, misst `@ScaledMetric`.** Eine feste Zahl
  hebelt die Textgrößen-Einstellung aus; bei „Größere Schrift" bricht der Name
  um, während die Kachel bleibt.
- **Eine Liste, nicht zwei nebeneinander.** Eine `List` in einer `ScrollView`
  bekommt keine Höhe, braucht deshalb eine feste, und eine feste Höhe mit
  wenigen Zeilen verteilt den Rest als Leere.
- **Ein Fehler, an dem niemand etwas berichtigen kann, ist kein Dialog.** Eine
  stumme Uhr bekommt ein Zeichen an der Uhr. Dialoge bleiben dem vorbehalten,
  was jemand richtigstellen kann — falsche Adresse, unerwartete Antwort.
- **Erklärtexte: ein Satz.** Was länger ist, gehört hinter ein `Hilfezeichen`
  (?) oder in die Hilfe. Zwei Absätze unter einem Schalter heißen, dass der
  Schalter falsch heißt oder am falschen Ort steht.
- **Erklärender Text steht nicht in der Oberfläche.** Wörtlich, am
  20.09.2026: *„Der Erklärungstext gefällt mir nicht, die macht die UI unrund
  und User, die sich auskennen, werden unnötig genervt. Bitte weglassen, wenn
  die Hilfe reicht, ein klickbares (i) mit Einblendhilfe oder eine
  Fehlermeldung, wenn der User was versucht zu machen, was nicht geht."* Drei
  zulässige Formen, in dieser Reihenfolge: nichts (die Hilfe trägt es), ein
  `Hilfezeichen`, eine Fehlermeldung an der Handlung. **Die Ausnahme:** Ein
  Satz darf stehen, wenn er eine Aussage über den **konkreten Zustand**
  macht — der Name der geladenen Grafik, die angesehene Uhr, was auf einem
  Platz liegt. Nicht, wie etwas funktioniert.
- **Keine Rechtfertigung, wo nichts im Weg steht.** Wörtlich verlangt:
  *„weniger direkte Rechtfertigungsversuche, wenn keine direkte Gefahr
  besteht. Gerne aber mehr (?)"*. Sichtbar bleibt, was jemanden aufhält — ein
  gesperrter Knopf sagt daneben, warum. Alles andere, was bloß erklärt, wie
  etwas zustande kommt, wandert hinter das Zeichen. Die Zahl steht da, der
  Grund dahinter.
- **Apples HIG ist der Maßstab, auch über einem Wunsch.** Wörtlich:
  *„Alle Angaben unter dem Vorbehalt, dass ich möglichst nahe am Apple HIG
  bleiben will."* Wo ein Wunsch ein Zeichen oder eine Form beschreibt, für die
  Apple schon eine hat, gilt Apples — und die Antwort sagt, welche das ist.
  Ein „↕" für ein Einblendmenü heißt `chevron.up.chevron.down`.
- **Keine Zahl ohne Bezugsgröße.** Wörtlich: *„Die einzige Engstelle ist die
  Uhr selbst … Aber iCloud und App ist das komplett egal."* Kilobyte in der
  Oberfläche beunruhigen, solange niemand sagen kann, wovon sie ein Teil sind
  — und die Werksfirmware gibt weder freien Speicher noch eine Grenze heraus.
  Was bleibt, ist eine Aussage über die Sache selbst: die Zahl der
  Einzelbilder, nicht die der Bytes.
- **Keine typografischen Investitionen.** Ausdrückliche Projektentscheidung:
  Die Gerätschriften sind vom Aussterben bedroht, sobald AWTRIX NG übernimmt.

### Mac

- **Knöpfe tragen Wörter.** Ein nacktes ✗/✓-Paar ist die Sprache der
  Fingerbedienung und sieht am Mac fremd aus. Zurück ist ein Winkel
  (`chevron.left`), die Haupthandlung ein beschrifteter Knopf.
- **Blätter: Knöpfe unten rechts**, Abbrechen links davon, mit
  `.keyboardShortcut(.cancelAction)` und `.defaultAction`. Der `Blatt`-Rahmen
  macht das; kein Blatt baut seine Zeile selbst.
- **Zerstörendes nur unter dem Zeiger.** Ein Löschzeichen am Block erscheint
  bei `onHover`, nie dauerhaft — dauerhaft liest es sich als Wackelmodus und
  verdeckt das Motiv. Zusätzlich das Kontextmenü.
- **Einstellungen sichern beim Ändern.** Ein Knopf „Sichern" ist ein
  Web-Formular und lässt den Anwender raten, ob die Schalter daneben auch
  erst nach einem Druck gelten.
- **Ein gefasstes Feld schreibt von links.** In einer `LabeledContent`-Zeile
  erbt es sonst die rechtsbündige Lage des *Werts*, und der Text läuft unter
  das Löschzeichen.

### iPad

- Teilt sich die Desktop-Oberfläche mit dem Mac (Seitenleiste, Inspektor) —
  der Unterschied liegt in der **Anordnung**, nicht im Umfang.
- **Runde Zeichen über dem Inhalt**, wie Fotos sie über dem bearbeiteten Bild
  hat: ✗ und ✓ in Kreisen von mindestens 44 Punkten.
- **`.help()` ist unsichtbar.** Am Zeiger erscheint es, am Finger nie. Jede
  Auskunft, die nur dort steht, braucht ein sichtbares Gegenstück — ein (?)
  mit Popover oder einen sichtbaren Namen. `EinblendtextGegenstueckTests`
  hält das für jede Datei fest.
- **`TabView` zeichnet iPadOS als schwebende Leiste unten** — dort gehört die
  Wahl der App, nicht die eines Bereichs innerhalb eines Bereichs. Für
  Abschnitte innerhalb einer Ansicht: `Picker` mit `.segmented` darüber.
- **`.bordered` färbt die Beschriftung in der Akzentfarbe**, anders als am
  Mac. Wo dunkle Schrift gewollt ist, gehört sie ausdrücklich dazu.

### iPhone

- **Senden ist die Wurzel.** Andere Bereiche sind Blätter, keine Reiter.
  Wird das geändert, ändert sich eine in `CLAUDE.md` festgehaltene
  Entscheidung mit.
- **Einstellungen sind eine Liste von Themen mit Unterseiten**, wie die
  Einstellungen-App — nicht Reiter.
- **Blätter: Abbrechen links, Bestätigen rechts** in der Titelleiste.
- **Werte rechtsbündig ohne Fassung**, wie in den Systemeinstellungen; die
  Beschriftung des Feldes ist dort der Platzhalter.
- **Kein dauerhaftes Löschzeichen.** Am Finger ist das Kontextmenü der Weg;
  es gibt keinen Zeiger, unter dem etwas erscheinen könnte.
- **Kleine Pillen statt großer Kreise** — der Gegenpol zum iPad.
- **Was oben steht, bleibt oben.** Die Gerätevorschau rollt nicht mit der
  Liste weg: Sie beantwortet „was steht gleich auf der Uhr" und muss sichtbar
  bleiben, während man im Verlauf blättert.
- **Die Eingabetaste schickt** (`.submitLabel(.send)`); es gibt keinen
  Sendeknopf, an dem eine Rückmeldung hängen könnte — sie steht dort, wo
  sonst der Fortschrittsdreher steht.

---

## Teil 2 — Die vier Prüfungen

Jede hält einen Fehler fest, der erst auf dem Gerät des Auftraggebers
aufgefallen ist.

### 1. Die Entscheidung an beiden Rändern prüfen

Eine Entscheidung, die für den Schreibtisch richtig ist, kann auf dem Telefon
ins Leere fallen — **weil es dort den Ort nicht gibt, auf den sie verweist.**

„52 × 16-Anzeigen gehören nicht in die Iconauswahl, sondern in den Bereich
Icons" war am Mac richtig und am iPhone sinnlos: Den Bereich Icons gab es
dort nicht.

Je Oberfläche fragen: Gilt die Entscheidung hier, und **existiert der Ort,
auf den sie zeigt?** Wenn nein, gehört er dazu oder die Entscheidung ist eine
andere.

### 2. Maße und Farben aus der Bedingung, nicht aus einer Annahme

Ein Wert aus einer Konstante, wo eine Bedingung gilt, ist ein Fehler — er
baut, er übersetzt, jeder Test bleibt grün, und man sieht ihn erst am Bild.

- Kantenlänge fest `6` statt aus der Breite: Der Geräterahmen lief seitlich
  aus dem Sichtfeld, sichtbar blieb nur das schwarze Feld.
- Höhe aus Kantenlänge `6`, gezeichnet wurde kleiner: eine leere Bahn über
  und unter der Uhr.
- Platz fürs Zubehör nicht abgezogen: Der Abspielknopf stand außerhalb.
- Ein Maß für alle Gattungen: Eine AWTRIX NG (32 Pixel) blieb halb so groß
  wie eine TC002 (52). **Gezeigt wird das Gerät, nicht das Pixel.**

Dasselbe für **Anwenderfarbe auf einer Systemfläche**: Der Verlaufstext stand
in der Farbe, in der er geschickt wurde — weiß auf weiß war unsichtbar, die
Zeile sah leer aus. Anwenderfarbe gehört in ein eigenes Element (Punkt,
Kachel), nicht in die Schriftfarbe einer Liste.

Prüffrage: **Woher kommt diese Zahl, und was passiert, wenn die Bedingung
kleiner ist als sie?**

Verwandt: Ein `Spacer` **innerhalb** eines Bausteins macht ihn gierig. Stehen
zwei gierige Geschwister in einer Zeile, teilen sie sich den Platz, und eine
Breitenprobe (`ViewThatFits`) bekommt nur die Hälfte vorgeschlagen. Der
Zwischenraum gehört dem Aufrufer.

### 3. Kein Commit an einer Layoutstelle ohne Bild

Auch für einen selbst, nicht nur für Agenten. **Jeder** Layoutfehler dieser
Runde ist am Bildschirmfoto aufgefallen, keiner an einem Test.

    xcrun simctl boot <UDID>
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'platform=iOS Simulator,id=<UDID>' -derivedDataPath .build/ios build
    xcrun simctl install <UDID> .build/ios/Build/Products/Debug-iphonesimulator/MQTT-TC002-iOS.app
    xcrun simctl launch <UDID> cloud.eriks.mqtt-tc002
    xcrun simctl io <UDID> screenshot <scratchpad>/x.png

Ausschnitt vergrößern: `sips -c <h> <b> --cropOffset <y> <x> a.png --out b.png`.

`simctl` kann nicht tippen. Um in einen Zustand zu kommen, darf ein
Anfangswert **vorübergehend** gepatcht werden — Marke `// SCHAUBILD`, vor
jedem Commit zurücknehmen, `grep -rn SCHAUBILD Sources/` muss leer sein.
Der Startbereich steht im `init` von `SchreibtischView`, nicht an der
Eigenschaft.

**Die Mac-App darf die Sitzung selbst starten und fotografieren** — seit
19.09.2026, samt Testmeldungen an die echten Uhren; die Bedingungen stehen in
`CLAUDE.md` (aufräumen, virtuelle Uhr zuerst, keine echten Adressen im Repo).
**Subagenten dürfen es nicht**; für sie bleibt die Schreibtisch-Oberfläche am
iPad zu belegen.

    open -a /Applications/MQTT-TC002.app
    screencapture -x <scratchpad>/mac.png      # Bildschirmfoto

Das Bild bleibt im Scratchpad. Es zeigt Adressen und Präfixe aus dem
Hausnetz.

**Das echte iPhone und iPad erreicht `xcrun devicectl`** (Bildschirmfoto,
Installieren, Starten) — aber **erst nach Rückfrage, jedes Mal**, und nur für
das, was der Simulator nicht zeigen kann.

**Der Simulator ist der Normalfall**, aus drei Gründen:

- Nur dort lässt sich ein Anfangswert patchen, um an einen Zustand zu kommen.
- **Das iPhone sperrt nach 30 Sekunden.** Ein Bildschirmfoto danach ist
  schwarz, und `devicectl` kann das Gerät nicht wecken — bauen, installieren,
  starten und fotografieren dauert länger als das.
- Ein Bildschirmfoto des Geräts zeigt, was gerade offen ist, und geht den
  Auftraggeber an.

    xcrun devicectl list devices
    xcrun devicectl device capture screenshot --device <UDID> --destination <pfad>.png

Nach `ditto` gehört der Hinweis dazu, die App **zu beenden und neu zu
starten** — ein laufendes Programm merkt vom getauschten Bündel nichts, und
der Auftraggeber prüft sonst alten Code.

### 4. Reichweite nach Anliegen, nicht nach Bereich

Wird ein **Bedienmuster** ersetzt, gilt das für jede Stelle, die es trägt.

„Kein dauerhaftes ⊗ mehr am Slotblock" traf die beiden Sendeansichten und
ließ die Blockreihe im Icon-Editor zurück: zwei Blockreihen in derselben App,
verschieden zu bedienen.

Vor dem Schneiden: `grep -rn "<das Muster>" Sources/`, **alle** Fundstellen
aufnehmen, und danach hält ein Wächtertest die Zusicherung für alle Stellen.

---

## Teil 3 — Beim Prüfen fremder Arbeit

- **Nicht dem Bericht glauben, sondern den Bildern** — und die Abnahmepunkte
  einzeln dagegenhalten.
- **Wächtertests sind der teuerste Ort für einen Fehler.** Je geänderten Test
  entscheiden: Prüft er die *Zusicherung* oder nur die *alte Schreibweise*?
  Ein Test, der eine Zusicherung stillschweigend aufgegeben hat, kostet mehr
  als der Fehler, den er decken sollte.

      git diff <basis>..HEAD -- Tests/ | grep "^-" | grep XCTAssert

  zeigt jede entfernte Zusicherung auf einen Blick. Erwartet: nichts.
- **Umfang mechanisch prüfen:** `git diff --name-only` gegen die verbotenen
  Dateien, und `grep -rn "SCHAUBILD\|TODO\|FIXME" Sources/` gegen Reste.
- **Ein Ausschnitt-Wächter braucht einen Anker, der kein Kommentar ist** —
  die Testhelfer streichen Kommentare vor dem Suchen.
