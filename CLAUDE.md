# CLAUDE.md

Arbeitsregeln für dieses Repo. Was die App tut, steht in `README.md`; wie man
sie bedient, in ihrer Hilfe (⌘?); was das Gerät kann, in
`docs/tc002-protokoll.md`; was uns an dessen Firmware als Mangel aufgefallen
ist und bei einem Update nachzuprüfen wäre, in
`docs/firmware-beobachtungen.md`. Hier nur, was sonst verletzt würde.

- **Die App heißt „Pixel Clock Messenger", das Repo weiter `mqtt-tc002`.**
  Geändert wurde nur, was angezeigt wird (`CFBundleName`,
  `CFBundleDisplayName`, „Über …", die Hilfe, der Kopf des Werkzeugs).
  **Nicht** geändert und nicht zu ändern: die Bündelkennung
  `cloud.eriks.mqtt-tc002` (App-Store-Eintrag, iCloud-Container,
  Schlüsselbund), der Datenordner `Application Support/MQTT-TC002/` (dort
  liegen Icons, Bilder, Slots), der Dateiname `MQTT-TC002.app` (die Freigabe
  „Lokales Netzwerk" hängt am Programm) und der Befehl `mqtttc002`.
- Logik gehört in `TC002Core` und wird dort getestet. Die Oberflächen bleiben
  dünn — reine SwiftUI-Views und Zustandsverdrahtung, keine Geschäftslogik.
- Sechs Ziele, und wer wohin gehört:
  `TC002Core` rechnet (Rastern, Laufschrift, Rahmenbau, MQTT-Bytes, Icons),
  `TC002Modell` hält den Zustand (`AppZustand`), `TC002Ansichten` sind
  plattformfreie SwiftUI-Bausteine für alle Oberflächen, `TC002App` ist die
  Mac-App, `TC002iOS` die iPhone-App, `TC002CLI` das Werkzeug. Die ersten
  drei kennen **keine** Plattform: kein `import AppKit`, kein `import UIKit`,
  kein `NSColor`, kein `UIColor`. Eine Ausnahme braucht einen Grund, und der
  gehört an die Stelle geschrieben. Bisher gibt es genau eine:
  `TC002Ansichten/Webansicht.swift` — SwiftUI hat bis macOS 26 keine eigene
  Webansicht, und `WKWebView` ist nur über `NSViewRepresentable` bzw.
  `UIViewRepresentable` einzusetzen. Der Unterschied betrifft vier Zeilen und
  bleibt in dieser Datei.
- **Dieselbe App, überall dasselbe Können — Unterschiede brauchen einen
  Grund.** Was die eine Oberfläche kann, kann die andere auch. Ein Unterschied
  ist nur zulässig, wenn ihn die **Bedienung** (Maus und Zeiger gegen Finger)
  oder das **Platzangebot** erzwingt; „das ist eben das Telefon" ist keiner.

  Zwei Oberflächenfamilien gibt es weiterhin, aber sie unterscheiden sich in
  der **Anordnung**, nicht im Umfang: Das iPhone hat Senden als Wurzel,
  Titelmenü, schiebbare Formatpille und Blätter; Mac und iPad teilen sich die
  Desktop-Oberfläche mit Seitenleiste und Inspektor.

- **Bedienelemente so, wie Apple sie festlegt** — ein eigener Nachbau braucht
  eine Begründung, und die gehört an den Nachbau geschrieben. Bisher gibt es
  zwei. Der erste ist `Farbkreis` (`TC002Ansichten`). Das Systemfeld ist bei weißer
  Farbe auf hellem Grund nicht mehr als Bedienelement zu erkennen, und
  SwiftUI lässt sein Aussehen nicht ändern — `ColorPicker` hat kein Gegenstück
  zu `buttonStyle` oder `pickerStyle` (im SDK nachgesehen), und sein `label`
  steht neben dem Feld statt darin. Der Kreis ist deshalb gezeichnet, die
  Systempalette darunter bleibt der Auslöser.

  Der zweite ist die Kapsel in `Filterleiste`. Größe und Bewegung sind zwei
  Filter über demselben Bestand und gehören sichtbar zusammen, aber nicht in
  **einen** `Picker`: Ein Segment „bewegte" höbe die Größenwahl auf, sobald
  man es wählt, und „8 × 8 **und** bewegt" wäre nicht mehr zu filtern. Zwei
  Bedienelemente nebeneinander lasen sich dagegen als zwei Sachen. Die Form —
  eine Kapsel, innen durch einen Strich geteilt — ist die, die Fotos für
  gruppierte Werkzeuge über dem Bild benutzt. Was der `Picker` mitbrachte,
  steht dort von Hand: die Wahl als `.isSelected` für die Sprachausgabe und je
  Segment ein eigener Einblendtext.
- **Die Hilfe ist zweigeteilt.** Die Darstellung (`TC002Ansichten/Hilfe.swift`)
  und die Absätze, die vom Gerät unabhängig sind
  (`TC002Ansichten/HilfeInhalt.swift`), gelten für beide; `HilfeView` (Mac) und
  `HilfeiOS` (iPhone) setzen ihr Dokument daraus und aus eigenen Absätzen
  zusammen. Ein Absatz gehört nur dann nach `HilfeInhalt`, wenn er für **beide**
  Oberflächen wahr ist — Fenster, Seitenleiste, Inspektor, Finder, Malen und der
  Icon-Editor gibt es nur am Mac, und das ist mit dem Platz begründet: Ein
  8×8-Raster mit dem Finger ist keine Arbeitsfläche. Was **beide** können,
  gehört auch in beide Hilfen. Ein zweiter Satz mit derselben Aussage wäre ein
  zweiter Übersetzungsschlüssel; deshalb Konstanten statt zweimal
  geschrieben.
- **Das Repo ist öffentlich.** Vor jedem Commit läuft
  `scripts/private-spuren.sh` als Haken (`core.hooksPath=.githooks`) und sucht
  in den vorgemerkten Zeilen nach Hausnetzangaben und Geheimnissen. Der
  häufigste Weg hinein sind Planpapiere unter `docs/superpowers/`: Wer misst,
  schreibt auf, was er sieht. **Messwerte gehören in die Doku, Kennungen
  nicht** — Adressen, MAC, Host- und Netznamen durch Platzhalter ersetzen.
  Ein frisch geklonter Baum hat den Haken nicht; einmalig
  `git config core.hooksPath .githooks`.
- Das echte Gerät und der Broker im Hausnetz sind in Tests tabu — ebenso in
  jeder Arbeit, die ein **Agent** ausführt.

  **Ausnahme für die Sitzung selbst, erteilt am 19.09.2026.** Wer unmittelbar
  mit dem Auftraggeber arbeitet, darf die installierte Mac-App starten, sie
  abfragen und mitlesen lassen, sie fotografieren und auch Testmeldungen an
  die echten Uhren schicken — der MQTT-Zugang ist dafür nicht eingeschränkt.
  Vier Bedingungen:

  1. **Aufräumen.** Was zum Ausprobieren auf eine Uhr geschickt wurde, wird
     danach wieder gelöscht.
  2. **Die virtuelle Uhr zuerst.** Wo sie oder der Simulator ausreichen,
     werden sie genommen; das echte Gerät ist für das, was sich anders nicht
     zeigen lässt.
  3. **Subagenten nicht.** Sie laufen unbeaufsichtigt und in eigenen
     Arbeitsbäumen. Eine Bahn, die nebenher eine Uhr in der Wohnung abfragt,
     ist nicht gewollt.
  4. **Kein Bildschirmfoto mit echten Adressen ins Repo.** Das Repo ist
     öffentlich, und Bilder gehen am Haken `scripts/private-spuren.sh`
     vorbei — der liest nur Text.

  **iPhone und iPad des Auftraggebers: vorher fragen, jedes Mal.** `xcrun
  devicectl` erreicht die angeschlossenen Geräte — Bildschirmfoto, Aufnahme,
  App installieren, starten, beenden (tippen und wischen kann es nicht, so
  wenig wie `simctl`). Erlaubt am 19.09.2026, aber **nur nach Rückfrage vor
  dem jeweiligen Zugriff**: Ein Bildschirmfoto zeigt, was gerade offen ist,
  und ein Installieren tauscht die App auf einem Gerät, das der Auftraggeber
  in der Hand hat.

  **Der Simulator ist der Normalfall**, und zwar nicht nur aus Rücksicht: Dort
  lassen sich Anfangswerte patchen (`// SCHAUBILD`), um an einen Zustand zu
  kommen — am echten Gerät geht das nicht. Das Gerät ist für das, was der
  Simulator nicht zeigen kann: die wirkliche Verbindung zu den Uhren, den
  iCloud-Abgleich zwischen mehreren Geräten, und Darstellungsfragen, bei denen
  dem Simulator nicht zu trauen ist. Ihre Adressen stehen in den
  Einstellungen der App, nicht hier; wer sie braucht, bekommt sie im Auftrag
  genannt — eine veraltete Adresse hier schützt die falsche Maschine. Dafür
  gibt es Doppelgänger: `URLProtocol` für die
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

## Was in einen Kommentar gehört

Kommentare und Doc-Comments dokumentieren **Verhalten und Entscheidungen samt
Begründung** — sonst nichts. Der Leser will wissen, was gilt und warum es so
gewählt wurde, nicht, wie es dazu kam.

Nicht hinein gehören:

- **Geschichtsschreibung.** „Bis zum TT.MM.JJJJ stand hier …, dann fiel auf …"
  Der alte Zustand steht in der Versionsverwaltung. Ein Datum bleibt nur, wenn
  es selbst die Information ist: eine Messung am Gerät, eine
  Firmware-Beobachtung, ein Befund, den man nachprüfen können muss.
- **Rechtfertigungsprosa.** Rhetorische Wendungen („Das ist die Bauart, nicht
  ein Versehen"), Steigerungen, Fettung zur Betonung, Sätze, die dieselbe
  Aussage ein zweites Mal machen.
- **Erzählung.** Wer was wann bemerkt hat, wie lange gesucht wurde, wie es sich
  angefühlt hat.

Hinein gehört die Regel selbst, knapp: was der Code tut, welche Alternative
verworfen wurde und woran sie scheitert, welche Zahl gemessen ist. Zwei Sätze
reichen fast immer.

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
- **Der App-Intents-Schritt läuft nicht von selbst neu.** Ein Bündel kann
  `Metadata.appintents` vom Vortag tragen: Der Kurzbefehl ist übersetzt, im
  Bündel aber nicht vorhanden, und `** BUILD SUCCEEDED **` sagt dazu nichts.
  Wer einen
  `AppIntent` hinzufügt oder umbenennt, wirft danach den DerivedData-Ordner
  weg und baut neu; nachgesehen wird in
  `Metadata.appintents/extract.actionsdata`, ob der Typ darin steht.
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
`--name` schreibt darum **nicht** ins Slotgedächtnis. Gelesen wird die Datei
an zwei Stellen, und sie entscheiden verschieden:

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
(`Contents/MacOS/mqtttc002`) und wird über einen Verweis benutzt. Drei Fallen
dabei:

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
sind. Im iOS-Bündel kann jede einzelne Ressource fehlen, wenn `project.yml` sie
unter einem Schlüssel führt, den XcodeGen nicht kennt und stillschweigend
überliest — am Quelltext ist das nicht zu sehen, erst am Gerät.

Deshalb nach jedem Bau:

    sh scripts/buendel-pruefen.sh                    # iOS
    sh scripts/buendel-pruefen.sh erzeugt/mac/MQTT-TC002.app   # macOS

Und eine dritte, die kein Bündelprüfer sieht: **Das mitreisende Werkzeug darf
nicht mit den Berechtigungen der App signiert werden.** Die iCloud-Einträge sind
eingeschränkt und gelten nur zusammen mit einem Bereitstellungsprofil; ein Profil
lässt sich aber nur in ein Bündel einbetten, nicht in eine einzelne Mach-O-Datei.
macOS beendet `mqtttc002` dann beim Start sofort mit SIGKILL — ohne Meldung, ohne
Absturzbericht, `codesign --verify` meldet die Signatur als gültig. Nachgesehen
wird, indem man es ausführt:

    erzeugt/mac/MQTT-TC002.app/Contents/MacOS/mqtttc002 uhren

Der Preis: Ohne die Berechtigung erreicht es den iCloud-Behälter nicht und
arbeitet im örtlichen Ordner — bei eingeschaltetem Abgleich schreibt es sein
Slotgedächtnis damit woanders hin als die App.

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

**Beim iOS-Ziel schreibt der Schritt in die Quell-Plist, nicht ins Bündel** —
und zwar **vor** dem Bau (`preBuildScripts`). Xcode kopiert
`erzeugt/InfoiOS.plist` nämlich mit `ProcessInfoPlistFile` erst **nach** den
Skriptschritten über das Produkt; ein Nachlauf schreibt gegen etwas an, das
gleich überbügelt wird; das Bündel trägt dann bei jedem Bau dieselbe
Baunummer, und App Store Connect nimmt keine zweimal an. Nachgesehen wird am
fertigen Bündel, nicht an der Ausgabe des Schritts: Er meldet die richtigen
Zahlen auch dann, wenn sie nirgends ankommen.

## Die iOS-Fassung

`project.yml` beschreibt das Xcode-Projekt; `xcodegen generate` erzeugt es.
Die `.xcodeproj` wird **nicht** eingecheckt — wer eine Quelldatei hinzufügt,
ändert die YAML und erzeugt neu, statt in erzeugtem XML zu schneiden.

**Sie bleibt in der Wurzel**, obwohl alles andere Erzeugte unter `erzeugt/`
liegt. `xcodegen generate --project erzeugt/ios` legt es zwar dort ab, rechnet dabei aber nicht alles um: Der
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

Stattdessen an Ort und Stelle ersetzen, das erhaelt die Identitaet:

    ditto erzeugt/mac/MQTT-TC002.app /Applications/MQTT-TC002.app

Und die App moeglichst nur von **einem** Ort aus starten. Zwei Kopien mit
derselben Buendelkennung — etwa `/Applications` und `erzeugt/mac/` — verwirren die
Rechteverwaltung zusaetzlich.

Ist es doch passiert: Systemeinstellungen > Datenschutz & Sicherheit >
Lokales Netzwerk > den Eintrag aus- und wieder einschalten.
