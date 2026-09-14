# CLAUDE.md

Arbeitsregeln für dieses Repo. Was die App tut, steht in `README.md`; wie man
sie bedient, in ihrer Hilfe (⌘?); was das Gerät kann, in
`docs/tc002-protokoll.md`; was uns an dessen Firmware als Mangel aufgefallen
ist und bei einem Update nachzuprüfen wäre, in
`docs/firmware-beobachtungen.md`. Hier nur, was sonst verletzt würde.

- Logik gehört in `TC002Core` und wird dort getestet. Die Oberflächen bleiben
  dünn — reine SwiftUI-Views und Zustandsverdrahtung, keine Geschäftslogik.
- Sechs Ziele, und wer wohin gehört:
  `TC002Core` rechnet (Rastern, Laufschrift, Rahmenbau, MQTT-Bytes, Icons),
  `TC002Modell` hält den Zustand (`AppZustand`), `TC002Ansichten` sind
  plattformfreie SwiftUI-Bausteine für alle Oberflächen, `TC002App` ist die
  Mac-App, `TC002iOS` die iPhone-App, `TC002CLI` das Werkzeug. Die ersten
  drei kennen **keine** Plattform: kein `import AppKit`, kein `import UIKit`,
  kein `NSColor`, kein `UIColor`.
- **Zwei Oberflächenfamilien, nicht eine.** Das iPhone hat seine eigene
  (Senden als Wurzel, Titelmenü, schiebbare Formatpille, Blätter). Mac und —
  sobald es sie gibt — die iPad-Fassung teilen sich die Desktop-Oberfläche mit
  Seitenleiste. Was auf dem Telefon richtig ist, ist es dort selten.
- **Die Hilfe ist zweigeteilt.** Die Darstellung (`TC002Ansichten/Hilfe.swift`)
  und die Absätze, die vom Gerät unabhängig sind
  (`TC002Ansichten/HilfeInhalt.swift`), gelten für beide; `HilfeView` (Mac) und
  `HilfeiOS` (iPhone) setzen ihr Dokument daraus und aus eigenen Absätzen
  zusammen. Ein Absatz gehört nur dann nach `HilfeInhalt`, wenn er für **beide**
  Oberflächen wahr ist — Fenster, Seitenleiste, Inspektor, Finder, Malen und der
  Icon-Editor gibt es nur am Mac, Seitenwechsel und Scrolltempo stellt die
  iPhone-Fassung nicht ein, und sie warnt vor unbekannten Zeichen nicht.
  Ein zweiter Satz mit derselben Aussage wäre ein zweiter
  Übersetzungsschlüssel; deshalb Konstanten statt zweimal geschrieben.
- **Das Repo ist öffentlich.** Vor jedem Commit läuft
  `scripts/private-spuren.sh` als Haken (`core.hooksPath=.githooks`) und sucht
  in den vorgemerkten Zeilen nach Hausnetzangaben und Geheimnissen. Zweimal sind
  solche Angaben über Planpapiere unter `docs/superpowers/` hereingekommen —
  einmal zwei Adressen, einmal ein wörtlicher Geräteabzug mit MAC und
  WLAN-Namen. Das ist die Bauart, nicht ein Versehen: Wer misst, schreibt auf,
  was er sieht. **Messwerte gehören in die Doku, Kennungen nicht** — Adressen,
  MAC, Host- und Netznamen durch Platzhalter ersetzen.
  Ein frisch geklonter Baum hat den Haken nicht; einmalig
  `git config core.hooksPath .githooks`.
- Das echte Gerät und der Broker im Hausnetz sind in Tests tabu — ebenso in
  jeder Arbeit, die ein Agent ausführt. Ihre Adressen stehen in den
  Einstellungen der App, nicht hier; wer sie braucht, bekommt sie im Auftrag
  genannt. (Bis 12.09.2026 standen an dieser Stelle zwei Adressen, die längst
  nicht mehr stimmten — gefährlicher als keine, weil sie die falschen
  Maschinen schützten.) Dafür gibt es Doppelgänger: `URLProtocol` für die
  HTTP-Schnittstelle des Geräts, `NachrichtSendend` für das MQTT-Senden.
- **Ohne Gerät ausprobieren: die virtuelle Uhr.** `Virtuelleuhr` beantwortet
  die Anfragen einer Ulanzi-Werksfirmware als reine Funktion, `Uhrenserver`
  hängt sie an einen Port. In den Einstellungen ist sie ein Schalter; in Tests
  ist sie die Naht, an der sich der **ganze** HTTP-Weg prüfen lässt, ohne die
  Regel oben zu verletzen — die Testreihe hört sich selbst zu, auf
  `127.0.0.1` und einem Port, den sie selbst aufmacht. Wer etwas am Sendeweg
  ändert, hat dort einen Prüfstand.
- Die MQTT-Bytes sind gegen eine echte Aufzeichnung von `mosquitto_pub`
  geprüft (`MQTTPaketTests`). Dieser Test wird nicht abgeschwächt.
- Das Themen-Präfix nie hart eintragen, immer über `Geraet.themenPraefix()`
  ermitteln — es weicht vom eingestellten Präfix ab (siehe
  `docs/tc002-protokoll.md`, §2).
- Blockierende Netzaufrufe nie auf dem Hauptthread: `AppZustand` ist
  `@MainActor`-isoliert, die eigentlichen Aufrufe laufen in `Task.detached`.
- Je Uhr eine eigene MQTT-Client-Kennung, sonst trennt der Broker die
  vorherige Sitzung.
- Eigene Icons liegen unter
  `~/Library/Application Support/MQTT-TC002/Icons`, nie im App-Bündel — dort
  wären sie beim nächsten Bau weg, und unter `/Applications` ist der Ordner
  nicht beschreibbar.

## Sprachen

Deutsch ist die Entwicklungssprache: Der deutsche Wortlaut steht im Quelltext
und ist zugleich der Schlüssel. Eine fehlende Übersetzung fällt damit auf den
deutschen Satz zurück, nicht auf einen Schlüsselnamen.

- Was SwiftUI als `LocalizedStringKey` bekommt (`Text`, `Button`, `Label`,
  `.help` …), schlägt es selbst nach. Nichts zu tun.
- Alles, was als gewöhnliches `String` weitergereicht wird — Fehlertexte,
  Meldungen, Protokollzeilen, die Hilfebausteine, das Kommandozeilenwerkzeug —
  muss durch `lok(…)` bzw. `lokf(…, %@)`. Sonst bleibt es deutsch, ohne dass
  irgendetwas darauf hinweist.
- **Ein Ternär mit einem `String`-Zweig übersetzt nicht.**
  `.navigationTitle(mehrere ? name : "Senden")` zwingt SwiftUI in die
  `StringProtocol`-Überladung, und die schlägt nichts nach. Der Eintrag steht
  in `en.lproj` und wird nie gefunden. Abhilfe: `lok("Senden")` — dann ist die
  Übersetzung schon geschehen, bevor SwiftUI den Wert sieht.
- **Was in der Kurzbefehle-App steht, schlüsselt anders.** App Intents führen
  ihre `parameterSummary` im Bündel als `${text} …`, nicht als
  `\(\.$text) …`. Wer den Quelltext abschreibt, legt einen Schlüssel an, den
  nie jemand nachschlägt. Nachsehen in `Metadata.appintents/extract.actionsdata`
  des gebauten Bündels.
- **Keine Werte in den Schlüssel einsetzen.** `Text("Rand \(rand)")` trägt zur
  Laufzeit den Schlüssel `Rand %lld`, im Quelltext steht aber `Rand \(rand)` —
  gesucht wird dann etwas, das es nicht gibt. Stattdessen `lokf("Rand %d", rand)`.

Geprüft wird das nicht von Hand:

    python3 scripts/texte-sammeln.py --pruefen

meldet jeden sichtbaren Text ohne Übersetzung und jeden Eintrag, den es nicht
mehr gibt. Vor einer Veröffentlichung muss die Zeile `0 ohne Uebersetzung`
lauten; `cli.hilfe` steht dort zu Recht als überzählig, weil dieser eine
Schlüssel erfunden ist.

Texte, die über eine Variable nachgeschlagen werden (`lok(a.rawValue)`), kann
der Sammler nicht sehen. Sie stehen als `DYNAMISCH` von Hand im Skript.

Eine neue Sprache ist ein Ordner `Resources/Sprachen/<code>.lproj` mit einer
`Localizable.strings`; `build.sh` nimmt jeden solchen Ordner mit. Die
Gerätereferenz ist ein durchgehendes Dokument und wird am Stück übersetzt
(`docs/en/tc002-protocol.md`), nicht Satz für Satz.

Probieren, ohne etwas umzustellen:

    /Applications/MQTT-TC002.app/Contents/MacOS/TC002App -AppleLanguages '(en)'
    mqtttc002 -AppleLanguages '(en)' hilfe

## Das Kommandozeilenwerkzeug

`mqtttc002` liest die Einrichtung der App (`Einstellungen` im Kern) und
schreibt sie **nie** — zwei Schreiber auf denselben Schlüsseln wären ein
Wettlauf. Das Slotgedächtnis (`Slotgedaechtnis` im Kern, eine eigene Datei je
Uhr unter `Application Support/MQTT-TC002/Slots`) ist davon ausdrücklich
ausgenommen: Dorthin schreibt das Werkzeug nach einer erfolgreichen Sendung,
wie App und Kurzbefehle auch — es ist eben keine Einstellung, sondern eine
eigens dafür gebaute Datei mit mehreren Schreibern. Das gilt aber nur, wenn
`--name` einen der fünf festen Plätze trifft (`meldung1`…`meldung5`); die
Vorgabe `--name cli` ist keiner davon, und `mqtttc002 senden "…"` ohne
`--name` schreibt darum **nicht** ins Slotgedächtnis — kein Fehler im
Schreiber, sondern der fehlende Platzbezug. Gelesen wird die Datei an zwei
Stellen, und der Unterschied zwischen ihnen ist der Kern der Sache:

- **Was ein Block zeigt**, entscheidet `AppZustand.slotzustand(_:belegt:)`
  (`Sources/TC002Modell/AppZustand.swift`) für alle drei Ansichten gleich —
  **ohne** Prüfsummenvergleich. Fehlen mitgelesene Pixel, rechnet es das Bild
  aus dem gemerkten Stand neu; ein Block kann damit eine Erinnerung zeigen.
- **Ob die Regler übernommen werden**, entscheidet `slotWaehlen` in den beiden
  Sendeansichten (`Sources/TC002App/SendenView.swift`,
  `Sources/TC002iOS/SendeniOS.swift`) — nur bei mitgelesenen Pixeln *und*
  passender Prüfsumme, sonst hat seither jemand anderes auf den Platz
  geschrieben (Hilfe → Senden erklärt das aus Anwendersicht).

Geschrieben wird es an zwei Stellen — **weggeworfen** überall dort, wo ein
Platz geräumt oder mit etwas Unmerkbarem überschrieben wird
(`Slotgedaechtnis.vergessen(fuer:platz:)`). Bliebe die Erinnerung liegen,
zeigte der Block nach dem nächsten Start ohne Broker den Text, der dort längst
nicht mehr steht:

- ein gemaltes Bild (`MalenView` → `AppZustand.senden` mit `slotPlatz`, aber
  ohne `slotOptionen`) — es hat keine Regler, die sich merken ließen;
- eine erfolgreiche Löschung. `AppZustand.anzeigeGeloescht` ist der gemeinsame
  Rumpf für `AppZustand.loeschen`, `AnzeigenView` und `AnzeigeniOS`; der
  Kurzbefehl „Meldung nehmen" (`Kurzbefehle.swift`) kommt ohne `AppZustand`
  aus und ruft deshalb selbst;
- eine **leere** Nutzlast beim Mitlesen: Genau null Bytes heißen, die Anzeige
  wurde auf der Uhr entfernt — gleich von wem. Der Platz zählt dann wieder als
  frei (`anzeigeVergessen`), ohne auf eine erneute `customList` zu warten, die
  nicht belegt ist.

Gelöscht wird über einen Anzeigennamen; nur die fünf festen Plätze haben
überhaupt eine Erinnerung (`Meldungsplatz.platz(fuerName:)`), „cli" hat nichts
zu vergessen. Eine nicht zerlegbare Nutzlast (Lauf-GIF, Gerätschrift) ist der
Gegenfall: Sie löscht allein den Eintrag in `slotInhalt` und lässt die Belegung
stehen — dort liegt etwas, wir kennen es nur nicht.

`TC002Ansichten/Slotblock.swift` rührt das Gedächtnis nirgends an: Der Block
zeigt nur, was ihm gereicht wird. Das Werkzeug reist im Bündel mit
(`Contents/MacOS/mqtttc002`)
und wird über einen Verweis benutzt. Zwei Fallen, beide schon zugeschnappt:

- **`Bundle.main` ist über einen Verweis nicht das App-Bündel**, sondern der
  Ordner des Verweises. Fassungsnummer, Schriften und Übersetzungen fehlen dann
  still. Deshalb `Programmbuendel.eigenes`, nie `Bundle.main`.
- **`UserDefaults(suiteName:)` mit der eigenen Kennung liefert nichts.** Genau
  das passiert, wenn das Werkzeug unmittelbar im Bündel aufgerufen wird. Dort
  ist `.standard` das Richtige — siehe `Einstellungen.ablage`.
- **Eine mit `swift build` erzeugte Binärdatei ist ad hoc signiert**, ihre
  Kennung ein Hash über die Datei selbst — und damit ist sie für den
  Schlüsselbund nach jedem Bau ein anderes Programm. „Immer erlauben" gilt
  darum immer nur für den einen Bau. Abhilfe für eine Entwicklerfassung, die
  wirklich senden soll, ist einmaliges Nachsignieren mit derselben Identität,
  die `build.sh` nimmt:

      codesign --force -s "Developer ID Application: …" .build/debug/mqtttc002

  Seit `Einstellungen.kennwort` träge geworden ist, fragen nur noch der
  Trockenlauf von `senden` und das wirkliche Senden den Schlüsselbund
  überhaupt.

Die `Codable`-Form von `Uhr` ist ein Dateiformat: Die App schreibt sie, das
Werkzeug liest sie. Feldnamen ändern macht die Einstellungen einer laufenden
Installation unlesbar (`EinstellungenTests` hält das fest).

## Ein grüner Bau beweist nichts über das Bündel

`** BUILD SUCCEEDED **` sagt, dass übersetzt wurde — nicht, dass Schriften,
Icons, das App-Symbol, die Übersetzungen und die `LICENSE` im Programm gelandet
sind. Am
12.09.2026 fehlte im iOS-Bündel **jede einzelne** Ressource, weil `project.yml`
sie unter einem Schlüssel führte, den XcodeGen nicht kennt und stillschweigend
überliest. Neun Aufgaben und ebenso viele Durchsichten haben das nicht
gesehen; aufgefallen ist es erst am Gerät, an einer Vorschau in der falschen
Schrift.

Deshalb nach jedem Bau:

    sh scripts/buendel-pruefen.sh                    # iOS
    sh scripts/buendel-pruefen.sh erzeugt/mac/MQTT-TC002.app   # macOS

Zwei Eigenheiten, die dahinterstecken:

- In XcodeGen gehören Ressourcen unter `sources:` mit `buildPhase: resources`.
  Ordner, die als Ordner im Bündel liegen sollen — `Icons`, `Schriften` —
  brauchen zusätzlich `type: folder`, sonst landen ihre Dateien einzeln in der
  Wurzel und niemand findet sie.
- **SwiftPM übersetzt Bildkataloge nur, wenn Xcode der Bauherr ist.** Über den
  nativen Bauweg, den `build.sh` benutzt, wird `.xcassets` roh kopiert — kein
  `actool`, kein `Assets.car`, ein leerer Rahmen zur Laufzeit. `build.sh` holt
  den Übersetzungsschritt deshalb selbst nach.

## Fassungsnummer

Nicht im Quelltext eintragen. `build.sh` nimmt sie aus `TC002_VERSION` oder vom
jüngsten Tag, die Baunummer ist die Zahl der Commits. `release.sh <fassung>`
setzt die Variable, bricht bei geändertem Arbeitsbaum ab und prüft hinterher
die Info.plist gegen sein Argument.

## Die iOS-Fassung

`project.yml` beschreibt das Xcode-Projekt; `xcodegen generate` erzeugt es.
Die `.xcodeproj` wird **nicht** eingecheckt — wer eine Quelldatei hinzufügt,
ändert die YAML und erzeugt neu, statt in erzeugtem XML zu schneiden.

**Sie bleibt in der Wurzel, und das ist kein Versäumnis.** Alles andere
Erzeugte liegt unter `erzeugt/`; für das Xcode-Projekt wurde dasselbe am
14.09.2026 versucht und wieder zurückgenommen. `xcodegen generate --project
erzeugt/ios` legt es zwar dort ab, rechnet dabei aber nicht alles um: Der
Paketpfad (`packages.TC002.path`) und die Bauvariable
`CODE_SIGN_ENTITLEMENTS` werden gegen `$(SRCROOT)` aufgelöst, also gegen das
erzeugte Projekt, und ein Ordnerverweis (`type: folder`, also `Icons` und
`Resources/Schriften`) behält `sourceTree = SOURCE_ROOT` mit unverändertem
Pfad — den relativiert XcodeGen gar nicht. Jede dieser Stellen ließe sich mit
einem `../..` erschlagen, aber dann gilt die Beschreibung nur noch für genau
einen Aufruf, und der nächste `xcodegen generate` ohne `--project` baut ein
Projekt, das nicht übersetzt. Die zwei Einträge in der Wurzel
(`MQTT-TC002-iOS.xcodeproj`, `MQTT-TC002-iOS.entitlements`) sind beide
ignoriert und in einem frischen Klon ohnehin nicht da.

    brew install xcodegen        # einmalig
    xcodegen generate
    xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
               -destination 'generic/platform=iOS Simulator' build

Aufs Gerät kommt sie aus Xcode. `TC002App` und `TC002CLI` binden AppKit ein und
sind nur unter macOS übersetzbar; das iOS-Ziel hängt ausschließlich an den
Bibliotheken `TC002Core`, `TC002Modell` und `TC002Ansichten` (die drei Produkte
in `project.yml`).

## Nach /Applications installieren

**Nicht** mit `rm -rf` und `cp` ersetzen. Die Freigabe „Lokales Netzwerk" haengt
bei macOS am Programm; ein so ausgetauschtes Buendel gilt leicht als ein anderes.
Die Freigabe steht dann weiter auf „erteilt", greift aber nicht mehr, und
nachgefragt wird auch nicht — die App erreicht Uhr und Broker einfach nicht.
Am 11.09.2026 genau so passiert, nach dreimaligem Austausch.

Stattdessen an Ort und Stelle ersetzen, das erhaelt die Identitaet:

    ditto erzeugt/mac/MQTT-TC002.app /Applications/MQTT-TC002.app

Und die App moeglichst nur von **einem** Ort aus starten. Zwei Kopien mit
derselben Buendelkennung — etwa `/Applications` und `erzeugt/mac/` — verwirren die
Rechteverwaltung zusaetzlich.

Ist es doch passiert: Systemeinstellungen > Datenschutz & Sicherheit >
Lokales Netzwerk > den Eintrag aus- und wieder einschalten.
