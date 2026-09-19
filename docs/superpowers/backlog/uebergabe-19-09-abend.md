# Übergabe, 19.09.2026 abends

Alles committet und gepusht; `main` ist der Stand. Die Mac-App ist in
`/Applications` installiert (Bau 575), iPad und iPhone tragen einen etwas
älteren Gerätebau.

## Was heute neu dazugekommen ist — an Möglichkeiten, nicht nur an Code

**Die Sitzung darf die Mac-App starten, fotografieren und probeweise senden**
(`CLAUDE.md`, Abschnitt zum Hausnetz). Damit lässt sich die Schreibtisch-
Oberfläche endlich selbst ansehen, statt sie beschreiben zu lassen.

**`xcrun devicectl` erreicht iPhone und iPad** — Bildschirmfoto, Installieren,
Starten. Ein **signierter Gerätebau** läuft ohne Xcode-Oberfläche:

    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'generic/platform=iOS' -derivedDataPath .build/geraet build
    xcrun devicectl device install app --device <UDID> \
          .build/geraet/Build/Products/Debug-iphoneos/MQTT-TC002-iOS.app

**Aber der Simulator bleibt der Normalfall**, und das iPhone sperrt nach 30
Sekunden — ein Bildschirmfoto danach ist schwarz. Vor jedem Zugriff auf ein
echtes Gerät wird gefragt.

**Die App darf mit den echten Uhren sprechen.** Der Auftraggeber: *„Das
Pixeluhren Universum ist nicht sicherheitskritisch. Kein Teil davon."* Die
Angaben stehen **nicht** im Repo — `defaults export cloud.eriks.mqtt-tc002 -`
liest sie aus der installierten Mac-App. Nichts davon in eine Datei, einen
Commit oder ein Papier.

**Ein Skill fasst die Arbeitsregeln:**
`.claude/skills/ui-umbau-pruefen/SKILL.md` — der Plattform-Kanon (was auf Mac,
iPad und iPhone als richtig gilt) und vier Prüfungen, jede aus einem Fehler
dieser Runde destilliert. Er lädt bei jeder Oberflächenarbeit.

## Was läuft

Ein Prüfdurchgang über iPhone und iPad, Zweig
`worktree-agent-ae8aab7dfdc599e24`. Er soll **finden und belegen**, nicht
reparieren — repariert wird an einer Stelle, sonst stoßen sich zwei an
denselben Dateien. Sein Bericht kommt vielleicht erst nach dem Sitzungsende;
dann liegt er im Aufgabenprotokoll dieser Sitzung.

Er arbeitet mit dem vom Auftraggeber bestückten **iPad Pro 13-inch (M5)**,
UDID `63C71893-4AA4-4CC4-8186-DC581AC1C37D` (zwei Uhren, beide Gattungen), und
dem **iPhone 17**, `DA0F3D5C-627E-4903-93E2-DF5351EB4F3A`.

## Offen, nach Gewicht

1. **Die Hilfe ist nur halb auf menschenfreundlichen Ton gebracht.** Einleitung
   und beanstandete Stellen sind umgeschrieben; `wolkenabgleich`,
   `blockwissen`, `verlaufEntstehung`, `randUndAbstand`, `fettUndGross`,
   `fehlerStille` tragen weiter Spezifikationston, und „Nutzlast", „Rahmen",
   „Platz/Slot" sind nirgends in einem Satz erklärt. Ein zweiter Durchgang von
   ähnlichem Umfang wie der erste.
2. **Das Slotbild überlebt keinen Neustart.** `slotInhalt` liegt im
   Arbeitsspeicher; dauerhaft merkt sich die App nur Regler. Ein Bild dauerhaft
   zu merken hiesse, das Format von `Slotgedaechtnis` zu ändern — das teilen
   App, Kurzbefehle und Kommandozeilenwerkzeug. **Entscheidung des
   Auftraggebers.**
3. **Das Einstellungs-Thema heisst „Broker" statt „MQTT-Broker".** Die
   Beanstandung traf die Hilfe *und* die Oberfläche; nur die Hilfe ist
   nachgezogen.
4. **Das Telefon hat keine Nutzlastzeile.** Wer dort einen langen Text
   schickt, sieht die Warnung vor einer grossen Nutzlast nie — kein Platz- und
   kein Bedienungsgrund, sondern eine fehlende Stelle.
5. **Umbenennen und Löschen einer 52 × 16 fehlt am Telefon.** Icons haben dort
   ein Mehr-Menü, Anzeigen nicht; am Schreibtisch haben beide eines.
6. **Zwei ⊗-Zeichen in der Mac-Seitenleiste** unter „Icons", auf einem
   Bildschirmfoto des Auftraggebers zu sehen. Ursache ungeklärt, nicht
   nachgestellt.
7. **Release 1.6** wartet weiter auf `./release.sh 1.6`.

## Was der Auftraggeber an Arbeitsweise verlangt hat

- **Bildschirmfoto statt Behauptung**, auch für einen selbst. Jeder
  Layoutfehler dieser Runde ist am Bild aufgefallen, keiner an einem Test.
- **Wächtertests werden umgeschrieben, nie abgeschwächt.** Die Prüfung dafür:
  `git diff <basis>..HEAD -- Tests/ | grep "^-" | grep XCTAssert` — erwartet:
  nichts.
- **Nach `ditto` die App neu starten**, sonst prüft er alten Code. Hat heute
  zweimal zu falschen Fehlerberichten geführt.
