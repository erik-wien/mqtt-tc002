# UX-Runde 19.09.2026 — Uebersicht und Arbeitsregeln

**Anlass.** Der Auftraggeber, 19.09.2026, zu zwei Bildschirmfotos (iPhone
Senden, iPad Senden): *„die ui/ux ist schon ziemlich ok, aber ich zweifle noch,
ob sie wirklich professionell aussieht. vor allem am iphone."* Farbwahl ist
ausdruecklich ausgenommen.

Sechs Befunde, je ein Papier, nach Gewicht sortiert. Die ersten zwei machen den
Eindruck „unfertig"; die anderen sind Feinschliff.

| Nr. | Papier | Kern |
|---|---|---|
| 1 | `iphone-senden-eine-liste.md` | Loch in der Mitte: Liste in Rolle mit fester Hoehe |
| 2 | `verlaufszeilen-inhalt-zuerst.md` | Zeilen zeigen Zeit und Nummer statt Inhalt; Doppelte |
| 3 | `slot-loeschen-ohne-dauerbadge.md` | Rote ✗-Badges wie im Wackelmodus |
| 4 | `vorschau-ohne-kleingedrucktes.md` | Zwei Zeilen Disclaimer unter der Vorschau |
| 5 | `formatpille-schrift-als-menue.md` | Schriftname als Wort, Pille endet abgeschnitten |
| 6 | `kleinigkeiten-belegt-und-titel.md` | Chip „belegt", Uhrenname im Titel |

## Arbeitsregeln fuer jedes Papier

Sie gelten zusaetzlich zu `CLAUDE.md`, das zuerst zu lesen ist.

**Ein Papier, ein Commit.** Kein Buendeln, kein „wo ich schon dabei bin".
Jeder Commit laesst `swift test` gruen, `python3 scripts/texte-sammeln.py
--pruefen` bei `0 ohne Uebersetzung` (das eine `cli.hilfe` bleibt
ueberzaehlig), und beide Ziele bauen:

    ./build.sh && sh scripts/buendel-pruefen.sh erzeugt/mac/MQTT-TC002.app
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'generic/platform=iOS Simulator' build

**Ansehen, nicht glauben.** Jedes Papier betrifft Aussehen. Vor dem Commit
das Ergebnis im Simulator ansehen und das Bild dem Auftraggeber zeigen:

    xcrun simctl boot "iPhone 17"
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'platform=iOS Simulator,name=iPhone 17' build
    xcrun simctl install booted <Pfad zur .app unter DerivedData/…/Debug-iphonesimulator>
    xcrun simctl launch booted cloud.eriks.mqtt-tc002
    xcrun simctl io booted screenshot <scratchpad>/iphone.png

Am Mac: `ditto erzeugt/mac/MQTT-TC002.app /Applications/MQTT-TC002.app`, nie
`rm -rf` und `cp` (CLAUDE.md, „Nach /Applications installieren").

**Waechtertests.** `Tests/TC002AnsichtenTests` haelt Schreibweisen im
Quelltext fest (`EinblendtextGegenstueckTests`, `KnopfstilTests`,
`EditorbereichTests`, `LoeschzeichenTests` …). Faellt einer, ist zu
entscheiden, ob er die Zusicherung oder nur die alte Schreibweise prueft; im
zweiten Fall wird er auf die neue Zusicherung umgeschrieben, nicht geloescht
und nicht abgeschwaecht. Ein Test, der eine Anzahl zaehlt (`.help(` in einer
Datei), bekommt die neue Anzahl **und** die neue Aufzaehlung in seiner
Meldung.

**Uebersetzung.** Jeder neue sichtbare Text bekommt seinen Eintrag in
`Resources/Sprachen/en.lproj/Localizable.strings`; jeder entfallene wird dort
gestrichen. Ein Ternaer mit `String`-Zweig uebersetzt nicht (`lok(…)`).

**Kommentare.** Verhalten und Entscheidung samt Begruendung, zwei Saetze.
Keine Datumsgeschichte, keine Erzaehlung, keine Fettung (CLAUDE.md, „Was in
einen Kommentar gehoert").

**Hilfe.** Was sich in der Bedienung aendert, aendert sich in der Hilfe
(`HilfeView.swift` Mac/iPad, `HilfeiOS.swift` iPhone, gemeinsames in
`HilfeInhalt.swift`) und in deren Uebersetzung.

**Dieselbe App ueberall.** Ein Unterschied zwischen Telefon und Schreibtisch
braucht einen Grund aus Bedienung (Finger gegen Zeiger) oder Platz und steht
als Kommentar an der Stelle.

**Kennungen.** Das Repo ist oeffentlich. Keine Hostnamen, Praefixe oder
Adressen aus dem Hausnetz in Commit, Kommentar oder Papier — der Haken
`scripts/private-spuren.sh` weist solche Commits ab.
