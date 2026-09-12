# iOS-Fassung von MQTT-TC002 — Design

Eine iPhone-App, die Meldungen an eine Ulanzi TC002 schickt. Sie teilt sich mit
der bestehenden macOS-App den Kern und die Zustandsschicht; nur die Oberfläche
ist eigen.

**Ziel dieser ersten Fassung:** eine App auf dem eigenen Telefon, die man
wirklich benutzt — Uhr einrichten, Text mit Icon schicken, aufräumen. Kein
Verkauf, keine Fremdtester.

---

## Abgrenzung

Gebaut wird:

- **Verbindung** — Uhren eintragen, abfragen, entfernen; Broker einrichten und
  prüfen; Seitenwechsel und Scrolltempo der aktiven Uhr.
- **Senden** — Text mit Farbe, Schrift, Größe, Ausrichtung, Rand und Abstand;
  Icon aus einem mitgelieferten Grundschatz oder über die LaMetric-Nummer
  nachgeladen; Laufschrift bei zu langem Text; beide Wege (eigenes Raster und
  Gerätetext); Meldungsplatz 1 bis 5; Anzeigedauer; Zielauswahl bei mehr als
  einer Uhr.
- **Anzeigen** — was auf der Uhr steht, umschalten, löschen, dazu das Protokoll.

Nicht gebaut wird:

- **Icon-Editor.** Nicht zurückgestellt, sondern eine Festlegung: Icons werden
  am Schreibtisch bearbeitet, also am Mac und später am iPad. Auf dem iPhone
  wird es ihn nicht geben. Ein 8×8-Raster mit dem Finger auf einem
  Telefonbildschirm zu malen wäre eine Funktion, die man einmal ausprobiert und
  nie wieder benutzt. Icons **wählen** und über die LaMetric-Nummer
  **nachladen** geht auf dem iPhone sehr wohl.
- **Malen** (die freie 52×16-Fläche). Zurückgestellt, nicht ausgeschlossen. Mit
  dem Finger ist das eigenständige Arbeit, und auf einem Telefon braucht man es
  am wenigsten. Auf einem iPad mit Stift sähe die Rechnung anders aus.
- **Hilfe und Gerätereferenz.** Beide hängen am Markdown-Zerleger, der heute in
  der macOS-Schicht liegt. Später billig nachzurüsten.
- **iPad-eigenes Layout.** Die App läuft dort im iPhone-Fenster mit.
- **Abgleich der Icons mit dem Mac.** Eigenes Vorhaben (iCloud), nicht hier.
- **TestFlight und App Store.** Installiert wird aus Xcode aufs eigene Gerät.

---

## Entscheidungen und ihre Gründe

| Frage | Entscheidung | Grund |
|---|---|---|
| Wo entsteht der Code | Zweig im selben Repo | Der Kern bleibt eine Datei-Sammlung. Ein Klon hätte ihn ab Tag eins verdoppelt, und eine Korrektur am MQTT-Teil wäre zweimal zu machen — und würde irgendwann nur einmal gemacht. Der Zweig lässt sich wegwerfen, ohne dass `main` etwas merkt. |
| Erstes Gerät | iPhone, Hochformat | Die Mac-Aufteilung passt dort ohnehin nicht, also gibt es keine Versuchung, sie zu übernehmen. Und das Telefon hat man dabei. |
| Oberflächen-Wiederverwendung | Zustandsschicht geteilt, Ansichten neu | `AppZustand` importiert nur Foundation, Observation und den Kern — null AppKit. Es ist bereits portabel. Die Ansichten dagegen sind auf Fenstergrößen gebaut. |
| Icons | Grundschatz im Bündel, Nachladen in den App-Ordner | Unter iOS gibt es den geteilten Ordner des Macs nicht. Bündel plus Sandbox-Ordner bildet beides ab, was man braucht. |
| Projektdatei | `xcodegen` aus einer `project.yml` | `swift build` kann keine iOS-App. Eine eingecheckte `.xcodeproj` wäre die erste undurchsichtige Datei im Repo, und jede später hinzugefügte Quelldatei wäre ein Eingriff in 2000 Zeilen erzeugtes XML. |
| Untergrenze iOS 17 | keine freie Wahl | `@Observable` gibt es erst ab iOS 17, und `AppZustand` hängt daran. |
| Bündelkennung | dieselbe wie beim Mac | Apple sieht eine geteilte Kennung für dasselbe Produkt auf zwei Plattformen vor. Hält den Weg zu gemeinsamem Verkauf und iCloud-Abgleich offen. |
| Icons bearbeiten | nur am Schreibtisch | Mac und später iPad. Auf dem iPhone dauerhaft nicht — ein 8×8-Raster mit dem Finger ist keine Arbeitsfläche. Wählen und Nachladen geht überall. |

---

## Aufbau

Aus drei Zielen werden fünf.

```
Package.swift          platforms: macOS 14, iOS 17
                       products: TC002Core, TC002Modell (Bibliotheken),
                                 mqtttc002 (Programm, nur macOS)
Sources/
  TC002Core/           Gerät, Protokoll, Rasterung, Icons, Einstellungen
                       + NEU: Meldungsoptionen und Meldungsbau
  TC002Modell/         NEU: AppZustand
  TC002App/            macOS-Ansichten            (SendenView gibt Rechenteile ab)
  TC002CLI/            Kommandozeilenwerkzeug     (verliert Meldungsbau)
  TC002iOS/            NEU: iPhone-Ansichten
Tests/
  TC002CoreTests/      + NEU: MeldungsbauTests
  TC002ModellTests/    NEU: die bisherigen AppZustandTests, verschoben
  TC002AppTests/       verbleibende macOS-Tests
  TC002CLITests/       unverändert
project.yml            NEU: Beschreibung des iOS-Projekts für xcodegen
```

`TC002Modell` enthält zunächst nur `AppZustand`. Ein eigenes Ziel und nicht ein
Platz im Kern, weil der Kern frei von Oberflächenbelangen ist und ohne sie
geprüft werden kann; `AppZustand` ist dagegen an den Hauptakteur gebunden und
beobachtbar.

### Abhängigkeiten

```
TC002Core   ← TC002Modell ← TC002App   (macOS)
     ↑            ↑        ← TC002iOS  (iOS)
     └──────────────────── ← TC002CLI  (macOS)
```

Keine neuen Paketabhängigkeiten. `xcodegen` ist ein Entwicklungswerkzeug, keine
Abhängigkeit des Erzeugnisses.

---

## Was in den Kern wandert

Die Sendeansicht enthält heute Rechnungen, die keine Ansichtssache sind. Das
Kommandozeilenwerkzeug hat sie in `Sources/TC002CLI/Meldungsbau.swift` bereits
ein zweites Mal nachgebaut. Die iPhone-Fassung wäre das dritte Mal.

### `Meldungsoptionen`

Ein Wertetyp im Kern mit allem, was eine Meldung ausmacht. Die Felder
entsprechen eins zu eins den heutigen `@AppStorage`-Werten der Sendeansicht:

| Feld | Typ | heute gesichert als |
|---|---|---|
| `text` | `String` | `senden.text` |
| `weg` | `SendeWeg` | `senden.weg` |
| `schrift` | `String` | `senden.schriftart` |
| `groesse` | `Double` | `senden.groesse` |
| `fett` | `Bool` | `senden.fett` |
| `farbe` | `String` | `senden.farbe` |
| `grossbuchstaben` | `Bool` | `senden.grossbuchstaben` |
| `waagrecht` | `Waagrecht` | `senden.horizontal` |
| `senkrecht` | `Senkrecht` | `senden.vertikal` |
| `rand` | `Int` | `senden.rand` |
| `abstand` | `Int` | `senden.luecke` |
| `tempo` | `Lauftempo` | `senden.tempo` |
| `iconLaeuftMit` | `Bool` | `senden.iconmitlaufend` |
| `dauer` | `Int?` | `senden.dauer` |

Die drei Aufzählungen `SendeWeg`, `Waagrecht`, `Senkrecht` und `Lauftempo`
ziehen mit in den Kern. Ihre `rawValue`-Zeichenketten bleiben unverändert,
sonst lesen sich die gesicherten Einstellungen einer laufenden Installation
nicht mehr.

### `Meldungsbau`

```swift
public enum Meldungsbau {
    public static func rahmen(_ optionen: Meldungsoptionen,
                              icon: Icon?,
                              sammlung: Iconsammlung) throws -> Frame
    public static func passt(_ optionen: Meldungsoptionen, mitIcon: Bool) -> Bool
    public static func versatzX(_ optionen: Meldungsoptionen, mitIcon: Bool) -> Int
    public static func versatzY(_ optionen: Meldungsoptionen) -> Int
    public static func laufschriftBilder(_ optionen: Meldungsoptionen,
                                         iconBilder: [[String?]]) -> [Bildraster.Einzelbild]
}
```

Die Rechnungen selbst werden **nicht** verändert, nur verschoben. Die
senkrechte Ausrichtung geht weiterhin über `Textraster.tintenZeilen`, nicht
über die Schriftgröße.

`laufschriftBilder` steht neben `rahmen`, weil die Vorschau die Einzelbilder
selbst braucht, um sie abzuspielen, während `rahmen` sie bereits zu einem GIF
verpackt hat. Beide Oberflächen zeigen die Laufschrift laufend; sie zweimal zu
rastern wäre die teuerste Rechnung der App, doppelt ausgeführt.

Ein Hinweis zum Bauen: `TC002App` und `TC002CLI` sind nur unter macOS
übersetzbar, weil sie AppKit einbinden. Das ist kein Problem, weil das
iOS-Projekt ausschließlich von den beiden Bibliotheken abhängt und Xcode nur
baut, was verlangt wird.

### Absicherung des Verschiebens

Vor jeder Verschiebung entstehen Festnagel-Tests: Für eine Reihe von
Einstellungen wird das heutige Rahmen-JSON aufgezeichnet und als erwarteter
Wert eingetragen. Abgedeckt werden mindestens:

- kurzer Text, alle drei waagrechten und alle drei senkrechten Ausrichtungen
- Rand 0, 1, 3 bei „oben" und bei „unten"
- Abstand 0, 1, 3
- mit Icon und ohne
- ein Text, der läuft, mit Icon feststehend und mitlaufend
- der Weg „als Text" mit allen Ausrichtungen

Nach dem Verschieben müssen diese Tests Byte für Byte dasselbe liefern. Eine
Abweichung ist ein Fehler der Verschiebung, keine Verbesserung.

### Folge für die bestehenden Aufrufer

- `SendenView` behält seine `@AppStorage`-Felder und baut daraus
  `Meldungsoptionen`. Die Ansicht verliert `textX`, `textY`, `passt`,
  `gebauterRahmen()` und die Aufzählungen.
- `Sources/TC002CLI/Meldungsbau.swift` entfällt. `Optionen` des Werkzeugs
  bildet künftig auf `Meldungsoptionen` ab.
- `MeldungsplatzWahl.name(fuer:)` und `MeldungsplatzWahl.anzahl` wandern in den
  Kern, weil beide Oberflächen sie brauchen.

---

## Die iPhone-Oberfläche

Drei Reiter unten: Senden, Anzeigen, Verbindung.

### Senden

Aufgebaut wie ein Nachrichtenfenster, von oben nach unten:

1. **Zieluhr in der Titelleiste.** Antippen öffnet die Auswahl. Nur sichtbar
   bei mehr als einer eingerichteten Uhr.
2. **Vorschau**, fest oben. 52×16 Pixel bei sechsfacher Vergrößerung, also 312
   auf 96 Punkte. Bleibt sichtbar, während die Tastatur offen ist.
3. **Meldungsplatz und Dauer** als schmale Zeile. Beides gilt für alles, was
   geschickt wird, und überlebt den Neustart.
4. **Formatleiste** unmittelbar über dem Eingabefeld. Direkt erreichbar: Farbe,
   Icon, Ausrichtung. Alles Übrige — Schriftart, Größe, Fett, Großbuchstaben,
   Rand, Abstand, Tempo, Weg — hinter einem Knopf, der ein Blatt öffnet.
5. **Eingabefeld und Sendeknopf** ganz unten, über der Tastatur.

Wird der Platz knapp, weicht zuerst Zeile 3. Reicht das nicht, fällt die
Formatleiste auf ihre Kurzfassung zusammen: nur noch Farbe und Icon, die
Ausrichtung wandert ins Blatt. Vorschau, Eingabefeld und Sendeknopf bleiben
immer sichtbar.

### Anzeigen

Liste dessen, was auf der aktiven Uhr steht, mit Herkunftsangabe (vom Gerät
gemeldet oder von dieser App angelegt). Je Zeile „Zeigen" und „Löschen".
Darunter das Protokoll mit einem Knopf zum Leeren.

### Verbindung

Liste der Uhren mit Name, Adresse, ermitteltem Präfix und Verbindungsstand; je
Zeile „Abfragen" und „Entfernen"; darunter ein Feld zum Hinzufügen. Dann
Seitenwechsel und Scrolltempo der aktiven Uhr, dann der Broker-Abschnitt mit
Adresse, Port, Benutzer, Kennwort und „Sichern und prüfen".

---

## Besonderheiten von iOS

**Freigabe fürs lokale Netzwerk.** Seit iOS 14 nötig, um eine Uhr oder einen
Broker im eigenen Netz zu erreichen. `NSLocalNetworkUsageDescription` steht von
Anfang an in der `project.yml`. Ohne sie scheitert der erste Versuch mit einer
Meldung, die in die falsche Richtung zeigt — derselbe Fall wie auf dem Mac.

**Hintergrund.** Eine offene MQTT-Verbindung überlebt den Wechsel in den
Hintergrund nicht. `AppZustand` bekommt dafür zwei Methoden, die die
iOS-Oberfläche an den Lebenszyklus hängt: beim Verlassen wird der Zuhörer
beendet, beim Zurückkommen neu aufgebaut. Auf dem Mac wird nichts davon
gerufen.

**Schriften.** `Schriften.registrieren()` im Kern benutzt CoreText und
funktioniert unter iOS unverändert, sofern der Ordner `Schriften` als Ressource
mitkommt.

**Programmsymbol.** Für iOS 17 werden die herkömmlichen Bildgrößen gebraucht,
nicht nur das Icon-Composer-Bündel. Sie werden aus dem vorhandenen Symbol
erzeugt und als Asset-Katalog abgelegt.

---

## Fehlerbehandlung

Unverändert die der Zustandsschicht, die bereits zwischen Broker- und
Gerätefehlern unterscheidet und jede Meldung zugleich ins Protokoll schreibt.
Die iPhone-Oberfläche zeigt `AppZustand.fehler` als Hinweisleiste unter der
Titelleiste, nicht als Blatt: Ein Blatt verdeckte die Vorschau, und die
Fehlermeldungen sind Hinweise, keine Entscheidungen.

---

## Bauen

```bash
brew install xcodegen          # einmalig
xcodegen generate              # erzeugt MQTT-TC002-iOS.xcodeproj
```

Die erzeugte Projektdatei wird **nicht** eingecheckt; `.gitignore` bekommt einen
Eintrag. Signiert wird automatisch mit der Mannschaftskennung `25ZK4SS655`.

Geprüft wird bei der Entwicklung gegen den Simulator:

```bash
xcodebuild -project MQTT-TC002-iOS.xcodeproj -scheme MQTT-TC002-iOS \
           -destination 'generic/platform=iOS Simulator' build
```

Das findet jeden Übersetzungsfehler und jede fehlende Ressource. Wie es
aussieht und sich anfühlt, zeigt erst das Gerät; installiert wird aus Xcode.

---

## Tests

`swift test` läuft weiter auf macOS und deckt Kern, Modell und Werkzeug ab. Die
bestehenden 159 Tests bleiben gültig; `AppZustandTests` wandern mit `AppZustand`
nach `TC002ModellTests`.

Neu hinzu kommen die Festnagel-Tests des Rahmenbaus (siehe oben) und Tests für
`Meldungsoptionen`, insbesondere dass die `rawValue`-Zeichenketten der
Aufzählungen unverändert bleiben — sie sind ein Dateiformat, genau wie die
`Codable`-Form von `Uhr`.

Für die iPhone-Oberfläche entstehen in dieser Fassung **keine** automatischen
Tests. Oberflächentests sind teuer und brüchig, und ihr Nutzen beginnt erst,
wenn die Form steht.

---

## Reihenfolge

1. Festnagel-Tests des heutigen Rahmenbaus, gegen die unveränderte Mac-App.
2. `Meldungsoptionen` und `Meldungsbau` in den Kern; `SendenView` und das
   Kommandozeilenwerkzeug darauf umstellen; Tests müssen unverändert grün sein.
3. `AppZustand` nach `TC002Modell`; `Package.swift` um iOS und die Produkte
   erweitern; `swift test` grün.
4. `project.yml`, Programmsymbol, Simulatorbau ohne Oberfläche.
5. Die drei Reiter, in der Reihenfolge Verbindung, Senden, Anzeigen — ohne
   Verbindung lässt sich das Senden nicht ausprobieren.
6. Auf dem Gerät prüfen.

Nach Schritt 3 ist die Mac-App noch genau die von heute, nur anders sortiert.
Das ist der Punkt, an dem sich am billigsten umkehren lässt.
