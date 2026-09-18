import XCTest

/// B1. Ein Stil lässt sich schlecht prüfen — der Übersetzer hat dazu nichts
/// zu sagen, und ohne Gerät sieht es niemand. Der Quelltext lässt sich
/// dagegen prüfen, und genau darum geht es hier: Kein Befehlsknopf steht
/// ohne Stil da, und kein Eingabefeld ohne Fassung.
///
/// Der Mangel, den das abfängt, ist der stumme: Ohne ausdrücklichen Stil
/// nimmt SwiftUI `.automatic`, und die sieht auf den beiden Geräten
/// verschieden aus — am Mac ein gerahmter Knopf, unter iPadOS bloße Schrift
/// in der Akzentfarbe. Ein Befehl sah dort damit aus wie ein Verweis. Ein
/// neuer Knopf, den jemand ohne Stil hinschreibt, fällt beim Übersetzen nicht
/// auf und auf dem Mac auch beim Ansehen nicht.
///
/// Geprüft wird nicht, welcher Stil dasteht, sondern dass einer dasteht.
/// `.plain`, `.borderless` und das ausdrückliche `.automatic` zählen mit:
/// Sie sind Entscheidungen — für eine Kachel, ein Löschzeichen, eine
/// Listenzeile — und stehen als solche im Quelltext. Vergessen zählt nicht.
///
/// Gleicher Weg wie `PlattformwegeTests` und `EditorbereichTests`: nachsehen
/// im Quelltext, Kommentare weg.
final class KnopfstilTests: XCTestCase {
    private static let wurzel = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Wo ein Knopf keinen eigenen Stil braucht, weil ihn das System
    /// setzt und ein eigener dort falsch wäre: Rückfragen, Menüs,
    /// Werkzeug- und Tastaturleisten, Wischgesten, das Mac-Menü.
    private static let ausnahmen = [
        "alert(", "confirmationDialog(", "contextMenu", "swipeActions",
        "toolbar", "ToolbarItem", "ToolbarItemGroup",
        "Menu {", "Menu(", "commands", "CommandGroup(", "CommandMenu(",
        // Das Titelmenue des Telefons: `toolbarTitleMenu` unter einem eigenen
        // Namen (`SendeniOS.swift`). Was darin steht, ist ein Menueeintrag —
        // ein Knopfstil waere dort so falsch wie in jedem anderen Menue.
        "titelmenuFallsMehrereUhren",
    ]

    /// Was als ausdrücklicher Stil gilt.
    private static let stile = [
        ".knopfBefehl()", ".knopfHaupthandlung()", ".knopfZerstoerend()",
        ".buttonStyle(",
    ]

    private static let ordner = [
        "Sources/TC002Ansichten", "Sources/TC002App", "Sources/TC002iOS",
    ]

    // MARK: - Quelltext lesen

    private struct Zeile {
        let text: String
        let einzug: Int
        let nackt: String
    }

    /// Zeilen ohne Kommentare, samt Einzug. Der Einzug trägt hier die ganze
    /// Struktur: In SwiftUI hängt die Modifikatorenkette eines Knopfes
    /// entweder tiefer als er oder gleich tief und beginnt mit einem Punkt.
    private func zeilen(_ pfad: String) throws -> [Zeile] {
        let url = Self.wurzel.appendingPathComponent(pfad)
        let roh = try String(contentsOf: url, encoding: .utf8)
        return roh.split(separator: "\n", omittingEmptySubsequences: false).map { z in
            let ohneKommentar: String
            if let strich = z.range(of: "//") {
                ohneKommentar = String(z[z.startIndex..<strich.lowerBound])
            } else {
                ohneKommentar = String(z)
            }
            let nackt = ohneKommentar.trimmingCharacters(in: .whitespaces)
            let einzug = ohneKommentar.prefix { $0 == " " }.count
            return Zeile(text: ohneKommentar, einzug: nackt.isEmpty ? Int.max : einzug, nackt: nackt)
        }
    }

    private func swiftDateien(unter ordner: String) -> [String] {
        let basis = Self.wurzel.appendingPathComponent(ordner)
        let inhalt = (try? FileManager.default.contentsOfDirectory(atPath: basis.path)) ?? []
        return inhalt.filter { $0.hasSuffix(".swift") }.sorted().map { "\(ordner)/\($0)" }
    }

    // MARK: - Der Scanner

    /// Steht dieser Knopf in einer der Ausnahmen? Dafür wird von der
    /// Knopfzeile aus nach außen gegangen: die jeweils nächste Zeile mit
    /// geringerem Einzug ist der umschließende Aufruf. Abgebrochen wird an
    /// der Deklaration, in der der Knopf steht — weiter außen steht nur noch
    /// der Typ.
    private func istAusgenommen(_ alle: [Zeile], ab stelle: Int) -> Bool {
        stehtIn(alle, ab: stelle, einem: Self.ausnahmen)
    }

    /// Derselbe Gang nach aussen, aber nach frei gewaehlten Umgebungen — die
    /// Grundlage der Kachelregel weiter unten.
    private func stehtIn(_ alle: [Zeile], ab stelle: Int, einem woerter: [String]) -> Bool {
        var einzug = alle[stelle].einzug
        var i = stelle - 1
        while i >= 0 {
            let z = alle[i]
            // Tiefer eingerückt heißt: gehört zu einem Geschwister, nicht zum
            // umschließenden Aufruf.
            if z.einzug > einzug { i -= 1; continue }
            // Gleich tief zählt mit: Ein Aufruf über mehrere Zeilen
            // (`confirmationDialog(` … `) { eintrag in`) trägt seinen Namen in
            // der ersten davon, und die steht nicht flacher als der Rest.
            if woerter.contains(where: { z.nackt.contains($0) }) { return true }
            if z.nackt.hasPrefix("var ") || z.nackt.hasPrefix("private var ")
                || z.nackt.hasPrefix("func ") || z.nackt.hasPrefix("private func ")
                || z.nackt.hasPrefix("struct ") || z.nackt.hasPrefix("public struct ")
                || z.nackt.hasPrefix("extension ") {
                return false
            }
            einzug = z.einzug
            i -= 1
        }
        return false
    }

    /// Die Modifikatorenkette eines Knopfes: alles, was tiefer eingerückt
    /// folgt, dazu die Zeilen auf seiner eigenen Höhe, die mit `.` oder `}`
    /// beginnen. Der erste Geschwisterausdruck beendet sie — so schlägt der
    /// Stil des nächsten Knopfes nicht auf diesen durch.
    private func kette(_ alle: [Zeile], ab stelle: Int) -> String {
        var stuecke = [alle[stelle].nackt]
        var i = stelle + 1
        while i < alle.count {
            let z = alle[i]
            if z.einzug == Int.max { i += 1; continue }
            if z.einzug > alle[stelle].einzug
                || (z.einzug == alle[stelle].einzug
                    && (z.nackt.hasPrefix(".") || z.nackt.hasPrefix("}"))) {
                stuecke.append(z.nackt)
                i += 1
                continue
            }
            break
        }
        return stuecke.joined(separator: "\n")
    }

    // MARK: - Die Prüfungen

    /// Jeder Knopf, der nicht in einer Ausnahme steht, trägt einen
    /// ausdrücklichen Stil.
    func testKeinBefehlsknopfOhneStil() throws {
        var ohneStil: [String] = []
        for ordner in Self.ordner {
            for datei in swiftDateien(unter: ordner) {
                let alle = try zeilen(datei)
                for (i, z) in alle.enumerated() {
                    guard z.nackt.range(of: #"\bButton\s*[\(\{]"#, options: .regularExpression) != nil
                    else { continue }
                    if istAusgenommen(alle, ab: i) { continue }
                    let kette = kette(alle, ab: i)
                    if Self.stile.contains(where: { kette.contains($0) }) { continue }
                    ohneStil.append("\(datei):\(i + 1)  \(z.nackt)")
                }
            }
        }
        XCTAssertTrue(ohneStil.isEmpty,
                      "Diese Knöpfe stehen ohne ausdrücklichen Stil da. Unter iPadOS sehen sie "
                      + "damit aus wie Verweise. Einen der drei Aufrufe aus `Knopfstil.swift` "
                      + "setzen — oder, wenn es wirklich keiner ist, `.buttonStyle(.automatic)` "
                      + "samt Begründung:\n" + ohneStil.joined(separator: "\n"))
    }

    /// Und auf den beiden Schreibtischen (`TC002Ansichten` — Mac und iPad)
    /// trägt jedes Eingabefeld seine Fassung.
    ///
    /// Warum nicht auch `TC002iOS`: Das Telefon zeigt seine Felder in einer
    /// `Form` oder einem Blatt, und dort ist der Kanon Beschriftung links,
    /// rechts angeschlagener Wert ohne Kasten — wie in den
    /// Systemeinstellungen. Ein Rahmen wäre dort der falsche Kanon, nicht
    /// die fehlende Fassung.
    ///
    /// `.eingabefeld(loeschbar:)` zählt mit: Dieselbe Fassung, dazu ein (x)
    /// für die flüchtigen Felder. Geprüft wird auf `.eingabefeld(` und nicht
    /// auf die leere Klammer — die Zusicherung ist „jedes Feld trägt die
    /// Fassung", nicht „jedes trägt genau diese Schreibweise".
    func testKeinEingabefeldOhneFassung() throws {
        var ohneFassung: [String] = []
        for datei in swiftDateien(unter: "Sources/TC002Ansichten") {
            let alle = try zeilen(datei)
            for (i, z) in alle.enumerated() {
                guard z.nackt.contains("TextField(") || z.nackt.contains("SecureField(") else { continue }
                if kette(alle, ab: i).contains(".eingabefeld(") { continue }
                ohneFassung.append("\(datei):\(i + 1)  \(z.nackt)")
            }
        }
        XCTAssertTrue(ohneFassung.isEmpty,
                      "Diesen Feldern fehlt die Fassung (`Eingabefeld.swift`). Ohne sie zeigt die "
                      + "Zeile nur ihre Beschriftung, und wo zu tippen ist, sieht man erst nach "
                      + "dem Hineinklicken:\n" + ohneFassung.joined(separator: "\n"))
    }

    /// Nicht nachbauen, was das System zeichnet.
    ///
    /// Ein blanker `Picker("Schriftart", selection:)` in einem gruppierten
    /// `Form` zeichnet die kanonische Zeile selbst: Beschriftung links, Wert
    /// im grauen Kästchen mit Doppelpfeil rechts — auf beiden Geräten, in
    /// hell und dunkel, bei jeder Textgröße und in jeder Sprache. Wickelt man
    /// ihn in `LabeledContent` und nimmt ihm mit `labelsHidden()` seine
    /// Beschriftung, verliert er genau diese Darstellung und fällt unter
    /// iPadOS auf blanken Text mit Doppelpfeil zurück.
    ///
    /// Der Fehler ist unsichtbar: Am Mac sieht die Umwicklung fast gleich
    /// aus, und der Übersetzer hat dazu nichts zu sagen.
    ///
    /// Für `TextField` gilt das nicht — dort ist die Umwicklung begründet:
    /// Unter iPadOS macht SwiftUI aus der Beschriftung eines Feldes den
    /// Platzhalter, und der verschwindet, sobald etwas darin steht (siehe
    /// `VerbindungView.brokerAbschnitt`). Deshalb prüft dieser Test nur
    /// Wähler.
    func testKeinWaehlerWirdUmwickeltUndEntwertet() throws {
        var umwickelt: [String] = []
        for datei in swiftDateien(unter: "Sources/TC002Ansichten") {
            let alle = try zeilen(datei)
            for (i, z) in alle.enumerated() {
                guard z.nackt.contains("LabeledContent(") else { continue }
                let block = kette(alle, ab: i)
                guard block.contains("labelsHidden()") else { continue }
                // Genau einer. Die Regel zielt auf den Waehler, der allein
                // in einer Zeile steht: Der zeichnet sie in einer gruppierten
                // `Form` selbst, und die Umwicklung nimmt ihm genau das.
                //
                // Stehen zwei Waehler in einer Zeile — „Schrift" traegt
                // Schriftart und Groesse nebeneinander, wie es Pages haelt
                // —, geht es ohne Klammer nicht, und dann gehoert die
                // Beschriftung ihr. Die Ausnahme ist am Doppelpunkt
                // abzulesen und nicht zu erschleichen: Wer einen einzelnen
                // Waehler umwickelt, faellt hier weiterhin. Mit Wortgrenze
                // gezaehlt, sonst zaehlte `ColorPicker(` mit — und die Zeile
                // „Stil", die zwei Schalter und den Farbwaehler traegt,
                // faellt faelschlich.
                let waehler = block.ranges(of: #/\bPicker\(/#).count
                guard waehler == 1 else { continue }
                umwickelt.append("\(datei):\(i + 1)  \(z.nackt)")
            }
        }
        XCTAssertTrue(umwickelt.isEmpty,
                      "Hier ist ein Wähler wieder in `LabeledContent` gewickelt und mit "
                      + "`labelsHidden()` entwertet. Ein blanker Picker in der `Form` zeichnet "
                      + "die Zeile selbst — und zwar auf beiden Geräten richtig:\n"
                      + umwickelt.joined(separator: "\n"))
    }

    /// Die Schrittwahl ist ein Element mit Trennstrich, nicht zwei Knöpfe,
    /// und ihr Wert steht in einem eigenen Kästchen. Beides steckt in
    /// `Schrittwahl`; hier steht, dass die drei Stellen sie auch benutzen und
    /// nicht wieder je einen nackten `Stepper` hinschreiben.
    func testDieDreiSchrittwahlenGehenUeberDasGemeinsameElement() throws {
        // „Scrolltempo" gehoert in die Einstellungen (`Uhreinstellungen`),
        // weil es das Geraet einstellt und nicht die Meldung. Im Zeit-Reiter
        // (`Zeitabschnitte`) bleiben Dauer und Lauftempo, beide ohne
        // Schrittwahl.
        for (datei, anzahl) in [("Sources/TC002Ansichten/SendenView.swift", 2),
                                ("Sources/TC002Ansichten/Uhreinstellungen.swift", 1)] {
            let text = try zeilen(datei).map(\.text).joined(separator: "\n")
            let treffer = text.components(separatedBy: "Schrittwahl(").count - 1
            XCTAssertEqual(treffer, anzahl,
                           "\(datei) hat nicht mehr \(anzahl) Schrittwahl(en) — "
                           + "steht dort wieder ein nackter Stepper ohne Wertkästchen?")
            XCTAssertFalse(text.contains("Stepper("),
                           "\(datei) baut wieder einen Stepper von Hand; "
                           + "der trägt weder Kästchen noch die gemeinsame Fassung")
        }
    }

    // MARK: - Die Kachelregel

    /// Ein Knopf in einer Rasterkachel ist `.plain`, nie `.automatic`.
    ///
    /// Eine Zeile einer `List` oder `Form` ist am Telefon selbst ein
    /// Bedienelement. Knöpfe mit dem vorgegebenen Stil darin teilen sich
    /// ihre Trefferfläche, und ein Tipp landet beim ersten: Im Editor traf
    /// „Neu“ statt „Sichern“; im Auswahlraster öffneten vierzig Kacheln
    /// dasselbe Icon.
    ///
    /// Geprüft wird die Umgebung, nicht die Datei: Jeder Knopf, der von einem
    /// `LazyVGrid` umschlossen ist, muss einen Stil tragen, der ihn als
    /// eigenes Bedienelement stehen lässt.
    func testEinKnopfInEinerRasterkachelTraegtKeinenVorgegebenenStil() throws {
        var beanstandet: [String] = []
        for ordner in Self.ordner {
            for pfad in swiftDateien(unter: ordner) {
                let alle = try zeilen(pfad)
                for (i, z) in alle.enumerated() where z.nackt.contains("Button") {
                    guard stehtIn(alle, ab: i, einem: ["LazyVGrid", "LazyHGrid"]) else { continue }
                    let k = kette(alle, ab: i)
                    guard k.contains(".buttonStyle(") else { continue }
                    if k.contains(".buttonStyle(.automatic)") {
                        beanstandet.append("\(pfad):\(i + 1)")
                    }
                }
            }
        }
        XCTAssertEqual(beanstandet, [],
                       "Knopf in einer Rasterkachel mit `.automatic`: Die Zeile der Liste nimmt den "
                       + "Tipp entgegen, nicht die Kachel — alle Kacheln lösen dann dieselbe Wahl aus")
    }

    // MARK: - Der Sperrklinken-Bestand

    /// Wo `.automatic` ausdrücklich richtig ist — und nirgends sonst.
    ///
    /// `.automatic` ist eine Entscheidung, keine Vergesslichkeit (siehe oben),
    /// aber eine, die nur an wenigen Stellen stimmt: bei einer Listenzeile,
    /// die für sich allein steht und weiterführt, bei den Kapseln der
    /// Formatpille, die keine Listenzeile sind, und beim plattformabhängigen
    /// Rückfall in `UeberView`. Diese Summe hält den Bestand fest: Eine neue
    /// Stelle fällt auf und will begründet werden, statt still dazuzukommen.
    func testDerBestandAnVorgegebenenStilenIstBekannt() throws {
        // Datei → Anzahl, mit dem Grund in einem Wort.
        let bekannt: [String: Int] = [
            // Die schiebbare Formatpille: Kapseln in einem `ScrollView`,
            // keine Listenzeilen — dort ist `.automatic` das Aussehen, das
            // die Pille haben soll (5: Icon, Format, Bild, Fett,
            // Großbuchstaben). Der Sendeknopf fehlt hier — die Eingabetaste
            // schickt, wie in Nachrichten.
            "Sources/TC002iOS/SendeniOS.swift": 5,
            // „Hilfe“ und „Über MQTT-TC002“: zwei Listenzeilen, die
            // weiterführen, jede für sich allein in ihrer Zeile.
            "Sources/TC002iOS/VerbindungiOS.swift": 2,
            // „Kein Icon“ — dieselbe Bauart, eigene Zeile.
            "Sources/TC002iOS/IconauswahliOS.swift": 1,
            // Die Löschzeile im Verlauf, allein in ihrer Zeile.
            "Sources/TC002iOS/AnzeigeniOS.swift": 1,
            // Plattformabhängiger Rückfall: `.link` gibt es nur am Mac.
            "Sources/TC002Ansichten/UeberView.swift": 1,
            // „Fertig“ im Nebenfenster-Blatt des iPads.
            "Sources/TC002Ansichten/SchreibtischView.swift": 1,
        ]
        var gefunden: [String: Int] = [:]
        for ordner in Self.ordner {
            for pfad in swiftDateien(unter: ordner) {
                let text = try zeilen(pfad).map(\.nackt).joined(separator: "\n")
                let anzahl = text.components(separatedBy: ".buttonStyle(.automatic)").count - 1
                if anzahl > 0 { gefunden[pfad] = anzahl }
            }
        }
        XCTAssertEqual(gefunden, bekannt,
                       "Der Bestand an `.buttonStyle(.automatic)` hat sich geändert. Jede Stelle ist "
                       + "eine Entscheidung: In einer Listenzeile mit mehreren Bedienelementen ist sie "
                       + "falsch (siehe die Kachelregel darüber), sonst kann sie richtig sein — dann "
                       + "gehört sie hier eingetragen, mit dem Grund.")
    }
}
